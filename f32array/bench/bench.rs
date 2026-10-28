use std::time::Instant;

const N: usize = 1 << 22;

fn ms(t: Instant) -> f64 {
    t.elapsed().as_secs_f64() * 1000.0
}

fn ends(x: &[f32]) -> u32 {
    (x[N - 1] + x[12345]) as u32
}

fn main() {
    let src: Vec<f32> = (0..N).map(|i| ((i + 3) & 3) as f32).collect();
    let b: Vec<f32> = (0..N).map(|i| ((i * 5 + 3) & 3) as f32).collect();
    let bytes: Vec<u8> = src.iter().flat_map(|x| x.to_le_bytes()).collect();

    let t = Instant::now();
    let mut a: Vec<f32> = bytes
        .chunks_exact(4)
        .map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]]))
        .collect();
    println!("from_bytes\t{:.6}\t{}", ms(t), ends(&a));

    let t = Instant::now();
    let s: f32 = a.iter().sum();
    println!("sum\t{:.6}\t{}", ms(t), s as u32);

    let t = Instant::now();
    let m = a.iter().copied().fold(a[0], f32::max);
    println!("max\t{:.6}\t{}", ms(t), m as u32);

    let t = Instant::now();
    let d: f32 = a.iter().zip(&b).map(|(x, y)| x * y).sum();
    println!("dot\t{:.6}\t{}", ms(t), d as u32);

    let t = Instant::now();
    a.iter_mut().for_each(|x| *x *= 2.0);
    println!("map\t{:.6}\t{}", ms(t), ends(&a));

    let t = Instant::now();
    a.iter_mut().zip(&b).for_each(|(x, y)| *x += y);
    println!("add\t{:.6}\t{}", ms(t), ends(&a));

    let t = Instant::now();
    let out: Vec<u8> = a.iter().flat_map(|x| x.to_le_bytes()).collect();
    println!("to_bytes\t{:.6}\t{}", ms(t), out.len() as u32 + out[out.len() - 1] as u32);
}
