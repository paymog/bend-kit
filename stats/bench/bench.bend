# Descriptive statistics benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import bend-kit-f64@0.1.3.0/f64.bend as F
import ../stats.bend as S

def xs(+x: U32) -> U32:
  +a = ((x << 13n) .^. x : U32)
  +b = ((a >> 17n) .^. a : U32)
  ((b << 5n) .^. b : U32)

# n xorshift32 draws from seed x, each shifted to 20 bits.
def gen(n: Nat, +x: U32) -> List<&2, F.F64>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +y = xs(x)
      Con{F.F64.from_u32((y >> 12n : U32)), gen(p, y)}

def chk(m: Maybe<&2, F.F64>) -> String:
  match m:
    case None{}:
      "none"
    case Some{x}:
      match x:
        case F.F64{h, l}:
          U32.show((h .^. l : U32))

def line(op: String, t0: Time.Duration, t1: Time.Duration, m: Maybe<&2, F.F64>) -> IO(Unit):
  IO.print(op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ chk(m))

def edges(n: Nat, +i: U32) -> List<&2, F.F64>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{F.F64.from_u32((i * 10486 : U32)), edges(p, (i + 1 : U32))}

def histogram.chk(ns: List<&2, U32>, +i: U32, acc: U32) -> F.F64:
  match ns:
    case Nil{}:
      F.F64.from_u32(acc)
    case Con{n, rest}:
      histogram.chk(rest, (i + 1 : U32), (acc + i * n : U32))

type Inputs is Data:
  Inputs{a: U32, b: U32}

def integer.random(n: Nat, +x: U32) -> List<&2, Inputs>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      +a = xs(x)
      +b = xs(a)
      Con{Inputs{a, b}, integer.random(p, b)}

def integer.fib(n: Nat, +a: U32, +b: U32, tail: List<&2, Inputs>) -> List<&2, Inputs>:
  match n:
    case 0n:
      tail
    case 1n+p:
      Con{Inputs{a, b}, integer.fib(p, b, (a + b : U32), tail)}

def integer.inputs(n: Nat) -> List<&2, Inputs>:
  Inputs{0, 0} <> Inputs{0, 4294967295} <> Inputs{4294967295, 0} <>
    Inputs{4294967295, 4294967295} <> Inputs{4294967295, 1} <>
    Inputs{65535, 65536} <> Inputs{65536, 65537} <> Inputs{12, 18} <>
    integer.fib(47n, 0, 1, integer.random(n, 44))

def integer.lcm.mark(r: Maybe<&2, U32>) -> U32:
  match r:
    case None{}:
      2654435769
    case Some{x}:
      x

def integer.lcm(a: U32, b: U32) -> U32:
  integer.lcm.mark(S.U32.lcm(a, b))

def integer.isqrt(a: U32, b: U32) -> U32:
  S.U32.isqrt(a)

def integer.sum(~f: U32 -> U32 -> U32, pairs: List<&2, Inputs>, acc: U32) -> U32:
  match pairs:
    case Nil{}:
      acc
    case Con{Inputs{a, b}, rest}:
      integer.sum(~f, rest, (acc + f(a, b) : U32))

def integer.line(op: String, t0: Time.Duration, t1: Time.Duration, checksum: U32) -> IO(Unit):
  IO.print(op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(checksum))

def integer.identity(a: U32, b: U32) -> U32:
  a

def packed.fill(pairs: List<&2, Inputs>, +i: U32, words: Array<U32>) -> Array<U32>:
  match pairs:
    case Nil{}:
      words
    case Con{Inputs{a, b}, rest}:
      words[i] <- a
      words[(i + 1 : U32)] <- b
      packed.fill(rest, (i + 2 : U32), words)

def packed.read.second(a: U32, r: Array<U32> & U32) -> Array<U32> & (U32 & U32):
  (words, b) = r
  (words, (a, b))

def packed.read.first(+i: U32, r: Array<U32> & U32) -> Array<U32> & (U32 & U32):
  (words, a) = r
  packed.read.second(a, words[(i + 1 : U32)])

def packed.read(words: Array<U32>, +i: U32) -> Array<U32> & (U32 & U32):
  packed.read.first(i, words[i])

def packed.sum.go(~f: U32 -> U32 -> U32, k: Nat, +i: U32, state: Array<U32> & (U32 & U32), acc: U32) -> Array<U32> & U32:
  match k:
    case 0n:
      (words, (a, b)) = state
      (words, acc)
    case 1n+p:
      (words, (a, b)) = state
      +next = (i + 2 : U32)
      packed.sum.go(~f, p, next, packed.read(words, next), (acc + f(a, b) : U32))

def packed.sum(~f: U32 -> U32 -> U32, count: Nat, words: Array<U32>) -> Array<U32> & U32:
  packed.sum.go(~f, count, 0, packed.read(words, 0), 0)

