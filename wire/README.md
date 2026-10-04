# Wire

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

Host effects are outside Bend's proof guarantees. `scripts/check.sh wire` permits the disclosed foreign-code proof exclusions while checking types and running existing checks. Pure laws do not attest socket IO, clocks, buffer cleanup, or scheduling. `scripts/publish.sh --check` checks the version gate; CI publishes `bend-kit-wire@0.4.4.0` after merge, never by hand.

### Observed acceptance (2026-10-03, macOS arm64)

`python3 -B wire/deadline_check.py` passed all eight scenarios in each compiled lane. Both peers received the exact 4099-byte binary success payload. Empty writes succeeded; oversize length, zero budget, and budget above INT32_MAX returned EINVAL with zero bytes. Real reset peers returned EPIPE with zero bytes in this run. Every returned socket was explicitly closed.

| 100 ms total budget | Native | JS |
| --- | --- | --- |
| No reads until failure | ETIMEDOUT, 653852 bytes, 104.755 ms | ETIMEDOUT, 621396 bytes, 106.072 ms |
| 8192-byte reads paced every 10 ms | ETIMEDOUT, 923824 bytes, 102.583 ms | ETIMEDOUT, 923720 bytes, 102.218 ms |

Each paced peer completed nine reads before the failure marker. More bytes progressed than in the stalled case, but the total budget still expired near 100 ms rather than restarting after progress. After explicit socket closure both peers drained exactly the reported accepted prefix, with exact binary contents. This controlled-peer observation is not a general peer-delivery guarantee.

The measured interval uses the published monotonic `Time.mono` clock immediately before the write and in its returned Bend continuation. It includes conversion, IO waiting, disposal, and continuation scheduling. It does not expose the internal timeout instant. The runner also retains parent-observed marker intervals separately; native buffered stdout can make those intervals shorter than the call interval. No claim is made about timely continuation scheduling during unrelated uncooperative work.

An initial native smoke caught incorrect deadline storage in `IoWork.word` (a u32 also overwritten with the parked fd). The corrected effect uses the runtime's u64 `IoWork.time`, which `io_wait_on` preserves as the same absolute deadline. This relies on the installed compiler ABI, as existing packed BUF access does; recheck it on compiler upgrades.

`scripts/check.sh wire` passed with all existing IPv6/TCP, IPv6/UDP, and live ALPN checks. It disclosed 18 foreign-code proof exclusions, including `send.words.deadline`; wire has no human-owned laws to change. `scripts/publish.sh --check wire` reported `bend-kit-wire@0.4.4.0 will publish`. The new feature was smoke-tested after settled implementation rather than run pre-edit, because the coordinated single-Bend slot excluded mid-flight verification.
