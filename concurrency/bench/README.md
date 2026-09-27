# Concurrency benchmark

This times a parallel map of one CPU-bound job over 64 inputs, on 1 worker and on 8, in Bend (`Conc.par_map`) and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The Bend binary runs with `--threads 8`. The run exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

The inputs are the integers 0 to 63. The job runs 2^20 rounds of `x = (x ^ (x >> 13)) * 1664525 + 1013904223` in wrapping u32 and answers `x`. The xor keeps the loop from having a closed form.

| op | work |
|---|---|
| `map_1` | the 64 jobs on 1 worker |
| `map_8` | the 64 jobs on 8 workers, 8 inputs each |

Each program times only the map. After the timer stops, it prints a checksum of the results in input order, `h = h*31 + x` in wrapping u32. The checksum is `4101098377` for both ops.

## The calls

| language | 1 worker | 8 workers |
|---|---|---|
| Bend | `Conc.par_map(~U32, ~U32, ~job, 1, xs)` | `Conc.par_map(~U32, ~U32, ~job, 8, xs)` |
| C | one `pthread_create` worker | 8 `pthread_create` workers, one contiguous chunk each |
| Rust | one `std::thread::scope` thread | 8 scoped threads over `chunks` |
| JavaScript | one `node:worker_threads` `Worker` | 8 `Worker`s |
| Python | `ProcessPoolExecutor(1).map` | `ProcessPoolExecutor(8).map`, chunk size 8 |

Python uses processes because the GIL keeps threads from running CPU work in parallel. Its pool starts before the timer. The JavaScript and C times include starting their workers.

## Results

Mac16,8 (Apple Silicon), Bend 2.0.31, Apple clang 17.0.0, Rust 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. One run with `python3 run.py 1`, milliseconds:

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| map_1 | 110.1 | 111.0 | 450.3 | 124.3 | 5796.8 | 92.0 |
| map_8 | 13.4 | 21.9 | 65.8 | 58.8 | 843.1 | 46.0 |
| speedup | 8.2x | 5.1x | 6.8x | 2.1x | 6.9x | 2.0x |

## Caveats

- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- 8 workers can only beat 1 on a machine with at least two free cores.
- These are micro-benchmarks on one machine.
