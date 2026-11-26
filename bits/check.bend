import Base
import ./bits.bend as Bits
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

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

def at_end.left(+ok: Bool, r: Bits.Reader & Nat) -> Bool:
  (rd, +left) = r
  Bool.and(ok, Nat.is_lt(left, 8n))

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

def enc.puts(xs: List<&2, Bits.Encoding>, +msb: Bool, w: Bits.Writer) -> Bits.Writer:
  match xs:
    case Nil{}:
      w
    case Con{e, t}:
      enc.puts(t, msb, Bits.Writer.code(msb, w, e))

def enc.decs(xs: List<&2, Bits.Encoding>, st: Bits.Huff & Bits.Reader & Bool) -> Bool:
  match xs:
    case Nil{}:
      (h, rd, ok) = st
      ok
    case Con{Bits.Encoding{+sym, len, value}, t}:
      enc.decs(t, decs.step(sym, st))

def enc.table(m: Maybe<&1, Bits.Huff>, +xs: List<&2, Bits.Encoding>, +msb: Bool) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{h}:
      enc.decs(xs, (h, Bits.Reader.new(Bits.Writer.finish(enc.puts(xs, msb, Bits.Writer.new()))), True{}))

def enc.codes(m: Maybe<&2, List<&2, Bits.Encoding>>, +cs: List<&2, Bits.Code>, +msb: Bool) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{xs}:
      enc.table(Bits.Huff.from_codes(msb, cs), xs, msb)

def enc.run(+msb: Bool, +cs: List<&2, Bits.Code>) -> Bool:
  enc.codes(Bits.Huff.encode_codes(cs), cs, msb)

