# Collections benchmark

This times insert and lookup on `OMap` and `HMap`, push and index on `Vec`, push and pop on `Deque`, and push and pop on `Heap`. It compares each against the closest standard-library container in Rust, Python, and JavaScript, plus `sortedcontainers` for Python and `js-sdsl` for JavaScript sorted maps.

## Run

```sh
python3 run.py      # 3 runs per variant, median; Python runs once
python3 run.py 5    # 5 runs
```

You need `bend`, `rustc`, `bun`, `node`, `npm`, `uv`, and `python3`. `run.py` installs `js-sdsl@4.4.2` into `out/js` and uses `uv` to run Python with `sortedcontainers==2.4.0`. Binaries also go to `out/`, which git ignores. It exits non-zero if a build or install fails, or if two programs disagree on a checksum.

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
| Python | `sortedcontainers.SortedDict` | `dict` | `list` | `collections.deque` | `heapq` |
| JavaScript | `js-sdsl.OrderedMap` | `Map` | `Array` | `js-sdsl.Deque` | `js-sdsl.PriorityQueue` |

C is left out: its standard library has no containers, and no single commonly used C library covers the same set of containers. Python's standard library has no sorted map, so omap uses `sortedcontainers.SortedDict`. `SortedDict` is a `dict` plus a sorted key list: `omap_put` pays for the sorted insert, but `omap_get` is a hash lookup, not a tree search. JavaScript uses `js-sdsl` for the ordered map, deque, and min-heap; its standard library has no equivalent.

A push op stops its clock before it reads the size, so the checksum does not add time. That matters for `Deque.length`, which walks the lists.

## Results

M4 Pro, macOS 26.6, 2026-09-28. Five runs (`python3 run.py 5`), in ms; Python runs once. Other runs can vary.

Versions: Bend 2.0.32, rustc 1.91.0, Bun 1.3.14, Node 24.0.1, js-sdsl 4.4.2, Python 3.14.6, sortedcontainers 2.4.0.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| omap_put | 128.7 | 531.7 | 550.7 | 1,352.0 | 3,027.9 |
| omap_get | 122.8 | 386.7 | 603.6 | 243.7 | 2,852.0 |
| hmap_put | 22.9 | 53.8 | 117.7 | 159.4 | 882.2 |
| hmap_get | 14.5 | 32.7 | 58.0 | 257.4 | 1,816.8 |
| vec_push | 0.6 | 6.5 | 4.4 | 32.1 | 2.1 |
| vec_get | 1.2 | 19.1 | 6.5 | 376.5 | 1.3 |
| deque_push | 0.8 | 6.1 | 7.6 | 34.2 | 129.9 |
| deque_pop | 0.8 | 19.5 | 11.1 | 117.1 | 909.3 |
| heap_push | 8.3 | 22.9 | 20.7 | 164.3 | 536.6 |
| heap_pop | 44.6 | 152.4 | 119.8 | 1,194.1 | 1,748.9 |

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
