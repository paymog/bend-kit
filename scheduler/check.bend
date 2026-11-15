import Base
import ./queue.bend as Q
import ./recurrence.bend as R

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

type Outcome<-A: Data> is Data:
  Outcome{s: Q.State<U32>, x: A}

def outcome(-A: Data, pair: Q.State<U32> & A) -> Outcome<A>:
  (s, x) = pair
  Outcome{s, x}

def state(-A: Data, pair: Outcome<A>) -> Q.State<U32>:
  match pair:
    case Outcome{s, x}:
      s

def value(-A: Data, pair: Outcome<A>) -> A:
  match pair:
    case Outcome{s, x}:
      x

def enqueue(d: Nat, x: U32, s: Q.State<U32>) -> Outcome<Nat>:
  outcome(Nat, Q.enqueue(~U32, d, x, s))

def select(now: Nat, s: Q.State<U32>) -> Outcome<Maybe<&2, Q.Ticket<U32>>>:
  outcome(Maybe<&2, Q.Ticket<U32>>, Q.select(~U32, now, s))

def requeue(id: Nat, d: Nat, s: Q.State<U32>) -> Outcome<Bool>:
  outcome(Bool, Q.requeue(~U32, id, d, s))

def complete(id: Nat, s: Q.State<U32>) -> Outcome<Maybe<&2, Q.Ticket<U32>>>:
  outcome(Maybe<&2, Q.Ticket<U32>>, Q.complete(U32, id, s))

def picked(m: Maybe<&2, Q.Ticket<U32>>, +id: Nat, +deadline: Nat, +payload: U32) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{Q.Ticket{i, d, p}}:
      Nat.is_eq(i, id) && Nat.is_eq(d, deadline) && U32.is_eq(p, payload)

def absent(m: Maybe<&2, Q.Ticket<U32>>) -> Bool:
  Maybe.is_none(&2, Q.Ticket<U32>, m)

def selected(pair: Outcome<Maybe<&2, Q.Ticket<U32>>>) -> Q.State<U32>:
  state(Maybe<&2, Q.Ticket<U32>>, pair)

def ticket(pair: Outcome<Maybe<&2, Q.Ticket<U32>>>) -> Maybe<&2, Q.Ticket<U32>>:
  value(Maybe<&2, Q.Ticket<U32>>, pair)

def ordering() -> Bool:
  +e0 = enqueue(10n, 1, Q.new(U32))
  +e1 = enqueue(10n, 2, state(Nat, e0))
  +e2 = enqueue(5n, 3, state(Nat, e1))
  +early = select(4n, state(Nat, e2))
  +first = select(5n, selected(early))
  +second = select(10n, selected(first))
  +third = select(10n, selected(second))
  empty = select(100n, selected(third))
  absent(ticket(early)) && picked(ticket(first), value(Nat, e2), 5n, 3) &&
    picked(ticket(second), value(Nat, e0), 10n, 1) &&
    picked(ticket(third), value(Nat, e1), 10n, 2) && absent(ticket(empty))

def cancellation() -> Bool:
  +e0 = enqueue(30n, 30, Q.new(U32))
  +e1 = enqueue(5n, 5, state(Nat, e0))
  +e2 = enqueue(40n, 40, state(Nat, e1))
  +e3 = enqueue(10n, 10, state(Nat, e2))
  +e4 = enqueue(50n, 50, state(Nat, e3))
  +e5 = enqueue(20n, 20, state(Nat, e4))
  +e6 = enqueue(15n, 15, state(Nat, e5))
  +e7 = enqueue(35n, 35, state(Nat, e6))
  s = Q.cancel(~U32, value(Nat, e2), state(Nat, e7))
  s = Q.cancel(~U32, value(Nat, e1), s)
  s = Q.cancel(~U32, 99n, s)
  +e8 = enqueue(17n, 17, s)
  +a = select(100n, state(Nat, e8))
  +b = select(100n, selected(a))
  +c = select(100n, selected(b))
  +d = select(100n, selected(c))
  +e = select(100n, selected(d))
  +f = select(100n, selected(e))
  +g = select(100n, selected(f))
  empty = select(100n, selected(g))
  Nat.is_eq(value(Nat, e8), 8n) &&
    picked(ticket(a), value(Nat, e3), 10n, 10) &&
    picked(ticket(b), value(Nat, e6), 15n, 15) &&
    picked(ticket(c), value(Nat, e8), 17n, 17) &&
    picked(ticket(d), value(Nat, e5), 20n, 20) &&
    picked(ticket(e), value(Nat, e0), 30n, 30) &&
    picked(ticket(f), value(Nat, e7), 35n, 35) &&
    picked(ticket(g), value(Nat, e4), 50n, 50) && absent(ticket(empty))

