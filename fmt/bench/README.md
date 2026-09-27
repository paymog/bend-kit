# Shortest F32 benchmark

This times `F32.shortest`, which prints the shortest decimal that reads back to the same `F32`, against the standard printers of C, Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, `python3`, and numpy. Binaries go to `out/`, which git ignores. The run takes about 10 seconds. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The work

N = 50000 words from the u32 LCG `s = s*1664525 + 1013904223`, seeded with 1. Each word is read as the bits of an `F32`, so the input has every exponent, subnormals, infinities, and NaNs. Every program builds the words before it starts the clock.

Each word prints in Python `repr` style: plain from 1e-4 up to 1e16, scientific outside, `.0` on whole numbers, `nan`, `inf`, and `-0.0`. The checksum is 32-bit FNV-1a over every string, each followed by `\n`.

When two shortest decimals are equally near the value, every program takes the one with the even last digit, as Ryu and numpy do.

| language | shortest digits |
|---|---|
| Bend | `Fmt.F32.shortest`: Burger and Dybvig's free-format algorithm over 224-bit integers |
| C | `snprintf("%.*e")` for 1 to 9 digits until `strtof` reads the value back |
| Rust | `format!("{:.*e}")` for 1 to 9 digits until `parse::<f32>` reads the value back. `{:e}` gives the shortest digits in one call, but it breaks exact ties upward. |
| Python | numpy `format_float_scientific(unique=True)`. Python has no `float32`. |
| JavaScript | `toExponential` for 1 to 9 digits until `Math.fround` reads the value back. It breaks exact ties upward, so a 40-digit expansion finds ties and steps an odd last digit down. |

Each baseline reshapes its digits and exponent into `repr` style. That glue is the same in every language.

## Results

M4 Pro, macOS, 2026-09-27. Bend 2.0.29, Apple clang 17.0.0 (`-O2`), rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6 with numpy 2.4.2. Median of three runs. Times are in ms.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| short | 44.1 | 46.4 | 103.4 | 95.7 | 135.4 | 1,844 |

Every program prints the checksum 3985549205.

## Reading it

- Bend takes about 37 µs per value, 40 times C. The digits come from exact integer arithmetic on 14 limbs of 16 bits: up to about 45 scalings by 10, then one subtraction loop per digit. Ryu would take a few 64-bit multiplies instead, but Base has no `U64` (bendlang/bend#1027).
- The C and Rust loops format up to nine times per value, so they are not the fastest possible printers either.

## Caveats

- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- One machine, one thread.
