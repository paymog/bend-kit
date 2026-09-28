# HTTP request parse phase breakdown (native). Same input as codec bench.
import Base
import ../../time/time.bend as Time
import ../http.bend as Http

def iters() -> Nat:
  20000n

def req_raw() -> String:
  "POST /api/v1/items?page=2&sort=name HTTP/1.1\r\nHost: example.com\r\nUser-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36\r\nAccept: application/json, text/plain, */*\r\nAccept-Language: en-US,en;q=0.9\r\nAccept-Encoding: gzip, deflate, br\r\nContent-Type: application/json\r\nCookie: session=0123456789abcdef; theme=dark\r\nConnection: keep-alive\r\nContent-Length: 26\r\n\r\n{\"name\":\"widget\",\"qty\":12}"

def len(s: String, n: U32) -> U32:
  match s:
    case SNil{}:
      n
    case SCon{_, t}:
      len(t, (n + 1 : U32))

def list_len(xs: List<&2, String>, n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{_, t}:
      list_len(t, (n + 1 : U32))

def score.got(g: Http.Got) -> U32:
  match g:
    case Http.GotReq{req}:
      Http.Req{method, path, headers, body} = req
      (len(method, 0) + len(path, 0) + 1 : U32)
    case Http.GotHead{req}:
      2
    case Http.GotMore{}:
      3
    case Http.GotBad{}:
      0

def score.maybe(m: Maybe<&1, Http.Req>) -> U32:
  match m:
    case None{}:
      0
    case Some{req}:
      Http.Req{method, path, headers, body} = req
      len(method, 0)

def score.fields(fs: Http.Fields) -> U32:
  match fs:
    case Http.FieldsBad{}:
      0
    case Http.FieldsOk{m}:
      1

def score.headers(m: Maybe<&2, Map<&2, List<&2, String>>>) -> U32:
  match m:
    case None{}:
      0
    case Some{h}:
      1

def head_parts(+raw: String) -> String & String:
  Http.split_at_blank(raw)

def header_lines(+head: String) -> List<&2, String>:
  String.lines(head)

def first_rest(xs: List<&2, String>) -> String & List<&2, String>:
  match xs:
    case Nil{}:
      ("", Nil{})
    case Con{line, rest}:
      (line, rest)


def loop.full(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.full(p, raw, (acc + score.maybe(Http.parse(raw)) : U32))

def loop.split.score(acc: U32, hb: String & String) -> U32:
  (+head, +rest) = hb
  (acc + len(head, 0) + len(rest, 0) : U32)

def loop.split(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.split(p, raw, loop.split.score(acc, head_parts(raw)))

def loop.whole.score(acc: U32, hb: String & String) -> U32:
  (+head, +rest) = hb
  (acc + Bool.to_u32(Http.blank_end(head)) + len(rest, 0) : U32)

def loop.whole(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.whole(p, raw, loop.whole.score(acc, head_parts(raw)))

def loop.lines.n(acc: U32, +head: String) -> U32:
  (acc + list_len(header_lines(head), 0) : U32)

def loop.lines.score(acc: U32, hb: String & String) -> U32:
  (+head, +rest) = hb
  loop.lines.n(acc, head)

def loop.lines(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.lines(p, raw, loop.lines.score(acc, head_parts(raw)))

def loop.start.score(acc: U32, mpv: String & String & String) -> U32:
  (+method, path, ver) = mpv
  (acc + len(method, 0) + len(path, 0) + len(ver, 0) : U32)

def loop.start.lr(acc: U32, lr: String & List<&2, String>) -> U32:
  (+line, xs) = lr
  loop.start.score(acc, Http.start_line(line))

def loop.start.h(acc: U32, +head: String) -> U32:
  loop.start.lr(acc, first_rest(header_lines(head)))

def loop.start.score_hb(acc: U32, hb: String & String) -> U32:
  (+head, +rest) = hb
  loop.start.h(acc, head)

def loop.start(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.start(p, raw, loop.start.score_hb(acc, head_parts(raw)))

def loop.field_ops.kv(acc: U32, kv: String & String) -> U32:
  (k, v) = kv
  (acc + len(k, 0) + len(Http.trim(v), 0) : U32)

def loop.field_ops.go(xs: List<&2, String>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{line, rest}:
      loop.field_ops.go(rest, loop.field_ops.kv(acc, Http.split_colon(Http.drop_cr(line))))

def loop.field_ops.lr(acc: U32, lr: String & List<&2, String>) -> U32:
  (+line, xs) = lr
  loop.field_ops.go(xs, acc)

def loop.field_ops.h(acc: U32, +head: String) -> U32:
  loop.field_ops.lr(acc, first_rest(header_lines(head)))

def loop.field_ops.score_hb(acc: U32, hb: String & String) -> U32:
  (+head, +rest) = hb
  loop.field_ops.h(acc, head)

def loop.field_ops(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.field_ops(p, raw, loop.field_ops.score_hb(acc, head_parts(raw)))

def loop.map_build.lr(acc: U32, lr: String & List<&2, String>) -> U32:
  (+line, xs) = lr
  (acc + score.headers(Http.parse.headers(xs, Http.FieldsOk{Http.empty()})) : U32)

def loop.map_build.h(acc: U32, +head: String) -> U32:
  loop.map_build.lr(acc, first_rest(header_lines(head)))

def loop.map_build.score_hb(acc: U32, hb: String & String) -> U32:
  (+head, +rest) = hb
  loop.map_build.h(acc, head)

def loop.map_build(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.map_build(p, raw, loop.map_build.score_hb(acc, head_parts(raw)))

def loop.head_got(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.head_got(p, raw, (acc + score.got(Http.parse.got(raw)) : U32))

def loop.body_len.tick(acc: U32, b: Http.Hold) -> U32:
  (acc + 1 : U32)

def loop.body_len.fs(acc: U32, fs: Maybe<&2, Map<&2, List<&2, String>>>, +rest: String) -> U32:
  match fs:
    case None{}:
      acc
    case Some{+h}:
      loop.body_len.tick(acc, Http.parse.body(h, rest))

def loop.body_len.lr(acc: U32, +rest: String, lr: String & List<&2, String>) -> U32:
  (+line, xs) = lr
  loop.body_len.fs(acc, Http.parse.headers(xs, Http.FieldsOk{Http.empty()}), rest)

def loop.body_len.h(acc: U32, +head: String, +rest: String) -> U32:
  loop.body_len.lr(acc, rest, first_rest(header_lines(head)))

def loop.body_len.score_hb(acc: U32, hb: String & String) -> U32:
  (+head, +rest) = hb
  loop.body_len.h(acc, head, rest)

def loop.body_len(n: Nat, +raw: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      loop.body_len(p, raw, loop.body_len.score_hb(acc, head_parts(raw)))

def stop(+name: String, t0: Time.Duration, sum: U32) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(sum))

def run.full() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("full", t0, loop.full(iters(), req_raw(), 0))

def run.split() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("split", t0, loop.split(iters(), req_raw(), 0))

def run.whole() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("whole", t0, loop.whole(iters(), req_raw(), 0))

def run.lines() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("lines", t0, loop.lines(iters(), req_raw(), 0))

def run.start_line() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("start_line", t0, loop.start(iters(), req_raw(), 0))

def run.field_ops() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("field_ops", t0, loop.field_ops(iters(), req_raw(), 0))

def run.map_build() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("map_build", t0, loop.map_build(iters(), req_raw(), 0))

def run.head_got() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("head_got", t0, loop.head_got(iters(), req_raw(), 0))

def run.body_len() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    stop("body_len", t0, loop.body_len(iters(), req_raw(), 0))

def main() -> IO(Unit):
  do IO<Unit>:
    run.full()
    run.split()
    run.whole()
    run.lines()
    run.start_line()
    run.field_ops()
    run.map_build()
    run.head_got()
    run.body_len()
