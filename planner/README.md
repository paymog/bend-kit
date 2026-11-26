# planner

Dependency plans for builds and task graphs. `plan` gives the dependency closure of the requested targets in an order where every prerequisite comes first, or says which node is missing or which cycle blocks the plan. `invalidate` finds what an input change makes stale, and `exec` decides which nodes run, which are reused, and which are skipped. `build` runs real commands on top of them. `LAWS.bend` states these properties for every graph, and `PROOF.bend` proves them.

```bend
import bend-kit-planner@0.5.1.1/planner.bend as P
```

It imports `bend-kit-bytes@0.3.3.2`, `bend-kit-hash@0.3.2.3`, `bend-kit-files@0.4.0.2`, `bend-kit-process@0.5.2.2`, and `bend-kit-collections@0.1.6.0`.

## Example

Build `app` from `lib`. A second build reuses both; a change to `lib.c` rebuilds `lib` and then `app`.

```bend
import Base
import bend-kit-planner@0.5.1.1/planner.bend as P

def tasks() -> List<&2, P.Task>:
  [P.Task{"app", ["lib"], ["cc", "-o", "app", "main.c", "lib.o"], ["main.c"]},
   P.Task{"lib", [], ["cc", "-c", "lib.c"], ["lib.c"]}]

def show(es: List<&2, P.Outcome>) -> IO(Unit):
  match es:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{P.Outcome{x, s, r}, t}:
      do IO<Unit>:
        IO.print(x ++ " " ++ P.Status.show(s))
        show(t)

def main() -> IO(Unit):
  do IO<Unit>:
    es : List<&2, P.Outcome> <- IO.try(List<&2, P.Outcome>, P.build(tasks(), ["app"], ".", ".planner-stamps", 4))
    show(es)
```

The first run prints `lib built` and `app built`; the second prints `lib fresh` and `app fresh`. [check.bend](check.bend) runs a diamond of shell commands through a first build, a reuse, an input change, a failed command, a cycle, and a missing node, and checks the order and the count of runs from a log the commands write.

## Model

The pure core is generic. A node id has any `Data` type `K` with an equality test `eq: K -> K -> Bool`.

| type | values |
|---|---|
| `Node<K>` | `Node{id, deps}`: a node and the nodes it requires |
| graph | `List<&2, Node<K>>`; when two nodes share an id, the first one counts |
| `Error<K>` | `Missing{node, chain}`, `Cycle{path}`, or `Refused{}` |
| `Status` | `Built{}`, `Fresh{}`, `Failed{}`, or `Skipped{}` |
| `Entry<K>` | `Entry{node, status}` |

**Inclusion rule.** The plan holds the targets and, for each node it holds, every prerequisite. It holds nothing else.

**Prerequisites must succeed.** A node runs, or is reused, only when each of its prerequisites ended `Built` or `Fresh`. Otherwise the node is `Skipped` and its command does not run. An undefined node is also `Skipped`.

**Stale nodes.** A node is stale when it changed, or when it requires a stale node. `exec` runs a stale node and reuses a node that is not stale. So a change reruns the changed node and everything downstream of it, and nothing else.

`plan` walks the graph depth first and then checks the result. The check confirms that each node is defined, comes once, and comes after all its prerequisites; that each node is a target or a prerequisite of a later node; and that each target is in the plan. The safety laws follow from the check, so they hold for every graph. The completeness laws prove that the walk always passes the check, so `Refused{}` never happens. A path never repeats a node, and every node on it is defined, so the walk needs one level of fuel for each node of the graph.

## API

Import `planner.bend` as `P`. The pure functions take `~K` and `~eq` as templates, as in `P.plan(~String, ~String.eq, g, ts)`.

