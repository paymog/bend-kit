import Base
import ./netip.bend as Netip

def ok(label: String, passed: Bool) -> IO(Unit):
  match passed:
    case True{}:
      IO.print("ok " ++ label)
    case False{}:
      IO.die(Unit, 1, "failed " ++ label)

def canonical.result(text: String, want: String, result: Maybe<&2, Netip.Addr>) -> IO(Unit):
  match result:
    case None{}:
      IO.die(Unit, 1, "rejected " ++ text)
    case Some{addr}:
      ok(text, String.eq(Netip.show(addr), want))

def canonical(+text: String, want: String) -> IO(Unit):
  canonical.result(text, want, Netip.parse(text))

def addr.invalid(result: Maybe<&2, Netip.Addr>) -> Bool:
  match result:
    case None{}:
      True{}
    case Some{addr}:
      False{}

def prefix.bad(result: Maybe<&2, Netip.Prefix>) -> Bool:
  match result:
    case None{}:
      True{}
    case Some{prefix}:
      False{}

def invalid(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      Bool.and(addr.invalid(Netip.parse(h)), invalid(t))

def prefix.invalid(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      Bool.and(prefix.bad(Netip.prefix.parse(h)), prefix.invalid(t))

def prefix.case.result(+text: String, want: String, first: Netip.Addr, last: Netip.Addr, outside: Netip.Addr,
  result: Maybe<&2, Netip.Prefix>) -> IO(Unit):
  match result:
    case None{}:
      IO.die(Unit, 1, "rejected prefix " ++ text)
    case Some{+prefix}:
      do IO<Unit>:
        ok(text ++ " canonical", String.eq(Netip.prefix.show(prefix), want))
        ok(text ++ " first", Netip.contains(prefix, first))
        ok(text ++ " last", Netip.contains(prefix, last))
        ok(text ++ " outside", Bool.not(Netip.contains(prefix, outside)))

def prefix.case(+text: String, want: String, first: Netip.Addr, last: Netip.Addr, outside: Netip.Addr) -> IO(Unit):
  prefix.case.result(text, want, first, last, outside, Netip.prefix.parse(text))

def main() -> IO(Unit):
  do IO<Unit>:
    canonical("0.0.0.0", "0.0.0.0")
    canonical("255.255.255.255", "255.255.255.255")
    canonical("192.0.2.1", "192.0.2.1")
    canonical("2001:0DB8:0:0:0:0:0:1", "2001:db8::1")
    canonical("2001:db8:0:0:1:0:0:1", "2001:db8::1:0:0:1")
    canonical("1:2:3:4:5:6:7:8", "1:2:3:4:5:6:7:8")
    canonical("::", "::")
    canonical("::1", "::1")
    canonical("1::", "1::")
    canonical("2001:db8:0:1:1:1:1:1", "2001:db8:0:1:1:1:1:1")
    canonical("::ffff:192.0.2.1", "::ffff:192.0.2.1")
    canonical("2001:db8::192.0.2.1", "2001:db8::c000:201")
    ok("invalid address syntax", invalid(["", "1.2.3", "1.2.3.4.5", "01.2.3.4", "1.2.3.-1", "1.2.3.256", "1.2.3.4:", ":::1", "1::2::3", "1:2:3:4:5:6:7", "1:2:3:4:5:6:7:8:9", "2001:db8::g", "2001:db8::10000", "fe80::1%eth0", "[::1]", "::ffff:192.0.2.256", "1:2:3:4:5:6:7:192.0.2.1"]))
    prefix.case("192.0.2.1/24", "192.0.2.1/24", Netip.V4{3221225984}, Netip.V4{3221226239}, Netip.V4{3221226240})
    prefix.case("0.0.0.0/0", "0.0.0.0/0", Netip.V4{0}, Netip.V4{4294967295}, Netip.V6{0, 0, 0, 0})
    prefix.case("192.0.2.1/32", "192.0.2.1/32", Netip.V4{3221225985}, Netip.V4{3221225985}, Netip.V4{3221225986})
    prefix.case("2001:db8::1/126", "2001:db8::1/126", Netip.V6{536939960, 0, 0, 0}, Netip.V6{536939960, 0, 0, 3}, Netip.V6{536939960, 0, 0, 4})
    prefix.case("::/0", "::/0", Netip.V6{0, 0, 0, 0}, Netip.V6{4294967295, 4294967295, 4294967295, 4294967295}, Netip.V4{0})
    prefix.case("::1/128", "::1/128", Netip.V6{0, 0, 0, 1}, Netip.V6{0, 0, 0, 1}, Netip.V6{0, 0, 0, 2})
    ok("invalid prefix syntax", prefix.invalid(["1.2.3.4/", "1.2.3.4/-1", "1.2.3.4/33", "1.2.3.4/024", "1.2.3.4/1/2", "::1/129", "::1/abc", "::1/1.0"]))
    ok("address equality", Netip.eq(Netip.V4{3221225985}, Netip.V4{3221225985}))
    ok("family inequality", Bool.not(Netip.eq(Netip.V4{0}, Netip.V6{0, 0, 0, 0})))
