# HTTP codec benchmark: parse and encode one fixed request and response (see README.md).
import Base
import ../../time/time.bend as Time
import ../http.bend as Http
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def iters() -> Nat:
  20000n

def req_raw() -> String:
  "POST /api/v1/items?page=2&sort=name HTTP/1.1\r\nHost: example.com\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36\r\nAccept: application/json, text/plain, */*\r\nAccept-Language: en-US,en;q=0.9\r\nAccept-Encoding: gzip, deflate, br\r\nContent-Type: application/json\r\nCookie: session=0123456789abcdef; theme=dark\r\nConnection: keep-alive\r\nContent-Length: 26\r\n\r\n{\"name\":\"widget\",\"qty\":12}"

def res_raw() -> String:
  "HTTP/1.1 200 OK\r\nDate: Fri, 25 Sep 2026 12:00:00 GMT\r\nServer: bend-kit\r\nContent-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nX-Request-Id: 7f3c2a10-5b6e-4d8f-9a1b-2c3d4e5f6a7b\r\nContent-Length: 34\r\n\r\n{\"id\":42,\"name\":\"widget\",\"qty\":12}"

def len(s: String, n: U32) -> U32:
  match s:
    case SNil{}:
      n
    case SCon{h, t}:
      len(t, (n + 1 : U32))

# Checksum: the sum over lines of h = h*31 + c (u32), so header order does not count.
def hash(s: String, +h: U32, +acc: U32) -> U32:
  match s:
    case SNil{}:
      (acc + h : U32)
    case SCon{Chr{+c}, t}:
      +nl = U32.is_eq(c, 10)
      hash(t, Bool.pick(U32, nl, 0, (h * 31 + c : U32)), Bool.pick(U32, nl, (acc + h : U32), acc))

def blen(p: Bytes.Bytes & U32) -> U32:
  (b, n) = p
  n

def vals(vs: List<&2, String>, +k: String, acc: U32) -> U32:
  match vs:
    case Nil{}:
      acc
    case Con{v, t}:
      vals(t, k, (acc + len(k, 0) + len(v, 0) + 1 : U32))

# Per field line: name length + value length + 1.
def fields(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case (k, vs) <> t:
      fields(t, vals(vs, k, acc))

def score.req(m: Maybe<&1, Http.Req>) -> U32:
  match m:
    case None{}:
      0
    case Some{r}:
      Http.Req{method, path, headers, body} = r
      (len(method, 0) + len(path, 0) + fields(Map.to_list(&2, List<&2, String>, headers), 0) + blen(Http.length(body)) : U32)

def score.res(m: Maybe<&1, Http.Res>) -> U32:
  match m:
    case None{}:
      0
    case Some{r}:
      Http.Res{status, headers, body} = r
      (status + fields(Map.to_list(&2, List<&2, String>, headers), 0) + blen(Http.length(body)) : U32)

def enc.req() -> Bytes.Bytes:
  Http.encode_req("POST", "/api/v1/items?page=2&sort=name", "example.com",
    Http.set(Http.set(Http.set(Http.empty(), "user-agent", "bend-kit-bench/1.0"), "accept", "application/json"), "content-type", "application/json"),
    Http.from_string("{\"name\":\"widget\",\"qty\":12}"))

def enc.res() -> Bytes.Bytes:
  Http.encode(Http.Res{200,
    Http.set(Http.set(Http.set(Http.set(Http.empty(), "date", "Fri, 25 Sep 2026 12:00:00 GMT"), "server", "bend-kit"), "content-type", "application/json; charset=utf-8"), "cache-control", "no-store"),
    Http.from_string("{\"id\":42,\"name\":\"widget\",\"qty\":12}")})

def loop.parse_req(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.parse_req(p, raw, (acc + score.req(Http.parse(raw)) : U32))

def loop.parse_res(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.parse_res(p, raw, (acc + score.res(Http.parse_res(raw)) : U32))

# Encode checksums: the total output length plus the hash of one output.
def loop.encode_req(n: Nat, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.encode_req(p, (acc + blen(Http.length(enc.req())) : U32))

def loop.encode_res(n: Nat, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.encode_res(p, (acc + blen(Http.length(enc.res())) : U32))

# Bend evaluates strictly: the sum is built before t1 is read.
def stop(+name: String, t0: Time.Duration, sum: U32, extra: U32) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show((sum + extra : U32)))

# The output hash is built by the caller, before t0.
def op.encode_res(extra: U32) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("encode_res", t0, loop.encode_res(iters(), 0), extra)

def op.encode_req(extra: U32) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("encode_req", t0, loop.encode_req(iters(), 0), extra)
    op.encode_res(hash(Http.to_string(enc.res()), 0, 0))

def op.parse_res(+raw: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("parse_res", t0, loop.parse_res(iters(), raw, 0), 0)
    op.encode_req(hash(Http.to_string(enc.req()), 0, 0))

def op.parse_req(+raw: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("parse_req", t0, loop.parse_req(iters(), raw, 0), 0)
    op.parse_res(res_raw())

def main() -> IO(Unit):
  op.parse_req(req_raw())
