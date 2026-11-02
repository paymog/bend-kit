import Base
import ./sse.bend as Sse
import ./llm.bend as Llm
import bend-kit-hairpin@0.13.0.1/hairpin.bend as Hairpin
import bend-kit-http@0.38.1.1/http.bend as Http
import bend-kit-http@0.38.1.1/admission.bend as Admission
import bend-kit-http@0.38.1.1/completion.bend as Completion
import bend-kit-json@0.7.0.0/json.bend as Json
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

# The laws run in the checker. This runs the parser on the runtime at sizes the checker would not reach.

# n events, each "data: <i>\n\n" on CRLF ends.
def events(n: Nat, +i: U32, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match n:
    case 0n:
      acc
    case 1n+p:
      events(p, (i + 1 : U32), Con{Bytes.from_string("event: e\r\ndata: " ++ U32.show(i) ++ "\r\n\r\n"), acc})

def many(+n: U32) -> Bytes.Bytes:
  Bytes.concat(List.reverse(&1, Bytes.Bytes, events(U32.to_nat(n), 0, Nil{})))

# One event whose data line holds n bytes.
def big(+n: U32) -> Bytes.Bytes:
  Bytes.concat([Bytes.from_string("data: "), Bytes.new(n), Bytes.from_string("\n\n")])

# f: at least the events left. c counts events; t sums their data lengths.
def drain(f: Nat, r: Sse.Reader & Sse.Next, +c: U32, +t: U32) -> Sse.Reader & U32 & U32:
  match f:
    case 0n:
      (rd, n) = r
      (rd, c, t)
    case 1n+p:
      (rd, n) = r
      match n:
        case Sse.Got{e}:
          Sse.Message{name, data, id} = e
          Bytes.Bytes{+len, buf} = data
          drain(p, Sse.next(rd), (c + 1 : U32), (t + len : U32))
        case Sse.Want{}:
          (rd, c, t)

def step(f: Nat, +k: U32, +at: U32, r: Sse.Reader & U32 & U32, rest: Bytes.Bytes & Bytes.Bytes) -> U32 & U32:
  match f:
    case 0n:
      (rd, c, t) = r
      (c, t)
    case 1n+p:
      (rd, c, t) = r
      (whole, piece) = rest
      step(p, k, (at + k : U32), drain(Nat.add(U32.to_nat(k), 1n), Sse.next(Sse.feed(rd, piece)), c, t), Bytes.slice(whole, (at + k : U32), k))

# Feeds b to a reader k bytes at a time, reading every event after each piece.
def chunks(b: Bytes.Bytes, +k: U32) -> U32 & U32:
  Bytes.Bytes{+len, buf} = b
  step(U32.to_nat(((len / k) + 1 : U32)), k, 0, (Sse.reader(), 0, 0), Bytes.slice(Bytes.Bytes{len, buf}, 0, k))

def verdict.of(good: Bool, +name: String, +gc: U32, +gt: U32) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.print("fail " ++ name ++ ": " ++ U32.show(gc) ++ " events, " ++ U32.show(gt) ++ " bytes")

def verdict(+name: String, r: U32 & U32, +c: U32, +t: U32) -> IO(Unit):
  (+gc, +gt) = r
  verdict.of(Bool.and(U32.is_eq(gc, c), U32.is_eq(gt, t)), name, gc, gt)

def reply(+status: U32, body: String) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{status, Http.set(Http.set(Http.empty(), "connection", "close"), "retry-after", "0"), Bytes.from_string(body)})

def s.overloaded(req: Http.Req) -> IO(Http.Res):
  reply(529, "{\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\"}}")

def s.fine(req: Http.Req) -> IO(Http.Res):
  reply(200, "{\"ok\":true}")

def wrap(op: IO(Http.Res)) -> IO(Http.Reply):
  do IO<Http.Reply>:
    res : Http.Res <- op
    return Http.Reply{res, Completion.Unobserved{}}

