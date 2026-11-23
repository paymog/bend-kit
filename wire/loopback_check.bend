import Base

def expect_denied(denied: Bool) -> IO(Unit):
  match denied:
    case True{}:
      IO.print("ok non-loopback connect denied")
    case False{}:
      IO.die(Unit, 1, "non-loopback connect must be denied by policy")

def denied(result: Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  match result:
    case Fail{(+code, _)}:
      do IO<Unit>:
        IO.print("non-loopback connect errno " ++ U32.show(code))
        expect_denied(Bool.or(U32.is_eq(code, 1), Bool.or(U32.is_eq(code, 13), U32.is_eq(code, 113))))
    case Done{socket}:
      do IO<Unit>:
        Socket.close(socket)
        IO.die(Unit, 1, "non-loopback connect escaped isolation")

def main() -> IO(Unit):
  do IO<Unit>:
    result : Result<&1, &1, U32 & String, Socket> <- TCP.connect("1.1.1.1", 443)
    denied(result)
