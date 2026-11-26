# Pure RESP3 codec and incremental reader.
import Base
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
# A RESP3 value (RESP2 replies decode into the same type). Text fields hold the raw
# bytes of the line. Dict (a RESP3 map) and Attr keep their pairs flat, key then value, as
# on the wire and in hiredis. Attr holds the attribute pairs, then the reply they annotate, last.
# Int is a signed 64-bit integer as two's-complement words.
type Val is Type:
  Simple{text: Bytes.Bytes}
  Error{text: Bytes.Bytes}
  Int{hi: U32, lo: U32}
  Bulk{data: Bytes.Bytes}
  Arr{items: List<&1, Val>}
  Null{}
  Boolean{value: Bool}
  Double{text: Bytes.Bytes}
  BigNum{text: Bytes.Bytes}
  BulkError{text: Bytes.Bytes}
  Verbatim{format: Bytes.Bytes, text: Bytes.Bytes}
  Dict{items: List<&1, Val>}
  Set{items: List<&1, Val>}
  Attr{items: List<&1, Val>}
  Push{items: List<&1, Val>}

# Aggregate kinds, in the order of their type bytes below.
def kind.tag(+kind: U32) -> String:
  match kind:
    case 0:
      "*"
    case 1:
      "%"
    case 2:
      "~"
    case 3:
      "|"
    case _:
      ">"

def kind.val(+kind: U32, xs: List<&1, Val>) -> Val:
  match kind:
    case 0:
      Arr{xs}
    case 1:
      Dict{xs}
    case 2:
      Set{xs}
    case 3:
      Attr{xs}
    case _:
      Push{xs}

# ---- integers

def i64.neg(+hi: U32, +lo: U32) -> U32 & U32:
  (((hi .^. 4294967295) + Bool.pick(U32, U32.is_eq(lo, 0), 1, 0) : U32), ((lo .^. 4294967295) + 1 : U32))

# The 64-bit (hi, lo) divided by 10, and the remainder, over 16-bit limbs.
def u64.div10(+hi: U32, +lo: U32) -> U32 & U32 & U32:
  +a = (hi >> 16n : U32)
  +x = (((a % 10) << 16n) .|. (hi .&. 65535) : U32)
  +y = (((x % 10) << 16n) .|. (lo >> 16n) : U32)
  +z = (((y % 10) << 16n) .|. (lo .&. 65535) : U32)
  ((((a / 10) << 16n) .|. (x / 10) : U32), (((y / 10) << 16n) .|. (z / 10) : U32), (z % 10 : U32))

def digit.put(z: Bool, +r: U32, acc: String) -> String:
  match z:
    case True{}:
      acc
    case False{}:
      SCon{Chr{(48 + r : U32)}, acc}

# z is set once the value left to print is zero; 20 digits hold any u64.
def u64.show.go(f: Nat, q: U32 & U32 & U32, acc: String, +z: Bool) -> String:
  match f:
    case 0n:
      acc
    case 1n+p:
      # A + on a later tuple binder fails to check (https://github.com/bendlang/bend/issues/1077).
      (hi0, lo0, r) = q
      +hi = hi0
      +lo = lo0
      u64.show.go(p, u64.div10(hi, lo), digit.put(z, r, acc), Bool.or(z, U32.is_eq((hi .|. lo : U32), 0)))

def u64.show(+hi: U32, +lo: U32) -> String:
  u64.show.go(20n, u64.div10(hi, lo), SNil{}, False{})

def i64.show.of(r: U32 & U32, neg: Bool) -> String:
  (+hi, +lo) = r
  match neg:
    case True{}:
      "-" ++ u64.show(hi, lo)
    case False{}:
      u64.show(hi, lo)

def i64.show(+hi: U32, +lo: U32) -> String:
  +neg = U32.is_le(2147483648, hi)
  i64.show.of(Bool.pick(U32 & U32, neg, i64.neg(hi, lo), (hi, lo)), neg)

# ---- encoder

# The output so far, whether every value had a RESP form, and the count of values written.
type E is Type:
  E{o: Bytes.Bytes, ok: Bool, n: U32}

def fresh() -> E:
  E{Bytes.new(0), True{}, 0}

