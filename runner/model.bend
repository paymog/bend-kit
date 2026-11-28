# Pure runner state transitions, retry decisions, and journal codecs.
import Base
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-encoding@0.5.0.3/encoding.bend as Encoding
import bend-kit-scheduler@0.4.4.0/queue.bend as Q
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-collections@0.1.6.0/heap.bend as H
import bend-kit-collections@0.1.6.0/omap.bend as O
import bend-kit-collections@0.1.6.0/hmap.bend as M
import bend-kit-collections@0.1.6.0/LAWS.bend as CL
import bend-kit-collections@0.1.6.0/PROOF.bend as CP
import bend-kit-collections@0.1.6.0/order.bend as Order

# Why retry gave up on a ticket: its budget was spent, its deadline passed, its failure must not repeat,
# or another try would repeat its failure.
type Why is Data:
  WhySpent{}
  WhyLate{}
  WhyUnsafe{}
  WhyFailed{}

# A ticket that retry gave up on, with its payload, and when it gave up (wall-clock ms).
# It stays until Revive, Cancel, or Purge takes it.
type Dead<-A: Data> is Data:
  Dead{ticket: Q.Ticket<A>, why: Why, at: Nat}

# One durable transition. Each one is one journal record, appended before the state changes.
# Select: the queue's select at now. Replay runs it at the same now, so it takes the same ticket.
# Requeue: the attempt failed; it counts one failure. Defer: the breaker held the ticket back; no attempt ran.
# Abandon: retry gave up at at; the running ticket becomes dead. Revive: a dead ticket is pending again at deadline, with a new budget.
# Purge: the dead tickets abandoned before before are dropped. PurgeAll: every dead ticket is dropped.
# Break: the breaker of target changed to state.
type Op<-A: Data> is Data:
  Enqueue{deadline: Nat, payload: A}
  Select{now: Nat}
  Complete{id: Nat}
  Cancel{id: Nat}
  Requeue{id: Nat, deadline: Nat}
  Defer{id: Nat, deadline: Nat}
  Abandon{id: Nat, why: Why, at: Nat}
  Revive{id: Nat, deadline: Nat}
  Purge{before: Nat}
  PurgeAll{}
  Break{target: String, state: Retry.State}

# The failed attempts of a ticket, and its first deadline, from which the policy deadline counts.
type Try is Data:
  Try{fails: Nat, start: Nat}

# A Try for each ticket that is not yet complete, cancelled, or dead, by ticket id.
def Tries() -> Data:
  O.OMap<Nat, Try>

# The breaker state of each target that has one, by target. An absent target is closed with no failures.
def Breakers() -> Data:
  M.HMap<String, Retry.State>

def dead.hash(i: Nat) -> U32:
  U32.from_nat(i)

# The dead tickets, by ticket id.
def Graves(-A: Data) -> Data:
  M.HMap<Nat, Dead<A>>

# The durable state: the queue, the tries, the dead tickets, and the breakers.
type State<-A: Data> is Data:
  State{queue: Q.State<A>, tries: Tries(), dead: Graves(A), breakers: Breakers()}

def new(-A: Data) -> State<A>:
  State{Q.new(A), O.OMap.new(Nat, Try), M.HMap.new(Nat, Dead<A>), M.HMap.new(String, Retry.State)}

def queue(-A: Data, s: State<A>) -> Q.State<A>:
  State{q, ts, ds, bs} = s
  q

def tries(-A: Data, s: State<A>) -> Tries():
  State{q, ts, ds, bs} = s
  ts

# The dead tickets, by id. A Revive of one makes it pending again; a Cancel or a Purge drops it.
def dead(-A: Data, s: State<A>) -> Graves(A):
  State{q, ts, ds, bs} = s
  ds

def breakers(-A: Data, s: State<A>) -> Breakers():
  State{q, ts, ds, bs} = s
  bs

# ---- dead tickets

def dead.get(~A: Data, ds: Graves(A), +i: Nat) -> Maybe<&2, Dead<A>>:
  M.HMap.get(~Nat, ~Dead<A>, ~dead.hash, ~Nat.is_eq, ds, i)

def dead.drop(~A: Data, ds: Graves(A), +i: Nat) -> Graves(A):
  M.HMap.del(~Nat, ~Dead<A>, ~dead.hash, ~Nat.is_eq, ds, i)

def dead.bury(~A: Data, m: Maybe<&2, Q.Ticket<A>>, ds: Graves(A), w: Why, +at: Nat) -> Graves(A):
  match m:
    case None{}:
      ds
    case Some{Q.Ticket{+i, d, x}}:
      M.HMap.put(~Nat, ~Dead<A>, ~dead.hash, ~Nat.is_eq, ds, i, Dead{Q.Ticket{i, d, x}, w, at})

def dead.list.entries(-A: Data, es: List<&2, M.Entry<Nat, Dead<A>>>, acc: List<&2, Dead<A>>) -> List<&2, Dead<A>>:
  match es:
    case Nil{}:
      acc
    case Con{M.Entry{k, d}, rest}:
      dead.list.entries(A, rest, Con{d, acc})

def dead.list.go(-A: Data, ds: Graves(A), acc: List<&2, Dead<A>>) -> List<&2, Dead<A>>:
  match ds:
    case M.HNil{}:
      acc
    case M.HLeaf{h, es}:
      dead.list.entries(A, es, acc)
    case M.HBranch{lo, hi}:
      dead.list.go(A, lo, dead.list.go(A, hi, acc))

# The dead tickets, in no set order.
def dead.list(-A: Data, ds: Graves(A)) -> List<&2, Dead<A>>:
  dead.list.go(A, ds, Nil{})

def dead.old.keep(-A: Data, old: Bool, +i: Nat, rest: List<&2, Nat>) -> List<&2, Nat>:
  match old:
    case True{}:
      Con{i, rest}
    case False{}:
      rest

# The ids of the dead tickets abandoned before t.
def dead.old(-A: Data, ds: List<&2, Dead<A>>, +t: Nat) -> List<&2, Nat>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{Dead{Q.Ticket{i, d, x}, w, +at}, rest}:
      dead.old.keep(A, Nat.is_lt(at, t), i, dead.old(A, rest, t))

def dead.drops(~A: Data, ks: List<&2, Nat>, ds: Graves(A)) -> Graves(A):
  match ks:
    case Nil{}:
      ds
    case Con{k, rest}:
      dead.drops(~A, rest, dead.drop(~A, ds, k))

# The dead tickets without those abandoned before t. It walks every dead ticket once.
def dead.purge(~A: Data, +ds: Graves(A), +t: Nat) -> Graves(A):
  dead.drops(~A, dead.old(A, dead.list(A, ds), t), ds)

# ---- tries

def tries.drop(ts: Tries(), +i: Nat) -> Tries():
  O.OMap.del(~Nat, ~Try, ~Nat.cmp, ts, i)

def tries.get(ts: Tries(), +i: Nat) -> Maybe<&2, Try>:
  O.OMap.get(~Nat, ~Try, ~Nat.cmp, ts, i)

def tries.bump.got(m: Maybe<&2, Try>, ts: Tries(), +i: Nat) -> Tries():
  match m:
    case None{}:
      ts
    case Some{Try{f, st}}:
      O.OMap.put(~Nat, ~Try, ~Nat.cmp, ts, i, Try{1n+f, st})

def tries.bump(+ts: Tries(), +i: Nat) -> Tries():
  tries.bump.got(tries.get(ts, i), ts, i)

# ---- breakers

def brk.hash.go(key: String, acc: U32) -> U32:
  match key:
    case SNil{}:
      acc
    case SCon{Chr{c}, rest}:
      brk.hash.go(rest, ((acc .^. c) * 16777619 : U32))

def brk.hash(key: String) -> U32:
  brk.hash.go(key, 2166136261)

def brk.eq(a: String, b: String) -> Bool:
  Cmp.is_eq(Order.string(a, b))

