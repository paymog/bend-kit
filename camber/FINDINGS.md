# Camber design validation

Date: 2026-10-02. These are experiment findings, not guarantees of an implemented or published Camber package. The user-approved [SPEC](SPEC.md) now targets a dedicated supervised server process and is included in [PR #315](https://github.com/paymog/bend-kit/pull/315).

## Verdict

The application-layer design fits Bend when reusable configuration and route descriptions are `Data`, execution is supplied through closed templates, and affine resources move through request work explicitly. A copied callback registry does not fit that model. The typed/scoped application now runs through finite real-socket transport in both lanes. Its behavior contract is coherent, but public interface ergonomics and production serving remain unproved.

Native direct overhead passed the frozen allowances in all 18 paired controls. A tighter five-workload recheck passed all native comparison gates, but three Bend-on-Bun direct overhead failures persisted. Historical routing, strict JSON, and cancellation probes found blockers under the earlier contract. Prepared routing now corrects the routing gaps below; strict JSON remains unresolved. The user removed runtime cancellation and embedded lifecycle isolation from the release contract, not from the recorded observations. Loopback throughput is measured; production capacity, complete-framework overhead, and release safety are not established.

## Design risks, in priority order

The lifecycle experiments ran sequentially in native and Bun/JavaScript lanes with Bend 2.0.34. Run `python3 -B camber/run_risks.py`. [design_risk_results.json](design_risk_results.json) retains every calibration and final scenario. These are boundary probes, not a serving implementation or a passing SPEC gate.

| Priority | Risk | Assessment |
| --- | --- | --- |
| 1 | Dedicated-process lifecycle | External termination works in the probes; integrated graceful drain and supervisor deployment remain unproved |
| 2 | Resource recovery and transport lifecycle | Affine ownership does not establish descriptor cleanup or socket teardown |
| 3 | Composition and authoring | Typed/scoped mechanisms work; the small final authoring interface remains unproved |
| 4 | Performance | Large-body transport risk and JS overhead failures remain; complete-framework costs are unknown |

### 1. Cancellation and containment

The candidate forced operation is Base `IO.die(Unit, 1, ...)`, invoked by spawned work after a 100 ms timer. It halts the whole program, not just server-owned work. With a sleeping worker, the halt marker arrived after 101 ms native and 113 ms JS. Neither worker explicitly closed its File, and unrelated work scheduled to write after 500 ms did not complete. This failed the earlier embedded-shutdown requirement, which the user has now removed. Runtime-crash containment is not promised by R6.8.

Pure CPU work was calibrated to at least 300 ms before testing its interaction with that timer:

| Lane | Iterations | Calibration | Timer to halt marker | Journal |
| --- | ---: | ---: | ---: | --- |
| Native, one runtime thread | 512,000,000 | 488 ms | 498 ms | `committed` then `late` |
| Bun/JavaScript | 128,000,000 | 807 ms | 823 ms | `committed` then `late` |

Both exceed the scaled 100 ms timer plus 100 ms forced-teardown allowance. Both perform the late write before halt. Native did not emit the explicit-close marker; JS did. These scaled experiments are not a measurement of the SPEC's default 5-second grace plus 1-second teardown. They show that this same-runtime timer is not a demonstrated hard interruption boundary for noncooperating pure work.

A cooperative worker blocked on a stop channel returns its File when the owner closes that channel. The owner joins and closes the File before unrelated work finishes successfully. The journal contains only `committed`. This validates one cooperative protocol, not cancellation of arbitrary handlers or pending socket effects. The earlier timeout/late-write failures remain unchanged and were not rerun.

The initial CPU fixture never reached its calibration floor and completed work before halt. Its [initial observations](design_risk_initial_results.json) remain retained, but are not CPU-interruption evidence. The final fixture uses a runtime-generated seed after the begin marker and larger inputs to keep the measured work inside the observation boundary.

The `process` package also has a separate capability defect. A minimal `Process.exit(77)` using the published hash exits 1 with `bend: an alien request` in native. Its JS build fails before main with `no effect registers .../process.exit.raw`. The relative native import failed too: emitted `CID____PROCESS_PROCESS_EXIT_RAW` does not match the adapter's literal registration guards. [process_exit_risk_results.json](process_exit_risk_results.json) retains those failures and the minimal source. The current effects guide requires namespace-aware `CID(name)` registration; these legacy adapters do not use it. This is adapter compatibility evidence, not an established compiler defect or a supported process-exit implementation.

#### Upstream boundary and external supervision

This is not an assumed pending runtime feature. Upstream [#1034](https://github.com/bendlang/bend/issues/1034#issuecomment-5857296248) was closed after adding the deadline race; cancellation of the losing blocking effect was explicitly excluded. Bend 2.0.34's [WONTFIX](https://github.com/bendlang/bend/blob/v2.0.34/WONTFIX.txt) lists that exclusion under capacity limits. The `v2.0.34` tag resolves to source revision `7d8a3eb036042c6549461054d25a10f26d361c5c`.

The [native scheduler](https://github.com/bendlang/bend/blob/v2.0.34/bend2/comp.ts#L5970-L6010) evaluates a continuation synchronously before handling its next IO request; a Halt calls process `exit`. The [JS scheduler](https://github.com/bendlang/bend/blob/v2.0.34/bend2/comp.ts#L6416-L6455) invokes continuations synchronously and returns from the whole IO runner on Halt. Pure work therefore can delay reaching the timer continuation. The runtime does not expose a server-owned cancellation/cleanup control through Base spawn or fork.

Run `python3 -B camber/run_supervision.py`. It reuses the retained CPU iteration counts, runs a dedicated Bend child, and sends OS `SIGKILL` after a 100 ms host-side delay. [supervision_risk_results.json](supervision_risk_results.json) retains all four observations:

| Lane | CPU signal to child reaping | Idle-socket signal to child reaping | Idle peer closes | Unrelated parent work |
| --- | ---: | ---: | --- | --- |
| Native | 1.309 ms | 1.333 ms | yes | completes |
| Bun/JavaScript | 3.595 ms | 1.294 ms | yes | completes |

The CPU worker has not emitted its end marker when killed. Both journals retain only `committed`; the later write does not occur. The idle peer observes closure after termination. No explicit File-close marker appears. The surviving unrelated work is an actual Python-parent task, not a computation embedded in the terminated Bend process. Recorded overall wall time includes waiting for that parent work; signal-to-reap time measures child termination.

This proves an external termination boundary for these dedicated-process workloads, not real-time OS scheduling, graceful drain, restart safety, descendant cleanup, or an implemented Bend supervisor. On 2026-10-02 the user explicitly chose dedicated-process serving and dropped embedded lifecycle isolation and preemptive handler cancellation. R7.4/R7.5 now permit an external supervisor to terminate the whole server process after grace expires. These probes support that fallback boundary, but do not establish the full serving contract or its default shutdown budgets.

The deployment must document its external supervisor, shutdown trigger, grace period, forced-termination action, and observed process exit. Cooperative work still returns its affine instances for explicit cleanup. Forced termination may skip cleanup, flushes, and completion notifications; remote side effects may outlive the process. Timeouts and disconnects do not release a dependency still held by running work. Direct dispatch remains supported without promising an independently stoppable embedded server.


### 2. Affine-resource recovery and transport lifecycle

After a worker sends its actual File into a closed result channel, `Chan.send` reports false and the worker finishes. `lsof` still finds that File's descriptor in the live process in both lanes. The probe stays alive for inspection, then exits naturally. Erasing the affine result is not observed File cleanup. A timeout or shutdown design must preserve an owner and a recovery path rather than drop the resource-bearing reply.

Closing the finite transport's listener refuses new connections in both lanes. An already accepted idle socket and the process remain alive 6.25 seconds later, beyond the SPEC's default combined shutdown budgets. Only after the client releases the socket does this fixture join the connection and close its File. This is not a shutdown invocation: it tests whether listener closure alone supplies the missing lifecycle behavior. It does not.

Source inspection identifies the shared seams: `Http.talk.after` loses the write outcome, the bundled fixture starts workers before `IO.try` on listen, and worker admission follows complete body framing. The follow-up runtime probes below exercise those paths. Their finite connection count and bounded job queue are not production T3 admission controls. Bind-result propagation and socket/write controls belong in `http`/`wire`; cleanup of opened application bundles belongs to their owner. Camber must not add a second transport.

#### Executed startup, admission, and write-outcome gates

Run `python3 -B camber/run_transport_risks.py`. [transport_risk_results.json](transport_risk_results.json) retains five scenarios in each lane: occupied-port startup, small and larger incomplete-body admission, healthy write, and reset-peer write. This validates current boundaries, not a public serving interface or passing transport contract.

| Gate | Observed in both lanes | Limit |
| --- | --- | --- |
| Startup bind failure | Store and audit files are created; exit code 48 and `Address already in use`; no READY or explicit bundle-close marker | Terminal diagnostics, not a returned startup result with logical resource cleanup |
| One held worker plus incomplete bodies | The small run has 3 live server endpoints; the larger run has 131 with one worker busy and 129 incomplete-body peers | Worker permits do not bound accepted sockets or pre-handler buffered work |
| Business overload and normal drain | Extra complete business request gets 503 without audit writes; release restores `busy=0`, then ordinary drain closes the bundle | Positive worker recovery, not forced shutdown or production admission |
| Healthy response write | Peer receives exact `200`/`ok`; raw IO result succeeds; public continuation is `TurnClose` | Closure does not identify successful write |
| Peer reset before response write | Actual IO result fails; the same public continuation is `TurnClose` | Failure is erased before completion reporting |

The bind-failure path is the existing `Live.start`: bundles open and workers start before `TCP.listen`, whose failure is passed through `IO.try`. This whole-program failure does not falsely signal listening. No explicit bundle-close marker appears before exit; OS process cleanup is not a resource-return protocol to an embedded owner. No live-process descriptor leak after exit is claimed.

The larger admission fixture deliberately calls the existing start helper with 132 lifetime accepts, rather than its original four-connection CLI horizon. `lsof` counts 131 actual established endpoints after the overload connection closes: held handler, control peer, and 129 incomplete-body peers. Each incomplete body declares 4,096 bytes and has sent 1,024. This exceeds the proposed 128-connection default, but that default is not configured or implemented in the fixture. It shows why the one-worker cap cannot supply T3. The measurements do not distinguish bytes in kernel receive queues from bytes already retained by Bend. Production `Http.conn` likewise spawns each accepted socket without an admission counter.

The write probe uses the same `Http.reply.bytes` and `Http.io.send.bytes` writer as `Http.talk.send`, observes its actual result, then passes that result through the existing `Http.talk.after` with non-keepalive policy. It adds only observation between writer and transition. Both success and real reset failure yield `TurnClose`, so the information is lost at that transition, not guessed from client disconnect. No completion-notification API was supplied or exercised. T5 must preserve the result before R6.7 can report it honestly.

The user initially kept cancellation blocked while these transport gates ran, then explicitly relaxed the contract to dedicated supervised serving. The raw observations remain unchanged. Runtime cancellation is no longer a release prerequisite; startup rollback, production connection/buffer limits, write-outcome reporting, notifications, and integrated graceful shutdown remain outstanding. Previous failure datasets and performance budgets remain unchanged.


### 3. Application composition and authoring

The retained direct and socket results support typed authentication, affine inputs, entered scopes, single-pass expected-error mapping, public sibling isolation, and plain packed-body handlers. They were not rerun to reconfirm known results. `author_app.bend` still needs explicit templates, quantity adapters, scope wrappers, metadata reconstruction, and a hardcoded route branch. The mechanism fits Bend; a small final public interface has not been demonstrated. Same-author examples do not establish independent-author usability, and no independent author or subagent was used.

### 4. Performance

The retained external comparison shows 4 MiB Bend raw/scoped echo throughput of 72/75 requests/s, against 1,041 for axum, 692 for Fastify, and 806 for FastAPI. At 37/s, corrected Bend raw/scoped p99 is 166/110 ms, against about 11–13 ms for those controls. The minimal scoped/raw ratio does not explain that large gap by itself. Transport/body profiling is warranted; an exact bottleneck is not established.

The native tighter recheck passed its frozen gates, while JS direct overhead and one p99 failure persisted. These measurements predate prepared routing and do not price the full typed application. Generator sensitivity prevents a clean capacity ranking. No performance comparison was rerun or budget relaxed during this risk validation.


## External framework performance comparison

The [benchmark report](bench/README.md) and [all retained samples](bench/frameworks/results.json) compare native Bend raw/scoped controls with Hyper/axum, Node HTTP/Fastify, and plain ASGI/FastAPI on Uvicorn. All eight variants passed 19 workloads with three closed-loop and three corrected fixed-rate trials each: 912 measured trials, with no transport errors or unexpected statuses and exact aggregate response bytes.

Bend scoped fixed text measured about 24k requests/s, versus axum 107k, Fastify 80k, and FastAPI 22k. The scoped/raw throughput ratio is 0.93–1.19 across the corpus. Four-MiB echoes expose a larger gap: Bend scoped about 75/s versus axum 1,041/s, Fastify 692/s, and FastAPI 806/s. At the common 37/s rate, Bend scoped corrected p99 is about 110 ms versus 11–13 ms for the other controls.

These are exploratory loopback observations, not production capacity or complete Camber overhead. Generator scaling changes Hyper throughput materially, and longer focused measurements retain large swings. Client CPU and scheduling still matter; no non-limiting generator claim is made. Fastify beats the simple Node adapter in most cells, while FastAPI loses throughput at 1,000 literal routes. Neither difference isolates pure framework overhead. The report records feature and routing differences, CPU/RSS definitions, all trial data, and unstable tails.

The next performance investigation should profile native HTTP transport/body work. The comparison predates the prepared-router cutover; its measured source revision is `f441c13`, and its datasets remain unchanged. It does not resolve strict JSON or production serving gaps. The later user-approved lifecycle scope change does not alter these measurements or human-owned laws.

## Prepared router prerequisite

The shared `router` now prepares and validates route descriptions before dispatch. Camber's reusable plans and scoped fixture use that table; the superseded callback-free list selector is removed. This is the local breaking `router` release `0.2.0.0`, pending merge and CI publication, not a published Camber API.

Selection is path-first and independent of registration order. The table rejects duplicate method/shape pairs and conflicting ancestry, preserves each method's capture names, exposes hidden methods, and supplies explicit/generated HEAD and OPTIONS plus sorted Allow sets. Targets retain exact slashes and case, decode segments once with strict UTF-8, preserve ordered repeated query fields, and reject invalid targets. Absolute-form authority replaces application Host.

Generated 405 and OPTIONS enter the selected group but skip route hooks, decoding, and business work. Group authorization and early responses still apply. `OPTIONS *` enters only the root scope. The reusable executor now receives the selected capture map; lookup no longer reparses the target or repeats method selection. Direct HEAD retains the GET body, while socket transport suppresses it.

Runtime evidence in both native and JavaScript lanes:

- `run_surface.py`: 47 direct cases; `run_surface_live.py`: 51 socket scenarios, including grouped method outcomes, invalid targets, HEAD, absolute/encoded paths, journal invariants, queued work, disconnects, and packed plain-handler bodies. New socket observations are retained in [router_surface_live_results.json](router_surface_live_results.json); the earlier dataset remains unchanged.
- `run_ownership.py`: ownership and reusable-plan checks; the reusable fixture also covers HEAD lookup, absolute-form encoded lookup with repeated query fields, and an encoded static route.
- `run_live.py`: all four bundled scenarios, with the route scenario extended for absolute-form HEAD lookup and encoded static selection.
- Prepared-router assertions pass in the checker and native/JavaScript builds. The unchanged entry/proof gates pass. A throwaway real-handler smoke observed `Host: example.test:8080` instead of the supplied `wrong.test` in both lanes.
- The 10-iteration dispatch smoke passes in both lanes with 10/100/1,000 prepared registrations. This is correctness smoke, not a replacement for retained performance budgets.
- The [router benchmark](../router/bench/README.md#prepared-router-results) agrees on checksum `3019866368` across C, Rust, Bun, Node, Python, and Bend. The final three-trial native Bend median is 472.5 ms for 160,000 requests; this includes strict target handling and remains a linear scan.

The asterisk/root pairwise regression failed before its fix and passes afterward. A new HEAD lookup check also exposed obsolete second-stage method dispatch; passing the prepared capture map to the business endpoint removes that second selection. Both fixes have retained behavior checks.

Preparation remains O(routes²), and resolution O(routes × segments). New routing/target guarantees have runtime evidence, not new quantified laws. General group construction, typed query access, final authoring signatures, completion notifications, strict JSON, and production transport remain open. Dedicated-process supervision replaces runtime cancellation as the release lifecycle boundary. This does not satisfy the complete SPEC or revalidate earlier framework-overhead budgets.


## Reproduce

```sh
python3 camber/run_ownership.py
python3 camber/run_dispatch.py 1000 3
python3 camber/run_dispatch.py 10000 3
python3 -B camber/run_live.py
```

The first command builds and runs both ownership and reusable-interface checks in native and Bun/JavaScript lanes. The measurement runner starts with 10 iterations, then runs the requested trial size. It warms each workload for 100 iterations, checks the expected result checksum, samples process RSS, kills a process above 20 GiB RSS, and applies command deadlines. The live runner exercises loopback sockets and bundled dependencies. All runners remove their temporary binaries and journals.

The separate [deadlock probe](deadlock_probe.bend) is intentionally unsuccessful. Build and run it in either lane:

```sh
bend camber/deadlock_probe.bend -o /tmp/camber-deadlock
/tmp/camber-deadlock
bend camber/deadlock_probe.bend -o /tmp/camber-deadlock.js
bun /tmp/camber-deadlock.js
```

Both lanes were observed to exit with status 1 after printing that both requests held one instance. The runtime reported `bend: deadlock: every computation waits on a channel`. This is evidence of an unsafe acquisition policy, not a passing server-lifecycle test.

## Ownership and composition

[ownership_check.bend](ownership_check.bend) passed in both lanes:

- The four example routes return the expected status and public JSON.
- Authentication rejects before JSON decoding. Invalid IDs, overflow, malformed JSON, missing or wrongly typed fields, extra fields, repeated keys, and empty names reject without creation.
- Accepted creation writes exactly one actual journal record and returns the expected Location. The user can be read afterward. Internal secret fields are absent from the response.
- A real failed write to a read-only file returns the handle. The failed creation leaves the user absent, and the same handle supports a later lookup.
- Two worker instances are in use while both requests wait at a deterministic barrier. Concurrent Alice and Bob requests return their own principals' users.
- An expected lookup failure overlaps another request. Both instances return to idle. Their files close after all admitted work finishes.

The store is an application fixture: each worker has its own user list and real journal handle. This does not establish shared database consistency or client-pool semantics.

The first runtime check exposed incorrect use of `IO.join` on persistent channels. `IO.join` closes the channel after receiving a value. The retained implementation uses `Chan.recv` for persistent event and release channels, and `IO.join` for one-shot replies.

## Are we fighting Bend?

### What fits

[interface_check.bend](interface_check.bend) passed in both lanes. It demonstrates:

- A reusable, copyable application plan containing route descriptions and runtime configuration, without stored callbacks or handles.
- A closed template executor that receives configuration and affine state as runtime arguments.
- A typed before hook from `Unit` context to `Principal` context. The protected handler receives the established principal, not an unchecked optional identity.
- Rejection without calling the protected handler, and a public health route without authentication.
- Two application configurations that do not leak their response labels into one another.
- A registered alias that invokes the selected action rather than treating the original target as the action.
- A plain `Http.Req -> IO(Http.Res)` echo handler that moves the same packed body into its response, including NUL and non-ASCII octets. Conversion to String occurs only in the test assertion.

These mechanisms respect the language. They do not require copying closures, sharing an affine File, implicit body copies, or a string-key service locator.

### What does not fit

A minimal checker probe declared this field:

```bend
type Route is Data:
  Route{handler: U32 -> U32}
```

Bend 2.0.34 rejected it with `expected: Data; observed: Type`. An ordinary callback is affine even if it captures only copyable data. An Express-style registry of copied callback values cannot be assumed valid. This does not rule out every callback-oriented interface; factories or explicitly threaded affine structures would need their own experiment.

A second probe created a `Chan(U32)` inside `main` and passed a template lambda that captured it. The checker rejected the call with:

```text
a template applied to closed ~ arguments
(queue is a variable here, not comptime: pass it at run time)
```

The same failure was observed at the actual `Http.serve.on` call. Its current handler parameter is a closed template and the serve function has no runtime application-context parameter. The original worker example cannot be adapted through that unchanged entry point. The live probe below passes runtime context explicitly instead.

**Required transport work:** provide an explicit runtime typed-context seam alongside the handler template. Channels may live in copyable context; File handles must remain in their affine owner set. This requirement is additional to the startup, write-outcome, admission, deadlines, and shutdown work already listed in T1-T6.

### Ownership is not liveness

The deadlock probe uses two bounded channels containing real File handles. Request A obtains the first set's instance. Request B obtains the second set's instance. A barrier ensures both hold one instance before either requests the other. Both runtimes report a deadlock.

R2.5's bounded queues do not prevent this failure. The live experiment below uses worker-owned resource bundles created before serving, so no request performs nested dependency checkout. That is a validated candidate, not a frozen public policy. Atomic bundle acquisition or a globally ordered acquisition protocol remain alternatives. A multi-connection pool must also be distinguished from a single checked-out connection; exclusive ownership of a whole pool can serialize otherwise independent work.

## Live transport and bundled dependencies

`python3 -B camber/run_live.py` passed all four scenarios in both native and Bun/JavaScript lanes. [live_check.bend](live_check.bend) uses [http/context_probe.bend](../http/context_probe.bend) as a finite transport probe. The probe reuses HTTP's existing framing state machine, packed receive effects, response writer, keep-alive decisions, and pipelined-rest handling. Its handler template receives copyable runtime context explicitly. It adds no foreign effects and no `@unsafe` definitions.

The live and direct paths call the same `Registry.invoke` executor. Each worker owns a bundle containing a real `Users.Store` journal and a separate real diagnostic File. Both handles are opened before listening and stay together; requests do not acquire resources in opposing orders. GET work can exercise Store first or diagnostic File first without nested checkout. The diagnostic File records POST attempts, including rejected application inputs; it is not a transaction log or a second business-data commit.

| Scenario | Observed result in both lanes |
| --- | --- |
| Four routes and packed-body handler | Correct health, parameter lookup, principal, creation, Location, and read-after-create; unauthorized malformed input rejects; repeated keys reject; NUL/high-octet echo remains exact |
| Keep-alive, pipelining, fragmented sends | Sequential requests reuse a connection; three pipelined responses preserve order; fragmented 1 KiB JSON creates the expected second user |
| Two occupied bundles | Deterministic barriers establish both slots in use; owner reports `busy=2, mask=3`; a third creation receives `503` and reaches neither journal |
| Return and recovery | Opposite operation orders return Alice and Bob correctly; owner reports `busy=0, mask=0`; another request succeeds after exhaustion |
| Store write failure | A read-only Store journal causes `500`, leaves the user absent, preserves both handles, and supports later lookup plus another failed write |
| Diagnostic File write failure | A read-only diagnostic handle causes `500` before application creation; Store stays unchanged; later lookup and another failed attempt work |
| Orderly drain | Listener closes while admitted requests remain held; no bundle closes then; after release, every slot closes once following the final leave event |

The route scenario finishes with 14 completed jobs and no rejection. The exhaustion scenario finishes with four completed jobs and one rejection. Each failure scenario finishes with five completed jobs, no rejection, and no user creation. The runner verifies actual journal contents, public response bytes, and final owner counters. Its separate direct-dispatch journal contains only the expected creation.

One existing transport behavior matters: `Http.serve.keep` closes connections for any `400`, including application input rejection. The live check therefore observes EOF after repeated-key rejection and uses another connection for later work. This is not a new Camber policy. The probe also preserves HTTP's bodyless `204` framing: no Content-Length or Transfer-Encoding is sent.

### Limits of this result

The fixture accepts one to four connections, bounds each connection to 64 framing steps, and has fixed owner/worker fuel. Its message channel has eight slots, and its job queue and admission count are bounded by the one or two bundles. It rejects resource exhaustion instead of building a waiting job queue. The bounds make this validation finite; they are not the release admission, timeout, shutdown, or cancellation design.

The `/_capacity`, `/_release`, `x-hold`, and `x-order` controls are test instrumentation, not Camber API proposals. Ordinary application routing and typed principal work still use the existing experiment. Shared database consistency, crashes, stuck-handler cancellation, startup failure cleanup, client-pool semantics, and full target/method handling remain unproved. Scoped transforms and mapper recovery are checked separately by the direct surface probe below, not by this live fixture. No production HTTP entry point, package version, or human-owned law changed.

The final live runner build observed 17.806 seconds and 5,254.45 MiB sampled compiler-process RSS for native, and 3.743 seconds and 2,920.83 MiB for JS. A preceding native build sampled 5,537.06 MiB. These are compilation observations, not request costs or total process-tree memory. Builds and server processes run sequentially with host deadlines and a 20 GiB RSS ceiling.

The existing affected-package gate, `scripts/check.sh http`, also exited 0. It ran the entry check, existing proof gate, and HTTP checks. Its expected unsafe/foreign dependency report is accepted by the repository's existing verdict wrapper; this is not a claim that host IO has a formal proof. The gate was monitored with a 180-second deadline and a 20 GiB process-group RSS ceiling.


## Direct application-author surface

Run `python3 -B camber/run_surface.py`. All 33 scenarios passed in native and Bend compiled to JS and run on Bun. The latest builds took 8.483 seconds and 2.619 seconds, with sampled compiler-process RSS of 4,270.16 MiB and 2,258.75 MiB respectively. The runner reuses the existing host deadline and 20 GiB RSS guard and runs one build or executable at a time.

`surface_app.bend` is the application example. It declares routes, typed before hooks, response transforms, a decoder, a handler, and an error mapper. It owns a File in its application state. It contains no channels, workers, acquisition messages, or HTTP framing code. `surface.bend` supplies provisional typed lifecycle primitives. This is an interface experiment, not a public API or a published package.

### Affine input and typed hook transitions

The input is genuinely affine:

```bend
type Document is Type:
  Document{principal: Users.Principal, value: Json.Val}
```

Authentication establishes `Users.Principal` before body decoding. The generic endpoint accepts `I: Type` and consumes the decoded input once. The decoder accepts exactly one `doc` envelope field, moves its arbitrary JSON value into `Document`, and rejects malformed JSON, missing/wrong/extra envelope fields, and duplicate envelope fields. Bodies and keys stay packed during decoding. The handler consumes the parsed value into a JSON response after one real receipt write.

Observed responses retained the correct Alice/Bob principal, UTF-8 text, and the exact number text `1e+02`. An escaped spelling of `doc` was accepted after JSON decoding. These are not the SPEC's four-route application or strict JSON prerequisites.

### Entered scopes and single-pass mapping

Semantic stage traces, HTTP policy headers, response bodies, and actual journal bytes establish:

- Before hooks run root, group, route. Two group hooks run in declaration order and pass a typed principal between them.
- Transforms run route, group, root, in reverse declaration order within each scope. The public route's identity entry adapter has no application before hook, but its transform still runs.
- The public sibling gets no user/document policy. An unknown path gets only root policy.
- Authentication rejection precedes parsing. A group early response or expected failure skips the route, decoder, and handler but retains group/root transforms. The early response does not invoke the mapper.
- Decoder rejection has no receipt write. An actual write through a read-only File fails, maps once, and returns a usable handle: the observer reads the original seed through that same handle before closing it.
- Transform failure stops all remaining transforms, including outer scopes. A previously unmapped failure maps once; failure after mapping produces a fixed empty-body `500` without another mapping.
- Mapper failure or invalid mapped status produces that same minimal `500`, without recursion or further transforms. Final invalid status maps once, or falls back without a second mapping if the response was already mapped.
- A successful handler write followed by transform, mapper, or status-validation failure leaves exactly one receipt. Recovery does not replay or undo the handler.

The mapper trace includes the actual error kind, so the checks distinguish decoder, authorization, domain IO, transform, and validation failures. Fault controls and stage traces are fixture instrumentation, not proposed public configuration.

### Ergonomics and limits

Worker plumbing can stay outside application code. The decoder and scoped hook contexts no longer need a blanket `Data` restriction. However, this surface still requires explicit template types/functions, quantity adapters, scope wrappers, an action enum, and an action-to-route match. It proves implementability, not a small final interface or independent-agent usability.

The checker distinguishes `K -> ...` from `@+config: K -> ...` even when `K` is Data. The `.go` adapters keep the callback's affine parameter signature and let its helper reuse copyable configuration or metadata. This avoids rebuilding application records to satisfy the template signature, but adds author-facing boilerplate.

The original dispatcher reused the callback-free list selector and pairwise router. The first 27-scenario revision was direct-only and validated status only. The later socket and response-safety results superseded those limits; the prepared-router cutover above now replaces that selector. RFC 9457 defaults, completion notifications, strict JSON, cancellation, and production lifecycle remain outside the implemented probes.

Simplification ran inline under the no-subagent constraint. It replaced key-to-String conversion with the existing packed `Bytes.eq` and removed an unused runner input fallback. No separate linter is configured for these experiment files. The retained runner compiles and exercises both lanes; existing unaffected HTTP/live/performance gates were not rerun.

Code review: skipped (ce-code-review unavailable) — its independent-agent workflow cannot run under the user's no-subagent constraint. No independent review is claimed.

## Performance evidence

Environment: Apple M4 Pro, macOS 26.6.2 arm64, Bend 2.0.34, Bun 1.3.14, Python 3.14.6. The table records medians of three trials of 10,000 iterations on the final measured experiment revision. Units are microseconds per iteration, derived from the runner's millisecond totals.

| Workload | Native | Bun/JS |
| --- | ---: | ---: |
| Health response | 0.470 | 2.584 |
| Authenticated parameter lookup | 2.692 | 11.249 |
| Invalid-ID rejection | 2.637 | 12.470 |
| 1 KiB JSON construction, parsing, and name validation | 11.445 | 64.727 |
| 1 KiB echo endpoint without route-table selection | 10.764 | 44.668 |
| Same echo endpoint, last hit in 10-entry registry | 14.725 | 53.607 |
| Same echo endpoint, last hit in 100-entry registry | 52.616 | 128.544 |
| Same echo endpoint, last hit in 1,000-entry registry | 466.142 | 939.016 |

All workload checksums agreed with their expected results in both lanes. The 1 KiB JSON payload is `{"name":"Cara"}` followed by spaces to reach 1,024 bytes. Input-body construction occurs inside the timed loop. Store opening, route-table construction, warmup, and final closing are outside the timer. These loops do not perform store writes. Response status and body length are consumed to force results; exact response bytes are checked separately by the correctness runner.

The registry uses the existing pairwise router, tries descriptions in order, and splits patterns repeatedly. The echo endpoint without table selection and the registry variants use the same endpoint, runtime configuration, metadata, and body. Their comparison isolates table selection for this accepted-request workload; it is not an equivalent full-server baseline or Camber's release overhead budget. The registry is an interface probe, not the prepared-router implementation required by R3.

At 1,000 iterations, native medians were 0.485 microseconds for health, 2.709 for parameter lookup, 11.295 for JSON, and 462.624 for the 1,000-entry registry. The 10,000-iteration run is consistent with approximately linear work for these native cases. The shorter run preceded the typed-hook/alias additions; the final large run includes them. JS trial variation and JIT/GC effects remain material.

### Build and memory observations

For the final large run:

| Observation | Native | JavaScript |
| --- | ---: | ---: |
| Build wall time | 11.522 s | 2.845 s |
| Generated artifact size | 1,867,920 bytes | 244,029 bytes |
| Sampled compiler-process peak RSS | 3,378.20 MiB | 2,443.31 MiB |
| Sampled runtime-process peak RSS | 2.61 MiB | 247.23 MiB |

RSS was sampled with `ps` every approximately 100 ms. These are observed samples, not kernel-recorded peaks or total process-tree memory. Other native builds in this session reached about 3.9 GiB sampled compiler RSS. Keep the repository's one-Bend-process rule even for a small source example that imports HTTP and JSON.

The shorter run sampled 2.59 MiB native runtime RSS and 179.02 MiB JS runtime RSS. The larger JS run used more memory. These observations do not establish bounded retained memory, absence of a leak, admission safety, or overload recovery. They also do not include slow clients, sockets, p99 latency, CPU utilization, or large response bodies.

**Conclusion:** small native application work is promising. The current repeated matcher is unsuitable for a scalable prepared-table design. JS costs and memory need their own budget. No comparative claim about Flask, Fastify, axum, or another production framework is supported here.

## Does the interface make sense?

The behavioral contract makes sense. Explicit input decoding, typed principal establishment, returned responses, and one shared dispatch path are useful, distinct concepts.

The descriptor/template split is one workable interface direction, not the final public interface. It exposes an action enum, a route-description table, and an action-to-handler match. That repeats registration information and could become administrative work in a larger application. Camber should hide worker/channel plumbing. It should not claim ergonomic parity with callback-based frameworks until an application author has exercised its actual public surface.

The original ownership fixture's generic decoder restricts input to `Data`. The direct surface probe now accepts a `Type` model containing `Json.Val`, and its generic hook contexts are also `Type`. This removes that assumption from the new candidate without changing the older fixture. It does not freeze the final decoder signature.

Scope inheritance, transform unwind, single-pass mapper recovery, and final response safety have direct and finite-socket evidence. The prepared-router cutover adds strict targets and validated registration. General group construction, typed query access, and completion notifications remain unimplemented by these probes.

## Will agents be able to use it?

The design has useful properties for agents: inspectable static descriptions, explicit resource flow, typed hook transitions, deterministic rejection, compiler feedback, and a port-free execution path. A complete small example gives an agent a pattern to copy rather than an invitation to invent ownership rules.

That is a design assessment, not a measured agent-usability result. No subagents or independent application-writing agents were used. These probes were authored and checked in the same session. They do not measure how reliably another agent can add a route, choose quantities, interpret errors, or maintain an application without editing framework internals.

The direct surface example now demonstrates an affine typed route, typed authentication, and expected-error mapping without worker or framing code. Before release, an independent author must exercise the intended public interface rather than these provisional primitives.

## Next work

1. **Integrate the dedicated-process lifecycle.** Preserve cooperative drain and explicit cleanup through shared transport controls. Document an external supervisor that enforces grace and forced termination even if Bend stops making progress, and verify actual process exit. Do not reintroduce embedded isolation or require runtime cancellation.
2. **Prove resource and transport lifecycle recovery.** Preserve resource-bearing replies until explicit cleanup. Exercise startup failure, bounded admission, write outcomes, idle/active connection teardown, and grace completion through shared `http`/`wire` controls. Keep worker-owned bundles distinct from checked-out connections and pools.
3. **Validate the intended small authoring interface.** Reduce template/quantity/dispatch glue without copying callbacks or affine state. Exercise that actual surface with an independent author before claiming usability. General group construction and typed query access remain open; no signature is frozen.
4. **Measure complete-application costs and profile transport/body work.** Preserve the raw controls, failed JS allowances, and external samples. Revalidate the final interface and prepared routing rather than treating historical minimal controls as a complete Camber gate.

The prepared router still needs merge and CI publication. Strict JSON remains an independent release prerequisite. Neither should displace the higher-risk cancellation and resource-lifecycle gates.

Do not broaden the initial feature set. The next work is making the existing ownership and application contract implementable and usable, not adding plugins, schema generators, or streaming.

## Raw HTTP control and pre-Camber budgets

Run `python3 -B camber/run_raw.py --output camber/raw_results.json`. The retained JSON contains every measured trial, build/artifact observations, verified startup, server/client CPU, latency percentiles, and sampled RSS. `camber/raw_budget.json` freezes numeric per-workload limits and their policy before any new Camber timing. These are raw measurements and chosen engineering limits, not a passed Camber overhead gate.

Environment: Apple M4 Pro, macOS 26.6.2 arm64, Bend 2.0.34, Bun 1.3.14, Python 3.14.6.

The same raw handlers serve direct calls and the actual `Http.serve.on.with` entry point. Profile 0 handles text, JSON, parameters, decode, hooks, and byte echo. Separate profiles register exactly 10, 100, or 1,000 canonical `/route/<id>` paths. Generated numeric predicates avoid runtime table construction. This specialized route family is not a general prepared router or a route-count scaling claim; an optimizing compiler can simplify contiguous numeric cases. A JS compiler probe showed that a template Map expression rebuilds its table on each lookup, so it was rejected for this control.

Both lanes use an 8 MiB body limit, the same headers and payload bytes, two keep-alive connections, and no pipelining. Native uses `--threads 1 --gpu off`; Bun uses its event loop. No affinity, exclusive-core allocation, or host-frequency control is applied. The host also runs the Python generator and RSS monitor. Route misses and method failures are successful expected 404/405 responses, not errors. Method failure skips ID response encoding.

Direct trials have ten warmup iterations and 10,000 timed iterations, except 4 MiB echo uses 50. Header construction is outside the timer; fresh request/body construction, handler work, response-length/status consumption, and disposal are inside. The JSON body is `{"name":"Cara"}` plus 1,009 spaces; echo bodies repeat octets `7f 80 00 ff`. Large bodies stay packed. Exact socket checks include both echo sizes, authorization/name rejection, canonical IDs, first/last registered IDs, route boundaries, and method errors.

Live rows have three one-second closed-loop trials and three fixed-rate trials. Each connection warms up before a shared start barrier. Fixed rate is 50% of that row's median closed-loop rate and stays identical across its three trials. Fixed-rate latency starts at scheduled arrival, so client lateness and queued arrivals remain visible; missed schedules are not discarded. Completion timestamps precede body/header comparison, but generator work still affects throughput and later arrivals. Trials drain started requests before stopping. Unexpected responses or transport failures abort rather than producing a successful result.

**Measurement limits:** closed-loop concurrency two measures this generator/server pair; it does not establish server or host saturation capacity. Python scheduling, GIL contention, body validation, and local sockets can limit it. Fixed-rate tails are sometimes tens of milliseconds even when closed-loop response times are submillisecond. Do not interpret those tails as isolated server service time. The CPU observations help expose generator pressure but do not prove the client is non-limiting. One-second trials and low sample counts for 4 MiB echo are exploratory evidence, not sustained-load or precise tail guarantees.

`ps` samples direct-process RSS approximately every 100 ms. Server RSS in trial rows is the cumulative observed peak for that profile, not a fresh per-trial peak, a kernel peak, or process-tree memory. Server CPU is sampled cumulative `ps time` with its platform resolution; phase deltas include connection warmup and monitoring boundaries. Client CPU is the Python process delta, including the monitor thread. Direct-process samples can miss short native runs. Startup timing starts after `Popen` returns and ends at a verified HTTP response, so host process-creation overhead is excluded. Servers are host-terminated after client work drains; graceful shutdown is not claimed.

### Construction, build, startup, and memory

Generating the exact registrations took 0.341 ms and produced 29,940 source bytes. Registrations are compiled ahead of runtime; no runtime table-construction latency is invented.

| Observation | Native | Bun/JS |
| --- | ---: | ---: |
| Build wall time | 18.861 s | 8.780 s |
| Artifact size | 2,013,480 bytes | 602,645 bytes |
| Sampled compiler-process peak RSS | 6,985.39 MiB | 4,834.86 MiB |
| Profile 0 post-spawn-to-verified-ready | 4.795 ms | 53.235 ms |
| Route-profile post-spawn-to-verified-ready range | 23.271–25.749 ms | 26.676–29.807 ms |
| Largest sampled server-process RSS | 31.56 MiB | 550.22 MiB |

All 18 workloads passed direct checksum and exact live-response checks in both lanes. All 216 recorded live trials had zero unexpected errors. CPU, all latency percentiles, absolute offered rates, and trial sample counts are retained in `raw_results.json`.

### Chosen comparison policy

- Direct added median cost is at most `min(10 us, max(2 us, 0.20 * raw median))`. The floor tolerates small-call overhead; the cap prevents expensive body work from hiding framework cost.
- Closed-loop expected-response throughput is at least 90% of the paired raw median under the same generator and concurrency.
- Both p95 and p99 are at most `raw median percentile + max(0.25 ms, 0.20 * raw median percentile)`, separately for closed-loop and fixed-rate phases.
- Correctness requires zero unexpected status, header, framing, body, or transport errors. Preserve hook counts and rejection behavior, not only payload lengths.
- Future Camber runs must use the recorded absolute fixed rates, identical payload construction, behavior, limits, headers, connection reuse, client concurrency, and scheduler controls. Run three paired raw/Camber trials and compare medians. Historical fixture timings above are not an equivalent Camber candidate. Re-measure raw controls to detect host drift; do not adjust budgets after seeing Camber results.

N means native. Displayed values are rounded; `raw_budget.json` retains the unrounded limits, including both p95 and p99 for both live phases.

| Workload | Direct raw N / JS (us) | Direct ceiling N / JS (us) | Closed-loop raw N / JS (responses/s) | Throughput floor N / JS (responses/s) | Fixed p99 ceiling N / JS (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| text | 0.466 / 1.237 | 2.466 / 3.237 | 22632 / 6852 | 20369 / 6167 | 34.267 / 13.202 |
| json | 1.021 / 1.524 | 3.021 / 3.524 | 22619 / 7056 | 20357 / 6350 | 32.637 / 1.468 |
| parameter | 1.304 / 4.828 | 3.304 / 6.828 | 22279 / 6784 | 20051 / 6105 | 40.788 / 16.482 |
| json-1k | 12.868 / 79.434 | 15.441 / 89.434 | 21225 / 5441 | 19103 / 4897 | 41.230 / 1.581 |
| hooks-0 | 0.426 / 1.801 | 2.426 / 3.801 | 22168 / 6836 | 19951 / 6153 | 33.702 / 11.926 |
| hooks-1 | 1.716 / 3.881 | 3.716 / 5.881 | 21474 / 6684 | 19327 / 6016 | 34.730 / 19.951 |
| hooks-5 | 5.318 / 11.315 | 7.318 / 13.579 | 20253 / 6424 | 18228 / 5782 | 9.867 / 13.890 |
| hit-10 | 1.715 / 4.885 | 3.715 / 6.885 | 22127 / 6544 | 19914 / 5890 | 2.551 / 1.674 |
| miss-10 | 1.661 / 3.862 | 3.661 / 5.862 | 22032 / 6838 | 19829 / 6154 | 43.184 / 8.051 |
| method-10 | 1.477 / 3.374 | 3.477 / 5.374 | 23068 / 7061 | 20761 / 6355 | 38.763 / 1.713 |
| hit-100 | 1.935 / 5.291 | 3.935 / 7.291 | 22017 / 6646 | 19815 / 5981 | 31.709 / 17.587 |
| miss-100 | 2.249 / 4.053 | 4.249 / 6.053 | 23048 / 6963 | 20743 / 6267 | 35.218 / 28.185 |
| method-100 | 2.238 / 3.709 | 4.238 / 5.709 | 23586 / 6835 | 21228 / 6151 | 31.237 / 24.042 |
| hit-1000 | 2.044 / 8.209 | 4.044 / 10.209 | 23073 / 6558 | 20765 / 5902 | 34.653 / 21.838 |
| miss-1000 | 1.748 / 5.176 | 3.748 / 7.176 | 22618 / 6071 | 20357 / 5464 | 5.808 / 22.743 |
| method-1000 | 2.685 / 5.928 | 4.685 / 7.928 | 22368 / 6727 | 20131 / 6054 | 3.014 / 1.801 |
| echo-64k | 4.198 / 3.980 | 6.198 / 5.980 | 3833 / 976 | 3450 / 878 | 3.095 / 5.165 |
| echo-4m | 297.880 / 222.687 | 307.880 / 232.687 | 84 / 27 | 75 / 24 | 22.806 / 59.856 |

The limits are engineering policy, not requirements silently added to the human-owned SPEC. This control records CPU and memory but does not establish production admission, cancellation, retained-memory bounds, overload recovery, cross-language framework comparisons, or release readiness. Earlier unaffected ownership, surface, and finite-live checks were not rerun.

Reuse, quality, and efficiency checks ran inline under the no-subagent constraint. The control reuses HTTP serving/framing, Router extraction, and the existing ID/name/JSON operations. An unused forwarding helper was removed. The published Time import matches HTTP to avoid duplicate foreign clock symbols. No separate linter is configured for these experiment files. The retained runner compiles and exercises both lanes. The independent-review skip above still applies.

## Paired lifecycle controls

The initial `lifecycle_results.json` retains all 18 workloads in both lanes, including all budget failures. There were 432 live trials with zero unexpected response or transport errors. Direct trials alternated raw/scoped order. The first live experiment grouped controls by profile, so paired observations could be separated by about a minute.

The control uses the same numeric registrations, raw business work, payload construction, transport, and exact responses. The scoped side adds one scope, an affine body-owning input adapter, recovery machinery, and real zero/one/five before callbacks. It has no response transforms, File state, or stage trace. Its response validator checks status only. JSON business validation stays in the raw work. This isolates a minimal lifecycle cost; it does not price the full typed application or the later header guard.

Direct medians are microseconds per request. All native added costs passed the frozen allowances.

| Workload | Native raw / scoped | Bend-on-Bun raw / scoped |
| --- | ---: | ---: |
| text | 0.253 / 0.818 | 1.153 / 2.976 |
| json | 0.264 / 0.807 | 1.472 / 3.358 |
| parameter | 1.358 / 1.922 | 4.841 / 7.070 |
| json-1k | 13.336 / 13.916 | 80.463 / 83.438 |
| hooks-0 | 0.369 / 1.044 | 1.819 / 4.217 |
| hooks-1 | 1.356 / 1.935 | 4.144 / 5.846 |
| hooks-5 | 5.193 / 6.075 | 11.460 / 14.238 |
| hit-10 | 1.661 / 2.232 | 4.923 / 6.731 |
| miss-10 | 1.467 / 2.069 | 3.822 / 5.541 |
| method-10 | 1.510 / 2.064 | 3.356 / 5.069 |
| hit-100 | 1.722 / 2.275 | 5.313 / 7.241 |
| miss-100 | 1.510 / 2.079 | 4.205 / 5.950 |
| method-100 | 1.556 / 2.131 | 3.673 / 5.529 |
| hit-1000 | 1.954 / 2.494 | 8.296 / 11.096 |
| miss-1000 | 1.586 / 2.164 | 5.185 / 7.381 |
| method-1000 | 1.771 / 2.427 | 5.798 / 8.740 |
| echo-64k | 4.301 / 4.859 | 4.049 / 5.958 |
| echo-4m | 263.680 / 261.460 | 226.403 / 253.633 |

Initial JS direct failures: parameter, hooks-0, hooks-5, hit-1000, miss-1000, method-1000, and echo-4m. Native live throughput failed for json, parameter, hooks-0, hooks-1, hooks-5, method-10, and echo-64k. JS live throughput failed for echo-4m. Of the 72 percentile comparisons per lane, 33 failed in native and 15 in JS. No threshold was relaxed.

Native scoped parameter throughput fell across trials while server CPU also fell, and later workloads recovered. This does not establish a cause. Client lateness explains much of several fixed-rate tails: native raw text p99 was 30.361 ms with scheduling lateness p99 30.186 ms; native scoped JSON-1k was 18.956/18.769 ms; JS scoped JSON-1k was 16.804/16.074 ms. Completion latency still includes lateness. It is not subtracted, and it does not explain every closed-loop failure.

The paired builds took 33.287 seconds native and 12.555 seconds JS, with sampled compiler RSS 7,457,392 KiB and 6,212,448 KiB. Direct warmup is 100 iterations, not the historical raw run's ten. Artifacts and every trial remain described in the JSON.

### Tighter recheck

The current runner pairs each workload/trial closely, alternates AB/BA order, and starts only one server at a time. Absolute offered rates and budgets stay frozen. This recheck targets the original live swings and large-body outlier; it is not a new all-18 pass.

```sh
python3 -B camber/run_lifecycle.py --output camber/lifecycle_recheck.json \
  --workload text --workload parameter --workload hooks-0 \
  --workload hooks-5 --workload echo-4m
```

All 120 live trials passed exact responses without unexpected errors. All five native direct, throughput, and percentile gates passed. All five JS throughput gates passed, but parameter, hooks-0, and hooks-5 failed direct added-cost allowances; hooks-0 also failed closed-loop p99.

| Workload | Native added cost (us) | Native throughput ratio | JS added cost (us) | JS throughput ratio |
| --- | ---: | ---: | ---: | ---: |
| text | 0.583 | 0.987 | 1.729 | 0.969 |
| parameter | 0.689 | 1.024 | 2.034 | 0.983 |
| hooks-0 | 0.669 | 0.969 | 2.294 | 0.937 |
| hooks-5 | 0.840 | 0.972 | 2.822 | 1.157 |
| echo-4m | -7.400 | 1.003 | -4.479 | 0.997 |

Negative added costs are measurement variation, not a claimed lifecycle speedup. The 4 MiB JS direct failure did not reproduce; three small-workload failures did. Better pairing substantially changed the live results, so the first profile-blocked run is not defensible as an isolated framework regression. Both datasets are retained. Host/generator limits, short trials, and low large-body sample counts still apply. These are native Bend versus Bend compiled to JS on Bun, not a comparison with `Bun.serve`.

## Scoped application over sockets and final response safety

Run `python3 -B camber/run_surface_live.py`. Both lanes passed all 33 direct scenario contracts through actual HTTP framing, plus four focused scenarios. Exact statuses, bodies, policy/auth headers, chronological stages, actual journal bytes, returned-handle readback, listener close, and natural process exit are checked.

- A same-worker sequence rejects an unauthenticated malformed request, accepts Alice, serves the public sibling, then accepts Bob. Receipts contain owners 7 and 8 exactly once; policy and principal state do not carry into the next request.
- Alice's successful request is deliberately held after its journal write. Bob's malformed request is submitted through a second connection while that write is observable. Alice returns 201, Bob returns 400, and only Alice has a receipt. The single worker returns its affine state.
- After an actual receipt is observable, the client resets the connection before a held response is released. The handler is not replayed, the receipt remains exactly once, the worker returns its handle, and the process exits naturally. The fixture does not expose the response-write outcome, so no observed write-failure notification or cancellation guarantee is claimed.
- An author-owned plain handler echoes every octet, including NUL and invalid UTF-8, at 64 KiB and 4 MiB. A wrong method returns 405 with `Allow: POST`. No receipt is written.

The initial 64-step finite connection probe could not carry a 4 MiB request plus headers: each read accepts at most 65,536 bytes, so 64 reads exhaust fuel before dispatch. This produced a connection reset. The finite probe now allows 512 framing steps; both binary sizes pass in both lanes. It still has a known finite horizon and is not production admission or cancellation policy.

The socket fixture builds took 14.280 seconds native and 2.824 seconds JS, with sampled compiler RSS 4,752,336 KiB and 2,547,952 KiB. Per-scenario sampled RSS and wall times are retained in `surface_live_results.json`; very short runs can evade RSS sampling.

### Confirmed guard defect and regression

The old application validator accepted an unsafe framing header. `response_check.bend` failed before the fix with `unsafe header accepted`. The shared application callback now uses `response.bend` to check status 200–599, nonempty lowercase token names, safe octet values, and framing/connection ownership before handing a response to transport.

It rejects CRLF injection, NUL/other controls, DEL, non-octet code points, uppercase/non-token names, and `content-length`, `transfer-encoding`, `keep-alive`, `upgrade`, `te`, `trailer`, and `proxy-connection`. `connection` values must be exactly `close`. HTAB, token punctuation, obs-text, repeated ordered cookies, and the original packed body are preserved. The checker passed natively and on Bun.

Six added application scenarios inject unsafe values, framing, or names in a root transform, before or after an earlier error mapping. Direct and socket checks confirm one mapper at most, a safe 500 result, no unsafe wire headers, and no replay of a completed journal write. Header checking walks the existing Map tree without building an intermediate field list.

### Authoring assessment

`author_app.bend` adds a plain `Http.Req -> IO(Http.Res)` handler inside existing root/public policies without changing `surface.bend`. This is a same-author exercise, not independent usability evidence. Its small handler still needs explicit template arguments, quantity adapters, scope wrappers, metadata reconstruction, and an application dispatch adapter. The hardcoded route branch is not prepared registration. Reusing the lifecycle works; the intended small public authoring surface is not yet demonstrated.

## Executed prerequisite and cancellation limitations

`prerequisites.bend` prints observations rather than pinning defects as desired behavior. Build it in either lane and pass an owned temporary journal path. `prerequisite_results.json` retains the historical pre-cutover outputs below; [router_prerequisite_results.json](router_prerequisite_results.json) records the corrected routing outputs in both lanes, with JSON rejection still false and a side effect still occurring after the deadline returns.

| Proposed contract | Native and Bend-on-Bun observation |
| --- | --- |
| Preserve double/trailing slash distinctions | `/users//7` and `/users/7/` match collapsed paths |
| Static precedence independent of registration order | Parameter-first registry selects the parameter; static-first selects the static route |
| Reject an unpaired surrogate during parsing | A lone high-surrogate escape is accepted |
| Reject duplicate keys in nested objects | `{"outer":{"id":1,"id":2}}` is accepted |
| Default depth 64 enforced during parsing | A depth-65 array is accepted |
| Deadline cancels pending work | Deadline returns, then the delayed action writes `late` and closes its File |

With a nominal 10 ms timeout, the deadline observation was at 13.850 ms native and 21.913 ms JS; the actual late side effect was at 256.286 ms and 256.930 ms. The journal contains `late` followed by LF after process exit. Timing is measured, not an exact-deadline guarantee. This is the documented behavior of `Conc.timeout`, not a compiler bug or genuine cancellation.

Prepared routing belongs in `router` and now has the implementation and runtime evidence above. Strict surrogate, nested-duplicate, and configurable depth rejection belong in `json` and remain release blockers. Real cancellation still needs runtime support, but the user-approved dedicated-process contract no longer requires it. The historical observations do not claim the full revised SPEC is satisfied.

The final inline reuse/quality/efficiency pass removed unused imports, reused existing socket/effect/scope helpers, and kept body ownership unchanged. The affected direct and socket surfaces and response checker were exercised in both lanes. Unaffected ownership and older finite-live suites were not rerun. No independent review, publication, production deployment, or PR watcher was performed.

The affected HTTP gate was run sequentially with the RSS/deadline guard: `http/http.bend --check-only`, `http/PROOF.bend --check-only`, then `http/check.bend`. Entry/proof checks produced the existing accepted foreign/unsafe dependency report, with no `LAWS` failure; the HTTP runtime checks exited 0. This is the same verdict policy as `scripts/check.sh http`, not a proof of foreign IO.
