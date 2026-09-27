import Base
import ./zlib.bend as Z
import ../bytes/bytes.bend as Bytes

def show(m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("none")
    case Some{s}:
      IO.print(s)

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

def dec(~eff: U32 -> U32 -> Array<U32> -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>), +max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+len, buf} = b
  eff(max, len, buf)

def gz(b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+len, buf} = b
  Z.gzip.words(len, buf)

def gz.back(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, U32 & Array<U32>>, Fail{e})
    case Done{(+len, buf)}:
      Z.inflate.words(1000, len, buf)

def ok(ok: Bool, +s: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(s)
    case False{}:
      IO.die(Unit, 1, "decoder gave " ++ s)

def got(+want: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+len, buf)}:
      +s = Bytes.to_string(Bytes.Bytes{len, buf})
      ok(String.eq(s, want), s)

def code(ok: Bool, +why: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(why)
    case False{}:
      IO.die(Unit, 1, "decoder failed the wrong way: " ++ why)

def big(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+c, why)}:
      code(U32.is_eq(c, 27), why)
    case Done{p}:
      IO.die(Unit, 1, "decoder passed max")


def stream.byte.of(h: Char) -> Bytes.Bytes:
  Bytes.from_string(SCon{h, SNil{}})

def stream.text(+out: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(String):
  match r:
    case Fail{(+code, why)}:
      IO.die(String, 1, "decoder failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+len, buf)}:
      IO.pure(String, out ++ Bytes.to_string(Bytes.Bytes{len, buf}))

def stream.eq(+all: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+len, buf)}:
      +ref = Bytes.to_string(Bytes.Bytes{len, buf})
      ok(String.eq(all, ref), all)

@unsafe def stream.inflate.after(pr: File & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(String):
  match pr:
    case (d2, mid):
      do IO<String>:
        acc : String <- stream.text("", mid)
        fin : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.inflate.decoder.finish(d2)
        all : String <- stream.text(acc, fin)
        return all

@unsafe def stream.inflate.run(dec: File, body: Bytes.Bytes) -> IO(String):
  Bytes.Bytes{+len, buf} = body
  do IO<String>:
    pr : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.inflate.decoder.feed(dec, len, buf)
    stream.inflate.after(pr)

@unsafe def stream.inflate.go(dec: File, s: String, +out: String) -> IO(String):
  match s:
    case SNil{}:
      do IO<String>:
        fin : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.inflate.decoder.finish(dec)
        all : String <- stream.text(out, fin)
        return all
    case SCon{h, t}:
      stream.inflate.one(dec, h, t, out)

@unsafe def stream.inflate.one(dec: File, h: Char, t: String, +out: String) -> IO(String):
  stream.inflate.one.b(dec, stream.byte.of(h), t, out)

@unsafe def stream.inflate.one.b(dec: File, b: Bytes.Bytes, t: String, +out: String) -> IO(String):
  Bytes.Bytes{+len, buf} = b
  do IO<String>:
    pr : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.inflate.decoder.feed(dec, len, buf)
    stream.inflate.step(pr, t, out)

@unsafe def stream.inflate.step(pr: File & Result<&1, &1, U32 & String, U32 & Array<U32>>, t: String, +out: String) -> IO(String):
  match pr:
    case (d2, mid):
      do IO<String>:
        acc2 : String <- stream.text(out, mid)
        stream.inflate.go(d2, t, acc2)

@unsafe def stream.inflate.check(+want: String, +max: U32, +body: Bytes.Bytes, +all: String) -> IO(Unit):
  Bytes.Bytes{+len, buf} = body
  do IO<Unit>:
    ref : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.inflate.words(max, len, buf)
    stream.inflate.check.ref(all, want, ref)

@unsafe def stream.inflate.check.ref(+all: String, +want: String, +ref: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match ref:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+len, buf)}:
      +rs = Bytes.to_string(Bytes.Bytes{len, buf})
      do IO<Unit>:
        ok(String.eq(all, rs), all)
        ok(String.eq(rs, want), rs)

@unsafe def stream.inflate.whole(+max: U32, body: Bytes.Bytes, +want: String) -> IO(Unit):
  do IO<Unit>:
    n : Result<&1, &1, U32 & String, File> <- Z.inflate.decoder.new(max)
    stream.inflate.whole.new(n, want, max, body)

@unsafe def stream.inflate.whole.new(n: Result<&1, &1, U32 & String, File>, +want: String, +max: U32, +body: Bytes.Bytes) -> IO(Unit):
  match n:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder new failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{dec}:
      do IO<Unit>:
        all : String <- stream.inflate.run(dec, body)
        stream.inflate.check(want, max, body, all)

@unsafe def stream.inflate.piece(+max: U32, body: Bytes.Bytes, +want: String) -> IO(Unit):
  do IO<Unit>:
    n : Result<&1, &1, U32 & String, File> <- Z.inflate.decoder.new(max)
    stream.inflate.piece.new(n, want, max, body)

@unsafe def stream.inflate.piece.new(n: Result<&1, &1, U32 & String, File>, +want: String, +max: U32, +body: Bytes.Bytes) -> IO(Unit):
  match n:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder new failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{dec}:
      do IO<Unit>:
        all : String <- stream.inflate.go(dec, Bytes.to_string(body), "")
        stream.inflate.check(want, max, body, all)

def stream.inflate.test(+max: U32, body: Bytes.Bytes, +want: String, whole: Bool) -> IO(Unit):
  match whole:
    case True{}:
      stream.inflate.whole(max, body, want)
    case False{}:
      stream.inflate.piece(max, body, want)

@unsafe def stream.brotli.after(pr: File & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(String):
  match pr:
    case (d2, mid):
      do IO<String>:
        acc : String <- stream.text("", mid)
        fin : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.brotli.decoder.finish(d2)
        all : String <- stream.text(acc, fin)
        return all

@unsafe def stream.brotli.run(dec: File, body: Bytes.Bytes) -> IO(String):
  Bytes.Bytes{+len, buf} = body
  do IO<String>:
    pr : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.brotli.decoder.feed(dec, len, buf)
    stream.brotli.after(pr)

@unsafe def stream.brotli.go(dec: File, s: String, +out: String) -> IO(String):
  match s:
    case SNil{}:
      do IO<String>:
        fin : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.brotli.decoder.finish(dec)
        all : String <- stream.text(out, fin)
        return all
    case SCon{h, t}:
      stream.brotli.one(dec, h, t, out)

@unsafe def stream.brotli.one(dec: File, h: Char, t: String, +out: String) -> IO(String):
  stream.brotli.one.b(dec, stream.byte.of(h), t, out)

@unsafe def stream.brotli.one.b(dec: File, b: Bytes.Bytes, t: String, +out: String) -> IO(String):
  Bytes.Bytes{+len, buf} = b
  do IO<String>:
    pr : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.brotli.decoder.feed(dec, len, buf)
    stream.brotli.step(pr, t, out)

@unsafe def stream.brotli.step(pr: File & Result<&1, &1, U32 & String, U32 & Array<U32>>, t: String, +out: String) -> IO(String):
  match pr:
    case (d2, mid):
      do IO<String>:
        acc2 : String <- stream.text(out, mid)
        stream.brotli.go(d2, t, acc2)

@unsafe def stream.brotli.check(+want: String, +max: U32, +body: Bytes.Bytes, +all: String) -> IO(Unit):
  Bytes.Bytes{+len, buf} = body
  do IO<Unit>:
    ref : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.brotli.words(max, len, buf)
    stream.brotli.check.ref(all, want, ref)

@unsafe def stream.brotli.check.ref(+all: String, +want: String, +ref: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match ref:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+len, buf)}:
      +rs = Bytes.to_string(Bytes.Bytes{len, buf})
      do IO<Unit>:
        ok(String.eq(all, rs), all)
        ok(String.eq(rs, want), rs)

@unsafe def stream.brotli.whole(+max: U32, body: Bytes.Bytes, +want: String) -> IO(Unit):
  do IO<Unit>:
    n : Result<&1, &1, U32 & String, File> <- Z.brotli.decoder.new(max)
    stream.brotli.whole.new(n, want, max, body)

@unsafe def stream.brotli.whole.new(n: Result<&1, &1, U32 & String, File>, +want: String, +max: U32, +body: Bytes.Bytes) -> IO(Unit):
  match n:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder new failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{dec}:
      do IO<Unit>:
        all : String <- stream.brotli.run(dec, body)
        stream.brotli.check(want, max, body, all)

@unsafe def stream.brotli.piece(+max: U32, body: Bytes.Bytes, +want: String) -> IO(Unit):
  do IO<Unit>:
    n : Result<&1, &1, U32 & String, File> <- Z.brotli.decoder.new(max)
    stream.brotli.piece.new(n, want, max, body)

@unsafe def stream.brotli.piece.new(n: Result<&1, &1, U32 & String, File>, +want: String, +max: U32, +body: Bytes.Bytes) -> IO(Unit):
  match n:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder new failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{dec}:
      do IO<Unit>:
        all : String <- stream.brotli.go(dec, Bytes.to_string(body), "")
        stream.brotli.check(want, max, body, all)

def stream.brotli.test(+max: U32, body: Bytes.Bytes, +want: String, whole: Bool) -> IO(Unit):
  match whole:
    case True{}:
      stream.brotli.whole(max, body, want)
    case False{}:
      stream.brotli.piece(max, body, want)

@unsafe def stream.zstd.after(pr: File & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(String):
  match pr:
    case (d2, mid):
      do IO<String>:
        acc : String <- stream.text("", mid)
        fin : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.zstd.decoder.finish(d2)
        all : String <- stream.text(acc, fin)
        return all

@unsafe def stream.zstd.run(dec: File, body: Bytes.Bytes) -> IO(String):
  Bytes.Bytes{+len, buf} = body
  do IO<String>:
    pr : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.zstd.decoder.feed(dec, len, buf)
    stream.zstd.after(pr)

@unsafe def stream.zstd.go(dec: File, s: String, +out: String) -> IO(String):
  match s:
    case SNil{}:
      do IO<String>:
        fin : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.zstd.decoder.finish(dec)
        all : String <- stream.text(out, fin)
        return all
    case SCon{h, t}:
      stream.zstd.one(dec, h, t, out)

@unsafe def stream.zstd.one(dec: File, h: Char, t: String, +out: String) -> IO(String):
  stream.zstd.one.b(dec, stream.byte.of(h), t, out)

@unsafe def stream.zstd.one.b(dec: File, b: Bytes.Bytes, t: String, +out: String) -> IO(String):
  Bytes.Bytes{+len, buf} = b
  do IO<String>:
    pr : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.zstd.decoder.feed(dec, len, buf)
    stream.zstd.step(pr, t, out)

@unsafe def stream.zstd.step(pr: File & Result<&1, &1, U32 & String, U32 & Array<U32>>, t: String, +out: String) -> IO(String):
  match pr:
    case (d2, mid):
      do IO<String>:
        acc2 : String <- stream.text(out, mid)
        stream.zstd.go(d2, t, acc2)

@unsafe def stream.zstd.check(+want: String, +max: U32, +body: Bytes.Bytes, +all: String) -> IO(Unit):
  Bytes.Bytes{+len, buf} = body
  do IO<Unit>:
    ref : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.zstd.words(max, len, buf)
    stream.zstd.check.ref(all, want, ref)

@unsafe def stream.zstd.check.ref(+all: String, +want: String, +ref: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match ref:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+len, buf)}:
      +rs = Bytes.to_string(Bytes.Bytes{len, buf})
      do IO<Unit>:
        ok(String.eq(all, rs), all)
        ok(String.eq(rs, want), rs)

@unsafe def stream.zstd.whole(+max: U32, body: Bytes.Bytes, +want: String) -> IO(Unit):
  do IO<Unit>:
    n : Result<&1, &1, U32 & String, File> <- Z.zstd.decoder.new(max)
    stream.zstd.whole.new(n, want, max, body)

@unsafe def stream.zstd.whole.new(n: Result<&1, &1, U32 & String, File>, +want: String, +max: U32, +body: Bytes.Bytes) -> IO(Unit):
  match n:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder new failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{dec}:
      do IO<Unit>:
        all : String <- stream.zstd.run(dec, body)
        stream.zstd.check(want, max, body, all)

@unsafe def stream.zstd.piece(+max: U32, body: Bytes.Bytes, +want: String) -> IO(Unit):
  do IO<Unit>:
    n : Result<&1, &1, U32 & String, File> <- Z.zstd.decoder.new(max)
    stream.zstd.piece.new(n, want, max, body)

@unsafe def stream.zstd.piece.new(n: Result<&1, &1, U32 & String, File>, +want: String, +max: U32, +body: Bytes.Bytes) -> IO(Unit):
  match n:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "decoder new failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{dec}:
      do IO<Unit>:
        all : String <- stream.zstd.go(dec, Bytes.to_string(body), "")
        stream.zstd.check(want, max, body, all)

def stream.zstd.test(+max: U32, body: Bytes.Bytes, +want: String, whole: Bool) -> IO(Unit):
  match whole:
    case True{}:
      stream.zstd.whole(max, body, want)
    case False{}:
      stream.zstd.piece(max, body, want)

def main() -> IO(Unit):
  do IO<Unit>:
    show(Z.inflate(SCon{Chr{203}, SCon{Chr{72}, SCon{Chr{205}, SCon{Chr{201}, SCon{Chr{201}, SCon{Chr{7}, SCon{Chr{0}, SNil{}}}}}}}}))
    show(Z.inflate("x"))
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- dec(~Z.zstd.words, 1000, frames())
    got("hello zstd", r)
    e : Result<&1, &1, U32 & String, U32 & Array<U32>> <- dec(~Z.zstd.words, 5, frames())
    big(e)
    g : Result<&1, &1, U32 & String, U32 & Array<U32>> <- dec(~Z.inflate.words, 1000, members())
    got("hello gzip", g)
    c : Result<&1, &1, U32 & String, U32 & Array<U32>> <- gz(Bytes.from_string("round trip"))
    t : Result<&1, &1, U32 & String, U32 & Array<U32>> <- gz.back(c)
    got("round trip", t)
    b : Result<&1, &1, U32 & String, U32 & Array<U32>> <- dec(~Z.brotli.words, 1000, brotli())
    got("hello brotli", b)
    m : Result<&1, &1, U32 & String, U32 & Array<U32>> <- dec(~Z.brotli.words, 5, brotli())
    big(m)
    stream.inflate.test(1000, members(), "hello gzip", True{})
    stream.inflate.test(1000, members(), "hello gzip", False{})
    stream.brotli.test(1000, brotli(), "hello brotli", True{})
    stream.brotli.test(1000, brotli(), "hello brotli", False{})
    stream.zstd.test(1000, frames(), "hello zstd", True{})
    stream.zstd.test(1000, frames(), "hello zstd", False{})
