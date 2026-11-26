import Base
import ./storage.bend as S
import ./pure.bend as P

def run(mode: String, +src: String, dst: String, +root: P.Digest) -> S.Run(U32):
  match mode:
    case "sync":
      S.sync(src, dst, root)
    case "named":
      S.Disk.collect_named(src)
    case _:
      S.Disk.collect(src, [root, root])

def args(args: List<&1, String>) -> IO(Unit):
  match args:
    case Con{mode, Con{src, Con{dst, Con{hex, Nil{}}}}}:
      do IO<Unit>:
        root : P.Digest <- IO.try(P.Digest, S.Run.some(P.Digest, P.Digest.read(hex), "invalid test digest"))
        count : U32 <- IO.try(U32, run(mode, src, dst, root))
        IO.print(U32.show(count))
    case _:
      IO.die(Unit, 1, "expected mode source destination root")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<&1, String> <- IO.args()
    args(List.tail(&1, String, argv))
