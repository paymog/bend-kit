import Base
import bend-mathlib@0.7.2.0/nat.bend as MNat
import ./cache.bend as C

# One operation on one key, in the order the cache sees it.
type Op<-V: Data> is Data:
  Start{}
  Complete{gen: Nat, at: Nat, found: C.Found<V>}
  Invalidate{}
  Evict{}

def step(-V: Data, p: C.Policy, o: Op<V>, s: C.Slot<V>) -> C.Slot<V>:
  match o:
    case Start{}:
      Pair.snd(Nat, C.Slot<V>, C.Slot.start(V, s))
    case Complete{g, at, r}:
      C.Slot.complete(V, p, s, g, at, r)
    case Invalidate{}:
      C.Slot.invalidate(V, s)
    case Evict{}:
      C.Slot.evict(V, s)

# The slot after each operation of os, in order.
def run(-V: Data, os: List<&2, Op<V>>, +p: C.Policy, s: C.Slot<V>) -> C.Slot<V>:
  match os:
    case Nil{}:
      s
    case Con{o, t}:
      run(V, t, p, step(V, p, o, s))

def next(-V: Data, s: C.Slot<V>) -> Nat:
  C.Slot{n, f, m} = s
  n

def floor(-V: Data, s: C.Slot<V>) -> Nat:
  C.Slot{n, f, m} = s
  f

# Every reachable slot has floor <= next.
def valid(-V: Data, +s: C.Slot<V>) -> Data:
  MNat.le(floor(V, s), next(V, s))

# A read answer is fresh at now: None, or an entry that has not expired.
def fresh(-V: Data, r: Maybe<&2, C.Entry<V>>, +now: Nat) -> Bool:
  match r:
    case None{}:
      True{}
    case Some{e}:
      Nat.is_lt(now, C.Entry.expires(V, e))

# Expiry
# ------

# A read never serves an expired entry.
law read_fresh:
  for -V: Data
  for s: C.Slot<V>
  for +now: Nat
  {fresh(V, C.Slot.read(V, s, now), now) == True{} : Bool}

# An entry that has not expired is served as it is.
law read_serves:
  for -V: Data
  for n: Nat
  for f: Nat
  for +e: C.Entry<V>
  for +now: Nat
  for h: MNat.lt(now, C.Entry.expires(V, e))
  {C.Slot.read(V, C.Slot{n, f, Some{e}}, now) == Some{e} : Maybe<&2, C.Entry<V>>}

# An expired entry is not served.
law read_expired:
  for -V: Data
  for n: Nat
  for f: Nat
  for +e: C.Entry<V>
  for +now: Nat
  for h: MNat.le(C.Entry.expires(V, e), now)
  {C.Slot.read(V, C.Slot{n, f, Some{e}}, now) == None{} : Maybe<&2, C.Entry<V>>}

# Generations
# -----------

law new_valid:
  for -V: Data
  valid(V, C.Slot.new(V))

# Every operation keeps a slot valid.
law run_valid:
  for -V: Data
  for os: List<&2, Op<V>>
  for +p: C.Policy
  for s: C.Slot<V>
  for h: valid(V, s)
  valid(V, run(V, os, p, s))

# The floor never goes down.
law run_floor:
  for -V: Data
  for os: List<&2, Op<V>>
  for +p: C.Policy
  for s: C.Slot<V>
  for h: valid(V, s)
  MNat.le(floor(V, s), floor(V, run(V, os, p, s)))

# A fresh fetch lands: its result is stored and the floor passes it.
law start_lands:
  for -V: Data
  for p: C.Policy
  for +n: Nat
  for f: Nat
  for m: Maybe<&2, C.Entry<V>>
  for h: MNat.le(f, n)
  for at: Nat
  for r: C.Found<V>
  {C.Slot.complete(V, p, Pair.snd(Nat, C.Slot<V>, C.Slot.start(V, C.Slot{n, f, m})), Pair.fst(Nat, C.Slot<V>, C.Slot.start(V, C.Slot{n, f, m})), at, r)
   == C.Slot{1n+n, 1n+n, Some{C.Entry.of(V, r, p, at)}} : C.Slot<V>}

# A completion of an issued generation at or above the floor is stored.
law complete_lands:
  for -V: Data
  for p: C.Policy
  for n: Nat
  for f: Nat
  for m: Maybe<&2, C.Entry<V>>
  for +g: Nat
  for at: Nat
  for r: C.Found<V>
  for hf: MNat.le(f, g)
  for hn: MNat.lt(g, n)
  {C.Slot.complete(V, p, C.Slot{n, f, m}, g, at, r) == C.Slot{n, 1n+g, Some{C.Entry.of(V, r, p, at)}} : C.Slot<V>}

