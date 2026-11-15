import Base
import bend-mathlib@0.7.4.0/nat.bend as MNat
import bend-kit-authz@0.1.0.0/authz.bend as Az
import bend-kit-collections@0.1.5.0/omap.bend as OMap
import bend-kit-collections@0.1.5.0/order.bend as Order
import bend-kit-collections@0.1.5.0/LAWS.bend as CL
import bend-kit-collections@0.1.5.0/PROOF.bend as CP
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-cache@0.3.1.0/cache.bend as C
import ./gateway.bend as G
import ./LAWS.bend as Laws

# Giving back one lent unit leaves the pool and the grant at h.
def give_one(+o: Nat, -c: Nat, +h: Nat, -cache: C.Cache<String>)
    -> {G.Settled{G.Gate{Res.Pool{o, c, h}, Res.Grant{o, h}, cache}}
        == G.give(Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, cache) : G.Finish}:
  %Equal.sym(Bool, Nat.is_le(1n, Nat.add(h, 1n)), True{}, MNat.le_add_left(1n, h)) : {G.Settled{G.Gate{Res.Pool{o, c, h}, Res.Grant{o, h}, cache}} == G.give.split(Res.split.go(_, o, Nat.add(h, 1n), 1n), Res.Pool{o, c, Nat.add(h, 1n)}, cache) : G.Finish}
  %Equal.sym(Bool, Nat.is_eq(o, o), True{}, MNat.is_eq_refl(o)) : {G.Settled{G.Gate{Res.Pool{o, c, h}, Res.Grant{o, h}, cache}} == G.give.released(Res.release.go(Bool.and(_, Nat.is_le(1n, Nat.add(h, 1n))), o, c, Nat.add(h, 1n), o, 1n), Res.Grant{o, Nat.sub(Nat.add(h, 1n), 1n)}, cache) : G.Finish}
  %Equal.sym(Bool, Nat.is_le(1n, Nat.add(h, 1n)), True{}, MNat.le_add_left(1n, h)) : {G.Settled{G.Gate{Res.Pool{o, c, h}, Res.Grant{o, h}, cache}} == G.give.released(Res.release.go(_, o, c, Nat.add(h, 1n), o, 1n), Res.Grant{o, Nat.sub(Nat.add(h, 1n), 1n)}, cache) : G.Finish}
  %Equal.sym(Nat, Nat.sub(Nat.add(h, 1n), 1n), h, MNat.add_sub_cancel(h, 1n)) : {G.Settled{G.Gate{Res.Pool{o, c, h}, Res.Grant{o, h}, cache}} == G.Settled{G.Gate{Res.Pool{o, c, _}, Res.Grant{o, _}, cache}} : G.Finish}
  {==}

# Taking one unit that fits joins it into the grant, then reads the cache.
def take_one(+o: Nat, +c: Nat, +h: Nat, fits: {Nat.is_le(Nat.add(h, 1n), c) == True{} : Bool}, +cache: C.Cache<String>, +k: String, +now: Nat)
    -> {G.begin.read(C.Cache.read(~String, cache, k, now), Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, cache, k, now)
        == G.begin.took(Res.reserve(Res.Pool{o, c, h}, 1n), Res.Grant{o, h}, cache, k, now) : G.Begin}:
  %Equal.sym(Bool, Nat.is_le(Nat.add(h, 1n), c), True{}, fits) : {G.begin.read(C.Cache.read(~String, cache, k, now), Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, cache, k, now) == G.begin.took(Res.reserve.go(_, o, c, h, 1n), Res.Grant{o, h}, cache, k, now) : G.Begin}
  %Equal.sym(Bool, Nat.is_eq(o, o), True{}, MNat.is_eq_refl(o)) : {G.begin.read(C.Cache.read(~String, cache, k, now), Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, cache, k, now) == G.begin.joined(Res.combine.go(_, o, h, o, 1n), Res.Pool{o, c, Nat.add(h, 1n)}, cache, k, now) : G.Begin}
  {==}

