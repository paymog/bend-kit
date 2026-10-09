import Base
import ../stream.bend as Stream
import bend-kit-files@0.1.1.1/files.bend as Files
import bend-kit-hash@0.1.0.0/hash.bend as Hash
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def checksum(fuel: Nat, pair: File & Result<&1, &1, U32 & String, U32 & Array<U32>>, h: U32) -> IO(U32):
  match fuel:
    case 0n:
      IO.die(U32, 1, "checksum fuel exhausted")
    case 1n+p:
      match pair:
        case (f, Fail{err}):
          IO.die(U32, 1, "checksum read failed")
        case (f, Done{(+len, words)}):
          match len:
            case 0:
              do IO<U32>:
                File.close(f)
                return h
            case _:
              next = Hash.v32(Hash.bytewise(~U32, ~Hash.fnv32.byte, ~Hash.fnv32.word, Bytes.Bytes{len, words}, h))
              do IO<U32>:
                r : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Files.read.words(f, 16384)
                checksum(p, r, next)

def finish(+path: String, p: File & File & Stream.Outcome) -> IO(Unit):
  match p:
    case (a, b, Stream.Complete{+n}):
      do IO<Unit>:
        File.close(a)
        File.close(b)
        f : File <- IO.try(File, File.open(path, "r"))
        r : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Files.read.words(f, 16384)
        h : U32 <- checksum(1n+U32.to_nat(n), r, 2166136261)
        IO.print(U32.show(n) ++ " " ++ U32.show(h))
    case (a, b, Stream.Failed{n, e}):
      do IO<Unit>:
        File.close(a)
        File.close(b)
        IO.die(Unit, 1, "bounded copy failed after " ++ U32.show(n))

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Con{src, Con{+dst, Con{size, Con{chunk, Nil{}}}}}:
      do IO<Unit>:
        a : File <- IO.try(File, File.open(src, "r"))
        b : File <- IO.try(File, File.open(dst, "w"))
        p : File & File & Stream.Outcome <- Stream.file.file(a, b,
          Maybe.default(&2, U32, U32.read(chunk), 0), Maybe.default(&2, U32, U32.read(size), 0))
        finish(dst, p)
    case _:
      IO.die(Unit, 1, "usage: bench source destination size chunk")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(List.tail(&1, String, xs))
