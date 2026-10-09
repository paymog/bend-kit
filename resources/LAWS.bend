import Base
import bend-mathlib@0.7.2.0/nat.bend as MNat
import ./resources.bend as Res

# A grant as copyable data.
type Held is Data:
  Held{owner: Nat, amount: Nat}

def grant(g: Res.Grant) -> Held:
  Res.Grant{o, n} = g
  Held{o, n}

# The pool after a reserve, and the grant it took, if any.
def reserve.view(r: Res.Reserve) -> Res.Pool & Maybe<&2, Held>:
  match r:
    case Res.Took{p, g}:
      (p, Some{grant(g)})
    case Res.Refused{p}:
      (p, None{})

def reserve.pool(r: Res.Reserve) -> Res.Pool:
  match r:
    case Res.Took{p, g}:
      p
    case Res.Refused{p}:
      p

# The pool after a release, and the grant it kept, if any.
def release.view(r: Res.Release) -> Res.Pool & Maybe<&2, Held>:
  match r:
    case Res.Released{p}:
      (p, None{})
    case Res.Kept{p, g}:
      (p, Some{grant(g)})

def release.pool(r: Res.Release) -> Res.Pool:
  match r:
    case Res.Released{p}:
      p
    case Res.Kept{p, g}:
      p

# Reserves, then releases what the reserve took.
def round_trip(r: Res.Reserve) -> Res.Pool:
  match r:
    case Res.Took{p, g}:
      release.pool(Res.release(p, g))
    case Res.Refused{p}:
      p

def split.view(s: Res.Split) -> List<&2, Held>:
  match s:
    case Res.Parts{x, y}:
      [grant(x), grant(y)]
    case Res.Whole{g}:
      [grant(g)]

def combine.view(c: Res.Combine) -> List<&2, Held>:
  match c:
    case Res.Joined{g}:
      [grant(g)]
    case Res.Apart{x, y}:
      [grant(x), grant(y)]

# The sum of the amounts in a view.
def total(xs: List<&2, Held>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Held{o, n} <> t:
      Nat.add(n, total(t))

# In a valid pool, the available and reserved units sum to the capacity.
law available_add_reserved:
  for o: Nat
  for c: Nat
  for h: Nat
  for e: MNat.le(h, c)
  {Nat.add(Res.available(Res.Pool{o, c, h}), Res.reserved(Res.Pool{o, c, h})) == c : Nat}

# A reserve that fits takes exactly n units and grants them.
law reserve_admits:
  for o: Nat
  for c: Nat
  for h: Nat
  for n: Nat
  for e: MNat.le(Nat.add(h, n), c)
  {reserve.view(Res.reserve(Res.Pool{o, c, h}, n)) == (Res.Pool{o, c, Nat.add(h, n)}, Some{Held{o, n}}) : Res.Pool & Maybe<&2, Held>}

# A reserve that does not fit leaves the pool unchanged and grants nothing.
law reserve_rejects:
  for o: Nat
  for c: Nat
  for h: Nat
  for n: Nat
  for e: {Nat.is_le(Nat.add(h, n), c) == False{} : Bool}
  {reserve.view(Res.reserve(Res.Pool{o, c, h}, n)) == (Res.Pool{o, c, h}, None{}) : Res.Pool & Maybe<&2, Held>}

# A reserve keeps the capacity.
law reserve_capacity:
  for o: Nat
  for c: Nat
  for h: Nat
  for n: Nat
  {Res.capacity(reserve.pool(Res.reserve(Res.Pool{o, c, h}, n))) == c : Nat}

# A reserve on a valid pool never holds more than the capacity.
law reserve_bounded:
  for o: Nat
  for c: Nat
  for h: Nat
  for n: Nat
  for e: MNat.le(h, c)
  MNat.le(Res.reserved(reserve.pool(Res.reserve(Res.Pool{o, c, h}, n))), c)

# Releasing what a reserve took restores the pool exactly.
law reserve_release:
  for o: Nat
  for c: Nat
  for h: Nat
  for n: Nat
  {round_trip(Res.reserve(Res.Pool{o, c, h}, n)) == Res.Pool{o, c, h} : Res.Pool}

# A release of a grant of this pool, within what it holds, frees exactly its units.
law release_frees:
  for o: Nat
  for c: Nat
  for h: Nat
  for n: Nat
  for e: MNat.le(n, h)
  {release.view(Res.release(Res.Pool{o, c, h}, Res.Grant{o, n})) == (Res.Pool{o, c, Nat.sub(h, n)}, None{}) : Res.Pool & Maybe<&2, Held>}

# A grant of another pool changes nothing and comes back.
law release_foreign:
  for o: Nat
  for c: Nat
  for h: Nat
  for q: Nat
  for n: Nat
  for e: {Nat.is_eq(o, q) == False{} : Bool}
  {release.view(Res.release(Res.Pool{o, c, h}, Res.Grant{q, n})) == (Res.Pool{o, c, h}, Some{Held{q, n}}) : Res.Pool & Maybe<&2, Held>}

# A grant larger than the reserved units changes nothing and comes back.
law release_excess:
  for o: Nat
  for c: Nat
  for h: Nat
  for q: Nat
  for n: Nat
  for e: {Nat.is_le(n, h) == False{} : Bool}
  {release.view(Res.release(Res.Pool{o, c, h}, Res.Grant{q, n})) == (Res.Pool{o, c, h}, Some{Held{q, n}}) : Res.Pool & Maybe<&2, Held>}

# Any release, of any grant, keeps the capacity and keeps a valid pool valid.
law release_capacity:
  for o: Nat
  for c: Nat
  for h: Nat
  for q: Nat
  for n: Nat
  {Res.capacity(release.pool(Res.release(Res.Pool{o, c, h}, Res.Grant{q, n}))) == c : Nat}

law release_bounded:
  for o: Nat
  for c: Nat
  for h: Nat
  for q: Nat
  for n: Nat
  for e: MNat.le(h, c)
  MNat.le(Res.reserved(release.pool(Res.release(Res.Pool{o, c, h}, Res.Grant{q, n}))), c)

# A split that fits gives two grants of the same pool.
law split_parts:
  for o: Nat
  for a: Nat
  for n: Nat
  for e: MNat.le(n, a)
  {split.view(Res.split(Res.Grant{o, a}, n)) == [Held{o, n}, Held{o, Nat.sub(a, n)}] : List<&2, Held>}

# A split conserves the reserved units.
law split_total:
  for o: Nat
  for a: Nat
  for n: Nat
  {total(split.view(Res.split(Res.Grant{o, a}, n))) == a : Nat}

# Two grants of one pool join into one grant of their sum.
law combine_joins:
  for o: Nat
  for a: Nat
  for b: Nat
  {combine.view(Res.combine(Res.Grant{o, a}, Res.Grant{o, b})) == [Held{o, Nat.add(a, b)}] : List<&2, Held>}

# Grants of two pools stay apart, unchanged.
law combine_apart:
  for o: Nat
  for a: Nat
  for q: Nat
  for b: Nat
  for e: {Nat.is_eq(o, q) == False{} : Bool}
  {combine.view(Res.combine(Res.Grant{o, a}, Res.Grant{q, b})) == [Held{o, a}, Held{q, b}] : List<&2, Held>}

# A combine conserves the reserved units.
law combine_total:
  for o: Nat
  for a: Nat
  for q: Nat
  for b: Nat
  {total(combine.view(Res.combine(Res.Grant{o, a}, Res.Grant{q, b}))) == Nat.add(a, b) : Nat}
