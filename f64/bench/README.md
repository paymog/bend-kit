# F64 benchmark

This times one fold of add, multiply, and divide on six finite values, and decimal text out and in for 1000 doubles. It compares them with IEEE doubles in C, Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, or if two programs disagree on the checksum.

## The work

**fold.** The six values, as high and low words, are `1`, `1.5`, `3`, `2^-53`, the minimum subnormal, and `-1`. For each pair the fold xors the high word of the sum, the product, and the quotient. Every program prints that word.

**show** and **read.** Each program makes 1000 xorshift32 pairs from seed 611, takes each pair as the high and low words of a double, and keeps the finite ones. `show` times writing each double as text. `read` times reading that text back. The checksum of both is the xor of the two words of each value read back, so it matches only when every text reads back to the same double.

| language | show | read |
|---|---|---|
| C | `snprintf("%.17g")` | `strtod` |
| Rust | `format!("{:?}")` | `str::parse::<f64>` |
| Python | `repr` | `float` |
| JavaScript | `String` | `Number` |
| Bend | `F64.show` | `F64.read` |

C's `%.17g` always writes 17 significant digits. The other printers write the shortest text that reads back. So C reads longer text than the others. Rust uses the standard library, not the `ryu` crate: `rustc` alone cannot build a crate dependency, and `{:?}` is already shortest round-trip.

Bend uses the soft-float in `f64.bend`. The other languages use a hardware double. The C program copies the words with `memcpy`, so it assumes a little-endian host.

## Results

M4 Pro, macOS, 2026-11-03. Bend 2.0.38, Apple clang 21.0.0 (`-O2`), rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs. Times are in ms.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| fold | 0.000 | 0.000 | 0.094 | 0.019 | 0.019 | 0.072 |
| show | 0.522 | 0.186 | 0.267 | 0.184 | 0.693 | 132.476 |
| read | 0.026 | 0.024 | 0.259 | 0.089 | 0.384 | 42.930 |

The checksum is `2245001216` for fold and `1004543192` for show and read, in every program.

C and Rust finish the fold in under 0.0005 ms, so the table prints `0.000`. Bend takes 0.072 ms for the same 108 operations. That is the soft-float. A native `F64` in Base would remove it.

Bend's `show` takes about 130 µs per double and `read` about 43 µs. Both work in exact big integers of 16-bit limbs. `show` scales by a power of ten up to 10^324, and `read` divides by a power of five, so the cost grows with the distance of the exponent from zero. The other languages use table-driven fast paths, such as Ryu, Grisu, or Eisel-Lemire, and fall back to big integers only for hard cases.
