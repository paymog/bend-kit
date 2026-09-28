use std::time::Instant;

fn checksum(b: &[u8]) -> u32 {
    let h = b.iter().fold(0u32, |h, &c| h.wrapping_mul(31).wrapping_add(c as u32));
    h.wrapping_add(b.len() as u32)
}

fn main() {
    let data = std::fs::read("out/doc.csv").unwrap();

    let t0 = Instant::now();
    let rows: Vec<csv::ByteRecord> = csv::ReaderBuilder::new()
        .has_headers(false)
        .flexible(true)
        .from_reader(&data[..])
        .byte_records()
        .map(|r| r.unwrap())
        .collect();
    let t1 = Instant::now();
    let mut w = csv::WriterBuilder::new()
        .terminator(csv::Terminator::CRLF)
        .flexible(true)
        .from_writer(Vec::new());
    for r in &rows {
        w.write_byte_record(r).unwrap();
    }
    let out = w.into_inner().unwrap();
    let t2 = Instant::now();

    let sum = checksum(&out);
    println!("parse\t{:.3}\t{}", (t1 - t0).as_secs_f64() * 1000.0, sum);
    println!("encode\t{:.3}\t{}", (t2 - t1).as_secs_f64() * 1000.0, sum);
}
