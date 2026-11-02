# Packed F32 arrays: get, set, slice, concat, map, fold, zip, dot, sum, max, and little- or big-endian Bytes and files. Source: https://github.com/paymog/bend-kit/tree/main/f32array
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-files@0.3.0.0/files.bend as Files

# Eight elements per Array slot, so one access reads or writes eight.
type Cell is Data:
  Cell{v0: F32, v1: F32, v2: F32, v3: F32, v4: F32, v5: F32, v6: F32, v7: F32}

# Element i is lane i % 8 of cell i / 8. buf has the fewest 2^d cells that hold len elements, and every lane at or past len is +0.0.
type F32Array is Type:
  F32Array{len: U32, buf: Array<Cell>}

def of_bits(x: U32) -> F32:
  match x:
    case U32{w}:
      F32{w}

def to_bits(x: F32) -> U32:
  match x:
    case F32{w}:
      U32{w}

def of_bits.be(x: U32) -> F32:
  +y = x
  of_bits(Bytes.bswap(y))

def to_bits.be(x: F32) -> U32:
  Bytes.bswap(to_bits(x))

def zero() -> Cell:
  Cell{0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}

def cells(+n: U32) -> U32:
  ((n + 7 : U32) >> 3n : U32)

def alloc(+n: U32) -> Array<Cell>:
  Array.new(Cell, Bytes.depth(cells(n)), zero())

# Lane k, for k < 8.
def lane(c: Cell, +k: U32) -> F32:
  Cell{v0, v1, v2, v3, v4, v5, v6, v7} = c
  Bool.pick(F32, U32.is_lt(k, 4), Bool.pick(F32, U32.is_lt(k, 2), Bool.pick(F32, U32.is_eq(k, 0), v0, v1), Bool.pick(F32, U32.is_eq(k, 2), v2, v3)), Bool.pick(F32, U32.is_lt(k, 6), Bool.pick(F32, U32.is_eq(k, 4), v4, v5), Bool.pick(F32, U32.is_eq(k, 6), v6, v7)))

def put(c: Cell, +k: U32, +v: F32) -> Cell:
  Cell{v0, v1, v2, v3, v4, v5, v6, v7} = c
  Cell{Bool.pick(F32, U32.is_eq(k, 0), v, v0), Bool.pick(F32, U32.is_eq(k, 1), v, v1), Bool.pick(F32, U32.is_eq(k, 2), v, v2), Bool.pick(F32, U32.is_eq(k, 3), v, v3), Bool.pick(F32, U32.is_eq(k, 4), v, v4), Bool.pick(F32, U32.is_eq(k, 5), v, v5), Bool.pick(F32, U32.is_eq(k, 6), v, v6), Bool.pick(F32, U32.is_eq(k, 7), v, v7)}

# Lanes at or past k become +0.0.
def mask(c: Cell, +k: U32) -> Cell:
  Cell{v0, v1, v2, v3, v4, v5, v6, v7} = c
  Cell{Bool.pick(F32, U32.is_lt(0, k), v0, 0.0), Bool.pick(F32, U32.is_lt(1, k), v1, 0.0), Bool.pick(F32, U32.is_lt(2, k), v2, 0.0), Bool.pick(F32, U32.is_lt(3, k), v3, 0.0), Bool.pick(F32, U32.is_lt(4, k), v4, 0.0), Bool.pick(F32, U32.is_lt(5, k), v5, 0.0), Bool.pick(F32, U32.is_lt(6, k), v6, 0.0), Bool.pick(F32, U32.is_lt(7, k), v7, 0.0)}

# Unchecked element read and write. Callers keep i below len.
def peek.of(+k: U32, r: Array<Cell> & Cell) -> Array<Cell> & F32:
  (a, c) = r
  (a, lane(c, k))

def peek(a: Array<Cell>, +i: U32) -> Array<Cell> & F32:
  peek.of((i .&. 7 : U32), Array.get(Cell, a, (i >> 3n : U32)))

def poke.of(+i: U32, +v: F32, r: Array<Cell> & Cell) -> Array<Cell>:
  (a, c) = r
  Array.set(Cell, a, (i >> 3n : U32), put(c, (i .&. 7 : U32), v))

