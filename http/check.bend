import Base
import ./http.bend as Http
import ./admission.bend as Admission
import ./completion.bend as Completion
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import bend-kit-http2@0.2.0.0/hpack.bend as Hpack
import bend-kit-http2@0.2.0.0/http2.bend as H2
import bend-kit-bytes@0.3.1.0/bytes.bend as HBytes
import bend-kit-time@0.1.0.0/time.bend as Time


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

def local.reply(operation: IO(Http.Res)) -> IO(Http.Reply):
  do IO<Http.Reply>:
    response : Http.Res <- operation
    return Http.Reply{response, Completion.Unobserved{}}

def local.handler(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), Bytes.from_string(Http.header(headers, "host"))})

def local.accept(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- Http.conn(~(req => local.reply(local.handler(req))), ~Completion.ignore, Http.limits(1048576n), inbox, m)
    Listener.close(l2)
    Admission.close(inbox)

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
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47812))
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
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47813))
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

def h2.has(xs: List<&2, Hpack.Field>, +want: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{Hpack.Field{name, value, mode}, rest}:
      Bool.or(String.eq(name, want), h2.has(rest, want))

def h2.bad(r: Result<&1, &1, Http.Err, Maybe<&1, Http.Res>>) -> Bool:
  match r:
    case Fail{e}:
      True{}
    case Done{m}:
      False{}

def h2.good(r: Result<&1, &1, Http.Err, Maybe<&1, Http.Res>>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{m}:
      match m:
        case None{}:
          False{}
        case Some{Http.Res{status, headers, body}}:
          U32.is_eq(status, 200)

def h2.check() -> IO(Unit):
  +fields = Http.h2.request.fields("GET", "/", "example.com",
    Http.set(Http.set(Http.set(Http.set(Http.empty(),
      "Connection", "X-Remove, keep-alive"), "X-Remove", "secret"),
      ":evil", "forbidden"), "X-Keep", "yes"))
  do IO<Unit>:
    local.ok(Bool.not(h2.has(fields, "x-remove")), "h2 Connection-nominated header")
    local.ok(Bool.not(h2.has(fields, ":evil")), "h2 caller pseudo-header")
    local.ok(h2.has(fields, "x-keep"), "h2 regular header")
    local.ok(h2.bad(Http.h2.response([Hpack.Field{":status", "0200", 0}],
      HBytes.new(0))), "h2 status has exactly three digits")
    local.ok(h2.good(List.foldl(~&1, ~H2.ClientEvent,
      ~Result<&1, &1, Http.Err, Maybe<&1, Http.Res>>, ~Http.h2.event.fold,
      [H2.Response{1, [Hpack.Field{":status", "103", 0}], HBytes.new(0)},
        H2.Response{1, [Hpack.Field{":status", "200", 0}], HBytes.new(0)}],
      Done{None{}})), "h2 interim followed by final response")

def resolve.ok(+want: String, m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "resolve gave None for " ++ want)
    case Some{got}:
      local.ok(String.eq(got, want), "resolve " ++ want)

def resolve.none(m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("ok resolve refuses a relative base")
    case Some{got}:
      IO.die(Unit, 1, "resolve joined a relative base: " ++ got)

def resolve.check() -> IO(Unit):
  do IO<Unit>:
    resolve.ok("https://api.example.com/v1/users/7?x=1", Http.resolve("https://api.example.com/v1/", "users/7?x=1"))
    resolve.ok("https://api.example.com/health", Http.resolve("https://api.example.com:443/v1/", "/health"))
    resolve.ok("http://[::1]:8080/c", Http.resolve("http://[::1]:8080/a/b", "../c"))
    resolve.ok("http://b.example/y", Http.resolve("https://a.example/x", "http://b.example/y"))
    resolve.none(Http.resolve("/v1/", "users"))

# The retry server answers one request per connection, in this order.
def retry.s1(req: Http.Req) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{503, Http.set(Http.empty(), "retry-after", "0"), Bytes.from_string("try 1")})

def retry.s2(req: Http.Req) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{500, Http.empty(), Bytes.from_string("try 2")})

def retry.s3(req: Http.Req) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{200, Http.empty(), Bytes.from_string("try 3")})

