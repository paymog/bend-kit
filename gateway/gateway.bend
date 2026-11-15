# A guarded read-through gateway: authorize, admit, serve from cache, and fetch on a miss. Source: https://github.com/paymog/bend-kit/tree/main/gateway
import Base
import bend-kit-authz@0.1.0.0/authz.bend as Az
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-cache@0.3.1.0/cache.bend as C

# The shared state of one gateway. `held` joins every unit that the pool lent
# and that no finish has given back yet.
type Gate is Type:
  Gate{pool: Res.Pool, held: Res.Grant, cache: C.Cache<String>}

# A fetch in flight, as copyable data, so it can cross to the request task and back.
type Pending is Data:
  Pending{key: String, gen: Nat, at: Nat}

# What the upstream fetch did. Failed covers an upstream error, a spent budget, and an open breaker.
type Upstream is Data:
  Fetched{found: C.Found<String>}
  Failed{}

type Begin is Type:
  Denied{gate: Gate}
  Busy{gate: Gate}
  Fresh{gate: Gate, entry: C.Entry<String>}
  Fetch{gate: Gate, pending: Pending}

type Finish is Type:
  Settled{gate: Gate}
  Unheld{gate: Gate}

# An empty gateway: `capacity` requests at once, and an empty cache.
def new(+owner: Nat, capacity: Nat, policy: C.Policy) -> Gate:
  Gate{Res.new(owner, capacity), Res.Grant{owner, 0n}, C.Cache.new(String, policy)}

def give.released(r: Res.Release, rest: Res.Grant, cache: C.Cache<String>) -> Finish:
  match r:
    case Res.Released{pool}:
      Settled{Gate{pool, rest, cache}}
    case Res.Kept{pool, one}:
      Unheld{Gate{pool, rest, cache}}

def give.split(s: Res.Split, pool: Res.Pool, cache: C.Cache<String>) -> Finish:
  match s:
    case Res.Parts{one, rest}:
      give.released(Res.release(pool, one), rest, cache)
    case Res.Whole{held}:
      Unheld{Gate{pool, held, cache}}

# Gives one lent unit back to the pool. Unheld means that no unit was lent.
def give(pool: Res.Pool, held: Res.Grant, cache: C.Cache<String>) -> Finish:
  give.split(Res.split(held, 1n), pool, cache)

# Starts a fetch of key at clock `at`, as data.
def start.ticket(r: C.Ticket & C.Cache<String>) -> Pending & C.Cache<String>:
  (t, cache) = r
  C.Ticket{key, gen, at} = t
  (Pending{key, gen, at}, cache)

def start(cache: C.Cache<String>, +key: String, at: Nat) -> Pending & C.Cache<String>:
  start.ticket(C.Cache.start(~String, cache, key, at))

# Stores what a fetch found. A failed fetch stores nothing.
def settle(cache: C.Cache<String>, p: Pending, u: Upstream) -> C.Cache<String>:
  Pending{key, gen, at} = p
  match u:
    case Fetched{found}:
      C.Cache.complete(~String, cache, C.Ticket{key, gen, at}, found)
    case Failed{}:
      cache

def begin.fetch(pool: Res.Pool, held: Res.Grant, r: Pending & C.Cache<String>) -> Begin:
  (p, cache) = r
  Fetch{Gate{pool, held, cache}, p}

# The joined grant names another pool: give the new unit back and refuse.
def begin.refund(r: Res.Release, held: Res.Grant, cache: C.Cache<String>) -> Begin:
  match r:
    case Res.Released{pool}:
      Busy{Gate{pool, held, cache}}
    case Res.Kept{pool, one}:
      Busy{Gate{pool, held, cache}}

def begin.fresh(f: Finish, e: C.Entry<String>) -> Begin:
  match f:
    case Settled{gate}:
      Fresh{gate, e}
    case Unheld{gate}:
      Busy{gate}

def begin.read(m: Maybe<&2, C.Entry<String>>, pool: Res.Pool, held: Res.Grant, cache: C.Cache<String>, +key: String, +now: Nat) -> Begin:
  match m:
    case Some{e}:
      begin.fresh(give(pool, held, cache), e)
    case None{}:
      begin.fetch(pool, held, start(cache, key, now))

def begin.joined(j: Res.Combine, pool: Res.Pool, +cache: C.Cache<String>, +key: String, +now: Nat) -> Begin:
  match j:
    case Res.Joined{held}:
      begin.read(C.Cache.read(~String, cache, key, now), pool, held, cache, key, now)
    case Res.Apart{held, one}:
      begin.refund(Res.release(pool, one), held, cache)

def begin.took(r: Res.Reserve, held: Res.Grant, cache: C.Cache<String>, +key: String, +now: Nat) -> Begin:
  match r:
    case Res.Took{pool, one}:
      begin.joined(Res.combine(held, one), pool, cache, key, now)
    case Res.Refused{pool}:
      Busy{Gate{pool, held, cache}}

def begin.granted(ok: Bool, gate: Gate, +key: String, +now: Nat) -> Begin:
  match ok:
    case True{}:
      Gate{pool, held, cache} = gate
      begin.took(Res.reserve(pool, 1n), held, cache, key, now)
    case False{}:
      Denied{gate}

# Authorizes req, takes one unit, and reads key at `now`. Fresh has given its
# unit back; Fetch keeps it until finish.
def begin(policy: Az.Policy, req: Az.Request, gate: Gate, +key: String, +now: Nat) -> Begin:
  begin.granted(Az.granted(policy, req), gate, key, now)

# Stores what the fetch did and gives its unit back.
def finish(gate: Gate, p: Pending, u: Upstream) -> Finish:
  Gate{pool, held, cache} = gate
  give(pool, held, settle(cache, p, u))