def poke(a: Array<Cell>, +i: U32, +v: F32) -> Array<Cell>:
  poke.of(i, v, Array.get(Cell, a, (i >> 3n : U32)))

def trim.of(+j: U32, +k: U32, r: Array<Cell> & Cell) -> Array<Cell>:
  (a, c) = r
  Array.set(Cell, a, j, mask(c, k))

def trim.if(part: Bool, a: Array<Cell>, +len: U32) -> Array<Cell>:
  match part:
    case True{}:
      trim.of((len >> 3n : U32), (len .&. 7 : U32), Array.get(Cell, a, (len >> 3n : U32)))
    case False{}:
      a

# The lanes past len in its last cell become +0.0 again.
def trim(a: Array<Cell>, +len: U32) -> Array<Cell>:
  trim.if(U32.is_ne((len .&. 7 : U32), 0), a, len)

# n zeros.
def new(+n: U32) -> F32Array:
  F32Array{n, alloc(n)}

def length(a: F32Array) -> F32Array & U32:
  F32Array{+len, buf} = a
  (F32Array{len, buf}, len)

def get.some(+len: U32, r: Array<Cell> & F32) -> F32Array & Maybe<&2, F32>:
  (a, v) = r
  (F32Array{len, a}, Some{v})

def get.if(ok: Bool, +len: U32, buf: Array<Cell>, +i: U32) -> F32Array & Maybe<&2, F32>:
  match ok:
    case True{}:
      get.some(len, peek(buf, i))
    case False{}:
      (F32Array{len, buf}, None{})

# Element i, or None when i >= len.
def get(a: F32Array, +i: U32) -> F32Array & Maybe<&2, F32>:
  F32Array{+len, buf} = a
  get.if(U32.is_lt(i, len), len, buf, i)

def set.if(ok: Bool, +len: U32, buf: Array<Cell>, +i: U32, +v: F32) -> F32Array:
  match ok:
    case True{}:
      F32Array{len, poke(buf, i, v)}
    case False{}:
      F32Array{len, buf}

# Element i becomes v. Nothing changes when i >= len.
def set(a: F32Array, +i: U32, +v: F32) -> F32Array:
  F32Array{+len, buf} = a
  set.if(U32.is_lt(i, len), len, buf, i, v)

def count(xs: List<&2, F32>, +n: U32) -> U32:
  match xs:
    case Nil{}:
      n
    case Con{h, t}:
      count(t, (n + 1 : U32))

def from_list.go(xs: List<&2, F32>, a: Array<Cell>, +i: U32) -> Array<Cell>:
  match xs:
    case Nil{}:
      a
    case Con{+h, t}:
      from_list.go(t, poke(a, i, h), (i + 1 : U32))

def from_list(+xs: List<&2, F32>) -> F32Array:
  +n = count(xs, 0)
  F32Array{n, from_list.go(xs, alloc(n), 0)}

# r holds element i; the list is built from the last element back.
def to_list.go(n: Nat, r: Array<Cell> & F32, +i: U32, acc: List<&2, F32>) -> List<&2, F32>:
  match n:
    case 0n:
      acc
    case 1n+p:
      (a, v) = r
      to_list.go(p, peek(a, (i - 1 : U32)), (i - 1 : U32), Con{v, acc})

def to_list(a: F32Array) -> List<&2, F32>:
  F32Array{+len, buf} = a
  to_list.go(U32.to_nat(len), peek(buf, (len - 1 : U32)), (len - 1 : U32), Nil{})

# n elements from src[s..] to dst[d..]; r holds src[s].
def copy.go(n: Nat, r: Array<Cell> & F32, dst: Array<Cell>, +s: U32, +d: U32) -> Array<Cell> & Array<Cell>:
  match n:
    case 0n:
      (a, v) = r
      (a, dst)
    case 1n+p:
      (a, +v) = r
      copy.go(p, peek(a, (s + 1 : U32)), poke(dst, d, v), (s + 1 : U32), (d + 1 : U32))

# n whole cells from src[s..] to dst[d..] (cell indexes); r holds src cell s.
def copy.cells(n: Nat, r: Array<Cell> & Cell, dst: Array<Cell>, +s: U32, +d: U32) -> Array<Cell> & Array<Cell>:
  match n:
    case 0n:
      (a, c) = r
      (a, dst)
    case 1n+p:
      (a, c) = r
      copy.cells(p, Array.get(Cell, a, (s + 1 : U32)), Array.set(Cell, dst, d, c), (s + 1 : U32), (d + 1 : U32))

