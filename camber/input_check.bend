# Native/JS direct and finite live callers of the same public typed application.
import Base
import ./camber.bend as C
import ./input_app.bend as App
import ./input.bend as Input
import bend-kit-http@0.32.0.0/http.bend as H
import bend-kit-http@0.32.0.0/completion.bend as T
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as B

def ready(result: Result<&2, &2, C.RegistrationError, C.Application<Unit, App.Config, C.Policy<Unit>>>) -> IO(C.Application<Unit, App.Config, C.Policy<Unit>>):
  match result:
    case Fail{error}: IO.die(C.Application<Unit, App.Config, C.Policy<Unit>>, 1, "registration failed")
    case Done{app}: IO.pure(C.Application<Unit, App.Config, C.Policy<Unit>>, app)

def response(completion: C.Completion<Unit, Unit>) -> H.Res:
  C.Completed{state, response, entered, mapped, stopped} = completion
  response

def dispatch(config: App.Config, req: H.Req) -> IO(H.Res):
  do IO<H.Res>:
    app : C.Application<Unit, App.Config, C.Policy<Unit>> <- ready(App.application(config))
    completion : C.Completion<Unit, Unit> <- App.dispatch(app, req)
    return response(completion)

def header(headers: Map<&2, List<&2, String>>, key: String, value: String) -> Map<&2, List<&2, String>>:
  match value:
    case "-": headers
    case _: H.set(headers, key, value)

def direct.body(body: Maybe<&1, B.Bytes>, method: String, target: String, headers: Map<&2, List<&2, String>>, depth: U32, journal: String) -> IO(Unit):
  match body:
    case None{}: IO.die(Unit, 1, "invalid fixture hex")
    case Some{body}:
      do IO<Unit>:
        res : H.Res <- dispatch(App.Config{journal, depth}, H.Req{method, target, headers, body})
        IO.print("RESPONSE " ++ B.to_hex(H.reply.bytes(res, False{}, True{})))

def integer(value: Maybe<&2, U32>) -> IO(U32):
  match value:
    case None{}: IO.die(U32, 1, "invalid fixture decimal")
    case Some{value}: IO.pure(U32, value)

def direct(method: String, target: String, media: String, encoding: String, auth: String, hex: String, depth: String, journal: String) -> IO(Unit):
  do IO<Unit>:
    cap : U32 <- integer(Input.u32(depth))
    direct.body(B.from_hex(hex), method, target, header(header(header(H.empty(), "content-type", media), "content-encoding", encoding), "authorization", auth), cap, journal)

# Finite evidence uses the same published server owner, not a socket loop.
type Live is Data:
  Live{config: App.Config, remaining: Chan(Nat), stop: Chan(H.ServerControl)}

def live.handler(context: Live, req: H.Req) -> IO(H.Reply):
  Live{config, remaining, stop} = context
  do IO<H.Reply>:
    res : H.Res <- dispatch(config, req)
    return H.Reply{res, T.Unobserved{}}

def live.remaining(count: Nat, +remaining: Chan(Nat), stop: Chan(H.ServerControl)) -> IO(Unit):
  match count:
    case 0n: IO.die(Unit, 1, "unexpected extra completion")
    case 1n+rest:
      match rest:
        case 0n:
          do IO<Unit>:
            control : H.ServerControl <- C.receive(H.ServerControl, stop)
            accepted : Bool <- H.server.stop(control)
            return Unit{}
        case 1n+tail:
          do IO<Unit>:
            sent : Result<&1, &1, Nat, Unit> <- Chan.send(Nat, remaining, 1n+tail)
            return Unit{}

def live.observe(context: Live, status: U32, outcome: T.Outcome) -> IO(Unit):
  Live{config, +remaining, stop} = context
  do IO<Unit>:
    count : Nat <- C.receive(Nat, remaining)
    live.remaining(count, remaining, stop)

def live.controlled(controlled: H.Server<Live> & H.ServerControl, context: Live) -> IO(Unit):
  (server, control) = controlled
  Live{config, remaining, +stop} = context
  do IO<Unit>:
    sent : Result<&1, &1, H.ServerControl, Unit> <- Chan.send(H.ServerControl, stop, control)
    IO.print("READY")
    exited : H.ServerExit <- H.server.run(~Live, ~live.handler, ~live.observe, server)
    Chan.close(Nat, remaining)
    Chan.close(H.ServerControl, stop)
    IO.print("CLOSED")

def live.started(started: Unit & Result<&2, &1, H.StartupError, H.Server<Live>>, context: Live) -> IO(Unit):
  (owner, result) = started
  match result:
    case Fail{error}:
      Live{config, remaining, stop} = context
      do IO<Unit>:
        Chan.close(Nat, remaining)
        Chan.close(H.ServerControl, stop)
        IO.die(Unit, 1, "live bind failed")
    case Done{server}: live.controlled(H.server.control(~Live, server), context)

def live(port: String, count: String, depth: String, journal: String) -> IO(Unit):
  do IO<Unit>:
    p : U32 <- integer(Input.u32(port))
    n : U32 <- integer(Input.u32(count))
    cap : U32 <- integer(Input.u32(depth))
    +remaining : Chan(Nat) <- Chan.new(Nat, 1)
    stop : Chan(H.ServerControl) <- Chan.new(H.ServerControl, 1)
    sent : Result<&1, &1, Nat, Unit> <- Chan.send(Nat, remaining, U32.to_nat(n))
    +context : Live = Live{App.Config{journal, cap}, remaining, stop}
    started : Unit & Result<&2, &1, H.StartupError, H.Server<Live>> <-
      H.server.start(~Live, ~Unit, context, Unit{}, C.server.config(p))
    live.started(started, context)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> "direct" <> method <> target <> media <> encoding <> auth <> hex <> depth <> journal <> Nil{}:
      direct(method, target, media, encoding, auth, hex, depth, journal)
    case program <> "live" <> port <> count <> depth <> journal <> Nil{}:
      live(port, count, depth, journal)
    case _: IO.die(Unit, 1, "usage: input_check direct <method> <target> <media|-> <encoding|-> <auth|-> <hex> <depth> <journal>; or live <port> <count> <depth> <journal>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
