import Base
import ../files.bend as Fs
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def hash.byte(+h: U32, +b: U32) -> U32:
  ((h .^. b) * 16777619 : U32)

def hash.list(xs: List<&2, U32>, +h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case Con{b, rest}:
      hash.list(rest, hash.byte(h, b))

def hash.packed.go(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      (a, b) = r
      hash.packed.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), hash.byte(h, b))

def hash.packed(b: Bytes.Bytes, h: U32) -> U32:
  Bytes.Bytes{len, buf} = b
  hash.packed.go(U32.to_nat(len), Bytes.peek(buf, 0), 0, h)

def packed.go(f: Nat, pair: File & Result<&1, &1, U32 & String, Bytes.Bytes>, h: U32) -> IO(U32):
  match f:
    case 0n:
      match pair:
        case (file, result):
          do IO<U32>:
            File.close(file)
            IO.die(U32, 1, "packed read exceeded fuel")
    case 1n+p:
      match pair:
        case (file, Fail{err}):
          do IO<U32>:
            File.close(file)
            IO.die(U32, 1, "packed read failed")
        case (file, Done{Bytes.Bytes{+len, buf}}):
          match len:
            case 0:
              do IO<U32>:
                File.close(file)
                return h
            case _:
              do IO<U32>:
                next : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 16384)
                packed.go(p, next, hash.packed(Bytes.Bytes{len, buf}, h))

def legacy.go(f: Nat, pair: File & Result<&1, &1, U32 & String, List<&2, U32>>, h: U32) -> IO(U32):
  match f:
    case 0n:
      match pair:
        case (file, result):
          do IO<U32>:
            File.close(file)
            IO.die(U32, 1, "Base read exceeded fuel")
    case 1n+p:
      match pair:
        case (file, Fail{err}):
          do IO<U32>:
            File.close(file)
            IO.die(U32, 1, "Base read failed")
        case (file, Done{Nil{}}):
          do IO<U32>:
            File.close(file)
            return h
        case (file, Done{Con{b, rest}}):
          do IO<U32>:
            next : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 16384)
            legacy.go(p, next, hash.list(rest, hash.byte(h, b)))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    file : File <- IO.try(File, File.open("bench/fixture.bin", "r"))
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 16384)
    a : U32 <- packed.go(18n, pair, 2166136261)
    +t1 : Nat <- IO.now()
    file : File <- IO.try(File, File.open("bench/fixture.bin", "r"))
    pair : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_bytes(file, 16384)
    b : U32 <- legacy.go(18n, pair, 2166136261)
    t2 : Nat <- IO.now()
    IO.print("packed\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(a))
    IO.print("base\t" ++ Nat.show((t2 - t1 : Nat)) ++ "\t" ++ U32.show(b))
