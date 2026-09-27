# RFC 9113 HTTP/2 client and frames, with RFC 7541 HPACK over packed Bytes.
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

# Send windows use U32 two's-complement; a SETTINGS change can make a stream window negative.
type Stream is Type:
  Stream{id: U32, send_window: U32, recv_window: U32, local_end: Bool, remote_end: Bool,
    head: Bool, headers: List<&2, Hpack.Field>, partial: Bytes.Bytes, body: Bytes.Bytes, outgoing: Bytes.Bytes}

type Control is Data:
  Control{next: U32, active: U32, frame_max: U32, initial: U32, max_streams: Maybe<&2, U32>,
    send_window: U32, recv_window: U32, first: Bool, ack: Bool,
    continuation: Maybe<&2, U32>, goaway: Maybe<&2, U32>}

type Client is Type:
  Client{input: Bytes.Bytes, streams: List<&1, Stream>,
    encoder: Hpack.State, decoder: Hpack.State, control: Control}

type ClientEvent is Type:
  Response{id: U32, headers: List<&2, Hpack.Field>, body: Bytes.Bytes}
  Reset{id: U32, code: U32}
  Shutdown{last: U32, code: U32}
  Pong{data: Bytes.Bytes}

type Reply is Type:
  Ready{client: Client, writes: List<&1, Bytes.Bytes>, events: List<&1, ClientEvent>}
  Failed{error: Error}

def client.start() -> Client & Bytes.Bytes:
  (Client{Bytes.new(0), Nil{}, Hpack.new(4096), Hpack.new(4096),
    Control{1, 0, 16384, 65535, None{}, 65535, 65535, True{}, True{}, None{}, None{}}},
    Bytes.append(Bytes.from_string("PRI * HTTP/2.0\u{d}\u{a}\u{d}\u{a}SM\u{d}\u{a}\u{d}\u{a}"),
      Bytes.set.u16be(Bytes.set(Bytes.set(Bytes.new(15), 2, 6), 3, 4), 9, 2)))

def client.frame(r: Result<&1, &1, Error, Bytes.Bytes>) -> Maybe<&1, Bytes.Bytes>:
  match r:
    case Fail{error}:
      None{}
    case Done{bytes}:
      Some{bytes}

def client.headers.empty(first: Bool, end_stream: Bool, id: U32, max: U32, rev: List<&1, Bytes.Bytes>) -> Maybe<&1, List<&1, Bytes.Bytes>>:
  match first:
    case False{}:
      Some{List.reverse(&1, Bytes.Bytes, rev)}
    case True{}:
      Maybe.map(&1, Bytes.Bytes, List<&1, Bytes.Bytes>,
        b => List.reverse(&1, Bytes.Bytes, Con{b, rev}),
        client.frame(encode(max, Frame{1, (4 + Bool.pick(U32, end_stream, 1, 0) : U32), id, Bytes.new(0)})))

def client.headers.go(n: Nat, +first: Bool, +end_stream: Bool, +id: U32, +max: U32, block: Bytes.Bytes, rev: List<&1, Bytes.Bytes>) -> Maybe<&1, List<&1, Bytes.Bytes>>:
  match n:
    case 0n:
      None{}
    case 1n+p:
      match block:
        case Bytes.Bytes{0, buf}:
          client.headers.empty(first, end_stream, id, max, rev)
        case Bytes.Bytes{+len, buf}:
          +take = Bool.pick(U32, U32.is_le(len, max), len, max)
          +last = U32.is_le(len, max)
          with_slice(Maybe<&1, List<&1, Bytes.Bytes>>, Bytes.slice(Bytes.Bytes{len, buf}, 0, take), whole => part =>
            with_slice(Maybe<&1, List<&1, Bytes.Bytes>>, Bytes.slice(whole, take, (len - take : U32)), unused => rest =>
              Maybe.bind(&1, Bytes.Bytes, List<&1, Bytes.Bytes>,
                client.frame(encode(max, Frame{Bool.pick(U32, first, 1, 9),
                  (Bool.pick(U32, last, 4, 0) + Bool.pick(U32, Bool.and(first, end_stream), 1, 0) : U32), id, part})),
                packet => client.headers.go(p, False{}, end_stream, id, max, rest, Con{packet, rev}))))

def client.headers(end_stream: Bool, +id: U32, +max: U32, block: Bytes.Bytes) -> Maybe<&1, List<&1, Bytes.Bytes>>:
  Bytes.Bytes{+len, buf} = block
  client.headers.go(1n+U32.to_nat(len), True{}, end_stream, id, max, Bytes.Bytes{len, buf}, Nil{})

type BodySent is Type:
  BodySent{remaining: Bytes.Bytes, ended: Bool, stream_window: U32,
    connection_window: U32, writes: List<&1, Bytes.Bytes>}

def client.min(+a: U32, +b: U32) -> U32:
  Bool.pick(U32, U32.is_le(a, b), a, b)

def client.positive(+w: U32) -> U32:
  Bool.pick(U32, U32.is_lt(w, 2147483648), w, 0)

def client.available(+len: U32, +max: U32, +connection: U32, +stream: U32) -> U32:
  client.min(client.min(len, max), client.min(client.positive(connection), client.positive(stream)))

