# CommonMark 0.31.2: Markdown to HTML.
import Base
import bend-kit-unicode@0.1.0.0/unicode.bend as U
import ./entities.bend as E

# ---- characters

# The first code point of s; 0 when s is empty.
def hd(s: String) -> U32:
  match s:
    case SNil{}:
      0
    case SCon{Chr{y}, t}:
      y

def eq(+a: U32, +b: U32) -> Bool:
  U32.is_eq(a, b)

def within(+c: U32, +lo: U32, +hi: U32) -> Bool:
  U32.is_ge(c, lo) && U32.is_le(c, hi)

def one(+c: U32) -> String:
  SCon{Chr{c}, SNil{}}

def is_sp(+c: U32) -> Bool:
  eq(c, 32) || eq(c, 9)

def is_nl(+c: U32) -> Bool:
  eq(c, 10) || eq(c, 13)

def is_digit(+c: U32) -> Bool:
  within(c, 48, 57)

def is_hex(+c: U32) -> Bool:
  is_digit(c) || within(c, 65, 70) || within(c, 97, 102)

def is_alpha(+c: U32) -> Bool:
  within(c, 65, 90) || within(c, 97, 122)

def is_alnum(+c: U32) -> Bool:
  is_alpha(c) || is_digit(c)

def is_apunct(+c: U32) -> Bool:
  within(c, 33, 47) || within(c, 58, 64) || within(c, 91, 96) || within(c, 123, 126)

def cat_ps(s: String) -> Bool:
  +c = hd(s)
  eq(c, 80) || eq(c, 83)

def is_punct.go(big: Bool, +c: U32) -> Bool:
  match big:
    case False{}:
      is_apunct(c)
    case True{}:
      cat_ps(U.category(Chr{c}))

# Unicode punctuation: general category P or S.
def is_punct(+c: U32) -> Bool:
  is_punct.go(U32.is_ge(c, 128), c)

def is_uws.go(big: Bool, +c: U32) -> Bool:
  match big:
    case False{}:
      eq(c, 32) || eq(c, 9) || eq(c, 10) || eq(c, 12) || eq(c, 13)
    case True{}:
      String.eq(U.category(Chr{c}), "Zs")

# Unicode whitespace: general category Zs, tab, LF, FF, or CR. 0 stands for the edge of the text.
def is_uws(+c: U32) -> Bool:
  eq(c, 0) || is_uws.go(U32.is_ge(c, 128), c)

def lower(+c: U32) -> U32:
  Bool.pick(U32, within(c, 65, 90), (c + 32 : U32), c)

# ---- scanning

# A parsed value and the text after it.
type Got is Data:
  Got{v: String, rest: String}

def fst(r: String & String) -> String:
  (a, b) = r
  a

def snd(r: String & String) -> String:
  (a, b) = r
  b

def span.cons(+y: U32, r: String & String) -> String & String:
  (a, b) = r
  (SCon{Chr{y}, a}, b)

def span.go(~p: U32 -> Bool, s: String, ok: Bool) -> String & String:
  match s:
    case SNil{}:
      (SNil{}, SNil{})
    case SCon{Chr{y}, +t}:
      match ok:
        case False{}:
          (SNil{}, SCon{Chr{y}, t})
        case True{}:
          span.cons(y, span.go(~p, t, p(hd(t))))

# The longest prefix of s whose code points satisfy p, and the rest.
def span(~p: U32 -> Bool, +s: String) -> String & String:
  span.go(~p, s, p(hd(s)))

def skip(~p: U32 -> Bool, +s: String) -> String:
  snd(span(~p, s))

def count.go(+k: U32, s: String, ok: Bool) -> Nat:
  match s:
    case SNil{}:
      0n
    case SCon{Chr{y}, +t}:
      match ok:
        case False{}:
          0n
        case True{}:
          1n+count.go(k, t, eq(hd(t), k))

# How many times k repeats at the start of s.
def count(+k: U32, +s: String) -> Nat:
  count.go(k, s, eq(hd(s), k))

def lit(+p: String, +s: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, String.starts_with(s, p), Some{String.drop(s, String.length(p))}, None{})

def lower_s(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, t}:
      SCon{Chr{lower(y)}, lower_s(t)}

# p must be lower case; s matches it in any ASCII case.
def lit_ci(+p: String, +s: String) -> Maybe<&2, String>:
  +n = String.length(p)
  Bool.pick(Maybe<&2, String>, String.eq(lower_s(String.take(s, n)), p) && Nat.is_eq(String.length(String.take(s, n)), n), Some{String.drop(s, n)}, None{})

def is_blank(s: String) -> Bool:
  String.is_empty(skip(~(c => is_sp(c) || is_nl(c)), s))

def trim_sp(s: String) -> String:
  String.reverse(skip(~(c => is_sp(c) || is_nl(c)), String.reverse(skip(~(c => is_sp(c) || is_nl(c)), s))))

# s holds p somewhere, ASCII case aside; p is lower case.
def has_ci(s: String, +p: String) -> Bool:
  String.contains(lower_s(s), p)

# ---- HTML output

def esc(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, t}:
      +c = {y : U32}
      +r = esc(t)
      Bool.pick(String, eq(c, 38), "&amp;" ++ r,
        Bool.pick(String, eq(c, 60), "&lt;" ++ r,
          Bool.pick(String, eq(c, 62), "&gt;" ++ r,
            Bool.pick(String, eq(c, 34), "&quot;" ++ r, SCon{Chr{c}, r}))))

def hexd(+n: U32) -> U32:
  Bool.pick(U32, U32.is_lt(n, 10), (n + 48 : U32), (n + 55 : U32))

def pct(+b: U32) -> String:
  SCon{'%', SCon{Chr{hexd((b >> 4n : U32))}, SCon{Chr{hexd((b .&. 15 : U32))}, SNil{}}}}

# Each UTF-8 octet of c as %XX.
def pct_utf8(+c: U32) -> String:
  +b1 = pct((192 + (c >> 6n) : U32)) ++ pct((128 + (c .&. 63) : U32))
  +b2 = pct((224 + (c >> 12n) : U32)) ++ pct((128 + ((c >> 6n) .&. 63) : U32)) ++ pct((128 + (c .&. 63) : U32))
  +b3 = pct((240 + (c >> 18n) : U32)) ++ pct((128 + ((c >> 12n) .&. 63) : U32)) ++ pct((128 + ((c >> 6n) .&. 63) : U32)) ++ pct((128 + (c .&. 63) : U32))
  Bool.pick(String, U32.is_lt(c, 128), pct(c), Bool.pick(String, U32.is_lt(c, 2048), b1, Bool.pick(String, U32.is_lt(c, 65536), b2, b3)))

def href_safe(+c: U32) -> Bool:
  is_alnum(c) || eq(c, 33) || within(c, 35, 47) || eq(c, 58) || eq(c, 59) || eq(c, 61) || eq(c, 63) || eq(c, 64) || eq(c, 95) || eq(c, 126)

# A URL for an href or src attribute: unsafe octets percent-encoded, & and ' as references.
def href(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, t}:
      +c = {y : U32}
      +r = href(t)
      Bool.pick(String, eq(c, 38), "&amp;" ++ r,
        Bool.pick(String, eq(c, 39), "&#x27;" ++ r,
          Bool.pick(String, href_safe(c), SCon{Chr{c}, r}, pct_utf8(c) ++ r)))

# ---- character references

def num.dec(s: String, acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{y}, t}:
      num.dec(t, (acc * 10 + (y - 48) : U32))

def hexv(+c: U32) -> U32:
  Bool.pick(U32, is_digit(c), (c - 48 : U32), (lower(c) - 87 : U32))

def num.hex(s: String, acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{y}, t}:
      num.hex(t, (acc * 16 + hexv(y) : U32))

def cp_ok(+n: U32) -> U32:
  Bool.pick(U32, eq(n, 0) || U32.is_gt(n, 1114111) || within(n, 55296, 57343), 65533, n)

def ent.num(+d: String, +rest: String, +lo: Nat, +hi: Nat, v: U32) -> Maybe<&2, Got>:
  +n = String.length(d)
  Bool.pick(Maybe<&2, Got>, Nat.is_le(lo, n) && Nat.is_le(n, hi) && eq(hd(rest), 59), Some{Got{one(cp_ok(v)), String.drop(rest, 1n)}}, None{})

def ent.named.go(m: Maybe<&2, String>, +rest: String) -> Maybe<&2, Got>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      Bool.pick(Maybe<&2, Got>, eq(hd(rest), 59), Some{Got{v, String.drop(rest, 1n)}}, None{})

def ent.named(r: String & String) -> Maybe<&2, Got>:
  (name, rest) = r
  ent.named.go(E.entity(name), rest)

def ent.hash(r: String & String) -> Maybe<&2, Got>:
  (+d, rest) = r
  ent.num(d, rest, 1n, 7n, num.dec(d, 0))

def ent.hex(r: String & String) -> Maybe<&2, Got>:
  (+d, rest) = r
  ent.num(d, rest, 1n, 6n, num.hex(d, 0))

def ent.sharp(+s: String) -> Maybe<&2, Got>:
  +x = hd(s)
  Bool.pick(Maybe<&2, Got>, eq(x, 120) || eq(x, 88), ent.hex(span(~(c => is_hex(c)), String.drop(s, 1n))), ent.hash(span(~(c => is_digit(c)), s)))

def ent.pick(sharp: Bool, +s: String) -> Maybe<&2, Got>:
  match sharp:
    case True{}:
      ent.sharp(String.drop(s, 1n))
    case False{}:
      ent.named(span(~(c => is_alnum(c)), s))

# s follows an &: the decoded reference and the text after its ;.
def ent(+s: String) -> Maybe<&2, Got>:
  ent.pick(eq(hd(s), 35), s)

# ---- backslash escapes and references in link parts

def unesc.ent(m: Maybe<&2, Got>, +y: U32, +t: String) -> Got:
  match m:
    case None{}:
      Got{one(y), t}
    case Some{g}:
      g

def unesc.amp(amp: Bool, +y: U32, +t: String) -> Got:
  match amp:
    case True{}:
      unesc.ent(ent(t), y, t)
    case False{}:
      Got{one(y), t}

# One step: the text the code point y (with t after it) stands for, and the rest.
def unesc.step(+y: U32, +t: String) -> Got:
  Bool.pick(Got, eq(y, 92) && is_apunct(hd(t)), Got{one(hd(t)), String.drop(t, 1n)}, unesc.amp(eq(y, 38), y, t))

def revapp(a: String, b: String) -> String:
  match a:
    case SNil{}:
      b
    case SCon{c, t}:
      revapp(t, SCon{c, b})

def unesc.go(f: Nat, g: Got, acc: String) -> String:
  match f:
    case 0n:
      String.reverse(acc)
    case 1n+h:
      match g:
        case Got{v, rest}:
          match rest:
            case SNil{}:
              String.reverse(revapp(v, acc))
            case SCon{Chr{y}, t}:
              unesc.go(h, unesc.step(y, t), revapp(v, acc))

