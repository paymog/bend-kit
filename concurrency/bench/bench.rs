// Concurrency benchmark: one CPU-bound job over 64 inputs, on 1 and 8 scoped threads (see README.md).
use std::time::Instant;

const N: usize = 64;
const ROUNDS: u32 = 1 << 20;

fn job(mut x: u32) -> u32 {
    for _ in 0..ROUNDS {
        x = (x ^ (x >> 13)).wrapping_mul(1664525).wrapping_add(1013904223);
    }
    x
}

fn op(name: &str, workers: usize, input: &[u32]) {
    let t0 = Instant::now();
    let mut out = vec![0u32; N];
    std::thread::scope(|s| {
        for (ins, outs) in input.chunks(N / workers).zip(out.chunks_mut(N / workers)) {
            s.spawn(move || {
                for (x, y) in ins.iter().zip(outs.iter_mut()) {
                    *y = job(*x);
                }
            });
        }
    });
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    let h = out.iter().fold(0u32, |h, &x| h.wrapping_mul(31).wrapping_add(x));
    println!("{name}\t{ms:.1}\t{h}");
}

fn main() {
    let input: Vec<u32> = (0..N as u32).collect();
    op("map_1", 1, &input);
    op("map_8", 8, &input);
}
