import Base
import ./http.bend as Http
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def show_req(req: Http.Req) -> IO(Unit):
  Http.Req{method, path, headers, body} = req
  do IO<Unit>:
    IO.print(method ++ " " ++ path ++ " [" ++ Bytes.to_string(body) ++ "]")
    IO.print(Bytes.to_string(Http.encode(Http.Res{200, Http.empty(), Bytes.from_string("ok")})))

def show(m: Maybe<&1, Http.Req>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{req}:
      show_req(req)

def pool.key() -> String:
  Http.pool.key("http", "127.0.0.1", 47811)

def pool.give.r(p: Http.Pool, r: Result<&1, &1, Http.Err, Http.Conn>) -> IO(Http.Pool):
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, "pool: connect failed")
    case Done{c}:
      Http.pool.give(p, pool.key(), c)

# A new socket to the local listener, given to the pool.
def pool.give.new(p: Http.Pool) -> IO(Http.Pool):
  do IO<Http.Pool>:
    r : Result<&1, &1, Http.Err, Http.Conn> <- Http.conn.open(False{}, 2000, "127.0.0.1", "127.0.0.1", 47811)
    pool.give.r(p, r)

# y when the pool had an idle socket, n when it did not.
def pool.took(+seen: String, pm: Http.Pool & Maybe<&1, Http.Conn>) -> IO(Http.Pool & String):
  (p, m) = pm
  match m:
    case None{}:
      IO.pure(Http.Pool & String, (p, seen ++ "n"))
    case Some{c}:
      do IO<Http.Pool & String>:
        Http.conn.close(c)
        return (p, seen ++ "y")

def pool.take(ps: Http.Pool & String) -> IO(Http.Pool & String):
  (p, +seen) = ps
  pool.took(seen, Http.pool.take(p, pool.key()))

def pool.verdict(ok: Bool, +seen: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("pool " ++ seen)
    case False{}:
      IO.die(Unit, 1, "pool gave " ++ seen)

def pool.report(+want: String, ps: Http.Pool & String) -> IO(Unit):
  (p, +seen) = ps
  do IO<Unit>:
    Http.pool.close(p)
    pool.verdict(String.eq(seen, want), seen)

# Two sockets given, then three takes: want has y for each take that found an idle socket.
def pool.run(p: Http.Pool, +want: String) -> IO(Unit):
  do IO<Unit>:
    p1 : Http.Pool <- pool.give.new(p)
    p2 : Http.Pool <- pool.give.new(p1)
    a : Http.Pool & String <- pool.take((p2, ""))
    b : Http.Pool & String <- pool.take(a)
    c : Http.Pool & String <- pool.take(b)
    pool.report(want, c)

def test.listen6(port: U32) -> IO(Result<&1, &1, U32 & String, Listener & U32>):
  import "../wire/effs/ipv6_test.c"
  import "../wire/effs/ipv6_test.js"

# The shared test twin also declares this UDP effect.
def test.udp6(port: U32) -> IO(Result<&1, &1, U32 & String, Socket & U32>):
  import "../wire/effs/ipv6_test.c"
  import "../wire/effs/ipv6_test.js"

def local.handler(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), Bytes.from_string(Http.header(headers, "host"))})

def local.accept(l: Listener) -> IO(Unit):
  do IO<Unit>:
    m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- Http.conn(~local.handler, 1048576n, m)
    Listener.close(l2)

def local.ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def local.got(+want: String, r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "local fetch failed")
    case Done{res}:
      Http.Res{+status, headers, body} = res
      do IO<Unit>:
        local.ok(U32.is_eq(status, 200), "local status")
        local.ok(String.eq(Bytes.to_string(body), want), "local Host header")

def local.ipv6(r: Result<&1, &1, U32 & String, Listener & U32>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "IPv6 bind: " ++ U32.show(code) ++ " " ++ why)
    case Done{(l, +port)}:
      +want = "[::1]:" ++ U32.show(port)
      do IO<Unit>:
        IO.spawn(Unit, local.accept(l))
        result : Result<&1, &1, Http.Err, Http.Res> <- Http.get("http://" ++ want ++ "/x")
        local.got(want, result)

def local.fallback() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(47812))
    IO.spawn(Unit, local.accept(l))
    result : Result<&1, &1, Http.Err, Http.Res> <- Http.get("http://localhost:47812/x")
    local.got("localhost:47812", result)

def main() -> IO(Unit):
  do IO<Unit>:
    show(Http.parse("GET /x HTTP/1.1\r\n\r\nhello"))
    show(Http.parse("GET /x HTTP/1.1\r\nHost: x\r\n\r\nhello"))
    show(Http.parse("GET /x HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhello"))
    show(Http.parse("GET / HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n"))
    show(Http.parse("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"))
    IO.print(Bytes.to_string(Http.res_body(Http.parse_res("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"))))
    IO.print(Http.sanitize("a\rb\nc"))
    l : Listener <- IO.try(Listener, TCP.listen(47811))
    pool.run(Http.pool.new(), "yyn")
    pool.run(Http.pool.new.with(1), "ynn")
    Listener.close(l)
    r : Result<&1, &1, U32 & String, Listener & U32> <- test.listen6(0)
    local.ipv6(r)
    local.fallback()
