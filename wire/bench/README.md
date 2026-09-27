# Wire benchmark

This times **R = 64** localhost TCP echo round trips with a fixed **1 MiB** payload per trip: Bend uses `Wire.send.words` and `Wire.recv.words`; C, Rust, Python, and JavaScript use raw `socket` / `std::net` / `node:net`. One timed op, **`echo`**, covers the full send+recv loop (all rounds).

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `clang`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes tens of seconds. It exits non-zero if a build fails or checksums disagree.

## Input

- Payload: **1,048,576** bytes (`N = 2^20`). Byte `i` is `(i * 31 + 7) & 255`.
- Port: **38501** on `127.0.0.1`.
- **Checksum:** u32 `h = h * 31 + b` (wrap) over **every byte received** in **every** round. Expected: **3187671040**.
- **Throughput:** `run.py` also reports **MB/s** for `echo` using `R * N * 2` bytes (send + recv) over median ms.

Bend runs in **one process**: `IO.fork` starts a TCP echo server (`TCP.listen` / `TCP.accept`, then `Wire.recv.words` / `Wire.send.words`); the main task sleeps 500 ms, connects with `Wire.connect`, builds the send buffer in IO (`buf()` after connect), then times the client echo loop. Other languages use a helper thread or async server that signals when listen is ready.

Wire `recv.words` is one POSIX read (up to `max` bytes). **Bend** loops it in `bench.bend` with a **Nat fuel** counter, copying each chunk into a scratch buffer until the round’s 1 MiB is complete—the same obvious socket loop the C/Python/JS benches use.

## Results

M4 Pro, macOS, 2026-09-27. Median of three runs. Times are in ms; **MB/s** and **vs fastest** come from `run.py`.

| variant | echo ms | echo MB/s | vs fastest |
|---:|---:|---:|---:|
| C | 59.3 | 2,265 | 1.0x ms, 1.00x MB/s |
| Rust | 59.8 | 2,246 | 1.0x ms, 0.99x MB/s |
| Bun | 502.1 | 267 | 8.5x ms, 0.12x MB/s |
| Node | 111.8 | 1,200 | 1.9x ms, 0.53x MB/s |
| Python | 3,510.8 | 38 | 59.2x ms, 0.02x MB/s |
| Bend | 513.4 | 261 | 8.7x ms, 0.12x MB/s |

Checksum walks received bytes via `Bytes.to_string` and the same u32 mix as the other variants.

Versions: Bend 2.0.31, Apple clang 17.0.0, Rust 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6.
