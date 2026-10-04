# Camber

`camber.bend` delivers fixed prepared application registration/direct dispatch, explicit output helpers, final response validation, and an independent bounded dependency owner. Hooks, body decoders, error mapping, and serving are not implemented by this entrypoint. Package version: `0.2.0.0`; CI publishes after merge, never by hand.

## API

### Fixed applications and direct dispatch

`application(~A, ~C, ~P, routes, groups, context, root)` returns `Result<RegistrationError, Application<A,C,P>>` without effects or listening. All three types are `Data`: action tags `A`, typed runtime context `C` (which may include the owner's `Context`), and policy declarations `P`. Routes are `Route{method, pattern, action, groups, policy}`. Groups are `Group{id, ancestors, policy}`; ancestors and route membership list IDs from root to leaf. Construction rejects unknown/duplicate groups, inconsistent ancestry, invalid patterns/methods, duplicate method/path shapes, and shared-path ancestry conflicts. Group declaration order does not matter. Policies prepare once as root, ancestor groups, then route; these are declarations, not executed hooks.

`describe(~A, ~C, ~P, app)` returns the published Router descriptions, including registered method/pattern/group membership and parameter-route methods hidden by a more specific literal path. No listener is needed.

`dispatch(~A, ~C, ~P, ~run, app, req)` uses published `bend-kit-router@0.2.0.0` and `bend-kit-http@0.25.0.2` types. The closed executor has type `A -> C -> Match<P> -> Http.Req -> IO(Http.Res)`. `Match{target, params, groups, method, pattern, policies}` carries the strictly parsed target/query, once-decoded captures with method-specific names, selected handler method/pattern, and prepared effective policy declarations. The request preserves its original method/target and original affine packed body; absolute-form authority replaces the application's Host header. For implied HEAD, `Match.method` is GET while `Req.method` remains HEAD.

`plain(~handler, req)` adapts an ordinary `Http.Req -> IO(Http.Res)` handler and returns `IO(Result<&2, &1, ResponseError, Http.Res>)`. `dispatch` now returns the same typed result after validating both business and generated responses. An executor can call its ordinary handler directly; dispatch performs the final validation once. There is no replay, affine callback registry, per-request pattern preparation, or implicit body/text conversion. Copy application/context metadata, never affine resources.

Direct misses return empty 400/404, sorted/deduplicated Allow on 405, and generated 204 OPTIONS (including OPTIONS *). Explicit HEAD/OPTIONS override generated behavior. This stage does not invoke future hooks/error mappers. It returns the handler's body even for HEAD/204/304: only Http transport may suppress it. Hook/decoder work and the serving adapter must extend/reuse this dispatch path rather than add a matcher or parser. Generated choices currently produce responses inside dispatch; implementing their group lifecycle belongs to the later hook stage.

`dispatch_check.bend` is the compiled acceptance consumer (also called by `check.bend`): registration rejection, reversed insertion order, path-first precedence, per-method captures, exact slashes, absolute authority Host, strict target/segment decoding, 404/405/Allow, explicit/implied HEAD/OPTIONS, OPTIONS *, hidden descriptions, prepared ancestry/policies, typed context, and a NUL/FF/80/slash packed-byte plain-handler fixture.

### Explicit outputs and expected failures

`json(~T, ~encode, status, value)` accepts an explicit `T -> Json.Val` public encoder and produces `application/json` using published Json `0.5.1.0`. It never reflects or serializes domain fields itself. `text(status, value)` encodes code-point text with the existing UTF-8 encoder and sets `text/plain; charset=utf-8`. `raw(status, Http.Body)` moves packed bytes without a guessed content type; `empty(status)` has no body or content type. These helpers return `Http.Res`; the final dispatch/plain boundary validates status and headers.

`redirect(status, location)` returns `Result<&2, &1, ResponseError, Http.Res>`. Only 301/302/303/307/308 with a nonempty safe Location succeed; other inputs return `InvalidRedirect`. Location is an HTTP field octet String, not an implicitly encoded Unicode URL.

`validate(response)` returns `Done` with the original packed body and repeated header values, or expected `Fail{InvalidResponse{}}`. It accepts status 200..599, lowercase RFC token names, and octet field values without controls except HTAB. Header values must be 0..255: shared Http concatenates header Strings and packs each Char's low eight bits, so accepting a larger code point could truncate into CR/LF. Encode non-ASCII header/URL bytes explicitly. Obs-text 128..255 is preserved.

Content-Length, Transfer-Encoding, Keep-Alive, Upgrade, TE, Trailer, and Proxy-Connection are prohibited. Every Connection value must be exactly `close`. Validation neither strips nor coerces invalid output. Callers must handle the expected failure before transport; the later error lifecycle can map this single `ResponseError` seam. No general mapper or serving adapter is supplied here.

This is a breaking return-type change from 0.1.1.0. All public consumers now inspect the typed result; ordinary handler inputs and `IO(Http.Res)` outputs remain unchanged.


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

## Output validation verification

The package gate `bash scripts/check.sh camber` passed with the public response checks included in `check.bend`. `bash scripts/publish.sh --check camber` passed and printed `bend-kit-camber@0.2.0.0 will publish`. Compiled `dispatch_check.bend` and `response_check.bend` passed natively and under Bun after `bend ... -o <binary>` / `bend ... -o <file.js>`. Fixtures observed the public JSON projection excluding secret/internal fields, UTF-8 café bytes, binary NUL/FF preservation, empty and allowed redirect semantics, unsafe Location rejection, status/header/framing/Connection rejection, repeated cookies, and unsuppressed direct HEAD/204/304 bodies. The original packed route-dispatch check and a separate plain-adapter check both observed word `796983040`.

Compiled `response_live.bend` passed in native and JS lanes. Real loopback clients received zero bytes for each of 21 invalid outputs, while both plain and routed handlers returned expected `InvalidResponse`. The final valid response reached shared `Http.talk.send` and sent distinct `set-cookie: a=1` and `set-cookie: b=2` lines plus `ok`. This finite acceptance caller is not a Camber server, parser, or mapper.

`python3 camber/run_response.py` exited 0 end-to-end for the exact final consumers, including routed 204/304 body retention, sequential package/publication gates, and both compiled lanes. It enforces the existing 10 GiB disk-headroom and 20 GiB RSS guards. During implementation, live-consumer compilation exposed affine header reuse, computed-result destructuring, and incorrect Base close/result-unwrapping calls; those were corrected before the successful run. Final peak sampled RSS was 2,351,824 KiB for the package gate; live native/JS compilation used 2,258,080 / 1,904,528 KiB. Temporary binaries, owner journals, listeners, and sockets were closed/removed.

The entry gate still explicitly reports 278 definitions relying on existing unsafe/foreign code. No new unsafe or foreign definition was added. The empty human-owned law inventory remains unchanged and is not proof of host IO, transport behavior, or response correctness. No HTTP serving, hook/error-mapper lifecycle, or strict request-text decoding claim is made.
