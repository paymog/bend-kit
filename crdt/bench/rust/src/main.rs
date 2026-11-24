// CRDT benchmark: crdts::GCounter (see ../README.md).
use crdts::{CmRDT, CvRDT, GCounter, PNCounter};
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

fn gossip_pn(rounds: u64) {
    let t0 = Instant::now();
    let mut s: Vec<PNCounter<u32>> = (0..R).map(|_| PNCounter::new()).collect();
    for _ in 0..rounds {
        for (r, c) in s.iter_mut().enumerate() {
            for _ in 0..2 {
                let op = c.inc(r as u32);
                c.apply(op);
            }
            let op = c.dec(r as u32);
            c.apply(op);
        }
        let old = s.clone();
        for r in 0..R {
            s[r].merge(old[(r + 1) % R].clone());
        }
    }
    let chk = s.iter().fold(0u32, |acc, c| acc.wrapping_add(c.read().to_u32().unwrap()));
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("gossip-pn\t{ms:.3}\t{chk}");
}

fn read_pn_exact(rounds: u64) {
    let mut s = PNCounter::<u32>::new();
    for actor in 0..2 {
        let count = if actor == 0 { u32::MAX as u64 } else { 1 };
        let op = s.inc_many(actor, count);
        s.apply(op);
        let op = s.dec_many(actor, count);
        s.apply(op);
    }
    let t0 = Instant::now();
    let mut chk = 0u32;
    for _ in 0..rounds {
        chk = chk.wrapping_add(s.read().to_u32().unwrap());
        let op = s.inc(1);
        s.apply(op);
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("read-pn-exact\t{ms:.3}\t{chk}");
}

fn main() {
    let lg: u32 = std::env::args().nth(1).map_or(14, |a| a.parse().unwrap());
    let rounds = 1u64 << lg;
    gossip("gossip", rounds, |r| r as u32);
    gossip("gossip-sparse", rounds, |r| r as u32 * 250_000_000 + 7);
    gossip_pn(rounds);
    read_pn_exact(rounds);
}
