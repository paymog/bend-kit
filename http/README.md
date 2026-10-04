# http

## Actual final-response outcomes (0.29.0.0)

Live whole/context handlers and upload `finish` callbacks now return
`IO(Http.Reply)`: `Reply{response: Http.Res, receipt: Completion.Receipt}`.
The codec's affine `Res` remains unchanged. Import `./completion.bend as
Completion` beside `Http`; use `Unobserved{}` when no application completion
is needed, or `Http.reply.complete(~D, ~done, payload, response)` for typed
request-local `D: Data`. The closed `done` callback receives
`Completion.Completion<D>{payload, status, outcome}` after the final write.
Supported receipts capture Data only through `Completion.receipt`; never hide
a File, Socket, response body, or other affine dependency in a disposable closure.

Configured `server.accept`/`server.run` also require
`~observe: C -> U32 -> Completion.Outcome -> IO(Unit)`. Convenience whole,
stream, and writer entry points require
`~observe: U32 -> Completion.Outcome -> IO(Unit)` after their handler templates.
`Completion.ignore` explicitly opts out. The owner observer runs once for every
final response attempted, including generated 400/408/413/431/503 responses
without an application receipt. Interim `100 Continue`, EOF, silent idle expiry,
and unread connection-cap closure do not fabricate final-response events.

`HostAccepted{}` means the host accepted all final framing/body writes, **not**
that the peer received them. `WriteFailed{code, message}` retains the real host
send/deadline failure. `IncompleteResponse{}` distinguishes a known-length
writer's short or overshooting body. Failure closes the socket without replay
or a replacement HTTP response. Writer failure survives later writes and finish.
Owner and application callbacks run inline outside the private accounting actor,
before active capacity is released; callbacks may query `server.stats`.

`WriteHead<S>` adds an initial receipt after `state`. The writer callback takes
`S -> Writer -> Receipt -> IO(Writer & Receipt)`, returning the actual final
request-local Data receipt. HEAD/204/304 suppression or header failure skips that
callback and reports with the initial receipt. Otherwise completion follows
callback return and the final chunk terminator, not merely a body prefix.

`Completion.open(~D, payload)` optionally returns a receipt and dedicated
one-slot copied-data observer. Its producer sends once without closing the
queued value; the observer owner must `IO.join` or explicitly close it.
Absent/closed observers do not hold transport resources or admission capacity.
An unclosed observer remains its caller's channel-lifetime responsibility.

`python3 -B http/outcome_check.py` passed 168 real-socket outcome cases across
native/JS configured and convenience whole/stream/writer paths, plus 12 retained
server journals. Evidence includes genuine RST, blocked-write deadlines,
known-length short/overshoot, terminal-chunk failure, header-only suppression,
exactly-once business effects, final writer state, observer disposal, and a late
receive after natural transport return. That late callback queried live counts
`(1,1,1)` before listener closure. See [`outcome_results.json`](outcome_results.json)
and [`outcome_verification.json`](outcome_verification.json), including adverse
compiler/gate receipts and all 307 unsafe/foreign exclusions per proof entry.
Human laws are unchanged; socket/clock behavior is runtime evidence, not proof.
#330 still owns stop/drain; #337 owns actual entered policies, notifications,
durations, and logging. This Data seam does not implement or verify those features.

## Finite admission and copied observations (0.28.0.0)

`ServerConfig` adds `buffered` immediately after `requests`. Every production
whole/context, upload-stream, response-writer, configured, and convenience path
reserves connection and buffered-work capacity before spawning its reader or
allocating its initial framing buffer. Exhaustion does not enqueue a reader:
the accepting task closes the unsafe, unread excess socket synchronously.
There is one transient close-only accept slot in addition to admitted sockets;
it has no read buffer, handler, or spawned task. The counters count admitted
ownership, not the kernel's listen backlog or that close-only slot.

A buffered-work unit is **one connection's retained input**, including its
incomplete headers/body, parsed request, and pipelined remainder. It remains
reserved until that connection operation actually returns and its retained
input is erased. Idle sockets deliberately retain their reservation too:
`buffered < connections` therefore reduces admitted sockets to `buffered`.
This conservative policy avoids both a waiting queue and a second parser.
Only one request per connection is framed/handled at a time; a pipelined suffix
is bounded bytes, not a queue of independently parsed requests.

Active capacity is acquired before any whole/writer handler or initial upload
callback. It stays held across subsequent upload callbacks, retained stream
state, response writes, and actual writer callback return. A safely parsed
capacity rejection sends `503` with `Connection: close`, with no application
callback and normal HEAD body suppression. Peer disconnection, write expiry,
and a closed completion observer
cannot replace still-running work. Capacity is returned exactly once after
the actual operation returns; a process crash or permanently stalled operation
does not provide recovery in the still-running process.

`Http.server.observer(~C, server)` returns the listener owner unchanged beside
a copyable `Http.ServerStats`. `Http.server.stats(observer)` returns
`IO(Maybe<&2, Http.ServerCounts>)`, so an owner can monitor while `server.run`
owns the affine listener. Counts contain current connection/active/buffered
ownership, each high-water mark, and separate cumulative connection/active/
buffered rejections. Replies contain only copied data. `None` means the private
accounting controller has closed after the listener and its retained operations
ended; it is not a drain receipt or response-write outcome. Snapshots use a
rendezvous command inbox and fresh one-shot copied replies: a successful send
was received, and a failed post-close send returns `None` without joining an
unanswered reply. The reusable private inbox uses `Chan.recv`, never `IO.join`.

### Quantitative input retention

Let `H = header_bytes`, `B = body_bytes`, `R = 65536` (one packed socket read),
and `T = H + B + R + 1`, using unbounded arithmetic for these bounds. A stable
connection framing state retains at most `H + B + R` logical input octets:
one incomplete header or parsed metadata, one decoded body, and at most one
read's pipelined suffix. During framing, a conservative **`8*T` logical-octet
bound per reserved unit** also includes the old and new header append buffers,
header/suffix slices, the current recv buffer, chunk slices, and simultaneous
body fragments plus their joined body. Repeated progress never accumulates
wire framing or trailers: those are discarded by the existing chunk decoder.

Logical octets are not heap bytes. Additional retained input representation
is quantitatively bounded as follows; these bounds deliberately do not rely on
sharing or compact `Nat` representation:

- Packed buffers use power-of-two U32 arrays. For a positive `n`-byte fragment,
  there are at most `n` U32 slots (one-byte fragments are the worst rounding);
  zero-length buffers add only a fixed number of slots. The aggregate input
  array-slot bound is `8*T + 16`, not one ideal flat `B`-byte allocation.
- Nonempty decoded fragments number at most `B + R`: each contains at least
  one decoded byte, including the one-read over-cap rejection overshoot.
  Original/reversed fragment lists and joining can retain at most
  `2*(B + R) + 16` list/byte-buffer wrappers concurrently.
- Header conversion and parsing retain bounded linked `String` characters,
  not UTF-8 bodies. Conservatively allow `16*(H + 1)` character cells for
  header text, field-line/key/value/path slices, lowercasing, and temporary
  key traversal copies, plus `4*(H + 1)` map/value-list nodes. Patricia-map
  branch positions are at most `33*H`; a unary position representation would
  therefore add at most `132*H*(H + 1)` position cells. This explicitly counts
  metadata overhead rather than equating a 64 KiB header cap with 64 KiB RSS.
- Together, `128*T + 256*H*(H + 1)` retained input term fields is a conservative
  structural envelope, including fixed parser state and array/list/tree
  bookkeeping. At eight bytes per native term field, its term-field-byte bound
  is eight times that expression. Allocation headers/arena reservation,
  scheduler/IO bookkeeping, JS object layout, kernel queues, application
  allocations/response bodies, and callback-spawned work are **not** that bound
  or an RSS guarantee. Stream state is application-owned and can itself grow.

Multiply the per-unit bounds by `buffered` for the admitted transport input
envelope. Rejection draining retains only one `R`-byte scratch read at a time
inside the same connection reservation; its existing total wire drain limit
remains 32 MiB and about 2.5 seconds.

The maximum representable header/body cap is precisely `4294901756`:
`cap + R + 3 <= 4294967295`. The fixed receive overshoot must fit before
`Bytes.words` rounds `len` with `len + 3` in U32; header append and decoded
body accounting must not wrap. Configured and legacy `.with` entry points
reject the first value beyond this boundary, not an arbitrary 1 GiB ceiling.
All three admission capacities remain positive finite U32 values.

### Exercised admission evidence

`python3 -B http/admission_check.py` passed real native and JavaScript sockets
in all three whole/stream/writer modes, independently exceeding connection,
active-operation, and buffered-input caps (18 bursts). Copied public observations
stayed within their caps and matched exact rejection counts; rejected IDs never
entered the business journal. Each profile returned to zero and served a healthy
request. Active tests kept disconnected callbacks and a reset pipelined request
counted until actual return; writer tests first witnessed an actual failed
`Writer` and then kept that callback's capacity until it returned. Parsed HEAD
overload returned bodyless `503` with close and no business effect.

Both lanes also passed concurrent copied snapshots, 128 post-close `None`
results, and explicit joins of both observer tasks. Continuous burst servers
were host-terminated after the checks; that is not graceful-drain evidence.
[`admission_results.json`](admission_results.json) preserves counts and journals;
[`admission_verification.json`](admission_verification.json) preserves commands,
initial own-source checker failures, exclusions, and regression/benchmark output.
Human laws are unchanged; pure checks do not establish unsafe or foreign IO.

The retained limits runner passed all 146 native/JS scenarios; startup passed
sixteen invalid configurations per lane, the exact representability boundary,
bind rollback, readiness, and shared-context requests. The HTTP package gate
passed with 304 entry unsafe/foreign exclusions, and the six-language codec
benchmark kept matching checksums. The migrated Camber transport probe retained
one busy dependency and zero creation effects while 129 incomplete peers were
attempted: quiescent server endpoints were 128 in each lane, versus the retained
historical 131. It recovered and explicitly closed the dependency bundle.
The retained legacy probe exits 48 on bind failure without rollback markers;
its historical `TurnClose` conflates healthy and failed writes. The current
0.29 probe additionally exposes actual write outcomes, without repairing legacy
startup or claiming application lifecycle completion.

## Runtime context, startup ownership, and phase limits (0.27.0.0)

`Http.server.start(~C, ~O, context, owner, config)` returns
`IO(O & Result<&2, &1, Http.StartupError, Http.Server<C>>)`.
`C` is copyable `Data` (configuration and shared channels); `O` is the application's
affine owner, such as preopened files or worker bundles. Both startup branches
return `O` unchanged. Invalid configuration returns `InvalidConfig`; listen failure
returns `BindError{code, message}` rather than terminating through `IO.try`.
The caller can explicitly close or recover its dependencies on either branch.

`Done{server}` is the ready signal: the listener has successfully bound and is
accepting TCP connections. Failure never returns a ready value. The application
may notify its supervisor only after matching `Done`; there is no speculative
readiness callback. `Http.server.accept(~C, ~handler, ~observe, server)` accepts one socket,
starts the existing HTTP connection machine, and returns the server owner plus
the accept result (`Result<&1, &1, U32 & String, Chan(Unit)>`). A successful result
includes a completion channel; joining it observes the whole connection task,
including its final write/close. Listener closure alone is not task completion.
`handler: C -> Http.Req -> IO(Http.Reply)` receives the same runtime
context on every request, including keep-alive and pipelined requests.
`Http.server.run` repeats accepting and returns the listener owner and OS error
if accepting fails. It closes unused completion observers without cancelling
connection tasks; use `server.accept` to retain and join individual task results.
`Http.server.close` explicitly closes the listener; it does not drain
already-started handlers or close application dependencies.

`Http.server.config(host, port)` supplies a 16 MiB body cap, 64 KiB headers,
128 connections, 128 active requests, 128 buffered-input units, and
5/30/30/30-second header/body/idle/write settings. All size, admission and deadline fields are finite `U32` values and
must be positive; zero is an error, never a disabled-limit sentinel. Deadlines
must also fit signed host milliseconds (at most 2147483647). Ports 0–65535
are accepted (0 requests an OS-assigned port).

**Enforced transport contract:** configured servers enforce independent header
and transfer-decoded body caps, and absolute header/body/idle/write deadlines.
Headers start with the first received byte; bodies start after headers finish.
Progress does not replenish either budget. Header/body expiry returns `408` and
closes when a response remains possible; idle expiry closes silently. Header,
body, and malformed-framing rejections remain `431`, `413`, and `400`.
Chunk framing, trailers, and pipelined remainder do not count toward body bytes.
An at-cap header plus an at-cap body is valid even in one larger socket read.
Writes use published Wire 0.4.4.0's bounded packed-write operation; conversion,
framing, and successive pieces share one deadline. Failure closes without replay.

HTTP 0.29.0.0 also preserves final public response-write outcomes as above;
#330 owns cooperative stop/drain and application-resource lifecycle integration.
These deadlines do not cancel handlers or preempt CPU work. On failed streamed
uploads, transport closes but does not explicitly recover/close generic
application-owned callback state; do not infer affine-resource cleanup.

The plain `serve`, `serve.on`, and `.with` convenience APIs keep their existing
closed-handler contract and use 64 KiB headers and 5/30/30/30-second phases.
Their `.with` body cap remains independent. `serve.stream.config` and
`serve.write.config` return validated startup errors and enforce `ServerConfig`.
Internal serving helpers now take `Limits`; `Serving` carries the read phase.
`Writer` owns `Maybe<Socket>` and one absolute deadline; failure immediately
closes and stores `None`, so subsequent writes cannot replay. `writer.finish`
returns `IO(Maybe<Socket>)`. This is a breaking helper/Writer contract.

Run `python3 -B http/startup_check.py` for compiled native and Bun real-socket
checks: returned bind failure without readiness, returned affine file recovery
and close, rejection of every zero policy field, overflowing deadlines and an out-of-range port, and
three requests on two sockets sharing one runtime context/channel. A separate
real request exercises `server.run` before host termination; that is not drain proof.
`startup_results.json` records command/output and sampled direct-process RSS.
IO and the unbounded `talk`/`server.run.loop` loops depend on foreign or unsafe
code and are excluded from pure proof guarantees; the package laws are unchanged.

Run `python3 http/limits_check.py` for the deterministic compiled native/JS socket
regression; `limits_results.json` records 146 observed scenarios across whole,
stream, and writer paths. With 600 ms phase budgets, trickle expiry was about
600–607 ms despite progress at 150/300/450 ms; assertions require less than
900 ms, below a per-progress reset's 1050 ms. Idle expiry was about 800–805 ms.
Pipelined body deadlines begin before upload callbacks. Slow readers receive
only a response prefix then EOF; failed writers close before callbacks return.
Existing native/JS startup, stream, writer suppression/framing, and rejection
delivery scenarios also passed. `limits_verification.json` retains package,
probe, publication-check, and adverse earlier receipts. The HTTP entry's 291
unsafe/foreign exclusions are not mathematical evidence for host socket IO.
No failing-before runtime baseline was run: execution required the coordinator's
exclusive verification slot. Human laws are unchanged.


HTTP/1.1 and HTTP/2 client, and HTTP/1.1 server for Bend 2: `http://` and `https://`, DNS, redirects, and timeouts. Bodies are packed bytes (`Http.Body`).

