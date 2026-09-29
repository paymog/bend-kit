// JSON benchmark in Rust with serde_json (see README.md).
use std::time::Instant;

// Checksum: h = h*31 + b, u32, then add the length.
fn chk(b: &[u8]) -> u32 {
    let h = b.iter().fold(0u32, |h, &c| h.wrapping_mul(31).wrapping_add(c as u32));
    h.wrapping_add(b.len() as u32)
}

fn main() {
    let raw = std::fs::read("out/doc.json").expect("read out/doc.json");

    let t0 = Instant::now();
    let v: serde_json::Value = serde_json::from_slice(&raw).expect("parse");
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("parse.bytes\t{ms:.3}\t{}", chk(&serde_json::to_vec(&v).unwrap()));

    let t0 = Instant::now();
    let out = serde_json::to_vec(&v).unwrap();
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("encode.bytes\t{ms:.3}\t{}", chk(&out));
}
