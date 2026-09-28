// Crypto benchmark in Rust: SHA-256 of 16 MiB of zero bytes, and PBKDF2-HMAC-SHA-256, with the sha2 and pbkdf2 crates.
use sha2::{Digest, Sha256};
use std::time::Instant;

fn hex(b: &[u8]) -> String {
    b.iter().map(|b| format!("{b:02x}")).collect()
}

fn main() {
    let data = vec![0u8; 16_777_216];
    let t0 = Instant::now();
    let h = Sha256::digest(&data);
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("sha256\t{ms:.3}\t{}", hex(&h));
    let mut k = [0u8; 32];
    let t0 = Instant::now();
    pbkdf2::pbkdf2_hmac::<Sha256>(b"password", b"salt", 100_000, &mut k);
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("pbkdf2\t{ms:.3}\t{}", hex(&k));
}