def retry.s4(req: Http.Req) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{503, Http.set(Http.empty(), "retry-after", "0"), Bytes.from_string("post")})

def retry.s5(req: Http.Req) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{502, Http.empty(), Bytes.from_string("try 5")})

def retry.s6(req: Http.Req) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{504, Http.empty(), Bytes.from_string("try 6")})

def retry.s7(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), Bytes.append(Bytes.from_string(method ++ " " ++ Http.header(headers, "content-type") ++ " "), body)})

def retry.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- Http.conn(~(req => local.reply(retry.s1(req))), ~Completion.ignore, Http.limits(1048576n), inbox, a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- Http.conn(~(req => local.reply(retry.s2(req))), ~Completion.ignore, Http.limits(1048576n), inbox, b)
    c : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- Http.conn(~(req => local.reply(retry.s3(req))), ~Completion.ignore, Http.limits(1048576n), inbox, c)
    d : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l3)
    l4 : Listener <- Http.conn(~(req => local.reply(retry.s4(req))), ~Completion.ignore, Http.limits(1048576n), inbox, d)
    e : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l4)
    l5 : Listener <- Http.conn(~(req => local.reply(retry.s5(req))), ~Completion.ignore, Http.limits(1048576n), inbox, e)
    f : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l5)
    l6 : Listener <- Http.conn(~(req => local.reply(retry.s6(req))), ~Completion.ignore, Http.limits(1048576n), inbox, f)
    g : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l6)
    l7 : Listener <- Http.conn(~(req => local.reply(retry.s7(req))), ~Completion.ignore, Http.limits(1048576n), inbox, g)
    Listener.close(l7)
    Admission.close(inbox)

def retry.check(+name: String, +status: U32, +want: String, r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, name ++ ": fetch failed")
    case Done{res}:
      Http.Res{got, headers, body} = res
      local.ok(Bool.and(U32.is_eq(got, status), String.eq(Bytes.to_string(body), want)), name)

# The body names the connection that answered, so "try 3" is the third try.
def retry.test() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47814))
    IO.spawn(Unit, retry.serve(l))
    flaky : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.retry(2, "GET", "http://127.0.0.1:47814/flaky", Http.empty(), Bytes.new(0))
    retry.check("retry GET: 503, 500, then 200 on try 3 of 3", 200, "try 3", flaky)
    post : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.retry(2, "POST", "http://127.0.0.1:47814/post", Http.empty(), Bytes.from_string("x"))
    retry.check("retry POST: one try, 503 kept", 503, "post", post)
    spent : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.retry(1, "GET", "http://127.0.0.1:47814/spent", Http.empty(), Bytes.new(0))
    retry.check("retry exhausted: last 504 kept", 504, "try 6", spent)
    posted : Result<&1, &1, Http.Err, Http.Res> <-
      Http.post.json("http://127.0.0.1:47814/json", Json.Arr{[Json.Num{Bytes.from_string("1")}, Json.Flag{True{}}]})
    retry.check("post.json", 200, "POST application/json [1,true]", posted)

def local.proxy.http(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, +headers, body} = req
  do IO<Http.Res>:
    local.ok(String.eq(method, "GET"), "proxy HTTP method")
    local.ok(String.eq(path, "http://elsewhere.test/path"), "proxy absolute-form")
    local.ok(String.eq(Http.header(headers, "host"), "elsewhere.test"), "proxy origin Host")
    local.ok(String.eq(Http.header(headers, "proxy-authorization"), "Basic dTpw"),
      "proxy HTTP authorization")
    return Http.Res{200, Http.set(Http.empty(), "connection", "close"),
      Bytes.from_string("proxy")}

def local.proxy.tunnel.received(l: Listener,
    received: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) ->
    IO(Unit):
  (s, answer) = received
  match answer:
    case Fail{e}:
      do IO<Unit>:
        Http.io.close(False{}, s)
        Listener.close(l)
        IO.die(Unit, 1, "proxy CONNECT read failed")
    case Done{(len, buf)}:
      +raw = Bytes.to_string(Bytes.Bytes{len, buf})
      do IO<Unit>:
        local.ok(String.starts_with(raw,
          "CONNECT elsewhere.test:443 HTTP/1.1\r\nHost: elsewhere.test:443\r\n"),
          "proxy CONNECT authority")
        local.ok(String.ends_with(raw,
          "\r\nProxy-Authorization: Basic dTpw\r\n\r\n"),
          "proxy CONNECT authorization")
        sent : Socket & Result<&1, &1, U32 & String, Unit> <-
          Http.io.send.bytes(False{}, s, Bytes.from_string("HTTP/1.1 200 Connection Established\r\n\r\n"))
        Http.io.close(False{}, local.gz.sent(sent))
        Listener.close(l)

