# Mustache templates: variables, sections, inverted sections, comments, partials, and set delimiters, with HTML escaping on by default.
import Base
import bend-kit-encoding@0.5.0.1/encoding.bend as Encoding
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

# Bool.pick evaluates both branches; when evaluates only the chosen one.
def when(-A: Type, c: Bool, t: Unit -> A, e: Unit -> A) -> A:
  match c:
    case True{}:
      t(Unit{})
    case False{}:
      e(Unit{})

# A context value. A section repeats over a VList, hides on VBool{False{}} or an empty VList, and pushes any other value.
type Value is Data:
  VStr{s: String}
  VBool{b: Bool}
  VList{xs: List<&2, Value>}
  VMap{m: Map<&2, Value>}

# A parsed template. A path is a dotted name split at its dots; the name "." is the empty path.
# NPart's ind is the whitespace before a standalone partial tag; it indents each line of the partial.
type Node is Data:
  NLine{}
  NText{s: String}
  NVar{path: List<&2, String>, raw: Bool}
  NSec{path: List<&2, String>, inv: Bool, body: List<&2, Node>}
  NPart{name: String, ind: String}

type Tok is Data:
  TLine{}
  TText{s: String}
  TVar{name: String}
  TRaw{name: String}
  TOpen{name: String}
  TInv{name: String}
  TClose{name: String}
  TSkip{}
  TDelim{open: String, close: String}
  TPart{name: String, ind: String}
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

def delim.pair(ws: List<&2, String>) -> Tok:
  match ws:
    case Con{o, Con{c, Nil{}}}:
      TDelim{o, c}
    case _:
      TBad{"bad set delimiters"}

def delim.of(ok: Bool, t: String) -> Tok:
  match ok:
    case False{}:
      TBad{"bad set delimiters"}
    case True{}:
      delim.pair(List.filter(~String, ~(w => Bool.not(String.is_empty(w))), String.split(String.reverse(String.drop(String.reverse(t), 1n)), ' ')))

# The body of {{=<% %>=}} after its first '=': two delimiters and a closing '='.
def delim(+t: String) -> Tok:
  delim.of(String.ends_with(t, "="), t)

def tag.sigil.set(set: Bool, +c: U32, +t: String) -> Tok:
  match set:
    case True{}:
      delim(t)
    case False{}:
      +n = String.trim(t)
      Bool.pick(Tok, U32.is_eq(c, 35), TOpen{n},
        Bool.pick(Tok, U32.is_eq(c, 94), TInv{n},
          Bool.pick(Tok, U32.is_eq(c, 47), TClose{n},
            Bool.pick(Tok, U32.is_eq(c, 33), TSkip{},
              Bool.pick(Tok, U32.is_eq(c, 38), TRaw{n},
                Bool.pick(Tok, U32.is_eq(c, 62), TPart{n, ""},
                  TVar{SCon{Chr{c}, t}}))))))

def tag.sigil(+c: U32, +t: String) -> Tok:
  tag.sigil.set(U32.is_eq(c, 61), c, t)

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

def lex.open(triple: Bool, text: String, +a: String, +c: String) -> Lex:
  match triple:
    case True{}:
      lex.close(text, True{}, cut(String.drop(a, 1n), "}" ++ c))
    case False{}:
      lex.close(text, False{}, cut(a, c))

def lex.after(p: String & Maybe<&2, String>, +c: String) -> Lex:
  (text, after) = p
  match after:
    case None{}:
      LEnd{text}
    case Some{+a}:
      lex.open(String.starts_with(a, "{"), text, a, c)

# The text up to the next tag between delimiters o and c, the tag, and the rest.
def lex(+o: String, +c: String, +src: String) -> Lex:
  lex.after(cut(src, o), c)

def lex.with(d: Tok, +src: String) -> Lex:
  match d:
    case TDelim{o, c}:
      lex(o, c, src)
    case _:
      lex("{{", "}}", src)

def delims(t: Tok, d: Tok) -> Tok:
  match t:
    case TDelim{o, c}:
      TDelim{o, c}
    case _:
      d

