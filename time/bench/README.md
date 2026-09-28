# Time benchmark

This times an RFC 3339 round trip: format an instant as UTC text, then parse the text back to Unix seconds.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `cargo`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 15 seconds. It exits non-zero if a build fails, or if two programs disagree on the checksum.

## The input

N = 4096 instants, whole seconds, from t = -2208988800 (1900-01-01T00:00:00Z) in steps of 3155761 s, so they span 1900 to 2309 and include instants before the epoch. Each program formats t as `YYYY-MM-DDTHH:MM:SSZ`, parses that text back, and adds the text's byte values and the parsed seconds (as a wrapping `u32`) to the checksum.

| language | format | parse |
|---|---|---|
| Bend | `Time.rfc3339` | `Time.rfc3339.parse` |
| C | `gmtime_r`, `strftime` | `strptime`, `timegm` |
| Rust | chrono 0.4.45 `to_rfc3339_opts(SecondsFormat::Secs, true)` | `DateTime::parse_from_rfc3339` |
| JavaScript | `Date.prototype.toISOString`, with `.000Z` cut to `Z` | `Date.parse` |
| Python | `datetime.strftime` | `datetime.fromisoformat` |

Rust's standard library has no calendar, so the Rust side uses chrono.

## Results

M4 Pro, macOS, 2026-09-27. Bend 2.0.31, Apple clang 17.0.0 (`-O2`), rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs.

| variant | trip ms | us per trip | vs fastest |
|---:|---:|---:|---:|
| C | 14.9 | 3.64 | 81.9x |
| Rust | 0.2 | 0.04 | 1.0x |
| Bun | 2.3 | 0.55 | 12.4x |
| Node | 4.3 | 1.04 | 23.4x |
| Python | 8.9 | 2.18 | 49.1x |
| Bend | 1,043.2 | 254.69 | 5731.9x |

Every program prints the checksum 1872943518.

## Reading it

- The calendar math runs on `U32`, but the seconds are an `Int.I64`, which is `Word(64n)`: a list of 64 `Bool` cells. Formatting divides by 86400 in `I64`, and parsing multiplies and adds in `I64`. Native `U64` in Base (bendlang/bend#1027) would let `I64` run on machine words.
- C is slower than Bun and Python here. Its time is in macOS libc (`gmtime_r`, `strftime`, `strptime`, `timegm`); it was not profiled.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one thread.
