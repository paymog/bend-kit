# CRDT benchmark

This times the G-Counter hot path: local increments and state merges among 16 replicas. It compares `crdt` against `crdts::GCounter` in Rust, once with dense replica IDs and once with sparse ones.

## Run

Run these commands from `crdt/bench/`.

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cargo`, and `python3`. Cargo fetches `crdts` 7.3.2. Binaries go to `out/`, which git ignores. The script exits non-zero if a build fails, or if the programs disagree on the checksum.

## The op

Each program starts 16 empty counters and runs R = 2^14 rounds. In a round, replica r increments its own entry once. Then each replica merges the state that replica r + 1 (mod 16) held after the increments. That is 262,144 increments and 262,144 merges. The checksum is the sum of the 16 counter values, in u32.

The program runs this twice. `gossip` gives replica r the ID r. `gossip-sparse` gives it the ID r * 250000000 + 7, so the IDs run from 7 to 3750000007.

| language | op | increment | merge |
|---|---|---|---|
| Bend | `gossip` | `Crdt.GCounter.inc(s, r)` | `Crdt.GCounter.merge(s, t)` |
| Bend | `gossip-sparse` | `Crdt.KCounter.inc(~U32, ~U32.cmp, s, id)` | `Crdt.KCounter.merge(~U32, ~U32.cmp, s, t)` |
| Rust | both | `GCounter::inc(id)`, then `apply` | `GCounter::merge` on a clone of the neighbor |

## Results

M4 Pro, macOS 26.6.2, 2026-10-25. Five runs (`python3 run.py 5`), median, in ms.

Versions: Bend 2.0.38, rustc 1.91.0, crdts 7.3.2.

| op | Rust | Bend |
|---|---:|---:|
| gossip | 91.6 | 56.9 |
| gossip-sparse | 87.8 | 152.9 |

Both programs print the checksum 4192624 for each op.

## Reading it

- `crdts::GCounter` keeps a `BTreeMap` from actor to count and reads the total as a `BigUint`, so the actor values do not change its cost. Bend's `GCounter` keeps a list of `U32` counts, one for each replica index. The Bend state is smaller, and a merge walks two lists in step.
- `KCounter` keeps a sorted list of `(id, count)` entries. A merge walks both lists in step and calls `cmp` once for each step, and an increment walks to the ID. It is about 2.7 times slower than the dense list and 1.7 times slower than Rust here. It wins when IDs are far apart: a dense list for these IDs would hold 3,750,000,008 entries.
- Rust clones the neighbor state, because `merge` takes it by value. Bend shares it.

## Not compared

- C: no standard library or popular library has a G-Counter.
- Python: no popular package has a state-based G-Counter.
- JavaScript: Yjs has no counter type. Automerge's `Counter` is an operation-based counter inside a document, so it is a different algorithm. A G-Counter written for this bench would reimplement the package, which the bench rules forbid.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads R from argv, so the work cannot run before the clock starts.
- Bend reads the stop time after it prints the checksum. The measured time includes checksum output.
- One machine, one size, one thread.
