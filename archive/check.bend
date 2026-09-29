import Base
import ./archive.bend as Archive
import ../bytes/bytes.bend as Bytes

def octets(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{h, t}:
      SCon{Chr{h}, octets(t)}

# Created with Python zipfile: one stored member and one DEFLATE member.
def mixed() -> Bytes.Bytes:
  Bytes.from_string(octets([80, 75, 3, 4, 20, 0, 0, 0, 0, 0, 232, 172, 60, 93, 11, 249, 67, 86, 6, 0, 0, 0, 6, 0, 0, 0, 5, 0, 0, 0, 97, 46, 116, 120, 116, 115, 116, 111, 114, 101, 100, 80, 75, 3, 4, 20, 0, 0, 0, 8, 0, 232, 172, 60, 93, 8, 223, 233, 71, 18, 0, 0, 0, 39, 0, 0, 0, 5, 0, 0, 0, 98, 46, 116, 120, 116, 75, 73, 77, 203, 73, 44, 73, 77, 81, 72, 202, 79, 169, 76, 193, 201, 1, 0, 80, 75, 1, 2, 20, 3, 20, 0, 0, 0, 0, 0, 232, 172, 60, 93, 11, 249, 67, 86, 6, 0, 0, 0, 6, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 1, 0, 0, 0, 0, 97, 46, 116, 120, 116, 80, 75, 1, 2, 20, 3, 20, 0, 0, 0, 8, 0, 232, 172, 60, 93, 8, 223, 233, 71, 18, 0, 0, 0, 39, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 1, 41, 0, 0, 0, 98, 46, 116, 120, 116, 80, 75, 5, 6, 0, 0, 0, 0, 2, 0, 2, 0, 102, 0, 0, 0, 94, 0, 0, 0, 0, 0]))

def empty() -> Bytes.Bytes:
  Bytes.from_string(octets([80, 75, 5, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))

def contents(xs: List<&1, Archive.Entry>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{e, t}:
      Archive.Entry{name, data, method, crc} = e
      Bytes.to_string(name) ++ "=" ++ Bytes.to_string(data) ++ ";" ++ contents(t)

def expect(name: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def good(name: String, want: String, r: Result<&1, &1, U32 & String, List<Archive.Entry>>) -> IO(Unit):
  match r:
    case Fail{e}:
      (code, msg) = e
      IO.die(Unit, 1, "FAIL " ++ name ++ ": " ++ msg)
    case Done{xs}:
      expect(name, String.eq(contents(xs), want))

def bad(name: String, code: U32, message: String, r: Result<&1, &1, U32 & String, List<Archive.Entry>>) -> IO(Unit):
  match r:
    case Fail{e}:
      (got, reason) = e
      expect(name, Bool.and(U32.is_eq(got, code), String.eq(reason, message)))
    case Done{xs}:
      IO.die(Unit, 1, "FAIL " ++ name)

def truncated() -> Bytes.Bytes:
  Bytes.snd(Bytes.slice(mixed(), 0, 210))

def main() -> IO(Unit):
  do IO<Unit>:
    e : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, empty())
    good("empty", "", e)
    r : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, mixed())
    good("stored and deflated", "a.txt=stored;b.txt=deflated bodydeflated bodydeflated body;", r)
    crc : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, Bytes.set(mixed(), 110, 0))
    bad("bad CRC", 22, "entry CRC-32 does not match", crc)
    size : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, Bytes.set(mixed(), 118, 7))
    bad("size mismatch", 22, "stored entry sizes differ", size)
    deflate_crc : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, Bytes.set(mixed(), 161, 0))
    bad("deflated CRC", 22, "entry CRC-32 does not match", deflate_crc)
    deflate_short : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, Bytes.set(mixed(), 169, 38))
    bad("deflated output exceeds declared size", 22, "entry size differs from the central directory", deflate_short)
    deflate_long : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, Bytes.set(mixed(), 169, 40))
    bad("deflated output below declared size", 22, "entry size differs from the central directory", deflate_long)
    short : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, truncated())
    bad("truncated end record", 22, "no end of central directory record", short)
    dir : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, Bytes.set(mixed(), 208, 101))
    bad("truncated directory", 22, "central directory header runs past the directory", dir)
    method : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(100, Bytes.set(mixed(), 104, 12))
    bad("unsupported method", 22, "unsupported compression method 12", method)
    limited : Result<&1, &1, U32 & String, List<Archive.Entry>> <- Archive.read(38, mixed())
    bad("size limit", 27, "archive output is larger than max", limited)
