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

def main() -> IO(Unit):
  +v = vals()
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    h : U32 = outer(v, v, 0)
    t1 : Time.Duration <- Time.mono()
    IO.print("chk\tfold\t" ++ U32.show(h))
    IO.print("ms\tfold\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
