# commands benchmark

This times `commands.handle`, one command in one SQLite transaction, in Bend and in C, Rust, JavaScript (Bun), and Python. No language has a standard idempotency library, so each variant runs the obvious loop over the same schema and SQL that `commands.open` creates. The payload, row key and value, result, and effect are BLOBs in every variant:

- `BEGIN IMMEDIATE`, then `SELECT payload, kind, result, at FROM commands_seen WHERE id = ?`.
- **Duplicate:** compare the payload bytes, then `COMMIT`.
- **New command:** read the row `total` (no row reads as 0), add the amount, `INSERT OR REPLACE` the row, `INSERT` the record, `INSERT` one outbox row, then `COMMIT`.

Six passes are timed:

- **`fresh`**: **N** new commands.
- **`replay`**: the same **N** commands again. Each must be a duplicate.
- **`range_small` / `range_large`**: **N** fresh commands read the same eight rows, among 100 or 100,000 unrelated rows.
- **`overflow_small` / `overflow_large`**: **N** attempts read that range with a seven-row bound. Each must fail with `SQLITE_TOOBIG` (18).

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

### Bounded ranges

Each table has eight selected BLOB keys, `pick_0` through `pick_7`, with decimal BLOB values `1` through `8`. It also has 100 (`small`) or 100,000 (`large`) unrelated BLOB keys, `z_0` through `z_99` or `z_99999`, all with value `100`. Setup clears rows, records, and outbox entries before each table size. Setup is not timed.

Each fresh command has id `range_i`, payload `8`, and timestamp 200. The lower bound is `pick_` (hex `7069636b5f`), inclusive. The upper bound is hex `7069636b60`, exclusive. The indexed query is:

```sql
SELECT k, v FROM commands_rows WHERE k >= ? AND k < ? ORDER BY k
```

Both bounds are BLOBs. The reader retains at most `max_rows` rows and steps once more to detect overflow. Bend, C, Rust, and Bun prepare and finalize the query for each command. Python uses `sqlite3.execute` and its statement cache. No SQL `LIMIT` hides the extra row. After a complete read, the decision accepts without changing rows or emitting effects. It hashes the ASCII text `pick_0=1;pick_1=2;...;pick_7=8;` with `h = h*31 + byte` in wrapping u32. The command records that hash and commits. Each pass hashes the N results with the same recurrence.

The overflow pass uses id `overflow` and payload `7` on every attempt. The eighth row must cause a rollback before the decision or record write. Its checksum hashes N error codes (18). Every variant checks that only N successful records exist and that the outbox is empty. After timing, the same `overflow` id with payload `8` must be fresh, not replayed or conflicting. This also checks that failure left no command record or open transaction. A returned decision on the failure path fails the benchmark.

`run.py` checks all six checksums across languages and repetitions. It also computes the expected range checksums independently. At N = 10,000, each range checksum is **4216059904** and each overflow checksum is **1895051776**.

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

### Bounded range results

Apple arm64, Darwin 25.6.0, 2026-11-23. `python3 run.py 3 10000`, in-memory database. Median of three runs; times are in ms. All five variants agree on all six checksums.

| variant | SQLite | range small ms | overflow small ms | range large ms | overflow large ms |
|---|---|---:|---:|---:|---:|
| C | 3.51.0 | 42.073 | 23.752 | 42.332 | 24.317 |
| Rust | 3.51.0 | 40.803 | 24.551 | 41.144 | 24.735 |
| Bun | 3.51.0 | 77.248 | 36.717 | 75.364 | 34.564 |
| Python | 3.54.0 | 115.907 | 43.633 | 117.653 | 45.176 |
| Bend | 3.51.0 | 158.345 | 107.840 | 158.942 | 107.993 |

Versions: Bend 2.0.40, Apple clang 21.0.0, rustc 1.91.0, Bun 1.4.4, Python 3.14.6. A small first run, `python3 run.py 1 5`, and a file-mode smoke, `python3 run.py 1 5 file`, also passed. At N = 5 the range checksum is 2969916024 and the overflow checksum is 17177490.

The 1,000-fold increase in unrelated rows changes Bend's successful range time from 158.345 to 158.942 ms. The fixed selection does not scale with the whole table in this measurement. Bend takes about 3.8 times C's successful range time and 4.4 times its overflow time on the large table. These are complete command transactions, not isolated SQLite scan times. The overflow pass includes no record write or commit.

A duplicate costs Bend one indexed lookup, a payload compare, and a `COMMIT`, as in the other variants: `handle` reads rows only when the id has no record. For a new command, `handle` copies the payload, because it goes to `keys` and to `step`, and `step` copies the payload and the result, because each goes both to its consumer and to the record. `rows.get` copies each key, because it goes to the lookup and to the row that `decide` sees. The keyed rows took the in-memory fresh pass from 89.1 ms (one state row read by `k = 0`) to 104.2 ms.
