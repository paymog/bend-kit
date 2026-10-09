# Private bounded transport accounting. Replies contain copied data, never resources.
import Base
import ../resources/resources.bend as Res

type Counts is Data:
  Counts{connections: U32, active: U32, buffered: U32,
    connection_high: U32, active_high: U32, buffered_high: U32,
    connection_rejected: Nat, active_rejected: Nat, buffered_rejected: Nat}

type Caps is Data:
  Caps{connections: U32, active: U32, buffered: U32}

type Command is Data:
  Acquire{kind: U32, reply: Chan(Bool)}
  Release{kind: U32, reply: Chan(Unit)}
  Snapshot{reply: Chan(Counts)}
  Quiesce{reply: Chan(Bool)}
  Running{reply: Chan(Bool)}
  Stop{}

# One transport resource: its pool, and every lease taken from it joined in one grant.
type Lease is Type:
  Lease{pool: Res.Pool, held: Res.Grant}

type Marks is Data:
  Marks{connection_high: U32, active_high: U32, buffered_high: U32,
    connection_rejected: Nat, active_rejected: Nat, buffered_rejected: Nat}

type Ledger is Type:
  Ledger{connections: Lease, active: Lease, buffered: Lease, marks: Marks}

# Broken means a lease count is wrong, such as a give with no matching take.
type Booked is Type:
  Booked{ledger: Ledger, admitted: Bool}
  Broken{}

type Taken is Type:
  Admitted{lease: Lease}
  Full{lease: Lease}
  Lost{}

def lease.open(+owner: Nat, capacity: U32) -> Lease:
  Lease{Res.new(owner, U32.to_nat(capacity)), Res.Grant{owner, 0n}}

def ledger.open(caps: Caps) -> Ledger:
  Caps{cc, ac, bc} = caps
  Ledger{lease.open(0n, cc), lease.open(1n, ac), lease.open(2n, bc), Marks{0, 0, 0, 0n, 0n, 0n}}

def lease.joined(combined: Res.Combine, pool: Res.Pool) -> Taken:
  match combined:
    case Res.Joined{grant}:
      Admitted{Lease{pool, grant}}
    case Res.Apart{first, second}:
      Lost{}

def lease.took(reserved: Res.Reserve, held: Res.Grant) -> Taken:
  match reserved:
    case Res.Took{pool, grant}:
      lease.joined(Res.combine(held, grant), pool)
    case Res.Refused{pool}:
      Full{Lease{pool, held}}

def lease.take(lease: Lease) -> Taken:
  Lease{pool, held} = lease
  lease.took(Res.reserve(pool, 1n), held)

def lease.released(released: Res.Release, rest: Res.Grant) -> Maybe<&1, Lease>:
  match released:
    case Res.Released{pool}:
      Some{Lease{pool, rest}}
    case Res.Kept{pool, grant}:
      None{}

def lease.split(parts: Res.Split, pool: Res.Pool) -> Maybe<&1, Lease>:
  match parts:
    case Res.Parts{one, rest}:
      lease.released(Res.release(pool, one), rest)
    case Res.Whole{grant}:
      None{}

def lease.give(lease: Lease) -> Maybe<&1, Lease>:
  Lease{pool, held} = lease
  lease.split(Res.split(held, 1n), pool)

def count(+pool: Res.Pool) -> U32:
  U32.from_nat(Res.reserved(pool))

def counts(ledger: Ledger) -> Counts & Ledger:
  Ledger{Lease{+cp, cg}, Lease{+ap, ag}, Lease{+bp, bg}, +marks} = ledger
  Marks{ch, ah, bh, cr, ar, br} = marks
  (Counts{count(cp), count(ap), count(bp), ch, ah, bh, cr, ar, br}, Ledger{Lease{cp, cg}, Lease{ap, ag}, Lease{bp, bg}, marks})

def final(ledger: Ledger) -> Counts:
  Pair.fst(Counts, Ledger, counts(ledger))

# Raises each high-water mark to its current count.
def marked(ledger: Ledger) -> Ledger:
  Ledger{Lease{+cp, cg}, Lease{+ap, ag}, Lease{+bp, bg}, marks} = ledger
  Marks{ch, ah, bh, cr, ar, br} = marks
  Ledger{Lease{cp, cg}, Lease{ap, ag}, Lease{bp, bg},
    Marks{U32.max(ch, count(cp)), U32.max(ah, count(ap)), U32.max(bh, count(bp)), cr, ar, br}}

def refused(kind: U32, marks: Marks) -> Marks:
  match kind marks:
    case 0 Marks{ch, ah, bh, cr, ar, br}:
      Marks{ch, ah, bh, 1n+cr, ar, br}
    case 1 Marks{ch, ah, bh, cr, ar, br}:
      Marks{ch, ah, bh, cr, 1n+ar, br}
    case _ Marks{ch, ah, bh, cr, ar, br}:
      Marks{ch, ah, bh, cr, ar, 1n+br}

