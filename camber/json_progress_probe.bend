# Observe HTTP progress while existing JSON parsing or name validation consumes a real body.
import Base
import ./progress_probe.bend as Progress
import ./ownership.bend as Users
import ../json/json.bend as Json
import ../http/http.bend as Http
import ../http/context_probe.bend as Transport
import bend-kit-wire@0.4.2.0/wire.bend as Wire
import bend-kit-time@0.1.0.0/time.bend as Time
import ./prerequisites.bend as Probe

type Context is Data:
  Context{mode: String, go: Chan(Unit)}

def complete(response: Http.Res, started: Time.Duration) -> IO(Http.Res):
  do IO<Http.Res>:
    finished : Time.Duration <- Time.mono()
    Probe.elapsed("WORK_TIME", Time.Duration.sub(finished, started))
    IO.print("CPU_END")
    return response

def result(valid: Bool, started: Time.Duration) -> IO(Http.Res):
  match valid:
    case True{}:
      complete(Http.Res{200, Http.empty(), Http.from_string("cpu")}, started)
    case False{}:
      complete(Http.Res{400, Http.empty(), Http.from_string("rejected")}, started)

def named(value: Maybe<&2, String>, started: Time.Duration) -> IO(Http.Res):
  match value:
    case None{}:
      result(False{}, started)
    case Some{name}:
      result(True{}, started)

def parsed(value: Maybe<&1, Json.Val>, started: Time.Duration) -> IO(Http.Res):
  match value:
    case None{}:
      result(False{}, started)
    case Some{document}:
      result(True{}, started)

def work(mode: String, body: Http.Body, started: Time.Duration) -> IO(Http.Res):
  match mode:
    case "name":
      named(Users.name(body), started)
    case "json":
      parsed(Json.parse.bytes(body), started)
    case _:
      IO.die(Http.Res, 1, "invalid JSON progress mode")

def run_work(context: Context, body: Http.Body) -> IO(Http.Res):
  Context{mode, go} = context
  do IO<Http.Res>:
    bodies0 : Chan(Http.Body) <- Chan.new(Http.Body, 1)
    +bodies : Chan(Http.Body) = bodies0
    queued : Bool <- Chan.send(Http.Body, bodies, body)
    IO.print("CPU_ARMED")
    IO.join(Unit, go)
    # Receive the affine body after the marker; decoder work must not run while building the earlier IO action.
    IO.print("CPU_BEGIN")
    # Native stdout flushes when the loop waits; this pre-work pause makes the marker visible before parsing.
    IO.sleep(1)
    started : Time.Duration <- Time.mono()
    received : Http.Body <- IO.join(Http.Body, bodies)
    work(mode, received, started)

def handler(context: Context, request: Http.Req) -> IO(Http.Res):
  Http.Req{method, path, headers, body} = request
  match path:
    case "/cpu":
      run_work(context, body)
    case _:
      do IO<Http.Res>:
        IO.print("ORDINARY_HANDLED")
        return Http.Res{200, Http.empty(), Http.from_string("ok")}

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
    timer_ready : Bool <- Chan.send(Unit, timer, Unit{})
    IO.sleep(50)
    released : Bool <- Chan.send(Unit, go, Unit{})
    Transport.join(requests)
    IO.join(Unit, deadline_done)
    IO.print("SERVER_DONE")

def serve(mode: String, port: U32) -> IO(Unit):
  do IO<Unit>:
    go0 : Chan(Unit) <- Chan.new(Unit, 1)
    timer0 : Chan(Unit) <- Chan.new(Unit, 1)
    +go : Chan(Unit) = go0
    +timer : Chan(Unit) = timer0
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("READY")
    first : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    setup : Listener & Chan(Unit) <- accepted(first, timer)
    start(mode, go, timer, setup)

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
