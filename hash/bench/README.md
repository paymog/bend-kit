# Hash benchmark

This times each hash in `hash` on one fixed input, in Bend and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang` with zlib, `pkg-config` with libsodium, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, or if two languages print different hashes for one op.

## Input

16,777,213 bytes (2^24 - 3), byte `i` is `i mod 251`. The length leaves a tail on every path: 1 byte past a word, 5 past a 64-bit lane, 13 past an xxh32 stripe, and 29 past an xxh64 stripe. Each program builds the input before any timer starts, times only the hash, and prints the hash in hex as its checksum. Seeds and SipHash keys are 0. The `crc32_short` op hashes the first 16 bytes of the input 100,000 times, so it times the cost of one call on a short input.

| op | checksum |
|---|---|
| crc32 | `b99c61cb` |
| crc32_short | `cecee288` |
| adler32 | `1a0c3336` |
| fnv1a32 | `d3ed8073` |
| fnv1a64 | `c4b7033804d9b153` |
| xxh32 | `c004c50d` |
| xxh64 | `ba036b508762d94b` |
| siphash13 | `5499ab03ca48bea5` |
| siphash24 | `f0c18ef62990dd94` |

## Results

M4 Pro, macOS, 2026-11-20, `hash` 0.3.2.0. Median of three runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| crc32 | 0.4 (1.0x) | n/a | 1.6 (3.9x) | 0.5 (1.4x) | 0.4 (1.0x) | 6.5 (16.2x) |
| crc32_short | 0.7 (1.7x) | n/a | 0.9 (2.0x) | 2.9 (6.7x) | 4.3 (10.2x) | 0.4 (1.0x) |
| adler32 | 0.8 (1.0x) | n/a | 4.4 (5.5x) | n/a | 0.8 (1.0x) | 15.8 (20.0x) |
| fnv1a32 | n/a | n/a | n/a | n/a | n/a | 16.8 (1.0x) |
| fnv1a64 | n/a | n/a | n/a | n/a | n/a | 33.9 (1.0x) |
| xxh32 | n/a | n/a | 2.8 (1.6x) | n/a | n/a | 1.8 (1.0x) |
| xxh64 | n/a | n/a | 0.7 (1.0x) | n/a | n/a | 4.7 (6.5x) |
| siphash13 | n/a | 3.0 (1.0x) | n/a | n/a | 3.1 (1.0x) | 4.5 (1.5x) |
| siphash24 | 5.6 (1.0x) | n/a | n/a | n/a | n/a | 8.6 (1.5x) |

Versions: Bend 2.0.40, Apple clang 21.0.0, rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6, libsodium 1.0.22.

The `hash` 0.3.1.0 helper release was checked on 2026-11-20 with Bend 2.0.40 and one run per variant (`python3 run.py 1`). All eight checksums matched. Bend times in ms were CRC-32 6.6, short CRC-32 0.4, Adler-32 16.0, FNV-1a 32 17.0, FNV-1a 64 34.0, xxHash32 1.8, xxHash64 4.7, and SipHash-1-3 4.5.

`hash` 0.3.0.4 runs CRC-32 by slicing-by-8: eight table lookups per 64-bit lane, over eight tables, each a `match`. One word and then single bytes take the tail.

| `crc32` variant | `hash` | crc32 | crc32_short |
|---|---|---:|---:|
| one byte step at a time | 0.3.0.2 | 31.3 | 0.7 |
| slicing-by-4, `match` tables | 0.3.0.3 | 11.0 | 0.3 |
| slicing-by-8, `match` tables | 0.3.0.4 | 6.6 | 0.4 |
| slicing-by-8, one 2,048-entry `Array` table passed through the fold, lanes only | not kept | 7.4 | n/a |

An `Array.get` costs more than a 256-arm `match` in compiled Bend, so the tables stay `match` defs. `crc32_short` hashes 16 bytes, which is two lanes, and the lane fold costs about 0.1 ms more there than four words.

Before `hash` 0.3.0.2, `crc32` built its 256-entry table on every call, with 2,048 bit steps. In the same run setup, `hash` 0.3.0.1 took 23.4 ms for `crc32_short` and 33.1 ms for `crc32`. The table is now a `match` on the index, so no call builds it.

### Slicing-by-16 trial

M4 Pro, macOS, Bend 2.0.40, 2026-11-21. Native builds use the same `bench.bend` input and timers as above. Each round starts a fresh process for each variant. Variant order reverses on every round. The first trial uses ten rounds in the order baseline / slicing-by-16 / short words, then the reverse. Each later trial uses twelve baseline / candidate pairs, alternating AB and BA. No Bend processes run concurrently. All runs retain `b99c61cb` and `cecee288`.

| trial | variant | crc32 (ms) | crc32_short (ms) |
|---|---|---:|---:|
| 1 | 0.3.2.0 baseline, slicing-by-8 | 6.471 | 0.401 |
| 1 | slicing-by-16, no short path | 4.330 | 0.478 |
| 1 | slicing-by-8, words below 32 bytes | 6.456 | 0.372 |
| 2 | 0.3.2.0 baseline | 6.411 | 0.412 |
| 2 | slicing-by-16, words below 32 bytes (kept) | 4.248 | 0.372 |
| 3 | 0.3.2.0 baseline | 6.416 | 0.412 |
| 3 | slicing-by-16, short word loop without read-ahead | 4.209 | 0.376 |
| 4 | 0.3.2.0 baseline | 6.394 | 0.396 |
| 4 | slicing-by-16, unrolled short words | 4.376 | 0.465 |

The kept variant wins all twelve long-input pairs and eleven of twelve short-input pairs in trial 2. Long-input times range from 4.082 to 4.824 ms, against 6.115 to 6.576 ms. Short-input times range from 0.351 to 0.401 ms, against 0.370 to 0.437 ms. The medians improve by 33.7% and 9.8%. The 0.3 ms short-input goal is not met.

The short word loop without read-ahead does not show a clear gain over the existing word fold. Unrolling makes the short case slower. Neither is kept. The long path reads two 64-bit lanes per step and uses sixteen constant `match` tables. One lane, one word, and then bytes handle the tail. Inputs below 32 bytes use the existing word fold.

Masked `Array.get` reads remain. These measurements do not depend on unchecked reads or a fix for bendlang/bend#1936. `check.bend` compares every length from 0 through 257 with a bitwise reference, with two byte patterns and non-zero padding beyond the logical input.

## The calls

| language | calls |
|---|---|
| Bend | `Hash.crc32`, `adler32`, `fnv1a32`, `fnv1a64`, `xxh32`, `xxh64`, `siphash13`, `siphash24` on `Bytes` |
| C | zlib `crc32` and `adler32`; libsodium `crypto_shorthash_siphash24` |
| Rust | `std::hash::DefaultHasher::new()`, which is SipHash-1-3 with a zero key |
| Bun | `Bun.hash.crc32`, `adler32`, `xxHash32`, `xxHash64` |
| Node | `zlib.crc32` |
| Python | `zlib.crc32` and `zlib.adler32`; `hash(bytes)` under `PYTHONHASHSEED=0`, which is SipHash-1-3 with a zero key |

No language here has FNV-1a in its standard library or in one very popular library, so the FNV rows are Bend only; the laws check those against the published vectors. C, Rust, and Python have no xxHash without a third-party package, and Rust's standard library has no CRC-32 or Adler-32.

SipHash-2-4 uses libsodium in C. The other standard libraries here do not expose SipHash-2-4 with a chosen key, so those cells are omitted.

## Caveats

- Adler-32 and FNV-1a take one byte per step, and a Bend step costs more than a C one. CRC-32 takes sixteen bytes per step and uses sixteen table lookups, each a `match`. xxHash and SipHash take a word or a 64-bit lane per step, so Bend is within a small multiple there.
- 64-bit hashes run on two `U32` halves, as `Hash.W64`. A 64-bit multiply is four 16-bit products.
- Python's `hash` and Rust's `DefaultHasher` fix the key at zero here. They are not APIs for a chosen key.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.
