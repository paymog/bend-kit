import Base
import ./bits.bend as Bits
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

# The laws run in the checker on short streams. This runs long ones on the native Array:
# many writer doublings, every width from 0 to 32 at every bit offset, and long Huffman runs.

def expect(+name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def lcg(+x: U32) -> U32:
  (x * 1664525 + 1013904223 : U32)

# Field i of a seeded run: a width from 0 to 32 and a value with stray high bits.
def width(+x: U32) -> U32:
  ((x >> 26n) % 33 : U32)

def put(msb: Bool, w: Bits.Writer, +n: U32, +v: U32) -> Bits.Writer:
  match msb:
    case True{}:
      Bits.Writer.msb(w, n, v)
    case False{}:
      Bits.Writer.lsb(w, n, v)

def puts(k: Nat, +msb: Bool, w: Bits.Writer, +x: U32) -> Bits.Writer:
  match k:
    case 0n:
      w
    case 1n+p:
      puts(p, msb, put(msb, w, width(x), lcg(x)), lcg(lcg(x)))

def get(msb: Bool, r: Bits.Reader, +n: U32) -> Bits.Reader & Maybe<&2, U32>:
  match msb:
    case True{}:
      Bits.Reader.msb(r, n)
    case False{}:
      Bits.Reader.lsb(r, n)

def same(m: Maybe<&2, U32>, +v: U32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{x}:
      U32.is_eq(x, v)

# ok stays True while every field reads back as its low n bits.
def gets(k: Nat, +msb: Bool, +x: U32, +ok: Bool, r: Bits.Reader & Maybe<&2, U32>, +want: U32) -> Bits.Reader & Bool:
  match k:
    case 0n:
      (rd, m) = r
      (rd, Bool.and(ok, same(m, want)))
    case 1n+p:
      (rd, m) = r
      +n = width(x)
      gets(p, msb, lcg(lcg(x)), Bool.and(ok, same(m, want)), get(msb, rd, n), (lcg(x) .&. Bits.mask(n) : U32))

def at_end.left(+ok: Bool, r: Bits.Reader & U32) -> Bool:
  (rd, +left) = r
  Bool.and(ok, U32.is_lt(left, 8))

def at_end(r: Bits.Reader & Bool) -> Bool:
  (rd, +ok) = r
  at_end.left(ok, Bits.Reader.left(rd))

def roundtrip(+msb: Bool, +k: Nat, +seed: U32) -> Bool:
  b = Bits.Writer.finish(puts(k, msb, Bits.Writer.new(), seed))
  at_end(gets(k, msb, seed, True{}, (Bits.Reader.new(b), Some{0}), 0))

def rep(k: Nat, +v: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+p:
      rep(p, v, Con{v, acc})

def rev(k: Nat, +v: U32, +acc: U32) -> U32:
  match k:
    case 0n:
      acc
    case 1n+p:
      rev(p, U32.shrn(v, 1n), ((acc << 1n) .|. (v .&. 1) : U32))

# RFC 1951 §3.2.6, as the laws state it.
def fixed.lens() -> List<&2, U32>:
  rep(144n, 8, rep(112n, 9, rep(24n, 7, rep(8n, 8, Nil{}))))

def fixed.put(w: Bits.Writer, +s: U32) -> Bits.Writer:
  +c = Bool.pick(U32, U32.is_lt(s, 144), (s + 48 : U32), Bool.pick(U32, U32.is_lt(s, 256), (s + 256 : U32), Bool.pick(U32, U32.is_lt(s, 280), (s - 256 : U32), (s - 88 : U32))))
  +n = Bool.pick(U32, U32.is_lt(s, 144), 8, Bool.pick(U32, U32.is_lt(s, 256), 9, Bool.pick(U32, U32.is_lt(s, 280), 7, 8)))
  Bits.Writer.lsb(w, n, rev(U32.to_nat(n), c, 0))

def fixed.puts(k: Nat, w: Bits.Writer, +x: U32) -> Bits.Writer:
  match k:
    case 0n:
      w
    case 1n+p:
      fixed.puts(p, fixed.put(w, ((x >> 8n) % 288 : U32)), lcg(x))

def decs.got(ok: Bool, +want: U32, r: Bits.Huff & Bits.Reader & Maybe<&2, U32>) -> Bits.Huff & Bits.Reader & Bool:
  (h, rd, m) = r
  (h, rd, Bool.and(ok, same(m, want)))

def decs.step(+want: U32, st: Bits.Huff & Bits.Reader & Bool) -> Bits.Huff & Bits.Reader & Bool:
  (h, rd, ok) = st
  decs.got(ok, want, Bits.Huff.decode(h, rd))

def decs(k: Nat, +x: U32, st: Bits.Huff & Bits.Reader & Bool) -> Bool:
  match k:
    case 0n:
      (h, rd, ok) = st
      ok
    case 1n+p:
      decs(p, lcg(x), decs.step(((x >> 8n) % 288 : U32), st))

def fixed.run(m: Maybe<&1, Bits.Huff>, +k: Nat, +seed: U32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{h}:
      decs(k, seed, (h, Bits.Reader.new(Bits.Writer.finish(fixed.puts(k, Bits.Writer.new(), seed))), True{}))

# A complete code with lengths 1 to 16 and one extra 16: 0, 10, 110, ..., 1...10, 1...11.
def deep.lens() -> List<&2, U32>:
  [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 16]

def deep.code(+s: U32) -> U32:
  Bool.pick(U32, U32.is_eq(s, 16), 65535, (U32.shln(1, U32.to_nat((s + 1 : U32))) - 2 : U32))

def deep.puts(k: Nat, w: Bits.Writer, +s: U32) -> Bits.Writer:
  match k:
    case 0n:
      w
    case 1n+p:
      deep.puts(p, Bits.Writer.msb(w, U32.min((s + 1 : U32), 16), deep.code(s)), (s + 1 : U32))

def deep.decs(k: Nat, +s: U32, st: Bits.Huff & Bits.Reader & Bool) -> Bool:
  match k:
    case 0n:
      (h, rd, ok) = st
      ok
    case 1n+p:
      deep.decs(p, (s + 1 : U32), decs.step(s, st))

def deep.run(m: Maybe<&1, Bits.Huff>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{h}:
      deep.decs(17n, 0, (h, Bits.Reader.new(Bits.Writer.finish(deep.puts(17n, Bits.Writer.new(), 0))), True{}))

def main() -> IO(Unit):
  do IO<Unit>:
    expect("lsb roundtrip, 20000 fields", roundtrip(False{}, 20000n, 12345))
    expect("msb roundtrip, 20000 fields", roundtrip(True{}, 20000n, 777))
    expect("fixed deflate decode, 50000 symbols", fixed.run(Bits.Huff.from_lens(False{}, fixed.lens()), 50000n, 99))
    expect("16-bit msb codes decode", deep.run(Bits.Huff.from_lens(True{}, deep.lens())))
