# Hash benchmark

This times each hash in `hash` on one fixed input, in Bend and in C, Rust, JavaScript (Bun and Node), and Python. It also measures a CRC-32 short-input matrix in Bend and Python zlib.

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

## Short-input matrix

Run `python3 run.py 5` from this directory. The runner prints compiler versions, checks all 36 Bend checksums against Python's standard `zlib.crc32`, and reports median batch times and Bend nanoseconds per call. Missing rows or changed checksums fail the run.

Each sample hashes one buffer 100,000 times. Input construction runs before the timer. The timed loop retains the buffer and returns the last CRC. Times include loop overhead; Python uses a scalar loop, not a list of results. Patterns are zero bytes, incrementing bytes (`byte[i] = i`), and deterministic mixed bytes (`byte[i] = ((i * 73 + 19) ^ (i * i * 11)) & 255`). Each length starts at byte index zero.

M4 Pro, macOS, 2026-11-25, `hash` 0.3.2.2 at `fb528db`. Median of five fresh processes per language. Bend 2.0.40, Apple clang 21.0.0, rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Only one process runs at a time. The unchanged 16 MB benchmark also ran; all nine existing checksums above still agree.

| pattern | bytes | checksum | Bend ms | Python zlib ms | Bend ns/call |
|---|---:|---|---:|---:|---:|
| zero | 0 | `00000000` | 0.258917 | 2.364000 | 2.589 |
| zero | 1 | `d202ef8d` | 0.247875 | 3.149000 | 2.479 |
| zero | 3 | `ff41d912` | 0.252459 | 3.192000 | 2.525 |
| zero | 4 | `2144df1c` | 0.247833 | 2.875000 | 2.478 |
| zero | 7 | `9d6cdf7e` | 0.278666 | 3.275000 | 2.787 |
| zero | 8 | `6522df69` | 0.268083 | 3.258000 | 2.681 |
| zero | 15 | `d7d303e7` | 0.360000 | 3.483000 | 3.600 |
| zero | 16 | `ecbb4b55` | 0.370959 | 4.093000 | 3.710 |
| zero | 17 | `c9eff1bd` | 0.410750 | 4.358000 | 4.107 |
| zero | 31 | `6909acb0` | 0.770333 | 6.834000 | 7.703 |
| zero | 32 | `190a55ad` | 1.076541 | 2.955000 | 10.765 |
| zero | 33 | `7a7c3a8d` | 0.853083 | 3.236000 | 8.531 |
| incrementing | 0 | `00000000` | 0.259333 | 2.291000 | 2.593 |
| incrementing | 1 | `d202ef8d` | 0.262583 | 3.080000 | 2.626 |
| incrementing | 3 | `0854897f` | 0.246291 | 2.881000 | 2.463 |
| incrementing | 4 | `8bb98613` | 0.250375 | 3.281000 | 2.504 |
| incrementing | 7 | `ad5809f9` | 0.281000 | 3.436000 | 2.810 |
| incrementing | 8 | `88aa689f` | 0.264375 | 3.245000 | 2.644 |
| incrementing | 15 | `a06c675e` | 0.359083 | 3.526000 | 3.591 |
| incrementing | 16 | `cecee288` | 0.361000 | 4.117000 | 3.610 |
| incrementing | 17 | `2c183a19` | 0.400333 | 3.561000 | 4.003 |
| incrementing | 31 | `4d786d77` | 0.716917 | 7.082000 | 7.169 |
| incrementing | 32 | `91267e8a` | 0.682500 | 3.151000 | 6.825 |
| incrementing | 33 | `e4908305` | 0.657500 | 3.262000 | 6.575 |
| mixed | 0 | `00000000` | 0.245792 | 2.480000 | 2.458 |
| mixed | 1 | `56bcae53` | 0.237792 | 3.150000 | 2.378 |
| mixed | 3 | `80bf342c` | 0.242000 | 3.207000 | 2.420 |
| mixed | 4 | `7353c3c7` | 0.235084 | 3.276000 | 2.351 |
| mixed | 7 | `c1b4bca4` | 0.271375 | 3.284000 | 2.714 |
| mixed | 8 | `7aa48464` | 0.268792 | 3.280000 | 2.688 |
| mixed | 15 | `1faad43c` | 0.366583 | 3.224000 | 3.666 |
| mixed | 16 | `37c8fb54` | 0.373083 | 3.579000 | 3.731 |
| mixed | 17 | `f1ec40c9` | 0.387292 | 4.455000 | 3.873 |
| mixed | 31 | `90b6db35` | 0.711542 | 7.133000 | 7.115 |
| mixed | 32 | `25f00e0b` | 0.590625 | 2.928000 | 5.906 |
| mixed | 33 | `fa25a71d` | 0.638458 | 3.282000 | 6.385 |

The 16-byte incrementing input does not represent all callers. These samples span about 2.35 to 10.77 ns per call. Lengths around the 32-byte path boundary and different byte patterns need separate measurements. Fixed pattern order and machine noise can affect these medians; the zero-byte 32-byte row alone does not prove a pattern-specific bottleneck.

