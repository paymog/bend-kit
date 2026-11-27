# Storage checkout bench: a small root from a large store, on demand and through a full load (see README.md).
import Base
import bend-kit-files@0.4.0.3/files.bend as Files
import ../../time/time.bend as Time
import ../storage.bend as S
import ../pure.bend as P
import ./bench.bend as B

def ms(t1: Time.Duration, t0: Time.Duration) -> String:
  Time.Duration.show_ms(Time.Duration.sub(t1, t0))

def small() -> S.Run(P.Tree<P.Blob>):
  do S.Run<P.Tree<P.Blob>>:
    b : P.Blob <- S.Blob.string("small root\n")
    return P.TItem{"note", P.TFile{b}, P.TEnd{}}

def octets(m: Maybe<&2, P.Tree<P.Blob>>) -> U32:
  B.loaded(m)

def timed(+dir: String, +root: P.Digest) -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    t : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, S.Disk.checkout(dir, root))
    IO.print("chk\tcheckout\t" ++ U32.show(B.total(t)))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tcheckout\t" ++ ms(t1, t0))
    u0 : Time.Duration <- Time.mono()
    s : P.Index(P.Digest, P.Blob) <- IO.try(P.Index(P.Digest, P.Blob), S.Disk.load(dir))
    IO.print("chk\tfull load\t" ++ U32.show(octets(P.Index.load(~P.Digest, ~P.Blob, ~P.Digest.cmp, P.limit(), s, root))))
    u1 : Time.Duration <- Time.mono()
    IO.print("ms\tfull load\t" ++ ms(u1, u0))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +k : Nat = U32.to_nat(B.side(args))
    tmp : String <- IO.try(String, Files.temp_dir())
    +dir : String = tmp ++ "/store"
    IO.try(Unit, S.Disk.init(dir))
    tree : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, B.prepare(B.dirs(k, 0, k)))
    big : P.Digest <- IO.try(P.Digest, S.Disk.commit(dir, tree))
    note : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, small())
    root : P.Digest <- IO.try(P.Digest, S.Disk.commit(dir, note))
    timed(dir, root)
