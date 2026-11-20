# Zlib benchmark: gunzip one fixed member, and gzip its plain text (see README.md).
import Base
import ../../time/time.bend as Time
import ../zlib.bend as Z
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

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

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, out: String) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk(out, 0)))

def text(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case None{}:
      "failed"
    case Some{b}:
      Bytes.to_string(b)

def op.inflated(t0: Time.Duration, m: Maybe<&1, Bytes.Bytes>) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    lap("inflate", t0, t1, text(m))

def op.inflate(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.inflated(t0, Z.gunzip(b))

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
def op.report(t0: Time.Duration, t1: Time.Duration, gz: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = gz
  +s = Bytes.to_string(Bytes.Bytes{len, buf})
  do IO<Unit>:
    IO.print("size\t0\t" ++ U32.show(len))
    lap("deflate", t0, t1, text(Z.gunzip(Bytes.from_string(s))))
    f : Result<&1, &1, U32 & String, File> <- File.open("out/bend.gz", "w")
    save(s, f)

def op.deflated(t0: Time.Duration, gz: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    op.report(t0, t1, gz)

def op.deflate(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    op.deflated(t0, Z.gzip(b))

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
