import Base
import ./planner.bend as P
import ./LAWS.bend as Laws
import bend-kit-collections@0.1.5.0/omap.bend as OMap
import bend-kit-collections@0.1.5.0/LAWS.bend as Col
import bend-kit-collections@0.1.5.0/PROOF.bend as ColProof

# Bool
# ----

def true_ne_false(e: {True{} == False{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Unit, Empty)
  Unit{}

def false_ne_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : Bool.pick(Type, _, Empty, Unit)
  Unit{}

def and_l(a: Bool, -b: Bool, h: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      Empty.absurd({False{} == True{} : Bool}, false_ne_true(h))

def and_r(a: Bool, -b: Bool, h: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      h
    case False{}:
      Empty.absurd({b == True{} : Bool}, false_ne_true(h))

def not_true(a: Bool, h: {Bool.not(a) == True{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, false_ne_true(h))
    case False{}:
      {==}

def or_false_r(a: Bool, -b: Bool, h: {Bool.or(a, b) == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({b == False{} : Bool}, true_ne_false(h))
    case False{}:
      h

def none_ne_some(-T: Data, -x: T, e: {None{} == Some{x} : Maybe<&2, T>}) -> Empty:
  %e : Bool.pick(Type, Maybe.is_some(&2, T, _), Empty, Unit)
  Unit{}

def some_inj(-T: Data, +a: T, -b: T, e: {Some{a} == Some{b} : Maybe<&2, T>}) -> {a == b : T}:
  Equal.cong(Maybe<&2, T>, T, m => Maybe.default(&2, T, m, a), Some{a}, Some{b}, e)

def fail_ne_done(-E: Data, -A: Data, -e: E, -x: A, h: {Fail{e} == Done{x} : Result<&2, &2, E, A>}) -> Empty:
  %h : Bool.pick(Type, Result.is_done(&2, &2, E, A, _), Empty, Unit)
  Unit{}

def done_inj(-E: Data, -A: Data, +a: A, -b: A, h: {Done{a} == Done{b} : Result<&2, &2, E, A>}) -> {a == b : A}:
  Equal.cong(Result<&2, &2, E, A>, A, r => Result.default(&2, &2, E, A, r, a), Done{a}, Done{b}, h)

# Membership
# ----------

def Sound(~K: Data, ~eq: K -> K -> Bool) -> Type:
  @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K}

def mem_hit(~K: Data, ~eq: K -> K -> Bool, +x: K, +t: List<&2, K>, +k: K, e: {eq(k, x) == True{} : Bool}) ->
  {P.member(~K, ~eq, x <> t, k) == True{} : Bool}:
  %Equal.sym(Bool, eq(k, x), True{}, e) : {P.when(Bool, u => P.member(~K, ~eq, t, k), _, True{}) == True{} : Bool}
  {==}

def mem_miss(~K: Data, ~eq: K -> K -> Bool, +x: K, +t: List<&2, K>, +k: K, e: {eq(k, x) == False{} : Bool}) ->
  {P.member(~K, ~eq, x <> t, k) == P.member(~K, ~eq, t, k) : Bool}:
  %Equal.sym(Bool, eq(k, x), False{}, e) : {P.when(Bool, u => P.member(~K, ~eq, t, k), _, True{}) == P.member(~K, ~eq, t, k) : Bool}
  {==}

def all_in_mem.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +x: K, +t: List<&2, K>, +ys: List<&2, K>, +d: K,
  hc: {eq(d, x) == c : Bool}, hx: {P.member(~K, ~eq, ys, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, d) == True{} : Bool} -> {P.member(~K, ~eq, ys, d) == True{} : Bool},
  hm: {P.member(~K, ~eq, x <> t, d) == True{} : Bool}
) -> {P.member(~K, ~eq, ys, d) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(K, d, x, sound(d, x, hc)) : {P.member(~K, ~eq, ys, _) == True{} : Bool}
      hx
    case False{}:
      ih(Equal.trans(Bool, P.member(~K, ~eq, t, d), P.member(~K, ~eq, x <> t, d), True{},
        Equal.sym(Bool, P.member(~K, ~eq, x <> t, d), P.member(~K, ~eq, t, d), mem_miss(~K, ~eq, x, t, d, hc)), hm))

# A member of xs is a member of ys when all_in(xs, ys).
def all_in_mem(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), xs: List<&2, K>, +ys: List<&2, K>, +d: K,
  ha: {P.all_in(~K, ~eq, xs, ys) == True{} : Bool}, hm: {P.member(~K, ~eq, xs, d) == True{} : Bool}
) -> {P.member(~K, ~eq, ys, d) == True{} : Bool}:
  match xs:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, ys, d) == True{} : Bool}, false_ne_true(hm))
    case Con{+x, +t}:
      +ha = ha
      all_in_mem.if(~K, ~eq, ~sound, eq(d, x), x, t, ys, d, {==},
        and_l(P.member(~K, ~eq, ys, x), P.all_in(~K, ~eq, t, ys), ha),
        h => all_in_mem(~K, ~eq, ~sound, t, ys, d, and_r(P.member(~K, ~eq, ys, x), P.all_in(~K, ~eq, t, ys), ha), h),
        hm)

# The plan check
# --------------

def plan_valid.ok(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +q: List<&2, K>, -p: List<&2, K>,
  hc: {P.valid(~K, ~eq, g, ts, q) == c : Bool},
  h: {P.plan.ok(K, c, q) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
) -> {P.valid(~K, ~eq, g, ts, p) == True{} : Bool}:
  match c:
    case True{}:
      %done_inj(P.Error<K>, List<&2, K>, q, p, h) : {P.valid(~K, ~eq, g, ts, _) == True{} : Bool}
      hc
    case False{}:
      Empty.absurd({P.valid(~K, ~eq, g, ts, p) == True{} : Bool}, fail_ne_done(P.Error<K>, List<&2, K>, P.Refused{}, p, h))

# A plan passed the check.
def plan_valid(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, r: Result<&2, &2, P.Error<K>, List<&2, K>>, -p: List<&2, K>,
  h: {P.plan.check(~K, ~eq, g, ts, r) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
) -> {P.valid(~K, ~eq, g, ts, p) == True{} : Bool}:
  match r:
    case Fail{e}:
      Empty.absurd({P.valid(~K, ~eq, g, ts, p) == True{} : Bool}, fail_ne_done(P.Error<K>, List<&2, K>, e, p, h))
    case Done{out}:
      +q = P.rev(K, out, Nil{})
      plan_valid.ok(~K, ~eq, P.valid(~K, ~eq, g, ts, q), g, ts, q, p, {==}, h)

def plan_ordered(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +p: List<&2, K>,
  h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
) -> {P.ordered(~K, ~eq, p, g, Nil{}) == True{} : Bool}:
  and_l(P.ordered(~K, ~eq, p, g, Nil{}), Bool.and(P.needed(~K, ~eq, P.rev(K, p, Nil{}), g, ts), P.all_in(~K, ~eq, ts, p)),
    plan_valid(~K, ~eq, g, ts, P.go(~K, ~eq, 1n+List.length(&2, P.Node<K>, g), ts, g, Nil{}, Nil{}), p, h))

def plan_needed(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +p: List<&2, K>,
  h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
) -> {P.needed(~K, ~eq, P.rev(K, p, Nil{}), g, ts) == True{} : Bool}:
  and_l(P.needed(~K, ~eq, P.rev(K, p, Nil{}), g, ts), P.all_in(~K, ~eq, ts, p),
    and_r(P.ordered(~K, ~eq, p, g, Nil{}), Bool.and(P.needed(~K, ~eq, P.rev(K, p, Nil{}), g, ts), P.all_in(~K, ~eq, ts, p)),
      plan_valid(~K, ~eq, g, ts, P.go(~K, ~eq, 1n+List.length(&2, P.Node<K>, g), ts, g, Nil{}, Nil{}), p, h)))

def plan_covers(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +p: List<&2, K>,
  h: {P.plan(~K, ~eq, g, ts) == Done{p} : Result<&2, &2, P.Error<K>, List<&2, K>>}
) -> {P.all_in(~K, ~eq, ts, p) == True{} : Bool}:
  and_r(P.needed(~K, ~eq, P.rev(K, p, Nil{}), g, ts), P.all_in(~K, ~eq, ts, p),
    and_r(P.ordered(~K, ~eq, p, g, Nil{}), Bool.and(P.needed(~K, ~eq, P.rev(K, p, Nil{}), g, ts), P.all_in(~K, ~eq, ts, p)),
      plan_valid(~K, ~eq, g, ts, P.go(~K, ~eq, 1n+List.length(&2, P.Node<K>, g), ts, g, Nil{}, Nil{}), p, h)))

def Laws.plan_targets(K, eq, sound, g, ts, p, t, h, ht):
  +g = g
  +ts = ts
  +p = p
  all_in_mem(~K, ~eq, ~sound, ts, p, t, plan_covers(~K, ~eq, g, ts, p, h), ht)

# More membership
# ---------------

def mem_cons_r.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +x: K, +t: List<&2, K>, +k: K,
  hc: {eq(k, x) == c : Bool}, h: {P.member(~K, ~eq, t, k) == True{} : Bool}
) -> {P.member(~K, ~eq, x <> t, k) == True{} : Bool}:
  match c:
    case True{}:
      mem_hit(~K, ~eq, x, t, k, hc)
    case False{}:
      Equal.trans(Bool, P.member(~K, ~eq, x <> t, k), P.member(~K, ~eq, t, k), True{}, mem_miss(~K, ~eq, x, t, k, hc), h)

def mem_cons_r(
  ~K: Data, ~eq: K -> K -> Bool, +x: K, +t: List<&2, K>, +k: K, h: {P.member(~K, ~eq, t, k) == True{} : Bool}
) -> {P.member(~K, ~eq, x <> t, k) == True{} : Bool}:
  mem_cons_r.if(~K, ~eq, eq(k, x), x, t, k, {==}, h)

# The tail of a match that misses its head.
def mem_tail(
  ~K: Data, ~eq: K -> K -> Bool, +x: K, +t: List<&2, K>, +k: K,
  hc: {eq(k, x) == False{} : Bool}, h: {P.member(~K, ~eq, x <> t, k) == True{} : Bool}
) -> {P.member(~K, ~eq, t, k) == True{} : Bool}:
  Equal.trans(Bool, P.member(~K, ~eq, t, k), P.member(~K, ~eq, x <> t, k), True{},
    Equal.sym(Bool, P.member(~K, ~eq, x <> t, k), P.member(~K, ~eq, t, k), mem_miss(~K, ~eq, x, t, k, hc)), h)

def mem_tail_false(
  ~K: Data, ~eq: K -> K -> Bool, +x: K, +t: List<&2, K>, +k: K,
  hc: {eq(k, x) == False{} : Bool}, h: {P.member(~K, ~eq, x <> t, k) == False{} : Bool}
) -> {P.member(~K, ~eq, t, k) == False{} : Bool}:
  Equal.trans(Bool, P.member(~K, ~eq, t, k), P.member(~K, ~eq, x <> t, k), False{},
    Equal.sym(Bool, P.member(~K, ~eq, x <> t, k), P.member(~K, ~eq, t, k), mem_miss(~K, ~eq, x, t, k, hc)), h)

def mem_cons_false(
  ~K: Data, ~eq: K -> K -> Bool, +x: K, +t: List<&2, K>, +k: K,
  hc: {eq(k, x) == False{} : Bool}, h: {P.member(~K, ~eq, t, k) == False{} : Bool}
) -> {P.member(~K, ~eq, x <> t, k) == False{} : Bool}:
  Equal.trans(Bool, P.member(~K, ~eq, x <> t, k), P.member(~K, ~eq, t, k), False{}, mem_miss(~K, ~eq, x, t, k, hc), h)

def clash(-b: Bool, ht: {b == True{} : Bool}, hf: {b == False{} : Bool}) -> Empty:
  true_ne_false(Equal.trans(Bool, True{}, b, False{}, Equal.sym(Bool, b, True{}, ht), hf))

def or_false_l(a: Bool, -b: Bool, hz: {a == False{} : Bool}, h: {Bool.or(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({b == True{} : Bool}, true_ne_false(hz))
    case False{}:
      h

def and_not_false(a: Bool, -b: Bool, ha: {a == False{} : Bool}, hb: {b == True{} : Bool}) -> {Bool.and(Bool.not(a), b) == True{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({Bool.and(Bool.not(True{}), b) == True{} : Bool}, true_ne_false(ha))
    case False{}:
      hb

def and_true(a: Bool, -b: Bool, ha: {a == True{} : Bool}, hb: {b == True{} : Bool}) -> {Bool.and(a, b) == True{} : Bool}:
  match a:
    case True{}:
      hb
    case False{}:
      Empty.absurd({Bool.and(False{}, b) == True{} : Bool}, false_ne_true(ha))

def rev_mem_r(
  ~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +acc: List<&2, K>, +k: K, h: {P.member(~K, ~eq, acc, k) == True{} : Bool}
) -> {P.member(~K, ~eq, P.rev(K, xs, acc), k) == True{} : Bool}:
  match xs:
    case Nil{}:
      h
    case Con{+x, t}:
      rev_mem_r(~K, ~eq, t, x <> acc, k, mem_cons_r(~K, ~eq, x, acc, k, h))

def rev_mem_l.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +x: K, +t: List<&2, K>, +acc: List<&2, K>, +k: K,
  hc: {eq(k, x) == c : Bool}, h: {P.member(~K, ~eq, x <> t, k) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, k) == True{} : Bool} -> {P.member(~K, ~eq, P.rev(K, t, x <> acc), k) == True{} : Bool}
) -> {P.member(~K, ~eq, P.rev(K, t, x <> acc), k) == True{} : Bool}:
  match c:
    case True{}:
      rev_mem_r(~K, ~eq, t, x <> acc, k, mem_hit(~K, ~eq, x, acc, k, hc))
    case False{}:
      ih(mem_tail(~K, ~eq, x, t, k, hc, h))

def rev_mem_l(
  ~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +acc: List<&2, K>, +k: K, h: {P.member(~K, ~eq, xs, k) == True{} : Bool}
) -> {P.member(~K, ~eq, P.rev(K, xs, acc), k) == True{} : Bool}:
  match xs:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, acc, k) == True{} : Bool}, false_ne_true(h))
    case Con{+x, +t}:
      rev_mem_l.if(~K, ~eq, eq(k, x), x, t, acc, k, {==}, h, hm => rev_mem_l(~K, ~eq, t, x <> acc, k, hm))

def rev_mem_inv.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +x: K, +t: List<&2, K>, +acc: List<&2, K>, +k: K,
  hc: {eq(k, x) == c : Bool}, hn: {P.member(~K, ~eq, acc, k) == False{} : Bool},
  ih: {P.member(~K, ~eq, x <> acc, k) == False{} : Bool} -> {P.member(~K, ~eq, t, k) == True{} : Bool}
) -> {P.member(~K, ~eq, x <> t, k) == True{} : Bool}:
  match c:
    case True{}:
      mem_hit(~K, ~eq, x, t, k, hc)
    case False{}:
      mem_cons_r(~K, ~eq, x, t, k, ih(mem_cons_false(~K, ~eq, x, acc, k, hc, hn)))

# A member of rev(xs, acc) that is not in acc is in xs.
def rev_mem_inv(
  ~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +acc: List<&2, K>, +k: K,
  h: {P.member(~K, ~eq, P.rev(K, xs, acc), k) == True{} : Bool}, hn: {P.member(~K, ~eq, acc, k) == False{} : Bool}
) -> {P.member(~K, ~eq, xs, k) == True{} : Bool}:
  match xs:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, Nil{}, k) == True{} : Bool}, clash(P.member(~K, ~eq, acc, k), h, hn))
    case Con{+x, +t}:
      rev_mem_inv.if(~K, ~eq, eq(k, x), x, t, acc, k, {==}, hn, hm => rev_mem_inv(~K, ~eq, t, x <> acc, k, h, hm))

def rev_not.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, xs: List<&2, K>, +acc: List<&2, K>, +k: K,
  hc: {P.member(~K, ~eq, xs, k) == c : Bool}, h: {P.member(~K, ~eq, P.rev(K, xs, acc), k) == False{} : Bool}
) -> {c == False{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, clash(P.member(~K, ~eq, P.rev(K, xs, acc), k), rev_mem_l(~K, ~eq, xs, acc, k, hc), h))
    case False{}:
      {==}

def rev_not(
  ~K: Data, ~eq: K -> K -> Bool, +xs: List<&2, K>, +acc: List<&2, K>, +k: K,
  h: {P.member(~K, ~eq, P.rev(K, xs, acc), k) == False{} : Bool}
) -> {P.member(~K, ~eq, xs, k) == False{} : Bool}:
  rev_not.if(~K, ~eq, P.member(~K, ~eq, xs, k), xs, acc, k, {==}, h)

# Order
# -----

def ord_cat(
  ~K: Data, ~eq: K -> K -> Bool, pre: List<&2, K>, +rest: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>,
  h: {P.ordered(~K, ~eq, P.cat(K, pre, rest), g, done) == True{} : Bool}
) -> {P.ordered(~K, ~eq, rest, g, P.rev(K, pre, done)) == True{} : Bool}:
  match pre:
    case Nil{}:
      h
    case Con{+y, +t}:
      ord_cat(~K, ~eq, t, rest, g, y <> done,
        and_r(P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done), P.ordered(~K, ~eq, P.cat(K, t, rest), g, y <> done),
          and_r(Bool.not(P.member(~K, ~eq, done, y)),
            Bool.and(P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done), P.ordered(~K, ~eq, P.cat(K, t, rest), g, y <> done)), h)))

# The facts that ordered checks for the head y.
def ord_fresh(
  ~K: Data, ~eq: K -> K -> Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>,
  h: {P.ordered(~K, ~eq, y <> t, g, done) == True{} : Bool}
) -> {P.member(~K, ~eq, done, y) == False{} : Bool}:
  not_true(P.member(~K, ~eq, done, y), and_l(Bool.not(P.member(~K, ~eq, done, y)),
    Bool.and(P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done), P.ordered(~K, ~eq, t, g, y <> done)), h))

def ord_node(
  ~K: Data, ~eq: K -> K -> Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>,
  h: {P.ordered(~K, ~eq, y <> t, g, done) == True{} : Bool}
) -> {P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done) == True{} : Bool}:
  and_l(P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done), P.ordered(~K, ~eq, t, g, y <> done),
    and_r(Bool.not(P.member(~K, ~eq, done, y)),
      Bool.and(P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done), P.ordered(~K, ~eq, t, g, y <> done)), h))

def ord_rest(
  ~K: Data, ~eq: K -> K -> Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>,
  h: {P.ordered(~K, ~eq, y <> t, g, done) == True{} : Bool}
) -> {P.ordered(~K, ~eq, t, g, y <> done) == True{} : Bool}:
  and_r(P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done), P.ordered(~K, ~eq, t, g, y <> done),
    and_r(Bool.not(P.member(~K, ~eq, done, y)),
      Bool.and(P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done), P.ordered(~K, ~eq, t, g, y <> done)), h))

def node_some(~K: Data, ~eq: K -> K -> Bool, m: Maybe<&2, List<&2, K>>, +done: List<&2, K>,
  h: {P.ordered.node(~K, ~eq, m, done) == True{} : Bool}
) -> {Maybe.is_some(&2, List<&2, K>, m) == True{} : Bool}:
  match m:
    case None{}:
      Empty.absurd({False{} == True{} : Bool}, false_ne_true(h))
    case Some{ds}:
      {==}

# ordered.node at a node whose prerequisites are ds: all of ds are done.
def node_all(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +x: K, +ds: List<&2, K>, +done: List<&2, K>,
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>},
  h: {P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, x), done) == True{} : Bool}
) -> {P.all_in(~K, ~eq, ds, done) == True{} : Bool}:
  Equal.trans(Bool, P.all_in(~K, ~eq, ds, done), P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, x), done), True{},
    Equal.sym(Bool, P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, x), done), P.all_in(~K, ~eq, ds, done),
      Equal.cong(Maybe<&2, List<&2, K>>, Bool, m => P.ordered.node(~K, ~eq, m, done), P.deps(~K, ~eq, g, x), Some{ds}, hd)), h)

# ordered.node moved along x == y.
def node_move(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +x: K, +y: K, +done: List<&2, K>,
  e: {x == y : K}, h: {P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done) == True{} : Bool}
) -> {P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, x), done) == True{} : Bool}:
  Equal.trans(Bool, P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, x), done), P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done), True{},
    Equal.cong(K, Bool, z => P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, z), done), x, y, e), h)

def defined_go.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>, +x: K,
  hc: {eq(x, y) == c : Bool}, hO: {P.ordered(~K, ~eq, y <> t, g, done) == True{} : Bool},
  hx: {P.member(~K, ~eq, y <> t, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {Maybe.is_some(&2, List<&2, K>, P.deps(~K, ~eq, g, x)) == True{} : Bool}
) -> {Maybe.is_some(&2, List<&2, K>, P.deps(~K, ~eq, g, x)) == True{} : Bool}:
  match c:
    case True{}:
      node_some(~K, ~eq, P.deps(~K, ~eq, g, x), done, node_move(~K, ~eq, g, x, y, done, sound(x, y, hc), ord_node(~K, ~eq, y, t, g, done, hO)))
    case False{}:
      ih(mem_tail(~K, ~eq, y, t, x, hc, hx))

def defined_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>, +x: K,
  hO: {P.ordered(~K, ~eq, p, g, done) == True{} : Bool}, hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
) -> {Maybe.is_some(&2, List<&2, K>, P.deps(~K, ~eq, g, x)) == True{} : Bool}:
  match p:
    case Nil{}:
      Empty.absurd({Maybe.is_some(&2, List<&2, K>, P.deps(~K, ~eq, g, x)) == True{} : Bool}, false_ne_true(hx))
    case Con{+y, +t}:
      +hO = hO
      defined_go.if(~K, ~eq, ~sound, eq(x, y), y, t, g, done, x, {==}, hO, hx,
        hm => defined_go(~K, ~eq, ~sound, t, g, y <> done, x, ord_rest(~K, ~eq, y, t, g, done, hO), hm))

def Laws.plan_defined(K, eq, sound, g, ts, p, x, h, hx):
  +g = g
  +ts = ts
  +p = p
  defined_go(~K, ~eq, ~sound, p, g, Nil{}, x, plan_ordered(~K, ~eq, g, ts, p, h), hx)

def split_ordered(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +pre: List<&2, K>, +x: K, +post: List<&2, K>,
  h: {P.plan(~K, ~eq, g, ts) == Done{P.cat(K, pre, x <> post)} : Result<&2, &2, P.Error<K>, List<&2, K>>}
) -> {P.ordered(~K, ~eq, x <> post, g, P.rev(K, pre, Nil{})) == True{} : Bool}:
  ord_cat(~K, ~eq, pre, x <> post, g, Nil{}, plan_ordered(~K, ~eq, g, ts, P.cat(K, pre, x <> post), h))

def Laws.plan_before(K, eq, sound, g, ts, pre, x, post, ds, d, h, hd, hm):
  +g = g
  +pre = pre
  +x = x
  +post = post
  +ds = ds
  +d = d
  +done = P.rev(K, pre, Nil{})
  rev_mem_inv(~K, ~eq, pre, Nil{}, d,
    all_in_mem(~K, ~eq, ~sound, ds, done, d,
      node_all(~K, ~eq, g, x, ds, done, hd, ord_node(~K, ~eq, x, post, g, done, split_ordered(~K, ~eq, g, ts, pre, x, post, h))),
      hm),
    {==})

def Laws.plan_once(K, eq, sound, g, ts, pre, x, post, h):
  +g = g
  +pre = pre
  +x = x
  +post = post
  +done = P.rev(K, pre, Nil{})
  rev_not(~K, ~eq, pre, Nil{}, x, ord_fresh(~K, ~eq, x, post, g, done, split_ordered(~K, ~eq, g, ts, pre, x, post, h)))

def closed_go.d(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +y: K, +t: List<&2, K>, +done: List<&2, K>, +d: K,
  hc: {eq(d, y) == c : Bool}, hnd: {P.member(~K, ~eq, done, d) == False{} : Bool},
  ih: {P.member(~K, ~eq, y <> done, d) == False{} : Bool} -> {P.member(~K, ~eq, t, d) == True{} : Bool}
) -> {P.member(~K, ~eq, y <> t, d) == True{} : Bool}:
  match c:
    case True{}:
      mem_hit(~K, ~eq, y, t, d, hc)
    case False{}:
      mem_cons_r(~K, ~eq, y, t, d, ih(mem_cons_false(~K, ~eq, y, done, d, hc, hnd)))

def closed_go.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>,
  +x: K, +ds: List<&2, K>, +d: K,
  hc: {eq(x, y) == c : Bool}, hO: {P.ordered(~K, ~eq, y <> t, g, done) == True{} : Bool}, hx: {P.member(~K, ~eq, y <> t, x) == True{} : Bool},
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, hm: {P.member(~K, ~eq, ds, d) == True{} : Bool},
  hnd: {P.member(~K, ~eq, done, d) == False{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {P.member(~K, ~eq, y <> done, d) == False{} : Bool} -> {P.member(~K, ~eq, t, d) == True{} : Bool}
) -> {P.member(~K, ~eq, y <> t, d) == True{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, y <> t, d) == True{} : Bool},
        clash(P.member(~K, ~eq, done, d),
          all_in_mem(~K, ~eq, ~sound, ds, done, d,
            node_all(~K, ~eq, g, x, ds, done, hd, node_move(~K, ~eq, g, x, y, done, sound(x, y, hc), ord_node(~K, ~eq, y, t, g, done, hO))), hm),
          hnd))
    case False{}:
      closed_go.d(~K, ~eq, eq(d, y), y, t, done, d, {==}, hnd, ih(mem_tail(~K, ~eq, y, t, x, hc, hx)))

# A prerequisite of a node of p that is not done is in p.
def closed_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>,
  +x: K, +ds: List<&2, K>, +d: K,
  hO: {P.ordered(~K, ~eq, p, g, done) == True{} : Bool}, hx: {P.member(~K, ~eq, p, x) == True{} : Bool},
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, hm: {P.member(~K, ~eq, ds, d) == True{} : Bool},
  hnd: {P.member(~K, ~eq, done, d) == False{} : Bool}
) -> {P.member(~K, ~eq, p, d) == True{} : Bool}:
  match p:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, Nil{}, d) == True{} : Bool}, false_ne_true(hx))
    case Con{+y, +t}:
      +hO = hO
      +hd = hd
      +hm = hm
      closed_go.if(~K, ~eq, ~sound, eq(x, y), y, t, g, done, x, ds, d, {==}, hO, hx, hd, hm, hnd,
        h1 => h2 => closed_go(~K, ~eq, ~sound, t, g, y <> done, x, ds, d, ord_rest(~K, ~eq, y, t, g, done, hO), h1, hd, hm, h2))

def Laws.plan_closed(K, eq, sound, g, ts, p, x, ds, d, h, hx, hd, hm):
  +g = g
  +ts = ts
  +p = p
  closed_go(~K, ~eq, ~sound, p, g, Nil{}, x, ds, d, plan_ordered(~K, ~eq, g, ts, p, h), hx, hd, hm, {==})

# Least
# -----

def all_in_cat(
  ~K: Data, ~eq: K -> K -> Bool, a: List<&2, K>, +b: List<&2, K>, +s: List<&2, K>,
  ha: {P.all_in(~K, ~eq, a, s) == True{} : Bool}, hb: {P.all_in(~K, ~eq, b, s) == True{} : Bool}
) -> {P.all_in(~K, ~eq, P.cat(K, a, b), s) == True{} : Bool}:
  match a:
    case Nil{}:
      hb
    case Con{+x, +t}:
      +ha = ha
      and_true(P.member(~K, ~eq, s, x), P.all_in(~K, ~eq, P.cat(K, t, b), s),
        and_l(P.member(~K, ~eq, s, x), P.all_in(~K, ~eq, t, s), ha),
        all_in_cat(~K, ~eq, t, b, s, and_r(P.member(~K, ~eq, s, x), P.all_in(~K, ~eq, t, s), ha), hb))

def closed_mem.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +s: List<&2, K>, +y: K,
  hc: {eq(y, z) == c : Bool}, hz: {P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, z), s) == True{} : Bool},
  hy: {P.member(~K, ~eq, z <> t, y) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, y) == True{} : Bool} -> {P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), s) == True{} : Bool}
) -> {P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), s) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(K, y, z, sound(y, z, hc)) : {P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, _), s) == True{} : Bool}
      hz
    case False{}:
      ih(mem_tail(~K, ~eq, z, t, y, hc, hy))

def closed_mem(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), xs: List<&2, K>, +g: List<&2, P.Node<K>>, +s: List<&2, K>, +y: K,
  hc: {Laws.closed(~K, ~eq, xs, g, s) == True{} : Bool}, hy: {P.member(~K, ~eq, xs, y) == True{} : Bool}
) -> {P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), s) == True{} : Bool}:
  match xs:
    case Nil{}:
      Empty.absurd({P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), s) == True{} : Bool}, false_ne_true(hy))
    case Con{+z, +t}:
      +hc = hc
      closed_mem.if(~K, ~eq, ~sound, eq(y, z), z, t, g, s, y, {==},
        and_l(P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, z), s), Laws.closed(~K, ~eq, t, g, s), hc), hy,
        hm => closed_mem(~K, ~eq, ~sound, t, g, s, y, and_r(P.all_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, z), s), Laws.closed(~K, ~eq, t, g, s), hc), hm))

def needed_sub.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +y: K, +t: List<&2, K>, +s: List<&2, K>, +x: K,
  hc: {eq(x, y) == c : Bool}, hy: {P.member(~K, ~eq, s, y) == True{} : Bool}, hx: {P.member(~K, ~eq, y <> t, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {P.member(~K, ~eq, s, x) == True{} : Bool}
) -> {P.member(~K, ~eq, s, x) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(K, x, y, sound(x, y, hc)) : {P.member(~K, ~eq, s, _) == True{} : Bool}
      hy
    case False{}:
      ih(mem_tail(~K, ~eq, y, t, x, hc, hx))

# Every node that needed walks is in a closed set that holds want.
def needed_sub(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), r: List<&2, K>, +g: List<&2, P.Node<K>>, +want: List<&2, K>, +s: List<&2, K>, +x: K,
  hN: {P.needed(~K, ~eq, r, g, want) == True{} : Bool}, hw: {P.all_in(~K, ~eq, want, s) == True{} : Bool},
  hcl: {Laws.closed(~K, ~eq, s, g, s) == True{} : Bool}, hx: {P.member(~K, ~eq, r, x) == True{} : Bool}
) -> {P.member(~K, ~eq, s, x) == True{} : Bool}:
  match r:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, s, x) == True{} : Bool}, false_ne_true(hx))
    case Con{+y, +t}:
      +hN = hN
      +hw = hw
      +hcl = hcl
      +dn = P.deps.or_nil(~K, ~eq, g, y)
      +hy = all_in_mem(~K, ~eq, ~sound, want, s, y, hw, and_l(P.member(~K, ~eq, want, y), P.needed(~K, ~eq, t, g, P.cat(K, dn, want)), hN))
      needed_sub.if(~K, ~eq, ~sound, eq(x, y), y, t, s, x, {==}, hy, hx,
        hm => needed_sub(~K, ~eq, ~sound, t, g, P.cat(K, dn, want), s, x,
          and_r(P.member(~K, ~eq, want, y), P.needed(~K, ~eq, t, g, P.cat(K, dn, want)), hN),
          all_in_cat(~K, ~eq, dn, want, s, closed_mem(~K, ~eq, ~sound, s, g, s, y, hcl, hy), hw),
          hcl, hm))

def Laws.plan_least(K, eq, sound, g, ts, s, hts, hcl, p, x, h, hx):
  +g = g
  +ts = ts
  +p = p
  +x = x
  needed_sub(~K, ~eq, ~sound, P.rev(K, p, Nil{}), g, ts, s, x, plan_needed(~K, ~eq, g, ts, p, h), hts, hcl,
    rev_mem_l(~K, ~eq, p, Nil{}, x, hx))

# Cycles
# ------

# No member of done is in c.
def disj(~K: Data, ~eq: K -> K -> Bool, done: List<&2, K>, +c: List<&2, K>) -> Bool:
  match done:
    case Nil{}:
      True{}
    case Con{+z, t}:
      Bool.and(Bool.not(P.member(~K, ~eq, c, z)), disj(~K, ~eq, t, c))

def disj_mem.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +z: K, +t: List<&2, K>, +c: List<&2, K>, +w: K,
  hb: {eq(w, z) == b : Bool}, hz: {P.member(~K, ~eq, c, z) == False{} : Bool}, hw: {P.member(~K, ~eq, z <> t, w) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, w) == True{} : Bool} -> {P.member(~K, ~eq, c, w) == False{} : Bool}
) -> {P.member(~K, ~eq, c, w) == False{} : Bool}:
  match b:
    case True{}:
      %Equal.sym(K, w, z, sound(w, z, hb)) : {P.member(~K, ~eq, c, _) == False{} : Bool}
      hz
    case False{}:
      ih(mem_tail(~K, ~eq, z, t, w, hb, hw))

def disj_mem(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), done: List<&2, K>, +c: List<&2, K>, +w: K,
  hd: {disj(~K, ~eq, done, c) == True{} : Bool}, hw: {P.member(~K, ~eq, done, w) == True{} : Bool}
) -> {P.member(~K, ~eq, c, w) == False{} : Bool}:
  match done:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, c, w) == False{} : Bool}, false_ne_true(hw))
    case Con{+z, +t}:
      +hd = hd
      disj_mem.if(~K, ~eq, ~sound, eq(w, z), z, t, c, w, {==},
        not_true(P.member(~K, ~eq, c, z), and_l(Bool.not(P.member(~K, ~eq, c, z)), disj(~K, ~eq, t, c), hd)), hw,
        hm => disj_mem(~K, ~eq, ~sound, t, c, w, and_r(Bool.not(P.member(~K, ~eq, c, z)), disj(~K, ~eq, t, c), hd), hm))

def cyclic_mem.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +z: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +c: List<&2, K>, +y: K,
  hb: {eq(y, z) == b : Bool}, hz: {P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, z), c) == True{} : Bool},
  hy: {P.member(~K, ~eq, z <> t, y) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, y) == True{} : Bool} -> {P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), c) == True{} : Bool}
) -> {P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), c) == True{} : Bool}:
  match b:
    case True{}:
      %Equal.sym(K, y, z, sound(y, z, hb)) : {P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, _), c) == True{} : Bool}
      hz
    case False{}:
      ih(mem_tail(~K, ~eq, z, t, y, hb, hy))

def cyclic_mem(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), xs: List<&2, K>, +g: List<&2, P.Node<K>>, +c: List<&2, K>, +y: K,
  hc: {Laws.cyclic(~K, ~eq, xs, g, c) == True{} : Bool}, hy: {P.member(~K, ~eq, xs, y) == True{} : Bool}
) -> {P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), c) == True{} : Bool}:
  match xs:
    case Nil{}:
      Empty.absurd({P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), c) == True{} : Bool}, false_ne_true(hy))
    case Con{+z, +t}:
      +hc = hc
      cyclic_mem.if(~K, ~eq, ~sound, eq(y, z), z, t, g, c, y, {==},
        and_l(P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, z), c), Laws.cyclic(~K, ~eq, t, g, c), hc), hy,
        hm => cyclic_mem(~K, ~eq, ~sound, t, g, c, y, and_r(P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, z), c), Laws.cyclic(~K, ~eq, t, g, c), hc), hm))

def any_all_disj.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +w: K, +t: List<&2, K>, +done: List<&2, K>, +c: List<&2, K>,
  hb: {P.member(~K, ~eq, c, w) == b : Bool}, hw: {P.member(~K, ~eq, done, w) == True{} : Bool},
  hd: {disj(~K, ~eq, done, c) == True{} : Bool}, hy: {Bool.or(b, P.any_in(~K, ~eq, t, c)) == True{} : Bool},
  ih: {P.any_in(~K, ~eq, t, c) == True{} : Bool} -> Empty
) -> Empty:
  match b:
    case True{}:
      clash(P.member(~K, ~eq, c, w), hb, disj_mem(~K, ~eq, ~sound, done, c, w, hd, hw))
    case False{}:
      ih(hy)

# No prerequisite list lies wholly in done and meets c, when done misses c.
def any_all_disj(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ds: List<&2, K>, +done: List<&2, K>, +c: List<&2, K>,
  ha: {P.all_in(~K, ~eq, ds, done) == True{} : Bool}, hy: {P.any_in(~K, ~eq, ds, c) == True{} : Bool},
  hd: {disj(~K, ~eq, done, c) == True{} : Bool}
) -> Empty:
  match ds:
    case Nil{}:
      false_ne_true(hy)
    case Con{+w, +t}:
      +ha = ha
      +hd = hd
      any_all_disj.if(~K, ~eq, ~sound, P.member(~K, ~eq, c, w), w, t, done, c, {==},
        and_l(P.member(~K, ~eq, done, w), P.all_in(~K, ~eq, t, done), ha), hd, hy,
        h => any_all_disj(~K, ~eq, ~sound, t, done, c, and_r(P.member(~K, ~eq, done, w), P.all_in(~K, ~eq, t, done), ha), h, hd))

