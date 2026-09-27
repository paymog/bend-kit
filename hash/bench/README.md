# Hash benchmark

This times each hash in `hash` on one fixed input, in Bend and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang` with zlib, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 15 seconds. It exits non-zero if a build fails, or if two languages print different hashes for one op.

## Input

16,777,213 bytes (2^24 - 3), byte `i` is `i mod 251`. The length leaves a tail on every path: 1 byte past a word, 5 past a 64-bit lane, 13 past an xxh32 stripe, and 29 past an xxh64 stripe. Each program builds the input before any timer starts, times only the hash, and prints the hash in hex as its checksum. Seeds and SipHash keys are 0.

| op | checksum |
|---|---|
| crc32 | `b99c61cb` |
| adler32 | `1a0c3336` |
| fnv1a32 | `d3ed8073` |
| fnv1a64 | `c4b7033804d9b153` |
| xxh32 | `c004c50d` |
| xxh64 | `ba036b508762d94b` |
| siphash13 | `5499ab03ca48bea5` |

## Results

M4 Pro, macOS 26.6.2, 2026-09-27, `hash` 0.1.0.0. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| crc32 | 0.6 (1.0x) | n/a | 3.0 (5.5x) | 1.9 (3.4x) | 2.5 (4.5x) | 80.0 (145.2x) |
| adler32 | 1.1 (1.0x) | n/a | 9.0 (8.2x) | n/a | 1.6 (1.4x) | 63.0 (57.1x) |
| fnv1a32 | n/a | n/a | n/a | n/a | n/a | 55.0 (1.0x) |
| fnv1a64 | n/a | n/a | n/a | n/a | n/a | 94.0 (1.0x) |
| xxh32 | n/a | n/a | 3.0 (1.0x) | n/a | n/a | 4.0 (1.3x) |
| xxh64 | n/a | n/a | 1.9 (1.0x) | n/a | n/a | 15.0 (8.0x) |
| siphash13 | n/a | 6.2 (1.0x) | n/a | n/a | 7.8 (1.3x) | 13.0 (2.1x) |

Versions: Bend 2.0.29, Apple clang 17.0.0, rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | calls |
|---|---|
| Bend | `Hash.crc32`, `adler32`, `fnv1a32`, `fnv1a64`, `xxh32`, `xxh64`, `siphash13` on `Bytes` |
| C | zlib `crc32` and `adler32` |
| Rust | `std::hash::DefaultHasher::new()`, which is SipHash-1-3 with a zero key |
| Bun | `Bun.hash.crc32`, `adler32`, `xxHash32`, `xxHash64` |
| Node | `zlib.crc32` |
| Python | `zlib.crc32` and `zlib.adler32`; `hash(bytes)` under `PYTHONHASHSEED=0`, which is SipHash-1-3 with a zero key |

No language here has FNV-1a in its standard library or in one very popular library, so the FNV rows are Bend only; the laws check those against the published vectors. C, Rust, and Python have no xxHash without a third-party package, and Rust's standard library has no CRC-32 or Adler-32.

## Caveats

- CRC-32, Adler-32, and FNV-1a take one byte per step, and a Bend step costs more than a C one. xxHash and SipHash take a word or a 64-bit lane per step, so Bend is within a small multiple there.
- 64-bit hashes run on two `U32` halves, as `Hash.W64`. A 64-bit multiply is four 16-bit products.
- Python's `hash` and Rust's `DefaultHasher` fix the key at zero here. They are not APIs for a chosen key.
- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- These are micro-benchmarks on one machine.
