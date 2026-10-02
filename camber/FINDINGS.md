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

The `/_capacity`, `/_release`, `x-hold`, and `x-order` controls are test instrumentation, not Camber API proposals. Ordinary application routing and typed principal work still use the existing experiment. Shared database consistency, crashes, stuck-handler cancellation, startup failure cleanup, client-pool semantics, and full target/method handling remain unproved. Scoped transforms and mapper recovery are checked separately by the direct surface probe below, not by this live fixture. No production HTTP entry point, package version, or human-owned law changed.

The final live runner build observed 17.806 seconds and 5,254.45 MiB sampled compiler-process RSS for native, and 3.743 seconds and 2,920.83 MiB for JS. A preceding native build sampled 5,537.06 MiB. These are compilation observations, not request costs or total process-tree memory. Builds and server processes run sequentially with host deadlines and a 20 GiB RSS ceiling.

The existing affected-package gate, `scripts/check.sh http`, also exited 0. It ran the entry check, existing proof gate, and HTTP checks. Its expected unsafe/foreign dependency report is accepted by the repository's existing verdict wrapper; this is not a claim that host IO has a formal proof. The gate was monitored with a 180-second deadline and a 20 GiB process-group RSS ceiling.


## Direct application-author surface

Run `python3 -B camber/run_surface.py`. All 27 scenarios passed in native and Bun/JS. The final builds took 6.192 seconds and 2.268 seconds, with sampled compiler-process RSS of 3,001.78 MiB and 2,010.14 MiB respectively. The runner reuses the existing host deadline and 20 GiB RSS guard and runs one build or executable at a time.

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

The new dispatcher reuses `Registry.choose` and the existing pairwise router. The earlier live fixture still uses `Registry.invoke`; it does not exercise this new lifecycle. These 27 scenarios are direct-dispatch evidence only. Full header/framing response validation, RFC 9457 defaults, completion notifications, strict JSON depth/surrogate behavior, prepared routing, live integration, cancellation, and production lifecycle remain outside this result. The status-only guard is not the full R5.7 response validator.

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

Scope inheritance, transform unwind, and single-pass mapper recovery now have direct fixture evidence. General group construction, completion notifications, full response validation, strict target parsing, and prepared route registration remain unimplemented by these probes.

## Will agents be able to use it?

The design has useful properties for agents: inspectable static descriptions, explicit resource flow, typed hook transitions, deterministic rejection, compiler feedback, and a port-free execution path. A complete small example gives an agent a pattern to copy rather than an invitation to invent ownership rules.

That is a design assessment, not a measured agent-usability result. No subagents or independent application-writing agents were used. These probes were authored and checked in the same session. They do not measure how reliably another agent can add a route, choose quantities, interpret errors, or maintain an application without editing framework internals.

The direct surface example now demonstrates an affine typed route, typed authentication, and expected-error mapping without worker or framing code. Before release, an independent author must exercise the intended public interface rather than these provisional primitives.

## Next work

1. **Measure Camber against the raw HTTP control.** The raw native/JS measurements and pre-Camber budgets below are recorded. Apply the same workloads to the scoped application lifecycle before claiming its overhead passes. Final surface design and independent-agent usability still need validation; no public signature is fixed.
2. **Review the bundled acquisition contract.** Worker-owned Store/File bundles now demonstrate progress, exhaustion rejection, return on failures, capacity reporting, and orderly close. Decide whether this resource grouping fits real application dependencies; keep pools distinct from checked-out connections. Do not freeze signatures or amend the human-owned spec from this experiment alone.
3. **Integrate the tested context seam and lifecycle into production transport.** The finite HTTP probe proves the explicit runtime-context mechanism, not a new public serving API. Connect the separately tested application lifecycle before claiming it works over sockets. Production admission, write outcomes, shutdown, and cancellation still need their own evidence.
4. **Then implement the prepared router and strict JSON prerequisites.** Preserve the spec's route semantics. Establish actual framework and transport measurements before claiming performance. Runtime cancellation remains an independent release blocker.

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