# A completion below the floor changes nothing.
law complete_stale:
  for -V: Data
  for p: C.Policy
  for +s: C.Slot<V>
  for +g: Nat
  for at: Nat
  for r: C.Found<V>
  for h: MNat.lt(g, floor(V, s))
  {C.Slot.complete(V, p, s, g, at, r) == s : C.Slot<V>}

# Once stale, a generation stays stale: after any operations, its completion changes nothing.
law stale_forever:
  for -V: Data
  for os: List<&2, Op<V>>
  for +p: C.Policy
  for +s: C.Slot<V>
  for h: valid(V, s)
  for +g: Nat
  for at: Nat
  for r: C.Found<V>
  for e: MNat.lt(g, floor(V, s))
  {C.Slot.complete(V, p, run(V, os, p, s), g, at, r) == run(V, os, p, s) : C.Slot<V>}

# Invalidation
# ------------

# An invalidated slot serves nothing.
law invalidate_clears:
  for -V: Data
  for s: C.Slot<V>
  for +now: Nat
  {C.Slot.read(V, C.Slot.invalidate(V, s), now) == None{} : Maybe<&2, C.Entry<V>>}

# A fetch issued before an invalidation never lands, whatever follows it.
law invalidate_forever:
  for -V: Data
  for os: List<&2, Op<V>>
  for +p: C.Policy
  for +s: C.Slot<V>
  for +g: Nat
  for at: Nat
  for r: C.Found<V>
  for e: MNat.lt(g, next(V, s))
  {C.Slot.complete(V, p, run(V, os, p, C.Slot.invalidate(V, s)), g, at, r) == run(V, os, p, C.Slot.invalidate(V, s)) : C.Slot<V>}

# Once fetch g lands, a fetch at or below g cannot overwrite it.
law older_loses:
  for -V: Data
  for p: C.Policy
  for n: Nat
  for f: Nat
  for m: Maybe<&2, C.Entry<V>>
  for +g: Nat
  for at: Nat
  for r: C.Found<V>
  for hf: MNat.le(f, g)
  for hn: MNat.lt(g, n)
  for +u: Nat
  for at2: Nat
  for r2: C.Found<V>
  for hu: MNat.le(u, g)
  {C.Slot.complete(V, p, C.Slot.complete(V, p, C.Slot{n, f, m}, g, at, r), u, at2, r2)
   == C.Slot{n, 1n+g, Some{C.Entry.of(V, r, p, at)}} : C.Slot<V>}

# Negative results
# ----------------

# A Missing result is served as a Miss until at + negative_ttl.
law negative_served:
  for -V: Data
  for ttl: Nat
  for +neg: Nat
  for n: Nat
  for f: Nat
  for m: Maybe<&2, C.Entry<V>>
  for +g: Nat
  for +at: Nat
  for hf: MNat.le(f, g)
  for hn: MNat.lt(g, n)
  for +now: Nat
  for h: MNat.lt(now, Nat.add(at, neg))
  {C.Slot.read(V, C.Slot.complete(V, C.Policy{ttl, neg}, C.Slot{n, f, m}, g, at, C.Missing{}), now)
   == Some{C.Miss{Nat.add(at, neg)}} : Maybe<&2, C.Entry<V>>}

# From at + negative_ttl on, a Missing result is not served.
law negative_expires:
  for -V: Data
  for ttl: Nat
  for +neg: Nat
  for n: Nat
  for f: Nat
  for m: Maybe<&2, C.Entry<V>>
  for +g: Nat
  for +at: Nat
  for hf: MNat.le(f, g)
  for hn: MNat.lt(g, n)
  for +now: Nat
  for h: MNat.le(Nat.add(at, neg), now)
  {C.Slot.read(V, C.Slot.complete(V, C.Policy{ttl, neg}, C.Slot{n, f, m}, g, at, C.Missing{}), now)
   == None{} : Maybe<&2, C.Entry<V>>}

# Eviction
# --------

# An evicted slot serves nothing.
law evict_clears:
  for -V: Data
  for s: C.Slot<V>
  for +now: Nat
  {C.Slot.read(V, C.Slot.evict(V, s), now) == None{} : Maybe<&2, C.Entry<V>>}

# Eviction changes only what is cached now. After any operations, the slot
# equals the one without the eviction, up to its entry.
law evict_only_availability:
  for -V: Data
  for os: List<&2, Op<V>>
  for +p: C.Policy
  for s: C.Slot<V>
  {C.Slot.evict(V, run(V, os, p, C.Slot.evict(V, s))) == C.Slot.evict(V, run(V, os, p, s)) : C.Slot<V>}
