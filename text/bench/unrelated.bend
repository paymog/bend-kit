# Diff of two inputs with no common line: the worst case for Myers (see README.md).
import Base
import ../../time/time.bend as Time
import ../text.bend as T

def side(n: Nat, +name: String, +i: U32) -> List<&2, String>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      (name ++ " " ++ U32.show(i)) <> side(p, name, (i + 1 : U32))

def changes(es: List<&2, T.Edit<String>>, +n: U32) -> U32:
  match es:
    case Nil{}:
      n
    case Con{T.Same{_, _}, t}:
      changes(t, n)
    case Con{_, t}:
      changes(t, (n + 1 : U32))

def lines(args: List<&1, String>) -> U32:
  match args:
    case program <> n <> Nil{}:
      Maybe.default(&2, U32, U32.read(n), 1000)
    case _:
      1000

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +n : Nat = U32.to_nat(lines(args))
    t0 : Time.Duration <- Time.mono()
    IO.print("chk\tunrelated\t" ++ U32.show(changes(T.diff(~String, ~String.eq, side(n, "a", 0), side(n, "b", 0)), 0)))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tunrelated\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
