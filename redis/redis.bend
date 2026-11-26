# Redis and Valkey client: RESP3 over TCP or TLS, with pipelining and a pool. Source: https://github.com/paymog/bend-kit/tree/main/redis
import Base
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-wire@0.4.8.1/wire.bend as Wire
import bend-kit-dns@0.8.0.2/dns.bend as Dns
import ./pure.bend as Pure

type Val is Type:
  Simple{text: Bytes.Bytes}
  Error{text: Bytes.Bytes}
  Int{hi: U32, lo: U32}
  Bulk{data: Bytes.Bytes}
  Arr{items: List<&1, Val>}
  Null{}
  Boolean{value: Bool}
  Double{text: Bytes.Bytes}
  BigNum{text: Bytes.Bytes}
  BulkError{text: Bytes.Bytes}
  Verbatim{format: Bytes.Bytes, text: Bytes.Bytes}
  Dict{items: List<&1, Val>}
  Set{items: List<&1, Val>}
  Attr{items: List<&1, Val>}
  Push{items: List<&1, Val>}

type E is Type:
  E{o: Bytes.Bytes, ok: Bool, n: U32}

type Num is Data:
  Num{neg: Bool, hi: U32, lo: U32, ok: Bool}

type Frame is Type:
  Frame{kind: U32, left: U32, xs: List<&1, Val>}

type St is Type:
  SHead{i: U32, stack: List<&1, Frame>}
  SLine{t: U32, i: U32, scan: U32, stack: List<&1, Frame>}
  SBlob{kind: U32, n: U32, next: U32, stack: List<&1, Frame>}
  SWait{state: St}
  SDone{v: Val, i: U32, stack: List<&1, Frame>}
  SOk{v: Val, i: U32}
  SMore{}
  SBad{}

type Step is Type:
  Reply{v: Val, next: U32}
  More{}
  Bad{}

type Reader is Type:
  Reader{state: Pure.Reader}

type Next is Type:
  Got{v: Val}
  Want{}
  Broken{}

def val.to.list(xs: List<&1, Val>) -> List<&1, Pure.Val>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Simple{text}, rest}:
      Con{Pure.Simple{text}, val.to.list(rest)}
    case Con{Error{text}, rest}:
      Con{Pure.Error{text}, val.to.list(rest)}
    case Con{Int{hi, lo}, rest}:
      Con{Pure.Int{hi, lo}, val.to.list(rest)}
    case Con{Bulk{data}, rest}:
      Con{Pure.Bulk{data}, val.to.list(rest)}
    case Con{Arr{items}, rest}:
      Con{Pure.Arr{val.to.list(items)}, val.to.list(rest)}
    case Con{Null{}, rest}:
      Con{Pure.Null{}, val.to.list(rest)}
    case Con{Boolean{value}, rest}:
      Con{Pure.Boolean{value}, val.to.list(rest)}
    case Con{Double{text}, rest}:
      Con{Pure.Double{text}, val.to.list(rest)}
    case Con{BigNum{text}, rest}:
      Con{Pure.BigNum{text}, val.to.list(rest)}
    case Con{BulkError{text}, rest}:
      Con{Pure.BulkError{text}, val.to.list(rest)}
    case Con{Verbatim{format, text}, rest}:
      Con{Pure.Verbatim{format, text}, val.to.list(rest)}
    case Con{Dict{items}, rest}:
      Con{Pure.Dict{val.to.list(items)}, val.to.list(rest)}
    case Con{Set{items}, rest}:
      Con{Pure.Set{val.to.list(items)}, val.to.list(rest)}
    case Con{Attr{items}, rest}:
      Con{Pure.Attr{val.to.list(items)}, val.to.list(rest)}
    case Con{Push{items}, rest}:
      Con{Pure.Push{val.to.list(items)}, val.to.list(rest)}


def val.to(v: Val) -> Pure.Val:
  match v:
    case Simple{text}:
      Pure.Simple{text}
    case Error{text}:
      Pure.Error{text}
    case Int{hi, lo}:
      Pure.Int{hi, lo}
    case Bulk{data}:
      Pure.Bulk{data}
    case Arr{items}:
      Pure.Arr{val.to.list(items)}
    case Null{}:
      Pure.Null{}
    case Boolean{value}:
      Pure.Boolean{value}
    case Double{text}:
      Pure.Double{text}
    case BigNum{text}:
      Pure.BigNum{text}
    case BulkError{text}:
      Pure.BulkError{text}
    case Verbatim{format, text}:
      Pure.Verbatim{format, text}
    case Dict{items}:
      Pure.Dict{val.to.list(items)}
    case Set{items}:
      Pure.Set{val.to.list(items)}
    case Attr{items}:
      Pure.Attr{val.to.list(items)}
    case Push{items}:
      Pure.Push{val.to.list(items)}

def frame.to(v: Frame) -> Pure.Frame:
  match v:
    case Frame{kind, left, xs}:
      Pure.Frame{kind, left, val.to.list(xs)}

def frame.to.list(r: List<&1, Frame>) -> List<&1, Pure.Frame>:
  List.map(~Frame, ~Pure.Frame, ~(x => frame.to(x)), r)

