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
