# CSV benchmark: parse and encode one fixed document as Bytes (see README.md).
import Base
import ../csv.bend as Csv
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Checksum: h = h*31 + c, u32, then add the length.
def hash(s: String, h: U32, n: U32) -> U32:
  match s:
    case SNil{}:
      (h + n : U32)
    case SCon{Chr{c}, t}:
      hash(t, (h * 31 + c : U32), (n + 1 : U32))

def lap(+name: String, t0: Nat, t1: Nat, +sum: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(sum))

# Records are affine, so the one encode gives both checksums. Checksums are not timed.
def op.encoded(t0: Nat, +t1: Nat, t2: Nat, out: Bytes.Bytes) -> IO(Unit):
  +sum = hash(Bytes.to_string(out), 0, 0)
  do IO<Unit>:
    lap("parse", t0, t1, sum)
    lap("encode", t1, t2, sum)

# Bend evaluates strictly: the output is built before t2 is read.
def op.encode(t0: Nat, t1: Nat, rs: List<&1, List<&1, Bytes.Bytes>>) -> IO(Unit):
  out = Csv.encode(rs)
  do IO<Unit>:
    t2 : Nat <- IO.now()
    op.encoded(t0, t1, t2, out)

def op.parsed(t0: Nat, r: Result<&1, &1, U32, List<&1, List<&1, Bytes.Bytes>>>) -> IO(Unit):
  match r:
    case Fail{at}:
      IO.print("parse\t0\tfailed at " ++ U32.show(at))
    case Done{rs}:
      do IO<Unit>:
        t1 : Nat <- IO.now()
        op.encode(t0, t1, rs)

# The file is read as octets, one Char each, and packed before the timer starts.
def op.parse(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.parsed(t0, Csv.parse(b))

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
    f : Result<&1, &1, U32 & String, File> <- File.open("out/doc.csv", "r")
    opened(f)