def brk.got(m: Maybe<&2, Retry.State>) -> Retry.State:
  match m:
    case None{}:
      Retry.CircuitClosed{Nil{}}
    case Some{b}:
      b

def brk.get(-A: Data, s: State<A>, key: String) -> Retry.State:
  brk.got(M.HMap.get(~String, ~Retry.State, ~brk.hash, ~brk.eq, breakers(A, s), key))

def brk.state(br: Retry.Breaker, old: Retry.State) -> Retry.State:
  match br:
    case Retry.BreakerOff{}:
      old
    case Retry.BreakerOn{c, st}:
      st

def brk.nats(a: List<&2, Nat>, b: List<&2, Nat>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{+x, xs} Con{+y, ys}:
      Bool.and(Nat.is_eq(x, y), brk.nats(xs, ys))
    case p q:
      False{}

def brk.same(a: Retry.State, b: Retry.State) -> Bool:
  match a b:
    case Retry.CircuitClosed{xs} Retry.CircuitClosed{ys}:
      brk.nats(xs, ys)
    case Retry.CircuitOpen{+x} Retry.CircuitOpen{+y}:
      Nat.is_eq(x, y)
    case Retry.CircuitHalf{+x} Retry.CircuitHalf{+y}:
      Nat.is_eq(x, y)
    case p q:
      False{}

def calm.state(b: Retry.State) -> Retry.State:
  match b:
    case Retry.CircuitClosed{fs}:
      Retry.CircuitClosed{fs}
    case Retry.CircuitOpen{u}:
      Retry.CircuitOpen{u}
    case Retry.CircuitHalf{k}:
      Retry.CircuitHalf{0n}

def calm.entries(es: List<&2, M.Entry<String, Retry.State>>) -> List<&2, M.Entry<String, Retry.State>>:
  match es:
    case Nil{}:
      Nil{}
    case Con{M.Entry{k, b}, rest}:
      M.Entry{k, calm.state(b)} <> calm.entries(rest)

def calm.map(m: Breakers()) -> Breakers():
  match m:
    case M.HNil{}:
      M.HNil{}
    case M.HLeaf{h, es}:
      M.HLeaf{h, calm.entries(es)}
    case M.HBranch{lo, hi}:
      M.HBranch{calm.map(lo), calm.map(hi)}

# The probes of a half-open breaker died with the process that ran them, so open counts none in flight.
def calm(-A: Data, s: State<A>) -> State<A>:
  State{q, ts, ds, bs} = s
  State{q, ts, ds, calm.map(bs)}

# ---- the transition

def step.enqueued(-A: Data, r: Q.State<A> & Nat, ts: Tries(), ds: Graves(A), bs: Breakers(), d: Nat) -> State<A>:
  (q, i) = r
  State{q, O.OMap.put(~Nat, ~Try, ~Nat.cmp, ts, i, Try{0n, d}), ds, bs}

def step.selected(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: Tries(), ds: Graves(A), bs: Breakers()) -> State<A>:
  (q, t) = r
  State{q, ts, ds, bs}

def step.requeued(-A: Data, r: Q.State<A> & Bool, ts: Tries(), ds: Graves(A), bs: Breakers()) -> State<A>:
  (q, b) = r
  State{q, ts, ds, bs}

# Complete takes the ticket from the running list only: O(running), not O(pending).
def step.completed(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: Tries(), ds: Graves(A), bs: Breakers()) -> State<A>:
  (q, t) = r
  State{q, ts, ds, bs}

# Abandon takes the ticket from the running list, as Complete does, and keeps it with its payload.
def step.abandoned(~A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: Tries(), ds: Graves(A), bs: Breakers(), w: Why, +at: Nat) -> State<A>:
  (q, t) = r
  State{q, ts, dead.bury(~A, t, ds, w, at), bs}

# The revived ticket keeps its payload and takes id i, the key it was dead under.
def step.revived(~A: Data, m: Maybe<&2, Dead<A>>, +i: Nat, n: Nat, h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: Tries(), ds: Graves(A), bs: Breakers(), +d: Nat) -> State<A>:
  match m:
    case None{}:
      State{Q.State{n, h, r}, ts, ds, bs}
    case Some{Dead{Q.Ticket{k, old, x}, w, at}}:
      State{Q.State{n, H.Heap.push(~Q.Ticket<A>, ~(a => b => Q.le(A, a, b)), Q.Ticket{i, d, x}, h), r}, O.OMap.put(~Nat, ~Try, ~Nat.cmp, ts, i, Try{0n, d}), dead.drop(~A, ds, i), bs}

# A closed breaker with no failures reads the same as an absent one, so it leaves the map.
def step.broke(bs: Breakers(), k: String, b: Retry.State) -> Breakers():
  match b:
    case Retry.CircuitClosed{Nil{}}:
      M.HMap.del(~String, ~Retry.State, ~brk.hash, ~brk.eq, bs, k)
    case b:
      M.HMap.put(~String, ~Retry.State, ~brk.hash, ~brk.eq, bs, k, b)

# The state after op. Live and replay both run it, so they agree.
def step(~A: Data, s: State<A>, op: Op<A>) -> State<A>:
  match s op:
    case State{q, ts, ds, bs} Enqueue{+d, x}:
      step.enqueued(A, Q.enqueue(~A, d, x, q), ts, ds, bs, d)
    case State{q, ts, ds, bs} Select{now}:
      step.selected(A, Q.select(~A, now, q), ts, ds, bs)
    case State{q, ts, ds, bs} Complete{+i}:
      step.completed(A, Q.complete(A, i, q), tries.drop(ts, i), ds, bs)
    case State{q, ts, ds, bs} Cancel{+i}:
      State{Q.cancel(~A, i, q), tries.drop(ts, i), dead.drop(~A, ds, i), bs}
    case State{q, ts, ds, bs} Requeue{+i, d}:
      step.requeued(A, Q.requeue(~A, i, d, q), tries.bump(ts, i), ds, bs)
    case State{q, ts, ds, bs} Defer{i, d}:
      step.requeued(A, Q.requeue(~A, i, d, q), ts, ds, bs)
    case State{q, ts, ds, bs} Abandon{+i, w, at}:
      step.abandoned(~A, Q.complete(A, i, q), tries.drop(ts, i), ds, bs, w, at)
    case State{Q.State{n, h, r}, ts, +ds, bs} Revive{+i, d}:
      step.revived(~A, dead.get(~A, ds, i), i, n, h, r, ts, ds, bs, d)
    case State{q, ts, ds, bs} Purge{t}:
      State{q, ts, dead.purge(~A, ds, t), bs}
    case State{q, ts, ds, bs} PurgeAll{}:
      State{q, ts, M.HMap.new(Nat, Dead<A>), bs}
    case State{q, ts, ds, bs} Break{k, b}:
      State{q, ts, ds, step.broke(bs, k, b)}

def apply.op(~A: Data, m: Maybe<&2, Op<A>>, s: State<A>) -> Maybe<&2, State<A>>:
  match m:
    case None{}:
      None{}
    case Some{op}:
      Some{step(~A, s, op)}

# Folds one record into the replayed state. A record that does not decode ends the replay with None.
def apply(~A: Data, ~R: Type, ~dec: R -> Maybe<&2, Op<A>>, acc: Maybe<&2, State<A>>, r: R) -> Maybe<&2, State<A>>:
  match acc:
    case None{}:
      None{}
    case Some{s}:
      apply.op(~A, dec(r), s)

# A journal record. Compaction writes one Snap of the whole state; every other record is one op.
type Rec<-A: Data> is Data:
  Snap{state: State<A>}
  Do{op: Op<A>}

def load.rec(~A: Data, m: Maybe<&2, Rec<A>>, s: State<A>) -> Maybe<&2, State<A>>:
  match m:
    case None{}:
      None{}
    case Some{Snap{t}}:
      Some{t}
    case Some{Do{op}}:
      Some{step(~A, s, op)}

# Folds one record into the replayed state: a Snap replaces it, and an op steps it, as apply does.
# A record that does not decode ends the replay with None.
def load(~A: Data, ~R: Type, ~dec: R -> Maybe<&2, Rec<A>>, acc: Maybe<&2, State<A>>, r: R) -> Maybe<&2, State<A>>:
  match acc:
    case None{}:
      None{}
    case Some{s}:
      load.rec(~A, dec(r), s)

# ---- pool

# Picked: a due ticket and one unit of the pool for it. Idle: no due ticket, or no free unit; the pool is unchanged.
type Pick<-A: Data> is Type:
  Picked{pool: Res.Pool, ticket: Q.Ticket<A>, grant: Res.Grant}
  Idle{pool: Res.Pool}

def pick.took(-A: Data, r: Res.Reserve, t: Q.Ticket<A>) -> Pick<A>:
  match r:
    case Res.Took{p, g}:
      Picked{p, t, g}
    case Res.Refused{p}:
      Idle{p}

def pick.due(-A: Data, m: Maybe<&2, Q.Ticket<A>>, p: Res.Pool) -> Pick<A>:
  match m:
    case None{}:
      Idle{p}
    case Some{t}:
      pick.took(A, Res.reserve(p, 1n), t)

def pick.sel(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, p: Res.Pool) -> Pick<A>:
  (q, m) = r
  pick.due(A, m, p)

# The ticket that Select{now} takes, with one unit of p, when there is a ticket due and a unit free.
def pick(~A: Data, p: Res.Pool, s: State<A>, now: Nat) -> Pick<A>:
  State{q, ts, ds, bs} = s
  pick.sel(A, Q.select(~A, now, q), p)

# A flight holds one unit; its affine grant is retained by the runtime.
type Loop<-A: Data> is Data:
  Loop{pool: Res.Pool, state: State<A>, flights: List<&2, Q.Ticket<A>>}

type LoopEvent is Data:
  Claim{now: Nat}
  Finish{id: Nat}
  CancelFlight{id: Nat}
  RetrySettle{id: Nat, due: Nat}

def loop.pool(-A: Data, s: Loop<A>) -> Res.Pool:
  Loop{p, s, fs} = s
  p

def loop.state(-A: Data, s: Loop<A>) -> State<A>:
  Loop{p, s, fs} = s
  s

def loop.flights(-A: Data, s: Loop<A>) -> List<&2, Q.Ticket<A>>:
  Loop{p, s, fs} = s
  fs

def loop.release(r: Res.Release) -> Res.Pool:
  match r:
    case Res.Released{p}:
      p
    case Res.Kept{p, g}:
      p

def loop.claim(~A: Data, k: Pick<A>, s: State<A>, fs: List<&2, Q.Ticket<A>>, now: Nat) -> Loop<A>:
  match k:
    case Idle{p}:
      Loop{p, s, fs}
    case Picked{p, +t, g}:
      Loop{p, step(~A, s, Select{now}), Con{t, fs}}

def loop.finished(~A: Data, tk: Q.Taken<A>, p: Res.Pool, s: State<A>, +i: Nat) -> Loop<A>:
  match tk p:
    case Q.Taken{fs, None{}} Res.Pool{o, c, h}:
      Loop{Res.Pool{o, c, h}, s, fs}
    case Q.Taken{fs, Some{t}} Res.Pool{+o, c, h}:
      Loop{loop.release(Res.release(Res.Pool{o, c, h}, Res.Grant{o, 1n})), step(~A, s, Complete{i}), fs}

def loop.retried(~A: Data, tk: Q.Taken<A>, p: Res.Pool, s: State<A>, +i: Nat, d: Nat) -> Loop<A>:
  match tk p:
    case Q.Taken{fs, None{}} Res.Pool{o, c, h}:
      Loop{Res.Pool{o, c, h}, s, fs}
    case Q.Taken{fs, Some{t}} Res.Pool{+o, c, h}:
      Loop{loop.release(Res.release(Res.Pool{o, c, h}, Res.Grant{o, 1n})), step(~A, s, Requeue{i, d}), fs}

def loop.step(~A: Data, e: LoopEvent, s: Loop<A>) -> Loop<A>:
  match e s:
    case Claim{+now} Loop{p, +s, fs}:
      loop.claim(~A, pick(~A, p, s, now), s, fs, now)
    case Finish{+i} Loop{p, s, fs}:
      loop.finished(~A, Q.take.list(A, fs, i), p, s, i)
    case CancelFlight{+i} Loop{p, s, fs}:
      Loop{p, step(~A, s, Cancel{i}), fs}
    case RetrySettle{+i, d} Loop{p, s, fs}:
      loop.retried(~A, Q.take.list(A, fs, i), p, s, i, d)

def loop.fold(~A: Data, es: List<&2, LoopEvent>, s: Loop<A>) -> Loop<A>:
  match es:
    case Nil{}:
      s
    case Con{e, rest}:
      loop.fold(~A, rest, loop.step(~A, e, s))

# ---- retry

# The budget left for ticket i: the policy's attempts less its failures, until its start plus the policy deadline.
def budget.of(+attempts: Nat, t: Maybe<&2, Try>, d: Maybe<&2, Nat>) -> Retry.Budget:
  match t d:
    case None{} m:
      Retry.Budget{attempts, None{}}
    case Some{Try{f, st}} None{}:
      Retry.Budget{Nat.sub(attempts, f), None{}}
    case Some{Try{f, +st}} Some{ms}:
      Retry.Budget{Nat.sub(attempts, f), Some{Nat.add(st, ms)}}

def budget(p: Retry.Policy, t: Maybe<&2, Try>) -> Retry.Budget:
  Retry.Policy{a, base, cap, d} = p
  budget.of(a, t, d)

# The failures so far: the index of the next retry.
def fails(t: Maybe<&2, Try>) -> Nat:
  match t:
    case None{}:
      0n
    case Some{Try{f, st}}:
      f

# Why retry stopped a transient failure: no attempt is left, or the next wait would reach the deadline.
def gave(b: Retry.Budget) -> Why:
  Retry.Budget{left, d} = b
  match left:
    case 0n:
      WhySpent{}
    case 1n+k:
      WhyLate{}

# A settled attempt completes its ticket; retry gave up at now on any other.
def stopped(-A: Data, o: Retry.Outcome, b: Retry.Budget, +id: Nat, +now: Nat) -> Op<A>:
  match o:
    case Retry.Settled{}:
      Complete{id}
    case Retry.Failed{}:
      Abandon{id, WhyFailed{}, now}
    case Retry.Rejected{}:
      Abandon{id, WhyFailed{}, now}
    case Retry.Unsafe{}:
      Abandon{id, WhyUnsafe{}, now}
    case Retry.Transient{w}:
      Abandon{id, gave(b), now}

def after.plan(-A: Data, pl: Retry.Plan, o: Retry.Outcome, b: Retry.Budget, +id: Nat, +now: Nat) -> Op<A>:
  match pl:
    case Retry.PlanStop{}:
      stopped(A, o, b, id, now)
    case Retry.PlanWait{w}:
      Requeue{id, Nat.add(now, w)}

# The record after an attempt of ticket id ends at now with o: requeue at now plus retry's wait,
# complete when o is settled, or abandon when retry gave up.
def after(-A: Data, +o: Retry.Outcome, p: Retry.Policy, +b: Retry.Budget, +id: Nat, +n: Nat, +now: Nat, +r: Nat) -> Op<A>:
  after.plan(A, Retry.plan(o, p, b, n, now, r), o, b, id, now)

# A target's breaker after an attempt ends at now with o.
def brk.after(+circ: Retry.Circuit, old: Retry.State, +now: Nat, o: Retry.Outcome) -> Retry.Breaker:
  Retry.Breaker.done(Retry.BreakerOn{circ, old}, now, Retry.failed(o))

# When an open breaker lets attempts start again.
def until(br: Retry.Breaker, +now: Nat) -> Nat:
  match br:
    case Retry.BreakerOn{c, Retry.CircuitOpen{u}}:
      u
    case Retry.BreakerOn{c, Retry.CircuitClosed{fs}}:
      Nat.add(now, Retry.Circuit.cooldown(c))
    case Retry.BreakerOn{c, Retry.CircuitHalf{k}}:
      Nat.add(now, Retry.Circuit.cooldown(c))
    case Retry.BreakerOff{}:
      now

# The record for a ticket that admit refused: Defer to when the breaker may admit, or Abandon when its budget is spent or late.
def held(-A: Data, why: Retry.Deny, br: Retry.Breaker, +id: Nat, +now: Nat) -> Op<A>:
  match why:
    case Retry.DenyOpen{}:
      Defer{id, until(br, now)}
    case Retry.DenyLate{}:
      Abandon{id, WhyLate{}, now}
    case Retry.DenySpent{}:
      Abandon{id, WhySpent{}, now}

# ---- the record codec: a u32le tag, then u64le fields; an Enqueue then holds the payload.
# An Abandon is tag 8, then id, why.code, and at. A Purge is tag 11 and before; a PurgeAll is tag 12.
# A Break is tag 13, then its UTF-8 target and its breaker state.

def why.code(w: Why) -> Nat:
  match w:
    case WhySpent{}:
      0n
    case WhyLate{}:
      1n
    case WhyUnsafe{}:
      2n
    case WhyFailed{}:
      3n

def W() -> Nat:
  Nat.mul(65536n, 65536n)

# Nat fields hold values under 2^64.
def put.u64(b: Bytes.Bytes, +at: U32, +n: Nat) -> Bytes.Bytes:
  Bytes.set.u32le(Bytes.set.u32le(b, at, U32.from_nat(Nat.mod(n, W()))), (at + 4 : U32), U32.from_nat(Nat.div(n, W())))

def head(+tag: U32, +a: Nat, +c: Nat) -> Bytes.Bytes:
  put.u64(put.u64(Bytes.set.u32le(Bytes.new(20), 0, tag), 4, a), 12, c)

def snap.u32(out: Bytes.Bytes, +v: U32) -> Bytes.Bytes:
  Bytes.append(out, Bytes.set.u32le(Bytes.new(4), 0, v))

def snap.u64(out: Bytes.Bytes, +n: Nat) -> Bytes.Bytes:
  Bytes.append(out, put.u64(Bytes.new(8), 0, n))

def snap.key.bytes(out: Bytes.Bytes, b: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = b
  Bytes.append(snap.u32(out, len), Bytes.Bytes{len, buf})

# A target is a u32 octet length, then UTF-8 octets.
def snap.key(out: Bytes.Bytes, k: String) -> Bytes.Bytes:
  snap.key.bytes(out, Encoding.utf8.encode(k))

def snap.nats(xs: List<&2, Nat>, out: Bytes.Bytes) -> Bytes.Bytes:
  match xs:
    case Nil{}:
      out
    case Con{x, rest}:
      snap.nats(rest, snap.u64(out, x))

# A breaker state is a u32 kind. 0 is closed: a u32 count, then each failure as a u64. 1 is open: until. 2 is half-open: busy.
def snap.brk(out: Bytes.Bytes, b: Retry.State) -> Bytes.Bytes:
  match b:
    case Retry.CircuitClosed{+fs}:
      snap.nats(fs, snap.u32(snap.u32(out, 0), U32.from_nat(List.length(&2, Nat, fs))))
    case Retry.CircuitOpen{u}:
      snap.u64(snap.u32(out, 1), u)
    case Retry.CircuitHalf{k}:
      snap.u64(snap.u32(out, 2), k)

def encode(~A: Data, ~penc: A -> Bytes.Bytes, op: Op<A>) -> Bytes.Bytes:
  match op:
    case Enqueue{+d, x}:
      Bytes.append(put.u64(Bytes.set.u32le(Bytes.new(12), 0, 1), 4, d), penc(x))
    case Select{+now}:
      head(2, now, 0n)
    case Complete{+i}:
      head(3, i, 0n)
    case Cancel{+i}:
      head(4, i, 0n)
    case Requeue{+i, +d}:
      head(5, i, d)
    case Defer{+i, +d}:
      head(6, i, d)
    case Abandon{+i, w, +at}:
      Bytes.append(head(8, i, why.code(w)), put.u64(Bytes.new(8), 0, at))
    case Revive{+i, +d}:
      head(9, i, d)
    case Purge{+t}:
      head(11, t, 0n)
    case PurgeAll{}:
      head(12, 0n, 0n)
    case Break{k, b}:
      snap.brk(snap.key(snap.u32(Bytes.new(0), 13), k), b)

def get.field(m: Maybe<&2, U32>) -> U32:
  match m:
    case None{}:
      0
    case Some{x}:
      x

def get.u32(r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & U32:
  (b, m) = r
  (b, get.field(m))

def get.hi(+lo: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Nat:
  (b, m) = r
  (b, Nat.add(U32.to_nat(lo), Nat.mul(U32.to_nat(get.field(m)), W())))

def get.lo(+at: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Bytes.Bytes & Nat:
  (b, m) = r
  +lo = get.field(m)
  get.hi(lo, Bytes.get.u32le(b, (at + 4 : U32)))

def get.u64(b: Bytes.Bytes, +at: U32) -> Bytes.Bytes & Nat:
  get.lo(at, Bytes.get.u32le(b, at))

# ---- the snapshot codec: tag 14 and the next id, then the heap, the running list, the tries, the dead tickets, and the breakers.
# A u32 flag starts each tree node and list cell (1) and marks each end (0), so decode rebuilds the same shape.
# A ticket is its u64 id and deadline, then a u32 length and the payload.
# The dead tickets are a trie: each node is a u32 kind, 0 empty, 1 a bucket, or 2 a branch, then its lo and hi nodes.
# A bucket is its u32 hash, then a list of entries: the u64 key, the ticket, a u32 why.code, and the u64 abandon time.
# A breaker is its target, then its state, as in a Break record.

def snap.payload(out: Bytes.Bytes, p: Bytes.Bytes) -> Bytes.Bytes:
  Bytes.Bytes{+len, buf} = p
  Bytes.append(snap.u32(out, len), Bytes.Bytes{len, buf})

def snap.ticket(~A: Data, ~penc: A -> Bytes.Bytes, out: Bytes.Bytes, t: Q.Ticket<A>) -> Bytes.Bytes:
  Q.Ticket{+i, +d, x} = t
  snap.payload(snap.u64(snap.u64(out, i), d), penc(x))

def snap.heap(~A: Data, ~penc: A -> Bytes.Bytes, h: H.Heap<Q.Ticket<A>>, out: Bytes.Bytes) -> Bytes.Bytes:
  match h:
    case H.HLeaf{}:
      snap.u32(out, 0)
    case H.HNode{+n, t, l, r}:
      snap.heap(~A, ~penc, r, snap.heap(~A, ~penc, l, snap.ticket(~A, ~penc, snap.u64(snap.u32(out, 1), n), t)))

def snap.run(~A: Data, ~penc: A -> Bytes.Bytes, xs: List<&2, Q.Ticket<A>>, out: Bytes.Bytes) -> Bytes.Bytes:
  match xs:
    case Nil{}:
      snap.u32(out, 0)
    case Con{t, rest}:
      snap.run(~A, ~penc, rest, snap.ticket(~A, ~penc, snap.u32(out, 1), t))

def snap.tries(ts: Tries(), out: Bytes.Bytes) -> Bytes.Bytes:
  match ts:
    case O.OTip{}:
      snap.u32(out, 0)
    case O.OBin{+n, +k, Try{+f, +st}, lo, hi}:
      snap.tries(hi, snap.tries(lo, snap.u64(snap.u64(snap.u64(snap.u32(snap.u32(out, 1), n), k), f), st)))

def snap.entries(~A: Data, ~penc: A -> Bytes.Bytes, es: List<&2, M.Entry<Nat, Dead<A>>>, out: Bytes.Bytes) -> Bytes.Bytes:
  match es:
    case Nil{}:
      snap.u32(out, 0)
    case Con{M.Entry{k, Dead{t, w, at}}, rest}:
      snap.entries(~A, ~penc, rest, snap.u64(snap.u32(snap.ticket(~A, ~penc, snap.u64(snap.u32(out, 1), k), t), U32.from_nat(why.code(w))), at))

def snap.graves(~A: Data, ~penc: A -> Bytes.Bytes, ds: Graves(A), out: Bytes.Bytes) -> Bytes.Bytes:
  match ds:
    case M.HNil{}:
      snap.u32(out, 0)
    case M.HLeaf{h, es}:
      snap.entries(~A, ~penc, es, snap.u32(snap.u32(out, 1), h))
    case M.HBranch{lo, hi}:
      snap.graves(~A, ~penc, hi, snap.graves(~A, ~penc, lo, snap.u32(out, 2)))

def brk.entries.leaf(es: List<&2, M.Entry<String, Retry.State>>, acc: List<&2, Sigma<&2, &2, String, _ => Retry.State>>) -> List<&2, Sigma<&2, &2, String, _ => Retry.State>>:
  match es:
    case Nil{}:
      acc
    case Con{M.Entry{k, b}, rest}:
      (k, b) <> brk.entries.leaf(rest, acc)

def brk.entries(bs: Breakers(), acc: List<&2, Sigma<&2, &2, String, _ => Retry.State>>) -> List<&2, Sigma<&2, &2, String, _ => Retry.State>>:
  match bs:
    case M.HNil{}:
      acc
    case M.HLeaf{h, es}:
      brk.entries.leaf(es, acc)
    case M.HBranch{lo, hi}:
      brk.entries(lo, brk.entries(hi, acc))

def snap.brks(xs: List<&2, Sigma<&2, &2, String, _ => Retry.State>>, out: Bytes.Bytes) -> Bytes.Bytes:
  match xs:
    case Nil{}:
      snap.u32(out, 0)
    case Con{(k, b), rest}:
      snap.brks(rest, snap.brk(snap.key(snap.u32(out, 1), k), b))

# The Snap record of s.
def encode.snap(~A: Data, ~penc: A -> Bytes.Bytes, s: State<A>) -> Bytes.Bytes:
  State{Q.State{+n, h, run}, ts, ds, bs} = s
  snap.brks(brk.entries(bs, Nil{}),
    snap.graves(~A, ~penc, ds, snap.tries(ts, snap.run(~A, ~penc, run, snap.heap(~A, ~penc, h, snap.u64(snap.u32(Bytes.new(0), 14), n))))))

def encode.rec(~A: Data, ~penc: A -> Bytes.Bytes, r: Rec<A>) -> Bytes.Bytes:
  match r:
    case Snap{s}:
      encode.snap(~A, ~penc, s)
    case Do{op}:
      encode(~A, ~penc, op)

# A snapshot reader: the record, and the offset of the next field.
type Rd is Type:
  Rd{b: Bytes.Bytes, at: U32}

# One step of the snapshot decoder. None: a field runs past the record or does not decode.
def Dec(-T: Type) -> Type:
  Rd -> Maybe<&1, Rd & T>

def Dec.next(-A: Type, -B: Type, m: Maybe<&1, Rd & A>, f: A -> Dec(B)) -> Maybe<&1, Rd & B>:
  match m:
    case None{}:
      None{}
    case Some{(r, x)}:
      f(x)(r)

def Dec.bind(-A: Type, -B: Type, m: Dec(A), f: A -> Dec(B)) -> Dec(B):
  r => Dec.next(A, B, m(r), f)

def Dec.pure(-A: Type, x: A) -> Dec(A):
  r => Some{(r, x)}

def Dec.fail(-A: Type) -> Dec(A):
  r => None{}

def rd.u32.of(m: Maybe<&2, U32>, b: Bytes.Bytes, +at: U32) -> Maybe<&1, Rd & U32>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{(Rd{b, (at + 4 : U32)}, x)}

def rd.u32.got(+at: U32, r: Bytes.Bytes & Maybe<&2, U32>) -> Maybe<&1, Rd & U32>:
  (b, m) = r
  rd.u32.of(m, b, at)

def rd.u32.at(r: Rd) -> Maybe<&1, Rd & U32>:
  Rd{b, +at} = r
  rd.u32.got(at, Bytes.get.u32le(b, at))

def rd.u32() -> Dec(U32):
  r => rd.u32.at(r)

def rd.u64.of(+lo: U32, +hi: U32) -> Nat:
  Nat.add(U32.to_nat(lo), Nat.mul(U32.to_nat(hi), W()))

def rd.u64() -> Dec(Nat):
  do Dec<Nat>:
    lo : U32 <- rd.u32()
    hi : U32 <- rd.u32()
    return rd.u64.of(lo, hi)

def rd.cut.got(+at: U32, +n: U32, r: Bytes.Bytes & Bytes.Bytes) -> Maybe<&1, Rd & Bytes.Bytes>:
  (b, p) = r
  Some{(Rd{b, (at + n : U32)}, p)}

def rd.cut.if(ok: Bool, b: Bytes.Bytes, +at: U32, +n: U32) -> Maybe<&1, Rd & Bytes.Bytes>:
  match ok:
    case False{}:
      None{}
    case True{}:
      rd.cut.got(at, n, Bytes.slice(b, at, n))

def rd.cut.at(+n: U32, r: Rd) -> Maybe<&1, Rd & Bytes.Bytes>:
  Rd{Bytes.Bytes{+len, buf}, +at} = r
  rd.cut.if(Bytes.fits(len, at, n), Bytes.Bytes{len, buf}, at, n)

# The next n octets.
def rd.cut(+n: U32) -> Dec(Bytes.Bytes):
  r => rd.cut.at(n, r)

def rd.flag.of(+m: U32) -> Dec(Bool):
  Bool.pick(Dec(Bool), U32.is_eq(m, 0), Dec.pure(Bool, False{}), Bool.pick(Dec(Bool), U32.is_eq(m, 1), Dec.pure(Bool, True{}), Dec.fail(Bool)))

# A u32 flag: 1 is True, 0 is False, and any other value fails.
def rd.flag() -> Dec(Bool):
  Dec.bind(U32, Bool, rd.u32(), m => rd.flag.of(m))

def rd.payload(-A: Data, +i: Nat, +d: Nat, m: Maybe<&2, A>) -> Dec(Q.Ticket<A>):
  match m:
    case None{}:
      Dec.fail(Q.Ticket<A>)
    case Some{x}:
      Dec.pure(Q.Ticket<A>, Q.Ticket{i, d, x})

def rd.ticket(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>) -> Dec(Q.Ticket<A>):
  do Dec<Q.Ticket<A>>:
    i : Nat <- rd.u64()
    d : Nat <- rd.u64()
    n : U32 <- rd.u32()
    p : Bytes.Bytes <- rd.cut(n)
    rd.payload(A, i, d, pdec(p))

# Each rd.* tree reader takes the flag already read. fuel bounds the depth: every node holds at least one 4-octet flag.
def rd.heap(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +fuel: Nat, node: Bool) -> Dec(H.Heap<Q.Ticket<A>>):
  match fuel node:
    case 0n b:
      Dec.fail(H.Heap<Q.Ticket<A>>)
    case 1n+f False{}:
      Dec.pure(H.Heap<Q.Ticket<A>>, H.HLeaf{})
    case 1n+f True{}:
      do Dec<H.Heap<Q.Ticket<A>>>:
        n : Nat <- rd.u64()
        t : Q.Ticket<A> <- rd.ticket(~A, ~pdec)
        lf : Bool <- rd.flag()
        l : H.Heap<Q.Ticket<A>> <- rd.heap(~A, ~pdec, f, lf)
        rf : Bool <- rd.flag()
        r : H.Heap<Q.Ticket<A>> <- rd.heap(~A, ~pdec, f, rf)
        return H.HNode{n, t, l, r}

def rd.run(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +fuel: Nat, more: Bool) -> Dec(List<&2, Q.Ticket<A>>):
  match fuel more:
    case 0n b:
      Dec.fail(List<&2, Q.Ticket<A>>)
    case 1n+f False{}:
      Dec.pure(List<&2, Q.Ticket<A>>, Nil{})
    case 1n+f True{}:
      do Dec<List<&2, Q.Ticket<A>>>:
        t : Q.Ticket<A> <- rd.ticket(~A, ~pdec)
        m : Bool <- rd.flag()
        rest : List<&2, Q.Ticket<A>> <- rd.run(~A, ~pdec, f, m)
        return Con{t, rest}

def rd.tries(+fuel: Nat, node: Bool) -> Dec(O.OMap<Nat, Try>):
  match fuel node:
    case 0n b:
      Dec.fail(O.OMap<Nat, Try>)
    case 1n+f False{}:
      Dec.pure(O.OMap<Nat, Try>, O.OTip{})
    case 1n+f True{}:
      do Dec<O.OMap<Nat, Try>>:
        n : U32 <- rd.u32()
        k : Nat <- rd.u64()
        fails : Nat <- rd.u64()
        st : Nat <- rd.u64()
        lf : Bool <- rd.flag()
        lo : O.OMap<Nat, Try> <- rd.tries(f, lf)
        hf : Bool <- rd.flag()
        hi : O.OMap<Nat, Try> <- rd.tries(f, hf)
        return O.OBin{n, k, Try{fails, st}, lo, hi}

def rd.why(+c: U32) -> Dec(Why):
  Bool.pick(Dec(Why), U32.is_eq(c, 0), Dec.pure(Why, WhySpent{}),
  Bool.pick(Dec(Why), U32.is_eq(c, 1), Dec.pure(Why, WhyLate{}),
  Bool.pick(Dec(Why), U32.is_eq(c, 2), Dec.pure(Why, WhyUnsafe{}),
  Bool.pick(Dec(Why), U32.is_eq(c, 3), Dec.pure(Why, WhyFailed{}), Dec.fail(Why)))))

def rd.entries(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +fuel: Nat, more: Bool) -> Dec(List<&2, M.Entry<Nat, Dead<A>>>):
  match fuel more:
    case 0n b:
      Dec.fail(List<&2, M.Entry<Nat, Dead<A>>>)
    case 1n+f False{}:
      Dec.pure(List<&2, M.Entry<Nat, Dead<A>>>, Nil{})
    case 1n+f True{}:
      do Dec<List<&2, M.Entry<Nat, Dead<A>>>>:
        k : Nat <- rd.u64()
        t : Q.Ticket<A> <- rd.ticket(~A, ~pdec)
        c : U32 <- rd.u32()
        w : Why <- rd.why(c)
        at : Nat <- rd.u64()
        m : Bool <- rd.flag()
        rest : List<&2, M.Entry<Nat, Dead<A>>> <- rd.entries(~A, ~pdec, f, m)
        return Con{M.Entry{k, Dead{t, w, at}}, rest}

def rd.entry.le(~A: Data, a: M.Entry<Nat, Dead<A>>, b: M.Entry<Nat, Dead<A>>) -> Bool:
  M.Entry{k, v} = a
  M.Entry{j, w} = b
  Nat.is_le(k, j)

def rd.ascending(~A: Data, xs: List<&2, M.Entry<Nat, Dead<A>>>, +previous: Nat) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{M.Entry{+key, value}, rest}:
      Nat.is_lt(previous, key) && rd.ascending(~A, rest, key)

def rd.distinct(~A: Data, xs: List<&2, M.Entry<Nat, Dead<A>>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{M.Entry{key, value}, rest}:
      rd.ascending(~A, rest, key)

def rd.valid.go(~A: Data, +n: Nat, ds: Graves(A)) -> Bool:
  match n:
    case 0n:
      match ds:
        case M.HNil{}:
          True{}
        case M.HLeaf{h, es}:
          rd.distinct(~A, es)
        case M.HBranch{lo, hi}:
          False{}
    case 1n+p:
      match ds:
        case M.HNil{}:
          True{}
        case M.HLeaf{h, +es}:
          CL.hmap_hashed(~Nat, ~Dead<A>, ~dead.hash, es, h) && rd.distinct(~A, es)
        case M.HBranch{lo, hi}:
          rd.valid.go(~A, p, lo) && rd.valid.go(~A, p, hi)

def rd.valid(~A: Data, ds: Graves(A)) -> Bool:
  rd.valid.go(~A, 32n, ds)

# A trie node whose kind is already read: nil is kind 0, leaf kind 1, and branch kind 2. Any other kind fails.
def rd.graves(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +fuel: Nat, nil: Bool, leaf: Bool, branch: Bool) -> Dec(Graves(A)):
  match fuel nil leaf branch:
    case 0n a b c:
      Dec.fail(Graves(A))
    case 1n+f True{} b c:
      Dec.pure(Graves(A), M.HNil{})
    case 1n+f False{} True{} c:
      do Dec<Graves(A)>:
        h : U32 <- rd.u32()
        m : Bool <- rd.flag()
        es : List<&2, M.Entry<Nat, Dead<A>>> <- rd.entries(~A, ~pdec, f, m)
        return M.HLeaf{h, List.sort(~M.Entry<Nat, Dead<A>>, ~(a => b => rd.entry.le(~A, a, b)), es)}
    case 1n+f False{} False{} True{}:
      do Dec<Graves(A)>:
        +lk : U32 <- rd.u32()
        lo : Graves(A) <- rd.graves(~A, ~pdec, f, U32.is_eq(lk, 0), U32.is_eq(lk, 1), U32.is_eq(lk, 2))
        +hk : U32 <- rd.u32()
        hi : Graves(A) <- rd.graves(~A, ~pdec, f, U32.is_eq(hk, 0), U32.is_eq(hk, 1), U32.is_eq(hk, 2))
        return M.HBranch{lo, hi}
    case 1n+f False{} False{} False{}:
      Dec.fail(Graves(A))

# The trie, when it is well formed as the never-selected laws assume.
def rd.wf(-A: Data, ok: Bool, ds: Graves(A)) -> Dec(Graves(A)):
  match ok:
    case True{}:
      Dec.pure(Graves(A), ds)
    case False{}:
      Dec.fail(Graves(A))

def rd.key() -> Dec(String):
  do Dec<String>:
    n : U32 <- rd.u32()
    octets : Bytes.Bytes <- rd.cut(n)
    return Encoding.utf8.decode(octets)

# Each sequence reader takes the count or flag already read; fuel bounds its length.

def rd.nats(+fuel: Nat, end: Bool, +n: U32) -> Dec(List<&2, Nat>):
  match fuel end:
    case 0n b:
      Dec.fail(List<&2, Nat>)
    case 1n+f True{}:
      Dec.pure(List<&2, Nat>, Nil{})
    case 1n+f False{}:
      +k = (n - 1 : U32)
      do Dec<List<&2, Nat>>:
        x : Nat <- rd.u64()
        rest : List<&2, Nat> <- rd.nats(f, U32.is_eq(k, 0), k)
        return Con{x, rest}

def rd.closed(+fuel: Nat) -> Dec(Retry.State):
  do Dec<Retry.State>:
    +n : U32 <- rd.u32()
    fs : List<&2, Nat> <- rd.nats(fuel, U32.is_eq(n, 0), n)
    return Retry.CircuitClosed{fs}

def rd.brk.of(+fuel: Nat, +kind: U32) -> Dec(Retry.State):
  Bool.pick(Dec(Retry.State), U32.is_eq(kind, 0), rd.closed(fuel),
  Bool.pick(Dec(Retry.State), U32.is_eq(kind, 1), Dec.bind(Nat, Retry.State, rd.u64(), u => Dec.pure(Retry.State, Retry.CircuitOpen{u})),
  Bool.pick(Dec(Retry.State), U32.is_eq(kind, 2), Dec.bind(Nat, Retry.State, rd.u64(), k => Dec.pure(Retry.State, Retry.CircuitHalf{k})), Dec.fail(Retry.State))))

def rd.brk(+fuel: Nat) -> Dec(Retry.State):
  Dec.bind(U32, Retry.State, rd.u32(), k => rd.brk.of(fuel, k))

def rd.break(-A: Data, +fuel: Nat) -> Dec(Op<A>):
  do Dec<Op<A>>:
    k : String <- rd.key()
    b : Retry.State <- rd.brk(fuel)
    return Break{k, b}

def rd.brks(+fuel: Nat, more: Bool, acc: Breakers()) -> Dec(Breakers()):
  match fuel more:
    case 0n b:
      Dec.fail(Breakers())
    case 1n+f False{}:
      Dec.pure(Breakers(), acc)
    case 1n+f True{}:
      do Dec<Breakers()>:
        k : String <- rd.key()
        b : Retry.State <- rd.brk(f)
        m : Bool <- rd.flag()
        rd.brks(f, m, M.HMap.put(~String, ~Retry.State, ~brk.hash, ~brk.eq, acc, k, b))

def rd.state(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +fuel: Nat) -> Dec(State<A>):
  do Dec<State<A>>:
    n : Nat <- rd.u64()
    hf : Bool <- rd.flag()
    h : H.Heap<Q.Ticket<A>> <- rd.heap(~A, ~pdec, fuel, hf)
    rf : Bool <- rd.flag()
    run : List<&2, Q.Ticket<A>> <- rd.run(~A, ~pdec, fuel, rf)
    tf : Bool <- rd.flag()
    ts : O.OMap<Nat, Try> <- rd.tries(fuel, tf)
    +dk : U32 <- rd.u32()
    +dt : Graves(A) <- rd.graves(~A, ~pdec, fuel, U32.is_eq(dk, 0), U32.is_eq(dk, 1), U32.is_eq(dk, 2))
    ds : Graves(A) <- rd.wf(A, rd.valid(~A, dt), dt)
    bf : Bool <- rd.flag()
    bs : Breakers() <- rd.brks(fuel, bf, M.HMap.new(String, Retry.State))
    return State{Q.State{n, h, run}, ts, ds, bs}

# The value read, when the reader ended at len, the record's end.
def rd.done(-T: Data, +len: U32, m: Maybe<&1, Rd & T>) -> Maybe<&2, T>:
  match m:
    case None{}:
      None{}
    case Some{(Rd{b, +at}, +x)}:
      Bool.pick(Maybe<&2, T>, U32.is_eq(at, len), Some{x}, None{})

# The Abandon of ticket a at e whose why.code is c, or None for any other code.
def decode.abandon(-A: Data, +a: Nat, +c: Nat, +e: Nat) -> Maybe<&2, Op<A>>:
  Bool.pick(Maybe<&2, Op<A>>, Nat.is_eq(c, 0n), Some{Abandon{a, WhySpent{}, e}},
  Bool.pick(Maybe<&2, Op<A>>, Nat.is_eq(c, 1n), Some{Abandon{a, WhyLate{}, e}},
  Bool.pick(Maybe<&2, Op<A>>, Nat.is_eq(c, 2n), Some{Abandon{a, WhyUnsafe{}, e}},
  Bool.pick(Maybe<&2, Op<A>>, Nat.is_eq(c, 3n), Some{Abandon{a, WhyFailed{}, e}}, None{}))))

def decode.small(-A: Data, ok: Bool, +tag: U32, +a: Nat, +c: Nat) -> Maybe<&2, Op<A>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 2), Some{Select{a}},
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 3), Some{Complete{a}},
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 4), Some{Cancel{a}},
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 5), Some{Requeue{a, c}},
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 6), Some{Defer{a, c}},
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 9), Some{Revive{a, c}},
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 11), Some{Purge{a}},
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 12), Some{PurgeAll{}}, None{}))))))))

