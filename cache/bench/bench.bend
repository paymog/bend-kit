# Cache benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../cache.bend as C

def keys(n: Nat, +i: U32) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      ("k" ++ U32.show(i)) <> keys(p, (i + 1 : U32))

def fill.one(p: C.Ticket & C.Cache<U32>, +v: U32) -> C.Cache<U32>:
  (t, c) = p
  C.Cache.complete(~U32, c, t, C.Found{U32.to_nat(v), v})

# Fetches every key at clock 0 and stores version v.
def fill(ks: List<&2, String>, c: C.Cache<U32>, +v: U32) -> C.Cache<U32>:
  match ks:
    case Nil{}:
      c
    case Con{+k, t}:
      fill(t, fill.one(C.Cache.start(~U32, c, k, 0n), v), v)

def value(r: Maybe<&2, C.Entry<U32>>) -> U32:
  match r:
    case Some{C.Hit{v, x, t}}:
      x
    case _:
      0

def reads.key(n: Nat, +c: C.Cache<U32>, +k: String, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      reads.key(p, c, k, (acc + value(C.Cache.read(~U32, c, k, 0n)) : U32))

# Reads every key 8 times at clock 0.
def reads(ks: List<&2, String>, +c: C.Cache<U32>, acc: U32) -> U32:
  match ks:
    case Nil{}:
      acc
    case Con{+k, t}:
      reads(t, c, reads.key(8n, c, k, acc))

def rounds(n: Nat, +ks: List<&2, String>, c: C.Cache<U32>, +i: U32, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      +v = (i + 1 : U32)
      +d = fill(ks, c, v)
      rounds(p, ks, d, v, reads(ks, d, acc))

def lg(args: List<&1, String>) -> Nat:
  match args:
    case program <> n <> Nil{}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(n), 12))
    case _:
      12n

# The rounds come from argv, so the work cannot be computed before the clock starts.
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +n : Nat = Nat.pow(2n, lg(args))
    t0 : Time.Duration <- Time.mono()
    +v : U32 = rounds(n, keys(64n, 0), C.Cache.new(U32, C.Policy{1000000n, 1000000n}), 0, 0)
    IO.print("chk\tcache\t" ++ U32.show(v))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tcache\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
