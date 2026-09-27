// Integer benchmark: the Rust side (see README.md). Argument: N.
use std::hint::black_box;
use std::time::Instant;

fn main() {
    let n: usize = std::env::args().nth(1).map_or(16384, |s| s.parse().unwrap());
    let a: u64 = black_box(6364136223846793005);
    let c: u64 = black_box(1442695040888963407);
    let m: u64 = black_box(1000003);

    let t0 = Instant::now();
    let mut x: u64 = 1;
    for _ in 0..n {
        x = x.wrapping_mul(a).wrapping_add(c);
    }
    println!("lcg\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, x);

    let mut s: u32 = 1;
    let xs: Vec<u64> = (0..n)
        .map(|_| {
            let hi = s.wrapping_mul(1664525).wrapping_add(1013904223);
            let lo = hi.wrapping_mul(1664525).wrapping_add(1013904223);
            s = lo;
            (hi as u64) << 32 | lo as u64
        })
        .collect();
    let t0 = Instant::now();
    let acc = xs.iter().fold(0u64, |acc, &x| acc.wrapping_add(x % m));
    println!("rem\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, acc);

    let n2: usize = std::env::args().nth(2).map_or(10000000, |s| s.parse().unwrap());
    let d: i32 = black_box(1000);
    let t0 = Instant::now();
    let (mut x, mut acc) = (1i32, 0i32);
    for _ in 0..n2 {
        x = x.wrapping_mul(1664525).wrapping_add(1013904223);
        acc = acc.wrapping_add(x / d);
    }
    println!("i32\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, acc);
    let t0 = Instant::now();
    let mut x: u16 = 1;
    for _ in 0..n2 {
        x = x.wrapping_mul(25173).wrapping_add(13849);
    }
    println!("u16\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, x);
    let t0 = Instant::now();
    let mut x: u8 = 1;
    for _ in 0..n2 {
        x = x.wrapping_mul(77).wrapping_add(13);
    }
    println!("u8\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, x);
}
