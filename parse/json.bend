import Base
import ./parse.bend as P
import ../json/json.bend as Json

# RFC 8259 JSON on the combinators, to the same Json.Val as json/json.bend.

def is_ws(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 32), Bool.or(U32.is_eq(c, 9), Bool.or(U32.is_eq(c, 10), U32.is_eq(c, 13))))

def ws(c: P.Cur) -> P.Res<String>:
  P.take_while(~is_ws, c)

def tok.r(+w: U32, r: P.Res<String>) -> P.Res<U32>:
  match r:
    case P.Ok{s, c}:
      P.char(w, c)
    case P.Err{o, e}:
      P.Err{o, e}

def tok(+w: U32, c: P.Cur) -> P.Res<U32>:
  tok.r(w, ws(c))

# Numbers (§6)
# ------------

def is_digit(+c: U32) -> Bool:
  Bool.and(U32.is_le(48, c), U32.is_le(c, 57))

def is_digit1(+c: U32) -> Bool:
  Bool.and(U32.is_le(49, c), U32.is_le(c, 57))

def digits1(c: P.Cur) -> P.Res<String>:
  P.text(~P.Both(U32, String), ~(d => P.seq(~U32, ~String, ~(e => P.satisfy(~is_digit, "digit", e)), ~(e => P.take_while(~is_digit, e)), d)), c)

def int(c: P.Cur) -> P.Res<String>:
  P.alt(~String, ~(d => P.lit("0", d)), ~(d => P.text(~P.Both(U32, String), ~(e => P.seq(~U32, ~String, ~(f => P.satisfy(~is_digit1, "digit", f)), ~(f => P.take_while(~is_digit, f)), e)), d)), c)

def frac(c: P.Cur) -> P.Res<Maybe<&2, String>>:
  P.opt(~String, ~(d => P.right(~U32, ~String, ~(e => P.char(46, e)), ~digits1, d)), c)

def is_e(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69))

def is_sign(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 43), U32.is_eq(c, 45))

def exp.tail(c: P.Cur) -> P.Res<P.Both(Maybe<&2, U32>, String)>:
  P.seq(~Maybe<&2, U32>, ~String, ~(d => P.opt(~U32, ~(e => P.satisfy(~is_sign, "sign", e)), d)), ~digits1, c)

def exp(c: P.Cur) -> P.Res<Maybe<&2, P.Both(U32, P.Both(Maybe<&2, U32>, String))>>:
  P.opt(~P.Both(U32, P.Both(Maybe<&2, U32>, String)), ~(d => P.seq(~U32, ~P.Both(Maybe<&2, U32>, String), ~(e => P.satisfy(~is_e, "exponent", e)), ~exp.tail, d)), c)

def num.body(c: P.Cur) -> P.Res<P.Both(String, P.Both(Maybe<&2, String>, Maybe<&2, P.Both(U32, P.Both(Maybe<&2, U32>, String))>))>:
  P.seq(~String, ~P.Both(Maybe<&2, String>, Maybe<&2, P.Both(U32, P.Both(Maybe<&2, U32>, String))>), ~int, ~(d => P.seq(~Maybe<&2, String>, ~Maybe<&2, P.Both(U32, P.Both(Maybe<&2, U32>, String))>, ~frac, ~exp, d)), c)

def num(c: P.Cur) -> P.Res<String>:
  P.text(~P.Both(Maybe<&2, U32>, P.Both(String, P.Both(Maybe<&2, String>, Maybe<&2, P.Both(U32, P.Both(Maybe<&2, U32>, String))>))), ~(d => P.seq(~Maybe<&2, U32>, ~P.Both(String, P.Both(Maybe<&2, String>, Maybe<&2, P.Both(U32, P.Both(Maybe<&2, U32>, String))>)), ~(e => P.opt(~U32, ~(f => P.char(45, f)), e)), ~num.body, d)), c)

# Strings (§7)
# ------------

def hexd(+c: U32) -> U32:
  Bool.pick(U32, is_digit(c), (c - 48 : U32), Bool.pick(U32, Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), (c - 87 : U32), (c - 55 : U32)))

def is_hex(+c: U32) -> Bool:
  Bool.or(is_digit(c), Bool.or(Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), Bool.and(U32.is_le(65, c), U32.is_le(c, 70))))

def hex(c: P.Cur) -> P.Res<U32>:
  P.map(~U32, ~U32, ~(x => hexd(x)), ~(d => P.satisfy(~is_hex, "hex digit", d)), c)

def hex.val(s: String, +acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+h}, t}:
      hex.val(t, (acc * 16 + hexd(h) : U32))

def hex4(c: P.Cur) -> P.Res<U32>:
  P.map(~String, ~U32, ~(s => hex.val(s, 0)), ~(d => P.text(~P.Both(U32, P.Both(U32, P.Both(U32, U32))), ~(e => P.seq(~U32, ~P.Both(U32, P.Both(U32, U32)), ~hex, ~(f => P.seq(~U32, ~P.Both(U32, U32), ~hex, ~(g => P.seq(~U32, ~U32, ~hex, ~hex, g)), f)), e)), d)), c)

