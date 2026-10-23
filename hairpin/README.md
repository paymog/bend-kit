# hairpin

Hairpin is an HTTP client for Bend 2, built on `bend-kit-http`. One `Client` holds a base URL, default headers, a socket pool, a cookie jar, a client certificate, a redirect mode, a step timeout, a retry policy, and a circuit breaker. Each request uses all of them. The model is undici's `Agent` with ky's instance options.

```bend
import bend-kit-hairpin@0.10.0.0/hairpin.bend as Hairpin
import bend-kit-retry@0.2.0.0/retry.bend as Retry
import bend-kit-http@0.36.0.0/http.bend as Http
import bend-kit-time@0.2.0.0/time.bend as Time
```

Import `bend-kit-http@0.36.0.0` and `bend-kit-retry@0.2.0.0`. Those are the versions `hairpin.bend` imports, and another version has a different `Http.Res` or `Retry.Budget`. `Time` supplies both `Time.mono.ms()` and the `Instant` values that Http uses.

Hairpinning, or NAT loopback, is traffic that goes out and bends back. A request does the same.

## Use

```bend
import Base

def api() -> Hairpin.Client:
  c = Hairpin.base(Hairpin.new(), "https://api.example.com/v1/")
  Hairpin.retry(Hairpin.header(c, "Accept", "application/json"), 2)

def done(r: Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Unit):
  (c, got) = r
  Hairpin.close(c)

def main() -> IO(Unit):
  do IO<Unit>:
    r : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(api(), "users/7")
    done(r)
```

A `Client` is affine. Every request returns the client beside the result; pass that client to the next request, and `Hairpin.close` it at the end to close its idle sockets.

The result is `Result<&1, &1, Hairpin.Err, Http.Res>`. `ErrHttp{e}` is the `Http.Err` of the last attempt. `ErrDenied{why}` means that no attempt started: `DenyLate` (the deadline passed), `DenySpent` (the budget is spent), or `DenyOpen` (the circuit is open).

## Options

