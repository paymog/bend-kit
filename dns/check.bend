import Base
import ./dns.bend as Dns
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes

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

def answer.is(m: Maybe<&2, String>, +want: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{ip}:
      String.eq(ip, want)

# A zero-length skipped RDATA region must leave at the next record's name.
def region.check() -> IO(Unit):
  ok(answer.is(Dns.answer(1, Bytes.from_string(
    "\u{0}\u{1}\u{81}\u{80}\u{0}\u{0}\u{0}\u{2}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{5}\u{0}\u{1}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{c0}\u{0}\u{0}\u{1}\u{0}\u{1}\u{0}\u{0}\u{0}\u{0}\u{0}\u{4}\u{1}\u{2}\u{3}\u{4}")), "1.2.3.4"),
    "zero-length RDATA then A", "wrong address")

def main() -> IO(Unit):
  do IO<Unit>:
    region.check()
    xs : List<&2, String> <- Dns.resolve.all("ipv6.google.com")
    report(xs)
