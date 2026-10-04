# Camber

`camber.bend` delivers fixed prepared registration, immutable scoped before/transform policies, once-only error mapping, application completion, explicit input/output choices, final response validation, and an independent bounded dependency owner. HTTP serving remains separate work. Package version: `0.4.0.0`; CI publishes after merge, never by hand.

## API

### Fixed applications and direct dispatch

`application(~A, ~K, ~P, routes, groups, context, root)` returns `Result<RegistrationError, Application<A,K,P>>` without effects or listening. Action tags `A`, application context `K` (which may include the owner's `Context`), and policy declarations `P` are `Data`. Routes are `Route{method, pattern, action, groups, policy}`; groups are `Group{id, ancestors, policy}`, with root-to-leaf IDs. Construction rejects unknown/duplicate groups, inconsistent ancestry, invalid patterns/methods, duplicate method/path shapes, and shared-path ancestry conflicts. Group declaration order does not matter. Executable dispatch uses `P = Policy<H>`: `policy(~H,id,before,transforms)` fixes declaration order and prepares reversed transforms once.

The application retains prepared `GroupPlan` chains for method misses and generated OPTIONS; dispatch never resolves group ancestry again.

`describe(~A, ~C, ~P, app)` returns the published Router descriptions, including registered method/pattern/group membership and parameter-route methods hidden by a more specific literal path. No listener is needed.

`dispatch(~A, ~S, ~K, ~E, ~H, ~before, ~after, ~run, ~mapper, app, state, req)` returns `IO(Completion<S,H>)` through one prepared Router selection pipeline. All five types are `Data`; `S` is copied request-local state, not an affine resource bundle. The executor has type `A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2,&1,Error<E>,Http.Res>)`. It performs its explicit decoding and business work only after selected before hooks. An ordinary `Http.Req -> IO(Http.Res)` handler fits by returning its response as `Done`, without calling `plain` first or converting its packed body.

Before hooks receive `H -> S -> K -> Metadata -> IO(Step<S,E>)`, where `Metadata{method,target,headers}` contains no body. `Continue{state}`, `Early{state,response}`, and `Reject{state,error}` preserve the request-local state; early exits skip subsequent scopes, decoding, and the executor. Root hooks precede target parsing. Path groups run for 405/generated OPTIONS, but route hooks do not. Empty scopes are entered too. Transforms receive `H -> S -> K -> Http.Res -> IO(S & Result<Error<E>,Http.Res>)` and unwind only entered scopes, inner-to-outer in reversed declaration order.

`Match{target,params,groups,method,pattern,policies}` preserves strictly parsed query/captures and effective declarations. Absolute-form authority replaces Host only after global hooks; implied HEAD keeps the original request method while selecting GET. Direct dispatch retains the original affine packed body and never suppresses HEAD/204/304 response bodies.

`Error<E>` distinguishes `ApplicationError{error}`, `Framework{status,allow}`, and `ResponseInvalid`. The application's closed mapper receives `S -> K -> Error<E> -> IO(S & Result<Error<E>,Http.Res>)` at most once. `default.mapper(~S,~K,~E)` produces RFC 9457 Problem Details for framework 400/404/405/415 and an empty generic500 otherwise. Deliberate early responses bypass mapping. Transform failure stops all remaining transforms; final validation failure maps without restarting transforms. Mapper failure/invalid output and failures after mapping return the fixed empty500. Runtime crashes/stalls are not expected failures and are not contained.

`Completed{state,response,entered,mapped,stopped}` records actual application completion. `entered` retains the actual immutable `Policy<H>` values inner-to-outer, including empty scopes, using O(1) stack pushes; IDs are labels, not unique identities. Later notifications can consume that stack without reconstructing scopes. `mapped` records one mapper invocation; `stopped` records halted recovery/unwinding. This value does not claim a transport write, duration, or peer receipt. Framing failures never call dispatch.

`plain(~handler,req)` remains a standalone validation adapter returning `IO(Result<&2,&1,ResponseError,Http.Res>)`; it is not a router or a hook pipeline. All routed consumers use `dispatch`, with explicit empty policies and the default mapper when no hooks are needed.

`dispatch_check.bend` is the compiled acceptance consumer (also called by `check.bend`): registration rejection, reversed insertion order, path-first precedence, per-method captures, exact slashes, absolute authority Host, strict target/segment decoding, 404/405/Allow, explicit/implied HEAD/OPTIONS, OPTIONS *, hidden descriptions, prepared ancestry/policies, typed context, and a NUL/FF/80/slash packed-byte plain-handler fixture.

### Checked typed inputs

Import the package's `input.bend` module as `Input`. `path(~I, ~convert, params, key)` reads the router's already-decoded capture without percent-decoding again. `query.scalar(~I, ~convert, query, key)` requires exactly one value; repeats (including escaped spellings of the same key) and missing values fail400. `query.list` converts every matching value in encounter order, returning an empty list when absent. Both use the published Target query result, never a competing target/query parser. `u32` requires nonempty ASCII decimal text and checks overflow before arithmetic.

`Input.raw(body)` moves the same affine packed bytes unchanged. `Input.text(headers, body)` accepts `text/*`, absent or UTF-8 charset, and identity content encoding; unsupported media/charset/encoding fails415, malformed UTF-8 fails400. Its packed byte walk reuses published Target's strict RFC3629 state machine, not `Http.text` replacement or a linked-list octet copy.

`Input.json(headers, body)` uses default depth64; `json.with_depth(headers, body, cap)` sets the maximum array/object nesting (scalars have depth0). Media is case-insensitive `application/json` or `application/<subtype>+json`; ignored parameters may contain quoted semicolons, and charset must be UTF-8. Published Json0.5.1.0 performs strict bounded parsing before an unrestricted tree can exist. Camber then rejects repeated decoded keys in every object, including objects nested in arrays, preserving the affine tree, object/array order and exact packed number text. Neither decoder decompresses or caches the body. `number.u32` is an explicit checked conversion of a JSON number; decimal fractions, exponents, signs and overflow are rejected rather than coerced.

Input helpers return `Result<&2,&1,U32,I>`, with expected status400/415. `C.input(~I,~E,result)` adapts them to the existing `Error<E>` mapper. Call `execute(~I,~S,~K,~E,~H,~decoder,~handler,state,config,match,req)` from dispatch's `run` template: its decoder returns a validated typed `I` or expected error; only success invokes the business handler. This is an executor inside the single public dispatcher, not another pipeline. All applicable before hooks therefore precede body and typed path/query decoding.

`input_app.bend` is a reusable public-dispatch consumer with typed lookup, raw, text, document, checked-number and validated creation inputs. `input_check.bend` and `run_inputs.py` exercise that same consumer directly and through finite published Http socket IO. Real file journals distinguish authentication, decoding, business effects and mapping. Historical ownership/surface/author research stays unchanged; it is not the new public API or its acceptance evidence.

### Explicit outputs and expected failures

`json(~T, ~encode, status, value)` accepts an explicit `T -> Json.Val` public encoder and produces `application/json` using published Json `0.5.1.0`. It never reflects or serializes domain fields itself. `text(status, value)` encodes code-point text with the existing UTF-8 encoder and sets `text/plain; charset=utf-8`. `raw(status, Http.Body)` moves packed bytes without a guessed content type; `empty(status)` has no body or content type. These helpers return `Http.Res`; the final dispatch/plain boundary validates status and headers.

`redirect(status, location)` returns `Result<&2, &1, ResponseError, Http.Res>`. Only 301/302/303/307/308 with a nonempty safe Location succeed; other inputs return `InvalidRedirect`. Location is an HTTP field octet String, not an implicitly encoded Unicode URL.

`validate(response)` returns `Done` with the original packed body and repeated header values, or expected `Fail{InvalidResponse{}}`. It accepts status 200..599, lowercase RFC token names, and octet field values without controls except HTAB. Header values must be 0..255: shared Http concatenates header Strings and packs each Char's low eight bits, so accepting a larger code point could truncate into CR/LF. Encode non-ASCII header/URL bytes explicitly. Obs-text 128..255 is preserved.

Content-Length, Transfer-Encoding, Keep-Alive, Upgrade, TE, Trailer, and Proxy-Connection are prohibited. Every Connection value must be exactly `close`. Validation neither strips nor coerces invalid output. Standalone `validate`/`plain` return expected failures before transport. Scoped `dispatch` maps them once after transforms and returns the final safe response. No serving adapter is supplied here.

This is a breaking dispatch/application-policy change from 0.2.0.0. All public dispatch consumers now inspect application completion; ordinary handler inputs and `IO(Http.Res)` outputs remain unchanged.


### Bounded dependency owner

`start(~K, ~R, ~P, ~I, ~E, ~O, ~create, ~handler, ~destroy, config, capacity, room)` opens exactly `capacity` complete affine bundles before starting its owner. Runtime configuration `K`, principal `P`, input `I`, expected error `E`, and output `O` are typed `Data`; bundle `R` is `Type`. The closed initializer receives runtime configuration and a slot index, and returns `Result<E, R>`. It must close partial handles on failure within one bundle. Camber closes all previously completed bundles on expected initialization failure. Expected startup failure is returned, not passed to `IO.try` internally.

A copied `Context<R,P,I,E,O>` is usable by concurrent requests. `call(..., context, principal, input)` returns `Success`, `Expected`, `Exhausted`, or `Stopped`. The closed handler receives one whole resource bundle and the request's typed principal/input, and returns that bundle beside success or expected failure. There is no per-request resource creation or separate dependency checkout. Opposite operation orders within a bundle cannot produce the two-set acquisition deadlock.

Only disposable `Data` outcomes cross caller reply channels. Perform business operations here and encode an affine HTTP response outside the operation. Resource handles never cross caller replies. `submit(..., context, principal, input, reply)` is the asynchronous variant; callers own a fresh, one-slot reply channel, receive at most one outcome, and close it. Closing that reply early does not strand the bundle or capacity.

`inspect(..., context)` returns counts (`capacity`, `in_use`, `completed`, `rejected`) or `None` after closure. `in_use` includes a handler that stalls or loses its bundle; capacity never silently replenishes. Available capacity is `capacity - in_use`.

`close(..., context)` returns `Busy{counts}` immediately while an operation still owns a bundle. Stop external admissions, wait for admitted operations, then retry close. Idle close explicitly runs the destructor once per returned bundle and ends the owner. Repeated close is harmless; calls afterward return `Stopped`. On a later startup failure (for example transport bind rejection), explicitly close the successfully initialized idle owner. Forced process termination cannot promise close or rollback.

### Cooperative transport shutdown (HTTP 0.30.0.0)

The shared HTTP owner now provides `server.control`, copied `server.stop`,
and actual `ServerExit`/drained-count results. A stop acknowledgment is only an
admission transition: retain and run/close the affine server, join its actual
completion, then explicitly close the separate idle Camber dependency owner.
Busy dependencies or stalled callbacks remain counted; a timer does not return
their instances. Stream abort and skipped-writer disposal callbacks consume
actual application state and must explicitly return/close its external handles.

[`../http/drain_results.json`](../http/drain_results.json) records 64 native/JS
socket cases, including the scoped `lifecycle_http.serve` adapter over the same
HTTP owner, natural cooperative exit, delayed/stuck work, and actual File
descriptor closure. This is not a new Camber serving implementation or #339's
supervisor deployment. Forced SIGKILL/reaping observations are distinct from
explicit application cleanup; historical pre-control supervision evidence stays
separate in [`supervision_risk_results.json`](supervision_risk_results.json).
Published Wire 0.4.5.0 is `0x1435aec27074c8141b74747909079afc`; local HTTP
0.30.0.0 awaits merge and automatic publication. No manual publish is required.


## Bounds and trust

The command inbox has `room` buffered slots (zero uses rendezvous). Resource exhaustion is rejected, never queued waiting for a bundle. Callers blocked submitting to the bounded inbox must be counted inside the caller's admission limit; this dependency owner does not replace transport admission. Reply channels must have one slot so abandoned receivers cannot block the owner. Do not forge protocol messages or close the context's internal owner channel; use the public lifecycle API. Bend has no module privacy enforcement.

The lifecycle receive loop uses `@unsafe` because its termination depends on an external orderly-close command, not structurally shrinking input. The post-close drain is structurally bounded by the inbox's slot count. Base channel/file effects also lie outside mathematical proofs. No human-authored Camber pure laws have been supplied: `LAWS.bend` contains only that disclosure, and `PROOF.bend` imports the empty inventory. There is no mathematical proof coverage beyond type checking and the structurally checked pure helpers; a clean empty proof gate does not attest IO correctness.

`check.bend` is a real native/JS consumer with two File handles per bundle, deterministic held principals, opposite operation orders, expected failure, exhaustion, counts, closed caller reply, partial startup cleanup, actual TCP bind rejection with owner cleanup, and explicit close. Run `python3 camber/run_owner.py` for the package gate and both compiled lanes, with disk/RSS/deadline guards and journal verification/cleanup. No extra serving scaffold exists. The owner-specific observations and proof exclusions are recorded in [OWNER_EVIDENCE.md](OWNER_EVIDENCE.md).

## Registration/direct-dispatch verification

`python3 camber/run_owner.py` exited 0 for the package gate and actual compiled native and JS consumers. Both lanes printed `camber registration/direct dispatch: PASS` and retained the owner journal/explicit-close checks. The dispatch assertions verified the scenarios listed above, including reading POST's `id` and GET's `name` independently, `%252F` captured as `%2F`, HEAD returning the unsuppressed handler body, and exact packed word `796983040` (`00 ff 80 2f`) through the plain adapter. Peak sampled RSS was 2,220,432 KiB for the package gate, 1,974,880 KiB for native compilation, and 1,681,856 KiB for JS compilation; the runner enforced at least 10 GiB free disk and a 20 GiB per-process RSS ceiling. Temporary binaries and owner journals were removed by the runner.

The first consumer checks exposed Bend's prohibition on destructuring computed IO/array results and an incorrect `Http.text` argument/quantity annotation; the fixture now uses parameter-bound helpers, packed-byte conversion only in assertions, and explicit reusable status metadata. Review also replaced eager group lookup with the existing lazy-helper pattern.

`bash scripts/publish.sh --check camber` exited 0 with `bend-kit-camber@0.1.1.0 will publish`. Hub Http/Router/Target imports resolved during compilation. No manual publication was performed.

The entry check explicitly reported 278 definitions relying on unsafe/foreign code, including imported Http/Wire effects and the existing owner lifecycle. The empty Camber proof inventory printed `ALL PROOFS CHECK`; it is not mathematical evidence of IO or routing behavior. No new unsafe or foreign definitions were added. These are direct-dispatch observations, not socket framing, HEAD/204/304 transport suppression, hook lifecycle, response validation, or serving evidence.

## Output validation verification (0.2.0.0 historical receipt)

The package gate `bash scripts/check.sh camber` passed with the public response checks included in `check.bend`. `bash scripts/publish.sh --check camber` passed and printed `bend-kit-camber@0.2.0.0 will publish`. Compiled `dispatch_check.bend` and `response_check.bend` passed natively and under Bun after `bend ... -o <binary>` / `bend ... -o <file.js>`. Fixtures observed the public JSON projection excluding secret/internal fields, UTF-8 café bytes, binary NUL/FF preservation, empty and allowed redirect semantics, unsafe Location rejection, status/header/framing/Connection rejection, repeated cookies, and unsuppressed direct HEAD/204/304 bodies. The original packed route-dispatch check and a separate plain-adapter check both observed word `796983040`.

Compiled `response_live.bend` passed in native and JS lanes. Real loopback clients received zero bytes for each of 21 invalid outputs, while both plain and routed handlers returned expected `InvalidResponse`. The final valid response reached shared `Http.talk.send` and sent distinct `set-cookie: a=1` and `set-cookie: b=2` lines plus `ok`. This finite acceptance caller is not a Camber server, parser, or mapper.

`python3 camber/run_response.py` exited 0 end-to-end for the exact final consumers, including routed 204/304 body retention, sequential package/publication gates, and both compiled lanes. It enforces the existing 10 GiB disk-headroom and 20 GiB RSS guards. During implementation, live-consumer compilation exposed affine header reuse, computed-result destructuring, and incorrect Base close/result-unwrapping calls; those were corrected before the successful run. Final peak sampled RSS was 2,351,824 KiB for the package gate; live native/JS compilation used 2,258,080 / 1,904,528 KiB. Temporary binaries, owner journals, listeners, and sockets were closed/removed.

The entry gate still explicitly reports 278 definitions relying on existing unsafe/foreign code. No new unsafe or foreign definition was added. The empty human-owned law inventory remains unchanged and is not proof of host IO, transport behavior, or response correctness. No HTTP serving, hook/error-mapper lifecycle, or strict request-text decoding claim is made.

## Scoped lifecycle verification (0.3.0.0)

The single public dispatcher replaces the prior basic dispatcher; no alternate matcher, target parser, router, compatibility entrypoint, or transport was added. `scoped_check.bend` is included in the package gate and was compiled and exercised in native and JS lanes. Both observed 26 scenarios, with actual `IO.print` effect journals plus returned per-request state assertions. Every R6.6 outcome is covered: invalid target/star misuse,404, OPTIONS*,405, generated OPTIONS, group/route early responses and failures, decoder/handler failure, validation failure, and success. Assertions check exact before/transform order, entered actual policy contents in inner-to-outer order, empty scopes, sibling isolation, reversed registration, metadata-before-decoding, unsuppressed raw body, and the absence of decoder/handler effects on early exits. Forked requests retain distinct typed principals and journals.

R6.5 checks observe one mapper event or none, transform halt, failure after previous mapping, mapper failure/invalid output, and validation before/after mapping. Recovery does not restart transforms or business effects. Framework400/404/405/415 bodies match Problem Details; application/fallback500 bodies are empty with no secret diagnostics. The helper regression also observes correct JSON escaping and UTF-8 for a title containing quote, backslash, newline, and café.

`python3 camber/run_response.py` completed its package and scoped publication gates and all four native/JS consumers with exit0. Live loopback clients observed zero bytes for21 invalid standalone `plain` outputs, then exactly one safe500 for21 invalid routed originals in each lane. Routed recovery uses the actual `Completion.response` through shared `Http.talk.send`: clients reject private/secret bodies, original application headers, or a second HTTP response. The valid final response still carries two distinct Set-Cookie lines. This finite caller proves write-boundary recovery, not production serving or completion notifications. The invocation was wrapped once in `run_owner.run`; after the child succeeded, that outer wrapper attempted to reread owner journals already checked/deleted by the child and raised FileNotFoundError. That wrapper error is not hidden or a failing application scenario.

`python3 camber/run_owner.py` separately exited0 after actual compiled native/JS owner+dispatch+helper+scoped regressions, journal checks, and explicit bundle/listener cleanup. `python3 camber/run_surface.py` exited0 for all47 unchanged experimental scoped cases per lane; these receipts preserve the experiments, not substitute for the public-dispatch evidence. The scoped publication check printed `bend-kit-camber@0.3.0.0 will publish`; nothing was manually published. The final owner compilation peak was6,216,560 KiB; final standalone scoped compilation peaked at5,326,784 KiB native and4,456,464 KiB JS. Every guarded command required10 GiB free disk and killed a process exceeding20 GiB RSS; no limit was reached. Temporary binaries and journals were removed and sockets/listeners closed.

The entry check discloses278 existing unsafe/foreign dependencies, including imported HTTP/Wire effects and the owner lifecycle. No unsafe or foreign definition was added; human-owned LAWS and adverse FINDINGS remain unchanged. The empty proof inventory is not mathematical evidence of IO behavior. This leaf does not deliver body codecs, transport framing/deadlines, live completion notifications/logging, server lifecycle, cancellation, exception containment, or peer receipt. It makes no public-dispatch throughput or release-performance-budget claim.

Full package release remains incomplete until the complete-application/cross-language benchmark gate in #340. These lifecycle receipts do not satisfy that gate.

## Historical typed input verification (0.4.0.0, initial PR head)

`python3 camber/run_inputs.py` exited0 after the coordinator's source review and exclusive Bend verification-slot grant. It ran `bash scripts/check.sh camber`, `bash scripts/publish.sh --check camber` (reported `bend-kit-camber@0.4.0.0 will publish`), and compiled `input_check`, `check`, `dispatch_check`, `response_check`, `scoped_check`, and `response_live` with both `bend camber/<source>.bend -o <temporary-binary>` and `bend camber/<source>.bend -o <temporary-file.js>`. Native binaries and `bun <temporary-file.js>` were run sequentially. No manual publication occurred.

[The historical input receipt](https://github.com/paymog/bend-kit/blob/0591c1f6cfc8ecc32108dd4387daa35e37fc56ec/camber/input_results.json) at initial PR head `0591c1f6cfc8ecc32108dd4387daa35e37fc56ec` records120 cases per lane and surface: native/direct, native/live, JS/direct, JS/live (480 checked request outcomes). Each set observed35 status200, two201,62 expected400, two auth401, and19 expected415 outcomes. Direct and real loopback requests agreed exactly on status, body bytes and all application headers (transport framing excluded). File journals show `auth,decode,business` only on success, `auth,decode,map` on applicable decoder rejections, and auth alone on early rejection. Invalid router target/query syntax maps before a route's auth scope is entered, as required by R6.6. Rejected inputs never record a business event; expected failures map once.

The cases cover once-decoded path captures, U32 max/overflow/nondigits/empty values, escaped scalar repeats versus ordered lists (empty keys/values, first `=`, `+`, ignored empty fields), malformed query escapes/UTF-8/NUL, JSON media suffix/case/quoted parameters, shared coding-list identity semantics, strict text UTF-8, empty/bad/BOM/surrogate JSON, escaped-key duplicates at nested object and array-object levels, valid independent object keys, exact `-0`/fraction/exponent/large-integer number text, checked JSON-U32 conversion,64/65 nesting, configured2/3 and0 depth boundaries, and application schema/name validation including100/101 four-byte Unicode scalars. Raw NUL/FF/80/slash bytes remain unchanged even when marked gzip; there is no decompression.

The same command retained compiled owner journal/explicit-close, registration/direct-dispatch, output-helper and26-case scoped-lifecycle regressions in both lanes. Real clients also retained21 invalid standalone responses with zero bytes sent,21 invalid routed originals recovered to exactly one safe500 without private body/headers, and the final valid response with distinct Set-Cookie fields. The finite input caller uses published Http's existing connection IO; its template-only transport constructs an application per request, so these are correctness receipts, not serving/startup or throughput measurements.

Adverse development evidence: three initial guarded native smoke compiles exited1, first for a computed tuple scrutinee, then a nominal packed-Bytes identity mismatch (`0x49814d83de8f70993a43e1002be29ecd/bytes.Bytes` versus newer `Bytes.Bytes`), then reusable-versus-affine callback quantity mismatch. Parameter-pair helper seams, the exact published Bytes identity shared by Http/Json, and affine callbacks with local Data copying corrected these; no checker warning was suppressed. The final guarded smoke compiled and returned200 for `/users/%37?limit=1` with an actual `auth,decode,business` journal before the full successful gate.

The entry still discloses278 unsafe/foreign dependencies; no new unsafe or foreign implementation was added. Human LAWS and research/benchmark artifacts remain unchanged. The maximum sampled RSS in the complete gate was6,459,616KiB, below the20GiB kill ceiling; disk headroom was checked before each process. The verification slot was released with no matched compiler/runtime processes, no listeners on18335 or18333,34,663,456,768 bytes free, and all owned temporary builds/journals removed. HTTP admission/T3, production serving, completion notifications, archive publication, and the full release benchmark remain outside this leaf.

## Final quoted-pair charset verification (0.4.0.0)

Coordinator source review found that quoted charset values must be compared after RFC quoted-pair decoding: `charset="ut\f-8"` denotes UTF-8, not an unsupported raw spelling. The shared `media.parameter` now uses a streaming expected-value comparison for both JSON and text. It consumes escaped characters once without allocating another decoded parameter string, retains case normalization, and requires a genuine unescaped closing quote at the end. Unsupported decoded values and malformed syntax still reject415.

A guarded native `bend camber/input_check.bend -o <temporary-binary>` smoke exercised all14 new direct cases with actual response and file-journal assertions: singly and multiply escaped UTF-8 succeed for JSON/text; unsupported values, escaped quote/backslash, incomplete close and trailing junk reject415. Its first compile exited1 because `c` was matched after later `expected`/`escaped` binders. Matching `c` first corrected the checker-order error without changing value semantics; the successful smoke compile peaked at3,532,304KiB. Coordinator reviewed and accepted the corrected source.

The exact final `python3 camber/run_inputs.py` exited0 in130.00 seconds. [The current receipt](input_results.json) records134 cases in each native/direct, native/live, JS/direct and JS/live set (536 checked outcomes), including all14 charset additions. Each set observed39 status200, two201,62 expected400, two auth401 and29 expected415. Exact direct/live responses and effect journals passed, as did the same package/publication, owner/dispatch/helpers/scoped and genuine recovered-safe-response live regressions described above. The final receipt's `adverse` array is empty; the earlier checker failures remain recorded here as historical development evidence, not erased or presented as final runtime failures.

The maximum sampled final-gate RSS was6,168,160KiB; the entry still discloses278 inherited unsafe/foreign dependencies. The exclusive verification slot was released with no matched compiler/runtime processes, no listeners on18335/18333,34,305,249,280 bytes free, and all temporary smoke/gate binaries and journals removed. No runtimes were started after release.
