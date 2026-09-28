# bend-kit

A general-purpose library for Bend 2. Each package is proved against its own laws and published to the Bend hub on its own. Networking came first, so `http` and its dependencies are the most complete today. [ROADMAP.md](ROADMAP.md) lists what comes next.

This project was called bend-net. Its old hub names, `bend-net-*`, still resolve but get no new versions.

## Install

You need [Bend 2.0.32 or newer](https://bend-lang.com/install.sh) and [Bun 1.4.2](https://bun.sh/docs/installation). macOS or Linux, including WSL. Windows is not supported.

Import a package at the top of your file. `bend` fetches it from the hub and checks it against its hash:

```bend
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

A name and its hash import the same package. Each version is a distinct type, so import the same version as the package you pass values to.

## Packages

| Package | Import | What it does |
|---|---|---|
| [`bytes`](bytes) | `0x49814d83de8f70993a43e1002be29ecd/bytes.bend` | Byte buffers packed four bytes to a `U32`, with bounds-checked access, endian integers, search, hex, and base64. |
| [`encoding`](encoding) | `0xcfc8be7b076f41f95c8e118383892d55/encoding.bend` | UTF-8 and hex encoding for byte strings. |
| [`json`](json) | `0x584fc27920487ceab242392391418d7f/json.bend` | JSON values, parsed and encoded as RFC 8259. |
| [`csv`](csv) | `bend-kit-csv@0.1.0.0/csv.bend` | CSV records over bytes (RFC 4180), with a record cursor, whole-document parse, and encoder. |
| [`cbor`](cbor) | `bend-kit-cbor@0.1.0.0/cbor.bend` | CBOR values encoded and decoded as bytes (RFC 8949). |
| [`zlib`](zlib) | `0x9d101c075b333e2b07242347f7c35b1c/zlib.bend` | DEFLATE, gzip, and zlib encoding and decoding (RFC 1951, 1952, 1950); native streaming raw DEFLATE, gzip/zlib, Brotli, and Zstandard decoders. |
| [`url`](url) | `0xd248560355ba8929ae030bc9c72f40be/url.bend` | URL parsing, resolution, bracketed IPv6 authorities, and percent-encoding (RFC 3986). |
| [`wire`](wire) | `0x096635686408886b7d907f16c4550317/wire.bend` | Byte-exact IPv4 and IPv6 TCP, UDP, and TLS sockets with packed-byte `.words` effects, including client certificates. |
| [`dns`](dns) | `0xc10a5eaaa9c896e1570e279945f4241e/dns.bend` | DNS A-record lookup over UDP. |
| [`http`](http) | `0xa32ae93500a5dfaef6edb45d6e7bcc3b/http.bend` | HTTP/1.1 client and server for http and https, with DNS and TLS. See [http/README.md](http/README.md). |
| [`http2`](http2) | `bend-kit-http2@0.1.0.0/http2.bend` | RFC 9113 HTTP/2 frame parsing and encoding over packed bytes. See [http2/README.md](http2/README.md). |
| [`hairpin`](hairpin) | `bend-kit-hairpin@0.1.0.0/hairpin.bend` | An HTTP client on top of `http`: a base URL, default headers, a socket pool, a cookie jar, a client certificate, redirects, and retries in one `Client`. See [hairpin/README.md](hairpin/README.md). |
| [`router`](router) | `0xf2239decc78af956c471ebf7f2f50374/router.bend` | Match an HTTP method and path to a handler. |
| [`files`](files) | `0x902b9f92801b87d6be0bcd03919d01bb/files.bend` | POSIX path operations, directory listing, metadata, mkdir, remove, rename, and private temp directories. |
| [`process`](process) | `0xb9c171843853f26eb0a0cfd88782e4d3/process.bend` | Run commands without a shell, with byte-exact stdin, stdout, and stderr, exit status, streaming pipes, and signals. |
| [`collections`](collections) | `0x620317aa272e53852c5b5baae68a727b/collections.bend` | An ordered map and set keyed by any `Data` type, a growable vector, a deque, and a priority queue. Import the file you need: `omap.bend`, `vec.bend`, `deque.bend`, or `heap.bend`. |
| [`unicode`](unicode) | `0x6c784a08486e2e02415e89c5249e9e8a/unicode.bend` | Unicode 17.0 general category, NFC/NFD, full case folding, and grapheme clusters. See [unicode/README.md](unicode/README.md). |
| [`regex`](regex) | `0x6fa820747435b3188e7e4f3d1ffc0325/regex.bend` | Linear-time regular expressions: RE2 syntax, capture groups, and Unicode categories. See [regex/README.md](regex/README.md). |
| [`parse`](parse) | `0x154e0a68ef9a0223bacaacefc589cad8/parse.bend` | Parser combinators over text, with positioned errors: sequence, choice, `many`, `sep_by`, `opt`, and `rec` for nested grammars. `parse/json.bend` is a JSON grammar on it. |
| [`int`](int) | `bend-kit-int@0.2.0.0/int.bend` | Fixed-width `U8`, `U16`, `U64`, `I32`, and `I64`, with wrapping, checked, and saturating arithmetic, text in radix 2 to 36, and conversions to `U32` and `Nat`. `U8`, `U16`, and `I32` run at native speed on Base's `U32`. `U64` and `I64` use `Word(64n)` and are slow. |
| [`fmt`](fmt) | `bend-kit-fmt@0.1.0.0/fmt.bend` | A string builder, `format`, padding, and the shortest `F32` text that reads back to the same value. |
| [`hash`](hash) | `bend-kit-hash@0.1.0.0/hash.bend` | Non-cryptographic hashes over `Bytes`, or over a byte string with the `.str` forms: FNV-1a (32 and 64), xxHash (32 and 64), SipHash-1-3, CRC-32, and Adler-32. 64-bit results are `Hash.W64{hi, lo}`, two `U32` halves; `int`'s `U64` is a bit list and too slow for hashing. |
| [`crypto`](crypto) | `bend-kit-crypto@0.1.0.0/crypto.bend` | SHA-256, SHA-512, SHA-1, HMAC, HKDF, secure random bytes, and constant-time compare through OpenSSL 3 libcrypto (`BEND_LIBCRYPTO` overrides the path). |
| [`websocket`](websocket) | `bend-kit-websocket@0.1.0.0/websocket.bend` | RFC 6455 client handshake and WebSocket frames. |
| [`multipart`](multipart) | `bend-kit-multipart@0.1.0.0/multipart.bend` | RFC 7578 form-data encoding and streaming decoding. |
| [`random`](random) | `bend-kit-random@0.1.0.0/random.bend` | Seeded xoshiro128** generator with unbiased ranges, `F32` in [0, 1), Fisher-Yates shuffles, and an OS-entropy seed. Not for cryptography. |
| [`time`](time) | `bend-kit-time@0.1.0.0/time.bend` | Monotonic and wall clocks, `Duration` and `Instant` on `Int.I64` seconds plus nanoseconds, Gregorian dates for years 0 to 9999, RFC 3339 and HTTP-date (IMF-fixdate) text, and TZif time zones. |
| [`notch`](notch) | `bend-kit-notch@0.1.0.0/notch.bend` | Leveled, structured logging. A logger value holds a minimum level, logfmt or JSON-lines format, and contextual fields. `Notch.info(lg, msg, fields)` writes to stderr with an RFC 3339 time; `Notch.file(handle, lg, level, msg, fields)` writes to a file and returns the handle; `Notch.line` returns the text for other sinks. Disabled levels skip the clock and rendering. |
| [`concurrency`](concurrency) | `bend-kit-concurrency@0.1.0.0/concurrency.bend` | Parallel `par_map` and `par_reduce` over lists and arrays, a worker pool whose workers each own an affine state, `select` over channels, and `timeout`. See [concurrency/README.md](concurrency/README.md). |
| [`redis`](redis) | `bend-kit-redis@0.1.0.0/redis.bend` | Redis and Valkey client: a RESP3 codec over bytes with an incremental reader, TCP or TLS connect with `HELLO 3`, `AUTH`, and `SELECT`, commands, pipelining, and a connection pool. |
| [`llm`](llm) | `bend-kit-llm@0.1.0.0/llm.bend` | LLM client on top of `hairpin` for the Anthropic Messages and OpenAI Chat Completions APIs: typed requests and replies, a raw JSON path for tools and images, retries on 408, 409, 429, and 5xx, and streaming through an incremental SSE parser (`llm/sse.bend`). |

Notch keeps fields in insertion order and does not deduplicate keys. Avoid `time`, `level`, and `msg` as field names in JSON output. `notch/check.bend` shows both formats and the level filter.

Each package is named `bend-kit-<package>` on the hub. The hub versions are `bytes@0.3.0.0`, `encoding@0.3.0.0`, `json@0.5.0.1`, `csv@0.1.0.0`, `cbor@0.1.0.0`, `zlib@0.1.4.0`, `url@0.4.0.0`, `wire@0.4.0.3`, `dns@0.3.2.1`, `http@0.16.0.0`, `http2@0.1.0.0`, `router@0.1.1.0`, `files@0.1.0.0`, `process@0.1.0.1`, `collections@0.1.0.0`, `unicode@0.1.0.0`, `regex@0.6.0.0`, `parse@0.1.0.0`, `int@0.2.0.0`, `fmt@0.1.0.0`, `hash@0.1.0.0`, `crypto@0.1.0.0`, `websocket@0.1.0.0`, `multipart@0.1.0.0`, `random@0.1.0.0`, `time@0.1.0.0`, `concurrency@0.1.0.0`, `notch@0.1.0.0`, `redis@0.1.0.0`, and `llm@0.1.0.0`.

For TOML 1.0, use [Emerging-Patterns/eztoml](https://github.com/Emerging-Patterns/eztoml) (`0xd79254973edee82bcf56616220876efe/main.bend`, v0.5.0). It covers datetimes, numbers, arrays, and tables; a second TOML parser is not part of this kit.

`wire`, `zlib`, `http`, `files`, `process`, `crypto`, `random`, and `time` ship `.c` and `.js` effects. They run host code, and proofs do not cover them.

In `process`, `env` entries are `KEY=VALUE` overrides of the inherited environment. Close the
spawned child's stdin to send EOF, drain stdout and stderr, then call `wait`.
Its C and JS effects require macOS or Linux and are not covered by the proofs.
On the JS target, `run` blocks other Bend fibers until the child exits; use
`spawn` and pipe handles when the program must remain responsive. JS signal
polling uses Bun's built-in FFI C compiler to install a signal-safe handler.

## Layout

Each package is one folder at the root. The folder name is the package name:

```
<package>/
  <package>.bend   entry file; its first comment line is the hub description
  VERSION          the hub version; CI publishes it on merge
  LAWS.bend        the claims
  PROOF.bend       a proof of each claim
  check.bend       runs the package on the native runtime (optional)
  effs/            .c and .js effects (optional)
  bench/           benchmarks (optional)
```

`http` also has `smoke.bend`, which does live fetches, and `demo.bend`, a small server for the serve smoke test. `llm/smoke.bend` sends one reply and one stream to each API whose key is set (`ANTHROPIC_API_KEY` or the bearer `ANTHROPIC_AUTH_TOKEN`, `OPENAI_API_KEY`, with optional `*_BASE_URL` and `*_MODEL`).

## Checks

```sh
scripts/check.sh              # every package
scripts/check.sh bytes http   # some packages
scripts/packages.sh origin/main   # the packages changed since origin/main
```

`check.sh` type-checks the entry file, then runs `PROOF.bend` and `check.bend` in the package folder. `bend PROOF.bend` prints "All terms check." when every law holds.

CI runs `check.sh` once for each package that a pull request changes. A change to `.github/` or `scripts/` checks every package, and so does each push to `main`. The `http` smoke tests run only when `http` changes.

CI installs the Bend version pinned in `scripts/install-bend.sh`, not the latest release. To move to a new Bend, change `VER` and `SHA` in that script. The change touches `scripts/`, so its pull request checks every package on the new version.

On each push to `main`, a package that passes its checks runs `scripts/publish.sh`. It publishes the package as `bend-kit-<package>@<VERSION>` unless that version is already on the hub. If the hub has that version with different files, the job fails, and the package needs a higher `VERSION`. Pull requests run `scripts/publish.sh --check`, which reports the same failure and publishes nothing.
