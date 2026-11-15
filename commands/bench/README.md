# commands benchmark

This times `commands.handle`, one command in one SQLite transaction, in Bend and in C, Rust, JavaScript (Bun), and Python. No language has a standard idempotency library, so each variant runs the obvious loop over the same schema and SQL that `commands.open` creates. The payload, row key and value, result, and effect are BLOBs in every variant:

- `BEGIN IMMEDIATE`, then `SELECT payload, kind, result, at FROM commands_seen WHERE id = ?`.
- **Duplicate:** compare the payload bytes, then `COMMIT`.
- **New command:** read the row `total` (no row reads as 0), add the amount, `INSERT OR REPLACE` the row, `INSERT` the record, `INSERT` one outbox row, then `COMMIT`.

Two passes are timed:

- **`fresh`**: **N** new commands.
- **`replay`**: the same **N** commands again. Each must be a duplicate.

## Run

Run these commands from `commands/bench/`.

```sh
python3 run.py               # 3 runs per variant, median, N = 10,000, in-memory database
python3 run.py 3 2000 file   # a file database in out/: every COMMIT syncs to disk
python3 run.py 1 500         # check RSS and checksums first after a change
```

You need `bend`, `cc`, `rustc`, `bun`, `python3`, and a system `libsqlite3`. `run.py` writes the binaries and the database to `out/`, which git ignores. It removes the database before each run. It exits non-zero if a build or run fails, or if two variants print different checksums.

| variant | SQLite API |
|---|---|
| C | libsqlite3 C API (`-lsqlite3`) |
| Rust | libsqlite3 C API through `extern "C"`, no crates |
| Bun | `bun:sqlite` |
| Python | `sqlite3` (standard library) |
| Bend | `commands.handle` over `bend-kit-sqlite` |

Rust's standard library has no SQLite, so `bench.rs` links libsqlite3 directly, as `sqlite/bench` does. Node is left out: `node:sqlite` is still experimental.

## Input

- Command **i** (0 ≤ i < N) has id `cmd_i` and payload `(x_i >> 1) mod 1000` in decimal, with `x_0 = 1` and `x_{i+1} = x_i * 1664525 + 1013904223` in wrapping u32.
- The domain state is one row, key `total`, holding a decimal total. No row means 0. A new command adds its amount. The result is the new total, and the outbox row is `total=<new total>`. Each is stored as the bytes of its ASCII text.
- The `fresh` checksum is the final total, read after the timer stops. The `replay` checksum is `h = h*31 + result` in wrapping u32 over every duplicate's recorded result.

With N = 10,000 the checksums are **5023800** and **1224217884**. With N = 2,000 they are **1018672** and **1045709524**. With N = 500 they are **259210** and **2276155089**.

## Results

Checksums agree across all five variants. Apple M-series (arm64), macOS 26.6.2, 2026-10-24. Median of three runs. Times are in ms.

In-memory database, N = 10,000:

| variant | SQLite | fresh ms | commands/s | vs fastest | replay ms | duplicates/s | vs fastest |
|---:|---:|---:|---:|---:|---:|---:|---:|
| C | 3.51.0 | 39.8 | 251,181 | 1.0x | 6.7 | 1,503,759 | 1.0x |
| Rust | 3.51.0 | 41.4 | 241,797 | 1.0x | 6.7 | 1,500,600 | 1.0x |
| Bun | 3.51.0 | 61.4 | 162,824 | 1.5x | 15.1 | 660,677 | 2.3x |
| Python | 3.54.0 | 78.6 | 127,246 | 2.0x | 23.6 | 423,980 | 3.5x |
| Bend | 3.51.0 | 104.2 | 95,997 | 2.6x | 35.6 | 280,743 | 5.4x |

File database, N = 2,000. Each new command's `COMMIT` waits for the disk, so `fresh` measures the disk more than the language:

| variant | SQLite | fresh ms | commands/s | vs fastest | replay ms | duplicates/s | vs fastest |
|---:|---:|---:|---:|---:|---:|---:|---:|
| C | 3.51.0 | 832.0 | 2,404 | 1.0x | 11.7 | 170,678 | 1.0x |
| Rust | 3.51.0 | 1,049.1 | 1,906 | 1.3x | 12.9 | 155,436 | 1.1x |
| Bun | 3.51.0 | 929.3 | 2,152 | 1.1x | 21.2 | 94,491 | 1.8x |
| Python | 3.54.0 | 878.7 | 2,276 | 1.1x | 14.2 | 141,084 | 1.2x |
| Bend | 3.51.0 | 893.7 | 2,238 | 1.1x | 19.5 | 102,380 | 1.7x |

Versions: Bend 2.0.38, Apple clang 17.0.0, rustc 1.91.0, Bun 1.3.14, Python 3.14.6.

A duplicate costs Bend one indexed lookup, a payload compare, and a `COMMIT`, as in the other variants: `handle` reads rows only when the id has no record. For a new command, `handle` copies the payload, because it goes to `keys` and to `step`, and `step` copies the payload and the result, because each goes both to its consumer and to the record. `rows.get` copies each key, because it goes to the lookup and to the row that `decide` sees. The keyed rows took the in-memory fresh pass from 89.1 ms (one state row read by `k = 0`) to 104.2 ms.
