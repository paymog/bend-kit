# resources

Bounded capacity pools with affine reservations. Use one for connection slots, worker capacity, memory budgets, or tenant quotas.

```bend
import bend-kit-resources@0.1.0.0/resources.bend as Res
```

## Example

```bend
import Base
import bend-kit-resources@0.1.0.0/resources.bend as Res

def freed(r: Res.Release) -> Nat:
  match r:
    case Res.Released{+pool}:
      Res.available(pool)
    case Res.Kept{pool, grant}:
      0n

def took(r: Res.Reserve) -> Nat:
  match r:
    case Res.Took{pool, grant}:
      freed(Res.release(pool, grant))
    case Res.Refused{pool}:
      0n

def main() -> Nat:
  took(Res.reserve(Res.new(7n, 4n), 3n))
```

`main` reserves 3 of 4 units, releases them, and answers 4.

## API

| def | answers |
|---|---|
| `new(owner, capacity)` | an empty `Pool{owner, capacity, 0n}` |
| `capacity(p)`, `reserved(p)`, `available(p)` | the units in all, the units held, and `capacity - held` |
| `reserve(p, n)` | `Took{pool, grant}` when `held + n <= capacity`, else `Refused{p}` |
| `release(p, g)` | `Released{pool}` when `g` names `p` and `g.amount <= held`, else `Kept{p, g}` |
| `split(g, n)` | `Parts{n units, the rest}` when `n <= g.amount`, else `Whole{g}` |
| `combine(x, y)` | `Joined{x + y}` when both name one pool, else `Apart{x, y}` |

A refused or kept operation hands back what it was given, unchanged. Counts are `Nat`.

## Invariants

`LAWS.bend` states these for every pool `Pool{o, c, h}`, every amount, and every owner. `PROOF.bend` proves them.

| law | claim |
|---|---|
| `available_add_reserved` | if `h <= c`, then `available + reserved = c` |
| `reserve_admits` | if `h + n <= c`, reserve holds `h + n` and grants `n` |
| `reserve_rejects` | otherwise, reserve leaves the pool unchanged and grants nothing |
| `reserve_capacity` | reserve keeps the capacity |
| `reserve_bounded` | if `h <= c`, the reserved units after a reserve stay at most `c` |
| `reserve_release` | releasing what a reserve took gives back the original pool |
| `release_frees` | a grant of this pool, with `n <= h`, frees exactly `n` units |
| `release_foreign` | a grant of another pool changes nothing and comes back |
| `release_excess` | a grant larger than `h` changes nothing and comes back |
| `release_capacity` | any release keeps the capacity |
| `release_bounded` | if `h <= c`, any release keeps the reserved units at most `c` |
| `split_parts` | a split that fits gives `n` and `a - n`, both of the same pool |
| `split_total` | every split keeps the total amount |
| `combine_joins` | two grants of one pool join into one grant of their sum |
| `combine_apart` | grants of two pools stay apart, unchanged |
| `combine_total` | every combine keeps the total amount |

## Ownership

These guarantees come from the types, not from the laws:

- A `Grant` is `Type`, so it cannot be copied. A grant is released at most once.
- `release`, `split`, and `combine` consume their grants. A refused or kept result hands the grant back, so the caller still owns it.
- A `Pool` is `Data`. Copying a pool copies its numbers, not its capacity. Keep one current pool in one owner, such as an actor.

## Trust boundary

- Bend has no private constructors. Code can write `Res.Grant{o, n}` without a reserve. `release` checks the owner and `n <= held`, so a forged grant cannot make a pool hold less than zero or free more than its capacity (`release_bounded`, `release_capacity`). It can still free units that another grant holds.
- Owner identity is a `Nat` that you choose. Give each pool its own owner.
- Dropping a grant is allowed, as with every affine value. The units stay reserved. Nothing returns them.
- The laws are about pure values. They do not cover concurrent access, crash recovery, or whether the host really has the resource. A shared pool needs one owner that serializes every operation.

`http` admission is that owner for its connection, active, and buffered pools. One actor holds each pool and one grant that joins every unit it took. A take reserves one unit and joins it; a give splits one unit off and releases it. A connection takes a connection unit and a buffered unit together, and returns the connection unit when the buffer pool refuses. Callers pair each successful take with one give; that pairing is the trust assumption. A give with no take stops the server instead of wrapping a counter.

## Checks

`bend check.bend` reserves until a pool is full, sees the refusal leave it unchanged, releases, admits again, refuses a foreign grant, and splits a joined grant. `http/check.bend` runs the same exhaustion, refusal, release, and renewed admission against the real admission actor. `bench/` times the lease hot path. See [bench/README.md](bench/README.md).
