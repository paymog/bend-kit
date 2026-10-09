# multipart/form-data (RFC 7578): an encoder with a secure random boundary and a streaming decoder over Bytes. Source: https://github.com/paymog/bend-kit/tree/main/multipart
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import bend-kit-crypto@0.1.0.0/crypto.bend as Crypto

# Names, filenames, and header values are byte strings, one Char per octet, as in Http.
# Bodies are Bytes and pass through untouched, so binary payloads keep every octet.
# Names and filenames are escaped as WHATWG does: '"' is %22, CR is %0D, LF is %0A.
#   import bend-kit-multipart@0.1.1.0/multipart.bend as Mp

# One form field. filename marks a file; ctype is its Content-Type (RFC 7578 §4.4 defaults to text/plain).
type Part is Type:
  Part{name: String, filename: Maybe<&2, String>, ctype: Maybe<&2, String>, body: Bytes.Bytes}

# What the streaming decoder reports, in order: Head, then zero or more Body pieces, then Tail, per part.
type Item is Type:
  Head{name: String, filename: Maybe<&2, String>, ctype: Maybe<&2, String>}
  Body{chunk: Bytes.Bytes}
  Tail{}

# ---- shared text helpers

# The text before the first c, and the text after it. No c gives (s, "").
def split1.cons(+h: U32, r: String & String) -> String & String:
  (a, b) = r
  (SCon{Chr{h}, a}, b)

def split1(s: String, +c: U32) -> String & String:
  match s:
    case SNil{}:
      (SNil{}, SNil{})
    case SCon{Chr{+h}, +t}:
      Bool.pick(String & String, U32.is_eq(h, c), (SNil{}, t), split1.cons(h, split1(t, c)))

# Header parameters (RFC 2045 §5.1, RFC 7578 §4.2): key=token or key="quoted", split on ';'.
# Keys are lowercased; a backslash escapes the next char inside quotes. An unterminated quote drops its parameter.
type Cls is Data:
  CEq{}
  CSemi{}
  CQuote{}
  CSlash{}
  CSp{}
  COther{}

type Pm is Data:
  PKey{}
  PStart{}
  PQuo{}
  PEsc{}
  PTok{}
  PSkip{}

type Param is Data:
  Param{key: String, val: String}

# mode, the key and value so far (reversed), and the parameters found (latest first).
type PS is Data:
  PS{mode: Pm, key: String, val: String, acc: List<&2, Param>}

def cls(+c: U32) -> Cls:
  Bool.pick(Cls, U32.is_eq(c, 61), CEq{}, Bool.pick(Cls, U32.is_eq(c, 59), CSemi{}, Bool.pick(Cls, U32.is_eq(c, 34), CQuote{}, Bool.pick(Cls, U32.is_eq(c, 92), CSlash{}, Bool.pick(Cls, Bool.or(U32.is_eq(c, 32), U32.is_eq(c, 9)), CSp{}, COther{})))))

def params.emit(key: String, val: String, acc: List<&2, Param>) -> List<&2, Param>:
  Con{Param{String.reverse(key), String.reverse(val)}, acc}

