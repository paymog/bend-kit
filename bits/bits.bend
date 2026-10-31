# Bit readers and writers over Bytes, LSB-first (DEFLATE) or MSB-first (JPEG), and canonical Huffman decode tables. Source: https://github.com/paymog/bend-kit/tree/main/bits
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

# Bytes packs byte i at bits 8*(i%4) of word i/4, so LSB-first stream bit p is bit p%32 of
# word p/32, and MSB-first it is bit 31 - p%32 of that word byte-swapped.
# A U32 shift by 32 or more gives 0; the code below relies on it.
# ponytail: positions are U32 bit counts, so a stream holds under 512 MiB; widen to U64 if that bites.

def mask(+n: U32) -> U32:
  (U32.shln(1, U32.to_nat(n)) - 1 : U32)

def win.lsb.join(+s: U32, +lo: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, +hi) = r
  (a, (U32.shrn(lo, U32.to_nat(s)) .|. U32.shln(hi, U32.to_nat((32 - s : U32))) : U32))

def win.msb.join(+s: U32, +lo: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, +hi) = r
  (a, (U32.shln(Bytes.bswap(lo), U32.to_nat(s)) .|. U32.shrn(Bytes.bswap(hi), U32.to_nat((32 - s : U32))) : U32))

def win.lsb.at(+p: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, +lo) = r
  win.lsb.join((p .&. 31 : U32), lo, Array.get(U32, a, ((p >> 5n) + 1 : U32)))

def win.msb.at(+p: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, +lo) = r
  win.msb.join((p .&. 31 : U32), lo, Array.get(U32, a, ((p >> 5n) + 1 : U32)))

# The 32 stream bits from bit p, in stream order: first bit lowest LSB-first, highest MSB-first.
# Bits past the buffer's last word wrap to its first, so callers mask what lies past the end.
def win(msb: Bool, a: Array<U32>, +p: U32) -> Array<U32> & U32:
  match msb:
    case True{}:
      win.msb.at(p, Array.get(U32, a, (p >> 5n : U32)))
    case False{}:
      win.lsb.at(p, Array.get(U32, a, (p >> 5n : U32)))

# The first n (at most 32) bits of a window as a number, first stream bit most significant MSB-first.
def field(+msb: Bool, +n: U32, +w: U32) -> U32:
  Bool.pick(U32, msb, U32.shrn(w, U32.to_nat((32 - n : U32))), (w .&. mask(n) : U32))

# A reader owns the buffer of len bytes; pos is the next bit.
type Reader is Type:
  Reader{len: U32, buf: Array<U32>, pos: U32}

def Reader.new(b: Bytes.Bytes) -> Reader:
  Bytes.Bytes{len, buf} = b
  Reader{len, buf, 0}

# The buffer back, and the bit position.
def Reader.finish(r: Reader) -> Bytes.Bytes & U32:
  Reader{len, buf, pos} = r
  (Bytes.Bytes{len, buf}, pos)

def Reader.left(r: Reader) -> Reader & U32:
  Reader{+len, buf, +pos} = r
  (Reader{len, buf, pos}, ((len << 3n) - pos : U32))

def read.got(+msb: Bool, +len: U32, +pos: U32, +n: U32, r: Array<U32> & U32) -> Reader & Maybe<&2, U32>:
  (a, +w) = r
  (Reader{len, a, (pos + n : U32)}, Some{field(msb, n, w)})

def read.if(ok: Bool, +msb: Bool, +len: U32, buf: Array<U32>, +pos: U32, +n: U32) -> Reader & Maybe<&2, U32>:
  match ok:
    case True{}:
      read.got(msb, len, pos, n, win(msb, buf, pos))
    case False{}:
      (Reader{len, buf, pos}, None{})

def read(+msb: Bool, r: Reader, +n: U32) -> Reader & Maybe<&2, U32>:
  Reader{+len, buf, +pos} = r
  read.if(U32.is_le(n, U32.min(32, ((len << 3n) - pos : U32))), msb, len, buf, pos, n)

# The next n bits (0 to 32) as a number, and the reader past them. None, with the reader
# unchanged, when n > 32 or fewer than n bits are left.
def Reader.lsb(r: Reader, +n: U32) -> Reader & Maybe<&2, U32>:
  read(False{}, r, n)

