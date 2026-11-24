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
The packed path avoids per-character String cells during its scan. The
collision fallback still builds exact octet lists.

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
