# Collections benchmark

This times insert and lookup on `OMap` and `HMap`, push and index on `Vec`, push and pop on `Deque`, and push and pop on `Heap`. It compares each against the closest standard-library container in Rust, Python, and JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median; Python runs once
python3 run.py 5    # 5 runs
```

You need `bend`, `rustc`, `bun`, `node`, and `python3`. Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, or if two programs disagree on a checksum.

## The ops

Every op uses N = 2^20 elements. `bench.rs`, `bench.py`, and `bench.ts` take log2(N) as their first argument. `bench.bend` has N built in. Keys come from the LCG `x = x*1664525 + 1013904223` (mod 2^32), seeded with 1. Its first N outputs are distinct. Checksum math is u32 and wraps. `mix(acc, x)` is `acc*31 + x`.

| op | work | checksum |
|---|---|---|
| `omap_put` | put key `x_i` with value `i`, for i < N | size |
| `omap_get` | get every key in the same order | sum of the values |
| `hmap_put` | put key `x_i` with value `i`, using `x_i` as its hash | size |
| `hmap_get` | get every key in the same order | sum of the values |
| `vec_push` | push 0..N-1 onto an empty vector | length |
| `vec_get` | N reads at index `x_i >> 12` | sum of the values |
| `deque_push` | push 0..N-1 onto the back | length |
| `deque_pop` | pop N/2 from the front, then N/2 from the back | `mix` over the popped values |
| `heap_push` | push `x_i` onto a min-heap, for i < N | size |
| `heap_pop` | pop every element | `mix` over the popped values, in ascending order |

| language | omap | hmap | vec | deque | heap |
|---|---|---|---|---|---|
| Bend | `OMap` | `HMap` | `Vec` | `Deque` | `Heap` |
| Rust | `BTreeMap` | `HashMap` | `Vec` | `VecDeque` | `BinaryHeap<Reverse<u32>>` |
| Python | none | `dict` | `list` | `collections.deque` | `heapq` |
| JavaScript | none | `Map` | `Array` | none | none |

C is left out: its standard library has no containers. Python and JavaScript have no sorted map. JavaScript also has no deque or heap. `Array.shift` is not a deque.

A push op stops its clock before it reads the size, so the checksum does not add time. That matters for `Deque.length`, which walks the lists.

## Results

M4 Pro, macOS, 2026-09-28. One run (`python3 run.py 1`), in ms. Other runs can vary.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| omap_put | 135.3 | n/a | n/a | n/a | 3,169.6 |
| omap_get | 123.1 | n/a | n/a | n/a | 2,976.1 |
| hmap_put | 23.2 | 58.3 | 96.4 | 193.7 | 960.5 |
| hmap_get | 15.5 | 34.9 | 59.6 | 272.8 | 1,827.4 |
| vec_push | 0.6 | 5.4 | 12.8 | 31.6 | 2.2 |
| vec_get | 1.2 | 19.9 | 6.2 | 413.1 | 1.3 |
| deque_push | 0.9 | n/a | n/a | 34.9 | 130.0 |
| deque_pop | 0.8 | n/a | n/a | 116.9 | 952.9 |
| heap_push | 8.2 | n/a | n/a | 180.5 | 544.0 |
| heap_pop | 45.3 | n/a | n/a | 1,275.6 | 1,829.8 |

Every program that runs an op prints the same checksum:

| op | checksum |
|---|---:|
| omap_put | 1048576 |
| omap_get | 4294443008 |
| hmap_put | 1048576 |
| hmap_get | 4294443008 |
| vec_push | 1048576 |
| vec_get | 331289856 |
| deque_push | 1048576 |
| deque_pop | 4018143232 |
| heap_push | 1048576 |
| heap_pop | 3458314104 |

## Reading it

- `HMap` inserts in about 0.9 µs and looks up in about 1.7 µs per key on this run. Its trie path is bounded by 32 bits, but collision buckets require a linear scan.
- `Vec` sits on `Array`, and `Deque` uses two lists with O(1) amortized ends.
- `OMap` balances a tree at each insertion or deletion. `Heap` is a tree of nodes, not an array.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one size, one thread. These measure the containers, not a program that uses them.
