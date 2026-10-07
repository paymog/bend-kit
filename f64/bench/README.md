# F64 benchmark

This times one fold of add, multiply, and divide on six finite values, and compares it with IEEE doubles in C, Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, or if two programs disagree on the checksum.

## The work

The six values, as high and low words, are `1`, `1.5`, `3`, `2^-53`, the minimum subnormal, and `-1`. For each pair the fold xors the high word of the sum, the product, and the quotient. Every program prints that word.

Bend uses the soft-float in `f64.bend`. The other languages use a hardware double. The C program copies the words with `memcpy`, so it assumes a little-endian host.

## Results

M4 Pro, macOS, 2026-10-07. Bend 2.0.35, Apple clang 17.0.0 (`-O2`), rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs. Times are in ms.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| fold | 0.000 | 0.000 | 0.065 | 0.018 | 0.019 | 0.074 |

Every program prints checksum `2245001216`.

C and Rust finish the fold in under 0.0005 ms, so the table prints `0.000`. Bend takes 0.074 ms for the same 108 operations. That is the soft-float. A native `F64` in Base would remove it.
