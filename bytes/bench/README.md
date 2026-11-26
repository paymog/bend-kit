# Bytes benchmark

This runs byte-buffer operations in two Bend layouts and five other languages.

- `packed.bend` measures the packed `Array<U32>` layout used by this package: four bytes per slot, little-endian.
- `string.bend` measures the former layout: a `String`, one `Char` list cell per byte.

## Run

```sh
python3 run.py      # 3 runs per variant, median; Python and Bend String run once
python3 run.py 5    # 5 runs
python3 run.py 1 --small  # check every supported op with small inputs
python3 run.py 3 --small --log2-size 8 --batch   # 256 B
python3 run.py 3 --small --log2-size 12 --batch  # 4 KiB
python3 run.py 3 --small --log2-size 16 --batch  # 64 KiB
python3 run.py 3 --small --log2-size 20 --batch  # 1 MiB
```

You need `bend`, `clang`, `rustc`, `go`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about a minute. It exits non-zero if any build fails, or if the variants that run at 256 MiB disagree on a checksum.

`--small` uses a 64 KiB buffer in every language, 256 random reads, and build sizes of 256 and 1024 bytes. It does not scale the String times. It checks the String checksums against the other languages for all six operations that String supports. The default inputs and table format stay unchanged.

The baseline programs and `packed.bend` accept `log2(N) reads build1 build2`. `string.bend` accepts only `log2(N)`. The runner passes these arguments before each operation starts its timer.

`--log2-size` selects the same buffer size for every variant (8 through 28). It does not scale String times. Use `--small` with it to select 256 random reads and build sizes of 256 and 1024 bytes. Without `--small`, the default read count and build sizes stay unchanged. Selected-size tables show milliseconds with six decimal places and omit ratios because a timer can report zero. These commands check all supported operations, including the extra packed sums and SWAR search. The runner compares each checksum with the corresponding baseline checksum.

`--batch` runs 32 warmup operations before each timed batch. It starts with 32 measured operations, then raises the count until every batch takes at least 5 ms. Calibration targets 10 ms and discards shorter batches. Each variant uses one count for all its operations. It repeats Python and Bend String as often as the other variants. The output records the count, median total batch time, median time per operation, and the minimum and maximum time per operation. This mode can take tens of minutes because the fastest operation sets the count for the whole variant.

Each program prints `op batch_ms last_checksum count checksum_sum` as tab-separated fields after the timer stops. The checksum sum adds every measured result with u32 wraparound. The runner checks it against `last_checksum * count`, then compares checksums across runs and languages. C uses compiler barriers and Rust uses `black_box` to keep repeated work in the timed loop. There is no output inside a timed region. The equality copy is made before warmup and timing. Allocation operations create a fresh result each time. They do not retain a batch of buffers, so reclamation can occur inside the timed region. Read operations reuse the input buffer.

The runner sets `BYTES_BENCH_COUNT` and `BYTES_BENCH_WARMUP` for each process. When these variables are absent, a program runs each operation once without warmup. The default buffer sizes, read count, and build sizes stay unchanged.

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

The default table reports `sum_bytewise` from `packed.bend` as `sum`. It reads one byte at a time, as a `Bytes.get` caller would. Batch tables also show the word-at-a-time `sum`, its repeated `sum_again` row, and `find_swar`, which skips words that hold no `\r`.

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

Apple M4 Pro, macOS 26.7.2 arm64, 2026-11-26. Commands are the four `--batch` commands above. Every variant ran three times. All supported checksums and batch checksum sums matched at all four sizes. Bend builds and runs ran one at a time.

Versions: Bend 2.0.40, Apple clang 21.0.0, rustc 1.91.0, Go 1.27.3, Bun 1.4.4, Node 24.0.1, Python 3.14.6.

These runs use 256 random reads and build sizes of 256 and 1024 bytes. They do not change the default workload. Below 64 KiB, concat allocates one N-byte chunk. At 64 KiB it allocates one 64-KiB chunk; at 1 MiB it allocates sixteen. Each row records the measured operation count, median total batch time, median time per operation, and its minimum and maximum across the three runs. All retained batches took at least 5 ms. The extra packed sums and SWAR search are shown without renaming.

### 256 B