def Reader.msb(r: Reader, +n: U32) -> Reader & Maybe<&2, U32>:
  read(True{}, r, n)

# Bits past the end read as 0: the low avail bits stay LSB-first, the high ones MSB-first.
def peek.got(+msb: Bool, +len: U32, +pos: U32, +n: U32, +avail: U32, r: Array<U32> & U32) -> Reader & U32:
  (a, +w) = r
  +v = field(msb, n, w)
  (Reader{len, a, pos}, Bool.pick(U32, msb, (v .&. U32.shln(4294967295, U32.to_nat((n - avail : U32))) : U32), (v .&. mask(avail) : U32)))

def peek(+msb: Bool, r: Reader, +n0: U32) -> Reader & U32:
  Reader{+len, buf, +pos} = r
  +n = U32.min(n0, 32)
  peek.got(msb, len, pos, n, U32.min(n, ((len << 3n) - pos : U32)), win(msb, buf, pos))

# The next n bits (at most 32) without moving. Bits past the end read as 0.
def Reader.peek.lsb(r: Reader, +n: U32) -> Reader & U32:
  peek(False{}, r, n)

def Reader.peek.msb(r: Reader, +n: U32) -> Reader & U32:
  peek(True{}, r, n)

# Moves n bits on. False, with the reader unchanged, when fewer than n are left.
def Reader.skip(r: Reader, +n: U32) -> Reader & Bool:
  Reader{+len, buf, +pos} = r
  +ok = U32.is_le(n, ((len << 3n) - pos : U32))
  (Reader{len, buf, Bool.pick(U32, ok, (pos + n : U32), pos)}, ok)

# Moves to the next byte boundary, as a DEFLATE stored block or a JPEG marker needs.
def Reader.align(r: Reader) -> Reader:
  Reader{len, buf, +pos} = r
  Reader{len, buf, ((pos + 7) .&. 4294967288 : U32)}

# A writer's buf has 2^dep words, all 0 past bit pos.
type Writer is Type:
  Writer{buf: Array<U32>, dep: U32, pos: U32}

def Writer.new() -> Writer:
  Writer{Array.new(U32, 0n, 0), 0, 0}

# A write adds at most 32 bits, so one doubling always makes room.
def room(full: Bool, w: Writer) -> Writer:
  match full:
    case False{}:
      w
    case True{}:
      Writer{buf, +dep, pos} = w
      Writer{Bytes.dst(Bytes.copy(U32.shln(4, U32.to_nat(dep)), buf, Array.new(U32, U32.to_nat((dep + 1 : U32)), 0), 0, 0)), (dep + 1 : U32), pos}

def or.of(+k: U32, +x: U32, r: Array<U32> & U32) -> Array<U32>:
  (a, +old) = r
  Array.set(U32, a, k, (old .|. x : U32))

def or.if(some: Bool, a: Array<U32>, +k: U32, +x: U32) -> Array<U32>:
  match some:
    case True{}:
      or.of(k, x, Array.get(U32, a, k))
    case False{}:
      a

# The parts of an n-bit v that land in word k and word k + 1, as stored words.
def parts(msb: Bool, +s: U32, +n: U32, +v: U32) -> U32 & U32:
  match msb:
    case True{}:
      +t = U32.shln(v, U32.to_nat((32 - n : U32)))
      (Bytes.bswap(U32.shrn(t, U32.to_nat(s))), Bytes.bswap(U32.shln(t, U32.to_nat((32 - s : U32)))))
    case False{}:
      +m = (v .&. mask(n) : U32)
      (U32.shln(m, U32.to_nat(s)), U32.shrn(m, U32.to_nat((32 - s : U32))))

def write.put(+k: U32, x: U32 & U32, a: Array<U32>) -> Array<U32>:
  (+x0, +x1) = x
  or.if(U32.is_ne(x1, 0), or.if(U32.is_ne(x0, 0), a, k, x0), (k + 1 : U32), x1)

def write.at(+msb: Bool, w: Writer, +n: U32, +v: U32) -> Writer:
  Writer{buf, dep, +pos} = w
  Writer{write.put((pos >> 5n : U32), parts(msb, (pos .&. 31 : U32), n, v), buf), dep, (pos + n : U32)}

