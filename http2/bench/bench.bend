import Base
import ../http2.bend as H
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def payload.sum(b: Bytes.Bytes) -> U32:
  H.with_number(U32, Bytes.get.u32be(b, 0), b => a =>
    H.with_number(U32, Bytes.get.u32be(b, 4), b => z => (a + z : U32)))

def one(d: H.Decode) -> U32:
  match d:
    case H.Need{b}:
      0
    case H.Bad{e}:
      0
    case H.Got{H.Frame{kind, flags, stream, payload}, rest}:
      payload.sum(payload)

def run(n: Nat, +sum: U32) -> U32:
  match n:
    case 0n:
      sum
    case 1n+p:
      +v = one(H.parse(16384, Bytes.from_string("\u{0}\u{0}\u{8}\u{6}\u{1}\u{0}\u{0}\u{0}\u{0}12345678")))
      run(p, (sum + v : U32))

def main() -> IO(Unit):
  IO.print(U32.show(run(10000n, 0)))
