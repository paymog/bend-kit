// Hash benchmark in Rust (see README.md). std has only SipHash-1-3: DefaultHasher::new() uses a zero key.
use std::hash::{DefaultHasher, Hasher};
use std::time::Instant;

fn main() {
    const N: usize = 16777213;
    let buf: Vec<u8> = (0..N).map(|i| (i % 251) as u8).collect();
    let t0 = Instant::now();
    let mut h = DefaultHasher::new();
    h.write(&buf);
    let v = h.finish();
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("siphash13\t{:.3}\t{:016x}", ms, v);
}
