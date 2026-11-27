# Live ws:// and wss:// write-deadline acceptance fixture.
import Base
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-time@0.3.0.5/time.bend as Time
import ./websocket.bend as WS

def finish(r: WS.Conn & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (c, out) = r
  match out:
    case Done{u}:
      do IO<Unit>:
        IO.print("DONE")
        WS.shutdown(c)
        IO.print("CLOSED")
    case Fail{(+code, why)}:
      do IO<Unit>:
        IO.print("FAIL " ++ U32.show(code))
        WS.shutdown(c)
        IO.print("CLOSED")

def send_timed(c: WS.Conn, payload: Bytes.Bytes, +ms: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("BEGIN")
    started : Time.Duration <- Time.mono()
    r : WS.Conn & Result<&1, &1, U32 & String, Unit> <- WS.send(c, True{}, 2, payload, ms)
    ended : Time.Duration <- Time.mono()
    IO.print("ELAPSED " ++ Time.Duration.show_ms(Time.Duration.sub(ended, started)))
    finish(r)

def close_timed(c: WS.Conn, +ms: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("BEGIN")
    started : Time.Duration <- Time.mono()
    r : WS.Conn & Result<&1, &1, U32 & String, Unit> <- WS.close(c, 1000, Bytes.from_string("bye"), ms)
    ended : Time.Duration <- Time.mono()
    IO.print("ELAPSED " ++ Time.Duration.show_ms(Time.Duration.sub(ended, started)))
    finish(r)

def run_mode(mode: String, c: WS.Conn) -> IO(Unit):
  match mode:
    case "send-stall":
      send_timed(c, Bytes.Bytes{16777216, [50462976 : U32*4194304n]}, 100)
    case "send-ok":
      send_timed(c, Bytes.Bytes{4096, [50462976 : U32*1024n]}, 1000)
    case "send-bad-ms":
      send_timed(c, Bytes.Bytes{4, [50462976 : U32*1n]}, 2147483648)
    case "close-bad-ms":
      close_timed(c, 2147483648)
    case "close-ok":
      close_timed(c, 1000)
    case _:
      do IO<Unit>:
        WS.shutdown(c)
        IO.die(Unit, 1, "unknown mode")

def on_conn(mode: String, r: Result<&1, &1, U32 & String, WS.Conn>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "connect failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{c}:
      run_mode(mode, c)

def start(mode: String, tls: Bool, port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case Some{+p}:
      do IO<Unit>:
        r : Result<&1, &1, U32 & String, WS.Conn> <- WS.connect("127.0.0.1", p, "localhost", "/ws", tls, 16777216, 5000)
        on_conn(mode, r)
    case None{}:
      IO.die(Unit, 1, "invalid port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> scheme <> port <> Nil{}:
      start(mode, String.eq(scheme, "wss"), U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: deadline_check <mode> <ws|wss> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
