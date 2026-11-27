# Pure XML parsing for S3 responses.
import Base

# One closed element: its parent's name, its name, and its own text, entities decoded. Names drop any namespace prefix.
type Leaf is Data:
  Leaf{parent: String, name: String, text: String}

# Where the lexer is: text; after '<'; a start tag's name; its attributes, outside or in "..." or '...'; after '/'
# in a start tag; an end tag's name; <?...?>, after '?'; after '<!'; a comment, after one or two '-'; <![CDATA[ up
# to its '['; CDATA, after one or two ']'; an entity; <!DOCTYPE ...>.
type Lx is Data:
  LText{}
  LOpen{}
  LName{}
  LAttr{}
  LDq{}
  LSq{}
  LSelf{}
  LEnd{}
  LPi{}
  LPiQ{}
  LBang{}
  LCom{}
  LCom1{}
  LCom2{}
  LCdHead{}
  LCd{}
  LCd1{}
  LCd2{}
  LEnt{}
  LDecl{}

# stack: open names, innermost first. txt and nm: text and the name or entity so far, reversed. out: leaves, last first.
# ok turns False at a mismatched end tag or an unknown entity.
type St is Data:
  St{stack: List<&2, String>, txt: String, nm: String, out: List<&2, Leaf>, ok: Bool}

def first(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{h, t}:
      h

def local.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      String.reverse(acc)
    case SCon{Chr{58}, t}:
      local.go(t, SNil{})
    case SCon{c, t}:
      local.go(t, SCon{c, acc})

# The name after its namespace prefix, as Key for s3:Key.
def local(s: String) -> String:
  local.go(s, SNil{})

def st.txt(st: St, c: Char) -> St:
  St{a, x, n, o, k} = st
  St{a, SCon{c, x}, n, o, k}

def st.nm(st: St, c: Char) -> St:
  St{a, x, n, o, k} = st
  St{a, x, SCon{c, n}, o, k}

def st.nm0(st: St) -> St:
  St{a, x, n, o, k} = st
  St{a, x, "", o, k}

def st.open(st: St) -> St:
  St{a, x, n, o, k} = st
  St{Con{local(String.reverse(n)), a}, "", "", o, k}

def st.shut(stack: List<&2, String>, txt: String, out: List<&2, Leaf>, ok: Bool, +name: String) -> St:
  match stack:
    case Nil{}:
      St{Nil{}, "", "", out, False{}}
    case Con{+top, +rest}:
      St{rest, "", "", Con{Leaf{first(rest), top, String.reverse(txt)}, out}, Bool.and(ok, String.eq(top, name))}

def st.close(st: St) -> St:
  St{a, x, n, o, k} = st
  st.shut(a, x, o, k, local(String.reverse(n)))

def st.close.top(st: St) -> St:
  St{+a, x, n, o, k} = st
  st.shut(a, x, o, k, first(a))

def hex.digit(+c: U32) -> Maybe<&2, U32>:
  Bool.pick(Maybe<&2, U32>, Bool.and(U32.is_le(48, c), U32.is_le(c, 57)), Some{(c - 48 : U32)},
    Bool.pick(Maybe<&2, U32>, Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), Some{(c - 87 : U32)},
      Bool.pick(Maybe<&2, U32>, Bool.and(U32.is_le(65, c), U32.is_le(c, 70)), Some{(c - 55 : U32)}, None{})))

def hex.step(m: Maybe<&2, U32>, +acc: U32) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{d}:
      Some{(acc * 16 + d : U32)}

