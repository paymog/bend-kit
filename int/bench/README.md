# Integer benchmark

This times `U64` multiply-add and `U64` remainder, and compares them against native 64-bit integers in C and Rust, `int` in Python, and `BigInt` in JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 20 seconds. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The ops

Every op uses N = 16384. The baselines take N as their first argument. `bench.bend` has N built in.

| op | work | checksum |
|---|---|---|
| `lcg` | `x = x * 6364136223846793005 + 1442695040888963407` (mod 2^64), N times from x = 1 | the last x |
| `rem` | sum of `x mod 1000003` over N dividends, wrapping mod 2^64 | the sum |

The `rem` dividends are `hi << 32 | lo`, where `hi` and `lo` are two steps of the u32 LCG `s = s*1664525 + 1013904223` seeded with 1. Every program builds the list before it starts the clock.

| language | type |
|---|---|
| Bend | `Int.U64` (`Word(64n)`) |
| C | `uint64_t` |
| Rust | `u64` with `wrapping_mul` and `wrapping_add` |
| Python | `int`, masked to 64 bits |
| JavaScript | `BigInt` with `BigInt.asUintN(64, …)`; JavaScript has no u64 |

## Results

M4 Pro, macOS, 2026-09-26. Bend 2.0.29, Apple clang 17.0.0 (`-O2`), rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs. Times are in ms.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| lcg | 0.017 | 0.028 | 0.999 | 1.157 | 1.703 | 1,122.000 |
| rem | 0.009 | 0.013 | 0.770 | 0.760 | 1.224 | 1,094.000 |

Every program prints the same checksum:

| op | checksum |
|---|---:|
| lcg | 11190202161140744193 |
| rem | 8184357799 |

## Reading it

- A Bend `U64` multiply-add takes about 68 µs, and a remainder takes about 67 µs. Bend is about 650 to 900 times slower than Python, and about 65,000 to 120,000 times slower than C.
- `Word(64n)` is a list of 64 `Bool` cells. `Word.mul` is shift-and-add over those cells, and the remainder is 64 rounds of shift, compare, and subtract. The cost is the representation, so a faster `U64` needs a different one, such as a pair of `U32`s.

## Caveats

- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- The C backend holds a known `Word(64n)` as 64 words, and a function with more than 247 live words does not build (bendlang/bend#1069). A loop that copies four `U64` values hits that limit, so `rem` walks a prebuilt list.
- One machine, one size, one thread.