```bend
import bend-kit-http@0.24.2.0/http.bend as Http
```

`http` imports `bytes`, `wire`, `url`, `json`, `encoding`, `dns`, `zlib`, `http2`, `time`, `int`, and `concurrency` from the hub. `Http.Body` keeps its pinned `bytes` type; the HTTP/2 client uses a newer `bytes` version internally and transfers the packed body without copying.

HTTPS needs OpenSSL 3 at run time. On macOS, `brew install openssl@3`. The client looks for Homebrew's `libssl.3.dylib`, then `libssl.so.3`. Set `BEND_LIBSSL` to the library path if it is somewhere else.

## Fetch

```bend
import Base
import bend-kit-http@0.24.2.0/http.bend as Http

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

A body is an `Http.Body`: bytes packed four to a `U32`. `Http.from_string(s)` makes one from a byte string (one `Char` per octet), and `Http.to_string(b)` turns it back. `Http.length(b)` returns the body and its length in bytes. `Http.Body` is `Bytes.Bytes` from `bend-kit-bytes@0.3.0.0`, so you can also import that package and use it directly. `Http.text(res)` decodes the body as UTF-8. A bad byte becomes U+FFFD. `Http.json(res)` parses the body as JSON in place. Bad UTF-8 in a string gives `None`. `Json.at(v, n)` is an array element. `Json.u32(v)` is a whole number that fits in `U32`. `Url.form(m)` is an `application/x-www-form-urlencoded` body. Space is `%20`.

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
import Base
import ./http.bend as Http
import ./completion.bend as Completion

def hello(req: Http.Req) -> IO(Http.Reply):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.empty(), Http.from_string(path)}, Completion.Unobserved{}})

def main() -> IO(Unit):
  Http.serve.on(~hello, ~Completion.ignore, "127.0.0.1", 18080)
```

