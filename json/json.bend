# JSON values, parsed and encoded as RFC 8259. Source: https://github.com/paymog/bend-kit/tree/main/json
import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# JSON (RFC 8259) as UTF-8 in Bytes. Strings, numbers and object keys are
# UTF-8 Bytes too. Nesting has no depth limit other than input size: the parser
# keeps its own stack, since a Bend def cannot call itself through another def.
#   import ./json/json.bend as Json

# Num keeps the number's exact text, so no precision is lost. Obj keeps its
# fields in document order, repeated keys included.
type Val is Type:
  Null{}
  Flag{on: Bool}
  Num{s: Bytes.Bytes}
  Str{s: Bytes.Bytes}
  Arr{xs: List<&1, Val>}
  Obj{kvs: List<&1, Bytes.Bytes & Val>}

# An open container: array items so far, object fields so far, or those fields
# and the key whose value comes next. Items and fields are reversed.
type Open is Type:
  OArr{xs: List<&1, Val>}
  OObj{kvs: List<&1, Bytes.Bytes & Val>}
  OKey{kvs: List<&1, Bytes.Bytes & Val>, key: Bytes.Bytes}

# Writer
# ------
# Octets being written: the buffer, its size in words, the count so far, and
# the word being filled. Bytes enter at the top of w, as in Bytes.from_string.
type W is Type:
  W{buf: Array<U32>, cap: U32, n: U32, w: U32}

# The buffer doubles when word k does not fit.
def w.room(grow: Bool, buf: Array<U32>, +k: U32) -> Array<U32>:
  match grow:
    case True{}:
      Bytes.grow((k * 4 : U32), buf, (k * 8 : U32))
    case False{}:
      buf

def w.store(full: Bool, buf: Array<U32>, +cap: U32, +n: U32, +w: U32) -> W:
  match full:
    case True{}:
      +k = (n >> 2n : U32)
      +g = U32.is_eq(k, cap)
      W{Array.set(U32, w.room(g, buf, k), k, w), Bool.pick(U32, g, (cap * 2 : U32), cap), (n + 1 : U32), 0}
    case False{}:
      W{buf, cap, (n + 1 : U32), w}

def w.put(o: W, +b: U32) -> W:
  W{buf, +cap, +n, +w} = o
  w.store(U32.is_eq((n .&. 3 : U32), 3), buf, cap, n, ((w >> 8n) .|. (b << 24n) : U32))

def w.shrink(fit: Bool, +n: U32, buf: Array<U32>) -> Array<U32>:
  match fit:
    case True{}:
      buf
    case False{}:
      Bytes.dst(Bytes.copy(n, buf, Bytes.alloc(n), 0, 0))

# Stores the last partial word, then copies into the fewest words, as Bytes requires.
def w.done(o: W) -> Bytes.Bytes:
  W{buf, +cap, +n, +w} = o
  +r = (n .&. 3 : U32)
  +k = (n >> 2n : U32)
  +g = U32.is_ne(r, 0) && U32.is_eq(k, cap)
  +cap2 = Bool.pick(U32, g, (cap * 2 : U32), cap)
  out = Bytes.flush(U32.is_ne(r, 0), w.room(g, buf, k), k, U32.shrn(w, U32.to_nat((((4 - r) .&. 3) * 8 : U32))))
  Bytes.Bytes{n, w.shrink(U32.is_eq(U32.shln(1, Bytes.depth(Bytes.words(n))), cap2), n, out)}

def w.cont(+c: U32, +k: Nat) -> U32:
  (128 + (U32.shrn(c, k) .&. 63) : U32)

def w.cp.of(+n: U32, +c: U32, o: W) -> W:
  match n:
    case 1:
      w.put(o, c)
    case 2:
      w.put(w.put(o, (192 + U32.shrn(c, 6n) : U32)), w.cont(c, 0n))
    case 3:
      w.put(w.put(w.put(o, (224 + U32.shrn(c, 12n) : U32)), w.cont(c, 6n)), w.cont(c, 0n))
    case _:
      w.put(w.put(w.put(w.put(o, (240 + U32.shrn(c, 18n) : U32)), w.cont(c, 12n)), w.cont(c, 6n)), w.cont(c, 0n))

# One code point in UTF-8.
def w.cp(+c: U32, o: W) -> W:
  w.cp.of(Bool.pick(U32, U32.is_lt(c, 128), 1, Bool.pick(U32, U32.is_lt(c, 2048), 2, Bool.pick(U32, U32.is_lt(c, 65536), 3, 4))), c, o)

def w.hex(+n: U32) -> U32:
  Bool.pick(U32, U32.is_lt(n, 10), (48 + n : U32), (87 + n : U32))

def w.new() -> W:
  W{Bytes.alloc(0), 1, 0, 0}

