import Base
import ./http.bend as Http
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

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

def body.ok(+name: String, +want: String, r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      die(name ++ " failed")
    case Done{res}:
      Http.Res{+status, headers, body} = res
      body.shown(name, want, Http.to_string(body), U32.is_eq(status, 200))

def tls.code(+name: String, +code: U32, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      die(name ++ " code " ++ U32.show(code))

def tls.fail(+name: String, +want: U32, r: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match r:
    case Done{res}:
      die(name ++ " succeeded")
    case Fail{e}:
      match e:
        case Http.ErrTls{+code, why}:
          tls.code(name, code, code.is(code, want))
        case other:
          die(name ++ " was not a TLS error")

def pool.ok(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  (p, r) = pr
  do IO<Unit>:
    body.ok("pool.fetch.ca", "ok", r)
    Http.pool.close(p)

def stream.piece(+name: String, r: Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>>) -> IO(Unit):
  match r:
    case Done{Some{b}}:
      body.eq(name, String.eq(Http.to_string(b), "ok"))
    case _:
      die(name ++ " read")

def stream.body(+name: String, r: Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>>) -> IO(Unit):
  (st, got) = r
  do IO<Unit>:
    Http.stream.close(st)
    stream.piece(name, got)

def stream.ok(+name: String, x: Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream>) -> IO(Unit):
  (jar, r) = x
  match r:
    case Fail{e}:
      die(name ++ " failed")
    case Done{st}:
      do IO<Unit>:
        got : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(st)
        stream.body(name, got)

def stream.fail(+name: String, +want: U32, x: Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream>) -> IO(Unit):
  (jar, r) = x
  match r:
    case Done{st}:
      do IO<Unit>:
        Http.stream.close(st)
        die(name ++ " succeeded")
    case Fail{e}:
      match e:
        case Http.ErrTls{+code, why}:
          tls.code(name, code, code.is(code, want))
        case other:
          die(name ++ " was not a TLS error")

def upload.sent(r: Http.Up & Result<&2, &2, Http.Err, Unit>) -> IO(Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream>):
  (up, w) = r
  do IO<Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream>>:
    st : Result<&1, &1, Http.Err, Http.Stream> <- Http.upload.finish(up)
    return (None{}, st)

def upload.ok(r: Result<&1, &1, Http.Err, Http.Up>) -> IO(Unit):
  match r:
    case Fail{e}:
      die("upload.how ca failed")
    case Done{up}:
      do IO<Unit>:
        w : Http.Up & Result<&2, &2, Http.Err, Unit> <- Http.upload.write(up, Http.from_string("hi"))
        x : Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream> <- upload.sent(w)
        stream.ok("upload.how ca", x)

def upload.fail(r: Result<&1, &1, Http.Err, Http.Up>) -> IO(Unit):
  match r:
    case Done{up}:
      do IO<Unit>:
        x : Result<&1, &1, Http.Err, Http.Stream> <- Http.upload.finish(up)
        die("upload.how default store accepted private CA")
    case Fail{e}:
      stream.fail("upload.how default store rejects private CA", 100, (None{}, Fail{e}))

def run(+ca: String, +base: String) -> IO(Unit):
  do IO<Unit>:
    ok : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.ca("GET", base ++ "/ok", Http.empty(), Http.from_string(""), ca)
    body.ok("fetch.ca", "ok", ok)
    gone : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.ca("GET", base ++ "/go", Http.empty(), Http.from_string(""), ca)
    body.ok("fetch.ca redirect", "ok", gone)
    bare : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch("GET", base ++ "/ok", Http.empty(), Http.from_string(""))
    tls.fail("default store rejects private CA", 100, bare)
    missing : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.ca("GET", base ++ "/ok", Http.empty(), Http.from_string(""), "/nonexistent/bend-kit-ca.pem")
    tls.fail("missing CA file", 22, missing)
    pooled : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch.ca(Http.pool.new(), "GET", base ++ "/ok", Http.empty(), Http.from_string(""), ca)
    pool.ok(pooled)
    opened : Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream> <-
      Http.open.how(Http.ModeFollow{}, None{}, ca, None{}, "GET", base ++ "/go", Http.empty(), Http.from_string(""), 30000)
    stream.ok("open.how ca redirect", opened)
    plain : Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream> <-
      Http.open.how(Http.ModeFollow{}, None{}, "", None{}, "GET", base ++ "/ok", Http.empty(), Http.from_string(""), 30000)
    stream.fail("open.how default store rejects private CA", 100, plain)
    uploaded : Result<&1, &1, Http.Err, Http.Up> <-
      Http.upload.how(None{}, ca, "POST", base ++ "/ok", Http.empty(), 30000)
    upload.ok(uploaded)
    refused : Result<&1, &1, Http.Err, Http.Up> <-
      Http.upload.how(None{}, "", "POST", base ++ "/ok", Http.empty(), 30000)
    upload.fail(refused)

def main.args(args: List<&1, String>) -> IO(Unit):
  match args:
    case Con{ca, Con{base, Nil{}}}:
      run(ca, base)
    case _:
      die("ca_check needs a CA file path and the server base URL")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    main.args(List.tail(&1, String, args))
