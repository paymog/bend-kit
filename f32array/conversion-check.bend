import Base
import ./f32array.bend as A
import ./io.bend as F
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def expect(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "FAIL native byte conversion")

def same(r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bool:
  (a, b, ok) = r
  ok

def source(+n: U32, +word: U32) -> Bytes.Bytes:
  Bytes.Bytes{(n << 2n : U32), Array.new(U32, Bytes.depth(n), word)}

def padded.go(k: Nat, r: Array<A.Cell> & F32, +i: U32) -> IO(Unit):
  match k:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      (buf, x) = r
      do IO<Unit>:
        expect(U32.is_eq(A.to_bits(x), 0))
        padded.go(p, A.peek(buf, (i + 1 : U32)), (i + 1 : U32))

def padded.size(+n: U32, r: Array<A.Cell> & U32) -> IO(Unit):
  (buf, +size) = r
  do IO<Unit>:
    expect(U32.is_eq(size, (1 << Bytes.depth(A.cells(n)) : U32)))
    padded.go(U32.to_nat(((size << 3n : U32) - n : U32)), A.peek(buf, n), n)

def padded(m: Maybe<&1, A.F32Array>) -> IO(Unit):
  match m:
    case None{}:
      expect(False{})
    case Some{A.F32Array{+len, buf}}:
      padded.size(len, Array.size(A.Cell, buf))

def encode(m: Maybe<&1, A.F32Array>, +big: U32) -> IO(Bytes.Bytes):
  match m:
    case None{}:
      IO.die(Bytes.Bytes, 1, "FAIL aligned conversion rejected")
    case Some{a}:
      F.to_bytes.with(a, big)

def rejected(m: Maybe<&1, A.F32Array>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{a}:
      False{}

def filled(+n: U32, +word: U32) -> A.F32Array:
  +x = A.of_bits(word)
  A.F32Array{n, A.trim(Array.new(A.Cell, Bytes.depth(A.cells(n)), A.Cell{x, x, x, x, x, x, x, x}), n)}

def expected(little: Bool, a: A.F32Array) -> Bytes.Bytes:
  match little:
    case True{}:
      A.to_bytes.le(a)
    case False{}:
      A.to_bytes.be(a)

def check(+n: U32, +word: U32, +big: U32) -> IO(Unit):
  do IO<Unit>:
    a : Maybe<&1, A.F32Array> <- F.from_bytes.with(source(n, word), big)
    b : Bytes.Bytes <- encode(a, big)
    expect(same(Bytes.eq(b, source(n, A.to_bits(A.of_bits(word))))))
    a : Maybe<&1, A.F32Array> <- F.from_bytes.with(source(n, word), big)
    padded(a)
    b : Bytes.Bytes <- F.to_bytes.with(filled(n, word), big)
    expect(same(Bytes.eq(b, expected(U32.is_eq(big, 0), filled(n, word)))))

def sizes(n: Nat, +i: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        check(i, 2147483648, 0)
        check(i, 1, 0)
        check(i, 2139095040, 0)
        check(i, 1065353216, 1)
        sizes(p, (i + 1 : U32))

def run() -> IO(Unit):
  do IO<Unit>:
    sizes(34n, 0)
    check(9, 2143289345, 0)
    check(1025, 1065353216, 0)
    check(1025, 1065353216, 1)
    m : Maybe<&1, A.F32Array> <- F.from_bytes.le(Bytes.new(3))
    expect(rejected(m))
    m : Maybe<&1, A.F32Array> <- F.from_bytes.be(Bytes.new(5))
    expect(rejected(m))
    IO.print("ok native byte conversions")
