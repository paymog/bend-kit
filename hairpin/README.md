# hairpin

Hairpin is an HTTP client for Bend 2, built on `bend-kit-http`. One `Client` holds a base URL, default headers, a socket pool, a cookie jar, a client certificate, a redirect mode, a step timeout, and a retry count. Each request uses all of them. The model is undici's `Agent` with ky's instance options.

```bend
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
```

Hairpinning, or NAT loopback, is traffic that goes out and bends back. A request does the same.

## Use

```bend
import Base

def api() -> Hairpin.Client:
  c = Hairpin.base(Hairpin.new(), "https://api.example.com/v1/")
  Hairpin.retry(Hairpin.header(c, "Accept", "application/json"), 2)

def done(r: Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  (c, got) = r
  Hairpin.close(c)

def main() -> IO(Unit):
  do IO<Unit>:
    r : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- Hairpin.get(api(), "users/7")
    done(r)
```

A `Client` is affine. Every request returns the client beside the result; pass that client to the next request, and `Hairpin.close` it at the end to close its idle sockets.

## Options

| call | default | effect |
|---|---|---|
| `Hairpin.new()` | | 8 idle sockets per origin. `Hairpin.new.with(cap)` sets another cap. |
| `Hairpin.base(c, url)` | none | Each request URL resolves against `url` (RFC 3986 §5.2), so `"users/7"` against `https://api.example.com/v1/` is `https://api.example.com/v1/users/7`. An absolute URL goes as given. With a base that is not an absolute `http` or `https` URL, every request fails with `ErrUrl`. |
| `Hairpin.header(c, k, v)` | none | A default header. A second default of the same name replaces the first. A request header of the same name, in any case, replaces the default. The client sets `Host`, `Connection`, `Content-Length`, and `Transfer-Encoding` itself and drops them from both. |
| `Hairpin.timeout(c, ms)` | 30000 | The step timeout of each connect, write, and read. |
| `Hairpin.redirect(c, mode)` | `Http.ModeFollow{}` | `ModeManual` returns the 3xx; `ModeError` fails with `ErrRedirect`. A chain stops after 20 hops. |
| `Hairpin.retry(c, n)` | 0 | Up to `n` more tries, with the `Http.fetch.retry` policy: only GET, HEAD, OPTIONS, TRACE, PUT, and DELETE, only after `ErrConnect`, `ErrTimeout`, or a 408, 429, 500, 502, 503, or 504. The wait is `Retry-After` (at most 30 s), or a backoff with jitter. When the tries run out, the last result comes back. Tries use the pool. |
| `Hairpin.cert(c, chain, key)` | none | Paths to a PEM client chain and key for mutual TLS. The identity follows same-origin redirects only, and pooled sockets are kept per identity. |
| `Hairpin.jar(c, jar)` | none | Every hop, redirects and retries included, sends the jar's cookies and stores each `Set-Cookie`. Before each try, the jar's clock moves to `Time.now()`. `Hairpin.jar.of(c)` gives the jar back. |

## Requests

- `Hairpin.request(c, method, url, headers, body)` makes one request. The body is an `Http.Body`.
- `Hairpin.get(c, url)` is a GET with no headers and no body.
- `Hairpin.post.json(c, url, v)` POSTs a `Json.Val` as compact JSON, with `content-type: application/json`.

Everything else is `Http.fetch`: IPv6, DNS order, proxies from `http_proxy`, `https_proxy`, and `no_proxy`, HTTP/2 over ALPN, and body decoding of `gzip`, `deflate`, `br`, and `zstd`. The result is `Result<&1, &1, Http.Err, Http.Res>`, as in `http`. See [../http/README.md](../http/README.md).

Hairpin does not stream. For a streamed body, use `Http.open` and `Http.upload`. For many requests at once, use `Http.fetch.all`.

## Checks

`LAWS.bend` covers the URL resolution and the header merge. `check.bend` runs a local server and makes one client take a redirect that sets a cookie, retry a 503, give a POST one try, and return a 302 in manual mode.
