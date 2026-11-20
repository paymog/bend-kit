# Linear-time regular expressions: RE2 syntax, Pike VM, capture groups. Source: https://github.com/paymog/bend-kit/tree/main/regex
import Base
import bend-kit-unicode@0.1.0.0/unicode.bend as U
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import ./fold.bend as F

# Positions count code points of the String, not octets.
# Leftmost-first semantics, as RE2 and Perl: the first alternative that matches wins.

# Syntax
# ------

# A set member: a code point range, or a Unicode general category ("L", "Lu", ...).
# Fold, under (?i): the code points whose simple case folding class meets items
# (complemented when neg). Its items are Rng and Prop only.
type Item is Data:
  Rng{lo: U32, hi: U32}
  Prop{neg: Bool, name: String}
  Fold{neg: Bool, items: List<&2, Item>}

# Assertion kinds: 0 start of text, 1 end of text, 2 word boundary, 3 not a word boundary.
type Node is Data:
  NEmpty{}
  NSet{neg: Bool, items: List<&2, Item>}
  NAssert{k: U32}
  NCat{a: Node, b: Node}
  NAlt{a: Node, b: Node}
  NPlus{greedy: Bool, a: Node}
  NQuest{greedy: Bool, a: Node}
  NGroup{i: U32, a: Node}

type Tok is Data:
  TAtom{n: Node}
  TOpen{cap: Bool}
  TClose{}
  TBar{}
  TRep{min: U32, max: Maybe<&2, U32>, greedy: Bool}

def lit(+c: U32) -> Node:
  NSet{False{}, [Rng{c, c}]}

# Case folding (?i)
# -----------------

def fold.points(xs: List<&2, U32>, acc: List<&2, Item>) -> List<&2, Item>:
  match xs:
    case Nil{}:
      acc
    case Con{+x, t}:
      fold.points(t, Rng{x, x} <> acc)

# c and the code points equivalent to it, as one-point ranges.
def fold.point(+c: U32) -> List<&2, Item>:
  Rng{c, c} <> fold.points(F.others(c), Nil{})

def lit.f(fold: Bool, +c: U32) -> Node:
  match fold:
    case True{}:
      NSet{False{}, fold.point(c)}
    case False{}:
      lit(c)

def fold.rng(one: Bool, +lo: U32, +hi: U32) -> List<&2, Item>:
  match one:
    case True{}:
      fold.point(lo)
    case False{}:
      [Fold{False{}, [Rng{lo, hi}]}]

# A class member under (?i). Escapes come back from esc already folded.
def fold.item(i: Item) -> List<&2, Item>:
  match i:
    case Rng{+lo, +hi}:
      fold.rng(U32.is_eq(lo, hi), lo, hi)
    case Prop{neg, name}:
      [Fold{neg, [Prop{False{}, name}]}]
    case Fold{neg, xs}:
      [Fold{neg, xs}]

def fold.items(xs: List<&2, Item>) -> List<&2, Item>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      List.append(&2, Item, fold.item(h), fold.items(t))

def fold.class(fold: Bool, items: List<&2, Item>) -> List<&2, Item>:
  match fold:
    case True{}:
      fold.items(items)
    case False{}:
      items

def is_digit(+c: U32) -> Bool:
  U32.is_le(48, c) && U32.is_le(c, 57)

def is_word(+c: U32) -> Bool:
  is_digit(c) || (U32.is_le(65, c) && U32.is_le(c, 90)) || (U32.is_le(97, c) && U32.is_le(c, 122)) || U32.is_eq(c, 95)

def is_alnum(+c: U32) -> Bool:
  Bool.and(is_word(c), U32.is_ne(c, 95))

# \d \w \s are ASCII, as in RE2.
def perl.d() -> List<&2, Item>:
  [Rng{48, 57}]

def perl.D() -> List<&2, Item>:
  [Rng{0, 47}, Rng{58, 1114111}]

def perl.w() -> List<&2, Item>:
  [Rng{48, 57}, Rng{65, 90}, Rng{95, 95}, Rng{97, 122}]

def perl.W() -> List<&2, Item>:
  [Rng{0, 47}, Rng{58, 64}, Rng{91, 94}, Rng{96, 96}, Rng{123, 1114111}]

def perl.s() -> List<&2, Item>:
  [Rng{9, 10}, Rng{12, 13}, Rng{32, 32}]

def perl.S() -> List<&2, Item>:
  [Rng{0, 8}, Rng{11, 11}, Rng{14, 31}, Rng{33, 1114111}]

def cats() -> List<&2, String>:
  ["L", "Lu", "Ll", "Lt", "Lm", "Lo", "M", "Mn", "Mc", "Me", "N", "Nd", "Nl", "No",
   "P", "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po", "S", "Sm", "Sc", "Sk", "So",
   "Z", "Zs", "Zl", "Zp", "C", "Cc", "Cf", "Cs", "Co", "Cn"]

# Escapes
# -------

type Esc is Data:
  EPoint{c: U32, rest: String}
  EItems{items: List<&2, Item>, rest: String}
  EAssert{k: U32, rest: String}
  EBad{}

def prop.if(ok: Bool, neg: Bool, name: String, t: String) -> Esc:
  match ok:
    case True{}:
      EItems{[Prop{neg, name}], t}
    case False{}:
      EBad{}

def prop.ok(neg: Bool, +name: String, t: String) -> Esc:
  prop.if(List.contains(~String, ~String.eq, cats(), name), neg, name, t)

def prop.name(s: String, neg: Bool, acc: String) -> Esc:
  match s:
    case SNil{}:
      EBad{}
    case SCon{'}', t}:
      prop.ok(neg, String.reverse(acc), t)
    case SCon{c, t}:
      prop.name(t, neg, SCon{c, acc})

# \pL or \p{Lu}; \P negates.
def prop(neg: Bool, s: String) -> Esc:
  match s:
    case SNil{}:
      EBad{}
    case SCon{'{', t}:
      prop.name(t, neg, SNil{})
    case SCon{c, t}:
      prop.ok(neg, SCon{c, SNil{}}, t)

# Under (?i), \p{X} is every code point equivalent to one in X, and \P{X} the rest.
def prop.fold(fold: Bool, e: Esc) -> Esc:
  match fold:
    case False{}:
      e
    case True{}:
      match e:
        case EItems{xs, t}:
          EItems{fold.items(xs), t}
        case EPoint{c, t}:
          EPoint{c, t}
        case EAssert{k, t}:
          EAssert{k, t}
        case EBad{}:
          EBad{}

# \w under (?i) adds the Kelvin sign and long s; \W loses them. \d and \s have no case.
def perl.w.f(fold: Bool) -> List<&2, Item>:
  match fold:
    case True{}:
      [Fold{False{}, perl.w()}]
    case False{}:
      perl.w()

def perl.W.f(fold: Bool) -> List<&2, Item>:
  match fold:
    case True{}:
      [Fold{True{}, perl.w()}]
    case False{}:
      perl.W()

# An escaped letter or digit with no meaning is an error, as in RE2.
def esc.other(alnum: Bool, +c: U32, t: String) -> Esc:
  match alnum:
    case True{}:
      EBad{}
    case False{}:
      EPoint{c, t}

# The text after a backslash; fold under (?i).
def esc(+fold: Bool, s: String) -> Esc:
  match s:
    case SNil{}:
      EBad{}
    case SCon{'d', t}:
      EItems{perl.d(), t}
    case SCon{'D', t}:
      EItems{perl.D(), t}
    case SCon{'w', t}:
      EItems{perl.w.f(fold), t}
    case SCon{'W', t}:
      EItems{perl.W.f(fold), t}
    case SCon{'s', t}:
      EItems{perl.s(), t}
    case SCon{'S', t}:
      EItems{perl.S(), t}
    case SCon{'p', t}:
      prop.fold(fold, prop(False{}, t))
    case SCon{'P', t}:
      prop.fold(fold, prop(True{}, t))
    case SCon{'A', t}:
      EAssert{0, t}
    case SCon{'z', t}:
      EAssert{1, t}
    case SCon{'b', t}:
      EAssert{2, t}
    case SCon{'B', t}:
      EAssert{3, t}
    case SCon{'n', t}:
      EPoint{10, t}
    case SCon{'t', t}:
      EPoint{9, t}
    case SCon{'r', t}:
      EPoint{13, t}
    case SCon{'f', t}:
      EPoint{12, t}
    case SCon{'v', t}:
      EPoint{11, t}
    case SCon{Chr{+c}, t}:
      esc.other(is_alnum(c), c, t)

# Classes
# -------

type Cs is Data:
  CsGo{s: String, first: Bool, items: List<&2, Item>}
  CsDone{items: List<&2, Item>, rest: String}
  CsFail{}

def class.range(ok: Bool, +c: U32, +d: U32, u: String, items: List<&2, Item>) -> Cs:
  match ok:
    case True{}:
      CsGo{u, False{}, Rng{c, d} <> items}
    case False{}:
      CsFail{}

def class.hi(e: Esc, +c: U32, items: List<&2, Item>) -> Cs:
  match e:
    case EPoint{+d, u}:
      class.range(U32.is_le(c, d), c, d, u, items)
    case EItems{xs, u}:
      CsFail{}
    case EAssert{k, u}:
      CsFail{}
    case EBad{}:
      CsFail{}

# c is one member; a "-" and a code point after it make a range.
def class.lo(+c: U32, t: String, items: List<&2, Item>) -> Cs:
  match t:
    case SCon{'-', SCon{']', u}}:
      CsDone{Rng{45, 45} <> Rng{c, c} <> items, u}
    case SCon{'-', SCon{'\\', u}}:
      class.hi(esc(False{}, u), c, items)
    case SCon{'-', SCon{Chr{+d}, u}}:
      class.range(U32.is_le(c, d), c, d, u, items)
    case _:
      CsGo{t, False{}, Rng{c, c} <> items}

def class.esc(e: Esc, items: List<&2, Item>) -> Cs:
  match e:
    case EPoint{+c, t}:
      class.lo(c, t, items)
    case EItems{xs, t}:
      CsGo{t, False{}, List.append(&2, Item, xs, items)}
    case EAssert{k, t}:
      CsFail{}
    case EBad{}:
      CsFail{}

# A "]" right after "[" or "[^" is a member.
def class.step(+fold: Bool, s: String, first: Bool, items: List<&2, Item>) -> Cs:
  match s:
    case SNil{}:
      CsFail{}
    case SCon{']', t}:
      match first:
        case True{}:
          class.lo(93, t, items)
        case False{}:
          CsDone{items, t}
    case SCon{'\\', t}:
      class.esc(esc(fold, t), items)
    case SCon{Chr{+c}, t}:
      class.lo(c, t, items)

# fuel: every step eats at least one char.
def class.run(fuel: Nat, +fold: Bool, st: Cs) -> Cs:
  match fuel:
    case 0n:
      CsFail{}
    case 1n+f:
      match st:
        case CsGo{s, first, items}:
          class.run(f, fold, class.step(fold, s, first, items))
        case CsDone{items, rest}:
          CsDone{items, rest}
        case CsFail{}:
          CsFail{}

def class(+fold: Bool, +s: String, first: Bool) -> Cs:
  class.run(Nat.add(String.length(s), 1n), fold, CsGo{s, first, Nil{}})

# Lexer
# -----

type Lx is Data:
  LGo{s: String, toks: List<&2, Tok>}
  LDone{toks: List<&2, Tok>}
  LFail{}

# A run of decimal digits: its value (capped at 100000), its length, and the rest.
type Num is Data:
  Num{v: U32, n: U32, rest: String}

def num.add(+acc: U32, +c: U32) -> U32:
  Bool.pick(U32, U32.is_lt(acc, 100000), (acc * 10 + (c - 48) : U32), 100000)

def num.go(t: String, +c: U32, +acc: U32, +n: U32, dig: Bool) -> Num:
  match t:
    case SNil{}:
      match dig:
        case True{}:
          Num{num.add(acc, c), (n + 1 : U32), SNil{}}
        case False{}:
          Num{acc, n, SCon{Chr{c}, SNil{}}}
    case SCon{Chr{+d}, u}:
      match dig:
        case True{}:
          num.go(u, d, num.add(acc, c), (n + 1 : U32), is_digit(d))
        case False{}:
          Num{acc, n, SCon{Chr{c}, SCon{Chr{d}, u}}}

def num(s: String) -> Num:
  match s:
    case SNil{}:
      Num{0, 0, SNil{}}
    case SCon{Chr{+c}, t}:
      num.go(t, c, 0, 0, is_digit(c))

# A trailing "?" makes a repetition lazy.
def lex.rep(+min: U32, max: Maybe<&2, U32>, t: String, toks: List<&2, Tok>) -> Lx:
  match t:
    case SCon{'?', u}:
      LGo{u, TRep{min, max, False{}} <> toks}
    case _:
      LGo{t, TRep{min, max, True{}} <> toks}

def Num.n(m: Num) -> U32:
  Num{v, n, r} = m
  n

# A "{" that does not start {n}, {n,} or {n,m} is a literal, as in RE2.
def lex.brace.max(none: Bool, +min: U32, m: Num, orig: String, toks: List<&2, Tok>) -> Lx:
  match none:
    case True{}:
      LGo{orig, TAtom{lit(123)} <> toks}
    case False{}:
      Num{+v, n, r} = m
      match r:
        case SCon{'}', u}:
          lex.rep(min, Some{v}, u, toks)
        case _:
          LGo{orig, TAtom{lit(123)} <> toks}

def lex.brace.min(none: Bool, m: Num, +orig: String, toks: List<&2, Tok>) -> Lx:
  match none:
    case True{}:
      LGo{orig, TAtom{lit(123)} <> toks}
    case False{}:
      Num{+v, n, r} = m
      match r:
        case SCon{'}', u}:
          lex.rep(v, Some{v}, u, toks)
        case SCon{',', SCon{'}', u}}:
          lex.rep(v, None{}, u, toks)
        case SCon{',', u}:
          +m2 = num(u)
          lex.brace.max(U32.is_eq(Num.n(m2), 0), v, m2, orig, toks)
        case _:
          LGo{orig, TAtom{lit(123)} <> toks}

def lex.class(fold: Bool, neg: Bool, r: Cs, toks: List<&2, Tok>) -> Lx:
  match r:
    case CsDone{items, rest}:
      LGo{rest, TAtom{NSet{neg, fold.class(fold, items)}} <> toks}
    case CsGo{s, first, items}:
      LFail{}
    case CsFail{}:
      LFail{}

def lex.esc(fold: Bool, e: Esc, toks: List<&2, Tok>) -> Lx:
  match e:
    case EPoint{c, t}:
      LGo{t, TAtom{lit.f(fold, c)} <> toks}
    case EItems{xs, t}:
      LGo{t, TAtom{NSet{False{}, xs}} <> toks}
    case EAssert{k, t}:
      LGo{t, TAtom{NAssert{k}} <> toks}
    case EBad{}:
      LFail{}

def lex.step(+fold: Bool, s: String, toks: List<&2, Tok>) -> Lx:
  match s:
    case SNil{}:
      LDone{toks}
    case SCon{'\\', t}:
      lex.esc(fold, esc(fold, t), toks)
    case SCon{'[', SCon{'^', t}}:
      lex.class(fold, True{}, class(fold, t, True{}), toks)
    case SCon{'[', t}:
      lex.class(fold, False{}, class(fold, t, True{}), toks)
    case SCon{'(', SCon{'?', SCon{':', t}}}:
      LGo{t, TOpen{False{}} <> toks}
    case SCon{'(', SCon{'?', t}}:
      LFail{}
    case SCon{'(', t}:
      LGo{t, TOpen{True{}} <> toks}
    case SCon{')', t}:
      LGo{t, TClose{} <> toks}
    case SCon{'|', t}:
      LGo{t, TBar{} <> toks}
    case SCon{'*', t}:
      lex.rep(0, None{}, t, toks)
    case SCon{'+', t}:
      lex.rep(1, None{}, t, toks)
    case SCon{'?', t}:
      lex.rep(0, Some{1}, t, toks)
    case SCon{'{', +t}:
      +m = num(t)
      lex.brace.min(U32.is_eq(Num.n(m), 0), m, t, toks)
    case SCon{'.', t}:
      LGo{t, TAtom{NSet{True{}, [Rng{10, 10}]}} <> toks}
    case SCon{'^', t}:
      LGo{t, TAtom{NAssert{0}} <> toks}
    case SCon{'$', t}:
      LGo{t, TAtom{NAssert{1}} <> toks}
    case SCon{Chr{+c}, t}:
      LGo{t, TAtom{lit.f(fold, c)} <> toks}

# fuel: every step but the last eats at least one char.
def lex(fuel: Nat, +fold: Bool, st: Lx) -> Maybe<&2, List<&2, Tok>>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      match st:
        case LGo{s, toks}:
          lex(f, fold, lex.step(fold, s, toks))
        case LDone{toks}:
          Some{List.reverse(&2, Tok, toks)}
        case LFail{}:
          None{}

# Parser
# ------

# An open group: its capture index (None for (?:...)), and the enclosing alternatives and sequence.
type Frame is Data:
  Frame{cap: Maybe<&2, U32>, alts: List<&2, Node>, cur: List<&2, Node>}

# n: the next capture index. rep: the last token was a repetition. alts and cur are reversed.
type Ps is Data:
  Ps{n: U32, rep: Bool, stack: List<&2, Frame>, alts: List<&2, Node>, cur: List<&2, Node>}
  PsFail{}
def cat(a: Node, b: Node) -> Node:
  match a:
    case NEmpty{}:
      b
    case _:
      match b:
        case NEmpty{}:
          a
        case _:
          NCat{a, b}

def seq.go(xs: List<&2, Node>, acc: Node) -> Node:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      seq.go(t, cat(h, acc))

def seq(xs: List<&2, Node>) -> Node:
  seq.go(xs, NEmpty{})

def alt.go(xs: List<&2, Node>, acc: Node) -> Node:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      alt.go(t, NAlt{h, acc})

def group(cap: Maybe<&2, U32>, a: Node) -> Node:
  match cap:
    case None{}:
      a
    case Some{i}:
      NGroup{i, a}

def rep.copies(k: Nat, +h: Node, acc: Node) -> Node:
  match k:
    case 0n:
      acc
    case 1n+p:
      rep.copies(p, h, cat(h, acc))

def rep.opt(k: Nat, +g: Bool, +h: Node) -> Node:
  match k:
    case 0n:
      NEmpty{}
    case 1n+p:
      NQuest{g, cat(h, rep.opt(p, g, h))}

# x* is (x+)?, so an empty x cannot loop; x{n,} is n-1 copies then x+; x{n,m} is n copies then (x(x...)?)?, as RE2 builds them.
def rep.inf(k: Nat, +g: Bool, +h: Node) -> Node:
  match k:
    case 0n:
      NQuest{g, NPlus{g, h}}
    case 1n+p:
      rep.copies(p, h, NPlus{g, h})

def rep.fin(max: Maybe<&2, U32>, +min: U32, +g: Bool, +h: Node) -> Node:
  match max:
    case None{}:
      rep.inf(U32.to_nat(min), g, h)
    case Some{m}:
      rep.copies(U32.to_nat(min), h, rep.opt(U32.to_nat((m - min : U32)), g, h))

def rep(+h: Node, +min: U32, max: Maybe<&2, U32>, +g: Bool) -> Node:
  rep.fin(max, min, g, h)

# Counts go up to 1000, and a repetition cannot repeat, as in RE2.
def rep.ok(+min: U32, max: Maybe<&2, U32>) -> Bool:
  match max:
    case None{}:
      U32.is_le(min, 1000)
    case Some{+m}:
      U32.is_le(m, 1000) && U32.is_le(min, m)

def parse.rep(ok: Bool, cur: List<&2, Node>, +min: U32, max: Maybe<&2, U32>, +g: Bool, +n: U32, stack: List<&2, Frame>, alts: List<&2, Node>) -> Ps:
  match ok:
    case False{}:
      PsFail{}
    case True{}:
      match cur:
        case Nil{}:
          PsFail{}
        case Con{h, t}:
          Ps{n, True{}, stack, alts, rep(h, min, max, g) <> t}

def parse.open(cap: Bool, +n: U32, stack: List<&2, Frame>, alts: List<&2, Node>, cur: List<&2, Node>) -> Ps:
  match cap:
    case True{}:
      Ps{(n + 1 : U32), False{}, Frame{Some{n}, alts, cur} <> stack, Nil{}, Nil{}}
    case False{}:
      Ps{n, False{}, Frame{None{}, alts, cur} <> stack, Nil{}, Nil{}}

def parse.close(stack: List<&2, Frame>, +n: U32, alts: List<&2, Node>, cur: List<&2, Node>) -> Ps:
  match stack:
    case Nil{}:
      PsFail{}
    case Con{Frame{cap, fa, fc}, up}:
      Ps{n, False{}, up, fa, group(cap, alt.go(alts, seq(cur))) <> fc}

def parse.tok(tok: Tok, +n: U32, rep: Bool, stack: List<&2, Frame>, alts: List<&2, Node>, cur: List<&2, Node>) -> Ps:
  match tok:
    case TAtom{a}:
      Ps{n, False{}, stack, alts, a <> cur}
    case TRep{+min, +max, g}:
      parse.rep(Bool.and(Bool.not(rep), rep.ok(min, max)), cur, min, max, g, n, stack, alts)
    case TOpen{cap}:
      parse.open(cap, n, stack, alts, cur)
    case TClose{}:
      parse.close(stack, n, alts, cur)
    case TBar{}:
      Ps{n, False{}, stack, seq(cur) <> alts, Nil{}}

def parse.step(st: Ps, tok: Tok) -> Ps:
  match st:
    case PsFail{}:
      PsFail{}
    case Ps{n, rep, stack, alts, cur}:
      parse.tok(tok, n, rep, stack, alts, cur)

def parse(toks: List<&2, Tok>, st: Ps) -> Ps:
  match toks:
    case Nil{}:
      st
    case Con{tok, t}:
      parse(t, parse.step(st, tok))

# Compiler
# --------

type Inst is Data:
  ISet{neg: Bool, items: List<&2, Item>}
  IAssert{k: U32}
  ISplit{x: U32, y: U32}
  IJmp{x: U32}
  ISave{k: U32}
  IMatch{}