def copy.trim(+end: U32, r: Array<Cell> & Array<Cell>) -> Array<Cell> & Array<Cell>:
  (a, b) = r
  (a, trim(b, end))

def copy.pick(aligned: Bool, +m: U32, src: Array<Cell>, dst: Array<Cell>, +s: U32, +d: U32) -> Array<Cell> & Array<Cell>:
  match aligned:
    case True{}:
      copy.trim((d + m : U32), copy.cells(U32.to_nat(cells(m)), Array.get(Cell, src, (s >> 3n : U32)), dst, (s >> 3n : U32), (d >> 3n : U32)))
    case False{}:
      copy.go(U32.to_nat(m), peek(src, s), dst, s, d)

# m elements from src[s..] to dst[d..]. When both are cell-aligned, whole cells move, and dst's lanes past d + m in its last cell become +0.0.
def copy(+m: U32, src: Array<Cell>, dst: Array<Cell>, +s: U32, +d: U32) -> Array<Cell> & Array<Cell>:
  copy.pick(U32.is_eq(((s .|. d) .&. 7 : U32), 0), m, src, dst, s, d)

def slice.fin(+len: U32, +m: U32, r: Array<Cell> & Array<Cell>) -> F32Array & F32Array:
  (a, c) = r
  (F32Array{len, a}, F32Array{m, c})

# The array back, and a copy of up to n elements from start. Both ends are clamped to len.
def slice(a: F32Array, +start: U32, +n: U32) -> F32Array & F32Array:
  F32Array{+len, buf} = a
  +s = U32.min(start, len)
  +m = U32.min(n, (len - s : U32))
  slice.fin(len, m, copy(m, buf, alloc(m), s, 0))

def concat.total.con(x: F32Array, r: List<&1, F32Array> & U32) -> List<&1, F32Array> & U32:
  (t, n) = r
  (Con{x, t}, n)

def concat.total(xs: List<&1, F32Array>, +n: U32) -> List<&1, F32Array> & U32:
  match xs:
    case Nil{}:
      (Nil{}, n)
    case Con{F32Array{+len, buf}, t}:
      concat.total.con(F32Array{len, buf}, concat.total(t, (n + len : U32)))

def snd(r: Array<Cell> & Array<Cell>) -> Array<Cell>:
  (a, b) = r
  b

def concat.go(xs: List<&1, F32Array>, out: Array<Cell>, +at: U32) -> Array<Cell>:
  match xs:
    case Nil{}:
      out
    case Con{F32Array{+len, buf}, t}:
      concat.go(t, snd(copy(len, buf, out, 0, at)), (at + len : U32))

def concat.of(r: List<&1, F32Array> & U32) -> F32Array:
  (xs, +n) = r
  F32Array{n, concat.go(xs, alloc(n), 0)}

# The pieces in order, in one new array.
def concat(xs: List<&1, F32Array>) -> F32Array:
  concat.of(concat.total(xs, 0))

def map.cell(~f: F32 -> F32, c: Cell) -> Cell:
  Cell{v0, v1, v2, v3, v4, v5, v6, v7} = c
  Cell{f(v0), f(v1), f(v2), f(v3), f(v4), f(v5), f(v6), f(v7)}

def map.step(~f: F32 -> F32, +i: U32, r: Array<Cell> & Cell) -> Array<Cell>:
  (a, c) = r
  Array.set(Cell, a, i, map.cell(~f, c))

# Each pass reads and writes its own cell; the form that read the next cell ahead ran 4x slower.
def map.go(~f: F32 -> F32, n: Nat, a: Array<Cell>, +i: U32) -> Array<Cell>:
  match n:
    case 0n:
      a
    case 1n+p:
      map.go(~f, p, map.step(~f, i, Array.get(Cell, a, i)), (i + 1 : U32))

# f on each element, in place.
def map(~f: F32 -> F32, a: F32Array) -> F32Array:
  F32Array{+len, buf} = a
  F32Array{len, trim(map.go(~f, U32.to_nat(cells(len)), buf, 0), len)}

