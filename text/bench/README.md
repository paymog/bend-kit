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

| language | diff | distance | wrap |
|---|---|---|---|
| Bend | `Text.diff_lines(a, b)` | `Text.distance(a, b)` | `Text.wrap(text, 72)` |
| Rust | `similar::capture_diff_slices(Algorithm::Myers, ..)` | `strsim::levenshtein` | `textwrap::wrap` |
| JavaScript | `diff` (jsdiff) `diffArrays` | `fastest-levenshtein` `distance` | — |
| Python | `difflib.SequenceMatcher(autojunk=False).get_opcodes()` | `rapidfuzz.distance.Levenshtein.distance` | `textwrap.wrap` |

## Results

M4 Pro, macOS 26.6.2, 2026-11-19. Five runs (`python3 run.py 5`), median, in ms.

Versions: Bend 2.0.38, rustc 1.91.0 with similar 3.2.1, strsim 0.11.1, and textwrap 0.16.4, Bun 1.4.4 and Node 24.0.1 with diff 9.0.0 and fastest-levenshtein 1.0.16, Python 3.14.6 with rapidfuzz 3.14.3.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| diff | 0.5 | 31.2 | 23.5 | 31.5 | 41.9 |
| distance | 3.0 | 6.6 | 6.4 | 63.4 | 14.6 |
| wrap | 5.1 | — | — | 12.8 | 44.3 |

Every program prints the checksums 654 for `diff`, 174397 for `distance`, and 2632:177792 for `wrap`.

`text` 0.1.0.0 took 43.8 ms for `diff` and 13.7 ms for `wrap`. Wrap is slower now because it measures each candidate line whole, which its width proof needs.

## Many edits

`unrelated.bend` diffs two N-line lists that share no line, so D = 2N. Run `bend unrelated.bend -o out/unrelated && /usr/bin/time -l out/unrelated N`.

| N | version | time | max RSS |
|---:|---|---:|---:|
| 2,000 | 0.1.0.0 | 1.1 s | 51 MB |
| 10,000 | 0.1.0.0 | 51.2 s | 1.21 GB |
| 4,000 | 0.2.0.0 | 1.2 s | 5.0 MB |
| 10,000 | 0.2.0.0 | 6.9 s | 9.8 MB |

0.1.0.0 kept one path list per diagonal, so memory grew as D². 0.2.0.0 finds the middle snake from both ends and keeps only the frontiers.

## Reading it

- `similar` runs the same linear-space Myers on slices. Bend walks linked lists and allocates a tip for each diagonal in each round. Comparing lines as interned `U32` ids instead of `String`s cut the Myers part from 45 ms to 39 ms, but interning 20,000 lines in a Base `Map` cost 18 ms, so `diff_lines` compares strings.
- Bend's distance keeps one DP row as a list. `strsim` and `fastest-levenshtein` use arrays, and `fastest-levenshtein` uses bit-parallel rows for short strings.
- Bend's wrap runs grapheme segmentation and the display-width table over each candidate line. `textwrap` in Python counts code points.

## Not compared

- C: neither the standard library nor a popular library has a diff, Levenshtein, or wrap function. GNU diff is a program, not a library.
- JavaScript wrap: no popular package is the standard choice.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads a scale from argv, so the work cannot run before the clock starts.
- Bend reads the stop time after it prints the checksum. The measured time includes the checksum output.
- One machine, one size, one thread.
