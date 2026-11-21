# Bit readers and writers over Bytes, LSB-first (DEFLATE) or MSB-first (JPEG), and canonical Huffman codes and decode tables. Source: https://github.com/paymog/bend-kit/tree/main/bits
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

# A writer's buf has 2^dep words, all 0 past bit pos; msb is the order of the last write.
type Writer is Type:
  Writer{buf: Array<U32>, dep: U32, pos: U32, msb: Bool}

def Writer.new() -> Writer:
  Writer{Array.new(U32, 0n, 0), 0, 0, False{}}

# A write adds at most 32 bits, so one doubling always makes room.
def room(full: Bool, w: Writer) -> Writer:
  match full:
    case False{}:
      w
    case True{}:
      Writer{buf, +dep, pos, msb} = w
      Writer{ANode{buf, Array.new(U32, U32.to_nat(dep), 0)}, (dep + 1 : U32), pos, msb}

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
  Writer{buf, dep, +pos, last} = w
  Writer{write.put((pos >> 5n : U32), parts(msb, (pos .&. 31 : U32), n, v), buf), dep, (pos + n : U32), msb}

# The two orders put a stream bit at different places in its byte, so an order switch starts a new byte.
def write(+msb: Bool, w: Writer, +n0: U32, +v: U32) -> Writer:
  Writer{buf, +dep, +pos0, +last} = w
  +pos = Bool.pick(U32, Bool.xor(msb, last), ((pos0 + 7) .&. 4294967288 : U32), pos0)
  +n = U32.min(n0, 32)
  write.at(msb, room(U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((pos + n + 31) >> 5n : U32)), Writer{buf, dep, pos, last}), n, v)

# Appends the low n bits of v (n is cut to 32). LSB-first sends v's lowest bit first;
# MSB-first sends bit n - 1 first. A write in the other order than the last one first pads to a byte boundary.
def Writer.lsb(w: Writer, +n: U32, +v: U32) -> Writer:
  write(False{}, w, n, v)

def Writer.msb(w: Writer, +n: U32, +v: U32) -> Writer:
  write(True{}, w, n, v)

# Pads with 0 bits to the next byte boundary.
def Writer.align(w: Writer) -> Writer:
  Writer{buf, dep, +pos, msb} = w
  Writer{buf, dep, ((pos + 7) .&. 4294967288 : U32), msb}

# The bytes written; 0 bits fill the last byte.
def Writer.finish(w: Writer) -> Bytes.Bytes:
  Writer{buf, dep, +pos, msb} = w
  Bytes.Bytes{((pos + 7) >> 3n : U32), buf}

# A root of up to nine bits; longer codes use fixed-width secondary tables.
type Huff is Type:
  Huff{msb: Bool, max: U32, table: Array<U32>, sub: Array<U32>}

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


def prefix(+msb: Bool, +root: U32, +len: U32, +code: U32) -> U32:
  Bool.pick(U32, msb, U32.shrn(code, U32.to_nat((len - root : U32))), (rev(U32.to_nat(len), code, 0) .&. (U32.shln(1, U32.to_nat(root)) - 1) : U32))

# Root length 31 marks a secondary-table offset; valid code lengths never exceed 16.
def reserve.hit(empty: Bool, +i: U32, +width: U32, +used: U32, t: Array<U32>) -> Array<U32> & U32:
  match empty:
    case True{}:
      (Array.set(U32, t, i, ((used << 5n) .|. 31 : U32)), (used + width : U32))
    case False{}:
      (t, used)

def reserve.entry(+i: U32, +width: U32, used: U32, r: Array<U32> & U32) -> Array<U32> & U32:
  (t, +e) = r
  reserve.hit(U32.is_eq(e, 0), i, width, used, t)

def reserve.long(long: Bool, +msb: Bool, +root: U32, +max: U32, +len: U32, +code: U32, t: Array<U32>, +used: U32) -> Array<U32> & U32:
  match long:
    case False{}:
      (t, used)
    case True{}:
      +i = prefix(msb, root, len, code)
      reserve.entry(i, U32.shln(1, U32.to_nat((max - root : U32))), used, Array.get(U32, t, i))

def reserve.state(n: Array<U32>, r: Array<U32> & U32) -> Array<U32> & Array<U32> & U32:
  (t, used) = r
  (n, t, used)

def reserve.one(+msb: Bool, +root: U32, +max: U32, +len: U32, t: Array<U32>, used: U32, r: Array<U32> & U32) -> Array<U32> & Array<U32> & U32:
  (n, +code) = r
  reserve.state(Array.set(U32, n, len, (code + 1 : U32)), reserve.long(U32.is_gt(len, root), msb, root, max, len, code, t, used))

def reserve(xs: List<&2, Code>, +msb: Bool, +root: U32, +max: U32, st: Array<U32> & Array<U32> & U32) -> Array<U32> & U32:
  match xs:
    case Nil{}:
      (n, t, used) = st
      (t, used)
    case Con{Code{sym, +len}, tail}:
      (n, t, used) = st
      reserve(tail, msb, root, max, reserve.one(msb, root, max, len, t, used, Array.get(U32, n, len)))

