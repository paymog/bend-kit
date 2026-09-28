# HTTP/1.1 and HTTP/2 client, with an HTTP/1.1 server. Source: https://github.com/paymog/bend-kit/tree/main/http
import Base
# By hash: bend-kit-url@0.4.1.0, -encoding@0.3.0.0, -json@0.5.0.1, -bytes@0.3.0.0, -dns@0.4.0.1, -zlib@0.1.5.0.
import bend-kit-wire@0.4.2.0/wire.bend as Wire
import bend-kit-http2@0.1.2.0/http2.bend as H2
import bend-kit-http2@0.1.2.0/hpack.bend as Hpack
import bend-kit-bytes@0.3.1.0/bytes.bend as HBytes
import bend-kit-time@0.1.0.0/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-concurrency@0.1.0.0/concurrency.bend as Conc
import 0x1f2d80f53f971b16c6de6a65cb1918ae/url.bend as Url
import 0xcfc8be7b076f41f95c8e118383892d55/encoding.bend as Enc
import 0x584fc27920487ceab242392391418d7f/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import 0x296c14c91cb121bd2f42e9d9f730480d/dns.bend as Dns
import 0x58bd522479d133cfe1b2c4451fc1a28f/zlib.bend as Zlib

# HTTP/1.1 codec and client (RFC 9112) for http:// and https:// (OpenSSL 3 at run time).
# parse: start-line → field lines → blank → body length (§6.3); chunked (§7.1).
# Bodies are Bytes. The String parsers below are the spec: one Char per octet.
# fetch reads until frame() says the response is whole. It returns Result, not Maybe.
# Build with -o for big bodies: the `bend file.bend` runner overflows on ~30 KB strings; native binaries do not.
#   import bend-kit-http@0.22.0.0/http.bend as Http

