import Base
import ./zlib.bend as Z
import ./native.bend as Native
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./encode.bend as Encode
import bend-kit-bits@0.4.0.2/bits.bend as Bits

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
      Native.libz.inflate(1000, b)

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

def stream.new(r: Result<&1, &1, U32 & String, Native.Decoder>) -> IO(Native.Decoder):
  match r:
    case Fail{(+code, why)}:
      IO.die(Native.Decoder, 1, "stream open: " ++ U32.show(code) ++ " " ++ why)
    case Done{d}:
      IO.pure(Native.Decoder, d)

def stream.bytes(r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(Bytes.Bytes):
  match r:
    case Fail{(+code, why)}:
      IO.die(Bytes.Bytes, 1, "stream feed: " ++ U32.show(code) ++ " " ++ why)
    case Done{b}:
      IO.pure(Bytes.Bytes, b)

type StreamState is Type:
  StreamState{dec: Native.Decoder, src: Bytes.Bytes, out: Bytes.Bytes}

def stream.closed(+want: String, out: Bytes.Bytes, r: Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "stream finish: " ++ U32.show(code) ++ " " ++ why)
    case Done{u}:
      ok(String.eq(Bytes.to_string(out), want), want)

def stream.done(+want: String, st: StreamState) -> IO(Unit):
  StreamState{d, src, out} = st
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Unit> <- Native.dec.finish(d)
    stream.closed(want, out, r)

def stream.feed.got(src: Bytes.Bytes, out: Bytes.Bytes, fed: Native.Decoder & Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(StreamState):
  (d, r) = fed
  do IO<StreamState>:
    piece : Bytes.Bytes <- stream.bytes(r)
    return StreamState{d, src, Bytes.append(out, piece)}

def stream.feed.pair(out: Bytes.Bytes, d: Native.Decoder, pair: Bytes.Bytes & Bytes.Bytes) -> IO(StreamState):
  (src, chunk) = pair
  do IO<StreamState>:
    fed : Native.Decoder & Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.dec.push(d, 1000, chunk)
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
    r : Result<&1, &1, U32 & String, Native.Decoder> <- Native.dec.new(kind)
    d : Native.Decoder <- stream.new(r)
    stream.test.with(one, len, want, StreamState{d, Bytes.Bytes{len, words}, Bytes.new(0)})

def encoder.got(+s: String, r: Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, code, why)
    case Done{b}:
      ok(String.eq(Bytes.to_string(b), s), "pure encoder, libz decoder")

def encoder.case(+s: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.libz.inflate.raw(200000, Z.deflate(Bytes.from_string(s)))
    encoder.got(s, r)

def encoder.noise(n: Nat, +seed: U32, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      encoder.noise(p, (seed * 1664525 + 1013904223 : U32), SCon{Chr{(97 + (U32.shrn(seed, 24n) .&. 15) : U32)}, acc})

def encoder.lazy.tokens(tokens: List<&2, Encode.Token>) -> IO(Unit):
  match tokens:
    case Nil{}:
      IO.die(Unit, 1, "lazy match missing")
    case Con{Encode.Copy{+ls, le, lv, ds, de, dv}, rest}:
      ok(U32.is_eq(ls, 260), "lazy matching")
    case Con{Encode.Lit{s}, rest}:
      IO.die(Unit, 1, "lazy match was emitted as literals")
def encoder.lazy(st: Z.Es) -> IO(Unit):
  Z.Es{z, tokens, i, n, more, len, dist} = st
  encoder.lazy.tokens(tokens)


def encoder.lazy.pending(st: Z.Es) -> IO(Unit):
  Z.Es{z, tokens, +i, +n, more, +len, +dist} = st
  do IO<Unit>:
    ok(Bool.and(U32.is_eq(i, 13), Bool.and(U32.is_eq(len, 6), U32.is_eq(dist, 8))), "deferred lazy match")
    encoder.lazy(Z.es.go(U32.to_nat(n), Z.Es{z, tokens, i, n, more, len, dist}))

def encoder.lazy.input(b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+n, src} = b
  encoder.lazy.pending(Z.es.go(11n, Z.Es{Z.Lz{src, Array.new(U32, 15n, 0), Array.new(U32, 15n, 0)}, Nil{}, 0, n, True{}, 0, 0}))

def encoder.tree.codes(m: Maybe<&2, List<&2, Bits.Encoding>>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "limited Huffman tree is invalid")
    case Some{codes}:
      IO.print("limited Huffman tree")

def encoder.tree(+ls: List<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    ok(U32.is_le(Encode.maxlen(ls, 0), 15), "Huffman depth limit")
    encoder.tree.codes(Bits.Huff.encode_lens(ls))

def encoder.runs.same(xs: List<&2, Encode.Run>, ys: List<&2, Encode.Run>) -> Bool:
  match xs:
    case Nil{}:
      match ys:
        case Nil{}:
          True{}
        case Con{h, t}:
          False{}
    case Con{Encode.Run{+s, +b, +v}, t}:
      match ys:
        case Nil{}:
          False{}
        case Con{Encode.Run{x, y, z}, rest}:
          Bool.and(Bool.and(U32.is_eq(s, x), Bool.and(U32.is_eq(b, y), U32.is_eq(v, z))), encoder.runs.same(t, rest))

def encoder.header.position(w: Bits.Writer, want: U32) -> IO(Unit):
  Bits.Writer{buf, dep, pos, msb} = w
  ok(U32.is_eq(U32.from_nat(pos), want), "dynamic header bit cost")

def encoder.header.codes(m: Maybe<&1, Array<U32>>, +h: Encode.Header) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "invalid code-length alphabet")
    case Some{a}:
      encoder.header.position(Encode.header.write(h, Bits.Writer.new(), a, 1), Encode.header.cost(h))

def encoder.header(+h: Encode.Header) -> IO(Unit):
  Encode.Header{+nl, +nd, +cl, order, rs} = h
  do IO<Unit>:
    ok(Bool.and(U32.is_eq(nl, 257), U32.is_eq(nd, 2)), "trim dynamic code lengths")
    ok(U32.is_le(Encode.maxlen(cl, 0), 7), "code-length alphabet depth")
    encoder.header.codes(Encode.codes(Bits.Huff.encode_lens(cl)), h)

def encoder.runs() -> IO(Unit):
  do IO<Unit>:
    ok(encoder.runs.same(Encode.runs(Z.rep(139n, 0, Z.rep(8n, 5, Z.rep(10n, 0, Z.rep(3n, 0, Nil{})))), 0, 0, Nil{}), [Encode.Run{18, 7, 127}, Encode.Run{0, 0, 0}, Encode.Run{5, 0, 0}, Encode.Run{16, 2, 3}, Encode.Run{5, 0, 0}, Encode.Run{18, 7, 2}]), "length run boundaries")
    ok(encoder.runs.same(Encode.runs([0, 0, 1, 1, 1, 2, 0, 0, 0], 0, 0, Nil{}), [Encode.Run{0, 0, 0}, Encode.Run{0, 0, 0}, Encode.Run{1, 0, 0}, Encode.Run{1, 0, 0}, Encode.Run{1, 0, 0}, Encode.Run{2, 0, 0}, Encode.Run{17, 3, 0}]), "short length runs")
    encoder.header(Encode.header.make(Z.rep(256n, 0, [1]), [1, 1, 0, 0]))

def encoder.symbol.scan(bs: List<&2, U32>, es: List<&2, U32>, +v: U32, +i: U32, +best: Z.Cx) -> Z.Cx:
  match bs:
    case Nil{}:
      best
    case Con{+b, bt}:
      match es:
        case Nil{}:
          best
        case Con{+e, et}:
          encoder.symbol.scan(bt, et, v, (i + 1 : U32), Bool.pick(Z.Cx, U32.is_le(b, v), Z.Cx{i, b, e}, best))

def encoder.symbol.same(a: Z.Cx, b: Z.Cx) -> Bool:
  Z.Cx{i, base, extra} = a
  Z.Cx{j, other, bits} = b
  Bool.and(U32.is_eq(i, j), Bool.and(U32.is_eq(base, other), U32.is_eq(extra, bits)))

def encoder.symbol.all(~map: @+v:U32 -> Z.Cx, fuel: Nat, +v: U32, +bs: List<&2, U32>, +es: List<&2, U32>, good: Bool) -> Bool:
  match fuel:
    case 0n:
      good
    case 1n+p:
      encoder.symbol.all(~map, p, (v + 1 : U32), bs, es, Bool.and(good, encoder.symbol.same(map(v), encoder.symbol.scan(bs, es, v, 0, Z.Cx{0, 0, 0}))))

def encoder.check() -> IO(Unit):
  do IO<Unit>:
    encoder.runs()
    ok(encoder.symbol.all(~Z.cx.length, 256n, 3, Z.len.base(), Z.len.extra(), True{}), "every length symbol boundary")
    ok(encoder.symbol.all(~Z.cx.distance, 32768n, 1, Z.dist.base(), Z.dist.extra(), True{}), "every distance symbol boundary")
    encoder.case("")
    encoder.case(String.repeat("a", 600n))
    encoder.case(String.repeat("abcde abcdf ghijkl mnopqr stuvwx yz. ", 2200n))
    encoder.case(String.repeat("a", 32767n))
    encoder.case(String.repeat("a", 32768n))
    encoder.case(String.repeat("a", 32769n))
    encoder.case(encoder.noise(70000n, 123456789, ""))
    encoder.lazy.input(Bytes.from_string("Xabc!abcdef?Xabcdef"))
    encoder.tree(Encode.tree.lengths(21n, [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181, 6765, 10946]))


def copy.seed(k: Nat, a: Array<U32>, +i: U32, +seed: U32) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+p:
      copy.seed(p, Array.set(U32, a, i, seed), (i + 1 : U32), (seed * 1664525 + 1013904223 : U32))

def copy.words(k: Nat, ar: Array<U32> & U32, br: Array<U32> & U32, +i: U32, good: Bool) -> Bool:
  match k:
    case 0n:
      good
    case 1n+p:
      (a, x) = ar
      (b, y) = br
      copy.words(p, Array.get(U32, a, (i + 1 : U32)), Array.get(U32, b, (i + 1 : U32)), (i + 1 : U32), Bool.and(good, U32.is_eq(x, y)))

def copy.same(a: Z.Out, b: Z.Out) -> Bool:
  Z.Out{ab, ad, an} = a
  Z.Out{bb, bd, bn} = b
  copy.words(256n, Array.get(U32, ab, 0), Array.get(U32, bb, 0), 0, Bool.and(U32.is_eq(ad, bd), U32.is_eq(an, bn)))

def copy.case.bufs(+len: U32, +d: U32, +n: U32, pair: Array<U32> & Array<U32>) -> Bool:
  (a, b) = pair
  copy.same(Z.cp.match(U32.is_le(len, d), len, d, Z.Out{a, 8, n}), Z.cp.go(U32.to_nat(len), d, Z.Out{b, 8, n}))

def copy.case(+len: U32, +d: U32, +n: U32) -> Bool:
  copy.case.bufs(len, d, n, Array.clone(U32, copy.seed(256n, Array.new(U32, 8n, 0), 0, 123456789)))

def copy.distances(ds: List<&2, U32>, +len: U32, +n: U32, good: Bool) -> Bool:
  match ds:
    case Nil{}:
      good
    case Con{d, rest}:
      copy.distances(rest, len, n, Bool.and(good, copy.case(len, d, n)))

def copy.lengths(k: Nat, +len: U32, +n: U32, good: Bool) -> Bool:
  match k:
    case 0n:
      good
    case 1n+p:
      copy.lengths(p, (len + 1 : U32), n, copy.distances([1, 2, 3, 4, 5, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128, 255, 256, 259, 260, U32.max(1, len), U32.max(1, (len - U32.min(len, 1) : U32)), (len + 1 : U32)], len, n, good))

def copy.check() -> IO(Unit):
  do IO<Unit>:
    ok(Bool.and(copy.lengths(259n, 0, 260, True{}), Bool.and(copy.lengths(259n, 0, 261, True{}), Bool.and(copy.lengths(259n, 0, 262, True{}), copy.lengths(259n, 0, 263, True{})))), "match copies, alignments, overlap, and untouched bytes")
    ok(Bool.and(copy.case(258, 260, 766), Bool.and(copy.case(257, 259, 767), Bool.and(copy.case(256, 258, 768), copy.case(255, 257, 769)))), "match copies at the buffer boundary")

def main() -> IO(Unit):
  do IO<Unit>:
    show(Z.inflate(raw()))
    show(Z.inflate(Bytes.from_string("x")))
    show(Z.gunzip(Z.gzip(Bytes.from_string("pure round trip"))))
    encoder.check()
    copy.check()
    r : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.zstd(1000, frames())
    got("hello zstd", r)
    e : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.zstd(5, frames())
    big(e)
    g : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.libz.inflate(1000, members())
    got("hello gzip", g)
    c : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.libz.gzip(Bytes.from_string("round trip"))
    t : Result<&1, &1, U32 & String, Bytes.Bytes> <- gz.back(c)
    got("round trip", t)
    p : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.libz.inflate(1000, Z.gzip(Bytes.from_string("pure gzip, libz gunzip")))
    got("pure gzip, libz gunzip", p)
    b : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.brotli(1000, brotli())
    got("hello brotli", b)
    m : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.brotli(5, brotli())
    big(m)
    stream.test(0, "hello gzip", True{}, members())
    stream.test(0, "hello gzip", False{}, members())
    stream.test(0, "hello raw", True{}, raw())
    stream.test(0, "hello raw", False{}, raw())
    stream.test(0, "hello raw", True{}, wrapped())
    stream.test(0, "hello raw", False{}, wrapped())
    stream.test(0, "A", True{}, raw.like_header())
    one : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.libz.inflate.raw(1000, raw())
    got("hello raw", one)
    twice : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.libz.inflate.raw(1000, Bytes.append(raw(), raw()))
    malformed(twice)
    cut : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.libz.inflate.raw(1000, Bytes.snd(Bytes.slice(raw(), 0, 10)))
    malformed(cut)
    bounded : Result<&1, &1, U32 & String, Bytes.Bytes> <- Native.libz.inflate.raw(5, raw())
    big(bounded)
    stream.test(0, "A", False{}, raw.like_header())
    stream.test(1, "hello brotli", True{}, brotli())
    stream.test(1, "hello brotli", False{}, brotli())
    stream.test(2, "hello zstd", True{}, frames())
    stream.test(2, "hello zstd", False{}, frames())
