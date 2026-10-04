# Observe HTTP progress beside serial pure work and an actual Wire read timeout.
import Base
import ./risk_probe.bend as Risk
import ../http/http.bend as Http
import ../http/context_probe.bend as Transport
import bend-kit-wire@0.4.2.0/wire.bend as Wire

type Context is Data:
  Context{mode: String, iterations: Nat, go: Chan(Unit)}

def work(mode: String, iterations: Nat) -> IO(Unit):
  match mode:
    case "yield":
      do IO<Unit>:
        IO.print("CPU_BEGIN")
        IO.sleep(500)
        IO.print("CPU_END yield")
    case _:
      do IO<Unit>:
        IO.print("CPU_BEGIN")
        seed : U32 <- IO.try(U32, IO.random_u32())
        IO.print("CPU_END " ++ U32.show(Risk.spin(iterations, seed)))

def run_work(context: Context) -> IO(Http.Res):
  Context{mode, iterations, go} = context
  do IO<Http.Res>:
    IO.print("CPU_ARMED")
    IO.join(Unit, go)
    work(mode, iterations)
    return Http.Res{200, Http.empty(), Http.from_string("cpu")}

def handler(context: Context, request: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = request
  match path:
    case "/cpu":
      run_work(context)
    case _:
      do IO<Http.Res>:
        IO.print("ORDINARY_HANDLED")
        return Http.Res{200, Http.empty(), Http.from_string("ok")}

def read_done(result: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  (socket, outcome) = result
  match outcome:
    case Fail{error}:
      (code, message) = error
      do IO<Unit>:
        IO.print("DEADLINE_READ_FAILED " ++ U32.show(code) ++ " " ++ message)
        Socket.close(socket)
        IO.print("DEADLINE_CLOSED")
    case Done{piece}:
      (len, words) = piece
      do IO<Unit>:
        IO.print("DEADLINE_READ_DONE " ++ U32.show(len))
        Socket.close(socket)
        IO.print("DEADLINE_CLOSED")

def partial_read(result: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  (socket, outcome) = result
  match outcome:
    case Fail{error}:
      do IO<Unit>:
        IO.print("PARTIAL_SETUP_FAILED")
        Socket.close(socket)
    case Done{piece}:
      (len, words) = piece
      do IO<Unit>:
        IO.print("PARTIAL_READ " ++ U32.show(len))
        IO.print("DEADLINE_ARMED")
        result : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(socket, 65536, 200)
        read_done(result)

def deadline(socket: Socket) -> IO(Unit):
  do IO<Unit>:
    first : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(socket, 65536, 5000)
    partial_read(first)

def accepted(result: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener & Chan(Unit)):
  (listener, outcome) = result
  do IO<Listener & Chan(Unit)>:
    socket : Socket <- IO.pass(Socket, outcome)
    done : Chan(Unit) <- IO.fork(Unit, deadline(socket))
    return (listener, done)

def start(mode: String, iterations: Nat, +go: Chan(Unit), setup: Listener & Chan(Unit)) -> IO(Unit):
  (listener, deadline_done) = setup
  do IO<Unit>:
    requests : List<Chan(Unit)> <- Transport.accept(~Context, ~handler, 2n, Context{mode, iterations, go}, 1024n, listener)
    IO.print("LOAD_ARMED")
    IO.sleep(50)
    released : Bool <- Chan.send(Unit, go, Unit{})
    Transport.join(requests)
    IO.join(Unit, deadline_done)
    IO.print("SERVER_DONE")

def serve(mode: String, iterations: Nat, port: U32) -> IO(Unit):
  do IO<Unit>:
    go0 : Chan(Unit) <- Chan.new(Unit, 1)
    +go : Chan(Unit) = go0
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("READY")
    first : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    setup : Listener & Chan(Unit) <- accepted(first)
    start(mode, iterations, go, setup)

def numbers(mode: String, count: Maybe<&2, Nat>, port: Maybe<&2, U32>) -> IO(Unit):
  match count port:
    case Some{n} Some{p}:
      serve(mode, n, p)
    case _ _:
      IO.die(Unit, 1, "invalid progress probe arguments")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> count <> port <> Nil{}:
      numbers(mode, Nat.read(count), U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: progress_probe <mode> <iterations> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
