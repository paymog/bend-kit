# tty width benchmark

This times `Tty.width` and `Tty.pad_right` against C's libc `wcswidth` and a Python version built on `unicodedata`.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, and `python3`. Binaries go to `out/`, which git ignores. The C program needs a UTF-8 locale: it tries `en_US.UTF-8`, then `C.UTF-8`, so it runs on macOS and glibc Linux. `run.py` exits non-zero if a build fails, or if two programs disagree on any checksum.

## The work

N = 20000 strings from the u32 LCG `s = s*1664525 + 1013904223`, seeded with 1. One word gives the string's length, 1 + (s >> 16) % 16 code points. Each code point then takes one word: with v = s >> 8, the class is v % 9 and the offset is v / 9 mod the class span.

| class | code points | columns |
|---|---|---|
| 0, 1, 2 | ASCII `!` to `~` | 1 |
| 3 | Greek `α` to `ω` (East Asian Ambiguous, taken as narrow) | 1 |
| 4 | CJK U+4E00 to U+51FF | 2 |
| 5 | Hangul syllables U+AC00 to U+ADFF | 2 |
| 6 | Hiragana U+3041 to U+3096 | 2 |
| 7 | Combining marks U+0300 to U+0333 | 0 |
| 8 | Fullwidth forms U+FF01 to U+FF5E | 2 |

Every program builds its strings before it starts the clock.

- `width`: the sum of every string's display width.
- `pad`: `pad_right(s, 20)` for every string. The checksum is 32-bit FNV-1a over the code points of each padded string, each followed by `\n`. `padlen` counts those code points.

The input has no emoji, ZWJ sequences, variation selectors, or control characters. libc `wcwidth` and Python `unicodedata` follow different Unicode versions and disagree with Unicode 17 on those. Every code point above has the same width in Unicode 9 through 17, so all three programs must agree.

| language | width |
|---|---|
| Bend | `Tty.width`: Unicode 17 East Asian Width and zero-width tables |
| C | libc `wcswidth` under a UTF-8 locale |
| Python | 0 if `unicodedata.combining(c)`, 2 if `east_asian_width(c)` is `W` or `F`, else 1 |

## Results

On Darwin arm64 with Bend 2.0.32, Apple clang 17.0.0 and Python 3.14.6, `python3 run.py` (three runs, median) produced:

| operation | C | Python | Bend |
|---|---:|---:|---:|
| width (ms) | 3.289 | 10.482 | 6.022 |
| pad (ms) | 3.727 | 42.964 | 11.851 |

All three produced `width=227110`, `pad=149484683`, and `padlen=367672`.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. C uses `CLOCK_MONOTONIC`, Python `perf_counter_ns`.
- C works on fixed `wchar_t` buffers. Python and Bend build new strings.
- One machine, one thread.
