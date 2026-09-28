# JSON benchmark: parse and encode one fixed document as UTF-8 Bytes (see README.md).
import Base
import ../../time/time.bend as Time
import ../json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Checksum: h = h*31 + c, u32, then add the length.
def hash(s: String, h: U32, n: U32) -> U32:
  match s:
    case SNil{}:
      (h + n : U32)
    case SCon{Chr{c}, t}:
      hash(t, (h * 31 + c : U32), (n + 1 : U32))

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, +sum: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(sum))

# Val is affine, so the one encode gives both checksums. Checksums are not timed.
def op.encoded(t0: Time.Duration, +t1: Time.Duration, t2: Time.Duration, out: Bytes.Bytes) -> IO(Unit):
  +sum = hash(Bytes.to_string(out), 0, 0)
  do IO<Unit>:
    lap("parse.bytes", t0, t1, sum)
    lap("encode.bytes", t1, t2, sum)

# Bend evaluates strictly: the output is built before t2 is read.
def op.encode(t0: Time.Duration, t1: Time.Duration, v: Json.Val) -> IO(Unit):
  out = Json.encode.bytes(v)
  do IO<Unit>:
    t2 : Time.Duration <- Time.mono()
    op.encoded(t0, t1, t2, out)

def op.parsed(t0: Time.Duration, m: Maybe<&1, Json.Val>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("parse.bytes\t0\tfailed")
    case Some{v}:
      do IO<Unit>:
        t1 : Time.Duration <- Time.mono()
        op.encode(t0, t1, v)

# The file is read as octets, one Char each, and packed before the timer starts.
def op.parse(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.parsed(t0, Json.parse.bytes(b))

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
    op.parse(Bytes.from_string(text(r)))

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