| variant | op | count | batch ms (median) | ms/op (median) | ms/op (min–max) |
|---|---|---:|---:|---:|---:|
| C | fill | 6291456 | 79.123000 | 0.000012576 | 0.000012390–0.000013186 |
| C | sum | 6291456 | 14.229000 | 0.000002262 | 0.000002239–0.000002291 |
| C | find | 6291456 | 931.548000 | 0.000148066 | 0.000146879–0.000150430 |
| C | slice | 6291456 | 76.834000 | 0.000012212 | 0.000012076–0.000012229 |
| C | concat | 6291456 | 84.375000 | 0.000013411 | 0.000013277–0.000013505 |
| C | random | 6291456 | 1484.173000 | 0.000235903 | 0.000235601–0.000236091 |
| C | equal | 6291456 | 39.090000 | 0.000006213 | 0.000006150–0.000007142 |
| C | build_256 | 6291456 | 1590.975000 | 0.000252879 | 0.000251959–0.000255237 |
| C | build_1024 | 6291456 | 3513.900000 | 0.000558519 | 0.000556426–0.000560527 |
| Rust | fill | 6291456 | 114.724750 | 0.000018235 | 0.000017506–0.000018413 |
| Rust | sum | 6291456 | 11.214334 | 0.000001782 | 0.000001767–0.000001794 |
| Rust | find | 6291456 | 470.679541 | 0.000074812 | 0.000074040–0.000075230 |
| Rust | slice | 6291456 | 86.603000 | 0.000013765 | 0.000013524–0.000013821 |
| Rust | concat | 6291456 | 101.046958 | 0.000016061 | 0.000015826–0.000016066 |
| Rust | random | 6291456 | 1527.714292 | 0.000242824 | 0.000242333–0.000243427 |
| Rust | equal | 6291456 | 35.412750 | 0.000005629 | 0.000005488–0.000005726 |
| Rust | build_256 | 6291456 | 1332.518416 | 0.000211798 | 0.000210998–0.000215728 |
| Rust | build_1024 | 6291456 | 3547.865292 | 0.000563918 | 0.000558518–0.000565654 |
| Go | fill | 2097152 | 327.162834 | 0.000156003 | 0.000155774–0.000157367 |
| Go | sum | 2097152 | 150.199125 | 0.000071621 | 0.000071495–0.000072249 |
| Go | find | 2097152 | 24.243125 | 0.000011560 | 0.000011544–0.000011608 |
| Go | slice | 2097152 | 38.289084 | 0.000018258 | 0.000017341–0.000018758 |
| Go | concat | 2097152 | 258.187041 | 0.000123113 | 0.000120937–0.000123753 |
| Go | random | 2097152 | 554.169084 | 0.000264248 | 0.000262805–0.000264864 |
| Go | equal | 2097152 | 10.046333 | 0.000004790 | 0.000004747–0.000004809 |
| Go | build_256 | 2097152 | 276.182375 | 0.000131694 | 0.000130432–0.000134138 |
| Go | build_1024 | 2097152 | 1221.560834 | 0.000582486 | 0.000575292–0.000588555 |
| Bun | fill | 917504 | 96.249000 | 0.000104903 | 0.000104657–0.000105783 |
| Bun | sum | 917504 | 72.621083 | 0.000079151 | 0.000079113–0.000080368 |
| Bun | find | 917504 | 17.076416 | 0.000018612 | 0.000018144–0.000018893 |
| Bun | slice | 917504 | 36.994375 | 0.000040321 | 0.000040243–0.000040569 |
| Bun | concat | 917504 | 49.258541 | 0.000053688 | 0.000052687–0.000054755 |
| Bun | random | 917504 | 345.238334 | 0.000376280 | 0.000375694–0.000376578 |
| Bun | equal | 917504 | 11.390917 | 0.000012415 | 0.000011994–0.000012441 |
| Bun | build_256 | 917504 | 262.463167 | 0.000286062 | 0.000285644–0.000289567 |
| Bun | build_1024 | 917504 | 812.201000 | 0.000885229 | 0.000873330–0.000889458 |
| Node | fill | 393216 | 79.665666 | 0.000202600 | 0.000202130–0.000206302 |
| Node | sum | 393216 | 32.352167 | 0.000082276 | 0.000078845–0.000084438 |
| Node | find | 393216 | 16.186042 | 0.000041163 | 0.000040747–0.000041363 |
| Node | slice | 393216 | 26.664667 | 0.000067812 | 0.000067767–0.000067902 |
| Node | concat | 393216 | 76.732791 | 0.000195142 | 0.000194459–0.000202977 |
| Node | random | 393216 | 102.120000 | 0.000259705 | 0.000259218–0.000260667 |
| Node | equal | 393216 | 10.490125 | 0.000026678 | 0.000026499–0.000027205 |
| Node | build_256 | 393216 | 337.744625 | 0.000858929 | 0.000855975–0.000859269 |
| Node | build_1024 | 393216 | 778.167041 | 0.001978981 | 0.001972473–0.001990995 |
| Python | fill | 131072 | 894.979084 | 0.006828149 | 0.006817819–0.006837082 |
| Python | sum | 131072 | 713.099166 | 0.005440515 | 0.005417064–0.005477323 |
| Python | find | 131072 | 22.627250 | 0.000172632 | 0.000168538–0.000174114 |
| Python | slice | 131072 | 21.163584 | 0.000161465 | 0.000160608–0.000163212 |
| Python | concat | 131072 | 30.286750 | 0.000231070 | 0.000227977–0.000231122 |
| Python | random | 131072 | 3655.229167 | 0.027887185 | 0.027600115–0.028226222 |
| Python | equal | 131072 | 8.099167 | 0.000061792 | 0.000061099–0.000061899 |
| Python | build_256 | 131072 | 590.983333 | 0.004508845 | 0.004496304–0.004541621 |
| Python | build_1024 | 131072 | 2592.922000 | 0.019782425 | 0.019761791–0.019919565 |
| Bend Array | fill | 786432 | 16.058542 | 0.000020419 | 0.000020399–0.000020449 |
| Bend Array | sum | 786432 | 37.099625 | 0.000047175 | 0.000047049–0.000047275 |
| Bend Array | sum_bytewise | 786432 | 52.222083 | 0.000066404 | 0.000066128–0.000066559 |
| Bend Array | sum_again | 786432 | 37.740584 | 0.000047990 | 0.000047683–0.000048794 |
| Bend Array | find | 786432 | 130.739250 | 0.000166244 | 0.000165468–0.000166264 |
| Bend Array | find_swar | 786432 | 143.875250 | 0.000182947 | 0.000182661–0.000183183 |
| Bend Array | slice | 786432 | 10.379750 | 0.000013199 | 0.000013104–0.000013497 |
| Bend Array | concat | 786432 | 27.786250 | 0.000035332 | 0.000034994–0.000035872 |
| Bend Array | random | 786432 | 204.342709 | 0.000259835 | 0.000257339–0.000262073 |
| Bend Array | equal | 786432 | 16.296125 | 0.000020722 | 0.000020635–0.000023067 |
| Bend Array | build_256 | 786432 | 1214.483542 | 0.001544296 | 0.001534465–0.001544685 |
| Bend Array | build_1024 | 786432 | 5300.397083 | 0.006739803 | 0.006651693–0.006742857 |
| Bend String | fill | 6144 | 22.117584 | 0.003599867 | 0.003512458–0.003609999 |
| Bend String | sum | 6144 | 9.446417 | 0.001537503 | 0.001531040–0.001574714 |
| Bend String | find | 6144 | 9.654459 | 0.001571364 | 0.001541599–0.001574748 |
| Bend String | slice | 6144 | 19.433916 | 0.003163072 | 0.003124776–0.003224413 |
| Bend String | concat | 6144 | 34.510000 | 0.005616862 | 0.005520840–0.005747023 |
| Bend String | equal | 6144 | 11.924250 | 0.001940796 | 0.001939134–0.001960225 |