def esc.u(c: P.Cur) -> P.Res<U32>:
  P.right(~String, ~U32, ~(d => P.lit("\\u", d)), ~hex4, c)

def is_hi(+v: U32) -> Bool:
  Bool.and(U32.is_le(55296, v), U32.is_le(v, 56319))

def is_lo(+v: U32) -> Bool:
  Bool.and(U32.is_le(56320, v), U32.is_le(v, 57343))

def when.if(ok: Bool, v: U32, c: P.Cur) -> P.Res<U32>:
  match ok:
    case True{}:
      P.Ok{v, c}
    case False{}:
      P.fail(U32, "surrogate", c)

def hi.k(+v: U32, c: P.Cur) -> P.Res<U32>:
  when.if(is_hi(v), v, c)

def lo.k(+v: U32, c: P.Cur) -> P.Res<U32>:
  when.if(is_lo(v), v, c)

def u.hi(c: P.Cur) -> P.Res<U32>:
  P.bind(~U32, ~U32, ~esc.u, ~(v => d => hi.k(v, d)), c)

def u.lo(c: P.Cur) -> P.Res<U32>:
  P.bind(~U32, ~U32, ~esc.u, ~(v => d => lo.k(v, d)), c)

def join(p: P.Both(U32, U32)) -> U32:
  (+hi, +lo) = p
  (65536 + (hi - 55296 : U32) * 1024 + (lo - 56320 : U32) : U32)

# §8.2: a high surrogate pairs with a following low one; a lone one is U+FFFD.
def uchar(c: P.Cur) -> P.Res<U32>:
  P.alt(~U32, ~(d => P.map(~P.Both(U32, U32), ~U32, ~join, ~(e => P.seq(~U32, ~U32, ~u.hi, ~u.lo, e)), d)),
  ~(d => P.alt(~U32, ~(e => P.map(~U32, ~U32, ~(v => 65533), ~u.hi, e)),
  ~(e => P.alt(~U32, ~(f => P.map(~U32, ~U32, ~(v => 65533), ~u.lo, f)), ~esc.u, e)), d)), c)

def esc.simple(+e: U32) -> U32:
  Bool.pick(U32, U32.is_eq(e, 34), 34, Bool.pick(U32, U32.is_eq(e, 92), 92, Bool.pick(U32, U32.is_eq(e, 47), 47,
  Bool.pick(U32, U32.is_eq(e, 98), 8, Bool.pick(U32, U32.is_eq(e, 102), 12, Bool.pick(U32, U32.is_eq(e, 110), 10,
  Bool.pick(U32, U32.is_eq(e, 114), 13, Bool.pick(U32, U32.is_eq(e, 116), 9, 99))))))))

def is_simple(+e: U32) -> Bool:
  Bool.not(U32.is_eq(esc.simple(e), 99))

def esc.one(c: P.Cur) -> P.Res<U32>:
  P.right(~U32, ~U32, ~(d => P.char(92, d)), ~(d => P.map(~U32, ~U32, ~(x => esc.simple(x)), ~(e => P.satisfy(~is_simple, "escape", e)), d)), c)

# §7: unescaped chars below U+0020 are not allowed in a string.
def is_plain(+c: U32) -> Bool:
  Bool.and(U32.is_le(32, c), Bool.and(Bool.not(U32.is_eq(c, 34)), Bool.not(U32.is_eq(c, 92))))

def str.char(c: P.Cur) -> P.Res<U32>:
  P.alt(~U32, ~(d => P.satisfy(~is_plain, "char", d)), ~(d => P.alt(~U32, ~uchar, ~esc.one, d)), c)

def chars(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, chars(t)}

def str(c: P.Cur) -> P.Res<String>:
  P.map(~List<&2, U32>, ~String, ~chars, ~(d => P.right(~U32, ~List<&2, U32>, ~(e => P.char(34, e)), ~(e => P.left(~List<&2, U32>, ~U32, ~(f => P.many(~U32, ~str.char, f)), ~(f => P.char(34, f)), e)), d)), c)

# Values
# ------

# An open container: array items so far (reversed), or object fields and the
# key whose value comes next.
type Fr is Data:
  FArr{xs: List<&2, Json.Val>}
  FObj{m: Map<&2, Json.Val>, k: String}

def key(c: P.Cur) -> P.Res<String>:
  P.right(~String, ~String, ~ws, ~(d => P.left(~String, ~U32, ~str, ~(e => tok(58, e)), d)), c)

def leaf(c: P.Cur) -> P.Res<Json.Val>:
  P.alt(~Json.Val, ~(d => P.map(~String, ~Json.Val, ~(s => Json.Null{}), ~(e => P.lit("null", e)), d)),
  ~(d => P.alt(~Json.Val, ~(e => P.map(~String, ~Json.Val, ~(s => Json.Flag{True{}}), ~(f => P.lit("true", f)), e)),
  ~(e => P.alt(~Json.Val, ~(f => P.map(~String, ~Json.Val, ~(s => Json.Flag{False{}}), ~(g => P.lit("false", g)), f)),
  ~(f => P.alt(~Json.Val, ~(g => P.map(~String, ~Json.Val, ~(s => Json.Str{s}), ~str, g)),
  ~(g => P.map(~String, ~Json.Val, ~(s => Json.Num{s}), ~num, g)), f)), e)), d)), c)