def fold.cell(~A: Data, ~f: A -> F32 -> A, acc: A, c: Cell) -> A:
  Cell{v0, v1, v2, v3, v4, v5, v6, v7} = c
  f(f(f(f(f(f(f(f(acc, v0), v1), v2), v3), v4), v5), v6), v7)

# Lanes j .. j + n - 1 of c.
def fold.lanes(~A: Data, ~f: A -> F32 -> A, n: Nat, +c: Cell, +j: U32, acc: A) -> A:
  match n:
    case 0n:
      acc
    case 1n+p:
      fold.lanes(~A, ~f, p, c, (j + 1 : U32), f(acc, lane(c, j)))

# n whole cells from cell i, then the first k lanes of the next one; r holds cell i.
def fold.go(~A: Data, ~f: A -> F32 -> A, n: Nat, +k: U32, r: Array<Cell> & Cell, +i: U32, acc: A) -> Array<Cell> & A:
  match n:
    case 0n:
      (a, +c) = r
      (a, fold.lanes(~A, ~f, U32.to_nat(k), c, 0, acc))
    case 1n+p:
      (a, c) = r
      fold.go(~A, ~f, p, k, Array.get(Cell, a, (i + 1 : U32)), (i + 1 : U32), fold.cell(~A, ~f, acc, c))

def fold.fin(-A: Data, +len: U32, r: Array<Cell> & A) -> F32Array & A:
  (a, x) = r
  (F32Array{len, a}, x)

# f(...f(f(init, a[0]), a[1])..., a[len-1]), left to right.
def fold(~A: Data, ~f: A -> F32 -> A, a: F32Array, init: A) -> F32Array & A:
  F32Array{+len, buf} = a
  fold.fin(A, len, fold.go(~A, ~f, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), Array.get(Cell, buf, 0), 0, init))

def zip.step(~f: F32 -> F32 -> F32, +i: U32, r: Array<Cell> & Cell, s: Array<Cell> & Cell) -> Array<Cell> & Array<Cell>:
  (a, Cell{x0, x1, x2, x3, x4, x5, x6, x7}) = r
  (b, Cell{y0, y1, y2, y3, y4, y5, y6, y7}) = s
  (Array.set(Cell, a, i, Cell{f(x0, y0), f(x1, y1), f(x2, y2), f(x3, y3), f(x4, y4), f(x5, y5), f(x6, y6), f(x7, y7)}), b)

def zip.at(~f: F32 -> F32 -> F32, +i: U32, ab: Array<Cell> & Array<Cell>) -> Array<Cell> & Array<Cell>:
  (a, b) = ab
  zip.step(~f, i, Array.get(Cell, a, i), Array.get(Cell, b, i))

# f(a's cell i, b's cell i) goes into a.
def zip.go(~f: F32 -> F32 -> F32, n: Nat, ab: Array<Cell> & Array<Cell>, +i: U32) -> Array<Cell> & Array<Cell>:
  match n:
    case 0n:
      ab
    case 1n+p:
      zip.go(~f, p, zip.at(~f, i, ab), (i + 1 : U32))

def zip.fin(+la: U32, +lb: U32, r: Array<Cell> & Array<Cell>) -> F32Array & F32Array & Bool:
  (a, b) = r
  (F32Array{la, trim(a, la)}, F32Array{lb, b}, True{})

def zip.if(~f: F32 -> F32 -> F32, same: Bool, +la: U32, xa: Array<Cell>, +lb: U32, ya: Array<Cell>) -> F32Array & F32Array & Bool:
  match same:
    case True{}:
      zip.fin(la, lb, zip.go(~f, U32.to_nat(cells(la)), (xa, ya), 0))
    case False{}:
      (F32Array{la, xa}, F32Array{lb, ya}, False{})

# f(a[i], b[i]) for each i, written into a, and b back. When the lengths differ, both come back unchanged beside False.
def zip_with(~f: F32 -> F32 -> F32, a: F32Array, b: F32Array) -> F32Array & F32Array & Bool:
  F32Array{+la, xa} = a
  F32Array{+lb, ya} = b
  zip.if(~f, U32.is_eq(la, lb), la, xa, lb, ya)

def add2(x: F32, y: F32) -> F32:
  (x + y : F32)

