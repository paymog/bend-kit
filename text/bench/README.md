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

- `diff`: the old list is the 10,000 lines `line 0` to `line 9999`. The new list changes line i to `changed i` when i mod 50 = 7, drops it when i mod 70 = 11, and adds `added i` after it when i mod 90 = 13. The checksum is the count of deleted and inserted lines. Every line is unique, so every library finds the same count.
- `distance`: 20,000 pairs of words from the stream, from seed 1. The time includes making the words. The checksum is the sum of the distances.
- `wrap`: 20,000 words from seed 1, joined with spaces, wrapped to 72 columns. The checksum is the line count and the total length of the lines.

| language | diff | distance | wrap |
|---|---|---|---|
| Bend | `Text.diff(~String, ~String.eq, a, b)` | `Text.distance(a, b)` | `Text.wrap(text, 72)` |
| Rust | `similar::capture_diff_slices(Algorithm::Myers, ..)` | `strsim::levenshtein` | `textwrap::wrap` |
| JavaScript | `diff` (jsdiff) `diffArrays` | `fastest-levenshtein` `distance` | — |
| Python | `difflib.SequenceMatcher(autojunk=False).get_opcodes()` | `rapidfuzz.distance.Levenshtein.distance` | `textwrap.wrap` |

## Results

M4 Pro, macOS 26.6.2, 2026-11-18. Five runs (`python3 run.py 5`), median, in ms.

Versions: Bend 2.0.38, rustc 1.91.0 with similar 3.2.1, strsim 0.11.1, and textwrap 0.16.4, Bun 1.4.4 and Node 24.0.1 with diff 9.0.0 and fastest-levenshtein 1.0.16, Python 3.14.6 with rapidfuzz 3.14.3.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| diff | 0.6 | 29.2 | 23.0 | 29.7 | 43.8 |
| distance | 3.1 | 5.6 | 5.4 | 58.1 | 14.3 |
| wrap | 3.9 | — | — | 12.5 | 13.7 |

Every program prints the checksums 654 for `diff`, 174397 for `distance`, and 2632:177792 for `wrap`.

## Reading it

- `similar` trims the common prefix and suffix and runs a linear-space Myers on slices. Bend walks linked lists, keeps one path list per diagonal, and compares lines as `String`s, char by char.
- Bend's distance keeps one DP row as a list. `strsim` and `fastest-levenshtein` use arrays, and `fastest-levenshtein` uses bit-parallel rows for short strings.
- Bend's wrap measures every word through grapheme segmentation and the display-width table. `textwrap` in Python counts code points.

## Not compared

- C: neither the standard library nor a popular library has a diff, Levenshtein, or wrap function. GNU diff is a program, not a library.
- JavaScript wrap: no popular package is the standard choice.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads a scale from argv, so the work cannot run before the clock starts.
- Bend reads the stop time after it prints the checksum. The measured time includes the checksum output.
- One machine, one size, one thread.
