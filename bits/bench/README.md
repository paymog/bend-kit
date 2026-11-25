# Bits benchmark

This times two hot paths over one fixed payload: Huffman decode of a DEFLATE block, and 13-bit field reads. Bend runs `bits.bend`. Rust runs `bitstream-io`. C, Python, and Bun run zlib's inflate.

## Run

```sh
python3 run.py            # 3 runs per variant, median, 1 MiB plain
python3 run.py 5          # 5 runs
python3 run.py 1 65536    # 1 run on 64 KiB plain
```

You need `bend`, `cc`, Homebrew `zlib`, `cargo`, `python3`, and `bun`. `run.py` writes `out/payload.bin`, `out/tree.rs`, and the binaries to `out/`, which git ignores. It exits non-zero if a build fails, if zlib does not inflate the payload back to the plain bytes, or if a variant prints a checksum that differs from the one `run.py` computes.

## Input

`run.py` builds **1,048,576** plain bytes: an LCG from seed **0x5EED** gives each byte as the top 8 bits of its state. It encodes them as one final fixed-Huffman DEFLATE block (RFC 1951 §3.2.6) of literals, then end-of-block. The payload is **1,105,946** bytes. zlib inflates it back to the plain bytes.

Each program reads `out/payload.bin` before its timer starts.

- **`huffman`**: decode every literal until end-of-block. Bend builds the fixed table with `Huff.from_lens` before the timer and calls `Huff.decode` per symbol. Rust calls `read_huffman` per symbol on a tree that `run.py` writes as `compile_read_tree_nodes!` input, the crate's own decoder. C (`inflate`), Python (`zlib.decompress`), and Bun (`inflateRawSync`) inflate the whole payload. Their timers stop before the checksum loop. Bend and Rust fold each symbol into the checksum as they decode. Checksum: `h = h*31 + byte` in wrapping u32 over the plain bytes, **1974733589**.
- **`fields`**: read the payload as 13-bit LSB-first fields until fewer than 13 bits are left (680,582 fields). Checksum: `h = h*31 + field`, **2819181156**.

`define_huffman_tree!` also generates a writer; its macro expansion did not finish in ten minutes for 288 symbols, so `run.py` uses the read macro alone. C, Python, and JavaScript have no bit reader in their standard libraries, so they skip `fields`. zlib is the popular library for DEFLATE decode in each, so `huffman` uses it. It does more work than a symbol decode: it also writes the output and its window.

## Results

M4 Pro, macOS 26.6.2, arm64, 2026-10-27. Median of three runs. Times are in ms. MB/s is plain bytes per second.

| variant | huffman ms | huffman MB/s | fields ms |
|---|---:|---:|---:|
| Bend | 5.55 | 189 | 0.56 |
| C (zlib inflate) | 4.63 | 226 | - |
| Rust (bitstream-io) | 36.58 | 29 | 0.62 |
| Python (zlib) | 1.89 | 555 | - |
| Bun (node:zlib) | 3.32 | 316 | - |

Bend's single-level table reads one 32-bit window and one table entry per symbol. `bitstream-io` reads one bit per tree step, so its Huffman decode is the slowest here. Python links its own zlib 1.2.12; C links Homebrew zlib 1.3.1.

Versions: Bend 2.0.38, Apple clang 17.0.0 (`-O2`), rustc 1.91.0 with bitstream-io 4.10.0 (Cargo release build), Python 3.14.6, Bun 1.3.14. `Cargo.lock` pins the crate.

## Dynamic table build cost

```sh
python3 run.py --build 3
```

This operation builds a complete literal/length tree with maximum length 15.
Symbols 0–254 have length 8. Symbols 255–262 have lengths
`[9, 10, 11, 12, 13, 14, 15, 15]`. The unused distance tree has one length-1 code.
The input contains literals and end-of-block, without length/distance matches.
The runner writes a valid dynamic DEFLATE header and checks zlib's result.
Bend receives the same coded symbols, without the dynamic header.
It times `Huff.from_lens` separately from `Huff.decode`, including the checksum.
File reads and byte conversion are outside both timers.
C times zlib's full inflate, including header parsing and table construction.
It excludes file reads and the checksum, as in the fixed-block benchmark.
All variants must return the plain input's checksum on every run.

