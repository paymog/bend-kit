# CSV (RFC 4180) over bytes: a record cursor, a whole-document parse, and an encoder. Source: https://github.com/paymog/bend-kit/tree/main/csv
import Base
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Fields are Bytes, taken as they are: no charset, no trimming. A record ends at
# CRLF, LF, or a lone CR, and the last line end is optional. A quoted field may
# hold commas, CR, LF, and "" for one quote. An empty line has no fields.
#   import ./csv/csv.bend as Csv

# The unread bytes and the offset of the next record.
type Cur is Type:
  Cur{src: Bytes.Bytes, at: U32}

# One step of the cursor: a record and the cursor after it, the end of input, or
# the offset of the first byte that breaks RFC 4180.
type Next is Type:
  Row{fields: List<&1, Bytes.Bytes>, cur: Cur}
  End{}
  Bad{at: U32}

# Reader
# ------
# A field's bytes are src[s..e]. esc says the field was quoted and holds "".
type Span is Data:
  Span{s: U32, e: U32, esc: Bool}

# Spans are latest first.
type Scan is Data:
  SRow{sp: List<&2, Span>, at: U32}
  SBad{at: U32}

# Start: before a field. Unq: in an unquoted field. Q: in a quoted field.
# QQ: just past a quote inside a quoted field. CR: just past a record's CR.
type St is Data:
  SStart{}
  SUnq{}
  SQ{}
  SQQ{}
  SCR{}

# Byte i, or 256 past the end.
def pk.if(ok: Bool, a: Array<U32>, +i: U32) -> Array<U32> & U32:
  match ok:
    case True{}:
      Bytes.peek(a, i)
    case False{}:
      (a, 256)

def pk(a: Array<U32>, +len: U32, +i: U32) -> Array<U32> & U32:
  pk.if(U32.is_lt(i, len), a, i)

# An empty line has no fields; a trailing comma adds an empty field.
def start.sp(sp: List<&2, Span>, +i: U32) -> List<&2, Span>:
  match sp:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Span{i, i, False{}} <> Con{h, t}


# r holds byte i. s is where the open field starts. Every step but the last reads one byte.
def rec.go(f: Nat, st: St, r: Array<U32> & U32, +len: U32, +i: U32, +s: U32, +esc: Bool, +sp: List<&2, Span>) -> Array<U32> & Scan:
  match f:
    case 0n:
      (a, c) = r
      (a, SBad{i})
    case 1n+p:
      match st:
        case SStart{}:
          (a, +c) = r
          match c:
            case 34:
              rec.go(p, SQ{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), (i + 1 : U32), False{}, sp)
            case 44:
              rec.go(p, SStart{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), (i + 1 : U32), False{}, Span{i, i, False{}} <> sp)
            case 10:
              (a, SRow{start.sp(sp, i), (i + 1 : U32)})
            case 13:
              rec.go(p, SCR{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), (i + 1 : U32), False{}, start.sp(sp, i))
            case 256:
              (a, SRow{start.sp(sp, i), i})
            case _:
              rec.go(p, SUnq{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), i, False{}, sp)
        case SUnq{}:
          (a, +c) = r
          match c:
            case 44:
              rec.go(p, SStart{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), (i + 1 : U32), False{}, Span{s, i, False{}} <> sp)
            case 10:
              (a, SRow{Span{s, i, False{}} <> sp, (i + 1 : U32)})
            case 13:
              rec.go(p, SCR{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), (i + 1 : U32), False{}, Span{s, i, False{}} <> sp)
            case 256:
              (a, SRow{Span{s, i, False{}} <> sp, i})
            case 34:
              (a, SBad{i})
            case _:
              rec.go(p, SUnq{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), s, False{}, sp)
        case SQ{}:
          (a, +c) = r
          match c:
            case 34:
              rec.go(p, SQQ{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), s, esc, sp)
            case 256:
              (a, SBad{i})
            case _:
              rec.go(p, SQ{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), s, esc, sp)
        case SQQ{}:
          (a, +c) = r
          match c:
            case 34:
              rec.go(p, SQ{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), s, True{}, sp)
            case 44:
              rec.go(p, SStart{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), (i + 1 : U32), False{}, Span{s, (i - 1 : U32), esc} <> sp)
            case 10:
              (a, SRow{Span{s, (i - 1 : U32), esc} <> sp, (i + 1 : U32)})
            case 13:
              rec.go(p, SCR{}, pk(a, len, (i + 1 : U32)), len, (i + 1 : U32), (i + 1 : U32), False{}, Span{s, (i - 1 : U32), esc} <> sp)
            case 256:
              (a, SRow{Span{s, (i - 1 : U32), esc} <> sp, i})
            case _:
              (a, SBad{i})
        case SCR{}:
          (a, +c) = r
          match c:
            case 10:
              (a, SRow{sp, (i + 1 : U32)})
            case _:
              (a, SRow{sp, i})

def q() -> Bytes.Bytes:
  Bytes.from_string("\"")

def qq() -> Bytes.Bytes:
  Bytes.from_string("\"\"")

