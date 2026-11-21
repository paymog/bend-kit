import Base
import ../../time/time.bend as Time
import ../bits.bend as Bits
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

def copied(buf: Array<U32>, +depth: U32) -> Array<U32>:
  Bytes.dst(Bytes.copy(U32.shln(4, U32.to_nat(depth)), buf,
    Array.new(U32, U32.to_nat((depth + 1 : U32)), 0), 0, 0))

def buffer(w: Bits.Writer) -> Array<U32>:
  Bits.Writer{buf, dep, pos, msb} = w
  buf

def grown(keep: Bool, buf: Array<U32>, +depth: U32) -> Array<U32>:
  match keep:
    case False{}:
      copied(buf, depth)
    case True{}:
      buffer(Bits.room(True{}, Bits.Writer{buf, depth, 0, False{}}))

def checksum(buf: Array<U32>) -> U32:
  match buf:
    case ALeaf{v}:
      v
    case ANode{xs, ys}:
      (checksum(xs) + checksum(ys) : U32)

def check(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "writer growth checksum mismatch")

def sample(+keep: Bool, +depth: U32) -> IO(Unit):
  do IO<Unit>:
    buf : Array<U32> = Array.new(U32, U32.to_nat(depth), 123456789)
    t0 : Time.Duration <- Time.mono()
    out : Array<U32> = grown(keep, buf, depth)
    t1 : Time.Duration <- Time.mono()
    +sum : U32 = checksum(out)
    check(U32.is_eq(sum, U32.shln(123456789, U32.to_nat(depth))))
    IO.print(Bool.pick(String, keep, "keep", "copy") ++ "\t" ++ U32.show(depth) ++ "\t" ++
      Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(sum))

def samples(k: Nat) -> IO(Unit):
  match k:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        sample(False{}, 16)
        sample(True{}, 16)
        sample(False{}, 18)
        sample(True{}, 18)
        samples(p)

def main() -> IO(Unit):
  samples(3n)
