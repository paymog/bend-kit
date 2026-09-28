// SSE parse benchmark in Rust with eventsource-stream (see README.md).
use eventsource_stream::Eventsource;
use futures::{executor::block_on, stream, StreamExt};
use std::time::Instant;

fn main() {
    let data = std::fs::read("out/stream.sse").unwrap();
    let t0 = Instant::now();
    let pieces = data.chunks(65536).map(|c| Ok::<_, std::io::Error>(bytes::Bytes::copy_from_slice(c)));
    let events: Vec<_> = block_on(stream::iter(pieces).eventsource().collect());
    let ms = t0.elapsed().as_secs_f64() * 1000.0;

    let m = |h: u32, x: u32| h.wrapping_mul(31).wrapping_add(x);
    let mut h = 0u32;
    for e in &events {
        let e = e.as_ref().unwrap();
        h = m(h, 1);
        for b in e.event.bytes() {
            h = m(h, b as u32);
        }
        h = m(h, 2);
        for b in e.data.bytes() {
            h = m(h, b as u32);
        }
    }
    h = h.wrapping_add(events.len() as u32);
    println!("parse\t{ms:.3}\t{h}");
}
