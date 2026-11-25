# Live caller: only validated Done reaches the shared Http write boundary.
import Base
import ./camber.bend as C
import ./dispatch_check.bend as Check
import bend-kit-http@0.44.0.1/http.bend as H
import bend-kit-http@0.44.0.1/pure.bend as Pure
import bend-kit-http@0.44.0.1/completion.bend as T
import bend-kit-wire@0.4.8.1/wire.bend as Wire

type Case is Data:
  Case{status: U32, name: String, value: String}

def cases() -> List<&2, Case>:
  [Case{199, "x", "ok"}, Case{600, "x", "ok"},
   Case{200, "content-length", "6"}, Case{200, "transfer-encoding", "chunked"},
   Case{200, "keep-alive", "close"}, Case{200, "upgrade", "websocket"},
   Case{200, "te", "trailers"}, Case{200, "trailer", "x"}, Case{200, "proxy-connection", "close"},
   Case{200, "connection", "keep-alive"}, Case{200, "connection", "close, upgrade"},
   Case{200, "X", "ok"}, Case{200, "", "ok"}, Case{200, "bad name", "ok"}, Case{200, "bad:name", "ok"},
   Case{200, "x", "a\r"}, Case{200, "x", "a\n"}, Case{200, "x", "\0"},
   Case{200, "x", "\u{1}"}, Case{200, "x", "\u{7F}"}, Case{200, "x", "\u{100}"}]

def plain(req: Pure.Req) -> IO(Pure.Res):
  Pure.Req{method, path, +headers, body} = req
  +status = Pure.header(headers, "x-status")
  IO.pure(Pure.Res, Pure.Res{Bool.pick(U32, String.eq(status, "199"), 199, Bool.pick(U32, String.eq(status, "600"), 600, 200)), headers, body})

def run(action: U32, state: Unit, context: Unit, matched: C.Match<C.Policy<Unit>>, req: Pure.Req) -> IO(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>):
  do IO<Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>>:
    response : Pure.Res <- plain(req)
    return (state, Done{response})

def before(hook: Unit, state: Unit, context: Unit, meta: C.Metadata) -> IO(C.Step<Unit, Unit>):
  IO.pure(C.Step<Unit, Unit>, C.Continue{state})

def after(hook: Unit, state: Unit, context: Unit, response: Pure.Res) -> IO(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>):
  IO.pure(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>, (state, Done{response}))


def sent(value: (Socket & Pure.Turn) & T.Outcome) -> IO(Unit):
  ((socket, turn), outcome) = value
  Socket.close(socket)

def output(result: Result<&2, &1, C.ResponseError, Pure.Res>, socket: Socket) -> IO(Unit):
  match result:
    case Fail{C.InvalidResponse{}}:
      do IO<Unit>:
        Socket.close(socket)
        IO.print("EXPECTED InvalidResponse NO WRITE")
    case Fail{error}:
      IO.die(Unit, 1, "unexpected response failure")
    case Done{res}:
      do IO<Unit>:
        value : (Socket & Pure.Turn) & T.Outcome <- H.talk.send(Pure.Limits{1024n, 65536, 5000, 30000, 30000, 30000}, socket, Pure.from_string(""), Pure.empty(), True{}, False{}, res)
        sent(value)

def accepted.result(result: Result<&1, &1, U32 & String, Socket>, listener: Listener) -> IO(Listener & Socket):
  match result:
    case Fail{error}: IO.die(Listener & Socket, 1, "accept failed")
    case Done{socket}: IO.pure(Listener & Socket, (listener, socket))

def accepted(value: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener & Socket):
  (listener, result) = value
  accepted.result(result, listener)


def ready(result: Result<&2, &2, C.RegistrationError, C.Application<U32, Unit, C.Policy<Unit>>>) -> IO(C.Application<U32, Unit, C.Policy<Unit>>):
  match result:
    case Fail{error}: IO.die(C.Application<U32, Unit, C.Policy<Unit>>, 1, "registration")
    case Done{app}: IO.pure(C.Application<U32, Unit, C.Policy<Unit>>, app)
