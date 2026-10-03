use axum::{Router, body::{Body, to_bytes}, routing::any};
use bytes::Bytes;
use http_body_util::{BodyExt, Limited};
use hyper::{Request, Response, header::HeaderMap, body::Incoming, service::service_fn};
use hyper_util::rt::TokioIo;
use std::convert::Infallible;

const LIMIT: usize = 8 * 1024 * 1024;
const TEXT: &str = "text/plain; charset=utf-8";
#[derive(Clone, Copy)]
enum Job { Text, Json, Decode, Echo, Hooks(u32), User, Route(u32), Missing }
fn select(path: &str, profile: u32) -> Job {
    if profile > 0 {
        if let Some(value) = path.strip_prefix("/route/").and_then(|s| s.parse::<u32>().ok()) {
            if value < profile && path == format!("/route/{value}") { return Job::Route(value); }
        }
        return Job::Missing;
    }
    match path {
        "/text" => Job::Text, "/json" => Job::Json, "/decode" => Job::Decode, "/echo" => Job::Echo,
        "/hooks/0" => Job::Hooks(0), "/hooks/1" => Job::Hooks(1), "/hooks/5" => Job::Hooks(5),
        value if value.starts_with("/users/") && !value[7..].contains('/') && value.len() > 7 => Job::User,
        _ => Job::Missing,
    }
}
fn reply(status: u16, body: Bytes, fields: &[(&str, &str)], head: bool) -> Response<Body> {
    let mut builder = Response::builder().status(status).header("content-length", body.len());
    for (key, value) in fields { builder = builder.header(*key, *value); }
    builder.body(if head { Body::empty() } else { Body::from(body) }).unwrap()
}
fn text(status: u16, value: &'static str, head: bool) -> Response<Body> {
    reply(status, Bytes::from_static(value.as_bytes()), &[("content-type", TEXT)], head)
}
fn json(value: serde_json::Value, head: bool) -> Response<Body> {
    reply(200, Bytes::from(serde_json::to_vec(&value).unwrap()), &[("content-type", "application/json")], head)
}
fn business(job: Job, method: &str, path: &str, fields: &HeaderMap, body: Bytes) -> Response<Body> {
    let head = method == "HEAD";
    let get = method == "GET" || head;
    if matches!(job, Job::Missing) { return text(404, "not found", head); }
    if matches!(job, Job::Decode | Job::Echo) {
        if method != "POST" { return reply(405, Bytes::new(), &[("allow", "POST")], head); }
        if matches!(job, Job::Echo) { return reply(200, body, &[("content-type", "application/octet-stream")], false); }
        if fields.get("content-type").and_then(|v| v.to_str().ok()) != Some("application/json") { return text(415, "unsupported media type", false); }
        if let Ok(value) = serde_json::from_slice::<serde_json::Value>(&body) {
            if let Some(object) = value.as_object() {
                if object.len() == 1 {
                    if let Some(name) = object.get("name").and_then(|v| v.as_str()).filter(|v| !v.is_empty()) {
                        return json(serde_json::json!({"name":name}), false);
                    }
                }
            }
        }
        return text(400, "invalid name", false);
    }
    if matches!(job, Job::User) {
        let raw = &path[7..];
        let id = if raw.bytes().all(|c| c.is_ascii_digit()) { raw.parse::<u32>().ok() } else { None };
        let Some(id) = id else { return text(400, "invalid id", head); };
        if !get { return reply(405, Bytes::new(), &[("allow", "GET, HEAD")], head); }
        return json(serde_json::json!({"id":id}), head);
    }
    if !get { return reply(405, Bytes::new(), &[("allow", "GET, HEAD")], head); }
    match job {
        Job::Text => text(200, "OK\n", head),
        Job::Json => reply(200, Bytes::from_static(b"{\"ok\":true}"), &[("content-type", "application/json")], head),
        Job::Route(id) => json(serde_json::json!({"id":id}), head),
        Job::Hooks(count) => {
            for _ in 0..count {
                if fields.get("authorization").and_then(|v| v.to_str().ok()) != Some("Bearer alice") {
                    return reply(401, Bytes::new(), &[("www-authenticate", "Bearer")], head);
                }
            }
            reply(200, Bytes::from_static(b"{\"ok\":true}"), &[("content-type", "application/json"), ("x-hook-count", &count.to_string())], head)
        }
        _ => unreachable!(),
    }
}
async fn framework(job: Job, request: Request<Body>) -> Response<Body> {
    let (parts, body) = request.into_parts();
    match to_bytes(body, LIMIT).await {
        Ok(body) => business(job, parts.method.as_str(), parts.uri.path(), &parts.headers, body),
        Err(_) => reply(413, Bytes::new(), &[], false),
    }
}
async fn raw(request: Request<Incoming>, profile: u32) -> Result<Response<Body>, Infallible> {
    let (parts, body) = request.into_parts();
    let result = match Limited::new(body, LIMIT).collect().await {
        Ok(body) => business(select(parts.uri.path(), profile), parts.method.as_str(), parts.uri.path(), &parts.headers, body.to_bytes()),
        Err(_) => reply(413, Bytes::new(), &[], false),
    };
    Ok(result)
}
#[tokio::main(flavor = "current_thread")]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mode = &args[1];
    let profile: u32 = args[2].parse().unwrap();
    let port: u16 = args[3].parse().unwrap();
    let listener = tokio::net::TcpListener::bind(("127.0.0.1", port)).await.unwrap();
    println!("READY");
    if mode == "raw" {
        loop {
            let (socket, _) = listener.accept().await.unwrap();
            tokio::spawn(async move {
                let _ = hyper::server::conn::http1::Builder::new().serve_connection(TokioIo::new(socket), service_fn(move |request| raw(request, profile))).await;
            });
        }
    } else if mode == "framework" {
        let mut router = Router::new();
        let mut jobs = vec![];
        if profile > 0 { for id in 0..profile { jobs.push((format!("/route/{id}"), Job::Route(id))); } }
        else {
            for path in ["/text", "/json", "/decode", "/echo", "/hooks/0", "/hooks/1", "/hooks/5"] { jobs.push((path.to_owned(), select(path, 0))); }
            jobs.push(("/users/{id}".to_owned(), Job::User));
        }
        for (path, job) in jobs {
            router = router.route(&path, any(move |request| framework(job, request)));
        }
        router = router.fallback(|request| framework(Job::Missing, request));
        axum::serve(listener, router).await.unwrap();
    } else { panic!("expected raw or framework"); }
}
