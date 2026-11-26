import Base
import ./sse.bend as Sse
import ./llm.bend as Llm
import bend-kit-hairpin@0.19.0.1/hairpin.bend as Hairpin
import bend-kit-http@0.45.0.1/http.bend as Http
import bend-kit-http@0.45.0.1/pure.bend as HttpPure
import bend-kit-http@0.45.0.1/admission.bend as Admission
import bend-kit-http@0.45.0.1/completion.bend as Completion
import bend-kit-json@0.7.3.1/json.bend as Json
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import bend-kit-wire@0.4.8.1/wire.bend as Wire

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

def reply(+status: U32, body: String) -> IO(HttpPure.Res):
  IO.pure(HttpPure.Res, HttpPure.Res{status, HttpPure.set(HttpPure.set(HttpPure.empty(), "connection", "close"), "retry-after", "0"), Bytes.from_string(body)})

def s.overloaded(req: HttpPure.Req) -> IO(HttpPure.Res):
  reply(529, "{\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\"}}")

def s.fine(req: HttpPure.Req) -> IO(HttpPure.Res):
  reply(200, "{\"ok\":true}")

def wrap(op: IO(HttpPure.Res)) -> IO(Http.Reply):
  do IO<Http.Reply>:
    res : HttpPure.Res <- op
    return Http.Reply{res, Completion.Unobserved{}}

