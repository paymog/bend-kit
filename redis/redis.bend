# Redis and Valkey client: RESP3 over TCP or TLS, with pipelining and a pool. Source: https://github.com/paymog/bend-kit/tree/main/redis
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import bend-kit-wire@0.4.2.0/wire.bend as Wire
# bend-kit-dns@0.4.0.1
import 0x296c14c91cb121bd2f42e9d9f730480d/dns.bend as Dns

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
      (b, SMore{})

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

def head.eol(+t: U32, +i: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & St:
  (b, m) = r
  match m:
    case Some{+e}:
      item(t, (i + 1 : U32), e, b, stack)
    case None{}:
      (b, SMore{})

def head.end(end: Bool) -> St:
  match end:
    case True{}:
      SMore{}
    case False{}:
      SBad{}

def head.known(ok: Bool, +t: U32, +i: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  match ok:
    case True{}:
      head.eol(t, i, stack, Bytes.find.from(b, "\r\n", (i + 1 : U32)))
    case False{}:
      (b, head.end(U32.is_eq(t, 256)))

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

def run(fuel: Nat, r: Bytes.Bytes & St) -> Bytes.Bytes & Step:
  match fuel:
    case 0n:
      (b, st) = r
      (b, Bad{})
    case 1n+f:
      (b, st) = r
      match st:
        case SOk{v, +i}:
          (b, Reply{v, i})
        case SMore{}:
          (b, More{})
        case SBad{}:
          (b, Bad{})
        case SHead{+i, stack}:
          run(f, head(i, stack, byte(b, i)))
        case SDone{v, +i, stack}:
          run(f, (b, done(stack, v, i)))

# One reply starting at byte i of b. Every item takes at least 3 bytes and each step
# reads an item or closes one, so 2 * (len - i) + 2 steps are enough.
def decode(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & Step:
  Bytes.Bytes{+len, buf} = b
  run(Nat.add(Nat.mul(U32.to_nat((len - i : U32)), 2n), 2n), (Bytes.Bytes{len, buf}, SHead{i, Nil{}}))

# ---- incremental reader

# Bytes read from the server, and the index of the first byte not yet decoded.
type Reader is Type:
  Reader{buf: Bytes.Bytes, pos: U32}

def reader() -> Reader:
  Reader{Bytes.new(0), 0}

def feed.at(zero: Bool, buf: Bytes.Bytes, +pos: U32, chunk: Bytes.Bytes) -> Reader:
  match zero:
    case True{}:
      Reader{Bytes.append(buf, chunk), 0}
    case False{}:
      Reader{Bytes.append(Bytes.snd(Bytes.slice(buf, pos, 4294967295)), chunk), 0}

# Drops the decoded bytes, then adds chunk.
# ponytail: a reply split over k reads is decoded from its start k times; keep state per item if huge arrays arrive slowly.
def feed(r: Reader, chunk: Bytes.Bytes) -> Reader:
  Reader{buf, +pos} = r
  feed.at(U32.is_zero(pos), buf, pos, chunk)

type Next is Type:
  Got{v: Val}
  Want{}
  Broken{}

def next.of(+pos: U32, r: Bytes.Bytes & Step) -> Reader & Next:
  (b, s) = r
  match s:
    case Reply{v, +i}:
      (Reader{b, i}, Got{v})
    case More{}:
      (Reader{b, pos}, Want{})
    case Bad{}:
      (Reader{b, pos}, Broken{})

# The next whole reply, Want when it has not all arrived, or Broken for bytes that are not RESP.
def next(r: Reader) -> Reader & Next:
  Reader{buf, +pos} = r
  next.of(pos, decode(buf, pos))

def pending.of(+pos: U32, r: Bytes.Bytes & U32) -> Reader & U32:
  (b, +len) = r
  (Reader{b, pos}, (len - pos : U32))

# The count of bytes read but not yet decoded.
def pending(r: Reader) -> Reader & U32:
  Reader{buf, +pos} = r
  pending.of(pos, Bytes.length(buf))

# ---- connections

# host is a name or a numeric address; TLS checks the certificate against it. Empty user
# and pass send no AUTH (a pass alone authenticates as "default"); db 0 sends no SELECT.
# ms bounds each connect and read (0: none).
type Config is Data:
  Config{host: String, port: U32, tls: Bool, user: String, pass: String, db: U32, ms: U32}

def config(+host: String, +port: U32) -> Config:
  Config{host, port, False{}, "", "", 0, 10000}

# A failed call closes its connection. Rejected carries the server's error reply to the handshake.
type Failure is Type:
  IoFail{code: U32, why: String}
  Closed{}
  Malformed{}
  Rejected{reply: Val}

# key names the pool bucket: TLS, user, host, port, and db.
type Conn is Type:
  Conn{tls: Bool, sock: Socket, rd: Reader, key: String, ms: U32}

def io.close(tls: Bool, s: Socket) -> IO(Unit):
  match tls:
    case True{}:
      Wire.tls.close(s)
    case False{}:
      Socket.close(s)

def io.send(tls: Bool, s: Socket, +len: U32, buf: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send.words(s, len, buf)
    case False{}:
      Wire.send.words(s, len, buf)

def io.recv(tls: Bool, s: Socket, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match tls:
    case True{}:
      Wire.tls.recv.words(s, 65536, ms)
    case False{}:
      Wire.recv.words(s, 65536, ms)

def close(c: Conn) -> IO(Unit):
  Conn{tls, sock, rd, key, ms} = c
  io.close(tls, sock)

def send.after(+tls: Bool, rd: Reader, +key: String, +ms: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Failure, Conn>):
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      do IO<Result<&1, &1, Failure, Conn>>:
        io.close(tls, s)
        return Fail{IoFail{code, why}}
    case Done{u}:
      IO.pure(Result<&1, &1, Failure, Conn>, Done{Conn{tls, s, rd, key, ms}})

def send(c: Conn, data: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn>):
  Conn{+tls, sock, rd, +key, +ms} = c
  Bytes.Bytes{+len, buf} = data
  do IO<Result<&1, &1, Failure, Conn>>:
    m : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(tls, sock, len, buf)
    send.after(tls, rd, key, ms, m)

# RNext holds the reader after its last decode attempt; RFail a socket to close.
type Rd is Type:
  RNext{tls: Bool, sock: Socket, key: String, ms: U32, r: Reader & Next}
  RFail{tls: Bool, sock: Socket, why: Failure}

def got.len(zero: Bool, +tls: Bool, +key: String, +ms: U32, rd: Reader, s: Socket, +len: U32, words: Array<U32>) -> Rd:
  match zero:
    case True{}:
      RFail{tls, s, Closed{}}
    case False{}:
      RNext{tls, s, key, ms, next(feed(rd, Bytes.Bytes{len, words}))}

def got(+tls: Bool, +key: String, +ms: U32, rd: Reader, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Rd:
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      RFail{tls, s, IoFail{code, why}}
    case Done{(+len, words)}:
      got.len(U32.is_zero(len), tls, key, ms, rd, s, len, words)

def read.fail(tls: Bool, sock: Socket, why: Failure) -> IO(Result<&1, &1, Failure, Conn & Val>):
  do IO<Result<&1, &1, Failure, Conn & Val>>:
    io.close(tls, sock)
    return Fail{why}

# One recv per step. 2^24 reads of up to 64 KiB pass Redis's 512 MiB bulk limit.
def read.loop(fuel: Nat, st: Rd) -> IO(Result<&1, &1, Failure, Conn & Val>):
  match fuel:
    case 0n:
      match st:
        case RNext{tls, sock, key, ms, r}:
          read.fail(tls, sock, Malformed{})
        case RFail{tls, sock, why}:
          read.fail(tls, sock, why)
    case 1n+f:
      match st:
        case RFail{tls, sock, why}:
          read.fail(tls, sock, why)
        case RNext{+tls, sock, +key, +ms, r}:
          (rd, nx) = r
          match nx:
            case Got{v}:
              IO.pure(Result<&1, &1, Failure, Conn & Val>, Done{(Conn{tls, sock, rd, key, ms}, v)})
            case Broken{}:
              read.fail(tls, sock, Malformed{})
            case Want{}:
              do IO<Result<&1, &1, Failure, Conn & Val>>:
                m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv(tls, sock, ms)
                read.loop(f, got(tls, key, ms, rd, m))

# The next reply. Bytes already read are decoded before the socket is asked for more.
def read(c: Conn) -> IO(Result<&1, &1, Failure, Conn & Val>):
  Conn{tls, sock, rd, key, ms} = c
  read.loop(Nat.mul(65536n, 256n), RNext{tls, sock, key, ms, next(rd)})

def read.push(xs: List<&1, Val>, r: Result<&1, &1, Failure, Conn & Val>) -> Result<&1, &1, Failure, Conn & List<&1, Val>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(c, v)}:
      Done{(c, Con{v, xs})}

# n more replies onto the reversed list in st.
def read.n(n: Nat, st: Result<&1, &1, Failure, Conn & List<&1, Val>>) -> IO(Result<&1, &1, Failure, Conn & List<&1, Val>>):
  match n:
    case 0n:
      match st:
        case Fail{e}:
          IO.pure(Result<&1, &1, Failure, Conn & List<&1, Val>>, Fail{e})
        case Done{(c, xs)}:
          IO.pure(Result<&1, &1, Failure, Conn & List<&1, Val>>, Done{(c, List.reverse(&1, Val, xs))})
    case 1n+p:
      match st:
        case Fail{e}:
          IO.pure(Result<&1, &1, Failure, Conn & List<&1, Val>>, Fail{e})
        case Done{(c, xs)}:
          do IO<Result<&1, &1, Failure, Conn & List<&1, Val>>>:
            r : Result<&1, &1, Failure, Conn & Val> <- read(c)
            read.n(p, read.push(xs, r))

def commands(cmds: List<&1, List<&1, Bytes.Bytes>>, o: Bytes.Bytes, +n: Nat) -> Bytes.Bytes & Nat:
  match cmds:
    case Nil{}:
      (o, n)
    case Con{h, t}:
      commands(t, Bytes.append(o, encode.command(h)), (1n + n : Nat))

def pipeline.sent(+n: Nat, r: Result<&1, &1, Failure, Conn>) -> IO(Result<&1, &1, Failure, Conn & List<&1, Val>>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn & List<&1, Val>>, Fail{e})
    case Done{c}:
      read.n(n, Done{(c, Nil{})})

def pipeline.of(c: Conn, r: Bytes.Bytes & Nat) -> IO(Result<&1, &1, Failure, Conn & List<&1, Val>>):
  (data, +n) = r
  do IO<Result<&1, &1, Failure, Conn & List<&1, Val>>>:
    s : Result<&1, &1, Failure, Conn> <- send(c, data)
    pipeline.sent(n, s)

# Sends every command in one write, then reads one reply per command, in order.
# Error replies come back as Error or BulkError values, not as failures.
def pipeline(c: Conn, cmds: List<&1, List<&1, Bytes.Bytes>>) -> IO(Result<&1, &1, Failure, Conn & List<&1, Val>>):
  pipeline.of(c, commands(cmds, Bytes.new(0), 0n))

def command.sent(r: Result<&1, &1, Failure, Conn>) -> IO(Result<&1, &1, Failure, Conn & Val>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn & Val>, Fail{e})
    case Done{c}:
      read(c)

# One command and its reply, for example command(c, args(["SET", "k", "v"])).
def command(c: Conn, argv: List<&1, Bytes.Bytes>) -> IO(Result<&1, &1, Failure, Conn & Val>):
  do IO<Result<&1, &1, Failure, Conn & Val>>:
    r : Result<&1, &1, Failure, Conn> <- send(c, encode.command(argv))
    command.sent(r)

def get(c: Conn, key: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn & Val>):
  command(c, [text("GET"), key])

def set(c: Conn, key: Bytes.Bytes, value: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn & Val>):
  command(c, [text("SET"), key, value])

def incr(c: Conn, key: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn & Val>):
  command(c, [text("INCR"), key])

def first.err(xs: List<&1, Val>) -> Maybe<&1, Val>:
  match xs:
    case Nil{}:
      None{}
    case Con{Error{t}, rest}:
      Some{Error{t}}
    case Con{BulkError{t}, rest}:
      Some{BulkError{t}}
    case Con{v, rest}:
      first.err(rest)

def hello.check(c: Conn, e: Maybe<&1, Val>) -> IO(Result<&1, &1, Failure, Conn>):
  match e:
    case None{}:
      IO.pure(Result<&1, &1, Failure, Conn>, Done{c})
    case Some{v}:
      do IO<Result<&1, &1, Failure, Conn>>:
        close(c)
        return Fail{Rejected{v}}

def hello.got(r: Result<&1, &1, Failure, Conn & List<&1, Val>>) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{e})
    case Done{(c, xs)}:
      hello.check(c, first.err(xs))

def hello.auth(+user: String, +pass: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.eq(pass, ""), Nil{}, ["AUTH", Bool.pick(String, String.eq(user, ""), "default", user), pass])

def hello.select(+db: U32) -> List<&1, List<&1, Bytes.Bytes>>:
  Bool.pick(List<&1, List<&1, Bytes.Bytes>>, U32.is_zero(db), Nil{}, [args(["SELECT", U32.show(db)])])

# HELLO 3 (with AUTH), then SELECT, in one pipeline.
def hello(c: Conn, +user: String, +pass: String, +db: U32) -> IO(Result<&1, &1, Failure, Conn>):
  do IO<Result<&1, &1, Failure, Conn>>:
    r : Result<&1, &1, Failure, Conn & List<&1, Val>> <- pipeline(c, Con{args(List.append(&2, String, ["HELLO", "3"], hello.auth(user, pass))), hello.select(db)})
    hello.got(r)

def key(cfg: Config) -> String:
  Config{+host, +port, +tls, +user, pass, +db, ms} = cfg
  Bool.pick(String, tls, "rediss://", "redis://") ++ user ++ "@" ++ host ++ ":" ++ U32.show(port) ++ "/" ++ U32.show(db)

def tls.done(+key: String, +ms: U32, +user: String, +pass: String, +db: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Failure, Conn>):
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      do IO<Result<&1, &1, Failure, Conn>>:
        Wire.tls.close(s)
        return Fail{IoFail{code, why}}
    case Done{u}:
      hello(Conn{True{}, s, reader(), key, ms}, user, pass, db)

def dialed(r: Result<&1, &1, U32 & String, Socket>, tls: Bool, +k: String, +host: String, +user: String, +pass: String, +db: U32, +ms: U32) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{(code, why)}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{IoFail{code, why}})
    case Done{s}:
      match tls:
        case True{}:
          do IO<Result<&1, &1, Failure, Conn>>:
            m : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, host, ms)
            tls.done(k, ms, user, pass, db, m)
        case False{}:
          hello(Conn{False{}, s, reader(), k, ms}, user, pass, db)

def dial.after(r: Result<&1, &1, U32 & String, Socket>, +ip: String, +port: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Socket>):
  match r:
    case Done{s}:
      IO.pure(Result<&1, &1, U32 & String, Socket>, Done{s})
    case Fail{e}:
      Wire.connect(ip, port, ms)

def dial.more(prev: IO(Result<&1, &1, U32 & String, Socket>), +ip: String, +port: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Socket>):
  do IO<Result<&1, &1, U32 & String, Socket>>:
    r : Result<&1, &1, U32 & String, Socket> <- prev
    dial.after(r, ip, port, ms)

# Each address in turn, until one connects.
def dial(ips: List<&2, String>, +port: U32, +ms: U32, acc: IO(Result<&1, &1, U32 & String, Socket>)) -> IO(Result<&1, &1, U32 & String, Socket>):
  match ips:
    case Nil{}:
      acc
    case Con{ip, t}:
      dial(t, port, ms, dial.more(acc, ip, port, ms))

def connect.to(+k: String, cfg: Config) -> IO(Result<&1, &1, Failure, Conn>):
  Config{+host, +port, +tls, +user, +pass, +db, +ms} = cfg
  do IO<Result<&1, &1, Failure, Conn>>:
    ips : List<&2, String> <- Dns.resolve.all(host)
    r : Result<&1, &1, U32 & String, Socket> <- dial(ips, port, ms, IO.pure(Result<&1, &1, U32 & String, Socket>, Fail{(0, "no address for " ++ host)}))
    dialed(r, tls, k, host, user, pass, db, ms)

# TCP (and TLS, which checks the certificate and host name), then the handshake.
def connect(+cfg: Config) -> IO(Result<&1, &1, Failure, Conn>):
  connect.to(key(cfg), cfg)

# ---- pool

# Idle connections per key, up to cap per key.
type Pool is Type:
  Pool{cap: U32, idle: Map<&1, List<&1, Conn>>}

def pool.new.with(+cap: U32) -> Pool:
  Pool{cap, Map.new(&1, List<&1, Conn>)}

def pool.new() -> Pool:
  pool.new.with(8)

def pool.take(+cap: U32, +k: String, r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> Pool & Maybe<&1, Conn>:
  (m, got) = r
  match got:
    case None{}:
      (Pool{cap, m}, None{})
    case Some{xs}:
      match xs:
        case Nil{}:
          (Pool{cap, m}, None{})
        case Con{c, t}:
          (Pool{cap, Map.set(&1, List<&1, Conn>, m, k, t)}, Some{c})

def pool.opened(p: Pool, r: Result<&1, &1, Failure, Conn>) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  IO.pure(Pool & Result<&1, &1, Failure, Conn>, (p, r))

def pool.got(cfg: Config, r: Pool & Maybe<&1, Conn>) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  (p, m) = r
  match m:
    case Some{c}:
      IO.pure(Pool & Result<&1, &1, Failure, Conn>, (p, Done{c}))
    case None{}:
      do IO<Pool & Result<&1, &1, Failure, Conn>>:
        c : Result<&1, &1, Failure, Conn> <- connect(cfg)
        pool.opened(p, c)

# The idle connection given back last, or a new one.
# ponytail: an idle connection the server has since closed fails on its first command; add a PING check if that bites.
def pool.get(p: Pool, +cfg: Config) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  Pool{+cap, idle} = p
  +k = key(cfg)
  pool.got(cfg, pool.take(cap, k, Map.pop(&1, List<&1, Conn>, idle, k)))

# The first n connections; the rest are closed.
def conns.cut(xs: List<&1, Conn>, n: Nat) -> IO(List<&1, Conn>):
  match xs:
    case Nil{}:
      IO.pure(List<&1, Conn>, Nil{})
    case Con{c, t}:
      match n:
        case 0n:
          do IO<List<&1, Conn>>:
            close(c)
            conns.cut(t, 0n)
        case 1n+k:
          do IO<List<&1, Conn>>:
            r : List<&1, Conn> <- conns.cut(t, k)
            return c <> r

def pool.keep(+cap: U32, +k: String, c: Conn, r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> IO(Pool):
  (m, old) = r
  do IO<Pool>:
    xs : List<&1, Conn> <- conns.cut(c <> Maybe.default(&1, List<&1, Conn>, old, Nil{}), U32.to_nat(cap))
    return Pool{cap, Map.set(&1, List<&1, Conn>, m, k, xs)}

def pool.give(p: Pool, c: Conn) -> IO(Pool):
  Pool{+cap, idle} = p
  Conn{tls, sock, rd, +k, ms} = c
  pool.keep(cap, k, Conn{tls, sock, rd, k, ms}, Map.pop(&1, List<&1, Conn>, idle, k))

def pool.clean(clean: Bool, p: Pool, c: Conn) -> IO(Pool):
  match clean:
    case True{}:
      pool.give(p, c)
    case False{}:
      do IO<Pool>:
        close(c)
        return p

def pool.left(p: Pool, +tls: Bool, sock: Socket, +key: String, +ms: U32, r: Reader & U32) -> IO(Pool):
  (rd, +n) = r
  pool.clean(U32.is_zero(n), p, Conn{tls, sock, rd, key, ms})

# Gives c back for reuse. A connection with unread reply bytes is out of step, so it is closed.
def pool.put(p: Pool, c: Conn) -> IO(Pool):
  Conn{+tls, sock, rd, +key, +ms} = c
  pool.left(p, tls, sock, key, ms, pending(rd))

def pool.close.go(xs: List<&1, List<&1, Conn>>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{cs, t}:
      do IO<Unit>:
        none : List<&1, Conn> <- conns.cut(cs, 0n)
        pool.close.go(t)

def pool.close(p: Pool) -> IO(Unit):
  Pool{cap, idle} = p
  pool.close.go(Map.values(&1, List<&1, Conn>, idle))
