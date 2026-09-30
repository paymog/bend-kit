# Packed transfer specification

The public surface is `file.file`, `file.socket`, and `socket.file`, with the
signatures listed in README.md. `Error` and `Outcome` are copyable Data types;
File/Socket handles and packed arrays remain affine. Both handles are returned
in source/destination order on every result. No handle is closed internally.

## State transitions

1. Reject `chunk = 0` or `chunk > 1048576` before any effect; return untouched
   handles and `Failed{0, BadChunk{}}`. Zero cap is valid.
2. Start at `count = 0`. Request `min(chunk, cap - count)` while count is below
   cap. When count equals cap, request exactly one byte as an EOF probe.
3. Read failure returns `Failed{count, Read{code, message}}` with the source
   returned by the read effect and the unchanged destination.
4. Successful zero-byte read returns `Complete{count}`. Nonzero reads below
   cap are forwarded even when shorter than requested. A nonzero cap probe
   returns `Failed{count, Limit{}}`, consuming the probe but never writing it.
5. Pass the read's length and owned packed array directly to the matching
   write.words effect. A successful write advances count by its entire length;
   a failed write returns `Failed{count, Write{code, message}}`, excluding the
   entire failing chunk. Preserve the write effect's returned destination.
6. Repeat with shrinking Nat fuel initialized to `1n + U32.to_nat(cap)`.
   Every continuing iteration advances count by at least one, so cap+1 reads
   suffice including the EOF/over-cap probe. Under the effect bounds, arithmetic
   cannot overflow U32: count never exceeds cap. The exhausted-fuel continuation
   branch is unreachable under these assumptions; it does not authorize an
   earlier fixed-size read limit.

The source has consumed each chunk before its write is attempted. A failing
write may leave a partial destination prefix while source consumption includes
the whole chunk. A Limit result consumes one extra source byte. Handle survival
is not a source/destination offset guarantee. No retry, rollback, seek,
truncation, or protocol shutdown is performed.

## Transport behavior

Plain TCP uses `Wire.recv.words` / `Wire.send.words`; TLS uses
`Wire.tls.recv.words` / `Wire.tls.send.words`. Sockets must already be connected
and, for TLS, handshaken. File IO uses `Files.read.words` / `Files.write.words`.
TLS clean EOF is only a successful zero-byte result after close_notify. Abrupt
TLS EOF remains Read failure; no EOF/error translation is added.

`socket.file` passes its caller-provided `ms` unchanged on every read, including
the cap probe. It is a per-read Wire deadline in milliseconds; zero disables
it. There is no total transfer deadline or extra write timeout. File→Socket
has no socket read and does not add a write deadline.

## Memory and trust boundary

The loop retains no chunk history and forwards packed arrays without copying
or per-byte String/list conversion. At most one read chunk is in flight; probe
storage is one byte. Read effects may round packed array capacity, but it must
remain bounded by the requested chunk rather than the total input/cap. The
native representation of Nat must support cap-derived fuel without allocating
an input-sized unary structure; generated/native execution must verify this.

Pure laws cover chunk validity, request bounds/probe selection, clean EOF,
nonempty probe rejection, and short-read continuation. They do **not** prove
foreign effects, transport completion, file persistence, allocation behavior,
or error/handle survival at the host boundary. Required trusted contracts:

- Successful reads return 0..requested bytes in the documented packed layout;
  nonzero length is positive progress, and zero is clean EOF. File reads respect
  the 1 MiB limit; TLS distinguishes close_notify from abrupt EOF.
- Writes accept the same packed layout and report success only after the full
  supplied length is delivered. Failures may have delivered a prefix.
- Effects return valid surviving handles on success/failure and preserve errno
  and error messages. No external actor closes or mutates handles concurrently.
- Wire honors each read's deadline. Effects terminate according to their own
  semantics; disabling socket deadlines may allow indefinite waiting.
- Host/runtime release consumed affine storage and use bounded packed buffers.

Native binary file/TCP/TLS fixtures, cap and validation boundaries, write/read
failures, short reads, deadlines, and large-cap/small-input memory measurements
provide runtime evidence separately from the pure proof gate.
