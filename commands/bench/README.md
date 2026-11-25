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

Both bounds are BLOBs. The reader retains at most `max_rows` rows and steps once more to detect overflow. C, Rust, and Bun prepare and finalize the query for each command. Bend reuses the store's prepared range statement and resets it after every read. Python uses `sqlite3.execute` and its statement cache. No SQL `LIMIT` hides the extra row. After a complete read, the decision accepts without changing rows or emitting effects. It hashes the ASCII text `pick_0=1;pick_1=2;...;pick_7=8;` with `h = h*31 + byte` in wrapping u32. The command records that hash and commits. Each pass hashes the N results with the same recurrence.

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

### Native range profile and statement reuse

Apple arm64, Darwin 25.6.0, 2026-11-25. Bend 2.0.40, Apple clang 21.0.0, rustc 1.91.0, Bun 1.4.4, Python 3.14.6. Both measurements use `python3 run.py 3 10000` on the same machine and compiler. Each had a small first run, `python3 run.py 1 5`.

| variant | phase | range small ms | overflow small ms | range large ms | overflow large ms |
|---|---|---:|---:|---:|---:|
| C | before | 42.113 | 23.836 | 41.535 | 24.474 |
| C | after | 40.292 | 23.390 | 41.639 | 24.491 |
| Rust | before | 41.676 | 24.300 | 42.368 | 24.908 |
| Rust | after | 40.777 | 23.880 | 41.622 | 24.183 |
| Bun | before | 79.043 | 37.013 | 74.127 | 34.992 |
| Bun | after | 77.205 | 35.861 | 75.827 | 34.955 |
| Python | before | 116.257 | 44.753 | 119.639 | 45.720 |
| Python | after | 115.170 | 43.356 | 117.508 | 45.135 |
| Bend | before | 159.455 | 108.531 | 158.534 | 108.875 |
| Bend | after | 135.359 | 87.818 | 137.172 | 89.097 |

All six checksums agree across all five languages in both runs: fresh **5023800**, replay **1224217884**, both ranges **4216059904**, and both overflows **1895051776**. `run.py` also checks the range hashes against its independent calculation. Each range pass checks that overflow returns code 18 before a decision, leaves no record or effect, and permits a fresh retry with bound eight.

The only runtime change is statement reuse. The store prepares the range query in `open`, binds both bounds on every read, resets it after success or failure, and finalizes it in `close`. The row reader, overflow check, decision, and transaction boundaries are unchanged. This removes repeated SQL string conversion, parsing, statement registration, and finalization. Bend's successful ranges improve by 15.1% (small) and 13.5% (large). Overflow improves by 19.1% and 18.2%. C, Rust, and Bun still prepare each query, so their timings compare full implementations, not identical statement-cache policies.

#### Sampling method

`profile.bend` runs only one path against 100,000 unrelated rows. It uses the same range loop and decision as `bench.bend`. Its post-run checks count records and effects, retry the overflow id with bound eight, and close the store.

```sh
bend profile.bend -o out/profile
out/profile range 5
out/profile overflow 5
out/profile range 1000000 > out/range-profile-run.txt &
pid=$!
sample "$pid" 5 1 -file out/range.sample.txt
wait "$pid"
out/profile overflow 1000000 > out/overflow-profile-run.txt &
pid=$!
sample "$pid" 5 1 -file out/overflow.sample.txt
wait "$pid"
```

The baseline sample has 3,965 main-thread observations for success and 3,980 for overflow. Samples are inclusive stack observations, not exact per-operation timers. The baseline success sample started about five seconds after launch; the overflow sample started at launch and includes the short untimed seed. The native profile uses 57 MB at the success sample point.

| baseline stack | success samples | overflow samples | interpretation |
|---|---:|---:|---|
| `work_loop` | 2,475 (62.4%) | 2,671 (67.1%) | Bend evaluation, continuation dispatch, and data handling |
| `WL_FID_Clo_apply` | 1,565 (39.5%) | 1,807 (45.4%) | Closure dispatch; included in `work_loop` |
| `stmt_prepare_run` | 401 (10.1%) | 592 (14.9%) | SQL conversion, preparation, and registration |
| `stmt_finalize_run` | 23 (0.6%) | 57 (1.4%) | Statement release |
| `stmt_column_blob_run` | 75 (1.9%) | 86 (2.2%) | Column validation and packed row-byte materialization |
| `stmt_step_run` | 720 (18.2%) | 364 (9.1%) | All SQLite steps: transaction, lookup, scan, and successful record write |
| `stmt_reset_run` | 50 (1.3%) | 55 (1.4%) | Reset of reused statements |

After statement reuse, the success sample has 3,974 observations and the overflow sample has 3,968. Neither sample contains `stmt_prepare_run` or `stmt_finalize_run`. `work_loop` accounts for 2,786 (70.1%) and 3,155 (79.5%) observations. Its closure-dispatch subset accounts for 1,720 (43.3%) and 2,152 (54.2%). Native column materialization stays small at 75 (1.9%) and 90 (2.3%). Both optimized samples start at launch, so the brief seed is included. These are proportions of different runs, not absolute time savings.

Row materialization is not the dominant native effect. Success reads 16 BLOB columns; overflow reads 14 and steps the eighth row without decoding it. Each read still crosses an effect boundary and the `Run` continuation chain, so the column effect percentage alone is not the total cost of reading rows. Transaction handling includes `BEGIN IMMEDIATE`, lookup, and either record insertion plus `COMMIT`, or cleanup plus `ROLLBACK`. These appear together under `stmt_step_run`; the sampler does not separate statement ids. Overflow has no decision, record write, or commit, yet closure dispatch remains the largest named cost.

The remaining large-table gap is about 3.3 times C for success and 3.6 times C for overflow. Removing transaction steps would weaken atomicity or retry behavior. Returning SQLite-owned row memory would break ownership when the statement advances. Fusing effects or changing continuation dispatch needs separate evidence and a wider interface change. This change does neither.
