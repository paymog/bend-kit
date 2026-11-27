import Base
import ./http.bend as Http
import ./pure.bend as Pure
import ./admission.bend as Admission
import ./completion.bend as Completion
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-json@0.7.3.2/json.bend as Json
import bend-kit-http2@0.6.0.2/hpack.bend as Hpack
import bend-kit-http2@0.6.0.2/http2.bend as H2
import bend-kit-bytes@0.3.3.3/bytes.bend as HBytes
import bend-kit-time@0.3.0.5/pure.bend as Time
import bend-kit-wire@0.4.8.1/wire.bend as Wire


def show_req(req: Pure.Req) -> IO(Unit):
  Pure.Req{method, path, headers, body} = req
  do IO<Unit>:
    IO.print(method ++ " " ++ path ++ " [" ++ Bytes.to_string(body) ++ "]")
    IO.print(Bytes.to_string(Pure.encode(Pure.Res{200, Pure.empty(), Bytes.from_string("ok")})))

def show(m: Maybe<&1, Pure.Req>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{req}:
      show_req(req)

def pool.key(port: U32) -> String:
  Pure.pool.key("http", "127.0.0.1", port)

def pool.give.r(port: U32, p: Http.Pool, r: Result<&1, &1, Pure.Err, Http.Conn>) -> IO(Http.Pool):
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, "pool: connect failed")
    case Done{c}:
      Http.pool.give(p, pool.key(port), c)

# A new socket to the local listener, given to the pool.
def pool.give.new(+port: U32, p: Http.Pool) -> IO(Http.Pool):
  do IO<Http.Pool>:
    r : Result<&1, &1, Pure.Err, Http.Conn> <- Http.conn.open(False{}, 2000, "127.0.0.1", "127.0.0.1", port)
    pool.give.r(port, p, r)

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

def pool.take(port: U32, ps: Http.Pool & String) -> IO(Http.Pool & String):
  (p, +seen) = ps
  pool.took(seen, Http.pool.take(p, pool.key(port)))

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
def pool.run(+port: U32, p: Http.Pool, +want: String) -> IO(Unit):
  do IO<Unit>:
    p1 : Http.Pool <- pool.give.new(port, p)
    p2 : Http.Pool <- pool.give.new(port, p1)
    a : Http.Pool & String <- pool.take(port, (p2, ""))
    b : Http.Pool & String <- pool.take(port, a)
    c : Http.Pool & String <- pool.take(port, b)
    pool.report(want, c)