def local.proxy.tunnel.accept(m: Listener & Result<&1, &1, U32 & String, Socket>) ->
    IO(Unit):
  (l, result) = m
  match result:
    case Fail{e}:
      do IO<Unit>:
        Listener.close(l)
        IO.die(Unit, 1, "proxy CONNECT accept failed")
    case Done{s}:
      do IO<Unit>:
        got : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
          Http.io.recv.words(False{}, s, 4096, 2000)
        local.proxy.tunnel.received(l, got)

def local.proxy.http.accept(inbox: Chan(Admission.Command), m: Listener & Result<&1, &1, U32 & String, Socket>) ->
    IO(Listener):
  Http.conn(~(req => local.reply(local.proxy.http(req))), ~Completion.ignore, Http.limits(1048576n), inbox, m)

def local.proxy.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    first : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- local.proxy.http.accept(inbox, first)
    second : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    local.proxy.tunnel.accept(second)
    Admission.close(inbox)

def local.proxy.first(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) ->
    IO(Http.Pool):
  (p, result) = pr
  match result:
    case Fail{e}:
      IO.die(Http.Pool, 1, "proxied HTTP fetch failed")
    case Done{Http.Res{+status, headers, body}}:
      do IO<Http.Pool>:
        local.ok(U32.is_eq(status, 200), "proxy HTTP status")
        local.ok(String.eq(Bytes.to_string(body), "proxy"), "proxy HTTP body")
        return p

def local.proxy.last.result(result: Result<&1, &1, Http.Err, Http.Res>) ->
    IO(Unit):
  match result:
    case Done{res}:
      IO.die(Unit, 1, "proxy CONNECT tunnel unexpectedly served TLS")
    case Fail{e}:
      match e:
        case Http.ErrTls{code, why}:
          local.ok(True{}, "proxy CONNECT followed by TLS")
        case Http.ErrRead{code, why}:
          local.ok(True{}, "proxy CONNECT followed by TLS")
        case other:
          IO.die(Unit, 1, "proxy CONNECT failed before TLS")

def local.proxy.last(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) ->
    IO(Unit):
  (p, result) = pr
  do IO<Unit>:
    Http.pool.close(p)
    local.proxy.last.result(result)

def local.proxy.test() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47815))
    IO.spawn(Unit, local.proxy.serve(l))
    first : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.origin.choice(Http.pool.new(), "GET", 2000, Http.empty(),
        Bytes.new(0), "elsewhere.test", "http", "elsewhere.test", 80, "/path",
        None{}, "", Http.proxy.from.url("http://u:p@127.0.0.1:47815"))
    p : Http.Pool <- local.proxy.first(first)
    second : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.origin.choice(p, "GET", 2000, Http.empty(), Bytes.new(0),
        "elsewhere.test", "https", "elsewhere.test", 443, "/path", None{}, "",
        Http.proxy.from.url("http://u:p@127.0.0.1:47815"))
    local.proxy.last(second)

