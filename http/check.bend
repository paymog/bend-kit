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

def local.gz.sent(m: Socket & Result<&1, &1, U32 & String, Unit>) -> Socket:
  (s, r) = m
  s

def local.gz.send(s: Socket, b: Bytes.Bytes) -> IO(Socket):
  do IO<Socket>:
    m : Socket & Result<&1, &1, U32 & String, Unit> <- Http.io.send.bytes(False{}, s, b)
    return local.gz.sent(m)

def local.gz.body.last(l: Listener, s: Socket, first: Bytes.Bytes, pair: Bytes.Bytes & Bytes.Bytes, header: String) -> IO(Listener):
  (old, last) = pair
  do IO<Listener>:
    s1 : Socket <- local.gz.send(s, Bytes.from_string(header))
    s2 : Socket <- local.gz.send(s1, first)
    IO.sleep(40)
    s3 : Socket <- local.gz.send(s2, last)
    Http.io.close(False{}, s3)
    return l

def local.gz.body.first(l: Listener, s: Socket, pair: Bytes.Bytes & Bytes.Bytes, header: String, +split: U32, +remaining: U32) -> IO(Listener):
  (whole, first) = pair
  local.gz.body.last(l, s, first, Bytes.slice(whole, split, remaining), header)

def local.gz.body(l: Listener, s: Socket, b: Bytes.Bytes, header: String, +split: U32, +remaining: U32) -> IO(Listener):
  local.gz.body.first(l, s, Bytes.slice(b, 0, split), header, split, remaining)

def local.gz.hex(l: Listener, s: Socket, m: Maybe<&1, Bytes.Bytes>, header: String, +split: U32, +remaining: U32) -> IO(Listener):
  match m:
    case None{}:
      IO.die(Listener, 1, "invalid compressed fixture")
    case Some{b}:
      local.gz.body(l, s, b, header, split, remaining)

def local.gz.received(l: Listener, recv: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Listener):
  (s, result) = recv
  local.gz.hex(l, s, Bytes.from_hex("1f8b08000000000002ff4bcc29c84854484a2d4954484fcccd4d040045445d3410000000"),
    "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: 36\r\nConnection: close\r\n\r\n", 10, 26)

def local.deflate.received(l: Listener, recv: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Listener):
  (s, result) = recv
  local.gz.hex(l, s, Bytes.from_hex("cb48cdc9c957284a2c0700"),
    "HTTP/1.1 200 OK\r\nContent-Encoding: deflate\r\nContent-Length: 11\r\nConnection: close\r\n\r\n", 1, 10)

def local.gz.dispatch(raw: Bool, l: Listener, recv: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Listener):
  match raw:
    case True{}:
      local.deflate.received(l, recv)
    case False{}:
      local.gz.received(l, recv)

