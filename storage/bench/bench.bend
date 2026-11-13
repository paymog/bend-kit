# Storage benchmark: the Bend side (see README.md).
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-collections@0.1.5.0/order.bend as Order
import ../../time/time.bend as Time
import ../storage.bend as S

# Octet j of file (d, f) is (d * 31 + f * 7 + j) & 255.
def fill(n: Nat, b: Bytes.Bytes, +j: U32, +seed: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      fill(p, Bytes.set(b, j, ((seed + j) .&. 255 : U32)), (j + 1 : U32), seed)

def content(+d: U32, +f: U32) -> S.Blob:
  S.Blob.of(fill(4096n, Bytes.new(4096), 0, (d * 31 + f * 7 : U32)))

def pad(+k: U32) -> String:
  Bool.pick(String, U32.is_lt(k, 10), "0", "") ++ U32.show(k)

def files(n: Nat, +d: U32, +f: U32) -> S.Tree<S.Blob>:
  match n:
    case 0n:
      S.TEnd{}
    case 1n+p:
      S.TItem{"f" ++ pad(f), S.TFile{content(d, f)}, files(p, d, (f + 1 : U32))}

def dirs(n: Nat, +d: U32, +k: Nat) -> S.Tree<S.Blob>:
  match n:
    case 0n:
      S.TEnd{}
    case 1n+p:
      S.TItem{"d" ++ pad(d), files(k, d, 0), dirs(p, (d + 1 : U32), k)}

# The octets in every file of the loaded tree.
def total(t: S.Tree<S.Blob>) -> U32:
  match t:
    case S.TFile{b}:
      S.Blob{+len, ws} = b
      len
    case S.TEnd{}:
      0
    case S.TItem{n, c, r}:
      (total(c) + total(r) : U32)

def loaded(m: Maybe<&2, S.Tree<S.Blob>>) -> U32:
  match m:
    case None{}:
      0
    case Some{t}:
      total(t)

# Indexes the committed objects, then loads the root back from the index.
def finish(r: String & S.Store<String, S.Blob>) -> String:
  (+root, objs) = r
  +s = S.Index.of(~String, ~S.Blob, ~Order.string, objs)
  root ++ "\t" ++ U32.show(loaded(S.Index.load(~String, ~S.Blob, ~Order.string, S.limit(), s, root)))

def side(args: List<&1, String>) -> U32:
  match args:
    case program <> n <> Nil{}:
      Maybe.default(&2, U32, U32.read(n), 16)
    case _:
      16

# The side comes from argv, so the work cannot run before the clock starts.
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +k : Nat = U32.to_nat(side(args))
    t : S.Tree<S.Blob> = dirs(k, 0, k)
    t0 : Time.Duration <- Time.mono()
    r : String & S.Store<String, S.Blob> <- IO.try(String & S.Store<String, S.Blob>, S.commit(t))
    IO.print("chk\tcommit\t" ++ finish(r))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tcommit\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
