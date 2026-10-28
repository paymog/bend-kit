import Base
import bend-mathlib@0.7.4.0/nat.bend as MNat
import bend-kit-scheduler@0.4.1.0/queue.bend as Q
import bend-kit-scheduler@0.4.1.0/queue_laws.bend as QL
import bend-kit-scheduler@0.4.1.0/queue_proof.bend as QP
import bend-kit-collections@0.1.4.1/heap.bend as H
import bend-kit-collections@0.1.4.1/LAWS.bend as CL
import bend-kit-collections@0.1.4.1/PROOF.bend as CP
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import ./runner.bend as R
import ./LAWS.bend as Laws

def split(-P: Bool -> Type, b: Bool, yes: {b == True{} : Bool} -> P(True{}), no: {b == False{} : Bool} -> P(False{})) -> P(b):
  match b:
    case True{}:
      yes({==})
    case False{}:
      no({==})

# ---- replay

def replay.go(~A: Data, ~X: Type, ~enc: R.Op<A> -> X, ~dec: X -> Maybe<&2, R.Op<A>>, ~round: @op: R.Op<A> -> {dec(enc(op)) == Some{op} : Maybe<&2, R.Op<A>>},
    ops: List<&2, R.Op<A>>, s: R.State<A>) -> {Laws.replayed(~A, ~X, ~enc, ~dec, ops, s) == Some{Laws.live(~A, ops, s)} : Maybe<&2, R.State<A>>}:
  match ops:
    case Nil{}:
      {==}
    case Con{+op, rest}:
      %Equal.sym(Maybe<&2, R.Op<A>>, dec(enc(op)), Some{op}, round(op)) : {Laws.replay.from(~A, ~X, ~dec, Laws.encode.all(~A, ~X, ~enc, rest), R.apply.op(~A, _, s)) == Some{Laws.live(~A, rest, R.step(~A, s, op))} : Maybe<&2, R.State<A>>}
      replay.go(~A, ~X, ~enc, ~dec, ~round, rest, R.step(~A, s, op))

def Laws.replay_live(A, X, enc, dec, round, ops, s):
  replay.go(~A, ~X, ~enc, ~dec, ~round, ops, s)

def Laws.replay_prefix(A, X, enc, dec, round, ops, k, s):
  replay.go(~A, ~X, ~enc, ~dec, ~round, List.take(&2, R.Op<A>, ops, k), s)

# ---- compaction

def restore.go(~A: Data, ~X: Type, ~enc: R.Rec<A> -> X, ~dec: X -> Maybe<&2, R.Rec<A>>, ~round: @r: R.Rec<A> -> {dec(enc(r)) == Some{r} : Maybe<&2, R.Rec<A>>},
    more: List<&2, R.Op<A>>, s: R.State<A>) -> {Laws.restore.from(~A, ~X, ~dec, Laws.encode.ops(~A, ~X, ~enc, more), Some{s}) == Some{Laws.live(~A, more, s)} : Maybe<&2, R.State<A>>}:
  match more:
    case Nil{}:
      {==}
    case Con{+op, rest}:
      %Equal.sym(Maybe<&2, R.Rec<A>>, dec(enc(R.Do{op})), Some{R.Do{op}}, round(R.Do{op})) : {Laws.restore.from(~A, ~X, ~dec, Laws.encode.ops(~A, ~X, ~enc, rest), R.load.rec(~A, _, s)) == Some{Laws.live(~A, rest, R.step(~A, s, op))} : Maybe<&2, R.State<A>>}
      restore.go(~A, ~X, ~enc, ~dec, ~round, rest, R.step(~A, s, op))

def Laws.replay_snapshot(A, X, enc, dec, round, ops, s, more, t):
  %Equal.sym(Maybe<&2, R.Rec<A>>, dec(enc(R.Snap{Laws.live(~A, ops, s)})), Some{R.Snap{Laws.live(~A, ops, s)}}, round(R.Snap{Laws.live(~A, ops, s)})) : {Laws.restore.from(~A, ~X, ~dec, Laws.encode.ops(~A, ~X, ~enc, more), R.load.rec(~A, _, t)) == Some{Laws.live(~A, more, Laws.live(~A, ops, s))} : Maybe<&2, R.State<A>>}
  restore.go(~A, ~X, ~enc, ~dec, ~round, more, Laws.live(~A, ops, s))

# ---- retry

def Laws.requeue_wait(A, o, p, b, id, n, now, r, w, e):
  %Equal.sym(Retry.Plan, Retry.plan(o, p, b, n, now, r), Retry.PlanWait{w}, e) : {R.after.plan(A, _, o, b, id, now) == R.Requeue{id, Nat.add(now, w)} : R.Op<A>}
  {==}

def Laws.settled_complete(A, p, b, id, n, now, r):
  {==}

def Laws.unsafe_abandon(A, p, b, id, n, now, r):
  {==}

def Laws.failed_abandon(A, p, b, id, n, now, r):
  {==}

def Laws.rejected_abandon(A, p, b, id, n, now, r):
  {==}

def Laws.rejected_spares_breaker(c, s, now):
  {==}

def Laws.rejected_keeps_closed(c, fs, now):
  {==}

def Laws.transient_abandon(A, a, p, b, id, n, now, r, e):
  %Equal.sym(Retry.Plan, Retry.plan(Retry.Transient{a}, p, b, n, now, r), Retry.PlanStop{}, e) : {R.after.plan(A, _, Retry.Transient{a}, b, id, now) == R.Abandon{id, R.gave(b), now} : R.Op<A>}
  {==}

# ---- pool

