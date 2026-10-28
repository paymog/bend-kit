import Base
import bend-mathlib@0.7.4.0/nat.bend as MNat
import bend-kit-scheduler@0.4.1.0/queue.bend as Q
import bend-kit-collections@0.1.4.1/heap.bend as H
import bend-kit-collections@0.1.4.1/LAWS.bend as CL
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import ./runner.bend as R

# ---- replay

def encode.all(~A: Data, ~X: Type, ~enc: R.Op<A> -> X, ops: List<&2, R.Op<A>>) -> List<&1, X>:
  match ops:
    case Nil{}:
      Nil{}
    case Con{op, rest}:
      Con{enc(op), encode.all(~A, ~X, ~enc, rest)}

# The state after the live runner applies ops to s, one at a time.
def live(~A: Data, ops: List<&2, R.Op<A>>, s: R.State<A>) -> R.State<A>:
  match ops:
    case Nil{}:
      s
    case Con{op, rest}:
      live(~A, rest, R.step(~A, s, op))

# open's fold: each record into the replayed state, as J.replay folds the committed records.
def replay.from(~A: Data, ~X: Type, ~dec: X -> Maybe<&2, R.Op<A>>, xs: List<&1, X>, acc: Maybe<&2, R.State<A>>) -> Maybe<&2, R.State<A>>:
  match xs:
    case Nil{}:
      acc
    case Con{x, rest}:
      replay.from(~A, ~X, ~dec, rest, R.apply(~A, ~X, ~dec, acc, x))

# The state that open replays from the records of ops: the journal's committed records, in order.
def replayed(~A: Data, ~X: Type, ~enc: R.Op<A> -> X, ~dec: X -> Maybe<&2, R.Op<A>>, ops: List<&2, R.Op<A>>, s: R.State<A>) -> Maybe<&2, R.State<A>>:
  replay.from(~A, ~X, ~dec, encode.all(~A, ~X, ~enc, ops), Some{s})

# Replaying the records of any ops gives the state that applying them live gives, when every record decodes to its op.
law replay_live:
  for ~A: Data
  for ~X: Type
  for ~enc: R.Op<A> -> X
  for ~dec: X -> Maybe<&2, R.Op<A>>
  for ~round: @op: R.Op<A> -> {dec(enc(op)) == Some{op} : Maybe<&2, R.Op<A>>}
  for ops: List<&2, R.Op<A>>
  for s: R.State<A>
  {replayed(~A, ~X, ~enc, ~dec, ops, s) == Some{live(~A, ops, s)} : Maybe<&2, R.State<A>>}

# Recovery after a crash keeps the first k records of the journal. Replaying them gives the live state after those k ops.
law replay_prefix:
  for ~A: Data
  for ~X: Type
  for ~enc: R.Op<A> -> X
  for ~dec: X -> Maybe<&2, R.Op<A>>
  for ~round: @op: R.Op<A> -> {dec(enc(op)) == Some{op} : Maybe<&2, R.Op<A>>}
  for +ops: List<&2, R.Op<A>>
  for k: Nat
  for s: R.State<A>
  {replayed(~A, ~X, ~enc, ~dec, List.take(&2, R.Op<A>, ops, k), s) == Some{live(~A, List.take(&2, R.Op<A>, ops, k), s)} : Maybe<&2, R.State<A>>}

# ---- compaction

# open's fold: each record, a snapshot or an op, into the replayed state.
def restore.from(~A: Data, ~X: Type, ~dec: X -> Maybe<&2, R.Rec<A>>, xs: List<&1, X>, acc: Maybe<&2, R.State<A>>) -> Maybe<&2, R.State<A>>:
  match xs:
    case Nil{}:
      acc
    case Con{x, rest}:
      restore.from(~A, ~X, ~dec, rest, R.load(~A, ~X, ~dec, acc, x))

def encode.ops(~A: Data, ~X: Type, ~enc: R.Rec<A> -> X, ops: List<&2, R.Op<A>>) -> List<&1, X>:
  match ops:
    case Nil{}:
      Nil{}
    case Con{op, rest}:
      Con{enc(R.Do{op}), encode.ops(~A, ~X, ~enc, rest)}