def cycle_head.m(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), m: Maybe<&2, List<&2, K>>, +done: List<&2, K>, +c: List<&2, K>,
  hn: {P.ordered.node(~K, ~eq, m, done) == True{} : Bool},
  hy: {P.any_in(~K, ~eq, Maybe.default(&2, List<&2, K>, m, Nil{}), c) == True{} : Bool},
  hd: {disj(~K, ~eq, done, c) == True{} : Bool}
) -> Empty:
  match m:
    case None{}:
      false_ne_true(hn)
    case Some{ds}:
      any_all_disj(~K, ~eq, ~sound, ds, done, c, hn, hy, hd)

def cycle_head.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +y: K, +g: List<&2, P.Node<K>>, +done: List<&2, K>, +c: List<&2, K>,
  hb: {P.member(~K, ~eq, c, y) == b : Bool}, hcy: {Laws.cyclic(~K, ~eq, c, g, c) == True{} : Bool},
  hn: {P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, y), done) == True{} : Bool}, hd: {disj(~K, ~eq, done, c) == True{} : Bool}
) -> {b == False{} : Bool}:
  match b:
    case True{}:
      Empty.absurd({True{} == False{} : Bool},
        cycle_head.m(~K, ~eq, ~sound, P.deps(~K, ~eq, g, y), done, c, hn, cyclic_mem(~K, ~eq, ~sound, c, g, c, y, hcy, hb), hd))
    case False{}:
      {==}

def cycle_go.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +y: K, +t: List<&2, K>, +c: List<&2, K>, +x: K,
  hb: {eq(x, y) == b : Bool}, hy: {P.member(~K, ~eq, c, y) == False{} : Bool}, hx: {P.member(~K, ~eq, y <> t, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {P.member(~K, ~eq, c, x) == False{} : Bool}
) -> {P.member(~K, ~eq, c, x) == False{} : Bool}:
  match b:
    case True{}:
      %Equal.sym(K, x, y, sound(x, y, hb)) : {P.member(~K, ~eq, c, _) == False{} : Bool}
      hy
    case False{}:
      ih(mem_tail(~K, ~eq, y, t, x, hb, hx))

def cycle_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>, +c: List<&2, K>, +x: K,
  hO: {P.ordered(~K, ~eq, p, g, done) == True{} : Bool}, hd: {disj(~K, ~eq, done, c) == True{} : Bool},
  hcy: {Laws.cyclic(~K, ~eq, c, g, c) == True{} : Bool}, hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
) -> {P.member(~K, ~eq, c, x) == False{} : Bool}:
  match p:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, c, x) == False{} : Bool}, false_ne_true(hx))
    case Con{+y, +t}:
      +hO = hO
      +hd = hd
      +hcy = hcy
      +hy = cycle_head.if(~K, ~eq, ~sound, P.member(~K, ~eq, c, y), y, g, done, c, {==}, hcy, ord_node(~K, ~eq, y, t, g, done, hO), hd)
      cycle_go.if(~K, ~eq, ~sound, eq(x, y), y, t, c, x, {==}, hy, hx,
        hm => cycle_go(~K, ~eq, ~sound, t, g, y <> done, c, x, ord_rest(~K, ~eq, y, t, g, done, hO),
          and_not_false(P.member(~K, ~eq, c, y), disj(~K, ~eq, done, c), hy, hd), hcy, hm))

def Laws.plan_cycle(K, eq, sound, g, c, hc, ts, p, x, h, hx):
  +g = g
  +ts = ts
  +p = p
  cycle_go(~K, ~eq, ~sound, p, g, Nil{}, c, x, plan_ordered(~K, ~eq, g, ts, p, h), {==}, hc, hx)

def Laws.plan_cycle_target(K, eq, sound, g, c, hc, ts, t, ht, hct, p, h):
  +g = g
  +c = c
  +ts = ts
  +p = p
  +t = t
  +h = h
  clash(P.member(~K, ~eq, c, t), hct,
    Laws.plan_cycle(~K, ~eq, ~sound, g, c, hc, ts, p, t, h, Laws.plan_targets(~K, ~eq, ~sound, g, ts, p, t, h, ht)))

# Invalidation
# ------------

def or_true_l(a: Bool, -b: Bool, ha: {a == True{} : Bool}) -> {Bool.or(a, b) == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      Empty.absurd({Bool.or(False{}, b) == True{} : Bool}, false_ne_true(ha))

def or_true_r(a: Bool, -b: Bool, hb: {b == True{} : Bool}) -> {Bool.or(a, b) == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      hb

def or_mono(a: Bool, -b: Bool, -c: Bool, h: {Bool.or(a, b) == True{} : Bool}, f: {b == True{} : Bool} -> {c == True{} : Bool}) ->
  {Bool.or(a, c) == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      f(h)

def imp_true(a: Bool, -b: Bool, ha: {a == True{} : Bool}, h: {Bool.or(Bool.not(a), b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      h
    case False{}:
      Empty.absurd({b == True{} : Bool}, false_ne_true(ha))

def Hit(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>, +y: K) -> Bool:
  Bool.or(P.member(~K, ~eq, changed, y), P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), acc))

def Acc(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>, +y: K) -> List<&2, K>:
  P.invalidate.if(K, Hit(~K, ~eq, g, changed, acc, y), y, acc)

def IG(~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>) -> List<&2, K>:
  P.invalidate.go(~K, ~eq, p, g, changed, acc)

def inv_if_mono(~K: Data, ~eq: K -> K -> Bool, c: Bool, +y: K, +acc: List<&2, K>, +k: K, h: {P.member(~K, ~eq, acc, k) == True{} : Bool}) ->
  {P.member(~K, ~eq, P.invalidate.if(K, c, y, acc), k) == True{} : Bool}:
  match c:
    case True{}:
      mem_cons_r(~K, ~eq, y, acc, k, h)
    case False{}:
      h

def inv_if_hit(~K: Data, ~eq: K -> K -> Bool, c: Bool, +y: K, +acc: List<&2, K>, +k: K, hc: {c == True{} : Bool}, he: {eq(k, y) == True{} : Bool}) ->
  {P.member(~K, ~eq, P.invalidate.if(K, c, y, acc), k) == True{} : Bool}:
  match c:
    case True{}:
      mem_hit(~K, ~eq, y, acc, k, he)
    case False{}:
      Empty.absurd({P.member(~K, ~eq, acc, k) == True{} : Bool}, false_ne_true(hc))

def inv_if_miss(~K: Data, ~eq: K -> K -> Bool, c: Bool, +y: K, +acc: List<&2, K>, +k: K, he: {eq(k, y) == False{} : Bool},
  h: {P.member(~K, ~eq, P.invalidate.if(K, c, y, acc), k) == True{} : Bool}
) -> {P.member(~K, ~eq, acc, k) == True{} : Bool}:
  match c:
    case True{}:
      mem_tail(~K, ~eq, y, acc, k, he, h)
    case False{}:
      h

def inv_if_false(~K: Data, ~eq: K -> K -> Bool, c: Bool, +y: K, +acc: List<&2, K>, +k: K, hc: {c == False{} : Bool},
  h: {P.member(~K, ~eq, P.invalidate.if(K, c, y, acc), k) == True{} : Bool}
) -> {P.member(~K, ~eq, acc, k) == True{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, acc, k) == True{} : Bool}, true_ne_false(hc))
    case False{}:
      h

def inv_if_all(~K: Data, ~eq: K -> K -> Bool, c: Bool, +y: K, +acc: List<&2, K>, +s: List<&2, K>,
  hy: {c == True{} : Bool} -> {P.member(~K, ~eq, s, y) == True{} : Bool}, ha: {P.all_in(~K, ~eq, acc, s) == True{} : Bool}
) -> {P.all_in(~K, ~eq, P.invalidate.if(K, c, y, acc), s) == True{} : Bool}:
  match c:
    case True{}:
      and_true(P.member(~K, ~eq, s, y), P.all_in(~K, ~eq, acc, s), hy({==}), ha)
    case False{}:
      ha

# Invalidation never drops a stale node.
def inv_mono(~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>, +k: K,
  h: {P.member(~K, ~eq, acc, k) == True{} : Bool}
) -> {P.member(~K, ~eq, IG(~K, ~eq, p, g, changed, acc), k) == True{} : Bool}:
  match p:
    case Nil{}:
      h
    case Con{+y, t}:
      inv_mono(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y), k, inv_if_mono(~K, ~eq, Hit(~K, ~eq, g, changed, acc, y), y, acc, k, h))

def mem_move(~K: Data, ~eq: K -> K -> Bool, +xs: List<&2, K>, +x: K, +y: K, e: {x == y : K}, h: {P.member(~K, ~eq, xs, x) == True{} : Bool}) ->
  {P.member(~K, ~eq, xs, y) == True{} : Bool}:
  Equal.trans(Bool, P.member(~K, ~eq, xs, y), P.member(~K, ~eq, xs, x), True{},
    Equal.cong(K, Bool, z => P.member(~K, ~eq, xs, z), y, x, Equal.sym(K, x, y, e)), h)

def changed_go.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>,
  +acc: List<&2, K>, +x: K,
  +hb: {eq(x, y) == b : Bool}, hx: {P.member(~K, ~eq, y <> t, x) == True{} : Bool}, hc: {P.member(~K, ~eq, changed, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {P.member(~K, ~eq, IG(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y)), x) == True{} : Bool}
) -> {P.member(~K, ~eq, IG(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y)), x) == True{} : Bool}:
  match b:
    case True{}:
      inv_mono(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y), x,
        inv_if_hit(~K, ~eq, Hit(~K, ~eq, g, changed, acc, y), y, acc, x,
          or_true_l(P.member(~K, ~eq, changed, y), P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), acc),
            mem_move(~K, ~eq, changed, x, y, sound(x, y, hb), hc)),
          hb))
    case False{}:
      ih(mem_tail(~K, ~eq, y, t, x, hb, hx))

def changed_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>, +x: K,
  hx: {P.member(~K, ~eq, p, x) == True{} : Bool}, hc: {P.member(~K, ~eq, changed, x) == True{} : Bool}
) -> {P.member(~K, ~eq, IG(~K, ~eq, p, g, changed, acc), x) == True{} : Bool}:
  match p:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, acc, x) == True{} : Bool}, false_ne_true(hx))
    case Con{+y, +t}:
      +hc = hc
      changed_go.if(~K, ~eq, ~sound, eq(x, y), y, t, g, changed, acc, x, {==}, hx, hc,
        hm => changed_go(~K, ~eq, ~sound, t, g, changed, Acc(~K, ~eq, g, changed, acc, y), x, hm, hc))

def Laws.stale_changed(K, eq, sound, p, g, changed, x, hx, hc):
  changed_go(~K, ~eq, ~sound, p, g, changed, Nil{}, x, hx, hc)

def ord_notin.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +z: K, +r: List<&2, K>, +done: List<&2, K>, +d: K,
  hb: {eq(d, z) == b : Bool}, hz: {P.member(~K, ~eq, done, z) == False{} : Bool}, hd: {P.member(~K, ~eq, done, d) == True{} : Bool},
  ih: {P.member(~K, ~eq, r, d) == False{} : Bool}
) -> {P.member(~K, ~eq, z <> r, d) == False{} : Bool}:
  match b:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, z <> r, d) == False{} : Bool},
        clash(P.member(~K, ~eq, done, z), mem_move(~K, ~eq, done, d, z, sound(d, z, hb), hd), hz))
    case False{}:
      mem_cons_false(~K, ~eq, z, r, d, hb, ih)

# A done node does not come again.
def ord_notin(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), t: List<&2, K>, +g: List<&2, P.Node<K>>, +done: List<&2, K>, +d: K,
  hO: {P.ordered(~K, ~eq, t, g, done) == True{} : Bool}, hd: {P.member(~K, ~eq, done, d) == True{} : Bool}
) -> {P.member(~K, ~eq, t, d) == False{} : Bool}:
  match t:
    case Nil{}:
      {==}
    case Con{+z, +r}:
      +hO = hO
      +hd = hd
      ord_notin.if(~K, ~eq, ~sound, eq(d, z), z, r, done, d, {==}, ord_fresh(~K, ~eq, z, r, g, done, hO), hd,
        ord_notin(~K, ~eq, ~sound, r, g, z <> done, d, ord_rest(~K, ~eq, z, r, g, done, hO), mem_cons_r(~K, ~eq, z, done, d, hd)))

def inv_notin.if(
  ~K: Data, ~eq: K -> K -> Bool, b: Bool, +z: K, +r: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>, +d: K,
  +hb: {eq(d, z) == b : Bool}, hn: {P.member(~K, ~eq, z <> r, d) == False{} : Bool},
  ih: {P.member(~K, ~eq, r, d) == False{} : Bool} -> {P.member(~K, ~eq, Acc(~K, ~eq, g, changed, acc, z), d) == True{} : Bool}
) -> {P.member(~K, ~eq, acc, d) == True{} : Bool}:
  match b:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, acc, d) == True{} : Bool}, clash(P.member(~K, ~eq, z <> r, d), mem_hit(~K, ~eq, z, r, d, hb), hn))
    case False{}:
      inv_if_miss(~K, ~eq, Hit(~K, ~eq, g, changed, acc, z), z, acc, d, hb, ih(mem_tail_false(~K, ~eq, z, r, d, hb, hn)))

# Invalidation adds only nodes of p.
def inv_notin(
  ~K: Data, ~eq: K -> K -> Bool, t: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>, +d: K,
  hn: {P.member(~K, ~eq, t, d) == False{} : Bool}, hs: {P.member(~K, ~eq, IG(~K, ~eq, t, g, changed, acc), d) == True{} : Bool}
) -> {P.member(~K, ~eq, acc, d) == True{} : Bool}:
  match t:
    case Nil{}:
      hs
    case Con{+z, +r}:
      inv_notin.if(~K, ~eq, eq(d, z), z, r, g, changed, acc, d, {==}, hn,
        h => inv_notin(~K, ~eq, r, g, changed, Acc(~K, ~eq, g, changed, acc, z), d, h, hs))

def any_in_intro.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +w: K, +t: List<&2, K>, +acc: List<&2, K>, +d: K,
  +hb: {eq(d, w) == b : Bool}, hm: {P.member(~K, ~eq, w <> t, d) == True{} : Bool}, ha: {P.member(~K, ~eq, acc, d) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, d) == True{} : Bool} -> {P.any_in(~K, ~eq, t, acc) == True{} : Bool}
) -> {P.any_in(~K, ~eq, w <> t, acc) == True{} : Bool}:
  match b:
    case True{}:
      or_true_l(P.member(~K, ~eq, acc, w), P.any_in(~K, ~eq, t, acc), mem_move(~K, ~eq, acc, d, w, sound(d, w, hb), ha))
    case False{}:
      or_true_r(P.member(~K, ~eq, acc, w), P.any_in(~K, ~eq, t, acc), ih(mem_tail(~K, ~eq, w, t, d, hb, hm)))

def any_in_intro(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ds: List<&2, K>, +acc: List<&2, K>, +d: K,
  hm: {P.member(~K, ~eq, ds, d) == True{} : Bool}, ha: {P.member(~K, ~eq, acc, d) == True{} : Bool}
) -> {P.any_in(~K, ~eq, ds, acc) == True{} : Bool}:
  match ds:
    case Nil{}:
      Empty.absurd({False{} == True{} : Bool}, false_ne_true(hm))
    case Con{+w, +t}:
      +ha = ha
      any_in_intro.if(~K, ~eq, ~sound, eq(d, w), w, t, acc, d, {==}, hm, ha, h => any_in_intro(~K, ~eq, ~sound, t, acc, d, h, ha))

def deps_move(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +x: K, +y: K, -ds: List<&2, K>, e: {x == y : K},
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
) -> {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>}:
  Equal.trans(Maybe<&2, List<&2, K>>, P.deps(~K, ~eq, g, y), P.deps(~K, ~eq, g, x), Some{ds},
    Equal.cong(K, Maybe<&2, List<&2, K>>, z => P.deps(~K, ~eq, g, z), y, x, Equal.sym(K, x, y, e)), hd)

def or_nil_some(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +y: K, +ds: List<&2, K>,
  hd: {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>}
) -> {P.deps.or_nil(~K, ~eq, g, y) == ds : List<&2, K>}:
  Equal.cong(Maybe<&2, List<&2, K>>, List<&2, K>, m => Maybe.default(&2, List<&2, K>, m, Nil{}), P.deps(~K, ~eq, g, y), Some{ds}, hd)

def dep_go.hit(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), cv: Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>,
  +acc: List<&2, K>, +x: K, +ds: List<&2, K>, +d: K,
  +hcv: {Hit(~K, ~eq, g, changed, acc, y) == cv : Bool}, hb: {eq(x, y) == True{} : Bool},
  hdy: {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>}, hm: {P.member(~K, ~eq, ds, d) == True{} : Bool},
  had: {P.member(~K, ~eq, Acc(~K, ~eq, g, changed, acc, y), d) == True{} : Bool}
) -> {P.member(~K, ~eq, IG(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y)), x) == True{} : Bool}:
  match cv:
    case True{}:
      inv_mono(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y), x,
        inv_if_hit(~K, ~eq, Hit(~K, ~eq, g, changed, acc, y), y, acc, x, hcv, hb))
    case False{}:
      +dn = P.deps.or_nil(~K, ~eq, g, y)
      Empty.absurd({P.member(~K, ~eq, IG(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y)), x) == True{} : Bool},
        clash(P.any_in(~K, ~eq, dn, acc),
          (%Equal.sym(List<&2, K>, P.deps.or_nil(~K, ~eq, g, y), ds, or_nil_some(~K, ~eq, g, y, ds, hdy)) : {P.any_in(~K, ~eq, _, acc) == True{} : Bool}
           any_in_intro(~K, ~eq, ~sound, ds, acc, d, hm, inv_if_false(~K, ~eq, Hit(~K, ~eq, g, changed, acc, y), y, acc, d, hcv, had))),
          or_false_r(P.member(~K, ~eq, changed, y), P.any_in(~K, ~eq, dn, acc), hcv)))

def dep_go.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>,
  +done: List<&2, K>, +acc: List<&2, K>, +x: K, +ds: List<&2, K>, +d: K,
  +hb: {eq(x, y) == b : Bool}, hO: {P.ordered(~K, ~eq, y <> t, g, done) == True{} : Bool}, hx: {P.member(~K, ~eq, y <> t, x) == True{} : Bool},
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, hm: {P.member(~K, ~eq, ds, d) == True{} : Bool},
  hs: {P.member(~K, ~eq, IG(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y)), d) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {P.member(~K, ~eq, IG(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y)), x) == True{} : Bool}
) -> {P.member(~K, ~eq, IG(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y)), x) == True{} : Bool}:
  match b:
    case True{}:
      +hO = hO
      +hm = hm
      +hdy = deps_move(~K, ~eq, g, x, y, ds, sound(x, y, hb), hd)
      +hdone = all_in_mem(~K, ~eq, ~sound, ds, done, d, node_all(~K, ~eq, g, y, ds, done, hdy, ord_node(~K, ~eq, y, t, g, done, hO)), hm)
      +hnt = ord_notin(~K, ~eq, ~sound, t, g, y <> done, d, ord_rest(~K, ~eq, y, t, g, done, hO), mem_cons_r(~K, ~eq, y, done, d, hdone))
      dep_go.hit(~K, ~eq, ~sound, Hit(~K, ~eq, g, changed, acc, y), y, t, g, changed, acc, x, ds, d, {==}, hb, hdy, hm,
        inv_notin(~K, ~eq, t, g, changed, Acc(~K, ~eq, g, changed, acc, y), d, hnt, hs))
    case False{}:
      ih(mem_tail(~K, ~eq, y, t, x, hb, hx))

# In an ordered p, a node that requires a stale node is stale.
def dep_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>,
  +done: List<&2, K>, +acc: List<&2, K>, +x: K, +ds: List<&2, K>, +d: K,
  hO: {P.ordered(~K, ~eq, p, g, done) == True{} : Bool}, hx: {P.member(~K, ~eq, p, x) == True{} : Bool},
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, hm: {P.member(~K, ~eq, ds, d) == True{} : Bool},
  hs: {P.member(~K, ~eq, IG(~K, ~eq, p, g, changed, acc), d) == True{} : Bool}
) -> {P.member(~K, ~eq, IG(~K, ~eq, p, g, changed, acc), x) == True{} : Bool}:
  match p:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, acc, x) == True{} : Bool}, false_ne_true(hx))
    case Con{+y, +t}:
      +hO = hO
      +hd = hd
      +hm = hm
      +hs = hs
      dep_go.if(~K, ~eq, ~sound, eq(x, y), y, t, g, changed, done, acc, x, ds, d, {==}, hO, hx, hd, hm, hs,
        h => dep_go(~K, ~eq, ~sound, t, g, changed, y <> done, Acc(~K, ~eq, g, changed, acc, y), x, ds, d,
          ord_rest(~K, ~eq, y, t, g, done, hO), h, hd, hm, hs))

def Laws.stale_dependents(K, eq, sound, g, ts, p, changed, x, ds, d, h, hx, hd, hm, hs):
  +g = g
  +ts = ts
  +p = p
  dep_go(~K, ~eq, ~sound, p, g, changed, Nil{}, Nil{}, x, ds, d, plan_ordered(~K, ~eq, g, ts, p, h), hx, hd, hm, hs)

def any_in_mono.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +w: K, +t: List<&2, K>, +a: List<&2, K>, +s: List<&2, K>,
  hb: {P.member(~K, ~eq, a, w) == b : Bool}, hab: {P.all_in(~K, ~eq, a, s) == True{} : Bool},
  h: {Bool.or(b, P.any_in(~K, ~eq, t, a)) == True{} : Bool},
  ih: {P.any_in(~K, ~eq, t, a) == True{} : Bool} -> {P.any_in(~K, ~eq, t, s) == True{} : Bool}
) -> {P.any_in(~K, ~eq, w <> t, s) == True{} : Bool}:
  match b:
    case True{}:
      or_true_l(P.member(~K, ~eq, s, w), P.any_in(~K, ~eq, t, s), all_in_mem(~K, ~eq, ~sound, a, s, w, hab, hb))
    case False{}:
      or_true_r(P.member(~K, ~eq, s, w), P.any_in(~K, ~eq, t, s), ih(h))

def any_in_mono(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), xs: List<&2, K>, +a: List<&2, K>, +s: List<&2, K>,
  hab: {P.all_in(~K, ~eq, a, s) == True{} : Bool}, h: {P.any_in(~K, ~eq, xs, a) == True{} : Bool}
) -> {P.any_in(~K, ~eq, xs, s) == True{} : Bool}:
  match xs:
    case Nil{}:
      h
    case Con{+w, +t}:
      +hab = hab
      any_in_mono.if(~K, ~eq, ~sound, P.member(~K, ~eq, a, w), w, t, a, s, {==}, hab, h,
        hh => any_in_mono(~K, ~eq, ~sound, t, a, s, hab, hh))

def Up(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +s: List<&2, K>, +y: K) -> Bool:
  Bool.or(P.member(~K, ~eq, changed, y), P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), s))

# Every stale node is in a set closed under the invalidation rule on p.
def sub_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>,
  +s: List<&2, K>, hup: {Laws.upward(~K, ~eq, p, g, changed, s) == True{} : Bool}, hacc: {P.all_in(~K, ~eq, acc, s) == True{} : Bool}
) -> {P.all_in(~K, ~eq, IG(~K, ~eq, p, g, changed, acc), s) == True{} : Bool}:
  match p:
    case Nil{}:
      hacc
    case Con{+y, t}:
      +hup = hup
      +hacc = hacc
      +head = Bool.or(Bool.not(Up(~K, ~eq, g, changed, s, y)), P.member(~K, ~eq, s, y))
      sub_go(~K, ~eq, ~sound, t, g, changed, Acc(~K, ~eq, g, changed, acc, y), s,
        and_r(head, Laws.upward(~K, ~eq, t, g, changed, s), hup),
        inv_if_all(~K, ~eq, Hit(~K, ~eq, g, changed, acc, y), y, acc, s,
          hc => imp_true(Up(~K, ~eq, g, changed, s, y), P.member(~K, ~eq, s, y),
            or_mono(P.member(~K, ~eq, changed, y), P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), acc), P.any_in(~K, ~eq, P.deps.or_nil(~K, ~eq, g, y), s), hc,
              ha => any_in_mono(~K, ~eq, ~sound, P.deps.or_nil(~K, ~eq, g, y), acc, s, hacc, ha)),
            and_l(head, Laws.upward(~K, ~eq, t, g, changed, s), hup)),
          hacc))

def Laws.stale_least(K, eq, sound, p, g, changed, s, hs, x, hx):
  +p = p
  +g = g
  +changed = changed
  +s = s
  all_in_mem(~K, ~eq, ~sound, IG(~K, ~eq, p, g, changed, Nil{}), s, x, sub_go(~K, ~eq, ~sound, p, g, changed, Nil{}, s, hs, {==}), hx)

# Execution
# ---------

def St(~K: Data, ~eq: K -> K -> Bool, +st: List<&2, P.Entry<K>>, +k: K) -> Maybe<&2, P.Status>:
  P.status(~K, ~eq, st, k)

def st_hit(~K: Data, ~eq: K -> K -> Bool, +x: K, +s: P.Status, +t: List<&2, P.Entry<K>>, +k: K, e: {eq(k, x) == True{} : Bool}) ->
  {St(~K, ~eq, P.Entry{x, s} <> t, k) == Some{s} : Maybe<&2, P.Status>}:
  %Equal.sym(Bool, eq(k, x), True{}, e) : {P.when(Maybe<&2, P.Status>, u => P.status(~K, ~eq, t, k), _, Some{s}) == Some{s} : Maybe<&2, P.Status>}
  {==}

def st_miss(~K: Data, ~eq: K -> K -> Bool, +x: K, +s: P.Status, +t: List<&2, P.Entry<K>>, +k: K, e: {eq(k, x) == False{} : Bool}) ->
  {St(~K, ~eq, P.Entry{x, s} <> t, k) == St(~K, ~eq, t, k) : Maybe<&2, P.Status>}:
  %Equal.sym(Bool, eq(k, x), False{}, e) : {P.when(Maybe<&2, P.Status>, u => P.status(~K, ~eq, t, k), _, Some{s}) == P.status(~K, ~eq, t, k) : Maybe<&2, P.Status>}
  {==}

def NotFresh(s: P.Status) -> Type:
  match s:
    case P.Fresh{}:
      Empty
    case _:
      Unit

def skipped_ne_fresh(e: {P.Skipped{} == P.Fresh{} : P.Status}) -> Empty:
  %e : NotFresh(_)
  Unit{}

def outcome_ne_fresh(rs: List<&2, Bool>, e: {P.outcome(rs) == P.Fresh{} : P.Status}) -> Empty:
  match rs:
    case Nil{}:
      %e : NotFresh(_)
      Unit{}
    case Con{b, t}:
      match b:
        case True{}:
          %e : NotFresh(_)
          Unit{}
        case False{}:
          %e : NotFresh(_)
          Unit{}

def none_of(m: Maybe<&2, P.Status>, h: {Maybe.is_some(&2, P.Status, m) == False{} : Bool}) -> {m == None{} : Maybe<&2, P.Status>}:
  match m:
    case None{}:
      {==}
    case Some{s}:
      Empty.absurd({Some{s} == None{} : Maybe<&2, P.Status>}, true_ne_false(h))

# What a decision tells about the state it was made in.
def View(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, m: Maybe<&2, P.Status>) -> Type:
  match m:
    case None{}:
      {Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y)) == True{} : Bool}
    case Some{+s}:
      {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}
      & ((@ds: List<&2, K> -> {P.Status.selected(s) == True{} : Bool} -> {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>} -> {P.ready(~K, ~eq, ds, st) == True{} : Bool})
      & ({s == P.Fresh{} : P.Status} -> {P.member(~K, ~eq, stale, y) == False{} : Bool}))

def ready_move(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +st: List<&2, P.Entry<K>>, +y: K, +dy: List<&2, K>, +ds: List<&2, K>,
  hdy: {P.deps(~K, ~eq, g, y) == Some{dy} : Maybe<&2, List<&2, K>>}, hd: {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>},
  hr: {P.ready(~K, ~eq, dy, st) == True{} : Bool}
) -> {P.ready(~K, ~eq, ds, st) == True{} : Bool}:
  %some_inj(List<&2, K>, dy, ds, Equal.trans(Maybe<&2, List<&2, K>>, Some{dy}, P.deps(~K, ~eq, g, y), Some{ds},
    Equal.sym(Maybe<&2, List<&2, K>>, P.deps(~K, ~eq, g, y), Some{dy}, hdy), hd)) : {P.ready(~K, ~eq, _, st) == True{} : Bool}
  hr

def view.ready(
  ~K: Data, ~eq: K -> K -> Bool, r: Bool, sx: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  +dy: List<&2, K>, rs: List<&2, Bool>,
  +hr: {P.ready(~K, ~eq, dy, st) == r : Bool}, hsx: {P.member(~K, ~eq, stale, y) == sx : Bool},
  +hdy: {P.deps(~K, ~eq, g, y) == Some{dy} : Maybe<&2, List<&2, K>>}, +hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}
) -> View(~K, ~eq, g, stale, st, y, P.Action.status(P.decide.ready(r, sx), rs)):
  match r sx:
    case False{} _:
      (hn, (ds => hs => hd => Empty.absurd({P.ready(~K, ~eq, ds, st) == True{} : Bool}, false_ne_true(hs)),
        e => Empty.absurd({P.member(~K, ~eq, stale, y) == False{} : Bool}, skipped_ne_fresh(e))))
    case True{} True{}:
      (hn, (ds => hs => hd => ready_move(~K, ~eq, g, st, y, dy, ds, hdy, hd, hr),
        e => Empty.absurd({P.member(~K, ~eq, stale, y) == False{} : Bool}, outcome_ne_fresh(rs, e))))
    case True{} False{}:
      (hn, (ds => hs => hd => ready_move(~K, ~eq, g, st, y, dy, ds, hdy, hd, hr), e => hsx))

def view.node(
  ~K: Data, ~eq: K -> K -> Bool, mn: Maybe<&2, List<&2, K>>, +sx: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  rs: List<&2, Bool>,
  hmn: {P.deps(~K, ~eq, g, y) == mn : Maybe<&2, List<&2, K>>}, hsx: {P.member(~K, ~eq, stale, y) == sx : Bool},
  +hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}
) -> View(~K, ~eq, g, stale, st, y, P.Action.status(P.decide.node(~K, ~eq, mn, sx, st), rs)):
  match mn:
    case None{}:
      (hn, (ds => hs => hd => Empty.absurd({P.ready(~K, ~eq, ds, st) == True{} : Bool}, false_ne_true(hs)),
        e => Empty.absurd({P.member(~K, ~eq, stale, y) == False{} : Bool}, skipped_ne_fresh(e))))
    case Some{+dy}:
      view.ready(~K, ~eq, P.ready(~K, ~eq, dy, st), sx, g, stale, st, y, dy, rs, {==}, hsx, hmn, hn)

def view.seen(
  ~K: Data, ~eq: K -> K -> Bool, b: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, rs: List<&2, Bool>,
  hb: {Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y)) == b : Bool}
) -> View(~K, ~eq, g, stale, st, y, P.Action.status(P.decide.seen(~K, ~eq, b, g, stale, st, y), rs)):
  match b:
    case True{}:
      hb
    case False{}:
      view.node(~K, ~eq, P.deps(~K, ~eq, g, y), P.member(~K, ~eq, stale, y), g, stale, st, y, rs, {==}, {==},
        none_of(St(~K, ~eq, st, y), hb))

def view(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, rs: List<&2, Bool>) ->
  View(~K, ~eq, g, stale, st, y, P.Action.status(P.decide(~K, ~eq, g, stale, st, y), rs)):
  view.seen(~K, ~eq, Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y)), g, stale, st, y, rs, {==})

def ok_keep.m(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +y: K, +s: P.Status, +st: List<&2, P.Entry<K>>, +d: K,
  hc: {eq(d, y) == c : Bool}, h: {P.ok.at(St(~K, ~eq, st, d)) == True{} : Bool}, hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}
) -> {P.ok.at(St(~K, ~eq, P.Entry{y, s} <> st, d)) == True{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.ok.at(St(~K, ~eq, P.Entry{y, s} <> st, d)) == True{} : Bool},
        false_ne_true(
          (%hn : {P.ok.at(_) == True{} : Bool}
           (%sound(d, y, hc) : {P.ok.at(St(~K, ~eq, st, _)) == True{} : Bool}
            h))))
    case False{}:
      %Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, d), St(~K, ~eq, st, d), st_miss(~K, ~eq, y, s, st, d, hc)) :
        {P.ok.at(_) == True{} : Bool}
      h

def ready_keep(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ds: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status,
  hr: {P.ready(~K, ~eq, ds, st) == True{} : Bool}, +hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}
) -> {P.ready(~K, ~eq, ds, P.Entry{y, s} <> st) == True{} : Bool}:
  match ds:
    case Nil{}:
      {==}
    case Con{+d, +t}:
      +hr = hr
      and_true(P.ok.at(St(~K, ~eq, P.Entry{y, s} <> st, d)), P.ready(~K, ~eq, t, P.Entry{y, s} <> st),
        ok_keep.m(~K, ~eq, ~sound, eq(d, y), y, s, st, d, {==}, and_l(P.ok.at(St(~K, ~eq, st, d)), P.ready(~K, ~eq, t, st), hr), hn),
        ready_keep(~K, ~eq, ~sound, t, st, y, s, and_r(P.ok.at(St(~K, ~eq, st, d)), P.ready(~K, ~eq, t, st), hr), hn))

def Inv.ready(~K: Data, ~eq: K -> K -> Bool, +st: List<&2, P.Entry<K>>, +x: K, +ds: List<&2, K>) -> Type:
  {P.selected.at(St(~K, ~eq, st, x)) == True{} : Bool} -> {P.ready(~K, ~eq, ds, st) == True{} : Bool}

def ready_step.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +g: List<&2, P.Node<K>>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status,
  +x: K, +ds: List<&2, K>,
  +hc: {eq(x, y) == c : Bool}, hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>},
  +hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>},
  hrd: @ds: List<&2, K> -> {P.Status.selected(s) == True{} : Bool} -> {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>} -> {P.ready(~K, ~eq, ds, st) == True{} : Bool},
  inv: Inv.ready(~K, ~eq, st, x, ds),
  hsel: {P.selected.at(St(~K, ~eq, P.Entry{y, s} <> st, x)) == True{} : Bool}
) -> {P.ready(~K, ~eq, ds, P.Entry{y, s} <> st) == True{} : Bool}:
  match c:
    case True{}:
      ready_keep(~K, ~eq, ~sound, ds, st, y, s,
        hrd(ds,
          (%st_hit(~K, ~eq, y, s, st, x, hc) : {P.selected.at(_) == True{} : Bool}
           hsel),
          deps_move(~K, ~eq, g, x, y, ds, sound(x, y, hc), hd)),
        hn)
    case False{}:
      ready_keep(~K, ~eq, ~sound, ds, st, y, s,
        inv(%st_miss(~K, ~eq, y, s, st, x, hc) : {P.selected.at(_) == True{} : Bool}
          hsel),
        hn)

def ready_step(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), m: Maybe<&2, P.Status>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +y: K, +x: K, +ds: List<&2, K>,
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, hv: View(~K, ~eq, g, stale, st, y, m), inv: Inv.ready(~K, ~eq, st, x, ds)
) -> Inv.ready(~K, ~eq, P.record(K, m, st, y), x, ds):
  match m:
    case None{}:
      inv
    case Some{+s}:
      (hn, rest) = hv
      (hrd, hfr) = rest
      hsel => ready_step.if(~K, ~eq, ~sound, eq(x, y), g, st, y, s, x, ds, {==}, hd, hn, hrd, inv, hsel)

def ready_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +rs: List<&2, Bool>, +x: K, +ds: List<&2, K>,
  +hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, inv: Inv.ready(~K, ~eq, st, x, ds)
) -> Inv.ready(~K, ~eq, P.exec(~K, ~eq, p, g, stale, st, rs), x, ds):
  match p:
    case Nil{}:
      inv
    case Con{+y, t}:
      +a = P.decide(~K, ~eq, g, stale, st, y)
      ready_go(~K, ~eq, ~sound, t, g, stale, P.step(K, a, st, y, rs), P.step.rest(a, rs), x, ds, hd,
        ready_step(~K, ~eq, ~sound, P.Action.status(a, rs), g, stale, st, y, x, ds, hd, view(~K, ~eq, g, stale, st, y, rs), inv))

def Laws.exec_ready(K, eq, sound, p, g, stale, rs, x, ds, hx, hd):
  ready_go(~K, ~eq, ~sound, p, g, stale, Nil{}, rs, x, ds, hd,
    h => Empty.absurd({P.ready(~K, ~eq, ds, Nil{}) == True{} : Bool}, false_ne_true(h)))(hx)

