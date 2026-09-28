# Shortest F32 benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../fmt.bend as Fmt

def N() -> Nat:
  50000n

def f32(x: U32) -> F32:
  match x:
    case U32{w}:
      F32{w}

def lcg32(+s: U32) -> U32:
  (s * 1664525 + 1013904223 : U32)

def gen(n: Nat, +s: U32, l: List<U32>) -> List<U32>:
  match n:
    case 0n:
      List.reverse(&1, U32, l)
    case 1n+p:
      +x = lcg32(s)
      gen(p, x, x <> l)

# FNV-1a over the octets of s.
def fnv(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      fnv(t, (U32.xor(h, c) * 16777619 : U32))

def run(l: List<U32>, h: U32) -> U32:
  match l:
    case Nil{}:
      h
    case Con{x, t}:
      run(t, fnv("\n", fnv(Fmt.F32.shortest(f32(x)), h)))

def main() -> IO(Unit):
  do IO<Unit>:
    l : List<U32> = gen(N(), 1, [])
    t0 : Time.Duration <- Time.mono()
    h : U32 = run(l, 2166136261)
    IO.print("chk\tshort\t" ++ U32.show(h))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tshort\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
