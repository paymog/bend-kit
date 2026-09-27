# Linear-time regular expressions: RE2 syntax, Pike VM, capture groups. Source: https://github.com/paymog/bend-kit/tree/main/regex
import Base
import 0x6c784a08486e2e02415e89c5249e9e8a/unicode.bend as U

# Positions count code points of the String, not octets.
# Leftmost-first semantics, as RE2 and Perl: the first alternative that matches wins.

# Syntax
# ------

# A set member: a code point range, or a Unicode general category ("L", "Lu", ...).
type Item is Data:
  Rng{lo: U32, hi: U32}
  Prop{neg: Bool, name: String}

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

# An escaped letter or digit with no meaning is an error, as in RE2.
def esc.other(alnum: Bool, +c: U32, t: String) -> Esc:
  match alnum:
    case True{}:
      EBad{}
    case False{}:
      EPoint{c, t}

# The text after a backslash.
def esc(s: String) -> Esc:
  match s:
    case SNil{}:
      EBad{}
    case SCon{'d', t}:
      EItems{perl.d(), t}
    case SCon{'D', t}:
      EItems{perl.D(), t}
    case SCon{'w', t}:
      EItems{perl.w(), t}
    case SCon{'W', t}:
      EItems{perl.W(), t}
    case SCon{'s', t}:
      EItems{perl.s(), t}
    case SCon{'S', t}:
      EItems{perl.S(), t}
    case SCon{'p', t}:
      prop(False{}, t)
    case SCon{'P', t}:
      prop(True{}, t)
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
      class.hi(esc(u), c, items)
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
def class.step(s: String, first: Bool, items: List<&2, Item>) -> Cs:
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
      class.esc(esc(t), items)
    case SCon{Chr{+c}, t}:
      class.lo(c, t, items)

# fuel: every step eats at least one char.
def class.run(fuel: Nat, st: Cs) -> Cs:
  match fuel:
    case 0n:
      CsFail{}
    case 1n+f:
      match st:
        case CsGo{s, first, items}:
          class.run(f, class.step(s, first, items))
        case CsDone{items, rest}:
          CsDone{items, rest}
        case CsFail{}:
          CsFail{}

def class(+s: String, first: Bool) -> Cs:
  class.run(Nat.add(String.length(s), 1n), CsGo{s, first, Nil{}})

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

def lex.class(neg: Bool, r: Cs, toks: List<&2, Tok>) -> Lx:
  match r:
    case CsDone{items, rest}:
      LGo{rest, TAtom{NSet{neg, items}} <> toks}
    case CsGo{s, first, items}:
      LFail{}
    case CsFail{}:
      LFail{}

def lex.esc(e: Esc, toks: List<&2, Tok>) -> Lx:
  match e:
    case EPoint{c, t}:
      LGo{t, TAtom{lit(c)} <> toks}
    case EItems{xs, t}:
      LGo{t, TAtom{NSet{False{}, xs}} <> toks}
    case EAssert{k, t}:
      LGo{t, TAtom{NAssert{k}} <> toks}
    case EBad{}:
      LFail{}

def lex.step(s: String, toks: List<&2, Tok>) -> Lx:
  match s:
    case SNil{}:
      LDone{toks}
    case SCon{'\\', t}:
      lex.esc(esc(t), toks)
    case SCon{'[', SCon{'^', t}}:
      lex.class(True{}, class(t, True{}), toks)
    case SCon{'[', t}:
      lex.class(False{}, class(t, True{}), toks)
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
      LGo{t, TAtom{lit(c)} <> toks}

# fuel: every step but the last eats at least one char.
def lex(fuel: Nat, st: Lx) -> Maybe<&2, List<&2, Tok>>:
  match fuel:
    case 0n:
      None{}
    case 1n+f:
      match st:
        case LGo{s, toks}:
          lex(f, lex.step(s, toks))
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
# FsAny when it reaches an assertion or a match, so that any char may start a match.
type Fs is Data:
  Fs{stack: List<&2, U32>, seen: List<&2, U32>, sets: List<&2, Inst>}
  FsAny{}

def first.inst(i: Maybe<&2, Inst>, +pc: U32, stack: List<&2, U32>, seen: List<&2, U32>, sets: List<&2, Inst>) -> Fs:
  match i:
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

def first.seen(hit: Bool, +prog: List<&2, Inst>, +pc: U32, stack: List<&2, U32>, seen: List<&2, U32>, sets: List<&2, Inst>) -> Fs:
  match hit:
    case True{}:
      Fs{stack, seen, sets}
    case False{}:
      first.inst(List.get(&2, Inst, prog, U32.to_nat(pc)), pc, stack, pc <> seen, sets)

