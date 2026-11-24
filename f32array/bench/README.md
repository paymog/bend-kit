# F32Array benchmark

This times the array ops that a model or feature pipeline runs, on 2^22 `float32` values (16 MiB), in Bend, C, Rust, JavaScript, and NumPy.

## Run

```sh
python3 run.py      # 3 runs, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, `python3`, and NumPy. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, or if two programs disagree on a checksum. Bend uses `parallel.bend` for sum and dot, with eight CPU workers.

## The work

`a[i] = (i + 3) & 3` and `b[i] = (5i + 3) & 3`, for N = 2^22. Every partial sum is an integer below 2^24, so each sum is exact in any order and every program prints the same checksums. Each program builds `a`, `b`, and the little-endian bytes of `a` before the first timer, then runs these ops in order:

| op | work | checksum |
|---|---|---|
| `from_bytes` | decode the 16 MiB of little-endian bytes into a new array `a` | `a[N-1] + a[12345]` |
| `sum` | add up `a` | the sum |
| `max` | the largest element of `a` | the max |
| `dot` | the sum of `a[i] * b[i]` | the dot product |
| `map` | `a[i] *= 2`, in place | `a[N-1] + a[12345]` |
| `add` | `a[i] += b[i]`, in place | `a[N-1] + a[12345]` |
| `to_bytes` | encode `a` as little-endian bytes in a new buffer | byte count + last byte |

Each language uses its obvious loop or standard call. C uses `memcpy` and plain loops (so it assumes a little-endian host). Rust uses `Vec<f32>` with `chunks_exact`, `from_le_bytes`, and iterator `sum`, `fold`, and `zip`. Bun and Node use `Float32Array` and `for` loops. Python's standard library has no vector math, so the Python column is NumPy: `frombuffer`, `sum`, `max`, `dot`, `*=`, `+=`, and `tobytes`.

## Results

M4 Pro, macOS, 2026-11-20. Bend 2.0.38, Apple clang 21.0.0 (`-O2`), rustc 1.91.0 (`opt-level=3`), Bun 1.4.4, Node 24.0.1, Python 3.14.6 with NumPy 2.4.2. Median of five runs with `python3 run.py 5`. Times are in ms; `Nx` is the multiple of the fastest program for that op.

| op | C | Rust | Bun | Node | NumPy | Bend |
|---|---:|---:|---:|---:|---:|---:|
| from_bytes | 0.98 (2.4x) | 1.83 (4.5x) | 1.04 (2.5x) | 1.32 (3.2x) | 0.41 (1.0x) | 3.25 (7.9x) |
| sum | 2.21 (5.1x) | 2.23 (5.2x) | 6.80 (15.8x) | 10.73 (25.0x) | 0.52 (1.2x) | 0.43 (1.0x) |
| max | 2.06 (10.6x) | 0.26 (1.3x) | 3.92 (20.0x) | 5.66 (28.9x) | 0.20 (1.0x) | 3.16 (16.2x) |
| dot | 2.27 (8.6x) | 2.26 (8.6x) | 24.77 (93.9x) | 25.10 (95.1x) | 0.26 (1.0x) | 0.43 (1.6x) |
| map | 0.25 (1.1x) | 0.24 (1.0x) | 19.08 (81.0x) | 2.99 (12.7x) | 0.26 (1.1x) | 0.49 (2.1x) |
| add | 0.34 (1.0x) | 0.36 (1.1x) | 6.08 (18.0x) | 8.27 (24.5x) | 0.36 (1.1x) | 0.45 (1.3x) |
| to_bytes | 0.99 (2.5x) | 1.12 (2.9x) | 1.08 (2.7x) | 0.39 (1.0x) | 2.36 (6.0x) | 2.08 (5.3x) |
| geomean vs fastest | 3.1x | 2.6x | 16.3x | 13.2x | 1.4x | 3.1x |

Every program printed checksums `2`, `6291456`, `3`, `14680064`, `4`, `6`, and `16777280`.

## Reading it

- Each `Array` slot holds eight elements. Each sum leaf adds the lanes of each cell pairwise, then adds at most 16 cell totals sequentially. Higher nodes add equal halves pairwise.
- The eight-worker sum and dot take about 0.43 ms each. The former sequential four-accumulator implementation measured 1.15 ms and 1.95 ms in the earlier 2026-10-27 run. Use the same-run comparison below to separate the algorithm from compiler and machine variation.
- `map` and `add` are within 2.1x of C.
- A loop that writes cells must not read the next cell ahead. The read-ahead form of `map` took 1.1 ms; reading and writing the same cell in each pass takes 0.3 to 0.4 ms. The read-only loops (`sum`, `dot`, `max`) read ahead without that cost.
- `max` is the slowest remaining numeric op: 3.16 ms against 2.06 ms in C.
- `from_bytes` and `to_bytes` move eight words per cell. C and JS copy the memory, so they are 2 to 6 times faster.
- Only sum and dot use fork-join. Other ops remain sequential.

## Cutoff and float64 error

Run `BEND=/path/to/bend python3 reduce.py 3` from this folder. This separate Bend benchmark keeps the former four-accumulator loops as a baseline. It runs each variant on one process at a time. It checks that the pure and fork-join results have identical bits at every worker count and cutoff.

The fixed input is `a[0] = 100000000`, every other `a[i] = 1`, and every `b[i] = 1`. All inputs and products are exact in float32. The float64 reference for both reductions is `100000000 + N - 1`, which is also the exact real sum. Bend prints float32 bits; Python decodes them before subtracting the float64 reference. Thus decimal display rounding cannot change the measured error.

Same machine and versions as above. Median of three runs. Each time pair is sum / dot, in ms. The fork-join column uses eight workers and a 4,096-cell task cutoff. The old and pure columns use one worker.

| N | old four sums | pure blocked pairwise | fork-join | old absolute error | pairwise absolute error |
|---:|---:|---:|---:|---:|---:|
| 49,152 | 0.0587 / 0.0455 | 0.0760 / 0.0691 | 0.1759 / 0.1389 | 12,287 | 7 |
| 65,536 | 0.0648 / 0.0560 | 0.0775 / 0.0669 | 0.1920 / 0.1487 | 16,383 | 7 |
| 262,144 | 0.0979 / 0.0859 | 0.1234 / 0.1498 | 0.2493 / 0.1953 | 65,535 | 7 |
| 1,048,576 | 0.2674 / 0.2289 | 0.3271 / 0.5084 | 0.3087 / 0.2569 | 262,143 | 7 |
| 4,194,304 | 0.8526 / 0.7917 | 1.1060 / 1.8461 | 0.4075 / 0.4253 | 1,048,575 | 7 |
| 16,777,216 | 2.8884 / 3.0733 | 4.2572 / 7.3268 | 0.8320 / 1.1409 | 4,194,303 | 7 |

Errors apply to both sum and dot. On the 49,152-term case, the result is `100049144`, against the reference `100049151`. The error is 7, not zero. A float32 result cannot represent the reference exactly. This input does not establish a bound for all inputs.

The task-size sweep at N = 4,194,304 gave:

| cell cutoff | elements per task | one worker, sum / dot ms | eight workers, sum / dot ms |
|---:|---:|---:|---:|
| 256 | 2,048 | 1.0856 / 1.8270 | 0.5108 / 0.6705 |
| 4,096 | 32,768 | 1.0838 / 1.8750 | 0.4075 / 0.4253 |
| 65,536 | 524,288 | 1.1434 / 1.8925 | 0.7940 / 1.0839 |
| 1,048,576 | 8,388,608 | 1.0975 / 1.9388 | 3.4668 / 5.1755 |

Use a 4,096-cell cutoff above 2^20 elements. Below that input size, use the pure sequential reduction: scheduling costs more than it saves. At 2^20, sum is near break-even against pure pairwise, while dot improves. This machine needs smaller tasks than the earlier upstream 2^23-multiply-add observation. The large unsplit eight-worker result is slower than one worker; worker count alone does not make a sequential call faster.

The 16-cell sequential leaf avoids one recursive call per cell. An initial full cell-by-cell pairwise version took 49.48 / 73.47 ms on this input with eight workers and no split, and 4.93 / 7.84 ms with a 32,768-cell cutoff. These are single exploratory runs, not medians. The bounded sequential leaf keeps the accuracy gain without that recursive overhead.

Fork-join does not clone the array. A pure structural `ANode` split was considered. In Bend 2.0.38's emitted C, `blk_half` allocates and copies each half; rebuilding `ANode` allocates and copies again. Sharing read-only handles with `Array.fork` and joining them after both calls avoids these copies. These unsafe Base operations stay in `parallel.bend`, outside the proof graph.

## Pure reduction overhead

M4 Pro, macOS, 2026-11-24, Bend 2.0.40. Run `python3 reduce.py 5` before and after the change. Each value below is the median of five runs. The pure path uses one worker. Both versions use the same 16-cell serial leaves and the same addition order.

| input | N | before sum / dot ms | after sum / dot ms | before and after sum / dot absolute error |
|---|---:|---:|---:|---:|
| positive | 49,152 | 0.0677 / 0.0725 | 0.0698 / 0.0559 | 7 / 7 |
| positive | 4,194,304 | 1.0845 / 1.8848 | 0.7110 / 1.3404 | 7 / 7 |
| positive | 16,777,216 | 4.2593 / 7.6791 | 2.6954 / 5.1215 | 7 / 7 |
| cancellation | 49,152 | 0.0739 / 0.0675 | 0.0809 / 0.0566 | 24,576 / 24,576 |
| cancellation | 4,194,304 | 1.0865 / 1.9107 | 0.7057 / 1.3385 | 2,097,152 / 2,097,152 |
| mixed-scale | 49,152 | 0.0761 / 0.0687 | 0.0629 / 0.0612 | 0.00390625 / 0 |
| mixed-scale | 4,194,304 | 1.0986 / 1.9245 | 0.7154 / 1.3548 | 0.25 / 0 |

The lowest recursive combine now calls its two 16-cell blocks directly. This removes half the recursive combine nodes and their closures. It does not extend a serial running sum or change a product. At N = 4,194,304, the pure positive sum and dot improve by 34% and 29%. The eight-worker 4,096-cell cutoff improves from 0.4333 / 0.4620 ms to 0.3459 / 0.3407 ms.

Other measured changes did not help. Reading the last cell in the loop's base case and expanding cell products into a scalar expression took 1.6020 / 3.5707 ms on the positive N = 4,194,304 input. Direct scalar expressions without that loop change took 1.0902 / 1.9303 ms. Eight lane accumulators confined to each 16-cell leaf took 1.1997 / 2.0345 ms and raised the positive absolute error from 7 to 15. These variants were removed.

The cancellation input repeats `[100000000, 1, -100000000, 1]`; its second dot input is all ones. The mixed-scale input repeats `[10000, 0.125, -10000, 0.25, 0.001, 8, -0.001, -4]`. Its second dot input repeats `[0.5, 2, 0.5, 4, 2, -0.5, 2, 0.25]`. Python first rounds each input to float32, then computes references with float64 `math.fsum`. These products are exact power-of-two scalings, so no product rounding enters the reference.

Cancellation still loses the unit terms inside each cell. The optimization does not fix that accuracy limit. The positive family alone must not be used to claim a general error bound.

The driver also checks N = 0, 1, 7, 8, 9, 127, 128, and 129 for each family. It checks pure/parallel result bits at cell cutoffs 16, 256, 4,096, 65,536, and 1,048,576, with one and eight workers.

## Destination-range loads

Run `python3 f32array/bench/load.py` from the repo root. It builds `load.bend`, writes NumPy float32 ones, and checks each checksum. It compares `.read.le.at.into` with `.read.le.at` followed by an element copy into the same destination range. Both retain a destination with two untouched boundary lanes. The timer includes the read, any copy, checksum reduction, and checksum output. The destination is allocated before the timer. File data is warm.

M4 Pro, macOS, 2026-11-24, Bend 2.0.40, one worker. Median of three separate processes. `/usr/bin/time -l` measures peak resident memory for each process; this is not an allocator byte counter.

| elements | into ms | allocate + copy ms | into peak RSS bytes | allocate + copy peak RSS bytes |
|---:|---:|---:|---:|---:|
| 8 | 0.115209 | 0.082167 | 1,982,464 | 1,982,464 |
| 1,048,576 | 5.424375 | 8.422959 | 12,533,760 | 17,809,408 |

At 2^20 elements, destination reads save 36% of measured load time and 5,275,648 bytes of peak RSS. The allocated path creates one extra 4 MiB logical F32 buffer, plus its runtime metadata. Both paths still allocate bounded packed-byte read chunks. Tiny loads are dominated by fixed IO and timing costs. This comparison measures the Bend API paths, not raw filesystem throughput.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It prints each checksum before the second clock read, so the work is forced inside the timer.
- These are micro-benchmarks on one machine. The main comparison uses one size; the reduction sweep adds cancellation and mixed-scale inputs to the positive family.