M4 Pro, macOS 25.6.0, arm64. Bend 2.0.40, Apple clang 17.0.0 (`-O2`),
Homebrew zlib 1.3.1, Python 3.14.6.
Each Bend cell is the median of 300 samples: 100 build/decode pairs per process,
three processes per block size. C cells are medians of three processes.
Times are milliseconds per block.

| plain bytes | single-level build | single-level decode | build / decode | zlib inflate |
|---:|---:|---:|---:|---:|
| 1024 | 0.057354 | 0.043729 | 1.31 | 0.012000 |
| 4096 | 0.054500 | 0.072791 | 0.75 | 0.016000 |
| 8192 | 0.054583 | 0.113604 | 0.48 | 0.023000 |
| 16383 | 0.054584 | 0.194812 | 0.28 | 0.036000 |

The single-level build exceeded half the decode time at 1 and 4 KiB.
The decoder now uses a 9-bit root and a secondary table for each occupied long-code
prefix. This fixture needs 512 root entries and 64 secondary entries, rather than
32768 entries. Trees of at most 9 bits still need only the root.
Secondary tables use the maximum remaining width, not a separate width per prefix.
Sparse long-code trees can therefore allocate unused secondary entries.

| plain bytes | two-level build | two-level decode | build / decode | zlib inflate |
|---:|---:|---:|---:|---:|
| 1024 | 0.041604 | 0.042625 | 0.98 | 0.014000 |
| 4096 | 0.041042 | 0.067333 | 0.61 | 0.015000 |
| 8192 | 0.041917 | 0.100959 | 0.42 | 0.020000 |
| 16383 | 0.040938 | 0.164729 | 0.25 | 0.037000 |

Build cost fell by 25–28%. Canonical setup still dominates the shortest blocks.
These inputs measure table setup, not a general DEFLATE throughput distribution.
The fixed-block results above describe the old single-level implementation.

The current fixed-block run (`python3 run.py 3`, same versions as the build run)
gave the following results. All five checksums matched.

| variant | huffman ms | huffman MB/s | fields ms |
|---|---:|---:|---:|
| Bend | 8.49 | 124 | 0.58 |
| C (zlib inflate) | 3.00 | 349 | - |
| Rust (bitstream-io) | 36.20 | 29 | 0.62 |
| Python (zlib) | 1.82 | 577 | - |
| Bun (node:zlib) | 3.14 | 334 | - |

The old fixed-block run used a different Bend version and OS version.
These runs do not isolate the effect of the table change on fixed-block decode.

## Writer growth

```sh
bend grow.bend -o out/grow
out/grow
```

This compares the previous byte-copy growth with `Bits.room` retaining its old
subtree. The old buffer contains `123456789` in every word. Allocation of that
buffer and a checksum of every result word are outside the timer. The new right
subtree contains zeroes. Each sample checks its checksum and exits on a mismatch.

M4 Pro, macOS 25.6.0, arm64, Bend 2.0.40. Median of three samples,
2026-11-21. Times are milliseconds per doubling.

| old buffer | copy | retain subtree | checksum |
|---|---:|---:|---:|
| 256 KiB | 0.057292 | 0.042458 | 3440705536 |
| 1 MiB | 0.117916 | 0.082209 | 877920256 |

Both methods returned the expected checksum in every sample. These short runs
measure one growth operation, not whole-stream write throughput.
The fixed-block suite (`python3 run.py 3`) also passed all five checksums:
Bend Huffman 8.40 ms and fields 0.57 ms; C 3.02 ms; Rust Huffman 36.33 ms
and fields 0.61 ms; Python 1.77 ms; Bun 3.15 ms.

## Large stream positions

