# http

HTTP/1.1 and HTTP/2 client, and HTTP/1.1 server for Bend 2: `http://` and `https://`, DNS, redirects, and timeouts. Bodies are packed bytes (`Http.Body`).

```bend
import bend-kit-http@0.22.0.0/http.bend as Http
```

`http` imports `bytes`, `wire`, `url`, `json`, `encoding`, `dns`, `zlib`, `http2`, `time`, `int`, and `concurrency` from the hub. `Http.Body` keeps its pinned `bytes` type; the HTTP/2 client uses a newer `bytes` version internally and transfers the packed body without copying.

HTTPS needs OpenSSL 3 at run time. On macOS, `brew install openssl@3`. The client looks for Homebrew's `libssl.3.dylib`, then `libssl.so.3`. Set `BEND_LIBSSL` to the library path if it is somewhere else.

## Fetch

```bend
import Base

def show(got: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match got:
    case Done{res}:
      Http.Res{status, headers, body} = res
      IO.print(U32.show(status) ++ " " ++ Http.header(headers, "content-type"))
    case Fail{err}:
      match err:
        case Http.ErrUrl{}:
          IO.print("bad url")
        case Http.ErrDns{}:
          IO.print("dns")
        case Http.ErrConnect{code, why}:
          IO.print("connect " ++ U32.show(code) ++ " " ++ why)
        case Http.ErrTls{code, why}:
          IO.print("tls " ++ U32.show(code) ++ " " ++ why)
        case Http.ErrRead{code, why}:
          IO.print("read " ++ U32.show(code) ++ " " ++ why)
        case Http.ErrWrite{code, why}:
          IO.print("write " ++ U32.show(code) ++ " " ++ why)
        case Http.ErrTimeout{}:
          IO.print("timeout")
        case Http.ErrRedirect{}:
          IO.print("redirect")
        case Http.ErrBad{}:
          IO.print("bad response")

def main() -> IO(Unit):
  do IO<Unit>:
    got : Result<&1, &1, Http.Err, Http.Res> <- Http.get("https://example.com/")
    show(got)
```

`Http.fetch(method, url, headers, body)` is the same call with a method, headers, and body. `Http.fetch.with(..., ms)` sets the per-step timeout. The default is 30 seconds. A redirect chain stops after 20 hops (`ErrRedirect`). `Http.fetch.how(..., ms, mode)` chooses the policy: `ModeFollow` follows, `ModeManual` returns the 3xx, `ModeError` fails on a redirect. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Both become `ErrTimeout`.

HTTPS `fetch` offers `h2,http/1.1` through ALPN. An HTTP/2 response uses the same `Http.Res` type as HTTP/1.1. Request headers named by `Connection`, pseudo-headers supplied by the caller, and other hop-by-hop headers are not sent over HTTP/2. Hosts that select HTTP/1.1 keep the existing behavior.

For a host with multiple addresses, the client tries them in DNS order until TCP connects, within the step timeout. `http://[::1]:8080/` connects to IPv6 and sends `Host: [::1]:8080`. Address attempts are sequential, not raced.

`fetch` and `pool.fetch` use `http_proxy`, `https_proxy`, and `no_proxy` (or uppercase names when lowercase is absent). An HTTP proxy receives an absolute-form request target. An HTTPS proxy receives `CONNECT host:port` before the client starts TLS to the origin; certificate and host verification still apply. Proxy URL userinfo supplies HTTP Basic `Proxy-Authorization`. `NO_PROXY` accepts a comma-separated list of hosts, domain suffixes, optional ports, bracketed IPv6 addresses, and `*`. Direct and proxied sockets, including different proxy credentials, have separate pool entries. Only `fetch` uses proxy environment variables; streaming requests and uploads connect directly.

`Http.get` is `fetch("GET", url, Http.empty(), Http.from_string(""))`.

`Http.fetch.cert(method, url, headers, body, cert_path, key_path)` presents a PEM client chain and private key to an HTTPS server. `fetch.cert.with(..., ms)` sets the timeout. The identity follows same-origin redirects but is dropped after a cross-origin redirect, even if a later hop returns. Server certificate and host verification still apply. `Http.pool.fetch.cert(p, method, url, headers, body, cert_path, key_path)` keeps authenticated connections by identity; a socket is never shared with a request without that identity or with another certificate. Run `http/mtls-check.sh` (or `http/mtls-check.sh js`) to exercise generated local certificates.

A response body over about 30 KB overflows `bend file.bend`. Compile it. That needs clang 14 or newer (`apt install clang` on Debian 12 or Ubuntu 22.04 and later; `xcode-select --install` on macOS):

