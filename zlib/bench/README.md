# Zlib benchmark

This times `gunzip` on one fixed gzip member and `gzip` on its plain text, in Bend and in JavaScript (Bun and Node) and Python. Bend runs twice: `bench.bend` uses the pure `gunzip` and `gzip`, and `native.bend` uses the libz effects `inflate.words` and `gzip.words`.

## Run

```sh
python3 run.py      # 3 runs per variant, median, 4 MiB plain
python3 run.py 5    # 5 runs
python3 run.py 1 65536   # 1 run on 64 KiB plain; check RSS and checksum first after a change
```

You need `bend`, `bun`, `node`, `python3`, and `gzip`. `run.py` writes the plain text to `out/plain.bin`, the gzip member to `out/payload.gz`, and the Bend binaries to `out/`, which git ignores. The run takes about fifteen seconds. It exits non-zero if a build fails, if two variants print different checksums, or if system `gzip -d` does not turn each Bend output (`out/bend.gz`, `out/native.gz`) back into the plain text.

C and Rust are omitted: neither standard library ships gzip or DEFLATE.

## Input

`run.py` builds **N = 4,194,304** bytes (4 MiB) of deterministic ASCII text:

- Seed **0xDEADBEEF** drives an LCG that builds **1024** unique sentences from a fixed **247-word** vocabulary (6–17 words each, period-terminated).
- Seed **0xC0FFEE01** walks the plain text: append a sentence (space-separated), a newline, or a raw byte from the LCG (~3% random bytes, ~1.5% newlines).
- Gzip level **6**, **mtime=0**. Wire size **1,050,286** bytes; compression ratio **3.99×** (plain ÷ gzip).

Each program reads its inputs before any timer starts. The timed ops:

- **`inflate`**: one `gunzip` / `gzip.decompress` / `gunzipSync` call on `out/payload.gz`.
- **`deflate`**: one `gzip` / `gzip.compress` / `gzipSync` / `gzip.words` call on `out/plain.bin`, level 6 where the library has levels. The pure Bend `gzip` has no levels; `gzip.words` uses level 6.

After each timer stops, the program prints a checksum of the plain bytes: `h = h*31 + b` in wrapping u32. For `deflate`, that is the checksum of its own output gunzipped again. Expected for both: **2339964736**.

Throughput in the table is plain bytes per second (decimal MB/s). **gzip bytes** is the size of each language's `deflate` output.

Bend reads the files with `File.read_bytes` so the bytes are not UTF-8 decoded. `native.bend` turns them into `Bytes` before the timer starts, and turns the output back into a `String` for the checksum after it stops. Bend peak RSS was about **6 MB** on **64 KiB** plain and about **227 MB** on the 4 MiB run of `bench.bend`.

## Results

M4 Pro, macOS 26.6.2, arm64, 2026-09-27. Median of three runs. Times are in ms.

| variant | inflate ms | inflate MB/s | deflate ms | deflate MB/s | gzip bytes | ratio |
|---:|---:|---:|---:|---:|---:|---:|
| Bun | 6.6 | 639 | 40.7 | 103 | 1,063,003 | 3.95x |
| Node | 6.3 | 663 | 77.1 | 54 | 1,045,511 | 4.01x |
| Python | 2.9 | 1,444 | 119.6 | 35 | 1,050,286 | 3.99x |
| Bend | 217.8 | 19 | 688.0 | 6 | 1,422,023 | 2.95x |
| Bend (libz) | 4.7 | 887 | 125.8 | 33 | 1,050,286 | 3.99x |

The pure Bend ratio is lower because it writes one fixed-Huffman block with greedy matching; the others use dynamic Huffman trees and lazy matching. `Bend (libz)` and Python call the same libz at level 6, so their outputs are the same size.

Versions: Bend 2.0.31, Bun 1.3.14, Node 24.0.1, Python 3.14.6.