def w.of.at(+len: U32, +cap: U32, r: Array<U32> & U32) -> W:
  (buf, +v) = r
  +m = (len .&. 3 : U32)
  W{buf, cap, len, Bool.pick(U32, U32.is_eq(m, 0), 0, U32.shln(v, U32.to_nat(((4 - m) * 8 : U32))))}

# A writer that appends to b.
def w.of(b: Bytes.Bytes) -> W:
  Bytes.Bytes{+len, buf} = b
  w.of.at(len, U32.shln(1, Bytes.depth(Bytes.words(len))), Array.get(U32, buf, (len >> 2n : U32)))

def w.text(s: String, o: W) -> W:
  match s:
    case SNil{}:
      o
    case SCon{Chr{+c}, t}:
      w.text(t, w.cp(c, o))

# Text, one Char per code point, as UTF-8.
def utf8(s: String) -> Bytes.Bytes:
  w.done(w.text(s, w.new()))

# Numbers (§6)
# ------------
# States: 0 start, 1 after "-", 2 after a leading "0", 3 int digits, 4 after
# ".", 5 fraction digits, 6 after "e", 7 after the exponent sign, 8 exponent
# digits. 99 means the char does not continue the number.

def digit(+c: U32) -> Bool:
  Bool.and(U32.is_le(48, c), U32.is_le(c, 57))

def num.trans(+st: U32, +c: U32) -> U32:
  +d = digit(c)
  +z = U32.is_eq(c, 48)
  +dot = U32.is_eq(c, 46)
  +e = Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69))
  +sign = Bool.or(U32.is_eq(c, 43), U32.is_eq(c, 45))
  Bool.pick(U32, U32.is_eq(st, 0), Bool.pick(U32, U32.is_eq(c, 45), 1, Bool.pick(U32, z, 2, Bool.pick(U32, d, 3, 99))),
  Bool.pick(U32, U32.is_eq(st, 1), Bool.pick(U32, z, 2, Bool.pick(U32, d, 3, 99)),
  Bool.pick(U32, Bool.or(U32.is_eq(st, 2), U32.is_eq(st, 3)), Bool.pick(U32, Bool.and(d, U32.is_eq(st, 3)), 3, Bool.pick(U32, dot, 4, Bool.pick(U32, e, 6, 99))),
  Bool.pick(U32, Bool.or(U32.is_eq(st, 4), U32.is_eq(st, 5)), Bool.pick(U32, d, 5, Bool.pick(U32, Bool.and(e, U32.is_eq(st, 5)), 6, 99)),
  Bool.pick(U32, U32.is_eq(st, 6), Bool.pick(U32, sign, 7, Bool.pick(U32, d, 8, 99)),
  Bool.pick(U32, Bool.or(U32.is_eq(st, 7), U32.is_eq(st, 8)), Bool.pick(U32, d, 8, 99), 99))))))

def num.accepts(+st: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(st, 2), U32.is_eq(st, 3)), Bool.or(U32.is_eq(st, 5), U32.is_eq(st, 8)))

# Strings (§7)
# ------------

def hexd(+c: U32) -> U32:
  Bool.pick(U32, digit(c), (c - 48 : U32), Bool.pick(U32, Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), (c - 87 : U32), Bool.pick(U32, Bool.and(U32.is_le(65, c), U32.is_le(c, 70)), (c - 55 : U32), 99)))

def is_hi(+v: U32) -> Bool:
  Bool.and(U32.is_le(55296, v), U32.is_le(v, 56319))

def is_lo(+v: U32) -> Bool:
  Bool.and(U32.is_le(56320, v), U32.is_le(v, 57343))

def esc.simple(+e: U32) -> U32:
  Bool.pick(U32, U32.is_eq(e, 34), 34, Bool.pick(U32, U32.is_eq(e, 92), 92, Bool.pick(U32, U32.is_eq(e, 47), 47,
  Bool.pick(U32, U32.is_eq(e, 98), 8, Bool.pick(U32, U32.is_eq(e, 102), 12, Bool.pick(U32, U32.is_eq(e, 110), 10,
  Bool.pick(U32, U32.is_eq(e, 114), 13, Bool.pick(U32, U32.is_eq(e, 116), 9, 99))))))))

# Parse
# -----
# A state holds the offset of its next byte; the buffer goes beside it. A
# string with no escape is copied out of the buffer when it closes; at its
# first escape it moves into a writer.

type Sb is Type:
  BValue{i: U32, stack: List<&1, Open>}
  BFirst{i: U32, open: Open, stack: List<&1, Open>}
  BKey{i: U32, stack: List<&1, Open>}
  BColon{key: Bytes.Bytes, i: U32, stack: List<&1, Open>}
  BStr{i: U32, start: U32, key: Bool, stack: List<&1, Open>}
  BEsc{i: U32, acc: W, key: Bool, stack: List<&1, Open>}
  BNum{i: U32, start: U32, st: U32, stack: List<&1, Open>}
  BAfter{v: Val, i: U32, stack: List<&1, Open>}
  BSep{i: U32, open: Open, stack: List<&1, Open>}
  BEnd{v: Val, i: U32}
  BOk{v: Val}
  BFail{}

