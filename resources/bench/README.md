# Resources benchmark

This times the lease hot path of `http` admission: take one unit from a pool of 64, and give one unit back. It compares `resources` against a counting semaphore in C, Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend` (2.0.35, the CI pin), `cc`, `cargo`, `bun`, `node`, `npm`, and `python3`. `run.py` installs `async-sema@3.1.1` into `out/js`, and cargo fetches `tokio`. Binaries go to `out/`, which git ignores. It exits non-zero if a build or install fails, or if two programs disagree on the checksum.

## The op

Each program runs R = 2^14 rounds. A round takes one unit 65 times, so 64 takes succeed and one is refused. Then it gives 64 units back. That is 2,113,536 operations. The checksum is `admitted*31 + refused`, in u32.

| language | take | give |
|---|---|---|
| Bend | `Res.reserve(pool, 1n)`, then `Res.combine` into the held grant | `Res.split(held, 1n)`, then `Res.release` |
| C | `dispatch_semaphore_wait(s, DISPATCH_TIME_NOW)` | `dispatch_semaphore_signal` |
| Rust | `tokio::sync::Semaphore::try_acquire`, then `forget` | `add_permits(64)` once per round |
| Python | `threading.BoundedSemaphore.acquire(blocking=False)` | `release` |
| JavaScript | `async-sema` `tryAcquire` | `release` |

C's standard library has no counting semaphore, and macOS does not implement unnamed POSIX semaphores, so C uses libdispatch. Rust's standard library has no semaphore, so Rust uses `tokio` 1.47.1. JavaScript's standard library has none, so it uses `async-sema`. The Bend loop is `bench.bend`, which keeps a lease as `http/admission.bend` does.

## Results

M4 Pro, macOS 26.6.2, 2026-10-08. Five runs (`python3 run.py 5`), median, in ms.

Versions: Bend 2.0.35, Apple clang 17.0.0, rustc 1.91.0, tokio 1.47.1, Bun 1.3.14, Node 24.0.1, async-sema 3.1.1, Python 3.14.6.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| lease | 4.9 | 4.1 | 28.9 | 9.8 | 1,188.3 | 0.4 |

Every program prints the checksum 32522240.

## Reading it

- The Bend loop is pure and has one owner, so it does no atomic operation. Each baseline is a thread-safe semaphore, and each take or give is an atomic read-modify-write. The Bend number measures the transitions, not synchronization.
- At R = 2^24 the native Bend binary takes about 350 ms on one thread, which is about 0.17 ns for each operation. That is less than one clock cycle, so the compiled loop does not run each transition as a separate step. Its checksum still equals `64R*31 + R` at 2^14, 2^18, 2^20, and 2^24. A real pool pays more.
- `http` admission runs these transitions inside one actor. Each take and give there also costs a channel round trip, which this bench does not time.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads R from argv, so the work cannot run before the clock starts.
- One machine, one size, one thread.
