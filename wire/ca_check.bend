import Base
import ./wire.bend as Wire

def die(+name: String, +why: String) -> IO(Unit):
  IO.die(Unit, 1, name ++ ": " ++ why)

def expect.fail.code(+name: String, +code: U32, +why: String, s: Socket, same: Bool) -> IO(Unit):
  match same:
    case True{}:
      do IO<Unit>:
        IO.print("ok " ++ name)
        Socket.close(s)
    case False{}:
      do IO<Unit>:
        Socket.close(s)
        die(name, U32.show(code) ++ " " ++ why)

def expect.fail(+name: String, +want: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match m:
    case (s, Fail{(+code, why)}):
      expect.fail.code(name, code, why, s, U32.is_eq(code, want))
    case (s, Done{u}):
      do IO<Unit>:
        Wire.tls.close(s)
        die(name, "handshake succeeded")

def expect.ok(+name: String, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match m:
    case (s, Fail{(+code, why)}):
      do IO<Unit>:
        Socket.close(s)
        die(name, U32.show(code) ++ " " ++ why)
    case (s, Done{u}):
      do IO<Unit>:
        IO.print("ok " ++ name)
        Wire.tls.close(s)

def expect.alpn(+name: String, m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match m:
    case (s, Fail{(+code, why)}):
      do IO<Unit>:
        Socket.close(s)
        die(name, U32.show(code) ++ " " ++ why)
    case (s, Done{proto}):
      do IO<Unit>:
        IO.print("ok " ++ name)
        Wire.tls.close(s)

def connected(+name: String, r: Result<&1, &1, U32 & String, Socket>) -> IO(Socket):
  match r:
    case Fail{(+code, why)}:
      IO.die(Socket, 1, name ++ ": " ++ U32.show(code) ++ " " ++ why)
    case Done{s}:
      IO.pure(Socket, s)

def step.ca(+ca: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Socket> <- Wire.connect("127.0.0.1", 39445, 5000)
    s : Socket <- connected("connect", r)
    m : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect.ca(s, "localhost", 5000, ca)
    expect.ok("private CA", m)

def step.alpn(+ca: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Socket> <- Wire.connect("127.0.0.1", 39445, 5000)
    s : Socket <- connected("connect", r)
    m : Socket & Result<&1, &1, U32 & String, String> <-
      Wire.tls.connect.alpn.ca(s, "localhost", 5000, "http/1.1", ca)
    expect.alpn("private CA with ALPN", m)

def step.default() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Socket> <- Wire.connect("127.0.0.1", 39445, 5000)
    s : Socket <- connected("connect", r)
    m : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, "localhost", 5000)
    expect.fail("default store rejects private CA", 100, m)

def step.missing() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Socket> <- Wire.connect("127.0.0.1", 39445, 5000)
    s : Socket <- connected("connect", r)
    m : Socket & Result<&1, &1, U32 & String, Unit> <-
      Wire.tls.connect.ca(s, "localhost", 5000, "/nonexistent/bend-kit-ca.pem")
    expect.fail("missing CA file", 22, m)

def run(+ca: String) -> IO(Unit):
  do IO<Unit>:
    step.ca(ca)
    step.alpn(ca)
    step.default()
    step.missing()

def main.args(args: List<&1, String>) -> IO(Unit):
  match args:
    case Con{ca, Nil{}}:
      run(ca)
    case _:
      IO.die(Unit, 1, "ca_check needs a CA file path")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    main.args(List.tail(&1, String, args))
