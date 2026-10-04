# Bounded affine dependency bundles with typed concurrent operations and explicit close.
import Base

type Counts is Data:
  Counts{capacity: Nat, in_use: Nat, completed: Nat, rejected: Nat}

type Outcome<-E: Data, -O: Data> is Data:
  Success{value: O}
  Expected{error: E}
  Exhausted{}
  Stopped{}

type CloseResult is Data:
  Closed{}
  Busy{counts: Counts}

type Message<-R: Type, -P: Data, -I: Data, -E: Data, -O: Data> is Type:
  Submit{principal: P, input: I, reply: Chan(Outcome<E, O>)}
  Returned{resource: R}
  Inspect{reply: Chan(Counts)}
  Shutdown{reply: Chan(CloseResult)}

# Copy only this context, never the resources. The inbox bounds queued commands;
# callers must count blocked submissions inside their transport admission limit.
type Context<-R: Type, -P: Data, -I: Data, -E: Data, -O: Data> is Data:
  Context{messages: Chan(Message<R, P, I, E, O>)}

def outcome.value(-E: Data, -O: Data, result: Result<&2, &2, E, O>) -> Outcome<E, O>:
  match result:
    case Fail{error}:
      Expected{error}
    case Done{value}:
      Success{value}

# The resources return through the private owner protocol BEFORE a disposable
# caller reply. A closed caller reply cannot erase a handle or strand capacity.
def work.return(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data,
  messages: Chan(Message<R, P, I, E, O>), reply: Chan(Outcome<E, O>),
  result: R & Result<&2, &2, E, O>
) -> IO(Unit):
  (returned, outcome) = result
  do IO<Unit>:
    accepted : Bool <- Chan.send(Message<R, P, I, E, O>, messages, Returned{returned})
    sent : Bool <- Chan.send(Outcome<E, O>, reply, outcome.value(E, O, outcome))
    return Unit{}

def work(~R: Type, ~P: Data, ~I: Data, ~E: Data, ~O: Data,
  ~handler: R -> P -> I -> IO(R & Result<&2, &2, E, O>),
  resource: R, principal: P, input: I,
  messages: Chan(Message<R, P, I, E, O>), reply: Chan(Outcome<E, O>)
) -> IO(Unit):
  do IO<Unit>:
    result : R & Result<&2, &2, E, O> <- handler(resource, principal, input)
    work.return(R, P, I, E, O, messages, reply, result)

def dispose(~R: Type, ~destroy: R -> IO(Unit), resources: List<R>) -> IO(Unit):
  match resources:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{resource, rest}:
      do IO<Unit>:
        destroy(resource)
        dispose(~R, ~destroy, rest)

# Closing Base channels retains buffered messages. Drain them and answer stopped
# callers, rather than stranding accepted commands behind the close command.
def drain.message(~R: Type, ~P: Data, ~I: Data, ~E: Data, ~O: Data,
  ~destroy: R -> IO(Unit), message: Message<R, P, I, E, O>
) -> IO(Unit):
  match message:
    case Submit{principal, input, reply}:
      do IO<Unit>:
        sent : Bool <- Chan.send(Outcome<E, O>, reply, Stopped{})
        return Unit{}
    case Inspect{reply}:
      Chan.close(Counts, reply)
    case Shutdown{reply}:
      do IO<Unit>:
        sent : Bool <- Chan.send(CloseResult, reply, Closed{})
        return Unit{}
    case Returned{resource}:
      destroy(resource)

def drain.step(~R: Type, ~P: Data, ~I: Data, ~E: Data, ~O: Data,
  ~destroy: R -> IO(Unit), pending: Maybe<&1, Message<R, P, I, E, O>>,
  next: Unit -> IO(Unit)
) -> IO(Unit):
  match pending:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{message}:
      do IO<Unit>:
        drain.message(~R, ~P, ~I, ~E, ~O, ~destroy, message)
        next(Unit{})

# The closed inbox contains at most room buffered messages.
def drain(~R: Type, ~P: Data, ~I: Data, ~E: Data, ~O: Data,
  ~destroy: R -> IO(Unit), fuel: Nat, +messages: Chan(Message<R, P, I, E, O>)
) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        pending : Maybe<&1, Message<R, P, I, E, O>> <- Chan.recv(Message<R, P, I, E, O>, messages)
        drain.step(~R, ~P, ~I, ~E, ~O, ~destroy, pending, u => drain(~R, ~P, ~I, ~E, ~O, ~destroy, p, messages))

type OwnerStep<-R: Type, -P: Data, -I: Data, -E: Data, -O: Data> is Type:
  Waiting{resources: List<R>, counts: Counts}
  Received{message: Message<R, P, I, E, O>, counts: Counts, resources: List<R>}