# A refused buffer returns the connection lease it already took.
def acquire.rollback(connections: Maybe<&1, Lease>, active: Lease, buffered: Lease, marks: Marks) -> Booked:
  match connections:
    case None{}:
      Broken{}
    case Some{lease}:
      Booked{Ledger{lease, active, buffered, refused(2, marks)}, False{}}

def acquire.buffered(taken: Taken, connections: Lease, active: Lease, marks: Marks) -> Booked:
  match taken:
    case Admitted{buffered}:
      Booked{marked(Ledger{connections, active, buffered, marks}), True{}}
    case Full{buffered}:
      acquire.rollback(lease.give(connections), active, buffered, marks)
    case Lost{}:
      Broken{}

# A connection holds one connection unit and one buffer unit, taken together.
def acquire.connection(taken: Taken, active: Lease, buffered: Lease, marks: Marks) -> Booked:
  match taken:
    case Admitted{connections}:
      acquire.buffered(lease.take(buffered), connections, active, marks)
    case Full{connections}:
      Booked{Ledger{connections, active, buffered, refused(0, marks)}, False{}}
    case Lost{}:
      Broken{}

def acquire.active(taken: Taken, connections: Lease, buffered: Lease, marks: Marks) -> Booked:
  match taken:
    case Admitted{active}:
      Booked{marked(Ledger{connections, active, buffered, marks}), True{}}
    case Full{active}:
      Booked{Ledger{connections, active, buffered, refused(1, marks)}, False{}}
    case Lost{}:
      Broken{}

def acquire(kind: U32, ledger: Ledger) -> Booked:
  match kind:
    case 0:
      Ledger{connections, active, buffered, marks} = ledger
      acquire.connection(lease.take(connections), active, buffered, marks)
    case _:
      Ledger{connections, active, buffered, marks} = ledger
      acquire.active(lease.take(active), connections, buffered, marks)

def acquire.running(running: Bool, kind: U32, ledger: Ledger) -> Booked:
  match running:
    case False{}:
      Booked{ledger, False{}}
    case True{}:
      acquire(kind, ledger)

def release.connection(connections: Maybe<&1, Lease>, buffered: Maybe<&1, Lease>, active: Lease, marks: Marks) -> Booked:
  match connections buffered:
    case Some{c} Some{b}:
      Booked{Ledger{c, active, b, marks}, True{}}
    case _ _:
      Broken{}

def release.active(active: Maybe<&1, Lease>, connections: Lease, buffered: Lease, marks: Marks) -> Booked:
  match active:
    case Some{a}:
      Booked{Ledger{connections, a, buffered, marks}, True{}}
    case None{}:
      Broken{}

def release(kind: U32, ledger: Ledger) -> Booked:
  match kind:
    case 0:
      Ledger{connections, active, buffered, marks} = ledger
      release.connection(lease.give(connections), lease.give(buffered), active, marks)
    case _:
      Ledger{connections, active, buffered, marks} = ledger
      release.active(lease.give(active), connections, buffered, marks)

def stopped(closing: Bool, counts: Counts) -> Bool:
  Counts{c, a, b, ch, ah, bh, cr, ar, br} = counts
  closing && U32.is_zero(c) && U32.is_zero(a) && U32.is_zero(b)

def idle(closing: Bool, counted: Counts & Ledger) -> Bool & Ledger:
  (counts, ledger) = counted
  (stopped(closing, counts), ledger)

type Step is Type:
  Waiting{ledger: Ledger}
  Received{ledger: Ledger, command: Maybe<&1, Command>}
  Acquired{reply: Chan(Bool), booked: Booked}
  Released{reply: Chan(Unit), booked: Booked}
  Counted{reply: Chan(Counts), counted: Counts & Ledger}
  Finishing{checked: Bool & Ledger}

# The private inbox is reusable: IO.join would close it after one receive.
@unsafe
def loop(+inbox: Chan(Command), +running: Bool, +closing: Bool, step: Step) -> IO(Counts):
  match step:
    case Waiting{ledger}:
      do IO<Counts>:
        got : Maybe<&1, Command> <- Chan.recv(Command, inbox)
        loop(inbox, running, closing, Received{ledger, got})
    case Acquired{reply, booked}:
      match booked:
        case Broken{}:
          IO.die(Counts, 1, "Admission: a lease count broke")
        case Booked{ledger, admitted}:
          do IO<Counts>:
            sent : Bool <- Chan.send(Bool, reply, admitted)
            loop(inbox, running, closing, Waiting{ledger})
    case Released{reply, booked}:
      match booked:
        case Broken{}:
          IO.die(Counts, 1, "Admission.give: no lease of this kind is held")
        case Booked{ledger, admitted}:
          do IO<Counts>:
            sent : Bool <- Chan.send(Unit, reply, Unit{})
            loop(inbox, running, closing, Finishing{idle(closing, counts(ledger))})
    case Counted{reply, counted}:
      (snapshot, ledger) = counted
      do IO<Counts>:
        sent : Bool <- Chan.send(Counts, reply, snapshot)
        loop(inbox, running, closing, Waiting{ledger})
    case Finishing{checked}:
      (done, ledger) = checked
      match done:
        case True{}:
          do IO<Counts>:
            Chan.close(Command, inbox)
            return final(ledger)
        case False{}:
          loop(inbox, running, closing, Waiting{ledger})
    case Received{ledger, got}:
      match got:
        case None{}:
          IO.pure(Counts, final(ledger))
        case Some{command}:
          match command:
            case Acquire{kind, reply}:
              loop(inbox, running, closing, Acquired{reply, acquire.running(running, kind, ledger)})
            case Release{kind, reply}:
              loop(inbox, running, closing, Released{reply, release(kind, ledger)})
            case Snapshot{reply}:
              loop(inbox, running, closing, Counted{reply, counts(ledger)})
            case Quiesce{reply}:
              do IO<Counts>:
                sent : Bool <- Chan.send(Bool, reply, running)
                loop(inbox, False{}, closing, Waiting{ledger})
            case Running{reply}:
              do IO<Counts>:
                sent : Bool <- Chan.send(Bool, reply, running)
                loop(inbox, running, closing, Waiting{ledger})
            case Stop{}:
              loop(inbox, running, True{}, Finishing{idle(True{}, counts(ledger))})

