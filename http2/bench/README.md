# HTTP/2 framing, HPACK, and client connection benchmarks

Install Python `h2` (which includes `hyperframe` and `hpack`), then run `python3 run.py` with Bend, a C compiler, and `pkg-config`/`libnghttp2` installed. The runner builds in a temporary directory and checks that C, Python, and Bend print the same checksum for each workload.

Framing input: 10,000 copies of a 17-byte PING frame with the ACK flag and opaque data `12345678`. Each parser reads the eight opaque octets. The checksum is the wrapping U32 sum of their two big-endian words: **1321016000**.

| Framing parser | Version | Time (macOS arm64, one run) | Checksum |
|---|---|---:|---:|
| C nghttp2 session | libnghttp2 1.70.0, Apple clang 17.0.0 | 0.2239 s | 1321016000 |
| Python h2/hyperframe | Python 3.14.6, h2 4.4.1, hyperframe 6.1.0 | 0.0415 s | 1321016000 |
| Bend frame codec | Bend 2.0.32 | 0.1692 s | 1321016000 |

HPACK input: 1,000 copies of RFC 7541 C.3.1's first request header block on one persistent decoder. Each parser maintains its dynamic table and sums every decoded name and value octet. The checksum is **5167000**.

| HPACK decoder | Version | Time (macOS arm64, one run) | Checksum |
|---|---|---:|---:|
| C nghttp2 HPACK | libnghttp2 1.70.0, Apple clang 17.0.0 | 0.1226 s | 5167000 |
| Python hpack | Python 3.14.6, hpack 4.2.0 | 0.0520 s | 5167000 |
| Bend HPACK | Bend 2.0.32 | 0.1557 s | 5167000 |

Connection input: one server SETTINGS frame followed by 10,000 PING ACK frames on the same client connection. Each implementation sums the two big-endian words of every acknowledgment. The checksum is **1321016000**.

| Client connection | Version | Time (macOS arm64, one run) | Checksum |
|---|---|---:|---:|
| C nghttp2 session | libnghttp2 1.70.0, Apple clang 17.0.0 | 0.0093 s | 1321016000 |
| Python h2 connection | Python 3.14.6, h2 4.4.1 | 0.0904 s | 1321016000 |
| Bend client connection | Bend 2.0.32 | 0.1433 s | 1321016000 |

The Bend HPACK loop creates a packed `Bytes` input on each iteration because byte buffers are affine. The C and Python loops reuse their input. The framing comparison also includes different layers: nghttp2's stateful session receive API includes the SETTINGS preface and session bookkeeping, Python h2 exposes framing through `hyperframe`, and Bend parses one frame. The Rust `h2` crate keeps its frame module private, and Node's `http2` exposes sessions rather than a raw frame codec.
