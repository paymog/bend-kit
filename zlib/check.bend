import Base
import ./zlib.bend as Z
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def show(m: Maybe<&1, Bytes.Bytes>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{b}:
      IO.print(Bytes.to_string(b))

def str.of(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{x, t}:
      SCon{Chr{x}, str.of(t)}

# "hello " and "zstd" as two frames with a skippable frame between them.
def frames() -> Bytes.Bytes:
  Bytes.from_string(str.of([40, 181, 47, 253, 32, 6, 49, 0, 0, 104, 101, 108, 108, 111, 32, 80, 42, 77, 24, 2, 0, 0, 0, 9, 9, 40, 181, 47, 253, 32, 4, 33, 0, 0, 122, 115, 116, 100]))

# "hello " and "gzip" as two gzip members.
def members() -> Bytes.Bytes:
  Bytes.from_string(str.of([31, 139, 8, 0, 0, 0, 0, 0, 0, 255, 203, 72, 205, 201, 201, 87, 0, 0, 246, 249, 129, 237, 6, 0, 0, 0, 31, 139, 8, 0, 0, 0, 0, 0, 0, 255, 75, 175, 202, 44, 0, 0, 242, 92, 233, 58, 4, 0, 0, 0]))

# "hello brotli".
def brotli() -> Bytes.Bytes:
  Bytes.from_string(str.of([139, 5, 128, 104, 101, 108, 108, 111, 32, 98, 114, 111, 116, 108, 105, 3]))

# "hello raw", with and without an RFC 1950 zlib wrapper.
def raw() -> Bytes.Bytes:
  Bytes.from_string(str.of([203, 72, 205, 201, 201, 87, 40, 74, 44, 7, 0]))

def wrapped() -> Bytes.Bytes:
  Bytes.from_string(str.of([120, 156, 203, 72, 205, 201, 201, 87, 40, 74, 44, 7, 0, 17, 143, 3, 127]))

# A raw stored block begins with 0x78 but has no valid zlib header.
def raw.like_header() -> Bytes.Bytes:
  Bytes.from_string(str.of([120, 0, 0, 255, 255, 1, 1, 0, 254, 255, 65]))

def gz.back(r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(Result<&1, &1, U32 & String, Bytes.Bytes>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, Bytes.Bytes>, Fail{e})
    case Done{b}:
      Z.libz.inflate(1000, b)

def ok(ok: Bool, +s: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(s)
    case False{}:
      IO.die(Unit, 1, "decoder gave " ++ s)

def got(+want: String, r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{b}:
      +s = Bytes.to_string(b)
      ok(String.eq(s, want), s)

def code(ok: Bool, +why: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(why)
    case False{}:
      IO.die(Unit, 1, "decoder failed the wrong way: " ++ why)

def big(r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{(+c, why)}:
      code(U32.is_eq(c, 27), why)
    case Done{p}:
      IO.die(Unit, 1, "decoder passed max")

def malformed(r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{(+c, why)}:
      code(U32.is_eq(c, 22), why)
    case Done{p}:
      IO.die(Unit, 1, "raw decoder accepted trailing or cut input")

def stream.new(r: Result<&1, &1, U32 & String, Z.Decoder>) -> IO(Z.Decoder):
  match r:
    case Fail{(+code, why)}:
      IO.die(Z.Decoder, 1, "stream open: " ++ U32.show(code) ++ " " ++ why)
    case Done{d}:
      IO.pure(Z.Decoder, d)

def stream.bytes(r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(Bytes.Bytes):
  match r:
    case Fail{(+code, why)}:
      IO.die(Bytes.Bytes, 1, "stream feed: " ++ U32.show(code) ++ " " ++ why)
    case Done{b}:
      IO.pure(Bytes.Bytes, b)

type StreamState is Type:
  StreamState{dec: Z.Decoder, src: Bytes.Bytes, out: Bytes.Bytes}

def stream.closed(+want: String, out: Bytes.Bytes, r: Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "stream finish: " ++ U32.show(code) ++ " " ++ why)
    case Done{u}:
      ok(String.eq(Bytes.to_string(out), want), want)

def stream.done(+want: String, st: StreamState) -> IO(Unit):
  StreamState{d, src, out} = st
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Unit> <- Z.dec.finish(d)
    stream.closed(want, out, r)

def stream.feed.got(src: Bytes.Bytes, out: Bytes.Bytes, fed: Z.Decoder & Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(StreamState):
  (d, r) = fed
  do IO<StreamState>:
    piece : Bytes.Bytes <- stream.bytes(r)
    return StreamState{d, src, Bytes.append(out, piece)}

def stream.feed.pair(out: Bytes.Bytes, d: Z.Decoder, pair: Bytes.Bytes & Bytes.Bytes) -> IO(StreamState):
  (src, chunk) = pair
  do IO<StreamState>:
    fed : Z.Decoder & Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.dec.push(d, 1000, chunk)
    stream.feed.got(src, out, fed)

def stream.step(+at: U32, +step: U32, st: StreamState) -> IO(StreamState):
  StreamState{d, src, out} = st
  stream.feed.pair(out, d, Bytes.slice(src, at, step))

# Feed the same compressed data in one piece, or one octet at a time.
def stream.parts(n: Nat, +step: U32, +at: U32, +want: String, st: StreamState) -> IO(Unit):
  match n:
    case 0n:
      stream.done(want, st)
    case 1n+k:
      do IO<Unit>:
        next : StreamState <- stream.step(at, step, st)
        stream.parts(k, step, (at + step : U32), want, next)

def stream.test.with(one: Bool, +len: U32, +want: String, st: StreamState) -> IO(Unit):
  match one:
    case True{}:
      stream.parts(U32.to_nat(len), 1, 0, want, st)
    case False{}:
      stream.parts(1n, len, 0, want, st)

def stream.test(+kind: U32, +want: String, +one: Bool, src: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, words} = src
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Z.Decoder> <- Z.dec.new(kind)
    d : Z.Decoder <- stream.new(r)
    stream.test.with(one, len, want, StreamState{d, Bytes.Bytes{len, words}, Bytes.new(0)})

def main() -> IO(Unit):
  do IO<Unit>:
    show(Z.inflate(raw()))
    show(Z.inflate(Bytes.from_string("x")))
    show(Z.gunzip(Z.gzip(Bytes.from_string("pure round trip"))))
    r : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.zstd(1000, frames())
    got("hello zstd", r)
    e : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.zstd(5, frames())
    big(e)
    g : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.libz.inflate(1000, members())
    got("hello gzip", g)
    c : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.libz.gzip(Bytes.from_string("round trip"))
    t : Result<&1, &1, U32 & String, Bytes.Bytes> <- gz.back(c)
    got("round trip", t)
    p : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.libz.inflate(1000, Z.gzip(Bytes.from_string("pure gzip, libz gunzip")))
    got("pure gzip, libz gunzip", p)
    b : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.brotli(1000, brotli())
    got("hello brotli", b)
    m : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.brotli(5, brotli())
    big(m)
    stream.test(0, "hello gzip", True{}, members())
    stream.test(0, "hello gzip", False{}, members())
    stream.test(0, "hello raw", True{}, raw())
    stream.test(0, "hello raw", False{}, raw())
    stream.test(0, "hello raw", True{}, wrapped())
    stream.test(0, "hello raw", False{}, wrapped())
    stream.test(0, "A", True{}, raw.like_header())
    one : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.libz.inflate.raw(1000, raw())
    got("hello raw", one)
    twice : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.libz.inflate.raw(1000, Bytes.append(raw(), raw()))
    malformed(twice)
    cut : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.libz.inflate.raw(1000, Bytes.snd(Bytes.slice(raw(), 0, 10)))
    malformed(cut)
    bounded : Result<&1, &1, U32 & String, Bytes.Bytes> <- Z.libz.inflate.raw(5, raw())
    big(bounded)
    stream.test(0, "A", False{}, raw.like_header())
    stream.test(1, "hello brotli", True{}, brotli())
    stream.test(1, "hello brotli", False{}, brotli())
    stream.test(2, "hello zstd", True{}, frames())
    stream.test(2, "hello zstd", False{}, frames())
