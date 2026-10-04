# Live affine acceptance: external peers exercise the returned listener.
import Base
import ./wire.bend as Wire
import bend-kit-time@0.1.2.0/time.bend as Time

def report(result: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (listener, outcome) = result
  match outcome:
    case Done{socket}:
      do IO<Listener>:
        Socket.close(socket)
        IO.print("DONE CLOSED_SOCKET")
        return listener
    case Fail{(code, why)}:
      do IO<Listener>:
        IO.print("FAIL " ++ U32.show(code))
        return listener

def accept(listener: Listener, ms: U32) -> IO(Listener):
  do IO<Listener>:
    started : Time.Duration <- Time.mono()
    result : Listener & Result<&1, &1, U32 & String, Socket> <-
      Wire.accept.deadline(listener, ms)
    ended : Time.Duration <- Time.mono()
    IO.print("ELAPSED " ++ Time.Duration.show_ms(Time.Duration.sub(ended, started)))
    report(result)

# Process.run blocks the JS loop but uses a native helper thread.
def blocker() -> IO(Unit):
  do IO<Unit>:
    IO.sleep(10)
    result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run("/bin/sleep", ["0.15"], "", 1024, 1000)
    IO.print("BLOCKER_DONE")

def scenario(mode: String, listener: Listener) -> IO(Listener):
  match mode:
    case "scheduling":
      do IO<Listener>:
        child : Chan(Unit) <- IO.fork(Unit, blocker())
        listener : Listener <- accept(listener, 40)
        IO.join(Unit, child)
        return listener
    case "queued":
      do IO<Listener>:
        IO.sleep(200)
        accept(listener, 1000)
    case "maximum":
      do IO<Listener>:
        IO.sleep(200)
        accept(listener, 2147483647)
    case "repeat":
      do IO<Listener>:
        listener : Listener <- accept(listener, 40)
        listener : Listener <- accept(listener, 40)
        IO.print("CONNECT")
        accept(listener, 1000)
    case "invalid":
      do IO<Listener>:
        listener : Listener <- accept(listener, 0)
        listener : Listener <- accept(listener, 2147483648)
        listener : Listener <- accept(listener, 4294967295)
        IO.print("CONNECT")
        accept(listener, 1000)
    case "minimum":
      accept(listener, 1)
    case "empty":
      accept(listener, 40)
    case "delayed":
      accept(listener, 1000)
    case "port-zero":
      accept(listener, 1000)
    case _:
      do IO<Listener>:
        Listener.close(listener)
        IO.die(Listener, 1, "unknown scenario")

def run(mode: String, port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case Some{p}:
      do IO<Unit>:
        listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", p))
        IO.print("READY")
        IO.sleep(200)
        IO.print("BEGIN")
        listener : Listener <- scenario(mode, listener)
        Listener.close(listener)
        IO.print("CLOSED_LISTENER")
    case None{}:
      IO.die(Unit, 1, "invalid port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> port <> Nil{}:
      run(mode, U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: accept_deadline <scenario> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