def serve.one(fine: Bool, +inbox: Chan(Admission.Command), a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  match fine:
    case True{}:
      Http.conn(~(req => wrap(s.fine(req))), ~Completion.ignore, HttpPure.limits(1048576n), inbox, a)
    case False{}:
      Http.conn(~(req => wrap(s.overloaded(req))), ~Completion.ignore, HttpPure.limits(1048576n), inbox, a)

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

def url(+port: U32) -> String:
  "http://127.0.0.1:" ++ U32.show(port)

def listen.on(ks: List<&2, Bool>, b: Listener & U32) -> IO(Chan(Unit) & U32):
  (l, +port) = b
  do IO<Chan(Unit) & U32>:
    ch : Chan(Unit) <- IO.fork(Unit, serve(ks, l))
    return (ch, port)

def listen(ks: List<&2, Bool>) -> IO(Chan(Unit) & U32):
  do IO<Chan(Unit) & U32>:
    b : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    listen.on(ks, b)

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
def overloaded.on(x: Chan(Unit) & U32) -> IO(Unit):
  (ch, +port) = x
  do IO<Unit>:
    y : Llm.Client & Result<&1, &1, Llm.Err, Json.Val> <- Llm.send.raw(Llm.base(Llm.anthropic("k"), url(port)), Json.Flag{True{}})
    got(y)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("3", m)

def overloaded() -> IO(Unit):
  do IO<Unit>:
    x : Chan(Unit) & U32 <- listen([False{}, False{}, True{}])
    overloaded.on(x)

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

# A stream open retries a 529 through Hairpin as call does.
def overloaded.stream.on(x: Chan(Unit) & U32) -> IO(Unit):
  (ch, +port) = x
  do IO<Unit>:
    y : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(Llm.base(Llm.anthropic("k"), url(port)), Json.Flag{True{}})
    opened(y)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("3", m)

# One retry is a budget of 2: the second 529 is the answer.
def overloaded.spent.on(x: Chan(Unit) & U32) -> IO(Unit):
  (ch, +port) = x
  do IO<Unit>:
    y : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(Llm.retry(Llm.base(Llm.anthropic("k"), url(port)), 1), Json.Flag{True{}})
    refused(y)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("2", m)

def overloaded.stream() -> IO(Unit):
  do IO<Unit>:
    x : Chan(Unit) & U32 <- listen([False{}, False{}, True{}])
    overloaded.stream.on(x)
    y : Chan(Unit) & U32 <- listen([False{}, False{}])
    overloaded.spent.on(y)

def sse.reply(req: HttpPure.Req) -> IO(Http.Reply):
  wrap(IO.pure(HttpPure.Res, HttpPure.Res{200, HttpPure.set(HttpPure.empty(), "content-type", "text/event-stream"), Bytes.from_string("data: a\n\ndata: b\n\n")}))

# One keep-alive connection, then stop listening.
def sse.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- Http.conn(~sse.reply, ~Completion.ignore, HttpPure.limits(1048576n), inbox, a)
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

def pool.left(+port: U32, c: Llm.Client) -> IO(Unit):
  Llm.Client{api, b, h, ms, n, hc} = c
  Hairpin.Client{o, p, j, br} = hc
  pool.idle(Http.pool.take(p, HttpPure.pool.key("http", "127.0.0.1", port)))

# The server takes one connection, so the second and third streams must reuse it.
def pooled.stream.on(b: Listener & U32) -> IO(Unit):
  (l, +port) = b
  do IO<Unit>:
    ch : Chan(Unit) <- IO.fork(Unit, sse.serve(l))
    a : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <-
      Llm.stream.raw(Llm.retry(Llm.base(Llm.anthropic("k"), url(port)), 0), Json.Flag{True{}})
    c1 : Llm.Client <- pool.got("pooled llm stream: first read to the end", a)
    b2 : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(c1, Json.Flag{True{}})
    c2 : Llm.Client <- pool.got("pooled llm stream: second on the same connection", b2)
    d : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(c2, Json.Flag{True{}})
    c3 : Llm.Client <- pool.early(d)
    pool.left(port, c3)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("1", m)

def pooled.stream() -> IO(Unit):
  do IO<Unit>:
    b : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    pooled.stream.on(b)

def refused.reply(first: Bool) -> IO(Http.Reply):
  match first:
    case True{}:
      wrap(IO.pure(HttpPure.Res, HttpPure.Res{529, HttpPure.empty(), Bytes.from_string("{\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\"}}")}))
    case False{}:
      sse.reply(HttpPure.Req{"POST", "/", HttpPure.empty(), Bytes.new(0)})

def refused.request(req: HttpPure.Req) -> IO(Http.Reply):
  HttpPure.Req{method, path, headers, body} = req
  refused.reply(String.eq(Bytes.to_string(body), "true"))

def refused.serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    +inbox : Chan(Admission.Command) <- Admission.open(Admission.Caps{128, 128, 128})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- Http.conn(~refused.request, ~Completion.ignore, HttpPure.limits(1048576n), inbox, a)
    Listener.close(l2)
    Admission.close(inbox)

def refused.keep(x: Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Llm.Client):
  (c, r) = x
  do IO<Llm.Client>:
    refused.r(r)
    return c

def refused.pool.on(b: Listener & U32) -> IO(Unit):
  (l, +port) = b
  do IO<Unit>:
    ch : Chan(Unit) <- IO.fork(Unit, refused.serve(l))
    x : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <-
      Llm.stream.raw(Llm.timeout(Llm.retry(Llm.base(Llm.anthropic("k"), url(port)), 0), 1000), Json.Flag{True{}})
    c : Llm.Client <- refused.keep(x)
    y : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <- Llm.stream.raw(c, Json.Flag{False{}})
    d : Llm.Client <- pool.got("a drained refusal returns its connection for the next stream", y)
    Llm.close(d)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("1", m)

def refused.pool() -> IO(Unit):
  do IO<Unit>:
    b : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    refused.pool.on(b)

def refused.drop.idle(+name: String, pm: Http.Pool & Maybe<&1, Http.Conn>) -> IO(Unit):
  (p, m) = pm
  match m:
    case None{}:
      do IO<Unit>:
        Http.pool.close(p)
        pool.ok(True{}, name ++ ": no idle connection")
    case Some{k}:
      do IO<Unit>:
        Http.conn.close(k)
        Http.pool.close(p)
        pool.ok(False{}, name ++ ": no idle connection")

def refused.drop.left(+name: String, +port: U32, c: Llm.Client) -> IO(Unit):
  Llm.Client{api, b, h, ms, n, Hairpin.Client{o, p, j, br}} = c
  refused.drop.idle(name, Http.pool.take(p, HttpPure.pool.key("http", "127.0.0.1", port)))

def refused.drop.result(+limited: Bool, +port: U32, x: Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream>) -> IO(Unit):
  (c, r) = x
  match r:
    case Fail{Llm.ErrApi{+status, +body}}:
      +name = Bool.pick(String, limited, "piece-limited refusal", "cut-off refusal")
      +good = Bool.pick(Bool, limited,
        Bool.and(String.starts_with(body, "first"), Bool.and(Nat.is_lt(0n, String.length(body)), Nat.is_le(String.length(body), 4194304n))),
        String.eq(body, "partial"))
      do IO<Unit>:
        pool.ok(Bool.and(U32.is_eq(status, 529), good), name ++ ": original status and partial body")
        refused.drop.left(name, port, c)
    case Fail{e}:
      do IO<Unit>:
        Llm.close(c)
        IO.die(Unit, 1, "fail an incomplete refusal did not return ErrApi")
    case Done{s}:
      do IO<Unit>:
        d : Llm.Client <- Llm.stream.close(c, s)
        Llm.close(d)
        IO.die(Unit, 1, "fail an incomplete refusal opened a stream")

def refused.drop.reset(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 32), Bool.or(U32.is_eq(code, 54), U32.is_eq(code, 104)))

