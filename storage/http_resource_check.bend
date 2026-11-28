import Base
import ./http_check.bend as Check

def run(fuel: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+ +p:
      do IO<Unit>:
        IO.print("HTTP storage lifecycle round " ++ Nat.show(1n+p))
        Check.run()
        run(p)

def main() -> IO(Unit):
  run(20n)
