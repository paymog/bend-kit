import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-files@0.4.0.1/files.bend as Files
import ./storage.bend as S
import ./pure.bend as P

def ok(good: Bool) -> IO(Unit):
  match good:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "bad bounded root publication")

def status(r: U32 & (String & String)) -> IO(Unit):
  (code, out) = r
  ok(U32.is_zero(code))

def shared(n: Nat, +dir: String, +d: P.Digest) -> S.Run(P.Digest):
  match n:
    case 0n:
      S.Run.pure(P.Digest, d)
    case 1n+p:
      do S.Run<P.Digest>:
        +node : P.Obj<P.Digest, P.Blob> = P.OItem{"shared", d, d}
        +next : P.Digest <- S.object.digest(node)
        S.Disk.put(dir, next, P.encode(node))
        shared(p, dir, next)

def main() -> IO(Unit):
  do IO<Unit>:
    +dir : String <- IO.try(String, Files.temp_dir())
    IO.try(Unit, S.Disk.init(dir))
    +end : P.Digest <- IO.try(P.Digest, S.Disk.commit(dir, P.TEnd{}))
    IO.try(Unit, S.Disk.set_root(dir, "small", end))
    +root : P.Digest <- IO.try(P.Digest, shared(24n, dir, end))
    +seen : P.Index(P.Digest, Unit) <- IO.try(P.Index(P.Digest, Unit), S.Disk.walk.go(~S.verified.sync, Nat.mul(3n, P.limit()), dir, S.FenceWant{root}, P.Index.new(P.Digest, Unit)))
    ok(U32.is_eq(P.Index.size(P.Digest, Unit, seen), 25))
    IO.try(Unit, S.Disk.set_root(dir, "shared", root))
    IO.try(Unit, Files.remove(S.Disk.object(dir, end)))
    cached : P.Index(P.Digest, Unit) <- IO.try(P.Index(P.Digest, Unit), S.Disk.walk.go(~S.verified.sync, 3n, dir, S.FenceWant{end}, seen))
    ok(U32.is_eq(P.Index.size(P.Digest, Unit, cached), 25))
    made : U32 & (String & String) <- IO.try(U32 & (String & String), Process.run("python3", ["-c",
      "import sys; f=open(sys.argv[1],'wb'); f.write(b'file 17825792\\n'); chunk=bytes(65536)\nfor _ in range(272): f.write(chunk)\nf.close()",
      dir ++ "/objects/89c9109ce931e20ac63a1729d6f6a9db03dee9401161eb8a3fbd35c4a09a9528"], "", 1024, 5000))
    status(made)
    +large : P.Digest = Maybe.default(&2, P.Digest, P.Digest.read("89c9109ce931e20ac63a1729d6f6a9db03dee9401161eb8a3fbd35c4a09a9528"), end)
    IO.try(Unit, S.Disk.set_root(dir, "large", large))
    result : P.Digest <- IO.try(P.Digest, S.Disk.root(dir, "large"))
    ok(Cmp.is_eq(P.Digest.cmp(result, large)))
    cleaned : U32 & (String & String) <- IO.try(U32 & (String & String), Process.run("python3", ["-c", "import shutil,sys; shutil.rmtree(sys.argv[1])", dir], "", 1024, 5000))
    status(cleaned)
    IO.print("ok bounded root publication: 17 MiB file and shared descendants")
