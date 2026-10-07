# Complete public-application benchmark

This harness consumes published Camber0.6.0.0, HTTP0.30.0.0, Router0.2.0.0 and Json0.5.1.0. `public_main.bend` uses the public Camber application/dispatcher and `server.start`/`server.run`; it does not import an experimental dispatcher or implement another production transport. The raw control prepares the same registered routes through published Router and serves the same business callbacks through published HTTP, without the Camber dispatcher, application owner, response guard or notices. Both controls use identical explicit transport limits, payloads, synthetic authorization and CPU work. The separate loopback control listener releases measured work and requests stop; never expose it.

## Frozen criteria

[`public_criteria.json`](public_criteria.json) was written before any measurement of these consumers. It references, rather than replaces, all18 historical native/JS numeric budgets in [`../raw_budget.json`](../raw_budget.json). Existing experiments, frozen failures and artifacts are untouched. Native-default uses the native historical budgets. New paired overhead gates and historical absolute gates are reported separately; neither excuses failure of the other. Rates are the original per-workload rates, not rates selected after seeing Camber results.

The retained-memory envelope is4096MiB; each30s overload interval has a10s steady window with at most64MiB sampled variation. Three load/reduction cycles run in the same PID, with64 offered connections against32 sockets/16 handlers/16 buffered reservations. Ten seconds after reduction, retained RSS must be within128MiB of initial RSS;100 recovery requests must have zero errors and p99<=100ms. Structural reservations are not a runtime RSS proof. Workload bodies use an explicit8MiB cap, including64KiB/4MiB packed echoes; JSON overlap uses1MiB inputs at depth64 and admitted concurrency1/16. Yielding work sleeps500ms; serial runtime-seeded arithmetic executes512 million native or128 million JS iterations. Actual HTTP header deadlines are200ms; delivery must be<=300ms, ordinary latency<=100ms and recovery<=100ms. A guard abort is FAIL/INCONCLUSIVE, never a passing plateau or cancellation result.

The original16-permit overlap trials remain unchanged and retain real ordinary/timeout capacity rejections. Additional, explicitly separate headroom trials use18 active requests,18 buffered reservations and18 application bundles for16 work operations plus ordinary and timeout probes. They do not replace the original capacity configuration or relax its budgets.

## Implementations and parity

- Bend raw and complete Camber, separately native single CPU thread, native default CPU threads (GPU off) and generated JavaScript on Bun.
- C libevent HTTP with json-c parsing; no C framework layer.
- Rust axum on current-thread Tokio, with separate actual middleware layers for hooks.
- Python Flask under production Waitress, one execution worker, with separate before-request callbacks.
- JavaScript Node HTTP, Fastify and Hono on Node; Elysia on Bun, with actual framework hooks/middleware.

Elysia uses the public `sucrose.gcTime: 0` constructor option to reclaim its compilation cache immediately, rather than leaving the pinned default's referenced295-second timer alive after server stop. This is an explicit comparator lifecycle distinction, not a request-deadline or numeric-budget change. The [diagnostic receipts](public_elysia_diagnostic.json) preserve both unsuccessful shutdown hypotheses and the actual immediate timer creation/execution followed by natural process exit; printing JOINED alone is not release proof.

Every shared fixture requires matching status, required application headers, Content-Length and complete body SHA-256. The runner checks every received response during measured loads, not merely before/after measurement. Fixed text/JSON, parameters,1KiB JSON decode/name validation,0/1/5 hooks, last hit/miss/method failure at10/100/1000 registered routes, and64KiB/4MiB binary echoes are measured. Expected404/405 are successful responses. Untimed direct parity traverses the same dispatch path as the timed loops, writes the complete packed body through published Files0.1.1.0, closes the actual File and verifies all bytes and required headers. Timed direct loops consume identical status+length checksums in both lanes. Construction/startup, build wall time, binary/source sizes and hashes, successful responses/s, p50/p95/p99, errors, CPU and sampled RSS are recorded. Numeric paired ceilings are derived from actual raw trials, persisted before corresponding Camber measurements, and subsequently read from that frozen ledger.

