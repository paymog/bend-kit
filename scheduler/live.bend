import Base
import bend-kit-concurrency@0.2.0.0/concurrency.bend as Conc
import ./queue.bend as Q
import bend-kit-time@0.3.0.0/time.bend as Time
import ./recurrence.bend as R
import ./check.bend as Check

# Host work is deliberately outside the transition core.
def work(s: Unit, value: U32) -> IO(Unit & U32):
  do IO<Unit & U32>:
    IO.sleep(2)
    return (s, value)

def result(r: List<Unit> & List<U32>, +want: U32) -> IO(Unit):
  (states, values) = r
  match values:
    case Con{v, Nil{}}:
      Check.require(U32.is_eq(v, want), "worker changed the scheduled payload")
    case _:
      IO.die(Unit, 1, "worker lost the scheduled payload")

def execute(+now: Nat, s: Q.State<U32>, ticket: Maybe<&2, Q.Ticket<U32>>) -> IO(Check.Outcome<Maybe<&2, U32>>):
  match ticket:
    case None{}:
      do IO<Check.Outcome<Maybe<&2, U32>>>:
        IO.sleep(1)
        return Check.Outcome{s, None{}}
    case Some{Q.Ticket{+id, +deadline, +payload}}:
      do IO<Check.Outcome<Maybe<&2, U32>>>:
        Check.require(Nat.is_le(deadline, now), "selected before monotonic deadline")
        outputs : List<Unit> & List<U32> <- Conc.pool(~Unit, ~U32, ~U32, ~work, [Unit{}], [payload])
        result(outputs, payload)
        +completed : Check.Outcome<Maybe<&2, Q.Ticket<U32>>> = Check.complete(id, s)
        Check.require(Check.picked(Check.ticket(completed), id, deadline, payload), "lost completion token")
        IO.print("selected " ++ U32.show(payload) ++ " at " ++ Nat.show(now) ++ ", deadline " ++ Nat.show(deadline))
        return Check.Outcome{Check.selected(completed), Some{payload}}

def execute.selected(now: Nat, selected: Q.State<U32> & Maybe<&2, Q.Ticket<U32>>) -> IO(Check.Outcome<Maybe<&2, U32>>):
  (s, ticket) = selected
  execute(now, s, ticket)

def advance(m: Maybe<&2, U32>, expected: List<U32>) -> IO(List<U32>):
  match m expected:
    case None{} xs:
      IO.pure(List<U32>, xs)
    case Some{+got} Con{want, rest}:
      do IO<List<U32>>:
        Check.require(U32.is_eq(got, want), "real runner selection order changed")
        return rest
    case Some{got} Nil{}:
      IO.die(List<U32>, 1, "unexpected scheduled job")

def run(fuel: Nat, s: Q.State<U32>, expected: List<U32>) -> IO(Unit):
  match fuel expected:
    case _ Nil{}:
      IO.print("scheduler: real monotonic runner order and pending cancellation pass")
    case 0n Con{x, xs}:
      IO.die(Unit, 1, "timer consumer exhausted its polling fuel")
    case 1n+p Con{x, xs}:
      do IO<Unit>:
        raw : Nat <- Time.mono.ms()
        +now : Nat = raw
        outcome : Check.Outcome<Maybe<&2, U32>> <- execute.selected(now, Q.select(~U32, now, s))
        +step : Check.Outcome<Maybe<&2, U32>> = outcome
        todo : List<U32> <- advance(Check.value(Maybe<&2, U32>, step), Con{x, xs})
        run(p, Check.state(Maybe<&2, U32>, step), todo)

def slow(+value: U32) -> IO(U32):
  do IO<U32>:
    IO.sleep(5)
    return value

# Cancelling a selected ticket cannot interrupt host work; it does revoke requeue.
def running(s: Q.State<U32>, ticket: Maybe<&2, Q.Ticket<U32>>) -> IO(Unit):
  match ticket:
    case None{}:
      IO.die(Unit, 1, "running cancellation scenario did not select")
    case Some{Q.Ticket{+id, deadline, +payload}}:
      do IO<Unit>:
        worker : Chan(U32) <- IO.fork(U32, slow(payload))
        cancelled : Q.State<U32> = Q.cancel(~U32, id, s)
        value : U32 <- IO.join(U32, worker)
        +restarted : Check.Outcome<Bool> = Check.requeue(id, 0n, cancelled)
        done : Check.Outcome<Maybe<&2, Q.Ticket<U32>>> = Check.complete(id, Check.state(Bool, restarted))
        Check.require(U32.is_eq(value, payload), "already-running work did not finish")
        Check.require(Bool.not(Check.value(Bool, restarted)) && Check.absent(Check.ticket(done)), "cancelled running work resurrected")
        IO.print("scheduler: running work finishes, cancellation revokes future selection")

def running_cancel() -> IO(Unit):
  e = Check.enqueue(0n, 8, Q.new(U32))
  +selected = Check.select(0n, Check.state(Nat, e))
  running(Check.selected(selected), Check.ticket(selected))

def start(+now: Nat) -> IO(Unit):
  e0 = Check.enqueue((now + 10n : Nat), 1, Q.new(U32))
  e1 = Check.enqueue((now + 10n : Nat), 2, Check.state(Nat, e0))
  +e2 = Check.enqueue((now + 5n : Nat), 99, Check.state(Nat, e1))
  e3 = Check.enqueue((now + 20n : Nat), 3, Check.state(Nat, e2))
  run(10000n, Q.cancel(~U32, Check.value(Nat, e2), Check.state(Nat, e3)), [1, 2, 3])

# A fixed-delay consumer runs twice, reusing one ID rather than completing it
# before rescheduling. Completion time comes from the real monotonic clock.
def recurring.plan(plan: Maybe<&2, R.Plan>, s: Q.State<U32>, id: Nat) -> IO(Unit):
  match plan:
    case None{}:
      IO.die(Unit, 1, "recurrence rejected a positive period")
    case Some{R.Planned{replay, +next}}:
      +restarted = Check.requeue(id, next, s)
      do IO<Unit>:
        Check.require(Check.value(Bool, restarted), "recurrence lost its running token")
        IO.print("fixed-delay requeue at " ++ Nat.show(next))
        run(10000n, Check.state(Bool, restarted), [4])

def recurring.first(s: Q.State<U32>, ticket: Maybe<&2, Q.Ticket<U32>>) -> IO(Unit):
  match ticket:
    case None{}:
      IO.die(Unit, 1, "recurring consumer did not select first tick")
    case Some{Q.Ticket{id, deadline, +payload}}:
      do IO<Unit>:
        outputs : List<Unit> & List<U32> <- Conc.pool(~Unit, ~U32, ~U32, ~work, [Unit{}], [payload])
        result(outputs, payload)
        finished : Nat <- Time.mono.ms()
        recurring.plan(R.plan(deadline, finished, 5n, R.FixedDelay{}), s, id)

def recurring() -> IO(Unit):
  e = Check.enqueue(0n, 4, Q.new(U32))
  +selected = Check.select(0n, Check.state(Nat, e))
  recurring.first(Check.selected(selected), Check.ticket(selected))

def main() -> IO(Unit):
  do IO<Unit>:
    now : Nat <- Time.mono.ms()
    start(now)
    running_cancel()
    recurring()
