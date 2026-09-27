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
