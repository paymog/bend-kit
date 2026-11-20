import Base
import bend-kit-authz@0.1.0.0/authz.bend as Az
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-cache@0.3.1.0/cache.bend as C
import bend-kit-collections@0.1.5.0/omap.bend as OMap
import ./gateway.bend as G

# A gate as copyable data: the pool, the owner and units of the joined grant, and the cache.
type View is Data:
  View{pool: Res.Pool, owner: Nat, held: Nat, cache: C.Cache<String>}

type Seen is Data:
  SDenied{gate: View}
  SBusy{gate: View}
  SFresh{gate: View, entry: C.Entry<String>}
  SFetch{gate: View, pending: G.Pending}

type Ended is Data:
  ESettled{gate: View}
  EUnheld{gate: View}

# The pool and the joined grant, without the cache.
type Count is Data:
  Count{pool: Res.Pool, owner: Nat, held: Nat}

def view(g: G.Gate) -> View:
  G.Gate{pool, Res.Grant{o, n}, cache} = g
  View{pool, o, n, cache}

def seen(b: G.Begin) -> Seen:
  match b:
    case G.Denied{g}:
      SDenied{view(g)}
    case G.Busy{g}:
      SBusy{view(g)}
    case G.Fresh{g, e}:
      SFresh{view(g), e}
    case G.Fetch{g, p}:
      SFetch{view(g), p}

def ended(f: G.Finish) -> Ended:
  match f:
    case G.Settled{g}:
      ESettled{view(g)}
    case G.Unheld{g}:
      EUnheld{view(g)}

def count(g: G.Gate) -> Count:
  G.Gate{pool, Res.Grant{o, n}, cache} = g
  Count{pool, o, n}

def count.finish(f: G.Finish) -> Count:
  match f:
    case G.Settled{g}:
      count(g)
    case G.Unheld{g}:
      count(g)

# Runs one request to its end: a fetch finishes with upstream result u.
def round(b: G.Begin, u: G.Upstream) -> Count:
  match b:
    case G.Denied{g}:
      count(g)
    case G.Busy{g}:
      count(g)
    case G.Fresh{g, e}:
      count(g)
    case G.Fetch{g, p}:
      count.finish(G.finish(g, p, u))

# A gate whose joined grant holds every unit the pool lent.
def gate(+o: Nat, c: Nat, +h: Nat, cache: C.Cache<String>) -> G.Gate:
  G.Gate{Res.Pool{o, c, h}, Res.Grant{o, h}, cache}

def fetched(+o: Nat, c: Nat, +h: Nat, r: G.Pending & C.Cache<String>) -> Seen:
  (p, cache) = r
  SFetch{View{Res.Pool{o, c, Nat.add(h, 1n)}, o, Nat.add(h, 1n), cache}, p}

# A cache that holds one key.
def one(pol: C.Policy, k: String, s: C.Slot<String>) -> C.Cache<String>:
  C.Cache{pol, OMap.OBin{1, k, s, OMap.OTip{}, OMap.OTip{}}}

# Fetch A started first. Fetch B starts after it and lands. Then A answers with u.
def older.second(pa: G.Pending, b: G.Pending & C.Cache<String>, rb: C.Found<String>, u: G.Upstream) -> C.Cache<String>:
  (pb, c) = b
  G.settle(G.settle(c, pb, G.Fetched{rb}), pa, u)

def older(a: G.Pending & C.Cache<String>, +k: String, +now: Nat, rb: C.Found<String>, u: G.Upstream) -> C.Cache<String>:
  (pa, c) = a
  older.second(pa, G.start(c, k, now), rb, u)

# The same, but A never answers.
def newer.second(b: G.Pending & C.Cache<String>, rb: C.Found<String>) -> C.Cache<String>:
  (pb, c) = b
  G.settle(c, pb, G.Fetched{rb})

def newer(a: G.Pending & C.Cache<String>, +k: String, +now: Nat, rb: C.Found<String>) -> C.Cache<String>:
  (pa, c) = a
  newer.second(G.start(c, k, now), rb)

# A denied request reserves nothing and starts no fetch: the gate comes back unchanged.
law denied_untouched:
  for pol: Az.Policy
  for req: Az.Request
  for e: {Az.granted(pol, req) == False{} : Bool}
  for o: Nat
  for c: Nat
  for h: Nat
  for q: Nat
  for n: Nat
  for cache: C.Cache<String>
  for k: String
  for now: Nat
  {seen(G.begin(pol, req, G.Gate{Res.Pool{o, c, h}, Res.Grant{q, n}, cache}, k, now))
   == SDenied{View{Res.Pool{o, c, h}, q, n, cache}} : Seen}

