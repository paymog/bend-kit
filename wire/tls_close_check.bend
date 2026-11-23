import Base
import ./wire.bend as Wire

def hand(p: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Socket):
  match p:
    case (s, r):
      do IO<Socket>:
        IO.pass(Unit, r)
        return s

def run(port: U32) -> IO(Unit):
  do IO<Unit>:
    s : Socket <- IO.try(Socket, Wire.connect("127.0.0.1", port, 5000))
    p : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, "localhost", 5000)
    s : Socket <- hand(p)
    p : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send(s, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
    s : Socket <- hand(p)
    p : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send(s, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
    s : Socket <- hand(p)
    p : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send(s, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
    s : Socket <- hand(p)
    p : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send(s, "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
    s : Socket <- hand(p)
    IO.print("closing")
    Wire.tls.close(s)
    IO.print("closed")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Con{port, Nil{}}:
      run(Maybe.default(&2, U32, U32.read(port), 0))
    case _:
      IO.die(Unit, 1, "usage: tls_close_check port")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(List.tail(&1, String, xs))
