# Resources benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../resources.bend as Res

# A lease as the http admission ledger keeps it: the pool, and one grant that
# joins every unit taken from it.
type State is Type:
  State{pool: Res.Pool, held: Res.Grant, admitted: U32, refused: U32}

def take.joined(c: Res.Combine, pool: Res.Pool, +admitted: U32, refused: U32) -> State:
  match c:
    case Res.Joined{g}:
      State{pool, g, (admitted + 1 : U32), refused}
    case Res.Apart{x, y}:
      State{pool, x, admitted, refused}

def take.took(r: Res.Reserve, held: Res.Grant, admitted: U32, +refused: U32) -> State:
  match r:
    case Res.Took{p, g}:
      take.joined(Res.combine(held, g), p, admitted, refused)
    case Res.Refused{p}:
      State{p, held, admitted, (refused + 1 : U32)}

def take(s: State) -> State:
  State{pool, held, a, r} = s
  take.took(Res.reserve(pool, 1n), held, a, r)

def give.released(r: Res.Release, rest: Res.Grant, admitted: U32, refused: U32) -> State:
  match r:
    case Res.Released{p}:
      State{p, rest, admitted, refused}
    case Res.Kept{p, g}:
      State{p, rest, admitted, refused}

def give.split(s: Res.Split, pool: Res.Pool, admitted: U32, refused: U32) -> State:
  match s:
    case Res.Parts{one, rest}:
      give.released(Res.release(pool, one), rest, admitted, refused)
    case Res.Whole{g}:
      State{pool, g, admitted, refused}

def give(s: State) -> State:
  State{pool, held, a, r} = s
  give.split(Res.split(held, 1n), pool, a, r)

def takes(n: Nat, s: State) -> State:
  match n:
    case 0n:
      s
    case 1n+p:
      takes(p, take(s))

def gives(n: Nat, s: State) -> State:
  match n:
    case 0n:
      s
    case 1n+p:
      gives(p, give(s))

# Each round takes 65 units of a 64-unit pool, so one is refused, then gives 64 back.
def rounds(n: Nat, s: State) -> State:
  match n:
    case 0n:
      s
    case 1n+p:
      rounds(p, gives(64n, takes(65n, s)))

def checksum(s: State) -> U32:
  State{pool, held, a, r} = s
  (a * 31 + r : U32)

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
    +v : U32 = checksum(rounds(n, State{Res.new(0n, 64n), Res.Grant{0n, 0n}, 0, 0}))
    IO.print("chk\tlease\t" ++ U32.show(v))
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tlease\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))