def decode.long(-A: Data, ok: Bool, +a: Nat, +c: Nat, r: Bytes.Bytes & Nat) -> Maybe<&2, Op<A>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      (b, +e) = r
      decode.abandon(A, a, c, e)

def decode.payload(-A: Data, m: Maybe<&2, A>, +d: Nat) -> Maybe<&2, Op<A>>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{Enqueue{d, x}}

def decode.c.if(-A: Data, abandon: Bool, +tag: U32, +len: U32, +a: Nat, +c: Nat, b: Bytes.Bytes) -> Maybe<&2, Op<A>>:
  match abandon:
    case True{}:
      decode.long(A, U32.is_eq(len, 28), a, c, get.u64(b, 20))
    case False{}:
      decode.small(A, U32.is_eq(len, 20), tag, a, c)

# An Abandon is 28 octets; every other op without a payload is 20.
def decode.c(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +tag: U32, +len: U32, +a: Nat, r: Bytes.Bytes & Nat) -> Maybe<&2, Op<A>>:
  (b, +c) = r
  decode.c.if(A, U32.is_eq(tag, 8), tag, len, a, c, b)

def decode.kind(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, enq: Bool, +tag: U32, +len: U32, +a: Nat, b: Bytes.Bytes) -> Maybe<&2, Op<A>>:
  match enq:
    case True{}:
      decode.payload(A, pdec(Bytes.snd(Bytes.slice(b, 12, (len - 12 : U32)))), a)
    case False{}:
      decode.c(~A, ~pdec, tag, len, a, get.u64(b, 12))