| def | result |
|---|---|
| `plan(g, ts)` | `Done{p}`: the closure of `ts` in dependency order, each node once; or `Fail{e}` |
| `plan.fast(~cmp, g, ts)` | the same answer as `plan`, with sets and the graph in ordered maps keyed by `cmp` |
| `invalidate(p, g, changed)` | the stale nodes of `p`, latest first |
| `invalidate.fast(~cmp, p, g, changed)` | the same answer as `invalidate`, with indexed lookups |
| `decide(g, stale, st, x)` | `Run{}`, `Mark{status}`, or `Pass{}` for node `x` in state `st` |
| `step(a, st, x, rs)` | `st` after action `a`; a `Run` takes its result from the head of `rs` |
| `exec(p, g, stale, st, rs)` | the state after each node of `p`, newest first; `rs` holds the command results in order |
| `status(st, x)` | `Maybe`: the status of `x` |
| `deps(g, x)` | `Maybe`: the prerequisites of `x`; `None` when `x` is undefined |
| `member(xs, x)`, `all_in(xs, ys)`, `any_in(xs, ys)`, `distinct(xs)` | the list tests the laws use |

`Error<K>`:

| error | meaning |
|---|---|
| `Missing{node, chain}` | `node` is undefined; `chain` runs from a target to the node that names it |
| `Cycle{path}` | each node of `path` requires the next, and the last is the first, as in `["a", "b", "a"]` |
| `Refused{}` | the candidate failed the check; a planner bug |

The build layer fixes `K` to `String`.

| def | result |
|---|---|
| `Task{id, deps, argv, inputs}` | a node with its command and the source files it reads; an empty `argv` is a group with no command |
| `build(tasks, targets, dir, path, jobs)` | `Run`: an `Outcome{node, status, ran}` for each planned node, in plan order. It plans `targets`, hashes each task, runs the stale tasks in `dir`, up to `jobs` at once (at least 1), reuses the rest, and writes the stamps to `path` |
| `Ran` | what a command left: `Exited{code, out, err}`, with the last 4096 octets of stdout and stderr as byte strings, or `Unstarted{error}`. `ran` is `None` when no command ran: the node was reused, skipped, or a group |
| `Error.show(e)`, `Status.show(s)` | text for an error or a status |

`build` runs each command with `process` in `dir`, with no shell, no stdin, and the inherited environment. Exit status 0 is `Built`; any other status, or a failure to start, is `Failed`. Paths in `inputs` are relative to `dir`. `build` fails, and runs nothing, when a task id is empty or not printable ASCII, or when `plan` fails.

`build` starts nodes in plan order. A node waits while one of its prerequisites runs, or while `jobs` commands run; then the first command to finish lets it go on. So independent tasks run at the same time: in a diamond, the two middle tasks run together. The JavaScript lane runs one command at a time, because its `process.run` blocks; a native build runs them at once.

| def | result |
|---|---|
| `par(es, p, g, stale, limit, pool)` | the model of a parallel run: `es` holds the finishes in the order they arrive |
| `decide.par(g, stale, limit, pool, x)` | `PSkip{}`, `PMark{status}`, `PStart{}`, or `PWait{}` for node `x` |
| `par.fast(~cmp, es, p, gidx(g), idx(stale), limit, lift(pool))` | `lift` of the `par` answer: the pool and an ordered map of its statuses |
| `finish(pool, e)`, `apply(a, pool, x)` | the pool after a finish, or after a decision |

## Laws

`LAWS.bend` states these for every node type, graph, target list, change set, and sequence of command results. `PROOF.bend` proves them.

