# Live packed write acceptance; external peers own reads/reset/stall behavior.
import Base
import ./wire.bend as Wire
import bend-kit-time@0.1.2.1/time.bend as Time

def report(result: Socket & (U32 & Result<&1, &1, U32 & String, Unit>)) -> IO(Socket):
  (socket, (made, outcome)) = result
  match outcome:
    case Done{unit}:
      do IO<Socket>:
        IO.print("DONE " ++ U32.show(made))
        return socket
    case Fail{(code, why)}:
      do IO<Socket>:
        IO.print("FAIL " ++ U32.show(code) ++ " " ++ U32.show(made))
        return socket

def write(socket: Socket, len: U32, words: Array<U32>, ms: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("BEGIN")
    started : Time.Duration <- Time.mono()
    result : Socket & (U32 & Result<&1, &1, U32 & String, Unit>) <-
      Wire.send.words.deadline(socket, len, words, ms)
    ended : Time.Duration <- Time.mono()
    IO.print("ELAPSED " ++ Time.Duration.show_ms(Time.Duration.sub(ended, started)))
    socket : Socket <- report(result)
    Socket.close(socket)
    IO.print("CLOSED")

def scenario(mode: String, socket: Socket) -> IO(Unit):
  match mode:
    case "success":
      write(socket, 4099, [50462976 : U32*2048n], 1000)
    case "stall":
      write(socket, 16777216, [50462976 : U32*4194304n], 100)
    case "reset":
      write(socket, 16777216, [50462976 : U32*4194304n], 1000)
    case "length":
      write(socket, 5, [50462976 : U32*1n], 100)
    case "zero-budget":
      write(socket, 4, [50462976 : U32*1n], 0)
    case "trickle":
      write(socket, 16777216, [50462976 : U32*4194304n], 100)
    case "large-budget":
      write(socket, 4, [50462976 : U32*1n], 2147483648)
    case "empty":
      write(socket, 0, [50462976 : U32*1n], 100)
    case _:
      do IO<Unit>:
        Socket.close(socket)
        IO.die(Unit, 1, "unknown scenario")

def accepted(result: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Socket):
  (listener, outcome) = result
  do IO<Socket>:
    socket : Socket <- IO.pass(Socket, outcome)
    Listener.close(listener)
    return socket

def run(mode: String, port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case Some{p}:
      do IO<Unit>:
        listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", p))
        IO.print("READY")
        result : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
        socket : Socket <- accepted(result)
        IO.sleep(100)
        scenario(mode, socket)
    case None{}:
      IO.die(Unit, 1, "invalid port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> port <> Nil{}:
      run(mode, U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: deadline <scenario> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
