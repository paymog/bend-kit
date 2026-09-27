# Concurrency benchmark: par_map of one CPU-bound job over 64 inputs, on 1 and 8 workers (see README.md).
import Base
import ../concurrency.bend as Conc

# 2^20 rounds of x = (x ^ x >> 13) * 1664525 + 1013904223, in wrapping u32.
def spin(n: Nat, +x: U32) -> U32:
  match n:
    case 0n:
      x
    case 1n+p:
      spin(p, ((x .^. (x >> 13n)) * 1664525 + 1013904223 : U32))

def job(x: U32) -> U32:
  spin(1048576n, x)

def upto(n: Nat, acc: List<U32>) -> List<U32>:
  match n:
    case 0n:
      acc
    case 1n+(+p):
      upto(p, U32.from_nat(p) <> acc)

# Checksum: h = h*31 + x over the results in order, u32.
def hash(xs: List<U32>, h: U32) -> U32:
  match xs:
    case Nil{}:
      h
    case x <> t:
      hash(t, (h * 31 + x : U32))

# Bend evaluates strictly: the results are built before t1 is read.
def stop(+name: String, t0: Nat, ys: List<U32>) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    IO.print(name ++ "\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(hash(ys, 0)))

def op(+name: String, +w: U32) -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    stop(name, t0, Conc.par_map(~U32, ~U32, ~job, w, upto(64n, Nil{})))

def main() -> IO(Unit):
  do IO<Unit>:
    op("map_1", 1)
    op("map_8", 8)