type Req is Type:
  Req{method: String, path: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

type Res is Type:
  Res{status: U32, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

# The body type and its conversions, so a caller needs no bytes import.
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

def parse.headers(xs: List<&2, String>, acc: Fields) -> Maybe<&2, Map<&2, List<&2, String>>>:
  match xs:
    case Nil{}:
      parse.headers.done(acc)
    case Con{line, rest}:
      parse.headers(rest, fields_put(acc, drop_cr(line)))

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

def parse.target(method: String, +path: String, headers: List<&2, String>, rest: String, v11: Bool, ok: Bool) -> Got:
  match ok:
    case False{}:
      GotBad{}
    case True{}:
      parse.fields(method, path, rest, v11, parse.headers(headers, FieldsOk{empty()}))

def parse.ver(method: String, +path: String, +v: String, headers: List<&2, String>, rest: String, ok: Bool) -> Got:
  match ok:
    case False{}:
      GotBad{}
    case True{}:
      parse.target(method, path, headers, rest, String.eq(v, "HTTP/1.1"), target_ok(path))

def parse.empty_method(method: String, path: String, +v: String, headers: List<&2, String>, rest: String, empty: Bool) -> Got:
  match empty:
    case True{}:
      GotBad{}
    case False{}:
      parse.ver(method, path, v, headers, rest, Bool.or(String.eq(v, "HTTP/1.1"), String.eq(v, "HTTP/1.0")))

def parse.start3(mpv: String & String & String, headers: List<&2, String>, rest: String) -> Got:
  (+method, path, v) = mpv
  parse.empty_method(method, path, v, headers, rest, String.is_empty(method))

def parse.lines(xs: List<&2, String>, rest: String) -> Got:
  match xs:
    case Nil{}:
      GotBad{}
    case Con{line, headers}:
      parse.start3(start_line(line), headers, rest)


def parse.head(+head: String, rest: String, whole: Bool) -> Got:
  match whole:
    case False{}:
      GotMore{}
    case True{}:
      parse.lines(String.lines(head), rest)

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

def parse.res.num(code: Maybe<&2, U32>, headers: List<&2, String>, rest: String, closed: Bool, head: Bool) -> Frame:
  match code:
    case None{}:
      FrameBad{}
    case Some{n}:
      parse.res.fields(n, rest, parse.headers(headers, FieldsOk{empty()}), closed, head)

def parse.res.ver(code: String, headers: List<&2, String>, rest: String, closed: Bool, head: Bool, ok: Bool) -> Frame:
  match ok:
    case False{}:
      FrameBad{}
    case True{}:
      parse.res.num(parse_u32(code), headers, rest, closed, head)

def parse.res.start3(mpv: String & String & String, headers: List<&2, String>, rest: String, closed: Bool, head: Bool) -> Frame:
  (+ver, code, reason) = mpv
  parse.res.ver(code, headers, rest, closed, head, Bool.or(String.eq(ver, "HTTP/1.1"), String.eq(ver, "HTTP/1.0")))

def parse.res.lines(xs: List<&2, String>, rest: String, closed: Bool, head: Bool) -> Frame:
  match xs:
    case Nil{}:
      FrameBad{}
    case Con{line, headers}:
      parse.res.start3(start_line(line), headers, rest, closed, head)

def parse.res.blank(hd: String, rest: String, +closed: Bool, head: Bool, ok: Bool) -> Frame:
  match ok:
    case False{}:
      frame.cut(closed)
    case True{}:
      parse.res.lines(String.lines(hd), rest, closed, head)

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

def io.recv.words(tls: Bool, s: Socket, max: U32, ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match tls:
    case True{}:
      Wire.tls.recv.words(s, max, ms)
    case False{}:
      Wire.recv.words(s, max, ms)

def io.send(tls: Bool, s: Socket, data: String) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send(s, data)
    case False{}:
      Wire.send(s, data)

def io.send.words(tls: Bool, s: Socket, +len: U32, buf: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send.words(s, len, buf)
    case False{}:
      Wire.send.words(s, len, buf)

def io.send.bytes(tls: Bool, s: Socket, b: Bytes.Bytes) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  Bytes.Bytes{+len, buf} = b
  io.send.words(tls, s, len, buf)

def io.close(tls: Bool, s: Socket) -> IO(Unit):
  match tls:
    case True{}:
      Wire.tls.close(s)
    case False{}:
      Socket.close(s)

def fetch.close(tls: Bool, s: Socket, r: Result<&1, &1, Err, Res>) -> IO(Result<&1, &1, Err, Res>):
  do IO<Result<&1, &1, Err, Res>>:
    io.close(tls, s)
    return r

# none: no response byte arrived, so an idempotent request may be retried (RFC 9112 §9.3.1).
# sock: the socket, when it can take another request.
type Out is Type:
  OutDone{res: Res, sock: Maybe<&1, Socket>, rest: Bytes.Bytes}
  OutFail{e: Err, none: Bool}

def fetch.boxed(r: Result<&1, &1, Err, Res>, none: Bool) -> Out:
  match r:
    case Done{res}:
      OutDone{res, None{}, Bytes.new(0)}
    case Fail{e}:
      OutFail{e, none}

def fetch.bad(tls: Bool, s: Socket, e: Maybe<&2, Err>) -> IO(Result<&1, &1, Err, Res>):
  match e:
    case None{}:
      fetch.close(tls, s, Fail{ErrBad{}})
    case Some{err}:
      fetch.close(tls, s, Fail{err})

def fetch.shut(tls: Bool, s: Socket, r: Result<&1, &1, Err, Res>, none: Bool) -> IO(Out):
  do IO<Out>:
    x : Result<&1, &1, Err, Res> <- fetch.close(tls, s, r)
    return fetch.boxed(x, none)

def fetch.hold.go(tls: Bool, s: Socket, res: Res, left: Maybe<&1, Bytes.Bytes>) -> IO(Out):
  match left:
    case Some{x}:
      IO.pure(Out, OutDone{res, Some{s}, x})
    case None{}:
      fetch.shut(tls, s, Done{res}, False{})

def fetch.hold(tls: Bool, close: Bool, s: Socket, res: Res, left: Maybe<&1, Bytes.Bytes>) -> IO(Out):
  Res{status, +headers, body} = res
  fetch.hold.go(tls, s, Res{status, headers, body}, again(close, headers, left))

def fetch.failout(tls: Bool, s: Socket, e: Maybe<&2, Err>, none: Bool) -> IO(Out):
  do IO<Out>:
    r : Result<&1, &1, Err, Res> <- fetch.bad(tls, s, e)
    return fetch.boxed(r, none)

# Read state: the response so far and the bytes read, or how it ended.
# none: no byte arrived, so an idempotent request may be retried.
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
@unsafe
def fetch.loop(+close: Bool, +head: Bool, +tls: Bool, +ms: U32, st: Socket & Fl) -> IO(Out):
  (s, fl) = st
  match fl:
    case FlMore{rv, +n}:
      do IO<Out>:
        m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv.words(tls, s, 65536, ms)
        fetch.loop(close, head, tls, ms, fetch.next(head, rv, n, m))
    case FlBad{err, none}:
      fetch.failout(tls, s, err, none)
    case FlDone{res, rest}:
      fetch.hold(tls, close, s, res, rest)

def exchange.sent(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Out):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      fetch.shut(tls, s, Fail{err.or_late(code, ErrWrite{code, why})}, True{})
    case Done{u}:
      fetch.loop(close, head, tls, ms, (s, FlMore{rv.start(), 0}))

def exchange.go(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, s: Socket, wire: Bytes.Bytes) -> IO(Out):
  do IO<Out>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(tls, s, wire)
    exchange.sent(tls, ms, close, head, sent)

def exchange.tup(o: Out) -> Maybe<&1, Socket> & Result<&1, &1, Err, Res> & Bytes.Bytes:
  match o:
    case OutFail{e, none}:
      (None{}, Fail{e}, Bytes.new(0))
    case OutDone{res, sock, rest}:
      (sock, Done{res}, rest)

# One request on an open socket. Some{socket}: it can take another request.
def exchange(+tls: Bool, +ms: U32, +close: Bool, +head: Bool, s: Socket, wire: Bytes.Bytes) -> IO(Maybe<&1, Socket> & Result<&1, &1, Err, Res> & Bytes.Bytes):
  do IO<Maybe<&1, Socket> & Result<&1, &1, Err, Res> & Bytes.Bytes>:
    o : Out <- exchange.go(tls, ms, close, head, s, wire)
    return exchange.tup(o)

# Paths to a PEM client chain and its private key for mutual TLS.
type Cert is Data:
  Cert{chain: String, key: String}

type Proxy is Data:
  ProxyDirect{}
  ProxyVia{host: String, port: U32, authorization: String}

type Route is Data:
  RouteDirect{tls: Bool, host: String, port: U32, cert: Maybe<&2, Cert>}
  RouteProxy{tls: Bool, host: String, port: U32, sni: String,
    authority: String, authorization: String, cert: Maybe<&2, Cert>}

# Connection pool: idle sockets by origin and client identity, newest first, at most cap per key.
# fetch uses a fresh pool per call.

type Conn is Type:
  Conn{tls: Bool, s: Socket}
  ConnH2{s: Socket, client: H2.Client}

type Send is Type:
  Send{method: String, target: String, authority: String,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

type H2Step is Type:
  H2Reply{s: Socket, reply: H2.Reply}
  H2Sent{client: H2.Client, events: List<&1, H2.ClientEvent>,
    sent: Result<&1, &1, Err, Socket>}
  H2Events{s: Socket, client: H2.Client, result: Result<&1, &1, Err, Maybe<&1, Res>>}
  H2Received{client: H2.Client,
    answer: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>}

type TunnelStep is Type:
  TunnelRead{s: Socket, raw: String}
  TunnelHead{s: Socket, raw: String, frame: Frame}
  TunnelGot{raw: String,
    answer: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>}

type Pool is Type:
  Pool{cap: U32, idle: Map<&1, List<&1, Conn>>}

def pool.new.with(+cap: U32) -> Pool:
  Pool{cap, Map.new(&1, List<&1, Conn>)}

# Up to 8 idle sockets per origin.
def pool.new() -> Pool:
  pool.new.with(8)

def pool.key(+scheme: String, +host: String, +port: U32) -> String:
  scheme ++ "://" ++ host ++ ":" ++ U32.show(port)

def pool.key.cert(+base: String, cert: Maybe<&2, Cert>) -> String:
  match cert:
    case None{}:
      base
    case Some{Cert{+chain, +key}}:
      base ++ "|cert:" ++ Nat.show(String.length(chain)) ++ ":" ++ chain
        ++ Nat.show(String.length(key)) ++ ":" ++ key

def pool.take.of(+cap: U32, +key: String, r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> Pool & Maybe<&1, Conn>:
  (m, got) = r
  match got:
    case None{}:
      (Pool{cap, m}, None{})
    case Some{xs}:
      match xs:
        case Nil{}:
          (Pool{cap, m}, None{})
        case Con{c, t}:
          (Pool{cap, Map.set(&1, List<&1, Conn>, m, key, t)}, Some{c})

# The socket given back last.
def pool.take(p: Pool, +key: String) -> Pool & Maybe<&1, Conn>:
  Pool{+cap, idle} = p
  pool.take.of(cap, key, Map.pop(&1, List<&1, Conn>, idle, key))

def conn.close(c: Conn) -> IO(Unit):
  match c:
    case Conn{tls, s}:
      io.close(tls, s)
    case ConnH2{s, client}:
      Wire.tls.close(s)

# The first n sockets; the rest are closed.
def conns.cut(xs: List<&1, Conn>, n: Nat) -> IO(List<&1, Conn>):
  match xs:
    case Nil{}:
      IO.pure(List<&1, Conn>, Nil{})
    case Con{c, t}:
      match n:
        case 0n:
          do IO<List<&1, Conn>>:
            conn.close(c)
            conns.cut(t, 0n)
        case 1n+k:
          do IO<List<&1, Conn>>:
            r : List<&1, Conn> <- conns.cut(t, k)
            return c <> r

def pool.give.of(+cap: U32, +key: String, c: Conn, limit: Nat,
    r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> IO(Pool):
  (m, old) = r
  do IO<Pool>:
    xs : List<&1, Conn> <- conns.cut(c <> Maybe.default(&1, List<&1, Conn>, old, Nil{}), limit)
    return Pool{cap, Map.set(&1, List<&1, Conn>, m, key, xs)}

# Past the limit (cap for HTTP/1.1, one session for HTTP/2), close the oldest idle connection.
def pool.give(p: Pool, +key: String, c: Conn) -> IO(Pool):
  Pool{+cap, idle} = p
  match c:
    case Conn{tls, s}:
      pool.give.of(cap, key, Conn{tls, s}, U32.to_nat(cap), Map.pop(&1, List<&1, Conn>, idle, key))
    case ConnH2{s, client}:
      pool.give.of(cap, key, ConnH2{s, client}, Bool.pick(Nat, U32.is_zero(cap), 0n, 1n),
        Map.pop(&1, List<&1, Conn>, idle, key))

def pool.close.go(xs: List<&1, List<&1, Conn>>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{cs, t}:
      do IO<Unit>:
        none : List<&1, Conn> <- conns.cut(cs, 0n)
        pool.close.go(t)

def pool.close(p: Pool) -> IO(Unit):
  Pool{cap, idle} = p
  pool.close.go(Map.values(&1, List<&1, Conn>, idle))

# RFC 9110 §9.2.2
def pool.idempotent(+method: String) -> Bool:
  Bool.or(String.eq(method, "GET"), Bool.or(String.eq(method, "HEAD"), Bool.or(String.eq(method, "OPTIONS"), Bool.or(String.eq(method, "TRACE"), Bool.or(String.eq(method, "PUT"), String.eq(method, "DELETE"))))))

def conn.tls(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Err, Conn>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Err, Conn>>:
        Wire.tls.close(s)
        return Fail{err.or_late(code, ErrTls{code, why})}
    case Done{u}:
      IO.pure(Result<&1, &1, Err, Conn>, Done{Conn{True{}, s}})

def conn.h2.sent(client: H2.Client, r: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Err, Conn>):
  (s, sent) = r
  match sent:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Err, Conn>>:
        Wire.tls.close(s)
        return Fail{err.or_late(code, ErrWrite{code, why})}
    case Done{u}:
      IO.pure(Result<&1, &1, Err, Conn>, Done{ConnH2{s, client}})

def conn.h2.start(s: Socket, r: H2.Client & HBytes.Bytes) -> IO(Result<&1, &1, Err, Conn>):
  (client, HBytes.Bytes{len, buf}) = r
  do IO<Result<&1, &1, Err, Conn>>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send.words(s, len, buf)
    conn.h2.sent(client, sent)

def conn.tls.protocol(proto: String, s: Socket) -> IO(Result<&1, &1, Err, Conn>):
  match proto:
    case "h2":
      conn.h2.start(s, H2.client.start())
    case "http/1.1":
      IO.pure(Result<&1, &1, Err, Conn>, Done{Conn{True{}, s}})
    case "":
      IO.pure(Result<&1, &1, Err, Conn>, Done{Conn{True{}, s}})
    case other:
      do IO<Result<&1, &1, Err, Conn>>:
        Wire.tls.close(s)
        return Fail{ErrTls{71, "unsupported ALPN: " ++ other}}

def conn.tls.alpn(m: Socket & Result<&1, &1, U32 & String, String>) -> IO(Result<&1, &1, Err, Conn>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Err, Conn>>:
        Wire.tls.close(s)
        return Fail{err.or_late(code, ErrTls{code, why})}
    case Done{proto}:
      conn.tls.protocol(proto, s)

def conn.secure.no.cert(offer: Bool, s: Socket, host: String, +ms: U32) ->
    IO(Result<&1, &1, Err, Conn>):
  match offer:
    case True{}:
      do IO<Result<&1, &1, Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, String> <-
          Wire.tls.connect.alpn(s, host, ms, "h2,http/1.1")
        conn.tls.alpn(hs)
    case False{}:
      do IO<Result<&1, &1, Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, host, ms)
        conn.tls(hs)

def conn.secure.tls(cert: Maybe<&2, Cert>, s: Socket, host: String, +ms: U32,
    offer: Bool) -> IO(Result<&1, &1, Err, Conn>):
  match cert:
    case None{}:
      conn.secure.no.cert(offer, s, host, ms)
    case Some{Cert{chain, key}}:
      do IO<Result<&1, &1, Err, Conn>>:
        hs : Socket & Result<&1, &1, U32 & String, Unit> <-
          Wire.tls.connect.cert(s, host, ms, chain, key)
        conn.tls(hs)

# A failed handshake is an error, never plaintext.
def conn.secure(+ms: U32, sni: String, s: Socket, tls: Bool,
    cert: Maybe<&2, Cert>, offer: Bool) -> IO(Result<&1, &1, Err, Conn>):
  match tls:
    case False{}:
      IO.pure(Result<&1, &1, Err, Conn>, Done{Conn{False{}, s}})
    case True{}:
      conn.secure.tls(cert, s, sni, ms, offer)

def conn.made(+ms: U32, sni: String, tls: Bool, cert: Maybe<&2, Cert>,
    offer: Bool, r: Result<&1, &1, U32 & String, Socket>) ->
    IO(Result<&1, &1, Err, Conn>):
  match r:
    case Fail{(+code, why)}:
      IO.pure(Result<&1, &1, Err, Conn>, Fail{err.or_late(code, ErrConnect{code, why})})
    case Done{s}:
      conn.secure(ms, sni, s, tls, cert, offer)

def conn.open(+tls: Bool, +ms: U32, sni: String, ip: String, port: U32) ->
    IO(Result<&1, &1, Err, Conn>):
  do IO<Result<&1, &1, Err, Conn>>:
    c : Result<&1, &1, U32 & String, Socket> <- Wire.connect(ip, port, ms)
    conn.made(ms, sni, tls, None{}, False{}, c)

# ponytail: addresses are tried in order, not raced; a broken first route can consume the step timeout.
type Dial is Type:
  Dial{port: U32, ms: U32, deadline: Nat, action: IO(Result<&1, &1, U32 & String, Socket>)}

def conn.dial.time(+ip: String, +port: U32, +deadline: Nat, now: Nat, expired: Bool) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  match expired:
    case True{}:
      IO.pure(Result<&1, &1, U32 & String, Socket>, Fail{(60, "connect timeout")})
    case False{}:
      Wire.connect(ip, port, U32.from_nat(Nat.sub(deadline, now)))

def conn.dial.with(+ip: String, +port: U32, +ms: U32, +deadline: Nat, +now: Nat, unlimited: Bool) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  match unlimited:
    case True{}:
      Wire.connect(ip, port, 0)
    case False{}:
      conn.dial.time(ip, port, deadline, now, Nat.is_le(deadline, now))

def conn.dial.try(+ip: String, +port: U32, +ms: U32, +deadline: Nat) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  do IO<Result<&1, &1, U32 & String, Socket>>:
    now : Nat <- IO.now()
    conn.dial.with(ip, port, ms, deadline, now, U32.is_zero(ms))

def conn.dial.after(r: Result<&1, &1, U32 & String, Socket>, ip: String, +port: U32, +ms: U32, +deadline: Nat) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  match r:
    case Done{s}:
      IO.pure(Result<&1, &1, U32 & String, Socket>, Done{s})
    case Fail{e}:
      conn.dial.try(ip, port, ms, deadline)

def conn.dial.more(prev: IO(Result<&1, &1, U32 & String, Socket>), ip: String, +port: U32, +ms: U32, +deadline: Nat) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  do IO<Result<&1, &1, U32 & String, Socket>>:
    r : Result<&1, &1, U32 & String, Socket> <- prev
    conn.dial.after(r, ip, port, ms, deadline)

def conn.dial.fold(d: Dial, ip: String) -> Dial:
  Dial{+port, +ms, +deadline, action} = d
  Dial{port, ms, deadline, conn.dial.more(action, ip, port, ms, deadline)}

def conn.dial.run(d: Dial) -> IO(Result<&1, &1, U32 & String, Socket>):
  Dial{port, ms, deadline, action} = d
  action

def conn.dial.all(+port: U32, +ms: U32, +start: Nat, first: String, rest: List<&2, String>) ->
  IO(Result<&1, &1, U32 & String, Socket>):
  match rest:
    case Nil{}:
      Wire.connect(first, port, ms)
    case Con{ip, tail}:
      +deadline = Nat.add(start, U32.to_nat(ms))
      conn.dial.run(List.foldl(~&2, ~String, ~Dial, ~conn.dial.fold, Con{ip, tail},
        Dial{port, ms, deadline, Wire.connect(first, port, ms)}))

def conn.open.all(+tls: Bool, +ms: U32, +host: String, +port: U32,
    ips: List<&2, String>, cert: Maybe<&2, Cert>, offer: Bool) ->
    IO(Result<&1, &1, Err, Conn>):
  match ips:
    case Nil{}:
      IO.pure(Result<&1, &1, Err, Conn>, Fail{ErrDns{}})
    case Con{addr, rest}:
      do IO<Result<&1, &1, Err, Conn>>:
        start : Nat <- IO.now()
        r : Result<&1, &1, U32 & String, Socket> <- conn.dial.all(port, ms, start, addr, rest)
        conn.made(ms, host, tls, cert, offer, r)

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

def proxy.env.lower(r: Result<&1, &1, U32 & String, String>, upper: String) ->
    IO(String):
  match r:
    case Done{value}:
      IO.pure(String, value)
    case Fail{e}:
      do IO<String>:
        got : Result<&1, &1, U32 & String, String> <- IO.get_env(upper)
        return proxy.env.value(got)

def proxy.env(lower: String, upper: String) -> IO(String):
  do IO<String>:
    got : Result<&1, &1, U32 & String, String> <- IO.get_env(lower)
    proxy.env.lower(got, upper)

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

def proxy.select(+scheme: String, +host: String, +port: U32) ->
    IO(Maybe<&2, Proxy>):
  +secure = String.eq(scheme, "https")
  do IO<Maybe<&2, Proxy>>:
    bypass : String <- proxy.env("no_proxy", "NO_PROXY")
    value : String <- proxy.env(Bool.pick(String, secure, "https_proxy", "http_proxy"),
      Bool.pick(String, secure, "HTTPS_PROXY", "HTTP_PROXY"))
    return proxy.choose(proxy.no_match(host, port, bypass), value)

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

def h2.header.values(+name: String, +mode: U32, vs: List<&2, String>) -> List<&2, Hpack.Field>:
  match vs:
    case Nil{}:
      Nil{}
    case Con{v, tail}:
      Hpack.Field{name, sanitize(v), mode} <> h2.header.values(name, mode, tail)

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

def h2.header.item(skip: Bool, +name: String, vs: List<&2, String>,
    tail: List<&2, Hpack.Field>) -> List<&2, Hpack.Field>:
  match skip:
    case True{}:
      tail
    case False{}:
      List.append(&2, Hpack.Field, h2.header.values(name, h2.header.mode(name), vs), tail)

def h2.header.items(xs: List<&2, Sigma<&2, &2, String, _ => List<&2, String>>>,
    +nominated: List<&2, String>) -> List<&2, Hpack.Field>:
  match xs:
    case Nil{}:
      Nil{}
    case (name, values) <> tail:
      +key = String.to_lower(name)
      h2.header.item(Bool.or(h2.header.skip(key), h2.header.has(nominated, key)),
        key, values, h2.header.items(tail, nominated))

def h2.request.fields(+method: String, target: String, authority: String,
    headers: Map<&2, List<&2, String>>) -> List<&2, Hpack.Field>:
  +xs = Map.to_list(&2, List<&2, String>, headers)
  List.append(&2, Hpack.Field,
    [Hpack.Field{":method", method, 0}, Hpack.Field{":scheme", "https", 0},
      Hpack.Field{":authority", authority, 0}, Hpack.Field{":path", target, 0}],
    h2.header.items(xs, h2.header.nominated(xs)))

def h2.response.status.value(+value: String, valid: Bool) -> Maybe<&2, U32>:
  match valid:
    case False{}:
      None{}
    case True{}:
      parse_u32(value)

def h2.response.status(xs: List<&2, Hpack.Field>) -> Maybe<&2, U32>:
  match xs:
    case Nil{}:
      None{}
    case Con{Hpack.Field{name, +value, mode}, tail}:
      match name:
        case ":status":
          h2.response.status.value(value, Nat.is_eq(String.length(value), 3n))
        case other:
          h2.response.status(tail)

def h2.response.headers(xs: List<&2, Hpack.Field>, acc: Map<&2, List<&2, String>>) ->
    Map<&2, List<&2, String>>:
  match xs:
    case Nil{}:
      acc
    case Con{Hpack.Field{name, value, mode}, tail}:
      match name:
        case SCon{Chr{58}, rest}:
          h2.response.headers(tail, acc)
        case other:
          h2.response.headers(tail, add(acc, String.to_lower(name), value))

def h2.response.final(interim: Bool, +status: U32, headers: List<&2, Hpack.Field>,
    body: HBytes.Bytes) -> Result<&1, &1, Err, Maybe<&1, Res>>:
  match interim:
    case True{}:
      Done{None{}}
    case False{}:
      HBytes.Bytes{len, buf} = body
      Done{Some{Res{status, h2.response.headers(headers, empty()), Bytes.Bytes{len, buf}}}}

def h2.response.valid(valid: Bool, +status: U32, headers: List<&2, Hpack.Field>,
    body: HBytes.Bytes) -> Result<&1, &1, Err, Maybe<&1, Res>>:
  match valid:
    case False{}:
      Fail{ErrBad{}}
    case True{}:
      h2.response.final(U32.is_lt(status, 200), status, headers, body)

def h2.response.parsed(m: Maybe<&2, U32>, headers: List<&2, Hpack.Field>,
    body: HBytes.Bytes) -> Result<&1, &1, Err, Maybe<&1, Res>>:
  match m:
    case None{}:
      Fail{ErrBad{}}
    case Some{+status}:
      h2.response.valid(Bool.and(U32.is_ge(status, 100), U32.is_lt(status, 600)),
        status, headers, body)

def h2.response(+fields: List<&2, Hpack.Field>, body: HBytes.Bytes) ->
    Result<&1, &1, Err, Maybe<&1, Res>>:
  h2.response.parsed(h2.response.status(fields), fields, body)

def h2.event.fold(acc: Result<&1, &1, Err, Maybe<&1, Res>>,
    event: H2.ClientEvent) -> Result<&1, &1, Err, Maybe<&1, Res>>:
  match acc:
    case Fail{e}:
      Fail{e}
    case Done{Some{res}}:
      Done{Some{res}}
    case Done{None{}}:
      match event:
        case H2.Response{id, headers, body}:
          h2.response(headers, body)
        case H2.Reset{id, code}:
          Fail{ErrBad{}}
        case H2.Shutdown{last, code}:
          Done{None{}}
        case H2.Pong{data}:
          Done{None{}}

def h2.send.report(r: Socket & Result<&1, &1, U32 & String, Unit>) ->
    IO(Result<&1, &1, Err, Socket>):
  (s, sent) = r
  match sent:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Err, Socket>>:
        Wire.tls.close(s)
        return Fail{err.or_late(code, ErrWrite{code, why})}
    case Done{unit}:
      IO.pure(Result<&1, &1, Err, Socket>, Done{s})

def h2.send.one(prev: Result<&1, &1, Err, Socket>, b: HBytes.Bytes) ->
    IO(Result<&1, &1, Err, Socket>):
  match prev:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Socket>, Fail{e})
    case Done{s}:
      HBytes.Bytes{len, buf} = b
      do IO<Result<&1, &1, Err, Socket>>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.send.words(s, len, buf)
        h2.send.report(sent)

def h2.send.fold(prev: IO(Result<&1, &1, Err, Socket>), b: HBytes.Bytes) ->
    IO(Result<&1, &1, Err, Socket>):
  do IO<Result<&1, &1, Err, Socket>>:
    r : Result<&1, &1, Err, Socket> <- prev
    h2.send.one(r, b)

def h2.send(xs: List<&1, HBytes.Bytes>, s: Socket) -> IO(Result<&1, &1, Err, Socket>):
  List.foldl(~&1, ~HBytes.Bytes, ~IO(Result<&1, &1, Err, Socket>), ~h2.send.fold,
    xs, IO.pure(Result<&1, &1, Err, Socket>, Done{s}))

def h2.received.step(over: Bool, s: Socket, client: H2.Client,
    +len: U32, buf: Array<U32>) -> H2Step:
  match over:
    case True{}:
      H2Reply{s, H2.Failed{H2.Error{1, True{}, 0}}}
    case False{}:
      H2Reply{s, H2.client.receive(client, HBytes.Bytes{len, buf})}

def h2.fail(s: Socket, e: Err) -> IO(Result<&1, &1, Err, Conn & Res>):
  do IO<Result<&1, &1, Err, Conn & Res>>:
    Wire.tls.close(s)
    return Fail{e}

def h2.loop(n: Nat, step: H2Step, +ms: U32, +used: U32) ->
    IO(Result<&1, &1, Err, Conn & Res>):
  match n:
    case 0n:
      match step:
        case H2Reply{s, reply}:
          h2.fail(s, ErrBad{})
        case H2Sent{client, events, sent}:
          match sent:
            case Fail{e}:
              IO.pure(Result<&1, &1, Err, Conn & Res>, Fail{e})
            case Done{s}:
              h2.fail(s, ErrBad{})
        case H2Events{s, client, result}:
          h2.fail(s, ErrBad{})
        case H2Received{client, answer}:
          (s, r) = answer
          h2.fail(s, ErrBad{})
    case 1n+p:
      match step:
        case H2Reply{s, reply}:
          match reply:
            case H2.Failed{error}:
              h2.fail(s, ErrBad{})
            case H2.Ready{client, writes, events}:
              do IO<Result<&1, &1, Err, Conn & Res>>:
                sent : Result<&1, &1, Err, Socket> <- h2.send(writes, s)
                h2.loop(p, H2Sent{client, events, sent}, ms, used)
        case H2Sent{client, events, sent}:
          match sent:
            case Fail{e}:
              IO.pure(Result<&1, &1, Err, Conn & Res>, Fail{e})
            case Done{s}:
              h2.loop(p, H2Events{s, client,
                List.foldl(~&1, ~H2.ClientEvent,
                  ~Result<&1, &1, Err, Maybe<&1, Res>>, ~h2.event.fold,
                  events, Done{None{}})}, ms, used)
        case H2Events{s, client, result}:
          match result:
            case Fail{e}:
              h2.fail(s, e)
            case Done{Some{res}}:
              IO.pure(Result<&1, &1, Err, Conn & Res>,
                Done{(ConnH2{s, client}, res)})
            case Done{None{}}:
              do IO<Result<&1, &1, Err, Conn & Res>>:
                r : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
                  Wire.tls.recv.words(s, 16384, ms)
                h2.loop(p, H2Received{client, r}, ms, used)
        case H2Received{client, answer}:
          match answer:
            case (s, Fail{(+code, why)}):
              h2.fail(s, err.or_late(code, ErrRead{code, why}))
            case (s, Done{(0, buf)}):
              h2.fail(s, ErrBad{})
            case (s, Done{(+len, buf)}):
              +total = (used + len : U32)
              h2.loop(p, h2.received.step(fetch.over(total), s, client, len, buf), ms, total)

def h2.exchange(s: Socket, client: H2.Client, +ms: U32, request: Send) ->
    IO(Result<&1, &1, Err, Conn & Res>):
  Send{method, target, authority, headers, Bytes.Bytes{len, buf}} = request
  h2.loop(Nat.mul(4n, Nat.add(fetch.max(), 65536n)),
    H2Reply{s, H2.client.request(client,
      h2.request.fields(method, target, authority, headers), HBytes.Bytes{len, buf})},
    ms, 0)

def proxy.connect.fail(s: Socket, e: Err) -> IO(Result<&1, &1, Err, Conn>):
  do IO<Result<&1, &1, Err, Conn>>:
    io.close(False{}, s)
    return Fail{e}

def proxy.connect.extra(m: Maybe<&2, String>, s: Socket, +ms: U32,
    sni: String, cert: Maybe<&2, Cert>) -> IO(Result<&1, &1, Err, Conn>):
  match m:
    case None{}:
      proxy.connect.fail(s, ErrBad{})
    case Some{rest}:
      match rest:
        case SNil{}:
          conn.secure(ms, sni, s, True{}, cert, True{})
        case other:
          proxy.connect.fail(s, ErrBad{})

def proxy.connect.status(ok: Bool, +status: U32, raw: String, s: Socket,
    +ms: U32, sni: String, cert: Maybe<&2, Cert>) ->
    IO(Result<&1, &1, Err, Conn>):
  match ok:
    case False{}:
      proxy.connect.fail(s, ErrConnect{status, "proxy CONNECT refused"})
    case True{}:
      proxy.connect.extra(after(raw, True{}), s, ms, sni, cert)

def proxy.connect.finish(res: Res, raw: String, s: Socket, +ms: U32,
    sni: String, cert: Maybe<&2, Cert>) -> IO(Result<&1, &1, Err, Conn>):
  Res{+status, headers, body} = res
  proxy.connect.status(Bool.and(U32.is_ge(status, 200), U32.is_lt(status, 300)),
    status, raw, s, ms, sni, cert)

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

def proxy.connect.loop(n: Nat, step: TunnelStep, +ms: U32, +sni: String,
    +cert: Maybe<&2, Cert>) -> IO(Result<&1, &1, Err, Conn>):
  match n:
    case 0n:
      match step:
        case TunnelRead{s, raw}:
          proxy.connect.fail(s, ErrBad{})
        case TunnelHead{s, raw, result}:
          proxy.connect.fail(s, ErrBad{})
        case TunnelGot{raw, answer}:
          (s, result) = answer
          proxy.connect.fail(s, ErrBad{})
    case 1n+p:
      match step:
        case TunnelRead{s, +raw}:
          proxy.connect.loop(p, TunnelHead{s, raw,
            proxy.connect.frame(raw, Nat.is_gt(String.length(raw), 65536n))},
            ms, sni, cert)
        case TunnelHead{s, raw, result}:
          match result:
            case FrameBad{}:
              proxy.connect.fail(s, ErrBad{})
            case FrameMore{}:
              do IO<Result<&1, &1, Err, Conn>>:
                answer : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
                  io.recv.words(False{}, s, 4096, ms)
                proxy.connect.loop(p, TunnelGot{raw, answer}, ms, sni, cert)
            case FrameDone{res}:
              proxy.connect.finish(res, raw, s, ms, sni, cert)
        case TunnelGot{raw, answer}:
          match answer:
            case (s, Fail{(+code, why)}):
              proxy.connect.fail(s, err.or_late(code, ErrRead{code, why}))
            case (s, Done{(+len, buf)}):
              proxy.connect.loop(p,
                proxy.connect.chunk(U32.is_zero(len), s, raw, len, buf),
                ms, sni, cert)

def proxy.connect.header(+authority: String, authorization: String) -> String:
  match authorization:
    case SNil{}:
      "CONNECT " ++ authority ++ " HTTP/1.1\r\nHost: " ++ authority ++ "\r\n\r\n"
    case other:
      "CONNECT " ++ authority ++ " HTTP/1.1\r\nHost: " ++ authority
        ++ "\r\nProxy-Authorization: " ++ authorization ++ "\r\n\r\n"

def proxy.connect.sent(r: Socket & Result<&1, &1, U32 & String, Unit>,
    +ms: U32, sni: String, cert: Maybe<&2, Cert>) ->
    IO(Result<&1, &1, Err, Conn>):
  (s, sent) = r
  match sent:
    case Fail{(+code, why)}:
      proxy.connect.fail(s, err.or_late(code, ErrWrite{code, why}))
    case Done{unit}:
      proxy.connect.loop(Nat.mul(3n, 65536n), TunnelRead{s, ""}, ms, sni, cert)

def proxy.connect(s: Socket, +ms: U32, sni: String, authority: String,
    authorization: String, cert: Maybe<&2, Cert>) ->
    IO(Result<&1, &1, Err, Conn>):
  do IO<Result<&1, &1, Err, Conn>>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <-
      io.send(False{}, s, proxy.connect.header(authority, authorization))
    proxy.connect.sent(sent, ms, sni, cert)

def proxy.route.tls(tls: Bool, s: Socket, +ms: U32, sni: String,
    authority: String, authorization: String, cert: Maybe<&2, Cert>) ->
    IO(Result<&1, &1, Err, Conn>):
  match tls:
    case False{}:
      IO.pure(Result<&1, &1, Err, Conn>, Done{Conn{False{}, s}})
    case True{}:
      proxy.connect(s, ms, sni, authority, authorization, cert)

def proxy.route.connected(tls: Bool, +ms: U32, sni: String, authority: String,
    authorization: String, cert: Maybe<&2, Cert>,
    r: Result<&1, &1, Err, Conn>) -> IO(Result<&1, &1, Err, Conn>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Conn>, Fail{e})
    case Done{c}:
      match c:
        case Conn{plain, s}:
          proxy.route.tls(tls, s, ms, sni, authority, authorization, cert)
        case ConnH2{s, client}:
          do IO<Result<&1, &1, Err, Conn>>:
            Wire.tls.close(s)
            return Fail{ErrBad{}}

def proxy.route.open(+ms: U32, +tls: Bool, +host: String, +port: U32,
    +sni: String, +authority: String, +authorization: String,
    cert: Maybe<&2, Cert>) -> IO(Result<&1, &1, Err, Conn>):
  do IO<Result<&1, &1, Err, Conn>>:
    ips : List<&2, String> <- Dns.resolve.all(host)
    conn : Result<&1, &1, Err, Conn> <-
      conn.open.all(False{}, ms, host, port, ips, None{}, False{})
    proxy.route.connected(tls, ms, sni, authority, authorization, cert, conn)

def route.open(+ms: U32, route: Route) -> IO(Result<&1, &1, Err, Conn>):
  match route:
    case RouteDirect{tls, +host, port, cert}:
      do IO<Result<&1, &1, Err, Conn>>:
        ips : List<&2, String> <- Dns.resolve.all(host)
        conn.open.all(tls, ms, host, port, ips, cert, True{})
    case RouteProxy{tls, host, port, sni, authority, authorization, cert}:
      proxy.route.open(ms, tls, host, port, sni, authority, authorization, cert)

def conn.ex.h1(+tls: Bool, s: Socket, +ms: U32, request: Send) -> IO(Out):
  Send{+method, target, authority, headers, body} = request
  exchange.go(tls, ms, False{}, String.eq(method, "HEAD"), s,
    encode_req.on(method, target, authority, headers, body, False{}))

# A socket with bytes past the response is out of step with the server, so it is closed.
def pool.keep.s(p: Pool, +key: String, +tls: Bool, res: Res, s: Socket, clean: Bool) -> IO(Pool & Result<&1, &1, Err, Res>):
  match clean:
    case True{}:
      do IO<Pool & Result<&1, &1, Err, Res>>:
        p2 : Pool <- pool.give(p, key, Conn{tls, s})
        return (p2, Done{res})
    case False{}:
      do IO<Pool & Result<&1, &1, Err, Res>>:
        io.close(tls, s)
        return (p, Done{res})

def pool.keep.m(p: Pool, +key: String, +tls: Bool, res: Res, +clean: Bool, sock: Maybe<&1, Socket>) -> IO(Pool & Result<&1, &1, Err, Res>):
  match sock:
    case None{}:
      IO.pure(Pool & Result<&1, &1, Err, Res>, (p, Done{res}))
    case Some{s}:
      pool.keep.s(p, key, tls, res, s, clean)

def pool.keep(p: Pool, +key: String, +tls: Bool, res: Res, sock: Maybe<&1, Socket>, rest: Bytes.Bytes) -> IO(Pool & Result<&1, &1, Err, Res>):
  Bytes.Bytes{+len, buf} = rest
  pool.keep.m(p, key, tls, res, U32.is_zero(len), sock)

def pool.after(p: Pool, +key: String, +tls: Bool, o: Out) -> IO(Pool & Result<&1, &1, Err, Res>):
  match o:
    case OutFail{e, none}:
      IO.pure(Pool & Result<&1, &1, Err, Res>, (p, Fail{e}))
    case OutDone{res, sock, rest}:
      pool.keep(p, key, tls, res, sock, rest)

def pool.h2.reusable(c: Conn) -> Bool & Conn:
  match c:
    case Conn{tls, s}:
      (True{}, Conn{tls, s})
    case ConnH2{s, H2.Client{input, streams, encoder, decoder, +control}}:
      H2.Control{next, active, frame_max, initial, max_streams, send_window,
        recv_window, first, ack, continuation, +goaway} = control
      (Maybe.is_none(&2, U32, goaway),
        ConnH2{s, H2.Client{input, streams, encoder, decoder, control}})

def pool.h2.keep(p: Pool, +key: String, res: Res, state: Bool & Conn) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  (reusable, c) = state
  match reusable:
    case True{}:
      do IO<Pool & Result<&1, &1, Err, Res>>:
        next : Pool <- pool.give(p, key, c)
        return (next, Done{res})
    case False{}:
      do IO<Pool & Result<&1, &1, Err, Res>>:
        conn.close(c)
        return (p, Done{res})

def pool.h2.result(p: Pool, +key: String, r: Result<&1, &1, Err, Conn & Res>) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  match r:
    case Fail{e}:
      IO.pure(Pool & Result<&1, &1, Err, Res>, (p, Fail{e}))
    case Done{(c, res)}:
      pool.h2.keep(p, key, res, pool.h2.reusable(c))

def pool.h2.ex(p: Pool, +key: String, +ms: U32, request: Send,
    s: Socket, client: H2.Client) -> IO(Pool & Result<&1, &1, Err, Res>):
  do IO<Pool & Result<&1, &1, Err, Res>>:
    r : Result<&1, &1, Err, Conn & Res> <- h2.exchange(s, client, ms, request)
    pool.h2.result(p, key, r)

def pool.fresh.conn(p: Pool, +key: String, +ms: U32, request: Send,
    r: Result<&1, &1, Err, Conn>) -> IO(Pool & Result<&1, &1, Err, Res>):
  match r:
    case Fail{e}:
      IO.pure(Pool & Result<&1, &1, Err, Res>, (p, Fail{e}))
    case Done{c}:
      match c:
        case Conn{+tls, s}:
          do IO<Pool & Result<&1, &1, Err, Res>>:
            o : Out <- conn.ex.h1(tls, s, ms, request)
            pool.after(p, key, tls, o)
        case ConnH2{s, client}:
          pool.h2.ex(p, key, ms, request, s, client)

def pool.fresh(p: Pool, +key: String, +ms: U32, request: Send, route: Route) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  do IO<Pool & Result<&1, &1, Err, Res>>:
    c : Result<&1, &1, Err, Conn> <- route.open(ms, route)
    pool.fresh.conn(p, key, ms, request, c)

# A reused socket the server already closed fails before any response byte.
def pool.retry(+none: Bool, +idem: Bool) -> Bool:
  Bool.and(none, idem)

def pool.stale(p: Pool, +key: String, +ms: U32, request: Send,
    e: Err, again: Bool, route: Route) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  match again:
    case True{}:
      pool.fresh(p, key, ms, request, route)
    case False{}:
      IO.pure(Pool & Result<&1, &1, Err, Res>, (p, Fail{e}))

def pool.reused(p: Pool, +key: String, +tls: Bool, +ms: U32, +idem: Bool,
    spare: Send, o: Out, route: Route) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  match o:
    case OutFail{e, +none}:
      pool.stale(p, key, ms, spare, e, pool.retry(none, idem), route)
    case OutDone{res, sock, rest}:
      pool.keep(p, key, tls, res, sock, rest)

# Copy only the reused HTTP/1.1 request body, for a stale-socket retry.
def pool.idle.h1.bodies(p: Pool, +key: String, +tls: Bool, +ms: U32, +idem: Bool,
    s: Socket, +method: String, +target: String, +authority: String,
    +headers: Map<&2, List<&2, String>>, r: Bytes.Bytes & Bytes.Bytes,
    route: Route) -> IO(Pool & Result<&1, &1, Err, Res>):
  (wire, spare) = r
  do IO<Pool & Result<&1, &1, Err, Res>>:
    o : Out <- conn.ex.h1(tls, s, ms, Send{method, target, authority, headers, wire})
    pool.reused(p, key, tls, ms, idem,
      Send{method, target, authority, headers, spare}, o, route)

def pool.idle.h1(p: Pool, +key: String, +tls: Bool, +ms: U32, +idem: Bool,
    s: Socket, request: Send, route: Route) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  Send{+method, +target, +authority, +headers, body} = request
  pool.idle.h1.bodies(p, key, tls, ms, idem, s, method, target,
    authority, headers, Bytes.slice(body, 0, 4294967295), route)

def pool.idle.reuse(p: Pool, +key: String, +ms: U32, +idem: Bool,
    c: Conn, request: Send, route: Route) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  match c:
    case Conn{tls, s}:
      pool.idle.h1(p, key, tls, ms, idem, s, request, route)
    case ConnH2{s, client}:
      pool.h2.ex(p, key, ms, request, s, client)

def pool.idle(taken: Pool & Maybe<&1, Conn>, +key: String, +ms: U32,
    +idem: Bool, request: Send, route: Route) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  (p, m) = taken
  match m:
    case None{}:
      pool.fresh(p, key, ms, request, route)
    case Some{c}:
      pool.idle.reuse(p, key, ms, idem, c, request, route)

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

def pool.origin.proxy(p: Pool, +method: String, +ms: U32,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +hf: String,
    +scheme: String, +host: String, +port: U32, +target: String,
    +cert: Maybe<&2, Cert>, proxy: Proxy) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  match proxy:
    case ProxyDirect{}:
      +key = pool.key.cert(pool.key(scheme, host, port), cert)
      pool.idle(pool.take(p, key), key, ms, pool.idempotent(method),
        Send{method, target, hf, headers, body},
        RouteDirect{String.eq(scheme, "https"), host, port, cert})
    case ProxyVia{+proxy_host, +proxy_port, +authorization}:
      +secure = String.eq(scheme, "https")
      +key = pool.key.cert(pool.key(scheme, host, port)
        ++ "|proxy:" ++ proxy_host ++ ":" ++ U32.show(proxy_port)
        ++ "|auth:" ++ authorization, cert)
      pool.idle(pool.take(p, key), key, ms, pool.idempotent(method),
        proxy.request(secure, scheme, method, target, hf, headers, body, authorization),
        RouteProxy{secure, proxy_host, proxy_port, host,
          Url.host_field.wrap(host, Url.has(host, 58)) ++ ":" ++ U32.show(port),
          authorization, cert})

def pool.origin.choice(p: Pool, method: String, ms: U32,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, hf: String,
    scheme: String, host: String, port: U32, target: String,
    cert: Maybe<&2, Cert>, choice: Maybe<&2, Proxy>) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  match choice:
    case None{}:
      IO.pure(Pool & Result<&1, &1, Err, Res>, (p, Fail{ErrUrl{}}))
    case Some{proxy}:
      pool.origin.proxy(p, method, ms, headers, body, hf, scheme, host, port,
        target, cert, proxy)

def pool.origin(p: Pool, method: String, ms: U32,
    headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, hf: String,
    a: Url.Abs, known: Bool, cert: Maybe<&2, Cert>,
    choice: Maybe<&2, Proxy>) ->
    IO(Pool & Result<&1, &1, Err, Res>):
  Url.Abs{scheme, host, port, target} = a
  match known:
    case False{}:
      IO.pure(Pool & Result<&1, &1, Err, Res>, (p, Fail{ErrUrl{}}))
    case True{}:
      pool.origin.choice(p, method, ms, headers, body, hf, scheme, host,
        port, target, cert, choice)

def pool.scheme.ok(a: Url.Abs) -> Bool:
  Url.Abs{+scheme, host, port, target} = a
  Bool.or(String.eq(scheme, "http"), String.eq(scheme, "https"))

def pool.one.back(h: Hop, pr: Pool & Result<&1, &1, Err, Res>) -> Pool & Result<&1, &1, Err, Res> & Hop:
  (p, r) = pr
  (p, r, h)

# sent is headers plus any jar cookies; the hop keeps headers, so cookies never pile up across hops.
def pool.one.of(p: Pool, +method: String, +url: Url.Abs,
    headers: Map<&2, List<&2, String>>, sent: Map<&2, List<&2, String>>,
    +ms: U32, r: Bytes.Bytes & Bytes.Bytes, cert: Maybe<&2, Cert>) ->
    IO(Pool & Result<&1, &1, Err, Res> & Hop):
  Url.Abs{+scheme, +host, +port, target} = url
  (body, wire) = r
  do IO<Pool & Result<&1, &1, Err, Res> & Hop>:
    choice : Maybe<&2, Proxy> <- proxy.select(scheme, host, port)
    pr : Pool & Result<&1, &1, Err, Res> <-
      pool.origin(p, method, ms, sent, wire, Url.host_field(url),
        url, pool.scheme.ok(url), cert, choice)
    return pool.one.back(Hop{method, url, headers, body}, pr)

# One request, on an idle socket to its origin when the pool has one. The hop comes back for the redirect.
def pool.one(p: Pool, h: Hop, +ms: U32, cert: Maybe<&2, Cert>, jar: Maybe<&2, Jar>) -> IO(Pool & Result<&1, &1, Err, Res> & Hop):
  Hop{+method, +url, +headers, body} = h
  pool.one.of(p, method, url, headers, jar.opt.apply(jar, url, headers), ms, Bytes.slice(body, 0, 4294967295), cert)

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

# The redirect loop's state: the pool, what to do next, the client identity, and the jar if any.
type Hops is Type:
  Hops{p: Pool, next: Next, cert: Maybe<&2, Cert>, jar: Maybe<&2, Jar>}

def pool.next.move(p: Pool, +old: String, cert: Maybe<&2, Cert>, jar: Maybe<&2, Jar>, n: Next) -> Hops:
  match n:
    case NGo{left, h}:
      Hop{method, +url, headers, body} = h
      Hops{p, NGo{left, Hop{method, url, headers, body}},
        Bool.pick(Maybe<&2, Cert>, String.eq(old, redirect.origin(url)), cert, None{}), jar}
    case NDone{r}:
      Hops{p, NDone{r}, None{}, jar}
    case NStop{}:
      Hops{p, NStop{}, None{}, jar}

def pool.next.of(+mode: Mode, left: Nat, cert: Maybe<&2, Cert>, p: Pool, +url: Url.Abs, h: Hop, r: Maybe<&2, Jar> & Result<&1, &1, Err, Res>) -> Hops:
  (jar, m) = r
  pool.next.move(p, redirect.origin(url), cert, jar, fetch.policy(mode, left, h, m))

# The jar takes the response's Set-Cookie fields first, redirect or not.
def pool.next(+mode: Mode, left: Nat, cert: Maybe<&2, Cert>, jar: Maybe<&2, Jar>, x: Pool & Result<&1, &1, Err, Res> & Hop) -> Hops:
  (p, m, h) = x
  Hop{method, +url, headers, body} = h
  pool.next.of(mode, left, cert, p, url, Hop{method, url, headers, body}, jar.opt.store(jar, url, m))

def pool.hops.one(+mode: Mode, +ms: U32, +cert: Maybe<&2, Cert>, +jar: Maybe<&2, Jar>, p: Pool, h: Hop, left: Nat) -> IO(Hops):
  do IO<Hops>:
    x : Pool & Result<&1, &1, Err, Res> & Hop <- pool.one(p, h, ms, cert, jar)
    return pool.next(mode, left, cert, jar, x)

# NGo.left is how many redirects may follow this request. 20 is WHATWG's limit.
# The jar, when there is one, gives cookies to every hop and takes them from every response.
@unsafe
def pool.hops(+mode: Mode, +ms: U32, st: Hops) -> IO(Pool & Result<&1, &1, Err, Res> & Maybe<&2, Jar>):
  Hops{p, n, cert, cj} = st
  match n:
    case NDone{m}:
      IO.pure(Pool & Result<&1, &1, Err, Res> & Maybe<&2, Jar>, (p, m, cj))
    case NStop{}:
      IO.pure(Pool & Result<&1, &1, Err, Res> & Maybe<&2, Jar>, (p, Fail{ErrRedirect{}}, cj))
    case NGo{+left, h}:
      do IO<Pool & Result<&1, &1, Err, Res> & Maybe<&2, Jar>>:
        next : Hops <- pool.hops.one(mode, ms, cert, cj, p, h, left)
        pool.hops(mode, ms, next)

# Content-Encoding (RFC 9110 §8.4): each value, trimmed and lowercased, in the order applied.
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
type Dec is Data:
  DecOk{b: String}
  DecBad{}
  DecSkip{}

def ce.of(m: Maybe<&2, String>) -> Dec:
  match m:
    case None{}:
      DecBad{}
    case Some{b}:
      DecOk{b}

# Servers send deflate both with and without the zlib wrapper.
def ce.deflate(+b: String, m: Maybe<&2, String>) -> Dec:
  match m:
    case Some{out}:
      DecOk{out}
    case None{}:
      ce.of(Zlib.inflate(b))

def ce.apply(+c: String, +b: String) -> Dec:
  Bool.pick(Dec, Bool.or(String.eq(c, "gzip"), String.eq(c, "x-gzip")), ce.of(Zlib.gunzip(b)),
    Bool.pick(Dec, String.eq(c, "deflate"), ce.deflate(b, Zlib.unzlib(b)),
      Bool.pick(Dec, String.eq(c, "identity"), DecOk{b}, DecSkip{})))

def ce.go(cs: List<&2, String>, d: Dec) -> Dec:
  match cs:
    case Nil{}:
      d
    case Con{+c, t}:
      match d:
        case DecOk{+b}:
          ce.go(t, ce.apply(c, b))
        case DecBad{}:
          DecBad{}
        case DecSkip{}:
          DecSkip{}

def decoded.pick(d: Dec, +status: U32, headers: Map<&2, List<&2, String>>, body: String) -> Result<&1, &1, Err, Res>:
  match d:
    case DecOk{b}:
      Done{Res{status, headers, Bytes.from_string(b)}}
    case DecBad{}:
      Fail{ErrBad{}}
    case DecSkip{}:
      Done{Res{status, headers, Bytes.from_string(body)}}

# ponytail: the codings run on a String copy of the body; give zlib a Bytes input if gzip bodies get big.
def decoded.cs(+status: U32, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, cs: List<&2, String>) -> Result<&1, &1, Err, Res>:
  match cs:
    case Nil{}:
      Done{Res{status, headers, body}}
    case Con{c, t}:
      +s = Bytes.to_string(body)
      decoded.pick(ce.go(Con{c, t}, DecOk{s}), status, headers, s)

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

def ce.words(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Maybe<&1, Bytes.Bytes>:
  match r:
    case Fail{e}:
      None{}
    case Done{(+len, buf)}:
      Some{Bytes.Bytes{len, buf}}

# A decoded body stops at 16 MiB, like a received one.
def ce.eff(~eff: U32 -> U32 -> Array<U32> -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>), b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  Bytes.Bytes{+len, buf} = b
  do IO<Maybe<&1, Bytes.Bytes>>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- eff(16777216, len, buf)
    return ce.words(r)

def ce.dec(d: Dec) -> Maybe<&1, Bytes.Bytes>:
  match d:
    case DecOk{b}:
      Some{Bytes.from_string(b)}
    case DecBad{}:
      None{}
    case DecSkip{}:
      None{}

# ponytail: deflate runs on the pure decoder, which also takes raw DEFLATE; servers rarely send it.
def ce.io.deflate(on: Bool, b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  match on:
    case True{}:
      +s = Bytes.to_string(b)
      IO.pure(Maybe<&1, Bytes.Bytes>, ce.dec(ce.deflate(s, Zlib.unzlib(s))))
    case False{}:
      IO.pure(Maybe<&1, Bytes.Bytes>, Some{b})

def ce.io.zstd(on: Bool, +c: String, b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  match on:
    case True{}:
      ce.eff(~Zlib.zstd.words, b)
    case False{}:
      ce.io.deflate(String.eq(c, "deflate"), b)

def ce.io.br(on: Bool, +c: String, b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  match on:
    case True{}:
      ce.eff(~Zlib.brotli.words, b)
    case False{}:
      ce.io.zstd(String.eq(c, "zstd"), c, b)

# One known coding undone: gzip, x-gzip, br, zstd, deflate, or identity.
def ce.io.gz(on: Bool, +c: String, b: Bytes.Bytes) -> IO(Maybe<&1, Bytes.Bytes>):
  match on:
    case True{}:
      ce.eff(~Zlib.inflate.words, b)
    case False{}:
      ce.io.br(String.eq(c, "br"), c, b)

def ce.io.go(cs: List<&2, String>, m: Maybe<&1, Bytes.Bytes>) -> IO(Maybe<&1, Bytes.Bytes>):
  match cs:
    case Nil{}:
      match m:
        case None{}:
          IO.pure(Maybe<&1, Bytes.Bytes>, None{})
        case Some{b}:
          IO.pure(Maybe<&1, Bytes.Bytes>, Some{b})
    case Con{+c, t}:
      match m:
        case None{}:
          IO.pure(Maybe<&1, Bytes.Bytes>, None{})
        case Some{b}:
          do IO<Maybe<&1, Bytes.Bytes>>:
            n : Maybe<&1, Bytes.Bytes> <- ce.io.gz(Bool.or(String.eq(c, "gzip"), String.eq(c, "x-gzip")), c, b)
            ce.io.go(t, n)

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

def decoded.io.run(known: Bool, +status: U32, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, cs: List<&2, String>) -> IO(Result<&1, &1, Err, Res>):
  match known:
    case True{}:
      do IO<Result<&1, &1, Err, Res>>:
        m : Maybe<&1, Bytes.Bytes> <- ce.io.go(cs, Some{body})
        return decoded.io.pick(m, status, headers)
    case False{}:
      IO.pure(Result<&1, &1, Err, Res>, Done{Res{status, headers, body}})

def decoded.io.go(empty: Bool, +enc: String, +status: U32, +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Result<&1, &1, Err, Res>):
  match empty:
    case True{}:
      IO.pure(Result<&1, &1, Err, Res>, Done{Res{status, headers, body}})
    case False{}:
      +cs = List.reverse(&2, String, ce.split(fields(headers, "content-encoding")))
      decoded.io.run(ce.known(cs, Con{"identity", Con{"x-gzip", ce.split(Con{enc, Nil{}})}}), status, headers, body, cs)

# decoded through the C libraries, for the codings in enc. A body with any other coding stays as sent.
def decoded.io(+enc: String, res: Res) -> IO(Result<&1, &1, Err, Res>):
  Res{+status, +headers, body} = res
  Bytes.Bytes{+len, buf} = body
  decoded.io.go(U32.is_zero(len), enc, status, headers, Bytes.Bytes{len, buf})

# An effect on empty input fails with ENOENT only when its library does not load.
def codings.ok(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Bool:
  match r:
    case Fail{(+c, why)}:
      Bool.not(U32.is_eq(c, 2))
    case Done{p}:
      True{}

def codings.has(~eff: U32 -> U32 -> Array<U32> -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>), b: Bytes.Bytes) -> IO(Bool):
  Bytes.Bytes{+len, buf} = b
  do IO<Bool>:
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- eff(0, len, buf)
    return codings.ok(r)

def codings.add(has: Bool, +enc: String, +c: String) -> String:
  Bool.pick(String, has, enc ++ ", " ++ c, enc)

# gzip and deflate, then br and zstd when their C library loads.
def codings() -> IO(String):
  do IO<String>:
    b : Bool <- codings.has(~Zlib.brotli.words, Bytes.new(0))
    z : Bool <- codings.has(~Zlib.zstd.words, Bytes.new(0))
    return codings.add(z, codings.add(b, "gzip, deflate", "br"), "zstd")

# The final response of a fetch, after redirects.
def fetch.final(+enc: String, r: Result<&1, &1, Err, Res>) -> IO(Result<&1, &1, Err, Res>):
  match r:
    case Done{res}:
      decoded.io(enc, res)
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Res>, Fail{e})

def pool.final(+enc: String, pr: Pool & Result<&1, &1, Err, Res> & Maybe<&2, Jar>) -> IO(Pool & Result<&1, &1, Err, Res>):
  (p, r, jar) = pr
  do IO<Pool & Result<&1, &1, Err, Res>>:
    d : Result<&1, &1, Err, Res> <- fetch.final(enc, r)
    return (p, d)

def pool.how.enc(+enc: String, p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32, mode: Mode, cert: Maybe<&2, Cert>) -> IO(Pool & Result<&1, &1, Err, Res>):
  do IO<Pool & Result<&1, &1, Err, Res>>:
    pr : Pool & Result<&1, &1, Err, Res> & Maybe<&2, Jar> <- pool.hops(mode, ms, Hops{p, fetch.start(method, headers, body, Url.absolute(url), enc), cert, None{}})
    pool.final(enc, pr)

def pool.how.cert(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32, mode: Mode, cert: Maybe<&2, Cert>) -> IO(Pool & Result<&1, &1, Err, Res>):
  do IO<Pool & Result<&1, &1, Err, Res>>:
    enc : String <- codings()
    pool.how.enc(enc, p, method, url, headers, body, ms, mode, cert)

# pool.how(p, "GET", "https://example.com/x?y=1", headers, body, ms, mode) follows redirects
# on p's idle sockets. Fail is a bad URL, a failed lookup, connect, handshake, send, read,
# a malformed response, more than 20 redirects, or a step past ms. Bodies are bytes.
def pool.how(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32, mode: Mode) -> IO(Pool & Result<&1, &1, Err, Res>):
  pool.how.cert(p, method, url, headers, body, ms, mode, None{})

def pool.fetch.with(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32) -> IO(Pool & Result<&1, &1, Err, Res>):
  pool.how(p, method, url, headers, body, ms, ModeFollow{})

def pool.fetch(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Pool & Result<&1, &1, Err, Res>):
  pool.fetch.with(p, method, url, headers, body, 30000)

def pool.fetch.cert.with(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, chain: String, key: String, ms: U32) -> IO(Pool & Result<&1, &1, Err, Res>):
  pool.how.cert(p, method, url, headers, body, ms, ModeFollow{}, Some{Cert{chain, key}})

def pool.fetch.cert(p: Pool, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, chain: String, key: String) -> IO(Pool & Result<&1, &1, Err, Res>):
  pool.fetch.cert.with(p, method, url, headers, body, chain, key, 30000)

# One request for fetch.all: the arguments of fetch, as a record.
type Fetch is Type:
  Fetch{method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes}

def fetch.all.job(p: Pool, f: Fetch) -> IO(Pool & Result<&1, &1, Err, Res>):
  Fetch{method, url, headers, body} = f
  pool.fetch(p, method, url, headers, body)

def fetch.all.pools(n: Nat) -> List<Pool>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      pool.new() <> fetch.all.pools(p)

def fetch.all.close(ps: List<Pool>) -> IO(Unit):
  match ps:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case p <> rest:
      do IO<Unit>:
        pool.close(p)
        fetch.all.close(rest)

def fetch.all.done(r: List<Pool> & List<Result<&1, &1, Err, Res>>) -> IO(List<Result<&1, &1, Err, Res>>):
  (ps, rs) = r
  do IO<List<Result<&1, &1, Err, Res>>>:
    fetch.all.close(ps)
    return rs

# No requests start no workers, since Conc.pool needs at least one.
def fetch.all.go(xs: List<Fetch>, +workers: Nat) -> IO(List<Result<&1, &1, Err, Res>>):
  match xs:
    case Nil{}:
      IO.pure(List<Result<&1, &1, Err, Res>>, Nil{})
    case x <> rest:
      do IO<List<Result<&1, &1, Err, Res>>>:
        r : List<Pool> & List<Result<&1, &1, Err, Res>> <-
          Conc.pool(~Pool, ~Fetch, ~Result<&1, &1, Err, Res>, ~fetch.all.job, fetch.all.pools(workers), x <> rest)
        fetch.all.done(r)

def fetch.all.of(+n: U32, nx: Nat & List<Fetch>) -> IO(List<Result<&1, &1, Err, Res>>):
  (+len, xs) = nx
  fetch.all.go(xs, Nat.min(len, Nat.max(1n, U32.to_nat(n))))

# Each request as fetch would make it, on at most n workers (0 counts as 1, and
# never more workers than requests). Each worker owns its own Pool, so an idle
# socket is reused only by the worker that opened it; every pool is closed at the
# end. Results come back in the order of reqs.
def fetch.all(reqs: List<Fetch>, +n: U32) -> IO(List<Result<&1, &1, Err, Res>>):
  fetch.all.of(n, Conc.count(Fetch, reqs))

# The hops always hand the jar back; j is only the type's fallback.
def pool.jar.final(+enc: String, j: Jar, pr: Pool & Result<&1, &1, Err, Res> & Maybe<&2, Jar>) -> IO(Pool & Jar & Result<&1, &1, Err, Res>):
  (p, r, jar) = pr
  do IO<Pool & Jar & Result<&1, &1, Err, Res>>:
    d : Result<&1, &1, Err, Res> <- fetch.final(enc, r)
    return (p, Maybe.default(&2, Jar, jar, j), d)

def pool.jar.enc(+enc: String, p: Pool, +j: Jar, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Pool & Jar & Result<&1, &1, Err, Res>):
  do IO<Pool & Jar & Result<&1, &1, Err, Res>>:
    pr : Pool & Result<&1, &1, Err, Res> & Maybe<&2, Jar> <- pool.hops(ModeFollow{}, 30000, Hops{p, fetch.start(method, headers, body, Url.absolute(url), enc), None{}, Some{j}})
    pool.jar.final(enc, j, pr)

# pool.fetch with a cookie jar (RFC 6265bis). Before every hop, redirects included, the jar's
# cookies for that URL join the request's cookie field; after every response, redirects included,
# its Set-Cookie fields go into the jar. The jar's clock is the caller's: advance it with jar.at.
def pool.fetch.jar(p: Pool, j: Jar, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Pool & Jar & Result<&1, &1, Err, Res>):
  do IO<Pool & Jar & Result<&1, &1, Err, Res>>:
    enc : String <- codings()
    pool.jar.enc(enc, p, j, method, url, headers, body)
def fetch.end(pr: Pool & Result<&1, &1, Err, Res>) -> IO(Result<&1, &1, Err, Res>):
  (p, r) = pr
  do IO<Result<&1, &1, Err, Res>>:
    pool.close(p)
    return r

# fetch is pool.how on a fresh pool that closes afterwards.
def fetch.how(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32, mode: Mode) -> IO(Result<&1, &1, Err, Res>):
  do IO<Result<&1, &1, Err, Res>>:
    pr : Pool & Result<&1, &1, Err, Res> <- pool.how(pool.new(), method, url, headers, body, ms, mode)
    fetch.end(pr)

def fetch.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, ms: U32) -> IO(Result<&1, &1, Err, Res>):
  fetch.how(method, url, headers, body, ms, ModeFollow{})

def fetch.cert.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, chain: String, key: String, ms: U32) -> IO(Result<&1, &1, Err, Res>):
  do IO<Result<&1, &1, Err, Res>>:
    pr : Pool & Result<&1, &1, Err, Res> <- pool.fetch.cert.with(pool.new(), method, url, headers, body, chain, key, ms)
    fetch.end(pr)

def fetch.cert(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, chain: String, key: String) -> IO(Result<&1, &1, Err, Res>):
  fetch.cert.with(method, url, headers, body, chain, key, 30000)

# fetch.with and a 30 s step timeout.
def fetch(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Result<&1, &1, Err, Res>):
  fetch.with(method, url, headers, body, 30000)

def get(url: String) -> IO(Result<&1, &1, Err, Res>):
  fetch("GET", url, empty(), Bytes.new(0))

# POST v as compact JSON, with content-type: application/json.
def post.json(url: String, v: Json.Val) -> IO(Result<&1, &1, Err, Res>):
  fetch("POST", url, set(empty(), "content-type", "application/json"), Json.encode.bytes(v))

# Base URLs: resolve(base, ref) is ref against the absolute http(s) URL base (RFC 3986 §5.2),
# written back as a URL for fetch. None when base is not absolute or ref has another scheme.
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

def retry.sleep(+v: String, n: Nat) -> IO(Unit):
  do IO<Unit>:
    now : Time.Instant <- Time.now()
    rnd : Result<&1, &1, U32 & String, U32> <- IO.random_u32()
    IO.sleep(retry.delay(v, now, n, retry.jitter(rnd)))

def retry.kept(body: Bytes.Bytes, j: Result<&1, &1, Err, Res> & Maybe<&2, String>) -> Bytes.Bytes & Result<&1, &1, Err, Res> & Maybe<&2, String>:
  (r, m) = j
  (body, r, m)

# One fetch of the copy; the body comes back for the next try.
def retry.one(+idem: Bool, +method: String, +url: String, +headers: Map<&2, List<&2, String>>,
    r: Bytes.Bytes & Bytes.Bytes) -> IO(Bytes.Bytes & Result<&1, &1, Err, Res> & Maybe<&2, String>):
  (body, spare) = r
  do IO<Bytes.Bytes & Result<&1, &1, Err, Res> & Maybe<&2, String>>:
    got : Result<&1, &1, Err, Res> <- fetch(method, url, headers, spare)
    return retry.kept(body, retry.judge(idem, got))

# left: retries still allowed. n: the retry to wait for next, 0 first.
def retry.go(left: Nat, +n: Nat, +idem: Bool, +method: String, +url: String,
    +headers: Map<&2, List<&2, String>>,
    t: Bytes.Bytes & Result<&1, &1, Err, Res> & Maybe<&2, String>) -> IO(Result<&1, &1, Err, Res>):
  match left:
    case 0n:
      (body, r, m) = t
      IO.pure(Result<&1, &1, Err, Res>, r)
    case 1n+p:
      (body, r, m) = t
      match m:
        case None{}:
          IO.pure(Result<&1, &1, Err, Res>, r)
        case Some{v}:
          do IO<Result<&1, &1, Err, Res>>:
            retry.sleep(v, n)
            tried : Bytes.Bytes & Result<&1, &1, Err, Res> & Maybe<&2, String> <-
              retry.one(idem, method, url, headers, Bytes.slice(body, 0, 4294967295))
            retry.go(p, 1n+n, idem, method, url, headers, tried)

# fetch.retry(n, method, url, headers, body) is fetch, tried again up to n times while an
# idempotent method (GET, HEAD, OPTIONS, TRACE, PUT, DELETE) gets a connect error, a timeout,
# or 408, 429, 500, 502, 503, or 504. POST, PATCH and other methods get one try. It waits
# Retry-After (seconds or HTTP-date, at most 30 s) when given, else the backoff. When retries
# run out, the last response or error comes back as it was.
def retry.start(enabled: Bool, n: U32, +method: String, +url: String,
    +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Result<&1, &1, Err, Res>):
  match enabled:
    case False{}:
      fetch(method, url, headers, body)
    case True{}:
      do IO<Result<&1, &1, Err, Res>>:
        first : Bytes.Bytes & Result<&1, &1, Err, Res> & Maybe<&2, String> <-
          retry.one(True{}, method, url, headers, Bytes.slice(body, 0, 4294967295))
        retry.go(U32.to_nat(n), 0n, True{}, method, url, headers, first)

def fetch.retry(+n: U32, +method: String, +url: String,
    +headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) ->
    IO(Result<&1, &1, Err, Res>):
  retry.start(Bool.and(U32.is_ne(n, 0), pool.idempotent(method)),
    n, method, url, headers, body)

# Streaming (a body read or sent in pieces). A decoded stream owns its decoders.
# What the next read returns: read more, a raw piece, a decoded piece, the end, or an error.
type Po is Type:
  PoNone{}
  PoPiece{b: Bytes.Bytes}
  PoReady{b: Bytes.Bytes}
  PoEnd{}
  PoBad{e: Err}

type Stream is Type:
  Stream{tls: Bool, s: Socket, ms: U32, res: Res, rb: Rb, out: Po, decs: List<&1, Zlib.Decoder>}

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

def stream.mk(+tls: Bool, s: Socket, +ms: U32, res: Res, decs: List<&1, Zlib.Decoder>, pc: Pc) -> Stream:
  Pc{rb, out} = pc
  Stream{tls, s, ms, res, rb, out, decs}

def stream.got.piece(+tls: Bool, s: Socket, +ms: U32, res: Res, decs: List<&1, Zlib.Decoder>, +rb: Rb, p: U32 & Array<U32>) -> Stream:
  (+len, buf) = p
  stream.mk(tls, s, ms, res, decs, Bool.pick(Pc, U32.is_zero(len), pc.eof(rb), pc.of(rb, Bytes.Bytes{len, buf})))

def stream.got(+tls: Bool, +ms: U32, res: Res, decs: List<&1, Zlib.Decoder>, +rb: Rb, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Stream:
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      Stream{tls, s, ms, res, RbDone{}, PoBad{err.or_late(code, ErrRead{code, why})}, decs}
    case Done{p}:
      stream.got.piece(tls, s, ms, res, decs, rb, p)

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

type Fed is Type:
  Fed{decs: List<&1, Zlib.Decoder>, body: Result<&1, &1, Err, Bytes.Bytes>}

def stream.feed.received(done: List<&1, Zlib.Decoder>, m: Zlib.Decoder & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Fed:
  (d, r) = m
  match r:
    case Fail{e}:
      Fed{d <> done, Fail{ErrBad{}}}
    case Done{(+len, buf)}:
      Fed{d <> done, Done{Bytes.Bytes{len, buf}}}

def stream.feed.step(st: Fed, d: Zlib.Decoder) -> IO(Fed):
  Fed{done, body} = st
  match body:
    case Fail{e}:
      IO.pure(Fed, Fed{d <> done, Fail{e}})
    case Done{b}:
      Bytes.Bytes{+len, buf} = b
      do IO<Fed>:
        m : Zlib.Decoder & Result<&1, &1, U32 & String, U32 & Array<U32>> <-
          Zlib.dec.feed.words(d, 16777216, len, buf)
        return stream.feed.received(done, m)

def stream.feed.one(prev: IO(Fed), d: Zlib.Decoder) -> IO(Fed):
  do IO<Fed>:
    st : Fed <- prev
    stream.feed.step(st, d)

def stream.feed.reverse(st: Fed) -> Fed:
  Fed{done, body} = st
  Fed{List.reverse(&1, Zlib.Decoder, done), body}

def stream.feed.all(decs: List<&1, Zlib.Decoder>, b: Bytes.Bytes) -> IO(Fed):
  do IO<Fed>:
    st : Fed <- List.foldl(~&1, ~Zlib.Decoder, ~IO(Fed), ~stream.feed.one, decs,
      IO.pure(Fed, Fed{Nil{}, Done{b}}))
    return stream.feed.reverse(st)

def stream.ready(empty: Bool, +rb: Rb, b: Bytes.Bytes) -> Po:
  match empty:
    case True{}:
      stream.after(rb)
    case False{}:
      PoReady{b}

def stream.feed.got(+tls: Bool, s: Socket, +ms: U32, res: Res, +rb: Rb, st: Fed) -> Stream:
  Fed{decs, body} = st
  match body:
    case Fail{e}:
      Stream{tls, s, ms, res, rb, PoBad{e}, decs}
    case Done{b}:
      Bytes.Bytes{+len, buf} = b
      Stream{tls, s, ms, res, rb, stream.ready(U32.is_zero(len), rb, Bytes.Bytes{len, buf}), decs}

def stream.feed.st(st: Stream, b: Bytes.Bytes) -> IO(Stream):
  Stream{+tls, s, +ms, res, +rb, out, decs} = st
  match decs:
    case Nil{}:
      IO.pure(Stream, Stream{tls, s, ms, res, rb, PoReady{b}, Nil{}})
    case Con{d, rest}:
      do IO<Stream>:
        fed : Fed <- stream.feed.all(Con{d, rest}, b)
        return stream.feed.got(tls, s, ms, res, rb, fed)

def stream.finish.ok(r: Result<&1, &1, U32 & String, Unit>) -> Bool:
  match r:
    case Fail{e}:
      False{}
    case Done{u}:
      True{}

def stream.finish(decs: List<&1, Zlib.Decoder>) -> IO(Bool):
  match decs:
    case Nil{}:
      IO.pure(Bool, True{})
    case Con{d, rest}:
      do IO<Bool>:
        r : Result<&1, &1, U32 & String, Unit> <- Zlib.dec.finish(d)
        tail : Bool <- stream.finish(rest)
        return Bool.and(stream.finish.ok(r), tail)

def stream.ended(good: Bool, +tls: Bool, s: Socket, +ms: U32, res: Res, +rb: Rb) ->
  Stream & Result<&1, &1, Err, Maybe<&1, Bytes.Bytes>>:
  match good:
    case True{}:
      (Stream{tls, s, ms, res, rb, PoEnd{}, Nil{}}, Done{None{}})
    case False{}:
      (Stream{tls, s, ms, res, rb, PoBad{ErrBad{}}, Nil{}}, Fail{ErrBad{}})

# The next piece of the body; None at the end. A piece is never empty.
@unsafe
def stream.read(st: Stream) -> IO(Stream & Result<&1, &1, Err, Maybe<&1, Bytes.Bytes>>):
  Stream{+tls, s, +ms, res, +rb, out, decs} = st
  match out:
    case PoPiece{b}:
      do IO<Stream & Result<&1, &1, Err, Maybe<&1, Bytes.Bytes>>>:
        next : Stream <- stream.feed.st(Stream{tls, s, ms, res, rb, PoNone{}, decs}, b)
        stream.read(next)
    case PoReady{b}:
      IO.pure(Stream & Result<&1, &1, Err, Maybe<&1, Bytes.Bytes>>,
        (Stream{tls, s, ms, res, rb, stream.after(rb), decs}, Done{Some{b}}))
    case PoEnd{}:
      do IO<Stream & Result<&1, &1, Err, Maybe<&1, Bytes.Bytes>>>:
        good : Bool <- stream.finish(decs)
        return stream.ended(good, tls, s, ms, res, rb)
    case PoBad{+e}:
      IO.pure(Stream & Result<&1, &1, Err, Maybe<&1, Bytes.Bytes>>,
        (Stream{tls, s, ms, res, rb, PoBad{e}, decs}, Fail{e}))
    case PoNone{}:
      do IO<Stream & Result<&1, &1, Err, Maybe<&1, Bytes.Bytes>>>:
        m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv.words(tls, s, 65536, ms)
        stream.read(stream.got(tls, ms, res, decs, rb, m))

# Status and headers. Its body is empty: read the body with stream.read.
def stream.res(st: Stream) -> Stream & Res:
  Stream{tls, s, ms, res, rb, out, decs} = st
  Res{+status, +headers, body} = res
  (Stream{tls, s, ms, Res{status, headers, body}, rb, out, decs}, Res{status, headers, Bytes.new(0)})

def stream.close(st: Stream) -> IO(Unit):
  Stream{tls, s, ms, res, rb, out, decs} = st
  do IO<Unit>:
    good : Bool <- stream.finish(decs)
    io.close(tls, s)

# Head read state: still scanning, cut short or bad, or the head with the bytes after it.
type Sh is Type:
  ShMore{buf: Bytes.Bytes, k: U32}
  ShBad{err: Maybe<&2, Err>}
  ShRes{res: Res, rb: Rb, rest: Bytes.Bytes}

def sh.of(hs: Hs) -> Sh:
  match hs:
    case HsWait{buf, k}:
      ShMore{buf, k}
    case HsBad{}:
      ShBad{None{}}
    case HsSeek{buf, from, k}:
      ShBad{None{}}
    case HsRes{res, rb, rest}:
      ShRes{res, rb, rest}

def sh.piece(+head: Bool, buf: Bytes.Bytes, +k: U32, p: U32 & Array<U32>) -> Sh:
  (+len, b) = p
  Bool.pick(Sh, U32.is_zero(len), ShBad{None{}}, sh.of(hs.more(head, k, buf, Bytes.Bytes{len, b})))

def sh.next(+head: Bool, buf: Bytes.Bytes, +k: U32, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Socket & Sh:
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      (s, ShBad{Some{err.or_late(code, ErrRead{code, why})}})
    case Done{p}:
      (s, sh.piece(head, buf, k, p))

def fetch.fail.of(r: Result<&1, &1, Err, Res>) -> Result<&1, &1, Err, Stream>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{res}:
      Fail{ErrBad{}}

# Reads until the final head is in; the body bytes that came with it are the first piece.
@unsafe
def stream.head(+tls: Bool, +ms: U32, +head: Bool, st: Socket & Sh) -> IO(Result<&1, &1, Err, Stream>):
  (s, sh) = st
  match sh:
    case ShMore{buf, +k}:
      do IO<Result<&1, &1, Err, Stream>>:
        m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv.words(tls, s, 65536, ms)
        stream.head(tls, ms, head, sh.next(head, buf, k, m))
    case ShBad{err}:
      do IO<Result<&1, &1, Err, Stream>>:
        r : Result<&1, &1, Err, Res> <- fetch.bad(tls, s, err)
        return fetch.fail.of(r)
    case ShRes{res, rb, rest}:
      IO.pure(Result<&1, &1, Err, Stream>, Done{stream.mk(tls, s, ms, res, Nil{}, pc.of(rb, rest))})

def stream.sent(+tls: Bool, +ms: U32, +head: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Err, Stream>):
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      do IO<Result<&1, &1, Err, Stream>>:
        io.close(tls, s)
        return Fail{err.or_late(code, ErrWrite{code, why})}
    case Done{u}:
      stream.head(tls, ms, head, (s, ShMore{Bytes.new(0), 0}))

def stream.conn(r: Result<&1, &1, Err, Conn>, +ms: U32, +head: Bool, wire: Bytes.Bytes) -> IO(Result<&1, &1, Err, Stream>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Stream>, Fail{e})
    case Done{c}:
      match c:
        case Conn{+tls, s}:
          do IO<Result<&1, &1, Err, Stream>>:
            sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(tls, s, wire)
            stream.sent(tls, ms, head, sent)
        case ConnH2{s, client}:
          do IO<Result<&1, &1, Err, Stream>>:
            Wire.tls.close(s)
            return Fail{ErrBad{}}

# One connection per stream; the request says close.
def stream.origin(+ms: U32, +head: Bool, wire: Bytes.Bytes, a: Url.Abs, known: Bool) -> IO(Result<&1, &1, Err, Stream>):
  Url.Abs{+scheme, +host, +port, target} = a
  match known:
    case False{}:
      IO.pure(Result<&1, &1, Err, Stream>, Fail{ErrUrl{}})
    case True{}:
      do IO<Result<&1, &1, Err, Stream>>:
        ips : List<&2, String> <- Dns.resolve.all(host)
        c : Result<&1, &1, Err, Conn> <- conn.open.all(String.eq(scheme, "https"), ms, host, port, ips, None{}, False{})
        stream.conn(c, ms, head, wire)

def stream.one.of(+method: String, +url: Url.Abs, +headers: Map<&2, List<&2, String>>, +ms: U32, r: Bytes.Bytes & Bytes.Bytes) -> IO(Hop & Result<&1, &1, Err, Stream>):
  Url.Abs{scheme, host, port, +target} = url
  (body, wire) = r
  do IO<Hop & Result<&1, &1, Err, Stream>>:
    got : Result<&1, &1, Err, Stream> <- stream.origin(ms, String.eq(method, "HEAD"), encode_req.on(method, target, Url.host_field(url), headers, wire, True{}), url, pool.scheme.ok(url))
    return (Hop{method, url, headers, body}, got)

# One request on its own connection. The hop comes back for the redirect.
def stream.one(h: Hop, +ms: U32) -> IO(Hop & Result<&1, &1, Err, Stream>):
  Hop{+method, +url, +headers, body} = h
  stream.one.of(method, url, headers, ms, Bytes.slice(body, 0, 4294967295))

# Go: the next request. Drop: close this stream, then go on. Done: the answer.
type Sn is Type:
  SnGo{left: Nat, hop: Hop}
  SnDrop{st: Stream, next: Next}
  SnDone{r: Result<&1, &1, Err, Stream>}

def sn.of(n: Next) -> Sn:
  match n:
    case NGo{l, h}:
      SnGo{l, h}
    case NStop{}:
      SnDone{Fail{ErrRedirect{}}}
    case NDone{m}:
      match m:
        case Fail{e}:
          SnDone{Fail{e}}
        case Done{r}:
          SnDone{Fail{ErrBad{}}}

def stream.decide.n(st: Stream, n: Next) -> Sn:
  match n:
    case NDone{m}:
      SnDone{Done{st}}
    case NGo{l, h}:
      SnDrop{st, NGo{l, h}}
    case NStop{}:
      SnDrop{st, NStop{}}

def stream.decide.of(+left: Nat, hop: Hop, sr: Stream & Res) -> Sn:
  (st, res) = sr
  stream.decide.n(st, fetch.decide(left, hop, Done{res}))

def stream.decide(+left: Nat, x: Hop & Result<&1, &1, Err, Stream>) -> Sn:
  (hop, r) = x
  match r:
    case Fail{e}:
      SnDone{Fail{e}}
    case Done{st}:
      stream.decide.of(left, hop, stream.res(st))

@unsafe
def stream.hops(+ms: U32, sn: Sn) -> IO(Result<&1, &1, Err, Stream>):
  match sn:
    case SnDone{r}:
      IO.pure(Result<&1, &1, Err, Stream>, r)
    case SnGo{+left, hop}:
      do IO<Result<&1, &1, Err, Stream>>:
        x : Hop & Result<&1, &1, Err, Stream> <- stream.one(hop, ms)
        stream.hops(ms, stream.decide(left, x))
    case SnDrop{st, next}:
      do IO<Result<&1, &1, Err, Stream>>:
        stream.close(st)
        stream.hops(ms, sn.of(next))

type Opened is Type:
  Opened{decs: List<&1, Zlib.Decoder>, bad: Bool}

def stream.open.got(st: Opened, r: Result<&1, &1, U32 & String, Zlib.Decoder>) -> Opened:
  Opened{decs, bad} = st
  match r:
    case Fail{e}:
      Opened{decs, True{}}
    case Done{d}:
      Opened{d <> decs, bad}

def stream.open.add(st: Opened, m: IO(Result<&1, &1, U32 & String, Zlib.Decoder>)) -> IO(Opened):
  do IO<Opened>:
    r : Result<&1, &1, U32 & String, Zlib.Decoder> <- m
    return stream.open.got(st, r)

def stream.open.zstd(zstd: Bool, st: Opened) -> IO(Opened):
  match zstd:
    case True{}:
      stream.open.add(st, Zlib.zstd.new())
    case False{}:
      IO.pure(Opened, st)

def stream.open.br(br: Bool, +c: String, st: Opened) -> IO(Opened):
  match br:
    case True{}:
      stream.open.add(st, Zlib.brotli.new())
    case False{}:
      stream.open.zstd(String.eq(c, "zstd"), st)

def stream.open.gz(gz: Bool, +c: String, st: Opened) -> IO(Opened):
  match gz:
    case True{}:
      stream.open.add(st, Zlib.inflate.new())
    case False{}:
      stream.open.br(String.eq(c, "br"), c, st)

def stream.open.step(+c: String, st: Opened) -> IO(Opened):
  Opened{decs, bad} = st
  match bad:
    case True{}:
      IO.pure(Opened, Opened{decs, True{}})
    case False{}:
      stream.open.gz(Bool.or(String.eq(c, "gzip"), Bool.or(String.eq(c, "x-gzip"), String.eq(c, "deflate"))),
        c, Opened{decs, False{}})

def stream.open.one(prev: IO(Opened), c: String) -> IO(Opened):
  do IO<Opened>:
    st : Opened <- prev
    stream.open.step(c, st)

def stream.open.all(cs: List<&2, String>) -> IO(Opened):
  List.foldl(~&2, ~String, ~IO(Opened), ~stream.open.one, cs, IO.pure(Opened, Opened{Nil{}, False{}}))

def stream.put.decs(st: Stream, decs: List<&1, Zlib.Decoder>) -> Stream:
  Stream{tls, s, ms, res, rb, out, old} = st
  Stream{tls, s, ms, res, rb, out, decs}

def stream.init.opened(st: Stream, opened: Opened) -> IO(Result<&1, &1, Err, Stream>):
  Opened{decs, bad} = opened
  match bad:
    case True{}:
      do IO<Result<&1, &1, Err, Stream>>:
        stream.close(stream.put.decs(st, decs))
        return Fail{ErrBad{}}
    case False{}:
      IO.pure(Result<&1, &1, Err, Stream>, Done{stream.put.decs(st, List.reverse(&1, Zlib.Decoder, decs))})

def stream.init.known(known: Bool, st: Stream, cs: List<&2, String>) -> IO(Result<&1, &1, Err, Stream>):
  match known:
    case False{}:
      IO.pure(Result<&1, &1, Err, Stream>, Done{st})
    case True{}:
      do IO<Result<&1, &1, Err, Stream>>:
        opened : Opened <- stream.open.all(cs)
        stream.init.opened(st, opened)

def stream.init.st(+enc: String, st: Stream) -> IO(Result<&1, &1, Err, Stream>):
  Stream{tls, s, ms, res, rb, out, decs} = st
  Res{+status, +headers, body} = res
  +cs = List.reverse(&2, String, ce.split(fields(headers, "content-encoding")))
  stream.init.known(ce.known(cs, Con{"identity", Con{"x-gzip", ce.split(Con{enc, Nil{}})}}),
    Stream{tls, s, ms, Res{status, headers, body}, rb, out, decs}, cs)

def stream.init(+enc: String, r: Result<&1, &1, Err, Stream>) -> IO(Result<&1, &1, Err, Stream>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Stream>, Fail{e})
    case Done{st}:
      stream.init.st(enc, st)

def stream.start(method: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, u: Maybe<&2, Url.Abs>) -> Sn:
  match u:
    case None{}:
      SnDone{Fail{ErrUrl{}}}
    case Some{a}:
      SnGo{20n, Hop{method, a, req.put(Map.to_list(&2, List<&2, String>, headers), empty()), body}}

# Open a raw stream. Its body bytes and headers remain as sent.
def open.raw.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Result<&1, &1, Err, Stream>):
  stream.hops(ms, stream.start(method, headers, body, Url.absolute(url)))

def open.raw(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Result<&1, &1, Err, Stream>):
  open.raw.with(method, url, headers, body, 30000)

def open.with.enc(+enc: String, method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Result<&1, &1, Err, Stream>):
  do IO<Result<&1, &1, Err, Stream>>:
    r : Result<&1, &1, Err, Stream> <-
      stream.hops(ms, stream.start(method, accept.enc(headers, enc), body, Url.absolute(url)))
    stream.init(enc, r)

# Follow redirects, then decode each body piece by Content-Encoding. Unknown codings stay raw.
def open.with(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes, +ms: U32) -> IO(Result<&1, &1, Err, Stream>):
  do IO<Result<&1, &1, Err, Stream>>:
    enc : String <- codings()
    open.with.enc(enc, method, url, headers, body, ms)

def open(method: String, url: String, headers: Map<&2, List<&2, String>>, body: Bytes.Bytes) -> IO(Result<&1, &1, Err, Stream>):
  open.with(method, url, headers, body, 30000)

# Upload: the request body sent in chunks (RFC 9112 §7.1). err: the first failed write.
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

def up.conn(r: Result<&1, &1, Err, Conn>, +ms: U32, +head: Bool, wire: String) -> IO(Result<&1, &1, Err, Up>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Err, Up>, Fail{e})
    case Done{c}:
      match c:
        case Conn{+tls, s}:
          do IO<Result<&1, &1, Err, Up>>:
            sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(tls, s, wire)
            return Done{up.sent(tls, ms, head, sent)}
        case ConnH2{s, client}:
          do IO<Result<&1, &1, Err, Up>>:
            Wire.tls.close(s)
            return Fail{ErrBad{}}

def up.head(+method: String, +target: String, +hf: String, +headers: Map<&2, List<&2, String>>) -> String:
  request(method, target, set(set(set(req.put(Map.to_list(&2, List<&2, String>, headers), empty()), "host", hf), "connection", "close"), "transfer-encoding", "chunked"), "")

def up.origin(+method: String, +ms: U32, headers: Map<&2, List<&2, String>>, a: Url.Abs, known: Bool) -> IO(Result<&1, &1, Err, Up>):
  Url.Abs{+scheme, +host, +port, +target} = a
  match known:
    case False{}:
      IO.pure(Result<&1, &1, Err, Up>, Fail{ErrUrl{}})
    case True{}:
      do IO<Result<&1, &1, Err, Up>>:
        ips : List<&2, String> <- Dns.resolve.all(host)
        c : Result<&1, &1, Err, Conn> <- conn.open.all(String.eq(scheme, "https"), ms, host, port, ips, None{}, False{})
        up.conn(c, ms, String.eq(method, "HEAD"), up.head(method, target, Url.host_field(a), headers))

def up.url(+method: String, +ms: U32, headers: Map<&2, List<&2, String>>, u: Maybe<&2, Url.Abs>) -> IO(Result<&1, &1, Err, Up>):
  match u:
    case None{}:
      IO.pure(Result<&1, &1, Err, Up>, Fail{ErrUrl{}})
    case Some{+a}:
      up.origin(method, ms, headers, a, pool.scheme.ok(a))

# Http.upload(method, url, headers) sends the head. A streamed body cannot be replayed, so redirects are not followed.
def upload.with(+method: String, url: String, headers: Map<&2, List<&2, String>>, +ms: U32) -> IO(Result<&1, &1, Err, Up>):
  up.url(method, ms, headers, Url.absolute(url))

def upload(+method: String, url: String, headers: Map<&2, List<&2, String>>) -> IO(Result<&1, &1, Err, Up>):
  upload.with(method, url, headers, 30000)

def up.wrote(+tls: Bool, +ms: U32, +head: Bool, m: Socket & Result<&1, &1, U32 & String, Unit>) -> Up & Result<&2, &2, Err, Unit>:
  (s, r) = m
  match r:
    case Fail{(+code, why)}:
      +e = err.or_late(code, ErrWrite{code, why})
      (Up{tls, s, ms, head, Some{e}}, Fail{e})
    case Done{u}:
      (Up{tls, s, ms, head, None{}}, Done{Unit{}})

# One write per chunk, so the size line and the data do not wait on each other (Nagle).
def up.put(+tls: Bool, s: Socket, +ms: U32, +head: Bool, +len: U32, piece: Bytes.Bytes, skip: Bool) -> IO(Up & Result<&2, &2, Err, Unit>):
  match skip:
    case True{}:
      IO.pure(Up & Result<&2, &2, Err, Unit>, (Up{tls, s, ms, head, None{}}, Done{Unit{}}))
    case False{}:
      do IO<Up & Result<&2, &2, Err, Unit>>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(tls, s, Bytes.concat(Con{Bytes.from_string(hex(len) ++ "\r\n"), Con{piece, Con{Bytes.from_string("\r\n"), Nil{}}}}))
        return up.wrote(tls, ms, head, sent)

def up.chunk(+tls: Bool, s: Socket, +ms: U32, +head: Bool, piece: Bytes.Bytes) -> IO(Up & Result<&2, &2, Err, Unit>):
  Bytes.Bytes{+len, buf} = piece
  up.put(tls, s, ms, head, len, Bytes.Bytes{len, buf}, U32.is_zero(len))

# One chunk. An empty piece sends nothing, since an empty chunk would end the body.
def upload.write(up: Up, piece: Bytes.Bytes) -> IO(Up & Result<&2, &2, Err, Unit>):
  Up{+tls, s, +ms, +head, err} = up
  match err:
    case Some{+e}:
      IO.pure(Up & Result<&2, &2, Err, Unit>, (Up{tls, s, ms, head, Some{e}}, Fail{e}))
    case None{}:
      up.chunk(tls, s, ms, head, piece)

# Ends the body and returns the response as a stream.
def upload.finish(up: Up) -> IO(Result<&1, &1, Err, Stream>):
  Up{+tls, s, +ms, +head, err} = up
  match err:
    case Some{e}:
      do IO<Result<&1, &1, Err, Stream>>:
        io.close(tls, s)
        return Fail{e}
    case None{}:
      do IO<Result<&1, &1, Err, Stream>>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(tls, s, "0\r\n\r\n")
        stream.sent(tls, ms, head, sent)

def reply.bytes(res: Res, head: Bool, close: Bool) -> Bytes.Bytes:
  Res{+status, +headers, body} = res
  encode.on(Res{status, Bool.pick(Map<&2, List<&2, String>>, close, set(headers, "connection", "close"), headers), body}, head)

def reply.fail.bytes(+status: U32) -> Res:
  Res{status, empty(), Bytes.from_string(reason(status))}

def reply.sent.close(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (s, r) = m
  Socket.close(s)

def reply_fail(s: Socket, +status: U32) -> IO(Unit):
  do IO<Unit>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(False{}, s, encode(reply.fail.bytes(status)))
    reply.sent.close(sent)


# The head is parsed once, when it is whole. Body pieces are kept as they come and joined once.
type Sv is Type:
  SvHead{buf: Bytes.Bytes}
  SvLen{req: Req, v11: Bool, left: U32, parts: List<&1, Bytes.Bytes>}
  SvChunk{req: Req, v11: Bool, n: U32, st: Dc, parts: List<&1, Bytes.Bytes>}

# More: read on, first answering 100 Continue when cont is set.
type Turn is Type:
  TurnClose{}
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

def sv.chunk.cap(big: Bool, req: Req, +v11: Bool, +n: U32, st: Dc, parts: List<&1, Bytes.Bytes>, piece: Bytes.Bytes) -> Turn:
  match big:
    case True{}:
      TurnFail{413}
    case False{}:
      sv.chunk.of(req, v11, n, ck(piece, st, parts))

def sv.chunk(+max: Nat, req: Req, +v11: Bool, +n: U32, st: Dc, parts: List<&1, Bytes.Bytes>, piece: Bytes.Bytes) -> Turn:
  Bytes.Bytes{+len, buf} = piece
  +n2 = (n + len : U32)
  sv.chunk.cap(Bool.or(U32.is_lt(n2, n), Nat.is_lt(max, U32.to_nat(n2))), req, v11, n2, st, parts, Bytes.Bytes{len, buf})

# RFC 9110 §10.1.1: answer 100 Continue only when the body is still to come.
def sv.cont(want: Bool, t: Turn) -> Turn:
  match t:
    case TurnMore{sv, c}:
      TurnMore{sv, want}
    case TurnClose{}:
      TurnClose{}
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

# RFC 6585 §5: a head over 64 KiB is refused.
def sv.hit(+max: Nat, +len: U32, buf: Bytes.Bytes, at: Maybe<&2, U32>) -> Turn:
  match at:
    case None{}:
      sv.hit.none(U32.is_lt(65536, len), buf)
    case Some{+i}:
      +hlen = (i + 4 : U32)
      sv.hit.some(U32.is_lt(65536, hlen), max, hlen, len, buf)

def sv.seek.of(+max: Nat, +len: U32, +from: U32, buf: Bytes.Bytes, r: Bytes.Bytes & Maybe<&2, U32>) -> Turn:
  (tail, m) = r
  sv.hit(max, len, buf, found.at(from, m))

def sv.seek(+max: Nat, +len: U32, +from: U32, r: Bytes.Bytes & Bytes.Bytes) -> Turn:
  (buf, tail) = r
  sv.seek.of(max, len, from, buf, Bytes.find(tail, "\r\n\r\n"))

# Only the new bytes, and the 3 before them, can finish the blank line.
def sv.head.at(+max: Nat, +from: U32, buf: Bytes.Bytes) -> Turn:
  Bytes.Bytes{+len, b} = buf
  sv.seek(max, len, from, Bytes.slice(Bytes.Bytes{len, b}, from, (len - from : U32)))

def sv.head(+max: Nat, buf: Bytes.Bytes, piece: Bytes.Bytes) -> Turn:
  Bytes.Bytes{+ol, ob} = buf
  sv.head.at(max, Bool.pick(U32, U32.is_lt(ol, 3), 0, (ol - 3 : U32)), Bytes.append(Bytes.Bytes{ol, ob}, piece))

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
def sv.step(closed: Bool, +max: Nat, sv: Sv, piece: Bytes.Bytes) -> Turn:
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
          sv.head(max, buf, piece)
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

def sv.frame.go(xs: List<&2, String>, t: Turn) -> Maybe<&1, String & String>:
  match xs:
    case Nil{}:
      sv.frame.req(t)
    case Con{+x, rest}:
      match t:
        case TurnMore{sv, c}:
          sv.frame.go(rest, sv.step(False{}, serve.max(), sv, Bytes.from_string(x)))
        case TurnReq{req, r, v11}:
          sv.frame.req(TurnReq{req, r, v11})
        case TurnFail{s}:
          None{}
        case TurnClose{}:
          None{}

# The body and the bytes after it, once the pieces make a whole request; None otherwise.
def serve.frame(xs: List<&2, String>) -> Maybe<&1, String & String>:
  sv.frame.go(xs, TurnMore{sv.none(), False{}})

def talk.piece(+max: Nat, sv: Sv, p: U32 & Array<U32>) -> Turn:
  (+len, buf) = p
  sv.step(U32.is_eq(len, 0), max, sv, Bytes.Bytes{len, buf})

def talk.next(+max: Nat, sv: Sv, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Socket & Turn:
  (s, r) = m
  match r:
    case Fail{e}:
      (s, TurnClose{})
    case Done{p}:
      (s, talk.piece(max, sv, p))

def talk.after.pick(empty: Bool, +max: Nat, rest: Bytes.Bytes) -> Turn:
  match empty:
    case True{}:
      TurnMore{sv.none(), False{}}
    case False{}:
      sv.step(False{}, max, sv.none(), rest)

def talk.after.rest(+max: Nat, rest: Bytes.Bytes, s: Socket) -> Socket & Turn:
  Bytes.Bytes{+len, buf} = rest
  (s, talk.after.pick(U32.is_eq(len, 0), max, Bytes.Bytes{len, buf}))

def talk.after.keep(keep: Bool, +max: Nat, rest: Bytes.Bytes, s: Socket) -> Socket & Turn:
  match keep:
    case False{}:
      (s, TurnClose{})
    case True{}:
      talk.after.rest(max, rest, s)

def talk.after(+max: Nat, keep: Bool, rest: Bytes.Bytes, m: Socket & Result<&1, &1, U32 & String, Unit>) -> Socket & Turn:
  (s, r) = m
  match r:
    case Fail{e}:
      (s, TurnClose{})
    case Done{u}:
      talk.after.keep(keep, max, rest, s)

def talk.send(+max: Nat, s: Socket, rest: Bytes.Bytes, +headers: Map<&2, List<&2, String>>, v11: Bool, +head: Bool, res: Res) -> IO(Socket & Turn):
  Res{+status, +rh, body} = res
  +keep = serve.keep(headers, v11, status, rh)
  do IO<Socket & Turn>:
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- io.send.bytes(False{}, s, reply.bytes(Res{status, rh, body}, head, Bool.not(keep)))
    return talk.after(max, keep, rest, sent)

def talk.cont.sent(m: Socket & Result<&1, &1, U32 & String, Unit>) -> Socket:
  (s, r) = m
  s

def talk.cont(cont: Bool, s: Socket) -> IO(Socket):
  match cont:
    case False{}:
      IO.pure(Socket, s)
    case True{}:
      do IO<Socket>:
        sent : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send(s, "HTTP/1.1 100 Continue\r\n\r\n")
        return talk.cont.sent(sent)

@unsafe
def talk(~h: Req -> IO(Res), +max: Nat, st: Socket & Turn) -> IO(Unit):
  (s, t) = st
  match t:
    case TurnMore{sv, cont}:
      do IO<Unit>:
        s2 : Socket <- talk.cont(cont, s)
        m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(s2, 65536, 30000)
        talk(~h, max, talk.next(max, sv, m))
    case TurnReq{req, rest, v11}:
      Req{+method, path, +headers, body} = req
      do IO<Unit>:
        res : Res <- h(Req{method, path, headers, body})
        next : Socket & Turn <- talk.send(max, s, rest, headers, v11, String.eq(method, "HEAD"), res)
        talk(~h, max, next)
    case TurnFail{status}:
      reply_fail(s, status)
    case TurnClose{}:
      Socket.close(s)

def conn(~h: Req -> IO(Res), +max: Nat, m: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Listener):
  (l, r) = m
  do IO<Listener>:
    s : Socket <- IO.pass(Socket, r)
    IO.spawn(Unit, talk(~h, max, (s, TurnMore{sv.none(), False{}})))
    return l

@unsafe
def loop(~h: Req -> IO(Res), +max: Nat, l: Listener) -> IO(Unit):
  do IO<Unit>:
    m  : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(l)
    l2 : Listener <- conn(~h, max, m)
    loop(~h, max, l2)

def serve.with(~h: Req -> IO(Res), +port: U32, +max: Nat) -> IO(Unit):
  do IO<Unit>:
    l : Listener <- IO.try(Listener, TCP.listen(port))
    IO.print("http://127.0.0.1:" ++ U32.show(port))
    loop(~h, max, l)

def serve(~h: Req -> IO(Res), +port: U32) -> IO(Unit):
  serve.with(~h, port, serve.max())