def fetch.seen(+o: Nat, +c: Nat, +h: Nat, r: G.Pending & C.Cache<String>)
    -> {Laws.seen(G.begin.fetch(Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, r)) == Laws.fetched(o, c, h, r) : Laws.Seen}:
  match r:
    case (p, cc):
      {==}

def fetch.round(+o: Nat, +c: Nat, +h: Nat, r: G.Pending & C.Cache<String>, u: G.Upstream)
    -> {Laws.round(G.begin.fetch(Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, r), u) == Laws.Count{Res.Pool{o, c, h}, o, h} : Laws.Count}:
  match r:
    case (p, cc):
      %give_one(o, c, h, G.settle(cc, p, u)) : {Laws.count.finish(_) == Laws.Count{Res.Pool{o, c, h}, o, h} : Laws.Count}
      {==}

def read.round(m: Maybe<&2, C.Entry<String>>, +o: Nat, +c: Nat, +h: Nat, +cache: C.Cache<String>, +k: String, +now: Nat, u: G.Upstream)
    -> {Laws.round(G.begin.read(m, Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, cache, k, now), u) == Laws.Count{Res.Pool{o, c, h}, o, h} : Laws.Count}:
  match m:
    case Some{e}:
      %give_one(o, c, h, cache) : {Laws.round(G.begin.fresh(_, e), u) == Laws.Count{Res.Pool{o, c, h}, o, h} : Laws.Count}
      {==}
    case None{}:
      fetch.round(o, c, h, G.start(cache, k, now), u)

def fits.round(b: Bool, +o: Nat, +c: Nat, +h: Nat, eb: {Nat.is_le(Nat.add(h, 1n), c) == b : Bool}, +cache: C.Cache<String>, +k: String, +now: Nat, u: G.Upstream)
    -> {Laws.round(G.begin.took(Res.reserve.go(b, o, c, h, 1n), Res.Grant{o, h}, cache, k, now), u) == Laws.Count{Res.Pool{o, c, h}, o, h} : Laws.Count}:
  match b:
    case True{}:
      %Equal.sym(Bool, Nat.is_eq(o, o), True{}, MNat.is_eq_refl(o)) : {Laws.round(G.begin.joined(Res.combine.go(_, o, h, o, 1n), Res.Pool{o, c, Nat.add(h, 1n)}, cache, k, now), u) == Laws.Count{Res.Pool{o, c, h}, o, h} : Laws.Count}
      read.round(C.Cache.read(~String, cache, k, now), o, c, h, cache, k, now, u)
    case False{}:
      {==}

def granted.round(b: Bool, +o: Nat, +c: Nat, +h: Nat, +cache: C.Cache<String>, +k: String, +now: Nat, u: G.Upstream)
    -> {Laws.round(G.begin.granted(b, Laws.gate(o, c, h, cache), k, now), u) == Laws.Count{Res.Pool{o, c, h}, o, h} : Laws.Count}:
  match b:
    case True{}:
      fits.round(Nat.is_le(Nat.add(h, 1n), c), o, c, h, {==}, cache, k, now, u)
    case False{}:
      {==}

def Laws.denied_untouched(pol, req, e, o, c, h, q, n, cache, k, now):
  %Equal.sym(Bool, Az.granted(pol, req), False{}, e) : {Laws.seen(G.begin.granted(_, G.Gate{Res.Pool{o, c, h}, Res.Grant{q, n}, cache}, k, now)) == Laws.SDenied{Laws.View{Res.Pool{o, c, h}, q, n, cache}} : Laws.Seen}
  {==}

