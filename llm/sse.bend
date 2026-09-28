# Server-Sent Events parser (WHATWG HTML §9.2.6), fed in pieces. Source: https://github.com/paymog/bend-kit/tree/main/llm
import Base
# By hash, as http imports it: bend-kit-bytes@0.3.0.0.
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# name: the event type, "message" when the stream sets none. data: the data lines joined by LF.
# id: the last event ID the stream set. name and id hold one Char per octet.
type Message is Type:
  Message{name: String, data: Bytes.Bytes, id: String}

# The event so far: its type, its data lines each ended by LF, the last event ID, and the last retry in ms.
type St is Type:
  St{name: String, data: Bytes.Bytes, id: String, retry: Maybe<&2, U32>}

# buf from pos: bytes not yet read as lines. No CR or LF is between pos and seen.
# cr: the last line ended with a CR at the end of buf, so an LF first belongs to it.
type Reader is Type:
  Reader{buf: Bytes.Bytes, pos: U32, seen: U32, cr: Bool, st: St}

type Next is Type:
  Got{e: Message}
  Want{}

# ponytail: a leading U+FEFF is not dropped; the LLM APIs never send one.
def reader() -> Reader:
  Reader{Bytes.new(0), 0, 0, False{}, St{"", Bytes.new(0), "", None{}}}

def feed.at(zero: Bool, buf: Bytes.Bytes, +pos: U32, +seen: U32, cr: Bool, st: St, chunk: Bytes.Bytes) -> Reader:
  match zero:
    case True{}:
      Reader{Bytes.append(buf, chunk), 0, seen, cr, st}
    case False{}:
      Reader{Bytes.append(Bytes.snd(Bytes.slice(buf, pos, 4294967295)), chunk), 0, (U32.max(seen, pos) - pos : U32), cr, st}

# Drops the lines already read, then adds chunk.
def feed(r: Reader, chunk: Bytes.Bytes) -> Reader:
  Reader{buf, +pos, +seen, cr, st} = r
  feed.at(U32.is_zero(pos), buf, pos, seen, cr, st, chunk)

# The last retry field, in ms.
def retry(r: Reader) -> Reader & Maybe<&2, U32>:
  Reader{buf, pos, seen, cr, St{name, data, id, +m}} = r
  (Reader{buf, pos, seen, cr, St{name, data, id, m}}, m)

# The first CR or LF at or after i, or the end. f counts the bytes from i to the end; r holds byte i.
def eol(f: Nat, r: Array<U32> & U32, +i: U32) -> Array<U32> & U32:
  match f:
    case 0n:
      (a, c) = r
      (a, i)
    case 1n+p:
      (a, +c) = r
      match c:
        case 10:
          (a, i)
        case 13:
          (a, i)
        case _:
          eol(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))

# The first colon at or after i, or the line's end. f counts the bytes from i to the line's end; r holds byte i.
def colon(f: Nat, r: Array<U32> & U32, +i: U32) -> Array<U32> & U32:
  match f:
    case 0n:
      (a, c) = r
      (a, i)
    case 1n+p:
      (a, +c) = r
      match c:
        case 58:
          (a, i)
        case _:
          colon(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))

# Base-ten digits, at most 9 of them; None for any other text.
def digits(s: String, +acc: U32, +n: U32, bad: Bool) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      Bool.pick(Maybe<&2, U32>, Bool.or(bad, Bool.or(U32.is_zero(n), U32.is_lt(9, n))), None{}, Some{acc})
    case SCon{Chr{+c}, t}:
      digits(t, (acc * 10 + (c - 48 : U32) : U32), (n + 1 : U32), Bool.or(bad, Bool.or(U32.is_lt(c, 48), U32.is_lt(57, c))))