def open(caps: Caps) -> IO(Chan(Command)):
  do IO<Chan(Command)>:
    +inbox : Chan(Command) <- Chan.new(Command, 0)
    IO.spawn(Counts, loop(inbox, True{}, False{}, Waiting{ledger.open(caps)}))
    return inbox

# The affine server owner joins this actual actor result after closing its listener.
def open.owner(caps: Caps) -> IO(Chan(Command) & Chan(Counts)):
  do IO<Chan(Command) & Chan(Counts)>:
    +inbox : Chan(Command) <- Chan.new(Command, 0)
    finished : Chan(Counts) <- IO.fork(Counts, loop(inbox, True{}, False{}, Waiting{ledger.open(caps)}))
    return (inbox, finished)

def boolean.sent(sent: Bool, +reply: Chan(Bool)) -> IO(Bool):
  match sent:
    case False{}:
      do IO<Bool>:
        Chan.close(Bool, reply)
        return False{}
    case True{}:
      IO.join(Bool, reply)

# False also covers copied controls used after actual controller closure.
def quiesce(+inbox: Chan(Command)) -> IO(Bool):
  do IO<Bool>:
    +reply : Chan(Bool) <- Chan.new(Bool, 1)
    sent : Bool <- Chan.send(Command, inbox, Quiesce{reply})
    boolean.sent(sent, reply)

def running(+inbox: Chan(Command)) -> IO(Bool):
  do IO<Bool>:
    +reply : Chan(Bool) <- Chan.new(Bool, 1)
    sent : Bool <- Chan.send(Command, inbox, Running{reply})
    boolean.sent(sent, reply)

def take(+inbox: Chan(Command), kind: U32) -> IO(Bool):
  do IO<Bool>:
    +reply : Chan(Bool) <- Chan.new(Bool, 1)
    sent : Bool <- Chan.send(Command, inbox, Acquire{kind, reply})
    boolean.sent(sent, reply)

# Correct owners cannot retire the actor while a lease remains counted. If an
# internal channel is externally closed, report the violation instead of joining
# an unanswered reply or pretending a retained operation drained.
def give.sent(sent: Bool, +reply: Chan(Unit)) -> IO(Unit):
  match sent:
    case False{}:
      do IO<Unit>:
        Chan.close(Unit, reply)
        IO.die(Unit, 1, "Admission.give: controller closed while lease retained")
    case True{}:
      IO.join(Unit, reply)

def give(+inbox: Chan(Command), kind: U32) -> IO(Unit):
  do IO<Unit>:
    +reply : Chan(Unit) <- Chan.new(Unit, 1)
    sent : Bool <- Chan.send(Command, inbox, Release{kind, reply})
    give.sent(sent, reply)

def snapshot.sent(sent: Bool, +reply: Chan(Counts)) -> IO(Maybe<&2, Counts>):
  match sent:
    case False{}:
      do IO<Maybe<&2, Counts>>:
        Chan.close(Counts, reply)
        return None{}
    case True{}:
      do IO<Maybe<&2, Counts>>:
        counts : Counts <- IO.join(Counts, reply)
        return Some{counts}

# A successful rendezvous send was received: Stop cannot erase a queued request.
# After controller closure a failed send returns None without waiting on its reply.
def snapshot(+inbox: Chan(Command)) -> IO(Maybe<&2, Counts>):
  do IO<Maybe<&2, Counts>>:
    +reply : Chan(Counts) <- Chan.new(Counts, 1)
    sent : Bool <- Chan.send(Command, inbox, Snapshot{reply})
    snapshot.sent(sent, reply)

# Retire accounting after listener closure; quiesce is the separate admission
# cutover. Finite internal fixtures may finish their already-accepted protocol.
def close(inbox: Chan(Command)) -> IO(Unit):
  do IO<Unit>:
    sent : Bool <- Chan.send(Command, inbox, Stop{})
    return Unit{}
