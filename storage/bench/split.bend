# Storage benchmark split: times commit, index build, load, and encode alone (see README.md).
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-collections@0.1.5.0/order.bend as Order
import ../../time/time.bend as Time
import ../storage.bend as S
import ./bench.bend as B

def ms(t1: Time.Duration, t0: Time.Duration) -> String:
  Time.Duration.show_ms(Time.Duration.sub(t1, t0))
def blen(b: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, buf} = b
  len

def enc(xs: S.Store<String, S.Blob>, +n: U32) -> U32:
  match xs:
    case S.StNil{}:
      n
    case S.StCon{d, o, r}:
      enc(r, (n + blen(S.encode(o)) : U32))

def rest(t0: Time.Duration, r: String & S.Store<String, S.Blob>) -> IO(Unit):
  (+root, +objs) = r
  do IO<Unit>:
    IO.print(U32.show(S.Store.size(String, S.Blob, objs)))
    t1 : Time.Duration <- Time.mono()
    IO.print("commit " ++ ms(t1, t0))
    a1 : Time.Duration <- Time.mono()
    +s : S.Index(String, S.Blob) = S.Index.of(~String, ~S.Blob, ~Order.string, objs)
    IO.print(U32.show(S.Index.size(String, S.Blob, s)))
    a2 : Time.Duration <- Time.mono()
    IO.print("index " ++ ms(a2, a1))
    b1 : Time.Duration <- Time.mono()
    IO.print(U32.show(B.loaded(S.Index.load(~String, ~S.Blob, ~Order.string, S.limit(), s, root))))
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
    r : String & S.Store<String, S.Blob> <- IO.try(String & S.Store<String, S.Blob>, S.commit(t))
    rest(t0, r)
