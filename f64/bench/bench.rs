use std::time::Instant;

fn f(hi: u32, lo: u32) -> f64 {
    f64::from_bits(((hi as u64) << 32) | lo as u64)
}

fn hi(x: f64) -> u32 {
    (x.to_bits() >> 32) as u32
}

fn main() {
    let xs = [
        f(1072693248, 0),
        f(1073217536, 0),
        f(1074266112, 0),
        f(1017118720, 0),
        f(0, 1),
        f(3220176896, 0),
    ];
    let t0 = Instant::now();
    let mut h = 0u32;
    for a in xs {
        for b in xs {
            h ^= hi(a + b) ^ hi(a * b) ^ hi(a / b);
        }
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("fold\t{ms:.3}\t{h}");
}