def write(+msb: Bool, w: Writer, +n0: U32, +v: U32) -> Writer:
  Writer{buf, +dep, +pos} = w
  +n = U32.min(n0, 32)
  write.at(msb, room(U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((pos + n + 31) >> 5n : U32)), Writer{buf, dep, pos}), n, v)

# Appends the low n bits of v (n is cut to 32). LSB-first sends v's lowest bit first;
# MSB-first sends bit n - 1 first.
def Writer.lsb(w: Writer, +n: U32, +v: U32) -> Writer:
  write(False{}, w, n, v)

def Writer.msb(w: Writer, +n: U32, +v: U32) -> Writer:
  write(True{}, w, n, v)

# Pads with 0 bits to the next byte boundary.
def Writer.align(w: Writer) -> Writer:
  Writer{buf, dep, +pos} = w
  Writer{buf, dep, ((pos + 7) .&. 4294967288 : U32)}

# The bytes written; 0 bits fill the last byte.
def Writer.finish(w: Writer) -> Bytes.Bytes:
  Writer{buf, dep, +pos} = w
  Bytes.Bytes{((pos + 7) >> 3n : U32), buf}

# A canonical Huffman table: entry i of 2^max is (sym << 5) | len for the code that the
# first max stream bits i start with, or 0 when no code does. msb is the stream's bit order.
# ponytail: one level of 2^max entries; a two-level table if building it dominates short blocks.
type Huff is Type:
  Huff{msb: Bool, max: U32, table: Array<U32>}

# One symbol and the length of its code.
type Code is Data:
  Code{sym: U32, len: U32}

def lens.max(xs: List<&2, Code>, +m: U32) -> U32:
  match xs:
    case Nil{}:
      m
    case Con{Code{sym, +len}, t}:
      lens.max(t, U32.max(m, len))

def count.of(+len: U32, r: Array<U32> & U32) -> Array<U32>:
  (c, +v) = r
  Array.set(U32, c, len, (v + 1 : U32))

def count.if(zero: Bool, c: Array<U32>, +len: U32) -> Array<U32>:
  match zero:
    case True{}:
      c
    case False{}:
      count.of(len, Array.get(U32, c, len))

def count(xs: List<&2, Code>, c: Array<U32>) -> Array<U32>:
  match xs:
    case Nil{}:
      c
    case Con{Code{sym, +len}, t}:
      count(t, count.if(U32.is_eq(len, 0), c, len))

# RFC 1951 §3.2.2: next[l] = (next[l-1] + count[l-1]) << 1. r holds count[l-1]; left counts
# the codes of length l - 1 still free, and a negative left means the lengths over-subscribe.
def next.go(k: Nat, +l: U32, +code: U32, +left: U32, +ok: Bool, n: Array<U32>, r: Array<U32> & U32) -> Array<U32> & Bool:
  match k:
    case 0n:
      (c, v) = r
      (n, ok)
    case 1n+p:
      (c, +v) = r
      +nx = ((code + v) << 1n : U32)
      next.go(p, (l + 1 : U32), nx, ((left - v) * 2 : U32), Bool.and(ok, U32.is_le(v, left)), Array.set(U32, n, l, nx), Array.get(U32, c, l))

def fill(f: Nat, t: Array<U32>, +i: U32, +step: U32, +e: U32) -> Array<U32>:
  match f:
    case 0n:
      t
    case 1n+p:
      fill(p, Array.set(U32, t, i, e), (i + step : U32), step, e)

def rev(k: Nat, +v: U32, +acc: U32) -> U32:
  match k:
    case 0n:
      acc
    case 1n+p:
      rev(p, U32.shrn(v, 1n), ((acc << 1n) .|. (v .&. 1) : U32))

# MSB-first, a code fills a run of consecutive entries; LSB-first, its bits reversed fill every 2^len-th.
def assign.put(+msb: Bool, +max: U32, +sym: U32, +len: U32, r: Array<U32> & U32, t: Array<U32>) -> Array<U32> & Array<U32>:
  (n, +code) = r
  +lo = (max - len : U32)
  +start = Bool.pick(U32, msb, U32.shln(code, U32.to_nat(lo)), rev(U32.to_nat(len), code, 0))
  +step = Bool.pick(U32, msb, 1, U32.shln(1, U32.to_nat(len)))
  (Array.set(U32, n, len, (code + 1 : U32)), fill(U32.to_nat(U32.shln(1, U32.to_nat(lo))), t, start, step, ((sym << 5n) .|. len : U32)))