def completion() -> Bool:
  +e0 = enqueue(3n, 8, Q.new(U32))
  +id = value(Nat, e0)
  +first = select(3n, state(Nat, e0))
  +again = requeue(id, 6n, selected(first))
  +early = select(5n, state(Bool, again))
  +second = select(6n, selected(early))
  +done = complete(id, selected(second))
  +duplicate = complete(id, selected(done))
  resurrection = requeue(id, 9n, selected(duplicate))
  picked(ticket(first), id, 3n, 8) && value(Bool, again) && absent(ticket(early)) &&
    picked(ticket(second), id, 6n, 8) && picked(ticket(done), id, 6n, 8) &&
    absent(ticket(duplicate)) && Bool.not(value(Bool, resurrection))

def running() -> Bool:
  +e0 = enqueue(10n, 10, Q.new(U32))
  +e1 = enqueue(10n, 11, state(Nat, e0))
  +e2 = enqueue(10n, 12, state(Nat, e1))
  +e3 = enqueue(10n, 13, state(Nat, e2))
  +e4 = enqueue(10n, 14, state(Nat, e3))
  +a = select(10n, state(Nat, e4))
  +b = select(10n, selected(a))
  +c = select(10n, selected(b))
  +d = select(10n, selected(c))
  +e = select(10n, selected(d))
  +done1 = complete(value(Nat, e1), selected(e))
  +again2 = requeue(value(Nat, e2), 20n, selected(done1))
  s = Q.cancel(~U32, value(Nat, e3), state(Bool, again2))
  +cancelled = complete(value(Nat, e3), s)
  +dead = requeue(value(Nat, e3), 20n, selected(cancelled))
  +done0 = complete(value(Nat, e0), state(Bool, dead))
  +e5 = enqueue(20n, 15, selected(done0))
  +again4 = requeue(value(Nat, e4), 20n, state(Nat, e5))
  +first = select(20n, state(Bool, again4))
  +second = select(20n, selected(first))
  +third = select(20n, selected(second))
  +done2 = complete(value(Nat, e2), selected(third))
  +done4 = complete(value(Nat, e4), selected(done2))
  +done5 = complete(value(Nat, e5), selected(done4))
  +e6 = enqueue(30n, 16, selected(done5))
  +last = select(30n, state(Nat, e6))
  +done6 = complete(value(Nat, e6), selected(last))
  empty = select(100n, selected(done6))
  picked(ticket(a), value(Nat, e0), 10n, 10) &&
    picked(ticket(b), value(Nat, e1), 10n, 11) &&
    picked(ticket(c), value(Nat, e2), 10n, 12) &&
    picked(ticket(d), value(Nat, e3), 10n, 13) &&
    picked(ticket(e), value(Nat, e4), 10n, 14) &&
    picked(ticket(done1), value(Nat, e1), 10n, 11) && value(Bool, again2) &&
    absent(ticket(cancelled)) && Bool.not(value(Bool, dead)) &&
    picked(ticket(done0), value(Nat, e0), 10n, 10) &&
    Nat.is_eq(value(Nat, e5), 5n) && value(Bool, again4) &&
    picked(ticket(first), value(Nat, e2), 20n, 12) &&
    picked(ticket(second), value(Nat, e4), 20n, 14) &&
    picked(ticket(third), value(Nat, e5), 20n, 15) &&
    picked(ticket(done2), value(Nat, e2), 20n, 12) &&
    picked(ticket(done4), value(Nat, e4), 20n, 14) &&
    picked(ticket(done5), value(Nat, e5), 20n, 15) &&
    Nat.is_eq(value(Nat, e6), 6n) &&
    picked(ticket(last), value(Nat, e6), 30n, 16) &&
    picked(ticket(done6), value(Nat, e6), 30n, 16) && absent(ticket(empty))

