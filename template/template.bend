# Mustache templates: variables, sections, inverted sections, and comments, with HTML escaping on by default.
import Base

# A context value. A section repeats over a VList, hides on VBool{False{}} or an empty VList, and pushes any other value.
type Value is Data:
  VStr{s: String}
  VBool{b: Bool}
  VList{xs: List<&2, Value>}
  VMap{m: Map<&2, Value>}

# A parsed template. A path is a dotted name split at its dots; the name "." is the empty path.
type Node is Data:
  NText{s: String}
  NVar{path: List<&2, String>, raw: Bool}
  NSec{path: List<&2, String>, inv: Bool, body: List<&2, Node>}

type Tok is Data:
  TText{s: String}
  TVar{name: String}
  TRaw{name: String}
  TOpen{name: String}
  TInv{name: String}
  TClose{name: String}
  TSkip{}
  TBad{msg: String}

type Lex is Data:
  LEnd{text: String}
  LTag{text: String, tag: Tok, rest: String}
  LErr{msg: String}

type Frame is Data:
  Frame{name: String, inv: Bool, acc: List<&2, Node>}

type St is Data:
  SOk{top: Frame, stack: List<&2, Frame>}
  SErr{msg: String}

def escape.pick(amp: Bool, lt: Bool, gt: Bool, quot: Bool, apos: Bool, c: Char, rest: String) -> String:
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
                  match apos:
                    case True{}:
                      "&#39;" ++ rest
                    case False{}:
                      SCon{c, rest}

# HTML text: & < > " ' become &amp; &lt; &gt; &quot; &#39;.
def escape(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, t}:
      +c = {y : U32}
      escape.pick(U32.is_eq(c, 38), U32.is_eq(c, 60), U32.is_eq(c, 62), U32.is_eq(c, 34), U32.is_eq(c, 39), Chr{c}, escape(t))

def cut.go(+s: String, hit: Bool, +pat: String, acc: String) -> String & Maybe<&2, String>:
  match s:
    case SNil{}:
      (String.reverse(acc), None{})
    case SCon{c, t}:
      match hit:
        case True{}:
          (String.reverse(acc), Some{String.drop(SCon{c, t}, String.length(pat))})
        case False{}:
          cut.go(t, String.starts_with(t, pat), pat, SCon{c, acc})

# s before the first pat, and Some of s after it; s and None when pat is absent.
def cut(+s: String, +pat: String) -> String & Maybe<&2, String>:
  cut.go(s, String.starts_with(s, pat), pat, SNil{})

def tag.sigil(+c: U32, +t: String) -> Tok:
  +n = String.trim(t)
  Bool.pick(Tok, U32.is_eq(c, 35), TOpen{n},
    Bool.pick(Tok, U32.is_eq(c, 94), TInv{n},
      Bool.pick(Tok, U32.is_eq(c, 47), TClose{n},
        Bool.pick(Tok, U32.is_eq(c, 33), TSkip{},
          Bool.pick(Tok, U32.is_eq(c, 38), TRaw{n},
            Bool.pick(Tok, U32.is_eq(c, 62), TBad{"partials are not supported"},
              Bool.pick(Tok, U32.is_eq(c, 61), TBad{"set delimiters are not supported"},
                TVar{SCon{Chr{c}, t}})))))))

def tag.plain(name: String) -> Tok:
  match name:
    case SNil{}:
      TVar{SNil{}}
    case SCon{Chr{y}, t}:
      tag.sigil(y, t)

def tag.of(triple: Bool, name: String) -> Tok:
  match triple:
    case True{}:
      TRaw{name}
    case False{}:
      tag.plain(name)

def lex.close(text: String, triple: Bool, p: String & Maybe<&2, String>) -> Lex:
  (inner, after) = p
  match after:
    case None{}:
      LErr{"unclosed tag"}
    case Some{r}:
      LTag{text, tag.of(triple, String.trim(inner)), r}

def lex.open(triple: Bool, text: String, +a: String) -> Lex:
  match triple:
    case True{}:
      lex.close(text, True{}, cut(String.drop(a, 1n), "}}}"))
    case False{}:
      lex.close(text, False{}, cut(a, "}}"))

def lex.after(p: String & Maybe<&2, String>) -> Lex:
  (text, after) = p
  match after:
    case None{}:
      LEnd{text}
    case Some{+a}:
      lex.open(String.starts_with(a, "{"), text, a)

# The text up to the next tag, the tag, and the rest.
def lex(+src: String) -> Lex:
  lex.after(cut(src, "{{"))

# Every lex step eats a char, so length + 1 steps are enough. Texts and tags alternate.
def toks.go(f: Nat, l: Lex, acc: List<&2, Tok>) -> Result<&2, &2, String, List<&2, Tok>>:
  match f:
    case 0n:
      Fail{"template too long"}
    case 1n+g:
      match l:
        case LEnd{text}:
          Done{List.reverse(&2, Tok, TText{text} <> acc)}
        case LErr{m}:
          Fail{m}
        case LTag{text, tag, rest}:
          toks.go(g, lex(rest), tag <> TText{text} <> acc)

