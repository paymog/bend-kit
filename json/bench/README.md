# JSON benchmark

This times `Json.parse.bytes` and `Json.encode.bytes` on one fixed document, in Bend and in JavaScript (Bun and Node) and Python.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 4000 records
python3 run.py 5        # 5 runs
python3 run.py 1 40     # 1 run on a 40-record document; check this first after a change
```

You need `bend`, `bun`, `node`, and `python3`. `run.py` writes the input to `out/doc.json` and the Bend binary to `out/`, which git ignores. The run takes about 5 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

`run.py` writes `{"count": N, "items": [...]}` with N = 4000 records, pretty-printed by `json.dumps(indent=2)`: 1,361,421 bytes. Each record has a bool, a null, integers, a half (`i + 0.5`), plain strings, a string with `\n`, `\t`, `\"`, and `\\` escapes, a nested object, and arrays.

The document is ASCII only, and its numbers are integers or exact halves. So every encoder prints the same compact text.

Each program reads the file before any timer starts. `parse.bytes` starts from the file's bytes, and `encode.bytes` ends with UTF-8 bytes; in JavaScript and Python that includes the UTF-8 decode or encode. Bend packs the file into `Bytes` before the timer starts. After each timer stops, the program prints a checksum of the compact encoding: `h = h*31 + c` over the bytes, in wrapping u32, plus the length. A Bend `Val` can be used only once, so Bend prints the checksum of its one `encode.bytes` output for both ops. All four checksums are `4114665117`.

## Results

M4 Pro, macOS 26.6.2, 2026-09-27. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|
| parse.bytes | 2.3 (1.0x) | 2.8 (1.2x) | 4.8 (2.1x) | 4.0 (1.8x) |
| encode.bytes | 0.9 (1.0x) | 1.4 (1.6x) | 4.0 (4.5x) | 4.0 (4.5x) |

Before strings, numbers, and keys were `Bytes` (json 0.4.0.0, same machine and Bend version), Bend took 12 ms to parse and 9 ms to encode.

Versions: Bend 2.0.31, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | parse.bytes | encode.bytes |
|---|---|---|
| Bend | `Json.parse.bytes` | `Json.encode.bytes` |
| JavaScript | `TextDecoder` then `JSON.parse` | `JSON.stringify` then `TextEncoder` |
| Python | `json.loads` on `bytes` | `json.dumps(v, separators=(",", ":"), ensure_ascii=False)`, then `.encode()` |

C and Rust have no JSON codec in their standard libraries, so they are left out.

## Caveats

- Bend objects are lists of fields in document order. The other languages use hash maps.
- Bend keeps each number's text. JavaScript and Python convert numbers to doubles or ints and print them back.
- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- These are micro-benchmarks on one machine.
