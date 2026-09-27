# bend-kit roadmap

The goal is a general-purpose library for Bend 2: the packages a program needs that Base does not have, each proved against its laws. This is a ranked backlog, not a promise. The top of **Next** is what we work on now. Each checkbox is one outcome. Re-rank items when evidence changes.

New packages are tracked as GitHub issues with a `pri-high`, `pri-med`, or `pri-low` label: high is what most programs need first, low is what can wait. `gh issue list --label pri-high` lists one priority. Each new package gets its own folder; see the layout in [README.md](README.md).

## Current baseline

- All 20 packages are named `bend-kit-<package>` on the Bend hub; [README.md](README.md) lists each version and hash. Each description links to its source folder. `http` and `dns` import their siblings by hash, so callers share their types.
- Laws: http 176, url 57, json 40, hash 41, bytes 122, regex 54, unicode 35, zlib 22, dns 18, random 13, encoding 12, router 3. Run `scripts/check.sh` to check them all.
- Big bodies need a native build (`bend file.bend -o app`). The `bend file.bend` runner overflows on strings over about 30 KB.

### bytes

- `bytes@0.1.0` (`67341da`) is a byte buffer packed four bytes to a `U32` `Array` slot. It has bounds-checked `get`/`set`, `slice`, `append`, `concat`, `find`, and `eq`, and it converts to and from byte strings. `bytes/bench` measures the layout.
- `bytes` also reads and writes u16, u32, and u64 in both byte orders (`get.u32be`, `set.u16le`, `get.u64be`, ...), searches with `find.from`, `rfind`, `starts_with`, `ends_with`, and `split`, orders buffers with `cmp`, and converts to and from hex and padded base64. The u64 forms use `int`'s `Int.U64`, which is slow until Base has a native `U64`. `append` writes into the left buffer while it has room and at least doubles it when it does not, so building 200 K bytes one at a time takes 0.6 s instead of 215 s.

### wire

- `wire` holds the effects Base lacks: byte-exact TCP/UDP, a TCP connect with a deadline, and TLS through OpenSSL 3 loaded at run time (`BEND_LIBSSL` overrides the path). Each effect has a C and a JS version. The `.words` forms move bytes in the `bytes` layout, with no list cell per byte (`52ca321`).

### unicode

- `unicode` has Unicode 17.0.0 general category, canonical combining class, NFC and NFD, full case folding, and extended grapheme clusters, in pure Bend. `gen.py` generates the tables from the UCD. `conformance.py` passes every line of `NormalizationTest.txt` (NFC and NFD) and `GraphemeBreakTest.txt`. It is not published yet.

### regex

- `regex` compiles RE2 syntax to a Pike VM with capture groups and matches in linear time: `(a*)*b` against 200 000 a's takes 267 ms. Its fixtures agree with Go's `regexp`. It is not published yet.

### http

