# websocket

RFC 6455 WebSocket client over `wire`: the opening handshake, frames on packed `Bytes`, message reassembly, and a connection that answers pings and closes cleanly.

`websocket.bend` imports `bend-kit-bytes@0.3.2.0`, `bend-kit-crypto@0.1.0.0`, and `bend-kit-wire@0.4.2.0`. The current `wire` package is `0.4.6.0`. A `Socket` from that version is a different type. The handshake uses libcrypto SHA-1 and secure random (`BEND_LIBCRYPTO`).


```bend
import bend-kit-websocket@0.2.0.0/websocket.bend as WS

# ws://127.0.0.1:8080/chat; tls True{} for wss://. 1 MiB frame and message cap, 5 s per socket step.
c : Result<&1, &1, U32 & String, WS.Conn> <- WS.connect("127.0.0.1", 8080, "localhost", "/chat", False{}, 1048576, 5000)
# then WS.send(conn, True{}, 1, text_bytes), WS.recv(conn, 5000), WS.close(conn, 1000, reason), WS.shutdown(conn)
```

- **Handshake** (§4.1). `key()` draws 16 octets from the OS secure random source (`crypto`'s `random.words`). `accept(key)` hashes it with the GUID through libcrypto SHA-1; `accept.of(digest)` is the pure base64 step. `request` refuses a host, path, or key with a char outside visible ASCII (EINVAL), so a caller's string cannot inject headers. `check` requires the status line `HTTP/1.1 101`, well-formed header lines, one `Upgrade: websocket`, a `Connection` list with `upgrade`, and exactly one matching `Sec-WebSocket-Accept`, and rejects any extension or subprotocol. Bytes after the server's head stay in the connection as frames.
- **Frames** (§5). `encode` masks a client frame word by word and writes the shortest length form; it refuses a bad opcode or an oversized or fragmented control frame. `parse` reads one frame from the front of a `Bytes.Cursor` and returns `Need` (input intact), `Got` (frame and the cursor past it), or `Bad` (close code). It checks RSV bits, opcodes, control-frame rules, the mask bit for the peer's role, and the size cap as soon as the header is whole. `push` appends a read to the input. A frame moves the cursor; only its payload is copied, and `push` copies the undecoded tail once.
- **Incremental decoding**. `parse` is `next`, a decoder over any input with four operations, run on `Bytes.Cursor`. `PROOF.bend` proves `next` on `list.next`, the same decoder over a list of octets. For every input and every split of it, feeding the parts one after another emits the same frames, rest, and fault as feeding them joined (`feed_split`). A decoded frame or fault stays the same when more octets arrive (`got_more`, `bad_more`), so only `Need` can change. A frame takes a prefix of the input and leaves the rest (`got_suffix`), at least one octet (`got_progress`, `frames_bound`), and a payload of at most max octets (`got_limit`). An input that still needs octets is shorter than 14 + max (`need_bound`), so the buffer is bounded by that plus one read. A 7-bit unmasked frame decodes to itself and every strict prefix of it is `Need` (`roundtrip`, `prefix_need`). The `Bytes.Cursor` arithmetic never wraps (`cut_exact`, `cut_within`).
- **Trust boundary**. The proofs hold for the list operations. `parse` assumes that its four `Bytes.Cursor` operations act as the list ones on the same octets; `check.bend` compares the two decoders on concatenated, masked, malformed, and over-limit inputs, split into two reads at every octet and into reads of every fixed size. Proofs do not cover socket delivery, the native effects, or the peer. The 16- and 64-bit lengths and masked frames are checked by fixtures, not by a universal round trip: that needs bit-level `U32` lemmas.
- **Messages** (§5.4). `feed` joins fragments, passes control frames through between them, rejects orphan continuations and interleaved data frames, caps the total size, and requires UTF-8 in text messages (1007).
- **Connection**. `recv` returns `Text`, `Binary`, `Pong`, or `Closed`. It answers pings, echoes the peer's close, and on a protocol fault sends close with the fault's code and fails with it. EOF inside a frame fails with 1006. A `Conn` built with `server` true reads masked frames and sends clear ones, for a socket an HTTP server upgraded; its input is a `Bytes.Cursor` (`Bytes.Cursor.new(rest)` for octets read past the HTTP head).

Errors are `(code, why)`: 1000 and up is the §7.4 close code at fault, anything lower is the errno of a socket or crypto effect.

Not covered: extensions (permessage-deflate) and subprotocol negotiation, the server side of the opening handshake, host names (resolve with `dns` first), and frames or messages of 2 GiB and up.

`bend PROOF.bend --check-only` checks the laws (the RFC 6455 §1.3 and §5.7 samples among them). `bend check.bend` splits inputs at every read boundary and runs two sessions against servers in the same program on 127.0.0.1:39461 and :39462. `bench/` compares the frame path and a stream of frames in 64 KiB reads with Rust, Node, and Python.
