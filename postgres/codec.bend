# Postgres frontend/backend protocol 3.0 messages over Bytes, and an incremental reader of backend messages.
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

# ---- messages

# A StartupMessage parameter, such as ("user", name) or ("database", db).
type Param is Type:
  Param{name: Bytes.Bytes, value: Bytes.Bytes}

# Frontend messages. Describe and CloseMsg take kind 83 ('S', statement) or 80 ('P', portal).
# Bind params hold one Maybe per parameter, None for SQL NULL; empty formats mean text.
type Front is Type:
  Startup{params: List<&1, Param>}
  SSLRequest{}
  Password{text: Bytes.Bytes}
  SASLInitial{mech: Bytes.Bytes, data: Bytes.Bytes}
  SASLResponse{data: Bytes.Bytes}
  Parse{name: Bytes.Bytes, query: Bytes.Bytes, oids: List<&2, U32>}
  Bind{portal: Bytes.Bytes, stmt: Bytes.Bytes, formats: List<&2, U32>, params: List<&1, Maybe<&1, Bytes.Bytes>>, results: List<&2, U32>}
  Describe{kind: U32, name: Bytes.Bytes}
  Execute{portal: Bytes.Bytes, max: U32}
  Sync{}
  CloseMsg{kind: U32, name: Bytes.Bytes}
  Terminate{}

# A RowDescription column. size and modifier are the raw int16 and int32 words.
type Field is Type:
  Field{name: Bytes.Bytes, table: U32, column: U32, oid: U32, size: U32, modifier: U32, format: U32}

# An ErrorResponse or NoticeResponse field: code is its type byte, such as 67 ('C', SQLSTATE) or 77 ('M', message).
type Notice is Type:
  Notice{code: U32, value: Bytes.Bytes}

# Backend messages. AuthOther holds any other authentication code (MD5 is 5) and its payload.
# ReadyForQuery status is 73 ('I'), 84 ('T') or 69 ('E'). Other holds a well-framed message of any other tag.
type Back is Type:
  AuthOk{}
  AuthCleartext{}
  AuthSASL{mechs: List<&1, Bytes.Bytes>}
  AuthSASLContinue{data: Bytes.Bytes}
  AuthSASLFinal{data: Bytes.Bytes}
  AuthOther{code: U32, data: Bytes.Bytes}
  ParameterStatus{name: Bytes.Bytes, value: Bytes.Bytes}
  BackendKeyData{pid: U32, key: U32}
  ReadyForQuery{status: U32}
  RowDescription{fields: List<&1, Field>}
  DataRow{cols: List<&1, Maybe<&1, Bytes.Bytes>>}
  CommandComplete{tag: Bytes.Bytes}
  ErrorResponse{fields: List<&1, Notice>}
  NoticeResponse{fields: List<&1, Notice>}
  ParseComplete{}
  BindComplete{}
  CloseComplete{}
  NoData{}
  EmptyQuery{}
  PortalSuspended{}
  Other{tag: U32, body: Bytes.Bytes}

# The first field whose code is code.
def notice.get(+code: U32, fs: List<&1, Notice>) -> Maybe<&1, Bytes.Bytes>:
  match fs:
    case Nil{}:
      None{}
    case Con{Notice{+k, v}, t}:
      Bool.pick(Maybe<&1, Bytes.Bytes>, U32.is_eq(k, code), Some{v}, notice.get(code, t))

# ---- encoder

def byte1(+c: U32) -> Bytes.Bytes:
  Bytes.set(Bytes.new(1), 0, c)

def be16(+v: U32) -> Bytes.Bytes:
  Bytes.set.u16be(Bytes.new(2), 0, v)

def be32(+v: U32) -> Bytes.Bytes:
  Bytes.set.u32be(Bytes.new(4), 0, v)

