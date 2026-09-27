# Parser combinator benchmark: the JSON grammar in ../json.bend on one fixed document (see README.md).
import Base
import ../../time/time.bend as Time
import ../json.bend as J
import ../../json/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Checksum: h = h*31 + c, u32, then add the length.
def hash(s: String, h: U32, n: U32) -> U32:
  match s:
    case SNil{}:
      (h + n : U32)
    case SCon{Chr{c}, t}:
      hash(t, (h * 31 + c : U32), (n + 1 : U32))

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, out: String) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(hash(out, 0, 0)))

# The checksum is not timed.
def op.parsed(t0: Time.Duration, m: Maybe<&2, J.Val>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("parse\t0\tfailed")
    case Some{+v}:
      do IO<Unit>:
        t1 : Time.Duration <- Time.mono()
        lap("parse", t0, t1, Bytes.to_string(Json.encode.bytes(J.to_json(v))))

def op.parse(s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.parsed(t0, J.parse(s))

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