M4 Pro, macOS 25.6.0, arm64, Bend 2.0.40, Apple clang 21.0.0, 2026-11-21.
The input is the same 1 MiB fixed block above. These are medians of 21 paired
native runs, alternating the baseline at `792ac4b` and this implementation.
Both binaries read the same `out/payload.bin`.

| position representation | huffman ms | fields ms |
|---|---:|---:|
| U32 bit cursor | 8.267458 | 0.564542 |
| Nat total and remaining bits | 9.059500 | 0.565375 |
| change | +9.58% | +0.15% |

Both operations stay below the 10% slowdown limit. A Nat cursor that recomputed
the remaining bits on each read slowed fields by 26.47%, so the reader keeps
total and remaining bits instead. Advancing subtracts from the remaining count.
The window still reads exactly two array words. The writer uses a Nat cursor.

The full suite (`python3 run.py 5`) also passed every checksum. Rust used
rustc 1.91.0 and bitstream-io 4.10.0. Python was 3.14.6; Bun was 1.4.4.
These separate five-run medians do not replace the paired comparison above.

| variant | huffman ms | fields ms |
|---|---:|---:|
| Bend | 9.23 | 0.57 |
| C (zlib inflate) | 2.97 | - |
| Rust (bitstream-io) | 37.19 | 0.63 |
| Python (zlib) | 1.87 | - |
| Bun (node:zlib) | 3.30 | - |

## Controlled Huffman profile

M4 Pro, macOS 26.7.2 (25G332), arm64, 2026-11-24. Bend 2.0.40,
Apple clang 21.0.0. All builds use the same compiler and machine.
Only benchmark files changed. The decoder and its validation did not change.

### Canonical setup

```sh
python3 run.py --build 3
python3 run.py --profile 3
```

The first command uses the normal timer boundaries. Each Bend cell is the
median of 300 samples, as in the earlier dynamic-table run.

| plain bytes | build ms | decode ms | build / decode | zlib inflate ms |
|---:|---:|---:|---:|---:|
| 1024 | 0.040646 | 0.041084 | 0.99 | 0.013000 |
| 4096 | 0.041229 | 0.069937 | 0.59 | 0.016000 |
| 8192 | 0.041271 | 0.106563 | 0.39 | 0.022000 |
| 16383 | 0.041542 | 0.176563 | 0.24 | 0.038000 |

The second command splits the same max-15 setup into stages in `profile.bend`.
It calls the existing setup helpers. `codes` converts lengths to symbol records.
`maximum` finds the longest code. `count` builds the length histogram.
`next` computes canonical starts and checks for over-subscription.
`reserve` clones the starts, reserves long-code prefixes, and allocates both tables.
`assign` fills both tables. Each stage is followed by a monotonic clock read.
`clock` times two consecutive clock reads, without setup work between them.
Each cell below is the median of 300 raw samples, in milliseconds.

| plain bytes | clock | codes | maximum | count | next | reserve | assign |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1024 | 0.033500 | 0.036312 | 0.034083 | 0.033771 | 0.032938 | 0.034105 | 0.035229 |
| 4096 | 0.033459 | 0.036812 | 0.033146 | 0.034229 | 0.033271 | 0.034125 | 0.034188 |
| 8192 | 0.032522 | 0.036334 | 0.034250 | 0.034146 | 0.033166 | 0.034313 | 0.034812 |
| 16383 | 0.033292 | 0.036499 | 0.034375 | 0.034250 | 0.033500 | 0.034334 | 0.034500 |

The clock boundary costs about 33 microseconds. Most stages cannot be ranked
reliably with these boundaries. Even the largest excess, length conversion,
is only about 3 microseconds. Do not add these medians or treat a difference
below the clock baseline as negative work. Instrumented total build medians
are 0.210250–0.212375 ms because they include six clock boundaries.

The profile also times 1000 complete builds inside one pure loop. It reads
root entry zero from each result and checks the sum against 8000.
This forces each build and includes destruction of its arrays.
Each cell below is the median of 30 batches: ten batches per process,
three processes per input size. The fixture is identical at every size.