# Every pick is Idle with the pool unchanged, or the reserve of one unit for a selected ticket.
def pick_cases(~A: Data, -P: R.Pick<A> -> Type, +p: Res.Pool, s: R.State<A>, +now: Nat, idle: P(R.Idle{p}),
    took: @t: Q.Ticket<A> -> P(R.pick.took(A, Res.reserve(p, 1n), t))) -> P(R.pick(~A, p, s, now)):
  match s:
    case R.State{Q.State{i, H.HLeaf{}, r}, ts, ds, bs}:
      idle
    case R.State{Q.State{i, H.HNode{n, +t, l, q}, r}, ts, ds, bs}:
      split(b => P(R.pick.sel(A, Q.select.due(~A, b, i, H.HNode{n, t, l, q}, r, t, l, q), p)), Nat.is_le(Q.deadline(A, t), now),
        e => took(t),
        e => idle)

def took.holds(-A: Data, +o: Nat, +c: Nat, +h: Nat, +t: Q.Ticket<A>) ->
    {Res.reserved(Laws.pick.pool(A, R.pick.took(A, Res.reserve(Res.Pool{o, c, h}, 1n), t))) == Laws.pick.held(A, R.pick.took(A, Res.reserve(Res.Pool{o, c, h}, 1n), t), h) : Nat}:
  split(b => {Res.reserved(Laws.pick.pool(A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t))) == Laws.pick.held(A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t), h) : Nat},
    Nat.is_le(Nat.add(h, 1n), c),
    e => {==},
    e => {==})

def Laws.pick_holds_one(A, o, c, h, s, now):
  +o = o
  +c = c
  pick_cases(~A, k => {Res.reserved(Laws.pick.pool(A, k)) == Laws.pick.held(A, k, h) : Nat}, Res.Pool{o, c, h}, s, now, {==}, t => took.holds(A, o, c, h, t))

def took.bounded(-A: Data, +o: Nat, +c: Nat, +h: Nat, e: MNat.le(h, c), +t: Q.Ticket<A>) ->
    MNat.le(Res.reserved(Laws.pick.pool(A, R.pick.took(A, Res.reserve(Res.Pool{o, c, h}, 1n), t))), c):
  split(b => MNat.le(Res.reserved(Laws.pick.pool(A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t))), c),
    Nat.is_le(Nat.add(h, 1n), c),
    f => f,
    f => e)

def Laws.pick_bounded(A, o, c, h, e, s, now):
  +o = o
  +c = c
  +h = h
  +now = now
  +e = e
  pick_cases(~A, k => MNat.le(Res.reserved(Laws.pick.pool(A, k)), c), Res.Pool{o, c, h}, s, now, e, t => took.bounded(A, o, c, h, e, t))

def zero_le(h: Nat) -> {Nat.is_le(0n, h) == True{} : Bool}:
  match h:
    case 0n:
      {==}
    case 1n+p:
      {==}

def took.release.go(+o: Nat, +c: Nat, +h: Nat) -> {Laws.release.pool(Res.release(Res.Pool{o, c, Nat.add(h, 1n)}, Res.Grant{o, 1n})) == Res.Pool{o, c, h} : Res.Pool}:
  %MNat.add_comm(1n, h) : {Laws.release.pool(Res.release(Res.Pool{o, c, _}, Res.Grant{o, 1n})) == Res.Pool{o, c, h} : Res.Pool}
  %Equal.sym(Bool, Nat.is_eq(o, o), True{}, MNat.is_eq_refl(o)) : {Laws.release.pool(Res.release.go(Bool.and(_, Nat.is_le(1n, 1n+h)), o, c, 1n+h, o, 1n)) == Res.Pool{o, c, h} : Res.Pool}
  %Equal.sym(Bool, Nat.is_le(0n, h), True{}, zero_le(h)) : {Laws.release.pool(Res.release.go(_, o, c, 1n+h, o, 1n)) == Res.Pool{o, c, h} : Res.Pool}
  %Equal.sym(Nat, Nat.sub(h, 0n), h, MNat.sub_zero(h)) : {Res.Pool{o, c, _} == Res.Pool{o, c, h} : Res.Pool}
  {==}

def took.release(-A: Data, +o: Nat, +c: Nat, +h: Nat, +t: Q.Ticket<A>) ->
    {Laws.pick.round(A, R.pick.took(A, Res.reserve(Res.Pool{o, c, h}, 1n), t)) == Res.Pool{o, c, h} : Res.Pool}:
  split(b => {Laws.pick.round(A, R.pick.took(A, Res.reserve.go(b, o, c, h, 1n), t)) == Res.Pool{o, c, h} : Res.Pool},
    Nat.is_le(Nat.add(h, 1n), c),
    f => took.release.go(o, c, h),
    f => {==})

def Laws.pick_release(A, o, c, h, s, now):
  +o = o
  +c = c
  +h = h
  +now = now
  pick_cases(~A, k => {Laws.pick.round(A, k) == Res.Pool{o, c, h} : Res.Pool}, Res.Pool{o, c, h}, s, now, {==}, t => took.release(A, o, c, h, t))

# ---- a finished ticket is never selected again

# Ticket i is not dead in ds, and ds is a well-formed trie.
def absent.dead(~A: Data, +i: Nat, ds: R.Graves(A)) -> Data:
  QL.Both<{R.dead.get(~A, ds, i) == None{} : Maybe<&2, R.Dead<A>>}, {Laws.dead.wf(~A, ds) == True{} : Bool}>

def anything(-A: Data, ds: R.Graves(A)) -> Data:
  Unit

# s will issue no id i again, ticket i is neither pending nor running, and P holds of the dead tickets.
def inv(-A: Data, +i: Nat, -P: R.Graves(A) -> Data, s: R.State<A>) -> Data:
  match s:
    case R.State{Q.State{n, h, r}, ts, ds, bs}:
      QL.Both<MNat.lt(i, n), QL.Both<QL.absent.heap(A, h, i), QL.Both<QL.absent.list(A, r, i), P(ds)>>>

# Ticket i is in no registry of s, and s will issue no id i again.
def gone(~A: Data, +i: Nat, s: R.State<A>) -> Data:
  inv(A, i, ds => absent.dead(~A, i, ds), s)

