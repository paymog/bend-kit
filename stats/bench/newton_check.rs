use std::time::Instant;
fn quo(n: u64, r: u64) -> u64 { if r == 0 { 0 } else { n / r } }
fn main() {
    let start = Instant::now();
    let mut sum = 0u64;
    let mut maximum = 0u64;
    let mut maximum_input = 0u32;
    let mut corrected = 0u64;
    for wide in 0..=u32::MAX as u64 {
        let n = wide as u32;
        let log = if n == 0 { 0 } else { 31 - n.leading_zeros() };
        let seed = (1u32 << (1 + log / 2)) as u64;
        let mut r = 1 + seed;
        for _ in 0..4 { r = (r + quo(wide, r)) / 2; }
        r = r.min(65536);
        let mut fuel = 65537u64;
        let mut count = 0u64;
        while wide < r * r && fuel != 0 {
            fuel -= 1;
            r -= 1;
            count += 1;
        }
        assert!(fuel != 0, "fuel exhausted for {}", n);
        assert!(r * r <= wide && wide < (r + 1) * (r + 1), "bad root for {}", n);
        assert!(r <= u32::MAX as u64);
        sum += r;
        corrected += (count != 0) as u64;
        if count > maximum { maximum = count; maximum_input = n; }
    }
    assert_eq!(sum, 187647836979200);
    println!("Checked all 4294967296 inputs; max decrements {}; first input {}; corrected inputs {}; sum {}; elapsed {:?}", maximum, maximum_input, corrected, sum, start.elapsed());
}