def ok_sel(m: Maybe<&2, P.Status>, h: {P.ok.at(m) == True{} : Bool}) -> {P.selected.at(m) == True{} : Bool}:
  match m:
    case None{}:
      h
    case Some{s}:
      match s:
        case P.Built{}:
          {==}
        case P.Fresh{}:
          {==}
        case P.Failed{}:
          Empty.absurd({True{} == True{} : Bool}, false_ne_true(h))
        case P.Skipped{}:
          Empty.absurd({False{} == True{} : Bool}, false_ne_true(h))

def ready_mem.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +w: K, +t: List<&2, K>, +st: List<&2, P.Entry<K>>, +d: K,
  hc: {eq(d, w) == c : Bool}, hw: {P.ok.at(St(~K, ~eq, st, w)) == True{} : Bool}, hm: {P.member(~K, ~eq, w <> t, d) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, d) == True{} : Bool} -> {P.ok.at(St(~K, ~eq, st, d)) == True{} : Bool}
) -> {P.ok.at(St(~K, ~eq, st, d)) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(K, d, w, sound(d, w, hc)) : {P.ok.at(St(~K, ~eq, st, _)) == True{} : Bool}
      hw
    case False{}:
      ih(mem_tail(~K, ~eq, w, t, d, hc, hm))

def ready_mem(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ds: List<&2, K>, +st: List<&2, P.Entry<K>>, +d: K,
  hr: {P.ready(~K, ~eq, ds, st) == True{} : Bool}, hm: {P.member(~K, ~eq, ds, d) == True{} : Bool}
) -> {P.ok.at(St(~K, ~eq, st, d)) == True{} : Bool}:
  match ds:
    case Nil{}:
      Empty.absurd({P.ok.at(St(~K, ~eq, st, d)) == True{} : Bool}, false_ne_true(hm))
    case Con{+w, +t}:
      +hr = hr
      ready_mem.if(~K, ~eq, ~sound, eq(d, w), w, t, st, d, {==},
        and_l(P.ok.at(St(~K, ~eq, st, w)), P.ready(~K, ~eq, t, st), hr), hm,
        h => ready_mem(~K, ~eq, ~sound, t, st, d, and_r(P.ok.at(St(~K, ~eq, st, w)), P.ready(~K, ~eq, t, st), hr), h))

def blocked.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +rs: List<&2, Bool>,
  +x: K, +ds: List<&2, K>, +d: K,
  hb: {P.ok.at(St(~K, ~eq, Laws.run(~K, ~eq, p, g, stale, rs), x)) == b : Bool},
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, hm: {P.member(~K, ~eq, ds, d) == True{} : Bool},
  hf: {P.ok.at(St(~K, ~eq, Laws.run(~K, ~eq, p, g, stale, rs), d)) == False{} : Bool}
) -> {b == False{} : Bool}:
  match b:
    case True{}:
      +f = Laws.run(~K, ~eq, p, g, stale, rs)
      Empty.absurd({True{} == False{} : Bool},
        clash(P.ok.at(St(~K, ~eq, f, d)),
          ready_mem(~K, ~eq, ~sound, ds, f, d,
            Laws.exec_ready(~K, ~eq, ~sound, p, g, stale, rs, x, ds, ok_sel(St(~K, ~eq, f, x), hb), hd), hm),
          hf))
    case False{}:
      {==}

def Laws.exec_blocked(K, eq, sound, p, g, stale, rs, x, ds, d, hd, hm, hf):
  +p = p
  +g = g
  +stale = stale
  +rs = rs
  +x = x
  blocked.if(~K, ~eq, ~sound, P.ok.at(St(~K, ~eq, Laws.run(~K, ~eq, p, g, stale, rs), x)), p, g, stale, rs, x, ds, d, {==}, hd, hm, hf)

def keys_none.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +z: K, +v: P.Status, +t: List<&2, P.Entry<K>>, +y: K,
  +hc: {eq(y, z) == c : Bool}, h: {St(~K, ~eq, P.Entry{z, v} <> t, y) == None{} : Maybe<&2, P.Status>},
  ih: {St(~K, ~eq, t, y) == None{} : Maybe<&2, P.Status>} -> {P.member(~K, ~eq, P.keys(K, t), y) == False{} : Bool}
) -> {P.member(~K, ~eq, z <> P.keys(K, t), y) == False{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, z <> P.keys(K, t), y) == False{} : Bool},
        none_ne_some(P.Status, v, Equal.trans(Maybe<&2, P.Status>, None{}, St(~K, ~eq, P.Entry{z, v} <> t, y), Some{v},
          Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{z, v} <> t, y), None{}, h), st_hit(~K, ~eq, z, v, t, y, hc))))
    case False{}:
      mem_cons_false(~K, ~eq, z, P.keys(K, t), y, hc,
        ih(Equal.trans(Maybe<&2, P.Status>, St(~K, ~eq, t, y), St(~K, ~eq, P.Entry{z, v} <> t, y), None{},
          Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{z, v} <> t, y), St(~K, ~eq, t, y), st_miss(~K, ~eq, z, v, t, y, hc)), h)))

# A node with no status is not a key.
def keys_none(
  ~K: Data, ~eq: K -> K -> Bool, st: List<&2, P.Entry<K>>, +y: K, h: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}
) -> {P.member(~K, ~eq, P.keys(K, st), y) == False{} : Bool}:
  match st:
    case Nil{}:
      {==}
    case Con{P.Entry{+z, +v}, +t}:
      keys_none.if(~K, ~eq, eq(y, z), z, v, t, y, {==}, h, hn => keys_none(~K, ~eq, t, y, hn))

def once_step(
  ~K: Data, ~eq: K -> K -> Bool, m: Maybe<&2, P.Status>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  hv: View(~K, ~eq, g, stale, st, y, m), hd: {P.distinct(~K, ~eq, P.keys(K, st)) == True{} : Bool}
) -> {P.distinct(~K, ~eq, P.keys(K, P.record(K, m, st, y))) == True{} : Bool}:
  match m:
    case None{}:
      hd
    case Some{s}:
      (hn, rest) = hv
      and_not_false(P.member(~K, ~eq, P.keys(K, st), y), P.distinct(~K, ~eq, P.keys(K, st)), keys_none(~K, ~eq, st, y, hn), hd)

def once_go(
  ~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +rs: List<&2, Bool>,
  hd: {P.distinct(~K, ~eq, P.keys(K, st)) == True{} : Bool}
) -> {P.distinct(~K, ~eq, P.keys(K, P.exec(~K, ~eq, p, g, stale, st, rs))) == True{} : Bool}:
  match p:
    case Nil{}:
      hd
    case Con{+y, t}:
      +a = P.decide(~K, ~eq, g, stale, st, y)
      once_go(~K, ~eq, t, g, stale, P.step(K, a, st, y, rs), P.step.rest(a, rs),
        once_step(~K, ~eq, P.Action.status(a, rs), g, stale, st, y, view(~K, ~eq, g, stale, st, y, rs), hd))

def Laws.exec_once(K, eq, sound, p, g, stale, rs):
  once_go(~K, ~eq, p, g, stale, Nil{}, rs, {==})

def some_keep.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +y: K, +s: P.Status, +st: List<&2, P.Entry<K>>, +x: K,
  hc: {eq(x, y) == c : Bool}, h: {Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)) == True{} : Bool}
) -> {Maybe.is_some(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, x)) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, x), Some{s}, st_hit(~K, ~eq, y, s, st, x, hc)) :
        {Maybe.is_some(&2, P.Status, _) == True{} : Bool}
      {==}
    case False{}:
      %Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, x), St(~K, ~eq, st, x), st_miss(~K, ~eq, y, s, st, x, hc)) :
        {Maybe.is_some(&2, P.Status, _) == True{} : Bool}
      h

def some_step(
  ~K: Data, ~eq: K -> K -> Bool, m: Maybe<&2, P.Status>, +st: List<&2, P.Entry<K>>, +y: K, +x: K,
  h: {Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)) == True{} : Bool}
) -> {Maybe.is_some(&2, P.Status, St(~K, ~eq, P.record(K, m, st, y), x)) == True{} : Bool}:
  match m:
    case None{}:
      h
    case Some{+s}:
      some_keep.if(~K, ~eq, eq(x, y), y, s, st, x, {==}, h)

# A status, once given, stays.
def total_keep(
  ~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +rs: List<&2, Bool>, +x: K,
  h: {Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)) == True{} : Bool}
) -> {Maybe.is_some(&2, P.Status, St(~K, ~eq, P.exec(~K, ~eq, p, g, stale, st, rs), x)) == True{} : Bool}:
  match p:
    case Nil{}:
      h
    case Con{+y, t}:
      +a = P.decide(~K, ~eq, g, stale, st, y)
      total_keep(~K, ~eq, t, g, stale, P.step(K, a, st, y, rs), P.step.rest(a, rs), x, some_step(~K, ~eq, P.Action.status(a, rs), st, y, x, h))

def total_head(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), m: Maybe<&2, P.Status>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +y: K, +x: K,
  hc: {eq(x, y) == True{} : Bool}, hv: View(~K, ~eq, g, stale, st, y, m)
) -> {Maybe.is_some(&2, P.Status, St(~K, ~eq, P.record(K, m, st, y), x)) == True{} : Bool}:
  match m:
    case None{}:
      %Equal.sym(K, x, y, sound(x, y, hc)) : {Maybe.is_some(&2, P.Status, St(~K, ~eq, st, _)) == True{} : Bool}
      hv
    case Some{+s}:
      %Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, x), Some{s}, st_hit(~K, ~eq, y, s, st, x, hc)) :
        {Maybe.is_some(&2, P.Status, _) == True{} : Bool}
      {==}

def total_go.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +y: K, +t: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +rs: List<&2, Bool>, +x: K,
  hc: {eq(x, y) == c : Bool}, hx: {P.member(~K, ~eq, y <> t, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} ->
    {Maybe.is_some(&2, P.Status, St(~K, ~eq, P.exec(~K, ~eq, t, g, stale, P.step(K, P.decide(~K, ~eq, g, stale, st, y), st, y, rs), P.step.rest(P.decide(~K, ~eq, g, stale, st, y), rs)), x)) == True{} : Bool}
) -> {Maybe.is_some(&2, P.Status, St(~K, ~eq, P.exec(~K, ~eq, t, g, stale, P.step(K, P.decide(~K, ~eq, g, stale, st, y), st, y, rs), P.step.rest(P.decide(~K, ~eq, g, stale, st, y), rs)), x)) == True{} : Bool}:
  match c:
    case True{}:
      +a = P.decide(~K, ~eq, g, stale, st, y)
      total_keep(~K, ~eq, t, g, stale, P.step(K, a, st, y, rs), P.step.rest(a, rs), x,
        total_head(~K, ~eq, ~sound, P.Action.status(a, rs), g, stale, st, y, x, hc, view(~K, ~eq, g, stale, st, y, rs)))
    case False{}:
      ih(mem_tail(~K, ~eq, y, t, x, hc, hx))

def total_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +rs: List<&2, Bool>, +x: K, hx: {P.member(~K, ~eq, p, x) == True{} : Bool}
) -> {Maybe.is_some(&2, P.Status, St(~K, ~eq, P.exec(~K, ~eq, p, g, stale, st, rs), x)) == True{} : Bool}:
  match p:
    case Nil{}:
      Empty.absurd({Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)) == True{} : Bool}, false_ne_true(hx))
    case Con{+y, +t}:
      +a = P.decide(~K, ~eq, g, stale, st, y)
      total_go.if(~K, ~eq, ~sound, eq(x, y), y, t, g, stale, st, rs, x, {==}, hx,
        hm => total_go(~K, ~eq, ~sound, t, g, stale, P.step(K, a, st, y, rs), P.step.rest(a, rs), x, hm))

def Laws.exec_total(K, eq, sound, p, g, stale, rs, x, hx):
  total_go(~K, ~eq, ~sound, p, g, stale, Nil{}, rs, x, hx)

def Inv.fresh(~K: Data, ~eq: K -> K -> Bool, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +x: K) -> Type:
  {St(~K, ~eq, st, x) == Some{P.Fresh{}} : Maybe<&2, P.Status>} -> {P.member(~K, ~eq, stale, x) == False{} : Bool}

def fresh_step.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status, +x: K,
  +hc: {eq(x, y) == c : Bool},
  hfr: {s == P.Fresh{} : P.Status} -> {P.member(~K, ~eq, stale, y) == False{} : Bool},
  inv: Inv.fresh(~K, ~eq, stale, st, x),
  hf: {St(~K, ~eq, P.Entry{y, s} <> st, x) == Some{P.Fresh{}} : Maybe<&2, P.Status>}
) -> {P.member(~K, ~eq, stale, x) == False{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(K, x, y, sound(x, y, hc)) : {P.member(~K, ~eq, stale, _) == False{} : Bool}
      hfr(some_inj(P.Status, s, P.Fresh{}, Equal.trans(Maybe<&2, P.Status>, Some{s}, St(~K, ~eq, P.Entry{y, s} <> st, x), Some{P.Fresh{}},
        Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, x), Some{s}, st_hit(~K, ~eq, y, s, st, x, hc)), hf)))
    case False{}:
      inv(Equal.trans(Maybe<&2, P.Status>, St(~K, ~eq, st, x), St(~K, ~eq, P.Entry{y, s} <> st, x), Some{P.Fresh{}},
        Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, x), St(~K, ~eq, st, x), st_miss(~K, ~eq, y, s, st, x, hc)), hf))

def fresh_step(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), m: Maybe<&2, P.Status>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +y: K, +x: K,
  hv: View(~K, ~eq, g, stale, st, y, m), inv: Inv.fresh(~K, ~eq, stale, st, x)
) -> Inv.fresh(~K, ~eq, stale, P.record(K, m, st, y), x):
  match m:
    case None{}:
      inv
    case Some{+s}:
      (hn, rest) = hv
      (hrd, hfr) = rest
      hf => fresh_step.if(~K, ~eq, ~sound, eq(x, y), stale, st, y, s, x, {==}, hfr, inv, hf)

def fresh_go(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +rs: List<&2, Bool>, +x: K, inv: Inv.fresh(~K, ~eq, stale, st, x)
) -> Inv.fresh(~K, ~eq, stale, P.exec(~K, ~eq, p, g, stale, st, rs), x):
  match p:
    case Nil{}:
      inv
    case Con{+y, t}:
      +a = P.decide(~K, ~eq, g, stale, st, y)
      fresh_go(~K, ~eq, ~sound, t, g, stale, P.step(K, a, st, y, rs), P.step.rest(a, rs), x,
        fresh_step(~K, ~eq, ~sound, P.Action.status(a, rs), g, stale, st, y, x, view(~K, ~eq, g, stale, st, y, rs), inv))

def Laws.exec_fresh(K, eq, sound, p, g, stale, rs, x, hx):
  fresh_go(~K, ~eq, ~sound, p, g, stale, Nil{}, rs, x,
    h => Empty.absurd({P.member(~K, ~eq, stale, x) == False{} : Bool}, none_ne_some(P.Status, P.Fresh{}, h)))(hx)

# Completeness: list lemmas
# -------------------------

def Refl(~K: Data, ~eq: K -> K -> Bool) -> Type:
  @x: K -> {eq(x, x) == True{} : Bool}

def mem_cat_r(~K: Data, ~eq: K -> K -> Bool, a: List<&2, K>, +b: List<&2, K>, +k: K, h: {P.member(~K, ~eq, b, k) == True{} : Bool}) ->
  {P.member(~K, ~eq, P.cat(K, a, b), k) == True{} : Bool}:
  match a:
    case Nil{}:
      h
    case Con{+x, +t}:
      mem_cons_r(~K, ~eq, x, P.cat(K, t, b), k, mem_cat_r(~K, ~eq, t, b, k, h))

def mem_cat_l.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +x: K, +t: List<&2, K>, +b: List<&2, K>, +k: K,
  hc: {eq(k, x) == c : Bool}, h: {P.member(~K, ~eq, x <> t, k) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, k) == True{} : Bool} -> {P.member(~K, ~eq, P.cat(K, t, b), k) == True{} : Bool}
) -> {P.member(~K, ~eq, x <> P.cat(K, t, b), k) == True{} : Bool}:
  match c:
    case True{}:
      mem_hit(~K, ~eq, x, P.cat(K, t, b), k, hc)
    case False{}:
      mem_cons_r(~K, ~eq, x, P.cat(K, t, b), k, ih(mem_tail(~K, ~eq, x, t, k, hc, h)))

def mem_cat_l(~K: Data, ~eq: K -> K -> Bool, a: List<&2, K>, +b: List<&2, K>, +k: K, h: {P.member(~K, ~eq, a, k) == True{} : Bool}) ->
  {P.member(~K, ~eq, P.cat(K, a, b), k) == True{} : Bool}:
  match a:
    case Nil{}:
      Empty.absurd({P.member(~K, ~eq, b, k) == True{} : Bool}, false_ne_true(h))
    case Con{+x, +t}:
      mem_cat_l.if(~K, ~eq, eq(k, x), x, t, b, k, {==}, h, hm => mem_cat_l(~K, ~eq, t, b, k, hm))

def mem_false_head.if(~K: Data, ~eq: K -> K -> Bool, c: Bool, +y: K, +t: List<&2, K>, +k: K,
  hc: {eq(k, y) == c : Bool}, h: {P.member(~K, ~eq, y <> t, k) == False{} : Bool}
) -> {c == False{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, clash(P.member(~K, ~eq, y <> t, k), mem_hit(~K, ~eq, y, t, k, hc), h))
    case False{}:
      {==}

def mem_false_head(~K: Data, ~eq: K -> K -> Bool, +y: K, +t: List<&2, K>, +k: K, h: {P.member(~K, ~eq, y <> t, k) == False{} : Bool}) ->
  {eq(k, y) == False{} : Bool}:
  mem_false_head.if(~K, ~eq, eq(k, y), y, t, k, {==}, h)

def all_in_cons(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +x: K, +s: List<&2, K>, h: {P.all_in(~K, ~eq, xs, s) == True{} : Bool}) ->
  {P.all_in(~K, ~eq, xs, x <> s) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+y, +t}:
      +h = h
      and_true(P.member(~K, ~eq, x <> s, y), P.all_in(~K, ~eq, t, x <> s),
        mem_cons_r(~K, ~eq, x, s, y, and_l(P.member(~K, ~eq, s, y), P.all_in(~K, ~eq, t, s), h)),
        all_in_cons(~K, ~eq, t, x, s, and_r(P.member(~K, ~eq, s, y), P.all_in(~K, ~eq, t, s), h)))

def all_in_self(~K: Data, ~eq: K -> K -> Bool, ~refl: Refl(~K, ~eq), xs: List<&2, K>) -> {P.all_in(~K, ~eq, xs, xs) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      and_true(P.member(~K, ~eq, x <> t, x), P.all_in(~K, ~eq, t, x <> t),
        mem_hit(~K, ~eq, x, t, x, refl(x)), all_in_cons(~K, ~eq, t, x, t, all_in_self(~K, ~eq, ~refl, t)))

def all_in_trans(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), xs: List<&2, K>, +a: List<&2, K>, +b: List<&2, K>,
  h1: {P.all_in(~K, ~eq, xs, a) == True{} : Bool}, +h2: {P.all_in(~K, ~eq, a, b) == True{} : Bool}
) -> {P.all_in(~K, ~eq, xs, b) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      +h1 = h1
      and_true(P.member(~K, ~eq, b, x), P.all_in(~K, ~eq, t, b),
        all_in_mem(~K, ~eq, ~sound, a, b, x, h2, and_l(P.member(~K, ~eq, a, x), P.all_in(~K, ~eq, t, a), h1)),
        all_in_trans(~K, ~eq, ~sound, t, a, b, and_r(P.member(~K, ~eq, a, x), P.all_in(~K, ~eq, t, a), h1), h2))

def all_in_cat_l(~K: Data, ~eq: K -> K -> Bool, ~refl: Refl(~K, ~eq), a: List<&2, K>, +b: List<&2, K>) ->
  {P.all_in(~K, ~eq, a, P.cat(K, a, b)) == True{} : Bool}:
  match a:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      and_true(P.member(~K, ~eq, x <> P.cat(K, t, b), x), P.all_in(~K, ~eq, t, x <> P.cat(K, t, b)),
        mem_hit(~K, ~eq, x, P.cat(K, t, b), x, refl(x)), all_in_cons(~K, ~eq, t, x, P.cat(K, t, b), all_in_cat_l(~K, ~eq, ~refl, t, b)))

def all_in_cat_r(~K: Data, ~eq: K -> K -> Bool, ~refl: Refl(~K, ~eq), a: List<&2, K>, +b: List<&2, K>) ->
  {P.all_in(~K, ~eq, b, P.cat(K, a, b)) == True{} : Bool}:
  match a:
    case Nil{}:
      all_in_self(~K, ~eq, ~refl, b)
    case Con{+x, +t}:
      all_in_cons(~K, ~eq, b, x, P.cat(K, t, b), all_in_cat_r(~K, ~eq, ~refl, t, b))

def cat_nil(-K: Data, xs: List<&2, K>) -> {P.cat(K, xs, Nil{}) == xs : List<&2, K>}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      Equal.cong(List<&2, K>, List<&2, K>, l => x <> l, P.cat(K, t, Nil{}), t, cat_nil(K, t))

def cat_assoc(-K: Data, a: List<&2, K>, +b: List<&2, K>, +c: List<&2, K>) ->
  {P.cat(K, P.cat(K, a, b), c) == P.cat(K, a, P.cat(K, b, c)) : List<&2, K>}:
  match a:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      Equal.cong(List<&2, K>, List<&2, K>, l => x <> l, P.cat(K, P.cat(K, t, b), c), P.cat(K, t, P.cat(K, b, c)), cat_assoc(K, t, b, c))

def rev_cat(-K: Data, xs: List<&2, K>, +acc: List<&2, K>) -> {P.rev(K, xs, acc) == P.cat(K, P.rev(K, xs, Nil{}), acc) : List<&2, K>}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      +r = P.rev(K, t, Nil{})
      Equal.trans(List<&2, K>, P.rev(K, t, x <> acc), P.cat(K, r, x <> acc), P.cat(K, P.rev(K, t, [x]), acc),
        rev_cat(K, t, x <> acc),
        Equal.trans(List<&2, K>, P.cat(K, r, x <> acc), P.cat(K, P.cat(K, r, [x]), acc), P.cat(K, P.rev(K, t, [x]), acc),
          Equal.sym(List<&2, K>, P.cat(K, P.cat(K, r, [x]), acc), P.cat(K, r, x <> acc), cat_assoc(K, r, [x], acc)),
          Equal.sym(List<&2, K>, P.cat(K, P.rev(K, t, [x]), acc), P.cat(K, P.cat(K, r, [x]), acc),
            Equal.cong(List<&2, K>, List<&2, K>, l => P.cat(K, l, acc), P.rev(K, t, [x]), P.cat(K, r, [x]), rev_cat(K, t, [x])))))

def rev_rev(-K: Data, xs: List<&2, K>, +acc: List<&2, K>) -> {P.rev(K, P.rev(K, xs, acc), Nil{}) == P.rev(K, acc, xs) : List<&2, K>}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      rev_rev(K, t, x <> acc)

def eq_sym_false.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +x: K, +y: K,
  hc: {eq(y, x) == c : Bool}, h: {eq(x, y) == False{} : Bool}
) -> {c == False{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, clash(eq(x, x), refl(x), (%sound(y, x, hc) : {eq(x, _) == False{} : Bool} h)))
    case False{}:
      {==}

def eq_sym_false(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +x: K, +y: K, h: {eq(x, y) == False{} : Bool}) ->
  {eq(y, x) == False{} : Bool}:
  eq_sym_false.if(~K, ~eq, ~sound, ~refl, eq(y, x), x, y, {==}, h)

# Completeness: needed
# --------------------

def needed_mono(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), r: List<&2, K>, +g: List<&2, P.Node<K>>,
  +w: List<&2, K>, +v: List<&2, K>,
  h: {P.needed(~K, ~eq, r, g, w) == True{} : Bool}, +hs: {P.all_in(~K, ~eq, w, v) == True{} : Bool}
) -> {P.needed(~K, ~eq, r, g, v) == True{} : Bool}:
  match r:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      +h = h
      +a = P.deps.or_nil(~K, ~eq, g, x)
      and_true(P.member(~K, ~eq, v, x), P.needed(~K, ~eq, t, g, P.cat(K, a, v)),
        all_in_mem(~K, ~eq, ~sound, w, v, x, hs, and_l(P.member(~K, ~eq, w, x), P.needed(~K, ~eq, t, g, P.cat(K, a, w)), h)),
        needed_mono(~K, ~eq, ~sound, ~refl, t, g, P.cat(K, a, w), P.cat(K, a, v),
          and_r(P.member(~K, ~eq, w, x), P.needed(~K, ~eq, t, g, P.cat(K, a, w)), h),
          all_in_cat(~K, ~eq, a, w, P.cat(K, a, v), all_in_cat_l(~K, ~eq, ~refl, a, v),
            all_in_trans(~K, ~eq, ~sound, w, v, P.cat(K, a, v), hs, all_in_cat_r(~K, ~eq, ~refl, a, v)))))

def needed_cat(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), a: List<&2, K>, +b: List<&2, K>, +g: List<&2, P.Node<K>>,
  +w: List<&2, K>, ha: {P.needed(~K, ~eq, a, g, w) == True{} : Bool}, hb: {P.needed(~K, ~eq, b, g, w) == True{} : Bool}
) -> {P.needed(~K, ~eq, P.cat(K, a, b), g, w) == True{} : Bool}:
  match a:
    case Nil{}:
      hb
    case Con{+x, +t}:
      +ha = ha
      +dx = P.deps.or_nil(~K, ~eq, g, x)
      and_true(P.member(~K, ~eq, w, x), P.needed(~K, ~eq, P.cat(K, t, b), g, P.cat(K, dx, w)),
        and_l(P.member(~K, ~eq, w, x), P.needed(~K, ~eq, t, g, P.cat(K, dx, w)), ha),
        needed_cat(~K, ~eq, ~sound, ~refl, t, b, g, P.cat(K, dx, w),
          and_r(P.member(~K, ~eq, w, x), P.needed(~K, ~eq, t, g, P.cat(K, dx, w)), ha),
          needed_mono(~K, ~eq, ~sound, ~refl, b, g, w, P.cat(K, dx, w), hb, all_in_cat_r(~K, ~eq, ~refl, dx, w))))

# Completeness: fuel
# ------------------

def add_zero(n: Nat) -> {Nat.add(n, 0n) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, m => 1n+m, Nat.add(p, 0n), p, add_zero(p))

