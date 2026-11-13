# Descriptive statistics benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import bend-kit-f64@0.1.3.0/f64.bend as F
import ../stats.bend as S

def xs(+x: U32) -> U32:
  +a = ((x << 13n) .^. x : U32)
  +b = ((a >> 17n) .^. a : U32)
  ((b << 5n) .^. b : U32)

# n xorshift32 draws from seed x, each shifted to 20 bits.
def gen(n: Nat, +x: U32) -> List<&2, F.F64>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +y = xs(x)
      Con{F.F64.from_u32((y >> 12n : U32)), gen(p, y)}

def chk(m: Maybe<&2, F.F64>) -> String:
  match m:
    case None{}:
      "none"
    case Some{x}:
      match x:
        case F.F64{h, l}:
          U32.show((h .^. l : U32))

def line(op: String, t0: Time.Duration, t1: Time.Duration, m: Maybe<&2, F.F64>) -> IO(Unit):
  IO.print(op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ chk(m))

def main() -> IO(Unit):
  +v = gen(10000n, 44)
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    +a : Maybe<&2, F.F64> = S.Stats.mean(v)
    t1 : Time.Duration <- Time.mono()
    line("mean", t0, t1, a)
    t2 : Time.Duration <- Time.mono()
    +b : Maybe<&2, F.F64> = S.Stats.variance(v)
    t3 : Time.Duration <- Time.mono()
    line("variance", t2, t3, b)
    t4 : Time.Duration <- Time.mono()
    +c : Maybe<&2, F.F64> = S.Stats.median(v)
    t5 : Time.Duration <- Time.mono()
    line("median", t4, t5, c)
