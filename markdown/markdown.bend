# CommonMark 0.31.2: Markdown to HTML.
import Base
import bend-kit-unicode@0.1.0.0/unicode.bend as U
import ./entities.bend as E

# Bool.pick evaluates both branches; when evaluates only the chosen one.
def when(-A: Type, c: Bool, t: Unit -> A, e: Unit -> A) -> A:
  match c:
    case True{}:
      t(Unit{})
    case False{}:
      e(Unit{})

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

def esc.pick(amp: Bool, lt: Bool, gt: Bool, quot: Bool, c: Char, rest: String) -> String:
  match amp:
    case True{}:
      "&amp;" ++ rest
    case False{}:
      match lt:
        case True{}:
          "&lt;" ++ rest
        case False{}:
          match gt:
            case True{}:
              "&gt;" ++ rest
            case False{}:
              match quot:
                case True{}:
                  "&quot;" ++ rest
                case False{}:
                  SCon{c, rest}

def esc(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, t}:
      +c = {y : U32}
      esc.pick(eq(c, 38), eq(c, 60), eq(c, 62), eq(c, 34), Chr{c}, esc(t))

def hexd(+n: U32) -> U32:
  Bool.pick(U32, U32.is_lt(n, 10), (n + 48 : U32), (n + 55 : U32))

def pct(+b: U32) -> String:
  SCon{'%', SCon{Chr{hexd((b >> 4n : U32))}, SCon{Chr{hexd((b .&. 15 : U32))}, SNil{}}}}

# Each UTF-8 octet of c as %XX.
def pct_utf8(+c: U32) -> String:
  when(String, U32.is_lt(c, 128), u => pct(c), u => when(String, U32.is_lt(c, 2048),
    v => pct((192 + (c >> 6n) : U32)) ++ pct((128 + (c .&. 63) : U32)),
    v => when(String, U32.is_lt(c, 65536),
      w => pct((224 + (c >> 12n) : U32)) ++ pct((128 + ((c >> 6n) .&. 63) : U32)) ++ pct((128 + (c .&. 63) : U32)),
      w => pct((240 + (c >> 18n) : U32)) ++ pct((128 + ((c >> 12n) .&. 63) : U32)) ++ pct((128 + ((c >> 6n) .&. 63) : U32)) ++ pct((128 + (c .&. 63) : U32)))))

def href_safe(+c: U32) -> Bool:
  is_alnum(c) || eq(c, 33) || within(c, 35, 47) || eq(c, 58) || eq(c, 59) || eq(c, 61) || eq(c, 63) || eq(c, 64) || eq(c, 95) || eq(c, 126)

def href.pick(amp: Bool, apos: Bool, safe: Bool, +c: U32, rest: String) -> String:
  match amp:
    case True{}:
      "&amp;" ++ rest
    case False{}:
      match apos:
        case True{}:
          "&#x27;" ++ rest
        case False{}:
          match safe:
            case True{}:
              SCon{Chr{c}, rest}
            case False{}:
              pct_utf8(c) ++ rest

# A URL for an href or src attribute: unsafe octets percent-encoded, & and ' as references.
def href(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, t}:
      +c = {y : U32}
      href.pick(eq(c, 38), eq(c, 39), href_safe(c), c, href(t))

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

def cut.go(+s: String, hit: Bool, +pat: String, +n: Nat) -> Maybe<&2, Nat>:
  match s:
    case SNil{}:
      None{}
    case SCon{c, t}:
      match hit:
        case True{}:
          Some{Nat.add(n, String.length(pat))}
        case False{}:
          cut.go(t, String.starts_with(t, pat), pat, 1n+n)

# The length of s up to and through the first pat.
def cut(+s: String, +pat: String) -> Maybe<&2, Nat>:
  cut.go(s, String.starts_with(s, pat), pat, 0n)

def is_wsn(+c: U32) -> Bool:
  is_sp(c) || is_nl(c)

def wsp(+s: String) -> String:
  skip(~(c => is_wsn(c)), s)

# The length of the longest prefix of s whose code points satisfy p.
def run(~p: U32 -> Bool, +s: String) -> Nat:
  String.length(fst(span(~p, s)))

def wsn(+s: String) -> Nat:
  run(~(c => is_wsn(c)), s)

def need(ok: Bool, +n: Nat) -> Maybe<&2, Nat>:
  Bool.pick(Maybe<&2, Nat>, ok, Some{n}, None{})

def tok(+p: String, +s: String) -> Maybe<&2, Nat>:
  need(String.starts_with(s, p), String.length(p))