# Every lex step eats a char, so length + 1 steps are enough. Texts and tags alternate. d is the TDelim in force.
def toks.go(f: Nat, l: Lex, acc: List<&2, Tok>, d: Tok) -> Result<&2, &2, String, List<&2, Tok>>:
  match f:
    case 0n:
      Fail{"template too long"}
    case 1n+g:
      match l:
        case LEnd{text}:
          Done{List.reverse(&2, Tok, TText{text} <> acc)}
        case LErr{m}:
          Fail{m}
        case LTag{text, +tag, rest}:
          +e = delims(tag, d)
          toks.go(g, lex.with(e, rest), tag <> TText{text} <> acc, e)

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
      when(String, blank(c), u => drop_blank(t), u => SCon{Chr{c}, t})

def drop_chr(+k: U32, s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{y}, +t}:
      +c = {y : U32}
      when(String, U32.is_eq(c, k), u => t, u => SCon{Chr{c}, t})

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
    case TDelim{o, c}:
      True{}
    case TPart{n, i}:
      True{}
    case _:
      False{}

def last_line.go(s: String, +acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{y}, +t}:
      +c = {y : U32}
      when(String, U32.is_eq(c, 10), u => acc, u => last_line.go(t, SCon{Chr{c}, acc}))

# The text after the last LF of s.
def last_line(s: String) -> String:
  last_line.go(String.reverse(s), SNil{})

# A partial tag takes ind as its indentation.
def std.ind(t: Tok, +ind: String) -> Tok:
  match t:
    case TLine{}:
      TLine{}
    case TPart{n, i}:
      TPart{n, ind}
    case TText{s}:
      TText{s}
    case TVar{n}:
      TVar{n}
    case TRaw{n}:
      TRaw{n}
    case TOpen{n}:
      TOpen{n}
    case TInv{n}:
      TInv{n}
    case TClose{n}:
      TClose{n}
    case TSkip{}:
      TSkip{}
    case TDelim{o, c}:
      TDelim{o, c}
    case TBad{m}:
      TBad{m}

def line.text(+s: String, line: Bool, +out: List<&2, Tok>) -> List<&2, Tok>:
  when(List<&2, Tok>, String.is_empty(s), u => out,
    u => TText{s} <> when(List<&2, Tok>, line, u => TLine{} <> out, u => out))

def line.mark(s: String, +line: Bool, +tag: Bool, +acc: String, +out: List<&2, Tok>) -> List<&2, Tok>:
  match s:
    case SNil{}:
      when(List<&2, Tok>, String.is_empty(acc) && line && tag,
        u => TLine{} <> out, u => line.text(String.reverse(acc), line, out))
    case SCon{Chr{10}, rest}:
      line.mark(rest, True{}, tag, "", line.text(String.reverse(acc) ++ "\n", line && Bool.not(String.is_empty(acc)), out))
    case SCon{c, rest}:
      line.mark(rest, line, tag, SCon{c, acc}, out)

# orig is the text before the tag as lexed; cur is that text after its own head trim.
def std.go(toks: List<&2, Tok>, +orig: String, first: Bool, +cur: String, line: Bool, out: List<&2, Tok>) -> List<&2, Tok>:
  match toks:
    case Con{+tag, Con{TText{+next}, +rest}}:
      +sa = Bool.and(std.kind(tag), Bool.and(head_ok(String.reverse(orig), first), head_ok(next, List.is_empty(&2, Tok, rest))))
      std.go(rest, next, False{}, when(String, sa, u => trim_head(next), u => next), sa, std.ind(tag, when(String, sa, u => last_line(cur), u => "")) <> line.mark(when(String, sa, u => trim_tail(cur), u => cur), line, Bool.not(sa), "", out))
    case _:
      List.reverse(&2, Tok, line.mark(cur, line, False{}, "", out))

# A section, inverted, close, comment, set-delimiter, or partial tag alone on its line takes the line with it.
def std(toks: List<&2, Tok>) -> List<&2, Tok>:
  match toks:
    case Con{TText{+t0}, rest}:
      std.go(rest, t0, True{}, t0, True{}, Nil{})
    case _:
      Nil{}