| call | default | effect |
|---|---|---|
| `Hairpin.new()` | | 8 idle sockets per origin. `Hairpin.new.with(cap)` sets another cap. |
| `Hairpin.base(c, url)` | none | Each request URL resolves against `url` (RFC 3986 §5.2), so `"users/7"` against `https://api.example.com/v1/` is `https://api.example.com/v1/users/7`. An absolute URL goes as given. With a base that is not an absolute `http` or `https` URL, every request fails with `ErrUrl`. |
| `Hairpin.header(c, k, v)` | none | A default header. A second default of the same name replaces the first. A request header of the same name, in any case, replaces the default. The client sets `Host`, `Connection`, `Content-Length`, and `Transfer-Encoding` itself and drops them from both. |
| `Hairpin.timeout(c, ms)` | 30000 | The step timeout of each connect, write, and read. |
| `Hairpin.redirect(c, mode)` | `Http.ModeFollow{}` | `ModeManual` returns the 3xx; `ModeError` fails with `ErrRedirect`. A chain stops after 20 hops. |
| `Hairpin.retry(c, n)` | 0 | Up to `n` retries: `n + 1` attempts in all. See [Retries](#retries). |
| `Hairpin.deadline(c, ms)` | none | No attempt of a request starts `ms` or more after the request starts. A wait that would reach the deadline ends the request instead. |
| `Hairpin.circuit(c, Retry.Circuit{threshold, window, cooldown, probes})` | none | A circuit breaker in front of every request on this client. See [Circuit breaker](#circuit-breaker). `Hairpin.breaker.of(c)` gives its state back. |
| `Hairpin.cert(c, chain, key)` | none | Paths to a PEM client chain and key for mutual TLS. The identity follows same-origin redirects only, and pooled sockets are kept per identity. |
| `Hairpin.ca(c, path)` | `""` | Path to a PEM CA file, trusted for the server handshake in place of the default store. `""` trusts the default store. Like the certificate, the file follows same-origin redirects only. Requests and streams both use it. |
| `Hairpin.jar(c, jar)` | none | Every hop, redirects and retries included, sends the jar's cookies and stores each `Set-Cookie`. Before each try, the jar's clock moves to `Time.now()`. `Hairpin.jar.of(c)` gives the jar back. |

## Requests

- `Hairpin.request(c, method, url, headers, body)` makes one request. The body is an `Http.Body`.
- `Hairpin.get(c, url)` is a GET with no headers and no body.
- `Hairpin.post.json(c, url, v)` POSTs a `Json.Val` as compact JSON, with `content-type: application/json`.
- `Hairpin.request.in(c, budget, method, url, headers, body)` makes one request inside a caller's retry layer. See [Nested retries](#nested-retries).
- `Hairpin.request.as(~judge, c, budget, idem, enc, method, url, headers, body)` is `request.in` with every choice explicit. See [Your own retry rules](#your-own-retry-rules).
- `Hairpin.open.as(~judge, c, budget, idem, enc, method, url, headers, body)` is `request.as` for a streamed response. See [Streams](#streams).
- `Hairpin.budget(c)` gives the budget that one plain `request` gets: the client's `retry` + 1 attempts and its `deadline` from now.

Everything else is `Http.fetch`: IPv6, DNS order, proxies from `http_proxy`, `https_proxy`, and `no_proxy`, HTTP/2 over ALPN, and body decoding of `gzip`, `deflate`, `br`, and `zstd`. See [../http/README.md](../http/README.md).

For a streamed response under the retry policy, use `open.as`. For a streamed upload, use `Http.upload`. For many requests at once, use `Http.fetch.all`.

## Retries

[`bend-kit-retry`](../retry) is the policy. It is pure; Hairpin reads the clock and calls it. Every `now` in the policy is monotonic milliseconds from `Time.mono.ms()`. Each request runs this loop:

1. **Admit.** `Retry.admit(breaker, budget, now)` checks the deadline, then the budget, then the breaker. Only `GateGo` starts an attempt, and it takes one attempt from the budget. A denial before the first attempt is `ErrDenied{why}`; a later denial returns the last result.
2. **Classify.** `Http.retry.judge` reads the result. A connect error, a timeout, and 408, 429, 500, 502, 503, and 504 are transient. Anything else (a success, another status, another error) is `Settled`; hairpin never answers `Retry.Failed`, so the breaker counts only transient failures. A transient failure of GET, HEAD, OPTIONS, TRACE, PUT, or DELETE is `Transient`, with the server's `Retry-After` (at most 30 s). The same failure of any other method is `Unsafe`.
3. **Tell the breaker.** `Unsafe` and `Transient` count as failures. `Settled` counts as a success.
4. **Plan.** `Retry.plan` stops on `Settled` and `Unsafe`. On `Transient` it waits `Retry-After`, or a backoff of 500 ms doubled per retry up to 30 s, with equal jitter (a wait in `[d/2, d]`). It stops when the budget is spent or when the wait would reach the deadline.

The policy is `Retry.Policy{attempts, base, cap, deadline}`. `Hairpin.retry` sets `attempts`, and `Hairpin.deadline` sets `deadline`.

A retry repeats the request. Hairpin retries only methods that RFC 9110 calls idempotent. That does not make a server's handler safe to repeat: a PUT with side effects is retried too.

## Nested retries

A caller with its own retry loop (an SDK above Hairpin, a job runner) multiplies attempts: 3 outer tries of 3 inner attempts are 9 requests. A shared `Retry.Budget` stops that. Make one budget for the whole operation, pass it to each `Hairpin.request.in`, and pass the budget that comes back to the next call:

```bend
def call(x: Hairpin.Client & Retry.Budget) -> IO(Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res>):
  (c, b) = x
  Hairpin.request.in(c, b, "GET", "jobs/7", Http.empty(), Bytes.new(0))

def start(c: Hairpin.Client) -> IO(Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res>):
  do IO<Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res>>:
    now : Nat <- Time.mono.ms()
    call((c, Retry.Budget.new(4n, now, Some{2000n})))
```

Every attempt of every call takes from the one budget and obeys its deadline. The client's `retry` setting still caps the attempts of each call; the client's `deadline` does not apply, because the budget carries its own. `Retry.Budget` is a plain value, so a layer can build a fresh one. Do not: a layer that builds its own budget resets the count.

## Your own retry rules

`request.in` retries only what `Http.retry.judge` calls transient, and only for an idempotent method. An API with other rules, such as Anthropic's 529 or a POST that the server deduplicates, uses `request.as`:

- `~judge` takes the result of one attempt. It returns the result and `Some{Retry-After}` when another attempt may help (`Some{""}` for no header), or `None{}`. `Hairpin.judge` is the default.
- `idem` says that the request is safe to repeat. When it is `False{}`, a judged failure counts against the breaker but never repeats.
- `enc` is the `Accept-Encoding` value. `Http.codings()` gives every coding that Http decodes. `"identity"` leaves the body as the server sent it.

The budget, the deadline, the backoff, and the breaker apply as for `request.in`.

## Streams

`open.as` takes the same arguments as `request.as` and returns an open `Http.Stream`. The budget, the deadline, the backoff, and the breaker apply as for `request.as`.

- `~judge` takes the result of one open. Read the status and headers with `Http.stream.res`, and give the stream back in the result.
- A refused stream closes when the next attempt is admitted. When no attempt follows, the last stream comes back open, so you can read its error body. Close every stream that comes back.
- A stream opens its own connection, outside the pool. It follows the client's redirect mode, presents its certificate, trusts its CA file, and sends and stores cookies through its jar, as `request.as` does. The jar comes back in the client.

## Circuit breaker

`Retry.Circuit{threshold, window, cooldown, probes}` sets the breaker. [../retry/README.md](../retry/README.md#circuit-breaker) gives its states.

A `Client` has one breaker for all origins. Requests on one client are sequential, so at most one probe is in flight; the `probes` limit matters to a caller that shares a breaker across fibers.

## Guarantees

[../retry/README.md](../retry/README.md#proven-claims) lists the proven claims of the policy. `LAWS.bend` here proves Hairpin's URL resolution, header merge, and outcome classification (`outcome_*`) on fixtures.

The proofs cover the policy, not the IO loop in `hairpin.bend`. Hairpin calls `Retry.admit` before each attempt and `Retry.plan` after it; `check.bend` tests this against a server that counts attempts. A deadline does not cancel an attempt in flight; its connect, write, and read steps each time out after `Hairpin.timeout`. The monotonic clock (`Time.mono.ms`), the random jitter (`IO.random_u32`), the sleep, and the sockets are host code. `request` and `request.in` retry only the methods that RFC 9110 calls idempotent. With `request.as`, the caller's `idem` and `judge` decide, and Hairpin trusts them.

## Checks

`check.bend` runs a local server that accepts exactly one connection per scripted response and then stops listening, so each scenario counts its attempts: a missing attempt times out, and an extra one finds no listener. It checks a redirect that sets a cookie, a 503 retried to a 200, a POST 503 tried once, a 302 in manual mode, 3 attempts for `retry 2`, one attempt for a 404, a deadline that stops after 2 of 6 attempts and one that denies the first, a breaker that opens after 2 failures, denies, and closes after one probe, three nested calls that share a budget of 4: 3 attempts, then 1, then none, a `request.as` judge that retries an idempotent POST through two 404s, an `open.as` stream that opens on the third attempt after two 503s, and an `open.as` stream through a redirect that sends the jar's cookie and the redirect's `Set-Cookie`, with the jar coming back holding both.

`ca-check.sh` makes a private CA and a localhost server signed by it, then runs `ca_check.bend`. A request and a stream, each through a redirect, reach the server with `Hairpin.ca`, and fail with a TLS error without it. CI runs it on both lanes; to run it by hand, use `hairpin/ca-check.sh` for the native lane and `hairpin/ca-check.sh js` for Bun. It needs `openssl` and `python3`.
