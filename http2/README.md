# HTTP/2 client, frame codec, and HPACK

```bend
import bend-kit-http2@0.4.0.0/http2.bend as H2
import bend-kit-http2@0.4.0.0/hpack.bend as Hpack
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
```

`http2.bend`, `hpack.bend`, and `huffman.bend` import `bend-kit-bytes@0.3.3.0`. `hpack.bend` is a separate file in this package. Use the same package version for both imports.

`http2.bend` encodes and parses the nine-octet frame header. It supports all ten frame types in RFC 9113 §6. A `Frame` carries the type, flags, stream ID, and packed payload bytes. The payload keeps padding and fixed fields in wire order. Callers can decode HPACK and other frame content without a `String` conversion.

`parse(max, bytes)` returns `Need{input}` for an incomplete frame. It returns `Got{frame, rest}` for a complete frame, or `Bad{error}` for a malformed frame. Keep the `Need` input. Append new bytes before you call `parse` again. `encode(max, frame)` returns `Done{bytes}` or `Fail{error}`. Use `16384` for `max` until the peer advertises another `SETTINGS_MAX_FRAME_SIZE`. `Error` contains the RFC §7 code. It identifies a connection error or a stream error.

The parser returns unknown frame types without changes. The client ignores them. The parser ignores reserved flag and stream-ID bits during validation. It clears the reserved stream-ID bit in the parsed frame. The encoder rejects unused flags on standard frame types. The connection checks stream state, header continuation order, flow-control windows, and direction rules.

`hpack.bend` encodes and decodes RFC 7541 header blocks over packed `Bytes`. Start with `Hpack.new(4096)` or the current `SETTINGS_HEADER_TABLE_SIZE`. Pass the returned `State` to the next block in that direction. Keep separate encoder and decoder states. `Hpack.encode(fields, huffman, state)` returns `Some{(next, bytes)}`. `Hpack.decode(bytes, state)` returns `Some{(next, fields)}`. Decode returns `None{}` for a malformed block. Encode returns `None{}` for a non-octet string or an invalid field mode. A `Field` has a name, value, and mode. Mode `0` permits dynamic indexing. Mode `1` forbids indexing. Mode `2` keeps the never-indexed representation for sensitive fields. Names and values are byte strings, with one `Char` per octet. They are not decoded UTF-8 text.

Call `Hpack.set_limit(max, state)` when the peer changes the encoder's table-size limit. Also call it when you advertise a new decoder limit. The encoder emits the required size updates at the start of its next block. The decoder requires them at the start of the peer's next nonempty block. It rejects updates above the advertised limit. It also rejects invalid indexes, integer overflow, invalid Huffman padding, and EOS. Multiple limit changes emit the smallest limit first.

## Client connection

`client.start()` returns a `Client` and the client preface with a SETTINGS frame. That frame disables server push. Send those bytes first. `client.request(client, fields, body)` allocates an odd stream ID. It returns `Advanced{client, writes, events}` or `Failed{error}`. Supply `:method`, `:scheme`, `:authority`, and `:path` as HPACK fields. Send `writes` in order. Keep the returned `client` for the next call.

Pass each packed byte chunk to `client.receive(client, chunk)`. It buffers incomplete frames. It returns SETTINGS ACKs, PING replies, WINDOW_UPDATE credit, and resumed DATA in `writes`. A `Response{id, headers, body}` event completes a response. Interim 1xx responses arrive as separate events. `Reset`, `Shutdown`, and `Pong` report RST_STREAM, GOAWAY, and PING ACK. `client.ping.request(client, payload)` sends an eight-octet PING. DATA pauses when either flow-control window is empty. It resumes when the peer increases that window. GOAWAY prevents new requests but lets earlier streams finish.

The laws prove the RFC 7541 Appendix C.2 to C.6 examples. They also exercise SETTINGS, fragmented headers, a flow-control stall, and GOAWAY. `scripts/check.sh http2` runs a public `nghttp2.org` TLS/ALPN request. That check needs network access. Frame, HPACK, and native client connection benchmarks are in `bench/`.