def path.of(+n: String) -> List<&2, String>:
  when(List<&2, String>, String.eq(n, "."), u => Nil{}, u => String.split(n, '.'))

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
        case TLine{}:
          SOk{add(top, NLine{}), stack}
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
        case TDelim{o, c}:
          SOk{top, stack}
        case TPart{n, i}:
          SOk{add(top, NPart{n, i}), stack}
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

# The template as nodes, or Fail with why it is malformed.
def parse(+src: String) -> Result<&2, &2, String, List<&2, Node>>:
  parse.tree(toks.go(1n+String.length(src), lex("{{", "}}", src), Nil{}, TDelim{"{{", "}}"}))

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

def first(a: Maybe<&2, Value>, b: Unit -> Maybe<&2, Value>) -> Maybe<&2, Value>:
  match a:
    case Some{v}:
      Some{v}
    case None{}:
      b(Unit{})

# The first value on the stack, innermost first, that is a map with key k.
def resolve(stack: List<&2, Value>, +k: String) -> Maybe<&2, Value>:
  match stack:
    case Nil{}:
      None{}
    case Con{v, rest}:
      first(probe(v, k), u => resolve(rest, k))

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
      when(String, raw, u => s, u => escape(s))
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
      when(List<&2, Value>, truthy(v), u => Nil{}, u => [VMap{Map.new(&2, Value)}])

def part.got(r: Map<&2, List<&2, Node>> & List<&2, Node>) -> List<&2, Node>:
  (m, v) = r
  v

# A missing partial renders as nothing.
def part(+ps: Map<&2, List<&2, Node>>, +n: String) -> List<&2, Node>:
  part.got(Map.get(List<&2, Node>, Nil{}, ps, n))

# f bounds partial nesting. iter renders nodes once per item, each pushed on the stack; otherwise it renders nodes once.
def go(f: Nat, nodes: List<&2, Node>, items: List<&2, Value>, iter: Bool, +ps: Map<&2, List<&2, Node>>, +stack: List<&2, Value>, +ind: String, tail: String) -> String:
  match f nodes items iter:
    case +k +ns Con{it, +more} True{}:
      go(k, ns, more, False{}, ps, it <> stack, ind, go(k, ns, more, True{}, ps, stack, ind, tail))
    case k ns Nil{} True{}:
      tail
    case k Nil{} xs False{}:
      tail
    case +k Con{NLine{}, rest} +xs False{}:
      ind ++ go(k, rest, xs, False{}, ps, stack, ind, tail)
    case +k Con{NText{s}, rest} +xs False{}:
      s ++ go(k, rest, xs, False{}, ps, stack, ind, tail)
    case +k Con{NVar{p, raw}, rest} +xs False{}:
      show(raw, lookup(p, stack)) ++ go(k, rest, xs, False{}, ps, stack, ind, tail)
    case +k Con{NSec{p, inv, body}, rest} +xs False{}:
      go(k, body, sec.items(inv, lookup(p, stack)), True{}, ps, stack, ind, go(k, rest, xs, False{}, ps, stack, ind, tail))
    case 0n Con{NPart{n, pi}, rest} +xs False{}:
      go(0n, rest, xs, False{}, ps, stack, ind, tail)
    case 1n+g Con{NPart{n, pi}, rest} +xs False{}:
      go(g, part(ps, n), Nil{}, False{}, ps, stack, ind ++ pi, go(1n+g, rest, xs, False{}, ps, stack, ind, tail))

# The nodes rendered against ctx, with {{> name}} taken from partials. Partials nest at most 64 deep; a deeper one renders as nothing.
def render_with(nodes: List<&2, Node>, ctx: Map<&2, Value>, partials: Map<&2, List<&2, Node>>) -> String:
  go(64n, nodes, Nil{}, False{}, partials, [VMap{ctx}], "", "")

# The nodes rendered against ctx. A partial renders as nothing.
def render(nodes: List<&2, Node>, ctx: Map<&2, Value>) -> String:
  render_with(nodes, ctx, Map.new(&2, List<&2, Node>))

def render_text.of(r: Result<&2, &2, String, List<&2, Node>>, ctx: Map<&2, Value>) -> Result<&2, &2, String, String>:
  match r:
    case Fail{m}:
      Fail{m}
    case Done{nodes}:
      Done{render(nodes, ctx)}

