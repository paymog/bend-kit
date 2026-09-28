import Base
import ./hairpin.bend as Hairpin
import bend-kit-http@0.23.0.0/http.bend as Http
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

# Each response closes its connection, so the server takes one accept per request, in this order.
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

def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- Http.conn(~s.login, 1048576n, a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- Http.conn(~s.echo, 1048576n, b)
    c : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l2)
    l3 : Listener <- Http.conn(~s.busy, 1048576n, c)
    d : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l3)
    l4 : Listener <- Http.conn(~s.again, 1048576n, d)
    e : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l4)
    l5 : Listener <- Http.conn(~s.post, 1048576n, e)
    f : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l5)
    l6 : Listener <- Http.conn(~s.login, 1048576n, f)
    Listener.close(l6)

def got(+name: String, +status: U32, +want: String, r: Hairpin.Client & Result<&1, &1, Http.Err, Http.Res>) -> IO(Hairpin.Client):
  (c, m) = r
  match m:
    case Fail{e}:
      IO.die(Hairpin.Client, 1, "FAIL " ++ name ++ ": request failed")
    case Done{res}:
      Http.Res{+s, headers, body} = res
      +seen = Bytes.to_string(body)
      do IO<Hairpin.Client>:
        ok(Bool.and(U32.is_eq(s, status), String.eq(seen, want)), name ++ " (" ++ U32.show(s) ++ " " ++ seen ++ ")")
        return c

def client(now: Time.Instant) -> Hairpin.Client:
  c0 = Hairpin.base(Hairpin.new(), "http://127.0.0.1:47830/api/")
  c1 = Hairpin.header(Hairpin.header(c0, "Accept", "text/plain"), "X-A", "default")
  Hairpin.jar(Hairpin.retry(c1, 2), Http.jar.new(now))

def main() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(47830))
    IO.spawn(Unit, serve(l))
    now : Time.Instant <- Time.now()
    r1 : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <-
      Hairpin.request(client(now), "GET", "login", Http.set(Http.empty(), "X-A", "mine"), Bytes.new(0))
    c1 : Hairpin.Client <- got("base, default and request headers, redirect, and jar", 200, "GET /api/echo text/plain mine sid=abc", r1)
    r2 : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- Hairpin.get(c1, "/api/flaky")
    c2 : Hairpin.Client <- got("503 then 200 on the retry, jar kept", 200, "retry sid=abc", r2)
    r3 : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- Hairpin.post.json(c2, "echo", Json.Flag{True{}})
    c3 : Hairpin.Client <- got("POST gets one try", 503, "POST application/json true", r3)
    r4 : Hairpin.Client & Result<&1, &1, Http.Err, Http.Res> <- Hairpin.get(Hairpin.redirect(c3, Http.ModeManual{}), "login")
    c4 : Hairpin.Client <- got("manual redirect mode returns the 302", 302, "", r4)
    Hairpin.close(c4)
