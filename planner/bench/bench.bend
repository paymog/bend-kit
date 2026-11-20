# Planner benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../planner.bend as P
import bend-kit-collections@0.1.5.0/order.bend as Order

def id(+i: U32) -> String:
  "n" ++ U32.show(i)

# Up to k ids from j on, below n.
def deps(k: Nat, +j: U32, +n: U32) -> List<&2, String>:
  match k:
    case 0n:
      Nil{}
    case 1n+m:
      Bool.pick(List<&2, String>, (j < n : U32), id(j) <> deps(m, (j + 1 : U32), n), Nil{})

# Node i requires nodes i + 1, i + 2, and i + 3, when they exist.
def graph(k: Nat, +i: U32, +n: U32) -> List<&2, P.Node<String>>:
  match k:
    case 0n:
      Nil{}
    case 1n+m:
      P.Node{id(i), deps(3n, (i + 1 : U32), n)} <> graph(m, (i + 1 : U32), n)

def number(s: String) -> U32:
  match s:
    case SCon{c, t}:
      Maybe.default(&2, U32, U32.read(t), 0)
    case SNil{}:
      0

# The length of the plan plus the sum of its node numbers.
def sum(p: List<&2, String>, acc: U32) -> U32:
  match p:
    case Nil{}:
      acc
    case Con{x, t}:
      sum(t, (acc + 1 + number(x) : U32))

def check(r: Result<&2, &2, P.Error<String>, List<&2, String>>) -> U32:
  match r:
    case Done{p}:
      sum(p, 0)
    case Fail{e}:
      0

def rounds(k: Nat, +g: List<&2, P.Node<String>>, acc: U32) -> U32:
  match k:
    case 0n:
      acc
    case 1n+m:
      rounds(m, g, (acc + check(P.plan.fast(~String, ~String.eq, ~Order.string, g, ["n0"])) : U32))

def arg(args: List<&1, String>) -> U32:
  match args:
    case program <> r <> Nil{}:
      Maybe.default(&2, U32, U32.read(r), 4)
    case _:
      4

# The node count and the rounds come from argv, so the work cannot run before the clock starts.
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    +n : U32 = 1000
    +r : U32 = arg(args)
    +g : List<&2, P.Node<String>> = graph(U32.to_nat(n), 0, n)
    t0 : Time.Duration <- Time.mono()
    +v : U32 = rounds(U32.to_nat(r), g, 0)
    IO.print("chk\tplan\t" ++ U32.show(v))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tplan\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