def mul2(x: F32, y: F32) -> F32:
  (x * y : F32)

# a[i] + b[i], into a, as zip_with.
def add(a: F32Array, b: F32Array) -> F32Array & F32Array & Bool:
  zip_with(~add2, a, b)

# a[i] * b[i], into a, as zip_with.
def mul(a: F32Array, b: F32Array) -> F32Array & F32Array & Bool:
  zip_with(~mul2, a, b)

# Four running sums: lanes 0 and 4 of each cell go to s0, 1 and 5 to s1, and so on. The +0.0 lanes past len add nothing.
def sum.go(n: Nat, r: Array<Cell> & Cell, +i: U32, s0: F32, s1: F32, s2: F32, s3: F32) -> Array<Cell> & F32:
  match n:
    case 0n:
      (a, c) = r
      (a, ((s0 + s1 : F32) + (s2 + s3 : F32) : F32))
    case 1n+p:
      (a, Cell{x0, x1, x2, x3, x4, x5, x6, x7}) = r
      sum.go(p, Array.get(Cell, a, (i + 1 : U32)), (i + 1 : U32), ((s0 + x0 : F32) + x4 : F32), ((s1 + x1 : F32) + x5 : F32), ((s2 + x2 : F32) + x6 : F32), ((s3 + x3 : F32) + x7 : F32))

def sum.fin(+len: U32, r: Array<Cell> & F32) -> F32Array & F32:
  (a, x) = r
  (F32Array{len, a}, x)

# The sum. Element i goes to running sum i % 4, each from +0.0, and the four are added as (s0 + s1) + (s2 + s3).
# ponytail: four running sums, so error still grows with len; a pairwise fork-join sum fixes accuracy and uses every core.
def sum(a: F32Array) -> F32Array & F32:
  F32Array{+len, buf} = a
  sum.fin(len, sum.go(U32.to_nat(cells(len)), Array.get(Cell, buf, 0), 0, 0.0, 0.0, 0.0, 0.0))

# Four running maxima, as sum.go keeps four sums, over n whole cells; then the first k lanes of the next cell.
def max.go(n: Nat, +k: U32, r: Array<Cell> & Cell, +i: U32, m0: F32, m1: F32, m2: F32, m3: F32) -> Array<Cell> & F32:
  match n:
    case 0n:
      (a, +c) = r
      (a, fold.lanes(~F32, ~F32.max, U32.to_nat(k), c, 0, F32.max(F32.max(m0, m1), F32.max(m2, m3))))
    case 1n+p:
      (a, Cell{x0, x1, x2, x3, x4, x5, x6, x7}) = r
      max.go(p, k, Array.get(Cell, a, (i + 1 : U32)), (i + 1 : U32), F32.max(F32.max(m0, x0), x4), F32.max(F32.max(m1, x1), x5), F32.max(F32.max(m2, x2), x6), F32.max(F32.max(m3, x3), x7))

def max.fin(+len: U32, r: Array<Cell> & F32) -> F32Array & Maybe<&2, F32>:
  (a, x) = r
  (F32Array{len, a}, Some{x})

def max.if(some: Bool, +len: U32, buf: Array<Cell>, +x: F32) -> F32Array & Maybe<&2, F32>:
  match some:
    case True{}:
      max.fin(len, max.go(U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), Array.get(Cell, buf, 0), 0, x, x, x, x))
    case False{}:
      (F32Array{len, buf}, None{})

def max.first(+len: U32, r: Array<Cell> & F32) -> F32Array & Maybe<&2, F32>:
  (a, +x) = r
  max.if(U32.is_ne(len, 0), len, a, x)

# The largest element by Base F32.max, or None when empty. Four running maxima all start at a[0], so a NaN is kept only when it comes first.
def max(a: F32Array) -> F32Array & Maybe<&2, F32>:
  F32Array{+len, buf} = a
  max.first(len, peek(buf, 0))