def add_succ(a: Nat, +b: Nat) -> {Nat.add(a, 1n+b) == 1n+Nat.add(a, b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, m => 1n+m, Nat.add(p, 1n+b), 1n+Nat.add(p, b), add_succ(p, b))

def le_succ_self(n: Nat) -> {P.le(1n+n, n) == False{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      le_succ_self(p)

# g without its first node named x.
def rm(~K: Data, ~eq: K -> K -> Bool, g: List<&2, P.Node<K>>, +x: K) -> List<&2, P.Node<K>>:
  match g:
    case Nil{}:
      Nil{}
    case Con{P.Node{+id, +ds}, +t}:
      P.when(List<&2, P.Node<K>>, u => P.Node{id, ds} <> rm(~K, ~eq, t, x), eq(x, id), t)

def Len(-K: Data, xs: List<&2, P.Node<K>>) -> Nat:
  List.length(&2, P.Node<K>, xs)

def Def(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +x: K) -> Bool:
  Maybe.is_some(&2, List<&2, K>, P.deps(~K, ~eq, g, x))

def deps_hit(~K: Data, ~eq: K -> K -> Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +k: K, e: {eq(k, id) == True{} : Bool}) ->
  {P.deps(~K, ~eq, P.Node{id, ds} <> t, k) == Some{ds} : Maybe<&2, List<&2, K>>}:
  %Equal.sym(Bool, eq(k, id), True{}, e) : {P.when(Maybe<&2, List<&2, K>>, u => P.deps(~K, ~eq, t, k), _, Some{ds}) == Some{ds} : Maybe<&2, List<&2, K>>}
  {==}

def deps_miss(~K: Data, ~eq: K -> K -> Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +k: K, e: {eq(k, id) == False{} : Bool}) ->
  {P.deps(~K, ~eq, P.Node{id, ds} <> t, k) == P.deps(~K, ~eq, t, k) : Maybe<&2, List<&2, K>>}:
  %Equal.sym(Bool, eq(k, id), False{}, e) : {P.when(Maybe<&2, List<&2, K>>, u => P.deps(~K, ~eq, t, k), _, Some{ds}) == P.deps(~K, ~eq, t, k) : Maybe<&2, List<&2, K>>}
  {==}

def rm_hit(~K: Data, ~eq: K -> K -> Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +x: K, e: {eq(x, id) == True{} : Bool}) ->
  {rm(~K, ~eq, P.Node{id, ds} <> t, x) == t : List<&2, P.Node<K>>}:
  %Equal.sym(Bool, eq(x, id), True{}, e) : {P.when(List<&2, P.Node<K>>, u => P.Node{id, ds} <> rm(~K, ~eq, t, x), _, t) == t : List<&2, P.Node<K>>}
  {==}

def rm_miss(~K: Data, ~eq: K -> K -> Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +x: K, e: {eq(x, id) == False{} : Bool}) ->
  {rm(~K, ~eq, P.Node{id, ds} <> t, x) == P.Node{id, ds} <> rm(~K, ~eq, t, x) : List<&2, P.Node<K>>}:
  %Equal.sym(Bool, eq(x, id), False{}, e) : {P.when(List<&2, P.Node<K>>, u => P.Node{id, ds} <> rm(~K, ~eq, t, x), _, t) == P.Node{id, ds} <> rm(~K, ~eq, t, x) : List<&2, P.Node<K>>}
  {==}

def some_move(~K: Data, ~eq: K -> K -> Bool, +a: Maybe<&2, List<&2, K>>, +b: Maybe<&2, List<&2, K>>, e: {a == b : Maybe<&2, List<&2, K>>},
  h: {Maybe.is_some(&2, List<&2, K>, a) == True{} : Bool}
) -> {Maybe.is_some(&2, List<&2, K>, b) == True{} : Bool}:
  %e : {Maybe.is_some(&2, List<&2, K>, _) == True{} : Bool}
  h

def len_rm.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +x: K,
  +hc: {eq(x, id) == c : Bool}, h: {Def(~K, ~eq, P.Node{id, ds} <> t, x) == True{} : Bool},
  ih: {Def(~K, ~eq, t, x) == True{} : Bool} -> {Len(K, t) == 1n+Len(K, rm(~K, ~eq, t, x)) : Nat}
) -> {Len(K, P.Node{id, ds} <> t) == 1n+Len(K, rm(~K, ~eq, P.Node{id, ds} <> t, x)) : Nat}:
  match c:
    case True{}:
      %Equal.sym(List<&2, P.Node<K>>, rm(~K, ~eq, P.Node{id, ds} <> t, x), t, rm_hit(~K, ~eq, id, ds, t, x, hc)) : {1n+Len(K, t) == 1n+Len(K, _) : Nat}
      {==}
    case False{}:
      %Equal.sym(List<&2, P.Node<K>>, rm(~K, ~eq, P.Node{id, ds} <> t, x), P.Node{id, ds} <> rm(~K, ~eq, t, x), rm_miss(~K, ~eq, id, ds, t, x, hc)) : {1n+Len(K, t) == 1n+Len(K, _) : Nat}
      Equal.cong(Nat, Nat, m => 1n+m, Len(K, t), 1n+Len(K, rm(~K, ~eq, t, x)),
        ih(some_move(~K, ~eq, P.deps(~K, ~eq, P.Node{id, ds} <> t, x), P.deps(~K, ~eq, t, x), deps_miss(~K, ~eq, id, ds, t, x, hc), h)))

# Removing a defined node shortens g by one.
def len_rm(~K: Data, ~eq: K -> K -> Bool, g: List<&2, P.Node<K>>, +x: K, h: {Def(~K, ~eq, g, x) == True{} : Bool}) ->
  {Len(K, g) == 1n+Len(K, rm(~K, ~eq, g, x)) : Nat}:
  match g:
    case Nil{}:
      Empty.absurd({0n == 1n : Nat}, false_ne_true(h))
    case Con{P.Node{+id, +ds}, +t}:
      len_rm.if(~K, ~eq, eq(x, id), id, ds, t, x, {==}, h, hm => len_rm(~K, ~eq, t, x, hm))

def def_rm.hit(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +x: K, +y: K,
  hc: {eq(y, id) == c : Bool}, hx: {x == id : K}, hy: {Def(~K, ~eq, P.Node{id, ds} <> t, y) == True{} : Bool}, hne: {eq(y, x) == False{} : Bool}
) -> {Def(~K, ~eq, t, y) == True{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({Def(~K, ~eq, t, y) == True{} : Bool},
        clash(eq(x, x), refl(x),
          (%Equal.trans(K, y, id, x, sound(y, id, hc), Equal.sym(K, x, id, hx)) : {eq(_, x) == False{} : Bool} hne)))
    case False{}:
      some_move(~K, ~eq, P.deps(~K, ~eq, P.Node{id, ds} <> t, y), P.deps(~K, ~eq, t, y), deps_miss(~K, ~eq, id, ds, t, y, hc), hy)

def def_rm.miss(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +x: K, +y: K,
  +hc: {eq(y, id) == c : Bool}, hy: {Def(~K, ~eq, P.Node{id, ds} <> t, y) == True{} : Bool},
  ih: {Def(~K, ~eq, t, y) == True{} : Bool} -> {Def(~K, ~eq, rm(~K, ~eq, t, x), y) == True{} : Bool}
) -> {Def(~K, ~eq, P.Node{id, ds} <> rm(~K, ~eq, t, x), y) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(Maybe<&2, List<&2, K>>, P.deps(~K, ~eq, P.Node{id, ds} <> rm(~K, ~eq, t, x), y), Some{ds}, deps_hit(~K, ~eq, id, ds, rm(~K, ~eq, t, x), y, hc)) : {Maybe.is_some(&2, List<&2, K>, _) == True{} : Bool}
      {==}
    case False{}:
      %Equal.sym(Maybe<&2, List<&2, K>>, P.deps(~K, ~eq, P.Node{id, ds} <> rm(~K, ~eq, t, x), y), P.deps(~K, ~eq, rm(~K, ~eq, t, x), y), deps_miss(~K, ~eq, id, ds, rm(~K, ~eq, t, x), y, hc)) : {Maybe.is_some(&2, List<&2, K>, _) == True{} : Bool}
      ih(some_move(~K, ~eq, P.deps(~K, ~eq, P.Node{id, ds} <> t, y), P.deps(~K, ~eq, t, y), deps_miss(~K, ~eq, id, ds, t, y, hc), hy))

def def_rm.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +x: K, +y: K,
  +hc: {eq(x, id) == c : Bool}, hy: {Def(~K, ~eq, P.Node{id, ds} <> t, y) == True{} : Bool}, hne: {eq(y, x) == False{} : Bool},
  ih: {Def(~K, ~eq, t, y) == True{} : Bool} -> {Def(~K, ~eq, rm(~K, ~eq, t, x), y) == True{} : Bool}
) -> {Def(~K, ~eq, rm(~K, ~eq, P.Node{id, ds} <> t, x), y) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(List<&2, P.Node<K>>, rm(~K, ~eq, P.Node{id, ds} <> t, x), t, rm_hit(~K, ~eq, id, ds, t, x, hc)) : {Def(~K, ~eq, _, y) == True{} : Bool}
      def_rm.hit(~K, ~eq, ~sound, ~refl, eq(y, id), id, ds, t, x, y, {==}, sound(x, id, hc), hy, hne)
    case False{}:
      %Equal.sym(List<&2, P.Node<K>>, rm(~K, ~eq, P.Node{id, ds} <> t, x), P.Node{id, ds} <> rm(~K, ~eq, t, x), rm_miss(~K, ~eq, id, ds, t, x, hc)) : {Def(~K, ~eq, _, y) == True{} : Bool}
      def_rm.miss(~K, ~eq, eq(y, id), id, ds, t, x, y, {==}, hy, ih)

# A defined node other than x stays defined when x is removed.
def def_rm(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), g: List<&2, P.Node<K>>, +x: K, +y: K,
  hy: {Def(~K, ~eq, g, y) == True{} : Bool}, +hne: {eq(y, x) == False{} : Bool}
) -> {Def(~K, ~eq, rm(~K, ~eq, g, x), y) == True{} : Bool}:
  match g:
    case Nil{}:
      Empty.absurd({False{} == True{} : Bool}, false_ne_true(hy))
    case Con{P.Node{+id, +ds}, +t}:
      def_rm.if(~K, ~eq, ~sound, ~refl, eq(x, id), id, ds, t, x, y, {==}, hy, hne, hm => def_rm(~K, ~eq, ~sound, ~refl, t, x, y, hm, hne))

# Every node of xs is defined.
def defd(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +g: List<&2, P.Node<K>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+x, +t}:
      Bool.and(Def(~K, ~eq, g, x), defd(~K, ~eq, t, g))

def defd_rm(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), xs: List<&2, K>, +g: List<&2, P.Node<K>>, +x: K,
  hn: {P.member(~K, ~eq, xs, x) == False{} : Bool}, hd: {defd(~K, ~eq, xs, g) == True{} : Bool}
) -> {defd(~K, ~eq, xs, rm(~K, ~eq, g, x)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+y, +t}:
      +hn = hn
      +hd = hd
      +hxy = mem_false_head(~K, ~eq, y, t, x, hn)
      and_true(Def(~K, ~eq, rm(~K, ~eq, g, x), y), defd(~K, ~eq, t, rm(~K, ~eq, g, x)),
        def_rm(~K, ~eq, ~sound, ~refl, g, x, y, and_l(Def(~K, ~eq, g, y), defd(~K, ~eq, t, g), hd), eq_sym_false(~K, ~eq, ~sound, ~refl, x, y, hxy)),
        defd_rm(~K, ~eq, ~sound, ~refl, t, g, x, mem_tail_false(~K, ~eq, y, t, x, hxy, hn), and_r(Def(~K, ~eq, g, y), defd(~K, ~eq, t, g), hd)))

# A list of distinct defined nodes is no longer than g.
def ph(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), xs: List<&2, K>, +g: List<&2, P.Node<K>>,
  hdist: {P.distinct(~K, ~eq, xs) == True{} : Bool}, hd: {defd(~K, ~eq, xs, g) == True{} : Bool}
) -> {P.le(List.length(&2, K, xs), Len(K, g)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +r}:
      +hdist = hdist
      +hd = hd
      +hnr = not_true(P.member(~K, ~eq, r, x), and_l(Bool.not(P.member(~K, ~eq, r, x)), P.distinct(~K, ~eq, r), hdist))
      %Equal.sym(Nat, Len(K, g), 1n+Len(K, rm(~K, ~eq, g, x)), len_rm(~K, ~eq, g, x, and_l(Def(~K, ~eq, g, x), defd(~K, ~eq, r, g), hd))) :
        {P.le(1n+List.length(&2, K, r), _) == True{} : Bool}
      ph(~K, ~eq, ~sound, ~refl, r, rm(~K, ~eq, g, x),
        and_r(Bool.not(P.member(~K, ~eq, r, x)), P.distinct(~K, ~eq, r), hdist),
        defd_rm(~K, ~eq, ~sound, ~refl, r, g, x, hnr, and_r(Def(~K, ~eq, g, x), defd(~K, ~eq, r, g), hd)))

# Completeness: errors
# --------------------

# path, nearest first: each node is required by the next, and the farthest by a target.
def chain(~K: Data, ~eq: K -> K -> Bool, path: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>) -> Bool:
  match path:
    case Nil{}:
      True{}
    case Con{+p, +rest}:
      Bool.and(Laws.req(~K, ~eq, g, ts, List.head(&2, K, rest), p), chain(~K, ~eq, rest, g, ts))

# Every node of ds is required by m.
def reqs(~K: Data, ~eq: K -> K -> Bool, ds: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +m: Maybe<&2, K>) -> Bool:
  match ds:
    case Nil{}:
      True{}
    case Con{+d, t}:
      Bool.and(Laws.req(~K, ~eq, g, ts, m, d), reqs(~K, ~eq, t, g, ts, m))

def reqs_none(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>,
  h: {P.all_in(~K, ~eq, xs, ts) == True{} : Bool}
) -> {reqs(~K, ~eq, xs, g, ts, None{}) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      +h = h
      and_true(P.member(~K, ~eq, ts, x), reqs(~K, ~eq, t, g, ts, None{}),
        and_l(P.member(~K, ~eq, ts, x), P.all_in(~K, ~eq, t, ts), h),
        reqs_none(~K, ~eq, t, g, ts, and_r(P.member(~K, ~eq, ts, x), P.all_in(~K, ~eq, t, ts), h)))

def reqs_some(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K,
  h: {P.all_in(~K, ~eq, xs, P.deps.or_nil(~K, ~eq, g, d)) == True{} : Bool}
) -> {reqs(~K, ~eq, xs, g, ts, Some{d}) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      +h = h
      +a = P.deps.or_nil(~K, ~eq, g, d)
      and_true(P.member(~K, ~eq, a, x), reqs(~K, ~eq, t, g, ts, Some{d}),
        and_l(P.member(~K, ~eq, a, x), P.all_in(~K, ~eq, t, a), h),
        reqs_some(~K, ~eq, t, g, ts, d, and_r(P.member(~K, ~eq, a, x), P.all_in(~K, ~eq, t, a), h)))

def linked_rev(
  ~K: Data, ~eq: K -> K -> Bool, path: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +acc: List<&2, K>,
  hch: {chain(~K, ~eq, path, g, ts) == True{} : Bool},
  hl: {Laws.linked(~K, ~eq, acc, g, ts, List.head(&2, K, path)) == True{} : Bool}
) -> {Laws.linked(~K, ~eq, P.rev(K, path, acc), g, ts, None{}) == True{} : Bool}:
  match path:
    case Nil{}:
      hl
    case Con{+p, +rest}:
      +hch = hch
      +m = List.head(&2, K, rest)
      linked_rev(~K, ~eq, rest, g, ts, p <> acc,
        and_r(Laws.req(~K, ~eq, g, ts, m, p), chain(~K, ~eq, rest, g, ts), hch),
        and_true(Laws.req(~K, ~eq, g, ts, m, p), Laws.linked(~K, ~eq, acc, g, ts, Some{p}),
          and_l(Laws.req(~K, ~eq, g, ts, m, p), chain(~K, ~eq, rest, g, ts), hch), hl))

def missing_true(
  ~K: Data, ~eq: K -> K -> Bool, +path: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K,
  hch: {chain(~K, ~eq, path, g, ts) == True{} : Bool},
  hreq: {Laws.req(~K, ~eq, g, ts, List.head(&2, K, path), d) == True{} : Bool}
) -> {Laws.linked(~K, ~eq, P.cat(K, P.rev(K, path, Nil{}), [d]), g, ts, None{}) == True{} : Bool}:
  %rev_cat(K, path, [d]) : {Laws.linked(~K, ~eq, _, g, ts, None{}) == True{} : Bool}
  linked_rev(~K, ~eq, path, g, ts, [d], hch,
    and_true(Laws.req(~K, ~eq, g, ts, List.head(&2, K, path), d), True{}, hreq, {==}))

def cyc_hit(~K: Data, ~eq: K -> K -> Bool, +p: K, +rest: List<&2, K>, +k: K, +acc: List<&2, K>, e: {eq(k, p) == True{} : Bool}) ->
  {P.cyc(~K, ~eq, p <> rest, k, acc) == p <> acc : List<&2, K>}:
  %Equal.sym(Bool, eq(k, p), True{}, e) : {P.when(List<&2, K>, u => P.cyc(~K, ~eq, rest, k, p <> acc), _, p <> acc) == p <> acc : List<&2, K>}
  {==}

def cyc_miss(~K: Data, ~eq: K -> K -> Bool, +p: K, +rest: List<&2, K>, +k: K, +acc: List<&2, K>, e: {eq(k, p) == False{} : Bool}) ->
  {P.cyc(~K, ~eq, p <> rest, k, acc) == P.cyc(~K, ~eq, rest, k, p <> acc) : List<&2, K>}:
  %Equal.sym(Bool, eq(k, p), False{}, e) : {P.when(List<&2, K>, u => P.cyc(~K, ~eq, rest, k, p <> acc), _, p <> acc) == P.cyc(~K, ~eq, rest, k, p <> acc) : List<&2, K>}
  {==}

def Ends(~K: Data, ~eq: K -> K -> Bool, +xs: List<&2, K>, +d: K) -> Type:
  @x: K -> {Laws.ends(~K, ~eq, xs, x) == eq(d, x) : Bool}

def cyc_ok.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +p: K, +rest: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K, +a: K, +t: List<&2, K>,
  +hc: {eq(d, p) == c : Bool}, hm: {P.member(~K, ~eq, p <> rest, d) == True{} : Bool},
  hch: {chain(~K, ~eq, p <> rest, g, ts) == True{} : Bool},
  hr: {Laws.req(~K, ~eq, g, ts, Some{p}, a) == True{} : Bool},
  hl: {Laws.linked(~K, ~eq, t, g, Nil{}, Some{a}) == True{} : Bool},
  he: Ends(~K, ~eq, a <> t, d),
  ih: {P.member(~K, ~eq, rest, d) == True{} : Bool} -> {chain(~K, ~eq, rest, g, ts) == True{} : Bool} ->
    {Laws.req(~K, ~eq, g, ts, List.head(&2, K, rest), p) == True{} : Bool} ->
    {Laws.linked(~K, ~eq, a <> t, g, Nil{}, Some{p}) == True{} : Bool} -> Ends(~K, ~eq, p <> a <> t, d) ->
    {Laws.cycle_ok(~K, ~eq, P.cyc(~K, ~eq, rest, d, p <> a <> t), g) == True{} : Bool}
) -> {Laws.cycle_ok(~K, ~eq, P.cyc(~K, ~eq, p <> rest, d, a <> t), g) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(List<&2, K>, P.cyc(~K, ~eq, p <> rest, d, a <> t), p <> a <> t, cyc_hit(~K, ~eq, p, rest, d, a <> t, hc)) :
        {Laws.cycle_ok(~K, ~eq, _, g) == True{} : Bool}
      and_true(Laws.linked(~K, ~eq, a <> t, g, Nil{}, Some{p}), Laws.ends(~K, ~eq, a <> t, p),
        and_true(Laws.req(~K, ~eq, g, Nil{}, Some{p}, a), Laws.linked(~K, ~eq, t, g, Nil{}, Some{a}), hr, hl),
        Equal.trans(Bool, Laws.ends(~K, ~eq, a <> t, p), eq(d, p), True{}, he(p), hc))
    case False{}:
      +hch = hch
      %Equal.sym(List<&2, K>, P.cyc(~K, ~eq, p <> rest, d, a <> t), P.cyc(~K, ~eq, rest, d, p <> a <> t), cyc_miss(~K, ~eq, p, rest, d, a <> t, hc)) :
        {Laws.cycle_ok(~K, ~eq, _, g) == True{} : Bool}
      ih(mem_tail(~K, ~eq, p, rest, d, hc, hm),
        and_r(Laws.req(~K, ~eq, g, ts, List.head(&2, K, rest), p), chain(~K, ~eq, rest, g, ts), hch),
        and_l(Laws.req(~K, ~eq, g, ts, List.head(&2, K, rest), p), chain(~K, ~eq, rest, g, ts), hch),
        and_true(Laws.req(~K, ~eq, g, Nil{}, Some{p}, a), Laws.linked(~K, ~eq, t, g, Nil{}, Some{a}), hr, hl),
        x => he(x))

# The cycle that cyc reports: a, then t, end at d, and the path's head requires a.
def cyc_ok(
  ~K: Data, ~eq: K -> K -> Bool, path: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K, +a: K, +t: List<&2, K>,
  hm: {P.member(~K, ~eq, path, d) == True{} : Bool}, hch: {chain(~K, ~eq, path, g, ts) == True{} : Bool},
  hr: {Laws.req(~K, ~eq, g, ts, List.head(&2, K, path), a) == True{} : Bool},
  hl: {Laws.linked(~K, ~eq, t, g, Nil{}, Some{a}) == True{} : Bool}, he: Ends(~K, ~eq, a <> t, d)
) -> {Laws.cycle_ok(~K, ~eq, P.cyc(~K, ~eq, path, d, a <> t), g) == True{} : Bool}:
  match path:
    case Nil{}:
      Empty.absurd({Laws.cycle_ok(~K, ~eq, a <> t, g) == True{} : Bool}, false_ne_true(hm))
    case Con{+p, +rest}:
      cyc_ok.if(~K, ~eq, eq(d, p), p, rest, g, ts, d, a, t, {==}, hm, hch, hr, hl, he,
        h1 => h2 => h3 => h4 => h5 => cyc_ok(~K, ~eq, rest, g, ts, d, p, a <> t, h1, h2, h3, h4, h5))

def cycle_true(
  ~K: Data, ~eq: K -> K -> Bool, +path: List<&2, K>, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K,
  hm: {P.member(~K, ~eq, path, d) == True{} : Bool}, hch: {chain(~K, ~eq, path, g, ts) == True{} : Bool},
  hreq: {Laws.req(~K, ~eq, g, ts, List.head(&2, K, path), d) == True{} : Bool}
) -> {Laws.cycle_ok(~K, ~eq, P.cyc(~K, ~eq, path, d, [d]), g) == True{} : Bool}:
  cyc_ok(~K, ~eq, path, g, ts, d, d, Nil{}, hm, hch, hreq, {==}, x => {==})

# Completeness: the walk
# ----------------------

# xs, latest first: each node is new, defined, and has its prerequisites after it.
def ordr(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +g: List<&2, P.Node<K>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+x, +t}:
      Bool.and(Bool.not(P.member(~K, ~eq, t, x)), Bool.and(P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, x), t), ordr(~K, ~eq, t, g)))

def Pre(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +fuel: Nat, +ds: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>) -> Type:
  {ordr(~K, ~eq, done, g) == True{} : Bool}
  & ({disj(~K, ~eq, done, path) == True{} : Bool}
  & ({chain(~K, ~eq, path, g, ts) == True{} : Bool}
  & ({reqs(~K, ~eq, ds, g, ts, List.head(&2, K, path)) == True{} : Bool}
  & ({P.distinct(~K, ~eq, path) == True{} : Bool}
  & ({defd(~K, ~eq, path, g) == True{} : Bool}
  & {Nat.add(List.length(&2, K, path), fuel) == 1n+Len(K, g) : Nat})))))

def Seg(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ds: List<&2, K>, +done: List<&2, K>, +x: List<&2, K>) -> Type:
  &seg: List<&2, K> -> ({x == P.cat(K, seg, done) : List<&2, K>} & {P.needed(~K, ~eq, seg, g, ds) == True{} : Bool})

def Post(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ds: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>, +x: List<&2, K>) -> Type:
  {P.all_in(~K, ~eq, ds, x) == True{} : Bool}
  & ({ordr(~K, ~eq, x, g) == True{} : Bool}
  & ({disj(~K, ~eq, x, path) == True{} : Bool}
  & Seg(~K, ~eq, g, ds, done, x)))

def Bad(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, e: P.Error<K>) -> Type:
  match e:
    case P.Missing{n, c}:
      {P.deps(~K, ~eq, g, n) == None{} : Maybe<&2, List<&2, K>>} & {Laws.linked(~K, ~eq, P.cat(K, c, [n]), g, ts, None{}) == True{} : Bool}
    case P.Cycle{c}:
      {Laws.cycle_ok(~K, ~eq, c, g) == True{} : Bool}
    case P.Refused{}:
      Empty

def Good(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +ds: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>,
  r: Result<&2, &2, P.Error<K>, List<&2, K>>
) -> Type:
  match r:
    case Fail{e}:
      Bad(~K, ~eq, g, ts, e)
    case Done{x}:
      Post(~K, ~eq, g, ds, path, done, x)

def disj_cons.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>, +d: K, +path: List<&2, K>,
  +hc: {eq(z, d) == c : Bool}, hnd: {P.member(~K, ~eq, z <> t, d) == False{} : Bool},
  hz: {P.member(~K, ~eq, path, z) == False{} : Bool},
  ih: {P.member(~K, ~eq, t, d) == False{} : Bool} -> {disj(~K, ~eq, t, d <> path) == True{} : Bool}
) -> {disj(~K, ~eq, z <> t, d <> path) == True{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({disj(~K, ~eq, z <> t, d <> path) == True{} : Bool},
        clash(P.member(~K, ~eq, z <> t, d),
          mem_hit(~K, ~eq, z, t, d, (%Equal.sym(K, z, d, sound(z, d, hc)) : {eq(d, _) == True{} : Bool} refl(d))), hnd))
    case False{}:
      +hdz = eq_sym_false(~K, ~eq, ~sound, ~refl, z, d, hc)
      and_not_false(P.member(~K, ~eq, d <> path, z), disj(~K, ~eq, t, d <> path),
        mem_cons_false(~K, ~eq, d, path, z, hc, hz), ih(mem_tail_false(~K, ~eq, z, t, d, hdz, hnd)))

def disj_cons(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), done: List<&2, K>, +d: K, +path: List<&2, K>,
  hnd: {P.member(~K, ~eq, done, d) == False{} : Bool}, hdis: {disj(~K, ~eq, done, path) == True{} : Bool}
) -> {disj(~K, ~eq, done, d <> path) == True{} : Bool}:
  match done:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      +hdis = hdis
      disj_cons.if(~K, ~eq, ~sound, ~refl, eq(z, d), z, t, d, path, {==}, hnd,
        not_true(P.member(~K, ~eq, path, z), and_l(Bool.not(P.member(~K, ~eq, path, z)), disj(~K, ~eq, t, path), hdis)),
        h => disj_cons(~K, ~eq, ~sound, ~refl, t, d, path, h, and_r(Bool.not(P.member(~K, ~eq, path, z)), disj(~K, ~eq, t, path), hdis)))

def disj_drop.if(~K: Data, ~eq: K -> K -> Bool, c: Bool, +z: K, +d: K, +path: List<&2, K>,
  hc: {eq(z, d) == c : Bool}, h: {P.member(~K, ~eq, d <> path, z) == False{} : Bool}
) -> {P.member(~K, ~eq, path, z) == False{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, path, z) == False{} : Bool}, clash(P.member(~K, ~eq, d <> path, z), mem_hit(~K, ~eq, d, path, z, hc), h))
    case False{}:
      mem_tail_false(~K, ~eq, d, path, z, hc, h)

def disj_drop(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +d: K, +path: List<&2, K>,
  h: {disj(~K, ~eq, xs, d <> path) == True{} : Bool}
) -> {disj(~K, ~eq, xs, path) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      +h = h
      +c = {d <> path : List<&2, K>}
      and_not_false(P.member(~K, ~eq, path, z), disj(~K, ~eq, t, path),
        disj_drop.if(~K, ~eq, eq(z, d), z, d, path, {==}, not_true(P.member(~K, ~eq, c, z), and_l(Bool.not(P.member(~K, ~eq, c, z)), disj(~K, ~eq, t, c), h))),
        disj_drop(~K, ~eq, t, d, path, and_r(Bool.not(P.member(~K, ~eq, c, z)), disj(~K, ~eq, t, c), h)))

def not_in.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), b: Bool, +x: List<&2, K>, +c: List<&2, K>, +d: K,
  hb: {P.member(~K, ~eq, x, d) == b : Bool}, hd: {disj(~K, ~eq, x, c) == True{} : Bool}, hin: {P.member(~K, ~eq, c, d) == True{} : Bool}
) -> {b == False{} : Bool}:
  match b:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, clash(P.member(~K, ~eq, c, d), hin, disj_mem(~K, ~eq, ~sound, x, c, d, hd, hb)))
    case False{}:
      {==}

# A node of c is not in a list that misses c.
def not_in(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), +x: List<&2, K>, +c: List<&2, K>, +d: K,
  hd: {disj(~K, ~eq, x, c) == True{} : Bool}, hin: {P.member(~K, ~eq, c, d) == True{} : Bool}
) -> {P.member(~K, ~eq, x, d) == False{} : Bool}:
  not_in.if(~K, ~eq, ~sound, P.member(~K, ~eq, x, d), x, c, d, {==}, hd, hin)

def node_of(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +d: K, +dd: List<&2, K>, +x: List<&2, K>,
  hm: {P.deps(~K, ~eq, g, d) == Some{dd} : Maybe<&2, List<&2, K>>}, h: {P.all_in(~K, ~eq, dd, x) == True{} : Bool}
) -> {P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, d), x) == True{} : Bool}:
  %Equal.sym(Maybe<&2, List<&2, K>>, P.deps(~K, ~eq, g, d), Some{dd}, hm) : {P.ordered.node(~K, ~eq, _, x) == True{} : Bool}
  h

def widen_skip(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), r: Result<&2, &2, P.Error<K>, List<&2, K>>,
  +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K, +rest: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>,
  hg: Good(~K, ~eq, g, ts, rest, path, done, r), hin: {P.member(~K, ~eq, done, d) == True{} : Bool}
) -> Good(~K, ~eq, g, ts, d <> rest, path, done, r):
  match r:
    case Fail{e}:
      hg
    case Done{+y}:
      (ha, r1) = hg
      (hb, r2) = r1
      (hd, hs) = r2
      (+seg, r3) = hs
      (+hy, hn) = r3
      (and_true(P.member(~K, ~eq, y, d), P.all_in(~K, ~eq, rest, y),
         (%Equal.sym(List<&2, K>, y, P.cat(K, seg, done), hy) : {P.member(~K, ~eq, _, d) == True{} : Bool}
          mem_cat_r(~K, ~eq, seg, done, d, hin)), ha),
       (hb, (hd, (seg, (hy, needed_mono(~K, ~eq, ~sound, ~refl, seg, g, rest, d <> rest, hn, all_in_cons(~K, ~eq, rest, d, rest, all_in_self(~K, ~eq, ~refl, rest))))))))

def widen_new(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), r: Result<&2, &2, P.Error<K>, List<&2, K>>,
  +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K, +rest: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>,
  +x: List<&2, K>, +seg1: List<&2, K>, +dd: List<&2, K>,
  hg: Good(~K, ~eq, g, ts, rest, path, d <> x, r), hx: {x == P.cat(K, seg1, done) : List<&2, K>},
  hn1: {P.needed(~K, ~eq, seg1, g, dd) == True{} : Bool}, hdn: {P.deps.or_nil(~K, ~eq, g, d) == dd : List<&2, K>}
) -> Good(~K, ~eq, g, ts, d <> rest, path, done, r):
  match r:
    case Fail{e}:
      hg
    case Done{+y}:
      (ha, r1) = hg
      (hb, r2) = r1
      (hd, hs) = r2
      (+seg2, r3) = hs
      (+hy, hn2) = r3
      +seg = P.cat(K, seg2, d <> seg1)
      +a = P.deps.or_nil(~K, ~eq, g, d)
      +w = {d <> rest : List<&2, K>}
      (and_true(P.member(~K, ~eq, y, d), P.all_in(~K, ~eq, rest, y),
         (%Equal.sym(List<&2, K>, y, P.cat(K, seg2, d <> x), hy) : {P.member(~K, ~eq, _, d) == True{} : Bool}
          mem_cat_r(~K, ~eq, seg2, d <> x, d, mem_hit(~K, ~eq, d, x, d, refl(d)))), ha),
       (hb, (hd, (seg,
         (Equal.trans(List<&2, K>, y, P.cat(K, seg2, d <> x), P.cat(K, seg, done), hy,
            Equal.trans(List<&2, K>, P.cat(K, seg2, d <> x), P.cat(K, seg2, d <> P.cat(K, seg1, done)), P.cat(K, seg, done),
              Equal.cong(List<&2, K>, List<&2, K>, l => P.cat(K, seg2, d <> l), x, P.cat(K, seg1, done), hx),
              Equal.sym(List<&2, K>, P.cat(K, seg, done), P.cat(K, seg2, d <> P.cat(K, seg1, done)), cat_assoc(K, seg2, d <> seg1, done)))),
          needed_cat(~K, ~eq, ~sound, ~refl, seg2, d <> seg1, g, w,
            needed_mono(~K, ~eq, ~sound, ~refl, seg2, g, rest, w, hn2, all_in_cons(~K, ~eq, rest, d, rest, all_in_self(~K, ~eq, ~refl, rest))),
            and_true(P.member(~K, ~eq, w, d), P.needed(~K, ~eq, seg1, g, P.cat(K, a, w)), mem_hit(~K, ~eq, d, rest, d, refl(d)),
              needed_mono(~K, ~eq, ~sound, ~refl, seg1, g, dd, P.cat(K, a, w), hn1,
                (%Equal.sym(List<&2, K>, a, dd, hdn) : {P.all_in(~K, ~eq, dd, P.cat(K, _, w)) == True{} : Bool}
                 all_in_cat_l(~K, ~eq, ~refl, dd, w))))))))))

def good.then(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), rc: Result<&2, &2, P.Error<K>, List<&2, K>>,
  +f: Nat, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K, +rest: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>, +dd: List<&2, K>,
  hgc: Good(~K, ~eq, g, ts, dd, d <> path, done, rc),
  +hm: {P.deps(~K, ~eq, g, d) == Some{dd} : Maybe<&2, List<&2, K>>}, +hopen: {P.member(~K, ~eq, path, d) == False{} : Bool},
  hch: {chain(~K, ~eq, path, g, ts) == True{} : Bool},
  hreqs: {reqs(~K, ~eq, rest, g, ts, List.head(&2, K, path)) == True{} : Bool},
  hdist: {P.distinct(~K, ~eq, path) == True{} : Bool}, hdef: {defd(~K, ~eq, path, g) == True{} : Bool},
  hfuel: {Nat.add(List.length(&2, K, path), 1n+f) == 1n+Len(K, g) : Nat},
  ih: @x: List<&2, K> -> Pre(~K, ~eq, g, ts, 1n+f, rest, path, d <> x) ->
    Good(~K, ~eq, g, ts, rest, path, d <> x, P.go(~K, ~eq, 1n+f, rest, g, path, d <> x))
) -> Good(~K, ~eq, g, ts, d <> rest, path, done, P.go.then(K, rc, r => P.go(~K, ~eq, 1n+f, rest, g, path, d <> r))):
  match rc:
    case Fail{e}:
      hgc
    case Done{+x}:
      (ha, r1) = hgc
      (hb, r2) = r1
      (+hd, hs) = r2
      (+seg1, r3) = hs
      (hx, hn) = r3
      +node = P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, d), x)
      widen_new(~K, ~eq, ~sound, ~refl, P.go(~K, ~eq, 1n+f, rest, g, path, d <> x), g, ts, d, rest, path, done, x, seg1, dd,
        ih(x,
          (and_not_false(P.member(~K, ~eq, x, d), Bool.and(node, ordr(~K, ~eq, x, g)),
             not_in(~K, ~eq, ~sound, x, d <> path, d, hd, mem_hit(~K, ~eq, d, path, d, refl(d))),
             and_true(node, ordr(~K, ~eq, x, g), node_of(~K, ~eq, g, d, dd, x, hm, ha), hb)),
           (and_not_false(P.member(~K, ~eq, path, d), disj(~K, ~eq, x, path), hopen, disj_drop(~K, ~eq, x, d, path, hd)),
            (hch, (hreqs, (hdist, (hdef, hfuel))))))),
        hx, hn, or_nil_some(~K, ~eq, g, d, dd, hm))

def good.node(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), m: Maybe<&2, List<&2, K>>,
  +f: Nat, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K, +rest: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>,
  +hm: {P.deps(~K, ~eq, g, d) == m : Maybe<&2, List<&2, K>>},
  +hnd: {P.member(~K, ~eq, done, d) == False{} : Bool}, +hopen: {P.member(~K, ~eq, path, d) == False{} : Bool},
  +hord: {ordr(~K, ~eq, done, g) == True{} : Bool}, +hdis: {disj(~K, ~eq, done, path) == True{} : Bool},
  +hch: {chain(~K, ~eq, path, g, ts) == True{} : Bool},
  +hreq: {Laws.req(~K, ~eq, g, ts, List.head(&2, K, path), d) == True{} : Bool},
  +hreqs: {reqs(~K, ~eq, rest, g, ts, List.head(&2, K, path)) == True{} : Bool},
  +hdist: {P.distinct(~K, ~eq, path) == True{} : Bool}, +hdef: {defd(~K, ~eq, path, g) == True{} : Bool},
  +hfuel: {Nat.add(List.length(&2, K, path), 1n+f) == 1n+Len(K, g) : Nat},
  ihc: @dd: List<&2, K> -> Pre(~K, ~eq, g, ts, f, dd, d <> path, done) ->
    Good(~K, ~eq, g, ts, dd, d <> path, done, P.go(~K, ~eq, f, dd, g, d <> path, done)),
  ihr: @x: List<&2, K> -> Pre(~K, ~eq, g, ts, 1n+f, rest, path, d <> x) ->
    Good(~K, ~eq, g, ts, rest, path, d <> x, P.go(~K, ~eq, 1n+f, rest, g, path, d <> x))
) -> Good(~K, ~eq, g, ts, d <> rest, path, done,
    P.go.node(K, Result<&2, &2, P.Error<K>, List<&2, K>>, m,
      u => Fail{P.Missing{d, P.rev(K, path, Nil{})}},
      dd => P.go.then(K, P.go(~K, ~eq, f, dd, g, d <> path, done), r => P.go(~K, ~eq, 1n+f, rest, g, path, d <> r)))):
  match m:
    case None{}:
      (hm, missing_true(~K, ~eq, path, g, ts, d, hch, hreq))
    case Some{+dd}:
      +hsm = Equal.sym(Maybe<&2, List<&2, K>>, P.deps(~K, ~eq, g, d), Some{dd}, hm)
      good.then(~K, ~eq, ~sound, ~refl, P.go(~K, ~eq, f, dd, g, d <> path, done), f, g, ts, d, rest, path, done, dd,
        ihc(dd,
          (hord,
           (disj_cons(~K, ~eq, ~sound, ~refl, done, d, path, hnd, hdis),
            (and_true(Laws.req(~K, ~eq, g, ts, List.head(&2, K, path), d), chain(~K, ~eq, path, g, ts), hreq, hch),
             (reqs_some(~K, ~eq, dd, g, ts, d,
                (%Equal.sym(List<&2, K>, P.deps.or_nil(~K, ~eq, g, d), dd, or_nil_some(~K, ~eq, g, d, dd, hm)) : {P.all_in(~K, ~eq, dd, _) == True{} : Bool}
                 all_in_self(~K, ~eq, ~refl, dd))),
              (and_not_false(P.member(~K, ~eq, path, d), P.distinct(~K, ~eq, path), hopen, hdist),
               (and_true(Def(~K, ~eq, g, d), defd(~K, ~eq, path, g), some_move(~K, ~eq, Some{dd}, P.deps(~K, ~eq, g, d), hsm, {==}), hdef),
                Equal.trans(Nat, 1n+Nat.add(List.length(&2, K, path), f), Nat.add(List.length(&2, K, path), 1n+f), 1n+Len(K, g),
                  Equal.sym(Nat, Nat.add(List.length(&2, K, path), 1n+f), 1n+Nat.add(List.length(&2, K, path), f), add_succ(List.length(&2, K, path), f)),
                  hfuel)))))))),
        hm, hopen, hch, hreqs, hdist, hdef, hfuel, ihr)

def good.open(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), open: Bool,
  +f: Nat, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K, +rest: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>,
  +hopen: {P.member(~K, ~eq, path, d) == open : Bool},
  +hnd: {P.member(~K, ~eq, done, d) == False{} : Bool},
  +hord: {ordr(~K, ~eq, done, g) == True{} : Bool}, +hdis: {disj(~K, ~eq, done, path) == True{} : Bool},
  +hch: {chain(~K, ~eq, path, g, ts) == True{} : Bool},
  +hreq: {Laws.req(~K, ~eq, g, ts, List.head(&2, K, path), d) == True{} : Bool},
  +hreqs: {reqs(~K, ~eq, rest, g, ts, List.head(&2, K, path)) == True{} : Bool},
  +hdist: {P.distinct(~K, ~eq, path) == True{} : Bool}, +hdef: {defd(~K, ~eq, path, g) == True{} : Bool},
  +hfuel: {Nat.add(List.length(&2, K, path), 1n+f) == 1n+Len(K, g) : Nat},
  ihc: @dd: List<&2, K> -> Pre(~K, ~eq, g, ts, f, dd, d <> path, done) ->
    Good(~K, ~eq, g, ts, dd, d <> path, done, P.go(~K, ~eq, f, dd, g, d <> path, done)),
  ihr: @x: List<&2, K> -> Pre(~K, ~eq, g, ts, 1n+f, rest, path, d <> x) ->
    Good(~K, ~eq, g, ts, rest, path, d <> x, P.go(~K, ~eq, 1n+f, rest, g, path, d <> x))
) -> Good(~K, ~eq, g, ts, d <> rest, path, done,
    P.go.open(K, Result<&2, &2, P.Error<K>, List<&2, K>>, open, u => P.deps(~K, ~eq, g, d),
      u => Fail{P.cycle(~K, ~eq, path, d)},
      u => Fail{P.Missing{d, P.rev(K, path, Nil{})}},
      dd => P.go.then(K, P.go(~K, ~eq, f, dd, g, d <> path, done), r => P.go(~K, ~eq, 1n+f, rest, g, path, d <> r)))):
  match open:
    case True{}:
      cycle_true(~K, ~eq, path, g, ts, d, hopen, hch, hreq)
    case False{}:
      good.node(~K, ~eq, ~sound, ~refl, P.deps(~K, ~eq, g, d), f, g, ts, d, rest, path, done, {==}, hnd, hopen,
        hord, hdis, hch, hreq, hreqs, hdist, hdef, hfuel, ihc, ihr)

def good.at(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), seen: Bool,
  +f: Nat, +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +d: K, +rest: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>,
  +hseen: {P.member(~K, ~eq, done, d) == seen : Bool},
  +hord: {ordr(~K, ~eq, done, g) == True{} : Bool}, +hdis: {disj(~K, ~eq, done, path) == True{} : Bool},
  +hch: {chain(~K, ~eq, path, g, ts) == True{} : Bool},
  +hreq: {Laws.req(~K, ~eq, g, ts, List.head(&2, K, path), d) == True{} : Bool},
  +hreqs: {reqs(~K, ~eq, rest, g, ts, List.head(&2, K, path)) == True{} : Bool},
  +hdist: {P.distinct(~K, ~eq, path) == True{} : Bool}, +hdef: {defd(~K, ~eq, path, g) == True{} : Bool},
  +hfuel: {Nat.add(List.length(&2, K, path), 1n+f) == 1n+Len(K, g) : Nat},
  ihs: Good(~K, ~eq, g, ts, rest, path, done, P.go(~K, ~eq, 1n+f, rest, g, path, done)),
  ihc: @dd: List<&2, K> -> Pre(~K, ~eq, g, ts, f, dd, d <> path, done) ->
    Good(~K, ~eq, g, ts, dd, d <> path, done, P.go(~K, ~eq, f, dd, g, d <> path, done)),
  ihr: @x: List<&2, K> -> Pre(~K, ~eq, g, ts, 1n+f, rest, path, d <> x) ->
    Good(~K, ~eq, g, ts, rest, path, d <> x, P.go(~K, ~eq, 1n+f, rest, g, path, d <> x))
) -> Good(~K, ~eq, g, ts, d <> rest, path, done,
    P.go.at(K, Result<&2, &2, P.Error<K>, List<&2, K>>, seen, u => P.member(~K, ~eq, path, d), u => P.deps(~K, ~eq, g, d),
      u => P.go(~K, ~eq, 1n+f, rest, g, path, done),
      u => Fail{P.cycle(~K, ~eq, path, d)},
      u => Fail{P.Missing{d, P.rev(K, path, Nil{})}},
      dd => P.go.then(K, P.go(~K, ~eq, f, dd, g, d <> path, done), r => P.go(~K, ~eq, 1n+f, rest, g, path, d <> r)))):
  match seen:
    case True{}:
      widen_skip(~K, ~eq, ~sound, ~refl, P.go(~K, ~eq, 1n+f, rest, g, path, done), g, ts, d, rest, path, done, ihs, hseen)
    case False{}:
      good.open(~K, ~eq, ~sound, ~refl, P.member(~K, ~eq, path, d), f, g, ts, d, rest, path, done, {==}, hseen,
        hord, hdis, hch, hreq, hreqs, hdist, hdef, hfuel, ihc, ihr)

