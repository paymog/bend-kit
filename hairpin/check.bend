import Base
import ./hairpin.bend as Hairpin
import ./retry.bend as Retry
import bend-kit-http@0.23.0.1/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def ok(b: Bool, +name: String) -> IO(Unit):
  match b:
    case True{}:
      IO.print("ok   " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def closing(+status: U32, h: Map<&2, List<&2, String>>, body: String) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{status, Http.set(h, "connection", "close"), Bytes.from_string(body)})

def echo(req: Http.Req) -> String:
  Http.Req{method, path, +headers, body} = req
  method ++ " " ++ path ++ " " ++ Http.header(headers, "accept") ++ " " ++ Http.header(headers, "x-a") ++ " " ++ Http.header(headers, "cookie")

# Every response closes its connection, so each attempt is one accept.
def s.login(req: Http.Req) -> IO(Http.Res):
  closing(302, Http.set(Http.set(Http.empty(), "location", "/api/echo"), "set-cookie", "sid=abc; Path=/"), "")

def s.echo(req: Http.Req) -> IO(Http.Res):
  closing(200, Http.empty(), echo(req))

def s.busy(req: Http.Req) -> IO(Http.Res):
  closing(503, Http.set(Http.empty(), "retry-after", "0"), "busy")

def s.again(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, +headers, body} = req
  closing(200, Http.empty(), "retry " ++ Http.header(headers, "cookie"))

def s.post(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, +headers, body} = req
  closing(503, Http.set(Http.empty(), "retry-after", "0"), method ++ " " ++ Http.header(headers, "content-type") ++ " " ++ Bytes.to_string(body))

def s.slow(req: Http.Req) -> IO(Http.Res):
  closing(503, Http.set(Http.empty(), "retry-after", "1"), "slow")

def s.fine(req: Http.Req) -> IO(Http.Res):
  closing(200, Http.empty(), "fine")

def s.missing(req: Http.Req) -> IO(Http.Res):
  closing(404, Http.empty(), "missing")

def serve.one(+k: U32, a: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  match k:
    case 0:
      Http.conn(~s.login, 1048576n, a)
    case 1:
      Http.conn(~s.echo, 1048576n, a)
    case 2:
      Http.conn(~s.busy, 1048576n, a)
    case 3:
      Http.conn(~s.again, 1048576n, a)
    case 4:
      Http.conn(~s.post, 1048576n, a)
    case 5:
      Http.conn(~s.slow, 1048576n, a)
    case 6:
      Http.conn(~s.fine, 1048576n, a)
    case _:
      Http.conn(~s.missing, 1048576n, a)

# Accept exactly one connection per script entry, then stop listening.
def serve(ks: List<&2, U32>, l: Listener) -> IO(Unit):
  match ks:
    case Nil{}:
      Listener.close(l)
    case Con{+k, rest}:
      do IO<Unit>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
        l2 : Listener <- serve.one(k, a)
        serve(rest, l2)

def login() -> U32:
  0

def echoed() -> U32:
  1

def busy() -> U32:
  2

def again() -> U32:
  3

def post() -> U32:
  4

def slow() -> U32:
  5

def fine() -> U32:
  6

def missing() -> U32:
  7

def server(+port: U32, ks: List<&2, U32>) -> IO(Chan(Unit)):
  do IO<Chan(Unit)>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.fork(Unit, serve(ks, l))

def served.of(+name: String, m: Maybe<&1, Unit>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": the server still waits for an attempt")
    case Some{u}:
      IO.print("ok   " ++ name ++ ": every scripted attempt arrived, and no more")

# The server took exactly its script: a missing attempt times out here, and an extra one finds no listener.
def served(+name: String, ch: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    m : Maybe<&1, Unit> <- IO.within(Unit, 3000, IO.join(Unit, ch))
    served.of(name, m)

def res.ok(+name: String, +status: U32, +want: String, m: Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Unit):
  match m:
    case Fail{e}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": request failed")
    case Done{res}:
      Http.Res{+s, headers, body} = res
      +seen = Bytes.to_string(body)
      ok(Bool.and(U32.is_eq(s, status), String.eq(seen, want)), name ++ " (" ++ U32.show(s) ++ " " ++ seen ++ ")")

def deny.code(d: Retry.Deny) -> U32:
  match d:
    case Retry.DenyLate{}:
      0
    case Retry.DenySpent{}:
      1
    case Retry.DenyOpen{}:
      2

def res.denied(+name: String, +want: U32, m: Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Unit):
  match m:
    case Fail{Hairpin.ErrDenied{why}}:
      ok(U32.is_eq(deny.code(why), want), name)
    case Fail{Hairpin.ErrHttp{e}}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": an attempt started and failed")
    case Done{res}:
      IO.die(Unit, 1, "FAIL " ++ name ++ ": an attempt started")

