// 1000 sequential GETs on one reqwest blocking Client with a default header; the URL joins a base.
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
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("get_1000\t{ms:.3}\t{sum}");
}