# Backslash escapes and character references resolved.
def unesc(+s: String) -> String:
  unesc.go(1n+String.length(s), Got{SNil{}, s}, SNil{})

# A scanner's view of the next code point.
type Ch is Data:
  CEnd{}
  CBs{}
  COpen{}
  CClose{}
  CNl{}
  COther{}

def ch(+c: U32, +open: U32, +close: U32) -> Ch:
  Bool.pick(Ch, eq(c, 0), CEnd{},
    Bool.pick(Ch, eq(c, 92), CBs{},
      Bool.pick(Ch, eq(c, close), CClose{},
        Bool.pick(Ch, eq(c, open), COpen{},
          Bool.pick(Ch, eq(c, 10), CNl{}, COther{})))))

# The class of a code point after a backslash: never a delimiter.
def esc_ch(+c: U32) -> Ch:
  Bool.pick(Ch, eq(c, 0), CEnd{}, COther{})

def label.go(s: String, k: Ch, acc: String) -> Maybe<&2, Got>:
  match s:
    case SNil{}:
      None{}
    case SCon{c, +t}:
      match k:
        case CClose{}:
          Some{Got{String.reverse(acc), t}}
        case COpen{}:
          None{}
        case CBs{}:
          label.go(t, esc_ch(hd(t)), SCon{c, acc})
        case _:
          label.go(t, ch(hd(t), 91, 93), SCon{c, acc})

def label.ok(m: Maybe<&2, Got>) -> Maybe<&2, Got>:
  match m:
    case None{}:
      None{}
    case Some{Got{+v, r}}:
      Bool.pick(Maybe<&2, Got>, Nat.is_le(String.length(v), 999n) && Bool.not(is_blank(v)), Some{Got{v, r}}, None{})

# s follows a [: the raw label up to the matching ], and the text after the ].
def label(+s: String) -> Maybe<&2, Got>:
  label.ok(label.go(s, ch(hd(s), 91, 93), SNil{}))

def dest.lt.go(s: String, k: Ch, acc: String) -> Maybe<&2, Got>:
  match s:
    case SNil{}:
      None{}
    case SCon{c, +t}:
      match k:
        case CClose{}:
          Some{Got{String.reverse(acc), t}}
        case COpen{}:
          None{}
        case CNl{}:
          None{}
        case CEnd{}:
          None{}
        case CBs{}:
          dest.lt.go(t, esc_ch(hd(t)), SCon{c, acc})
        case COther{}:
          dest.lt.go(t, ch(hd(t), 60, 62), SCon{c, acc})

type Dk is Data:
  DStop{}
  DOpen{}
  DDec{}
  DBs{}
  DOther{}

def dk(+c: U32, +depth: U32) -> Dk:
  Bool.pick(Dk, U32.is_le(c, 32) || eq(c, 127), DStop{},
    Bool.pick(Dk, eq(c, 92), DBs{},
      Bool.pick(Dk, eq(c, 40), DOpen{},
        Bool.pick(Dk, eq(c, 41), Bool.pick(Dk, eq(depth, 0), DStop{}, DDec{}), DOther{}))))

def dest.go(s: String, k: Dk, +depth: U32, acc: String) -> Got & U32:
  match s:
    case SNil{}:
      (Got{String.reverse(acc), SNil{}}, depth)
    case SCon{c, +t}:
      match k:
        case DStop{}:
          (Got{String.reverse(acc), SCon{c, t}}, depth)
        case DOpen{}:
          dest.go(t, dk(hd(t), (depth + 1 : U32)), (depth + 1 : U32), SCon{c, acc})
        case DDec{}:
          dest.go(t, dk(hd(t), (depth - 1 : U32)), (depth - 1 : U32), SCon{c, acc})
        case DBs{}:
          dest.go(t, Bool.pick(Dk, U32.is_le(hd(t), 32), DStop{}, DOther{}), depth, SCon{c, acc})
        case DOther{}:
          dest.go(t, dk(hd(t), depth), depth, SCon{c, acc})

def dest.plain(r: Got & U32) -> Maybe<&2, Got>:
  (g, depth) = r
  match g:
    case Got{+v, rest}:
      Bool.pick(Maybe<&2, Got>, eq(depth, 0) && Bool.not(String.is_empty(v)), Some{Got{v, rest}}, None{})

def dest.pick(lt: Bool, +s: String) -> Maybe<&2, Got>:
  match lt:
    case True{}:
      +t = String.drop(s, 1n)
      dest.lt.go(t, ch(hd(t), 60, 62), SNil{})
    case False{}:
      dest.plain(dest.go(s, dk(hd(s), 0), 0, SNil{}))

# A link destination, raw: <...> or a run with balanced parentheses.
def dest(+s: String) -> Maybe<&2, Got>:
  dest.pick(eq(hd(s), 60), s)

def title.go(s: String, k: Ch, +open: U32, +close: U32, acc: String) -> Maybe<&2, Got>:
  match s:
    case SNil{}:
      None{}
    case SCon{c, +t}:
      match k:
        case CClose{}:
          Some{Got{String.reverse(acc), t}}
        case COpen{}:
          None{}
        case CEnd{}:
          None{}
        case CNl{}:
          Bool.pick(Maybe<&2, Got>, eq(hd(skip(~(x => is_sp(x)), t)), 10), None{}, title.go(t, ch(hd(t), open, close), open, close, SCon{c, acc}))
        case CBs{}:
          title.go(t, esc_ch(hd(t)), open, close, SCon{c, acc})
        case COther{}:
          title.go(t, ch(hd(t), open, close), open, close, SCon{c, acc})

def title.of(+q: U32, +s: String) -> Maybe<&2, Got>:
  +t = String.drop(s, 1n)
  +close = Bool.pick(U32, eq(q, 40), 41, q)
  +open = Bool.pick(U32, eq(q, 40), 40, 65535)
  title.go(t, ch(hd(t), open, close), open, close, SNil{})

# A link title, raw: "...", '...', or (...).
def title(+s: String) -> Maybe<&2, Got>:
  +q = hd(s)
  Bool.pick(Maybe<&2, Got>, eq(q, 34) || eq(q, 39) || eq(q, 40), title.of(q, s), None{})

# Spaces and tabs, with at most one line ending among them.
def ws1(+s: String) -> String:
  +a = skip(~(c => is_sp(c)), s)
  Bool.pick(String, eq(hd(a), 10), skip(~(c => is_sp(c)), String.drop(a, 1n)), a)

# The end of a line: spaces and tabs, then a line ending or the end of s.
def eol(+s: String) -> Maybe<&2, String>:
  +a = skip(~(c => is_sp(c)), s)
  +c = hd(a)
  Bool.pick(Maybe<&2, String>, eq(c, 0), Some{SNil{}}, Bool.pick(Maybe<&2, String>, eq(c, 10), Some{String.drop(a, 1n)}, None{}))

type Ref is Data:
  Ref{label: String, dest: String, title: Maybe<&2, String>}

# A parsed definition and the text after it.
type RefGot is Data:
  RefGot{ref: Ref, rest: String}

def norm.go(s: String, +ws: Bool, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+y}, t}:
      +w = is_sp(y) || is_nl(y)
      norm.go(t, w, Bool.pick(String, w && ws, acc, SCon{Chr{Bool.pick(U32, w, 32, y)}, acc}))

# A label for matching: case-folded, inner whitespace runs as one space, trimmed.
def norm(s: String) -> String:
  trim_sp(norm.go(U.fold(s), False{}, SNil{}))

def alt(a: Maybe<&2, RefGot>, b: Maybe<&2, RefGot>) -> Maybe<&2, RefGot>:
  match a:
    case Some{x}:
      Some{x}
    case None{}:
      b

def refdef.title(+lab: String, +d: String, tg: Got) -> Maybe<&2, RefGot>:
  match tg:
    case Got{v, r}:
      do Maybe<&2, RefGot>:
        after : String <- eol(r)
        return RefGot{Ref{norm(lab), unesc(d), Some{unesc(v)}}, after}

def refdef.titled(+lab: String, +d: String, +rest: String) -> Maybe<&2, RefGot>:
  +e = ws1(rest)
  do Maybe<&2, RefGot>:
    tg : Got <- Bool.pick(Maybe<&2, Got>, String.eq(e, rest), None{}, title(e))
    r : RefGot <- refdef.title(lab, d, tg)
    return r

def refdef.bare(+lab: String, +d: String, +rest: String) -> Maybe<&2, RefGot>:
  do Maybe<&2, RefGot>:
    after : String <- eol(rest)
    return RefGot{Ref{norm(lab), unesc(d), None{}}, after}

def refdef.dest(+lab: String, dg: Got) -> Maybe<&2, RefGot>:
  match dg:
    case Got{+d, +rest}:
      alt(refdef.titled(lab, d, rest), refdef.bare(lab, d, rest))

def refdef.label(lg: Got) -> Maybe<&2, RefGot>:
  match lg:
    case Got{+lab, rest}:
      do Maybe<&2, RefGot>:
        b : String <- lit(":", rest)
        dg : Got <- dest(ws1(b))
        r : RefGot <- refdef.dest(lab, dg)
        return r

# A link reference definition at the start of s.
def refdef(+s: String) -> Maybe<&2, RefGot>:
  do Maybe<&2, RefGot>:
    a : String <- lit("[", s)
    lg : Got <- label(a)
    r : RefGot <- refdef.label(lg)
    return r

# ---- raw HTML

def cut.go(+s: String, hit: Bool, +pat: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      None{}
    case SCon{c, t}:
      match hit:
        case True{}:
          Some{String.drop(SCon{c, t}, String.length(pat))}
        case False{}:
          cut.go(t, String.starts_with(t, pat), pat)

# The text after the first pat in s.
def cut(+s: String, +pat: String) -> Maybe<&2, String>:
  cut.go(s, String.starts_with(s, pat), pat)

def is_wsn(+c: U32) -> Bool:
  is_sp(c) || is_nl(c)

def wsp(+s: String) -> String:
  skip(~(c => is_wsn(c)), s)

def need(ok: Bool, +s: String) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, ok, Some{s}, None{})

def tagname(+s: String) -> Maybe<&2, String>:
  need(is_alpha(hd(s)), skip(~(c => is_alnum(c) || eq(c, 45)), s))

def attrname(+s: String) -> Maybe<&2, String>:
  +c = hd(s)
  need(is_alpha(c) || eq(c, 95) || eq(c, 58), skip(~(x => is_alnum(x) || eq(x, 95) || eq(x, 46) || eq(x, 58) || eq(x, 45)), s))

def unquoted(+c: U32) -> Bool:
  Bool.not(eq(c, 0) || is_wsn(c) || eq(c, 34) || eq(c, 39) || eq(c, 61) || eq(c, 60) || eq(c, 62) || eq(c, 96))

