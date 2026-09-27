# RFC 9113 HTTP/2 frames and RFC 7541 HPACK header blocks over packed Bytes.
import Base
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
import ./hpack.bend as Hpack

type Frame is Type:
  Frame{kind: U32, flags: U32, stream: U32, payload: Bytes.Bytes}

type Error is Data:
  Error{code: U32, connection: Bool, stream: U32}

type Decode is Type:
  Need{input: Bytes.Bytes}
  Got{frame: Frame, rest: Bytes.Bytes}
  Bad{error: Error}

type Checked is Type:
  Valid{frame: Frame}
  Invalid{error: Error}

# Error codes from RFC 9113 §7: 1=PROTOCOL_ERROR, 3=FLOW_CONTROL_ERROR,
# 6=FRAME_SIZE_ERROR. A connection error uses stream 0.
def fail(+code: U32, +connection: Bool, +stream: U32) -> Maybe<&2, Error>:
  Some{Error{code, connection, Bool.pick(U32, connection, 0, stream)}}

def reject(bad: Bool, +code: U32, +connection: Bool, +stream: U32) -> Maybe<&2, Error>:
  match bad:
    case True{}:
      fail(code, connection, stream)
    case False{}:
      None{}

def first(m: Maybe<&2, Error>, n: Maybe<&2, Error>) -> Maybe<&2, Error>:
  match m:
    case Some{e}:
      Some{e}
    case None{}:
      n

