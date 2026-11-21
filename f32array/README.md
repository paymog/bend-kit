# f32array

Packed `F32` arrays with affine ownership. Each `Array` slot is a `Cell` of eight `F32` values, so one array access reads or writes eight elements. Use it for model weights, feature rows, and other numeric buffers.

```bend
import Base
import bend-kit-f32array@0.2.1.0/f32array.bend as A

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

The pure module imports `bend-kit-bytes@0.3.3.0`. `io.bend` also imports `bend-kit-files@0.4.0.0`. `from_bytes.le`, `to_bytes.le`, and their `.be` twins take and give that `Bytes.Bytes`.

A call that reads an array returns the array beside its result. Pass that array on. `get` returns `None` when the index is at or past `len`, and `set` then leaves the array unchanged. `map` and `zip_with` write into the array they are given. `zip_with`, `add`, and `mul` give `b` back, and they return `False` with both arrays unchanged when the two lengths differ. `dot` returns `None` when the lengths differ.

`sum` and `dot` add each eight-lane cell pairwise. They add at most 16 cell totals in a sequential leaf, then combine equal halves of the padded cell tree pairwise. This bounds the sequential part to 128 elements rather than the whole input. The order differs from the former four running sums. Rounding, overflow, signed zero, and NaN payloads can therefore change. Empty inputs return `+0.0`. `dot` rounds each product to `F32` before adding it.

For CPU parallelism, import `bend-kit-f32array@0.2.1.0/parallel.bend as P` and call `P.sum(a)` or `P.dot(a, b)`. They return the same types and use the same addition order as the pure calls. Below 2^20 elements they stay sequential. Larger inputs split into read-only tasks of at most 4,096 cells (32,768 elements). `Array.fork` shares each buffer without cloning it. Every pair of returned handles is joined before the caller can write again. These Base operations are unsafe, so the parallel module must not enter proof imports. Native binaries use `+RTS --threads 8` to select eight CPU workers. The JS target stays sequential.

`P.sum.with_cutoff(a, cells)` and `P.dot.with_cutoff(a, b, cells)` expose the task cutoff for measurements or a different machine. The cutoff is at least 16 cells. These calls do not apply the default 2^20-element threshold. Their results keep the same bits at every cutoff and worker count. See [the benchmark](bench/README.md) for the measured cutoff and float64 errors.

`max` keeps four running maxima with Base `F32.max`, all started at `a[0]`, so a NaN is kept only when it is the first element. `fold` goes left to right, one element at a time.

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
| `F.read.le(file: File) -> IO(File & Result<&1, &1, U32 & String, F32Array>)` | In `io.bend`. The rest of an open file, as for `from_bytes.le`. It fails with errno 22 when the size is not a multiple of 4. |
| `F.read.le.at(file, hi: U32, lo: U32, n: U32)` | Exactly `n` little-endian F32 elements at byte offset `hi * 2^32 + lo`. Same return type as `F.read.le`. |
| `F.read.bf16.at(file, hi: U32, lo: U32, n: U32)` | Exactly `n` little-endian BF16 elements at that offset. Each 16-bit value becomes the top 16 bits of its F32 value. |

The `.at` calls keep the file position unchanged. They read in chunks of at most 1 MiB into one output array and carry partial elements across short reads. Unexpected EOF fails with errno 5 rather than returning a partial tensor. Errors retain the file handle. Byte offsets need no alignment. The byte count must be at most 4,294,967,292 (`n <= 1,073,741,823` for F32 or `2,147,483,646` for BF16). The offset and its exclusive end must be below 2^63. Invalid ranges fail with errno 22 before allocation. A zero-element request returns an empty array without reading.

Native F32 and BF16 loads preserve all bits, including signed zero, subnormals, and NaN sign and payload. The JS lane canonicalizes NaN bits, including for the existing `from_bytes.le` path. This is a [Bend runtime limit](https://github.com/bendlang/bend/issues/1419), not a rounding step in BF16 widening.

`from_bytes.be`, `to_bytes.be`, and `F.read.be` are the big-endian twins. File reads moved to `io.bend` so the pure module and its proofs import no effects. A little-endian file of `float32` values, such as NumPy's `a.astype('<f4').tofile(path)` writes, loads with `F.read.le`:

```bend
import Base
import bend-kit-f32array@0.2.1.0/f32array.bend as A
import bend-kit-f32array@0.2.1.0/io.bend as F

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
    got : File & Result<&1, &1, U32 & String, A.F32Array> <- F.read.le(f)
    report(got)
```

`io.bend` calls `files` effects. The proofs do not cover these effects or `parallel.bend`. `LAWS.bend` states universal get-after-set, lane-after-put, and little-endian array-to-Bytes-to-array laws. The Bytes law requires `len < 2^30` and compares element lists with Bend's structural equality. It includes NaNs; it does not claim that arbitrary input Bytes retain NaN payloads on JS. Other laws remain fixtures, including two-cell arrays and zero padding past `len`. `check.bend` checks arithmetic, the 49,152-term precision case, forced parallel splits, partial cells, retained writable handles, empty inputs, length mismatches, and a file read. Run `scripts/check.sh f32array`. Compile `check.bend` and run it with one and eight threads to exercise native fork-join.

Run `python3 f32array/test_tensor.py` from the repo root to check NumPy-written F32 and BF16 data on native and Bun. It creates a temporary sparse file with offsets above 4 GiB. It checks unaligned offsets, low-word carry, exact tensor lengths, signed zero, subnormals, infinities, cursor retention, short-element decoding, EOF, invalid ranges, and reuse after failure. Native-only checks cover NaN sign and payload. The runner needs NumPy and Bun.