# A granted request that does not fit answers Busy and changes nothing.
law busy_untouched:
  for pol: Az.Policy
  for req: Az.Request
  for e: {Az.granted(pol, req) == True{} : Bool}
  for o: Nat
  for c: Nat
  for h: Nat
  for q: Nat
  for n: Nat
  for full: {Nat.is_le(Nat.add(h, 1n), c) == False{} : Bool}
  for cache: C.Cache<String>
  for k: String
  for now: Nat
  {seen(G.begin(pol, req, G.Gate{Res.Pool{o, c, h}, Res.Grant{q, n}, cache}, k, now))
   == SBusy{View{Res.Pool{o, c, h}, q, n, cache}} : Seen}

# A fresh hit takes one unit and gives it back: the gate comes back unchanged.
law hit_releases:
  for pol: Az.Policy
  for req: Az.Request
  for e: {Az.granted(pol, req) == True{} : Bool}
  for o: Nat
  for c: Nat
  for h: Nat
  for fits: {Nat.is_le(Nat.add(h, 1n), c) == True{} : Bool}
  for cache: C.Cache<String>
  for k: String
  for now: Nat
  for entry: C.Entry<String>
  for hit: {C.Cache.read(~String, cache, k, now) == Some{entry} : Maybe<&2, C.Entry<String>>}
  {seen(G.begin(pol, req, gate(o, c, h, cache), k, now))
   == SFresh{View{Res.Pool{o, c, h}, o, h, cache}, entry} : Seen}

# A miss keeps one unit in the joined grant and starts one fetch at `now`.
law miss_holds:
  for pol: Az.Policy
  for req: Az.Request
  for e: {Az.granted(pol, req) == True{} : Bool}
  for o: Nat
  for c: Nat
  for h: Nat
  for fits: {Nat.is_le(Nat.add(h, 1n), c) == True{} : Bool}
  for cache: C.Cache<String>
  for k: String
  for now: Nat
  for miss: {C.Cache.read(~String, cache, k, now) == None{} : Maybe<&2, C.Entry<String>>}
  {seen(G.begin(pol, req, gate(o, c, h, cache), k, now)) == fetched(o, c, h, G.start(cache, k, now)) : Seen}

# A finish gives back exactly the one unit its begin took, whatever upstream did.
law finish_releases:
  for o: Nat
  for c: Nat
  for h: Nat
  for cache: C.Cache<String>
  for p: G.Pending
  for u: G.Upstream
  {ended(G.finish(gate(o, c, Nat.add(h, 1n), cache), p, u))
   == ESettled{View{Res.Pool{o, c, h}, o, h, G.settle(cache, p, u)}} : Ended}

# A finish with no unit lent frees nothing.
law finish_unheld:
  for o: Nat
  for c: Nat
  for cache: C.Cache<String>
  for p: G.Pending
  for u: G.Upstream
  {ended(G.finish(gate(o, c, 0n, cache), p, u))
   == EUnheld{View{Res.Pool{o, c, 0n}, o, 0n, G.settle(cache, p, u)}} : Ended}

# Every path gives back what it took: deny, busy, hit, and a miss that finishes
# with any upstream result (found, missing, failure, open breaker).
law every_path_releases:
  for pol: Az.Policy
  for req: Az.Request
  for o: Nat
  for c: Nat
  for h: Nat
  for cache: C.Cache<String>
  for k: String
  for now: Nat
  for u: G.Upstream
  {round(G.begin(pol, req, gate(o, c, h, cache), k, now), u) == Count{Res.Pool{o, c, h}, o, h} : Count}

# Two fetches of one key race. B starts after A and lands first. A's answer,
# whatever it is, does not change the cache.
law older_fetch_loses:
  for pol: C.Policy
  for k: String
  for n: Nat
  for f: Nat
  for m: Maybe<&2, C.Entry<String>>
  for valid: {Nat.is_le(f, n) == True{} : Bool}
  for at: Nat
  for now: Nat
  for rb: C.Found<String>
  for u: G.Upstream
  {older(G.start(one(pol, k, C.Slot{n, f, m}), k, at), k, now, rb, u)
   == newer(G.start(one(pol, k, C.Slot{n, f, m}), k, at), k, now, rb) : C.Cache<String>}
