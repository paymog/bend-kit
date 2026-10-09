import Base
import ./sse.bend as Sse
import ./llm.bend as Llm
import ../http/http.bend as Http
import ../http/admission.bend as Admission
import ../http/completion.bend as Completion
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

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

# Two 529s, then a 200; then stop listening, so an extra attempt finds no listener.
def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- Http.conn(~(req => wrap(s.overloaded(req))), ~Completion.ignore, Http.limits(1048576n), inbox, a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- Http.conn(~(req => wrap(s.overloaded(req))), ~Completion.ignore, Http.limits(1048576n), inbox, b)
    c : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- Http.conn(~(req => wrap(s.fine(req))), ~Completion.ignore, Http.limits(1048576n), inbox, c)
    Listener.close(l3)
    Admission.close(inbox)

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

def served(m: Maybe<&1, Unit>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "fail the server still waits for an attempt")
    case Some{u}:
      IO.print("ok 3 attempts arrived, and no more")

# The POST retries as llm judges, through Hairpin: 529 is not one of Hairpin's own retry statuses.
def overloaded() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47853))
    ch : Chan(Unit) <- IO.fork(Unit, serve(l))
    x : Llm.Client & Result<&1, &1, Llm.Err, Json.Val> <- Llm.send.raw(Llm.base(Llm.anthropic("k"), "http://127.0.0.1:47853"), Json.Flag{True{}})
    got(x)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served(m)

def main() -> IO(Unit):
  do IO<Unit>:
    verdict("20000 events in 7-byte reads", chunks(many(20000), 7), 20000, 88890)
    verdict("20000 events in 65536-byte reads", chunks(many(20000), 65536), 20000, 88890)
    verdict("1 MiB data line in 65536-byte reads", chunks(big(1048576), 65536), 1, 1048576)
    overloaded()
