# JSON values, parsed and encoded as RFC 8259. Source: https://github.com/paymog/bend-kit/tree/main/json
import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# JSON (RFC 8259). parse and encode work on text; parse.bytes and encode.bytes
# work on UTF-8 in Bytes, with no String of the whole text. Nesting has no
# depth limit other than input size: the parser keeps its own stack, since a
# Bend def cannot call itself through another def.
#   import ./json/json.bend as Json

# Num keeps the number's exact text, so no precision is lost.
type Val is Data:
  Null{}
  Flag{on: Bool}
  Num{s: String}
  Str{s: String}
  Arr{xs: List<&2, Val>}
  Obj{m: Map<&2, Val>}

type Next is Data:
  Next{v: Val, rest: String}

# An open container: array items so far (reversed), or object fields and the
# key whose value comes next.
type Open is Data:
  OArr{xs: List<&2, Val>}
  OObj{m: Map<&2, Val>, key: String}

type St is Data:
  SValue{s: String, stack: List<&2, Open>}
  SKey{s: String, stack: List<&2, Open>}
  SColon{key: String, s: String, stack: List<&2, Open>}
  SStr{s: String, acc: String, key: Bool, stack: List<&2, Open>}
  SAfter{v: Val, s: String, stack: List<&2, Open>}
  SDone{v: Val, s: String}
  SFail{}

# Whitespace
# ----------

def is_ws(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 32), Bool.or(U32.is_eq(c, 9), Bool.or(U32.is_eq(c, 10), U32.is_eq(c, 13))))

# Bool.pick runs both arms, so loops peek: the next char's class is a Bool
# param and only the matching arm recurses.
def ws.go(t: String, +c: U32, ws: Bool) -> String:
  match t:
    case SNil{}:
      match ws:
        case True{}:
          SNil{}
        case False{}:
          SCon{Chr{c}, SNil{}}
    case SCon{Chr{+d}, u}:
      match ws:
        case True{}:
          ws.go(u, d, is_ws(d))
        case False{}:
          SCon{Chr{c}, SCon{Chr{d}, u}}

def skip_ws(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      ws.go(t, c, is_ws(c))

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

def num.end(+st: U32, acc: String, rest: String) -> Maybe<&2, Next>:
  Bool.pick(Maybe<&2, Next>, num.accepts(st), Some{Next{Num{String.reverse(acc)}, rest}}, None{})

def num.go(t: String, +c: U32, +st: U32, acc: String, stop: Bool) -> Maybe<&2, Next>:
  match t:
    case SNil{}:
      match stop:
        case True{}:
          num.end(st, acc, SCon{Chr{c}, SNil{}})
        case False{}:
          num.end(num.trans(st, c), SCon{Chr{c}, acc}, SNil{})
    case SCon{Chr{+d}, u}:
      match stop:
        case True{}:
          num.end(st, acc, SCon{Chr{c}, SCon{Chr{d}, u}})
        case False{}:
          +n = num.trans(st, c)
          num.go(u, d, n, SCon{Chr{c}, acc}, U32.is_eq(num.trans(n, d), 99))

def num(s: String) -> Maybe<&2, Next>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, t}:
      num.go(t, c, 0, SNil{}, U32.is_eq(num.trans(0, c), 99))

# Literals
# --------

def lit.if(+s: String, v: Val, n: Nat, ok: Bool) -> Maybe<&2, Next>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Next{v, String.drop(s, n)}}

def lit(+s: String, word: String, v: Val, +n: Nat) -> Maybe<&2, Next>:
  lit.if(s, v, n, String.starts_with(s, word))

# Strings (§7)
# ------------

type Esc is Data:
  Esc{cp: U32, rest: String}

def hexd(+c: U32) -> U32:
  Bool.pick(U32, digit(c), (c - 48 : U32), Bool.pick(U32, Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), (c - 87 : U32), Bool.pick(U32, Bool.and(U32.is_le(65, c), U32.is_le(c, 70)), (c - 55 : U32), 99)))

