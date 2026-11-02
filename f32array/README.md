# f32array

Packed `F32` arrays with affine ownership. Each `Array` slot is a `Cell` of eight `F32` values, so one array access reads or writes eight elements. Use it for model weights, feature rows, and other numeric buffers.

```bend
import Base
import bend-kit-f32array@0.1.0.0/f32array.bend as A

def show(r: A.F32Array & A.F32Array & Maybe<&2, F32>) -> IO(Unit):
  (a, b, d) = r
  match d:
    case None{}:
      IO.print("lengths differ")
    case Some{x}:
      IO.print(F32.show(x))

def main() -> IO(Unit):
  show(A.dot(A.from_list([1.0, 2.0, 3.0]), A.from_list([4.0, 5.0, 6.0])))
```

This package imports `bend-kit-bytes@0.3.3.0` and `bend-kit-files@0.3.0.0`. `from_bytes.le`, `to_bytes.le`, and their `.be` twins take and give that `Bytes.Bytes`.

A call that reads an array returns the array beside its result. Pass that array on. `get` returns `None` when the index is at or past `len`, and `set` then leaves the array unchanged. `map` and `zip_with` write into the array they are given. `zip_with`, `add`, and `mul` give `b` back, and they return `False` with both arrays unchanged when the two lengths differ. `dot` returns `None` when the lengths differ.

`sum` and `dot` keep four running sums: element `i` goes to sum `i % 4`, and the result is `(s0 + s1) + (s2 + s3)`. The order is fixed, so every run gives the same bits, but it is not the order of one running sum. Rounding error still grows with the length. NumPy's `sum` adds pairwise and is more accurate on long arrays. `max` keeps four running maxima with Base `F32.max`, all started at `a[0]`, so a NaN is kept only when it is the first element. `fold` goes left to right, one element at a time.

| def | returns |
|---|---|
| `new(n: U32) -> F32Array` | `n` zeros. |
| `from_list(xs: List<&2, F32>) -> F32Array` | The elements in order. |
| `to_list(a: F32Array) -> List<&2, F32>` | The elements in order. The call consumes the array. |
| `length(a) -> F32Array & U32` | The element count. |
| `get(a, i: U32) -> F32Array & Maybe<&2, F32>` | Element `i`, or `None`. |
| `set(a, i: U32, v: F32) -> F32Array` | The array with element `i` set to `v`. |
| `slice(a, start: U32, n: U32) -> F32Array & F32Array` | The array, and a copy of up to `n` elements from `start`. Both ends are clamped to `len`. |
| `concat(xs: List<&1, F32Array>) -> F32Array` | The pieces in order, in one new array. |
| `map(~f: F32 -> F32, a) -> F32Array` | `f` on each element, in place. |
| `fold(~A, ~f: A -> F32 -> A, a, init: A) -> F32Array & A` | `f` over the elements from the left. |
| `zip_with(~f: F32 -> F32 -> F32, a, b) -> F32Array & F32Array & Bool` | `f(a[i], b[i])` written into `a`, then `b`, then `True`. |
| `add(a, b)`, `mul(a, b) -> F32Array & F32Array & Bool` | `a[i] + b[i]` or `a[i] * b[i]`, as for `zip_with`. |
| `dot(a, b) -> F32Array & F32Array & Maybe<&2, F32>` | Both arrays, and the sum of `a[i] * b[i]`. |
| `sum(a) -> F32Array & F32` | The sum, from `+0.0`. |
| `max(a) -> F32Array & Maybe<&2, F32>` | The largest element, or `None` when empty. |
| `from_bytes.le(b: Bytes.Bytes) -> Maybe<&1, F32Array>` | Four bytes per element, least significant first. `None` when the length is not a multiple of 4. |
| `to_bytes.le(a) -> Bytes.Bytes` | Four bytes per element, least significant first. `len` must be below 2^30. |
| `read.le(file: File) -> IO(File & Result<&1, &1, U32 & String, F32Array>)` | The rest of an open file, as for `from_bytes.le`. It fails with errno 22 when the size is not a multiple of 4. |

`from_bytes.be`, `to_bytes.be`, and `read.be` are the big-endian twins. A little-endian file of `float32` values, such as NumPy's `a.astype('<f4').tofile(path)` writes, loads with `read.le`:

```bend
def count(r: A.F32Array & U32) -> String:
  (a, n) = r
  U32.show(n)

def report(r: File & Result<&1, &1, U32 & String, A.F32Array>) -> IO(Unit):
  (f, x) = r
  do IO<Unit>:
    File.close(f)
    a : A.F32Array <- IO.try(A.F32Array, IO.pure(Result<&1, &1, U32 & String, A.F32Array>, x))
    IO.print(count(A.length(a)))

def main() -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open("weights.bin", "r"))
    got : File & Result<&1, &1, U32 & String, A.F32Array> <- A.read.le(f)
    report(got)
```

`read.le` and `read.be` call `files` effects. The proofs do not cover them. The laws in `LAWS.bend` are fixtures, because the checker does not run `F32` arithmetic. They include arrays that span two cells and check that the lanes past `len` stay `+0.0`. `check.bend` runs the arithmetic natively on 300,003 elements, which ends in a partial cell, and reads a file back. Run `scripts/check.sh f32array`.
