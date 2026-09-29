# tty width/pad_right benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../tty.bend as Tty

def N() -> Nat:
  20000n

def COLS() -> U32:
  20

def lcg32(+s: U32) -> U32:
  (s * 1664525 + 1013904223 : U32)

# Class c of 9: 0..2 ASCII, 3 Greek, 4 CJK, 5 Hangul, 6 Hiragana, 7 combining marks, 8 fullwidth forms.
def base(+c: U32) -> U32:
  Bool.pick(U32, U32.is_lt(c, 3), 33, Bool.pick(U32, U32.is_eq(c, 3), 945, Bool.pick(U32, U32.is_eq(c, 4), 19968, Bool.pick(U32, U32.is_eq(c, 5), 44032, Bool.pick(U32, U32.is_eq(c, 6), 12353, Bool.pick(U32, U32.is_eq(c, 7), 768, 65281))))))

def span(+c: U32) -> U32:
  Bool.pick(U32, U32.is_lt(c, 3), 94, Bool.pick(U32, U32.is_eq(c, 3), 25, Bool.pick(U32, U32.is_eq(c, 4), 512, Bool.pick(U32, U32.is_eq(c, 5), 512, Bool.pick(U32, U32.is_eq(c, 6), 86, Bool.pick(U32, U32.is_eq(c, 7), 52, 94))))))

def cp(+v: U32) -> U32:
  +c = (v % 9 : U32)
  (base(c) + v / 9 % span(c) : U32)

def gen.str(k: Nat, +s: U32, acc: String) -> U32 & String:
  match k:
    case 0n:
      (s, String.reverse(acc))
    case 1n+p:
      +x = lcg32(s)
      gen.str(p, x, SCon{Chr{cp((x >> 8n : U32))}, acc})

# One string: length 1..16 from the next word, then one code point per word.
def step(+s: U32) -> U32 & String:
  +x = lcg32(s)
  gen.str(U32.to_nat((1 + (x >> 16n : U32) % 16 : U32)), x, SNil{})

# r holds the seed and the string drawn last, not yet in acc.
def gen(n: Nat, r: U32 & String, acc: List<&2, String>) -> List<&2, String>:
  match n:
    case 0n:
      (s, str) = r
      List.reverse(&2, String, str <> acc)
    case 1n+p:
      (+s, str) = r
      gen(p, step(s), str <> acc)

def gen.start(n: Nat) -> List<&2, String>:
  match n:
    case 0n:
      []
    case 1n+p:
      gen(p, step(1), [])

def widths(+xs: List<&2, String>, t: U32) -> U32:
  match xs:
    case Nil{}:
      t
    case Con{x, rest}:
      widths(rest, (t + Tty.width(x) : U32))

# FNV-1a over code points; n counts them.
def fnv(s: String, h: U32, n: U32) -> U32 & U32:
  match s:
    case SNil{}:
      (h, n)
    case SCon{Chr{c}, t}:
      fnv(t, (U32.xor(h, c) * 16777619 : U32), (n + 1 : U32))

def pads(+xs: List<&2, String>, r: U32 & U32) -> U32 & U32:
  match xs:
    case Nil{}:
      r
    case Con{x, rest}:
      (h, n) = r
      pads(rest, fnv(Tty.pad_right(x, COLS()) ++ "\n", h, n))

def lap(+op: String, t0: Time.Duration, t1: Time.Duration) -> IO(Unit):
  IO.print("ms\t" ++ op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

# Checksums print before the second clock read so the work is forced.
def op.pad(t0: Time.Duration, r: U32 & U32) -> IO(Unit):
  (h, n) = r
  do IO<Unit>:
    IO.print("chk\tpad\t" ++ U32.show(h))
    IO.print("chk\tpadlen\t" ++ U32.show(n))
    t1 : Time.Duration <- Time.mono()
    lap("pad", t0, t1)

def main() -> IO(Unit):
  do IO<Unit>:
    +xs : List<&2, String> = gen.start(N())
    t0 : Time.Duration <- Time.mono()
    IO.print("chk\twidth\t" ++ U32.show(widths(xs, 0)))
    t1 : Time.Duration <- Time.mono()
    lap("width", t0, t1)
    t2 : Time.Duration <- Time.mono()
    op.pad(t2, pads(xs, (2166136261, 0)))