```sh
bend file.bend -o app
```

## Request helpers

`Http.post.json(url, v)` POSTs a `Json.Val` as compact JSON (`Json.encode.bytes`) with `content-type: application/json`.

`Http.resolve(base, ref)` resolves `ref` against the absolute `http` or `https` URL `base` with `Url.resolve` (RFC 3986 §5.2) and gives back a URL string for `fetch`: `Http.resolve("https://api.example.com/v1/", "users/7")` is `Some{"https://api.example.com/v1/users/7"}`. The default port is dropped and an IPv6 host keeps its brackets. It is `None` when `base` is not absolute or `ref` has another scheme.

`Http.fetch.retry(n, method, url, headers, body)` is `fetch` tried again up to `n` more times, so `n = 2` makes at most three tries. It retries only idempotent methods (GET, HEAD, OPTIONS, TRACE, PUT, DELETE), and only after `ErrConnect`, `ErrTimeout`, or a 408, 429, 500, 502, 503, or 504. POST, PATCH, and other methods get one try. Before retry `k` (0 first) it waits the `Retry-After` of the response, as seconds or an HTTP-date, at most 30 s. Without one it waits `half + r mod (half + 1)` ms, where `half` is half of 500 ms doubled `k` times (at most 30 s), and `r` comes from `IO.random_u32`. When the retries run out, the last response or error comes back unchanged. Each try uses a new connection and the step timeout of `fetch`. `LAWS.bend` pins the retry decision, the `Retry-After` reading, and the backoff for fixed `r`.

## Headers

A header map is `Map<String, List<String>>`. Names are lowercase after parse.

`Http.empty()` is an empty map. `Http.set(m, k, v)` replaces `k` with one value. `Http.add(m, k, v)` appends. `Http.header(h, k)` is the first value, or `""`. `Http.fields(h, k)` is the list.

Repeated `Set-Cookie` lines stay separate. Encode writes one line per value. A second `Host` or `Content-Length` is rejected.

## Bodies

A body is an `Http.Body`: bytes packed four to a `U32`. `Http.from_string(s)` makes one from a byte string (one `Char` per octet), and `Http.to_string(b)` turns it back. `Http.length(b)` returns the body and its length in bytes. `Http.Body` is `Bytes.Bytes` from `bend-kit-bytes@0.2.0.0`, so you can also import that package and use it directly. `Http.text(res)` decodes the body as UTF-8. A bad byte becomes U+FFFD. `Http.json(res)` parses the body as JSON in place. Bad UTF-8 in a string gives `None`. `Json.at(v, n)` is an array element. `Json.u32(v)` is a whole number that fits in `U32`. `Url.form(m)` is an `application/x-www-form-urlencoded` body. Space is `%20`.

A response with `Transfer-Encoding` other than `chunked` is read until the connection closes. The bytes are not decoded. `Content-Length` together with `Transfer-Encoding` is rejected. A response over 16 MiB of body and 64 KiB of head is `ErrBad`. `Http.after(raw, head)` is the bytes after a complete self-delimited message, or `None` if the message is not finished or runs until close. `Http.encode_req(method, target, host, headers, body)` is the request as an `Http.Body`; `Http.encode_req.on(..., False)` sends `keep-alive`. `Http.exchange(tls, ms, close, head, socket, bytes)` writes one request on that socket. It returns `Some{socket}` when the socket can take another request, the result, and any bytes already read past the response.

## Compressed bodies

`fetch` sends `accept-encoding: gzip, deflate, br, zstd` unless you set `Accept-Encoding` yourself. It lists `br` and `zstd` only when libbrotlidec and libzstd load. It decodes the body per `Content-Encoding`: `gzip` and `x-gzip` (every member) through libz, `br` through libbrotlidec, `zstd` through libzstd, `deflate` with or without the zlib wrapper through the pure decoder, and `identity`. A list of codings is undone in reverse order. A coding it did not ask for leaves the body as sent. A corrupt body, or one that decodes past 16 MiB, is `ErrBad`. The headers stay as the server sent them, so `content-length` is the compressed size. `exchange` never decodes.

`Http.decoded(res)` decodes a response you got another way, with the pure `bend-kit-zlib` decoders: `gzip`, `x-gzip`, `deflate`, and `identity`. It needs no C library, and `LAWS.bend` covers it. `bend-kit-zlib` has the native effects too: `Zlib.inflate.words`, `Zlib.gzip.words`, `Zlib.brotli.words`, and `Zlib.zstd.words`.

## Streams