def hex4.go(s: String, +acc: U32, n: Nat) -> Maybe<&2, Esc>:
  match s:
    case SNil{}:
      match n:
        case 0n:
          Some{Esc{acc, SNil{}}}
        case 1n+k:
          None{}
    case SCon{Chr{+c}, t}:
      match n:
        case 0n:
          Some{Esc{acc, SCon{Chr{c}, t}}}
        case 1n+k:
          +h = hexd(c)
          Bool.pick(Maybe<&2, Esc>, U32.is_eq(h, 99), None{}, hex4.go(t, (acc * 16 + h : U32), k))

def hex4(s: String) -> Maybe<&2, Esc>:
  hex4.go(s, 0, 4n)

def is_hi(+v: U32) -> Bool:
  Bool.and(U32.is_le(55296, v), U32.is_le(v, 56319))

def is_lo(+v: U32) -> Bool:
  Bool.and(U32.is_le(56320, v), U32.is_le(v, 57343))

def pair.lo(+hi: U32, +rest: String, lo: Maybe<&2, Esc>) -> Esc:
  match lo:
    case None{}:
      Esc{65533, rest}
    case Some{Esc{+v, r}}:
      Bool.pick(Esc, is_lo(v), Esc{(65536 + (hi - 55296 : U32) * 1024 + (v - 56320 : U32) : U32), r}, Esc{65533, rest})

# §8.2: a high surrogate pairs with a following \uDC00-\uDFFF; a lone one is U+FFFD.
def pair(+hi: U32, +rest: String) -> Esc:
  Bool.pick(Esc, String.starts_with(rest, "\\u"), pair.lo(hi, rest, hex4(String.drop(rest, 2n))), Esc{65533, rest})

def esc.u(e: Maybe<&2, Esc>) -> Maybe<&2, Esc>:
  match e:
    case None{}:
      None{}
    case Some{Esc{+v, +r}}:
      Some{Bool.pick(Esc, is_hi(v), pair(v, r), Bool.pick(Esc, is_lo(v), Esc{65533, r}, Esc{v, r}))}

def esc.simple(+e: U32) -> U32:
  Bool.pick(U32, U32.is_eq(e, 34), 34, Bool.pick(U32, U32.is_eq(e, 92), 92, Bool.pick(U32, U32.is_eq(e, 47), 47,
  Bool.pick(U32, U32.is_eq(e, 98), 8, Bool.pick(U32, U32.is_eq(e, 102), 12, Bool.pick(U32, U32.is_eq(e, 110), 10,
  Bool.pick(U32, U32.is_eq(e, 114), 13, Bool.pick(U32, U32.is_eq(e, 116), 9, 99))))))))

# One escape after the backslash.
def esc.one(t: String) -> Maybe<&2, Esc>:
  match t:
    case SNil{}:
      None{}
    case SCon{Chr{+e}, +u}:
      +v = esc.simple(e)
      Bool.pick(Maybe<&2, Esc>, U32.is_eq(e, 117), esc.u(hex4(u)), Bool.pick(Maybe<&2, Esc>, U32.is_eq(v, 99), None{}, Some{Esc{v, u}}))

def str.esc(e: Maybe<&2, Esc>, acc: String, key: Bool, stack: List<&2, Open>) -> St:
  match e:
    case None{}:
      SFail{}
    case Some{Esc{cp, r}}:
      SStr{r, SCon{Chr{cp}, acc}, key, stack}

def str.close(+acc: String, t: String, key: Bool, stack: List<&2, Open>) -> St:
  match key:
    case True{}:
      SColon{String.reverse(acc), t, stack}
    case False{}:
      SAfter{Str{String.reverse(acc)}, t, stack}

def str.c(quote: Bool, ctl: Bool, bs: Bool, c: U32, t: String, acc: String, key: Bool, stack: List<&2, Open>) -> St:
  match quote:
    case True{}:
      str.close(acc, t, key, stack)
    case False{}:
      match ctl:
        case True{}:
          SFail{}
        case False{}:
          match bs:
            case True{}:
              str.esc(esc.one(t), acc, key, stack)
            case False{}:
              SStr{t, SCon{Chr{c}, acc}, key, stack}

