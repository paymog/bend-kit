# Collections benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../omap.bend as O
import ../vec.bend as V
import ../deque.bend as D
import ../heap.bend as H

# N = 2^20 elements. vec_get takes its index from the top 20 bits of the LCG.
def N() -> Nat:
  1048576n

def N1() -> Nat:
  1048575n

def HALF1() -> Nat:
  524287n

def SHIFT() -> Nat:
  12n

def lcg(+x: U32) -> U32:
  (x * 1664525 + 1013904223 : U32)

def mix(+acc: U32, +x: U32) -> U32:
  (acc * 31 + x : U32)

def stamp(+name: String, t0: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\t" ++ name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def chk(+name: String, +v: U32) -> IO(Unit):
  IO.print("chk\t" ++ name ++ "\t" ++ U32.show(v))

# A computed checksum is printed before the clock stops, so it cannot be deferred.
def lap(+name: String, t0: Time.Duration, +v: U32) -> IO(Unit):
  do IO<Unit>:
    chk(name, v)
    stamp(name, t0)

# omap: put key lcg^i(1) with value i, then get every key in the same order.
def mput(n: Nat, m: O.OMap<U32, U32>, +x: U32, +i: U32) -> O.OMap<U32, U32>:
  match n:
    case 0n:
      m
    case 1n+p:
      +k = lcg(x)
      mput(p, O.OMap.put(~U32, ~U32, ~U32.cmp, m, k, i), k, (i + 1 : U32))

def mget(n: Nat, +m: O.OMap<U32, U32>, +x: U32, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      +k = lcg(x)
      mget(p, m, k, (acc + Maybe.default(&2, U32, O.OMap.get(~U32, ~U32, ~U32.cmp, m, k), 0) : U32))

# vec: push 0..N-1, then N reads at LCG indexes.
def vpush(n: Nat, v: V.Vec<U32>, +i: U32) -> V.Vec<U32>:
  match n:
    case 0n:
      v
    case 1n+p:
      vpush(p, V.Vec.push(~U32, v, i), (i + 1 : U32))

# r is the vector beside the previous read; the first read is None.
def vget(n: Nat, r: V.Vec<U32> & Maybe<&2, U32>, +x: U32, +acc: U32) -> U32:
  match n:
    case 0n:
      (v, got) = r
      (acc + Maybe.default(&2, U32, got, 0) : U32)
    case 1n+p:
      (v, got) = r
      +k = lcg(x)
      vget(p, V.Vec.get(~U32, v, (k >> SHIFT() : U32)), k,
        (acc + Maybe.default(&2, U32, got, 0) : U32))

# deque: push_back 0..N-1, pop N/2 from the front, then N/2 from the back.
def dpush(n: Nat, d: D.Deque<&2, U32>, +i: U32) -> D.Deque<&2, U32>:
  match n:
    case 0n:
      d
    case 1n+p:
      dpush(p, D.Deque.push_back(&2, U32, i, d), (i + 1 : U32))

# r is the last pop; n more pops follow it.
def dfront(n: Nat, r: Maybe<&1, U32 & D.Deque<&2, U32>>, +acc: U32) -> U32 & D.Deque<&2, U32>:
  match n r:
    case _ None{}:
      (acc, D.Deque.new(&2, U32))
    case 0n Some{p}:
      (x, d) = p
      (mix(acc, x), d)
    case 1n+q Some{p}:
      (x, d) = p
      dfront(q, D.Deque.pop_front(&2, U32, d), mix(acc, x))

def dback(n: Nat, r: Maybe<&1, U32 & D.Deque<&2, U32>>, +acc: U32) -> U32 & D.Deque<&2, U32>:
  match n r:
    case _ None{}:
      (acc, D.Deque.new(&2, U32))
    case 0n Some{p}:
      (x, d) = p
      (mix(acc, x), d)
    case 1n+q Some{p}:
      (x, d) = p
      dback(q, D.Deque.pop_back(&2, U32, d), mix(acc, x))

# heap: push lcg^i(1) for i < N, then pop every element in ascending order.
def hpush(n: Nat, h: H.Heap<U32>, +x: U32) -> H.Heap<U32>:
  match n:
    case 0n:
      h
    case 1n+p:
      +k = lcg(x)
      hpush(p, H.Heap.push(~U32, ~U32.is_le, k, h), k)

def hpop(n: Nat, r: Maybe<&1, U32 & H.Heap<U32>>, +acc: U32) -> U32:
  match n r:
    case _ None{}:
      acc
    case 0n Some{p}:
      (x, h) = p
      mix(acc, x)
    case 1n+q Some{p}:
      (x, h) = p
      hpop(q, H.Heap.pop(~U32, ~U32.is_le, h), mix(acc, x))

# The ops run in sequence. A push op stops its clock first, then prints the size,
# so a size walk (Deque.length) is not timed.
def op.heap.popped(t0: Time.Duration, +acc: U32) -> IO(Unit):
  lap("heap_pop", t0, acc)

def op.heap.pushed(t0: Time.Duration, +h: H.Heap<U32>) -> IO(Unit):
  do IO<Unit>:
    stamp("heap_push", t0)
    chk("heap_push", U32.from_nat(H.Heap.size(U32, h)))
    t1 : Time.Duration <- Time.mono()
    op.heap.popped(t1, hpop(N1(), H.Heap.pop(~U32, ~U32.is_le, h), 0))

def op.heap() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.heap.pushed(t0, hpush(N(), H.Heap.new(U32), 1))

def op.deque.popped(t0: Time.Duration, r: U32 & D.Deque<&2, U32>) -> IO(Unit):
  (acc, d) = r
  do IO<Unit>:
    lap("deque_pop", t0, acc)
    op.heap()

def op.deque.half(t0: Time.Duration, r: U32 & D.Deque<&2, U32>) -> IO(Unit):
  (acc, d) = r
  op.deque.popped(t0, dback(HALF1(), D.Deque.pop_back(&2, U32, d), acc))

def op.deque.pushed(t0: Time.Duration, +d: D.Deque<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    stamp("deque_push", t0)
    chk("deque_push", U32.from_nat(D.Deque.length(&2, U32, d)))
    t1 : Time.Duration <- Time.mono()
    op.deque.half(t1, dfront(HALF1(), D.Deque.pop_front(&2, U32, d), 0))

def op.deque() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.deque.pushed(t0, dpush(N(), D.Deque.new(&2, U32), 0))

def op.vec.got(t0: Time.Duration, +acc: U32) -> IO(Unit):
  do IO<Unit>:
    lap("vec_get", t0, acc)
    op.deque()

def op.vec.pushed(t0: Time.Duration, r: V.Vec<U32> & U32) -> IO(Unit):
  (v, n) = r
  do IO<Unit>:
    stamp("vec_push", t0)
    chk("vec_push", n)
    t1 : Time.Duration <- Time.mono()
    op.vec.got(t1, vget(N(), (v, None{}), 1, 0))

def op.vec() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.vec.pushed(t0, V.Vec.len(~U32, vpush(N(), V.Vec.new(~U32), 0)))

def op.omap.got(t0: Time.Duration, +acc: U32) -> IO(Unit):
  do IO<Unit>:
    lap("omap_get", t0, acc)
    op.vec()

def op.omap.put(t0: Time.Duration, +m: O.OMap<U32, U32>) -> IO(Unit):
  do IO<Unit>:
    stamp("omap_put", t0)
    chk("omap_put", O.OMap.size(U32, U32, m))
    t1 : Time.Duration <- Time.mono()
    op.omap.got(t1, mget(N(), m, 1, 0))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.omap.put(t0, mput(N(), O.OMap.new(U32, U32), 1, 0))
