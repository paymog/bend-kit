// Resources benchmark: tokio::sync::Semaphore (see ../README.md).
use std::time::Instant;
use tokio::sync::Semaphore;

fn main() {
    let lg: u32 = std::env::args().nth(1).map_or(14, |a| a.parse().unwrap());
    let rounds = 1u64 << lg;
    let pool = Semaphore::new(64);
    let (mut admitted, mut refused) = (0u32, 0u32);
    let t0 = Instant::now();
    for _ in 0..rounds {
        for _ in 0..65 {
            match pool.try_acquire() {
                Ok(permit) => {
                    permit.forget();
                    admitted += 1;
                }
                Err(_) => refused += 1,
            }
        }
        pool.add_permits(64);
    }
    let chk = admitted.wrapping_mul(31).wrapping_add(refused);
    let ms = t0.elapsed().as_secs_f64() * 1e3;
    println!("lease\t{ms:.3}\t{chk}");
}