def arr.open(c: P.Cur) -> P.Res<P.Step<Json.Val, Fr>>:
  P.alt(~P.Step<Json.Val, Fr>, ~(d => P.map(~U32, ~P.Step<Json.Val, Fr>, ~(x => P.Leaf{Json.Arr{Nil{}}}), ~(e => P.right(~U32, ~U32, ~(f => P.char(91, f)), ~(f => tok(93, f)), e)), d)),
  ~(d => P.map(~U32, ~P.Step<Json.Val, Fr>, ~(x => P.Open{FArr{Nil{}}}), ~(e => P.char(91, e)), d)), c)

def obj.open(c: P.Cur) -> P.Res<P.Step<Json.Val, Fr>>:
  P.alt(~P.Step<Json.Val, Fr>, ~(d => P.map(~U32, ~P.Step<Json.Val, Fr>, ~(x => P.Leaf{Json.Obj{Map.new(&2, Json.Val)}}), ~(e => P.right(~U32, ~U32, ~(f => P.char(123, f)), ~(f => tok(125, f)), e)), d)),
  ~(d => P.map(~String, ~P.Step<Json.Val, Fr>, ~(k => P.Open{FObj{Map.new(&2, Json.Val), k}}), ~(e => P.right(~U32, ~String, ~(f => P.char(123, f)), ~key, e)), d)), c)

def open(c: P.Cur) -> P.Res<P.Step<Json.Val, Fr>>:
  P.right(~String, ~P.Step<Json.Val, Fr>, ~ws, ~(d => P.alt(~P.Step<Json.Val, Fr>, ~arr.open,
  ~(e => P.alt(~P.Step<Json.Val, Fr>, ~obj.open, ~(f => P.map(~Json.Val, ~P.Step<Json.Val, Fr>, ~(v => P.Leaf{v}), ~leaf, f)), e)), d)), c)

def arr.tag(comma: Bool, xs: List<&2, Json.Val>, c: P.Cur) -> P.Res<P.Step<Json.Val, Fr>>:
  match comma:
    case True{}:
      P.Ok{P.Open{FArr{xs}}, c}
    case False{}:
      P.Ok{P.Leaf{Json.Arr{List.reverse(&2, Json.Val, xs)}}, c}

def arr.next(xs: List<&2, Json.Val>, r: P.Res<U32>) -> P.Res<P.Step<Json.Val, Fr>>:
  match r:
    case P.Ok{+t, c}:
      arr.tag(U32.is_eq(t, 44), xs, c)
    case P.Err{o, w}:
      P.Err{o, w}

def obj.next(m: Map<&2, Json.Val>, r: P.Res<Maybe<&2, String>>) -> P.Res<P.Step<Json.Val, Fr>>:
  match r:
    case P.Ok{Some{k}, c}:
      P.Ok{P.Open{FObj{m, k}}, c}
    case P.Ok{None{}, c}:
      P.Ok{P.Leaf{Json.Obj{m}}, c}
    case P.Err{o, w}:
      P.Err{o, w}

def arr.sep(c: P.Cur) -> P.Res<U32>:
  P.right(~String, ~U32, ~ws, ~(d => P.alt(~U32, ~(e => P.char(44, e)), ~(e => P.char(93, e)), d)), c)

def obj.sep(c: P.Cur) -> P.Res<Maybe<&2, String>>:
  P.right(~String, ~Maybe<&2, String>, ~ws, ~(d => P.alt(~Maybe<&2, String>, ~(e => P.map(~String, ~Maybe<&2, String>, ~(k => Some{k}), ~(f => P.right(~U32, ~String, ~(g => P.char(44, g)), ~key, f)), e)),
  ~(e => P.map(~U32, ~Maybe<&2, String>, ~(x => None{}), ~(f => P.char(125, f)), e)), d)), c)

# §4: names SHOULD be unique; like most parsers, the last one wins.
def next(f: Fr, v: Json.Val, c: P.Cur) -> P.Res<P.Step<Json.Val, Fr>>:
  match f:
    case FArr{xs}:
      arr.next(v <> xs, arr.sep(c))
    case FObj{m, k}:
      obj.next(Map.set(&2, Json.Val, m, k, v), obj.sep(c))

def value(c: P.Cur) -> P.Res<Json.Val>:
  P.left(~Json.Val, ~String, ~(d => P.rec(~Json.Val, ~Fr, ~open, ~next, d)), ~ws, c)

def parse.res(+s: String) -> P.Res<Json.Val>:
  P.run(~Json.Val, ~value, s)

def maybe(r: P.Res<Json.Val>) -> Maybe<&2, Json.Val>:
  match r:
    case P.Ok{v, c}:
      Some{v}
    case P.Err{o, w}:
      None{}

# One JSON text, as Json.parse.
def parse(+s: String) -> Maybe<&2, Json.Val>:
  maybe(parse.res(s))
