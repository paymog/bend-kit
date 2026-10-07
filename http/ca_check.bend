import Base
import ./http.bend as Http

def die(+why: String) -> IO(Unit):
  IO.die(Unit, 1, why)

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
          tls.code(name, code, U32.is_eq(code, want))
        case other:
          die(name ++ " was not a TLS error")

def pool.ok(pr: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  (p, r) = pr
  do IO<Unit>:
    body.ok("pool.fetch.ca", "ok", r)
    Http.pool.close(p)

def run(+ca: String) -> IO(Unit):
  do IO<Unit>:
    ok : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.ca("GET", "https://localhost:39446/ok", Http.empty(), Http.from_string(""), ca)
    body.ok("fetch.ca", "ok", ok)
    gone : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.ca("GET", "https://localhost:39446/go", Http.empty(), Http.from_string(""), ca)
    body.ok("fetch.ca redirect", "ok", gone)
    bare : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch("GET", "https://localhost:39446/ok", Http.empty(), Http.from_string(""))
    tls.fail("default store rejects private CA", 100, bare)
    missing : Result<&1, &1, Http.Err, Http.Res> <-
      Http.fetch.ca("GET", "https://localhost:39446/ok", Http.empty(), Http.from_string(""), "/nonexistent/bend-kit-ca.pem")
    tls.fail("missing CA file", 22, missing)
    pooled : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <-
      Http.pool.fetch.ca(Http.pool.new(), "GET", "https://localhost:39446/ok", Http.empty(), Http.from_string(""), ca)
    pool.ok(pooled)

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
