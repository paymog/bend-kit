# Camber design directions

Status: ideas to evaluate, not frozen public interfaces or implemented guarantees.

## Priorities

Most or all consumers are expected to be AI agents. Correctness and performance take priority over concise authoring. Verbose types, quantities, and ownership transfers are acceptable when explicit and consistent. Optimize for fewer independent decisions, not fewer lines. Do not depend on an agent inferring hidden invariants.

Live serving targets a dedicated supervised process. Runtime cancellation and embedded-server lifecycle isolation are not release requirements. Request identity and sibling-policy isolation still are. See [SPEC](SPEC.md) and [FINDINGS](FINDINGS.md).

## Worth pursuing

1. **Measure progress under load.** Observe ordinary request latency and client-visible read-timeout behavior alongside permitted CPU work. Compare native single-thread, native default CPU-thread configuration, and JS. External termination does not establish server responsiveness. Distinguish completion of a host IO operation from delivery of its result through Bend and subsequent socket closure.
2. **Keep one canonical route description.** Method, path, selected policy, and dispatch identity should not be repeated in independent selectors. Explicit action enums and handler matches are acceptable. Validate registration and dispatch coverage. Do not add a generator or schema language merely to reduce lines.
3. **Keep ownership explicit.** Separate copyable configuration, request context, packed body, and affine dependency state. Success and expected failure return state. Framework code owns hook ordering, framing, admission, worker channels, and lifecycle; route authors should not reproduce these protocols.
4. **Prefer whole resource-bundle admission initially.** The live candidate admits a worker-owned bundle rather than nesting checkouts in opposing orders. This avoids the demonstrated acquisition deadlock, not all deadlocks. Measure reservation costs; distinguish a shared client pool from a checked-out connection so whole-pool ownership does not serialize independent work. Do not add a general dependency-injection system without a demonstrated need.
5. **Profile shared byte work before changing hooks.** The raw HTTP control also has the large-body gap. Measure repeated traversal, conversion, copying, and allocation. Keep bodies packed. Use the existing native-effect pattern for measured heavy byte work where appropriate; native code is not automatically nonblocking or cancellable. Check throughput and responsiveness separately.
6. **Evaluate agent use by outcomes.** The useful exercise is adding an authenticated route with an affine dependency and an expected failure without changing framework internals, leaking resources, or weakening policy. Compilation, public response behavior, ownership recovery, and overhead matter more than line count. Use complete compiling examples and actionable diagnostics. Independent-author validation remains unperformed under the current no-subagent constraint.

## Executed progress probe

`python3 -B camber/run_progress.py` completed 21 observations. [FINDINGS.md](FINDINGS.md#progress-under-cpu-load) and [progress_results.json](progress_results.json) retain the evidence. Yielding controls keep ordinary requests responsive; serial pure work delays them until compute finishes in native single/default-thread and JS configurations. A 200 ms Wire read timeout is followed by socket closure after about 541–543 ms native and 875 ms JS during CPU work. This is not an absolute HTTP phase-deadline test.

The next investigation is worst-case permitted parsing and real handler work. Bounded compute chunks with explicit yielding, nonblocking native effects, and separate execution are candidates to measure, not implemented fixes. More CPU threads did not solve the tested serial-work case.


## Deliberately not chosen

- A terse callback registry that hides or copies affine ownership.
- A second Camber router or transport.
- Automatic request replay after timeout, disconnect, or process termination.
- Worker-process IPC for every request. Consider separate execution for measured CPU-heavy work only if profiling justifies transfer, consistency, and lifecycle costs.
- Reducing failed benchmark allowances or relabeling timeouts as cancellation.

## Remaining uncertainty

The design has no confirmed existential incompatibility under dedicated-process scope. The synthetic CPU probe now establishes a shared event-loop progress risk, not its severity for normal application inputs. Transport correctness, strict JSON, and complete-application overhead still need evidence. A supervisor can terminate a stalled instance; it does not keep that instance responsive or roll back remote side effects.