# The walk ends in a true error, or in a dependency order of exactly the closure of ds.
def good(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), fuel: Nat, ds: List<&2, K>,
  +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +path: List<&2, K>, +done: List<&2, K>,
  pre: Pre(~K, ~eq, g, ts, fuel, ds, path, done)
) -> Good(~K, ~eq, g, ts, ds, path, done, P.go(~K, ~eq, fuel, ds, g, path, done)):
  match fuel:
    case 0n:
      (hord, p1) = pre
      (hdis, p2) = p1
      (hch, p3) = p2
      (hreqs, p4) = p3
      (hdist, p5) = p4
      (hdef, hfuel) = p5
      +n = List.length(&2, K, path)
      Empty.absurd(Good(~K, ~eq, g, ts, ds, path, done, P.go.out(K, ds, done)),
        clash(P.le(1n+Len(K, g), Len(K, g)),
          (%Equal.trans(Nat, n, Nat.add(n, 0n), 1n+Len(K, g), Equal.sym(Nat, Nat.add(n, 0n), n, add_zero(n)), hfuel) :
             {P.le(_, Len(K, g)) == True{} : Bool}
           ph(~K, ~eq, ~sound, ~refl, path, g, hdist, hdef)),
          le_succ_self(Len(K, g))))
    case 1n+(+f):
      match ds:
        case Nil{}:
          (hord, p1) = pre
          (hdis, p2) = p1
          +hord = hord
          +hdis = hdis
          ({==}, (hord, (hdis, (Nil{}, ({==}, {==})))))
        case Con{+d, +rest}:
          (hord, p1) = pre
          (hdis, p2) = p1
          (hch, p3) = p2
          (hreqs, p4) = p3
          (hdist, p5) = p4
          (hdef, hfuel) = p5
          +hord = hord
          +hdis = hdis
          +hch = hch
          +hreqs = hreqs
          +hdist = hdist
          +hdef = hdef
          +hfuel = {hfuel : {Nat.add(List.length(&2, K, path), 1n+f) == 1n+Len(K, g) : Nat}}
          +m = List.head(&2, K, path)
          +hreq = and_l(Laws.req(~K, ~eq, g, ts, m, d), reqs(~K, ~eq, rest, g, ts, m), hreqs)
          +hrest = and_r(Laws.req(~K, ~eq, g, ts, m, d), reqs(~K, ~eq, rest, g, ts, m), hreqs)
          good.at(~K, ~eq, ~sound, ~refl, P.member(~K, ~eq, done, d), f, g, ts, d, rest, path, done, {==},
            hord, hdis, hch, hreq, hrest, hdist, hdef, hfuel,
            good(~K, ~eq, ~sound, ~refl, 1n+f, rest, g, ts, path, done, {(hord, (hdis, (hch, (hrest, (hdist, (hdef, hfuel)))))) : Pre(~K, ~eq, g, ts, 1n+f, rest, path, done)}),
            dd => pc => good(~K, ~eq, ~sound, ~refl, f, dd, g, ts, d <> path, done, pc),
            x => pr => good(~K, ~eq, ~sound, ~refl, 1n+f, rest, g, ts, path, d <> x, pr))

def plan_good(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +g: List<&2, P.Node<K>>, +ts: List<&2, K>) ->
  Good(~K, ~eq, g, ts, ts, Nil{}, Nil{}, P.go(~K, ~eq, 1n+Len(K, g), ts, g, Nil{}, Nil{})):
  good(~K, ~eq, ~sound, ~refl, 1n+Len(K, g), ts, g, ts, Nil{}, Nil{},
    ({==}, ({==}, ({==}, (reqs_none(~K, ~eq, ts, g, ts, all_in_self(~K, ~eq, ~refl, ts)), ({==}, ({==}, {==})))))))

def ord_rev(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +g: List<&2, P.Node<K>>, +acc: List<&2, K>,
  h: {ordr(~K, ~eq, xs, g) == True{} : Bool}, ho: {P.ordered(~K, ~eq, acc, g, xs) == True{} : Bool}
) -> {P.ordered(~K, ~eq, P.rev(K, xs, acc), g, Nil{}) == True{} : Bool}:
  match xs:
    case Nil{}:
      ho
    case Con{+x, +t}:
      +h = h
      +node = P.ordered.node(~K, ~eq, P.deps(~K, ~eq, g, x), t)
      +nt = Bool.not(P.member(~K, ~eq, t, x))
      ord_rev(~K, ~eq, t, g, x <> acc,
        and_r(node, ordr(~K, ~eq, t, g), and_r(nt, Bool.and(node, ordr(~K, ~eq, t, g)), h)),
        and_true(nt, Bool.and(node, P.ordered(~K, ~eq, acc, g, x <> t)),
          and_l(nt, Bool.and(node, ordr(~K, ~eq, t, g)), h),
          and_true(node, P.ordered(~K, ~eq, acc, g, x <> t), and_l(node, ordr(~K, ~eq, t, g), and_r(nt, Bool.and(node, ordr(~K, ~eq, t, g)), h)), ho)))

def all_in_rev(~K: Data, ~eq: K -> K -> Bool, ~refl: Refl(~K, ~eq), xs: List<&2, K>, +acc: List<&2, K>) ->
  {P.all_in(~K, ~eq, xs, P.rev(K, xs, acc)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      and_true(P.member(~K, ~eq, P.rev(K, t, x <> acc), x), P.all_in(~K, ~eq, t, P.rev(K, t, x <> acc)),
        rev_mem_r(~K, ~eq, t, x <> acc, x, mem_hit(~K, ~eq, x, acc, x, refl(x))), all_in_rev(~K, ~eq, ~refl, t, x <> acc))

def valid_of_post(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +x: List<&2, K>,
  post: Post(~K, ~eq, g, ts, Nil{}, Nil{}, x)
) -> {P.valid(~K, ~eq, g, ts, P.rev(K, x, Nil{})) == True{} : Bool}:
  (ha, r1) = post
  (hb, r2) = r1
  (hd, hs) = r2
  (+seg, r3) = hs
  (hx, hn) = r3
  +p = P.rev(K, x, Nil{})
  +rr = P.rev(K, p, Nil{})
  and_true(P.ordered(~K, ~eq, p, g, Nil{}), Bool.and(P.needed(~K, ~eq, rr, g, ts), P.all_in(~K, ~eq, ts, p)),
    ord_rev(~K, ~eq, x, g, Nil{}, hb, {==}),
    and_true(P.needed(~K, ~eq, rr, g, ts), P.all_in(~K, ~eq, ts, p),
      (%Equal.sym(List<&2, K>, rr, seg, Equal.trans(List<&2, K>, rr, x, seg, rev_rev(K, x, Nil{}),
          Equal.trans(List<&2, K>, x, P.cat(K, seg, Nil{}), seg, hx, cat_nil(K, seg)))) : {P.needed(~K, ~eq, _, g, ts) == True{} : Bool}
       hn),
      all_in_trans(~K, ~eq, ~sound, ts, x, p, ha, all_in_rev(~K, ~eq, ~refl, x, Nil{}))))

def err.of(-K: Data, r: Result<&2, &2, P.Error<K>, List<&2, K>>, d: P.Error<K>) -> P.Error<K>:
  match r:
    case Fail{e}:
      e
    case Done{x}:
      d

def fail_inj(-K: Data, +a: P.Error<K>, -b: P.Error<K>, h: {Fail{a} == Fail{b} : Result<&2, &2, P.Error<K>, List<&2, K>>}) -> {a == b : P.Error<K>}:
  Equal.cong(Result<&2, &2, P.Error<K>, List<&2, K>>, P.Error<K>, r => err.of(K, r, a), Fail{a}, Fail{b}, h)

def done_ne_fail(-K: Data, -x: List<&2, K>, -e: P.Error<K>, h: {Done{x} == Fail{e} : Result<&2, &2, P.Error<K>, List<&2, K>>}) -> Empty:
  %h : Bool.pick(Type, Result.is_done(&2, &2, P.Error<K>, List<&2, K>, _), Unit, Empty)
  Unit{}

# What plan.check makes of a walk that ended well: the walk's error, or Done.
def fin(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), r: Result<&2, &2, P.Error<K>, List<&2, K>>,
  +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +e: P.Error<K>,
  hg: Good(~K, ~eq, g, ts, ts, Nil{}, Nil{}, r), h: {P.plan.check(~K, ~eq, g, ts, r) == Fail{e} : Result<&2, &2, P.Error<K>, List<&2, K>>}
) -> Bad(~K, ~eq, g, ts, e):
  match r:
    case Fail{a}:
      %fail_inj(K, a, e, h) : Bad(~K, ~eq, g, ts, _)
      hg
    case Done{+x}:
      +p = P.rev(K, x, Nil{})
      Empty.absurd(Bad(~K, ~eq, g, ts, e),
        done_ne_fail(K, p, e,
          (%valid_of_post(~K, ~eq, ~sound, ~refl, g, ts, x, hg) : {P.plan.ok(K, _, p) == Fail{e} : Result<&2, &2, P.Error<K>, List<&2, K>>}
           h)))

def plan_bad(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +g: List<&2, P.Node<K>>, +ts: List<&2, K>, +e: P.Error<K>,
  h: {P.plan(~K, ~eq, g, ts) == Fail{e} : Result<&2, &2, P.Error<K>, List<&2, K>>}
) -> Bad(~K, ~eq, g, ts, e):
  fin(~K, ~eq, ~sound, ~refl, P.go(~K, ~eq, 1n+Len(K, g), ts, g, Nil{}, Nil{}), g, ts, e, plan_good(~K, ~eq, ~sound, ~refl, g, ts), h)

def pair.fst(-A: Type, -B: Type, p: A & B) -> A:
  (a, b) = p
  a

def pair.snd(-A: Type, -B: Type, p: A & B) -> B:
  (a, b) = p
  b

def Laws.plan_missing(K, eq, sound, refl, g, ts, n, c, h):
  pair.fst({P.deps(~K, ~eq, g, n) == None{} : Maybe<&2, List<&2, K>>}, {Laws.linked(~K, ~eq, P.cat(K, c, [n]), g, ts, None{}) == True{} : Bool},
    plan_bad(~K, ~eq, ~sound, ~refl, g, ts, P.Missing{n, c}, h))

def Laws.plan_missing_chain(K, eq, sound, refl, g, ts, n, c, h):
  pair.snd({P.deps(~K, ~eq, g, n) == None{} : Maybe<&2, List<&2, K>>}, {Laws.linked(~K, ~eq, P.cat(K, c, [n]), g, ts, None{}) == True{} : Bool},
    plan_bad(~K, ~eq, ~sound, ~refl, g, ts, P.Missing{n, c}, h))

def Laws.plan_cycle_path(K, eq, sound, refl, g, ts, c, h):
  plan_bad(~K, ~eq, ~sound, ~refl, g, ts, P.Cycle{c}, h)

def Laws.plan_complete(K, eq, sound, refl, g, ts, h):
  plan_bad(~K, ~eq, ~sound, ~refl, g, ts, P.Refused{}, h)

# Parallel execution: lists
# -------------------------

def or_false_l2(a: Bool, -b: Bool, h: {Bool.or(a, b) == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, true_ne_false(h))
    case False{}:
      {==}

def or_mono_l(a: Bool, -b: Bool, c: Bool, h: {Bool.or(a, b) == True{} : Bool}, f: {a == True{} : Bool} -> {c == True{} : Bool}) ->
  {Bool.or(c, b) == True{} : Bool}:
  match a:
    case True{}:
      or_true_l(c, b, f({==}))
    case False{}:
      or_true_r(c, b, h)

def or_swap(a: Bool, b: Bool, h: {Bool.or(a, b) == True{} : Bool}) -> {Bool.or(b, a) == True{} : Bool}:
  match a:
    case True{}:
      or_true_r(b, True{}, {==})
    case False{}:
      or_true_l(b, False{}, h)

def none_of2(m: Maybe<&2, P.Status>, h: {Maybe.is_none(&2, P.Status, m) == True{} : Bool}) -> {m == None{} : Maybe<&2, P.Status>}:
  match m:
    case None{}:
      {==}
    case Some{s}:
      Empty.absurd({Some{s} == None{} : Maybe<&2, P.Status>}, false_ne_true(h))

def is_none_of(m: Maybe<&2, P.Status>, h: {m == None{} : Maybe<&2, P.Status>}) -> {Maybe.is_none(&2, P.Status, m) == True{} : Bool}:
  %Equal.sym(Maybe<&2, P.Status>, m, None{}, h) : {Maybe.is_none(&2, P.Status, _) == True{} : Bool}
  {==}

def drop_hit(~K: Data, ~eq: K -> K -> Bool, +z: K, +t: List<&2, K>, +y: K, e: {eq(y, z) == True{} : Bool}) ->
  {P.drop(~K, ~eq, z <> t, y) == P.drop(~K, ~eq, t, y) : List<&2, K>}:
  %Equal.sym(Bool, eq(y, z), True{}, e) : {P.invalidate.if(K, Bool.not(_), z, P.drop(~K, ~eq, t, y)) == P.drop(~K, ~eq, t, y) : List<&2, K>}
  {==}

def drop_miss(~K: Data, ~eq: K -> K -> Bool, +z: K, +t: List<&2, K>, +y: K, e: {eq(y, z) == False{} : Bool}) ->
  {P.drop(~K, ~eq, z <> t, y) == z <> P.drop(~K, ~eq, t, y) : List<&2, K>}:
  %Equal.sym(Bool, eq(y, z), False{}, e) : {P.invalidate.if(K, Bool.not(_), z, P.drop(~K, ~eq, t, y)) == z <> P.drop(~K, ~eq, t, y) : List<&2, K>}
  {==}

def Dr(~K: Data, ~eq: K -> K -> Bool, +xs: List<&2, K>, +y: K) -> List<&2, K>:
  P.drop(~K, ~eq, xs, y)

def mem_drop_sub.miss(~K: Data, ~eq: K -> K -> Bool, c: Bool, +z: K, +t: List<&2, K>, +y: K, +x: K,
  hc: {eq(x, z) == c : Bool}, h: {P.member(~K, ~eq, z <> Dr(~K, ~eq, t, y), x) == True{} : Bool},
  ih: {P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == True{} : Bool} -> {P.member(~K, ~eq, t, x) == True{} : Bool}
) -> {P.member(~K, ~eq, z <> t, x) == True{} : Bool}:
  match c:
    case True{}:
      mem_hit(~K, ~eq, z, t, x, hc)
    case False{}:
      mem_cons_r(~K, ~eq, z, t, x, ih(mem_tail(~K, ~eq, z, Dr(~K, ~eq, t, y), x, hc, h)))

def mem_drop_sub.if(~K: Data, ~eq: K -> K -> Bool, c: Bool, +z: K, +t: List<&2, K>, +y: K, +x: K,
  +hc: {eq(y, z) == c : Bool}, h: {P.member(~K, ~eq, Dr(~K, ~eq, z <> t, y), x) == True{} : Bool},
  ih: {P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == True{} : Bool} -> {P.member(~K, ~eq, t, x) == True{} : Bool}
) -> {P.member(~K, ~eq, z <> t, x) == True{} : Bool}:
  match c:
    case True{}:
      mem_cons_r(~K, ~eq, z, t, x, ih(%drop_hit(~K, ~eq, z, t, y, hc) : {P.member(~K, ~eq, _, x) == True{} : Bool} h))
    case False{}:
      mem_drop_sub.miss(~K, ~eq, eq(x, z), z, t, y, x, {==},
        (%drop_miss(~K, ~eq, z, t, y, hc) : {P.member(~K, ~eq, _, x) == True{} : Bool} h), ih)

# A node left by drop was in the list.
def mem_drop_sub(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +y: K, +x: K, h: {P.member(~K, ~eq, Dr(~K, ~eq, xs, y), x) == True{} : Bool}) ->
  {P.member(~K, ~eq, xs, x) == True{} : Bool}:
  match xs:
    case Nil{}:
      h
    case Con{+z, +t}:
      mem_drop_sub.if(~K, ~eq, eq(y, z), z, t, y, x, {==}, h, hm => mem_drop_sub(~K, ~eq, t, y, x, hm))

def mem_drop_keep.miss(~K: Data, ~eq: K -> K -> Bool, c: Bool, +z: K, +t: List<&2, K>, +y: K, +x: K,
  hc: {eq(x, z) == c : Bool}, h: {P.member(~K, ~eq, z <> t, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == True{} : Bool}
) -> {P.member(~K, ~eq, z <> Dr(~K, ~eq, t, y), x) == True{} : Bool}:
  match c:
    case True{}:
      mem_hit(~K, ~eq, z, Dr(~K, ~eq, t, y), x, hc)
    case False{}:
      mem_cons_r(~K, ~eq, z, Dr(~K, ~eq, t, y), x, ih(mem_tail(~K, ~eq, z, t, x, hc, h)))

def mem_drop_keep.hit(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>, +y: K, +x: K,
  hc: {eq(x, z) == c : Bool}, hyz: {eq(y, z) == True{} : Bool}, hne: {eq(y, x) == False{} : Bool}, h: {P.member(~K, ~eq, z <> t, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == True{} : Bool}
) -> {P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == True{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == True{} : Bool},
        clash(eq(y, x), (%Equal.sym(K, x, z, sound(x, z, hc)) : {eq(y, _) == True{} : Bool} hyz), hne))
    case False{}:
      ih(mem_tail(~K, ~eq, z, t, x, hc, h))

def mem_drop_keep.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>, +y: K, +x: K,
  +hc: {eq(y, z) == c : Bool}, hne: {eq(y, x) == False{} : Bool}, h: {P.member(~K, ~eq, z <> t, x) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, x) == True{} : Bool} -> {P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == True{} : Bool}
) -> {P.member(~K, ~eq, Dr(~K, ~eq, z <> t, y), x) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(List<&2, K>, Dr(~K, ~eq, z <> t, y), Dr(~K, ~eq, t, y), drop_hit(~K, ~eq, z, t, y, hc)) : {P.member(~K, ~eq, _, x) == True{} : Bool}
      mem_drop_keep.hit(~K, ~eq, ~sound, eq(x, z), z, t, y, x, {==}, hc, hne, h, ih)
    case False{}:
      %Equal.sym(List<&2, K>, Dr(~K, ~eq, z <> t, y), z <> Dr(~K, ~eq, t, y), drop_miss(~K, ~eq, z, t, y, hc)) : {P.member(~K, ~eq, _, x) == True{} : Bool}
      mem_drop_keep.miss(~K, ~eq, eq(x, z), z, t, y, x, {==}, h, ih)

# drop keeps the nodes other than y.
def mem_drop_keep(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), xs: List<&2, K>, +y: K, +x: K,
  +hne: {eq(y, x) == False{} : Bool}, h: {P.member(~K, ~eq, xs, x) == True{} : Bool}
) -> {P.member(~K, ~eq, Dr(~K, ~eq, xs, y), x) == True{} : Bool}:
  match xs:
    case Nil{}:
      h
    case Con{+z, +t}:
      mem_drop_keep.if(~K, ~eq, ~sound, eq(y, z), z, t, y, x, {==}, hne, h, hm => mem_drop_keep(~K, ~eq, ~sound, t, y, x, hne, hm))

def mem_drop_self.miss(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>, +y: K, +x: K,
  +hc: {eq(x, z) == c : Bool}, hyz: {eq(y, z) == False{} : Bool}, +hxy: {eq(x, y) == True{} : Bool},
  ih: {P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == False{} : Bool}
) -> {P.member(~K, ~eq, z <> Dr(~K, ~eq, t, y), x) == False{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, z <> Dr(~K, ~eq, t, y), x) == False{} : Bool},
        clash(eq(y, z),
          (%Equal.trans(K, y, x, z, Equal.sym(K, x, y, sound(x, y, hxy)), sound(x, z, hc)) : {eq(y, _) == True{} : Bool} refl(y)), hyz))
    case False{}:
      mem_cons_false(~K, ~eq, z, Dr(~K, ~eq, t, y), x, hc, ih)

def mem_drop_self.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>, +y: K, +x: K,
  +hc: {eq(y, z) == c : Bool}, +hxy: {eq(x, y) == True{} : Bool},
  ih: {P.member(~K, ~eq, Dr(~K, ~eq, t, y), x) == False{} : Bool}
) -> {P.member(~K, ~eq, Dr(~K, ~eq, z <> t, y), x) == False{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(List<&2, K>, Dr(~K, ~eq, z <> t, y), Dr(~K, ~eq, t, y), drop_hit(~K, ~eq, z, t, y, hc)) : {P.member(~K, ~eq, _, x) == False{} : Bool}
      ih
    case False{}:
      %Equal.sym(List<&2, K>, Dr(~K, ~eq, z <> t, y), z <> Dr(~K, ~eq, t, y), drop_miss(~K, ~eq, z, t, y, hc)) : {P.member(~K, ~eq, _, x) == False{} : Bool}
      mem_drop_self.miss(~K, ~eq, ~sound, ~refl, eq(x, z), z, t, y, x, {==}, hc, hxy, ih)

# drop leaves no node eq to y.
def mem_drop_self(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), xs: List<&2, K>, +y: K, +x: K,
  +hxy: {eq(x, y) == True{} : Bool}
) -> {P.member(~K, ~eq, Dr(~K, ~eq, xs, y), x) == False{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      mem_drop_self.if(~K, ~eq, ~sound, ~refl, eq(y, z), z, t, y, x, {==}, hxy, mem_drop_self(~K, ~eq, ~sound, ~refl, t, y, x, hxy))

def le_succ_r(a: Nat, +b: Nat, h: {P.le(a, b) == True{} : Bool}) -> {P.le(a, 1n+b) == True{} : Bool}:
  match a b:
    case 0n _:
      {==}
    case 1n+p 0n:
      Empty.absurd({P.le(1n+p, 1n) == True{} : Bool}, false_ne_true(h))
    case 1n+p 1n+q:
      le_succ_r(p, q, h)

def le_trans(a: Nat, +b: Nat, +c: Nat, h1: {P.le(a, b) == True{} : Bool}, h2: {P.le(b, c) == True{} : Bool}) -> {P.le(a, c) == True{} : Bool}:
  match a b c:
    case 0n _ _:
      {==}
    case 1n+p 0n _:
      Empty.absurd({P.le(1n+p, c) == True{} : Bool}, false_ne_true(h1))
    case 1n+p 1n+q 0n:
      Empty.absurd({False{} == True{} : Bool}, false_ne_true(h2))
    case 1n+p 1n+q 1n+r:
      le_trans(p, q, r, h1, h2)

def Ln(-K: Data, xs: List<&2, K>) -> Nat:
  List.length(&2, K, xs)

def len_drop.if(~K: Data, ~eq: K -> K -> Bool, c: Bool, +z: K, +t: List<&2, K>, +y: K,
  +hc: {eq(y, z) == c : Bool}, ih: {P.le(Ln(K, Dr(~K, ~eq, t, y)), Ln(K, t)) == True{} : Bool}
) -> {P.le(Ln(K, Dr(~K, ~eq, z <> t, y)), 1n+Ln(K, t)) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(List<&2, K>, Dr(~K, ~eq, z <> t, y), Dr(~K, ~eq, t, y), drop_hit(~K, ~eq, z, t, y, hc)) : {P.le(Ln(K, _), 1n+Ln(K, t)) == True{} : Bool}
      le_succ_r(Ln(K, Dr(~K, ~eq, t, y)), Ln(K, t), ih)
    case False{}:
      %Equal.sym(List<&2, K>, Dr(~K, ~eq, z <> t, y), z <> Dr(~K, ~eq, t, y), drop_miss(~K, ~eq, z, t, y, hc)) : {P.le(Ln(K, _), 1n+Ln(K, t)) == True{} : Bool}
      ih

def len_drop(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +y: K) -> {P.le(Ln(K, Dr(~K, ~eq, xs, y)), Ln(K, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      len_drop.if(~K, ~eq, eq(y, z), z, t, y, {==}, len_drop(~K, ~eq, t, y))

def any_nil(~K: Data, ~eq: K -> K -> Bool, ds: List<&2, K>) -> {P.any_in(~K, ~eq, ds, Nil{}) == False{} : Bool}:
  match ds:
    case Nil{}:
      {==}
    case Con{+d, +t}:
      any_nil(~K, ~eq, t)

# Parallel execution: pool facts
# ------------------------------

# No running node has a status.
def none_all(~K: Data, ~eq: K -> K -> Bool, r: List<&2, K>, +st: List<&2, P.Entry<K>>) -> Bool:
  match r:
    case Nil{}:
      True{}
    case Con{+z, t}:
      Bool.and(Maybe.is_none(&2, P.Status, St(~K, ~eq, st, z)), none_all(~K, ~eq, t, st))

# Every started node runs or has a status.
def logged(~K: Data, ~eq: K -> K -> Bool, l: List<&2, K>, +r: List<&2, K>, +st: List<&2, P.Entry<K>>) -> Bool:
  match l:
    case Nil{}:
      True{}
    case Con{+z, t}:
      Bool.and(Bool.or(P.member(~K, ~eq, r, z), Maybe.is_some(&2, P.Status, St(~K, ~eq, st, z))), logged(~K, ~eq, t, r, st))

def none_mem.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  hc: {eq(y, z) == c : Bool}, hz: {Maybe.is_none(&2, P.Status, St(~K, ~eq, st, z)) == True{} : Bool}, hm: {P.member(~K, ~eq, z <> t, y) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, y) == True{} : Bool} -> {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}
) -> {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}:
  match c:
    case True{}:
      %Equal.sym(K, y, z, sound(y, z, hc)) : {St(~K, ~eq, st, _) == None{} : Maybe<&2, P.Status>}
      none_of2(St(~K, ~eq, st, z), hz)
    case False{}:
      ih(mem_tail(~K, ~eq, z, t, y, hc, hm))

# A running node has no status.
def none_mem(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  h: {none_all(~K, ~eq, r, st) == True{} : Bool}, hm: {P.member(~K, ~eq, r, y) == True{} : Bool}
) -> {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}:
  match r:
    case Nil{}:
      Empty.absurd({St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}, false_ne_true(hm))
    case Con{+z, +t}:
      +h = h
      +hz = Maybe.is_none(&2, P.Status, St(~K, ~eq, st, z))
      none_mem.if(~K, ~eq, ~sound, eq(y, z), z, t, st, y, {==}, and_l(hz, none_all(~K, ~eq, t, st), h), hm,
        hh => none_mem(~K, ~eq, ~sound, t, st, y, and_r(hz, none_all(~K, ~eq, t, st), h), hh))

def none_cons.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status,
  +hc: {eq(z, y) == c : Bool}, hm: {P.member(~K, ~eq, z <> t, y) == False{} : Bool},
  hz: {Maybe.is_none(&2, P.Status, St(~K, ~eq, st, z)) == True{} : Bool},
  ih: {P.member(~K, ~eq, t, y) == False{} : Bool} -> {none_all(~K, ~eq, t, P.Entry{y, s} <> st) == True{} : Bool}
) -> {none_all(~K, ~eq, z <> t, P.Entry{y, s} <> st) == True{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({none_all(~K, ~eq, z <> t, P.Entry{y, s} <> st) == True{} : Bool},
        clash(P.member(~K, ~eq, z <> t, y),
          mem_hit(~K, ~eq, z, t, y, (%Equal.sym(K, z, y, sound(z, y, hc)) : {eq(y, _) == True{} : Bool} refl(y))), hm))
    case False{}:
      and_true(Maybe.is_none(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, z)), none_all(~K, ~eq, t, P.Entry{y, s} <> st),
        (%Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, z), St(~K, ~eq, st, z), st_miss(~K, ~eq, y, s, st, z, hc)) : {Maybe.is_none(&2, P.Status, _) == True{} : Bool} hz),
        ih(mem_tail_false(~K, ~eq, z, t, y, eq_sym_false(~K, ~eq, ~sound, ~refl, z, y, hc), hm)))

def none_cons(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status,
  hm: {P.member(~K, ~eq, r, y) == False{} : Bool}, h: {none_all(~K, ~eq, r, st) == True{} : Bool}
) -> {none_all(~K, ~eq, r, P.Entry{y, s} <> st) == True{} : Bool}:
  match r:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      +h = h
      +hz = Maybe.is_none(&2, P.Status, St(~K, ~eq, st, z))
      none_cons.if(~K, ~eq, ~sound, ~refl, eq(z, y), z, t, st, y, s, {==}, hm, and_l(hz, none_all(~K, ~eq, t, st), h),
        hh => none_cons(~K, ~eq, ~sound, ~refl, t, st, y, s, hh, and_r(hz, none_all(~K, ~eq, t, st), h)))

def none_drop.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status,
  +hc: {eq(y, z) == c : Bool}, hz: {Maybe.is_none(&2, P.Status, St(~K, ~eq, st, z)) == True{} : Bool},
  ih: {none_all(~K, ~eq, Dr(~K, ~eq, t, y), P.Entry{y, s} <> st) == True{} : Bool}
) -> {none_all(~K, ~eq, Dr(~K, ~eq, z <> t, y), P.Entry{y, s} <> st) == True{} : Bool}:
  match c:
    case True{}:
      %Equal.sym(List<&2, K>, Dr(~K, ~eq, z <> t, y), Dr(~K, ~eq, t, y), drop_hit(~K, ~eq, z, t, y, hc)) :
        {none_all(~K, ~eq, _, P.Entry{y, s} <> st) == True{} : Bool}
      ih
    case False{}:
      %Equal.sym(List<&2, K>, Dr(~K, ~eq, z <> t, y), z <> Dr(~K, ~eq, t, y), drop_miss(~K, ~eq, z, t, y, hc)) :
        {none_all(~K, ~eq, _, P.Entry{y, s} <> st) == True{} : Bool}
      and_true(Maybe.is_none(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, z)), none_all(~K, ~eq, Dr(~K, ~eq, t, y), P.Entry{y, s} <> st),
        (%Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, z), St(~K, ~eq, st, z), st_miss(~K, ~eq, y, s, st, z, eq_sym_false(~K, ~eq, ~sound, ~refl, y, z, hc))) : {Maybe.is_none(&2, P.Status, _) == True{} : Bool} hz),
        ih)

def none_drop(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status,
  h: {none_all(~K, ~eq, r, st) == True{} : Bool}
) -> {none_all(~K, ~eq, Dr(~K, ~eq, r, y), P.Entry{y, s} <> st) == True{} : Bool}:
  match r:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      +h = h
      +hz = Maybe.is_none(&2, P.Status, St(~K, ~eq, st, z))
      none_drop.if(~K, ~eq, ~sound, ~refl, eq(y, z), z, t, st, y, s, {==}, and_l(hz, none_all(~K, ~eq, t, st), h),
        none_drop(~K, ~eq, ~sound, ~refl, t, st, y, s, and_r(hz, none_all(~K, ~eq, t, st), h)))

def Acp(~K: Data, ~eq: K -> K -> Bool, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +z: K) -> Bool:
  Bool.or(P.member(~K, ~eq, r, z), Maybe.is_some(&2, P.Status, St(~K, ~eq, st, z)))

def logged_mark(~K: Data, ~eq: K -> K -> Bool, l: List<&2, K>, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status,
  h: {logged(~K, ~eq, l, r, st) == True{} : Bool}
) -> {logged(~K, ~eq, l, r, P.Entry{y, s} <> st) == True{} : Bool}:
  match l:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      +h = h
      and_true(Acp(~K, ~eq, r, P.Entry{y, s} <> st, z), logged(~K, ~eq, t, r, P.Entry{y, s} <> st),
        or_mono(P.member(~K, ~eq, r, z), Maybe.is_some(&2, P.Status, St(~K, ~eq, st, z)), Maybe.is_some(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, z)),
          and_l(Acp(~K, ~eq, r, st, z), logged(~K, ~eq, t, r, st), h),
          f => some_keep.if(~K, ~eq, eq(z, y), y, s, st, z, {==}, f)),
        logged_mark(~K, ~eq, t, r, st, y, s, and_r(Acp(~K, ~eq, r, st, z), logged(~K, ~eq, t, r, st), h)))

def logged_cons_run(~K: Data, ~eq: K -> K -> Bool, l: List<&2, K>, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  h: {logged(~K, ~eq, l, r, st) == True{} : Bool}
) -> {logged(~K, ~eq, l, y <> r, st) == True{} : Bool}:
  match l:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      +h = h
      +so = Maybe.is_some(&2, P.Status, St(~K, ~eq, st, z))
      and_true(Acp(~K, ~eq, y <> r, st, z), logged(~K, ~eq, t, y <> r, st),
        or_mono_l(P.member(~K, ~eq, r, z), so, P.member(~K, ~eq, y <> r, z),
          and_l(Acp(~K, ~eq, r, st, z), logged(~K, ~eq, t, r, st), h),
          f => mem_cons_r(~K, ~eq, y, r, z, f)),
        logged_cons_run(~K, ~eq, t, r, st, y, and_r(Acp(~K, ~eq, r, st, z), logged(~K, ~eq, t, r, st), h)))

def logged_start(~K: Data, ~eq: K -> K -> Bool, ~refl: Refl(~K, ~eq), +l: List<&2, K>, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  h: {logged(~K, ~eq, l, r, st) == True{} : Bool}
) -> {logged(~K, ~eq, y <> l, y <> r, st) == True{} : Bool}:
  and_true(Acp(~K, ~eq, y <> r, st, y), logged(~K, ~eq, l, y <> r, st),
    or_true_l(P.member(~K, ~eq, y <> r, y), Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y)), mem_hit(~K, ~eq, y, r, y, refl(y))),
    logged_cons_run(~K, ~eq, l, r, st, y, h))

def logged_not.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +z: K, +t: List<&2, K>, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  +hc: {eq(y, z) == c : Bool}, hz: {Acp(~K, ~eq, r, st, z) == True{} : Bool},
  hr: {P.member(~K, ~eq, r, y) == False{} : Bool}, hs: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>},
  ih: {P.member(~K, ~eq, t, y) == False{} : Bool}
) -> {P.member(~K, ~eq, z <> t, y) == False{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, z <> t, y) == False{} : Bool},
        false_ne_true(
          (%hs : {Bool.or(False{}, Maybe.is_some(&2, P.Status, _)) == True{} : Bool}
           (%hr : {Bool.or(_, Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y))) == True{} : Bool}
            (%Equal.sym(K, y, z, sound(y, z, hc)) : {Acp(~K, ~eq, r, st, _) == True{} : Bool} hz)))))
    case False{}:
      mem_cons_false(~K, ~eq, z, t, y, hc, ih)

# A node that neither runs nor has a status was never started.
def logged_not(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), l: List<&2, K>, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K,
  h: {logged(~K, ~eq, l, r, st) == True{} : Bool}, +hr: {P.member(~K, ~eq, r, y) == False{} : Bool}, +hs: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}
) -> {P.member(~K, ~eq, l, y) == False{} : Bool}:
  match l:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      +h = h
      logged_not.if(~K, ~eq, ~sound, eq(y, z), z, t, r, st, y, {==}, and_l(Acp(~K, ~eq, r, st, z), logged(~K, ~eq, t, r, st), h), hr, hs,
        logged_not(~K, ~eq, ~sound, t, r, st, y, and_r(Acp(~K, ~eq, r, st, z), logged(~K, ~eq, t, r, st), h), hr, hs))

def acc_fin.miss(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), b: Bool, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status, +z: K,
  hb: {P.member(~K, ~eq, r, z) == b : Bool}, +hzy: {eq(z, y) == False{} : Bool},
  h: {Bool.or(b, Maybe.is_some(&2, P.Status, St(~K, ~eq, st, z))) == True{} : Bool}
) -> {Acp(~K, ~eq, Dr(~K, ~eq, r, y), P.Entry{y, s} <> st, z) == True{} : Bool}:
  match b:
    case True{}:
      or_true_l(P.member(~K, ~eq, Dr(~K, ~eq, r, y), z), Maybe.is_some(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, z)),
        mem_drop_keep(~K, ~eq, ~sound, r, y, z, eq_sym_false(~K, ~eq, ~sound, ~refl, z, y, hzy), hb))
    case False{}:
      or_true_r(P.member(~K, ~eq, Dr(~K, ~eq, r, y), z), Maybe.is_some(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, z)),
        some_keep.if(~K, ~eq, False{}, y, s, st, z, hzy, h))

def acc_fin.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), c: Bool, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status, +z: K,
  +hc: {eq(z, y) == c : Bool}, h: {Acp(~K, ~eq, r, st, z) == True{} : Bool}
) -> {Acp(~K, ~eq, Dr(~K, ~eq, r, y), P.Entry{y, s} <> st, z) == True{} : Bool}:
  match c:
    case True{}:
      or_true_r(P.member(~K, ~eq, Dr(~K, ~eq, r, y), z), Maybe.is_some(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, z)),
        (%Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, z), Some{s}, st_hit(~K, ~eq, y, s, st, z, hc)) :
          {Maybe.is_some(&2, P.Status, _) == True{} : Bool} {==}))
    case False{}:
      acc_fin.miss(~K, ~eq, ~sound, ~refl, P.member(~K, ~eq, r, z), r, st, y, s, z, {==}, hc, h)

# A finish keeps every node accounted for: it runs, or it has a status.
def acc_fin(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status, +z: K,
  h: {Acp(~K, ~eq, r, st, z) == True{} : Bool}
) -> {Acp(~K, ~eq, Dr(~K, ~eq, r, y), P.Entry{y, s} <> st, z) == True{} : Bool}:
  acc_fin.if(~K, ~eq, ~sound, ~refl, eq(z, y), r, st, y, s, z, {==}, h)

def logged_finish(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), l: List<&2, K>, +r: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +s: P.Status,
  h: {logged(~K, ~eq, l, r, st) == True{} : Bool}
) -> {logged(~K, ~eq, l, Dr(~K, ~eq, r, y), P.Entry{y, s} <> st) == True{} : Bool}:
  match l:
    case Nil{}:
      {==}
    case Con{+z, +t}:
      +h = h
      and_true(Acp(~K, ~eq, Dr(~K, ~eq, r, y), P.Entry{y, s} <> st, z), logged(~K, ~eq, t, Dr(~K, ~eq, r, y), P.Entry{y, s} <> st),
        acc_fin(~K, ~eq, ~sound, ~refl, r, st, y, s, z, and_l(Acp(~K, ~eq, r, st, z), logged(~K, ~eq, t, r, st), h)),
        logged_finish(~K, ~eq, ~sound, ~refl, t, r, st, y, s, and_r(Acp(~K, ~eq, r, st, z), logged(~K, ~eq, t, r, st), h)))

