# Bytes benchmark: today's String-as-bytes layout (see README.md).
import Base
import ./batch.bend as Batch

# Bytes as today's String: one Char per byte. L = 26 (64 MiB): at 16 bytes per cell, 2^28 needs 4 GiB+.

def b8(+x: U32) -> U32:
  (x .&. 255 : U32)

def build(n: Nat, +i: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      build(p, (i - 1 : U32), SCon{Chr{b8((i * 31 + 7 : U32))}, acc})

def fill(+n: U32) -> String:
  build(U32.to_nat((n - 4 : U32)), (n - 5 : U32), "\r\n\r\n")

def nth(n: Nat, s: String) -> U32:
  match n:
    case 0n:
      match s:
        case SNil{}:
          0
        case SCon{Chr{c}, t}:
          c
    case 1n+p:
      match s:
        case SNil{}:
          0
        case SCon{c, t}:
          nth(p, t)

def last(s: String, +prev: U32) -> U32:
  match s:
    case SNil{}:
      prev
    case SCon{Chr{c}, t}:
      last(t, c)

def sum(s: String, acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      sum(t, (acc + c : U32))

def find(s: String, win: U32, +res: U32, +i: U32) -> U32:
  match s:
    case SNil{}:
      res
    case SCon{Chr{c}, t}:
      +w2 = ((win << 8n) .|. c : U32)
      find(t, w2, Bool.pick(U32, Bool.and(U32.is_eq(w2, 218762506), U32.is_eq(res, 4294967295)), (i - 3 : U32), res), (i + 1 : U32))

def take(n: Nat, s: String) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      match s:
        case SNil{}:
          SNil{}
        case SCon{c, t}:
          SCon{c, take(p, t)}

def ends(+s: String) -> U32:
  (nth(0n, s) + last(s, 0) : U32)

def rep(n: Nat, +c: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      rep(p, c, SCon{Chr{c}, acc})

def collect(n: Nat, +chunk_size: U32, +k: U32, acc: List<String>) -> List<String>:
  match n:
    case 0n:
      acc
    case 1n+p:
      collect(p, chunk_size, (k + 1 : U32), Con{rep(U32.to_nat(chunk_size), b8(k), SNil{}), acc})

def joinr(xs: List<String>, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case Con{c, t}:
      joinr(t, c ++ acc)

def step.fill(state: U32 & String) -> (U32 & String) & U32:
  (+n, old) = state
  +s = fill(n)
  ((n, s), (nth(U32.to_nat((12345 % n : U32)), s) + last(s, 0) : U32))

def step.sum(state: U32 & String) -> (U32 & String) & U32:
  (+n, +s) = state
  ((n, s), sum(s, 0))

def step.find(state: U32 & String) -> (U32 & String) & U32:
  (+n, +s) = state
  ((n, s), find(s, 0, 4294967295, 0))

def step.slice(state: U32 & String) -> (U32 & String) & U32:
  (+n, +s) = state
  ((n, s), ends(take(U32.to_nat((n / 2 : U32)), String.drop(s, U32.to_nat((n / 4 + 1 : U32))))))

def step.concat(state: U32 & String) -> (U32 & String) & U32:
  (+n, s) = state
  +chunk_size = U32.min(n, 65536)
  ((n, s), ends(joinr(collect(U32.to_nat((n / chunk_size : U32)), chunk_size, 0, Nil{}), SNil{})))

def step.equal(state: String & String) -> (String & String) & U32:
  (+s, +copy) = state
  ((s, copy), Bool.pick(U32, String.eq(s, copy), 1, 0))

def size(args: List<&1, String>) -> U32:
  match args:
    case program <> l <> Nil{}:
      U32.shln(1, U32.to_nat(Maybe.default(&2, U32, U32.read(l), 26)))
    case _:
      67108864

def finish(state: U32 & String) -> IO(Unit):
  (n, +s) = state
  do IO<Unit>:
    +copy : String = fill(n)
    IO.print("copy ready " ++ U32.show(last(copy, 0)))
    unused : String & String <- Batch.run(~(String & String), ~step.equal, "equal", (s, copy))
    return Unit{}
def start(+n: U32) -> IO(Unit):
  do IO<Unit>:
    state : U32 & String <- Batch.run(~(U32 & String), ~step.fill, "fill", (n, ""))
    state : U32 & String <- Batch.run(~(U32 & String), ~step.sum, "sum", state)
    state : U32 & String <- Batch.run(~(U32 & String), ~step.find, "find", state)
    state : U32 & String <- Batch.run(~(U32 & String), ~step.slice, "slice", state)
    state : U32 & String <- Batch.run(~(U32 & String), ~step.concat, "concat", state)
    finish(state)
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    start(size(args))
