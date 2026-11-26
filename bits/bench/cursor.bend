import Base
import ./bench.bend as Bench
import ../bits.bend as Bits
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

def get(msb: Bool, rd: Bits.Reader) -> Bits.Reader & Maybe<&2, U32>:
  match msb:
    case False{}:
      Bits.Reader.lsb(rd, 13)
    case True{}:
      Bits.Reader.msb(rd, 13)

def mixed(k: Nat, +msb: Bool, +h: U32, r: Bits.Reader & Maybe<&2, U32>) -> U32:
  match k:
    case 0n:
      h
    case 1n+p:
      (rd, value) = r
      match value:
        case None{}:
          h
        case Some{+v}:
          mixed(p, Bool.not(msb), (h * 31 + v : U32), get(Bool.not(msb), rd))

def run(+s: String) -> IO(Unit):
  do IO<Unit>:
    Bench.run(s)
    rd : Bits.Reader = Bits.Reader.new(Bytes.from_string(s))
    t0 : Time.Duration <- Time.mono()
    +sum : U32 = mixed(16777216n, False{}, 0, get(False{}, rd))
    t1 : Time.Duration <- Time.mono()
    Bench.lap("mixed", t0, t1, sum)

def read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    run(Bench.from_bytes(Bench.bytes.of(r)))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "cannot open payload")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 16777216)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    p : Result<&1, &1, U32 & String, File> <- File.open("out/payload.bin", "r")
    opened(p)
