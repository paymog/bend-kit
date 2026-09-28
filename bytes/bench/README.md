# Bytes benchmark

How fast could a Bend `Bytes` type be? This runs byte-buffer operations in two Bend layouts and five other languages.

- `packed.bend` is the candidate: `Array<U32>`, 4 bytes per slot, little-endian.
- `string.bend` is what bend-kit uses today: a `String`, one `Char` list cell per byte.

## Run

```sh
python3 run.py      # 3 runs per variant, median; Python and Bend String run once
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `rustc`, `go`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about a minute. It exits non-zero if any build fails, or if the variants that run at 256 MiB disagree on a checksum.

## The ops

Every program times each op in-process and prints its checksum. Except for `build`, the buffer is N = 2^28 bytes (256 MiB). `bench.*` takes log2(N) as its first argument. The Bend files have N built in: 2^28 in `packed.bend`, and 2^26 in `string.bend`, since 256 MiB as a list takes more than 4 GiB. `run.py` multiplies the `String` times by 4. Checksum math is u32 and wraps.

| op | work | checksum |
|---|---|---|
| `fill` | allocate N bytes, set `b[i] = (31i + 7) & 255`, then set the last 4 bytes to `13,10,13,10` | `b[12345] + b[N-1]` |
| `sum` | add up every byte | the sum |
| `find` | index of the first `\r\n\r\n` (it is at N-4) | the index |
| `slice` | copy `b[N/4+1 .. N/4+1+N/2)` into a new buffer (not word-aligned) | first + last byte |
| `concat` | append N/65536 new 64 KiB chunks (chunk k is filled with `k & 255`) to an empty buffer that is not preallocated | first + last byte |
| `random` | 2^24 reads: `x = x*1664525 + 1013904223`, `idx = x >> (32 - log2 N)` | the sum |
| `equal` | compare `b` with a copy of it (the copy is made before the timer starts) | 1 |
| `build_1000000`, `build_4000000` | start empty; append bytes `i & 255` one at a time, without reserving capacity | size + last byte |

The two `build` sizes use 1,000,000 and 4,000,000 bytes, not the 256 MiB used by the other ops. Bend Array calls `Bytes.append` with a one-byte buffer each time. Bend String has no build row: `string.bend` measures construction in `fill`, not incremental append.

Each language uses its idiomatic stdlib calls: `memmem`/`memcmp` in C, `windows(4).position` in Rust, `bytes.Index`/`bytes.Equal` in Go, `Buffer.indexOf`/`Buffer.equals` in JS, and `bytes.find` in Python. There is no hand-written SIMD and no third-party code.

In Bend, `sum` goes through the per-byte `byte(a, i)` read, which is what a `Bytes.get` caller would pay. `packed.bend` also prints two more ops that the table leaves out. `sum` reads a word at a time, and is slower (see below). `find_swar` skips words that hold no `\r`, but it does not beat the byte loop.

## Results

M4 Pro, macOS, 2026-09-27, from `python3 run.py`. Median of three runs, except Python and Bend String (one run). Every variant that runs at 256 MiB printed the same checksums. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

Versions: Bend 2.0.31, Apple clang 17.0.0, rustc 1.91.0, Go 1.27.1, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

| op | C | Rust | Go | Bun | Node | Python | Bend Array | Bend String |
|---|---|---|---|---|---|---|---|---|
| fill | 15.6 (1.1x) | 14.0 (1.0x) | 93.1 (6.6x) | 112.3 (8.0x) | 154.3 (11.0x) | 11,599.9 (827.1x) | 43.4 (3.1x) | 2,485.9 (177.3x) |
| sum | 10.4 (1.4x) | 7.4 (1.0x) | 75.8 (10.3x) | 518.9 (70.4x) | 1,243.3 (168.7x) | 14,638.8 (1986.1x) | 34.8 (4.7x) | 1,124.1 (152.5x) |
| find | 146.3 (15.6x) | 70.1 (7.5x) | 12.4 (1.3x) | 11.8 (1.3x) | 9.4 (1.0x) | 140.6 (15.0x) | 188.1 (20.0x) | 1,109.1 (118.1x) |
| slice | 7.4 (1.0x) | 7.6 (1.0x) | 10.6 (1.4x) | 8.1 (1.1x) | 7.7 (1.0x) | 9.3 (1.3x) | 18.5 (2.5x) | 3,829.3 (517.1x) |
| concat | 13.4 (1.0x) | 13.2 (1.0x) | 155.6 (11.8x) | 34.6 (2.6x) | 39.2 (3.0x) | 19.3 (1.5x) | 58.6 (4.4x) | 5,845.1 (441.5x) |
| random | 57.5 (1.0x) | 57.3 (1.0x) | 71.5 (1.2x) | 999.0 (17.4x) | 103.7 (1.8x) | 5,295.1 (92.4x) | 58.5 (1.0x) | n/a |
| equal | 5.1 (1.0x) | 9.8 (1.9x) | 9.4 (1.9x) | 9.8 (1.9x) | 10.1 (2.0x) | 5.0 (1.0x) | 23.5 (4.7x) | 6,082.3 (1211.5x) |
| build_1000000 | 0.3 (1.0x) | 0.5 (1.6x) | 0.4 (1.5x) | 5.0 (17.9x) | 3.1 (11.2x) | 35.6 (127.5x) | 9.9 (35.5x) | n/a |
| build_4000000 | 1.3 (1.0x) | 1.9 (1.5x) | 1.4 (1.1x) | 18.2 (14.2x) | 8.8 (6.9x) | 144.7 (113.0x) | 41.2 (32.2x) | n/a |
| build (4M / 1M) | 4.6x | 4.2x | 3.5x | 3.6x | 2.8x | 4.1x | 4.2x | n/a |
| geomean vs fastest | 1.4x | 1.5x | 2.6x | 6.4x | 4.9x | 34.0x | 6.4x | 309.8x |

`String` has no `random` row, because every read walks the list and is O(n). It has no `build` rows either (see above). Its geomean covers the other six ops.

Four times as many one-byte appends took Bend Array 4.2 times as long. This is consistent with linear growth; the two sizes do not prove an asymptotic bound.

## Reading it

- A packed `Array` is about 6 to 260 times faster than `String`, and it uses 1/16 of the memory.
- Over the seven buffer ops, without the `build` rows, the geomean is 4.0x for Bend Array, 4.1x for Node, and 3.2x for Go. Random reads match C. The one-byte `build` appends are 32 to 36 times slower than C, which pulls the full geomean to 6.4x.
- `find` is the weak spot. Go and JS hand it to SIMD `memchr`/`memmem`, and a Bend loop cannot call host code outside `IO`. Closing that gap probably needs native `Array` primitives in Bend itself. The C and Python columns are slow here for a different reason: macOS `memmem` and CPython's search do not use SIMD for this pattern.
- `concat` keeps the chunks in a list and copies them once at the end. `Array.join` might make that O(1) per chunk; it has not been tried.

## Later: parallel ops

For now we accept the gap: `find` is about 20x slower, and `concat` about 4x. Every Bend op here is one sequential loop.

The idea to try later: other standard libraries close gaps like these with SIMD, and Bend can close them with fork-join instead. `Array` is a binary tree (`ALeaf{value}` / `ANode{xs, ys}`), so an op can match `ANode{xs, ys}` and run `a b = op(xs) op(ys)` on all cores. Compare against each language's standard library as it is. If Bend's parallelism beats their SIMD, that counts.

Plan:

1. Run every op at several sizes, say 256 B, 4 KiB, 64 KiB, 1 MiB, and 256 MiB. HTTP headers are small, and on small buffers forking costs more than it saves.
2. Go parallel automatically once a buffer passes a size cutoff. Take the cutoff from those size curves, and stay sequential below it.
3. Parallelize `fill`, `sum`, `find`, and `equal`. `find` has to catch a match that spans the split: each half reports its first and last 3 bytes, or the halves overlap by 3 bytes. Try `Array.join` for `concat`.

Keep in mind that parallelism borrows idle cores, while SIMD speeds up one core. On a loaded server every core is already busy, so the cutoff should be conservative.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- Bend `concat` and `find_swar` vary up to 2x between runs. Rerun before you trust a small change.
- The byte-at-a-time `sum` beats the word-at-a-time one, even on `--threads 1`. The likely cause is clang optimizing the C that Bend emits for the byte loop better. That is not confirmed.
- These are micro-benchmarks on one machine. They measure primitives, not an HTTP parser.
