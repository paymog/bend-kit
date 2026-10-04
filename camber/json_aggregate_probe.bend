# Observe bounded JSON batches beside ordinary HTTP and a real timed socket read.
import Base
import ./json_progress_probe.bend as JsonProgress
import ./interface_check.bend as Registry
import ../http/http.bend as Http
import ../http/context_probe.bend as Transport
import bend-kit-time@0.1.0.0/time.bend as Time

type Context is Data:
  Context{mode: String, ready: Chan(Unit), go: Chan(Unit)}

def work(mode: String, body: Http.Body, started: Time.Duration) -> IO(Http.Res):
  match mode:
    case "yield":
      do IO<Http.Res>:
        IO.sleep(500)
        JsonProgress.result(True{}, started)
    case _:
      JsonProgress.work("json", body, started)

def run_work(context: Context, body: Http.Body) -> IO(Http.Res):
  Context{mode, ready, go} = context
  do IO<Http.Res>:
    bodies0 : Chan(Http.Body) <- Chan.new(Http.Body, 1)
    +bodies : Chan(Http.Body) = bodies0
    queued : Bool <- Chan.send(Http.Body, bodies, body)
    Registry.require(queued, "body queue closed")
    IO.print("CPU_ARMED")
    armed : Bool <- Chan.send(Unit, ready, Unit{})
    Registry.require(armed, "ready queue closed")
    IO.join(Unit, go)
    IO.print("CPU_BEGIN")
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

def wait_ready(count: Nat, +ready: Chan(Unit)) -> IO(Unit):
  match count:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        IO.join(Unit, ready)
        wait_ready(rest, ready)

def release(count: Nat, +go: Chan(Unit)) -> IO(Unit):
  match count:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+rest:
      do IO<Unit>:
        sent : Bool <- Chan.send(Unit, go, Unit{})
        Registry.require(sent, "release queue closed")
        release(rest, go)

def start(mode: String, +count: Nat, +ready: Chan(Unit), +go: Chan(Unit), timer: Chan(Unit), setup: Listener & Chan(Unit)) -> IO(Unit):
  (listener, deadline_done) = setup
  do IO<Unit>:
    requests : List<Chan(Unit)> <- Transport.accept(~Context, ~handler, Nat.add(count, 1n), Context{mode, ready, go}, 1048576n, listener)
    wait_ready(count, ready)
    IO.print("BATCH_ARMED")
    timer_ready : Bool <- Chan.send(Unit, timer, Unit{})
    Registry.require(timer_ready, "timer queue closed")
    IO.sleep(50)
    release(count, go)
    Transport.join(requests)
    IO.join(Unit, deadline_done)
    IO.print("SERVER_DONE")

def serve(mode: String, +count: U32, port: U32) -> IO(Unit):
  do IO<Unit>:
    Registry.require(U32.is_gt(count, 0) && U32.is_le(count, 126), "invalid batch count")
    ready0 : Chan(Unit) <- Chan.new(Unit, count)
    go0 : Chan(Unit) <- Chan.new(Unit, count)
    timer0 : Chan(Unit) <- Chan.new(Unit, 1)
    +ready : Chan(Unit) = ready0
    +go : Chan(Unit) = go0
    +timer : Chan(Unit) = timer0
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("READY")
    first : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    setup : Listener & Chan(Unit) <- JsonProgress.accepted(first, timer)
    start(mode, U32.to_nat(count), ready, go, timer, setup)

def numbers(mode: String, count: Maybe<&2, U32>, port: Maybe<&2, U32>) -> IO(Unit):
  match count:
    case None{}:
      IO.die(Unit, 1, "invalid count")
    case Some{n}:
      match port:
        case None{}:
          IO.die(Unit, 1, "invalid port")
        case Some{p}:
          serve(mode, n, p)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> count <> port <> Nil{}:
      numbers(mode, U32.read(count), U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: json_aggregate_probe <json|yield> <count> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