def add(+a: Nat, m: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Some{Nat.add(a, b)}

def tagname(+s: String) -> Maybe<&2, Nat>:
  need(is_alpha(hd(s)), run(~(c => is_alnum(c) || eq(c, 45)), s))

def attrname(+s: String) -> Maybe<&2, Nat>:
  +c = hd(s)
  need(is_alpha(c) || eq(c, 95) || eq(c, 58), run(~(x => is_alnum(x) || eq(x, 95) || eq(x, 46) || eq(x, 58) || eq(x, 45)), s))

def unquoted(+c: U32) -> Bool:
  Bool.not(eq(c, 0) || is_wsn(c) || eq(c, 34) || eq(c, 39) || eq(c, 61) || eq(c, 60) || eq(c, 62) || eq(c, 96))

def attrval(+s: String) -> Maybe<&2, Nat>:
  +q = hd(s)
  when(Maybe<&2, Nat>, eq(q, 34) || eq(q, 39), u => add(1n, cut(String.drop(s, 1n), one(q))),
    u => need(unquoted(q), run(~(c => unquoted(c)), s)))

def or(a: Maybe<&2, Nat>, b: Maybe<&2, Nat>) -> Maybe<&2, Nat>:
  match a:
    case Some{x}:
      Some{x}
    case None{}:
      b

def attr.value(+s: String) -> Maybe<&2, Nat>:
  +a = wsn(s)
  do Maybe<&2, Nat>:
    b : Nat <- tok("=", String.drop(s, a))
    +c : Nat = Nat.add(a, b)
    +d : Nat = Nat.add(c, wsn(String.drop(s, c)))
    e : Nat <- attrval(String.drop(s, d))
    return Nat.add(d, e)

def attr(+s: String) -> Maybe<&2, Nat>:
  +a = wsn(s)
  do Maybe<&2, Nat>:
    +b : Nat <- add(a, need(is_wsn(hd(s)), 0n))
    +c : Nat <- add(b, attrname(String.drop(s, b)))
    return Maybe.default(&2, Nat, add(c, attr.value(String.drop(s, c))), c)

def attrs.go(f: String, m: Maybe<&2, Nat>, +s: String, +n: Nat) -> Nat:
  match f:
    case SNil{}:
      n
    case SCon{x, g}:
      match m:
        case None{}:
          n
        case Some{+k}:
          +r = String.drop(s, k)
          attrs.go(g, attr(r), r, Nat.add(n, k))

# Each attribute takes at least one code point, so s itself is enough fuel.
def attrs(+s: String) -> Nat:
  attrs.go(s, attr(s), s, 0n)

def open_tag(+s: String) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    z : Nat <- tok("<", s)
    +a : Nat <- add(1n, tagname(String.drop(s, 1n)))
    +b : Nat = Nat.add(a, attrs(String.drop(s, a)))
    +c : Nat = Nat.add(b, wsn(String.drop(s, b)))
    +r : String = String.drop(s, c)
    d : Nat <- or(tok("/>", r), tok(">", r))
    return Nat.add(c, d)

def close_tag(+s: String) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    _ : Nat <- tok("</", s)
    +a : Nat <- add(2n, tagname(String.drop(s, 2n)))
    +b : Nat = Nat.add(a, wsn(String.drop(s, a)))
    c : Nat <- tok(">", String.drop(s, b))
    return Nat.add(b, c)

# The closers that an earlier < showed are missing from the rest of the paragraph: -->, ?>, ]]>, and the > of a declaration.
type Ms is Data:
  Ms{com: Bool, pi: Bool, cd: Bool, dec: Bool}

# cut, unless pat is known to be missing.
def cut.if(no: Bool, +s: String, +pat: String) -> Maybe<&2, Nat>:
  when(Maybe<&2, Nat>, no, u => None{}, u => cut(s, pat))

def comment(+no: Bool, +s: String) -> Maybe<&2, Nat>:
  +a = String.drop(s, 4n)
  do Maybe<&2, Nat>:
    _ : Nat <- tok("<!--", s)
    b : Nat <- or(tok(">", a), or(tok("->", a), cut.if(no, a, "-->")))
    return Nat.add(4n, b)

def decl(+no: Bool, +s: String) -> Maybe<&2, Nat>:
  do Maybe<&2, Nat>:
    _ : Nat <- tok("<!", s)
    _ : Nat <- need(is_alpha(hd(String.drop(s, 2n))), 0n)
    c : Nat <- cut.if(no, String.drop(s, 2n), ">")
    return Nat.add(2n, c)

def cut.after(+no: Bool, +p: String, +s: String, +pat: String) -> Maybe<&2, Nat>:
  +n = String.length(p)
  do Maybe<&2, Nat>:
    _ : Nat <- tok(p, s)
    c : Nat <- cut.if(no, String.drop(s, n), pat)
    return Nat.add(n, c)

# The length of the raw inline HTML at the start of s.
def raw_html(ms: Ms, +s: String) -> Maybe<&2, Nat>:
  match ms:
    case Ms{com, pi, cd, dec}:
      or(open_tag(s), or(close_tag(s), or(comment(com, s), or(cut.after(pi, "<?", s, "?>"), or(cut.after(cd, "<![CDATA[", s, "]]>"), decl(dec, s))))))

# After a < at t that was not inline HTML: the closer it scanned for is missing from the rest.
def ms.add(+t: String, m: Ms) -> Ms:
  match m:
    case Ms{com, pi, cd, dec}:
      Ms{com || String.starts_with(t, "!--"), pi || String.starts_with(t, "?"), cd || String.starts_with(t, "![CDATA["), dec || (String.starts_with(t, "!") && is_alpha(hd(String.drop(t, 1n))))}

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
  St{when(List<&2, Frame>, is_blank(rest), u => stack, u => add_kid(stack, Kid{llb, BPara{String.trim_end(rest)}})), LNone{}, refs, line}

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

def html7.ok(m: Maybe<&2, Nat>, +s: String) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{n}:
      is_blank(String.drop(s, n))

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
                  Bool.pick(U32, Bool.not(cpara) && (html7.ok(open_tag(s), s) || html7.ok(close_tag(s), s)), 7, 0)))))))

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
      when(Sr, U32.is_ge(ind, 4) && Bool.not(p_tipp(p)) && Bool.not(blank), u => SDone{set_leaf(prep(p), LCode{False{}, [ln_s(adv(ln, 4))]})}, u => SStop{p})

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
      when(Sr, ok, u => SCont{P{push_frame(prep(p), f), Bool.pick(Ln, pb, cx_at(pc), adv(post, used)), 0n, LkNone{}, p_tipp(p)}}, u => try.code(p, c))

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
  when(Sr, is_blank(rest), u => SCont{P{St{stack, LNone{}, refs, line}, p_ln(p), 0n, LkNone{}, p_tipp(p)}}, u => SDone{St{add_kid(stack, Kid{False{}, BHead{lv, String.trim(rest)}}), LNone{}, refs, line}})

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
  SDone{when(St, U32.is_le(k, 5) && html_end(k, s), u => close_leaf(st), u => st)}

def try.html(+k: U32, +p: P, +c: Cx) -> Sr:
  +lv = setext(ln_s(cx_at(c)))
  when(Sr, U32.is_gt(k, 0), u => html.open(k, p, c), u => try.setext(U32.is_le(cx_ind(c), 3) && p_cpara(p) && U32.is_gt(lv, 0), lv, p, c))

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
          when(St, U32.is_le(k, 5) && html_end(k, s), u => close_leaf(st2), u => st2)
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
          when(St, cx_blank(c), u => head_blank(st), u => reset_llb(leaf_add(st, ln_s(cx_at(c)))))

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
  when(String, String.ends_with(l, "\r"), u => String.take(l, Nat.sub(String.length(l), 1n)), u => l)

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

# An inline in progress. IHtml is finished output and its plain text, for image alt text. IMark renders as nothing; no active link bracket lies below it.
type Inl is Data:
  IText{s: String}
  IHtml{html: String, plain: String}
  IDelim{c: U32, n: U32, orig: U32, open: Bool, close: Bool}
  IBrack{img: Bool, active: Bool, after: String, ms: Ms}
  IMark{}

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
    case Con{IBrack{img, a, af, m}, rest}:
      Bool.pick(String, img, "![", "[") ++ r.inl(rest)
    case Con{IMark{}, rest}:
      r.inl(rest)

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
    case Con{IBrack{img, a, af, m}, rest}:
      Bool.pick(String, img, "![", "[") ++ p.inl(rest)
    case Con{IMark{}, rest}:
      p.inl(rest)

# ---- emphasis

# A matching opener: the inlines after it (oldest first), the opener, the height of the stack below it, and that stack.
type Fd is Data:
  Fd{above: List<&2, Inl>, c: U32, n: U32, o: U32, op: Bool, cl: Bool, hb: Nat, below: List<&2, Inl>}

type Rs is Data:
  RDone{}
  RNone{}
  RFound{fd: Fd}

# A closer kind's openers_bottom, as in the CommonMark reference: the bottom h inlines of the stack hold no opener for it.
type Bot is Data:
  Bot{k: U32, h: Nat}

# The emphasis stack, newest first, its height, and the bottom of each closer kind.
type Em is Data:
  Em{stack: List<&2, Inl>, h: Nat, bots: List<&2, Bot>}

# Whether an opener fits a closer depends only on its character, whether it can open, and its length mod 3.
def bot.key(+c: U32, +copen: Bool, +orig: U32) -> U32:
  ((c * 6) + Bool.pick(U32, copen, 3, 0) + (orig % 3) : U32)

