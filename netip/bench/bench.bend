# IP address benchmark: parse+show and prefix parse+contains on fixed lists, N rounds (see README.md).
import Base
import ../../time/time.bend as Time
import ../netip.bend as Netip

def rounds() -> Nat:
  10000n

def addrs() -> List<&2, String>:
  [
    "0.0.0.0",
    "127.0.0.1",
    "192.168.1.254",
    "255.255.255.255",
    "10.0.0.1",
    "::",
    "::1",
    "2001:db8::1",
    "2001:DB8:0:0:0:0:0:1",
    "2001:0db8:0000:0000:0001:0000:0000:0001",
    "fe80::1:2:3:4",
    "1:0:0:2:0:0:0:3",
    "1:2:3:4:5:6:7:8",
    "1::",
    "2001:db8:0:1:1:1:1:1",
    "::ffff:192.0.2.128",
    "::ffff:c000:280",
    "64:ff9b::192.0.2.33",
    "ff02::fb",
    "2001:db8:85a3::8a2e:370:7334",
    "",
    "1.2.3",
    "1.2.3.4.5",
    "256.1.1.1",
    "01.2.3.4",
    "1.2.3.4 ",
    "1.2.3.٤",
    "1.2.3.4:80",
    "1:2:3:4:5:6:7",
    "1:2:3:4:5:6:7:8:9",
    "1:2:3:4:5:6:7::8",
    "1::2::3",
    "12345::",
    "1:2:3:4:5:6:7:",
    ":1:2:3:4:5:6:7",
    "[::1]",
    "fe80::1%en0",
    "::ffff:1.2.3",
    "1.2.3.4::1",
    "1:2:3:4:5:6:7:8::"
  ]

def prefixes() -> List<&2, String>:
  [
    "10.0.0.0/8",
    "192.168.0.0/16",
    "192.168.1.0/24",
    "0.0.0.0/0",
    "203.0.113.7/32",
    "2001:db8::/32",
    "fe80::/10",
    "::/0",
    "::1/128",
    "2001:db8:85a3::/48",
    "10.0.0.0/33",
    "2001:db8::/129",
    "10.0.0.0/",
    "/8",
    "10.0.0.0/8/8",
    "10.0.0.0/-1"
  ]

def probes() -> List<&2, String>:
  [
    "10.1.2.3",
    "11.0.0.1",
    "192.168.1.77",
    "192.168.2.1",
    "203.0.113.7",
    "203.0.113.8",
    "8.8.8.8",
    "2001:db8::1",
    "2001:db8:85a3::8a2e:370:7334",
    "2001:db9::1",
    "fe80::1",
    "febf:ffff::1",
    "fec0::1",
    "::1",
    "::"
  ]

# h = h*31 + c, u32, over each char.
def chk(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{+c}, t}:
      chk(t, (h * 31 + c : U32))

# A failed parse steps 1; a good one steps 2, then every char of its show.
def addr.one(m: Maybe<&2, Netip.Addr>, h: U32) -> U32:
  match m:
    case None{}:
      (h * 31 + 1 : U32)
    case Some{a}:
      chk(Netip.show(a), (h * 31 + 2 : U32))

def addr.each(xs: List<&2, String>, h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{s, t}:
      addr.each(t, addr.one(Netip.parse(s), h))

def addr.rounds(n: Nat, h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      addr.rounds(p, addr.each(addrs(), h))

def probes.push(m: Maybe<&2, Netip.Addr>, acc: List<&2, Netip.Addr>) -> List<&2, Netip.Addr>:
  match m:
    case None{}:
      acc
    case Some{a}:
      a <> acc

def probes.go(xs: List<&2, String>) -> List<&2, Netip.Addr>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{s, t}:
      probes.push(Netip.parse(s), probes.go(t))

def hit(b: Bool) -> U32:
  match b:
    case True{}:
      2
    case False{}:
      1

# h = h*3 + x: x is 0 for a failed prefix parse, else 1 (miss) or 2 (hit) per probe.
def cidr.hits(ps: List<&2, Netip.Addr>, +p: Netip.Prefix, h: U32) -> U32:
  match ps:
    case Nil{}:
      h
    case Con{a, t}:
      cidr.hits(t, p, (h * 3 + hit(Netip.contains(p, a)) : U32))

def cidr.one(m: Maybe<&2, Netip.Prefix>, +ps: List<&2, Netip.Addr>, h: U32) -> U32:
  match m:
    case None{}:
      (h * 3 : U32)
    case Some{p}:
      cidr.hits(ps, p, h)

def cidr.each(xs: List<&2, String>, +ps: List<&2, Netip.Addr>, h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{s, t}:
      cidr.each(t, ps, cidr.one(Netip.prefix.parse(s), ps, h))

def cidr.rounds(n: Nat, h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      cidr.rounds(p, cidr.each(prefixes(), probes.go(probes()), h))

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, chk: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    achk : U32 = addr.rounds(rounds(), 0)
    t1 : Time.Duration <- Time.mono()
    lap("addr", t0, t1, achk)
    t0 : Time.Duration <- Time.mono()
    cchk : U32 = cidr.rounds(rounds(), 0)
    t1 : Time.Duration <- Time.mono()
    lap("cidr", t0, t1, cchk)
