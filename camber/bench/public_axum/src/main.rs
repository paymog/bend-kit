use axum::{Router, body::{Body, Bytes, to_bytes}, http::{Request, Response}, routing::any, middleware::{self, Next}};
use std::time::Instant;
const LIMIT: usize = 8388608;
#[derive(Clone, Copy)]
enum Job { Text, Json, Parameter, Decode, Echo, Hooks(u32), Route(u32) }
fn reply(status: u16, body: Bytes, fields: &[(&str, &str)]) -> Response<Body> {
    let mut builder = Response::builder().status(status).header("content-length", body.len());
    for (k,v) in fields { builder = builder.header(*k,*v); }
    builder.body(Body::from(body)).unwrap()
}
fn text(status: u16, body: &'static str) -> Response<Body> { reply(status, Bytes::from_static(body.as_bytes()), &[("content-type","text/plain; charset=utf-8")]) }
fn json(value: serde_json::Value) -> Response<Body> { reply(200, Bytes::from(serde_json::to_vec(&value).unwrap()), &[("content-type","application/json")]) }
async fn hook(request: Request<Body>, next: Next) -> Response<Body> {
    if request.headers().get("authorization").and_then(|v|v.to_str().ok()) != Some("Bearer alice") { return reply(401, Bytes::new(), &[("www-authenticate","Bearer")]); }
    next.run(request).await
}
async fn handle(job: Job, request: Request<Body>) -> Response<Body> {
    let (parts, body) = request.into_parts();
    let post = matches!(job, Job::Decode|Job::Echo);
    if (post && parts.method != "POST") || (!post && parts.method != "GET" && parts.method != "HEAD") { return reply(405, Bytes::new(), &[("allow", if post {"OPTIONS, POST"} else {"GET, HEAD, OPTIONS"})]); }
    let body = match to_bytes(body,LIMIT).await { Ok(b)=>b, Err(_)=>return reply(413,Bytes::new(),&[]) };
    match job {
        Job::Text=>text(200,"OK\n"),
        Job::Json=>reply(200,Bytes::from_static(b"{\"ok\":true}"),&[("content-type","application/json")]),
        Job::Route(id)=>json(serde_json::json!({"id":id})),
        Job::Parameter=>{
            let raw=parts.uri.path().strip_prefix("/users/").unwrap_or("");
            if raw.is_empty() || !raw.bytes().all(|b|b.is_ascii_digit()) {return text(400,"invalid id");}
            match raw.parse::<u32>() {Ok(id)=>json(serde_json::json!({"id":id})),Err(_)=>text(400,"invalid id")}
        },
        Job::Hooks(n)=>reply(200,Bytes::from_static(b"{\"ok\":true}"),&[("content-type","application/json"),("x-hook-count",&n.to_string())]),
        Job::Echo=>reply(200,body,&[("content-type","application/octet-stream")]),
        Job::Decode=>{
            if parts.headers.get("content-type").and_then(|v|v.to_str().ok())!=Some("application/json") {return text(415,"invalid name");}
            if let Ok(value)=serde_json::from_slice::<serde_json::Value>(&body) {
                if let Some(object)=value.as_object() {if object.len()==1 {if let Some(name)=object.get("name").and_then(|v|v.as_str()).filter(|s|s.chars().count()>0 && s.chars().count()<=100) {return json(serde_json::json!({"name":name}));}}}
            }
            text(400,"invalid name")
        }
    }
}
#[tokio::main(flavor="current_thread")]
async fn main() {
    let args:Vec<String>=std::env::args().collect();let profile:u32=args[1].parse().unwrap();let port:u16=args[2].parse().unwrap();let start=Instant::now();
    let mut router=Router::new();
    if profile==0 {
    for (path,job) in [("/text",Job::Text),("/json",Job::Json),("/users/{id}",Job::Parameter),("/decode",Job::Decode),("/echo",Job::Echo),("/hooks/0",Job::Hooks(0)),("/hooks/1",Job::Hooks(1)),("/hooks/5",Job::Hooks(5))] {
        let mut route=any(move |r|handle(job,r));
        if let Job::Hooks(n)=job {for _ in 0..n {route=route.layer(middleware::from_fn(hook));}}
        router=router.route(path,route);
    }
    }
    for id in 0..profile {router=router.route(&format!("/route/{id}"),any(move |r|handle(Job::Route(id),r)));}
    router=router.fallback(||async {text(404,"not found")});
    let listener=tokio::net::TcpListener::bind(("127.0.0.1",port)).await.unwrap();
    println!("CONSTRUCTION_MS {}\nREADY",start.elapsed().as_secs_f64()*1000.0);
    axum::serve(listener,router).with_graceful_shutdown(async {tokio::signal::ctrl_c().await.unwrap()}).await.unwrap();
    println!("JOINED");
}