### 4 KiB

| variant | op | count | batch ms (median) | ms/op (median) | ms/op (min–max) |
|---|---|---:|---:|---:|---:|
| C | fill | 393216 | 18.930000 | 0.000048141 | 0.000047071–0.000048375 |
| C | sum | 393216 | 13.008000 | 0.000033081 | 0.000032847–0.000033704 |
| C | find | 393216 | 853.166000 | 0.002169713 | 0.002168465–0.002174754 |
| C | slice | 393216 | 13.576000 | 0.000034526 | 0.000034144–0.000037079 |
| C | concat | 393216 | 19.285000 | 0.000049044 | 0.000048948–0.000051147 |
| C | random | 393216 | 93.321000 | 0.000237328 | 0.000235107–0.000238202 |
| C | equal | 393216 | 32.386000 | 0.000082362 | 0.000081645–0.000082654 |
| C | build_256 | 393216 | 101.984000 | 0.000259359 | 0.000256592–0.000260040 |
| C | build_1024 | 393216 | 223.957000 | 0.000569552 | 0.000569173–0.000570168 |
| Rust | fill | 393216 | 33.229292 | 0.000084506 | 0.000082695–0.000086122 |
| Rust | sum | 393216 | 13.603709 | 0.000034596 | 0.000034288–0.000035127 |
| Rust | find | 393216 | 403.182000 | 0.001025345 | 0.001023533–0.001028783 |
| Rust | slice | 393216 | 13.949541 | 0.000035476 | 0.000035367–0.000036058 |
| Rust | concat | 393216 | 19.675250 | 0.000050037 | 0.000049200–0.000051086 |
| Rust | random | 393216 | 95.555833 | 0.000243011 | 0.000240541–0.000244598 |
| Rust | equal | 393216 | 32.200792 | 0.000081891 | 0.000081773–0.000082868 |
| Rust | build_256 | 393216 | 84.082458 | 0.000213833 | 0.000212127–0.000215237 |
| Rust | build_1024 | 393216 | 217.617125 | 0.000553429 | 0.000552517–0.000557842 |
| Go | fill | 131072 | 295.273375 | 0.002252757 | 0.002240890–0.002260294 |
| Go | sum | 131072 | 133.476458 | 0.001018345 | 0.001010113–0.001032272 |
| Go | find | 131072 | 24.119083 | 0.000184014 | 0.000181444–0.000184527 |
| Go | slice | 131072 | 23.687750 | 0.000180723 | 0.000178605–0.000199404 |
| Go | concat | 131072 | 202.164083 | 0.001542390 | 0.001524096–0.001592560 |
| Go | random | 131072 | 34.649959 | 0.000264358 | 0.000262142–0.000267845 |
| Go | equal | 131072 | 6.606084 | 0.000050400 | 0.000049434–0.000050577 |
| Go | build_256 | 131072 | 17.736916 | 0.000135322 | 0.000134147–0.000137096 |
| Go | build_1024 | 131072 | 74.308708 | 0.000566930 | 0.000565770–0.000593913 |
| Bun | fill | 114688 | 167.836416 | 0.001463417 | 0.001458825–0.001476176 |
| Bun | sum | 114688 | 138.443209 | 0.001207129 | 0.001132711–0.001271703 |
| Bun | find | 114688 | 13.408459 | 0.000116912 | 0.000103802–0.000118717 |
| Bun | slice | 114688 | 17.197084 | 0.000149947 | 0.000148649–0.000150287 |
| Bun | concat | 114688 | 46.829417 | 0.000408320 | 0.000403913–0.000416668 |
| Bun | random | 114688 | 43.860375 | 0.000382432 | 0.000380207–0.000383638 |
| Bun | equal | 114688 | 10.184791 | 0.000088804 | 0.000086190–0.000089730 |
| Bun | build_256 | 114688 | 34.049500 | 0.000296888 | 0.000293546–0.000307202 |
| Bun | build_1024 | 114688 | 100.548292 | 0.000876712 | 0.000869683–0.000892797 |
| Node | fill | 81920 | 138.509750 | 0.001690793 | 0.001674813–0.001739326 |
| Node | sum | 81920 | 109.881291 | 0.001341324 | 0.001323507–0.001386010 |
| Node | find | 81920 | 18.092083 | 0.000220851 | 0.000213374–0.000222521 |
| Node | slice | 81920 | 14.285416 | 0.000174383 | 0.000174279–0.000175478 |
| Node | concat | 81920 | 51.044750 | 0.000623105 | 0.000589334–0.000629805 |
| Node | random | 81920 | 21.548334 | 0.000263041 | 0.000261678–0.000265202 |
| Node | equal | 81920 | 8.914625 | 0.000108821 | 0.000108039–0.000109219 |
| Node | build_256 | 81920 | 72.120667 | 0.000880379 | 0.000877012–0.000889362 |
| Node | build_1024 | 81920 | 163.832583 | 0.001999909 | 0.001999185–0.002053464 |
| Python | fill | 73728 | 8790.407208 | 0.119227528 | 0.119179673–0.119341350 |
| Python | sum | 73728 | 6143.486708 | 0.083326371 | 0.082698835–0.083626161 |
| Python | find | 73728 | 155.872209 | 0.002114152 | 0.002107519–0.002122940 |
| Python | slice | 73728 | 17.784167 | 0.000241213 | 0.000237234–0.000244783 |
| Python | concat | 73728 | 25.741208 | 0.000349137 | 0.000348208–0.000349892 |
| Python | random | 73728 | 2070.934875 | 0.028088852 | 0.027753383–0.028092057 |
| Python | equal | 73728 | 10.492334 | 0.000142311 | 0.000140738–0.000143277 |
| Python | build_256 | 73728 | 334.016500 | 0.004530389 | 0.004503196–0.004535801 |
| Python | build_1024 | 73728 | 1463.252042 | 0.019846626 | 0.019791268–0.019956620 |
| Bend Array | fill | 57344 | 19.700667 | 0.000343552 | 0.000341893–0.000344128 |
| Bend Array | sum | 57344 | 57.418875 | 0.001001306 | 0.000992795–0.001005810 |
| Bend Array | sum_bytewise | 57344 | 57.474667 | 0.001002279 | 0.000999268–0.001004769 |
| Bend Array | sum_again | 57344 | 57.222916 | 0.000997888 | 0.000990545–0.001001748 |
| Bend Array | find | 57344 | 158.829125 | 0.002769760 | 0.002753717–0.002784380 |
| Bend Array | find_swar | 57344 | 173.973083 | 0.003033850 | 0.003031211–0.003034357 |
| Bend Array | slice | 57344 | 10.848167 | 0.000189177 | 0.000188257–0.000190827 |
| Bend Array | concat | 57344 | 21.620584 | 0.000377033 | 0.000373744–0.000378042 |
| Bend Array | random | 57344 | 15.185375 | 0.000264812 | 0.000260073–0.000269071 |
| Bend Array | equal | 57344 | 20.095000 | 0.000350429 | 0.000346660–0.000351812 |
| Bend Array | build_256 | 57344 | 89.823125 | 0.001566391 | 0.001532680–0.001593773 |
| Bend Array | build_1024 | 57344 | 382.113083 | 0.006663523 | 0.006647168–0.006757045 |
| Bend String | fill | 384 | 12.658958 | 0.032966036 | 0.032816841–0.033549044 |
| Bend String | sum | 384 | 9.949292 | 0.025909615 | 0.024836263–0.026010633 |
| Bend String | find | 384 | 9.895500 | 0.025769531 | 0.025628690–0.025936740 |
| Bend String | slice | 384 | 15.074417 | 0.039256294 | 0.038759656–0.039365234 |
| Bend String | concat | 384 | 21.504750 | 0.056001953 | 0.055800456–0.056322591 |
| Bend String | equal | 384 | 12.598625 | 0.032808919 | 0.032597982–0.032902018 |

