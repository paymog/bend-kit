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

def zstd.run(+max: U32, b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+len, buf} = b
  Z.zstd.words(max, len, buf)

def zstd.ok(ok: Bool, +s: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(s)
    case False{}:
      IO.die(Unit, 1, "zstd gave " ++ s)

def zstd.got(+want: String, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      IO.die(Unit, 1, "zstd failed: " ++ U32.show(code) ++ " " ++ why)
    case Done{(+len, buf)}:
      +s = Bytes.to_string(Bytes.Bytes{len, buf})
      zstd.ok(String.eq(s, want), s)

def zstd.code(ok: Bool, +why: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(why)
    case False{}:
      IO.die(Unit, 1, "zstd failed the wrong way: " ++ why)

def zstd.big(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{(+code, why)}:
      zstd.code(U32.is_eq(code, 27), why)
    case Done{p}:
      IO.die(Unit, 1, "zstd passed max")

def main() -> IO(Unit):
  do IO<Unit>:
    show(Z.inflate(SCon{Chr{203}, SCon{Chr{72}, SCon{Chr{205}, SCon{Chr{201}, SCon{Chr{201}, SCon{Chr{7}, SCon{Chr{0}, SNil{}}}}}}}}))
    show(Z.inflate("x"))
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- zstd.run(1000, frames())
    zstd.got("hello zstd", r)
    e : Result<&1, &1, U32 & String, U32 & Array<U32>> <- zstd.run(5, frames())
    zstd.big(e)