def lt_ne(i: Nat, n: Nat, e: MNat.lt(i, n)) -> {Nat.is_eq(n, i) == False{} : Bool}:
  match i n:
    case 0n 0n:
      Empty.absurd({Nat.is_eq(0n, 0n) == False{} : Bool}, MNat.lt_irrefl(0n, e))
    case 0n 1n+m:
      {==}
    case 1n+p 0n:
      {==}
    case 1n+p 1n+m:
      lt_ne(p, m, e)

# Removing ticket j keeps ticket i absent.
def remove_keeps.list(-A: Data, +xs: List<&2, Q.Ticket<A>>, +j: Nat, +i: Nat, +e: QL.absent.list(A, xs, i)) -> QL.absent.list(A, Q.remove.list(A, xs, j), i):
  match xs:
    case Nil{}:
      Unit{}
    case Con{t, rest}:
      QL.Both{et, er} = e
      +r2 = Q.remove.list(A, rest, j)
      +er2 = remove_keeps.list(A, rest, j, i, er)
      split(c => QL.absent.list(A, Q.remove.list.keep(A, c, t, r2), i), Nat.is_eq(Q.id(A, t), j),
        f => er2,
        f => QL.Both{et, er2})

def found.absent(-A: Data, m: Maybe<&2, Q.Ticket<A>>, +i: Nat) -> Data:
  match m:
    case None{}:
      Unit
    case Some{t}:
      QL.absent.ticket(A, i, t)

def taken.ok(-A: Data, tk: Q.Taken<A>, +i: Nat) -> Data:
  match tk:
    case Q.Taken{rest, found}:
      QL.Both<QL.absent.list(A, rest, i), found.absent(A, found, i)>

def keep_ok(-A: Data, b: Bool, t: Q.Ticket<A>, tk: Q.Taken<A>, +i: Nat, +et: QL.absent.ticket(A, i, t), etk: taken.ok(A, tk, i)) -> taken.ok(A, Q.take.keep(A, b, t, tk), i):
  match b tk:
    case True{} Q.Taken{rest, found}:
      QL.Both{erest, ef} = etk
      QL.Both{erest, et}
    case False{} Q.Taken{rest, found}:
      QL.Both{erest, ef} = etk
      QL.Both{QL.Both{et, erest}, ef}

# Taking ticket j from a list without ticket i leaves no i, and takes no i.
def take_ok(-A: Data, +xs: List<&2, Q.Ticket<A>>, +j: Nat, +i: Nat, e: QL.absent.list(A, xs, i)) -> taken.ok(A, Q.take.list(A, xs, j), i):
  match xs:
    case Nil{}:
      QL.Both{Unit{}, Unit{}}
    case Con{t, rest}:
      QL.Both{et, er} = e
      keep_ok(A, Nat.is_eq(Q.id(A, t), j), t, Q.take.list(A, rest, j), i, et, take_ok(A, rest, j, i, er))

def taken.rem_ok(-A: Data, tk: Q.Taken<A>, +i: Nat) -> Data:
  match tk:
    case Q.Taken{rest, found}:
      QL.absent.list(A, rest, i)

def ok_rem(-A: Data, tk: Q.Taken<A>, +i: Nat, etk: taken.ok(A, tk, i)) -> taken.rem_ok(A, tk, i):
  match tk:
    case Q.Taken{rest, found}:
      QL.Both{erest, ef} = etk
      erest

def keep_absent(-A: Data, b: Bool, t: Q.Ticket<A>, tk: Q.Taken<A>, +i: Nat, et: {b == False{} : Bool} -> QL.absent.ticket(A, i, t), erest: taken.rem_ok(A, tk, i)) ->
    taken.rem_ok(A, Q.take.keep(A, b, t, tk), i):
  match b tk:
    case True{} Q.Taken{rest, found}:
      erest
    case False{} Q.Taken{rest, found}:
      QL.Both{et({==}), erest}

# Taking ticket i leaves no i in the list.
def take_absent(-A: Data, +xs: List<&2, Q.Ticket<A>>, +i: Nat) -> taken.rem_ok(A, Q.take.list(A, xs, i), i):
  match xs:
    case Nil{}:
      Unit{}
    case Con{t, rest}:
      keep_absent(A, Nat.is_eq(Q.id(A, t), i), t, Q.take.list(A, rest, i), i, f => f, take_absent(A, rest, i))

def complete_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, tk: Q.Taken<A>, +n: Nat, +h: H.Heap<Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(),
    lt: MNat.lt(i, n), eh: QL.absent.heap(A, h, i), erem: taken.rem_ok(A, tk, i), ed: P(ds)) ->
    inv(A, i, P, R.step.completed(A, Q.complete.taken(A, tk, n, h), ts, ds, bs)):
  match tk:
    case Q.Taken{rest, found}:
      QL.Both{lt, QL.Both{eh, QL.Both{erem, ed}}}

def found.of(-A: Data, tk: Q.Taken<A>) -> Maybe<&2, Q.Ticket<A>>:
  match tk:
    case Q.Taken{rest, found}:
      found

def abandon_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, tk: Q.Taken<A>, +n: Nat, +h: H.Heap<Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), w: R.Why, +at: Nat,
    lt: MNat.lt(i, n), eh: QL.absent.heap(A, h, i), erem: taken.rem_ok(A, tk, i), ed: P(R.dead.bury(~A, found.of(A, tk), ds, w, at))) ->
    inv(A, i, P, R.step.abandoned(~A, Q.complete.taken(A, tk, n, h), ts, ds, bs, w, at)):
  match tk:
    case Q.Taken{rest, found}:
      QL.Both{lt, QL.Both{eh, QL.Both{erem, ed}}}

