use std::{env, fs::File, io::{self, Read, Write}};

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let cap: usize = args[3].parse().unwrap();
    let chunk: usize = args[4].parse().unwrap();
    assert!((1..=1048576).contains(&chunk));
    let mut src = File::open(&args[1])?;
    let mut dst = File::create(&args[2])?;
    let mut buf = vec![0; chunk];
    let mut count = 0;
    while count < cap {
        let n = src.read(&mut buf[..chunk.min(cap - count)])?;
        if n == 0 { break; }
        dst.write_all(&buf[..n])?;
        count += n;
    }
    assert_eq!(src.read(&mut buf[..1])?, 0, "cap exceeded");
    dst.flush()?;
    drop(dst);
    let mut output = File::open(&args[2])?;
    let mut hash = 2166136261u32;
    loop {
        let n = output.read(&mut buf)?;
        if n == 0 { break; }
        for &byte in &buf[..n] { hash = (hash ^ u32::from(byte)).wrapping_mul(16777619); }
    }
    println!("{count} {hash}");
    Ok(())
}
