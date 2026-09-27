// Shortest F32 benchmark: the Rust side (see README.md). Argument: N.
// `{:e}` breaks exact ties upward, so this uses the obvious loop: 1 to 9 digits,
// rounded half to even, until parse reads x back. The rest is Python repr style.
use std::fmt::Write;
use std::time::Instant;

fn shortest(x: f32, out: &mut String) {
    out.clear();
    if x.is_nan() { out.push_str("nan"); return; }
    if x.is_infinite() { out.push_str(if x < 0.0 { "-inf" } else { "inf" }); return; }
    if x == 0.0 { out.push_str(if x.is_sign_negative() { "-0.0" } else { "0.0" }); return; }
    let a = x.abs();
    let mut sci = String::new();
    for p in 0..9 {
        sci = format!("{:.*e}", p, a);
        if sci.parse::<f32>().unwrap() == a { break; }
    }
    let (m, e) = sci.split_once('e').unwrap();
    let e: i32 = e.parse().unwrap();
    let mut d: String = m.chars().filter(|c| *c != '.').collect();
    while d.len() > 1 && d.ends_with('0') { d.pop(); }
    let nd = d.len() as i32;
    if x < 0.0 { out.push('-'); }
    if e < -4 || e >= 16 {
        out.push_str(&d[..1]);
        if nd > 1 { out.push('.'); out.push_str(&d[1..]); }
        write!(out, "e{}{:02}", if e < 0 { '-' } else { '+' }, e.abs()).unwrap();
    } else if e < 0 {
        out.push_str("0.");
        for _ in 0..(-e - 1) { out.push('0'); }
        out.push_str(&d);
    } else if e + 1 >= nd {
        out.push_str(&d);
        for _ in 0..(e + 1 - nd) { out.push('0'); }
        out.push_str(".0");
    } else {
        out.push_str(&d[..(e + 1) as usize]);
        out.push('.');
        out.push_str(&d[(e + 1) as usize..]);
    }
}

fn main() {
    let n: usize = std::env::args().nth(1).map_or(50000, |s| s.parse().unwrap());
    let mut s: u32 = 1;
    let xs: Vec<u32> = (0..n).map(|_| { s = s.wrapping_mul(1664525).wrapping_add(1013904223); s }).collect();
    let t0 = Instant::now();
    let mut h: u32 = 2166136261;
    let mut out = String::new();
    for &b in &xs {
        shortest(f32::from_bits(b), &mut out);
        for c in out.bytes().chain(std::iter::once(b'\n')) {
            h = (h ^ c as u32).wrapping_mul(16777619);
        }
    }
    println!("short\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, h);
}
