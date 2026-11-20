import Base
import ./planner.bend as P
import bend-kit-collections@0.1.5.0/LAWS.bend as Col

# Every member of s has all its prerequisites in s.
def closed(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +g: List<&2, P.Node<K>>, +s: List<&2, K>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+y, t}:
      Bool.and(P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), s), closed(~K, ~eq, t, g, s))

# Every member of c requires a member of c: c is a cycle, or reaches one.
def cyclic(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +g: List<&2, P.Node<K>>, +c: List<&2, K>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+y, t}:
      Bool.and(P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), c), cyclic(~K, ~eq, t, g, c))

# Every node of p that changed or requires a member of s is in s.
def upward(~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +s: List<&2, K>) -> Bool:
  match p:
    case Nil{}:
      True{}
    case Con{+y, t}:
      Bool.and(
        Bool.or(Bool.not(Bool.or(P.member(~K, ~eq, changed, y), P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), s))), P.member(~K, ~eq, s, y)),
        upward(~K, ~eq, t, g, changed, s))

# The run of plan p: no command has run before, and rs holds each command's result.
def run(~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +rs: List<&2, Bool>) -> List<&2, P.Entry<K>>:
  P.exec(~K, ~eq, p, g, stale, Nil{}, rs)

# x is required by the node before it, or is a target when nothing comes before it.
def req(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, m: Maybe<&2, K>, +x: K) -> Bool:
  match m:
    case None{}:
      P.member(~K, ~eq, ts, x)
    case Some{y}:
      P.member(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), x)

# Each node of xs is required by the one before it; the first by m, or by the targets when m is None.
def linked(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +m: Maybe<&2, K>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+x, t}:
      Bool.and(req(~K, ~eq, g, ts, m, x), linked(~K, ~eq, t, g, ts, Some{x}))

# The last node of xs is x.
def ends(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +x: K) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{y, Nil{}}:
      eq(y, x)
    case Con{y, t}:
      ends(~K, ~eq, t, x)

# c is a cycle: each node requires the next, and the last is the first.
def cycle_ok(~K: Data, ~eq: K -> K -> Bool, c: List<&2, K>, +g: List<&2, P.Node<K>>) -> Bool:
  match c:
    case Nil{}:
      False{}
    case Con{+x, +t}:
      Bool.and(linked(~K, ~eq, t, g, Nil{}, Some{x}), ends(~K, ~eq, t, x))

# Plans
# -----
# Every law takes eq as sound: eq(x, y) gives x == y.

# Every node of a plan is defined.
law plan_defined:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for p: List<&2, K>
  for x: K
  for h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  for hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
  {Maybe.is_some(&2, List<&2, K>, P.deps(~K, ~eq, g, x)) == True{} : Bool}

