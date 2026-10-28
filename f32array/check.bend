import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-files@0.3.0.0/files.bend as Files
import ./f32array.bend as A

# The laws cannot run F32 arithmetic in the checker. This runs it natively, and at sizes the checker would not reach.

def expect(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def has(m: Maybe<&2, F32>, +v: F32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{x}:
      F32.is_eq(x, v)

def value(r: A.F32Array & Maybe<&2, F32>) -> Maybe<&2, F32>:
  (a, x) = r
  x

def total(r: A.F32Array & F32) -> F32:
  (a, x) = r
  x

def product(r: A.F32Array & A.F32Array & Maybe<&2, F32>) -> Maybe<&2, F32>:
  (a, b, x) = r
  x

def at(m: Maybe<&1, A.F32Array>, +i: U32) -> Maybe<&2, F32>:
  match m:
    case None{}:
      None{}
    case Some{a}:
      value(A.get(a, i))

def zipped(r: A.F32Array & A.F32Array & Bool, +i: U32) -> Maybe<&2, F32>:
  (a, b, ok) = r
  match ok:
    case True{}:
      value(A.get(a, i))
    case False{}:
      None{}

def ramp.go(n: Nat, a: A.F32Array, +i: U32, +k: U32) -> A.F32Array:
  match n:
    case 0n:
      a
    case 1n+p:
      ramp.go(p, A.set(a, i, U32.to_f32((((i * k) + 3 : U32) .&. 7 : U32))), (i + 1 : U32), k)

# n elements, element i = (i * k + 3) & 7: small integers, so every sum below is exact.
def ramp(+n: U32, +k: U32) -> A.F32Array:
  ramp.go(U32.to_nat(n), A.new(n), 0, k)

def twice(x: F32) -> F32:
  (x * 2.0 : F32)

def plus1(x: F32) -> F32:
  (x + 1.0 : F32)

def neg(x: F32) -> F32:
  F32.neg(x)

def big.sum(+n: U32) -> F32:
  total(A.sum(ramp(n, 1)))

def big.dot(+n: U32) -> Maybe<&2, F32>:
  product(A.dot(ramp(n, 1), ramp(n, 5)))

def big.roundtrip(+n: U32) -> Maybe<&2, F32>:
  at(A.from_bytes.be(A.to_bytes.be(A.map(~twice, ramp(n, 1)))), (n - 1 : U32))

def wrote(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (f, x) = r
  do IO<Unit>:
    File.close(f)
    IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, x))

def loaded(r: File & Result<&1, &1, U32 & String, A.F32Array>) -> IO(A.F32Array):
  (f, x) = r
  do IO<A.F32Array>:
    File.close(f)
    IO.try(A.F32Array, IO.pure(Result<&1, &1, U32 & String, A.F32Array>, x))

def main() -> IO(Unit):
  +n = {300003 : U32}
  do IO<Unit>:
    expect("add", has(zipped(A.add(A.from_list([1.0, 2.5]), A.from_list([0.5, 0.25])), 1), 2.75))
    expect("mul", has(zipped(A.mul(A.from_list([1.5, 2.0]), A.from_list([2.0, 0.25])), 0), 3.0))
    expect("sum", F32.is_eq(total(A.sum(A.from_list([1.0, 2.5, 0.5]))), 4.0))
    expect("dot", has(product(A.dot(A.from_list([1.0, 2.0, 3.0]), A.from_list([4.0, 5.0, 6.0]))), 32.0))
    expect("max", has(value(A.max(A.from_list([1.0, 7.5, 2.0]))), 7.5))
    expect("sum_empty", F32.is_eq(total(A.sum(A.new(0))), 0.0))
    expect("dot_empty", has(product(A.dot(A.new(0), A.new(0))), 0.0))
    expect("sum_partial", F32.is_eq(total(A.sum(A.map(~plus1, A.new(11)))), 11.0))
    expect("max_negative", has(value(A.max(A.map(~neg, A.from_list([3.0, 1.0, 2.0, 5.0, 4.0, 6.0, 7.0, 9.0, 8.0, 2.5])))), F32.neg(1.0)))
    expect("max_tail", has(value(A.max(A.map(~neg, A.from_list([3.0, 4.0, 2.0, 5.0, 4.0, 6.0, 7.0, 9.0, 8.0, 0.5])))), F32.neg(0.5)))
    expect("max_full_cell", has(value(A.max(A.map(~neg, A.from_list([3.0, 4.0, 2.0, 5.0, 4.0, 0.25, 7.0, 9.0])))), F32.neg(0.25)))
    expect("big_max", has(value(A.max(ramp(n, 1))), 7.0))
    expect("max_one", has(value(A.max(A.from_list([0.25]))), 0.25))
    # n is not a multiple of 8, so the last cell is partial; every sum is an exact integer.
    expect("big_sum", F32.is_eq(big.sum(n), 1050012.0))
    expect("big_dot", has(big.dot(n), 4050034.0))
    expect("big_roundtrip", has(big.roundtrip(n), 10.0))
    +dir : String <- IO.try(String, Files.temp_dir())
    +path : String = dir ++ "/f32.bin"
    w : File <- IO.try(File, File.open(path, "w"))
    wr : File & Result<&1, &1, U32 & String, Unit> <- Files.write_bytes(w, A.to_bytes.le(ramp(n, 1)))
    wrote(wr)
    r : File <- IO.try(File, File.open(path, "r"))
    got : File & Result<&1, &1, U32 & String, A.F32Array> <- A.read.le(r)
    a : A.F32Array <- loaded(got)
    expect("read_le", F32.is_eq(total(A.sum(a)), 1050012.0))
    rm1 : Unit <- IO.try(Unit, Files.remove(path))
    rm2 : Unit <- IO.try(Unit, Files.remove(dir))
    return Unit{}