def enc.rejected(m: Maybe<&2, List<&2, Bits.Encoding>>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{xs}:
      False{}

def enc.empty(m: Maybe<&2, List<&2, Bits.Encoding>>) -> Bool:
  match m:
    case Some{Nil{}}:
      True{}
    case _:
      False{}

def enc.fixture(m: Maybe<&2, List<&2, Bits.Encoding>>) -> Bool:
  match m:
    case Some{[Bits.Encoding{66, 2, 2}, Bits.Encoding{9, 1, 0}, Bits.Encoding{7, 2, 3}]}:
      True{}
    case _:
      False{}

def rejected.pos(r: Bytes.Bytes & Nat) -> Bool:
  (b, pos) = r
  Nat.is_eq(pos, 0n)

def rejected.got(r: Bits.Huff & Bits.Reader & Maybe<&2, U32>) -> Bool:
  (h, rd, m) = r
  match m:
    case None{}:
      rejected.pos(Bits.Reader.finish(rd))
    case Some{s}:
      False{}

def rejected.table(m: Maybe<&1, Bits.Huff>, s: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{h}:
      rejected.got(Bits.Huff.decode(h, Bits.Reader.new(Bytes.from_string(s))))

# An order switch inside a byte would land on bits the earlier field already set.
def mixed() -> Bool:
  w = Bits.Writer.lsb(Bits.Writer.msb(Bits.Writer.lsb(Bits.Writer.new(), 1, 1), 7, 0), 3, 5)
  String.eq(Bytes.to_string(Bits.Writer.finish(w)), "\u{1}\u{0}\u{5}")

def mixed.last(ok: Bool, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, c) = r
  Bool.and(ok, same(c, 5))

def mixed.second(+msb: Bool, a: Maybe<&2, U32>, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, b) = r
  mixed.last(Bool.and(same(a, 1), same(b, 0)), get(msb, rd, 3))

def mixed.first(+msb: Bool, n: U32, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, a) = r
  mixed.second(msb, a, get(Bool.not(msb), rd, n))

def mixed.read(+msb: Bool, +n: U32) -> Bool:
  w = put(msb, put(Bool.not(msb), put(msb, Bits.Writer.new(), 1, 1), n, 0), 3, 5)
  mixed.first(msb, n, get(msb, Bits.Reader.new(Bits.Writer.finish(w)), 1))

def read.is(want: U32, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, value) = r
  same(value, want)

def mixed.failed(r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, value) = r
  match value:
    case None{}:
      read.is(2, Bits.Reader.lsb(rd, 3))
    case Some{v}:
      False{}

def mixed.reject.first(n: U32, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, value) = r
  mixed.failed(Bits.Reader.msb(rd, n))

def mixed.reject(n: U32) -> Bool:
  rd = Bits.Reader.new(Bytes.from_string("\u{5}\u{0}"))
  mixed.reject.first(n, Bits.Reader.lsb(rd, 1))

def mixed.peeked(r: Bits.Reader & U32) -> Bool:
  (rd, value) = r
  Bool.and(U32.is_eq(value, 6), read.is(2, Bits.Reader.lsb(rd, 3)))

def mixed.peek.first(r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, value) = r
  mixed.peeked(Bits.Reader.peek.msb(rd, 3))

def mixed.peek() -> Bool:
  mixed.peek.first(Bits.Reader.lsb(Bits.Reader.new(Bytes.from_string("\u{5}\u{C0}")), 1))

def mixed.decoded(r: Bits.Huff & Bits.Reader & Maybe<&2, U32>) -> Bool:
  (h, rd, value) = r
  Bool.and(same(value, 1), read.is(5, Bits.Reader.lsb(rd, 3)))

def mixed.decode.first(h: Bits.Huff, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, value) = r
  mixed.decoded(Bits.Huff.decode(h, rd))

def mixed.decode.table(m: Maybe<&1, Bits.Huff>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{h}:
      w = Bits.Writer.lsb(Bits.Writer.msb(Bits.Writer.lsb(Bits.Writer.new(), 1, 1), 1, 1), 3, 5)
      mixed.decode.first(h, Bits.Reader.lsb(Bits.Reader.new(Bits.Writer.finish(w)), 1))

def mixed.decode.failed(r: Bits.Huff & Bits.Reader & Maybe<&2, U32>) -> Bool:
  (h, rd, value) = r
  mixed.failed((rd, value))

def mixed.decode.reject.first(h: Bits.Huff, r: Bits.Reader & Maybe<&2, U32>) -> Bool:
  (rd, value) = r
  mixed.decode.failed(Bits.Huff.decode(h, rd))

def mixed.decode.reject(m: Maybe<&1, Bits.Huff>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{h}:
      mixed.decode.reject.first(h, Bits.Reader.lsb(Bits.Reader.new(Bytes.from_string("\u{5}\u{80}")), 1))

def main() -> IO(Unit):
  do IO<Unit>:
    expect("lsb roundtrip, 20000 fields", roundtrip(False{}, 20000n, 12345))
    expect("msb roundtrip, 20000 fields", roundtrip(True{}, 20000n, 777))
    expect("fixed deflate decode, 50000 symbols", fixed.run(Bits.Huff.from_lens(False{}, fixed.lens()), 50000n, 99))
    expect("16-bit msb codes decode", deep.run(Bits.Huff.from_lens(True{}, deep.lens())))
    expect("writer small lsb", enc.run(False{}, Bits.codes([2, 1, 3, 3], 0)))
    expect("writer small msb", enc.run(True{}, Bits.codes([2, 1, 3, 3], 0)))
    expect("writer fixed lsb", enc.run(False{}, Bits.codes(fixed.lens(), 0)))
    expect("writer fixed msb", enc.run(True{}, Bits.codes(fixed.lens(), 0)))
    expect("writer 16-bit codes", enc.run(False{}, Bits.codes(deep.lens(), 0)))
    expect("secondary tables lsb", enc.run(False{}, Bits.codes([0, 9, 10, 10, 15, 16, 16], 0)))
    expect("secondary tables msb", enc.run(True{}, Bits.codes([0, 9, 10, 10, 15, 16, 16], 0)))
    expect("unused secondary lsb", rejected.table(Bits.Huff.from_lens(False{}, [10]), "\u{0}\u{2}"))
    expect("unused secondary msb", rejected.table(Bits.Huff.from_lens(True{}, [10]), "\u{0}\u{40}"))
    expect("truncated secondary lsb", rejected.table(Bits.Huff.from_lens(False{}, [10]), "\u{0}"))
    expect("truncated secondary msb", rejected.table(Bits.Huff.from_lens(True{}, [10]), "\u{0}"))
    expect("writer sparse list order", enc.fixture(Bits.Huff.encode_codes([Bits.Code{66, 2}, Bits.Code{3, 0}, Bits.Code{9, 1}, Bits.Code{7, 2}])))
    expect("writer empty", enc.empty(Bits.Huff.encode_lens([])))
    expect("writer zero lengths", enc.empty(Bits.Huff.encode_lens([0, 0])))
    expect("writer incomplete", enc.run(True{}, [Bits.Code{8, 16}]))
    expect("writer over-subscribed", enc.rejected(Bits.Huff.encode_lens([1, 1, 1])))
    expect("writer too long", enc.rejected(Bits.Huff.encode_lens([17])))
    expect("order switch starts a new byte", mixed())
    expect("mixed lsb reads align", mixed.read(False{}, 7))
    expect("mixed msb reads align", mixed.read(True{}, 7))
    expect("zero-width msb switch aligns", mixed.read(False{}, 0))
    expect("zero-width lsb switch aligns", mixed.read(True{}, 0))
    expect("failed order switch keeps position and order", mixed.reject(9))
    expect("invalid width keeps position and order", mixed.reject(33))
    expect("mixed peek aligns without moving", mixed.peek())
    expect("mixed Huffman reads align", mixed.decode.table(Bits.Huff.from_lens(True{}, [1, 1])))
    expect("failed Huffman switch keeps position and order", mixed.decode.reject(Bits.Huff.from_lens(True{}, [1])))