def packed.report(op: String, t0: Time.Duration, r: Array<U32> & U32) -> IO(Array<U32>):
  (words, checksum) = r
  do IO<Array<U32>>:
    t1 : Time.Duration <- Time.mono()
    integer.line(op, t0, t1, checksum)
    return words

def packed.time(~f: U32 -> U32 -> U32, op: String, count: Nat, words: Array<U32>) -> IO(Array<U32>):
  do IO<Array<U32>>:
    t0 : Time.Duration <- Time.mono()
    packed.report(op, t0, packed.sum(~f, count, words))

def packed.finish(r: Array<U32> & U32) -> IO(Unit):
  (words, first) = r
  IO.print("# packed keepalive " ++ U32.show(first))

def packed.run(+count: Nat, words: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    words : Array<U32> <- packed.time(~integer.identity, "packed_identity", count, words)
    words : Array<U32> <- packed.time(~(a => b => S.U32.gcd(a, b)), "packed_gcd", count, words)
    words : Array<U32> <- packed.time(~integer.lcm, "packed_lcm", count, words)
    words : Array<U32> <- packed.time(~integer.isqrt, "packed_isqrt", count, words)
    packed.finish(words[0])

def integer.diagnostic(+n: Nat) -> IO(Unit):
  +pairs = integer.inputs(n)
  +count = Nat.add(n, 55n)
  depth = {1n+U32.log2(U32.from_nat(Nat.double(count))) : Nat}
  words = packed.fill(pairs, 0, Array.new(U32, depth, 0))
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    a : U32 = integer.sum(~integer.identity, pairs, 0)
    t1 : Time.Duration <- Time.mono()
    integer.line("identity_shared", t0, t1, a)
    t2 : Time.Duration <- Time.mono()
    b : U32 = integer.sum(~(a => b => S.U32.gcd(a, b)), pairs, 0)
    t3 : Time.Duration <- Time.mono()
    integer.line("gcd_shared", t2, t3, b)
    t4 : Time.Duration <- Time.mono()
    c : U32 = integer.sum(~integer.lcm, pairs, 0)
    t5 : Time.Duration <- Time.mono()
    integer.line("lcm_shared", t4, t5, c)
    t6 : Time.Duration <- Time.mono()
    d : U32 = integer.sum(~integer.isqrt, pairs, 0)
    t7 : Time.Duration <- Time.mono()
    integer.line("isqrt_shared", t6, t7, d)
    t8 : Time.Duration <- Time.mono()
    e : U32 = integer.sum(~integer.identity, pairs, 0)
    t9 : Time.Duration <- Time.mono()
    integer.line("identity_release", t8, t9, e)
    packed.run(count, words)

def integer.run(+n: Nat) -> IO(Unit):
  +pairs = integer.inputs(n)
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    a : U32 = integer.sum(~(a => b => S.U32.gcd(a, b)), pairs, 0)
    t1 : Time.Duration <- Time.mono()
    integer.line("gcd", t0, t1, a)
    t2 : Time.Duration <- Time.mono()
    b : U32 = integer.sum(~integer.lcm, pairs, 0)
    t3 : Time.Duration <- Time.mono()
    integer.line("lcm", t2, t3, b)
    t4 : Time.Duration <- Time.mono()
    c : U32 = integer.sum(~integer.isqrt, pairs, 0)
    t5 : Time.Duration <- Time.mono()
    integer.line("isqrt", t4, t5, c)
    integer.diagnostic(n)

def integer.count.value(n: Maybe<&2, U32>) -> Nat:
  match n:
    case None{}:
      2097152n
    case Some{x}:
      U32.to_nat(x)

def integer.count(args: List<&1, String>) -> Nat:
  match args:
    case Con{program, Con{n, rest}}:
      integer.count.value(U32.read(n))
    case _:
      2097152n

def main() -> IO(Unit):
  +v = gen(10000n, 44)
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    +a : Maybe<&2, F.F64> = S.Stats.mean(v)
    t1 : Time.Duration <- Time.mono()
    line("mean", t0, t1, a)
    t2 : Time.Duration <- Time.mono()
    +b : Maybe<&2, F.F64> = S.Stats.variance(v)
    t3 : Time.Duration <- Time.mono()
    line("variance", t2, t3, b)
    t4 : Time.Duration <- Time.mono()
    +c : Maybe<&2, F.F64> = S.Stats.median(v)
    t5 : Time.Duration <- Time.mono()
    line("median", t4, t5, c)
    t6 : Time.Duration <- Time.mono()
    +d : F.F64 = histogram.chk(S.Stats.histogram(edges(101n, 0), v), 1, 0)
    t7 : Time.Duration <- Time.mono()
    line("histogram", t6, t7, Some{d})
    args : List<&1, String> <- IO.args()
    integer.run(integer.count(args))
