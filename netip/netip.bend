# IPv4 and IPv6 address values: strict parsing, RFC 5952 text, and CIDR prefixes. Source: https://github.com/paymog/bend-kit/tree/main/netip
import Base

# V4: the address as one big-endian word. V6: four network-order words, a first.
type Addr is Data:
  V4{word: U32}
  V6{a: U32, b: U32, c: U32, d: U32}

# A hex digit's value, or 16 when c is not one.
def hexval(+c: U32) -> U32:
  Bool.pick(U32, Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), (c - 48 : U32),
    Bool.pick(U32, Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), (c - 87 : U32),
      Bool.pick(U32, Bool.and(U32.is_le(65, c), U32.is_le(c, 70)), (c - 55 : U32), 16)))

def hex.step(+d: U32, acc: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match acc:
    case None{}:
      None{}
    case Some{v}:
      Bool.pick(Maybe<&2, U32>, U32.is_lt(d, 16), Some{(v * 16 + d : U32)}, None{})

def hex.go(s: String, acc: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      hex.go(t, hex.step(hexval(c), acc))

def hextet.ok(ok: Bool, s: String) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      hex.go(s, Some{0})
    case False{}:
      None{}

# One IPv6 group: 1 to 4 hex digits, either case.
def hextet(+s: String) -> Maybe<&2, U32>:
  hextet.ok(Bool.and(Bool.not(String.is_empty(s)), Nat.is_le(String.length(s), 4n)), s)

# A non-digit wraps past 9 in (c - 48), so it fails the digit test.
def dec.step(+d: U32, acc: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match acc:
    case None{}:
      None{}
    case Some{v}:
      Bool.pick(Maybe<&2, U32>, U32.is_lt(d, 10), Some{(v * 10 + d : U32)}, None{})

def dec.go(s: String, acc: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      dec.go(t, dec.step((c - 48 : U32), acc))

# 1 to 3 characters, and no leading zero unless the octet is "0".
def octet.lead(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, +t}:
      Bool.and(Nat.is_le(String.length(t), 2n), Bool.or(Bool.not(U32.is_eq(c, 48)), String.is_empty(t)))

def octet.max(m: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{+v}:
      Bool.pick(Maybe<&2, U32>, U32.is_le(v, 255), Some{v}, None{})

def octet.ok(ok: Bool, s: String) -> Maybe<&2, U32>:
  match ok:
    case True{}:
      octet.max(dec.go(s, Some{0}))
    case False{}:
      None{}

def octet(+s: String) -> Maybe<&2, U32>:
  octet.ok(octet.lead(s), s)

def v4.parts(ps: List<&2, String>) -> Maybe<&2, U32>:
  match ps:
    case Con{a, Con{b, Con{c, Con{d, Nil{}}}}}:
      do Maybe<&2, U32>:
        w : U32 <- octet(a)
        x : U32 <- octet(b)
        y : U32 <- octet(c)
        z : U32 <- octet(d)
        return (w * 16777216 + x * 65536 + y * 256 + z : U32)
    case _:
      None{}

# Dotted-decimal IPv4 as its big-endian word.
def v4.word(s: String) -> Maybe<&2, U32>:
  v4.parts(String.split(s, '.'))

def v4.wrap(m: Maybe<&2, U32>) -> Maybe<&2, Addr>:
  match m:
    case None{}:
      None{}
    case Some{w}:
      Some{V4{w}}

def v4(s: String) -> Maybe<&2, Addr>:
  v4.wrap(v4.word(s))

# Groups read so far, each list newest first. Gap: "::" was seen; post holds the groups after it.
type Walk is Data:
  NoGap{pre: List<&2, U32>}
  Gap{pre: List<&2, U32>, post: List<&2, U32>}

def walk.push(st: Walk, +g: U32) -> Walk:
  match st:
    case NoGap{pre}:
      NoGap{g <> pre}
    case Gap{pre, post}:
      Gap{pre, g <> post}

def v6.hex(w: Walk, m: Maybe<&2, U32>) -> Maybe<&2, Walk>:
  match m:
    case None{}:
      None{}
    case Some{g}:
      Some{walk.push(w, g)}

# An empty inner segment is the one "::".
def v6.gap(w: Walk) -> Maybe<&2, Walk>:
  match w:
    case NoGap{pre}:
      Some{Gap{pre, Nil{}}}
    case Gap{pre, post}:
      None{}

def v6.mid.seg(h: String, w: Walk) -> Maybe<&2, Walk>:
  match h:
    case SNil{}:
      v6.gap(w)
    case SCon{c, t}:
      v6.hex(w, hextet(SCon{c, t}))

def v6.mid(st: Maybe<&2, Walk>, h: String) -> Maybe<&2, Walk>:
  match st:
    case None{}:
      None{}
    case Some{w}:
      v6.mid.seg(h, w)

# An empty last segment is the second colon of a trailing "::".
def v6.trail(w: Walk) -> Maybe<&2, Walk>:
  match w:
    case Gap{pre, Nil{}}:
      Some{Gap{pre, Nil{}}}
    case _:
      None{}

# Embedded dotted IPv4 fills the last two groups.
def v6.dot(w: Walk, m: Maybe<&2, U32>) -> Maybe<&2, Walk>:
  match m:
    case None{}:
      None{}
    case Some{+x}:
      Some{walk.push(walk.push(w, (x / 65536 : U32)), (x % 65536 : U32))}

def v6.last.kind(dot: Bool, w: Walk, s: String) -> Maybe<&2, Walk>:
  match dot:
    case True{}:
      v6.dot(w, v4.word(s))
    case False{}:
      v6.hex(w, hextet(s))

def v6.last.text(w: Walk, +s: String) -> Maybe<&2, Walk>:
  v6.last.kind(String.contains(s, "."), w, s)

def v6.last.seg(h: String, w: Walk) -> Maybe<&2, Walk>:
  match h:
    case SNil{}:
      v6.trail(w)
    case SCon{c, t}:
      v6.last.text(w, SCon{c, t})

def v6.last(st: Maybe<&2, Walk>, h: String) -> Maybe<&2, Walk>:
  match st:
    case None{}:
      None{}
    case Some{w}:
      v6.last.seg(h, w)

# h: the current segment; t: the segments after it.
def v6.go(t: List<&2, String>, h: String, st: Maybe<&2, Walk>) -> Maybe<&2, Walk>:
  match t:
    case Nil{}:
      v6.last(st, h)
    case Con{h2, t2}:
      v6.go(t2, h2, v6.mid(st, h))

def v6.words(gs: List<&2, U32>) -> Maybe<&2, Addr>:
  match gs:
    case Con{a, Con{b, Con{c, Con{d, Con{e, Con{f, Con{g, Con{h, Nil{}}}}}}}}}:
      Some{V6{(a * 65536 + b : U32), (c * 65536 + d : U32), (e * 65536 + f : U32), (g * 65536 + h : U32)}}
    case _:
      None{}

# "::" stands for at least one zero group.
def v6.pad(ok: Bool, pre: List<&2, U32>, post: List<&2, U32>, n: Nat) -> Maybe<&2, Addr>:
  match ok:
    case True{}:
      v6.words(List.append(&2, U32, List.reverse(&2, U32, pre), List.append(&2, U32, List.replicate(U32, Nat.sub(8n, n), 0), List.reverse(&2, U32, post))))
    case False{}:
      None{}

def v6.fill(w: Walk) -> Maybe<&2, Addr>:
  match w:
    case NoGap{pre}:
      v6.words(List.reverse(&2, U32, pre))
    case Gap{+pre, +post}:
      +n = (List.length(&2, U32, pre) + List.length(&2, U32, post) : Nat)
      v6.pad(Nat.is_le(n, 7n), pre, post, n)

def v6.fin(m: Maybe<&2, Walk>) -> Maybe<&2, Addr>:
  match m:
    case None{}:
      None{}
    case Some{w}:
      v6.fill(w)

# The ":"-split segments. Only a leading "::" may start with an empty segment.
def v6(ps: List<&2, String>) -> Maybe<&2, Addr>:
  match ps:
    case Con{SNil{}, Con{SNil{}, Con{h, t}}}:
      v6.fin(v6.go(t, h, Some{Gap{Nil{}, Nil{}}}))
    case Con{SNil{}, t}:
      None{}
    case Con{h, t}:
      v6.fin(v6.go(t, h, Some{NoGap{Nil{}}}))
    case Nil{}:
      None{}

def parse.fam(colon: Bool, s: String) -> Maybe<&2, Addr>:
  match colon:
    case True{}:
      v6(String.split(s, ':'))
    case False{}:
      v4(s)

# Strict address text: 4 dotted-decimal octets, or RFC 4291 IPv6 with at most one "::" and an optional
# trailing dotted IPv4. No brackets, zones, ports, or surrounding space.
def parse(+s: String) -> Maybe<&2, Addr>:
  parse.fam(String.contains(s, ":"), s)

# Hex fields contain no leading zeros.
def hex.char(+n: U32) -> String:
  SCon{Chr{Bool.pick(U32, U32.is_lt(n, 10), (n + 48 : U32), (n + 87 : U32))}, SNil{}}

def hex.two(+n: U32) -> String:
  hex.char((n >> 4n : U32)) ++ hex.char((n .&. 15 : U32))

def hex.three(+n: U32) -> String:
  hex.char((n >> 8n : U32)) ++ hex.two((n .&. 255 : U32))

def hex.four(+n: U32) -> String:
  hex.char((n >> 12n : U32)) ++ hex.three((n .&. 4095 : U32))

def hex.many(n: U32, small: Bool) -> String:
  match small:
    case True{}:
      hex.three(n)
    case False{}:
      hex.four(n)

def hex.more(+n: U32, small: Bool) -> String:
  match small:
    case True{}:
      hex.two(n)
    case False{}:
      hex.many(n, U32.is_lt(n, 4096))

def hex.group.small(+n: U32, small: Bool) -> String:
  match small:
    case True{}:
      hex.char(n)
    case False{}:
      hex.more(n, U32.is_lt(n, 256))

def hex.group(+n: U32) -> String:
  hex.group.small(n, U32.is_lt(n, 16))

def groups(+a: U32, +b: U32, +c: U32, +d: U32) -> List<&2, U32>:
  [(a >> 16n : U32), (a .&. 65535 : U32), (b >> 16n : U32), (b .&. 65535 : U32),
   (c >> 16n : U32), (c .&. 65535 : U32), (d >> 16n : U32), (d .&. 65535 : U32)]

# Keep the first run when two longest zero runs tie.
def zeros.best(xs: List<&2, U32>, +i: U32, +run: U32, +start: U32, +best: U32, +length: U32) -> U32 & U32:
  match xs:
    case Nil{}:
      (best, length)
    case Con{h, t}:
      +next = Bool.pick(U32, U32.is_zero(h), (run + 1 : U32), 0)
      +begin = Bool.pick(U32, U32.is_zero(run), i, start)
      +longer = U32.is_gt(next, length)
      zeros.best(t, (i + 1 : U32), next, begin, Bool.pick(U32, longer, begin, best),
        Bool.pick(U32, longer, next, length))

def v6.field.if(inside: Bool, n: U32, +i: U32, start: U32, end: U32) -> String:
  match inside:
    case True{}:
      Bool.pick(String, U32.is_eq(i, start), "::", "")
    case False{}:
      Bool.pick(String, Bool.or(U32.is_zero(i), U32.is_eq(i, end)), "", ":") ++ hex.group(n)

def v6.field(n: U32, +i: U32, +start: U32, +length: U32) -> String:
  +end = (start + length : U32)
  v6.field.if(Bool.and(U32.is_ge(i, start), U32.is_lt(i, end)), n, i, start, end)

def v6.render(xs: List<&2, U32>, +i: U32, +start: U32, +length: U32) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, t}:
      v6.field(h, i, start, length) ++ v6.render(t, (i + 1 : U32), start, length)

def v6.show.run(+a: U32, +b: U32, +c: U32, +d: U32, run: U32 & U32) -> String:
  (+start, +length) = run
  v6.render(groups(a, b, c, d), 0, Bool.pick(U32, U32.is_ge(length, 2), start, 8),
    Bool.pick(U32, U32.is_ge(length, 2), length, 0))

def v4.show(+w: U32) -> String:
  U32.show((w >> 24n : U32)) ++ "." ++ U32.show(((w >> 16n : U32) .&. 255 : U32)) ++ "." ++
  U32.show(((w >> 8n : U32) .&. 255 : U32)) ++ "." ++ U32.show((w .&. 255 : U32))

def v6.show.mapped(mapped: Bool, +a: U32, +b: U32, +c: U32, +d: U32) -> String:
  match mapped:
    case True{}:
      "::ffff:" ++ v4.show(d)
    case False{}:
      v6.show.run(a, b, c, d, zeros.best(groups(a, b, c, d), 0, 0, 0, 0, 0))

# RFC 5952: lowercase, shortest hex groups, longest leftmost "::" run.
def show(addr: Addr) -> String:
  match addr:
    case V4{w}:
      v4.show(w)
    case V6{+a, +b, +c, +d}:
      v6.show.mapped(Bool.and(U32.is_zero(a), Bool.and(U32.is_zero(b), U32.is_eq(c, 65535))), a, b, c, d)

def eq(x: Addr, y: Addr) -> Bool:
  match x y:
    case V4{a} V4{b}:
      U32.is_eq(a, b)
    case V6{a, b, c, d} V6{e, f, g, h}:
      Bool.and(U32.is_eq(a, e), Bool.and(U32.is_eq(b, f), Bool.and(U32.is_eq(c, g), U32.is_eq(d, h))))
    case _ _:
      False{}

type Prefix is Data:
  Prefix{addr: Addr, bits: U32}

def prefix.digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), prefix.digits(t))

def prefix.limit(addr: Addr, +bits: U32) -> Maybe<&2, Prefix>:
  match addr:
    case V4{w}:
      Bool.pick(Maybe<&2, Prefix>, U32.is_le(bits, 32), Some{Prefix{V4{w}, bits}}, None{})
    case V6{a, b, c, d}:
      Bool.pick(Maybe<&2, Prefix>, U32.is_le(bits, 128), Some{Prefix{V6{a, b, c, d}, bits}}, None{})

def prefix.valid(addr: Addr, bits: U32, valid: Bool) -> Maybe<&2, Prefix>:
  match valid:
    case True{}:
      prefix.limit(addr, bits)
    case False{}:
      None{}

def prefix.number(addr: Addr, +text: String, parsed: Maybe<&2, U32>) -> Maybe<&2, Prefix>:
  match parsed:
    case None{}:
      None{}
    case Some{+bits}:
      prefix.valid(addr, bits, Bool.and(prefix.digits(text), String.eq(U32.show(bits), text)))

def prefix.addr(text: String, +suffix: String, parsed: Maybe<&2, Addr>) -> Maybe<&2, Prefix>:
  match parsed:
    case None{}:
      None{}
    case Some{addr}:
      prefix.number(addr, suffix, U32.read(suffix))

def prefix.parts(parts: List<&2, String>) -> Maybe<&2, Prefix>:
  match parts:
    case Con{+addr, Con{suffix, Nil{}}}:
      prefix.addr(addr, suffix, parse(addr))
    case _:
      None{}

def prefix.parse(s: String) -> Maybe<&2, Prefix>:
  prefix.parts(String.split(s, '/'))

def prefix.show(p: Prefix) -> String:
  Prefix{addr, bits} = p
  show(addr) ++ "/" ++ U32.show(bits)

def mask(bits: U32) -> U32:
  U32.not(U32.shrn(4294967295, U32.to_nat(U32.min(bits, 32))))

def leading(+bits: U32, +offset: U32) -> U32:
  Bool.pick(U32, U32.is_ge(bits, offset), U32.min((bits - offset : U32), 32), 0)

def word.contains(+a: U32, +b: U32, bits: U32) -> Bool:
  +m = mask(bits)
  U32.is_eq((a .&. m : U32), (b .&. m : U32))

# Address and prefix families must match. The supplied prefix address keeps its host bits.
def contains(p: Prefix, addr: Addr) -> Bool:
  match p addr:
    case Prefix{V4{a}, +bits} V4{b}:
      Bool.and(U32.is_le(bits, 32), word.contains(a, b, bits))
    case Prefix{V6{a, b, c, d}, +bits} V6{e, f, g, h}:
      Bool.and(U32.is_le(bits, 128), Bool.and(word.contains(a, e, leading(bits, 0)),
        Bool.and(word.contains(b, f, leading(bits, 32)),
          Bool.and(word.contains(c, g, leading(bits, 64)), word.contains(d, h, leading(bits, 96))))))
    case _ _:
      False{}
