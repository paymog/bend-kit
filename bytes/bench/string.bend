# Bytes benchmark: today's String-as-bytes layout (see README.md).
import Base
import ../../time/time.bend as Time

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

def collect(n: Nat, +k: U32, acc: List<String>) -> List<String>:
  match n:
    case 0n:
      acc
    case 1n+p:
      collect(p, (k + 1 : U32), Con{rep(65536n, b8(k), SNil{}), acc})

def joinr(xs: List<String>, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case Con{c, t}:
      joinr(t, c ++ acc)

def lap(+name: String, t0: Time.Duration, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ name ++ "\t" ++ U32.show(chk))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\t" ++ name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def op.equal(+s: String, +s2: String) -> IO(Unit):
  do IO<Unit>:
    IO.print("copy ready " ++ U32.show(last(s2, 0)))
    t0 : Time.Duration <- Time.mono()
    lap("equal", t0, Bool.pick(U32, String.eq(s, s2), 1, 0))

def op.concat(+n: U32, +s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap("concat", t0, ends(joinr(collect(U32.to_nat((n / 65536 : U32)), 0, Nil{}), SNil{})))
    op.equal(s, fill(n))

def op.slice(+n: U32, +s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap("slice", t0, ends(take(U32.to_nat((n / 2 : U32)), String.drop(s, U32.to_nat((n / 4 + 1 : U32))))))
    op.concat(n, s)

def op.find(+n: U32, +s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap("find", t0, find(s, 0, 4294967295, 0))
    op.slice(n, s)

def op.sum(+n: U32, +s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap("sum", t0, sum(s, 0))
    op.find(n, s)

def op.fill.done(+n: U32, t0: Time.Duration, +s: String) -> IO(Unit):
  do IO<Unit>:
    lap("fill", t0, (nth(12345n, s) + last(s, 0) : U32))
    op.sum(n, s)

def size(args: List<&1, String>) -> U32:
  match args:
    case program <> l <> Nil{}:
      U32.shln(1, U32.to_nat(Maybe.default(&2, U32, U32.read(l), 26)))
    case _:
      67108864

def start(+n: U32) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.fill.done(n, t0, fill(n))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    start(size(args))
