# retry

A pure retry policy for Bend 2: a shared attempt budget, an operation deadline, bounded backoff with equal jitter, and a circuit breaker. It imports only `Base`, so a caller that does not use HTTP can use it.

```bend
import bend-kit-retry@0.3.0.0/retry.bend as Retry
```

`bend-kit-hairpin` uses this package for its retries. Import the same `retry` version that your `hairpin` version imports, because another version has a different `Retry.Budget`.

The defs are pure. The caller reads the clock, makes the attempts, sleeps, and calls the policy. All times are milliseconds on one monotonic clock, as `Nat`.

## The loop

1. **Admit.** `Retry.admit(breaker, budget, now)` checks the deadline, then the budget, then the breaker. It returns the new breaker, the new budget, and a `Gate`. Only `GateGo` starts an attempt, and it takes one attempt from the budget. `GateNo{why}` gives `DenyLate`, `DenySpent`, or `DenyOpen`.
2. **Classify.** The caller turns the result of the attempt into an `Outcome`: `Settled` (a success), `Failed` (a failure that another try would repeat), `Rejected` (the caller is at fault, such as a 4xx, so another try would repeat it), `Unsafe` (a transient failure of an operation that must not repeat), or `Transient{after}` (another try can help; `after` is the server's wait in ms).
3. **Tell the breaker.** `Retry.Breaker.done(breaker, now, Retry.failed(outcome))`. `Failed`, `Unsafe`, and `Transient` count as failures. `Settled` and `Rejected` do not, so a run of client errors does not open the circuit.
4. **Plan.** `Retry.plan(outcome, policy, budget, n, now, r)` gives `PlanStop` or `PlanWait{ms}`. `n` is the retry number (0 first) and `r` is a random number for the jitter. `Settled`, `Failed`, `Rejected`, and `Unsafe` stop. `Transient` waits `after`, or `min(cap, base * 2^n)` with equal jitter, at most `cap` either way. It stops when the budget is spent or when the wait would reach the deadline.

| Value | Meaning |
|---|---|
| `Retry.Budget.new(attempts, now, ms)` | `attempts` tries in all, the first one included. `Some{ms}` sets the deadline `now + ms`; `None{}` sets none. |
| `Retry.Policy{attempts, base, cap, deadline}` | The tries of one layer, the first backoff in ms, the longest wait in ms (`U32`, so a wait fits a sleep), and the deadline in ms from the start. |
| `Retry.Circuit{threshold, window, cooldown, probes}` | The breaker settings. See [Circuit breaker](#circuit-breaker). |
| `Retry.Breaker.new(circuit)` | A closed breaker. `Retry.BreakerOff{}` admits every attempt. |

| def | result |
|---|---|
| `Retry.delay(n: Nat, base: Nat, cap: Nat)` | `Nat`; the backoff before jitter, bounded by `cap`. |

## Nested retries

A layer with its own retry loop above another one multiplies attempts: 3 outer tries of 3 inner attempts are 9. Make one `Retry.Budget` for the whole operation, pass it to each layer, and pass the budget that comes back to the next call. Every attempt then takes from the one budget and obeys its deadline. `Retry.Budget` is a plain value, so a layer can build a fresh one. Do not: a layer that builds its own budget resets the count.

## Circuit breaker

- **Closed** admits every attempt. `threshold` failures in a row, each inside `window` ms of the newest, open it. A success clears the count.
- **Open** admits nothing for `cooldown` ms. An attempt that was already running and ends now changes nothing.
- **Half-open** begins at the first admission after the cooldown. It admits at most `probes` attempts at once. A probe success closes the circuit; a probe failure opens it for another `cooldown`.

## Proven claims

`LAWS.bend` states and `PROOF.bend` proves these claims for every input:

- `budget_step_exact`: one admission takes exactly one attempt from the budget when it starts an attempt, and none when it denies.
- `budget_trace_exact`, `budget_bound`: over any trace of admissions and completions, with any breaker and any clock, the attempts started plus the budget left equal the budget given. So the attempts never exceed the budget.
- `budget_nested`: an inner layer, then an outer layer on the budget that the inner layer returned, start at most the one budget's attempts together. Composition cannot reset or multiply the budget.
- `deadline_denies`: no attempt is admitted at or after the deadline. `deadline_before_admits` shows that one is admitted just before it.
- `delay_le_cap`, `jitter_floor`, `jitter_ceiling`: each backoff step is at most the cap, and equal jitter keeps the wait in `[d/2, d]`.
- `wait_le_cap`, `wait_fits_u32`: every wait, a server's wait included, is at most the `U32` cap, so the conversion to a `U32` sleep is exact. Nothing overflows.
- `plan_settled_stops`, `plan_failed_stops`, `plan_rejected_stops`, `plan_unsafe_stops`: a non-retryable outcome never schedules another attempt. `plan_spent_stops` and `plan_late_stops`: neither does a spent budget, nor a wait that would reach the deadline.
- `failed_counts`: a failure that another try would repeat counts against the breaker. `rejected_not_counted`: a caller's fault does not.
- `probe_limit`, `done_frees_probes`: a half-open circuit never has more than `probes` attempts in flight.
- `closed_admits`, `open_denies_before_cooldown`, `open_probes_after_cooldown`, `half_success_closes`, `half_failure_opens`, `open_ignores_done`, `closed_success_clears`, `closed_failure_under_threshold`: each transition of the circuit breaker.

Fixtures cover the failure window (`window_trips`, `window_expires`, `window_success_resets`) and a full half-open circuit (`half_full_denies`). `==` in a law is Bend's equality type: both sides reduce to the same term.

## Trust assumptions

- The proofs cover `retry.bend`, not the caller's IO loop. The caller must call `admit` before each attempt, start an attempt only on `GateGo`, and call `plan` after it.
- An attempt is admitted when it starts. A deadline does not cancel an attempt in flight.
- The clock, the random jitter, and the sleep belong to the caller. The policy is only as right as the times it gets.
- A retry is safe only when the operation can run twice. The caller decides between `Transient` and `Unsafe`; the proofs do not make an unsafe operation safe to repeat.

## Checks

```sh
scripts/check.sh retry
```

`check.bend` runs the backoff, the jitter, a server wait, a wait that reaches the deadline, and a breaker that opens and then admits a probe after its cooldown. [Benchmark](bench/README.md).
