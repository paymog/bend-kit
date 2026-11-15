// Gateway benchmark: the Rust side (see README.md).
use std::collections::HashMap;
use std::hint::black_box;
use std::time::Instant;

const CAPACITY: u32 = 4;
const TTL: u64 = 1_000_000;

fn allowed(method: &str, roles: &[String]) -> bool {
    !roles.iter().any(|r| r == "suspended") && method == "GET" && roles.iter().any(|r| r == "reader")
}

fn main() {
    let lg: u32 = std::env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(10);
    let rounds = 1u64 << lg;
    let keys: Vec<String> = (0..64).map(|i| format!("k{i}")).collect();
    let roles = vec!["reader".to_string()];
    let t0 = Instant::now();
    let mut cache: HashMap<String, (String, u64)> = HashMap::new();
    let mut in_use = 0u32;
    for k in &keys {
        if allowed("GET", &roles) && in_use < CAPACITY {
            in_use += 1;
            cache.insert(k.clone(), (k.clone(), TTL));
            in_use -= 1;
        }
    }
    let mut acc = 0u32;
    for _ in 0..rounds {
        for k in &keys {
            for _ in 0..8 {
                if !allowed(black_box("GET"), black_box(&roles)) || in_use >= CAPACITY {
                    continue;
                }
                in_use += 1;
                if let Some((v, exp)) = cache.get(black_box(k.as_str())) {
                    if 0 < *exp {
                        acc = acc.wrapping_add(v.len() as u32);
                    }
                }
                in_use -= 1;
            }
        }
    }
    let ms = t0.elapsed().as_secs_f64() * 1000.0;
    println!("gateway\t{ms:.3}\t{acc}");
}