def decode.a(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +tag: U32, +len: U32, r: Bytes.Bytes & Nat) -> Maybe<&2, Op<A>>:
  (b, +a) = r
  decode.kind(~A, ~pdec, U32.is_eq(tag, 1), tag, len, a, b)

def decode.tag.if(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, brk: Bool, +tag: U32, +len: U32, b: Bytes.Bytes) -> Maybe<&2, Op<A>>:
  match brk:
    case True{}:
      rd.done(Op<A>, len, rd.break(A, U32.to_nat((len / 4 + 1 : U32)))(Rd{b, 4}))
    case False{}:
      decode.a(~A, ~pdec, tag, len, get.u64(b, 4))

def decode.tag(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +len: U32, r: Bytes.Bytes & U32) -> Maybe<&2, Op<A>>:
  (b, +tag) = r
  decode.tag.if(~A, ~pdec, U32.is_eq(tag, 13), tag, len, b)

def decode.len(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, ok: Bool, +len: U32, b: Bytes.Bytes) -> Maybe<&2, Op<A>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      decode.tag(~A, ~pdec, len, get.u32(Bytes.get.u32le(b, 0)))

# The op of a record, or None when it is not one that encode writes.
def decode(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes) -> Maybe<&2, Op<A>>:
  Bytes.Bytes{+len, buf} = b
  decode.len(~A, ~pdec, U32.is_ge(len, 12), len, Bytes.Bytes{len, buf})

