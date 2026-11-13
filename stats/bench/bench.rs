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

fn time(op: &str, f: impl Fn() -> f64) {
    let t0 = Instant::now();
    let r = f();
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("{op}\t{ms:.3}\t{}", mix(r));
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
}