def bot.get(bs: List<&2, Bot>, +k: U32) -> Nat:
  match bs:
    case Nil{}:
      0n
    case Con{Bot{k2, +h}, rest}:
      when(Nat, eq(k2, k), u => h, u => bot.get(rest, k))

def bot.put(bs: List<&2, Bot>, +k: U32, +h: Nat) -> List<&2, Bot>:
  match bs:
    case Nil{}:
      [Bot{k, h}]
    case Con{Bot{+k2, +h2}, +rest}:
      when(List<&2, Bot>, eq(k2, k), u => Bot{k, h} <> rest, u => Bot{k2, h2} <> bot.put(rest, k, h))

def bot.clamp(bs: List<&2, Bot>, +h: Nat) -> List<&2, Bot>:
  match bs:
    case Nil{}:
      Nil{}
    case Con{Bot{k, h2}, rest}:
      Bot{k, Nat.min(h, h2)} <> bot.clamp(rest, h)

# Rule of three: a run that can both open and close matches only if the lengths do not sum to a multiple of 3, unless both are.
def odd_fail(+ocl: Bool, +o: U32, +copen: Bool, +orig: U32) -> Bool:
  (ocl || copen) && eq(((o + orig) % 3 : U32), 0) && Bool.not(eq((o % 3 : U32), 0) && eq((orig % 3 : U32), 0))

# Searches the stack, h high, for an opener above its bottom bot.
def find(stack: List<&2, Inl>, +h: Nat, +bot: Nat, +c: U32, +orig: U32, +copen: Bool, +acc: List<&2, Inl>) -> Maybe<&2, Fd>:
  match stack:
    case Nil{}:
      None{}
    case Con{IDelim{+c2, +n2, +o2, +op2, +cl2}, +rest}:
      +hb = Nat.sub(h, 1n)
      +fits = Bool.pick(Bool, eq(c, 126), eq(o2, orig), Bool.not(odd_fail(cl2, o2, copen, orig)))
      when(Maybe<&2, Fd>, Nat.is_le(h, bot), u => None{},
        u => when(Maybe<&2, Fd>, eq(c2, c) && op2 && fits, v => Some{Fd{acc, c2, n2, o2, op2, cl2, hb, rest}}, v => find(rest, hb, bot, c, orig, copen, IDelim{c2, n2, o2, op2, cl2} <> acc)))
    case Con{+x, +rest}:
      when(Maybe<&2, Fd>, Nat.is_le(h, bot), u => None{}, u => find(rest, Nat.sub(h, 1n), bot, c, orig, copen, x <> acc))

def rs.of(m: Maybe<&2, Fd>) -> Rs:
  match m:
    case None{}:
      RNone{}
    case Some{fd}:
      RFound{fd}

def seek(more: Bool, +stack: List<&2, Inl>, +h: Nat, +bots: List<&2, Bot>, +c: U32, +orig: U32, +copen: Bool) -> Rs:
  match more:
    case False{}:
      RDone{}
    case True{}:
      rs.of(find(stack, h, bot.get(bots, bot.key(c, copen, orig)), c, orig, copen, Nil{}))

def wrap(+c: U32, +use: U32, +xs: List<&2, Inl>) -> Inl:
  +tag = Bool.pick(String, eq(c, 126), "del", Bool.pick(String, eq(use, 2), "strong", "em"))
  +plain = p.inl(xs)
  IHtml{"<" ++ tag ++ ">" ++ r.inl(xs) ++ "</" ++ tag ++ ">", plain}

def keep(+n: U32, +c: U32, +o: U32, +op: Bool, +cl: Bool, +below: List<&2, Inl>) -> List<&2, Inl>:
  Bool.pick(List<&2, Inl>, eq(n, 0), below, IDelim{c, n, o, op, cl} <> below)

# Matches the closer, n long, against openers until it runs out or none is left. A miss raises the closer kind's bottom to the stack top; a match lowers every bottom to the new top.
def resolve(f: Nat, r: Rs, +stack: List<&2, Inl>, +h: Nat, +bots: List<&2, Bot>, +c: U32, +n: U32, +orig: U32, +copen: Bool) -> Em:
  match f:
    case 0n:
      Em{stack, h, bots}
    case 1n+g:
      match r:
        case RDone{}:
          Em{stack, h, bots}
        case RNone{}:
          +b2 = bot.put(bots, bot.key(c, copen, orig), h)
          Bool.pick(Em, copen, Em{IDelim{c, n, orig, copen, True{}} <> stack, 1n+h, b2}, Em{IText{rep(c, n)} <> stack, 1n+h, b2})
        case RFound{Fd{above, c2, +n2, o2, op2, cl2, +hb, below}}:
          +use = Bool.pick(U32, eq(c, 126), n, Bool.pick(U32, U32.is_ge(n, 2) && U32.is_ge(n2, 2), 2, 1))
          +left = (n2 - use : U32)
          +st2 = {wrap(c, use, above) <> keep(left, c2, o2, op2, cl2, below) : List<&2, Inl>}
          +h2 = Nat.add(hb, Bool.pick(Nat, eq(left, 0), 1n, 2n))
          +b2 = bot.clamp(bots, h2)
          +nr = (n - use : U32)
          resolve(g, seek(U32.is_gt(nr, 0), st2, h2, b2, c, orig, copen), st2, h2, b2, c, nr, orig, copen)

def emph.delim(cl: Bool, em: Em, +c: U32, +n: U32, +o: U32, +op: Bool) -> Em:
  match cl:
    case False{}:
      match em:
        case Em{stack, h, bots}:
          Em{IDelim{c, n, o, op, False{}} <> stack, 1n+h, bots}
    case True{}:
      match em:
        case Em{+stack, +h, +bots}:
          resolve(1n+U32.to_nat(n), seek(True{}, stack, h, bots, c, o, op), stack, h, bots, c, n, o, op)

def emph.go(xs: List<&2, Inl>, em: Em) -> List<&2, Inl>:
  match xs:
    case Nil{}:
      match em:
        case Em{stack, h, bots}:
          List.reverse(&2, Inl, stack)
    case Con{IDelim{c, n, o, op, cl}, rest}:
      emph.go(rest, emph.delim(cl, em, c, n, o, op))
    case Con{x, rest}:
      match em:
        case Em{stack, h, bots}:
          emph.go(rest, Em{x <> stack, 1n+h, bots})

# Emphasis and strong emphasis, by the delimiter run rules.
def emph(xs: List<&2, Inl>) -> List<&2, Inl>:
  emph.go(xs, Em{Nil{}, 0n, Nil{}})

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
  when(String, strip, u => String.take(String.drop(s, 1n), Nat.sub(String.length(s), 2n)), u => s)

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

