import Base
import ./http.bend as Http
import ./pure.bend as Pure
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def die(+why: String) -> IO(Unit):
  IO.die(Unit, 1, why)

# EPROTO is 100 on macOS and 71 on Linux.
def code.is(+code: U32, +want: U32) -> Bool:
  Bool.or(U32.is_eq(code, want), Bool.and(U32.is_eq(want, 100), U32.is_eq(code, 71)))

def body.eq(+name: String, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      die(name ++ " body")

def body.shown(+name: String, +want: String, +got: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}:
      die(name ++ " status")
    case True{}:
      body.eq(name, String.eq(got, want))

def body.ok(+name: String, +want: String, r: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      die(name ++ " failed")
    case Done{res}:
      Pure.Res{+status, headers, body} = res
      body.shown(name, want, Pure.to_string(body), U32.is_eq(status, 200))

def tls.code(+name: String, +code: U32, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      die(name ++ " code " ++ U32.show(code))

def tls.fail(+name: String, +want: U32, r: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Unit):
  match r:
    case Done{res}:
      die(name ++ " succeeded")
    case Fail{e}:
      match e:
        case Pure.ErrTls{+code, why}:
          tls.code(name, code, code.is(code, want))
        case other:
          die(name ++ " was not a TLS error")

def pool.ok(+name: String, +want: String, pr: Http.Pool & Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Unit):
  (p, r) = pr
  do IO<Unit>:
    body.ok(name, want, r)
    Http.pool.close(p)

type Read is Type:
  Reading{st: Http.Stream, body: Bytes.Bytes}
  Read{got: Http.Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>>, body: Bytes.Bytes}

def stream.read(fuel: Nat, step: Read) -> IO(Http.Stream & Bytes.Bytes):
  match fuel:
    case 0n:
      IO.die(Http.Stream & Bytes.Bytes, 1, "response stream did not end")
    case 1n+p:
      match step:
        case Reading{st, body}:
          do IO<Http.Stream & Bytes.Bytes>:
            got : Http.Stream & Result<&1, &1, Pure.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(st)
            stream.read(p, Read{got, body})
        case Read{got, body}:
          (st, r) = got
          match r:
            case Done{Some{piece}}:
              stream.read(p, Reading{st, Bytes.append(body, piece)})
            case Done{None{}}:
              IO.pure(Http.Stream & Bytes.Bytes, (st, body))
            case Fail{e}:
              IO.die(Http.Stream & Bytes.Bytes, 1, "response stream read failed")

def stream.body(+name: String, +want: String, r: Http.Stream & Bytes.Bytes) -> IO(Unit):
  (st, body) = r
  do IO<Unit>:
    Http.stream.close(st)
    body.eq(name, String.eq(Pure.to_string(body), want))

def stream.ok(+name: String, +want: String, x: Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Unit):
  (jar, r) = x
  match r:
    case Fail{e}:
      die(name ++ " failed")
    case Done{st}:
      do IO<Unit>:
        got : Http.Stream & Bytes.Bytes <- stream.read(40n, Reading{st, Bytes.new(0)})
        stream.body(name, want, got)

def stream.fail(+name: String, +want: U32, x: Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Unit):
  (jar, r) = x
  match r:
    case Done{st}:
      do IO<Unit>:
        Http.stream.close(st)
        die(name ++ " succeeded")
    case Fail{e}:
      match e:
        case Pure.ErrTls{+code, why}:
          tls.code(name, code, code.is(code, want))
        case other:
          die(name ++ " was not a TLS error")

def upload.sent(r: Pure.Up & Result<&2, &2, Pure.Err, Unit>) -> IO(Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream>):
  (up, w) = r
  do IO<Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream>>:
    st : Result<&1, &1, Pure.Err, Http.Stream> <- Http.upload.finish(up)
    return (None{}, st)

def upload.ok(r: Result<&1, &1, Pure.Err, Pure.Up>) -> IO(Unit):
  match r:
    case Fail{e}:
      die("upload.how ca failed")
    case Done{up}:
      do IO<Unit>:
        w : Pure.Up & Result<&2, &2, Pure.Err, Unit> <- Http.upload.write(up, Pure.from_string("hi"))
        x : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <- upload.sent(w)
        stream.ok("upload.how ca", "ok", x)

def upload.fail(r: Result<&1, &1, Pure.Err, Pure.Up>) -> IO(Unit):
  match r:
    case Done{up}:
      do IO<Unit>:
        x : Result<&1, &1, Pure.Err, Http.Stream> <- Http.upload.finish(up)
        die("upload.how default store accepted private CA")
    case Fail{e}:
      stream.fail("upload.how default store rejects private CA", 100, (None{}, Fail{e}))

def upload.written(r: Pure.Up & Result<&2, &2, Pure.Err, Unit>) -> IO(Pure.Up):
  match r:
    case (up, Done{Unit{}}):
      IO.pure(Pure.Up, up)
    case (up, Fail{e}):
      IO.die(Pure.Up, 1, "CONNECT upload write failed")

def upload.tunnel(r: Result<&1, &1, Pure.Err, Pure.Up>) -> IO(Unit):
  match r:
    case Fail{e}:
      die("CONNECT upload open failed")
    case Done{up}:
      do IO<Unit>:
        first : Pure.Up & Result<&2, &2, Pure.Err, Unit> <-
          Http.upload.write(up, Pure.from_string("first\r\n"))
        next : Pure.Up <- upload.written(first)
        second : Pure.Up & Result<&2, &2, Pure.Err, Unit> <-
          Http.upload.write(next, Pure.from_string("second last"))
        last : Pure.Up <- upload.written(second)
        finished : Result<&1, &1, Pure.Err, Http.Stream> <- Http.upload.finish(last)
        stream.ok("CONNECT TLS upload body at origin", "tunnel upload verified", (None{}, finished))

def stream.tunnel(r: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Unit):
  (p, response) = r
  do IO<Unit>:
    stream.ok("CONNECT TLS response stream", "tunnel streamed response complete", (None{}, response))
    Http.pool.close(p)

def run(+ca: String, +base: String, +port: U32, +proxy: String) -> IO(Unit):
  do IO<Unit>:
    ok : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.ca("GET", base ++ "/ok", Pure.empty(), Pure.from_string(""), ca)
    body.ok("fetch.ca", "ok", ok)
    gone : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.ca("GET", base ++ "/go", Pure.empty(), Pure.from_string(""), ca)
    body.ok("fetch.ca redirect", "ok", gone)
    bare : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch("GET", base ++ "/ok", Pure.empty(), Pure.from_string(""))
    tls.fail("default store rejects private CA", 100, bare)
    missing : Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.fetch.ca("GET", base ++ "/ok", Pure.empty(), Pure.from_string(""), "/nonexistent/bend-kit-ca.pem")
    tls.fail("missing CA file", 22, missing)
    pooled : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.fetch.ca(Http.pool.new(), "GET", base ++ "/ok", Pure.empty(), Pure.from_string(""), ca)
    pool.ok("pool.fetch.ca", "ok", pooled)
    opened : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open.how(Pure.ModeFollow{}, None{}, ca, None{}, "GET", base ++ "/go", Pure.empty(), Pure.from_string(""), 30000)
    stream.ok("open.how ca redirect", "ok", opened)
    plain : Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.open.how(Pure.ModeFollow{}, None{}, "", None{}, "GET", base ++ "/ok", Pure.empty(), Pure.from_string(""), 30000)
    stream.fail("open.how default store rejects private CA", 100, plain)
    uploaded : Result<&1, &1, Pure.Err, Pure.Up> <-
      Http.upload.how(None{}, ca, "POST", base ++ "/ok", Pure.empty(), 30000)
    upload.ok(uploaded)
    refused : Result<&1, &1, Pure.Err, Pure.Up> <-
      Http.upload.how(None{}, "", "POST", base ++ "/ok", Pure.empty(), 30000)
    upload.fail(refused)
    tunneled : Result<&1, &1, Pure.Err, Pure.Up> <-
      Http.up.origin.choice("POST", 5000, Pure.empty(), "localhost:" ++ U32.show(port),
        "https", "localhost", port, "/tunnel", None{}, ca, Pure.proxy.from.url(proxy))
    upload.tunnel(tunneled)
    fetched : Http.Pool & Result<&1, &1, Pure.Err, Pure.Res> <-
      Http.pool.origin.choice(Http.pool.new(), "GET", 5000, Pure.empty(), Bytes.new(0),
        "localhost:" ++ U32.show(port), "https", "localhost", port, "/tunnel-pool",
        None{}, ca, Pure.proxy.from.url(proxy))
    pool.ok("CONNECT TLS pooled fetch", "tunnel pooled response complete", fetched)
    streaming : Http.Pool & Result<&1, &1, Pure.Err, Http.Stream> <-
      Http.stream.origin.choice(Http.pool.new(), "GET", 5000, Pure.empty(), Bytes.new(0),
        "localhost:" ++ U32.show(port), "https", "localhost", port, "/tunnel-stream",
        None{}, ca, Pure.proxy.from.url(proxy))
    stream.tunnel(streaming)

def main.port(ca: String, base: String, proxy: String, port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case Some{n}:
      run(ca, base, n, proxy)
    case None{}:
      die("ca_check needs a valid origin port")

def main.args(args: List<&1, String>) -> IO(Unit):
  match args:
    case Con{ca, Con{base, Con{port, Con{proxy, Nil{}}}}}:
      main.port(ca, base, proxy, U32.read(port))
    case _:
      die("ca_check needs a CA file path, server base URL, origin port, and proxy URL")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    main.args(List.tail(&1, String, args))
