# Camber design validation

Date: 2026-10-01. These are experiment findings, not guarantees of an implemented or published Camber package. The proposed local `camber/SPEC.md` is unchanged and excluded from the PR. The experiment is tracked in [PR #315](https://github.com/paymog/bend-kit/pull/315).

## Verdict

The application-layer design fits Bend when reusable configuration and route descriptions are `Data`, execution is supplied through closed templates, and affine resources move through request work explicitly. A copied callback registry does not fit that model. A finite live transport probe now passes runtime context explicitly and reaches the same application dispatch in both lanes. The application behavior contract is coherent, but public interface ergonomics and production transport integration remain unproved.

Native small-request dispatch looks promising in this experiment. Repeated matching with the current router does not scale well. No HTTP throughput, production-safety, or release-overhead claim follows from these measurements.

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

The `/_capacity`, `/_release`, `x-hold`, and `x-order` controls are test instrumentation, not Camber API proposals. Ordinary application routing and typed principal work still use the existing experiment. Shared database consistency, crashes, stuck-handler cancellation, startup failure cleanup, client-pool semantics, full target/method handling, scoped transforms, and mapper recovery remain unproved. No production HTTP entry point, package version, or human-owned law changed.

The final live runner build observed 17.806 seconds and 5,254.45 MiB sampled compiler-process RSS for native, and 3.743 seconds and 2,920.83 MiB for JS. A preceding native build sampled 5,537.06 MiB. These are compilation observations, not request costs or total process-tree memory. Builds and server processes run sequentially with host deadlines and a 20 GiB RSS ceiling.

The existing affected-package gate, `scripts/check.sh http`, also exited 0. It ran the entry check, existing proof gate, and HTTP checks. Its expected unsafe/foreign dependency report is accepted by the repository's existing verdict wrapper; this is not a claim that host IO has a formal proof. The gate was monitored with a 180-second deadline and a 20 GiB process-group RSS ceiling.


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

The original ownership fixture's generic decoder restricts input to `Data`. Do not infer that all valid typed request models are copyable: Bytes, Json.Val, and records containing affine fields are `Type`. The final decoder design must account for those models or state a deliberate restriction. The plain-handler probe establishes an affine raw-body path, not a general affine typed-decoder interface.

General group inheritance, response-transform unwind, completion notifications, single-pass mapper recovery, response validation, strict target parsing, and prepared route registration are not implemented by these probes.

## Will agents be able to use it?

The design has useful properties for agents: inspectable static descriptions, explicit resource flow, typed hook transitions, deterministic rejection, compiler feedback, and a port-free execution path. A complete small example gives an agent a pattern to copy rather than an invitation to invent ownership rules.

That is a design assessment, not a measured agent-usability result. No subagents or independent application-writing agents were used. These probes were authored and checked in the same session. They do not measure how reliably another agent can add a route, choose quantities, interpret errors, or maintain an application without editing framework internals.

Before release, demonstrate an application change through the intended public interface: add a route with an affine typed input, attach a typed authentication hook, map an expected error, and verify it through direct dispatch. The author should not need the worker protocol or HTTP framing implementation to do that.

## Next work

1. **Test the intended public application surface.** Hide the now-tested worker protocol, demonstrate affine typed input as well as copyable models, and exercise scoped hooks and error mapping. Independent-agent usability still needs a separate trial when that is permitted.
2. **Review the bundled acquisition contract.** Worker-owned Store/File bundles now demonstrate progress, exhaustion rejection, return on failures, capacity reporting, and orderly close. Decide whether this resource grouping fits real application dependencies; keep pools distinct from checked-out connections. Do not freeze signatures or amend the human-owned spec from this experiment alone.
3. **Integrate the tested context seam into production transport.** The finite HTTP probe proves the explicit runtime-context mechanism, not a new public serving API. Production lifecycle, admission, write outcomes, and cancellation still need their own evidence. Gate 1 also needs an equivalent raw HTTP baseline and a recorded overhead budget.
4. **Then implement the prepared router and strict JSON prerequisites.** Preserve the spec's route semantics. Establish actual framework and transport measurements before claiming performance. Runtime cancellation remains an independent release blocker.

Do not broaden the initial feature set. The next work is making the existing ownership and application contract implementable and usable, not adding plugins, schema generators, or streaming.
