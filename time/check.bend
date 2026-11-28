import Base
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./time.bend as Time

def show(m: Maybe<&2, String>) -> String:
  Maybe.default(&2, String, m, "none")

def chars(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{x, t}:
      SCon{Chr{x}, chars(t)}

def trip.eq(+i: Time.Instant, m: Maybe<&2, Time.Instant>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{x}:
      Cmp.is_eq(Time.Instant.cmp(x, i))

def trip.ok(+i: Time.Instant, m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{s}:
      trip.eq(i, Time.rfc3339.parse(s))

# 12:34:56.789 on day d since 1970-01-01. A def of its own: inline, the C backend hits bendlang/bend#1069.
def at(d: Int.I64) -> Time.Instant:
  Time.Instant.add(Time.Instant.of_unix(Int.I64.mul(d, Int.I64.from_u32(86400))), Time.Duration.of_ms(45296789))

# Every step days from day: parse(format(i)) == i, which runs Date.of_days and Date.to_days.
def trips(f: Nat, +day: Int.I64, +step: Int.I64, +bad: U32) -> U32:
  match f:
    case 0n:
      bad
    case 1n+g:
      +i = at(day)
      trips(g, Int.I64.add(day, step), step, (bad + Bool.pick(U32, trip.ok(i, Time.rfc3339(i)), 0, 1) : U32))


def zone.count(m: Maybe<&2, Time.Zone>) -> Nat:
  match m:
    case None{}:
      0n
    case Some{Time.Zone{ts, types, tz}}:
      List.length(&2, Time.Trans, ts)

def zone(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("zone file: read failed")
    case Done{xs}:
      +z = Time.tzif.parse(Bytes.from_string(chars(xs)))
      do IO<Unit>:
        IO.print("New_York transitions: " ++ Nat.show(zone.count(z)))

def read.done(fr: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = fr
  do IO<Unit>:
    File.close(f)
    zone(r)

def read(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("zone file: open failed")
    case Done{f}:
      do IO<Unit>:
        fr : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 1000000)
        read.done(fr)

def show_now(+n: Time.Instant) -> IO(Unit):
  IO.print("now: " ++ show(Time.rfc3339(n)) ++ " / " ++ show(Time.http_date(n)))

def dur(hi: U32, lo: U32, n: U32) -> Time.Duration:
  Time.raw.dur((hi, lo, n))

# Duration.to_us_nat and to_ms_nat round down, carry seconds past 2^32, and clamp negatives to 0.
def nats() -> Bool:
  Nat.is_eq(Time.Duration.to_us_nat(dur(0, 0, 999)), 0n) &&
    Nat.is_eq(Time.Duration.to_us_nat(dur(0, 0, 1999)), 1n) &&
    Nat.is_eq(Time.Duration.to_us_nat(dur(0, 1, 999999999)), 1999999n) &&
    Nat.is_eq(Time.Duration.to_us_nat(dur(0, 4294, 967296000)), (4294967295n + 1n : Nat)) &&
    Nat.is_eq(Time.Duration.to_us_nat(dur(0, 281474976, 710655000)), (65536n * 4294967295n + 65535n : Nat)) &&
    Nat.is_eq(Time.Duration.to_ms_nat(dur(0, 2, 345999999)), 2345n) &&
    Nat.is_eq(Time.Duration.to_ms_nat(dur(1, 0, 0)), (4294967295n * 1000n + 1000n : Nat)) &&
    Nat.is_eq(Time.Duration.to_ms_nat(Time.Duration{Int.I64.neg(Int.I64.from_u32(1)), 999999999}), 0n)

def expect(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(label ++ ": ok")
    case False{}:
      IO.die(Unit, 1, label ++ ": failed")

def zone.type(m: Maybe<&2, Time.Ttype>, offset: U32, +dst: Bool, abbr: String, label: String) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, label ++ ": no type")
    case Some{Time.Ttype{off, +flag, name}}:
      expect(Cmp.is_eq(Int.I64.cmp(off, Int.I64.neg(Int.I64.from_u32(offset)))) &&
        Bool.pick(Bool, dst, flag, Bool.not(flag)) && String.eq(name, abbr), label ++ " type")

def zone.local(m: Maybe<&2, Time.DateTime>, want: String, label: String) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, label ++ ": no local time")
    case Some{t}:
      expect(String.eq(Time.DateTime.rfc3339(t), want), label ++ " local")

def zone.case(+z: Time.Zone, +secs: U32, offset: U32, dst: Bool, abbr: String, want: String) -> IO(Unit):
  do IO<Unit>:
    zone.type(Time.Zone.at(z, Time.Instant.of_unix(Int.I64.from_u32(secs))), offset, dst, abbr, U32.show(secs))
    zone.local(Time.Zone.local(z, Time.Instant.of_unix(Int.I64.from_u32(secs))), want, U32.show(secs))

def zone.parsed(m: Maybe<&2, Time.Zone>) -> IO(Time.Zone):
  match m:
    case None{}:
      IO.die(Time.Zone, 1, "invalid timezone fixture")
    case Some{z}:
      IO.pure(Time.Zone, z)

def zone.fixture(m: Maybe<&1, Bytes.Bytes>) -> IO(Time.Zone):
  match m:
    case None{}:
      IO.die(Time.Zone, 1, "invalid timezone fixture hex")
    case Some{b}:
      zone.parsed(Time.tzif.parse(b))

def zone.checks() -> IO(Unit):
  do IO<Unit>:
    +ny : Time.Zone <- zone.fixture(Bytes.from_hex("545a696632000000000000000000000000000000000000000000000000000000000000000000000100000004ffffb9b0000045535400545a6966320000000000000000000000000000000000000000000000000000000000000300000002000000080000000065472f600000000065ed5a700000000067271160000100ffffb9b00000ffffc7c0010445535400454454000a455354354544542c4d332e322e302c4d31312e312e300a"))
    zone.case(ny, 1710053999, 18000, False{}, "EST", "2024-03-10T01:59:59Z")
    zone.case(ny, 1710054000, 14400, True{}, "EDT", "2024-03-10T03:00:00Z")
    +slim : Time.Zone <- zone.fixture(Bytes.from_hex("545a696632000000000000000000000000000000000000000000000000000000000000000000000200000008ffffb9b00000ffffc7c001044553540045445400545a6966320000000000000000000000000000000000000000000000000000000000000200000002000000080000000045f3a8f000000000472d5fe00100ffffb9b00000ffffc7c0010445535400454454000a455354354544542c4d332e322e302c4d31312e312e300a"))
    zone.case(slim, 1893456000, 18000, False{}, "EST", "2029-12-31T19:00:00Z")
    zone.case(slim, 1909094400, 14400, True{}, "EDT", "2030-06-30T20:00:00Z")

def main() -> IO(Unit):
  do IO<Unit>:
    zone.checks()
    t0 : Time.Duration <- Time.mono()
    IO.sleep(20)
    t1 : Time.Duration <- Time.mono()
    IO.print("slept 20 ms, mono says " ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    IO.print("show_ms of 2 s + 345 ns (want 2000.000345): " ++ Time.Duration.show_ms(Time.Duration{Int.I64.from_u32(2), 345}))
    IO.print("show_ms of -1 ns (want -0.000001): " ++ Time.Duration.show_ms(Time.Duration{Int.I64.neg(Int.I64.from_u32(1)), 999999999}))
    IO.print("Duration to ms/us Nat conversions (want True): " ++ Bool.show(nats()))
    m0 : Nat <- Time.mono.ms()
    u0 : Nat <- Time.mono.us()
    IO.print("mono.us / 1000 >= mono.ms (want True): " ++ Bool.show(Nat.is_ge(Nat.div(u0, 1000n), m0)))
    now : Time.Instant <- Time.now()
    show_now(now)
    IO.print("round-trip failures in 3653 days: " ++ U32.show(trips(3653n, Int.I64.neg(Int.I64.from_u32(719528)), Int.I64.from_u32(997), 0)))
    r : Result<&1, &1, U32 & String, File> <- File.open("/usr/share/zoneinfo/America/New_York", "r")
    read(r)
