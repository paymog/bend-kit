# Soft-float benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../f64.bend as F

def vals() -> List<&2, F.F64>:
  F.F64{1072693248, 0} <> F.F64{1073217536, 0} <> F.F64{1074266112, 0} <> F.F64{1017118720, 0} <> F.F64{0, 1} <> F.F64{3220176896, 0} <> Nil{}

def hi(x: F.F64) -> U32:
  match x:
    case F.F64{h, l}:
      h

def mix(h: U32, +a: F.F64, +b: F.F64) -> U32:
  ((h .^. hi(F.F64.add(a, b)) .^. hi(F.F64.mul(a, b)) .^. hi(F.F64.div(a, b)) : U32))

def inner(bs: List<&2, F.F64>, +a: F.F64, h: U32) -> U32:
  match bs:
    case Nil{}:
      h
    case Con{b, t}:
      inner(t, a, mix(h, a, b))

def outer(as: List<&2, F.F64>, +bs: List<&2, F.F64>, h: U32) -> U32:
  match as:
    case Nil{}:
      h
    case Con{a, t}:
      outer(t, bs, inner(bs, a, h))

def xs(+x: U32) -> U32:
  +a = ((x << 13n) .^. x : U32)
  +b = ((a >> 17n) .^. a : U32)
  ((b << 5n) .^. b : U32)

def pick(fin: Bool, +h: U32, l: U32, rest: List<&2, F.F64>) -> List<&2, F.F64>:
  match fin:
    case True{}:
      Con{F.F64{h, l}, rest}
    case False{}:
      rest

# n xorshift32 pairs as high and low words, keeping the finite ones.
def gen(n: Nat, +x: U32) -> List<&2, F.F64>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +h = xs(x)
      +l = xs(h)
      pick(Bool.not(U32.is_eq(((h >> 20n) .&. 2047 : U32), 2047)), h, l, gen(p, l))

def shows(v: List<&2, F.F64>) -> List<&2, String>:
  match v:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      Con{F.F64.show(x), shows(t)}

def word(m: Maybe<&2, F.F64>) -> U32:
  match m:
    case None{}:
      0
    case Some{x}:
      match x:
        case F.F64{h, l}:
          (h .^. l : U32)

def reads(ss: List<&2, String>, h: U32) -> U32:
  match ss:
    case Nil{}:
      h
    case Con{s, t}:
      reads(t, (h .^. word(F.F64.read(s)) : U32))

def roots(xs: List<&2, F.F64>, h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{x, t}:
      +r = F.F64.sqrt(F.F64.abs(x))
      roots(t, (h .^. F.F64.hi(r) .^. F.F64.lo(r) : U32))

def main() -> IO(Unit):
  +v = vals()
  +nums = gen(1000n, 611)
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    h : U32 = outer(v, v, 0)
    t1 : Time.Duration <- Time.mono()
    IO.print("chk\tfold\t" ++ U32.show(h))
    IO.print("ms\tfold\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    t2 : Time.Duration <- Time.mono()
    +ss : List<&2, String> = shows(nums)
    t3 : Time.Duration <- Time.mono()
    IO.print("chk\tshow\t" ++ U32.show(reads(ss, 0)))
    IO.print("ms\tshow\t" ++ Time.Duration.show_ms(Time.Duration.sub(t3, t2)))
    t4 : Time.Duration <- Time.mono()
    r : U32 = reads(ss, 0)
    t5 : Time.Duration <- Time.mono()
    IO.print("chk\tread\t" ++ U32.show(r))
    IO.print("ms\tread\t" ++ Time.Duration.show_ms(Time.Duration.sub(t5, t4)))
    t6 : Time.Duration <- Time.mono()
    h : U32 = roots(nums, 0)
    t7 : Time.Duration <- Time.mono()
    IO.print("chk\tsqrt\t" ++ U32.show(h))
    IO.print("ms\tsqrt\t" ++ Time.Duration.show_ms(Time.Duration.sub(t7, t6)))