`Http.open(method, url, headers, body)` follows redirects like `fetch` and returns a `Stream` as soon as the head is in. It advertises the same `Accept-Encoding` as `fetch` unless you set that header. `Http.stream.res(st)` gives the status and headers (its body is empty). `Http.stream.read(st)` returns the next decoded piece of the body as an `Http.Body`, or `None` at the end; a piece is never empty. Codings are undone in reverse order. An unknown coding leaves the body as sent. The headers stay as sent, so `content-length` is the compressed size. `Http.stream.close(st)` closes the connection and releases any decoders. `Http.open.raw(...)` and `Http.open.raw.with(..., ms)` send no extra `Accept-Encoding` and return bytes as sent, for proxies. Content-Length, chunked, and close-delimited bodies all stream, and interim 1xx responses are skipped. Streaming a 50 MB uncompressed body keeps the program under 10 MB.

Streams and streamed uploads negotiate HTTP/1.1 only.

`Http.upload(method, url, headers)` sends the head with `Transfer-Encoding: chunked`. `Http.upload.write(up, piece)` sends one `Http.Body` chunk; an empty piece sends nothing. `Http.upload.finish(up)` ends the body and returns the response as a `Stream`. A streamed request body cannot be replayed, so uploads do not follow redirects. `open.with` and `upload.with` take a step timeout.

## Pool

```bend
def next(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Http.Pool & Result<&1, &1, Http.Err, Http.Res>):
  (p, first) = pr
  Http.pool.fetch(p, "GET", "https://example.com/b", Http.empty(), Http.from_string(""))

def done(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  (p, second) = pr
  Http.pool.close(p)

def main() -> IO(Unit):
  do IO<Unit>:
    r1 : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <- Http.pool.fetch(Http.pool.new(), "GET", "https://example.com/a", Http.empty(), Http.from_string(""))
    r2 : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <- next(r1)
    done(r2)
```

`Http.pool.fetch(p, method, url, headers, body)` is `fetch` on the pool's idle sockets. It returns the pool with the result. Pass that pool to the next call. A pool holds up to 8 idle sockets per scheme, host, and port; `Http.pool.new.with(cap)` sets another cap. A request takes the socket given back last. When a socket comes back past the cap, the pool closes the oldest one of that origin. Redirects use the pool too. When a reused socket fails before any response byte, a GET, HEAD, OPTIONS, TRACE, PUT, or DELETE is retried once on a new connection; other methods fail. `Http.pool.fetch.with(..., ms)` sets the step timeout. `Http.pool.how(..., ms, mode)` sets the redirect mode. `Http.pool.close(p)` closes the idle sockets. `Http.fetch` is a pool of its own that closes when the call ends.

For HTTPS origins that select HTTP/2, the pool keeps one session per origin and reuses it for sequential requests. It closes a session after GOAWAY. HTTP/1.1 sockets use the configured cap.

## Many requests

```bend
def get(url: String) -> Http.Fetch:
  Http.Fetch{"GET", url, Http.empty(), Http.from_string("")}

def main() -> IO(Unit):
  do IO<Unit>:
    rs : List<Result<&1, &1, Http.Err, Http.Res>> <- Http.fetch.all([get("https://example.com/a"), get("https://example.com/b")], 8)
    IO.print("done")
```

`Http.fetch.all(reqs, n)` makes each `Http.Fetch{method, url, headers, body}` as `Http.fetch` would, on at most `n` workers at once, and returns the results in the order of `reqs`. A failed request is a `Fail` in its place; the others go on. `n = 0` runs one worker, a list shorter than `n` runs one worker per request, and an empty list starts none.

The workers are `Conc.pool` from `bend-kit-concurrency`, and each one owns its own `Http.Pool`. A `Pool` is affine, so it cannot be shared between workers; one pool per worker needs no owner task or message protocol, and a worker reuses its idle sockets for its later requests. The cost is up to `n` connections to one origin rather than one shared set. Every worker's pool is closed when the list is done. The workers are IO computations on Bend's event loop, so the requests overlap while each waits on the network.

## Cookies

```bend
import bend-kit-time@0.1.0.0/time.bend as Time

def login(now: Time.Instant) -> IO(Http.Pool & Http.Jar & Result<&1, &1, Http.Err, Http.Res>):
  Http.pool.fetch.jar(Http.pool.new(), Http.jar.new(now), "POST", "https://example.com/login", Http.empty(), Http.from_string("user=a"))
```

`Http.Jar` is a pure cookie store (RFC 6265bis §5), a `Data` value you pass along. Its clock is yours: `Http.jar.new(now)` starts an empty jar at a `Time.Instant`, and `Http.jar.at(jar, now)` moves it to a later time and evicts the cookies that expired by then. Nothing in the jar reads the clock itself.

