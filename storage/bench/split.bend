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

def encoded(xs: S.Store<S.Digest, S.Blob>) -> List<&1, Bytes.Bytes>:
  match xs:
    case S.StNil{}:
      Nil{}
    case S.StCon{d, o, r}:
      Con{S.encode(o), encoded(r)}

def checksum(d: S.Digest) -> U32:
  match d:
    case S.Digest{Con{h, t}}:
      h
    case S.Digest{Nil{}}:
      0

def hashed(xs: List<&1, Bytes.Bytes>, +n: U32) -> S.Run(U32):
  match xs:
    case Nil{}:
      S.Run.pure(U32, n)
    case Con{b, r}:
      do S.Run<U32>:
        d : S.Digest <- S.digest(b)
        hashed(r, (n + checksum(d) : U32))

def listed(t: S.Tree<S.Blob>, +d: S.Digest) -> S.Store<S.Digest, S.Blob>:
  match t:
    case S.TFile{b}:
      S.StCon{d, S.OFile{b}, S.StNil{}}
    case S.TEnd{}:
      S.StCon{d, S.OEnd{}, S.StNil{}}
    case S.TItem{n, c, r}:
      S.Store.cat(S.Digest, S.Blob, listed(c, d),
        S.Store.cat(S.Digest, S.Blob, listed(r, d), S.StCon{d, S.OItem{n, d, d}, S.StNil{}}))

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
    bs : List<&1, Bytes.Bytes> = encoded(objs)
    d1 : Time.Duration <- Time.mono()
    sum : U32 <- IO.try(U32, hashed(bs, 0))
    IO.print(U32.show(sum))
    d2 : Time.Duration <- Time.mono()
    IO.print("sha-only " ++ ms(d2, d1))
    IO.print("root " ++ S.Digest.hex(root))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +k : Nat = U32.to_nat(B.side(args))
    raw : B.Input = B.dirs(k, 0, k)
    p0 : Time.Duration <- Time.mono()
    +t : S.Tree<S.Blob> <- IO.try(S.Tree<S.Blob>, B.prepare(raw))
    p1 : Time.Duration <- Time.mono()
    IO.print("prepare " ++ ms(p1, p0))
    l0 : Time.Duration <- Time.mono()
    IO.print(U32.show(S.Store.size(S.Digest, S.Blob, listed(t, S.Digest{[0, 0, 0, 0, 0, 0, 0, 0]}))))
    l1 : Time.Duration <- Time.mono()
    IO.print("list-only " ++ ms(l1, l0))
    t0 : Time.Duration <- Time.mono()
    r : S.Digest & S.Store<S.Digest, S.Blob> <- IO.try(S.Digest & S.Store<S.Digest, S.Blob>, S.commit(t))
    rest(t0, r)
