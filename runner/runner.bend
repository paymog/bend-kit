# Durable job runner: a journaled scheduler queue, bounded by a resources pool, with retry and a breaker per target. Source: https://github.com/paymog/bend-kit/tree/main/runner
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-journal@0.2.0.0/journal.bend as J
import bend-kit-scheduler@0.3.0.0/queue.bend as Q
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-retry@0.2.0.0/retry.bend as Retry
import bend-kit-time@0.2.0.0/time.bend as Time
import bend-kit-collections@0.1.3.0/heap.bend as H
import bend-kit-collections@0.1.3.0/omap.bend as O
import bend-kit-files@0.2.0.0/files.bend as Files

# Why retry gave up on a ticket: its budget was spent, its deadline passed, its failure must not repeat,
# or another try would repeat its failure.
type Why is Data:
  WhySpent{}
  WhyLate{}
  WhyUnsafe{}
  WhyFailed{}

# A ticket that retry gave up on, with its payload. It stays until Revive or Cancel takes it.
type Dead<-A: Data> is Data:
  Dead{ticket: Q.Ticket<A>, why: Why}

# One queue transition. Each one is one journal record, appended before the state changes.
# Select: the queue's select at now. Replay runs it at the same now, so it takes the same ticket.
# Requeue: the attempt failed; it counts one failure. Defer: the breaker held the ticket back; no attempt ran.
# Abandon: retry gave up; the running ticket becomes dead. Revive: a dead ticket is pending again at deadline, with a new budget.
type Op<-A: Data> is Data:
  Enqueue{deadline: Nat, payload: A}
  Select{now: Nat}
  Complete{id: Nat}
  Cancel{id: Nat}
  Requeue{id: Nat, deadline: Nat}
  Defer{id: Nat, deadline: Nat}
  Abandon{id: Nat, why: Why}
  Revive{id: Nat, deadline: Nat}

# The failed attempts of a ticket, and its first deadline, from which the policy deadline counts.
type Try is Data:
  Try{fails: Nat, start: Nat}

# A Try for each ticket that is not yet complete, cancelled, or dead, by ticket id.
def Tries() -> Data:
  O.OMap<Nat, Try>

# The durable state: the queue, the tries, and the dead tickets, newest first.
type State<-A: Data> is Data:
  State{queue: Q.State<A>, tries: Tries(), dead: List<&2, Dead<A>>}

def new(-A: Data) -> State<A>:
  State{Q.new(A), O.OMap.new(Nat, Try), Nil{}}

def queue(-A: Data, s: State<A>) -> Q.State<A>:
  State{q, ts, ds} = s
  q

def tries(-A: Data, s: State<A>) -> Tries():
  State{q, ts, ds} = s
  ts

# The dead tickets, newest first. A Revive of one makes it pending again; a Cancel drops it.
def dead(-A: Data, s: State<A>) -> List<&2, Dead<A>>:
  State{q, ts, ds} = s
  ds

# ---- dead tickets

def dead.id(-A: Data, d: Dead<A>) -> Nat:
  match d:
    case Dead{t, w}:
      Q.id(A, t)

def dead.remove.keep(-A: Data, b: Bool, d: Dead<A>, rest: List<&2, Dead<A>>) -> List<&2, Dead<A>>:
  match b:
    case True{}:
      rest
    case False{}:
      Con{d, rest}

# The dead tickets without ticket i.
def dead.remove(-A: Data, ds: List<&2, Dead<A>>, +i: Nat) -> List<&2, Dead<A>>:
  match ds:
    case Nil{}:
      Nil{}
    case Con{+d, rest}:
      dead.remove.keep(A, Nat.is_eq(dead.id(A, d), i), d, dead.remove(A, rest, i))

def dead.find.choose(-A: Data, b: Bool, d: Dead<A>, rest: Maybe<&2, Q.Ticket<A>>) -> Maybe<&2, Q.Ticket<A>>:
  match b:
    case True{}:
      match d:
        case Dead{t, w}:
          Some{t}
    case False{}:
      rest

# The ticket of dead ticket i.
def dead.find(-A: Data, ds: List<&2, Dead<A>>, +i: Nat) -> Maybe<&2, Q.Ticket<A>>:
  match ds:
    case Nil{}:
      None{}
    case Con{+d, rest}:
      dead.find.choose(A, Nat.is_eq(dead.id(A, d), i), d, dead.find(A, rest, i))

def dead.bury(-A: Data, m: Maybe<&2, Q.Ticket<A>>, ds: List<&2, Dead<A>>, w: Why) -> List<&2, Dead<A>>:
  match m:
    case None{}:
      ds
    case Some{t}:
      Con{Dead{t, w}, ds}

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

# ---- the transition

def step.enqueued(-A: Data, r: Q.State<A> & Nat, ts: Tries(), ds: List<&2, Dead<A>>, d: Nat) -> State<A>:
  (q, i) = r
  State{q, O.OMap.put(~Nat, ~Try, ~Nat.cmp, ts, i, Try{0n, d}), ds}

def step.selected(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: Tries(), ds: List<&2, Dead<A>>) -> State<A>:
  (q, t) = r
  State{q, ts, ds}

def step.requeued(-A: Data, r: Q.State<A> & Bool, ts: Tries(), ds: List<&2, Dead<A>>) -> State<A>:
  (q, b) = r
  State{q, ts, ds}

# Complete takes the ticket from the running list only: O(running), not O(pending).
def step.completed(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: Tries(), ds: List<&2, Dead<A>>) -> State<A>:
  (q, t) = r
  State{q, ts, ds}

# Abandon takes the ticket from the running list, as Complete does, and keeps it with its payload.
def step.abandoned(-A: Data, r: Q.State<A> & Maybe<&2, Q.Ticket<A>>, ts: Tries(), ds: List<&2, Dead<A>>, w: Why) -> State<A>:
  (q, t) = r
  State{q, ts, dead.bury(A, t, ds, w)}

def step.revived(~A: Data, m: Maybe<&2, Q.Ticket<A>>, n: Nat, h: H.Heap<Q.Ticket<A>>, r: List<&2, Q.Ticket<A>>, ts: Tries(), ds: List<&2, Dead<A>>, +d: Nat) -> State<A>:
  match m:
    case None{}:
      State{Q.State{n, h, r}, ts, ds}
    case Some{Q.Ticket{+i, old, x}}:
      State{Q.State{n, H.Heap.push(~Q.Ticket<A>, ~(a => b => Q.le(A, a, b)), Q.Ticket{i, d, x}, h), r}, O.OMap.put(~Nat, ~Try, ~Nat.cmp, ts, i, Try{0n, d}), ds}