def requeue_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, tk: Q.Taken<A>, +n: Nat, +h: H.Heap<Q.Ticket<A>>, +d: Nat, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(),
    lt: MNat.lt(i, n), eh: QL.absent.heap(A, h, i), etk: taken.ok(A, tk, i), ed: P(ds)) ->
    inv(A, i, P, R.step.requeued(A, Q.requeue.completed(~A, Q.complete.taken(A, tk, n, h), d), ts, ds, bs)):
  match tk:
    case Q.Taken{rest, None{}}:
      QL.Both{erest, ef} = etk
      QL.Both{lt, QL.Both{eh, QL.Both{erest, ed}}}
    case Q.Taken{rest, Some{Q.Ticket{j, old, x}}}:
      QL.Both{erest, ej} = etk
      QL.Both{lt, QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), H.HNode{1n, Q.Ticket{j, d, x}, H.HLeaf{}, H.HLeaf{}}, h, QL.Both{ej, QL.Both{Unit{}, Unit{}}}, eh), QL.Both{erest, ed}}}

def select_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, +now: Nat, +n: Nat, h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(),
    +lt: MNat.lt(i, n), +eh: QL.absent.heap(A, h, i), +er: QL.absent.list(A, r, i), +ed: P(ds)) ->
    inv(A, i, P, R.step.selected(A, Q.select(~A, now, Q.State{n, h, r}), ts, ds, bs)):
  match h:
    case H.HLeaf{}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}}
    case H.HNode{size, +t, +l, +q}:
      QL.Both{+et, QL.Both{+el, +eq}} = eh
      split(c => inv(A, i, P, R.step.selected(A, Q.select.due(~A, c, n, H.HNode{size, t, l, q}, r, t, l, q), ts, ds, bs)), Nat.is_le(Q.deadline(A, t), now),
        e => QL.Both{lt, QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), l, q, el, eq), QL.Both{QL.Both{et, er}, ed}}},
        e => QL.Both{lt, QL.Both{QL.Both{et, QL.Both{el, eq}}, QL.Both{er, ed}}})

# A Revive of j that finds a dead ticket pushes ticket j; it must not be i.
def revive.ok(-A: Data, m: Maybe<&2, R.Dead<A>>, +j: Nat, +i: Nat) -> Data:
  match m:
    case None{}:
      Unit
    case Some{x}:
      {Nat.is_eq(j, i) == False{} : Bool}

def revive_inv(~A: Data, +i: Nat, -P: R.Graves(A) -> Data, m: Maybe<&2, R.Dead<A>>, +j: Nat, +n: Nat, +h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: R.Tries(),
    rest: R.Graves(A), bs: R.Breakers(), +d: Nat, lt: MNat.lt(i, n), eh: QL.absent.heap(A, h, i), er: QL.absent.list(A, r, i), em: revive.ok(A, m, j, i), ed: P(rest)) ->
    inv(A, i, P, R.step.revived(~A, m, j, n, h, r, ts, rest, bs, d)):
  match m:
    case None{}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}}
    case Some{R.Dead{Q.Ticket{k, old, x}, w, at}}:
      QL.Both{lt, QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), H.HNode{1n, Q.Ticket{j, d, x}, H.HLeaf{}, H.HLeaf{}}, h, QL.Both{em, QL.Both{Unit{}, Unit{}}}, eh), QL.Both{er, ed}}}

# ---- dead tickets

def P.gone(~A: Data, +i: Nat) -> (R.Graves(A) -> Data):
  ds => absent.dead(~A, i, ds)

def is_eq_of(+a: Nat, -b: Nat, e: {a == b : Nat}) -> {Nat.is_eq(a, b) == True{} : Bool}:
  %e : {Nat.is_eq(a, _) == True{} : Bool}
  MNat.is_eq_refl(a)

def ne_of(+a: Nat, +b: Nat, f: {Nat.is_eq(a, b) == False{} : Bool}) -> {a != b : Nat}:
  e => MNat.internal_false_ne_true(Equal.trans(Bool, False{}, Nat.is_eq(a, b), True{}, Equal.sym(Bool, Nat.is_eq(a, b), False{}, f), is_eq_of(a, b, e)))

def get_drop_same(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, e: {Nat.is_eq(j, i) == True{} : Bool}, wf: {Laws.dead.wf(~A, ds) == True{} : Bool}) ->
    {R.dead.get(~A, R.dead.drop(~A, ds, j), i) == None{} : Maybe<&2, R.Dead<A>>}:
  %Equal.sym(Nat, j, i, MNat.eq_of_is_eq(j, i, e)) : {R.dead.get(~A, R.dead.drop(~A, ds, _), i) == None{} : Maybe<&2, R.Dead<A>>}
  CL.hmap_get_del_same(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, ds, wf, i)

def get_drop_other(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, f: {Nat.is_eq(j, i) == False{} : Bool}, eg: {R.dead.get(~A, ds, i) == None{} : Maybe<&2, R.Dead<A>>}) ->
    {R.dead.get(~A, R.dead.drop(~A, ds, j), i) == None{} : Maybe<&2, R.Dead<A>>}:
  Equal.trans(Maybe<&2, R.Dead<A>>, R.dead.get(~A, R.dead.drop(~A, ds, j), i), R.dead.get(~A, ds, i), None{},
    CL.hmap_get_del_other_key(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, ds, j, i, ne_of(j, i, f)), eg)

# Dropping any ticket keeps ticket i not dead and the trie well formed.
def drop_keeps(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, g: absent.dead(~A, i, ds)) -> absent.dead(~A, i, R.dead.drop(~A, ds, j)):
  QL.Both{+eg, +wf} = g
  QL.Both{split(b => {R.dead.get(~A, R.dead.drop(~A, ds, j), i) == None{} : Maybe<&2, R.Dead<A>>}, Nat.is_eq(j, i),
      e => get_drop_same(~A, ds, j, i, e, wf),
      f => get_drop_other(~A, ds, j, i, f, eg)),
    CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, j)}

