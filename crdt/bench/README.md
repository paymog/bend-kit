# CRDT benchmark

This times the G-Counter hot path: local increments and state merges among 16 replicas. It compares `crdt` against `crdts::GCounter` in Rust.

## Run

Run these commands from `crdt/bench/`.

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cargo`, and `python3`. Cargo fetches `crdts` 7.3.2. Binaries go to `out/`, which git ignores. The script exits non-zero if a build fails, or if the programs disagree on the checksum.

## The op

Each program starts 16 empty counters and runs R = 2^14 rounds. In a round, replica r increments its own entry once. Then each replica merges the state that replica r + 1 (mod 16) held after the increments. That is 262,144 increments and 262,144 merges. The checksum is the sum of the 16 counter values, in u32.

| language | increment | merge |
|---|---|---|
| Bend | `Crdt.GCounter.inc(s, r)` | `Crdt.GCounter.merge(s, t)` |
| Rust | `GCounter::inc(r)`, then `apply` | `GCounter::merge` on a clone of the neighbor |

## Results

M4 Pro, macOS 26.6.2, 2026-10-23. Five runs (`python3 run.py 5`), median, in ms.

Versions: Bend 2.0.38, rustc 1.91.0, crdts 7.3.2.

| op | Rust | Bend |
|---|---:|---:|
| gossip | 80.4 | 55.3 |

Both programs print the checksum 4192624.

## Reading it

- `crdts::GCounter` keeps a `BTreeMap` from actor to count and reads the total as a `BigUint`. Bend keeps a list of `U32` counts, one for each replica index. The Bend state is smaller, and a merge walks two lists in step.
- Rust clones the neighbor state, because `merge` takes it by value. Bend shares it.

## Not compared

- C: no standard library or popular library has a G-Counter.
- Python: no popular package has a state-based G-Counter.
- JavaScript: Yjs has no counter type. Automerge's `Counter` is an operation-based counter inside a document, so it is a different algorithm. A G-Counter written for this bench would reimplement the package, which the bench rules forbid.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads R from argv, so the work cannot run before the clock starts.
- Bend reads the stop time after it prints the checksum. The measured time includes checksum output.
- One machine, one size, one thread.
