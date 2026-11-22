import Base
import ./bench.bend as Bench
import ../bits.bend as Bits
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

def lens() -> List<&2, U32>:
  Bench.rep(255n, 8, [9, 10, 11, 12, 13, 14, 15, 15])

def decoded(m: Maybe<&1, Bits.Huff>, b: Bytes.Bytes, t0: Time.Duration, +t1: Time.Duration) -> IO(Unit):
  match m:
    case None{}:
      IO.print("build\t0\tfailed")
    case Some{h}:
      do IO<Unit>:
        +sum : U32 = Bench.lits(h, b)
        t2 : Time.Duration <- Time.mono()
        Bench.lap("build", t0, t1, sum)
        Bench.lap("decode", t1, t2, sum)

def repeat(k: Nat, +s: String) -> IO(Unit):
  match k:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        b : Bytes.Bytes = Bytes.from_string(s)
        t0 : Time.Duration <- Time.mono()
        h : Maybe<&1, Bits.Huff> = Bits.Huff.from_lens(False{}, lens())
        t1 : Time.Duration <- Time.mono()
        decoded(h, b, t0, t1)
        repeat(p, s)

def read(m: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, r) = m
  do IO<Unit>:
    File.close(f)
    repeat(100n, Bench.from_bytes(Bench.bytes.of(r)))

def opened(r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("open\t0\tfailed")
    case Done{f}:
      do IO<Unit>:
        m : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 65536)
        read(m)

def main() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, File> <- File.open("out/short.bin", "r")
    opened(r)
