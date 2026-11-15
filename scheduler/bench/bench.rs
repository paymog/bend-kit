use std::{cmp::Reverse, collections::BinaryHeap, time::Instant};
fn main() {
    let start = Instant::now();
    let mut queue = BinaryHeap::new();
    for i in 0..1024u32 {
        queue.push(Reverse(((i * 37) % 64, i)));
    }
    let mut checksum = 0u32;
    while let Some(Reverse((_, id))) = queue.pop() {
        checksum = checksum.wrapping_mul(31).wrapping_add(id);
    }
    println!("{:.6}\t{}", start.elapsed().as_secs_f64() * 1000.0, checksum);
}