def blank(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 32), U32.is_eq(c, 9))

def blank13(+c: U32) -> Bool:
  Bool.or(blank(c), U32.is_eq(c, 13))

# Is s blank up to its first LF? At the end of s, last decides.
def head_ok(s: String, last: Bool) -> Bool:
  match s:
    case SNil{}:
      last
    case SCon{Chr{y}, t}:
      +c = {y : U32}
      Bool.or(U32.is_eq(c, 10), Bool.and(blank13(c), head_ok(t, last)))

def drop_blank(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, +t}:
      +c = {y : U32}
      Bool.pick(String, blank(c), drop_blank(t), SCon{Chr{c}, t})

def drop_chr(+k: U32, s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, +t}:
      +c = {y : U32}
      Bool.pick(String, U32.is_eq(c, k), t, SCon{Chr{c}, t})

def trim_head(s: String) -> String:
  drop_chr(10, drop_chr(13, drop_blank(s)))

def trim_tail(s: String) -> String:
  String.reverse(drop_blank(String.reverse(s)))

def std.kind(t: Tok) -> Bool:
  match t:
    case TOpen{n}:
      True{}
    case TInv{n}:
      True{}
    case TClose{n}:
      True{}
    case TSkip{}:
      True{}
    case _:
      False{}

# orig is the text before the tag as lexed; cur is that text after its own head trim.
def std.go(toks: List<&2, Tok>, +orig: String, first: Bool, +cur: String, out: List<&2, Tok>) -> List<&2, Tok>:
  match toks:
    case Con{+tag, Con{TText{+next}, +rest}}:
      +sa = Bool.and(std.kind(tag), Bool.and(head_ok(String.reverse(orig), first), head_ok(next, List.is_empty(&2, Tok, rest))))
      std.go(rest, next, False{}, Bool.pick(String, sa, trim_head(next), next), tag <> TText{Bool.pick(String, sa, trim_tail(cur), cur)} <> out)
    case _:
      List.reverse(&2, Tok, TText{cur} <> out)

# A section, inverted, close, or comment tag alone on its line takes the line with it.
def std(toks: List<&2, Tok>) -> List<&2, Tok>:
  match toks:
    case Con{TText{+t0}, rest}:
      std.go(rest, t0, True{}, t0, Nil{})
    case _:
      Nil{}

def path.of(+n: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.eq(n, "."), Nil{}, String.split(n, '.'))

def add(top: Frame, n: Node) -> Frame:
  match top:
    case Frame{name, inv, acc}:
      Frame{name, inv, n <> acc}

def close.pop(stack: List<&2, Frame>, +name: String, inv: Bool, acc: List<&2, Node>) -> St:
  match stack:
    case Nil{}:
      SErr{"close tag without a section: " ++ name}
    case Con{parent, more}:
      SOk{add(parent, NSec{path.of(name), inv, List.reverse(&2, Node, acc)}), more}

def close(same: Bool, +n: String, top: Frame, stack: List<&2, Frame>) -> St:
  match same:
    case False{}:
      SErr{"close tag does not match its section: " ++ n}
    case True{}:
      match top:
        case Frame{name, inv, acc}:
          close.pop(stack, name, inv, acc)

def close.of(+n: String, top: Frame, stack: List<&2, Frame>) -> St:
  match top:
    case Frame{+name, inv, acc}:
      close(String.eq(n, name), n, Frame{name, inv, acc}, stack)

def step(st: St, t: Tok) -> St:
  match st:
    case SErr{m}:
      SErr{m}
    case SOk{top, stack}:
      match t:
        case TText{s}:
          SOk{add(top, NText{s}), stack}
        case TVar{n}:
          SOk{add(top, NVar{path.of(n), False{}}), stack}
        case TRaw{n}:
          SOk{add(top, NVar{path.of(n), True{}}), stack}
        case TOpen{n}:
          SOk{Frame{n, False{}, Nil{}}, top <> stack}
        case TInv{n}:
          SOk{Frame{n, True{}, Nil{}}, top <> stack}
        case TClose{n}:
          close.of(n, top, stack)
        case TSkip{}:
          SOk{top, stack}
        case TBad{m}:
          SErr{m}

def tree.go(toks: List<&2, Tok>, st: St) -> St:
  match toks:
    case Nil{}:
      st
    case Con{t, rest}:
      tree.go(rest, step(st, t))

def tree.fin(st: St) -> Result<&2, &2, String, List<&2, Node>>:
  match st:
    case SErr{m}:
      Fail{m}
    case SOk{Frame{name, inv, acc}, stack}:
      match stack:
        case Nil{}:
          Done{List.reverse(&2, Node, acc)}
        case Con{p, more}:
          Fail{"unclosed section: " ++ name}

def parse.tree(r: Result<&2, &2, String, List<&2, Tok>>) -> Result<&2, &2, String, List<&2, Node>>:
  match r:
    case Fail{m}:
      Fail{m}
    case Done{toks}:
      tree.fin(tree.go(std(toks), SOk{Frame{"", False{}, Nil{}}, Nil{}}))

