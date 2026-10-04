# Native/JS direct and finite live callers of the same public typed application.
import Base
import ./camber.bend as C
import ./input_app.bend as App
import ./input.bend as Input
import bend-kit-http@0.25.0.2/http.bend as H
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

# Published Http owns buffering, framing and response writing. This finite fixture
# uses its existing single-connection talk; it is not a production serving API.
# The old published template-only transport has no runtime application context,
# so this evidence caller constructs its prepared app per request; no perf claim.
def live.args(values: List<&1, String>, req: H.Req) -> IO(H.Res):
  match values:
    case program <> "live" <> port <> count <> depth <> journal <> Nil{}:
      do IO<H.Res>:
        cap : U32 <- integer(Input.u32(depth))
        dispatch(App.Config{journal, cap}, req)
    case _: IO.die(H.Res, 1, "live arguments")

def live.handler(req: H.Req) -> IO(H.Res):
  do IO<H.Res>:
    values : List<&1, String> <- IO.args()
    live.args(values, req)

def live.accepted(pair: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (listener, result) = pair
  do IO<Listener>:
    socket : Socket <- IO.pass(Socket, result)
    H.talk(~live.handler, 1048576n, (socket, H.TurnMore{H.sv.none(), False{}}))
    return listener

def live.connections(count: Nat, listener: Listener) -> IO(Unit):
  match count:
    case 0n: Listener.close(listener)
    case 1n+rest:
      do IO<Unit>:
        accepted : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
        listener : Listener <- live.accepted(accepted)
        live.connections(rest, listener)

def live(port: String, count: String) -> IO(Unit):
  do IO<Unit>:
    p : U32 <- integer(Input.u32(port))
    n : U32 <- integer(Input.u32(count))
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", p))
    IO.print("READY")
    live.connections(U32.to_nat(n), listener)
    IO.print("CLOSED")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> "direct" <> method <> target <> media <> encoding <> auth <> hex <> depth <> journal <> Nil{}:
      direct(method, target, media, encoding, auth, hex, depth, journal)
    case program <> "live" <> port <> count <> depth <> journal <> Nil{}:
      live(port, count)
    case _: IO.die(Unit, 1, "usage: input_check direct <method> <target> <media|-> <encoding|-> <auth|-> <hex> <depth> <journal>; or live <port> <count> <depth> <journal>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
