# Storage benchmark split: times commit, index build, load, and encode alone (see README.md).
import Base
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import ../../time/time.bend as Time
import ../storage.bend as S
import ../pure.bend as P
import ./bench.bend as B

def ms(t1: Time.Duration, t0: Time.Duration) -> String:
  Time.Duration.show_ms(Time.Duration.sub(t1, t0))

def blen(b: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, buf} = b
  len

def enc(xs: P.Store<P.Digest, P.Blob>, +n: U32) -> U32:
  match xs:
    case P.StNil{}:
      n
    case P.StCon{d, o, r}:
      enc(r, (n + blen(P.encode(o)) : U32))

def encoded(xs: P.Store<P.Digest, P.Blob>) -> List<&1, Bytes.Bytes>:
  match xs:
    case P.StNil{}:
      Nil{}
    case P.StCon{d, o, r}:
      Con{P.encode(o), encoded(r)}

def checksum(d: P.Digest) -> U32:
  match d:
    case P.Digest{Con{h, t}}:
      h
    case P.Digest{Nil{}}:
      0

def hashed(xs: List<&1, Bytes.Bytes>, +n: U32) -> S.Run(U32):
  match xs:
    case Nil{}:
      S.Run.pure(U32, n)
    case Con{b, r}:
      do S.Run<U32>:
        d : P.Digest <- S.digest(b)
        hashed(r, (n + checksum(d) : U32))

def listed(t: P.Tree<P.Blob>, +d: P.Digest) -> P.Store<P.Digest, P.Blob>:
  match t:
    case P.TFile{b}:
      P.StCon{d, P.OFile{b}, P.StNil{}}
    case P.TEnd{}:
      P.StCon{d, P.OEnd{}, P.StNil{}}
    case P.TItem{n, c, r}:
      P.Store.cat(P.Digest, P.Blob, listed(c, d),
        P.Store.cat(P.Digest, P.Blob, listed(r, d), P.StCon{d, P.OItem{n, d, d}, P.StNil{}}))

def rest(t0: Time.Duration, r: P.Digest & P.Store<P.Digest, P.Blob>) -> IO(Unit):
  (+root, +objs) = r
  do IO<Unit>:
    IO.print(U32.show(P.Store.size(P.Digest, P.Blob, objs)))
    t1 : Time.Duration <- Time.mono()
    IO.print("commit " ++ ms(t1, t0))
    a1 : Time.Duration <- Time.mono()
    +s : P.Index(P.Digest, P.Blob) = P.Index.of(~P.Digest, ~P.Blob, ~P.Digest.cmp, objs)
    IO.print(U32.show(P.Index.size(P.Digest, P.Blob, s)))
    a2 : Time.Duration <- Time.mono()
    IO.print("index " ++ ms(a2, a1))
    b1 : Time.Duration <- Time.mono()
    IO.print(U32.show(B.loaded(P.Index.load(~P.Digest, ~P.Blob, ~P.Digest.cmp, P.limit(), s, root))))
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
    IO.print("root " ++ P.Digest.hex(root))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +k : Nat = U32.to_nat(B.side(args))
    raw : B.Input = B.dirs(k, 0, k)
    p0 : Time.Duration <- Time.mono()
    +t : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, B.prepare(raw))
    p1 : Time.Duration <- Time.mono()
    IO.print("prepare " ++ ms(p1, p0))
    l0 : Time.Duration <- Time.mono()
    IO.print(U32.show(P.Store.size(P.Digest, P.Blob, listed(t, P.Digest{[0, 0, 0, 0, 0, 0, 0, 0]}))))
    l1 : Time.Duration <- Time.mono()
    IO.print("list-only " ++ ms(l1, l0))
    t0 : Time.Duration <- Time.mono()
    r : P.Digest & P.Store<P.Digest, P.Blob> <- IO.try(P.Digest & P.Store<P.Digest, P.Blob>, S.commit(t))
    rest(t0, r)
