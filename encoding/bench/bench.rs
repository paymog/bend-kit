// Rust has no standard hex codec, so hex uses the hex crate.
use std::time::Instant;

const REPS: usize = 1 << 18;

fn chk(xs: impl Iterator<Item = u32>) -> u32 {
    let (mut h, mut n) = (0u32, 0u32);
    for x in xs {
        h = h.wrapping_mul(31).wrapping_add(x);
        n = n.wrapping_add(1);
    }
    h.wrapping_add(n)
}

fn main() {
    let text: Vec<char> = "Hello \u{e9} \u{3a9} \u{20ac} \u{4e2d} \u{1f600}\n".repeat(REPS).chars().collect();

    let t0 = Instant::now();
    let octets: String = text.iter().collect();
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("utf8_encode\t{:.3}\t{}", ms, chk(octets.bytes().map(u32::from)));

    let bytes = octets.into_bytes();
    let t0 = Instant::now();
    let back: Vec<char> = String::from_utf8_lossy(&bytes).chars().collect();
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("utf8_decode\t{:.3}\t{}", ms, chk(back.iter().map(|&c| c as u32)));

    let t0 = Instant::now();
    let hex = hex::encode(&bytes);
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("hex_encode\t{:.3}\t{}", ms, chk(hex.bytes().map(u32::from)));

    let t0 = Instant::now();
    let bin = hex::decode(&hex).unwrap();
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("hex_decode\t{:.3}\t{}", ms, chk(bin.iter().map(|&b| u32::from(b))));
}
