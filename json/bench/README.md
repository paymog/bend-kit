# JSON benchmark

This times `Json.parse.bytes` and `Json.encode.bytes` on one fixed document, in Bend and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 4000 records
python3 run.py 5        # 5 runs
python3 run.py 1 40     # 1 run on a 40-record document; check this first after a change
```

You need `bend`, `cc`, `pkg-config`, `cJSON`, `cargo`, `bun`, `node`, and `python3`. On the first run, Cargo fetches `serde_json` at the versions pinned in `rs/Cargo.lock`. `run.py` writes the input to `out/doc.json` and the binaries to `out/`, which git ignores. It exits non-zero if a build fails, or if two languages print different checksums for one op.

## Input

`run.py` writes `{"count": N, "items": [...]}` with N = 4000 records, pretty-printed by `json.dumps(indent=2)`: 1,361,421 bytes. Each record has a bool, a null, integers, a half (`i + 0.5`), plain strings, a string with `\n`, `\t`, `\"`, and `\\` escapes, a nested object, and arrays.

The document is ASCII only, and its numbers are integers or exact halves. So every encoder prints the same compact text.

Each program reads the file before any timer starts. `parse.bytes` starts from the file's bytes, and `encode.bytes` ends with UTF-8 bytes; in JavaScript and Python that includes the UTF-8 decode or encode. C and Rust parse the bytes directly and encode straight to bytes. Bend packs the file into `Bytes` before the timer starts. After each timer stops, the program prints a checksum of the compact encoding: `h = h*31 + c` over the bytes, in wrapping u32, plus the length. A Bend `Val` can be used only once, so Bend prints the checksum of its one `encode.bytes` output for both ops. All six variants print `4114665117` for each op.

## Results

M4 Pro, macOS 26.6, 2026-09-28. Median of five runs (`python3 run.py 5`). Times are in ms; `Nx` is the multiple of the fastest variant for that op.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| parse.bytes | 3.2 (1.4x) | 3.1 (1.4x) | 2.3 (1.0x) | 2.8 (1.2x) | 4.6 (2.0x) | 4.8 (2.2x) |
| encode.bytes | 3.1 (4.9x) | 0.6 (1.0x) | 0.9 (1.4x) | 1.4 (2.2x) | 4.1 (6.5x) | 3.9 (6.2x) |

Before strings, numbers, and keys were `Bytes` (json 0.4.0.0, same machine and Bend version), Bend took 12 ms to parse and 9 ms to encode. The parser takes a run of whitespace, plain string bytes, or digits in one inner loop. On a document ten times as big (`python3 run.py 1 40000`), that cut `parse.bytes` from 49 ms to 32 ms. The encoder walked a work list until json 0.5.0.2; it now recurses on the `Val`, which took `encode.bytes` from 5.9 ms to 3.9 ms.

Versions: Bend 2.0.32, Apple clang 17.0.0, cJSON 1.7.19, rustc 1.91.0, serde_json 1.0.151, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

## The calls

| language | parse.bytes | encode.bytes |
|---|---|---|
| Bend | `Json.parse.bytes` | `Json.encode.bytes` |
| C | cJSON `cJSON_ParseWithLength` | `cJSON_PrintUnformatted` |
| Rust | `serde_json::from_slice::<Value>` | `serde_json::to_vec` |
| JavaScript | `TextDecoder` then `JSON.parse` | `JSON.stringify` then `TextEncoder` |
| Python | `json.loads` on `bytes` | `json.dumps(v, separators=(",", ":"), ensure_ascii=False)`, then `.encode()` |

## Caveats

- Bend objects are lists of fields in document order, and so are cJSON objects. `serde_json::Value` objects are sorted maps (the input's keys are already sorted), and JavaScript and Python use hash maps.
- Bend keeps each number's text. C and JavaScript convert numbers to doubles, Rust and Python to ints or doubles, and they print them back.
- Bend times itself with `Time.mono`, a nanosecond clock.
- These are micro-benchmarks on one machine.
