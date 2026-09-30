# Byte buffers packed four bytes to a U32, with bounds-checked access. Source: https://github.com/paymog/bend-kit/tree/main/bytes
import Base
# bend-kit-int@0.2.0.0
import 0x4eed9d7ac6ece61523d747a9d804e4f0/int.bend as Int

# Bytes{len, buf}: byte i is bits 8*(i%4) of buf[i/4]. buf has the fewest 2^d words
# that hold len bytes. Every byte at or past len is 0, so equal buffers have equal words.
# Out-of-range reads answer None and out-of-range writes do nothing; Array alone would wrap.
#   import ./bytes/bytes.bend as Bytes

type Bytes is Type:
  Bytes{len: U32, buf: Array<U32>}

def b8(+x: U32) -> U32:
  (x .&. 255 : U32)

def shift(+i: U32) -> Nat:
  U32.to_nat(((i .&. 3 : U32) * 8 : U32))

def words(+n: U32) -> U32:
  ((n + 3 : U32) >> 2n : U32)

# The fewest d with 2^d >= w.
def depth.go(f: Nat, more: Bool, +w: U32, +d: Nat, +cap: U32) -> Nat:
  match f:
    case 0n:
      d
    case 1n+p:
      match more:
        case False{}:
          d
        case True{}:
          depth.go(p, U32.is_lt((cap * 2 : U32), w), w, 1n+d, (cap * 2 : U32))

def depth(+w: U32) -> Nat:
  depth.go(32n, U32.is_lt(1, w), w, 0n, 1)

def alloc(+n: U32) -> Array<U32>:
  Array.new(U32, depth(words(n)), 0)

# Unchecked byte read and write. Callers keep i below len.
def peek.of(+sh: Nat, r: Array<U32> & U32) -> Array<U32> & U32:
  (a, w) = r
  (a, b8(U32.shrn(w, sh)))

def peek(a: Array<U32>, +i: U32) -> Array<U32> & U32:
  peek.of(shift(i), Array.get(U32, a, (i >> 2n : U32)))

def poke.of(+i: U32, +v: U32, r: Array<U32> & U32) -> Array<U32>:
  (a, w) = r
  +sh = shift(i)
  Array.set(U32, a, (i >> 2n : U32), ((w .&. ((255 << sh) .^. 4294967295)) .|. (b8(v) << sh) : U32))

def poke(a: Array<U32>, +i: U32, +v: U32) -> Array<U32>:
  poke.of(i, v, Array.get(U32, a, (i >> 2n : U32)))

# n bytes from src[s..] to dst[d..], one byte at a time.
def copy.go(n: Nat, r: Array<U32> & U32, dst: Array<U32>, +s: U32, +d: U32) -> Array<U32> & Array<U32>:
  match n:
    case 0n:
      (a, v) = r
      (a, dst)
    case 1n+p:
      (a, v) = r
      copy.go(p, peek(a, (s + 1 : U32)), poke(dst, d, v), (s + 1 : U32), (d + 1 : U32))

