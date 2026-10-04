# Dedicated users deployment (macOS launchd)

This consumer imports the final four-route `../users.bend` application and published Camber 0.6.0.0 / HTTP 0.30.0.0. `users_demo.bend` supplies existing owner-result checks, not a second dispatcher or transport. Both lanes run as **launchd-owned dedicated processes**, not Python-owned Bend children. The historical `../run_supervision.py` and its risk artifacts remain historical only.

## Build and install

From the repository root, build **one lane at a time**:

```sh
bend camber/deploy/users.bend -o /opt/camber/users
bend camber/deploy/users.bend -o /opt/camber/users.js
# JS only: install the SAME native signal source adjacent to users.js.
sudo install -o root -g wheel -m 0444 camber/deploy/signals.c /opt/camber/signals.c
```

Provision a dedicated unprivileged `camber` account, `/var/lib/camber` and `/var/log/camber` owned by that account with mode 0700. Install the selected `users.plist` or `users-js.plist` root-owned, mode 0644 under `/Library/LaunchDaemons/`. Install immutable/root-owned binaries and a pinned Bun at `/opt/camber/bin/bun`; the service account must not be able to change its executable or launch configuration. The journal is a demonstrator's owned file and in-memory user store, **not persistent database storage**. Do not run both plists against the same ports.

