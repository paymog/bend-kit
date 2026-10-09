# HTTP/2 client, frame codec, and HPACK

```bend
import bend-kit-http2@0.2.0.0/http2.bend as H2
import bend-kit-http2@0.2.0.0/hpack.bend as Hpack
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
```

`http@0.32.0.0` imports this `http2` version. `hpack.bend` is a separate file in the same package.


`http2.bend` encodes and parses the nine-octet frame header and all ten frame types in RFC 9113 §6. A `Frame` carries the type, flags, stream ID, and packed payload bytes. The payload retains padding and fixed fields in wire order so callers can decode HPACK and other frame-specific content without converting it to a `String`.

`parse(max, bytes)` returns `Need{input}` when a frame is incomplete, `Got{frame, rest}` when it is complete, or `Bad{error}` for a malformed frame. Keep the `Need` input and append newly received bytes before calling `parse` again. `encode(max, frame)` returns `Done{bytes}` or `Fail{error}`. Use `16384` for `max` until the peer advertises another `SETTINGS_MAX_FRAME_SIZE`. `Error` contains the RFC §7 code and identifies whether it is a connection error or a stream error.

Unknown frame types are returned intact; the connection client ignores them. Incoming reserved flag and stream-ID bits are ignored when validating; the stream-ID bit is cleared in the parsed frame. The encoder rejects unused flags on standard frame types. Stream state, header continuation ordering, flow-control windows, and direction-specific rules belong to the connection, not the individual frame.

`hpack.bend` encodes and decodes RFC 7541 header blocks over packed `Bytes`. Start with `Hpack.new(4096)` or the current `SETTINGS_HEADER_TABLE_SIZE`, then pass the returned `State` into the next block in that direction. Keep separate encoder and decoder states. `Hpack.encode(fields, huffman, state)` returns `Some{(next, bytes)}`; `Hpack.decode(bytes, state)` returns `Some{(next, fields)}`. `None{}` means a malformed HPACK block on decode or a non-octet string or invalid field mode on encode. A `Field` has a name, value, and mode: `0` permits dynamic indexing, `1` forbids indexing, and `2` preserves the never-indexed representation for sensitive fields. Names and values are byte strings (one `Char` per octet), not UTF-8-decoded text.

Call `Hpack.set_limit(max, state)` when the peer changes its table-size limit for your encoder, or when you advertise a new limit to your decoder. The encoder emits required size updates at the start of its next block. The decoder requires them at the start of the peer's next nonempty block, rejects updates larger than the advertised limit, and rejects invalid indexes, overflowing integers, or invalid Huffman padding and EOS. Multiple limit changes emit the smallest limit first.

## Client connection

`client.start()` returns a `Client` and the client preface plus a SETTINGS frame that disables server push. Send those bytes first. `client.request(client, fields, body)` allocates an odd stream ID and returns `Advanced{client, writes, events}` or `Failed{error}`. Supply the HTTP/2 pseudo-headers (`:method`, `:scheme`, `:authority`, `:path`) as HPACK fields. Send `writes` in order and keep the returned `client` for the next call.

Pass each received packed byte chunk to `client.receive(client, chunk)`. It buffers incomplete frames and returns SETTINGS ACKs, PING replies, WINDOW_UPDATE credit, and resumed DATA in `writes`. A `Response{id, headers, body}` event completes a response; interim 1xx responses arrive as separate events. `Reset`, `Shutdown`, and `Pong` report RST_STREAM, GOAWAY, and PING ACK. `client.ping.request(client, payload)` sends an eight-octet PING. Sending DATA pauses when either flow-control window is empty and resumes when the peer raises that window. GOAWAY prevents new requests but permits earlier streams to finish.

The laws prove the RFC 7541 Appendix C.2 to C.6 examples and drive the client through SETTINGS, fragmented headers, a flow-control stall, and GOAWAY. `scripts/check.sh http2` also runs a public `nghttp2.org` TLS/ALPN request, so it needs network access. Cross-language frame, HPACK, and native client connection benchmarks are in `bench/`.
