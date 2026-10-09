# Live S3 smoke: put, head, get, list with continuation and delimiter, delete, then a typed 404.
# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL, S3_BUCKET (default bend-kit-smoke),
# S3_VIRTUAL_HOSTED=1 for virtual-hosted addressing. The bucket must exist.
import Base
import ./sigv4.bend as S3
import bend-kit-hairpin@0.2.1.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def net(e: Http.Err) -> String:
  match e:
    case Http.ErrUrl{}:
      "bad url"
    case Http.ErrDns{}:
      "dns"
    case Http.ErrConnect{code, why}:
      "connect: " ++ why
    case Http.ErrTls{code, why}:
      "tls: " ++ why
    case Http.ErrRead{code, why}:
      "read: " ++ why
    case Http.ErrWrite{code, why}:
      "write: " ++ why
    case Http.ErrTimeout{}:
      "timeout"
    case Http.ErrRedirect{}:
      "redirect"
    case Http.ErrBad{}:
      "bad response"

def err(e: S3.Err) -> String:
  match e:
    case S3.ErrNet{Hairpin.ErrHttp{x}}:
      net(x)
    case S3.ErrNet{Hairpin.ErrDenied{why}}:
      "denied: no attempt started"
    case S3.ErrSign{code, why}:
      "sign: " ++ why
    case S3.ErrConfig{why}:
      why
    case S3.ErrS3{+s, code, m}:
      "status " ++ U32.show(s) ++ " " ++ code ++ ": " ++ m
    case S3.ErrXml{b}:
      "bad xml: " ++ b

def want(ok: Bool, what: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ what)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ what)

def got(-A: Type, what: String, x: S3.Client & Result<&1, &1, S3.Err, A>) -> IO(S3.Client & A):
  (c, r) = x
  match r:
    case Fail{e}:
      IO.die(S3.Client & A, 1, "FAIL " ++ what ++ ": " ++ err(e))
    case Done{v}:
      IO.pure(S3.Client & A, (c, v))

def s.put.check(key: String, y: S3.Client & String) -> IO(S3.Client):
  (c, +etag) = y
  do IO<S3.Client>:
    want(Bool.not(String.is_empty(etag)), "put " ++ key ++ " etag " ++ etag)
    return c

def s.put(+bucket: String, +key: String, +body: String, c: S3.Client) -> IO(S3.Client):
  do IO<S3.Client>:
    x : S3.Client & Result<&1, &1, S3.Err, String> <- S3.put(c, bucket, key, "text/plain", Http.from_string(body))
    y : S3.Client & String <- got(String, "put " ++ key, x)
    s.put.check(key, y)

def s.head.check(+n: Nat, y: S3.Client & S3.Meta) -> IO(S3.Client):
  (c, m) = y
  S3.Meta{+size, etag, +mime, mod} = m
  do IO<S3.Client>:
    want(Bool.and(Nat.is_eq(size, n), String.eq(mime, "text/plain")), "head size " ++ Nat.show(size) ++ " type " ++ mime)
    return c

def s.head(+bucket: String, +key: String, +n: Nat, c: S3.Client) -> IO(S3.Client):
  do IO<S3.Client>:
    x : S3.Client & Result<&1, &1, S3.Err, S3.Meta> <- S3.head(c, bucket, key)
    y : S3.Client & S3.Meta <- got(S3.Meta, "head " ++ key, x)
    s.head.check(n, y)

def s.get.check(+want_body: String, y: S3.Client & Bytes.Bytes) -> IO(S3.Client):
  (c, b) = y
  +text = Http.to_string(b)
  do IO<S3.Client>:
    want(String.eq(text, want_body), "get body " ++ text)
    return c

def s.get(+bucket: String, +key: String, +body: String, c: S3.Client) -> IO(S3.Client):
  do IO<S3.Client>:
    x : S3.Client & Result<&1, &1, S3.Err, Bytes.Bytes> <- S3.get(c, bucket, key)
    y : S3.Client & Bytes.Bytes <- got(Bytes.Bytes, "get " ++ key, x)
    s.get.check(body, y)

def keys(os: List<&2, S3.Object>) -> List<&2, String>:
  match os:
    case Nil{}:
      Nil{}
    case Con{S3.Object{k, sz, e, m}, t}:
      Con{k, keys(t)}

def s.list.check(+expect: String, +expect_pre: String, y: S3.Client & S3.Page) -> IO(S3.Client):
  (c, p) = y
  S3.Page{os, ps, next} = p
  +ks = String.join(keys(os), ",")
  +pre = String.join(ps, ",")
  do IO<S3.Client>:
    want(Bool.and(String.eq(ks, expect), String.eq(pre, expect_pre)), "list [" ++ ks ++ "] prefixes [" ++ pre ++ "]")
    return c

