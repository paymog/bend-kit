import Base
import bend-kit-int@0.2.0.0/int.bend as Int
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
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

def zone.show(m: Maybe<&2, Time.Zone>, +s: U32) -> String:
  match m:
    case None{}:
      "no zone"
    case Some{z}:
      show(Maybe.map(&2, Time.DateTime, String, Time.DateTime.rfc3339,
        Time.Zone.local(z, Time.Instant{Int.I64.from_u32(s), 0})))

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
        IO.print("2024-03-10T06:59:59Z local: " ++ zone.show(z, 1710053999))
        IO.print("2024-03-10T07:00:00Z local: " ++ zone.show(z, 1710054000))
        IO.print("2024-11-03T05:59:59Z local: " ++ zone.show(z, 1730613599))
        IO.print("2024-11-03T06:00:00Z local: " ++ zone.show(z, 1730613600))

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

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    IO.sleep(20)
    t1 : Time.Duration <- Time.mono()
    IO.print("slept 20 ms, mono says " ++ Int.I64.show(Time.Duration.to_ms(Time.Duration.sub(t1, t0))))
    now : Time.Instant <- Time.now()
    show_now(now)
    IO.print("round-trip failures in 3653 days: " ++ U32.show(trips(3653n, Int.I64.neg(Int.I64.from_u32(719528)), Int.I64.from_u32(997), 0)))
    r : Result<&1, &1, U32 & String, File> <- File.open("/usr/share/zoneinfo/America/New_York", "r")
    read(r)
