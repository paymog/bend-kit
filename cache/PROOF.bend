import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool
import ./cache.bend as C
import bend-kit-collections@0.1.4.1/omap.bend as OMap
import bend-kit-collections@0.1.4.1/order.bend as Order
import bend-kit-collections@0.1.4.1/LAWS.bend as CL
import bend-kit-collections@0.1.4.1/PROOF.bend as CP
import ./LAWS.bend as Laws

# Bool and order lemmas
# ---------------------

def not_true(x: Bool, e: {Bool.not(x) == True{} : Bool}) -> {x == False{} : Bool}:
  match x:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, MBool.false_ne_true()(e))
    case False{}:
      {==}

def and_left(x: Bool, -y: Bool, e: {Bool.and(x, y) == True{} : Bool}) -> {x == True{} : Bool}:
  match x:
    case True{}:
      {==}
    case False{}:
      e

def and_right(x: Bool, -y: Bool, e: {Bool.and(x, y) == True{} : Bool}) -> {y == True{} : Bool}:
  match x:
    case True{}:
      e
    case False{}:
      Empty.absurd({y == True{} : Bool}, MBool.false_ne_true()(e))

# a < b gives a + 1 <= b.
def lt_succ(+a: Nat, +b: Nat, h: MNat.lt(a, b)) -> MNat.le(1n+a, b):
  %MNat.is_lt_eq_succ_le(a, b) : {_ == True{} : Bool}
  h

# a <= b gives a < b + 1.
def lt_of_le_succ(+a: Nat, +b: Nat, h: MNat.le(a, b)) -> MNat.lt(a, 1n+b):
  %Equal.sym(Bool, Nat.is_lt(a, 1n+b), Nat.is_le(1n+a, 1n+b), MNat.is_lt_eq_succ_le(a, 1n+b)) : {_ == True{} : Bool}
  h

def lt_le(+a: Nat, +b: Nat, +c: Nat, ab: MNat.lt(a, b), bc: MNat.le(b, c)) -> MNat.lt(a, c):
  %Equal.sym(Bool, Nat.is_lt(a, c), Nat.is_le(1n+a, c), MNat.is_lt_eq_succ_le(a, c)) : {_ == True{} : Bool}
  MNat.le_trans(1n+a, b, c, lt_succ(a, b, ab), bc)

# a < b gives not (b <= a).
def le_false(+a: Nat, +b: Nat, h: MNat.lt(a, b)) -> {Nat.is_le(b, a) == False{} : Bool}:
  not_true(Nat.is_le(b, a), Equal.trans(Bool, Bool.not(Nat.is_le(b, a)), Nat.is_lt(a, b), True{}, MNat.not_is_le(b, a), h))

# Expiry
# ------

def read_fresh.serve(-V: Data, b: Bool, +now: Nat, +e: C.Entry<V>, eb: {Nat.is_lt(now, C.Entry.expires(V, e)) == b : Bool}) -> {Laws.fresh(V, C.Slot.serve(V, b, e), now) == True{} : Bool}:
  match b:
    case True{}:
      eb
    case False{}:
      {==}

