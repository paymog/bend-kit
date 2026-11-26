import Base
import ./bench.bend as Bench
import ./build.bend as Build
import ../bits.bend as Bits
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

def reserved.done(n: Array<U32>, r: Array<U32> & U32) -> Array<U32> & Array<U32> & Array<U32>:
  (table, +used) = r
  (n, table, Array.new(U32, Bits.depth(16n, used, 0n), 0))

def reserved(+xs: List<&2, Bits.Code>, +max: U32, pair: Array<U32> & Array<U32>) -> Array<U32> & Array<U32> & Array<U32>:
  (n, copy) = pair
  reserved.done(n, Bits.reserve(xs, False{}, 9, max, (copy, Array.new(U32, 9n, 0), 0)))

def assign(+xs: List<&2, Bits.Code>, +max: U32, n: Array<U32>, b: Bytes.Bytes, +t0: Time.Duration, +t1: Time.Duration, +t2: Time.Duration, +t3: Time.Duration, +t4: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    state : Array<U32> & Array<U32> & Array<U32> = reserved(xs, max, Array.clone(U32, n))
    +t5 : Time.Duration <- Time.mono()
    h : Bits.Huff = Bits.build.done(False{}, max, Bits.assign.two(xs, False{}, 9, max, state))
    +t6 : Time.Duration <- Time.mono()
    +sum : U32 = Bench.lits(h, b)
    t7 : Time.Duration <- Time.mono()
    clock0 : Time.Duration <- Time.mono()
    clock1 : Time.Duration <- Time.mono()
    Bench.lap("clock", clock0, clock1, sum)
    Bench.lap("codes", t0, t1, sum)
    Bench.lap("maximum", t1, t2, sum)
    Bench.lap("count", t2, t3, sum)
    Bench.lap("next", t3, t4, sum)
    Bench.lap("reserve", t4, t5, sum)
    Bench.lap("assign", t5, t6, sum)
    Bench.lap("build", t0, t6, sum)
    Bench.lap("decode", t6, t7, sum)

def checked.if(ok: Bool, xs: List<&2, Bits.Code>, max: U32, n: Array<U32>, b: Bytes.Bytes, t0: Time.Duration, t1: Time.Duration, t2: Time.Duration, t3: Time.Duration, t4: Time.Duration) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "invalid profile fixture")
    case True{}:
      assign(xs, max, n, b, t0, t1, t2, t3, t4)

def checked(state: Array<U32> & Bool, xs: List<&2, Bits.Code>, +max: U32, b: Bytes.Bytes, t0: Time.Duration, t1: Time.Duration, t2: Time.Duration, t3: Time.Duration, t4: Time.Duration) -> IO(Unit):
  (n, valid) = state
  checked.if(Bool.and(valid, U32.is_le(max, 16)), xs, max, n, b, t0, t1, t2, t3, t4)

def repeat(k: Nat, +s: String) -> IO(Unit):
  match k:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        b : Bytes.Bytes = Bytes.from_string(s)
        lens : List<&2, U32> = Build.lens()
        t0 : Time.Duration <- Time.mono()
        +xs : List<&2, Bits.Code> = Bits.codes(lens, 0)
        t1 : Time.Duration <- Time.mono()
        +max : U32 = Bits.lens.max(xs, 0)
        t2 : Time.Duration <- Time.mono()
        counts : Array<U32> = Bits.count(xs, Array.new(U32, 5n, 0))
        t3 : Time.Duration <- Time.mono()
        state : Array<U32> & Bool = Bits.next.go(17n, 1, 0, 1, True{}, Array.new(U32, 5n, 0), Array.get(U32, counts, 0))
        t4 : Time.Duration <- Time.mono()
        checked(state, xs, max, b, t0, t1, t2, t3, t4)
        repeat(p, s)

def batch.entry(r: Array<U32> & U32) -> U32:
  (table, entry) = r
  entry

def batch.code(m: Maybe<&1, Bits.Huff>) -> U32:
  match m:
    case None{}:
      0
    case Some{Bits.Huff{msb, max, table, sub}}:
      batch.entry(Array.get(U32, table, 0))

def batch.loop(k: Nat, acc: U32) -> U32:
  match k:
    case 0n:
      acc
    case 1n+p:
      batch.loop(p, (acc + batch.code(Bits.Huff.from_lens(False{}, Build.lens())) : U32))

def batch.checked(ok: Bool, t0: Time.Duration, t1: Time.Duration, sum: U32) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "batch build checksum mismatch")
    case True{}:
      Bench.lap("batch1000", t0, t1, sum)

def batch(k: Nat) -> IO(Unit):
  match k:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        t0 : Time.Duration <- Time.mono()
        +sum : U32 = batch.loop(1000n, 0)
        t1 : Time.Duration <- Time.mono()
        batch.checked(U32.is_eq(sum, 8000), t0, t1, sum)
        batch(p)

def read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    repeat(100n, Bench.from_bytes(Bench.bytes.of(r)))
    batch(10n)

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "cannot open profile input")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 65536)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open("out/short.bin", "r")
    opened(r)
