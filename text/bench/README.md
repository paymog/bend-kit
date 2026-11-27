# Text benchmark

This times the three hot paths of `text`: a line diff, Levenshtein distance, and word wrap. It compares them with popular libraries in Rust, JavaScript, and Python.

## Run

Run these commands from `text/bench/`.

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cargo`, `bun`, `node`, `uv`, and `python3`. Binaries go to `out/`, which git ignores. The script exits non-zero if a build fails, or if the programs disagree on a checksum.

## The ops

Every program makes the same input from the same generator: x ← (x × 1103515245 + 12345) mod 2^32, then the low 31 bits. A word takes 4 + (x >> 16) mod 9 lowercase letters, and each letter is `a` + (x >> 16) mod 26.

- `diff`: the old list is the 10,000 lines `line 0` to `line 9999`. The new list changes line i to `changed i` when i mod 50 = 7, drops it when i mod 70 = 11, and adds `added i` after it when i mod 90 = 13. The checksum is the count of deleted and inserted lines. Every line is unique, so every library finds the same count. Bend gets the two texts as strings and its time includes splitting them into lines; the others get line arrays.
- `distance`: 20,000 pairs of words from the stream, from seed 1. The time includes making the words. The checksum is the sum of the distances.
- `wrap`: 20,000 words from seed 1, joined with spaces, wrapped to 72 columns. The checksum is the line count and the total length of the lines.
- `wrap_utf`: the same, with each letter Cyrillic `а` + (x >> 16) mod 26 (U+0430 to U+0449). Each is one code point and one column, so every library agrees on the lines, and none is ASCII. The checksum counts code points.

| language | diff | distance | wrap, wrap_utf |
|---|---|---|---|
| Bend | `Text.diff_lines(a, b)` | `Text.distance(a, b)` | `Text.wrap(text, 72)` |
| Rust | `similar::capture_diff_slices(Algorithm::Myers, ..)` | `strsim::levenshtein` | `textwrap::wrap` |
| JavaScript | `diff` (jsdiff) `diffArrays` | `fastest-levenshtein` `distance` | — |
| Python | `difflib.SequenceMatcher(autojunk=False).get_opcodes()` | `rapidfuzz.distance.Levenshtein.distance` | `textwrap.wrap` |

## Results

M4 Pro, macOS 26.6.2, 2026-11-20. Five runs (`python3 run.py 5`), median, in ms.

Versions: Bend 2.0.38, rustc 1.91.0 with similar 3.2.1, strsim 0.11.1, and textwrap 0.16.4, Bun 1.4.4 and Node 24.0.1 with diff 9.0.0 and fastest-levenshtein 1.0.16, Python 3.14.6 with rapidfuzz 3.14.3.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| diff | 0.5 | 26.8 | 20.3 | 28.8 | 6.4 |
| distance | 3.2 | 5.1 | 5.1 | 58.5 | 15.4 |
| wrap | 3.9 | — | — | 12.4 | 13.3 |
| wrap_utf | 4.6 | — | — | 15.0 | 20.8 |

Every program prints the checksums 654 for `diff`, 174397 for `distance`, and 2632:177792 for `wrap` and `wrap_utf`.

`text` 0.1.0.0 took 43.8 ms for `diff` and 13.7 ms for `wrap`. 0.2.0.0 took 41.9 ms for `diff` and 44.3 ms for `wrap`, because it measured each candidate line whole. 0.2.1.0 measures a printable ASCII word by its length, then checks each line once; it took 55.3 ms for `wrap_utf`, because it still measured non-ASCII lines whole. 0.2.1.1 segments only the space and the new word.

## Many edits

`unrelated.bend` diffs two N-line lists that share no line, so D = 2N. Run `bend unrelated.bend -o out/unrelated && /usr/bin/time -l out/unrelated N`.

| N | version | time | max RSS |
|---:|---|---:|---:|
| 2,000 | 0.1.0.0 | 1.1 s | 51 MB |
| 10,000 | 0.1.0.0 | 51.2 s | 1.21 GB |
| 4,000 | 0.2.0.0 | 1.2 s | 5.0 MB |
| 10,000 | 0.2.0.0 | 6.9 s | 9.8 MB |
| 10,000 | 0.2.0.1 | 3.0 s | 7.0 MB |
| 10,000 | 0.2.1.0, `diff` | 2.1 s | 7.2 MB |
| 10,000 | 0.2.1.0, `diff_by` with `fnv` | 0.17 s | 7.2 MB |

0.1.0.0 kept one path list per diagonal, so memory grew as D². 0.2.0.0 finds the middle snake from both ends and keeps only the frontiers. 0.2.0.1 keeps the items and frontiers in arrays. The bench runs `diff` with `String.eq`, then `diff_by` with `String.eq` and `fnv` keys, on the same lists.

## Reading it

- `similar` runs the same linear-space Myers on slices. Bend does too: the items and both frontiers are arrays, updated in place. Of Bend's 6.4 ms, splitting the two texts into lines takes about 3.5 ms and Myers on the line hashes about 1.2 ms.
- Myers over the `String` lines takes 23 ms instead of 1.2 ms over their hashes, for the same script. `Array.get` hands out a shared copy of the item, and `String.eq` then pays a reference count on each cell it reads: about 80 ns a char, where walking an owned string with `String.length` takes about 7 ns. A `U32` carries no count.
- Splitting the lines costs about 17 ns a char. Building the lines and their hashes in one pass, or matching chars as `U32`, did not change it.
- Bend's distance keeps one DP row as a list. `strsim` and `fastest-levenshtein` use arrays, and `fastest-levenshtein` uses bit-parallel rows for short strings.
- Bend's wrap runs grapheme segmentation and the display-width table once over each line, to check it. `textwrap` in Python counts code points.

## Not compared

- C: neither the standard library nor a popular library has a diff, Levenshtein, or wrap function. GNU diff is a program, not a library.
- JavaScript wrap: no popular package is the standard choice.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads a scale from argv, so the work cannot run before the clock starts.
- Bend reads the stop time after it prints the checksum. The measured time includes the checksum output.
- One machine, one size, one thread.

## Packed-input line diff

Run `python3 packed.py` from this directory. It builds one native executable,
checks five-line inputs, then runs five pairs on the same 10,000-line workload.
Odd pairs run String then packed; even pairs run packed then String.
Every full-size run checks checksum **654**.

M4 Pro, macOS arm64, 2026-11-24, Bend **2.0.40**, one thread.
Times are milliseconds. RSS is the process peak from `/usr/bin/time -l`, in MiB.

| pair | String diff | packed diff | conversion | full materialization | String RSS | packed RSS |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 8.727625 | 4.834625 | 1.427166 | 4.848667 | 9.500000 | 9.703125 |
| 2 | 8.988708 | 4.785792 | 1.322875 | 4.916375 | 9.500000 | 9.718750 |
| 3 | 9.007458 | 4.931958 | 1.490333 | 4.672458 | 9.500000 | 9.703125 |
| 4 | 8.957333 | 4.699667 | 1.350084 | 4.915375 | 9.515625 | 9.703125 |
| 5 | 8.945084 | 4.761125 | 1.337709 | 4.797750 | 9.515625 | 9.703125 |
| median | **8.957333** | **4.785792** | **1.350084** | **4.848667** | **9.500000** | **9.703125** |

The packed timer starts with two existing Bytes buffers. Conversion from
String finishes before that timer starts. The materialization timer copies
every range on both sides to octet Strings, then joins them. Most callers
should materialize only selected lines. All timers include their checksum
output, as the existing benchmark does. RSS includes input generation,
conversion, diff, and materialization; it does not isolate diff allocations.
The packed path avoids per-character String cells during its scan.
The collision fallback now builds exact packed-word lists; see the measurements below.

The packed median is about 47% below the paired String median. It does not
reach the proposed sub-4-ms target. Converting String inputs and materializing
every output line removes this benefit. This result does not meet or replace
the String API benchmark acceptance in issue #820.

The existing complete package benchmark also ran with `python3 run.py 5`.
Median milliseconds:

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| diff | 0.5 | 26.5 | 19.5 | 28.3 | 8.6 |
| distance | 3.2 | 5.0 | 5.0 | 57.2 | 15.8 |
| wrap | 3.9 | — | — | 12.0 | 13.3 |
| wrap_utf | 4.4 | — | — | 14.5 | 20.6 |

All existing checksums match: 654, 174397, and 2632:177792 for both wrap cases.

## Lazy Myers overlap points

Measured on the same M4 Pro, macOS arm64, Bend 2.0.40, one thread,
2026-11-25. Baseline is `bd8aceb` (`text` 0.2.2.0). Candidate is
`text` 0.2.2.1. Compile the baseline before changing `text.bend`, then run:

```sh
bend packed.bend -o /tmp/text-packed-baseline
# After applying the candidate:
python3 packed.py --baseline /tmp/text-packed-baseline
bend profile.bend -o out/profile
out/profile
python3 run.py 5
```

The retained runner alternates baseline/candidate, then candidate/baseline,
for five pairs. Both binaries run the packed operation, with the same input
and timer boundaries as above. Every full-size checksum is **654**.
Times are milliseconds; peak process RSS is MiB.

| pair | baseline diff | candidate diff | baseline conversion | candidate conversion | baseline materialization | candidate materialization | baseline RSS | candidate RSS |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 4.771458 | 2.077625 | 1.375500 | 1.425458 | 4.947541 | 4.780916 | 9.718750 | 9.718750 |
| 2 | 4.729167 | 2.012416 | 1.380375 | 1.334042 | 4.902250 | 4.788750 | 9.718750 | 9.718750 |
| 3 | 4.877250 | 2.019667 | 1.347334 | 1.363417 | 4.856125 | 4.888583 | 9.718750 | 9.718750 |
| 4 | 4.717292 | 2.061917 | 1.312916 | 1.335083 | 4.853583 | 4.952375 | 9.718750 | 9.718750 |
| 5 | 4.815292 | 2.069000 | 1.403292 | 1.355542 | 4.879417 | 4.878917 | 9.718750 | 9.718750 |
| median | **4.771458** | **2.061917** | **1.375500** | **1.355542** | **4.879417** | **4.878917** | **9.718750** | **9.718750** |

The packed diff median falls by about 57%, below 4 ms. Conversion and full
materialization remain outside the diff timer. RSS still covers the whole
process, not diff-only allocations.

`profile.bend` separates indexed scanning (including FNV hashing and range
records), key-array/frontier setup, Myers plus script construction, and exact
matched-range verification. Three native samples per version:

| version | sample | scan | setup | Myers/script | verification |
|---|---:|---:|---:|---:|---:|
| baseline | 1 | 0.396375 | 0.332625 | 3.679250 | 0.177542 |
| baseline | 2 | 0.359375 | 0.346042 | 3.711625 | 0.179125 |
| baseline | 3 | 0.340083 | 0.326166 | 3.760625 | 0.184958 |
| candidate | 1 | 0.398959 | 0.340167 | 1.008791 | 0.206000 |
| candidate | 2 | 0.356916 | 0.355250 | 0.979250 | 0.193709 |
| candidate | 3 | 0.329916 | 0.317416 | 0.971000 | 0.208875 |
| baseline median | — | 0.359375 | 0.332625 | 3.711625 | 0.179125 |
| candidate median | — | 0.356916 | 0.340167 | 0.979250 | 0.206000 |

The measured cost was in Myers, not byte scanning. `Bool.pick` eagerly built
both candidate meeting points, then `Some`, even when the frontiers did not
overlap. The candidate checks overlap first, then builds only the selected
point. Scanning, hashing, range records, setup, exact verification, and the
collision fallback remain unchanged. The stage harness holds its own range
references, so its stage sum is not a replacement for the full diff timer.
Collision fallback allocation measurements are recorded below.

The complete five-run package benchmark gives these medians in milliseconds:

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| diff | 0.5 | 24.8 | 19.6 | 28.0 | 5.8 |
| distance | 3.2 | 4.9 | 5.1 | 55.5 | 15.9 |
| wrap | 3.9 | — | — | 12.0 | 13.4 |
| wrap_utf | 4.4 | — | — | 14.6 | 20.3 |

All checksums match. String diff remains above 4 ms; issue #820 remains open.
Package checks pass the packed boundary and collision round trips and find
zero non-shortest scripts in 3,000 random pairs.

## Exact-octet collision fallback

Run `python3 collision.py` from this directory. It requires Bend **2.0.40**
and `clang`. It builds native timing and allocation-counting executables.
It first checks eight-line inputs, then records five alternating pairs:
collision/control, control/collision, and so on. Each timing run is followed
by a separate allocation run of the same workload. Raw results also go to
`out/collision-samples.json`.

Each side has 10,000 lines and **1,418,602 octets**. Every hundredth line,
starting at index 7, changes from `aan1wu` to `aa0tfa` (collision) or
`aa0tfb` (control). Other lines contain their unique index. Every line has
the same suffix: 128 `x` octets, NUL, FF, 80, CR, LF. The runner checks that
the first pair has equal FNV-1a hashes and the control does not. A common
suffix preserves an existing FNV collision. Lengths and edit positions
match between workloads.

Both workloads have exactly 100 absent old lines and 100 absent new lines.
The other 9,900 lines occur in order, so the shortest script has **200**
insertions plus deletions. Every run checks that count, reconstructs both
octet inputs from the ranges, and checks both returned owned buffers.
The public `diff_bytes` runs before the staged measurement and passes the
same checks. Existing empty, boundary, collision, and arbitrary-octet
fixtures also run. The collision hash script fails exact verification;
the control passes it. Both final scripts pass.

Stages call the production helpers without changing the pure API:
String-to-Bytes conversion; indexed scan and FNV hashes; hash Myers/script;
exact verification; `byte_diff.pick` (including the exact-octet fallback
only for collisions); and full materialization with round-trip validation.
Input generation and the public API check finish before these timers.
Both buffers stay owned throughout the measured diff. The harness retains
input Strings and range lists for validation, so its absolute costs are not
a replacement for an application benchmark.

Apple M4 Pro, macOS 26.7.2, arm64, 2026-11-26. Bend 2.0.40,
Apple clang 21.0.0, `-O2 -pthread`, one runtime thread. All times are ms.
`clock` is an empty stage with the same timer and snapshot boundaries.

| pair | workload | clock | conversion | scan | hash diff | verify | fallback | materialize/check |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | collision | 0.054834 | 23.040625 | 2.372042 | 0.893708 | 1.163083 | 237.817500 | 123.221666 |
| 1 | control | 0.059166 | 23.048375 | 2.461542 | 1.143167 | 1.206000 | 0.273250 | 110.172500 |
| 2 | collision | 0.063167 | 23.290125 | 2.451709 | 0.918000 | 1.210916 | 237.001458 | 114.100000 |
| 2 | control | 0.069375 | 22.977084 | 2.565375 | 1.148125 | 1.191791 | 0.295208 | 107.104708 |
| 3 | collision | 0.060834 | 23.145959 | 2.468459 | 0.924166 | 1.168625 | 238.092208 | 117.237583 |
| 3 | control | 0.056875 | 23.089042 | 2.380500 | 1.093625 | 1.161750 | 0.238000 | 108.449417 |
| 4 | collision | 0.058750 | 22.861416 | 2.371084 | 0.891791 | 1.174584 | 237.965708 | 120.109125 |
| 4 | control | 0.069459 | 22.273333 | 2.387416 | 1.129584 | 1.165042 | 0.216167 | 113.686791 |
| 5 | collision | 0.051125 | 23.555417 | 2.508541 | 0.905083 | 1.206375 | 247.353791 | 125.759000 |
| 5 | control | 0.057208 | 23.149250 | 2.364041 | 1.081666 | 1.176875 | 0.313666 | 114.948250 |
| median | collision | **0.058750** | **23.145959** | **2.451709** | **0.905083** | **1.174584** | **237.965708** | **120.109125** |
| median | control | **0.059166** | **23.048375** | **2.387416** | **1.129584** | **1.176875** | **0.273250** | **110.172500** |

### Allocation evidence

The runner instruments the generated native runtime's `heap_alloc` entry.
Each request adds one call and `8 << cls` requested bytes. It counts requests
even when the runtime serves them from a free list. It does not count
compiler-generated in-place node reuse, host malloc, or live/peak memory.
These are cumulative allocator-request bytes, **not RSS**. A source-shape
guard rejects a changed allocator. The production source is not modified.
Only the separate counted executable has this instrumentation.

The benchmark-only snapshot effect resets the counters at each boundary.
It excludes its own result String. Clock calls and their Bend wrappers
remain inside each interval; the empty stage records their overhead.
All five samples in each workload produced exactly the counts below.
Thus each row reports all five allocation samples and their median.

| stage | collision calls (each sample/median) | collision bytes (each sample/median) | control calls (each sample/median) | control bytes (each sample/median) |
|---|---:|---:|---:|---:|
| clock | 9,931 | 127,704 | 9,931 | 127,704 |
| conversion | 9,933 | 4,322,072 | 9,933 | 4,322,072 |
| scan | 109,927 | 1,567,864 | 109,927 | 1,567,864 |
| hash diff | 149,954 | 2,463,496 | 159,612 | 2,582,176 |
| verify | 9,931 | 127,896 | 9,931 | 127,896 |
| fallback | 8,671,220 | 93,503,680 | 9,931 | 127,832 |
| materialize/check | 17,153,146 | 210,646,280 | 17,153,146 | 210,646,280 |

The collision fallback interval adds **8,661,289 allocator requests** and
**93,375,848 requested bytes (89.05 MiB)** over the matched control.
That interval includes octet-list construction, exact Myers, script
construction, and disposal of the rejected hash script. Scanning,
conversion, verification, and materialization are outside it.
This is a measurement, not a speed improvement or a peak-memory claim.
`scripts/check.sh text`, `scripts/publish.sh --check`, and `scripts/pins.sh`
were run. No published source changed.

### Packed fallback keys

The fallback now reads four octets per U32 directly from the owned arrays.
Unaligned reads combine adjacent words. Each line key stores its byte length,
its final zero-to-three octets, and the full words in reverse order.
The byte length distinguishes trailing zero octets. Equality still compares
every word; no hash stands in for exact equality. Myers and its tie rules
do not change. No per-line octet-list reversal is needed.

The same command, compiler, machine, input, and alternating order were run
before and after this change on 2026-11-26. The baseline is `ae99a6e`.
Each row below is one timing sample, in ms. Allocation runs are separate.

| source | pair | workload | clock | conversion | scan | hash diff | verify | fallback | materialize/check |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| before | 1 | collision | 0.058500 | 22.682500 | 2.384583 | 0.926208 | 1.190334 | 236.271459 | 122.207375 |
| before | 1 | control | 0.065000 | 22.998375 | 2.334667 | 1.032208 | 1.133875 | 0.236083 | 105.817625 |
| before | 2 | control | 0.057000 | 23.026042 | 2.441625 | 1.114083 | 1.174750 | 0.227334 | 106.681708 |
| before | 2 | collision | 0.058167 | 22.717042 | 2.523458 | 0.900250 | 1.194792 | 234.490917 | 120.293416 |
| before | 3 | collision | 0.069667 | 23.213958 | 2.555083 | 0.928417 | 1.205000 | 238.880208 | 118.360834 |
| before | 3 | control | 0.061792 | 22.598083 | 2.375292 | 1.087041 | 1.206042 | 0.233042 | 108.725625 |
| before | 4 | control | 0.052042 | 23.879375 | 2.491209 | 1.112667 | 1.168583 | 0.224125 | 115.569625 |
| before | 4 | collision | 0.063667 | 23.231042 | 2.487959 | 0.945208 | 1.183541 | 248.093292 | 121.263292 |
| before | 5 | collision | 0.061041 | 23.445584 | 2.438042 | 0.915459 | 1.183708 | 237.535708 | 118.627667 |
| before | 5 | control | 0.073791 | 22.620000 | 2.483334 | 1.088208 | 1.187250 | 0.225708 | 110.918583 |
| after | 1 | collision | 0.060000 | 22.945083 | 2.463708 | 0.866000 | 1.257875 | 54.947125 | 118.955375 |
| after | 1 | control | 0.060291 | 22.851042 | 2.459750 | 1.148208 | 1.191541 | 0.228500 | 112.578958 |
| after | 2 | control | 0.055667 | 23.371750 | 2.566083 | 1.099584 | 1.149166 | 0.229833 | 113.406500 |
| after | 2 | collision | 0.060375 | 22.904209 | 2.460875 | 0.883291 | 1.172958 | 55.285292 | 120.549584 |
| after | 3 | collision | 0.063500 | 23.192417 | 2.481750 | 0.878208 | 1.155750 | 54.206041 | 123.405000 |
| after | 3 | control | 0.053208 | 23.016458 | 2.325334 | 1.059250 | 1.142125 | 0.269250 | 113.317416 |
| after | 4 | control | 0.064792 | 24.235166 | 2.384541 | 1.056166 | 1.103458 | 0.233375 | 111.222000 |
| after | 4 | collision | 0.054500 | 22.694167 | 2.473750 | 0.884667 | 1.154834 | 56.179542 | 123.554208 |
| after | 5 | collision | 0.060667 | 23.091917 | 2.431708 | 0.883333 | 1.147666 | 56.305375 | 117.837709 |
| after | 5 | control | 0.059583 | 22.618375 | 2.486292 | 1.071208 | 1.208000 | 0.244208 | 111.417916 |
| before | median | collision | 0.061041 | 23.213958 | 2.487959 | 0.926208 | 1.190334 | **237.535708** | 120.293416 |
| before | median | control | 0.061792 | 22.998375 | 2.441625 | 1.088208 | 1.174750 | **0.227334** | 108.725625 |
| after | median | collision | 0.060375 | 22.945083 | 2.463708 | 0.883291 | 1.155750 | **55.285292** | 120.549584 |
| after | median | control | 0.059583 | 23.016458 | 2.459750 | 1.071208 | 1.149166 | **0.233375** | 112.578958 |

All five allocation samples and their medians are identical within each
source/workload. The counter and byte definitions are unchanged.

| source | stage | collision calls | collision bytes | control calls | control bytes |
|---|---|---:|---:|---:|---:|
| before and after | clock | 9,931 | 127,704 | 9,931 | 127,704 |
| before and after | conversion | 9,933 | 4,322,072 | 9,933 | 4,322,072 |
| before and after | scan | 109,927 | 1,567,864 | 109,927 | 1,567,864 |
| before and after | hash diff | 149,954 | 2,463,496 | 159,612 | 2,582,176 |
| before and after | verify | 9,931 | 127,896 | 9,931 | 127,896 |
| before | fallback | 8,671,220 | 93,503,680 | 9,931 | 127,832 |
| after | fallback | 1,659,172 | 20,627,920 | 9,931 | 127,832 |
| before and after | materialize/check | 17,153,146 | 210,646,280 | 17,153,146 | 210,646,280 |

Collision fallback time falls **76.7%** (4.30x faster).
Its allocator requests fall **80.9%** and requested bytes fall **77.9%**.
All other stage allocation counts stay identical: the cost did not move.
Materialization time varies slightly; its work and allocation counts do not
change. These remain allocator-request figures, not peak RSS.

The retained runner passes collision detection, 200 shortest-script changes,
arbitrary-octet reconstruction, and both owned-buffer checks. Forced-fallback
checks also cover all four source offsets, different offsets across buffers,
zero-to-eight-octet tails, trailing NUL lengths, and FF/FE differences.

## String line splitting

macOS arm64, 2026-11-27, Bend **2.0.40**, one thread. The baseline is
`e3b01c8`. All experiments use the existing 10,000-line generator, timer
boundaries, checksum consumption, and compiler.

Measure splitting alone from the repository root:

```sh
bend text/bench/lines.bend -o text/bench/out/lines
text/bench/out/lines
```

The harness builds both texts before the clock starts. It times `lines` on
both texts and consumes their lengths. Its checksum is **19,968**. Empty
input, blank lines, final LF, missing final LF, CRLF, and Unicode fixtures
must pass before timing. `Ċ` has low byte 10 but is not LF.

Each candidate also ran `python3 text/bench/run.py 5`. Every language agreed
on checksums **654**, **174397**, and **2632:177792** for both wrap variants.
The table gives the Bend diff median and seven fresh-process split medians.

| approach | package diff, ms | split alone, ms |
|---|---:|---:|
| baseline | 5.9 | 3.339250 |
| direct LF constructor pattern | 5.7 | 3.174167 |
| partial line paired with finished suffix lines | 5.7 | 3.141375 |
| forward tail scan, reverse each line | 5.9 | 3.520333 |
| literal Char predicate, existing Boolean dispatch | 5.9 | 3.364583 |
| literal U32 predicate, unboxed character | 5.9 | 3.372208 |
| carry the next character and LF flag into recursion | 5.9 | 3.391167 |
| partial-line pair with Boolean dispatch | 5.9 | 3.329125 |
| merge Boolean dispatch and list-head update | 5.9 | 3.319375 |
| forward scan with fused FNV-1a, reverse each line | 6.6 | not measured separately |

The first three candidates then ran in 15 fresh-process groups with the
baseline. Odd groups ran baseline, literal, pair, forward; even groups
reversed that order. Each diff process runs the complete package workload.
Each split measurement uses a separate process, so these are not additive
phase times. All diff checksums are 654 and all split checksums are 19,968.

| group | baseline diff | literal diff | pair diff | forward diff | baseline split | literal split | pair split | forward split |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6.212459 | 5.644083 | 5.766666 | 5.896292 | 3.565583 | 3.207500 | 3.062875 | 3.456584 |
| 2 | 5.859333 | 5.616042 | 5.489500 | 5.935375 | 3.327959 | 3.184041 | 3.104416 | 3.448833 |
| 3 | 5.817291 | 5.566834 | 5.523041 | 5.693250 | 3.342375 | 3.168000 | 3.117042 | 3.409708 |
| 4 | 5.865334 | 5.564667 | 5.513542 | 5.706791 | 3.305667 | 3.119791 | 3.095167 | 3.512584 |
| 5 | 5.830708 | 5.935167 | 5.572875 | 5.736166 | 3.307458 | 3.178083 | 3.087417 | 3.424708 |
| 6 | 6.115625 | 5.578500 | 5.637208 | 5.682042 | 3.307667 | 3.131459 | 3.166250 | 3.418542 |
| 7 | 5.847625 | 5.610250 | 5.530958 | 5.735084 | 3.311834 | 3.205000 | 3.118834 | 3.458917 |
| 8 | 5.840000 | 5.655542 | 5.548334 | 5.711125 | 3.292584 | 3.135167 | 3.076375 | 3.483917 |
| 9 | 5.875209 | 5.619375 | 5.561333 | 5.700417 | 3.309042 | 3.193208 | 3.089584 | 3.467583 |
| 10 | 5.835375 | 5.664875 | 5.584042 | 5.736375 | 3.329083 | 3.168083 | 3.115250 | 3.505042 |
| 11 | 5.878917 | 5.579667 | 5.738833 | 5.847875 | 3.353916 | 3.237500 | 3.258500 | 3.456042 |
| 12 | 5.914083 | 5.601958 | 5.779750 | 5.874750 | 3.341000 | 3.188958 | 3.116500 | 3.582375 |
| 13 | 5.773959 | 5.593917 | 5.601834 | 5.674208 | 3.304458 | 3.192750 | 3.085084 | 3.439958 |
| 14 | 6.002584 | 5.594250 | 5.518375 | 5.700625 | 3.286083 | 3.163667 | 3.160375 | 3.446916 |
| 15 | 5.848291 | 5.823916 | 5.608917 | 5.722334 | 3.287917 | 3.276125 | 3.122458 | 3.540750 |
| median | **5.859333** | **5.610250** | **5.572875** | **5.722334** | **3.309042** | **3.184041** | **3.115250** | **3.456584** |

A second 15-group comparison checked the Boolean-dispatch candidates.
It used the same alternating order and checksums.

| approach | diff median, ms | split median, ms |
|---|---:|---:|
| baseline | 5.872417 | 3.339041 |
| merged dispatch | 5.912500 | 3.362125 |
| partial-line pair | 5.956250 | 3.332125 |
| next-character state | 5.913542 | 3.373542 |
| Char predicate | 5.869958 | 3.390125 |
| U32 predicate | 5.972541 | 3.339042 |

The retained direct pattern lowers the diff median **4.25%** and the split
median **3.78%**. It wins 14 of 15 diff groups and all 15 split groups.
The pair representation saves another 0.037375 ms on the diff median.
That small difference does not justify its extra state and helpers.

The original below-4-ms String diff target is **not met**. The revised
target is a repeatable String-path gain with the same input, checksum, API,
and universal reconstruction laws. No packed-input result substitutes for
the String measurement. The LF proof handles each first differing U32 bit
explicitly; a numeric-pattern catch-all does not reduce in the checker.

The final retained build ran the full package benchmark again: Bend diff
**5.8 ms**, distance **16.1 ms**, wrap **13.4 ms**, and wrap_utf **20.6 ms**.
All checksums still agree. Its seven split samples were 3.168542, 3.201250,
3.147125, 3.203250, 3.158500, 3.247791, and 3.160167 ms; median **3.168542 ms**.
`scripts/check.sh text`, `scripts/publish.sh --check text`, and
`scripts/pins.sh origin/main text` pass. Both universal reconstruction laws
remain proved, and both 3,000-case randomized checks report zero failures.
