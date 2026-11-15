// 1000 sequential GETs on one reqwest blocking Client with a default header; the URL joins a base.
// Then 1000 GETs of a flaky URL through reqwest's retry policy, which retries a GET 503.
use reqwest::header::{HeaderMap, HeaderValue};
use std::time::Instant;

fn main() {
    let mut h = HeaderMap::new();
    h.insert("x-bench", HeaderValue::from_static("1"));
    let c = reqwest::blocking::Client::builder().default_headers(h).build().unwrap();
    let base = reqwest::Url::parse("http://127.0.0.1:47840/api/").unwrap();
    let mut sum: u32 = 0;
    let t0 = Instant::now();
    for _ in 0..1000 {
        if let Ok(r) = c.get(base.join("item").unwrap()).send() {
            let status = r.status().as_u16() as u32;
            let len = r.bytes().map(|b| b.len() as u32).unwrap_or(0);
            sum = sum.wrapping_add(status + len);
        }
    }
    println!("get_1000\t{:.3}\t{sum}", t0.elapsed().as_secs_f64() * 1e3);

    // The default budget allows 20% extra load; every request here needs one retry, so the bench lifts it.
    let policy = reqwest::retry::for_host("127.0.0.1")
        .max_retries_per_request(2)
        .no_budget()
        .classify_fn(|rr| match (rr.method(), rr.status()) {
            (&reqwest::Method::GET, Some(reqwest::StatusCode::SERVICE_UNAVAILABLE)) => rr.retryable(),
            _ => rr.success(),
        });
    let c = reqwest::blocking::Client::builder().retry(policy).build().unwrap();
    let url = base.join("flaky").unwrap();
    sum = 0;
    let t0 = Instant::now();
    for _ in 0..1000 {
        if let Ok(r) = c.get(url.clone()).send() {
            let status = r.status().as_u16() as u32;
            let len = r.bytes().map(|b| b.len() as u32).unwrap_or(0);
            sum = sum.wrapping_add(status + len);
        }
    }
    println!("retry_1000\t{:.3}\t{sum}", t0.elapsed().as_secs_f64() * 1e3);
}