# The fetch.all server answers each path after 100 ms and closes its connection.
# Sixteen requests therefore make sixteen connections, even with pooled workers.
def all.slow(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = req
  do IO<Http.Res>:
    IO.sleep(100)
    return Http.Res{200, Http.set(Http.empty(), "connection", "close"), Bytes.from_string(path)}

def all.serve.loop(n: Nat, +inbox: Chan(Admission.Command), l: Listener) -> IO(Unit):
  match n:
    case 0n:
      do IO<Unit>:
        Listener.close(l)
        Admission.close(inbox)
    case 1n+p:
      do IO<Unit>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l1 : Listener <- Http.conn(~(req => local.reply(all.slow(req))), ~Completion.ignore, Http.limits(1048576n), inbox, a)
        all.serve.loop(p, inbox, l1)

def all.serve(n: Nat, l: Listener) -> IO(Unit):
  do IO<Unit>:
    inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    all.serve.loop(n, inbox, l)

def all.path(+i: U32) -> String:
  "/" ++ U32.show(i)

def all.reqs(n: Nat, +i: U32) -> List<Http.Fetch>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Http.Fetch{"GET", "http://127.0.0.1:47816" ++ all.path(i), Http.empty(), Bytes.new(0)} <> all.reqs(p, (i + 1 : U32))

def all.paths(n: Nat, +i: U32) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      all.path(i) <> all.paths(p, (i + 1 : U32))

def all.err(e: Http.Err) -> String:
  match e:
    case Http.ErrUrl{}:
      "bad url"
    case _:
      "failed"

def all.body(r: Result<&1, &1, Http.Err, Http.Res>) -> String:
  match r:
    case Fail{e}:
      all.err(e)
    case Done{res}:
      Http.Res{status, headers, body} = res
      Bytes.to_string(body)

def all.bodies(rs: List<Result<&1, &1, Http.Err, Http.Res>>) -> List<&2, String>:
  match rs:
    case Nil{}:
      Nil{}
    case r <> t:
      all.body(r) <> all.bodies(t)

def all.same(xs: List<&2, String>, ys: List<&2, String>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      String.eq(x, y) && all.same(xt, yt)
    case _ _:
      False{}

# Serial is 16 * 100 = 1600 ms. Eight workers should finish well under that.
def all.check(+dt: Nat, rs: List<Result<&1, &1, Http.Err, Http.Res>>) -> IO(Unit):
  do IO<Unit>:
    IO.print("fetch.all: 16 requests of 100 ms on 8 workers in " ++ Nat.show(dt) ++ " ms")
    local.ok(all.same(all.bodies(rs), all.paths(16n, 0)), "fetch.all: 16 distinct results in request order")
    local.ok(Nat.is_lt(dt, 800n), "fetch.all: 8 at once, well under 1600 ms serial")

def all.timed(t0: Nat, rs: List<Result<&1, &1, Http.Err, Http.Res>>) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    all.check((t1 - t0 : Nat), rs)

def all.test() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47816))
    IO.spawn(Unit, all.serve(16n, l))
    t0 : Nat <- IO.now()
    rs : List<Result<&1, &1, Http.Err, Http.Res>> <- Http.fetch.all(all.reqs(16n, 0), 8)
    all.timed(t0, rs)
    none : List<Result<&1, &1, Http.Err, Http.Res>> <- Http.fetch.all(Nil{}, 8)
    local.ok(all.same(all.bodies(none), Nil{}), "fetch.all: no requests, no results")
    bad : List<Result<&1, &1, Http.Err, Http.Res>> <-
      Http.fetch.all([Http.Fetch{"GET", "not a url", Http.empty(), Bytes.new(0)}], 0)
    local.ok(all.same(all.bodies(bad), ["bad url"]), "fetch.all: n = 0 runs one worker; a bad URL fails in place")
# /login redirects to /home and sets sid; /home echoes every cookie field it got, joined by "|",
# and sets last. Each response closes its connection, so the server takes one accept per request.
def cookie.srv.pick(login: Bool, got: String) -> Http.Res:
  match login:
    case True{}:
      Http.Res{302, Http.add(Http.add(Http.set(Http.empty(), "location", "/home"), "set-cookie", "sid=abc; Path=/; HttpOnly"), "connection", "close"), Bytes.new(0)}
    case False{}:
      Http.Res{200, Http.add(Http.set(Http.empty(), "set-cookie", "last=1"), "connection", "close"), Bytes.from_string(got)}

def cookie.srv(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, +headers, body} = req
  IO.pure(Http.Res, cookie.srv.pick(String.eq(path, "/login"), String.join(Http.fields(headers, "cookie"), "|")))