def fin_ne_fresh(ok: Bool, e: {P.Fin.status(ok) == P.Fresh{} : P.Status}) -> Empty:
  match ok:
    case True{}:
      %e : NotFresh(_)
      Unit{}
    case False{}:
      %e : NotFresh(_)
      Unit{}

# Parallel execution: decisions
# -----------------------------

def Sts(-K: Data, pool: P.Pool<K>) -> List<&2, P.Entry<K>>:
  Laws.statuses(K, pool)

def Run(-K: Data, pool: P.Pool<K>) -> List<&2, K>:
  Laws.running(K, pool)

def Log(-K: Data, pool: P.Pool<K>) -> List<&2, K>:
  Laws.started(K, pool)

# What a parallel decision tells about the pool it was made in.
def VP(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, +y: K, a: P.Step) -> Type:
  match a:
    case P.PSkip{}:
      {Bool.or(Maybe.is_some(&2, P.Status, St(~K, ~eq, Sts(K, pool), y)), P.member(~K, ~eq, Run(K, pool), y)) == True{} : Bool}
    case P.PWait{}:
      {P.le(1n, limit) == True{} : Bool} -> {Run(K, pool) == Nil{} : List<&2, K>} -> Empty
    case P.PMark{+s}:
      {St(~K, ~eq, Sts(K, pool), y) == None{} : Maybe<&2, P.Status>}
      & ({P.member(~K, ~eq, Run(K, pool), y) == False{} : Bool}
      & ((@dy: List<&2, K> -> {P.Status.selected(s) == True{} : Bool} -> {P.deps(~K, ~eq, g, y) == Some{dy} : Maybe<&2, List<&2, K>>} -> {P.ready(~K, ~eq, dy, Sts(K, pool)) == True{} : Bool})
      & ({s == P.Fresh{} : P.Status} -> {P.member(~K, ~eq, stale, y) == False{} : Bool})))
    case P.PStart{}:
      {St(~K, ~eq, Sts(K, pool), y) == None{} : Maybe<&2, P.Status>}
      & ({P.member(~K, ~eq, Run(K, pool), y) == False{} : Bool}
      & ((@dy: List<&2, K> -> {P.deps(~K, ~eq, g, y) == Some{dy} : Maybe<&2, List<&2, K>>} -> {P.ready(~K, ~eq, dy, Sts(K, pool)) == True{} : Bool})
      & {P.le(1n+Ln(K, Run(K, pool)), limit) == True{} : Bool}))

def vp.skip(
  ~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K,
  hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}, hm: {P.member(~K, ~eq, r, y) == False{} : Bool}
) -> VP(~K, ~eq, g, stale, limit, P.Pool{st, r, l}, y, P.PMark{P.Skipped{}}):
  (hn, (hm, (dy => hs => hd => Empty.absurd({P.ready(~K, ~eq, dy, st) == True{} : Bool}, false_ne_true(hs)),
    e => Empty.absurd({P.member(~K, ~eq, stale, y) == False{} : Bool}, skipped_ne_fresh(e)))))

def vp.room(
  ~K: Data, ~eq: K -> K -> Bool, room: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K, +ds: List<&2, K>,
  hroom: {P.le(1n+Ln(K, r), limit) == room : Bool}, +hds: {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>},
  +hgo: {P.ready(~K, ~eq, ds, st) == True{} : Bool}, hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}, hm: {P.member(~K, ~eq, r, y) == False{} : Bool}
) -> VP(~K, ~eq, g, stale, limit, P.Pool{st, r, l}, y, P.decide.par.room(room)):
  match room:
    case True{}:
      (hn, (hm, (dy => hd => ready_move(~K, ~eq, g, st, y, ds, dy, hds, hd, hgo), hroom)))
    case False{}:
      hl => hr0 => clash(P.le(1n, limit), hl, (%hr0 : {P.le(1n+Ln(K, _), limit) == False{} : Bool} hroom))

def vp.go(
  ~K: Data, ~eq: K -> K -> Bool, go: Bool, sx: Bool, room: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K, +ds: List<&2, K>,
  +hgo: {P.ready(~K, ~eq, ds, st) == go : Bool}, hsx: {P.member(~K, ~eq, stale, y) == sx : Bool},
  hroom: {P.le(1n+Ln(K, r), limit) == room : Bool}, +hds: {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>},
  +hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}, +hm: {P.member(~K, ~eq, r, y) == False{} : Bool}
) -> VP(~K, ~eq, g, stale, limit, P.Pool{st, r, l}, y, P.decide.par.go(go, sx, room)):
  match go:
    case False{}:
      vp.skip(~K, ~eq, g, stale, limit, st, r, l, y, hn, hm)
    case True{}:
      match sx:
        case False{}:
          (hn, (hm, (dy => hs => hd => ready_move(~K, ~eq, g, st, y, ds, dy, hds, hd, hgo), e => hsx)))
        case True{}:
          vp.room(~K, ~eq, room, g, stale, limit, st, r, l, y, ds, hroom, hds, hgo, hn, hm)

def vp.wait(
  ~K: Data, ~eq: K -> K -> Bool, busy: Bool, go: Bool, sx: Bool, room: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K, +ds: List<&2, K>,
  hbusy: {P.any_in(~K, ~eq, ds, r) == busy : Bool}, hgo: {P.ready(~K, ~eq, ds, st) == go : Bool}, hsx: {P.member(~K, ~eq, stale, y) == sx : Bool},
  hroom: {P.le(1n+Ln(K, r), limit) == room : Bool}, hds: {P.deps(~K, ~eq, g, y) == Some{ds} : Maybe<&2, List<&2, K>>},
  hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}, hm: {P.member(~K, ~eq, r, y) == False{} : Bool}
) -> VP(~K, ~eq, g, stale, limit, P.Pool{st, r, l}, y, P.decide.par.wait(busy, go, sx, room)):
  match busy:
    case True{}:
      hl => hr0 => clash(P.any_in(~K, ~eq, ds, Nil{}), (%hr0 : {P.any_in(~K, ~eq, ds, _) == True{} : Bool} hbusy), any_nil(~K, ~eq, ds))
    case False{}:
      vp.go(~K, ~eq, go, sx, room, g, stale, limit, st, r, l, y, ds, hgo, hsx, hroom, hds, hn, hm)

def vp.node(
  ~K: Data, ~eq: K -> K -> Bool, m: Maybe<&2, List<&2, K>>, sx: Bool, room: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K,
  hmm: {P.deps(~K, ~eq, g, y) == m : Maybe<&2, List<&2, K>>}, hsx: {P.member(~K, ~eq, stale, y) == sx : Bool},
  hroom: {P.le(1n+Ln(K, r), limit) == room : Bool},
  hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}, hm: {P.member(~K, ~eq, r, y) == False{} : Bool}
) -> VP(~K, ~eq, g, stale, limit, P.Pool{st, r, l}, y, P.decide.par.node(~K, ~eq, m, st, r, sx, room)):
  match m:
    case None{}:
      vp.skip(~K, ~eq, g, stale, limit, st, r, l, y, hn, hm)
    case Some{+ds}:
      vp.wait(~K, ~eq, P.any_in(~K, ~eq, ds, r), P.ready(~K, ~eq, ds, st), sx, room, g, stale, limit, st, r, l, y, ds,
        {==}, {==}, hsx, hroom, hmm, hn, hm)

def vp.seen(
  ~K: Data, ~eq: K -> K -> Bool, b: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K,
  +hb: {Bool.or(Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y)), P.member(~K, ~eq, r, y)) == b : Bool}
) -> VP(~K, ~eq, g, stale, limit, P.Pool{st, r, l}, y, P.decide.par.seen(~K, ~eq, b, g, stale, limit, st, r, y)):
  match b:
    case True{}:
      hb
    case False{}:
      +so = Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y))
      vp.node(~K, ~eq, P.deps(~K, ~eq, g, y), P.member(~K, ~eq, stale, y), P.le(1n+Ln(K, r), limit), g, stale, limit, st, r, l, y,
        {==}, {==}, {==}, none_of(St(~K, ~eq, st, y), or_false_l2(so, P.member(~K, ~eq, r, y), hb)), or_false_r(so, P.member(~K, ~eq, r, y), hb))

def view.par(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, pool: P.Pool<K>, +y: K) ->
  VP(~K, ~eq, g, stale, limit, pool, y, P.decide.par(~K, ~eq, g, stale, limit, pool, y)):
  match pool:
    case P.Pool{+st, +r, +l}:
      vp.seen(~K, ~eq, Bool.or(Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y)), P.member(~K, ~eq, r, y)), g, stale, limit, st, r, l, y, {==})

# Parallel execution: invariants
# ------------------------------

def GAc(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>) -> Bool:
  Bool.and(none_all(~K, ~eq, r, st), Bool.and(P.distinct(~K, ~eq, P.keys(K, st)), Bool.and(P.distinct(~K, ~eq, l),
    Bool.and(logged(~K, ~eq, l, r, st), P.le(Ln(K, r), limit)))))

def GA(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +pool: P.Pool<K>) -> Type:
  {GAc(~K, ~eq, limit, Sts(K, pool), Run(K, pool), Log(K, pool)) == True{} : Bool}

def mk_ga(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>,
  h1: {none_all(~K, ~eq, r, st) == True{} : Bool}, h2: {P.distinct(~K, ~eq, P.keys(K, st)) == True{} : Bool},
  h3: {P.distinct(~K, ~eq, l) == True{} : Bool}, h4: {logged(~K, ~eq, l, r, st) == True{} : Bool}, h5: {P.le(Ln(K, r), limit) == True{} : Bool}
) -> {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}:
  and_true(none_all(~K, ~eq, r, st), Bool.and(P.distinct(~K, ~eq, P.keys(K, st)), Bool.and(P.distinct(~K, ~eq, l), Bool.and(logged(~K, ~eq, l, r, st), P.le(Ln(K, r), limit)))), h1,
    and_true(P.distinct(~K, ~eq, P.keys(K, st)), Bool.and(P.distinct(~K, ~eq, l), Bool.and(logged(~K, ~eq, l, r, st), P.le(Ln(K, r), limit))), h2,
      and_true(P.distinct(~K, ~eq, l), Bool.and(logged(~K, ~eq, l, r, st), P.le(Ln(K, r), limit)), h3,
        and_true(logged(~K, ~eq, l, r, st), P.le(Ln(K, r), limit), h4, h5))))

def GA4(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>) -> Bool:
  Bool.and(logged(~K, ~eq, l, r, st), P.le(Ln(K, r), limit))

def GA3(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>) -> Bool:
  Bool.and(P.distinct(~K, ~eq, l), GA4(~K, ~eq, limit, st, r, l))

def GA2(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>) -> Bool:
  Bool.and(P.distinct(~K, ~eq, P.keys(K, st)), GA3(~K, ~eq, limit, st, r, l))

def ga1(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, h: {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}) ->
  {none_all(~K, ~eq, r, st) == True{} : Bool}:
  and_l(none_all(~K, ~eq, r, st), GA2(~K, ~eq, limit, st, r, l), h)

def ga2(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, h: {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}) ->
  {P.distinct(~K, ~eq, P.keys(K, st)) == True{} : Bool}:
  and_l(P.distinct(~K, ~eq, P.keys(K, st)), GA3(~K, ~eq, limit, st, r, l), and_r(none_all(~K, ~eq, r, st), GA2(~K, ~eq, limit, st, r, l), h))

def ga3(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +h: {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}) ->
  {P.distinct(~K, ~eq, l) == True{} : Bool}:
  and_l(P.distinct(~K, ~eq, l), GA4(~K, ~eq, limit, st, r, l),
    and_r(P.distinct(~K, ~eq, P.keys(K, st)), GA3(~K, ~eq, limit, st, r, l), and_r(none_all(~K, ~eq, r, st), GA2(~K, ~eq, limit, st, r, l), h)))

def ga45(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +h: {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}) ->
  {GA4(~K, ~eq, limit, st, r, l) == True{} : Bool}:
  and_r(P.distinct(~K, ~eq, l), GA4(~K, ~eq, limit, st, r, l),
    and_r(P.distinct(~K, ~eq, P.keys(K, st)), GA3(~K, ~eq, limit, st, r, l), and_r(none_all(~K, ~eq, r, st), GA2(~K, ~eq, limit, st, r, l), h)))

def ga4(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +h: {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}) ->
  {logged(~K, ~eq, l, r, st) == True{} : Bool}:
  and_l(logged(~K, ~eq, l, r, st), P.le(Ln(K, r), limit), ga45(~K, ~eq, limit, st, r, l, h))

def ga5(~K: Data, ~eq: K -> K -> Bool, +limit: Nat, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +h: {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}) ->
  {P.le(Ln(K, r), limit) == True{} : Bool}:
  and_r(logged(~K, ~eq, l, r, st), P.le(Ln(K, r), limit), ga45(~K, ~eq, limit, st, r, l, h))

def ga_apply(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  pool: P.Pool<K>, +y: K, hv: VP(~K, ~eq, g, stale, limit, pool, y, a), ga: GA(~K, ~eq, limit, pool)
) -> GA(~K, ~eq, limit, P.apply(K, a, pool, y)):
  match a:
    case P.PSkip{}:
      ga
    case P.PWait{}:
      ga
    case P.PMark{+s}:
      match pool:
        case P.Pool{+st, +r, +l}:
          (hn, h1) = hv
          (hm, h2) = h1
          +ga = {ga : {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}}
          mk_ga(~K, ~eq, limit, P.Entry{y, s} <> st, r, l,
            none_cons(~K, ~eq, ~sound, ~refl, r, st, y, s, hm, ga1(~K, ~eq, limit, st, r, l, ga)),
            and_not_false(P.member(~K, ~eq, P.keys(K, st), y), P.distinct(~K, ~eq, P.keys(K, st)), keys_none(~K, ~eq, st, y, hn), ga2(~K, ~eq, limit, st, r, l, ga)),
            ga3(~K, ~eq, limit, st, r, l, ga), logged_mark(~K, ~eq, l, r, st, y, s, ga4(~K, ~eq, limit, st, r, l, ga)), ga5(~K, ~eq, limit, st, r, l, ga))
    case P.PStart{}:
      match pool:
        case P.Pool{+st, +r, +l}:
          (hn, h1) = hv
          (hm, h2) = h1
          (hdep, hroom) = h2
          +ga = {ga : {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}}
          +hn = {hn : {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}}
          +hm = {hm : {P.member(~K, ~eq, r, y) == False{} : Bool}}
          +g4 = ga4(~K, ~eq, limit, st, r, l, ga)
          mk_ga(~K, ~eq, limit, st, y <> r, y <> l,
            and_true(Maybe.is_none(&2, P.Status, St(~K, ~eq, st, y)), none_all(~K, ~eq, r, st), is_none_of(St(~K, ~eq, st, y), hn), ga1(~K, ~eq, limit, st, r, l, ga)),
            ga2(~K, ~eq, limit, st, r, l, ga),
            and_not_false(P.member(~K, ~eq, l, y), P.distinct(~K, ~eq, l), logged_not(~K, ~eq, ~sound, l, r, st, y, g4, hm, hn), ga3(~K, ~eq, limit, st, r, l, ga)),
            logged_start(~K, ~eq, ~refl, l, r, st, y, g4), hroom)

def ga_fin.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), b: Bool, +limit: Nat,
  +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K, +ok: Bool,
  hb: {P.member(~K, ~eq, r, y) == b : Bool}, ga: GA(~K, ~eq, limit, P.Pool{st, r, l})
) -> GA(~K, ~eq, limit, P.finish.if(K, b, y, ok, st, r, Dr(~K, ~eq, r, y), l)):
  match b:
    case True{}:
      +ga = {ga : {GAc(~K, ~eq, limit, st, r, l) == True{} : Bool}}
      +g1 = ga1(~K, ~eq, limit, st, r, l, ga)
      +s = P.Fin.status(ok)
      +hn = none_mem(~K, ~eq, ~sound, r, st, y, g1, hb)
      mk_ga(~K, ~eq, limit, P.Entry{y, s} <> st, Dr(~K, ~eq, r, y), l,
        none_drop(~K, ~eq, ~sound, ~refl, r, st, y, s, g1),
        and_not_false(P.member(~K, ~eq, P.keys(K, st), y), P.distinct(~K, ~eq, P.keys(K, st)), keys_none(~K, ~eq, st, y, hn), ga2(~K, ~eq, limit, st, r, l, ga)),
        ga3(~K, ~eq, limit, st, r, l, ga), logged_finish(~K, ~eq, ~sound, ~refl, l, r, st, y, s, ga4(~K, ~eq, limit, st, r, l, ga)),
        le_trans(Ln(K, Dr(~K, ~eq, r, y)), Ln(K, r), limit, len_drop(~K, ~eq, r, y), ga5(~K, ~eq, limit, st, r, l, ga)))
    case False{}:
      ga

def ga_finish(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +limit: Nat, pool: P.Pool<K>, e: P.Fin<K>, ga: GA(~K, ~eq, limit, pool)
) -> GA(~K, ~eq, limit, P.finish(~K, ~eq, pool, e)):
  match pool e:
    case P.Pool{+st, +r, +l} P.Fin{+y, +ok}:
      ga_fin.if(~K, ~eq, ~sound, ~refl, P.member(~K, ~eq, r, y), limit, st, r, l, y, ok, {==}, ga)

def GB(~K: Data, ~eq: K -> K -> Bool, +stale: List<&2, K>, +pool: P.Pool<K>, +x: K, +ds: List<&2, K>) -> Type:
  ({P.selected.at(St(~K, ~eq, Sts(K, pool), x)) == True{} : Bool} -> {P.ready(~K, ~eq, ds, Sts(K, pool)) == True{} : Bool})
  & ({Bool.or(Bool.not(P.member(~K, ~eq, Run(K, pool), x)), P.ready(~K, ~eq, ds, Sts(K, pool))) == True{} : Bool}
  & ({St(~K, ~eq, Sts(K, pool), x) == Some{P.Fresh{}} : Maybe<&2, P.Status>} -> {P.member(~K, ~eq, stale, x) == False{} : Bool}))

def imp_intro(a: Bool, -b: Bool, f: {a == True{} : Bool} -> {b == True{} : Bool}) -> {Bool.or(Bool.not(a), b) == True{} : Bool}:
  match a:
    case True{}:
      f({==})
    case False{}:
      {==}

def gb_start.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +g: List<&2, P.Node<K>>, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +y: K, +x: K, +ds: List<&2, K>,
  hc: {eq(x, y) == c : Bool}, hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>},
  hdep: @dy: List<&2, K> -> {P.deps(~K, ~eq, g, y) == Some{dy} : Maybe<&2, List<&2, K>>} -> {P.ready(~K, ~eq, dy, st) == True{} : Bool},
  b2: {Bool.or(Bool.not(P.member(~K, ~eq, r, x)), P.ready(~K, ~eq, ds, st)) == True{} : Bool},
  hm2: {P.member(~K, ~eq, y <> r, x) == True{} : Bool}
) -> {P.ready(~K, ~eq, ds, st) == True{} : Bool}:
  match c:
    case True{}:
      hdep(ds, deps_move(~K, ~eq, g, x, y, ds, sound(x, y, hc), hd))
    case False{}:
      imp_true(P.member(~K, ~eq, r, x), P.ready(~K, ~eq, ds, st), mem_tail(~K, ~eq, y, r, x, hc, hm2), b2)

def gb_apply(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  pool: P.Pool<K>, +y: K, +x: K, +ds: List<&2, K>, +hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>},
  hv: VP(~K, ~eq, g, stale, limit, pool, y, a), gb: GB(~K, ~eq, stale, pool, x, ds)
) -> GB(~K, ~eq, stale, P.apply(K, a, pool, y), x, ds):
  match a:
    case P.PSkip{}:
      gb
    case P.PWait{}:
      gb
    case P.PMark{+s}:
      match pool:
        case P.Pool{+st, +r, +l}:
          (hn, h1) = hv
          (hm, h2) = h1
          (hsel, hfr) = h2
          (b1, q) = gb
          (b2, b3) = q
          +hn = {hn : {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>}}
          (hs => ready_step.if(~K, ~eq, ~sound, eq(x, y), g, st, y, s, x, ds, {==}, hd, hn, hsel, b1, hs),
           (imp_intro(P.member(~K, ~eq, r, x), P.ready(~K, ~eq, ds, P.Entry{y, s} <> st),
              hm2 => ready_keep(~K, ~eq, ~sound, ds, st, y, s, imp_true(P.member(~K, ~eq, r, x), P.ready(~K, ~eq, ds, st), hm2, b2), hn)),
            hf => fresh_step.if(~K, ~eq, ~sound, eq(x, y), stale, st, y, s, x, {==}, hfr, b3, hf)))
    case P.PStart{}:
      match pool:
        case P.Pool{+st, +r, +l}:
          (hn, h1) = hv
          (hm, h2) = h1
          (hdep, hroom) = h2
          (b1, q) = gb
          (b2, b3) = q
          (b1, (imp_intro(P.member(~K, ~eq, y <> r, x), P.ready(~K, ~eq, ds, st),
             hm2 => gb_start.if(~K, ~eq, ~sound, eq(x, y), g, st, r, y, x, ds, {==}, hd, hdep, b2, hm2)), b3))

def gb_fin_sel.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), c: Bool, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +y: K, +s: P.Status, +x: K, +ds: List<&2, K>,
  +hc: {eq(x, y) == c : Bool}, hb: {P.member(~K, ~eq, r, y) == True{} : Bool}, +hn: {St(~K, ~eq, st, y) == None{} : Maybe<&2, P.Status>},
  b1: {P.selected.at(St(~K, ~eq, st, x)) == True{} : Bool} -> {P.ready(~K, ~eq, ds, st) == True{} : Bool},
  b2: {Bool.or(Bool.not(P.member(~K, ~eq, r, x)), P.ready(~K, ~eq, ds, st)) == True{} : Bool},
  hs: {P.selected.at(St(~K, ~eq, P.Entry{y, s} <> st, x)) == True{} : Bool}
) -> {P.ready(~K, ~eq, ds, P.Entry{y, s} <> st) == True{} : Bool}:
  match c:
    case True{}:
      ready_keep(~K, ~eq, ~sound, ds, st, y, s,
        imp_true(P.member(~K, ~eq, r, x), P.ready(~K, ~eq, ds, st), (%Equal.sym(K, x, y, sound(x, y, hc)) : {P.member(~K, ~eq, r, _) == True{} : Bool} hb), b2), hn)
    case False{}:
      ready_keep(~K, ~eq, ~sound, ds, st, y, s,
        b1(%st_miss(~K, ~eq, y, s, st, x, hc) : {P.selected.at(_) == True{} : Bool} hs), hn)

def gb_fin_fresh.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +y: K, +ok: Bool, +x: K,
  +hc: {eq(x, y) == c : Bool},
  b3: {St(~K, ~eq, st, x) == Some{P.Fresh{}} : Maybe<&2, P.Status>} -> {P.member(~K, ~eq, stale, x) == False{} : Bool},
  hf: {St(~K, ~eq, P.Entry{y, P.Fin.status(ok)} <> st, x) == Some{P.Fresh{}} : Maybe<&2, P.Status>}
) -> {P.member(~K, ~eq, stale, x) == False{} : Bool}:
  match c:
    case True{}:
      Empty.absurd({P.member(~K, ~eq, stale, x) == False{} : Bool},
        fin_ne_fresh(ok, some_inj(P.Status, P.Fin.status(ok), P.Fresh{},
          Equal.trans(Maybe<&2, P.Status>, Some{P.Fin.status(ok)}, St(~K, ~eq, P.Entry{y, P.Fin.status(ok)} <> st, x), Some{P.Fresh{}},
            Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, P.Fin.status(ok)} <> st, x), Some{P.Fin.status(ok)}, st_hit(~K, ~eq, y, P.Fin.status(ok), st, x, hc)), hf))))
    case False{}:
      b3(%st_miss(~K, ~eq, y, P.Fin.status(ok), st, x, hc) : {_ == Some{P.Fresh{}} : Maybe<&2, P.Status>} hf)

def gb_fin.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), b: Bool, +stale: List<&2, K>,
  +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K, +ok: Bool, +x: K, +ds: List<&2, K>,
  +hb: {P.member(~K, ~eq, r, y) == b : Bool}, hnone: {none_all(~K, ~eq, r, st) == True{} : Bool}, gb: GB(~K, ~eq, stale, P.Pool{st, r, l}, x, ds)
) -> GB(~K, ~eq, stale, P.finish.if(K, b, y, ok, st, r, Dr(~K, ~eq, r, y), l), x, ds):
  match b:
    case True{}:
      (b1, q) = gb
      (b2, b3) = q
      +b2 = {b2 : {Bool.or(Bool.not(P.member(~K, ~eq, r, x)), P.ready(~K, ~eq, ds, st)) == True{} : Bool}}
      +s = P.Fin.status(ok)
      +hn = none_mem(~K, ~eq, ~sound, r, st, y, hnone, hb)
      (hs => gb_fin_sel.if(~K, ~eq, ~sound, eq(x, y), st, r, y, s, x, ds, {==}, hb, hn, b1, b2, hs),
       (imp_intro(P.member(~K, ~eq, Dr(~K, ~eq, r, y), x), P.ready(~K, ~eq, ds, P.Entry{y, s} <> st),
          hm2 => ready_keep(~K, ~eq, ~sound, ds, st, y, s, imp_true(P.member(~K, ~eq, r, x), P.ready(~K, ~eq, ds, st), mem_drop_sub(~K, ~eq, r, y, x, hm2), b2), hn)),
        hf => gb_fin_fresh.if(~K, ~eq, eq(x, y), stale, st, y, ok, x, {==}, b3, hf)))
    case False{}:
      gb


def gb_finish(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +stale: List<&2, K>, +limit: Nat, pool: P.Pool<K>, e: P.Fin<K>, +x: K, +ds: List<&2, K>,
  ga: GA(~K, ~eq, limit, pool), gb: GB(~K, ~eq, stale, pool, x, ds)
) -> GB(~K, ~eq, stale, P.finish(~K, ~eq, pool, e), x, ds):
  match pool e:
    case P.Pool{+st, +r, +l} P.Fin{+y, +ok}:
      gb_fin.if(~K, ~eq, ~sound, ~refl, P.member(~K, ~eq, r, y), stale, st, r, l, y, ok, x, ds, {==},
        ga1(~K, ~eq, limit, st, r, l, ga), gb)

# Parallel execution: induction
# -----------------------------

def PAR(~K: Data, ~eq: K -> K -> Bool, es: List<&2, P.Fin<K>>, p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>) -> P.Pool<K>:
  P.par(~K, ~eq, es, p, g, stale, limit, pool)

def ga.at0(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +y: K, +t: List<&2, K>, hv: VP(~K, ~eq, g, stale, limit, pool, y, a), ga: GA(~K, ~eq, limit, pool),
  ih: @q: P.Pool<K> -> GA(~K, ~eq, limit, q) -> GA(~K, ~eq, limit, PAR(~K, ~eq, Nil{}, t, g, stale, limit, q))
) -> GA(~K, ~eq, limit, P.par.at(P.Pool<K>, a, u => pool, u => P.par(~K, ~eq, Nil{}, t, g, stale, limit, P.apply(K, a, pool, y)))):
  match a:
    case P.PWait{}:
      ga
    case P.PSkip{}:
      ih(P.apply(K, P.PSkip{}, pool, y), ga_apply(~K, ~eq, ~sound, ~refl, P.PSkip{}, g, stale, limit, pool, y, hv, ga))
    case P.PMark{+s}:
      ih(P.apply(K, P.PMark{s}, pool, y), ga_apply(~K, ~eq, ~sound, ~refl, P.PMark{s}, g, stale, limit, pool, y, hv, ga))
    case P.PStart{}:
      ih(P.apply(K, P.PStart{}, pool, y), ga_apply(~K, ~eq, ~sound, ~refl, P.PStart{}, g, stale, limit, pool, y, hv, ga))

def ga.at1(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +e: P.Fin<K>, +r: List<&2, P.Fin<K>>, +y: K, +t: List<&2, K>, hv: VP(~K, ~eq, g, stale, limit, pool, y, a), ga: GA(~K, ~eq, limit, pool),
  ihw: GA(~K, ~eq, limit, PAR(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e))),
  ih: @q: P.Pool<K> -> GA(~K, ~eq, limit, q) -> GA(~K, ~eq, limit, PAR(~K, ~eq, e <> r, t, g, stale, limit, q))
) -> GA(~K, ~eq, limit, P.par.at(P.Pool<K>, a,
    u => P.par(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)),
    u => P.par(~K, ~eq, e <> r, t, g, stale, limit, P.apply(K, a, pool, y)))):
  match a:
    case P.PWait{}:
      ihw
    case P.PSkip{}:
      ih(P.apply(K, P.PSkip{}, pool, y), ga_apply(~K, ~eq, ~sound, ~refl, P.PSkip{}, g, stale, limit, pool, y, hv, ga))
    case P.PMark{+s}:
      ih(P.apply(K, P.PMark{s}, pool, y), ga_apply(~K, ~eq, ~sound, ~refl, P.PMark{s}, g, stale, limit, pool, y, hv, ga))
    case P.PStart{}:
      ih(P.apply(K, P.PStart{}, pool, y), ga_apply(~K, ~eq, ~sound, ~refl, P.PStart{}, g, stale, limit, pool, y, hv, ga))

def par_ga(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), es: List<&2, P.Fin<K>>, p: List<&2, K>,
  +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, ga: GA(~K, ~eq, limit, pool)
) -> GA(~K, ~eq, limit, PAR(~K, ~eq, es, p, g, stale, limit, pool)):
  match es:
    case Nil{}:
      match p:
        case Nil{}:
          ga
        case Con{+y, +t}:
          ga.at0(~K, ~eq, ~sound, ~refl, P.decide.par(~K, ~eq, g, stale, limit, pool, y), g, stale, limit, pool, y, t,
            view.par(~K, ~eq, g, stale, limit, pool, y), ga, q => h => par_ga(~K, ~eq, ~sound, ~refl, Nil{}, t, g, stale, limit, q, h))
    case Con{+e, +r}:
      match p:
        case Nil{}:
          par_ga(~K, ~eq, ~sound, ~refl, r, Nil{}, g, stale, limit, P.finish(~K, ~eq, pool, e), ga_finish(~K, ~eq, ~sound, ~refl, limit, pool, e, ga))
        case Con{+y, +t}:
          +ga = {ga : {GAc(~K, ~eq, limit, Sts(K, pool), Run(K, pool), Log(K, pool)) == True{} : Bool}}
          ga.at1(~K, ~eq, ~sound, ~refl, P.decide.par(~K, ~eq, g, stale, limit, pool, y), g, stale, limit, pool, e, r, y, t,
            view.par(~K, ~eq, g, stale, limit, pool, y), ga,
            par_ga(~K, ~eq, ~sound, ~refl, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e), ga_finish(~K, ~eq, ~sound, ~refl, limit, pool, e, ga)),
            q => h => par_ga(~K, ~eq, ~sound, ~refl, e <> r, t, g, stale, limit, q, h))

def GAB(~K: Data, ~eq: K -> K -> Bool, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, +x: K, +ds: List<&2, K>) -> Type:
  GA(~K, ~eq, limit, pool) & GB(~K, ~eq, stale, pool, x, ds)

def gab_apply(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +y: K, +x: K, +ds: List<&2, K>, +hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>},
  hva: VP(~K, ~eq, g, stale, limit, pool, y, a), hvb: VP(~K, ~eq, g, stale, limit, pool, y, a), h: GAB(~K, ~eq, stale, limit, pool, x, ds)
) -> GAB(~K, ~eq, stale, limit, P.apply(K, a, pool, y), x, ds):
  (ga, gb) = h
  (ga_apply(~K, ~eq, ~sound, ~refl, a, g, stale, limit, pool, y, hva, ga), gb_apply(~K, ~eq, ~sound, a, g, stale, limit, pool, y, x, ds, hd, hvb, gb))

def gab_finish(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, +e: P.Fin<K>, +x: K, +ds: List<&2, K>,
  h: GAB(~K, ~eq, stale, limit, pool, x, ds)
) -> GAB(~K, ~eq, stale, limit, P.finish(~K, ~eq, pool, e), x, ds):
  (ga0, gb) = h
  +ga = {ga0 : {GAc(~K, ~eq, limit, Sts(K, pool), Run(K, pool), Log(K, pool)) == True{} : Bool}}
  (ga_finish(~K, ~eq, ~sound, ~refl, limit, pool, e, ga), gb_finish(~K, ~eq, ~sound, ~refl, stale, limit, pool, e, x, ds, ga, gb))

def gab.at0(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +y: K, +t: List<&2, K>, +x: K, +ds: List<&2, K>, +hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>},
  hva: VP(~K, ~eq, g, stale, limit, pool, y, a), hvb: VP(~K, ~eq, g, stale, limit, pool, y, a), h: GAB(~K, ~eq, stale, limit, pool, x, ds),
  ih: @q: P.Pool<K> -> GAB(~K, ~eq, stale, limit, q, x, ds) -> GAB(~K, ~eq, stale, limit, PAR(~K, ~eq, Nil{}, t, g, stale, limit, q), x, ds)
) -> GAB(~K, ~eq, stale, limit, P.par.at(P.Pool<K>, a, u => pool, u => P.par(~K, ~eq, Nil{}, t, g, stale, limit, P.apply(K, a, pool, y))), x, ds):
  match a:
    case P.PWait{}:
      h
    case P.PSkip{}:
      ih(P.apply(K, P.PSkip{}, pool, y), gab_apply(~K, ~eq, ~sound, ~refl, P.PSkip{}, g, stale, limit, pool, y, x, ds, hd, hva, hvb, h))
    case P.PMark{+s}:
      ih(P.apply(K, P.PMark{s}, pool, y), gab_apply(~K, ~eq, ~sound, ~refl, P.PMark{s}, g, stale, limit, pool, y, x, ds, hd, hva, hvb, h))
    case P.PStart{}:
      ih(P.apply(K, P.PStart{}, pool, y), gab_apply(~K, ~eq, ~sound, ~refl, P.PStart{}, g, stale, limit, pool, y, x, ds, hd, hva, hvb, h))

def gab.at1(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +e: P.Fin<K>, +r: List<&2, P.Fin<K>>, +y: K, +t: List<&2, K>, +x: K, +ds: List<&2, K>, +hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>},
  hva: VP(~K, ~eq, g, stale, limit, pool, y, a), hvb: VP(~K, ~eq, g, stale, limit, pool, y, a), h: GAB(~K, ~eq, stale, limit, pool, x, ds),
  ihw: GAB(~K, ~eq, stale, limit, P.finish(~K, ~eq, pool, e), x, ds) -> GAB(~K, ~eq, stale, limit, PAR(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)), x, ds),
  ih: @q: P.Pool<K> -> GAB(~K, ~eq, stale, limit, q, x, ds) -> GAB(~K, ~eq, stale, limit, PAR(~K, ~eq, e <> r, t, g, stale, limit, q), x, ds)
) -> GAB(~K, ~eq, stale, limit, P.par.at(P.Pool<K>, a,
    u => P.par(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)),
    u => P.par(~K, ~eq, e <> r, t, g, stale, limit, P.apply(K, a, pool, y))), x, ds):
  match a:
    case P.PWait{}:
      ihw(gab_finish(~K, ~eq, ~sound, ~refl, stale, limit, pool, e, x, ds, h))
    case P.PSkip{}:
      ih(P.apply(K, P.PSkip{}, pool, y), gab_apply(~K, ~eq, ~sound, ~refl, P.PSkip{}, g, stale, limit, pool, y, x, ds, hd, hva, hvb, h))
    case P.PMark{+s}:
      ih(P.apply(K, P.PMark{s}, pool, y), gab_apply(~K, ~eq, ~sound, ~refl, P.PMark{s}, g, stale, limit, pool, y, x, ds, hd, hva, hvb, h))
    case P.PStart{}:
      ih(P.apply(K, P.PStart{}, pool, y), gab_apply(~K, ~eq, ~sound, ~refl, P.PStart{}, g, stale, limit, pool, y, x, ds, hd, hva, hvb, h))

def par_gab(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), es: List<&2, P.Fin<K>>, p: List<&2, K>,
  +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, +x: K, +ds: List<&2, K>,
  +hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, h: GAB(~K, ~eq, stale, limit, pool, x, ds)
) -> GAB(~K, ~eq, stale, limit, PAR(~K, ~eq, es, p, g, stale, limit, pool), x, ds):
  match es:
    case Nil{}:
      match p:
        case Nil{}:
          h
        case Con{+y, +t}:
          gab.at0(~K, ~eq, ~sound, ~refl, P.decide.par(~K, ~eq, g, stale, limit, pool, y), g, stale, limit, pool, y, t, x, ds, hd,
            view.par(~K, ~eq, g, stale, limit, pool, y), view.par(~K, ~eq, g, stale, limit, pool, y), h,
            q => hh => par_gab(~K, ~eq, ~sound, ~refl, Nil{}, t, g, stale, limit, q, x, ds, hd, hh))
    case Con{+e, +r}:
      match p:
        case Nil{}:
          par_gab(~K, ~eq, ~sound, ~refl, r, Nil{}, g, stale, limit, P.finish(~K, ~eq, pool, e), x, ds, hd,
            gab_finish(~K, ~eq, ~sound, ~refl, stale, limit, pool, e, x, ds, h))
        case Con{+y, +t}:
          gab.at1(~K, ~eq, ~sound, ~refl, P.decide.par(~K, ~eq, g, stale, limit, pool, y), g, stale, limit, pool, e, r, y, t, x, ds, hd,
            view.par(~K, ~eq, g, stale, limit, pool, y), view.par(~K, ~eq, g, stale, limit, pool, y), h,
            hh => par_gab(~K, ~eq, ~sound, ~refl, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e), x, ds, hd, hh),
            q => hh => par_gab(~K, ~eq, ~sound, ~refl, e <> r, t, g, stale, limit, q, x, ds, hd, hh))

