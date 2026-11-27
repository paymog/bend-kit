# Live packed TLS write acceptance; external peers own handshake/reads/reset/stall behavior.
import Base
import ./wire.bend as Wire
import bend-kit-time@0.3.0.5/time.bend as Time

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

def close_sock(close_tls: Bool, socket: Socket) -> IO(Unit):
  match close_tls:
    case True{}:
      do IO<Unit>:
        Wire.tls.close(socket)
        IO.print("CLOSED")
    case False{}:
      do IO<Unit>:
        Socket.close(socket)
        IO.print("CLOSED")

def write_tls(socket: Socket, len: U32, words: Array<U32>, ms: U32, close_tls: Bool) -> IO(Unit):
  do IO<Unit>:
    IO.print("BEGIN")
    started : Time.Duration <- Time.mono()
    result : Socket & (U32 & Result<&1, &1, U32 & String, Unit>) <-
      Wire.tls.send.words.deadline(socket, len, words, ms)
    ended : Time.Duration <- Time.mono()
    IO.print("ELAPSED " ++ Time.Duration.show_ms(Time.Duration.sub(ended, started)))
    socket : Socket <- report(result)
    close_sock(close_tls, socket)

def scenario(mode: String, socket: Socket) -> IO(Unit):
  match mode:
    case "success":
      write_tls(socket, 4099, [50462976 : U32*2048n], 1000, True{})
    case "empty":
      write_tls(socket, 0, [50462976 : U32*1n], 100, True{})
    case "length":
      write_tls(socket, 5, [50462976 : U32*1n], 100, True{})
    case "zero-budget":
      write_tls(socket, 4, [50462976 : U32*1n], 0, True{})
    case "large-budget":
      write_tls(socket, 4, [50462976 : U32*1n], 2147483648, True{})
    case "bad-fd":
      write_tls(socket, 4, [50462976 : U32*1n], 100, False{})
    case "reset":
      write_tls(socket, 16777216, [50462976 : U32*4194304n], 1000, True{})
    case "stall":
      write_tls(socket, 16777216, [50462976 : U32*4194304n], 100, True{})
    case "trickle":
      write_tls(socket, 16777216, [50462976 : U32*4194304n], 100, True{})
    case _:
      do IO<Unit>:
        Wire.tls.close(socket)
        IO.die(Unit, 1, "unknown scenario")

def hand(p: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Socket):
  (s, r) = p
  do IO<Socket>:
    IO.pass(Unit, r)
    return s

def connect_and_run(no_tls: Bool, mode: String, socket: Socket) -> IO(Unit):
  match no_tls:
    case True{}:
      scenario(mode, socket)
    case False{}:
      do IO<Unit>:
        p : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(socket, "localhost", 5000)
        s : Socket <- hand(p)
        IO.sleep(50)
        scenario(mode, s)

def run(+mode: String, port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case Some{p}:
      do IO<Unit>:
        socket : Socket <- IO.try(Socket, Wire.connect("127.0.0.1", p, 5000))
        connect_and_run(String.eq(mode, "bad-fd"), mode, socket)
    case None{}:
      IO.die(Unit, 1, "invalid port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> port <> Nil{}:
      run(mode, U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: tls_deadline <scenario> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
