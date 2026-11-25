use std::hint::black_box;
use std::time::Instant;

fn fill_buf(b: &mut [u8]) -> u32 {
    for (i, byte) in b.iter_mut().enumerate() {
        *byte = ((i as u64 * 31 + 7) & 255) as u8;
    }
    let n = b.len();
    b[n - 4] = 13;
    b[n - 3] = 10;
    b[n - 2] = 13;
    b[n - 1] = 10;
    b[12345 % n] as u32 + b[n - 1] as u32
}

fn build(n: usize) {
    let t0 = Instant::now();
    let mut out = Vec::new();
    for i in 0..n {
        out.push((i & 255) as u8);
    }
    let cs = n as u32 + out[n - 1] as u32;
    println!("build_{n}\t{:.6}\t{cs}", t0.elapsed().as_secs_f64() * 1000.0);
}

fn main() {
    let l: u32 = std::env::args()
        .nth(1)
        .and_then(|s| s.parse().ok())
        .unwrap_or(28);
    let n = 1usize << l;
    let reads: u32 = std::env::args().nth(2).map_or(1 << 24, |s| s.parse().unwrap());
    let b1: usize = std::env::args().nth(3).map_or(1000000, |s| s.parse().unwrap());
    let b2: usize = std::env::args().nth(4).map_or(4000000, |s| s.parse().unwrap());

    let t0 = Instant::now();
    let mut b = vec![0u8; n];
    let cs = fill_buf(&mut b);
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("fill\t{ms:.6}\t{cs}");

    let t0 = Instant::now();
    let mut sum: u32 = 0;
    for &byte in &b {
        sum = sum.wrapping_add(byte as u32);
    }
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("sum\t{ms:.6}\t{sum}");

    let needle = [13u8, 10, 13, 10];
    let t0 = Instant::now();
    let find_idx = b
        .windows(4)
        .position(|w| w == needle)
        .unwrap_or(usize::MAX);
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("find\t{ms:.6}\t{}", find_idx as u32);

    let slice_start = n / 4 + 1;
    let slice_len = n / 2;
    let t0 = Instant::now();
    let s: Vec<u8> = b[slice_start..slice_start + slice_len].to_vec();
    let cs = s[0] as u32 + s[s.len() - 1] as u32;
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("slice\t{ms:.6}\t{cs}");

    let t0 = Instant::now();
    let mut out: Vec<u8> = Vec::new();
    let chunk_size = n.min(65536);
    let chunks = n / chunk_size;
    for k in 0..chunks {
        let byte = (k & 255) as u8;
        out.extend(std::iter::repeat(byte).take(chunk_size));
    }
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    if out.len() != n {
        std::process::exit(1);
    }
    let cs = out[0] as u32 + out[out.len() - 1] as u32;
    println!("concat\t{ms:.6}\t{cs}");

    let mut x: u32 = 1;
    let mut acc: u32 = 0;
    let shift = 32 - l;
    let t0 = Instant::now();
    for _ in 0..reads {
        x = x.wrapping_mul(1664525).wrapping_add(1013904223);
        let idx = (x >> shift) as usize;
        acc = acc.wrapping_add(b[idx] as u32);
    }
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    black_box(acc);
    println!("random\t{ms:.6}\t{acc}");

    let c = b.clone();
    let t0 = Instant::now();
    let eq = b == c;
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("equal\t{ms:.6}\t{}", if eq { 1u32 } else { 0 });

    black_box(b);
    build(b1);
    build(b2);
}
