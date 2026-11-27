# Statistics benchmark

## Proved Newton integer square root

Stats 0.1.8.1 removes the certificate and runtime search fallback. The seed, four Newton steps, and division-based correction are unchanged. The last three steps use a terminating countdown so the proof can induct on the remaining work without expanding four nested arithmetic terms.

Build and run the retained paired control:

```sh
bend stats/bench/evidence/newton.bend -o /tmp/stats-newton && \
/tmp/stats-newton 16 && \
/tmp/stats-newton && \
/tmp/stats-newton && \
/tmp/stats-newton
```

The small probe uses 71 pairs. Its isqrt checksum is `1042369`; its identity checksum is `1836604304`. Each full run uses the same 2097207 pairs as the prior controls. It retains one shared list for the identity, certified stats 0.1.8.0, and proved passes. The final identity pass releases the list. Input generation is outside the timed passes.

2026-11-26, Apple M4 Pro, macOS 26.7.2 arm64, Bend 2.0.40. Times are ms.

| paired shared-list pass | run 1 | run 2 | run 3 | median |
|---|---:|---:|---:|---:|
| Identity | 9.583375 | 9.644542 | 9.652416 | 9.644542 |
| Certified Newton, stats 0.1.8.0 | 11.098042 | 11.039458 | 11.053459 | 11.053459 |
| Proved Newton, stats 0.1.8.1 | 8.792250 | 9.223292 | 9.668083 | 9.223292 |
| Identity with list release | 27.385208 | 28.327833 | 27.497917 | 27.497917 |

The controlled median improves by 16.6%. Every full isqrt pass returns `1421540955`; every full identity pass returns `2699619501`. These are end-to-end shared-list timings, not isolated arithmetic costs. The control always runs the certified pass first, so it does not separate order effects from the implementation change.

`python3 stats/bench/run.py 3` also passes the small probe and three full runs in all six languages. The isqrt medians are:

| pass | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| Original list/array pass | 32.064 | 5.471 | 268.986 | 188.757 | 237.975 | 28.007 |
| Packed pass | 31.921 | 5.548 | 280.134 | 176.545 | 328.096 | 4.717 |

Bend's shared-list isqrt median is 8.692 ms, with identity at 7.773 ms and the final releasing identity at 27.121 ms. The original Bend list pass consumes its last list reference; the shared pass retains it. Do not compare those ownership paths as isolated arithmetic timings.

All implementations retain these checksums: mean `3422847917`, variance `1370401302`, median `1092607460`, histogram `1092535808`, gcd `18047959`, lcm `3181042401`, isqrt `1421540955`, and packed identity `2699619501`. Packed gcd, lcm, and isqrt agree with their original passes. The JavaScript warm-up and dispatch controls also pass. Tool versions: Apple clang 21.0.0, rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6.

The older measurements below retain their original package versions and runtime certification status.