# As sum.go, over the products of the two cells.
def dot.go(n: Nat, r: Array<Cell> & Cell, s: Array<Cell> & Cell, +i: U32, s0: F32, s1: F32, s2: F32, s3: F32) -> Array<Cell> & Array<Cell> & F32:
  match n:
    case 0n:
      (a, x) = r
      (b, y) = s
      (a, b, ((s0 + s1 : F32) + (s2 + s3 : F32) : F32))
    case 1n+p:
      (a, Cell{x0, x1, x2, x3, x4, x5, x6, x7}) = r
      (b, Cell{y0, y1, y2, y3, y4, y5, y6, y7}) = s
      +j = (i + 1 : U32)
      dot.go(p, Array.get(Cell, a, j), Array.get(Cell, b, j), j, ((s0 + x0 * y0 : F32) + x4 * y4 : F32), ((s1 + x1 * y1 : F32) + x5 * y5 : F32), ((s2 + x2 * y2 : F32) + x6 * y6 : F32), ((s3 + x3 * y3 : F32) + x7 * y7 : F32))

def dot.fin(+la: U32, +lb: U32, r: Array<Cell> & Array<Cell> & F32) -> F32Array & F32Array & Maybe<&2, F32>:
  (a, b, x) = r
  (F32Array{la, a}, F32Array{lb, b}, Some{x})

def dot.if(same: Bool, +la: U32, xa: Array<Cell>, +lb: U32, ya: Array<Cell>) -> F32Array & F32Array & Maybe<&2, F32>:
  match same:
    case True{}:
      dot.fin(la, lb, dot.go(U32.to_nat(cells(la)), Array.get(Cell, xa, 0), Array.get(Cell, ya, 0), 0, 0.0, 0.0, 0.0, 0.0))
    case False{}:
      (F32Array{la, xa}, F32Array{lb, ya}, None{})

# Both arrays back, and the sum of a[i] * b[i], added in four running sums as sum adds. None when the lengths differ.
def dot(a: F32Array, b: F32Array) -> F32Array & F32Array & Maybe<&2, F32>:
  F32Array{+la, xa} = a
  F32Array{+lb, ya} = b
  dot.if(U32.is_eq(la, lb), la, xa, lb, ya)

# Words j .. j + 7 of a Bytes buffer as one cell; r holds word j.
def from.c7(~f: U32 -> F32, +j: U32, r: Array<U32> & U32, +x0: U32, +x1: U32, +x2: U32, +x3: U32, +x4: U32, +x5: U32, +x6: U32) -> Array<U32> & Cell:
  (w, +x7) = r
  (w, Cell{f(x0), f(x1), f(x2), f(x3), f(x4), f(x5), f(x6), f(x7)})

def from.c6(~f: U32 -> F32, +j: U32, r: Array<U32> & U32, +x0: U32, +x1: U32, +x2: U32, +x3: U32, +x4: U32, +x5: U32) -> Array<U32> & Cell:
  (w, +x6) = r
  from.c7(~f, j, Array.get(U32, w, (j + 7 : U32)), x0, x1, x2, x3, x4, x5, x6)

def from.c5(~f: U32 -> F32, +j: U32, r: Array<U32> & U32, +x0: U32, +x1: U32, +x2: U32, +x3: U32, +x4: U32) -> Array<U32> & Cell:
  (w, +x5) = r
  from.c6(~f, j, Array.get(U32, w, (j + 6 : U32)), x0, x1, x2, x3, x4, x5)

def from.c4(~f: U32 -> F32, +j: U32, r: Array<U32> & U32, +x0: U32, +x1: U32, +x2: U32, +x3: U32) -> Array<U32> & Cell:
  (w, +x4) = r
  from.c5(~f, j, Array.get(U32, w, (j + 5 : U32)), x0, x1, x2, x3, x4)

def from.c3(~f: U32 -> F32, +j: U32, r: Array<U32> & U32, +x0: U32, +x1: U32, +x2: U32) -> Array<U32> & Cell:
  (w, +x3) = r
  from.c4(~f, j, Array.get(U32, w, (j + 4 : U32)), x0, x1, x2, x3)

def from.c2(~f: U32 -> F32, +j: U32, r: Array<U32> & U32, +x0: U32, +x1: U32) -> Array<U32> & Cell:
  (w, +x2) = r
  from.c3(~f, j, Array.get(U32, w, (j + 3 : U32)), x0, x1, x2)

def from.c1(~f: U32 -> F32, +j: U32, r: Array<U32> & U32, +x0: U32) -> Array<U32> & Cell:
  (w, +x1) = r
  from.c2(~f, j, Array.get(U32, w, (j + 2 : U32)), x0, x1)

