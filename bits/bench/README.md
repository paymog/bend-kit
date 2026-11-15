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