def GF(~K: Data, ~eq: K -> K -> Bool, +stale: List<&2, K>, +pool: P.Pool<K>, +x: K) -> Type:
  {St(~K, ~eq, Sts(K, pool), x) == Some{P.Fresh{}} : Maybe<&2, P.Status>} -> {P.member(~K, ~eq, stale, x) == False{} : Bool}

def gf_apply(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  pool: P.Pool<K>, +y: K, +x: K, hv: VP(~K, ~eq, g, stale, limit, pool, y, a), gf: GF(~K, ~eq, stale, pool, x)
) -> GF(~K, ~eq, stale, P.apply(K, a, pool, y), x):
  match a:
    case P.PSkip{}:
      gf
    case P.PWait{}:
      gf
    case P.PMark{+s}:
      match pool:
        case P.Pool{+st, +r, +l}:
          (hn, h1) = hv
          (hm, h2) = h1
          (hsel, hfr) = h2
          hf => fresh_step.if(~K, ~eq, ~sound, eq(x, y), stale, st, y, s, x, {==}, hfr, gf, hf)
    case P.PStart{}:
      match pool:
        case P.Pool{+st, +r, +l}:
          gf

def gf_fin.if(~K: Data, ~eq: K -> K -> Bool, b: Bool, +stale: List<&2, K>, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K, +ok: Bool, +x: K,
  gf: GF(~K, ~eq, stale, P.Pool{st, r, l}, x)
) -> GF(~K, ~eq, stale, P.finish.if(K, b, y, ok, st, r, Dr(~K, ~eq, r, y), l), x):
  match b:
    case True{}:
      hf => gb_fin_fresh.if(~K, ~eq, eq(x, y), stale, st, y, ok, x, {==}, gf, hf)
    case False{}:
      gf

def gf_finish(~K: Data, ~eq: K -> K -> Bool, +stale: List<&2, K>, pool: P.Pool<K>, e: P.Fin<K>, +x: K, gf: GF(~K, ~eq, stale, pool, x)) ->
  GF(~K, ~eq, stale, P.finish(~K, ~eq, pool, e), x):
  match pool e:
    case P.Pool{+st, +r, +l} P.Fin{+y, +ok}:
      gf_fin.if(~K, ~eq, P.member(~K, ~eq, r, y), stale, st, r, l, y, ok, x, gf)

def gf.at0(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +y: K, +t: List<&2, K>, +x: K, hv: VP(~K, ~eq, g, stale, limit, pool, y, a), h: GF(~K, ~eq, stale, pool, x),
  ih: @q: P.Pool<K> -> GF(~K, ~eq, stale, q, x) -> GF(~K, ~eq, stale, PAR(~K, ~eq, Nil{}, t, g, stale, limit, q), x)
) -> GF(~K, ~eq, stale, P.par.at(P.Pool<K>, a, u => pool, u => P.par(~K, ~eq, Nil{}, t, g, stale, limit, P.apply(K, a, pool, y))), x):
  match a:
    case P.PWait{}:
      h
    case P.PSkip{}:
      ih(P.apply(K, P.PSkip{}, pool, y), gf_apply(~K, ~eq, ~sound, P.PSkip{}, g, stale, limit, pool, y, x, hv, h))
    case P.PMark{+s}:
      ih(P.apply(K, P.PMark{s}, pool, y), gf_apply(~K, ~eq, ~sound, P.PMark{s}, g, stale, limit, pool, y, x, hv, h))
    case P.PStart{}:
      ih(P.apply(K, P.PStart{}, pool, y), gf_apply(~K, ~eq, ~sound, P.PStart{}, g, stale, limit, pool, y, x, hv, h))

def gf.at1(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +e: P.Fin<K>, +r: List<&2, P.Fin<K>>, +y: K, +t: List<&2, K>, +x: K, hv: VP(~K, ~eq, g, stale, limit, pool, y, a), h: GF(~K, ~eq, stale, pool, x),
  ihw: GF(~K, ~eq, stale, P.finish(~K, ~eq, pool, e), x) -> GF(~K, ~eq, stale, PAR(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)), x),
  ih: @q: P.Pool<K> -> GF(~K, ~eq, stale, q, x) -> GF(~K, ~eq, stale, PAR(~K, ~eq, e <> r, t, g, stale, limit, q), x)
) -> GF(~K, ~eq, stale, P.par.at(P.Pool<K>, a,
    u => P.par(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)),
    u => P.par(~K, ~eq, e <> r, t, g, stale, limit, P.apply(K, a, pool, y))), x):
  match a:
    case P.PWait{}:
      ihw(gf_finish(~K, ~eq, stale, pool, e, x, h))
    case P.PSkip{}:
      ih(P.apply(K, P.PSkip{}, pool, y), gf_apply(~K, ~eq, ~sound, P.PSkip{}, g, stale, limit, pool, y, x, hv, h))
    case P.PMark{+s}:
      ih(P.apply(K, P.PMark{s}, pool, y), gf_apply(~K, ~eq, ~sound, P.PMark{s}, g, stale, limit, pool, y, x, hv, h))
    case P.PStart{}:
      ih(P.apply(K, P.PStart{}, pool, y), gf_apply(~K, ~eq, ~sound, P.PStart{}, g, stale, limit, pool, y, x, hv, h))

def par_gf(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), es: List<&2, P.Fin<K>>, p: List<&2, K>,
  +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, +x: K, h: GF(~K, ~eq, stale, pool, x)
) -> GF(~K, ~eq, stale, PAR(~K, ~eq, es, p, g, stale, limit, pool), x):
  match es:
    case Nil{}:
      match p:
        case Nil{}:
          h
        case Con{+y, +t}:
          gf.at0(~K, ~eq, ~sound, P.decide.par(~K, ~eq, g, stale, limit, pool, y), g, stale, limit, pool, y, t, x,
            view.par(~K, ~eq, g, stale, limit, pool, y), h, q => hh => par_gf(~K, ~eq, ~sound, Nil{}, t, g, stale, limit, q, x, hh))
    case Con{+e, +r}:
      match p:
        case Nil{}:
          par_gf(~K, ~eq, ~sound, r, Nil{}, g, stale, limit, P.finish(~K, ~eq, pool, e), x, gf_finish(~K, ~eq, stale, pool, e, x, h))
        case Con{+y, +t}:
          gf.at1(~K, ~eq, ~sound, P.decide.par(~K, ~eq, g, stale, limit, pool, y), g, stale, limit, pool, e, r, y, t, x,
            view.par(~K, ~eq, g, stale, limit, pool, y), h,
            hh => par_gf(~K, ~eq, ~sound, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e), x, hh),
            q => hh => par_gf(~K, ~eq, ~sound, e <> r, t, g, stale, limit, q, x, hh))

# Parallel execution: totality
# ----------------------------

def AP(~K: Data, ~eq: K -> K -> Bool, +pool: P.Pool<K>, +x: K) -> Bool:
  Acp(~K, ~eq, Run(K, pool), Sts(K, pool), x)

def acc_apply(~K: Data, ~eq: K -> K -> Bool, a: P.Step, pool: P.Pool<K>, +y: K, +x: K, h: {AP(~K, ~eq, pool, x) == True{} : Bool}) ->
  {AP(~K, ~eq, P.apply(K, a, pool, y), x) == True{} : Bool}:
  match a:
    case P.PSkip{}:
      h
    case P.PWait{}:
      h
    case P.PMark{+s}:
      match pool:
        case P.Pool{+st, +r, +l}:
          or_mono(P.member(~K, ~eq, r, x), Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)), Maybe.is_some(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, x)), h,
            f => some_keep.if(~K, ~eq, eq(x, y), y, s, st, x, {==}, f))
    case P.PStart{}:
      match pool:
        case P.Pool{+st, +r, +l}:
          or_mono_l(P.member(~K, ~eq, r, x), Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)), P.member(~K, ~eq, y <> r, x), h,
            f => mem_cons_r(~K, ~eq, y, r, x, f))

def acc_fin2.if(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), b: Bool, +st: List<&2, P.Entry<K>>, +r: List<&2, K>, +l: List<&2, K>, +y: K, +ok: Bool, +x: K,
  h: {Acp(~K, ~eq, r, st, x) == True{} : Bool}
) -> {AP(~K, ~eq, P.finish.if(K, b, y, ok, st, r, Dr(~K, ~eq, r, y), l), x) == True{} : Bool}:
  match b:
    case True{}:
      acc_fin(~K, ~eq, ~sound, ~refl, r, st, y, P.Fin.status(ok), x, h)
    case False{}:
      h

def acc_finish(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), pool: P.Pool<K>, e: P.Fin<K>, +x: K,
  h: {AP(~K, ~eq, pool, x) == True{} : Bool}
) -> {AP(~K, ~eq, P.finish(~K, ~eq, pool, e), x) == True{} : Bool}:
  match pool e:
    case P.Pool{+st, +r, +l} P.Fin{+y, +ok}:
      acc_fin2.if(~K, ~eq, ~sound, ~refl, P.member(~K, ~eq, r, y), st, r, l, y, ok, x, h)

def tt.next.if(
  ~K: Data, ~eq: K -> K -> Bool, c: Bool, +a: P.Step, +pool: P.Pool<K>, +y: K, +t: List<&2, K>, +x: K,
  hc: {eq(x, y) == c : Bool}, h: {Bool.or(P.member(~K, ~eq, y <> t, x), AP(~K, ~eq, pool, x)) == True{} : Bool},
  head: {eq(x, y) == True{} : Bool} -> {AP(~K, ~eq, P.apply(K, a, pool, y), x) == True{} : Bool}
) -> {Bool.or(P.member(~K, ~eq, t, x), AP(~K, ~eq, P.apply(K, a, pool, y), x)) == True{} : Bool}:
  match c:
    case True{}:
      or_true_r(P.member(~K, ~eq, t, x), AP(~K, ~eq, P.apply(K, a, pool, y), x), head(hc))
    case False{}:
      or_mono(P.member(~K, ~eq, t, x), AP(~K, ~eq, pool, x), AP(~K, ~eq, P.apply(K, a, pool, y), x),
        (%mem_miss(~K, ~eq, y, t, x, hc) : {Bool.or(_, AP(~K, ~eq, pool, x)) == True{} : Bool} h),
        f => acc_apply(~K, ~eq, a, pool, y, x, f))

def tt.next(
  ~K: Data, ~eq: K -> K -> Bool, +a: P.Step, +pool: P.Pool<K>, +y: K, +t: List<&2, K>, +x: K,
  h: {Bool.or(P.member(~K, ~eq, y <> t, x), AP(~K, ~eq, pool, x)) == True{} : Bool},
  head: {eq(x, y) == True{} : Bool} -> {AP(~K, ~eq, P.apply(K, a, pool, y), x) == True{} : Bool}
) -> {Bool.or(P.member(~K, ~eq, t, x), AP(~K, ~eq, P.apply(K, a, pool, y), x)) == True{} : Bool}:
  tt.next.if(~K, ~eq, eq(x, y), a, pool, y, t, x, {==}, h, head)

def head_skip(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), pool: P.Pool<K>, +y: K, +x: K, hxy: {eq(x, y) == True{} : Bool},
  hv: {Bool.or(Maybe.is_some(&2, P.Status, St(~K, ~eq, Sts(K, pool), y)), P.member(~K, ~eq, Run(K, pool), y)) == True{} : Bool}
) -> {AP(~K, ~eq, pool, x) == True{} : Bool}:
  match pool:
    case P.Pool{+st, +r, +l}:
      %Equal.sym(K, x, y, sound(x, y, hxy)) : {Acp(~K, ~eq, r, st, _) == True{} : Bool}
      or_swap(Maybe.is_some(&2, P.Status, St(~K, ~eq, st, y)), P.member(~K, ~eq, r, y), hv)

def head_mark(~K: Data, ~eq: K -> K -> Bool, +s: P.Status, pool: P.Pool<K>, +y: K, +x: K, hxy: {eq(x, y) == True{} : Bool}) ->
  {AP(~K, ~eq, P.apply(K, P.PMark{s}, pool, y), x) == True{} : Bool}:
  match pool:
    case P.Pool{+st, +r, +l}:
      or_true_r(P.member(~K, ~eq, r, x), Maybe.is_some(&2, P.Status, St(~K, ~eq, P.Entry{y, s} <> st, x)),
        (%Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{y, s} <> st, x), Some{s}, st_hit(~K, ~eq, y, s, st, x, hxy)) :
          {Maybe.is_some(&2, P.Status, _) == True{} : Bool} {==}))

def head_start(~K: Data, ~eq: K -> K -> Bool, pool: P.Pool<K>, +y: K, +x: K, hxy: {eq(x, y) == True{} : Bool}) ->
  {AP(~K, ~eq, P.apply(K, P.PStart{}, pool, y), x) == True{} : Bool}:
  match pool:
    case P.Pool{+st, +r, +l}:
      or_true_l(P.member(~K, ~eq, y <> r, x), Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)), mem_hit(~K, ~eq, y, r, x, hxy))

def IsSome(~K: Data, ~eq: K -> K -> Bool, +pool: P.Pool<K>, +x: K) -> Type:
  {Maybe.is_some(&2, P.Status, St(~K, ~eq, Sts(K, pool), x)) == True{} : Bool}

def tt.at0(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +y: K, +t: List<&2, K>, +x: K, hv: VP(~K, ~eq, g, stale, limit, pool, y, a),
  h: {Bool.or(P.member(~K, ~eq, y <> t, x), AP(~K, ~eq, pool, x)) == True{} : Bool}, hl: {P.le(1n, limit) == True{} : Bool},
  hr: {Run(K, P.par.at(P.Pool<K>, a, u => pool, u => P.par(~K, ~eq, Nil{}, t, g, stale, limit, P.apply(K, a, pool, y)))) == Nil{} : List<&2, K>},
  ih: @q: P.Pool<K> -> {Bool.or(P.member(~K, ~eq, t, x), AP(~K, ~eq, q, x)) == True{} : Bool} ->
    {Run(K, PAR(~K, ~eq, Nil{}, t, g, stale, limit, q)) == Nil{} : List<&2, K>} -> IsSome(~K, ~eq, PAR(~K, ~eq, Nil{}, t, g, stale, limit, q), x)
) -> IsSome(~K, ~eq, P.par.at(P.Pool<K>, a, u => pool, u => P.par(~K, ~eq, Nil{}, t, g, stale, limit, P.apply(K, a, pool, y))), x):
  match a:
    case P.PWait{}:
      Empty.absurd(IsSome(~K, ~eq, pool, x), hv(hl, hr))
    case P.PSkip{}:
      ih(P.apply(K, P.PSkip{}, pool, y), tt.next(~K, ~eq, P.PSkip{}, pool, y, t, x, h, hxy => head_skip(~K, ~eq, ~sound, pool, y, x, hxy, hv)), hr)
    case P.PMark{+s}:
      ih(P.apply(K, P.PMark{s}, pool, y), tt.next(~K, ~eq, P.PMark{s}, pool, y, t, x, h, hxy => head_mark(~K, ~eq, s, pool, y, x, hxy)), hr)
    case P.PStart{}:
      ih(P.apply(K, P.PStart{}, pool, y), tt.next(~K, ~eq, P.PStart{}, pool, y, t, x, h, hxy => head_start(~K, ~eq, pool, y, x, hxy)), hr)

def tt.at1(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), a: P.Step, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat,
  +pool: P.Pool<K>, +e: P.Fin<K>, +r: List<&2, P.Fin<K>>, +y: K, +t: List<&2, K>, +x: K, hv: VP(~K, ~eq, g, stale, limit, pool, y, a),
  h: {Bool.or(P.member(~K, ~eq, y <> t, x), AP(~K, ~eq, pool, x)) == True{} : Bool},
  hr: {Run(K, P.par.at(P.Pool<K>, a,
    u => P.par(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)),
    u => P.par(~K, ~eq, e <> r, t, g, stale, limit, P.apply(K, a, pool, y)))) == Nil{} : List<&2, K>},
  ihw: {Bool.or(P.member(~K, ~eq, y <> t, x), AP(~K, ~eq, P.finish(~K, ~eq, pool, e), x)) == True{} : Bool} ->
    {Run(K, PAR(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e))) == Nil{} : List<&2, K>} ->
    IsSome(~K, ~eq, PAR(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)), x),
  ih: @q: P.Pool<K> -> {Bool.or(P.member(~K, ~eq, t, x), AP(~K, ~eq, q, x)) == True{} : Bool} ->
    {Run(K, PAR(~K, ~eq, e <> r, t, g, stale, limit, q)) == Nil{} : List<&2, K>} -> IsSome(~K, ~eq, PAR(~K, ~eq, e <> r, t, g, stale, limit, q), x)
) -> IsSome(~K, ~eq, P.par.at(P.Pool<K>, a,
    u => P.par(~K, ~eq, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)),
    u => P.par(~K, ~eq, e <> r, t, g, stale, limit, P.apply(K, a, pool, y))), x):
  match a:
    case P.PWait{}:
      ihw(or_mono(P.member(~K, ~eq, y <> t, x), AP(~K, ~eq, pool, x), AP(~K, ~eq, P.finish(~K, ~eq, pool, e), x), h,
        f => acc_finish(~K, ~eq, ~sound, ~refl, pool, e, x, f)), hr)
    case P.PSkip{}:
      ih(P.apply(K, P.PSkip{}, pool, y), tt.next(~K, ~eq, P.PSkip{}, pool, y, t, x, h, hxy => head_skip(~K, ~eq, ~sound, pool, y, x, hxy, hv)), hr)
    case P.PMark{+s}:
      ih(P.apply(K, P.PMark{s}, pool, y), tt.next(~K, ~eq, P.PMark{s}, pool, y, t, x, h, hxy => head_mark(~K, ~eq, s, pool, y, x, hxy)), hr)
    case P.PStart{}:
      ih(P.apply(K, P.PStart{}, pool, y), tt.next(~K, ~eq, P.PStart{}, pool, y, t, x, h, hxy => head_start(~K, ~eq, pool, y, x, hxy)), hr)

# A run that ends with nothing running has given a status to each node it accounted for.
def par_tt(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), es: List<&2, P.Fin<K>>, p: List<&2, K>,
  +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, +x: K,
  h: {Bool.or(P.member(~K, ~eq, p, x), AP(~K, ~eq, pool, x)) == True{} : Bool}, +hl: {P.le(1n, limit) == True{} : Bool},
  hr: {Run(K, PAR(~K, ~eq, es, p, g, stale, limit, pool)) == Nil{} : List<&2, K>}
) -> IsSome(~K, ~eq, PAR(~K, ~eq, es, p, g, stale, limit, pool), x):
  match es:
    case Nil{}:
      match p:
        case Nil{}:
          (%hr : {Bool.or(P.member(~K, ~eq, _, x), Maybe.is_some(&2, P.Status, St(~K, ~eq, Sts(K, pool), x))) == True{} : Bool} h)
        case Con{+y, +t}:
          tt.at0(~K, ~eq, ~sound, P.decide.par(~K, ~eq, g, stale, limit, pool, y), g, stale, limit, pool, y, t, x,
            view.par(~K, ~eq, g, stale, limit, pool, y), h, hl, hr,
            q => h1 => h2 => par_tt(~K, ~eq, ~sound, ~refl, Nil{}, t, g, stale, limit, q, x, h1, hl, h2))
    case Con{+e, +r}:
      match p:
        case Nil{}:
          par_tt(~K, ~eq, ~sound, ~refl, r, Nil{}, g, stale, limit, P.finish(~K, ~eq, pool, e), x, acc_finish(~K, ~eq, ~sound, ~refl, pool, e, x, h), hl, hr)
        case Con{+y, +t}:
          tt.at1(~K, ~eq, ~sound, ~refl, P.decide.par(~K, ~eq, g, stale, limit, pool, y), g, stale, limit, pool, e, r, y, t, x,
            view.par(~K, ~eq, g, stale, limit, pool, y), h, hr,
            h1 => h2 => par_tt(~K, ~eq, ~sound, ~refl, r, y <> t, g, stale, limit, P.finish(~K, ~eq, pool, e), x, h1, hl, h2),
            q => h1 => h2 => par_tt(~K, ~eq, ~sound, ~refl, e <> r, t, g, stale, limit, q, x, h1, hl, h2))

# Parallel execution: laws
# ------------------------

def P0(-K: Data) -> P.Pool<K>:
  P.Pool{Nil{}, Nil{}, Nil{}}

def gab.sel(~K: Data, ~eq: K -> K -> Bool, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, +x: K, +ds: List<&2, K>, h: GAB(~K, ~eq, stale, limit, pool, x, ds)) ->
  {P.selected.at(St(~K, ~eq, Sts(K, pool), x)) == True{} : Bool} -> {P.ready(~K, ~eq, ds, Sts(K, pool)) == True{} : Bool}:
  (ga, gb) = h
  (b1, q) = gb
  b1

def gab.run(~K: Data, ~eq: K -> K -> Bool, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>, +x: K, +ds: List<&2, K>, h: GAB(~K, ~eq, stale, limit, pool, x, ds)) ->
  {Bool.or(Bool.not(P.member(~K, ~eq, Run(K, pool), x)), P.ready(~K, ~eq, ds, Sts(K, pool))) == True{} : Bool}:
  (ga, gb) = h
  (b1, q) = gb
  (b2, b3) = q
  b2

def gab0(~K: Data, ~eq: K -> K -> Bool, +stale: List<&2, K>, +limit: Nat, +x: K, +ds: List<&2, K>) -> GAB(~K, ~eq, stale, limit, P0(K), x, ds):
  ({==}, (hs => Empty.absurd({P.ready(~K, ~eq, ds, Nil{}) == True{} : Bool}, false_ne_true(hs)),
    ({==}, hf => Empty.absurd({P.member(~K, ~eq, stale, x) == False{} : Bool}, none_ne_some(P.Status, P.Fresh{}, hf)))))

def run_gab(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), es: List<&2, P.Fin<K>>, p: List<&2, K>,
  +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +x: K, +ds: List<&2, K>, +hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}
) -> GAB(~K, ~eq, stale, limit, Laws.prun(~K, ~eq, es, p, g, stale, limit), x, ds):
  par_gab(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit, P0(K), x, ds, hd, gab0(~K, ~eq, stale, limit, x, ds))

def run_ga(~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), es: List<&2, P.Fin<K>>, p: List<&2, K>,
  +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat
) -> GA(~K, ~eq, limit, Laws.prun(~K, ~eq, es, p, g, stale, limit)):
  par_ga(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit, P0(K), {==})

def Laws.par_ready(K, eq, sound, refl, es, p, g, stale, limit, x, ds, hx, hd):
  +es = es
  +p = p
  +g = g
  +stale = stale
  +limit = limit
  +x = x
  +ds = ds
  gab.sel(~K, ~eq, stale, limit, Laws.prun(~K, ~eq, es, p, g, stale, limit), x, ds, run_gab(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit, x, ds, hd))(hx)

def Laws.par_running(K, eq, sound, refl, es, p, g, stale, limit, x, ds, hx, hd):
  +es = es
  +p = p
  +g = g
  +stale = stale
  +limit = limit
  +x = x
  +ds = ds
  +f = Laws.prun(~K, ~eq, es, p, g, stale, limit)
  imp_true(P.member(~K, ~eq, Run(K, f), x), P.ready(~K, ~eq, ds, Sts(K, f)), hx,
    gab.run(~K, ~eq, stale, limit, f, x, ds, run_gab(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit, x, ds, hd)))

def par_blocked.if(
  ~K: Data, ~eq: K -> K -> Bool, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), b: Bool, +es: List<&2, P.Fin<K>>, +p: List<&2, K>,
  +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +x: K, +ds: List<&2, K>, +d: K,
  hb: {P.ok.at(St(~K, ~eq, Sts(K, Laws.prun(~K, ~eq, es, p, g, stale, limit)), x)) == b : Bool},
  hd: {P.deps(~K, ~eq, g, x) == Some{ds} : Maybe<&2, List<&2, K>>}, hm: {P.member(~K, ~eq, ds, d) == True{} : Bool},
  hf: {P.ok.at(St(~K, ~eq, Sts(K, Laws.prun(~K, ~eq, es, p, g, stale, limit)), d)) == False{} : Bool}
) -> {b == False{} : Bool}:
  match b:
    case True{}:
      +f = Sts(K, Laws.prun(~K, ~eq, es, p, g, stale, limit))
      Empty.absurd({True{} == False{} : Bool},
        clash(P.ok.at(St(~K, ~eq, f, d)),
          ready_mem(~K, ~eq, ~sound, ds, f, d,
            Laws.par_ready(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit, x, ds, ok_sel(St(~K, ~eq, f, x), hb), hd), hm),
          hf))
    case False{}:
      {==}

def Laws.par_blocked(K, eq, sound, refl, es, p, g, stale, limit, x, ds, d, hd, hm, hf):
  +es = es
  +p = p
  +g = g
  +stale = stale
  +limit = limit
  +x = x
  par_blocked.if(~K, ~eq, ~sound, ~refl, P.ok.at(St(~K, ~eq, Sts(K, Laws.prun(~K, ~eq, es, p, g, stale, limit)), x)), es, p, g, stale, limit, x, ds, d,
    {==}, hd, hm, hf)

def Laws.par_once(K, eq, sound, refl, es, p, g, stale, limit):
  +es = es
  +p = p
  +g = g
  +stale = stale
  +limit = limit
  +f = Laws.prun(~K, ~eq, es, p, g, stale, limit)
  ga3(~K, ~eq, limit, Sts(K, f), Run(K, f), Log(K, f), run_ga(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit))

def Laws.par_once_status(K, eq, sound, refl, es, p, g, stale, limit):
  +es = es
  +p = p
  +g = g
  +stale = stale
  +limit = limit
  +f = Laws.prun(~K, ~eq, es, p, g, stale, limit)
  ga2(~K, ~eq, limit, Sts(K, f), Run(K, f), Log(K, f), run_ga(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit))

def Laws.par_limit(K, eq, sound, refl, es, p, g, stale, limit):
  +es = es
  +p = p
  +g = g
  +stale = stale
  +limit = limit
  +f = Laws.prun(~K, ~eq, es, p, g, stale, limit)
  ga5(~K, ~eq, limit, Sts(K, f), Run(K, f), Log(K, f), run_ga(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit))

def Laws.par_fresh(K, eq, sound, refl, es, p, g, stale, limit, x, hx):
  +x = x
  +stale = stale
  par_gf(~K, ~eq, ~sound, es, p, g, stale, limit, P0(K), x,
    hf => Empty.absurd({P.member(~K, ~eq, stale, x) == False{} : Bool}, none_ne_some(P.Status, P.Fresh{}, hf)))(hx)

def Laws.par_total(K, eq, sound, refl, es, p, g, stale, limit, x, hl, hr, hx):
  +p = p
  +x = x
  par_tt(~K, ~eq, ~sound, ~refl, es, p, g, stale, limit, P0(K), x,
    or_true_l(P.member(~K, ~eq, p, x), AP(~K, ~eq, P0(K), x), hx), hl, hr)

# Indexes
# -------

def CRefl(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> {cmp(x, x) == EQ{} : Cmp}

def CEq(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}

def CFlip(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> {cmp(y, x) == Col.flip(cmp(x, y)) : Cmp}

def CTrans(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}

def Agree(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool) -> Type:
  @x: K -> @y: K -> {eq(x, y) == Cmp.is_eq(cmp(x, y)) : Bool}

def is_eq_true(c: Cmp, h: {Cmp.is_eq(c) == True{} : Bool}) -> {c == EQ{} : Cmp}:
  match c:
    case LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, false_ne_true(h))
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, false_ne_true(h))

def sound_of(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~ceq: CEq(~K, ~cmp), ~agree: Agree(~K, ~cmp, ~eq), +x: K, +y: K,
  h: {eq(x, y) == True{} : Bool}
) -> {x == y : K}:
  ceq(x, y, is_eq_true(cmp(x, y), Equal.trans(Bool, Cmp.is_eq(cmp(x, y)), eq(x, y), True{}, Equal.sym(Bool, eq(x, y), Cmp.is_eq(cmp(x, y)), agree(x, y)), h)))

def refl_of(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~agree: Agree(~K, ~cmp, ~eq), +x: K) ->
  {eq(x, x) == True{} : Bool}:
  %Equal.sym(Bool, eq(x, x), Cmp.is_eq(cmp(x, x)), agree(x, x)) : {_ == True{} : Bool}
  %Equal.sym(Cmp, cmp(x, x), EQ{}, crefl(x)) : {Cmp.is_eq(_) == True{} : Bool}
  {==}

# eq(k, x) is false, so cmp(x, k) is not EQ.
def ne_of_false(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~agree: Agree(~K, ~cmp, ~eq), +k: K, +x: K,
  h: {eq(k, x) == False{} : Bool}
) -> {cmp(x, k) == EQ{} : Cmp} -> Empty:
  e => clash(eq(k, x), (%Equal.sym(K, x, k, ceq(x, k, e)) : {eq(k, _) == True{} : Bool} refl_of(~K, ~cmp, ~eq, ~crefl, ~agree, k)), h)

def ST(~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: OMap.OMap<K, V>) -> Bool:
  Col.searchtree(~K, ~V, ~cmp, m)

def idx_tree(~K: Data, ~cmp: K -> K -> Cmp, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  xs: List<&2, K>
) -> {ST(~K, ~Unit, ~cmp, P.idx(~K, ~cmp, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      Col.omap_new_searchtree(~K, ~Unit, ~cmp)
    case Con{+x, +t}:
      Col.omap_put_searchtree(~K, ~Unit, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, P.idx(~K, ~cmp, t),
        idx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t), x, Unit{})

def gidx_tree(~K: Data, ~cmp: K -> K -> Cmp, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  g: List<&2, P.Node<K>>
) -> {ST(~K, ~List<&2, K>, ~cmp, P.gidx(~K, ~cmp, g)) == True{} : Bool}:
  match g:
    case Nil{}:
      Col.omap_new_searchtree(~K, ~List<&2, K>, ~cmp)
    case Con{P.Node{+id, +ds}, +t}:
      Col.omap_put_searchtree(~K, ~List<&2, K>, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, P.gidx(~K, ~cmp, t),
        gidx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t), id, ds)

def IHas(~K: Data, ~cmp: K -> K -> Cmp, +s: OMap.OSet(K), +k: K) -> Bool:
  OMap.OSet.has(~K, ~cmp, s, k)

def ihas.if(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), c: Bool, +x: K, +t: List<&2, K>, +k: K,
  +hc: {eq(k, x) == c : Bool}, ih: {IHas(~K, ~cmp, P.idx(~K, ~cmp, t), k) == P.member(~K, ~eq, t, k) : Bool}
) -> {IHas(~K, ~cmp, P.idx(~K, ~cmp, x <> t), k) == P.member(~K, ~eq, x <> t, k) : Bool}:
  match c:
    case True{}:
      +m = P.idx(~K, ~cmp, t)
      +tree = idx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t)
      %Equal.sym(Bool, P.member(~K, ~eq, x <> t, k), True{}, mem_hit(~K, ~eq, x, t, k, hc)) : {IHas(~K, ~cmp, P.idx(~K, ~cmp, x <> t), k) == _ : Bool}
      %Equal.sym(K, k, x, sound_of(~K, ~cmp, ~eq, ~ceq, ~agree, k, x, hc)) : {IHas(~K, ~cmp, P.idx(~K, ~cmp, x <> t), _) == True{} : Bool}
      %Equal.sym(Maybe<&2, Unit>, OMap.OMap.get(~K, ~Unit, ~cmp, OMap.OMap.put(~K, ~Unit, ~cmp, m, x, Unit{}), x), Some{Unit{}},
        Col.omap_get_put_same(~K, ~Unit, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, x, Unit{})) : {Maybe.is_some(&2, Unit, _) == True{} : Bool}
      {==}
    case False{}:
      +m = P.idx(~K, ~cmp, t)
      +tree = idx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t)
      %Equal.sym(Bool, P.member(~K, ~eq, x <> t, k), P.member(~K, ~eq, t, k), mem_miss(~K, ~eq, x, t, k, hc)) : {IHas(~K, ~cmp, P.idx(~K, ~cmp, x <> t), k) == _ : Bool}
      %Equal.sym(Maybe<&2, Unit>, OMap.OMap.get(~K, ~Unit, ~cmp, OMap.OMap.put(~K, ~Unit, ~cmp, m, x, Unit{}), k), OMap.OMap.get(~K, ~Unit, ~cmp, m, k),
        Col.omap_get_put_other_key(~K, ~Unit, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, x, k,
          ne_of_false(~K, ~cmp, ~eq, ~crefl, ~ceq, ~agree, k, x, hc), Unit{})) : {Maybe.is_some(&2, Unit, _) == P.member(~K, ~eq, t, k) : Bool}
      ih

# The index of xs has exactly the members of xs.
def ihas(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), xs: List<&2, K>, +k: K
) -> {IHas(~K, ~cmp, P.idx(~K, ~cmp, xs), k) == P.member(~K, ~eq, xs, k) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      ihas.if(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, eq(k, x), x, t, k, {==},
        ihas(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, k))

def GGet(~K: Data, ~cmp: K -> K -> Cmp, +gi: OMap.OMap<K, List<&2, K>>, +k: K) -> Maybe<&2, List<&2, K>>:
  OMap.OMap.get(~K, ~List<&2, K>, ~cmp, gi, k)

def gget.if(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), c: Bool, +id: K, +ds: List<&2, K>, +t: List<&2, P.Node<K>>, +k: K,
  +hc: {eq(k, id) == c : Bool}, ih: {GGet(~K, ~cmp, P.gidx(~K, ~cmp, t), k) == P.deps(~K, ~eq, t, k) : Maybe<&2, List<&2, K>>}
) -> {GGet(~K, ~cmp, P.gidx(~K, ~cmp, P.Node{id, ds} <> t), k) == P.deps(~K, ~eq, P.Node{id, ds} <> t, k) : Maybe<&2, List<&2, K>>}:
  match c:
    case True{}:
      +m = P.gidx(~K, ~cmp, t)
      +tree = gidx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t)
      %Equal.sym(Maybe<&2, List<&2, K>>, P.deps(~K, ~eq, P.Node{id, ds} <> t, k), Some{ds}, deps_hit(~K, ~eq, id, ds, t, k, hc)) :
        {GGet(~K, ~cmp, P.gidx(~K, ~cmp, P.Node{id, ds} <> t), k) == _ : Maybe<&2, List<&2, K>>}
      %Equal.sym(K, k, id, sound_of(~K, ~cmp, ~eq, ~ceq, ~agree, k, id, hc)) : {GGet(~K, ~cmp, P.gidx(~K, ~cmp, P.Node{id, ds} <> t), _) == Some{ds} : Maybe<&2, List<&2, K>>}
      Col.omap_get_put_same(~K, ~List<&2, K>, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, id, ds)
    case False{}:
      +m = P.gidx(~K, ~cmp, t)
      +tree = gidx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t)
      %Equal.sym(Maybe<&2, List<&2, K>>, P.deps(~K, ~eq, P.Node{id, ds} <> t, k), P.deps(~K, ~eq, t, k), deps_miss(~K, ~eq, id, ds, t, k, hc)) :
        {GGet(~K, ~cmp, P.gidx(~K, ~cmp, P.Node{id, ds} <> t), k) == _ : Maybe<&2, List<&2, K>>}
      %Equal.sym(Maybe<&2, List<&2, K>>, GGet(~K, ~cmp, OMap.OMap.put(~K, ~List<&2, K>, ~cmp, m, id, ds), k), GGet(~K, ~cmp, m, k),
        Col.omap_get_put_other_key(~K, ~List<&2, K>, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, id, k,
          ne_of_false(~K, ~cmp, ~eq, ~crefl, ~ceq, ~agree, k, id, hc), ds)) : {_ == P.deps(~K, ~eq, t, k) : Maybe<&2, List<&2, K>>}
      ih

# The graph index finds the prerequisites that deps finds.
def gget(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), g: List<&2, P.Node<K>>, +k: K
) -> {GGet(~K, ~cmp, P.gidx(~K, ~cmp, g), k) == P.deps(~K, ~eq, g, k) : Maybe<&2, List<&2, K>>}:
  match g:
    case Nil{}:
      {==}
    case Con{P.Node{+id, +ds}, +t}:
      gget.if(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, eq(k, id), id, ds, t, k, {==},
        gget(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, k))

