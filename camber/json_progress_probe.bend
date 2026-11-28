# Observe HTTP progress while existing JSON parsing or name validation consumes a real body.
import Base
import ./progress_probe.bend as Progress
import ./ownership.bend as Users
import bend-kit-json@0.7.3.2/json.bend as Json
import ../http/http.bend as Http
import ../http/pure.bend as Pure
import ../http/context_probe.bend as Transport
import bend-kit-wire@0.4.9.0/wire.bend as Wire
import bend-kit-time@0.3.0.5/time.bend as Time
import ./prerequisites.bend as Probe
import ./probe_stdout.bend as Stdout

type Context is Data:
  Context{mode: String, go: Chan(Unit)}

def complete(response: Pure.Res, started: Time.Duration) -> IO(Pure.Res):
  do IO<Pure.Res>:
    finished : Time.Duration <- Time.mono()
    Probe.elapsed("WORK_TIME", Time.Duration.sub(finished, started))
    IO.print("CPU_END")
    return response

def result(valid: Bool, started: Time.Duration) -> IO(Pure.Res):
  match valid:
    case True{}:
      complete(Pure.Res{200, Pure.empty(), Pure.from_string("cpu")}, started)
    case False{}:
      complete(Pure.Res{400, Pure.empty(), Pure.from_string("rejected")}, started)

def named(value: Maybe<&2, String>, started: Time.Duration) -> IO(Pure.Res):
  match value:
    case None{}:
      result(False{}, started)
    case Some{name}:
      result(True{}, started)

def parsed(value: Maybe<&1, Json.Val>, started: Time.Duration) -> IO(Pure.Res):
  match value:
    case None{}:
      result(False{}, started)
    case Some{document}:
      result(True{}, started)

def work(mode: String, body: Pure.Body, started: Time.Duration) -> IO(Pure.Res):
  match mode:
    case "name":
      named(Users.name(body), started)
    case "json":
      parsed(Json.parse.bytes(body), started)
    case _:
      IO.die(Pure.Res, 1, "invalid JSON progress mode")

def run_work(context: Context, body: Pure.Body) -> IO(Pure.Res):
  Context{mode, go} = context
  do IO<Pure.Res>:
    bodies0 : Chan(Pure.Body) <- Chan.new(Pure.Body, 1)
    +bodies : Chan(Pure.Body) = bodies0
    queued : Result<&1, &1, Pure.Body, Unit> <- Chan.send(Pure.Body, bodies, body)
    IO.print("CPU_ARMED")
    IO.join(Unit, go)
    # Receive the affine body after the marker; decoder work must not run while building the earlier IO action.
    IO.print("CPU_BEGIN")
    Stdout.flush()
    started : Time.Duration <- Time.mono()
    received : Pure.Body <- IO.join(Pure.Body, bodies)
    work(mode, received, started)

def handler(context: Context, request: Pure.Req) -> IO(Pure.Res):
  Pure.Req{method, path, headers, body} = request
  match path:
    case "/cpu":
      run_work(context, body)
    case _:
      do IO<Pure.Res>:
        IO.print("ORDINARY_HANDLED")
        return Pure.Res{200, Pure.empty(), Pure.from_string("ok")}

def partial_ready(result: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>, go: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    IO.print("PARTIAL_READY")
    IO.join(Unit, go)
    Progress.partial_read(result)

def deadline(socket: Socket, go: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    first : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(socket, 65536, 5000)
    partial_ready(first, go)

def accepted(result: Listener & Result<&1, &1, U32 & String, Socket>, go: Chan(Unit)) -> IO(Listener & Chan(Unit)):
  (listener, outcome) = result
  do IO<Listener & Chan(Unit)>:
    socket : Socket <- IO.pass(Socket, outcome)
    done : Chan(Unit) <- IO.fork(Unit, deadline(socket, go))
    return (listener, done)

def start(mode: String, +go: Chan(Unit), timer: Chan(Unit), setup: Listener & Chan(Unit)) -> IO(Unit):
  (listener, deadline_done) = setup
  do IO<Unit>:
    requests : List<Chan(Unit)> <- Transport.accept(~Context, ~handler, 2n, Context{mode, go}, 1048576n, listener)
    IO.print("LOAD_ARMED")
    timer_ready : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, timer, Unit{})
    IO.sleep(50)
    released : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, go, Unit{})
    Transport.join(requests)
    IO.join(Unit, deadline_done)
    IO.print("SERVER_DONE")

def listening(bound: Listener & U32, mode: String, go: Chan(Unit), +timer: Chan(Unit)) -> IO(Unit):
  (listener, port) = bound
  do IO<Unit>:
    IO.print("READY " ++ U32.show(port))
    first : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    setup : Listener & Chan(Unit) <- accepted(first, timer)
    start(mode, go, timer, setup)

def serve(mode: String, port: U32) -> IO(Unit):
  do IO<Unit>:
    go0 : Chan(Unit) <- Chan.new(Unit, 1)
    timer0 : Chan(Unit) <- Chan.new(Unit, 1)
    +go : Chan(Unit) = go0
    +timer : Chan(Unit) = timer0
    bound : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", port))
    listening(bound, mode, go, timer)

def numbers(mode: String, port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case Some{p}:
      serve(mode, p)
    case _:
      IO.die(Unit, 1, "invalid JSON progress port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> port <> Nil{}:
      numbers(mode, U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: json_progress_probe <name|json> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
