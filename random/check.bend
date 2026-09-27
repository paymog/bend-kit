import Base
import ./random.bend as Rand

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def first(ur: F32 & Rand.Rng) -> F32:
  (u, r) = ur
  u

def perm(xr: List<&2, U32> & Rand.Rng) -> List<&2, U32>:
  (xs, r) = xr
  xs

def upto(n: Nat, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      acc
    case 1n+(+p):
      upto(p, U32.from_nat(p) <> acc)

def same(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      U32.is_eq(x, y) && same(xt, yt)
    case _ _:
      False{}

def state_eq(a: Rand.Rng, b: Rand.Rng) -> Bool:
  match a b:
    case Rand.Rng{a0, a1, a2, a3} Rand.Rng{b0, b1, b2, b3}:
      U32.is_eq(a0, b0) && U32.is_eq(a1, b1) && U32.is_eq(a2, b2) && U32.is_eq(a3, b3)

def main() -> IO(Unit):
  do IO<Unit>:
    +u : F32 = first(Rand.unit(Rand.seed(42)))
    require(F32.is_eq(u, F32.div(2579860.0, 16777216.0)), "unit draw is wrong")
    +xs : List<&2, U32> = upto(1000n, Nil{})
    +ys : List<&2, U32> = perm(Rand.shuffle(~U32, xs, Rand.seed(1)))
    require(Bool.not(same(xs, ys)), "shuffle left 1000 items in order")
    require(same(List.sort(~U32, ~U32.is_le, ys), xs), "shuffle is not a permutation")
    a : Rand.Rng <- IO.try(Rand.Rng, Rand.from_os())
    b : Rand.Rng <- IO.try(Rand.Rng, Rand.from_os())
    require(Bool.not(state_eq(a, b)), "two OS seeds are equal")
    IO.print("random ok")