# fuel: each pc expands once and pushes at most two pcs.
def first(fuel: Nat, +prog: List<&2, Inst>, st: Fs) -> Maybe<&2, List<&2, Inst>>:
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
          first(f, prog, first.seen(List.contains(~U32, ~U32.is_eq, seen, pc), prog, pc, t, seen, sets))

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

# prog: the instructions by pc; fuel: enough steps for one closure; slots: two per group, group 0 included;
# start: the sets one of which the first char of a match is in, or None when a match may start anywhere;
# bits: the bit-parallel form, for programs of at most 32 instructions without word boundaries.
type Regex is Data:
  Regex{prog: Trie<Inst>, fuel: Nat, slots: Nat, start: Maybe<&2, List<&2, Inst>>, bits: Maybe<&2, Bits>}

def build(+node: Node, +n: U32) -> Regex:
  +insts = {ISave{0} <> emit(node, 1, [ISave{1}, IMatch{}]) : List<&2, Inst>}
  +fuel = Nat.add(Nat.mul(3n, List.length(&2, Inst, insts)), 2n)
  Regex{trie.from(Inst, insts, 0, TTip{}), fuel, U32.to_nat((2 * n : U32)), first(fuel, insts, Fs{[0], Nil{}, Nil{}}), bits(fuel, insts)}

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

# The pattern, or None for a syntax error.
def compile(+pat: String) -> Maybe<&2, Regex>:
  compile.parse(lex(Nat.add(String.length(pat), 2n), LGo{pat, Nil{}}))

# Matcher
# -------

def item.has(i: Item, +c: U32) -> Bool:
  match i:
    case Rng{+lo, +hi}:
      U32.is_le(lo, c) && U32.is_le(c, hi)
    case Prop{neg, name}:
      Bool.xor(neg, String.starts_with(U.category(Chr{c}), name))

def items.has(xs: List<&2, Item>, +c: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{h, t}:
      item.has(h, c) || items.has(t, c)

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

def starts(xs: List<&2, Inst>, +c: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{ISet{neg, set}, t}:
      Bool.xor(neg, items.has(set, c)) || starts(t, c)
    case Con{i, t}:
      starts(t, c)

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

# pos: the position of s's head. Once a match exists and no thread is live, the rest of s cannot change it.
def run(s: String, +prog: Trie<Inst>, +fuel: Nat, +init: List<&2, Maybe<&2, U32>>, +start: Maybe<&2, List<&2, Inst>>, +any: Bool, +pos: U32, st: Vm) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  match s:
    case SNil{}:
      Vm{ths, best} = st
      run.end(scan(ths, prog, None{}, any, Sc{Nil{}, best, False{}}))
    case SCon{+c, +t}:
      match st:
        case Vm{Nil{}, Some{b}}:
          Some{b}
        case Vm{ths, best}:
          +p = (pos + 1 : U32)
          run(t, prog, fuel, init, start, any, p, run.step(Vm{ths, best}, prog, fuel, init, start, any, p, c, String.get(t, 0n)))

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

# slots: capture slots to keep; is_match keeps none, so each ISave is free.
def exec(re: Regex, +s: String, +any: Bool) -> Maybe<&2, List<&2, Maybe<&2, U32>>>:
  Regex{+prog, +fuel, +slots, +start, bits} = re
  +init = List.replicate(Maybe<&2, U32>, Bool.pick(Nat, any, 0n, slots), None{})
  run(s, prog, fuel, init, start, any, 0, run.close(Sc{Nil{}, None{}, False{}}, prog, fuel, init, start, 0, None{}, String.get(s, 0n)))

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

def bits.is_match(b: Bits, start: Maybe<&2, List<&2, Inst>>, s: String) -> Bool:
  Bits{sets, at0, hit0, hit01, atn, hit1} = b
  bits.run(s, sets, start, atn, hit1, Bs{at0, hit0, hit01})

# The bit NFA form of is_match, or None when the program is too large or has a word boundary.
def is_match.bits(re: Regex, s: String) -> Maybe<&2, Bool>:
  Regex{prog, fuel, slots, start, bits} = re
  match bits:
    case None{}:
      None{}
    case Some{b}:
      Some{bits.is_match(b, start, s)}

def is_match.pick(m: Maybe<&2, Bool>, re: Regex, +s: String) -> Bool:
  match m:
    case Some{x}:
      x
    case None{}:
      is_match.vm(re, s)

# Whether s has a match; the bit NFA runs when the program allows it, else the Pike VM.
def is_match(+re: Regex, +s: String) -> Bool:
  is_match.pick(is_match.bits(re, s), re, s)
