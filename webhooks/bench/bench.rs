// Webhook verify benchmark in Rust with standardwebhooks: one fixed message, 10,000 verifies (see README.md).
use http::HeaderMap;
use standardwebhooks::Webhook;
use std::time::Instant;

const N: u32 = 10_000;

fn main() {
    let body = br#"{"test": 2432232314}"#;
    // run.py signs the message at its start and passes the timestamp and signature in the environment.
    let env = |k: &str| -> http::HeaderValue { std::env::var(k).unwrap().parse().unwrap() };
    let mut headers = HeaderMap::new();
    headers.insert("webhook-id", "msg_p5jXN8AQM9LWM0D4loKWxJek".parse().unwrap());
    headers.insert("webhook-timestamp", env("WEBHOOK_TS"));
    headers.insert("webhook-signature", env("WEBHOOK_SIG"));
    let wh = Webhook::new("whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw").unwrap();
    let mut n = 0u32;
    let t0 = Instant::now();
    for _ in 0..N {
        wh.verify(std::hint::black_box(body), &headers).unwrap();
        n += 1;
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("verify\t{ms:.3}\t{n} {}", headers["webhook-id"].to_str().unwrap());
}
