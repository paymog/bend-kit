# Camber

`camber.bend` delivers fixed prepared application registration/direct dispatch and an independent bounded dependency owner. Hooks, body decoders, error mapping, response validation, and serving are not implemented by this entrypoint. Package version: `0.1.1.0`; CI publishes after merge, never by hand.

## API

### Fixed applications and direct dispatch

`application(~A, ~C, ~P, routes, groups, context, root)` returns `Result<RegistrationError, Application<A,C,P>>` without effects or listening. All three types are `Data`: action tags `A`, typed runtime context `C` (which may include the owner's `Context`), and policy declarations `P`. Routes are `Route{method, pattern, action, groups, policy}`. Groups are `Group{id, ancestors, policy}`; ancestors and route membership list IDs from root to leaf. Construction rejects unknown/duplicate groups, inconsistent ancestry, invalid patterns/methods, duplicate method/path shapes, and shared-path ancestry conflicts. Group declaration order does not matter. Policies prepare once as root, ancestor groups, then route; these are declarations, not executed hooks.

`describe(~A, ~C, ~P, app)` returns the published Router descriptions, including registered method/pattern/group membership and parameter-route methods hidden by a more specific literal path. No listener is needed.

`dispatch(~A, ~C, ~P, ~run, app, req)` uses published `bend-kit-router@0.2.0.0` and `bend-kit-http@0.25.0.2` types. The closed executor has type `A -> C -> Match<P> -> Http.Req -> IO(Http.Res)`. `Match{target, params, groups, method, pattern, policies}` carries the strictly parsed target/query, once-decoded captures with method-specific names, selected handler method/pattern, and prepared effective policy declarations. The request preserves its original method/target and original affine packed body; absolute-form authority replaces the application's Host header. For implied HEAD, `Match.method` is GET while `Req.method` remains HEAD.

Use `plain(~handler, req)` inside an action branch to adapt an ordinary `Http.Req -> IO(Http.Res)` handler. There is no replay, affine callback registry, per-request pattern preparation, or implicit body/text conversion. Copy application/context metadata, never affine resources. Affine dependencies remain inside the bounded owner; explicit executors call its typed operations.

Direct misses return empty 400/404, sorted/deduplicated Allow on 405, and generated 204 OPTIONS (including OPTIONS *). Explicit HEAD/OPTIONS override generated behavior. This stage does not invoke future hooks/error mappers or validate responses. It returns the handler's body even for HEAD/204/304: only Http transport may suppress it. Later hook/decoder work (#333/#334) and the serving adapter (#336) must extend/reuse this dispatch path rather than add a matcher or parser. Generated choices currently produce responses inside dispatch; implementing their group lifecycle belongs to the later hook stage, not to a second dispatch seam.

`dispatch_check.bend` is the compiled acceptance consumer (also called by `check.bend`): registration rejection, reversed insertion order, path-first precedence, per-method captures, exact slashes, absolute authority Host, strict target/segment decoding, 404/405/Allow, explicit/implied HEAD/OPTIONS, OPTIONS *, hidden descriptions, prepared ancestry/policies, typed context, and a NUL/FF/80/slash packed-byte plain-handler fixture.

### Bounded dependency owner

`start(~K, ~R, ~P, ~I, ~E, ~O, ~create, ~handler, ~destroy, config, capacity, room)` opens exactly `capacity` complete affine bundles before starting its owner. Runtime configuration `K`, principal `P`, input `I`, expected error `E`, and output `O` are typed `Data`; bundle `R` is `Type`. The closed initializer receives runtime configuration and a slot index, and returns `Result<E, R>`. It must close partial handles on failure within one bundle. Camber closes all previously completed bundles on expected initialization failure. Expected startup failure is returned, not passed to `IO.try` internally.

A copied `Context<R,P,I,E,O>` is usable by concurrent requests. `call(..., context, principal, input)` returns `Success`, `Expected`, `Exhausted`, or `Stopped`. The closed handler receives one whole resource bundle and the request's typed principal/input, and returns that bundle beside success or expected failure. There is no per-request resource creation or separate dependency checkout. Opposite operation orders within a bundle cannot produce the two-set acquisition deadlock.

Only disposable `Data` outcomes cross caller reply channels. Perform business operations here and encode an affine HTTP response outside the operation. Resource handles never cross caller replies. `submit(..., context, principal, input, reply)` is the asynchronous variant; callers own a fresh, one-slot reply channel, receive at most one outcome, and close it. Closing that reply early does not strand the bundle or capacity.

`inspect(..., context)` returns counts (`capacity`, `in_use`, `completed`, `rejected`) or `None` after closure. `in_use` includes a handler that stalls or loses its bundle; capacity never silently replenishes. Available capacity is `capacity - in_use`.

`close(..., context)` returns `Busy{counts}` immediately while an operation still owns a bundle. Stop external admissions, wait for admitted operations, then retry close. Idle close explicitly runs the destructor once per returned bundle and ends the owner. Repeated close is harmless; calls afterward return `Stopped`. On a later startup failure (for example transport bind rejection), explicitly close the successfully initialized idle owner. Forced process termination cannot promise close or rollback.

## Bounds and trust

The command inbox has `room` buffered slots (zero uses rendezvous). Resource exhaustion is rejected, never queued waiting for a bundle. Callers blocked submitting to the bounded inbox must be counted inside the caller's admission limit; this dependency owner does not replace transport admission. Reply channels must have one slot so abandoned receivers cannot block the owner. Do not forge protocol messages or close the context's internal owner channel; use the public lifecycle API. Bend has no module privacy enforcement.

The lifecycle receive loop uses `@unsafe` because its termination depends on an external orderly-close command, not structurally shrinking input. The post-close drain is structurally bounded by the inbox's slot count. Base channel/file effects also lie outside mathematical proofs. No human-authored Camber pure laws have been supplied: `LAWS.bend` contains only that disclosure, and `PROOF.bend` imports the empty inventory. There is no mathematical proof coverage beyond type checking and the structurally checked pure helpers; a clean empty proof gate does not attest IO correctness.

`check.bend` is a real native/JS consumer with two File handles per bundle, deterministic held principals, opposite operation orders, expected failure, exhaustion, counts, closed caller reply, partial startup cleanup, actual TCP bind rejection with owner cleanup, and explicit close. Run `python3 camber/run_owner.py` for the package gate and both compiled lanes, with disk/RSS/deadline guards and journal verification/cleanup. No extra serving scaffold exists. The owner-specific observations and proof exclusions are recorded in [OWNER_EVIDENCE.md](OWNER_EVIDENCE.md).

## Registration/direct-dispatch verification

`python3 camber/run_owner.py` exited 0 for the package gate and actual compiled native and JS consumers. Both lanes printed `camber registration/direct dispatch: PASS` and retained the owner journal/explicit-close checks. The dispatch assertions verified the scenarios listed above, including reading POST's `id` and GET's `name` independently, `%252F` captured as `%2F`, HEAD returning the unsuppressed handler body, and exact packed word `796983040` (`00 ff 80 2f`) through the plain adapter. Peak sampled RSS was 2,220,432 KiB for the package gate, 1,974,880 KiB for native compilation, and 1,681,856 KiB for JS compilation; the runner enforced at least 10 GiB free disk and a 20 GiB per-process RSS ceiling. Temporary binaries and owner journals were removed by the runner.

The first consumer checks exposed Bend's prohibition on destructuring computed IO/array results and an incorrect `Http.text` argument/quantity annotation; the fixture now uses parameter-bound helpers, packed-byte conversion only in assertions, and explicit reusable status metadata. Review also replaced eager group lookup with the existing lazy-helper pattern.

`bash scripts/publish.sh --check camber` exited 0 with `bend-kit-camber@0.1.1.0 will publish`. Hub Http/Router/Target imports resolved during compilation. No manual publication was performed.

The entry check explicitly reported 278 definitions relying on unsafe/foreign code, including imported Http/Wire effects and the existing owner lifecycle. The empty Camber proof inventory printed `ALL PROOFS CHECK`; it is not mathematical evidence of IO or routing behavior. No new unsafe or foreign definitions were added. These are direct-dispatch observations, not socket framing, HEAD/204/304 transport suppression, hook lifecycle, response validation, or serving evidence.
