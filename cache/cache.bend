# Cache validity: expiry, negative results, invalidation, and generation-safe fetch completion. Source: https://github.com/paymog/bend-kit/tree/main/cache
import Base
import bend-kit-collections@0.1.2.0/omap.bend as OMap

# How long a result stays fresh, in the units of the caller's clock.
type Policy is Data:
  Policy{ttl: Nat, negative_ttl: Nat}

# What one fetch found upstream: a value at an upstream version, or nothing.
type Found<-V: Data> is Data:
  Found{version: Nat, value: V}
  Missing{}

# A cached result. It serves a read at `now` only while now < expires.
type Entry<-V: Data> is Data:
  Hit{version: Nat, value: V, expires: Nat}
  Miss{expires: Nat}

# The state of one key. Fetches take the generations floor, floor+1, ..., next-1.
# A completion lands only when floor <= its generation < next. It then raises
# floor past its generation, so no older fetch can land after it.
type Slot<-V: Data> is Data:
  Slot{next: Nat, floor: Nat, entry: Maybe<&2, Entry<V>>}

# One fetch in flight: its key, its generation, and the clock when it started.
# It is affine, so it completes at most once.
type Ticket is Type:
  Ticket{key: String, gen: Nat, at: Nat}

type Cache<-V: Data> is Data:
  Cache{policy: Policy, slots: OMap.OMap<String, Slot<V>>}

# Slot
# ----

def Slot.new(-V: Data) -> Slot<V>:
  Slot{0n, 0n, None{}}

def Entry.expires(-V: Data, e: Entry<V>) -> Nat:
  match e:
    case Hit{v, x, t}:
      t
    case Miss{t}:
      t

# The entry for a result fetched at `at`. Its age counts from the fetch start.
def Entry.of(-V: Data, r: Found<V>, p: Policy, at: Nat) -> Entry<V>:
  match r:
    case Found{v, x}:
      Policy{ttl, neg} = p
      Hit{v, x, Nat.add(at, ttl)}
    case Missing{}:
      Policy{ttl, neg} = p
      Miss{Nat.add(at, neg)}

def Slot.serve(-V: Data, fresh: Bool, e: Entry<V>) -> Maybe<&2, Entry<V>>:
  match fresh:
    case True{}:
      Some{e}
    case False{}:
      None{}

def Slot.lookup(-V: Data, m: Maybe<&2, Entry<V>>, +now: Nat) -> Maybe<&2, Entry<V>>:
  match m:
    case None{}:
      None{}
    case Some{+e}:
      Slot.serve(V, Nat.is_lt(now, Entry.expires(V, e)), e)

# The fresh entry at `now`, or None when the caller must fetch.
def Slot.read(-V: Data, s: Slot<V>, +now: Nat) -> Maybe<&2, Entry<V>>:
  Slot{n, f, m} = s
  Slot.lookup(V, m, now)

# Takes the next generation for a new fetch.
def Slot.start(-V: Data, s: Slot<V>) -> Nat & Slot<V>:
  Slot{+n, f, m} = s
  (n, Slot{1n+n, f, m})

def Slot.complete.if(-V: Data, ok: Bool, n: Nat, f: Nat, m: Maybe<&2, Entry<V>>, g: Nat, e: Entry<V>) -> Slot<V>:
  match ok:
    case True{}:
      Slot{n, 1n+g, Some{e}}
    case False{}:
      Slot{n, f, m}

# Stores the result of fetch g, unless g is stale or was never issued.
def Slot.complete(-V: Data, p: Policy, s: Slot<V>, +g: Nat, at: Nat, r: Found<V>) -> Slot<V>:
  Slot{+n, +f, m} = s
  Slot.complete.if(V, Nat.is_le(f, g) && Nat.is_lt(g, n), n, f, m, g, Entry.of(V, r, p, at))

# Drops the entry and voids every fetch issued so far.
def Slot.invalidate(-V: Data, s: Slot<V>) -> Slot<V>:
  Slot{+n, f, m} = s
  Slot{n, n, None{}}

# Drops the entry. The generations stay, so no fetch that was stale before is accepted after.
def Slot.evict(-V: Data, s: Slot<V>) -> Slot<V>:
  Slot{n, f, m} = s
  Slot{n, f, None{}}

# Cache
# -----

def key.cmp.fin(c: Cmp, rest: Cmp) -> Cmp:
  match c:
    case LT{}:
      LT{}
    case EQ{}:
      rest
    case GT{}:
      GT{}

# Keys in code-point order. String.order rebuilds both strings on every call.
def key.cmp(a: String, b: String) -> Cmp:
  match a b:
    case SNil{} SNil{}:
      EQ{}
    case SNil{} SCon{h, t}:
      LT{}
    case SCon{h, t} SNil{}:
      GT{}
    case SCon{Chr{+x}, s} SCon{Chr{+y}, t}:
      key.cmp.fin(U32.cmp(x, y), key.cmp(s, t))

def Cache.new(-V: Data, p: Policy) -> Cache<V>:
  Cache{p, OMap.OMap.new(String, Slot<V>)}

def Cache.slot(~V: Data, slots: OMap.OMap<String, Slot<V>>, +key: String) -> Slot<V>:
  Maybe.default(&2, Slot<V>, OMap.OMap.get(~String, ~Slot<V>, ~key.cmp, slots, key), Slot.new(V))

def Cache.put(~V: Data, p: Policy, slots: OMap.OMap<String, Slot<V>>, +key: String, +s: Slot<V>) -> Cache<V>:
  Cache{p, OMap.OMap.put(~String, ~Slot<V>, ~key.cmp, slots, key, s)}

# The fresh entry for key at `now`, or None when the caller must fetch.
def Cache.read(~V: Data, c: Cache<V>, +key: String, +now: Nat) -> Maybe<&2, Entry<V>>:
  Cache{p, slots} = c
  Slot.read(V, Cache.slot(~V, slots, key), now)

def Cache.start.fin(~V: Data, p: Policy, slots: OMap.OMap<String, Slot<V>>, +key: String, at: Nat, r: Nat & Slot<V>) -> Ticket & Cache<V>:
  (g, s) = r
  (Ticket{key, g, at}, Cache.put(~V, p, slots, key, s))

# Starts a fetch of key at clock `at`. Fetch upstream, then pass the ticket to complete.
def Cache.start(~V: Data, c: Cache<V>, +key: String, at: Nat) -> Ticket & Cache<V>:
  Cache{p, +slots} = c
  Cache.start.fin(~V, p, slots, key, at, Slot.start(V, Cache.slot(~V, slots, key)))

# Stores what the ticket's fetch found. A stale ticket changes nothing.
def Cache.complete(~V: Data, c: Cache<V>, t: Ticket, r: Found<V>) -> Cache<V>:
  Cache{+p, +slots} = c
  Ticket{+key, g, at} = t
  Cache.put(~V, p, slots, key, Slot.complete(V, p, Cache.slot(~V, slots, key), g, at, r))

# Drops key's entry and voids its fetches in flight.
def Cache.invalidate(~V: Data, c: Cache<V>, +key: String) -> Cache<V>:
  Cache{p, +slots} = c
  Cache.put(~V, p, slots, key, Slot.invalidate(V, Cache.slot(~V, slots, key)))

# Drops key's entry. Its generations stay, so stale fetches stay stale.
def Cache.evict(~V: Data, c: Cache<V>, +key: String) -> Cache<V>:
  Cache{p, +slots} = c
  Cache.put(~V, p, slots, key, Slot.evict(V, Cache.slot(~V, slots, key)))