def recovered(completion: C.Completion<Unit, Unit>, socket: Socket) -> IO(Unit):
  C.Completed{state, Pure.Res{+status, +headers, body}, entered, mapped, stopped} = completion
  do IO<Unit>:
    Check.require(U32.is_eq(status, 500) && mapped && stopped, "invalid routed output not recovered")
    value : (Socket & Pure.Turn) & T.Outcome <- H.talk.send(Pure.Limits{1024n, 65536, 5000, 30000, 30000, 30000}, socket, Pure.from_string(""), Pure.empty(), True{}, False{}, Pure.Res{status, headers, body})
    sent(value)
    IO.print("EXPECTED SAFE MAPPED500 WRITE")

def safety(routed: Bool, app: C.Application<U32, Unit, C.Policy<Unit>>, req: Pure.Req, socket: Socket) -> IO(Unit):
  match routed:
    case False{}:
      do IO<Unit>:
        response : Result<&2, &1, C.ResponseError, Pure.Res> <- C.plain(~plain, req)
        output(response, socket)
    case True{}:
      do IO<Unit>:
        completion : C.Completion<Unit, Unit> <- C.dispatch(~U32, ~Unit, ~Unit, ~Unit, ~Unit, ~Unit, ~before, ~after, ~run, ~C.default.mapper(~Unit, ~Unit, ~Unit), ~C.notice.ignore(~Unit, ~Unit, ~Unit), ~C.notice.error.ignore(~Unit, ~Unit), Unit{}, C.access.disabled(~Unit, Unit{}), app, Unit{}, req)
        recovered(completion, socket)


def invalid.accepted(pair: Listener & Socket, status: U32, name: String, value: String, app: C.Application<U32, Unit, C.Policy<Unit>>, routed: Bool, next_case: Listener -> IO(Listener)) -> IO(Listener):
  (next, socket) = pair
  do IO<Listener>:
    safety(routed, app, Pure.Req{"GET", "/", Pure.set(Pure.set(Pure.empty(), name, value), "x-status", U32.show(status)), Pure.from_string("private")}, socket)
    next_case(next)

def invalid(xs: List<&2, Case>, listener: Listener, +app: C.Application<U32, Unit, C.Policy<Unit>>, +routed: Bool) -> IO(Listener):
  match xs:
    case Nil{}:
      IO.pure(Listener, listener)
    case Case{+status, +name, +value} <> rest:
      do IO<Listener>:
        a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
        pair : Listener & Socket <- accepted(a)
        invalid.accepted(pair, status, name, value, app, routed, next => invalid(rest, next, app, routed))


def finish(pair: Listener & Socket) -> IO(Unit):
  (last, socket) = pair
  do IO<Unit>:
    output(C.validate(Pure.Res{200, Pure.add(Pure.set(Pure.empty(), "set-cookie", "a=1"), "set-cookie", "b=2"), Pure.from_string("ok")}), socket)
    Listener.close(last)
    IO.print("live response safety: PASS")

def serve(bound: Listener & U32) -> IO(Unit):
  (listener, port) = bound
  do IO<Unit>:
    +app : C.Application<U32, Unit, C.Policy<Unit>> <- ready(C.application(~U32, ~Unit, ~C.Policy<Unit>, [C.Route{"GET", "/", 0, [], C.policy(~Unit, 1, Nil{}, Nil{})}], [], Unit{}, C.policy(~Unit, 0, Nil{}, Nil{})))
    IO.print("READY " ++ U32.show(port))
    plain_done : Listener <- invalid(cases(), listener, app, False{})
    next : Listener <- invalid(cases(), plain_done, app, True{})
    a : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(next)
    pair : Listener & Socket <- accepted(a)
    finish(pair)

def main() -> IO(Unit):
  do IO<Unit>:
    bound : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    serve(bound)