def cookie.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- Http.conn(~(req => local.reply(cookie.srv(req))), ~Completion.ignore, Http.limits(1048576n), inbox, a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- Http.conn(~(req => local.reply(cookie.srv(req))), ~Completion.ignore, Http.limits(1048576n), inbox, b)
    c : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- Http.conn(~(req => local.reply(cookie.srv(req))), ~Completion.ignore, Http.limits(1048576n), inbox, c)
    Listener.close(l3)
    Admission.close(inbox)

def cookie.got(+name: String, +want: String, r: Http.Pool & Http.Jar & Result<&1, &1, Http.Err, Http.Res>) -> IO(Http.Pool & Http.Jar):
  (p, j, m) = r
  match m:
    case Fail{e}:
      IO.die(Http.Pool & Http.Jar, 1, name ++ ": fetch failed")
    case Done{res}:
      Http.Res{+status, headers, body} = res
      +seen = Bytes.to_string(body)
      do IO<Http.Pool & Http.Jar>:
        local.ok(Bool.and(U32.is_eq(status, 200), String.eq(seen, want)), name ++ " (got " ++ seen ++ ")")
        return (p, j)

def cookie.sent(+j: Http.Jar, url: String) -> String:
  Http.header(Http.jar.apply(j, url, Http.empty()), "cookie")

def cookie.end(pj: Http.Pool & Http.Jar) -> IO(Unit):
  (p, +j) = pj
  do IO<Unit>:
    local.ok(String.eq(cookie.sent(j, "http://127.0.0.1:47817/"), "sid=abc; last=1"), "cookie jar kept redirect and final Set-Cookie")
    local.ok(String.is_empty(cookie.sent(j, "http://localhost:47817/")), "cookie jar: host-only cookie not sent to another host")
    Http.pool.close(p)

# The jar the first fetch gave back is used again, with a caller cookie that must share one field.
def cookie.again(pj: Http.Pool & Http.Jar) -> IO(Unit):
  (p, j) = pj
  do IO<Unit>:
    r : Http.Pool & Http.Jar & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch.jar(p, j, "GET", "http://127.0.0.1:47817/home", Http.set(Http.empty(), "Cookie", "pre=1"), Bytes.new(0))
    pj2 : Http.Pool & Http.Jar <- cookie.got("cookie jar: caller cookie and jar in one field", "pre=1; sid=abc; last=1", r)
    cookie.end(pj2)

def cookie.flags(cs: List<&2, Http.Cookie>) -> String:
  match cs:
    case Nil{}:
      "none"
    case Con{Http.Cookie{n, v, d, h, p, s, o, ss, e}, t}:
      Bool.pick(String, o, "httponly ", "") ++ ss

def cookie.jar.of(r: Http.Jar & Http.Res) -> Http.Jar:
  (j, res) = r
  j

def cookie.stored(+now: Time.Instant, from: String, +line: String) -> Http.Jar:
  cookie.jar.of(Http.jar.store(Http.jar.new(now), from, Http.Res{200, Http.set(Http.empty(), "set-cookie", line), Bytes.new(0)}))

# Secure, SameSite, HttpOnly and the name prefixes, which the laws do not cover.
def cookie.pure(+now: Time.Instant) -> IO(Unit):
  +sec = cookie.stored(now, "https://s.example/", "s=1; Secure; HttpOnly; SameSite=None")
  do IO<Unit>:
    local.ok(String.eq(cookie.sent(sec, "https://s.example/"), "s=1"), "cookie Secure sent over https")
    local.ok(String.is_empty(cookie.sent(sec, "http://s.example/")), "cookie Secure not sent over http")
    local.ok(String.eq(cookie.flags(Http.jar.cookies(sec)), "httponly none"), "cookie HttpOnly and SameSite kept")
    local.ok(String.is_empty(cookie.sent(cookie.stored(now, "http://s.example/", "t=1; Secure"), "https://s.example/")), "cookie Secure from http ignored")
    local.ok(String.is_empty(cookie.sent(cookie.stored(now, "https://s.example/", "n=1; SameSite=None"), "https://s.example/")), "cookie SameSite=None without Secure ignored")
    local.ok(String.eq(cookie.sent(cookie.stored(now, "https://s.example/", "__Host-a=1; Secure; Path=/"), "https://s.example/"), "__Host-a=1"), "cookie __Host- accepted")
    local.ok(String.is_empty(cookie.sent(cookie.stored(now, "https://s.example/", "__Host-b=1; Secure; Path=/; Domain=s.example"), "https://s.example/")), "cookie __Host- with Domain ignored")
    local.ok(String.is_empty(cookie.sent(cookie.stored(now, "https://s.example/", "__Secure-c=1"), "https://s.example/")), "cookie __Secure- without Secure ignored")

# A redirect that sets a cookie: the next hop, on the same fetch, must send it.
def cookie.live(+now: Time.Instant) -> IO(Unit):
  do IO<Unit>:
    cookie.pure(now)
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47817))
    IO.spawn(Unit, cookie.serve(l))
    r : Http.Pool & Http.Jar & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch.jar(Http.pool.new(), Http.jar.new(now), "GET", "http://127.0.0.1:47817/login", Http.empty(), Bytes.new(0))
    pj : Http.Pool & Http.Jar <- cookie.got("cookie jar: redirect cookie reached the next hop", "sid=abc", r)
    cookie.again(pj)

