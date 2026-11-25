import Base
import ../check.bend as Check
import ../redis.bend as R

def count(m: Maybe<&1, R.Val>) -> Nat:
  match m:
    case Some{R.Arr{xs}}:
      List.length(&1, R.Val, xs)
    case _:
      0n

def timed(t0: Nat, n: Nat) -> IO(Unit):
  do IO<Unit>:
    t1 : Nat <- IO.now()
    IO.print(Nat.show((t1 - t0 : Nat)) ++ " ms\t" ++ Nat.show(n) ++ " items")

def main() -> IO(Unit):
  b = Check.arr(4000)
  do IO<Unit>:
    t0 : Nat <- IO.now()
    timed(t0, count(Check.chunks(b, 32)))