# §7: unescaped chars below U+0020 are not allowed in a string.
def str.step(s: String, acc: String, key: Bool, stack: List<&2, Open>) -> St:
  match s:
    case SNil{}:
      SFail{}
    case SCon{Chr{+c}, t}:
      str.c(U32.is_eq(c, 34), U32.is_lt(c, 32), U32.is_eq(c, 92), c, t, acc, key, stack)

# Machine
# -------

def got(m: Maybe<&2, Next>, stack: List<&2, Open>) -> St:
  match m:
    case None{}:
      SFail{}
    case Some{Next{v, r}}:
      SAfter{v, r, stack}

def open.close(r: String, close: Val, stack: List<&2, Open>, empty: Bool, open: Open) -> St:
  match empty:
    case True{}:
      SAfter{close, String.drop(r, 1n), stack}
    case False{}:
      match open:
        case OArr{xs}:
          SValue{r, Con{OArr{xs}, stack}}
        case OObj{m, k}:
          SKey{r, Con{OObj{m, k}, stack}}

def value.step(+s: String, +c: U32, +t: String, +stack: List<&2, Open>) -> St:
  +r = skip_ws(t)
  Bool.pick(St, U32.is_eq(c, 91), open.close(r, Arr{Nil{}}, stack, String.starts_with(r, "]"), OArr{Nil{}}),
  Bool.pick(St, U32.is_eq(c, 123), open.close(r, Obj{Map.new(&2, Val)}, stack, String.starts_with(r, "}"), OObj{Map.new(&2, Val), ""}),
  Bool.pick(St, U32.is_eq(c, 34), SStr{t, SNil{}, False{}, stack},
  Bool.pick(St, U32.is_eq(c, 116), got(lit(s, "true", Flag{True{}}, 4n), stack),
  Bool.pick(St, U32.is_eq(c, 102), got(lit(s, "false", Flag{False{}}, 5n), stack),
  Bool.pick(St, U32.is_eq(c, 110), got(lit(s, "null", Null{}, 4n), stack),
  got(num(s), stack)))))))

def value(s: String, stack: List<&2, Open>) -> St:
  match s:
    case SNil{}:
      SFail{}
    case SCon{Chr{+c}, +t}:
      value.step(SCon{Chr{c}, t}, c, t, stack)

def key(s: String, stack: List<&2, Open>) -> St:
  match s:
    case SNil{}:
      SFail{}
    case SCon{Chr{+c}, t}:
      Bool.pick(St, U32.is_eq(c, 34), SStr{t, SNil{}, True{}, stack}, SFail{})

def colon.top(k: String, r: String, stack: List<&2, Open>) -> St:
  match stack:
    case Nil{}:
      SFail{}
    case Con{OArr{xs}, up}:
      SFail{}
    case Con{OObj{m, old}, up}:
      SValue{r, Con{OObj{m, k}, up}}

def colon(k: String, s: String, stack: List<&2, Open>) -> St:
  match s:
    case SNil{}:
      SFail{}
    case SCon{Chr{+c}, t}:
      Bool.pick(St, U32.is_eq(c, 58), colon.top(k, t, stack), SFail{})

# A finished value joins its container; then "," or the closing bracket.
def after.arr.c(comma: Bool, close: Bool, t: String, xs: List<&2, Val>, up: List<&2, Open>) -> St:
  match comma:
    case True{}:
      SValue{t, Con{OArr{xs}, up}}
    case False{}:
      match close:
        case True{}:
          SAfter{Arr{List.reverse(&2, Val, xs)}, t, up}
        case False{}:
          SFail{}

def after.arr(xs: List<&2, Val>, r: String, up: List<&2, Open>) -> St:
  match r:
    case SNil{}:
      SFail{}
    case SCon{Chr{+c}, t}:
      after.arr.c(U32.is_eq(c, 44), U32.is_eq(c, 93), t, xs, up)

def after.obj.c(comma: Bool, close: Bool, t: String, m: Map<&2, Val>, up: List<&2, Open>) -> St:
  match comma:
    case True{}:
      SKey{t, Con{OObj{m, ""}, up}}
    case False{}:
      match close:
        case True{}:
          SAfter{Obj{m}, t, up}
        case False{}:
          SFail{}

