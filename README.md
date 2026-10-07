# bend-kit

Packages for Bend 2 that Base does not include. Each package has its own laws and its own hub version. Networking came first, so `http` and the packages under it are the most complete. [ROADMAP.md](ROADMAP.md) is the backlog.

This project was called bend-net. The old hub names, `bend-net-*`, still resolve. They get no new versions.

Licensed under Apache-2.0. See [LICENSE](LICENSE).

## Install

You need [Bend 2.0.35 or newer](https://bend-lang.com/install.sh) and [Bun 1.4.2](https://bun.sh/docs/installation). macOS or Linux, including WSL. Windows is not supported.

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

`http@0.30.0.0` imports `bend-kit-wire@0.4.5.0`, `bend-kit-http2@0.1.2.0`, `bend-kit-dns@0.5.0.0`, `bend-kit-time@0.1.0.0`, `bend-kit-int@0.2.0.0`, and `bend-kit-concurrency@0.1.0.0`. Its entry file also names these hashes as url `0.4.1.0`, encoding `0.3.0.0`, json `0.5.0.1`, bytes `0.3.0.0`, and zlib `0.2.0.0`:

```
0x1f2d80f53f971b16c6de6a65cb1918ae/url.bend
0xcfc8be7b076f41f95c8e118383892d55/encoding.bend
0x584fc27920487ceab242392391418d7f/json.bend
0x49814d83de8f70993a43e1002be29ecd/bytes.bend
0xaca98ab7f724003ea421c18792cafe52/zlib.bend
```

`Http.Body` is that bytes hash, not `bend-kit-bytes@0.3.2.0`. `bend-kit-json@0.5.1.0` is a later publish than the json hash above.

`hairpin@0.1.0.0`, and `oauth2`, `jwt`, `sigv4`, `llm`, and `webhooks`, import `bend-kit-http@0.23.0.1`. That `Http.Res` is not `bend-kit-http@0.30.0.0`.

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
| [`bignum`](bignum) | `bend-kit-bignum@0.1.0.0/bigint.bend` | Exact integers, decimals, and rationals. Import `decimal.bend` or `rational.bend` for those types. |
| [`json`](json) | `bend-kit-json@0.5.1.0/json.bend` | JSON values as RFC 8259, over `Bytes`. |
| [`csv`](csv) | `bend-kit-csv@0.1.0.0/csv.bend` | RFC 4180 records over `Bytes`. |
| [`cbor`](cbor) | `bend-kit-cbor@0.1.0.1/cbor.bend` | RFC 8949 encode and decode over `Bytes`. |
| [`tar`](tar) | `bend-kit-tar@0.2.0.0/tar.bend` | POSIX ustar and PAX archives over `Bytes`. |
| [`archive`](archive) | `bend-kit-archive@0.2.0.0/archive.bend` | ZIP read: stored and DEFLATE entries, checked against CRC-32. |
| [`zlib`](zlib) | `bend-kit-zlib@0.2.0.0/zlib.bend` | DEFLATE, gzip, and zlib, plus native gzip, zstd, and brotli. |

### Network

| Package | Import | What it does |
|---|---|---|
| [`url`](url) | `bend-kit-url@0.4.1.0/url.bend` | RFC 3986 parse, resolve, and percent-encoding. |
| [`netip`](netip) | `bend-kit-netip@0.1.0.0/netip.bend` | IPv4, IPv6, and CIDR values. No DNS. |
| [`dns`](dns) | `bend-kit-dns@0.6.0.0/dns.bend` | DNS codec and host lookup. |
| [`wire`](wire) | `bend-kit-wire@0.4.6.0/wire.bend` | TCP, UDP, and TLS sockets. |
| [`http`](http) | `bend-kit-http@0.30.0.0/http.bend` | HTTP/1.1 and HTTP/2 client, and an HTTP/1.1 server. |
| [`http2`](http2) | `bend-kit-http2@0.1.2.0/http2.bend` | RFC 9113 frames and an HTTP/2 client. HPACK is `hpack.bend`. |
| [`hairpin`](hairpin) | `bend-kit-hairpin@0.1.0.0/hairpin.bend` | An HTTP client: base URL, headers, pool, cookies, redirects, and retries. |
| [`websocket`](websocket) | `bend-kit-websocket@0.1.0.0/websocket.bend` | RFC 6455 client handshake and frames. |
| [`multipart`](multipart) | `bend-kit-multipart@0.1.0.0/multipart.bend` | RFC 7578 form-data encode and decode. |

### Identity

| Package | Import | What it does |
|---|---|---|
| [`crypto`](crypto) | `bend-kit-crypto@0.2.2.0/crypto.bend` | Digests, HMAC, HKDF, AEAD, scrypt, RSA, and P-256 through OpenSSL 3. |
| [`oauth2`](oauth2) | `bend-kit-oauth2@0.1.0.0/oauth2.bend` | Client credentials, refresh, and authorization code with PKCE. |
| [`jwt`](jwt) | `bend-kit-jwt@0.1.0.0/jwt.bend` | HS256/384/512, RS256, and ES256, plus JWKS lookup. |
| [`sigv4`](sigv4) | `bend-kit-sigv4@0.1.0.0/sigv4.bend` | AWS Signature V4 and S3 over `hairpin`. |
| [`webhooks`](webhooks) | `bend-kit-webhooks@0.1.0.0/webhooks.bend` | Standard Webhooks, Stripe, and GitHub signature checks. |

### Programs

| Package | Import | What it does |
|---|---|---|
| [`files`](files) | `bend-kit-files@0.1.1.0/files.bend` | POSIX paths, directories, and packed file IO. |
| [`stream`](stream) | `bend-kit-stream@0.1.0.0/stream.bend` | Bounded copies between files and TCP/TLS sockets. |
| [`process`](process) | `bend-kit-process@0.2.0.0/process.bend` | Commands without a shell, with byte-exact stdin, stdout, and stderr. |
| [`collections`](collections) | `bend-kit-collections@0.1.2.0/omap.bend` | Ordered maps, a hash map, a vector, a deque, and a heap. Import the file you need. |
| [`time`](time) | `bend-kit-time@0.1.2.0/time.bend` | Clocks, dates, RFC 3339, HTTP-date, and TZif zones. |
| [`random`](random) | `bend-kit-random@0.1.0.0/random.bend` | Seeded xoshiro128**. Not for cryptography. |
| [`concurrency`](concurrency) | `bend-kit-concurrency@0.1.0.0/concurrency.bend` | Parallel map and reduce, a worker pool, `select`, and `timeout`. |
| [`notch`](notch) | `bend-kit-notch@0.1.0.0/notch.bend` | Leveled logfmt or JSON-lines logging. |
| [`tty`](tty) | `bend-kit-tty@0.1.0.0/tty.bend` | Terminal size, color, and display width. |
| [`router`](router) | `bend-kit-router@0.2.0.0/router.bend` | Prepared HTTP routes. Target parsing is `target.bend`. |
| [`property`](property) | `bend-kit-property@0.1.0.0/property.bend` | Seeded generators, shrinking, and a property runner. |

### Services

| Package | Import | What it does |
|---|---|---|
| [`sqlite`](sqlite) | `bend-kit-sqlite@0.1.0.0/sqlite.bend` | Prepared statements through libsqlite3. |
| [`postgres`](postgres) | `bend-kit-postgres@0.1.0.1/postgres.bend` | Postgres protocol 3.0, SCRAM-SHA-256, and a pool. |
| [`redis`](redis) | `bend-kit-redis@0.1.0.1/redis.bend` | Redis and Valkey over RESP3, with pipelining and a pool. |
| [`llm`](llm) | `bend-kit-llm@0.1.0.0/llm.bend` | Anthropic Messages and OpenAI Chat Completions, including SSE. |

### Applications

| Package | Import | What it does |
|---|---|---|
| [`camber`](camber) | `bend-kit-camber@0.6.0.0/camber.bend` | Prepared HTTP applications, typed inputs, and bounded dependency owners. |

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

`check.sh` type-checks the entry file, then runs `PROOF.bend` and `check.bend`. CI checks each package a pull request changes. A change under `.github/` or `scripts/`, and each push to `main`, checks every package.

CI installs the Bend version pinned in `scripts/install-bend.sh`. To move to a new Bend, change `VER` and `SHA` in that script.

On each push to `main`, a package that passes its checks is published as `bend-kit-<package>@<VERSION>` unless that version is already on the hub. If the hub has that version with different files, the job fails and `VERSION` must rise. Pull requests run `scripts/publish.sh --check` and publish nothing.