def got(+name: String, +status: U32, +want: String, r: Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Hairpin.Client):
  (c, m) = r
  do IO<Hairpin.Client>:
    res.ok(name, status, want, m)
    return c

def denied(+name: String, +want: U32, r: Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res>) -> IO(Hairpin.Client):
  (c, m) = r
  do IO<Hairpin.Client>:
    res.denied(name, want, m)
    return c

def got.in(+name: String, +status: U32, +want: String, r: Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res>) ->
    IO(Hairpin.Client & Retry.Budget):
  (c, b, m) = r
  do IO<Hairpin.Client & Retry.Budget>:
    res.ok(name, status, want, m)
    return (c, b)

def denied.in(+name: String, +want: U32, r: Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res>) ->
    IO(Hairpin.Client & Retry.Budget):
  (c, b, m) = r
  do IO<Hairpin.Client & Retry.Budget>:
    res.denied(name, want, m)
    return (c, b)

def at(+port: U32) -> Hairpin.Client:
  Hairpin.base(Hairpin.new(), "http://127.0.0.1:" ++ U32.show(port) ++ "/api/")

def client(now: Time.Instant) -> Hairpin.Client:
  c0 = at(47830)
  c1 = Hairpin.header(Hairpin.header(c0, "Accept", "text/plain"), "X-A", "default")
  Hairpin.jar(Hairpin.retry(c1, 2), Http.jar.new(now))

# A redirect that sets a cookie, a 503 retried to a 200, a POST tried once, and a 302 in manual mode.
def basics() -> IO(Unit):
  do IO<Unit>:
    ch : Chan(Unit) <- server(47830, [login(), echoed(), busy(), again(), post(), login()])
    now : Time.Instant <- Time.now()
    r1 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <-
      Hairpin.request(client(now), "GET", "login", Http.set(Http.empty(), "X-A", "mine"), Bytes.new(0))
    c1 : Hairpin.Client <- got("base, default and request headers, redirect, and jar", 200, "GET /api/echo text/plain mine sid=abc", r1)
    r2 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c1, "/api/flaky")
    c2 : Hairpin.Client <- got("503 then 200 on the retry, jar kept", 200, "retry sid=abc", r2)
    r3 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.post.json(c2, "echo", Json.Flag{True{}})
    c3 : Hairpin.Client <- got("a POST 503 is Unsafe: one try", 503, "POST application/json true", r3)
    r4 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(Hairpin.redirect(c3, Http.ModeManual{}), "login")
    c4 : Hairpin.Client <- got("manual redirect mode returns the 302", 302, "", r4)
    Hairpin.close(c4)
    served("basics: 6 attempts", ch)

# retry 2 is 3 attempts in all; a 404 is settled after one.
def counts() -> IO(Unit):
  do IO<Unit>:
    ch : Chan(Unit) <- server(47831, [busy(), busy(), busy(), missing()])
    r1 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(Hairpin.retry(at(47831), 2), "x")
    c1 : Hairpin.Client <- got("retry 2 on a 503 ends with the third 503", 503, "busy", r1)
    r2 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c1, "x")
    c2 : Hairpin.Client <- got("a 404 is settled: one attempt", 404, "missing", r2)
    Hairpin.close(c2)
    served("counts: 3 + 1 attempts", ch)

def took.ms(+ms: Nat) -> IO(Unit):
  ok(Bool.and(Nat.is_le(1000n, ms), Nat.is_lt(ms, 1500n)), "the deadline run took " ++ Nat.show(ms) ++ " ms: one 1000 ms wait, under 1500")

def took(t0: Nat, t1: Nat) -> IO(Unit):
  took.ms((t1 - t0 : Nat))

# Retry-After: 1 with a 1500 ms deadline: the second wait would reach the deadline, so 2 attempts of 6.
# A 0 ms deadline admits no attempt at all.
def deadlines() -> IO(Unit):
  do IO<Unit>:
    ch : Chan(Unit) <- server(47832, [slow(), slow()])
    t0 : Nat <- Hairpin.now.ms()
    r1 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(Hairpin.deadline(Hairpin.retry(at(47832), 5), 1500), "x")
    t1 : Nat <- Hairpin.now.ms()
    c1 : Hairpin.Client <- got("the deadline stops the retries after 2 attempts", 503, "slow", r1)
    took(t0, t1)
    r2 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(Hairpin.deadline(c1, 0), "x")
    c2 : Hairpin.Client <- denied("a past deadline denies the first attempt", 0, r2)
    Hairpin.close(c2)
    served("deadlines: 2 attempts", ch)

