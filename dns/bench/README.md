# DNS benchmark

Times `Dns.query` and `Dns.answer` on one fixed message, with no socket, against the C resolver library.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, and `python3`. Binaries go to `out/`, which git ignores. The run takes a few seconds. It exits non-zero if a build fails or the checksums disagree.

## The ops

Each op runs 100,000 rounds. Round `i` uses the id `i & 65535`, so no round can reuse the work of another.

| op | work | checksum |
|---|---|---|
| `build` | build the A/IN query for `www.example.com` with recursion desired (33 bytes) | sum of every query byte |
| `parse` | check the header of a 49-byte response, skip the question, and return the first A/IN answer (`93.184.216.34`, named by a pointer) as dotted text | sum of every character of the dotted text |

Checksum math is u32 and wraps. The response is the id followed by the bytes in `tail()` in `bench.bend` and `TAIL` in `bench.c`.

- C: `res_mkquery` builds, and `ns_initparse` and `ns_parserr` parse. Both come from libresolv, which ships with macOS and glibc. `res_mkquery` sets a random id, so the program overwrites the first two bytes. `snprintf` makes the dotted text.
- Bend: `bench.bend` calls `Dns.query` and `Dns.answer` from `../dns.bend`.

Rust, Python, and JavaScript are left out. Their standard libraries resolve names through the OS, but none of them builds or parses a DNS message.

## Results

M4 Pro, macOS, 2026-09-27. Median of three runs. Times are in ms for 100,000 rounds; `Nx` is the multiple of the faster variant.

Versions: Bend 2.0.31, Apple clang 17.0.0.

| op | C | Bend |
|---|---:|---:|
| build | 17.6 (1.0x) | 87.1 (4.9x) |
| parse | 13.6 (1.0x) | 103.5 (7.6x) |

Checksums: build 167500816, parse 65900000. Both variants agree.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- Bend messages are `String`s, one `Char` list cell per byte. The gap measures that layout as much as the parser.
