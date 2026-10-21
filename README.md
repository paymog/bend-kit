# bend-kit

Packages for Bend 2 that Base does not include. Each package has its own laws and its own hub version. Networking came first, so `http` and the packages under it are the most complete. [ROADMAP.md](ROADMAP.md) is the backlog.

This project was called bend-net. The old hub names, `bend-net-*`, still resolve. They get no new versions.

Licensed under Apache-2.0. See [LICENSE](LICENSE). [Contributing](CONTRIBUTING.md). [Security](SECURITY.md).

[![ci](https://github.com/paymog/bend-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/paymog/bend-kit/actions/workflows/ci.yml)

## Install

You need [Bend 2.0.37 or newer](https://bend-lang.com/install.sh) and [Bun 1.4.2](https://bun.sh/docs/installation). macOS or Linux, including WSL. Windows is not supported.

```bend
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

def show(r: Bytes.Bytes & U32) -> IO(Unit):
  (b, n) = r
  IO.print(U32.show(n) ++ " " ++ Bytes.to_string(b))

def main() -> IO(Unit):
  show(Bytes.length(Bytes.from_string("hi")))
```

`bend` fetches that import and checks it against the published hash. `bend-kit-bytes@0.3.2.0` is `0x185ae03c75e3e75be1171471f68b43cb`. A name and its hash are the same package. A different version is a different type.

The kit is in alpha. Types, names, and entry points can change. There is no compatibility shim. A break raises the second number of `VERSION`, from `0.3.0.0` to `0.4.0.0`, and the packages that import it move with it.

## Proofs

Each package has `LAWS.bend` and `PROOF.bend`. In that folder, `bend PROOF.bend` prints `All terms check.` when every law holds. Proofs do not cover `.c` and `.js` effects. Those effects run host code.

## Same type

Import the version the callee imports when you pass it a value. The newest folder version is often a different type. Each package README names the pins in its entry file.

`http@0.35.0.0` imports its siblings by name: `wire@0.4.6.1`, `http2@0.3.0.0`, `bytes@0.3.2.0`, `time@0.2.0.0`, `int@0.2.0.0`, `concurrency@0.2.0.0`, `url@0.4.1.0`, `encoding@0.4.0.0`, `json@0.6.1.1`, `dns@0.6.0.2`, and `zlib@0.3.0.0`. `Http.Body` is `bend-kit-bytes@0.3.2.0`.

`hairpin@0.10.0.0`, `camber@0.12.0.0`, `jwt@0.9.0.0`, `llm@0.10.0.0`, `oauth2@0.9.0.0`, `sigv4@0.9.0.0`, and `webhooks@0.9.0.0` import `bend-kit-http@0.36.0.0`, and all but `camber` import `bend-kit-hairpin@0.10.0.0`. A program that uses these versions together carries one copy of each C effect.

## Native libraries

The effects load these libraries at run time. Set the override when the library is not on the default search path. On macOS, `brew install openssl@3` covers TLS and crypto.

| Library | Used by | Override |
|---|---|---|
| OpenSSL 3 `libssl` | `wire` TLS, HTTPS in `http` and `hairpin` | `BEND_LIBSSL` |
| OpenSSL 3 `libcrypto` | `crypto`, and signing or secure random through it | `BEND_LIBCRYPTO` |
| `libsqlite3` | `sqlite` | `BEND_LIBSQLITE` |
| `libz` | `zlib` inflate and gzip, `archive` DEFLATE, `http` gzip | `BEND_LIBZ` |
| `libzstd` | `zlib` and `http` zstd | `BEND_LIBZSTD` |
| `libbrotlidec` | `zlib` and `http` brotli | `BEND_LIBBROTLIDEC` |

`files`, `process`, `dns`, `time`, `random`, and `tty` call the OS through effects. They do not load one of those libraries. Proofs do not cover any of these effects.

## Calling the packages

A `Socket`, `File`, `Cursor`, or `Client` is used once. The call returns the handle beside the result. Pass that handle on.

Octet buffers are `Bytes`: four octets in each `U32`. Use `String` for short text, such as header fields, paths, URLs, and code points.

`match` takes a parameter, not a computed value. Match a `Result` in a helper.

A body over about 30 KB overflows `bend file.bend`. Build it with `bend file.bend -o app`.

Each package README has the import, one example, and the limits that change the call. `bench/README.md` records timings. CI does not run benches.

## Packages

### Bytes and text

| Package | Import | What it does |
|---|---|---|
| [`bytes`](bytes) | `bend-kit-bytes@0.3.2.0/bytes.bend` | Packed byte buffers, cursors, endian integers, search, hex, and base64. |
| [`encoding`](encoding) | `bend-kit-encoding@0.3.0.0/encoding.bend` | UTF-8 between `String` and `Bytes`. |
| [`unicode`](unicode) | `bend-kit-unicode@0.1.0.0/unicode.bend` | Unicode 17.0 category, NFC/NFD, case folding, and grapheme clusters. |
| [`regex`](regex) | `bend-kit-regex@0.6.0.4/regex.bend` | Linear-time RE2 matching, with capture groups. |
| [`parse`](parse) | `bend-kit-parse@0.1.0.1/parse.bend` | Parser combinators over text. `parse/json.bend` is a JSON grammar on them, not the `json` package. |
| [`fmt`](fmt) | `bend-kit-fmt@0.1.0.0/fmt.bend` | A string builder, `{}` formatting, padding, and shortest `F32` text. |
| [`int`](int) | `bend-kit-int@0.2.0.0/int.bend` | `U8`, `U16`, `U64`, `I32`, and `I64`. `U64` and `I64` are slow. |
| [`hash`](hash) | `bend-kit-hash@0.1.0.0/hash.bend` | FNV-1a, xxHash, SipHash-1-3, CRC-32, and Adler-32. Not cryptographic. |

### Numbers and data

| Package | Import | What it does |
|---|---|---|
| [`f64`](f64) | `bend-kit-f64@0.1.0.0/f64.bend` | IEEE 754 binary64 add, subtract, multiply, and divide. Soft-float on two `U32` halves. |
| [`bignum`](bignum) | `bend-kit-bignum@0.1.0.0/bigint.bend` | Exact integers, decimals, and rationals. Import `decimal.bend` or `rational.bend` for those types. |
| [`json`](json) | `bend-kit-json@0.5.1.0/json.bend` | JSON values as RFC 8259, over `Bytes`. |
| [`csv`](csv) | `bend-kit-csv@0.1.0.0/csv.bend` | RFC 4180 records over `Bytes`. |
| [`cbor`](cbor) | `bend-kit-cbor@0.1.0.1/cbor.bend` | RFC 8949 encode and decode over `Bytes`. |
| [`protobuf`](protobuf) | `bend-kit-protobuf@0.1.0.0/protobuf.bend` | Pure bounded proto3 messages over `Bytes`, with typed `protoc` code generation. |
| [`tar`](tar) | `bend-kit-tar@0.2.0.0/tar.bend` | POSIX ustar and PAX archives over `Bytes`. |
| [`archive`](archive) | `bend-kit-archive@0.2.0.1/archive.bend` | ZIP read: stored and DEFLATE entries, checked against CRC-32. |
| [`zlib`](zlib) | `bend-kit-zlib@0.2.0.1/zlib.bend` | DEFLATE, gzip, and zlib, plus native gzip, zstd, and brotli. |

### Network

| Package | Import | What it does |
|---|---|---|
| [`url`](url) | `bend-kit-url@0.4.1.0/url.bend` | RFC 3986 parse, resolve, and percent-encoding. |
| [`netip`](netip) | `bend-kit-netip@0.1.0.0/netip.bend` | IPv4, IPv6, and CIDR values. No DNS. |
| [`dns`](dns) | `bend-kit-dns@0.6.0.2/dns.bend` | DNS codec and host lookup. |
| [`wire`](wire) | `bend-kit-wire@0.4.6.1/wire.bend` | TCP, UDP, and TLS sockets. |
| [`http`](http) | `bend-kit-http@0.36.0.0/http.bend` | HTTP/1.1 and HTTP/2 client, and an HTTP/1.1 server. |
| [`http2`](http2) | `bend-kit-http2@0.2.0.0/http2.bend` | RFC 9113 frames and an HTTP/2 client. HPACK is `hpack.bend`. |
| [`hairpin`](hairpin) | `bend-kit-hairpin@0.10.0.0/hairpin.bend` | An HTTP client: base URL, headers, pool, cookies, redirects, streams, and proven retries with a shared budget, deadlines, and a circuit breaker. |
| [`retry`](retry) | `bend-kit-retry@0.2.0.0/retry.bend` | A pure retry policy: a shared attempt budget, a deadline, bounded backoff with jitter, and a circuit breaker, with proofs. |
| [`websocket`](websocket) | `bend-kit-websocket@0.3.0.0/websocket.bend` | RFC 6455 client handshake and frames. |
| [`multipart`](multipart) | `bend-kit-multipart@0.2.0.1/multipart.bend` | RFC 7578 form-data encode and decode. |

### Identity

| Package | Import | What it does |
|---|---|---|
| [`crypto`](crypto) | `bend-kit-crypto@0.2.2.1/crypto.bend` | Digests, HMAC, HKDF, AEAD, scrypt, RSA, and P-256 through OpenSSL 3. |
| [`oauth2`](oauth2) | `bend-kit-oauth2@0.9.0.0/oauth2.bend` | Client credentials, refresh, and authorization code with PKCE. |
| [`authz`](authz) | `bend-kit-authz@0.1.0.0/authz.bend` | Pure authorization policies: deny-overrides, default deny, intersection, and fail-closed missing context. |
| [`jwt`](jwt) | `bend-kit-jwt@0.9.0.0/jwt.bend` | HS256/384/512, RS256, and ES256, plus JWKS lookup. |
| [`sigv4`](sigv4) | `bend-kit-sigv4@0.9.0.0/sigv4.bend` | AWS Signature V4 and S3 over `hairpin`. |
| [`webhooks`](webhooks) | `bend-kit-webhooks@0.9.0.0/webhooks.bend` | Standard Webhooks, Stripe, and GitHub signature checks. |

### Programs

| Package | Import | What it does |
|---|---|---|
| [`files`](files) | `bend-kit-files@0.1.1.1/files.bend` | POSIX paths, directories, and packed file IO. |
| [`stream`](stream) | `bend-kit-stream@0.1.0.1/stream.bend` | Bounded copies between files and TCP/TLS sockets. |
| [`process`](process) | `bend-kit-process@0.4.0.0/process.bend` | Commands with a child working directory and byte-exact stdin, stdout, and stderr. |
| [`collections`](collections) | `bend-kit-collections@0.1.3.0/omap.bend` | Ordered maps, a hash map, a vector, a deque, a heap, and comparators. Import the file you need. |
| [`time`](time) | `bend-kit-time@0.1.3.0/time.bend` | Clocks, dates, RFC 3339, HTTP-date, and TZif zones. |
| [`random`](random) | `bend-kit-random@0.1.0.1/random.bend` | Seeded xoshiro128**. Not for cryptography. |
| [`concurrency`](concurrency) | `bend-kit-concurrency@0.2.0.0/concurrency.bend` | Parallel map and reduce, a worker pool, `select`, and `timeout`. |
| [`scheduler`](scheduler) | `bend-kit-scheduler@0.3.0.0/queue.bend` | Pure stable deadline queues, cancellation tokens, and bounded recurrence planning. |
| [`resources`](resources) | `bend-kit-resources@0.1.0.0/resources.bend` | Bounded capacity pools with affine reservations: reserve, release, split, and combine. |
| [`journal`](journal) | `bend-kit-journal@0.1.0.0/journal.bend` | An append-only journal: checksummed frames, fsync'd appends, and proven crash recovery of the committed prefix. |
| [`runner`](runner) | `bend-kit-runner@0.8.0.0/runner.bend` | A durable job runner: a journaled queue, a bounded pool, retry with dead tickets, a breaker per target, and an inbox for other fibers, with proven replay and journal compaction. |
| [`commands`](commands) | `bend-kit-commands@0.2.0.0/commands.bend` | Retry-safe commands: deduplication by id, recorded replies, and state, record, and outbox committed in one SQLite transaction, with proofs. |
| [`cache`](cache) | `bend-kit-cache@0.2.0.0/cache.bend` | Cache validity: expiry, negative results, invalidation, and generation-safe fetch completion. |
| [`notch`](notch) | `bend-kit-notch@0.3.0.0/notch.bend` | Leveled logfmt or JSON-lines logging. |
| [`tty`](tty) | `bend-kit-tty@0.1.0.1/tty.bend` | Terminal size, color, and display width. |
| [`router`](router) | `bend-kit-router@0.2.0.0/router.bend` | Prepared HTTP routes. Target parsing is `target.bend`. |
| [`property`](property) | `bend-kit-property@0.2.0.0/property.bend` | Seeded generators, shrinking, and a property runner. |
| [`lemmas`](lemmas) | `bend-kit-lemmas@0.1.0.0/lemmas.bend` | Proved laws that relate `Word` and `U32` arithmetic to `Nat`, on top of `bend-mathlib`. |

### Services

| Package | Import | What it does |
|---|---|---|
| [`sqlite`](sqlite) | `bend-kit-sqlite@0.1.0.1/sqlite.bend` | Prepared statements through libsqlite3. |
| [`postgres`](postgres) | `bend-kit-postgres@0.1.0.2/postgres.bend` | Postgres protocol 3.0, SCRAM-SHA-256, and a pool. |
| [`redis`](redis) | `bend-kit-redis@0.1.0.2/redis.bend` | Redis and Valkey over RESP3, with pipelining and a pool. |
| [`llm`](llm) | `bend-kit-llm@0.10.0.0/llm.bend` | Anthropic Messages and OpenAI Chat Completions, including SSE. |

### Applications

| Package | Import | What it does |
|---|---|---|
| [`camber`](camber) | `bend-kit-camber@0.12.0.0/camber.bend` | Prepared HTTP applications, typed inputs, and bounded dependency owners. |
| [`gateway`](gateway) | `bend-kit-gateway@0.2.0.0/gateway.bend` | A guarded read-through gateway: authorize, admit, serve from cache, and fetch on a miss, with proofs that every path gives its unit back. `app.bend` is the Camber app. |

For TOML 1.0, use [Emerging-Patterns/eztoml](https://github.com/Emerging-Patterns/eztoml) (`0xd79254973edee82bcf56616220876efe/main.bend`, v0.5.0). For CLI arguments, use [shake](https://github.com/Emerging-Patterns/shake).

## Layout

Each package is one folder. The folder name is the package name.

```
<package>/
  <package>.bend   entry file; its first comment line is the hub description
  VERSION          the hub version; CI publishes it on merge to main
  LAWS.bend        the claims
  PROOF.bend       a proof of each claim
  check.bend       native examples, when the package has them
  effs/            .c and .js effects, when the package has them
  bench/           timings, run by hand
```

`http/smoke.bend` does live fetches. `llm/smoke.bend`, `postgres/smoke.bend`, and `redis/smoke.bend` talk to a live service when their keys or server are set.

## Checks

```sh
scripts/check.sh              # every package
scripts/check.sh bytes http   # some packages
scripts/packages.sh origin/main
```

`check.sh` type-checks the entry file, then runs `PROOF.bend` and `check.bend`. CI checks each package a pull request changes. A change under `.github/` or `scripts/`, and each push to `main`, checks every package. A package with `effs/*.c`, and `webhooks`, also runs `scripts/native-check.sh`. `scripts/pins.sh` fails a pull request whose changed packages import a sibling at a version other than its `VERSION`, or by hash; `scripts/pins.allow` lists the exceptions.

CI installs the Bend version pinned in `scripts/install-bend.sh`. To move to a new Bend, change `VER` and `SHA` in that script.

On each push to `main`, a package that passes its checks is published as `bend-kit-<package>@<VERSION>` unless that version is already on the hub. If the hub has that version with different files, the job fails and `VERSION` must rise. Pull requests run `scripts/publish.sh --check` and publish nothing.