# The state after op. Live and replay both run it, so they agree.
def step(~A: Data, s: State<A>, op: Op<A>) -> State<A>:
  match s op:
    case State{q, ts, ds} Enqueue{+d, x}:
      step.enqueued(A, Q.enqueue(~A, d, x, q), ts, ds, d)
    case State{q, ts, ds} Select{now}:
      step.selected(A, Q.select(~A, now, q), ts, ds)
    case State{q, ts, ds} Complete{+i}:
      step.completed(A, Q.complete(A, i, q), tries.drop(ts, i), ds)
    case State{q, ts, ds} Cancel{+i}:
      State{Q.cancel(~A, i, q), tries.drop(ts, i), dead.remove(A, ds, i)}
    case State{q, ts, ds} Requeue{+i, d}:
      step.requeued(A, Q.requeue(~A, i, d, q), tries.bump(ts, i), ds)
    case State{q, ts, ds} Defer{i, d}:
      step.requeued(A, Q.requeue(~A, i, d, q), ts, ds)
    case State{q, ts, ds} Abandon{+i, w}:
      step.abandoned(A, Q.complete(A, i, q), tries.drop(ts, i), ds, w)
    case State{Q.State{n, h, r}, ts, +ds} Revive{+i, d}:
      step.revived(~A, dead.find(A, ds, i), n, h, r, ts, dead.remove(A, ds, i), d)

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
  State{q, ts, ds} = s
  pick.sel(A, Q.select(~A, now, q), p)

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

# A settled attempt completes its ticket; retry gave up on any other.
def stopped(-A: Data, o: Retry.Outcome, b: Retry.Budget, +id: Nat) -> Op<A>:
  match o:
    case Retry.Settled{}:
      Complete{id}
    case Retry.Failed{}:
      Abandon{id, WhyFailed{}}
    case Retry.Unsafe{}:
      Abandon{id, WhyUnsafe{}}
    case Retry.Transient{w}:
      Abandon{id, gave(b)}

def after.plan(-A: Data, pl: Retry.Plan, o: Retry.Outcome, b: Retry.Budget, +id: Nat, +now: Nat) -> Op<A>:
  match pl:
    case Retry.PlanStop{}:
      stopped(A, o, b, id)
    case Retry.PlanWait{w}:
      Requeue{id, Nat.add(now, w)}

# The record after an attempt of ticket id ends at now with o: requeue at now plus retry's wait,
# complete when o is settled, or abandon when retry gave up.
def after(-A: Data, +o: Retry.Outcome, p: Retry.Policy, +b: Retry.Budget, +id: Nat, +n: Nat, +now: Nat, +r: Nat) -> Op<A>:
  after.plan(A, Retry.plan(o, p, b, n, now, r), o, b, id, now)

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
      Abandon{id, WhyLate{}}
    case Retry.DenySpent{}:
      Abandon{id, WhySpent{}}

# ---- the record codec: a u32le tag, then u64le fields; an Enqueue then holds the payload. An Abandon's second field is why.code.

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
    case Abandon{+i, w}:
      head(8, i, why.code(w))
    case Revive{+i, +d}:
      head(9, i, d)

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

# The Abandon of ticket a whose why.code is c, or None for any other code.
def decode.abandon(-A: Data, +a: Nat, +c: Nat) -> Maybe<&2, Op<A>>:
  Bool.pick(Maybe<&2, Op<A>>, Nat.is_eq(c, 0n), Some{Abandon{a, WhySpent{}}},
  Bool.pick(Maybe<&2, Op<A>>, Nat.is_eq(c, 1n), Some{Abandon{a, WhyLate{}}},
  Bool.pick(Maybe<&2, Op<A>>, Nat.is_eq(c, 2n), Some{Abandon{a, WhyUnsafe{}}},
  Bool.pick(Maybe<&2, Op<A>>, Nat.is_eq(c, 3n), Some{Abandon{a, WhyFailed{}}}, None{}))))

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
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 8), decode.abandon(A, a, c),
      Bool.pick(Maybe<&2, Op<A>>, U32.is_eq(tag, 9), Some{Revive{a, c}}, None{})))))))

def decode.payload(-A: Data, m: Maybe<&2, A>, +d: Nat) -> Maybe<&2, Op<A>>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{Enqueue{d, x}}

def decode.c(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +tag: U32, +len: U32, +a: Nat, r: Bytes.Bytes & Nat) -> Maybe<&2, Op<A>>:
  (b, +c) = r
  decode.small(A, U32.is_eq(len, 20), tag, a, c)

def decode.kind(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, enq: Bool, +tag: U32, +len: U32, +a: Nat, b: Bytes.Bytes) -> Maybe<&2, Op<A>>:
  match enq:
    case True{}:
      decode.payload(A, pdec(Bytes.snd(Bytes.slice(b, 12, (len - 12 : U32)))), a)
    case False{}:
      decode.c(~A, ~pdec, tag, len, a, get.u64(b, 12))

def decode.a(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +tag: U32, +len: U32, r: Bytes.Bytes & Nat) -> Maybe<&2, Op<A>>:
  (b, +a) = r
  decode.kind(~A, ~pdec, U32.is_eq(tag, 1), tag, len, a, b)

def decode.tag(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +len: U32, r: Bytes.Bytes & U32) -> Maybe<&2, Op<A>>:
  (b, +tag) = r
  decode.a(~A, ~pdec, tag, len, get.u64(b, 4))

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

# ---- the snapshot codec: tag 7 and the next id, then the heap, the running list, the tries, and the dead tickets.
# A u32 flag starts each tree node and list cell (1) and marks each end (0), so decode rebuilds the same shape.
# A ticket is its u64 id and deadline, then a u32 length and the payload. A dead ticket is its ticket, then a u32 why.code.

def snap.u32(out: Bytes.Bytes, +v: U32) -> Bytes.Bytes:
  Bytes.append(out, Bytes.set.u32le(Bytes.new(4), 0, v))

def snap.u64(out: Bytes.Bytes, +n: Nat) -> Bytes.Bytes:
  Bytes.append(out, put.u64(Bytes.new(8), 0, n))

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

def snap.dead(~A: Data, ~penc: A -> Bytes.Bytes, ds: List<&2, Dead<A>>, out: Bytes.Bytes) -> Bytes.Bytes:
  match ds:
    case Nil{}:
      snap.u32(out, 0)
    case Con{Dead{t, w}, rest}:
      snap.dead(~A, ~penc, rest, snap.u32(snap.ticket(~A, ~penc, snap.u32(out, 1), t), U32.from_nat(why.code(w))))

# The Snap record of s.
def encode.snap(~A: Data, ~penc: A -> Bytes.Bytes, s: State<A>) -> Bytes.Bytes:
  State{Q.State{+n, h, run}, ts, ds} = s
  snap.dead(~A, ~penc, ds, snap.tries(ts, snap.run(~A, ~penc, run, snap.heap(~A, ~penc, h, snap.u64(snap.u32(Bytes.new(0), 7), n)))))

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

def rd.dead(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +fuel: Nat, more: Bool) -> Dec(List<&2, Dead<A>>):
  match fuel more:
    case 0n b:
      Dec.fail(List<&2, Dead<A>>)
    case 1n+f False{}:
      Dec.pure(List<&2, Dead<A>>, Nil{})
    case 1n+f True{}:
      do Dec<List<&2, Dead<A>>>:
        t : Q.Ticket<A> <- rd.ticket(~A, ~pdec)
        c : U32 <- rd.u32()
        w : Why <- rd.why(c)
        m : Bool <- rd.flag()
        rest : List<&2, Dead<A>> <- rd.dead(~A, ~pdec, f, m)
        return Con{Dead{t, w}, rest}