def after.obj(m: Map<&2, Val>, r: String, up: List<&2, Open>) -> St:
  match r:
    case SNil{}:
      SFail{}
    case SCon{Chr{+c}, t}:
      after.obj.c(U32.is_eq(c, 44), U32.is_eq(c, 125), t, m, up)

def after(v: Val, s: String, stack: List<&2, Open>) -> St:
  match stack:
    case Nil{}:
      SDone{v, s}
    case Con{OArr{xs}, up}:
      after.arr(Con{v, xs}, skip_ws(s), up)
    case Con{OObj{m, k}, up}:
      after.obj(Map.set(&2, Val, m, k, v), skip_ws(s), up)

def step(st: St) -> St:
  match st:
    case SValue{s, stack}:
      value(skip_ws(s), stack)
    case SKey{s, stack}:
      key(skip_ws(s), stack)
    case SColon{k, s, stack}:
      colon(k, skip_ws(s), stack)
    case SStr{s, acc, k, stack}:
      str.step(s, acc, k, stack)
    case SAfter{v, s, stack}:
      after(v, s, stack)
    case SDone{v, s}:
      SDone{v, s}
    case SFail{}:
      SFail{}

def done(v: Val, rest: String) -> Maybe<&2, Val>:
  match rest:
    case SNil{}:
      Some{v}
    case SCon{h, t}:
      None{}

# fuel: every step but the last eats at least one char.
def run(fuel: Nat, st: St) -> Maybe<&2, Val>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      match st:
        case SDone{v, s}:
          done(v, skip_ws(s))
        case SFail{}:
          None{}
        case SValue{s, stack}:
          run(f, step(SValue{s, stack}))
        case SKey{s, stack}:
          run(f, step(SKey{s, stack}))
        case SColon{k, s, stack}:
          run(f, step(SColon{k, s, stack}))
        case SStr{s, acc, k, stack}:
          run(f, step(SStr{s, acc, k, stack}))
        case SAfter{v, s, stack}:
          run(f, step(SAfter{v, s, stack}))

# One JSON text: a value with optional whitespace around it.
def parse(+s: String) -> Maybe<&2, Val>:
  run(Nat.add(String.length(s), 2n), SValue{s, Nil{}})

# Access
# ------

def get.hit(r: Map<&2, Val> & Bool) -> Bool:
  (m, b) = r
  b

def get.some(r: Map<&2, Val> & Val) -> Maybe<&2, Val>:
  (m, x) = r
  Some{x}

def get.has(+m: Map<&2, Val>, +k: String, hit: Bool) -> Maybe<&2, Val>:
  match hit:
    case False{}:
      None{}
    case True{}:
      get.some(Map.get(Val, Null{}, m, k))

def get.of(+m: Map<&2, Val>, +k: String) -> Maybe<&2, Val>:
  get.has(m, k, get.hit(Map.has(&2, Val, m, k)))

# The value under key k of an object.
def get(v: Val, k: String) -> Maybe<&2, Val>:
  match v:
    case Obj{m}:
      get.of(m, k)
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

# Encode
# ------

def hexc(+n: U32) -> Char:
  Chr{Bool.pick(U32, U32.is_lt(n, 10), (48 + n : U32), (87 + n : U32))}

# The escaped form of one char, reversed (it is pushed onto a reversed acc).
def esc.put(+c: U32, +acc: String) -> String:
  Bool.pick(String, U32.is_eq(c, 34), SCon{Chr{34}, SCon{Chr{92}, acc}},
  Bool.pick(String, U32.is_eq(c, 92), SCon{Chr{92}, SCon{Chr{92}, acc}},
  Bool.pick(String, U32.is_eq(c, 10), SCon{Chr{110}, SCon{Chr{92}, acc}},
  Bool.pick(String, U32.is_eq(c, 13), SCon{Chr{114}, SCon{Chr{92}, acc}},
  Bool.pick(String, U32.is_eq(c, 9), SCon{Chr{116}, SCon{Chr{92}, acc}},
  Bool.pick(String, U32.is_lt(c, 32), SCon{hexc(U32.and(c, 15)), SCon{hexc(U32.shrn(c, 4n)), SCon{Chr{48}, SCon{Chr{48}, SCon{Chr{117}, SCon{Chr{92}, acc}}}}}},
  SCon{Chr{c}, acc}))))))

