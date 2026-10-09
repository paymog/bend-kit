# Bounded capacity pools with affine reservations: reserve, release, split, and combine.
import Base

# A pool of `capacity` units, `held` of them reserved. `owner` names the pool,
# so a reservation cannot return to a different pool.
type Pool is Data:
  Pool{owner: Nat, capacity: Nat, held: Nat}

# A reservation of `amount` units from the pool named `owner`. It is affine:
# it cannot be copied, so it is released at most once.
type Grant is Type:
  Grant{owner: Nat, amount: Nat}

type Reserve is Type:
  Took{pool: Pool, grant: Grant}
  Refused{pool: Pool}

type Release is Type:
  Released{pool: Pool}
  Kept{pool: Pool, grant: Grant}

type Split is Type:
  Parts{taken: Grant, rest: Grant}
  Whole{grant: Grant}

type Combine is Type:
  Joined{grant: Grant}
  Apart{first: Grant, second: Grant}

# An empty pool of `capacity` units.
def new(owner: Nat, capacity: Nat) -> Pool:
  Pool{owner, capacity, 0n}

def capacity(p: Pool) -> Nat:
  Pool{o, c, h} = p
  c

def reserved(p: Pool) -> Nat:
  Pool{o, c, h} = p
  h

# The units that a reserve can still take.
def available(p: Pool) -> Nat:
  Pool{o, c, h} = p
  Nat.sub(c, h)

def reserve.go(fits: Bool, +o: Nat, c: Nat, h: Nat, +n: Nat) -> Reserve:
  match fits:
    case True{}:
      Took{Pool{o, c, Nat.add(h, n)}, Grant{o, n}}
    case False{}:
      Refused{Pool{o, c, h}}

# Takes n units when they fit. Refused hands back the pool unchanged.
def reserve(p: Pool, +n: Nat) -> Reserve:
  Pool{o, +c, +h} = p
  reserve.go(Nat.is_le(Nat.add(h, n), c), o, c, h, n)

def release.go(ok: Bool, o: Nat, c: Nat, h: Nat, q: Nat, +n: Nat) -> Release:
  match ok:
    case True{}:
      Released{Pool{o, c, Nat.sub(h, n)}}
    case False{}:
      Kept{Pool{o, c, h}, Grant{q, n}}

# Returns g's units to p. Kept hands back both unchanged when g names another
# pool or holds more than p has reserved.
def release(p: Pool, g: Grant) -> Release:
  Pool{+o, c, +h} = p
  Grant{+q, +n} = g
  release.go(Nat.is_eq(o, q) && Nat.is_le(n, h), o, c, h, q, n)

def split.go(fits: Bool, +o: Nat, +a: Nat, +n: Nat) -> Split:
  match fits:
    case True{}:
      Parts{Grant{o, n}, Grant{o, Nat.sub(a, n)}}
    case False{}:
      Whole{Grant{o, a}}

# Splits n units off g. Whole hands back g when it holds fewer than n.
def split(g: Grant, +n: Nat) -> Split:
  Grant{+o, +a} = g
  split.go(Nat.is_le(n, a), o, a, n)

def combine.go(same: Bool, o: Nat, a: Nat, q: Nat, b: Nat) -> Combine:
  match same:
    case True{}:
      Joined{Grant{o, Nat.add(a, b)}}
    case False{}:
      Apart{Grant{o, a}, Grant{q, b}}

# Joins two grants of one pool. Apart hands back both when their pools differ.
def combine(x: Grant, y: Grant) -> Combine:
  Grant{+o, a} = x
  Grant{+q, b} = y
  combine.go(Nat.is_eq(o, q), o, a, q, b)