def client.data.go(n: Nat, body: Bytes.Bytes, take: U32, +id: U32, +max: U32,
    +connection: U32, +stream: U32, rev: List<&1, Bytes.Bytes>) -> Maybe<&1, BodySent>:
  match n:
    case 0n:
      None{}
    case 1n+p:
      match body:
        case Bytes.Bytes{0, buf}:
          Some{BodySent{Bytes.Bytes{0, buf}, True{}, stream, connection, List.reverse(&1, Bytes.Bytes, rev)}}
        case Bytes.Bytes{+len, buf}:
          match take:
            case 0:
              Some{BodySent{Bytes.Bytes{len, buf}, False{}, stream, connection, List.reverse(&1, Bytes.Bytes, rev)}}
            case +count:
              with_slice(Maybe<&1, BodySent>, Bytes.slice(Bytes.Bytes{len, buf}, 0, count), whole => part =>
                with_slice(Maybe<&1, BodySent>, Bytes.slice(whole, count, (len - count : U32)), unused => rest =>
                  Maybe.bind(&1, Bytes.Bytes, BodySent,
                    client.frame(encode(max, Frame{0, Bool.pick(U32, U32.is_eq(count, len), 1, 0), id, part})), packet =>
                      +new_connection = (connection - count : U32)
                      +new_stream = (stream - count : U32)
                      +remaining = (len - count : U32)
                      client.data.go(p, rest, client.available(remaining, max, new_connection, new_stream),
                        id, max, new_connection, new_stream, Con{packet, rev}))))

def client.data(+id: U32, +max: U32, +connection: U32, +stream: U32, body: Bytes.Bytes) -> Maybe<&1, BodySent>:
  Bytes.Bytes{+len, buf} = body
  client.data.go(1n+U32.to_nat(len), Bytes.Bytes{len, buf},
    client.available(len, max, connection, stream), id, max, connection, stream, Nil{})

def client.limit(m: Maybe<&2, U32>, active: U32) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{max}:
      U32.is_lt(active, max)

def client.can(c: Control) -> Bool:
  Control{+next, active, frame_max, initial, max_streams, send_window, recv_window, first, ack, continuation, goaway} = c
  Bool.and(U32.is_le(next, 2147483647),
    Bool.and(Maybe.is_none(&2, U32, goaway), client.limit(max_streams, active)))

def client.id(c: Control) -> U32:
  Control{next, active, frame_max, initial, max_streams, send_window, recv_window, first, ack, continuation, goaway} = c
  next

def client.frame_max(c: Control) -> U32:
  Control{next, active, frame_max, initial, max_streams, send_window, recv_window, first, ack, continuation, goaway} = c
  frame_max

def client.request.done(sent: BodySent, headers: List<&1, Bytes.Bytes>, encoder: Hpack.State, c: Client) -> Reply:
  BodySent{remaining, ended, stream_window, connection_window, data} = sent
  Client{input, streams, old, decoder,
    Control{+next, +active, frame_max, initial, max_streams, previous, recv_window, first, ack, continuation, goaway}} = c
  Ready{Client{input,
    Con{Stream{next, stream_window, 65535, ended, False{}, False{}, Nil{}, Bytes.new(0), Bytes.new(0), remaining}, streams},
    encoder, decoder,
    Control{(next + 2 : U32), (active + 1 : U32), frame_max, initial, max_streams,
      connection_window, recv_window, first, ack, continuation, goaway}},
    List.append(&1, Bytes.Bytes, headers, data), Nil{}}

def client.request.data(m: Maybe<&1, BodySent>, headers: List<&1, Bytes.Bytes>, encoder: Hpack.State, c: Client) -> Reply:
  match m:
    case None{}:
      Failed{Error{1, True{}, 0}}
    case Some{sent}:
      client.request.done(sent, headers, encoder, c)

def client.request.frames(m: Maybe<&1, List<&1, Bytes.Bytes>>, body: Bytes.Bytes, encoder: Hpack.State, c: Client) -> Reply:
  match m:
    case None{}:
      Failed{Error{6, True{}, 0}}
    case Some{headers}:
      Client{input, streams, old, decoder,
        +control} = c
      Control{+next, active, +frame_max, initial, max_streams, +connection, recv_window, first, ack, continuation, goaway} = control
      client.request.data(client.data(next, frame_max, connection, initial, body),
        headers, encoder, Client{input, streams, old, decoder, control})

def client.request.body(r: Bytes.Bytes & U32, encoder: Hpack.State, block: Bytes.Bytes, c: Client) -> Reply:
  (body, +len) = r
  Client{input, streams, old, decoder, +control} = c
  client.request.frames(client.headers(U32.is_eq(len, 0), client.id(control), client.frame_max(control), block),
    body, encoder, Client{input, streams, old, decoder, control})

def client.request.encoded(m: Maybe<&1, Hpack.State & Bytes.Bytes>, c: Client, body: Bytes.Bytes) -> Reply:
  match m:
    case None{}:
      Failed{Error{1, True{}, 0}}
    case Some{(encoder, block)}:
      client.request.body(Bytes.length(body), encoder, block, c)

def client.request.ready(valid: Bool, c: Client, fields: List<&2, Hpack.Field>, body: Bytes.Bytes) -> Reply:
  match valid:
    case False{}:
      Failed{Error{7, True{}, 0}}
    case True{}:
      Client{input, streams, +encoder, decoder, control} = c
      client.request.encoded(Hpack.encode(fields, False{}, encoder),
        Client{input, streams, encoder, decoder, control}, body)

def client.request(c: Client, fields: List<&2, Hpack.Field>, body: Bytes.Bytes) -> Reply:
  Client{input, streams, encoder, decoder, +control} = c
  client.request.ready(client.can(control), Client{input, streams, encoder, decoder, control}, fields, body)

def client.fail(+code: U32, +connection: Bool, +stream: U32) -> Reply:
  Failed{Error{code, connection, Bool.pick(U32, connection, 0, stream)}}

def client.ok(c: Client) -> Reply:
  Ready{c, Nil{}, Nil{}}

def client.after(r: Reply, k: Client -> List<&1, Bytes.Bytes> -> List<&1, ClientEvent> -> Reply) -> Reply:
  match r:
    case Failed{error}:
      Failed{error}
    case Ready{client, writes, events}:
      k(client, writes, events)