def esc.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+c}, t}:
      esc.go(t, esc.put(c, acc))

def esc(s: String) -> String:
  esc.go(s, SNil{})

type Item is Data:
  ILit{s: String}
  IKey{k: String}
  IVal{v: Val}

def items.sep(first: Bool, tail: List<&2, Item>) -> List<&2, Item>:
  match first:
    case True{}:
      tail
    case False{}:
      Con{ILit{","}, tail}

def items.arr(xs: List<&2, Val>, first: Bool, rest: List<&2, Item>) -> List<&2, Item>:
  match xs:
    case Nil{}:
      Con{ILit{"]"}, rest}
    case Con{x, t}:
      items.sep(first, Con{IVal{x}, items.arr(t, False{}, rest)})

def items.obj(kvs: List<&2, Sigma<&2, &2, String, _ => Val>>, first: Bool, rest: List<&2, Item>) -> List<&2, Item>:
  match kvs:
    case Nil{}:
      Con{ILit{"}"}, rest}
    case (k, v) <> t:
      items.sep(first, Con{IKey{k}, Con{IVal{v}, items.obj(t, False{}, rest)}})

def put(s: String, racc: String) -> String:
  String.reverse(s) ++ racc

# ponytail: @unsafe because it walks a work list, not the Val; each step
# emits text or swaps a container for its strictly smaller parts.
@unsafe
def enc.go(items: List<&2, Item>, racc: String) -> String:
  match items:
    case Nil{}:
      String.reverse(racc)
    case Con{ILit{s}, t}:
      enc.go(t, put(s, racc))
    case Con{IKey{k}, t}:
      enc.go(t, put("\"" ++ esc(k) ++ "\":", racc))
    case Con{IVal{Null{}}, t}:
      enc.go(t, put("null", racc))
    case Con{IVal{Flag{True{}}}, t}:
      enc.go(t, put("true", racc))
    case Con{IVal{Flag{False{}}}, t}:
      enc.go(t, put("false", racc))
    case Con{IVal{Num{n}}, t}:
      enc.go(t, put(n, racc))
    case Con{IVal{Str{s}}, t}:
      enc.go(t, put("\"" ++ esc(s) ++ "\"", racc))
    case Con{IVal{Arr{xs}}, t}:
      enc.go(Con{ILit{"["}, items.arr(xs, True{}, t)}, racc)
    case Con{IVal{Obj{m}}, t}:
      enc.go(Con{ILit{"{"}, items.obj(Map.to_list(&2, Val, m), True{}, t)}, racc)

# Compact JSON; object keys come out sorted.
def encode(v: Val) -> String:
  enc.go(Con{IVal{v}, Nil{}}, "")

def at.go(xs: List<&2, Val>, n: Nat) -> Maybe<&2, Val>:
  match xs:
    case Nil{}:
      None{}
    case Con{v, t}:
      match n:
        case 0n:
          Some{v}
        case 1n+p:
          at.go(t, p)


def at(v: Val, n: Nat) -> Maybe<&2, Val>:
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
    case Obj{m}:
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

def u32(v: Val) -> Maybe<&2, U32>:
  match v:
    case Num{s}:
      u32.num(s)
    case Null{}:
      None{}
    case Flag{on}:
      None{}
    case Str{s}:
      None{}
    case Arr{xs}:
      None{}
    case Obj{m}:
      None{}

# Bytes: parse
# ------------
# The same machine over UTF-8 in a Bytes buffer. A state holds the offset of
# its next byte; the buffer goes beside it.

type Sb is Data:
  BValue{i: U32, stack: List<&2, Open>}
  BFirst{i: U32, open: Open, stack: List<&2, Open>}
  BKey{i: U32, stack: List<&2, Open>}
  BColon{key: String, i: U32, stack: List<&2, Open>}
  BStr{i: U32, acc: String, key: Bool, stack: List<&2, Open>}
  BNum{i: U32, st: U32, acc: String, stack: List<&2, Open>}
  BAfter{v: Val, i: U32, stack: List<&2, Open>}
  BSep{i: U32, open: Open, stack: List<&2, Open>}
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

