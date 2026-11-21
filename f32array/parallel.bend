# Pairwise F32Array reductions with read-only, zero-copy fork-join handles.
import Base
import ./f32array.bend as A
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def sum.join(l: Array<A.Cell> & F32, r: Array<A.Cell> & F32) -> Array<A.Cell> & F32:
  (a, x) = l
  (b, y) = r
  (Array.join(A.Cell, a, b), (x + y : F32))

@unsafe
def sum.fork(+d: Nat, +h: U32, +i: U32, lr: Array<A.Cell> & Array<A.Cell>, +cutoff: U32) -> Array<A.Cell> & F32:
  (l, r) = lr
  lo hi = sum.range(d, h, i, l, cutoff) sum.range(d, h, (i + h : U32), r, cutoff)
  sum.join(lo, hi)

@unsafe
def sum.range(d: Nat, +n: U32, +i: U32, a: Array<A.Cell>, +cutoff: U32) -> Array<A.Cell> & F32:
  match d:
    case 0n:
      A.sum.range(0n, n, i, a)
    case 1n+ +p:
      sum.split(U32.is_gt(n, cutoff), p, n, i, a, cutoff)

def sum.split(split: Bool, +d: Nat, +n: U32, +i: U32, a: Array<A.Cell>, +cutoff: U32) -> Array<A.Cell> & F32:
  match split:
    case False{}:
      A.sum.range(Nat.sub(1n+d, 4n), n, i, a)
    case True{}:
      +h = (n >> 1n : U32)
      sum.fork(d, h, i, Array.fork(A.Cell, a), cutoff)

def sum.with_cutoff(a: A.F32Array, cutoff: U32) -> A.F32Array & F32:
  A.F32Array{+len, buf} = a
  +d = Bytes.depth(A.cells(len))
  A.sum.fin(len, sum.range(d, (1 << d : U32), 0, buf, U32.max(cutoff, 16)))

def sum.top(small: Bool, a: A.F32Array) -> A.F32Array & F32:
  match small:
    case True{}:
      A.sum(a)
    case False{}:
      sum.with_cutoff(a, 4096)

def sum(a: A.F32Array) -> A.F32Array & F32:
  A.F32Array{+len, buf} = a
  sum.top(U32.is_lt(len, 1048576), A.F32Array{len, buf})

def dot.join(l: Array<A.Cell> & Array<A.Cell> & F32, r: Array<A.Cell> & Array<A.Cell> & F32) -> Array<A.Cell> & Array<A.Cell> & F32:
  (a, b, x) = l
  (c, d, y) = r
  (Array.join(A.Cell, a, c), Array.join(A.Cell, b, d), (x + y : F32))

@unsafe
def dot.fork(+d: Nat, +h: U32, +i: U32, aa: Array<A.Cell> & Array<A.Cell>, bb: Array<A.Cell> & Array<A.Cell>, +cutoff: U32) -> Array<A.Cell> & Array<A.Cell> & F32:
  (al, ar) = aa
  (bl, br) = bb
  lo hi = dot.range(d, h, i, al, bl, cutoff) dot.range(d, h, (i + h : U32), ar, br, cutoff)
  dot.join(lo, hi)

@unsafe
def dot.range(d: Nat, +n: U32, +i: U32, a: Array<A.Cell>, b: Array<A.Cell>, +cutoff: U32) -> Array<A.Cell> & Array<A.Cell> & F32:
  match d:
    case 0n:
      A.dot.range(0n, n, i, a, b)
    case 1n+ +p:
      dot.split(U32.is_gt(n, cutoff), p, n, i, a, b, cutoff)

def dot.split(split: Bool, +d: Nat, +n: U32, +i: U32, a: Array<A.Cell>, b: Array<A.Cell>, +cutoff: U32) -> Array<A.Cell> & Array<A.Cell> & F32:
  match split:
    case False{}:
      A.dot.range(Nat.sub(1n+d, 4n), n, i, a, b)
    case True{}:
      +h = (n >> 1n : U32)
      dot.fork(d, h, i, Array.fork(A.Cell, a), Array.fork(A.Cell, b), cutoff)

def dot.if(same: Bool, +la: U32, a: Array<A.Cell>, +lb: U32, b: Array<A.Cell>, cutoff: U32) -> A.F32Array & A.F32Array & Maybe<&2, F32>:
  match same:
    case False{}:
      (A.F32Array{la, a}, A.F32Array{lb, b}, None{})
    case True{}:
      +d = Bytes.depth(A.cells(la))
      A.dot.fin(la, lb, dot.range(d, (1 << d : U32), 0, a, b, cutoff))

def dot.with_cutoff(a: A.F32Array, b: A.F32Array, cutoff: U32) -> A.F32Array & A.F32Array & Maybe<&2, F32>:
  A.F32Array{+la, xa} = a
  A.F32Array{+lb, xb} = b
  dot.if(U32.is_eq(la, lb), la, xa, lb, xb, U32.max(cutoff, 16))

def dot.top(small: Bool, a: A.F32Array, b: A.F32Array) -> A.F32Array & A.F32Array & Maybe<&2, F32>:
  match small:
    case True{}:
      A.dot(a, b)
    case False{}:
      dot.with_cutoff(a, b, 4096)

def dot(a: A.F32Array, b: A.F32Array) -> A.F32Array & A.F32Array & Maybe<&2, F32>:
  A.F32Array{+len, buf} = a
  dot.top(U32.is_lt(len, 1048576), A.F32Array{len, buf}, b)