def local.gz.reply(raw: Bool, m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  match r:
    case Fail{e}:
      IO.die(Listener, 1, "compressed accept failed")
    case Done{s}:
      do IO<Listener>:
        recv : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
          Http.io.recv.words(False{}, s, 4096, 2000)
        local.gz.dispatch(raw, l, recv)

def local.gz.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- local.gz.reply(False{}, a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- local.gz.reply(False{}, b)
    c : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- local.gz.reply(True{}, c)
    Listener.close(l3)

type Gr is Type:
  GrRead{st: Http.Stream, acc: Bytes.Bytes, count: U32}
  GrGot{m: Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>>, acc: Bytes.Bytes, count: U32}

def local.gz.read(fuel: Nat, step: Gr) -> IO(Http.Stream & Bytes.Bytes & U32):
  match fuel:
    case 0n:
      IO.die(Http.Stream & Bytes.Bytes & U32, 1, "gzip stream did not end")
    case 1n+p:
      match step:
        case GrRead{st, acc, +count}:
          do IO<Http.Stream & Bytes.Bytes & U32>:
            m : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(st)
            local.gz.read(p, GrGot{m, acc, count})
        case GrGot{m, acc, +count}:
          (s, r) = m
          match r:
            case Fail{e}:
              IO.die(Http.Stream & Bytes.Bytes & U32, 1, "gzip stream read failed")
            case Done{part}:
              match part:
                case None{}:
                  IO.pure(Http.Stream & Bytes.Bytes & U32, (s, acc, count))
                case Some{b}:
                  local.gz.read(p, GrRead{s, Bytes.append(acc, b), (count + 1 : U32)})

def local.gz.checked(+want: String, +pieces: U32, got: Http.Stream & Bytes.Bytes & U32) -> IO(Unit):
  (end, body, count) = got
  do IO<Unit>:
    local.ok(String.eq(Bytes.to_hex(body), want), "gzip stream bytes")
    local.ok(U32.is_eq(count, pieces), "gzip stream piece count")
    Http.stream.close(end)

def local.gz.check(+want: String, +pieces: U32, r: Result<&1, &1, Http.Err, Http.Stream>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "gzip stream open failed")
    case Done{st}:
      do IO<Unit>:
        got : Http.Stream & Bytes.Bytes & U32 <- local.gz.read(20n, GrRead{st, Bytes.new(0), 0})
        local.gz.checked(want, pieces, got)

def local.gz.test() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(47813))
    IO.spawn(Unit, local.gz.serve(l))
    decoded : Result<&1, &1, Http.Err, Http.Stream> <-
      Http.open("GET", "http://127.0.0.1:47813/", Http.empty(), Bytes.new(0))
    local.gz.check("616c70686120626574612067616d6d61", 1, decoded)
    raw : Result<&1, &1, Http.Err, Http.Stream> <-
      Http.open.raw("GET", "http://127.0.0.1:47813/", Http.empty(), Bytes.new(0))
    local.gz.check("1f8b08000000000002ff4bcc29c84854484a2d4954484fcccd4d040045445d3410000000", 2, raw)
    deflated : Result<&1, &1, Http.Err, Http.Stream> <-
      Http.open("GET", "http://127.0.0.1:47813/", Http.empty(), Bytes.new(0))
    local.gz.check("68656c6c6f20726177", 1, deflated)

def mtls.ok(+want: String, r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "mTLS fetch failed")
    case Done{res}:
      Http.Res{+status, headers, body} = res
      do IO<Unit>:
        local.ok(U32.is_eq(status, 200), "mTLS status")
        local.ok(String.eq(Bytes.to_string(body), want), "mTLS identity")

def mtls.err(r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      match e:
        case Http.ErrTls{code, why}:
          IO.print("ok mTLS rejected")
        case other:
          IO.die(Unit, 1, "mTLS failed without TLS error")
    case Done{res}:
      IO.die(Unit, 1, "mTLS accepted a missing certificate")

def mtls.pool.good(+want: String, pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Http.Pool):
  (p, r) = pr
  do IO<Http.Pool>:
    mtls.ok(want, r)
    return p

def mtls.pool.bad(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Http.Pool):
  (p, r) = pr
  do IO<Http.Pool>:
    mtls.err(r)
    return p

def mtls.run(+one: String, +key1: String, +two: String, +key2: String) -> IO(Unit):
  do IO<Unit>:
    missing : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch("GET", "https://localhost:39444/who", Http.empty(), Bytes.new(0))
    mtls.err(missing)
    accepted : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.cert("GET", "https://localhost:39444/who", Http.empty(), Bytes.new(0), one, key1)
    mtls.ok("client-one", accepted)
    same : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.cert("GET", "https://localhost:39444/same", Http.empty(), Bytes.new(0), one, key1)
    mtls.ok("client-one", same)
    cross : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.cert("GET", "https://localhost:39444/cross", Http.empty(), Bytes.new(0), one, key1)
    mtls.ok("clean", cross)
    back : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.cert("GET", "https://localhost:39444/back", Http.empty(), Bytes.new(0), one, key1)
    mtls.err(back)
    first : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch.cert(Http.pool.new(), "GET", "https://localhost:39444/who", Http.empty(), Bytes.new(0), one, key1)
    p1 : Http.Pool <- mtls.pool.good("client-one", first)
    no_cert : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch(p1, "GET", "https://localhost:39444/who", Http.empty(), Bytes.new(0))
    p2 : Http.Pool <- mtls.pool.bad(no_cert)
    second : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch.cert(p2, "GET", "https://localhost:39444/who", Http.empty(), Bytes.new(0), two, key2)
    p3 : Http.Pool <- mtls.pool.good("client-two", second)
    again : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch.cert(p3, "GET", "https://localhost:39444/who", Http.empty(), Bytes.new(0), one, key1)
    p4 : Http.Pool <- mtls.pool.good("client-one", again)
    Http.pool.close(p4)

def mtls.args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{one, tail}:
      match tail:
        case Nil{}:
          IO.die(Unit, 1, "mTLS needs four certificate paths")
        case Con{key1, rest}:
          match rest:
            case Nil{}:
              IO.die(Unit, 1, "mTLS needs four certificate paths")
            case Con{two, last}:
              match last:
                case Nil{}:
                  IO.die(Unit, 1, "mTLS needs four certificate paths")
                case Con{key2, extra}:
                  mtls.run(one, key1, two, key2)
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
    local.gz.test()
    args : List<&1, String> <- IO.args()
    mtls.args(args)