### 64 KiB

| variant | op | count | batch ms (median) | ms/op (median) | ms/op (min–max) |
|---|---|---:|---:|---:|---:|
| C | fill | 49152 | 37.639000 | 0.000765767 | 0.000743123–0.000786499 |
| C | sum | 49152 | 36.092000 | 0.000734294 | 0.000734273–0.000737895 |
| C | find | 49152 | 1697.646000 | 0.034538696 | 0.034445333–0.034550578 |
| C | slice | 49152 | 16.172000 | 0.000329020 | 0.000320943–0.000331685 |
| C | concat | 49152 | 18.263000 | 0.000371562 | 0.000368123–0.000371745 |
| C | random | 49152 | 11.710000 | 0.000238241 | 0.000234741–0.000241597 |
| C | equal | 49152 | 65.934000 | 0.001341431 | 0.001146647–0.001342082 |
| C | build_256 | 49152 | 14.099000 | 0.000286845 | 0.000286438–0.000289124 |
| C | build_1024 | 49152 | 29.554000 | 0.000601278 | 0.000596252–0.000602254 |
| Rust | fill | 40960 | 53.448916 | 0.001304905 | 0.001299314–0.001543568 |
| Rust | sum | 40960 | 30.227041 | 0.000737965 | 0.000728216–0.000739684 |
| Rust | find | 40960 | 669.908833 | 0.016355196 | 0.016342327–0.016422016 |
| Rust | slice | 40960 | 13.427208 | 0.000327813 | 0.000326728–0.000329555 |
| Rust | concat | 40960 | 15.265292 | 0.000372688 | 0.000372440–0.000388855 |
| Rust | random | 40960 | 10.216417 | 0.000249424 | 0.000245120–0.000250264 |
| Rust | equal | 40960 | 47.291584 | 0.001154580 | 0.001142122–0.001342915 |
| Rust | build_256 | 40960 | 9.350750 | 0.000228290 | 0.000227946–0.000233628 |
| Rust | build_1024 | 40960 | 23.194125 | 0.000566263 | 0.000554225–0.000569854 |
| Go | fill | 73728 | 2579.794084 | 0.034990697 | 0.034848493–0.035060432 |
| Go | sum | 73728 | 1196.331583 | 0.016226286 | 0.016208164–0.016348009 |
| Go | find | 73728 | 203.607666 | 0.002761606 | 0.002745615–0.002780958 |
| Go | slice | 73728 | 152.486792 | 0.002068234 | 0.001982094–0.002196571 |
| Go | concat | 73728 | 1680.493792 | 0.022793156 | 0.022768530–0.022904559 |
| Go | random | 73728 | 19.588917 | 0.000265692 | 0.000261941–0.000267176 |
| Go | equal | 73728 | 57.816166 | 0.000784182 | 0.000780728–0.000788248 |
| Go | build_256 | 73728 | 9.894333 | 0.000134200 | 0.000133484–0.000134454 |
| Go | build_1024 | 73728 | 42.254000 | 0.000573107 | 0.000562489–0.000589335 |
| Bun | fill | 32768 | 715.793333 | 0.021844279 | 0.021738593–0.021897535 |
| Bun | sum | 32768 | 533.669083 | 0.016286288 | 0.016282945–0.016293854 |
| Bun | find | 32768 | 45.948042 | 0.001402223 | 0.001371152–0.001559915 |
| Bun | slice | 32768 | 35.821292 | 0.001093179 | 0.001021680–0.001109455 |
| Bun | concat | 32768 | 137.905958 | 0.004208556 | 0.004170494–0.004226426 |
| Bun | random | 32768 | 12.632916 | 0.000385526 | 0.000385020–0.000400684 |
| Bun | equal | 32768 | 38.773792 | 0.001183282 | 0.001177841–0.001186876 |
| Bun | build_256 | 32768 | 10.320125 | 0.000314945 | 0.000308061–0.000321712 |
| Bun | build_1024 | 32768 | 29.828334 | 0.000910289 | 0.000907589–0.001007078 |
| Node | fill | 32768 | 872.325917 | 0.026621274 | 0.026395149–0.026698414 |
| Node | sum | 32768 | 752.725958 | 0.022971373 | 0.020455159–0.023416428 |
| Node | find | 32768 | 86.777791 | 0.002648248 | 0.002485049–0.002661944 |
| Node | slice | 32768 | 44.224875 | 0.001349636 | 0.001300393–0.001384046 |
| Node | concat | 32768 | 140.882167 | 0.004299383 | 0.004179091–0.004310983 |
| Node | random | 32768 | 8.993708 | 0.000274466 | 0.000270096–0.000274990 |
| Node | equal | 32768 | 41.187291 | 0.001256936 | 0.001249016–0.001259599 |
| Node | build_256 | 32768 | 29.613584 | 0.000903735 | 0.000900898–0.000911132 |
| Node | build_1024 | 32768 | 66.429750 | 0.002027275 | 0.002017409–0.002097543 |
| Python | fill | 8192 | 15620.383208 | 1.906785060 | 1.905147339–1.907286657 |
| Python | sum | 8192 | 10805.770583 | 1.319063792 | 1.318334132–1.354554453 |
| Python | find | 8192 | 269.743625 | 0.032927689 | 0.032793035–0.033065196 |
| Python | slice | 8192 | 8.300959 | 0.001013301 | 0.000996729–0.001029271 |
| Python | concat | 8192 | 12.802750 | 0.001562836 | 0.001534439–0.001634883 |
| Python | random | 8192 | 231.448417 | 0.028252981 | 0.027527949–0.028700948 |
| Python | equal | 8192 | 10.587459 | 0.001292414 | 0.001289673–0.001312439 |
| Python | build_256 | 8192 | 36.958500 | 0.004511536 | 0.004475128–0.004534505 |
| Python | build_1024 | 8192 | 162.414666 | 0.019826009 | 0.019738240–0.019890971 |
| Bend Array | fill | 40960 | 215.961291 | 0.005272492 | 0.005247891–0.005314553 |
| Bend Array | sum | 40960 | 665.675750 | 0.016251849 | 0.016246581–0.016287101 |
| Bend Array | sum_bytewise | 40960 | 656.768542 | 0.016034388 | 0.015982732–0.016053214 |
| Bend Array | sum_again | 40960 | 664.974458 | 0.016234728 | 0.016209769–0.016284276 |
| Bend Array | find | 40960 | 1817.764000 | 0.044379004 | 0.044329473–0.044519588 |
| Bend Array | find_swar | 40960 | 1985.992542 | 0.048486146 | 0.048458630–0.048501928 |
| Bend Array | slice | 40960 | 123.243000 | 0.003008862 | 0.003004397–0.003022582 |
| Bend Array | concat | 40960 | 240.849167 | 0.005880107 | 0.005867854–0.005889013 |
| Bend Array | random | 40960 | 10.692500 | 0.000261047 | 0.000248048–0.000268670 |
| Bend Array | equal | 40960 | 231.163916 | 0.005643650 | 0.005641622–0.005651320 |
| Bend Array | build_256 | 40960 | 63.452708 | 0.001549138 | 0.001530783–0.001550238 |
| Bend Array | build_1024 | 40960 | 277.975917 | 0.006786521 | 0.006659483–0.006798930 |
| Bend String | fill | 32 | 21.014708 | 0.656709625 | 0.652979156–0.660397125 |
| Bend String | sum | 32 | 13.376500 | 0.418015625 | 0.410179688–0.423376313 |
| Bend String | find | 32 | 13.413417 | 0.419169281 | 0.415662750–0.422110656 |
| Bend String | slice | 32 | 20.647125 | 0.645222656 | 0.637914063–0.647986969 |
| Bend String | concat | 32 | 31.748042 | 0.992126313 | 0.991488281–1.002796875 |
| Bend String | equal | 32 | 16.271917 | 0.508497406 | 0.506816406–0.519054687 |

