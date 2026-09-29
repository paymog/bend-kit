// Collections benchmark: Rust std (see README.md).
use std::cmp::Reverse;
use std::collections::{BTreeMap, BinaryHeap, HashMap, VecDeque};
use std::hint::black_box;
use std::time::Instant;

fn lcg(x: u32) -> u32 {
    x.wrapping_mul(1664525).wrapping_add(1013904223)
}

fn mix(acc: u32, x: u32) -> u32 {
    acc.wrapping_mul(31).wrapping_add(x)
}

fn lap(name: &str, t0: Instant, chk: u32) {
    println!("{}\t{:.3}\t{}", name, t0.elapsed().as_secs_f64() * 1000.0, chk);
}

fn main() {
    let l: u32 = std::env::args().nth(1).map_or(20, |s| s.parse().unwrap());
    let n = 1usize << l;

    let t0 = Instant::now();
    let mut m = BTreeMap::new();
    let mut x = 1u32;
    for i in 0..n as u32 {
        x = lcg(x);
        m.insert(x, i);
    }
    lap("omap_put", t0, black_box(m.len() as u32));

    let t0 = Instant::now();
    let (mut x, mut acc) = (1u32, 0u32);
    for _ in 0..n {
        x = lcg(x);
        acc = acc.wrapping_add(*m.get(&x).unwrap_or(&0));
    }
    lap("omap_get", t0, acc);

    let t0 = Instant::now();
    let mut m = HashMap::new();
    let mut x = 1u32;
    for i in 0..n as u32 {
        x = lcg(x);
        m.insert(x, i);
    }
    lap("hmap_put", t0, black_box(m.len() as u32));

    let t0 = Instant::now();
    let (mut x, mut acc) = (1u32, 0u32);
    for _ in 0..n {
        x = lcg(x);
        acc = acc.wrapping_add(*m.get(&x).unwrap_or(&0));
    }
    lap("hmap_get", t0, acc);

    let t0 = Instant::now();
    let mut v = Vec::new();
    for i in 0..n as u32 {
        v.push(i);
    }
    lap("vec_push", t0, black_box(v.len() as u32));

    let t0 = Instant::now();
    let (mut x, mut acc) = (1u32, 0u32);
    for _ in 0..n {
        x = lcg(x);
        acc = acc.wrapping_add(v[(x >> (32 - l)) as usize]);
    }
    lap("vec_get", t0, acc);

    let t0 = Instant::now();
    let mut d = VecDeque::new();
    for i in 0..n as u32 {
        d.push_back(i);
    }
    lap("deque_push", t0, black_box(d.len() as u32));

    let t0 = Instant::now();
    let mut acc = 0u32;
    for _ in 0..n / 2 {
        acc = mix(acc, d.pop_front().unwrap());
    }
    for _ in 0..n / 2 {
        acc = mix(acc, d.pop_back().unwrap());
    }
    lap("deque_pop", t0, acc);

    let t0 = Instant::now();
    let mut h = BinaryHeap::new();
    let mut x = 1u32;
    for _ in 0..n {
        x = lcg(x);
        h.push(Reverse(x));
    }
    lap("heap_push", t0, black_box(h.len() as u32));

    let t0 = Instant::now();
    let mut acc = 0u32;
    while let Some(Reverse(y)) = h.pop() {
        acc = mix(acc, y);
    }
    lap("heap_pop", t0, acc);
}
