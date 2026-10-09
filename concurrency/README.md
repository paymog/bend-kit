# concurrency

Parallel map and reduce over lists and arrays, a worker pool, select over channels, and timeouts, on Base's parallel calls, `IO.spawn`, `IO.fork`, and `Chan`.

```bend
import bend-kit-concurrency@0.2.0.0/concurrency.bend as Conc
```

## Pure parallelism

| def | answers |
|---|---|
| `par_map(~A, ~B, ~f, workers, xs)` | `List.map(f, xs)` |
| `par_reduce(~A, ~f, workers, z, xs)` | the left fold of `xs` from `z` |
| `par_map.array(~A, ~B, ~f, workers, a)` | `f` on every slot of `a`, each at its index |
| `par_reduce.array(~A, ~f, workers, a)` | the slots of `a` combined in index order |

`workers` is a `U32`. The input splits into at most `workers` balanced parts, rounded down to a power of two, and the parts run as parallel calls (`a b = f(x) g(y)`). A native build spreads them over its `--threads`; the JavaScript target runs them one after another. Results keep the input order. 0 or 1 workers run one sequential part.

`par_reduce` needs an associative `f`. The list form also needs `z` to be `f`'s identity, since each part folds from `z`, and so its element type is `Data`. An `Array` is never empty, so the array form takes no `z`.

Pick `workers` from `IO.thread_count()` for the whole machine. Parallel calls cost a task each, so a part should do enough work to pay for it.

## IO

| def | does |
|---|---|
| `pool(~S, ~A, ~B, ~work, states, xs)` | runs `work(s, x)` for each `x` on one worker per state; answers `(final states, results)` in worker order and in the order of `xs` |
| `select(A, chans)` | answers one `Chan(U32 & A)` that carries `(i, value)` for each value received on `chans[i]` |
| `timeout(A, ms, act)` | `Some{result}` if `act` finishes within `ms` milliseconds, else `None` at the deadline |

`pool` keeps affine handles safe: each worker owns one state of type `S` and threads it through its jobs, with `work: S -> A -> IO(S & B)`. A connection pool or socket is never shared between workers, and the caller gets each state back to close it. Jobs go on one queue, so a free worker takes the next one; each job has its own reply channel, which keeps the results in order. `pool` fails with no states.

`select` starts one relay per source. `Chan.recv` on the selector waits for whichever source is ready first, and answers `None` once every source is closed. The selector owns the receiving side of its sources: do not receive from them elsewhere. Close the selector to stop early; each relay then drops the one value it holds, if any, and stops. A relay forwards at most about 1.4 billion values, since its loop counts down `Nat` fuel.

Base has no cancellation. `timeout` does not stop `act`: it runs on, and its late result is dropped. A Bend program exits only when every computation is done, so it also waits for an abandoned `act` and for the timer. Likewise a relay that waits on a source that never closes keeps the program from ending.

## Checks

`bend check.bend` checks the `par_map` checksum on 64 CPU-bound jobs with 1 and 8 workers and reports both times. It checks that a 50 ms `timeout` wins over a 600 ms action and keeps a quick result, that `select` answers channels in the order they become ready and closes after them, and that `pool` runs 8 sleeping jobs on 4 workers with the results in order. `bench/` measures parallel speedup without making the test sensitive to machine load.

`bench/` compares `par_map` with the same job on threads in C, Rust, JavaScript, and processes in Python. See [bench/README.md](bench/README.md).