- `Http.jar.store(jar, url, res) -> Http.Jar & Http.Res` stores every `set-cookie` field of `res` as received from `url`, and hands `res` back.
- `Http.jar.apply(jar, url, headers) -> Map<&2, List<&2, String>>` puts the jar's cookies for `url` in the `cookie` field, after any cookie value already there, as one field.
- `Http.jar.cookies(jar)` lists the stored `Http.Cookie{name, value, domain, host_only, path, secure, http_only, same_site, expiry}` values, oldest first.
- `Http.pool.fetch.jar(p, jar, method, url, headers, body) -> IO(Http.Pool & Http.Jar & Result<...>)` is `pool.fetch` with a jar: before every hop, redirects included, the jar's cookies for that URL join the request, and every response's `Set-Cookie`, redirects included, goes into the jar. Your own `Cookie` header still follows the redirect rules (dropped on a cross-origin hop); jar cookies go only where they match.

Storage follows §5.6 and §5.7: `Domain` (a leading dot is dropped) widens a cookie from host-only to subdomains and must domain-match the host; `Path` must start with `/`, else the request's default path is used; `Max-Age` beats `Expires`; a zero or negative `Max-Age`, or an `Expires` in the past, deletes the cookie with the same name, domain, and path; no cookie lives past 400 days. `Secure` cookies come only from, and go only to, `https`, and a plain-`http` response cannot overlay a secure cookie. `SameSite=None` needs `Secure`, and the `__Secure-` and `__Host-` prefixes are enforced. `HttpOnly` and `SameSite` are kept but not enforced: `fetch` has no browsing client, so every request counts as same-site. Cookies are sent longest path first. Cookies ignore ports, as the RFC says.

The public-suffix check rejects only a single-label `Domain` such as `com`. Multi-label suffixes such as `co.uk` or `github.io` need the Public Suffix List, which the jar does not ship, so `Domain=co.uk` from `a.co.uk` is accepted.
## Serve

```bend
def hello(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), Http.from_string(path)})

def main() -> IO(Unit):
  Http.serve(~hello, 18080)
```

`Http.serve(~h, port)` reads each request until it is whole, calls `h`, and sends the response. HTTP/1.1 connections stay open unless the request or response says `Connection: close`; HTTP/1.0 connections close after each response. Pipelined requests are handled in order. `Http.serve.with(~h, port, max)` sets the maximum request size in bytes; `serve` defaults to 16 MiB. A malformed request gets 400, a request over the cap gets 413, and a header block over 64 KiB gets 431. Chunked bodies are decoded as they arrive, so a large upload costs time in proportion to its size. An idle client is dropped after 30 seconds. Responses use the RFC 9110 reason phrase. HEAD, 1xx, 204, and 304 responses have no body.

## Versions

`0.22.0.0` adds a pure RFC 6265bis cookie jar and `Http.pool.fetch.jar`. The redirect-loop helpers `pool.one`, `pool.next.move`, `pool.next`, `pool.hops.one`, `pool.hops`, and `pool.final` now pass an optional jar and use a `Hops` state record; code that calls these helpers must migrate.

`0.21.1.0` adds `Http.Fetch` and `Http.fetch.all`, and imports `bend-kit-concurrency@0.1.0.0` for its worker pool.

`0.21.0.0` adds environment-controlled HTTP and HTTPS proxy routing for `fetch` and pooled fetch.

`0.20.1.0` adds `Http.post.json`, `Http.resolve`, and `Http.fetch.retry`, and imports `bend-kit-time@0.1.0.0` for `Retry-After` dates.

`0.20.0.0` adds HTTP/2 to HTTPS `fetch` and pooled fetch. `Conn` now includes `ConnH2`; code that matches `Conn` must handle both variants.

`bend-kit-http@0.14.0.0` is `http@0.13.1` moved to the Bend hub. Each package's hub description links to its folder here. It imports its sibling packages by hash, so their types are shared with your code. `http@0.13.0` is a break from `http@0.12.0`: request and response bodies, stream pieces, and the wire bytes of `encode`, `encode_req`, and `exchange` are `Http.Body`. `http@0.13.1` adds `Http.Body`, `Http.from_string`, `Http.to_string`, and `Http.length`. `Req` and `Res` are `Type`, so a value is used once: its result type is `Result<&1, &1, Http.Err, Http.Res>`. `http@0.12.0` removed the client read internals (`need`, `fetch.gate`, `Sf`). `http@0.11.0` added `GotHead` to `Got`. `http@0.10.0` changed `exchange` to return the socket as `Maybe<Socket>`.
