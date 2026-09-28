# Collections benchmark

This times insert and lookup on `OMap`, push and index on `Vec`, push and pop on `Deque`, and push and pop on `Heap`. It compares each against the closest standard-library container in Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median; Python runs once
python3 run.py 5    # 5 runs
```

You need `bend`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. The run takes about 20 seconds. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The ops

Every op uses N = 2^20 elements. `bench.rs`, `bench.py`, and `bench.ts` take log2(N) as their first argument. `bench.bend` has N built in. Keys come from the LCG `x = x*1664525 + 1013904223` (mod 2^32), seeded with 1. Its first N outputs are distinct. Checksum math is u32 and wraps. `mix(acc, x)` is `acc*31 + x`.

| op | work | checksum |
|---|---|---|
| `omap_put` | put key `x_i` with value `i`, for i < N | size |
| `omap_get` | get every key in the same order | sum of the values |
| `vec_push` | push 0..N-1 onto an empty vector | length |
| `vec_get` | N reads at index `x_i >> 12` | sum of the values |
| `deque_push` | push 0..N-1 onto the back | length |
| `deque_pop` | pop N/2 from the front, then N/2 from the back | `mix` over the popped values |
| `heap_push` | push `x_i` onto a min-heap, for i < N | size |
| `heap_pop` | pop every element | `mix` over the popped values, in ascending order |

| language | omap | vec | deque | heap |
|---|---|---|---|---|
| Bend | `OMap` | `Vec` | `Deque` | `Heap` |
| Rust | `BTreeMap` | `Vec` | `VecDeque` | `BinaryHeap<Reverse<u32>>` |
| Python | none | `list` | `collections.deque` | `heapq` |
| JavaScript | none | `Array` | none | none |

C is left out: its standard library has no containers. Python and JavaScript have no sorted map; their `dict` and `Map` are hash maps, which do a different job. JavaScript also has no deque or heap. `Array.shift` is not a deque.

A push op stops its clock before it reads the size, so the checksum does not add time. That matters for `Deque.length`, which walks the lists.

## Results

M4 Pro, macOS, 2026-09-27. Bend 2.0.31, rustc 1.91.0, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs, except Python (one run). Times are in ms.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| omap_put | 118.2 | n/a | n/a | n/a | 2,321.0 |
| omap_get | 122.3 | n/a | n/a | n/a | 2,253.0 |
| vec_push | 0.7 | 4.5 | 5.6 | 32.2 | 2.0 |
| vec_get | 1.1 | 9.0 | 6.2 | 370.0 | 1.3 |
| deque_push | 0.5 | n/a | n/a | 34.2 | 18.7 |
| deque_pop | 0.8 | n/a | n/a | 114.1 | 67.8 |
| heap_push | 8.4 | n/a | n/a | 161.3 | 470.2 |
| heap_pop | 45.8 | n/a | n/a | 1,310.8 | 1,553.2 |

Every program that runs an op prints the same checksum:

| op | checksum |
|---|---:|
| omap_put | 1048576 |
| omap_get | 4294443008 |
| vec_push | 1048576 |
| vec_get | 331289856 |
| deque_push | 1048576 |
| deque_pop | 4018143232 |
| heap_push | 1048576 |
| heap_pop | 3458314104 |

## Reading it

- `Vec` stays within a few ms of Rust. `Deque` takes tens of ms more. The vector sits on `Array`, and the deque on two lists with O(1) amortized ends.
- `OMap` is about 19 times slower than `BTreeMap`, and takes about 2.2 µs per operation. The likely costs, not measured: every comparison goes through `Cmp.case` closures, every put rebuilds its path with a rebalance check at each level, and a B-tree keeps many keys per node.
- `Heap` push is about 56 times slower than Rust's, and pop is about 19% slower than Python's `heapq`. `Heap` is a tree of nodes, not an array.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one size, one thread. These measure the containers, not a program that uses them.
