# scheduler

Pure deadline queues and recurrence planning. Import `bend-kit-scheduler@0.4.2.0/queue.bend` as `Queue` and `bend-kit-scheduler@0.4.2.0/recurrence.bend` as `Recurrence`.

## Queue transitions

`State<A>` stores copyable payloads in the `collections@0.1.3.0` skew heap. Thread the returned state through every transition; do not fork state snapshots into independent runners.

| Operation | Result | Meaning |
|---|---|---|
| `new(A)` | State | Empty queue; first ID is zero. |
| `enqueue(~A, deadline, payload, state)` | State & Nat | Assign a fresh, never-reused ID. |
| `select(~A, now, state)` | State & Maybe Ticket | Select the minimum due ticket; move it from pending to running. |
| `complete(A, id, state)` | State & Maybe Ticket | Consume a running token once. Missing/cancelled/completed tokens return None. |
| `requeue(~A, id, deadline, state)` | State & Bool | Move an existing running token back to pending, retaining its ID. False if absent. |
| `cancel(~A, id, state)` | State | Remove that ID from pending and running; an unknown ID is a no-op. |
| `running(A, state)` | `List<&2, Ticket<A>>` | Read the tickets that have running tokens. |

A ticket is `Ticket{id, deadline, payload}`. Ordering is ascending `(deadline, id)`: equal deadlines retain original enqueue order, including after requeue. Selection uses `deadline <= now`; an early poll returns None without removing anything. A selected ticket is not pending again unless successfully requeued. For one-shot work, complete it after execution.

Serialize transitions with one state owner. Cancellation before selection prevents selection. Cancellation after selection cannot stop an already-dispatched host action, but removes its running token so completion/requeue cannot resurrect it. Calling complete before requeue consumes the token; recurring consumers **requeue instead of completing**. Do not manually construct State/Ticket values: ordering assumes valid heap sizes/order, and token uniqueness assumes IDs produced by enqueue.

Cancellation visits the heap and running registry. Enqueue/select/requeue use amortized O(log n) heap operations; running-token lookup/removal is O(r) in the number of running tickets. Cancellation is O(n+r), without retained tombstones.

## Recurrence

`plan(previous, completion, period, cadence)` returns `Some{Planned{replay, next}}`, or None for zero period. All times and periods are Nat ticks in one supplied clock domain.

- **FixedDelay:** `next = completion + period`, with no replay.
- **FixedRate{Skip}:** set `q = (completion - previous) / period` (Nat subtraction saturates at zero); `next = previous + (q + 1) * period`, with no replay.
- **FixedRate{CatchUp{bound}}:** same next deadline; replay the earliest `min(bound, q)` missed deadlines `previous + period`, `previous + 2*period`, …, in ascending order. Drop the remaining missed ticks. After a long stall these are the oldest ticks, not the most recent; use Skip when only a current refresh matters. A tick exactly equal to completion is due. The already-executed previous tick is excluded.

For a positive period, next is the first anchored deadline strictly after completion when `previous <= completion`; it is `previous + period` if completion precedes previous. Replay is bounded **per planning call**, not a global rate limit. The consumer reads completion time once for that plan, optionally dispatches replay actions, then requeues the still-running ID at next. Immediately before each replay dispatch, check `Queue.find.list(A, Queue.running(A, state), id)` for a live token, with cancellation and dispatch serialized by the state owner. Never blindly execute a saved replay plan after its token was cancelled. No job overlap, execution, or replay is performed by the pure planner itself.

## Clock and arithmetic trust boundary

The core never reads a clock. `now` and deadlines must share epoch, units, and clock domain. Use a monotonic clock for elapsed-time scheduling: wall clocks may jump. Decreasing supplied time still cannot select a ticket before its supplied deadline, but elapsed-time meaning requires nondecreasing input.

Every `now` and deadline in `live.bend` is monotonic milliseconds from `Time.mono.ms()` in `bend-kit-time@0.3.0.0`; the benchmark times itself with `Time.mono.us()`. Pass the same `Time.mono.ms()` reading to this queue and to other pure cores, such as Hairpin's retry policy, so their times share one unit. OS monotonic-clock correctness and effect code are trusted, not proved. No exact punctuality, fairness, eventual execution, crash durability, or distributed-scheduler claim is made.

The proof model is exact mathematical Nat, with no modular arithmetic. **Bend 2.0.36 native Nat is checked and limited to `2^48 - 1`.** Unrepresentable inputs/intermediate arithmetic terminate with an explicit `bend: a Nat past the largest immediate 2^48-1` error; they do not wrap into an earlier deadline. This is a fatal runtime overflow report, not a recoverable Maybe result. Keep all intermediate values representable. Milliseconds reach that limit after about 8900 years of uptime, microseconds after about 8.9 years. Select a smaller origin/unit for longer-lived clock domains. Resource exhaustion is not covered by arithmetic proofs.

## Proofs and checks

`LAWS.bend` imports quantified queue and recurrence claims; `PROOF.bend` supplies constructive proofs. Queue claims use semantic predicates over every heap element and an ordered-heap predicate, rather than equality of internal heap shapes. Queue operations preserve that ordering predicate. Accurate cached heap sizes and element conservation rely on valid API construction and the pinned heap implementation; they are not additional quantified scheduler invariants. Nat comparison and arithmetic lemmas come from `bend-mathlib@0.8.0.0`. Payload equality is not needed for scheduling order; cancellation is by exact Nat ID.

`scheduler.bend` imports `PROOF.bend`, so the laws and proofs publish with the package. A dependent package can cite a queue lemma in its own proofs: import `bend-kit-scheduler@0.4.2.0/queue_laws.bend` for the predicates and claims, and `bend-kit-scheduler@0.4.2.0/queue_proof.bend` for the lemmas, such as `merge_all.full`, `remove_all`, `remove_absent.heap`, `remove_absent.list`, and `select_selected_absent`. The lemmas hold for the `queue.bend` of the same version only.

```sh
scripts/check.sh scheduler
(cd scheduler && bend PROOF.bend && bend check.bend)
(cd scheduler && bend check.bend -o /tmp/scheduler-check && /tmp/scheduler-check)
(cd scheduler && bend live.bend -o /tmp/scheduler-live && /tmp/scheduler-live)
python3 scheduler/bench/run.py 3
```

`check.bend` covers deterministic deadline/FIFO order, decreasing-time early polls, nontrivial pending cancellation with surviving tickets, simultaneous running-token completion/requeue/cancellation, fresh IDs, both recurrence policies, zero periods, and deadlines beyond U32. `time/check.bend` covers the clock conversion through the native Nat ceiling. `live.bend` uses the real clock and `concurrency@0.2.0.0` worker pool, observes selection order and cancellation, demonstrates that already-running work finishes without resurrection, and requeues and selects a fixed-delay task again. It intentionally asserts no exact timing tolerance. [Benchmark results](bench/README.md).
