import Base
import ./bench.bend as Bench

def name(pattern: U32) -> String:
  match pattern:
    case 0:
      "zero"
    case 1:
      "incrementing"
    case _:
      "mixed"

def rows(n: Nat, +index: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      +pattern = (index / 3 : U32)
      do IO<Unit>:
        Bench.matrix.lengths([(31 + index % 3 : U32)], pattern, name(pattern))
        rows(p, ((index + 1) % 9 : U32))

def rounds(n: Nat, +start: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        rows(9n, start)
        rounds(p, (start + 1 : U32))

def main() -> IO(Unit):
  rounds(9n, 0)
