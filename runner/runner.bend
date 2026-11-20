# Durable job runner: a journaled scheduler queue, bounded by a resources pool, with retry and a breaker per target. Source: https://github.com/paymog/bend-kit/tree/main/runner
import Base
import ./model.bend as Model
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-journal@0.3.1.1/journal.bend as J
import bend-kit-scheduler@0.4.3.0/queue.bend as Q
import bend-kit-resources@0.1.0.0/resources.bend as Res
import bend-kit-retry@0.3.0.0/retry.bend as Retry
import bend-kit-time@0.3.0.0/time.bend as Time
import bend-kit-collections@0.1.5.0/heap.bend as H
import bend-kit-files@0.4.0.0/files.bend as Files


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
  Runner{log: Log, state: Model.State<A>, pool: Res.Pool, config: Config, inbox: Chan(Msg<A>), flights: List<&1, Flight<A>>}

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

def commit.done(~A: Data, x: Log & Out(Unit), s: Model.State<A>, +op: Model.Op<A>, p: Res.Pool, c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>) -> Ran(A):
  match x:
    case (j, Done{u}):
      (Runner{j, Model.step(~A, s, op), p, c, ib, fs}, Done{u})
    case (j, Fail{e}):
      (Runner{j, s, p, c, ib, fs}, Fail{e})

# Appends op, and applies it once the append is durable. After a failed append the state is as it was,
# and the journal refuses every later append until the runner is reopened.
def commit(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +op: Model.Op<A>) -> IO(Ran(A)):
  Runner{j, s, p, c, ib, fs} = r
  do IO<Ran(A)>:
    x : Log & Out(Unit) <- log.append(j, Model.encode(~A, ~penc, op))
    return commit.done(~A, x, s, op, p, c, ib, fs)

def enqueue.done(-A: Data, +id: Nat, y: Ran(A)) -> Runner<A> & Out(Nat):
  match y:
    case (r, Done{u}):
      (r, Done{id})
    case (r, Fail{e}):
      (r, Fail{e})

# Adds a job that is due at deadline (wall-clock ms) and answers its ticket id once the record is durable.
def enqueue(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +deadline: Nat, x: A) -> IO(Runner<A> & Out(Nat)):
  Runner{j, +s, p, c, ib, fs} = r
  do IO<Runner<A> & Out(Nat)>:
    y : Ran(A) <- commit(~A, ~penc, Runner{j, s, p, c, ib, fs}, Model.Enqueue{deadline, x})
    return enqueue.done(A, Q.next_id(A, Model.queue(A, s)), y)

# Cancels ticket id. A running attempt finishes, but its ticket is never selected again. A dead ticket is dropped.
def cancel(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +id: Nat) -> IO(Ran(A)):
  commit(~A, ~penc, r, Model.Cancel{id})

# Makes dead ticket id pending again at deadline (wall-clock ms), with its payload and a new retry budget.
# A ticket that is not dead does not change.
def revive(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +id: Nat, +deadline: Nat) -> IO(Ran(A)):
  commit(~A, ~penc, r, Model.Revive{id, deadline})

# Drops, as one record, the dead tickets that retry gave up on before `before` (wall-clock ms).
def purge(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +before: Nat) -> IO(Ran(A)):
  commit(~A, ~penc, r, Model.Purge{before})

# Drops every dead ticket, as one record.
def purge.all(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>) -> IO(Ran(A)):
  commit(~A, ~penc, r, Model.PurgeAll{})

# ---- asks from other fibers

# The runner back, and its inbox. Another fiber passes the inbox to ask.enqueue and ask.cancel.
def inbox(-A: Data, r: Runner<A>) -> Runner<A> & Chan(Msg<A>):
  Runner{j, s, p, c, +ib, fs} = r
  (Runner{j, s, p, c, ib, fs}, ib)

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
def release.got(-A: Data, x: Res.Release, j: Log, s: Model.State<A>, c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>) -> Runner<A>:
  match x:
    case Res.Released{p}:
      Runner{j, s, p, c, ib, fs}
    case Res.Kept{p, g}:
      Runner{j, s, p, c, ib, fs}