# The template as nodes, or Fail with why it is malformed. Partials and set delimiters fail.
def parse(+src: String) -> Result<&2, &2, String, List<&2, Node>>:
  parse.tree(toks.go(1n+String.length(src), lex(src), Nil{}))

def find.got(r: Map<&2, Value> & Value) -> Maybe<&2, Value>:
  (m, v) = r
  Some{v}

def find.if(r: Map<&2, Value> & Bool, +k: String) -> Maybe<&2, Value>:
  (m, b) = r
  match b:
    case False{}:
      None{}
    case True{}:
      find.got(Map.get(Value, VBool{False{}}, m, k))

def probe(v: Value, +k: String) -> Maybe<&2, Value>:
  match v:
    case VMap{m}:
      find.if(Map.has(&2, Value, m, k), k)
    case _:
      None{}

def first(a: Maybe<&2, Value>, b: Maybe<&2, Value>) -> Maybe<&2, Value>:
  match a:
    case Some{v}:
      Some{v}
    case None{}:
      b

# The first value on the stack, innermost first, that is a map with key k.
def resolve(stack: List<&2, Value>, +k: String) -> Maybe<&2, Value>:
  match stack:
    case Nil{}:
      None{}
    case Con{v, rest}:
      first(probe(v, k), resolve(rest, k))

def sub(mv: Maybe<&2, Value>, +k: String) -> Maybe<&2, Value>:
  match mv:
    case None{}:
      None{}
    case Some{v}:
      probe(v, k)

def dig(path: List<&2, String>, mv: Maybe<&2, Value>) -> Maybe<&2, Value>:
  match path:
    case Nil{}:
      mv
    case Con{k, ks}:
      dig(ks, sub(mv, k))

def top(stack: List<&2, Value>) -> Maybe<&2, Value>:
  match stack:
    case Nil{}:
      None{}
    case Con{v, rest}:
      Some{v}

# Only the first part of a dotted name searches the stack.
def lookup(path: List<&2, String>, +stack: List<&2, Value>) -> Maybe<&2, Value>:
  match path:
    case Nil{}:
      top(stack)
    case Con{k, ks}:
      dig(ks, resolve(stack, k))

def show(raw: Bool, v: Maybe<&2, Value>) -> String:
  match v:
    case Some{VStr{+s}}:
      Bool.pick(String, raw, s, escape(s))
    case Some{VBool{b}}:
      Bool.pick(String, b, "true", "false")
    case _:
      ""

def truthy(v: Maybe<&2, Value>) -> Bool:
  match v:
    case None{}:
      False{}
    case Some{VBool{b}}:
      b
    case Some{VList{Nil{}}}:
      False{}
    case _:
      True{}

def items.of(v: Maybe<&2, Value>) -> List<&2, Value>:
  match v:
    case None{}:
      Nil{}
    case Some{VList{xs}}:
      xs
    case Some{VBool{b}}:
      Bool.pick(List<&2, Value>, b, [VBool{True{}}], Nil{})
    case Some{VStr{s}}:
      [VStr{s}]
    case Some{VMap{m}}:
      [VMap{m}]

# The values a section's body renders once each against.
def sec.items(inv: Bool, +v: Maybe<&2, Value>) -> List<&2, Value>:
  match inv:
    case False{}:
      items.of(v)
    case True{}:
      Bool.pick(List<&2, Value>, truthy(v), Nil{}, [VMap{Map.new(&2, Value)}])

# iter renders nodes once per item, each pushed on the stack; otherwise it renders nodes once.
def go(nodes: List<&2, Node>, items: List<&2, Value>, iter: Bool, +stack: List<&2, Value>) -> String:
  match nodes items iter:
    case +ns Con{it, +more} True{}:
      go(ns, more, False{}, it <> stack) ++ go(ns, more, True{}, stack)
    case ns Nil{} True{}:
      ""
    case Nil{} xs False{}:
      ""
    case Con{NText{s}, rest} +xs False{}:
      s ++ go(rest, xs, False{}, stack)
    case Con{NVar{p, raw}, rest} +xs False{}:
      show(raw, lookup(p, stack)) ++ go(rest, xs, False{}, stack)
    case Con{NSec{p, inv, body}, rest} +xs False{}:
      go(body, sec.items(inv, lookup(p, stack)), True{}, stack) ++ go(rest, xs, False{}, stack)

# The nodes rendered against ctx.
def render(nodes: List<&2, Node>, ctx: Map<&2, Value>) -> String:
  go(nodes, Nil{}, False{}, [VMap{ctx}])

def render_text.of(r: Result<&2, &2, String, List<&2, Node>>, ctx: Map<&2, Value>) -> Result<&2, &2, String, String>:
  match r:
    case Fail{m}:
      Fail{m}
    case Done{nodes}:
      Done{render(nodes, ctx)}

# parse, then render.
def render_text(+src: String, ctx: Map<&2, Value>) -> Result<&2, &2, String, String>:
  render_text.of(parse(src), ctx)