This times the mean, sample variance, median, and a 100-bin histogram of 10000 doubles. It also times U32 gcd, checked lcm, and integer square root. It compares `stats` with C, Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 4 runs, median; one complete process-order cycle
python3 run.py 8    # 8 runs; two complete cycles
```

You need `bend`, `cc`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. Each invocation builds each native program once. It checks a small integer input before the full input. It exits non-zero if a build fails, if checksums change between runs, or if two programs disagree on a checksum.

## The work

Each program makes 10000 xorshift32 draws from seed 44 and shifts each draw right by 12 bits, so every value is an integer below 2^20 and exact as a double. Each op prints the xor of the two words of its result.

| op | C | Rust | Python | JavaScript | Bend |
|---|---|---|---|---|---|
| mean | loop | `Iterator::sum` | `statistics.fmean` | loop | `Stats.mean` |
| variance | two-pass loop | two-pass `sum` | two-pass loop | two-pass loop | `Stats.variance` |
| median | `qsort` | `sort_by(total_cmp)` | `statistics.median` | `Float64Array.sort` | `Stats.median` |
| histogram | binary-search loop | `slice::partition_point` | `bisect.bisect_right` | binary-search loop | `Stats.histogram` |
| gcd | Euclid loop | Euclid loop | `math.gcd` | Euclid loop | `U32.gcd` |
| checked lcm | Euclid and U64 product | Euclid and `checked_mul` | `math.lcm` and U32 bound check | Euclid and division bound check | `U32.lcm` |
| isqrt | integer binary search | `u32::isqrt` | `math.isqrt` | integer binary search | `U32.isqrt` |

C and JavaScript have no statistics in the standard library, and Rust's has none either, so those use the obvious loop. Python's `statistics.variance` rounds the exact value once, and Python's `sum` compensates. Both give a variance that differs from the plain two-pass loop in the low bits, so the Python program sums with a plain loop for that op. The sum of the values is exact here, so `fmean` matches the loop.

Bend uses the soft-float in `bend-kit-f64`. The other languages use a hardware double. The C program copies the words with `memcpy`, so it assumes a little-endian host.

## Results

M4 Pro, macOS, 2026-11-13. Bend 2.0.38, Apple clang 21.0.0 (`-O2`), rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Median of three runs. Times are in ms.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| mean | 0.005 | 0.006 | 0.608 | 0.476 | 0.027 | 0.287 |
| variance | 0.012 | 0.011 | 0.546 | 0.616 | 0.264 | 0.875 |
| median | 0.576 | 0.129 | 0.097 | 0.483 | 0.684 | 3.818 |

The checksums are `3422847917` for the mean, `1370401302` for the variance, and `1092607460` for the median, in every program.

Bend's mean and variance are about 50 to 80 times slower than C. That is the soft-float add and multiply, about 30 ns each. The median sorts a linked list with `List.sort` and soft-float compares, about 7 times slower than C's `qsort`. Bun and Node include JIT warm-up, because each op runs once.

## f64 0.1.3.0 re-pin

`python3 bench/run.py` from `stats/`, on the same machine and tool versions above, gives these medians of three runs. Times are in ms. All checksums remain the same in every language.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| mean | 0.005 | 0.006 | 0.586 | 0.455 | 0.029 | 0.286 |
| variance | 0.012 | 0.011 | 0.705 | 0.708 | 0.269 | 0.912 |
| median | 0.584 | 0.128 | 0.123 | 0.499 | 0.715 | 3.819 |

## Universal gcd symmetry

The same `python3 bench/run.py` command after argument ordering gives 0.314 ms for mean, 0.928 ms for variance, and 4.034 ms for median (three-run medians). All six languages retain the checksums above. These float operations do not call gcd.

## Histogram binary search

The histogram has 100 bins and 101 edges, `i * 10486` for `i = 0..100`. It uses the same 10000 draws as the other operations. The last bin is closed. Its checksum is the double word-xor of `sum((i + 1) * count[i])`, so bin placement, not only the total, affects it.

`python3 bench/run.py` from `stats/` on the machine and tool versions above gives these three-run medians in ms. Edge and count allocation are timed in every language.

| implementation | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| Before: one scan per bin | 0.187 | 0.045 | 1.109 | 0.924 | 1.173 | 10.042 |
| After: binary search | 0.098 | 0.062 | 1.373 | 0.957 | 1.156 | 0.416 |

The other languages use binary search in both rows. Bend is about 24 times faster. Every language gives histogram checksum `1092535808` in both runs. The final run also gives Bend mean 0.451 ms, variance 1.545 ms, and median 5.984 ms, with the same checksums as above. Unchanged operations vary between runs.

## Adjacent-rank selection

Before the change, `python3 bench/run.py` gives these three-run medians in ms on the same machine and tool versions:

| implementation | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| Median: full list sort | 0.879 | 0.273 | 0.139 | 0.491 | 0.681 | 4.950 |
| Median: adjacent-rank selection | 0.799 | 0.172 | 0.116 | 0.494 | 0.715 | 1.158 |

A native profiling probe used the same list and clock. Three-run medians were 0.441 ms to build and count `List.sort.runs`, 4.610 ms to sort with direct unsigned word comparisons, and 5.186 ms for the old soft-float median. Direct word order is valid only for this nonnegative fixture. Both sorts gave median checksum `1092607460`. Building singleton runs is a small part of the cost. Removing soft-float comparison logic saved about 0.576 ms. Most time remained in merge passes and list traffic; this probe does not separate their allocation and traversal costs.

The first selection trial ran two independent searches for adjacent ranks and took 4.502 ms. The retained implementation finds both ranks in one search. It keeps the first value above each retained bucket, so it does not select the second rank from scratch. Partitions keep equal values in input order. A logarithmic partition budget falls back to a stable sort of the remaining bucket, so adversarial pivots cannot force quadratic work.

The final `python3 bench/run.py` run gives:

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| mean | 0.007 | 0.008 | 0.685 | 0.500 | 0.029 | 0.276 |
| variance | 0.013 | 0.015 | 0.699 | 0.692 | 0.284 | 1.000 |
| median | 0.799 | 0.172 | 0.116 | 0.494 | 0.715 | 1.158 |
| histogram | 0.171 | 0.049 | 1.530 | 0.917 | 1.181 | 0.273 |

Every language retains the four checksums above. Median is about 4.3 times faster than the preceding full-sort run. Timing varies between runs; no Array-sort experiment was needed after selection improved the fixed workload.

## Universal integer laws

`python3 bench/run.py 1` on 2026-11-15 confirms all four checksums above in C, Rust, Bun, Node, Python, and Bend. This is one checksum run, not a new timing baseline. These float workloads do not call gcd, lcm, or integer square root; their universal proofs and existing fixtures cover the integer changes.

## Integer workloads

Each integer workload uses 2097207 pairs, generated before timing:

- Eight edge pairs: `(0, 0)`, `(0, 0xFFFFFFFF)`, `(0xFFFFFFFF, 0)`, `(0xFFFFFFFF, 0xFFFFFFFF)`, `(0xFFFFFFFF, 1)`, `(65535, 65536)`, `(65536, 65537)`, and `(12, 18)`.
- All 47 consecutive Fibonacci pairs that fit U32, from `(0, 1)` through `(1836311903, 2971215073)`.
- 2097152 pairs from xorshift32, starting at seed 44. For each pair, `a = xs(x)` and `b = xs(a)`; the next seed is `b`. These draws keep all 32 bits.

Gcd and lcm use both values. Isqrt uses the first value. The lcm cases include zero, equal maximum values, coprime values with a product that fits, and products that overflow. Each program sums the results modulo 2^32. A checked lcm result above `0xFFFFFFFF` is `None` and contributes `0x9E3779B9`, not zero. Python computes `math.lcm` first and checks that bound. JavaScript checks the bound before multiplication, so every retained product is exact.

C and JavaScript have no standard-library integer gcd or isqrt. They use Euclid's loop and an integer binary-search loop. Rust has no standard-library gcd or lcm, so it uses Euclid's loop and `checked_mul`; its isqrt uses the standard library. No extra dependency is needed.

The first probe uses the same 55 edge and Fibonacci pairs with only 16 random pairs. The harness checks its checksums across all six implementations. Each program accepts the random-pair count as its first argument. The full input is large enough for even Rust's isqrt to take several milliseconds. The float workloads are unchanged.

### Results

Command from the repository root: `python3 stats/bench/run.py` (three runs, median). The run used a process monitor that kills a Bend process above 8 GiB RSS. The small probe passed before the full input. No process reached that limit.

M4 Pro, macOS 25.6.0 arm64, 2026-11-15. Bend 2.0.38 (native), Apple clang 21.0.0 (`-O2`), rustc 1.91.0 (`-C opt-level=3`), Bun 1.4.4, Node 24.0.1, Python 3.14.6. Times are in ms. Input generation is not timed. Traversal, calls, and checksum accumulation are timed. JavaScript includes JIT warm-up. Bend uses a shared list; the final traversal also releases that list.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| mean | 0.006 | 0.005 | 0.626 | 0.510 | 0.028 | 0.258 |
| variance | 0.011 | 0.011 | 0.615 | 0.754 | 0.271 | 0.894 |
| median | 0.581 | 0.129 | 0.101 | 0.495 | 0.704 | 1.008 |
| histogram | 0.099 | 0.035 | 1.058 | 0.950 | 1.202 | 0.268 |
| gcd | 124.400 | 124.029 | 830.388 | 714.705 | 318.521 | 135.605 |
| lcm | 124.711 | 123.512 | 828.964 | 519.887 | 515.763 | 133.552 |
| isqrt | 32.043 | 5.599 | 264.228 | 191.325 | 234.334 | 16.898 |

All six implementations agree in every run:

| op | checksum |
|---|---:|
| mean | 3422847917 |
| variance | 1370401302 |
| median | 1092607460 |
| histogram | 1092535808 |
| gcd | 18047959 |
| lcm | 3181042401 |
| isqrt | 1421540955 |

Bend's gcd and lcm are within about 9% of C and Rust. Its isqrt is about 3.0 times slower than Rust's standard library, but faster than the C binary-search loop. [Issue #771](https://github.com/paymog/bend-kit/issues/771) tracks that measured isqrt gap. The checksums exposed no integer correctness failure.

## Certified Newton integer square root

Command: `python3 stats/bench/run.py`, from the repository root. Both rows use the same 2097207 pairs and three-run medians. The small probe passes first. The process monitor caps Bend at 8 GiB RSS.

M4 Pro, macOS 25.6.0 arm64, 2026-11-15. Bend 2.0.38, Apple clang 21.0.0, rustc 1.91.0, Bun 1.4.4, Node 24.0.1, Python 3.14.6. Native build flags and input generation are unchanged. Times are in ms.

| isqrt implementation | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| Before: 16-round search, stats 0.1.6.0 | 33.771 | 5.817 | 275.176 | 197.694 | 240.289 | 17.759 |
| After: certified Newton, stats 0.1.7.0 | 28.734 | 4.951 | 242.535 | 176.091 | 226.483 | 10.034 |

Other languages also became faster between batches. A separate native control therefore times the original search and the final certified implementation in the same process, over the same shared list. Its three runs give:

| controlled pass | run 1 | run 2 | run 3 | median |
|---|---:|---:|---:|---:|
| Shared identity traversal | 9.649 | 8.743 | 9.540 | 9.540 |
| Original shared isqrt | 17.835 | 16.992 | 17.212 | 17.212 |
| Certified Newton shared isqrt | 10.968 | 11.357 | 11.052 | 11.052 |
| Final identity traversal with list release | 26.948 | 27.204 | 27.038 | 27.038 |

The controlled median improves by 35.8%. The final public call includes every certification check. The control generates its input before timing and uses `integer.sum` for each pass. The baseline calls `U32.isqrt.go(16n, a, 0, 65536)`; the new pass calls `U32.isqrt(a)`. Each pass prints its checksum. The list remains shared for both searches, then the final identity pass releases it. These are end-to-end traversal times, not isolated kernel times.

The emitted C showed a round-count loop, candidate multiplication, and a separate selection helper. A first control measured identity traversal at 8.172 ms of the original 15.718 ms total. Six search variants and an arithmetic-selection variant did not give a reliable win: `Bool.pick` 18.105 ms, paired rounds 17.459 ms, fully expanded rounds 17.770 ms, arithmetic selection 22.867 ms, fused selection 15.906 ms, a constant first-round seed 17.093 ms, and a skipped leading round 19.161 ms. These exploratory batches were not interleaved. Their small differences cannot be ranked across batches. The paired-round control was slower than the original. None of those changes is retained.

The retained seed is `1 << (1 + log2(n) / 2)`. Four integer Newton steps compute `(r + n / r) / 2`. One correction compares `r > n / r`, so a temporary value of 65536 cannot wrap a square. The certificate checks both square bounds with bounded products and treats 65535 separately. A failed certificate uses the existing proved search. The universal law proves the certificate and the search, not a convergence assumption about the seed.

An independent Rust mirror of the exact U32 operations checked all 4294967296 inputs in 14.108 seconds with rustc 1.91.0 (`--edition=2021 -C opt-level=3`). Every candidate passed the certificate. The fallback count was zero. U64 squares also checked both bounds independently. The sum of all roots was `187647836979200`. This exhaustive check supplements, but does not replace, the universal Bend proof.

To repeat that check, compile and run:

```rust
fn quo(n: u32, r: u32) -> u32 {
    if r == 0 { 0 } else { n / r }
}
fn main() {
    let mut sum = 0u64;
    for wide in 0..=u32::MAX as u64 {
        let n = wide as u32;
        let log = if n == 0 { 0 } else { 31 - n.leading_zeros() };
        let mut r = 1u32 << (1 + log / 2);
        for _ in 0..4 { r = r.wrapping_add(quo(n, r)) / 2; }
        if r > quo(n, r) { r = r.wrapping_sub(1); }
        let next = r.wrapping_add(1);
        assert!(r.wrapping_mul(r) <= n && (r == 65535 ||
            (r < 65536 && next < 65536 && n < next.wrapping_mul(next))));
        assert!((r as u64) * (r as u64) <= wide &&
            wide < (r as u64 + 1) * (r as u64 + 1));
        sum += r as u64;
    }
    assert_eq!(sum, 187647836979200);
}
```

The final full harness gives:

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| mean | 0.005 | 0.005 | 0.536 | 0.464 | 0.025 | 0.250 |
| variance | 0.012 | 0.014 | 0.537 | 0.637 | 0.263 | 0.804 |
| median | 0.580 | 0.123 | 0.086 | 0.479 | 0.663 | 0.963 |
| histogram | 0.100 | 0.044 | 0.932 | 0.877 | 1.117 | 0.288 |
| gcd | 120.014 | 112.784 | 787.665 | 666.527 | 303.726 | 121.936 |
| lcm | 114.032 | 114.695 | 780.080 | 484.984 | 495.221 | 119.868 |
| isqrt | 28.734 | 4.951 | 242.535 | 176.091 | 226.483 | 10.034 |

All six languages agree in every baseline and final run. The checksums remain mean `3422847917`, variance `1370401302`, median `1092607460`, histogram `1092535808`, gcd `18047959`, lcm `3181042401`, and isqrt `1421540955`.

[Issue #773](https://github.com/paymog/bend-kit/issues/773) tracks separate kernel, traversal, and release measurements. [Issue #774](https://github.com/paymog/bend-kit/issues/774) tracks a direct Newton convergence proof to remove runtime certification. The temporary profiling and exhaustive-check programs are not part of the package.

## Packed kernels and list ownership

`python3 stats/bench/run.py` now keeps the seven original end-to-end rows and adds four packed-input rows in every language. The input and integer functions are unchanged. The small 71-pair probe runs before the full 2097207-pair input. Every packed result must match its original checksum in every run. The harness also checks the Bend ownership passes against those same checksums.

Each language builds an interleaved sequence of U32 words before timing: `a0, b0, a1, b1, ...`. C uses a `uint32_t` allocation, Rust uses `Vec<u32>`, Bun and Node use `Uint32Array`, Python uses `array('I')`, and Bend uses `Array<U32>`. The same allocation survives all four packed passes. Allocation, conversion, and release are outside their clocks. Each pass includes reads, calls, and checksum accumulation. These are direct packed-loop measurements, not isolated kernel times.

Bend carries the affine array through each clock boundary and reads its first word after the last clock. Its array has power-of-two capacity. The loop preloads one extra unused pair at the end; only the requested pairs contribute to the checksum. The identity pass uses the same reader and sum loop as the kernels. Native compilers can optimize unused loads and vectorize identity differently, so subtraction is only an estimate.

The Bend-only diagnostic creates a separate copy of the fixed list before timing. Identity, gcd, lcm, and isqrt retain that same shared list. The final identity pass consumes and releases it. This keeps the original end-to-end workload intact and makes ownership costs explicit. Python and JavaScript keep their packed allocation alive through all passes; their collectors can still run during a clock. JavaScript timings include JIT warm-up.

### Results

M4 Pro, macOS 25.6.0 arm64, 2026-11-17. Stats 0.1.7.0, Bend 2.0.38, Apple clang 21.0.0 (`-O2`), rustc 1.91.0 (`-C opt-level=3`), Bun 1.4.4, Node 24.0.1, Python 3.14.6. Command: `python3 stats/bench/run.py`. Three-run medians in ms. A monitor caps Bend at 8 GiB RSS; no process reached the cap.

| direct packed-loop measurement | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| identity | 0.355 | 0.212 | 50.396 | 11.607 | 301.559 | 0.952 |
| gcd | 126.534 | 125.276 | 831.830 | 500.159 | 410.643 | 120.408 |
| checked lcm | 126.289 | 126.093 | 843.569 | 496.617 | 595.255 | 121.034 |
| isqrt | 31.732 | 5.388 | 272.766 | 177.555 | 325.807 | 6.251 |

The harness subtracts packed identity from each packed kernel **within each run**, then takes the median of those differences. These are kernel-cost estimates, not directly measured kernel times. It does not subtract the displayed medians, and it does not clamp negative estimates.

| estimated kernel cost | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| gcd | 126.179 | 125.066 | 781.137 | 488.552 | 108.173 | 119.344 |
| checked lcm | 125.928 | 125.649 | 792.876 | 484.880 | 293.836 | 120.124 |
| isqrt | 31.435 | 5.158 | 222.073 | 165.818 | 24.248 | 5.299 |

| Bend list ownership pass | ms | checksum |
|---|---:|---:|
| identity, shared | 7.996 | 2699619501 |
| gcd, shared | 133.852 | 18047959 |
| checked lcm, shared | 135.074 | 3181042401 |
| isqrt, shared | 9.644 | 1421540955 |
| identity, consuming and releasing | 26.984 | 2699619501 |

The original integer rows remain available: C/Rust/Bun/Node/Python/Bend gcd is 126.630/124.897/834.346/711.659/325.585/134.591 ms; lcm is 126.779/124.908/833.611/520.018/515.252/134.067 ms; isqrt is 31.766/5.471/261.937/190.485/237.207/29.548 ms. Bend's original isqrt is the final consuming list traversal. Its cost must not be compared with a retained packed loop as though both measured only arithmetic.

All six languages retain the seven existing checksums above. Every identity pass gives `2699619501`; packed gcd, lcm, and isqrt give `18047959`, `3181042401`, and `1421540955`. No library code or package version changes in this benchmark update. The packed rows provide the stats 0.1.7.0 baseline for the direct Newton proof work.

## Warmed packed JavaScript comparison

The harness retains every original end-to-end and cold packed row. After those clocks, Bun and Node run three untimed full-input passes for each of identity, gcd, checked lcm, and isqrt. They then time one full-input pass per function. Every warm-up checksum must remain stable and match the timed checksum. The small probe also warms its own 71-pair input and checks every warmed row.

The warmed passes reuse the same `Uint32Array` and integer functions as the cold passes. `packedSum` provides the same shared callback dispatch site for warm-up and measurement. Each warm-up round visits all four functions in the same order as measurement. The clock includes array reads, callback dispatch, integer work, and checksum accumulation. Allocation and warm-up remain outside it. The array stays reachable through every pass; garbage collection can still interrupt a clock.

These are warmed comparisons, not a claim that either JIT reaches a fixed optimization tier. The original cold passes use their original inline loop. The warmed helper has a separate call site, so JIT specialization and loop shape can differ as well as warm-up. Neither subtraction nor this comparison isolates arithmetic or the causal effect of warm-up alone. Native compilers can vectorize identity differently from kernels. The harness prints every per-run kernel-minus-identity estimate and its median for cold lanes and warmed JavaScript. Negative estimates remain signed and visible.

### Calibration results

Command: `python3 stats/bench/run.py 3`, from the repository root. M4 Pro, macOS 25.6.0 arm64, 2026-11-21. Bend 2.0.40 (native), Apple clang 21.0.0 (`-O2`), rustc 1.91.0 (`-C opt-level=3`), Bun 1.4.4, Node 24.0.1, Python 3.14.6. Three fresh processes per language; each JavaScript process includes its own warm-up. The monitor caps Bend at 20 GB RSS; no process reached that cap.

Three-run medians in ms, on the same 2097207 pairs. Native and Python columns are the original packed lanes, not extra warmed runs.

| packed pass | C | Rust | Bun cold | Bun warmed | Node cold | Node warmed | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| identity | 0.344 | 0.266 | 52.524 | 18.217 | 11.460 | 22.509 | 308.218 | 0.704 |
| gcd | 122.179 | 121.839 | 814.415 | 797.142 | 487.313 | 484.627 | 409.997 | 116.602 |
| checked lcm | 122.438 | 122.404 | 842.263 | 813.406 | 482.026 | 485.479 | 604.518 | 117.045 |
| isqrt | 31.308 | 5.278 | 266.784 | 240.380 | 172.773 | 173.480 | 335.301 | 5.973 |

Per-run subtraction estimates in ms, without clamping:

| language | pass | run 1 | run 2 | run 3 | median |
|---|---|---:|---:|---:|---:|
| Bun | cold gcd | 758.156 | 763.456 | 761.891 | 761.891 |
| Bun | warmed gcd | 775.023 | 781.666 | 778.734 | 778.734 |
| Bun | cold checked lcm | 781.752 | 789.827 | 792.087 | 789.827 |
| Bun | warmed checked lcm | 788.814 | 795.971 | 795.171 | 795.171 |
| Bun | cold isqrt | 217.677 | 214.348 | 211.859 | 214.348 |
| Bun | warmed isqrt | 225.009 | 222.236 | 221.972 | 222.236 |
| Node | cold gcd | 474.833 | 475.853 | 477.461 | 475.853 |
| Node | warmed gcd | 462.062 | 461.430 | 462.961 | 462.062 |
| Node | cold checked lcm | 470.402 | 470.022 | 476.174 | 470.402 |
| Node | warmed checked lcm | 464.748 | 462.997 | 462.786 | 462.997 |
| Node | cold isqrt | 161.149 | 161.181 | 161.820 | 161.181 |
| Node | warmed isqrt | 150.429 | 151.003 | 150.971 | 150.971 |

Bun's direct packed loops become faster, but its subtraction estimates increase because identity falls more. Node's warmed identity becomes slower while its isqrt clock stays similar, so its isqrt subtraction estimate falls. This is evidence that loop dispatch and JIT specialization matter; it does not show an arithmetic speed change. No estimate in this batch was negative. All original, packed, warmed, and Bend ownership checksums agree, including the small probe. No library code, laws, imports, or package versions change.

## Controlled JavaScript dispatch and warm-up

The original rows above remain available. The harness now also launches four fresh processes per JavaScript runtime per run: `shared_cold`, `shared_warm`, `direct_cold`, and `direct_warm`. Each process builds the same packed input but skips all original timed rows and their warm-up. To run one mode alone, use `bun stats/bench/bench.ts 2097152 shared_cold` or replace `bun` with `node --no-warnings`. The first argument is the random-pair count; use `16` for the small probe.

Both shared modes measure `packedSum` and its single callback call site. That site belongs to all four operations, not one operation per process. Both direct modes measure four separate loops: identity reads the word directly, and each other loop calls its named integer function directly. The outer driver selects a direct loop once per pass; it does not dispatch a callback per pair. The integer functions and packed inputs are unchanged.

Cold modes run one measured round with no earlier packed pass. Warm modes run three discarded rounds, then one measured round. Every round visits identity, gcd, lcm, and isqrt in that order. Each pass covers the whole input. Warm-up and measurement use the same loop and call sites within each path. Earlier operations can train shared code, including gcd inside lcm, in both cold and warm processes. Thus "cold" means no explicit packed warm-up, not an untrained runtime for every operation.

The four modes run in the order listed above, once per outer run. Each uses a new process and its own allocation. Allocation and warm-up are outside the reported clocks. Each measured clock includes loop traversal, calls, and checksum accumulation. The allocation remains reachable across all passes. Garbage collection and process-to-process noise can still affect a clock. Every warm-up checksum must equal its measured checksum. The harness checks every controlled row against the original packed row, for both the small and full input.

### Results

Command: `python3 stats/bench/run.py 3`, from the repository root. M4 Pro, macOS 26.7.2 (Darwin 25.6.0), arm64, 2026-11-24. Bend 2.0.40, Apple clang 21.0.0 (`-O2`), rustc 1.91.0 (`-C opt-level=3`), Bun 1.4.4, Node 24.0.1, Python 3.14.6. The monitor caps Bend at 20 GB RSS; no process reached the cap.

Three-run medians in ms, over the same 2097207 pairs:

| runtime | op | shared cold | shared warm | direct cold | direct warm |
|---|---|---:|---:|---:|---:|
| Bun | identity | 10.693 | 18.362 | 10.710 | 2.121 |
| Bun | gcd | 818.044 | 802.625 | 817.706 | 802.779 |
| Bun | checked lcm | 816.316 | 816.847 | 726.114 | 724.639 |
| Bun | isqrt | 246.133 | 243.237 | 186.989 | 172.334 |
| Node | identity | 10.476 | 22.367 | 10.558 | 10.463 |
| Node | gcd | 503.462 | 490.836 | 473.876 | 474.078 |
| Node | checked lcm | 496.345 | 491.259 | 487.486 | 484.743 |
| Node | isqrt | 179.296 | 176.070 | 176.233 | 172.577 |

Signed warm-minus-cold deltas in ms. Each delta pairs the two fresh processes from the same outer run. The last column is the median of those deltas, not the difference of the displayed medians.

| runtime | path and op | run 1 | run 2 | run 3 | median |
|---|---|---:|---:|---:|---:|
| Bun | shared identity | +7.669 | +14.455 | +6.268 | +7.669 |
| Bun | shared gcd | -9.144 | -15.424 | +4.945 | -9.144 |
| Bun | shared checked lcm | +4.747 | +0.531 | +11.373 | +4.747 |
| Bun | shared isqrt | -2.896 | -3.598 | -1.047 | -2.896 |
| Bun | direct identity | -9.482 | -8.560 | -1.449 | -8.560 |
| Bun | direct gcd | -13.777 | -14.927 | -22.060 | -14.927 |
| Bun | direct checked lcm | -1.584 | -3.948 | -1.475 | -1.584 |
| Bun | direct isqrt | -17.027 | -9.232 | -14.655 | -14.655 |
| Node | shared identity | +12.639 | +11.725 | +11.626 | +11.725 |
| Node | shared gcd | -14.121 | -14.645 | -12.626 | -14.121 |
| Node | shared checked lcm | -2.064 | -5.321 | -5.086 | -5.086 |
| Node | shared isqrt | -3.226 | +0.030 | -4.781 | -3.226 |
| Node | direct identity | -0.385 | +0.141 | -0.095 | -0.095 |
| Node | direct gcd | -2.383 | -1.238 | +1.674 | -1.238 |
| Node | direct checked lcm | -2.743 | -3.761 | -1.697 | -2.743 |
| Node | direct isqrt | -2.967 | -4.828 | -3.571 | -3.571 |

With the loop and callback site held fixed, shared identity becomes slower after the stated warm-up in both runtimes. Bun direct identity instead becomes faster. Bun's warmed direct lcm and isqrt are also faster than its warmed shared path. These path comparisons include loop shape and call-site specialization; they do not identify a particular JIT tier or isolate callback instruction cost. The warm-minus-cold comparison changes only the explicit warm-up schedule within each path, but still includes independent-process noise. A fixed process order does not control thermal or scheduling drift.

The harness also prints signed per-run kernel-minus-identity estimates for all four controlled modes. Those estimates remain traversal-and-dispatch subtraction estimates, not isolated arithmetic clocks. Negative values are not clamped. All six original language lanes, controlled modes, old warmed rows, and Bend ownership rows pass the small and full checksum checks. Controlled identity, gcd, lcm, and isqrt retain checksums `2699619501`, `18047959`, `3181042401`, and `1421540955`. No library code, laws, imports, or package versions change.

## Counterbalanced JavaScript process order

The fixed-order results above remain the baseline. The harness now uses a four-run Williams design for the controlled processes. Each mode occupies each position once per cycle. Each mode also immediately precedes every other mode once within the four runs. The same schedule applies to Bun and Node. The harness prints each runtime's mode order to stderr. It repeats the cycle for additional runs; use a multiple of four for complete balance. A shorter final cycle is incomplete.

| run in cycle | first | second | third | fourth |
|---|---|---|---|---|
| 1 | shared cold | shared warm | direct warm | direct cold |
| 2 | shared warm | direct cold | shared cold | direct warm |
| 3 | direct cold | direct warm | shared warm | shared cold |
| 4 | direct warm | shared cold | direct cold | shared warm |

Only the order of the four full-input controlled processes changes. The original rows, small probe, packed inputs, integer functions, three-pass warm-up schedule, and checksum gates stay the same. Each mode still runs in a fresh process. The small probe uses the original order before the full runs. The original JavaScript rows still run before the four modes in each run. This schedule balances position and immediate predecessor within the controlled group, not every source of thermal, scheduling, garbage collection, or cross-run drift. It does not identify a fixed JIT tier or isolate an arithmetic clock.

Run `python3 stats/bench/order_check.py` from the repository root to check the schedule and subprocess order.

### Counterbalanced results

Command: `python3 stats/bench/run.py 4`, from the repository root, 2026-11-25. M4 Pro, macOS 26.7.2 (Darwin 25.6.0), arm64. Bend 2.0.40, Apple clang 21.0.0 (`-O2`), rustc 1.91.0 (`-C opt-level=3`), Bun 1.4.4, Node 24.0.1, Python 3.14.6. A monitor checked Bend RSS once per second and would stop a process above 20 GB; none reached the cap.

Each runtime used runs 1–4 of the order table above, with 2097207 pairs per process. All six language lanes passed the existing small and full checksum gates. All warm-up, controlled-mode, and ownership checks passed. Controlled identity, gcd, checked lcm, and isqrt retain checksums `2699619501`, `18047959`, `3181042401`, and `1421540955`.

Four-run medians in ms:

| runtime | op | shared cold | shared warm | direct cold | direct warm |
|---|---|---:|---:|---:|---:|
| Bun | identity | 10.011 | 18.148 | 8.828 | 2.105 |
| Bun | gcd | 804.990 | 794.947 | 800.542 | 793.045 |
| Bun | checked lcm | 814.186 | 809.716 | 719.732 | 716.942 |
| Bun | isqrt | 242.174 | 241.770 | 183.851 | 171.065 |
| Node | identity | 9.957 | 22.483 | 10.123 | 10.075 |
| Node | gcd | 498.350 | 485.207 | 468.079 | 468.260 |
| Node | checked lcm | 486.161 | 485.172 | 480.738 | 478.735 |
| Node | isqrt | 174.024 | 173.611 | 174.262 | 169.959 |

Signed warm-minus-cold deltas in ms. Each delta pairs processes from the same outer run. Medians summarize the per-run deltas, not the difference of mode medians. The fixed column repeats the three-run median from the fixed-order baseline above.

| runtime | path and op | run 1 | run 2 | run 3 | run 4 | balanced median | fixed median |
|---|---|---:|---:|---:|---:|---:|---:|
| Bun | shared identity | +8.771 | +3.847 | +8.293 | +7.972 | +8.133 | +7.669 |
| Bun | shared gcd | -2.464 | -18.042 | -13.037 | -2.043 | -7.750 | -9.144 |
| Bun | shared checked lcm | -1.851 | -9.674 | -2.719 | +0.145 | -2.285 | +4.747 |
| Bun | shared isqrt | -0.889 | -0.574 | +1.415 | -0.514 | -0.544 | -2.896 |
| Bun | direct identity | -12.116 | -1.257 | -12.809 | -1.330 | -6.723 | -8.560 |
| Bun | direct gcd | -5.794 | -8.905 | -6.792 | -6.278 | -6.535 | -14.927 |
| Bun | direct checked lcm | -4.261 | -0.754 | -4.827 | -3.060 | -3.661 | -1.584 |
| Bun | direct isqrt | -14.005 | -10.513 | -14.124 | -11.503 | -12.754 | -14.655 |
| Node | shared identity | +12.393 | +12.187 | +12.368 | +13.049 | +12.381 | +11.725 |
| Node | shared gcd | -9.149 | -17.161 | -13.150 | -10.705 | -11.928 | -14.121 |
| Node | shared checked lcm | -1.984 | -0.950 | +1.586 | -2.179 | -1.467 | -5.086 |
| Node | shared isqrt | -0.377 | -0.244 | -3.337 | +0.562 | -0.310 | -3.226 |
| Node | direct identity | +0.295 | -0.207 | +0.045 | +0.180 | +0.112 | -0.095 |
| Node | direct gcd | -1.263 | +0.928 | -0.566 | +2.103 | +0.181 | -1.238 |
| Node | direct checked lcm | -2.611 | -1.395 | +1.718 | -4.197 | -2.003 | -2.743 |
| Node | direct isqrt | -5.852 | -5.940 | -1.440 | -4.494 | -5.173 | -3.571 |

Shared identity remains slower after warm-up in both runtimes. Bun direct identity and direct isqrt remain faster. Bun shared gcd still varies: the balanced deltas range from -18.042 to -2.043 ms, versus -15.424 to +4.945 ms in the fixed-order sample. Bun shared lcm changes median sign. Node direct identity and gcd also change median sign, but their per-run deltas still cross zero.

Thus the earlier numerical deltas are not stable constants. The broad identity-path result survives this order cycle, while small effects remain noisy. The fixed baseline and balanced cycle were collected on different dates, not interleaved, and each schedule has only one sample block. These observations cannot attribute the difference to process order alone or prove that order has no effect. Repeated balanced and fixed blocks would be needed to separate schedule effects from between-block drift. The clocks still include traversal, dispatch, checksum work, and runtime behavior; neither this comparison nor kernel-minus-identity subtraction isolates arithmetic or a fixed JIT tier.

## Interleaved fixed and counterbalanced blocks

Run `python3 -u stats/bench/blocks.py` from the repository root. This first runs the six-language harness once, including its small probe, original rows, and checksum gates. It then runs six JavaScript blocks in this order: fixed, balanced, balanced, fixed, fixed, balanced. Each runtime gets three four-run blocks per schedule. Each balanced block uses one complete Williams cycle from the table above. Each fixed block repeats `shared_cold -> shared_warm -> direct_cold -> direct_warm` four times.

Bun runs before Node in odd blocks; Node runs before Bun in even blocks. Every outer run retains the original JavaScript rows before its four fresh controlled processes. The packed input, integer functions, per-mode operation order, and three discarded warm-up rounds stay unchanged. Every run checks all original and diagnostic rows against the full C checksums already checked by the six-language harness. The output records block order, runtime order, mode order, signed per-run deltas, block medians, and per-block minimum and maximum deltas. The final table compares medians of block medians and their ranges. No library file or package version changes.

This is a descriptive comparison, not a randomized causal experiment. Blocks retain time order and only three repetitions per schedule. Runtime order also alternates rather than randomizes. Drift, scheduling, garbage collection, and cross-process runtime behavior remain possible causes of differences. These clocks do not isolate arithmetic or identify a fixed JIT tier.

### Interleaved results

Command: `python3 -u stats/bench/blocks.py`, 2026-11-26. M4 Pro, macOS 26.7.2 (Darwin 25.6.0), arm64. Bend 2.0.40, Apple clang 21.0.0 (`-O2`), rustc 1.91.0 (`-C opt-level=3`), Bun 1.4.4, Node 24.0.1, Python 3.14.6. A one-second monitor capped Bend at 20 GB RSS; peak observed RSS was 657616 KiB.

All six languages passed the small and full checksum gates. All 48 JavaScript outer runs passed the original, packed, warmed, and controlled checksum gates. Each outer run launched four fresh controlled processes. Full controlled identity, gcd, checked lcm, and isqrt checksums remain `2699619501`, `18047959`, `3181042401`, and `1421540955`.

[The complete output](interleaved-results.txt) records the baseline rows, every process order, signed per-run warm-minus-cold deltas, block medians, and each block's minimum and maximum delta. The table below gives the three block medians in time order within each schedule. The difference is balanced median-of-block-medians minus fixed median-of-block-medians. Spread is maximum minus minimum block median. All values are ms; calculations use unrounded deltas.

| runtime | path and op | fixed block medians | balanced block medians | balanced-fixed | fixed spread | balanced spread |
|---|---|---|---|---:|---:|---:|
| Bun | shared identity | +12.475, +4.801, +10.477 | +11.440, +11.399, +10.885 | +0.921 | 7.674 | 0.555 |
| Bun | shared gcd | -13.455, -10.025, -9.908 | -12.561, -11.061, -11.073 | -1.048 | 3.547 | 1.500 |
| Bun | shared checked lcm | -1.212, -1.688, +1.001 | -0.945, -3.078, +3.496 | +0.267 | 2.688 | 6.574 |
| Bun | shared isqrt | -0.157, -1.690, -1.785 | -1.489, -0.171, -0.133 | +1.519 | 1.627 | 1.356 |
| Bun | direct identity | -10.395, -6.729, -8.259 | -8.308, -2.997, -1.836 | +5.262 | 3.666 | 6.472 |
| Bun | direct gcd | -14.584, -11.837, -11.107 | -15.240, -8.565, -15.221 | -3.384 | 3.478 | 6.675 |
| Bun | direct checked lcm | -5.970, -3.830, -4.726 | -6.356, -3.267, -3.549 | +1.178 | 2.140 | 3.089 |
| Bun | direct isqrt | -16.259, -14.061, -16.233 | -10.429, -11.544, -15.715 | +4.689 | 2.198 | 5.286 |
| Node | shared identity | +11.886, +12.108, +12.236 | +12.021, +12.158, +12.344 | +0.050 | 0.350 | 0.322 |
| Node | shared gcd | -12.274, -11.066, -12.117 | -12.565, -10.179, -12.060 | +0.058 | 1.207 | 2.386 |
| Node | shared checked lcm | -5.774, +0.531, -4.611 | -5.206, -0.481, -5.416 | -0.594 | 6.305 | 4.935 |
| Node | shared isqrt | -2.355, -1.431, -1.710 | -1.645, -1.123, -1.446 | +0.264 | 0.924 | 0.522 |
| Node | direct identity | -0.204, +0.064, +0.412 | -0.072, +0.360, -0.062 | -0.127 | 0.616 | 0.432 |
| Node | direct gcd | -1.081, -0.655, +0.728 | +0.614, -0.286, -1.630 | +0.369 | 1.809 | 2.244 |
| Node | direct checked lcm | -3.940, -0.720, -2.529 | -3.558, -1.070, -1.946 | +0.583 | 3.220 | 2.488 |
| Node | direct isqrt | -5.141, -5.170, -5.034 | -6.691, -5.392, -5.473 | -0.332 | 0.135 | 1.299 |

Bun shared checked lcm has a +0.267 ms schedule difference, smaller than either between-block spread (2.688 and 6.574 ms). Both schedules contain positive and negative block medians. Its earlier cross-date sign change does not persist as a clear schedule separation. Bun shared gcd differs by -1.048 ms, also smaller than either block spread (3.547 and 1.500 ms).

Bun direct identity and isqrt have larger schedule differences (+5.262 and +4.689 ms). Each exceeds the fixed block spread but remains below the balanced block spread (6.472 and 5.286 ms). Their block ranges overlap. Shared identity remains slower after explicit warm-up, while Bun direct identity and isqrt remain faster, in every block median.

Every Node schedule difference is smaller than at least one corresponding block spread. For direct isqrt, the -0.332 ms difference exceeds the fixed spread of 0.135 ms but not the balanced spread of 1.299 ms; the fixed and balanced block ranges do not overlap in this sample. That is a descriptive separation, not proof of an order effect. The larger balanced spread and ordered collection still leave drift and process noise unresolved.

The sample does not establish a causal order effect beyond between-block variation, nor does it prove that process order has no effect. It does show why one fixed block and one balanced block from different dates cannot support that claim. No isolated arithmetic timing or fixed JIT tier is inferred.