def Laws.busy_untouched(pol, req, e, o, c, h, q, n, full, cache, k, now):
  %Equal.sym(Bool, Az.granted(pol, req), True{}, e) : {Laws.seen(G.begin.granted(_, G.Gate{Res.Pool{o, c, h}, Res.Grant{q, n}, cache}, k, now)) == Laws.SBusy{Laws.View{Res.Pool{o, c, h}, q, n, cache}} : Laws.Seen}
  %Equal.sym(Bool, Nat.is_le(Nat.add(h, 1n), c), False{}, full) : {Laws.seen(G.begin.took(Res.reserve.go(_, o, c, h, 1n), Res.Grant{q, n}, cache, k, now)) == Laws.SBusy{Laws.View{Res.Pool{o, c, h}, q, n, cache}} : Laws.Seen}
  {==}

def Laws.hit_releases(pol, req, e, o, c, h, fits, cache, k, now, entry, hit):
  +o = o
  +c = c
  +h = h
  +cache = cache
  +k = k
  +now = now
  %Equal.sym(Bool, Az.granted(pol, req), True{}, e) : {Laws.seen(G.begin.granted(_, Laws.gate(o, c, h, cache), k, now)) == Laws.SFresh{Laws.View{Res.Pool{o, c, h}, o, h, cache}, entry} : Laws.Seen}
  %take_one(o, c, h, fits, cache, k, now) : {Laws.seen(_) == Laws.SFresh{Laws.View{Res.Pool{o, c, h}, o, h, cache}, entry} : Laws.Seen}
  %Equal.sym(Maybe<&2, C.Entry<String>>, C.Cache.read(~String, cache, k, now), Some{entry}, hit) : {Laws.seen(G.begin.read(_, Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, cache, k, now)) == Laws.SFresh{Laws.View{Res.Pool{o, c, h}, o, h, cache}, entry} : Laws.Seen}
  %give_one(o, c, h, cache) : {Laws.seen(G.begin.fresh(_, entry)) == Laws.SFresh{Laws.View{Res.Pool{o, c, h}, o, h, cache}, entry} : Laws.Seen}
  {==}

def Laws.miss_holds(pol, req, e, o, c, h, fits, cache, k, now, miss):
  +o = o
  +c = c
  +h = h
  +cache = cache
  +k = k
  +now = now
  %Equal.sym(Bool, Az.granted(pol, req), True{}, e) : {Laws.seen(G.begin.granted(_, Laws.gate(o, c, h, cache), k, now)) == Laws.fetched(o, c, h, G.start(cache, k, now)) : Laws.Seen}
  %take_one(o, c, h, fits, cache, k, now) : {Laws.seen(_) == Laws.fetched(o, c, h, G.start(cache, k, now)) : Laws.Seen}
  %Equal.sym(Maybe<&2, C.Entry<String>>, C.Cache.read(~String, cache, k, now), None{}, miss) : {Laws.seen(G.begin.read(_, Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, Nat.add(h, 1n)}, cache, k, now)) == Laws.fetched(o, c, h, G.start(cache, k, now)) : Laws.Seen}
  fetch.seen(o, c, h, G.start(cache, k, now))

def Laws.finish_releases(o, c, h, cache, p, u):
  +o = o
  +c = c
  +h = h
  +cache = cache
  +p = p
  +u = u
  %give_one(o, c, h, G.settle(cache, p, u)) : {Laws.ended(_) == Laws.ESettled{Laws.View{Res.Pool{o, c, h}, o, h, G.settle(cache, p, u)}} : Laws.Ended}
  {==}

def Laws.finish_unheld(o, c, cache, p, u):
  {==}

def Laws.every_path_releases(pol, req, o, c, h, cache, k, now, u):
  granted.round(Az.granted(pol, req), o, c, h, cache, k, now, u)

def key_refl(+k: String) -> {EQ{} == Order.string(k, k) : Cmp}:
  Equal.sym(Cmp, Order.string(k, k), EQ{}, CL.order_string_refl(k))

