# Zlib benchmark

This times `gunzip` on one fixed gzip member and `gzip` on its plain text, in Bend and in JavaScript (Bun and Node) and Python. Bend runs twice: `bench.bend` uses the pure `gunzip` and `gzip`, and `native.bend` uses `libz.inflate` and `libz.gzip`.

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
- **`deflate`**: one `gzip` / `gzip.compress` / `gzipSync` / `libz.gzip` call on `out/plain.bin`, level 6 where the library has levels. The pure Bend `gzip` has no levels; `libz.gzip` uses level 6.

After each timer stops, the program prints a checksum of the plain bytes: `h = h*31 + b` in wrapping u32. For `deflate`, that is the checksum of its own output gunzipped again. Expected for both: **2339964736**.

Throughput in the table is plain bytes per second (decimal MB/s). **gzip bytes** is the size of each language's `deflate` output.

Bend reads the files with `File.read_bytes` so the bytes are not UTF-8 decoded. Both Bend programs turn them into `Bytes` before the timer starts, and turn the output back into a `String` for the checksum after it stops.

## Results

M4 Pro, macOS arm64, 2026-11-24. Median of three runs. Times are in ms.

| variant | inflate ms | inflate MB/s | deflate ms | deflate MB/s | gzip bytes | ratio |
|---:|---:|---:|---:|---:|---:|---:|
| Bun | 7.1 | 591 | 40.2 | 104 | 1,063,003 | 3.95x |
| Node | 6.3 | 668 | 75.4 | 56 | 1,045,511 | 4.01x |
| Python | 2.9 | 1,441 | 117.2 | 36 | 1,050,286 | 3.99x |
| Bend | 96.3 | 44 | 474.7 | 9 | 1,083,353 | 3.87x |
| Bend (libz) | 3.9 | 1,069 | 118.7 | 35 | 1,050,286 | 3.99x |

The pure encoder uses lazy matching and dynamic Huffman trees in 32 KiB blocks. It keeps fixed codes when they cost fewer bits. Dynamic headers trim trailing unused lengths and encode runs with symbols 16–18. `run.py` decodes the first output header and reports its exact bit count, including the block prefix, alphabet lengths, run symbols, and extra bits.

The first block header costs **446 bits**, down from **1,338 bits**. Output falls from **1,097,622** to **1,083,353 bytes** (14,269 bytes, 1.3%). The ratio rises from **3.82x** to **3.87x**. Output is 3.1% larger than libz level 6. The previous Bend 2.0.40 run took 466.9 ms; this run takes 474.7 ms. These are separate measurements, not an isolated speed comparison.

The 64 KiB smoke run passes. Pure Bend emits 19,032 bytes in 7.6 ms, versus Python's 18,870 bytes in 1.6 ms. Both full-run checksums are 2339964736, and system `gzip -d` accepts `out/bend.gz` and `out/native.gz`.

Versions: Bend 2.0.40, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Python `gzip.compress(..., compresslevel=6)` and Bend's native wrapper both use libz level 6.
