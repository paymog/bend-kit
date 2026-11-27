import Base
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ./storage.bend as S
import ./pure.bend as P

def run(mode: String, +dir: String, value: String, +root: P.Digest) -> S.Run(Unit):
  match mode:
    case "object":
      do S.Run<Unit>:
        bytes : Bytes.Bytes <- S.read(value)
        received : P.Index(P.Digest, P.Blob) <- S.Disk.receive(dir, P.Index.new(P.Digest, P.Blob), root, bytes)
        return Unit{}
    case "root":
      S.Disk.set_root(dir, value, root)
    case "verify":
      do S.Run<Unit>:
        tree : P.Tree<P.Blob> <- S.Disk.checkout(dir, root)
        return Unit{}
    case "clean":
      do S.Run<Unit>:
        count : U32 <- S.Disk.clean_tmp(dir)
        return Unit{}
    case _:
      S.Disk.init(dir)

def args(args: List<&1, String>) -> IO(Unit):
  match args:
    case Con{mode, Con{dir, Con{value, Con{hex, Nil{}}}}}:
      do IO<Unit>:
        root : P.Digest <- IO.try(P.Digest, S.Run.some(P.Digest, P.Digest.read(hex), "invalid test digest"))
        IO.try(Unit, run(mode, dir, value, root))
        IO.print("ACK")
    case _:
      IO.die(Unit, 1, "expected mode store value digest")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<&1, String> <- IO.args()
    args(List.tail(&1, String, argv))
