# HTTP/2 frame codec

`http2.bend` encodes and parses the nine-octet frame header and all ten frame types in RFC 9113 §6. A `Frame` carries the type, flags, stream ID, and packed payload bytes. The payload retains padding and fixed fields in wire order so callers can decode HPACK and other frame-specific content without converting it to a `String`.

`parse(max, bytes)` returns `Need{input}` when a frame is incomplete, `Got{frame, rest}` when it is complete, or `Bad{error}` for a malformed frame. Keep the `Need` input and append newly received bytes before calling `parse` again. `encode(max, frame)` returns `Done{bytes}` or `Fail{error}`. Use `16384` for `max` until the peer advertises another `SETTINGS_MAX_FRAME_SIZE`. `Error` contains the RFC §7 code and identifies whether it is a connection error or a stream error.

Unknown frame types are returned intact; a connection consumer must ignore them. Incoming reserved flag and stream-ID bits are ignored when validating; the stream-ID bit is cleared in the parsed frame. The encoder rejects unused flags on standard frame types. Stream state, header continuation ordering, flow-control windows, and direction-specific rules are connection-layer responsibilities, not individual-frame properties.

Run `scripts/check.sh http2` from the repository root to type-check the codec, prove the fixture laws, and execute the 16 KiB frame smoke check. The cross-language benchmark is in `bench/`.