| associated plain bytes | 1000 builds ms | ms per build |
|---:|---:|---:|
| 1024 | 7.228375 | 0.007228 |
| 4096 | 7.265021 | 0.007265 |
| 8192 | 7.264333 | 0.007264 |
| 16383 | 7.266021 | 0.007266 |

The earlier 0.041 ms build measurement is mostly clock-boundary overhead.
It is not evidence that canonical setup consumes 0.041 ms of CPU work.
Every profiled decode still checks the original payload checksum.

### Batched canonical stages

```sh
python3 stages.py 3
```

Run this command from `bits/bench`. It compiles `stages.bend` with Bend 2.0.40.
M4 Pro, macOS 26.7.2 (25G332), arm64, Apple clang 21.0.0, Python 3.14.6,
2026-11-25. No runtime code changed.

The fixture is `Build.lens()`, the same complete max-15 tree used above.
Each native process takes ten samples. Each sample runs each stage 1000 times
in a pure loop, without an intervening clock read. The table contains medians
of 30 samples from three processes. All times are milliseconds per 1000 trees.

Before each operation timer, the program prepares 1000 independent inputs.
The preparation column includes that allocation, the required earlier stages,
and one clock boundary. It is not part of the operation column.
The operation column includes loop traversal, the stage, result consumption,
and destruction. A separate control prepares the same stage's outputs outside
its timer, then runs the same consumer over 1000 outputs.
The paired difference subtracts this control from the operation in each sample.
The final column is the observed minimum–maximum of those paired differences,
not a confidence interval.

Maximum, count, reserve, and assign retain the code list beside their result.
Both their operation and control consume this list with the same checksum loop.
This keeps list destruction in both measurements and gives the operation a
shared input list, as in the full builder. Without this control, freeing a
unique list makes the maximum scan appear to cost several extra milliseconds.
`reserve` calls `Profile.reserved`, including the starts clone and table
allocations. `assign` calls `Bits.assign.two` and wraps the result as `Huff`.
The inputs for `next` are already-built count arrays.

| stage | input preparation | operation + consumption | consumption control | paired difference | difference range |
|---|---:|---:|---:|---:|---:|
| codes | 0.989980 | 4.019145 | 1.772792 | 2.255708 | 1.816167–2.528292 |
| maximum | 3.547645 | 2.700770 | 1.848292 | 0.964938 | 0.463375–1.680417 |
| count | 3.599875 | 2.890270 | 1.836334 | 1.043938 | 0.541750–1.718166 |
| next | 6.851145 | 0.053875 | 0.044791 | 0.009751 | -0.007584–0.027000 |
| reserve | 11.041458 | 3.127063 | 1.887417 | 1.128125 | 0.829166–2.003792 |
| assign | 17.844063 | 5.238646 | 1.941541 | 3.294105 | 2.518625–4.045541 |

Two consecutive `Time.mono` calls have a median of 0.034875 ms and a range
of 0.030334–0.136083 ms. This boundary occurs once per batch, not per tree.
Length conversion and assignment are the largest resolved costs here.
The maximum, count, and reserve ranges overlap, so this run cannot rank them.
The `next` difference is smaller than the clock boundary and crosses zero.
It is unresolved; the negative lower end does not mean negative CPU work.

Each operation and control checks a fixed wrapping-U32 checksum.
The code-list consumer adds every symbol and length, giving 36592 per tree.
Count reads bin 8 (255). Next checks canonical start 15 (32766) and validity
(1). Reserve reads start 15, root entry 511 (31), and secondary entry 0 (0).
Assign reads root entry 0 (8), using `Profile.batch.code`.
With retained-list sums, the six batch checksums are respectively
`36592000`, `36607000`, `36847000`, `32767000`, `69389000`, and `36600000`.
The program exits on a mismatch. The Python runner also checks all 20 rows
per sample. Checks and printing occur outside the operation and control timers.