def val.from.list(xs: List<&1, Pure.Val>) -> List<&1, Val>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Pure.Simple{text}, rest}:
      Con{Simple{text}, val.from.list(rest)}
    case Con{Pure.Error{text}, rest}:
      Con{Error{text}, val.from.list(rest)}
    case Con{Pure.Int{hi, lo}, rest}:
      Con{Int{hi, lo}, val.from.list(rest)}
    case Con{Pure.Bulk{data}, rest}:
      Con{Bulk{data}, val.from.list(rest)}
    case Con{Pure.Arr{items}, rest}:
      Con{Arr{val.from.list(items)}, val.from.list(rest)}
    case Con{Pure.Null{}, rest}:
      Con{Null{}, val.from.list(rest)}
    case Con{Pure.Boolean{value}, rest}:
      Con{Boolean{value}, val.from.list(rest)}
    case Con{Pure.Double{text}, rest}:
      Con{Double{text}, val.from.list(rest)}
    case Con{Pure.BigNum{text}, rest}:
      Con{BigNum{text}, val.from.list(rest)}
    case Con{Pure.BulkError{text}, rest}:
      Con{BulkError{text}, val.from.list(rest)}
    case Con{Pure.Verbatim{format, text}, rest}:
      Con{Verbatim{format, text}, val.from.list(rest)}
    case Con{Pure.Dict{items}, rest}:
      Con{Dict{val.from.list(items)}, val.from.list(rest)}
    case Con{Pure.Set{items}, rest}:
      Con{Set{val.from.list(items)}, val.from.list(rest)}
    case Con{Pure.Attr{items}, rest}:
      Con{Attr{val.from.list(items)}, val.from.list(rest)}
    case Con{Pure.Push{items}, rest}:
      Con{Push{val.from.list(items)}, val.from.list(rest)}


def val.from(v: Pure.Val) -> Val:
  match v:
    case Pure.Simple{text}:
      Simple{text}
    case Pure.Error{text}:
      Error{text}
    case Pure.Int{hi, lo}:
      Int{hi, lo}
    case Pure.Bulk{data}:
      Bulk{data}
    case Pure.Arr{items}:
      Arr{val.from.list(items)}
    case Pure.Null{}:
      Null{}
    case Pure.Boolean{value}:
      Boolean{value}
    case Pure.Double{text}:
      Double{text}
    case Pure.BigNum{text}:
      BigNum{text}
    case Pure.BulkError{text}:
      BulkError{text}
    case Pure.Verbatim{format, text}:
      Verbatim{format, text}
    case Pure.Dict{items}:
      Dict{val.from.list(items)}
    case Pure.Set{items}:
      Set{val.from.list(items)}
    case Pure.Attr{items}:
      Attr{val.from.list(items)}
    case Pure.Push{items}:
      Push{val.from.list(items)}

def frame.from(v: Pure.Frame) -> Frame:
  match v:
    case Pure.Frame{kind, left, xs}:
      Frame{kind, left, val.from.list(xs)}

def frame.from.list(r: List<&1, Pure.Frame>) -> List<&1, Frame>:
  List.map(~Pure.Frame, ~Frame, ~(x => frame.from(x)), r)

def num.from(v: Pure.Num) -> Num:
  match v:
    case Pure.Num{neg, hi, lo, ok}:
      Num{neg, hi, lo, ok}

def num.from.bytes(r: Bytes.Bytes & Pure.Num) -> Bytes.Bytes & Num:
  (x0, x1) = r
  (x0, num.from(x1))

def val.from.maybe(r: Maybe<&1, Pure.Val>) -> Maybe<&1, Val>:
  Maybe.map(&1, Pure.Val, Val, x => val.from(x), r)

def st.from(v: Pure.St) -> St:
  match v:
    case Pure.SHead{i, stack}:
      SHead{i, frame.from.list(stack)}
    case Pure.SDone{v, i, stack}:
      SDone{val.from(v), i, frame.from.list(stack)}
    case Pure.SOk{v, i}:
      SOk{val.from(v), i}
    case Pure.SLine{t, i, scan, stack}:
      SLine{t, i, scan, frame.from.list(stack)}
    case Pure.SBlob{kind, n, next, stack}:
      SBlob{kind, n, next, frame.from.list(stack)}
    case Pure.SWait{state}:
      SWait{st.from(state)}
    case Pure.SMore{}:
      SMore{}
    case Pure.SBad{}:
      SBad{}

def st.from.bytes(r: Bytes.Bytes & Pure.St) -> Bytes.Bytes & St:
  (x0, x1) = r
  (x0, st.from(x1))

def val.to.maybe(r: Maybe<&1, Val>) -> Maybe<&1, Pure.Val>:
  Maybe.map(&1, Val, Pure.Val, x => val.to(x), r)

def num.to(v: Num) -> Pure.Num:
  match v:
    case Num{neg, hi, lo, ok}:
      Pure.Num{neg, hi, lo, ok}

def num.to.bytes(r: Bytes.Bytes & Num) -> Bytes.Bytes & Pure.Num:
  (x0, x1) = r
  (x0, num.to(x1))

def st.to(v: St) -> Pure.St:
  match v:
    case SHead{i, stack}:
      Pure.SHead{i, frame.to.list(stack)}
    case SDone{v, i, stack}:
      Pure.SDone{val.to(v), i, frame.to.list(stack)}
    case SOk{v, i}:
      Pure.SOk{val.to(v), i}
    case SLine{t, i, scan, stack}:
      Pure.SLine{t, i, scan, frame.to.list(stack)}
    case SBlob{kind, n, next, stack}:
      Pure.SBlob{kind, n, next, frame.to.list(stack)}
    case SWait{state}:
      Pure.SWait{st.to(state)}
    case SMore{}:
      Pure.SMore{}
    case SBad{}:
      Pure.SBad{}

