# Integer benchmark

This times arithmetic on each `int` type and compares it against native integers in C and Rust, `int` in Python, and numbers or `BigInt` in JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 30 seconds. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The ops

The `U64` ops use N = 16384. The 32-bit and narrower ops use N2 = 10^7. The baselines take N and N2 as their first two arguments. `bench.bend` has both built in.

| op | work | checksum |
|---|---|---|
| `lcg` | `U64`: `x = x * 6364136223846793005 + 1442695040888963407`, N times from x = 1 | the last x |
| `rem` | `U64`: sum of `x mod 1000003` over N dividends | the sum |
| `i32` | `I32`: `x = x * 1664525 + 1013904223` and `acc = acc + x / 1000` (truncating), N2 times from x = 1 | acc |
| `u16` | `U16`: `x = x * 25173 + 13849`, N2 times from x = 1 | the last x |
| `u8` | `U8`: `x = x * 77 + 13`, N2 times from x = 1 | the last x |

All arithmetic wraps. The `rem` dividends are `hi << 32 | lo`, where `hi` and `lo` are two steps of the u32 LCG `s = s*1664525 + 1013904223` seeded with 1. Every program builds that list before it starts the clock. N2 is not a power of two, because 2^k steps of the full-period `u16` and `u8` LCGs return to the seed.

| language | 64-bit | 32-bit and narrower |
|---|---|---|
| Bend | `Int.U64` (`Word(64n)`) | `Int.I32`, `Int.U16`, `Int.U8` (a `U32` inside) |
| C | `uint64_t` | `int32_t`, `uint16_t`, `uint8_t` |
| Rust | `u64`, wrapping | `i32`, `u16`, `u8`, wrapping |
| Python | `int`, masked | `int`, masked |
| JavaScript | `BigInt` with `BigInt.asUintN(64, …)` | numbers with `Math.imul`, `\| 0`, and masks |

## Results

M4 Pro, macOS, 2026-09-26. Bend 2.0.29, Apple clang 17.0.0 (`-O2`), rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs. Times are in ms.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| lcg | 0.016 | 0.017 | 0.960 | 1.142 | 1.688 | 1,138 |
| rem | 0.008 | 0.008 | 0.730 | 0.828 | 1.233 | 1,103 |
| i32 | 10.2 | 10.0 | 11.1 | 11.0 | 2,897 | 11 |
| u16 | 10.2 | 9.4 | 12.6 | 12.8 | 568 | 12 |
| u8 | 10.3 | 9.7 | 13.4 | 14.3 | 404 | 12 |

Every program prints the same checksum:

| op | checksum |
|---|---:|
| lcg | 11190202161140744193 |
| rem | 8184357799 |
| i32 | -1610362603 |
| u16 | 59265 |
| u8 | 129 |

## Reading it

- `I32`, `U16`, and `U8` keep their value in a Base `U32`, which the compiler lowers to a machine integer. They run at about 1 ns per step, level with C and Rust. The first version kept them in `Word(n)`: at N2 = 10^5 it took 3,787 ms for `i32`, 541 ms for `u16`, and 201 ms for `u8`, with the same checksums.
- `U64` is still `Word(64n)`, a list of 64 `Bool` cells, and one multiply-add or remainder takes about 68 µs. That is about 650 to 900 times slower than Python. Native `U64` in Base (bendlang/bend#1027) would remove that cost.

## Caveats

- Bend's `IO.now` counts in whole ms, so the Bend rows for the small types are ±1 ms. The other languages use sub-ms clocks.
- The small-type loops take their seed from the clock (`one(t)`), so the compiler cannot fold them at build time.
- The C backend holds a known `Word(64n)` as 64 words, and a function with more than 247 live words does not build (bendlang/bend#1069). A loop that copies four `U64` values hits that limit, so `rem` walks a prebuilt list.
- One machine, one thread.