The same sample also runs the existing `Profile.batch.loop` unchanged.
Its 1000 complete builds take 7.325229 ms (range 6.741041–7.850000), with
checksum 8000. This agrees with the earlier 7.23–7.27 ms batch measurements
within the observed range. The paired stage sums have median 8.719541 ms
(range 7.446209–10.255333), about 19% above the complete-build median.
The stages are therefore not an exact additive decomposition: separate batches
change allocation, ownership, cache state, and destruction, and subtract noisy
controls. They establish microsecond-scale costs, not the earlier clock-bound
33–37 microsecond stage estimates. No runtime rewrite follows from this run.


### Fixed-tree comparison

`compare.py` runs prebuilt binaries 21 times each. It rotates their order
between rounds and checks both original checksums on every run.
It generates the same 1 MiB fixed block used above.

```sh
python3 compare.py out/single-decode out/two-decode out/bend
```

The source snapshots are `1e909ec` (last single-level release), `0bff13e`
(two-level release with a U32 cursor), and `dc65cc4` (current Nat counts).
Export `bits/` and `time/` from each historical revision to a temporary
directory outside the repo. In historical `bits.bend` and `bench/bench.bend`,
change only the byte import to `bend-kit-bytes@0.3.3.1`.
Build each `bench/bench.bend` with Bend 2.0.40 and place its binary at the
path shown above. Build current `bench.bend` as `out/bend`.
The benchmark source is otherwise identical. The historical timer source
differs only in its byte import; the clock implementation is unchanged.
All binaries run from this benchmark directory and read its `out/payload.bin`.

| implementation | Huffman ms | fields ms |
|---|---:|---:|
| single-level, U32 cursor | 9.570958 | 0.577708 |
| two-level, U32 cursor | 8.463792 | 0.582708 |
| two-level, Nat total/remaining counts | 9.254500 | 0.581583 |

The two-level release is 11.57% faster than the single-level release here.
The current decoder is 3.31% faster than the single-level release.
The 5.55 ms historical result is not a valid baseline for this toolchain.
Nat counts add 9.34% to the two-level result, while fields change by -0.19%.
The decode path subtracts remaining bits from total bits before each window
lookup. This comparison includes that arithmetic, the remaining-count update,
and all intervening source changes; it does not isolate subtraction alone.
Both window implementations read two array words.

No runtime optimization was selected. The table change does not regress the
fixed-tree benchmark under a controlled comparison. Setup needs a lower-overhead
stage measurement before another rewrite is justified. The Nat-count cost is
measurable, but these results do not establish a faster replacement that retains
large-stream support and validation.

The full five-language suite (`python3 run.py 5`) passed every checksum:
Bend Huffman 9.26 ms and fields 0.58 ms; C 3.03 ms; Rust Huffman 36.87 ms
and fields 0.62 ms; Python 1.88 ms; Bun 3.13 ms.

## Sparse max-16 tables

```sh
python3 sparse.py 3
```

This measures the existing uniform secondary width, without changing the decoder.
The sparse fixture has lengths `[16, 16]`. The mixed fixture has 32 length-10
codes, 16 length-12 codes, and two length-16 codes. Both sets are incomplete.
Each input cycles through every symbol for 4096 symbols. Python assigns canonical
codes and packs the stream independently, in both stream orders.
The runner checks every decode checksum and each table's actual `Array.size`.

Each process runs ten samples per fixture and order. A build sample constructs
1000 tables, reads root entry zero from each, and checks the sum against 31000.
This forces construction and includes table destruction. The reported build time
is the batch time divided by 1000. Input conversion and decode-table construction
are outside the decode timer. Decode folds symbols into the wrapping checksum.
As in the fixed benchmark loop, it also makes one final unused decode probe.
The checksum and sample output are outside both timers.

M4 Pro, macOS 26.7.2, arm64, 2026-11-24. Bend 2.0.40.
Each cell is the median of 30 samples from three native processes.
Times are milliseconds.

