# Random benchmark

This times 2^24 xoshiro128** draws (`Rand.next`) from one fixed state, in Bend and in Rust.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cargo`, and `python3`. Binaries go to `out/`, which git ignores. The script exits non-zero if a build fails or if the checksums differ.

## Input

The state is `{1, 2, 3, 4}`. Each program draws 16,777,216 `U32`s and folds them into `h = h*31 + x`, in wrapping u32. The checksum is `3687561720`.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27, `random` 0.1.0.0. Median of five runs. Times are in ms.

| op | Rust | Bend |
|---|---:|---:|
| next | 14.6 (1.0x) | 14.0 (1.0x) |

Versions: Bend 2.0.31, rustc 1.91.0, `rand_xoshiro` 0.8.1.

## The calls

| language | call |
|---|---|
| Bend | `Rand.next`, from `Rand.from_state(1, 2, 3, 4)` |
| Rust | `rand_xoshiro::Xoshiro128StarStar::next_u32`, from `from_seed` with the same words, little-endian |

C, Python, and JavaScript are left out. Their standard libraries have no xoshiro128**: C has `rand`, Python has MT19937, and `Math.random` cannot be seeded. A different generator would print a different checksum.

## Caveats

- The checksum's `h*31` chain is serial, so both loops are bound by its latency, not by the generator.
- Bend's `IO.now` counts in whole ms.
- This is a micro-benchmark on one machine.
