# JSON benchmark: parse and encode one fixed document, as text and as Bytes (see README.md).
import Base
import ../json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Checksum: h = h*31 + c, u32, then add the length.
def hash(s: String, h: U32, n: U32) -> U32:
  match s:
    case SNil{}:
      (h + n : U32)
    case SCon{Chr{c}, t}:
      hash(t, (h * 31 + c : U32), (n + 1 : U32))

def lap(+name: String, t0: Nat, t1: Nat, out: String) -> IO(Unit):
  IO.print(name ++ "\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(hash(out, 0, 0)))

# Bend evaluates strictly: the output is built before t1 is read. The checksum is not timed.
def op.encoded.bytes(t0: Nat, out: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    lap("encode.bytes", t0, t1, Bytes.to_string(out))

def op.encode.bytes(v: Json.Val) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.encoded.bytes(t0, Json.encode.bytes(v))

def op.parsed.bytes(t0: Nat, m: Maybe<&2, Json.Val>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("parse.bytes\t0\tfailed")
    case Some{+v}:
      do IO<Unit>:
        t1 : Nat <- IO.now()
        lap("parse.bytes", t0, t1, Json.encode(v))
        op.encode.bytes(v)

# The file is read as octets, one Char each, and packed before the timer starts.
def op.parse.bytes(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.parsed.bytes(t0, Json.parse.bytes(b))

def op.encoded(t0: Nat, out: String) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    lap("encode", t0, t1, out)

def op.encode(v: Json.Val) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.encoded(t0, Json.encode(v))

def op.parsed(t0: Nat, m: Maybe<&2, Json.Val>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("parse\t0\tfailed")
    case Some{+v}:
      do IO<Unit>:
        t1 : Nat <- IO.now()
        lap("parse", t0, t1, Json.encode(v))
        op.encode(v)

def op.parse.text(s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.parsed(t0, Json.parse(s))

def op.parse(+s: String) -> IO(Unit):
  do IO<Unit>:
    op.parse.text(s)
    op.parse.bytes(Bytes.from_string(s))

def text(r: Result<&1, &1, U32 & String, String>) -> String:
  match r:
    case Fail{e}:
      SNil{}
    case Done{s}:
      s

def read(m: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    op.parse(text(r))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, String> <- File.read(f, 16777216)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    f : Result<&1, &1, U32 & String, File> <- File.open("out/doc.json", "r")
    opened(f)