def client.write(m: Maybe<&1, Bytes.Bytes>, c: Client) -> Reply:
  match m:
    case None{}:
      client.fail(1, True{}, 0)
    case Some{packet}:
      Ready{c, [packet], Nil{}}

def client.ping(+flags: U32, payload: Bytes.Bytes, c: Client) -> Reply:
  match flags:
    case 0:
      client.write(client.frame(encode(16384, Frame{6, 1, 0, payload})), c)
    case 1:
      Ready{c, Nil{}, [Pong{payload}]}
    case _:
      client.fail(1, True{}, 0)

def client.ping.request(c: Client, payload: Bytes.Bytes) -> Reply:
  client.write(client.frame(encode(16384, Frame{6, 0, 0, payload})), c)

def client.window.add(valid: Bool, +w: U32, +delta: U32) -> Maybe<&1, U32>:
  match valid:
    case False{}:
      None{}
    case True{}:
      Some{(w + delta : U32)}

def client.window.adjust.sign(positive: Bool, +w: U32, +delta: U32) -> Maybe<&1, U32>:
  match positive:
    case True{}:
      client.window.add(Bool.or(U32.is_ge(w, 2147483648),
        U32.is_le(w, (2147483647 - delta : U32))), w, delta)
    case False{}:
      client.window.add(Bool.or(U32.is_lt(w, 2147483648),
        U32.is_ge(w, (2147483648 - delta : U32))), w, delta)

def client.window.adjust(+w: U32, +delta: U32) -> Maybe<&1, U32>:
  client.window.adjust.sign(U32.is_lt(delta, 2147483648), w, delta)

def client.window.plus.sign(positive: Bool, +w: U32, +value: U32) -> Maybe<&1, U32>:
  match positive:
    case True{}:
      client.window.add(U32.is_le(value, (2147483647 - w : U32)), w, value)
    case False{}:
      Some{(w + value : U32)}

def client.window.plus(+w: U32, value: U32) -> Maybe<&1, U32>:
  client.window.plus.sign(U32.is_lt(w, 2147483648), w, value)

def client.stream.adjust(s: Stream, delta: U32) -> Maybe<&1, Stream>:
  Stream{id, send_window, recv_window, local_end, remote_end, head, headers, partial, body, outgoing} = s
  Maybe.map(&1, U32, Stream,
    next => Stream{id, next, recv_window, local_end, remote_end, head, headers, partial, body, outgoing},
    client.window.adjust(send_window, delta))

def client.streams.adjust(xs: List<&1, Stream>, +delta: U32) -> Maybe<&1, List<&1, Stream>>:
  match xs:
    case Nil{}:
      Some{Nil{}}
    case Con{first, rest}:
      Maybe.bind(&1, Stream, List<&1, Stream>, client.stream.adjust(first, delta), updated =>
        Maybe.map(&1, List<&1, Stream>, List<&1, Stream>, tail => Con{updated, tail},
          client.streams.adjust(rest, delta)))

