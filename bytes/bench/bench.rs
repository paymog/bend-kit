use std::hint::black_box;
use std::time::Instant;

fn measure(name: &str, mut operation: impl FnMut() -> u32) {
    let count: u32 = std::env::var("BYTES_BENCH_COUNT").map_or(1, |s| s.parse().unwrap());
    let warmup: u32 = std::env::var("BYTES_BENCH_WARMUP").map_or(0, |s| s.parse().unwrap());
    for _ in 0..warmup { black_box(operation()); }
    let (mut last, mut total) = (0u32, 0u32);
    let t0 = Instant::now();
    for _ in 0..count {
        last = black_box(operation());
        total = total.wrapping_add(last);
    }
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("{name}\t{ms:.6}\t{last}\t{count}\t{total}");
}

fn fill(n: usize) -> Vec<u8> {
    let mut b = vec![0u8; n];
    for (i, byte) in b.iter_mut().enumerate() { *byte = ((i as u64 * 31 + 7) & 255) as u8; }
    b[n - 4..].copy_from_slice(&[13, 10, 13, 10]);
    b
}

fn main() {
    let l: u32 = std::env::args().nth(1).map_or(28, |s| s.parse().unwrap());
    let n = 1usize << l;
    let reads: u32 = std::env::args().nth(2).map_or(1 << 24, |s| s.parse().unwrap());
    let b1: usize = std::env::args().nth(3).map_or(1000000, |s| s.parse().unwrap());
    let b2: usize = std::env::args().nth(4).map_or(4000000, |s| s.parse().unwrap());
    measure("fill", || {
        let b = black_box(fill(black_box(n)));
        b[12345 % n] as u32 + b[n - 1] as u32
    });
    let b = fill(n);
    measure("sum", || {
        let mut sum = 0u32;
        for &byte in black_box(&b) { sum = sum.wrapping_add(byte as u32); }
        sum
    });
    measure("find", || black_box(&b).windows(4).position(|w| w == [13, 10, 13, 10]).unwrap_or(usize::MAX) as u32);
    measure("slice", || {
        let out = black_box(black_box(&b)[n / 4 + 1..n / 4 + 1 + n / 2].to_vec());
        out[0] as u32 + out[out.len() - 1] as u32
    });
    measure("concat", || {
        let mut out = Vec::new();
        let chunk_size = n.min(65536);
        for k in 0..n / chunk_size { out.extend(std::iter::repeat((k & 255) as u8).take(chunk_size)); }
        let out = black_box(out);
        assert_eq!(out.len(), n);
        out[0] as u32 + out[out.len() - 1] as u32
    });
    measure("random", || {
        let b = black_box(&b);
        let (mut x, mut acc) = (1u32, 0u32);
        for _ in 0..reads {
            x = x.wrapping_mul(1664525).wrapping_add(1013904223);
            acc = acc.wrapping_add(b[(x >> (32 - l)) as usize] as u32);
        }
        acc
    });
    let c = b.clone();
    measure("equal", || (black_box(&b) == black_box(&c)) as u32);
    for size in [b1, b2] {
        measure(&format!("build_{size}"), || {
            let mut out = Vec::new();
            for i in 0..size { out.push((i & 255) as u8); }
            let out = black_box(out);
            size as u32 + out[size - 1] as u32
        });
    }
}
