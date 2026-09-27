# Zlib benchmark: gunzip one fixed member, and gzip its plain text (see README.md).
import Base
import ../zlib.bend as Z

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

def op.inflated(t0: Nat, m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("inflate\t0\tfailed")
    case Some{+out}:
      do IO<Unit>:
        t1 : Nat <- IO.now()
        lap("inflate", t0, t1, out)

def op.inflate(s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.inflated(t0, Z.gunzip(s))

def unwrap(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "failed"
    case Some{s}:
      s

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

# The checksum is of the round trip; run.py also feeds out/bend.gz to gzip -d.
def op.deflated(t0: Nat, +gz: String) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    IO.print("size\t0\t" ++ U32.show(Z.slen(gz, 0)))
    lap("deflate", t0, t1, unwrap(Z.gunzip(gz)))
    f : Result<&1, &1, U32 & String, File> <- File.open("out/bend.gz", "w")
    save(gz, f)

def op.deflate(s: String) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.deflated(t0, Z.gzip(s))

def bytes.of(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      Nil{}
    case Done{xs}:
      xs

def read(~op: String -> IO(Unit), m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    op(from_bytes(bytes.of(r)))

def opened(~op: String -> IO(Unit), r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
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
