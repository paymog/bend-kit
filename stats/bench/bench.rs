use std::time::Instant;

fn xs(mut x: u32) -> u32 {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    x
}

fn mix(x: f64) -> u32 {
    let b = x.to_bits();
    (b >> 32) as u32 ^ b as u32
}

fn mean(v: &[f64]) -> f64 {
    v.iter().sum::<f64>() / v.len() as f64
}

fn variance(v: &[f64]) -> f64 {
    let m = mean(v);
    v.iter().map(|x| (x - m) * (x - m)).sum::<f64>() / (v.len() - 1) as f64
}

fn median(v: &[f64]) -> f64 {
    let mut s = v.to_vec();
    s.sort_by(f64::total_cmp);
    let i = (s.len() - 1) / 2;
    if (s.len() - 1) % 2 == 1 {
        s[i] + 0.5 * (s[i + 1] - s[i])
    } else {
        s[i]
    }
}

fn histogram(v: &[f64]) -> f64 {
    let edges: Vec<f64> = (0..=100).map(|i| (i * 10486) as f64).collect();
    let mut counts = [0u32; 100];
    for &x in v {
        if edges[0] <= x && x <= edges[100] {
            let i = edges.partition_point(|&edge| edge <= x).saturating_sub(1).min(99);
            counts[i] += 1;
        }
    }
    counts.iter().enumerate().map(|(i, &n)| (i + 1) as f64 * n as f64).sum()
}

fn time(op: &str, f: impl Fn() -> f64) {
    let t0 = Instant::now();
    let r = f();
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("{op}\t{ms:.3}\t{}", mix(r));
}

fn gcd(mut a: u32, mut b: u32) -> u32 {
    while b != 0 {
        (a, b) = (b, a % b);
    }
    a
}

fn lcm(a: u32, b: u32) -> u32 {
    if a == 0 || b == 0 {
        return 0;
    }
    (a / gcd(a, b)).checked_mul(b).unwrap_or(0x9E3779B9)
}

fn integers() {
    let mut pairs = vec![(0, 0), (0, u32::MAX), (u32::MAX, 0),
        (u32::MAX, u32::MAX), (u32::MAX, 1), (65535, 65536),
        (65536, 65537), (12, 18)];
    let (mut a, mut b) = (0u32, 1u32);
    for _ in 0..47 {
        pairs.push((a, b));
        (a, b) = (b, a.wrapping_add(b));
    }
    let n = std::env::args().nth(1).map(|s| s.parse().unwrap()).unwrap_or(2097152);
    let mut x = 44;
    for _ in 0..n {
        a = xs(x);
        x = xs(a);
        pairs.push((a, x));
    }
    for (op, f) in [("gcd", gcd as fn(u32, u32) -> u32),
                    ("lcm", lcm), ("isqrt", |a: u32, _| a.isqrt())] {
        let t0 = Instant::now();
        let mut checksum = 0u32;
        for &(a, b) in &pairs {
            checksum = checksum.wrapping_add(f(a, b));
        }
        println!("{op}\t{:.3}\t{checksum}", t0.elapsed().as_secs_f64() * 1e3);
    }
    let mut packed = Vec::with_capacity(pairs.len() * 2);
    for &(a, b) in &pairs {
        packed.extend_from_slice(&[a, b]);
    }
    let t0 = Instant::now();
    let mut checksum = 0u32;
    for pair in packed.chunks_exact(2) {
        checksum = checksum.wrapping_add(pair[0]);
    }
    println!("packed_identity\t{:.3}\t{checksum}", t0.elapsed().as_secs_f64() * 1e3);
    for (op, f) in [("packed_gcd", gcd as fn(u32, u32) -> u32),
                    ("packed_lcm", lcm), ("packed_isqrt", |a: u32, _| a.isqrt())] {
        let t0 = Instant::now();
        let mut checksum = 0u32;
        for pair in packed.chunks_exact(2) {
            checksum = checksum.wrapping_add(f(pair[0], pair[1]));
        }
        println!("{op}\t{:.3}\t{checksum}", t0.elapsed().as_secs_f64() * 1e3);
    }
    drop(packed);
}

fn main() {
    let mut x = 44u32;
    let v: Vec<f64> = (0..10000)
        .map(|_| {
            x = xs(x);
            (x >> 12) as f64
        })
        .collect();
    time("mean", || mean(&v));
    time("variance", || variance(&v));
    time("median", || median(&v));
    time("histogram", || histogram(&v));
    integers();
}
