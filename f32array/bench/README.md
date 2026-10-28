# F32Array benchmark

This times the array ops that a model or feature pipeline runs, on 2^22 `float32` values (16 MiB), in Bend, C, Rust, JavaScript, and NumPy.

## Run

```sh
python3 run.py      # 3 runs, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, `python3`, and NumPy. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The work

`a[i] = (i + 3) & 3` and `b[i] = (5i + 3) & 3`, for N = 2^22. Every partial sum is an integer below 2^24, so each sum is exact in any order and every program prints the same checksums. Each program builds `a`, `b`, and the little-endian bytes of `a` before the first timer, then runs these ops in order:

| op | work | checksum |
|---|---|---|
| `from_bytes` | decode the 16 MiB of little-endian bytes into a new array `a` | `a[N-1] + a[12345]` |
| `sum` | add up `a` | the sum |
| `max` | the largest element of `a` | the max |
| `dot` | the sum of `a[i] * b[i]` | the dot product |
| `map` | `a[i] *= 2`, in place | `a[N-1] + a[12345]` |
| `add` | `a[i] += b[i]`, in place | `a[N-1] + a[12345]` |
| `to_bytes` | encode `a` as little-endian bytes in a new buffer | byte count + last byte |

Each language uses its obvious loop or standard call. C uses `memcpy` and plain loops (so it assumes a little-endian host). Rust uses `Vec<f32>` with `chunks_exact`, `from_le_bytes`, and iterator `sum`, `fold`, and `zip`. Bun and Node use `Float32Array` and `for` loops. Python's standard library has no vector math, so the Python column is NumPy: `frombuffer`, `sum`, `max`, `dot`, `*=`, `+=`, and `tobytes`.

## Results

M4 Pro, macOS, 2026-10-27. Bend 2.0.38, Apple clang 17.0.0 (`-O2`), rustc 1.91.0 (`opt-level=3`), Bun 1.3.14, Node 24.0.1, Python 3.14.6 with NumPy 2.4.2. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest program for that op.

| op | C | Rust | Bun | Node | NumPy | Bend |
|---|---:|---:|---:|---:|---:|---:|
| from_bytes | 1.26 (2.7x) | 2.15 (4.6x) | 1.84 (3.9x) | 1.54 (3.3x) | 0.46 (1.0x) | 3.66 (7.9x) |
| sum | 2.12 (4.0x) | 2.53 (4.7x) | 7.54 (14.1x) | 11.16 (20.9x) | 0.53 (1.0x) | 1.15 (2.2x) |
| max | 1.91 (8.9x) | 0.27 (1.2x) | 4.39 (20.4x) | 5.49 (25.5x) | 0.22 (1.0x) | 3.32 (15.4x) |
| dot | 2.42 (6.9x) | 2.57 (7.3x) | 25.74 (73.6x) | 25.55 (73.1x) | 0.35 (1.0x) | 1.95 (5.6x) |
| map | 0.25 (1.0x) | 0.28 (1.1x) | 21.02 (85.1x) | 3.28 (13.3x) | 0.28 (1.1x) | 0.44 (1.8x) |
| add | 0.34 (1.0x) | 0.37 (1.1x) | 6.36 (18.5x) | 8.51 (24.7x) | 0.37 (1.1x) | 0.45 (1.3x) |
| to_bytes | 1.11 (3.2x) | 1.56 (4.5x) | 0.34 (1.0x) | 0.61 (1.8x) | 2.49 (7.2x) | 2.13 (6.2x) |
| geomean vs fastest | 3.0x | 2.7x | 14.5x | 13.3x | 1.4x | 4.1x |

Every program printed checksums `2`, `6291456`, `3`, `14680064`, `4`, `6`, and `16777280`.

## Reading it

- Each `Array` slot holds a cell of eight elements, so a loop does one array access per eight elements. `sum`, `dot`, and `max` also keep four running values instead of one, so the next add does not wait for the last one. Before these two changes, with one `F32` per slot and one running value, Bend took 2.49 ms for `sum`, 2.99 for `dot`, 12.87 for `max`, 1.37 for `map`, and 1.62 for `add`.
- `sum` and `dot` now beat the C and Rust loops, which add one element at a time because IEEE rules stop the compiler from reordering the adds. NumPy adds pairwise with SIMD, and its `dot` calls BLAS, so it is still 2 to 6 times faster.
- `map` and `add` are within 2x of C.
- A loop that writes cells must not read the next cell ahead. The read-ahead form of `map` took 1.1 ms; reading and writing the same cell in each pass takes 0.3 to 0.4 ms. The read-only loops (`sum`, `dot`, `max`) read ahead without that cost.
- `max` is the slowest op that is left: 3.3 ms against 1.9 ms in C.
- `from_bytes` and `to_bytes` move eight words per cell. C and JS copy the memory, so they are 2 to 6 times faster.
- Every Bend op is one sequential loop. A fork-join split over the array's tree would use every core and give a pairwise sum. It has not been tried.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It prints each checksum before the second clock read, so the work is forced inside the timer.
- These are micro-benchmarks on one machine, at one size.
