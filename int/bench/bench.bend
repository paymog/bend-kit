# Integer benchmark: the Bend side (see README.md).
import Base
import ../int.bend as Int

def N() -> Nat:
  16384n

def num(s: String) -> Int.U64:
  Maybe.default(&2, Int.U64, Int.U64.read(s), Int.U64.MIN())

def stamp(+name: String, t0: Nat) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    IO.print("ms\t" ++ name ++ "\t" ++ Nat.show((t1 - t0 : Nat)))

def lap(+name: String, t0: Nat, +v: Int.U64) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ name ++ "\t" ++ Int.U64.show(v))
    stamp(name, t0)

# x_{i+1} = x_i * a + c (mod 2^64) from x_0 = 1; returns x_N.
def lcg(n: Nat, +a: Int.U64, +c: Int.U64, x: Int.U64) -> Int.U64:
  match n:
    case 0n:
      x
    case 1n+p:
      lcg(p, a, c, Int.U64.add(Int.U64.mul(x, a), c))

def lcg32(+s: U32) -> U32:
  (s * 1664525 + 1013904223 : U32)

def join(hi: U32, lo: U32) -> Int.U64:
  Int.U64.or(Int.U64.shl(Int.U64.from_u32(hi), 32n), Int.U64.from_u32(lo))

# The dividends come from a U32 LCG: a U64 loop that copies four U64 values
# overflows the C backend's 247 live words (bendlang/bend#1069).
def gen(n: Nat, +s: U32, l: List<Int.U64>) -> List<Int.U64>:
  match n:
    case 0n:
      l
    case 1n+p:
      +hi = lcg32(s)
      +lo = lcg32(hi)
      gen(p, lo, join(hi, lo) <> l)

# Sum of x mod m over the list, wrapping.
def rem(l: List<Int.U64>, +m: Int.U64, acc: Int.U64) -> Int.U64:
  match l:
    case Nil{}:
      acc
    case Con{x, t}:
      rem(t, m, Int.U64.add(acc, Int.U64.mod(x, m)))

def op.rem(l: List<Int.U64>) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    lap("rem", t0, rem(l, Int.U64.from_u32(1000003), Int.U64.MIN()))

def run(+a: Int.U64, +c: Int.U64) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    lap("lcg", t0, lcg(N(), a, c, Int.U64.from_u32(1)))
    op.rem(gen(N(), 1, []))

def main() -> IO(Unit):
  run(num("6364136223846793005"), num("1442695040888963407"))