# The journal after compaction: the snapshot of the state that ops gave from s, then the records of the ops after it.
def compacted(~A: Data, ~X: Type, ~enc: R.Rec<A> -> X, ops: List<&2, R.Op<A>>, s: R.State<A>, more: List<&2, R.Op<A>>) -> List<&1, X>:
  Con{enc(R.Snap{live(~A, ops, s)}), encode.ops(~A, ~X, ~enc, more)}

# Replaying a snapshot of live(ops, s) and then more gives live(more, live(ops, s)), whatever state the replay starts from.
law replay_snapshot:
  for ~A: Data
  for ~X: Type
  for ~enc: R.Rec<A> -> X
  for ~dec: X -> Maybe<&2, R.Rec<A>>
  for ~round: @r: R.Rec<A> -> {dec(enc(r)) == Some{r} : Maybe<&2, R.Rec<A>>}
  for +ops: List<&2, R.Op<A>>
  for +s: R.State<A>
  for more: List<&2, R.Op<A>>
  for t: R.State<A>
  {restore.from(~A, ~X, ~dec, compacted(~A, ~X, ~enc, ops, s, more), Some{t}) == Some{live(~A, more, live(~A, ops, s))} : Maybe<&2, R.State<A>>}

# ---- a finished ticket is never selected again

def selected(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>) -> Maybe<&2, Q.Ticket<A>>:
  (q, t) = r
  t

# The ticket that a Select at now takes from s.
def next(~A: Data, now: Nat, s: R.State<A>) -> Maybe<&2, Q.Ticket<A>>:
  selected(A, Q.select(~A, now, R.queue(A, s)))

# Whether a ticket with id i is in heap h.
def has(-A: Data, h: H.Heap<Q.Ticket<A>>, +i: Nat) -> Bool:
  match h:
    case H.HLeaf{}:
      False{}
    case H.HNode{n, t, l, r}:
      Bool.or(Nat.is_eq(Q.id(A, t), i), Bool.or(has(A, l, i), has(A, r, i)))

# The dead-ticket trie is well formed, as collections defines it: R.new's is, and dead_wf shows that every op keeps it so.
def dead.wf(~A: Data, ds: R.Graves(A)) -> Bool:
  CL.hmap_wf(~Nat, ~R.Dead<A>, ~R.dead.hash, ~Nat.is_eq, ds)

# Ticket i was running in s when it completed: issued (below s's next id), not pending, and not dead.
# Complete then takes it from the running list, and any ops run after.
law complete_never_selected:
  for ~A: Data
  for +i: Nat
  for s: R.State<A>
  for fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s)))
  for idle: {has(A, Q.pending(A, R.queue(A, s)), i) == False{} : Bool}
  for alive: {R.dead.get(~A, R.dead(A, s), i) == None{} : Maybe<&2, R.Dead<A>>}
  for wf: {dead.wf(~A, R.dead(A, s)) == True{} : Bool}
  for ops: List<&2, R.Op<A>>
  for now: Nat
  for t: Q.Ticket<A>
  for e: {next(~A, now, live(~A, ops, R.step(~A, s, R.Complete{i}))) == Some{t} : Maybe<&2, Q.Ticket<A>>}
  {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}

# Cancel takes ticket i from every registry, so it needs no hypothesis but issue and a well-formed trie.
law cancel_never_selected:
  for ~A: Data
  for +i: Nat
  for s: R.State<A>
  for fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s)))
  for wf: {dead.wf(~A, R.dead(A, s)) == True{} : Bool}
  for ops: List<&2, R.Op<A>>
  for now: Nat
  for t: Q.Ticket<A>
  for e: {next(~A, now, live(~A, ops, R.step(~A, s, R.Cancel{i}))) == Some{t} : Maybe<&2, Q.Ticket<A>>}
  {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}