def serve.one(fine: Bool, +inbox: Chan(Admission.Command), a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  match fine:
    case True{}:
      Http.conn(~(req => wrap(s.fine(req))), ~Completion.ignore, Http.limits(1048576n), inbox, a)
    case False{}:
      Http.conn(~(req => wrap(s.overloaded(req))), ~Completion.ignore, Http.limits(1048576n), inbox, a)

def serve.go(ks: List<&2, Bool>, +inbox: Chan(Admission.Command), l: Listener) -> IO(Unit):
  match ks:
    case Nil{}:
      do IO<Unit>:
        Listener.close(l)
        Admission.close(inbox)
    case Con{k, rest}:
      do IO<Unit>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l2 : Listener <- serve.one(k, inbox, a)
        serve.go(rest, inbox, l2)

# One connection per script entry: a 200 for True, a 529 for False. Then stop listening, so an extra attempt finds no listener.
def serve(ks: List<&2, Bool>, l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    serve.go(ks, inbox, l)

def listen(+port: U32, ks: List<&2, Bool>) -> IO(Chan(Unit)):
  do IO<Chan(Unit)>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.fork(Unit, serve(ks, l))

def got.r(r: Result<&1, &1, Llm.Err, Json.Val>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "fail Anthropic's 529 was not retried to the 200")
    case Done{v}:
      IO.print("ok two 529s retried to a 200 within 2 retries")

def got(x: Llm.Client & Result<&1, &1, Llm.Err, Json.Val>) -> IO(Unit):
  (c, r) = x
  do IO<Unit>:
    Llm.close(c)
    got.r(r)

def served(+n: String, m: Maybe<&1, Unit>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "fail the server still waits for an attempt")
    case Some{u}:
      IO.print("ok " ++ n ++ " attempts arrived, and no more")

# The POST retries as llm judges, through Hairpin: 529 is not one of Hairpin's own retry statuses.
def overloaded() -> IO(Unit):
  do IO<Unit>:
    ch : Chan(Unit) <- listen(47853, [False{}, False{}, True{}])
    x : Llm.Client & Result<&1, &1, Llm.Err, Json.Val> <- Llm.send.raw(Llm.base(Llm.anthropic("k"), "http://127.0.0.1:47853"), Json.Flag{True{}})
    got(x)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("3", m)

def opened.r(c: Llm.Client, r: Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Unit):
  match r:
    case Fail{e}:
      do IO<Unit>:
        Llm.close(c)
        IO.die(Unit, 1, "fail the stream open did not retry two 529s to the 200")
    case Done{s}:
      do IO<Unit>:
        d : Llm.Client <- Llm.stream.close(c, s)
        Llm.close(d)
        IO.print("ok a stream open retried two 529s to a 200 within 2 retries")

def opened(x: Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Unit):
  (c, r) = x
  opened.r(c, r)

def refused.api(good: Bool, +status: U32, +body: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok the budget spent, the last 529 comes back with its body")
    case False{}:
      IO.die(Unit, 1, "fail the stream ended with " ++ U32.show(status) ++ " " ++ body)

def refused.r(r: Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Unit):
  match r:
    case Fail{Llm.ErrApi{+status, +body}}:
      refused.api(Bool.and(U32.is_eq(status, 529), String.eq(body, "{\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\"}}")), status, body)
    case Fail{Llm.ErrNet{e}}:
      IO.die(Unit, 1, "fail the stream ended with a network error")
    case Fail{Llm.ErrReply{b}}:
      IO.die(Unit, 1, "fail the stream ended with a bad reply")
    case Done{s}:
      IO.die(Unit, 1, "fail a 529 stream opened")

def refused(x: Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Unit):
  (c, r) = x
  do IO<Unit>:
    Llm.close(c)
    refused.r(r)

# A stream open retries a 529 through Hairpin as call does. One retry is a budget of 2: the second 529 is the answer.
def overloaded.stream() -> IO(Unit):
  do IO<Unit>:
    ch : Chan(Unit) <- listen(47854, [False{}, False{}, True{}])
    x : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(Llm.base(Llm.anthropic("k"), "http://127.0.0.1:47854"), Json.Flag{True{}})
    opened(x)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("3", m)
    ch2 : Chan(Unit) <- listen(47855, [False{}, False{}])
    y : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(Llm.retry(Llm.base(Llm.anthropic("k"), "http://127.0.0.1:47855"), 1), Json.Flag{True{}})
    refused(y)
    m2 : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch2))
    served("2", m2)

def sse.reply(req: Http.Req) -> IO(Http.Reply):
  wrap(IO.pure(Http.Res, Http.Res{200, Http.set(Http.empty(), "content-type", "text/event-stream"), Bytes.from_string("data: a\n\ndata: b\n\n")}))

# One keep-alive connection, then stop listening.
def sse.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- Http.conn(~sse.reply, ~Completion.ignore, Http.limits(1048576n), inbox, a)
    Listener.close(l2)
    Admission.close(inbox)

def pool.ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "fail " ++ name)

