# CRDT benchmark

This times local updates and state merges among 16 replicas. It compares `crdt` against `crdts::GCounter` in Rust, once with dense replica IDs and once with sparse ones. It also compares `PNCounter` against `crdts::PNCounter`.

## Run

Run these commands from `crdt/bench/`.

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
python3 run.py 1 2  # 1 run at 4 rounds; check every supported op
```

The second argument sets log2(rounds). It defaults to 14. Small runs use the same operations and checksum checks as the default run.

You need `bend`, `cargo`, and `python3`. Cargo fetches `crdts` 7.3.2. Binaries go to `out/`, which git ignores. The script exits non-zero if a build fails, or if the programs disagree on the checksum.

## The op

Each program starts 16 empty counters and runs R = 2^14 rounds. In a round, replica r increments its own entry once. Then each replica merges the state that replica r + 1 (mod 16) held after the increments. That is 262,144 increments and 262,144 merges. The checksum is the sum of the 16 counter values, in u32.

The program runs this twice. `gossip` gives replica r the ID r. `gossip-sparse` gives it the ID r * 250000000 + 7, so the IDs run from 7 to 3750000007.

`gossip-pn` uses dense IDs. Each replica increments twice and decrements once per round, then merges its successor's state. It runs 524,288 increments, 262,144 decrements, and 262,144 merges. Both halves grow. Its net value and checksum match `gossip`.

`read-pn-exact` starts both PN halves at 4294967296, split across two replica entries. It reads the exact signed value, adds its magnitude to a U32 checksum, and increments replica 1. It repeats R times. The timer excludes setup and includes the reads and updates. Bend uses `PNCounter.value_exact`; Rust uses `PNCounter::read`. The checksum is 134209536.

`read-keyed-exact` starts a keyed counter at 4294967296 with counts 4294967295 and 1 under IDs 7 and 4000000000. Each round reads the unbounded total and increments the second ID. The timer excludes setup and includes reads and updates. Bend uses `KCounter.value_exact`; Rust uses `crdts::GCounter::read`. Both add the low 32 bits of each total to a wrapping U32 checksum. The default checksum is 134209536.

| language | op | increment | merge |
|---|---|---|---|
| Bend | `gossip` | `Crdt.GCounter.inc(s, r)` | `Crdt.GCounter.merge(s, t)` |
| Bend | `gossip-sparse` | `Crdt.KCounter.inc(~U32, ~U32.cmp, s, id)` | `Crdt.KCounter.merge(~U32, ~U32.cmp, s, t)` |
| Rust | both | `GCounter::inc(id)`, then `apply` | `GCounter::merge` on a clone of the neighbor |

## Results

macOS arm64, 2026-11-24. Three runs (`python3 run.py 3`), median, in ms.

Versions: Bend 2.0.40, rustc 1.91.0, crdts 7.3.2.

| op | Rust | Bend |
|---|---:|---:|
| gossip | 79.7 | 55.1 |
| gossip-sparse | 79.1 | 73.7 |
| gossip-pn | 165.0 | 175.6 |
| read-pn-exact | 0.3 | 1.1 |
| read-keyed-exact | 0.1 | 0.2 |

Both programs print the checksum 4192624 for each gossip op and 134209536 for each exact read op.

## Reading it

- `crdts::GCounter` keeps a `BTreeMap` from actor to count and reads the total as a `BigUint`, so the actor values do not change its cost. Bend's `GCounter` keeps a list of `U32` counts, one for each replica index. The Bend state is smaller, and a merge walks two lists in step.
- `KCounter` keeps a sorted list of `(id, count)` entries. A merge walks both lists in step and calls `cmp` once for each step. It supports far-apart IDs without dense padding: a dense list for these IDs would hold 3,750,000,008 entries.
- Rust clones the neighbor state, because `merge` takes it by value. Bend shares it.
- `PNCounter` merges two dense G-Counters. Rust keeps two G-Counters backed by maps and reads their difference as a `BigInt`. Bend offers a checked U32 signed magnitude and an exact `Nat` signed magnitude.

## Not compared

- C: no standard library or popular library has a G-Counter.
- Python: no popular package has a state-based G-Counter.
- JavaScript: Yjs has no counter type. Automerge's `Counter` is an operation-based counter inside a document, so it is a different algorithm. A G-Counter written for this bench would reimplement the package, which the bench rules forbid.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock. It reads R from argv, so the work cannot run before the clock starts.
- The G-Counter timers include checksum output in Bend. The PN-Counter timer stops before output.
- One machine, one size, one thread.
