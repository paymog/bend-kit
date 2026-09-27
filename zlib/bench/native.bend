# Zlib benchmark through libz: inflate.words and gzip.words on the same inputs as bench.bend.
import Base
import ../zlib.bend as Z
import ../../bytes/bytes.bend as Bytes

def from_bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, from_bytes(t)}

def to_bytes(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{c}, t}:
      Con{c, to_bytes(t)}

# Checksum: h = h*31 + c, u32, over every inflated byte.
def chk(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      chk(t, (h * 31 + c : U32))

def lap(+name: String, t0: Nat, t1: Nat, out: String) -> IO(Unit):
  IO.print(name ++ "\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(chk(out, 0)))

def text(r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> String:
  match r:
    case Fail{e}:
      "failed"
    case Done{(+len, buf)}:
      Bytes.to_string(Bytes.Bytes{len, buf})

def op.inflated(t0: Nat, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    lap("inflate", t0, t1, text(r))

def op.inflate(b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  do IO<Unit>:
    t0 : Nat <- IO.now()
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.inflate.words(16777216, len, buf)
    op.inflated(t0, r)

def saved(r: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (f, x) = r
  File.close(f)

def save(+gz: String, r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("save\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        w : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(f, to_bytes(gz))
        saved(w)

def back(b: Bytes.Bytes) -> IO(Result<&1, &1, U32 & String, U32 & Array<U32>>):
  Bytes.Bytes{+len, buf} = b
  Z.inflate.words(16777216, len, buf)

# The checksum is of the round trip; run.py also feeds out/native.gz to gzip -d.
def op.deflated(t0: Nat, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("deflate\t0\tfailed")
    case Done{(+len, buf)}:
      +gz = Bytes.to_string(Bytes.Bytes{len, buf})
      do IO<Unit>:
        t1 : Nat <- IO.now()
        IO.print("size\t0\t" ++ U32.show(len))
        u : Result<&1, &1, U32 & String, U32 & Array<U32>> <- back(Bytes.from_string(gz))
        lap("deflate", t0, t1, text(u))
        f : Result<&1, &1, U32 & String, File> <- File.open("out/native.gz", "w")
        save(gz, f)

def op.deflate(b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  do IO<Unit>:
    t0 : Nat <- IO.now()
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- Z.gzip.words(len, buf)
    op.deflated(t0, r)

def bytes.of(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      Nil{}
    case Done{xs}:
      xs

def read(~op: Bytes.Bytes -> IO(Unit), m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    op(Bytes.from_string(from_bytes(bytes.of(r))))

def opened(~op: Bytes.Bytes -> IO(Unit), r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 16777216)
        read(~op, m)

def main() -> IO(Unit):
  do IO<Unit>:
    g : Result<&1, &1, U32 & String, File> <- File.open("out/payload.gz", "r")
    opened(~op.inflate, g)
    p : Result<&1, &1, U32 & String, File> <- File.open("out/plain.bin", "r")
    opened(~op.deflate, p)