# A byte that every match must contain. Optional branches and character classes have none.
def required.right(b: Maybe<&2, U32>, a: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match b:
    case Some{c}:
      Some{c}
    case None{}:
      a

def required(n: Node) -> Maybe<&2, U32>:
  match n:
    case NEmpty{}:
      None{}
    case NSet{False{}, Con{Rng{+lo, +hi}, Nil{}}}:
      Bool.pick(Maybe<&2, U32>, U32.is_eq(lo, hi) && U32.is_lt(lo, 128), Some{lo}, None{})
    case NSet{neg, items}:
      None{}
    case NAssert{k}:
      None{}
    case NCat{a, b}:
      required.right(required(b), required(a))
    case NAlt{a, b}:
      None{}
    case NPlus{g, a}:
      required(a)
    case NQuest{g, a}:
      None{}
    case NGroup{i, a}:
      required(a)

def required.join(right: Maybe<&2, Node>, left: Maybe<&2, Node>, a: Node) -> Maybe<&2, Node>:
  match right:
    case Some{r}:
      Some{NCat{a, r}}
    case None{}:
      left

# The first iteration contains the selected literal; every occurrence is inspected.
def required.prefix(n: Node) -> Maybe<&2, Node>:
  match n:
    case NSet{False{}, Con{Rng{+lo, +hi}, Nil{}}}:
      Bool.pick(Maybe<&2, Node>, U32.is_eq(lo, hi) && U32.is_lt(lo, 128), Some{lit(lo)}, None{})
    case NCat{+a, b}:
      required.join(required.prefix(b), required.prefix(a), a)
    case NPlus{g, a}:
      required.prefix(a)
    case NGroup{i, a}:
      required.prefix(a)
    case _:
      None{}

def reverse.ok(n: Node) -> Bool:
  match n:
    case NAssert{k}:
      False{}
    case NCat{a, b}:
      reverse.ok(a) && reverse.ok(b)
    case NAlt{a, b}:
      reverse.ok(a) && reverse.ok(b)
    case NPlus{g, a}:
      reverse.ok(a)
    case NQuest{g, a}:
      reverse.ok(a)
    case NGroup{i, a}:
      reverse.ok(a)
    case _:
      True{}

def reverse.node(n: Node) -> Node:
  match n:
    case NCat{a, b}:
      NCat{reverse.node(b), reverse.node(a)}
    case NAlt{a, b}:
      NAlt{reverse.node(a), reverse.node(b)}
    case NPlus{g, a}:
      NPlus{g, reverse.node(a)}
    case NQuest{g, a}:
      NQuest{g, reverse.node(a)}
    case NGroup{i, a}:
      reverse.node(a)
    case other:
      other

def size(n: Node) -> U32:
  match n:
    case NEmpty{}:
      0
    case NSet{neg, items}:
      1
    case NAssert{k}:
      1
    case NCat{a, b}:
      (size(a) + size(b) : U32)
    case NAlt{a, b}:
      (2 + size(a) + size(b) : U32)
    case NPlus{g, a}:
      (1 + size(a) : U32)
    case NQuest{g, a}:
      (1 + size(a) : U32)
    case NGroup{i, a}:
      (2 + size(a) : U32)

# The instructions of n, placed at pc, in front of rest. ISplit tries x first.
def emit(n: Node, +pc: U32, rest: List<&2, Inst>) -> List<&2, Inst>:
  match n:
    case NEmpty{}:
      rest
    case NSet{neg, items}:
      ISet{neg, items} <> rest
    case NAssert{k}:
      IAssert{k} <> rest
    case NCat{+a, b}:
      emit(a, pc, emit(b, (pc + size(a) : U32), rest))
    case NAlt{+a, +b}:
      +j = (pc + 1 + size(a) : U32)
      ISplit{(pc + 1 : U32), (j + 1 : U32)} <> emit(a, (pc + 1 : U32), IJmp{(j + 1 + size(b) : U32)} <> emit(b, (j + 1 : U32), rest))
    case NPlus{+g, +a}:
      +out = (pc + 1 + size(a) : U32)
      emit(a, pc, ISplit{Bool.pick(U32, g, pc, out), Bool.pick(U32, g, out, pc)} <> rest)
    case NQuest{+g, +a}:
      +out = (pc + 1 + size(a) : U32)
      ISplit{Bool.pick(U32, g, (pc + 1 : U32), out), Bool.pick(U32, g, out, (pc + 1 : U32))} <> emit(a, (pc + 1 : U32), rest)
    case NGroup{+i, a}:
      ISave{(2 * i : U32)} <> emit(a, (pc + 1 : U32), ISave{(2 * i + 1 : U32)} <> rest)

# A binary trie keyed by n >= 1: the path is the bits of n below its top bit, low bit
# first, so key n costs log2(n) steps and small keys stay near the root.
type Trie<-V: Data> is Data:
  TTip{}
  TNode{val: Maybe<&2, V>, lo: Trie<V>, hi: Trie<V>}

# here: n is 1. left: n is even.
def trie.get(-V: Data, t: Trie<V>, here: Bool, left: Bool, +n: U32) -> Maybe<&2, V>:
  match t:
    case TTip{}:
      None{}
    case TNode{v, lo, hi}:
      match here:
        case True{}:
          v
        case False{}:
          match left:
            case True{}:
              trie.get(V, lo, U32.is_eq(U32.shr(n), 1), U32.is_even(U32.shr(n)), U32.shr(n))
            case False{}:
              trie.get(V, hi, U32.is_eq(U32.shr(n), 1), U32.is_even(U32.shr(n)), U32.shr(n))

# fuel: a U32 key has at most 32 bits.
def trie.put(-V: Data, fuel: Nat, t: Trie<V>, here: Bool, left: Bool, +n: U32, v: V) -> Trie<V>:
  match fuel:
    case 0n:
      t
    case 1n+f:
      match t:
        case TNode{x, lo, hi}:
          match here:
            case True{}:
              TNode{Some{v}, lo, hi}
            case False{}:
              match left:
                case True{}:
                  TNode{x, trie.put(V, f, lo, U32.is_eq(U32.shr(n), 1), U32.is_even(U32.shr(n)), U32.shr(n), v), hi}
                case False{}:
                  TNode{x, lo, trie.put(V, f, hi, U32.is_eq(U32.shr(n), 1), U32.is_even(U32.shr(n)), U32.shr(n), v)}
        case TTip{}:
          match here:
            case True{}:
              TNode{Some{v}, TTip{}, TTip{}}
            case False{}:
              match left:
                case True{}:
                  TNode{None{}, trie.put(V, f, TTip{}, U32.is_eq(U32.shr(n), 1), U32.is_even(U32.shr(n)), U32.shr(n), v), TTip{}}
                case False{}:
                  TNode{None{}, TTip{}, trie.put(V, f, TTip{}, U32.is_eq(U32.shr(n), 1), U32.is_even(U32.shr(n)), U32.shr(n), v)}

# The value at key k, stored as n = k + 1.
def trie.at(-V: Data, t: Trie<V>, +k: U32) -> Maybe<&2, V>:
  +n = (k + 1 : U32)
  trie.get(V, t, U32.is_eq(n, 1), U32.is_even(n), n)

def trie.set(-V: Data, t: Trie<V>, +k: U32, v: V) -> Trie<V>:
  +n = (k + 1 : U32)
  trie.put(V, 32n, t, U32.is_eq(n, 1), U32.is_even(n), n, v)

def trie.from(-V: Data, xs: List<&2, V>, +k: U32, t: Trie<V>) -> Trie<V>:
  match xs:
    case Nil{}:
      t
    case Con{h, r}:
      trie.from(V, r, (k + 1 : U32), trie.set(V, t, k, h))

# The walk from pc 0 over the instructions that consume no char: the sets it reaches, or
# FsAny when it reaches a match, so that any char may start a match. thru: an assertion
# passes on to the next pc, as if it held; else it ends the walk with FsAny too.
type Fs is Data:
  Fs{stack: List<&2, U32>, seen: List<&2, U32>, sets: List<&2, Inst>}
  FsAny{}

def first.inst(thru: Bool, i: Maybe<&2, Inst>, +pc: U32, stack: List<&2, U32>, seen: List<&2, U32>, sets: List<&2, Inst>) -> Fs:
  match i:
    case Some{IAssert{k}}:
      Bool.pick(Fs, thru, Fs{(pc + 1 : U32) <> stack, seen, sets}, FsAny{})
    case Some{IJmp{x}}:
      Fs{x <> stack, seen, sets}
    case Some{ISplit{x, y}}:
      Fs{x <> y <> stack, seen, sets}
    case Some{ISave{k}}:
      Fs{(pc + 1 : U32) <> stack, seen, sets}
    case Some{ISet{neg, items}}:
      Fs{stack, seen, ISet{neg, items} <> sets}
    case _:
      FsAny{}

def first.seen(+thru: Bool, hit: Bool, +prog: List<&2, Inst>, +pc: U32, stack: List<&2, U32>, seen: List<&2, U32>, sets: List<&2, Inst>) -> Fs:
  match hit:
    case True{}:
      Fs{stack, seen, sets}
    case False{}:
      first.inst(thru, List.get(&2, Inst, prog, U32.to_nat(pc)), pc, stack, pc <> seen, sets)

# fuel: each pc expands once and pushes at most two pcs.
def first(fuel: Nat, +thru: Bool, +prog: List<&2, Inst>, st: Fs) -> Maybe<&2, List<&2, Inst>>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      match st:
        case FsAny{}:
          None{}
        case Fs{Nil{}, seen, sets}:
          Some{sets}
        case Fs{Con{+pc, t}, +seen, sets}:
          first(f, thru, prog, first.seen(thru, List.contains(~U32, ~U32.is_eq, seen, pc), prog, pc, t, seen, sets))

# Bit-parallel NFA for is_match: bit pc stands for the set at pc, waiting on the next char.
# The epsilon walk from a pc: the sets it reaches and whether it reaches the match, where at0
# says the position is the start of the text and at1 the end.
type Ew is Data:
  Ew{stack: List<&2, U32>, seen: List<&2, U32>, mask: U32, hit: Bool}

def eps.ctx(k: U32, +at0: Bool, +at1: Bool) -> Bool:
  match k:
    case 0:
      at0
    case 1:
      at1
    case _:
      False{}

def eps.assert(ok: Bool, +pc: U32, stack: List<&2, U32>, seen: List<&2, U32>, mask: U32, hit: Bool) -> Ew:
  match ok:
    case True{}:
      Ew{(pc + 1 : U32) <> stack, seen, mask, hit}
    case False{}:
      Ew{stack, seen, mask, hit}

def eps.inst(i: Maybe<&2, Inst>, +pc: U32, +at0: Bool, +at1: Bool, stack: List<&2, U32>, seen: List<&2, U32>, +mask: U32, hit: Bool) -> Ew:
  match i:
    case Some{IJmp{x}}:
      Ew{x <> stack, seen, mask, hit}
    case Some{ISplit{x, y}}:
      Ew{x <> y <> stack, seen, mask, hit}
    case Some{ISave{k}}:
      Ew{(pc + 1 : U32) <> stack, seen, mask, hit}
    case Some{IAssert{k}}:
      eps.assert(eps.ctx(k, at0, at1), pc, stack, seen, mask, hit)
    case Some{ISet{neg, items}}:
      Ew{stack, seen, (mask .|. (1 << U32.to_nat(pc)) : U32), hit}
    case Some{IMatch{}}:
      Ew{stack, seen, mask, True{}}
    case None{}:
      Ew{stack, seen, mask, hit}

def eps.seen(hit: Bool, +prog: List<&2, Inst>, +pc: U32, +at0: Bool, +at1: Bool, w: Ew) -> Ew:
  match hit:
    case True{}:
      w
    case False{}:
      Ew{stack, seen, mask, h} = w
      eps.inst(List.get(&2, Inst, prog, U32.to_nat(pc)), pc, at0, at1, stack, pc <> seen, mask, h)

# fuel: each pc expands once and pushes at most two pcs.
def eps.go(fuel: Nat, +prog: List<&2, Inst>, +at0: Bool, +at1: Bool, w: Ew) -> Ew:
  match fuel:
    case 0n:
      w
    case 1n+f:
      match w:
        case Ew{Nil{}, seen, mask, hit}:
          Ew{Nil{}, seen, mask, hit}
        case Ew{Con{+pc, t}, +seen, mask, hit}:
          eps.go(f, prog, at0, at1, eps.seen(List.contains(~U32, ~U32.is_eq, seen, pc), prog, pc, at0, at1, Ew{t, seen, mask, hit}))

def eps(+fuel: Nat, +prog: List<&2, Inst>, +pc: U32, +at0: Bool, +at1: Bool) -> Ew:
  eps.go(fuel, prog, at0, at1, Ew{[pc], Nil{}, 0, False{}})

def Ew.mask(w: Ew) -> U32:
  Ew{s, v, mask, hit} = w
  mask

def Ew.hit(w: Ew) -> Bool:
  Ew{s, v, mask, hit} = w
  hit

# The set at bit mask; follow: the sets live after it takes a char; fin, end: whether the match
# is then reached inside the text, or at its end.
type Bit is Data:
  Bit{mask: U32, neg: Bool, items: List<&2, Item>, follow: U32, fin: Bool, end: Bool}

# at0: the sets live at the start of the text, and hit0 whether the empty match is there;
# hit01 the same for the empty text; atn and hitn the same inside the text, hit1 at its end.
type Bits is Data:
  Bits{sets: List<&2, Bit>, at0: U32, hit0: Bool, hit01: Bool, atn: U32, hit1: Bool}

def bits.set(+fuel: Nat, +prog: List<&2, Inst>, +pc: U32, neg: Bool, items: List<&2, Item>) -> Bit:
  +w = eps(fuel, prog, (pc + 1 : U32), False{}, False{})
  Bit{(1 << U32.to_nat(pc) : U32), neg, items, Ew.mask(w), Ew.hit(w), Ew.hit(eps(fuel, prog, (pc + 1 : U32), False{}, True{}))}

def bits.sets(xs: List<&2, Inst>, +fuel: Nat, +prog: List<&2, Inst>, +pc: U32) -> List<&2, Bit>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{ISet{neg, items}, t}:
      bits.set(fuel, prog, pc, neg, items) <> bits.sets(t, fuel, prog, (pc + 1 : U32))
    case Con{i, t}:
      bits.sets(t, fuel, prog, (pc + 1 : U32))

# Word boundaries depend on the chars on both sides, which one mask per set cannot track.
def bits.plain(xs: List<&2, Inst>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{IAssert{+k}, t}:
      U32.is_lt(k, 2) && bits.plain(t)
    case Con{i, t}:
      bits.plain(t)

def bits.if(ok: Bool, +fuel: Nat, +prog: List<&2, Inst>) -> Maybe<&2, Bits>:
  match ok:
    case False{}:
      None{}
    case True{}:
      +w0 = eps(fuel, prog, 0, True{}, False{})
      +wn = eps(fuel, prog, 0, False{}, False{})
      Some{Bits{bits.sets(prog, fuel, prog, 0), Ew.mask(w0), Ew.hit(w0), Ew.hit(eps(fuel, prog, 0, True{}, True{})), Ew.mask(wn), Ew.hit(eps(fuel, prog, 0, False{}, True{}))}}

def bits(+fuel: Nat, +prog: List<&2, Inst>) -> Maybe<&2, Bits>:
  bits.if(Nat.is_le(List.length(&2, Inst, prog), 32n) && bits.plain(prog), fuel, prog)

# A Rng or Prop; a Fold never nests.
def item.plain(i: Item, +c: U32) -> Bool:
  match i:
    case Rng{+lo, +hi}:
      U32.is_le(lo, c) && U32.is_le(c, hi)
    case Prop{neg, name}:
      Bool.xor(neg, String.starts_with(U.category(Chr{c}), name))
    case Fold{neg, xs}:
      False{}

def items.plain(xs: List<&2, Item>, +c: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      item.plain(h, c) || items.plain(t, c)

def fold.any(os: List<&2, U32>, +xs: List<&2, Item>) -> Bool:
  match os:
    case Nil{}:
      False{}
    case Con{+o, t}:
      items.plain(xs, o) || fold.any(t, xs)

# The case table is read only when c itself misses.
def fold.has(hit: Bool, +c: U32, +xs: List<&2, Item>) -> Bool:
  match hit:
    case True{}:
      True{}
    case False{}:
      fold.any(F.others(c), xs)

def item.has(i: Item, +c: U32) -> Bool:
  match i:
    case Rng{+lo, +hi}:
      U32.is_le(lo, c) && U32.is_le(c, hi)
    case Prop{neg, name}:
      Bool.xor(neg, String.starts_with(U.category(Chr{c}), name))
    case Fold{neg, +xs}:
      Bool.xor(neg, fold.has(items.plain(xs, c), c, xs))

def items.has(xs: List<&2, Item>, +c: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      item.has(h, c) || items.has(t, c)

def starts(xs: List<&2, Inst>, +c: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{ISet{neg, set}, t}:
      Bool.xor(neg, items.has(set, c)) || starts(t, c)
    case Con{i, t}:
      starts(t, c)

# The ASCII bytes that may start a match, one bit per byte, 32 to a word.
type Asc is Data:
  Asc{m0: U32, m1: U32, m2: U32, m3: U32}

def asc.bit(hit: Bool, +c: U32, a: Asc) -> Asc:
  match hit:
    case False{}:
      a
    case True{}:
      Asc{+m0, +m1, +m2, +m3} = a
      +b = (1 << U32.to_nat((c .&. 31 : U32)) : U32)
      Asc{Bool.pick(U32, U32.is_eq((c >> 5n : U32), 0), (m0 .|. b : U32), m0), Bool.pick(U32, U32.is_eq((c >> 5n : U32), 1), (m1 .|. b : U32), m1), Bool.pick(U32, U32.is_eq((c >> 5n : U32), 2), (m2 .|. b : U32), m2), Bool.pick(U32, U32.is_eq((c >> 5n : U32), 3), (m3 .|. b : U32), m3)}

# The bits a..b of a word, or none when out.
def rng.mask(out: Bool, +a: U32, +b: U32) -> U32:
  match out:
    case True{}:
      0
    case False{}:
      ((4294967295 << U32.to_nat(a) : U32) .&. U32.shrn(4294967295, U32.to_nat((31 - b : U32))) : U32)

# The bytes lo..hi of the word for bytes base to base+31.
def rng.word(+base: U32, +lo: U32, +hi: U32) -> U32:
  +top = (base + 31 : U32)
  rng.mask(U32.is_lt(hi, base) || U32.is_lt(top, lo), (U32.max(lo, base) - base : U32), (Bool.pick(U32, U32.is_lt(hi, top), hi, top) - base : U32))

# c: the byte for step n, counting down from 127 to 0.
def item.scan(n: Nat, +c: U32, +i: Item, a: Asc) -> Asc:
  match n:
    case 0n:
      a
    case 1n+p:
      item.scan(p, (c - 1 : U32), i, asc.bit(item.has(i, c), c, a))

# The ASCII bytes of an item: a range by its bounds, others byte by byte.
def item.asc(i: Item) -> Asc:
  match i:
    case Rng{+lo, +hi}:
      Asc{rng.word(0, lo, hi), rng.word(32, lo, hi), rng.word(64, lo, hi), rng.word(96, lo, hi)}
    case Prop{neg, name}:
      item.scan(128n, 127, Prop{neg, name}, Asc{0, 0, 0, 0})
    case Fold{neg, xs}:
      item.scan(128n, 127, Fold{neg, xs}, Asc{0, 0, 0, 0})

def asc.union(a: Asc, b: Asc) -> Asc:
  Asc{a0, a1, a2, a3} = a
  Asc{b0, b1, b2, b3} = b
  Asc{(a0 .|. b0 : U32), (a1 .|. b1 : U32), (a2 .|. b2 : U32), (a3 .|. b3 : U32)}

def asc.flip(neg: Bool, a: Asc) -> Asc:
  match neg:
    case False{}:
      a
    case True{}:
      Asc{a0, a1, a2, a3} = a
      Asc{U32.not(a0), U32.not(a1), U32.not(a2), U32.not(a3)}

def items.asc(xs: List<&2, Item>, a: Asc) -> Asc:
  match xs:
    case Nil{}:
      a
    case Con{h, t}:
      items.asc(t, asc.union(a, item.asc(h)))

# The ASCII bytes that start sets, as starts finds them.
def sets.asc(xs: List<&2, Inst>, a: Asc) -> Asc:
  match xs:
    case Nil{}:
      a
    case Con{ISet{neg, set}, t}:
      sets.asc(t, asc.union(a, asc.flip(neg, items.asc(set, Asc{0, 0, 0, 0}))))
    case Con{i, t}:
      sets.asc(t, a)

def asc(start: Maybe<&2, List<&2, Inst>>) -> Maybe<&2, Asc>:
  match start:
    case None{}:
      None{}
    case Some{sets}:
      Some{sets.asc(sets, Asc{0, 0, 0, 0})}

def asc.word(k: U32, a: Asc) -> U32:
  match k:
    case 0:
      Asc{m0, m1, m2, m3} = a
      m0
    case 1:
      Asc{m0, m1, m2, m3} = a
      m1
    case 2:
      Asc{m0, m1, m2, m3} = a
      m2
    case _:
      Asc{m0, m1, m2, m3} = a
      m3

# Any non-ASCII byte may start a match: it may lead a char in start.
def asc.has(+b: U32, a: Asc) -> Bool:
  U32.is_le(128, b) || U32.is_ne((U32.shrn(asc.word((b >> 5n : U32), a), U32.to_nat((b .&. 31 : U32))) .&. 1 : U32), 0)

# Required literals
# -----------------
# A literal is a sequence of sets: a text holds it at k when its unit at k+j is in set j for each
# j. Over a String the units are code points; over Bytes they are bytes. A Need is literals one of
# which every match contains, and far: the most units from a match's start to the start of that
# literal, or None when unbounded. A set is a node's own set, so under (?i) it holds every
# equivalent the node matches.
type Need is Data:
  Need{lits: List<&2, List<&2, List<&2, U32>>>, far: Maybe<&2, U32>}

# What every match of a node holds. exact: the literal every match spells out whole, when it has
# at most 32 sets; pre: a literal every match starts with; max: the most units a match takes, None
# when unbounded or past lt.cap(); cand: the best Need inside the node, far counted from its start.
type Lt is Data:
  Lt{exact: Maybe<&2, List<&2, List<&2, U32>>>, pre: List<&2, List<&2, U32>>, max: Maybe<&2, U32>, cand: Maybe<&2, Need>}

def lt.cap() -> U32:
  1048576

def mx.add(a: Maybe<&2, U32>, b: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match a b:
    case Some{+x} Some{+y}:
      Bool.pick(Maybe<&2, U32>, U32.is_le(x, lt.cap()) && U32.is_le(y, lt.cap()) && U32.is_le((x + y : U32), lt.cap()), Some{(x + y : U32)}, None{})
    case _ _:
      None{}

def mx.max(a: Maybe<&2, U32>, b: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match a b:
    case Some{+x} Some{+y}:
      Some{Bool.pick(U32, U32.is_lt(x, y), y, x)}
    case _ _:
      None{}

# The length of the shortest literal of xs, or acc.
def lits.short(xs: List<&2, List<&2, List<&2, U32>>>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{l, t}:
      +n = U32.from_nat(List.length(&2, List<&2, U32>, l))
      lits.short(t, Bool.pick(U32, U32.is_lt(n, acc), n, acc))

# Longer literals first, then a bounded far.
def need.score(n: Need) -> U32:
  Need{lits, far} = n
  ((2 * lits.short(lits, 4294967295)) + Bool.pick(U32, Maybe.is_some(&2, U32, far), 1, 0) : U32)

# The better of a and b; a on a tie.
def need.best(a: Maybe<&2, Need>, b: Maybe<&2, Need>) -> Maybe<&2, Need>:
  match a b:
    case Some{+x} Some{+y}:
      Bool.pick(Maybe<&2, Need>, U32.is_le(need.score(y), need.score(x)), Some{x}, Some{y})
    case Some{x} None{}:
      Some{x}
    case None{} y:
      y

def need.shift(c: Maybe<&2, Need>, m: Maybe<&2, U32>) -> Maybe<&2, Need>:
  match c:
    case None{}:
      None{}
    case Some{Need{lits, far}}:
      Some{Need{lits, mx.add(m, far)}}

def need.pre(p: List<&2, List<&2, U32>>) -> Maybe<&2, Need>:
  match p:
    case Nil{}:
      None{}
    case Con{h, t}:
      Some{Need{[h <> t], Some{0}}}

# One literal of each branch: at most 8 in all.
def need.alt(a: Maybe<&2, Need>, b: Maybe<&2, Need>) -> Maybe<&2, Need>:
  match a b:
    case Some{Need{+la, fa}} Some{Need{+lb, fb}}:
      +n = Nat.add(List.length(&2, List<&2, List<&2, U32>>, la), List.length(&2, List<&2, List<&2, U32>>, lb))
      Bool.pick(Maybe<&2, Need>, Nat.is_ge(8n, n), Some{Need{List.append(&2, List<&2, List<&2, U32>>, la, lb), mx.max(fa, fb)}}, None{})
    case _ _:
      None{}

def lt.exact(ea: Maybe<&2, List<&2, List<&2, U32>>>, eb: Maybe<&2, List<&2, List<&2, U32>>>) -> Maybe<&2, List<&2, List<&2, U32>>>:
  match ea eb:
    case Some{+x} Some{+y}:
      +n = Nat.add(List.length(&2, List<&2, U32>, x), List.length(&2, List<&2, U32>, y))
      Bool.pick(Maybe<&2, List<&2, List<&2, U32>>>, Nat.is_ge(32n, n), Some{List.append(&2, List<&2, U32>, x, y)}, None{})
    case _ _:
      None{}

def lt.pre(ea: Maybe<&2, List<&2, List<&2, U32>>>, pa: List<&2, List<&2, U32>>, pb: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match ea:
    case Some{x}:
      List.take(&2, List<&2, U32>, List.append(&2, List<&2, U32>, x, pb), 32n)
    case None{}:
      pa

def lt.cat(x: Lt, y: Lt) -> Lt:
  match x y:
    case Lt{+ea, pa, +ma, ca} Lt{eb, pb, mb, cb}:
      Lt{lt.exact(ea, eb), lt.pre(ea, pa, pb), mx.add(ma, mb), need.best(ca, need.shift(cb, ma))}

def lt.alt(x: Lt, y: Lt) -> Lt:
  match x y:
    case Lt{ea, pa, ma, ca} Lt{eb, pb, mb, cb}:
      Lt{None{}, Nil{}, mx.max(ma, mb), need.alt(ca, cb)}

# A node that matches only the empty text spells it out.
def lt.ezero(e: Maybe<&2, List<&2, List<&2, U32>>>) -> Maybe<&2, List<&2, List<&2, U32>>>:
  match e:
    case Some{Nil{}}:
      Some{Nil{}}
    case _:
      None{}

def lt.pmax(m: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match m:
    case Some{+x}:
      Bool.pick(Maybe<&2, U32>, U32.is_eq(x, 0), Some{0}, None{})
    case None{}:
      None{}

# Every match of a+ starts with a match of a.
def lt.plus(x: Lt) -> Lt:
  match x:
    case Lt{ea, pa, ma, ca}:
      Lt{lt.ezero(ea), pa, lt.pmax(ma), ca}

def lt.quest(x: Lt) -> Lt:
  match x:
    case Lt{ea, pa, ma, ca}:
      Lt{lt.ezero(ea), Nil{}, ma, None{}}

def lt.zero() -> Lt:
  Lt{Some{Nil{}}, Nil{}, Some{0}, None{}}

def lt.none(+w: U32) -> Lt:
  Lt{None{}, Nil{}, Some{w}, None{}}

# The code points of a set made of single points only, or None.
def set.pts(items: List<&2, Item>, acc: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match items:
    case Nil{}:
      Some{acc}
    case Con{Rng{+lo, +hi}, t}:
      Bool.pick(Maybe<&2, List<&2, U32>>, U32.is_eq(lo, hi), set.pts(t, lo <> acc), None{})
    case Con{h, t}:
      None{}

def pts.ascii(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+x, t}:
      U32.is_lt(x, 128) && pts.ascii(t)

def u8w(+c: U32) -> U32:
  Bool.pick(U32, U32.is_lt(c, 128), 1, Bool.pick(U32, U32.is_lt(c, 2048), 2, Bool.pick(U32, U32.is_lt(c, 65536), 3, 4)))

# The UTF-8 bytes of c, one set each.
def u8(+c: U32) -> List<&2, List<&2, U32>>:
  +w = u8w(c)
  +x0 = (c .&. 63 : U32)
  +x1 = ((c >> 6n) .&. 63 : U32)
  +x2 = ((c >> 12n) .&. 63 : U32)
  Bool.pick(List<&2, List<&2, U32>>, U32.is_eq(w, 1), [[c]], Bool.pick(List<&2, List<&2, U32>>, U32.is_eq(w, 2), [[(192 .|. (c >> 6n) : U32)], [(128 .|. x0 : U32)]], Bool.pick(List<&2, List<&2, U32>>, U32.is_eq(w, 3), [[(224 .|. (c >> 12n) : U32)], [(128 .|. x1 : U32)], [(128 .|. x0 : U32)]], [[(240 .|. (c >> 18n) : U32)], [(128 .|. x2 : U32)], [(128 .|. x1 : U32)], [(128 .|. x0 : U32)]])))

# A set of code points as byte sets: one code point by its UTF-8 bytes, ASCII points as one set.
# U+FFFD also matches an invalid byte, so it has no bytes to require.
def set.bytes(+p: List<&2, U32>) -> Maybe<&2, List<&2, List<&2, U32>>>:
  match p:
    case Con{+c, Nil{}}:
      Bool.pick(Maybe<&2, List<&2, List<&2, U32>>>, U32.is_eq(c, 65533), None{}, Some{u8(c)})
    case _:
      Bool.pick(Maybe<&2, List<&2, List<&2, U32>>>, pts.ascii(p), Some{[p]}, None{})

# The most bytes a char of the set takes.
def items.w(xs: List<&2, Item>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{Rng{lo, +hi}, t}:
      items.w(t, U32.max(acc, u8w(hi)))
    case Con{h, t}:
      4

def lt.lit(m: Maybe<&2, List<&2, List<&2, U32>>>, +w: U32) -> Lt:
  match m:
    case Some{+l}:
      Lt{Some{l}, l, Some{U32.from_nat(List.length(&2, List<&2, U32>, l))}, None{}}
    case None{}:
      lt.none(w)

def lt.small(m: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match m:
    case Some{+p}:
      Bool.pick(Maybe<&2, List<&2, U32>>, Nat.is_ge(4n, List.length(&2, U32, p)), Some{p}, None{})
    case None{}:
      None{}

def lt.char(m: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, List<&2, U32>>>:
  match m:
    case Some{p}:
      Some{[p]}
    case None{}:
      None{}

def lt.byte(m: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, List<&2, U32>>>:
  match m:
    case Some{p}:
      set.bytes(p)
    case None{}:
      None{}

# A set of at most 4 single points is a literal of one char.
def lt.set(neg: Bool, bytes: Bool, +items: List<&2, Item>) -> Lt:
  match neg:
    case True{}:
      lt.none(Bool.pick(U32, bytes, 4, 1))
    case False{}:
      match bytes:
        case True{}:
          lt.lit(lt.byte(lt.small(set.pts(items, Nil{}))), items.w(items, 1))
        case False{}:
          lt.lit(lt.char(lt.small(set.pts(items, Nil{}))), 1)

# A node's prefix is a Need at its start.
def lt.fin(l: Lt) -> Lt:
  match l:
    case Lt{e, +p, m, c}:
      Lt{e, p, m, need.best(c, need.pre(p))}

def lt(n: Node, +bytes: Bool) -> Lt:
  match n:
    case NEmpty{}:
      lt.zero()
    case NSet{neg, items}:
      lt.fin(lt.set(neg, bytes, items))
    case NAssert{k}:
      lt.zero()
    case NCat{a, b}:
      lt.fin(lt.cat(lt(a, bytes), lt(b, bytes)))
    case NAlt{a, b}:
      lt.alt(lt(a, bytes), lt(b, bytes))
    case NPlus{g, a}:
      lt.plus(lt(a, bytes))
    case NQuest{g, a}:
      lt.quest(lt(a, bytes))
    case NGroup{i, a}:
      lt(a, bytes)

# The literals every match of n holds: over code points, or over bytes.
def lt.cand(l: Lt) -> Maybe<&2, Need>:
  match l:
    case Lt{e, p, m, c}:
      c

def need.of(n: Node, +bytes: Bool) -> Maybe<&2, Need>:
  lt.cand(lt(n, bytes))

def pts.has(xs: List<&2, U32>, +c: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+x, t}:
      U32.is_eq(x, c) || pts.has(t, c)

# Anchors
# -------
# A scan for a literal looks for its rarest set, its anchor, and checks the literal around each
# place that holds it, so that a text full of a literal's first char does not stop the scan at
# every char. rank: how common a unit is in text, from 0, the rarest, to 9. The ASCII ranks:
#   0  control chars but \t \n \r, and DEL
#   1  ! # $ % & + ; ? @ ^ ` | ~ Q X Z J
#   2  K V Y W U B G H F O
#   3  * < > q z j D L M P R C N T E A I S
#   4  k v w b = { } [ ]
#   5  f g y p 2-9 \ '
#   6  c u m x 0 1 ( ) - / _
#   7  d l h " , . : \t \r
#   8  t a o i n s r \n
#   9  e, space
# rank.word(k) holds the ranks of bytes 8k to 8k+7, four bits each, byte 8k+j at bit 4j.
def rank.word(k: U32) -> U32:
  match k:
    case 0:
      0
    case 1:
      7342192
    case 2:
      0
    case 3:
      0
    case 4:
      1360074521
    case 5:
      1734808422
    case 6:
      1431655782
    case 7:
      323163989
    case 8:
      573780529
    case 9:
      590553394
    case 10:
      572732179
    case 11:
      1631928609
    case 12:
      1435985025
    case 13:
      2288468871
    case 14:
      1147701301
    case _:
      21054294

# Past ASCII: over Bytes a continuation byte 5, a lead byte 4, and a byte no UTF-8 text holds 0;
# over a String, a code point 4.
def rank.hi(+bytes: Bool, +c: U32) -> U32:
  Bool.pick(U32, bytes, Bool.pick(U32, U32.is_lt(c, 192), 5, Bool.pick(U32, U32.is_le(194, c) && U32.is_le(c, 244), 4, 0)), 4)

def rank(+bytes: Bool, +c: U32) -> U32:
  Bool.pick(U32, U32.is_lt(c, 128), (U32.shrn(rank.word((c >> 3n : U32)), U32.to_nat(((c .&. 7) * 4 : U32))) .&. 15 : U32), rank.hi(bytes, c))

# The rank of a set: that of its most common member, or acc.
def set.rank(xs: List<&2, U32>, +bytes: Bool, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{+x, t}:
      set.rank(t, bytes, U32.max(acc, rank(bytes, x)))

# A literal of a Need with its anchor: off, the anchor's place in the literal; set, the anchor;
# lit, the literal; tail, the literal from the anchor on.
type Anc is Data:
  Anc{off: U32, set: List<&2, U32>, lit: List<&2, List<&2, U32>>, tail: List<&2, List<&2, U32>>}

# The place and the set of l's rarest set, the first of them on a tie: i is the place of l's head,
# and at, rk and best the place, rank and set of the rarest before it.
def lit.anchor(l: List<&2, List<&2, U32>>, +bytes: Bool, +i: U32, +at: U32, +rk: U32, best: List<&2, U32>) -> U32 & List<&2, U32>:
  match l:
    case Nil{}:
      (at, best)
    case Con{+set, t}:
      +r = set.rank(set, bytes, 0)
      +take = U32.is_lt(r, rk)
      lit.anchor(t, bytes, (i + 1 : U32), Bool.pick(U32, take, i, at), Bool.pick(U32, take, r, rk), Bool.pick(List<&2, U32>, take, set, best))

def anc.of(r: U32 & List<&2, U32>, +l: List<&2, List<&2, U32>>) -> Anc:
  (+o, set) = r
  Anc{o, set, l, List.drop(&2, List<&2, U32>, l, U32.to_nat(o))}

def lit.anc(+l: List<&2, List<&2, U32>>, +bytes: Bool) -> Anc:
  anc.of(lit.anchor(l, bytes, 0, 0, 10, Nil{}), l)

# The literals with their anchors, over bytes or code points.
def lits.ancs(ls: List<&2, List<&2, List<&2, U32>>>, +bytes: Bool) -> List<&2, Anc>:
  match ls:
    case Nil{}:
      Nil{}
    case Con{l, t}:
      lit.anc(l, bytes) <> lits.ancs(t, bytes)

# The anchors of xs, added to acc.
def ancs.sets(xs: List<&2, Anc>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{Anc{o, set, l, tail}, t}:
      ancs.sets(t, List.append(&2, U32, set, acc))

# The largest anchor place of xs, or acc. A literal found with its anchor at p starts at p - off;
# one that starts earlier has its anchor at p or later, so it starts at p - big or later.
def ancs.big(xs: List<&2, Anc>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{Anc{+o, set, l, tail}, t}:
      ancs.big(t, U32.max(acc, o))

# Whether s starts with the literal l.
def lit.at(l: List<&2, List<&2, U32>>, s: String) -> Bool:
  match l:
    case Nil{}:
      True{}
    case Con{set, rest}:
      match s:
        case SNil{}:
          False{}
        case SCon{Chr{+c}, t}:
          pts.has(set, c) && lit.at(rest, t)

# Whether the text c, then t, starts with the literal l.
def lit.at.c(l: List<&2, List<&2, U32>>, +c: U32, t: String) -> Bool:
  match l:
    case Nil{}:
      True{}
    case Con{set, rest}:
      pts.has(set, c) && lit.at(rest, t)

# Whether a literal of ls starts the text c, then t.
def lits.any(ls: List<&2, List<&2, List<&2, U32>>>, +c: U32, +t: String) -> Bool:
  match ls:
    case Nil{}:
      False{}
    case Con{l, r}:
      lit.at.c(l, c, t) || lits.any(r, c, t)

# The anchors as a table of ASCII bytes: the ASCII members of xs added to a.
def lits.asc(xs: List<&2, U32>, a: Asc) -> Asc:
  match xs:
    case Nil{}:
      a
    case Con{+x, t}:
      lits.asc(t, asc.bit(U32.is_lt(x, 128), x, a))

# Whether c is an anchor place: by the table m when ASCII, else among first.
def fst.has(+c: U32, +m: Asc, +first: List<&2, U32>) -> Bool:
  asc.has(c, m) && (U32.is_lt(c, 128) || pts.has(first, c))

# Whether s's head is an anchor place; the end of the text is not.
def fst.head(s: String, +m: Asc, +first: List<&2, U32>) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      fst.has(c, m, first)

# Whether a literal of ls starts at s's head.
def lits.here(s: String, +ls: List<&2, List<&2, List<&2, U32>>>) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, +t}:
      lits.any(ls, c, t)

# s from its first char at an anchor place on, or empty; hit: whether s's head is one. fuel: each
# round passes a char. s is returned only before it is taken apart, so the loop reads it in place.
def lits.pass(fuel: Nat, hit: Bool, +s: String, +m: Asc, +first: List<&2, U32>) -> String:
  match fuel:
    case 0n:
      match hit:
        case True{}:
          s
        case False{}:
          s
    case 1n+f:
      match hit:
        case True{}:
          s
        case False{}:
          match s:
            case SNil{}:
              SNil{}
            case SCon{h, +t}:
              lits.pass(f, fst.head(t, m, first), t, m, first)

# With every anchor at the head of its literal: s from the first literal of ls on, or empty when it
# holds none: s starts at an anchor place, or is empty, and ok: whether a literal starts at its
# head. fuel: each round passes a char.
def lits.find(fuel: Nat, ok: Bool, +s: String, +m: Asc, +first: List<&2, U32>, +ls: List<&2, List<&2, List<&2, U32>>>) -> String:
  match fuel:
    case 0n:
      SNil{}
    case 1n++f:
      match ok:
        case True{}:
          s
        case False{}:
          match s:
            case SNil{}:
              SNil{}
            case SCon{h, +t}:
              +r = lits.pass(f, fst.head(t, m, first), t, m, first)
              lits.find(f, lits.here(r, ls), r, m, first, ls)

# As lits.pass, counting: s from its first char at an anchor place on, and that char's offset, i
# being s's.
def lits.passn(fuel: Nat, hit: Bool, +s: String, +i: U32, +m: Asc, +first: List<&2, U32>) -> String & U32:
  match fuel:
    case 0n:
      match hit:
        case True{}:
          (s, i)
        case False{}:
          (s, i)
    case 1n+f:
      match hit:
        case True{}:
          (s, i)
        case False{}:
          match s:
            case SNil{}:
              (SNil{}, i)
            case SCon{h, +t}:
              lits.passn(f, fst.head(t, m, first), t, (i + 1 : U32), m, first)

def anc.tail.if(fits: Bool, tail: List<&2, List<&2, U32>>, +t: String) -> Bool:
  match fits:
    case True{}:
      lit.at(tail, t)
    case False{}:
      False{}

# Whether x's anchor is at offset p, as far as the text from p on, t, shows: the literal fits
# before p, and its tail starts t.
def anc.tail(x: Anc, +t: String, +p: U32) -> Bool:
  Anc{+o, set, l, tail} = x
  anc.tail.if(U32.is_le(o, p), tail, t)

def ancs.tail(xs: List<&2, Anc>, +t: String, +p: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{x, r}:
      anc.tail(x, t, p) || ancs.tail(r, t, p)

def anc.full.if(fits: Bool, l: List<&2, List<&2, U32>>, +b: String, +n: U32) -> Bool:
  match fits:
    case True{}:
      lit.at(l, String.drop(b, U32.to_nat(n)))
    case False{}:
      False{}

# Whether x's literal starts at offset p - off, b being the text from bp on, bp <= p - off.
def anc.full(x: Anc, +b: String, +bp: U32, +p: U32) -> Bool:
  Anc{+o, set, l, tail} = x
  anc.full.if(U32.is_le(o, p), l, b, (p - o - bp : U32))

def ancs.full(xs: List<&2, Anc>, +b: String, +bp: U32, +p: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{x, r}:
      anc.full(x, b, bp, p) || ancs.full(r, b, bp, p)

# A round of lits.seek: done, with the text it gives; or go on at t, the text from the anchor place
# p on, with b, the text from bp on.
type Sg is Data:
  SkDone{r: String}
  SkGo{t: String, p: U32, b: String, bp: U32}

def seek.go(r: String & U32, +b: String, +bp: U32) -> Sg:
  (+t, +p) = r
  SkGo{t, p, b, bp}

# On from the anchor place after p, rest being the text after it.
def seek.next(f: Nat, +rest: String, +p: U32, +b: String, +bp: U32, +m: Asc, +first: List<&2, U32>) -> Sg:
  seek.go(lits.passn(f, fst.head(rest, m, first), rest, (p + 1 : U32), m, first), b, bp)

# ok: whether a literal has its anchor at p; b: the text from bp on.
def seek.full(ok: Bool, f: Nat, +rest: String, +p: U32, +b: String, +bp: U32, +m: Asc, +first: List<&2, U32>) -> Sg:
  match ok:
    case True{}:
      SkDone{b}
    case False{}:
      seek.next(f, rest, p, b, bp, m, first)

# ok: whether a tail starts at the anchor place p. Only then does b move up, to p - big, and the
# literals are checked whole.
def seek.cand(ok: Bool, f: Nat, +rest: String, +p: U32, +b: String, +bp: U32, +m: Asc, +first: List<&2, U32>, +xs: List<&2, Anc>, +big: U32) -> Sg:
  match ok:
    case False{}:
      seek.next(f, rest, p, b, bp, m, first)
    case True{}:
      +tp = Bool.pick(U32, U32.is_le(big, p), (p - big : U32), 0)
      +b2 = String.drop(b, U32.to_nat((tp - bp : U32)))
      seek.full(ancs.full(xs, b2, tp, p), f, rest, p, b2, tp, m, first)

def seek.step(f: Nat, +t: String, +p: U32, +b: String, +bp: U32, +m: Asc, +first: List<&2, U32>, +xs: List<&2, Anc>, +big: U32) -> Sg:
  match t:
    case SNil{}:
      SkDone{SNil{}}
    case SCon{h, +rest}:
      seek.cand(ancs.tail(xs, t, p), f, rest, p, b, bp, m, first, xs, big)

# The text from p - big on, or from 0 when p < big, p being the first anchor place where a literal
# of xs holds; empty when the text holds none. Each SkGo holds bp <= p - big for every anchor place
# p still to come. fuel: each round passes a char.
def lits.seek(fuel: Nat, st: Sg, +m: Asc, +first: List<&2, U32>, +xs: List<&2, Anc>, +big: U32) -> String:
  match fuel:
    case 0n:
      SNil{}
    case 1n++f:
      match st:
        case SkDone{r}:
          r
        case SkGo{+t, +p, +b, +bp}:
          lits.seek(f, seek.step(f, t, p, b, bp, m, first, xs, big), m, first, xs, big)

# zero: whether every anchor heads its literal (big, the largest anchor place, is 0); then the
# literals are tested at each anchor place as they are, ls.
def lits.find.by(zero: Bool, +big: U32, +fuel: Nat, +s: String, +m: Asc, +first: List<&2, U32>, +xs: List<&2, Anc>, +ls: List<&2, List<&2, List<&2, U32>>>) -> String:
  match zero:
    case True{}:
      +r = lits.pass(fuel, fst.head(s, m, first), s, m, first)
      lits.find(fuel, lits.here(r, ls), r, m, first, ls)
    case False{}:
      lits.seek(Nat.add(fuel, 1n), seek.go(lits.passn(fuel, fst.head(s, m, first), s, 0, m, first), s, 0), m, first, xs, big)

# s from where a match may start on: from p - big, p being the first anchor place where a literal
# of xs holds, or from 0 when p < big; empty when s holds none. A literal is never empty, so a found
# one leaves a text that is not.
def lits.find.start(+s: String, +ls: List<&2, List<&2, List<&2, U32>>>) -> String:
  +xs = lits.ancs(ls, False{})
  +first = ancs.sets(xs, Nil{})
  +m = lits.asc(first, Asc{0, 0, 0, 0})
  +fuel = Nat.add(String.length(s), 1n)
  +big = ancs.big(xs, 0)
  lits.find.by(U32.is_eq(big, 0), big, fuel, s, m, first, xs, ls)

# Where a match may start: None when no literal occurs, so there is no match; else the first
# occurrence h less far, or 0 when far is unbounded or reaches past the start.
def need.from(h: Maybe<&2, U32>, far: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match h:
    case None{}:
      None{}
    case Some{+k}:
      match far:
        case None{}:
          Some{0}
        case Some{+d}:
          Some{Bool.pick(U32, U32.is_le(d, k), (k - d : U32), 0)}

# Whether every match starts at its literal.
def need.zero(far: Maybe<&2, U32>) -> Bool:
  match far:
    case None{}:
      False{}
    case Some{+d}:
      U32.is_eq(d, 0)

# Whether a String search uses its Need: when every match starts at its literal and no word
# boundary reads the char before one, so the automata start at the first literal, or at most the
# largest anchor place before it, with nothing to look up. Else a found literal would leave the
# automata the whole text from its start, or a walk back to the char before it, on top of the scan.
def need.gate(m: Maybe<&2, Need>, +plain: Bool) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{Need{ls, far}}:
      need.zero(far) && plain

# prog: the instructions by pc; fuel: enough steps for one closure; slots: two per group, group 0 included;
# start: the sets one of which the first char of a match is in, or None when a match may start anywhere;
# bits: the bit-parallel form, for programs of at most 32 instructions without word boundaries;
# lead: as start, but past assertions, as if they held: a char outside it starts no match, though
# one inside may still fail an assertion; asc: lead as a table of ASCII bytes, for skipping;
# plain: no word boundary; need, needb: the literals every match holds, over a String and over Bytes;
# gate: whether a String search uses need, as need.gate.

def rev.build(m: Maybe<&2, Node>) -> Maybe<&2, Bits>:
  match m:
    case None{}:
      None{}
    case Some{node}:
      +insts = emit(reverse.node(node), 0, [IMatch{}])
      +fuel = Nat.add(Nat.mul(3n, List.length(&2, Inst, insts)), 2n)
      bits(fuel, insts)

def rev.if(ok: Bool, node: Node) -> Maybe<&2, Bits>:
  match ok:
    case False{}:
      None{}
    case True{}:
      rev.build(required.prefix(node))

type Regex is Data:
  Regex{prog: Trie<Inst>, fuel: Nat, slots: Nat, start: Maybe<&2, List<&2, Inst>>, lead: Maybe<&2, List<&2, Inst>>, bits: Maybe<&2, Bits>, asc: Maybe<&2, Asc>, plain: Bool, must: Maybe<&2, U32>, reverse: Maybe<&2, Bits>, need: Maybe<&2, Need>, needb: Maybe<&2, Need>, gate: Bool}

# A walk that reaches start meets no assertion, so passing assertions changes nothing: lead is start.
def lead.of(start: Maybe<&2, List<&2, Inst>>, fuel: Nat, +insts: List<&2, Inst>) -> Maybe<&2, List<&2, Inst>>:
  match start:
    case Some{sets}:
      Some{sets}
    case None{}:
      first(fuel, True{}, insts, Fs{[0], Nil{}, Nil{}})

def build(+node: Node, +n: U32) -> Regex:
  +insts = {ISave{0} <> emit(node, 1, [ISave{1}, IMatch{}]) : List<&2, Inst>}
  +fuel = Nat.add(Nat.mul(3n, List.length(&2, Inst, insts)), 2n)
  +start = first(fuel, False{}, insts, Fs{[0], Nil{}, Nil{}})
  +lead = lead.of(start, fuel, insts)
  +plain = bits.plain(insts)
  +need = need.of(node, False{})
  Regex{trie.from(Inst, insts, 0, TTip{}), fuel, U32.to_nat((2 * n : U32)), start, lead, bits(fuel, insts), asc(lead), plain, required(node), rev.if(reverse.ok(node), node), need, need.of(node, True{}), need.gate(need, plain)}

def compile.fin(st: Ps) -> Maybe<&2, Regex>:
  match st:
    case PsFail{}:
      None{}
    case Ps{n, rep, stack, alts, cur}:
      match stack:
        case Nil{}:
          Some{build(alt.go(alts, seq(cur)), n)}
        case Con{f, up}:
          None{}

def compile.parse(toks: Maybe<&2, List<&2, Tok>>) -> Maybe<&2, Regex>:
  match toks:
    case None{}:
      None{}
    case Some{ts}:
      compile.fin(parse(ts, Ps{1, False{}, Nil{}, Nil{}, Nil{}}))

def compile.go(+fold: Bool, +pat: String) -> Maybe<&2, Regex>:
  compile.parse(lex(Nat.add(String.length(pat), 2n), fold, LGo{pat, Nil{}}))

# The pattern, or None for a syntax error. A leading (?i) folds case over the
# whole pattern, by Unicode simple case folding as in RE2; no other flag is known.
def compile(+pat: String) -> Maybe<&2, Regex>:
  match pat:
    case SCon{'(', SCon{'?', SCon{'i', SCon{')', t}}}}:
      compile.go(True{}, t)
    case _:
      compile.go(False{}, pat)

# Matcher
# -------

def word(m: Maybe<&2, Char>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{Chr{+c}}:
      is_word(c)

def assert.ok(k: U32, +prev: Maybe<&2, Char>, +next: Maybe<&2, Char>) -> Bool:
  match k:
    case 0:
      Maybe.is_none(&2, Char, prev)
    case 1:
      Maybe.is_none(&2, Char, next)
    case 2:
      Bool.xor(word(prev), word(next))
    case _:
      Bool.not(Bool.xor(word(prev), word(next)))

# A thread: its pc and its capture slots.
type Th is Data:
  Th{pc: U32, caps: List<&2, Maybe<&2, U32>>}

# The epsilon closure as a depth-first walk: stack is the work left, seen the pcs
# visited at this position, out the threads that wait on a char or match (reversed).
type Cl is Data:
  Cl{stack: List<&2, Th>, seen: Trie<Unit>, out: List<&2, Th>}

def close.assert(ok: Bool, +pc: U32, caps: List<&2, Maybe<&2, U32>>, stack: List<&2, Th>, seen: Trie<Unit>, out: List<&2, Th>) -> Cl:
  match ok:
    case True{}:
      Cl{Th{(pc + 1 : U32), caps} <> stack, seen, out}
    case False{}:
      Cl{stack, seen, out}

def close.inst(i: Maybe<&2, Inst>, +pc: U32, +caps: List<&2, Maybe<&2, U32>>, stack: List<&2, Th>, seen: Trie<Unit>, out: List<&2, Th>, +pos: U32, +prev: Maybe<&2, Char>, +next: Maybe<&2, Char>) -> Cl:
  match i:
    case None{}:
      Cl{stack, seen, out}
    case Some{IJmp{x}}:
      Cl{Th{x, caps} <> stack, seen, out}
    case Some{ISplit{x, y}}:
      Cl{Th{x, caps} <> Th{y, caps} <> stack, seen, out}
    case Some{ISave{k}}:
      Cl{Th{(pc + 1 : U32), List.set(&2, Maybe<&2, U32>, caps, U32.to_nat(k), Some{pos})} <> stack, seen, out}
    case Some{IAssert{k}}:
      close.assert(assert.ok(k, prev, next), pc, caps, stack, seen, out)
    case Some{ISet{neg, items}}:
      Cl{stack, seen, Th{pc, caps} <> out}
    case Some{IMatch{}}:
      Cl{stack, seen, Th{pc, caps} <> out}

# ponytail: trie lookup and membership cost O(log m) per thread step, so a char costs
# O(m log m) for m instructions; a sparse set over an Array would make a step O(1).
def close.seen(hit: Bool, +prog: Trie<Inst>, +pc: U32, caps: List<&2, Maybe<&2, U32>>, stack: List<&2, Th>, seen: Trie<Unit>, out: List<&2, Th>, +pos: U32, +prev: Maybe<&2, Char>, +next: Maybe<&2, Char>) -> Cl:
  match hit:
    case True{}:
      Cl{stack, seen, out}
    case False{}:
      close.inst(trie.at(Inst, prog, pc), pc, caps, stack, trie.set(Unit, seen, pc, Unit{}), out, pos, prev, next)

def close.step(th: Th, stack: List<&2, Th>, +seen: Trie<Unit>, out: List<&2, Th>, +prog: Trie<Inst>, +pos: U32, +prev: Maybe<&2, Char>, +next: Maybe<&2, Char>) -> Cl:
  Th{+pc, caps} = th
  close.seen(Maybe.is_some(&2, Unit, trie.at(Unit, seen, pc)), prog, pc, caps, stack, seen, out, pos, prev, next)

# fuel: each pc expands once and pushes at most two threads.
def close(fuel: Nat, +prog: Trie<Inst>, +pos: U32, +prev: Maybe<&2, Char>, +next: Maybe<&2, Char>, st: Cl) -> List<&2, Th>:
  match fuel:
    case 0n:
      Cl{stack, seen, out} = st
      List.reverse(&2, Th, out)
    case 1n+f:
      match st:
        case Cl{Nil{}, seen, out}:
          List.reverse(&2, Th, out)
        case Cl{Con{th, t}, seen, out}:
          close(f, prog, pos, prev, next, close.step(th, t, seen, out, prog, pos, prev, next))

# A scan of the threads at one char, in priority order: items are the threads that
# step past it (reversed), best the latest match. A match drops every later thread.
type Sc is Data:
  Sc{items: List<&2, Th>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>, stop: Bool}

def scan.set(hit: Bool, +pc: U32, caps: List<&2, Maybe<&2, U32>>, items: List<&2, Th>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Sc:
  match hit:
    case True{}:
      Sc{Th{(pc + 1 : U32), caps} <> items, best, False{}}
    case False{}:
      Sc{items, best, False{}}

def scan.char(c: Maybe<&2, Char>, neg: Bool, set: List<&2, Item>, +pc: U32, caps: List<&2, Maybe<&2, U32>>, items: List<&2, Th>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Sc:
  match c:
    case None{}:
      Sc{items, best, False{}}
    case Some{Chr{+x}}:
      scan.set(Bool.xor(neg, items.has(set, x)), pc, caps, items, best)

# any: only whether a match exists counts, so a match also drops the earlier threads.
def scan.hit(any: Bool, caps: List<&2, Maybe<&2, U32>>, items: List<&2, Th>) -> Sc:
  match any:
    case True{}:
      Sc{Nil{}, Some{caps}, True{}}
    case False{}:
      Sc{items, Some{caps}, True{}}

def scan.inst(i: Maybe<&2, Inst>, c: Maybe<&2, Char>, +any: Bool, +pc: U32, caps: List<&2, Maybe<&2, U32>>, items: List<&2, Th>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Sc:
  match i:
    case Some{IMatch{}}:
      scan.hit(any, caps, items)
    case Some{ISet{neg, set}}:
      scan.char(c, neg, set, pc, caps, items, best)
    case _:
      Sc{items, best, False{}}

def scan.go(stop: Bool, th: Th, +prog: Trie<Inst>, c: Maybe<&2, Char>, +any: Bool, items: List<&2, Th>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Sc:
  match stop:
    case True{}:
      Sc{items, best, True{}}
    case False{}:
      Th{+pc, caps} = th
      scan.inst(trie.at(Inst, prog, pc), c, any, pc, caps, items, best)

def scan.step(st: Sc, th: Th, +prog: Trie<Inst>, c: Maybe<&2, Char>, +any: Bool) -> Sc:
  Sc{items, best, stop} = st
  scan.go(stop, th, prog, c, any, items, best)

def scan(xs: List<&2, Th>, +prog: Trie<Inst>, +c: Maybe<&2, Char>, +any: Bool, st: Sc) -> Sc:
  match xs:
    case Nil{}:
      st
    case Con{th, t}:
      scan(t, prog, c, any, scan.step(st, th, prog, c, any))

# The live threads and the best match so far.
type Vm is Data:
  Vm{ths: List<&2, Th>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>}

# Until a match is found, a new thread starts at each position, below every other.
def seed(best: Maybe<&2, List<&2, Maybe<&2, U32>>>, xs: List<&2, Th>, init: List<&2, Maybe<&2, U32>>) -> List<&2, Th>:
  match best:
    case None{}:
      List.append(&2, Th, xs, [Th{0, init}])
    case Some{b}:
      xs

# No live thread and no match yet: the seed is the only thread, and it dies unless next is in start.
def seed.skip(items: List<&2, Th>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>, start: Maybe<&2, List<&2, Inst>>, next: Maybe<&2, Char>) -> Bool:
  match items best start next:
    case Nil{} None{} Some{sets} None{}:
      True{}
    case Nil{} None{} Some{sets} Some{Chr{+c}}:
      Bool.not(starts(sets, c))
    case _ _ _ _:
      False{}

def run.seed(skip: Bool, items: List<&2, Th>, +best: Maybe<&2, List<&2, Maybe<&2, U32>>>, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +pos: U32, +prev: Maybe<&2, Char>, +next: Maybe<&2, Char>) -> Vm:
  match skip:
    case True{}:
      Vm{Nil{}, None{}}
    case False{}:
      Vm{close(fuel, prog, pos, prev, next, Cl{seed(best, List.reverse(&2, Th, items), init), TTip{}, Nil{}}), best}

def run.close(sc: Sc, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +pos: U32, +prev: Maybe<&2, Char>, +next: Maybe<&2, Char>) -> Vm:
  Sc{+items, +best, stop} = sc
  run.seed(seed.skip(items, best, start, next), items, best, prog, fuel, init, pos, prev, next)

def run.step(st: Vm, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool, +pos: U32, +c: Char, +next: Maybe<&2, Char>) -> Vm:
  Vm{ths, best} = st
  run.close(scan(ths, prog, Some{c}, any, Sc{Nil{}, best, False{}}), prog, fuel, init, start, pos, Some{c}, next)

def run.end(sc: Sc) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  Sc{items, best, stop} = sc
  best

# Whether c is in lead: by the table for ASCII, by the sets past it.
def lead.has(+c: U32, +m: Asc, +sets: List<&2, Inst>) -> Bool:
  asc.has(c, m) && (U32.is_lt(c, 128) || starts(sets, c))

# How many chars of an idle text to pass, and the char before the first one not passed.
type Pass is Data:
  Pass{n: U32, prev: U32}

# Whether the head of s is in lead; the end of the text counts as in it, so a pass stops there.
def head.in(s: String, +m: Asc, +sets: List<&2, Inst>) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      lead.has(c, m, sets)

# Pass the chars of s outside lead; hit: whether s's head is in lead; n counts the chars
# passed, prev is the last one passed.
def skip.str(s: String, hit: Bool, +m: Asc, +sets: List<&2, Inst>, +n: U32, +prev: U32) -> Pass:
  match s:
    case SNil{}:
      Bool.pick(Pass, hit, Pass{n, prev}, Pass{n, prev})
    case SCon{Chr{+c}, +t}:
      match hit:
        case True{}:
          Pass{n, prev}
        case False{}:
          skip.str(t, head.in(t, m, sets), m, sets, (n + 1 : U32), c)

# Without lead every char may start a match, so none is passed.
def skip.lead(lead: Maybe<&2, List<&2, Inst>>, asc: Maybe<&2, Asc>, +s: String, +c: Char) -> Pass:
  match lead asc:
    case Some{+sets} Some{+m}:
      Chr{+x} = c
      skip.str(s, head.in(s, m, sets), m, sets, 0, x)
    case _ _:
      Chr{+x} = c
      Pass{0, x}

def str.drop(n: Nat, +s: String) -> String:
  match n:
    case 0n:
      s
    case 1n+p:
      match s:
        case SNil{}:
          SNil{}
        case SCon{h, +t}:
          str.drop(p, t)

def Pass.n(ps: Pass) -> U32:
  Pass{+n, +q} = ps
  n

def Pass.prev(ps: Pass) -> U32:
  Pass{+n, +q} = ps
  q

# pos: the position of s's head. Once a match exists and no thread is live, the rest of s cannot change it.
# With no thread live and no match yet, a char outside lead cannot start one, so the chars up to
# the next one in lead pass without a step: the seed there sees the char before it as prev.
# fuel: each round eats at least one char.
def run(fuel: Nat, s: String, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +lead: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool, +pos: U32, st: Vm) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      match s:
        case SNil{}:
          Vm{ths, best} = st
          run.end(scan(ths, prog, None{}, any, Sc{Nil{}, best, False{}}))
        case SCon{+c, +t}:
          match st:
            case Vm{Nil{}, Some{b}}:
              Some{b}
            case Vm{Nil{}, None{}}:
              +ps = skip.lead(lead, asc, t, c)
              +r = str.drop(U32.to_nat(Pass.n(ps)), t)
              +p = ((pos + 1 : U32) + Pass.n(ps) : U32)
              run(f, r, prog, cfuel, init, start, lead, asc, any, p, run.close(Sc{Nil{}, None{}, False{}}, prog, cfuel, init, start, p, Some{Chr{Pass.prev(ps)}}, String.get(r, 0n)))
            case Vm{ths, best}:
              +p = (pos + 1 : U32)
              run(f, t, prog, cfuel, init, start, lead, asc, any, p, run.step(Vm{ths, best}, prog, cfuel, init, start, any, p, c, String.get(t, 0n)))

# States
# ------

# The seed thread's index, and the id of a state the full cache could not add.
def seed.id() -> U32:
  4294967295

# A new thread: pc, the thread at src it came from (or the seed), and the slots it saved.
type Op is Data:
  Op{src: U32, pc: U32, saves: List<&2, U32>}

# next: the state after the char; hit: 1 + the index of the thread that matched, or 0;
# fresh: no match yet and every new thread comes from the seed, so the next state is a fresh start.
type Tr is Data:
  TrNo{}
  TrSame{}
  Tr{next: U32, hit: U32, outs: List<&2, Op>, fresh: Bool}

type Sk is Data:
  Sk{pcs: List<&2, U32>, done: Bool}

type Ix is Data:
  Ix{key: Sk, id: U32}

# The interned states, how many there are, and the id of one.
type Ik is Data:
  Ik{keys: Trie<List<&2, Ix>>, n: U32, id: U32}

# A learned transition, with the next state's key in place of its id.
type Lr is Data:
  Lr{hit: U32, outs: List<&2, Op>, key: Sk, fresh: Bool}

def vm.pcs(xs: List<&2, Th>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Th{pc, caps}, t}:
      pc <> vm.pcs(t)

def vm.key(st: Vm) -> Sk:
  Vm{ths, best} = st
  Sk{vm.pcs(ths), Maybe.is_some(&2, List<&2, Maybe<&2, U32>>, best)}

def pcs.eq(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{+a, s} Con{+b, t}:
      U32.is_eq(a, b) && pcs.eq(s, t)
    case _ _:
      False{}

def sk.eq(a: Sk, b: Sk) -> Bool:
  Sk{p, x} = a
  Sk{q, y} = b
  Bool.not(Bool.xor(x, y)) && pcs.eq(p, q)

def pcs.hash(xs: List<&2, U32>, +h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{+pc, rest}:
      pcs.hash(rest, (U32.xor(h, pc) * 16777619 : U32))

def sk.hash(k: Sk) -> U32:
  Sk{pcs, done} = k
  U32.and(pcs.hash(pcs, Bool.pick(U32, done, 2166136260, 2166136261)), 2147483647)

def ix.find(xs: List<&2, Ix>, +k: Sk) -> U32:
  match xs:
    case Nil{}:
      seed.id()
    case Con{Ix{key, +id}, t}:
      Bool.pick(U32, sk.eq(key, k), id, ix.find(t, k))

def intern.bucket(m: Maybe<&2, List<&2, Ix>>, +k: Sk) -> U32:
  match m:
    case None{}:
      seed.id()
    case Some{xs}:
      ix.find(xs, k)

def intern.add(m: Maybe<&2, List<&2, Ix>>, +k: Sk, +n: U32) -> List<&2, Ix>:
  match m:
    case None{}:
      [Ix{k, n}]
    case Some{xs}:
      Ix{k, n} <> xs

def intern.if(miss: Bool, +found: U32, +keys: Trie<List<&2, Ix>>, +n: U32, +k: Sk, +hash: U32) -> Ik:
  match miss:
    case True{}:
      Ik{trie.set(List<&2, Ix>, keys, hash, intern.add(trie.at(List<&2, Ix>, keys, hash), k, n)), (n + 1 : U32), n}
    case False{}:
      Ik{keys, n, found}

def intern.full(room: Bool, +keys: Trie<List<&2, Ix>>, +n: U32, +k: Sk) -> Ik:
  match room:
    case True{}:
      +hash = sk.hash(k)
      +found = intern.bucket(trie.at(List<&2, Ix>, keys, hash), k)
      intern.if(U32.is_eq(found, seed.id()), found, keys, n, k, hash)
    case False{}:
      Ik{keys, n, seed.id()}

# A full cache is not searched; the plain Pike VM handles the remaining text.
def intern(+keys: Trie<List<&2, Ix>>, +n: U32, +cap: U32, +k: Sk) -> Ik:
  intern.full(U32.is_lt(n, cap), keys, n, k)

# Capture-free DFA
# ----------------
# Finds whether a match exists, and where the Pike VM must start to find its captures. A state
# is the pcs, in priority order, of the threads that passed the char before a position, and the
# kind of that char: 0 none, at the start of the text; 2 a word char, when the program has a word
# boundary; 1 any other char. A step closes those threads, the seed below them, between that char
# and the one read: a thread at IMatch means a match ends before the char read, and the threads
# that pass it make the next state. A step depends only on the state and the char, so steps on
# ASCII chars are learned once into a table; wider chars step uncached.
#
# A position whose state has no thread is idle: no thread from an earlier start is alive there,
# and no match ended before it, so the Pike VM started there, with the char before as prev, finds
# the leftmost-first match the one started at the beginning finds. The DFA keeps the last idle
# point and hands it on at the first match, or when the cache is full. The idle state of kind k
# has id k; they are interned first.

# The sets of lead; none without it.
def lead.sets(m: Maybe<&2, List<&2, Inst>>) -> List<&2, Inst>:
  match m:
    case None{}:
      Nil{}
    case Some{xs}:
      xs

# The table of asc; empty without it.
def asc.or(m: Maybe<&2, Asc>) -> Asc:
  match m:
    case None{}:
      Asc{0, 0, 0, 0}
    case Some{x}:
      x

# Byte i of a buffer, from the word that holds it.
def byte.at(+w: U32, +i: U32) -> U32:
  (U32.shrn(w, U32.to_nat(((i .&. 3 : U32) * 8 : U32))) .&. 255 : U32)

def dk.none() -> U32:
  4294967295

def dk.of(+wb: Bool, +c: U32) -> U32:
  Bool.pick(U32, wb && is_word(c), 2, 1)

# A char of kind k, as an assertion reads it.
def dk.prev(+k: U32) -> Maybe<&2, Char>:
  match k:
    case 0:
      None{}
    case 1:
      Some{Chr{32}}
    case _:
      Some{Chr{97}}

# The threads of a state, the seed below them. A DFA keeps no captures.
def dk.ths(xs: List<&2, U32>) -> List<&2, Th>:
  match xs:
    case Nil{}:
      [Th{0, Nil{}}]
    case Con{+pc, t}:
      Th{pc, Nil{}} <> dk.ths(t)

# A state's key: its kind, then its pcs.
def dk.key(+k: U32, pcs: List<&2, U32>) -> Sk:
  Sk{k <> pcs, False{}}

def dk.kind(k: Sk) -> U32:
  match k:
    case Sk{Con{+x, t}, d}:
      x
    case Sk{Nil{}, d}:
      0

def dk.pcs(k: Sk) -> List<&2, U32>:
  match k:
    case Sk{Con{x, t}, d}:
      t
    case Sk{Nil{}, d}:
      Nil{}

# Whether idle states may skip: lead and its table exist.
def dk.sk(lead: Maybe<&2, List<&2, Inst>>, asc: Maybe<&2, Asc>) -> Bool:
  match lead asc:
    case Some{x} Some{y}:
      True{}
    case _ _:
      False{}

# A step: the next state's pcs, and whether a match ends before the char.
type Dt is Data:
  Dt{pcs: List<&2, U32>, hit: Bool}

def dt.of(sc: Sc) -> Dt:
  Sc{items, best, stop} = sc
  Dt{vm.pcs(List.reverse(&2, Th, items)), stop}

def dt.hit(d: Dt) -> Bool:
  Dt{pcs, hit} = d
  hit

def dt.pcs(d: Dt) -> List<&2, U32>:
  Dt{pcs, hit} = d
  pcs

# The step from the state key on c; None is the end of the text.
def dfa.go(+prog: Trie<Inst>, +fuel: Nat, +key: Sk, +c: Maybe<&2, Char>) -> Dt:
  dt.of(scan(close(fuel, prog, 0, dk.prev(dk.kind(key)), c, Cl{dk.ths(dk.pcs(key)), TTip{}, Nil{}}), prog, c, True{}, Sc{Nil{}, None{}, False{}}))

# The next state, interned, unless a match ended.
def dfa.ik(hit: Bool, +keys: Trie<List<&2, Ix>>, +n: U32, +cap: U32, +key: Sk) -> Ik:
  match hit:
    case True{}:
      Ik{keys, n, seed.id()}
    case False{}:
      intern(keys, n, cap, key)

def ik.keys(k: Ik) -> Trie<List<&2, Ix>>:
  Ik{keys, n, id} = k
  keys

def ik.n(k: Ik) -> U32:
  Ik{keys, n, id} = k
  n

def ik.id(k: Ik) -> U32:
  Ik{keys, n, id} = k
  id

# The index with the idle states.
def dk.keys(+cap: U32) -> Trie<List<&2, Ix>>:
  ik.keys(intern(ik.keys(intern(ik.keys(intern(TTip{}, 0, cap, dk.key(0, Nil{}))), 1, cap, dk.key(1, Nil{}))), 2, cap, dk.key(2, Nil{})))

# The states by id, with the idle states.
def dk.sts(+depth: Nat) -> Array<Sk>:
  Array.set(Sk, Array.set(Sk, Array.new(Sk, depth, dk.key(0, Nil{})), 1, dk.key(1, Nil{})), 2, dk.key(2, Nil{}))

# A learned step into the table: 1 a match, 2 + the next id, 0 unknown. Wide chars are not cached.
def dfa.store(cache: Bool, tab: Array<U32>, +idx: U32, +e: U32) -> Array<U32>:
  match cache:
    case True{}:
      Array.set(U32, tab, idx, e)
    case False{}:
      tab

def dfa.put(ok: Bool, sts: Array<Sk>, +id: U32, +key: Sk) -> Array<Sk>:
  match ok:
    case True{}:
      Array.set(Sk, sts, id, key)
    case False{}:
      sts

# The table entry for a learned step.
def dfa.entry(+hit: Bool, +id: U32) -> U32:
  Bool.pick(U32, hit, 1, Bool.pick(U32, U32.is_eq(id, seed.id()), 0, (id + 2 : U32)))

# A learned step: the table, the states, the index, its size, the next id (seed.id() after a
# match or with a full cache), and whether a match ended.
type Dl is Type:
  Dl{tab: Array<U32>, sts: Array<Sk>, keys: Trie<List<&2, Ix>>, n: U32, id: U32, hit: Bool}

# Learn the step from state id on c; r holds the states and id's key.
def dfa.learn(r: Array<Sk> & Sk, tab: Array<U32>, +keys: Trie<List<&2, Ix>>, +n: U32, +id: U32, +c: U32, +prog: Trie<Inst>, +cfuel: Nat, +wb: Bool, +cap: U32) -> Dl:
  (sts, +key) = r
  +got = dfa.go(prog, cfuel, key, Some{Chr{c}})
  +hit = dt.hit(got)
  +nk = dk.key(dk.of(wb, c), dt.pcs(got))
  +ik = dfa.ik(hit, keys, n, cap, nk)
  +id2 = ik.id(ik)
  Dl{dfa.store(U32.is_lt(c, 128), tab, ((id * 128) + c : U32), dfa.entry(hit, id2)), dfa.put(U32.is_ne(id2, seed.id()), sts, id2, nk), ik.keys(ik), ik.n(ik), id2, hit}

# The cache size for a text of len chars: states, and the depths of the table and the state array.
def dk.cap(+len: U32) -> U32:
  Bool.pick(U32, U32.is_lt(len, 4096), 8, Bool.pick(U32, U32.is_lt(len, 65536), 64, 1024))

def dk.tab(+len: U32) -> Nat:
  Bool.pick(Nat, U32.is_lt(len, 4096), 10n, Bool.pick(Nat, U32.is_lt(len, 65536), 13n, 17n))

def dk.depth(+len: U32) -> Nat:
  Bool.pick(Nat, U32.is_lt(len, 4096), 3n, Bool.pick(Nat, U32.is_lt(len, 65536), 6n, 10n))

# What the DFA hands on: no match; a match, which the Pike VM finds from the idle point p; or a
# full cache, after which the Pike VM runs from p.
type Dr is Data:
  DNo{}
  DHit{p: U32}
  DFull{p: U32}

def dr.end(hit: Bool, +p: U32) -> Dr:
  match hit:
    case True{}:
      DHit{p}
    case False{}:
      DNo{}

def dfas.end(r: Array<Sk> & Sk, +p: U32, +prog: Trie<Inst>, +cfuel: Nat) -> Dr:
  (sts, +key) = r
  dr.end(dt.hit(dfa.go(prog, cfuel, key, None{})), p)

# The head of s as a table column; a wide char or the end reads a column it then ignores.
def str.head(s: String) -> U32:
  match s:
    case SNil{}:
      0
    case SCon{Chr{+c}, t}:
      c

# A learn round's result, for the round after it.
type Dz is Type:
  Dz0{}
  DzL{dl: Dl}

# The rounds of dfas.
type Ds is Data:
  DsRead{}   # read s's head in state id, or end at SNil
  DsSkip{}   # pass the chars of s that cannot start a match, from the idle state id
  DsLearn{}  # learn the step from state id on q
  DsTake{}   # take the step learned, from z
  DsHit{}    # a match
  DsFull{}   # a full cache

# The DFA over a String; mode picks the round. rt: the table and, in DsRead, its entry for id
# and s's head. i: the position of s's head, q the char before it (in DsLearn and DsTake, i is
# q's position); p: the last idle point. fuel: each char takes at most three rounds. Each value
# the next round takes is bound first, so no round delays work into it.
def dfas(fuel: Nat, +mode: Ds, z: Dz, +s: String, rt: Array<U32> & U32, sts: Array<Sk>, +keys: Trie<List<&2, Ix>>, +n: U32, +i: U32, +id: U32, +q: U32, +p: U32, +prog: Trie<Inst>, +cfuel: Nat, +wb: Bool, +lead: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +am: Asc, +sets: List<&2, Inst>, +sk: Bool, +cap: U32) -> Dr:
  match fuel:
    case 0n:
      DFull{p}
    case 1n+f:
      match mode:
        case DsRead{}:
          match s:
            case SNil{}:
              (tab, e) = rt
              dfas.end(Array.get(Sk, sts, id), p, prog, cfuel)
            case SCon{Chr{+x}, +t}:
              (tab, +e) = rt
              +ascii = U32.is_lt(x, 128)
              +adv = ascii && U32.is_le(2, e)
              +e2 = (e - 2 : U32)
              +id2 = Bool.pick(U32, adv, e2, id)
              +idle = adv && U32.is_le(id2, 2)
              +i1 = (i + 1 : U32)
              +i2 = Bool.pick(U32, adv, i1, i)
              +p2 = Bool.pick(U32, idle, i2, p)
              +hit = ascii && U32.is_eq(e, 1)
              +mh = Bool.pick(Ds, hit, DsHit{}, DsLearn{})
              +h = str.head(t)
              +isk = idle && sk && Bool.not(lead.has(h, am, sets))
              +mi = Bool.pick(Ds, isk, DsSkip{}, DsRead{})
              +m = Bool.pick(Ds, adv, mi, mh)
              +col = ((id2 * 128) + h : U32)
              +idx = Bool.pick(U32, adv, col, 0)
              rt2 = Array.get(U32, tab, idx)
              dfas(f, m, Dz0{}, t, rt2, sts, keys, n, i2, id2, x, p2, prog, cfuel, wb, lead, asc, am, sets, sk, cap)
        case DsSkip{}:
          (tab, e) = rt
          +pass = skip.lead(lead, asc, s, Chr{q})
          +nn = Pass.n(pass)
          +q2 = Pass.prev(pass)
          +s2 = str.drop(U32.to_nat(nn), s)
          +moved = U32.is_ne(nn, 0)
          +i2 = (i + nn : U32)
          +kd = dk.of(wb, q2)
          +id2 = Bool.pick(U32, moved, kd, id)
          +p2 = Bool.pick(U32, moved, i2, p)
          +h = str.head(s2)
          +idx = ((id2 * 128) + h : U32)
          rt2 = Array.get(U32, tab, idx)
          dfas(f, DsRead{}, Dz0{}, s2, rt2, sts, keys, n, i2, id2, q2, p2, prog, cfuel, wb, lead, asc, am, sets, sk, cap)
        case DsLearn{}:
          (tab, e) = rt
          z2 = {DzL{dfa.learn(Array.get(Sk, sts, id), tab, keys, n, id, q, prog, cfuel, wb, cap)} : Dz}
          rt2 = {(Array.new(U32, 0n, 0), 0) : Array<U32> & U32}
          sts2 = Array.new(Sk, 0n, dk.key(0, Nil{}))
          dfas(f, DsTake{}, z2, s, rt2, sts2, keys, n, i, id, q, p, prog, cfuel, wb, lead, asc, am, sets, sk, cap)
        case DsTake{}:
          match z:
            case DzL{Dl{t2, s2, +k2, +n2, +id2, +hit}}:
              +ok = U32.is_ne(id2, seed.id())
              +idle = ok && U32.is_le(id2, 2)
              +i2 = (i + 1 : U32)
              +p2 = Bool.pick(U32, idle, i2, p)
              +isk = idle && sk
              +m0 = Bool.pick(Ds, isk, DsSkip{}, DsRead{})
              +m1 = Bool.pick(Ds, ok, m0, DsFull{})
              +m = Bool.pick(Ds, hit, DsHit{}, m1)
              +h = str.head(s)
              +idx = ((id2 * 128) + h : U32)
              rt2 = Array.get(U32, t2, idx)
              dfas(f, m, Dz0{}, s, rt2, s2, k2, n2, i2, id2, q, p2, prog, cfuel, wb, lead, asc, am, sets, sk, cap)
            case Dz0{}:
              DFull{p}
        case DsHit{}:
          DHit{p}
        case DsFull{}:
          DFull{p}

# The char before position p of s, or None at 0.
def str.prev.if(zero: Bool, +p: U32, +s: String) -> Maybe<&2, Char>:
  match zero:
    case True{}:
      None{}
    case False{}:
      String.get(s, U32.to_nat((p - 1 : U32)))

# The Pike VM from position p of s; total: the length of s.
def exec.pike(+s: String, +p: U32, +total: U32, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +lead: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  +r = str.drop(U32.to_nat(p), s)
  run(Nat.add(U32.to_nat((total - p : U32)), 1n), r, prog, fuel, init, start, lead, asc, any, p, run.close(Sc{Nil{}, None{}, False{}}, prog, fuel, init, start, p, str.prev.if(U32.is_eq(p, 0), p, s), String.get(r, 0n)))

# After the DFA: with any, a match found is the answer; else the Pike VM runs from the idle point.
def exec.dr(d: Dr, +any: Bool, +s: String, +total: U32, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +lead: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match d:
    case DNo{}:
      None{}
    case DHit{+p}:
      match any:
        case True{}:
          Some{Nil{}}
        case False{}:
          exec.pike(s, p, total, prog, fuel, init, start, lead, asc, any)
    case DFull{+p}:
      exec.pike(s, p, total, prog, fuel, init, start, lead, asc, any)

type Span is Data:
  Span{start: U32, end: U32}

def spans(caps: List<&2, Maybe<&2, U32>>) -> List<&2, Maybe<&2, Span>>:
  match caps:
    case Con{Some{a}, Con{Some{b}, t}}:
      Some{Span{a, b}} <> spans(t)
    case Con{x, Con{y, t}}:
      None{} <> spans(t)
    case _:
      Nil{}

def find.spans(m: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Maybe<&2, List<&2, Maybe<&2, Span>>>:
  match m:
    case None{}:
      None{}
    case Some{caps}:
      Some{spans(caps)}

def str.code(m: Maybe<&2, Char>) -> U32:
  match m:
    case None{}:
      0
    case Some{Chr{+c}}:
      c

# The DFA, then the Pike VM, from position k of s: no match starts before k, and r is s from k.
# Past the start only a program without word boundaries comes here, so the DFA's first state is
# idle of kind 1, whatever the char before k. slots: capture slots to keep; is_match keeps none,
# so each ISave is free.
def exec.at(+k: U32, +r: String, +s: String, +any: Bool, +prog: Trie<Inst>, +fuel: Nat, +slots: Nat, +start: Maybe<&2, List<&2, Inst>>, +lead: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +plain: Bool) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  +init = List.replicate(Maybe<&2, U32>, Bool.pick(Nat, any, 0n, slots), None{})
  +total = U32.from_nat(String.length(s))
  +rest = (total - k : U32)
  +zero = U32.is_eq(k, 0)
  +wb = Bool.not(plain)
  +id = Bool.pick(U32, zero, 0, 1)
  +cap = dk.cap(rest)
  +sk = dk.sk(lead, asc)
  exec.dr(dfas(Nat.add(Nat.mul(3n, U32.to_nat(rest)), 8n), Bool.pick(Ds, sk, DsSkip{}, DsRead{}), Dz0{}, r, Array.get(U32, Array.new(U32, dk.tab(rest), 0), ((id * 128) + str.head(r) : U32)), dk.sts(dk.depth(rest)), dk.keys(cap), 3, k, id, dk.none(), k, prog, fuel, wb, lead, asc, asc.or(asc), lead.sets(lead), sk, cap), any, s, total, prog, fuel, init, start, lead, asc)

# found: whether s holds a literal, r being s from the first, where the automata start.
def exec.lit(found: Bool, +r: String, +s: String, +any: Bool, +prog: Trie<Inst>, +fuel: Nat, +slots: Nat, +start: Maybe<&2, List<&2, Inst>>, +lead: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +plain: Bool) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match found:
    case False{}:
      None{}
    case True{}:
      exec.at((U32.from_nat(String.length(s)) - U32.from_nat(String.length(r)) : U32), r, s, any, prog, fuel, slots, start, lead, asc, plain)

def exec.need(m: Maybe<&2, Need>, +s: String, +any: Bool, +prog: Trie<Inst>, +fuel: Nat, +slots: Nat, +start: Maybe<&2, List<&2, Inst>>, +lead: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +plain: Bool) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match m:
    case None{}:
      exec.at(0, s, s, any, prog, fuel, slots, start, lead, asc, plain)
    case Some{Need{ls, far}}:
      +r = lits.find.start(s, ls)
      exec.lit(Nat.is_ge(String.length(r), 1n), r, s, any, prog, fuel, slots, start, lead, asc, plain)

# The Need a String search uses: none without gate.
def need.used(m: Maybe<&2, Need>, gate: Bool) -> Maybe<&2, Need>:
  Bool.pick(Maybe<&2, Need>, gate, m, None{})

# With gate, a text without a required literal has no match, and no automaton runs; else the
# automata start at the first literal.
def exec(re: Regex, +s: String, +any: Bool) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  Regex{+prog, +fuel, +slots, +start, +lead, bits, +asc, +plain, must, reverse, need, needb, gate} = re
  exec.need(need.used(need, gate), s, any, prog, fuel, slots, start, lead, asc, plain)

# The leftmost match in s: the span of group 0, then of each group; None for a group that did not take part.
def find(re: Regex, +s: String) -> Maybe<&2, List<&2, Maybe<&2, Span>>>:
  find.spans(exec(re, s, False{}))

# The Pike VM form of is_match: stops at the first match of any priority and records no captures.
def is_match.vm(re: Regex, +s: String) -> Bool:
  Maybe.is_some(&2, List<&2, Maybe<&2, U32>>, exec(re, s, True{}))

# One char through the bit NFA: next the sets live after it, fin and end as in Bit.
type Bs is Data:
  Bs{next: U32, fin: Bool, end: Bool}

def bits.take(hit: Bool, +follow: U32, +fin: Bool, +end: Bool, acc: Bs) -> Bs:
  match hit:
    case False{}:
      acc
    case True{}:
      Bs{+nx, f, e} = acc
      Bs{(nx .|. follow : U32), f || fin, e || end}

def bits.char(live: Bool, +c: U32, neg: Bool, items: List<&2, Item>, +follow: U32, +fin: Bool, +end: Bool, acc: Bs) -> Bs:
  match live:
    case False{}:
      acc
    case True{}:
      bits.take(Bool.xor(neg, items.has(items, c)), follow, fin, end, acc)

# ponytail: one test per set in the program, not a table lookup; use per-byte tables if sets grow many.
def bits.step(xs: List<&2, Bit>, +cur: U32, +c: U32, acc: Bs) -> Bs:
  match xs:
    case Nil{}:
      acc
    case Con{Bit{+mask, neg, items, follow, fin, end}, t}:
      bits.step(t, cur, c, bits.char(U32.is_ne((cur .&. mask : U32), 0), c, neg, items, follow, fin, end, acc))

# Only the sets live at a fresh start wait on c, and c starts none of them: nothing moves.
def bits.idle(start: Maybe<&2, List<&2, Inst>>, +cur: U32, +atn: U32, +c: U32) -> Bool:
  match start:
    case None{}:
      False{}
    case Some{sets}:
      U32.is_eq(cur, atn) && Bool.not(starts(sets, c))

# hit1: a match starts and ends at the end of the text, so end starts from it.
def bits.go(idle: Bool, +sets: List<&2, Bit>, +atn: U32, +hit1: Bool, +cur: U32, +c: U32) -> Bs:
  match idle:
    case True{}:
      Bs{atn, False{}, hit1}
    case False{}:
      bits.step(sets, cur, c, Bs{atn, False{}, hit1})

# r: the sets live at s's head, whether a match was found, and whether one ends at the end of
# the text, if the text ends here. Inside the text an assertion can only fail, so fin implies end,
# and a match at fin is final.
def bits.run(s: String, +sets: List<&2, Bit>, +start: Maybe<&2, List<&2, Inst>>, +atn: U32, +hit1: Bool, r: Bs) -> Bool:
  match s:
    case SNil{}:
      Bs{cur, done, ok} = r
      done || ok
    case SCon{Chr{+c}, t}:
      match r:
        case Bs{cur, True{}, ok}:
          True{}
        case Bs{+cur, False{}, ok}:
          bits.run(t, sets, start, atn, hit1, bits.go(bits.idle(start, cur, atn, c), sets, atn, hit1, cur, c))

# From position k of s, no match starting before k: a fresh state past the start, as an idle step leaves.
def bits.is_match(b: Bits, start: Maybe<&2, List<&2, Inst>>, +k: U32, r: String) -> Bool:
  Bits{sets, +at0, +hit0, +hit01, +atn, +hit1} = b
  +zero = U32.is_eq(k, 0)
  bits.run(r, sets, start, atn, hit1, Bs{Bool.pick(U32, zero, at0, atn), Bool.pick(Bool, zero, hit0, False{}), Bool.pick(Bool, zero, hit01, hit1)})

# As exec.lit.
def bits.lit(found: Bool, +r: String, +s: String, b: Bits, start: Maybe<&2, List<&2, Inst>>) -> Bool:
  match found:
    case False{}:
      False{}
    case True{}:
      bits.is_match(b, start, (U32.from_nat(String.length(s)) - U32.from_nat(String.length(r)) : U32), r)

def bits.need(m: Maybe<&2, Need>, +s: String, b: Bits, start: Maybe<&2, List<&2, Inst>>) -> Bool:
  match m:
    case None{}:
      bits.is_match(b, start, 0, s)
    case Some{Need{ls, far}}:
      +r = lits.find.start(s, ls)
      bits.lit(Nat.is_ge(String.length(r), 1n), r, s, b, start)

# The bit NFA form of is_match, or None when the program is too large or has a word boundary.
def is_match.bits(re: Regex, +s: String) -> Maybe<&2, Bool>:
  Regex{prog, fuel, slots, start, lead, bits, asc, plain, must, reverse, need, needb, gate} = re
  match bits:
    case None{}:
      None{}
    case Some{b}:
      Some{bits.need(need.used(need, gate), s, b, start)}

def is_match.pick(m: Maybe<&2, Bool>, re: Regex, +s: String) -> Bool:
  match m:
    case Some{x}:
      x
    case None{}:
      is_match.vm(re, s)

# Whether s has a match; the bit NFA runs when the program allows it, else the Pike VM.
def is_match(+re: Regex, +s: String) -> Bool:
  is_match.pick(is_match.bits(re, s), re, s)

# Bytes
# -----
# The same matchers over a UTF-8 Bytes buffer; positions are byte offsets, as in RE2 and Go.

# A code point decoded from UTF-8 and its width in bytes, or DEnd at the end of the buffer.
# An invalid byte is U+FFFD of width 1, as in RE2.
type Dc is Data:
  Dc{c: U32, w: U32}
  DEnd{}

def Dc.char(d: Dc) -> Maybe<&2, Char>:
  match d:
    case DEnd{}:
      None{}
    case Dc{c, w}:
      Some{Chr{c}}

def pk.if(ok: Bool, a: Array<U32>, +i: U32) -> Array<U32> & U32:
  match ok:
    case True{}:
      Bytes.peek(a, i)
    case False{}:
      (a, 0)

# Byte i, or 0 past len, which is no continuation byte.
def pk(a: Array<U32>, +len: U32, +i: U32) -> Array<U32> & U32:
  pk.if(U32.is_lt(i, len), a, i)

def cont(+b: U32) -> Bool:
  U32.is_eq((b .&. 192 : U32), 128)

def dec.pick(ok2: Bool, ok3: Bool, ok4: Bool, +c2: U32, +c3: U32, +c4: U32) -> Dc:
  match ok2:
    case True{}:
      Dc{c2, 2}
    case False{}:
      match ok3:
        case True{}:
          Dc{c3, 3}
        case False{}:
          match ok4:
            case True{}:
              Dc{c4, 4}
            case False{}:
              Dc{65533, 1}

# Overlong forms, surrogates, and code points past U+10FFFF are invalid.
def dec.n(+b0: U32, +b1: U32, +b2: U32, +b3: U32) -> Dc:
  +x1 = (b1 .&. 63 : U32)
  +x2 = (b2 .&. 63 : U32)
  +x3 = (b3 .&. 63 : U32)
  +c2 = (((b0 .&. 31) << 6n) .|. x1 : U32)
  +c3 = ((((b0 .&. 15) << 12n) .|. (x1 << 6n)) .|. x2 : U32)
  +c4 = (((((b0 .&. 7) << 18n) .|. (x1 << 12n)) .|. (x2 << 6n)) .|. x3 : U32)
  +ok2 = U32.is_le(192, b0) && U32.is_lt(b0, 224) && cont(b1) && U32.is_le(128, c2)
  +ok3 = U32.is_le(224, b0) && U32.is_lt(b0, 240) && cont(b1) && cont(b2) && U32.is_le(2048, c3) && (U32.is_lt(c3, 55296) || U32.is_lt(57343, c3))
  +ok4 = U32.is_le(240, b0) && U32.is_lt(b0, 248) && cont(b1) && cont(b2) && cont(b3) && U32.is_le(65536, c4) && U32.is_le(c4, 1114111)
  dec.pick(ok2, ok3, ok4, c2, c3, c4)

def dec.b3(+b0: U32, +b1: U32, +b2: U32, r: Array<U32> & U32) -> Array<U32> & Dc:
  (a, +b3) = r
  (a, dec.n(b0, b1, b2, b3))

def dec.b2(+len: U32, +i: U32, +b0: U32, +b1: U32, r: Array<U32> & U32) -> Array<U32> & Dc:
  (a, +b2) = r
  dec.b3(b0, b1, b2, pk(a, len, (i + 3 : U32)))

def dec.b1(+len: U32, +i: U32, +b0: U32, r: Array<U32> & U32) -> Array<U32> & Dc:
  (a, +b1) = r
  dec.b2(len, i, b0, b1, pk(a, len, (i + 2 : U32)))

def dec.lead(ascii: Bool, +len: U32, +i: U32, +b0: U32, a: Array<U32>) -> Array<U32> & Dc:
  match ascii:
    case True{}:
      (a, Dc{b0, 1})
    case False{}:
      dec.b1(len, i, b0, pk(a, len, (i + 1 : U32)))

def dec.at(+len: U32, +i: U32, r: Array<U32> & U32) -> Array<U32> & Dc:
  (a, +b0) = r
  dec.lead(U32.is_lt(b0, 128), len, i, b0, a)

def dec.if(ok: Bool, a: Array<U32>, +len: U32, +i: U32) -> Array<U32> & Dc:
  match ok:
    case True{}:
      dec.at(len, i, Bytes.peek(a, i))
    case False{}:
      (a, DEnd{})

# The char at byte i, or DEnd at len.
def dec(a: Array<U32>, +len: U32, +i: U32) -> Array<U32> & Dc:
  dec.if(U32.is_lt(i, len), a, len, i)

def probe.of(+m: Asc, r: Array<U32> & U32) -> Array<U32> & Bool:
  (a, +v) = r
  (a, asc.has(v, m))

# Past len counts as a hit, so a skip stops there.
def probe.if(ok: Bool, a: Array<U32>, +k: U32, +m: Asc) -> Array<U32> & Bool:
  match ok:
    case True{}:
      probe.of(m, Bytes.peek(a, k))
    case False{}:
      (a, True{})

def probe(a: Array<U32>, +len: U32, +k: U32, +m: Asc) -> Array<U32> & Bool:
  probe.if(U32.is_lt(k, len), a, k, m)

# The first offset at or after k whose byte may start a match, or len; r holds the probe of k.
def skip(fuel: Nat, r: Array<U32> & Bool, +len: U32, +k: U32, +m: Asc) -> Array<U32> & U32:
  match fuel:
    case 0n:
      (a, h) = r
      (a, k)
    case 1n+f:
      (a, hit) = r
      match hit:
        case True{}:
          (a, k)
        case False{}:
          skip(f, probe(a, len, (k + 1 : U32), m), len, (k + 1 : U32), m)

def skip.from(a: Array<U32>, +len: U32, +k: U32, +m: Asc) -> Array<U32> & U32:
  skip(U32.to_nat((len - k : U32)), probe(a, len, k, m), len, k, m)

# The Pike VM over Bytes: the buffer, the offset i of the next char, that char, and the threads waiting on it.
type Rb is Type:
  Rb{a: Array<U32>, i: U32, d: Dc, st: Vm}

def rb.step(r: Array<U32> & Dc, +j: U32, st: Vm, +c: U32, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool) -> Rb:
  (a, +d) = r
  Rb{a, j, d, run.step(st, prog, fuel, init, start, any, j, Chr{c}, Dc.char(d))}

# The char before byte k as an assertion reads it: None at 0, an ASCII byte as itself, and
# U+FFFD, which is no word char, for a byte of a wider char. k is on a char boundary.
def prev.byte(r: Array<U32> & U32) -> Array<U32> & Maybe<&2, Char>:
  (a, +b) = r
  (a, Some{Chr{Bool.pick(U32, U32.is_lt(b, 128), b, 65533)}})

def prev.if(z: Bool, a: Array<U32>, +k: U32) -> Array<U32> & Maybe<&2, Char>:
  match z:
    case True{}:
      (a, None{})
    case False{}:
      prev.byte(Bytes.peek(a, (k - 1 : U32)))

def prev.at(a: Array<U32>, +k: U32) -> Array<U32> & Maybe<&2, Char>:
  prev.if(U32.is_eq(k, 0), a, k)

def rb.seed.at(r: Array<U32> & Maybe<&2, Char>, +k: U32, +d: Dc, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>) -> Rb:
  (a, +prev) = r
  Rb{a, k, d, run.close(Sc{Nil{}, None{}, False{}}, prog, fuel, init, start, k, prev, Dc.char(d))}

# A fresh seed at k.
def rb.seed(r: Array<U32> & Dc, +k: U32, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>) -> Rb:
  (a, +d) = r
  rb.seed.at(prev.at(a, k), k, d, prog, fuel, init, start)

def rb.skip(r: Array<U32> & U32, +len: U32, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>) -> Rb:
  (a, +k) = r
  rb.seed(dec(a, len, k), k, prog, fuel, init, start)

# No thread is live and no match exists. With asc, the seed at the char before j was skipped
# because that char cannot start a match: jump to the next byte that may, and seed there with the
# byte before it as prev. Without asc, the
# seed died on an assertion, so step on as usual; prev matters then.
def rb.idle(asc: Maybe<&2, Asc>, a: Array<U32>, +len: U32, +j: U32, +c: U32, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool) -> Rb:
  match asc:
    case None{}:
      rb.step(dec(a, len, j), j, Vm{Nil{}, None{}}, c, prog, fuel, init, start, any)
    case Some{+m}:
      rb.skip(skip.from(a, len, j, m), len, prog, fuel, init, start)

# fuel: each step eats at least one byte, and the last one sees DEnd.
def runb(fuel: Nat, r: Rb, +len: U32, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match fuel:
    case 0n:
      Rb{a, i, d, st} = r
      (a, None{})
    case 1n+f:
      Rb{a, +i, d, st} = r
      match d:
        case DEnd{}:
          Vm{ths, best} = st
          (a, run.end(scan(ths, prog, None{}, any, Sc{Nil{}, best, False{}})))
        case Dc{+c, +w}:
          match st:
            case Vm{Nil{}, Some{b}}:
              (a, Some{b})
            case Vm{Nil{}, None{}}:
              runb(f, rb.idle(asc, a, len, (i + w : U32), c, prog, cfuel, init, start, any), len, prog, cfuel, init, start, asc, any)
            case Vm{ths, best}:
              +j = (i + w : U32)
              runb(f, rb.step(dec(a, len, j), j, Vm{ths, best}, c, prog, cfuel, init, start, any), len, prog, cfuel, init, start, asc, any)

# Lazy DFA
# --------
# The Pike VM step over Bytes, cached per state and ASCII char. A state is the ordered pcs of
# the threads and whether a match was found. A transition is learned once, by running the step
# on symbolic captures: each thread holds only its own index, in an extra last slot, so after the
# step each new thread shows the thread it came from and the slots it saved. Later steps replay
# that on the real captures. Inside the text ^ and $ always fail, so a transition does not depend
# on the chars around it; the last char, which sees the end, takes the plain step. Word boundaries
# read the chars on both sides, so programs with them keep the plain Pike VM.

def sym.caps(+slots: Nat, +i: U32) -> List<&2, Maybe<&2, U32>>:
  List.append(&2, Maybe<&2, U32>, List.replicate(Maybe<&2, U32>, slots, None{}), [Some{i}])

def sym.ths(xs: List<&2, Th>, +slots: Nat, +i: U32) -> List<&2, Th>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Th{pc, caps}, t}:
      Th{pc, sym.caps(slots, i)} <> sym.ths(t, slots, (i + 1 : U32))

# The index in the last slot.
def sym.src(xs: List<&2, Maybe<&2, U32>>) -> U32:
  match xs:
    case Con{Some{x}, Nil{}}:
      x
    case Con{h, t}:
      sym.src(t)
    case Nil{}:
      seed.id()

# The slots before the last that hold a position.
def sym.saves(xs: List<&2, Maybe<&2, U32>>, +k: U32) -> List<&2, U32>:
  match xs:
    case Con{h, Nil{}}:
      Nil{}
    case Con{Some{x}, t}:
      k <> sym.saves(t, (k + 1 : U32))
    case Con{None{}, t}:
      sym.saves(t, (k + 1 : U32))
    case Nil{}:
      Nil{}

def sym.outs(xs: List<&2, Th>) -> List<&2, Op>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Th{+pc, +caps}, t}:
      Op{sym.src(caps), pc, sym.saves(caps, 0)} <> sym.outs(t)

def sym.fresh(xs: List<&2, Op>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{Op{+src, pc, saves}, t}:
      U32.is_eq(src, seed.id()) && sym.fresh(t)

def op.same(saves: List<&2, U32>, +src: U32, +pc: U32, +i: U32, +old: U32) -> Bool:
  match saves:
    case Nil{}:
      U32.is_eq(src, i) && U32.is_eq(pc, old)
    case Con{h, t}:
      False{}

def ops.same(xs: List<&2, Op>, ths: List<&2, Th>, +i: U32) -> Bool:
  match xs ths:
    case Nil{} Nil{}:
      True{}
    case Con{Op{+src, +pc, saves}, t} Con{Th{+old, caps}, rest}:
      op.same(saves, src, pc, i, old) && ops.same(t, rest, (i + 1 : U32))
    case _ _:
      False{}

def tr.of(same: Bool, +next: U32, +hit: U32, +outs: List<&2, Op>, +fresh: Bool) -> Tr:
  match same:
    case True{}:
      TrSame{}
    case False{}:
      Tr{next, hit, outs, fresh}

def sym.lr(+hit: U32, +done: Bool, v: Vm) -> Lr:
  Vm{+ths, best} = v
  +outs = sym.outs(ths)
  Lr{hit, outs, Sk{vm.pcs(ths), done}, Bool.not(done) && sym.fresh(outs)}

def sym.hit(stop: Bool, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> U32:
  match stop:
    case True{}:
      match best:
        case None{}:
          0
        case Some{caps}:
          (sym.src(caps) + 1 : U32)
    case False{}:
      0

# The closure after the char, inside the text: prev and next are any chars, and start is None
# so the seed always runs; replay.vm skips a fresh start the way seed.skip does.
def sym.close(sc: Sc, +done: Bool, +prog: Trie<Inst>, +fuel: Nat, +slots: Nat, +c: U32) -> Lr:
  Sc{items, +best, +stop} = sc
  sym.lr(sym.hit(stop, best), done || stop, run.close(Sc{items, best, stop}, prog, fuel, sym.caps(slots, seed.id()), None{}, 0, Some{Chr{c}}, Some{Chr{c}}))

# Once a match is found no seed starts, so a done state scans with some best.
def sym.best(best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match best:
    case None{}:
      None{}
    case Some{b}:
      Some{Nil{}}

def learn(st: Vm, +c: U32, +prog: Trie<Inst>, +fuel: Nat, +slots: Nat, +any: Bool) -> Lr:
  Vm{ths, +best} = st
  sym.close(scan(sym.ths(ths, slots, 0), prog, Some{Chr{c}}, any, Sc{Nil{}, sym.best(best), False{}}), Maybe.is_some(&2, List<&2, Maybe<&2, U32>>, best), prog, fuel, slots, c)

def caps.at(m: Maybe<&2, Th>, +init: List<&2, Maybe<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  match m:
    case None{}:
      init
    case Some{Th{pc, caps}}:
      caps

def caps.of.if(seed: Bool, +src: U32, +ths: List<&2, Th>, +init: List<&2, Maybe<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  match seed:
    case True{}:
      init
    case False{}:
      caps.at(List.get(&2, Th, ths, U32.to_nat(src)), init)

def caps.of(+src: U32, +ths: List<&2, Th>, +init: List<&2, Maybe<&2, U32>>) -> List<&2, Maybe<&2, U32>>:
  caps.of.if(U32.is_eq(src, seed.id()), src, ths, init)

def saves.put(xs: List<&2, U32>, caps: List<&2, Maybe<&2, U32>>, +pos: U32) -> List<&2, Maybe<&2, U32>>:
  match xs:
    case Nil{}:
      caps
    case Con{+k, t}:
      saves.put(t, List.set(&2, Maybe<&2, U32>, caps, U32.to_nat(k), Some{pos}), pos)

def replay(xs: List<&2, Op>, +ths: List<&2, Th>, +init: List<&2, Maybe<&2, U32>>, +pos: U32) -> List<&2, Th>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Op{+src, pc, saves}, t}:
      Th{pc, saves.put(saves, caps.of(src, ths, init), pos)} <> replay(t, ths, init, pos)

def replay.best(none: Bool, +hit: U32, +ths: List<&2, Th>, +init: List<&2, Maybe<&2, U32>>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match none:
    case True{}:
      best
    case False{}:
      Some{caps.of((hit - 1 : U32), ths, init)}

# fresh: no match yet and every thread starts at the seed; skip it when next cannot start a match.
def replay.fresh(skip: Bool, outs: List<&2, Op>, +ths: List<&2, Th>, +init: List<&2, Maybe<&2, U32>>, +pos: U32) -> Vm:
  match skip:
    case True{}:
      Vm{Nil{}, None{}}
    case False{}:
      Vm{replay(outs, ths, init, pos), None{}}

# A learned transition on the real threads; next is the char after the new position.
def replay.vm(fresh: Bool, +hit: U32, outs: List<&2, Op>, st: Vm, +init: List<&2, Maybe<&2, U32>>, +pos: U32, +start: Maybe<&2, List<&2, Inst>>, +next: Maybe<&2, Char>) -> Vm:
  match fresh:
    case True{}:
      Vm{+ths, best} = st
      replay.fresh(seed.skip(Nil{}, None{}, start, next), outs, ths, init, pos)
    case False{}:
      Vm{+ths, best} = st
      Vm{replay(outs, ths, init, pos), replay.best(U32.is_eq(hit, 0), hit, ths, init, best)}

# The DFA over Bytes: the buffer, the transitions by state and ASCII char, the interned states,
# the current state, the offset i of the next char, that char, and the threads waiting on it.
type Rq is Type:
  Rq{a: Array<U32>, tab: Array<Tr>, keys: Trie<List<&2, Ix>>, n: U32, id: U32, i: U32, d: Dc, st: Vm, same: Bool}

def rq.ik(ik: Ik, a: Array<U32>, tab: Array<Tr>, +j: U32, +d: Dc, st: Vm) -> Rq:
  Ik{keys, n, id} = ik
  Rq{a, tab, keys, n, id, j, d, st, False{}}

def rq.of(r: Rb, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +cap: U32) -> Rq:
  Rb{a, +i, +d, +st} = r
  rq.ik(intern(keys, n, cap, vm.key(st)), a, tab, i, d, st)

def rq.store(ik: Ik, a: Array<U32>, tab: Array<Tr>, +idx: U32, +old: U32, +hit: U32, +outs: List<&2, Op>, +fresh: Bool, +j: U32, +d: Dc, st: Vm, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>) -> Rq:
  Ik{keys, +n, +id} = ik
  Vm{+ths, +best} = st
  +same = U32.is_eq(id, old) && U32.is_eq(hit, 0) && ops.same(outs, ths, 0)
  Rq{a, Array.set(Tr, tab, idx, tr.of(same, id, hit, outs, fresh)), keys, n, id, j, d, replay.vm(fresh, hit, outs, Vm{ths, best}, init, j, start, Dc.char(d)), same}

def rq.learn(lr: Lr, a: Array<U32>, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +idx: U32, +old: U32, +j: U32, +d: Dc, st: Vm, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +cap: U32) -> Rq:
  Lr{+hit, +outs, +key, +fresh} = lr
  rq.store(intern(keys, n, cap, key), a, tab, idx, old, hit, outs, fresh, j, d, st, init, start)

# With a full cache, skip building the key too.
def rq.real(room: Bool, a: Array<U32>, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +j: U32, +d: Dc, +st: Vm, +cap: U32) -> Rq:
  match room:
    case True{}:
      rq.ik(intern(keys, n, cap, vm.key(st)), a, tab, j, d, st)
    case False{}:
      Rq{a, tab, keys, n, seed.id(), j, d, st, False{}}

# A same transition leaves the VM and state id intact. Stop before the last byte:
# its following end-of-text context needs the plain Pike step.
type Spin is Type:
  Spin{a: Array<U32>, tab: Array<Tr>, i: U32}

type SpinStep is Type:
  SpinStep{a: Array<U32>, tab: Array<Tr>, i: U32, tr: Tr}

def spin.byte(last: Bool, a: Array<U32>, +i: U32) -> Array<U32> & U32:
  match last:
    case True{}:
      (a, 128)
    case False{}:
      Bytes.peek(a, i)

def spin.tr(ascii: Bool, tab: Array<Tr>, +id: U32, +c: U32) -> Array<Tr> & Tr:
  match ascii:
    case True{}:
      Array.get(Tr, tab, ((id * 128) + c : U32))
    case False{}:
      (tab, TrNo{})

def spin.state.tr(r: Array<Tr> & Tr, a: Array<U32>, +i: U32) -> SpinStep:
  (tab, tr) = r
  SpinStep{a, tab, i, tr}

def spin.state(r: Array<U32> & U32, tab: Array<Tr>, +i: U32, +id: U32, +cap: U32) -> SpinStep:
  (a, +c) = r
  spin.state.tr(spin.tr(U32.is_lt(c, 128) && U32.is_lt(id, cap), tab, id, c), a, i)

def spin(fuel: Nat, s: SpinStep, +len: U32, +id: U32, +cap: U32) -> Spin:
  match fuel:
    case 0n:
      SpinStep{a, tab, i, tr} = s
      Spin{a, tab, i}
    case 1n+f:
      SpinStep{a, tab, +i, tr} = s
      match tr:
        case TrSame{}:
          +j = (i + 1 : U32)
          spin(f, spin.state(spin.byte(Bool.not(U32.is_lt((j + 1 : U32), len)), a, j), tab, j, id, cap), len, id, cap)
        case TrNo{}:
          Spin{a, tab, i}
        case Tr{next, hit, outs, fresh}:
          Spin{a, tab, i}

# Cached DFA steps reuse two thread buffers; the Pike VM handles learning and text boundaries.
type Ar is Type:
  Ar{old: Array<Th>, spare: Array<Th>, count: U32, cap: U32, best: Maybe<&2, List<&2, Maybe<&2, U32>>>}

def ar.fill(xs: List<&2, Th>, a: Array<Th>, +i: U32) -> Array<Th>:
  match xs:
    case Nil{}:
      a
    case Con{th, rest}:
      ar.fill(rest, Array.set(Th, a, i, th), (i + 1 : U32))

def ar.reset.size(fits: Bool, ths: List<&2, Th>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>, old: Array<Th>, spare: Array<Th>, +count: U32, +cap: U32, +init: List<&2, Maybe<&2, U32>>) -> Ar:
  match fits:
    case True{}:
      Ar{ar.fill(ths, old, 0), spare, count, cap, best}
    case False{}:
      +depth = Nat.add(U32.log2(count), 1n)
      Ar{ar.fill(ths, Array.new(Th, depth, Th{0, init}), 0), Array.new(Th, depth, Th{0, init}), count, U32.shln(1, depth), best}

def ar.reset.put(vm: Vm, old: Array<Th>, spare: Array<Th>, +cap: U32, +init: List<&2, Maybe<&2, U32>>) -> Ar:
  Vm{+ths, best} = vm
  +count = U32.from_nat(List.length(&2, Th, ths))
  ar.reset.size(U32.is_le(count, cap), ths, best, old, spare, count, cap, init)

def ar.reset(vm: Vm, ar: Ar, +init: List<&2, Maybe<&2, U32>>) -> Ar:
  Ar{old, spare, count, cap, best} = ar
  ar.reset.put(vm, old, spare, cap, init)

def ar.new(vm: Vm, +init: List<&2, Maybe<&2, U32>>) -> Ar:
  ar.reset(vm, Ar{Array.new(Th, 2n, Th{0, init}), Array.new(Th, 2n, Th{0, init}), 0, 4, None{}}, init)

def ar.list.go(fuel: Nat, r: Array<Th> & Th, +i: U32, acc: List<&2, Th>) -> Array<Th> & List<&2, Th>:
  match fuel:
    case 0n:
      (a, th) = r
      (a, acc)
    case 1n+f:
      (a, th) = r
      ar.list.go(f, Array.get(Th, a, (i - 1 : U32)), (i - 1 : U32), th <> acc)

def ar.vm.put(r: Array<Th> & List<&2, Th>, spare: Array<Th>, +count: U32, +cap: U32, +best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Ar & Vm:
  (old, ths) = r
  (Ar{old, spare, count, cap, best}, Vm{ths, best})

def ar.vm(ar: Ar) -> Ar & Vm:
  Ar{old, spare, +count, +cap, +best} = ar
  ar.vm.put(ar.list.go(U32.to_nat(count), Array.get(Th, old, (count - 1 : U32)), (count - 1 : U32), Nil{}), spare, count, cap, best)

def ar.src.get(r: Array<Th> & Th) -> Array<Th> & List<&2, Maybe<&2, U32>>:
  (old, Th{pc, caps}) = r
  (old, caps)

def ar.src(seed: Bool, old: Array<Th>, +src: U32, +init: List<&2, Maybe<&2, U32>>) -> Array<Th> & List<&2, Maybe<&2, U32>>:
  match seed:
    case True{}:
      (old, init)
    case False{}:
      ar.src.get(Array.get(Th, old, src))

def ar.put(r: Array<Th> & List<&2, Maybe<&2, U32>>, spare: Array<Th>, +pc: U32, saves: List<&2, U32>, +pos: U32, +i: U32) -> Array<Th> & Array<Th>:
  (old, caps) = r
  (old, Array.set(Th, spare, i, Th{pc, saves.put(saves, caps, pos)}))

def ar.replay(xs: List<&2, Op>, r: Array<Th> & Array<Th>, +init: List<&2, Maybe<&2, U32>>, +pos: U32, +i: U32, +cap: U32, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Ar:
  match xs:
    case Nil{}:
      (old, spare) = r
      Ar{spare, old, i, cap, best}
    case Con{Op{+src, +pc, saves}, rest}:
      (old, spare) = r
      ar.replay(rest, ar.put(ar.src(U32.is_eq(src, seed.id()), old, src, init), spare, pc, saves, pos, i), init, pos, (i + 1 : U32), cap, best)

def ar.best.get(r: Array<Th> & List<&2, Maybe<&2, U32>>) -> Array<Th> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  (old, caps) = r
  (old, Some{caps})

def ar.best.none(no_hit: Bool, old: Array<Th>, +hit: U32, +init: List<&2, Maybe<&2, U32>>, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Array<Th> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match no_hit:
    case True{}:
      (old, best)
    case False{}:
      ar.best.get(ar.src(U32.is_eq((hit - 1 : U32), seed.id()), old, (hit - 1 : U32), init))

def ar.replay.best(r: Array<Th> & Maybe<&2, List<&2, Maybe<&2, U32>>>, spare: Array<Th>, outs: List<&2, Op>, +cap: U32, +init: List<&2, Maybe<&2, U32>>, +pos: U32) -> Ar:
  (old, best) = r
  ar.replay(outs, (old, spare), init, pos, 0, cap, best)

def ar.cached.fresh(skip: Bool, ar: Ar, outs: List<&2, Op>, +init: List<&2, Maybe<&2, U32>>, +pos: U32) -> Ar:
  match skip:
    case True{}:
      Ar{old, spare, size, +cap, best} = ar
      Ar{old, spare, 0, cap, None{}}
    case False{}:
      Ar{old, spare, size, +cap, best} = ar
      ar.replay.best((old, None{}), spare, outs, cap, init, pos)

# A cached transition was learned in this run, so the buffers already fit its outputs.
def ar.cached(fresh: Bool, +hit: U32, outs: List<&2, Op>, ar: Ar, +init: List<&2, Maybe<&2, U32>>, +pos: U32, +start: Maybe<&2, List<&2, Inst>>, +next: Maybe<&2, Char>) -> Ar:
  match fresh:
    case True{}:
      ar.cached.fresh(seed.skip(Nil{}, None{}, start, next), ar, outs, init, pos)
    case False{}:
      Ar{old, spare, size, +cap, best} = ar
      ar.replay.best(ar.best.none(U32.is_eq(hit, 0), old, hit, init, best), spare, outs, cap, init, pos)

type Qst is Type:
  QDone{best: List<&2, Maybe<&2, U32>>}
  QIdle{ar: Ar}
  QLive{ar: Ar}
  QPlain{st: Vm}

def qa.status.if(zero: Bool, old: Array<Th>, spare: Array<Th>, +count: U32, +cap: U32, best: Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Qst:
  match zero:
    case False{}:
      QLive{Ar{old, spare, count, cap, best}}
    case True{}:
      match best:
        case Some{caps}:
          QDone{caps}
        case None{}:
          QIdle{Ar{old, spare, count, cap, None{}}}

def qa.status(ar: Ar) -> Qst:
  Ar{old, spare, +count, +cap, best} = ar
  qa.status.if(U32.is_zero(count), old, spare, count, cap, best)

type Qa is Type:
  Qa{a: Array<U32>, tab: Array<Tr>, keys: Trie<List<&2, Ix>>, n: U32, id: U32, i: U32, d: Dc, ar: Qst, same: Bool}

def qa.seed(r: Rq, +init: List<&2, Maybe<&2, U32>>) -> Qa:
  Rq{a, tab, keys, n, id, i, d, st, same} = r
  Qa{a, tab, keys, n, id, i, d, qa.status(ar.new(st, init)), same}

def qa.from.state(cached: Bool, st: Vm, ar: Ar, +init: List<&2, Maybe<&2, U32>>) -> Qst:
  match cached:
    case True{}:
      qa.status(ar.reset(st, ar, init))
    case False{}:
      QPlain{st}

def qa.from(r: Rq, ar: Ar, +init: List<&2, Maybe<&2, U32>>, +cap: U32) -> Qa:
  Rq{a, tab, keys, n, +id, i, d, st, same} = r
  Qa{a, tab, keys, n, id, i, d, qa.from.state(U32.is_lt(id, cap), st, ar, init), same}

def qa.learn.vm(r: Ar & Vm, a: Array<U32>, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +idx: U32, +j: U32, +d: Dc, +c: U32, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat, +cap: U32) -> Qa:
  (ar, +st) = r
  qa.from(rq.learn(learn(st, c, prog, cfuel, slots, any), a, tab, keys, n, idx, (idx / 128 : U32), j, d, st, init, start, cap), ar, init, cap)

def qa.real.vm(r: Ar & Vm, s: Array<U32> & Dc, +j: U32, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +c: U32, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool, +cap: U32) -> Qa:
  (ar, st) = r
  (a, +d) = s
  qa.from(rq.real(U32.is_lt(n, cap), a, tab, keys, n, j, d, run.step(st, prog, cfuel, init, start, any, j, Chr{c}, Dc.char(d)), cap), ar, init, cap)

def qa.real(s: Array<U32> & Dc, +j: U32, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, ar: Ar, +c: U32, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool, +cap: U32) -> Qa:
  qa.real.vm(ar.vm(ar), s, j, tab, keys, n, c, prog, cfuel, init, start, any, cap)

def qa.cached(r: Array<Tr> & Tr, a: Array<U32>, +keys: Trie<List<&2, Ix>>, +n: U32, +idx: U32, +j: U32, +d: Dc, ar: Ar, +c: U32, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat, +cap: U32) -> Qa:
  (tab, tr) = r
  match tr:
    case TrNo{}:
      qa.learn.vm(ar.vm(ar), a, tab, keys, n, idx, j, d, c, prog, cfuel, init, start, any, slots, cap)
    case TrSame{}:
      Qa{a, tab, keys, n, (idx / 128 : U32), j, d, qa.status(ar), True{}}
    case Tr{+next, +hit, +outs, +fresh}:
      Qa{a, tab, keys, n, next, j, d, qa.status(ar.cached(fresh, hit, outs, ar, init, j, start, Dc.char(d))), False{}}

def qa.pick(ok: Bool, a: Array<U32>, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +id: U32, +j: U32, +d: Dc, ar: Ar, +c: U32, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat, +cap: U32) -> Qa:
  match ok:
    case True{}:
      +idx = ((id * 128) + c : U32)
      qa.cached(Array.get(Tr, tab, idx), a, keys, n, idx, j, d, ar, c, prog, cfuel, init, start, any, slots, cap)
    case False{}:
      qa.real((a, d), j, tab, keys, n, ar, c, prog, cfuel, init, start, any, cap)

def qa.step(s: Array<U32> & Dc, +j: U32, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +id: U32, ar: Ar, +c: U32, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat, +cap: U32) -> Qa:
  (a, +d) = s
  qa.pick(U32.is_lt(c, 128) && U32.is_lt(id, cap) && Maybe.is_some(&2, Char, Dc.char(d)), a, tab, keys, n, id, j, d, ar, c, prog, cfuel, init, start, any, slots, cap)

def qa.spin.read(s: Array<U32> & Dc, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +id: U32, +i: U32, ar: Qst) -> Qa:
  (a, d) = s
  Qa{a, tab, keys, n, id, i, d, ar, False{}}

def qa.spin.dec(moved: Bool, a: Array<U32>, tab: Array<Tr>, +len: U32, +keys: Trie<List<&2, Ix>>, +n: U32, +id: U32, +i: U32, d: Dc, ar: Qst) -> Qa:
  match moved:
    case True{}:
      qa.spin.read(dec(a, len, i), tab, keys, n, id, i, ar)
    case False{}:
      Qa{a, tab, keys, n, id, i, d, ar, False{}}

def qa.spin.at(s: Spin, +old: U32, +len: U32, +keys: Trie<List<&2, Ix>>, +n: U32, +id: U32, d: Dc, ar: Qst) -> Qa:
  Spin{a, tab, +i} = s
  qa.spin.dec(U32.is_ne(i, old), a, tab, len, keys, n, id, i, d, ar)

def qa.spin.if(same: Bool, a: Array<U32>, tab: Array<Tr>, +keys: Trie<List<&2, Ix>>, +n: U32, +id: U32, +i: U32, d: Dc, ar: Qst, +fuel: Nat, +len: U32, +cap: U32) -> Qa:
  match same:
    case True{}:
      qa.spin.at(spin(fuel, spin.state(spin.byte(Bool.not(U32.is_lt((i + 1 : U32), len)), a, i), tab, i, id, cap), len, id, cap), i, len, keys, n, id, d, ar)
    case False{}:
      Qa{a, tab, keys, n, id, i, d, ar, False{}}

def qa.spin(r: Qa, +fuel: Nat, +len: U32, +cap: U32) -> Qa:
  Qa{a, tab, keys, n, +id, +i, d, ar, same} = r
  qa.spin.if(same, a, tab, keys, n, id, i, d, ar, fuel, len, cap)

def qa.end.vm(st: Vm, a: Array<U32>, +prog: Trie<Inst>, +any: Bool) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  Vm{ths, best} = st
  (a, run.end(scan(ths, prog, None{}, any, Sc{Nil{}, best, False{}})))

def qa.end(r: Ar & Vm, a: Array<U32>, +prog: Trie<Inst>, +any: Bool) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  (ar, st) = r
  qa.end.vm(st, a, prog, any)

def qa.end.status(st: Qst, a: Array<U32>, +prog: Trie<Inst>, +any: Bool) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match st:
    case QDone{best}:
      (a, Some{best})
    case QIdle{ar}:
      qa.end(ar.vm(ar), a, prog, any)
    case QLive{ar}:
      qa.end(ar.vm(ar), a, prog, any)
    case QPlain{st}:
      qa.end.vm(st, a, prog, any)

# Each step consumes a byte; after the cache fills, continue in the plain Pike VM.
def runqa(+fuel: Nat, r: Qa, +len: U32, +prog: Trie<Inst>, +cfuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool, +slots: Nat, +cap: U32) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match fuel:
    case 0n:
      Qa{a, tab, keys, n, id, i, d, ar, same} = r
      (a, None{})
    case 1n+f:
      Qa{a, tab, +keys, +n, +id, +i, d, ar, same} = r
      match d:
        case DEnd{}:
          qa.end.status(ar, a, prog, any)
        case Dc{+c, +w}:
          match ar:
            case QDone{best}:
              (a, Some{best})
            case QIdle{ar}:
              runqa(f, qa.from(rq.of(rb.idle(asc, a, len, (i + w : U32), c, prog, cfuel, init, start, any), tab, keys, n, cap), ar, init, cap), len, prog, cfuel, init, start, asc, any, slots, cap)
            case QLive{ar}:
              +j = (i + w : U32)
              runqa(f, qa.spin(qa.step(dec(a, len, j), j, tab, keys, n, id, ar, c, prog, cfuel, init, start, any, slots, cap), f, len, cap), len, prog, cfuel, init, start, asc, any, slots, cap)
            case QPlain{st}:
              runb(Nat.add(f, 1n), Rb{a, i, Dc{c, w}, st}, len, prog, cfuel, init, start, asc, any)

def exec.bytes.fin(+len: U32, r: Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  (a, m) = r
  (Bytes.Bytes{len, a}, m)

# Short large programs use the plain VM; long large programs can use 2048 states.
def exec.bytes.go.if(use: Bool, +len: U32, +from: U32, buf: Array<U32>, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool, +slots: Nat) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match use:
    case True{}:
      +small = U32.is_lt(len, 4096)
      +wide = Nat.is_ge(fuel, 300n)
      +cap = Bool.pick(U32, small, 8, Bool.pick(U32, wide, 2048, 256))
      runqa(Nat.add(U32.to_nat((len - from : U32)), 2n), qa.seed(rq.of(rb.seed(dec(buf, len, from), from, prog, fuel, init, start), Array.new(Tr, Bool.pick(Nat, small, 10n, Bool.pick(Nat, wide, 18n, 15n)), TrNo{}), TTip{}, 0, cap), init), len, prog, fuel, init, start, asc, any, slots, cap)
    case False{}:
      runb(Nat.add(U32.to_nat((len - from : U32)), 2n), rb.seed(dec(buf, len, from), from, prog, fuel, init, start), len, prog, fuel, init, start, asc, any)

def exec.bytes.go(plain: Bool, +len: U32, +from: U32, buf: Array<U32>, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool, +slots: Nat) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  exec.bytes.go.if(plain && (U32.is_le(4096, len) || Bool.not(Nat.is_ge(fuel, 300n))), len, from, buf, prog, fuel, init, start, asc, any, slots)

# The DFA over Bytes
# -------------------
def dc.c(d: Dc) -> U32:
  match d:
    case Dc{+c, w}:
      c
    case DEnd{}:
      65533

def dc.w(d: Dc) -> U32:
  match d:
    case Dc{c, +w}:
      w
    case DEnd{}:
      1

# A decoded char packed in one word: its width above bit 24, its code point below; 0 at the end.
def dc.pack(d: Dc) -> U32:
  match d:
    case Dc{+c, +w}:
      ((w << 24n) .|. c : U32)
    case DEnd{}:
      0

def dec.pack.of(r: Array<U32> & Dc) -> Array<U32> & U32:
  (a, +d) = r
  (a, dc.pack(d))

def dec.pack(a: Array<U32>, +len: U32, +i: U32) -> Array<U32> & U32:
  dec.pack.of(dec(a, len, i))

# Skip from k to the next char that may start a match: ASCII bytes by the table m, wide chars by
# the sets of lead. ph: 1 r holds the table skip's offset, so decode the char there; 0 r holds
# the char at k, packed; 2 r holds the answer. fuel: every two rounds pass at least one byte.
def skip.wide(fuel: Nat, +ph: U32, r: Array<U32> & U32, +len: U32, +k: U32, +m: Asc, +sets: List<&2, Inst>) -> Array<U32> & U32:
  match fuel:
    case 0n:
      (a, x) = r
      (a, k)
    case 1n+f:
      match ph:
        case 1:
          (a, +k2) = r
          r2 = dec.pack(a, len, k2)
          skip.wide(f, 0, r2, len, k2, m, sets)
        case 0:
          (a, +cw) = r
          +c = (cw .&. 16777215 : U32)
          +w = (cw >> 24n : U32)
          +stop = U32.is_eq(w, 0) || U32.is_lt(c, 128) || starts(sets, c)
          +kw = (k + w : U32)
          +at = Bool.pick(U32, stop, k, kw)
          +ph2 = Bool.pick(U32, stop, 2, 1)
          r2 = skip.from(a, len, at, m)
          skip.wide(f, ph2, r2, len, k, m, sets)
        case _:
          r

# The round after a step to state id, the next char at i: DbFull when the cache is full, DbEnd
# at the end of the text, DbSkip in an idle state that skips, else ready (DbRead when the next
# read is primed, else DbPrime).
def dfa.mode(+id: U32, +i: U32, +len: U32, +sk: Bool, +ready: Db) -> Db:
  +full = U32.is_eq(id, seed.id())
  +more = U32.is_lt(i, len)
  +isk = sk && U32.is_le(id, 2)
  +m0 = Bool.pick(Db, isk, DbSkip{}, ready)
  +m1 = Bool.pick(Db, more, m0, DbEnd{})
  Bool.pick(Db, full, DbFull{}, m1)

def dfab.end(r: Array<Sk> & Sk, a: Array<U32>, +p: U32, +prog: Trie<Inst>, +cfuel: Nat) -> Array<U32> & Dr:
  (sts, +key) = r
  (a, dr.end(dt.hit(dfa.go(prog, cfuel, key, None{})), p))

# A step learned over bytes: the buffer, the char's width, the step.
type Dlb is Type:
  Dlb{a: Array<U32>, w: U32, dl: Dl}

type Dzb is Type:
  Dzb0{}
  DzbL{dl: Dlb}

def dfab.learn(rd: Array<U32> & Dc, r: Array<Sk> & Sk, tab: Array<U32>, +keys: Trie<List<&2, Ix>>, +n: U32, +id: U32, +prog: Trie<Inst>, +cfuel: Nat, +wb: Bool, +cap: U32) -> Dlb:
  (a, +d) = rd
  Dlb{a, dc.w(d), dfa.learn(r, tab, keys, n, id, dc.c(d), prog, cfuel, wb, cap)}

# The rounds of dfab.
type Db is Data:
  DbRead{}     # read the byte b at i in state id
  DbPrime{}    # prime DbRead at i
  DbSkip{}     # skip from the idle state id at i
  DbSkipped{}  # take the skip's offset
  DbKind{}     # take the kind of the byte before i
  DbLearn{}    # learn the step on the char at i
  DbTake{}     # take the step learned, from z
  DbEnd{}      # the end of the text
  DbHit{}      # a match
  DbFull{}     # a full cache

# The DFA over the bytes of a, up to len; mode picks the round. A read hands back the array
# beside the value, and a round may not take apart a computed value, so each round passes its
# reads to the next: ra the buffer and, in DbRead, the byte after b; rt the table and, in
# DbRead, its entry for id and b. p: the last idle point. fuel: each byte takes at most six
# rounds. Each value the next round takes is bound first, so no round delays work into it.
def dfab(fuel: Nat, +mode: Db, z: Dzb, ra: Array<U32> & U32, rt: Array<U32> & U32, sts: Array<Sk>, +keys: Trie<List<&2, Ix>>, +n: U32, +len: U32, +i: U32, +id: U32, +p: U32, +b: U32, +prog: Trie<Inst>, +cfuel: Nat, +wb: Bool, +am: Asc, +sets: List<&2, Inst>, +sk: Bool, +cap: U32) -> Array<U32> & Dr:
  match fuel:
    case 0n:
      (a, x) = ra
      (a, DFull{p})
    case 1n+f:
      match mode:
        case DbRead{}:
          (a, +wn) = ra
          (tab, +e) = rt
          +bn = byte.at(wn, (i + 1 : U32))
          +ascii = U32.is_lt(b, 128)
          +adv = ascii && U32.is_le(2, e)
          +e2 = (e - 2 : U32)
          +id2 = Bool.pick(U32, adv, e2, id)
          +i1 = (i + 1 : U32)
          +i2 = Bool.pick(U32, adv, i1, i)
          +idle = adv && U32.is_le(id2, 2)
          +p2 = Bool.pick(U32, idle, i2, p)
          +far = sk && Bool.not(asc.has(bn, am))
          +md = dfa.mode(id2, i2, len, far, DbRead{})
          +hit = ascii && U32.is_eq(e, 1)
          +mh = Bool.pick(Db, hit, DbHit{}, DbLearn{})
          +m = Bool.pick(Db, adv, md, mh)
          +b2 = Bool.pick(U32, adv, bn, b)
          +nx = (i2 + 1 : U32)
          +col = ((id2 * 128) + bn : U32)
          +idx = Bool.pick(U32, adv, col, 0)
          ra2 = Array.get(U32, a, (nx >> 2n : U32))
          rt2 = Array.get(U32, tab, idx)
          dfab(f, m, Dzb0{}, ra2, rt2, sts, keys, n, len, i2, id2, p2, b2, prog, cfuel, wb, am, sets, sk, cap)
        case DbSkip{}:
          (a, x) = ra
          ra2 = skip.wide(Nat.add(Nat.mul(2n, U32.to_nat((len - i : U32))), 4n), 1, skip.from(a, len, i, am), len, i, am, sets)
          dfab(f, DbSkipped{}, Dzb0{}, ra2, rt, sts, keys, n, len, i, id, p, b, prog, cfuel, wb, am, sets, sk, cap)
        case DbLearn{}:
          (a, x) = ra
          (tab, e) = rt
          z2 = {DzbL{dfab.learn(dec(a, len, i), Array.get(Sk, sts, id), tab, keys, n, id, prog, cfuel, wb, cap)} : Dzb}
          ra2 = {(Array.new(U32, 0n, 0), 0) : Array<U32> & U32}
          rt2 = {(Array.new(U32, 0n, 0), 0) : Array<U32> & U32}
          sts2 = Array.new(Sk, 0n, dk.key(0, Nil{}))
          dfab(f, DbTake{}, z2, ra2, rt2, sts2, keys, n, len, i, id, p, b, prog, cfuel, wb, am, sets, sk, cap)
        case DbTake{}:
          match z:
            case DzbL{Dlb{a2, +w, Dl{t2, s2, +k2, +n2, +id2, +hit}}}:
              +i2 = (i + w : U32)
              +md = dfa.mode(id2, i2, len, sk, DbPrime{})
              +m = Bool.pick(Db, hit, DbHit{}, md)
              +idle = U32.is_ne(id2, seed.id()) && U32.is_le(id2, 2)
              +p2 = Bool.pick(U32, idle, i2, p)
              ra2 = Array.get(U32, a2, (i2 >> 2n : U32))
              rt2 = {(t2, 0) : Array<U32> & U32}
              dfab(f, m, Dzb0{}, ra2, rt2, s2, k2, n2, len, i2, id2, p2, b, prog, cfuel, wb, am, sets, sk, cap)
            case Dzb0{}:
              (a, x) = ra
              (a, DFull{p})
        case DbPrime{}:
          (a, +w0) = ra
          (tab, e) = rt
          +bc = byte.at(w0, i)
          +nx = (i + 1 : U32)
          +idx = ((id * 128) + bc : U32)
          ra2 = Array.get(U32, a, (nx >> 2n : U32))
          rt2 = Array.get(U32, tab, idx)
          dfab(f, DbRead{}, Dzb0{}, ra2, rt2, sts, keys, n, len, i, id, p, bc, prog, cfuel, wb, am, sets, sk, cap)
        case DbSkipped{}:
          (a, +k) = ra
          +moved = U32.is_ne(k, i)
          +km = (k - 1 : U32)
          +at = Bool.pick(U32, moved, km, k)
          +m = Bool.pick(Db, moved, DbKind{}, DbPrime{})
          ra2 = Array.get(U32, a, (at >> 2n : U32))
          dfab(f, m, Dzb0{}, ra2, rt, sts, keys, n, len, k, id, p, b, prog, cfuel, wb, am, sets, sk, cap)
        case DbKind{}:
          (a, +w0) = ra
          +pb = byte.at(w0, (i - 1 : U32))
          +more = U32.is_lt(i, len)
          +m = Bool.pick(Db, more, DbPrime{}, DbEnd{})
          +kw = dk.of(wb, pb)
          +low = U32.is_lt(pb, 128)
          +kd = Bool.pick(U32, low, kw, 1)
          ra2 = Array.get(U32, a, (i >> 2n : U32))
          dfab(f, m, Dzb0{}, ra2, rt, sts, keys, n, len, i, kd, i, b, prog, cfuel, wb, am, sets, sk, cap)
        case DbEnd{}:
          (a, x) = ra
          dfab.end(Array.get(Sk, sts, id), a, p, prog, cfuel)
        case DbHit{}:
          (a, x) = ra
          (a, DHit{p})
        case DbFull{}:
          (a, x) = ra
          (a, DFull{p})

# The DFA from byte from: the state there is idle, of the kind of the byte before.
def dfab.init(r: Array<U32> & U32, +len: U32, +from: U32, +prog: Trie<Inst>, +cfuel: Nat, +wb: Bool, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>) -> Array<U32> & Dr:
  (a, +pb) = r
  +id = Bool.pick(U32, U32.is_eq(from, 0), 0, Bool.pick(U32, U32.is_lt(pb, 128), dk.of(wb, pb), 1))
  +rest = (len - from : U32)
  +cap = dk.cap(rest)
  +sk = dk.sk(lead, asc)
  dfab(Nat.add(Nat.mul(6n, U32.to_nat(rest)), 16n), dfa.mode(id, from, len, sk, DbPrime{}), Dzb0{}, Array.get(U32, a, (from >> 2n : U32)), (Array.new(U32, dk.tab(rest), 0), 0), dk.sts(dk.depth(rest)), dk.keys(cap), 3, len, from, id, from, 0, prog, cfuel, wb, asc.or(asc), lead.sets(lead), sk, cap)

def exec.bytes.hit(any: Bool, a: Array<U32>, +len: U32, +p: U32, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +slots: Nat) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match any:
    case True{}:
      (a, Some{Nil{}})
    case False{}:
      exec.bytes.go(plain, len, p, a, prog, fuel, init, start, asc, False{}, slots)

# After the DFA: with any, a match found is the answer; else the Pike VM runs from the idle point.
def exec.bytes.dr(r: Array<U32> & Dr, +len: U32, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool, +slots: Nat) -> Array<U32> & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  (a, +d) = r
  match d:
    case DNo{}:
      (a, None{})
    case DHit{+p}:
      exec.bytes.hit(any, a, len, p, plain, prog, fuel, init, start, asc, slots)
    case DFull{+p}:
      exec.bytes.go(plain, len, p, a, prog, fuel, init, start, asc, any, slots)

# The DFA, then the Pike VM, from byte k, a char boundary: no match starts before k.
def exec.bytes.from(b: Bytes.Bytes, +k: U32, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  Bytes.Bytes{+len, buf} = b
  exec.bytes.fin(len, exec.bytes.dr(dfab.init(Bytes.peek(buf, (k - 1 : U32)), len, k, prog, fuel, Bool.not(plain), asc, lead), len, plain, prog, fuel, init, start, asc, any, slots))

def exec.bytes.run(b: Bytes.Bytes, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  exec.bytes.from(b, 0, plain, prog, fuel, init, start, asc, lead, any, slots)

# Required literals over Bytes
# ----------------------------

# Whether the bytes from k spell the literal l; ok: whether those before k did; r: byte k.
def blit.go(l: List<&2, List<&2, U32>>, ok: Bool, r: Array<U32> & U32, +len: U32, +k: U32) -> Array<U32> & Bool:
  match l:
    case Nil{}:
      (a, v) = r
      (a, ok)
    case Con{set, t}:
      match ok:
        case False{}:
          (a, v) = r
          (a, False{})
        case True{}:
          (a, +v) = r
          blit.go(t, U32.is_lt(k, len) && pts.has(set, v), pk(a, len, (k + 1 : U32)), len, (k + 1 : U32))

# Whether the literal l starts at byte j, when it fits before the anchor place.
def banc.at(fits: Bool, l: List<&2, List<&2, U32>>, a: Array<U32>, +len: U32, +j: U32) -> Array<U32> & Bool:
  match fits:
    case True{}:
      blit.go(l, True{}, pk(a, len, j), len, j)
    case False{}:
      (a, False{})

def blits.step(ok: Bool, x: Anc, a: Array<U32>, +len: U32, +k: U32) -> Array<U32> & Bool:
  match ok:
    case True{}:
      (a, True{})
    case False{}:
      Anc{+o, set, l, tail} = x
      banc.at(U32.is_le(o, k), l, a, len, (k - o : U32))

# Whether a literal of xs has its anchor at byte k; r holds whether one already did.
def blits.go(xs: List<&2, Anc>, r: Array<U32> & Bool, +len: U32, +k: U32) -> Array<U32> & Bool:
  match xs:
    case Nil{}:
      r
    case Con{l, t}:
      (a, ok) = r
      blits.go(t, blits.step(ok, l, a, len, k), len, k)

def blits.u(r: Array<U32> & Bool) -> Array<U32> & U32:
  (a, ok) = r
  (a, Bool.pick(U32, ok, 1, 0))

# The top bit of each byte of w that equals a byte of xs is set in the result. A false mark can
# follow a true one in the same word, never stand alone.
def swar.has(xs: List<&2, U32>, +w: U32, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{+b, t}:
      +x = U32.xor(w, (b * 16843009 : U32))
      swar.has(t, w, (acc .|. (((x - 16843009) .&. U32.not(x)) .&. 2155905152) : U32))

def wprobe.of(+first: List<&2, U32>, r: Array<U32> & U32) -> Array<U32> & Bool:
  (a, +w) = r
  (a, U32.is_ne(swar.has(first, w, 0), 0))

# Whether word wi has a byte in first; past nw counts as one, so a skip stops there.
def wprobe.if(ok: Bool, a: Array<U32>, +wi: U32, +first: List<&2, U32>) -> Array<U32> & Bool:
  match ok:
    case True{}:
      wprobe.of(first, Array.get(U32, a, wi))
    case False{}:
      (a, True{})

def wprobe(a: Array<U32>, +wi: U32, +nw: U32, +first: List<&2, U32>) -> Array<U32> & Bool:
  wprobe.if(U32.is_lt(wi, nw), a, wi, first)

# The first word at or after wi with a byte in first, or nw; r holds the probe of wi.
def wskip(fuel: Nat, r: Array<U32> & Bool, +wi: U32, +nw: U32, +first: List<&2, U32>) -> Array<U32> & U32:
  match fuel:
    case 0n:
      (a, h) = r
      (a, wi)
    case 1n+f:
      (a, hit) = r
      match hit:
        case True{}:
          (a, wi)
        case False{}:
          wskip(f, wprobe(a, (wi + 1 : U32), nw, first), (wi + 1 : U32), nw, first)

# The first byte offset that is the anchor place of a literal of ls, a word of four bytes at a
# time; first: the anchors' bytes. ph: 0 skip the words from wi with no byte in first; 3 take the
# word found, in r; 4 mark the bytes of word wi, in r, that are in first; 1 test the literals
# around byte j of word wi when m marks it; 2 take that test, in r; 5 found at byte j of word wi;
# 6 none. nw: the number of words. fuel: each word with a marked byte takes at most twelve rounds.
def bfind(fuel: Nat, +ph: U32, r: Array<U32> & U32, +len: U32, +wi: U32, +j: U32, +m: U32, +first: List<&2, U32>, +ls: List<&2, Anc>, +nw: U32) -> Array<U32> & Maybe<&2, U32>:
  match fuel:
    case 0n:
      (a, x) = r
      (a, None{})
    case 1n+f:
      match ph:
        case 0:
          (a, x) = r
          r2 = wskip(Nat.add(U32.to_nat((nw - wi : U32)), 1n), wprobe(a, wi, nw, first), wi, nw, first)
          bfind(f, 3, r2, len, wi, j, m, first, ls, nw)
        case 3:
          (a, +w2) = r
          r2 = Array.get(U32, a, w2)
          bfind(f, Bool.pick(U32, U32.is_le(nw, w2), 6, 4), r2, len, w2, 0, m, first, ls, nw)
        case 4:
          (a, +w) = r
          bfind(f, 1, (a, 0), len, wi, 0, swar.has(first, w, 0), first, ls, nw)
        case 1:
          (a, x) = r
          +k = ((wi * 4) + j : U32)
          +cand = U32.is_ne((U32.shrn(m, U32.to_nat(((j * 8) + 7 : U32))) .&. 1 : U32), 0)
          r2 = blits.u(blits.go(Bool.pick(List<&2, Anc>, cand, ls, Nil{}), (a, False{}), len, k))
          bfind(f, 2, r2, len, wi, j, m, first, ls, nw)
        case 2:
          (a, +ok) = r
          +found = U32.is_eq(ok, 1)
          +stay = found || U32.is_ne(j, 3)
          +ph2 = Bool.pick(U32, found, 5, Bool.pick(U32, stay, 1, 0))
          +wn = Bool.pick(U32, stay, wi, (wi + 1 : U32))
          +j2 = Bool.pick(U32, found, j, Bool.pick(U32, stay, (j + 1 : U32), 0))
          bfind(f, ph2, (a, 0), len, wn, j2, m, first, ls, nw)
        case 5:
          (a, x) = r
          (a, Some{((wi * 4) + j : U32)})
        case _:
          (a, x) = r
          (a, None{})

def bfind.start(a: Array<U32>, +len: U32, +xs: List<&2, Anc>) -> Array<U32> & Maybe<&2, U32>:
  +nw = ((len + 3) >> 2n : U32)
  bfind(Nat.add(Nat.mul(12n, U32.to_nat(nw)), 8n), 0, (a, 0), len, 0, 0, 0, ancs.sets(xs, Nil{}), xs, nw)

# The last char boundary at or before k, from the bytes k, k-1, k-2, k-3: a byte that is no
# continuation byte starts a char, and no char spans more than four bytes.
def bk.pick(+k: U32, +b0: U32, +b1: U32, +b2: U32, +b3: U32) -> U32:
  Bool.pick(U32, Bool.not(cont(b0)), k, Bool.pick(U32, U32.is_eq(k, 0), 0, Bool.pick(U32, Bool.not(cont(b1)), (k - 1 : U32), Bool.pick(U32, U32.is_eq(k, 1), 0, Bool.pick(U32, Bool.not(cont(b2)), (k - 2 : U32), Bool.pick(U32, U32.is_eq(k, 2), 0, Bool.pick(U32, Bool.not(cont(b3)), (k - 3 : U32), k)))))))

def bk.a3(+len: U32, +k: U32, +b0: U32, +b1: U32, +b2: U32, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, U32>:
  (a, +b3) = r
  (Bytes.Bytes{len, a}, Some{bk.pick(k, b0, b1, b2, b3)})

def bk.a2(+len: U32, +k: U32, +b0: U32, +b1: U32, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, U32>:
  (a, +b2) = r
  bk.a3(len, k, b0, b1, b2, pk(a, len, (k - 3 : U32)))

def bk.a1(+len: U32, +k: U32, +b0: U32, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, U32>:
  (a, +b1) = r
  bk.a2(len, k, b0, b1, pk(a, len, (k - 2 : U32)))

def bk.a0(+len: U32, +k: U32, r: Array<U32> & U32) -> Bytes.Bytes & Maybe<&2, U32>:
  (a, +b0) = r
  bk.a1(len, k, b0, pk(a, len, (k - 1 : U32)))

def need.fromb.k(m: Maybe<&2, U32>, a: Array<U32>, +len: U32) -> Bytes.Bytes & Maybe<&2, U32>:
  match m:
    case None{}:
      (Bytes.Bytes{len, a}, None{})
    case Some{+k}:
      bk.a0(len, k, pk(a, len, k))

def need.fromb(r: Array<U32> & Maybe<&2, U32>, far: Maybe<&2, U32>, +len: U32) -> Bytes.Bytes & Maybe<&2, U32>:
  (a, h) = r
  need.fromb.k(need.from(h, far), a, len)

# The first byte a match may start at, a char boundary, or None when b has no match: the first
# anchor place where a literal holds, less big and far.
def need.atb(m: Maybe<&2, Need>, b: Bytes.Bytes) -> Bytes.Bytes & Maybe<&2, U32>:
  match m:
    case None{}:
      (b, Some{0})
    case Some{Need{ls, far}}:
      Bytes.Bytes{+len, a} = b
      +xs = lits.ancs(ls, True{})
      need.fromb(bfind.start(a, len, xs), mx.add(Some{ancs.big(xs, 0)}, far), len)


def rev.best(hit: Bool, +i: U32, prev: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match hit:
    case True{}:
      Some{i}
    case False{}:
      prev


type Rv is Type:
  Rv{a: Array<U32>, best: Maybe<&2, U32>, ascii: Bool}

type RevBits is Type:
  RevBits{running: Bool, a: Array<U32>, mask: U32, best: Maybe<&2, U32>, ascii: Bool}

def rev.bits.after(step: Bs, a: Array<U32>, best: Maybe<&2, U32>, +i: U32) -> RevBits:
  Bs{+next, fin, end} = step
  RevBits{U32.is_ne(next, 0), a, next, rev.best(fin, i, best), True{}}

def rev.bits.char(valid: Bool, a: Array<U32>, +mask: U32, best: Maybe<&2, U32>, +c: U32, +i: U32, +sets: List<&2, Bit>) -> RevBits:
  match valid:
    case False{}:
      RevBits{False{}, a, mask, best, False{}}
    case True{}:
      rev.bits.after(bits.step(sets, mask, c, Bs{0, False{}, False{}}), a, best, i)

def rev.bits.read(r: Array<U32> & U32, +mask: U32, best: Maybe<&2, U32>, +i: U32, +sets: List<&2, Bit>) -> RevBits:
  (a, +c) = r
  rev.bits.char(U32.is_lt(c, 128), a, mask, best, c, i, sets)

def rev.bits.walk(fuel: Nat, r: RevBits, +i: U32, +sets: List<&2, Bit>) -> RevBits:
  match fuel:
    case 0n:
      r
    case 1n+f:
      RevBits{running, a, +mask, best, ascii} = r
      match running:
        case False{}:
          RevBits{False{}, a, mask, best, ascii}
        case True{}:
          rev.bits.walk(f, rev.bits.read(Bytes.peek(a, (i - 1 : U32)), mask, best, (i - 1 : U32), sets), (i - 1 : U32), sets)

def rev.bits.result(done: Bool, r: RevBits) -> Rv:
  RevBits{running, a, mask, best, ascii} = r
  Rv{a, best, ascii && (done || U32.is_eq(mask, 0))}

def rev.bits.run(a: Array<U32>, +end: U32, bits: Bits) -> Rv:
  Bits{+sets, +at0, hit0, hit01, atn, hit1} = bits
  +limit = Bool.pick(U32, U32.is_lt(end, 4096), end, 4096)
  rev.bits.result(U32.is_le(end, 4096), rev.bits.walk(U32.to_nat(limit), RevBits{True{}, a, at0, None{}, True{}}, end, sets))


type RevPhase is Type:
  Seek{hit: Maybe<&2, U32>, b: Bytes.Bytes, best: Maybe<&2, U32>}
  Check{run: Rv, len: U32, at: U32, best: Maybe<&2, U32>}

type RevFound is Type:
  RevFound{b: Bytes.Bytes, best: Maybe<&2, U32>, safe: Bool}

def rev.min(m: Maybe<&2, U32>, prev: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      prev
    case Some{+i}:
      match prev:
        case None{}:
          Some{i}
        case Some{+j}:
          Some{Bool.pick(U32, U32.is_lt(i, j), i, j)}

def rev.seek(r: Bytes.Bytes & Maybe<&2, U32>, best: Maybe<&2, U32>) -> RevPhase:
  (b, hit) = r
  Seek{hit, b, best}

def rev.abort(r: RevPhase) -> RevFound:
  match r:
    case Seek{hit, b, best}:
      RevFound{b, best, False{}}
    case Check{Rv{a, found, ascii}, len, at, best}:
      RevFound{Bytes.Bytes{len, a}, best, False{}}

def rev.candidates(fuel: Nat, r: RevPhase, +needle: String, +bits: Bits) -> RevFound:
  match fuel:
    case 0n:
      rev.abort(r)
    case 1n+f:
      match r:
        case Seek{hit, b, best}:
          match hit:
            case None{}:
              RevFound{b, best, True{}}
            case Some{+i}:
              Bytes.Bytes{+len, a} = b
              rev.candidates(f, Check{rev.bits.run(a, (i + 1 : U32), bits), len, i, best}, needle, bits)
        case Check{Rv{a, found, ascii}, +len, +at, best}:
          match ascii:
            case False{}:
              RevFound{Bytes.Bytes{len, a}, best, False{}}
            case True{}:
              rev.candidates(f, rev.seek(Bytes.find.from(Bytes.Bytes{len, a}, needle, (at + 1 : U32)), rev.min(found, best)), needle, bits)

def exec.bytes.at(b: Bytes.Bytes, +k: U32, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  Bytes.Bytes{+len, buf} = b
  exec.bytes.fin(len, exec.bytes.go(plain, len, k, buf, prog, fuel, init, start, asc, any, slots))

def rev.confirm.best(best: Maybe<&2, U32>, b: Bytes.Bytes, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match best:
    case None{}:
      (b, None{})
    case Some{k}:
      exec.bytes.at(b, k, plain, prog, fuel, init, start, asc, any, slots)


def rev.confirm(r: RevFound, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  RevFound{b, best, safe} = r
  match safe:
    case False{}:
      exec.bytes.run(b, plain, prog, fuel, init, start, asc, lead, any, slots)
    case True{}:
      rev.confirm.best(best, b, plain, prog, fuel, init, start, asc, any, slots)

def exec.bytes.candidate(r: Bytes.Bytes & Maybe<&2, U32>, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  (b, hit) = r
  match hit:
    case None{}:
      (b, None{})
    case Some{i}:
      exec.bytes.run(b, plain, prog, fuel, init, start, asc, lead, any, slots)

def exec.bytes.reverse(r: Bytes.Bytes & Maybe<&2, U32>, bits: Bits, +needle: String, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  (b, hit) = r
  rev.confirm(rev.candidates(16n, Seek{hit, b, None{}}, needle, bits), plain, prog, fuel, init, start, asc, lead, any, slots)

def exec.bytes.select(rev: Maybe<&2, Bits>, r: Bytes.Bytes & Maybe<&2, U32>, +needle: String, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match rev:
    case None{}:
      exec.bytes.candidate(r, plain, prog, fuel, init, start, asc, lead, any, slots)
    case Some{x}:
      exec.bytes.reverse(r, x, needle, plain, prog, fuel, init, start, asc, lead, any, slots)


def exec.bytes.must.hit(b: Bytes.Bytes, rev: Maybe<&2, Bits>, +c: U32, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  +needle = {SCon{Chr{c}, SNil{}} : String}
  exec.bytes.select(rev, Bytes.find(b, needle), needle, plain, prog, fuel, init, start, asc, lead, any, slots)

def exec.bytes.must(m: Maybe<&2, U32>, rev: Maybe<&2, Bits>, b: Bytes.Bytes, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match m:
    case None{}:
      exec.bytes.run(b, plain, prog, fuel, init, start, asc, lead, any, slots)
    case Some{c}:
      exec.bytes.must.hit(b, rev, c, plain, prog, fuel, init, start, asc, lead, any, slots)

# From byte 0 the required byte and the reverse scan apply as before; past it the DFA starts there.
def exec.bytes.zero(zero: Bool, +k: U32, m: Maybe<&2, U32>, rev: Maybe<&2, Bits>, b: Bytes.Bytes, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match zero:
    case True{}:
      exec.bytes.must(m, rev, b, plain, prog, fuel, init, start, asc, lead, any, slots)
    case False{}:
      exec.bytes.from(b, k, plain, prog, fuel, init, start, asc, lead, any, slots)

def exec.bytes.pick(k: Maybe<&2, U32>, m: Maybe<&2, U32>, rev: Maybe<&2, Bits>, b: Bytes.Bytes, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match k:
    case None{}:
      (b, None{})
    case Some{+x}:
      exec.bytes.zero(U32.is_eq(x, 0), x, m, rev, b, plain, prog, fuel, init, start, asc, lead, any, slots)

def exec.bytes.need(r: Bytes.Bytes & Maybe<&2, U32>, m: Maybe<&2, U32>, rev: Maybe<&2, Bits>, +plain: Bool, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +lead: Maybe<&2, List<&2, Inst>>, +any: Bool, +slots: Nat) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  (b, k) = r
  exec.bytes.pick(k, m, rev, b, plain, prog, fuel, init, start, asc, lead, any, slots)

# A buffer without a required literal has no match, and no automaton runs.
def exec.bytes(re: Regex, b: Bytes.Bytes, +any: Bool) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>:
  Regex{+prog, +fuel, +slots, +start, +lead, bits, +asc, plain, must, reverse, need, needb, gate} = re
  +sl = Bool.pick(Nat, any, 0n, slots)
  exec.bytes.need(need.atb(needb, b), must, reverse, plain, prog, fuel, List.replicate(Maybe<&2, U32>, sl, None{}), start, asc, lead, any, sl)

def find.bytes.fin(r: Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, Span>>>:
  (b, m) = r
  (b, find.spans(m))

# find over UTF-8 bytes: the buffer back, and spans as byte offsets.
def find.bytes(re: Regex, b: Bytes.Bytes) -> Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, Span>>>:
  find.bytes.fin(exec.bytes(re, b, False{}))

def is_match.bytes.fin(r: Bytes.Bytes & Maybe<&2, List<&2, Maybe<&2, U32>>>) -> Bytes.Bytes & Bool:
  (b, m) = r
  (b, Maybe.is_some(&2, List<&2, Maybe<&2, U32>>, m))

def is_match.bytes.vm(re: Regex, b: Bytes.Bytes) -> Bytes.Bytes & Bool:
  is_match.bytes.fin(exec.bytes(re, b, True{}))

# The bit NFA over Bytes: the buffer, the offset i of the next char, that char, and the NFA state.
type Rt is Type:
  Rt{a: Array<U32>, i: U32, d: Dc, st: Bs}

def rt.at(r: Array<U32> & Dc, +j: U32, st: Bs) -> Rt:
  (a, +d) = r
  Rt{a, j, d, st}

def rt.skip(r: Array<U32> & U32, +len: U32, +atn: U32, +hit1: Bool) -> Rt:
  (a, +k) = r
  rt.at(dec(a, len, k), k, Bs{atn, False{}, hit1})

# idle: only the sets live at a fresh start wait on c, and c starts none of them.
def rt.next(idle: Bool, asc: Maybe<&2, Asc>, a: Array<U32>, +len: U32, +j: U32, +sets: List<&2, Bit>, +atn: U32, +hit1: Bool, +cur: U32, +c: U32) -> Rt:
  match idle:
    case True{}:
      match asc:
        case None{}:
          rt.at(dec(a, len, j), j, Bs{atn, False{}, hit1})
        case Some{+m}:
          rt.skip(skip.from(a, len, j, m), len, atn, hit1)
    case False{}:
      rt.at(dec(a, len, j), j, bits.step(sets, cur, c, Bs{atn, False{}, hit1}))

def bitsb(fuel: Nat, r: Rt, +len: U32, +sets: List<&2, Bit>, +start: Maybe<&2, List<&2, Inst>>, +asc: Maybe<&2, Asc>, +atn: U32, +hit1: Bool) -> Array<U32> & Bool:
  match fuel:
    case 0n:
      Rt{a, i, d, st} = r
      (a, False{})
    case 1n+f:
      Rt{a, +i, d, st} = r
      match d:
        case DEnd{}:
          Bs{cur, done, ok} = st
          (a, done || ok)
        case Dc{+c, +w}:
          match st:
            case Bs{cur, True{}, ok}:
              (a, True{})
            case Bs{+cur, False{}, ok}:
              bitsb(f, rt.next(bits.idle(start, cur, atn, c), asc, a, len, (i + w : U32), sets, atn, hit1, cur, c), len, sets, start, asc, atn, hit1)

def bits.bytes.fin(+len: U32, r: Array<U32> & Bool) -> Bytes.Bytes & Maybe<&2, Bool>:
  (a, x) = r
  (Bytes.Bytes{len, a}, Some{x})

# From byte k, a char boundary, as bits.is_match from a position.
def bits.bytes(b: Bits, start: Maybe<&2, List<&2, Inst>>, asc: Maybe<&2, Asc>, +len: U32, buf: Array<U32>, +k: U32) -> Bytes.Bytes & Maybe<&2, Bool>:
  Bits{sets, +at0, +hit0, +hit01, +atn, +hit1} = b
  +zero = U32.is_eq(k, 0)
  bits.bytes.fin(len, bitsb(Nat.add(U32.to_nat((len - k : U32)), 2n), rt.at(dec(buf, len, k), k, Bs{Bool.pick(U32, zero, at0, atn), Bool.pick(Bool, zero, hit0, False{}), Bool.pick(Bool, zero, hit01, hit1)}), len, sets, start, asc, atn, hit1))

def bits.bytes.k(m: Maybe<&2, U32>, x: Bits, start: Maybe<&2, List<&2, Inst>>, asc: Maybe<&2, Asc>, b: Bytes.Bytes) -> Bytes.Bytes & Maybe<&2, Bool>:
  match m:
    case None{}:
      (b, Some{False{}})
    case Some{+k}:
      Bytes.Bytes{+len, buf} = b
      bits.bytes(x, start, asc, len, buf, k)

def bits.bytes.at(r: Bytes.Bytes & Maybe<&2, U32>, x: Bits, start: Maybe<&2, List<&2, Inst>>, asc: Maybe<&2, Asc>) -> Bytes.Bytes & Maybe<&2, Bool>:
  (b, m) = r
  bits.bytes.k(m, x, start, asc, b)

def bits.bytes.if(m: Maybe<&2, Bits>, need: Maybe<&2, Need>, start: Maybe<&2, List<&2, Inst>>, asc: Maybe<&2, Asc>, b: Bytes.Bytes) -> Bytes.Bytes & Maybe<&2, Bool>:
  match m:
    case None{}:
      (b, None{})
    case Some{x}:
      bits.bytes.at(need.atb(need, b), x, start, asc)

# The bit NFA form of is_match over Bytes, or None when the program does not allow it.
def is_match.bytes.bits(re: Regex, b: Bytes.Bytes) -> Bytes.Bytes & Maybe<&2, Bool>:
  Regex{prog, fuel, slots, start, lead, bt, asc, plain, must, reverse, need, needb, gate} = re
  bits.bytes.if(bt, needb, start, asc, b)

def is_match.bytes.pick(r: Bytes.Bytes & Maybe<&2, Bool>, re: Regex) -> Bytes.Bytes & Bool:
  (b, m) = r
  match m:
    case Some{x}:
      (b, x)
    case None{}:
      is_match.bytes.vm(re, b)

# is_match over UTF-8 bytes: the buffer back, and whether it has a match.
def is_match.bytes(+re: Regex, b: Bytes.Bytes) -> Bytes.Bytes & Bool:
  is_match.bytes.pick(is_match.bytes.bits(re, b), re)