def text(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def none(m: Maybe<&2, U32>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{x}:
      False{}

def clean.lf(+cr: Bool, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Bool:
  (b, m) = r
  (b, Bool.and(cr, none(m)))

def clean.cr(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Bool:
  (b, m) = r
  clean.lf(none(m), Bytes.find(b, "\n"))

# A line has no CR and no LF.
def clean(t: Bytes.Bytes) -> Bytes.Bytes & Bool:
  clean.cr(Bytes.find(t, "\r"))

def put(st: E, +head: String, body: Bytes.Bytes, +good: Bool) -> E:
  E{o, +ok, +n} = st
  E{Bytes.append(Bytes.append(Bytes.append(o, text(head)), body), text("\r\n")), Bool.and(ok, good), (n + 1 : U32)}

def line(st: E, +tag: String, r: Bytes.Bytes & Bool) -> E:
  (t, +good) = r
  put(st, tag, t, good)

def blob(st: E, +tag: String, b: Bytes.Bytes) -> E:
  Bytes.Bytes{+len, buf} = b
  put(st, tag ++ U32.show(len) ++ "\r\n", Bytes.Bytes{len, buf}, True{})

def verbatim.of(st: E, +tl: U32, r: Bytes.Bytes & U32, t: Bytes.Bytes) -> E:
  (f, +fl) = r
  put(st, "=" ++ U32.show((tl + 4 : U32)) ++ "\r\n", Bytes.append(Bytes.append(f, text(":")), t), U32.is_eq(fl, 3))

def verbatim(st: E, f: Bytes.Bytes, t: Bytes.Bytes) -> E:
  Bytes.Bytes{+tl, tb} = t
  verbatim.of(st, tl, Bytes.length(f), Bytes.Bytes{tl, tb})

# Maps count pairs and need an even count; Attr needs its pairs and one reply.
def agg.count(+kind: U32, +n: U32) -> U32:
  Bool.pick(U32, U32.is_eq(kind, 1), (n >> 1n : U32), Bool.pick(U32, U32.is_eq(kind, 3), (n >> 1n : U32), n))

def agg.ok(+kind: U32, +n: U32) -> Bool:
  +odd = U32.is_eq((n .&. 1 : U32), 1)
  Bool.pick(Bool, U32.is_eq(kind, 1), Bool.not(odd), Bool.pick(Bool, U32.is_eq(kind, 3), odd, True{}))

def agg(st: E, +kind: U32, sub: E) -> E:
  E{o, +ok, +n} = st
  E{body, +good, +k} = sub
  +head = kind.tag(kind) ++ U32.show(agg.count(kind, k)) ++ "\r\n"
  E{Bytes.append(Bytes.append(o, text(head)), body), Bool.and(ok, Bool.and(good, agg.ok(kind, k))), (n + 1 : U32)}

def boolean(v: Bool) -> String:
  match v:
    case True{}:
      "t"
    case False{}:
      "f"

def enc(xs: List<&1, Val>, st: E) -> E:
  match xs:
    case Nil{}:
      st
    case Con{Simple{t}, rest}:
      enc(rest, line(st, "+", clean(t)))
    case Con{Error{t}, rest}:
      enc(rest, line(st, "-", clean(t)))
    case Con{Int{+hi, +lo}, rest}:
      enc(rest, put(st, ":" ++ i64.show(hi, lo), Bytes.new(0), True{}))
    case Con{Bulk{d}, rest}:
      enc(rest, blob(st, "$", d))
    case Con{Arr{items}, rest}:
      enc(rest, agg(st, 0, enc(items, fresh())))
    case Con{Null{}, rest}:
      enc(rest, put(st, "_", Bytes.new(0), True{}))
    case Con{Boolean{v}, rest}:
      enc(rest, put(st, "#" ++ boolean(v), Bytes.new(0), True{}))
    case Con{Double{t}, rest}:
      enc(rest, line(st, ",", clean(t)))
    case Con{BigNum{t}, rest}:
      enc(rest, line(st, "(", clean(t)))
    case Con{BulkError{t}, rest}:
      enc(rest, blob(st, "!", t))
    case Con{Verbatim{f, t}, rest}:
      enc(rest, verbatim(st, f, t))
    case Con{Dict{items}, rest}:
      enc(rest, agg(st, 1, enc(items, fresh())))
    case Con{Set{items}, rest}:
      enc(rest, agg(st, 2, enc(items, fresh())))
    case Con{Attr{items}, rest}:
      enc(rest, agg(st, 3, enc(items, fresh())))
    case Con{Push{items}, rest}:
      enc(rest, agg(st, 4, enc(items, fresh())))

def encode.done(st: E) -> Maybe<&1, Bytes.Bytes>:
  E{o, ok, n} = st
  match ok:
    case True{}:
      Some{o}
    case False{}:
      None{}

# None when a line value holds CR or LF, a Dict has an odd item count, an Attr an even
# one, or a Verbatim format is not 3 bytes.
def encode(v: Val) -> Maybe<&1, Bytes.Bytes>:
  encode.done(enc([v], fresh()))

def bulks(xs: List<&1, Bytes.Bytes>) -> List<&1, Val>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{Bulk{h}, bulks(t)}

def encode.command.done(st: E) -> Bytes.Bytes:
  E{o, ok, n} = st
  o

# A command as a RESP array of bulk strings, the form every server accepts.
def encode.command(args: List<&1, Bytes.Bytes>) -> Bytes.Bytes:
  encode.command.done(enc([Arr{bulks(args)}], fresh()))

# Byte-string arguments (one Char per octet) as Bytes.
def args(xs: List<&2, String>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{Bytes.from_string(h), args(t)}

# ---- decoder

# A decimal line: sign, magnitude words, and whether it has 1 to 19 digits.
type Num is Data:
  Num{neg: Bool, hi: U32, lo: U32, ok: Bool}

# n digits from i: (hi, lo) = (hi, lo) * 10 + d over 16-bit limbs. 19 digits stay below 2^64.
def num.go(n: Nat, r: Array<U32> & U32, +i: U32, +hi: U32, +lo: U32, +ok: Bool) -> Array<U32> & U32 & U32 & Bool:
  match n:
    case 0n:
      (a, c) = r
      (a, hi, lo, ok)
    case 1n+p:
      (a, +c) = r
      +d = (c - 48 : U32)
      +p0 = ((lo .&. 65535) * 10 + d : U32)
      +p1 = ((lo >> 16n) * 10 + (p0 >> 16n) : U32)
      num.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), (hi * 10 + (p1 >> 16n) : U32), ((p1 << 16n) .|. (p0 .&. 65535) : U32), Bool.and(ok, U32.is_lt(d, 10)))

def num.fin(+neg: Bool, +len: U32, r: Array<U32> & U32 & U32 & Bool) -> Bytes.Bytes & Num:
  (a, hi, lo, ok) = r
  (Bytes.Bytes{len, a}, Num{neg, hi, lo, ok})

def num.digits(+neg: Bool, a: Array<U32>, +len: U32, +s: U32, +e: U32) -> Bytes.Bytes & Num:
  +k = (e - s : U32)
  num.fin(neg, len, num.go(U32.to_nat(k), Bytes.peek(a, s), s, 0, 0, Bool.and(U32.is_lt(0, k), U32.is_le(k, 19))))

def num.sign(+len: U32, +s: U32, +e: U32, r: Array<U32> & U32) -> Bytes.Bytes & Num:
  (a, +c) = r
  +neg = Bool.and(U32.is_eq(c, 45), U32.is_lt(s, e))
  num.digits(neg, a, len, Bool.pick(U32, neg, (s + 1 : U32), s), e)

# Bytes s until e, which are before len.
def num(b: Bytes.Bytes, +s: U32, +e: U32) -> Bytes.Bytes & Num:
  Bytes.Bytes{+len, buf} = b
  num.sign(len, s, e, Bytes.peek(buf, s))

def int.mk(r: U32 & U32) -> Val:
  (hi, lo) = r
  Int{hi, lo}

def int.val(good: Bool, +neg: Bool, +hi: U32, +lo: U32) -> Maybe<&1, Val>:
  match good:
    case True{}:
      Some{int.mk(Bool.pick(U32 & U32, neg, i64.neg(hi, lo), (hi, lo)))}
    case False{}:
      None{}

# RESP integers are signed 64-bit: the magnitude may reach 2^63 only when negative.
def int.of(n: Num) -> Maybe<&1, Val>:
  Num{+neg, +hi, +lo, ok} = n
  +fits = Bool.or(U32.is_lt(hi, 2147483648), Bool.and(neg, Bool.and(U32.is_eq(hi, 2147483648), U32.is_eq(lo, 0))))
  int.val(Bool.and(ok, fits), neg, hi, lo)

# A length or count below 2^31; -1 (RESP2 null) is 4294967295 and anything else is 4294967294.
def len.of(n: Num) -> U32:
  Num{+neg, +hi, +lo, +ok} = n
  +nil = Bool.and(ok, Bool.and(neg, Bool.and(U32.is_eq(hi, 0), U32.is_eq(lo, 1))))
  +good = Bool.and(ok, Bool.and(Bool.not(neg), Bool.and(U32.is_eq(hi, 0), U32.is_lt(lo, 2147483648))))
  Bool.pick(U32, good, lo, Bool.pick(U32, nil, 4294967295, 4294967294))

# An open aggregate: its kind, the items still due, and the items so far, reversed.
type Frame is Type:
  Frame{kind: U32, left: U32, xs: List<&1, Val>}

type St is Type:
  SHead{i: U32, stack: List<&1, Frame>}
  SLine{t: U32, i: U32, scan: U32, stack: List<&1, Frame>}
  SBlob{kind: U32, n: U32, next: U32, stack: List<&1, Frame>}
  SWait{state: St}
  SDone{v: Val, i: U32, stack: List<&1, Frame>}
  SOk{v: Val, i: U32}
  SMore{}
  SBad{}

# One reply and the index after it; More when the bytes end first; Bad when they cannot start a reply.
type Step is Type:
  Reply{v: Val, next: U32}
  More{}
  Bad{}

def byte.of(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & U32:
  (b, m) = r
  match m:
    case Some{c}:
      (b, c)
    case None{}:
      (b, 256)

# Byte i, or 256 past the end.
def byte(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & U32:
  byte.of(Bytes.get(b, i))

def known(+t: U32) -> Bool:
  match t:
    case 43:
      True{}
    case 45:
      True{}
    case 58:
      True{}
    case 36:
      True{}
    case 42:
      True{}
    case 95:
      True{}
    case 35:
      True{}
    case 44:
      True{}
    case 40:
      True{}
    case 33:
      True{}
    case 61:
      True{}
    case 37:
      True{}
    case 126:
      True{}
    case 124:
      True{}
    case 62:
      True{}
    case _:
      False{}

def null.st(ok: Bool, +next: U32, stack: List<&1, Frame>) -> St:
  match ok:
    case True{}:
      SDone{Null{}, next, stack}
    case False{}:
      SBad{}

def line.val(+k: U32, t: Bytes.Bytes) -> Val:
  match k:
    case 0:
      Simple{t}
    case 1:
      Error{t}
    case 2:
      Double{t}
    case _:
      BigNum{t}

def line.st(+k: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & St:
  (b, t) = r
  (b, SDone{line.val(k, t), next, stack})

def int.done(m: Maybe<&1, Val>, +next: U32, stack: List<&1, Frame>) -> St:
  match m:
    case Some{v}:
      SDone{v, next, stack}
    case None{}:
      SBad{}

def int.st(+next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Num) -> Bytes.Bytes & St:
  (b, n) = r
  (b, int.done(int.of(n), next, stack))

def boolean.done(ok: Bool, +v: Bool, +next: U32, stack: List<&1, Frame>) -> St:
  match ok:
    case True{}:
      SDone{Boolean{v}, next, stack}
    case False{}:
      SBad{}

def boolean.st(+next: U32, stack: List<&1, Frame>, +one: Bool, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  (b, +c) = r
  (b, boolean.done(Bool.and(one, Bool.or(U32.is_eq(c, 116), U32.is_eq(c, 102))), U32.is_eq(c, 116), next, stack))

def blob.mk(+kind: U32, d: Bytes.Bytes) -> Val:
  match kind:
    case 0:
      Bulk{d}
    case _:
      BulkError{d}

def blob.done(+kind: U32, +after: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & St:
  (b, d) = r
  (b, SDone{blob.mk(kind, d), after, stack})

def verb.text(f: Bytes.Bytes, +after: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & St:
  (b, t) = r
  (b, SDone{Verbatim{f, t}, after, stack})

def verb.fmt(+n: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & St:
  (b, f) = r
  verb.text(f, (next + n + 2 : U32), stack, Bytes.slice(b, (next + 4 : U32), (n - 4 : U32)))

def verb.ok(ok: Bool, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  match ok:
    case True{}:
      verb.fmt(n, next, stack, Bytes.slice(b, next, 3))
    case False{}:
      (b, SBad{})

def verb.colon(+n: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  (b, +c) = r
  verb.ok(U32.is_eq(c, 58), n, next, stack, b)

# A verbatim string is a 3-byte format, a colon, then the text.
def verb.len(ok: Bool, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  match ok:
    case True{}:
      verb.colon(n, next, stack, byte(b, (next + 3 : U32)))
    case False{}:
      (b, SBad{})

def blob.val(+kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  match kind:
    case 2:
      verb.len(U32.is_le(4, n), n, next, stack, b)
    case _:
      blob.done(kind, (next + n + 2 : U32), stack, Bytes.slice(b, next, n))

def blob.crlf(+kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bool) -> Bytes.Bytes & St:
  (b, ok) = r
  match ok:
    case True{}:
      blob.val(kind, n, next, stack, b)
    case False{}:
      (b, SBad{})

def crlf.at(b: Bytes.Bytes, +j: U32) -> Bytes.Bytes & Bool:
  Bytes.Bytes{+len, buf} = b
  Bytes.at.fin(len, Bytes.at(buf, "\r\n", j))

def blob.fit(ok: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  match ok:
    case True{}:
      blob.crlf(kind, n, next, stack, crlf.at(b, (next + n : U32)))
    case False{}:
      (b, SWait{SBlob{kind, n, next, stack}})

def blob.room(+kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  (b, +len) = r
  blob.fit(Bytes.fits(len, next, (n + 2 : U32)), kind, n, next, stack, b)

def blob.bad(bad: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  match bad:
    case True{}:
      (b, SBad{})
    case False{}:
      blob.room(kind, n, next, stack, Bytes.length(b))

# $-1 is RESP2's null bulk string; ! and = have no null form.
def blob.nil(nil: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  match nil:
    case True{}:
      (b, null.st(U32.is_eq(kind, 0), next, stack))
    case False{}:
      blob.bad(U32.is_eq(n, 4294967294), kind, n, next, stack, b)

# kind 0 is $, 1 is !, 2 is =.
def blob.st(+kind: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Num) -> Bytes.Bytes & St:
  (b, n) = r
  +k = len.of(n)
  blob.nil(U32.is_eq(k, 4294967295), kind, k, next, stack, b)

def agg.open(empty: Bool, +kind: U32, +left: U32, +next: U32, stack: List<&1, Frame>) -> St:
  match empty:
    case True{}:
      SDone{kind.val(kind, Nil{}), next, stack}
    case False{}:
      SHead{next, Con{Frame{kind, left, Nil{}}, stack}}

# A map of n pairs has 2n items; an attribute adds the reply after its pairs.
def agg.left(+kind: U32, +n: U32) -> U32:
  Bool.pick(U32, U32.is_eq(kind, 1), (n * 2 : U32), Bool.pick(U32, U32.is_eq(kind, 3), (n * 2 + 1 : U32), n))

def agg.bad(bad: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>) -> St:
  match bad:
    case True{}:
      SBad{}
    case False{}:
      +left = agg.left(kind, n)
      agg.open(U32.is_eq(left, 0), kind, left, next, stack)

# *-1 is RESP2's null array.
def agg.nil(nil: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>) -> St:
  match nil:
    case True{}:
      null.st(U32.is_eq(kind, 0), next, stack)
    case False{}:
      agg.bad(U32.is_eq(n, 4294967294), kind, n, next, stack)

def agg.st(+kind: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Num) -> Bytes.Bytes & St:
  (b, n) = r
  +k = len.of(n)
  (b, agg.nil(U32.is_eq(k, 4294967295), kind, k, next, stack))

# The type byte t, then the line from s until the CRLF at e.
def item(+t: U32, +s: U32, +e: U32, b: Bytes.Bytes, stack: List<&1, Frame>) -> Bytes.Bytes & St:
  match t:
    case 43:
      line.st(0, (e + 2 : U32), stack, Bytes.slice(b, s, (e - s : U32)))
    case 45:
      line.st(1, (e + 2 : U32), stack, Bytes.slice(b, s, (e - s : U32)))
    case 44:
      line.st(2, (e + 2 : U32), stack, Bytes.slice(b, s, (e - s : U32)))
    case 40:
      line.st(3, (e + 2 : U32), stack, Bytes.slice(b, s, (e - s : U32)))
    case 58:
      int.st((e + 2 : U32), stack, num(b, s, e))
    case 95:
      (b, null.st(U32.is_eq(s, e), (e + 2 : U32), stack))
    case 35:
      boolean.st((e + 2 : U32), stack, U32.is_eq(e, (s + 1 : U32)), byte(b, s))
    case 36:
      blob.st(0, (e + 2 : U32), stack, num(b, s, e))
    case 33:
      blob.st(1, (e + 2 : U32), stack, num(b, s, e))
    case 61:
      blob.st(2, (e + 2 : U32), stack, num(b, s, e))
    case 42:
      agg.st(0, (e + 2 : U32), stack, num(b, s, e))
    case 37:
      agg.st(1, (e + 2 : U32), stack, num(b, s, e))
    case 126:
      agg.st(2, (e + 2 : U32), stack, num(b, s, e))
    case 124:
      agg.st(3, (e + 2 : U32), stack, num(b, s, e))
    case _:
      agg.st(4, (e + 2 : U32), stack, num(b, s, e))

def head.wait(+t: U32, +i: U32, stack: List<&1, Frame>, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  (b, +len) = r
  (b, SWait{SLine{t, i, U32.max((i + 1 : U32), (len - 1 : U32)), stack}})

def head.eol(+t: U32, +i: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & St:
  (b, m) = r
  match m:
    case Some{+e}:
      item(t, (i + 1 : U32), e, b, stack)
    case None{}:
      head.wait(t, i, stack, Bytes.length(b))

def head.end(end: Bool) -> St:
  match end:
    case True{}:
      SMore{}
    case False{}:
      SBad{}

def head.missing(end: Bool, +i: U32, stack: List<&1, Frame>) -> St:
  match end:
    case True{}:
      SWait{SHead{i, stack}}
    case False{}:
      SBad{}

def head.known(ok: Bool, +t: U32, +i: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  match ok:
    case True{}:
      head.eol(t, i, stack, Bytes.find.from(b, "\r\n", (i + 1 : U32)))
    case False{}:
      (b, head.missing(U32.is_eq(t, 256), i, stack))

def head(+i: U32, stack: List<&1, Frame>, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  (b, +t) = r
  head.known(known(t), t, i, stack, b)

def done.last(last: Bool, +kind: U32, +left: U32, xs: List<&1, Val>, +i: U32, rest: List<&1, Frame>) -> St:
  match last:
    case True{}:
      SDone{kind.val(kind, List.reverse(&1, Val, xs)), i, rest}
    case False{}:
      SHead{i, Con{Frame{kind, (left - 1 : U32), xs}, rest}}

def done(stack: List<&1, Frame>, v: Val, +i: U32) -> St:
  match stack:
    case Nil{}:
      SOk{v, i}
    case Con{fr, rest}:
      Frame{+kind, +left, xs} = fr
      done.last(U32.is_eq(left, 1), kind, left, Con{v, xs}, i, rest)

def run.state(fuel: Nat, r: Bytes.Bytes & St) -> Bytes.Bytes & St:
  match fuel:
    case 0n:
      (b, st) = r
      (b, SBad{})
    case 1n+f:
      (b, st) = r
      match st:
        case SOk{v, i}:
          (b, SOk{v, i})
        case SMore{}:
          (b, SMore{})
        case SBad{}:
          (b, SBad{})
        case SWait{state}:
          (b, state)
        case SHead{+i, stack}:
          run.state(f, head(i, stack, byte(b, i)))
        case SLine{+t, +i, +scan, stack}:
          run.state(f, head.eol(t, i, stack, Bytes.find.from(b, "\r\n", scan)))
        case SBlob{+kind, +n, +next, stack}:
          run.state(f, blob.room(kind, n, next, stack, Bytes.length(b)))
        case SDone{v, +i, stack}:
          run.state(f, (b, done(stack, v, i)))

def run.step(r: Bytes.Bytes & St) -> Bytes.Bytes & Step:
  (b, st) = r
  match st:
    case SOk{v, i}:
      (b, Reply{v, i})
    case SBad{}:
      (b, Bad{})
    case _:
      (b, More{})

def run(fuel: Nat, r: Bytes.Bytes & St) -> Bytes.Bytes & Step:
  run.step(run.state(fuel, r))

# One reply starting at byte i of b. Every item takes at least 3 bytes and each step
# reads an item or closes one, so 2 * (len - i) + 2 steps are enough.
def decode(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & Step:
  Bytes.Bytes{+len, buf} = b
  run(Nat.add(Nat.mul(U32.to_nat((len - i : U32)), 2n), 2n), (Bytes.Bytes{len, buf}, SHead{i, Nil{}}))

# ---- incremental reader

# The reply start stays pending while its phase and aggregate stack advance.
type Reader is Type:
  Reader{buf: Bytes.Bytes, pos: U32, state: St}

def reader() -> Reader:
  Reader{Bytes.new(0), 0, SHead{0, Nil{}}}

def state.shift(st: St, +pos: U32) -> St:
  match st:
    case SHead{+i, stack}:
      SHead{(i - pos : U32), stack}
    case SLine{t, +i, +scan, stack}:
      SLine{t, (i - pos : U32), (scan - pos : U32), stack}
    case SBlob{kind, n, +next, stack}:
      SBlob{kind, n, (next - pos : U32), stack}
    case _:
      SBad{}

def feed.at(zero: Bool, buf: Bytes.Bytes, +pos: U32, state: St, chunk: Bytes.Bytes) -> Reader:
  match zero:
    case True{}:
      Reader{Bytes.append(buf, chunk), 0, state}
    case False{}:
      Reader{Bytes.append(Bytes.snd(Bytes.slice(buf, pos, 4294967295)), chunk), 0, state.shift(state, pos)}

# Drops completed replies, then adds chunk without revisiting completed items.
def feed(r: Reader, chunk: Bytes.Bytes) -> Reader:
  Reader{buf, +pos, state} = r
  feed.at(U32.is_zero(pos), buf, pos, state, chunk)

type Next is Type:
  Got{v: Val}
  Want{}
  Broken{}

def next.of(+pos: U32, r: Bytes.Bytes & St) -> Reader & Next:
  (b, s) = r
  match s:
    case SOk{v, +i}:
      (Reader{b, i, SHead{i, Nil{}}}, Got{v})
    case SBad{}:
      (Reader{b, pos, SBad{}}, Broken{})
    case SHead{i, stack}:
      (Reader{b, pos, SHead{i, stack}}, Want{})
    case SLine{t, i, scan, stack}:
      (Reader{b, pos, SLine{t, i, scan, stack}}, Want{})
    case SBlob{kind, n, next, stack}:
      (Reader{b, pos, SBlob{kind, n, next, stack}}, Want{})
    case _:
      (Reader{b, pos, SBad{}}, Broken{})

# The next whole reply, Want when it has not all arrived, or Broken for bytes that are not RESP.
def next(r: Reader) -> Reader & Next:
  Reader{buf, +pos, state} = r
  Bytes.Bytes{+len, words} = buf
  next.of(pos, run.state(Nat.add(Nat.mul(U32.to_nat(len), 2n), 4n), (Bytes.Bytes{len, words}, state)))

def pending.of(+pos: U32, state: St, r: Bytes.Bytes & U32) -> Reader & U32:
  (b, +len) = r
  (Reader{b, pos, state}, (len - pos : U32))

# The count of bytes in replies that are not yet complete.
def pending(r: Reader) -> Reader & U32:
  Reader{buf, +pos, state} = r
  pending.of(pos, state, Bytes.length(buf))
