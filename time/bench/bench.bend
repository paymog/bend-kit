# Time benchmark: the Bend side (see README.md).
import Base
import bend-kit-int@0.2.0.0/int.bend as Int
import ../time.bend as Time

def N() -> Nat:
  4096n

# The char codes of s, added to acc.
def sum(s: String, +acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      sum(t, (acc + c : U32))

def secs(m: Maybe<&2, Time.Instant>) -> U32:
  match m:
    case None{}:
      0
    case Some{Time.Instant{s, n}}:
      Int.I64.to_u32(s)

def one(+s: String) -> U32:
  (sum(s, 0) + secs(Time.rfc3339.parse(s)) : U32)

# Formats and parses back t, t + step, ...; the checksum adds each text's char codes and each parsed second.
def trip(n: Nat, +t: Int.I64, +step: Int.I64, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      trip(p, Int.I64.add(t, step), step,
        (acc + one(Maybe.default(&2, String, Time.rfc3339(Time.Instant.of_unix(t)), "")) : U32))

def report(+t0: Time.Duration, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("trip\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    report(t0, trip(N(), Int.I64.neg(Int.I64.from_u32(2208988800)), Int.I64.from_u32(3155761), 0))
