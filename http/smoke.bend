import Base
import ./http.bend as Http
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-http2@0.2.0.0/http2.bend as H2


def line(kind: String, url: String) -> IO(Unit):
  IO.print(kind ++ " " ++ url)

def ok_page.go(url: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      line("ok", url)
    case False{}:
      line("fail", url)

def ok_page(url: String, m: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match m:
    case Fail{e}:
      line("fail", url)
    case Done{res}:
      Http.Res{+status, headers, body} = res
      ok_page.go(url, U32.is_eq(status, 200))

def ok_tls(url: String, m: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match m:
    case Fail{e}:
      match e:
        case Http.ErrTls{code, why}:
          line("ok", url)
        case Http.ErrUrl{}:
          line("fail", url)
        case Http.ErrDns{}:
          line("fail", url)
        case Http.ErrConnect{code, why}:
          line("fail", url)
        case Http.ErrRead{code, why}:
          line("fail", url)
        case Http.ErrWrite{code, why}:
          line("fail", url)
        case Http.ErrTimeout{}:
          line("fail", url)
        case Http.ErrRedirect{}:
          line("fail", url)
        case Http.ErrBad{}:
          line("fail", url)
    case Done{res}:
      line("fail", url)

def page(+url: String) -> IO(Unit):
  do IO<Unit>:
    m : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch.with("GET", url, Http.empty(), Bytes.new(0), 15000)
    ok_page(url, m)

def tls(+url: String) -> IO(Unit):
  do IO<Unit>:
    m : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch.with("GET", url, Http.empty(), Bytes.new(0), 15000)
    ok_tls(url, m)

def h2.status(ok: Bool, p: Http.Pool) -> IO(Http.Pool):
  match ok:
    case True{}:
      IO.pure(Http.Pool, p)
    case False{}:
      do IO<Http.Pool>:
        Http.pool.close(p)
        IO.die(Http.Pool, 1, "HTTP/2 response mapping was wrong")

def h2.checked(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Http.Pool):
  (p, r) = pr
  match r:
    case Fail{e}:
      do IO<Http.Pool>:
        Http.pool.close(p)
        IO.die(Http.Pool, 1, "HTTP/2 fetch failed")
    case Done{Http.Res{+status, headers, body}}:
      h2.status(Bool.and(U32.is_eq(status, 200),
        Bool.and(String.eq(Http.header(headers, "content-type"), "text/html; charset=utf-8"),
          String.eq(Bytes.to_string(body), "hello"))), p)

def h2.fetch(p: Http.Pool) -> IO(Http.Pool):
  do IO<Http.Pool>:
    pr : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch(p, "GET", "https://http2.testserver.host/base64/aGVsbG8=", Http.empty(), Bytes.new(0))
    h2.checked(pr)

def h2.status.check(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok h2 pooled two streams")
    case False{}:
      IO.die(Unit, 1, "HTTP/2 pool did not reuse the session")

def h2.inspected(taken: Http.Pool & Maybe<&1, Http.Conn>) -> IO(Unit):
  (p, found) = taken
  match found:
    case None{}:
      do IO<Unit>:
        Http.pool.close(p)
        IO.die(Unit, 1, "HTTP/2 connection was not pooled")
    case Some{c}:
      match c:
        case Http.Conn{tls, s}:
          do IO<Unit>:
            Http.conn.close(Http.Conn{tls, s})
            Http.pool.close(p)
            IO.die(Unit, 1, "HTTP/2-only endpoint negotiated HTTP/1.1")
        case Http.ConnH2{s, H2.Client{input, streams, encoder, decoder, +control}}:
          H2.Control{+next, active, frame_max, initial, max_streams, send_window,
            recv_window, first, ack, continuation, goaway} = control
          do IO<Unit>:
            Http.conn.close(Http.ConnH2{s, H2.Client{input, streams, encoder, decoder, control}})
            Http.pool.close(p)
            h2.status.check(U32.is_eq(next, 5))

def main() -> IO(Unit):
  do IO<Unit>:
    page("http://example.com/")
    page("https://example.com/")
    tls("https://expired.badssl.com/")
    tls("https://wrong.host.badssl.com/")
    tls("https://self-signed.badssl.com/")
    page("https://http1.testserver.host/status/200")
    first : Http.Pool <- h2.fetch(Http.pool.new())
    second : Http.Pool <- h2.fetch(first)
    h2.inspected(Http.pool.take(second, "https://http2.testserver.host:443"))