def params.step(st: PS, k: Cls, +c: U32) -> PS:
  PS{mode, key, val, acc} = st
  match mode:
    case PKey{}:
      match k:
        case CEq{}:
          PS{PStart{}, key, SNil{}, acc}
        case CSemi{}:
          PS{PKey{}, SNil{}, SNil{}, acc}
        case CSp{}:
          PS{PKey{}, key, val, acc}
        case _:
          PS{PKey{}, SCon{Char.to_lower(Chr{c}), key}, val, acc}
    case PStart{}:
      match k:
        case CQuote{}:
          PS{PQuo{}, key, SNil{}, acc}
        case CSp{}:
          PS{PStart{}, key, val, acc}
        case CSemi{}:
          PS{PKey{}, SNil{}, SNil{}, params.emit(key, SNil{}, acc)}
        case _:
          PS{PTok{}, key, SCon{Chr{c}, SNil{}}, acc}
    case PQuo{}:
      match k:
        case CSlash{}:
          PS{PEsc{}, key, val, acc}
        case CQuote{}:
          PS{PSkip{}, SNil{}, SNil{}, params.emit(key, val, acc)}
        case _:
          PS{PQuo{}, key, SCon{Chr{c}, val}, acc}
    case PEsc{}:
      PS{PQuo{}, key, SCon{Chr{c}, val}, acc}
    case PTok{}:
      match k:
        case CSemi{}:
          PS{PKey{}, SNil{}, SNil{}, params.emit(key, String.trim_start(val), acc)}
        case _:
          PS{PTok{}, key, SCon{Chr{c}, val}, acc}
    case PSkip{}:
      match k:
        case CSemi{}:
          PS{PKey{}, SNil{}, SNil{}, acc}
        case _:
          PS{PSkip{}, key, val, acc}

def params.end(st: PS) -> List<&2, Param>:
  PS{mode, key, val, acc} = st
  match mode:
    case PStart{}:
      params.emit(key, SNil{}, acc)
    case PTok{}:
      params.emit(key, String.trim_start(val), acc)
    case _:
      acc

def params.go(s: String, st: PS) -> PS:
  match s:
    case SNil{}:
      st
    case SCon{Chr{+c}, t}:
      params.go(t, params.step(st, cls(c), c))

# The parameters of a header value's text after its first ';', in order.
def params(s: String) -> List<&2, Param>:
  List.reverse(&2, Param, params.end(params.go(s, PS{PKey{}, SNil{}, SNil{}, Nil{}})))

# The first parameter named k (lowercase).
def lookup(xs: List<&2, Param>, +k: String) -> Maybe<&2, String>:
  match xs:
    case Nil{}:
      None{}
    case Con{Param{+k2, +v}, t}:
      Bool.pick(Maybe<&2, String>, String.eq(k2, k), Some{v}, lookup(t, k))

# WHATWG form-data escapes for names and filenames.
def esc.one(+c: U32) -> String:
  Bool.pick(String, U32.is_eq(c, 34), "%22", Bool.pick(String, U32.is_eq(c, 13), "%0D", Bool.pick(String, U32.is_eq(c, 10), "%0A", SCon{Chr{c}, SNil{}})))