def release(-A: Data, r: Runner<A>, g: Res.Grant) -> Runner<A>:
  Runner{j, s, p, c, ib, fs} = r
  release.got(A, Res.release(p, g), j, s, c, ib, fs)

def claim.held(-A: Data, y: Ran(A), g: Res.Grant, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match y:
    case (r, Fail{e}):
      IO.pure(Claimed(A), (release(A, r, g), 0n, Fail{e}))
    case (r, Done{u}):
      next(release(A, r, g))

def claim.tag(-A: Data, +id: Nat, o: Retry.Outcome) -> IO(Msg<A>):
  IO.pure(Msg<A>, Ended{id, o})

def trip.if(~A: Data, ~penc: A -> Bytes.Bytes, same: Bool, r: Runner<A>, +key: String, st: Retry.State) -> IO(Ran(A)):
  match same:
    case True{}:
      IO.pure(Ran(A), (r, Done{Unit{}}))
    case False{}:
      commit(~A, ~penc, r, Model.Break{key, st})

# Appends a Break when the target's breaker left old, so that a reopen restores it.
def trip(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>, +key: String, +old: Retry.State, br: Retry.Breaker) -> IO(Ran(A)):
  +st = Model.brk.state(br, old)
  trip.if(~A, ~penc, Model.brk.same(old, st), r, key, st)

def claim.go(~A: Data, ~penc: A -> Bytes.Bytes, ~work: A -> IO(Retry.Outcome), +now: Nat, gate: Retry.Gate, +br: Retry.Breaker, b: Retry.Budget, +key: String,
    r: Runner<A>, +id: Nat, d: Nat, +x: A, g: Res.Grant, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match gate:
    case Retry.GateGo{}:
      Runner{j, s, p, c, +ib, fs} = r
      do IO<Claimed(A)>:
        u : Chan(Msg<A>) <- IO.fork.go(Msg<A>, IO.bind(Retry.Outcome, Msg<A>, work(x), o => claim.tag(A, id, o)), ib)
        next(Runner{j, s, p, c, ib, Con{Flight{Q.Ticket{id, d, x}, g, b, key}, fs}})
    case Retry.GateNo{why}:
      do IO<Claimed(A)>:
        y : Ran(A) <- commit(~A, ~penc, r, Model.held(A, why, br, id, now))
        claim.held(A, y, g, next)

def claim.tripped(~A: Data, ~penc: A -> Bytes.Bytes, ~work: A -> IO(Retry.Outcome), +now: Nat, y: Ran(A), gate: Retry.Gate, +br: Retry.Breaker, b: Retry.Budget, +key: String,
    +id: Nat, d: Nat, +x: A, g: Res.Grant, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match y:
    case (r, Fail{e}):
      IO.pure(Claimed(A), (release(A, r, g), 0n, Fail{e}))
    case (r, Done{u}):
      claim.go(~A, ~penc, ~work, now, gate, br, b, key, r, id, d, x, g, next)

# A change to the breaker is durable before the attempt starts.
def claim.gate(~A: Data, ~penc: A -> Bytes.Bytes, ~work: A -> IO(Retry.Outcome), +now: Nat, a: Retry.Breaker & Retry.Budget & Retry.Gate, +key: String, +old: Retry.State,
    r: Runner<A>, +id: Nat, d: Nat, +x: A, g: Res.Grant, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  (+br, b, gate) = a
  do IO<Claimed(A)>:
    y : Ran(A) <- trip(~A, ~penc, r, key, old, br)
    claim.tripped(~A, ~penc, ~work, now, y, gate, br, b, key, id, d, x, g, next)

# The selected ticket asks its target's breaker and its own budget for an attempt.
def claim.admit(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +now: Nat, r: Runner<A>, t: Q.Ticket<A>, g: Res.Grant,
    next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  Runner{j, +s, p, +c, ib, fs} = r
  Config{pol, circ, idle, every} = c
  Q.Ticket{+id, d, +x} = t
  +key = target(x)
  +old = Model.brk.get(A, s, key)
  claim.gate(~A, ~penc, ~work, now, Retry.admit(Retry.BreakerOn{circ, old}, Model.budget(pol, Model.tries.get(Model.tries(A, s), id)), now), key, old,
    Runner{j, s, p, c, ib, fs}, id, d, x, g, next)

def claim.selected(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +now: Nat, y: Ran(A),
    t: Q.Ticket<A>, g: Res.Grant, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match y:
    case (r, Fail{e}):
      IO.pure(Claimed(A), (release(A, r, g), 0n, Fail{e}))
    case (r, Done{u}):
      claim.admit(~A, ~penc, ~target, ~work, now, r, t, g, next)

def claim.pick(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +left: Nat, +now: Nat, k: Model.Pick<A>, j: Log, s: Model.State<A>,
    c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>, next: Runner<A> -> IO(Claimed(A))) -> IO(Claimed(A)):
  match k:
    case Model.Idle{p}:
      IO.pure(Claimed(A), (Runner{j, s, p, c, ib, fs}, Nat.add(1n, left), Done{Unit{}}))
    case Model.Picked{p, t, g}:
      do IO<Claimed(A)>:
        y : Ran(A) <- commit(~A, ~penc, Runner{j, s, p, c, ib, fs}, Model.Select{now})
        claim.selected(~A, ~penc, ~target, ~work, now, y, t, g, next)

# Starts an attempt for each due ticket while the pool has a free unit; each attempt sends its outcome on the inbox.
# fuel bounds the tickets taken, and the fuel left comes back.
def claim(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), fuel: Nat, +now: Nat, r: Runner<A>) -> IO(Claimed(A)):
  match fuel:
    case 0n:
      IO.pure(Claimed(A), (r, 0n, Done{Unit{}}))
    case 1n+n:
      Runner{j, +s, p, c, ib, fs} = r
      +m = n
      claim.pick(~A, ~penc, ~target, ~work, m, now, Model.pick(~A, p, s, now), j, s, c, ib, fs, (r2 => claim(~A, ~penc, ~target, ~work, m, now, r2)))

def settle.done(-A: Data, y: Ran(A), g: Res.Grant, err: Out(Unit), next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  (r, res) = y
  next(release(A, r, g), first(err, res))

def settle.br(~A: Data, ~penc: A -> Bytes.Bytes, +op: Model.Op<A>, y: Ran(A), g: Res.Grant, err: Out(Unit),
    next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  match y:
    case (r, Fail{e}):
      next(release(A, r, g), first(err, Fail{e}))
    case (r, Done{u}):
      do IO<Runner<A> & Out(Bool)>:
        z : Ran(A) <- commit(~A, ~penc, r, op)
        settle.done(A, z, g, err, next)

# Tells the target's breaker, appends the outcome's op, and returns the attempt's unit to the pool.
# The op of a cancelled ticket changes no state: the queue no longer holds it.
def settle.op(~A: Data, ~penc: A -> Bytes.Bytes, +o: Retry.Outcome, b: Retry.Budget, +id: Nat, +key: String, +now: Nat, +rnd: Nat, r: Runner<A>, g: Res.Grant,
    err: Out(Unit), next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  Runner{j, +s, p, +c, ib, fs} = r
  Config{pol, circ, idle, every} = c
  +old = Model.brk.get(A, s, key)
  do IO<Runner<A> & Out(Bool)>:
    y : Ran(A) <- trip(~A, ~penc, Runner{j, s, p, c, ib, fs}, key, old, Model.brk.after(circ, old, now, o))
    settle.br(~A, ~penc, Model.after(A, o, pol, b, id, Model.fails(Model.tries.get(Model.tries(A, s), id)), now, rnd), y, g, err, next)

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
    j: Log, s: Model.State<A>, p: Res.Pool, c: Config, ib: Chan(Msg<A>), err: Out(Unit),
    next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  (mf, fs) = t
  settle.flight(~A, ~penc, mf, o, now, rnd, Runner{j, s, p, c, ib, fs}, err, next)

# Settles the flight of ticket id with outcome o.
def settle(~A: Data, ~penc: A -> Bytes.Bytes, +id: Nat, +o: Retry.Outcome, +now: Nat, +rnd: Nat, r: Runner<A>, err: Out(Unit),
    next: Runner<A> -> Out(Unit) -> IO(Runner<A> & Out(Bool))) -> IO(Runner<A> & Out(Bool)):
  Runner{j, s, p, c, ib, fs} = r
  settle.take(~A, ~penc, take(A, fs, id), o, now, rnd, j, s, p, c, ib, err, next)

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


# The flights back, and whether none runs.
def flights.none(-A: Data, fs: List<&1, Flight<A>>) -> List<&1, Flight<A>> & Bool:
  match fs:
    case Nil{}:
      (Nil{}, True{})
    case Con{f, rest}:
      (Con{f, rest}, False{})

# ---- compaction

# Kept: compaction failed before the rename, and the old journal stands.
# Stranded: the rename happened, but the new journal did not open. Moved: the journal at path is the snapshot.
type Swap is Type:
  Kept{err: U32 & String}
  Stranded{err: U32 & String}
  Moved{journal: J.Journal}

def swap.reopened(x: Out(J.Journal & Unit)) -> Swap:
  match x:
    case Fail{e}:
      Stranded{e}
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
    case Stranded{e}:
      IO.pure(Log & Out(Unit), (Log{log.stop(j), path, limit, base}, Fail{e}))
    case Moved{k}:
      do IO<Log & Out(Unit)>:
        J.close(j)
        return (log.of(k, max, path, limit), Done{Unit{}})

def compact.if(~A: Data, ~penc: A -> Bytes.Bytes, ok: Bool, j: J.Journal, +max: U32, +path: String, +limit: U32, +base: U32, s: Model.State<A>) -> IO(Log & Out(Unit)):
  match ok:
    case False{}:
      IO.pure(Log & Out(Unit), (Log{j, path, limit, base}, Fail{(5, "runner: an append failed; reopen the runner")}))
    case True{}:
      do IO<Log & Out(Unit)>:
        x : Swap <- swap(path, limit, Model.encode.snap(~A, ~penc, s))
        compact.moved(x, j, max, path, limit, base)

def compact.done(-A: Data, x: Log & Out(Unit), s: Model.State<A>, p: Res.Pool, c: Config, ib: Chan(Msg<A>), fs: List<&1, Flight<A>>) -> Ran(A):
  (l, o) = x
  (Runner{l, s, p, c, ib, fs}, o)

# Writes the state as one Snap record into a new journal, fsyncs it, and renames it over the old one.
# A crash leaves one of the two journals, and both replay to this state. After a failure the old
# journal stands; when the failure came after the rename, appends stop until the runner is reopened.
def compact(~A: Data, ~penc: A -> Bytes.Bytes, r: Runner<A>) -> IO(Ran(A)):
  Runner{Log{j, path, limit, base}, +s, p, c, ib, fs} = r
  J.Journal{file, +max, end, +ok} = j
  do IO<Ran(A)>:
    x : Log & Out(Unit) <- compact.if(~A, ~penc, ok, J.Journal{file, max, end, ok}, max, path, limit, base, s)
    return compact.done(A, x, s, p, c, ib, fs)

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
  Runner{Log{J.Journal{file, max, +end, ok}, path, limit, +base}, s, p, +c, ib, fs} = r
  Config{pol, circ, idle, +every} = c
  tick.due(~A, ~penc, Bool.and(Bool.not(U32.is_eq(every, 0)), U32.is_gt((end - base : U32), every)), b,
    Runner{Log{J.Journal{file, max, end, ok}, path, limit, base}, s, p, c, ib, fs})

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

def tick.wait(-A: Data, t: List<&1, Flight<A>> & Bool, j: Log, s: Model.State<A>, p: Res.Pool, c: Config, +ib: Chan(Msg<A>)) ->
    IO(Runner<A> & Maybe<&1, Msg<A>>):
  (fs, none) = t
  match none:
    case False{}:
      do IO<Runner<A> & Maybe<&1, Msg<A>>>:
        m : Maybe<&1, Msg<A>> <- Chan.recv(Msg<A>, ib)
        return (Runner{j, s, p, c, ib, fs}, m)
    case True{}:
      do IO<Runner<A> & Maybe<&1, Msg<A>>>:
        x : Poll<&1, &1, Maybe<&1, Msg<A>>, Unit> <- Chan.try_recv(Msg<A>, ib, 0)
        return (Runner{j, s, p, c, ib, fs}, tick.polled(A, x))

# The next message. While an attempt runs, it waits for one; when none runs, it takes one only when the inbox holds one.
def tick.next(-A: Data, r: Runner<A>) -> IO(Runner<A> & Maybe<&1, Msg<A>>):
  Runner{j, s, p, c, ib, fs} = r
  tick.wait(A, flights.none(A, fs), j, s, p, c, ib)

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
  Runner{j, +s, +p, c, ib, fs} = r
  +fuel = Nat.add(2n, Nat.add(Model.pending(A, s), Res.capacity(p)))
  do IO<Runner<A> & Out(Bool)>:
    k : Claimed(A) <- claim(~A, ~penc, ~target, ~work, fuel, now, Runner{j, s, p, c, ib, fs})
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

def finished.of(-A: Data, +quiet: Bool, t: List<&1, Flight<A>> & Bool, j: Log, s: Model.State<A>, p: Res.Pool, c: Config, ib: Chan(Msg<A>)) ->
    Runner<A> & Bool:
  (fs, none) = t
  (Runner{j, s, p, c, ib, fs}, Bool.and(quiet, none))

# The runner back, and whether no ticket is pending or running and no attempt runs.
def finished(-A: Data, r: Runner<A>) -> Runner<A> & Bool:
  Runner{j, +s, p, c, ib, fs} = r
  finished.of(A, Model.idle(A, s), flights.none(A, fs), j, s, p, c, ib)

def drain.handled(-A: Data, t: Runner<A> & Out(Bool), next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  match t:
    case (r, Fail{e}):
      IO.pure(Ran(A), (r, Fail{e}))
    case (r, Done{b}):
      next(r)

def drain.woke(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +idle: U32,
    x: Poll<&1, &1, Maybe<&1, Msg<A>>, Unit>, r: Runner<A>, next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  match x:
    case Ready{Some{m}}:
      do IO<Ran(A)>:
        t : Runner<A> & Out(Bool) <- tick.got(~A, ~penc, ~target, ~work, (r, Some{m}), True{}, 0n, Done{Unit{}},
          (k => tick.run(~A, ~penc, ~target, ~work, 0n, True{}, k)))
        drain.handled(A, t, next)
    case Ready{None{}}:
      do IO<Ran(A)>:
        IO.sleep(idle)
        next(r)
    case Wait{u}:
      next(r)


def drain.poll(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +ms: U32, r: Runner<A>,
    next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  Runner{j, s, p, c, +ib, fs} = r
  do IO<Ran(A)>:
    x : Poll<&1, &1, Maybe<&1, Msg<A>>, Unit> <- Chan.try_recv(Msg<A>, ib, ms)
    drain.woke(~A, ~penc, ~target, ~work, ms, x, Runner{j, s, p, c, ib, fs}, next)

def drain.wait(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +idle: U32, r: Runner<A>,
    next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  Runner{j, +s, p, c, ib, fs} = r
  do IO<Ran(A)>:
    now : Nat <- clock()
    drain.poll(~A, ~penc, ~target, ~work, Model.drain.ms(A, idle, now, Model.soonest(A, s)), Runner{j, s, p, c, ib, fs}, next)

def drain.ticked(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), +idle: U32,
    t: Runner<A> & Out(Bool), next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  match t:
    case (r, Fail{e}):
      IO.pure(Ran(A), (r, Fail{e}))
    case (r, Done{True{}}):
      next(r)
    case (r, Done{False{}}):
      drain.wait(~A, ~penc, ~target, ~work, idle, r, next)

def drain.if(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), done: Bool, r: Runner<A>, next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  match done:
    case True{}:
      IO.pure(Ran(A), (r, Done{Unit{}}))
    case False{}:
      Runner{j, s, p, +c, ib, fs} = r
      Config{pol, circ, +idle, every} = c
      do IO<Ran(A)>:
        t : Runner<A> & Out(Bool) <- tick(~A, ~penc, ~target, ~work, Runner{j, s, p, c, ib, fs})
        drain.ticked(~A, ~penc, ~target, ~work, idle, t, next)

def drain.at(~A: Data, ~penc: A -> Bytes.Bytes, ~target: A -> String, ~work: A -> IO(Retry.Outcome), x: Runner<A> & Bool, next: Runner<A> -> IO(Ran(A))) -> IO(Ran(A)):
  (r, done) = x
  drain.if(~A, ~penc, ~target, ~work, done, r, next)

def drain.end(-A: Data, x: Runner<A> & Bool) -> Ran(A):
  (r, done) = x
  (r, Bool.pick(Out(Unit), done, Done{Unit{}}, Fail{(62, "runner: drain ran out of rounds")}))

# Ticks until no ticket is pending or running and no attempt runs. After a round that did nothing, it waits for a message
# up to idle ms, or until the earliest pending ticket is due when that is sooner, and handles one that arrives at once.
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
        y : Ran(A) <- commit(~A, ~penc, r, Model.Requeue{id, now})
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
  Runner{j, s, +p, c, +ib, fs} = r
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

def open.got(~A: Data, ~penc: A -> Bytes.Bytes, x: Out(J.Journal & Maybe<&2, Model.State<A>>), +max: U32, path: String, +limit: U32, c: Config, +capacity: Nat) ->
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
        y : Ran(A) <- orphans(~A, ~penc, Q.running(A, Model.queue(A, s)), now, Runner{log.of(j, max, path, limit), Model.calm(A, s), Res.new(0n, capacity), c, ib, Nil{}}, Done{Unit{}})
        open.done(A, y)


# Opens the runner at path: replays its journal into the state, then requeues each ticket that was running.
# capacity bounds the attempts that run at once. max caps an op record's octets; limit caps the journal file and a snapshot.
# Fails when the journal fails to open, or a committed record is not a snapshot or an op.
def open(~A: Data, ~penc: A -> Bytes.Bytes, ~pdec: Bytes.Bytes -> Maybe<&2, A>, +path: String, +max: U32, +limit: U32, c: Config, +capacity: Nat) -> IO(Out(Runner<A>)):
  do IO<Out(Runner<A>)>:
    x : Out(J.Journal & Maybe<&2, Model.State<A>>) <- J.open(~Maybe<&2, Model.State<A>>, ~(acc => b => Model.replay.step(~A, ~pdec, acc, b)), path, limit, limit, Some{Model.new(A)})
    open.got(~A, ~penc, x, max, path, limit, c, capacity)

# The runner back, and a copy of its state.
def state(-A: Data, r: Runner<A>) -> Runner<A> & Model.State<A>:
  Runner{j, +s, p, c, ib, fs} = r
  (Runner{j, s, p, c, ib, fs}, s)
