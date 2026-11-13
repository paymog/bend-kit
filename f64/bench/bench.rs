use std::time::Instant;

fn f(hi: u32, lo: u32) -> f64 {
    f64::from_bits(((hi as u64) << 32) | lo as u64)
}

fn hi(x: f64) -> u32 {
    (x.to_bits() >> 32) as u32
}

fn mix(x: f64) -> u32 {
    let b = x.to_bits();
    (b >> 32) as u32 ^ b as u32
}

fn xs(mut x: u32) -> u32 {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    x
}

fn main() {
    let v = [
        f(1072693248, 0),
        f(1073217536, 0),
        f(1074266112, 0),
        f(1017118720, 0),
        f(0, 1),
        f(3220176896, 0),
    ];
    let t0 = Instant::now();
    let mut h = 0u32;
    for a in v {
        for b in v {
            h ^= hi(a + b) ^ hi(a * b) ^ hi(a / b);
        }
    }
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("fold\t{ms:.3}\t{h}");

    let mut nums = Vec::new();
    let mut x = 611u32;
    for _ in 0..1000 {
        let a = xs(x);
        let b = xs(a);
        x = b;
        if (a >> 20) & 2047 != 2047 {
            nums.push(f(a, b));
        }
    }
    let t0 = Instant::now();
    let text: Vec<String> = nums.iter().map(|x| format!("{x:?}")).collect();
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    let h = text.iter().fold(0, |h, s| h ^ mix(s.parse().unwrap()));
    println!("show\t{ms:.3}\t{h}");

    let t0 = Instant::now();
    let h = text.iter().fold(0, |h, s| h ^ mix(s.parse().unwrap()));
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("read\t{ms:.3}\t{h}");

    let t0 = Instant::now();
    let h = nums.iter().fold(0, |h, x| h ^ mix(x.abs().sqrt()));
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("sqrt\t{ms:.3}\t{h}");
}
