import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-files@0.4.0.1/files.bend as Files
import ./f32array.bend as A
import ./io.bend as F

def expect(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "FAIL tensor read")

def bits(xs: List<&2, F32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      Bool.and(U32.is_eq(A.to_bits(x), y), bits(xt, yt))
    case Nil{} Con{y, yt}:
      False{}
    case Con{x, xt} Nil{}:
      False{}

def result(r: Result<&1, &1, U32 & String, A.F32Array>, expected: List<&2, U32>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{a}:
      bits(A.to_list(a), expected)

def word(pair: Array<U32> & U32) -> U32:
  (words, value) = pair
  value

def cursor.bytes(got: U32 & Array<U32>) -> Bool:
  (n, words) = got
  Bool.and(U32.is_eq(n, 3), U32.is_eq(word(Array.get(U32, words, 0)), 197121))

def cursor(pair: File & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  (f, r) = pair
  do IO<Unit>:
    File.close(f)
    got : U32 & Array<U32> <- IO.try(U32 & Array<U32>, IO.pure(Result<&1, &1, U32 & String, U32 & Array<U32>>, r))
    expect(cursor.bytes(got))

def read.done(pair: File & Result<&1, &1, U32 & String, A.F32Array>, expected: List<&2, U32>) -> IO(Unit):
  (f, r) = pair
  do IO<Unit>:
    expect(result(r, expected))
    pair : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Files.read.words(f, 3)
    cursor(pair)

def read(~reader: File -> U32 -> U32 -> U32 -> IO(File & Result<&1, &1, U32 & String, A.F32Array>), +hi: U32, +lo: U32, +n: U32, expected: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("tensor-fixture.bin", "r"))
    pair : File & Result<&1, &1, U32 & String, A.F32Array> <- reader(f, hi, lo, n)
    read.done(pair, expected)

def failed(r: Result<&1, &1, U32 & String, A.F32Array>, +code: U32) -> Bool:
  match r:
    case Fail{(errno, text)}:
      U32.is_eq(errno, code)
    case Done{a}:
      False{}

def failure.done(pair: File & Result<&1, &1, U32 & String, A.F32Array>, code: U32) -> IO(Unit):
  (f, r) = pair
  do IO<Unit>:
    expect(failed(r, code))
    pair : File & Result<&1, &1, U32 & String, A.F32Array> <- F.read.le.at(f, 0, 3, 1)
    read.done(pair, [0])

def failure(hi: U32, lo: U32, n: U32, code: U32) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("tensor-fixture.bin", "r"))
    pair : File & Result<&1, &1, U32 & String, A.F32Array> <- F.read.le.at(f, hi, lo, n)
    failure.done(pair, code)

def patterns() -> List<&2, U32>:
  [0, 2147483648, 1065353216, 3221225472, 65536, 8323072, 2139095040, 4286578688, 2143354880, 4286775296, 2139029504, 8388608, 1056964608]

def partial.done(state: F.Tensor) -> Bool:
  F.Tensor{a, carry, used, index} = state
  bits(A.to_list(a), [1065353216, 2147549184])

def partial() -> Bool:
  partial.done(F.tensor.take(F.tensor.take(F.tensor.take(F.tensor.take(F.Tensor{A.new(2), 0, 0, 0}, 2, 128), 2, 63), 2, 1), 2, 128))

def native(enabled: Bool) -> IO(Unit):
  match enabled:
    case True{}:
      do IO<Unit>:
        read(~F.read.le.at, 0, 3, 13, patterns())
        read(~F.read.bf16.at, 0, 100, 13, patterns())
        IO.print("ok native NaN sign and payload")
    case False{}:
      IO.pure(Unit, Unit{})

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    native(List.is_empty(&1, String, List.tail(&1, String, args)))
    read(~F.read.le.at, 0, 3, 8, [0, 2147483648, 1065353216, 3221225472, 65536, 8323072, 2139095040, 4286578688])
    read(~F.read.bf16.at, 0, 100, 8, [0, 2147483648, 1065353216, 3221225472, 65536, 8323072, 2139095040, 4286578688])
    read(~F.read.le.at, 0, 4294967293, 8, [0, 2147483648, 1065353216, 3221225472, 65536, 8323072, 2139095040, 4286578688])
    read(~F.read.bf16.at, 1, 100, 8, [0, 2147483648, 1065353216, 3221225472, 65536, 8323072, 2139095040, 4286578688])
    read(~F.read.le.at, 0, 43, 3, [2139029504, 8388608, 1056964608])
    read(~F.read.bf16.at, 0, 120, 3, [2139029504, 8388608, 1056964608])
    read(~F.read.le.at, 0, 3, 1, [0])
    read(~F.read.le.at, 1, 1000, 0, [])
    failure(1, 125, 1, 5)
    failure(1, 126, 1, 5)
    failure(2147483648, 0, 0, 22)
    failure(2147483647, 4294967295, 1, 22)
    failure(0, 0, 1073741824, 22)
    expect(partial())
    IO.print("ok tensor offset, BF16 bits, cursor, EOF, limits, retained handles")
