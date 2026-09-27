# HTTP/2 framing benchmark

Run `python3 -m pip install h2`, then `python3 run.py` on a machine with Bend, a C compiler, and `pkg-config`/`libnghttp2`. The runner builds into a temporary directory and checks that each implementation prints the same checksum.

Input: 10,000 copies of a 17-byte PING frame with the ACK flag and opaque data `12345678`. Each parser reads the eight opaque octets. The checksum is the wrapping U32 sum of their two big-endian words: **1321016000**.

| Parser | Version | Time (macOS arm64, one run) | Checksum |
|---|---|---:|---:|
| C nghttp2 session | libnghttp2 1.70.0, Apple clang 17.0.0 | 0.1648 s | 1321016000 |
| Python h2/hyperframe | Python 3.14.6, h2 4.4.1, hyperframe 6.1.0 | 0.0420 s | 1321016000 |
| Bend frame codec | Bend 2.0.31 | 0.1408 s | 1321016000 |

`nghttp2` exposes a stateful session receive API rather than a standalone frame parser; its run includes the SETTINGS preface and session bookkeeping. Python `h2` exposes framing through its `hyperframe` dependency. The Rust `h2` crate keeps its frame module private, and Node's `http2` exposes sessions rather than a raw frame codec. Neither has a comparable standalone codec API. These times compare working parsers on one input, not identical layers of protocol work.
