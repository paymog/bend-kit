# http

An HTTP/1.1 and HTTP/2 client, and an HTTP/1.1 server. Bodies are packed `Bytes`.

```bend
import bend-kit-http@0.32.0.0/http.bend as Http
import bend-kit-http@0.32.0.0/completion.bend as Completion
```

`Http.Body` is `Bytes` from `0x49814d83de8f70993a43e1002be29ecd/bytes.bend`, which the entry file names as bytes `0.3.0.0`. It is not `bend-kit-bytes@0.3.2.0`. JSON values passed to `post.json` come from `0x584fc27920487ceab242392391418d7f/json.bend` (json `0.5.0.1`), not `bend-kit-json@0.5.1.0`. DNS lookup uses `bend-kit-dns@0.6.0.2`. TLS uses `bend-kit-wire@0.4.6.1`.

`hairpin` and the packages on it import `bend-kit-http@0.23.0.1`. That `Http.Res` is a different type.

HTTPS needs OpenSSL 3. On macOS, `brew install openssl@3`. Set `BEND_LIBSSL` if `libssl` is not on the default path. A body over about 30 KB overflows `bend file.bend`. Build with `bend file.bend -o app`.

## Fetch

```bend
import Base
import bend-kit-http@0.32.0.0/http.bend as Http

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

`Http.get(url)` is `fetch("GET", url, Http.empty(), Http.from_string(""))`. `Http.fetch(method, url, headers, body)` is the full call. `fetch.with` adds a per-step timeout in milliseconds. The default is 30 seconds. A redirect chain stops after 20 hops (`ErrRedirect`). `fetch.how` takes `ModeFollow`, `ModeManual`, or `ModeError`. `ETIMEDOUT` is 60 on macOS and 110 on Linux. Both become `ErrTimeout`.

HTTPS `fetch` offers `h2,http/1.1` through ALPN. An HTTP/2 response uses the same `Res` type. Streams and uploads negotiate HTTP/1.1 only. For several addresses, the client tries them in DNS order until TCP connects, within the step timeout. Attempts are sequential.

`fetch` and `pool.fetch` read `http_proxy`, `https_proxy`, and `no_proxy`, or the uppercase names when the lowercase ones are absent. An HTTP proxy gets an absolute-form target. An HTTPS proxy gets `CONNECT` before TLS to the origin. Certificate and host checks still apply. Streaming and uploads connect directly and ignore those variables.

`fetch.cert` presents a PEM client chain and key. The identity follows same-origin redirects and is dropped after a cross-origin redirect. `post.json(url, v)` POSTs compact JSON with `content-type: application/json`. `resolve(base, ref)` applies RFC 3986 §5.2 and returns `None` when `base` is not an absolute `http` or `https` URL. `fetch.retry(n, method, url, headers, body)` allows `n` extra tries of an idempotent method after connect failure, timeout, or 408, 429, 500, 502, 503, or 504.

## Headers and bodies

A header map is `Map<String, List<String>>`. Names are lowercase after parse. `empty` is an empty map. `set` replaces one name. `add` appends. `header` is the first value, or `""`. `fields` is the list. Repeated `Set-Cookie` lines stay separate. A second `Host` or `Content-Length` is rejected.

`from_string` and `to_string` convert a byte string, one `Char` per octet. `length` returns the body and its length. `text` decodes UTF-8 and replaces a bad byte with U+FFFD. `json` parses the body in place. `Url.form` builds an `application/x-www-form-urlencoded` body.

`Http.fetch.ca(method, url, headers, body, ca_path)` trusts the PEM certificates in that file for the server handshake, instead of the default verify paths. Verification stays on. The file follows same-origin redirects and is dropped after a cross-origin redirect. `Http.pool.fetch.ca` keeps those sockets apart from default-trust sockets and from a different file. A missing file is `ErrTls` with EINVAL. This does not present a client certificate; use `fetch.cert` for that.

`fetch` sends `accept-encoding: gzip, deflate`, plus `br` and `zstd` when those libraries load, unless you set `Accept-Encoding`. It decodes `gzip`, `x-gzip`, `deflate`, `br`, `zstd`, and `identity` in reverse order. An unknown coding stays as sent. A corrupt body, or one that decodes past 16 MiB, is `ErrBad`. `content-length` stays the compressed size. `exchange` does not decode. `decoded` is the pure gzip, deflate, and identity path, and the laws cover it.

A response over 16 MiB of body or 64 KiB of head is `ErrBad`. `Content-Length` together with `Transfer-Encoding` is rejected.

## Streams, pools, and cookies

`open` follows redirects and returns a `Stream` when the head is in. `stream.res` is the status and headers. `stream.read` is the next decoded piece, or `None` at the end. `stream.close` closes the socket. `open.raw` returns bytes as sent. `upload` sends a chunked body. `upload.write` sends one piece. `upload.finish` ends the body and returns the response as a `Stream`. Uploads do not follow redirects.

`pool.fetch` is `fetch` on a pool of idle sockets. It returns the pool beside the result. Pass that pool on. `pool.close` closes the idle sockets. The default cap is 8 idle sockets per origin. `pool.new.with(cap)` sets another. A reused socket that fails before any response byte is retried once for GET, HEAD, OPTIONS, TRACE, PUT, and DELETE. For an HTTP/2 origin, the pool keeps one session and closes it after GOAWAY.

`fetch.all(reqs, n)` runs each `Fetch{method, url, headers, body}` on at most `n` workers. Each worker owns a pool. Results stay in request order. A failure is a `Fail` in its place.

`Jar` is a pure cookie store. You pass the clock: `jar.new(now)` and `jar.at(jar, now)`. `pool.fetch.jar` sends matching cookies and stores each `Set-Cookie`, including on redirects. The public-suffix check rejects only a single-label `Domain` such as `com`. It does not ship the Public Suffix List, so `Domain=co.uk` is accepted.

## Serve

A convenience handler returns `IO(Reply)`. `Reply` is the `Res` plus a completion receipt. `Completion.Unobserved{}` means you do not need a callback. `Completion.ignore` opts out of the owner observer.

```bend
import Base
import bend-kit-http@0.32.0.0/http.bend as Http
import bend-kit-http@0.32.0.0/completion.bend as Completion

