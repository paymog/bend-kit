// Postgres result decode benchmark in Rust with postgres-protocol, the codec under tokio-postgres (see README.md).
use bytes::BytesMut;
use fallible_iterator::FallibleIterator;
use postgres_protocol::message::backend::{DataRowBody, Message};
use std::ops::Range;
use std::time::Instant;

fn m(h: u32, x: u32) -> u32 {
    h.wrapping_mul(31).wrapping_add(x)
}

fn s(mut h: u32, b: &[u8]) -> u32 {
    h = m(h, b.len() as u32);
    for &x in b {
        h = m(h, x as u32);
    }
    h
}

fn main() {
    let data = std::fs::read("out/result.pgwire").unwrap();
    let t0 = Instant::now();
    // What tokio-postgres keeps: each column's name and type, each row's body and value ranges, the tag.
    let mut cols: Vec<(String, u32)> = Vec::new();
    let mut rows: Vec<(DataRowBody, Vec<Option<Range<usize>>>)> = Vec::new();
    let mut tag = String::new();
    let mut buf = BytesMut::new();
    // 64 KiB at a time, as a socket delivers it.
    for piece in data.chunks(65536) {
        buf.extend_from_slice(piece);
        while let Some(msg) = Message::parse(&mut buf).unwrap() {
            match msg {
                Message::RowDescription(b) => {
                    cols = b.fields().map(|f| Ok((f.name().to_string(), f.type_oid()))).collect().unwrap();
                }
                Message::DataRow(b) => {
                    let ranges = b.ranges().collect().unwrap();
                    rows.push((b, ranges));
                }
                Message::CommandComplete(b) => tag = b.tag().unwrap().to_string(),
                Message::ReadyForQuery(_) => {}
                _ => panic!("unexpected message"),
            }
        }
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;

    // The checksum in run.py.
    let mut h = m(0, 1);
    for (name, oid) in &cols {
        h = m(s(h, name.as_bytes()), *oid);
    }
    h = m(h, 2);
    for (body, ranges) in &rows {
        h = m(h, 3);
        for r in ranges {
            h = match r {
                None => m(h, 4),
                Some(r) => s(m(h, 5), &body.buffer()[r.clone()]),
            };
        }
        h = m(h, 6);
    }
    h = s(m(h, 7), tag.as_bytes());
    println!("decode\t{ms:.3}\t{h}");
}