This is a baseline measurement, not an optimization comparison. No production CRC code changes. A future candidate must run alternating baseline/candidate pairs (AB, BA) for every matrix row before claiming a gain. Keep the long-input checksum and timing in that comparison.

## Rotated 32-byte boundary

Run `python3 boundary.py 5 boundary.csv` from this directory. This builds
`boundary.bend`, which reuses the matrix input builder, timer, and 100,000-call
loop from `bench.bend`. Each fresh process runs nine rotations of the nine
pattern/length rows. Rotation `r` starts at row `r` and wraps around. Each row
thus occupies each timed position once per process. Input construction is
outside the timer. The runner rejects missing rows, wrong row order, and any
checksum that differs from Python's standard `zlib.crc32`.

M4 Pro, macOS 26.7.2 arm64, 2026-11-26. Baseline: `hash` 0.3.2.2 at
`666d99b`. Bend 2.0.40, Apple clang 21.0.0 (clang-2100.4.1.1), Python
3.14.6. Five fresh processes, one at a time, give 45 samples per row and
405 samples in total. [boundary.csv](boundary.csv) retains every sample,
with process, rotation, position, call count, time, and checksum. Times
below are milliseconds per 100,000 calls, including the repeat loop.

| pattern | bytes | median ms | min ms | max ms |
|---|---:|---:|---:|---:|
| zero | 31 | 0.684125 | 0.636708 | 0.834750 |
| zero | 32 | 0.629250 | 0.563291 | 0.669875 |
| zero | 33 | 0.638667 | 0.588750 | 0.744959 |
| incrementing | 31 | 0.737542 | 0.683667 | 0.801667 |
| incrementing | 32 | 0.472125 | 0.429917 | 0.528709 |
| incrementing | 33 | 0.497084 | 0.467584 | 0.552917 |
| mixed | 31 | 0.739750 | 0.680791 | 0.816208 |
| mixed | 32 | 0.445209 | 0.424333 | 0.513917 |
| mixed | 33 | 0.476916 | 0.444667 | 0.512625 |

The medians by timed position, across all rows and processes, are
0.604125, 0.614792, 0.595209, 0.630583, 0.629250, 0.612459, 0.606792,
0.629959, and 0.630333 ms. Each position has the same mix of rows.
The 0.035124 ms position-median range is smaller than the 32-byte zero
versus incrementing gap (0.157125 ms), or the zero versus mixed gap
(0.184041 ms). In all five processes, the zero 32-byte median exceeds
both other 32-byte medians. Its individual samples do not overlap theirs.
The pattern cost therefore survives row rotation in this build.

The previous 1.076541 ms zero 32-byte median does not reproduce. This
experiment does not assign that earlier excess to order alone: it uses
a separate entry point and cannot remove machine or code-layout effects.
Rotation balances timed position, not every possible predecessor pair.
At 31 bytes, zero is faster than the other patterns. At 32 and 33, it
is slower. The boundary reduces the median for every pattern, but by
different amounts. There is no general 32-byte slowdown.

### Generated-code inspection

From the repo root:

```sh
bend hash/bench/boundary.bend -o hash/bench/out/boundary.c
clang -O2 -S hash/bench/out/boundary.c -o hash/bench/out/boundary.s
```

- **Path selection:** generated C `spin____hash_crc32` compares the
  logical length with 32. The assembly retains `cmp w12, #32` and
  `b.lo` inside the repeat loop. No branch inspects the byte pattern.
  Thus pattern differences at a fixed length do not select another path.
- **Table work:** `spin____hash_crc_tab*` emits `TAB_AT`, not a
  256-way runtime branch. Assembly uses indexed constant-table `ldr`
  instructions and XORs. The 31-byte path performs seven word updates
  (four table reads each), then three byte updates: 31 table reads.
  The 32-byte path performs two 16-byte updates: 32 table reads.
  The 33-byte path adds one byte update: 33 table reads.
  Table addresses depend on the input and CRC state. There is no
  zero-specific instruction path. Cache or load scheduling could explain
  part of the pattern gap, but these timings do not prove that cause.
- **Loop work:** `spin_bench_short` counts down and calls the CRC on
  the same retained buffer. The native assembly retains that outer loop;
  it does not hoist the hash out. At 31 bytes the word loop has seven
  iterations and the byte tail has three. At 32 bytes the block loop
  has two iterations and no byte tail. At 33 bytes it has two iterations
  and one byte tail. The generated folds carry scalar CRC state and
  read masked array indices. They allocate no per-word or per-block
  heap objects. The short word fold still reads ahead, and both paths
  still enter their tail helpers even when a tail count is zero.

These are operation counts and inclusive timings, not separate nanosecond
estimates for dispatch, loads, or loop control. The lower block-loop count
explains why more table reads need not mean a slower call. The remaining
pattern cost is reproducible here, but its hardware cause is unresolved.
Production code is unchanged. No candidate or optimization gain is claimed.
Any future candidate must use alternating AB/BA pairs and retain the
16 MB benchmark and its checksums.