def str.b.cp(acc: String, key: Bool, stack: List<&2, Open>, +i: U32, r: Array<U32> & Cp) -> Array<U32> & Sb:
  (a, Cp{+c, +w}) = r
  (a, Bool.pick(Sb, U32.is_eq(w, 0), BFail{}, BStr{(i + w : U32), SCon{Chr{c}, acc}, key, stack}))

def str.b.lo(+i: U32, +hi: U32, +acc: String, +key: Bool, +stack: List<&2, Open>, r: Array<U32> & U32) -> Array<U32> & Sb:
  (a, +lo) = r
  (a, Bool.pick(Sb, is_lo(lo), BStr{(i + 12 : U32), SCon{Chr{(65536 + (hi - 55296 : U32) * 1024 + (lo - 56320 : U32) : U32)}, acc}, key, stack}, BStr{(i + 6 : U32), SCon{Chr{65533}, acc}, key, stack}))

# §8.2: a high surrogate pairs with a following \uDC00-\uDFFF; a lone one is U+FFFD.
def str.b.pair(+len: U32, +i: U32, +hi: U32, acc: String, key: Bool, stack: List<&2, Open>, r: Array<U32> & Bool) -> Array<U32> & Sb:
  (a, ok) = r
  match ok:
    case True{}:
      str.b.lo(i, hi, acc, key, stack, hex4.b(a, len, (i + 8 : U32)))
    case False{}:
      (a, BStr{(i + 6 : U32), SCon{Chr{65533}, acc}, key, stack})

# 0: not four hex digits; 1: high surrogate; 2: low surrogate; 3: other.
def u.class(+v: U32) -> U32:
  Bool.pick(U32, U32.is_eq(v, 65536), 0, Bool.pick(U32, is_hi(v), 1, Bool.pick(U32, is_lo(v), 2, 3)))

def str.b.u.of(+k: U32, a: Array<U32>, +len: U32, +i: U32, +v: U32, acc: String, key: Bool, stack: List<&2, Open>) -> Array<U32> & Sb:
  match k:
    case 0:
      (a, BFail{})
    case 1:
      str.b.pair(len, i, v, acc, key, stack, word(a, len, "\\u", (i + 6 : U32)))
    case 2:
      (a, BStr{(i + 6 : U32), SCon{Chr{65533}, acc}, key, stack})
    case _:
      (a, BStr{(i + 6 : U32), SCon{Chr{v}, acc}, key, stack})

def str.b.u(+len: U32, +i: U32, acc: String, key: Bool, stack: List<&2, Open>, r: Array<U32> & U32) -> Array<U32> & Sb:
  (a, +v) = r
  str.b.u.of(u.class(v), a, len, i, v, acc, key, stack)

# The escape whose backslash is at i.
def str.b.esc(+len: U32, +i: U32, acc: String, key: Bool, stack: List<&2, Open>, r: Array<U32> & U32) -> Array<U32> & Sb:
  (a, +e) = r
  match e:
    case 117:
      str.b.u(len, i, acc, key, stack, hex4.b(a, len, (i + 2 : U32)))
    case _:
      +v = esc.simple(e)
      (a, Bool.pick(Sb, U32.is_eq(v, 99), BFail{}, BStr{(i + 2 : U32), SCon{Chr{v}, acc}, key, stack}))

def str.b.close(+i: U32, acc: String, key: Bool, stack: List<&2, Open>) -> Sb:
  match key:
    case True{}:
      BColon{String.reverse(acc), (i + 1 : U32), stack}
    case False{}:
      BAfter{Str{String.reverse(acc)}, (i + 1 : U32), stack}

# §7: unescaped chars below U+0020 are not allowed in a string.
def str.b.other(ascii: Bool, +c: U32, a: Array<U32>, +len: U32, +i: U32, acc: String, key: Bool, stack: List<&2, Open>) -> Array<U32> & Sb:
  match ascii:
    case True{}:
      (a, Bool.pick(Sb, U32.is_lt(c, 32), BFail{}, BStr{(i + 1 : U32), SCon{Chr{c}, acc}, key, stack}))
    case False{}:
      str.b.cp(acc, key, stack, i, utf8.at(a, len, i, c))

