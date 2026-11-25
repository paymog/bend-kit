# Bytes benchmark

This runs byte-buffer operations in two Bend layouts and five other languages.

- `packed.bend` measures the packed `Array<U32>` layout used by this package: four bytes per slot, little-endian.
- `string.bend` measures the former layout: a `String`, one `Char` list cell per byte.

## Run

```sh
python3 run.py      # 3 runs per variant, median; Python and Bend String run once
python3 run.py 5    # 5 runs
python3 run.py 1 --small  # check every supported op with small inputs
python3 run.py 3 --small --log2-size 8   # 256 B
python3 run.py 3 --small --log2-size 12  # 4 KiB
python3 run.py 3 --small --log2-size 16  # 64 KiB
python3 run.py 3 --small --log2-size 20  # 1 MiB
```

You need `bend`, `clang`, `rustc`, `go`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about a minute. It exits non-zero if any build fails, or if the variants that run at 256 MiB disagree on a checksum.

`--small` uses a 64 KiB buffer in every language, 256 random reads, and build sizes of 256 and 1024 bytes. It does not scale the String times. It checks the String checksums against the other languages for all six operations that String supports. The default inputs and table format stay unchanged.

The baseline programs and `packed.bend` accept `log2(N) reads build1 build2`. `string.bend` accepts only `log2(N)`. The runner passes these arguments before each operation starts its timer.

`--log2-size` selects the same buffer size for every variant (8 through 28). It does not scale String times. Use `--small` with it to select 256 random reads and build sizes of 256 and 1024 bytes. Without `--small`, the default read count and build sizes stay unchanged. Selected-size tables show milliseconds with six decimal places and omit ratios because a timer can report zero. These commands check all supported operations, including the extra packed sums and SWAR search. The runner compares each checksum with the corresponding baseline checksum.

## The ops

Every program times each op in-process and prints its checksum. Except for `build`, the buffer is N = 2^28 bytes (256 MiB). `bench.*` takes log2(N) as its first argument. The default is 2^28 in `packed.bend` and 2^26 in `string.bend`, since 256 MiB as a list takes more than 4 GiB. `run.py` multiplies the default `String` times by 4. All programs accept their buffer size at runtime. Checksum math is u32 and wraps.

| op | work | checksum |
|---|---|---|
| `fill` | allocate N bytes, set `b[i] = (31i + 7) & 255`, then set the last 4 bytes to `13,10,13,10` | `b[12345 % N] + b[N-1]` |
| `sum` | add up every byte | the sum |
| `find` | index of the first `\r\n\r\n` (it is at N-4) | the index |
| `slice` | copy `b[N/4+1 .. N/4+1+N/2)` into a new buffer (not word-aligned) | first + last byte |
| `concat` | append N/C new chunks, where C = min(N, 65536) bytes and chunk k is filled with `k & 255`, to an empty buffer that is not preallocated | first + last byte |
| `random` | 2^24 reads: `x = x*1664525 + 1013904223`, `idx = x >> (32 - log2 N)` | the sum |
| `equal` | compare `b` with a copy of it (the copy is made before the timer starts) | 1 |
| `build_1000000`, `build_4000000` | start empty; append bytes `i & 255` one at a time, without reserving capacity | size + last byte |

The two `build` sizes use 1,000,000 and 4,000,000 bytes, not the 256 MiB used by the other ops. Bend Array calls `Bytes.append` with a one-byte buffer each time. Bend String has no build row: `string.bend` measures construction in `fill`, not incremental append.

Each language uses its idiomatic stdlib calls: `memmem`/`memcmp` in C, `windows(4).position` in Rust, `bytes.Index`/`bytes.Equal` in Go, `Buffer.indexOf`/`Buffer.equals` in JS, and `bytes.find` in Python. There is no hand-written SIMD and no third-party code.

The reported `sum` uses the `sum_bytewise` output from `packed.bend`. It reads one byte at a time, as a `Bytes.get` caller would. The table omits the word-at-a-time `sum` output and `find_swar`, which skips words that hold no `\r`. Neither was faster in the recorded run.

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

## Size curves

Apple M4 Pro, macOS arm64, 2026-11-25. Commands are the four `--log2-size` commands above. Times are milliseconds: median of three runs, except Python and Bend String (one run). Each process measures each operation once. All supported checksums matched across languages at all four sizes. The extra packed sums and SWAR search also matched. Bend builds and runs ran one at a time.