def rd.state(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +fuel: Nat) -> Dec(State<A>):
  do Dec<State<A>>:
    n : Nat <- rd.u64()
    hf : Bool <- rd.flag()
    h : H.Heap<Q.Ticket<A>> <- rd.heap(~A, ~pdec, fuel, hf)
    rf : Bool <- rd.flag()
    run : List<&2, Q.Ticket<A>> <- rd.run(~A, ~pdec, fuel, rf)
    tf : Bool <- rd.flag()
    ts : O.OMap<Nat, Try> <- rd.tries(fuel, tf)
    df : Bool <- rd.flag()
    ds : List<&2, Dead<A>> <- rd.dead(~A, ~pdec, fuel, df)
    return State{Q.State{n, h, run}, ts, ds}

def decode.snap.end(-A: Data, +len: U32, m: Maybe<&1, Rd & State<A>>) -> Maybe<&2, State<A>>:
  match m:
    case None{}:
      None{}
    case Some{(Rd{b, +at}, +s)}:
      Bool.pick(Maybe<&2, State<A>>, U32.is_eq(at, len), Some{s}, None{})

# The state of a Snap record whose tag is already checked. The decoder must end at the record's end.
def decode.snap(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes) -> Maybe<&2, State<A>>:
  Bytes.Bytes{+len, buf} = b
  decode.snap.end(A, len, rd.state(~A, ~pdec, U32.to_nat((len / 4 + 1 : U32)))(Rd{Bytes.Bytes{len, buf}, 4}))

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
  decode.rec.if(~A, ~pdec, U32.is_eq(tag, 7), b)

# The Rec of a journal record, or None when it is neither a Snap nor an op that encode.rec writes.
def decode.rec(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, b: Bytes.Bytes) -> Maybe<&2, Rec<A>>:
  decode.rec.tag(~A, ~pdec, get.u32(Bytes.get.u32le(b, 0)))

# ---- the runner

# policy: retry's policy for each ticket. circuit: the breaker of each target. idle: ms that drain waits when no attempt started.
# compact: tick compacts the journal once records past this many octets were appended since open or the last compaction; 0 never.
type Config is Data:
  Config{policy: Retry.Policy, circuit: Retry.Circuit, idle: U32, compact: U32}

# The journal, its path, its file cap, and its length at open or at the last compaction.
type Log is Type:
  Log{journal: J.Journal, path: String, limit: U32, base: U32}

# An attempt that runs: its unit of the pool, the budget that admit left, and its target.
type Flight<-A: Data> is Type:
  Flight{ticket: Q.Ticket<A>, grant: Res.Grant, budget: Retry.Budget, target: String}

def Out(-X: Type) -> Type:
  Result<&1, &1, U32 & String, X>

# A message to the fiber that owns the runner. Ended: an attempt finished. Add and Drop: another fiber asks for an enqueue or a cancel.
type Msg<-A: Data> is Type:
  Ended{id: Nat, outcome: Retry.Outcome}
  Add{deadline: Nat, payload: A, reply: Chan(Out(Nat))}
  Drop{id: Nat, reply: Chan(Out(Unit))}

# An open runner. Replaying its journal gives its state; its pool bounds the attempts that run at once.
# Each attempt sends its outcome, and each other fiber its ask, on inbox. flights are the attempts that run.
type Runner<-A: Data> is Type:
  Runner{log: Log, state: State<A>, pool: Res.Pool, breakers: Map<&2, Retry.Breaker>, config: Config, inbox: Chan(Msg<A>), flights: List<&1, Flight<A>>}

# The runner, the claim fuel left, and the first error.
def Claimed(-A: Data) -> Type:
  Runner<A> & Nat & Out(Unit)

def Ran(-A: Data) -> Type:
  Runner<A> & Out(Unit)

# Wall-clock ms since the Unix epoch. Deadlines must keep their meaning across a restart.
def clock() -> IO(Nat):
  do IO<Nat>:
    t : Time.Instant <- Time.now()
    return Time.Duration.to_ms_nat(Time.Instant.since_epoch(t))

def first(a: Out(Unit), b: Out(Unit)) -> Out(Unit):
  match a:
    case Fail{e}:
      Fail{e}
    case Done{u}:
      b

def log.appended(+path: String, +limit: U32, +base: U32, x: J.Journal & Out(Unit)) -> Log & Out(Unit):
  (j, o) = x
  (Log{j, path, limit, base}, o)

def log.append(l: Log, p: Bytes.Bytes) -> IO(Log & Out(Unit)):
  Log{j, +path, +limit, +base} = l
  do IO<Log & Out(Unit)>:
    x : J.Journal & Out(Unit) <- J.append(j, p)
    return log.appended(path, limit, base, x)

def log.close(l: Log) -> IO(Unit):
  Log{j, path, limit, base} = l
  J.close(j)

# The journal reads with limit as its record cap, so that a snapshot fits; appends keep max.
def log.of(j: J.Journal, +max: U32, path: String, +limit: U32) -> Log:
  J.Journal{file, cap, +end, ok} = j
  Log{J.Journal{file, max, end, ok}, path, limit, end}

def commit.done(~A: Data, x: Log & Out(Unit), s: State<A>, +op: Op<A>, p: Res.Pool, bs: Map<&2, Retry.Breaker>, c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>) -> Ran(A):
  match x:
    case (j, Done{u}):
      (Runner{j, step(~A, s, op), p, bs, c, ib, fs}, Done{u})
    case (j, Fail{e}):
      (Runner{j, s, p, bs, c, ib, fs}, Fail{e})

# Appends op, and applies it once the append is durable. After a failed append the state is as it was,
# and the journal refuses every later append until the runner is reopened.
def commit(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +op: Op<A>) -> IO(Ran(A)):
  Runner{j, s, p, bs, c, ib, fs} = r
  do IO<Ran(A)>:
    x : Log & Out(Unit) <- log.append(j, encode(~A, ~penc, op))
    return commit.done(~A, x, s, op, p, bs, c, ib, fs)

def enqueue.done(-A: Data, +id: Nat, y: Ran(A)) -> Runner<A> & Out(Nat):
  match y:
    case (r, Done{u}):
      (r, Done{id})
    case (r, Fail{e}):
      (r, Fail{e})

# Adds a job that is due at deadline (wall-clock ms) and answers its ticket id once the record is durable.
def enqueue(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +deadline: Nat, x: A) -> IO(Runner<A> & Out(Nat)):
  Runner{j, +s, p, bs, c, ib, fs} = r
  do IO<Runner<A> & Out(Nat)>:
    y : Ran(A) <- commit(~A, ~penc, Runner{j, s, p, bs, c, ib, fs}, Enqueue{deadline, x})
    return enqueue.done(A, Q.next_id(A, queue(A, s)), y)

