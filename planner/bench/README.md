# Planner benchmark

This times the hot path of `planner`: the plan of one target whose closure is a whole graph. It compares `plan` against a topological sort from a standard or popular library in Rust, Python, and JavaScript.

## Run

```sh
python3 run.py          # 3 runs per variant, 16 plans per run, median
python3 run.py 5 16     # 5 runs, 16 plans per run
```

You need `bend` (2.0.38, the CI pin), `cargo`, `bun`, `node`, `npm`, and `python3`. `run.py` installs `toposort@2.0.2` into `out/js`, and cargo fetches `petgraph`. Binaries go to `out/`, which git ignores. It exits non-zero if a build or install fails, or if two programs disagree on the checksum.

## The op

The graph has 1,000 nodes, `n0` to `n999`. Node `ni` requires `n(i+1)`, `n(i+2)`, and `n(i+3)` when they exist, so there are 2,997 edges and `n0` reaches every node. Each program plans the graph 16 times. The checksum adds, for each planned node, 1 plus its number, in u32.

| language | op |
|---|---|
| Bend | `plan.fast(~String, ~String.eq, ~Order.string, g, ["n0"])`: the closure and a dependency order, with sets and the graph in ordered maps |
| Rust | `petgraph` 0.8.3: build a `DiGraph` from the ids through a `HashMap`, then `algo::toposort` |
| Python | `graphlib.TopologicalSorter`: `add` each node, then `static_order` |
| JavaScript | `toposort` 2.0.2: build the edge list, then `toposort(edges)` |

C has neither a standard nor a dominant topological sort library, so C is left out.

## Results

M4 Pro, macOS 26.7.2, 2026-11-18. Five runs (`python3 run.py 5 16`), median, in ms. The load average was about 2.5 during the runs.

Versions: Bend 2.0.38, rustc 1.91.0, petgraph 0.8.3, Bun 1.4.4, Node 24.0.1, toposort 2.0.2, Python 3.14.6.

| op | Rust | Bun | Node | Python | Bend |
|---|---:|---:|---:|---:|---:|
| plan x16 | 1.8 | 8.5 | 11.9 | 24.5 | 109.4 |

Every program prints the checksum 8008000.

## Reading it

- Bend is about 4.5 times slower than Python. `plan.fast` keeps the open path, the finished nodes, and the graph in `OMap`s from `collections`, so a plan takes O(n log n) comparisons of `String` ids, one character at a time. The baselines hash each id once.
- The list version, `plan`, took 1,981.7 ms on this bench: it compares ids O(n²) times and checks its result again. `plan.fast` answers exactly as `plan` (law `plan_index`), and the completeness laws prove that the check always passes, so `plan.fast` leaves it out.
- `graphlib` and `toposort` sort every node they are given. `plan.fast` visits only the closure of the targets; here the closure is the whole graph.

## Caveats

- Bend times itself with `Time.mono`. It reads the plan count from argv, so the work cannot run before the clock starts.
- One machine, one graph shape, one size.
