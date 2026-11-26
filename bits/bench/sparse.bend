import Base
import ./bench.bend as Bench
import ./profile.bend as Profile
import ../bits.bend as Bits
import ../../time/time.bend as Time
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes

def lens(mixed: Bool) -> List<&2, U32>:
  match mixed:
    case False{}:
      [16, 16]
    case True{}:
      Bench.rep(32n, 10, Bench.rep(16n, 12, [16, 16]))

def built(k: Nat, +msb: Bool, +mixed: Bool, acc: U32) -> U32:
  match k:
    case 0n:
      acc
    case 1n+p:
      built(p, msb, mixed, (acc + Profile.batch.code(Bits.Huff.from_lens(msb, lens(mixed))) : U32))

def decoded(k: Nat, acc: U32, r: Bits.Huff & Bits.Reader & Maybe<&2, U32>) -> U32:
  match k:
    case 0n:
      acc
    case 1n+p:
      (h, rd, result) = r
      match result:
        case None{}:
          4294967295
        case Some{+symbol}:
          decoded(p, (acc * 31 + symbol : U32), Bits.Huff.decode(h, rd))

def timed(m: Maybe<&1, Bits.Huff>, b: Bytes.Bytes) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "invalid sparse fixture")
    case Some{h}:
      do IO<Unit>:
        rd : Bits.Reader = Bits.Reader.new(b)
        t0 : Time.Duration <- Time.mono()
        +sum : U32 = decoded(4096n, 0, Bits.Huff.decode(h, rd))
        t1 : Time.Duration <- Time.mono()
        Bench.lap("decode4096", t0, t1, sum)

def repeat(k: Nat, +msb: Bool, +mixed: Bool, +s: String) -> IO(Unit):
  match k:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        t0 : Time.Duration <- Time.mono()
        +sum : U32 = built(1000n, msb, mixed, 0)
        t1 : Time.Duration <- Time.mono()
        Bench.lap("build1000", t0, t1, sum)
        timed(Bits.Huff.from_lens(msb, lens(mixed)), Bytes.from_string(s))
        repeat(p, msb, mixed, s)

def entries.sized(r: Array<U32> & U32, s: Array<U32> & U32) -> IO(Unit):
  (root, nr) = r
  (sub, ns) = s
  IO.print("entries\t" ++ U32.show(nr) ++ "\t" ++ U32.show(ns))

def entries(m: Maybe<&1, Bits.Huff>) -> IO(Unit):
  match m:
    case None{}:
      IO.die(Unit, 1, "invalid sparse fixture")
    case Some{Bits.Huff{msb, max, root, sub}}:
      entries.sized(Array.size(U32, root), Array.size(U32, sub))

def read(msb: Bool, mixed: Bool, r: File & Result<&1, &1, U32 & String, List<&2, U32>>) -> IO(Unit):
  (f, result) = r
  do IO<Unit>:
    File.close(f)
    bytes : List<&2, U32> <- IO.try(List<&2, U32>, IO.pure(Result<&1, &1, U32 & String, List<&2, U32>>, result))
    repeat(10n, msb, mixed, Bench.from_bytes(bytes))

def opened(msb: Bool, mixed: Bool, r: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "cannot open sparse fixture")
    case Done{f}:
      do IO<Unit>:
        r : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(f, 8193)
        read(msb, mixed, r)

def run(+name: String, +msb: Bool, +mixed: Bool) -> IO(Unit):
  do IO<Unit>:
    IO.print(name)
    entries(Bits.Huff.from_lens(msb, lens(mixed)))
    r : Result<&1, &1, U32 & String, File> <- File.open("out/" ++ name ++ ".bin", "r")
    opened(msb, mixed, r)

def main() -> IO(Unit):
  do IO<Unit>:
    run("sparse-lsb", False{}, False{})
    run("sparse-msb", True{}, False{})
    run("mixed-lsb", False{}, True{})
    run("mixed-msb", True{}, True{})