def number(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{x}:
      x
    case None{}:
      0

def with_number(-R: Type, r: Bytes.Bytes & Maybe<&2, U32>, k: Bytes.Bytes -> U32 -> R) -> R:
  (b, m) = r
  k(b, number(m))

def with_slice(-R: Type, r: Bytes.Bytes & Bytes.Bytes, k: Bytes.Bytes -> Bytes.Bytes -> R) -> R:
  (b, part) = r
  k(b, part)

def has(+flags: U32, +bit: U32) -> Bool:
  U32.is_ne((flags .&. bit : U32), 0)

# Field blocks, SETTINGS, and stream 0 make frame-size faults connection-wide.
def size.scope(+kind: U32, +stream: U32) -> Bool:
  match kind:
    case 1:
      True{}
    case 4:
      True{}
    case 5:
      True{}
    case 9:
      True{}
    case _:
      U32.is_eq(stream, 0)

def size.error(+kind: U32, +stream: U32) -> Error:
  +connection = size.scope(kind, stream)
  Error{6, connection, Bool.pick(U32, connection, 0, stream)}

def size.reject(oversized: Bool, +kind: U32, +stream: U32) -> Maybe<&2, Error>:
  match oversized:
    case True{}:
      Some{size.error(kind, stream)}
    case False{}:
      None{}

# A PADDED payload must contain the pad-length octet and all the padding.
def padding(+flags: U32, +len: U32, +fixed: U32, +pad: U32) -> Bool:
  Bool.and(has(flags, 8), Bool.or(U32.is_le(len, fixed), U32.is_gt(pad, (len - fixed - 1 : U32))))

def setting(+id: U32, +value: U32) -> Maybe<&2, Error>:
  match id:
    case 2:
      reject(U32.is_gt(value, 1), 1, True{}, 0)
    case 4:
      reject(U32.is_gt(value, 2147483647), 3, True{}, 0)
    case 5:
      reject(Bool.or(U32.is_lt(value, 16384), U32.is_gt(value, 16777215)), 1, True{}, 0)
    case _:
      None{}

def settings.go(n: Nat, b: Bytes.Bytes, +at: U32, m: Maybe<&2, Error>) -> Bytes.Bytes & Maybe<&2, Error>:
  match n:
    case 0n:
      (b, m)
    case 1n+p:
      with_number(Bytes.Bytes & Maybe<&2, Error>, Bytes.get.u16be(b, at), b => id =>
        with_number(Bytes.Bytes & Maybe<&2, Error>, Bytes.get.u32be(b, (at + 2 : U32)), b => value =>
          settings.go(p, b, (at + 6 : U32), first(m, setting(id, value)))))

def rules(+kind: U32, +flags: U32, +stream: U32, +len: U32, +pad: U32, +promised: U32, +value: U32, m: Maybe<&2, Error>) -> Maybe<&2, Error>:
  match kind:
    case 0:
      first(reject(U32.is_eq(stream, 0), 1, True{}, stream),
        first(reject(Bool.and(has(flags, 8), U32.is_eq(len, 0)), 6, False{}, stream),
          reject(padding(flags, len, 0, pad), 1, True{}, stream)))
    case 1:
      +fixed = Bool.pick(U32, has(flags, 32), 5, 0)
      +prefix = Bool.pick(U32, has(flags, 8), 1, 0)
      first(reject(U32.is_eq(stream, 0), 1, True{}, stream),
        first(reject(U32.is_lt(len, (fixed + prefix : U32)), 6, True{}, stream),
          reject(padding(flags, len, fixed, pad), 1, True{}, stream)))
    case 2:
      first(reject(U32.is_ne(len, 5), 6, U32.is_eq(stream, 0), stream),
        reject(U32.is_eq(stream, 0), 1, True{}, stream))
    case 3:
      first(reject(U32.is_ne(len, 4), 6, True{}, stream),
        reject(U32.is_eq(stream, 0), 1, True{}, stream))
    case 4:
      first(reject(U32.is_ne(stream, 0), 1, True{}, stream),
        first(reject(Bool.and(has(flags, 1), U32.is_ne(len, 0)), 6, True{}, stream),
          first(reject(U32.is_ne((len % 6 : U32), 0), 6, True{}, stream), m)))
    case 5:
      +prefix = Bool.pick(U32, has(flags, 8), 1, 0)
      first(reject(U32.is_eq(stream, 0), 1, True{}, stream),
        first(reject(U32.is_lt(len, (prefix + 4 : U32)), 6, True{}, stream),
          first(reject(padding(flags, len, 4, pad), 1, True{}, stream),
            reject(U32.is_eq(promised, 0), 1, True{}, stream))))
    case 6:
      first(reject(U32.is_ne(len, 8), 6, True{}, stream),
        reject(U32.is_ne(stream, 0), 1, True{}, stream))
    case 7:
      first(reject(U32.is_lt(len, 8), 6, True{}, stream),
        reject(U32.is_ne(stream, 0), 1, True{}, stream))
    case 8:
      first(reject(U32.is_ne(len, 4), 6, U32.is_eq(stream, 0), stream),
        reject(U32.is_eq((value .&. 2147483647 : U32), 0), 1, U32.is_eq(stream, 0), stream))
    case 9:
      reject(U32.is_eq(stream, 0), 1, True{}, stream)
    case _:
      None{}

def checked(m: Maybe<&2, Error>, +kind: U32, +flags: U32, +stream: U32, b: Bytes.Bytes) -> Checked:
  match m:
    case Some{e}:
      Invalid{e}
    case None{}:
      Valid{Frame{kind, flags, stream, b}}

def with_settings(r: Bytes.Bytes & Maybe<&2, Error>, +flags: U32, +stream: U32) -> Checked:
  (b, m) = r
  checked(m, 4, flags, stream, b)

def inspect.settings(m: Maybe<&2, Error>, +flags: U32, +stream: U32, +len: U32, b: Bytes.Bytes) -> Checked:
  match m:
    case Some{e}:
      Invalid{e}
    case None{}:
      with_settings(settings.go(U32.to_nat((len / 6 : U32)), b, 0, None{}), flags, stream)

def inspect.promised(+kind: U32, +flags: U32, +stream: U32, +len: U32, +pad: U32, b: Bytes.Bytes) -> Checked:
  match kind:
    case 5:
      +prefix = Bool.pick(U32, has(flags, 8), 1, 0)
      with_number(Checked, Bytes.get.u32be(b, prefix), b => promised =>
        checked(rules(kind, flags, stream, len, pad, (promised .&. 2147483647 : U32), 0, None{}), kind, flags, stream, b))
    case _:
      checked(rules(kind, flags, stream, len, pad, 0, 0, None{}), kind, flags, stream, b)

def inspect.padded.if(padded: Bool, +kind: U32, +flags: U32, +stream: U32, +len: U32, b: Bytes.Bytes) -> Checked:
  match padded:
    case True{}:
      with_number(Checked, Bytes.get(b, 0), b => pad =>
        inspect.promised(kind, flags, stream, len, pad, b))
    case False{}:
      inspect.promised(kind, flags, stream, len, 0, b)

def inspect.padded(+kind: U32, +flags: U32, +stream: U32, +len: U32, b: Bytes.Bytes) -> Checked:
  inspect.padded.if(has(flags, 8), kind, flags, stream, len, b)

def inspect.detail(+kind: U32, +flags: U32, +stream: U32, +len: U32, b: Bytes.Bytes) -> Checked:
  match kind:
    case 0:
      inspect.padded(kind, flags, stream, len, b)
    case 1:
      inspect.padded(kind, flags, stream, len, b)
    case 4:
      inspect.settings(rules(kind, flags, stream, len, 0, 0, 0, None{}), flags, stream, len, b)
    case 5:
      inspect.padded(kind, flags, stream, len, b)
    case 8:
      with_number(Checked, Bytes.get.u32be(b, 0), b => value =>
        checked(rules(kind, flags, stream, len, 0, 0, value, None{}), kind, flags, stream, b))
    case _:
      checked(rules(kind, flags, stream, len, 0, 0, 0, None{}), kind, flags, stream, b)


def inspect.basic(m: Maybe<&2, Error>, +kind: U32, +flags: U32, +stream: U32, +len: U32, b: Bytes.Bytes) -> Checked:
  match m:
    case Some{e}:
      Invalid{e}
    case None{}:
      inspect.detail(kind, flags, stream, len, b)

def inspect(max: U32, +kind: U32, +flags: U32, +stream: U32, b: Bytes.Bytes) -> Checked:
  Bytes.Bytes{+len, buf} = b
  +basic = first(size.reject(Bool.or(U32.is_gt(len, max), U32.is_gt(len, 16777215)), kind, stream),
    first(reject(U32.is_gt(kind, 255), 1, True{}, stream),
      first(reject(U32.is_gt(flags, 255), 1, True{}, stream),
        reject(U32.is_gt(stream, 2147483647), 1, True{}, stream))))
  inspect.basic(basic, kind, flags, stream, len, Bytes.Bytes{len, buf})

# max is the peer's SETTINGS_MAX_FRAME_SIZE, initially 16384.
def allowed(+kind: U32) -> U32:
  match kind:
    case 0:
      9
    case 1:
      45
    case 2:
      0
    case 3:
      0
    case 4:
      1
    case 5:
      12
    case 6:
      1
    case 7:
      0
    case 8:
      0
    case 9:
      4
    case _:
      255

def encode.buffer(b: Bytes.Bytes, src: Array<U32>, +len: U32) -> Result<&1, &1, Error, Bytes.Bytes>:
  Bytes.Bytes{_, dst} = b
  Done{Bytes.Bytes{(len + 9 : U32), Bytes.dst(Bytes.copy(len, src, dst, 0, 9))}}

def encode.flags(ok: Bool, +kind: U32, +flags: U32, +stream: U32, payload: Bytes.Bytes) -> Result<&1, &1, Error, Bytes.Bytes>:
  match ok:
    case False{}:
      Fail{Error{1, True{}, 0}}
    case True{}:
      Bytes.Bytes{+len, src} = payload
      encode.buffer(Bytes.set.u32be(Bytes.set(Bytes.set(Bytes.put(Bytes.new((len + 9 : U32)), 0, 3, True{}, len), 3, kind), 4, flags), 5, stream), src, len)

def encode.checked(c: Checked) -> Result<&1, &1, Error, Bytes.Bytes>:
  match c:
    case Invalid{e}:
      Fail{e}
    case Valid{Frame{+kind, +flags, +stream, payload}}:
      encode.flags(U32.is_eq((flags .&. U32.not(allowed(kind)) : U32), 0), kind, flags, stream, payload)
def encode(max: U32, f: Frame) -> Result<&1, &1, Error, Bytes.Bytes>:
  Frame{+kind, +flags, +stream, payload} = f
  encode.checked(inspect(max, kind, flags, stream, payload))

def parse.result(c: Checked, b: Bytes.Bytes, +len: U32) -> Decode:
  match c:
    case Invalid{e}:
      Bad{e}
    case Valid{f}:
      Bytes.Bytes{+n, buf} = b
      with_slice(Decode, Bytes.slice(Bytes.Bytes{n, buf}, (len + 9 : U32), (n - len - 9 : U32)),
        unused => rest => Got{f, rest})

def parse.payload(max: U32, +len: U32, +kind: U32, +flags: U32, +stream: U32, b: Bytes.Bytes) -> Decode:
  with_slice(Decode, Bytes.slice(b, 9, len), b => payload =>
    parse.result(inspect(max, kind, flags, stream, payload), b, len))

def parse.full(enough: Bool, max: U32, +len: U32, +kind: U32, +flags: U32, +stream: U32, b: Bytes.Bytes) -> Decode:
  match enough:
    case True{}:
      parse.payload(max, len, kind, flags, stream, b)
    case False{}:
      Need{b}

def parse.size(oversized: Bool, max: U32, +len: U32, +kind: U32, +flags: U32, +stream: U32, b: Bytes.Bytes) -> Decode:
  match oversized:
    case True{}:
      Bad{size.error(kind, stream)}
    case False{}:
      Bytes.Bytes{+n, buf} = b
      parse.full(U32.is_le(len, (n - 9 : U32)), max, len, kind, flags, stream, Bytes.Bytes{n, buf})

def parse.header(+max: U32, b: Bytes.Bytes) -> Decode:
  with_number(Decode, Bytes.uint(b, 0, 3, True{}), b => +len =>
    with_number(Decode, Bytes.get(b, 3), b => kind =>
      with_number(Decode, Bytes.get(b, 4), b => flags =>
        with_number(Decode, Bytes.get.u32be(b, 5), b => stream =>
          parse.size(U32.is_gt(len, max), max, len, kind, flags, (stream .&. 2147483647 : U32), b)))))

def parse.start(short: Bool, max: U32, b: Bytes.Bytes) -> Decode:
  match short:
    case True{}:
      Need{b}
    case False{}:
      parse.header(max, b)

# A partial header or payload returns Need with the original input intact.
def parse(max: U32, b: Bytes.Bytes) -> Decode:
  Bytes.Bytes{+n, buf} = b
  parse.start(U32.is_lt(n, 9), max, Bytes.Bytes{n, buf})