# Pieces between "" pairs, latest first, with one quote between each.
def unq.go(xs: List<&1, Bytes.Bytes>, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      unq.go(t, h <> q() <> acc)

def unq.of(xs: List<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match xs:
    case Nil{}:
      Bytes.new(0)
    case Con{h, t}:
      Bytes.concat(List.reverse(&1, Bytes.Bytes, unq.go(t, [h])))

# A quoted field's inner bytes with each "" as one quote. Quotes inside come in pairs.
def field.of(esc: Bool, b: Bytes.Bytes) -> Bytes.Bytes:
  match esc:
    case True{}:
      unq.of(Bytes.split(b, "\"\""))
    case False{}:
      b

def cut.fin(+m: U32, +esc: Bool, r: Array<U32> & Array<U32>, acc: List<&1, Bytes.Bytes>) -> Array<U32> & List<&1, Bytes.Bytes>:
  (a, d) = r
  (a, field.of(esc, Bytes.Bytes{m, d}) <> acc)

# Spans latest first give fields in order.
def cut.go(sp: List<&2, Span>, r: Array<U32> & List<&1, Bytes.Bytes>) -> Array<U32> & List<&1, Bytes.Bytes>:
  match sp:
    case Nil{}:
      r
    case Con{Span{+s, +e, +esc}, t}:
      (a, acc) = r
      +m = (e - s : U32)
      cut.go(t, cut.fin(m, esc, Bytes.copy(m, a, Bytes.alloc(m), s, 0), acc))

def next.fin(+len: U32, +at: U32, r: Array<U32> & List<&1, Bytes.Bytes>) -> Next:
  (a, fs) = r
  Row{fs, Cur{Bytes.Bytes{len, a}, at}}

def next.row(+len: U32, r: Array<U32> & Scan) -> Next:
  (a, sc) = r
  match sc:
    case SRow{sp, +at}:
      next.fin(len, at, cut.go(sp, (a, Nil{})))
    case SBad{+at}:
      Bad{at}

def next.if(more: Bool, +len: U32, buf: Array<U32>, +at: U32) -> Next:
  match more:
    case False{}:
      End{}
    case True{}:
      next.row(len, rec.go(U32.to_nat((len - at + 1 : U32)), SStart{}, pk(buf, len, at), len, at, at, False{}, Nil{}))

# A cursor at the first record.
def cursor(b: Bytes.Bytes) -> Cur:
  Cur{b, 0}

# The next record, End at the end of input, or Bad with the offset of the first bad byte.
def next(c: Cur) -> Next:
  Cur{Bytes.Bytes{+len, buf}, +at} = c
  next.if(U32.is_lt(at, len), len, buf, at)

# Each record reads at least one byte, so len + 1 steps are enough.
def parse.go(f: Nat, nx: Next, acc: List<&1, List<&1, Bytes.Bytes>>) -> Result<&1, &1, U32, List<&1, List<&1, Bytes.Bytes>>>:
  match f:
    case 0n:
      Fail{0}
    case 1n+p:
      match nx:
        case End{}:
          Done{List.reverse(&1, List<&1, Bytes.Bytes>, acc)}
        case Bad{+at}:
          Fail{at}
        case Row{fs, cur}:
          parse.go(p, next(cur), fs <> acc)

# Every record, or Fail with the offset of the first bad byte.
def parse(b: Bytes.Bytes) -> Result<&1, &1, U32, List<&1, List<&1, Bytes.Bytes>>>:
  Bytes.Bytes{+len, buf} = b
  parse.go(U32.to_nat((len + 1 : U32)), next(Cur{Bytes.Bytes{len, buf}, 0}), Nil{})

# Writer
# ------
# Does a byte from i on need quotes? n counts the bytes left.
def needs.go(n: Nat, r: Array<U32> & U32, +i: U32) -> Array<U32> & Bool:
  match n:
    case 0n:
      (a, c) = r
      (a, False{})
    case 1n+p:
      (a, +c) = r
      match c:
        case 34:
          (a, True{})
        case 44:
          (a, True{})
        case 10:
          (a, True{})
        case 13:
          (a, True{})
        case _:
          needs.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))

# The pieces after the first, each after "".
def enc.rest(xs: List<&1, Bytes.Bytes>, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      enc.rest(t, h <> qq() <> acc)

def enc.parts(xs: List<&1, Bytes.Bytes>, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      q() <> enc.rest(t, h <> q() <> acc)

def enc.pick(+len: U32, r: Array<U32> & Bool, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  (a, quote) = r
  match quote:
    case False{}:
      Bytes.Bytes{len, a} <> acc
    case True{}:
      enc.parts(Bytes.split(Bytes.Bytes{len, a}, "\""), acc)

# Pieces are latest first. A field is quoted only when it holds a quote, comma, CR, or LF.
def enc.field(f: Bytes.Bytes, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  Bytes.Bytes{+len, buf} = f
  enc.pick(len, needs.go(U32.to_nat(len), Bytes.peek(buf, 0), 0), acc)

def enc.more(fs: List<&1, Bytes.Bytes>, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match fs:
    case Nil{}:
      acc
    case Con{h, t}:
      enc.more(t, enc.field(h, Bytes.from_string(",") <> acc))

def enc.only.if(empty: Bool, f: Bytes.Bytes, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match empty:
    case True{}:
      Bytes.from_string("\"\"") <> acc
    case False{}:
      enc.field(f, acc)

def enc.only(f: Bytes.Bytes, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  Bytes.Bytes{+len, buf} = f
  enc.only.if(U32.is_eq(len, 0), Bytes.Bytes{len, buf}, acc)


def enc.fields(fs: List<&1, Bytes.Bytes>, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match fs:
    case Nil{}:
      acc
    case Con{h, Nil{}}:
      enc.only(h, acc)
    case Con{h, t}:
      enc.more(t, enc.field(h, acc))

def enc.recs(rs: List<&1, List<&1, Bytes.Bytes>>, acc: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match rs:
    case Nil{}:
      acc
    case Con{r, t}:
      enc.recs(t, Bytes.from_string("\r\n") <> enc.fields(r, acc))

# Records as RFC 4180 text: fields joined by commas, each record ended by CRLF.
def encode(rs: List<&1, List<&1, Bytes.Bytes>>) -> Bytes.Bytes:
  Bytes.concat(List.reverse(&1, Bytes.Bytes, enc.recs(rs, Nil{})))