def boundaries() -> Bool:
  +wide = (4294967295n + 1n : Nat)
  +e0 = enqueue(10n, 10, Q.new(U32))
  +e1 = enqueue(20n, 20, state(Nat, e0))
  +e2 = enqueue(wide, 30, state(Nat, e1))
  +first = select(10n, state(Nat, e2))
  +backward = select(5n, selected(first))
  +second = select(20n, selected(backward))
  +early = select(4294967295n, selected(second))
  +third = select(wide, selected(early))
  empty = select(wide, selected(third))
  picked(ticket(first), value(Nat, e0), 10n, 10) && absent(ticket(backward)) &&
    picked(ticket(second), value(Nat, e1), 20n, 20) && absent(ticket(early)) &&
    picked(ticket(third), value(Nat, e2), wide, 30) && absent(ticket(empty))

def same(xs: List<&2, Nat>, ys: List<&2, Nat>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      Nat.is_eq(x, y) && same(xt, yt)
    case _ _:
      False{}

def planned(m: Maybe<&2, R.Plan>, due: List<&2, Nat>, next: Nat) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{R.Planned{ds, d}}:
      same(ds, due) && Nat.is_eq(d, next)

def invalid(m: Maybe<&2, R.Plan>) -> Bool:
  Maybe.is_none(&2, R.Plan, m)

def recurrence() -> Bool:
  planned(R.plan(10n, 35n, 5n, R.FixedDelay{}), Nil{}, 40n) &&
    planned(R.plan(10n, 35n, 5n, R.FixedRate{R.Skip{}}), Nil{}, 40n) &&
    planned(R.plan(10n, 35n, 5n, R.FixedRate{R.CatchUp{2n}}), [15n, 20n], 40n) &&
    planned(R.plan(10n, 35n, 5n, R.FixedRate{R.CatchUp{0n}}), Nil{}, 40n) &&
    planned(R.plan(10n, 10n, 5n, R.FixedRate{R.CatchUp{8n}}), Nil{}, 15n) &&
    planned(R.plan(10n, 0n, 5n, R.FixedRate{R.Skip{}}), Nil{}, 15n) &&
    planned(R.plan(10n, 34n, 5n, R.FixedRate{R.Skip{}}), Nil{}, 35n) &&
    planned(R.plan(10n, 22n, 5n, R.FixedRate{R.CatchUp{8n}}), [15n, 20n], 25n) &&
    invalid(R.plan(10n, 35n, 0n, R.FixedDelay{})) &&
    invalid(R.plan(10n, 35n, 0n, R.FixedRate{R.Skip{}})) &&
    invalid(R.plan(10n, 35n, 0n, R.FixedRate{R.CatchUp{2n}})) &&
    planned(R.plan(4294967295n, 4294967295n, 2n, R.FixedDelay{}), Nil{}, (4294967295n + 2n : Nat))

def main() -> IO(Unit):
  do IO<Unit>:
    require(ordering(), "deadline or FIFO selection failed")
    require(cancellation(), "pending cancellation lost survivors or reused IDs")
    require(completion(), "running token completion/requeue failed")
    require(running(), "running operations lost tokens, reused IDs or changed FIFO order")
    require(boundaries(), "wide deadlines or decreasing supplied time failed")
    require(recurrence(), "recurrence policy or exact arithmetic failed")
    IO.print("scheduler: order, cancellation, running tokens, recurrence and wide deadlines pass")
