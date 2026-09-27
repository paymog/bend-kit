# Crypto benchmark: SHA-256 of 16 MiB of zero bytes (see README.md).
import Base
import ../crypto.bend as C
import ../../bytes/bytes.bend as Bytes

def lap(t0: Nat, t1: Nat, r: Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("sha256\t0\tfailed")
    case Done{(+len, buf)}:
      IO.print("sha256\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ Bytes.to_hex(Bytes.Bytes{len, buf}))

def run(b: Bytes.Bytes) -> IO(Unit):
  Bytes.Bytes{+len, buf} = b
  do IO<Unit>:
    t0 : Nat <- IO.now()
    r : Result<&1, &1, U32 & String, U32 & Array<U32>> <- C.sha256.words(len, buf)
    t1 : Nat <- IO.now()
    lap(t0, t1, r)

def main() -> IO(Unit):
  run(Bytes.new(16777216))