def st.to.bytes(r: Bytes.Bytes & St) -> Bytes.Bytes & Pure.St:
  (x0, x1) = r
  (x0, st.to(x1))

def step.from(v: Pure.Step) -> Step:
  match v:
    case Pure.Reply{v, next}:
      Reply{val.from(v), next}
    case Pure.More{}:
      More{}
    case Pure.Bad{}:
      Bad{}

def step.from.bytes(r: Bytes.Bytes & Pure.Step) -> Bytes.Bytes & Step:
  (x0, x1) = r
  (x0, step.from(x1))

def step.to(v: Step) -> Pure.Step:
  match v:
    case Reply{v, next}:
      Pure.Reply{val.to(v), next}
    case More{}:
      Pure.More{}
    case Bad{}:
      Pure.Bad{}

def step.to.bytes(r: Bytes.Bytes & Step) -> Bytes.Bytes & Pure.Step:
  (x0, x1) = r
  (x0, step.to(x1))

def reader.from(v: Pure.Reader) -> Reader:
  Reader{v}

def next.from(v: Pure.Next) -> Next:
  match v:
    case Pure.Got{v}:
      Got{val.from(v)}
    case Pure.Want{}:
      Want{}
    case Pure.Broken{}:
      Broken{}

def next.from.reader(r: Pure.Reader & Pure.Next) -> Reader & Next:
  (x0, x1) = r
  (reader.from(x0), next.from(x1))

def pending.from.reader(r: Pure.Reader & U32) -> Reader & U32:
  (x0, x1) = r
  (reader.from(x0), x1)

def e.to(v: E) -> Pure.E:
  match v:
    case E{o, ok, n}:
      Pure.E{o, ok, n}

def reader.to(v: Reader) -> Pure.Reader:
  match v:
    case Reader{state}:
      state

def next.to(v: Next) -> Pure.Next:
  match v:
    case Got{v}:
      Pure.Got{val.to(v)}
    case Want{}:
      Pure.Want{}
    case Broken{}:
      Pure.Broken{}

def e.from(v: Pure.E) -> E:
  match v:
    case Pure.E{o, ok, n}:
      E{o, ok, n}

def kind.tag(+kind: U32) -> String:
  Pure.kind.tag(kind)

def kind.val(+kind: U32, xs: List<&1, Val>) -> Val:
  val.from(Pure.kind.val(kind, val.to.list(xs)))

def i64.neg(+hi: U32, +lo: U32) -> U32 & U32:
  Pure.i64.neg(hi, lo)

def u64.div10(+hi: U32, +lo: U32) -> U32 & U32 & U32:
  Pure.u64.div10(hi, lo)

def digit.put(z: Bool, +r: U32, acc: String) -> String:
  Pure.digit.put(z, r, acc)

def u64.show.go(f: Nat, q: U32 & U32 & U32, acc: String, +z: Bool) -> String:
  Pure.u64.show.go(f, q, acc, z)

def u64.show(+hi: U32, +lo: U32) -> String:
  Pure.u64.show(hi, lo)

def i64.show.of(r: U32 & U32, neg: Bool) -> String:
  Pure.i64.show.of(r, neg)

def i64.show(+hi: U32, +lo: U32) -> String:
  Pure.i64.show(hi, lo)

def fresh() -> E:
  e.from(Pure.fresh())

def text(+s: String) -> Bytes.Bytes:
  Pure.text(s)

def none(m: Maybe<&2, U32>) -> Bool:
  Pure.none(m)

