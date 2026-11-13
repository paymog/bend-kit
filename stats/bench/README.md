# Statistics benchmark

This times the mean, the sample variance, and the median of 10000 doubles. It compares `stats` with C, Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The work

Each program makes 10000 xorshift32 draws from seed 44 and shifts each draw right by 12 bits, so every value is an integer below 2^20 and exact as a double. Each op prints the xor of the two words of its result.

| op | C | Rust | Python | JavaScript | Bend |
|---|---|---|---|---|---|
| mean | loop | `Iterator::sum` | `statistics.fmean` | loop | `Stats.mean` |
| variance | two-pass loop | two-pass `sum` | two-pass loop | two-pass loop | `Stats.variance` |
| median | `qsort` | `sort_by(total_cmp)` | `statistics.median` | `Float64Array.sort` | `Stats.median` |

C and JavaScript have no statistics in the standard library, and Rust's has none either, so those use the obvious loop. Python's `statistics.variance` rounds the exact value once, and Python's `sum` compensates. Both give a variance that differs from the plain two-pass loop in the low bits, so the Python program sums with a plain loop for that op. The sum of the values is exact here, so `fmean` matches the loop.

Bend uses the soft-float in `bend-kit-f64`. The other languages use a hardware double. The C program copies the words with `memcpy`, so it assumes a little-endian host.

## Results

M4 Pro, macOS, 2026-11-13. Bend 2.0.38, Apple clang 21.0.0 (`-O2`), rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Median of three runs. Times are in ms.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| mean | 0.005 | 0.006 | 0.608 | 0.476 | 0.027 | 0.287 |
| variance | 0.012 | 0.011 | 0.546 | 0.616 | 0.264 | 0.875 |
| median | 0.576 | 0.129 | 0.097 | 0.483 | 0.684 | 3.818 |

The checksums are `3422847917` for the mean, `1370401302` for the variance, and `1092607460` for the median, in every program.

Bend's mean and variance are about 50 to 80 times slower than C. That is the soft-float add and multiply, about 30 ns each. The median sorts a linked list with `List.sort` and soft-float compares, about 7 times slower than C's `qsort`. Bun and Node include JIT warm-up, because each op runs once.
