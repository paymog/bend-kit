# F32Array benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import ../f32array.bend as A

# N = 2^22 elements. a[i] = (i + 3) & 3 and b[i] = (5i + 3) & 3, so every sum is an exact integer.

def ramp.go(n: Nat, a: A.F32Array, +i: U32, +k: U32) -> A.F32Array:
  match n:
    case 0n:
      a
    case 1n+p:
      ramp.go(p, A.set(a, i, U32.to_f32(((i * k + 3 : U32) .&. 3 : U32))), (i + 1 : U32), k)

def ramp(+k: U32) -> A.F32Array:
  ramp.go(4194304n, A.new(4194304), 0, k)

def twice(x: F32) -> F32:
  (x * 2.0 : F32)

def num(m: Maybe<&2, F32>) -> U32:
  match m:
    case None{}:
      4294967295
    case Some{x}:
      F32.to_u32(x)

def ends.of(+x: U32, r: A.F32Array & Maybe<&2, F32>) -> A.F32Array & U32:
  (a, y) = r
  (a, (x + num(y) : U32))

def ends.hi(r: A.F32Array & Maybe<&2, F32>) -> A.F32Array & U32:
  (a, x) = r
  ends.of(num(x), A.get(a, 12345))

# a[N-1] + a[12345], as whole numbers.
def ends(a: A.F32Array) -> A.F32Array & U32:
  ends.hi(A.get(a, 4194303))

# The checksum is printed before the second clock read, so it is forced.
def lap(+name: String, t0: Time.Duration, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ name ++ "\t" ++ U32.show(chk))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\t" ++ name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def last(r: Bytes.Bytes & Maybe<&2, U32>) -> U32:
  (b, x) = r
  match x:
    case None{}:
      0
    case Some{v}:
      v

# b rides along so that no timed op frees it.
def op.to_bytes.done(t0: Time.Duration, b: Bytes.Bytes, keep: A.F32Array) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  lap("to_bytes", t0, (len + last(Bytes.get(Bytes.Bytes{len, buf}, (len - 1 : U32))) : U32))

def op.to_bytes(c: A.F32Array, keep: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.to_bytes.done(t0, A.to_bytes.le(c), keep)

def op.add.chk(t0: Time.Duration, b: A.F32Array, r: A.F32Array & U32) -> IO(Unit):
  (c, +v) = r
  do IO<Unit>:
    lap("add", t0, v)
    op.to_bytes(c, b)

def op.add.done(t0: Time.Duration, r: A.F32Array & A.F32Array & Bool) -> IO(Unit):
  (c, b, ok) = r
  match ok:
    case False{}:
      IO.die(Unit, 1, "add: lengths differ")
    case True{}:
      op.add.chk(t0, b, ends(c))

def op.add(a: A.F32Array, b: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.add.done(t0, A.add(a, b))

def op.map.chk(t0: Time.Duration, b: A.F32Array, r: A.F32Array & U32) -> IO(Unit):
  (a, +v) = r
  do IO<Unit>:
    lap("map", t0, v)
    op.add(a, b)

def op.map(a: A.F32Array, b: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.map.chk(t0, b, ends(A.map(~twice, a)))

def op.dot.done(t0: Time.Duration, r: A.F32Array & A.F32Array & Maybe<&2, F32>) -> IO(Unit):
  (a, b, x) = r
  do IO<Unit>:
    lap("dot", t0, num(x))
    op.map(a, b)

def op.dot(a: A.F32Array, b: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.dot.done(t0, A.dot(a, b))

def op.max.done(t0: Time.Duration, b: A.F32Array, r: A.F32Array & Maybe<&2, F32>) -> IO(Unit):
  (a, x) = r
  do IO<Unit>:
    lap("max", t0, num(x))
    op.dot(a, b)

def op.max(a: A.F32Array, b: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.max.done(t0, b, A.max(a))

def op.sum.done(t0: Time.Duration, b: A.F32Array, r: A.F32Array & F32) -> IO(Unit):
  (a, x) = r
  do IO<Unit>:
    lap("sum", t0, F32.to_u32(x))
    op.max(a, b)

def op.sum(a: A.F32Array, b: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.sum.done(t0, b, A.sum(a))

def op.from.chk(t0: Time.Duration, b: A.F32Array, r: A.F32Array & U32) -> IO(Unit):
  (a, +v) = r
  do IO<Unit>:
    lap("from_bytes", t0, v)
    op.sum(a, b)

def op.from.done(t0: Time.Duration, b: A.F32Array, m: Maybe<&1, A.F32Array>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "from_bytes: unaligned")
    case Some{a}:
      op.from.chk(t0, b, ends(a))

def op.from(bytes: Bytes.Bytes, b: A.F32Array) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.from.done(t0, b, A.from_bytes.le(bytes))

def main() -> IO(Unit):
  op.from(A.to_bytes.le(ramp(1)), ramp(5))
