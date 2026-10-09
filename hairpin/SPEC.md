# Hairpin retry policy

`retry.bend` decides when an attempt may start, how long to wait before the next one, and what the circuit breaker does. It is pure. `hairpin.bend` reads the clock, makes the attempts, and calls it.

## Proven claims

`LAWS.bend` states and `PROOF.bend` proves these claims for every input:

- `budget_step_exact`: one admission takes exactly one attempt from the budget when it starts an attempt, and none when it denies.
- `budget_trace_exact`, `budget_bound`: over any trace of admissions and completions, with any breaker and any clock, the attempts started plus the budget left equal the budget given. So the attempts never exceed the budget.
- `budget_nested`: an inner layer, then an outer layer on the budget that the inner layer returned, start at most the one budget's attempts together. Composition cannot reset or multiply the budget.
- `deadline_denies`: no attempt is admitted at or after the deadline. `deadline_before_admits` shows that one is admitted just before it.
- `delay_le_cap`, `jitter_floor`, `jitter_ceiling`: each backoff step is at most the cap, and equal jitter keeps the wait in `[d/2, d]`.
- `wait_le_cap`, `wait_fits_u32`: every wait, a server's `Retry-After` included, is at most the `U32` cap, so the conversion to the `U32` sleep is exact. Nothing overflows.
- `plan_settled_stops`, `plan_unsafe_stops`: a non-retryable outcome never schedules another attempt. `plan_spent_stops` and `plan_late_stops`: neither does a spent budget, nor a wait that would reach the deadline.
- `probe_limit`, `done_frees_probes`: a half-open circuit never has more than `probes` attempts in flight.
- `closed_admits`, `open_denies_before_cooldown`, `open_probes_after_cooldown`, `half_success_closes`, `half_failure_opens`, `open_ignores_done`, `closed_success_clears`, `closed_failure_under_threshold`: each transition of the circuit breaker.

Fixtures cover the failure window (`window_trips`, `window_expires`, `window_success_resets`), a full half-open circuit (`half_full_denies`), and Hairpin's outcome classification (`outcome_*`).

## Conventions

- Times are milliseconds on one monotonic clock, as `Nat`. "At or after the deadline" means `deadline <= now`.
- A budget counts attempts, the first one included. `Hairpin.retry(c, n)` gives `n + 1` attempts.
- `==` in a law is Bend's equality type: both sides reduce to the same term.

## Trust assumptions

- The proofs cover `retry.bend`, not the IO loop in `hairpin.bend`. Hairpin calls `Retry.admit` before each attempt and `Retry.plan` after it. `check.bend` tests this against a server that counts attempts.
- An attempt is admitted when it starts. A deadline does not cancel an attempt in flight. Its connect, write, and read steps each time out after `Hairpin.timeout`.
- The monotonic clock (`Time.mono.raw`), the random jitter (`IO.random_u32`), the sleep, and the sockets are host code. Bend cannot prove host code.
- `Retry.Budget` is a plain value. A layer that builds a new budget instead of passing on the one it got resets the count. The proofs hold for layers that pass the budget on.
- A retry is safe only when the server can handle the same request twice. `request` and `request.in` retry only the methods that RFC 9110 calls idempotent. With `request.as`, the caller's `idem` and `judge` decide, and Hairpin trusts them. The proofs do not make an unsafe operation safe to repeat.
