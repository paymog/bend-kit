# stream

Bounded, byte-exact transfers using the packed `U32 & Array<U32>` effects from
`bend-kit-files@0.1.1.1` and `bend-kit-wire@0.4.6.1`. No per-byte String/list
conversion, whole-input buffering, reader/writer hierarchy, or new host effect.

```bend
import Base
import bend-kit-stream@0.1.0.1/stream.bend as Stream

# Handles are already open; the caller owns their lifetime.
def copy(source: File, destination: File) -> IO(File & File & Stream.Outcome):
  Stream.file.file(source, destination, 65536, 16777216)
```

## API

- `file.file(source: File, destination: File, chunk: U32, cap: U32)`
  → `IO(File & File & Outcome)`
- `file.socket(source: File, destination: Socket, tls: Bool, chunk: U32, cap: U32)`
  → `IO(File & Socket & Outcome)`
- `socket.file(source: Socket, destination: File, tls: Bool, chunk: U32, cap: U32, ms: U32)`
  → `IO(Socket & File & Outcome)`

`tls = True{}` selects Wire's TLS words effects on an already-handshaken socket;
`False{}` selects plain TCP. Establish connections/TLS and close handles yourself.
Transfers never close either handle, including on errors.

`Outcome` is `Complete{count}` or `Failed{count, error}`. Errors are `BadChunk{}`,
`Limit{}`, `Read{code, message}`, and `Write{code, message}`. Native error codes
and messages are retained unchanged. `chunk` must be 1–1,048,576 bytes inclusive;
invalid values return both untouched handles and `Failed{0, BadChunk{}}`.

## Limits, EOF, and deadlines

`cap` is the maximum number of bytes forwarded, including when it is zero.
Reads request at most `min(chunk, cap - count)`. At the cap, one extra read
requests **one byte**: EOF completes successfully; a byte is consumed, never
written, and returns `Limit`. Thus exact-cap input succeeds, zero-cap empty
input succeeds, and zero-cap nonempty input fails without writing.

A short read continues; only a successful zero-byte read is clean EOF. TLS
requires the peer's `close_notify`; abrupt TLS EOF remains a `Read` error.
Every socket read, including the probe, receives the caller's `ms` unchanged.
This is Wire's **per-read** deadline in milliseconds, not a whole-transfer
budget; `0` disables it. There is no additional write or overall deadline.

## Counts and returned handle positions

`count` includes only complete, successful writes. A failing write may already
have delivered a prefix, but **none of that failing chunk** contributes to
`count`. The entire failing chunk was already read from the source. Likewise,
an over-cap result consumes one source probe byte beyond the forwarded cap.
Returning handles does not imply that either handle's position equals `count`.
There is no retry, rollback, seek, destination truncation, or shutdown. Callers
must account for a possibly partial last destination chunk before deciding
whether/how to resume.

The loop holds one packed chunk at a time. Its shrinking Nat fuel allows
`cap + 1` reads even with one-byte short reads; it imposes no smaller fixed read
ceiling. Packed storage is bounded by `chunk` (plus the one-byte probe), not
input length or cap. Native Nat representation and effect allocation behavior
are runtime trust/verification obligations, not consequences of these proofs.

## Verification

`../scripts/check.sh stream` checks the entry file, pure proofs, and package
check program. `python3 check.py` exercises compiled binary file/TCP/TLS
transfers, partial writes, returned handles, and failure boundaries.
`python3 check.py --target js` runs the same cases through Bun. Both lanes
have passed. The manual five-language benchmark and native cap-fuel RSS
measurement are in [bench/README.md](bench/README.md).
See [SPEC.md](SPEC.md) for the precise effect assumptions. `LAWS.bend` and
`PROOF.bend` cover pure validation/read decisions only, not foreign IO.