def copy.bytes(+m: U32, src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> Array<U32> & Array<U32>:
  copy.go(U32.to_nat(m), peek(src, s), dst, s, d)

# n words from src[s..] to dst[d..] (word indexes).
def copy.words(n: Nat, r: Array<U32> & U32, dst: Array<U32>, +s: U32, +d: U32) -> Array<U32> & Array<U32>:
  match n:
    case 0n:
      (a, w) = r
      (a, dst)
    case 1n+p:
      (a, +w) = r
      copy.words(p, Array.get(U32, a, (s + 1 : U32)), Array.set(U32, dst, d, w), (s + 1 : U32), (d + 1 : U32))

# m bytes to a word-aligned d from an unaligned s: each out word joins two source words.
# lo = 8*(s%4) and hi = 32 - lo; r holds source word k, prev the word before it.
def copy.shift(n: Nat, +lo: Nat, +hi: Nat, +prev: U32, r: Array<U32> & U32, dst: Array<U32>, +k: U32, +d: U32) -> Array<U32> & Array<U32>:
  match n:
    case 0n:
      (a, w) = r
      (a, dst)
    case 1n+p:
      (a, +w) = r
      copy.shift(p, lo, hi, w, Array.get(U32, a, (k + 1 : U32)), Array.set(U32, dst, d, (U32.shrn(prev, lo) .|. U32.shln(w, hi) : U32)), (k + 1 : U32), (d + 1 : U32))

def copy.shift.at(+w: U32, +lo: U32, +k: U32, +d: U32, r: Array<U32> & U32, dst: Array<U32>) -> Array<U32> & Array<U32>:
  (a, prev) = r
  copy.shift(U32.to_nat(w), U32.to_nat(lo), U32.to_nat((32 - lo : U32)), prev, Array.get(U32, a, (k + 1 : U32)), dst, (k + 1 : U32), d)

def copy.tail(+m: U32, +s: U32, +d: U32, r: Array<U32> & Array<U32>) -> Array<U32> & Array<U32>:
  (a, b) = r
  copy.bytes(m, a, b, s, d)

def copy.pick(aligned: Bool, +m: U32, src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> Array<U32> & Array<U32>:
  match aligned:
    case True{}:
      +w = (m >> 2n : U32)
      +k = (w * 4 : U32)
      copy.tail((m - k : U32), (s + k : U32), (d + k : U32), copy.words(U32.to_nat(w), Array.get(U32, src, (s >> 2n : U32)), dst, (s >> 2n : U32), (d >> 2n : U32)))
    case False{}:
      +w = (m >> 2n : U32)
      +k = (w * 4 : U32)
      copy.tail((m - k : U32), (s + k : U32), (d + k : U32), copy.shift.at(w, ((s .&. 3 : U32) * 8 : U32), (s >> 2n : U32), (d >> 2n : U32), Array.get(U32, src, (s >> 2n : U32)), dst))

def copy.dst(daligned: Bool, +m: U32, src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> Array<U32> & Array<U32>:
  match daligned:
    case False{}:
      copy.bytes(m, src, dst, s, d)
    case True{}:
      copy.pick(U32.is_eq((s .&. 3 : U32), 0), m, src, dst, s, d)

# m bytes from src[s..] to dst[d..]. Whole words when d is word-aligned, shifted when s is not.
# ponytail: an unaligned d (append after an odd length) copies bytes; merge into d's first word if that gets hot.
def copy(+m: U32, src: Array<U32>, dst: Array<U32>, +s: U32, +d: U32) -> Array<U32> & Array<U32>:
  copy.dst(U32.is_eq((d .&. 3 : U32), 0), m, src, dst, s, d)

# n zero bytes.
def new(+n: U32) -> Bytes:
  Bytes{n, alloc(n)}

def length(b: Bytes) -> Bytes & U32:
  Bytes{+len, buf} = b
  (Bytes{len, buf}, len)

def get.some(+len: U32, r: Array<U32> & U32) -> Bytes & Maybe<&2, U32>:
  (a, v) = r
  (Bytes{len, a}, Some{v})

def get.if(ok: Bool, +len: U32, buf: Array<U32>, +i: U32) -> Bytes & Maybe<&2, U32>:
  match ok:
    case True{}:
      get.some(len, peek(buf, i))
    case False{}:
      (Bytes{len, buf}, None{})

# Byte i, or None when i >= len.
def get(b: Bytes, +i: U32) -> Bytes & Maybe<&2, U32>:
  Bytes{+len, buf} = b
  get.if(U32.is_lt(i, len), len, buf, i)

def set.if(ok: Bool, +len: U32, buf: Array<U32>, +i: U32, +v: U32) -> Bytes:
  match ok:
    case True{}:
      Bytes{len, poke(buf, i, v)}
    case False{}:
      Bytes{len, buf}

# Byte i becomes v & 255. Nothing changes when i >= len.
def set(b: Bytes, +i: U32, +v: U32) -> Bytes:
  Bytes{+len, buf} = b
  set.if(U32.is_lt(i, len), len, buf, i, v)

# The next index: one forward when up, one back when not.
def step(+up: Bool, +i: U32) -> U32:
  Bool.pick(U32, up, (i + 1 : U32), (i - 1 : U32))

# Do n bytes from i fit in len?
def fits(+len: U32, +i: U32, +n: U32) -> Bool:
  Bool.and(U32.is_le(n, len), U32.is_le(i, (len - n : U32)))

# n bytes from j, each shifted in below the ones before: the first byte read is the most significant.
def uint.go(n: Nat, r: Array<U32> & U32, +j: U32, +up: Bool, +acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (a, v) = r
      (a, acc)
    case 1n+p:
      (a, +v) = r
      uint.go(p, peek(a, step(up, j)), step(up, j), up, ((acc << 8n) .|. v : U32))

# Big-endian reads forward from i; little-endian reads back from the last byte.
def uint.if(ok: Bool, +len: U32, buf: Array<U32>, +i: U32, +n: U32, +be: Bool) -> Bytes & Maybe<&2, U32>:
  match ok:
    case True{}:
      +j = Bool.pick(U32, be, i, (i + n - 1 : U32))
      get.some(len, uint.go(U32.to_nat(n), peek(buf, j), j, be, 0))
    case False{}:
      (Bytes{len, buf}, None{})

def uint(b: Bytes, +i: U32, +n: U32, +be: Bool) -> Bytes & Maybe<&2, U32>:
  Bytes{+len, buf} = b
  uint.if(fits(len, i, n), len, buf, i, n, be)

# Unsigned integers at byte i, or None when they run past len.
# be: most significant byte first (network order); le: least significant first.
def get.u16be(b: Bytes, +i: U32) -> Bytes & Maybe<&2, U32>:
  uint(b, i, 2, True{})

def get.u16le(b: Bytes, +i: U32) -> Bytes & Maybe<&2, U32>:
  uint(b, i, 2, False{})

def get.u32be(b: Bytes, +i: U32) -> Bytes & Maybe<&2, U32>:
  uint(b, i, 4, True{})

def get.u32le(b: Bytes, +i: U32) -> Bytes & Maybe<&2, U32>:
  uint(b, i, 4, False{})

# n bytes of v from j, least significant first.
def put.go(n: Nat, a: Array<U32>, +j: U32, +up: Bool, +v: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      put.go(p, poke(a, j, v), step(up, j), up, U32.shrn(v, 8n))

# Little-endian writes forward from i; big-endian writes back from the last byte.
def put.if(ok: Bool, +len: U32, buf: Array<U32>, +i: U32, +n: U32, +be: Bool, +v: U32) -> Bytes:
  match ok:
    case True{}:
      Bytes{len, put.go(U32.to_nat(n), buf, Bool.pick(U32, be, (i + n - 1 : U32), i), Bool.not(be), v)}
    case False{}:
      Bytes{len, buf}

def put(b: Bytes, +i: U32, +n: U32, +be: Bool, +v: U32) -> Bytes:
  Bytes{+len, buf} = b
  put.if(fits(len, i, n), len, buf, i, n, be, v)

# v's low 16 or 32 bits at byte i. Nothing changes when they would run past len.
def set.u16be(b: Bytes, +i: U32, +v: U32) -> Bytes:
  put(b, i, 2, True{}, v)

def set.u16le(b: Bytes, +i: U32, +v: U32) -> Bytes:
  put(b, i, 2, False{}, v)

def set.u32be(b: Bytes, +i: U32, +v: U32) -> Bytes:
  put(b, i, 4, True{}, v)

def set.u32le(b: Bytes, +i: U32, +v: U32) -> Bytes:
  put(b, i, 4, False{}, v)

# The U64 whose words, in byte order, are x then y.
def u64.of(be: Bool, +x: U32, +y: U32) -> Int.U64:
  match be:
    case True{}:
      Int.U64.or(Int.U64.shl(Int.U64.from_u32(x), 32n), Int.U64.from_u32(y))
    case False{}:
      Int.U64.or(Int.U64.shl(Int.U64.from_u32(y), 32n), Int.U64.from_u32(x))

def u64.join(+be: Bool, x: Maybe<&2, U32>, y: Maybe<&2, U32>) -> Maybe<&2, Int.U64>:
  match x y:
    case Some{a} Some{c}:
      Some{u64.of(be, a, c)}
    case _ _:
      None{}

def u64.lo(+be: Bool, x: Maybe<&2, U32>, r: Bytes & Maybe<&2, U32>) -> Bytes & Maybe<&2, Int.U64>:
  (b, y) = r
  (b, u64.join(be, x, y))

def u64.hi(+i: U32, +be: Bool, r: Bytes & Maybe<&2, U32>) -> Bytes & Maybe<&2, Int.U64>:
  (b, x) = r
  u64.lo(be, x, uint(b, (i + 4 : U32), 4, be))

def u64(b: Bytes, +i: U32, +be: Bool) -> Bytes & Maybe<&2, Int.U64>:
  u64.hi(i, be, uint(b, i, 4, be))

# A U64 at byte i, or None when its 8 bytes run past len.
def get.u64be(b: Bytes, +i: U32) -> Bytes & Maybe<&2, Int.U64>:
  u64(b, i, True{})

def get.u64le(b: Bytes, +i: U32) -> Bytes & Maybe<&2, Int.U64>:
  u64(b, i, False{})

# Writes words x then y at byte i, both in the same byte order.
def put64.if(ok: Bool, +len: U32, buf: Array<U32>, +i: U32, +be: Bool, +x: U32, +y: U32) -> Bytes:
  match ok:
    case True{}:
      put(put(Bytes{len, buf}, i, 4, be, x), (i + 4 : U32), 4, be, y)
    case False{}:
      Bytes{len, buf}

def put64(b: Bytes, +i: U32, +be: Bool, +v: Int.U64) -> Bytes:
  Bytes{+len, buf} = b
  +hi = Int.U64.to_u32(Int.U64.shr(v, 32n))
  +lo = Int.U64.to_u32(v)
  put64.if(fits(len, i, 8), len, buf, i, be, Bool.pick(U32, be, hi, lo), Bool.pick(U32, be, lo, hi))

# v at byte i. Nothing changes when its 8 bytes would run past len.
def set.u64be(b: Bytes, +i: U32, +v: Int.U64) -> Bytes:
  put64(b, i, True{}, v)

def set.u64le(b: Bytes, +i: U32, +v: Int.U64) -> Bytes:
  put64(b, i, False{}, v)

# String.length counts in Nat, which costs more than the walk itself.
def count(s: String, +n: U32) -> U32:
  match s:
    case SNil{}:
      n
    case SCon{c, t}:
      count(t, (n + 1 : U32))

# Bytes enter at the top of w and shift down, so a full word has byte 0 lowest.
def flush(full: Bool, a: Array<U32>, +k: U32, +w: U32) -> Array<U32>:
  match full:
    case True{}:
      Array.set(U32, a, k, w)
    case False{}:
      a

def from.go(s: String, a: Array<U32>, +i: U32, +w: U32) -> Array<U32>:
  match s:
    case SNil{}:
      +r = (i .&. 3 : U32)
      flush(U32.is_ne(r, 0), a, (i >> 2n : U32), U32.shrn(w, U32.to_nat((((4 - r) .&. 3) * 8 : U32))))
    case SCon{Chr{+c}, t}:
      +w2 = ((w >> 8n) .|. (b8(c) << 24n) : U32)
      +full = U32.is_eq((i .&. 3 : U32), 3)
      from.go(t, flush(full, a, (i >> 2n : U32), w2), (i + 1 : U32), Bool.pick(U32, full, 0, w2))

# A byte string (one Char per octet, as Wire and Http use) to Bytes. Each Char keeps its low 8 bits.
def from_string(+s: String) -> Bytes:
  +n = count(s, 0)
  Bytes{n, from.go(s, alloc(n), 0, 0)}

def to.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      (a, v) = r
      to.go(p, peek(a, (i - 1 : U32)), (i - 1 : U32), SCon{Chr{v}, acc})

# Bytes to a byte string, one Char per octet.
def to_string(b: Bytes) -> String:
  Bytes{+len, buf} = b
  to.go(U32.to_nat(len), peek(buf, (len - 1 : U32)), (len - 1 : U32), SNil{})

def slice.fin(+len: U32, +m: U32, r: Array<U32> & Array<U32>) -> Bytes & Bytes:
  (a, c) = r
  (Bytes{len, a}, Bytes{m, c})

def slice.at(+len: U32, buf: Array<U32>, +s: U32, +m: U32) -> Bytes & Bytes:
  slice.fin(len, m, copy(m, buf, alloc(m), s, 0))

# The buffer back, and a copy of up to n bytes from start. Both ends are clamped to len.
def slice(b: Bytes, +start: U32, +n: U32) -> Bytes & Bytes:
  Bytes{+len, buf} = b
  +s = U32.min(start, len)
  slice.at(len, buf, s, U32.min(n, (len - s : U32)))

def dst(r: Array<U32> & Array<U32>) -> Array<U32>:
  (src, out) = r
  out

# Does a buffer holding len bytes have room for n? Its 2^d words fit the fewest that hold len.
def room(+len: U32, +n: U32) -> Bool:
  U32.is_le(words(n), U32.shln(1, depth(words(len))))

def grow.if(fits: Bool, +len: U32, buf: Array<U32>, +n: U32) -> Array<U32>:
  match fits:
    case True{}:
      buf
    case False{}:
      dst(copy(len, buf, alloc(n), 0, 0))

# buf, or a copy of its first len bytes in the fewest 2^d words that hold n.
def grow(+len: U32, buf: Array<U32>, +n: U32) -> Array<U32>:
  grow.if(room(len, n), len, buf, n)

# a then b. b is written into a's buffer while it has room, and the buffer at least
# doubles when it runs out, so building a buffer one piece at a time is O(total).
def append(a: Bytes, b: Bytes) -> Bytes:
  Bytes{+la, ba} = a
  Bytes{+lb, bb} = b
  +n = (la + lb : U32)
  Bytes{n, dst(copy(lb, bb, grow(la, ba, n), 0, la))}

def concat.total.con(x: Bytes, r: List<&1, Bytes> & U32) -> List<&1, Bytes> & U32:
  (t, n) = r
  (Con{x, t}, n)

def concat.total(xs: List<&1, Bytes>, +n: U32) -> List<&1, Bytes> & U32:
  match xs:
    case Nil{}:
      (Nil{}, n)
    case Con{x, t}:
      Bytes{+l, buf} = x
      concat.total.con(Bytes{l, buf}, concat.total(t, (n + l : U32)))

def concat.go(xs: List<&1, Bytes>, out: Array<U32>, +at: U32) -> Array<U32>:
  match xs:
    case Nil{}:
      out
    case Con{x, t}:
      Bytes{+l, buf} = x
      concat.go(t, dst(copy(l, buf, out, 0, at)), (at + l : U32))

def concat.of(r: List<&1, Bytes> & U32) -> Bytes:
  (xs, +n) = r
  Bytes{n, concat.go(xs, alloc(n), 0)}

# The pieces in order, in one new buffer: one copy per byte, however many pieces.
def concat(xs: List<&1, Bytes>) -> Bytes:
  concat.of(concat.total(xs, 0))

# Does needle match at j? ok is the previous byte's result; the first mismatch stops the walk.
def at.go(needle: String, ok: Bool, r: Array<U32> & U32, +j: U32) -> Array<U32> & Bool:
  match needle:
    case SNil{}:
      (a, v) = r
      (a, ok)
    case SCon{Chr{+c}, t}:
      match ok:
        case False{}:
          (a, v) = r
          (a, False{})
        case True{}:
          (a, +v) = r
          at.go(t, U32.is_eq(v, c), peek(a, (j + 1 : U32)), (j + 1 : U32))

def at(a: Array<U32>, +needle: String, +j: U32) -> Array<U32> & Bool:
  at.go(needle, True{}, peek(a, j), j)

# ponytail: naive search; a mismatch costs one byte read per position, but a repetitive needle is O(len * needle). Add a SWAR scan or two-way search if find gets hot.
# f counts the positions left after i.
def find.go(f: Nat, r: Array<U32> & Bool, +needle: String, +i: U32, +up: Bool) -> Array<U32> & Maybe<&2, U32>:
  match f:
    case 0n:
      (a, hit) = r
      (a, Bool.pick(Maybe<&2, U32>, hit, Some{i}, None{}))
    case 1n+p:
      (a, hit) = r
      match hit:
        case True{}:
          (a, Some{i})
        case False{}:
          find.go(p, at(a, needle, step(up, i)), needle, step(up, i), up)

def find.fin(+len: U32, r: Array<U32> & Maybe<&2, U32>) -> Bytes & Maybe<&2, U32>:
  (a, x) = r
  (Bytes{len, a}, x)

def find.at(none: Bool, +len: U32, buf: Array<U32>, +needle: String, +i: U32, +f: U32, +up: Bool) -> Bytes & Maybe<&2, U32>:
  match none:
    case True{}:
      (Bytes{len, buf}, None{})
    case False{}:
      find.fin(len, find.go(U32.to_nat(f), at(buf, needle, i), needle, i, up))

# Index of the first match of needle (a byte string) at or after start, or None.
# An empty needle matches at start when start <= len.
def find.from(b: Bytes, +needle: String, +start: U32) -> Bytes & Maybe<&2, U32>:
  Bytes{+len, buf} = b
  +m = count(needle, 0)
  find.at(Bool.or(U32.is_lt(len, m), U32.is_lt((len - m : U32), start)), len, buf, needle, start, (len - m - start : U32), True{})

# Index of the first match of needle (a byte string), or None. An empty needle matches at 0.
def find(b: Bytes, +needle: String) -> Bytes & Maybe<&2, U32>:
  find.from(b, needle, 0)

# Index of the last match of needle, or None. An empty needle matches at len.
def rfind(b: Bytes, +needle: String) -> Bytes & Maybe<&2, U32>:
  Bytes{+len, buf} = b
  +m = count(needle, 0)
  find.at(U32.is_lt(len, m), len, buf, needle, (len - m : U32), (len - m : U32), False{})

def at.fin(+len: U32, r: Array<U32> & Bool) -> Bytes & Bool:
  (a, ok) = r
  (Bytes{len, a}, ok)

def at.if(fits: Bool, +len: U32, buf: Array<U32>, +needle: String, +j: U32) -> Bytes & Bool:
  match fits:
    case True{}:
      at.fin(len, at(buf, needle, j))
    case False{}:
      (Bytes{len, buf}, False{})

# Does b begin with prefix (a byte string)?
def starts_with(b: Bytes, +prefix: String) -> Bytes & Bool:
  Bytes{+len, buf} = b
  +m = count(prefix, 0)
  at.if(U32.is_le(m, len), len, buf, prefix, 0)

# Does b end with suffix (a byte string)?
def ends_with(b: Bytes, +suffix: String) -> Bytes & Bool:
  Bytes{+len, buf} = b
  +m = count(suffix, 0)
  at.if(U32.is_le(m, len), len, buf, suffix, (len - m : U32))

# Match positions of sep, latest first, that do not overlap an earlier match.
# f counts the positions left; skip counts the bytes still inside the last match.
def split.scan(f: Nat, r: Array<U32> & Bool, +sep: String, +m: U32, +i: U32, +skip: U32, +cuts: List<&2, U32>) -> Array<U32> & List<&2, U32>:
  match f:
    case 0n:
      (a, hit) = r
      (a, cuts)
    case 1n+p:
      (a, +hit) = r
      +take = Bool.and(hit, U32.is_eq(skip, 0))
      +next = Bool.pick(U32, take, (m - 1 : U32), Bool.pick(U32, U32.is_eq(skip, 0), 0, (skip - 1 : U32)))
      split.scan(p, at(a, sep, (i + 1 : U32)), sep, m, (i + 1 : U32), next, Bool.pick(List<&2, U32>, take, Con{i, cuts}, cuts))

def snd(r: Bytes & Bytes) -> Bytes:
  (a, b) = r
  b

# r holds the buffer and the piece that ends at end; each earlier cut j starts one at j + m.
def split.cut(cuts: List<&2, U32>, r: Bytes & Bytes, +end: U32, +m: U32, acc: List<&1, Bytes>) -> List<&1, Bytes>:
  match cuts:
    case Nil{}:
      (b, piece) = r
      Con{snd(slice(b, 0, end)), Con{piece, acc}}
    case Con{+j, t}:
      (b, piece) = r
      split.cut(t, slice(b, (j + m : U32), (end - j - m : U32)), j, m, Con{piece, acc})

def split.of(cuts: List<&2, U32>, b: Bytes, +len: U32, +m: U32) -> List<&1, Bytes>:
  match cuts:
    case Nil{}:
      Con{b, Nil{}}
    case Con{+j, t}:
      split.cut(t, slice(b, (j + m : U32), (len - j - m : U32)), j, m, Nil{})

def split.run(+len: U32, +m: U32, r: Array<U32> & List<&2, U32>) -> List<&1, Bytes>:
  (a, cuts) = r
  split.of(cuts, Bytes{len, a}, len, m)

def split.if(whole: Bool, +len: U32, buf: Array<U32>, +sep: String, +m: U32) -> List<&1, Bytes>:
  match whole:
    case True{}:
      Con{Bytes{len, buf}, Nil{}}
    case False{}:
      split.run(len, m, split.scan(U32.to_nat((len - m + 1 : U32)), at(buf, sep, 0), sep, m, 0, 0, Nil{}))

# The pieces between matches of sep (a byte string), left to right. n matches give n + 1
# pieces, so a match at either end gives an empty piece. An empty sep gives b whole.
def split(b: Bytes, +sep: String) -> List<&1, Bytes>:
  Bytes{+len, buf} = b
  +m = count(sep, 0)
  split.if(Bool.or(U32.is_eq(m, 0), U32.is_lt(len, m)), len, buf, sep, m)

# Compares whole words; same tells whether the previous pair matched.
def eq.go(n: Nat, same: Bool, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32) -> Array<U32> & Array<U32> & Bool:
  match n:
    case 0n:
      (x, v) = r
      (y, w) = s
      (x, y, same)
    case 1n+p:
      match same:
        case False{}:
          (x, v) = r
          (y, w) = s
          (x, y, False{})
        case True{}:
          (x, +v) = r
          (y, +w) = s
          eq.go(p, U32.is_eq(v, w), Array.get(U32, x, (i + 1 : U32)), Array.get(U32, y, (i + 1 : U32)), (i + 1 : U32))

def eq.fin(+la: U32, +lb: U32, r: Array<U32> & Array<U32> & Bool) -> Bytes & Bytes & Bool:
  (x, y, ok) = r
  (Bytes{la, x}, Bytes{lb, y}, ok)

def eq.len(same: Bool, +la: U32, xa: Array<U32>, +lb: U32, ya: Array<U32>) -> Bytes & Bytes & Bool:
  match same:
    case False{}:
      (Bytes{la, xa}, Bytes{lb, ya}, False{})
    case True{}:
      eq.fin(la, lb, eq.go(U32.to_nat(words(la)), True{}, Array.get(U32, xa, 0), Array.get(U32, ya, 0), 0))

# Both buffers back, and whether they hold the same bytes.
def eq(a: Bytes, b: Bytes) -> Bytes & Bytes & Bool:
  Bytes{+la, xa} = a
  Bytes{+lb, ya} = b
  eq.len(U32.is_eq(la, lb), la, xa, lb, ya)

# Byte 0 of w becomes the most significant, so words compare in byte order.
def bswap(+w: U32) -> U32:
  ((b8(w) << 24n) .|. (b8(U32.shrn(w, 8n)) << 16n) .|. (b8(U32.shrn(w, 16n)) << 8n) .|. U32.shrn(w, 24n) : U32)

# Compares whole words; c is the previous pair's order.
def cmp.go(n: Nat, c: Cmp, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32) -> Array<U32> & Array<U32> & Cmp:
  match n:
    case 0n:
      (x, v) = r
      (y, w) = s
      (x, y, c)
    case 1n+p:
      match c:
        case LT{}:
          (x, v) = r
          (y, w) = s
          (x, y, LT{})
        case GT{}:
          (x, v) = r
          (y, w) = s
          (x, y, GT{})
        case EQ{}:
          (x, +v) = r
          (y, +w) = s
          cmp.go(p, U32.cmp(bswap(v), bswap(w)), Array.get(U32, x, (i + 1 : U32)), Array.get(U32, y, (i + 1 : U32)), (i + 1 : U32))

def cmp.len(c: Cmp, +la: U32, +lb: U32) -> Cmp:
  match c:
    case EQ{}:
      U32.cmp(la, lb)
    case LT{}:
      LT{}
    case GT{}:
      GT{}

def cmp.fin(+la: U32, +lb: U32, r: Array<U32> & Array<U32> & Cmp) -> Bytes & Bytes & Cmp:
  (x, y, c) = r
  (Bytes{la, x}, Bytes{lb, y}, cmp.len(c, la, lb))

# Both buffers back, and their order byte by byte; a prefix sorts first.
# The shorter buffer's bytes past its len are 0, so its last word compares low when only the longer one goes on.
def cmp(a: Bytes, b: Bytes) -> Bytes & Bytes & Cmp:
  Bytes{+la, xa} = a
  Bytes{+lb, ya} = b
  cmp.fin(la, lb, cmp.go(U32.to_nat(words(U32.min(la, lb))), EQ{}, Array.get(U32, xa, 0), Array.get(U32, ya, 0), 0))

def nibble(+n: U32) -> Char:
  Chr{Bool.pick(U32, U32.is_lt(n, 10), (48 + n : U32), (87 + n : U32))}

def hex.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      (a, +v) = r
      hex.go(p, peek(a, (i - 1 : U32)), (i - 1 : U32), SCon{nibble(U32.shrn(v, 4n)), SCon{nibble((v .&. 15 : U32)), acc}})

# Two lowercase hex digits per byte.
def to_hex(b: Bytes) -> String:
  Bytes{+len, buf} = b
  hex.go(U32.to_nat(len), peek(buf, (len - 1 : U32)), (len - 1 : U32), SNil{})

def in(+lo: U32, +c: U32, +hi: U32) -> Bool:
  Bool.and(U32.is_le(lo, c), U32.is_le(c, hi))

# A hex digit's value, or 16.
def unnibble(+c: U32) -> U32:
  Bool.pick(U32, in(48, c, 57), (c - 48 : U32), Bool.pick(U32, in(97, c, 102), (c - 87 : U32), Bool.pick(U32, in(65, c, 70), (c - 55 : U32), 16)))

def poke.when(write: Bool, a: Array<U32>, +i: U32, +v: U32) -> Array<U32>:
  match write:
    case True{}:
      poke(a, i, v)
    case False{}:
      a

# hi is the previous digit; an odd i completes a byte.
def unhex.go(s: String, a: Array<U32>, +i: U32, +hi: U32, +ok: Bool) -> Array<U32> & Bool:
  match s:
    case SNil{}:
      (a, ok)
    case SCon{Chr{+c}, t}:
      +d = unnibble(c)
      unhex.go(t, poke.when(U32.is_eq((i .&. 1 : U32), 1), a, (i >> 1n : U32), ((hi << 4n) .|. d : U32)), (i + 1 : U32), d, Bool.and(ok, U32.is_lt(d, 16)))

def decoded(+n: U32, r: Array<U32> & Bool) -> Maybe<&1, Bytes>:
  (a, ok) = r
  match ok:
    case True{}:
      Some{Bytes{n, a}}
    case False{}:
      None{}

def unhex.if(even: Bool, +s: String, +n: U32) -> Maybe<&1, Bytes>:
  match even:
    case True{}:
      decoded((n >> 1n : U32), unhex.go(s, alloc((n >> 1n : U32)), 0, 0, True{}))
    case False{}:
      None{}

# Hex digits, either case, to bytes. None for an odd count or a non-hex char.
def from_hex(+s: String) -> Maybe<&1, Bytes>:
  +n = count(s, 0)
  unhex.if(U32.is_eq((n .&. 1 : U32), 0), s, n)

# RFC 4648 §4: the standard alphabet, padded with '='.
def b64.char(+i: U32) -> U32:
  Bool.pick(U32, U32.is_lt(i, 26), (65 + i : U32), Bool.pick(U32, U32.is_lt(i, 52), (71 + i : U32), Bool.pick(U32, U32.is_lt(i, 62), (i - 4 : U32), Bool.pick(U32, U32.is_eq(i, 62), 43, 47))))

# The six bits of v at k as a base64 char.
def b64.at(+v: U32, +k: Nat) -> Char:
  Chr{b64.char((U32.shrn(v, k) .&. 63 : U32))}

# Groups of three bytes, last first; r holds the 24 bits of the group at i.
def b64.go(n: Nat, r: Array<U32> & U32, +i: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      (a, +v) = r
      +j = (i - 3 : U32)
      b64.go(p, uint.go(3n, peek(a, j), j, True{}, 0), j, SCon{b64.at(v, 18n), SCon{b64.at(v, 12n), SCon{b64.at(v, 6n), SCon{b64.at(v, 0n), acc}}}})

# The rem < 3 bytes after the last whole group, then the groups before them.
def b64.tail(+rem: U32, +t: U32, +q: U32, r: Array<U32> & U32) -> String:
  (a, +v0) = r
  +v = U32.shln(v0, U32.to_nat(((3 - rem) * 8 : U32)))
  +end = Bool.pick(String, U32.is_eq(rem, 0), "", Bool.pick(String, U32.is_eq(rem, 1), SCon{b64.at(v, 18n), SCon{b64.at(v, 12n), "=="}}, SCon{b64.at(v, 18n), SCon{b64.at(v, 12n), SCon{b64.at(v, 6n), "="}}}))
  +j = (t - 3 : U32)
  b64.go(U32.to_nat(q), uint.go(3n, peek(a, j), j, True{}, 0), j, end)

# Base64 (RFC 4648 §4) with '=' padding.
def to_base64(b: Bytes) -> String:
  Bytes{+len, buf} = b
  +q = (len / 3 : U32)
  +t = (q * 3 : U32)
  b64.tail((len - t : U32), t, q, uint.go(U32.to_nat((len - t : U32)), peek(buf, t), t, True{}, 0))

# A base64 char's value, 64 for '=', or 65.
def b64.val(+c: U32) -> U32:
  Bool.pick(U32, in(65, c, 90), (c - 65 : U32), Bool.pick(U32, in(97, c, 122), (c - 71 : U32), Bool.pick(U32, in(48, c, 57), (c + 4 : U32), Bool.pick(U32, U32.is_eq(c, 43), 62, Bool.pick(U32, U32.is_eq(c, 47), 63, Bool.pick(U32, U32.is_eq(c, 61), 64, 65))))))

# The count of '=' at the end of s.
def b64.pads(s: String, +run: U32) -> U32:
  match s:
    case SNil{}:
      run
    case SCon{Chr{+c}, t}:
      b64.pads(t, Bool.pick(U32, U32.is_eq(c, 61), (run + 1 : U32), 0))

# A whole group of four chars writes its bytes at o, as many as fit before len.
def b64.put(full: Bool, a: Array<U32>, +o: U32, +w: U32, +v: U32) -> Array<U32>:
  match full:
    case True{}:
      put.go(U32.to_nat(w), a, (o + w - 1 : U32), False{}, U32.shrn(v, U32.to_nat(((3 - w) * 8 : U32))))
    case False{}:
      a

# v collects six bits per char. '=' is allowed only at body and after.
def unb64.go(s: String, a: Array<U32>, +i: U32, +v: U32, +ok: Bool, +len: U32, +body: U32) -> Array<U32> & Bool:
  match s:
    case SNil{}:
      (a, ok)
    case SCon{Chr{+c}, t}:
      +d = b64.val(c)
      +v2 = ((v << 6n) .|. (d .&. 63) : U32)
      +o = ((i >> 2n) * 3 : U32)
      +good = Bool.pick(Bool, U32.is_lt(i, body), U32.is_lt(d, 64), U32.is_eq(d, 64))
      unb64.go(t, b64.put(U32.is_eq((i .&. 3 : U32), 3), a, o, U32.min(3, (len - o : U32)), v2), (i + 1 : U32), v2, Bool.and(ok, good), len, body)

def unb64.if(ok: Bool, +s: String, +n: U32, +pads: U32) -> Maybe<&1, Bytes>:
  match ok:
    case True{}:
      +len = ((n >> 2n) * 3 - pads : U32)
      decoded(len, unb64.go(s, alloc(len), 0, 0, True{}, len, (n - pads : U32)))
    case False{}:
      None{}

# Padded base64 (RFC 4648 §4) to bytes. None for a length that is not a multiple of 4,
# more than two '=', '=' before the end, or a char outside the alphabet.
def from_base64(+s: String) -> Maybe<&1, Bytes>:
  +n = count(s, 0)
  +pads = b64.pads(s, 0)
  unb64.if(Bool.and(U32.is_eq((n .&. 3 : U32), 0), U32.is_le(pads, 2)), s, n, pads)

# A cursor owns the same packed buffer; start and end bound a region without slicing it.
type Cursor is Type:
  Cursor{bytes: Bytes, pos: U32, start: U32, end: U32}

type CursorLimit is Type:
  CursorLimit{resume: U32, start: U32, end: U32}

def Cursor.new(b: Bytes) -> Cursor:
  Bytes{+len, buf} = b
  Cursor{Bytes{len, buf}, 0, 0, len}

def Cursor.finish(c: Cursor) -> Bytes & U32:
  Cursor{b, pos, start, end} = c
  (b, pos)

def Cursor.position(c: Cursor) -> Cursor & U32:
  Cursor{b, +pos, start, end} = c
  (Cursor{b, pos, start, end}, pos)

def Cursor.remaining(c: Cursor) -> Cursor & U32:
  Cursor{b, +pos, start, +end} = c
  (Cursor{b, pos, start, end}, (end - U32.min(pos, end) : U32))

def Cursor.fits(+len: U32, +pos: U32, +start: U32, +end: U32, +n: U32) -> Bool:
  U32.is_le(start, pos) && U32.is_le(end, len) && fits(end, pos, n)

def Cursor.seek.if(ok: Bool, c: Cursor, +pos: U32) -> Cursor & Bool:
  match ok:
    case False{}:
      (c, False{})
    case True{}:
      Cursor{b, old, start, end} = c
      (Cursor{b, pos, start, end}, True{})

def Cursor.seek(c: Cursor, +pos: U32) -> Cursor & Bool:
  Cursor{Bytes{+len, buf}, old, +start, +end} = c
  Cursor.seek.if(Cursor.fits(len, pos, start, end, 0), Cursor{Bytes{len, buf}, old, start, end}, pos)

def Cursor.skip(c: Cursor, +n: U32) -> Cursor & Bool:
  Cursor{Bytes{+len, buf}, +pos, +start, +end} = c
  Cursor.seek.if(Cursor.fits(len, pos, start, end, n), Cursor{Bytes{len, buf}, pos, start, end}, (pos + n : U32))

# On success, read inside the region, then leave with the returned affine limit.
def Cursor.region.if(ok: Bool, c: Cursor, +n: U32) -> Cursor & Maybe<&1, CursorLimit>:
  match ok:
    case False{}:
      (c, None{})
    case True{}:
      Cursor{b, +pos, start, end} = c
      +resume = (pos + n : U32)
      (Cursor{b, pos, pos, resume}, Some{CursorLimit{resume, start, end}})

def Cursor.region(c: Cursor, +n: U32) -> Cursor & Maybe<&1, CursorLimit>:
  Cursor{Bytes{+len, buf}, +pos, +start, +end} = c
  Cursor.region.if(Cursor.fits(len, pos, start, end, n), Cursor{Bytes{len, buf}, pos, start, end}, n)

def Cursor.leave(c: Cursor, limit: CursorLimit) -> Cursor:
  Cursor{b, pos, start, end} = c
  CursorLimit{resume, outer_start, outer_end} = limit
  Cursor{b, resume, outer_start, outer_end}

def Cursor.read.done(~T: Data, +pos: U32, start: U32, end: U32, +n: U32, r: Bytes & Maybe<&2, T>) -> Cursor & Maybe<&2, T>:
  (b, m) = r
  match m:
    case None{}:
      (Cursor{b, pos, start, end}, None{})
    case Some{v}:
      (Cursor{b, (pos + n : U32), start, end}, Some{v})

def Cursor.read.if(~T: Data, ~read: Bytes -> @+i:U32 -> Bytes & Maybe<&2, T>, ok: Bool, c: Cursor, +n: U32) -> Cursor & Maybe<&2, T>:
  match ok:
    case False{}:
      (c, None{})
    case True{}:
      Cursor{b, +pos, start, end} = c
      Cursor.read.done(~T, pos, start, end, n, read(b, pos))

def Cursor.read(~T: Data, ~read: Bytes -> @+i:U32 -> Bytes & Maybe<&2, T>, c: Cursor, +n: U32) -> Cursor & Maybe<&2, T>:
  Cursor{Bytes{+len, buf}, +pos, +start, +end} = c
  Cursor.read.if(~T, ~read, Cursor.fits(len, pos, start, end, n), Cursor{Bytes{len, buf}, pos, start, end}, n)

def Cursor.u8(c: Cursor) -> Cursor & Maybe<&2, U32>:
  Cursor.read(~U32, ~get, c, 1)

def Cursor.u16be(c: Cursor) -> Cursor & Maybe<&2, U32>:
  Cursor.read(~U32, ~get.u16be, c, 2)

def Cursor.u16le(c: Cursor) -> Cursor & Maybe<&2, U32>:
  Cursor.read(~U32, ~get.u16le, c, 2)

def Cursor.u32be(c: Cursor) -> Cursor & Maybe<&2, U32>:
  Cursor.read(~U32, ~get.u32be, c, 4)

def Cursor.u32le(c: Cursor) -> Cursor & Maybe<&2, U32>:
  Cursor.read(~U32, ~get.u32le, c, 4)

def Cursor.u64be(c: Cursor) -> Cursor & Maybe<&2, Int.U64>:
  Cursor.read(~Int.U64, ~get.u64be, c, 8)

def Cursor.u64le(c: Cursor) -> Cursor & Maybe<&2, Int.U64>:
  Cursor.read(~Int.U64, ~get.u64le, c, 8)

def Cursor.write.if(~T: Data, ~write: Bytes -> @+i:U32 -> @+v:T -> Bytes, ok: Bool, c: Cursor, +n: U32, v: T) -> Cursor & Bool:
  match ok:
    case False{}:
      (c, False{})
    case True{}:
      Cursor{b, +pos, start, end} = c
      (Cursor{write(b, pos, v), (pos + n : U32), start, end}, True{})

def Cursor.write(~T: Data, ~write: Bytes -> @+i:U32 -> @+v:T -> Bytes, c: Cursor, +n: U32, v: T) -> Cursor & Bool:
  Cursor{Bytes{+len, buf}, +pos, +start, +end} = c
  Cursor.write.if(~T, ~write, Cursor.fits(len, pos, start, end, n), Cursor{Bytes{len, buf}, pos, start, end}, n, v)

def Cursor.put.u8(c: Cursor, v: U32) -> Cursor & Bool:
  Cursor.write(~U32, ~set, c, 1, v)

def Cursor.put.u16be(c: Cursor, v: U32) -> Cursor & Bool:
  Cursor.write(~U32, ~set.u16be, c, 2, v)

def Cursor.put.u16le(c: Cursor, v: U32) -> Cursor & Bool:
  Cursor.write(~U32, ~set.u16le, c, 2, v)

def Cursor.put.u32be(c: Cursor, v: U32) -> Cursor & Bool:
  Cursor.write(~U32, ~set.u32be, c, 4, v)

def Cursor.put.u32le(c: Cursor, v: U32) -> Cursor & Bool:
  Cursor.write(~U32, ~set.u32le, c, 4, v)

def Cursor.put.u64be(c: Cursor, v: Int.U64) -> Cursor & Bool:
  Cursor.write(~Int.U64, ~set.u64be, c, 8, v)

def Cursor.put.u64le(c: Cursor, v: Int.U64) -> Cursor & Bool:
  Cursor.write(~Int.U64, ~set.u64le, c, 8, v)