### 1 MiB

| variant | op | count | batch ms (median) | ms/op (median) | ms/op (min–max) |
|---|---|---:|---:|---:|---:|
| C | fill | 49152 | 444.433000 | 0.009042013 | 0.008990011–0.009046041 |
| C | sum | 49152 | 604.434000 | 0.012297241 | 0.012192424–0.012306966 |
| C | find | 49152 | 27181.973000 | 0.553018656 | 0.552541748–0.553495707 |
| C | slice | 49152 | 319.794000 | 0.006506226 | 0.006502238–0.006506429 |
| C | concat | 49152 | 415.307000 | 0.008449443 | 0.008449198–0.008497274 |
| C | random | 49152 | 11.730000 | 0.000238647 | 0.000237000–0.000240763 |
| C | equal | 49152 | 899.033000 | 0.018290873 | 0.018277425–0.018321106 |
| C | build_256 | 49152 | 13.885000 | 0.000282491 | 0.000282166–0.000287781 |
| C | build_1024 | 49152 | 28.776000 | 0.000585449 | 0.000579549–0.000596334 |
| Rust | fill | 49152 | 675.010792 | 0.013733130 | 0.013711805–0.013788811 |
| Rust | sum | 49152 | 604.045625 | 0.012289340 | 0.012245333–0.012366396 |
| Rust | find | 49152 | 12884.938333 | 0.262144741 | 0.261688037–0.264478850 |
| Rust | slice | 49152 | 318.749833 | 0.006484982 | 0.006468895–0.006513194 |
| Rust | concat | 49152 | 420.084250 | 0.008546636 | 0.008534320–0.008675945 |
| Rust | random | 49152 | 11.760875 | 0.000239276 | 0.000237358–0.000253314 |
| Rust | equal | 49152 | 901.330875 | 0.018337624 | 0.018299939–0.018365477 |
| Rust | build_256 | 49152 | 11.790584 | 0.000239880 | 0.000234714–0.000244577 |
| Rust | build_1024 | 49152 | 28.002041 | 0.000569703 | 0.000556462–0.000572249 |
| Go | fill | 73728 | 41278.834083 | 0.559880020 | 0.559680212–0.559883210 |
| Go | sum | 73728 | 19840.748416 | 0.269107373 | 0.268715263–0.269291953 |
| Go | find | 73728 | 3495.578958 | 0.047411824 | 0.047371984–0.047627413 |
| Go | slice | 73728 | 2141.971167 | 0.029052343 | 0.028980898–0.030680742 |
| Go | concat | 73728 | 44178.983583 | 0.599215815 | 0.598960445–0.635277418 |
| Go | random | 73728 | 19.996875 | 0.000271225 | 0.000267582–0.000272390 |
| Go | equal | 73728 | 1304.297291 | 0.017690664 | 0.017685758–0.018912329 |
| Go | build_256 | 73728 | 10.078625 | 0.000136700 | 0.000135531–0.000137935 |
| Go | build_1024 | 73728 | 42.669500 | 0.000578742 | 0.000573699–0.000579688 |
| Bun | fill | 32768 | 11384.943500 | 0.347440903 | 0.341301979–0.347931039 |
| Bun | sum | 32768 | 9420.914583 | 0.287503497 | 0.275672335–0.520172826 |
| Bun | find | 32768 | 728.734584 | 0.022239215 | 0.021881330–0.024581490 |
| Bun | slice | 32768 | 548.869583 | 0.016750170 | 0.016590432–0.016783506 |
| Bun | concat | 32768 | 2474.328834 | 0.075510523 | 0.075487985–0.076162247 |
| Bun | random | 32768 | 13.052584 | 0.000398333 | 0.000394995–0.000414374 |
| Bun | equal | 32768 | 604.957084 | 0.018461825 | 0.018400801–0.018580013 |
| Bun | build_256 | 32768 | 10.901666 | 0.000332692 | 0.000318680–0.000335822 |
| Bun | build_1024 | 32768 | 30.841292 | 0.000941202 | 0.000910606–0.000944232 |
| Node | fill | 30720 | 12799.718084 | 0.416657490 | 0.416546118–0.417153135 |
| Node | sum | 30720 | 10254.765125 | 0.333813969 | 0.331624974–0.334407861 |
| Node | find | 30720 | 1267.804541 | 0.041269679 | 0.040040164–0.043719777 |
| Node | slice | 30720 | 317.915250 | 0.010348804 | 0.010335033–0.010449105 |
| Node | concat | 30720 | 1906.836084 | 0.062071487 | 0.061416923–0.063055668 |
| Node | random | 30720 | 8.628792 | 0.000280885 | 0.000271408–0.000283598 |
| Node | equal | 30720 | 571.569042 | 0.018605763 | 0.018575509–0.018631559 |
| Node | build_256 | 30720 | 27.317542 | 0.000889243 | 0.000880093–0.000889583 |
| Node | build_1024 | 30720 | 65.027834 | 0.002116791 | 0.001993853–0.002131452 |
| Python | fill | 2560 | 77949.251375 | 30.448926318 | 30.392419287–30.462567122 |
| Python | sum | 2560 | 53878.220583 | 21.046179915 | 21.013519336–21.106799039 |
| Python | find | 2560 | 1345.420000 | 0.525554688 | 0.525170378–0.526437256 |
| Python | slice | 2560 | 34.060458 | 0.013304866 | 0.013273682–0.013392513 |
| Python | concat | 2560 | 55.621292 | 0.021727067 | 0.021635889–0.021794287 |
| Python | random | 2560 | 71.721208 | 0.028016097 | 0.028009261–0.028074398 |
| Python | equal | 2560 | 48.063084 | 0.018774642 | 0.018574316–0.018947266 |
| Python | build_256 | 2560 | 11.766750 | 0.004596387 | 0.004578304–0.004630566 |
| Python | build_1024 | 2560 | 50.870500 | 0.019871289 | 0.019770003–0.020094368 |
| Bend Array | fill | 40960 | 3427.458250 | 0.083678180 | 0.083570705–0.083769223 |
| Bend Array | sum | 40960 | 10688.061250 | 0.260938995 | 0.260641236–0.261892480 |
| Bend Array | sum_bytewise | 40960 | 10571.645833 | 0.258096822 | 0.257967562–0.258344607 |
| Bend Array | sum_again | 40960 | 10682.262917 | 0.260797434 | 0.260409906–0.261589761 |
| Bend Array | find | 40960 | 29139.581334 | 0.711415560 | 0.711006255–0.711480682 |
| Bend Array | find_swar | 40960 | 31843.012042 | 0.777417286 | 0.777204217–0.778010445 |
| Bend Array | slice | 40960 | 1930.656667 | 0.047135173 | 0.046825518–0.047149390 |
| Bend Array | concat | 40960 | 4333.955208 | 0.105809453 | 0.105715862–0.105857639 |
| Bend Array | random | 40960 | 10.726750 | 0.000261884 | 0.000259637–0.000265835 |
| Bend Array | equal | 40960 | 3725.210584 | 0.090947524 | 0.090909571–0.091030139 |
| Bend Array | build_256 | 40960 | 64.489791 | 0.001574458 | 0.001513203–0.001575859 |
| Bend Array | build_1024 | 40960 | 276.689250 | 0.006755109 | 0.006633081–0.006769185 |
| Bend String | fill | 32 | 334.870125 | 10.464691406 | 10.452434875–10.561450531 |
| Bend String | sum | 32 | 219.738917 | 6.866841156 | 6.827326812–6.882579437 |
| Bend String | find | 32 | 220.408292 | 6.887759125 | 6.883052063–6.894660156 |
| Bend String | slice | 32 | 335.300208 | 10.478131500 | 10.461183594–10.685819031 |
| Bend String | concat | 32 | 531.230959 | 16.600967469 | 16.384459656–16.796774750 |
| Bend String | equal | 32 | 262.582625 | 8.205707031 | 8.133183594–8.229630219 |

