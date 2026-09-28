// Log line benchmark: the Rust side (see README.md). Argument: N.
use serde_json::json;
use std::time::Instant;

fn main() {
    let n: usize = std::env::args().nth(1).map_or(20000, |a| a.parse().unwrap());
    let mut s: u32 = 1;
    let xs: Vec<u32> = (0..n)
        .map(|_| {
            s = s.wrapping_mul(1664525).wrapping_add(1013904223);
            s
        })
        .collect();

    let t0 = Instant::now();
    let mut h: u32 = 2166136261;
    for &x in &xs {
        let rec = json!({"time": "2026-09-27T12:00:00Z", "level": "INFO", "msg": "request done",
            "svc": "api", "user": format!("u\"{}", x % 1000), "id": x, "ok": x & 1 == 1});
        let mut line = serde_json::to_string(&rec).unwrap();
        line.push('\n');
        for c in line.bytes() {
            h = (h ^ c as u32).wrapping_mul(16777619);
        }
    }
    println!("json\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1000.0, h);
}
