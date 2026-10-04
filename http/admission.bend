# Private bounded transport accounting. Replies contain copied data, never resources.
import Base

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

def empty() -> Counts:
  Counts{0, 0, 0, 0, 0, 0, 0n, 0n, 0n}

def acquire.connection(full: Bool, buffer_full: Bool, counts: Counts) -> Counts & Bool:
  match full buffer_full counts:
    case True{} _ Counts{c, a, b, ch, ah, bh, cr, ar, br}:
      (Counts{c, a, b, ch, ah, bh, 1n+cr, ar, br}, False{})
    case False{} True{} Counts{c, a, b, ch, ah, bh, cr, ar, br}:
      (Counts{c, a, b, ch, ah, bh, cr, ar, 1n+br}, False{})
    case False{} False{} Counts{c, a, b, ch, ah, bh, cr, ar, br}:
      +nc = (c + 1 : U32)
      +nb = (b + 1 : U32)
      (Counts{nc, a, nb, U32.max(ch, nc), ah, U32.max(bh, nb), cr, ar, br}, True{})

def acquire.active(full: Bool, counts: Counts) -> Counts & Bool:
  match full counts:
    case True{} Counts{c, a, b, ch, ah, bh, cr, ar, br}:
      (Counts{c, a, b, ch, ah, bh, cr, 1n+ar, br}, False{})
    case False{} Counts{c, a, b, ch, ah, bh, cr, ar, br}:
      +na = (a + 1 : U32)
      (Counts{c, na, b, ch, U32.max(ah, na), bh, cr, ar, br}, True{})

def acquire(kind: U32, caps: Caps, +counts: Counts) -> Counts & Bool:
  match kind:
    case 0:
      Caps{cc, ac, bc} = caps
      Counts{c, a, b, ch, ah, bh, cr, ar, br} = counts
      acquire.connection(U32.is_ge(c, cc), U32.is_ge(b, bc), counts)
    case _:
      Caps{cc, ac, bc} = caps
      Counts{c, a, b, ch, ah, bh, cr, ar, br} = counts
      acquire.active(U32.is_ge(a, ac), counts)

def acquire.running(running: Bool, kind: U32, caps: Caps, counts: Counts) -> Counts & Bool:
  match running:
    case False{}:
      (counts, False{})
    case True{}:
      acquire(kind, caps, counts)

def release(kind: U32, counts: Counts) -> Counts:
  match kind counts:
    case 0 Counts{c, a, b, ch, ah, bh, cr, ar, br}:
      Counts{(c - 1 : U32), a, (b - 1 : U32), ch, ah, bh, cr, ar, br}
    case _ Counts{c, a, b, ch, ah, bh, cr, ar, br}:
      Counts{c, (a - 1 : U32), b, ch, ah, bh, cr, ar, br}

def stopped(closing: Bool, counts: Counts) -> Bool:
  Counts{c, a, b, ch, ah, bh, cr, ar, br} = counts
  closing && U32.is_zero(c) && U32.is_zero(a) && U32.is_zero(b)

type Step is Type:
  Waiting{}
  Received{command: Maybe<&1, Command>}
  Acquired{reply: Chan(Bool), result: Counts & Bool}
  Finishing{done: Bool}

# The private inbox is reusable: IO.join would close it after one receive.
@unsafe
def loop(+inbox: Chan(Command), +caps: Caps, +counts: Counts, +running: Bool, +closing: Bool, step: Step) -> IO(Counts):
  match step:
    case Waiting{}:
      do IO<Counts>:
        got : Maybe<&1, Command> <- Chan.recv(Command, inbox)
        loop(inbox, caps, counts, running, closing, Received{got})
    case Acquired{reply, result}:
      (next, admitted) = result
      do IO<Counts>:
        sent : Bool <- Chan.send(Bool, reply, admitted)
        loop(inbox, caps, next, running, closing, Waiting{})
    case Finishing{done}:
      match done:
        case True{}:
          do IO<Counts>:
            Chan.close(Command, inbox)
            return counts
        case False{}:
          loop(inbox, caps, counts, running, closing, Waiting{})
    case Received{got}:
      match got:
        case None{}:
          IO.pure(Counts, counts)
        case Some{command}:
          match command:
            case Acquire{kind, reply}:
              loop(inbox, caps, counts, running, closing, Acquired{reply, acquire.running(running, kind, caps, counts)})
            case Release{kind, reply}:
              +next = release(kind, counts)
              do IO<Counts>:
                sent : Bool <- Chan.send(Unit, reply, Unit{})
                loop(inbox, caps, next, running, closing, Finishing{stopped(closing, next)})
            case Snapshot{reply}:
              do IO<Counts>:
                sent : Bool <- Chan.send(Counts, reply, counts)
                loop(inbox, caps, counts, running, closing, Waiting{})
            case Quiesce{reply}:
              do IO<Counts>:
                sent : Bool <- Chan.send(Bool, reply, running)
                loop(inbox, caps, counts, False{}, closing, Waiting{})
            case Running{reply}:
              do IO<Counts>:
                sent : Bool <- Chan.send(Bool, reply, running)
                loop(inbox, caps, counts, running, closing, Waiting{})
            case Stop{}:
              loop(inbox, caps, counts, running, True{}, Finishing{stopped(True{}, counts)})

def open(caps: Caps) -> IO(Chan(Command)):
  do IO<Chan(Command)>:
    +inbox : Chan(Command) <- Chan.new(Command, 0)
    IO.spawn(Counts, loop(inbox, caps, empty(), True{}, False{}, Waiting{}))
    return inbox

# The affine server owner joins this actual actor result after closing its listener.
def open.owner(caps: Caps) -> IO(Chan(Command) & Chan(Counts)):
  do IO<Chan(Command) & Chan(Counts)>:
    +inbox : Chan(Command) <- Chan.new(Command, 0)
    finished : Chan(Counts) <- IO.fork(Counts, loop(inbox, caps, empty(), True{}, False{}, Waiting{}))
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
