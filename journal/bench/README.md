# Journal benchmark

This times recovery at open: decoding a journal of frames, checking each CRC-32, and folding the records. It compares `journal` with a straight scan in C, Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median, 2^20 records
python3 run.py 5    # 5 runs
```

You need `bend` (2.0.36), `clang` with zlib, `cargo`, `bun`, `node`, and `python3`. Cargo fetches `crc32fast` 1.5.0. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, a program prints no result, or two programs disagree on the checksum or the record count.

## Input

R = 2^20 records (1,048,576). Record `i` has payload length `16 + (i * 7 mod 48)` octets. Octet `j` is `(i * 31 + j) & 255`. A frame is `len` u32le, `~len` u32le, CRC-32 of the payload u32le, then the payload. The longest payload is 63 octets, and recovery refuses a payload longer than 64.

Each program builds that log before the timer starts. The timed region scans every frame, checks `~len` and the CRC-32, folds `acc = acc * 31 + len + first payload octet` in wrapping u32, and counts records. 2^16 takes about 19 ms in native Bend, under the 100 ms floor, so the run uses 2^20.

| language | scan |
|---|---|
| Bend | `J.replay.bytes(~U32, ~step, 64, buf, 0)` |
| C | zlib `crc32` |
| Rust | `crc32fast` 1.5.0 |
| Python | `zlib.crc32` and `struct.unpack_from` |
| JavaScript | `zlib.crc32` from `node:zlib` |

Bun 1.3.14 and Node 24.0.1 both have `zlib.crc32`, so neither needs a package.

## Results

Apple M4 Pro, macOS 26.6.2 arm64, 2026-10-11. Three runs (`python3 run.py`), median, in ms. `Nx` is the multiple of the fastest variant.

Versions: Bend 2.0.36, Apple clang 17.0.0, rustc 1.91.0, crc32fast 1.5.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| recover | 28.6 (1.0x) | 39.6 (1.4x) | 388.3 (13.6x) | 138.5 (4.8x) | 737.5 (25.8x) | 302.9 (10.6x) |

Every program prints checksum `1372270592` and `1048576` records.

## Reading it

Bend's number is `replay.bytes`. Each record calls `Hash.crc32`, which rebuilds its 256-entry table (`journal.bend`, the ponytail note on `cur.sum`). The other programs call a library CRC-32 that keeps one table. That rebuild is the likely cause of most of the gap; this bench does not separate it from the frame walk.

Bend prints the argv count only after replay returns a clean log whose cursor is at the end of the buffer. The checksum is the fold, and it matches the scans that count each frame.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads R from argv, so the replay cannot run before the clock starts. Building the log, including `J.frame`, is outside the timer.
- One machine, one size, one thread.
- The C, Rust, Python, and JavaScript loops are the obvious scan over a library CRC-32. They are not a second journal.
