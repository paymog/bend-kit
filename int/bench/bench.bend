# Integer benchmark: the Bend side (see README.md).
import Base
import ../int.bend as Int

def N() -> Nat:
  16384n

# The 32-bit and narrower ops run 10^7 steps. A power of two would return the
# full-period U8 and U16 LCGs to their seed.
def N2() -> Nat:
  10000000n

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

def lap.s(+name: String, t0: Nat, +v: String) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ name ++ "\t" ++ v)
    stamp(name, t0)

# x = x*1664525 + 1013904223 and acc = acc + x / 1000, in wrapping I32.
def i32(n: Nat, x: Int.I32, acc: Int.I32) -> Int.I32:
  match n:
    case 0n:
      acc
    case 1n+p:
      +y = Int.I32.add(Int.I32.mul(x, Int.I32.from_u32(1664525)),
        Int.I32.from_u32(1013904223))
      i32(p, y, Int.I32.add(acc, Int.I32.div(y, Int.I32.from_u32(1000))))

# x = x*25173 + 13849 in wrapping U16; returns the last x.
def u16(n: Nat, x: Int.U16) -> Int.U16:
  match n:
    case 0n:
      x
    case 1n+p:
      u16(p, Int.U16.add(Int.U16.mul(x, Int.U16.from_u32(25173)),
        Int.U16.from_u32(13849)))

# x = x*77 + 13 in wrapping U8; returns the last x.
def u8(n: Nat, x: Int.U8) -> Int.U8:
  match n:
    case 0n:
      x
    case 1n+p:
      u8(p, Int.U8.add(Int.U8.mul(x, Int.U8.from_u32(77)), Int.U8.from_u32(13)))

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

# The seed is 1 plus a zero read from the clock, so the compiler cannot fold the loop.
def one(+t: Nat) -> U32:
  U32.from_nat(((t - t : Nat) + 1n : Nat))

def op.i32(+t: Nat) -> IO(Unit):
  lap.s("i32", t, Int.I32.show(i32(N2(), Int.I32.from_u32(one(t)), Int.I32.from_u32(0))))

def op.u16(+t: Nat) -> IO(Unit):
  lap.s("u16", t, Int.U16.show(u16(N2(), Int.U16.from_u32(one(t)))))

def op.u8(+t: Nat) -> IO(Unit):
  lap.s("u8", t, Int.U8.show(u8(N2(), Int.U8.from_u32(one(t)))))

def op.small() -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.i32(t0)
    t1 : Nat <- IO.now()
    op.u16(t1)
    t2 : Nat <- IO.now()
    op.u8(t2)

def op.rem(l: List<Int.U64>) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    lap("rem", t0, rem(l, Int.U64.from_u32(1000003), Int.U64.MIN()))
    op.small()

def run(+a: Int.U64, +c: Int.U64) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    lap("lcg", t0, lcg(N(), a, c, Int.U64.from_u32(1)))
    op.rem(gen(N(), 1, []))

def main() -> IO(Unit):
  run(num("6364136223846793005"), num("1442695040888963407"))