# Dropping ticket i leaves it not dead.
def drop_self(~A: Data, +ds: R.Graves(A), +i: Nat, +wf: {Laws.dead.wf(~A, ds) == True{} : Bool}) -> absent.dead(~A, i, R.dead.drop(~A, ds, i)):
  QL.Both{CL.hmap_get_del_same(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, ds, wf, i),
    CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, i)}

def drops_keeps(~A: Data, ks: List<&2, Nat>, +ds: R.Graves(A), +i: Nat, g: absent.dead(~A, i, ds)) -> absent.dead(~A, i, R.dead.drops(~A, ks, ds)):
  match ks:
    case Nil{}:
      g
    case Con{+k, rest}:
      drops_keeps(~A, rest, R.dead.drop(~A, ds, k), i, drop_keeps(~A, ds, k, i, g))

def purge_keeps(~A: Data, +ds: R.Graves(A), +t: Nat, +i: Nat, g: absent.dead(~A, i, ds)) -> absent.dead(~A, i, R.dead.purge(~A, ds, t)):
  drops_keeps(~A, R.dead.old(A, R.dead.list(A, ds), t), ds, i, g)

# Burying a ticket other than i keeps ticket i not dead.
def bury_keeps(~A: Data, m: Maybe<&2, Q.Ticket<A>>, +ds: R.Graves(A), +w: R.Why, +at: Nat, +i: Nat, ef: found.absent(A, m, i), g: absent.dead(~A, i, ds)) ->
    absent.dead(~A, i, R.dead.bury(~A, m, ds, w, at)):
  match m:
    case None{}:
      g
    case Some{Q.Ticket{+k, +d, +x}}:
      QL.Both{+eg, +wf} = g
      QL.Both{Equal.trans(Maybe<&2, R.Dead<A>>, R.dead.get(~A, R.dead.bury(~A, Some{Q.Ticket{k, d, x}}, ds, w, at), i), R.dead.get(~A, ds, i), None{},
          CL.hmap_get_put_other_key(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.eq_of_is_eq, ds, wf, k, i, ne_of(k, i, ef), R.Dead{Q.Ticket{k, d, x}, w, at}), eg),
        CL.hmap_put_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.is_eq_refl, ~MNat.eq_of_is_eq, ds, wf, k, R.Dead{Q.Ticket{k, d, x}, w, at})}

def bury_absent(~A: Data, tk: Q.Taken<A>, +ds: R.Graves(A), +w: R.Why, +at: Nat, +i: Nat, etk: taken.ok(A, tk, i), g: absent.dead(~A, i, ds)) ->
    absent.dead(~A, i, R.dead.bury(~A, found.of(A, tk), ds, w, at)):
  match tk:
    case Q.Taken{rest, found}:
      QL.Both{erest, ef} = etk
      bury_keeps(~A, found, ds, w, at, i, ef, g)

def any_ok(-A: Data, m: Maybe<&2, R.Dead<A>>, +j: Nat, +i: Nat, f: {Nat.is_eq(j, i) == False{} : Bool}) -> revive.ok(A, m, j, i):
  match m:
    case None{}:
      Unit{}
    case Some{x}:
      f

def same_ok(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, e: {Nat.is_eq(j, i) == True{} : Bool}, eg: {R.dead.get(~A, ds, i) == None{} : Maybe<&2, R.Dead<A>>}) ->
    revive.ok(A, R.dead.get(~A, ds, j), j, i):
  %Equal.sym(Nat, j, i, MNat.eq_of_is_eq(j, i, e)) : revive.ok(A, R.dead.get(~A, ds, _), j, i)
  %Equal.sym(Maybe<&2, R.Dead<A>>, R.dead.get(~A, ds, i), None{}, eg) : revive.ok(A, _, j, i)
  Unit{}

# A Revive of j, when ticket i is not dead, pushes no ticket i.
def revive_ok(~A: Data, +ds: R.Graves(A), +j: Nat, +i: Nat, +eg: {R.dead.get(~A, ds, i) == None{} : Maybe<&2, R.Dead<A>>}) -> revive.ok(A, R.dead.get(~A, ds, j), j, i):
  split(b => revive.ok(A, R.dead.get(~A, ds, j), j, i), Nat.is_eq(j, i),
    e => same_ok(~A, ds, j, i, e, eg),
    f => any_ok(A, R.dead.get(~A, ds, j), j, i, f))

# ---- every op keeps a gone ticket gone

