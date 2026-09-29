# Send a signed event through Hairpin; the local HTTP server verifies both the 501 and its retry.
import Base
import ./webhooks.bend as Webhooks
import bend-kit-hairpin@0.1.0.0/hairpin.bend as Hairpin
import bend-kit-http@0.23.0.1/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# The official Standard Webhooks test key, not a production secret.
def secret() -> String:
  "whsec_MfKQ9r8GKYqrTwjUPD8ILPZIo2LaLaSw"

def respond(status: U32) -> IO(Http.Res):
  IO.pure(Http.Res, Http.Res{status, Http.set(Http.set(Http.empty(), "connection", "close"), "retry-after", "0"), Bytes.new(0)})

def verified.id(status: U32, ok: Bool) -> IO(Http.Res):
  match ok:
    case False{}:
      IO.die(Http.Res, 1, "event ID changed")
    case True{}:
      respond(status)

def verified(status: U32, r: Bytes.Bytes & Result<&1, &1, Webhooks.Err, String>) -> IO(Http.Res):
  (body, result) = r
  match result:
    case Fail{e}:
      IO.die(Http.Res, 1, "webhook signature rejected")
    case Done{id}:
      verified.id(status, String.eq(id, "msg_local_1"))

def handle(status: U32, req: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, +headers, body} = req
  do IO<Http.Res>:
    now : Time.Instant <- Time.now()
    r : Bytes.Bytes & Result<&1, &1, Webhooks.Err, String> <- Webhooks.verify([secret()], now, headers, body)
    verified(status, r)

def busy(req: Http.Req) -> IO(Http.Res):
  handle(501, req)

def accepted(req: Http.Req) -> IO(Http.Res):
  handle(200, req)

def serve(l: Listener) -> IO(Unit):
  do IO<Unit>:
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l1 : Listener <- Http.conn(~busy, 1048576n, a)
    b : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l1)
    l2 : Listener <- Http.conn(~accepted, 1048576n, b)
    Listener.close(l2)

def done.status(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok signed delivery retried and verified")
    case False{}:
      IO.die(Unit, 1, "wrong delivery status")

def done.result(result: Result<&1, &1, Webhooks.SendErr, Http.Res>) -> IO(Unit):
  match result:
    case Fail{e}:
      IO.die(Unit, 1, "webhook delivery failed")
    case Done{res}:
      Http.Res{+status, headers, body} = res
      done.status(U32.is_eq(status, 200))

def done(r: Hairpin.Client & Result<&1, &1, Webhooks.SendErr, Http.Res>) -> IO(Unit):
  (c, result) = r
  do IO<Unit>:
    Hairpin.close(c)
    done.result(result)

def main() -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", 47852))
    IO.spawn(Unit, serve(l))
    sent : Hairpin.Client & Result<&1, &1, Webhooks.SendErr, Http.Res> <-
      Webhooks.send(Hairpin.new(), "http://127.0.0.1:47852/webhook", "msg_local_1", secret(), Bytes.from_string("{\"test\": 2432232314}"))
    done(sent)
