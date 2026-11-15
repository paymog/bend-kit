// CRDT benchmark: crdts::GCounter (see ../README.md).
use crdts::{CmRDT, CvRDT, GCounter};
use num_traits::ToPrimitive;
use std::time::Instant;

const R: usize = 16;

// Replica r uses actor id(r): r itself for the dense case, a spread value for the sparse one.
fn gossip(name: &str, rounds: u64, id: impl Fn(usize) -> u32) {
    let t0 = Instant::now();
    let mut s: Vec<GCounter<u32>> = (0..R).map(|_| GCounter::new()).collect();
    for _ in 0..rounds {
        for (r, c) in s.iter_mut().enumerate() {
            let op = c.inc(id(r));
            c.apply(op);
        }
        let old = s.clone();
        for r in 0..R {
            s[r].merge(old[(r + 1) % R].clone());
        }
    }
    let chk = s.iter().fold(0u32, |acc, c| acc.wrapping_add(c.read().to_u32().unwrap()));
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("{name}\t{ms:.3}\t{chk}");
}

fn main() {
    let lg: u32 = std::env::args().nth(1).map_or(14, |a| a.parse().unwrap());
    let rounds = 1u64 << lg;
    gossip("gossip", rounds, |r| r as u32);
    gossip("gossip-sparse", rounds, |r| r as u32 * 250_000_000 + 7);
}
