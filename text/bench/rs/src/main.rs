// Text benchmark: similar, strsim, and textwrap (see README.md).
use similar::{capture_diff_slices, Algorithm, DiffOp};
use std::time::Instant;

fn lcg(x: u32) -> u32 {
    x.wrapping_mul(1103515245).wrapping_add(12345) & 0x7FFF_FFFF
}

fn word(mut x: u32) -> (String, u32) {
    x = lcg(x);
    let n = 4 + (x >> 16) % 9;
    let mut w = String::new();
    for _ in 0..n {
        x = lcg(x);
        w.push((97 + (x >> 16) % 26) as u8 as char);
    }
    (w, x)
}

fn report(op: &str, t0: Instant, chk: String) {
    println!("{op}\t{:.3}\t{chk}", t0.elapsed().as_secs_f64() * 1000.0);
}

fn main() {
    let s: usize = std::env::args().nth(1).and_then(|a| a.parse().ok()).unwrap_or(1);
    let n = s * 10000;
    let a: Vec<String> = (0..n).map(|i| format!("line {i}")).collect();
    let mut b = Vec::new();
    for i in 0..n {
        if i % 50 == 7 {
            b.push(format!("changed {i}"));
        } else if i % 70 != 11 {
            b.push(format!("line {i}"));
        }
        if i % 90 == 13 {
            b.push(format!("added {i}"));
        }
    }

    let t0 = Instant::now();
    let changes: usize = capture_diff_slices(Algorithm::Myers, &a, &b)
        .iter()
        .map(|op| match *op {
            DiffOp::Equal { .. } => 0,
            DiffOp::Delete { old_len, .. } => old_len,
            DiffOp::Insert { new_len, .. } => new_len,
            DiffOp::Replace { old_len, new_len, .. } => old_len + new_len,
        })
        .sum();
    report("diff", t0, changes.to_string());

    let t0 = Instant::now();
    let (mut acc, mut x) = (0u32, 1u32);
    for _ in 0..s * 20000 {
        let (w1, x1) = word(x);
        let (w2, x2) = word(x1);
        x = x2;
        acc = acc.wrapping_add(strsim::levenshtein(&w1, &w2) as u32);
    }
    report("distance", t0, acc.to_string());

    let mut ws = Vec::new();
    let mut x = 1u32;
    for _ in 0..s * 20000 {
        let (w, x1) = word(x);
        x = x1;
        ws.push(w);
    }
    let text = ws.join(" ");
    let t0 = Instant::now();
    let ls = textwrap::wrap(&text, 72);
    let chars: usize = ls.iter().map(|l| l.len()).sum();
    report("wrap", t0, format!("{}:{}", ls.len(), chars));
}