- `Http.fetch(method, url, headers, body)` does http and https, DNS, redirects (20 hops), and a 30 s timeout per step. It runs on a pool of its own that it closes; `Http.pool.*` keeps one idle socket per origin across calls and retries an idempotent request once when a reused socket fails before any response byte (`b566beb`). `fetch.with(..., ms)` sets the timeout. It returns `Result<Res, Err>`: bad URL, DNS, connect, TLS (errno and verify text), read, write, timeout, too many redirects, or a malformed response. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Headers are a list per name. `header` is the first value. `Set-Cookie` is never joined. Encode writes one line per value.
- Bodies are `Http.Body` (`Bytes.Bytes` from `bend-kit-bytes`, with `Http.from_string`, `to_string`, and `length`): `Req.body`, `Res.body`, request bodies, stream pieces, and the wire bytes of `encode`, `encode_req`, and `exchange`. The `String` parsers (`parse`, `frame`) stay as the spec. `Http.text` decodes UTF-8. `Http.json` parses that text. `Url.form` writes a form body. `fetch` sends `accept-encoding: gzip, deflate` and decodes gzip and deflate through the `zlib` package (`4787d29`); an unknown coding is left as sent. `Http.open`/`stream.read` and `Http.upload` stream bodies in pieces (`ec55a76`).
- A bad chunk or bad framing is `FrameBad` while the connection is still open. A close-delimited TLS body that ends without `close_notify` is a read error. Content-Length and chunked bodies do not wait for that close. `100` and `103` are skipped; `101` is final.
- `fetch`, `exchange`, and streams read into `Bytes` and frame each read once: the head is parsed when it is whole, and chunk data runs are sliced whole. A Content-Length body of up to 16 MiB is allocated once from its length, and each read is written into it (#52). At 12 MiB a download takes about 8 ms in-process and peaks at 19 MB of RSS, down from 32 MB: the body sits in a 16 MiB array (arrays are a power of two in size). Chunked and close-delimited bodies still join their pieces at the end, and peak at about 33 MB. Streaming the same body with `Http.open` peaks at 2.4 MB. It took 1.1 s and 1.1 GB with Content-Length, and 27.5 s chunked, which re-framed the whole buffer after every read (`http/bench/fetch16.bend`). A `String` body alone held 434 MB. The cap is 16 MiB of body and 64 KiB of head; before, a body of exactly 16 MiB failed.
- `Dns.resolve` checks `/etc/hosts`, then the first three nameservers. `resolve.at` asks one server. A silent server is 2 attempts × 5 s, then the next server. `Http.exchange` does one request on an open socket and says whether that socket can take another.
- `Http.serve` reads into `Bytes`, parses the head once, and joins the body once; chunk data runs are sliced whole. A 16 MiB upload takes about 0.03 s, down from 2.7 s on a `String` buffer and 0.26 s with a `String` body (`f3ceb23`, `http/bench/serve16.bend`). A 12 MiB response goes out in about 25 ms. It sends 100 Continue when a request expects it. It keeps HTTP/1.1 connections open and answers pipelined requests in order (`a7d28f7`). `serve.with` sets the request cap; the default is 16 MiB. A bad request is 400, an oversized one 413, a head over 64 KiB 431. It sends the RFC 9110 reason phrase, no body for HEAD, 1xx, 204 and 304, and accepts `HTTP/1.0` without `Host`.
- Header lines, request targets, and URLs parse in linear time. They were O(n²), so a 70 KB header or a 32 KB `Location` held a worker for 20 to 30 s (`05cbd5b`, `7487a84`). The `url` package has no `@unsafe` defs.
- The README install and fetch example pass on clean Debian 12 containers (arm64 and amd64), in the runner and as a native build. The x86_64 Mac is not tested.

## Next

- [ ] **Prove universal laws.** Most laws are fixtures. Add laws over all inputs for the claims that matter most: `res.frame` agrees with `frame` for every split of the bytes, `dc.feed` of `a ++ b` equals feeding `a` then `b`, `parse.got` never says Bad to a prefix of a valid request, `utf8.decode(utf8.encode(s)) == s`, `Json.parse.bytes(Json.encode.bytes(v)) == Some{v}`, and `Bytes.to_string(Bytes.from_string(s)) == s` for every byte string.
- [ ] **Report the runner overflow upstream.** `String.repeat`/`String.length` on about 30 KB overflows in the `bend file.bend` runner but not in native builds. Report it to Bend with the three-line repro.

### Tier 1

- [ ] Bytes: endian ints, builder, search, compare (#20)
- [x] Integer types: U8, U16, U64, I32, I64 (#21)
- [ ] Filesystem and paths (#22)
- [ ] Process and OS (#23)
- [x] Generic collections (#24). A hash map can now build on `hash` (#27).
- [x] Text formatting and number parsing (#25)
- [x] Time: clock, Duration, Instant, dates, time zones (#26). The TZ rule in a TZif footer is not applied yet, so times past a zone's last transition keep its last offset (#198).

### Tier 2

- [x] Non-cryptographic hashing (#27): FNV-1a, xxHash, SipHash-1-3, CRC-32, and Adler-32 over `Bytes`. `zlib` still has its own CRC-32 and Adler-32.
- [x] Cryptography: SHA-2, SHA-1, HMAC, HKDF, secure random (#28)
- [x] Random numbers: seeded PRNGs and distributions (#29). `F64` distributions such as normal wait on F64 (#37).
- [ ] Property-based testing (#30)
- [x] Regex (linear time, RE2-style) (#32)
- [ ] Serialization: CSV, TOML, CBOR/MessagePack, YAML (#33)
- [x] CLI argument parsing (#34): use [shake](https://github.com/Emerging-Patterns/shake) from the hub
- [ ] Logging (#35)
- [ ] Big numbers: BigInt, BigDecimal, rationals (#36)
- [ ] F64: 64-bit floating point (#37)

### Tier 3

- [x] Parser combinators (#38)
- [x] Compression through libz, libzstd, and libbrotlidec, and `http` decoding with them (#142)
- [ ] Concurrency helpers (#40)
- [ ] Databases: SQLite binding, Postgres client (#41)
- [ ] Networking: WebSocket, cookies, multipart (#42)
- [ ] Templating and Markdown (#43)
- [ ] Math and statistics (#44)
- [ ] Proof library: reusable lemmas (#45)
- [ ] Diff and text utilities (#46)

### Existing packages

- [ ] **Decode bodies without a `String` copy.** `decoded` turns a compressed body into a `String` for `zlib` and the result back into `Bytes`. The native effects in #142 take and return the `Bytes` layout, which removes both copies.
- [ ] **Speed up JSON.** On the 1.36 MB bench document, `Json.parse.bytes` takes 3 ms and `Json.encode.bytes` 4 ms; Bun takes about 2 ms and 1 ms. The encoder still takes one step per byte.
- [ ] **Stream in the server.** `serve` hands the handler a whole `Req` and sends a whole `Res`. Add a handler form that reads the request body and writes the response in pieces, on the same `Rb`/`ck` framing the client streams use.
- [ ] **Lingering close in `serve`.** After a 400, 413, or 431, `serve` closes with unread client bytes, so the client may get an RST instead of the response. Stop writing, drain for a moment, then close.
- [ ] **IPv6.** `Dns.resolve` goes through `getaddrinfo` (#93) but asks for `AF_INET` only, and the runtime's `io_sys_addr` connects over IPv4 only. Ask for AAAA too and add IPv6 connect.

## Later

- [ ] **JSON number to F32.** `Json.at` and `Json.u32` exist. `json.encode` is still `@unsafe` because it walks a work list.
- [ ] `Bytes` as map keys. Base's `Map` is a trie over `String` keys and takes no comparator, so `Bytes.cmp` cannot key it. Use `Bytes.to_string` as the key, or add an ordered map over `cmp`.
- [ ] More than one idle socket per origin in the pool, and decoding inside streams.
- [ ] A cookie jar, proxies (`HTTP_PROXY`), client certificates, ALPN, HTTP/2.
- [ ] Windows support (the effects use POSIX sockets and `dlopen`).
- [ ] Test on an x86_64 Mac.

## Depends on the Bend hub

- The hub registers at most five new names per account per day.
- Packages ship `.c` and `.js` effects that run host code, and proofs do not cover them. The hub does not show this before import.

When an item is done, link its commit here and remove it.
