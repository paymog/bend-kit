# Unicode benchmark

This times `U.nfc` and `U.graphemes` on one fixed input, in Bend (native build) and in JavaScript (Bun and Node) and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median; ~1 MiB UTF-8 input
python3 run.py 5    # 5 runs
python3 run.py 1 65536   # smoke: 64 KiB target, one run
```

You need `bend`, `bun`, `node`, and `python3`. `gen_input.py` writes `out/input.txt`; Bend builds the same text in memory (see below). Binaries go to `out/`, which git ignores. A full run takes about 10 seconds. It exits non-zero if a build fails, or if checksums disagree.

## Input

`gen_input.py` repeats a fixed seed until the UTF-8 size is at least the target (default **1,000,000** bytes). The on-disk file is **1,000,004** bytes and **603,776** code points. The seed includes ASCII, Latin with combining marks, Hangul (jamo and syllables), Devanagari, an emoji ZWJ family sequence, a skin-tone + ZWJ + gender sequence, and regional-indicator flags, with `\n` line breaks.

| piece | role |
|---|---|
| `gen_input.py` | writes `out/input.txt` for Python and JavaScript |
| `bench.bend` | `REPS = 4717` repeats the same code-point list (`seed()`), matching `ceil(1_000_000 / 212)` seed UTF-8 bytes |

Each program builds or loads the input before any timer starts. **MB/s** uses the input UTF-8 byte count over median ms.

## Checksums

After each timed op, every program prints `op<TAB>ms<TAB>checksum`:

| op | checksum |
|---|---|
| `nfc` | `h = h*31 + b` over every UTF-8 byte of the NFC output (u32 wrap), plus the byte length |
| `graphemes` | extended grapheme cluster count |

Expected: **nfc** `4037258967`, **graphemes** `509436`.

Bend evaluates strictly: the result is computed before `Time.mono()` is read for the stop time. UTF-8 encoding for the NFC checksum is not timed.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27. Median of three runs. Bend peak RSS about **39 MiB** on the 1 MiB input (`time -l ./out/bend`).

| op | Bend ms | Bun ms | Node ms | Python ms | Bend MB/s | Bun MB/s | Node MB/s | Python MB/s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| nfc | 23.7 | 1.5 | 1.0 | 11.8 | 42.12 | 668.01 | 973.71 | 85.08 |
| graphemes | 9.6 | 19.9 | 28.9 | n/a | 104.40 | 50.24 | 34.64 | n/a |

Versions: Bend 2.0.31, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | NFC | Grapheme clusters |
|---|---|---|
| Bend | `U.nfc` | `U.graphemes` |
| JavaScript | `String.prototype.normalize('NFC')` | `Intl.Segmenter` with `granularity: 'grapheme'` |
| Python | `unicodedata.normalize('NFC', ...)` | left out: no standard-library equivalent |
| C, Rust | left out: no standard-library equivalent | left out |

Python reads `out/input.txt` with `read_bytes().decode('utf-8')` so `\n` bytes are preserved. Bend does not read the file: `File.open` text mode would alter newlines, and the input is a `String` (one list cell per code point), so the bench builds it with `seed()` and `rep` like `encoding/bench`.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- Grapheme rules follow the engine (Bend: Unicode **17.0.0** tables; V8 `Intl.Segmenter` on this input agrees with Bend).
- These are micro-benchmarks on one machine.