def has_nul(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.or(U32.is_zero(c), has_nul(t))

def lf() -> Bytes.Bytes:
  Bytes.from_string("\n")

def kind.is(+k: U32, r: Array<U32> & Bool) -> Array<U32> & U32:
  (a, +hit) = r
  (a, Bool.pick(U32, hit, k, 0))

def kind.five(+s: U32, r: Array<U32> & Bool) -> Array<U32> & U32:
  (a, hit) = r
  match hit:
    case True{}:
      (a, 2)
    case False{}:
      kind.is(4, Bytes.at(a, "retry", s))

# The kind of the field whose n-byte name starts at s: 1 data, 2 event, 3 id, 4 retry, 0 any other.
def kind(+n: U32, a: Array<U32>, +s: U32) -> Array<U32> & U32:
  match n:
    case 2:
      kind.is(3, Bytes.at(a, "id", s))
    case 4:
      kind.is(1, Bytes.at(a, "data", s))
    case 5:
      kind.five(s, Bytes.at(a, "event", s))
    case _:
      (a, 0)

def set.retry(m: Maybe<&2, U32>, old: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match m:
    case None{}:
      old
    case Some{x}:
      Some{x}

# The event after a field of kind k with value v. An id with NUL and a retry that is not digits change nothing.
def set(+k: U32, v: Bytes.Bytes, st: St) -> St:
  match k:
    case 1:
      St{name, data, id, retry} = st
      St{name, Bytes.append(Bytes.append(data, v), lf()), id, retry}
    case 2:
      St{old, data, id, retry} = st
      St{Bytes.to_string(v), data, id, retry}
    case 3:
      St{name, data, old, retry} = st
      +s = Bytes.to_string(v)
      St{name, data, Bool.pick(String, has_nul(s), old, s), retry}
    case 4:
      St{name, data, id, old} = st
      St{name, data, id, set.retry(digits(Bytes.to_string(v), 0, 0, False{}), old)}
    case _:
      st

def field.put(+k: U32, st: St, r: Bytes.Bytes & Bytes.Bytes) -> Array<U32> & St:
  (Bytes.Bytes{l, a}, v) = r
  (a, set(k, v, st))

def field.set(+len: U32, +v: U32, +e: U32, st: St, r: Array<U32> & U32) -> Array<U32> & St:
  (a, +k) = r
  field.put(k, st, Bytes.slice(Bytes.Bytes{len, a}, v, (e - v : U32)))

# r holds the byte after the colon at c. The value starts after the colon and one space, if there is one.
def field.at(+s: U32, +c: U32, +e: U32, +len: U32, st: St, r: Array<U32> & U32) -> Array<U32> & St:
  (a, +b) = r
  +v = Bool.pick(U32, U32.is_eq(c, e), e, Bool.pick(U32, Bool.and(U32.is_lt((c + 1 : U32), e), U32.is_eq(b, 32)), (c + 2 : U32), (c + 1 : U32)))
  field.set(len, v, e, st, kind((c - s : U32), a, s))

def field.colon(+s: U32, +e: U32, +len: U32, st: St, r: Array<U32> & U32) -> Array<U32> & St:
  (a, +c) = r
  field.at(s, c, e, len, st, Bytes.peek(a, (c + 1 : U32)))

# The line from s to e as a field: the name up to the first colon, the value after it. A comment's name is empty.
def field(a: Array<U32>, +len: U32, +s: U32, +e: U32, st: St) -> Array<U32> & St:
  field.colon(s, e, len, st, colon(U32.to_nat((e - s : U32)), Bytes.peek(a, s), s))

# Drops the last LF. Bytes past len stay 0.
def trim(b: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+n, buf} = b
  Bytes.Bytes{(n - 1 : U32), Bytes.poke(buf, (n - 1 : U32), 0)}

def dispatch.of(empty: Bool, +name: String, data: Bytes.Bytes, +id: String, retry: Maybe<&2, U32>) -> St & Maybe<&1, Message>:
  match empty:
    case True{}:
      (St{"", data, id, retry}, None{})
    case False{}:
      (St{"", Bytes.new(0), id, retry}, Some{Message{Bool.pick(String, String.is_empty(name), "message", name), trim(data), id}})

# A blank line: the event, when it has data. Either way the event type starts over.
def dispatch(st: St) -> St & Maybe<&1, Message>:
  St{name, Bytes.Bytes{+n, buf}, id, retry} = st
  dispatch.of(U32.is_zero(n), name, Bytes.Bytes{n, buf}, id, retry)

# A line was read and more may follow; the bytes ran out first; or a line ended an event.
type Line is Type:
  LMore{a: Array<U32>, pos: U32, cr: Bool, st: St}
  LWant{a: Array<U32>, pos: U32, cr: Bool, st: St}
  LGot{a: Array<U32>, pos: U32, cr: Bool, st: St, e: Message}

def line.got(a: Array<U32>, +next: U32, cr: Bool, r: St & Maybe<&1, Message>) -> Line:
  (st, m) = r
  match m:
    case None{}:
      LMore{a, next, cr, st}
    case Some{e}:
      LGot{a, next, cr, st, e}

def line.set(+next: U32, cr: Bool, r: Array<U32> & St) -> Line:
  (a, st) = r
  LMore{a, next, cr, st}

# The line from s to e; the next line starts at next.
def line.body(blank: Bool, a: Array<U32>, +len: U32, +s: U32, +e: U32, +next: U32, cr: Bool, st: St) -> Line:
  match blank:
    case True{}:
      line.got(a, next, cr, dispatch(st))
    case False{}:
      line.set(next, cr, field(a, len, s, e, st))

def line.crlf(+len: U32, +s: U32, +e: U32, st: St, r: Array<U32> & U32) -> Line:
  (a, +c) = r
  line.body(U32.is_eq(s, e), a, len, s, e, Bool.pick(U32, U32.is_eq(c, 10), (e + 2 : U32), (e + 1 : U32)), False{}, st)

# A CR at e. With nothing after it yet, an LF may still come.
def line.cr(more: Bool, a: Array<U32>, +len: U32, +s: U32, +e: U32, st: St) -> Line:
  match more:
    case True{}:
      line.crlf(len, s, e, st, Bytes.peek(a, (e + 1 : U32)))
    case False{}:
      line.body(U32.is_eq(s, e), a, len, s, e, (e + 1 : U32), True{}, st)

def line.term(+len: U32, +s: U32, +e: U32, st: St, r: Array<U32> & U32) -> Line:
  (a, +t) = r
  match t:
    case 13:
      line.cr(U32.is_lt((e + 1 : U32), len), a, len, s, e, st)
    case _:
      line.body(U32.is_eq(s, e), a, len, s, e, (e + 1 : U32), False{}, st)

def line.end(want: Bool, a: Array<U32>, +len: U32, +s: U32, +e: U32, cr: Bool, st: St) -> Line:
  match want:
    case True{}:
      LWant{a, s, cr, st}
    case False{}:
      line.term(len, s, e, st, Bytes.peek(a, e))

def line.eol(+len: U32, +s: U32, cr: Bool, st: St, r: Array<U32> & U32) -> Line:
  (a, +e) = r
  line.end(U32.is_eq(e, len), a, len, s, e, cr, st)

# The line that starts at s. No CR or LF lies between s and seen.
def line(a: Array<U32>, +len: U32, +s: U32, +seen: U32, cr: Bool, st: St) -> Line:
  +i = U32.max(s, seen)
  line.eol(len, s, cr, st, eol(U32.to_nat((len - i : U32)), Bytes.peek(a, i), i))

def stop(l: Line, +len: U32) -> Reader & Next:
  match l:
    case LMore{a, +pos, cr, st}:
      (Reader{Bytes.Bytes{len, a}, pos, pos, cr, st}, Want{})
    case LWant{a, +pos, cr, st}:
      (Reader{Bytes.Bytes{len, a}, pos, len, cr, st}, Want{})
    case LGot{a, +pos, cr, st, e}:
      (Reader{Bytes.Bytes{len, a}, pos, pos, cr, st}, Got{e})

# f: at least the lines left, plus one.
def loop(f: Nat, l: Line, +len: U32) -> Reader & Next:
  match f:
    case 0n:
      stop(l, len)
    case 1n+p:
      match l:
        case LMore{a, +pos, cr, st}:
          loop(p, line(a, len, pos, pos, cr, st), len)
        case LWant{a, +pos, cr, st}:
          stop(LWant{a, pos, cr, st}, len)
        case LGot{a, +pos, cr, st, e}:
          stop(LGot{a, pos, cr, st, e}, len)

def skip.byte(+pos: U32, r: Array<U32> & U32) -> Array<U32> & U32 & Bool:
  (a, +c) = r
  (a, Bool.pick(U32, U32.is_eq(c, 10), (pos + 1 : U32), pos), False{})

def skip.at(some: Bool, a: Array<U32>, +pos: U32) -> Array<U32> & U32 & Bool:
  match some:
    case True{}:
      skip.byte(pos, Bytes.peek(a, pos))
    case False{}:
      (a, pos, True{})

# After a CR that ended the last piece, an LF first belongs to that CR.
def skip(cr: Bool, a: Array<U32>, +len: U32, +pos: U32) -> Array<U32> & U32 & Bool:
  match cr:
    case True{}:
      skip.at(U32.is_lt(pos, len), a, pos)
    case False{}:
      (a, pos, False{})

def next.at(+len: U32, +seen: U32, st: St, r: Array<U32> & U32 & Bool) -> Reader & Next:
  (a, +pos, cr) = r
  loop(Nat.add(U32.to_nat((len - pos : U32)), 2n), line(a, len, pos, seen, cr, st), len)

# The next whole event, or Want when the bytes run out first. A blank line with no data before it gives no event.
def next(r: Reader) -> Reader & Next:
  Reader{Bytes.Bytes{+len, a}, +pos, +seen, cr, st} = r
  next.at(len, seen, st, skip(cr, a, len, pos))