# ponytail: no overflow check; a reference past U+10FFFF wraps and decodes to junk rather than failing.
def hex(s: String, m: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      m
    case SCon{Chr{c}, t}:
      match m:
        case None{}:
          None{}
        case Some{acc}:
          hex(t, hex.step(hex.digit(c), acc))

def ent.num(+s: String) -> Maybe<&2, U32>:
  Bool.pick(Maybe<&2, U32>, String.starts_with(s, "x"), hex(String.drop(s, 1n), Some{0}), U32.read(s))

# The five XML entities and &#NN; / &#xHH;. None for any other.
def ent(+e: String) -> Maybe<&2, U32>:
  Bool.pick(Maybe<&2, U32>, String.eq(e, "lt"), Some{60},
    Bool.pick(Maybe<&2, U32>, String.eq(e, "gt"), Some{62},
      Bool.pick(Maybe<&2, U32>, String.eq(e, "amp"), Some{38},
        Bool.pick(Maybe<&2, U32>, String.eq(e, "quot"), Some{34},
          Bool.pick(Maybe<&2, U32>, String.eq(e, "apos"), Some{39},
            Bool.pick(Maybe<&2, U32>, Bool.and(String.starts_with(e, "#"), Nat.is_lt(1n, String.length(e))), ent.num(String.drop(e, 1n)), None{}))))))

def st.ent.of(m: Maybe<&2, U32>, st: St) -> St:
  match m:
    case None{}:
      St{a, x, n, o, k} = st
      St{a, x, n, o, False{}}
    case Some{c}:
      st.txt(st, Chr{c})

def st.ent(st: St) -> St:
  St{a, x, n, o, k} = st
  st.ent.of(ent(String.reverse(n)), St{a, x, "", o, k})

def lx.idle(m: Lx) -> Bool:
  match m:
    case LText{}:
      True{}
    case _:
      False{}

def st.end(m: Lx, st: St) -> St:
  St{a, x, n, o, k} = st
  St{a, x, n, o, Bool.and(k, lx.idle(m))}

# One pass over the text. Each step takes one char, so it ends.
def lex(s: String, m: Lx, st: St) -> St:
  match s:
    case SNil{}:
      st.end(m, st)
    case SCon{h, t}:
      match h m:
        case '<' LText{}:
          lex(t, LOpen{}, st.nm0(st))
        case '&' LText{}:
          lex(t, LEnt{}, st.nm0(st))
        case c LText{}:
          lex(t, LText{}, st.txt(st, c))
        case '/' LOpen{}:
          lex(t, LEnd{}, st)
        case '?' LOpen{}:
          lex(t, LPi{}, st)
        case '!' LOpen{}:
          lex(t, LBang{}, st)
        case c LOpen{}:
          lex(t, LName{}, st.nm(st, c))
        case '>' LName{}:
          lex(t, LText{}, st.open(st))
        case '/' LName{}:
          lex(t, LSelf{}, st.open(st))
        case ' ' LName{}:
          lex(t, LAttr{}, st.open(st))
        case Chr{9} LName{}:
          lex(t, LAttr{}, st.open(st))
        case Chr{10} LName{}:
          lex(t, LAttr{}, st.open(st))
        case Chr{13} LName{}:
          lex(t, LAttr{}, st.open(st))
        case c LName{}:
          lex(t, LName{}, st.nm(st, c))
        case '"' LAttr{}:
          lex(t, LDq{}, st)
        case Chr{39} LAttr{}:
          lex(t, LSq{}, st)
        case '>' LAttr{}:
          lex(t, LText{}, st)
        case '/' LAttr{}:
          lex(t, LSelf{}, st)
        case c LAttr{}:
          lex(t, LAttr{}, st)
        case '"' LDq{}:
          lex(t, LAttr{}, st)
        case c LDq{}:
          lex(t, LDq{}, st)
        case Chr{39} LSq{}:
          lex(t, LAttr{}, st)
        case c LSq{}:
          lex(t, LSq{}, st)
        case '>' LSelf{}:
          lex(t, LText{}, st.close.top(st))
        case c LSelf{}:
          lex(t, LAttr{}, st)
        case '>' LEnd{}:
          lex(t, LText{}, st.close(st))
        case ' ' LEnd{}:
          lex(t, LEnd{}, st)
        case Chr{9} LEnd{}:
          lex(t, LEnd{}, st)
        case Chr{10} LEnd{}:
          lex(t, LEnd{}, st)
        case Chr{13} LEnd{}:
          lex(t, LEnd{}, st)
        case c LEnd{}:
          lex(t, LEnd{}, st.nm(st, c))
        case '?' LPi{}:
          lex(t, LPiQ{}, st)
        case c LPi{}:
          lex(t, LPi{}, st)
        case '>' LPiQ{}:
          lex(t, LText{}, st)
        case '?' LPiQ{}:
          lex(t, LPiQ{}, st)
        case c LPiQ{}:
          lex(t, LPi{}, st)
        case '-' LBang{}:
          lex(t, LCom{}, st)
        case '[' LBang{}:
          lex(t, LCdHead{}, st)
        case c LBang{}:
          lex(t, LDecl{}, st)
        case '-' LCom{}:
          lex(t, LCom1{}, st)
        case c LCom{}:
          lex(t, LCom{}, st)
        case '-' LCom1{}:
          lex(t, LCom2{}, st)
        case c LCom1{}:
          lex(t, LCom{}, st)
        case '>' LCom2{}:
          lex(t, LText{}, st)
        case '-' LCom2{}:
          lex(t, LCom2{}, st)
        case c LCom2{}:
          lex(t, LCom{}, st)
        case '[' LCdHead{}:
          lex(t, LCd{}, st)
        case c LCdHead{}:
          lex(t, LCdHead{}, st)
        case ']' LCd{}:
          lex(t, LCd1{}, st)
        case c LCd{}:
          lex(t, LCd{}, st.txt(st, c))
        case ']' LCd1{}:
          lex(t, LCd2{}, st)
        case c LCd1{}:
          lex(t, LCd{}, st.txt(st.txt(st, ']'), c))
        case '>' LCd2{}:
          lex(t, LText{}, st)
        case ']' LCd2{}:
          lex(t, LCd2{}, st.txt(st, ']'))
        case c LCd2{}:
          lex(t, LCd{}, st.txt(st.txt(st.txt(st, ']'), ']'), c))
        case ';' LEnt{}:
          lex(t, LText{}, st.ent(st))
        case c LEnt{}:
          lex(t, LEnt{}, st.nm(st, c))
        case '>' LDecl{}:
          lex(t, LText{}, st)
        case c LDecl{}:
          lex(t, LDecl{}, st)

def xml.if(ok: Bool, out: List<&2, Leaf>) -> Maybe<&2, List<&2, Leaf>>:
  match ok:
    case True{}:
      Some{List.reverse(&2, Leaf, out)}
    case False{}:
      None{}

def closed(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      False{}

def xml.fin(st: St) -> Maybe<&2, List<&2, Leaf>>:
  St{a, x, n, o, k} = st
  xml.if(Bool.and(k, closed(a)), o)

# The closed elements of a document in document order, or None when it is not well formed.
# ponytail: no DTD internal subsets, and no check of names or attribute syntax; S3 sends neither.
def xml(s: String) -> Maybe<&2, List<&2, Leaf>>:
  xml.fin(lex(s, LText{}, St{Nil{}, "", "", Nil{}, True{}}))

# ---- responses

# S3's <Error><Code>..</Code><Message>..</Message></Error>.
def fault.scan(ls: List<&2, Leaf>, code: String, msg: String) -> String & String:
  match ls:
    case Nil{}:
      (code, msg)
    case Con{Leaf{+p, +n, +x}, t}:
      +err = String.eq(p, "Error")
      fault.scan(t, Bool.pick(String, Bool.and(err, String.eq(n, "Code")), x, code),
        Bool.pick(String, Bool.and(err, String.eq(n, "Message")), x, msg))

def fault(m: Maybe<&2, List<&2, Leaf>>) -> String & String:
  match m:
    case None{}:
      ("", "")
    case Some{ls}:
      fault.scan(ls, "", "")

type Page<-O: Data> is Data:
  Page{objects: List<&2, O>, prefixes: List<&2, String>, next: Maybe<&2, String>}

type Acc<-O: Data> is Data:
  Acc{key: String, size: Nat, etag: String, modified: String, objs: List<&2, O>, pre: List<&2, String>, cut: Bool, next: String}

def nat(s: String) -> Nat:
  Maybe.default(&2, Nat, Nat.read(s), 0n)

def page.objects(~O: Data, ~object: String -> Nat -> String -> String -> O, done: Bool, key: String, size: Nat, etag: String, modified: String, objs: List<&2, O>) -> List<&2, O>:
  match done:
    case True{}:
      Con{object(key, size, etag, modified), objs}
    case False{}:
      objs

def page.leaf(~O: Data, ~object: String -> Nat -> String -> String -> O, a: Acc<O>, +p: String, +n: String, +x: String) -> Acc<O>:
  Acc{+key, +size, +etag, +modified, +objs, +pre, +cut, +next} = a
  +top = String.eq(p, "ListBucketResult")
  +field = String.eq(p, "Contents")
  +done = Bool.and(top, String.eq(n, "Contents"))
  Acc{Bool.pick(String, done, "", Bool.pick(String, Bool.and(field, String.eq(n, "Key")), x, key)),
    Bool.pick(Nat, done, 0n, Bool.pick(Nat, Bool.and(field, String.eq(n, "Size")), nat(x), size)),
    Bool.pick(String, done, "", Bool.pick(String, Bool.and(field, String.eq(n, "ETag")), x, etag)),
    Bool.pick(String, done, "", Bool.pick(String, Bool.and(field, String.eq(n, "LastModified")), x, modified)),
    page.objects(~O, ~object, done, key, size, etag, modified, objs),
    Bool.pick(List<&2, String>, Bool.and(String.eq(p, "CommonPrefixes"), String.eq(n, "Prefix")), Con{x, pre}, pre),
    Bool.pick(Bool, Bool.and(top, String.eq(n, "IsTruncated")), String.eq(x, "true"), cut),
    Bool.pick(String, Bool.and(top, String.eq(n, "NextContinuationToken")), x, next)}

def page.scan(~O: Data, ~object: String -> Nat -> String -> String -> O, ls: List<&2, Leaf>, a: Acc<O>) -> Acc<O>:
  match ls:
    case Nil{}:
      a
    case Con{Leaf{p, n, x}, t}:
      page.scan(~O, ~object, t, page.leaf(~O, ~object, a, p, n, x))

def page.fin(~O: Data, a: Acc<O>) -> Page<O>:
  Acc{key, size, etag, modified, objs, pre, +cut, +next} = a
  Page{List.reverse(&2, O, objs), List.reverse(&2, String, pre),
    Bool.pick(Maybe<&2, String>, Bool.and(cut, Bool.not(String.is_empty(next))), Some{next}, None{})}

def page.root.last(ls: List<&2, Leaf>, +n: String) -> String:
  match ls:
    case Nil{}:
      n
    case Con{Leaf{p, +m, x}, t}:
      page.root.last(t, m)

def page.if(~O: Data, ~object: String -> Nat -> String -> String -> O, good: Bool, ls: List<&2, Leaf>) -> Maybe<&2, Page<O>>:
  match good:
    case True{}:
      Some{page.fin(~O, page.scan(~O, ~object, ls, Acc{"", 0n, "", "", Nil{}, Nil{}, False{}, ""}))}
    case False{}:
      None{}

def page(~O: Data, ~object: String -> Nat -> String -> String -> O, m: Maybe<&2, List<&2, Leaf>>) -> Maybe<&2, Page<O>>:
  match m:
    case None{}:
      None{}
    case Some{+ls}:
      page.if(~O, ~object, String.eq(page.root.last(ls, ""), "ListBucketResult"), ls)