def get1(+k: String, +s: C.Slot<String>)
    -> {Some{s} == OMap.OMap.get(~String, ~C.Slot<String>, ~Order.string, OMap.OBin{1, k, s, OMap.OTip{}, OMap.OTip{}}, k) : Maybe<&2, C.Slot<String>>}:
  %key_refl(k) : {Some{s} == OMap.Cmp.case(Maybe<&2, C.Slot<String>>, _, u => None{}, u => Some{s}, u => None{}) : Maybe<&2, C.Slot<String>>}
  {==}

def put1(+k: String, +s: C.Slot<String>, +v: C.Slot<String>)
    -> {OMap.OBin{1, k, v, OMap.OTip{}, OMap.OTip{}} == OMap.OMap.put(~String, ~C.Slot<String>, ~Order.string, OMap.OBin{1, k, s, OMap.OTip{}, OMap.OTip{}}, k, v) : OMap.OMap<String, C.Slot<String>>}:
  %key_refl(k) : {OMap.OBin{1, k, v, OMap.OTip{}, OMap.OTip{}} == OMap.Cmp.case(OMap.OMap<String, C.Slot<String>>, _,
    u => OMap.OMap.balance(String, C.Slot<String>, k, s, OMap.OMap.put(~String, ~C.Slot<String>, ~Order.string, OMap.OTip{}, k, v), OMap.OTip{}),
    u => OMap.OBin{1, k, v, OMap.OTip{}, OMap.OTip{}},
    u => OMap.OMap.balance(String, C.Slot<String>, k, s, OMap.OTip{}, OMap.OMap.put(~String, ~C.Slot<String>, ~Order.string, OMap.OTip{}, k, v))) : OMap.OMap<String, C.Slot<String>>}
  {==}

# A fetch on a one-key cache takes the slot's next generation.
def start1(+pol: C.Policy, +k: String, +n: Nat, +f: Nat, +m: Maybe<&2, C.Entry<String>>, +at: Nat)
    -> {(G.Pending{k, n, at}, Laws.one(pol, k, C.Slot{1n+n, f, m})) == G.start(Laws.one(pol, k, C.Slot{n, f, m}), k, at) : G.Pending & C.Cache<String>}:
  %get1(k, C.Slot{n, f, m}) : {(G.Pending{k, n, at}, Laws.one(pol, k, C.Slot{1n+n, f, m})) == G.start.ticket(C.Cache.start.fin(~String, pol, OMap.OBin{1, k, C.Slot{n, f, m}, OMap.OTip{}, OMap.OTip{}}, k, at, C.Slot.start(String, Maybe.default(&2, C.Slot<String>, _, C.Slot.new(String))))) : G.Pending & C.Cache<String>}
  %put1(k, C.Slot{n, f, m}, C.Slot{1n+n, f, m}) : {(G.Pending{k, n, at}, Laws.one(pol, k, C.Slot{1n+n, f, m})) == G.start.ticket((C.Ticket{k, n, at}, C.Cache{pol, _})) : G.Pending & C.Cache<String>}
  {==}

# A found result on a one-key cache completes the slot.
def settle1(+pol: C.Policy, +k: String, +s: C.Slot<String>, +g: Nat, +at: Nat, +r: C.Found<String>)
    -> {Laws.one(pol, k, C.Slot.complete(String, pol, s, g, at, r)) == G.settle(Laws.one(pol, k, s), G.Pending{k, g, at}, G.Fetched{r}) : C.Cache<String>}:
  %get1(k, s) : {Laws.one(pol, k, C.Slot.complete(String, pol, s, g, at, r)) == C.Cache.put(~String, pol, OMap.OBin{1, k, s, OMap.OTip{}, OMap.OTip{}}, k, C.Slot.complete(String, pol, Maybe.default(&2, C.Slot<String>, _, C.Slot.new(String)), g, at, r)) : C.Cache<String>}
  %put1(k, s, C.Slot.complete(String, pol, s, g, at, r)) : {Laws.one(pol, k, C.Slot.complete(String, pol, s, g, at, r)) == C.Cache{pol, _} : C.Cache<String>}
  {==}

