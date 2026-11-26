# Storage benchmark: the Bend side (see README.md).
import Base
import bend-kit-bytes@0.3.3.2/bytes.bend as Bytes
import ../../time/time.bend as Time
import ../storage.bend as S
import ../pure.bend as P

# Octet j of file (d, f) is (d * 31 + f * 7 + j) & 255.
def fill(n: Nat, b: Bytes.Bytes, +j: U32, +seed: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      fill(p, Bytes.set(b, j, ((seed + j) .&. 255 : U32)), (j + 1 : U32), seed)

type Input is Type:
  File{bytes: Bytes.Bytes}
  End{}
  Item{name: String, child: Input, rest: Input}

def content(+d: U32, +f: U32) -> Bytes.Bytes:
  fill(4096n, Bytes.new(4096), 0, (d * 31 + f * 7 : U32))

def pad(+k: U32) -> String:
  Bool.pick(String, U32.is_lt(k, 10), "0", "") ++ U32.show(k)

def files(n: Nat, +d: U32, +f: U32) -> Input:
  match n:
    case 0n:
      End{}
    case 1n+p:
      Item{"f" ++ pad(f), File{content(d, f)}, files(p, d, (f + 1 : U32))}

def dirs(n: Nat, +d: U32, +k: Nat) -> Input:
  match n:
    case 0n:
      End{}
    case 1n+p:
      Item{"d" ++ pad(d), files(k, d, 0), dirs(p, (d + 1 : U32), k)}

def prepare(t: Input) -> S.Run(P.Tree<P.Blob>):
  match t:
    case File{bytes}:
      do S.Run<P.Tree<P.Blob>>:
        blob : P.Blob <- S.Blob.of(bytes)
        return P.TFile{blob}
    case End{}:
      S.Run.pure(P.Tree<P.Blob>, P.TEnd{})
    case Item{n, c, r}:
      do S.Run<P.Tree<P.Blob>>:
        child : P.Tree<P.Blob> <- prepare(c)
        rest : P.Tree<P.Blob> <- prepare(r)
        return P.TItem{n, child, rest}

# The octets in every file of the loaded tree.
def total(t: P.Tree<P.Blob>) -> U32:
  match t:
    case P.TFile{b}:
      P.Blob{+len, ws, digest} = b
      len
    case P.TEnd{}:
      0
    case P.TItem{n, c, r}:
      (total(c) + total(r) : U32)

def loaded(m: Maybe<&2, P.Tree<P.Blob>>) -> U32:
  match m:
    case None{}:
      0
    case Some{t}:
      total(t)

# Indexes the committed objects, then loads the root back from the index.
def finish(r: P.Digest & P.Store<P.Digest, P.Blob>) -> String:
  (+root, objs) = r
  +s = P.Index.of(~P.Digest, ~P.Blob, ~P.Digest.cmp, objs)
  P.Digest.hex(root) ++ "\t" ++ U32.show(loaded(P.Index.load(~P.Digest, ~P.Blob, ~P.Digest.cmp, P.limit(), s, root)))

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
    raw : Input = dirs(k, 0, k)
    t0 : Time.Duration <- Time.mono()
    t : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, prepare(raw))
    r : P.Digest & P.Store<P.Digest, P.Blob> <- IO.try(P.Digest & P.Store<P.Digest, P.Blob>, S.commit(t))
    IO.print("chk\tcommit\t" ++ finish(r))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tcommit\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
