# Storage checkout bench: a small root from a large store, on demand and through a full load (see README.md).
import Base
import bend-kit-files@0.4.0.1/files.bend as Files
import ../../time/time.bend as Time
import ../storage.bend as S
import ./bench.bend as B

def ms(t1: Time.Duration, t0: Time.Duration) -> String:
  Time.Duration.show_ms(Time.Duration.sub(t1, t0))

def small() -> S.Run(S.Tree<S.Blob>):
  do S.Run<S.Tree<S.Blob>>:
    b : S.Blob <- S.Blob.string("small root\n")
    return S.TItem{"note", S.TFile{b}, S.TEnd{}}

def octets(m: Maybe<&2, S.Tree<S.Blob>>) -> U32:
  B.loaded(m)

def timed(+dir: String, +root: S.Digest) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    t : S.Tree<S.Blob> <- IO.try(S.Tree<S.Blob>, S.Disk.checkout(dir, root))
    IO.print("chk\tcheckout\t" ++ U32.show(B.total(t)))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tcheckout\t" ++ ms(t1, t0))
    u0 : Time.Duration <- Time.mono()
    s : S.Index(S.Digest, S.Blob) <- IO.try(S.Index(S.Digest, S.Blob), S.Disk.load(dir))
    IO.print("chk\tfull load\t" ++ U32.show(octets(S.Index.load(~S.Digest, ~S.Blob, ~S.Digest.cmp, S.limit(), s, root))))
    u1 : Time.Duration <- Time.mono()
    IO.print("ms\tfull load\t" ++ ms(u1, u0))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +k : Nat = U32.to_nat(B.side(args))
    tmp : String <- IO.try(String, Files.temp_dir())
    +dir : String = tmp ++ "/store"
    IO.try(Unit, S.Disk.init(dir))
    tree : S.Tree<S.Blob> <- IO.try(S.Tree<S.Blob>, B.prepare(B.dirs(k, 0, k)))
    big : S.Digest <- IO.try(S.Digest, S.Disk.commit(dir, tree))
    note : S.Tree<S.Blob> <- IO.try(S.Tree<S.Blob>, small())
    root : S.Digest <- IO.try(S.Digest, S.Disk.commit(dir, note))
    timed(dir, root)
