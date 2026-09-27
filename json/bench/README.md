# JSON benchmark

This times `Json.parse` and `Json.encode` on one fixed document, in Bend and in JavaScript (Bun and Node) and Python. It times them twice: once on text, and once on UTF-8 bytes (`Json.parse.bytes` and `Json.encode.bytes`).

## Run

```sh
python3 run.py          # 3 runs per variant, median, 4000 records
python3 run.py 5        # 5 runs
python3 run.py 1 40     # 1 run on a 40-record document; check this first after a change
```

You need `bend`, `bun`, `node`, and `python3`. `run.py` writes the input to `out/doc.json` and the Bend binary to `out/`, which git ignores. The run takes about 5 seconds. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

`run.py` writes `{"count": N, "items": [...]}` with N = 4000 records, pretty-printed by `json.dumps(indent=2)`: 1,361,421 bytes. Each record has a bool, a null, integers, a half (`i + 0.5`), plain strings, a string with `\n`, `\t`, `\"`, and `\\` escapes, a nested object, and arrays.

The document is ASCII only, its keys are in sorted order, and its numbers are integers or exact halves. So every encoder prints the same compact text, and Bend's sorted keys match the insertion order that JavaScript and Python keep.

Each program reads the file before any timer starts. `parse` times the parse of the text. `encode` times the encode of the parsed value to compact JSON. `parse.bytes` starts from the file's bytes, and `encode.bytes` ends with UTF-8 bytes; in JavaScript and Python that includes the UTF-8 decode or encode. Bend packs the file into `Bytes` before the timer starts. After each timer stops, the program prints a checksum of the compact encoding: `h = h*31 + c` over the chars (or bytes), in wrapping u32, plus the length. All four checksums are `4114665117`.

## Results

M4 Pro, macOS 26.6.2, 2026-09-26. Median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant for that op. Bend's peak RSS was 81 MB for all four ops.

| op | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|
| parse | 2.1 (1.0x) | 2.9 (1.4x) | 4.4 (2.1x) | 40.0 (19.0x) |
| encode | 0.9 (1.0x) | 1.1 (1.2x) | 3.9 (4.6x) | 71.0 (82.0x) |
| parse.bytes | 2.1 (1.0x) | 2.8 (1.3x) | 4.8 (2.2x) | 11.0 (5.1x) |
| encode.bytes | 0.8 (1.0x) | 1.3 (1.6x) | 3.9 (4.7x) | 9.0 (10.7x) |

The Bytes path is 3.6x faster to parse and 8x faster to encode than the text path. The text path also needs a UTF-8 decode before `parse`, which this table does not time.

Versions: Bend 2.0.29, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | parse | encode | parse.bytes | encode.bytes |
|---|---|---|---|---|
| Bend | `Json.parse` | `Json.encode` | `Json.parse.bytes` | `Json.encode.bytes` |
| JavaScript | `JSON.parse` | `JSON.stringify` | `TextDecoder` then `JSON.parse` | `JSON.stringify` then `TextEncoder` |
| Python | `json.loads` | `json.dumps(v, separators=(",", ":"), ensure_ascii=False)` | `json.loads` on `bytes` | the same `json.dumps`, then `.encode()` |

C and Rust have no JSON codec in their standard libraries, so they are left out.

## Caveats

- Bend strings are lists, one cell per char, and objects are `Map`s. The other languages use flat strings and hash maps. The Bytes path reads and writes a flat buffer, but keys and string values are still `String`s.
- Bend keeps each number's text. JavaScript and Python convert numbers to doubles or ints and print them back.
- Bend's `Json.encode` sorts keys. The others keep insertion order, so they do not sort.
- Bend's `IO.now` counts in whole ms. The other languages use sub-ms clocks.
- These are micro-benchmarks on one machine.
