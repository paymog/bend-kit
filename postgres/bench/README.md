# Postgres result decode benchmark

This times decoding one fixed recording of a large result set (RowDescription, then many DataRow messages) in Bend and in C, Rust, JavaScript (Bun and Node), and Python. No Postgres server runs.

## Run

```sh
python3 run.py          # 3 runs per variant, median, the committed 20,000-row recording
python3 run.py 5        # 5 runs
python3 run.py 1 1000   # 1 run on a generated 1,000-row recording (small smoke run)
python3 run.py fixture  # rewrite result.pgwire from the generator
```

You need `bend` (2.0.32), `cc` with Homebrew `libpq` in `/opt/homebrew/opt/libpq`, `cargo`, `npm`, `bun`, `node`, and `uv`. On the first run, Cargo fetches `postgres-protocol`, `npm` installs `pg-protocol` into `out/js`, and `uv` fetches `psycopg[binary]`. Binaries go to `out/`, which git ignores. Once built, a full run takes about 6 seconds. It exits non-zero if a build or a run fails, if a checksum differs from the one `run.py` computes from its own rows, or if `result.pgwire` no longer matches the generator.

## Input

`result.pgwire` is committed: 1,437,933 bytes, the backend's text-format reply to `SELECT id, name, balance, note, active FROM accounts`. It holds one RowDescription, 20,000 DataRows, `CommandComplete` with tag `SELECT 20000`, and `ReadyForQuery` (`I`). `run.py` writes it with `row(i)` and `recording(rows)`, and checks it before every run. The columns come from table oid 16384:

| column | type (oid) | value of row `i` |
|---|---|---|
| id | int4 (23) | `i + 1` |
| name | text (25) | `zoë-i` when `i % 7 == 0` (UTF-8), else `user-i` |
| balance | int8 (20) | `i*1000003 - 2^40` (negative, then positive, past 32 bits) |
| note | text (25) | NULL when `i % 5 == 0`, else `i % 40` bytes of letters, digits, quotes, commas, and a backslash |
| active | bool (16) | `f` when `i % 3 == 0`, else `t` |

Every program takes the recording into its library's values; only that is timed. The checksum then walks them with `h = h*31 + x` (u32, wrapping): 1, then for each column its name (length, then bytes) and type oid, then 2; for each row 3, then per value 4 for NULL or 5, the length, and the bytes, then 6; then 7 and the command tag (length, then bytes). Every checksum must equal `run.py`'s: `2789966000` for the 20,000-row recording and `2366601296` for 1,000 rows.

## Results

M4 Pro, macOS 26.6.2, 2026-09-28. `python3 run.py 5`, median of five runs. Times are in ms; `Nx` is the multiple of the fastest variant.

| op | C | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|---:|
| decode | 1.5 (1.4x) | 1.1 (1.0x) | 6.4 (6.0x) | 10.6 (10.1x) | 4.9 (4.6x) | 4.0 (3.8x) |

Versions: Bend 2.0.32, Apple clang 17.0.0 with libpq 18.0, rustc 1.91.0 with postgres-protocol 0.6.12, Bun 1.3.14 and Node 24.0.1 with pg-protocol 1.16.0, Python 3.14.6 with psycopg 3.3.6 (psycopg-binary, which bundles libpq 18.0.6).

**The C and Python lanes are not like for like with the others.** libpq has no public API that parses protocol bytes; it decodes only what it reads from a connection, and psycopg sits on libpq. So `bench.c` and `bench.py` start a thread that serves a Unix socket in a temp dir and replays a canned startup (AuthenticationOk, ParameterStatus, BackendKeyData, ReadyForQuery), then the recording in reply to the query. The decode is real libpq and psycopg, but their times also hold the query's send and the recording's trip through a local socket, handed over in whatever pieces the kernel delivers. Rust, JavaScript, and Bend decode from memory in 64 KiB pieces.

Bend's `IO.now` counts whole ms, so Bend times are integers, and at 4 ms one run can land a ms or two either way. The Bend binary peaked at about 53 MB RSS (`/usr/bin/time -l out/bend`).

## The calls

| language | decode |
|---|---|
| Bend | `feed` then `next` from `../codec.bend` until `Want`, per 64 KiB piece |
| C | libpq `PQexec` over the replay socket; the result is one `PGresult` |
| Rust | `postgres_protocol::message::backend::Message::parse` on a `BytesMut` fed 64 KiB at a time; it keeps each row's body and its `ranges()`, and each column's name and type oid, as tokio-postgres's `Row` and `Column` do |
| JavaScript | pg-protocol `Parser.parse` (`pg-protocol/dist/parser`, the parser inside `pg`), per 64 KiB piece |
| Python | psycopg `ClientCursor.execute` then `fetchall` over the replay socket, with `autocommit=True` |

`ClientCursor` sends a simple Query, as `PQexec` does; a plain psycopg cursor would send Parse/Bind/Execute, and a connection without autocommit would send a `BEGIN` first, which the replay would answer with the recording. psycopg loads `int4` and `int8` as `int`, `bool` as `bool`, and `text` as `str`, so its time holds that type conversion, and the checksum turns the values back into their text bytes (`str(n)`, `t`/`f`, UTF-8). pg-protocol decodes names, values, and the tag as UTF-8 strings, so the JavaScript checksum turns them back into bytes; every value here is valid UTF-8.
