import Base
import ./resources.bend as Res

def ok(good: Bool, +name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad " ++ name)

def show(+p: Res.Pool) -> String:
  Nat.show(Res.available(p)) ++ "/" ++ Nat.show(Res.reserved(p)) ++ "/" ++ Nat.show(Res.capacity(p))

def amount(g: Res.Grant) -> Nat:
  Res.Grant{o, n} = g
  n

def parts(s: Res.Split, +p: Res.Pool) -> IO(Unit):
  match s:
    case Res.Whole{g}:
      IO.die(Unit, 1, "bad a split that fits was refused")
    case Res.Parts{x, y}:
      ok(Nat.is_eq(amount(x), 1n) && Nat.is_eq(amount(y), 2n), "a split keeps the reserved units")

def foreign(r: Res.Release, +p: Res.Pool) -> IO(Unit):
  match r:
    case Res.Released{q}:
      IO.die(Unit, 1, "bad another pool took a foreign grant")
    case Res.Kept{q, g}:
      parts(Res.split(g, 1n), p)

def joined(c: Res.Combine, +p: Res.Pool) -> IO(Unit):
  match c:
    case Res.Apart{x, y}:
      IO.die(Unit, 1, "bad grants of one pool stayed apart")
    case Res.Joined{g}:
      foreign(Res.release(Res.Pool{9n, 8n, 8n}, g), p)

def renewed(r: Res.Reserve, kept: Res.Grant) -> IO(Unit):
  match r:
    case Res.Refused{p}:
      IO.die(Unit, 1, "bad freed units were not admitted again")
    case Res.Took{+p, g}:
      do IO<Unit>:
        ok(String.eq(show(p), "1/3/4"), "freed units admit again")
        joined(Res.combine(g, kept), p)

def released(r: Res.Release, kept: Res.Grant) -> IO(Unit):
  match r:
    case Res.Kept{p, g}:
      IO.die(Unit, 1, "bad a release of this pool's grant was kept")
    case Res.Released{+p}:
      do IO<Unit>:
        ok(String.eq(show(p), "3/1/4"), "a release frees exactly its units")
        renewed(Res.reserve(p, 2n), kept)

# The second reserve takes the last units; the third finds the pool full.
def full(r: Res.Reserve, first: Res.Grant, second: Res.Grant) -> IO(Unit):
  match r:
    case Res.Took{p, g}:
      IO.die(Unit, 1, "bad an exhausted pool admitted a reserve")
    case Res.Refused{+p}:
      do IO<Unit>:
        ok(String.eq(show(p), "0/4/4"), "a full pool refuses and stays unchanged")
        released(Res.release(p, second), first)

def second(r: Res.Reserve, a: Res.Grant) -> IO(Unit):
  match r:
    case Res.Refused{p}:
      IO.die(Unit, 1, "bad a reserve that fits was refused")
    case Res.Took{p, b}:
      full(Res.reserve(p, 1n), a, b)

def first(r: Res.Reserve) -> IO(Unit):
  match r:
    case Res.Refused{p}:
      IO.die(Unit, 1, "bad an empty pool refused a reserve")
    case Res.Took{p, a}:
      second(Res.reserve(p, 3n), a)

def main() -> IO(Unit):
  first(Res.reserve(Res.new(0n, 4n), 1n))
