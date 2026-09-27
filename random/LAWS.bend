import Base
import ./random.bend as Rand

# n draws of f, where xr is the next draw.
def draws.go(~f: Rand.Rng -> U32 & Rand.Rng, n: Nat, xr: U32 & Rand.Rng) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      (x, r) = xr
      x <> draws.go(~f, p, f(r))

def draws(~f: Rand.Rng -> U32 & Rand.Rng, n: Nat, r: Rand.Rng) -> List<&2, U32>:
  draws.go(~f, n, f(r))

def perm(xr: List<&2, U32> & Rand.Rng) -> List<&2, U32>:
  (xs, r) = xr
  xs

law next_reference:
  {draws(~Rand.next, 4n, Rand.from_state(1, 2, 3, 4)) == [11520, 0, 5927040, 70819200] : List<&2, U32>}

law seed_splitmix32:
  {Rand.seed(42) == Rand.Rng{551831576, 144025891, 322543647, 3034809370} : Rand.Rng}

law seed_stream:
  {draws(~Rand.next, 4n, Rand.seed(42)) == [660444221, 3652823732, 77672526, 910233633] : List<&2, U32>}

law from_state_zero:
  {Rand.from_state(0, 0, 0, 0) == Rand.seed(0) : Rand.Rng}

law below_zero:
  for r: Rand.Rng
  {Rand.below(0, r) == (0, r) : U32 & Rand.Rng}

law below_one:
  for r: Rand.Rng
  {Rand.below(1, r) == (0, r) : U32 & Rand.Rng}

law below_die:
  {draws(~(r => Rand.below(6, r)), 5n, Rand.seed(42)) == [5, 2, 0, 3, 0] : List<&2, U32>}

# 2^32 mod 3e9 is 1294967296, so this bound rejects draws below it.
law below_large:
  {draws(~(r => Rand.below(3000000000, r)), 4n, Rand.seed(7))
    == [993689120, 1089369890, 1706118055, 2746022466] : List<&2, U32>}

law range_offset:
  {draws(~(r => Rand.range(10, 16, r)), 5n, Rand.seed(42)) == [15, 12, 10, 13, 10] : List<&2, U32>}

law range_empty:
  for r: Rand.Rng
  {Rand.range(5, 5, r) == (5, r) : U32 & Rand.Rng}

law shuffle_nil:
  for r: Rand.Rng
  {Rand.shuffle(~U32, Nil{}, r) == (Nil{}, r) : List<&2, U32> & Rand.Rng}

law shuffle_one:
  for r: Rand.Rng
  {Rand.shuffle(~U32, [7], r) == ([7], r) : List<&2, U32> & Rand.Rng}

law shuffle_eight:
  {perm(Rand.shuffle(~U32, [1, 2, 3, 4, 5, 6, 7, 8], Rand.seed(42)))
    == [2, 5, 3, 7, 4, 1, 8, 6] : List<&2, U32>}
