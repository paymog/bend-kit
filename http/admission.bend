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

# The private inbox is reusable: IO.join would close it after one receive.
@unsafe
def loop(+inbox: Chan(Command), +caps: Caps, +counts: Counts, +closing: Bool, step: Step) -> IO(Unit):
  match step:
    case Waiting{}:
      do IO<Unit>:
        got : Maybe<&1, Command> <- Chan.recv(Command, inbox)
        loop(inbox, caps, counts, closing, Received{got})
    case Acquired{reply, result}:
      (next, admitted) = result
      do IO<Unit>:
        sent : Bool <- Chan.send(Bool, reply, admitted)
        loop(inbox, caps, next, closing, Waiting{})
    case Received{got}:
      match got:
        case None{}:
          IO.pure(Unit, Unit{})
        case Some{command}:
          match command:
            case Acquire{kind, reply}:
              loop(inbox, caps, counts, closing, Acquired{reply, acquire(kind, caps, counts)})
            case Release{kind, reply}:
              +next = release(kind, counts)
              do IO<Unit>:
                sent : Bool <- Chan.send(Unit, reply, Unit{})
                finish(stopped(closing, next), inbox, caps, next, closing)
            case Snapshot{reply}:
              do IO<Unit>:
                sent : Bool <- Chan.send(Counts, reply, counts)
                loop(inbox, caps, counts, closing, Waiting{})
            case Stop{}:
              finish(stopped(True{}, counts), inbox, caps, counts, True{})

@unsafe
def finish(done: Bool, +inbox: Chan(Command), caps: Caps, counts: Counts, closing: Bool) -> IO(Unit):
  match done:
    case True{}:
      Chan.close(Command, inbox)
    case False{}:
      loop(inbox, caps, counts, closing, Waiting{})

def open(caps: Caps) -> IO(Chan(Command)):
  do IO<Chan(Command)>:
    +inbox : Chan(Command) <- Chan.new(Command, 0)
    IO.spawn(Unit, loop(inbox, caps, empty(), False{}, Waiting{}))
    return inbox

def take(+inbox: Chan(Command), kind: U32) -> IO(Bool):
  do IO<Bool>:
    +reply : Chan(Bool) <- Chan.new(Bool, 1)
    sent : Bool <- Chan.send(Command, inbox, Acquire{kind, reply})
    IO.join(Bool, reply)

def give(+inbox: Chan(Command), kind: U32) -> IO(Unit):
  do IO<Unit>:
    +reply : Chan(Unit) <- Chan.new(Unit, 1)
    sent : Bool <- Chan.send(Command, inbox, Release{kind, reply})
    IO.join(Unit, reply)

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

def close(inbox: Chan(Command)) -> IO(Unit):
  do IO<Unit>:
    sent : Bool <- Chan.send(Command, inbox, Stop{})
    return Unit{}
