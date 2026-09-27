use rand_xoshiro::rand_core::{Rng, SeedableRng};
use rand_xoshiro::Xoshiro128StarStar;
use std::hint::black_box;
use std::time::Instant;

const N: u32 = 1 << 24;

fn main() {
    // The state {1, 2, 3, 4}, as little-endian words.
    let mut seed = [0u8; 16];
    for (i, w) in [1u32, 2, 3, 4].iter().enumerate() {
        seed[i * 4..i * 4 + 4].copy_from_slice(&w.to_le_bytes());
    }
    let mut r = Xoshiro128StarStar::from_seed(black_box(seed));
    let t0 = Instant::now();
    let mut h: u32 = 0;
    for _ in 0..N {
        h = h.wrapping_mul(31).wrapping_add(r.next_u32());
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("next\t{ms:.3}\t{h}");
}