Versions: Bend 2.0.40, Apple clang 21.0.0, rustc 1.91.0, Go 1.27.3, Bun 1.4.4, Node 24.0.1, Python 3.14.6.

These runs use 256 random reads and the two small build sizes, not the default read count or build sizes. Below 64 KiB, concat allocates one N-byte chunk. At 64 KiB it allocates one 64-KiB chunk; at 1 MiB it allocates sixteen. Fill samples byte `12345 % N`, which keeps the default sample unchanged.

### 256 B

| op | C | Rust | Go | Bun | Node | Python | Bend Array | Bend String |
|---|---|---|---|---|---|---|---|---|
| fill | 0.000000 | 0.000917 | 0.001542 | 0.029500 | 0.030500 | 0.013250 | 0.056042 | 0.128000 |
| sum | 0.000000 | 0.000042 | 0.000125 | 0.002791 | 0.003791 | 0.015125 | 0.031459 | 0.046167 |
| find | 0.001000 | 0.000125 | 0.000125 | 0.001792 | 0.006625 | 0.000625 | 0.039917 | 0.036208 |
| slice | 0.000000 | 0.000125 | 0.001167 | 0.004167 | 0.007666 | 0.001041 | 0.035750 | 0.039000 |
| concat | 0.000000 | 0.000125 | 0.000292 | 0.008000 | 0.011833 | 0.002084 | 0.031416 | 0.041208 |
| random | 0.000000 | 0.000333 | 0.000375 | 0.032666 | 0.101125 | 0.038416 | 0.031042 | n/a |
| equal | 0.000000 | 0.000041 | 0.000042 | 0.002041 | 0.001750 | 0.000458 | 0.031250 | 0.032250 |
| build_256 | 0.002000 | 0.001959 | 0.000459 | 0.026125 | 0.008791 | 0.011709 | 0.033417 | n/a |
| build_1024 | 0.001000 | 0.001125 | 0.002916 | 0.049959 | 0.018708 | 0.045292 | 0.042375 | n/a |

### 4 KiB

| op | C | Rust | Go | Bun | Node | Python | Bend Array | Bend String |
|---|---|---|---|---|---|---|---|---|
| fill | 0.000000 | 0.000875 | 0.003208 | 0.142917 | 0.113167 | 0.114000 | 0.064167 | 0.143750 |
| sum | 0.000000 | 0.000125 | 0.001375 | 0.098166 | 0.145750 | 0.213083 | 0.031750 | 0.043125 |
| find | 0.003000 | 0.001333 | 0.000541 | 0.001750 | 0.006916 | 0.003291 | 0.034750 | 0.039375 |
| slice | 0.000000 | 0.000833 | 0.001542 | 0.004041 | 0.007334 | 0.001541 | 0.034875 | 0.068000 |
| concat | 0.001000 | 0.001542 | 0.003125 | 0.010250 | 0.013292 | 0.002667 | 0.035375 | 0.087333 |
| random | 0.000000 | 0.000334 | 0.000375 | 0.017917 | 0.007833 | 0.052750 | 0.031458 | n/a |
| equal | 0.000000 | 0.000125 | 0.000125 | 0.001916 | 0.001916 | 0.000458 | 0.034625 | 0.044042 |
| build_256 | 0.002000 | 0.002625 | 0.001916 | 0.028125 | 0.007667 | 0.010959 | 0.043792 | n/a |
| build_1024 | 0.001000 | 0.001291 | 0.003417 | 0.497459 | 0.019208 | 0.032750 | 0.038791 | n/a |

### 64 KiB

| op | C | Rust | Go | Bun | Node | Python | Bend Array | Bend String |
|---|---|---|---|---|---|---|---|---|
| fill | 0.006000 | 0.007500 | 0.022500 | 0.394208 | 0.406584 | 1.927541 | 0.064041 | 0.563542 |
| sum | 0.000000 | 0.001042 | 0.018417 | 1.446041 | 0.606958 | 3.323416 | 0.049250 | 0.231250 |
| find | 0.036000 | 0.020416 | 0.003958 | 0.003625 | 0.009334 | 0.043125 | 0.077458 | 0.230750 |
| slice | 0.002000 | 0.003667 | 0.002875 | 0.006875 | 0.012667 | 0.003209 | 0.035583 | 0.790833 |
| concat | 0.004000 | 0.003708 | 0.028833 | 0.016750 | 0.022917 | 0.010625 | 0.057209 | 1.027000 |
| random | 0.000000 | 0.000292 | 0.000375 | 0.016333 | 0.008125 | 0.046583 | 0.035458 | n/a |
| equal | 0.001000 | 0.001250 | 0.001542 | 0.003208 | 0.003250 | 0.002208 | 0.037000 | 0.305042 |
| build_256 | 0.003000 | 0.002292 | 0.002250 | 0.027833 | 0.008708 | 0.015875 | 0.042667 | n/a |
| build_1024 | 0.002000 | 0.001167 | 0.002958 | 0.055209 | 0.019542 | 0.043458 | 0.038709 | n/a |