`Http.serve.on(~h, ~observe, host, port)` binds to an IPv4 address such as `127.0.0.1` for loopback or `0.0.0.0` for every interface. `Http.serve(~h, ~observe, port)` defaults to `0.0.0.0`; neither writes a start message. `Http.serve.on.with(~h, ~observe, host, port, max)` and `Http.serve.with(~h, ~observe, port, max)` set the maximum request size in bytes; the other entry points default to 16 MiB. Each server reads a whole request, calls `h`, sends its `Reply`, and reports the actual final outcome. HTTP/1.1 connections stay open unless the request or response says `Connection: close`; HTTP/1.0 connections close after each response. Pipelined requests are handled in order. Malformed requests get 400, requests over the cap get 413, and header blocks over 64 KiB get 431. Responses use the RFC 9110 reason phrase; HEAD, 1xx, 204, and 304 have no body.

On a rejected request, the server sends `Connection: close` and drains unread bytes before closing. The drain stops after 32 MiB or about 2.5 seconds. Each read waits at most 50 ms; a peer that sends beyond the bounds can still see a reset. The bounds prevent a slow sender from holding the connection indefinitely.

For bounded uploads, `Http.serve.stream.on.with(~S, ~start, ~piece, ~finish, ~observe, host, port, max)` calls `start` with request headers and an empty body. Each `piece` receives decoded `Bytes.Bytes` and returns `IO(S & Bool)`: updated state and `True{}` to discard the rest, or `False{}` to keep receiving. After the body is read/discarded, `finish` returns `IO(Http.Reply)`. The server owns the connection throughout and reports after the final response write. Reads are at most 64 KiB; `max` retains the normal request-size limit. `Http.serve.stream.with` binds all IPv4 interfaces. See `stream_demo.bend` and `stream_check.py`.

