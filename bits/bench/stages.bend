import Base
import ./bench.bend as Bench
import ./build.bend as Build
import ./profile.bend as Profile
import ../bits.bend as Bits
import ../../time/time.bend as Time

def codes(u: Unit) -> List<&2, Bits.Code>:
  Bits.codes(Build.lens(), 0)

def count(xs: List<&2, Bits.Code>) -> Array<U32>:
  Bits.count(xs, Array.new(U32, 5n, 0))

def counts(u: Unit) -> Array<U32>:
  count(codes(u))

def next(c: Array<U32>) -> Array<U32> & Bool:
  Bits.next.go(17n, 1, 0, 1, True{}, Array.new(U32, 5n, 0), Array.get(U32, c, 0))

def starts(r: Array<U32> & Bool) -> Array<U32>:
  (n, ok) = r
  n

def reserve.input(u: Unit) -> List<&2, Bits.Code> & Array<U32>:
  (codes(u), starts(next(counts(Unit{}))))

def reserve(r: List<&2, Bits.Code> & Array<U32>) -> Array<U32> & Array<U32> & Array<U32>:
  (xs, n) = r
  Profile.reserved(xs, 15, Array.clone(U32, n))

def assign.input(u: Unit) -> List<&2, Bits.Code> & (Array<U32> & Array<U32> & Array<U32>):
  (codes(u), reserve(reserve.input(Unit{})))

def assign(r: List<&2, Bits.Code> & (Array<U32> & Array<U32> & Array<U32>)) -> Bits.Huff:
  (xs, state) = r
  Bits.build.done(False{}, 15, Bits.assign.two(xs, False{}, 9, 15, state))

def sum.codes(xs: List<&2, Bits.Code>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{Bits.Code{sym, len}, tail}:
      sum.codes(tail, (acc + sym + len : U32))

def consume.codes(xs: List<&2, Bits.Code>) -> U32:
  sum.codes(xs, 0)

def consume.scalar(n: U32) -> U32:
  n

def consume.array(a: Array<U32>) -> U32:
  Profile.batch.entry(Array.get(U32, a, 8))

def consume.next(r: Array<U32> & Bool) -> U32:
  (n, ok) = r
  (Profile.batch.entry(Array.get(U32, n, 15)) + Bool.pick(U32, ok, 1, 0) : U32)

def consume.reserve(r: Array<U32> & Array<U32> & Array<U32>) -> U32:
  (n, table, sub) = r
  (Profile.batch.entry(Array.get(U32, n, 15)) + Profile.batch.entry(Array.get(U32, table, 511)) + Profile.batch.entry(Array.get(U32, sub, 0)) : U32)

def consume.assign(h: Bits.Huff) -> U32:
  Profile.batch.code(Some{h})

def retained(~O: Type, ~op: List<&2, Bits.Code> -> O, +xs: List<&2, Bits.Code>) -> List<&2, Bits.Code> & O:
  (xs, op(xs))

def retained.reserve(r: List<&2, Bits.Code> & Array<U32>) -> List<&2, Bits.Code> & (Array<U32> & Array<U32> & Array<U32>):
  (+xs, n) = r
  (xs, reserve((xs, n)))

def retained.assign(r: List<&2, Bits.Code> & (Array<U32> & Array<U32> & Array<U32>)) -> List<&2, Bits.Code> & Bits.Huff:
  (+xs, state) = r
  (xs, assign((xs, state)))

def consume.retained(~O: Type, ~consume: O -> U32, r: List<&2, Bits.Code> & O) -> U32:
  (xs, value) = r
  (consume.codes(xs) + consume(value) : U32)

def prepare(~T: Type, ~make: Unit -> T, k: Nat) -> List<T>:
  match k:
    case 0n:
      Nil{}
    case 1n+p:
      Con{make(Unit{}), prepare(~T, ~make, p)}

def loop(~I: Type, ~O: Type, ~op: I -> O, ~consume: O -> U32, xs: List<I>, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{x, tail}:
      loop(~I, ~O, ~op, ~consume, tail, (acc + consume(op(x)) : U32))

def checked(ok: Bool, name: String, t0: Time.Duration, t1: Time.Duration, sum: U32) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "stage checksum mismatch: " ++ name)
    case True{}:
      Bench.lap(name, t0, t1, sum)

def sample(~I: Type, ~O: Type, ~make: Unit -> I, ~op: I -> O, ~consume: O -> U32, +k: Nat, +name: String, +expected: U32) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    inputs : List<I> = prepare(~I, ~make, k)
    +t1 : Time.Duration <- Time.mono()
    +sum : U32 = loop(~I, ~O, ~op, ~consume, inputs, 0)
    t2 : Time.Duration <- Time.mono()
    checked(U32.is_eq(sum, expected), name ++ "-prepare", t0, t1, sum)
    checked(U32.is_eq(sum, expected), name, t1, t2, sum)
    outputs : List<O> = prepare(~O, ~(u => op(make(u))), k)
    t3 : Time.Duration <- Time.mono()
    +control : U32 = loop(~O, ~O, ~(x => x), ~consume, outputs, 0)
    t4 : Time.Duration <- Time.mono()
    checked(U32.is_eq(control, expected), name ++ "-consume", t3, t4, control)

def repeat(k: Nat, +n: Nat, +scale: U32) -> IO(Unit):
  match k:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        c0 : Time.Duration <- Time.mono()
        c1 : Time.Duration <- Time.mono()
        Bench.lap("clock", c0, c1, 0)
        sample(~List<&2, U32>, ~List<&2, Bits.Code>, ~(u => Build.lens()), ~(xs => Bits.codes(xs, 0)), ~consume.codes, n, "codes", (scale * 36592 : U32))
        sample(~List<&2, Bits.Code>, ~(List<&2, Bits.Code> & U32), ~codes, ~(xs => retained(~U32, ~(cs => Bits.lens.max(cs, 0)), xs)), ~(r => consume.retained(~U32, ~consume.scalar, r)), n, "maximum", (scale * 36607 : U32))
        sample(~List<&2, Bits.Code>, ~(List<&2, Bits.Code> & Array<U32>), ~codes, ~(xs => retained(~Array<U32>, ~count, xs)), ~(r => consume.retained(~Array<U32>, ~consume.array, r)), n, "count", (scale * 36847 : U32))
        sample(~Array<U32>, ~(Array<U32> & Bool), ~counts, ~next, ~consume.next, n, "next", (scale * 32767 : U32))
        sample(~(List<&2, Bits.Code> & Array<U32>), ~(List<&2, Bits.Code> & (Array<U32> & Array<U32> & Array<U32>)), ~reserve.input, ~retained.reserve, ~(r => consume.retained(~(Array<U32> & Array<U32> & Array<U32>), ~consume.reserve, r)), n, "reserve", (scale * 69389 : U32))
        sample(~(List<&2, Bits.Code> & (Array<U32> & Array<U32> & Array<U32>)), ~(List<&2, Bits.Code> & Bits.Huff), ~assign.input, ~retained.assign, ~(r => consume.retained(~Bits.Huff, ~consume.assign, r)), n, "assign", (scale * 36600 : U32))
        t0 : Time.Duration <- Time.mono()
        +sum : U32 = Profile.batch.loop(n, 0)
        t1 : Time.Duration <- Time.mono()
        checked(U32.is_eq(sum, (scale * 8 : U32)), "complete", t0, t1, sum)
        repeat(p, n, scale)

def main() -> IO(Unit):
  repeat(10n, 1000n, 1000)
