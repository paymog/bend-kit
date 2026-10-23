import Base
import ./hairpin.bend as Hairpin
import bend-kit-http@0.36.0.0/http.bend as Http
import bend-kit-retry@0.2.0.0/retry.bend as Retry
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

def die(+why: String) -> IO(Unit):
  IO.die(Unit, 1, why)

def body.eq(+name: String, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      die(name ++ " body")

def body.shown(+name: String, +got: String, ok: Bool) -> IO(Unit):
  match ok:
    case False{}:
      die(name ++ " status")
    case True{}:
      body.eq(name, String.eq(got, "ok"))

def res.ok.of(+name: String, r: Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Unit):
  match r:
    case Fail{e}:
      die(name ++ " failed")
    case Done{res}:
      Http.Res{+status, headers, body} = res
      body.shown(name, Http.to_string(body), U32.is_eq(status, 200))

def res.ok(+name: String, x: Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Unit):
  (c, r) = x
  do IO<Unit>:
    Hairpin.close(c)
    res.ok.of(name, r)

def tls.code(+name: String, +code: U32, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      die(name ++ " code " ++ U32.show(code))

# EPROTO is 100 on macOS and 71 on Linux.
def tls.fail.of(+name: String, e: Hairpin.Err) -> IO(Unit):
  match e:
    case Hairpin.ErrHttp{Http.ErrTls{+code, why}}:
      tls.code(name, code, Bool.or(U32.is_eq(code, 100), U32.is_eq(code, 71)))
    case other:
      die(name ++ " was not a TLS error")

def res.fail.of(+name: String, r: Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Unit):
  match r:
    case Done{res}:
      die(name ++ " succeeded")
    case Fail{e}:
      tls.fail.of(name, e)

def res.fail(+name: String, x: Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Unit):
  (c, r) = x
  do IO<Unit>:
    Hairpin.close(c)
    res.fail.of(name, r)

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

def stream.ok.of(+name: String, r: Result<&1, &1, Hairpin.Err, Http.Stream>) -> IO(Unit):
  match r:
    case Fail{e}:
      die(name ++ " failed")
    case Done{st}:
      do IO<Unit>:
        got : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Bytes.Bytes>> <- Http.stream.read(st)
        stream.body(name, got)

def stream.ok(+name: String, x: Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream>) -> IO(Unit):
  (c, b, r) = x
  do IO<Unit>:
    Hairpin.close(c)
    stream.ok.of(name, r)

def stream.fail.of(+name: String, r: Result<&1, &1, Hairpin.Err, Http.Stream>) -> IO(Unit):
  match r:
    case Done{st}:
      do IO<Unit>:
        Http.stream.close(st)
        die(name ++ " succeeded")
    case Fail{e}:
      tls.fail.of(name, e)

def stream.fail(+name: String, x: Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream>) -> IO(Unit):
  (c, b, r) = x
  do IO<Unit>:
    Hairpin.close(c)
    stream.fail.of(name, r)

def judge.stream(r: Result<&1, &1, Http.Err, Http.Stream>) -> Result<&1, &1, Http.Err, Http.Stream> & Maybe<&2, String>:
  (r, None{})

def client(+ca: String) -> Hairpin.Client:
  Hairpin.ca(Hairpin.base(Hairpin.new(), "https://localhost:39447/"), ca)

def open(c: Hairpin.Client, +url: String) -> IO(Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream>):
  Hairpin.open.as(~judge.stream, c, Retry.Budget.new(1n, 0n, None{}), True{}, "identity", "GET", url, Http.empty(), Bytes.new(0))

def run(+ca: String) -> IO(Unit):
  do IO<Unit>:
    got : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(client(ca), "go")
    res.ok("request with ca, through a redirect", got)
    bare : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(client(""), "ok")
    res.fail("request: default store rejects private CA", bare)
    opened : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream> <- open(client(ca), "go")
    stream.ok("stream with ca, through a redirect", opened)
    plain : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Stream> <- open(client(""), "ok")
    stream.fail("stream: default store rejects private CA", plain)

def main.args(args: List<&1, String>) -> IO(Unit):
  match args:
    case Con{ca, Nil{}}:
      run(ca)
    case _:
      die("ca_check needs a CA file path")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    main.args(List.tail(&1, String, args))
