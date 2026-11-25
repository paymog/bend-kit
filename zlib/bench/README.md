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

M4 Pro, macOS arm64, 2026-11-25. Median of five runs on Bend 2.0.40.

| variant | inflate ms | inflate MB/s | deflate ms | deflate MB/s | gzip bytes | ratio |
|---:|---:|---:|---:|---:|---:|---:|
| Bun | 7.0 | 598 | 39.6 | 106 | 1,063,003 | 3.95x |
| Node | 6.3 | 663 | 74.5 | 56 | 1,045,511 | 4.01x |
| Python | 2.8 | 1,496 | 115.6 | 36 | 1,050,286 | 3.99x |
| Bend | 113.2 | 37 | 251.2 | 17 | 1,083,353 | 3.87x |
| Bend (libz) | 3.8 | 1,107 | 116.9 | 36 | 1,050,286 | 3.99x |

The pure encoder uses lazy matching and dynamic Huffman trees in 32 KiB blocks. It keeps fixed codes when they cost fewer bits. Dynamic headers trim trailing unused lengths and encode runs with symbols 16–18. `run.py` decodes the first output header and reports its exact bit count, including the block prefix, alphabet lengths, run symbols, and extra bits.

The first block header costs **446 bits**. Output is **1,083,353 bytes**, 3.1% larger than libz level 6.

### Lazy-match comparison

The before and after runs use the same compiler, corpus, and command: `python3 run.py 5`. Before: commit `16c351e`, Bend 2.0.40, **475.1 ms**. After: Bend 2.0.40, **457.8 ms**, **3.6% less time**. `cmp out/before.gz out/bend.gz` passes: output is byte-for-byte unchanged.

A native `sample` profile (`sample <pid> 2 1 -file out/before.sample`) shows tokenization in `zlib_blocks_go`, including its inlined match searches, and 170 samples in `es_emit`. Sorted-tree insertion appears in only three samples. This is a sampling profile of the whole benchmark, not isolated stage timing. The small tree alphabet does not justify a new tree data structure in this change.

When lazy lookahead wins, the encoder now carries its length and distance into the next step. That step inserts the position into its hash chain but does not search the same candidates again. It still performs the next lazy comparison, so token choice does not change.

The 64 KiB smoke run passes. Pure Bend emits 19,032 bytes in 7.7 ms. Both full-run checksums are 2339964736, and system `gzip -d` accepts `out/bend.gz` and `out/native.gz`.

### Token-symbol comparison

Before changing the mapper, `symbols.bend` isolated the two `cx.go` list scans plus `es.copy` from `es.copy` with preselected descriptors. Both loops construct and consume 1,048,576 tokens. Lengths cycle through 3–258 and distances through 1–32768. This is a uniform-domain microbenchmark, not the corpus's token distribution.

On Bend 2.0.40, five native runs gave median **331.95 ms** for scans plus construction and **0.159 ms** for construction with preselected descriptors. The compiler can inline and eliminate temporary tokens in this loop. These figures isolate mapping work; they do not measure retained-token allocation in the full encoder.

The replacement uses the power-of-two groups in RFC 1951, with direct cases for lengths 3–10 and 258 and distances 1–4. `U32.log2` gives the group exponent. No lookup array or per-token lists are needed. The same mapping loop now takes **1.959 ms**; its checksum stays **3210001344**. The construction-only checksum is **402653184**. The benchmark retains the old scan as `legacy` for comparison:

```sh
bend symbols.bend -o out/symbols
for i in 1 2 3 4 5; do out/symbols; done
```

On the fixed 4 MiB corpus, `python3 run.py 5` measured **458.2 ms before** (commit `36cfda9`) and **251.2 ms after**, both with Bend 2.0.40: **45.2% less encoder time**. `cmp out/before.gz out/bend.gz` passes. Output remains **1,083,353 bytes**, and system `gzip -d` restores the input. Both full-run checksums are **2339964736**. The 64 KiB smoke run passes at **3.9 ms** with **19,032 output bytes**.

`check.bend` compares every legal length (3–258) and distance (1–32768), including both sides of every symbol boundary, against the previous table scan. Match selection and Huffman planning are unchanged.

Versions: Bend 2.0.40, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Python `gzip.compress(..., compresslevel=6)` and Bend's native wrapper both use libz level 6.
