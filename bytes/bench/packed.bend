# Bytes benchmark: a packed Array<U32> byte buffer (see README.md).
import Base
import ../../time/time.bend as Time
import ../bytes.bend as Bytes

# Bytes as Array<U32>, 4 bytes per slot, little-endian: byte i = (w[i/4] >> 8*(i%4)) & 255.
# L = 28: N = 2^28 bytes, 2^26 words.

def b8(+x: U32) -> U32:
  (x .&. 255 : U32)

def unpack(+w: U32) -> U32:
  (b8(w) + b8((w >> 8n : U32)) + b8((w >> 16n : U32)) + (w >> 24n : U32) : U32)

def packw(+t: U32) -> U32:
  (b8(t) .|. (b8((t + 31 : U32)) << 8n) .|. (b8((t + 62 : U32)) << 16n) .|. (b8((t + 93 : U32)) << 24n) : U32)

def byte.of(+sh: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (b, w) = r
  (b, b8(U32.shrn(w, U32.to_nat(sh))))

# The Bytes read API: one byte at index i.
def byte(a: Array<U32>, +i: U32) -> Array<U32> & U32:
  byte.of(((i .&. 3 : U32) * 8 : U32), Array.get(U32, a, (i >> 2n : U32)))

def add2.of(+x: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (b, y) = r
  (b, (x + y : U32))

def add2(r: Array<U32> & U32, +j: U32) -> Array<U32> & U32:
  (b, x) = r
  add2.of(x, byte(b, j))

# fill
def fill(n: Nat, a: Array<U32>, +j: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fill(p, Array.set(U32, a, j, packw((j * 124 + 7 : U32))), (j + 1 : U32))

def fill.all() -> Array<U32>:
  Array.set(U32, fill(67108864n, Array.new(U32, 26n, 0), 0), 67108863, 168626701)

# sum, word at a time
def sum.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      (b, acc)
    case 1n+p:
      (b, +v) = r
      sum.go(p, Array.get(U32, b, (i + 1 : U32)), (i + 1 : U32), (acc + unpack(v) : U32))

# sum through byte(): what a caller of a Bytes.get API pays
def sumb.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      (b, acc)
    case 1n+p:
      (b, +v) = r
      sumb.go(p, byte(b, (i + 1 : U32)), (i + 1 : U32), (acc + v : U32))

# find \r\n\r\n with a 4-byte shift window; pattern is at the end, so no early exit is needed
def find.b(st: U32 & U32, +c: U32, +idx: U32) -> U32 & U32:
  (win, +res) = st
  +w2 = ((win << 8n) .|. c : U32)
  (w2, Bool.pick(U32, Bool.and(U32.is_eq(w2, 218762506), U32.is_eq(res, 4294967295)), (idx - 3 : U32), res))

def find.w(st: U32 & U32, +w: U32, +base: U32) -> U32 & U32:
  find.b(find.b(find.b(find.b(st, b8(w), base), b8((w >> 8n : U32)), (base + 1 : U32)), b8((w >> 16n : U32)), (base + 2 : U32)), (w >> 24n : U32), (base + 3 : U32))

def find.fin(b: Array<U32>, st: U32 & U32) -> Array<U32> & U32:
  (win, res) = st
  (b, res)

def find.go(n: Nat, r: Array<U32> & U32, st: U32 & U32, +i: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      find.fin(b, st)
    case 1n+p:
      (b, +v) = r
      find.go(p, Array.get(U32, b, (i + 1 : U32)), find.w(st, v, (i * 4 : U32)), (i + 1 : U32))

# find, SWAR: a word with no 13 byte holds no byte of a match, so skip it and reset the window
def has13(+w: U32) -> Bool:
  +v = (w .^. 218959117 : U32)
  U32.is_ne(((v - 16843009 : U32) .&. (v .^. 4294967295 : U32) .&. 2155905152 : U32), 0)

def findw.step(hit: Bool, st: U32 & U32, +w: U32, +base: U32) -> U32 & U32:
  match hit:
    case True{}:
      find.w(st, w, base)
    case False{}:
      (win, res) = st
      (0, res)

def findw.go(n: Nat, r: Array<U32> & U32, st: U32 & U32, +i: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      find.fin(b, st)
    case 1n+p:
      (b, +v) = r
      findw.go(p, Array.get(U32, b, (i + 1 : U32)), findw.step(has13(v), st, v, (i * 4 : U32)), (i + 1 : U32))

# slice bytes [N/4+1, N/4+1+N/2): unaligned, so each out word joins two source words
def slice.go(n: Nat, r: Array<U32> & U32, +prev: U32, out: Array<U32>, +j: U32, +k: U32) -> Array<U32> & Array<U32>:
  match n:
    case 0n:
      (b, w) = r
      (b, out)
    case 1n+p:
      (b, +w) = r
      slice.go(p, Array.get(U32, b, (k + 1 : U32)), w, Array.set(U32, out, j, ((prev >> 8n) .|. (w << 24n) : U32)), (j + 1 : U32), (k + 1 : U32))

def slice.start(r: Array<U32> & U32) -> Array<U32> & Array<U32>:
  (b, w0) = r
  slice.go(33554432n, Array.get(U32, b, 16777217), w0, Array.new(U32, 25n, 0), 0, 16777217)

# concat: 4096 fresh 64 KiB chunks, kept in a list (O(1) append), flattened once
def fillc(n: Nat, a: Array<U32>, +j: U32, +w: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fillc(p, Array.set(U32, a, j, w), (j + 1 : U32), w)

def chunk(+k: U32) -> Array<U32>:
  fillc(16384n, Array.new(U32, 14n, 0), 0, (b8(k) * 16843009 : U32))

def collect(n: Nat, +k: U32, acc: List<Array<U32>>) -> List<Array<U32>>:
  match n:
    case 0n:
      acc
    case 1n+p:
      collect(p, (k + 1 : U32), Con{chunk(k), acc})

def copyc(n: Nat, r: Array<U32> & U32, out: Array<U32>, +j: U32, +off: U32) -> Array<U32>:
  match n:
    case 0n:
      out
    case 1n+p:
      (c, w) = r
      copyc(p, Array.get(U32, c, (j + 1 : U32)), Array.set(U32, out, (off + j : U32), w), (j + 1 : U32), off)

def flatten(xs: List<Array<U32>>, out: Array<U32>, +off: U32) -> Array<U32>:
  match xs:
    case Nil{}:
      out
    case Con{c, t}:
      flatten(t, copyc(16384n, Array.get(U32, c, 0), out, 0, off), (off - 16384 : U32))

def concat() -> Array<U32>:
  flatten(collect(4096n, 0, Nil{}), Array.new(U32, 26n, 0), 67092480)

# random reads through byte()
def rnd.go(n: Nat, r: Array<U32> & U32, +x: U32, acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (b, v) = r
      (b, (acc + v : U32))
    case 1n+p:
      (b, v) = r
      +x2 = (x * 1664525 + 1013904223 : U32)
      rnd.go(p, byte(b, (x2 >> 4n : U32)), x2, (acc + v : U32))

# equal, word at a time
def eq.fin(r1: Array<U32> & U32, r2: Array<U32> & U32, ok: Bool) -> Array<U32> & U32:
  (a, x) = r1
  (c, y) = r2
  (a, Bool.pick(U32, Bool.and(ok, U32.is_eq(x, y)), 1, 0))

def eq.go(n: Nat, r1: Array<U32> & U32, r2: Array<U32> & U32, +i: U32, ok: Bool) -> Array<U32> & U32:
  match n:
    case 0n:
      eq.fin(r1, r2, ok)
    case 1n+p:
      (a, +x) = r1
      (c, +y) = r2
      eq.go(p, Array.get(U32, a, (i + 1 : U32)), Array.get(U32, c, (i + 1 : U32)), (i + 1 : U32), Bool.and(ok, U32.is_eq(x, y)))

def eq.start(ac: Array<U32> & Array<U32>) -> Array<U32> & U32:
  (a, c) = ac
  eq.go(67108864n, (a, 0), (c, 0), 4294967295, True{})

# ops, timed in-process. The checksum is printed before the second clock read so it is forced.
def lap(+name: String, t0: Time.Duration, +chk: U32) -> IO(Unit):
  do IO<Unit>:
    IO.print("chk\t" ++ name ++ "\t" ++ U32.show(chk))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\t" ++ name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def build.go(n: Nat, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      build.go(p, Bytes.append(b, Bytes.set(Bytes.new(1), 0, (i .&. 255 : U32))), (i + 1 : U32))

def build.check(r: Bytes.Bytes & Maybe<&2, U32>, +n: U32) -> U32:
  (b, v) = r
  match v:
    case Some{x}:
      (n + x : U32)
    case None{}:
      0

def build.done(b: Bytes.Bytes, +n: U32) -> U32:
  build.check(Bytes.get(b, (n - 1 : U32)), n)

def op.build(+n: U32, +name: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    lap(name, t0, build.done(build.go(U32.to_nat(n), Bytes.new(0), 0), n))

def op.equal.done(t0: Time.Duration, r: Array<U32> & U32) -> IO(Unit):
  (a, v) = r
  do IO<Unit>:
    lap("equal", t0, v)
    op.build(1000000, "build_1000000")
    op.build(4000000, "build_4000000")

def op.equal(ac: Array<U32> & Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.equal.done(t0, eq.start(ac))

def op.random.done(t0: Time.Duration, r: Array<U32> & U32) -> IO(Unit):
  (a, v) = r
  do IO<Unit>:
    lap("random", t0, v)
    op.equal(Array.clone(U32, a))

def op.random(a: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.random.done(t0, rnd.go(16777216n, (a, 0), 1, 0))

def op.concat.done(t0: Time.Duration, a: Array<U32>, r: Array<U32> & U32) -> IO(Unit):
  (o, v) = r
  do IO<Unit>:
    lap("concat", t0, v)
    op.random(a)

def op.concat(a: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.concat.done(t0, a, add2(byte(concat(), 0), 268435455))

def op.slice.chk(t0: Time.Duration, a: Array<U32>, r: Array<U32> & U32) -> IO(Unit):
  (s, v) = r
  do IO<Unit>:
    lap("slice", t0, v)
    op.concat(a)

def op.slice.done(t0: Time.Duration, r: Array<U32> & Array<U32>) -> IO(Unit):
  (a, s) = r
  op.slice.chk(t0, a, add2(byte(s, 0), 134217727))

def op.slice(a: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.slice.done(t0, slice.start(Array.get(U32, a, 16777216)))

def op.findw.done(t0: Time.Duration, r: Array<U32> & U32) -> IO(Unit):
  (a, v) = r
  do IO<Unit>:
    lap("find_swar", t0, v)
    op.slice(a)

def op.findw(a: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.findw.done(t0, findw.go(67108864n, Array.get(U32, a, 0), (0, 4294967295), 0))

def op.find.done(t0: Time.Duration, r: Array<U32> & U32) -> IO(Unit):
  (a, v) = r
  do IO<Unit>:
    lap("find", t0, v)
    op.findw(a)

def op.find(a: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.find.done(t0, find.go(67108864n, Array.get(U32, a, 0), (0, 4294967295), 0))

def op.sum2.done(t0: Time.Duration, r: Array<U32> & U32) -> IO(Unit):
  (a, v) = r
  do IO<Unit>:
    lap("sum_again", t0, v)
    op.find(a)

def op.sum2(a: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.sum2.done(t0, sum.go(67108864n, Array.get(U32, a, 0), 0, 0))

def op.sumb.done(t0: Time.Duration, r: Array<U32> & U32) -> IO(Unit):
  (a, v) = r
  do IO<Unit>:
    lap("sum_bytewise", t0, v)
    op.sum2(a)

def op.sumb(a: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.sumb.done(t0, sumb.go(268435456n, byte(a, 0), 0, 0))

def op.sum.done(t0: Time.Duration, r: Array<U32> & U32) -> IO(Unit):
  (a, v) = r
  do IO<Unit>:
    lap("sum", t0, v)
    op.sumb(a)

def op.sum(a: Array<U32>) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.sum.done(t0, sum.go(67108864n, Array.get(U32, a, 0), 0, 0))

def op.fill.done(t0: Time.Duration, r: Array<U32> & U32) -> IO(Unit):
  (a, v) = r
  do IO<Unit>:
    lap("fill", t0, v)
    op.sum(a)

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.fill.done(t0, add2(byte(fill.all(), 12345), 268435455))