def depth(k: Nat, +size: U32, +d: Nat) -> Nat:
  match k:
    case 0n:
      d
    case 1n+p:
      depth(p, U32.shrn((size + 1 : U32), 1n), Bool.pick(Nat, U32.is_gt(size, 1), 1n+d, d))

def assign.short(sub: Array<U32>, r: Array<U32> & Array<U32>) -> Array<U32> & Array<U32> & Array<U32>:
  (n, t) = r
  (n, t, sub)

def assign.tail(+msb: Bool, +root: U32, +max: U32, +sym: U32, +len: U32, +code: U32, n: Array<U32>, sub: Array<U32>, r: Array<U32> & U32) -> Array<U32> & Array<U32> & Array<U32>:
  (t, +e) = r
  +tail = (len - root : U32)
  +lo = (max - len : U32)
  +start = Bool.pick(U32, msb, U32.shln((code .&. (U32.shln(1, U32.to_nat(tail)) - 1) : U32), U32.to_nat(lo)), U32.shrn(rev(U32.to_nat(len), code, 0), U32.to_nat(root)))
  +step = Bool.pick(U32, msb, 1, U32.shln(1, U32.to_nat(tail)))
  (Array.set(U32, n, len, (code + 1 : U32)), t, fill(U32.to_nat(U32.shln(1, U32.to_nat(lo))), sub, (U32.shrn(e, 5n) + start : U32), step, ((sym << 5n) .|. len : U32)))

def assign.long(+msb: Bool, +root: U32, +max: U32, sym: U32, +len: U32, t: Array<U32>, sub: Array<U32>, r: Array<U32> & U32) -> Array<U32> & Array<U32> & Array<U32>:
  (n, +code) = r
  assign.tail(msb, root, max, sym, len, code, n, sub, Array.get(U32, t, prefix(msb, root, len, code)))

def assign.split(long: Bool, +msb: Bool, +root: U32, +max: U32, +sym: U32, +len: U32, n: Array<U32>, t: Array<U32>, sub: Array<U32>) -> Array<U32> & Array<U32> & Array<U32>:
  match long:
    case False{}:
      assign.short(sub, assign.one(U32.is_eq(len, 0), msb, root, sym, len, (n, t)))
    case True{}:
      assign.long(msb, root, max, sym, len, t, sub, Array.get(U32, n, len))

def assign.two(xs: List<&2, Code>, +msb: Bool, +root: U32, +max: U32, st: Array<U32> & Array<U32> & Array<U32>) -> Array<U32> & Array<U32>:
  match xs:
    case Nil{}:
      (n, t, sub) = st
      (t, sub)
    case Con{Code{+sym, +len}, tail}:
      (n, t, sub) = st
      assign.two(tail, msb, root, max, assign.split(U32.is_gt(len, root), msb, root, max, sym, len, n, t, sub))

def build.done(msb: Bool, max: U32, r: Array<U32> & Array<U32>) -> Huff:
  (t, sub) = r
  Huff{msb, max, t, sub}

def build.reserved(+msb: Bool, +max: U32, +root: U32, xs: List<&2, Code>, n: Array<U32>, r: Array<U32> & U32) -> Huff:
  (t, +used) = r
  build.done(msb, max, assign.two(xs, msb, root, max, (n, t, Array.new(U32, depth(16n, used, 0n), 0))))

def build.cloned(+msb: Bool, +max: U32, +root: U32, +xs: List<&2, Code>, r: Array<U32> & Array<U32>) -> Huff:
  (n, copy) = r
  build.reserved(msb, max, root, xs, n, reserve(xs, msb, root, max, (copy, Array.new(U32, U32.to_nat(root), 0), 0)))

def build.two(+msb: Bool, +max: U32, +xs: List<&2, Code>, n: Array<U32>) -> Huff:
  build.cloned(msb, max, U32.min(max, 9), xs, Array.clone(U32, n))

def build.choose(small: Bool, +msb: Bool, +max: U32, xs: List<&2, Code>, n: Array<U32>) -> Huff:
  match small:
    case True{}:
      build.done(msb, max, assign.two(xs, msb, max, max, (n, Array.new(U32, U32.to_nat(max), 0), Array.new(U32, 0n, 0))))
    case False{}:
      build.two(msb, max, xs, n)

def build.next(+msb: Bool, +max: U32, xs: List<&2, Code>, r: Array<U32> & Bool) -> Maybe<&1, Huff>:
  (n, ok) = r
  match ok:
    case True{}:
      Some{build.choose(U32.is_le(max, 9), msb, max, xs, n)}
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

# A symbol's canonical value, with its first stream bit at bit len - 1.
type Encoding is Data:
  Encoding{sym: U32, len: U32, value: U32}

def encode.put(+sym: U32, +len: U32, acc: List<&2, Encoding>, r: Array<U32> & U32) -> Array<U32> & List<&2, Encoding>:
  (n, +value) = r
  (Array.set(U32, n, len, (value + 1 : U32)), Con{Encoding{sym, len, value}, acc})