def hello(req: Http.Req) -> IO(Http.Reply):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.empty(), Http.from_string(path)}, Completion.Unobserved{}})

def main() -> IO(Unit):
  Http.serve.on(~hello, ~Completion.ignore, "127.0.0.1", 18080)
```

`serve.on` binds an address. `serve` binds `0.0.0.0`. Neither prints a start line. `serve.with` and `serve.on.with` set the body cap. The default is 16 MiB. Header cap on these entry points is 64 KiB. Phase deadlines are 5, 30, 30, and 30 seconds for header, body, idle, and write. A bad request is 400, an oversized body is 413, and a head over 64 KiB is 431. HTTP/1.1 connections stay open unless `Connection: close`. Pipelined requests run in order. HEAD, 1xx, 204, and 304 get no body.

`serve.stream.on.with` takes `start`, `piece`, `finish`, and `abort`. `abort` runs on an incomplete upload and must close any handle it owns. It does not call `finish`. `serve.write.on.with` takes `start`, `write`, and `dispose`. `dispose` runs when the body is suppressed or the header write fails. `Some{n}` sends `Content-Length`. `None` sends chunked encoding. A length mismatch closes the socket and does not replay the body.

## Configured server

`server.config(host, port)` is the same caps as above, plus 128 connections, 128 active requests, and 128 buffered-input units. Every size and deadline is a positive `U32`. Zero is an error, not an unlimited setting. A deadline must fit in signed host milliseconds, at most 2147483647. The largest header or body cap that fits is 4294901756. Port 0 asks the OS for a port.

`server.start` returns your affine owner beside `Done{server}` or a `StartupError`. `InvalidConfig` and `BindError` both return the owner, so you can close it. `Done` means the listener is accepting. Do not treat a failure as ready.

`0.31.0.0` adds `fetch.ca` and `pool.fetch.ca`. `Hops` and `Route` gain a `ca` field. A caller that builds those records must pass `""` when it wants the default trust store. `http` imports `bend-kit-wire@0.4.6.0`.

`server.run` consumes the server and returns `ServerExit` after the listener is closed and the accepted work has returned. `server.close` does that close and returns the counts. It waits until handlers and cleanup callbacks return. It can wait forever. `server.stop` refuses new admission and returns `True` the first time. Stop is not drain. You still run or close the server. A callback that does not return is not cancelled. An external supervisor has to enforce a process deadline.

`server.observer` returns a copyable `ServerStats` beside the server, so you can read counts while `run` owns the listener. `stats` returns `None` after the accounting actor has closed. That `None` is not a drain receipt.

`HostAccepted` means the host accepted the writes. It does not mean the peer received them. `WriteFailed` keeps the host error. `IncompleteResponse` is a known-length writer that sent the wrong number of bytes. Failure closes the socket and does not send a replacement response.

A buffered unit is one connection's retained input: incomplete headers, the decoded body, and at most one 64 KiB pipelined suffix. During framing the connection retains at most `8*T` logical octets, where `T` is header bytes + body bytes + 65536 + 1. That is not an RSS figure. Application stream state is extra. Idle sockets keep their reservation, so `buffered` below `connections` lowers how many sockets are admitted.

Rejected connections are closed without a read buffer. A parsed request that exceeds active or buffered capacity gets `503` and `Connection: close`, and the handler is not called. The drain of a rejected request stops after 32 MiB or about 2.5 seconds.

`0.31.1.0` keeps each count in a [`resources`](../resources) pool. A connection reserves one connection unit and one buffered unit together, and a refused buffer returns the connection unit. Every release splits one unit off the grant that its takes joined, so a release with no take stops the server with `Admission.give: no lease of this kind is held` instead of wrapping a counter.

Deadlines do not cancel a handler. Affine erasure does not close an application file or socket. The `abort` and `dispose` callbacks do that, and they must return.

`python3 -B http/drain_check.py`, `http/outcome_check.py`, `http/admission_check.py`, and `http/startup_check.py` are the socket checks for this contract. The laws do not cover the effects.
