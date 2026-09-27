// Crypto benchmark in Rust: SHA-256 of 16 MiB of zero bytes with the sha2 crate.
use sha2::{Digest, Sha256};
use std::time::Instant;

fn main() {
    let data = vec![0u8; 16_777_216];
    let t0 = Instant::now();
    let h = Sha256::digest(&data);
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    let hex: String = h.iter().map(|b| format!("{b:02x}")).collect();
    println!("sha256\t{ms:.3}\t{hex}");
}
