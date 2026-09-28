# websocket

RFC 6455 WebSocket client over `wire`: the opening handshake, frames on packed `Bytes`, message reassembly, and a connection that answers pings and closes cleanly.

```bend
import bend-kit-websocket@0.1.0.0/websocket.bend as WS

# ws://127.0.0.1:8080/chat; tls True{} for wss://. 1 MiB frame and message cap, 5 s per socket step.
c : Result<&1, &1, U32 & String, WS.Conn> <- WS.connect("127.0.0.1", 8080, "localhost", "/chat", False{}, 1048576, 5000)
# then WS.send(conn, True{}, 1, text_bytes), WS.recv(conn, 5000), WS.close(conn, 1000, reason), WS.shutdown(conn)
```

- **Handshake** (§4.1). `key()` draws 16 octets from the OS secure random source (`crypto`'s `random.words`). `accept(key)` hashes it with the GUID through libcrypto SHA-1; `accept.of(digest)` is the pure base64 step. `request` refuses a host, path, or key with a char outside visible ASCII (EINVAL), so a caller's string cannot inject headers. `check` requires the status line `HTTP/1.1 101`, well-formed header lines, one `Upgrade: websocket`, a `Connection` list with `upgrade`, and exactly one matching `Sec-WebSocket-Accept`, and rejects any extension or subprotocol. Bytes after the server's head stay in the connection as frames.
- **Frames** (§5). `encode` masks a client frame word by word and writes the shortest length form; it refuses a bad opcode or an oversized or fragmented control frame. `parse` reads one frame from the front of a buffer and returns `Need` (input intact), `Got` (frame and rest), or `Bad` (close code). It checks RSV bits, opcodes, control-frame rules, the mask bit for the peer's role, and the size cap as soon as the header is whole.
- **Messages** (§5.4). `feed` joins fragments, passes control frames through between them, rejects orphan continuations and interleaved data frames, caps the total size, and requires UTF-8 in text messages (1007).
- **Connection**. `recv` returns `Text`, `Binary`, `Pong`, or `Closed`. It answers pings, echoes the peer's close, and on a protocol fault sends close with the fault's code and fails with it. A `Conn` built with `server` true reads masked frames and sends clear ones, for a socket an HTTP server upgraded.

Errors are `(code, why)`: 1000 and up is the §7.4 close code at fault, anything lower is the errno of a socket or crypto effect.

Not covered: extensions (permessage-deflate) and subprotocol negotiation, the server side of the opening handshake, host names (resolve with `dns` first), and frames or messages of 2 GiB and up. A buffer that holds many frames is copied once per frame.

`bend PROOF.bend` checks the laws (the RFC 6455 §1.3 and §5.7 samples among them). `bend check.bend` runs a whole session against a server in the same program on 127.0.0.1:39461. `bench/` compares the frame path with Rust, Node, and Python.
