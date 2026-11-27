import Base
import ./bytes.bend as Bytes

def go_zero(r: Array<U32> & U32, dst: Array<U32>, +s: U32, +d: U32) -> {Bytes.dst(Bytes.copy.go(0n, r, dst, s, d)) == dst : Array<U32>}:
  (a, v) = r
  {==}

def bytes_zero(src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> {Bytes.dst(Bytes.copy.bytes(0, src, dst, s, d)) == dst : Array<U32>}:
  go_zero(Bytes.peek(src, s), dst, s, d)

def words_tail_zero(r: Array<U32> & U32, dst: Array<U32>, +s: U32, +d: U32, +ts: U32, +td: U32) -> {Bytes.dst(Bytes.copy.tail(0, ts, td, Bytes.copy.words(0n, r, dst, s, d))) == dst : Array<U32>}:
  (a, w) = r
  bytes_zero(a, dst, ts, td)

def shift_tail_zero(r: Array<U32> & U32, dst: Array<U32>, +lo: Nat, +hi: Nat, +prev: U32, +k: U32, +d: U32, +ts: U32, +td: U32) -> {Bytes.dst(Bytes.copy.tail(0, ts, td, Bytes.copy.shift(0n, lo, hi, prev, r, dst, k, d))) == dst : Array<U32>}:
  (a, w) = r
  bytes_zero(a, dst, ts, td)

def shift_at_tail_zero(r: Array<U32> & U32, dst: Array<U32>, +lo: U32, +k: U32, +d: U32, +ts: U32, +td: U32) -> {Bytes.dst(Bytes.copy.tail(0, ts, td, Bytes.copy.shift.at(0, lo, k, d, r, dst))) == dst : Array<U32>}:
  (a, prev) = r
  shift_tail_zero(Array.get(U32, a, U32.add(k, 1)), dst, U32.to_nat(lo), U32.to_nat(U32.sub(32, lo)), prev, U32.add(k, 1), d, ts, td)

def pick_zero(aligned: Bool, src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> {Bytes.dst(Bytes.copy.pick(aligned, 0, src, dst, s, d)) == dst : Array<U32>}:
  match aligned:
    case True{}:
      words_tail_zero(Array.get(U32, src, U32.shrn(s, 2n)), dst, U32.shrn(s, 2n), U32.shrn(d, 2n), U32.add(s, 0), U32.add(d, 0))
    case False{}:
      shift_at_tail_zero(Array.get(U32, src, U32.shrn(s, 2n)), dst, U32.mul(U32.and(s, 3), 8), U32.shrn(s, 2n), U32.shrn(d, 2n), U32.add(s, 0), U32.add(d, 0))

def dst_zero(aligned: Bool, src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> {Bytes.dst(Bytes.copy.dst(aligned, 0, src, dst, s, d)) == dst : Array<U32>}:
  match aligned:
    case False{}:
      bytes_zero(src, dst, s, d)
    case True{}:
      pick_zero(U32.is_eq(U32.and(s, 3), 0), src, dst, s, d)

def zero(src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> {Bytes.dst(Bytes.copy(0, src, dst, s, d)) == dst : Array<U32>}:
  dst_zero(U32.is_eq(U32.and(d, 3), 0), src, dst, s, d)