### 1 MiB

| op | C | Rust | Go | Bun | Node | Python | Bend Array | Bend String |
|---|---|---|---|---|---|---|---|---|
| fill | 0.057000 | 0.058166 | 0.359458 | 1.269708 | 1.370000 | 30.018917 | 0.173667 | 7.035417 |
| sum | 0.013000 | 0.013958 | 0.278584 | 2.741167 | 1.583459 | 48.690125 | 0.169292 | 3.285375 |
| find | 0.537000 | 0.240208 | 0.045875 | 0.026750 | 0.045417 | 0.558708 | 0.768250 | 3.195125 |
| slice | 0.030000 | 0.034375 | 0.039709 | 0.041833 | 0.019667 | 0.047459 | 0.116959 | 12.225583 |
| concat | 0.034000 | 0.057542 | 0.758209 | 0.161875 | 0.249250 | 0.143125 | 0.235791 | 16.889833 |
| random | 0.000000 | 0.000333 | 0.000500 | 0.014625 | 0.009625 | 0.066042 | 0.035500 | n/a |
| equal | 0.016000 | 0.016917 | 0.025417 | 0.022333 | 0.021292 | 0.019708 | 0.124250 | 4.229042 |
| build_256 | 0.002000 | 0.001333 | 0.002500 | 0.029792 | 0.009083 | 0.013792 | 0.039750 | n/a |
| build_1024 | 0.001000 | 0.001250 | 0.002083 | 0.009000 | 0.017958 | 0.041125 | 0.048875 | n/a |

### Limits and cost changes

A printed zero is below the timer or output resolution, not a zero-cost operation. These short runs include cold allocator and JIT costs. Bend also prints the checksum before it stops the timer. Its roughly 0.03-ms floor hides many small-buffer differences. These tables are not steady-state throughput estimates.

Bend Array sum stays near that floor through 4 KiB, then rises at 64 KiB and 1 MiB. Its find time rises from about 0.035 ms at 4 KiB to 0.077 ms at 64 KiB and 0.768 ms at 1 MiB. String slice and concat costs become clear at 64 KiB and grow further at 1 MiB. The fixed-count random and build rows do not measure work proportional to N. Do not infer linear growth or a parallel cutoff from those rows.

No parallel cutoff is selected. A cutoff needs repeated batches above the timer floor, then direct sequential and parallel measurements under both idle and loaded cores.

## Later: parallel ops

For now we accept the gap: `find` is about 20x slower, and `concat` about 4x. Every Bend op here is one sequential loop.

The idea to try later: other standard libraries close gaps like these with SIMD, and Bend can close them with fork-join instead. `Array` is a binary tree (`ALeaf{value}` / `ANode{xs, ys}`), so an op can match `ANode{xs, ys}` and run `a b = op(xs) op(ys)` on all cores. Compare against each language's standard library as it is. If Bend's parallelism beats their SIMD, that counts.

Plan:

1. The size curves above cover 256 B through 1 MiB. Measure repeated batches before comparing parallel variants. HTTP headers are small, and on small buffers forking can cost more than it saves.
2. Go parallel automatically once a buffer passes a size cutoff. Take the cutoff from those size curves, and stay sequential below it.
3. Parallelize `fill`, `sum`, `find`, and `equal`. `find` has to catch a match that spans the split: each half reports its first and last 3 bytes, or the halves overlap by 3 bytes. Try `Array.join` for `concat`.

Keep in mind that parallelism borrows idle cores, while SIMD speeds up one core. On a loaded server every core is already busy, so the cutoff should be conservative.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- Bend `concat` and `find_swar` vary up to 2x between runs. Rerun before you trust a small change.
- The byte-at-a-time `sum` beats the word-at-a-time one, even on `--threads 1`. The likely cause is clang optimizing the C that Bend emits for the byte loop better. That is not confirmed.
- These are micro-benchmarks on one machine. They measure primitives, not an HTTP parser.
