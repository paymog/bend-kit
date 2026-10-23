# Migration benchmark

This times the hot path of `migrate`: parse a JSON array of subscription records, decode and validate each, upgrade it to v3, and encode the v3 array. It runs in Bend and in C, Rust, JavaScript (Bun and Node), and Python.

## Run

```sh
python3 run.py          # 3 runs per variant, median, 20000 records
python3 run.py 5        # 5 runs
python3 run.py 1 300    # 1 run on 300 records; check this first after a change
```

You need `bend`, `cc`, `pkg-config`, `cJSON`, `cargo`, `bun`, `node`, and `python3`. On the first run, Cargo fetches `serde` and `serde_json` at the versions pinned in `rs/Cargo.lock`. `run.py` writes the input to `out/doc.json` and the binaries to `out/`, which git ignores. It exits non-zero if a build fails, or if two languages print different checksums.

## Input

`run.py` writes a compact JSON array of 20,000 records: 1,664,046 bytes. A third are v1, a third v2, and a third v3. The v2 records rotate through both periods, all three statuses, an absent `period`, and an optional `note`. All text is ASCII.

Each program reads the file before its timer starts and stops the timer after it has the output bytes. After the timer stops, it prints a checksum of the output: `h = h*31 + c` over the bytes, in wrapping u32, plus the length. All six variants print `1959877304`.

## Results

M4 Pro, macOS 26.6, 2026-10-23. Median of five runs (`python3 run.py 5`). Times are in ms; `Nx` is the multiple of the fastest variant.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| migrate | 20.4 (2.9x) | 11.0 (1.5x) | 7.1 (1.0x) | 10.8 (1.5x) | 35.1 (4.9x) | 83.6 (11.8x) |

Versions: Bend 2.0.38, Apple clang 17.0.0, cJSON 1.7.19, rustc 1.91.0, serde_json 1.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6.

`Json.parse.bytes` takes about 5 ms on a document this size (see `json/bench`), so most of Bend's time is in decode: every key and string becomes a `String`, and each field lookup compares strings.

## The calls

| language | parse | per record | encode |
|---|---|---|---|
| Bend | `Json.parse.strict.bytes(b, 2)` | `M.decode.val`, `M.Record.upgrade`, `M.V3.json` | `Json.encode.bytes` |
| C | cJSON `cJSON_ParseWithLength` | key, type, and range checks; a new cJSON object | `cJSON_PrintUnformatted` |
| Rust | `serde_json::from_slice::<Vec<Value>>` | key, type, and range checks; a `#[derive(Serialize)]` struct | `serde_json::to_vec` |
| JavaScript | `TextDecoder` then `JSON.parse` | key, type, and range checks; an object literal | `JSON.stringify` then `TextEncoder` |
| Python | `json.loads` on `bytes` | key, type, and range checks; a dict | `json.dumps(v, separators=(",", ":"), ensure_ascii=False)`, then `.encode()` |

No language has a standard or popular versioned-record migration library, so each one does the migration as a short function over its standard JSON values. Each applies the same rules as `migrate`: known keys per version, types, whole `U32` numbers, known `period` and `status` values, defaults, and the business rules.

## Caveats

- Bend rejects a duplicate key in a record. The other parsers keep the last value without an error.
- C and JavaScript read numbers as doubles. Rust and Python read them as integers.
- These are micro-benchmarks on one machine.