# The same after a crash: the state that open replays from the journal never selects a completed ticket.
law recovered_never_selected:
  for ~A: Data
  for ~X: Type
  for ~enc: R.Op<A> -> X
  for ~dec: X -> Maybe<&2, R.Op<A>>
  for ~round: @op: R.Op<A> -> {dec(enc(op)) == Some{op} : Maybe<&2, R.Op<A>>}
  for +i: Nat
  for +s: R.State<A>
  for fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s)))
  for idle: {has(A, Q.pending(A, R.queue(A, s)), i) == False{} : Bool}
  for alive: {R.dead.get(~A, R.dead(A, s), i) == None{} : Maybe<&2, R.Dead<A>>}
  for wf: {dead.wf(~A, R.dead(A, s)) == True{} : Bool}
  for +ops: List<&2, R.Op<A>>
  for r: R.State<A>
  for back: {replayed(~A, ~X, ~enc, ~dec, ops, R.step(~A, s, R.Complete{i})) == Some{r} : Maybe<&2, R.State<A>>}
  for now: Nat
  for t: Q.Ticket<A>
  for e: {next(~A, now, r) == Some{t} : Maybe<&2, Q.Ticket<A>>}
  {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}

# Whether op revives ticket i.
def revived(-A: Data, op: R.Op<A>, +i: Nat) -> Bool:
  match op:
    case R.Revive{j, d}:
      Nat.is_eq(j, i)
    case _:
      False{}

# Whether some op in ops revives ticket i.
def revives(-A: Data, ops: List<&2, R.Op<A>>, +i: Nat) -> Bool:
  match ops:
    case Nil{}:
      False{}
    case Con{+op, rest}:
      Bool.or(revived(A, op, i), revives(A, rest, i))

# Ticket i was running in s when retry gave up on it. It stays dead, and no Select takes it, until a Revive of i.
law dead_never_selected:
  for ~A: Data
  for +i: Nat
  for s: R.State<A>
  for fresh: MNat.lt(i, Q.next_id(A, R.queue(A, s)))
  for idle: {has(A, Q.pending(A, R.queue(A, s)), i) == False{} : Bool}
  for w: R.Why
  for at: Nat
  for ops: List<&2, R.Op<A>>
  for kept: {revives(A, ops, i) == False{} : Bool}
  for now: Nat
  for t: Q.Ticket<A>
  for e: {next(~A, now, live(~A, ops, R.step(~A, s, R.Abandon{i, w, at}))) == Some{t} : Maybe<&2, Q.Ticket<A>>}
  {Nat.is_eq(Q.id(A, t), i) == False{} : Bool}

# Every op keeps the dead-ticket trie well formed.
law dead_wf:
  for ~A: Data
  for s: R.State<A>
  for wf: {dead.wf(~A, R.dead(A, s)) == True{} : Bool}
  for op: R.Op<A>
  {dead.wf(~A, R.dead(A, R.step(~A, s, op))) == True{} : Bool}

# ---- the pool bounds the attempts

def pick.pool(-A: Data, k: R.Pick<A>) -> Res.Pool:
  match k:
    case R.Picked{p, t, g}:
      p
    case R.Idle{p}:
      p

# The units held after a pick that started from h: one more for a Picked ticket, none for Idle.
def pick.held(-A: Data, k: R.Pick<A>, h: Nat) -> Nat:
  match k:
    case R.Picked{p, t, g}:
      Nat.add(h, 1n)
    case R.Idle{p}:
      h

def release.pool(r: Res.Release) -> Res.Pool:
  match r:
    case Res.Released{p}:
      p
    case Res.Kept{p, g}:
      p

# The pool after the picked ticket's grant goes back.
def pick.round(-A: Data, k: R.Pick<A>) -> Res.Pool:
  match k:
    case R.Picked{p, t, g}:
      release.pool(Res.release(p, g))
    case R.Idle{p}:
      p

# Each attempt holds exactly one unit of the pool.
law pick_holds_one:
  for ~A: Data
  for o: Nat
  for c: Nat
  for +h: Nat
  for +s: R.State<A>
  for +now: Nat
  {Res.reserved(pick.pool(A, R.pick(~A, Res.Pool{o, c, h}, s, now))) == pick.held(A, R.pick(~A, Res.Pool{o, c, h}, s, now), h) : Nat}

