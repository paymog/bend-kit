// Bits benchmark in Rust with bitstream-io: the fixed literal/length tree from run.py, then 13-bit fields.
use bitstream_io::{BitRead, BitReader, LittleEndian};
use std::io::Cursor;
use std::time::Instant;

include!("out/tree.rs");

fn lits(data: &[u8]) -> u32 {
    let mut r = BitReader::endian(Cursor::new(data), LittleEndian);
    r.read::<3, u8>().unwrap();
    let mut h: u32 = 0;
    loop {
        let s = r.read_huffman::<FixedLit>().unwrap();
        if s == 256 {
            return h;
        }
        h = h.wrapping_mul(31).wrapping_add(s as u32);
    }
}

fn fields(data: &[u8]) -> u32 {
    let mut r = BitReader::endian(Cursor::new(data), LittleEndian);
    let mut h: u32 = 0;
    while let Ok(v) = r.read::<13, u32>() {
        h = h.wrapping_mul(31).wrapping_add(v);
    }
    h
}

fn main() {
    let data = std::fs::read("out/payload.bin").unwrap();
    let t = Instant::now();
    let h = lits(&data);
    println!("huffman\t{:.3}\t{}", t.elapsed().as_secs_f64() * 1e3, h);
    let t = Instant::now();
    let h = fields(&data);
    println!("fields\t{:.3}\t{}", t.elapsed().as_secs_f64() * 1e3, h);
}
