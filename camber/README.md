# Camber ownership

`camber.bend` delivers an independent bounded dependency owner, not an HTTP framework entrypoint. Routing, dispatch, and serving remain separate umbrella work. Initial package version: `0.1.0.0`; CI publishes after merge, never by hand.

## API

`start(~K, ~R, ~P, ~I, ~E, ~O, ~create, ~handler, ~destroy, config, capacity, room)` opens exactly `capacity` complete affine bundles before starting its owner. Runtime configuration `K`, principal `P`, input `I`, expected error `E`, and output `O` are typed `Data`; bundle `R` is `Type`. The closed initializer receives runtime configuration and a slot index, and returns `Result<E, R>`. It must close partial handles on failure within one bundle. Camber closes all previously completed bundles on expected initialization failure. Expected startup failure is returned, not passed to `IO.try` internally.

A copied `Context<R,P,I,E,O>` is usable by concurrent requests. `call(..., context, principal, input)` returns `Success`, `Expected`, `Exhausted`, or `Stopped`. The closed handler receives one whole resource bundle and the request's typed principal/input, and returns that bundle beside success or expected failure. There is no per-request resource creation or separate dependency checkout. Opposite operation orders within a bundle cannot produce the two-set acquisition deadlock.

Only disposable `Data` outcomes cross caller reply channels. Perform business operations here and encode an affine HTTP response outside the operation. Resource handles never cross caller replies. `submit(..., context, principal, input, reply)` is the asynchronous variant; callers own a fresh, one-slot reply channel, receive at most one outcome, and close it. Closing that reply early does not strand the bundle or capacity.

`inspect(..., context)` returns counts (`capacity`, `in_use`, `completed`, `rejected`) or `None` after closure. `in_use` includes a handler that stalls or loses its bundle; capacity never silently replenishes. Available capacity is `capacity - in_use`.

`close(..., context)` returns `Busy{counts}` immediately while an operation still owns a bundle. Stop external admissions, wait for admitted operations, then retry close. Idle close explicitly runs the destructor once per returned bundle and ends the owner. Repeated close is harmless; calls afterward return `Stopped`. On a later startup failure (for example transport bind rejection), explicitly close the successfully initialized idle owner. Forced process termination cannot promise close or rollback.

## Bounds and trust

The command inbox has `room` buffered slots (zero uses rendezvous). Resource exhaustion is rejected, never queued waiting for a bundle. Callers blocked submitting to the bounded inbox must be counted inside the caller's admission limit; this dependency owner does not replace transport admission. Reply channels must have one slot so abandoned receivers cannot block the owner. Do not forge protocol messages or close the context's internal owner channel; use the public lifecycle API. Bend has no module privacy enforcement.

The lifecycle receive loop uses `@unsafe` because its termination depends on an external orderly-close command, not structurally shrinking input. The post-close drain is structurally bounded by the inbox's slot count. Base channel/file effects also lie outside mathematical proofs. No human-authored Camber pure laws have been supplied: `LAWS.bend` contains only that disclosure, and `PROOF.bend` imports the empty inventory. There is no mathematical proof coverage beyond type checking and the structurally checked pure helpers; a clean empty proof gate does not attest IO correctness.

`check.bend` is a real native/JS consumer with two File handles per bundle, deterministic held principals, opposite operation orders, expected failure, exhaustion, counts, closed caller reply, partial startup cleanup, actual TCP bind rejection with owner cleanup, and explicit close. Run `python3 camber/run_owner.py` for the package gate and both compiled lanes, with disk/RSS/deadline guards and journal verification/cleanup. No extra serving scaffold exists. The owner-specific observations and proof exclusions are recorded in [OWNER_EVIDENCE.md](OWNER_EVIDENCE.md).