def step_gone(~A: Data, +i: Nat, s: R.State<A>, op: R.Op<A>, g: gone(~A, i, s)) -> gone(~A, i, R.step(~A, s, op)):
  match s op:
    case R.State{Q.State{+n, h, r}, ts, ds, bs} R.Enqueue{d, x}:
      QL.Both{+lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{MNat.lt_trans(i, n, 1n+n, lt, MNat.lt_succ_self(n)), QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), H.HNode{1n, Q.Ticket{n, d, x}, H.HLeaf{}, H.HLeaf{}}, h, QL.Both{lt_ne(i, n, lt), QL.Both{Unit{}, Unit{}}}, eh), QL.Both{er, ed}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Select{now}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      select_inv(~A, i, P.gone(~A, i), now, n, h, r, ts, ds, bs, lt, eh, er, ed)
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Complete{+j}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      complete_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, j), n, h, R.tries.drop(ts, j), ds, bs, lt, eh, ok_rem(A, Q.take.list(A, r, j), i, take_ok(A, r, j, i, er)), ed)
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Cancel{+j}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{QP.remove_all(~A, QL.absent.ticket(A, i), h, j, eh), QL.Both{remove_keeps.list(A, r, j, i, er), drop_keeps(~A, ds, j, i, ed)}}}
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Requeue{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      requeue_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, j), n, h, d, R.tries.bump(ts, j), ds, bs, lt, eh, take_ok(A, r, j, i, er), ed)
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Defer{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      requeue_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, j), n, h, d, ts, ds, bs, lt, eh, take_ok(A, r, j, i, er), ed)
    case R.State{Q.State{n, h, +r}, ts, +ds, bs} R.Abandon{+j, +w, +at}:
      QL.Both{lt, QL.Both{eh, QL.Both{+er, ed}}} = g
      abandon_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, j), n, h, R.tries.drop(ts, j), ds, bs, w, at, lt, eh, ok_rem(A, Q.take.list(A, r, j), i, take_ok(A, r, j, i, er)),
        bury_absent(~A, Q.take.list(A, r, j), ds, w, at, i, take_ok(A, r, j, i, er), ed))
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Revive{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{+eg, +wf} = ed
      revive_inv(~A, i, P.gone(~A, i), R.dead.get(~A, ds, j), j, n, h, r, ts, R.dead.drop(~A, ds, j), bs, d, lt, eh, er, revive_ok(~A, ds, j, i, eg), drop_keeps(~A, ds, j, i, QL.Both{eg, wf}))
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Purge{+t}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{eh, QL.Both{er, purge_keeps(~A, ds, t, i, ed)}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.PurgeAll{}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{eh, QL.Both{er, QL.Both{{==}, {==}}}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Break{k, b}:
      g

def live_gone(~A: Data, +i: Nat, ops: List<&2, R.Op<A>>, +s: R.State<A>, g: gone(~A, i, s)) -> gone(~A, i, Laws.live(~A, ops, s)):
  match ops:
    case Nil{}:
      g
    case Con{op, rest}:
      +op = op
      live_gone(~A, i, rest, R.step(~A, s, op), step_gone(~A, i, s, op, g))

# Every op but a Revive of i keeps ticket i out of the queue, whether or not it is dead.
def step_buried(~A: Data, +i: Nat, s: R.State<A>, op: R.Op<A>, g: inv(A, i, anything(A), s), no: {Laws.revived(A, op, i) == False{} : Bool}) ->
    inv(A, i, anything(A), R.step(~A, s, op)):
  match s op:
    case R.State{Q.State{+n, h, r}, ts, ds, bs} R.Enqueue{d, x}:
      QL.Both{+lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{MNat.lt_trans(i, n, 1n+n, lt, MNat.lt_succ_self(n)), QL.Both{QP.merge_all.full(~A, QL.absent.ticket(A, i), H.HNode{1n, Q.Ticket{n, d, x}, H.HLeaf{}, H.HLeaf{}}, h, QL.Both{lt_ne(i, n, lt), QL.Both{Unit{}, Unit{}}}, eh), QL.Both{er, Unit{}}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Select{now}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      select_inv(~A, i, anything(A), now, n, h, r, ts, ds, bs, lt, eh, er, Unit{})
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Complete{+j}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      complete_inv(~A, i, anything(A), Q.take.list(A, r, j), n, h, R.tries.drop(ts, j), ds, bs, lt, eh, ok_rem(A, Q.take.list(A, r, j), i, take_ok(A, r, j, i, er)), Unit{})
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Cancel{+j}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{QP.remove_all(~A, QL.absent.ticket(A, i), h, j, eh), QL.Both{remove_keeps.list(A, r, j, i, er), Unit{}}}}
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Requeue{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      requeue_inv(~A, i, anything(A), Q.take.list(A, r, j), n, h, d, R.tries.bump(ts, j), ds, bs, lt, eh, take_ok(A, r, j, i, er), Unit{})
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Defer{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      requeue_inv(~A, i, anything(A), Q.take.list(A, r, j), n, h, d, ts, ds, bs, lt, eh, take_ok(A, r, j, i, er), Unit{})
    case R.State{Q.State{n, h, +r}, ts, ds, bs} R.Abandon{+j, w, at}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      abandon_inv(~A, i, anything(A), Q.take.list(A, r, j), n, h, R.tries.drop(ts, j), ds, bs, w, at, lt, eh, ok_rem(A, Q.take.list(A, r, j), i, take_ok(A, r, j, i, er)), Unit{})
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Revive{+j, d}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      revive_inv(~A, i, anything(A), R.dead.get(~A, ds, j), j, n, h, r, ts, R.dead.drop(~A, ds, j), bs, d, lt, eh, er, any_ok(A, R.dead.get(~A, ds, j), j, i, no), Unit{})
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Purge{t}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{eh, QL.Both{er, Unit{}}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.PurgeAll{}:
      QL.Both{lt, QL.Both{eh, QL.Both{er, ed}}} = g
      QL.Both{lt, QL.Both{eh, QL.Both{er, Unit{}}}}
    case R.State{Q.State{n, h, r}, ts, ds, bs} R.Break{k, b}:
      g

def or_false_left(a: Bool, b: Bool, e: {Bool.or(a, b) == False{} : Bool}) -> {a == False{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({True{} == False{} : Bool}, MNat.internal_false_ne_true(Equal.sym(Bool, True{}, False{}, e)))
    case False{}:
      {==}

def or_false_right(a: Bool, b: Bool, e: {Bool.or(a, b) == False{} : Bool}) -> {b == False{} : Bool}:
  match a:
    case True{}:
      Empty.absurd({b == False{} : Bool}, MNat.internal_false_ne_true(Equal.sym(Bool, True{}, False{}, e)))
    case False{}:
      e

def live_buried(~A: Data, +i: Nat, ops: List<&2, R.Op<A>>, +s: R.State<A>, g: inv(A, i, anything(A), s), +kept: {Laws.revives(A, ops, i) == False{} : Bool}) ->
    inv(A, i, anything(A), Laws.live(~A, ops, s)):
  match ops:
    case Nil{}:
      g
    case Con{op, +rest}:
      +op = op
      live_buried(~A, i, rest, R.step(~A, s, op), step_buried(~A, i, s, op, g, or_false_left(Laws.revived(A, op, i), Laws.revives(A, rest, i), kept)),
        or_false_right(Laws.revived(A, op, i), Laws.revives(A, rest, i), kept))

def absent_of_has(-A: Data, h: H.Heap<Q.Ticket<A>>, +i: Nat, +e: {Laws.has(A, h, i) == False{} : Bool}) -> QL.absent.heap(A, h, i):
  match h:
    case H.HLeaf{}:
      Unit{}
    case H.HNode{n, +t, +l, +r}:
      +rest = or_false_right(Nat.is_eq(Q.id(A, t), i), Bool.or(Laws.has(A, l, i), Laws.has(A, r, i)), e)
      QL.Both{or_false_left(Nat.is_eq(Q.id(A, t), i), Bool.or(Laws.has(A, l, i), Laws.has(A, r, i)), e),
        QL.Both{absent_of_has(A, l, i, or_false_left(Laws.has(A, l, i), Laws.has(A, r, i), rest)), absent_of_has(A, r, i, or_false_right(Laws.has(A, l, i), Laws.has(A, r, i), rest))}}

def finish_gone(~A: Data, +i: Nat, s: R.State<A>, fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s))), idle: {Laws.has(A, Q.pending(A, R.queue(A, s)), i) == False{} : Bool},
    alive: {R.dead.get(~A, R.dead(A, s), i) == None{} : Maybe<&2, R.Dead<A>>}, wf: {Laws.dead.wf(~A, R.dead(A, s)) == True{} : Bool}) -> gone(~A, i, R.step(~A, s, R.Complete{i})):
  match s:
    case R.State{Q.State{n, +h, +r}, ts, ds, bs}:
      complete_inv(~A, i, P.gone(~A, i), Q.take.list(A, r, i), n, h, R.tries.drop(ts, i), ds, bs, fresh, absent_of_has(A, h, i, idle), take_absent(A, r, i), QL.Both{alive, wf})

def cancel_gone(~A: Data, +i: Nat, s: R.State<A>, fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s))), wf: {Laws.dead.wf(~A, R.dead(A, s)) == True{} : Bool}) ->
    gone(~A, i, R.step(~A, s, R.Cancel{i})):
  match s:
    case R.State{Q.State{n, +h, +r}, ts, +ds, bs}:
      QL.Both{fresh, QL.Both{QP.remove_absent.heap(~A, h, i), QL.Both{QP.remove_absent.list(A, r, i), drop_self(~A, ds, i, wf)}}}

def abandon_buried(~A: Data, +i: Nat, s: R.State<A>, w: R.Why, +at: Nat, fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s))), idle: {Laws.has(A, Q.pending(A, R.queue(A, s)), i) == False{} : Bool}) ->
    inv(A, i, anything(A), R.step(~A, s, R.Abandon{i, w, at})):
  match s:
    case R.State{Q.State{n, +h, +r}, ts, ds, bs}:
      abandon_inv(~A, i, anything(A), Q.take.list(A, r, i), n, h, R.tries.drop(ts, i), ds, bs, w, at, fresh, absent_of_has(A, h, i, idle), take_absent(A, r, i), Unit{})

def selected_same(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>) -> {QL.selected(A, r) == Laws.selected(A, r) : Maybe<&2, Q.Ticket<A>>}:
  match r:
    case (q, t):
      {==}

# A Select from a state where i is neither pending nor running never takes i.
def never(~A: Data, +now: Nat, +i: Nat, -P: R.Graves(A) -> Data, s: R.State<A>, g: inv(A, i, P, s), t: Q.Ticket<A>, e: {Laws.next(~A, now, s) == Some{t} : Maybe<&2, Q.Ticket<A>>}) ->
    {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}:
  match s:
    case R.State{Q.State{+n, +h, +r}, ts, ds, bs}:
      QL.Both{lt, QL.Both{eh, rest}} = g
      %e : QP.selected_absent(A, i, _)
      %selected_same(A, Q.select(~A, now, Q.State{n, h, r})) : QP.selected_absent(A, i, _)
      QP.select_selected_absent(~A, now, i, Q.State{n, h, r}, eh)

def Laws.complete_never_selected(A, i, s, fresh, idle, alive, wf, ops, now, t, e):
  +s = s
  +ops = ops
  never(~A, now, i, P.gone(~A, i), Laws.live(~A, ops, R.step(~A, s, R.Complete{i})), live_gone(~A, i, ops, R.step(~A, s, R.Complete{i}), finish_gone(~A, i, s, fresh, idle, alive, wf)), t, e)

def Laws.cancel_never_selected(A, i, s, fresh, wf, ops, now, t, e):
  +s = s
  +ops = ops
  never(~A, now, i, P.gone(~A, i), Laws.live(~A, ops, R.step(~A, s, R.Cancel{i})), live_gone(~A, i, ops, R.step(~A, s, R.Cancel{i}), cancel_gone(~A, i, s, fresh, wf)), t, e)

def Laws.dead_never_selected(A, i, s, fresh, idle, w, at, ops, kept, now, t, e):
  +s = s
  +w = w
  +at = at
  +ops = ops
  never(~A, now, i, anything(A), Laws.live(~A, ops, R.step(~A, s, R.Abandon{i, w, at})), live_buried(~A, i, ops, R.step(~A, s, R.Abandon{i, w, at}), abandon_buried(~A, i, s, w, at, fresh, idle), kept), t, e)

def unsome(-T: Data, d: T, m: Maybe<&2, T>) -> T:
  match m:
    case None{}:
      d
    case Some{x}:
      x

def some_inj(-T: Data, +a: T, b: T, e: {Some{a} == Some{b} : Maybe<&2, T>}) -> {a == b : T}:
  %e : {a == unsome(T, a, _) : T}
  {==}

def moved(~A: Data, +i: Nat, x: R.State<A>, y: R.State<A>, q: {x == y : R.State<A>}, g: gone(~A, i, x)) -> gone(~A, i, y):
  %q : gone(~A, i, _)
  g

def Laws.recovered_never_selected(A, X, enc, dec, round, i, s, fresh, idle, alive, wf, ops, r, back, now, t, e):
  +r = r
  +s1 = R.step(~A, s, R.Complete{i})
  +q = some_inj(R.State<A>, Laws.live(~A, ops, s1), r,
    Equal.trans(Maybe<&2, R.State<A>>, Some{Laws.live(~A, ops, s1)}, Laws.replayed(~A, ~X, ~enc, ~dec, ops, s1), Some{r},
      Equal.sym(Maybe<&2, R.State<A>>, Laws.replayed(~A, ~X, ~enc, ~dec, ops, s1), Some{Laws.live(~A, ops, s1)}, replay.go(~A, ~X, ~enc, ~dec, ~round, ops, s1)), back))
  never(~A, now, i, P.gone(~A, i), r, moved(~A, i, Laws.live(~A, ops, s1), r, q, live_gone(~A, i, ops, s1, finish_gone(~A, i, s, fresh, idle, alive, wf))), t, e)

# ---- every op keeps the dead-ticket trie well formed

def WF(~A: Data, ds: R.Graves(A)) -> Data:
  {Laws.dead.wf(~A, ds) == True{} : Bool}

def wf.enqueued(~A: Data, r: Q.State<A> & Nat, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), d: Nat, wf: WF(~A, ds)) -> WF(~A, R.dead(A, R.step.enqueued(A, r, ts, ds, bs, d))):
  match r:
    case (q, i):
      wf