| fixture | root entries | allocated secondary entries | build ms | decode 4096 ms | checksum |
|---|---:|---:|---:|---:|---:|
| sparse LSB | 512 | 128 | 0.000126 | 0.066583 | 628164608 |
| sparse MSB | 512 | 128 | 0.000136 | 0.073271 | 628164608 |
| mixed LSB | 512 | 4096 | 0.002261 | 0.072312 | 3343667776 |
| mixed MSB | 512 | 4096 | 0.002167 | 0.080500 | 3343667776 |

The sparse fixture occupies one root prefix. Its only secondary table needs
all seven remaining bits. Per-prefix widths cannot save entries there.
The mixed fixture occupies 19 prefixes: 16 need one bit, two need three bits,
and one needs seven bits. The current layout reserves 2432 entries and rounds
its array up to 4096 entries. Per-prefix widths would reserve 176 entries and
round up to 256. With the unchanged root, that is 768 rather than 4608 entries.
These are logical entry counts, not resident-byte measurements.
The compact counts exclude any new width metadata.

Keep the current layout. The mixed case exposes substantial potential memory
savings, but its current build costs only about 2.2 microseconds. The sparse case
has no width savings. Neither synthetic fixture establishes a caller memory
limit or a decode-speed benefit that warrants new width metadata and lookup work.
The compact counts are a sizing model, not measured compact-layout timings.
Revisit the layout when a real mixed-depth workload needs less table memory,
and compare build and decode times before selecting it. Both stream orders,
incomplete-code rejection, and truncation behavior remain unchanged.

## Reader order tracking

macOS arm64, Bend 2.0.40, 2026-11-24. `python3 run.py 3` used the same
1 MiB fixed block above. All five variants passed their checksum checks.
Times are medians of three runs, in milliseconds.

| variant | Huffman ms | fields ms |
|---|---:|---:|
| Bend | 12.32 | 0.58 |
| C (zlib inflate) | 2.97 | - |
| Rust (bitstream-io) | 36.50 | 0.64 |
| Python (zlib) | 1.90 | - |
| Bun (node:zlib) | 3.13 | - |

The reader now keeps the last successful field or Huffman read order.
It computes byte alignment only on an order switch. This run checks the
homogeneous-order hot paths; it is not a controlled before/after comparison.

## Isolated fixed-tree cursor experiments

M4 Pro, macOS 26.7.2 (25G332), arm64, Bend 2.0.40,
Apple clang 21.0.0, 2026-11-25.
The baseline is `a3257d1`, including reader order tracking.
Each candidate changes only one part of `bits.bend`; candidates are not combined.
All keep Nat stream counts and the two-word window.

- **Position:** replace the window's `Nat.sub(total, aligned)` with word-index
  subtraction and a low-five-bit borrow. Let `a = pos.offset(total)` and
  `b = pos.offset(aligned)`. Call `win.at` with index
  `pos.index(total) - pos.index(aligned) - (a < b ? 1 : 0)` and offset
  `(a - b) & 31`, using wrapping U32 arithmetic.
  This avoids the absolute-position Nat subtraction, but splits both counts.
- **Remaining:** replace only the successful remaining-count subtraction in
  `decode.hit`. If `left <= 4294967295n`, compute
  `U32.to_nat((U32.from_nat(left) - l : U32))`; otherwise keep
  `Nat.sub(left, U32.to_nat(l))`. The existing validity test still selects the
  original count on failure. The Nat fallback retains large-stream support.
- **Dispatch:** branch on `max <= 9` in `decode.root`. The short arm calls
  `decode.hit` directly. The other arm keeps the existing `decode.sub` and
  `decode.found` path. Both arms keep the original validation.

To reproduce, copy `bits.bend` separately for each candidate and apply only its
change above. Copy `bench.bend` for each candidate and change only its Bits import.
Compile the baseline and all three copies with `bend FILE -o BINARY`.
Run a 1 KiB payload first, then run the following command twice from `bits/bench`:

```sh
python3 compare.py out/baseline out/position out/remaining out/dispatch
```