def refused.drop.eof(got: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (s, r) = got
  match r:
    case Done{body}:
      do IO<Unit>:
        Socket.close(s)
        pool.ok(String.eq(body, ""), "piece-limited refusal: peer closed the socket")
    case Fail{(code, why)}:
      do IO<Unit>:
        Socket.close(s)
        pool.ok(refused.drop.reset(code), "piece-limited refusal: peer reset the socket, not a timeout")

def refused.drop.sent(limited: Bool, sent: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match limited:
    case False{}:
      (s, r) = sent
      do IO<Unit>:
        u : Unit <- IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, r))
        Socket.close(s)
    case True{}:
      (s, r) = sent
      match r:
        case Fail{(code, why)}:
          do IO<Unit>:
            Socket.close(s)
            pool.ok(refused.drop.reset(code), "piece-limited refusal: peer closed during send")
        case Done{u}:
          do IO<Unit>:
            got : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(s, 4096, 3000)
            refused.drop.eof(got)

def refused.drop.send(+limited: Bool, s: Socket, body: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{len, words} = body
  do IO<Unit>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send.words(s, len, words)
    refused.drop.sent(limited, sent)

def refused.drop.reply(+limited: Bool, s: Socket) -> IO(Unit):
  # Each read is at most 65536 bytes, so this body cannot finish in 64 pieces.
  body = Bool.pick(Bytes.Bytes, limited,
    Bytes.append(Bytes.from_string("first"), Bytes.Bytes{4325371, Array.new(U32, 21n, 2021161080)}), Bytes.from_string("partial"))
  head = "HTTP/1.1 529 Overloaded\r\nContent-Length: " ++
    Bool.pick(String, limited, "4325376", "100") ++ "\r\n\r\n"
  refused.drop.send(limited, s, Bytes.append(Bytes.from_string(head), body))

def refused.drop.request(f: Nat, +limited: Bool, +acc: String, got: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match f:
    case 0n:
      IO.die(Unit, 1, "fail refusal server did not receive the request")
    case 1n+g:
      (s, r) = got
      match r:
        case Fail{e}:
          IO.die(Unit, 1, "fail refusal server could not read the request")
        case Done{piece}:
          +req = acc ++ piece
          Bool.pick(Socket -> IO(Unit), String.ends_with(req, "\r\n\r\ntrue"),
            (s => refused.drop.reply(limited, s)),
            (s => IO.bind(Socket & Result<&1, &1, U32 & String, String>, Unit,
              Wire.recv(s, 4096, 3000), next => refused.drop.request(g, limited, req, next))))(s)

def refused.drop.accepted(+limited: Bool, a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  (l, r) = a
  do IO<Unit>:
    Listener.close(l)
    s : Socket <- IO.try(Socket, IO.pure(Result<&1, &1, U32 & String, Socket>, r))
    got : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(s, 4096, 3000)
    refused.drop.request(8n, limited, "", got)

def refused.drop.serve(+limited: Bool, l: Listener) -> IO(Unit):
  do IO<Unit>:
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    refused.drop.accepted(limited, a)

def refused.drop.on(+limited: Bool, b: Listener & U32) -> IO(Unit):
  (l, +port) = b
  do IO<Unit>:
    ch : Chan(Unit) <- IO.fork(Unit, refused.drop.serve(limited, l))
    x : Llm.Client & Result<&1, &1, Llm.Err, Llm.Stream> <-
      Llm.stream.raw(Llm.timeout(Llm.retry(Llm.base(Llm.anthropic("k"), url(port)), 0), 3000), Json.Flag{True{}})
    refused.drop.result(limited, port, x)
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served("1", m)

def refused.drop(+limited: Bool) -> IO(Unit):
  do IO<Unit>:
    b : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    refused.drop.on(limited, b)

def codec.reply(r: Result<&1, &1, Llm.Err, Llm.Reply>) -> Bool:
  match r:
    case Done{Llm.Reply{id, model, +text, stop, input, output}}:
      String.eq(text, "Hi")
    case Fail{e}:
      False{}

def codec.event(e: Llm.Ev) -> Bool:
  match e:
    case Llm.EText{+s}:
      String.eq(s, "Hi")
    case other:
      False{}

def codec.error(r: Result<&1, &1, Llm.Err, Llm.Reply>) -> Bool:
  match r:
    case Fail{Llm.ErrReply{+s}}:
      String.eq(s, "<html>")
    case other:
      False{}

def codecs() -> IO(Unit):
  do IO<Unit>:
    pool.ok(codec.reply(Llm.reply(Llm.Anthropic{}, Bytes.from_string("{\"content\":[{\"type\":\"text\",\"text\":\"Hi\"}]}"))), "Anthropic runtime reply codec")
    pool.ok(codec.reply(Llm.reply(Llm.OpenAI{}, Bytes.from_string("{\"choices\":[{\"message\":{\"content\":\"Hi\"}}]}"))), "OpenAI runtime reply codec")
    pool.ok(codec.event(Llm.ev(Llm.Anthropic{}, Sse.Message{"content_block_delta", Bytes.from_string("{\"delta\":{\"text\":\"Hi\"}}"), ""})), "Anthropic runtime event codec")
    pool.ok(codec.event(Llm.ev(Llm.OpenAI{}, Sse.Message{"message", Bytes.from_string("{\"choices\":[{\"delta\":{\"content\":\"Hi\"}}]}"), ""})), "OpenAI runtime event codec")
    pool.ok(codec.error(Llm.reply(Llm.OpenAI{}, Bytes.from_string("<html>"))), "runtime codec error conversion")
    pool.ok(String.eq(Bytes.to_string(Json.encode.bytes(Llm.body(Llm.OpenAI{}, Llm.Req{"m", "s", [Llm.Msg{Llm.User{}, "hi"}, Llm.Msg{Llm.Assistant{}, "yo"}], 9}, True{}))),
      "{\"model\":\"m\",\"max_completion_tokens\":9,\"messages\":[{\"role\":\"system\",\"content\":\"s\"},{\"role\":\"user\",\"content\":\"hi\"},{\"role\":\"assistant\",\"content\":\"yo\"}],\"stream\":true}"), "runtime request codec")

def main() -> IO(Unit):
  do IO<Unit>:
    codecs()
    verdict("20000 events in 7-byte reads", chunks(many(20000), 7), 20000, 88890)
    verdict("20000 events in 65536-byte reads", chunks(many(20000), 65536), 20000, 88890)
    verdict("1 MiB data line in 65536-byte reads", chunks(big(1048576), 65536), 1, 1048576)
    overloaded()
    overloaded.stream()
    pooled.stream()
    refused.pool()
    refused.drop(False{})
    refused.drop(True{})