# ponytail: a NUL inside a cstr field ends it early; the message length still frames it, so the server rejects that message only.
def cstr.enc(b: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.append(b, Bytes.new(1))

def frame.of(+tag: U32, r: Bytes.Bytes & U32) -> Bytes.Bytes:
  (body, +n) = r
  Bytes.concat([byte1(tag), be32((n + 4 : U32)), body])

# A tagged message: the tag byte, the int32 length (counting itself), then the body.
def frame(+tag: U32, body: Bytes.Bytes) -> Bytes.Bytes:
  frame.of(tag, Bytes.length(body))

def packet.of(r: Bytes.Bytes & U32) -> Bytes.Bytes:
  (body, +n) = r
  Bytes.append(be32((n + 4 : U32)), body)

# An untagged startup-phase packet.
def packet(body: Bytes.Bytes) -> Bytes.Bytes:
  packet.of(Bytes.length(body))

def n16.con(h: Bytes.Bytes, r: List<&1, Bytes.Bytes> & U32) -> List<&1, Bytes.Bytes> & U32:
  (t, +n) = r
  (Con{h, t}, (n + 1 : U32))

def n16.count(xs: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes> & U32:
  match xs:
    case Nil{}:
      (Nil{}, 0)
    case Con{h, t}:
      n16.con(h, n16.count(t))

def n16.of(r: List<&1, Bytes.Bytes> & U32) -> Bytes.Bytes:
  (xs, +n) = r
  Bytes.concat(Con{be16(n), xs})

# An int16 count, then the pieces.
def n16(xs: List<&1, Bytes.Bytes>) -> Bytes.Bytes:
  n16.of(n16.count(xs))

def be16s(xs: List<&2, U32>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{be16(h), be16s(t)}

def be32s(xs: List<&2, U32>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{be32(h), be32s(t)}

def value.of(r: Bytes.Bytes & U32) -> Bytes.Bytes:
  (b, +n) = r
  Bytes.append(be32(n), b)

# An int32 length then the bytes; -1 and nothing for NULL.
def value(m: Maybe<&1, Bytes.Bytes>) -> Bytes.Bytes:
  match m:
    case None{}:
      be32(4294967295)
    case Some{b}:
      value.of(Bytes.length(b))

def values(xs: List<&1, Maybe<&1, Bytes.Bytes>>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{value(h), values(t)}

def params.enc(xs: List<&1, Param>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      [byte1(0)]
    case Con{Param{n, v}, t}:
      Con{Bytes.append(cstr.enc(n), cstr.enc(v)), params.enc(t)}

def names.enc(xs: List<&1, Bytes.Bytes>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      [byte1(0)]
    case Con{h, t}:
      Con{cstr.enc(h), names.enc(t)}

def notices.enc(xs: List<&1, Notice>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      [byte1(0)]
    case Con{Notice{+k, v}, t}:
      Con{Bytes.append(byte1(k), cstr.enc(v)), notices.enc(t)}

def fields.enc(xs: List<&1, Field>) -> List<&1, Bytes.Bytes>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{Field{n, +tb, +col, +oid, +sz, +md, +fmt}, t}:
      Con{Bytes.concat([cstr.enc(n), be32(tb), be16(col), be32(oid), be16(sz), be32(md), be16(fmt)]), fields.enc(t)}

# The wire bytes of a frontend message.
def encode(m: Front) -> Bytes.Bytes:
  match m:
    case Startup{ps}:
      packet(Bytes.concat(Con{be32(196608), params.enc(ps)}))
    case SSLRequest{}:
      packet(be32(80877103))
    case Password{t}:
      frame(112, cstr.enc(t))
    case SASLInitial{mech, d}:
      frame(112, Bytes.append(cstr.enc(mech), value(Some{d})))
    case SASLResponse{d}:
      frame(112, d)
    case Parse{n, q, oids}:
      frame(80, Bytes.concat([cstr.enc(n), cstr.enc(q), n16(be32s(oids))]))
    case Bind{p, s, fs, ps, rs}:
      frame(66, Bytes.concat([cstr.enc(p), cstr.enc(s), n16(be16s(fs)), n16(values(ps)), n16(be16s(rs))]))
    case Describe{+k, n}:
      frame(68, Bytes.append(byte1(k), cstr.enc(n)))
    case Execute{p, +max}:
      frame(69, Bytes.append(cstr.enc(p), be32(max)))
    case Sync{}:
      frame(83, Bytes.new(0))
    case CloseMsg{+k, n}:
      frame(67, Bytes.append(byte1(k), cstr.enc(n)))
    case Terminate{}:
      frame(88, Bytes.new(0))

def auth.enc(+code: U32, payload: Bytes.Bytes) -> Bytes.Bytes:
  frame(82, Bytes.append(be32(code), payload))

# The wire bytes of a backend message, as a server sends it.
def encode.back(m: Back) -> Bytes.Bytes:
  match m:
    case AuthOk{}:
      auth.enc(0, Bytes.new(0))
    case AuthCleartext{}:
      auth.enc(3, Bytes.new(0))
    case AuthSASL{ms}:
      auth.enc(10, Bytes.concat(names.enc(ms)))
    case AuthSASLContinue{d}:
      auth.enc(11, d)
    case AuthSASLFinal{d}:
      auth.enc(12, d)
    case AuthOther{+code, d}:
      auth.enc(code, d)
    case ParameterStatus{n, v}:
      frame(83, Bytes.append(cstr.enc(n), cstr.enc(v)))
    case BackendKeyData{+pid, +key}:
      frame(75, Bytes.append(be32(pid), be32(key)))
    case ReadyForQuery{+s}:
      frame(90, byte1(s))
    case RowDescription{fs}:
      frame(84, n16(fields.enc(fs)))
    case DataRow{cs}:
      frame(68, n16(values(cs)))
    case CommandComplete{t}:
      frame(67, cstr.enc(t))
    case ErrorResponse{fs}:
      frame(69, Bytes.concat(notices.enc(fs)))
    case NoticeResponse{fs}:
      frame(78, Bytes.concat(notices.enc(fs)))
    case ParseComplete{}:
      frame(49, Bytes.new(0))
    case BindComplete{}:
      frame(50, Bytes.new(0))
    case CloseComplete{}:
      frame(51, Bytes.new(0))
    case NoData{}:
      frame(110, Bytes.new(0))
    case EmptyQuery{}:
      frame(73, Bytes.new(0))
    case PortalSuspended{}:
      frame(115, Bytes.new(0))
    case Other{+tag, b}:
      frame(tag, b)

# ---- body cursor

# The buffer, the next byte i, the end e of the message body (e <= len), and whether every read so far fit.
# A read that does not fit clears ok and leaves i; the message is Bad unless ok holds and i reaches e.
type Cur is Type:
  Cur{b: Bytes.Bytes, i: U32, e: U32, ok: Bool}

def fail(c: Cur) -> Cur:
  Cur{b, +i, +e, ok} = c
  Cur{b, i, e, False{}}

def need(ok: Bool, c: Cur) -> Cur:
  match ok:
    case True{}:
      c
    case False{}:
      fail(c)

def left(c: Cur) -> Cur & Nat:
  Cur{b, +i, +e, +ok} = c
  (Cur{b, i, e, ok}, U32.to_nat((e - i : U32)))

def uint.got(+i: U32, +n: U32, +e: U32, +ok: Bool, r: Bytes.Bytes & Maybe<&2, U32>) -> Cur & U32:
  (b, m) = r
  match m:
    case Some{+v}:
      (Cur{b, (i + n : U32), e, ok}, v)
    case None{}:
      (Cur{b, i, e, False{}}, 0)

def uint.at(fit: Bool, b: Bytes.Bytes, +i: U32, +n: U32, +e: U32, +ok: Bool) -> Cur & U32:
  match fit:
    case True{}:
      uint.got(i, n, e, ok, Bytes.uint(b, i, n, True{}))
    case False{}:
      (Cur{b, i, e, False{}}, 0)

# A big-endian unsigned integer of n bytes (1, 2 or 4).
def uint(c: Cur, +n: U32) -> Cur & U32:
  Cur{b, +i, +e, +ok} = c
  uint.at(Bytes.fits(e, i, n), b, i, n, e, ok)

def take.got(+i: U32, +e: U32, +ok: Bool, r: Bytes.Bytes & Bytes.Bytes) -> Cur & Bytes.Bytes:
  (b, s) = r
  (Cur{b, i, e, ok}, s)

def take.at(fit: Bool, b: Bytes.Bytes, +i: U32, +n: U32, +e: U32, +ok: Bool) -> Cur & Bytes.Bytes:
  match fit:
    case True{}:
      take.got((i + n : U32), e, ok, Bytes.slice(b, i, n))
    case False{}:
      (Cur{b, i, e, False{}}, Bytes.new(0))

# The next n bytes, copied out.
def take(c: Cur, +n: U32) -> Cur & Bytes.Bytes:
  Cur{b, +i, +e, +ok} = c
  take.at(Bytes.fits(e, i, n), b, i, n, e, ok)

def rest(c: Cur) -> Cur & Bytes.Bytes:
  Cur{b, +i, +e, +ok} = c
  take(Cur{b, i, e, ok}, (e - i : U32))

def nul() -> String:
  SCon{Chr{0}, SNil{}}

def cstr.in(inside: Bool, b: Bytes.Bytes, +i: U32, +j: U32, +e: U32, +ok: Bool) -> Cur & Bytes.Bytes:
  match inside:
    case True{}:
      take.got((j + 1 : U32), e, ok, Bytes.slice(b, i, (j - i : U32)))
    case False{}:
      (Cur{b, i, e, False{}}, Bytes.new(0))

def cstr.at(+i: U32, +e: U32, +ok: Bool, r: Bytes.Bytes & Maybe<&2, U32>) -> Cur & Bytes.Bytes:
  (b, m) = r
  match m:
    case Some{+j}:
      cstr.in(U32.is_lt(j, e), b, i, j, e, ok)
    case None{}:
      (Cur{b, i, e, False{}}, Bytes.new(0))

# The bytes before the next NUL inside the body, and the cursor past it.
def cstr(c: Cur) -> Cur & Bytes.Bytes:
  Cur{b, +i, +e, +ok} = c
  cstr.at(i, e, ok, Bytes.find.from(b, nul(), i))

def u16s(c: Cur) -> Cur & U32:
  uint(c, 2)

def u32s(c: Cur) -> Cur & U32:
  uint(c, 4)

# n more items after the one in r, oldest last in acc.
def many(~A: Type, ~item: Cur -> Cur & A, n: Nat, r: Cur & A, acc: List<&1, A>) -> Cur & List<&1, A>:
  match n:
    case 0n:
      (c, v) = r
      (c, List.reverse(&1, A, Con{v, acc}))
    case 1n+p:
      (c, v) = r
      many(~A, ~item, p, item(c), Con{v, acc})

def n16.go(~A: Type, ~item: Cur -> Cur & A, zero: Bool, +k: U32, c: Cur) -> Cur & List<&1, A>:
  match zero:
    case True{}:
      (c, Nil{})
    case False{}:
      many(~A, ~item, U32.to_nat((k - 1 : U32)), item(c), Nil{})

# An int16 count, then that many items.
def n16.dec(~A: Type, ~item: Cur -> Cur & A, r: Cur & U32) -> Cur & List<&1, A>:
  (c, +k) = r
  n16.go(~A, ~item, U32.is_eq(k, 0), k, c)

def list16(~A: Type, ~item: Cur -> Cur & A, c: Cur) -> Cur & List<&1, A>:
  n16.dec(~A, ~item, uint(c, 2))

def dup(xs: List<&1, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Con{h, dup(t)}

def col.some(r: Cur & Bytes.Bytes) -> Cur & Maybe<&1, Bytes.Bytes>:
  (c, b) = r
  (c, Some{b})

def col.of(null: Bool, +n: U32, c: Cur) -> Cur & Maybe<&1, Bytes.Bytes>:
  match null:
    case True{}:
      (c, None{})
    case False{}:
      col.some(take(c, n))

def col.len(r: Cur & U32) -> Cur & Maybe<&1, Bytes.Bytes>:
  (c, +n) = r
  col.of(U32.is_eq(n, 4294967295), n, c)

# An int32 length then the bytes; -1 is NULL, and any other negative length does not fit.
def col(c: Cur) -> Cur & Maybe<&1, Bytes.Bytes>:
  col.len(uint(c, 4))

# A loop up to a terminator: Go holds an item still to push, Stop the end. acc is reversed.
type Loop<-A: Type, -B: Type> is Type:
  Go{c: Cur, x: A, acc: List<&1, B>}
  Stop{c: Cur, acc: List<&1, B>}

# Out of fuel before the terminator is Bad.
def loop.end(-A: Type, -B: Type, s: Loop<A, B>) -> Cur & List<&1, B>:
  match s:
    case Go{c, x, acc}:
      (fail(c), List.reverse(&1, B, acc))
    case Stop{c, acc}:
      (c, List.reverse(&1, B, acc))

def loop.pick(-A: Type, -B: Type, stop: Bool, c: Cur, x: A, acc: List<&1, B>) -> Loop<A, B>:
  match stop:
    case True{}:
      Stop{c, acc}
    case False{}:
      Go{c, x, acc}

def strs.len(c: Cur, acc: List<&1, Bytes.Bytes>, r: Bytes.Bytes & U32) -> Loop<Bytes.Bytes, Bytes.Bytes>:
  (m, +n) = r
  loop.pick(Bytes.Bytes, Bytes.Bytes, U32.is_eq(n, 0), c, m, acc)

def strs.read(acc: List<&1, Bytes.Bytes>, r: Cur & Bytes.Bytes) -> Loop<Bytes.Bytes, Bytes.Bytes>:
  (c, m) = r
  strs.len(c, acc, Bytes.length(m))

# Each string takes a byte, so fuel of the bytes left is enough.
def strs(f: Nat, s: Loop<Bytes.Bytes, Bytes.Bytes>) -> Cur & List<&1, Bytes.Bytes>:
  match f:
    case 0n:
      loop.end(Bytes.Bytes, Bytes.Bytes, s)
    case 1n+p:
      match s:
        case Go{c, m, acc}:
          strs(p, strs.read(Con{m, acc}, cstr(c)))
        case Stop{c, acc}:
          (c, List.reverse(&1, Bytes.Bytes, acc))

def strs.start(r: Cur & Nat) -> Cur & List<&1, Bytes.Bytes>:
  (c, f) = r
  strs(f, strs.read(Nil{}, cstr(c)))

# NUL-terminated strings up to an empty one.
def names.dec(c: Cur) -> Cur & List<&1, Bytes.Bytes>:
  strs.start(left(c))

def pr.len(c: Cur, acc: List<&1, Param>, r: Bytes.Bytes & U32) -> Loop<Bytes.Bytes, Param>:
  (m, +n) = r
  loop.pick(Bytes.Bytes, Param, U32.is_eq(n, 0), c, m, acc)

def pr.read(acc: List<&1, Param>, r: Cur & Bytes.Bytes) -> Loop<Bytes.Bytes, Param>:
  (c, m) = r
  pr.len(c, acc, Bytes.length(m))

def pr.val(name: Bytes.Bytes, acc: List<&1, Param>, r: Cur & Bytes.Bytes) -> Loop<Bytes.Bytes, Param>:
  (c, v) = r
  pr.read(Con{Param{name, v}, acc}, cstr(c))

# Name and value pairs up to an empty name; a value may be empty. Each pair takes two bytes.
def prs(f: Nat, s: Loop<Bytes.Bytes, Param>) -> Cur & List<&1, Param>:
  match f:
    case 0n:
      loop.end(Bytes.Bytes, Param, s)
    case 1n+p:
      match s:
        case Go{c, name, acc}:
          prs(p, pr.val(name, acc, cstr(c)))
        case Stop{c, acc}:
          (c, List.reverse(&1, Param, acc))

def prs.start(r: Cur & Nat) -> Cur & List<&1, Param>:
  (c, f) = r
  prs(f, pr.read(Nil{}, cstr(c)))

def params.dec(c: Cur) -> Cur & List<&1, Param>:
  prs.start(left(c))

def notice.code(acc: List<&1, Notice>, r: Cur & U32) -> Loop<U32, Notice>:
  (c, +k) = r
  loop.pick(U32, Notice, U32.is_eq(k, 0), c, k, acc)

def notice.push(+code: U32, acc: List<&1, Notice>, r: Cur & Bytes.Bytes) -> Loop<U32, Notice>:
  (c, v) = r
  notice.code(Con{Notice{code, v}, acc}, uint(c, 1))

# Fields up to a zero code byte; each takes two bytes, so the bytes left are enough fuel.
def notices(f: Nat, s: Loop<U32, Notice>) -> Cur & List<&1, Notice>:
  match f:
    case 0n:
      loop.end(U32, Notice, s)
    case 1n+p:
      match s:
        case Go{c, +code, acc}:
          notices(p, notice.push(code, acc, cstr(c)))
        case Stop{c, acc}:
          (c, List.reverse(&1, Notice, acc))

def notices.start(r: Cur & Nat) -> Cur & List<&1, Notice>:
  (c, f) = r
  notices(f, notice.code(Nil{}, uint(c, 1)))

def notices.dec(c: Cur) -> Cur & List<&1, Notice>:
  notices.start(left(c))

def fd.g(name: Bytes.Bytes, +tb: U32, +col: U32, +oid: U32, +sz: U32, +md: U32, r: Cur & U32) -> Cur & Field:
  (c, +fmt) = r
  (c, Field{name, tb, col, oid, sz, md, fmt})

def fd.f(name: Bytes.Bytes, +tb: U32, +col: U32, +oid: U32, +sz: U32, r: Cur & U32) -> Cur & Field:
  (c, +md) = r
  fd.g(name, tb, col, oid, sz, md, uint(c, 2))

def fd.e(name: Bytes.Bytes, +tb: U32, +col: U32, +oid: U32, r: Cur & U32) -> Cur & Field:
  (c, +sz) = r
  fd.f(name, tb, col, oid, sz, uint(c, 4))

def fd.d(name: Bytes.Bytes, +tb: U32, +col: U32, r: Cur & U32) -> Cur & Field:
  (c, +oid) = r
  fd.e(name, tb, col, oid, uint(c, 2))

def fd.c(name: Bytes.Bytes, +tb: U32, r: Cur & U32) -> Cur & Field:
  (c, +col) = r
  fd.d(name, tb, col, uint(c, 4))

def fd.b(name: Bytes.Bytes, r: Cur & U32) -> Cur & Field:
  (c, +tb) = r
  fd.c(name, tb, uint(c, 2))

def fd.a(r: Cur & Bytes.Bytes) -> Cur & Field:
  (c, name) = r
  fd.b(name, uint(c, 4))

def field(c: Cur) -> Cur & Field:
  fd.a(cstr(c))

# ---- backend bodies

def one(-A: Type, f: A -> Back, r: Cur & A) -> Cur & Back:
  (c, x) = r
  (c, f(x))

def ps.b(name: Bytes.Bytes, r: Cur & Bytes.Bytes) -> Cur & Back:
  (c, v) = r
  (c, ParameterStatus{name, v})

def ps.a(r: Cur & Bytes.Bytes) -> Cur & Back:
  (c, n) = r
  ps.b(n, cstr(c))

def bkd.b(+pid: U32, r: Cur & U32) -> Cur & Back:
  (c, +k) = r
  (c, BackendKeyData{pid, k})

def bkd.a(r: Cur & U32) -> Cur & Back:
  (c, +p) = r
  bkd.b(p, uint(c, 4))

def rfq(r: Cur & U32) -> Cur & Back:
  (c, +s) = r
  (need(Bool.or(U32.is_eq(s, 73), Bool.or(U32.is_eq(s, 84), U32.is_eq(s, 69))), c), ReadyForQuery{s})

def auth.data(k: U32, +code: U32, r: Cur & Bytes.Bytes) -> Cur & Back:
  match k:
    case 11:
      (c, d) = r
      (c, AuthSASLContinue{d})
    case 12:
      (c, d) = r
      (c, AuthSASLFinal{d})
    case _:
      (c, d) = r
      (c, AuthOther{code, d})

def auth.of(k: U32, +code: U32, c: Cur) -> Cur & Back:
  match k:
    case 0:
      (c, AuthOk{})
    case 3:
      (c, AuthCleartext{})
    case 10:
      one(List<&1, Bytes.Bytes>, xs => AuthSASL{xs}, names.dec(c))
    case _:
      auth.data(code, code, rest(c))

def auth(r: Cur & U32) -> Cur & Back:
  (c, +code) = r
  auth.of(code, code, c)

def back(t: U32, +tag: U32, c: Cur) -> Cur & Back:
  match t:
    case 82:
      auth(uint(c, 4))
    case 83:
      ps.a(cstr(c))
    case 75:
      bkd.a(uint(c, 4))
    case 90:
      rfq(uint(c, 1))
    case 84:
      one(List<&1, Field>, xs => RowDescription{xs}, list16(~Field, ~field, c))
    case 68:
      one(List<&1, Maybe<&1, Bytes.Bytes>>, xs => DataRow{xs}, list16(~Maybe<&1, Bytes.Bytes>, ~col, c))
    case 67:
      one(Bytes.Bytes, x => CommandComplete{x}, cstr(c))
    case 69:
      one(List<&1, Notice>, xs => ErrorResponse{xs}, notices.dec(c))
    case 78:
      one(List<&1, Notice>, xs => NoticeResponse{xs}, notices.dec(c))
    case 49:
      (c, ParseComplete{})
    case 50:
      (c, BindComplete{})
    case 51:
      (c, CloseComplete{})
    case 110:
      (c, NoData{})
    case 73:
      (c, EmptyQuery{})
    case 115:
      (c, PortalSuspended{})
    case _:
      one(Bytes.Bytes, b => Other{tag, b}, rest(c))

# ---- incremental reader

# Bytes read from the server, and the index of the first byte not yet decoded.
type Reader is Type:
  Reader{buf: Bytes.Bytes, pos: U32}

def reader() -> Reader:
  Reader{Bytes.new(0), 0}

def feed.at(zero: Bool, buf: Bytes.Bytes, +pos: U32, chunk: Bytes.Bytes) -> Reader:
  match zero:
    case True{}:
      Reader{Bytes.append(buf, chunk), 0}
    case False{}:
      Reader{Bytes.append(Bytes.snd(Bytes.slice(buf, pos, 4294967295)), chunk), 0}

# Drops the decoded bytes, then adds chunk.
def feed(r: Reader, chunk: Bytes.Bytes) -> Reader:
  Reader{buf, +pos} = r
  feed.at(U32.is_zero(pos), buf, pos, chunk)

# One message; Want until it has all arrived; Bad for a length below 4 or above 1 GiB,
# or a body its tag does not fill exactly. After Bad the stream has lost its framing.
type Next is Type:
  Got{m: Back}
  Want{}
  Bad{}

def next.done(ok: Bool, +pos: U32, +e: U32, buf: Bytes.Bytes, m: Back) -> Reader & Next:
  match ok:
    case True{}:
      (Reader{buf, e}, Got{m})
    case False{}:
      (Reader{buf, pos}, Bad{})

def next.body(+pos: U32, r: Cur & Back) -> Reader & Next:
  (c, m) = r
  Cur{buf, +i, +e, +ok} = c
  next.done(Bool.and(ok, U32.is_eq(i, e)), pos, e, buf, m)

def next.whole(ok: Bool, +t: U32, +pos: U32, +n: U32, buf: Bytes.Bytes) -> Reader & Next:
  match ok:
    case True{}:
      next.body(pos, back(t, t, Cur{buf, (pos + 5 : U32), (pos + 1 + n : U32), True{}}))
    case False{}:
      (Reader{buf, pos}, Want{})

def next.size(ok: Bool, +t: U32, +pos: U32, +len: U32, +n: U32, buf: Bytes.Bytes) -> Reader & Next:
  match ok:
    case True{}:
      next.whole(Bytes.fits(len, (pos + 1 : U32), n), t, pos, n, buf)
    case False{}:
      (Reader{buf, pos}, Bad{})

def next.n(+t: U32, +pos: U32, +len: U32, r: Cur & U32) -> Reader & Next:
  (c, +n) = r
  Cur{buf, i, e, ok} = c
  next.size(Bool.and(U32.is_le(4, n), U32.is_le(n, 1073741824)), t, pos, len, n, buf)

def next.tag(+pos: U32, +len: U32, r: Cur & U32) -> Reader & Next:
  (c, +t) = r
  next.n(t, pos, len, uint(c, 4))

def next.room(ok: Bool, +pos: U32, +len: U32, buf: Bytes.Bytes) -> Reader & Next:
  match ok:
    case True{}:
      next.tag(pos, len, uint(Cur{buf, pos, len, True{}}, 1))
    case False{}:
      (Reader{buf, pos}, Want{})

def next.len(+pos: U32, r: Bytes.Bytes & U32) -> Reader & Next:
  (buf, +len) = r
  next.room(Bytes.fits(len, pos, 5), pos, len, buf)

# The next backend message.
def next(r: Reader) -> Reader & Next:
  Reader{buf, +pos} = r
  next.len(pos, Bytes.length(buf))

def pending.of(+pos: U32, r: Bytes.Bytes & U32) -> Reader & U32:
  (b, +len) = r
  (Reader{b, pos}, (len - pos : U32))

# The count of bytes read but not yet decoded.
def pending(r: Reader) -> Reader & U32:
  Reader{buf, +pos} = r
  pending.of(pos, Bytes.length(buf))

# ---- frontend decoder, for tests and mock servers

def one.f(-A: Type, f: A -> Front, r: Cur & A) -> Cur & Front:
  (c, x) = r
  (c, f(x))

def fe.sasl(mech: Bytes.Bytes, r: Cur & Maybe<&1, Bytes.Bytes>) -> Cur & Front:
  (c, m) = r
  match m:
    case Some{d}:
      (c, SASLInitial{mech, d})
    case None{}:
      (fail(c), SASLInitial{mech, Bytes.new(0)})

def fe.sasl.a(r: Cur & Bytes.Bytes) -> Cur & Front:
  (c, mech) = r
  fe.sasl(mech, col(c))

def fe.pass(k: U32, c: Cur) -> Cur & Front:
  match k:
    case 1:
      one.f(Bytes.Bytes, t => Password{t}, cstr(c))
    case 2:
      fe.sasl.a(cstr(c))
    case _:
      one.f(Bytes.Bytes, d => SASLResponse{d}, rest(c))

def fe.parse.c(name: Bytes.Bytes, q: Bytes.Bytes, r: Cur & List<&1, U32>) -> Cur & Front:
  (c, oids) = r
  (c, Parse{name, q, dup(oids)})

def fe.parse.b(name: Bytes.Bytes, r: Cur & Bytes.Bytes) -> Cur & Front:
  (c, q) = r
  fe.parse.c(name, q, list16(~U32, ~u32s, c))

def fe.parse.a(r: Cur & Bytes.Bytes) -> Cur & Front:
  (c, name) = r
  fe.parse.b(name, cstr(c))

def fe.bind.e(p: Bytes.Bytes, s: Bytes.Bytes, fs: List<&1, U32>, ps: List<&1, Maybe<&1, Bytes.Bytes>>, r: Cur & List<&1, U32>) -> Cur & Front:
  (c, rs) = r
  (c, Bind{p, s, dup(fs), ps, dup(rs)})

def fe.bind.d(p: Bytes.Bytes, s: Bytes.Bytes, fs: List<&1, U32>, r: Cur & List<&1, Maybe<&1, Bytes.Bytes>>) -> Cur & Front:
  (c, ps) = r
  fe.bind.e(p, s, fs, ps, list16(~U32, ~u16s, c))

def fe.bind.c(p: Bytes.Bytes, s: Bytes.Bytes, r: Cur & List<&1, U32>) -> Cur & Front:
  (c, fs) = r
  fe.bind.d(p, s, fs, list16(~Maybe<&1, Bytes.Bytes>, ~col, c))

def fe.bind.b(p: Bytes.Bytes, r: Cur & Bytes.Bytes) -> Cur & Front:
  (c, s) = r
  fe.bind.c(p, s, list16(~U32, ~u16s, c))

def fe.bind.a(r: Cur & Bytes.Bytes) -> Cur & Front:
  (c, p) = r
  fe.bind.b(p, cstr(c))

def fe.kind(close: Bool, +k: U32, r: Cur & Bytes.Bytes) -> Cur & Front:
  match close:
    case True{}:
      (c, n) = r
      (need(Bool.or(U32.is_eq(k, 83), U32.is_eq(k, 80)), c), CloseMsg{k, n})
    case False{}:
      (c, n) = r
      (need(Bool.or(U32.is_eq(k, 83), U32.is_eq(k, 80)), c), Describe{k, n})

def fe.kind.a(+close: Bool, r: Cur & U32) -> Cur & Front:
  (c, +k) = r
  fe.kind(close, k, cstr(c))

def fe.exec(p: Bytes.Bytes, r: Cur & U32) -> Cur & Front:
  (c, +max) = r
  (c, Execute{p, max})

def fe.exec.a(r: Cur & Bytes.Bytes) -> Cur & Front:
  (c, p) = r
  fe.exec(p, uint(c, 4))

def fe.tagged(t: U32, +mode: U32, c: Cur) -> Cur & Front:
  match t:
    case 112:
      fe.pass(mode, c)
    case 80:
      fe.parse.a(cstr(c))
    case 66:
      fe.bind.a(cstr(c))
    case 68:
      fe.kind.a(False{}, uint(c, 1))
    case 69:
      fe.exec.a(cstr(c))
    case 83:
      (c, Sync{})
    case 67:
      fe.kind.a(True{}, uint(c, 1))
    case 88:
      (c, Terminate{})
    case _:
      (fail(c), Sync{})

def fe.len(+t: U32, +mode: U32, r: Cur & U32) -> Cur & Front:
  (c, +n) = r
  Cur{b, +i, +e, +ok} = c
  fe.tagged(t, mode, Cur{b, i, e, Bool.and(ok, U32.is_eq((n + 1 : U32), e))})

def fe.tag(+mode: U32, r: Cur & U32) -> Cur & Front:
  (c, +t) = r
  fe.len(t, mode, uint(c, 4))

def fe.pkt(k: U32, c: Cur) -> Cur & Front:
  match k:
    case 80877103:
      (c, SSLRequest{})
    case 196608:
      one.f(List<&1, Param>, ps => Startup{ps}, params.dec(c))
    case _:
      (fail(c), SSLRequest{})

def fe.code(r: Cur & U32) -> Cur & Front:
  (c, +k) = r
  fe.pkt(k, c)

def fe.plen(r: Cur & U32) -> Cur & Front:
  (c, +n) = r
  Cur{b, +i, +e, +ok} = c
  fe.code(uint(Cur{b, i, e, Bool.and(ok, U32.is_eq(n, e))}, 4))

def fe.start(k: U32, +mode: U32, c: Cur) -> Cur & Front:
  match k:
    case 0:
      fe.plen(uint(c, 4))
    case _:
      fe.tag(mode, uint(c, 1))

def fe.fin(r: Cur & Front) -> Maybe<&1, Front>:
  (c, m) = r
  Cur{b, +i, +e, ok} = c
  match ok:
    case True{}:
      Bool.pick(Maybe<&1, Front>, U32.is_eq(i, e), Some{m}, None{})
    case False{}:
      None{}

# One frontend message that fills b exactly, or None. The protocol leaves the phase to context:
# mode 0 reads an untagged startup packet, and 'p' reads as Password (1), SASLInitial (2) or SASLResponse (3).
def decode.front(+mode: U32, b: Bytes.Bytes) -> Maybe<&1, Front>:
  Bytes.Bytes{+len, buf} = b
  fe.fin(fe.start(mode, mode, Cur{Bytes.Bytes{len, buf}, 0, len, True{}}))