Each pass has 21 rounds in rotating binary order on the same 1 MiB payload.
Each cell is the median in milliseconds. Both original checksums passed on all
168 full-size process runs: Huffman **1974733589**, fields **2819181156**.

| candidate | pass 1 Huffman | pass 1 fields | pass 2 Huffman | pass 2 fields |
|---|---:|---:|---:|---:|
| baseline | 12.234208 | 0.560500 | 12.464584 | 0.577500 |
| position | 12.906875 | 0.568834 | 12.909875 | 0.570083 |
| remaining | 12.360125 | 0.571542 | 12.425958 | 0.565459 |
| dispatch | 14.336958 | 0.572959 | 14.354209 | 0.573792 |

Position and dispatch are slower in both passes. The remaining-count fast path
changes from 1.03% slower to 0.31% faster, so it gives no repeatable gain.
Keep the runtime unchanged. These experiments do not rule out a different
representation, such as a separately maintained Nat cursor; they only reject
these three local replacements. No package version or sibling pin changes.
The unchanged package proofs and functional checks pass, including invalid and
truncated secondary-code checks in both orders. There are no native effects in
this package. The temporary candidate sources and binaries are not shipped.

## Caller table memory

```sh
python3 memory.py 1 1024
python3 memory.py 3
```

Run from `bits/bench` on macOS. The runner builds three native binaries,
one at a time. It needs Bend 2.0.40, Python, and `/usr/bin/time`.
Generated inputs, binaries, and `report.json` stay in `out/memory/`.
The JSON records every process RSS sample, input SHA-256, checksum, block
boundary, and code-length histogram, including unused symbols.
The parser checks stored, fixed, and dynamic blocks before the measurements.

The kit has one compression caller of `Bits.Huff`: the pure `zlib` decoder.
Raw DEFLATE, zlib, and gzip wrappers use that decoder. Native zlib effects use
the host library, not these tables. There is no JPEG or MP3 caller in the kit.
This run uses the actual caller, with its existing bits 0.3.0.1 hub pin.
Current bits 0.4.0.0 has the same uniform secondary layout. The synthetic
controls import local bits. No runtime, version, or pin changes are made.

The plain bytes come from `zlib/bench/run.py:plain_bytes`: LCG sentences,
newlines, and occasional raw bytes. The default sizes are 1024, 32768, and
131072 bytes. `kit` uses the kit's gzip encoder, with 32 KiB blocks.
`python` uses Python's `gzip.compress(..., mtime=0)`, with its default level.
Both compressed streams pass Python decompression against the exact plain
bytes. Every measured kit decode must return the plain-byte checksum.
The runner parses every block, not only the first header.

M4 Pro, macOS 25.6.0, arm64, 2026-11-25. Bend 2.0.40,
Apple clang 21.0.0, Python 3.14.6. Three fresh processes per row.
RSS is the whole process maximum from `/usr/bin/time -l`, in bytes.
The timer surrounds `gunzip`; file reads and output checksum conversion are
outside it. RSS includes those operations, runtime pages, input conversion,
the output buffer, and table construction. It is not table-only memory.

| encoder | plain bytes | gzip bytes | dynamic blocks | peak RSS bytes | checksum |
|---|---:|---:|---:|---:|---:|
| kit | 1024 | 540 | 1 | 2162688 | 569392708 |
| Python | 1024 | 538 | 1 | 2162688 | 569392708 |
| kit | 32768 | 10443 | 1 | 3244032 | 1279667653 |
| Python | 32768 | 10408 | 1 | 3244032 | 1279667653 |
| kit | 131072 | 35862 | 4 | 6406144 | 2713400746 |
| Python | 131072 | 35133 | 2 | 6389760 | 2713400746 |

The table gives the maximum of three RSS samples. Kit 1024 ranged from
2146304 to 2162688 bytes; kit 131072 ranged from 6389760 to 6406144.
All three samples matched within each other caller row.
The following depth ranges are the nonzero lengths across all blocks.
The secondary columns are allocated entries per table, not resident bytes.
The last column is the largest simultaneous literal-plus-distance allocation,
including both roots and both secondary arrays.

