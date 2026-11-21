# Compare the former four accumulators, pairwise order, and zero-copy fork-join.
import Base
import ../../time/time.bend as Time
import ../f32array.bend as A
import ../parallel.bend as P

def ones(x: F32) -> F32:
  1.0

def legacy.sum(n: Nat, r: Array<A.Cell> & A.Cell, +i: U32, s0: F32, s1: F32, s2: F32, s3: F32) -> Array<A.Cell> & F32:
  match n:
    case 0n:
      (a, c) = r
      (a, ((s0 + s1 : F32) + (s2 + s3 : F32) : F32))
    case 1n+p:
      (a, A.Cell{x0, x1, x2, x3, x4, x5, x6, x7}) = r
      legacy.sum(p, Array.get(A.Cell, a, (i + 1 : U32)), (i + 1 : U32), ((s0 + x0 : F32) + x4 : F32), ((s1 + x1 : F32) + x5 : F32), ((s2 + x2 : F32) + x6 : F32), ((s3 + x3 : F32) + x7 : F32))

def legacy.dot(n: Nat, r: Array<A.Cell> & A.Cell, s: Array<A.Cell> & A.Cell, +i: U32, s0: F32, s1: F32, s2: F32, s3: F32) -> Array<A.Cell> & Array<A.Cell> & F32:
  match n:
    case 0n:
      (a, x) = r
      (b, y) = s
      (a, b, ((s0 + s1 : F32) + (s2 + s3 : F32) : F32))
    case 1n+p:
      (a, A.Cell{x0, x1, x2, x3, x4, x5, x6, x7}) = r
      (b, A.Cell{y0, y1, y2, y3, y4, y5, y6, y7}) = s
      +j = (i + 1 : U32)
      legacy.dot(p, Array.get(A.Cell, a, j), Array.get(A.Cell, b, j), j, ((s0 + x0 * y0 : F32) + x4 * y4 : F32), ((s1 + x1 * y1 : F32) + x5 * y5 : F32), ((s2 + x2 * y2 : F32) + x6 * y6 : F32), ((s3 + x3 * y3 : F32) + x7 * y7 : F32))

def sum(mode: U32, a: A.F32Array, cutoff: U32) -> A.F32Array & F32:
  match mode:
    case 0:
      A.F32Array{+len, buf} = a
      A.sum.fin(len, legacy.sum(U32.to_nat(A.cells(len)), Array.get(A.Cell, buf, 0), 0, 0.0, 0.0, 0.0, 0.0))
    case 1:
      A.sum(a)
    case _:
      P.sum.with_cutoff(a, cutoff)

def dot(mode: U32, a: A.F32Array, b: A.F32Array, cutoff: U32) -> A.F32Array & A.F32Array & Maybe<&2, F32>:
  match mode:
    case 0:
      A.F32Array{+la, xa} = a
      A.F32Array{+lb, xb} = b
      A.dot.fin(la, lb, legacy.dot(U32.to_nat(A.cells(la)), Array.get(A.Cell, xa, 0), Array.get(A.Cell, xb, 0), 0, 0.0, 0.0, 0.0, 0.0))
    case 1:
      A.dot(a, b)
    case _:
      P.dot.with_cutoff(a, b, cutoff)

def report(+op: String, t0: Time.Duration, +x: F32) -> IO(Unit):
  do IO<Unit>:
    IO.print("bits\t" ++ op ++ "\t" ++ U32.show(A.to_bits(x)))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\t" ++ op ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def dot.done(t0: Time.Duration, r: A.F32Array & A.F32Array & Maybe<&2, F32>) -> IO(Unit):
  (a, b, x) = r
  match x:
    case Some{v}:
      report("dot", t0, v)
    case None{}:
      IO.die(Unit, 1, "length mismatch")

def sum.done(t0: Time.Duration, +mode: U32, +cutoff: U32, b: A.F32Array, r: A.F32Array & F32) -> IO(Unit):
  (a, x) = r
  do IO<Unit>:
    report("sum", t0, x)
    t1 : Time.Duration <- Time.mono()
    dot.done(t1, dot(mode, a, b, cutoff))

def run(+n: U32, +mode: U32, +cutoff: U32, a: A.F32Array, b: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    sum.done(t0, mode, cutoff, b, sum(mode, a, cutoff))

def number(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{n}:
      n
    case None{}:
      0

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case _ <> ns <> ms <> cs <> Nil{}:
      +n = number(U32.read(ns))
      +mode = number(U32.read(ms))
      +cutoff = number(U32.read(cs))
      run(n, mode, cutoff, A.set(A.map(~ones, A.new(n)), 0, 100000000.0), A.map(~ones, A.new(n)))
    case _:
      IO.die(Unit, 1, "usage: reduce N MODE CELL_CUTOFF (MODE 0=old, 1=pairwise, 2=fork-join)")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
