# Encoding benchmark

This times UTF-8 encode and decode (`encoding`) and hex encode and decode (`Bytes.to_hex` and `Bytes.from_hex`) on one fixed input, in Bend and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 20 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

The seed is `Hello é Ω € 中 😀\n`: 16 code points, 25 UTF-8 bytes, with 1-, 2-, 3-, and 4-byte sequences. Each program repeats it 2^18 times:

| op | input | output |
|---|---|---|
| `utf8_encode` | text, 4,194,304 code points | 6,553,600 bytes |
| `utf8_decode` | those 6,553,600 bytes | 4,194,304 code points |
| `hex_encode` | those 6,553,600 bytes | 13,107,200 hex digits |
| `hex_decode` | those 13,107,200 hex digits | 6,553,600 bytes |

Each program builds its inputs before any timer starts, and times only the op. After the timer stops, it prints a checksum of the output: `h = h*31 + x` over the bytes or code points, in wrapping u32, plus the length. The checksums are `2586050560`, `2599682048`, `4003201024`, and `2586050560`, in table order.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27, `encoding` 0.3.0.0. Median of three runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| utf8_encode | 6.2 (2.3x) | 3.7 (1.4x) | 2.6 (1.0x) | 8.1 (3.0x) | 4.7 (1.8x) | 30.8 (11.7x) |
| utf8_decode | 7.8 (1.8x) | 4.7 (1.1x) | 4.4 (1.0x) | 10.8 (2.5x) | 5.6 (1.3x) | 32.1 (7.4x) |
| hex_encode | n/a | n/a | 1.0 (1.0x) | 2.9 (2.8x) | 4.0 (3.9x) | 46.3 (44.7x) |
| hex_decode | n/a | n/a | 4.6 (1.1x) | 4.3 (1.0x) | 4.2 (1.0x) | 91.2 (21.5x) |

`encoding` 0.2.1.0 kept octets as a `String`, one list cell per byte, and built each output reversed. On the same machine its Bend times were 68, 47, 135, and 83 ms. The move to `Bytes` made encode 2.2x faster and decode 1.5x faster. Hex encode is 3x faster because `Bytes.to_hex` reads a packed buffer. Hex decode did not change, because hex digits are still a `String` on the way in.

Versions: Bend 2.0.31, Apple clang 17.0.0, rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | UTF-8 encode | UTF-8 decode | hex |
|---|---|---|---|
| Bend | `Enc.utf8.encode` to `Bytes` | `Enc.utf8.decode` from `Bytes` | `Bytes.to_hex`, `Bytes.from_hex` |
| C | `wcsrtombs` from `wchar_t[]` | `mbsrtowcs` to `wchar_t[]` | left out |
| Rust | `Vec<char>` collected into a `String` | `String::from_utf8_lossy`, then collected into `Vec<char>` | left out |
| JavaScript | `TextEncoder.encode` | `TextDecoder.decode` | `Buffer` `toString("hex")` and `Buffer.from(s, "hex")` |
| Python | `str.encode` | `bytes.decode("utf-8", "replace")` | `bytes.hex`, `bytes.fromhex` |

C and Rust have no hex codec in their standard libraries, so they have no hex rows. `bench.ts` uses `Buffer`, which is in the Node standard library and in Bun, but not in ECMAScript itself.

## Caveats

- Bend octets are packed `Bytes`, but Bend text is a `String`: a list, one cell per code point or hex digit. The other languages use flat buffers for both.
- The outputs are not all the same shape. C and Rust decode to UTF-32 arrays, JavaScript to a UTF-16 string, and Python to its compact `str`. Bend decodes to a list of code points, built reversed and then reversed. Building it in order with non-tail recursion saved about 3 ms, so the simpler loop stays.
- C's `mbsrtowcs` fails on malformed input. The others substitute U+FFFD. The input is valid UTF-8, so this does not change the work here.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.