# Indexes: the walk
# -----------------

def RW(-K: Data) -> Type:
  Result<&2, &2, P.Error<K>, P.Walk<K>>

def walked(~K: Data, ~cmp: K -> K -> Cmp, r: Result<&2, &2, P.Error<K>, List<&2, K>>) -> Result<&2, &2, P.Error<K>, P.Walk<K>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{+x}:
      Done{P.Walk{x, P.idx(~K, ~cmp, x)}}

def at_eq(
  ~K: Data, ~cmp: K -> K -> Cmp, b1: Bool, b2: Bool, m: Maybe<&2, List<&2, K>>,
  skipL: Unit -> Result<&2, &2, P.Error<K>, P.Walk<K>>, skipR: Unit -> Result<&2, &2, P.Error<K>, List<&2, K>>,
  loopL: Unit -> Result<&2, &2, P.Error<K>, P.Walk<K>>, loopR: Unit -> Result<&2, &2, P.Error<K>, List<&2, K>>,
  missL: Unit -> Result<&2, &2, P.Error<K>, P.Walk<K>>, missR: Unit -> Result<&2, &2, P.Error<K>, List<&2, K>>,
  childL: List<&2, K> -> Result<&2, &2, P.Error<K>, P.Walk<K>>, childR: List<&2, K> -> Result<&2, &2, P.Error<K>, List<&2, K>>,
  es: {skipL(Unit{}) == walked(~K, ~cmp, skipR(Unit{})) : Result<&2, &2, P.Error<K>, P.Walk<K>>},
  el: {loopL(Unit{}) == walked(~K, ~cmp, loopR(Unit{})) : Result<&2, &2, P.Error<K>, P.Walk<K>>},
  em: {missL(Unit{}) == walked(~K, ~cmp, missR(Unit{})) : Result<&2, &2, P.Error<K>, P.Walk<K>>},
  ec: @dd: List<&2, K> -> {childL(dd) == walked(~K, ~cmp, childR(dd)) : Result<&2, &2, P.Error<K>, P.Walk<K>>}
) -> {P.fast.at(K, Result<&2, &2, P.Error<K>, P.Walk<K>>, b1, b2, m, skipL, loopL, missL, childL)
      == walked(~K, ~cmp, P.go.at(K, Result<&2, &2, P.Error<K>, List<&2, K>>, b1, u => b2, u => m, skipR, loopR, missR, childR))
      : Result<&2, &2, P.Error<K>, P.Walk<K>>}:
  match b1:
    case True{}:
      es
    case False{}:
      match b2:
        case True{}:
          el
        case False{}:
          match m:
            case None{}:
              em
            case Some{dd}:
              ec(dd)

def then_eq(
  ~K: Data, ~cmp: K -> K -> Cmp, r: Result<&2, &2, P.Error<K>, List<&2, K>>,
  kL: List<&2, K> -> OMap.OSet(K) -> Result<&2, &2, P.Error<K>, P.Walk<K>>, kR: List<&2, K> -> Result<&2, &2, P.Error<K>, List<&2, K>>,
  hk: @x: List<&2, K> -> {kL(x)(P.idx(~K, ~cmp, x)) == walked(~K, ~cmp, kR(x)) : Result<&2, &2, P.Error<K>, P.Walk<K>>}
) -> {P.fast.then(K, walked(~K, ~cmp, r), kL) == walked(~K, ~cmp, P.go.then(K, r, kR)) : Result<&2, &2, P.Error<K>, P.Walk<K>>}:
  match r:
    case Fail{e}:
      {==}
    case Done{x}:
      hk(x)

def FGO(~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, fuel: Nat, ds: List<&2, K>, +g: List<&2, P.Node<K>>, +path: List<&2, K>, +done: List<&2, K>) -> Result<&2, &2, P.Error<K>, P.Walk<K>>:
  P.go.fast(~K, ~eq, ~cmp, fuel, ds, P.gidx(~K, ~cmp, g), path, P.idx(~K, ~cmp, path), done, P.idx(~K, ~cmp, done))

def out_eq(~K: Data, ~cmp: K -> K -> Cmp, ds: List<&2, K>, +done: List<&2, K>) ->
  {P.fast.out(K, ds, done, P.idx(~K, ~cmp, done)) == walked(~K, ~cmp, P.go.out(K, ds, done)) : Result<&2, &2, P.Error<K>, P.Walk<K>>}:
  match ds:
    case Nil{}:
      {==}
    case Con{d, t}:
      {==}

# The indexed walk answers as the list walk.
def go_fast_eq(
  ~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), fuel: Nat, ds: List<&2, K>, +g: List<&2, P.Node<K>>, +path: List<&2, K>, +done: List<&2, K>
) -> {FGO(~K, ~eq, ~cmp, fuel, ds, g, path, done) == walked(~K, ~cmp, P.go(~K, ~eq, fuel, ds, g, path, done)) : Result<&2, &2, P.Error<K>, P.Walk<K>>}:
  match fuel:
    case 0n:
      out_eq(~K, ~cmp, ds, done)
    case 1n+(+f):
      match ds:
        case Nil{}:
          {==}
        case Con{+d, +rest}:
          +gi = P.gidx(~K, ~cmp, g)
          +pi = P.idx(~K, ~cmp, path)
          +di = P.idx(~K, ~cmp, done)
          %Equal.sym(Bool, IHas(~K, ~cmp, P.idx(~K, ~cmp, done), d), P.member(~K, ~eq, done, d), ihas(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, done, d)) :
            {P.fast.at(K, RW(K), _, IHas(~K, ~cmp, pi, d), GGet(~K, ~cmp, gi, d),
               u => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, done, di),
               u => Fail{P.cycle(~K, ~eq, path, d)},
               u => Fail{P.Missing{d, P.rev(K, path, Nil{})}},
               dd => P.fast.then(K, P.go.fast(~K, ~eq, ~cmp, f, dd, gi, d <> path, OMap.OSet.add(~K, ~cmp, pi, d), done, di),
                 x => xi => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, d <> x, OMap.OSet.add(~K, ~cmp, xi, d))))
             == walked(~K, ~cmp, P.go(~K, ~eq, 1n+f, d <> rest, g, path, done)) : RW(K)}
          %Equal.sym(Bool, IHas(~K, ~cmp, P.idx(~K, ~cmp, path), d), P.member(~K, ~eq, path, d), ihas(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, path, d)) :
            {P.fast.at(K, RW(K), P.member(~K, ~eq, done, d), _, GGet(~K, ~cmp, gi, d),
               u => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, done, di),
               u => Fail{P.cycle(~K, ~eq, path, d)},
               u => Fail{P.Missing{d, P.rev(K, path, Nil{})}},
               dd => P.fast.then(K, P.go.fast(~K, ~eq, ~cmp, f, dd, gi, d <> path, OMap.OSet.add(~K, ~cmp, pi, d), done, di),
                 x => xi => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, d <> x, OMap.OSet.add(~K, ~cmp, xi, d))))
             == walked(~K, ~cmp, P.go(~K, ~eq, 1n+f, d <> rest, g, path, done)) : RW(K)}
          %Equal.sym(Maybe<&2, List<&2, K>>, GGet(~K, ~cmp, P.gidx(~K, ~cmp, g), d), P.deps(~K, ~eq, g, d), gget(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, g, d)) :
            {P.fast.at(K, RW(K), P.member(~K, ~eq, done, d), P.member(~K, ~eq, path, d), _,
               u => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, done, di),
               u => Fail{P.cycle(~K, ~eq, path, d)},
               u => Fail{P.Missing{d, P.rev(K, path, Nil{})}},
               dd => P.fast.then(K, P.go.fast(~K, ~eq, ~cmp, f, dd, gi, d <> path, OMap.OSet.add(~K, ~cmp, pi, d), done, di),
                 x => xi => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, d <> x, OMap.OSet.add(~K, ~cmp, xi, d))))
             == walked(~K, ~cmp, P.go(~K, ~eq, 1n+f, d <> rest, g, path, done)) : RW(K)}
          at_eq(~K, ~cmp, P.member(~K, ~eq, done, d), P.member(~K, ~eq, path, d), P.deps(~K, ~eq, g, d),
            u => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, done, di),
            u => P.go(~K, ~eq, 1n+f, rest, g, path, done),
            u => Fail{P.cycle(~K, ~eq, path, d)},
            u => Fail{P.cycle(~K, ~eq, path, d)},
            u => Fail{P.Missing{d, P.rev(K, path, Nil{})}},
            u => Fail{P.Missing{d, P.rev(K, path, Nil{})}},
            dd => P.fast.then(K, P.go.fast(~K, ~eq, ~cmp, f, dd, gi, d <> path, OMap.OSet.add(~K, ~cmp, pi, d), done, di),
              x => xi => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, d <> x, OMap.OSet.add(~K, ~cmp, xi, d))),
            dd => P.go.then(K, P.go(~K, ~eq, f, dd, g, d <> path, done), r => P.go(~K, ~eq, 1n+f, rest, g, path, d <> r)),
            go_fast_eq(~K, ~eq, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, 1n+f, rest, g, path, done),
            {==}, {==},
            +dd => (%Equal.sym(RW(K), FGO(~K, ~eq, ~cmp, f, dd, g, d <> path, done), walked(~K, ~cmp, P.go(~K, ~eq, f, dd, g, d <> path, done)), go_fast_eq(~K, ~eq, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, f, dd, g, d <> path, done)) :
                {P.fast.then(K, _, x => xi => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, d <> x, OMap.OSet.add(~K, ~cmp, xi, d)))
                 == walked(~K, ~cmp, P.go.then(K, P.go(~K, ~eq, f, dd, g, d <> path, done), r => P.go(~K, ~eq, 1n+f, rest, g, path, d <> r))) : RW(K)}
              then_eq(~K, ~cmp, P.go(~K, ~eq, f, dd, g, d <> path, done),
                x => xi => P.go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, d <> x, OMap.OSet.add(~K, ~cmp, xi, d)),
                r => P.go(~K, ~eq, 1n+f, rest, g, path, d <> r),
                x => go_fast_eq(~K, ~eq, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, 1n+f, rest, g, path, d <> x))))

def fin_eq(
  ~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, ~sound: Sound(~K, ~eq), ~refl: Refl(~K, ~eq), r: Result<&2, &2, P.Error<K>, List<&2, K>>,
  +g: List<&2, P.Node<K>>, +ts: List<&2, K>, hg: Good(~K, ~eq, g, ts, ts, Nil{}, Nil{}, r)
) -> {P.plan.fast.fin(K, walked(~K, ~cmp, r)) == P.plan.check(~K, ~eq, g, ts, r) : Result<&2, &2, P.Error<K>, List<&2, K>>}:
  match r:
    case Fail{e}:
      {==}
    case Done{+x}:
      +p = P.rev(K, x, Nil{})
      %Equal.sym(Bool, P.valid(~K, ~eq, g, ts, p), True{}, valid_of_post(~K, ~eq, ~sound, ~refl, g, ts, x, hg)) : {Done{p} == P.plan.ok(K, _, p) : Result<&2, &2, P.Error<K>, List<&2, K>>}
      {==}

def Laws.plan_index(K, eq, cmp, crefl, ceq, cflip, ctrans, agree, g, ts):
  +g = g
  +ts = ts
  +r = P.go(~K, ~eq, 1n+Len(K, g), ts, g, Nil{}, Nil{})
  %Equal.sym(RW(K), FGO(~K, ~eq, ~cmp, 1n+Len(K, g), ts, g, Nil{}, Nil{}), walked(~K, ~cmp, r), go_fast_eq(~K, ~eq, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, 1n+Len(K, g), ts, g, Nil{}, Nil{})) :
    {P.plan.fast.fin(K, _) == P.plan(~K, ~eq, g, ts) : Result<&2, &2, P.Error<K>, List<&2, K>>}
  fin_eq(~K, ~eq, ~cmp, ~(x => y => h => sound_of(~K, ~cmp, ~eq, ~ceq, ~agree, x, y, h)), ~(x => refl_of(~K, ~cmp, ~eq, ~crefl, ~agree, x)), r, g, ts,
    plan_good(~K, ~eq, ~(x => y => h => sound_of(~K, ~cmp, ~eq, ~ceq, ~agree, x, y, h)), ~(x => refl_of(~K, ~cmp, ~eq, ~crefl, ~agree, x)), g, ts))

# Indexes: invalidation
# ---------------------

def any_fast(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), xs: List<&2, K>, +acc: List<&2, K>
) -> {P.any_in.fast(~K, ~cmp, xs, P.idx(~K, ~cmp, acc)) == P.any_in(~K, ~eq, xs, acc) : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      %Equal.sym(Bool, IHas(~K, ~cmp, P.idx(~K, ~cmp, acc), x), P.member(~K, ~eq, acc, x), ihas(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, acc, x)) :
        {Bool.or(_, P.any_in.fast(~K, ~cmp, t, P.idx(~K, ~cmp, acc))) == Bool.or(P.member(~K, ~eq, acc, x), P.any_in(~K, ~eq, t, acc)) : Bool}
      %Equal.sym(Bool, P.any_in.fast(~K, ~cmp, t, P.idx(~K, ~cmp, acc)), P.any_in(~K, ~eq, t, acc), any_fast(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, acc)) :
        {Bool.or(P.member(~K, ~eq, acc, x), _) == Bool.or(P.member(~K, ~eq, acc, x), P.any_in(~K, ~eq, t, acc)) : Bool}
      {==}

def idx_if(~K: Data, ~cmp: K -> K -> Cmp, c: Bool, +x: K, +acc: List<&2, K>) ->
  {P.idx.if(~K, ~cmp, c, x, P.idx(~K, ~cmp, acc)) == P.idx(~K, ~cmp, P.invalidate.if(K, c, x, acc)) : OMap.OSet(K)}:
  match c:
    case True{}:
      {==}
    case False{}:
      {==}

def inv_fast_eq(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), p: List<&2, K>, +g: List<&2, P.Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>
) -> {P.invalidate.fast.go(~K, ~cmp, p, P.gidx(~K, ~cmp, g), P.idx(~K, ~cmp, changed), acc, P.idx(~K, ~cmp, acc))
      == P.invalidate.go(~K, ~eq, p, g, changed, acc) : List<&2, K>}:
  match p:
    case Nil{}:
      {==}
    case Con{+x, +t}:
      +gi = P.gidx(~K, ~cmp, g)
      +ci = P.idx(~K, ~cmp, changed)
      +dn = P.deps.or_nil(~K, ~eq, g, x)
      +hit = Bool.or(P.member(~K, ~eq, changed, x), P.any_in(~K, ~eq, dn, acc))
      +hdeps = Equal.cong(Maybe<&2, List<&2, K>>, List<&2, K>, m => Maybe.default(&2, List<&2, K>, m, Nil{}),
        GGet(~K, ~cmp, gi, x), P.deps(~K, ~eq, g, x), gget(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, g, x))
      %Equal.sym(Bool, IHas(~K, ~cmp, P.idx(~K, ~cmp, changed), x), P.member(~K, ~eq, changed, x), ihas(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, changed, x)) :
        {P.invalidate.fast.go(~K, ~cmp, t, gi, ci,
           P.invalidate.if(K, Bool.or(_, P.any_in.fast(~K, ~cmp, P.deps.fast(~K, ~cmp, gi, x), P.idx(~K, ~cmp, acc))), x, acc),
           P.idx.if(~K, ~cmp, Bool.or(_, P.any_in.fast(~K, ~cmp, P.deps.fast(~K, ~cmp, gi, x), P.idx(~K, ~cmp, acc))), x, P.idx(~K, ~cmp, acc)))
         == P.invalidate.go(~K, ~eq, x <> t, g, changed, acc) : List<&2, K>}
      %Equal.sym(List<&2, K>, P.deps.fast(~K, ~cmp, gi, x), dn, hdeps) :
        {P.invalidate.fast.go(~K, ~cmp, t, gi, ci,
           P.invalidate.if(K, Bool.or(P.member(~K, ~eq, changed, x), P.any_in.fast(~K, ~cmp, _, P.idx(~K, ~cmp, acc))), x, acc),
           P.idx.if(~K, ~cmp, Bool.or(P.member(~K, ~eq, changed, x), P.any_in.fast(~K, ~cmp, _, P.idx(~K, ~cmp, acc))), x, P.idx(~K, ~cmp, acc)))
         == P.invalidate.go(~K, ~eq, x <> t, g, changed, acc) : List<&2, K>}
      %Equal.sym(Bool, P.any_in.fast(~K, ~cmp, dn, P.idx(~K, ~cmp, acc)), P.any_in(~K, ~eq, dn, acc), any_fast(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, dn, acc)) :
        {P.invalidate.fast.go(~K, ~cmp, t, gi, ci,
           P.invalidate.if(K, Bool.or(P.member(~K, ~eq, changed, x), _), x, acc),
           P.idx.if(~K, ~cmp, Bool.or(P.member(~K, ~eq, changed, x), _), x, P.idx(~K, ~cmp, acc)))
         == P.invalidate.go(~K, ~eq, x <> t, g, changed, acc) : List<&2, K>}
      %Equal.sym(OMap.OSet(K), P.idx.if(~K, ~cmp, hit, x, P.idx(~K, ~cmp, acc)), P.idx(~K, ~cmp, P.invalidate.if(K, hit, x, acc)), idx_if(~K, ~cmp, hit, x, acc)) :
        {P.invalidate.fast.go(~K, ~cmp, t, gi, ci, P.invalidate.if(K, hit, x, acc), _) == P.invalidate.go(~K, ~eq, x <> t, g, changed, acc) : List<&2, K>}
      inv_fast_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, g, changed, P.invalidate.if(K, hit, x, acc))

def Laws.stale_index(K, eq, cmp, crefl, ceq, cflip, ctrans, agree, p, g, changed):
  inv_fast_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, p, g, changed, Nil{})

# Indexes: parallel execution
# ---------------------------

def sidx_tree(~K: Data, ~cmp: K -> K -> Cmp, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  st: List<&2, P.Entry<K>>
) -> {ST(~K, ~P.Status, ~cmp, P.sidx(~K, ~cmp, st)) == True{} : Bool}:
  match st:
    case Nil{}:
      Col.omap_new_searchtree(~K, ~P.Status, ~cmp)
    case Con{P.Entry{+x, +s}, +t}:
      Col.omap_put_searchtree(~K, ~P.Status, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, P.sidx(~K, ~cmp, t),
        sidx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t), x, s)

def SGet(~K: Data, ~cmp: K -> K -> Cmp, +si: OMap.OMap<K, P.Status>, +k: K) -> Maybe<&2, P.Status>:
  OMap.OMap.get(~K, ~P.Status, ~cmp, si, k)

def sget.if(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), c: Bool, +x: K, +s: P.Status, +t: List<&2, P.Entry<K>>, +k: K,
  +hc: {eq(k, x) == c : Bool}, ih: {SGet(~K, ~cmp, P.sidx(~K, ~cmp, t), k) == St(~K, ~eq, t, k) : Maybe<&2, P.Status>}
) -> {SGet(~K, ~cmp, P.sidx(~K, ~cmp, P.Entry{x, s} <> t), k) == St(~K, ~eq, P.Entry{x, s} <> t, k) : Maybe<&2, P.Status>}:
  match c:
    case True{}:
      +m = P.sidx(~K, ~cmp, t)
      +tree = sidx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t)
      %Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{x, s} <> t, k), Some{s}, st_hit(~K, ~eq, x, s, t, k, hc)) :
        {SGet(~K, ~cmp, P.sidx(~K, ~cmp, P.Entry{x, s} <> t), k) == _ : Maybe<&2, P.Status>}
      %Equal.sym(K, k, x, sound_of(~K, ~cmp, ~eq, ~ceq, ~agree, k, x, hc)) : {SGet(~K, ~cmp, P.sidx(~K, ~cmp, P.Entry{x, s} <> t), _) == Some{s} : Maybe<&2, P.Status>}
      Col.omap_get_put_same(~K, ~P.Status, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, x, s)
    case False{}:
      +m = P.sidx(~K, ~cmp, t)
      +tree = sidx_tree(~K, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, t)
      %Equal.sym(Maybe<&2, P.Status>, St(~K, ~eq, P.Entry{x, s} <> t, k), St(~K, ~eq, t, k), st_miss(~K, ~eq, x, s, t, k, hc)) :
        {SGet(~K, ~cmp, P.sidx(~K, ~cmp, P.Entry{x, s} <> t), k) == _ : Maybe<&2, P.Status>}
      %Equal.sym(Maybe<&2, P.Status>, SGet(~K, ~cmp, OMap.OMap.put(~K, ~P.Status, ~cmp, m, x, s), k), SGet(~K, ~cmp, m, k),
        Col.omap_get_put_other_key(~K, ~P.Status, ~cmp, ~crefl, ~ceq, ~cflip, ~ctrans, m, tree, x, k,
          ne_of_false(~K, ~cmp, ~eq, ~crefl, ~ceq, ~agree, k, x, hc), s)) : {_ == St(~K, ~eq, t, k) : Maybe<&2, P.Status>}
      ih

# The status index finds the status that status finds.
def sget(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), st: List<&2, P.Entry<K>>, +k: K) -> {SGet(~K, ~cmp, P.sidx(~K, ~cmp, st), k) == St(~K, ~eq, st, k) : Maybe<&2, P.Status>}:
  match st:
    case Nil{}:
      {==}
    case Con{P.Entry{+x, +s}, +t}:
      sget.if(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, eq(k, x), x, s, t, k, {==}, sget(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, k))

def ready_fast(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), ds: List<&2, K>, +st: List<&2, P.Entry<K>>) ->
  {P.ready.fast(~K, ~cmp, ds, P.sidx(~K, ~cmp, st)) == P.ready(~K, ~eq, ds, st) : Bool}:
  match ds:
    case Nil{}:
      {==}
    case Con{+d, +t}:
      %Equal.sym(Maybe<&2, P.Status>, SGet(~K, ~cmp, P.sidx(~K, ~cmp, st), d), St(~K, ~eq, st, d), sget(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, st, d)) :
        {Bool.and(P.ok.at(_), P.ready.fast(~K, ~cmp, t, P.sidx(~K, ~cmp, st))) == Bool.and(P.ok.at(St(~K, ~eq, st, d)), P.ready(~K, ~eq, t, st)) : Bool}
      %Equal.sym(Bool, P.ready.fast(~K, ~cmp, t, P.sidx(~K, ~cmp, st)), P.ready(~K, ~eq, t, st), ready_fast(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, t, st)) :
        {Bool.and(P.ok.at(St(~K, ~eq, st, d)), _) == Bool.and(P.ok.at(St(~K, ~eq, st, d)), P.ready(~K, ~eq, t, st)) : Bool}
      {==}

def pnode_eq(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), m: Maybe<&2, List<&2, K>>, +st: List<&2, P.Entry<K>>, +running: List<&2, K>, b: Bool, room: Bool) ->
  {P.decide.par.node.fast(~K, ~eq, ~cmp, m, P.sidx(~K, ~cmp, st), running, b, room) == P.decide.par.node(~K, ~eq, m, st, running, b, room) : P.Step}:
  match m:
    case None{}:
      {==}
    case Some{+ds}:
      %Equal.sym(Bool, P.ready.fast(~K, ~cmp, ds, P.sidx(~K, ~cmp, st)), P.ready(~K, ~eq, ds, st), ready_fast(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, ds, st)) :
        {P.decide.par.wait(P.any_in(~K, ~eq, ds, running), _, b, room) == P.decide.par.wait(P.any_in(~K, ~eq, ds, running), P.ready(~K, ~eq, ds, st), b, room) : P.Step}
      {==}

def pseen_eq(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), c: Bool, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +st: List<&2, P.Entry<K>>, +running: List<&2, K>, +x: K) ->
  {P.decide.par.seen.fast(~K, ~eq, ~cmp, c, P.gidx(~K, ~cmp, g), P.idx(~K, ~cmp, stale), limit, P.sidx(~K, ~cmp, st), running, x)
    == P.decide.par.seen(~K, ~eq, c, g, stale, limit, st, running, x) : P.Step}:
  match c:
    case True{}:
      {==}
    case False{}:
      +room = P.le(1n+List.length(&2, K, running), limit)
      %Equal.sym(Maybe<&2, List<&2, K>>, GGet(~K, ~cmp, P.gidx(~K, ~cmp, g), x), P.deps(~K, ~eq, g, x), gget(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, g, x)) :
        {P.decide.par.node.fast(~K, ~eq, ~cmp, _, P.sidx(~K, ~cmp, st), running, OMap.OSet.has(~K, ~cmp, P.idx(~K, ~cmp, stale), x), room)
          == P.decide.par.node(~K, ~eq, P.deps(~K, ~eq, g, x), st, running, P.member(~K, ~eq, stale, x), room) : P.Step}
      %Equal.sym(Bool, IHas(~K, ~cmp, P.idx(~K, ~cmp, stale), x), P.member(~K, ~eq, stale, x), ihas(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, stale, x)) :
        {P.decide.par.node.fast(~K, ~eq, ~cmp, P.deps(~K, ~eq, g, x), P.sidx(~K, ~cmp, st), running, _, room)
          == P.decide.par.node(~K, ~eq, P.deps(~K, ~eq, g, x), st, running, P.member(~K, ~eq, stale, x), room) : P.Step}
      pnode_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, P.deps(~K, ~eq, g, x), st, running, P.member(~K, ~eq, stale, x), room)

def pdecide_eq(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, pool: P.Pool<K>, +x: K) ->
  {P.decide.par.fast(~K, ~eq, ~cmp, P.gidx(~K, ~cmp, g), P.idx(~K, ~cmp, stale), limit, P.lift(~K, ~cmp, pool), x)
    == P.decide.par(~K, ~eq, g, stale, limit, pool, x) : P.Step}:
  match pool:
    case P.Pool{+st, +running, +log}:
      %Equal.sym(Maybe<&2, P.Status>, SGet(~K, ~cmp, P.sidx(~K, ~cmp, st), x), St(~K, ~eq, st, x), sget(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, st, x)) :
        {P.decide.par.seen.fast(~K, ~eq, ~cmp, Bool.or(Maybe.is_some(&2, P.Status, _), P.member(~K, ~eq, running, x)),
            P.gidx(~K, ~cmp, g), P.idx(~K, ~cmp, stale), limit, P.sidx(~K, ~cmp, st), running, x)
          == P.decide.par.seen(~K, ~eq, Bool.or(Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)), P.member(~K, ~eq, running, x)), g, stale, limit, st, running, x) : P.Step}
      pseen_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, Bool.or(Maybe.is_some(&2, P.Status, St(~K, ~eq, st, x)), P.member(~K, ~eq, running, x)), g, stale, limit, st, running, x)

def papply_eq(~K: Data, ~cmp: K -> K -> Cmp, a: P.Step, pool: P.Pool<K>, +x: K) ->
  {P.apply.fast(~K, ~cmp, a, P.lift(~K, ~cmp, pool), x) == P.lift(~K, ~cmp, P.apply(K, a, pool, x)) : P.FPool<K>}:
  match a pool:
    case P.PSkip{} P.Pool{st, r, l}:
      {==}
    case P.PMark{s} P.Pool{st, r, l}:
      {==}
    case P.PStart{} P.Pool{st, r, l}:
      {==}
    case P.PWait{} P.Pool{st, r, l}:
      {==}

def pfin_if(~K: Data, ~cmp: K -> K -> Cmp, c: Bool, +y: K, +ok: Bool, +st: List<&2, P.Entry<K>>, +running: List<&2, K>, +dr: List<&2, K>, +log: List<&2, K>) ->
  {P.FPool{P.finish.if(K, c, y, ok, st, running, dr, log), P.finish.si(~K, ~cmp, c, P.sidx(~K, ~cmp, st), y, ok)}
    == P.lift(~K, ~cmp, P.finish.if(K, c, y, ok, st, running, dr, log)) : P.FPool<K>}:
  match c:
    case True{}:
      {==}
    case False{}:
      {==}

def pfinish_eq(~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, pool: P.Pool<K>, e: P.Fin<K>) ->
  {P.finish.fast(~K, ~eq, ~cmp, P.lift(~K, ~cmp, pool), e) == P.lift(~K, ~cmp, P.finish(~K, ~eq, pool, e)) : P.FPool<K>}:
  match pool e:
    case P.Pool{+st, +running, +log} P.Fin{+y, +ok}:
      pfin_if(~K, ~cmp, P.member(~K, ~eq, running, y), y, ok, st, running, P.drop(~K, ~eq, running, y), log)

def pat_eq(~K: Data, ~cmp: K -> K -> Cmp, a: P.Step,
  wL: Unit -> P.FPool<K>, wR: Unit -> P.Pool<K>, gL: Unit -> P.FPool<K>, gR: Unit -> P.Pool<K>,
  ew: {wL(Unit{}) == P.lift(~K, ~cmp, wR(Unit{})) : P.FPool<K>}, eg: {gL(Unit{}) == P.lift(~K, ~cmp, gR(Unit{})) : P.FPool<K>}
) -> {P.par.at(P.FPool<K>, a, wL, gL) == P.lift(~K, ~cmp, P.par.at(P.Pool<K>, a, wR, gR)) : P.FPool<K>}:
  match a:
    case P.PSkip{}:
      eg
    case P.PMark{s}:
      eg
    case P.PStart{}:
      eg
    case P.PWait{}:
      ew

# The indexed parallel run answers as the list run, with an exact status index.
def par_fast_eq(~K: Data, ~cmp: K -> K -> Cmp, ~eq: K -> K -> Bool, ~crefl: CRefl(~K, ~cmp), ~ceq: CEq(~K, ~cmp), ~cflip: CFlip(~K, ~cmp), ~ctrans: CTrans(~K, ~cmp),
  ~agree: Agree(~K, ~cmp, ~eq), es: List<&2, P.Fin<K>>, p: List<&2, K>, +g: List<&2, P.Node<K>>, +stale: List<&2, K>, +limit: Nat, +pool: P.Pool<K>) ->
  {P.par.fast(~K, ~eq, ~cmp, es, p, P.gidx(~K, ~cmp, g), P.idx(~K, ~cmp, stale), limit, P.lift(~K, ~cmp, pool))
    == P.lift(~K, ~cmp, P.par(~K, ~eq, es, p, g, stale, limit, pool)) : P.FPool<K>}:
  match es:
    case Nil{}:
      match p:
        case Nil{}:
          {==}
        case Con{+x, +t}:
          +gi = P.gidx(~K, ~cmp, g)
          +si = P.idx(~K, ~cmp, stale)
          +a = P.decide.par(~K, ~eq, g, stale, limit, pool, x)
          %Equal.sym(P.Step, P.decide.par.fast(~K, ~eq, ~cmp, gi, si, limit, P.lift(~K, ~cmp, pool), x), a, pdecide_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, g, stale, limit, pool, x)) :
            {P.par.at(P.FPool<K>, _, u => P.lift(~K, ~cmp, pool), u => P.par.fast(~K, ~eq, ~cmp, Nil{}, t, gi, si, limit, P.apply.fast(~K, ~cmp, _, P.lift(~K, ~cmp, pool), x)))
              == P.lift(~K, ~cmp, P.par.at(P.Pool<K>, a, u => pool, u => P.par(~K, ~eq, Nil{}, t, g, stale, limit, P.apply(K, a, pool, x)))) : P.FPool<K>}
          pat_eq(~K, ~cmp, a,
            u => P.lift(~K, ~cmp, pool), u => pool,
            u => P.par.fast(~K, ~eq, ~cmp, Nil{}, t, gi, si, limit, P.apply.fast(~K, ~cmp, a, P.lift(~K, ~cmp, pool), x)),
            u => P.par(~K, ~eq, Nil{}, t, g, stale, limit, P.apply(K, a, pool, x)),
            {==},
            (%Equal.sym(P.FPool<K>, P.apply.fast(~K, ~cmp, a, P.lift(~K, ~cmp, pool), x), P.lift(~K, ~cmp, P.apply(K, a, pool, x)), papply_eq(~K, ~cmp, a, pool, x)) :
              {P.par.fast(~K, ~eq, ~cmp, Nil{}, t, gi, si, limit, _) == P.lift(~K, ~cmp, P.par(~K, ~eq, Nil{}, t, g, stale, limit, P.apply(K, a, pool, x))) : P.FPool<K>}
              par_fast_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, Nil{}, t, g, stale, limit, P.apply(K, a, pool, x))))
    case Con{+e, +r}:
      match p:
        case Nil{}:
          +gi = P.gidx(~K, ~cmp, g)
          +si = P.idx(~K, ~cmp, stale)
          %Equal.sym(P.FPool<K>, P.finish.fast(~K, ~eq, ~cmp, P.lift(~K, ~cmp, pool), e), P.lift(~K, ~cmp, P.finish(~K, ~eq, pool, e)), pfinish_eq(~K, ~eq, ~cmp, pool, e)) :
            {P.par.fast(~K, ~eq, ~cmp, r, Nil{}, gi, si, limit, _) == P.lift(~K, ~cmp, P.par(~K, ~eq, r, Nil{}, g, stale, limit, P.finish(~K, ~eq, pool, e))) : P.FPool<K>}
          par_fast_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, r, Nil{}, g, stale, limit, P.finish(~K, ~eq, pool, e))
        case Con{+x, +t}:
          +gi = P.gidx(~K, ~cmp, g)
          +si = P.idx(~K, ~cmp, stale)
          +a = P.decide.par(~K, ~eq, g, stale, limit, pool, x)
          %Equal.sym(P.Step, P.decide.par.fast(~K, ~eq, ~cmp, gi, si, limit, P.lift(~K, ~cmp, pool), x), a, pdecide_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, g, stale, limit, pool, x)) :
            {P.par.at(P.FPool<K>, _,
                u => P.par.fast(~K, ~eq, ~cmp, r, x <> t, gi, si, limit, P.finish.fast(~K, ~eq, ~cmp, P.lift(~K, ~cmp, pool), e)),
                u => P.par.fast(~K, ~eq, ~cmp, e <> r, t, gi, si, limit, P.apply.fast(~K, ~cmp, _, P.lift(~K, ~cmp, pool), x)))
              == P.lift(~K, ~cmp, P.par.at(P.Pool<K>, a,
                u => P.par(~K, ~eq, r, x <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)),
                u => P.par(~K, ~eq, e <> r, t, g, stale, limit, P.apply(K, a, pool, x)))) : P.FPool<K>}
          pat_eq(~K, ~cmp, a,
            u => P.par.fast(~K, ~eq, ~cmp, r, x <> t, gi, si, limit, P.finish.fast(~K, ~eq, ~cmp, P.lift(~K, ~cmp, pool), e)),
            u => P.par(~K, ~eq, r, x <> t, g, stale, limit, P.finish(~K, ~eq, pool, e)),
            u => P.par.fast(~K, ~eq, ~cmp, e <> r, t, gi, si, limit, P.apply.fast(~K, ~cmp, a, P.lift(~K, ~cmp, pool), x)),
            u => P.par(~K, ~eq, e <> r, t, g, stale, limit, P.apply(K, a, pool, x)),
            (%Equal.sym(P.FPool<K>, P.finish.fast(~K, ~eq, ~cmp, P.lift(~K, ~cmp, pool), e), P.lift(~K, ~cmp, P.finish(~K, ~eq, pool, e)), pfinish_eq(~K, ~eq, ~cmp, pool, e)) :
              {P.par.fast(~K, ~eq, ~cmp, r, x <> t, gi, si, limit, _) == P.lift(~K, ~cmp, P.par(~K, ~eq, r, x <> t, g, stale, limit, P.finish(~K, ~eq, pool, e))) : P.FPool<K>}
              par_fast_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, r, x <> t, g, stale, limit, P.finish(~K, ~eq, pool, e))),
            (%Equal.sym(P.FPool<K>, P.apply.fast(~K, ~cmp, a, P.lift(~K, ~cmp, pool), x), P.lift(~K, ~cmp, P.apply(K, a, pool, x)), papply_eq(~K, ~cmp, a, pool, x)) :
              {P.par.fast(~K, ~eq, ~cmp, e <> r, t, gi, si, limit, _) == P.lift(~K, ~cmp, P.par(~K, ~eq, e <> r, t, g, stale, limit, P.apply(K, a, pool, x))) : P.FPool<K>}
              par_fast_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, e <> r, t, g, stale, limit, P.apply(K, a, pool, x))))

def Laws.par_index(K, eq, cmp, crefl, ceq, cflip, ctrans, agree, es, p, g, stale, limit, pool):
  par_fast_eq(~K, ~cmp, ~eq, ~crefl, ~ceq, ~cflip, ~ctrans, ~agree, es, p, g, stale, limit, pool)

# Fixtures
# --------

def Laws.fixture_par():
  {==}

def Laws.fixture_plan():
  {==}

def Laws.fixture_plan_shared():
  {==}

def Laws.fixture_cycle():
  {==}

def Laws.fixture_missing():
  {==}

def Laws.fixture_stale():
  {==}

def Laws.fixture_reuse():
  {==}

def Laws.fixture_failure():
  {==}