# f: events left to read. n counts events.
def pool.read(f: Nat, +name: String, x: Llm.Stream & Result<&1, &1, Llm.Err, Maybe<&1, Sse.Message>>, +n: U32) -> IO(Llm.Stream & U32):
  match f:
    case 0n:
      (s, r) = x
      IO.pure(Llm.Stream & U32, (s, n))
    case 1n+g:
      (s, r) = x
      match r:
        case Fail{e}:
          IO.die(Llm.Stream & U32, 1, "fail " ++ name ++ ": read failed")
        case Done{m}:
          match m:
            case None{}:
              IO.pure(Llm.Stream & U32, (s, n))
            case Some{e}:
              do IO<Llm.Stream & U32>:
                y : Llm.Stream & Result<&1, &1, Llm.Err, Maybe<&1, Sse.Message>> <- Llm.event(s)
                pool.read(g, name, y, (n + 1 : U32))

def pool.end(+name: String, c: Llm.Client, z: Llm.Stream & U32) -> IO(Llm.Client):
  (s, +n) = z
  do IO<Llm.Client>:
    pool.ok(U32.is_eq(n, 2), name)
    Llm.stream.close(c, s)

def pool.got(+name: String, x: Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Llm.Client):
  (c, r) = x
  match r:
    case Fail{e}:
      IO.die(Llm.Client, 1, "fail " ++ name ++ ": open failed")
    case Done{s}:
      do IO<Llm.Client>:
        y : Llm.Stream & Result<&1, &1, Llm.Err, Maybe<&1, Sse.Message>> <- Llm.event(s)
        z : Llm.Stream & U32 <- pool.read(8n, name, y, 0)
        pool.end(name, c, z)

def pool.early(x: Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Llm.Client):
  (c, r) = x
  match r:
    case Fail{e}:
      IO.die(Llm.Client, 1, "fail pooled llm stream: third open failed")
    case Done{s}:
      Llm.stream.close(c, s)

def pool.idle(pm: Http.Pool & Maybe<&1, Http.Conn>) -> IO(Unit):
  (p, m) = pm
  match m:
    case None{}:
      do IO<Unit>:
        Http.pool.close(p)
        IO.print("ok pooled llm stream: a stream closed before its end keeps its connection out of the pool")
    case Some{k}:
      do IO<Unit>:
        Http.conn.close(k)
        Http.pool.close(p)
        IO.die(Unit, 1, "fail pooled llm stream: a stream closed early gave its connection back")

def pool.left(c: Llm.Client) -> IO(Unit):
  Llm.Client{api, b, h, ms, n, hc} = c
  Hairpin.Client{o, p, j, br} = hc
  pool.idle(Http.pool.take(p, Http.pool.key("http", "127.0.0.1", 47856)))

# The server takes one connection, so the second and third streams must reuse it.
def pooled.stream() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47856))
    ch : Chan(Unit) <- IO.fork(Unit, sse.serve(l))
    a : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <-
      Llm.stream.raw(Llm.retry(Llm.base(Llm.anthropic("k"), "http://127.0.0.1:47856"), 0), Json.Flag{True{}})
    c1 : Llm.Client <- pool.got("pooled llm stream: first read to the end", a)
    b : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(c1, Json.Flag{True{}})
    c2 : Llm.Client <- pool.got("pooled llm stream: second on the same connection", b)
    d : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(c2, Json.Flag{True{}})
    c3 : Llm.Client <- pool.early(d)
    pool.left(c3)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("1", m)

def main() -> IO(Unit):
  do IO<Unit>:
    verdict("20000 events in 7-byte reads", chunks(many(20000), 7), 20000, 88890)
    verdict("20000 events in 65536-byte reads", chunks(many(20000), 65536), 20000, 88890)
    verdict("1 MiB data line in 65536-byte reads", chunks(big(1048576), 65536), 1, 1048576)
    overloaded()
    overloaded.stream()
    pooled.stream()
