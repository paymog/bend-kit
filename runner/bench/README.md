# Runner benchmark

This times replay at `open`: scanning the journal's frames, checking each CRC-32, decoding each record, and applying it to the queue. Replay is the runner's CPU hot path. A live transition is one fsync, which the disk dominates.

It replays the bench log three ways: as written, as `compact` leaves it (one frame that holds the snapshot of the final state), and a second log in which every job dies.

## Run

```sh
python3 run.py        # 3 runs per variant, median, 2^16 jobs
python3 run.py 5 14   # 5 runs, 2^14 jobs
```

You need `bend` (2.0.38), `cargo`, and `python3`. Cargo fetches `crc32fast` 1.5.0. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, a program prints no result, or two programs disagree on a row's checksum or counts.

## Input

J = 2^16 jobs, so the log holds 3 × 2^16 = 196,608 records:

1. For each job i: `Enqueue{deadline = (i * 37) mod 1024, payload = i as u32le}`.
2. J rounds of `Select{1024}`, then, for the selected ticket, `Complete{id}` in the first J/2 rounds and `Requeue{id, 2048 + k}` in round k after that.

The `dead` log holds 3.75 × J records + 1, and every ticket dies:

1. The same J enqueues.
2. J rounds of `Select{1024}`, then `Abandon{id, WhyFailed, at = k}` for the selected ticket in round k.
3. In the order they died: `Cancel{id}` for the first J/4; one `Purge{J/2}`, which drops the next J/4; then `Revive{id, 4096 + k}` for the last J/2.

Each `Cancel` and `Revive` finds its dead ticket by id, so this row grows with the dead tickets as a replay grows with the pending ones.

The records and frames are as `runner.bend` and `journal` write them. Each program builds the log before the timer starts. The generators find the selected ids by sorting on (deadline, id); Bend runs the runner's own `step`. Bend also builds the compacted journal before the timer: `J.frame(R.encode.snap(state))`.

The timed region scans every frame, checks `~len` and the CRC-32, decodes the record, applies it, and then sums `id * 31 + deadline` over the pending tickets, mod 2^32.

| language | replay |
|---|---|
| Bend | `J.replay.bytes` folding `R.replay.step`: the code that `open` runs |
| Rust | `crc32fast` 1.5.0, `std::collections::BinaryHeap`, `HashMap`, `HashSet` |
| Python | `zlib.crc32`, `struct.unpack_from`, `heapq`, `dict`, `set` |

C and JavaScript are left out: neither standard library has a priority queue, and the replay needs a dynamic one. Only Bend has the `compacted` row: the baselines have no snapshot format, and writing one would be a second runner. The baselines keep dead tickets in a hash map. The `dead` log cancels only dead tickets, so their `Cancel` does not take a ticket from the heap.

## Results

Apple M4 Pro, macOS 26.6.2 arm64, 2026-10-24. Three runs (`python3 run.py`), median, in ms. `Nx` is the multiple of the fastest variant.

Versions: Bend 2.0.38, rustc 1.91.0, crc32fast 1.5.0, Python 3.14.6.

| op | Rust | Python | Bend |
|---|---:|---:|---:|
| replay | 10.7 (1.0x) | 202.1 (18.8x) | 438.2 (40.8x) |
| dead | 15.5 (1.4x) | 268.1 (25.0x) | 662.9 (61.8x) |
| compacted | - | - | 121.8 (11.3x) |

Every program prints checksum `607518720` and `32768/65536` (pending tickets / next id) for `replay` and `compacted`, and checksum `674627584` and `32768/65536` for `dead`.

## Reading it

Compaction cuts open's replay by 3.6x here. The log holds 196,608 records, and the compacted journal holds one: the 32,768 pending tickets and their tries. Replay time then follows the live state, not the history. Half of the jobs here are still pending; a runner whose jobs finish gains more.

Replay is O(n log n) in Bend: the queue is a heap, the tries are an ordered map, and the dead tickets are a hash trie keyed by id. Native Bend took 19 ms at 2^12 jobs, 83 ms at 2^14, and 431 ms at 2^16 on Bend 2.0.36. The `dead` row took 23 ms at 2^12, 107 ms at 2^14, and 581 ms at 2^16 on Bend 2.0.38: each `Cancel` and `Revive` costs about the same at every size. A snapshot rebuilds the same trees without the heap and map work, so its decode is linear in its size.

`journal`'s bench shows that its frame scan alone takes about 300 ms for 2^20 records, because `Hash.crc32` rebuilds its table per record. Here the scan is a part of the total, and the heap and map work is the rest. This bench does not split them.

## Caveats

- Bend times itself with `Time.mono`. It reads the size from argv, so the replay cannot run before the clock starts. Building the log is outside the timer.
- One machine, one size, one thread.
- The Rust and Python loops are the obvious replay over a standard-library heap. They keep payloads and tries in hash maps, as the runner keeps them in its state. They are not a second runner: they have no retry, breaker, or pool.
