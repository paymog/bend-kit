// Tar benchmark in Rust with the tar crate (see ../README.md).
use std::io::Read;
use std::os::unix::ffi::OsStrExt;
use std::path::Path;
use std::time::Instant;
use tar::{Archive, Builder, EntryType, Header};

struct Ent {
    dir: bool,
    name: Vec<u8>,
    data: Vec<u8>,
}

fn decode(buf: &[u8]) -> Vec<Ent> {
    let mut v = Vec::new();
    for e in Archive::new(buf).entries().expect("entries") {
        let mut e = e.expect("entry");
        let dir = match e.header().entry_type() {
            EntryType::Regular => false,
            EntryType::Directory => true,
            t => panic!("unexpected entry type {t:?}"),
        };
        let name = e.path_bytes().into_owned();
        let mut data = Vec::with_capacity(e.size() as usize);
        e.read_to_end(&mut data).expect("data");
        v.push(Ent { dir, name, data });
    }
    v
}

// Builder writes a GNU long-name entry for a path that does not fit the header.
fn encode(es: &[Ent], cap: usize) -> Vec<u8> {
    let mut b = Builder::new(Vec::with_capacity(cap));
    for e in es {
        let mut h = Header::new_gnu();
        h.set_entry_type(if e.dir { EntryType::Directory } else { EntryType::Regular });
        h.set_mode(if e.dir { 0o755 } else { 0o644 });
        h.set_mtime(0);
        h.set_size(e.data.len() as u64);
        b.append_data(&mut h, Path::new(std::ffi::OsStr::from_bytes(&e.name)), &e.data[..]).expect("append");
    }
    b.into_inner().expect("finish")
}

// Checksum (see run.py): per entry fold kind, name bytes + length, file data bytes + length; add the count.
fn fold(p: &[u8], mut h: u32) -> u32 {
    for &b in p {
        h = h.wrapping_mul(31).wrapping_add(b as u32);
    }
    h.wrapping_mul(31).wrapping_add(p.len() as u32)
}

fn checksum(es: &[Ent]) -> u32 {
    let mut h: u32 = 0;
    for e in es {
        if e.dir {
            let n = e.name.strip_suffix(b"/").unwrap_or(&e.name);
            h = fold(n, h.wrapping_mul(31).wrapping_add(2));
        } else {
            h = fold(&e.data, fold(&e.name, h.wrapping_mul(31).wrapping_add(1)));
        }
    }
    h.wrapping_add(es.len() as u32)
}

fn main() {
    let data = std::fs::read("out/input.tar").expect("read out/input.tar");

    let t0 = Instant::now();
    let es = decode(&data);
    let t1 = Instant::now();
    let out = encode(&es, data.len());
    let t2 = Instant::now();

    let ms = |a: Instant, b: Instant| (b - a).as_secs_f64() * 1000.0;
    println!("decode\t{:.3}\t{}", ms(t0, t1), checksum(&es));
    println!("encode\t{:.3}\t{}", ms(t1, t2), checksum(&decode(&out)));
}
