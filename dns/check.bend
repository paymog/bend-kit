import Base
import ./dns.bend as Dns

def ok(hit: Bool, +name: String, +got: String) -> IO(Unit):
  match hit:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, name ++ " gave " ++ got)

def ipv6.in(+s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.or(U32.is_eq(c, 58), ipv6.in(t))

def has_ipv6(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+a, t}:
      Bool.or(ipv6.in(a), has_ipv6(t))

def quote(s: String) -> String:
  "\"" ++ s ++ "\""

def report(+xs: List<&2, String>) -> IO(Unit):
  ok(has_ipv6(xs), "resolve.all AAAA", List.show(~&2, ~String, ~quote, xs))

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&2, String> <- Dns.resolve.all("ipv6.google.com")
    report(xs)
