import Base
import ./bits.bend as Bits
import ./check.bend as Check
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

def finished(+ok: Bool, r: Bytes.Bytes & Nat) -> Bool:
  (b, pos) = r
  Bytes.Bytes{len, buf} = b
  Bool.and(ok, Nat.is_eq(pos, Nat.mul(U32.to_nat(len), 8n)))

def aligned(+ok: Bool, r: Bits.Reader & Bool) -> Bool:
  (rd, skipped) = r
  finished(Bool.and(ok, Bool.not(skipped)), Bits.Reader.finish(rd))

def remaining(+ok: Bool, r: Bits.Reader & Nat) -> Bool:
  (rd, left) = r
  aligned(Bool.and(ok, Nat.is_eq(left, 6n)), Bits.Reader.skip(Bits.Reader.align(rd), 1n))

def second(+ok: Bool, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, value) = r
  remaining(Bool.and(ok, Check.same(value, 5461)), Bits.Reader.left(rd))

def peeked(+msb: Bool, +ok: Bool, r: Bits.Reader & U32) -> Bool:
  (rd, value) = r
  second(Bool.and(ok, U32.is_eq(value, 5461)), Check.get(msb, rd, 13))

def peek(msb: Bool, rd: Bits.Reader) -> Bits.Reader & U32:
  match msb:
    case False{}:
      Bits.Reader.peek.lsb(rd, 13)
    case True{}:
      Bits.Reader.peek.msb(rd, 13)

def first(+msb: Bool, +ok: Bool, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, value) = r
  peeked(msb, Bool.and(ok, Check.same(value, 3735928559)), peek(msb, rd))

def skipped(+msb: Bool, r: Bits.Reader & Bool) -> Bool:
  (rd, ok) = r
  first(msb, ok, Check.get(msb, rd, 32))

def run(+msb: Bool, +depth: U32) -> Bool:
  +start = Nat.sub(Nat.mul(U32.to_nat(U32.shln(1, U32.to_nat(depth))), 32n), 3n)
  w : Bits.Writer = Bits.Writer{Array.new(U32, U32.to_nat(depth), 0), depth, start, msb}
  b = Bits.Writer.finish(Check.put(msb, Check.put(msb, w, 32, 3735928559), 13, 5461))
  skipped(msb, Bits.Reader.skip(Bits.Reader.new(b), start))

def checked(ok: Bool, +depth: U32) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "depth must be between 0 and 27")
    case True{}:
      do IO<Unit>:
        Check.expect("lsb fields across and past the initial capacity", run(False{}, depth))
        Check.expect("msb fields across and past the initial capacity", run(True{}, depth))

def parsed(depth: Maybe<&2, U32>) -> IO(Unit):
  match depth:
    case None{}:
      IO.die(Unit, 1, "expected an array depth")
    case Some{+d}:
      checked(U32.is_le(d, 27), d)

def args(xs: List<String>) -> IO(Unit):
  match xs:
    case Con{program, Con{depth, Nil{}}}:
      parsed(U32.read(depth))
    case _:
      IO.die(Unit, 1, "usage: large-check DEPTH")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<String> <- IO.args()
    args(xs)