# IO.join closes a one-shot channel; the owner inbox must remain reusable.
def receive.value(-A: Type, value: Maybe<&1, A>) -> IO(A):
  match value:
    case None{}:
      IO.die(A, 1, "camber internal channel closed unexpectedly")
    case Some{message}:
      IO.pure(A, message)

def receive(-A: Type, channel: Chan(A)) -> IO(A):
  do IO<A>:
    value : Maybe<&1, A> <- Chan.recv(A, channel)
    receive.value(A, value)

# Only idle close ends this loop. Busy close never waits on a stalled handler.
# @unsafe is solely the lifecycle receive loop, not a termination/proof claim.
@unsafe def owner(~R: Type, ~P: Data, ~I: Data, ~E: Data, ~O: Data,
  ~handler: R -> P -> I -> IO(R & Result<&2, &2, E, O>), ~destroy: R -> IO(Unit),
  +messages: Chan(Message<R, P, I, E, O>), +room: U32, step: OwnerStep<R, P, I, E, O>
) -> IO(Unit):
  match step:
    case Waiting{resources, counts}:
      do IO<Unit>:
        message : Message<R, P, I, E, O> <- receive(Message<R, P, I, E, O>, messages)
        owner(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, messages, room, Received{message, counts, resources})
    case Received{message, counts, resources}:
      match message:
        case Returned{resource}:
          Counts{capacity, in_use, completed, rejected} = counts
          owner(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, messages, room, Waiting{resource <> resources, Counts{capacity, Nat.sub(in_use, 1n), 1n+completed, rejected}})
        case Inspect{reply}:
          Counts{+capacity, +in_use, +completed, +rejected} = counts
          do IO<Unit>:
            sent : Bool <- Chan.send(Counts, reply, Counts{capacity, in_use, completed, rejected})
            owner(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, messages, room, Waiting{resources, Counts{capacity, in_use, completed, rejected}})
        case Shutdown{reply}:
          Counts{+capacity, in_use, +completed, +rejected} = counts
          match in_use:
            case 0n:
              do IO<Unit>:
                dispose(~R, ~destroy, resources)
                Chan.close(Message<R, P, I, E, O>, messages)
                sent : Bool <- Chan.send(CloseResult, reply, Closed{})
                drain(~R, ~P, ~I, ~E, ~O, ~destroy, U32.to_nat(room), messages)
            case 1n+ +p:
              do IO<Unit>:
                sent : Bool <- Chan.send(CloseResult, reply, Busy{Counts{capacity, 1n+p, completed, rejected}})
                owner(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, messages, room, Waiting{resources, Counts{capacity, 1n+p, completed, rejected}})
        case Submit{principal, input, reply}:
          Counts{capacity, in_use, completed, rejected} = counts
          match resources:
            case Nil{}:
              do IO<Unit>:
                sent : Bool <- Chan.send(Outcome<E, O>, reply, Exhausted{})
                owner(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, messages, room, Waiting{Nil{}, Counts{capacity, in_use, completed, 1n+rejected}})
            case Con{resource, rest}:
              do IO<Unit>:
                IO.spawn(Unit, work(~R, ~P, ~I, ~E, ~O, ~handler, resource, principal, input, messages, reply))
                owner(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, messages, room, Waiting{rest, Counts{capacity, 1n+in_use, completed, rejected}})

def build.step(~R: Type, ~E: Data, ~destroy: R -> IO(Unit),
  result: Result<&2, &1, E, R>, resources: List<R>,
  next: List<R> -> IO(Result<&2, &1, E, List<R>>)
) -> IO(Result<&2, &1, E, List<R>>):
  match result:
    case Fail{error}:
      do IO<Result<&2, &1, E, List<R>>>:
        dispose(~R, ~destroy, resources)
        return Fail{error}
    case Done{resource}:
      next(resource <> resources)

def build(~K: Data, ~R: Type, ~E: Data, ~create: K -> Nat -> IO(Result<&2, &1, E, R>), ~destroy: R -> IO(Unit),
  remaining: Nat, +config: K, resources: List<R>
) -> IO(Result<&2, &1, E, List<R>>):
  match remaining:
    case 0n:
      IO.pure(Result<&2, &1, E, List<R>>, Done{resources})
    case 1n+ +p:
      do IO<Result<&2, &1, E, List<R>>>:
        result : Result<&2, &1, E, R> <- create(config, p)
        build.step(~R, ~E, ~destroy, result, resources, next => build(~K, ~R, ~E, ~create, ~destroy, p, config, next))