def client.settings.initial.done(m: Maybe<&1, List<&1, Stream>>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  match m:
    case None{}:
      client.fail(3, True{}, 0)
    case Some{streams}:
      client.ok(Client{input, streams, encoder, decoder, control})

def client.settings.initial(+value: U32, c: Client) -> Reply:
  Client{input, streams, encoder, decoder,
    Control{next, active, frame_max, +initial, max_streams, send_window, recv_window,
      first, ack, continuation, goaway}} = c
  +delta = (value - initial : U32)
  client.settings.initial.done(client.streams.adjust(streams, delta),
    input, encoder, decoder,
    Control{next, active, frame_max, value, max_streams, send_window, recv_window,
      first, ack, continuation, goaway})

def client.settings.item(id: U32, +value: U32, c: Client) -> Reply:
  match id:
    case 1:
      Client{input, streams, encoder, decoder, control} = c
      client.ok(Client{input, streams, Hpack.set_limit(value, encoder), decoder, control})
    case 2:
      client.fail(1, True{}, 0)
    case 3:
      Client{input, streams, encoder, decoder,
        Control{next, active, frame_max, initial, max_streams, send_window, recv_window,
          first, ack, continuation, goaway}} = c
      client.ok(Client{input, streams, encoder, decoder,
        Control{next, active, frame_max, initial, Some{value}, send_window, recv_window,
          first, ack, continuation, goaway}})
    case 4:
      client.settings.initial(value, c)
    case 5:
      Client{input, streams, encoder, decoder,
        Control{next, active, frame_max, initial, max_streams, send_window, recv_window,
          first, ack, continuation, goaway}} = c
      client.ok(Client{input, streams, encoder, decoder,
        Control{next, active, value, initial, max_streams, send_window, recv_window,
          first, ack, continuation, goaway}})
    case _:
      client.ok(c)

def client.settings.go(n: Nat, b: Bytes.Bytes, +at: U32, c: Client) -> Reply:
  match n:
    case 0n:
      client.write(client.frame(encode(16384, Frame{4, 1, 0, Bytes.new(0)})), c)
    case 1n+p:
      with_number(Reply, Bytes.get.u16be(b, at), read_id => id =>
        with_number(Reply, Bytes.get.u32be(read_id, (at + 2 : U32)), rest => value =>
          client.after(client.settings.item(id, value, c), next => writes => events =>
            client.settings.go(p, rest, (at + 6 : U32), next))))

def client.settings.mark(c: Client) -> Client:
  Client{input, streams, encoder, decoder,
    Control{next, active, frame_max, initial, max_streams, send_window, recv_window,
      first, ack, continuation, goaway}} = c
  Client{input, streams, encoder, decoder,
    Control{next, active, frame_max, initial, max_streams, send_window, recv_window,
      False{}, ack, continuation, goaway}}

def client.settings.ack(c: Client) -> Reply:
  Client{input, streams, encoder, decoder,
    Control{next, active, frame_max, initial, max_streams, send_window, recv_window,
      first, ack, continuation, goaway}} = c
  match ack:
    case False{}:
      client.fail(1, True{}, 0)
    case True{}:
      client.ok(Client{input, streams, encoder, decoder,
        Control{next, active, frame_max, initial, max_streams, send_window, recv_window,
          first, False{}, continuation, goaway}})

def client.settings(flags: U32, payload: Bytes.Bytes, c: Client) -> Reply:
  match flags:
    case 1:
      client.settings.ack(c)
    case 0:
      Bytes.Bytes{+len, buf} = payload
      client.settings.go(U32.to_nat(U32.div(len, 6)), Bytes.Bytes{len, buf}, 0, client.settings.mark(c))
    case _:
      client.fail(1, True{}, 0)

def client.streams.prefix(previous: Maybe<&1, Stream>, r: Reply) -> Reply:
  match previous:
    case None{}:
      r
    case Some{s}:
      match r:
        case Failed{error}:
          Failed{error}
        case Ready{Client{input, streams, encoder, decoder, control}, writes, events}:
          Ready{Client{input, Con{s, streams}, encoder, decoder, control}, writes, events}

def client.streams.go(xs: List<&1, Stream>, found: Bool, previous: Maybe<&1, Stream>,
    +target: U32, k: Stream -> List<&1, Stream> -> Reply) -> Reply:
  match xs:
    case Nil{}:
      match found:
        case False{}:
          client.fail(5, False{}, target)
        case True{}:
          match previous:
            case None{}:
              client.fail(1, True{}, 0)
            case Some{s}:
              k(s, Nil{})
    case Con{s, rest}:
      Stream{+id, send_window, recv_window, local_end, remote_end, head, headers, partial, body, outgoing} = s
      match found:
        case True{}:
          match previous:
            case None{}:
              client.fail(1, True{}, 0)
            case Some{matched}:
              k(matched, Con{Stream{id, send_window, recv_window, local_end, remote_end,
                head, headers, partial, body, outgoing}, rest})
        case False{}:
          client.streams.prefix(previous,
            client.streams.go(rest, U32.is_eq(id, target),
              Some{Stream{id, send_window, recv_window, local_end, remote_end, head, headers, partial, body, outgoing}},
              target, k))

def client.streams.use(xs: List<&1, Stream>, target: U32, k: Stream -> List<&1, Stream> -> Reply) -> Reply:
  client.streams.go(xs, False{}, None{}, target, k)

type Flushed is Type:
  Flushed{streams: List<&1, Stream>, connection: U32, writes: List<&1, Bytes.Bytes>}

def client.flush.prepend(s: Stream, packets: List<&1, Bytes.Bytes>, tail: Flushed) -> Flushed:
  Flushed{more, window, writes} = tail
  Flushed{Con{s, more}, window, List.append(&1, Bytes.Bytes, packets, writes)}

def client.with_sent(-R: Type, sent: BodySent,
    k: Bytes.Bytes -> Bool -> U32 -> U32 -> List<&1, Bytes.Bytes> -> R) -> R:
  BodySent{remaining, ended, stream, connection, packets} = sent
  k(remaining, ended, stream, connection, packets)

def client.flush.go(xs: List<&1, Stream>, +connection: U32, +max: U32) -> Maybe<&1, Flushed>:
  match xs:
    case Nil{}:
      Some{Flushed{Nil{}, connection, Nil{}}}
    case Con{Stream{+id, +stream_window, recv_window, local_end, remote_end,
        head, headers, partial, body, outgoing}, rest}:
      match outgoing:
        case Bytes.Bytes{0, buf}:
          Maybe.map(&1, Flushed, Flushed, tail =>
            client.flush.prepend(Stream{id, stream_window, recv_window, local_end, remote_end,
              head, headers, partial, body, Bytes.Bytes{0, buf}}, Nil{}, tail),
            client.flush.go(rest, connection, max))
        case Bytes.Bytes{+len, buf}:
          Maybe.bind(&1, BodySent, Flushed,
            client.data(id, max, connection, stream_window, Bytes.Bytes{len, buf}), sent =>
              client.with_sent(Maybe<&1, Flushed>, sent, remaining => ended => next_stream => next_connection => packets =>
                Maybe.map(&1, Flushed, Flushed, tail =>
                  client.flush.prepend(Stream{id, next_stream, recv_window, ended, remote_end,
                    head, headers, partial, body, remaining}, packets, tail),
                  client.flush.go(rest, next_connection, max))))

def client.flush.done(m: Maybe<&1, Flushed>, input: Bytes.Bytes, encoder: Hpack.State,
    decoder: Hpack.State, control: Control) -> Reply:
  match m:
    case None{}:
      client.fail(1, True{}, 0)
    case Some{Flushed{streams, +connection, writes}}:
      Control{next, active, frame_max, initial, max_streams, previous, recv_window,
        first, ack, continuation, goaway} = control
      Ready{Client{input, streams, encoder, decoder,
        Control{next, active, frame_max, initial, max_streams, connection, recv_window,
          first, ack, continuation, goaway}}, writes, Nil{}}

def client.window.connection.valid(m: Maybe<&1, U32>, c: Client) -> Reply:
  match m:
    case None{}:
      client.fail(3, True{}, 0)
    case Some{w}:
      Client{input, streams, encoder, decoder, +control} = c
      Control{next, active, +frame_max, initial, max_streams, send_window, recv_window,
        first, ack, continuation, goaway} = control
      client.flush.done(client.flush.go(streams, w, frame_max),
        input, encoder, decoder, control)

def client.window.connection(+value: U32, c: Client) -> Reply:
  Client{input, streams, encoder, decoder, +control} = c
  Control{next, active, frame_max, initial, max_streams, +send_window, recv_window,
    first, ack, continuation, goaway} = control
  client.window.connection.valid(client.window.plus(send_window, value),
    Client{input, streams, encoder, decoder, control})

def client.window.stream.valid(m: Maybe<&1, U32>, +id: U32, s: Stream, tail: List<&1, Stream>,
    input: Bytes.Bytes, encoder: Hpack.State, decoder: Hpack.State, +control: Control) -> Reply:
  match m:
    case None{}:
      client.fail(3, False{}, id)
    case Some{w}:
      Stream{id, previous, recv_window, local_end, remote_end, head, headers, partial, body, outgoing} = s
      Control{next, active, +frame_max, initial, max_streams, +connection, recv, first, ack, continuation, goaway} = control
      client.flush.done(client.flush.go(
        Con{Stream{id, w, recv_window, local_end, remote_end,
          head, headers, partial, body, outgoing}, tail}, connection, frame_max),
        input, encoder, decoder, control)

def client.window.stream.handle(+value: U32, s: Stream, tail: List<&1, Stream>,
    input: Bytes.Bytes, encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  Stream{+id, +send_window, recv_window, local_end, remote_end, head, headers, partial, body, outgoing} = s
  client.window.stream.valid(client.window.plus(send_window, value), id,
    Stream{id, send_window, recv_window, local_end, remote_end, head, headers, partial, body, outgoing},
    tail, input, encoder, decoder, control)

def client.window.stream(id: U32, +value: U32, c: Client) -> Reply:
  Client{input, streams, encoder, decoder, control} = c
  client.streams.use(streams, id, s => tail =>
    client.window.stream.handle(value, s, tail, input, encoder, decoder, control))

def client.window.route(stream: U32, value: U32, c: Client) -> Reply:
  match stream:
    case 0:
      client.window.connection(value, c)
    case +id:
      client.window.stream(id, value, c)

def client.window.update(stream: U32, payload: Bytes.Bytes, c: Client) -> Reply:
  with_number(Reply, Bytes.get.u32be(payload, 0), rest => raw =>
    client.window.route(stream, (raw .&. 2147483647 : U32), c))

def client.rst.stream(s: Stream, tail: List<&1, Stream>, +code: U32, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  Stream{+id, send_window, recv_window, local_end, remote_end, head, headers, partial, body, outgoing} = s
  Control{next, +active, frame_max, initial, max_streams, connection, recv,
    first, ack, continuation, goaway} = control
  Ready{Client{input, tail, encoder, decoder,
    Control{next, (active - 1 : U32), frame_max, initial, max_streams,
      connection, recv, first, ack, continuation, goaway}}, Nil{}, [Reset{id, code}]}

def client.rst.code(id: U32, +code: U32, c: Client) -> Reply:
  Client{input, streams, encoder, decoder, control} = c
  client.streams.use(streams, id, s => tail =>
    client.rst.stream(s, tail, code, input, encoder, decoder, control))

def client.rst(id: U32, payload: Bytes.Bytes, c: Client) -> Reply:
  with_number(Reply, Bytes.get.u32be(payload, 0), rest => code =>
    client.rst.code(id, code, c))

type Gone is Type:
  Gone{streams: List<&1, Stream>, active: U32, events: List<&1, ClientEvent>}

def client.goaway.cons(keep: Bool, s: Stream, id: U32, tail: Gone) -> Gone:
  match keep:
    case True{}:
      Gone{streams, +active, events} = tail
      Gone{Con{s, streams}, (active + 1 : U32), events}
    case False{}:
      Gone{streams, active, events} = tail
      Gone{streams, active, Con{Reset{id, 7}, events}}

def client.goaway.filter(xs: List<&1, Stream>, +last: U32) -> Gone:
  match xs:
    case Nil{}:
      Gone{Nil{}, 0, Nil{}}
    case Con{Stream{+id, send_window, recv_window, local_end, remote_end,
        head, headers, partial, body, outgoing}, rest}:
      client.goaway.cons(U32.is_le(id, last),
        Stream{id, send_window, recv_window, local_end, remote_end, head, headers, partial, body, outgoing},
        id, client.goaway.filter(rest, last))

def client.goaway.allowed(previous: Maybe<&2, U32>, last: U32) -> Bool:
  match previous:
    case None{}:
      True{}
    case Some{older}:
      U32.is_le(last, older)

def client.goaway.finish(g: Gone, +last: U32, code: U32, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  Gone{remaining, count, events} = g
  Control{next, active, frame_max, initial, max_streams, connection, recv,
    first, ack, continuation, previous} = control
  Ready{Client{input, remaining, encoder, decoder,
    Control{next, count, frame_max, initial, max_streams, connection, recv,
      first, ack, continuation, Some{last}}}, Nil{},
    Con{Shutdown{last, code}, events}}

def client.goaway.valid(valid: Bool, +last: U32, code: U32, c: Client) -> Reply:
  match valid:
    case False{}:
      client.fail(1, True{}, 0)
    case True{}:
      Client{input, streams, encoder, decoder, control} = c
      client.goaway.finish(client.goaway.filter(streams, last), last, code,
        input, encoder, decoder, control)

def client.goaway.body(+last: U32, +code: U32, c: Client) -> Reply:
  Client{input, streams, encoder, decoder, +control} = c
  Control{next, active, frame_max, initial, max_streams, connection, recv,
    first, ack, continuation, +previous} = control
  client.goaway.valid(client.goaway.allowed(previous, last), last, code,
    Client{input, streams, encoder, decoder, control})

def client.goaway(payload: Bytes.Bytes, c: Client) -> Reply:
  with_number(Reply, Bytes.get.u32be(payload, 0), b => raw =>
    with_number(Reply, Bytes.get.u32be(b, 4), rest => code =>
      client.goaway.body((raw .&. 2147483647 : U32), code, c)))

def client.complete.ready(+id: U32, headers: List<&2, Hpack.Field>, body: Bytes.Bytes,
    tail: List<&1, Stream>, input: Bytes.Bytes, encoder: Hpack.State,
    decoder: Hpack.State, control: Control, writes: List<&1, Bytes.Bytes>) -> Reply:
  Control{next, +active, frame_max, initial, max_streams, connection, recv,
    first, ack, continuation, goaway} = control
  Ready{Client{input, tail, encoder, decoder,
    Control{next, (active - 1 : U32), frame_max, initial, max_streams,
      connection, recv, first, ack, continuation, goaway}},
    writes, [Response{id, headers, body}]}

def client.complete.packet(m: Maybe<&1, Bytes.Bytes>, id: U32, headers: List<&2, Hpack.Field>,
    body: Bytes.Bytes, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  match m:
    case None{}:
      client.fail(1, True{}, 0)
    case Some{packet}:
      client.complete.ready(id, headers, body, tail, input, encoder, decoder, control, [packet])

def client.complete(s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  Stream{+id, send_window, recv_window, local_end, remote_end, head,
    headers, partial, body, outgoing} = s
  match local_end:
    case True{}:
      client.complete.ready(id, headers, body, tail, input, encoder, decoder, control, Nil{})
    case False{}:
      client.complete.packet(client.frame(encode(16384,
        Frame{3, 0, id, Bytes.set.u32be(Bytes.new(4), 0, 8)})),
        id, headers, body, tail, input, encoder, decoder, control)

def client.fragment.slice(b: Bytes.Bytes, +offset: U32, +pad: U32) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = b
  with_slice(Bytes.Bytes, Bytes.slice(Bytes.Bytes{len, buf}, offset, (len - offset - pad : U32)),
    whole => part => part)

def client.fragment.padded(padded: Bool, +fixed: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  match padded:
    case False{}:
      client.fragment.slice(b, fixed, 0)
    case True{}:
      with_number(Bytes.Bytes, Bytes.get(b, 0), rest => pad =>
        client.fragment.slice(rest, (fixed + 1 : U32), pad))

def client.fragment(+kind: U32, +flags: U32, b: Bytes.Bytes) -> Bytes.Bytes:
  client.fragment.padded(has(flags, 8),
    Bool.pick(U32, Bool.and(U32.is_eq(kind, 1), has(flags, 32)), 5, 0), b)

def client.fragments.join(first: Bytes.Bytes, second: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{len, buf} = first
  match len:
    case 0:
      second
    case +count:
      Bytes.append(Bytes.Bytes{count, buf}, second)

def client.headers.interim.status(s: String) -> Bool:
  match s:
    case SCon{Chr{49}, rest}:
      True{}
    case _:
      False{}

def client.headers.interim(xs: List<&2, Hpack.Field>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{Hpack.Field{name, value, mode}, rest}:
      Bool.and(String.eq(name, ":status"), client.headers.interim.status(value))

def client.headers.interim.valid(valid: Bool, id: U32, fields: List<&2, Hpack.Field>,
    s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  match valid:
    case False{}:
      client.fail(1, False{}, id)
    case True{}:
      Ready{Client{input, Con{s, tail}, encoder, decoder, control}, Nil{},
        [Response{id, fields, Bytes.new(0)}]}

def client.headers.fields.select(interim: Bool, fields: List<&2, Hpack.Field>, s: Stream,
    tail: List<&1, Stream>, input: Bytes.Bytes, encoder: Hpack.State,
    decoder: Hpack.State, control: Control) -> Reply:
  match interim:
    case True{}:
      Stream{+id, send_window, recv_window, local_end, +remote_end, head,
        headers, partial, body, outgoing} = s
      client.headers.interim.valid(Bool.not(remote_end), id, fields,
        Stream{id, send_window, recv_window, local_end, remote_end, head,
          headers, partial, body, outgoing}, tail, input, encoder, decoder, control)
    case False{}:
      Stream{id, send_window, recv_window, local_end, remote_end, head,
        headers, partial, body, outgoing} = s
      match remote_end:
        case True{}:
          client.complete(Stream{id, send_window, recv_window, local_end, True{}, True{},
            List.append(&2, Hpack.Field, headers, fields), partial, body, outgoing},
            tail, input, encoder, decoder, control)
        case False{}:
          client.ok(Client{input,
            Con{Stream{id, send_window, recv_window, local_end, False{}, True{},
              List.append(&2, Hpack.Field, headers, fields), partial, body, outgoing}, tail},
            encoder, decoder, control})

def client.headers.fields(+fields: List<&2, Hpack.Field>, s: Stream, tail: List<&1, Stream>,
    input: Bytes.Bytes, encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  client.headers.fields.select(client.headers.interim(fields),
    fields, s, tail, input, encoder, decoder, control)

def client.headers.decoded(m: Maybe<&1, Hpack.State & List<&2, Hpack.Field>>,
    s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, control: Control) -> Reply:
  match m:
    case None{}:
      client.fail(9, True{}, 0)
    case Some{(decoder, fields)}:
      client.headers.fields(fields, s, tail, input, encoder, decoder, control)

def client.headers.finish(end_headers: Bool, s: Stream, tail: List<&1, Stream>,
    input: Bytes.Bytes, encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  match end_headers:
    case False{}:
      Stream{+id, send_window, recv_window, local_end, remote_end, head,
        headers, partial, body, outgoing} = s
      Control{next, active, frame_max, initial, max_streams, connection, recv,
        first, ack, continuation, goaway} = control
      client.ok(Client{input,
        Con{Stream{id, send_window, recv_window, local_end, remote_end,
          head, headers, partial, body, outgoing}, tail},
        encoder, decoder,
        Control{next, active, frame_max, initial, max_streams, connection, recv,
          first, ack, Some{id}, goaway}})
    case True{}:
      Stream{id, send_window, recv_window, local_end, remote_end, head,
        headers, partial, body, outgoing} = s
      Control{next, active, frame_max, initial, max_streams, connection, recv,
        first, ack, continuation, goaway} = control
      client.headers.decoded(Hpack.decode(partial, decoder),
        Stream{id, send_window, recv_window, local_end, remote_end, head,
          headers, Bytes.new(0), body, outgoing}, tail, input, encoder,
        Control{next, active, frame_max, initial, max_streams, connection, recv,
          first, ack, None{}, goaway})

def client.headers.accumulate(end_headers: Bool, fragment: Bytes.Bytes,
    s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  Stream{id, send_window, recv_window, local_end, remote_end, head,
    headers, partial, body, outgoing} = s
  client.headers.finish(end_headers,
    Stream{id, send_window, recv_window, local_end, remote_end, head,
      headers, client.fragments.join(partial, fragment), body, outgoing},
    tail, input, encoder, decoder, control)

def client.headers.open.valid(valid: Bool, +id: U32, end_headers: Bool, end_stream: Bool,
    fragment: Bytes.Bytes, s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  match valid:
    case False{}:
      client.fail(5, False{}, id)
    case True{}:
      Stream{stream, send_window, recv_window, local_end, remote_end, head,
        headers, partial, body, outgoing} = s
      client.headers.accumulate(end_headers, fragment,
        Stream{stream, send_window, recv_window, local_end, end_stream, head,
          headers, partial, body, outgoing}, tail, input, encoder, decoder, control)

def client.headers.open(end_headers: Bool, +end_stream: Bool, fragment: Bytes.Bytes,
    s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  Stream{+id, send_window, recv_window, local_end, +remote_end, +head,
    headers, partial, body, outgoing} = s
  client.headers.open.valid(Bool.and(Bool.not(remote_end), Bool.or(Bool.not(head), end_stream)),
    id, end_headers, end_stream, fragment,
    Stream{id, send_window, recv_window, local_end, remote_end, head,
      headers, partial, body, outgoing}, tail, input, encoder, decoder, control)

def client.headers.receive(+id: U32, +flags: U32, payload: Bytes.Bytes, c: Client) -> Reply:
  Client{input, streams, encoder, decoder, control} = c
  +end_headers = has(flags, 4)
  +end_stream = has(flags, 1)
  fragment = client.fragment(1, flags, payload)
  client.streams.use(streams, id, s => tail =>
    client.headers.open(end_headers, end_stream, fragment, s, tail, input, encoder, decoder, control))

def client.continuation(+id: U32, +flags: U32, payload: Bytes.Bytes, c: Client) -> Reply:
  Client{input, streams, encoder, decoder, control} = c
  client.streams.use(streams, id, s => tail =>
    client.headers.accumulate(has(flags, 4), payload, s, tail, input, encoder, decoder, control))

def client.data.updates.end(end_stream: Bool, +count: U32, id: U32,
    connection: Bytes.Bytes) -> Maybe<&1, List<&1, Bytes.Bytes>>:
  match end_stream:
    case True{}:
      Some{[connection]}
    case False{}:
      Maybe.map(&1, Bytes.Bytes, List<&1, Bytes.Bytes>,
        stream => [connection, stream],
        client.frame(encode(16384, Frame{8, 0, id, Bytes.set.u32be(Bytes.new(4), 0, count)})))

def client.data.updates(+len: U32, end_stream: Bool, +id: U32) -> Maybe<&1, List<&1, Bytes.Bytes>>:
  match len:
    case 0:
      Some{Nil{}}
    case +count:
      Maybe.bind(&1, Bytes.Bytes, List<&1, Bytes.Bytes>,
        client.frame(encode(16384, Frame{8, 0, 0, Bytes.set.u32be(Bytes.new(4), 0, count)})), connection =>
          client.data.updates.end(end_stream, count, id, connection))

def client.data.content(end_stream: Bool, content: Bytes.Bytes, writes: List<&1, Bytes.Bytes>,
    s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  match end_stream:
    case False{}:
      Stream{id, send_window, recv_window, local_end, remote_end, head,
        headers, partial, body, outgoing} = s
      Ready{Client{input,
        Con{Stream{id, send_window, recv_window, local_end, False{}, head,
          headers, partial, Bytes.append(body, content), outgoing}, tail},
        encoder, decoder, control}, writes, Nil{}}
    case True{}:
      Stream{id, send_window, recv_window, local_end, remote_end, head,
        headers, partial, body, outgoing} = s
      client.after(client.complete(Stream{id, send_window, recv_window, local_end, True{}, head,
        headers, partial, Bytes.append(body, content), outgoing}, tail, input, encoder, decoder, control),
        next => extra => events =>
          Ready{next, List.append(&1, Bytes.Bytes, writes, extra), events})

def client.data.content.updated(m: Maybe<&1, List<&1, Bytes.Bytes>>, end_stream: Bool,
    content: Bytes.Bytes, s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  match m:
    case None{}:
      client.fail(1, True{}, 0)
    case Some{writes}:
      client.data.content(end_stream, content, writes, s, tail, input, encoder, decoder, control)

def client.data.stream.state(open: Bool, available: Bool, +id: U32, +len: U32,
    +end_stream: Bool, content: Bytes.Bytes, s: Stream, tail: List<&1, Stream>,
    input: Bytes.Bytes, encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  match open:
    case False{}:
      client.fail(1, False{}, id)
    case True{}:
      match available:
        case False{}:
          client.fail(3, False{}, id)
        case True{}:
          client.data.content.updated(client.data.updates(len, end_stream, id),
            end_stream, content, s, tail, input, encoder, decoder, control)

def client.data.stream(+len: U32, end_stream: Bool, content: Bytes.Bytes,
    s: Stream, tail: List<&1, Stream>, input: Bytes.Bytes,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  Stream{+id, send_window, +recv_window, local_end, +remote_end, +head,
    headers, partial, body, outgoing} = s
  client.data.stream.state(Bool.and(head, Bool.not(remote_end)), U32.is_le(len, recv_window),
    id, len, end_stream, content,
    Stream{id, send_window, recv_window, local_end, remote_end, head,
      headers, partial, body, outgoing}, tail, input, encoder, decoder, control)

def client.data.connection(valid: Bool, +id: U32, +flags: U32, +len: U32,
    payload: Bytes.Bytes, c: Client) -> Reply:
  match valid:
    case False{}:
      client.fail(3, True{}, 0)
    case True{}:
      Client{input, streams, encoder, decoder, control} = c
      content = client.fragment(0, flags, payload)
      client.streams.use(streams, id, s => tail =>
        client.data.stream(len, has(flags, 1), content, s, tail, input, encoder, decoder, control))

def client.data.receive(+id: U32, +flags: U32, payload: Bytes.Bytes, c: Client) -> Reply:
  Bytes.Bytes{+len, buf} = payload
  Client{input, streams, encoder, decoder, +control} = c
  Control{next, active, frame_max, initial, max_streams, connection, +recv_window,
    first, ack, continuation, goaway} = control
  client.data.connection(U32.is_le(len, recv_window), id, flags, len, Bytes.Bytes{len, buf},
    Client{input, streams, encoder, decoder, control})

def client.continuation.expected(m: Maybe<&2, U32>, +kind: U32, id: U32) -> Bool:
  match m:
    case None{}:
      U32.is_ne(kind, 9)
    case Some{expected}:
      Bool.and(U32.is_eq(kind, 9), U32.is_eq(expected, id))

def client.apply.allowed(c: Control, +kind: U32, flags: U32, id: U32) -> Bool:
  Control{next, active, frame_max, initial, max_streams, connection, recv,
    first, ack, continuation, goaway} = c
  Bool.and(Bool.or(Bool.not(first), Bool.and(U32.is_eq(kind, 4), U32.is_eq(flags, 0))),
    client.continuation.expected(continuation, kind, id))

def client.apply.frame(kind: U32, flags: U32, id: U32, payload: Bytes.Bytes, c: Client) -> Reply:
  match kind:
    case 0:
      client.data.receive(id, flags, payload, c)
    case 1:
      client.headers.receive(id, flags, payload, c)
    case 2:
      client.ok(c)
    case 3:
      client.rst(id, payload, c)
    case 4:
      client.settings(flags, payload, c)
    case 5:
      client.fail(1, True{}, 0)
    case 6:
      client.ping(flags, payload, c)
    case 7:
      client.goaway(payload, c)
    case 8:
      client.window.update(id, payload, c)
    case 9:
      client.continuation(id, flags, payload, c)
    case _:
      client.ok(c)

def client.apply.checked(valid: Bool, kind: U32, flags: U32, id: U32,
    payload: Bytes.Bytes, c: Client) -> Reply:
  match valid:
    case False{}:
      client.fail(1, True{}, 0)
    case True{}:
      client.apply.frame(kind, flags, id, payload, c)

def client.apply(f: Frame, c: Client) -> Reply:
  Frame{+kind, +flags, +id, payload} = f
  Client{input, streams, encoder, decoder, +control} = c
  client.apply.checked(client.apply.allowed(control, kind, flags, id), kind, flags, id,
    payload, Client{input, streams, encoder, decoder, control})

def client.receive.advance(c: Client,
    k: Decode -> List<&1, Stream> -> Hpack.State -> Hpack.State -> Control -> Reply) -> Reply:
  Client{input, streams, encoder, decoder, control} = c
  k(parse(16384, input), streams, encoder, decoder, control)

def client.receive.go(n: Nat, d: Decode, streams: List<&1, Stream>,
    encoder: Hpack.State, decoder: Hpack.State, control: Control,
    rev_writes: List<&1, Bytes.Bytes>, rev_events: List<&1, ClientEvent>) -> Reply:
  match n:
    case 0n:
      client.fail(1, True{}, 0)
    case 1n+p:
      match d:
        case Need{input}:
          Ready{Client{input, streams, encoder, decoder, control},
            List.reverse(&1, Bytes.Bytes, rev_writes), List.reverse(&1, ClientEvent, rev_events)}
        case Bad{error}:
          Failed{error}
        case Got{frame, rest}:
          client.after(client.apply(frame, Client{rest, streams, encoder, decoder, control}),
            next => writes => events =>
              client.receive.advance(next, more => streams2 => enc => dec => ctl =>
                client.receive.go(p, more, streams2, enc, dec, ctl,
                  List.append(&1, Bytes.Bytes, List.reverse(&1, Bytes.Bytes, writes), rev_writes),
                  List.append(&1, ClientEvent, List.reverse(&1, ClientEvent, events), rev_events))))

def client.receive.buffer(b: Bytes.Bytes, streams: List<&1, Stream>,
    encoder: Hpack.State, decoder: Hpack.State, control: Control) -> Reply:
  Bytes.Bytes{+len, buf} = b
  client.receive.go(1n+U32.to_nat(len), parse(16384, Bytes.Bytes{len, buf}),
    streams, encoder, decoder, control, Nil{}, Nil{})

def client.receive(c: Client, chunk: Bytes.Bytes) -> Reply:
  Client{input, streams, encoder, decoder, control} = c
  client.receive.buffer(Bytes.append(input, chunk), streams, encoder, decoder, control)
