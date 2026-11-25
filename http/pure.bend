# Pure HTTP codecs, framing, redirect, retry, and cookie rules.
import Base
import bend-kit-time@0.3.0.2/pure.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-url@0.4.1.0/url.bend as Url
import bend-kit-encoding@0.5.0.1/encoding.bend as Enc
import bend-kit-json@0.7.3.0/json.bend as Json
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-zlib@0.7.0.2/zlib.bend as Zlib

type Req is Type:
  Req{method: String, path: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

type Res is Type:
  Res{status: U32, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

# A typed Data payload can be captured in receipt; the response remains affine.
def Body() -> Type:
  Bytes.Bytes

# A byte string (one Char per octet) to a body, and back.
def from_string(+s: String) -> Bytes.Bytes:
  Bytes.from_string(s)

def to_string(b: Bytes.Bytes) -> String:
  Bytes.to_string(b)

def length(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  Bytes.length(b)

# Why fetch failed. Wire errors keep the errno and the text the effect already had.
# ponytail: 60 and 110 are ETIMEDOUT on macOS and Linux. Windows is out of scope.
type Err is Data:
  ErrUrl{}
  ErrDns{}
  ErrConnect{code: U32, why: String}
  ErrTls{code: U32, why: String}
  ErrRead{code: U32, why: String}
  ErrWrite{code: U32, why: String}
  ErrTimeout{}
  ErrRedirect{}
  ErrBad{}

def err.late(+code: U32) -> Bool:
  Bool.or(U32.is_eq(code, 60), U32.is_eq(code, 110))

def err.pick(e: Err, late: Bool) -> Err:
  match late:
    case True{}:
      ErrTimeout{}
    case False{}:
      e

def err.or_late(code: U32, e: Err) -> Err:
  err.pick(e, err.late(code))

type Fields is Data:
  FieldsBad{}
  FieldsOk{m: Map<&2, List<&2, String>>}

# One list per field name, in arrival order. header() is the first value.
# Set-Cookie is never joined. Encode writes one line per value.
def empty() -> Map<&2, List<&2, String>>:
  Map.new(&2, List<&2, String>)

def fields.of(r: Map<&2, List<&2, String>> & List<&2, String>) -> List<&2, String>:
  (h, xs) = r
  xs

def fields(+h: Map<&2, List<&2, String>>, k: String) -> List<&2, String>:
  fields.of(Map.get(List<&2, String>, Nil{}, h, k))

def header.first(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{v, t}:
      v

def header(+h: Map<&2, List<&2, String>>, k: String) -> String:
  header.first(fields(h, k))

def field.last(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{v, Nil{}}:
      v
    case Con{v, t}:
      field.last(t)

# Transfer-Encoding is a list; chunked, when present, is the last coding.
def header.last(+h: Map<&2, List<&2, String>>, k: String) -> String:
  field.last(fields(h, k))

def snoc(xs: List<&2, String>, v: String) -> List<&2, String>:
  match xs:
    case Nil{}:
      [v]
    case Con{h, t}:
      Con{h, snoc(t, v)}

def set(m: Map<&2, List<&2, String>>, k: String, v: String) -> Map<&2, List<&2, String>>:
  Map.set(&2, List<&2, String>, m, k, [v])

def add(+m: Map<&2, List<&2, String>>, +k: String, v: String) -> Map<&2, List<&2, String>>:
  Map.set(&2, List<&2, String>, m, k, snoc(fields(m, k), v))

def sanitize.cons(ch: Char, rest: String, drop: Bool) -> String:
  match drop:
    case True{}:
      rest
    case False{}:
      SCon{ch, rest}

def sanitize(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      sanitize.cons(Chr{c}, sanitize(t), Bool.or(U32.is_eq(c, 13), U32.is_eq(c, 10)))

def drop_cr.last.if(cr: Bool, c: U32) -> String:
  match cr:
    case True{}:
      SNil{}
    case False{}:
      SCon{Chr{c}, SNil{}}

def drop_cr.last(+c: U32) -> String:
  drop_cr.last.if(U32.is_eq(c, 13), c)

# prev is the char before s; it is kept unless it is a final CR.
def drop_cr.go(s: String, prev: U32) -> String:
  match s:
    case SNil{}:
      drop_cr.last(prev)
    case SCon{Chr{c}, t}:
      SCon{Chr{prev}, drop_cr.go(t, c)}

def drop_cr(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{c}, t}:
      drop_cr.go(t, c)

# w holds the last four octets; a char past 255 clears it.
def blank_end.go(s: String, w: U32) -> Bool:
  match s:
    case SNil{}:
      U32.is_eq(w, 218762506)
    case SCon{Chr{+c}, t}:
      blank_end.go(t, Bool.pick(U32, U32.is_lt(c, 256), (w * 256 + c : U32), 0))

# String.ends_with(s, "\r\n\r\n") in one pass, with no reversed copy.
def blank_end(s: String) -> Bool:
  blank_end.go(s, 0)

def trim_end.cons(h: Char, r: String, space: Bool) -> String:
  match r:
    case SNil{}:
      match space:
        case True{}:
          SNil{}
        case False{}:
          SCon{h, SNil{}}
    case SCon{a, t}:
      SCon{h, SCon{a, t}}

# String.trim_end without the two reversed copies.
def trim_end(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+h, t}:
      trim_end.cons(h, trim_end(t), Char.is_space(h))

def trim(s: String) -> String:
  trim_end(String.trim_start(s))

# Bool.pick evaluates both arms; a split that recursed inside it would reverse acc at every byte.
def take.cut(acc: String, rest: String) -> String & String:
  (String.reverse(String.drop(acc, 1n)), rest)

# hit: the last char pushed onto acc was the stop char.
def take_sp.go(s: String, acc: String, hit: Bool) -> String & String:
  match s:
    case SNil{}:
      match hit:
        case True{}:
          take.cut(acc, SNil{})
        case False{}:
          (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, t}:
      match hit:
        case True{}:
          take.cut(acc, SCon{Chr{c}, t})
        case False{}:
          take_sp.go(t, SCon{Chr{c}, acc}, U32.is_eq(c, 32))

def take_sp(s: String) -> String & String:
  take_sp.go(s, SNil{}, False{})

def start_line.ver(m: String, pv: String & String) -> String & String & String:
  (p, v) = pv
  (m, p, drop_cr(v))

def start_line.rest(mr: String & String) -> String & String & String:
  (m, r) = mr
  start_line.ver(m, take_sp(r))

def start_line(s: String) -> String & String & String:
  start_line.rest(take_sp(s))

def split_at_blank.go(s: String, e: Bool, w: U32, acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{+a}, t}:
      match e:
        case True{}:
          (String.reverse(acc), SCon{Chr{a}, t})
        case False{}:
          +w2 = (w * 256 + a : U32)
          split_at_blank.go(t, U32.is_eq(w2, 218762506), w2, SCon{Chr{a}, acc})

# split_at_blank, plus whether the head ends in the blank line.
def split_at_blank.flag.go(+raw: String, s: String, off: Nat, w: U32, e: Bool) -> String & String & Bool:
  match s:
    case SNil{}:
      (String.take(raw, off), SNil{}, e)
    case SCon{Chr{+a}, t}:
      match e:
        case True{}:
          (String.take(raw, off), SCon{Chr{a}, t}, True{})
        case False{}:
          +w2 = (w * 256 + a : U32)
          +off1 = (1n + off : Nat)
          split_at_blank.flag.go(raw, t, off1, w2, U32.is_eq(w2, 218762506))

def split_at_blank.pair(r: String & String & Bool) -> String & String:
  (head, rest, whole) = r
  (head, rest)

def split_at_blank(+s: String) -> String & String:
  split_at_blank.pair(split_at_blank.flag.go(s, s, 0n, 0, False{}))

def split_colon.go(s: String, acc: String, hit: Bool) -> String & String:
  match s:
    case SNil{}:
      match hit:
        case True{}:
          take.cut(acc, SNil{})
        case False{}:
          (String.reverse(acc), SNil{})
    case SCon{Chr{+c}, t}:
      match hit:
        case True{}:
          take.cut(acc, SCon{Chr{c}, t})
        case False{}:
          split_colon.go(t, SCon{Char.to_lower(Chr{c}), acc}, U32.is_eq(c, 58))

def split_colon(+s: String) -> String & String:
  split_colon.go(s, SNil{}, False{})

def has_header.of(r: Map<&2, List<&2, String>> & Bool) -> Bool:
  (h, b) = r
  b

def has_header(+h: Map<&2, List<&2, String>>, k: String) -> Bool:
  has_header.of(Map.has(&2, List<&2, String>, h, k))

def folded(+line: String) -> Bool:
  Bool.or(String.starts_with(line, " "), String.starts_with(line, "\t"))

def tracked(+k: String) -> Bool:
  Bool.or(String.eq(k, "host"), String.eq(k, "content-length"))

def fields_put.dup(m: Map<&2, List<&2, String>>, k: String, v: String, bad: Bool) -> Fields:
  match bad:
    case True{}:
      FieldsBad{}
    case False{}:
      FieldsOk{add(m, k, v)}

def fields_put.tracked(+m: Map<&2, List<&2, String>>, +k: String, v: String, t: Bool) -> Fields:
  match t:
    case True{}:
      fields_put.dup(m, k, v, has_header(m, k))
    case False{}:
      FieldsOk{add(m, k, v)}

def fields_put.key(+m: Map<&2, List<&2, String>>, +k: String, v: String) -> Fields:
  fields_put.tracked(m, k, v, tracked(k))

def fields_put.kv(m: Map<&2, List<&2, String>>, kv: String & String) -> Fields:
  (k, v) = kv
  fields_put.key(m, k, trim(v))

def fields_put.fold(m: Map<&2, List<&2, String>>, line: String, fold: Bool) -> Fields:
  match fold:
    case True{}:
      FieldsBad{}
    case False{}:
      fields_put.kv(m, split_colon(line))

def fields_put.empty(m: Map<&2, List<&2, String>>, +line: String, e: Bool) -> Fields:
  match e:
    case True{}:
      FieldsOk{m}
    case False{}:
      fields_put.fold(m, line, folded(line))

def fields_put.ok(m: Map<&2, List<&2, String>>, +line: String) -> Fields:
  fields_put.empty(m, line, String.is_empty(line))

def fields_put(acc: Fields, line: String) -> Fields:
  match acc:
    case FieldsBad{}:
      FieldsBad{}
    case FieldsOk{m}:
      fields_put.ok(m, line)

def parse.headers.done(acc: Fields) -> Maybe<&2, Map<&2, List<&2, String>>>:
  match acc:
    case FieldsBad{}:
      None{}
    case FieldsOk{m}:
      Some{m}


def parse.headers.scan.line(acc: String, fields: Fields) -> Fields:
  match acc:
    case SCon{Chr{13}, t}:
      fields_put(fields, String.reverse(t))
    case other:
      fields_put(fields, String.reverse(other))

def parse.headers.scan(s: String, acc: String, fields: Fields) -> Fields:
  match s:
    case SNil{}:
      parse.headers.scan.line(acc, fields)
    case SCon{Chr{10}, t}:
      parse.headers.scan(t, SNil{}, parse.headers.scan.line(acc, fields))
    case SCon{c, t}:
      parse.headers.scan(t, SCon{c, acc}, fields)

def parse.headers.raw(s: String) -> Maybe<&2, Map<&2, List<&2, String>>>:
  parse.headers.done(parse.headers.scan(s, SNil{}, FieldsOk{empty()}))

def parse.first(s: String, acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), SNil{})
    case SCon{Chr{10}, t}:
      (String.reverse(acc), t)
    case SCon{c, t}:
      parse.first(t, SCon{c, acc})

def parse_u32.digit(+c: U32) -> Bool:
  Bool.and(U32.is_le(48, c), U32.is_le(c, 57))

def parse_u32.add(acc: U32, c: U32) -> U32:
  (acc * 10 + (c - 48 : U32) : U32)

def parse_u32.done(acc: U32, bad: Bool) -> Maybe<&2, U32>:
  match bad:
    case True{}:
      None{}
    case False{}:
      Some{acc}

def parse_u32.go(s: String, acc: U32, bad: Bool) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      parse_u32.done(acc, bad)
    case SCon{Chr{+c}, t}:
      parse_u32.go(t, parse_u32.add(acc, c), Bool.or(bad, Bool.not(parse_u32.digit(c))))

def parse_u32(s: String) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, t}:
      parse_u32.go(t, parse_u32.add(0, c), Bool.not(parse_u32.digit(c)))

# More: a valid prefix. Bad: cannot become a body. Body: a whole chunked body.
type Hold is Data:
  HoldMore{}
  HoldBad{}
  HoldBody{b: String}
  HoldUntil{b: String}

def is_hex(+c: U32) -> Bool:
  Bool.or(parse_u32.digit(c), Bool.or(Bool.and(U32.is_le(97, c), U32.is_le(c, 102)), Bool.and(U32.is_le(65, c), U32.is_le(c, 70))))

def hexv(+c: U32) -> U32:
  Bool.pick(U32, parse_u32.digit(c), (c - 48 : U32), Bool.pick(U32, U32.is_le(c, 70), (c - 55 : U32), (c - 87 : U32)))

# A chunked body decoder that reads each byte once, so a body fed in pieces
# costs O(bytes) in total. Tr{j}: j bytes of the closing CRLF CRLF matched.
type Dc is Data:
  DcSize{acc: U32, seen: Bool}
  DcExt{n: U32}
  DcSizeLf{n: U32}
  DcData{k: U32}
  DcDataCr{}
  DcDataLf{}
  DcTr{j: U32}
  DcDone{}
  DcBad{}

# st: where the decoder is. racc: the body so far, reversed. rest: bytes after a Done body.
type Dco is Data:
  Dco{st: Dc, racc: String, rest: String}

def dc.start() -> Dc:
  DcSize{0, False{}}

def dc.size.semi(+n: U32, semi: Bool) -> Dc:
  match semi:
    case True{}:
      DcExt{n}
    case False{}:
      DcBad{}

def dc.size.cr(+n: U32, +c: U32, cr: Bool) -> Dc:
  match cr:
    case True{}:
      DcSizeLf{n}
    case False{}:
      dc.size.semi(n, U32.is_eq(c, 59))

def dc.size.end(+n: U32, +c: U32, seen: Bool) -> Dc:
  match seen:
    case False{}:
      DcBad{}
    case True{}:
      dc.size.cr(n, c, U32.is_eq(c, 13))

# A size that would overflow 32 bits ends the digits, and size.end then refuses it.
def dc.size(+acc: U32, seen: Bool, +c: U32, digit: Bool) -> Dc:
  match digit:
    case True{}:
      DcSize{(acc * 16 + hexv(c) : U32), True{}}
    case False{}:
      dc.size.end(acc, c, seen)

# RFC 9112 §7.1.1: recipients ignore unknown chunk extensions; a bare LF is not CRLF.
def dc.ext.lf(+n: U32, lf: Bool) -> Dc:
  match lf:
    case True{}:
      DcBad{}
    case False{}:
      DcExt{n}

def dc.ext(+n: U32, +c: U32, cr: Bool) -> Dc:
  match cr:
    case True{}:
      DcSizeLf{n}
    case False{}:
      dc.ext.lf(n, U32.is_eq(c, 10))

def dc.sized(+n: U32, zero: Bool) -> Dc:
  match zero:
    case True{}:
      DcTr{2}
    case False{}:
      DcData{n}

def dc.size.lf(+n: U32, lf: Bool) -> Dc:
  match lf:
    case True{}:
      dc.sized(n, U32.is_eq(n, 0))
    case False{}:
      DcBad{}

# k data bytes are left and m of them were just read.
def dc.data(+k: U32, +m: U32) -> Dc:
  Bool.pick(Dc, U32.is_le(k, m), DcDataCr{}, DcData{(k - m : U32)})

def dc.pick(ok: Bool, next: Dc) -> Dc:
  match ok:
    case True{}:
      next
    case False{}:
      DcBad{}

# ponytail: trailer fields are dropped unparsed (§7.1.2 allows discarding)
def dc.tr.hit(+j: U32) -> Dc:
  Bool.pick(Dc, U32.is_eq(j, 3), DcDone{}, DcTr{(j + 1 : U32)})

def dc.tr(+j: U32, +c: U32, hit: Bool) -> Dc:
  match hit:
    case True{}:
      dc.tr.hit(j)
    case False{}:
      Bool.pick(Dc, U32.is_eq(c, 13), DcTr{1}, DcTr{0})

def dc.tr.want(+j: U32) -> U32:
  Bool.pick(U32, U32.is_eq(U32.mod(j, 2), 0), 13, 10)

def dc.byte(h: Char) -> U32:
  Chr{c} = h
  c

# One byte c. Done and Bad never look at it, and a data byte is not inspected.
def dc.step(st: Dc, +c: U32) -> Dc:
  match st:
    case DcBad{}:
      DcBad{}
    case DcSize{+acc, seen}:
      dc.size(acc, seen, c, Bool.and(is_hex(c), U32.is_le(acc, 268435455)))
    case DcExt{+n}:
      dc.ext(n, c, U32.is_eq(c, 13))
    case DcSizeLf{+n}:
      dc.size.lf(n, U32.is_eq(c, 10))
    case DcDataCr{}:
      dc.pick(U32.is_eq(c, 13), DcDataLf{})
    case DcDataLf{}:
      dc.pick(U32.is_eq(c, 10), dc.start())
    case DcTr{+j}:
      dc.tr(j, c, U32.is_eq(c, dc.tr.want(j)))
    case DcData{+k}:
      dc.data(k, 1)
    case DcDone{}:
      DcDone{}

def dc.live(st: Dc) -> Bool:
  match st:
    case DcDone{}:
      False{}
    case DcBad{}:
      False{}
    case DcSize{a, b}:
      True{}
    case DcExt{n}:
      True{}
    case DcSizeLf{n}:
      True{}
    case DcData{k}:
      True{}
    case DcDataCr{}:
      True{}
    case DcDataLf{}:
      True{}
    case DcTr{j}:
      True{}

def dc.feed(s: String, st: Dc, racc: String) -> Dco:
  match s:
    case SNil{}:
      Dco{st, racc, ""}
    case SCon{h, t}:
      match st:
        case DcBad{}:
          Dco{DcBad{}, racc, ""}
        case DcDone{}:
          Dco{DcDone{}, racc, SCon{h, t}}
        case DcData{+k}:
          dc.feed(t, dc.data(k, 1), SCon{h, racc})
        case DcSize{+acc, seen}:
          dc.feed(t, dc.step(DcSize{acc, seen}, dc.byte(h)), racc)
        case DcExt{+n}:
          dc.feed(t, dc.step(DcExt{n}, dc.byte(h)), racc)
        case DcSizeLf{+n}:
          dc.feed(t, dc.step(DcSizeLf{n}, dc.byte(h)), racc)
        case DcDataCr{}:
          dc.feed(t, dc.step(DcDataCr{}, dc.byte(h)), racc)
        case DcDataLf{}:
          dc.feed(t, dc.step(DcDataLf{}, dc.byte(h)), racc)
        case DcTr{+j}:
          dc.feed(t, dc.step(DcTr{j}, dc.byte(h)), racc)

def chunk.hold(o: Dco) -> Hold:
  Dco{st, racc, rest} = o
  match st:
    case DcDone{}:
      HoldBody{String.reverse(racc)}
    case DcBad{}:
      HoldBad{}
    case DcSize{a, b}:
      HoldMore{}
    case DcExt{n}:
      HoldMore{}
    case DcSizeLf{n}:
      HoldMore{}
    case DcData{k}:
      HoldMore{}
    case DcDataCr{}:
      HoldMore{}
    case DcDataLf{}:
      HoldMore{}
    case DcTr{j}:
      HoldMore{}

def chunk.live(s: String) -> Hold:
  chunk.hold(dc.feed(s, dc.start(), ""))

def chunk.rest(o: Dco) -> Maybe<&2, String>:
  Dco{st, racc, rest} = o
  match st:
    case DcDone{}:
      Some{rest}
    case DcBad{}:
      None{}
    case DcSize{a, b}:
      None{}
    case DcExt{n}:
      None{}
    case DcSizeLf{n}:
      None{}
    case DcData{k}:
      None{}
    case DcDataCr{}:
      None{}
    case DcDataLf{}:
      None{}
    case DcTr{j}:
      None{}

def chunk.suffix(s: String) -> Maybe<&2, String>:
  chunk.rest(dc.feed(s, dc.start(), ""))

def chunk.decode.hold(h: Hold) -> Maybe<&2, String>:
  match h:
    case HoldMore{}:
      None{}
    case HoldBad{}:
      None{}
    case HoldUntil{b}:
      None{}
    case HoldBody{b}:
      Some{b}

def chunk.decode(s: String) -> Maybe<&2, String>:
  chunk.decode.hold(chunk.live(s))

def bytes.snd(r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes:
  (a, b) = r
  b

def found.at(+from: U32, m: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{+j}:
      Some{(from + j : U32)}

# A chunked body decoded from piece[i..]: a data run is sliced whole, and every other byte steps dc.
type Cs is Type:
  Cs{piece: Bytes.Bytes, i: U32, st: Dc, parts: List<&1, Bytes.Bytes>}

# st: where the decoder stopped. parts: the data so far, newest first. rest: the bytes after a Done body.
type Ck is Type:
  Ck{st: Dc, parts: List<&1, Bytes.Bytes>, rest: Bytes.Bytes}

def ck.next(+len: U32, +i: U32, +st: Dc, piece: Bytes.Bytes, parts: List<&1, Bytes.Bytes>) -> Bool & Cs:
  (Bool.and(U32.is_lt(i, len), dc.live(st)), Cs{piece, i, st, parts})

def ck.data(+len: U32, +i: U32, +k: U32, +m: U32, parts: List<&1, Bytes.Bytes>, r: Bytes.Bytes & Bytes.Bytes) -> Bool & Cs:
  (piece, run) = r
  ck.next(len, (i + m : U32), dc.data(k, m), piece, Con{run, parts})

def ck.byte(+len: U32, +i: U32, st: Dc, parts: List<&1, Bytes.Bytes>, r: Bytes.Bytes & Maybe<&2, U32>) -> Bool & Cs:
  (piece, m) = r
  match m:
    case None{}:
      ck.next(len, i, DcBad{}, piece, parts)
    case Some{+c}:
      ck.next(len, (i + 1 : U32), dc.step(st, c), piece, parts)

def ck.step(+len: U32, cs: Cs) -> Bool & Cs:
  Cs{piece, +i, st, parts} = cs
  match st:
    case DcData{+k}:
      +m = U32.min(k, (len - i : U32))
      ck.data(len, i, k, m, parts, Bytes.slice(piece, i, m))
    case DcDone{}:
      (False{}, Cs{piece, i, DcDone{}, parts})
    case DcBad{}:
      (False{}, Cs{piece, i, DcBad{}, parts})
    case DcSize{+acc, seen}:
      ck.byte(len, i, DcSize{acc, seen}, parts, Bytes.get(piece, i))
    case DcExt{+n}:
      ck.byte(len, i, DcExt{n}, parts, Bytes.get(piece, i))
    case DcSizeLf{+n}:
      ck.byte(len, i, DcSizeLf{n}, parts, Bytes.get(piece, i))
    case DcDataCr{}:
      ck.byte(len, i, DcDataCr{}, parts, Bytes.get(piece, i))
    case DcDataLf{}:
      ck.byte(len, i, DcDataLf{}, parts, Bytes.get(piece, i))
    case DcTr{+j}:
      ck.byte(len, i, DcTr{j}, parts, Bytes.get(piece, i))

def ck.rest(st: Dc, parts: List<&1, Bytes.Bytes>, r: Bytes.Bytes & Bytes.Bytes) -> Ck:
  (piece, rest) = r
  Ck{st, parts, rest}

def ck.end(+len: U32, cs: Cs) -> Ck:
  Cs{piece, +i, st, parts} = cs
  ck.rest(st, parts, Bytes.slice(piece, i, (len - i : U32)))

# Each step reads at least one byte, so len steps are enough.
def ck.feed(f: Nat, +len: U32, r: Bool & Cs) -> Ck:
  match f:
    case 0n:
      (go, cs) = r
      ck.end(len, cs)
    case 1n+p:
      (go, cs) = r
      match go:
        case False{}:
          ck.end(len, cs)
        case True{}:
          ck.feed(p, len, ck.step(len, cs))

def ck(piece: Bytes.Bytes, +st: Dc, parts: List<&1, Bytes.Bytes>) -> Ck:
  Bytes.Bytes{+len, buf} = piece
  ck.feed(U32.to_nat(len), len, ck.next(len, 0, st, Bytes.Bytes{len, buf}, parts))

def parse.res.cl.have(+rest: String, +k: Nat, short: Bool) -> Hold:
  match short:
    case True{}:
      HoldMore{}
    case False{}:
      HoldBody{String.take(rest, k)}

def parse.res.cl.k(+rest: String, +k: Nat) -> Hold:
  parse.res.cl.have(rest, k, Nat.is_lt(String.length(rest), k))

def parse.res.cl.n(rest: String, n: Maybe<&2, U32>) -> Hold:
  match n:
    case None{}:
      HoldBad{}
    case Some{k}:
      parse.res.cl.k(rest, U32.to_nat(k))

def parse.body.cl(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Hold:
  match hascl:
    case False{}:
      HoldBody{""}
    case True{}:
      parse.res.cl.n(rest, parse_u32(header(h, "content-length")))

# RFC 9112 §6.3 (4): a request coding other than chunked cannot be framed.
def parse.body.chunked.eq(rest: String, ok: Bool) -> Hold:
  match ok:
    case False{}:
      HoldBad{}
    case True{}:
      chunk.live(rest)

def parse.body.chunked.val(te: String, rest: String) -> Hold:
  parse.body.chunked.eq(rest, String.eq(String.to_lower(te), "chunked"))

def parse.body.chunked(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Hold:
  match hascl:
    case True{}:
      HoldBad{}
    case False{}:
      parse.body.chunked.val(header.last(h, "transfer-encoding"), rest)

def parse.body.te(+h: Map<&2, List<&2, String>>, rest: String, te: Bool) -> Hold:
  match te:
    case True{}:
      parse.body.chunked(h, rest, has_header(h, "content-length"))
    case False{}:
      parse.body.cl(h, rest, has_header(h, "content-length"))

def parse.body(+h: Map<&2, List<&2, String>>, rest: String) -> Hold:
  parse.body.te(h, rest, has_header(h, "transfer-encoding"))

# Bad: never a request. More: the head is not whole; read on. Head: the head is whole
# and valid, and the body is still coming (req.body is empty). Req: a whole request.
type Got is Type:
  GotBad{}
  GotMore{}
  GotHead{req: Req}
  GotReq{req: Req}

def parse.finish(method: String, path: String, h: Map<&2, List<&2, String>>, body: Hold) -> Got:
  match body:
    case HoldBad{}:
      GotBad{}
    case HoldMore{}:
      GotHead{Req{method, path, h, Bytes.new(0)}}
    case HoldUntil{b}:
      GotBad{}
    case HoldBody{b}:
      GotReq{Req{method, path, h, Bytes.from_string(b)}}

def parse.host(method: String, path: String, +h: Map<&2, List<&2, String>>, rest: String, has: Bool) -> Got:
  match has:
    case False{}:
      GotBad{}
    case True{}:
      parse.finish(method, path, h, parse.body(h, rest))

# RFC 9112 §3.2: only HTTP/1.1 requires Host.
def parse.fields(method: String, path: String, rest: String, v11: Bool, fs: Maybe<&2, Map<&2, List<&2, String>>>) -> Got:
  match fs:
    case None{}:
      GotBad{}
    case Some{+h}:
      parse.host(method, path, h, rest, Bool.or(Bool.not(v11), has_header(h, "host")))

def target_ok(+p: String) -> Bool:
  Bool.or(String.starts_with(p, "/"), Bool.or(String.eq(p, "*"), String.starts_with(p, "http://")))

def parse.target(method: String, +path: String, headers: String, rest: String, v11: Bool, ok: Bool) -> Got:
  match ok:
    case False{}:
      GotBad{}
    case True{}:
      parse.fields(method, path, rest, v11, parse.headers.raw(headers))

def parse.ver(method: String, +path: String, +v: String, headers: String, rest: String, ok: Bool) -> Got:
  match ok:
    case False{}:
      GotBad{}
    case True{}:
      parse.target(method, path, headers, rest, String.eq(v, "HTTP/1.1"), target_ok(path))

def parse.empty_method(method: String, path: String, +v: String, headers: String, rest: String, empty: Bool) -> Got:
  match empty:
    case True{}:
      GotBad{}
    case False{}:
      parse.ver(method, path, v, headers, rest, Bool.or(String.eq(v, "HTTP/1.1"), String.eq(v, "HTTP/1.0")))

def parse.start3(mpv: String & String & String, headers: String, rest: String) -> Got:
  (+method, path, v) = mpv
  parse.empty_method(method, path, v, headers, rest, String.is_empty(method))

def parse.lines(lr: String & String, rest: String) -> Got:
  (line, headers) = lr
  parse.start3(start_line(line), headers, rest)


def parse.head(+head: String, rest: String, whole: Bool) -> Got:
  match whole:
    case False{}:
      GotMore{}
    case True{}:
      parse.lines(parse.first(head, SNil{}), rest)

def parse.of(hb: String & String & Bool) -> Got:
  (head, rest, whole) = hb
  parse.head(head, rest, whole)

# serve reads until this is not GotMore.
def parse.got(+raw: String) -> Got:
  parse.of(split_at_blank.flag.go(raw, raw, 0n, 0, False{}))


def parse.req(g: Got) -> Maybe<&1, Req>:
  match g:
    case GotReq{req}:
      Some{req}
    case GotBad{}:
      None{}
    case GotMore{}:
      None{}
    case GotHead{req}:
      None{}

def parse(raw: String) -> Maybe<&1, Req>:
  parse.req(parse.got(raw))

def parse.res.cl(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Hold:
  match hascl:
    case False{}:
      HoldBody{rest}
    case True{}:
      parse.res.cl.n(rest, parse_u32(header(h, "content-length")))

def parse.res.chunked.eq(rest: String, ok: Bool) -> Hold:
  match ok:
    case False{}:
      HoldUntil{rest}
    case True{}:
      chunk.live(rest)

def parse.res.chunked.val(te: String, rest: String) -> Hold:
  parse.res.chunked.eq(rest, String.eq(String.to_lower(te), "chunked"))

def parse.res.chunked(+h: Map<&2, List<&2, String>>, rest: String, hascl: Bool) -> Hold:
  match hascl:
    case True{}:
      HoldBad{}
    case False{}:
      parse.res.chunked.val(header.last(h, "transfer-encoding"), rest)

def parse.res.te(+h: Map<&2, List<&2, String>>, rest: String, te: Bool) -> Hold:
  match te:
    case True{}:
      parse.res.chunked(h, rest, has_header(h, "content-length"))
    case False{}:
      parse.res.cl(h, rest, has_header(h, "content-length"))

def parse.res.body(+h: Map<&2, List<&2, String>>, rest: String) -> Hold:
  parse.res.te(h, rest, has_header(h, "transfer-encoding"))

# Bad: never a message. More: a valid prefix; read on. Done: a whole response.
type Frame is Type:
  FrameBad{}
  FrameMore{}
  FrameDone{res: Res}

# RFC 9112 §8: a message cut short by close is incomplete, not valid.
def frame.cut(closed: Bool) -> Frame:
  match closed:
    case True{}:
      FrameBad{}
    case False{}:
      FrameMore{}

def frame.wait(res: Res, wait: Bool) -> Frame:
  match wait:
    case True{}:
      FrameMore{}
    case False{}:
      FrameDone{res}

def frame.done(status: U32, h: Map<&2, List<&2, String>>, body: Hold, +closed: Bool, open: Bool) -> Frame:
  match body:
    case HoldBad{}:
      FrameBad{}
    case HoldMore{}:
      frame.cut(closed)
    case HoldUntil{b}:
      frame.wait(Res{status, h, Bytes.from_string(b)}, Bool.not(closed))
    case HoldBody{b}:
      frame.wait(Res{status, h, Bytes.from_string(b)}, Bool.and(open, Bool.not(closed)))

# RFC 9112 §6.3 (8): no TE and no CL ⇒ the body runs until the server closes.
def frame.open(+h: Map<&2, List<&2, String>>) -> Bool:
  Bool.not(Bool.or(has_header(h, "transfer-encoding"), has_header(h, "content-length")))

# RFC 9112 §6.3 (1): HEAD, 1xx, 204 and 304 responses end at the blank line.
def frame.nobody(+status: U32, head: Bool) -> Bool:
  Bool.or(head, Bool.or(U32.is_lt(status, 200), Bool.or(U32.is_eq(status, 204), U32.is_eq(status, 304))))

# 101 is the final response. Other 1xx are interim; a final response follows.
def frame.interim(+status: U32) -> Bool:
  Bool.and(U32.is_lt(status, 200), Bool.not(U32.is_eq(status, 101)))

def frame.status(status: U32, +h: Map<&2, List<&2, String>>, rest: String, closed: Bool, nobody: Bool) -> Frame:
  match nobody:
    case True{}:
      FrameDone{Res{status, h, Bytes.new(0)}}
    case False{}:
      frame.done(status, h, parse.res.body(h, rest), closed, frame.open(h))

def parse.res.fields(+status: U32, rest: String, fs: Maybe<&2, Map<&2, List<&2, String>>>, closed: Bool, head: Bool) -> Frame:
  match fs:
    case None{}:
      FrameBad{}
    case Some{h}:
      frame.status(status, h, rest, closed, frame.nobody(status, head))

def parse.res.num(code: Maybe<&2, U32>, headers: String, rest: String, closed: Bool, head: Bool) -> Frame:
  match code:
    case None{}:
      FrameBad{}
    case Some{n}:
      parse.res.fields(n, rest, parse.headers.raw(headers), closed, head)

def parse.res.ver(code: String, headers: String, rest: String, closed: Bool, head: Bool, ok: Bool) -> Frame:
  match ok:
    case False{}:
      FrameBad{}
    case True{}:
      parse.res.num(parse_u32(code), headers, rest, closed, head)

def parse.res.start3(mpv: String & String & String, headers: String, rest: String, closed: Bool, head: Bool) -> Frame:
  (+ver, code, reason) = mpv
  parse.res.ver(code, headers, rest, closed, head, Bool.or(String.eq(ver, "HTTP/1.1"), String.eq(ver, "HTTP/1.0")))

def parse.res.lines(lr: String & String, rest: String, closed: Bool, head: Bool) -> Frame:
  (line, headers) = lr
  parse.res.start3(start_line(line), headers, rest, closed, head)

def parse.res.blank(hd: String, rest: String, +closed: Bool, head: Bool, ok: Bool) -> Frame:
  match ok:
    case False{}:
      frame.cut(closed)
    case True{}:
      parse.res.lines(parse.first(hd, SNil{}), rest, closed, head)

def parse.res.of(hb: String & String, closed: Bool, head: Bool) -> Frame:
  (+hd, rest) = hb
  parse.res.blank(hd, rest, closed, head, blank_end(hd))

type Lead is Data:
  LeadCut{}
  LeadFinal{}
  LeadSkip{+rest: String}

def frame.lead.if(rest: String, interim: Bool) -> Lead:
  match interim:
    case True{}:
      LeadSkip{rest}
    case False{}:
      LeadFinal{}

def frame.lead.num(n: Maybe<&2, U32>, rest: String) -> Lead:
  match n:
    case None{}:
      LeadFinal{}
    case Some{s}:
      frame.lead.if(rest, frame.interim(s))

def frame.lead.code(mpv: String & String & String, rest: String) -> Lead:
  (ver, code, reason) = mpv
  frame.lead.num(parse_u32(code), rest)

def frame.lead.lines(xs: List<&2, String>, rest: String) -> Lead:
  match xs:
    case Nil{}:
      LeadFinal{}
    case Con{line, headers}:
      frame.lead.code(start_line(line), rest)

def frame.lead.blank(+hd: String, rest: String, ok: Bool) -> Lead:
  match ok:
    case False{}:
      LeadCut{}
    case True{}:
      frame.lead.lines(String.lines(hd), rest)

def frame.lead(hb: String & String) -> Lead:
  (+hd, rest) = hb
  frame.lead.blank(hd, rest, blank_end(hd))

def frame.at.cont(+raw: String, lead: Lead) -> String:
  match lead:
    case LeadCut{}:
      raw
    case LeadFinal{}:
      raw
    case LeadSkip{rest}:
      rest

def frame.at.zero.go(+raw: String, closed: Bool, head: Bool, lead: Lead) -> Frame:
  match lead:
    case LeadCut{}:
      frame.cut(closed)
    case LeadFinal{}:
      parse.res.of(split_at_blank(raw), closed, head)
    case LeadSkip{rest}:
      FrameBad{}

def frame.at.zero.of(+raw: String, closed: Bool, head: Bool) -> Frame:
  frame.at.zero.go(raw, closed, head, frame.lead(split_at_blank(raw)))

def frame.at.pos.do(f: Nat, +raw: String, closed: Bool, head: Bool, hb: String & String, lead: Lead) -> Frame:
  match f:
    case 0n:
      match lead:
        case LeadCut{}:
          frame.cut(closed)
        case LeadFinal{}:
          parse.res.of(hb, closed, head)
        case LeadSkip{+rest}:
          frame.at.zero.of(rest, closed, head)
    case 1n+g:
      match lead:
        case LeadCut{}:
          frame.cut(closed)
        case LeadFinal{}:
          parse.res.of(hb, closed, head)
        case LeadSkip{+rest}:
          frame.at.pos.do(g, rest, closed, head, split_at_blank(rest), frame.lead(split_at_blank(rest)))

def frame.at.zero(+raw: String, closed: Bool, head: Bool) -> Frame:
  frame.at.zero.of(raw, closed, head)

# ponytail: 8 interim responses; raise the fuel if a server sends more
def frame.at(fuel: Nat, +raw: String, closed: Bool, head: Bool) -> Frame:
  match fuel:
    case 0n:
      frame.at.zero(raw, closed, head)
    case 1n+f:
      frame.at.pos.do(f, raw, closed, head, split_at_blank(raw), frame.lead(split_at_blank(raw)))

# frame(bytes so far, server closed?, request was HEAD?)
def frame(raw: String, closed: Bool, head: Bool) -> Frame:
  frame.at(8n, raw, closed, head)

def frame.res(f: Frame) -> Maybe<&1, Res>:
  match f:
    case FrameDone{res}:
      Some{res}
    case FrameBad{}:
      None{}
    case FrameMore{}:
      None{}

def parse_res(raw: String) -> Maybe<&1, Res>:
  frame.res(frame(raw, True{}, False{}))

def res_fields.res(res: Res, k: String) -> List<&2, String>:
  Res{status, headers, body} = res
  fields(headers, k)

def res_fields(m: Maybe<&1, Res>, k: String) -> List<&2, String>:
  match m:
    case None{}:
      Nil{}
    case Some{res}:
      res_fields.res(res, k)

# The response body as it arrives. Len: bytes left. Chunk: the decoder. Close: until the
# server closes. Done: the body is whole. Bad: it cannot become a body.
type Rb is Data:
  RbLen{left: U32}
  RbChunk{st: Dc}
  RbClose{}
  RbDone{}
  RbBad{}

def rb.cl(n: Maybe<&2, U32>) -> Maybe<&2, Rb>:
  match n:
    case None{}:
      None{}
    case Some{+k}:
      Some{Bool.pick(Rb, U32.is_zero(k), RbDone{}, RbLen{k})}

def rb.te(+h: Map<&2, List<&2, String>>, cl: Bool) -> Maybe<&2, Rb>:
  match cl:
    case True{}:
      None{}
    case False{}:
      Some{Bool.pick(Rb, String.eq(String.to_lower(header.last(h, "transfer-encoding")), "chunked"), RbChunk{dc.start()}, RbClose{})}

def rb.len(+h: Map<&2, List<&2, String>>, te: Bool) -> Maybe<&2, Rb>:
  match te:
    case True{}:
      rb.te(h, has_header(h, "content-length"))
    case False{}:
      Bool.pick(Maybe<&2, Rb>, has_header(h, "content-length"), rb.cl(parse_u32(header(h, "content-length"))), Some{RbClose{}})

# RFC 9112 §6.3: how the body of this response ends. None: it cannot be framed.
def rb.of(+h: Map<&2, List<&2, String>>, nobody: Bool) -> Maybe<&2, Rb>:
  match nobody:
    case True{}:
      Some{RbDone{}}
    case False{}:
      rb.len(h, has_header(h, "transfer-encoding"))

# rb: how the body goes on. parts: body bytes so far, newest first. rest: bytes past a Done body.
type Bf is Type:
  Bf{rb: Rb, parts: List<&1, Bytes.Bytes>, rest: Bytes.Bytes}

def rb.len.cut(parts: List<&1, Bytes.Bytes>, +len: U32, +left: U32, r: Bytes.Bytes & Bytes.Bytes) -> Bf:
  (piece, data) = r
  Bf{RbDone{}, Con{data, parts}, bytes.snd(Bytes.slice(piece, left, (len - left : U32)))}

def rb.len.have(short: Bool, +left: U32, parts: List<&1, Bytes.Bytes>, +len: U32, piece: Bytes.Bytes) -> Bf:
  match short:
    case True{}:
      Bf{RbLen{(left - len : U32)}, Con{piece, parts}, Bytes.new(0)}
    case False{}:
      rb.len.cut(parts, len, left, Bytes.slice(piece, 0, left))

def rb.chunk(c: Ck) -> Bf:
  Ck{st, parts, rest} = c
  match st:
    case DcDone{}:
      Bf{RbDone{}, parts, rest}
    case DcBad{}:
      Bf{RbBad{}, parts, rest}
    case DcSize{a, b}:
      Bf{RbChunk{DcSize{a, b}}, parts, rest}
    case DcExt{x}:
      Bf{RbChunk{DcExt{x}}, parts, rest}
    case DcSizeLf{x}:
      Bf{RbChunk{DcSizeLf{x}}, parts, rest}
    case DcData{k}:
      Bf{RbChunk{DcData{k}}, parts, rest}
    case DcDataCr{}:
      Bf{RbChunk{DcDataCr{}}, parts, rest}
    case DcDataLf{}:
      Bf{RbChunk{DcDataLf{}}, parts, rest}
    case DcTr{j}:
      Bf{RbChunk{DcTr{j}}, parts, rest}

# The body bytes in piece, added to parts.
def rb.feed(rb: Rb, parts: List<&1, Bytes.Bytes>, piece: Bytes.Bytes) -> Bf:
  match rb:
    case RbLen{+left}:
      Bytes.Bytes{+len, buf} = piece
      rb.len.have(U32.is_lt(len, left), left, parts, len, Bytes.Bytes{len, buf})
    case RbChunk{st}:
      rb.chunk(ck(piece, st, parts))
    case RbClose{}:
      Bf{RbClose{}, Con{piece, parts}, Bytes.new(0)}
    case RbDone{}:
      Bf{RbDone{}, parts, piece}
    case RbBad{}:
      Bf{RbBad{}, parts, piece}

# RFC 9112 §8: only a close-delimited body may end at close.
def rb.eof(rb: Rb) -> Bool:
  match rb:
    case RbClose{}:
      True{}
    case RbDone{}:
      True{}
    case RbLen{n}:
      False{}
    case RbChunk{st}:
      False{}
    case RbBad{}:
      False{}

def rb.body(parts: List<&1, Bytes.Bytes>) -> Bytes.Bytes:
  Bytes.concat(List.reverse(&1, Bytes.Bytes, parts))

# The head scan. Seek: look for the blank line from byte from; k interim heads are behind.
# Wait: no blank line yet. Res: the final head, how its body ends, and the bytes after it.
type Hs is Type:
  HsSeek{buf: Bytes.Bytes, from: U32, k: U32}
  HsWait{buf: Bytes.Bytes, k: U32}
  HsBad{}
  HsRes{res: Res, rb: Rb, rest: Bytes.Bytes}

def hs.final(+status: U32, +h: Map<&2, List<&2, String>>, rest: Bytes.Bytes, m: Maybe<&2, Rb>) -> Hs:
  match m:
    case None{}:
      HsBad{}
    case Some{rb}:
      HsRes{Res{status, h, Bytes.new(0)}, rb, rest}

def hs.skip(more: Bool, +k: U32, rest: Bytes.Bytes) -> Hs:
  match more:
    case True{}:
      HsSeek{rest, 0, (k + 1 : U32)}
    case False{}:
      HsBad{}

def hs.pick(interim: Bool, +head: Bool, +k: U32, +status: U32, +h: Map<&2, List<&2, String>>, rest: Bytes.Bytes) -> Hs:
  match interim:
    case True{}:
      hs.skip(U32.is_lt(k, 8), k, rest)
    case False{}:
      hs.final(status, h, rest, rb.of(h, frame.nobody(status, head)))

def hs.res(+head: Bool, +k: U32, rest: Bytes.Bytes, res: Res) -> Hs:
  Res{+status, +h, body} = res
  hs.pick(frame.interim(status), head, k, status, h, rest)

# The head alone, framed as a HEAD response so it stops at the blank line.
def hs.parsed(+head: Bool, +k: U32, rest: Bytes.Bytes, f: Frame) -> Hs:
  match f:
    case FrameDone{res}:
      hs.res(head, k, rest, res)
    case FrameBad{}:
      HsBad{}
    case FrameMore{}:
      HsBad{}

def hs.split(+head: Bool, +k: U32, +hlen: U32, +len: U32, r: Bytes.Bytes & Bytes.Bytes) -> Hs:
  (buf, hb) = r
  hs.parsed(head, k, bytes.snd(Bytes.slice(buf, hlen, (len - hlen : U32))), parse.res.of(split_at_blank(Bytes.to_string(hb)), False{}, True{}))

def hs.hit(+head: Bool, +k: U32, +len: U32, buf: Bytes.Bytes, at: Maybe<&2, U32>) -> Hs:
  match at:
    case None{}:
      HsWait{buf, k}
    case Some{+i}:
      +hlen = (i + 4 : U32)
      hs.split(head, k, hlen, len, Bytes.slice(buf, 0, hlen))

def hs.seek.of(+head: Bool, +k: U32, +len: U32, +from: U32, buf: Bytes.Bytes, r: Bytes.Bytes & Maybe<&2, U32>) -> Hs:
  (tail, m) = r
  hs.hit(head, k, len, buf, found.at(from, m))

def hs.seek(+head: Bool, +k: U32, +len: U32, +from: U32, r: Bytes.Bytes & Bytes.Bytes) -> Hs:
  (buf, tail) = r
  hs.seek.of(head, k, len, from, buf, Bytes.find(tail, "\r\n\r\n"))

def hs.step(+head: Bool, st: Hs) -> Hs:
  match st:
    case HsSeek{buf, +from, +k}:
      Bytes.Bytes{+len, b} = buf
      hs.seek(head, k, len, from, Bytes.slice(Bytes.Bytes{len, b}, from, (len - from : U32)))
    case HsWait{buf, k}:
      HsWait{buf, k}
    case HsBad{}:
      HsBad{}
    case HsRes{res, rb, rest}:
      HsRes{res, rb, rest}

# Each step ends the scan or passes one interim head, and at most 8 interim heads pass.
def hs.scan(fuel: Nat, +head: Bool, st: Hs) -> Hs:
  match fuel:
    case 0n:
      match st:
        case HsSeek{buf, from, k}:
          HsBad{}
        case HsWait{buf, k}:
          HsWait{buf, k}
        case HsBad{}:
          HsBad{}
        case HsRes{res, rb, rest}:
          HsRes{res, rb, rest}
    case 1n+f:
      hs.scan(f, head, hs.step(head, st))

# piece joins buf; only the new bytes, and the 3 before them, can finish the blank line.
def hs.more(+head: Bool, +k: U32, buf: Bytes.Bytes, piece: Bytes.Bytes) -> Hs:
  Bytes.Bytes{+ol, ob} = buf
  hs.scan(10n, head, HsSeek{Bytes.append(Bytes.Bytes{ol, ob}, piece), Bool.pick(U32, U32.is_lt(ol, 3), 0, (ol - 3 : U32)), k})

# Untrusted servers must not grow the buffer without bound.
def fetch.max() -> Nat:
  U32.to_nat(16777216)

# A response read in pieces. Head: the head is not whole yet. Body: it is, and parts is the body so far.
# Len: a Content-Length body in one buffer of that size, with left bytes still to come.
type Rv is Type:
  RvHead{buf: Bytes.Bytes, k: U32}
  RvBody{res: Res, rb: Rb, parts: List<&1, Bytes.Bytes>}
  RvLen{res: Res, left: U32, body: Bytes.Bytes}

# More: read on. Done: the response, and the bytes after it when the body is self-delimited.
type Rt is Type:
  RtMore{rv: Rv}
  RtBad{}
  RtDone{res: Res, rest: Maybe<&1, Bytes.Bytes>}

def rv.start() -> Rv:
  RvHead{Bytes.new(0), 0}

def rv.whole(res: Res, b: Bytes.Bytes, rest: Maybe<&1, Bytes.Bytes>) -> Rt:
  Res{status, headers, body} = res
  RtDone{Res{status, headers, b}, rest}

def rv.done(res: Res, parts: List<&1, Bytes.Bytes>, rest: Maybe<&1, Bytes.Bytes>) -> Rt:
  rv.whole(res, rb.body(parts), rest)

def rl.put.of(+total: U32, +len: U32, r: Array<U32> & Array<U32>) -> Bytes.Bytes & Bytes.Bytes:
  (src, dst) = r
  (Bytes.Bytes{total, dst}, Bytes.Bytes{len, src})

# The first m bytes of piece, written into body after the total - left bytes already there.
def rl.put(+m: U32, +left: U32, body: Bytes.Bytes, piece: Bytes.Bytes) -> Bytes.Bytes & Bytes.Bytes:
  Bytes.Bytes{+total, dst} = body
  Bytes.Bytes{+len, src} = piece
  rl.put.of(total, len, Bytes.copy(m, src, dst, 0, (total - left : U32)))

def rl.fed(short: Bool, res: Res, +left: U32, +len: U32, r: Bytes.Bytes & Bytes.Bytes) -> Rt:
  match short:
    case True{}:
      (body, piece) = r
      RtMore{RvLen{res, (left - len : U32), body}}
    case False{}:
      (body, piece) = r
      rv.whole(res, body, Some{bytes.snd(Bytes.slice(piece, left, (len - left : U32)))})

def rl.feed(res: Res, +left: U32, body: Bytes.Bytes, piece: Bytes.Bytes) -> Rt:
  Bytes.Bytes{+len, buf} = piece
  rl.fed(U32.is_lt(len, left), res, left, len, rl.put(U32.min(len, left), left, body, Bytes.Bytes{len, buf}))

def rv.fed(res: Res, bf: Bf) -> Rt:
  Bf{rb, parts, rest} = bf
  match rb:
    case RbDone{}:
      rv.done(res, parts, Some{rest})
    case RbBad{}:
      RtBad{}
    case RbLen{n}:
      RtMore{RvBody{res, RbLen{n}, parts}}
    case RbChunk{st}:
      RtMore{RvBody{res, RbChunk{st}, parts}}
    case RbClose{}:
      RtMore{RvBody{res, RbClose{}, parts}}

# Some{left}: a Content-Length body small enough to allocate up front. Larger ones fail at the fetch cap.
def rb.buf(rb: Rb) -> Maybe<&2, U32>:
  match rb:
    case RbLen{+left}:
      Bool.pick(Maybe<&2, U32>, Nat.is_lt(fetch.max(), U32.to_nat(left)), None{}, Some{left})
    case RbChunk{st}:
      None{}
    case RbClose{}:
      None{}
    case RbDone{}:
      None{}
    case RbBad{}:
      None{}

def rv.body(m: Maybe<&2, U32>, res: Res, rb: Rb, rest: Bytes.Bytes) -> Rt:
  match m:
    case None{}:
      rv.fed(res, rb.feed(rb, Nil{}, rest))
    case Some{+left}:
      rl.feed(res, left, Bytes.new(left), rest)

def rv.head(hs: Hs) -> Rt:
  match hs:
    case HsWait{buf, k}:
      RtMore{RvHead{buf, k}}
    case HsBad{}:
      RtBad{}
    case HsSeek{buf, from, k}:
      RtBad{}
    case HsRes{res, +rb, rest}:
      rv.body(rb.buf(rb), res, rb, rest)

def rv.eof(res: Res, parts: List<&1, Bytes.Bytes>, ok: Bool) -> Rt:
  match ok:
    case True{}:
      rv.done(res, parts, None{})
    case False{}:
      RtBad{}

# One read: piece, or the server closed (RFC 9112 §8: a message cut short is not a message).
def rv.step(closed: Bool, +head: Bool, rv: Rv, piece: Bytes.Bytes) -> Rt:
  match closed:
    case True{}:
      match rv:
        case RvHead{buf, k}:
          RtBad{}
        case RvBody{res, rb, parts}:
          rv.eof(res, parts, rb.eof(rb))
        case RvLen{res, left, body}:
          RtBad{}
    case False{}:
      match rv:
        case RvHead{buf, +k}:
          rv.head(hs.more(head, k, buf, piece))
        case RvBody{res, rb, parts}:
          rv.fed(res, rb.feed(rb, parts, piece))
        case RvLen{res, +left, body}:
          rl.feed(res, left, body, piece)

def rv.end(closed: Bool, +head: Bool, t: Rt) -> Rt:
  match closed:
    case False{}:
      t
    case True{}:
      match t:
        case RtMore{rv}:
          rv.step(True{}, head, rv, Bytes.new(0))
        case RtBad{}:
          RtBad{}
        case RtDone{res, rest}:
          RtDone{res, rest}

def rv.go(xs: List<&2, String>, closed: Bool, +head: Bool, t: Rt) -> Rt:
  match xs:
    case Nil{}:
      rv.end(closed, head, t)
    case Con{+x, rest}:
      match t:
        case RtMore{rv}:
          rv.go(rest, closed, head, rv.step(False{}, head, rv, Bytes.from_string(x)))
        case RtBad{}:
          RtBad{}
        case RtDone{res, r}:
          RtDone{res, r}

def rt.frame(t: Rt) -> Frame:
  match t:
    case RtMore{rv}:
      FrameMore{}
    case RtBad{}:
      FrameBad{}
    case RtDone{res, rest}:
      FrameDone{res}

# What the read loop makes of these pieces, then a close when closed is set.
def res.frame(xs: List<&2, String>, closed: Bool, +head: Bool) -> Frame:
  rt.frame(rv.go(xs, closed, head, RtMore{rv.start()}))

def rt.rest(t: Rt) -> Maybe<&1, Bytes.Bytes>:
  match t:
    case RtMore{rv}:
      None{}
    case RtBad{}:
      None{}
    case RtDone{res, rest}:
      rest

def after.of(m: Maybe<&1, Bytes.Bytes>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      Some{Bytes.to_string(b)}

# Bytes after a complete self-delimited message. None if it is not one yet.
def after(+raw: String, +head: Bool) -> Maybe<&2, String>:
  after.of(rt.rest(rv.go([raw], False{}, head, RtMore{rv.start()})))

def req.v11.ver(mpv: String & String & String) -> Bool:
  (+method, path, v) = mpv
  String.eq(v, "HTTP/1.1")

def req.v11.line(+line: String) -> Bool:
  req.v11.ver(start_line(line))

def req.v11.lines(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{line, headers}:
      req.v11.line(line)

def req.v11.pick(+head: String, ok: Bool) -> Bool:
  match ok:
    case False{}:
      False{}
    case True{}:
      req.v11.lines(String.lines(head))

def req.v11.of(hb: String & String) -> Bool:
  (+head, rest) = hb
  req.v11.pick(head, blank_end(head))

def req.v11(+raw: String) -> Bool:
  req.v11.of(split_at_blank(raw))

def req.conn_close(+headers: Map<&2, List<&2, String>>) -> Bool:
  String.eq(String.to_lower(header(headers, "connection")), "close")

def res.conn_close(+headers: Map<&2, List<&2, String>>) -> Bool:
  String.eq(String.to_lower(header(headers, "connection")), "close")

def serve.fail_close(+status: U32) -> Bool:
  Bool.or(U32.is_eq(status, 400), Bool.or(U32.is_eq(status, 413), U32.is_eq(status, 431)))

def serve.keep.ok(fail: Bool, res_close: Bool) -> Bool:
  match fail:
    case True{}:
      False{}
    case False{}:
      Bool.not(res_close)

def serve.keep.v11(v11: Bool, +req_close: Bool, +status: U32, res_close: Bool) -> Bool:
  match v11:
    case False{}:
      False{}
    case True{}:
      match req_close:
        case True{}:
          False{}
        case False{}:
          serve.keep.ok(serve.fail_close(status), res_close)

def serve.keep(+headers: Map<&2, List<&2, String>>, v11: Bool, +status: U32, +res: Map<&2, List<&2, String>>) -> Bool:
  serve.keep.v11(v11, req.conn_close(headers), status, res.conn_close(res))


def again.keep(close: Bool, x: Bytes.Bytes) -> Maybe<&1, Bytes.Bytes>:
  match close:
    case True{}:
      None{}
    case False{}:
      Some{x}

def again.rest(close: Bool, rest: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match rest:
    case None{}:
      None{}
    case Some{x}:
      again.keep(close, x)

# The bytes past the response when the socket can take another request: the request did not
# ask to close, the response is self-delimited, and the peer did not say close.
def again(close: Bool, +h: Map<&2, List<&2, String>>, rest: Maybe<&1, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match close:
    case True{}:
      None{}
    case False{}:
      again.rest(String.eq(String.to_lower(header(h, "connection")), "close"), rest)

def res_body.res(res: Res) -> Bytes.Bytes:
  Res{status, headers, body} = res
  body

def res_body(m: Maybe<&1, Res>) -> Bytes.Bytes:
  match m:
    case None{}:
      Bytes.new(0)
    case Some{res}:
      res_body.res(res)

def text(res: Res) -> String:
  Enc.utf8.decode(res_body.res(res))

# UTF-8 is checked, not repaired: bad UTF-8 in a string gives None (RFC 8259 §8.1).
def json(res: Res) -> Maybe<&1, Json.Val>:
  Json.parse.bytes(res_body.res(res))

def got_body.req(req: Req) -> Bytes.Bytes:
  Req{method, path, headers, body} = req
  body

def got_body(m: Maybe<&1, Req>) -> Bytes.Bytes:
  match m:
    case None{}:
      Bytes.new(0)
    case Some{req}:
      got_body.req(req)

def body.of(hb: String & String) -> String:
  (h, b) = hb
  b

def body(s: String) -> String:
  body.of(split_at_blank.go(s, False{}, 0, SNil{}))

def headers_lines(+k: String, vs: List<&2, String>, acc: String) -> String:
  match vs:
    case Nil{}:
      acc
    case Con{v, t}:
      headers_lines(k, t, acc ++ ("\r\n" ++ sanitize(k) ++ ": " ++ sanitize(v)))

def headers_block.go(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case (k, vs) <> t:
      headers_block.go(t, headers_lines(k, vs, acc))

def headers_block(h: Map<&2, List<&2, String>>) -> String:
  headers_block.go(Map.to_list(&2, List<&2, String>, h), "")

# RFC 9110 §15. An unknown code gets an empty reason, which RFC 9112 §4 allows.
type Reason is Data:
  Reason{code: U32, text: String}

def reasons() -> List<&2, Reason>:
  [Reason{100, "Continue"}, Reason{101, "Switching Protocols"}, Reason{103, "Early Hints"},
   Reason{200, "OK"}, Reason{201, "Created"}, Reason{202, "Accepted"}, Reason{203, "Non-Authoritative Information"}, Reason{204, "No Content"}, Reason{205, "Reset Content"}, Reason{206, "Partial Content"},
   Reason{300, "Multiple Choices"}, Reason{301, "Moved Permanently"}, Reason{302, "Found"}, Reason{303, "See Other"}, Reason{304, "Not Modified"}, Reason{307, "Temporary Redirect"}, Reason{308, "Permanent Redirect"},
   Reason{400, "Bad Request"}, Reason{401, "Unauthorized"}, Reason{402, "Payment Required"}, Reason{403, "Forbidden"}, Reason{404, "Not Found"}, Reason{405, "Method Not Allowed"}, Reason{406, "Not Acceptable"}, Reason{407, "Proxy Authentication Required"}, Reason{408, "Request Timeout"}, Reason{409, "Conflict"}, Reason{410, "Gone"}, Reason{411, "Length Required"}, Reason{412, "Precondition Failed"}, Reason{413, "Content Too Large"}, Reason{414, "URI Too Long"}, Reason{415, "Unsupported Media Type"}, Reason{416, "Range Not Satisfiable"}, Reason{417, "Expectation Failed"}, Reason{421, "Misdirected Request"}, Reason{422, "Unprocessable Content"}, Reason{426, "Upgrade Required"}, Reason{428, "Precondition Required"}, Reason{429, "Too Many Requests"}, Reason{431, "Request Header Fields Too Large"},
   Reason{500, "Internal Server Error"}, Reason{501, "Not Implemented"}, Reason{502, "Bad Gateway"}, Reason{503, "Service Unavailable"}, Reason{504, "Gateway Timeout"}, Reason{505, "HTTP Version Not Supported"}]

def reason.go(xs: List<&2, Reason>, +status: U32) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{Reason{k, v}, t}:
      Bool.pick(String, U32.is_eq(k, status), v, reason.go(t, status))

def reason(+status: U32) -> String:
  reason.go(reasons(), status)

def response(+status: U32, headers: Map<&2, List<&2, String>>, body: String) -> String:
  ("HTTP/1.1 " ++ U32.show(status) ++ " " ++ reason(status) ++ headers_block(headers)) ++ ("\r\n\r\n" ++ body)

def encode.body(head: Bool, top: Bytes.Bytes, body: Bytes.Bytes) -> Bytes.Bytes:
  match head:
    case True{}:
      top
    case False{}:
      Bytes.append(top, body)

def encode.len(+status: U32, headers: Map<&2, List<&2, String>>, head: Bool, body: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = body
  encode.body(head, Bytes.from_string(response(status, set(headers, "content-length", U32.show(len)), "")), Bytes.Bytes{len, buf})

# RFC 9110 §6.4.1, §8.6: 1xx, 204 and 304 have no body; HEAD gets the length but no body.
def encode.pick(+status: U32, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, head: Bool, nobody: Bool) -> Bytes.Bytes:
  match nobody:
    case True{}:
      Bytes.from_string(response(status, headers, ""))
    case False{}:
      encode.len(status, headers, head, body)

def encode.on(r: Res, head: Bool) -> Bytes.Bytes:
  Res{+status, headers, body} = r
  encode.pick(status, headers, body, head, frame.nobody(status, False{}))

def encode(r: Res) -> Bytes.Bytes:
  encode.on(r, False{})

def request(method: String, path: String, headers: Map<&2, List<&2, String>>, body: String) -> String:
  (method ++ " " ++ path ++ " HTTP/1.1" ++ headers_block(headers)) ++ ("\r\n\r\n" ++ body)

def req.reserved(+k: String) -> Bool:
  Bool.or(Bool.or(String.eq(k, "host"), String.eq(k, "connection")), Bool.or(String.eq(k, "content-length"), String.eq(k, "transfer-encoding")))

def req.put.one(m: Map<&2, List<&2, String>>, +k: String, vs: List<&2, String>, skip: Bool) -> Map<&2, List<&2, String>>:
  match skip:
    case True{}:
      m
    case False{}:
      Map.set(&2, List<&2, String>, m, k, vs)

def req.put(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>, m: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match xs:
    case Nil{}:
      m
    case (k, vs) <> t:
      +lk = String.to_lower(k)
      req.put(t, req.put.one(m, lk, vs, req.reserved(lk)))

# RFC 9110 §8.6: no Content-Length on a bodiless request whose method gives a body no meaning.
def req.cl(+m: Map<&2, List<&2, String>>, +method: String, +len: U32) -> Map<&2, List<&2, String>>:
  +bodied = Bool.or(Bool.not(U32.is_zero(len)), Bool.or(String.eq(method, "POST"), Bool.or(String.eq(method, "PUT"), String.eq(method, "PATCH"))))
  Bool.pick(Map<&2, List<&2, String>>, bodied, set(m, "content-length", U32.show(len)), m)

# Caller headers are lowercased so they cannot duplicate ours; host, connection,
# content-length and transfer-encoding are always ours (no smuggling through them).
def encode_req.word(close: Bool) -> String:
  match close:
    case True{}:
      "close"
    case False{}:
      "keep-alive"

def encode_req.on(+method: String, target: String, host: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, close: Bool) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = body
  +h = set(set(req.put(Map.to_list(&2, List<&2, String>, headers), empty()), "host", host), "connection", encode_req.word(close))
  Bytes.append(Bytes.from_string(request(method, target, req.cl(h, method, len), "")), Bytes.Bytes{len, buf})

def encode_req(+method: String, target: String, host: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> Bytes.Bytes:
  encode_req.on(method, target, host, headers, body, True{})

# Redirects (RFC 9110 §15.4, as WHATWG fetch applies them)
# --------------------------------------------------------

# One request to make: headers are already lowercased (see req.put).
type Hop is Type:
  Hop{method: String, url: Url.Abs, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

def redirect.code(+s: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(s, 301), U32.is_eq(s, 302)), Bool.or(U32.is_eq(s, 303), Bool.or(U32.is_eq(s, 307), U32.is_eq(s, 308))))

def redirect.origin(a: Url.Abs) -> String:
  Url.Abs{scheme, host, port, target} = a
  scheme ++ "://" ++ host ++ ":" ++ U32.show(port)

def redirect.del(ks: List<&2, String>, m: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match ks:
    case Nil{}:
      m
    case Con{k, t}:
      redirect.del(t, Map.del(&2, List<&2, String>, m, k))

def redirect.hdrs(+h: Map<&2, List<&2, String>>, drop: Bool, cross: Bool) -> Map<&2, List<&2, String>>:
  +h2 = Bool.pick(Map<&2, List<&2, String>>, drop, redirect.del(["content-type", "content-encoding", "content-language", "content-location"], h), h)
  Bool.pick(Map<&2, List<&2, String>>, cross, redirect.del(["authorization", "cookie", "proxy-authorization"], h2), h2)

# 303 turns any method but HEAD into GET; 301 and 302 turn POST into GET;
# 307 and 308 keep method and body. A GET carries no body or body headers.
# Credentials do not follow a hop to another origin.
def redirect.body(drop: Bool, body: Bytes.Bytes) -> Bytes.Bytes:
  match drop:
    case True{}:
      Bytes.new(0)
    case False{}:
      body

def redirect.to(+status: U32, +method: String, +from: Url.Abs, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, next: Maybe<&2, Url.Abs>) -> Maybe<&1, Hop>:
  match next:
    case None{}:
      None{}
    case Some{+to}:
      +drop = Bool.or(Bool.and(U32.is_eq(status, 303), Bool.not(String.eq(method, "HEAD"))), Bool.and(Bool.or(U32.is_eq(status, 301), U32.is_eq(status, 302)), String.eq(method, "POST")))
      Some{Hop{Bool.pick(String, drop, "GET", method), to, redirect.hdrs(headers, drop, Bool.not(String.eq(redirect.origin(from), redirect.origin(to)))), redirect.body(drop, body)}}

def redirect.hop(status: U32, h: Hop, loc: String) -> Maybe<&1, Hop>:
  Hop{method, +url, headers, body} = h
  redirect.to(status, method, url, headers, body, Url.resolve(url, loc))

def redirect.if(status: U32, h: Hop, loc: String, ok: Bool) -> Maybe<&1, Hop>:
  match ok:
    case False{}:
      None{}
    case True{}:
      redirect.hop(status, h, loc)

# The next request after a response, or None when it is not a redirect we follow.
def redirect(+status: U32, +headers: Map<&2, List<&2, String>>, h: Hop) -> Maybe<&1, Hop>:
  redirect.if(status, h, header(headers, "location"), Bool.and(redirect.code(status), has_header(headers, "location")))

# Cookies (RFC 6265bis §5)
# ------------------------

# A stored cookie. domain is lowercase, with no leading dot; host_only sends it to that host alone.
# expiry None is a session cookie. http_only and same_site ("strict", "lax", "none" or "default")
# are kept, not enforced: fetch has no browsing client, so its requests are same-site (§5.2).
type Cookie is Data:
  Cookie{name: String, value: String, domain: String, host_only: Bool, path: String, secure: Bool, http_only: Bool, same_site: String, expiry: Maybe<&2, Time.Instant>}

# The cookies, oldest first, and the caller's clock. No cookie in it has expired by now.
type Jar is Data:
  Jar{now: Time.Instant, cookies: List<&2, Cookie>}

def jar.new(now: Time.Instant) -> Jar:
  Jar{now, Nil{}}

def jar.cookies(j: Jar) -> List<&2, Cookie>:
  Jar{now, cs} = j
  cs

def cookie.live.at(+now: Time.Instant, e: Maybe<&2, Time.Instant>) -> Bool:
  match e:
    case None{}:
      True{}
    case Some{t}:
      Cmp.is_lt(Time.Instant.cmp(now, t))

# Alive at now: no expiry, or an expiry after now.
def cookie.live(+now: Time.Instant, c: Cookie) -> Bool:
  Cookie{name, value, domain, host_only, path, secure, http_only, same_site, expiry} = c
  cookie.live.at(now, expiry)

def jar.live(cs: List<&2, Cookie>, +now: Time.Instant) -> List<&2, Cookie>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{+c, t}:
      List.filter.put(Cookie, c, jar.live(t, now), cookie.live(now, c))

# The jar at a later time: cookies expired by now are evicted (§5.7).
def jar.at(j: Jar, +now: Time.Instant) -> Jar:
  Jar{old, cs} = j
  Jar{now, jar.live(cs, now)}

def cookie.cut.found(r: String & String) -> String & String & Bool:
  (a, b) = r
  (a, b, True{})

# hit: the last char pushed onto acc was c.
def cookie.cut.go(s: String, +c: U32, acc: String, hit: Bool) -> String & String & Bool:
  match s:
    case SNil{}:
      match hit:
        case True{}:
          cookie.cut.found(take.cut(acc, SNil{}))
        case False{}:
          (String.reverse(acc), SNil{}, False{})
    case SCon{Chr{+x}, t}:
      match hit:
        case True{}:
          cookie.cut.found(take.cut(acc, SCon{Chr{x}, t}))
        case False{}:
          cookie.cut.go(t, c, SCon{Chr{x}, acc}, U32.is_eq(x, c))

# s split at its first c: before, after, and whether c was there.
def cookie.cut(s: String, +c: U32) -> String & String & Bool:
  cookie.cut.go(s, c, SNil{}, False{})

def cookie.fst(r: String & String & Bool) -> String:
  (a, b, found) = r
  a

# The path of an origin-form target: the part before "?".
def cookie.target_path(t: String) -> String:
  cookie.fst(cookie.cut(t, 63))

# Longer than n octets.
def cookie.over(s: String, +n: U32) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{c, t}:
      Bool.or(U32.is_eq(n, 0), cookie.over(t, (n - 1 : U32)))

# %x00-08 / %x0A-1F / %x7F: control characters other than HTAB.
def cookie.ctl(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.or(Bool.or(U32.is_lt(c, 9), Bool.and(U32.is_gt(c, 9), U32.is_lt(c, 32))), Bool.or(U32.is_eq(c, 127), cookie.ctl(t)))

def cookie.ascii(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(U32.is_lt(c, 128), cookie.ascii(t))

def cookie.ip4(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(parse_u32.digit(c), U32.is_eq(c, 46)), cookie.ip4(t))

# An IP literal rather than a host name: IPv6 has a colon, IPv4 is digits and dots.
def cookie.ip(+h: String) -> Bool:
  Bool.or(String.contains(h, ":"), cookie.ip4(h))

# §5.1.3: s is d, or a host name under d on a label boundary.
def cookie.domain_match(+s: String, +d: String) -> Bool:
  Bool.or(String.eq(s, d), Bool.and(String.ends_with(s, "." ++ d), Bool.not(cookie.ip(s))))

# A reversed path with its last segment and slash dropped.
def cookie.up(rs: String) -> String:
  match rs:
    case SNil{}:
      SNil{}
    case SCon{Chr{47}, t}:
      t
    case SCon{Chr{c}, t}:
      cookie.up(t)

# §5.1.4: the request path up to its last "/", or "/".
def cookie.default_path(+p: String) -> String:
  +up = String.reverse(cookie.up(String.reverse(p)))
  Bool.pick(String, Bool.or(Bool.not(String.starts_with(p, "/")), String.is_empty(up)), "/", up)

# §5.1.4: request path p path-matches cookie path c.
def cookie.path_match(+p: String, +c: String) -> Bool:
  Bool.or(String.eq(p, c), Bool.and(String.starts_with(p, c), Bool.or(String.ends_with(c, "/"), String.starts_with(String.drop(p, String.length(c)), "/"))))

type Hms is Data:
  Hms{h: U32, m: U32, s: U32}

# §5.1.1 cookie-date: the first time, day, month and year tokens found.
type Cdate is Data:
  Cdate{time: Maybe<&2, Hms>, day: Maybe<&2, U32>, month: Maybe<&2, U32>, year: Maybe<&2, U32>}

def cookie.date.delim(+c: U32) -> Bool:
  Bool.or(U32.is_eq(c, 9), Bool.or(Bool.and(U32.is_ge(c, 32), U32.is_le(c, 47)), Bool.or(Bool.and(U32.is_ge(c, 59), U32.is_le(c, 64)), Bool.or(Bool.and(U32.is_ge(c, 91), U32.is_le(c, 96)), Bool.and(U32.is_ge(c, 123), U32.is_le(c, 126))))))

def cookie.date.push(acc: String, ts: List<&2, String>) -> List<&2, String>:
  match acc:
    case SNil{}:
      ts
    case SCon{h, t}:
      Con{String.reverse(SCon{h, t}), ts}

def cookie.date.step(d: Bool, +c: U32, acc: String, ts: List<&2, String>) -> String & List<&2, String>:
  match d:
    case True{}:
      (SNil{}, cookie.date.push(acc, ts))
    case False{}:
      (SCon{Chr{c}, acc}, ts)

# The date-tokens, last first. st: the token so far (reversed) and the tokens before it.
def cookie.date.tokens(s: String, st: String & List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      (acc, ts) = st
      cookie.date.push(acc, ts)
    case SCon{Chr{+c}, t}:
      (acc, ts) = st
      cookie.date.tokens(t, cookie.date.step(cookie.date.delim(c), c, acc, ts))

def cookie.date.head(+s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      parse_u32.digit(c)

# The digits at the start of s: (count, value, rest). d: s starts with a digit.
def cookie.date.run(s: String, d: Bool, +n: U32, +acc: U32) -> U32 & U32 & String:
  match s:
    case SNil{}:
      (n, acc, SNil{})
    case SCon{Chr{+c}, +t}:
      match d:
        case True{}:
          cookie.date.run(t, cookie.date.head(t), (n + 1 : U32), (acc * 10 + (c - 48 : U32) : U32))
        case False{}:
          (n, acc, SCon{Chr{c}, t})

def cookie.date.within(r: U32 & U32 & String, +lo: U32, +hi: U32) -> Maybe<&1, U32 & String>:
  (+n, v, rest) = r
  Bool.pick(Maybe<&1, U32 & String>, Bool.and(U32.is_ge(n, lo), U32.is_le(n, hi)), Some{(v, rest)}, None{})

# lo to hi digits and what follows them, which does not start with a digit.
def cookie.date.num(+s: String, +lo: U32, +hi: U32) -> Maybe<&1, U32 & String>:
  cookie.date.within(cookie.date.run(s, cookie.date.head(s), 0, 0), lo, hi)

def cookie.date.val(m: Maybe<&1, U32 & String>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{(v, t)}:
      Some{v}

def cookie.date.colon(s: String) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{58}, t}:
      Some{t}
    case SCon{Chr{c}, t}:
      None{}

def cookie.date.sec(+h: U32, +m: U32, r: Maybe<&1, U32 & String>) -> Maybe<&2, Hms>:
  match r:
    case None{}:
      None{}
    case Some{(s, t)}:
      Some{Hms{h, m, s}}

def cookie.date.min.c(+h: U32, +m: U32, c: Maybe<&2, String>) -> Maybe<&2, Hms>:
  match c:
    case None{}:
      None{}
    case Some{+t}:
      cookie.date.sec(h, m, cookie.date.num(t, 1, 2))

def cookie.date.min(+h: U32, r: Maybe<&1, U32 & String>) -> Maybe<&2, Hms>:
  match r:
    case None{}:
      None{}
    case Some{(m, t)}:
      cookie.date.min.c(h, m, cookie.date.colon(t))

def cookie.date.hour.c(+h: U32, c: Maybe<&2, String>) -> Maybe<&2, Hms>:
  match c:
    case None{}:
      None{}
    case Some{+t}:
      cookie.date.min(h, cookie.date.num(t, 1, 2))

def cookie.date.hour(r: Maybe<&1, U32 & String>) -> Maybe<&2, Hms>:
  match r:
    case None{}:
      None{}
    case Some{(h, t)}:
      cookie.date.hour.c(h, cookie.date.colon(t))

# hms-time: 1*2DIGIT ":" 1*2DIGIT ":" 1*2DIGIT, then anything but a digit.
def cookie.date.time(+tok: String) -> Maybe<&2, Hms>:
  cookie.date.hour(cookie.date.num(tok, 1, 2))

def cookie.date.month.go(xs: List<&2, String>, +w: String, +i: U32) -> Maybe<&2, U32>:
  match xs:
    case Nil{}:
      None{}
    case Con{x, t}:
      Bool.pick(Maybe<&2, U32>, String.eq(x, w), Some{i}, cookie.date.month.go(t, w, (i + 1 : U32)))

# The month named by the first three letters, from 1.
def cookie.date.month(+tok: String) -> Maybe<&2, U32>:
  cookie.date.month.go(["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"], String.to_lower(String.take(tok, 3n)), 1)

# Each try* below: the flag is set, so go on; or the token matches, so stop; or go on.
def cookie.date.year(y: Maybe<&2, U32>, +tok: String, t: Maybe<&2, Hms>, d: Maybe<&2, U32>, m: Maybe<&2, U32>) -> Cdate:
  match y:
    case None{}:
      Cdate{t, d, m, cookie.date.val(cookie.date.num(tok, 2, 4))}
    case Some{v}:
      Cdate{t, d, m, Some{v}}

def cookie.date.month.got(g: Maybe<&2, U32>, +tok: String, t: Maybe<&2, Hms>, d: Maybe<&2, U32>, y: Maybe<&2, U32>) -> Cdate:
  match g:
    case None{}:
      cookie.date.year(y, tok, t, d, None{})
    case Some{v}:
      Cdate{t, d, Some{v}, y}

def cookie.date.month.try(m: Maybe<&2, U32>, +tok: String, t: Maybe<&2, Hms>, d: Maybe<&2, U32>, y: Maybe<&2, U32>) -> Cdate:
  match m:
    case None{}:
      cookie.date.month.got(cookie.date.month(tok), tok, t, d, y)
    case Some{v}:
      cookie.date.year(y, tok, t, d, Some{v})

def cookie.date.day.got(g: Maybe<&2, U32>, +tok: String, t: Maybe<&2, Hms>, m: Maybe<&2, U32>, y: Maybe<&2, U32>) -> Cdate:
  match g:
    case None{}:
      cookie.date.month.try(m, tok, t, None{}, y)
    case Some{v}:
      Cdate{t, Some{v}, m, y}

def cookie.date.day.try(d: Maybe<&2, U32>, +tok: String, t: Maybe<&2, Hms>, m: Maybe<&2, U32>, y: Maybe<&2, U32>) -> Cdate:
  match d:
    case None{}:
      cookie.date.day.got(cookie.date.val(cookie.date.num(tok, 1, 2)), tok, t, m, y)
    case Some{v}:
      cookie.date.month.try(m, tok, t, Some{v}, y)

def cookie.date.time.got(g: Maybe<&2, Hms>, +tok: String, d: Maybe<&2, U32>, m: Maybe<&2, U32>, y: Maybe<&2, U32>) -> Cdate:
  match g:
    case None{}:
      cookie.date.day.try(d, tok, None{}, m, y)
    case Some{v}:
      Cdate{Some{v}, d, m, y}

def cookie.date.time.try(t: Maybe<&2, Hms>, +tok: String, d: Maybe<&2, U32>, m: Maybe<&2, U32>, y: Maybe<&2, U32>) -> Cdate:
  match t:
    case None{}:
      cookie.date.time.got(cookie.date.time(tok), tok, d, m, y)
    case Some{v}:
      cookie.date.day.try(d, tok, Some{v}, m, y)

def cookie.date.fold(ts: List<&2, String>, st: Cdate) -> Cdate:
  match ts:
    case Nil{}:
      st
    case Con{+tok, rest}:
      Cdate{t, d, m, y} = st
      cookie.date.fold(rest, cookie.date.time.try(t, tok, d, m, y))

# 70–99 are 19xx, 0–69 are 20xx.
def cookie.date.fix(+y: U32) -> U32:
  Bool.pick(U32, U32.is_le(y, 69), (y + 2000 : U32), Bool.pick(U32, U32.is_le(y, 99), (y + 1900 : U32), y))

def cookie.date.at(+y: U32, +d: U32, mo: U32, h: U32, mi: U32, s: U32) -> Maybe<&2, Time.Instant>:
  Bool.pick(Maybe<&2, Time.Instant>, Bool.and(U32.is_ge(y, 1601), Bool.and(U32.is_ge(d, 1), U32.is_le(d, 31))), Time.mk(Time.DateTime{Time.Date{y, mo, d}, h, mi, s, 0}), None{})

def cookie.date.fin(st: Cdate) -> Maybe<&2, Time.Instant>:
  match st:
    case Cdate{Some{Hms{h, mi, s}}, Some{d}, Some{mo}, Some{y}}:
      cookie.date.at(cookie.date.fix(y), d, mo, h, mi, s)
    case _:
      None{}

# §5.1.1: a cookie-date such as "Sun, 06 Nov 1994 08:49:37 GMT" or "Thu, 01-Jan-70 00:00:01 GMT".
# Time.mk refuses a day past the month's end and a time past 23:59:59.
def cookie.date(s: String) -> Maybe<&2, Time.Instant>:
  cookie.date.fin(cookie.date.fold(List.reverse(&2, String, cookie.date.tokens(s, (SNil{}, Nil{}))), Cdate{None{}, None{}, None{}, None{}}))

# §5.6.1–§5.6.7: the last of each attribute. expires is the date as sent; max_age is capped seconds.
# Neither is a time from now yet: a Cav with a Time.Instant and now beside it is too wide (bendlang/bend#1069).
type Cav is Data:
  Cav{expires: Maybe<&2, Time.Instant>, max_age: Maybe<&2, U32>, domain: String, path: Maybe<&2, String>, secure: Bool, http_only: Bool, same_site: String}

def cookie.cav() -> Cav:
  Cav{None{}, None{}, "", None{}, False{}, False{}, "default"}

# §5.5: 400 days, the longest a cookie lives.
def cookie.limit() -> U32:
  34560000

def cookie.later(+now: Time.Instant, +secs: U32) -> Time.Instant:
  Time.Instant.add(now, Time.Duration.of_secs(Int.I64.from_u32(secs)))

def cookie.expires.cap(+now: Time.Instant, m: Maybe<&2, Time.Instant>) -> Maybe<&2, Time.Instant>:
  match m:
    case None{}:
      None{}
    case Some{+t}:
      +lim = cookie.later(now, cookie.limit())
      Some{Bool.pick(Time.Instant, Cmp.is_lt(Time.Instant.cmp(lim, t)), lim, t)}

def cookie.max_age.zero(m: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Some{0}

def cookie.max_age.nz(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{48}, t}:
      cookie.max_age.nz(t)
    case SCon{Chr{c}, t}:
      SCon{Chr{c}, t}

# More than 9 significant digits is past the limit (and would overflow parse_u32).
def cookie.max_age.cap(long: Bool, m: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Some{Bool.pick(U32, long, cookie.limit(), s)}

def cookie.max_age.secs(+v: String, neg: Bool) -> Maybe<&2, U32>:
  match neg:
    case True{}:
      cookie.max_age.zero(parse_u32(String.drop(v, 1n)))
    case False{}:
      cookie.max_age.cap(cookie.over(cookie.max_age.nz(v), 9), parse_u32(v))

# Zero or less is the earliest time, so the cookie is already expired.
def cookie.max_age.at(+now: Time.Instant, m: Maybe<&2, U32>) -> Maybe<&2, Time.Instant>:
  match m:
    case None{}:
      None{}
    case Some{+s}:
      Some{Bool.pick(Time.Instant, U32.is_eq(s, 0), Time.Instant.epoch(), cookie.later(now, U32.min(s, cookie.limit())))}

# §5.6.2: DIGIT*, or "-" and DIGIT*. Anything else is ignored.
def cookie.max_age(+v: String) -> Maybe<&2, U32>:
  cookie.max_age.secs(v, String.starts_with(v, "-"))

def cookie.same_site(+v: String) -> String:
  +l = String.to_lower(v)
  Bool.pick(String, Bool.or(String.eq(l, "strict"), Bool.or(String.eq(l, "lax"), String.eq(l, "none"))), l, "default")

type Av is Data:
  AvExpires{}
  AvMaxAge{}
  AvDomain{}
  AvPath{}
  AvSecure{}
  AvHttpOnly{}
  AvSameSite{}
  AvOther{}

def cookie.av.kind(+k: String) -> Av:
  Bool.pick(Av, String.eq(k, "expires"), AvExpires{}, Bool.pick(Av, String.eq(k, "max-age"), AvMaxAge{}, Bool.pick(Av, String.eq(k, "domain"), AvDomain{}, Bool.pick(Av, String.eq(k, "path"), AvPath{}, Bool.pick(Av, String.eq(k, "secure"), AvSecure{}, Bool.pick(Av, String.eq(k, "httponly"), AvHttpOnly{}, Bool.pick(Av, String.eq(k, "samesite"), AvSameSite{}, AvOther{})))))))

# An Expires or Max-Age that does not parse leaves the earlier one. A leading dot of Domain is dropped.
def cookie.av.put(k: Av, a: Cav, +v: String) -> Cav:
  match k a:
    case AvExpires{} Cav{e, m, d, p, s, h, ss}:
      Cav{Maybe.or(&2, Time.Instant, cookie.date(v), e), m, d, p, s, h, ss}
    case AvMaxAge{} Cav{e, m, d, p, s, h, ss}:
      Cav{e, Maybe.or(&2, U32, cookie.max_age(v), m), d, p, s, h, ss}
    case AvDomain{} Cav{e, m, d, p, s, h, ss}:
      Cav{e, m, String.to_lower(Bool.pick(String, String.starts_with(v, "."), String.drop(v, 1n), v)), p, s, h, ss}
    case AvPath{} Cav{e, m, d, p, s, h, ss}:
      Cav{e, m, d, Some{v}, s, h, ss}
    case AvSecure{} Cav{e, m, d, p, s, h, ss}:
      Cav{e, m, d, p, True{}, h, ss}
    case AvHttpOnly{} Cav{e, m, d, p, s, h, ss}:
      Cav{e, m, d, p, s, True{}, ss}
    case AvSameSite{} Cav{e, m, d, p, s, h, ss}:
      Cav{e, m, d, p, s, h, cookie.same_site(v)}
    case AvOther{} Cav{e, m, d, p, s, h, ss}:
      Cav{e, m, d, p, s, h, ss}

# §5.6: name and value trimmed; a value over 1024 octets drops the attribute.
def cookie.av(+a: Cav, kv: String & String & Bool) -> Cav:
  (k, v, found) = kv
  +tv = trim(v)
  Bool.pick(Cav, cookie.over(tv, 1024), a, cookie.av.put(cookie.av.kind(String.to_lower(trim(k))), a, tv))

def cookie.avs(xs: List<&2, String>, a: Cav) -> Cav:
  match xs:
    case Nil{}:
      a
    case Con{x, t}:
      cookie.avs(t, cookie.av(a, cookie.cut(x, 61)))

# §5.6: with no "=", the name is empty and the pair is the value.
def cookie.nv(r: String & String & Bool) -> String & String:
  (a, b, found) = r
  match found:
    case True{}:
      (trim(a), trim(b))
    case False{}:
      ("", trim(a))

def cookie.prefixed(+s: String, +p: String) -> Bool:
  String.starts_with(String.to_lower(s), p)

# §5.7 steps 8–10: (domain, host-only), or None to ignore the cookie.
# ponytail: the public-suffix check knows single-label suffixes only (com, org, localhost). Multi-label
# ones (co.uk, github.io) need the publicsuffix.org list; ship it as data when a caller needs it.
def cookie.domain.of(+host: String, +d: String) -> Maybe<&1, String & Bool>:
  +suffix = Bool.and(Bool.not(String.is_empty(d)), Bool.not(String.contains(d, ".")))
  +d2 = Bool.pick(String, Bool.and(suffix, String.eq(d, host)), "", d)
  Bool.pick(Maybe<&1, String & Bool>, Bool.or(Bool.and(suffix, Bool.not(String.eq(d, host))), Bool.not(cookie.ascii(d))), None{},
    Bool.pick(Maybe<&1, String & Bool>, String.is_empty(d2), Some{(host, True{})},
      Bool.pick(Maybe<&1, String & Bool>, cookie.domain_match(host, d2), Some{(d2, False{})}, None{})))

def cookie.path.of(p: Maybe<&2, String>, +req: String) -> String:
  match p:
    case None{}:
      cookie.default_path(req)
    case Some{+v}:
      Bool.pick(String, String.starts_with(v, "/"), v, cookie.default_path(req))

# §5.7 steps 12–20: Secure needs https; SameSite=None needs Secure; the __Secure- and __Host- prefixes.
def cookie.make.dm(dm: Maybe<&1, String & Bool>, +name: String, +value: String, +path: String, has_path: Bool, +secure: Bool, http_only: Bool, +same_site: String, expiry: Maybe<&2, Time.Instant>, https: Bool) -> Maybe<&2, Cookie>:
  match dm:
    case None{}:
      None{}
    case Some{(domain, +host_only)}:
      +host = Bool.and(Bool.and(secure, host_only), Bool.and(has_path, String.eq(path, "/")))
      +bad = Bool.or(Bool.or(Bool.and(secure, Bool.not(https)), Bool.and(String.eq(same_site, "none"), Bool.not(secure))),
        Bool.or(Bool.or(Bool.and(cookie.prefixed(name, "__secure-"), Bool.not(secure)), Bool.and(cookie.prefixed(name, "__host-"), Bool.not(host))),
          Bool.and(String.is_empty(name), Bool.or(cookie.prefixed(value, "__secure-"), cookie.prefixed(value, "__host-")))))
      Bool.pick(Maybe<&2, Cookie>, bad, None{}, Some{Cookie{name, value, domain, host_only, path, secure, http_only, same_site, expiry}})

# Max-Age wins over Expires, whatever their order (§5.7 step 6). Both count from now.
def cookie.expiry(+now: Time.Instant, m: Maybe<&2, U32>, e: Maybe<&2, Time.Instant>) -> Maybe<&2, Time.Instant>:
  Maybe.or(&2, Time.Instant, cookie.max_age.at(now, m), cookie.expires.cap(now, e))

def cookie.make(+now: Time.Instant, a: Url.Abs, +name: String, +value: String, c: Cav) -> Maybe<&2, Cookie>:
  Url.Abs{scheme, host, port, target} = a
  Cav{e, m, d, +p, secure, http_only, same_site} = c
  cookie.make.dm(cookie.domain.of(host, d), name, value, cookie.path.of(p, cookie.target_path(target)), Maybe.is_some(&2, String, p), secure, http_only, same_site, cookie.expiry(now, m, e), String.eq(scheme, "https"))

# An empty name and value, or more than 4096 octets of them, is ignored.
def cookie.parse.nv(+now: Time.Instant, a: Url.Abs, nv: String & String, avs: List<&2, String>) -> Maybe<&2, Cookie>:
  (+name, +value) = nv
  Bool.pick(Maybe<&2, Cookie>, Bool.or(Bool.and(String.is_empty(name), String.is_empty(value)), cookie.over(name ++ value, 4096)), None{}, cookie.make(now, a, name, value, cookie.avs(avs, cookie.cav())))

def cookie.parse.go(+now: Time.Instant, a: Url.Abs, xs: List<&2, String>) -> Maybe<&2, Cookie>:
  match xs:
    case Nil{}:
      None{}
    case Con{first, avs}:
      cookie.parse.nv(now, a, cookie.nv(cookie.cut(first, 61)), avs)

# §5.6 and §5.7: one Set-Cookie value received from a at now, or None when it is ignored.
def cookie.parse(+now: Time.Instant, a: Url.Abs, +line: String) -> Maybe<&2, Cookie>:
  Bool.pick(Maybe<&2, Cookie>, cookie.ctl(line), None{}, cookie.parse.go(now, a, String.split(line, ';')))

def cookie.https(a: Url.Abs) -> Bool:
  Url.Abs{scheme, host, port, target} = a
  String.eq(scheme, "https")

def cookie.secure(c: Cookie) -> Bool:
  Cookie{name, value, domain, host_only, path, secure, http_only, same_site, expiry} = c
  secure

# Same name, domain, host-only flag and path: the new cookie replaces the old one.
def cookie.same(+a: Cookie, +b: Cookie) -> Bool:
  Cookie{n1, v1, d1, h1, p1, s1, o1, ss1, e1} = a
  Cookie{n2, v2, d2, h2, p2, s2, o2, ss2, e2} = b
  Bool.and(Bool.and(String.eq(n1, n2), String.eq(d1, d2)), Bool.and(Bool.not(Bool.xor(h1, h2)), String.eq(p1, p2)))

# §5.7 step 16: a secure cookie that a new cookie from plain http must not overlay.
def cookie.shadows(+old: Cookie, +c: Cookie) -> Bool:
  Cookie{n1, v1, +d1, h1, p1, s1, o1, ss1, e1} = old
  Cookie{n2, v2, +d2, h2, p2, s2, o2, ss2, e2} = c
  Bool.and(Bool.and(String.eq(n1, n2), s1), Bool.and(Bool.or(cookie.domain_match(d1, d2), cookie.domain_match(d2, d1)), cookie.path_match(p2, p1)))

def cookie.shadowed(cs: List<&2, Cookie>, +c: Cookie) -> Bool:
  match cs:
    case Nil{}:
      False{}
    case Con{+o, t}:
      Bool.or(cookie.shadows(o, c), cookie.shadowed(t, c))

# cs with the cookie c replaces swapped for c (keeping its place, so its creation order), or c last.
# A c that is not live only removes the old one: that is how a server deletes a cookie.
def cookie.put(cs: List<&2, Cookie>, +c: Cookie, +live: Bool) -> List<&2, Cookie>:
  match cs:
    case Nil{}:
      Bool.pick(List<&2, Cookie>, live, [c], Nil{})
    case Con{+o, +t}:
      Bool.pick(List<&2, Cookie>, cookie.same(o, c), Bool.pick(List<&2, Cookie>, live, Con{c, t}, t), Con{o, cookie.put(t, c, live)})

def jar.put.c(m: Maybe<&2, Cookie>, j: Jar, +https: Bool) -> Jar:
  match m:
    case None{}:
      Jar{now, cs} = j
      Jar{now, cs}
    case Some{+c}:
      Jar{+now, +cs} = j
      Jar{now, Bool.pick(List<&2, Cookie>, Bool.and(Bool.not(Bool.or(https, cookie.secure(c))), cookie.shadowed(cs, c)), cs, cookie.put(cs, c, cookie.live(now, c)))}

def jar.put.one(j: Jar, +a: Url.Abs, x: String) -> Jar:
  Jar{+now, cs} = j
  jar.put.c(cookie.parse(now, a, x), Jar{now, cs}, cookie.https(a))

def jar.put.all(xs: List<&2, String>, j: Jar, +a: Url.Abs) -> Jar:
  match xs:
    case Nil{}:
      j
    case Con{x, t}:
      jar.put.all(t, jar.put.one(j, a, x), a)

# Every set-cookie field of h, in order, as received from a.
def jar.store.abs(j: Jar, +a: Url.Abs, +h: Map<&2, List<&2, String>>) -> Jar:
  jar.put.all(fields(h, "set-cookie"), j, a)

def jar.store.url(j: Jar, u: Maybe<&2, Url.Abs>, +h: Map<&2, List<&2, String>>) -> Jar:
  match u:
    case None{}:
      j
    case Some{+a}:
      jar.store.abs(j, a, h)

# The jar after res came from url, and res as it was. Header names are lowercase, as parse gives them.
# An unparsable url stores nothing.
def jar.store(j: Jar, url: String, res: Res) -> Jar & Res:
  Res{status, +headers, body} = res
  (jar.store.url(j, Url.absolute(url), headers), Res{status, headers, body})

# §5.8.3: domain (exact when host-only), path, and Secure only over https.
def cookie.sends(+host: String, +path: String, +https: Bool, +c: Cookie) -> Bool:
  Cookie{n, v, +d, +ho, +p, s, o, ss, e} = c
  Bool.and(Bool.pick(Bool, ho, String.eq(host, d), cookie.domain_match(host, d)), Bool.and(cookie.path_match(path, p), Bool.or(Bool.not(s), https)))

def cookie.pick(cs: List<&2, Cookie>, +host: String, +path: String, +https: Bool) -> List<&2, Cookie>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{+c, t}:
      List.filter.put(Cookie, c, cookie.pick(t, host, path, https), cookie.sends(host, path, https, c))

# The sort order of §5.8.3: longer paths first; the stable sort keeps creation order among equals.
def cookie.longer(a: Cookie, b: Cookie) -> Bool:
  Cookie{n1, v1, d1, h1, p1, s1, o1, ss1, e1} = a
  Cookie{n2, v2, d2, h2, p2, s2, o2, ss2, e2} = b
  Bool.not(Nat.is_lt(String.length(p1), String.length(p2)))

def cookie.pair(c: Cookie) -> String:
  Cookie{+n, +v, d, h, p, s, o, ss, e} = c
  Bool.pick(String, String.is_empty(n), v, n ++ "=" ++ v)

def cookie.pairs(cs: List<&2, Cookie>) -> List<&2, String>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      Con{cookie.pair(c), cookie.pairs(t)}

# §5.8.3: the cookie-string for a request to a, or "" when no cookie matches.
def jar.string(j: Jar, a: Url.Abs) -> String:
  Jar{now, cs} = j
  Url.Abs{scheme, +host, port, target} = a
  String.join(cookie.pairs(List.sort(~Cookie, ~cookie.longer, cookie.pick(cs, host, cookie.target_path(target), String.eq(scheme, "https")))), "; ")

# One cookie field: the caller's own cookie values first, then the jar's.
def jar.header(+h: Map<&2, List<&2, String>>, +s: String) -> Map<&2, List<&2, String>>:
  +old = String.join(fields(h, "cookie"), "; ")
  Bool.pick(Map<&2, List<&2, String>>, String.is_empty(s), h, set(h, "cookie", Bool.pick(String, String.is_empty(old), s, old ++ "; " ++ s)))

def jar.apply.url(j: Jar, u: Maybe<&2, Url.Abs>, +h: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match u:
    case None{}:
      h
    case Some{a}:
      jar.header(h, jar.string(j, a))

# The headers with the jar's cookies for a request to url in their cookie field (lowercase, as fetch
# sends names). An unparsable url adds nothing.
def jar.apply(j: Jar, url: String, +h: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  jar.apply.url(j, Url.absolute(url), h)

# The jar, if any, that a fetch threads through its hops.
def jar.opt.apply(m: Maybe<&2, Jar>, a: Url.Abs, +h: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match m:
    case None{}:
      h
    case Some{j}:
      jar.header(h, jar.string(j, a))

def jar.opt.res(j: Jar, +a: Url.Abs, r: Result<&1, &1, Err, Res>) -> Maybe<&2, Jar> & Result<&1, &1, Err, Res>:
  match r:
    case Fail{e}:
      (Some{j}, Fail{e})
    case Done{res}:
      Res{status, +headers, body} = res
      (Some{jar.store.abs(j, a, headers)}, Done{Res{status, headers, body}})

def jar.opt.store(m: Maybe<&2, Jar>, +a: Url.Abs, r: Result<&1, &1, Err, Res>) -> Maybe<&2, Jar> & Result<&1, &1, Err, Res>:
  match m:
    case None{}:
      (None{}, r)
    case Some{j}:
      jar.opt.res(j, a, r)

type Out is Type:
  OutDone{res: Res, sock: Maybe<&1, Socket>, rest: Bytes.Bytes}
  OutFail{e: Err, none: Bool}

def fetch.boxed(r: Result<&1, &1, Err, Res>, none: Bool) -> Out:
  match r:
    case Done{res}:
      OutDone{res, None{}, Bytes.new(0)}
    case Fail{e}:
      OutFail{e, none}

type Fl is Type:
  FlMore{rv: Rv, n: U32}
  FlBad{err: Maybe<&2, Err>, none: Bool}
  FlDone{res: Res, rest: Maybe<&1, Bytes.Bytes>}

def fetch.rt(+n: U32, t: Rt) -> Fl:
  match t:
    case RtMore{rv}:
      FlMore{rv, n}
    case RtBad{}:
      FlBad{None{}, U32.is_zero(n)}
    case RtDone{res, rest}:
      FlDone{res, rest}

# 64 KiB of head past the body cap, as serve allows.
def fetch.over(+n: U32) -> Bool:
  Nat.is_lt(Nat.add(fetch.max(), 65536n), U32.to_nat(n))

def fetch.piece.cap(over: Bool, +head: Bool, rv: Rv, +n2: U32, +len: U32, buf: Array<U32>) -> Fl:
  match over:
    case True{}:
      FlBad{None{}, False{}}
    case False{}:
      fetch.rt(n2, rv.step(U32.is_zero(len), head, rv, Bytes.Bytes{len, buf}))

def fetch.piece(+head: Bool, rv: Rv, +n: U32, p: U32 & Array<U32>) -> Fl:
  (+len, buf) = p
  +n2 = (n + len : U32)
  fetch.piece.cap(fetch.over(n2), head, rv, n2, len, buf)

def fetch.next(+head: Bool, rv: Rv, +n: U32, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Socket & Fl:
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      (s, FlBad{Some{err.or_late(code, ErrRead{code, why})}, U32.is_zero(n)})
    case Done{p}:
      (s, fetch.piece(head, rv, n, p))

# Reads until the response is whole or cannot be; an empty read means the server closed.
def exchange.tup(o: Out) -> Maybe<&1, Socket> & Result<&1, &1, Err, Res> & Bytes.Bytes:
  match o:
    case OutFail{e, none}:
      (None{}, Fail{e}, Bytes.new(0))
    case OutDone{res, sock, rest}:
      (sock, Done{res}, rest)

# One request on an open socket. Some{socket}: it can take another request.
type Cert is Data:
  Cert{chain: String, key: String}

type Proxy is Data:
  ProxyDirect{}
  ProxyVia{host: String, port: U32, authorization: String}

type Route is Data:
  RouteDirect{tls: Bool, host: String, port: U32, cert: Maybe<&2, Cert>, ca: String}
  RouteProxy{tls: Bool, host: String, port: U32, sni: String,
    authority: String, authorization: String, cert: Maybe<&2, Cert>, ca: String}

# Connection pool: idle sockets by origin and client identity, newest first, at most cap per key.
# fetch uses a fresh pool per call.

type Send is Type:
  Send{method: String, target: String, authority: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

type TunnelStep is Type:
  TunnelRead{s: Socket, raw: String}
  TunnelHead{s: Socket, raw: String, frame: Frame}
  TunnelGot{raw: String,
    answer: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>}

def pool.key(+scheme: String, +host: String, +port: U32) -> String:
  scheme ++ "://" ++ host ++ ":" ++ U32.show(port)

def pool.key.cert(+base: String, cert: Maybe<&2, Cert>) -> String:
  match cert:
    case None{}:
      base
    case Some{Cert{+chain, +key}}:
      base ++ "|cert:" ++ Nat.show(String.length(chain)) ++ ":" ++ chain
        ++ Nat.show(String.length(key)) ++ ":" ++ key

def pool.key.ca(+base: String, +ca: String, empty: Bool) -> String:
  match empty:
    case True{}:
      base
    case False{}:
      base ++ "|ca:" ++ Nat.show(String.length(ca)) ++ ":" ++ ca

def pool.key.trust(+base: String, cert: Maybe<&2, Cert>, +ca: String) -> String:
  pool.key.ca(pool.key.cert(base, cert), ca, String.is_empty(ca))

def pool.idempotent(+method: String) -> Bool:
  Bool.or(String.eq(method, "GET"), Bool.or(String.eq(method, "HEAD"), Bool.or(String.eq(method, "OPTIONS"), Bool.or(String.eq(method, "TRACE"), Bool.or(String.eq(method, "PUT"), String.eq(method, "DELETE"))))))

def proxy.auth.safe(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, rest}:
      Bool.and(U32.is_ge(c, 32), Bool.and(U32.is_ne(c, 127), proxy.auth.safe(rest)))

def proxy.auth.checked(+decoded: String, valid: Bool) -> Maybe<&2, String>:
  match valid:
    case False{}:
      None{}
    case True{}:
      Some{"Basic " ++ Bytes.to_base64(Bytes.from_string(decoded))}

def proxy.auth.value(m: Maybe<&2, String>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{+decoded}:
      proxy.auth.checked(decoded, Bool.and(Url.has(decoded, 58), proxy.auth.safe(decoded)))

def proxy.from.abs(authorization: String, m: Maybe<&2, Url.Abs>) -> Maybe<&2, Proxy>:
  match m:
    case None{}:
      None{}
    case Some{Url.Abs{scheme, host, port, target}}:
      Some{ProxyVia{host, port, authorization}}

def proxy.from.user(user: String, host: String) -> Maybe<&2, Proxy>:
  do Maybe<&2, Proxy>:
    authorization : String <- proxy.auth.value(Url.pct.decode(user))
    proxy.from.abs(authorization, Url.absolute("http://" ++ host))

def proxy.from.authority(has_user: Bool, authority: String, split: String & String) ->
    Maybe<&2, Proxy>:
  match has_user:
    case False{}:
      proxy.from.abs("", Url.absolute("http://" ++ authority))
    case True{}:
      (user, host) = split
      proxy.from.user(user, host)

def proxy.from.parts(parts: String & String) -> Maybe<&2, Proxy>:
  (+authority, path) = parts
  match path:
    case SNil{}:
      proxy.from.authority(Url.has(authority, 64), authority, Url.take_to(authority, 64))
    case other:
      None{}

def proxy.from.url.if(valid: Bool, raw: String) -> Maybe<&2, Proxy>:
  match valid:
    case False{}:
      None{}
    case True{}:
      proxy.from.parts(Url.take_to(String.drop(raw, 7n), 47))

def proxy.from.url(+raw: String) -> Maybe<&2, Proxy>:
  proxy.from.url.if(String.starts_with(String.to_lower(raw), "http://"), raw)

def proxy.no.domain(+host: String, +suffix: String) -> Bool:
  Bool.or(String.eq(host, suffix), String.ends_with(host, "." ++ suffix))

def proxy.no.suffix(+host: String, +raw: String) -> Bool:
  match raw:
    case SCon{Chr{46}, +suffix}:
      proxy.no.domain(host, suffix)
    case other:
      proxy.no.domain(host, raw)

def proxy.no.port(valid: Bool, +host: String, suffix: String) -> Bool:
  match valid:
    case False{}:
      False{}
    case True{}:
      proxy.no.suffix(host, suffix)

def proxy.no.named(+host: String, +port: U32, parts: String & String) -> Bool:
  (suffix, port_text) = parts
  match port_text:
    case SNil{}:
      proxy.no.suffix(host, suffix)
    case other:
      proxy.no.port(String.eq(port_text, U32.show(port)), host, suffix)

def proxy.no.literal(+host: String, +port: U32, +name: String) -> Bool:
  Bool.or(String.eq(name, host), Bool.or(String.eq(name, "[" ++ host ++ "]"),
    Bool.or(String.eq(name, host ++ ":" ++ U32.show(port)),
      String.eq(name, "[" ++ host ++ "]:" ++ U32.show(port)))))

def proxy.no.token(+host: String, +port: U32, token: String) -> Bool:
  +name = String.to_lower(trim(token))
  Bool.or(String.eq(name, "*"),
    Bool.or(proxy.no.literal(host, port, name),
      Bool.and(Bool.not(Url.has(host, 58)),
        proxy.no.named(host, port, Url.take_to(name, 58)))))

def proxy.no.list(xs: List<&2, String>, +host: String, +port: U32) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{token, rest}:
      Bool.or(proxy.no.token(host, port, token), proxy.no.list(rest, host, port))

def proxy.no_match(+host: String, +port: U32, no_proxy: String) -> Bool:
  proxy.no.list(String.split(no_proxy, ','), String.to_lower(host), port)

def proxy.env.value(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Fail{e}:
      ""
    case Done{value}:
      value

def proxy.from.env(value: String) -> Maybe<&2, Proxy>:
  match value:
    case SNil{}:
      Some{ProxyDirect{}}
    case other:
      proxy.from.url(value)

def proxy.choose(bypass: Bool, value: String) -> Maybe<&2, Proxy>:
  match bypass:
    case True{}:
      Some{ProxyDirect{}}
    case False{}:
      proxy.from.env(value)

def h2.header.skip(+name: String) -> Bool:
  match name:
    case SCon{Chr{58}, rest}:
      True{}
    case other:
      Bool.or(req.reserved(name),
        Bool.or(String.eq(name, "keep-alive"),
          Bool.or(String.eq(name, "proxy-connection"),
            Bool.or(String.eq(name, "upgrade"), String.eq(name, "te")))))

def h2.header.mode(+name: String) -> U32:
  Bool.pick(U32,
    Bool.or(String.eq(name, "authorization"),
      Bool.or(String.eq(name, "cookie"), String.eq(name, "proxy-authorization"))),
    2, 0)

def h2.header.tokens(vs: List<&2, String>) -> List<&2, String>:
  match vs:
    case Nil{}:
      Nil{}
    case Con{value, rest}:
      List.append(&2, String, String.split(value, ','), h2.header.tokens(rest))

def h2.header.nominated.one(enabled: Bool, vs: List<&2, String>,
    rest: List<&2, String>) -> List<&2, String>:
  match enabled:
    case True{}:
      List.append(&2, String, h2.header.tokens(vs), rest)
    case False{}:
      rest

def h2.header.nominated(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>) ->
    List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case (name, values) <> tail:
      h2.header.nominated.one(String.eq(String.to_lower(name), "connection"),
        values, h2.header.nominated(tail))

def h2.header.has(xs: List<&2, String>, +key: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{value, rest}:
      Bool.or(String.eq(String.to_lower(trim(value)), key), h2.header.has(rest, key))

def h2.response.status.value(+value: String, valid: Bool) -> Maybe<&2, U32>:
  match valid:
    case False{}:
      None{}
    case True{}:
      parse_u32(value)

def h2.buffered.head.result(r: Result<&1, &1, Err, Maybe<&1, Res>>) -> Maybe<&1, Res>:
  match r:
    case Fail{e}:
      None{}
    case Done{res}:
      res

def proxy.connect.frame(raw: String, over: Bool) -> Frame:
  match over:
    case True{}:
      FrameBad{}
    case False{}:
      frame(raw, False{}, True{})

def proxy.connect.chunk(empty: Bool, s: Socket, raw: String,
    +len: U32, buf: Array<U32>) -> TunnelStep:
  match empty:
    case True{}:
      TunnelHead{s, raw, FrameBad{}}
    case False{}:
      TunnelRead{s, raw ++ Bytes.to_string(Bytes.Bytes{len, buf})}

def proxy.connect.header(+authority: String, authorization: String) -> String:
  match authorization:
    case SNil{}:
      "CONNECT " ++ authority ++ " HTTP/1.1\r\nHost: " ++ authority ++ "\r\n\r\n"
    case other:
      "CONNECT " ++ authority ++ " HTTP/1.1\r\nHost: " ++ authority
        ++ "\r\nProxy-Authorization: " ++ authorization ++ "\r\n\r\n"

def pool.retry(+none: Bool, +idem: Bool) -> Bool:
  Bool.and(none, idem)

def proxy.http.headers(headers: Map<&2, List<&2, String>>,
    authorization: String) -> Map<&2, List<&2, String>>:
  match authorization:
    case SNil{}:
      headers
    case other:
      set(headers, "proxy-authorization", authorization)

def proxy.absolute(scheme: String, host_field: String, target: String) -> String:
  scheme ++ "://" ++ host_field ++ target

def proxy.request(secure: Bool, +scheme: String, method: String,
    +target: String, +hf: String, headers: Map<&2, List<&2, String>>,
    body: Bytes.Bytes, authorization: String) -> Send:
  match secure:
    case True{}:
      Send{method, target, hf, Map.del(&2, List<&2, String>, headers,
        "proxy-authorization"), body}
    case False{}:
      Send{method, proxy.absolute(scheme, hf, target), hf,
        proxy.http.headers(headers, authorization), body}

# The pool key, the request as sent, and the route to one origin, direct or through a proxy.
def origin.route(+method: String, headers: Map<&2, List<&2, String>>,
    body: Bytes.Bytes, +hf: String, +scheme: String, +host: String, +port: U32,
    +target: String, +cert: Maybe<&2, Cert>, +ca: String, proxy: Proxy) ->
    String & Send & Route:
  match proxy:
    case ProxyDirect{}:
      (pool.key.trust(pool.key(scheme, host, port), cert, ca),
        Send{method, target, hf, headers, body},
        RouteDirect{String.eq(scheme, "https"), host, port, cert, ca})
    case ProxyVia{+proxy_host, +proxy_port, +authorization}:
      +secure = String.eq(scheme, "https")
      (pool.key.trust(pool.key(scheme, host, port)
          ++ "|proxy:" ++ proxy_host ++ ":" ++ U32.show(proxy_port)
          ++ "|auth:" ++ authorization, cert, ca),
        proxy.request(secure, scheme, method, target, hf, headers, body, authorization),
        RouteProxy{secure, proxy_host, proxy_port, host,
          Url.host_field.wrap(host, Url.has(host, 58)) ++ ":" ++ U32.show(port),
          authorization, cert, ca})

def pool.scheme.ok(a: Url.Abs) -> Bool:
  Url.Abs{+scheme, host, port, target} = a
  Bool.or(String.eq(scheme, "http"), String.eq(scheme, "https"))

type Next is Type:
  NDone{res: Result<&1, &1, Err, Res>}
  NStop{}
  NGo{left: Nat, hop: Hop}

type Mode is Data:
  ModeFollow{}
  ModeManual{}
  ModeError{}

# left: redirects still allowed after the request we just finished.
def fetch.hop(left: Nat, h: Hop) -> Next:
  match left:
    case 0n:
      NStop{}
    case 1n+p:
      NGo{p, h}

def fetch.decide.r(left: Nat, r: Res, next: Maybe<&1, Hop>) -> Next:
  match next:
    case None{}:
      NDone{Done{r}}
    case Some{h}:
      fetch.hop(left, h)

def fetch.decide.res(left: Nat, h: Hop, r: Res) -> Next:
  Res{+status, +headers, body} = r
  fetch.decide.r(left, Res{status, headers, body}, redirect(status, headers, h))

def fetch.decide(left: Nat, h: Hop, m: Result<&1, &1, Err, Res>) -> Next:
  match m:
    case Fail{e}:
      NDone{Fail{e}}
    case Done{r}:
      fetch.decide.res(left, h, r)

def fetch.error.res(r: Res, bad: Bool) -> Next:
  match bad:
    case True{}:
      NDone{Fail{ErrRedirect{}}}
    case False{}:
      NDone{Done{r}}

def fetch.error(h: Hop, m: Result<&1, &1, Err, Res>) -> Next:
  match m:
    case Fail{e}:
      NDone{Fail{e}}
    case Done{r}:
      Res{+status, +headers, body} = r
      fetch.error.res(Res{status, headers, body}, Bool.and(redirect.code(status), has_header(headers, "location")))

def fetch.policy(mode: Mode, left: Nat, h: Hop, m: Result<&1, &1, Err, Res>) -> Next:
  match mode:
    case ModeFollow{}:
      fetch.decide(left, h, m)
    case ModeManual{}:
      NDone{m}
    case ModeError{}:
      fetch.error(h, m)

# A caller's own Accept-Encoding wins; enc is the codings fetch can undo.
def accept.enc(+h: Map<&2, List<&2, String>>, +enc: String) -> Map<&2, List<&2, String>>:
  Bool.pick(Map<&2, List<&2, String>>, has_header(h, "accept-encoding"), h, set(h, "accept-encoding", enc))

def fetch.start(method: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, u: Maybe<&2, Url.Abs>, +enc: String) -> Next:
  match u:
    case None{}:
      NDone{Fail{ErrUrl{}}}
    case Some{a}:
      NGo{20n, Hop{method, a, accept.enc(req.put(Map.to_list(&2, List<&2, String>, headers), empty()), enc), body}}

# The redirect loop's state: the pool, what to do next, the client identity, the jar, and the CA file.
def pool.next.ca(same: Bool, +ca: String) -> String:
  match same:
    case True{}:
      ca
    case False{}:
      ""

# The certificate and CA file go on only to a hop on the same origin.
def next.trust(+old: String, cert: Maybe<&2, Cert>, +ca: String, n: Next) -> Next & Maybe<&2, Cert> & String:
  match n:
    case NGo{left, h}:
      Hop{method, +url, headers, body} = h
      +same = String.eq(old, redirect.origin(url))
      (NGo{left, Hop{method, url, headers, body}}, Bool.pick(Maybe<&2, Cert>, same, cert, None{}), pool.next.ca(same, ca))
    case NDone{r}:
      (NDone{r}, None{}, "")
    case NStop{}:
      (NStop{}, None{}, "")

def ce.keep(+w: String, +rest: List<&2, String>) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.is_empty(w), rest, Con{w, rest})

def ce.norm(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{v, t}:
      ce.keep(String.to_lower(trim(v)), ce.norm(t))

def ce.split(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{v, t}:
      List.append(&2, String, ce.norm(String.split(v, ',')), ce.split(t))

# Ok: decoded so far. Bad: a coding failed. Skip: a coding we cannot decode, so the body stays as sent.
type Dec is Type:
  DecOk{b: Bytes.Bytes}
  DecBad{}
  DecSkip{}

def ce.of(m: Maybe<&1, Bytes.Bytes>) -> Dec:
  match m:
    case None{}:
      DecBad{}
    case Some{b}:
      DecOk{b}

# Servers send deflate both with and without the zlib wrapper.
def ce.deflate.raw(b: Bytes.Bytes, m: Maybe<&1, Bytes.Bytes>) -> Dec:
  match m:
    case Some{out}:
      DecOk{out}
    case None{}:
      ce.of(Zlib.inflate(b))

def ce.deflate.of(r: Bytes.Bytes & Bytes.Bytes) -> Dec:
  (a, b) = r
  ce.deflate.raw(b, Zlib.unzlib(a))

def ce.deflate(b: Bytes.Bytes) -> Dec:
  ce.deflate.of(Bytes.clone(b))

def ce.apply.id(on: Bool, b: Bytes.Bytes) -> Dec:
  match on:
    case True{}:
      DecOk{b}
    case False{}:
      DecSkip{}

def ce.apply.de(on: Bool, +c: String, b: Bytes.Bytes) -> Dec:
  match on:
    case True{}:
      ce.deflate(b)
    case False{}:
      ce.apply.id(String.eq(c, "identity"), b)

def ce.apply.gz(on: Bool, +c: String, b: Bytes.Bytes) -> Dec:
  match on:
    case True{}:
      ce.of(Zlib.gunzip(b))
    case False{}:
      ce.apply.de(String.eq(c, "deflate"), c, b)

def ce.apply(+c: String, b: Bytes.Bytes) -> Dec:
  ce.apply.gz(Bool.or(String.eq(c, "gzip"), String.eq(c, "x-gzip")), c, b)

def ce.go(cs: List<&2, String>, d: Dec) -> Dec:
  match cs:
    case Nil{}:
      d
    case Con{+c, t}:
      match d:
        case DecOk{b}:
          ce.go(t, ce.apply(c, b))
        case DecBad{}:
          DecBad{}
        case DecSkip{}:
          DecSkip{}

def decoded.pick(d: Dec, +status: U32, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> Result<&1, &1, Err, Res>:
  match d:
    case DecOk{b}:
      Done{Res{status, headers, b}}
    case DecBad{}:
      Fail{ErrBad{}}
    case DecSkip{}:
      Done{Res{status, headers, body}}

# One copy decodes; the other is the body as sent, for a coding we cannot decode.
def decoded.both(+status: U32, +headers: Map<&2, List<&2, String>>, cs: List<&2, String>, r: Bytes.Bytes & Bytes.Bytes) -> Result<&1, &1, Err, Res>:
  (a, body) = r
  decoded.pick(ce.go(cs, DecOk{a}), status, headers, body)

def decoded.cs(+status: U32, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, cs: List<&2, String>) -> Result<&1, &1, Err, Res>:
  match cs:
    case Nil{}:
      Done{Res{status, headers, body}}
    case Con{c, t}:
      decoded.both(status, headers, Con{c, t}, Bytes.clone(body))

def decoded.go(empty: Bool, +status: U32, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> Result<&1, &1, Err, Res>:
  match empty:
    case True{}:
      Done{Res{status, headers, body}}
    case False{}:
      decoded.cs(status, headers, body, List.reverse(&2, String, ce.split(fields(headers, "content-encoding"))))

# The body decoded per Content-Encoding; the headers stay as sent. A corrupt body is ErrBad.
def decoded(res: Res) -> Result<&1, &1, Err, Res>:
  Res{+status, +headers, body} = res
  Bytes.Bytes{+len, buf} = body
  decoded.go(U32.is_zero(len), status, headers, Bytes.Bytes{len, buf})

def decoded.m(r: Result<&1, &1, Err, Res>) -> Maybe<&1, Res>:
  match r:
    case Done{x}:
      Some{x}
    case Fail{e}:
      None{}

def decoded.some(res: Res) -> Maybe<&1, Res>:
  decoded.m(decoded(res))

def ce.words(r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match r:
    case Fail{e}:
      None{}
    case Done{b}:
      Some{b}

# A decoded body stops at 16 MiB, like a received one.
def ce.dec(d: Dec) -> Maybe<&1, Bytes.Bytes>:
  match d:
    case DecOk{b}:
      Some{b}
    case DecBad{}:
      None{}
    case DecSkip{}:
      None{}

# ponytail: deflate runs on the pure decoder, which also takes raw DEFLATE; servers rarely send it.
def ce.has(xs: List<&2, String>, +c: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{x, t}:
      Bool.or(String.eq(c, x), ce.has(t, c))

def ce.known(cs: List<&2, String>, +ok: List<&2, String>) -> Bool:
  match cs:
    case Nil{}:
      True{}
    case Con{c, t}:
      Bool.and(ce.has(ok, c), ce.known(t, ok))

def decoded.io.pick(m: Maybe<&1, Bytes.Bytes>, +status: U32, headers: Map<&2, List<&2, String>>) -> Result<&1, &1, Err, Res>:
  match m:
    case Some{b}:
      Done{Res{status, headers, b}}
    case None{}:
      Fail{ErrBad{}}

def codings.ok(r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> Bool:
  match r:
    case Fail{(+c, why)}:
      Bool.not(U32.is_eq(c, 2))
    case Done{p}:
      True{}

def codings.add(has: Bool, +enc: String, +c: String) -> String:
  Bool.pick(String, has, enc ++ ", " ++ c, enc)

# gzip and deflate, then br and zstd when their C library loads.
type Fetch is Type:
  Fetch{method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

def resolve.show(a: Url.Abs) -> String:
  Url.Abs{+scheme, host, port, +target} = a
  scheme ++ "://" ++ Url.host_field(Url.Abs{scheme, host, port, target}) ++ target

def resolve.to(m: Maybe<&2, Url.Abs>) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{a}:
      Some{resolve.show(a)}

def resolve.base(m: Maybe<&2, Url.Abs>, +ref: String) -> Maybe<&2, String>:
  match m:
    case None{}:
      None{}
    case Some{b}:
      resolve.to(Url.resolve(b, ref))

def resolve(base: String, +ref: String) -> Maybe<&2, String>:
  resolve.base(Url.absolute(base), ref)

# Retry. The wait before retry n (0 first) is 500 ms doubled n times, at most 30 s;
# its upper half is jitter r: backoff(n, r) = half + r mod (half + 1).
def retry.cap() -> U32:
  30000

def retry.base(n: Nat) -> U32:
  match n:
    case 0n:
      500
    case 1n+p:
      U32.min((retry.base(p) * 2 : U32), retry.cap())

def retry.backoff.half(+half: U32, +r: U32) -> U32:
  (half + (r % (half + 1)) : U32)

def retry.backoff(n: Nat, +r: U32) -> U32:
  retry.backoff.half((retry.base(n) / 2 : U32), r)

# ms clamped to 0 .. retry.cap().
def retry.after.ms(+ms: Int.I64) -> U32:
  Bool.pick(U32, Int.I64.is_neg(ms), 0,
    Bool.pick(U32, Int.I64.is_lt(ms, Int.I64.from_u32(retry.cap())), Int.I64.to_u32(ms), retry.cap()))

def retry.after.date(m: Maybe<&2, Time.Instant>, now: Time.Instant) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{date}:
      Some{retry.after.ms(Time.Duration.to_ms(Time.Instant.since(date, now)))}

# More than 5 digits is past the cap, and would overflow parse_u32.
def retry.after.secs(+v: String, now: Time.Instant, n: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match n:
    case None{}:
      retry.after.date(Time.http_date.parse(v), now)
    case Some{s}:
      Some{Bool.pick(U32, Nat.is_lt(5n, String.length(v)), retry.cap(), U32.min((s * 1000 : U32), retry.cap()))}

# Retry-After (RFC 9110 §10.2.3) as ms from now, at most retry.cap(): delay-seconds, or an
# HTTP-date (a past date is 0). None when v is empty or neither form.
def retry.after(+v: String, now: Time.Instant) -> Maybe<&2, U32>:
  retry.after.secs(v, now, parse_u32(v))

def retry.wait(m: Maybe<&2, U32>, n: Nat, +r: U32) -> U32:
  match m:
    case None{}:
      retry.backoff(n, r)
    case Some{ms}:
      ms

# The wait before retry n: Retry-After v when it reads as a delay, else backoff with jitter r.
def retry.delay(+v: String, now: Time.Instant, n: Nat, +r: U32) -> U32:
  retry.wait(retry.after(v, now), n, r)

# Statuses a later try may clear.
def retry.status(+s: U32) -> Bool:
  Bool.or(Bool.or(U32.is_eq(s, 408), U32.is_eq(s, 429)),
    Bool.or(Bool.or(U32.is_eq(s, 500), U32.is_eq(s, 502)), Bool.or(U32.is_eq(s, 503), U32.is_eq(s, 504))))

# A refused connect or a timeout may clear; any other error would repeat.
def retry.fail(e: Err) -> Result<&1, &1, Err, Res> & Maybe<&2, String>:
  match e:
    case ErrConnect{code, why}:
      (Fail{ErrConnect{code, why}}, Some{""})
    case ErrTimeout{}:
      (Fail{ErrTimeout{}}, Some{""})
    case other:
      (Fail{other}, None{})

def retry.res(res: Res) -> Result<&1, &1, Err, Res> & Maybe<&2, String>:
  Res{+status, +headers, body} = res
  (Done{Res{status, headers, body}}, Bool.pick(Maybe<&2, String>, retry.status(status), Some{header(headers, "retry-after")}, None{}))

def retry.judge.try(r: Result<&1, &1, Err, Res>) -> Result<&1, &1, Err, Res> & Maybe<&2, String>:
  match r:
    case Fail{e}:
      retry.fail(e)
    case Done{res}:
      retry.res(res)

# One try, judged: the result as it came, and Some{Retry-After value} ("" when absent)
# when an idempotent request may try again.
def retry.judge(idem: Bool, r: Result<&1, &1, Err, Res>) -> Result<&1, &1, Err, Res> & Maybe<&2, String>:
  match idem:
    case False{}:
      (r, None{})
    case True{}:
      retry.judge.try(r)

# ponytail: a failed random source gives jitter 0, so the wait is the lower half.
def retry.jitter(r: Result<&1, &1, U32 & String, U32>) -> U32:
  match r:
    case Fail{e}:
      0
    case Done{x}:
      x

def retry.kept(body: Bytes.Bytes, j: Result<&1, &1, Err, Res> & Maybe<&2, String>) -> Bytes.Bytes & Result<&1, &1, Err, Res> & Maybe<&2, String>:
  (r, m) = j
  (body, r, m)

# One fetch of the copy; the body comes back for the next try.
type Po is Type:
  PoNone{}
  PoPiece{b: Bytes.Bytes}
  PoReady{b: Bytes.Bytes}
  PoEnd{}
  PoBad{e: Err}

type Pc is Type:
  Pc{rb: Rb, out: Po}

# A body piece, or none when empty: more reads the next piece, and not more is the end.
def pc.po(more: Bool, empty: Bool, b: Bytes.Bytes) -> Po:
  match empty:
    case True{}:
      Bool.pick(Po, more, PoNone{}, PoEnd{})
    case False{}:
      PoPiece{b}

def pc.piece(more: Bool, +rb: Rb, b: Bytes.Bytes) -> Pc:
  Bytes.Bytes{+len, buf} = b
  Pc{rb, pc.po(more, U32.is_zero(len), Bytes.Bytes{len, buf})}

def pc.fed.of(b: Bytes.Bytes, st: Rb) -> Pc:
  match st:
    case RbDone{}:
      pc.piece(False{}, RbDone{}, b)
    case RbBad{}:
      Pc{RbDone{}, PoBad{ErrBad{}}}
    case RbLen{n}:
      pc.piece(True{}, RbLen{n}, b)
    case RbChunk{st}:
      pc.piece(True{}, RbChunk{st}, b)
    case RbClose{}:
      pc.piece(True{}, RbClose{}, b)

def pc.fed(bf: Bf) -> Pc:
  Bf{st, parts, rest} = bf
  pc.fed.of(rb.body(parts), st)

# The body bytes that just arrived: what they add to the body, and how it ends.
def pc.of(rb: Rb, piece: Bytes.Bytes) -> Pc:
  pc.fed(rb.feed(rb, Nil{}, piece))

# The server closed. Only a close-delimited body may end this way (RFC 9112 §8).
def pc.end(ok: Bool) -> Pc:
  match ok:
    case True{}:
      Pc{RbDone{}, PoEnd{}}
    case False{}:
      Pc{RbDone{}, PoBad{ErrBad{}}}

def pc.eof(st: Rb) -> Pc:
  pc.end(rb.eof(st))

# pc.of, and whether bytes came past the end of the body.
def stream.pc.of(bf: Bf) -> Pc & Bool:
  Bf{st, parts, rest} = bf
  Bytes.Bytes{+len, buf} = rest
  (pc.fed.of(rb.body(parts), st), Bool.not(U32.is_zero(len)))

def stream.pc(rb: Rb, piece: Bytes.Bytes) -> Pc & Bool:
  stream.pc.of(rb.feed(rb, Nil{}, piece))

# Bytes past the body put the socket out of step with the server, so it cannot go back to a pool.
def stream.after(+rb: Rb) -> Po:
  match rb:
    case RbDone{}:
      PoEnd{}
    case RbBad{}:
      PoEnd{}
    case RbLen{n}:
      PoNone{}
    case RbChunk{st}:
      PoNone{}
    case RbClose{}:
      PoNone{}

def stream.ready(empty: Bool, +rb: Rb, b: Bytes.Bytes) -> Po:
  match empty:
    case True{}:
      stream.after(rb)
    case False{}:
      PoReady{b}

def stream.finish.ok(r: Result<&1, &1, U32 & String, Unit>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{u}:
      True{}

def stream.po.end(out: Po) -> Bool:
  match out:
    case PoEnd{}:
      True{}
    case other:
      False{}

def stream.rb.done(+rb: Rb) -> Bool:
  match rb:
    case RbDone{}:
      True{}
    case other:
      False{}

type Sh is Type:
  ShMore{buf: Bytes.Bytes, k: U32}
  ShBad{err: Maybe<&2, Err>, none: Bool}
  ShRes{res: Res, rb: Rb, rest: Bytes.Bytes}

def sh.of(hs: Hs) -> Sh:
  match hs:
    case HsWait{buf, k}:
      ShMore{buf, k}
    case HsBad{}:
      ShBad{None{}, False{}}
    case HsSeek{buf, from, k}:
      ShBad{None{}, False{}}
    case HsRes{res, rb, rest}:
      ShRes{res, rb, rest}

def sh.none(buf: Bytes.Bytes, +k: U32) -> Bool:
  Bytes.Bytes{+len, b} = buf
  Bool.and(U32.is_zero(len), U32.is_zero(k))

def sh.piece(+head: Bool, buf: Bytes.Bytes, +k: U32, p: U32 & Array<U32>) -> Sh:
  Bytes.Bytes{+ol, ob} = buf
  (+len, b) = p
  Bool.pick(Sh, U32.is_zero(len), ShBad{None{}, Bool.and(U32.is_zero(ol), U32.is_zero(k))}, sh.of(hs.more(head, k, Bytes.Bytes{ol, ob}, Bytes.Bytes{len, b})))

def sh.next(+head: Bool, buf: Bytes.Bytes, +k: U32, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Socket & Sh:
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      (s, ShBad{Some{err.or_late(code, ErrRead{code, why})}, sh.none(buf, k)})
    case Done{p}:
      (s, sh.piece(head, buf, k, p))

def stream.back(back: Maybe<&2, String>, +rb: Rb, +headers: Map<&2, List<&2, String>>) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, Bool.and(Bool.not(rb.eof(rb)), Bool.not(res.conn_close(headers))), back, None{})

# Reads until the final head is in; the body bytes that came with it are the first piece.
type Up is Type:
  Up{tls: Bool, s: Socket, ms: U32, head: Bool, err: Maybe<&2, Err>}

def hex.digit(+n: U32) -> Char:
  Chr{Bool.pick(U32, U32.is_lt(n, 10), (48 + n : U32), (87 + n : U32))}

def hex.go(k: Nat, +n: U32, acc: String) -> String:
  match k:
    case 0n:
      acc
    case 1n+p:
      hex.go(p, U32.shrn(n, 4n), SCon{hex.digit(U32.and(n, 15)), acc})

def hex.trim(+s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, +t}:
      Bool.pick(String, Bool.and(U32.is_eq(c, 48), Bool.not(String.is_empty(t))), hex.trim(t), SCon{Chr{c}, t})

def hex(+n: U32) -> String:
  hex.trim(hex.go(8n, n, ""))

def up.sent(+tls: Bool, +ms: U32, +head: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> Up:
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      Up{tls, s, ms, head, Some{err.or_late(code, ErrWrite{code, why})}}
    case Done{u}:
      Up{tls, s, ms, head, None{}}

def up.head(+method: String, +target: String, +hf: String, +headers: Map<&2, List<&2, String>>) -> String:
  request(method, target, set(set(set(req.put(Map.to_list(&2, List<&2, String>, headers), empty()), "host", hf), "connection", "close"), "transfer-encoding", "chunked"), "")

def up.wrote(+tls: Bool, +ms: U32, +head: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> Up & Result<&2, &2, Err, Unit>:
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      +e = err.or_late(code, ErrWrite{code, why})
      (Up{tls, s, ms, head, Some{e}}, Fail{e})
    case Done{u}:
      (Up{tls, s, ms, head, None{}}, Done{Unit{}})

# One write per chunk, so the size line and the data do not wait on each other (Nagle).
type ServerConfig is Data:
  ServerConfig{host: String, port: U32, body_bytes: U32, header_bytes: U32,
    connections: U32, requests: U32, buffered: U32, header_ms: U32, body_ms: U32,
    idle_ms: U32, write_ms: U32}

# Shared framing settings; all live readers reserve admission before allocation.
type Limits is Data:
  Limits{body: Nat, headers: U32, header_ms: U32, body_ms: U32, idle_ms: U32, write_ms: U32}

# Bytes.words rounds with len+3 in U32. A retained cap plus the fixed 65536
# receive overshoot must still fit before that addition, including temporary copies.
def limits.representable() -> U32:
  4294901756

def limits(max: Nat) -> Limits:
  Limits{max, 65536, 5000, 30000, 30000, 30000}

def limits.config(config: ServerConfig) -> Limits:
  ServerConfig{host, port, body, headers, connections, requests, buffered, header_ms, body_ms, idle_ms, write_ms} = config
  Limits{U32.to_nat(body), headers, header_ms, body_ms, idle_ms, write_ms}

# One absolute deadline, never replenished by progress.
type Phase is Data:
  Phase{kind: U32, until: Time.Duration}

def phase.new(+kind: U32, ms: U32, now: Time.Duration) -> Phase:
  Phase{kind, Time.Duration.add(now, Time.Duration.of_ms(ms))}

def phase.remaining(+until: Time.Duration, +now: Time.Duration) -> U32:
  Bool.pick(U32, Cmp.is_lt(Time.Duration.cmp(now, until)),
    U32.max(1, Int.I64.to_u32(Time.Duration.to_ms(Time.Duration.sub(until, now)))), 0)

def bounded.sent(m: Socket & (U32 & Result<&1, &1, U32 & String, Unit>)) -> Socket & Result<&1, &1, U32 & String, Unit>:
  (s, (accepted, result)) = m
  (s, result)

def reply.bytes(res: Res, head: Bool, close: Bool) -> Bytes.Bytes:
  Res{+status, +headers, body} = res
  encode.on(Res{status, Bool.pick(Map<&2, List<&2, String>>, close, set(headers, "connection", "close"), headers), body}, head)

def reply.fail.bytes(+status: U32) -> Res:
  Res{status, set(empty(), "connection", "close"), Bytes.from_string(reason(status))}

def reply.drain.of(m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Socket & Bool:
  (s, r) = m
  match r:
    case Fail{e}:
      (s, False{})
    case Done{data}:
      (len, words) = data
      (s, Bool.not(U32.is_zero(len)))

# ponytail: cap drain at 32 MiB and 2.55 s; use socket half-close if larger peers need guaranteed delivery.
type Sv is Type:
  SvHead{buf: Bytes.Bytes}
  SvLen{req: Req, v11: Bool, left: U32, parts: List<&1, Bytes.Bytes>}
  SvChunk{req: Req, v11: Bool, n: U32, st: Dc, parts: List<&1, Bytes.Bytes>}

type InputOperation is Data:
  ReadInput{}
  SendContinue{}

# More: read on, first answering 100 Continue when cont is set.
type Turn is Type:
  TurnClose{}
  TurnInputFailed{operation: InputOperation, code: U32, message: String}
  TurnFail{status: U32}
  TurnReq{req: Req, rest: Bytes.Bytes, v11: Bool}
  TurnMore{sv: Sv, cont: Bool}

def serve.max() -> Nat:
  fetch.max()

def sv.none() -> Sv:
  SvHead{Bytes.new(0)}

def sv.body(req: Req, +v11: Bool, parts: List<&1, Bytes.Bytes>, rest: Bytes.Bytes) -> Turn:
  Req{method, path, headers, body} = req
  TurnReq{Req{method, path, headers, rb.body(parts)}, rest, v11}

def sv.len.cut(req: Req, +v11: Bool, parts: List<&1, Bytes.Bytes>, +len: U32, +left: U32, r: Bytes.Bytes & Bytes.Bytes) -> Turn:
  (piece, last) = r
  sv.body(req, v11, Con{last, parts}, bytes.snd(Bytes.slice(piece, left, (len - left : U32))))

def sv.len.have(short: Bool, req: Req, +v11: Bool, +left: U32, parts: List<&1, Bytes.Bytes>, +len: U32, piece: Bytes.Bytes) -> Turn:
  match short:
    case True{}:
      TurnMore{SvLen{req, v11, (left - len : U32), Con{piece, parts}}, False{}}
    case False{}:
      sv.len.cut(req, v11, parts, len, left, Bytes.slice(piece, 0, left))

def sv.len(req: Req, +v11: Bool, +left: U32, parts: List<&1, Bytes.Bytes>, piece: Bytes.Bytes) -> Turn:
  Bytes.Bytes{+len, buf} = piece
  sv.len.have(U32.is_lt(len, left), req, v11, left, parts, len, Bytes.Bytes{len, buf})

def sv.chunk.of(req: Req, +v11: Bool, +n: U32, c: Ck) -> Turn:
  Ck{st, parts, rest} = c
  match st:
    case DcDone{}:
      sv.body(req, v11, parts, rest)
    case DcBad{}:
      TurnFail{400}
    case DcSize{a, b}:
      TurnMore{SvChunk{req, v11, n, DcSize{a, b}, parts}, False{}}
    case DcExt{x}:
      TurnMore{SvChunk{req, v11, n, DcExt{x}, parts}, False{}}
    case DcSizeLf{x}:
      TurnMore{SvChunk{req, v11, n, DcSizeLf{x}, parts}, False{}}
    case DcData{k}:
      TurnMore{SvChunk{req, v11, n, DcData{k}, parts}, False{}}
    case DcDataCr{}:
      TurnMore{SvChunk{req, v11, n, DcDataCr{}, parts}, False{}}
    case DcDataLf{}:
      TurnMore{SvChunk{req, v11, n, DcDataLf{}, parts}, False{}}
    case DcTr{j}:
      TurnMore{SvChunk{req, v11, n, DcTr{j}, parts}, False{}}

def sv.chunk.parts.cons(+len: U32, buf: Array<U32>, counted: List<&1, Bytes.Bytes> & Nat) -> List<&1, Bytes.Bytes> & Nat:
  (rest, n) = counted
  (Con{Bytes.Bytes{len, buf}, rest}, Nat.add(U32.to_nat(len), n))

def sv.chunk.parts(xs: List<&1, Bytes.Bytes>, old: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes> & Nat:
  match xs:
    case Nil{}:
      (old, 0n)
    case Con{b, tail}:
      Bytes.Bytes{+len, buf} = b
      sv.chunk.parts.cons(len, buf, sv.chunk.parts(tail, old))

def sv.chunk.cap(big: Bool, req: Req, +v11: Bool, n: U32, st: Dc, parts: List<&1, Bytes.Bytes>, rest: Bytes.Bytes) -> Turn:
  match big:
    case True{}:
      TurnFail{413}
    case False{}:
      sv.chunk.of(req, v11, n, Ck{st, parts, rest})

def sv.chunk.counted(+max: Nat, req: Req, v11: Bool, n: U32, st: Dc, rest: Bytes.Bytes, counted: List<&1, Bytes.Bytes> & Nat) -> Turn:
  (parts, size) = counted
  +total = Nat.add(U32.to_nat(n), size)
  sv.chunk.cap(Nat.is_lt(max, total) || Nat.is_lt(U32.to_nat(4294967295), total), req, v11,
    U32.from_nat(total), st, parts, rest)

def sv.chunk.decoded(max: Nat, req: Req, v11: Bool, n: U32, old: List<&1, Bytes.Bytes>, c: Ck) -> Turn:
  Ck{st, parts, rest} = c
  sv.chunk.counted(max, req, v11, n, st, rest, sv.chunk.parts(parts, old))

def sv.chunk(+max: Nat, req: Req, +v11: Bool, +n: U32, st: Dc, parts: List<&1, Bytes.Bytes>, piece: Bytes.Bytes) -> Turn:
  sv.chunk.decoded(max, req, v11, n, parts, ck(piece, st, Nil{}))

# RFC 9110 §10.1.1: answer 100 Continue only when the body is still to come.
def sv.cont(want: Bool, t: Turn) -> Turn:
  match t:
    case TurnMore{sv, c}:
      TurnMore{sv, want}
    case TurnClose{}:
      TurnClose{}
    case TurnInputFailed{operation, code, message}:
      TurnInputFailed{operation, code, message}
    case TurnFail{s}:
      TurnFail{s}
    case TurnReq{req, rest, v11}:
      TurnReq{req, rest, v11}

def sv.cl.k(big: Bool, req: Req, +v11: Bool, +k: U32, rest: Bytes.Bytes) -> Turn:
  match big:
    case True{}:
      TurnFail{413}
    case False{}:
      sv.len(req, v11, k, Nil{}, rest)

def sv.cl(+max: Nat, req: Req, +v11: Bool, rest: Bytes.Bytes, n: Maybe<&2, U32>) -> Turn:
  match n:
    case None{}:
      TurnFail{400}
    case Some{+k}:
      sv.cl.k(Nat.is_lt(max, U32.to_nat(k)), req, v11, k, rest)

def sv.frame(+max: Nat, req: Req, +v11: Bool, rest: Bytes.Bytes, te: Bool) -> Turn:
  Req{method, path, +headers, body} = req
  match te:
    case True{}:
      sv.chunk(max, Req{method, path, headers, body}, v11, 0, dc.start(), Nil{}, rest)
    case False{}:
      sv.cl(max, Req{method, path, headers, body}, v11, rest, parse_u32(header(headers, "content-length")))

def sv.expects(+v11: Bool, +headers: Map<&2, List<&2, String>>) -> Bool:
  Bool.and(v11, String.eq(String.to_lower(header(headers, "expect")), "100-continue"))

def sv.got.head(+max: Nat, +v11: Bool, rest: Bytes.Bytes, req: Req) -> Turn:
  Req{method, path, +headers, body} = req
  sv.cont(sv.expects(v11, headers), sv.frame(max, Req{method, path, headers, body}, v11, rest, has_header(headers, "transfer-encoding")))

def sv.parsed(+max: Nat, +v11: Bool, rest: Bytes.Bytes, g: Got) -> Turn:
  match g:
    case GotBad{}:
      TurnFail{400}
    case GotMore{}:
      TurnFail{400}
    case GotReq{req}:
      TurnReq{req, rest, v11}
    case GotHead{req}:
      sv.got.head(max, v11, rest, req)

def sv.split(+max: Nat, +hlen: U32, +len: U32, r: Bytes.Bytes & Bytes.Bytes) -> Turn:
  (buf, hb) = r
  +head = Bytes.to_string(hb)
  sv.parsed(max, req.v11(head), bytes.snd(Bytes.slice(buf, hlen, (len - hlen : U32))), parse.got(head))

def sv.hit.none(big: Bool, buf: Bytes.Bytes) -> Turn:
  match big:
    case True{}:
      TurnFail{431}
    case False{}:
      TurnMore{SvHead{buf}, False{}}

def sv.hit.some(big: Bool, +max: Nat, +hlen: U32, +len: U32, buf: Bytes.Bytes) -> Turn:
  match big:
    case True{}:
      TurnFail{431}
    case False{}:
      sv.split(max, hlen, len, Bytes.slice(buf, 0, hlen))

# RFC 6585 §5: refuse a head over the configured byte limit.
def sv.hit(+max: Nat, +headers: U32, +len: U32, buf: Bytes.Bytes, at: Maybe<&2, U32>) -> Turn:
  match at:
    case None{}:
      sv.hit.none(U32.is_lt(headers, len), buf)
    case Some{+i}:
      +hlen = (i + 4 : U32)
      sv.hit.some(U32.is_lt(headers, hlen), max, hlen, len, buf)

def sv.seek.of(+max: Nat, +headers: U32, +len: U32, +from: U32, buf: Bytes.Bytes, r: Bytes.Bytes & Maybe<&2, U32>) -> Turn:
  (tail, m) = r
  sv.hit(max, headers, len, buf, found.at(from, m))

def sv.seek(+max: Nat, +headers: U32, +len: U32, +from: U32, r: Bytes.Bytes & Bytes.Bytes) -> Turn:
  (buf, tail) = r
  sv.seek.of(max, headers, len, from, buf, Bytes.find(tail, "\r\n\r\n"))

# Only the new bytes, and the 3 before them, can finish the blank line.
def sv.head.at(+max: Nat, +headers: U32, +from: U32, buf: Bytes.Bytes) -> Turn:
  Bytes.Bytes{+len, b} = buf
  sv.seek(max, headers, len, from, Bytes.slice(Bytes.Bytes{len, b}, from, (len - from : U32)))

def sv.head(+max: Nat, +headers: U32, buf: Bytes.Bytes, piece: Bytes.Bytes) -> Turn:
  Bytes.Bytes{+ol, ob} = buf
  sv.head.at(max, headers, Bool.pick(U32, U32.is_lt(ol, 3), 0, (ol - 3 : U32)), Bytes.append(Bytes.Bytes{ol, ob}, piece))

def sv.closed.pick(empty: Bool) -> Turn:
  match empty:
    case True{}:
      TurnClose{}
    case False{}:
      TurnFail{400}

def sv.closed.head(buf: Bytes.Bytes) -> Turn:
  Bytes.Bytes{+len, b} = buf
  sv.closed.pick(U32.is_eq(len, 0))

# A close mid-request is a request cut short (RFC 9112 §8).
def sv.step(closed: Bool, +max: Nat, +headers: U32, sv: Sv, piece: Bytes.Bytes) -> Turn:
  match closed:
    case True{}:
      match sv:
        case SvHead{buf}:
          sv.closed.head(buf)
        case SvLen{req, v11, left, parts}:
          TurnFail{400}
        case SvChunk{req, v11, n, st, parts}:
          TurnFail{400}
    case False{}:
      match sv:
        case SvHead{buf}:
          sv.head(max, headers, buf, piece)
        case SvLen{req, +v11, +left, parts}:
          sv.len(req, v11, left, parts, piece)
        case SvChunk{req, +v11, +n, st, parts}:
          sv.chunk(max, req, v11, n, st, parts, piece)

def sv.frame.req(t: Turn) -> Maybe<&1, String & String>:
  match t:
    case TurnReq{req, rest, v11}:
      Req{method, path, headers, body} = req
      Some{(Bytes.to_string(body), Bytes.to_string(rest))}
    case TurnMore{sv, c}:
      None{}
    case TurnFail{s}:
      None{}
    case TurnClose{}:
      None{}
    case TurnInputFailed{operation, code, message}:
      None{}

def sv.frame.go(xs: List<&2, String>, t: Turn) -> Maybe<&1, String & String>:
  match xs:
    case Nil{}:
      sv.frame.req(t)
    case Con{+x, rest}:
      match t:
        case TurnMore{sv, c}:
          sv.frame.go(rest, sv.step(False{}, serve.max(), 65536, sv, Bytes.from_string(x)))
        case TurnReq{req, r, v11}:
          sv.frame.req(TurnReq{req, r, v11})
        case TurnFail{s}:
          None{}
        case TurnClose{}:
          None{}
        case TurnInputFailed{operation, code, message}:
          None{}

# The body and the bytes after it, once the pieces make a whole request; None otherwise.
def serve.frame(xs: List<&2, String>) -> Maybe<&1, String & String>:
  sv.frame.go(xs, TurnMore{sv.none(), False{}})

def talk.piece(settings: Limits, sv: Sv, p: U32 & Array<U32>) -> Turn:
  Limits{max, headers, hm, bm, im, wm} = settings
  (+len, buf) = p
  sv.step(U32.is_eq(len, 0), max, headers, sv, Bytes.Bytes{len, buf})

def talk.next(settings: Limits, sv: Sv, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Socket & Turn:
  (s, r) = m
  match r:
    case Fail{(+code, message)}:
      (s, Bool.pick(Turn, err.late(code), TurnFail{408}, TurnInputFailed{ReadInput{}, code, message}))
    case Done{p}:
      (s, talk.piece(settings, sv, p))

def talk.after.pick(empty: Bool, settings: Limits, rest: Bytes.Bytes) -> Turn:
  match empty:
    case True{}:
      TurnMore{sv.none(), False{}}
    case False{}:
      Limits{max, headers, hm, bm, im, wm} = settings
      sv.step(False{}, max, headers, sv.none(), rest)

def talk.after.rest(settings: Limits, rest: Bytes.Bytes, s: Socket) -> Socket & Turn:
  Bytes.Bytes{+len, buf} = rest
  (s, talk.after.pick(U32.is_eq(len, 0), settings, Bytes.Bytes{len, buf}))

def talk.after.keep(keep: Bool, settings: Limits, rest: Bytes.Bytes, s: Socket) -> Socket & Turn:
  match keep:
    case False{}:
      (s, TurnClose{})
    case True{}:
      talk.after.rest(settings, rest, s)

def phase.head(empty: Bool, settings: Limits, now: Time.Duration) -> Phase:
  match empty:
    case True{}:
      Limits{max, cap, hm, bm, im, wm} = settings
      phase.new(0, im, now)
    case False{}:
      Limits{max, cap, hm, bm, im, wm} = settings
      phase.new(1, hm, now)

def phase.start(settings: Limits, sv: Sv, now: Time.Duration) -> Phase & Sv:
  Limits{max, cap, hm, bm, im, wm} = settings
  match sv:
    case SvHead{buf}:
      Bytes.Bytes{+len, words} = buf
      (phase.head(U32.is_zero(len), Limits{max, cap, hm, bm, im, wm}, now), SvHead{Bytes.Bytes{len, words}})
    case SvLen{req, v11, left, parts}:
      (phase.new(2, bm, now), SvLen{req, v11, left, parts})
    case SvChunk{req, v11, n, st, parts}:
      (phase.new(2, bm, now), SvChunk{req, v11, n, st, parts})

def phase.select(settings: Limits, sv: Sv, now: Time.Duration, previous: Maybe<&2, Phase>) -> Phase & Sv:
  match previous:
    case None{}:
      phase.start(settings, sv, now)
    case Some{phase}:
      (phase, sv)

# Buffered pipelined headers have already ended before upload callbacks run.
def phase.body(previous: Maybe<&2, Phase>, settings: Limits, now: Time.Duration) -> Phase:
  match previous:
    case Some{phase}:
      phase
    case None{}:
      Limits{max, cap, hm, bm, im, wm} = settings
      phase.new(2, bm, now)

def phase.after(+settings: Limits, +now: Time.Duration, +phase: Phase, t: Turn) -> Turn & Phase:
  Limits{max, cap, hm, bm, im, wm} = settings
  Phase{+kind, until} = phase
  match t:
    case TurnMore{sv, cont}:
      match sv:
        case SvHead{buf}:
          (TurnMore{SvHead{buf}, cont}, Bool.pick(Phase, U32.is_zero(kind), phase.new(1, hm, now), phase))
        case SvLen{req, v11, left, parts}:
          (TurnMore{SvLen{req, v11, left, parts}, cont}, Bool.pick(Phase, U32.is_eq(kind, 2), phase, phase.new(2, bm, now)))
        case SvChunk{req, v11, n, st, parts}:
          (TurnMore{SvChunk{req, v11, n, st, parts}, cont}, Bool.pick(Phase, U32.is_eq(kind, 2), phase, phase.new(2, bm, now)))
    case TurnReq{req, rest, v11}:
      (TurnReq{req, rest, v11}, phase)
    case TurnFail{+status}:
      (Bool.pick(Turn, U32.is_zero(kind) && U32.is_eq(status, 408), TurnClose{}, TurnFail{status}), phase)
    case TurnClose{}:
      (TurnClose{}, phase)
    case TurnInputFailed{operation, code, message}:
      (TurnInputFailed{operation, code, message}, phase)

def phase.expired(phase: Phase) -> Turn:
  Phase{kind, until} = phase
  Bool.pick(Turn, U32.is_zero(kind), TurnClose{}, TurnFail{408})

def talk.received.state(s: Socket, next: Turn & Phase) -> (Socket & Turn) & Phase:
  (t, p) = next
  ((s, t), p)

def talk.received.phase(settings: Limits, phase: Phase, now: Time.Duration, next: Socket & Turn) -> (Socket & Turn) & Phase:
  (s, t) = next
  talk.received.state(s, phase.after(settings, now, phase, t))

def talk.received.late(expired: Bool, +settings: Limits, +phase: Phase, now: Time.Duration, sv: Sv, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> (Socket & Turn) & Phase:
  match expired:
    case True{}:
      (s, r) = m
      ((s, phase.expired(phase)), phase)
    case False{}:
      talk.received.phase(settings, phase, now, talk.next(settings, sv, m))

# A real host read slice returns its socket; no raced operation is abandoned.
# The original absolute phase survives slice timeouts and stop observations.
# Admitted streamed uploads retain their state and finish; unadmitted input closes.
type ReadStep is Type:
  ReadChecking{socket: Socket, state: Sv, phase: Phase}
  ReadAllowed{running: Bool, socket: Socket, state: Sv, phase: Phase}
  ReadBudget{ms: U32, socket: Socket, state: Sv, phase: Phase}
  ReadReceived{state: Sv, phase: Phase, now: Time.Duration,
    result: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>}
  ReadFailed{retry: Bool, socket: Socket, state: Sv, phase: Phase,
    now: Time.Duration, error: U32 & String}

# One state machine owns the socket through each actual host return.
type Serving is Type:
  Serving{connection: Socket & Turn, phase: Maybe<&2, Phase>}

def talk.state(received: (Socket & Turn) & Phase) -> Serving:
  (connection, phase) = received
  Serving{connection, Some{phase}}

def serve.write.state(after: Maybe<&1, Socket & Turn>) -> Maybe<&1, Serving>:
  match after:
    case None{}:
      None{}
    case Some{connection}:
      Some{Serving{connection, None{}}}

# A buffered-work unit owns one connection's incomplete request, decoded body,
# and pipelined remainder from before its first recv until the task really returns.
# ponytail: idle sockets also reserve buffer units; split idle/read leases if idle utilization matters.
def admission.head(req: Req) -> Bool:
  Req{method, path, headers, body} = req
  String.eq(method, "HEAD")

def admission.turn.head(turn: Turn) -> Bool:
  match turn:
    case TurnReq{req, rest, v11}:
      admission.head(req)
    case TurnMore{sv, cont}:
      match sv:
        case SvHead{buf}:
          False{}
        case SvLen{req, v11, left, parts}:
          admission.head(req)
        case SvChunk{req, v11, n, state, parts}:
          admission.head(req)
    case TurnFail{status}:
      False{}
    case TurnClose{}:
      False{}
    case TurnInputFailed{operation, code, message}:
      False{}

# This rejection has parsed metadata, so normal HEAD body suppression still applies.
type StartupError is Data:
  InvalidConfig{}
  BindError{code: U32, message: String}

# Application-owned affine dependencies never enter this transport owner.
def server.config(host: String, port: U32) -> ServerConfig:
  ServerConfig{host, port, 16777216, 65536, 128, 128, 128, 5000, 30000, 30000, 30000}

def server.config.with(host: String, port: U32, max: Nat) -> ServerConfig:
  ServerConfig{host, port, U32.from_nat(max), 65536, 128, 128, 128, 5000, 30000, 30000, 30000}

# Host deadline effects use signed 32-bit milliseconds.
def server.deadline.valid(+ms: U32) -> Bool:
  U32.is_gt(ms, 0) && U32.is_le(ms, 2147483647)

def server.config.valid(config: ServerConfig) -> Bool:
  ServerConfig{host, port, +body, +headers, connections, requests, buffered, header_ms, body_ms, idle_ms, write_ms} = config
  U32.is_le(port, 65535) && U32.is_gt(body, 0) && U32.is_le(body, limits.representable()) &&
    U32.is_gt(headers, 0) && U32.is_le(headers, limits.representable()) &&
    U32.is_gt(connections, 0) && U32.is_gt(requests, 0) && U32.is_gt(buffered, 0) &&
    server.deadline.valid(header_ms) && server.deadline.valid(body_ms) &&
    server.deadline.valid(idle_ms) && server.deadline.valid(write_ms)

type ServerCounts is Data:
  ServerCounts{connections: U32, active: U32, buffered: U32,
    connection_high: U32, active_high: U32, buffered_high: U32,
    connection_rejected: Nat, active_rejected: Nat, buffered_rejected: Nat}

type ServerExit is Data:
  ServerStopped{counts: ServerCounts}
  ServerAcceptFailed{code: U32, message: String, counts: ServerCounts}

def server.finished(stopped: Bool, error: U32 & String, counts: ServerCounts) -> ServerExit:
  match stopped:
    case True{}:
      ServerStopped{counts}
    case False{}:
      (code, message) = error
      ServerAcceptFailed{code, message, counts}

def error.stopped(error: U32 & String) -> Bool:
  (code, message) = error
  U32.is_zero(code) && String.eq(message, "server stopped")

def error.capacity(error: U32 & String) -> Bool:
  (code, message) = error
  U32.is_eq(code, 11) && String.eq(message, "transport capacity exhausted")


# A single recursive state machine avoids recursion hidden inside a template.
def admission.ready(t: Turn) -> Bool & Turn:
  match t:
    case TurnReq{req, rest, v11}:
      (True{}, TurnReq{req, rest, v11})
    case TurnMore{sv, cont}:
      match sv:
        case SvHead{buf}:
          (False{}, TurnMore{SvHead{buf}, cont})
        case SvLen{req, v11, left, parts}:
          (True{}, TurnMore{SvLen{req, v11, left, parts}, cont})
        case SvChunk{req, v11, n, state, parts}:
          (True{}, TurnMore{SvChunk{req, v11, n, state, parts}, cont})
    case TurnFail{status}:
      (False{}, TurnFail{status})
    case TurnClose{}:
      (False{}, TurnClose{})
    case TurnInputFailed{operation, code, message}:
      (False{}, TurnInputFailed{operation, code, message})

type StreamServing<-S: Type> is Type:
  StreamCheck{held: Bool, connection: Serving, state: Maybe<&1, S & Bool>}
  StreamReady{held: Bool, ready: Bool, connection: Serving, state: Maybe<&1, S & Bool>}
  StreamChecked{held: Bool, admitted: Bool, connection: Serving, state: Maybe<&1, S & Bool>}
  StreamDone{}

def serve.stream.after(~S: Type, next: Maybe<&1, Socket & Turn>) -> StreamServing<S>:
  match next:
    case None{}:
      StreamDone{}
    case Some{connection}:
      StreamCheck{False{}, Serving{connection, None{}}, None{}}

def serve.stream.ready(~S: Type, held: Bool, socket: Socket, phase: Maybe<&2, Phase>,
  state: Maybe<&1, S & Bool>, result: Bool & Turn) -> StreamServing<S>:
  (ready, turn) = result
  StreamReady{held, ready, Serving{(socket, turn), phase}, state}

type StreamAbort is Data:
  StreamClosed{}
  StreamFailed{status: U32}
  StreamInputFailed{operation: InputOperation, code: U32, message: String}

# The application consumes its real affine state on unsuccessful upload paths.
# An abort that does not return remains admitted work, not a fabricated drain.
type WriterMode is Data:
  WriteKnown{left: U32}
  WriteChunk{}
  WriteNone{}

def writer.header.one(m: Map<&2, List<&2, String>>, +key: String, vs: List<&2, String>, framing: Bool) -> Map<&2, List<&2, String>>:
  match framing:
    case True{}:
      m
    case False{}:
      Map.set(&2, List<&2, String>, m, key, vs)

def writer.headers(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>, m: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match xs:
    case Nil{}:
      m
    case (k, vs) <> rest:
      +key = String.to_lower(k)
      +framing = Bool.or(String.eq(key, "content-length"), String.eq(key, "transfer-encoding"))
      writer.headers(rest, writer.header.one(m, key, vs, framing))

def writer.plan.body(headers: Map<&2, List<&2, String>>, length: Maybe<&2, U32>) -> WriterMode & Map<&2, List<&2, String>>:
  match length:
    case Some{+n}:
      (WriteKnown{n}, set(headers, "content-length", U32.show(n)))
    case None{}:
      (WriteChunk{}, set(headers, "transfer-encoding", "chunked"))

def writer.plan(nobody: Bool, headers: Map<&2, List<&2, String>>, length: Maybe<&2, U32>) -> WriterMode & Map<&2, List<&2, String>>:
  match nobody:
    case True{}:
      (WriteNone{}, headers)
    case False{}:
      writer.plan.body(headers, length)

def serve.write.after(settings: Limits, keep: Bool, rest: Bytes.Bytes, socket: Maybe<&1, Socket>) -> Maybe<&1, Socket & Turn>:
  match socket:
    case None{}:
      None{}
    case Some{s}:
      Some{talk.after.keep(keep, settings, rest, s)}

def writer.connection(keep: Bool, headers: Map<&2, List<&2, String>>) -> Map<&2, List<&2, String>>:
  match keep:
    case True{}:
      headers
    case False{}:
      set(headers, "connection", "close")