def queue.absent.heap(-A: Data, h: H.Heap<Q.Ticket<A>>, +i: Nat) -> Bool:
  match h:
    case H.HLeaf{}:
      True{}
    case H.HNode{n, t, l, r}:
      Bool.not(Nat.is_eq(Q.id(A, t), i)) && (queue.absent.heap(A, l, i) && queue.absent.heap(A, r, i))

def queue.cross(-A: Data, a: H.Heap<Q.Ticket<A>>, +b: H.Heap<Q.Ticket<A>>) -> Bool:
  match a:
    case H.HLeaf{}:
      True{}
    case H.HNode{n, t, l, r}:
      queue.absent.heap(A, b, Q.id(A, t)) && (queue.cross(A, l, b) && queue.cross(A, r, b))

def queue.unique.heap(-A: Data, h: H.Heap<Q.Ticket<A>>) -> Bool:
  match h:
    case H.HLeaf{}:
      True{}
    case H.HNode{n, t, +l, +r}:
      +i = Q.id(A, t)
      queue.absent.heap(A, l, i) && (queue.absent.heap(A, r, i) &&
        (queue.unique.heap(A, l) && (queue.unique.heap(A, r) && queue.cross(A, l, r))))

def queue.absent.list(-A: Data, xs: List<&2, Q.Ticket<A>>, +i: Nat) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{t, rest}:
      Bool.not(Nat.is_eq(Q.id(A, t), i)) && queue.absent.list(A, rest, i)

