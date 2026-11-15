// Journal recovery benchmark: crc32fast and a straight scan (see ../README.md).
use std::time::Instant;

fn main() {
    let lg: u32 = std::env::args().nth(1).map_or(20, |a| a.parse().unwrap());
    let n = 1u32 << lg;
    let mut buf = Vec::with_capacity(n as usize * 75);
    for i in 0..n {
        let plen = 16 + ((i * 7) % 48);
        let start = buf.len();
        buf.extend_from_slice(&[0u8; 12]);
        for j in 0..plen {
            buf.push(((i * 31 + j) & 255) as u8);
        }
        let sum = crc32fast::hash(&buf[start + 12..]);
        buf[start..start + 4].copy_from_slice(&plen.to_le_bytes());
        buf[start + 4..start + 8].copy_from_slice(&(!plen).to_le_bytes());
        buf[start + 8..start + 12].copy_from_slice(&sum.to_le_bytes());
    }

    let t0 = Instant::now();
    let mut acc = 0u32;
    let mut count = 0u32;
    let mut off = 0usize;
    while off + 12 <= buf.len() {
        let plen = u32::from_le_bytes(buf[off..off + 4].try_into().unwrap());
        let nlen = u32::from_le_bytes(buf[off + 4..off + 8].try_into().unwrap());
        let want = u32::from_le_bytes(buf[off + 8..off + 12].try_into().unwrap());
        let end = off + 12 + plen as usize;
        if nlen != !plen || plen > 64 || end > buf.len() {
            eprintln!("bad frame");
            std::process::exit(1);
        }
        let payload = &buf[off + 12..end];
        if crc32fast::hash(payload) != want {
            eprintln!("bad frame");
            std::process::exit(1);
        }
        acc = acc.wrapping_mul(31).wrapping_add(plen).wrapping_add(payload[0] as u32);
        count += 1;
        off = end;
    }
    if off != buf.len() || count != n {
        eprintln!("bad frame");
        std::process::exit(1);
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("recover\t{ms:.3}\t{acc}\t{count}");
}