def wf.selected(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), wf: WF(~A, ds)) -> WF(~A, R.dead(A, R.step.selected(A, r, ts, ds, bs))):
  match r:
    case (q, t):
      wf

def wf.requeued(~A: Data, r: Q.State<A> & Bool, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), wf: WF(~A, ds)) -> WF(~A, R.dead(A, R.step.requeued(A, r, ts, ds, bs))):
  match r:
    case (q, b):
      wf

def wf.completed(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), ds: R.Graves(A), bs: R.Breakers(), wf: WF(~A, ds)) -> WF(~A, R.dead(A, R.step.completed(A, r, ts, ds, bs))):
  match r:
    case (q, t):
      wf

def bury_wf(~A: Data, m: Maybe<&2, Q.Ticket<A>>, +ds: R.Graves(A), +w: R.Why, +at: Nat, +wf: WF(~A, ds)) -> WF(~A, R.dead.bury(~A, m, ds, w, at)):
  match m:
    case None{}:
      wf
    case Some{Q.Ticket{+k, +d, +x}}:
      CL.hmap_put_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ~MNat.is_eq_refl, ~MNat.eq_of_is_eq, ds, wf, k, R.Dead{Q.Ticket{k, d, x}, w, at})

def wf.abandoned(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: R.Tries(), +ds: R.Graves(A), bs: R.Breakers(), +w: R.Why, +at: Nat, +wf: WF(~A, ds)) ->
    WF(~A, R.dead(A, R.step.abandoned(~A, r, ts, ds, bs, w, at))):
  match r:
    case (q, t):
      bury_wf(~A, t, ds, w, at, wf)