# Each prerequisite of a node comes before it.
law plan_before:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for pre: List<&2, K>
  for x: K
  for post: List<&2, K>
  for ds: List<&2, K>
  for d: K
  for h: {P.plan(~K, ~eq, g, ts) == Done{P.cat(K, pre, x <> post)} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  for hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
  for hm: {P.member(~K, ~eq, ds, d) == True{} : Bool}
  {P.member(~K, ~eq, pre, d) == True{} : Bool}

# No node comes twice.
law plan_once:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for pre: List<&2, K>
  for x: K
  for post: List<&2, K>
  for h: {P.plan(~K, ~eq, g, ts) == Done{P.cat(K, pre, x <> post)} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  {P.member(~K, ~eq, pre, x) == False{} : Bool}

# The plan holds every target,
law plan_targets:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for p: List<&2, K>
  for t: K
  for h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  for ht: {P.member(~K, ~eq, ts, t) == True{} : Bool}
  {P.member(~K, ~eq, p, t) == True{} : Bool}

# and every prerequisite of a node it holds,
law plan_closed:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for p: List<&2, K>
  for x: K
  for ds: List<&2, K>
  for d: K
  for h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  for hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
  for hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
  for hm: {P.member(~K, ~eq, ds, d) == True{} : Bool}
  {P.member(~K, ~eq, p, d) == True{} : Bool}

# and nothing else: every set that holds the targets and the prerequisites of its
# members holds the plan. So the plan is exactly the dependency closure of ts.
law plan_least:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for s: List<&2, K>
  for hts: {P.all_in(~K, ~eq, ts, s) == True{} : Bool}
  for hcl: {closed(~K, ~eq, s, g, s) == True{} : Bool}
  for p: List<&2, K>
  for x: K
  for h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  for hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
  {P.member(~K, ~eq, s, x) == True{} : Bool}

# No plan holds a node of a cycle, or of any set whose every member requires a member.
law plan_cycle:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for c: List<&2, K>
  for hc: {cyclic(~K, ~eq, c, g, c) == True{} : Bool}
  for ts: List<&2, K>
  for p: List<&2, K>
  for x: K
  for h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  for hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
  {P.member(~K, ~eq, c, x) == False{} : Bool}

# So a target on a cycle has no plan.
law plan_cycle_target:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for c: List<&2, K>
  for hc: {cyclic(~K, ~eq, c, g, c) == True{} : Bool}
  for ts: List<&2, K>
  for t: K
  for ht: {P.member(~K, ~eq, ts, t) == True{} : Bool}
  for hct: {P.member(~K, ~eq, c, t) == True{} : Bool}
  for p: List<&2, K>
  for h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  Empty

# Errors and completeness
# -----------------------
# These laws also take eq as reflexive.

# A missing node is undefined,
law plan_missing:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for n: K
  for c: List<&2, K>
  for h: {P.plan(~K, ~eq, g, ts) == Fail{P.Missing{n, c}} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  {P.deps(~K, ~eq, g, n) == None{} : Maybe<&2, List<&2, K>>}

# and its chain runs from a target, through nodes that each require the next, to it.
law plan_missing_chain:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for n: K
  for c: List<&2, K>
  for h: {P.plan(~K, ~eq, g, ts) == Fail{P.Missing{n, c}} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  {linked(~K, ~eq, P.cat(K, c, [n]), g, ts, None{}) == True{} : Bool}

# A reported cycle is a cycle.
law plan_cycle_path:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for c: List<&2, K>
  for h: {P.plan(~K, ~eq, g, ts) == Fail{P.Cycle{c}} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  {cycle_ok(~K, ~eq, c, g) == True{} : Bool}

# plan never refuses. So it fails only on a true missing node or a true cycle, and plans every other graph.
law plan_complete:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for h: {P.plan(~K, ~eq, g, ts) == Fail{P.Refused{}} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  Empty

# Indexes
# -------
# plan.fast and invalidate.fast answer exactly as plan and invalidate when cmp is a
# total order whose EQ means equal keys, and eq agrees with it. So every law above
# holds for them too.

law plan_index:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~cmp: K -> K -> Cmp
  for ~crefl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~ceq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for ~cflip: @x: K -> @y: K -> {cmp(y, x) == Col.flip(cmp(x, y)) : Cmp}
  for ~ctrans: @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}
  for ~agree: @x: K -> @y: K -> {eq(x, y) == Cmp.is_eq(cmp(x, y)) : Bool}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  {P.plan.fast(~K, ~eq, ~cmp, g, ts) == P.plan(~K, ~eq, g, ts) : Result<&2, &2, P.Error<K>, List<&2, K>>}

law stale_index:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~cmp: K -> K -> Cmp
  for ~crefl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~ceq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for ~cflip: @x: K -> @y: K -> {cmp(y, x) == Col.flip(cmp(x, y)) : Cmp}
  for ~ctrans: @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}
  for ~agree: @x: K -> @y: K -> {eq(x, y) == Cmp.is_eq(cmp(x, y)) : Bool}
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for changed: List<&2, K>
  {P.invalidate.fast(~K, ~cmp, p, g, changed) == P.invalidate(~K, ~eq, p, g, changed) : List<&2, K>}

# Invalidation
# ------------

# A changed node of p is stale,
law stale_changed:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for changed: List<&2, K>
  for x: K
  for hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
  for hc: {P.member(~K, ~eq, changed, x) == True{} : Bool}
  {P.member(~K, ~eq, P.invalidate(~K, ~eq, p, g, changed), x) == True{} : Bool}

# and so is every node of a plan that requires a stale node,
law stale_dependents:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for g: List<&2, P.Node<K>>
  for ts: List<&2, K>
  for p: List<&2, K>
  for changed: List<&2, K>
  for x: K
  for ds: List<&2, K>
  for d: K
  for h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
  for hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
  for hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
  for hm: {P.member(~K, ~eq, ds, d) == True{} : Bool}
  for hs: {P.member(~K, ~eq, P.invalidate(~K, ~eq, p, g, changed), d) == True{} : Bool}
  {P.member(~K, ~eq, P.invalidate(~K, ~eq, p, g, changed), x) == True{} : Bool}

# and nothing else: every set that holds each node of p that changed or requires
# a member holds every stale node.
law stale_least:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for changed: List<&2, K>
  for s: List<&2, K>
  for hs: {upward(~K, ~eq, p, g, changed, s) == True{} : Bool}
  for x: K
  for hx: {P.member(~K, ~eq, P.invalidate(~K, ~eq, p, g, changed), x) == True{} : Bool}
  {P.member(~K, ~eq, s, x) == True{} : Bool}

# Execution
# ---------
# These hold for every node list p, stale set, and sequence of command results rs.

# A node that ran or was reused had every prerequisite Built or Fresh.
law exec_ready:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for rs: List<&2, Bool>
  for x: K
  for ds: List<&2, K>
  for hx: {P.selected.at(P.status(~K, ~eq, run(~K, ~eq, p, g, stale, rs), x)) == True{} : Bool}
  for hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
  {P.ready(~K, ~eq, ds, run(~K, ~eq, p, g, stale, rs)) == True{} : Bool}

# A prerequisite that did not succeed keeps its dependents from success.
law exec_blocked:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for rs: List<&2, Bool>
  for x: K
  for ds: List<&2, K>
  for d: K
  for hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
  for hm: {P.member(~K, ~eq, ds, d) == True{} : Bool}
  for hf: {P.ok.at(P.status(~K, ~eq, run(~K, ~eq, p, g, stale, rs), d)) == False{} : Bool}
  {P.ok.at(P.status(~K, ~eq, run(~K, ~eq, p, g, stale, rs), x)) == False{} : Bool}

# Each node gets at most one status, so its command runs at most once.
law exec_once:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for rs: List<&2, Bool>
  {P.distinct(~K, ~eq, P.keys(K, run(~K, ~eq, p, g, stale, rs))) == True{} : Bool}

# Each node of p gets a status.
law exec_total:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for rs: List<&2, Bool>
  for x: K
  for hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
  {Maybe.is_some(&2, P.Status, P.status(~K, ~eq, run(~K, ~eq, p, g, stale, rs), x)) == True{} : Bool}

# A stale node is never reused.
law exec_fresh:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for rs: List<&2, Bool>
  for x: K
  for hx: {P.status(~K, ~eq, run(~K, ~eq, p, g, stale, rs), x) == Some{P.Fresh{}} : Maybe<&2, P.Status>}
  {P.member(~K, ~eq, stale, x) == False{} : Bool}

# Parallel execution
# ------------------
# These hold for every node list p, stale set, limit, and order of finishes es.
# They take eq as sound and reflexive.

def prun(~K: Data, ~eq: K -> K -> Bool, es: List<&2, P.Fin<K>>, p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat) -> P.Pool<K>:
  P.par(~K, ~eq, es, p, g, stale, limit, P.Pool{Nil{}, Nil{}, Nil{}})

def statuses(-K: Data, pool: P.Pool<K>) -> List<&2, P.Entry<K>>:
  match pool:
    case P.Pool{st, r, l}:
      st

def running(-K: Data, pool: P.Pool<K>) -> List<&2, K>:
  match pool:
    case P.Pool{st, r, l}:
      r

def started(-K: Data, pool: P.Pool<K>) -> List<&2, K>:
  match pool:
    case P.Pool{st, r, l}:
      l

# A node that ran or was reused had every prerequisite Built or Fresh,
law par_ready:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  for x: K
  for ds: List<&2, K>
  for hx: {P.selected.at(P.status(~K, ~eq, statuses(K, prun(~K, ~eq, es, p, g, stale, limit)), x)) == True{} : Bool}
  for hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
  {P.ready(~K, ~eq, ds, statuses(K, prun(~K, ~eq, es, p, g, stale, limit))) == True{} : Bool}

# and so does a node whose command runs now.
law par_running:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  for x: K
  for ds: List<&2, K>
  for hx: {P.member(~K, ~eq, running(K, prun(~K, ~eq, es, p, g, stale, limit)), x) == True{} : Bool}
  for hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
  {P.ready(~K, ~eq, ds, statuses(K, prun(~K, ~eq, es, p, g, stale, limit))) == True{} : Bool}

# A prerequisite that did not succeed keeps its dependents from success.
law par_blocked:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  for x: K
  for ds: List<&2, K>
  for d: K
  for hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
  for hm: {P.member(~K, ~eq, ds, d) == True{} : Bool}
  for hf: {P.ok.at(P.status(~K, ~eq, statuses(K, prun(~K, ~eq, es, p, g, stale, limit)), d)) == False{} : Bool}
  {P.ok.at(P.status(~K, ~eq, statuses(K, prun(~K, ~eq, es, p, g, stale, limit)), x)) == False{} : Bool}

# Each command starts at most once,
law par_once:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  {P.distinct(~K, ~eq, started(K, prun(~K, ~eq, es, p, g, stale, limit))) == True{} : Bool}

# and each node gets at most one status.
law par_once_status:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  {P.distinct(~K, ~eq, P.keys(K, statuses(K, prun(~K, ~eq, es, p, g, stale, limit)))) == True{} : Bool}

# A stale node is never reused.
law par_fresh:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  for x: K
  for hx: {P.status(~K, ~eq, statuses(K, prun(~K, ~eq, es, p, g, stale, limit)), x) == Some{P.Fresh{}} : Maybe<&2, P.Status>}
  {P.member(~K, ~eq, stale, x) == False{} : Bool}

# No more than limit commands run at once.
law par_limit:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  {P.le(List.length(&2, K, running(K, prun(~K, ~eq, es, p, g, stale, limit))), limit) == True{} : Bool}

# With room for one command, a run that ends with nothing running gives every node of p a status.
law par_total:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}
  for ~refl: @x: K -> {eq(x, x) == True{} : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  for x: K
  for hl: {P.le(1n, limit) == True{} : Bool}
  for hr: {running(K, prun(~K, ~eq, es, p, g, stale, limit)) == Nil{} : List<&2, K>}
  for hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
  {Maybe.is_some(&2, P.Status, P.status(~K, ~eq, statuses(K, prun(~K, ~eq, es, p, g, stale, limit)), x)) == True{} : Bool}

# par.fast runs as par and keeps its status index exact, under the order facts of plan_index.
# So every parallel law holds for it too.
law par_index:
  for ~K: Data
  for ~eq: K -> K -> Bool
  for ~cmp: K -> K -> Cmp
  for ~crefl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~ceq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for ~cflip: @x: K -> @y: K -> {cmp(y, x) == Col.flip(cmp(x, y)) : Cmp}
  for ~ctrans: @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}
  for ~agree: @x: K -> @y: K -> {eq(x, y) == Cmp.is_eq(cmp(x, y)) : Bool}
  for es: List<&2, P.Fin<K>>
  for p: List<&2, K>
  for g: List<&2, P.Node<K>>
  for stale: List<&2, K>
  for limit: Nat
  for pool: P.Pool<K>
  {P.par.fast(~K, ~eq, ~cmp, es, p, P.gidx(~K, ~cmp, g), P.idx(~K, ~cmp, stale), limit, P.lift(~K, ~cmp, pool))
   == P.lift(~K, ~cmp, P.par(~K, ~eq, es, p, g, stale, limit, pool)) : P.FPool<K>}

# The diamond with room for two: base runs alone, lib and gen run together, then app.
law fixture_par:
  {prun(~String, ~String.eq, [P.Fin{"base", True{}}, P.Fin{"gen", True{}}, P.Fin{"lib", True{}}, P.Fin{"app", True{}}],
     ["base", "lib", "gen", "app"], [P.Node{"app", ["lib", "gen"]}, P.Node{"lib", ["base"]}, P.Node{"gen", ["base"]}, P.Node{"base", []}],
     ["base", "lib", "gen", "app"], 2n)
   == P.Pool{[P.Entry{"app", P.Built{}}, P.Entry{"lib", P.Built{}}, P.Entry{"gen", P.Built{}}, P.Entry{"base", P.Built{}}], Nil{}, ["app", "gen", "lib", "base"]}
   : P.Pool<String>}

# Fixtures
# --------
# A diamond: app requires lib and gen, and both require base.

def diamond() -> List<&2, P.Node<String>>:
  [P.Node{"app", ["lib", "gen"]}, P.Node{"lib", ["base"]}, P.Node{"gen", ["base"]}, P.Node{"base", []},
   P.Node{"a", ["b"]}, P.Node{"b", ["c"]}, P.Node{"c", ["a"]}, P.Node{"bad", ["nope"]}]

def order() -> List<&2, String>:
  ["base", "lib", "gen", "app"]

law fixture_plan:
  {P.plan(~String, ~String.eq, diamond(), ["app"]) == Done{order()} : Result<&2, &2, P.Error<String>, List<&2, String>>}

# A target that another target requires comes once.
law fixture_plan_shared:
  {P.plan(~String, ~String.eq, diamond(), ["lib", "app", "base"]) == Done{order()} : Result<&2, &2, P.Error<String>, List<&2, String>>}

law fixture_cycle:
  {P.plan(~String, ~String.eq, diamond(), ["app", "b"]) == Fail{P.Cycle{["b", "c", "a", "b"]}} : Result<&2, &2, P.Error<String>, List<&2, String>>}

law fixture_missing:
  {P.plan(~String, ~String.eq, diamond(), ["bad"]) == Fail{P.Missing{"nope", ["bad"]}} : Result<&2, &2, P.Error<String>, List<&2, String>>}

# A change to gen makes gen and app stale, not lib or base.
law fixture_stale:
  {P.invalidate(~String, ~String.eq, order(), diamond(), ["gen"]) == ["app", "gen"] : List<&2, String>}

law fixture_reuse:
  {run(~String, ~String.eq, order(), diamond(), ["app", "gen"], [True{}, True{}])
   == [P.Entry{"app", P.Built{}}, P.Entry{"gen", P.Built{}}, P.Entry{"lib", P.Fresh{}}, P.Entry{"base", P.Fresh{}}]
   : List<&2, P.Entry<String>>}

# gen fails, so app does not run.
law fixture_failure:
  {run(~String, ~String.eq, order(), diamond(), order(), [True{}, True{}, False{}, True{}])
   == [P.Entry{"app", P.Skipped{}}, P.Entry{"gen", P.Failed{}}, P.Entry{"lib", P.Built{}}, P.Entry{"base", P.Built{}}]
   : List<&2, P.Entry<String>>}