def str.b(r: Array<U32> & U32, +len: U32, +i: U32, acc: String, key: Bool, stack: List<&2, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  match c:
    case 34:
      (a, str.b.close(i, acc, key, stack))
    case 92:
      str.b.esc(len, i, acc, key, stack, pk(a, len, (i + 1 : U32)))
    case 256:
      (a, BFail{})
    case _:
      str.b.other(U32.is_lt(c, 128), c, a, len, i, acc, key, stack)

def num.b.end(ok: Bool, +i: U32, acc: String, stack: List<&2, Open>) -> Sb:
  match ok:
    case True{}:
      BAfter{Num{String.reverse(acc)}, i, stack}
    case False{}:
      BFail{}

def num.b.if(stop: Bool, +c: U32, +i: U32, +st: U32, +n: U32, acc: String, stack: List<&2, Open>) -> Sb:
  match stop:
    case True{}:
      num.b.end(num.accepts(st), i, acc, stack)
    case False{}:
      BNum{(i + 1 : U32), n, SCon{Chr{c}, acc}, stack}

def num.b(r: Array<U32> & U32, +i: U32, +st: U32, acc: String, stack: List<&2, Open>) -> Array<U32> & Sb:
  (a, +c) = r
  +n = num.trans(st, c)
  (a, num.b.if(U32.is_eq(n, 99), c, i, st, n, acc, stack))

def lit.b(+i: U32, +n: U32, v: Val, stack: List<&2, Open>, r: Array<U32> & Bool) -> Array<U32> & Sb:
  (a, ok) = r
  match ok:
    case True{}:
      (a, BAfter{v, (i + n : U32), stack})
    case False{}:
      (a, BFail{})

def value.b(r: Array<U32> & U32, +len: U32, +i: U32, stack: List<&2, Open>) -> Array<U32> & Sb:
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
      (a, BFirst{(i + 1 : U32), OObj{Map.new(&2, Val), ""}, stack})
    case 34:
      (a, BStr{(i + 1 : U32), SNil{}, False{}, stack})
    case 116:
      lit.b(i, 4, Flag{True{}}, stack, word(a, len, "true", i))
    case 102:
      lit.b(i, 5, Flag{False{}}, stack, word(a, len, "false", i))
    case 110:
      lit.b(i, 4, Null{}, stack, word(a, len, "null", i))
    case _:
      (a, BNum{i, 0, SNil{}, stack})

# After "[" or "{": the closing bracket, or the first item.
def first.b.end(open: Open, +c: U32, +i: U32, stack: List<&2, Open>) -> Sb:
  match open:
    case OArr{xs}:
      Bool.pick(Sb, U32.is_eq(c, 93), BAfter{Arr{Nil{}}, (i + 1 : U32), stack}, BFail{})
    case OObj{m, k}:
      Bool.pick(Sb, U32.is_eq(c, 125), BAfter{Obj{m}, (i + 1 : U32), stack}, BFail{})

def first.b.open(open: Open, +i: U32, stack: List<&2, Open>) -> Sb:
  match open:
    case OArr{xs}:
      BValue{i, Con{OArr{xs}, stack}}
    case OObj{m, k}:
      BKey{i, Con{OObj{m, k}, stack}}

def first.b(r: Array<U32> & U32, +i: U32, open: Open, stack: List<&2, Open>) -> Array<U32> & Sb:
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

def key.b(r: Array<U32> & U32, +i: U32, stack: List<&2, Open>) -> Array<U32> & Sb:
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
      (a, BStr{(i + 1 : U32), SNil{}, True{}, stack})
    case _:
      (a, BFail{})

def colon.b.top(k: String, +i: U32, stack: List<&2, Open>) -> Sb:
  match stack:
    case Nil{}:
      BFail{}
    case Con{OArr{xs}, up}:
      BFail{}
    case Con{OObj{m, old}, up}:
      BValue{i, Con{OObj{m, k}, up}}

def colon.b(r: Array<U32> & U32, k: String, +i: U32, stack: List<&2, Open>) -> Array<U32> & Sb:
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
def after.b(v: Val, +i: U32, stack: List<&2, Open>) -> Sb:
  match stack:
    case Nil{}:
      BEnd{v, i}
    case Con{OArr{xs}, up}:
      BSep{i, OArr{Con{v, xs}}, up}
    case Con{OObj{m, k}, up}:
      BSep{i, OObj{Map.set(&2, Val, m, k, v), ""}, up}

def sep.b.comma(open: Open, +i: U32, up: List<&2, Open>) -> Sb:
  match open:
    case OArr{xs}:
      BValue{i, Con{OArr{xs}, up}}
    case OObj{m, k}:
      BKey{i, Con{OObj{m, k}, up}}

def sep.b.close(open: Open, +c: U32, +i: U32, up: List<&2, Open>) -> Sb:
  match open:
    case OArr{xs}:
      Bool.pick(Sb, U32.is_eq(c, 93), BAfter{Arr{List.reverse(&2, Val, xs)}, i, up}, BFail{})
    case OObj{m, k}:
      Bool.pick(Sb, U32.is_eq(c, 125), BAfter{Obj{m}, i, up}, BFail{})

# After an item: "," or the closing bracket.
def sep.b(r: Array<U32> & U32, +i: U32, open: Open, up: List<&2, Open>) -> Array<U32> & Sb:
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
def runb(fuel: Nat, r: Array<U32> & Sb, +len: U32) -> Maybe<&2, Val>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      (a, st) = r
      match st:
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
        case BStr{+i, acc, k, stack}:
          runb(f, str.b(pk(a, len, i), len, i, acc, k, stack), len)
        case BNum{+i, +s, acc, stack}:
          runb(f, num.b(pk(a, len, i), i, s, acc, stack), len)
        case BAfter{v, +i, stack}:
          runb(f, (a, after.b(v, i, stack)), len)
        case BSep{+i, open, stack}:
          runb(f, sep.b(pk(a, len, i), i, open, stack), len)
        case BEnd{v, +i}:
          runb(f, end.b(pk(a, len, i), v, i), len)

# One JSON text in UTF-8. None for bad JSON or bad UTF-8 (RFC 8259 §8.1).
def parse.bytes(b: Bytes.Bytes) -> Maybe<&2, Val>:
  Bytes.Bytes{+len, buf} = b
  runb(Nat.add(Nat.mul(U32.to_nat(len), 4n), 4n), (buf, BValue{0, Nil{}}), len)

# Bytes: encode
# -------------

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

def w.ctl(ctl: Bool, +c: U32, o: W) -> W:
  match ctl:
    case True{}:
      w.put(w.put(w.put(w.put(w.put(w.put(o, 92), 117), 48), 48), w.hex(U32.shrn(c, 4n))), w.hex((c .&. 15 : U32)))
    case False{}:
      w.cp(c, o)

# §7: quote, backslash and control chars are escaped.
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

def w.text(s: String, o: W) -> W:
  match s:
    case SNil{}:
      o
    case SCon{Chr{+c}, t}:
      w.text(t, w.cp(c, o))

# A quoted, escaped string.
def w.str.go(s: String, o: W) -> W:
  match s:
    case SNil{}:
      w.put(o, 34)
    case SCon{Chr{+c}, t}:
      w.str.go(t, w.esc.c(c, o))

def w.str(s: String, o: W) -> W:
  w.str.go(s, w.put(o, 34))

# ponytail: @unsafe for the same reason as enc.go.
@unsafe
def encb.go(items: List<&2, Item>, o: W) -> W:
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
      encb.go(t, w.text(n, o))
    case Con{IVal{Str{s}}, t}:
      encb.go(t, w.str(s, o))
    case Con{IVal{Arr{xs}}, t}:
      encb.go(Con{ILit{"["}, items.arr(xs, True{}, t)}, o)
    case Con{IVal{Obj{m}}, t}:
      encb.go(Con{ILit{"{"}, items.obj(Map.to_list(&2, Val, m), True{}, t)}, o)

# encode, as UTF-8 in Bytes.
def encode.bytes(v: Val) -> Bytes.Bytes:
  w.done(encb.go(Con{IVal{v}, Nil{}}, W{Bytes.alloc(64), 16, 0, 0}))
