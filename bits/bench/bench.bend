# Bits benchmark: fixed-Huffman literal decode and 13-bit field reads over out/payload.bin.
import Base
import ../../time/time.bend as Time
import ../bits.bend as Bits
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def from_bytes(xs: List<&2, U32>) -> String:
  match xs:
    case Nil{}:
      SNil{}
    case Con{c, t}:
      SCon{Chr{c}, from_bytes(t)}

def rep(k: Nat, +v: U32, acc: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      acc
    case 1n+p:
      rep(p, v, Con{v, acc})

# RFC 1951 §3.2.6.
def fixed.lens() -> List<&2, U32>:
  rep(144n, 8, rep(112n, 9, rep(24n, 7, rep(8n, 8, Nil{}))))

def lap(+name: String, t0: Time.Duration, t1: Time.Duration, +h: U32) -> IO(Unit):
  IO.print(name ++ "\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(h))

# The symbol, and whether to go on: not end-of-block (256) and not a bad code.
def tag(r: Bits.Huff & Bits.Reader & Maybe<&2, U32>) -> Bits.Huff & Bits.Reader & U32 & Bool:
  (t, rd, m) = r
  match m:
    case None{}:
      (t, rd, 0, False{})
    case Some{+s}:
      (t, rd, s, U32.is_ne(s, 256))

# Literals until end-of-block: h = h*31 + literal.
def lits.got(k: Nat, +h: U32, r: Bits.Huff & Bits.Reader & U32 & Bool) -> U32:
  match k:
    case 0n:
      h
    case 1n+p:
      (t, rd, +s, go) = r
      match go:
        case True{}:
          lits.got(p, (h * 31 + s : U32), tag(Bits.Huff.decode(t, rd)))
        case False{}:
          h

def skip3(r: Bits.Reader & Maybe<&2, U32>) -> Bits.Reader:
  (rd, m) = r
  rd

def lits(h: Bits.Huff, b: Bytes.Bytes) -> U32:
  lits.got(16777216n, 0, tag(Bits.Huff.decode(h, skip3(Bits.Reader.lsb(Bits.Reader.new(b), 3)))))

def fields.got(k: Nat, +h: U32, r: Bits.Reader & Maybe<&2, U32>) -> U32:
  match k:
    case 0n:
      h
    case 1n+p:
      (rd, m) = r
      match m:
        case None{}:
          h
        case Some{+v}:
          fields.got(p, (h * 31 + v : U32), Bits.Reader.lsb(rd, 13))

def fields(b: Bytes.Bytes) -> U32:
  fields.got(16777216n, 0, Bits.Reader.lsb(Bits.Reader.new(b), 13))

def op.huff(m: Maybe<&1, Bits.Huff>, b: Bytes.Bytes) -> IO(Unit):
  match m:
    case None{}:
      IO.print("huffman\t0\tfailed")
    case Some{h}:
      do IO<Unit>:
        t0 : Time.Duration <- Time.mono()
        +sum : U32 = lits(h, b)
        t1 : Time.Duration <- Time.mono()
        lap("huffman", t0, t1, sum)

def op.fields(b: Bytes.Bytes) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    +sum : U32 = fields(b)
    t1 : Time.Duration <- Time.mono()
    lap("fields", t0, t1, sum)

def bytes.of(r: Result<&1, &1, U32 & String, List<&2, U32>>) -> List<&2, U32>:
  match r:
    case Fail{e}:
      Nil{}
    case Done{xs}:
      xs

def run(+s: String) -> IO(Unit):
  do IO<Unit>:
    op.huff(Bits.Huff.from_lens(False{}, fixed.lens()), Bytes.from_string(s))
    op.fields(Bytes.from_string(s))

def read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    run(from_bytes(bytes.of(r)))

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
    p : Result<&1, &1, U32 & String, File> <- File.open("out/payload.bin", "r")
    opened(p)