def le_ss_false(n: Nat) -> {False{} == Nat.is_le(1n+1n+n, n) : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      le_ss_false(p)

# Fetch B, issued after A at generation 1+n, lands on a valid slot.
def landed(+pol: C.Policy, +n: Nat, +f: Nat, +m: Maybe<&2, C.Entry<String>>, valid: {Nat.is_le(f, n) == True{} : Bool}, +now: Nat, +rb: C.Found<String>)
    -> {C.Slot{1n+1n+n, 1n+1n+n, Some{C.Entry.of(String, rb, pol, now)}} == C.Slot.complete(String, pol, C.Slot{1n+1n+n, f, m}, 1n+n, now, rb) : C.Slot<String>}:
  %Equal.sym(Bool, Nat.is_le(f, 1n+n), True{}, MNat.le_trans(f, n, 1n+n, valid, MNat.le_succ(n))) : {C.Slot{1n+1n+n, 1n+1n+n, Some{C.Entry.of(String, rb, pol, now)}} == C.Slot.complete.if(String, Bool.and(_, Nat.is_lt(1n+n, 1n+1n+n)), 1n+1n+n, f, m, 1n+n, C.Entry.of(String, rb, pol, now)) : C.Slot<String>}
  %Equal.sym(Bool, Nat.is_lt(n, 1n+n), True{}, MNat.lt_succ_self(n)) : {C.Slot{1n+1n+n, 1n+1n+n, Some{C.Entry.of(String, rb, pol, now)}} == C.Slot.complete.if(String, Bool.and(True{}, _), 1n+1n+n, f, m, 1n+n, C.Entry.of(String, rb, pol, now)) : C.Slot<String>}
  {==}

def late(+pol: C.Policy, +k: String, +n: Nat, +e: C.Entry<String>, +at: Nat, u: G.Upstream)
    -> {G.settle(Laws.one(pol, k, C.Slot{1n+1n+n, 1n+1n+n, Some{e}}), G.Pending{k, n, at}, u) == Laws.one(pol, k, C.Slot{1n+1n+n, 1n+1n+n, Some{e}}) : C.Cache<String>}:
  match u:
    case G.Fetched{ra}:
      %settle1(pol, k, C.Slot{1n+1n+n, 1n+1n+n, Some{e}}, n, at, ra) : {_ == Laws.one(pol, k, C.Slot{1n+1n+n, 1n+1n+n, Some{e}}) : C.Cache<String>}
      %le_ss_false(n) : {Laws.one(pol, k, C.Slot.complete.if(String, Bool.and(_, Nat.is_lt(n, 1n+1n+n)), 1n+1n+n, 1n+1n+n, Some{e}, n, C.Entry.of(String, ra, pol, at))) == Laws.one(pol, k, C.Slot{1n+1n+n, 1n+1n+n, Some{e}}) : C.Cache<String>}
      {==}
    case G.Failed{}:
      {==}

def Laws.older_fetch_loses(pol, k, n, f, m, valid, at, now, rb, u):
  +pol = pol
  +k = k
  +n = n
  +f = f
  +m = m
  +at = at
  +now = now
  +rb = rb
  %start1(pol, k, n, f, m, at) : {Laws.older(_, k, now, rb, u) == Laws.newer(_, k, now, rb) : C.Cache<String>}
  %start1(pol, k, 1n+n, f, m, now) : {Laws.older.second(G.Pending{k, n, at}, _, rb, u) == Laws.newer.second(_, rb) : C.Cache<String>}
  %settle1(pol, k, C.Slot{1n+1n+n, f, m}, 1n+n, now, rb) : {G.settle(_, G.Pending{k, n, at}, u) == _ : C.Cache<String>}
  %landed(pol, n, f, m, valid, now, rb) : {G.settle(Laws.one(pol, k, _), G.Pending{k, n, at}, u) == Laws.one(pol, k, _) : C.Cache<String>}
  late(pol, k, n, C.Entry.of(String, rb, pol, now), at, u)