def wf.revived(~A: Data, m: Maybe<&2, R.Dead<A>>, +j: Nat, n: Nat, h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: R.Tries(), rest: R.Graves(A), bs: R.Breakers(), +d: Nat,
    wf: WF(~A, rest)) -> WF(~A, R.dead(A, R.step.revived(~A, m, j, n, h, r, ts, rest, bs, d))):
  match m:
    case None{}:
      wf
    case Some{R.Dead{Q.Ticket{k, old, x}, w, at}}:
      wf

def drops_wf(~A: Data, ks: List<&2, Nat>, +ds: R.Graves(A), +wf: WF(~A, ds)) -> WF(~A, R.dead.drops(~A, ks, ds)):
  match ks:
    case Nil{}:
      wf
    case Con{+k, rest}:
      drops_wf(~A, rest, R.dead.drop(~A, ds, k), CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, k))

def step_wf(~A: Data, s: R.State<A>, op: R.Op<A>, wf: WF(~A, R.dead(A, s))) -> WF(~A, R.dead(A, R.step(~A, s, op))):
  match s op:
    case R.State{q, ts, ds, bs} R.Enqueue{+d, x}:
      wf.enqueued(~A, Q.enqueue(~A, d, x, q), ts, ds, bs, d, wf)
    case R.State{q, ts, ds, bs} R.Select{now}:
      wf.selected(~A, Q.select(~A, now, q), ts, ds, bs, wf)
    case R.State{q, ts, ds, bs} R.Complete{+i}:
      wf.completed(~A, Q.complete(A, i, q), R.tries.drop(ts, i), ds, bs, wf)
    case R.State{q, ts, ds, bs} R.Cancel{+i}:
      CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, i)
    case R.State{q, ts, ds, bs} R.Requeue{+i, d}:
      wf.requeued(~A, Q.requeue(~A, i, d, q), R.tries.bump(ts, i), ds, bs, wf)
    case R.State{q, ts, ds, bs} R.Defer{i, d}:
      wf.requeued(~A, Q.requeue(~A, i, d, q), ts, ds, bs, wf)
    case R.State{q, ts, ds, bs} R.Abandon{+i, w, at}:
      wf.abandoned(~A, Q.complete(A, i, q), R.tries.drop(ts, i), ds, bs, w, at, wf)
    case R.State{Q.State{n, h, r}, ts, +ds, bs} R.Revive{+i, d}:
      wf.revived(~A, R.dead.get(~A, ds, i), i, n, h, r, ts, R.dead.drop(~A, ds, i), bs, d, CL.hmap_del_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds, wf, i))
    case R.State{q, ts, +ds, bs} R.Purge{t}:
      drops_wf(~A, R.dead.old(A, R.dead.list(A, ds), t), ds, wf)
    case R.State{q, ts, ds, bs} R.PurgeAll{}:
      {==}
    case R.State{q, ts, ds, bs} R.Break{k, b}:
      wf

def Laws.dead_wf(A, s, wf, op):
  step_wf(~A, s, op, wf)