def assign.one(zero: Bool, +msb: Bool, +max: U32, +sym: U32, +len: U32, st: Array<U32> & Array<U32>) -> Array<U32> & Array<U32>:
  match zero:
    case True{}:
      st
    case False{}:
      (n, t) = st
      assign.put(msb, max, sym, len, Array.get(U32, n, len), t)

def assign(xs: List<&2, Code>, +msb: Bool, +max: U32, st: Array<U32> & Array<U32>) -> Array<U32>:
  match xs:
    case Nil{}:
      (n, t) = st
      t
    case Con{Code{+sym, +len}, t}:
      assign(t, msb, max, assign.one(U32.is_eq(len, 0), msb, max, sym, len, st))

def build.next(+msb: Bool, +max: U32, xs: List<&2, Code>, r: Array<U32> & Bool) -> Maybe<&1, Huff>:
  (n, ok) = r
  match ok:
    case True{}:
      Some{Huff{msb, max, assign(xs, msb, max, (n, Array.new(U32, U32.to_nat(max), 0)))}}
    case False{}:
      None{}

def build.short(ok: Bool, +msb: Bool, +max: U32, +xs: List<&2, Code>) -> Maybe<&1, Huff>:
  match ok:
    case True{}:
      build.next(msb, max, xs, next.go(17n, 1, 0, 1, True{}, Array.new(U32, 5n, 0), Array.get(U32, count(xs, Array.new(U32, 5n, 0)), 0)))
    case False{}:
      None{}

# A table from codes. Codes go shortest first, ties in list order; length 0 means no code.
# None when a length exceeds 16 or the lengths over-subscribe. An incomplete set is allowed,
# and decode answers None for its unused codes. Symbols must be below 2^27.
def Huff.from_codes(+msb: Bool, +xs: List<&2, Code>) -> Maybe<&1, Huff>:
  +max = lens.max(xs, 0)
  build.short(U32.is_le(max, 16), msb, max, xs)

def codes(xs: List<&2, U32>, +i: U32) -> List<&2, Code>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+len, t}:
      Con{Code{i, len}, codes(t, (i + 1 : U32))}

# Symbol i has length lens[i], as DEFLATE sends them (RFC 1951 §3.2.2).
def Huff.from_lens(+msb: Bool, +lens: List<&2, U32>) -> Maybe<&1, Huff>:
  Huff.from_codes(msb, codes(lens, 0))

# Bits past the end may be garbage in w: a code's entry repeats over every suffix, so only
# its own len bits pick it, and len <= left keeps them inside the stream.
def decode.hit(+msb: Bool, +max: U32, +len: U32, +pos: U32, +left: U32, buf: Array<U32>, r: Array<U32> & U32) -> Huff & Reader & Maybe<&2, U32>:
  (t, +e) = r
  +l = (e .&. 31 : U32)
  +ok = Bool.and(U32.is_ne(l, 0), U32.is_le(l, left))
  (Huff{msb, max, t}, Reader{len, buf, Bool.pick(U32, ok, (pos + l : U32), pos)}, Bool.pick(Maybe<&2, U32>, ok, Some{U32.shrn(e, 5n)}, None{}))

def decode.look(+msb: Bool, +max: U32, +len: U32, +pos: U32, t: Array<U32>, r: Array<U32> & U32) -> Huff & Reader & Maybe<&2, U32>:
  (buf, +w) = r
  decode.hit(msb, max, len, pos, ((len << 3n) - pos : U32), buf, Array.get(U32, t, field(msb, max, w)))

# One symbol, and the reader past its code. None, with the reader unchanged, when the next
# bits start no code or the input ends inside one.
def Huff.decode(h: Huff, r: Reader) -> Huff & Reader & Maybe<&2, U32>:
  Huff{+msb, +max, t} = h
  Reader{+len, buf, +pos} = r
  decode.look(msb, max, len, pos, t, win(msb, buf, pos))
