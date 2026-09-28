// CBOR benchmark in Rust with ciborium's dynamic Value (see ../README.md).
use ciborium::Value;
use std::time::Instant;

fn main() {
    let data = std::fs::read("out/doc.cbor").expect("read out/doc.cbor");

    let t0 = Instant::now();
    let value: Value = ciborium::de::from_reader(&data[..]).expect("decode");
    let t1 = Instant::now();
    let mut out = Vec::with_capacity(data.len());
    ciborium::ser::into_writer(&value, &mut out).expect("encode");
    let t2 = Instant::now();

    // Checksum: h = h*31 + b, u32, then add the length.
    let mut h: u32 = 0;
    for &b in &out {
        h = h.wrapping_mul(31).wrapping_add(b as u32);
    }
    h = h.wrapping_add(out.len() as u32);
    let ms = |a: Instant, b: Instant| (b - a).as_secs_f64() * 1000.0;
    println!("decode\t{:.3}\t{}", ms(t0, t1), h);
    println!("encode\t{:.3}\t{}", ms(t1, t2), h);
}