def cookie.test() -> IO(Unit):
  do IO<Unit>:
    now : Time.Instant <- Time.now()
    cookie.live(now)

def limits.overflow(turn: Http.Turn) -> Bool:
  match turn:
    case Http.TurnFail{status}:
      U32.is_eq(status, 413)
    case _:
      False{}

def limits.counter() -> IO(Unit):
  local.ok(limits.overflow(Http.sv.chunk(
    Nat.add(U32.to_nat(4294967295), 1n),
    Http.Req{"POST", "/", Http.empty(), Bytes.new(0)}, True{}, 4294967295,
    Http.DcData{1}, Nil{}, Bytes.from_string("x"))),
    "decoded body counter rejects representability overflow")

def admission.counts(counts: Maybe<&2, Admission.Counts>) -> String:
  match counts:
    case None{}:
      "closed"
    case Some{Admission.Counts{c, a, b, ch, ah, bh, cr, ar, br}}:
      U32.show(c) ++ "," ++ U32.show(a) ++ "," ++ U32.show(b) ++ "," ++
        U32.show(ch) ++ "," ++ U32.show(ah) ++ "," ++ U32.show(bh) ++ "," ++
        Nat.show(cr) ++ "," ++ Nat.show(ar) ++ "," ++ Nat.show(br)

# Exhaustion, refusal, release, and renewed admission on the real admission pools.
def admission.smoke() -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{3, 1, 2})
    a : Bool <- Admission.take(inbox, 0)
    b : Bool <- Admission.take(inbox, 0)
    c : Bool <- Admission.take(inbox, 0)
    local.ok(a && b && Bool.not(c), "admission: a full buffer pool refuses a connection")
    d : Bool <- Admission.take(inbox, 1)
    e : Bool <- Admission.take(inbox, 1)
    local.ok(d && Bool.not(e), "admission: a full active pool refuses a request")
    Admission.give(inbox, 0)
    f : Bool <- Admission.take(inbox, 0)
    Admission.give(inbox, 1)
    g : Bool <- Admission.take(inbox, 1)
    local.ok(f && g, "admission: a release admits again")
    counts : Maybe<&2, Admission.Counts> <- Admission.snapshot(inbox)
    local.ok(String.eq(admission.counts(counts), "2,1,2,2,1,2,0,1,1"), "admission: counts after release")
    Admission.give(inbox, 0)
    Admission.give(inbox, 0)
    Admission.give(inbox, 1)
    Admission.close(inbox)

def main() -> IO(Unit):
  do IO<Unit>:
    limits.counter()
    admission.smoke()
    show(Http.parse("GET /x HTTP/1.1\r\n\r\nhello"))
    show(Http.parse("GET /x HTTP/1.1\r\nHost: x\r\n\r\nhello"))
    show(Http.parse("GET /x HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhello"))
    show(Http.parse("GET / HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n"))
    show(Http.parse("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"))
    IO.print(Bytes.to_string(Http.res_body(Http.parse_res("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"))))
    IO.print(Http.sanitize("a\rb\nc"))
    h2.check()
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47811))
    pool.run(Http.pool.new(), "yyn")
    pool.run(Http.pool.new.with(1), "ynn")
    Listener.close(l)
    r : Result<&1, &1, U32 & String, Listener & U32> <- test.listen6(0)
    local.ipv6(r)
    local.fallback()
    local.gz.test()
    resolve.check()
    retry.test()
    local.proxy.test()
    all.test()
    cookie.test()
    args : List<&1, String> <- IO.args()
    mtls.args(List.tail(&1, String, args))
