use std::fs::File;
use std::io::{Read, Result};

fn main() -> Result<()> {
    let mut file = File::open("bench/fixture.bin")?;
    let mut bytes = [0u8; 16384];
    let mut hash = 2166136261u32;
    loop {
        let n = file.read(&mut bytes)?;
        if n == 0 { break; }
        for &byte in &bytes[..n] {
            hash = (hash ^ u32::from(byte)).wrapping_mul(16777619);
        }
    }
    println!("{hash}");
    Ok(())
}
