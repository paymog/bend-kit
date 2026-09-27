// Time benchmark: Rust with chrono (see README.md). Rust's std has no calendar.
use chrono::{DateTime, SecondsFormat};
use std::time::Instant;

const N: usize = 4096;
const T0: i64 = -2208988800;
const STEP: i64 = 3155761;

fn main() {
    let start = Instant::now();
    let mut chk: u32 = 0;
    let mut t = T0;
    for _ in 0..N {
        let s = DateTime::from_timestamp(t, 0).unwrap().to_rfc3339_opts(SecondsFormat::Secs, true);
        let back = DateTime::parse_from_rfc3339(&s).unwrap().timestamp();
        let sum: u32 = s.bytes().map(u32::from).sum();
        chk = chk.wrapping_add(sum).wrapping_add(back as u32);
        t += STEP;
    }
    let ms = start.elapsed().as_secs_f64() * 1000.0;
    println!("trip\t{:.3}\t{}", ms, chk);
}
