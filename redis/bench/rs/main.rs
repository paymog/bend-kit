// RESP decode benchmark in Rust with the redis crate's Parser (see README.md).
use redis::{Parser, Value};
use std::time::Instant;

fn m(h: u32, x: u32) -> u32 {
    h.wrapping_mul(31).wrapping_add(x)
}

fn bytes(mut h: u32, b: &[u8]) -> u32 {
    h = m(m(h, 1), b.len() as u32);
    for &x in b {
        h = m(h, x as u32);
    }
    h
}

// The pre-order checksum in run.py.
fn walk(v: &Value, mut h: u32) -> u32 {
    match v {
        Value::Okay => bytes(h, b"OK"),
        Value::SimpleString(s) => bytes(h, s.as_bytes()),
        Value::BulkString(b) => bytes(h, b),
        Value::Int(i) => m(m(h, 2), *i as u32),
        Value::Nil => m(h, 3),
        Value::Boolean(b) => m(m(h, 8), *b as u32),
        Value::Array(xs) => {
            h = m(h, 4);
            for x in xs {
                h = walk(x, h);
            }
            m(h, 5)
        }
        Value::Map(kvs) => {
            h = m(h, 6);
            for (k, x) in kvs {
                h = walk(x, walk(k, h));
            }
            m(h, 7)
        }
        other => panic!("unexpected {other:?}"),
    }
}

fn main() {
    let data = std::fs::read("out/replies.resp").unwrap();
    let t0 = Instant::now();
    let mut parser = Parser::new();
    let mut input: &[u8] = &data;
    let mut replies = Vec::new();
    while let Ok(v) = parser.parse_value(&mut input) {
        replies.push(v);
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    let mut h = 0u32;
    for v in &replies {
        h = walk(v, h);
    }
    h = h.wrapping_add(replies.len() as u32);
    println!("decode\t{ms:.3}\t{h}");
}
