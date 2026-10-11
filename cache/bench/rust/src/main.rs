// Cache benchmark: moka::sync::Cache with a time to live (see README.md).
use moka::sync::Cache;
use std::time::{Duration, Instant};

fn main() {
    let lg: u32 = std::env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(12);
    let rounds = 1u32 << lg;
    let keys: Vec<String> = (0..64).map(|i| format!("k{i}")).collect();
    let cache: Cache<String, (u32, u32)> = Cache::builder()
        .max_capacity(64)
        .time_to_live(Duration::from_secs(1_000_000))
        .build();
    let mut chk: u32 = 0;
    let t0 = Instant::now();
    for i in 0..rounds {
        let v = i + 1;
        for k in &keys {
            cache.insert(k.clone(), (v, v));
        }
        for k in &keys {
            for _ in 0..8 {
                if let Some((_, x)) = cache.get(k) {
                    chk = chk.wrapping_add(x);
                }
            }
        }
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("cache\t{ms:.3}\t{chk}");
}