def esc(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      esc.one(c) ++ esc(t)

# acc is reversed, so "%22" shows as "22%".
def unesc.fix(+a: String) -> String:
  Bool.pick(String, String.starts_with(a, "22%"), SCon{Chr{34}, String.drop(a, 3n)}, Bool.pick(String, String.starts_with(a, "D0%"), SCon{Chr{13}, String.drop(a, 3n)}, Bool.pick(String, String.starts_with(a, "A0%"), SCon{Chr{10}, String.drop(a, 3n)}, a)))

def unesc.go(s: String, acc: String) -> String:
  match s:
    case SNil{}:
      acc
    case SCon{c, t}:
      unesc.go(t, unesc.fix(SCon{c, acc}))

# Undoes esc, as the Fetch spec's form-data parser does. A literal "%22" in a name reads back as '"'.
def unesc(s: String) -> String:
  String.reverse(unesc.go(s, SNil{}))

def unesc.m(m: Maybe<&2, String>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{unesc(x)}

# ---- boundary

# RFC 2046 §5.1.1 bchars: DIGIT ALPHA ' ( ) + _ , - . / : = ? and space.
def bchar(+c: U32) -> Bool:
  Bool.or(Bool.or(Bool.or(Bytes.in(39, c, 41), Bytes.in(43, c, 58)), Bool.or(Bytes.in(65, c, 90), Bytes.in(97, c, 122))), Bool.or(Bool.or(U32.is_eq(c, 61), U32.is_eq(c, 63)), Bool.or(U32.is_eq(c, 95), U32.is_eq(c, 32))))

def bchars(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(bchar(c), bchars(t))

# 1 to 70 bchars, not ending in a space.
def boundary.ok(+b: String) -> Bool:
  +n = Bytes.count(b, 0)
  Bool.and(Bool.and(U32.is_le(1, n), U32.is_le(n, 70)), Bool.and(bchars(b), Bool.not(String.ends_with(b, " "))))

def boundary.words(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Result<&1, &1, U32 & String, String>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(+n, w)}:
      Done{"bend-kit-" ++ Bytes.to_hex(Bytes.Bytes{n, w})}

# "bend-kit-" and 128 bits from the OS secure random source, as hex: 41 bchars.
def boundary.new() -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Crypto.random.words(16)
    return boundary.words(r)

# The Content-Type header value for a body encoded with boundary b.
def content_type(b: String) -> String:
  "multipart/form-data; boundary=" ++ b

def boundary.get.of(r: String & String) -> Maybe<&2, String>:
  (ty, rest) = r
  lookup(params(rest), "boundary")

# The boundary parameter of a Content-Type value, such as a request's, or None.
def boundary.get(ct: String) -> Maybe<&2, String>:
  boundary.get.of(split1(ct, 59))

# ---- encoder

def enc.fname(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      SNil{}
    case Some{f}:
      "; filename=\"" ++ esc(f) ++ "\""

def enc.ctype(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      SNil{}
    case Some{c}:
      "Content-Type: " ++ c ++ "\r\n"

def enc.head(+b: String, name: String, fname: Maybe<&2, String>, ct: Maybe<&2, String>) -> String:
  "--" ++ b ++ "\r\nContent-Disposition: form-data; name=\"" ++ esc(name) ++ "\"" ++ enc.fname(fname) ++ "\r\n" ++ enc.ctype(ct) ++ "\r\n"

# A Content-Type with CR or LF would inject header lines.
def enc.ctype.ok(m: Maybe<&2, String>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{+c}:
      Bool.not(Bool.or(String.contains(c, "\r"), String.contains(c, "\n")))

def enc.found(r: Bytes.Bytes & Maybe<&2, U32>, +head: String, xs: List<&1, Bytes.Bytes>) -> Result<&1, &1, String, List<&1, Bytes.Bytes>>:
  (body, hit) = r
  match hit:
    case Some{i}:
      Fail{"multipart: boundary occurs in a part body"}
    case None{}:
      Done{Con{Bytes.from_string("\r\n"), Con{body, Con{Bytes.from_string(head), xs}}}}

def enc.body(ok: Bool, r: Bytes.Bytes & Maybe<&2, U32>, +head: String, xs: List<&1, Bytes.Bytes>) -> Result<&1, &1, String, List<&1, Bytes.Bytes>>:
  match ok:
    case False{}:
      Fail{"multipart: Content-Type has CR or LF"}
    case True{}:
      enc.found(r, head, xs)

# The pieces so far, latest first. A body cannot hold CRLF "--" boundary; bchars hold no CR,
# so the delimiter cannot start inside the body and end in the one after it.
def enc.part(acc: Result<&1, &1, String, List<&1, Bytes.Bytes>>, p: Part, +b: String, +delim: String) -> Result<&1, &1, String, List<&1, Bytes.Bytes>>:
  match acc:
    case Fail{e}:
      Fail{e}
    case Done{xs}:
      Part{name, fname, +ct, body} = p
      enc.body(enc.ctype.ok(ct), Bytes.find(body, delim), enc.head(b, name, fname, ct), xs)

def enc.fin(+b: String, acc: Result<&1, &1, String, List<&1, Bytes.Bytes>>) -> Result<&1, &1, String, Bytes.Bytes>:
  match acc:
    case Fail{e}:
      Fail{e}
    case Done{xs}:
      Done{Bytes.concat(List.reverse(&1, Bytes.Bytes, Con{Bytes.from_string("--" ++ b ++ "--\r\n"), xs}))}

def enc.go(parts: List<&1, Part>, +b: String, +delim: String, acc: Result<&1, &1, String, List<&1, Bytes.Bytes>>) -> Result<&1, &1, String, Bytes.Bytes>:
  match parts:
    case Nil{}:
      enc.fin(b, acc)
    case Con{p, t}:
      enc.go(t, b, delim, enc.part(acc, p, b, delim))

def encode.if(ok: Bool, +b: String, parts: List<&1, Part>) -> Result<&1, &1, String, Bytes.Bytes>:
  match ok:
    case False{}:
      Fail{"multipart: boundary must be 1 to 70 RFC 2046 bchars, not ending in a space"}
    case True{}:
      enc.go(parts, b, "\r\n--" ++ b, Done{Nil{}})

# The body for parts under boundary b (RFC 7578 §4.1). Fails when b is not a valid boundary,
# b's delimiter occurs in a body, or a Content-Type holds CR or LF.
def encode(+b: String, parts: List<&1, Part>) -> Result<&1, &1, String, Bytes.Bytes>:
  encode.if(boundary.ok(b), b, parts)

def form.enc(+b: String, r: Result<&1, &1, String, Bytes.Bytes>) -> Result<&1, &1, U32 & String, String & Bytes.Bytes>:
  match r:
    case Fail{m}:
      Fail{(22, m)}
    case Done{body}:
      Done{(content_type(b), body)}

def form.of(r: Result<&1, &1, U32 & String, String>, parts: List<&1, Part>) -> Result<&1, &1, U32 & String, String & Bytes.Bytes>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{+b}:
      form.enc(b, encode(b, parts))

# The Content-Type value and body for parts, under a fresh random boundary.
# Fails with the random source's error, or EINVAL (22) when encode fails.
def form(parts: List<&1, Part>) -> IO(Result<&1, &1, U32 & String, String & Bytes.Bytes>):
  do IO<Result<&1, &1, U32 & String, String & Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, String> <- boundary.new()
    return form.of(r, parts)

# ---- streaming decoder

# Pre: before the first delimiter. After: past a delimiter, before its line ends.
# Heads: in a header block. Text: in a body. End: past the close delimiter.
type Stage is Data:
  Pre{}
  After{}
  Heads{}
  Text{}
  End{}

type Step is Type:
  More{stage: Stage, buf: Bytes.Bytes, out: List<&1, Item>}
  Pause{stage: Stage, buf: Bytes.Bytes, out: List<&1, Item>}
  Bad{error: String}

# delim is CRLF "--" boundary and dlen its length; buf holds the bytes not yet decided.
type Dec is Type:
  Dec{delim: String, dlen: U32, stage: Stage, buf: Bytes.Bytes}

# ponytail: a fixed cap on a header block or boundary line; make it a decoder field if a caller needs another.
def MAX_HEAD() -> U32:
  16384

def drop(b: Bytes.Bytes, +n: U32) -> Bytes.Bytes:
  Bytes.snd(Bytes.slice(b, n, 4294967295))

def keep.two(+cut: U32, +k: U32, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & Bytes.Bytes:
  (b, h) = r
  (h, Bytes.snd(Bytes.slice(b, cut, k)))

def keep.of(+k: U32, r: Bytes.Bytes & U32) -> Bytes.Bytes & Bytes.Bytes:
  (b, +n) = r
  +cut = (n - U32.min(k, n) : U32)
  keep.two(cut, k, Bytes.slice(b, 0, cut))

# b as (all but its last k bytes, its last k bytes).
def keep(b: Bytes.Bytes, +k: U32) -> Bytes.Bytes & Bytes.Bytes:
  keep.of(k, Bytes.length(b))

def emit(empty: Bool, b: Bytes.Bytes, out: List<&1, Item>) -> List<&1, Item>:
  match empty:
    case True{}:
      out
    case False{}:
      Con{Body{b}, out}

def wait.if(big: Bool, st: Stage, buf: Bytes.Bytes, out: List<&1, Item>) -> Step:
  match big:
    case True{}:
      Bad{"multipart: header block or boundary line too long"}
    case False{}:
      Pause{st, buf, out}

# Wait for more input, unless the undecided bytes already pass MAX_HEAD.
def wait.big(st: Stage, r: Bytes.Bytes & U32, out: List<&1, Item>) -> Step:
  (buf, +n) = r
  wait.if(U32.is_lt(MAX_HEAD(), n), st, buf, out)

# What follows a delimiter match (RFC 2046 §5.1.1): "--", or transport padding then CRLF, makes it a
# delimiter (0). Anything else makes it data, as "--Bextra" is for boundary B (1). Too few bytes: 2.
def suffix.dash(s: String) -> U32:
  match s:
    case SNil{}:
      2
    case SCon{Chr{+c}, t}:
      Bool.pick(U32, U32.is_eq(c, 45), 0, 1)

def suffix.lf(s: String) -> U32:
  match s:
    case SNil{}:
      2
    case SCon{Chr{+c}, t}:
      Bool.pick(U32, U32.is_eq(c, 10), 0, 1)

def suffix(s: String, +first: Bool) -> U32:
  match s:
    case SNil{}:
      2
    case SCon{Chr{+c}, +t}:
      Bool.pick(U32, Bool.and(first, U32.is_eq(c, 45)), suffix.dash(t), Bool.pick(U32, Bool.or(U32.is_eq(c, 32), U32.is_eq(c, 9)), suffix(t, False{}), Bool.pick(U32, U32.is_eq(c, 13), suffix.lf(t), 1)))

# ponytail: looks at 64 bytes past the match; padding longer than that counts as data.
def suffix.win(+s: String) -> U32:
  +k = suffix(s, True{})
  Bool.pick(U32, Bool.and(U32.is_eq(k, 2), U32.is_eq(Bytes.count(s, 0), 64)), 1, k)

def suffix.of(r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & U32:
  (buf, w) = r
  (buf, suffix.win(Bytes.to_string(w)))

# The buffer and the kind of the match at i.
def suffix.at(buf: Bytes.Bytes, +i: U32, +dlen: U32) -> Bytes.Bytes & U32:
  suffix.of(Bytes.slice(buf, (i + dlen : U32), 64))

# Pre: the preamble is dropped. Keeping dlen - 1 bytes means a delimiter split across chunks is still found.
# A 0/1/2 suffix kind as two flags, since only a parameter can be matched.
def pre.if(delim: Bool, data: Bool, buf: Bytes.Bytes, +i: U32, +dlen: U32, out: List<&1, Item>) -> Step:
  match delim:
    case True{}:
      More{After{}, drop(buf, (i + dlen : U32)), out}
    case False{}:
      match data:
        case True{}:
          More{Pre{}, drop(buf, (i + 1 : U32)), out}
        case False{}:
          Pause{Pre{}, drop(buf, i), out}

def pre.kind(r: Bytes.Bytes & U32, +i: U32, +dlen: U32, out: List<&1, Item>) -> Step:
  (buf, +k) = r
  pre.if(U32.is_eq(k, 0), U32.is_eq(k, 1), buf, i, dlen, out)

def pre.hit(+dlen: U32, r: Bytes.Bytes & Maybe<&2, U32>, out: List<&1, Item>) -> Step:
  (buf, hit) = r
  match hit:
    case Some{+i}:
      pre.kind(suffix.at(buf, i, dlen), i, dlen, out)
    case None{}:
      Pause{Pre{}, Bytes.snd(keep(buf, (dlen - 1 : U32))), out}

# After: suffix already saw "--" or padding then CRLF, so both are in buf. "--" closes the body.
# The CRLF stays in buf, so the header block is found as CRLF ... CRLF CRLF, empty or not.
def after.line(r: Bytes.Bytes & Maybe<&2, U32>, out: List<&1, Item>) -> Step:
  (buf, hit) = r
  match hit:
    case Some{+i}:
      More{Heads{}, drop(buf, i), out}
    case None{}:
      wait.big(After{}, Bytes.length(buf), out)

def after.dash(r: Bytes.Bytes & Bool, out: List<&1, Item>) -> Step:
  (buf, dash) = r
  match dash:
    case True{}:
      More{End{}, Bytes.new(0), out}
    case False{}:
      after.line(Bytes.find(buf, "\r\n"), out)

# Header block to a Head (RFC 7578 §4.2, §4.4). Other headers are ignored (§4.8).
def meta.line(r: String & String, st: Maybe<&2, String> & Maybe<&2, String>) -> Maybe<&2, String> & Maybe<&2, String>:
  (n, v) = r
  (cd, ct) = st
  +key = String.to_lower(String.trim(n))
  +val = String.trim(v)
  (Bool.pick(Maybe<&2, String>, String.eq(key, "content-disposition"), Some{val}, cd), Bool.pick(Maybe<&2, String>, String.eq(key, "content-type"), Some{val}, ct))

def meta.go(lines: List<&2, String>, st: Maybe<&2, String> & Maybe<&2, String>) -> Maybe<&2, String> & Maybe<&2, String>:
  match lines:
    case Nil{}:
      st
    case Con{h, t}:
      meta.go(t, meta.line(split1(h, 58), st))

def head.named(n: Maybe<&2, String>, f: Maybe<&2, String>, ct: Maybe<&2, String>) -> Result<&1, &1, String, Item>:
  match n:
    case None{}:
      Fail{"multipart: part has no name"}
    case Some{x}:
      Done{Head{unesc(x), unesc.m(f), ct}}

def head.form(ok: Bool, +ps: List<&2, Param>, ct: Maybe<&2, String>) -> Result<&1, &1, String, Item>:
  match ok:
    case False{}:
      Fail{"multipart: Content-Disposition is not form-data"}
    case True{}:
      head.named(lookup(ps, "name"), lookup(ps, "filename"), ct)

def head.disp(r: String & String, ct: Maybe<&2, String>) -> Result<&1, &1, String, Item>:
  (ty, rest) = r
  head.form(String.eq(String.to_lower(String.trim(ty)), "form-data"), params(rest), ct)

def head.meta(r: Maybe<&2, String> & Maybe<&2, String>) -> Result<&1, &1, String, Item>:
  (cd, ct) = r
  match cd:
    case None{}:
      Fail{"multipart: part has no Content-Disposition"}
    case Some{v}:
      head.disp(split1(v, 59), ct)

# Lines split on LF; trimming drops each CR.
def head.parse(block: String) -> Result<&1, &1, String, Item>:
  head.meta(meta.go(String.split(block, Chr{10}), (None{}, None{})))

def heads.item(h: Result<&1, &1, String, Item>, rest: Bytes.Bytes, out: List<&1, Item>) -> Step:
  match h:
    case Fail{e}:
      Bad{e}
    case Done{it}:
      More{Text{}, rest, Con{it, out}}

def heads.cut(+j: U32, r: Bytes.Bytes & Bytes.Bytes, out: List<&1, Item>) -> Step:
  (buf, block) = r
  heads.item(head.parse(Bytes.to_string(block)), drop(buf, (j + 4 : U32)), out)

# buf starts with the CRLF that ended the boundary line, so a match at 0 is an empty block.
def heads.found(r: Bytes.Bytes & Maybe<&2, U32>, out: List<&1, Item>) -> Step:
  (buf, hit) = r
  match hit:
    case Some{+j}:
      heads.cut(j, Bytes.slice(buf, 2, (U32.max(j, 2) - 2 : U32)), out)
    case None{}:
      wait.big(Heads{}, Bytes.length(buf), out)

# Text: bytes that cannot begin a delimiter go out as Body; the last dlen - 1 wait for the next chunk.
def text.flush.len(r: Bytes.Bytes & U32, tail: Bytes.Bytes, out: List<&1, Item>) -> Step:
  (head, +n) = r
  Pause{Text{}, tail, emit(U32.is_eq(n, 0), head, out)}

def text.flush(r: Bytes.Bytes & Bytes.Bytes, out: List<&1, Item>) -> Step:
  (head, tail) = r
  text.flush.len(Bytes.length(head), tail, out)

def text.cut(+i: U32, +dlen: U32, r: Bytes.Bytes & Bytes.Bytes, out: List<&1, Item>) -> Step:
  (buf, piece) = r
  More{After{}, drop(buf, (i + dlen : U32)), Con{Tail{}, emit(U32.is_eq(i, 0), piece, out)}}

# A match that is data goes out through its first byte, and the search goes on after it.
def text.data(+n: U32, r: Bytes.Bytes & Bytes.Bytes, out: List<&1, Item>) -> Step:
  (buf, piece) = r
  More{Text{}, drop(buf, n), emit(False{}, piece, out)}

# A match whose suffix has not arrived: the bytes before it go out, and it waits.
def text.hold(+i: U32, r: Bytes.Bytes & Bytes.Bytes, out: List<&1, Item>) -> Step:
  (buf, piece) = r
  Pause{Text{}, drop(buf, i), emit(U32.is_eq(i, 0), piece, out)}

def text.if(delim: Bool, data: Bool, buf: Bytes.Bytes, +i: U32, +dlen: U32, out: List<&1, Item>) -> Step:
  match delim:
    case True{}:
      text.cut(i, dlen, Bytes.slice(buf, 0, i), out)
    case False{}:
      match data:
        case True{}:
          text.data((i + 1 : U32), Bytes.slice(buf, 0, (i + 1 : U32)), out)
        case False{}:
          text.hold(i, Bytes.slice(buf, 0, i), out)

def text.kind(r: Bytes.Bytes & U32, +i: U32, +dlen: U32, out: List<&1, Item>) -> Step:
  (buf, +k) = r
  text.if(U32.is_eq(k, 0), U32.is_eq(k, 1), buf, i, dlen, out)

def text.hit(+dlen: U32, r: Bytes.Bytes & Maybe<&2, U32>, out: List<&1, Item>) -> Step:
  (buf, hit) = r
  match hit:
    case Some{+i}:
      text.kind(suffix.at(buf, i, dlen), i, dlen, out)
    case None{}:
      text.flush(keep(buf, (dlen - 1 : U32)), out)

def step(st: Stage, +delim: String, +dlen: U32, buf: Bytes.Bytes, out: List<&1, Item>) -> Step:
  match st:
    case Pre{}:
      pre.hit(dlen, Bytes.find(buf, delim), out)
    case After{}:
      after.dash(Bytes.starts_with(buf, "--"), out)
    case Heads{}:
      heads.found(Bytes.find(buf, "\r\n\r\n"), out)
    case Text{}:
      text.hit(dlen, Bytes.find(buf, delim), out)
    case End{}:
      Pause{End{}, Bytes.new(0), out}

def go.stop(+delim: String, +dlen: U32, s: Step) -> Result<&1, &1, String, Dec & List<&1, Item>>:
  match s:
    case More{st, buf, out}:
      Done{(Dec{delim, dlen, st, buf}, List.reverse(&1, Item, out))}
    case Pause{st, buf, out}:
      Done{(Dec{delim, dlen, st, buf}, List.reverse(&1, Item, out))}
    case Bad{e}:
      Fail{e}

# Each More step consumes a byte, except the two after a delimiter, which itself consumes dlen >= 5,
# so len + 8 steps suffice. Running out still returns a sound state: the next feed goes on from it.
def go(fuel: Nat, +delim: String, +dlen: U32, s: Step) -> Result<&1, &1, String, Dec & List<&1, Item>>:
  match fuel:
    case 0n:
      go.stop(delim, dlen, s)
    case 1n+p:
      match s:
        case More{st, buf, out}:
          go(p, delim, dlen, step(st, delim, dlen, buf, out))
        case Pause{st, buf, out}:
          go.stop(delim, dlen, Pause{st, buf, out})
        case Bad{e}:
          Fail{e}

# A decoder for boundary b. It starts with a CRLF, so a delimiter at the very start is found like any other.
def decoder(b: String) -> Dec:
  +delim = "\r\n--" ++ b
  Dec{delim, Bytes.count(delim, 0), Pre{}, Bytes.from_string("\r\n")}

def feed.go(+delim: String, +dlen: U32, st: Stage, r: Bytes.Bytes & U32) -> Result<&1, &1, String, Dec & List<&1, Item>>:
  (buf, +n) = r
  go(U32.to_nat((n + 8 : U32)), delim, dlen, More{st, buf, Nil{}})

# The next chunk of a body, in any split. Answers the decoder and the items the chunk completes,
# or the first error. A body piece is held back only while it could start a delimiter.
def feed(d: Dec, chunk: Bytes.Bytes) -> Result<&1, &1, String, Dec & List<&1, Item>>:
  Dec{+delim, +dlen, st, buf} = d
  feed.go(delim, dlen, st, Bytes.length(Bytes.append(buf, chunk)))

# Done once the close delimiter has been read; the epilogue is ignored.
def finish(d: Dec) -> Result<&1, &1, String, Unit>:
  Dec{delim, dlen, st, buf} = d
  match st:
    case End{}:
      Done{Unit{}}
    case _:
      Fail{"multipart: body ends before the close delimiter"}

def collect.add(ps: List<&1, Part>, b: Bytes.Bytes) -> List<&1, Part>:
  match ps:
    case Nil{}:
      Nil{}
    case Con{Part{n, f, c, body}, t}:
      Con{Part{n, f, c, Bytes.append(body, b)}, t}

# Items folded into parts, latest first.
def collect(items: List<&1, Item>, ps: List<&1, Part>) -> List<&1, Part>:
  match items:
    case Nil{}:
      ps
    case Con{Head{n, f, c}, t}:
      collect(t, Con{Part{n, f, c, Bytes.new(0)}, ps})
    case Con{Body{b}, t}:
      collect(t, collect.add(ps, b))
    case Con{Tail{}, t}:
      collect(t, ps)

def chunks.fed(r: Result<&1, &1, String, Dec & List<&1, Item>>, ps: List<&1, Part>) -> Result<&1, &1, String, Dec & List<&1, Part>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(d, items)}:
      Done{(d, collect(items, ps))}

def chunks.step(st: Result<&1, &1, String, Dec & List<&1, Part>>, c: Bytes.Bytes) -> Result<&1, &1, String, Dec & List<&1, Part>>:
  match st:
    case Fail{e}:
      Fail{e}
    case Done{(d, ps)}:
      chunks.fed(feed(d, c), ps)

def chunks.fin(r: Result<&1, &1, String, Unit>, ps: List<&1, Part>) -> Result<&1, &1, String, List<&1, Part>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{u}:
      Done{List.reverse(&1, Part, ps)}

def chunks.end(st: Result<&1, &1, String, Dec & List<&1, Part>>) -> Result<&1, &1, String, List<&1, Part>>:
  match st:
    case Fail{e}:
      Fail{e}
    case Done{(d, ps)}:
      chunks.fin(finish(d), ps)

def chunks.go(cs: List<&1, Bytes.Bytes>, st: Result<&1, &1, String, Dec & List<&1, Part>>) -> Result<&1, &1, String, List<&1, Part>>:
  match cs:
    case Nil{}:
      chunks.end(st)
    case Con{c, t}:
      chunks.go(t, chunks.step(st, c))

# The parts of a body that arrives as chunks, split anywhere.
def decode.chunks(b: String, cs: List<&1, Bytes.Bytes>) -> Result<&1, &1, String, List<&1, Part>>:
  chunks.go(cs, Done{(decoder(b), Nil{})})

# The parts of a whole body.
def decode(b: String, body: Bytes.Bytes) -> Result<&1, &1, String, List<&1, Part>>:
  decode.chunks(b, [body])
