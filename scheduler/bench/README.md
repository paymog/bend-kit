# Scheduler benchmark

```sh
python3 scheduler/bench/run.py 3
```

Fixed input: enqueue 1,024 one-shot U32 payloads in ID order, with deadline `(id * 37) % 64`; drain all tasks with supplied time 64. Hash selected IDs in order using wrapping U32 `hash = hash * 31 + id`. Every implementation prints checksum **1499750400**, which the runner checks across implementations and repetitions. Bend additionally completes each running token. Timers cover construction, ordering and draining, not executable startup or compilation. Median of three fresh-process runs.

Measured on an arm64 Mac, macOS 25.6.0, Bend 2.0.36, Apple clang 17.0.0, Rust 1.91.0, Python 3.14.6, Bun 1.3.14:

| Implementation | Median ms |
|---|---:|
| C qsort (batch) | 0.048 |
| Rust BinaryHeap | 0.026 |
| Python heapq | 0.453 |
| JavaScript sort (batch) | 1.356 |
| Bend scheduler | 0.924 |

Rust uses `std::collections::BinaryHeap<Reverse<(deadline, id)>>`; Python uses `heapq`. C and JavaScript have no standard-library mutable priority queue: their standard sorting functions give the same stable logical `(deadline, id)` output for this **batch-only** workload. They are not comparisons of dynamic enqueue/cancellation/recurrence. No priority-queue implementation is recreated in another language. Cold JavaScript JIT overhead is included in its timed section. The checksum verifies ordering, not deadline punctuality.

This benchmark targets enqueue/select/complete, not cancellation or replay planning. It makes no fairness or OS timer accuracy claim. Build products live in `out/`, ignored by git; the Bend native executable runs one at a time on this small input. Bend times itself with `Time.mono.us()`, monotonic microseconds.