# The attempts that hold units never exceed the capacity.
law pick_bounded:
  for ~A: Data
  for o: Nat
  for c: Nat
  for h: Nat
  for e: MNat.le(h, c)
  for s: R.State<A>
  for now: Nat
  MNat.le(Res.reserved(pick.pool(A, R.pick(~A, Res.Pool{o, c, h}, s, now))), c)

# The grant of an attempt goes back once, and the pool is then as it was.
law pick_release:
  for ~A: Data
  for o: Nat
  for c: Nat
  for h: Nat
  for s: R.State<A>
  for now: Nat
  {pick.round(A, R.pick(~A, Res.Pool{o, c, h}, s, now)) == Res.Pool{o, c, h} : Res.Pool}

# ---- a failed attempt waits retry's wait

# A requeued ticket's deadline is now plus the wait that retry.plan gives.
law requeue_wait:
  for -A: Data
  for o: Retry.Outcome
  for p: Retry.Policy
  for b: Retry.Budget
  for +id: Nat
  for +n: Nat
  for +now: Nat
  for +r: Nat
  for w: Nat
  for e: {Retry.plan(o, p, b, n, now, r) == Retry.PlanWait{w} : Retry.Plan}
  {R.after(A, o, p, b, id, n, now, r) == R.Requeue{id, Nat.add(now, w)} : R.Op<A>}

# A settled attempt completes its ticket.
law settled_complete:
  for -A: Data
  for p: Retry.Policy
  for b: Retry.Budget
  for +id: Nat
  for +n: Nat
  for +now: Nat
  for +r: Nat
  {R.after(A, Retry.Settled{}, p, b, id, n, now, r) == R.Complete{id} : R.Op<A>}

# An unsafe failure must not repeat, so its ticket is dead from now.
law unsafe_abandon:
  for -A: Data
  for p: Retry.Policy
  for b: Retry.Budget
  for +id: Nat
  for +n: Nat
  for +now: Nat
  for +r: Nat
  {R.after(A, Retry.Unsafe{}, p, b, id, n, now, r) == R.Abandon{id, R.WhyUnsafe{}, now} : R.Op<A>}

# Another try would repeat the failure, so its ticket is dead after this attempt.
law failed_abandon:
  for -A: Data
  for p: Retry.Policy
  for b: Retry.Budget
  for +id: Nat
  for +n: Nat
  for +now: Nat
  for +r: Nat
  {R.after(A, Retry.Failed{}, p, b, id, n, now, r) == R.Abandon{id, R.WhyFailed{}, now} : R.Op<A>}

# A client error, such as a 404, would repeat, so its ticket is dead after this attempt.
law rejected_abandon:
  for -A: Data
  for p: Retry.Policy
  for b: Retry.Budget
  for +id: Nat
  for +n: Nat
  for +now: Nat
  for +r: Nat
  {R.after(A, Retry.Rejected{}, p, b, id, n, now, r) == R.Abandon{id, R.WhyFailed{}, now} : R.Op<A>}

# A client error is not the target's failure: its breaker moves as on a success.
law rejected_spares_breaker:
  for +c: Retry.Circuit
  for s: Retry.State
  for +now: Nat
  {R.brk.after(c, s, now, Retry.Rejected{}) == R.brk.after(c, s, now, Retry.Settled{}) : Retry.Breaker}

# So a run of client errors never opens a closed breaker.
law rejected_keeps_closed:
  for +c: Retry.Circuit
  for fs: List<&2, Nat>
  for +now: Nat
  {R.brk.after(c, Retry.CircuitClosed{fs}, now, Retry.Rejected{}) == Retry.BreakerOn{c, Retry.CircuitClosed{Nil{}}} : Retry.Breaker}

# When retry.plan stops a transient failure, its ticket is dead: spent when no attempt is left, else late.
law transient_abandon:
  for -A: Data
  for a: Maybe<&2, Nat>
  for p: Retry.Policy
  for b: Retry.Budget
  for +id: Nat
  for +n: Nat
  for +now: Nat
  for +r: Nat
  for e: {Retry.plan(Retry.Transient{a}, p, b, n, now, r) == Retry.PlanStop{} : Retry.Plan}
  {R.after(A, Retry.Transient{a}, p, b, id, n, now, r) == R.Abandon{id, R.gave(b), now} : R.Op<A>}
