import Base
import ./url.bend as Url

def show(m: Maybe<&2, Url.Url>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{u}:
      IO.print(Url.encode(u))

def case.ipv6(good: Bool, +label: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ label)
    case False{}:
      IO.die(Unit, 1, label)

def ipv6.valid(m: Maybe<&2, Url.Abs>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "IPv6 URL was rejected")
    case Some{+a}:
      Url.Abs{scheme, host, +port, +target} = a
      do IO<Unit>:
        case.ipv6(String.eq(host, "::1"), "IPv6 host")
        case.ipv6(U32.is_eq(port, 8080), "IPv6 port")
        case.ipv6(String.eq(target, "/x"), "IPv6 target")
        case.ipv6(String.eq(Url.host_field(a), "[::1]:8080"), "IPv6 Host header")

def ipv6.invalid(m: Maybe<&2, Url.Abs>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("ok malformed IPv6 authority rejected")
    case Some{a}:
      IO.die(Unit, 1, "malformed IPv6 authority accepted")

def main() -> IO(Unit):
  do IO<Unit>:
    show(Url.parse("/"))
    show(Url.parse("/x?a=1&b=2"))
    show(Url.parse("/a%20b"))
    show(Url.parse("nope"))
    ipv6.valid(Url.absolute("http://[::1]:8080/x"))
    ipv6.invalid(Url.absolute("http://[::1:8080/x"))
    ipv6.invalid(Url.absolute("http://[::1]extra/x"))
    ipv6.invalid(Url.absolute("http://[abc]/x"))