# Cancels ticket id. A running attempt finishes, but its ticket is never selected again. A dead ticket is dropped.
def cancel(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +id: Nat) -> IO(Ran(A)):
  commit(~A, ~penc, r, Cancel{id})

# Makes dead ticket id pending again at deadline (wall-clock ms), with its payload and a new retry budget.
# A ticket that is not dead does not change.
def revive(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +id: Nat, +deadline: Nat) -> IO(Ran(A)):
  commit(~A, ~penc, r, Revive{id, deadline})

# ---- asks from other fibers

# The runner back, and its inbox. Another fiber passes the inbox to ask.enqueue and ask.cancel.
def inbox(-A: Data, r: Runner<A>) -> Runner<A> & Chan(Msg<A>):
  Runner{j, s, p, bs, c, +ib, fs} = r
  (Runner{j, s, p, bs, c, ib, fs}, ib)

def ask.answer(-X: Type, m: Maybe<&1, Out(X)>) -> Out(X):
  match m:
    case None{}:
      Fail{(32, "runner: the runner closed before it answered")}
    case Some{o}:
      o

def ask.sent(-A: Data, -X: Type, x: Result<&1, &1, Msg<A>, Unit>, +rep: Chan(Out(X))) -> IO(Out(X)):
  match x:
    case Fail{m}:
      IO.pure(Out(X), Fail{(32, "runner: the inbox is closed")})
    case Done{u}:
      do IO<Out(X)>:
        a : Maybe<&1, Out(X)> <- Chan.recv(Out(X), rep)
        return ask.answer(X, a)

# Sends m, built with a new reply channel, on the inbox and waits for the reply.
def ask(-A: Data, -X: Type, +ib: Chan(Msg<A>), m: Chan(Out(X)) -> Msg<A>) -> IO(Out(X)):
  do IO<Out(X)>:
    +rep : Chan(Out(X)) <- Chan.new(Out(X), 1)
    x : Result<&1, &1, Msg<A>, Unit> <- Chan.send(Msg<A>, ib, m(rep))
    ask.sent(A, X, x, rep)

# From another fiber: adds a job due at deadline, and answers its ticket id once the record is durable.
# The answer comes when the fiber that owns the runner reads the inbox, in tick or drain.
def ask.enqueue(-A: Data, +ib: Chan(Msg<A>), +deadline: Nat, x: A) -> IO(Out(Nat)):
  ask(A, Nat, ib, rep => Add{deadline, x, rep})

# From another fiber: cancels ticket id, as cancel does. The answer comes when the owner reads the inbox.
def ask.cancel(-A: Data, +ib: Chan(Msg<A>), +id: Nat) -> IO(Out(Unit)):
  ask(A, Unit, ib, rep => Drop{id, rep})

# ---- one round

# A grant of this runner's pool always fits it, so Kept does not happen.
def release.got(-A: Data, x: Res.Release, j: Log, s: State<A>, bs: Map<&2, Retry.Breaker>, c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>) -> Runner<A>:
  match x:
    case Res.Released{p}:
      Runner{j, s, p, bs, c, ib, fs}
    case Res.Kept{p, g}:
      Runner{j, s, p, bs, c, ib, fs}

def release(-A: Data, r: Runner<A>, g: Res.Grant) -> Runner<A>:
  Runner{j, s, p, bs, c, ib, fs} = r
  release.got(A, Res.release(p, g), j, s, bs, c, ib, fs)