For bounded downloads, `Http.serve.write.on.with(~S, ~start, ~write, ~observe, host, port, max)` calls `start` with a whole request and obtains `Http.WriteHead<S>{status, headers, length, state, receipt}`. `Some{n}` sends `Content-Length: n`; `None{}` sends chunked transfer coding. The callback takes state, `Http.Writer`, and the initial receipt, then returns `IO(Http.Writer & Completion.Receipt)` after `Http.writer.write` calls. Final completion includes chunk termination and actual callback return. Length mismatch or host failure closes without replay; HEAD, 1xx, 204, and 304 suppress the callback and retain its initial receipt. `Http.serve.write.with` binds all IPv4 interfaces. See `write_demo.bend` and `write_check.py`.

## Versions
`0.29.0.0` breaks live serving callback contracts: `Reply` carries typed completion
beside affine `Res`, every serving path takes an owner outcome observer,
`WriteHead` adds a receipt, and writer callbacks return writer plus final receipt.
Pure codec/client response contracts remain unchanged.


`0.23.0.0` builds natively again: a program that imported `0.22.0.0` failed `bend file.bend -o app` with `an arity over 247` (bendlang/bend#1069). The cookie parser now keeps `Expires` as the date sent and `Max-Age` as seconds until it makes the cookie, so the internal helpers `Cav`, `cookie.max_age`, `cookie.av.put`, `cookie.av`, `cookie.avs`, and `cookie.make` changed signature. The jar behaves as before.

`0.22.0.0` adds a pure RFC 6265bis cookie jar and `Http.pool.fetch.jar`. The redirect-loop helpers `pool.one`, `pool.next.move`, `pool.next`, `pool.hops.one`, `pool.hops`, and `pool.final` now pass an optional jar and use a `Hops` state record; code that calls these helpers must migrate.

`0.21.1.0` adds `Http.Fetch` and `Http.fetch.all`, and imports `bend-kit-concurrency@0.1.0.0` for its worker pool.

`0.21.0.0` adds environment-controlled HTTP and HTTPS proxy routing for `fetch` and pooled fetch.

`0.20.1.0` adds `Http.post.json`, `Http.resolve`, and `Http.fetch.retry`, and imports `bend-kit-time@0.1.0.0` for `Retry-After` dates.

`0.20.0.0` adds HTTP/2 to HTTPS `fetch` and pooled fetch. `Conn` now includes `ConnH2`; code that matches `Conn` must handle both variants.

`bend-kit-http@0.14.0.0` is `http@0.13.1` moved to the Bend hub. Each package's hub description links to its folder here. It imports its sibling packages by hash, so their types are shared with your code. `http@0.13.0` is a break from `http@0.12.0`: request and response bodies, stream pieces, and the wire bytes of `encode`, `encode_req`, and `exchange` are `Http.Body`. `http@0.13.1` adds `Http.Body`, `Http.from_string`, `Http.to_string`, and `Http.length`. `Req` and `Res` are `Type`, so a value is used once: its result type is `Result<&1, &1, Http.Err, Http.Res>`. `http@0.12.0` removed the client read internals (`need`, `fetch.gate`, `Sf`). `http@0.11.0` added `GotHead` to `Got`. `http@0.10.0` changed `exchange` to return the socket as `Maybe<Socket>`.