The supported JS host is pinned Bun 1.3.14 on the recorded macOS arm64 host, with native FFI and experimental `bun:ffi cc` enabled. Do not pass `--no-ffi-cc` or `--no-addons`; missing/disabled FFI, missing source or native compilation failure is a startup failure, not a fallback to a JavaScript signal callback. The service account must not be able to modify `/opt/camber/signals.c` **or its parent directory**. At startup TinyCC compiles that exact adjacent source with `CAMBER_SIGNAL_HOST=1`, excluding only Bend-specific effect wrappers. Both lanes use the same C signal handler and flag; the native image is retained until process death because the installed handler points into it. No extra dylib provisioning or cross-platform support is claimed. See [Bun's C compiler requirements](https://bun.sh/docs/runtime/c-compiler).

```sh
sudo launchctl bootstrap system /Library/LaunchDaemons/org.bend-kit.camber.users.plist
# JS alternative, not in addition:
sudo launchctl bootstrap system /Library/LaunchDaemons/org.bend-kit.camber.users-js.plist
sudo launchctl print system/org.bend-kit.camber.users
```

Native `ProgramArguments` execute `/opt/camber/users --threads 1 --gpu off 19441 19442 /var/lib/camber/journal`; JS executes `/opt/camber/bin/bun /opt/camber/users.js 19441 19442 /var/lib/camber/journal`. Neither lane passes credentials in argv. The final optional acceptance-mode argument is omitted in deployment; `cooperative`, `cpu`, `io`, and `tls-proof` are deliberate verification fixtures, not public routes. The blocking IO fixture retains a real TCP Socket while receiving from a private loopback peer; the CPU fixture intentionally does not yield.

## Stop and observe

The supported platform stop trigger is `launchctl stop LABEL`, executed in the service's bootstrap context (root selects the system domain). With `KeepAlive=false`, no demand endpoints and `ExitTimeOut=5`, launchd sends SIGTERM, allows five seconds, then sends SIGKILL if the dedicated process remains. Both lanes' same C signal handler sets a `sig_atomic_t` flag using only async-signal-safe logging. A yielding Bend watcher reads that flag and translates it into the **real published application and administrative server stop controls**. Serial CPU work can starve the watcher; the platform remains outside that runtime. The JS twin does not rely on Bun dispatching a host signal callback during live Bend IO.

```sh
sudo launchctl stop org.bend-kit.camber.users
sudo launchctl list org.bend-kit.camber.users
sudo launchctl print system/org.bend-kit.camber.users
sudo launchctl bootout system/org.bend-kit.camber.users
# Use the users-js label in all three commands for JS.
```

The owner log records stop-control acceptance, request completion, application owner completion, transport owner completion, `STORE CLOSED` **after actual File.close**, store-owner join and administrative-owner completion. `NATURAL EXIT READY` is only a program marker; the kernel exit event and launchd's last exit status must separately prove natural exit. SIGTERM receipt or a five-second timer is never process-exit proof. The verification runner uses kernel `NOTE_EXIT`, then separately observes the PID absent from `ps` (not a zombie), and reads launchd's last exit status. `launchctl print/list` output is diagnostic and not a stable API; the runner is scoped to the recorded macOS host.

There is also a private loopback-only administrative `POST http://127.0.0.1:19442/stop`. It requests the same stop controls, but **does not arm launchd's deadline**: use the platform stop trigger for bounded shutdown. It trusts local processes, is not production authentication, and must never be exposed, tunnelled or proxied. On a multi-user/untrusted-local-process machine isolate the account/network namespace or do not deploy this local-trust demo.

The frozen acceptance budget is five seconds grace plus one second for actual forced exit, reap and peer closure. `ExitTimeOut` is a signal escalation setting, not a kernel scheduling/reaping guarantee: a budget violation is an adverse failure, not silently relaxed. Forced termination may skip affine cleanup and completion notifications, cannot undo external side effects, and is not hard runtime cancellation. No automatic replay, rollback, descendant-cleanup guarantee or preserved in-process work is claimed.

## TLS and secure logging

Render `nginx.conf`'s `@STATE@` to an operator-owned private directory (the supplied proxy plist uses `/var/lib/camber/proxy`). Install the real certificate and key there; key mode 0600. Install a pinned nginx as `/opt/camber/bin/nginx`. The proxy plist runs nginx in foreground under launchd. The supplied TLS configuration listens only on loopback 19444 for local verification; for a public deployment explicitly replace `listen` and `server_name`, provision a trusted certificate and restrict firewall ingress to the TLS port. **Do not publish plaintext 19441 or administrative 19442.** There is no plaintext redirect listener that could first receive bearer credentials.

```sh
/opt/camber/bin/nginx -t -p /var/lib/camber/proxy/ -c /var/lib/camber/proxy/nginx.conf
sudo launchctl bootstrap system /Library/LaunchDaemons/org.bend-kit.camber.tls.plist
sudo launchctl stop org.bend-kit.camber.tls
sudo launchctl bootout system/org.bend-kit.camber.tls
```

The proxy forwards to the loopback application, never the admin port. `proxy_pass` has **no URI suffix**, no rewrites and no path-based authorization; `merge_slashes off` avoids collapsing slashes. Public authorization belongs in the existing Camber group. `proxy_next_upstream off` prevents upstream handler replay. Verification sends raw origin-form targets on a TLS socket: a test-only root-hook equality oracle compares the exact received target to the test-supplied expected bytes and emits only a fixed marker. Distinct percent encodings, query bytes and unmatched slash/dot paths are checked before decoding; application 404 separately verifies routing. Marker totals are observed only after actual owner/process exit because physical host logs can lag peer-visible response writes. This test header/oracle is inactive without explicit `tls-proof` mode.

The example accepts only demonstration `seven`/`eight` bearer credentials and seeds demonstration users. **This is neither a production authentication product nor a production credential/trust claim.** Replace the application-supplied demo auth/store for real deployment; do not confuse TLS transport proof with auth security.

Application tracing and access logging are disabled in ordinary deployment. Owner logs contain fixed lifecycle/error categories only; never enable demo fault tracing as production logging. No bodies, query strings, credentials, sensitive headers or internal diagnostics belong in default logs. Proxy logging has a separate posture: access logs are off and error logs go to `/dev/null` because nginx errors can include request targets. Enabling either requires an explicitly reviewed/redacted projection, private permissions and retention policy. Core dumps are disabled. Startup/config diagnostics also require private handling. Test-only equality mismatches disclose only a fixed error, not target bytes.

## Guarded operation evidence

Run only with an exclusive local-runtime slot, at least 10 GiB free disk, and no other Bend programs. The runner monitors aggregate RSS across its own root **and actual launchd job roots and their descendants**, failing and killing above 20 GiB. Passing cases may not use safety kills or forced cleanup. It unregisters every owned job, closes all peers/listeners/kqueues, verifies all four ports refused, and removes only its private temporary directory. Builds, services and matrix cases are sequential.

```sh
python3 camber/deploy/run.py --lane native --case cooperative --output camber/deploy/native-cooperative.json
python3 camber/deploy/run.py --lane all --case all
```

The JSON output is a cumulative `invocations` history: each retry appends, never overwrites earlier failed/adverse attempts. Command receipts persist before startup and after nonzero exits, timeouts and cleanup failures; cases persist before bootstrap. PID plus `lstart` identities follow the existing serving-runner pattern, including observed compiler descendants. Safety/timeout cleanup makes the invocation fail even when every process is subsequently reaped. Cleanup skips a prior guard failure but never the disk prerequisite; unavailable release/observation is recorded as failure, not zero survivors. A private temporary tree is preserved for recovery when owned jobs or observed descendants cannot be verified released.

Each invocation records runtime-consumed source/config SHA-256 (documentation and output JSON are not executable inputs), rendered configuration, platform PID/PPID, monotonic observations, exact response bytes, platform exit status and sampled aggregate RSS. For JS the runner copies exact `signals.c` adjacent to the generated program, makes it mode 0400 in its private tree and checks its hash before and after operation; this test uses the caller's ownership, not a claimed root-owned installation. Embedded TinyCC compilation occurs inside the observed platform job's guarded startup. The TLS row also retains the actual nginx platform job, stop/exit/reap and release evidence. Launchd snapshots use a closed lifecycle projection; inherited/operator environment, other services, arguments and internal diagnostics are omitted. Host-observed log timestamps are not internal work clocks. Production system-domain installation requires administrator provisioning; the local matrix uses the caller's GUI launchd domain and verifies parent PID 1.

The signal twins are foreign IO and the signal watcher/CPU fixture are `@unsafe`: type checking and actual native/JS operation are the evidence, **not mathematical proof of host IO, signal delivery or cancellation**. Human `LAWS.bend` is unchanged. This consumer-only addition does not alter hub entry/effects or require a VERSION bump. The unrelated HTTP retry CI residual and archive-publication conflict are not addressed here.

## Recorded final matrix

[results.json](results.json), invocation index **6** (seventh entry), passed all eight cases on Bend 2.0.35, Bun 1.3.14, nginx 1.29.3 and `macOS-26.6.2-arm64-arm-64bit-Mach-O`. Every application and nginx root had parent PID 1. Kernel `NOTE_EXIT` was 2147483648; PID-identity disappearance and launchd exit status were observed separately. The native and JS cases bind the same final shared-C source, not earlier native-only evidence.

| Lane / case | PID | launchd exit status | Exit seconds | Reap seconds | Stuck-peer closure seconds |
| --- | ---: | ---: | ---: | ---: | ---: |
| Native cooperative | 10828 | 0 | 0.990088 | 1.014567 | n/a |
| Native CPU | 11106 | -9 | 5.050416 | 5.082083 | 5.239121 |
| Native blocked IO | 12166 | -9 | 5.061787 | 5.084841 | 5.241367 |
| Native TLS | 13559 | 0 | 0.129699 | 0.152363 | n/a |
| JS cooperative | 14701 | 0 | 0.991336 | 1.015212 | n/a |
| JS CPU | 15099 | -9 | 5.051983 | 5.075459 | 5.248824 |
| JS blocked IO | 16465 | -9 | 5.059519 | 5.084818 | 5.284296 |
| JS TLS | 17553 | 0 | 0.070203 | 0.093082 | n/a |

Cooperative/CPU/IO times start at the recorded platform stop request. TLS times start after the private admin stop response; those rows are **not** platform-grace escalation measurements. Both cooperative cases observed listener refusal and completed-idle-keepalive closure before admitted work completed with exact `200 {"id":7,"name":"Alice"}`, then real state/store/transport/admin owner joins and journal hex `434c4f5345440a` (`CLOSED\n`). The CPU/IO cases observed actual launchd SIGKILL after five seconds, admitted and idle peer closure within six seconds, and real blocked TCP peer closure for IO. Their empty journals and lack of completed owner cleanup are retained, not presented as graceful shutdown. All six platform-stop cases recorded the native signal-handler marker, including CPU cases whose Bend watchers could not complete shutdown.

Each TLS lane made nine actual HTTPS requests, retained exact raw-target equality markers for all nine, exercised all four users routes (including exact create body and `/users/9` Location), and checked public `POST /stop` returned application 404 rather than private administrative 200. Native nginx PID 13708/worker 13709 and JS nginx PID 17690/worker 17691 exited with status 0; controlled reap times were 0.075551s and 0.073309s. Disposable explicitly trusted localhost certificates prove this local TLS path only, not public-CA installation or malformed-target acceptance.

The final run's aggregate peak was 5,125,600 KiB. No safety failure or forced cleanup occurred; all ten platform jobs were unregistered, every observed root/descendant identity was released, ports 19441–19444 refused connections, and the owned temporary tree was removed. The mode-0400 JS source copy's before/after SHA matched the repository C source. Every recorded source/config SHA matched before/after operation:

| Final runtime input | SHA-256 |
| --- | --- |
| `users.bend` | `857ec936738d178f4d12b5c8794682986819e56e1f67eb31719f9b8f40dd9b46` |
| `signals.c` | `e3a3a8e1a459cbfde62d975d9178052395c2150f16ec80943cac530fa1562b0a` |
| `signals.js` | `46afccf02209f4fea267f73e9e789cc24f91a409cf8cd1739e3b163ba7adb94d` |
| `run.py` | `53589c908483db541ec6387868cabbd236bf57d3042b3d83967b652430ae81e9` |

The JSON retains the complete eleven-input SHA table, including both imported users consumers and all three plists/proxy configuration. Documentation is not a runtime input.

### Preserved adverse attempts

[native-cooperative.json](native-cooperative.json) retains two checker failures (`TCP.close` was not the socket-close API; an affine hook template needed the existing affine-wrapper pattern) before the earlier native smoke passed. [results.json](results.json) retains all earlier attempts and their original hashes:

- Index 0: CPU admission observation timed out before the effect-dependent seed correction; cleanup was forced and the invocation remains failed. The corrected pure CPU fixture uses the existing `risk_probe.bend` effect-input pattern, not foreign CPU work.
- Index 1: TLS marker expectation incorrectly omitted root hooks on unmatched paths; eight were observed instead of the expected five. Failed receipt and forced users cleanup remain retained.
- Index 2: the nine-marker check ran before physical stdout caught up with the ninth peer-visible response. Error-time log had eight; final flushed log had nine. The unchanged nine-marker oracle now runs after actual owner/process exit.
- Index 3: the first JS job naturally stopped before serving proof because a tagged `False` object was truthy under JS's primitive Boolean ABI. This startup failure is not counted as successful serving.
- Index 4: primitive Boolean fixed admission, but the `process.on` signal callback did not dispatch during the observed live Bend IO run. The listener-refusal deadline and forced cleanup remain failures; this is not evidence about cancellation of arbitrary handlers.
- Index 5: the smallest corrected JS cooperative proof passed with the shared native signal bridge. Index 6 is the complete final-source matrix above.

Every retained attempt ultimately released its owned jobs/observed identities and private temporary tree. These local GUI-domain results do not claim a production system-domain installation, portability, hard in-runtime cancellation, mathematical foreign-code proof, or a passing Linux HTTP retry gate.
