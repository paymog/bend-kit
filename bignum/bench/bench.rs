// BigInt benchmark: the Rust side, with num-bigint (see README.md).
use num_bigint::BigUint;
use num_integer::Integer;
use std::hint::black_box;
use std::time::Instant;

const M: &str = "170141183460469231731687303715884105727";
const X: &str = "123456789012345678901234567890123456789";
const A: &str = "98765432109876543210987654321098765432";
const N: usize = 64;

fn main() {
    let t0 = Instant::now();
    let m: BigUint = black_box(M).parse().unwrap();
    let a: BigUint = black_box(A).parse().unwrap();
    let mut x: BigUint = black_box(X).parse().unwrap();
    let mut acc = x.clone();
    for _ in 0..N {
        let (q, r) = (&x * &x + &a).div_rem(&m);
        black_box(q);
        x = r;
        acc += &x;
    }
    let chk = acc.to_string();
    println!("modsq\t{:.3}\t{}", t0.elapsed().as_secs_f64() * 1e3, chk);
}