def queue.unique.list(-A: Data, xs: List<&2, Q.Ticket<A>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{t, +rest}:
      queue.absent.list(A, rest, Q.id(A, t)) && queue.unique.list(A, rest)

def queue.apart(-A: Data, xs: List<&2, Q.Ticket<A>>, +h: H.Heap<Q.Ticket<A>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{t, rest}:
      queue.absent.heap(A, h, Q.id(A, t)) && queue.apart(A, rest, h)

# ponytail: pairwise id checks cost O(n²); use a proved sorted-id check if recovery size requires it.
def queue.unique(-A: Data, s: State<A>) -> Bool:
  State{Q.State{n, +h, +run}, ts, ds, bs} = s
  queue.unique.list(A, run) && (queue.unique.heap(A, h) && queue.apart(A, run, h))

def fresh.heap(-A: Data, h: H.Heap<Q.Ticket<A>>, +n: Nat) -> Bool:
  match h:
    case H.HLeaf{}:
      True{}
    case H.HNode{size, t, l, r}:
      Nat.is_lt(Q.id(A, t), n) && (fresh.heap(A, l, n) && fresh.heap(A, r, n))

def fresh.list(-A: Data, xs: List<&2, Q.Ticket<A>>, +n: Nat) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{t, rest}:
      Nat.is_lt(Q.id(A, t), n) && fresh.list(A, rest, n)

def fresh.entries(-A: Data, xs: List<&2, M.Entry<Nat, Dead<A>>>, +n: Nat) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{M.Entry{k, Dead{t, w, at}}, rest}:
      Nat.is_lt(k, n) && (Nat.is_lt(Q.id(A, t), n) && fresh.entries(A, rest, n))

def fresh.graves(-A: Data, ds: Graves(A), +n: Nat) -> Bool:
  match ds:
    case M.HNil{}:
      True{}
    case M.HLeaf{hash, es}:
      fresh.entries(A, es, n)
    case M.HBranch{lo, hi}:
      fresh.graves(A, lo, n) && fresh.graves(A, hi, n)

def fresh(-A: Data, s: State<A>) -> Bool:
  State{Q.State{+n, h, run}, ts, ds, bs} = s
  fresh.heap(A, h, n) && (fresh.list(A, run, n) && fresh.graves(A, ds, n))

def registry.entries(-A: Data, es: List<&2, M.Entry<Nat, Dead<A>>>, +h: H.Heap<Q.Ticket<A>>, +run: List<&2, Q.Ticket<A>>) -> Bool:
  match es:
    case Nil{}:
      True{}
    case Con{M.Entry{+k, Dead{t, w, at}}, rest}:
      Nat.is_eq(k, Q.id(A, t)) && (queue.absent.heap(A, h, k) &&
        (queue.absent.list(A, run, k) && registry.entries(A, rest, h, run)))

def registry.graves(-A: Data, ds: Graves(A), +h: H.Heap<Q.Ticket<A>>, +run: List<&2, Q.Ticket<A>>) -> Bool:
  match ds:
    case M.HNil{}:
      True{}
    case M.HLeaf{hash, es}:
      registry.entries(A, es, h, run)
    case M.HBranch{lo, hi}:
      registry.graves(A, lo, h, run) && registry.graves(A, hi, h, run)

def registry.valid(-A: Data, s: State<A>) -> Bool:
  State{Q.State{n, h, run}, ts, ds, bs} = s
  registry.graves(A, ds, h, run)

def queue.valid(-A: Data, +s: State<A>) -> Bool:
  queue.unique(A, s) && (fresh(A, s) && registry.valid(A, s))

def rd.queue.keep(-A: Data, ok: Bool, s: State<A>) -> Maybe<&2, State<A>>:
  match ok:
    case True{}:
      Some{s}
    case False{}:
      None{}

def rd.queue(-A: Data, m: Maybe<&2, State<A>>) -> Maybe<&2, State<A>>:
  match m:
    case None{}:
      None{}
    case Some{+s}:
      rd.queue.keep(A, queue.valid(A, s), s)

# The state of a Snap record whose tag is already checked. The decoder must end at the record's end.
def decode.snap(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes) -> Maybe<&2, State<A>>:
  Bytes.Bytes{+len, buf} = b
  rd.queue(A, rd.done(State<A>, len, rd.state(~A, ~pdec, U32.to_nat((len / 4 + 1 : U32)))(Rd{Bytes.Bytes{len, buf}, 4})))

def decode.snapped(-A: Data, m: Maybe<&2, State<A>>) -> Maybe<&2, Rec<A>>:
  match m:
    case None{}:
      None{}
    case Some{s}:
      Some{Snap{s}}

def decode.did(-A: Data, m: Maybe<&2, Op<A>>) -> Maybe<&2, Rec<A>>:
  match m:
    case None{}:
      None{}
    case Some{op}:
      Some{Do{op}}

def decode.rec.if(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, snap: Bool, b: Bytes.Bytes) -> Maybe<&2, Rec<A>>:
  match snap:
    case True{}:
      decode.snapped(A, decode.snap(~A, ~pdec, b))
    case False{}:
      decode.did(A, decode(~A, ~pdec, b))

def decode.rec.tag(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, r: Bytes.Bytes & U32) -> Maybe<&2, Rec<A>>:
  (b, +tag) = r
  decode.rec.if(~A, ~pdec, U32.is_eq(tag, 14), b)

# The Rec of a journal record, or None when it is neither a Snap nor an op that encode.rec writes.
def decode.rec(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes) -> Maybe<&2, Rec<A>>:
  decode.rec.tag(~A, ~pdec, get.u32(Bytes.get.u32le(b, 0)))

def empty.heap(-A: Data, h: H.Heap<Q.Ticket<A>>) -> Bool:
  match h:
    case H.HLeaf{}:
      True{}
    case H.HNode{n, t, l, r}:
      False{}

def empty.list(-A: Data, xs: List<&2, Q.Ticket<A>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{t, rest}:
      False{}

# No ticket is pending or running. Dead tickets wait for a Revive, so they do not count.
def idle(-A: Data, s: State<A>) -> Bool:
  State{Q.State{n, h, run}, ts, ds, bs} = s
  Bool.and(empty.heap(A, h), empty.list(A, run))

def pending(-A: Data, s: State<A>) -> Nat:
  State{Q.State{n, h, run}, ts, ds, bs} = s
  H.Heap.size(Q.Ticket<A>, h)

# ms to wait: idle, or less when the earliest pending ticket falls due sooner.
def drain.ms(-A: Data, idle: U32, now: Nat, m: Maybe<&2, Q.Ticket<A>>) -> U32:
  match m:
    case None{}:
      idle
    case Some{Q.Ticket{i, d, x}}:
      U32.from_nat(Nat.min(U32.to_nat(idle), Nat.sub(d, now)))

def soonest(-A: Data, s: State<A>) -> Maybe<&2, Q.Ticket<A>>:
  State{Q.State{n, h, run}, ts, ds, bs} = s
  H.Heap.peek(Q.Ticket<A>, h)

def replay.step(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, acc: Maybe<&2, State<A>>, b: Bytes.Bytes) -> Maybe<&2, State<A>>:
  load(~A, ~Bytes.Bytes, ~(y => decode.rec(~A, ~pdec, y)), acc, b)

