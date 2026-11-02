// Storage benchmark: sha2 SHA-256 and a HashMap (see README.md).
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::fmt::Write;
use std::time::Instant;

enum Obj {
    File(usize),
    End,
    Item(String, String),
}

fn put(store: &mut HashMap<String, Obj>, raw: &[u8], obj: Obj) -> String {
    let mut d = String::with_capacity(64);
    for b in Sha256::digest(raw) {
        write!(d, "{b:02x}").unwrap();
    }
    store.entry(d.clone()).or_insert(obj);
    d
}

fn listing(store: &mut HashMap<String, Obj>, entries: &[(String, String)]) -> String {
    let mut rest = put(store, b"end\n", Obj::End);
    for (name, child) in entries.iter().rev() {
        let line = format!("item {child} {rest} {name}\n");
        rest = put(store, line.as_bytes(), Obj::Item(child.clone(), rest.clone()));
    }
    rest
}

fn load(store: &HashMap<String, Obj>, d: &str) -> usize {
    match &store[d] {
        Obj::File(n) => *n,
        Obj::End => 0,
        Obj::Item(c, r) => load(store, c) + load(store, r),
    }
}

fn main() {
    let k: usize = std::env::args().nth(1).and_then(|s| s.parse().ok()).unwrap_or(16);
    let tree: Vec<(String, Vec<(String, Vec<u8>)>)> = (0..k)
        .map(|d| {
            let fs = (0..k)
                .map(|f| (format!("f{f:02}"), (0..4096).map(|j| ((d * 31 + f * 7 + j) & 255) as u8).collect()))
                .collect();
            (format!("d{d:02}"), fs)
        })
        .collect();
    let t0 = Instant::now();
    let mut store = HashMap::new();
    let mut top = Vec::new();
    for (dname, fs) in &tree {
        let mut files = Vec::new();
        for (fname, data) in fs {
            let mut raw = format!("file {}\n", data.len()).into_bytes();
            raw.extend_from_slice(data);
            files.push((fname.clone(), put(&mut store, &raw, Obj::File(data.len()))));
        }
        top.push((dname.clone(), listing(&mut store, &files)));
    }
    let root = listing(&mut store, &top);
    let n = load(&store, &root);
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("commit\t{ms:.3}\t{root}\t{n}");
}