def url.has.of(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{r}:
      True{}

def url.has(+p: String, +s: String) -> Bool:
  url.has.of(lit_ci(p, s))

# cmark's unsafe schemes. A data: image in PNG, GIF, JPEG, or WebP is safe.
def url.bad(+s: String) -> Bool:
  +img = url.has("data:image/png", s) || url.has("data:image/gif", s) || url.has("data:image/jpeg", s) || url.has("data:image/webp", s)
  Bool.not(img) && (url.has("javascript:", s) || url.has("vbscript:", s) || url.has("file:", s) || url.has("data:", s))

# An href or src value. In safe mode an unsafe URL becomes empty.
def url(safe: Bool, +s: String) -> String:
  match safe:
    case False{}:
      href(s)
    case True{}:
      href(Bool.pick(String, url.bad(s), SNil{}, s))

# Render options. safe renders as cmark without --unsafe. gfm turns on the GitHub extensions.
type Opts is Data:
  Opts{safe: Bool, gfm: Bool}

def o.safe(o: Opts) -> Bool:
  match o:
    case Opts{s, g}:
      s

def o.gfm(o: Opts) -> Bool:
  match o:
    case Opts{s, g}:
      g

def tagf.end(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{+r}:
      +c = hd(r)
      is_sp(c) || eq(c, 10) || eq(c, 12) || eq(c, 13) || eq(c, 62) || String.starts_with(r, "/>")

def tagf.name(+n: String, +a: String) -> Bool:
  tagf.end(lit_ci(n, a))

# s follows a <. GFM's tag filter blocks these nine tags, open or closed.
def tagf.bad(+s: String) -> Bool:
  +a = Bool.pick(String, eq(hd(s), 47), String.drop(s, 1n), s)
  tagf.name("title", a) || tagf.name("textarea", a) || tagf.name("style", a) || tagf.name("xmp", a) || tagf.name("iframe", a) || tagf.name("noembed", a) || tagf.name("noframes", a) || tagf.name("script", a) || tagf.name("plaintext", a)

def tagf.lt(lt: Bool, +s: String) -> Bool:
  match lt:
    case False{}:
      False{}
    case True{}:
      tagf.bad(s)

def tagfilter(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+y}, +t}:
      +r = tagfilter(t)
      Bool.pick(String, tagf.lt(eq(y, 60), t), "&lt;" ++ r, SCon{Chr{y}, r})

# Raw HTML as the options render it.
def html_out(o: Opts, +raw: String) -> String:
  match o:
    case Opts{s, g}:
      match s:
        case True{}:
          "<!-- raw HTML omitted -->"
        case False{}:
          match g:
            case True{}:
              tagfilter(raw)
            case False{}:
              raw

def lt.html(m: Maybe<&2, Nat>, +s: String, +buf: String, out: List<&2, Inl>, +o: Opts) -> Is:
  match m:
    case None{}:
      Is{String.drop(s, 1n), 60, SCon{'<', buf}, out}
    case Some{+n}:
      +raw = String.take(s, n)
      Is{String.drop(s, n), 62, SNil{}, IHtml{html_out(o, raw), raw} <> flush(buf, out)}

def lt.email(m: Maybe<&2, Got>, +ms: Ms, +s: String, +buf: String, out: List<&2, Inl>, +o: Opts) -> Is:
  match m:
    case Some{Got{+v, rest}}:
      Is{rest, 62, SNil{}, IHtml{"<a href=\"mailto:" ++ href(v) ++ "\">" ++ esc(v) ++ "</a>", v} <> flush(buf, out)}
    case None{}:
      lt.html(raw_html(ms, s), s, buf, out, o)

def lt.uri(m: Maybe<&2, Got>, +ms: Ms, +s: String, +buf: String, out: List<&2, Inl>, +o: Opts) -> Is:
  match m:
    case Some{Got{+v, rest}}:
      Is{rest, 62, SNil{}, IHtml{"<a href=\"" ++ url(o.safe(o), v) ++ "\">" ++ esc(v) ++ "</a>", v} <> flush(buf, out)}
    case None{}:
      lt.email(auto.email(String.drop(s, 1n)), ms, s, buf, out, o)

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
  Is{skip(~(c => is_sp(c)), t), 10, SNil{}, IHtml{Bool.pick(String, Nat.is_ge(k, 2n), "<br />\n", "\n"), " "} <> flush(b2, out)}

def bs(+t: String, +buf: String, +out: List<&2, Inl>) -> Is:
  +x = hd(t)
  Bool.pick(Is, is_apunct(x), Is{String.drop(t, 1n), x, SCon{Chr{x}, buf}, out},
    Bool.pick(Is, eq(x, 10), Is{skip(~(c => is_sp(c)), String.drop(t, 1n)), 10, SNil{}, IHtml{"<br />\n", " "} <> flush(buf, out)},
      Is{t, 92, SCon{'\\', buf}, out}))

def delim(+c: U32, +s: String, +prev: U32, +buf: String, +out: List<&2, Inl>) -> Is:
  +n = count(c, s)
  +rest = String.drop(s, n)
  +nx = hd(rest)
  +left = Bool.not(is_uws(nx)) && (Bool.not(is_punct(nx)) || is_uws(prev) || is_punct(prev))
  +right = Bool.not(is_uws(prev)) && (Bool.not(is_punct(prev)) || is_uws(nx) || is_punct(nx))
  +star = eq(c, 42) || eq(c, 126)
  +op = Bool.pick(Bool, star, left, left && (Bool.not(right) || is_punct(prev)))
  +cl = Bool.pick(Bool, star, right, right && (Bool.not(left) || is_punct(nx)))
  +k = U32.from_nat(n)
  Bool.pick(Is, eq(c, 126) && U32.is_gt(k, 2), Is{rest, c, revapp(rep(c, k), buf), out}, Is{rest, c, SNil{}, IDelim{c, k, k, op, cl} <> flush(buf, out)})

# ---- GFM extended autolinks

# A code point after which an extended autolink may start.
def al.bound(+c: U32) -> Bool:
  eq(c, 10) || eq(c, 32) || eq(c, 9) || eq(c, 42) || eq(c, 95) || eq(c, 126) || eq(c, 40)

def al.space(+c: U32) -> Bool:
  eq(c, 32) || within(c, 9, 13)

def al.host(+c: U32) -> Bool:
  is_alnum(c) || U32.is_ge(c, 128)

def al.cnt(+k: U32, s: String, +n: Nat) -> Nat:
  match s:
    case SNil{}:
      n
    case SCon{Chr{+y}, t}:
      al.cnt(k, t, Bool.pick(Nat, eq(y, k), 1n+n, n))

def al.last2(xs: List<&2, String>, +a: String, +b: String) -> String & String:
  match xs:
    case Nil{}:
      (a, b)
    case Con{x, rest}:
      al.last2(rest, b, x)

def al.dom.of(+run: String, +allow_short: Bool, p: String & String) -> Nat:
  (u1s, u2s) = p
  +np = al.cnt(46, run, 0n)
  +bad = Bool.not(Nat.is_eq(al.cnt(95, u1s, 0n), 0n)) || Bool.not(Nat.is_eq(al.cnt(95, u2s, 0n), 0n))
  Bool.pick(Nat, bad || Bool.not(allow_short || Bool.not(Nat.is_eq(np, 0n))), 0n, 1n+String.length(run))

def al.dom.run(p: String & String) -> String:
  (+run0, rest0) = p
  Bool.pick(String, String.is_empty(rest0), String.reverse(String.drop(String.reverse(run0), 1n)), run0)

# cmark-gfm's check_domain: the length of the domain at s, or 0. It never looks at the last code point of s.
def al.dom(+s: String, +allow_short: Bool) -> Nat:
  +run = al.dom.run(span(~(c => al.host(c) || eq(c, 45) || eq(c, 95) || eq(c, 46)), String.drop(s, 1n)))
  al.dom.of(run, allow_short, al.last2(String.split(run, '.'), "", ""))

type Ak is Data:
  AkStop{}
  AkParen{}
  AkPunct{}
  AkSemi{}

def al.k(+c: U32) -> Ak:
  Bool.pick(Ak, eq(c, 41), AkParen{},
    Bool.pick(Ak, eq(c, 63) || eq(c, 33) || eq(c, 46) || eq(c, 44) || eq(c, 58) || eq(c, 42) || eq(c, 95) || eq(c, 126) || eq(c, 39) || eq(c, 34), AkPunct{},
      Bool.pick(Ak, eq(c, 59), AkSemi{}, AkStop{})))

def al.semi(+t: String) -> String:
  +k = String.length(fst(span(~(c => is_alpha(c)), t)))
  Bool.pick(String, Nat.is_gt(k, 0n) && eq(hd(String.drop(t, k)), 38), String.drop(t, 1n+k), t)

# cmark-gfm's autolink_delim over the link reversed: trailing punctuation, unbalanced ) and a trailing entity drop off.
def al.trim(f: Nat, k: Ak, +rs: String, +closing: Nat, +opening: Nat) -> String:
  match f:
    case 0n:
      rs
    case 1n+g:
      match k:
        case AkStop{}:
          rs
        case AkPunct{}:
          +t = String.drop(rs, 1n)
          al.trim(g, al.k(hd(t)), t, closing, opening)
        case AkSemi{}:
          +t = al.semi(String.drop(rs, 1n))
          al.trim(g, al.k(hd(t)), t, closing, opening)
        case AkParen{}:
          +t = String.drop(rs, 1n)
          Bool.pick(String, Nat.is_le(closing, opening), rs, al.trim(g, al.k(hd(t)), t, Nat.sub(closing, 1n), opening))

def al.delim(+link: String) -> String:
  +l = fst(span(~(c => Bool.not(eq(c, 60))), link))
  +rs = String.reverse(l)
  String.reverse(al.trim(1n+String.length(rs), al.k(hd(rs)), rs, al.cnt(41, l, 0n), al.cnt(40, l, 0n)))

type Al is Data:
  Al{href: String, text: String}

def al.link(+pre: String, +text: String) -> Maybe<&2, Al>:
  Bool.pick(Maybe<&2, Al>, String.is_empty(text), None{}, Some{Al{pre ++ text, text}})

# The domain is d long; the link runs to the next space, then loses its trailing punctuation.
def al.tail(+pre: String, +d: Nat, +s: String) -> Maybe<&2, Al>:
  +e = Nat.add(d, String.length(fst(span(~(c => Bool.not(al.space(c))), String.drop(s, d)))))
  Bool.pick(Maybe<&2, Al>, Nat.is_eq(d, 0n), None{}, al.link(pre, al.delim(String.take(s, e))))

def al.www(+s: String) -> Maybe<&2, Al>:
  Bool.pick(Maybe<&2, Al>, String.starts_with(s, "www."), al.tail("http://", al.dom(s, False{}), s), None{})

def al.scheme.of(m: Maybe<&2, String>, +k: Nat, +s: String) -> Maybe<&2, Al>:
  match m:
    case None{}:
      None{}
    case Some{+a}:
      +d = Bool.pick(Nat, al.host(hd(a)), al.dom(a, True{}), 0n)
      al.tail("", Bool.pick(Nat, Nat.is_eq(d, 0n), 0n, Nat.add(k, d)), s)

def al.scheme(+p: String, +s: String) -> Maybe<&2, Al>:
  al.scheme.of(lit(p, s), String.length(p), s)

def al.mail_ch(+c: U32) -> Bool:
  is_alnum(c) || eq(c, 46) || eq(c, 43) || eq(c, 45) || eq(c, 95)

def al.dpart.ok(+c: U32, +nx: U32) -> Bool:
  is_alnum(c) || eq(c, 45) || eq(c, 95) || eq(c, 64) || (eq(c, 46) && is_alnum(nx))

def al.dpart.go(s: String, ok: Bool, +acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{+y}, +t}:
      match ok:
        case False{}:
          String.reverse(acc)
        case True{}:
          al.dpart.go(t, al.dpart.ok(hd(t), hd(String.drop(t, 1n))), SCon{Chr{y}, acc})

# The domain of an email after its @, as cmark-gfm's email_match scans it.
def al.dpart(+s: String) -> String:
  al.dpart.go(s, al.dpart.ok(hd(s), hd(String.drop(s, 1n))), SNil{})

def al.mail(+s: String) -> Maybe<&2, Al>:
  +local = fst(span(~(c => al.mail_ch(c)), s))
  +a = String.drop(s, String.length(local))
  +dom = al.dpart(String.drop(a, 1n))
  +ok = Bool.not(String.is_empty(local)) && eq(hd(a), 64) && Bool.not(String.is_empty(dom)) && Nat.is_eq(al.cnt(64, dom, 0n), 0n) && Bool.not(Nat.is_eq(al.cnt(46, dom, 0n), 0n)) && is_alpha(hd(String.reverse(dom)))
  Bool.pick(Maybe<&2, Al>, ok, al.link("mailto:", local ++ "@" ++ dom), None{})

def al.or(a: Maybe<&2, Al>, b: Maybe<&2, Al>) -> Maybe<&2, Al>:
  match a:
    case Some{x}:
      Some{x}
    case None{}:
      b

# A GFM extended autolink at the start of s: www., http://, https://, ftp://, or an email address.
def al(+s: String) -> Maybe<&2, Al>:
  al.or(al.www(s), al.or(al.scheme("http://", s), al.or(al.scheme("https://", s), al.or(al.scheme("ftp://", s), al.mail(s)))))

def other.al(m: Maybe<&2, Al>, +y: U32, +t: String, +buf: String, out: List<&2, Inl>, +safe: Bool) -> Is:
  match m:
    case None{}:
      Is{t, y, SCon{Chr{y}, buf}, out}
    case Some{Al{h, +x}}:
      Is{String.drop(SCon{Chr{y}, t}, String.length(x)), hd(String.reverse(x)), SNil{}, IHtml{"<a href=\"" ++ url(safe, h) ++ "\">" ++ esc(x) ++ "</a>", x} <> flush(buf, out)}

def other(try: Bool, +y: U32, +t: String, +buf: String, out: List<&2, Inl>, +o: Opts) -> Is:
  match try:
    case False{}:
      Is{t, y, SCon{Chr{y}, buf}, out}
    case True{}:
      other.al(al(SCon{Chr{y}, t}), y, t, buf, out, o.safe(o))

# ---- links

# Splits the output at its newest bracket: the inlines after it (oldest first), the bracket, and the rest.
type Bk is Data:
  Bk{above: List<&2, Inl>, img: Bool, active: Bool, after: String, ms: Ms, below: List<&2, Inl>}

def brk(out: List<&2, Inl>, acc: List<&2, Inl>) -> Maybe<&2, Bk>:
  match out:
    case Nil{}:
      None{}
    case Con{IBrack{img, a, af, m}, rest}:
      Some{Bk{acc, img, a, af, m, rest}}
    case Con{x, rest}:
      brk(rest, x <> acc)

# Deactivates the link brackets below a new link. It stops at an IMark or an inactive bracket, because all brackets below one are already inactive.
def deact(xs: List<&2, Inl>) -> List<&2, Inl>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{IMark{}, rest}:
      IMark{} <> rest
    case Con{IBrack{False{}, False{}, af, m}, rest}:
      IBrack{False{}, False{}, af, m} <> rest
    case Con{IBrack{False{}, True{}, af, m}, rest}:
      IBrack{False{}, False{}, af, m} <> deact(rest)
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

def lookup.raw(+refs: List<&2, Ref>, m: Maybe<&2, String>, +rest: String) -> Maybe<&2, Lt>:
  match m:
    case None{}:
      None{}
    case Some{raw}:
      lookup(refs, raw, rest)

def ref.full(m: Maybe<&2, Got>, +t: String, +raw: Maybe<&2, String>, +refs: List<&2, Ref>) -> Maybe<&2, Lt>:
  match m:
    case Some{Got{lab, rest}}:
      lookup(refs, lab, rest)
    case None{}:
      when(Maybe<&2, Lt>, String.starts_with(t, "[]"), u => lookup.raw(refs, raw, String.drop(t, 2n)), u => lookup.raw(refs, raw, t))

def ref.tail(+t: String, +raw: Maybe<&2, String>, +refs: List<&2, Ref>) -> Maybe<&2, Lt>:
  ref.full(when(Maybe<&2, Got>, eq(hd(t), 91), u => label(String.drop(t, 1n)), u => None{}), t, raw, refs)

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

def title_attr(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{t}:
      " title=\"" ++ esc(t) ++ "\""

def link.make(lt: Lt, xs: List<&2, Inl>, +img: Bool, +below: List<&2, Inl>, +o: Opts) -> Is:
  match lt:
    case Lt{d, +t, +rest}:
      +ys = emph(xs)
      +plain = p.inl(ys)
      +u = url(o.safe(o), d)
      when(Is, img,
        z => Is{rest, 93, SNil{}, IHtml{"<img src=\"" ++ u ++ "\" alt=\"" ++ esc(plain) ++ "\"" ++ title_attr(t) ++ " />", plain} <> below},
        z => Is{rest, 93, SNil{}, IHtml{"<a href=\"" ++ u ++ "\"" ++ title_attr(t) ++ ">" ++ r.inl(ys) ++ "</a>", plain} <> IMark{} <> deact(below)})

def link.fail(above: List<&2, Inl>, +img: Bool, below: List<&2, Inl>, +t: String) -> Is:
  Is{t, 93, SCon{']', SNil{}}, List.append(&2, Inl, List.reverse(&2, Inl, above), IText{Bool.pick(String, img, "![", "[")} <> below)}

def link.try(m: Maybe<&2, Lt>, above: List<&2, Inl>, +img: Bool, below: List<&2, Inl>, +t: String, +o: Opts) -> Is:
  match m:
    case Some{lt}:
      link.make(lt, above, img, below, o)
    case None{}:
      link.fail(above, img, below, t)

def lab.tick.of(m: Maybe<&2, Got>, +n: Nat) -> Nat:
  match m:
    case None{}:
      n
    case Some{Got{v, r}}:
      Nat.add(Nat.add(n, n), String.length(v))

def lab.tick(+n: Nat, +s: String) -> Nat:
  lab.tick.of(tick.go(String.drop(s, n), False{}, 0n, n, SNil{}), n)

def lab.lt(u: Maybe<&2, Got>, e: Maybe<&2, Got>, h: Maybe<&2, Nat>) -> Nat:
  match u:
    case Some{Got{v, r}}:
      Nat.add(2n, String.length(v))
    case None{}:
      match e:
        case Some{Got{v, r}}:
          Nat.add(2n, String.length(v))
        case None{}:
          Maybe.default(&2, Nat, h, 1n)

def lab.al(m: Maybe<&2, Al>) -> Nat:
  match m:
    case None{}:
      1n
    case Some{Al{h, x}}:
      String.length(x)

# How many code points the piece at s takes, by the inline scanner's rules: an escape, a code span, an autolink, raw HTML, a GFM extended autolink after prev, or one code point.
def lab.len(+c: U32, +prev: U32, +ms: Ms, +gfm: Bool, +s: String) -> Nat:
  +t = String.drop(s, 1n)
  when(Nat, eq(c, 92), u => Bool.pick(Nat, is_apunct(hd(t)), 2n, 1n),
    u => when(Nat, eq(c, 96), u => lab.tick(count(96, s), s),
      u => when(Nat, eq(c, 60), u => lab.lt(auto.uri(t), auto.email(t), raw_html(ms, s)),
        u => when(Nat, gfm && al.bound(prev), u => lab.al(al(s)), u => 1n))))

# The length of a bracket's raw label: the text up to the ] that closes it, scanned as the inline scanner scans it. None when another bracket comes first or the label passes 999 code points.
def lab.go(f: Nat, +s: String, +n: Nat, +prev: U32, +ms: Ms, +gfm: Bool) -> Maybe<&2, Nat>:
  match f:
    case 0n:
      None{}
    case 1n+g:
      +c = hd(s)
      +k = lab.len(c, prev, ms, gfm, s)
      +ms2 = when(Ms, eq(c, 60) && Nat.is_eq(k, 1n), u => ms.add(String.drop(s, 1n), ms), u => ms)
      when(Maybe<&2, Nat>, eq(c, 93), u => Some{n},
        u => when(Maybe<&2, Nat>, eq(c, 91) || eq(c, 0) || Nat.is_gt(n, 999n), u => None{},
          u => lab.go(g, String.drop(s, k), Nat.add(n, k), hd(String.reverse(String.take(s, k))), ms2, gfm)))

def lab.take(m: Maybe<&2, Nat>, +after: String) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{n}:
      Some{String.take(after, n)}

# An inline link, else a reference link.
def link.inl(m: Maybe<&2, Lt>, +above: List<&2, Inl>, +img: Bool, below: List<&2, Inl>, +t: String, +after: String, +ms: Ms, +refs: List<&2, Ref>, +o: Opts) -> Is:
  match m:
    case Some{lt}:
      link.make(lt, above, img, below, o)
    case None{}:
      link.try(ref.tail(t, lab.take(lab.go(1000n, after, 0n, 91, ms, o.gfm(o)), after), refs), above, img, below, t, o)

def close.br(m: Maybe<&2, Bk>, +t: String, +out: List<&2, Inl>, +refs: List<&2, Ref>, +o: Opts) -> Is:
  match m:
    case None{}:
      Is{t, 93, SCon{']', SNil{}}, out}
    case Some{Bk{above, +img, active, +after, +ms, below}}:
      match active:
        case False{}:
          link.fail(above, img, below, t)
        case True{}:
          link.inl(inl.tail(t), above, img, below, t, after, ms, refs, o)

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

def ic(+c: U32, +nx: U32, +gfm: Bool) -> Ic:
  Bool.pick(Ic, eq(c, 92), IcBs{},
    Bool.pick(Ic, eq(c, 96), IcTick{},
      Bool.pick(Ic, eq(c, 42) || eq(c, 95) || (gfm && eq(c, 126)), IcStar{},
        Bool.pick(Ic, eq(c, 91), IcOpen{},
          Bool.pick(Ic, eq(c, 33) && eq(nx, 91), IcBang{},
            Bool.pick(Ic, eq(c, 93), IcClose{},
              Bool.pick(Ic, eq(c, 60), IcLt{},
                Bool.pick(Ic, eq(c, 38), IcAmp{},
                  Bool.pick(Ic, eq(c, 10), IcNl{}, IcOther{})))))))))

# How many brackets are open after a step of kind k.
def opens(k: Ic, +n: Nat) -> Nat:
  match k:
    case IcOpen{}:
      1n+n
    case IcBang{}:
      1n+n
    case IcClose{}:
      Nat.sub(n, 1n)
    case _:
      n

# A < step that ends with prev still < was not inline HTML or an autolink.
def misses(k: Ic, +t: String, st: Is, +ms: Ms) -> Ms:
  match k:
    case IcLt{}:
      match st:
        case Is{s, prev, buf, out}:
          when(Ms, eq(prev, 60), u => ms.add(t, ms), u => ms)
    case _:
      ms

def istep(k: Ic, +open: Nat, +ms: Ms, +y: U32, +t: String, +prev: U32, +buf: String, +out: List<&2, Inl>, +refs: List<&2, Ref>, +o: Opts) -> Is:
  match k:
    case IcOther{}:
      other(o.gfm(o) && al.bound(prev), y, t, buf, out, o)
    case IcBs{}:
      bs(t, buf, out)
    case IcTick{}:
      code(SCon{Chr{y}, t}, buf, out)
    case IcStar{}:
      delim(y, SCon{Chr{y}, t}, prev, buf, out)
    case IcOpen{}:
      Is{t, 91, SNil{}, IBrack{False{}, True{}, t, ms} <> flush(buf, out)}
    case IcBang{}:
      Is{String.drop(t, 1n), 91, SNil{}, IBrack{True{}, True{}, String.drop(t, 1n), ms} <> flush(buf, out)}
    case IcClose{}:
      when(Is, Nat.is_eq(open, 0n), u => Is{t, 93, SCon{']', SNil{}}, flush(buf, out)}, u => close.br(brk(flush(buf, out), Nil{}), t, flush(buf, out), refs, o))
    case IcLt{}:
      lt.uri(auto.uri(t), ms, SCon{Chr{y}, t}, buf, out, o)
    case IcAmp{}:
      amp.got(ent(t), t, buf, out)
    case IcNl{}:
      nl(t, buf, out)

def inl.go(f: Nat, st: Is, +open: Nat, +ms: Ms, +refs: List<&2, Ref>, +o: Opts) -> List<&2, Inl>:
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
              +k = ic(y, hd(t), o.gfm(o))
              +st2 = istep(k, open, ms, y, t, prev, buf, out, refs, o)
              inl.go(g, st2, opens(k, open), misses(k, t, st2, ms), refs, o)

# A paragraph or heading's text as HTML.
def inline(+s: String, +refs: List<&2, Ref>, +o: Opts) -> String:
  r.inl(emph(inl.go(Nat.add(String.length(s), 2n), Is{s, 10, SNil{}, Nil{}}, 0n, Ms{False{}, False{}, False{}, False{}}, refs, o)))

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

# ---- GFM tables

# Pieces split at every |; a piece that ends in an odd run of \ joins the next one, its \ dropped.
def tbl.join(xs: List<&2, String>, +cur: String, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      List.reverse(&2, String, String.trim(cur) <> acc)
    case Con{+p, rest}:
      +odd = Nat.is_eq(Nat.mod(count(92, String.reverse(cur)), 2n), 1n)
      +cur2 = String.reverse(String.drop(String.reverse(cur), 1n)) ++ "|" ++ p
      tbl.join(rest, Bool.pick(String, odd, cur2, p), Bool.pick(List<&2, String>, odd, acc, String.trim(cur) <> acc))

def tbl.cells.of(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+p, rest}:
      tbl.join(rest, p, Nil{})

# A table row's cells, trimmed, with its outer pipes dropped and \| as |.
def tbl.cells(+row: String) -> List<&2, String>:
  +r = String.trim(row)
  +a = Bool.pick(String, String.starts_with(r, "|"), String.drop(r, 1n), r)
  +ra = String.reverse(a)
  +tail = String.starts_with(ra, "|") && Nat.is_eq(Nat.mod(count(92, String.drop(ra, 1n)), 2n), 0n) && Bool.not(String.is_empty(a))
  tbl.cells.of(String.split(Bool.pick(String, tail, String.reverse(String.drop(ra, 1n)), a), '|'))

def tbl.dcell(+c: String) -> Bool:
  +a = Bool.pick(String, String.starts_with(c, ":"), String.drop(c, 1n), c)
  +ra = String.reverse(a)
  +b = Bool.pick(String, String.starts_with(ra, ":"), String.drop(ra, 1n), ra)
  Bool.not(String.is_empty(b)) && String.is_empty(skip(~(x => eq(x, 45)), b))

def tbl.drow(cs: List<&2, String>) -> Bool:
  match cs:
    case Nil{}:
      True{}
    case Con{c, rest}:
      tbl.dcell(c) && tbl.drow(rest)

def tbl.align(+c: String) -> String:
  +l = String.starts_with(c, ":")
  +r = String.ends_with(c, ":")
  Bool.pick(String, l && r, " align=\"center\"", Bool.pick(String, r, " align=\"right\"", Bool.pick(String, l, " align=\"left\"", "")))

def tbl.aligns(cs: List<&2, String>) -> List<&2, String>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{c, rest}:
      tbl.align(c) <> tbl.aligns(rest)

# A table in a paragraph: the lines before its header row, the header cells, the alignments, and the body rows.
type Tb is Data:
  Tb{before: List<&2, String>, head: List<&2, String>, aligns: List<&2, String>, rows: List<&2, String>}

def tbl.find(ls: List<&2, String>, +before: List<&2, String>) -> Maybe<&2, Tb>:
  match ls:
    case Con{+h, +tl}:
      match tl:
        case Con{+d, +rest}:
          +hc = tbl.cells(h)
          +dc = tbl.cells(d)
          +hit = String.contains(d, "-") && tbl.drow(dc) && Nat.is_eq(List.length(&2, String, hc), List.length(&2, String, dc))
          when(Maybe<&2, Tb>, hit, u => Some{Tb{List.reverse(&2, String, before), hc, tbl.aligns(dc), rest}}, u => tbl.find(tl, h <> before))
        case Nil{}:
          None{}
    case Nil{}:
      None{}

# One row's cells, cut or padded with empty cells to the header's width.
def tbl.row(aligns: List<&2, String>, cs: List<&2, String>, +tag: String, +refs: List<&2, Ref>, +o: Opts) -> String:
  match aligns cs:
    case Nil{} _:
      ""
    case Con{+a, ar} Nil{}:
      "<" ++ tag ++ a ++ "></" ++ tag ++ ">\n" ++ tbl.row(ar, Nil{}, tag, refs, o)
    case Con{+a, ar} Con{c, cr}:
      "<" ++ tag ++ a ++ ">" ++ inline(c, refs, o) ++ "</" ++ tag ++ ">\n" ++ tbl.row(ar, cr, tag, refs, o)

def tbl.rows(rows: List<&2, String>, +aligns: List<&2, String>, +refs: List<&2, Ref>, +o: Opts) -> String:
  match rows:
    case Nil{}:
      ""
    case Con{r, rest}:
      "<tr>\n" ++ tbl.row(aligns, tbl.cells(r), "td", refs, o) ++ "</tr>\n" ++ tbl.rows(rest, aligns, refs, o)

def tbl.html(+head: List<&2, String>, +aligns: List<&2, String>, +rows: List<&2, String>, +refs: List<&2, Ref>, +o: Opts) -> String:
  +body = Bool.pick(String, List.is_empty(&2, String, rows), "", "<tbody>\n" ++ tbl.rows(rows, aligns, refs, o) ++ "</tbody>\n")
  "<table>\n<thead>\n<tr>\n" ++ tbl.row(aligns, head, "th", refs, o) ++ "</tr>\n</thead>\n" ++ body ++ "</table>\n"

# A paragraph's text, after pre, in <p> unless tight.
def r.text(+t: String, +tight: Bool, +refs: List<&2, Ref>, +o: Opts, +pre: String, +out: String) -> String:
  +h = pre ++ inline(t, refs, o)
  when(String, tight, u => put(h, out), u => put("</p>\n", put(h, put("<p>", cr(out)))))

def r.tbl(m: Maybe<&2, Tb>, +t: String, +tight: Bool, +refs: List<&2, Ref>, +o: Opts, +out: String) -> String:
  match m:
    case None{}:
      r.text(t, tight, refs, o, "", out)
    case Some{Tb{+before, head, aligns, rows}}:
      +o1 = when(String, List.is_empty(&2, String, before), u => out, u => r.text(String.join(before, "\n"), tight, refs, o, "", out))
      put(tbl.html(head, aligns, rows, refs, o), cr(o1))

def r.para(gfm: Bool, +t: String, +tight: Bool, +refs: List<&2, Ref>, +o: Opts, +out: String) -> String:
  match gfm:
    case False{}:
      r.text(t, tight, refs, o, "", out)
    case True{}:
      r.tbl(when(Maybe<&2, Tb>, String.contains(t, "|"), u => tbl.find(String.split(t, '\n'), Nil{}), u => None{}), t, tight, refs, o, out)

# A GFM task list item's first paragraph: 0 for none, 1 for [ ], 2 for [x] or [X].
def task.kind(+gfm: Bool, +t: String) -> U32:
  +ws = is_sp(hd(String.drop(t, 3n))) || eq(hd(String.drop(t, 3n)), 10)
  +box = Bool.pick(U32, String.starts_with(t, "[ ]"), 1, Bool.pick(U32, String.starts_with(t, "[x]") || String.starts_with(t, "[X]"), 2, 0))
  Bool.pick(U32, gfm && ws, box, 0)

def r.first(task: Bool, +k: U32, +t: String, +tight: Bool, +refs: List<&2, Ref>, +o: Opts, +out: String) -> String:
  match task:
    case False{}:
      r.para(o.gfm(o), t, tight, refs, o, out)
    case True{}:
      r.text(String.drop(t, 3n), tight, refs, o, Bool.pick(String, eq(k, 2), "<input checked=\"\" disabled=\"\" type=\"checkbox\">", "<input disabled=\"\" type=\"checkbox\">"), out)

# out is reversed. tight: these kids are the children of an item in a tight list.
def r.go(ks: List<&2, Kid>, +tight: Bool, +refs: List<&2, Ref>, +o: Opts, +out: String) -> String:
  match ks:
    case Nil{}:
      out
    case Con{Kid{l, BPara{t}}, rest}:
      r.go(rest, tight, refs, o, r.para(o.gfm(o), t, tight, refs, o, out))
    case Con{Kid{l, BHead{+lv, t}}, rest}:
      r.go(rest, tight, refs, o, put(">\n", put(U32.show(lv), put("</h", put(inline(t, refs, o), put(">", put(U32.show(lv), put("<h", cr(out)))))))))
    case Con{Kid{l, BCode{info, t}}, rest}:
      r.go(rest, tight, refs, o, put("</code></pre>\n", put(esc(t), put(code_open(info), cr(out)))))
    case Con{Kid{l, BHtml{t}}, rest}:
      r.go(rest, tight, refs, o, cr(put(html_out(o, t), cr(out))))
    case Con{Kid{l, BRule{}}, rest}:
      r.go(rest, tight, refs, o, put("<hr />\n", cr(out)))
    case Con{Kid{l, BQuote{inner}}, rest}:
      r.go(rest, tight, refs, o, put("</blockquote>\n", cr(r.go(inner, False{}, refs, o, put("<blockquote>\n", cr(out))))))
    case Con{Kid{l, BList{+ord, start, lt, items}}, rest}:
      r.go(rest, tight, refs, o, put(Bool.pick(String, ord, "</ol>\n", "</ul>\n"), r.go(items, lt, refs, o, put(list_open(ord, start), cr(out)))))
    case Con{Kid{l, BItem{k, s, Con{Kid{l2, BPara{+t}}, more}}}, rest}:
      +tk = task.kind(o.gfm(o), t)
      +first = r.first(Bool.not(eq(tk, 0)), tk, t, tight, refs, o, put("<li>", cr(out)))
      r.go(rest, tight, refs, o, put("</li>\n", r.go(more, tight, refs, o, first)))
    case Con{Kid{l, BItem{k, s, inner}}, rest}:
      r.go(rest, tight, refs, o, put("</li>\n", r.go(inner, tight, refs, o, put("<li>", cr(out)))))

def render(+o: Opts, r: List<&2, Kid> & List<&2, Ref>) -> String:
  (ks, refs) = r
  String.reverse(r.go(ks, False{}, refs, o, SNil{}))

# Markdown to HTML with options: o.safe for untrusted input, o.gfm for GitHub tables, task lists, strikethrough, extended autolinks, and the tag filter.
def to_html_with(o: Opts, s: String) -> String:
  render(o, blocks(s))

# CommonMark to HTML. Raw HTML and every URL pass through, as the spec requires.
def to_html(s: String) -> String:
  to_html_with(Opts{False{}, False{}}, s)

# CommonMark to HTML for untrusted input, as cmark renders without --unsafe: raw HTML becomes a comment, and a javascript:, vbscript:, file:, or data: URL becomes empty.
def to_html_safe(s: String) -> String:
  to_html_with(Opts{True{}, False{}}, s)