### Limits and cost changes

These batches replace the earlier single-operation curves, which included zero C timings and a roughly 0.03-ms Bend floor. Output is now outside each timed region. Warmup and calibration reduce cold allocator and JIT effects. The batch includes loop and checksum overhead; it does not subtract an empty-loop estimate. Allocation timings can include reclamation. The warm input and allocator state do not model a cold request.

Bend Array bytewise sum rises from about 0.000066 ms at 256 B to 0.0010 ms at 4 KiB, 0.016 ms at 64 KiB, and 0.258 ms at 1 MiB. Find rises from 0.000166 ms to 0.711 ms over the same sizes. The fixed-count random and build rows do not measure work proportional to N. Do not infer a parallel cutoff from them.

No parallel cutoff is selected. A cutoff needs direct sequential and parallel measurements under both idle and loaded cores.

## Later: parallel ops

For now we accept the gap: `find` is about 20x slower, and `concat` about 4x. Every Bend op here is one sequential loop.

The idea to try later: other standard libraries close gaps like these with SIMD, and Bend can close them with fork-join instead. `Array` is a binary tree (`ALeaf{value}` / `ANode{xs, ys}`), so an op can match `ANode{xs, ys}` and run `a b = op(xs) op(ys)` on all cores. Compare against each language's standard library as it is. If Bend's parallelism beats their SIMD, that counts.

Plan:

1. The batch curves above cover 256 B through 1 MiB. Compare sequential and parallel variants directly. HTTP headers are small, and on small buffers forking can cost more than it saves.
2. Select a cutoff only from those direct measurements under both idle and loaded cores. Stay sequential below it.
3. Parallelize `fill`, `sum`, `find`, and `equal`. `find` has to catch a match that spans the split: each half reports its first and last 3 bytes, or the halves overlap by 3 bytes. Try `Array.join` for `concat`.

Keep in mind that parallelism borrows idle cores, while SIMD speeds up one core. On a loaded server every core is already busy, so the cutoff should be conservative.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- Bend `concat` and `find_swar` vary up to 2x between runs. Rerun before you trust a small change.
- The byte-at-a-time `sum` beats the word-at-a-time one, even on `--threads 1`. The likely cause is clang optimizing the C that Bend emits for the byte loop better. That is not confirmed.
- These are micro-benchmarks on one machine. They measure primitives, not an HTTP parser.