# Two failures open the breaker; it denies until the 300 ms cooldown ends, then one probe closes it again.
def breaker() -> IO(Unit):
  do IO<Unit>:
    ch : Chan(Unit) <- server(47833, [busy(), busy(), fine(), fine()])
    c0 : Hairpin.Client = Hairpin.circuit(at(47833), Retry.Circuit{2n, 10000n, 300n, 1n})
    r1 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c0, "x")
    c1 : Hairpin.Client <- got("breaker: first failure", 503, "busy", r1)
    r2 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c1, "x")
    c2 : Hairpin.Client <- got("breaker: second failure opens it", 503, "busy", r2)
    r3 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c2, "x")
    c3 : Hairpin.Client <- denied("breaker: open, no attempt", 2, r3)
    IO.sleep(400)
    r4 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c3, "x")
    c4 : Hairpin.Client <- got("breaker: the probe after cooldown succeeds", 200, "fine", r4)
    r5 : Hairpin.Client & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.get(c4, "x")
    c5 : Hairpin.Client <- got("breaker: closed again", 200, "fine", r5)
    Hairpin.close(c5)
    served("breaker: 4 attempts", ch)

def nested.c(x: Hairpin.Client & Retry.Budget) -> Hairpin.Client:
  (c, b) = x
  c

def nested.b(x: Hairpin.Client & Retry.Budget) -> Retry.Budget:
  (c, b) = x
  b

def nested.call(x: Hairpin.Client & Retry.Budget) -> IO(Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res>):
  (c, b) = x
  Hairpin.request.in(c, b, "GET", "x", Http.empty(), Bytes.new(0))

# An outer layer makes 3 calls, each allowed 3 attempts by the client, on one budget of 4:
# 3 attempts, then 1, then none. Without the shared budget it would be 9.
def nested() -> IO(Unit):
  do IO<Unit>:
    ch : Chan(Unit) <- server(47834, [busy(), busy(), busy(), busy()])
    now : Nat <- Hairpin.now.ms()
    b0 : Retry.Budget = Retry.Budget.new(4n, now, None{})
    r1 : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res> <- Hairpin.request.in(Hairpin.retry(at(47834), 2), b0, "GET", "x", Http.empty(), Bytes.new(0))
    x1 : Hairpin.Client & Retry.Budget <- got.in("nested: the first call takes 3", 503, "busy", r1)
    r2 : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res> <- nested.call(x1)
    x2 : Hairpin.Client & Retry.Budget <- got.in("nested: the second call gets the 1 left", 503, "busy", r2)
    r3 : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res> <- nested.call(x2)
    x3 : Hairpin.Client & Retry.Budget <- denied.in("nested: the third call is denied, the budget is spent", 1, r3)
    Hairpin.close(nested.c(x3))
    served("nested: 4 attempts on a budget of 4", ch)

# Any status but 200 may clear, after Retry-After: 0.
def judge.all(r: Result<&1, &1, Http.Err, Http.Res>) -> Result<&1, &1, Http.Err, Http.Res> & Maybe<&2, String>:
  match r:
    case Fail{e}:
      (Fail{e}, Some{"0"})
    case Done{res}:
      Http.Res{+s, h, b} = res
      (Done{Http.Res{s, h, b}}, Bool.pick(Maybe<&2, String>, U32.is_eq(s, 200), None{}, Some{"0"}))

# A caller's judge retries a 404, and a POST it calls idempotent repeats: 3 attempts.
def judged() -> IO(Unit):
  do IO<Unit>:
    ch : Chan(Unit) <- server(47835, [missing(), missing(), fine()])
    b0 : Retry.Budget = Retry.Budget.new(3n, 0n, None{})
    r1 : Hairpin.Client & Retry.Budget & Result<&1, &1, Hairpin.Err, Http.Res> <-
      Hairpin.request.as(~judge.all, Hairpin.retry(at(47835), 2), b0, True{}, "identity", "POST", "x", Http.empty(), Bytes.from_string("{}"))
    x1 : Hairpin.Client & Retry.Budget <- got.in("request.as: the caller's judge retries an idempotent POST", 200, "fine", r1)
    Hairpin.close(nested.c(x1))
    served("judged: 3 attempts", ch)

def main() -> IO(Unit):
  do IO<Unit>:
    basics()
    counts()
    deadlines()
    breaker()
    nested()
    judged()
