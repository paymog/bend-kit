# Wire

Byte-exact TCP, UDP, and TLS. A socket or listener is used once. The call returns it beside the result, except `connect`, which returns the socket inside the `Result`.

```bend
import bend-kit-wire@0.4.6.1/wire.bend as Wire
```

`connect(host, port, ms)` opens TCP. `recv` and `send` move a byte `String`. The `.words` forms move packed `Array<U32>` buffers, four octets per word, and do not build a list cell per byte. `recv_from` and `send_to` are UDP. `ms` is a deadline in milliseconds. `0` means no deadline, except where a def says otherwise. `accept.deadline` rejects `0`. A miss is the host `ETIMEDOUT`: 60 on macOS, 110 on Linux.

`tls.connect` checks the certificate chain and the host name. `tls.connect.cert` adds a PEM client chain and key. `tls.connect.ca` trusts the PEM certificates in one file for that handshake, instead of the default verify paths. Verification stays on. `tls.connect.alpn` returns the selected protocol. `tls.connect.alpn.ca` does both. Set `BEND_LIBSSL` when OpenSSL 3 `libssl` is not on the default path. Proofs do not cover `effs/wire.c` and `effs/wire.js`.

`http` imports `bend-kit-wire@0.4.6.0`. `dns` imports `0.4.3.0`. `redis`, `postgres`, and `websocket` import `0.4.2.0`. A `Socket` from one version is not a `Socket` from another.


## Deadline-bounded listener acceptance

`accept.deadline(listener, ms)` returns
`IO(Listener & Result<&1, &1, U32 & String, Socket>)`.

- `ms` must be 1 through 2147483647 milliseconds. Zero and larger budgets return EINVAL without accepting a connection.
- Every outcome returns the actual affine listener. Timeout and invalid input leave it usable for another accept; the caller must eventually call `Listener.close`.
- One absolute monotonic budget covers nonblocking accept, interrupted calls, and readiness retries. Expiry returns the host's ETIMEDOUT (60 on macOS, 110 on Linux), not a synthetic application code.
- Accepted sockets are nonblocking, as with Base `TCP.accept`. The caller owns and must close each successful socket. A failure while configuring an accepted descriptor closes that descriptor before returning the error and listener.
- No listener duplication, detached accept task, or `IO.within` cancellation is involved. A listener bound to port zero remains supported; shutdown does not depend on self-connecting to a guessed address.

This bounds IO waiting, not arbitrary CPU work or blocking effects. An expired budget is observed when the cooperative event loop can run the effect again. HTTP lifecycle changes belong to its separate consumer cutover.

Run `python3 -B wire/accept_deadline_check.py` from the repository root. The macOS harness requires `lsof` to discover each real port-zero listener. It runs native and JS sequentially with a 10 GiB disk floor and a 20 GiB aggregate descendant RSS ceiling. It checks accepted-socket EOF, explicit listener closure, immediate rebinding of the same address, process exit, and absence of observed child processes. Emitted and compiled programs are temporary.

### Observed accept acceptance (2026-10-04, macOS arm64)

All nine scenarios passed in each compiled lane. The small minimum/empty/queued cases ran first. The remaining cases used those same compiled programs, rather than rebuilding them. Every case bound port zero, explicitly closed its listener, and rebound the released address without retry. Successful accepted sockets were explicitly closed and the real peers observed EOF. All observed process IDs were gone after exit.

The durable run receipt is [accept_deadline_results.json](accept_deadline_results.json).

| Case | Native elapsed ms | JS elapsed ms | Outcome |
| --- | --- | --- | --- |
| Minimum 1 ms, empty | 1.408542 | 4.090750 | ETIMEDOUT |
| Empty, 40 ms | 45.058333 | 45.791750 | ETIMEDOUT |
| Queued before accept | 0.095000 | 0.627541 | Success |
| Connect 100 ms after BEGIN | 104.523917 | 103.820541 | Success |
| Two 40 ms expiries, then connect | 43.312167 / 42.699875 / 0.378125 | 45.928459 / 45.139125 / 0.438583 | ETIMEDOUT / ETIMEDOUT / success on returned listener |
| Budgets 0 / 2147483648 / 4294967295, then connect | 0.077500 / 0.047292 / 0.047875 / 0.450250 | 0.534042 / 0.073500 / 0.069084 / 0.859958 | EINVAL / EINVAL / EINVAL / success on returned listener |
| Maximum valid budget, queued | 0.094583 | 0.557209 | Success |
| Immediate accept on port-zero listener | 0.100667 | 2.386750 | Success |
| 40 ms accept alongside delayed 150 ms `Process.run` | 40.910666 | 175.105416 | ETIMEDOUT |

`Process.run` uses a helper thread natively but blocks the JS loop. The observed JS continuation arrived well after 40 ms; this is evidence against a hard delivery-time promise, not a failure of the absolute budget. Measurements span the call through its Bend continuation using `Time.mono`; they include scheduling and do not expose the internal timeout instant. The empty/repeated test allows 500 ms observation tolerance, not a production guarantee.

The installed emitted ABI was inspected before runtime: native `IoWork.hand` is preserved and `time` is u64; `io_wait_on` overwrites `word` with the fd and sets `time` to the same absolute deadline. JS preserves the absolute `at` with its callback. Recheck these internal ABI assumptions on compiler upgrades.