def attrval(+s: String) -> Maybe<&2, String>:
  +q = hd(s)
  Bool.pick(Maybe<&2, String>, eq(q, 34) || eq(q, 39), cut(String.drop(s, 1n), one(q)),
    need(unquoted(q), skip(~(c => unquoted(c)), s)))

def or(a: Maybe<&2, String>, b: Maybe<&2, String>) -> Maybe<&2, String>:
  match a:
    case Some{x}:
      Some{x}
    case None{}:
      b

def attr.value(+s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    a : String <- lit("=", wsp(s))
    b : String <- attrval(wsp(a))
    return b

def attr(+s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    a : String <- need(is_wsn(hd(s)), wsp(s))
    +b : String <- attrname(a)
    return Maybe.default(&2, String, attr.value(b), b)

def attrs.go(f: Nat, m: Maybe<&2, String>, +s: String) -> String:
  match f:
    case 0n:
      s
    case 1n+g:
      match m:
        case None{}:
          s
        case Some{+r}:
          attrs.go(g, attr(r), r)

def attrs(+s: String) -> String:
  attrs.go(String.length(s), attr(s), s)

def open_tag(+s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    a : String <- lit("<", s)
    b : String <- tagname(a)
    +c : String = wsp(attrs(b))
    d : String <- or(lit("/>", c), lit(">", c))
    return d

def close_tag(+s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    a : String <- lit("</", s)
    b : String <- tagname(a)
    c : String <- lit(">", wsp(b))
    return c

def comment(+s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    +a : String <- lit("<!--", s)
    b : String <- or(lit(">", a), or(lit("->", a), cut(a, "-->")))
    return b

def decl(+s: String) -> Maybe<&2, String>:
  do Maybe<&2, String>:
    +a : String <- lit("<!", s)
    b : String <- need(is_alpha(hd(a)), a)
    c : String <- cut(b, ">")
    return c

def cut.after(m: Maybe<&2, String>, +pat: String) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{r}:
      cut(r, pat)

# Raw inline HTML at the start of s: the text after it.
def raw_html(+s: String) -> Maybe<&2, String>:
  or(open_tag(s), or(close_tag(s), or(comment(s), or(cut.after(lit("<?", s), "?>"), or(cut.after(lit("<![CDATA[", s), "]]>"), decl(s))))))

# ---- blocks

type Mark is Data:
  KBul{c: U32}
  KOrd{d: U32}

# A block and whether the last line it took was blank, for tight and loose lists.
type Kid is Data:
  Kid{llb: Bool, b: Block}

type Block is Data:
  BPara{text: String}
  BHead{lv: U32, text: String}
  BCode{info: String, text: String}
  BHtml{text: String}
  BRule{}
  BQuote{kids: List<&2, Kid>}
  BItem{kind: Mark, start: U32, kids: List<&2, Kid>}
  BList{ord: Bool, start: U32, tight: Bool, items: List<&2, Kid>}

# An open container. kids are newest first.
type Frame is Data:
  FDoc{kids: List<&2, Kid>}
  FQuote{llb: Bool, kids: List<&2, Kid>}
  FItem{llb: Bool, kind: Mark, start: U32, pad: U32, line0: U32, kids: List<&2, Kid>}

# The open leaf of the innermost container. lines are newest first.
type Leaf is Data:
  LNone{}
  LPara{llb: Bool, lines: List<&2, String>}
  LCode{llb: Bool, lines: List<&2, String>}
  LFence{c: U32, n: U32, ind: U32, info: String, lines: List<&2, String>}
  LHtml{kind: U32, lines: List<&2, String>}

# The parser between lines. stack is innermost first and ends with FDoc.
type St is Data:
  St{stack: List<&2, Frame>, leaf: Leaf, refs: List<&2, Ref>, line: U32}

# The rest of a line and the column it starts at.
type Ln is Data:
  Ln{s: String, col: U32}

def same_kind(a: Mark, b: Mark) -> Bool:
  match a b:
    case KBul{x} KBul{y}:
      eq(x, y)
    case KOrd{x} KOrd{y}:
      eq(x, y)
    case _ _:
      False{}

def is_ord(k: Mark) -> Bool:
  match k:
    case KOrd{d}:
      True{}
    case KBul{c}:
      False{}

# Does the last of ks end with a blank line, looking into lists and items?
def ends(ks: List<&2, Kid>) -> Bool:
  match ks:
    case Nil{}:
      False{}
    case Con{Kid{l, BList{o, s, t, items}}, Nil{}}:
      l || ends(items)
    case Con{Kid{l, BItem{k, s, kids}}, Nil{}}:
      l || ends(kids)
    case Con{Kid{l, b}, Nil{}}:
      l
    case Con{k, rest}:
      ends(rest)

def loose.sub(ks: List<&2, Kid>, +next: Bool) -> Bool:
  match ks:
    case Nil{}:
      False{}
    case Con{+k, +rest}:
      (ends([k]) && (next || Bool.not(List.is_empty(&2, Kid, rest)))) || loose.sub(rest, next)

def loose(items: List<&2, Kid>) -> Bool:
  match items:
    case Nil{}:
      False{}
    case Con{Kid{l, BItem{k, s, ks}}, +rest}:
      +next = Bool.not(List.is_empty(&2, Kid, rest))
      (l && next) || loose.sub(ks, next) || loose(rest)
    case Con{k, rest}:
      loose(rest)

type G is Data:
  G{has: Bool, kind: Mark, start: U32, items: List<&2, Kid>, out: List<&2, Kid>}

def g_flush(g: G) -> List<&2, Kid>:
  match g:
    case G{has, kind, start, items, out}:
      match has:
        case False{}:
          out
        case True{}:
          +its = List.reverse(&2, Kid, items)
          Kid{False{}, BList{is_ord(kind), start, Bool.not(loose(its)), its}} <> out

def g_same(g: G, k: Mark) -> Bool:
  match g:
    case G{has, gk, gs, items, out}:
      has && same_kind(gk, k)

def group.item(same: Bool, g: G, +k: Kid, +kind: Mark, +start: U32) -> G:
  match same:
    case True{}:
      match g:
        case G{has, gk, gs, items, out}:
          G{has, gk, gs, k <> items, out}
    case False{}:
      G{True{}, kind, start, [k], g_flush(g)}

def group.step(+g: G, k: Kid) -> G:
  match k:
    case Kid{l, BItem{+kind, +start, ks}}:
      group.item(g_same(g, kind), g, Kid{l, BItem{kind, start, ks}}, kind, start)
    case _:
      G{False{}, KBul{0}, 0, Nil{}, k <> g_flush(g)}

def group.go(ks: List<&2, Kid>, +g: G) -> List<&2, Kid>:
  match ks:
    case Nil{}:
      List.reverse(&2, Kid, g_flush(g))
    case Con{k, rest}:
      group.go(rest, group.step(g, k))

# Runs of items of one kind become lists.
def group(ks: List<&2, Kid>) -> List<&2, Kid>:
  group.go(ks, G{False{}, KBul{0}, 0, Nil{}, Nil{}})

def push_kid(f: Frame, k: Kid) -> Frame:
  match f:
    case FDoc{ks}:
      FDoc{k <> ks}
    case FQuote{l, ks}:
      FQuote{l, k <> ks}
    case FItem{l, kind, s, pad, l0, ks}:
      FItem{l, kind, s, pad, l0, k <> ks}

def add_kid(stack: List<&2, Frame>, k: Kid) -> List<&2, Frame>:
  match stack:
    case Nil{}:
      Nil{}
    case Con{f, rest}:
      push_kid(f, k) <> rest

def join_rev(lines: List<&2, String>) -> String:
  String.join(List.reverse(&2, String, lines), "\n")

def drop_blank_lines(lines: List<&2, String>) -> List<&2, String>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{+l, +rest}:
      Bool.pick(List<&2, String>, is_blank(l), drop_blank_lines(rest), l <> rest)

def has_ref(refs: List<&2, Ref>, +label: String) -> Bool:
  match refs:
    case Nil{}:
      False{}
    case Con{Ref{l, d, t}, rest}:
      String.eq(l, label) || has_ref(rest, label)

# The first definition of a label wins.
def add_ref(+refs: List<&2, Ref>, r: Ref) -> List<&2, Ref>:
  match r:
    case Ref{+l, d, t}:
      Bool.pick(List<&2, Ref>, has_ref(refs, l), refs, Ref{l, d, t} <> refs)

def defs.go(f: Nat, m: Maybe<&2, RefGot>, +s: String, +refs: List<&2, Ref>) -> String & List<&2, Ref>:
  match f:
    case 0n:
      (s, refs)
    case 1n+g:
      match m:
        case None{}:
          (s, refs)
        case Some{RefGot{r, +rest}}:
          defs.go(g, refdef(rest), rest, add_ref(refs, r))

# The link reference definitions at the start of a paragraph, and the text after them.
def defs(+s: String, refs: List<&2, Ref>) -> String & List<&2, Ref>:
  defs.go(String.length(s), refdef(s), s, refs)

def para.close(+llb: Bool, r: String & List<&2, Ref>, +stack: List<&2, Frame>, +line: U32) -> St:
  (+rest, refs) = r
  St{Bool.pick(List<&2, Frame>, is_blank(rest), stack, add_kid(stack, Kid{llb, BPara{String.trim_end(rest)}})), LNone{}, refs, line}

def fence.body(+lines: List<&2, String>) -> String:
  Bool.pick(String, List.is_empty(&2, String, lines), "", join_rev(lines) ++ "\n")

def close_leaf(st: St) -> St:
  match st:
    case St{+stack, leaf, refs, +line}:
      match leaf:
        case LNone{}:
          St{stack, LNone{}, refs, line}
        case LPara{l, lines}:
          para.close(l, defs(join_rev(lines), refs), stack, line)
        case LCode{l, lines}:
          St{add_kid(stack, Kid{l, BCode{"", join_rev(drop_blank_lines(lines)) ++ "\n"}}), LNone{}, refs, line}
        case LFence{c, n, ind, info, lines}:
          St{add_kid(stack, Kid{False{}, BCode{unesc(info), fence.body(lines)}}), LNone{}, refs, line}
        case LHtml{k, lines}:
          St{add_kid(stack, Kid{False{}, BHtml{join_rev(lines)}}), LNone{}, refs, line}

def frame_kid(f: Frame) -> Kid:
  match f:
    case FDoc{ks}:
      Kid{False{}, BQuote{group(List.reverse(&2, Kid, ks))}}
    case FQuote{l, ks}:
      Kid{l, BQuote{group(List.reverse(&2, Kid, ks))}}
    case FItem{l, kind, s, pad, l0, ks}:
      Kid{l, BItem{kind, s, group(List.reverse(&2, Kid, ks))}}

# Closes the innermost container; its leaf must be closed.
def close_frame(st: St) -> St:
  match st:
    case St{stack, leaf, refs, line}:
      match stack:
        case Nil{}:
          St{Nil{}, leaf, refs, line}
        case Con{f, rest}:
          St{add_kid(rest, frame_kid(f)), leaf, refs, line}

def pop(n: Nat, st: St) -> St:
  match n:
    case 0n:
      st
    case 1n+m:
      pop(m, close_frame(st))

# ---- lines

def ln_s(ln: Ln) -> String:
  match ln:
    case Ln{s, col}:
      s

def ln_col(ln: Ln) -> U32:
  match ln:
    case Ln{s, col}:
      col

def tabw(+col: U32) -> U32:
  (4 - (col % 4) : U32)

def adv.w(+c: U32, +col: U32) -> U32:
  Bool.pick(U32, eq(c, 9), tabw(col), 1)

# go: s starts with a space or tab and n > 0. full: that character fits in n columns.
def adv.go(+s: String, go: Bool, full: Bool, +n: U32, +col: U32) -> Ln:
  match s:
    case SNil{}:
      Ln{SNil{}, col}
    case SCon{Chr{+y}, +t}:
      match go:
        case False{}:
          Ln{SCon{Chr{y}, t}, col}
        case True{}:
          match full:
            case True{}:
              +m = (n - adv.w(y, col) : U32)
              +c2 = (col + adv.w(y, col) : U32)
              adv.go(t, U32.is_gt(m, 0) && is_sp(hd(t)), U32.is_le(adv.w(hd(t), c2), m), m, c2)
            case False{}:
              Ln{String.repeat(" ", U32.to_nat((adv.w(y, col) - n : U32))) ++ t, (col + n : U32)}

# Consumes up to n columns of leading spaces and tabs. A tab it cuts leaves its other columns as spaces.
def adv(ln: Ln, +n: U32) -> Ln:
  match ln:
    case Ln{+s, +col}:
      adv.go(s, U32.is_gt(n, 0) && is_sp(hd(s)), U32.is_le(adv.w(hd(s), col), n), n, col)

def ns(ln: Ln) -> Ln:
  adv(ln, 4294967295)

# A line at the current container: the line, the line at its first non-space, the indent in columns, and blankness.
type Cx is Data:
  Cx{ln: Ln, at: Ln, ind: U32, blank: Bool}

def cx(+ln: Ln) -> Cx:
  +at = ns(ln)
  Cx{ln, at, (ln_col(at) - ln_col(ln) : U32), String.is_empty(ln_s(at))}

def cx_ln(c: Cx) -> Ln:
  match c:
    case Cx{ln, at, ind, blank}:
      ln

def cx_at(c: Cx) -> Ln:
  match c:
    case Cx{ln, at, ind, blank}:
      at

def cx_ind(c: Cx) -> U32:
  match c:
    case Cx{ln, at, ind, blank}:
      ind

def cx_blank(c: Cx) -> Bool:
  match c:
    case Cx{ln, at, ind, blank}:
      blank

# ---- block starts

type Hd is Data:
  Hd{lv: U32, text: String}

def atx.text(+t: String) -> String:
  +rev = String.reverse(t)
  +base = String.drop(rev, count(35, rev))
  Bool.pick(String, String.is_empty(base), "", Bool.pick(String, is_sp(hd(base)), String.trim_end(String.reverse(base)), t))

def atx.of(+n: Nat, +r: String) -> Maybe<&2, Hd>:
  Bool.pick(Maybe<&2, Hd>, Nat.is_le(1n, n) && Nat.is_le(n, 6n) && (eq(hd(r), 0) || is_sp(hd(r))), Some{Hd{U32.from_nat(n), atx.text(String.trim(r))}}, None{})

def atx(+s: String) -> Maybe<&2, Hd>:
  +n = count(35, s)
  atx.of(n, String.drop(s, n))

type Fg is Data:
  Fg{c: U32, n: U32, info: String}

def fence(+s: String) -> Maybe<&2, Fg>:
  +c = hd(s)
  +n = count(c, s)
  +info = String.trim(String.drop(s, n))
  Bool.pick(Maybe<&2, Fg>, (eq(c, 96) || eq(c, 126)) && Nat.is_ge(n, 3n) && Bool.not(eq(c, 96) && String.contains(info, "`")), Some{Fg{c, U32.from_nat(n), info}}, None{})

def close_fence(+s: String, +c: U32, +n: U32) -> Bool:
  +k = count(c, s)
  eq(hd(s), c) && Nat.is_ge(k, U32.to_nat(n)) && is_blank(String.drop(s, k))

def hr.go(s: String, +c: U32, +n: Nat) -> Bool:
  match s:
    case SNil{}:
      Nat.is_ge(n, 3n)
    case SCon{Chr{+y}, t}:
      (eq(y, c) || is_sp(y)) && hr.go(t, c, Bool.pick(Nat, eq(y, c), 1n+n, n))

def hr(+s: String) -> Bool:
  +c = hd(s)
  (eq(c, 42) || eq(c, 45) || eq(c, 95)) && hr.go(s, c, 0n)

# 1 for a = underline, 2 for -, 0 for neither.
def setext(+s: String) -> U32:
  +c = hd(s)
  +ok = (eq(c, 61) || eq(c, 45)) && is_blank(String.drop(s, count(c, s)))
  Bool.pick(U32, ok, Bool.pick(U32, eq(c, 61), 1, 2), 0)

# A list marker: its kind, start number, and width in characters.
type Im is Data:
  Im{kind: Mark, start: U32, w: U32}

def item.ord(+d: String, +r: String) -> Maybe<&2, Im>:
  +n = String.length(d)
  +c = hd(r)
  +nx = hd(String.drop(r, 1n))
  Bool.pick(Maybe<&2, Im>, Nat.is_le(1n, n) && Nat.is_le(n, 9n) && (eq(c, 46) || eq(c, 41)) && (eq(nx, 0) || is_sp(nx)), Some{Im{KOrd{c}, num.dec(d, 0), (U32.from_nat(n) + 1 : U32)}}, None{})

def item.of(r: String & String) -> Maybe<&2, Im>:
  (+d, +rest) = r
  item.ord(d, rest)

def item.scan(+s: String) -> Maybe<&2, Im>:
  +c = hd(s)
  +nx = hd(String.drop(s, 1n))
  Bool.pick(Maybe<&2, Im>, (eq(c, 45) || eq(c, 43) || eq(c, 42)) && (eq(nx, 0) || is_sp(nx)), Some{Im{KBul{c}, 0, 1}}, item.of(span(~(x => is_digit(x)), s)))

def blocknames() -> List<&2, String>:
  ["address", "article", "aside", "base", "basefont", "blockquote", "body", "caption", "center", "col", "colgroup", "dd", "details", "dialog", "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form", "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hr", "html", "iframe", "legend", "li", "link", "main", "menu", "menuitem", "nav", "noframes", "ol", "optgroup", "option", "p", "param", "search", "section", "summary", "table", "tbody", "td", "tfoot", "th", "thead", "title", "tr", "track", "ul"]

def member(xs: List<&2, String>, +n: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{x, rest}:
      String.eq(x, n) || member(rest, n)

def html6(+s: String) -> Bool:
  +a = Bool.pick(String, String.starts_with(s, "</"), String.drop(s, 2n), String.drop(s, 1n))
  +rest = snd(span(~(c => is_alnum(c)), a))
  +c = hd(rest)
  member(blocknames(), lower_s(fst(span(~(c => is_alnum(c)), a)))) && (eq(c, 0) || is_sp(c) || eq(c, 62) || String.starts_with(rest, "/>"))

def html1.one(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{r}:
      +c = hd(r)
      eq(c, 0) || is_sp(c) || eq(c, 62)

def html1(+s: String) -> Bool:
  html1.one(lit_ci("<script", s)) || html1.one(lit_ci("<pre", s)) || html1.one(lit_ci("<style", s)) || html1.one(lit_ci("<textarea", s))

def html7.ok(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{r}:
      is_blank(r)

def html_start.lt(lt: Bool, +s: String, +cpara: Bool) -> U32:
  match lt:
    case False{}:
      0
    case True{}:
      Bool.pick(U32, html1(s), 1,
        Bool.pick(U32, String.starts_with(s, "<!--"), 2,
          Bool.pick(U32, String.starts_with(s, "<?"), 3,
            Bool.pick(U32, String.starts_with(s, "<!") && is_alpha(hd(String.drop(s, 2n))), 4,
              Bool.pick(U32, String.starts_with(s, "<![CDATA["), 5,
                Bool.pick(U32, html6(s), 6,
                  Bool.pick(U32, Bool.not(cpara) && (html7.ok(open_tag(s)) || html7.ok(close_tag(s))), 7, 0)))))))

# The HTML block kind (1 to 7) that a line at s starts, or 0.
def html_start(+s: String, +cpara: Bool) -> U32:
  html_start.lt(eq(hd(s), 60), s, cpara)

def html_end(+k: U32, +s: String) -> Bool:
  Bool.pick(Bool, eq(k, 1), has_ci(s, "</script>") || has_ci(s, "</pre>") || has_ci(s, "</style>") || has_ci(s, "</textarea>"),
    Bool.pick(Bool, eq(k, 2), String.contains(s, "-->"),
      Bool.pick(Bool, eq(k, 3), String.contains(s, "?>"),
        Bool.pick(Bool, eq(k, 4), String.contains(s, ">"),
          Bool.pick(Bool, eq(k, 5), String.contains(s, "]]>"), False{})))))

# ---- continuation

def after_gt(at: Ln) -> Ln:
  match at:
    case Ln{s, +col}:
      adv(Ln{String.drop(s, 1n), (col + 1 : U32)}, 1)

def quote_cont(c: Cx) -> Maybe<&2, Ln>:
  match c:
    case Cx{ln, +at, +ind, blank}:
      Bool.pick(Maybe<&2, Ln>, U32.is_le(ind, 3) && eq(hd(ln_s(at)), 62), Some{after_gt(at)}, None{})

def item_cont(+hc: Bool, +pad: U32, c: Cx) -> Maybe<&2, Ln>:
  match c:
    case Cx{+ln, +at, +ind, +blank}:
      Bool.pick(Maybe<&2, Ln>, blank, Bool.pick(Maybe<&2, Ln>, hc, Some{at}, None{}), Bool.pick(Maybe<&2, Ln>, U32.is_ge(ind, pad), Some{adv(ln, pad)}, None{}))

# The line after f's own prefix, or None when f does not continue. hc: f has a child besides its kids.
def cont(f: Frame, c: Cx, +hc: Bool) -> Maybe<&2, Ln>:
  match f:
    case FDoc{ks}:
      Some{cx_ln(c)}
    case FQuote{l, ks}:
      quote_cont(c)
    case FItem{l, k, s, pad, l0, ks}:
      item_cont(hc || Bool.not(List.is_empty(&2, Kid, ks)), pad, c)

type W is Data:
  W{k: Nat, ln: Ln}

def walk.head(frames: List<&2, Frame>, +ln: Ln, +leafnone: Bool) -> Maybe<&2, Ln>:
  match frames:
    case Nil{}:
      None{}
    case Con{f, +rest}:
      cont(f, cx(ln), Bool.not(List.is_empty(&2, Frame, rest)) || Bool.not(leafnone))

# m is the head frame's continuation. k counts the frames that continued.
def walk(frames: List<&2, Frame>, m: Maybe<&2, Ln>, +ln: Ln, +k: Nat, +leafnone: Bool) -> W:
  match frames:
    case Nil{}:
      W{k, ln}
    case Con{f, +rest}:
      match m:
        case None{}:
          W{k, ln}
        case Some{+l2}:
          walk(rest, walk.head(rest, l2, leafnone), l2, 1n+k, leafnone)

type Lm is Data:
  LmNo{}
  LmPara{}
  LmLeaf{ln: Ln}
  LmEnd{}

def leaf_cont(leaf: Leaf, c: Cx) -> Lm:
  match leaf:
    case LNone{}:
      LmNo{}
    case LPara{l, ls}:
      Bool.pick(Lm, cx_blank(c), LmNo{}, LmPara{})
    case LCode{l, ls}:
      match c:
        case Cx{+ln, at, +ind, +blank}:
          Bool.pick(Lm, U32.is_ge(ind, 4), LmLeaf{adv(ln, 4)}, Bool.pick(Lm, blank, LmLeaf{at}, LmNo{}))
    case LFence{+fc, +fn, +find, info, ls}:
      match c:
        case Cx{+ln, +at, +ind, blank}:
          Bool.pick(Lm, U32.is_le(ind, 3) && close_fence(ln_s(at), fc, fn), LmEnd{}, LmLeaf{adv(ln, find)})
    case LHtml{+k, ls}:
      match c:
        case Cx{ln, at, ind, +blank}:
          Bool.pick(Lm, U32.is_ge(k, 6) && blank, LmNo{}, LmLeaf{ln})

# ---- one line

type Lk is Data:
  LkNone{}
  LkPara{}
  LkLeaf{}
  LkUn{}

# A line in progress. pops counts the containers it did not continue. tipp: the leaf was a paragraph when the line began.
type P is Data:
  P{st: St, ln: Ln, pops: Nat, lk: Lk, tipp: Bool}

type Sr is Data:
  SCont{p: P}
  SStop{p: P}
  SDone{st: St}

def p_ln(p: P) -> Ln:
  match p:
    case P{st, ln, pops, lk, tipp}:
      ln

def p_tipp(p: P) -> Bool:
  match p:
    case P{st, ln, pops, lk, tipp}:
      tipp

def p_cpara(p: P) -> Bool:
  match p:
    case P{st, ln, pops, lk, tipp}:
      match lk:
        case LkPara{}:
          True{}
        case _:
          False{}

def p_line(p: P) -> U32:
  match p:
    case P{St{stack, leaf, refs, line}, ln, pops, lk, tipp}:
      line

def push_frame(st: St, f: Frame) -> St:
  match st:
    case St{stack, leaf, refs, line}:
      St{f <> stack, leaf, refs, line}

def set_leaf(st: St, leaf: Leaf) -> St:
  match st:
    case St{stack, l, refs, line}:
      St{stack, leaf, refs, line}

def add_kid_st(st: St, k: Kid) -> St:
  match st:
    case St{stack, leaf, refs, line}:
      St{add_kid(stack, k), leaf, refs, line}

# Closes the containers, and the leaf, that the line did not continue.
def unmatched(p: P) -> P:
  match p:
    case P{st, ln, pops, lk, tipp}:
      match lk:
        case LkUn{}:
          P{pop(pops, close_leaf(st)), ln, 0n, LkNone{}, tipp}
        case _:
          P{pop(pops, st), ln, 0n, lk, tipp}

def prep.go(p: P) -> St:
  match p:
    case P{st, ln, pops, lk, tipp}:
      close_leaf(st)

# Ready for a new block: unmatched blocks closed, and the leaf closed.
def prep(p: P) -> St:
  prep.go(unmatched(p))

def try.code(+p: P, c: Cx) -> Sr:
  match c:
    case Cx{+ln, at, +ind, +blank}:
      Bool.pick(Sr, U32.is_ge(ind, 4) && Bool.not(p_tipp(p)) && Bool.not(blank), SDone{set_leaf(prep(p), LCode{False{}, [ln_s(adv(ln, 4))]})}, SStop{p})

def item.open(im: Im, +p: P, +c: Cx) -> Sr:
  match im:
    case Im{+kind, +start, +w}:
      +at = cx_at(c)
      +post = {Ln{String.drop(ln_s(at), U32.to_nat(w)), (ln_col(at) + w : U32)} : Ln}
      +pc = cx(post)
      +pb = cx_blank(pc)
      +used = Bool.pick(U32, pb || U32.is_ge(cx_ind(pc), 5), 1, cx_ind(pc))
      +ok = Bool.not(p_cpara(p)) || (Bool.not(pb) && (Bool.not(is_ord(kind)) || eq(start, 1)))
      +f = {FItem{False{}, kind, start, (cx_ind(c) + w + used : U32), p_line(p), Nil{}} : Frame}
      Bool.pick(Sr, ok, SCont{P{push_frame(prep(p), f), Bool.pick(Ln, pb, cx_at(pc), adv(post, used)), 0n, LkNone{}, p_tipp(p)}}, try.code(p, c))

def try.item(m: Maybe<&2, Im>, +p: P, +c: Cx) -> Sr:
  match m:
    case None{}:
      try.code(p, c)
    case Some{im}:
      item.open(im, p, c)

def try.hr(ok: Bool, +p: P, +c: Cx) -> Sr:
  match ok:
    case True{}:
      SDone{add_kid_st(prep(p), Kid{False{}, BRule{}})}
    case False{}:
      try.item(Bool.pick(Maybe<&2, Im>, U32.is_le(cx_ind(c), 3), item.scan(ln_s(cx_at(c))), None{}), p, c)

def setext.close(+lv: U32, r: String & List<&2, Ref>, +stack: List<&2, Frame>, +line: U32, +p: P) -> Sr:
  (+rest, +refs) = r
  Bool.pick(Sr, is_blank(rest), SCont{P{St{stack, LNone{}, refs, line}, p_ln(p), 0n, LkNone{}, p_tipp(p)}}, SDone{St{add_kid(stack, Kid{False{}, BHead{lv, String.trim(rest)}}), LNone{}, refs, line}})

def setext.apply(+lv: U32, +p: P) -> Sr:
  match p:
    case P{St{stack, leaf, refs, line}, ln, pops, lk, tipp}:
      match leaf:
        case LPara{l, lines}:
          setext.close(lv, defs(join_rev(lines), refs), stack, line, p)
        case _:
          SStop{p}

def try.setext(ok: Bool, +lv: U32, +p: P, +c: Cx) -> Sr:
  match ok:
    case True{}:
      setext.apply(lv, p)
    case False{}:
      try.hr(U32.is_le(cx_ind(c), 3) && hr(ln_s(cx_at(c))), p, c)

def html.open(+k: U32, +p: P, +c: Cx) -> Sr:
  +s = ln_s(cx_ln(c))
  +st = set_leaf(prep(p), LHtml{k, [s]})
  SDone{Bool.pick(St, U32.is_le(k, 5) && html_end(k, s), close_leaf(st), st)}

def try.html(+k: U32, +p: P, +c: Cx) -> Sr:
  +lv = setext(ln_s(cx_at(c)))
  Bool.pick(Sr, U32.is_gt(k, 0), html.open(k, p, c), try.setext(U32.is_le(cx_ind(c), 3) && p_cpara(p) && U32.is_gt(lv, 0), lv, p, c))

def try.fence(m: Maybe<&2, Fg>, +p: P, +c: Cx) -> Sr:
  match m:
    case Some{Fg{fc, fn, info}}:
      SDone{set_leaf(prep(p), LFence{fc, fn, cx_ind(c), info, Nil{}})}
    case None{}:
      try.html(Bool.pick(U32, U32.is_le(cx_ind(c), 3), html_start(ln_s(cx_at(c)), p_cpara(p)), 0), p, c)

def try.atx(m: Maybe<&2, Hd>, +p: P, +c: Cx) -> Sr:
  match m:
    case Some{Hd{lv, text}}:
      SDone{add_kid_st(prep(p), Kid{False{}, BHead{lv, text}})}
    case None{}:
      try.fence(Bool.pick(Maybe<&2, Fg>, U32.is_le(cx_ind(c), 3), fence(ln_s(cx_at(c))), None{}), p, c)

def try.quote(ok: Bool, +p: P, +c: Cx) -> Sr:
  match ok:
    case True{}:
      SCont{P{push_frame(prep(p), FQuote{False{}, Nil{}}), after_gt(cx_at(c)), 0n, LkNone{}, p_tipp(p)}}
    case False{}:
      try.atx(Bool.pick(Maybe<&2, Hd>, U32.is_le(cx_ind(c), 3), atx(ln_s(cx_at(c))), None{}), p, c)

def starts.try(+p: P) -> Sr:
  +c = cx(p_ln(p))
  try.quote(U32.is_le(cx_ind(c), 3) && eq(hd(ln_s(cx_at(c))), 62), p, c)

def starts.go(f: Nat, r: Sr) -> Sr:
  match f:
    case 0n:
      r
    case 1n+g:
      match r:
        case SCont{p}:
          starts.go(g, starts.try(p))
        case _:
          r

# ---- blank-line bookkeeping

def f_reset(f: Frame) -> Frame:
  match f:
    case FDoc{ks}:
      FDoc{ks}
    case FQuote{l, ks}:
      FQuote{False{}, ks}
    case FItem{l, k, s, pad, l0, ks}:
      FItem{False{}, k, s, pad, l0, ks}

def reset_all(stack: List<&2, Frame>) -> List<&2, Frame>:
  match stack:
    case Nil{}:
      Nil{}
    case Con{f, rest}:
      f_reset(f) <> reset_all(rest)

def kid_blank(ks: List<&2, Kid>) -> List<&2, Kid>:
  match ks:
    case Nil{}:
      Nil{}
    case Con{Kid{l, b}, rest}:
      Kid{True{}, b} <> rest

# A blank line went to f: its last child ends blank, and so does f unless it is a quote or an item that began on this line with no child.
def f_blank(f: Frame, +line: U32) -> Frame:
  match f:
    case FDoc{ks}:
      FDoc{kid_blank(ks)}
    case FQuote{l, ks}:
      FQuote{False{}, kid_blank(ks)}
    case FItem{l, k, s, pad, +l0, +ks}:
      FItem{Bool.not(List.is_empty(&2, Kid, ks) && eq(l0, line)), k, s, pad, l0, kid_blank(ks)}

def reset_llb(st: St) -> St:
  match st:
    case St{stack, leaf, refs, line}:
      St{reset_all(stack), leaf, refs, line}

def head_blank(st: St) -> St:
  match st:
    case St{stack, leaf, refs, +line}:
      match stack:
        case Nil{}:
          St{Nil{}, leaf, refs, line}
        case Con{f, rest}:
          St{f_blank(f, line) <> reset_all(rest), leaf, refs, line}

def leaf_llb(st: St, +blank: Bool) -> St:
  match st:
    case St{stack, leaf, refs, line}:
      match leaf:
        case LCode{l, ls}:
          St{reset_all(stack), LCode{blank, ls}, refs, line}
        case _:
          St{reset_all(stack), leaf, refs, line}

# ---- adding a line's text

def st_leaf(st: St) -> Leaf:
  match st:
    case St{stack, leaf, refs, line}:
      leaf

def leaf_none(leaf: Leaf) -> Bool:
  match leaf:
    case LNone{}:
      True{}
    case _:
      False{}

def leaf_para(leaf: Leaf) -> Bool:
  match leaf:
    case LPara{l, ls}:
      True{}
    case _:
      False{}

def leaf_add(st: St, +s: String) -> St:
  match st:
    case St{stack, leaf, refs, line}:
      match leaf:
        case LPara{l, ls}:
          St{stack, LPara{l, s <> ls}, refs, line}
        case LCode{l, ls}:
          St{stack, LCode{l, s <> ls}, refs, line}
        case LFence{c, n, ind, info, ls}:
          St{stack, LFence{c, n, ind, info, s <> ls}, refs, line}
        case LHtml{+k, ls}:
          +st2 = {St{stack, LHtml{k, s <> ls}, refs, line} : St}
          Bool.pick(St, U32.is_le(k, 5) && html_end(k, s), close_leaf(st2), st2)
        case LNone{}:
          St{stack, LPara{False{}, [s]}, refs, line}

def text.put(p: P, +c: Cx) -> St:
  match p:
    case P{+st, ln, pops, lk, tipp}:
      match lk:
        case LkPara{}:
          reset_llb(leaf_add(st, ln_s(cx_at(c))))
        case LkLeaf{}:
          leaf_llb(leaf_add(st, ln_s(ln)), cx_blank(c))
        case _:
          Bool.pick(St, cx_blank(c), head_blank(st), reset_llb(leaf_add(st, ln_s(cx_at(c)))))

def text.lazy(lazy: Bool, +p: P, +c: Cx) -> St:
  match lazy:
    case True{}:
      match p:
        case P{st, ln, pops, lk, tipp}:
          reset_llb(leaf_add(st, ln_s(cx_at(c))))
    case False{}:
      text.put(unmatched(p), c)

# The rest of a line after block starts: a lazy paragraph line, a leaf's line, a new paragraph, or a blank.
def text.add(+p: P) -> St:
  match p:
    case P{+st, +ln, +pops, lk, tipp}:
      +c = cx(ln)
      text.lazy(Nat.is_gt(pops, 0n) && Bool.not(cx_blank(c)) && leaf_para(st_leaf(st)), p, c)

# ---- one line, then the document

def line.fin(r: Sr) -> St:
  match r:
    case SCont{p}:
      text.add(p)
    case SStop{p}:
      text.add(p)
    case SDone{st}:
      reset_llb(st)

def line.run(p: P, +ln: Ln) -> St:
  line.fin(starts.go(Nat.add(String.length(ln_s(ln)), 2n), SCont{p}))

def line.lm(m: Lm, +st: St, +ln: Ln, +tipp: Bool) -> St:
  match m:
    case LmNo{}:
      line.run(P{st, ln, 0n, Bool.pick(Lk, leaf_none(st_leaf(st)), LkNone{}, LkUn{}), tipp}, ln)
    case LmPara{}:
      line.run(P{st, ln, 0n, LkPara{}, tipp}, ln)
    case LmLeaf{l2}:
      text.add(P{st, l2, 0n, LkLeaf{}, tipp})
    case LmEnd{}:
      reset_llb(close_leaf(st))

def line.pops(un: Bool, +pops: Nat, +st: St, +ln: Ln, +tipp: Bool) -> St:
  match un:
    case True{}:
      line.run(P{st, ln, pops, Bool.pick(Lk, leaf_none(st_leaf(st)), LkNone{}, LkUn{}), tipp}, ln)
    case False{}:
      line.lm(leaf_cont(st_leaf(st), cx(ln)), st, ln, tipp)

def line.walked(w: W, +st: St, +depth: Nat, +tipp: Bool) -> St:
  match w:
    case W{+k, +ln}:
      +pops = Nat.sub(depth, k)
      line.pops(Nat.is_gt(pops, 0n), pops, st, ln, tipp)

def line(st: St, raw: String) -> St:
  match st:
    case St{+stack, +leaf, refs, +n}:
      +frames = List.reverse(&2, Frame, stack)
      +ln = {Ln{raw, 0} : Ln}
      +none = leaf_none(leaf)
      line.walked(walk(frames, walk.head(frames, ln, none), ln, 0n, none), St{stack, leaf, refs, (n + 1 : U32)}, List.length(&2, Frame, stack), leaf_para(leaf))

def doc.go(lines: List<&2, String>, st: St) -> St:
  match lines:
    case Nil{}:
      st
    case Con{l, rest}:
      doc.go(rest, line(st, l))

def finish.doc(st: St) -> List<&2, Kid> & List<&2, Ref>:
  match st:
    case St{stack, leaf, refs, line}:
      match stack:
        case Con{FDoc{ks}, rest}:
          (group(List.reverse(&2, Kid, ks)), refs)
        case _:
          (Nil{}, refs)

def finish(st: St) -> List<&2, Kid> & List<&2, Ref>:
  match st:
    case St{+stack, leaf, refs, line}:
      finish.doc(pop(Nat.sub(List.length(&2, Frame, stack), 1n), close_leaf(St{stack, leaf, refs, line})))

def clean(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+y}, t}:
      SCon{Chr{Bool.pick(U32, eq(y, 0), 65533, y)}, clean(t)}

def drop_cr(+l: String) -> String:
  Bool.pick(String, String.ends_with(l, "\r"), String.take(l, Nat.sub(String.length(l), 1n)), l)

def lines.go(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+l, Nil{}}:
      Bool.pick(List<&2, String>, String.is_empty(l), Nil{}, [drop_cr(l)])
    case Con{l, rest}:
      drop_cr(l) <> lines.go(rest)

# The block tree and the link reference definitions of a document.
def blocks(s: String) -> List<&2, Kid> & List<&2, Ref>:
  finish(doc.go(lines.go(String.split(clean(s), '\n')), St{[FDoc{Nil{}}], LNone{}, Nil{}, 0}))

# ---- inlines

# An inline in progress. IHtml is finished output and its plain text, for image alt text.
type Inl is Data:
  IText{s: String}
  IHtml{html: String, plain: String}
  IDelim{c: U32, n: U32, orig: U32, open: Bool, close: Bool}
  IBrack{img: Bool, active: Bool, after: String}

def rep(+c: U32, n: U32) -> String:
  String.repeat(one(c), U32.to_nat(n))

def r.inl(xs: List<&2, Inl>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{IText{s}, rest}:
      esc(s) ++ r.inl(rest)
    case Con{IHtml{h, p}, rest}:
      h ++ r.inl(rest)
    case Con{IDelim{c, n, o, op, cl}, rest}:
      rep(c, n) ++ r.inl(rest)
    case Con{IBrack{img, a, af}, rest}:
      Bool.pick(String, img, "![", "[") ++ r.inl(rest)

def p.inl(xs: List<&2, Inl>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{IText{s}, rest}:
      s ++ p.inl(rest)
    case Con{IHtml{h, p}, rest}:
      p ++ p.inl(rest)
    case Con{IDelim{c, n, o, op, cl}, rest}:
      rep(c, n) ++ p.inl(rest)
    case Con{IBrack{img, a, af}, rest}:
      Bool.pick(String, img, "![", "[") ++ p.inl(rest)

# ---- emphasis

# A matching opener: the inlines after it (oldest first), the opener, and the stack below it.
type Fd is Data:
  Fd{above: List<&2, Inl>, c: U32, n: U32, o: U32, op: Bool, cl: Bool, below: List<&2, Inl>}

type Rs is Data:
  RDone{}
  RNone{}
  RFound{fd: Fd}

# Rule of three: a run that can both open and close matches only if the lengths do not sum to a multiple of 3, unless both are.
def odd_fail(+ocl: Bool, +o: U32, +copen: Bool, +orig: U32) -> Bool:
  (ocl || copen) && eq(((o + orig) % 3 : U32), 0) && Bool.not(eq((o % 3 : U32), 0) && eq((orig % 3 : U32), 0))

def find(stack: List<&2, Inl>, +c: U32, +orig: U32, +copen: Bool, +acc: List<&2, Inl>) -> Maybe<&2, Fd>:
  match stack:
    case Nil{}:
      None{}
    case Con{IDelim{+c2, +n2, +o2, +op2, +cl2}, +rest}:
      Bool.pick(Maybe<&2, Fd>, eq(c2, c) && op2 && Bool.not(odd_fail(cl2, o2, copen, orig)), Some{Fd{acc, c2, n2, o2, op2, cl2, rest}}, find(rest, c, orig, copen, IDelim{c2, n2, o2, op2, cl2} <> acc))
    case Con{x, rest}:
      find(rest, c, orig, copen, x <> acc)

def rs.of(m: Maybe<&2, Fd>) -> Rs:
  match m:
    case None{}:
      RNone{}
    case Some{fd}:
      RFound{fd}

def seek(more: Bool, stack: List<&2, Inl>, +c: U32, +orig: U32, +copen: Bool) -> Rs:
  match more:
    case False{}:
      RDone{}
    case True{}:
      rs.of(find(stack, c, orig, copen, Nil{}))

def wrap(+use: U32, +xs: List<&2, Inl>) -> Inl:
  +tag = Bool.pick(String, eq(use, 2), "strong", "em")
  +plain = p.inl(xs)
  IHtml{"<" ++ tag ++ ">" ++ r.inl(xs) ++ "</" ++ tag ++ ">", plain}

def keep(+n: U32, +c: U32, +o: U32, +op: Bool, +cl: Bool, +below: List<&2, Inl>) -> List<&2, Inl>:
  Bool.pick(List<&2, Inl>, eq(n, 0), below, IDelim{c, n, o, op, cl} <> below)

# Matches the closer, n long, against openers until it runs out or none is left.
def resolve(f: Nat, r: Rs, +stack: List<&2, Inl>, +c: U32, +n: U32, +orig: U32, +copen: Bool) -> List<&2, Inl>:
  match f:
    case 0n:
      stack
    case 1n+g:
      match r:
        case RDone{}:
          stack
        case RNone{}:
          Bool.pick(List<&2, Inl>, copen, IDelim{c, n, orig, copen, True{}} <> stack, IText{rep(c, n)} <> stack)
        case RFound{Fd{above, c2, +n2, o2, op2, cl2, below}}:
          +use = Bool.pick(U32, U32.is_ge(n, 2) && U32.is_ge(n2, 2), 2, 1)
          +st2 = {wrap(use, above) <> keep((n2 - use : U32), c2, o2, op2, cl2, below) : List<&2, Inl>}
          +nr = (n - use : U32)
          resolve(g, seek(U32.is_gt(nr, 0), st2, c, orig, copen), st2, c, nr, orig, copen)

def emph.delim(cl: Bool, +stack: List<&2, Inl>, +c: U32, +n: U32, +o: U32, +op: Bool) -> List<&2, Inl>:
  match cl:
    case False{}:
      IDelim{c, n, o, op, False{}} <> stack
    case True{}:
      resolve(1n+U32.to_nat(n), seek(True{}, stack, c, o, op), stack, c, n, o, op)

def emph.go(xs: List<&2, Inl>, +stack: List<&2, Inl>) -> List<&2, Inl>:
  match xs:
    case Nil{}:
      List.reverse(&2, Inl, stack)
    case Con{IDelim{c, n, o, op, cl}, rest}:
      emph.go(rest, emph.delim(cl, stack, c, n, o, op))
    case Con{x, rest}:
      emph.go(rest, x <> stack)

# Emphasis and strong emphasis, by the delimiter run rules.
def emph(xs: List<&2, Inl>) -> List<&2, Inl>:
  emph.go(xs, Nil{})

# ---- inline scanner

type Is is Data:
  Is{s: String, prev: U32, buf: String, out: List<&2, Inl>}

def flush(+buf: String, +out: List<&2, Inl>) -> List<&2, Inl>:
  Bool.pick(List<&2, Inl>, String.is_empty(buf), out, IText{String.reverse(buf)} <> out)

def tick.go(s: String, hit: Bool, +run: Nat, +n: Nat, acc: String) -> Maybe<&2, Got>:
  match s:
    case SNil{}:
      match hit:
        case True{}:
          Some{Got{String.reverse(String.drop(acc, n)), SNil{}}}
        case False{}:
          None{}
    case SCon{Chr{+y}, +t}:
      match hit:
        case True{}:
          Some{Got{String.reverse(String.drop(acc, n)), SCon{Chr{y}, t}}}
        case False{}:
          +r2 = Bool.pick(Nat, eq(y, 96), 1n+run, 0n)
          tick.go(t, Bool.not(eq(hd(t), 96)) && Nat.is_eq(r2, n), r2, n, SCon{Chr{y}, acc})

def cnl(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+y}, t}:
      SCon{Chr{Bool.pick(U32, eq(y, 10), 32, y)}, cnl(t)}

# Code span text: line endings as spaces, and one space stripped from each end when both ends have one.
def cnorm(+s: String) -> String:
  +strip = String.starts_with(s, " ") && String.ends_with(s, " ") && Bool.not(String.is_empty(skip(~(c => eq(c, 32)), s)))
  Bool.pick(String, strip, String.take(String.drop(s, 1n), Nat.sub(String.length(s), 2n)), s)

def code.got(m: Maybe<&2, Got>, +ticks: Nat, +after: String, +buf: String, out: List<&2, Inl>) -> Is:
  match m:
    case None{}:
      Is{after, 96, revapp(String.repeat("`", ticks), buf), out}
    case Some{Got{v, rest}}:
      +x = cnorm(cnl(v))
      Is{rest, 96, SNil{}, IHtml{"<code>" ++ esc(x) ++ "</code>", x} <> flush(buf, out)}

def code(+s: String, +buf: String, out: List<&2, Inl>) -> Is:
  +n = count(96, s)
  +after = String.drop(s, n)
  code.got(tick.go(after, False{}, 0n, n, SNil{}), n, after, buf, out)

def scheme_ch(+c: U32) -> Bool:
  is_alnum(c) || eq(c, 43) || eq(c, 46) || eq(c, 45)

def uri_ch(+c: U32) -> Bool:
  U32.is_gt(c, 32) && Bool.not(eq(c, 60) || eq(c, 62) || eq(c, 127))

def auto.uri(+t: String) -> Maybe<&2, Got>:
  +sch = fst(span(~(c => scheme_ch(c)), t))
  +k = String.length(sch)
  +a = String.drop(t, k)
  +body = fst(span(~(c => uri_ch(c)), String.drop(a, 1n)))
  +rest = String.drop(a, Nat.add(1n, String.length(body)))
  Bool.pick(Maybe<&2, Got>, is_alpha(hd(t)) && Nat.is_le(2n, k) && Nat.is_le(k, 32n) && eq(hd(a), 58) && eq(hd(rest), 62), Some{Got{sch ++ ":" ++ body, String.drop(rest, 1n)}}, None{})

def email_ch(+c: U32) -> Bool:
  is_alnum(c) || eq(c, 46) || eq(c, 33) || within(c, 35, 39) || eq(c, 42) || eq(c, 43) || eq(c, 47) || eq(c, 61) || eq(c, 63) || within(c, 94, 96) || within(c, 123, 126) || eq(c, 45)

def dom_ch(+c: U32) -> Bool:
  is_alnum(c) || eq(c, 45) || eq(c, 46)

def dom.parts(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+p, rest}:
      +n = String.length(p)
      Nat.is_le(1n, n) && Nat.is_le(n, 63n) && Bool.not(eq(hd(p), 45)) && Bool.not(eq(hd(String.reverse(p)), 45)) && dom.parts(rest)

def dom_ok(+d: String) -> Bool:
  +parts = String.split(d, '.')
  Bool.not(String.is_empty(d)) && dom.parts(parts)

def auto.email(+t: String) -> Maybe<&2, Got>:
  +local = fst(span(~(c => email_ch(c)), t))
  +a = String.drop(t, String.length(local))
  +dom = fst(span(~(c => dom_ch(c)), String.drop(a, 1n)))
  +rest = String.drop(a, Nat.add(1n, String.length(dom)))
  Bool.pick(Maybe<&2, Got>, Bool.not(String.is_empty(local)) && eq(hd(a), 64) && dom_ok(dom) && eq(hd(rest), 62), Some{Got{local ++ "@" ++ dom, String.drop(rest, 1n)}}, None{})

def lt.html(m: Maybe<&2, String>, +s: String, +buf: String, out: List<&2, Inl>) -> Is:
  match m:
    case None{}:
      Is{String.drop(s, 1n), 60, SCon{'<', buf}, out}
    case Some{+rest}:
      +raw = String.take(s, Nat.sub(String.length(s), String.length(rest)))
      Is{rest, 62, SNil{}, IHtml{raw, raw} <> flush(buf, out)}

def lt.email(m: Maybe<&2, Got>, +s: String, +buf: String, out: List<&2, Inl>) -> Is:
  match m:
    case Some{Got{+v, rest}}:
      Is{rest, 62, SNil{}, IHtml{"<a href=\"mailto:" ++ href(v) ++ "\">" ++ esc(v) ++ "</a>", v} <> flush(buf, out)}
    case None{}:
      lt.html(raw_html(s), s, buf, out)

def lt.uri(m: Maybe<&2, Got>, +s: String, +buf: String, out: List<&2, Inl>) -> Is:
  match m:
    case Some{Got{+v, rest}}:
      Is{rest, 62, SNil{}, IHtml{"<a href=\"" ++ href(v) ++ "\">" ++ esc(v) ++ "</a>", v} <> flush(buf, out)}
    case None{}:
      lt.email(auto.email(String.drop(s, 1n)), s, buf, out)

def amp.got(m: Maybe<&2, Got>, +t: String, buf: String, out: List<&2, Inl>) -> Is:
  match m:
    case None{}:
      Is{t, 38, SCon{'&', buf}, out}
    case Some{Got{v, rest}}:
      Is{rest, 59, revapp(v, buf), out}

# Trailing spaces before a line ending: two or more make a hard break.
def nl(+t: String, +buf: String, out: List<&2, Inl>) -> Is:
  +k = count(32, buf)
  +b2 = String.drop(buf, k)
  Is{skip(~(c => is_sp(c)), t), 10, SNil{}, IHtml{Bool.pick(String, Nat.is_ge(k, 2n), "<br />\n", "\n"), "\n"} <> flush(b2, out)}

def bs(+t: String, +buf: String, +out: List<&2, Inl>) -> Is:
  +x = hd(t)
  Bool.pick(Is, is_apunct(x), Is{String.drop(t, 1n), x, SCon{Chr{x}, buf}, out},
    Bool.pick(Is, eq(x, 10), Is{skip(~(c => is_sp(c)), String.drop(t, 1n)), 10, SNil{}, IHtml{"<br />\n", "\n"} <> flush(buf, out)},
      Is{t, 92, SCon{'\\', buf}, out}))

def delim(+c: U32, +s: String, +prev: U32, +buf: String, out: List<&2, Inl>) -> Is:
  +n = count(c, s)
  +rest = String.drop(s, n)
  +nx = hd(rest)
  +left = Bool.not(is_uws(nx)) && (Bool.not(is_punct(nx)) || is_uws(prev) || is_punct(prev))
  +right = Bool.not(is_uws(prev)) && (Bool.not(is_punct(prev)) || is_uws(nx) || is_punct(nx))
  +star = eq(c, 42)
  +op = Bool.pick(Bool, star, left, left && (Bool.not(right) || is_punct(prev)))
  +cl = Bool.pick(Bool, star, right, right && (Bool.not(left) || is_punct(nx)))
  +k = U32.from_nat(n)
  Is{rest, c, SNil{}, IDelim{c, k, k, op, cl} <> flush(buf, out)}

# ---- links

# Splits the output at its newest bracket: the inlines after it (oldest first), the bracket, and the rest.
type Bk is Data:
  Bk{above: List<&2, Inl>, img: Bool, active: Bool, after: String, below: List<&2, Inl>}

def brk(out: List<&2, Inl>, acc: List<&2, Inl>) -> Maybe<&2, Bk>:
  match out:
    case Nil{}:
      None{}
    case Con{IBrack{img, a, af}, rest}:
      Some{Bk{acc, img, a, af, rest}}
    case Con{x, rest}:
      brk(rest, x <> acc)

def deact(xs: List<&2, Inl>) -> List<&2, Inl>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{IBrack{False{}, a, af}, rest}:
      IBrack{False{}, False{}, af} <> deact(rest)
    case Con{x, rest}:
      x <> deact(rest)

type Lt is Data:
  Lt{dest: String, title: Maybe<&2, String>, rest: String}

def find_ref(refs: List<&2, Ref>, +label: String) -> Maybe<&2, Ref>:
  match refs:
    case Nil{}:
      None{}
    case Con{Ref{+l, d, t}, rest}:
      Bool.pick(Maybe<&2, Ref>, String.eq(l, label), Some{Ref{l, d, t}}, find_ref(rest, label))

def lookup.got(m: Maybe<&2, Ref>, +rest: String) -> Maybe<&2, Lt>:
  match m:
    case None{}:
      None{}
    case Some{Ref{l, d, t}}:
      Some{Lt{d, t, rest}}

def lookup(+refs: List<&2, Ref>, +raw: String, +rest: String) -> Maybe<&2, Lt>:
  lookup.got(Bool.pick(Maybe<&2, Ref>, Nat.is_le(String.length(raw), 999n) && Bool.not(is_blank(raw)), find_ref(refs, norm(raw)), None{}), rest)

def ref.full(m: Maybe<&2, Got>, +t: String, +raw: String, +refs: List<&2, Ref>) -> Maybe<&2, Lt>:
  match m:
    case Some{Got{lab, rest}}:
      lookup(refs, lab, rest)
    case None{}:
      Bool.pick(Maybe<&2, Lt>, String.starts_with(t, "[]"), lookup(refs, raw, String.drop(t, 2n)), lookup(refs, raw, t))

def ref.tail(+t: String, +raw: String, +refs: List<&2, Ref>) -> Maybe<&2, Lt>:
  ref.full(Bool.pick(Maybe<&2, Got>, eq(hd(t), 91), label(String.drop(t, 1n)), None{}), t, raw, refs)

def inl.close.of(+d: String, v: String, m: Maybe<&2, String>) -> Maybe<&2, Lt>:
  match m:
    case None{}:
      None{}
    case Some{e}:
      Some{Lt{d, Some{unesc(v)}, e}}

def inl.close(+d: String, tg: Got) -> Maybe<&2, Lt>:
  match tg:
    case Got{v, rest}:
      inl.close.of(d, v, lit(")", wsp(rest)))

def inl.title(+d: String, +c: String) -> Maybe<&2, Lt>:
  do Maybe<&2, Lt>:
    tg : Got <- title(c)
    r : Lt <- inl.close(d, tg)
    return r

def inl.dest(+d: String, +r: String) -> Maybe<&2, Lt>:
  +c = wsp(r)
  Bool.pick(Maybe<&2, Lt>, eq(hd(c), 41), Some{Lt{d, None{}, String.drop(c, 1n)}}, Bool.pick(Maybe<&2, Lt>, String.eq(c, r), None{}, inl.title(d, c)))

def inl.got(m: Maybe<&2, Got>) -> Maybe<&2, Lt>:
  match m:
    case None{}:
      None{}
    case Some{Got{d, r}}:
      inl.dest(unesc(d), r)

def inl.open(+b: String) -> Maybe<&2, Lt>:
  Bool.pick(Maybe<&2, Lt>, eq(hd(b), 41), Some{Lt{SNil{}, None{}, String.drop(b, 1n)}}, inl.got(dest(b)))

# An inline link's (destination "title").
def inl.tail(+t: String) -> Maybe<&2, Lt>:
  Bool.pick(Maybe<&2, Lt>, eq(hd(t), 40), inl.open(wsp(String.drop(t, 1n))), None{})

def lt_or(a: Maybe<&2, Lt>, b: Maybe<&2, Lt>) -> Maybe<&2, Lt>:
  match a:
    case Some{x}:
      Some{x}
    case None{}:
      b

def title_attr(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{t}:
      " title=\"" ++ esc(t) ++ "\""

def link.make(lt: Lt, xs: List<&2, Inl>, +img: Bool, +below: List<&2, Inl>) -> Is:
  match lt:
    case Lt{d, +t, +rest}:
      +ys = emph(xs)
      +plain = p.inl(ys)
      +u = href(d)
      Bool.pick(Is, img,
        Is{rest, 93, SNil{}, IHtml{"<img src=\"" ++ u ++ "\" alt=\"" ++ esc(plain) ++ "\"" ++ title_attr(t) ++ " />", plain} <> below},
        Is{rest, 93, SNil{}, IHtml{"<a href=\"" ++ u ++ "\"" ++ title_attr(t) ++ ">" ++ r.inl(ys) ++ "</a>", plain} <> deact(below)})

def link.fail(above: List<&2, Inl>, +img: Bool, below: List<&2, Inl>, +t: String) -> Is:
  Is{t, 93, SCon{']', SNil{}}, List.append(&2, Inl, List.reverse(&2, Inl, above), IText{Bool.pick(String, img, "![", "[")} <> below)}

def link.try(m: Maybe<&2, Lt>, above: List<&2, Inl>, +img: Bool, below: List<&2, Inl>, +t: String) -> Is:
  match m:
    case Some{lt}:
      link.make(lt, above, img, below)
    case None{}:
      link.fail(above, img, below, t)

def close.br(m: Maybe<&2, Bk>, +t: String, +out: List<&2, Inl>, +refs: List<&2, Ref>) -> Is:
  match m:
    case None{}:
      Is{t, 93, SCon{']', SNil{}}, out}
    case Some{Bk{above, +img, active, +after, below}}:
      match active:
        case False{}:
          link.fail(above, img, below, t)
        case True{}:
          +raw = String.take(after, Nat.sub(Nat.sub(String.length(after), String.length(t)), 1n))
          link.try(lt_or(inl.tail(t), ref.tail(t, raw, refs)), above, img, below, t)

# ---- the scanner loop

type Ic is Data:
  IcBs{}
  IcTick{}
  IcStar{}
  IcOpen{}
  IcBang{}
  IcClose{}
  IcLt{}
  IcAmp{}
  IcNl{}
  IcOther{}

def ic(+c: U32, +nx: U32) -> Ic:
  Bool.pick(Ic, eq(c, 92), IcBs{},
    Bool.pick(Ic, eq(c, 96), IcTick{},
      Bool.pick(Ic, eq(c, 42) || eq(c, 95), IcStar{},
        Bool.pick(Ic, eq(c, 91), IcOpen{},
          Bool.pick(Ic, eq(c, 33) && eq(nx, 91), IcBang{},
            Bool.pick(Ic, eq(c, 93), IcClose{},
              Bool.pick(Ic, eq(c, 60), IcLt{},
                Bool.pick(Ic, eq(c, 38), IcAmp{},
                  Bool.pick(Ic, eq(c, 10), IcNl{}, IcOther{})))))))))

def istep(k: Ic, +y: U32, +t: String, +prev: U32, +buf: String, +out: List<&2, Inl>, +refs: List<&2, Ref>) -> Is:
  match k:
    case IcOther{}:
      Is{t, y, SCon{Chr{y}, buf}, out}
    case IcBs{}:
      bs(t, buf, out)
    case IcTick{}:
      code(SCon{Chr{y}, t}, buf, out)
    case IcStar{}:
      delim(y, SCon{Chr{y}, t}, prev, buf, out)
    case IcOpen{}:
      Is{t, 91, SNil{}, IBrack{False{}, True{}, t} <> flush(buf, out)}
    case IcBang{}:
      Is{String.drop(t, 1n), 91, SNil{}, IBrack{True{}, True{}, String.drop(t, 1n)} <> flush(buf, out)}
    case IcClose{}:
      close.br(brk(flush(buf, out), Nil{}), t, flush(buf, out), refs)
    case IcLt{}:
      lt.uri(auto.uri(t), SCon{Chr{y}, t}, buf, out)
    case IcAmp{}:
      amp.got(ent(t), t, buf, out)
    case IcNl{}:
      nl(t, buf, out)

def inl.go(f: Nat, st: Is, +refs: List<&2, Ref>) -> List<&2, Inl>:
  match f:
    case 0n:
      Nil{}
    case 1n+g:
      match st:
        case Is{s, prev, buf, out}:
          match s:
            case SNil{}:
              List.reverse(&2, Inl, flush(buf, out))
            case SCon{Chr{+y}, +t}:
              inl.go(g, istep(ic(y, hd(t)), y, t, prev, buf, out, refs), refs)

# A paragraph or heading's text as HTML.
def inline(+s: String, +refs: List<&2, Ref>) -> String:
  r.inl(emph(inl.go(Nat.add(String.length(s), 2n), Is{s, 10, SNil{}, Nil{}}, refs)))

# ---- HTML

def cr(+out: String) -> String:
  Bool.pick(String, String.is_empty(out) || eq(hd(out), 10), out, SCon{'\n', out})

def put(s: String, out: String) -> String:
  revapp(s, out)

def code_open(+info: String) -> String:
  +lang = fst(span(~(c => Bool.not(is_sp(c) || eq(c, 0))), info))
  Bool.pick(String, String.is_empty(info), "<pre><code>", "<pre><code class=\"language-" ++ esc(lang) ++ "\">")

def list_open(+ord: Bool, +start: U32) -> String:
  Bool.pick(String, ord, Bool.pick(String, eq(start, 1), "<ol>\n", "<ol start=\"" ++ U32.show(start) ++ "\">\n"), "<ul>\n")

# out is reversed. tight: these kids are the children of an item in a tight list.
def r.go(ks: List<&2, Kid>, +tight: Bool, +refs: List<&2, Ref>, +out: String) -> String:
  match ks:
    case Nil{}:
      out
    case Con{Kid{l, BPara{t}}, rest}:
      +h = inline(t, refs)
      r.go(rest, tight, refs, Bool.pick(String, tight, put(h, out), put("</p>\n", put(h, put("<p>", cr(out))))))
    case Con{Kid{l, BHead{+lv, t}}, rest}:
      r.go(rest, tight, refs, put(">\n", put(U32.show(lv), put("</h", put(inline(t, refs), put(">", put(U32.show(lv), put("<h", cr(out)))))))))
    case Con{Kid{l, BCode{info, t}}, rest}:
      r.go(rest, tight, refs, put("</code></pre>\n", put(esc(t), put(code_open(info), cr(out)))))
    case Con{Kid{l, BHtml{t}}, rest}:
      r.go(rest, tight, refs, cr(put(t, cr(out))))
    case Con{Kid{l, BRule{}}, rest}:
      r.go(rest, tight, refs, put("<hr />\n", cr(out)))
    case Con{Kid{l, BQuote{inner}}, rest}:
      r.go(rest, tight, refs, put("</blockquote>\n", cr(r.go(inner, False{}, refs, put("<blockquote>\n", cr(out))))))
    case Con{Kid{l, BList{+ord, start, lt, items}}, rest}:
      r.go(rest, tight, refs, put(Bool.pick(String, ord, "</ol>\n", "</ul>\n"), r.go(items, lt, refs, put(list_open(ord, start), cr(out)))))
    case Con{Kid{l, BItem{k, s, inner}}, rest}:
      r.go(rest, tight, refs, put("</li>\n", r.go(inner, tight, refs, put("<li>", cr(out)))))

def render(r: List<&2, Kid> & List<&2, Ref>) -> String:
  (ks, refs) = r
  String.reverse(r.go(ks, False{}, refs, SNil{}))

# CommonMark to HTML.
def to_html(s: String) -> String:
  render(blocks(s))