| encoder / plain bytes | literal depths | distance depths | literal secondary | distance secondary | peak payload entries |
|---|---|---|---:|---:|---:|
| kit / 1024 | 3–9 | 3–7 | 1 | 1 | 642 |
| Python / 1024 | 3–9 | 3–6 | 1 | 1 | 578 |
| kit / 32768 | 2–13 | 3–13 | 64 | 16 | 1104 |
| Python / 32768 | 2–13 | 3–10 | 64 | 2 | 1090 |
| kit / 131072 | 2–13 | 3–13 | 32–64 | 16 | 1104 |
| Python / 131072 | 2–13 | 3–11 | 8–64 | 2–8 | 1096 |

For the kit's first 32 KiB block, the literal histogram is
`2:1, 3:3, 4:1, 5:2, 6:7, 7:14, 8:4, 9:5, 10:2, 11:5, 12:3, 13:6`,
with 226 unused symbols. Its distance histogram is
`3:2, 4:9, 5:4, 6:2, 7:2, 8:2, 9:3, 10:1, 11:1, 12:1, 13:2`,
with one unused symbol. The other blocks' full histograms are in the JSON.
Header trees have maximum lengths 5–7 and no secondary entries beyond the
one-entry placeholder.

### Retention and controls

Concurrent table counts come from the caller's ownership flow, not an allocator
trace. `Cd` retains one header tree while it reads the lengths.
`dyn.done` drops that tree before `dyn.tables` creates the payload pair.
`MoCodes` retains exactly two tables during payload decode.
`inf.end` drops both on end-of-block; `inf.go` then reads the next header.
Neither later blocks nor later gzip members retain earlier tables.
Thus these sequential caller workloads retain at most two decode tables,
not two per block. The encoder builds encoding arrays, not decode tables.
Concurrent independent streams would multiply this count; this run uses one.

The parser records lifetime in compressed bit positions and output bytes.
For the kit's 128 KiB stream, the four payload intervals are
`[446,83400)`, `[83851,152108)`, `[152551,219178)`, and `[219609,286746)`.
Each pair serves exactly 32768 output bytes. Python's intervals are
`[414,254884)` and `[255274,280920)`, serving 118266 and 12806 bytes.
Positions exclude the gzip header. These are stream lifetimes, not elapsed
per-table times. The RSS high-water mark does not identify a particular phase.

The same runner executes the existing sparse/mixed controls in both orders.
It checks every build and decode checksum and the actual array sizes.
Each operation retains one table; the 1000-build loop destroys each before
the next build. The process runs all four controls in sequence.
Its three combined peak RSS samples were 2408448, 2392064, and 2392064 bytes.
These are not separate sparse and mixed RSS measurements, and must not be
subtracted from caller RSS to estimate table memory.

| control | lengths | root | secondary | modeled compact secondary |
|---|---|---:|---:|---:|
| sparse | two at 16 | 512 | 128 | 128 |
| mixed | 32 at 10, 16 at 12, two at 16 | 512 | 4096 | 256 |

Keep the current layout. These real mixed-depth caller trees allocate at most
64 secondary entries per literal tree, not the synthetic mixed tree's 4096.
A per-prefix model reduces the first kit literal secondary from 64 to 32
entries, but leaves its distance secondary at 16. Across all measured trees,
the largest saving is 32 allocated entries per table, before width metadata.
The caller has no configured table-memory limit and does not cache tables.
This run shows no caller limit that smaller secondary widths would resolve.
Whole-process RSS rises with the input/output workload, while retained table
counts stay at two. It does not establish table-only resident-byte costs.
No compact implementation was tested, so there is no compact decode-speed or
RSS claim. Revisit only with a caller limit or high concurrent-stream count,
then compare metadata-inclusive memory and batched build/decode on that input.
The caller's reader-order re-pin is already tracked in issue #1107.