def clean.lf(+cr: Bool, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Bool:
  Pure.clean.lf(cr, r)

def clean.cr(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Bool:
  Pure.clean.cr(r)

def clean(t: Bytes.Bytes) -> Bytes.Bytes & Bool:
  Pure.clean(t)

def put(st: E, +head: String, body: Bytes.Bytes, +good: Bool) -> E:
  e.from(Pure.put(e.to(st), head, body, good))

def line(st: E, +tag: String, r: Bytes.Bytes & Bool) -> E:
  e.from(Pure.line(e.to(st), tag, r))

def blob(st: E, +tag: String, b: Bytes.Bytes) -> E:
  e.from(Pure.blob(e.to(st), tag, b))

def verbatim.of(st: E, +tl: U32, r: Bytes.Bytes & U32, t: Bytes.Bytes) -> E:
  e.from(Pure.verbatim.of(e.to(st), tl, r, t))

def verbatim(st: E, f: Bytes.Bytes, t: Bytes.Bytes) -> E:
  e.from(Pure.verbatim(e.to(st), f, t))

def agg.count(+kind: U32, +n: U32) -> U32:
  Pure.agg.count(kind, n)

def agg.ok(+kind: U32, +n: U32) -> Bool:
  Pure.agg.ok(kind, n)

def agg(st: E, +kind: U32, sub: E) -> E:
  e.from(Pure.agg(e.to(st), kind, e.to(sub)))

def boolean(v: Bool) -> String:
  Pure.boolean(v)

def enc(xs: List<&1, Val>, st: E) -> E:
  e.from(Pure.enc(val.to.list(xs), e.to(st)))

def encode.done(st: E) -> Maybe<&1, Bytes.Bytes>:
  Pure.encode.done(e.to(st))

def encode(v: Val) -> Maybe<&1, Bytes.Bytes>:
  Pure.encode(val.to(v))

def bulks(xs: List<&1, Bytes.Bytes>) -> List<&1, Val>:
  val.from.list(Pure.bulks(xs))

def encode.command.done(st: E) -> Bytes.Bytes:
  Pure.encode.command.done(e.to(st))

def encode.command(args: List<&1, Bytes.Bytes>) -> Bytes.Bytes:
  Pure.encode.command(args)

def args(xs: List<&2, String>) -> List<&1, Bytes.Bytes>:
  Pure.args(xs)

def num.go(n: Nat, r: Array<U32> & U32, +i: U32, +hi: U32, +lo: U32, +ok: Bool) -> Array<U32> & U32 & U32 & Bool:
  Pure.num.go(n, r, i, hi, lo, ok)

def num.fin(+neg: Bool, +len: U32, r: Array<U32> & U32 & U32 & Bool) -> Bytes.Bytes & Num:
  num.from.bytes(Pure.num.fin(neg, len, r))

def num.digits(+neg: Bool, a: Array<U32>, +len: U32, +s: U32, +e: U32) -> Bytes.Bytes & Num:
  num.from.bytes(Pure.num.digits(neg, a, len, s, e))

def num.sign(+len: U32, +s: U32, +e: U32, r: Array<U32> & U32) -> Bytes.Bytes & Num:
  num.from.bytes(Pure.num.sign(len, s, e, r))

def num(b: Bytes.Bytes, +s: U32, +e: U32) -> Bytes.Bytes & Num:
  num.from.bytes(Pure.num(b, s, e))

def int.mk(r: U32 & U32) -> Val:
  val.from(Pure.int.mk(r))

def int.val(good: Bool, +neg: Bool, +hi: U32, +lo: U32) -> Maybe<&1, Val>:
  val.from.maybe(Pure.int.val(good, neg, hi, lo))

def int.of(n: Num) -> Maybe<&1, Val>:
  val.from.maybe(Pure.int.of(num.to(n)))

def len.of(n: Num) -> U32:
  Pure.len.of(num.to(n))

def byte.of(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & U32:
  Pure.byte.of(r)

def byte(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & U32:
  Pure.byte(b, i)

def known(+t: U32) -> Bool:
  Pure.known(t)

def null.st(ok: Bool, +next: U32, stack: List<&1, Frame>) -> St:
  st.from(Pure.null.st(ok, next, frame.to.list(stack)))

def line.val(+k: U32, t: Bytes.Bytes) -> Val:
  val.from(Pure.line.val(k, t))

def line.st(+k: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.line.st(k, next, frame.to.list(stack), r))

def int.done(m: Maybe<&1, Val>, +next: U32, stack: List<&1, Frame>) -> St:
  st.from(Pure.int.done(val.to.maybe(m), next, frame.to.list(stack)))

def int.st(+next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Num) -> Bytes.Bytes & St:
  st.from.bytes(Pure.int.st(next, frame.to.list(stack), num.to.bytes(r)))

def boolean.done(ok: Bool, +v: Bool, +next: U32, stack: List<&1, Frame>) -> St:
  st.from(Pure.boolean.done(ok, v, next, frame.to.list(stack)))

def boolean.st(+next: U32, stack: List<&1, Frame>, +one: Bool, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  st.from.bytes(Pure.boolean.st(next, frame.to.list(stack), one, r))

def blob.mk(+kind: U32, d: Bytes.Bytes) -> Val:
  val.from(Pure.blob.mk(kind, d))

def blob.done(+kind: U32, +after: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.blob.done(kind, after, frame.to.list(stack), r))

def verb.text(f: Bytes.Bytes, +after: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.verb.text(f, after, frame.to.list(stack), r))

def verb.fmt(+n: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.verb.fmt(n, next, frame.to.list(stack), r))

def verb.ok(ok: Bool, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.verb.ok(ok, n, next, frame.to.list(stack), b))

def verb.colon(+n: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  st.from.bytes(Pure.verb.colon(n, next, frame.to.list(stack), r))

def verb.len(ok: Bool, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.verb.len(ok, n, next, frame.to.list(stack), b))

def blob.val(+kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.blob.val(kind, n, next, frame.to.list(stack), b))

def blob.crlf(+kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Bool) -> Bytes.Bytes & St:
  st.from.bytes(Pure.blob.crlf(kind, n, next, frame.to.list(stack), r))

def crlf.at(b: Bytes.Bytes, +j: U32) -> Bytes.Bytes & Bool:
  Pure.crlf.at(b, j)

def blob.fit(ok: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.blob.fit(ok, kind, n, next, frame.to.list(stack), b))

def blob.room(+kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  st.from.bytes(Pure.blob.room(kind, n, next, frame.to.list(stack), r))

def blob.bad(bad: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.blob.bad(bad, kind, n, next, frame.to.list(stack), b))

def blob.nil(nil: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.blob.nil(nil, kind, n, next, frame.to.list(stack), b))

def blob.st(+kind: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Num) -> Bytes.Bytes & St:
  st.from.bytes(Pure.blob.st(kind, next, frame.to.list(stack), num.to.bytes(r)))

def agg.open(empty: Bool, +kind: U32, +left: U32, +next: U32, stack: List<&1, Frame>) -> St:
  st.from(Pure.agg.open(empty, kind, left, next, frame.to.list(stack)))

def agg.left(+kind: U32, +n: U32) -> U32:
  Pure.agg.left(kind, n)

def agg.bad(bad: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>) -> St:
  st.from(Pure.agg.bad(bad, kind, n, next, frame.to.list(stack)))

def agg.nil(nil: Bool, +kind: U32, +n: U32, +next: U32, stack: List<&1, Frame>) -> St:
  st.from(Pure.agg.nil(nil, kind, n, next, frame.to.list(stack)))

def agg.st(+kind: U32, +next: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Num) -> Bytes.Bytes & St:
  st.from.bytes(Pure.agg.st(kind, next, frame.to.list(stack), num.to.bytes(r)))

def item(+t: U32, +s: U32, +e: U32, b: Bytes.Bytes, stack: List<&1, Frame>) -> Bytes.Bytes & St:
  st.from.bytes(Pure.item(t, s, e, b, frame.to.list(stack)))

def head.eol(+t: U32, +i: U32, stack: List<&1, Frame>, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & St:
  st.from.bytes(Pure.head.eol(t, i, frame.to.list(stack), r))

def head.end(end: Bool) -> St:
  st.from(Pure.head.end(end))

def head.known(ok: Bool, +t: U32, +i: U32, stack: List<&1, Frame>, b: Bytes.Bytes) -> Bytes.Bytes & St:
  st.from.bytes(Pure.head.known(ok, t, i, frame.to.list(stack), b))

def head(+i: U32, stack: List<&1, Frame>, r: Bytes.Bytes & U32) -> Bytes.Bytes & St:
  st.from.bytes(Pure.head(i, frame.to.list(stack), r))

def done.last(last: Bool, +kind: U32, +left: U32, xs: List<&1, Val>, +i: U32, rest: List<&1, Frame>) -> St:
  st.from(Pure.done.last(last, kind, left, val.to.list(xs), i, frame.to.list(rest)))

def done(stack: List<&1, Frame>, v: Val, +i: U32) -> St:
  st.from(Pure.done(frame.to.list(stack), val.to(v), i))

def run(fuel: Nat, r: Bytes.Bytes & St) -> Bytes.Bytes & Step:
  step.from.bytes(Pure.run(fuel, st.to.bytes(r)))

def decode(b: Bytes.Bytes, +i: U32) -> Bytes.Bytes & Step:
  step.from.bytes(Pure.decode(b, i))

def reader() -> Reader:
  reader.from(Pure.reader())

def feed.at(zero: Bool, buf: Bytes.Bytes, +pos: U32, state: St, chunk: Bytes.Bytes) -> Reader:
  reader.from(Pure.feed.at(zero, buf, pos, st.to(state), chunk))

def feed(r: Reader, chunk: Bytes.Bytes) -> Reader:
  reader.from(Pure.feed(reader.to(r), chunk))

def next.of(+pos: U32, r: Bytes.Bytes & St) -> Reader & Next:
  next.from.reader(Pure.next.of(pos, st.to.bytes(r)))

def next(r: Reader) -> Reader & Next:
  next.from.reader(Pure.next(reader.to(r)))

def pending.of(+pos: U32, state: St, r: Bytes.Bytes & U32) -> Reader & U32:
  pending.from.reader(Pure.pending.of(pos, st.to(state), r))

def pending(r: Reader) -> Reader & U32:
  pending.from.reader(Pure.pending(reader.to(r)))


# ---- connections

# host is a name or a numeric address; TLS checks the certificate against it. Empty user
# and pass send no AUTH (a pass alone authenticates as "default"); db 0 sends no SELECT.
# ms bounds each connect and read (0: none).
type Config is Data:
  Config{host: String, port: U32, tls: Bool, user: String, pass: String, db: U32, ms: U32}

def config(+host: String, +port: U32) -> Config:
  Config{host, port, False{}, "", "", 0, 10000}

# A failed call closes its connection. Rejected carries the server's error reply to the handshake.
type Failure is Type:
  IoFail{code: U32, why: String}
  Closed{}
  Malformed{}
  Rejected{reply: Val}

# key names the pool bucket: TLS, user, host, port, and db.
type Conn is Type:
  Conn{tls: Bool, sock: Socket, rd: Reader, key: String, ms: U32}

def io.close(tls: Bool, s: Socket) -> IO(Unit):
  match tls:
    case True{}:
      Wire.tls.close(s)
    case False{}:
      Socket.close(s)

def io.send(tls: Bool, s: Socket, +len: U32, buf: Array<U32>) -> IO(Socket & Result<&1, &1, U32 & String, Unit>):
  match tls:
    case True{}:
      Wire.tls.send.words(s, len, buf)
    case False{}:
      Wire.send.words(s, len, buf)

def io.recv(tls: Bool, s: Socket, +ms: U32) -> IO(Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match tls:
    case True{}:
      Wire.tls.recv.words(s, 65536, ms)
    case False{}:
      Wire.recv.words(s, 65536, ms)

def close(c: Conn) -> IO(Unit):
  Conn{tls, sock, rd, key, ms} = c
  io.close(tls, sock)

def send.after(+tls: Bool, rd: Reader, +key: String, +ms: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Failure, Conn>):
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      do IO<Result<&1, &1, Failure, Conn>>:
        io.close(tls, s)
        return Fail{IoFail{code, why}}
    case Done{u}:
      IO.pure(Result<&1, &1, Failure, Conn>, Done{Conn{tls, s, rd, key, ms}})

def send(c: Conn, data: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn>):
  Conn{+tls, sock, rd, +key, +ms} = c
  Bytes.Bytes{+len, buf} = data
  do IO<Result<&1, &1, Failure, Conn>>:
    m : Socket & Result<&1, &1, U32 & String, Unit> <- io.send(tls, sock, len, buf)
    send.after(tls, rd, key, ms, m)

# RNext holds the reader after its last decode attempt; RFail a socket to close.
type Rd is Type:
  RNext{tls: Bool, sock: Socket, key: String, ms: U32, r: Reader & Next}
  RFail{tls: Bool, sock: Socket, why: Failure}

def got.len(zero: Bool, +tls: Bool, +key: String, +ms: U32, rd: Reader, s: Socket, +len: U32, words: Array<U32>) -> Rd:
  match zero:
    case True{}:
      RFail{tls, s, Closed{}}
    case False{}:
      RNext{tls, s, key, ms, next(feed(rd, Bytes.Bytes{len, words}))}

def got(+tls: Bool, +key: String, +ms: U32, rd: Reader, m: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> Rd:
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      RFail{tls, s, IoFail{code, why}}
    case Done{(+len, words)}:
      got.len(U32.is_zero(len), tls, key, ms, rd, s, len, words)

def read.fail(tls: Bool, sock: Socket, why: Failure) -> IO(Result<&1, &1, Failure, Conn & Val>):
  do IO<Result<&1, &1, Failure, Conn & Val>>:
    io.close(tls, sock)
    return Fail{why}

# One recv per step. 2^24 reads of up to 64 KiB pass Redis's 512 MiB bulk limit.
def read.loop(fuel: Nat, st: Rd) -> IO(Result<&1, &1, Failure, Conn & Val>):
  match fuel:
    case 0n:
      match st:
        case RNext{tls, sock, key, ms, r}:
          read.fail(tls, sock, Malformed{})
        case RFail{tls, sock, why}:
          read.fail(tls, sock, why)
    case 1n+f:
      match st:
        case RFail{tls, sock, why}:
          read.fail(tls, sock, why)
        case RNext{+tls, sock, +key, +ms, r}:
          (rd, nx) = r
          match nx:
            case Got{v}:
              IO.pure(Result<&1, &1, Failure, Conn & Val>, Done{(Conn{tls, sock, rd, key, ms}, v)})
            case Broken{}:
              read.fail(tls, sock, Malformed{})
            case Want{}:
              do IO<Result<&1, &1, Failure, Conn & Val>>:
                m : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- io.recv(tls, sock, ms)
                read.loop(f, got(tls, key, ms, rd, m))

# The next reply. Bytes already read are decoded before the socket is asked for more.
def read(c: Conn) -> IO(Result<&1, &1, Failure, Conn & Val>):
  Conn{tls, sock, rd, key, ms} = c
  read.loop(Nat.mul(65536n, 256n), RNext{tls, sock, key, ms, next(rd)})

def read.push(xs: List<&1, Val>, r: Result<&1, &1, Failure, Conn & Val>) -> Result<&1, &1, Failure, Conn & List<&1, Val>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{(c, v)}:
      Done{(c, Con{v, xs})}

# n more replies onto the reversed list in st.
def read.n(n: Nat, st: Result<&1, &1, Failure, Conn & List<&1, Val>>) -> IO(Result<&1, &1, Failure, Conn & List<&1, Val>>):
  match n:
    case 0n:
      match st:
        case Fail{e}:
          IO.pure(Result<&1, &1, Failure, Conn & List<&1, Val>>, Fail{e})
        case Done{(c, xs)}:
          IO.pure(Result<&1, &1, Failure, Conn & List<&1, Val>>, Done{(c, List.reverse(&1, Val, xs))})
    case 1n+p:
      match st:
        case Fail{e}:
          IO.pure(Result<&1, &1, Failure, Conn & List<&1, Val>>, Fail{e})
        case Done{(c, xs)}:
          do IO<Result<&1, &1, Failure, Conn & List<&1, Val>>>:
            r : Result<&1, &1, Failure, Conn & Val> <- read(c)
            read.n(p, read.push(xs, r))

def commands(cmds: List<&1, List<&1, Bytes.Bytes>>, o: Bytes.Bytes, +n: Nat) -> Bytes.Bytes & Nat:
  match cmds:
    case Nil{}:
      (o, n)
    case Con{h, t}:
      commands(t, Bytes.append(o, encode.command(h)), (1n + n : Nat))

def pipeline.sent(+n: Nat, r: Result<&1, &1, Failure, Conn>) -> IO(Result<&1, &1, Failure, Conn & List<&1, Val>>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn & List<&1, Val>>, Fail{e})
    case Done{c}:
      read.n(n, Done{(c, Nil{})})

def pipeline.of(c: Conn, r: Bytes.Bytes & Nat) -> IO(Result<&1, &1, Failure, Conn & List<&1, Val>>):
  (data, +n) = r
  do IO<Result<&1, &1, Failure, Conn & List<&1, Val>>>:
    s : Result<&1, &1, Failure, Conn> <- send(c, data)
    pipeline.sent(n, s)

# Sends every command in one write, then reads one reply per command, in order.
# Error replies come back as Error or BulkError values, not as failures.
def pipeline(c: Conn, cmds: List<&1, List<&1, Bytes.Bytes>>) -> IO(Result<&1, &1, Failure, Conn & List<&1, Val>>):
  pipeline.of(c, commands(cmds, Bytes.new(0), 0n))

def command.sent(r: Result<&1, &1, Failure, Conn>) -> IO(Result<&1, &1, Failure, Conn & Val>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn & Val>, Fail{e})
    case Done{c}:
      read(c)

# One command and its reply, for example command(c, args(["SET", "k", "v"])).
def command(c: Conn, argv: List<&1, Bytes.Bytes>) -> IO(Result<&1, &1, Failure, Conn & Val>):
  do IO<Result<&1, &1, Failure, Conn & Val>>:
    r : Result<&1, &1, Failure, Conn> <- send(c, encode.command(argv))
    command.sent(r)

def get(c: Conn, key: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn & Val>):
  command(c, [text("GET"), key])

def set(c: Conn, key: Bytes.Bytes, value: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn & Val>):
  command(c, [text("SET"), key, value])

def incr(c: Conn, key: Bytes.Bytes) -> IO(Result<&1, &1, Failure, Conn & Val>):
  command(c, [text("INCR"), key])

def first.err(xs: List<&1, Val>) -> Maybe<&1, Val>:
  match xs:
    case Nil{}:
      None{}
    case Con{Error{t}, rest}:
      Some{Error{t}}
    case Con{BulkError{t}, rest}:
      Some{BulkError{t}}
    case Con{v, rest}:
      first.err(rest)

def hello.check(c: Conn, e: Maybe<&1, Val>) -> IO(Result<&1, &1, Failure, Conn>):
  match e:
    case None{}:
      IO.pure(Result<&1, &1, Failure, Conn>, Done{c})
    case Some{v}:
      do IO<Result<&1, &1, Failure, Conn>>:
        close(c)
        return Fail{Rejected{v}}

def hello.got(r: Result<&1, &1, Failure, Conn & List<&1, Val>>) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{e})
    case Done{(c, xs)}:
      hello.check(c, first.err(xs))

def hello.auth(+user: String, +pass: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.eq(pass, ""), Nil{}, ["AUTH", Bool.pick(String, String.eq(user, ""), "default", user), pass])

def hello.select(+db: U32) -> List<&1, List<&1, Bytes.Bytes>>:
  Bool.pick(List<&1, List<&1, Bytes.Bytes>>, U32.is_zero(db), Nil{}, [args(["SELECT", U32.show(db)])])

# HELLO 3 (with AUTH), then SELECT, in one pipeline.
def hello(c: Conn, +user: String, +pass: String, +db: U32) -> IO(Result<&1, &1, Failure, Conn>):
  do IO<Result<&1, &1, Failure, Conn>>:
    r : Result<&1, &1, Failure, Conn & List<&1, Val>> <- pipeline(c, Con{args(List.append(&2, String, ["HELLO", "3"], hello.auth(user, pass))), hello.select(db)})
    hello.got(r)

def key(cfg: Config) -> String:
  Config{+host, +port, +tls, +user, pass, +db, ms} = cfg
  Bool.pick(String, tls, "rediss://", "redis://") ++ user ++ "@" ++ host ++ ":" ++ U32.show(port) ++ "/" ++ U32.show(db)

def tls.done(+key: String, +ms: U32, +user: String, +pass: String, +db: U32, m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Result<&1, &1, Failure, Conn>):
  (s, r) = m
  match r:
    case Fail{(code, why)}:
      do IO<Result<&1, &1, Failure, Conn>>:
        Wire.tls.close(s)
        return Fail{IoFail{code, why}}
    case Done{u}:
      hello(Conn{True{}, s, reader(), key, ms}, user, pass, db)

def dialed(r: Result<&1, &1, U32 & String, Socket>, tls: Bool, +k: String, +host: String, +user: String, +pass: String, +db: U32, +ms: U32) -> IO(Result<&1, &1, Failure, Conn>):
  match r:
    case Fail{(code, why)}:
      IO.pure(Result<&1, &1, Failure, Conn>, Fail{IoFail{code, why}})
    case Done{s}:
      match tls:
        case True{}:
          do IO<Result<&1, &1, Failure, Conn>>:
            m : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, host, ms)
            tls.done(k, ms, user, pass, db, m)
        case False{}:
          hello(Conn{False{}, s, reader(), k, ms}, user, pass, db)

def dial.after(r: Result<&1, &1, U32 & String, Socket>, +ip: String, +port: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Socket>):
  match r:
    case Done{s}:
      IO.pure(Result<&1, &1, U32 & String, Socket>, Done{s})
    case Fail{e}:
      Wire.connect(ip, port, ms)

def dial.more(prev: IO(Result<&1, &1, U32 & String, Socket>), +ip: String, +port: U32, +ms: U32) -> IO(Result<&1, &1, U32 & String, Socket>):
  do IO<Result<&1, &1, U32 & String, Socket>>:
    r : Result<&1, &1, U32 & String, Socket> <- prev
    dial.after(r, ip, port, ms)

# Each address in turn, until one connects.
def dial(ips: List<&2, String>, +port: U32, +ms: U32, acc: IO(Result<&1, &1, U32 & String, Socket>)) -> IO(Result<&1, &1, U32 & String, Socket>):
  match ips:
    case Nil{}:
      acc
    case Con{ip, t}:
      dial(t, port, ms, dial.more(acc, ip, port, ms))

def connect.to(+k: String, cfg: Config) -> IO(Result<&1, &1, Failure, Conn>):
  Config{+host, +port, +tls, +user, +pass, +db, +ms} = cfg
  do IO<Result<&1, &1, Failure, Conn>>:
    ips : List<&2, String> <- Dns.resolve.all(host)
    r : Result<&1, &1, U32 & String, Socket> <- dial(ips, port, ms, IO.pure(Result<&1, &1, U32 & String, Socket>, Fail{(0, "no address for " ++ host)}))
    dialed(r, tls, k, host, user, pass, db, ms)

# TCP (and TLS, which checks the certificate and host name), then the handshake.
def connect(+cfg: Config) -> IO(Result<&1, &1, Failure, Conn>):
  connect.to(key(cfg), cfg)

# ---- pool

# Idle connections per key, up to cap per key.
type Pool is Type:
  Pool{cap: U32, idle: Map<&1, List<&1, Conn>>}

def pool.new.with(+cap: U32) -> Pool:
  Pool{cap, Map.new(&1, List<&1, Conn>)}

def pool.new() -> Pool:
  pool.new.with(8)

def pool.take(+cap: U32, +k: String, r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> Pool & Maybe<&1, Conn>:
  (m, got) = r
  match got:
    case None{}:
      (Pool{cap, m}, None{})
    case Some{xs}:
      match xs:
        case Nil{}:
          (Pool{cap, m}, None{})
        case Con{c, t}:
          (Pool{cap, Map.set(&1, List<&1, Conn>, m, k, t)}, Some{c})

def pool.opened(p: Pool, r: Result<&1, &1, Failure, Conn>) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  IO.pure(Pool & Result<&1, &1, Failure, Conn>, (p, r))

def pool.got(cfg: Config, r: Pool & Maybe<&1, Conn>) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  (p, m) = r
  match m:
    case Some{c}:
      IO.pure(Pool & Result<&1, &1, Failure, Conn>, (p, Done{c}))
    case None{}:
      do IO<Pool & Result<&1, &1, Failure, Conn>>:
        c : Result<&1, &1, Failure, Conn> <- connect(cfg)
        pool.opened(p, c)

# The idle connection given back last, or a new one.
# ponytail: an idle connection the server has since closed fails on its first command; add a PING check if that bites.
def pool.get(p: Pool, +cfg: Config) -> IO(Pool & Result<&1, &1, Failure, Conn>):
  Pool{+cap, idle} = p
  +k = key(cfg)
  pool.got(cfg, pool.take(cap, k, Map.pop(&1, List<&1, Conn>, idle, k)))

# The first n connections; the rest are closed.
def conns.cut(xs: List<&1, Conn>, n: Nat) -> IO(List<&1, Conn>):
  match xs:
    case Nil{}:
      IO.pure(List<&1, Conn>, Nil{})
    case Con{c, t}:
      match n:
        case 0n:
          do IO<List<&1, Conn>>:
            close(c)
            conns.cut(t, 0n)
        case 1n+k:
          do IO<List<&1, Conn>>:
            r : List<&1, Conn> <- conns.cut(t, k)
            return c <> r

def pool.keep(+cap: U32, +k: String, c: Conn, r: Map<&1, List<&1, Conn>> & Maybe<&1, List<&1, Conn>>) -> IO(Pool):
  (m, old) = r
  do IO<Pool>:
    xs : List<&1, Conn> <- conns.cut(c <> Maybe.default(&1, List<&1, Conn>, old, Nil{}), U32.to_nat(cap))
    return Pool{cap, Map.set(&1, List<&1, Conn>, m, k, xs)}

def pool.give(p: Pool, c: Conn) -> IO(Pool):
  Pool{+cap, idle} = p
  Conn{tls, sock, rd, +k, ms} = c
  pool.keep(cap, k, Conn{tls, sock, rd, k, ms}, Map.pop(&1, List<&1, Conn>, idle, k))

def pool.clean(clean: Bool, p: Pool, c: Conn) -> IO(Pool):
  match clean:
    case True{}:
      pool.give(p, c)
    case False{}:
      do IO<Pool>:
        close(c)
        return p

def pool.left(p: Pool, +tls: Bool, sock: Socket, +key: String, +ms: U32, r: Reader & U32) -> IO(Pool):
  (rd, +n) = r
  pool.clean(U32.is_zero(n), p, Conn{tls, sock, rd, key, ms})

# Gives c back for reuse. A connection with unread reply bytes is out of step, so it is closed.
def pool.put(p: Pool, c: Conn) -> IO(Pool):
  Conn{+tls, sock, rd, +key, +ms} = c
  pool.left(p, tls, sock, key, ms, pending(rd))

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
