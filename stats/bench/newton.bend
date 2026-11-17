import Base
import ./bench.bend as B
import ../stats.bend as S
import bend-kit-stats@0.1.7.0/stats.bend as Old

def baseline(a: U32, b: U32) -> U32:
  Old.U32.isqrt(a)

def pair(a: U32, b: U32) -> U32:
  S.U32.isqrt(a)

def run(+n: Nat) -> IO(Unit):
  +count = Nat.add(n, 55n)
  depth = {1n+U32.log2(U32.from_nat(Nat.double(count))) : Nat}
  words = B.packed.fill(B.integer.inputs(n), 0, Array.new(U32, depth, 0))
  do IO<Unit>:
    words : Array<U32> <- B.packed.time(~B.integer.identity, "packed_identity", count, words)
    words : Array<U32> <- B.packed.time(~baseline, "baseline", count, words)
    words : Array<U32> <- B.packed.time(~pair, "candidate", count, words)
    B.packed.finish(words[0])

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run(B.integer.count(args))