# max 1 forces one page per key, so every key past the first comes by continuation token.
def s.list(+bucket: String, +prefix: String, +delim: String, +expect: String, +expect_pre: String, c: S3.Client) -> IO(S3.Client):
  do IO<S3.Client>:
    x : S3.Client & Result<&1, &1, S3.Err, S3.Page> <- S3.list.all(c, bucket, prefix, delim, 1)
    y : S3.Client & S3.Page <- got(S3.Page, "list " ++ prefix, x)
    s.list.check(expect, expect_pre, y)

def s.delete.done(y: S3.Client & Unit) -> IO(S3.Client):
  (c, u) = y
  IO.pure(S3.Client, c)

def s.delete(+bucket: String, +key: String, c: S3.Client) -> IO(S3.Client):
  do IO<S3.Client>:
    x : S3.Client & Result<&1, &1, S3.Err, Unit> <- S3.delete(c, bucket, key)
    y : S3.Client & Unit <- got(Unit, "delete " ++ key, x)
    s.delete.done(y)

def no_such_key(e: S3.Err) -> Bool:
  match e:
    case S3.ErrS3{+s, +code, m}:
      Bool.and(U32.is_eq(s, 404), String.eq(code, "NoSuchKey"))
    case _:
      False{}

def s.missing.check(x: S3.Client & Result<&1, &1, S3.Err, Bytes.Bytes>) -> IO(S3.Client):
  (c, r) = x
  match r:
    case Done{b}:
      do IO<S3.Client>:
        want(False{}, "get after delete answered 2xx")
        return c
    case Fail{+e}:
      do IO<S3.Client>:
        want(no_such_key(e), "get after delete: " ++ err(e))
        return c

def s.missing(+bucket: String, +key: String, c: S3.Client) -> IO(S3.Client):
  do IO<S3.Client>:
    x : S3.Client & Result<&1, &1, S3.Err, Bytes.Bytes> <- S3.get(c, bucket, key)
    s.missing.check(x)

def s.reject.empty.check(x: S3.Client & Result<&1, &1, S3.Err, Unit>) -> IO(S3.Client):
  (c, r) = x
  match r:
    case Fail{S3.ErrConfig{why}}:
      do IO<S3.Client>:
        want(True{}, "empty key rejected: " ++ why)
        return c
    case Fail{e}:
      IO.die(S3.Client, 1, "wrong empty-key error: " ++ err(e))
    case Done{u}:
      IO.die(S3.Client, 1, "empty key deleted bucket")

def s.reject.empty(+bucket: String, c: S3.Client) -> IO(S3.Client):
  do IO<S3.Client>:
    x : S3.Client & Result<&1, &1, S3.Err, Unit> <- S3.delete(c, bucket, "")
    s.reject.empty.check(x)

# '&' and '+' test XML entities and path encoding; 'ü' tests UTF-8.
def K1() -> String:
  "smoke/a b&c+ü.txt"

def K2() -> String:
  "smoke/two.txt"

def K3() -> String:
  "smoke/d/three.txt"

def run(c0: S3.Client, +bucket: String) -> IO(Unit):
  +k1 = K1()
  +k2 = K2()
  +k3 = K3()
  do IO<Unit>:
    c1 : S3.Client <- s.put(bucket, k1, "hello s3", c0)
    c2 : S3.Client <- s.put(bucket, k2, "second", c1)
    c3 : S3.Client <- s.put(bucket, k3, "third", c2)
    c4 : S3.Client <- s.head(bucket, k1, 8n, c3)
    c5 : S3.Client <- s.get(bucket, k1, "hello s3", c4)
    c6 : S3.Client <- s.list(bucket, "smoke/", "", k1 ++ "," ++ k3 ++ "," ++ k2, "", c5)
    c7 : S3.Client <- s.list(bucket, "smoke/", "/", k1 ++ "," ++ k2, "smoke/d/", c6)
    c8 : S3.Client <- s.delete(bucket, k1, c7)
    c9 : S3.Client <- s.delete(bucket, k2, c8)
    c10 : S3.Client <- s.delete(bucket, k3, c9)
    c11 : S3.Client <- s.missing(bucket, k1, c10)
    c12 : S3.Client <- s.reject.empty(bucket, c11)
    c13 : S3.Client <- s.list(bucket, "smoke/", "", "", "", c12)
    S3.close(c13)

def style(cfg: S3.Config, virtual: Bool) -> S3.Config:
  S3.Config{endpoint, region, old, creds} = cfg
  match virtual:
    case True{}:
      S3.Config{endpoint, region, S3.Virtual{}, creds}
    case False{}:
      S3.Config{endpoint, region, old, creds}

def start(r: Result<&1, &1, S3.Err, S3.Config>, +bucket: String, virtual: Bool) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("skip s3: " ++ err(e))
    case Done{cfg}:
      run(S3.new(style(cfg, virtual)), bucket)

def main() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, S3.Err, S3.Config> <- S3.from_env()
    b : Result<&1, &1, U32 & String, String> <- IO.get_env("S3_BUCKET")
    v : Result<&1, &1, U32 & String, String> <- IO.get_env("S3_VIRTUAL_HOSTED")
    start(r, S3.or(S3.env(b), "bend-kit-smoke"), String.eq(S3.env(v), "1"))