def encode.one(zero: Bool, +sym: U32, +len: U32, st: Array<U32> & List<&2, Encoding>) -> Array<U32> & List<&2, Encoding>:
  match zero:
    case True{}:
      st
    case False{}:
      (n, acc) = st
      encode.put(sym, len, acc, Array.get(U32, n, len))

def encode.go(xs: List<&2, Code>, st: Array<U32> & List<&2, Encoding>) -> List<&2, Encoding>:
  match xs:
    case Nil{}:
      (n, acc) = st
      List.reverse(&2, Encoding, acc)
    case Con{Code{+sym, +len}, t}:
      encode.go(t, encode.one(U32.is_eq(len, 0), sym, len, st))

def encode.next(xs: List<&2, Code>, r: Array<U32> & Bool) -> Maybe<&2, List<&2, Encoding>>:
  (n, ok) = r
  match ok:
    case True{}:
      Some{encode.go(xs, (n, Nil{}))}
    case False{}:
      None{}

def encode.short(ok: Bool, +xs: List<&2, Code>) -> Maybe<&2, List<&2, Encoding>>:
  match ok:
    case True{}:
      encode.next(xs, next.go(17n, 1, 0, 1, True{}, Array.new(U32, 5n, 0), Array.get(U32, count(xs, Array.new(U32, 5n, 0)), 0)))
    case False{}:
      None{}

# Input order, without zero lengths; validation and canonical assignment match Huff.from_codes.
def Huff.encode_codes(+xs: List<&2, Code>) -> Maybe<&2, List<&2, Encoding>>:
  encode.short(U32.is_le(lens.max(xs, 0), 16), xs)

def Huff.encode_lens(lens: List<&2, U32>) -> Maybe<&2, List<&2, Encoding>>:
  Huff.encode_codes(codes(lens, 0))

# Huffman codes send their most significant bit first in either stream order.
def Writer.code(msb: Bool, w: Writer, e: Encoding) -> Writer:
  match msb:
    case True{}:
      Encoding{sym, +len, +value} = e
      Writer.msb(w, len, value)
    case False{}:
      Encoding{sym, +len, +value} = e
      Writer.lsb(w, len, rev(U32.to_nat(len), value, 0))

# Bits past the end may be garbage in w: a code's entry repeats over every suffix, so only
# its own len bits pick it, and len <= left keeps them inside the stream.
def decode.hit(+msb: Bool, +max: U32, +len: U32, +pos: U32, +left: U32, buf: Array<U32>, sub: Array<U32>, r: Array<U32> & U32) -> Huff & Reader & Maybe<&2, U32>:
  (t, +e) = r
  +l = (e .&. 31 : U32)
  +ok = Bool.and(U32.is_ne(l, 0), U32.is_le(l, left))
  (Huff{msb, max, t, sub}, Reader{len, buf, Bool.pick(U32, ok, (pos + l : U32), pos)}, Bool.pick(Maybe<&2, U32>, ok, Some{U32.shrn(e, 5n)}, None{}))

def decode.sub(long: Bool, +msb: Bool, +max: U32, +w: U32, +e: U32, sub: Array<U32>) -> Array<U32> & U32:
  match long:
    case False{}:
      (sub, e)
    case True{}:
      +width = (max - 9 : U32)
      +all = field(msb, max, w)
      +i = Bool.pick(U32, msb, (all .&. (U32.shln(1, U32.to_nat(width)) - 1) : U32), U32.shrn(all, 9n))
      Array.get(U32, sub, (U32.shrn(e, 5n) + i : U32))

def decode.found(+msb: Bool, +max: U32, +len: U32, +pos: U32, buf: Array<U32>, t: Array<U32>, r: Array<U32> & U32) -> Huff & Reader & Maybe<&2, U32>:
  (sub, e) = r
  decode.hit(msb, max, len, pos, ((len << 3n) - pos : U32), buf, sub, (t, e))

def decode.root(+msb: Bool, +max: U32, +len: U32, +pos: U32, w: U32, buf: Array<U32>, sub: Array<U32>, r: Array<U32> & U32) -> Huff & Reader & Maybe<&2, U32>:
  (t, +e) = r
  decode.found(msb, max, len, pos, buf, t, decode.sub(U32.is_eq((e .&. 31 : U32), 31), msb, max, w, e, sub))

def decode.look(+msb: Bool, +max: U32, +len: U32, +pos: U32, t: Array<U32>, sub: Array<U32>, r: Array<U32> & U32) -> Huff & Reader & Maybe<&2, U32>:
  (buf, +w) = r
  decode.root(msb, max, len, pos, w, buf, sub, Array.get(U32, t, field(msb, U32.min(max, 9), w)))

# One symbol, and the reader past its code. None, with the reader unchanged, when the next
# bits start no code or the input ends inside one.
def Huff.decode(h: Huff, r: Reader) -> Huff & Reader & Maybe<&2, U32>:
  Huff{+msb, +max, t, sub} = h
  Reader{+len, buf, +pos} = r
  decode.look(msb, max, len, pos, t, sub, win(msb, buf, pos))