def from.c0(~f: U32 -> F32, +j: U32, r: Array<U32> & U32) -> Array<U32> & Cell:
  (w, +x0) = r
  from.c1(~f, j, Array.get(U32, w, (j + 1 : U32)), x0)

# r holds cell i; each pass writes cell i and reads cell i + 1.
def from.go(~f: U32 -> F32, n: Nat, r: Array<U32> & Cell, out: Array<Cell>, +i: U32) -> Array<Cell>:
  match n:
    case 0n:
      (w, c) = r
      out
    case 1n+p:
      (w, c) = r
      +j = (i + 1 : U32)
      from.go(~f, p, from.c0(~f, (j << 3n : U32), Array.get(U32, w, (j << 3n : U32))), Array.set(Cell, out, i, c), j)

# Reads past the words wrap around, so the last cell is trimmed.
def from_bytes.if(~f: U32 -> F32, aligned: Bool, +len: U32, buf: Array<U32>) -> Maybe<&1, F32Array>:
  match aligned:
    case True{}:
      +n = (len >> 2n : U32)
      Some{F32Array{n, trim(from.go(~f, U32.to_nat(cells(n)), from.c0(~f, 0, Array.get(U32, buf, 0)), alloc(n), 0), n)}}
    case False{}:
      None{}

# Four bytes per element, least significant first. None when the length is not a multiple of 4.
def from_bytes.le(b: Bytes.Bytes) -> Maybe<&1, F32Array>:
  Bytes.Bytes{+len, buf} = b
  from_bytes.if(~of_bits, U32.is_eq((len .&. 3 : U32), 0), len, buf)

# Four bytes per element, most significant first. None when the length is not a multiple of 4.
def from_bytes.be(b: Bytes.Bytes) -> Maybe<&1, F32Array>:
  Bytes.Bytes{+len, buf} = b
  from_bytes.if(~of_bits.be, U32.is_eq((len .&. 3 : U32), 0), len, buf)

def to.cell(~g: F32 -> U32, c: Cell, w: Array<U32>, +j: U32) -> Array<U32>:
  Cell{v0, v1, v2, v3, v4, v5, v6, v7} = c
  Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, Array.set(U32, w, (j + 0 : U32), g(v0)), (j + 1 : U32), g(v1)), (j + 2 : U32), g(v2)), (j + 3 : U32), g(v3)), (j + 4 : U32), g(v4)), (j + 5 : U32), g(v5)), (j + 6 : U32), g(v6)), (j + 7 : U32), g(v7))

# The first n lanes of c, from lane l, into words j ..
def to.tail(~g: F32 -> U32, n: Nat, +c: Cell, w: Array<U32>, +j: U32, +l: U32) -> Array<U32>:
  match n:
    case 0n:
      w
    case 1n+p:
      to.tail(~g, p, c, Array.set(U32, w, j, g(lane(c, l))), (j + 1 : U32), (l + 1 : U32))

# n whole cells from cell i, then the first k lanes of the next one, so no write runs past the words.
def to.go(~g: F32 -> U32, n: Nat, +k: U32, r: Array<Cell> & Cell, w: Array<U32>, +i: U32) -> Array<Cell> & Array<U32>:
  match n:
    case 0n:
      (a, +c) = r
      (a, to.tail(~g, U32.to_nat(k), c, w, (i << 3n : U32), 0))
    case 1n+p:
      (a, c) = r
      to.go(~g, p, k, Array.get(Cell, a, (i + 1 : U32)), to.cell(~g, c, w, (i << 3n : U32)), (i + 1 : U32))

def to.fin(+n: U32, r: Array<Cell> & Array<U32>) -> Bytes.Bytes:
  (a, w) = r
  Bytes.Bytes{n, w}

def to_bytes.with(~g: F32 -> U32, a: F32Array) -> Bytes.Bytes:
  F32Array{+len, buf} = a
  +n = (len << 2n : U32)
  to.fin(n, to.go(~g, U32.to_nat((len >> 3n : U32)), (len .&. 7 : U32), Array.get(Cell, buf, 0), Bytes.alloc(n), 0))

# Each element as four bytes, least significant first. len must be below 2^30.
def to_bytes.le(a: F32Array) -> Bytes.Bytes:
  to_bytes.with(~to_bits, a)