def claim.held(-A: Data, y: Ran(A), g: Res.Grant, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match y:
    case (r, Fail{e}):
      IO.pure(Claimed(A), (release(A, r, g), 0n, Fail{e}))
    case (r, Done{u}):
      next(release(A, r, g))

def claim.tag(-A: Data, +id: Nat, o: Retry.Outcome) -> IO(Msg<A>):
  IO.pure(Msg<A>, Ended{id, o})

def claim.go(~A: Data, ~penc: A -> Bytes.Bytes, ~work: A -> IO(Retry.Outcome), +now: Nat, a: Retry.Breaker & Retry.Budget & Retry.Gate, +key: String,
    j: Log, s: State<A>, p: Res.Pool, bs: Map<&2, Retry.Breaker>, c: Config, +ib: Chan(Msg<A>), fs: List<&1, Flight<A>>, +id: Nat, d: Nat, +x: A, g: Res.Grant,
    next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match a:
    case (+br, b, Retry.GateGo{}):
      do IO<Claimed(A)>:
        u : Chan(Msg<A>) <- IO.fork.go(Msg<A>, IO.bind(Retry.Outcome, Msg<A>, work(x), o => claim.tag(A, id, o)), ib)
        next(Runner{j, s, p, Map.set(&2, Retry.Breaker, bs, key, br), c, ib, Con{Flight{Q.Ticket{id, d, x}, g, b, key}, fs}})
    case (+br, b, Retry.GateNo{why}):
      do IO<Claimed(A)>:
        y : Ran(A) <- commit(~A, ~penc, Runner{j, s, p, Map.set(&2, Retry.Breaker, bs, key, br), c, ib, fs}, held(A, why, br, id, now))
        claim.held(A, y, g, next)

def claim.gate(~A: Data, ~penc: A -> Bytes.Bytes, ~work: A -> IO(Retry.Outcome), +now: Nat, got: Map<&2, Retry.Breaker> & Retry.Breaker, +key: String,
    j: Log, +s: State<A>, p: Res.Pool, +c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>, +id: Nat, d: Nat, +x: A, g: Res.Grant,
    next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  (bs, br) = got
  Config{pol, circ, idle, every} = c
  claim.go(~A, ~penc, ~work, now, Retry.admit(br, budget(pol, tries.get(tries(A, s), id)), now), key, j, s, p, bs, c, ib, fs, id, d, x, g, next)

# The selected ticket asks its target's breaker and its own budget for an attempt.
def claim.admit(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +now: Nat, r: Runner<A>, t: Q.Ticket<A>, g: Res.Grant,
    next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  Runner{j, s, p, bs, +c, ib, fs} = r
  Config{pol, circ, idle, every} = c
  Q.Ticket{id, d, +x} = t
  +key = target(x)
  claim.gate(~A, ~penc, ~work, now, Map.get(Retry.Breaker, Retry.Breaker.new(circ), bs, key), key, j, s, p, c, ib, fs, id, d, x, g, next)

def claim.selected(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +now: Nat, y: Ran(A),
    t: Q.Ticket<A>, g: Res.Grant, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match y:
    case (r, Fail{e}):
      IO.pure(Claimed(A), (release(A, r, g), 0n, Fail{e}))
    case (r, Done{u}):
      claim.admit(~A, ~penc, ~target, ~work, now, r, t, g, next)

def claim.pick(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +left: Nat, +now: Nat, k: Pick<A>, j: Log, s: State<A>,
    bs: Map<&2, Retry.Breaker>, c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match k:
    case Idle{p}:
      IO.pure(Claimed(A), (Runner{j, s, p, bs, c, ib, fs}, Nat.add(1n, left), Done{Unit{}}))
    case Picked{p, t, g}:
      do IO<Claimed(A)>:
        y : Ran(A) <- commit(~A, ~penc, Runner{j, s, p, bs, c, ib, fs}, Select{now})
        claim.selected(~A, ~penc, ~target, ~work, now, y, t, g, next)

# Starts an attempt for each due ticket while the pool has a free unit; each attempt sends its outcome on the inbox.
# fuel bounds the tickets taken, and the fuel left comes back.
def claim(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), fuel: Nat, +now: Nat, r: Runner<A>) -> IO(Claimed(A)):
  match fuel:
    case 0n:
      IO.pure(Claimed(A), (r, 0n, Done{Unit{}}))
    case 1n+n:
      Runner{j, +s, p, bs, c, ib, fs} = r
      +m = n
      claim.pick(~A, ~penc, ~target, ~work, m, now, pick(~A, p, s, now), j, s, bs, c, ib, fs, (r2 => claim(~A, ~penc, ~target, ~work, m, now, r2)))

def settle.done(-A: Data, y: Ran(A), g: Res.Grant, err: Out(Unit), next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  (r, res) = y
  next(release(A, r, g), first(err, res))

def settle.br(~A: Data, ~penc: A -> Bytes.Bytes, +failed: Bool, +key: String, +now: Nat, got: Map<&2, Retry.Breaker> & Retry.Breaker, +op: Op<A>,
    j: Log, s: State<A>, p: Res.Pool, c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>, g: Res.Grant, err: Out(Unit),
    next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  (bs, br) = got
  do IO<Runner<A> & Out(Bool)>:
    y : Ran(A) <- commit(~A, ~penc, Runner{j, s, p, Map.set(&2, Retry.Breaker, bs, key, Retry.Breaker.done(br, now, failed)), c, ib, fs}, op)
    settle.done(A, y, g, err, next)

# Tells the target's breaker, appends the outcome's op, and returns the attempt's unit to the pool.
# The op of a cancelled ticket changes no state: the queue no longer holds it.
def settle.op(~A: Data, ~penc: A -> Bytes.Bytes, +o: Retry.Outcome, b: Retry.Budget, +id: Nat, +key: String, +now: Nat, +rnd: Nat, r: Runner<A>, g: Res.Grant,
    err: Out(Unit), next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  Runner{j, +s, p, bs, +c, ib, fs} = r
  Config{pol, circ, idle, every} = c
  settle.br(~A, ~penc, Retry.failed(o), key, now, Map.get(Retry.Breaker, Retry.Breaker.new(circ), bs, key),
    after(A, o, pol, b, id, fails(tries.get(tries(A, s), id)), now, rnd), j, s, p, c, ib, fs, g, err, next)

def random(r: Out(U32)) -> Nat:
  match r:
    case Done{x}:
      U32.to_nat(x)
    case Fail{e}:
      0n

def take.keep(-A: Data, m: Maybe<&1, Flight<A>>, xs: List<&1, Flight<A>>) -> List<&1, Flight<A>>:
  match m:
    case None{}:
      xs
    case Some{f}:
      Con{f, xs}

def take.at(-A: Data, eq: Bool, f: Flight<A>, r: Maybe<&1, Flight<A>> & List<&1, Flight<A>>) -> Maybe<&1, Flight<A>> & List<&1, Flight<A>>:
  match eq:
    case True{}:
      (m, xs) = r
      (Some{f}, take.keep(A, m, xs))
    case False{}:
      (m, xs) = r
      (m, Con{f, xs})

# The flight of ticket id, and the other flights.
def take(-A: Data, fs: List<&1, Flight<A>>, +id: Nat) -> Maybe<&1, Flight<A>> & List<&1, Flight<A>>:
  match fs:
    case Nil{}:
      (None{}, Nil{})
    case Con{Flight{Q.Ticket{+i, d, x}, g, b, k}, rest}:
      take.at(A, Nat.is_eq(i, id), Flight{Q.Ticket{i, d, x}, g, b, k}, take(A, rest, id))

def settle.flight(~A: Data, ~penc: A -> Bytes.Bytes, mf: Maybe<&1, Flight<A>>, +o: Retry.Outcome, +now: Nat, +rnd: Nat, r: Runner<A>, err: Out(Unit),
    next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  match mf:
    case None{}:
      next(r, err)
    case Some{Flight{Q.Ticket{id, d, x}, g, b, key}}:
      settle.op(~A, ~penc, o, b, id, key, now, rnd, r, g, err, next)

def settle.take(~A: Data, ~penc: A -> Bytes.Bytes, t: Maybe<&1, Flight<A>> & List<&1, Flight<A>>, +o: Retry.Outcome, +now: Nat, +rnd: Nat,
    j: Log, s: State<A>, p: Res.Pool, bs: Map<&2, Retry.Breaker>, c: Config, ib: Chan(Msg<A>), err: Out(Unit),
    next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  (mf, fs) = t
  settle.flight(~A, ~penc, mf, o, now, rnd, Runner{j, s, p, bs, c, ib, fs}, err, next)

# Settles the flight of ticket id with outcome o.
def settle(~A: Data, ~penc: A -> Bytes.Bytes, +id: Nat, +o: Retry.Outcome, +now: Nat, +rnd: Nat, r: Runner<A>, err: Out(Unit),
    next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  Runner{j, s, p, bs, c, ib, fs} = r
  settle.take(~A, ~penc, take(A, fs, id), o, now, rnd, j, s, p, bs, c, ib, err, next)

# Sends the failure to the asker, and keeps it as the round's error.
def asked.failed(-A: Data, -X: Type, +rep: Chan(Out(X)), r: Runner<A>, +c: U32, +m: String, err: Out(Unit),
    next: Runner<A> -> Nat -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  do IO<Runner<A> & Out(Bool)>:
    x : Result<&1, &1, Out(X), Unit> <- Chan.send(Out(X), rep, Fail{(c, m)})
    next(r, 0n, first(err, Fail{(c, m)}))

def asked.fail(-A: Data, -X: Type, +rep: Chan(Out(X)), r: Runner<A>, e: U32 & String, err: Out(Unit),
    next: Runner<A> -> Nat -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  (c, m) = e
  asked.failed(A, X, rep, r, c, m, err, next)

def added(-A: Data, +rep: Chan(Out(Nat)), y: Runner<A> & Out(Nat), err: Out(Unit),
    next: Runner<A> -> Nat -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  match y:
    case (r, Done{+i}):
      do IO<Runner<A> & Out(Bool)>:
        x : Result<&1, &1, Out(Nat), Unit> <- Chan.send(Out(Nat), rep, Done{i})
        next(r, 1n, err)
    case (r, Fail{e}):
      asked.fail(A, Nat, rep, r, e, err, next)

def dropped(-A: Data, +rep: Chan(Out(Unit)), y: Ran(A), err: Out(Unit),
    next: Runner<A> -> Nat -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  match y:
    case (r, Done{u}):
      do IO<Runner<A> & Out(Bool)>:
        x : Result<&1, &1, Out(Unit), Unit> <- Chan.send(Out(Unit), rep, Done{Unit{}})
        next(r, 0n, err)
    case (r, Fail{e}):
      asked.fail(A, Unit, rep, r, e, err, next)

# Settles an ended attempt, or appends an ask's op and answers it. next gets the claim fuel the message adds: 1 for an enqueue.
def handle(~A: Data, ~penc: A -> Bytes.Bytes, m: Msg<A>, +now: Nat, +rnd: Nat, r: Runner<A>, err: Out(Unit),
    next: Runner<A> -> Nat -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  match m:
    case Ended{+id, +o}:
      settle(~A, ~penc, id, o, now, rnd, r, err, (r2 => e2 => next(r2, 0n, e2)))
    case Add{+d, x, +rep}:
      IO.bind(Runner<A> & Out(Nat), Runner<A> & Out(Bool), enqueue(~A, ~penc, r, d, x), y => added(A, rep, y, err, next))
    case Drop{+i, +rep}:
      IO.bind(Ran(A), Runner<A> & Out(Bool), cancel(~A, ~penc, r, i), y => dropped(A, rep, y, err, next))

def merged(-A: Data, e: Out(Unit), k: Claimed(A)) -> Claimed(A):
  (r, n, err) = k
  (r, n, first(e, err))

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
  State{Q.State{n, h, run}, ts, ds} = s
  Bool.and(empty.heap(A, h), empty.list(A, run))

def pending(-A: Data, s: State<A>) -> Nat:
  State{Q.State{n, h, run}, ts, ds} = s
  H.Heap.size(Q.Ticket<A>, h)

# The flights back, and whether none runs.
def flights.none(-A: Data, fs: List<&1, Flight<A>>) -> List<&1, Flight<A>> & Bool:
  match fs:
    case Nil{}:
      (Nil{}, True{})
    case Con{f, rest}:
      (Con{f, rest}, False{})

# ---- compaction

# Kept: compaction failed before the rename, and the old journal stands.
# Lost: the rename happened, but the new journal did not open. Moved: the journal at path is the snapshot.
type Swap is Type:
  Kept{err: U32 & String}
  Lost{err: U32 & String}
  Moved{journal: J.Journal}

def swap.reopened(x: Out(J.Journal & Unit)) -> Swap:
  match x:
    case Fail{e}:
      Lost{e}
    case Done{(j, u)}:
      Moved{j}

# The reopen fsyncs the directory, so the rename is durable before the next append.
def swap.renamed(+path: String, +limit: U32, x: Out(Unit)) -> IO(Swap):
  match x:
    case Fail{e}:
      IO.pure(Swap, Kept{e})
    case Done{u}:
      do IO<Swap>:
        y : Out(J.Journal & Unit) <- J.open(~Unit, ~(a => b => a), path, limit, limit, Unit{})
        return swap.reopened(y)

def swap.written(+path: String, +tmp: String, +limit: U32, x: J.Journal & Out(Unit)) -> IO(Swap):
  match x:
    case (t, Fail{e}):
      do IO<Swap>:
        J.close(t)
        return Kept{e}
    case (t, Done{u}):
      do IO<Swap>:
        J.close(t)
        y : Out(Unit) <- Files.rename(tmp, path)
        swap.renamed(path, limit, y)

def swap.opened(+path: String, +tmp: String, +limit: U32, x: Out(J.Journal & Unit), snap: Bytes.Bytes) -> IO(Swap):
  match x:
    case Fail{e}:
      IO.pure(Swap, Kept{e})
    case Done{(t, u)}:
      do IO<Swap>:
        y : J.Journal & Out(Unit) <- J.append(t, snap)
        swap.written(path, tmp, limit, y)

# Writes snap as the only record of path.compact, fsyncs it, and renames it over path.
def swap(+path: String, +limit: U32, snap: Bytes.Bytes) -> IO(Swap):
  +tmp = path ++ ".compact"
  do IO<Swap>:
    gone : Out(Unit) <- Files.remove(tmp)
    x : Out(J.Journal & Unit) <- J.open(~Unit, ~(a => b => a), tmp, limit, limit, Unit{})
    swap.opened(path, tmp, limit, x, snap)

def log.stop(j: J.Journal) -> J.Journal:
  J.Journal{file, max, end, ok} = j
  J.Journal{file, max, end, False{}}

def compact.moved(x: Swap, j: J.Journal, +max: U32, path: String, +limit: U32, +base: U32) -> IO(Log & Out(Unit)):
  match x:
    case Kept{e}:
      IO.pure(Log & Out(Unit), (Log{j, path, limit, base}, Fail{e}))
    case Lost{e}:
      IO.pure(Log & Out(Unit), (Log{log.stop(j), path, limit, base}, Fail{e}))
    case Moved{k}:
      do IO<Log & Out(Unit)>:
        J.close(j)
        return (log.of(k, max, path, limit), Done{Unit{}})

def compact.if(~A: Data, ~penc: A -> Bytes.Bytes, ok: Bool, j: J.Journal, +max: U32, +path: String, +limit: U32, +base: U32, s: State<A>) -> IO(Log & Out(Unit)):
  match ok:
    case False{}:
      IO.pure(Log & Out(Unit), (Log{j, path, limit, base}, Fail{(5, "runner: an append failed; reopen the runner")}))
    case True{}:
      do IO<Log & Out(Unit)>:
        x : Swap <- swap(path, limit, encode.snap(~A, ~penc, s))
        compact.moved(x, j, max, path, limit, base)

def compact.done(-A: Data, x: Log & Out(Unit), s: State<A>, p: Res.Pool, bs: Map<&2, Retry.Breaker>, c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>) -> Ran(A):
  (l, o) = x
  (Runner{l, s, p, bs, c, ib, fs}, o)

# Writes the state as one Snap record into a new journal, fsyncs it, and renames it over the old one.
# A crash leaves one of the two journals, and both replay to this state. After a failure the old
# journal stands; when the failure came after the rename, appends stop until the runner is reopened.
def compact(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>) -> IO(Ran(A)):
  Runner{Log{j, path, limit, base}, +s, p, bs, c, ib, fs} = r
  J.Journal{file, +max, end, +ok} = j
  do IO<Ran(A)>:
    x : Log & Out(Unit) <- compact.if(~A, ~penc, ok, J.Journal{file, max, end, ok}, max, path, limit, base, s)
    return compact.done(A, x, s, p, bs, c, ib, fs)

def tick.ran(e: Out(Unit), b: Bool) -> Out(Bool):
  match e:
    case Fail{x}:
      Fail{x}
    case Done{u}:
      Done{b}

def tick.compacted(-A: Data, +b: Bool, y: Ran(A)) -> Runner<A> & Out(Bool):
  (r, e) = y
  (r, tick.ran(e, b))

def tick.due(~A: Data, ~penc: A -> Bytes.Bytes, due: Bool, +b: Bool, r: Runner<A>) -> IO(Runner<A> & Out(Bool)):
  match due:
    case False{}:
      IO.pure(Runner<A> & Out(Bool), (r, Done{b}))
    case True{}:
      do IO<Runner<A> & Out(Bool)>:
        y : Ran(A) <- compact(~A, ~penc, r)
        return tick.compacted(A, b, y)

def tick.size(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +b: Bool) -> IO(Runner<A> & Out(Bool)):
  Runner{Log{J.Journal{file, max, +end, ok}, path, limit, +base}, s, p, bs, +c, ib, fs} = r
  Config{pol, circ, idle, +every} = c
  tick.due(~A, ~penc, Bool.and(Bool.not(U32.is_eq(every, 0)), U32.is_gt((end - base : U32), every)), b,
    Runner{Log{J.Journal{file, max, end, ok}, path, limit, base}, s, p, bs, c, ib, fs})

# Compacts once the journal grew past Config.compact octets since open or the last compaction.
def tick.grown(~A: Data, ~penc: A -> Bytes.Bytes, t: Runner<A> & Out(Bool)) -> IO(Runner<A> & Out(Bool)):
  match t:
    case (r, Fail{e}):
      IO.pure(Runner<A> & Out(Bool), (r, Fail{e}))
    case (r, Done{b}):
      tick.size(~A, ~penc, r, b)

def tick.polled(-A: Data, x: Poll<&1, &1, Maybe<&1, Msg<A>>, Unit>) -> Maybe<&1, Msg<A>>:
  match x:
    case Ready{m}:
      m
    case Wait{u}:
      None{}

def tick.wait(-A: Data, t: List<&1, Flight<A>> & Bool, j: Log, s: State<A>, p: Res.Pool, bs: Map<&2, Retry.Breaker>, c: Config, +ib: Chan(Msg<A>)) ->
    IO(Runner<A> & Maybe<&1, Msg<A>>):
  (fs, none) = t
  match none:
    case False{}:
      do IO<Runner<A> & Maybe<&1, Msg<A>>>:
        m : Maybe<&1, Msg<A>> <- Chan.recv(Msg<A>, ib)
        return (Runner{j, s, p, bs, c, ib, fs}, m)
    case True{}:
      do IO<Runner<A> & Maybe<&1, Msg<A>>>:
        x : Poll<&1, &1, Maybe<&1, Msg<A>>, Unit> <- Chan.try_recv(Msg<A>, ib, 0)
        return (Runner{j, s, p, bs, c, ib, fs}, tick.polled(A, x))

# The next message. While an attempt runs, it waits for one; when none runs, it takes one only when the inbox holds one.
def tick.next(-A: Data, r: Runner<A>) -> IO(Runner<A> & Maybe<&1, Msg<A>>):
  Runner{j, s, p, bs, c, ib, fs} = r
  tick.wait(A, flights.none(A, fs), j, s, p, bs, c, ib)

# Handles the message, then claims due tickets into free units with the claim fuel left. None ends the round.
def tick.got(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), x: Runner<A> & Maybe<&1, Msg<A>>, +ran: Bool, +left: Nat,
    err: Out(Unit), next: Claimed(A) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  (r, m) = x
  match m:
    case None{}:
      IO.pure(Runner<A> & Out(Bool), (r, tick.ran(err, ran)))
    case Some{msg}:
      do IO<Runner<A> & Out(Bool)>:
        +now : Nat <- clock()
        rnd : Out(U32) <- IO.random_u32()
        handle(~A, ~penc, msg, now, random(rnd), r, err, (r2 => more => e2 =>
          IO.bind(Claimed(A), Runner<A> & Out(Bool), claim(~A, ~penc, ~target, ~work, Nat.add(left, more), now, r2), k2 => next(merged(A, e2, k2)))))

# Handles messages until no attempt runs and the inbox is empty. fuel bounds the messages; attempts that still run
# when it ends stay in the runner, and the next tick settles them.
def tick.run(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), fuel: Nat, +ran: Bool, k: Claimed(A)) ->
    IO(Runner<A> & Out(Bool)):
  match fuel:
    case 0n:
      (r, left, err) = k
      IO.pure(Runner<A> & Out(Bool), (r, tick.ran(err, ran)))
    case 1n+n:
      (r, +left, err) = k
      do IO<Runner<A> & Out(Bool)>:
        x : Runner<A> & Maybe<&1, Msg<A>> <- tick.next(A, r)
        tick.got(~A, ~penc, ~target, ~work, x, ran, left, err, (k2 => tick.run(~A, ~penc, ~target, ~work, n, True{}, k2)))

# Fuel for each pending ticket, each attempt that may already run, and the last look at the inbox.
def tick.at(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +now: Nat, r: Runner<A>) -> IO(Runner<A> & Out(Bool)):
  Runner{j, +s, +p, bs, c, ib, fs} = r
  +fuel = Nat.add(2n, Nat.add(pending(A, s), Res.capacity(p)))
  do IO<Runner<A> & Out(Bool)>:
    k : Claimed(A) <- claim(~A, ~penc, ~target, ~work, fuel, now, Runner{j, s, p, bs, c, ib, fs})
    tick.run(~A, ~penc, ~target, ~work, fuel, False{}, k)

# One round: start an attempt for each due ticket the pool admits. Then read the inbox: as each attempt finishes, record its outcome,
# return its unit, and start the next due ticket in that unit; append and answer each ask from another fiber.
# The round ends when no attempt runs and the inbox is empty. Then compact the journal when it grew past Config.compact.
# Done{True} when an attempt ran or an ask was answered. work runs on its own; target names the breaker that guards it.
def tick(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), r: Runner<A>) -> IO(Runner<A> & Out(Bool)):
  do IO<Runner<A> & Out(Bool)>:
    now : Nat <- clock()
    t : Runner<A> & Out(Bool) <- tick.at(~A, ~penc, ~target, ~work, now, r)
    tick.grown(~A, ~penc, t)

def finished.of(-A: Data, +quiet: Bool, t: List<&1, Flight<A>> & Bool, j: Log, s: State<A>, p: Res.Pool, bs: Map<&2, Retry.Breaker>, c: Config, ib: Chan(Msg<A>)) ->
    Runner<A> & Bool:
  (fs, none) = t
  (Runner{j, s, p, bs, c, ib, fs}, Bool.and(quiet, none))

# The runner back, and whether no ticket is pending or running and no attempt runs.
def finished(-A: Data, r: Runner<A>) -> Runner<A> & Bool:
  Runner{j, +s, p, bs, c, ib, fs} = r
  finished.of(A, idle(A, s), flights.none(A, fs), j, s, p, bs, c, ib)

def drain.ticked(-A: Data, +idle: U32, t: Runner<A> & Out(Bool), next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  match t:
    case (r, Fail{e}):
      IO.pure(Ran(A), (r, Fail{e}))
    case (r, Done{True{}}):
      next(r)
    case (r, Done{False{}}):
      do IO<Ran(A)>:
        IO.sleep(idle)
        next(r)

def drain.if(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), done: Bool, r: Runner<A>, next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  match done:
    case True{}:
      IO.pure(Ran(A), (r, Done{Unit{}}))
    case False{}:
      Runner{j, s, p, bs, +c, ib, fs} = r
      Config{pol, circ, +idle, every} = c
      do IO<Ran(A)>:
        t : Runner<A> & Out(Bool) <- tick(~A, ~penc, ~target, ~work, Runner{j, s, p, bs, c, ib, fs})
        drain.ticked(A, idle, t, next)

def drain.at(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), x: Runner<A> & Bool, next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  (r, done) = x
  drain.if(~A, ~penc, ~target, ~work, done, r, next)

def drain.end(-A: Data, x: Runner<A> & Bool) -> Ran(A):
  (r, done) = x
  (r, Bool.pick(Out(Unit), done, Done{Unit{}}, Fail{(62, "runner: drain ran out of rounds")}))

# Ticks until no ticket is pending or running and no attempt runs. It waits idle ms after a round that did nothing.
# Fails when fuel rounds leave work.
def drain(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), fuel: Nat, r: Runner<A>) -> IO(Ran(A)):
  match fuel:
    case 0n:
      IO.pure(Ran(A), drain.end(A, finished(A, r)))
    case 1n+n:
      drain.at(~A, ~penc, ~target, ~work, finished(A, r), (r2 => drain(~A, ~penc, ~target, ~work, n, r2)))

def orphans.next(-A: Data, y: Ran(A), err: Out(Unit), next: Runner<A> -> Out(Unit) -> IO(Ran(A))) -> IO(Ran(A)):
  (r, e) = y
  next(r, first(err, e))

# A running ticket at open lost its attempt in a crash: it is requeued at now, as a failed attempt.
def orphans(~A: Data, ~penc: A -> Bytes.Bytes, ts: List<&2, Q.Ticket<A>>, +now: Nat, r: Runner<A>, err: Out(Unit)) -> IO(Ran(A)):
  match ts:
    case Nil{}:
      IO.pure(Ran(A), (r, err))
    case Con{Q.Ticket{id, d, x}, rest}:
      do IO<Ran(A)>:
        y : Ran(A) <- commit(~A, ~penc, r, Requeue{id, now})
        orphans.next(A, y, err, (r2 => e2 => orphans(~A, ~penc, rest, now, r2, e2)))

def close.answer(-A: Data, m: Msg<A>) -> IO(Unit):
  match m:
    case Ended{id, o}:
      IO.pure(Unit, Unit{})
    case Add{d, x, rep}:
      do IO<Unit>:
        y : Result<&1, &1, Out(Nat), Unit> <- Chan.send(Out(Nat), rep, Fail{(32, "runner: the runner closed")})
        return Unit{}
    case Drop{i, rep}:
      do IO<Unit>:
        y : Result<&1, &1, Out(Unit), Unit> <- Chan.send(Out(Unit), rep, Fail{(32, "runner: the runner closed")})
        return Unit{}

def close.polled(-A: Data, x: Poll<&1, &1, Maybe<&1, Msg<A>>, Unit>, next: Unit -> IO(Unit)) -> IO(Unit):
  match x:
    case Ready{Some{m}}:
      do IO<Unit>:
        close.answer(A, m)
        next(Unit{})
    case Ready{None{}}:
      IO.pure(Unit, Unit{})
    case Wait{u}:
      IO.pure(Unit, Unit{})

# Answers each ask left in the closed inbox with a failure. fuel bounds the messages it reads.
def close.drain(-A: Data, fuel: Nat, +ib: Chan(Msg<A>)) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+n:
      do IO<Unit>:
        x : Poll<&1, &1, Maybe<&1, Msg<A>>, Unit> <- Chan.try_recv(Msg<A>, ib, 0)
        close.polled(A, x, (u => close.drain(A, n, ib)))

# Closes the inbox and the journal. Each ask still in the inbox gets a failure, and no op is appended for it.
def close(-A: Data, r: Runner<A>) -> IO(Unit):
  Runner{j, s, +p, bs, c, +ib, fs} = r
  do IO<Unit>:
    Chan.close(Msg<A>, ib)
    close.drain(A, Nat.add(2n, Res.capacity(p)), ib)
    log.close(j)

def open.done(-A: Data, y: Ran(A)) -> IO(Out(Runner<A>)):
  match y:
    case (r, Fail{e}):
      do IO<Out(Runner<A>)>:
        close(A, r)
        return Fail{e}
    case (r, Done{u}):
      IO.pure(Out(Runner<A>), Done{r})

def open.got(~A: Data, ~penc: A -> Bytes.Bytes, x: Out(J.Journal & Maybe<&2, State<A>>), +max: U32, path: String, +limit: U32, c: Config, +capacity: Nat) ->
    IO(Out(Runner<A>)):
  match x:
    case Fail{e}:
      IO.pure(Out(Runner<A>), Fail{e})
    case Done{(j, None{})}:
      do IO<Out(Runner<A>)>:
        J.close(j)
        return Fail{(22, "runner: a journal record is not a runner record")}
    case Done{(j, Some{+s})}:
      do IO<Out(Runner<A>)>:
        now : Nat <- clock()
        ib : Chan(Msg<A>) <- Chan.new(Msg<A>, (U32.from_nat(capacity) + 1 : U32))
        y : Ran(A) <- orphans(~A, ~penc, Q.running(A, queue(A, s)), now, Runner{log.of(j, max, path, limit), s, Res.new(0n, capacity), Map.new(&2, Retry.Breaker), c, ib, Nil{}}, Done{Unit{}})
        open.done(A, y)

def replay.step(~A: Data, ~pdec: Bytes.Bytes -> Maybe<&2, A>, acc: Maybe<&2, State<A>>, b: Bytes.Bytes) -> Maybe<&2, State<A>>:
  load(~A, ~Bytes.Bytes, ~(y => decode.rec(~A, ~pdec, y)), acc, b)

# Opens the runner at path: replays its journal into the state, then requeues each ticket that was running.
# capacity bounds the attempts that run at once. max caps an op record's octets; limit caps the journal file and a snapshot.
# Fails when the journal fails to open, or a committed record is not a snapshot or an op.
def open(~A: Data, ~penc: A -> Bytes.Bytes, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +path: String, +max: U32, +limit: U32, c: Config, +capacity: Nat) -> IO(Out(Runner<A>)):
  do IO<Out(Runner<A>)>:
    x : Out(J.Journal & Maybe<&2, State<A>>) <- J.open(~Maybe<&2, State<A>>, ~(acc => b => replay.step(~A, ~pdec, acc, b)), path, limit, limit, Some{new(A)})
    open.got(~A, ~penc, x, max, path, limit, c, capacity)

# The runner back, and a copy of its state.
def state(-A: Data, r: Runner<A>) -> Runner<A> & State<A>:
  Runner{j, +s, p, bs, c, ib, fs} = r
  (Runner{j, s, p, bs, c, ib, fs}, s)