def start.ready(~R: Type, ~P: Data, ~I: Data, ~E: Data, ~O: Data,
  ~handler: R -> P -> I -> IO(R & Result<&2, &2, E, O>), ~destroy: R -> IO(Unit),
  capacity: Nat, +room: U32, result: Result<&2, &1, E, List<R>>
) -> IO(Result<&2, &2, E, Context<R, P, I, E, O>>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2, &2, E, Context<R, P, I, E, O>>, Fail{error})
    case Done{resources}:
      do IO<Result<&2, &2, E, Context<R, P, I, E, O>>>:
        channel : Chan(Message<R, P, I, E, O>) <- Chan.new(Message<R, P, I, E, O>, room)
        +messages : Chan(Message<R, P, I, E, O>) = channel
        IO.spawn(Unit, owner(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, messages, room, Waiting{resources, Counts{capacity, 0n, 0n, 0n}}))
        return Done{Context{messages}}

# The initializer closes partial handles within a failed bundle; start closes
# all prior whole bundles. No workers exist until the complete set opens.
def start(~K: Data, ~R: Type, ~P: Data, ~I: Data, ~E: Data, ~O: Data,
  ~create: K -> Nat -> IO(Result<&2, &1, E, R>),
  ~handler: R -> P -> I -> IO(R & Result<&2, &2, E, O>), ~destroy: R -> IO(Unit),
  config: K, +capacity: Nat, room: U32
) -> IO(Result<&2, &2, E, Context<R, P, I, E, O>>):
  do IO<Result<&2, &2, E, Context<R, P, I, E, O>>>:
    result : Result<&2, &1, E, List<R>> <- build(~K, ~R, ~E, ~create, ~destroy, capacity, config, Nil{})
    start.ready(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, capacity, room, result)

def submit(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data,
  context: Context<R, P, I, E, O>, principal: P, input: I, reply: Chan(Outcome<E, O>)
) -> IO(Bool):
  Context{messages} = context
  Chan.send(Message<R, P, I, E, O>, messages, Submit{principal, input, reply})

def call.accepted(-E: Data, -O: Data, accepted: Bool, +reply: Chan(Outcome<E, O>)) -> IO(Outcome<E, O>):
  match accepted:
    case False{}:
      do IO<Outcome<E, O>>:
        Chan.close(Outcome<E, O>, reply)
        return Stopped{}
    case True{}:
      do IO<Outcome<E, O>>:
        result : Outcome<E, O> <- IO.join(Outcome<E, O>, reply)
        Chan.close(Outcome<E, O>, reply)
        return result

def call(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data,
  context: Context<R, P, I, E, O>, principal: P, input: I
) -> IO(Outcome<E, O>):
  do IO<Outcome<E, O>>:
    channel : Chan(Outcome<E, O>) <- Chan.new(Outcome<E, O>, 1)
    +reply : Chan(Outcome<E, O>) = channel
    accepted : Bool <- submit(R, P, I, E, O, context, principal, input, reply)
    call.accepted(E, O, accepted, reply)

def inspect.value(value: Maybe<&1, Counts>) -> Maybe<&2, Counts>:
  match value:
    case None{}:
      None{}
    case Some{counts}:
      Some{counts}

def inspect.sent(sent: Bool, +reply: Chan(Counts)) -> IO(Maybe<&2, Counts>):
  match sent:
    case False{}:
      do IO<Maybe<&2, Counts>>:
        Chan.close(Counts, reply)
        return None{}
    case True{}:
      do IO<Maybe<&2, Counts>>:
        value : Maybe<&1, Counts> <- Chan.recv(Counts, reply)
        Chan.close(Counts, reply)
        return inspect.value(value)

def inspect(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data, context: Context<R, P, I, E, O>) -> IO(Maybe<&2, Counts>):
  Context{messages} = context
  do IO<Maybe<&2, Counts>>:
    channel : Chan(Counts) <- Chan.new(Counts, 1)
    +reply : Chan(Counts) = channel
    sent : Bool <- Chan.send(Message<R, P, I, E, O>, messages, Inspect{reply})
    inspect.sent(sent, reply)

def close.sent(sent: Bool, +reply: Chan(CloseResult)) -> IO(CloseResult):
  match sent:
    case False{}:
      do IO<CloseResult>:
        Chan.close(CloseResult, reply)
        return Closed{}
    case True{}:
      do IO<CloseResult>:
        value : CloseResult <- IO.join(CloseResult, reply)
        Chan.close(CloseResult, reply)
        return value

# Stop external admissions before close. Busy preserves live context/capacity;
# retry after admitted operations finish. Stalled operations remain observable.
def close(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data, context: Context<R, P, I, E, O>) -> IO(CloseResult):
  Context{messages} = context
  do IO<CloseResult>:
    channel : Chan(CloseResult) <- Chan.new(CloseResult, 1)
    +reply : Chan(CloseResult) = channel
    sent : Bool <- Chan.send(Message<R, P, I, E, O>, messages, Shutdown{reply})
    close.sent(sent, reply)