| law | claim |
|---|---|
| `plan_defined` | every node of a plan is defined |
| `plan_before` | each prerequisite of a node comes before it |
| `plan_once` | no node comes twice |
| `plan_targets`, `plan_closed` | the plan holds every target, and every prerequisite of a node it holds |
| `plan_least` | every set that holds the targets and the prerequisites of its members holds the plan; so the plan is exactly the closure |
| `plan_cycle`, `plan_cycle_target` | no plan holds a node of a set whose every member requires a member, such as a cycle; so a target on a cycle has no plan |
| `plan_missing`, `plan_missing_chain` | a reported missing node is undefined, and its chain runs from a target through nodes that each require the next |
| `plan_cycle_path` | a reported cycle is a cycle: each node requires the next, and the last is the first |
| `plan_complete` | `plan` never gives `Refused{}`. So it fails only for a true missing node or a true cycle, and it plans every other graph |
| `plan_index`, `stale_index` | for a total order `cmp` that agrees with `eq`, `plan.fast` equals `plan` and `invalidate.fast` equals `invalidate` |
| `stale_changed`, `stale_dependents` | a changed node of `p` is stale, and so is every node of a plan that requires a stale node |
| `stale_least` | every set that holds each node of `p` that changed or requires a member holds every stale node; so invalidation is minimal |
| `exec_ready` | a node that ran or was reused had every prerequisite `Built` or `Fresh` |
| `exec_blocked` | a prerequisite that did not succeed keeps its dependents from success |
| `exec_once` | each node gets at most one status, so its command runs at most once |
| `exec_total` | each node of `p` gets a status |
| `exec_fresh` | a stale node is never reused |
| `par_ready`, `par_running` | in a parallel run, a node that ran, was reused, or runs now had every prerequisite `Built` or `Fresh` |
| `par_blocked` | in a parallel run, a prerequisite that did not succeed keeps its dependents from success |
| `par_once`, `par_once_status` | each command starts at most once, and each node gets at most one status |
| `par_fresh` | in a parallel run, a stale node is never reused |
| `par_limit` | no more than `limit` commands run at once |
| `par_total` | with room for one command, a run that ends with nothing running gives every node of `p` a status |
| `par_index` | for a total order `cmp` that agrees with `eq`, `par.fast` runs as `par` and its status index stays exact |

Every law takes `eq` as sound: `eq(x, y)` gives `x == y`. The completeness and parallel laws also take it as reflexive: `eq(x, x)`. `String.eq` is both. The `exec_` and `par_` laws hold for any node list, not only a plan, and the `par_` laws hold for every order in which commands finish. The fixture laws check the same functions on a diamond, a cycle, and a missing node.

## Trust boundary

The proofs cover the pure core. They do not cover hashing, the disk, or the commands.

- **Declared dependencies.** Reuse is safe only when each task declares every task whose output it reads, and lists every source file it reads in `inputs`. A read that the declarations miss is not tracked.
- **Inputs are sources.** `build` hashes all inputs before it runs a command. List only files that no task writes; an edge to the task that writes a file covers that file.
- **Commands.** A command that exits 0 is taken to have written its outputs. `build` does not check them, and it does not sandbox the command.
- **Hashing.** A stamp is xxHash64 over the argv, the prerequisite ids, and each input path and its octets. xxHash64 is not cryptographic: two inputs with one hash can make a stale task look fresh. Do not reuse outputs across a trust boundary on these stamps.
- **The run loop.** `build` repeats the shape of `par` in `IO`: it uses `decide.par`, `apply`, and `finish` for each step, and takes each finish from a job's message. The laws cover `par`. A wait always finds a running command when `jobs` is at least 1, which `build` ensures.
- **Stamps file.** `build` writes the stamps through `path.tmp` and a rename, so a reader sees the old file or the new one. A crash before the rename keeps the old stamps, so the next build reruns what the lost build ran. An unreadable stamps file counts as empty. Two builds that share a stamps file must not run at once.

## Limits

- `plan.fast` and `invalidate.fast` take O(n log n) comparisons, and `build` uses them. A plan of 1,000 nodes takes about 7 ms. See [bench/README.md](bench/README.md).
- `build` runs through `par.fast` and looks up tasks, stamps, and command output in ordered maps, so a build of n tasks takes O(n log n) comparisons outside the commands. The run model on 1,000 nodes takes about 10 ms.
- `plan`, `invalidate`, `exec`, and `par` are the list models that the laws speak about. They take O(n²) comparisons. `exec` has no indexed version, because `build` does not use it.
- A task id is printable ASCII and not empty, because the stamps file holds one id per line.

## Bench

`bench/` times a plan of a 1,000-node graph against `petgraph`, `graphlib`, and `toposort` in Rust, Python, and JavaScript. See [bench/README.md](bench/README.md).