# Each element as four bytes, most significant first. len must be below 2^30.
def to_bytes.be(a: F32Array) -> Bytes.Bytes:
  to_bytes.with(~to_bits.be, a)

# A file read in progress: more bytes to read, or the final result.
type Read is Type:
  More{file: File, acc: Bytes.Bytes, left: U32}
  Stop{file: File, result: Result<&1, &1, U32 & String, Bytes.Bytes>}

def read.next(more: Bool, file: File, acc: Bytes.Bytes, +left: U32) -> Read:
  match more:
    case True{}:
      More{file, acc, left}
    case False{}:
      Stop{file, Done{acc}}

# A read of no bytes ends the loop early, so a file that shrank stops there.
def read.step(got: File & Result<&1, &1, U32 & String, Bytes.Bytes>, acc: Bytes.Bytes, +left: U32) -> Read:
  (file, r) = got
  match r:
    case Fail{e}:
      Stop{file, Fail{e}}
    case Done{Bytes.Bytes{+m, buf}}:
      +rest = (left - U32.min(m, left) : U32)
      read.next(Bool.and(U32.is_ne(m, 0), U32.is_ne(rest, 0)), file, Bytes.append(acc, Bytes.Bytes{m, buf}), rest)

# Each pass reads at least one byte or stops, so left + 1 passes are enough.
def read.loop(n: Nat, st: Read) -> IO(File & Result<&1, &1, U32 & String, Bytes.Bytes>):
  match n:
    case 0n:
      match st:
        case More{file, acc, left}:
          IO.pure(File & Result<&1, &1, U32 & String, Bytes.Bytes>, (file, Done{acc}))
        case Stop{file, result}:
          IO.pure(File & Result<&1, &1, U32 & String, Bytes.Bytes>, (file, result))
    case 1n+p:
      match st:
        case More{file, acc, +left}:
          do IO<File & Result<&1, &1, U32 & String, Bytes.Bytes>>:
            got : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Files.read_bytes(file, U32.min(left, 1048576))
            read.loop(p, read.step(got, acc, left))
        case Stop{file, result}:
          IO.pure(File & Result<&1, &1, U32 & String, Bytes.Bytes>, (file, result))

def read.sized(sz: File & Result<&1, &1, U32 & String, U32>) -> IO(File & Result<&1, &1, U32 & String, Bytes.Bytes>):
  (file, r) = sz
  match r:
    case Fail{e}:
      IO.pure(File & Result<&1, &1, U32 & String, Bytes.Bytes>, (file, Fail{e}))
    case Done{+n}:
      read.loop(1n+U32.to_nat(n), read.next(U32.is_ne(n, 0), file, Bytes.new(0), n))

def read.decode(m: Maybe<&1, F32Array>) -> Result<&1, &1, U32 & String, F32Array>:
  match m:
    case None{}:
      Fail{(22, "f32array: the file size is not a multiple of 4")}
    case Some{a}:
      Done{a}

def read.fin(~f: Bytes.Bytes -> Maybe<&1, F32Array>, got: File & Result<&1, &1, U32 & String, Bytes.Bytes>) -> File & Result<&1, &1, U32 & String, F32Array>:
  (file, r) = got
  match r:
    case Fail{e}:
      (file, Fail{e})
    case Done{b}:
      (file, read.decode(f(b)))

def read.with(~f: Bytes.Bytes -> Maybe<&1, F32Array>, file: File) -> IO(File & Result<&1, &1, U32 & String, F32Array>):
  do IO<File & Result<&1, &1, U32 & String, F32Array>>:
    sz : File & Result<&1, &1, U32 & String, U32> <- File.size(file)
    got : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- read.sized(sz)
    return read.fin(~f, got)

# The rest of an open file, four little-endian bytes per element. Fails EINVAL when its size is not a multiple of 4.
def read.le(file: File) -> IO(File & Result<&1, &1, U32 & String, F32Array>):
  read.with(~from_bytes.le, file)

# The rest of an open file, four big-endian bytes per element. Fails EINVAL when its size is not a multiple of 4.
def read.be(file: File) -> IO(File & Result<&1, &1, U32 & String, F32Array>):
  read.with(~from_bytes.be, file)