type Cp is Data:
  Cp{c: U32, w: U32}

def pk.if(ok: Bool, a: Array<U32>, +i: U32) -> Array<U32> & U32:
  match ok:
    case True{}:
      Bytes.peek(a, i)
    case False{}:
      (a, 256)

# Byte i, or 256 at the end, which no rule accepts.
def pk(a: Array<U32>, +len: U32, +i: U32) -> Array<U32> & U32:
  pk.if(U32.is_lt(i, len), a, i)

def word.go(w: String, ok: Bool, r: Array<U32> & U32, +len: U32, +j: U32) -> Array<U32> & Bool:
  match w:
    case SNil{}:
      (a, b) = r
      (a, ok)
    case SCon{Chr{+c}, t}:
      (a, +b) = r
      word.go(t, ok && U32.is_eq(b, c), pk(a, len, (j + 1 : U32)), len, (j + 1 : U32))

# Do the bytes from j spell w?
def word(a: Array<U32>, +len: U32, w: String, +j: U32) -> Array<U32> & Bool:
  word.go(w, True{}, pk(a, len, j), len, j)

def hex4.b.go(n: Nat, r: Array<U32> & U32, +len: U32, +j: U32, +acc: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      (a, b) = r
      (a, acc)
    case 1n+k:
      (a, +b) = r
      +h = hexd(b)
      hex4.b.go(k, pk(a, len, (j + 1 : U32)), len, (j + 1 : U32), Bool.pick(U32, U32.is_eq(h, 99) || U32.is_eq(acc, 65536), 65536, (acc * 16 + h : U32)))

# Four hex digits from byte j, or 65536 if one is not a hex digit.
def hex4.b(a: Array<U32>, +len: U32, +j: U32) -> Array<U32> & U32:
  hex4.b.go(4n, pk(a, len, j), len, j, 0)

def cont(+b: U32) -> Bool:
  U32.is_eq((b .&. 192 : U32), 128)

# RFC 3629 §4: overlong forms, surrogates, and code points past U+10FFFF are invalid, width 0.
def utf8.n(+b0: U32, +b1: U32, +b2: U32, +b3: U32) -> Cp:
  +x1 = (b1 .&. 63 : U32)
  +x2 = (b2 .&. 63 : U32)
  +x3 = (b3 .&. 63 : U32)
  +c2 = (((b0 .&. 31) << 6n) .|. x1 : U32)
  +c3 = ((((b0 .&. 15) << 12n) .|. (x1 << 6n)) .|. x2 : U32)
  +c4 = (((((b0 .&. 7) << 18n) .|. (x1 << 12n)) .|. (x2 << 6n)) .|. x3 : U32)
  +ok2 = U32.is_le(192, b0) && U32.is_lt(b0, 224) && cont(b1) && U32.is_le(128, c2)
  +ok3 = U32.is_le(224, b0) && U32.is_lt(b0, 240) && cont(b1) && cont(b2) && U32.is_le(2048, c3) && (U32.is_lt(c3, 55296) || U32.is_lt(57343, c3))
  +ok4 = U32.is_le(240, b0) && U32.is_lt(b0, 248) && cont(b1) && cont(b2) && cont(b3) && U32.is_le(65536, c4) && U32.is_le(c4, 1114111)
  Bool.pick(Cp, ok2, Cp{c2, 2}, Bool.pick(Cp, ok3, Cp{c3, 3}, Bool.pick(Cp, ok4, Cp{c4, 4}, Cp{0, 0})))

def utf8.b3(+b0: U32, +b1: U32, +b2: U32, r: Array<U32> & U32) -> Array<U32> & Cp:
  (a, +b3) = r
  (a, utf8.n(b0, b1, b2, b3))

def utf8.b2(+len: U32, +i: U32, +b0: U32, +b1: U32, r: Array<U32> & U32) -> Array<U32> & Cp:
  (a, +b2) = r
  utf8.b3(b0, b1, b2, pk(a, len, (i + 3 : U32)))

def utf8.b1(+len: U32, +i: U32, +b0: U32, r: Array<U32> & U32) -> Array<U32> & Cp:
  (a, +b1) = r
  utf8.b2(len, i, b0, b1, pk(a, len, (i + 2 : U32)))

# The code point whose lead byte b0 is at i.
def utf8.at(a: Array<U32>, +len: U32, +i: U32, +b0: U32) -> Array<U32> & Cp:
  utf8.b1(len, i, b0, pk(a, len, (i + 1 : U32)))

def slice.of(+n: U32, r: Array<U32> & Array<U32>) -> Array<U32> & Bytes.Bytes:
  (a, out) = r
  (a, Bytes.Bytes{n, out})

# The n bytes from start, copied.
def slice(+n: U32, +start: U32, a: Array<U32>) -> Array<U32> & Bytes.Bytes:
  slice.of(n, Bytes.copy(n, a, Bytes.alloc(n), start, 0))

def str.b.done(key: Bool, s: Bytes.Bytes, +i: U32, stack: List<&1, Open>) -> Sb:
  match key:
    case True{}:
      BColon{s, i, stack}
    case False{}:
      BAfter{Str{s}, i, stack}

def esc.b.lo.if(ok: Bool, +i: U32, +hi: U32, +lo: U32, acc: W, key: Bool, stack: List<&1, Open>) -> Sb:
  match ok:
    case True{}:
      BEsc{(i + 12 : U32), w.cp((65536 + (hi - 55296 : U32) * 1024 + (lo - 56320 : U32) : U32), acc), key, stack}
    case False{}:
      BEsc{(i + 6 : U32), w.cp(65533, acc), key, stack}

def esc.b.lo(+i: U32, +hi: U32, acc: W, key: Bool, stack: List<&1, Open>, r: Array<U32> & U32) -> Array<U32> & Sb:
  (a, +lo) = r
  (a, esc.b.lo.if(is_lo(lo), i, hi, lo, acc, key, stack))

# §8.2: a high surrogate pairs with a following \uDC00-\uDFFF; a lone one is U+FFFD.
def esc.b.pair(+len: U32, +i: U32, +hi: U32, acc: W, key: Bool, stack: List<&1, Open>, r: Array<U32> & Bool) -> Array<U32> & Sb:
  (a, ok) = r
  match ok:
    case True{}:
      esc.b.lo(i, hi, acc, key, stack, hex4.b(a, len, (i + 8 : U32)))
    case False{}:
      (a, BEsc{(i + 6 : U32), w.cp(65533, acc), key, stack})

# 0: not four hex digits; 1: high surrogate; 2: low surrogate; 3: other.
def u.class(+v: U32) -> U32:
  Bool.pick(U32, U32.is_eq(v, 65536), 0, Bool.pick(U32, is_hi(v), 1, Bool.pick(U32, is_lo(v), 2, 3)))

def esc.b.u.of(+k: U32, a: Array<U32>, +len: U32, +i: U32, +v: U32, acc: W, key: Bool, stack: List<&1, Open>) -> Array<U32> & Sb:
  match k:
    case 0:
      (a, BFail{})
    case 1:
      esc.b.pair(len, i, v, acc, key, stack, word(a, len, "\\u", (i + 6 : U32)))
    case 2:
      (a, BEsc{(i + 6 : U32), w.cp(65533, acc), key, stack})
    case _:
      (a, BEsc{(i + 6 : U32), w.cp(v, acc), key, stack})

def esc.b.u(+len: U32, +i: U32, acc: W, key: Bool, stack: List<&1, Open>, r: Array<U32> & U32) -> Array<U32> & Sb:
  (a, +v) = r
  esc.b.u.of(u.class(v), a, len, i, v, acc, key, stack)

# The escape whose backslash is at i.
def esc.b.one(+len: U32, +i: U32, acc: W, key: Bool, stack: List<&1, Open>, r: Array<U32> & U32) -> Array<U32> & Sb:
  (a, +e) = r
  match e:
    case 117:
      esc.b.u(len, i, acc, key, stack, hex4.b(a, len, (i + 2 : U32)))
    case _:
      +v = esc.simple(e)
      (a, Bool.pick(Sb, U32.is_eq(v, 99), BFail{}, BEsc{(i + 2 : U32), w.put(acc, v), key, stack}))

def esc.b.cp(acc: W, key: Bool, stack: List<&1, Open>, +i: U32, r: Array<U32> & Cp) -> Array<U32> & Sb:
  (a, Cp{+c, +n}) = r
  (a, Bool.pick(Sb, U32.is_eq(n, 0), BFail{}, BEsc{(i + n : U32), w.cp(c, acc), key, stack}))

# §7: unescaped chars below U+0020 are not allowed in a string.
def esc.b.other(ascii: Bool, +c: U32, a: Array<U32>, +len: U32, +i: U32, acc: W, key: Bool, stack: List<&1, Open>) -> Array<U32> & Sb:
  match ascii:
    case True{}:
      (a, Bool.pick(Sb, U32.is_lt(c, 32), BFail{}, BEsc{(i + 1 : U32), w.put(acc, c), key, stack}))
    case False{}:
      esc.b.cp(acc, key, stack, i, utf8.at(a, len, i, c))

# A string after its first escape.
def esc.b(r: Array<U32> & U32, +len: U32, +i: U32, acc: W, key: Bool, stack: List<&1, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 34:
      (a, str.b.done(key, w.done(acc), (i + 1 : U32), stack))
    case 92:
      esc.b.one(len, i, acc, key, stack, pk(a, len, (i + 1 : U32)))
    case 256:
      (a, BFail{})
    case _:
      esc.b.other(U32.is_lt(c, 128), c, a, len, i, acc, key, stack)

def str.b.close(key: Bool, +i: U32, stack: List<&1, Open>, r: Array<U32> & Bytes.Bytes) -> Array<U32> & Sb:
  (a, s) = r
  (a, str.b.done(key, s, (i + 1 : U32), stack))

def str.b.esc(+len: U32, +i: U32, key: Bool, stack: List<&1, Open>, r: Array<U32> & Bytes.Bytes) -> Array<U32> & Sb:
  (a, s) = r
  esc.b.one(len, i, w.of(s), key, stack, pk(a, len, (i + 1 : U32)))

def str.b.cp(+start: U32, key: Bool, stack: List<&1, Open>, +i: U32, r: Array<U32> & Cp) -> Array<U32> & Sb:
  (a, Cp{+c, +n}) = r
  (a, Bool.pick(Sb, U32.is_eq(n, 0), BFail{}, BStr{(i + n : U32), start, key, stack}))

def str.b.other(ascii: Bool, +c: U32, a: Array<U32>, +len: U32, +i: U32, +start: U32, key: Bool, stack: List<&1, Open>) -> Array<U32> & Sb:
  match ascii:
    case True{}:
      (a, Bool.pick(Sb, U32.is_lt(c, 32), BFail{}, BStr{(i + 1 : U32), start, key, stack}))
    case False{}:
      str.b.cp(start, key, stack, i, utf8.at(a, len, i, c))

# A string whose text so far starts at start and has no escape.
def str.b(r: Array<U32> & U32, +len: U32, +i: U32, +start: U32, key: Bool, stack: List<&1, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 34:
      str.b.close(key, i, stack, slice((i - start : U32), start, a))
    case 92:
      str.b.esc(len, i, key, stack, slice((i - start : U32), start, a))
    case 256:
      (a, BFail{})
    case _:
      str.b.other(U32.is_lt(c, 128), c, a, len, i, start, key, stack)

def num.b.fin(+i: U32, stack: List<&1, Open>, r: Array<U32> & Bytes.Bytes) -> Array<U32> & Sb:
  (a, s) = r
  (a, BAfter{Num{s}, i, stack})

def num.b.stop(ok: Bool, a: Array<U32>, +i: U32, +start: U32, stack: List<&1, Open>) -> Array<U32> & Sb:
  match ok:
    case True{}:
      num.b.fin(i, stack, slice((i - start : U32), start, a))
    case False{}:
      (a, BFail{})

def num.b.if(stop: Bool, a: Array<U32>, +i: U32, +start: U32, +st: U32, +n: U32, stack: List<&1, Open>) -> Array<U32> & Sb:
  match stop:
    case True{}:
      num.b.stop(num.accepts(st), a, i, start, stack)
    case False{}:
      (a, BNum{(i + 1 : U32), start, n, stack})

def num.b(r: Array<U32> & U32, +i: U32, +start: U32, +st: U32, stack: List<&1, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  +n = num.trans(st, c)
  num.b.if(U32.is_eq(n, 99), a, i, start, st, n, stack)

def lit.b(+i: U32, +n: U32, v: Val, stack: List<&1, Open>, r: Array<U32> & Bool) -> Array<U32> & Sb:
  (a, ok) = r
  match ok:
    case True{}:
      (a, BAfter{v, (i + n : U32), stack})
    case False{}:
      (a, BFail{})

def value.b(r: Array<U32> & U32, +len: U32, +i: U32, stack: List<&1, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 32:
      (a, BValue{(i + 1 : U32), stack})
    case 9:
      (a, BValue{(i + 1 : U32), stack})
    case 10:
      (a, BValue{(i + 1 : U32), stack})
    case 13:
      (a, BValue{(i + 1 : U32), stack})
    case 91:
      (a, BFirst{(i + 1 : U32), OArr{Nil{}}, stack})
    case 123:
      (a, BFirst{(i + 1 : U32), OObj{Nil{}}, stack})
    case 34:
      (a, BStr{(i + 1 : U32), (i + 1 : U32), False{}, stack})
    case 116:
      lit.b(i, 4, Flag{True{}}, stack, word(a, len, "true", i))
    case 102:
      lit.b(i, 5, Flag{False{}}, stack, word(a, len, "false", i))
    case 110:
      lit.b(i, 4, Null{}, stack, word(a, len, "null", i))
    case _:
      (a, BNum{i, i, 0, stack})

# After "[" or "{": the closing bracket, or the first item.
def first.b.end(open: Open, +c: U32, +i: U32, stack: List<&1, Open>) -> Sb:
  match open:
    case OArr{xs}:
      Bool.pick(Sb, U32.is_eq(c, 93), BAfter{Arr{xs}, (i + 1 : U32), stack}, BFail{})
    case OObj{kvs}:
      Bool.pick(Sb, U32.is_eq(c, 125), BAfter{Obj{kvs}, (i + 1 : U32), stack}, BFail{})
    case OKey{kvs, k}:
      BFail{}

def first.b.open(open: Open, +i: U32, stack: List<&1, Open>) -> Sb:
  match open:
    case OArr{xs}:
      BValue{i, Con{OArr{xs}, stack}}
    case OObj{kvs}:
      BKey{i, Con{OObj{kvs}, stack}}
    case OKey{kvs, k}:
      BFail{}

def first.b(r: Array<U32> & U32, +i: U32, open: Open, stack: List<&1, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 32:
      (a, BFirst{(i + 1 : U32), open, stack})
    case 9:
      (a, BFirst{(i + 1 : U32), open, stack})
    case 10:
      (a, BFirst{(i + 1 : U32), open, stack})
    case 13:
      (a, BFirst{(i + 1 : U32), open, stack})
    case 93:
      (a, first.b.end(open, c, i, stack))
    case 125:
      (a, first.b.end(open, c, i, stack))
    case _:
      (a, first.b.open(open, i, stack))

def key.b(r: Array<U32> & U32, +i: U32, stack: List<&1, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 32:
      (a, BKey{(i + 1 : U32), stack})
    case 9:
      (a, BKey{(i + 1 : U32), stack})
    case 10:
      (a, BKey{(i + 1 : U32), stack})
    case 13:
      (a, BKey{(i + 1 : U32), stack})
    case 34:
      (a, BStr{(i + 1 : U32), (i + 1 : U32), True{}, stack})
    case _:
      (a, BFail{})

def colon.b.top(k: Bytes.Bytes, +i: U32, stack: List<&1, Open>) -> Sb:
  match stack:
    case Nil{}:
      BFail{}
    case Con{OArr{xs}, up}:
      BFail{}
    case Con{OObj{kvs}, up}:
      BValue{i, Con{OKey{kvs, k}, up}}
    case Con{OKey{kvs, old}, up}:
      BFail{}

def colon.b(r: Array<U32> & U32, k: Bytes.Bytes, +i: U32, stack: List<&1, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 32:
      (a, BColon{k, (i + 1 : U32), stack})
    case 9:
      (a, BColon{k, (i + 1 : U32), stack})
    case 10:
      (a, BColon{k, (i + 1 : U32), stack})
    case 13:
      (a, BColon{k, (i + 1 : U32), stack})
    case 58:
      (a, colon.b.top(k, (i + 1 : U32), stack))
    case _:
      (a, BFail{})

# A finished value joins its container.
def after.b(v: Val, +i: U32, stack: List<&1, Open>) -> Sb:
  match stack:
    case Nil{}:
      BEnd{v, i}
    case Con{OArr{xs}, up}:
      BSep{i, OArr{Con{v, xs}}, up}
    case Con{OObj{kvs}, up}:
      BFail{}
    case Con{OKey{kvs, k}, up}:
      BSep{i, OObj{Con{(k, v), kvs}}, up}

def sep.b.comma(open: Open, +i: U32, up: List<&1, Open>) -> Sb:
  match open:
    case OArr{xs}:
      BValue{i, Con{OArr{xs}, up}}
    case OObj{kvs}:
      BKey{i, Con{OObj{kvs}, up}}
    case OKey{kvs, k}:
      BFail{}

def sep.b.close(open: Open, +c: U32, +i: U32, up: List<&1, Open>) -> Sb:
  match open:
    case OArr{xs}:
      Bool.pick(Sb, U32.is_eq(c, 93), BAfter{Arr{List.reverse(&1, Val, xs)}, i, up}, BFail{})
    case OObj{kvs}:
      Bool.pick(Sb, U32.is_eq(c, 125), BAfter{Obj{List.reverse(&1, Bytes.Bytes & Val, kvs)}, i, up}, BFail{})
    case OKey{kvs, k}:
      BFail{}

# After an item: "," or the closing bracket.
def sep.b(r: Array<U32> & U32, +i: U32, open: Open, up: List<&1, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 32:
      (a, BSep{(i + 1 : U32), open, up})
    case 9:
      (a, BSep{(i + 1 : U32), open, up})
    case 10:
      (a, BSep{(i + 1 : U32), open, up})
    case 13:
      (a, BSep{(i + 1 : U32), open, up})
    case 44:
      (a, sep.b.comma(open, (i + 1 : U32), up))
    case _:
      (a, sep.b.close(open, c, (i + 1 : U32), up))

def end.b(r: Array<U32> & U32, v: Val, +i: U32) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 32:
      (a, BEnd{v, (i + 1 : U32)})
    case 9:
      (a, BEnd{v, (i + 1 : U32)})
    case 10:
      (a, BEnd{v, (i + 1 : U32)})
    case 13:
      (a, BEnd{v, (i + 1 : U32)})
    case 256:
      (a, BOk{v})
    case _:
      (a, BFail{})

# fuel: a step eats a byte, or ends a number, a value, or an opening bracket, so 4 * len + 4 steps are enough.
def runb(fuel: Nat, r: Array<U32> & Sb, +len: U32) -> Maybe<&1, Val>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      (a, sb) = r
      match sb:
        case BOk{v}:
          Some{v}
        case BFail{}:
          None{}
        case BValue{+i, stack}:
          runb(f, value.b(pk(a, len, i), len, i, stack), len)
        case BFirst{+i, open, stack}:
          runb(f, first.b(pk(a, len, i), i, open, stack), len)
        case BKey{+i, stack}:
          runb(f, key.b(pk(a, len, i), i, stack), len)
        case BColon{k, +i, stack}:
          runb(f, colon.b(pk(a, len, i), k, i, stack), len)
        case BStr{+i, +s, k, stack}:
          runb(f, str.b(pk(a, len, i), len, i, s, k, stack), len)
        case BEsc{+i, acc, k, stack}:
          runb(f, esc.b(pk(a, len, i), len, i, acc, k, stack), len)
        case BNum{+i, +s, +st, stack}:
          runb(f, num.b(pk(a, len, i), i, s, st, stack), len)
        case BAfter{v, +i, stack}:
          runb(f, (a, after.b(v, i, stack)), len)
        case BSep{+i, open, stack}:
          runb(f, sep.b(pk(a, len, i), i, open, stack), len)
        case BEnd{v, +i}:
          runb(f, end.b(pk(a, len, i), v, i), len)

# One JSON text in UTF-8. None for bad JSON or bad UTF-8 (RFC 8259 §8.1).
def parse.bytes(b: Bytes.Bytes) -> Maybe<&1, Val>:
  Bytes.Bytes{+len, buf} = b
  runb(Nat.add(Nat.mul(U32.to_nat(len), 4n), 4n), (buf, BValue{0, Nil{}}), len)

# Access
# ------

def get.pick(v: Val, found: Maybe<&1, Val>, r: Bytes.Bytes & Bytes.Bytes & Bool) -> Bytes.Bytes & Maybe<&1, Val>:
  (k, key, same) = r
  (key, Bool.pick(Maybe<&1, Val>, same, Some{v}, found))

def get.step(k: Bytes.Bytes, v: Val, st: Bytes.Bytes & Maybe<&1, Val>) -> Bytes.Bytes & Maybe<&1, Val>:
  (key, found) = st
  get.pick(v, found, Bytes.eq(k, key))

def get.go(kvs: List<&1, Bytes.Bytes & Val>, st: Bytes.Bytes & Maybe<&1, Val>) -> Maybe<&1, Val>:
  match kvs:
    case Nil{}:
      (key, found) = st
      found
    case (k, v) <> t:
      get.go(t, get.step(k, v, st))

# §4: the value under key k of an object; the last one when k repeats, as most parsers do.
def get(v: Val, k: String) -> Maybe<&1, Val>:
  match v:
    case Obj{kvs}:
      get.go(kvs, (utf8(k), None{}))
    case Null{}:
      None{}
    case Flag{on}:
      None{}
    case Num{n}:
      None{}
    case Str{s}:
      None{}
    case Arr{xs}:
      None{}

def at.go(xs: List<&1, Val>, n: Nat) -> Maybe<&1, Val>:
  match xs:
    case Nil{}:
      None{}
    case Con{v, t}:
      match n:
        case 0n:
          Some{v}
        case 1n+p:
          at.go(t, p)

# Item n of an array.
def at(v: Val, n: Nat) -> Maybe<&1, Val>:
  match v:
    case Arr{xs}:
      at.go(xs, n)
    case Null{}:
      None{}
    case Flag{on}:
      None{}
    case Num{s}:
      None{}
    case Str{s}:
      None{}
    case Obj{kvs}:
      None{}

def u32.over(+acc: U32, +c: U32) -> Bool:
  Bool.or(U32.is_lt(429496729, acc), Bool.and(U32.is_eq(acc, 429496729), U32.is_lt(53, c)))

def u32.dig(s: String, +acc: U32, bad: Bool) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      match bad:
        case True{}:
          None{}
        case False{}:
          Some{acc}
    case SCon{Chr{+c}, t}:
      u32.dig(t, (acc * 10 + (c - 48 : U32) : U32), Bool.or(bad, Bool.or(Bool.not(digit(c)), u32.over(acc, c))))

def u32.zero(t: String) -> Maybe<&2, U32>:
  match t:
    case SNil{}:
      Some{0}
    case SCon{d, u}:
      None{}

def u32.lead(+c: U32, t: String, zero: Bool) -> Maybe<&2, U32>:
  match zero:
    case True{}:
      u32.zero(t)
    case False{}:
      u32.dig(t, (c - 48 : U32), Bool.or(Bool.not(digit(c)), u32.over(0, c)))

def u32.num(s: String) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, t}:
      u32.lead(c, t, U32.is_eq(c, 48))

# A number that is a whole U32, with no sign, fraction or exponent.
def u32(v: Val) -> Maybe<&2, U32>:
  match v:
    case Num{s}:
      u32.num(Bytes.to_string(s))
    case Null{}:
      None{}
    case Flag{on}:
      None{}
    case Str{s}:
      None{}
    case Arr{xs}:
      None{}
    case Obj{kvs}:
      None{}

# Encode
# ------

def w.ctl(ctl: Bool, +c: U32, o: W) -> W:
  match ctl:
    case True{}:
      w.put(w.put(w.put(w.put(w.put(w.put(o, 92), 117), 48), 48), w.hex(U32.shrn(c, 4n))), w.hex((c .&. 15 : U32)))
    case False{}:
      w.put(o, c)

# §7: quote, backslash and control chars are escaped. Other bytes are already UTF-8.
def w.esc.c(+c: U32, o: W) -> W:
  match c:
    case 34:
      w.put(w.put(o, 92), 34)
    case 92:
      w.put(w.put(o, 92), 92)
    case 10:
      w.put(w.put(o, 92), 110)
    case 13:
      w.put(w.put(o, 92), 114)
    case 9:
      w.put(w.put(o, 92), 116)
    case _:
      w.ctl(U32.is_lt(c, 32), c, o)

def w.bytes.go(n: Nat, r: Array<U32> & U32, +i: U32, o: W) -> W:
  match n:
    case 0n:
      o
    case 1n+k:
      (a, +c) = r
      w.bytes.go(k, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), w.put(o, c))

def w.bytes(b: Bytes.Bytes, o: W) -> W:
  Bytes.Bytes{+len, buf} = b
  w.bytes.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, o)

def w.str.go(n: Nat, r: Array<U32> & U32, +i: U32, o: W) -> W:
  match n:
    case 0n:
      w.put(o, 34)
    case 1n+k:
      (a, +c) = r
      w.str.go(k, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), w.esc.c(c, o))

# A quoted, escaped string.
def w.str(b: Bytes.Bytes, o: W) -> W:
  Bytes.Bytes{+len, buf} = b
  w.str.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, w.put(o, 34))

type Item is Type:
  ILit{s: String}
  IKey{k: Bytes.Bytes}
  IVal{v: Val}

def items.sep(first: Bool, tail: List<&1, Item>) -> List<&1, Item>:
  match first:
    case True{}:
      tail
    case False{}:
      Con{ILit{","}, tail}

def items.arr(xs: List<&1, Val>, first: Bool, rest: List<&1, Item>) -> List<&1, Item>:
  match xs:
    case Nil{}:
      Con{ILit{"]"}, rest}
    case Con{x, t}:
      items.sep(first, Con{IVal{x}, items.arr(t, False{}, rest)})

def items.obj(kvs: List<&1, Bytes.Bytes & Val>, first: Bool, rest: List<&1, Item>) -> List<&1, Item>:
  match kvs:
    case Nil{}:
      Con{ILit{"}"}, rest}
    case (k, v) <> t:
      items.sep(first, Con{IKey{k}, Con{IVal{v}, items.obj(t, False{}, rest)}})

# ponytail: @unsafe because it walks a work list, not the Val; each step
# emits text or swaps a container for its strictly smaller parts.
@unsafe
def encb.go(items: List<&1, Item>, o: W) -> W:
  match items:
    case Nil{}:
      o
    case Con{ILit{s}, t}:
      encb.go(t, w.text(s, o))
    case Con{IKey{k}, t}:
      encb.go(t, w.put(w.str(k, o), 58))
    case Con{IVal{Null{}}, t}:
      encb.go(t, w.text("null", o))
    case Con{IVal{Flag{True{}}}, t}:
      encb.go(t, w.text("true", o))
    case Con{IVal{Flag{False{}}}, t}:
      encb.go(t, w.text("false", o))
    case Con{IVal{Num{n}}, t}:
      encb.go(t, w.bytes(n, o))
    case Con{IVal{Str{s}}, t}:
      encb.go(t, w.str(s, o))
    case Con{IVal{Arr{xs}}, t}:
      encb.go(Con{ILit{"["}, items.arr(xs, True{}, t)}, o)
    case Con{IVal{Obj{kvs}}, t}:
      encb.go(Con{ILit{"{"}, items.obj(kvs, True{}, t)}, o)

# Compact JSON in UTF-8, with object fields in their order.
def encode.bytes(v: Val) -> Bytes.Bytes:
  w.done(encb.go(Con{IVal{v}, Nil{}}, W{Bytes.alloc(64), 16, 0, 0}))