def pool.test(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  do IO<Unit>:
    pool.run(port, Http.pool.new(), "yyn")
    pool.run(port, Http.pool.new.with(1), "ynn")
    Listener.close(l)

def local.bound(r: Result<&1, &1, U32 & String, Listener & U32>) -> IO(Listener & U32):
  match r:
    case Fail{(+code, why)}:
      IO.die(Listener & U32, 1, "IPv4 bind: " ++ U32.show(code) ++ " " ++ why)
    case Done{lp}:
      IO.pure(Listener & U32, lp)

# A loopback listener on a port the OS picks, so a busy fixed port cannot fail the check.
def local.listen() -> IO(Listener & U32):
  do IO<Listener & U32>:
    r : Result<&1, &1, U32 & String, Listener & U32> <- Wire.listen("127.0.0.1", 0)
    local.bound(r)

def local.reply(operation: IO(Pure.Res)) -> IO(Http.Reply):
  do IO<Http.Reply>:
    response : Pure.Res <- operation
    return Http.Reply{response, Completion.Unobserved{}}

def local.handler(req: Pure.Req) -> IO(Pure.Res):
  Pure.Req{method, path, headers, body} = req
  IO.pure(Pure.Res, Pure.Res{200, Pure.empty(), Bytes.from_string(Pure.header(headers, "host"))})

def local.accept(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    m : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- Http.conn(~(req => local.reply(local.handler(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, m)
    Listener.close(l2)
    Admission.close(inbox)

def local.ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def local.got(+want: String, r: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "local fetch failed")
    case Done{res}:
      Pure.Res{+status, headers, body} = res
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
        result : Result<&1, &1, Pure.Err, Pure.Res> <- Http.get("http://" ++ want ++ "/x")
        local.got(want, result)

def local.fallback(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  +at = "localhost:" ++ U32.show(port)
  do IO<Unit>:
    IO.spawn(Unit, local.accept(l))
    result : Result<&1, &1, Pure.Err, Pure.Res> <- Http.get("http://" ++ at ++ "/x")
    local.got(at, result)

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
  GrGot{m: Http.Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>, acc: Bytes.Bytes, count: U32}

def local.gz.read(fuel: Nat, step: Gr) -> IO(Http.Stream & Bytes.Bytes & U32):
  match fuel:
    case 0n:
      IO.die(Http.Stream & Bytes.Bytes & U32, 1, "gzip stream did not end")
    case 1n+p:
      match step:
        case GrRead{st, acc, +count}:
          do IO<Http.Stream & Bytes.Bytes & U32>:
            m : Http.Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(st)
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

def local.gz.check(+want: String, +pieces: U32, r: Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "gzip stream open failed")
    case Done{st}:
      do IO<Unit>:
        got : Http.Stream & Bytes.Bytes & U32 <- local.gz.read(20n, GrRead{st, Bytes.new(0), 0})
        local.gz.checked(want, pieces, got)

def local.gz.test(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  +url = "http://127.0.0.1:" ++ U32.show(port) ++ "/"
  do IO<Unit>:
    IO.spawn(Unit, local.gz.serve(l))
    decoded : Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open("GET", url, Pure.empty(), Bytes.new(0))
    local.gz.check("616c70686120626574612067616d6d61", 1, decoded)
    raw : Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open.raw("GET", url, Pure.empty(), Bytes.new(0))
    local.gz.check("1f8b08000000000002ff4bcc29c84854484a2d4954484fcccd4d040045445d3410000000", 2, raw)
    deflated : Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open("GET", url, Pure.empty(), Bytes.new(0))
    local.gz.check("68656c6c6f20726177", 1, deflated)

def opened.body(+name: String, +want: String, got: Http.Stream & Bytes.Bytes & U32) -> IO(Unit):
  (end, body, count) = got
  +seen = Bytes.to_string(body)
  do IO<Unit>:
    local.ok(String.eq(seen, want), name ++ " (got " ++ seen ++ ")")
    Http.stream.close(end)

# The whole body of an opened stream, checked against want. The jar comes back.
def opened.got(+name: String, +want: String, x: Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Maybe<&2, Pure.Jar>):
  (m, r) = x
  match r:
    case Fail{e}:
      IO.die(Maybe<&2, Pure.Jar>, 1, name ++ ": open failed")
    case Done{st}:
      do IO<Maybe<&2, Pure.Jar>>:
        got : Http.Stream & Bytes.Bytes & U32 <- local.gz.read(20n, GrRead{st, Bytes.new(0), 0})
        opened.body(name, want, got)
        return m

# A failed write stays in the Up, so upload.finish reports it.
def upload.wrote(r: Pure.Up & Result<&2, &2, Pure.Err, Unit>) ->
    IO(Result<&1, &1, Pure.Err, Http.Stream>):
  (up, w) = r
  Http.upload.finish(up)

def upload.started(r: Result<&1, &1, Pure.Err, Pure.Up>) ->
    IO(Result<&1, &1, Pure.Err, Http.Stream>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Pure.Err, Http.Stream>, Fail{e})
    case Done{up}:
      do IO<Result<&1, &1, Pure.Err, Http.Stream>>:
        w : Pure.Up & Result<&2, &2, Pure.Err, Unit> <- Http.upload.write(up, Bytes.from_string("hi"))
        upload.wrote(w)

def mtls.ok(+want: String, r: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "mTLS fetch failed")
    case Done{res}:
      Pure.Res{+status, headers, body} = res
      do IO<Unit>:
        local.ok(U32.is_eq(status, 200), "mTLS status")
        local.ok(String.eq(Bytes.to_string(body), want), "mTLS identity")

def mtls.err(r: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      match e:
        case Pure.ErrTls{code, why}:
          IO.print("ok mTLS rejected")
        case other:
          IO.die(Unit, 1, "mTLS failed without TLS error")
    case Done{res}:
      IO.die(Unit, 1, "mTLS accepted a missing certificate")

def mtls.pool.good(+want: String, pr: Http.Pool & Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Http.Pool):
  (p, r) = pr
  do IO<Http.Pool>:
    mtls.ok(want, r)
    return p

def mtls.pool.bad(pr: Http.Pool & Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Http.Pool):
  (p, r) = pr
  do IO<Http.Pool>:
    mtls.err(r)
    return p

def mtls.upload.err(r: Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Unit):
  match r:
    case Fail{Pure.ErrTls{code, why}}:
      IO.print("ok mTLS upload rejected")
    case Fail{other}:
      IO.die(Unit, 1, "mTLS upload failed without TLS error")
    case Done{st}:
      do IO<Unit>:
        Http.stream.close(st)
        IO.die(Unit, 1, "mTLS upload accepted a missing certificate")

def mtls.run(+one: String, +key1: String, +two: String, +key2: String, +base: String) -> IO(Unit):
  do IO<Unit>:
    missing : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch("GET", base ++ "/who", Pure.empty(), Bytes.new(0))
    mtls.err(missing)
    accepted : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.cert("GET", base ++ "/who", Pure.empty(), Bytes.new(0), one, key1)
    mtls.ok("client-one", accepted)
    began : Result<&1, &1, Pure.Err, Pure.Up> <-
      Http.upload.how(Some{Pure.Cert{one, key1}}, "", "GET", base ++ "/who", Pure.empty(), 30000)
    uploaded : Result<&1, &1, Pure.Err, Http.Stream> <- upload.started(began)
    ju : Maybe<&2, Pure.Jar> <- opened.got("mTLS upload identity", "client-one", (None{}, uploaded))
    bare : Result<&1, &1, Pure.Err, Pure.Up> <-
      Http.upload.how(None{}, "", "GET", base ++ "/who", Pure.empty(), 30000)
    rejected : Result<&1, &1, Pure.Err, Http.Stream> <- upload.started(bare)
    mtls.upload.err(rejected)
    same : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.cert("GET", base ++ "/same", Pure.empty(), Bytes.new(0), one, key1)
    mtls.ok("client-one", same)
    cross : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.cert("GET", base ++ "/cross", Pure.empty(), Bytes.new(0), one, key1)
    mtls.ok("clean", cross)
    back : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.cert("GET", base ++ "/back", Pure.empty(), Bytes.new(0), one, key1)
    mtls.err(back)
    streamed : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open.how(Pure.ModeFollow{}, Some{Pure.Cert{one, key1}}, "", None{}, "GET", base ++ "/who", Pure.empty(), Bytes.new(0), 30000)
    j1 : Maybe<&2, Pure.Jar> <- opened.got("mTLS stream identity", "client-one", streamed)
    crossed : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open.how(Pure.ModeFollow{}, Some{Pure.Cert{one, key1}}, "", None{}, "GET", base ++ "/cross", Pure.empty(), Bytes.new(0), 30000)
    j2 : Maybe<&2, Pure.Jar> <- opened.got("mTLS stream: no certificate after a cross-origin redirect", "clean", crossed)
    first : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.cert(Http.pool.new(), "GET", base ++ "/who", Pure.empty(), Bytes.new(0), one, key1)
    p1 : Http.Pool <- mtls.pool.good("client-one", first)
    no_cert : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch(p1, "GET", base ++ "/who", Pure.empty(), Bytes.new(0))
    p2 : Http.Pool <- mtls.pool.bad(no_cert)
    second : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.cert(p2, "GET", base ++ "/who", Pure.empty(), Bytes.new(0), two, key2)
    p3 : Http.Pool <- mtls.pool.good("client-two", second)
    again : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.cert(p3, "GET", base ++ "/who", Pure.empty(), Bytes.new(0), one, key1)
    p4 : Http.Pool <- mtls.pool.good("client-one", again)
    Http.pool.close(p4)

def h2.idle.got(+name: String, +want: String, pr: Http.Pool & Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Http.Pool):
  (p, r) = pr
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, name ++ ": fetch failed")
    case Done{Pure.Res{+status, headers, body}}:
      do IO<Http.Pool>:
        local.ok(Bool.and(U32.is_eq(status, 200), String.eq(Bytes.to_string(body), want)), name)
        return p

# The HTTP/2 server answers one request per connection with the connection number, then closes TCP.
def h2.idle(+base: String) -> IO(Unit):
  do IO<Unit>:
    first : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch(Http.pool.new(), "GET", base ++ "/a", Pure.empty(), Bytes.new(0))
    p1 : Http.Pool <- h2.idle.got("h2 pool: GET", "1", first)
    IO.sleep(500)
    second : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch(p1, "POST", base ++ "/b", Pure.empty(), Bytes.from_string("x"))
    p2 : Http.Pool <- h2.idle.got("h2 pool: POST on a new connection after the server closed the idle session", "2", second)
    Http.pool.close(p2)

def h2.stream.body(p: Http.Pool, +want: String, got: Http.Stream & Bytes.Bytes & U32) -> IO(Http.Pool):
  (st, body, count) = got
  do IO<Http.Pool>:
    local.ok(String.eq(Bytes.to_string(body), want), "h2 stream: body on the original connection")
    local.ok(U32.is_eq(count, 2), "h2 stream: two DATA pieces")
    Http.pool.stream.close(p, st)

def h2.stream.got(+want: String, opened: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Http.Pool):
  (p, r) = opened
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, "h2 stream open failed")
    case Done{st}:
      do IO<Http.Pool>:
        got : Http.Stream & Bytes.Bytes & U32 <- local.gz.read(20n, GrRead{st, Bytes.new(0), 0})
        h2.stream.body(p, want, got)

def h2.stream.early(opened: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Http.Pool):
  (p, r) = opened
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, "h2 early stream open failed")
    case Done{st}:
      Http.pool.stream.close(p, st)


def h2.large.body(p: Http.Pool, body: Bytes.Bytes) -> IO(Http.Pool):
  Bytes.Bytes{len, buf} = body
  do IO<Http.Pool>:
    local.ok(U32.is_eq(len, 131072), "h2 body exceeds the receive window")
    return p

def h2.large.buffered(got: Http.Pool & Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Http.Pool):
  (p, r) = got
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, "h2 large buffered response failed")
    case Done{Pure.Res{status, headers, body}}:
      h2.large.body(p, body)

def h2.large.read(p: Http.Pool, read: Http.Stream & Bytes.Bytes & U32) -> IO(Http.Pool):
  (end, body, count) = read
  do IO<Http.Pool>:
    next : Http.Pool <- h2.large.body(p, body)
    Http.pool.stream.close(next, end)

def h2.large.stream(got: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Http.Pool):
  (p, r) = got
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, "h2 large stream failed")
    case Done{st}:
      do IO<Http.Pool>:
        read : Http.Stream & Bytes.Bytes & U32 <- local.gz.read(100n, GrRead{st, Bytes.new(0), 0})
        h2.large.read(p, read)

def h2.delayed.read(got: Http.Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>,
    p: Http.Pool) -> IO(Http.Pool):
  (st, r) = got
  match r:
    case Done{Some{b}}:
      do IO<Http.Pool>:
        IO.sleep(500)
        Http.pool.stream.close(p, st)
    case _:
      IO.die(Http.Pool, 1, "h2 delayed stream did not return a chunk")

def h2.delayed(got: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Http.Pool):
  (p, r) = got
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, "h2 delayed stream failed")
    case Done{st}:
      do IO<Http.Pool>:
        IO.sleep(500)
        read : Http.Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(st)
        h2.delayed.read(read, p)

def h2.stream(+base: String) -> IO(Unit):
  do IO<Unit>:
    a : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(Http.pool.new(), "GET", base ++ "/a", Pure.empty(), Bytes.new(0), 2000)
    p1 : Http.Pool <- h2.stream.got("1ab", a)
    b : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(p1, "POST", base ++ "/cancel", Pure.empty(), Bytes.from_string("upload"), 2000)
    p2 : Http.Pool <- h2.stream.early(b)
    c : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(p2, "GET", base ++ "/c", Pure.empty(), Bytes.new(0), 2000)
    p3 : Http.Pool <- h2.stream.got("1ab", c)
    large : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.with(p3, "GET", base ++ "/large", Pure.empty(), Bytes.new(0), 2000)
    p4 : Http.Pool <- h2.large.buffered(large)
    streamed : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(p4, "GET", base ++ "/large-stream", Pure.empty(), Bytes.new(0), 2000)
    p5 : Http.Pool <- h2.large.stream(streamed)
    delayed : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(p5, "GET", base ++ "/delayed", Pure.empty(), Bytes.new(0), 2000)
    p6 : Http.Pool <- h2.delayed(delayed)
    after : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.with(p6, "GET", base ++ "/after-cancel", Pure.empty(), Bytes.new(0), 2000)
    p7 : Http.Pool <- h2.idle.got("h2 session after pending-credit cancellation", "1ab", after)
    complete : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(p7, "GET", base ++ "/complete-discard", Pure.empty(), Bytes.new(0), 2000)
    p8 : Http.Pool <- h2.delayed(complete)
    d : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.with(p8, "GET", base ++ "/d", Pure.empty(), Bytes.new(0), 2000)
    p9 : Http.Pool <- h2.idle.got("h2 buffered fetch after streams", "1ab", d)
    Http.pool.close(p9)

def h2.has(xs: List<&2, Hpack.Field>, +want: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{Hpack.Field{name, value, mode}, rest}:
      Bool.or(String.eq(name, want), h2.has(rest, want))

def h2.bad(r: Result<&1, &1, Pure.Err, Maybe<&1, Pure.Res>>) -> Bool:
  match r:
    case Fail{e}:
      True{}
    case Done{m}:
      False{}

def h2.good(r: Result<&1, &1, Pure.Err, Maybe<&1, Pure.Res>>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{m}:
      match m:
        case None{}:
          False{}
        case Some{Pure.Res{status, headers, body}}:
          U32.is_eq(status, 200)

def h2.check() -> IO(Unit):
  +fields = Http.h2.request.fields("GET", "/", "example.com",
    Pure.set(Pure.set(Pure.set(Pure.set(Pure.empty(),
      "Connection", "X-Remove, keep-alive"), "X-Remove", "secret"),
      ":evil", "forbidden"), "X-Keep", "yes"))
  do IO<Unit>:
    local.ok(Bool.not(h2.has(fields, "x-remove")), "h2 Connection-nominated header")
    local.ok(Bool.not(h2.has(fields, ":evil")), "h2 caller pseudo-header")
    local.ok(h2.has(fields, "x-keep"), "h2 regular header")
    local.ok(h2.bad(Http.h2.response([Hpack.Field{":status", "0200", 0}],
      HBytes.new(0))), "h2 status has exactly three digits")
    local.ok(h2.good(Http.h2.response([Hpack.Field{":status", "200", 0}],
      HBytes.new(0))), "h2 final response")

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
    resolve.ok("https://api.example.com/v1/users/7?x=1", Pure.resolve("https://api.example.com/v1/", "users/7?x=1"))
    resolve.ok("https://api.example.com/health", Pure.resolve("https://api.example.com:443/v1/", "/health"))
    resolve.ok("http://[::1]:8080/c", Pure.resolve("http://[::1]:8080/a/b", "../c"))
    resolve.ok("http://b.example/y", Pure.resolve("https://a.example/x", "http://b.example/y"))
    resolve.none(Pure.resolve("/v1/", "users"))

# The retry server answers one request per connection, in this order.
def retry.s1(req: Pure.Req) -> IO(Pure.Res):
  IO.pure(Pure.Res, Pure.Res{503, Pure.set(Pure.empty(), "retry-after", "0"), Bytes.from_string("try 1")})

def retry.s2(req: Pure.Req) -> IO(Pure.Res):
  IO.pure(Pure.Res, Pure.Res{500, Pure.empty(), Bytes.from_string("try 2")})

def retry.s3(req: Pure.Req) -> IO(Pure.Res):
  IO.pure(Pure.Res, Pure.Res{200, Pure.empty(), Bytes.from_string("try 3")})

def retry.s4(req: Pure.Req) -> IO(Pure.Res):
  IO.pure(Pure.Res, Pure.Res{503, Pure.set(Pure.empty(), "retry-after", "0"), Bytes.from_string("post")})

def retry.s5(req: Pure.Req) -> IO(Pure.Res):
  IO.pure(Pure.Res, Pure.Res{502, Pure.empty(), Bytes.from_string("try 5")})

def retry.s6(req: Pure.Req) -> IO(Pure.Res):
  IO.pure(Pure.Res, Pure.Res{504, Pure.empty(), Bytes.from_string("try 6")})

def retry.s7(req: Pure.Req) -> IO(Pure.Res):
  Pure.Req{method, path, headers, body} = req
  IO.pure(Pure.Res, Pure.Res{200, Pure.empty(), Bytes.append(Bytes.from_string(method ++ " " ++ Pure.header(headers, "content-type") ++ " "), body)})

def retry.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- Http.conn(~(req => local.reply(retry.s1(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- Http.conn(~(req => local.reply(retry.s2(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, b)
    c : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- Http.conn(~(req => local.reply(retry.s3(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, c)
    d : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l3)
    l4 : Listener <- Http.conn(~(req => local.reply(retry.s4(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, d)
    e : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l4)
    l5 : Listener <- Http.conn(~(req => local.reply(retry.s5(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, e)
    f : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l5)
    l6 : Listener <- Http.conn(~(req => local.reply(retry.s6(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, f)
    g : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l6)
    l7 : Listener <- Http.conn(~(req => local.reply(retry.s7(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, g)
    Listener.close(l7)
    Admission.close(inbox)

def retry.check(+name: String, +status: U32, +want: String, r: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, name ++ ": fetch failed")
    case Done{res}:
      Pure.Res{got, headers, body} = res
      local.ok(Bool.and(U32.is_eq(got, status), String.eq(Bytes.to_string(body), want)), name)

# The body names the connection that answered, so "try 3" is the third try.
def retry.test(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  +base = "http://127.0.0.1:" ++ U32.show(port)
  do IO<Unit>:
    IO.spawn(Unit, retry.serve(l))
    flaky : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.retry(2, "GET", base ++ "/flaky", Pure.empty(), Bytes.new(0))
    retry.check("retry GET: 503, 500, then 200 on try 3 of 3", 200, "try 3", flaky)
    post : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.retry(2, "POST", base ++ "/post", Pure.empty(), Bytes.from_string("x"))
    retry.check("retry POST: one try, 503 kept", 503, "post", post)
    spent : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.retry(1, "GET", base ++ "/spent", Pure.empty(), Bytes.new(0))
    retry.check("retry exhausted: last 504 kept", 504, "try 6", spent)
    posted : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.post.json(base ++ "/json", Json.Arr{[Json.Num{Bytes.from_string("1")}, Json.Flag{True{}}]})
    retry.check("post.json", 200, "POST application/json [1,true]", posted)

def local.proxy.http(req: Pure.Req) -> IO(Pure.Res):
  Pure.Req{+method, path, +headers, body} = req
  do IO<Pure.Res>:
    local.ok(Bool.or(String.eq(method, "GET"), String.eq(method, "POST")), "proxy HTTP method")
    local.ok(String.eq(path, "http://elsewhere.test/path"), "proxy absolute-form")
    local.ok(String.eq(Pure.header(headers, "host"), "elsewhere.test"), "proxy origin Host")
    local.ok(String.eq(Pure.header(headers, "proxy-authorization"), "Basic dTpw"),
      "proxy HTTP authorization")
    return Pure.Res{200, Pure.set(Pure.empty(), "connection", "close"),
      Bytes.from_string("proxy")}

def local.proxy.tunnel.received(l: Listener,
    received: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) ->
    IO(Listener):
  (s, answer) = received
  match answer:
    case Fail{e}:
      do IO<Listener>:
        Http.io.close(False{}, s)
        Listener.close(l)
        IO.die(Listener, 1, "proxy CONNECT read failed")
    case Done{(len, buf)}:
      +raw = Bytes.to_string(Bytes.Bytes{len, buf})
      do IO<Listener>:
        local.ok(String.starts_with(raw,
          "CONNECT elsewhere.test:443 HTTP/1.1\r\nHost: elsewhere.test:443\r\n"),
          "proxy CONNECT authority")
        local.ok(String.ends_with(raw,
          "\r\nProxy-Authorization: Basic dTpw\r\n\r\n"),
          "proxy CONNECT authorization")
        sent : Socket & Result<&1, &1, U32 & String, Unit> <-
          Http.io.send.bytes(False{}, s, Bytes.from_string("HTTP/1.1 200 Connection Established\r\n\r\n"))
        Http.io.close(False{}, local.gz.sent(sent))
        return l

def local.proxy.tunnel.accept(m: Listener & Result<&1, &1, U32 & String, Socket>) ->
    IO(Listener):
  (l, result) = m
  match result:
    case Fail{e}:
      do IO<Listener>:
        Listener.close(l)
        IO.die(Listener, 1, "proxy CONNECT accept failed")
    case Done{s}:
      do IO<Listener>:
        got : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
          Http.io.recv.words(False{}, s, 4096, 2000)
        local.proxy.tunnel.received(l, got)

def local.proxy.http.accept(inbox: Chan(Admission.Command), m: Listener & Result<&1, &1, U32 & String, Socket>) ->
    IO(Listener):
  Http.conn(~(req => local.reply(local.proxy.http(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, m)

# Three forward requests, then three CONNECT tunnels: pool, stream, and upload in each group.
def local.proxy.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    first : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- local.proxy.http.accept(inbox, first)
    second : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2a : Listener <- local.proxy.http.accept(inbox, second)
    upload : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2a)
    l2 : Listener <- local.proxy.http.accept(inbox, upload)
    third : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- local.proxy.tunnel.accept(third)
    fourth : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l3)
    l4 : Listener <- local.proxy.tunnel.accept(fourth)
    fifth : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l4)
    l5 : Listener <- local.proxy.tunnel.accept(fifth)
    Listener.close(l5)
    Admission.close(inbox)

def local.proxy.first(pr: Http.Pool & Result<&1, &1, Pure.Err, Pure.Res>) ->
    IO(Http.Pool):
  (p, result) = pr
  match result:
    case Fail{e}:
      IO.die(Http.Pool, 1, "proxied HTTP fetch failed")
    case Done{Pure.Res{+status, headers, body}}:
      do IO<Http.Pool>:
        local.ok(U32.is_eq(status, 200), "proxy HTTP status")
        local.ok(String.eq(Bytes.to_string(body), "proxy"), "proxy HTTP body")
        return p

def local.proxy.tunneled(e: Pure.Err) -> IO(Unit):
  match e:
    case Pure.ErrTls{code, why}:
      local.ok(True{}, "proxy CONNECT followed by TLS")
    case Pure.ErrRead{code, why}:
      local.ok(True{}, "proxy CONNECT followed by TLS")
    case other:
      IO.die(Unit, 1, "proxy CONNECT failed before TLS")

def local.proxy.last.result(result: Result<&1, &1, Pure.Err, Pure.Res>) ->
    IO(Unit):
  match result:
    case Done{res}:
      IO.die(Unit, 1, "proxy CONNECT tunnel unexpectedly served TLS")
    case Fail{e}:
      local.proxy.tunneled(e)

def local.proxy.stream.last(result: Result<&1, &1, Pure.Err, Http.Stream>) ->
    IO(Unit):
  match result:
    case Done{st}:
      do IO<Unit>:
        Http.stream.close(st)
        IO.die(Unit, 1, "proxy CONNECT stream unexpectedly served TLS")
    case Fail{e}:
      local.proxy.tunneled(e)

def local.proxy.last(pr: Http.Pool & Result<&1, &1, Pure.Err, Pure.Res>) ->
    IO(Unit):
  (p, result) = pr
  do IO<Unit>:
    Http.pool.close(p)
    local.proxy.last.result(result)

def local.stream.unpool(pr: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Result<&1, &1, Pure.Err, Http.Stream>):
  (p, r) = pr
  do IO<Result<&1, &1, Pure.Err, Http.Stream>>:
    Http.pool.close(p)
    return r

def local.proxy.test(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  +proxy = "http://u:p@127.0.0.1:" ++ U32.show(port)
  do IO<Unit>:
    IO.spawn(Unit, local.proxy.serve(l))
    first : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.origin.choice(Http.pool.new(), "GET", 2000, Pure.empty(),
        Bytes.new(0), "elsewhere.test", "http", "elsewhere.test", 80, "/path",
        None{}, "", Pure.proxy.from.url(proxy))
    p : Http.Pool <- local.proxy.first(first)
    pooled : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.stream.origin.choice(Http.pool.new(), "GET", 2000, Pure.empty(), Bytes.new(0),
        "elsewhere.test", "http", "elsewhere.test", 80, "/path", None{}, "",
        Pure.proxy.from.url(proxy))
    streamed : Result<&1, &1, Pure.Err, Http.Stream> <- local.stream.unpool(pooled)
    j : Maybe<&2, Pure.Jar> <- opened.got("proxy stream body", "proxy", (None{}, streamed))
    began : Result<&1, &1, Pure.Err, Pure.Up> <-
      Http.up.origin.choice("POST", 2000, Pure.empty(), "elsewhere.test", "http",
        "elsewhere.test", 80, "/path", None{}, "",
        Pure.proxy.from.url(proxy))
    uploaded : Result<&1, &1, Pure.Err, Http.Stream> <- upload.started(began)
    ju : Maybe<&2, Pure.Jar> <- opened.got("proxy upload body", "proxy", (None{}, uploaded))
    second : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.origin.choice(p, "GET", 2000, Pure.empty(), Bytes.new(0),
        "elsewhere.test", "https", "elsewhere.test", 443, "/path", None{}, "",
        Pure.proxy.from.url(proxy))
    local.proxy.last(second)
    tunnel : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.stream.origin.choice(Http.pool.new(), "GET", 2000, Pure.empty(), Bytes.new(0),
        "elsewhere.test", "https", "elsewhere.test", 443, "/path", None{}, "",
        Pure.proxy.from.url(proxy))
    tunneled : Result<&1, &1, Pure.Err, Http.Stream> <- local.stream.unpool(tunnel)
    local.proxy.stream.last(tunneled)
    tunnel_upload : Result<&1, &1, Pure.Err, Pure.Up> <-
      Http.up.origin.choice("POST", 2000, Pure.empty(), "elsewhere.test", "https",
        "elsewhere.test", 443, "/path", None{}, "", Pure.proxy.from.url(proxy))
    upload_tunneled : Result<&1, &1, Pure.Err, Http.Stream> <- upload.started(tunnel_upload)
    local.proxy.stream.last(upload_tunneled)

def spool.end(p: Http.Pool, +name: String, host: String, got: Http.Stream & Bytes.Bytes & U32) -> IO(Http.Pool):
  (st, body, n) = got
  do IO<Http.Pool>:
    local.ok(String.eq(Bytes.to_string(body), host), name)
    Http.pool.stream.close(p, st)

def spool.read(+name: String, host: String, pr: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Http.Pool):
  (p, r) = pr
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, name ++ ": open failed")
    case Done{st}:
      do IO<Http.Pool>:
        got : Http.Stream & Bytes.Bytes & U32 <- local.gz.read(20n, GrRead{st, Bytes.new(0), 0})
        spool.end(p, name, host, got)

def spool.early(pr: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Http.Pool):
  (p, r) = pr
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, "pooled stream: third open failed")
    case Done{st}:
      Http.pool.stream.close(p, st)

def spool.left(pm: Http.Pool & Maybe<&1, Http.Conn>) -> IO(Unit):
  (p, m) = pm
  match m:
    case None{}:
      do IO<Unit>:
        Http.pool.close(p)
        local.ok(True{}, "pooled stream: a stream closed before its end keeps its connection out of the pool")
    case Some{c}:
      do IO<Unit>:
        Http.conn.close(c)
        Http.pool.close(p)
        IO.die(Unit, 1, "pooled stream: a stream closed early gave its connection back")

# The listener takes one connection, so the second and third streams must reuse it.
def spool.test(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  +host = "127.0.0.1:" ++ U32.show(port)
  do IO<Unit>:
    IO.spawn(Unit, local.accept(l))
    a : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(Http.pool.new(), "GET", "http://" ++ host ++ "/a", Pure.empty(), Bytes.new(0), 2000)
    p1 : Http.Pool <- spool.read("pooled stream: first read to the end", host, a)
    b : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(p1, "GET", "http://" ++ host ++ "/b", Pure.empty(), Bytes.new(0), 2000)
    p2 : Http.Pool <- spool.read("pooled stream: second on the same connection", host, b)
    c : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(p2, "GET", "http://" ++ host ++ "/c", Pure.empty(), Bytes.new(0), 2000)
    p3 : Http.Pool <- spool.early(c)
    spool.left(Http.pool.take(p3, Pure.pool.key("http", "127.0.0.1", port)))

def stale.srv.closed(sent: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = sent
  Socket.close(s)

def stale.srv.reply(+want: String, +body: String, got: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match got:
    case (s, Fail{(+code, why)}):
      do IO<Unit>:
        Socket.close(s)
        IO.die(Unit, 1, "stale pool: server recv: " ++ why)
    case (s, Done{+req}):
      do IO<Unit>:
        local.ok(String.starts_with(req, want), "stale pool: server got " ++ want)
        sent : Socket & Result<&1, &1, U32 & String, Unit> <-
          Wire.send(s, "HTTP/1.1 200 OK\r\nContent-Length: 1\r\n\r\n" ++ body)
        stale.srv.closed(sent)

def stale.srv.one(+want: String, +body: String, a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  match a:
    case (l, Fail{(+code, why)}):
      IO.die(Listener, 1, "stale pool: accept: " ++ why)
    case (l, Done{s}):
      do IO<Listener>:
        got : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(s, 4096, 2000)
        stale.srv.reply(want, body, got)
        return l

# Each connection answers one request, keeps the connection alive in its reply, then closes it.
def stale.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- stale.srv.one("GET ", "a", a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- stale.srv.one("POST ", "b", b)
    c : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- stale.srv.one("POST ", "c", c)
    Listener.close(l3)

def stale.got(+name: String, +want: String, pr: Http.Pool & Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Http.Pool):
  (p, r) = pr
  do IO<Http.Pool>:
    retry.check(name, 200, want, r)
    return p

def stale.stream.end(p: Http.Pool, +name: String, +want: String, got: Http.Stream & Bytes.Bytes & U32) -> IO(Http.Pool):
  (st, body, n) = got
  do IO<Http.Pool>:
    local.ok(String.eq(Bytes.to_string(body), want), name)
    Http.pool.stream.close(p, st)

def stale.stream(+name: String, +want: String, pr: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Http.Pool):
  (p, r) = pr
  match r:
    case Fail{e}:
      IO.die(Http.Pool, 1, name ++ ": open failed")
    case Done{st}:
      do IO<Http.Pool>:
        got : Http.Stream & Bytes.Bytes & U32 <- local.gz.read(20n, GrRead{st, Bytes.new(0), 0})
        stale.stream.end(p, name, want, got)

# The server closes each pooled socket; each POST must take a new connection, not fail on the dead one.
def stale.test(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  +base = "http://127.0.0.1:" ++ U32.show(port)
  do IO<Unit>:
    IO.spawn(Unit, stale.serve(l))
    first : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.with(Http.pool.new(), "GET", base ++ "/a", Pure.empty(), Bytes.new(0), 2000)
    p1 : Http.Pool <- stale.got("stale pool: GET", "a", first)
    IO.sleep(100)
    second : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.with(p1, "POST", base ++ "/b", Pure.empty(), Bytes.from_string("x"), 2000)
    p2 : Http.Pool <- stale.got("stale pool: POST on a new connection after the server closed the idle one", "b", second)
    IO.sleep(100)
    third : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.pool.open.with(p2, "POST", base ++ "/c", Pure.empty(), Bytes.from_string("x"), 2000)
    p3 : Http.Pool <- stale.stream("stale pool: streamed POST on a new connection after the server closed the idle one", "c", third)
    Http.pool.close(p3)

# The fetch.all server answers each path after 100 ms and closes its connection.
# Sixteen requests therefore make sixteen connections, even with pooled workers.
def all.slow(req: Pure.Req) -> IO(Pure.Res):
  Pure.Req{method, path, headers, body} = req
  do IO<Pure.Res>:
    IO.sleep(100)
    return Pure.Res{200, Pure.set(Pure.empty(), "connection", "close"), Bytes.from_string(path)}

def all.serve.loop(n: Nat, +inbox: Chan(Admission.Command), l: Listener) -> IO(Unit):
  match n:
    case 0n:
      do IO<Unit>:
        Listener.close(l)
        Admission.close(inbox)
    case 1n+p:
      do IO<Unit>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l1 : Listener <- Http.conn(~(req => local.reply(all.slow(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, a)
        all.serve.loop(p, inbox, l1)

def all.serve(n: Nat, l: Listener) -> IO(Unit):
  do IO<Unit>:
    inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    all.serve.loop(n, inbox, l)

def all.path(+i: U32) -> String:
  "/" ++ U32.show(i)

def all.reqs(n: Nat, +base: String, +i: U32) -> List<Pure.Fetch>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Pure.Fetch{"GET", base ++ all.path(i), Pure.empty(), Bytes.new(0)} <> all.reqs(p, base, (i + 1 : U32))

def all.paths(n: Nat, +i: U32) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      all.path(i) <> all.paths(p, (i + 1 : U32))

def all.err(e: Pure.Err) -> String:
  match e:
    case Pure.ErrUrl{}:
      "bad url"
    case _:
      "failed"

def all.body(r: Result<&1, &1, Pure.Err, Pure.Res>) -> String:
  match r:
    case Fail{e}:
      all.err(e)
    case Done{res}:
      Pure.Res{status, headers, body} = res
      Bytes.to_string(body)

def all.bodies(rs: List<Result<&1, &1, Pure.Err, Pure.Res>>) -> List<&2, String>:
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
def all.check(+dt: Nat, rs: List<Result<&1, &1, Pure.Err, Pure.Res>>) -> IO(Unit):
  do IO<Unit>:
    IO.print("fetch.all: 16 requests of 100 ms on 8 workers in " ++ Nat.show(dt) ++ " ms")
    local.ok(all.same(all.bodies(rs), all.paths(16n, 0)), "fetch.all: 16 distinct results in request order")
    local.ok(Nat.is_lt(dt, 800n), "fetch.all: 8 at once, well under 1600 ms serial")

def all.timed(t0: Nat, rs: List<Result<&1, &1, Pure.Err, Pure.Res>>) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    all.check((t1 - t0 : Nat), rs)

def all.test(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  do IO<Unit>:
    IO.spawn(Unit, all.serve(16n, l))
    t0 : Nat <- IO.now()
    rs : List<Result<&1, &1, Pure.Err, Pure.Res>> <- Http.fetch.all(all.reqs(16n, "http://127.0.0.1:" ++ U32.show(port), 0), 8)
    all.timed(t0, rs)
    none : List<Result<&1, &1, Pure.Err, Pure.Res>> <- Http.fetch.all(Nil{}, 8)
    local.ok(all.same(all.bodies(none), Nil{}), "fetch.all: no requests, no results")
    bad : List<Result<&1, &1, Pure.Err, Pure.Res>> <-
      Http.fetch.all([Pure.Fetch{"GET", "not a url", Pure.empty(), Bytes.new(0)}], 0)
    local.ok(all.same(all.bodies(bad), ["bad url"]), "fetch.all: n = 0 runs one worker; a bad URL fails in place")
# /login redirects to /home and sets sid; /home echoes every cookie field it got, joined by "|",
# and sets last. Each response closes its connection, so the server takes one accept per request.
def cookie.srv.pick(login: Bool, got: String) -> Pure.Res:
  match login:
    case True{}:
      Pure.Res{302, Pure.add(Pure.add(Pure.set(Pure.empty(), "location", "/home"), "set-cookie", "sid=abc; Path=/; HttpOnly"), "connection", "close"), Bytes.new(0)}
    case False{}:
      Pure.Res{200, Pure.add(Pure.set(Pure.empty(), "set-cookie", "last=1"), "connection", "close"), Bytes.from_string(got)}

def cookie.srv(req: Pure.Req) -> IO(Pure.Res):
  Pure.Req{method, path, +headers, body} = req
  IO.pure(Pure.Res, cookie.srv.pick(String.eq(path, "/login"), String.join(Pure.fields(headers, "cookie"), "|")))

def cookie.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- Http.conn(~(req => local.reply(cookie.srv(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- Http.conn(~(req => local.reply(cookie.srv(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, b)
    c : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- Http.conn(~(req => local.reply(cookie.srv(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, c)
    Listener.close(l3)
    Admission.close(inbox)

def cookie.got(+name: String, +want: String, r: Http.Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Http.Pool & Pure.Jar):
  (p, j, m) = r
  match m:
    case Fail{e}:
      IO.die(Http.Pool & Pure.Jar, 1, name ++ ": fetch failed")
    case Done{res}:
      Pure.Res{+status, headers, body} = res
      +seen = Bytes.to_string(body)
      do IO<Http.Pool & Pure.Jar>:
        local.ok(Bool.and(U32.is_eq(status, 200), String.eq(seen, want)), name ++ " (got " ++ seen ++ ")")
        return (p, j)

def cookie.sent(+j: Pure.Jar, url: String) -> String:
  Pure.header(Pure.jar.apply(j, url, Pure.empty()), "cookie")

def cookie.end(+port: U32, pj: Http.Pool & Pure.Jar) -> IO(Unit):
  (p, +j) = pj
  do IO<Unit>:
    local.ok(String.eq(cookie.sent(j, "http://127.0.0.1:" ++ U32.show(port) ++ "/"), "sid=abc; last=1"), "cookie jar kept redirect and final Set-Cookie")
    local.ok(String.is_empty(cookie.sent(j, "http://localhost:" ++ U32.show(port) ++ "/")), "cookie jar: host-only cookie not sent to another host")
    Http.pool.close(p)

# The jar the first fetch gave back is used again, with a caller cookie that must share one field.
def cookie.again(+port: U32, pj: Http.Pool & Pure.Jar) -> IO(Unit):
  (p, j) = pj
  do IO<Unit>:
    r : Http.Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.jar(p, j, "GET", "http://127.0.0.1:" ++ U32.show(port) ++ "/home", Pure.set(Pure.empty(), "Cookie", "pre=1"), Bytes.new(0))
    pj2 : Http.Pool & Pure.Jar <- cookie.got("cookie jar: caller cookie and jar in one field", "pre=1; sid=abc; last=1", r)
    cookie.end(port, pj2)

def cookie.flags(cs: List<&2, Pure.Cookie>) -> String:
  match cs:
    case Nil{}:
      "none"
    case Con{Pure.Cookie{n, v, d, h, p, s, o, ss, e}, t}:
      Bool.pick(String, o, "httponly ", "") ++ ss

def cookie.jar.of(r: Pure.Jar & Pure.Res) -> Pure.Jar:
  (j, res) = r
  j

def cookie.stored(+now: Time.Instant, from: String, +line: String) -> Pure.Jar:
  cookie.jar.of(Pure.jar.store(Pure.jar.new(now), from, Pure.Res{200, Pure.set(Pure.empty(), "set-cookie", line), Bytes.new(0)}))

# Secure, SameSite, HttpOnly and the name prefixes, which the laws do not cover.
def cookie.pure(+now: Time.Instant) -> IO(Unit):
  +sec = cookie.stored(now, "https://s.example/", "s=1; Secure; HttpOnly; SameSite=None")
  do IO<Unit>:
    local.ok(String.eq(cookie.sent(sec, "https://s.example/"), "s=1"), "cookie Secure sent over https")
    local.ok(String.is_empty(cookie.sent(sec, "http://s.example/")), "cookie Secure not sent over http")
    local.ok(String.eq(cookie.flags(Pure.jar.cookies(sec)), "httponly none"), "cookie HttpOnly and SameSite kept")
    local.ok(String.is_empty(cookie.sent(cookie.stored(now, "http://s.example/", "t=1; Secure"), "https://s.example/")), "cookie Secure from http ignored")
    local.ok(String.is_empty(cookie.sent(cookie.stored(now, "https://s.example/", "n=1; SameSite=None"), "https://s.example/")), "cookie SameSite=None without Secure ignored")
    local.ok(String.eq(cookie.sent(cookie.stored(now, "https://s.example/", "__Host-a=1; Secure; Path=/"), "https://s.example/"), "__Host-a=1"), "cookie __Host- accepted")
    local.ok(String.is_empty(cookie.sent(cookie.stored(now, "https://s.example/", "__Host-b=1; Secure; Path=/; Domain=s.example"), "https://s.example/")), "cookie __Host- with Domain ignored")
    local.ok(String.is_empty(cookie.sent(cookie.stored(now, "https://s.example/", "__Secure-c=1"), "https://s.example/")), "cookie __Secure- without Secure ignored")

# A redirect that sets a cookie: the next hop, on the same fetch, must send it.
def cookie.live(+now: Time.Instant, lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  do IO<Unit>:
    cookie.pure(now)
    IO.spawn(Unit, cookie.serve(l))
    r : Http.Pool & Pure.Jar & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.jar(Http.pool.new(), Pure.jar.new(now), "GET", "http://127.0.0.1:" ++ U32.show(port) ++ "/login", Pure.empty(), Bytes.new(0))
    pj : Http.Pool & Pure.Jar <- cookie.got("cookie jar: redirect cookie reached the next hop", "sid=abc", r)
    cookie.again(port, pj)

def cookie.test(lp: Listener & U32) -> IO(Unit):
  do IO<Unit>:
    now : Time.Instant <- Http.clock.now()
    cookie.live(now, lp)

# cookie.srv, one connection per accept, then the listener closes.
def redir.serve(n: Nat, +inbox: Chan(Admission.Command), l: Listener) -> IO(Unit):
  match n:
    case 0n:
      do IO<Unit>:
        Listener.close(l)
        Admission.close(inbox)
    case 1n+p:
      do IO<Unit>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l1 : Listener <- Http.conn(~(req => local.reply(cookie.srv(req))), ~Completion.ignore, Pure.limits(1048576n), inbox, a)
        redir.serve(p, inbox, l1)

def redir.start(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    redir.serve(4n, inbox, l)

def redir.jar(url: String, m: Maybe<&2, Pure.Jar>) -> String:
  match m:
    case None{}:
      "no jar"
    case Some{j}:
      cookie.sent(j, url)

def redir.error(x: Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Unit):
  (m, r) = x
  match r:
    case Fail{e}:
      match e:
        case Pure.ErrRedirect{}:
          IO.print("ok stream ModeError fails on a redirect, as fetch does")
        case other:
          IO.die(Unit, 1, "stream ModeError failed with another error")
    case Done{st}:
      do IO<Unit>:
        Http.stream.close(st)
        IO.die(Unit, 1, "stream ModeError opened a redirect")

def redir.manual.res(sr: Http.Stream & Pure.Res) -> IO(Unit):
  (st, res) = sr
  Pure.Res{+status, headers, body} = res
  do IO<Unit>:
    local.ok(U32.is_eq(status, 302), "stream ModeManual returns the 302 as the stream")
    Http.stream.close(st)

def redir.manual(x: Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Unit):
  (m, r) = x
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "stream ModeManual open failed")
    case Done{st}:
      redir.manual.res(Http.stream.res(st))

# /login answers 302 to /home with a cookie; /home echoes the cookies it got.
def redir.test(lp: Listener & U32) -> IO(Unit):
  (l, +port) = lp
  +base = "http://127.0.0.1:" ++ U32.show(port)
  do IO<Unit>:
    now : Time.Instant <- Http.clock.now()
    IO.spawn(Unit, redir.start(l))
    followed : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open.how(Pure.ModeFollow{}, None{}, "", Some{Pure.jar.new(now)}, "GET", base ++ "/login", Pure.empty(), Bytes.new(0), 2000)
    j : Maybe<&2, Pure.Jar> <- opened.got("stream jar: Set-Cookie on the first hop is sent on the second", "sid=abc", followed)
    local.ok(String.eq(redir.jar(base ++ "/", j), "sid=abc; last=1"), "stream jar comes back with both Set-Cookie fields")
    failed : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open.how(Pure.ModeError{}, None{}, "", None{}, "GET", base ++ "/login", Pure.empty(), Bytes.new(0), 2000)
    redir.error(failed)
    manual : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open.how(Pure.ModeManual{}, None{}, "", None{}, "GET", base ++ "/login", Pure.empty(), Bytes.new(0), 2000)
    redir.manual(manual)

def limits.overflow(turn: Pure.Turn) -> Bool:
  match turn:
    case Pure.TurnFail{status}:
      U32.is_eq(status, 413)
    case _:
      False{}

def limits.counter() -> IO(Unit):
  local.ok(limits.overflow(Pure.sv.chunk(
    Nat.add(U32.to_nat(4294967295), 1n),
    Pure.Req{"POST", "/", Pure.empty(), Bytes.new(0)}, True{}, 4294967295,
    Pure.DcData{1}, Nil{}, Bytes.from_string("x"))),
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
    show(Pure.parse("GET /x HTTP/1.1\r\n\r\nhello"))
    show(Pure.parse("GET /x HTTP/1.1\r\nHost: x\r\n\r\nhello"))
    show(Pure.parse("GET /x HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\nhello"))
    show(Pure.parse("GET / HTTP/1.1\r\nHost: x\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n"))
    show(Pure.parse("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n"))
    IO.print(Bytes.to_string(Pure.res_body(Pure.parse_res("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok"))))
    IO.print(Pure.sanitize("a\rb\nc"))
    h2.check()
    pl : Listener & U32 <- local.listen()
    pool.test(pl)
    r : Result<&1, &1, U32 & String, Listener & U32> <- Wire.listen("::1", 0)
    local.ipv6(r)
    fl : Listener & U32 <- local.listen()
    local.fallback(fl)
    gl : Listener & U32 <- local.listen()
    local.gz.test(gl)
    resolve.check()
    rl : Listener & U32 <- local.listen()
    retry.test(rl)
    xl : Listener & U32 <- local.listen()
    local.proxy.test(xl)
    sl : Listener & U32 <- local.listen()
    spool.test(sl)
    tl : Listener & U32 <- local.listen()
    stale.test(tl)
    al : Listener & U32 <- local.listen()
    all.test(al)
    cl : Listener & U32 <- local.listen()
    cookie.test(cl)
    dl : Listener & U32 <- local.listen()
    redir.test(dl)