def read_fresh.go(-V: Data, m: Maybe<&2, C.Entry<V>>, +now: Nat) -> {Laws.fresh(V, C.Slot.lookup(V, m, now), now) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{+e}:
      read_fresh.serve(V, Nat.is_lt(now, C.Entry.expires(V, e)), now, e, {==})

def Laws.read_fresh(V, s, now):
  match s:
    case C.Slot{n, f, m}:
      read_fresh.go(V, m, now)

def Laws.read_serves(V, n, f, e, now, h):
  %Equal.sym(Bool, Nat.is_lt(now, C.Entry.expires(V, e)), True{}, h) : {C.Slot.serve(V, _, e) == Some{e} : Maybe<&2, C.Entry<V>>}
  {==}

def Laws.read_expired(V, n, f, e, now, h):
  +x = C.Entry.expires(V, e)
  %Equal.sym(Bool, Nat.is_lt(now, x), False{}, not_true(Nat.is_lt(now, x), Equal.trans(Bool, Bool.not(Nat.is_lt(now, x)), Nat.is_le(x, now), True{}, MNat.not_is_lt(now, x), h))) : {C.Slot.serve(V, _, e) == None{} : Maybe<&2, C.Entry<V>>}
  {==}

# Generations
# -----------

def Laws.new_valid(V):
  {==}

def step_valid.complete(-V: Data, b: Bool, +n: Nat, +f: Nat, -m: Maybe<&2, C.Entry<V>>, +g: Nat, -e: C.Entry<V>, eb: {Bool.and(Nat.is_le(f, g), Nat.is_lt(g, n)) == b : Bool}, h: MNat.le(f, n)) -> Laws.valid(V, C.Slot.complete.if(V, b, n, f, m, g, e)):
  match b:
    case True{}:
      lt_succ(g, n, and_right(Nat.is_le(f, g), Nat.is_lt(g, n), eb))
    case False{}:
      h

def step_valid(-V: Data, +p: C.Policy, o: Laws.Op<V>, s: C.Slot<V>, h: Laws.valid(V, s)) -> Laws.valid(V, Laws.step(V, p, o, s)):
  match o s:
    case Laws.Start{} C.Slot{+n, +f, m}:
      MNat.le_trans(f, n, 1n+n, h, MNat.le_succ(n))
    case Laws.Complete{+g, at, r} C.Slot{+n, +f, m}:
      step_valid.complete(V, Bool.and(Nat.is_le(f, g), Nat.is_lt(g, n)), n, f, m, g, C.Entry.of(V, r, p, at), {==}, h)
    case Laws.Invalidate{} C.Slot{+n, f, m}:
      MNat.le_refl(n)
    case Laws.Evict{} C.Slot{n, f, m}:
      h

def Laws.run_valid(V, os, p, s, h):
  match os:
    case Nil{}:
      h
    case Con{o, t}:
      +s = s
      +o = o
      Laws.run_valid(V, t, p, Laws.step(V, p, o, s), step_valid(V, p, o, s, h))

def step_floor.complete(-V: Data, b: Bool, +n: Nat, +f: Nat, -m: Maybe<&2, C.Entry<V>>, +g: Nat, -e: C.Entry<V>, eb: {Bool.and(Nat.is_le(f, g), Nat.is_lt(g, n)) == b : Bool}) -> MNat.le(f, Laws.floor(V, C.Slot.complete.if(V, b, n, f, m, g, e))):
  match b:
    case True{}:
      MNat.le_trans(f, g, 1n+g, and_left(Nat.is_le(f, g), Nat.is_lt(g, n), eb), MNat.le_succ(g))
    case False{}:
      MNat.le_refl(f)

def step_floor(-V: Data, +p: C.Policy, o: Laws.Op<V>, s: C.Slot<V>, h: Laws.valid(V, s)) -> MNat.le(Laws.floor(V, s), Laws.floor(V, Laws.step(V, p, o, s))):
  match o s:
    case Laws.Start{} C.Slot{n, +f, m}:
      MNat.le_refl(f)
    case Laws.Complete{+g, at, r} C.Slot{+n, +f, m}:
      step_floor.complete(V, Bool.and(Nat.is_le(f, g), Nat.is_lt(g, n)), n, f, m, g, C.Entry.of(V, r, p, at), {==})
    case Laws.Invalidate{} C.Slot{n, f, m}:
      h
    case Laws.Evict{} C.Slot{n, +f, m}:
      MNat.le_refl(f)

def Laws.run_floor(V, os, p, s, h):
  match os:
    case Nil{}:
      MNat.le_refl(Laws.floor(V, s))
    case Con{o, +t}:
      +s = s
      +o = o
      +h = h
      MNat.le_trans(Laws.floor(V, s), Laws.floor(V, Laws.step(V, p, o, s)), Laws.floor(V, Laws.run(V, t, p, Laws.step(V, p, o, s))),
        step_floor(V, p, o, s, h),
        Laws.run_floor(V, t, p, Laws.step(V, p, o, s), step_valid(V, p, o, s, h)))

def Laws.complete_lands(V, p, n, f, m, g, at, r, hf, hn):
  %Equal.sym(Bool, Nat.is_le(f, g), True{}, hf) : {C.Slot.complete.if(V, Bool.and(_, Nat.is_lt(g, n)), n, f, m, g, C.Entry.of(V, r, p, at)) == C.Slot{n, 1n+g, Some{C.Entry.of(V, r, p, at)}} : C.Slot<V>}
  %Equal.sym(Bool, Nat.is_lt(g, n), True{}, hn) : {C.Slot.complete.if(V, _, n, f, m, g, C.Entry.of(V, r, p, at)) == C.Slot{n, 1n+g, Some{C.Entry.of(V, r, p, at)}} : C.Slot<V>}
  {==}

def Laws.start_lands(V, p, n, f, m, h, at, r):
  Laws.complete_lands(V, p, 1n+n, f, m, n, at, r, h, MNat.lt_succ_self(n))

def Laws.complete_stale(V, p, s, g, at, r, h):
  match s:
    case C.Slot{+n, +f, m}:
      %Equal.sym(Bool, Nat.is_le(f, g), False{}, le_false(g, f, h)) : {C.Slot.complete.if(V, Bool.and(_, Nat.is_lt(g, n)), n, f, m, g, C.Entry.of(V, r, p, at)) == C.Slot{n, f, m} : C.Slot<V>}
      {==}

def Laws.stale_forever(V, os, p, s, h, g, at, r, e):
  +os = os
  Laws.complete_stale(V, p, Laws.run(V, os, p, s), g, at, r,
    lt_le(g, Laws.floor(V, s), Laws.floor(V, Laws.run(V, os, p, s)), e, Laws.run_floor(V, os, p, s, h)))

# Invalidation
# ------------

def Laws.invalidate_clears(V, s, now):
  match s:
    case C.Slot{n, f, m}:
      {==}

def Laws.invalidate_forever(V, os, p, s, g, at, r, e):
  match s:
    case C.Slot{+n, f, m}:
      Laws.stale_forever(V, os, p, C.Slot{n, n, None{}}, MNat.le_refl(n), g, at, r, e)

def Laws.older_loses(V, p, n, f, m, g, at, r, hf, hn, u, at2, r2, hu):
  +p = p
  +n = n
  +at = at
  +r = r
  %Equal.sym(C.Slot<V>, C.Slot.complete(V, p, C.Slot{n, f, m}, g, at, r), C.Slot{n, 1n+g, Some{C.Entry.of(V, r, p, at)}}, Laws.complete_lands(V, p, n, f, m, g, at, r, hf, hn)) : {C.Slot.complete(V, p, _, u, at2, r2) == C.Slot{n, 1n+g, Some{C.Entry.of(V, r, p, at)}} : C.Slot<V>}
  Laws.complete_stale(V, p, C.Slot{n, 1n+g, Some{C.Entry.of(V, r, p, at)}}, u, at2, r2, lt_of_le_succ(u, g, hu))

# Negative results
# ----------------

def Laws.negative_served(V, ttl, neg, n, f, m, g, at, hf, hn, now, h):
  +ttl = ttl
  +n = n
  %Equal.sym(C.Slot<V>, C.Slot.complete(V, C.Policy{ttl, neg}, C.Slot{n, f, m}, g, at, C.Missing{}), C.Slot{n, 1n+g, Some{C.Miss{Nat.add(at, neg)}}}, Laws.complete_lands(V, C.Policy{ttl, neg}, n, f, m, g, at, C.Missing{}, hf, hn)) : {C.Slot.read(V, _, now) == Some{C.Miss{Nat.add(at, neg)}} : Maybe<&2, C.Entry<V>>}
  Laws.read_serves(V, n, 1n+g, C.Miss{Nat.add(at, neg)}, now, h)

def Laws.negative_expires(V, ttl, neg, n, f, m, g, at, hf, hn, now, h):
  +ttl = ttl
  +n = n
  %Equal.sym(C.Slot<V>, C.Slot.complete(V, C.Policy{ttl, neg}, C.Slot{n, f, m}, g, at, C.Missing{}), C.Slot{n, 1n+g, Some{C.Miss{Nat.add(at, neg)}}}, Laws.complete_lands(V, C.Policy{ttl, neg}, n, f, m, g, at, C.Missing{}, hf, hn)) : {C.Slot.read(V, _, now) == None{} : Maybe<&2, C.Entry<V>>}
  Laws.read_expired(V, n, 1n+g, C.Miss{Nat.add(at, neg)}, now, h)

# Eviction
# --------

def Laws.evict_clears(V, s, now):
  match s:
    case C.Slot{n, f, m}:
      {==}

def evict_same.complete(-V: Data, b: Bool, -t: List<&2, Laws.Op<V>>, -p: C.Policy, -n: Nat, -f: Nat, -e1: Maybe<&2, C.Entry<V>>, -e2: Maybe<&2, C.Entry<V>>, -g: Nat, -e: C.Entry<V>,
  ih: {C.Slot.evict(V, Laws.run(V, t, p, C.Slot{n, f, e1})) == C.Slot.evict(V, Laws.run(V, t, p, C.Slot{n, f, e2})) : C.Slot<V>})
  -> {C.Slot.evict(V, Laws.run(V, t, p, C.Slot.complete.if(V, b, n, f, e1, g, e))) == C.Slot.evict(V, Laws.run(V, t, p, C.Slot.complete.if(V, b, n, f, e2, g, e))) : C.Slot<V>}:
  match b:
    case True{}:
      {==}
    case False{}:
      ih

# Two slots that differ only in their entry agree, up to the entry, after any operations.
def evict_same(-V: Data, os: List<&2, Laws.Op<V>>, +p: C.Policy, +n: Nat, +f: Nat, -e1: Maybe<&2, C.Entry<V>>, -e2: Maybe<&2, C.Entry<V>>)
  -> {C.Slot.evict(V, Laws.run(V, os, p, C.Slot{n, f, e1})) == C.Slot.evict(V, Laws.run(V, os, p, C.Slot{n, f, e2})) : C.Slot<V>}:
  match os:
    case Nil{}:
      {==}
    case Con{o, +t}:
      match o:
        case Laws.Start{}:
          evict_same(V, t, p, 1n+n, f, e1, e2)
        case Laws.Complete{+g, at, r}:
          evict_same.complete(V, Bool.and(Nat.is_le(f, g), Nat.is_lt(g, n)), t, p, n, f, e1, e2, g, C.Entry.of(V, r, p, at), evict_same(V, t, p, n, f, e1, e2))
        case Laws.Invalidate{}:
          {==}
        case Laws.Evict{}:
          {==}

def Laws.evict_only_availability(V, os, p, s):
  match s:
    case C.Slot{n, f, m}:
      evict_same(V, os, p, n, f, None{}, m)

# Keys
# ----

# The slot that one operation on key stores back.
def next(~V: Data, o: Laws.Op<V>, p: C.Policy, slots: OMap.OMap<String, C.Slot<V>>, +key: String) -> C.Slot<V>:
  match o:
    case Laws.Start{}:
      Pair.snd(Nat, C.Slot<V>, C.Slot.start(V, C.Cache.slot(~V, slots, key)))
    case Laws.Complete{g, at, r}:
      C.Slot.complete(V, p, C.Cache.slot(~V, slots, key), g, at, r)
    case Laws.Invalidate{}:
      C.Slot.invalidate(V, C.Cache.slot(~V, slots, key))
    case Laws.Evict{}:
      C.Slot.evict(V, C.Cache.slot(~V, slots, key))

def start_put(~V: Data, +p: C.Policy, +slots: OMap.OMap<String, C.Slot<V>>, +key: String, r: Nat & C.Slot<V>)
  -> {Pair.snd(C.Ticket, C.Cache<V>, C.Cache.start.fin(~V, p, slots, key, 0n, r)) == C.Cache.put(~V, p, slots, key, Pair.snd(Nat, C.Slot<V>, r)) : C.Cache<V>}:
  match r:
    case (g, s):
      {==}

# Every operation on key reads key's slot and stores one slot back at key.
def apply_put(~V: Data, o: Laws.Op<V>, +p: C.Policy, +slots: OMap.OMap<String, C.Slot<V>>, +key: String)
  -> {Laws.apply(~V, o, C.Cache{p, slots}, key) == C.Cache.put(~V, p, slots, key, next(~V, o, p, slots, key)) : C.Cache<V>}:
  match o:
    case Laws.Start{}:
      start_put(~V, p, slots, key, C.Slot.start(V, C.Cache.slot(~V, slots, key)))
    case Laws.Complete{g, at, r}:
      {==}
    case Laws.Invalidate{}:
      {==}
    case Laws.Evict{}:
      {==}

def ne_cmp(+key: String, +other: String, ne: {key != other : String}) -> {Order.string(key, other) != EQ{} : Cmp}:
  e => ne(CL.order_string_eq(key, other, e))

def put_other(
  ~V: Data, p: C.Policy, +slots: OMap.OMap<String, C.Slot<V>>,
  tree: {CL.searchtree(~String, ~C.Slot<V>, ~Order.string, slots) == True{} : Bool},
  +key: String, +other: String, ne: {key != other : String}, +s: C.Slot<V>
) -> {Laws.slot(~V, C.Cache.put(~V, p, slots, key, s), other) == C.Cache.slot(~V, slots, other) : C.Slot<V>}:
  Equal.cong(Maybe<&2, C.Slot<V>>, C.Slot<V>, mm => Maybe.default(&2, C.Slot<V>, mm, C.Slot.new(V)),
    OMap.OMap.get(~String, ~C.Slot<V>, ~Order.string, OMap.OMap.put(~String, ~C.Slot<V>, ~Order.string, slots, key, s), other),
    OMap.OMap.get(~String, ~C.Slot<V>, ~Order.string, slots, other),
    CL.omap_get_put_other_key(~String, ~C.Slot<V>, ~Order.string, ~CL.order_string_refl, ~CL.order_string_eq,
      ~CL.order_string_flip, ~CL.order_string_trans, slots, tree, key, other, ne_cmp(key, other, ne), s))

def Laws.new_keyed(V, p):
  {==}

def Laws.apply_keyed(V, o, c, h, key):
  match c:
    case C.Cache{+p, +slots}:
      %Equal.sym(C.Cache<V>, Laws.apply(~V, o, C.Cache{p, slots}, key), C.Cache.put(~V, p, slots, key, next(~V, o, p, slots, key)), apply_put(~V, o, p, slots, key)) :
        {Laws.keyed(~V, _) == True{} : Bool}
      CL.omap_put_searchtree(~String, ~C.Slot<V>, ~Order.string, ~CL.order_string_refl, ~CL.order_string_eq,
        ~CL.order_string_flip, ~CL.order_string_trans, slots, h, key, next(~V, o, p, slots, key))

def Laws.apply_other_key(V, o, c, h, key, other, ne):
  match c:
    case C.Cache{+p, +slots}:
      %Equal.sym(C.Cache<V>, Laws.apply(~V, o, C.Cache{p, slots}, key), C.Cache.put(~V, p, slots, key, next(~V, o, p, slots, key)), apply_put(~V, o, p, slots, key)) :
        {Laws.slot(~V, _, other) == Laws.slot(~V, C.Cache{p, slots}, other) : C.Slot<V>}
      put_other(~V, p, slots, h, key, other, ne, next(~V, o, p, slots, key))
