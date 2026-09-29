# SQLite benchmark

This times two SQLite workloads on an in-memory database, in Bend and in C, Rust, JavaScript (Bun), and Python. Every variant runs the same SQL through a prepared statement:

- **`insert`**: `BEGIN`, then **N** runs of `INSERT INTO t VALUES (?1, ?2)` (bind, step, reset), then `COMMIT`.
- **`select`**: **N** runs of `SELECT v FROM t WHERE k = ?1` (bind, step, read column 0, reset) on the primary key.

## Run

```sh
python3 run.py            # 3 runs per variant, median, N = 100,000 rows
python3 run.py 5          # 5 runs
python3 run.py 1 1000     # 1 run on 1,000 rows; check RSS and checksums first after a change
```

You need `bend`, `cc`, `rustc`, `bun`, `python3`, and a system `libsqlite3`. `run.py` writes the C, Rust, and Bend binaries to `out/`, which git ignores. It exits non-zero if a build or run fails, or if two variants print different checksums. Each program prints the SQLite version it loaded, and the table shows it.

| variant | SQLite API |
|---|---|
| C | libsqlite3 C API (`-lsqlite3`) |
| Rust | libsqlite3 C API through `extern "C"`, no crates |
| Bun | `bun:sqlite` |
| Python | `sqlite3` (standard library) |
| Bend | `sqlite.bend` effects (`BEND_LIBSQLITE` selects the library) |

Rust's standard library has no SQLite, so `bench.rs` links libsqlite3 directly, as C does, rather than add `rusqlite`. Node is left out: `node:sqlite` is still experimental.

## Input

- Table `t(k INTEGER PRIMARY KEY, v INTEGER NOT NULL)` in `:memory:`, created before any timer starts.
- Row **i** (0 ≤ i < N) is `(i, x_i >> 1)`, with `x_0 = 1` and `x_{i+1} = x_i * 1664525 + 1013904223` in wrapping u32. The shift keeps each value below 2^31.
- `select` reads key `k mod N` for `k = 0, 7919, 2·7919, …`, N times.

The `insert` timer covers `BEGIN` through `COMMIT`. Its checksum is `SELECT count(*) FROM t`, read after the timer stops. The `select` checksum is `h = h*31 + v` in wrapping u32 over every value read. With N = 100,000 the checksums are **100000** and **1213052288**; with N = 1,000 they are **1000** and **2185717440**.

## Results

Checksums agree across all five variants: insert **100000**, select **1213052288**.

Apple M-series (arm64), macOS 25.6, 2026-09-28. Median of three runs, N = 100,000. Times are in ms.

| variant | SQLite | insert ms | inserts/s | vs fastest | select ms | selects/s | vs fastest |
|---:|---:|---:|---:|---:|---:|---:|---:|
| C | 3.51.0 | 21.9 | 4,558,716 | 1.0x | 37.9 | 2,636,714 | 1.1x |
| Rust | 3.51.0 | 21.3 | 4,695,718 | 1.0x | 33.0 | 3,028,376 | 1.0x |
| Bun | 3.51.0 | 29.3 | 3,415,534 | 1.4x | 41.2 | 2,426,478 | 1.2x |
| Python | 3.53.4 | 67.5 | 1,481,679 | 3.2x | 100.8 | 992,359 | 3.1x |
| Bend | 3.51.0 | 99.9 | 1,000,893 | 4.7x | 116.3 | 859,916 | 3.5x |

Versions: Bend 2.0.32, Apple clang 17.0.0, rustc 1.91.0, Bun 1.3.14, Python 3.14.6.
