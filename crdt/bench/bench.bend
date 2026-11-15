# CRDT benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../crdt.bend as Crdt

# 0 on overflow, which the checksum shows.
def inc.or(m: Maybe<&2, List<&2, U32>>) -> List<&2, U32>:
  match m:
    case None{}:
      Nil{}
    case Some{s}:
      s

# Replica r increments its own entry.
def incs(xs: List<&2, List<&2, U32>>, +r: Nat) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{s, t}:
      Con{inc.or(Crdt.GCounter.inc(s, r)), incs(t, 1n+r)}

def merges(xs: List<&2, List<&2, U32>>, ys: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs ys:
    case Con{x, xt} Con{y, yt}:
      Con{Crdt.GCounter.merge(x, y), merges(xt, yt)}
    case _ _:
      Nil{}

def rotate(xs: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      List.append(&2, List<&2, U32>, t, [h])

# Each replica counts one event, then merges the state its successor held.
def rounds(n: Nat, +xs: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match n:
    case 0n:
      xs
    case 1n+p:
      +ys = incs(xs, 0n)
      rounds(p, merges(ys, rotate(ys)))

def checksum(xs: List<&2, List<&2, U32>>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{s, t}:
      checksum(t, (acc + Maybe.default(&2, U32, Crdt.GCounter.value(s), 0) : U32))

def kinc.or(m: Maybe<&2, Crdt.KCounter<U32>>) -> Crdt.KCounter<U32>:
  match m:
    case None{}:
      Crdt.KNil{}
    case Some{s}:
      s

# Replica r has ID r * 250000000 + 7, so IDs are far apart.
def kincs(xs: List<&2, Crdt.KCounter<U32>>, +r: U32) -> List<&2, Crdt.KCounter<U32>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{s, t}:
      Con{kinc.or(Crdt.KCounter.inc(~U32, ~U32.cmp, s, (r * 250000000 + 7 : U32))), kincs(t, (r + 1 : U32))}

def kmerges(xs: List<&2, Crdt.KCounter<U32>>, ys: List<&2, Crdt.KCounter<U32>>) -> List<&2, Crdt.KCounter<U32>>:
  match xs ys:
    case Con{x, xt} Con{y, yt}:
      Con{Crdt.KCounter.merge(~U32, ~U32.cmp, x, y), kmerges(xt, yt)}
    case _ _:
      Nil{}

def krotate(xs: List<&2, Crdt.KCounter<U32>>) -> List<&2, Crdt.KCounter<U32>>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      List.append(&2, Crdt.KCounter<U32>, t, [h])

def krounds(n: Nat, +xs: List<&2, Crdt.KCounter<U32>>) -> List<&2, Crdt.KCounter<U32>>:
  match n:
    case 0n:
      xs
    case 1n+p:
      +ys = kincs(xs, 0)
      krounds(p, kmerges(ys, krotate(ys)))

def kchecksum(xs: List<&2, Crdt.KCounter<U32>>, +acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{s, t}:
      kchecksum(t, (acc + Maybe.default(&2, U32, Crdt.KCounter.value(U32, s), 0) : U32))

def lg(args: List<&1, String>) -> Nat:
  match args:
    case program <> n <> Nil{}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(n), 14))
    case _:
      14n

# The rounds come from argv, so the work cannot be computed before the clock starts.
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +n : Nat = Nat.pow(2n, lg(args))
    t0 : Time.Duration <- Time.mono()
    +start : List<&2, List<&2, U32>> = List.replicate(List<&2, U32>, 16n, Crdt.GCounter.new())
    +v : U32 = checksum(rounds(n, start), 0)
    IO.print("chk\tgossip\t" ++ U32.show(v))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tgossip\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
    t2 : Time.Duration <- Time.mono()
    +kstart : List<&2, Crdt.KCounter<U32>> = List.replicate(Crdt.KCounter<U32>, 16n, Crdt.KCounter.new(U32))
    +kv : U32 = kchecksum(krounds(n, kstart), 0)
    IO.print("chk\tgossip-sparse\t" ++ U32.show(kv))
    t3 : Time.Duration <- Time.mono()
    IO.print("ms\tgossip-sparse\t" ++ Time.Duration.show_ms(Time.Duration.sub(t3, t2)))