# parse, then render.
def render_text(+src: String, ctx: Map<&2, Value>) -> Result<&2, &2, String, String>:
  render_text.of(parse(src), ctx)

def packed.reserve(+s: String, o: Encoding.Out, +factor: U32) -> Encoding.Out:
  Encoding.Out{buf, +n, w} = o
  Encoding.Out{Bytes.grow(n, buf, (n + Bytes.count(s, 0) * factor : U32)), n, w}

def packed.text(+s: String, o: Encoding.Out) -> Encoding.Out:
  Encoding.utf8.encode.go(s, packed.reserve(s, o, 4))

def packed.escaped(s: String, o: Encoding.Out) -> Encoding.Out:
  match s:
    case SNil{}:
      o
    case SCon{Chr{+c}, t}:
      packed.escaped(t, Encoding.utf8.encode.go(escape.pick(U32.is_eq(c, 38), U32.is_eq(c, 60), U32.is_eq(c, 62), U32.is_eq(c, 34), U32.is_eq(c, 39), Chr{c}, ""), o))

def packed.string(raw: Bool, +s: String, o: Encoding.Out) -> Encoding.Out:
  match raw:
    case True{}:
      packed.text(s, o)
    case False{}:
      packed.escaped(s, packed.reserve(s, o, 6))

def packed.value(raw: Bool, v: Maybe<&2, Value>, o: Encoding.Out) -> Encoding.Out:
  match v:
    case Some{VStr{+s}}:
      packed.string(raw, s, o)
    case Some{VBool{b}}:
      packed.text(Bool.pick(String, b, "true", "false"), o)
    case _:
      o

def packed.go(f: Nat, nodes: List<&2, Node>, items: List<&2, Value>, iter: Bool, +ps: Map<&2, List<&2, Node>>, +stack: List<&2, Value>, +ind: String, out: Encoding.Out) -> Encoding.Out:
  match f nodes items iter:
    case +k +ns Con{it, +more} True{}:
      packed.go(k, ns, more, True{}, ps, stack, ind, packed.go(k, ns, more, False{}, ps, it <> stack, ind, out))
    case k ns Nil{} True{}:
      out
    case k Nil{} xs False{}:
      out
    case +k Con{NLine{}, rest} +xs False{}:
      packed.go(k, rest, xs, False{}, ps, stack, ind, packed.text(ind, out))
    case +k Con{NText{s}, rest} +xs False{}:
      packed.go(k, rest, xs, False{}, ps, stack, ind, packed.text(s, out))
    case +k Con{NVar{p, raw}, rest} +xs False{}:
      packed.go(k, rest, xs, False{}, ps, stack, ind, packed.value(raw, lookup(p, stack), out))
    case +k Con{NSec{p, inv, body}, rest} +xs False{}:
      packed.go(k, rest, xs, False{}, ps, stack, ind, packed.go(k, body, sec.items(inv, lookup(p, stack)), True{}, ps, stack, ind, out))
    case 0n Con{NPart{n, pi}, rest} +xs False{}:
      packed.go(0n, rest, xs, False{}, ps, stack, ind, out)
    case 1n+g Con{NPart{n, pi}, rest} +xs False{}:
      packed.go(1n+g, rest, xs, False{}, ps, stack, ind, packed.go(g, part(ps, n), Nil{}, False{}, ps, stack, ind ++ pi, out))

# Render UTF-8 directly into packed bytes, with the same partial rules as render_with.
def render_bytes_with(nodes: List<&2, Node>, ctx: Map<&2, Value>, partials: Map<&2, List<&2, Node>>) -> Bytes.Bytes:
  Encoding.done(packed.go(64n, nodes, Nil{}, False{}, partials, [VMap{ctx}], "", Encoding.Out{Bytes.alloc(0), 0, 0}))

# Render UTF-8 directly into packed bytes without partials.
def render_bytes(nodes: List<&2, Node>, ctx: Map<&2, Value>) -> Bytes.Bytes:
  render_bytes_with(nodes, ctx, Map.new(&2, List<&2, Node>))
