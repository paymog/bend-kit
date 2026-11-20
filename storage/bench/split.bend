# Storage benchmark split: times commit, index build, load, and encode alone (see README.md).
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import ../../time/time.bend as Time
import ../storage.bend as S
import ./bench.bend as B

def ms(t1: Time.Duration, t0: Time.Duration) -> String:
  Time.Duration.show_ms(Time.Duration.sub(t1, t0))

def blen(b: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, buf} = b
  len

def enc(xs: S.Store<S.Digest, S.Blob>, +n: U32) -> U32:
  match xs:
    case S.StNil{}:
      n
    case S.StCon{d, o, r}:
      enc(r, (n + blen(S.encode(o)) : U32))

def rest(t0: Time.Duration, r: S.Digest & S.Store<S.Digest, S.Blob>) -> IO(Unit):
  (+root, +objs) = r
  do IO<Unit>:
    IO.print(U32.show(S.Store.size(S.Digest, S.Blob, objs)))
    t1 : Time.Duration <- Time.mono()
    IO.print("commit " ++ ms(t1, t0))
    a1 : Time.Duration <- Time.mono()
    +s : S.Index(S.Digest, S.Blob) = S.Index.of(~S.Digest, ~S.Blob, ~S.Digest.cmp, objs)
    IO.print(U32.show(S.Index.size(S.Digest, S.Blob, s)))
    a2 : Time.Duration <- Time.mono()
    IO.print("index " ++ ms(a2, a1))
    b1 : Time.Duration <- Time.mono()
    IO.print(U32.show(B.loaded(S.Index.load(~S.Digest, ~S.Blob, ~S.Digest.cmp, S.limit(), s, root))))
    b2 : Time.Duration <- Time.mono()
    IO.print("load " ++ ms(b2, b1))
    c1 : Time.Duration <- Time.mono()
    IO.print(U32.show(enc(objs, 0)))
    c2 : Time.Duration <- Time.mono()
    IO.print("encode-only " ++ ms(c2, c1))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +k : Nat = U32.to_nat(B.side(args))
    t : S.Tree<S.Blob> = B.dirs(k, 0, k)
    t0 : Time.Duration <- Time.mono()
    r : S.Digest & S.Store<S.Digest, S.Blob> <- IO.try(S.Digest & S.Store<S.Digest, S.Blob>, S.commit(t))
    rest(t0, r)
