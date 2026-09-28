# Log line benchmark: the Bend side (see README.md).
import Base
import ../notch.bend as Notch

def N() -> Nat:
  20000n

def lcg32(+s: U32) -> U32:
  (s * 1664525 + 1013904223 : U32)

def gen(n: Nat, +s: U32, l: List<U32>) -> List<U32>:
  match n:
    case 0n:
      List.reverse(&1, U32, l)
    case 1n+p:
      +x = lcg32(s)
      gen(p, x, x <> l)

# FNV-1a over the chars of s, which are all ASCII here.
def fnv(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      fnv(t, (U32.xor(h, c) * 16777619 : U32))

def fields(+x: U32) -> List<&2, Notch.Field>:
  [Notch.str("user", "u\"" ++ U32.show((x % 1000 : U32))), Notch.num("id", x),
    Notch.flag("ok", U32.is_eq((x .&. 1 : U32), 1))]

def run(+lg: Notch.Logger, l: List<U32>, h: U32) -> U32:
  match l:
    case Nil{}:
      h
    case Con{x, t}:
      run(lg, t, fnv("\n", fnv(Notch.render(lg, Some{"2026-09-27T12:00:00Z"}, Notch.Info{},
        "request done", fields(x)), h)))

def main() -> IO(Unit):
  do IO<Unit>:
    l : List<U32> = gen(N(), 1, [])
    lg : Notch.Logger = Notch.with(Notch.json(Notch.Info{}), [Notch.str("svc", "api")])
    t0 : Nat <- IO.now()
    h : U32 = run(lg, l, 2166136261)
    t1 : Nat <- IO.now()
    IO.print("chk\tjson\t" ++ U32.show(h))
    IO.print("ms\tjson\t" ++ Nat.show((t1 - t0 : Nat)))