No pre-edit runtime failure was captured: the coordinator required source acceptance before the exclusive verification slot. No runtime attempt failed. Accepted-fd setup failure and EINTR retry behavior were source-inspected, not syscall-fault-injected. There are no Wire human-owned laws/proofs to modify; the package gate passed with **19 disclosed foreign-code exclusions**, including the new effect, plus the existing IPv6 TCP/UDP and live ALPN checks.

Peak aggregate RSS was 947184 KiB for the native smoke build, 48288 KiB across accept scenarios, 153824 KiB for the package gate, and 1000064 KiB for the unchanged write-deadline runner. Its eight scenarios passed in both lanes: exact 4099-byte success, empty success, EINVAL boundaries, EPIPE reset, and exact partial-prefix receipt after timeout. Native stall/trickle accepted 678428/939740 bytes at 103.191/103.697 ms; JS accepted the same byte counts at 104.610/101.783 ms. Both paced peers completed nine reads before failure.

The existing checksum benchmark ran once per variant, not a statistical performance study: C 57.3 ms, Rust 54.4 ms, Bun 446.5 ms, Node 102.5 ms, Python 3411.6 ms, Bend 494.8 ms. All agreed on checksum **3187671040**; peak aggregate RSS was 558176 KiB. Merge CI publishes the package.

## Deadline-bounded packed TCP writes

`send.words.deadline(socket, len, words, ms)` returns
`IO(Socket & (U32 & Result<&1, &1, U32 & String, Unit>))`.

- `words` packs four octets per U32, least-significant byte first. `len` may be zero but must not exceed the array's byte capacity.
- `ms` must be 1 through 2147483647 milliseconds. Zero is invalid, not an unlimited write. Invalid length or budget returns EINVAL with zero progress before sending.
- One monotonic deadline starts before unpacking. Partial sends, readiness wakeups, and interrupted system calls do not reset it. An IO stall returns ETIMEDOUT.
- The U32 beside the result counts bytes accepted by local `send`, on **every** outcome. Success means all `len` bytes were accepted locally, not that the peer received or processed them.
- The effect consumes the affine input array on every outcome. Native drops the Bend array after conversion and frees its host byte copy before returning; JS releases its array reference after conversion and its byte-copy reference before returning (physical reclamation follows host GC).
- The caller owns the returned socket on success, invalid input, timeout, or disconnect. The effect never closes it. Close it after timeout/disconnect: a prefix may already be committed, so replaying the original buffer can duplicate bytes. Invalid input does not send bytes or invalidate the socket.

This primitive bounds socket IO waiting, **not arbitrary Bend computation**. OS scheduling, event-loop starvation by other work, packed conversion, and result/buffer disposal can delay observation. The live acceptance fixture uses a 100 ms budget plus **150 ms host scheduling/cleanup tolerance**, on an otherwise cooperative loop. This is a test allowance, not a hard real-time promise. Dedicated-process supervision is still needed for uncooperative computation.

Existing `send.words` has its separate, unlimited-write contract. Consumers that require a total write budget must call the deadline primitive; no HTTP server cutover is included in this package change.

## Live acceptance

Run `python3 -B wire/deadline_check.py` from the repository root. It compiles native and JS sequentially and uses actual loopback peers for exact binary success, empty success, peer reset, stalled reading with partial-progress accounting and exact prefix receipt, and invalid length/deadline boundaries. Each fixture explicitly closes its returned socket. Builds are RSS-limited to 20 GiB and the runner requires 10 GiB disk headroom; temporary binaries are removed.

Host effects are outside Bend's proof guarantees. `scripts/check.sh wire` permits the disclosed foreign-code proof exclusions while checking types and running existing checks. Pure laws do not attest socket IO, clocks, buffer cleanup, or scheduling. CI publishes the version in `VERSION`. Do not publish by hand.

### Observed acceptance (2026-10-03, macOS arm64)

`python3 -B wire/deadline_check.py` passed all eight scenarios in each compiled lane. Both peers received the exact 4099-byte binary success payload. Empty writes succeeded; oversize length, zero budget, and budget above INT32_MAX returned EINVAL with zero bytes. Real reset peers returned EPIPE with zero bytes in this run. Every returned socket was explicitly closed.

| 100 ms total budget | Native | JS |
| --- | --- | --- |
| No reads until failure | ETIMEDOUT, 653852 bytes, 104.755 ms | ETIMEDOUT, 621396 bytes, 106.072 ms |
| 8192-byte reads paced every 10 ms | ETIMEDOUT, 923824 bytes, 102.583 ms | ETIMEDOUT, 923720 bytes, 102.218 ms |

Each paced peer completed nine reads before the failure marker. More bytes progressed than in the stalled case, but the total budget still expired near 100 ms rather than restarting after progress. After explicit socket closure both peers drained exactly the reported accepted prefix, with exact binary contents. This controlled-peer observation is not a general peer-delivery guarantee.

The measured interval uses the published monotonic `Time.mono` clock immediately before the write and in its returned Bend continuation. It includes conversion, IO waiting, disposal, and continuation scheduling. It does not expose the internal timeout instant. The runner also retains parent-observed marker intervals separately; native buffered stdout can make those intervals shorter than the call interval. No claim is made about timely continuation scheduling during unrelated uncooperative work.

An initial native smoke caught incorrect deadline storage in `IoWork.word` (a u32 also overwritten with the parked fd). The corrected effect uses the runtime's u64 `IoWork.time`, which `io_wait_on` preserves as the same absolute deadline. This relies on the installed compiler ABI, as existing packed BUF access does; recheck it on compiler upgrades.

`scripts/check.sh wire` is the socket check. Wire has no human-owned laws. Proofs do not cover the effects.