Validation: `scripts/check.sh hash`, `scripts/native-check.sh hash`,
`scripts/publish.sh --check`, and `scripts/pins.sh` pass. The unchanged
`python3 hash/bench/run.py 1` also passes all cross-language and matrix
checksum checks. Its Bend 16 MB CRC time is 4.4 ms, checksum `b99c61cb`;
the other eight operation checksums remain as listed above. This one-run
check is not a performance comparison.

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

### Short-call overhead trials

M4 Pro, macOS, Bend 2.0.40, 2026-11-24. The baseline is `hash` 0.3.2.2 at commit `bcf3678`. Build each variant with `bend hash/bench/bench.bend -o hash/bench/out/<variant>` from the repo root. Each trial runs twelve baseline / candidate pairs in fresh processes. Order alternates AB and BA. Each process runs the unchanged benchmark above, including the other hashes. Only one process runs at a time. All 48 runs retain CRC checksums `b99c61cb` and `cecee288`.

Two candidates target the short path without changing the long path:

- **Aligned tail:** keep `wfrom` and `crc.word`, but skip `bytewise.rest` when `len & 3` is zero. Return the buffer and accumulated CRC directly before `crc.fin`. Other lengths keep the existing byte tail.
- **Fused short loop:** replace the generic word fold with a CRC-specific loop. Carry the next word and read ahead as before. At zero words, call `bytewise.last` and `crc.fin` inside the loop, rather than return through `bytewise.rest` and finalize outside the fold.

Times are medians in ms. Wins count pairs in which the candidate is faster.

| trial | variant | crc32 | crc32_short | long wins | short wins |
|---|---|---:|---:|---:|---:|
| aligned tail | baseline | 4.278688 | 0.372479 | — | — |
| aligned tail | candidate | 4.290667 | 0.373208 | 6/12 | 3/12 |
| fused short loop | baseline | 4.241979 | 0.358854 | — | — |
| fused short loop | candidate | 4.214000 | 0.365437 | 7/12 | 6/12 |

The individual paired times follow. Odd pairs run baseline first; even pairs run candidate first.

| trial | pair | baseline long | candidate long | baseline short | candidate short |
|---|---:|---:|---:|---:|---:|
| aligned tail | 1 | 4.982583 | 4.426042 | 0.396000 | 0.357750 |
| aligned tail | 2 | 4.260834 | 4.368167 | 0.355042 | 0.368833 |
| aligned tail | 3 | 4.183000 | 4.363875 | 0.361042 | 0.375625 |
| aligned tail | 4 | 5.073125 | 4.201542 | 0.355208 | 0.367000 |
| aligned tail | 5 | 4.185375 | 4.285375 | 0.424083 | 0.434292 |
| aligned tail | 6 | 4.386291 | 4.295959 | 0.410500 | 0.357583 |
| aligned tail | 7 | 4.373083 | 4.241708 | 0.382000 | 0.365542 |
| aligned tail | 8 | 4.088500 | 4.312625 | 0.341750 | 0.383333 |
| aligned tail | 9 | 4.296541 | 4.159459 | 0.367458 | 0.382916 |
| aligned tail | 10 | 4.213834 | 4.407459 | 0.329125 | 0.370791 |
| aligned tail | 11 | 4.104583 | 4.223334 | 0.390792 | 0.403958 |
| aligned tail | 12 | 4.345041 | 4.217209 | 0.377500 | 0.378250 |
| fused short loop | 1 | 4.602917 | 4.462167 | 0.368042 | 0.365958 |
| fused short loop | 2 | 4.260709 | 4.389459 | 0.387375 | 0.337292 |
| fused short loop | 3 | 4.238833 | 4.160000 | 0.352916 | 0.346666 |
| fused short loop | 4 | 4.182666 | 4.169084 | 0.355333 | 0.370375 |
| fused short loop | 5 | 4.231833 | 4.253292 | 0.350791 | 0.364917 |
| fused short loop | 6 | 4.196417 | 4.210833 | 0.357750 | 0.355625 |
| fused short loop | 7 | 4.245125 | 4.175750 | 0.364042 | 0.398041 |
| fused short loop | 8 | 4.291542 | 4.206042 | 0.359958 | 0.379458 |
| fused short loop | 9 | 4.182750 | 4.217167 | 0.413625 | 0.385708 |
| fused short loop | 10 | 4.377875 | 4.156583 | 0.372959 | 0.344666 |
| fused short loop | 11 | 4.339417 | 4.283209 | 0.333708 | 0.364500 |
| fused short loop | 12 | 4.194375 | 4.229375 | 0.353750 | 0.385083 |

Neither candidate gives a reliable short-input gain or reaches 0.3 ms. Both are discarded. The generated C already uses scalar CRC state and constant table reads; the word loop allocates no per-word objects. Skipping the empty tail and folding finalization into the loop do not establish a remaining call-overhead bottleneck.

The production implementation stays unchanged. `scripts/check.sh hash` and `scripts/native-check.sh hash` pass after discarding the candidates. They include CRC laws and the reference checks for lengths 0 through 257, two byte patterns, and dirty padding. These results close this experiment without claiming the 0.3 ms target.

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
