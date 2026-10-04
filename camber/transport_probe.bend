# Observe existing startup, admission, and response-write seams; not a serving API.
import Base
import ./live_check.bend as Live
import ../http/http.bend as Http
import ../http/completion.bend as Completion

def written(result: Socket & Result<&1, &1, U32 & String, Unit>) -> IO((Socket & Http.Turn) & Completion.Outcome):
  (socket, outcome) = result
  match outcome:
    case Fail{error}:
      do IO<(Socket & Http.Turn) & Completion.Outcome>:
        IO.print("WRITE_FAILED")
        return Http.talk.after(Http.limits(65536n), False{}, Http.from_string(""), (socket, Fail{error}))
    case Done{unit}:
      do IO<(Socket & Http.Turn) & Completion.Outcome>:
        IO.print("WRITE_SUCCEEDED")
        return Http.talk.after(Http.limits(65536n), False{}, Http.from_string(""), (socket, Done{unit}))

def finish.turn(result: Socket & Http.Turn) -> IO(Unit):
  (socket, turn) = result
  match turn:
    case Http.TurnClose{}:
      do IO<Unit>:
        IO.print("PUBLIC_TURN_CLOSE")
        Socket.close(socket)
    case _:
      do IO<Unit>:
        IO.print("PUBLIC_TURN_OTHER")
        Socket.close(socket)

def finish.outcome(outcome: Completion.Outcome) -> IO(Unit):
  match outcome:
    case Completion.HostAccepted{}: IO.print("PUBLIC_WRITE_ACCEPTED")
    case Completion.WriteFailed{code, message}: IO.print("PUBLIC_WRITE_FAILED")
    case Completion.IncompleteResponse{}: IO.die(Unit, 1, "unexpected incomplete response")

def finish(result: (Socket & Http.Turn) & Completion.Outcome) -> IO(Unit):
  (connection, outcome) = result
  do IO<Unit>:
    finish.outcome(outcome)
    finish.turn(connection)

def accepted(result: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Socket):
  (listener, outcome) = result
  do IO<Socket>:
    socket : Socket <- IO.pass(Socket, outcome)
    Listener.close(listener)
    return socket

def write(port: U32) -> IO(Unit):
  do IO<Unit>:
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("READY")
    connection : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    socket : Socket <- accepted(connection)
    IO.print("WRITE_ARMED")
    IO.sleep(200)
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- Http.io.send.bytes(False{}, socket, Http.reply.bytes(Http.Res{200, Http.empty(), Http.from_string("ok")}, False{}, True{}))
    next : (Socket & Http.Turn) & Completion.Outcome <- written(sent)
    finish(next)

def run(mode: String, path: String, port: Maybe<&2, U32>, count: Maybe<&2, U32>) -> IO(Unit):
  match mode port count:
    case "startup" Some{p} Some{n}:
      Live.start(1, path, p, n, "w", "w")
    case "admission" Some{p} Some{n}:
      Live.start(1, path, p, n, "w", "w")
    case "write" Some{p} Some{n}:
      write(p)
    case _ _ _:
      IO.die(Unit, 1, "invalid transport probe arguments")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> path <> port <> count <> Nil{}:
      run(mode, path, U32.read(port), U32.read(count))
    case _:
      IO.die(Unit, 1, "usage: transport_probe <mode> <owned-prefix> <port> <connections>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
