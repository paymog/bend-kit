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
