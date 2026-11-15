import Base
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
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
        # Local time is not printed: Zone.local and DateTime.rfc3339 in one segment hit bendlang/bend#1069.

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

def main() -> IO(Unit):
  do IO<Unit>:
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
