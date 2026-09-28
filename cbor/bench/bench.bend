# CBOR benchmark: decode one fixed document from Bytes, and encode it back to Bytes (see README.md).
import Base
import ../cbor.bend as Cbor
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Checksum: h = h*31 + b, u32, then add the length.
def hash.go(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      (a, +b) = r
      hash.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), (h * 31 + b : U32))

def hash(b: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, buf} = b
  (hash.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, 0) + len : U32)

def lap(+name: String, t0: Nat, t1: Nat, +sum: String) -> IO(Unit):
  IO.print(name ++ "\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ sum)

def sum(m: Maybe<&1, Bytes.Bytes>) -> String:
  match m:
    case None{}:
      "failed"
    case Some{b}:
      U32.show(hash(b))

# Val is affine, so the one encode gives both checksums. Checksums are not timed.
def op.encoded(t0: Nat, +t1: Nat, t2: Nat, out: Maybe<&1, Bytes.Bytes>) -> IO(Unit):
  +s = sum(out)
  do IO<Unit>:
    lap("decode", t0, t1, s)
    lap("encode", t1, t2, s)

# Bend evaluates strictly: the output is built before t2 is read.
def op.encode(t0: Nat, t1: Nat, v: Cbor.Val) -> IO(Unit):
  out = Cbor.encode(v)
  do IO<Unit>:
    t2 : Nat <- IO.now()
    op.encoded(t0, t1, t2, out)

def op.decoded(t0: Nat, m: Maybe<&1, Cbor.Val>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("decode\t0\tfailed")
    case Some{v}:
      do IO<Unit>:
        t1 : Nat <- IO.now()
        op.encode(t0, t1, v)

# The file is read as octets and packed into Bytes before the timer starts.
def op.decode(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    op.decoded(t0, Cbor.decode(b))

def octets(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, octets(t)}

def list(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      Nil{}
    case Done{xs}:
      xs

def read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    op.decode(Bytes.from_string(octets(list(r))))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 16777216)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    f : Result<&1, &1, U32 & String, File> <- File.open("out/doc.cbor", "r")
    opened(f)