Semantic differences are intentional and disclosed: only the shared corpus attests equivalence. The C control registers actual literal routes with libevent and uses its generic callback for parameter selection and misses, not a parameter-routing framework. JSON duplicate-key/depth, Unicode length, target normalization, generated OPTIONS/HEAD and malicious framing policies are not declared equivalent outside that corpus. Camber and raw use the same production admission/deadline owner; comparators retain their idiomatic transport policies, not a hand-reimplementation of Bend admission. Hono/Fastify/Elysia route methods are registered together to produce the shared405 oracle. Framework notifications are disabled consistently. C json-c counts UTF-8 bytes for name length, whereas the other consumers count characters; the shared name fixture is ASCII. libevent moves the echo input buffer into its output; axum moves owned Bytes into Body without a4MiB Vec copy. No comparator is a production security or lifecycle conformance oracle.

## C prerequisite pin

The recorded C comparator uses libevent2.1.12-stable and json-c0.19. When json-c is missing, prepare it in the owned scratch prefix, not through a global package install. Fetch [json-c0.19](https://s3.amazonaws.com/json-c_releases/releases/json-c-0.19.tar.gz) and verify SHA-256 `37ad0249902e301bd9052bf712e511fcc6acff4ecaad4b5900aad9ce564e26de` **before** extraction. The archive is462232 bytes in the recorded prerequisite attempt.

Use `json-c-src`, `json-c-build` and `json-c-prefix` beneath `/tmp/camber-340-owned`. Configure CMake with `-DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_INSTALL_PREFIX=/tmp/camber-340-owned/json-c-prefix -DCMAKE_INSTALL_LIBDIR=lib`; build with `--parallel 1`, then install. Every download/extract/configure/build/install command must run serially through the existing `Guard`/`command` receipt mechanics under an explicit grant. [`public_prerequisite_results.json`](public_prerequisite_results.json) preserves the exact recipe, verified archive hash, natural root/descendant release and installed artifact inventories. The recorded build used CMake4.4.2.

For the granted build process only, prepend `/tmp/camber-340-owned/json-c-prefix/lib/pkgconfig` to `PKG_CONFIG_PATH`, retaining any prior value. No host configuration change is needed; the normal build records the actual pkg-config version and links the owned static library.

## Running, only with an exclusive grant

The runner refuses execution without `CAMBER_RUNTIME_SLOT=340`; setting it requires coordinator authorization, not merely shell access. Run exactly one runner and one Bend program at a time. It samples the actual process roots and their descendants plus the Python load generator at100ms intervals, refuses to start below10GiB disk headroom and kills above20GiB aggregate RSS. Every forced stop remains adverse evidence. The root process owner waits/reaps its process. No platform-supervised service is launched by this harness.

Smallest native smoke (no installs or comparator builds):

```sh
CAMBER_RUNTIME_SLOT=340 python3 -B camber/bench/run_public.py \
  --phase bend-smoke --scratch /tmp/camber-340-owned \
  --output camber/bench/public_smoke_results.json
```

It builds only `public_main.bend`, starts raw then Camber sequentially, checks fixed-text sockets, runs tiny paired load cells and requests actual stop/drain/join. The smoke is not the release matrix and cannot receive an overall release PASS.

After source review and additional grants, `--phase build` prepares the native/JS server and direct consumers, C/Rust binaries and benchmark-only JS/Python dependencies. `--phase measure`, `--phase overload` and `--phase overlap` reuse those prepared artifacts, verify their hashes and exact source snapshot, and write separate source-bound evidence. `--phase full` builds and performs the complete matrix in one invocation. Reusing an evidence filename appends an attempt rather than erasing earlier failures; separate filenames are also supported. Package checks/publication previews belong to the coordinator's separate affected-package grant; no manual publishing and no VERSION bump for these consumer-only additions.

The optional `--measure-implementation elysia` selects only Elysia's live matrix; it still runs every direct raw/Camber workload in all three execution lanes. Without the option, the complete13-implementation live matrix remains the default. Selected scope is recorded in the receipt. A continuation does not reattribute previous measurements to its new source hashes: the [lossless original measure evidence](public_measure_results.json.gz), [compression identity](public_evidence_compression.json) and [compact derived facts](public_measure_summary.json) preserve the original twelve implementations and their failures under the original source/artifact bindings.

Trials use1s warmup and three5s measured repetitions,2-connection budget controls,16-connection closed-loop pressure and fixed offered rates with scheduled-arrival-corrected client latency. Warmup rows and errors are retained. Throughput divides actual successful responses by the actual first-offer-to-final-response interval, including drain; within-window and drained completions are reported separately. The bounded Python asyncio client records offered arrivals, client queue drops, full-body checksum counts and actual response errors. A client-limited fixed-rate row is FAIL/INCONCLUSIVE, not server capacity. Closed-loop pressure is not proof that the host or server alone saturates; interpret CPU and generator drops together. These are loopback measurements without CPU affinity, a non-limiting-generator claim or throughput promises.

Corrected overload timing records the actual last offer and producer finish before waiting for outstanding responses. An independent task schedules the retention checkpoint and real recovery requests at actual offer-end plus 10 seconds while the original pressure task drains normally. Only an actual monitor observation at or before that boundary can satisfy the retained-RSS gate; its timestamp and age are recorded. Current RSS, checkpoint/recovery scheduling lateness, and final drain completion are separate observations. The original post-drain timing attempt remains adverse historical evidence.

`--overlap-completed camber/bench/public_overlap_results.json` skips only the original receipt's 12 completed, validated scenario identities. The active aborted CPU/16-permit trial is retried, and all 150 remaining identities are recorded with their new source binding. Without this option, overlap runs all 162 trials. The timeout probe collects actual chunks under one 120-second read budget. Reset, partial response, EOF without a complete response, capacity rejection, or a late 408 cannot become timeout PASS.

Overlap arms all admitted work behind real channels before releasing it. An incomplete ordinary HTTP request arms the actual production header deadline; release and ordinary-request tasks run concurrently, never waiting for the CPU response before starting the progress request. Unique work IDs pair internal BEGIN/END intervals; an internal ORDINARY marker proves whether the actual ordinary handler ran during at least one matched work interval. Ordinary probes require full text/header/body parity. Client times and buffered host log receipts remain separate diagnostics, never handler-progress proof or an assumed cross-runtime clock alignment. Short controls that finish before the ordinary handler runs are explicit failures/inconclusive overlap evidence. Capacity503 is neither ordinary progress nor an admitted timeout. Timeout408/EOF and same-process recovery are actual peer observations, not a timer race or an external kill.

The failed gates do not establish one common cause. Direct overhead exceeds the frozen ceilings on both native and JavaScript; native erasure limitations (`bendlang/bend#1307`) cannot explain every result. No complete scheduler-isolation or bounded-retention guarantee is claimed. Published HTTP/Wire/clock effects and the C/other comparator runtimes include unsafe or foreign operations that remain host trust assumptions. Human LAWS.bend is unchanged; these measurements do not prove IO, deadlines, memory, buffering, cleanup, or cancellation.

## Evidence and release

No results are claimed until real source-bound rows exist. Each output contains an `attempts` array preserving prior attempts, including source-bound command failures and guard aborts. Attempts store consumer/runner/criteria hashes, exact commands/runtime versions, dependency manifests, build receipts, statuses/checksums, warmups, frozen numeric ceilings, guard samples, internal/host timestamps, exact observed PID-start identities, natural exit, reader release and actual main/control listener rebind receipts. Cleanup continues after monitor or constructor failure; forced cleanup does not become a natural success. The owned scratch directory retains prepared artifacts for the next explicitly granted stage and must be removed, with no survivors/listeners, before shipping. No compatibility alias, alternate transport, resource-handle erasure or handler replay is used.

Evidence writes flush/fsync an owned temporary file before atomic replacement; interrupted writes cannot truncate prior attempts. The initial attempt and pre-start command are saved before the first process starts, running receipts carry the actual PID, and finalization updates the same receipt. Warmup failures remain adverse and prohibit full PASS. Each cleanup owner, reader and listener is attempted independently; cleanup/receipt-write errors are retained and cannot skip the final adverse-save attempt.

## Recorded outcomes

The aggregate verdict is **FAIL/INCONCLUSIVE**. The complete application corpus passes the untimed response-equivalence checks, but several frozen acceptance criteria fail. CLI exit 0 and natural cleanup are execution evidence, not a pass of those criteria. Initial release accepts this verdict as the operating boundary. It does not turn these failed criteria into PASS.

| Matrix or gate | Actual coverage and outcome | Evidence |
| --- | --- | --- |
| Live applications | 13 implementations × 18 workloads: 234 successful parity checks, 234 passing warmups, and 2,106 trial rows (1,433 PASS; 673 FAIL/INCONCLUSIVE) | [Complete measurement summary](public_complete_measure_summary.json) |
| Direct dispatch | Three execution lanes × 18 workloads × raw/Camber: 108 complete-byte/header parity checks pass; all 324 timed trials complete | [Remaining measurement receipt](public_remaining_measure_results.json) |
| Paired performance | 216 gates: 20 pass, 196 fail; all 54 direct overhead gates fail | [Gate and timing summary](public_complete_measure_summary.json) |
| Historical absolute budgets | 216 gates: 28 pass, 188 fail; all 54 direct ceilings fail | [Original numeric budgets](../raw_budget.json), [gate summary](public_complete_measure_summary.json) |
| Corrected sustained overload | Six raw/Camber variants × three workloads × three same-PID cycles: all 54 overall scenarios fail | [Timed overload receipt](public_overload_timed_results.json), [summary](public_overload_timed_summary.json) |
| Overlap with original 16 permits | 108 trials: 9 PASS, 99 FAIL/INCONCLUSIVE | [Overlap summary](public_overlap_summary.json) |
| Separate 18-permit headroom | 54 trials: 9 PASS, 45 FAIL/INCONCLUSIVE | [Overlap summary](public_overlap_summary.json) |

For example, native-single fixed-text direct medians are 2.0513 µs raw and 85.2657 µs Camber, against a frozen paired ceiling of 4.0513 µs and an unchanged historical ceiling of 2.4659 µs. No threshold, fixture, required header, dependency pin, or library entry was changed to pass these gates. Fixed-rate generator drops and transport errors remain adverse rows and do not establish server capacity.

All 54 corrected overload trials have actual at/before-boundary RSS observations. Their age before offer-end plus 10 seconds ranges from 2.5 to 140.6 ms. The sampled envelope passes in 54 trials, steady variation in 52, on-time retained RSS in 24 (30 fail), and the 100-request recovery criterion in 54. Overall overload still fails in every trial because pressure errors and other criteria remain adverse. Checkpoint scheduling is 0.34 to 1.47 ms late; separate current-RSS observations are 26.2 to 51.4 ms late, and actual recovery starts are 50.6 to 78.0 ms late. Favorable later RSS never substitutes for on-time evidence.

The composed overlap matrix contains 162 unique trial identities: 18 PASS and 144 FAIL/INCONCLUSIVE. Every admitted work-response oracle and recovery latency check passes. Ordinary response parity passes in 126 trials; the actual ordinary handler runs inside a matched internal BEGIN/END work interval in only 18. Of 108 complete 408 responses, 45 arrive within 300 ms. The corrected continuation also preserves 25 reset errors and 26 incomplete/empty EOF outcomes. Buffered host receipt overlap is never used as handler-progress proof.

### Source attribution

Each receipt retains its executed source and prepared-artifact bindings. Summaries compose those receipts without assigning old rows to a new whole-file hash.

| Executed stage | Runner SHA-256 prefix | Source-bound evidence |
| --- | --- | --- |
| First 12 live implementations | `b1a9a41a5f7a` | [Lossless original receipt](public_measure_results.json.gz) |
| Elysia live matrix and complete direct matrix | `d4b02524bd1e` | [Remaining measurement receipt](public_remaining_measure_results.json) |
| Original post-drain overload attempt | `d4b02524bd1e` | [Historical overload receipt](public_overload_results.json) |
| Corrected offer-boundary overload | `f53e1219191d` | [Timed overload receipt](public_overload_timed_results.json) |
| First 12 overlap trials and aborted trial | `f53e1219191d` | [Original overlap receipt](public_overlap_results.json) |
| Remaining 150 overlap trials | `0bcad635c5ed` | [Overlap continuation](public_overlap_remaining_results.json) |

Node HTTP, Fastify, and Hono ran the original comparator file (`aa08c62324b5…`). Only the Elysia branch changed afterward: static-route parameter access and the public immediate-cache-reclamation constructor setting. Their previously executed branches are unchanged; their rows still carry the original whole-file hash. Native/JS Bend and C/Rust artifacts and resolved dependency receipts were preserved through every manifest-only rebind.

### Preserved failures and shipping identity

The [native smoke history](public_smoke_results.json) retains seven compiler failures and the later narrow successful text smoke, including its fixed-rate drops. The [three build attempts](public_build_results.json) retain the missing json-c prerequisite and direct-consumer ownership error before the successful build. The [owned json-c prerequisite](public_prerequisite_results.json) records the exact archive pin and natural release.

The original Elysia text 500 and forced `-9` release remain in the compressed first measurement receipt. The [lifecycle diagnostics](public_elysia_diagnostic.json) retain two further forced releases that disproved missing-await and signal-listener hypotheses, followed by actual immediate cache-timer execution and natural exit. The [client-abort smoke](public_load_cancel_smoke.json) records a genuine full queue/live TCP peer, propagated CancelledError, joined owned workers, closed client descriptor, and natural server/control/listener release. Its aborted load remains FAIL/INCONCLUSIVE; cleanup proof is separate. The cancellation hazard was identified from code, not an observed historical hang.

The original [54 post-drain overload failures](public_overload_results.json) and the [12-row overlap attempt plus reset abort](public_overlap_results.json) are not rewritten. Their corrected continuations preserve new timing/error evidence separately. No historical failure, forced cleanup, or missing observation becomes PASS.

The first measurement JSON is 839,479,792 bytes and is excluded from shipping. Its lossless gzip is 33,741,857 bytes. [Compression identity and natural-reap receipts](public_evidence_compression.json) verify the decompressed bytes exactly:

| Artifact | SHA-256 |
| --- | --- |
| Original/decompressed JSON | `ac54c05d1bf6d8d9c89f9ab4431a0ccf4c67d1d07aa05828e34bbecc546e1953` |
| Gzip | `7e5802abe61c4ad07e62454448172e0121fcd541e2567dc7476fb4a66b96ca21` |

Ship the gzip, exact identity, compact summaries, and remaining source-bound receipts. Owned scratch artifacts, temporary fixture output, diagnostic drivers, and the original uncompressed JSON are excluded. Their authorized deletion was denied by the filesystem guard, as recorded below; no alternative deletion mechanism was attempted. Package checks, publication verification, source acceptance, and shipping authorization belong to the coordinator.

### Affected-package gate

The coordinator-authorized [Camber gate receipt](public_gate_results.json) records `bash scripts/check.sh camber` and then `bash scripts/publish.sh --check camber`, both exit 0 with natural root/descendant release. The package check retains the full output reporting 331 unsafe/foreign-dependent definitions under the existing exclusion policy; the preserved human LAWS.bend contains no supplied laws. This accepted exclusion policy is not host-IO proof. Publication validation reports the existing `bend-kit-camber@0.6.0.0` on the hub and compares its published files; it does not publish or bump a version.

All 14 benchmark source hashes and the package gate input hashes are unchanged before/after the attempt. Peak sampled aggregate RSS is 4,815,072 KiB, with no guard failure, forced cleanup, cleanup error, or surviving tracked root. These package/publication checks do not change the failed frozen performance, overload, or overlap verdicts above.

### Cleanup verification and filesystem blocker

The [cleanup receipt](public_cleanup_results.json) records successful authorized pre-deletion verification: exact gzip SHA-256, streamed decompressed length and SHA-256, and the current original JSON hash all match the lossless identity above. The 967 retained PID-start identities have no live matches; the actual owned-program census is empty, and actual scratch descriptor/reader enumeration finds no open descriptors. The complete actual TCP listener census is retained separately. Peak sampled aggregate RSS is 45,504 KiB, with natural verifier/helper release and no resource-guard or cleanup error.

Only the authorized command `rm -r /tmp/camber-340-owned /Users/paymahn/code/bend-kit-issue-340/camber/bench/public_measure_results.json` was requested. The filesystem guard rejected it before launch:

```text
recursive rm targeting a root, home, or absolute system path is EXTREMELY DANGEROUS, even without --force.

Rule: core.filesystem:rm-recursive-root-home
```

The owned scratch root, temporary drivers and 4 MiB fixture, and original 839,479,792-byte JSON still exist. The verified gzip remains intact. No relative-path alias, Python deletion, alternate mechanism, or guard bypass was attempted. The removal monitor joined without observing a launched removal process. This is a recorded cleanup blocker, not successful artifact deletion; all retained temporary/raw paths stay outside the shipping inventory.
