# Fixed prepared HTTP applications and bounded affine dependency bundles.
import Base
import bend-kit-http@0.30.0.0/http.bend as Http
import bend-kit-router@0.2.0.0/router.bend as Router
import bend-kit-router@0.2.0.0/target.bend as Target
import bend-kit-json@0.5.1.0/json.bend as Json
import ./response.bend as Response
import ./input.bend as Input
import bend-kit-http@0.30.0.0/completion.bend as TransportCompletion
import ./notices.bend as Notices
import bend-kit-time@0.1.0.0/time.bend as Time

type ResponseError is Data:
  InvalidResponse{}
  InvalidRedirect{}

def validate.checked(valid: Bool, response: Http.Res) -> Result<&2, &1, ResponseError, Http.Res>:
  match valid:
    case True{}:
      Done{response}
    case False{}:
      Fail{InvalidResponse{}}

def validate(response: Http.Res) -> Result<&2, &1, ResponseError, Http.Res>:
  Http.Res{+status, +headers, body} = response
  validate.checked(Response.valid(status, headers), Http.Res{status, headers, body})

# The encoder is an explicit public projection, never record reflection.
def json(~T: Type, ~encode: T -> Json.Val, status: U32, value: T) -> Http.Res:
  Http.Res{status, Http.set(Http.empty(), "content-type", "application/json"), Json.encode.bytes(encode(value))}

def text(status: U32, value: String) -> Http.Res:
  Http.Res{status, Http.set(Http.empty(), "content-type", "text/plain; charset=utf-8"), Json.utf8(value)}

def raw(status: U32, body: Http.Body) -> Http.Res:
  Http.Res{status, Http.empty(), body}

def empty(status: U32) -> Http.Res:
  raw(status, Http.from_string(""))

def redirect.checked(valid: Bool, status: U32, location: String) -> Result<&2, &1, ResponseError, Http.Res>:
  match valid:
    case False{}:
      Fail{InvalidRedirect{}}
    case True{}:
      Done{Http.Res{status, Http.set(Http.empty(), "location", location), Http.from_string("")}}

def redirect(+status: U32, +location: String) -> Result<&2, &1, ResponseError, Http.Res>:
  redirect.checked((U32.is_eq(status, 301) || U32.is_eq(status, 302) || U32.is_eq(status, 303) || U32.is_eq(status, 307) || U32.is_eq(status, 308)) && Bool.not(String.eq(location, "")) && Response.value(location), status, location)

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

# The completion future has one affine owner; request contexts copy only inbox.
type Owner<-R: Type, -P: Data, -I: Data, -E: Data, -O: Data> is Type:
  Owner{context: Context<R, P, I, E, O>, finished: Chan(Unit)}

type OwnerClose<-R: Type, -P: Data, -I: Data, -E: Data, -O: Data> is Type:
  OwnerClosed{}
  OwnerBusy{owner: Owner<R, P, I, E, O>, counts: Counts}

def owner.context(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data,
  owner: Owner<R, P, I, E, O>
) -> Owner<R, P, I, E, O> & Context<R, P, I, E, O>:
  Owner{+context, finished} = owner
  (Owner{context, finished}, context)

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
) -> IO(Result<&2, &1, E, Owner<R, P, I, E, O>>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2, &1, E, Owner<R, P, I, E, O>>, Fail{error})
    case Done{resources}:
      do IO<Result<&2, &1, E, Owner<R, P, I, E, O>>>:
        channel : Chan(Message<R, P, I, E, O>) <- Chan.new(Message<R, P, I, E, O>, room)
        +messages : Chan(Message<R, P, I, E, O>) = channel
        finished : Chan(Unit) <- IO.fork(Unit, owner(~R, ~P, ~I, ~E, ~O, ~handler, ~destroy, messages, room, Waiting{resources, Counts{capacity, 0n, 0n, 0n}}))
        return Done{Owner{Context{messages}, finished}}

# The initializer closes partial handles within a failed bundle; start closes
# all prior whole bundles. No workers exist until the complete set opens.
def start(~K: Data, ~R: Type, ~P: Data, ~I: Data, ~E: Data, ~O: Data,
  ~create: K -> Nat -> IO(Result<&2, &1, E, R>),
  ~handler: R -> P -> I -> IO(R & Result<&2, &2, E, O>), ~destroy: R -> IO(Unit),
  config: K, +capacity: Nat, room: U32
) -> IO(Result<&2, &1, E, Owner<R, P, I, E, O>>):
  do IO<Result<&2, &1, E, Owner<R, P, I, E, O>>>:
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

def close.join(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data,
  owner: Owner<R, P, I, E, O>
) -> IO(OwnerClose<R, P, I, E, O>):
  Owner{context, finished} = owner
  do IO<OwnerClose<R, P, I, E, O>>:
    IO.join(Unit, finished)
    return OwnerClosed{}

def close.completed(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data,
  result: CloseResult, owner: Owner<R, P, I, E, O>
) -> IO(OwnerClose<R, P, I, E, O>):
  match result:
    case Closed{}:
      close.join(R, P, I, E, O, owner)
    case Busy{counts}:
      IO.pure(OwnerClose<R, P, I, E, O>, OwnerBusy{owner, counts})

# Stop external admissions before close. Busy preserves live context/capacity;
# retry after admitted operations finish. Stalled operations remain observable.
def close(-R: Type, -P: Data, -I: Data, -E: Data, -O: Data, owner: Owner<R, P, I, E, O>) -> IO(OwnerClose<R, P, I, E, O>):
  Owner{Context{+messages}, finished} = owner
  do IO<OwnerClose<R, P, I, E, O>>:
    channel : Chan(CloseResult) <- Chan.new(CloseResult, 1)
    +reply : Chan(CloseResult) = channel
    sent : Bool <- Chan.send(Message<R, P, I, E, O>, messages, Shutdown{reply})
    result : CloseResult <- close.sent(sent, reply)
    close.completed(R, P, I, E, O, result, Owner{Context{messages}, finished})

# Policies are prepared Data, not callbacks. Later lifecycle stages can consume
# these root-to-route declarations without splitting patterns or finding groups.
type Group<-P: Data> is Data:
  Group{id: U32, ancestors: List<&2, U32>, policy: P}

type GroupPlan<-P: Data> is Data:
  GroupPlan{ids: List<&2, U32>, policies: List<&2, P>}

type Route<-A: Data, -P: Data> is Data:
  Route{method: String, pattern: String, action: A, groups: List<&2, U32>, policy: P}

type Endpoint<-A: Data, -P: Data> is Data:
  Endpoint{action: A, policies: List<&2, P>}

type Application<-A: Data, -C: Data, -P: Data> is Data:
  Application{table: Router.Table<Endpoint<A, P>>, context: C, root: P, groups: List<&2, GroupPlan<P>>}

type RegistrationError is Data:
  RouteError{error: Router.Error}
  InvalidGroups{groups: List<&2, U32>}

type Match<-P: Data> is Data:
  Match{target: Target.Target, params: Map<&2, String>, groups: List<&2, U32>, method: String, pattern: String, policies: List<&2, P>}

def groups.equal(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case x <> xt y <> yt:
      U32.is_eq(x, y) && groups.equal(xt, yt)
    case _ _:
      False{}

def group.pick(~P: Data, same: Bool, group: Group<P>, later: Unit -> Maybe<&2, Group<P>>) -> Maybe<&2, Group<P>>:
  match same:
    case True{}:
      Some{group}
    case False{}:
      later(Unit{})

def group.find(~P: Data, groups: List<&2, Group<P>>, +id: U32) -> Maybe<&2, Group<P>>:
  match groups:
    case Nil{}:
      None{}
    case Group{+here, ancestors, policy} <> rest:
      group.pick(~P, U32.is_eq(here, id), Group{here, ancestors, policy}, u => group.find(~P, rest, id))

def group.checked(~P: Data, same: Bool, policy: P) -> Maybe<&2, P>:
  match same:
    case False{}:
      None{}
    case True{}:
      Some{policy}

def group.policy(~P: Data, found: Maybe<&2, Group<P>>, ancestors: List<&2, U32>) -> Maybe<&2, P>:
  match found:
    case None{}:
      None{}
    case Some{Group{id, expected, policy}}:
      group.checked(~P, groups.equal(expected, ancestors), policy)

def groups.policies(~P: Data, ids: List<&2, U32>, +declared: List<&2, Group<P>>, +ancestors: List<&2, U32>) -> Maybe<&2, List<&2, P>>:
  match ids:
    case Nil{}:
      Some{Nil{}}
    case +id <> rest:
      do Maybe<&2, List<&2, P>>:
        policy : P <- group.policy(~P, group.find(~P, declared, id), ancestors)
        policies : List<&2, P> <- groups.policies(~P, rest, declared, List.append(&2, U32, ancestors, [id]))
        return policy <> policies

def groups.unique(~P: Data, found: Maybe<&2, Group<P>>) -> Bool:
  match found:
    case None{}:
      True{}
    case Some{group}:
      False{}

def groups.valid(~P: Data, groups: List<&2, Group<P>>, +all: List<&2, Group<P>>) -> Bool:
  match groups:
    case Nil{}:
      True{}
    case Group{+id, +ancestors, policy} <> +rest:
      chain = groups.policies(~P, List.append(&2, U32, ancestors, [id]), all, Nil{})
      groups.unique(~P, group.find(~P, rest, id)) && Maybe.is_some(&2, List<&2, P>, chain) && groups.valid(~P, rest, all)

def routes.policies(~P: Data, result: Maybe<&2, List<&2, P>>, ids: List<&2, U32>) -> Result<&2, &2, RegistrationError, List<&2, P>>:
  match result:
    case None{}:
      Fail{InvalidGroups{ids}}
    case Some{policies}:
      Done{policies}

def routes.prepare(~A: Data, ~P: Data, routes: List<&2, Route<A, P>>, +groups: List<&2, Group<P>>, +root: P) -> Result<&2, &2, RegistrationError, List<&2, Router.Entry<Endpoint<A, P>>>>:
  match routes:
    case Nil{}:
      Done{Nil{}}
    case Route{method, pattern, action, +ids, policy} <> rest:
      do Result<&2, &2, RegistrationError, List<&2, Router.Entry<Endpoint<A, P>>>>:
        policies : List<&2, P> <- routes.policies(~P, groups.policies(~P, ids, groups, Nil{}), ids)
        entries : List<&2, Router.Entry<Endpoint<A, P>>> <- routes.prepare(~A, ~P, rest, groups, root)
        return Router.Entry{method, pattern, Endpoint{action, root <> List.append(&2, P, policies, [policy])}, ids} <> entries

def groups.prepare(~P: Data, groups: List<&2, Group<P>>, +all: List<&2, Group<P>>) -> Result<&2, &2, RegistrationError, List<&2, GroupPlan<P>>>:
  match groups:
    case Nil{}:
      Done{Nil{}}
    case Group{id, ancestors, policy} <> rest:
      +ids = List.append(&2, U32, ancestors, [id])
      do Result<&2, &2, RegistrationError, List<&2, GroupPlan<P>>>:
        policies : List<&2, P> <- routes.policies(~P, groups.policies(~P, ids, all, Nil{}), ids)
        plans : List<&2, GroupPlan<P>> <- groups.prepare(~P, rest, all)
        return GroupPlan{ids, policies} <> plans

def groups.select(~P: Data, same: Bool, policies: List<&2, P>, later: Unit -> List<&2, P>) -> List<&2, P>:
  match same:
    case True{}: policies
    case False{}: later(Unit{})

def groups.prepared(~P: Data, plans: List<&2, GroupPlan<P>>, +ids: List<&2, U32>) -> List<&2, P>:
  match plans:
    case Nil{}:
      Nil{}
    case GroupPlan{here, policies} <> rest:
      groups.select(~P, groups.equal(here, ids), policies, u => groups.prepared(~P, rest, ids))

def application.table(~A: Data, ~C: Data, ~P: Data, result: Result<&2, &2, Router.Error, Router.Table<Endpoint<A, P>>>, context: C, root: P, groups: List<&2, GroupPlan<P>>) -> Result<&2, &2, RegistrationError, Application<A, C, P>>:
  match result:
    case Fail{error}:
      Fail{RouteError{error}}
    case Done{table}:
      Done{Application{table, context, root, groups}}

def application.valid(~A: Data, ~C: Data, ~P: Data, valid: Bool, routes: List<&2, Route<A, P>>, +groups: List<&2, Group<P>>, context: C, +root: P) -> Result<&2, &2, RegistrationError, Application<A, C, P>>:
  match valid:
    case False{}:
      Fail{InvalidGroups{Nil{}}}
    case True{}:
      do Result<&2, &2, RegistrationError, Application<A, C, P>>:
        entries : List<&2, Router.Entry<Endpoint<A, P>>> <- routes.prepare(~A, ~P, routes, groups, root)
        plans : List<&2, GroupPlan<P>> <- groups.prepare(~P, groups, groups)
        application.table(~A, ~C, ~P, Router.prepare(~Endpoint<A, P>, entries), context, root, plans)

# Construction is pure and fallible; no listener or owner is started here.
def application(~A: Data, ~C: Data, ~P: Data, routes: List<&2, Route<A, P>>, +groups: List<&2, Group<P>>, context: C, root: P) -> Result<&2, &2, RegistrationError, Application<A, C, P>>:
  application.valid(~A, ~C, ~P, groups.valid(~P, groups, groups), routes, groups, context, root)

def describe(~A: Data, ~C: Data, ~P: Data, app: Application<A, C, P>) -> List<&2, Router.Description>:
  Application{table, context, root, groups} = app
  Router.describe(~Endpoint<A, P>, table)

# A closed template can run repeatedly; an affine callback registry cannot.
def plain(~handler: Http.Req -> IO(Http.Res), req: Http.Req) -> IO(Result<&2, &1, ResponseError, Http.Res>):
  do IO<Result<&2, &1, ResponseError, Http.Res>>:
    response : Http.Res <- handler(req)
    return validate(response)

type Policy<-H: Data> is Data:
  Policy{id: U32, before: List<&2, H>, transforms: List<&2, H>}

def policy(~H: Data, id: U32, before: List<&2, H>, transforms: List<&2, H>) -> Policy<H>:
  Policy{id, before, List.reverse(&2, H, transforms)}

type Metadata is Data:
  Metadata{method: String, target: String, headers: Map<&2, List<&2, String>>}

type Error<-E: Data> is Data:
  ApplicationError{error: E}
  Framework{status: U32, allow: String}
  ResponseInvalid{}

# Adapt reusable input status failures to the existing one-pass dispatch mapper.
def input(~I: Type, ~E: Data, outcome: Result<&2, &1, U32, I>) -> Result<&2, &1, Error<E>, I>:
  match outcome:
    case Fail{status}: Fail{Framework{status, ""}}
    case Done{value}: Done{value}

def execute.decoded(~I: Type, ~S: Type, ~K: Data, ~E: Data,
  ~handler: S -> K -> I -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  outcome: Result<&2, &1, Error<E>, I>, state: S, config: K
) -> IO(S & Result<&2, &1, Error<E>, Http.Res>):
  match outcome:
    case Fail{error}: IO.pure(S & Result<&2, &1, Error<E>, Http.Res>, (state, Fail{error}))
    case Done{value}: handler(state, config, value)

# An executor, not a second dispatcher: call from dispatch's run template, after
# all applicable before hooks. Only validated typed input reaches business IO.
def execute(~I: Type, ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~decoder: K -> Match<Policy<H>> -> Http.Req -> Result<&2, &1, Error<E>, I>,
  ~handler: S -> K -> I -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  state: S, +config: K, selected: Match<Policy<H>>, req: Http.Req
) -> IO(S & Result<&2, &1, Error<E>, Http.Res>):
  execute.decoded(~I, ~S, ~K, ~E, ~handler, decoder(config, selected, req), state, config)

type Step<-S: Type, -E: Data> is Type:
  Continue{state: S}
  Early{state: S, response: Http.Res}
  Reject{state: S, error: Error<E>}

type Completion<-S: Type, -H: Data> is Type:
  Completed{state: S, response: Http.Res, entered: List<&2, Policy<H>>, mapped: Bool, stopped: Bool}

# Application completion only: no socket write, duration, or peer-receipt claim.
def minimal() -> Http.Res:
  empty(500)

def problem.allow(add: Bool, headers: Map<&2, List<&2, String>>, allow: String) -> Map<&2, List<&2, String>>:
  match add:
    case True{}: Http.set(headers, "allow", allow)
    case False{}: headers

def problem.response(allow: String, response: Http.Res) -> Http.Res:
  Http.Res{+status, headers, body} = response
  Http.Res{status, problem.allow(U32.is_eq(status, 405), Http.set(headers, "content-type", "application/problem+json"), allow), body}

def problem(+status: U32, title: String, allow: String) -> Http.Res:
  problem.response(allow, json(~Json.Val, ~(x => x), status, Json.Obj{[(Json.utf8("type"), Json.Str{Json.utf8("about:blank")}), (Json.utf8("title"), Json.Str{Json.utf8(title)}), (Json.utf8("status"), Json.Num{Json.utf8(U32.show(status))})]}))

def default.error(~E: Data, error: Error<E>) -> Http.Res:
  match error:
    case Framework{status, allow}:
      match status:
        case 400:
          problem(400, "Bad Request", allow)
        case 404:
          problem(404, "Not Found", allow)
        case 405:
          problem(405, "Method Not Allowed", allow)
        case 415:
          problem(415, "Unsupported Media Type", allow)
        case _:
          minimal()
    case _:
      minimal()

def default.mapper(~S: Type, ~K: Data, ~E: Data, state: S, config: K, error: Error<E>) -> IO(S & Result<&2, &1, Error<E>, Http.Res>):
  IO.pure(S & Result<&2, &1, Error<E>, Http.Res>, (state, Done{default.error(~E, error)}))

def mapped.checked(~S: Type, ~H: Data, state: S, entered: List<&2, Policy<H>>, stopped: Bool, result: Result<&2, &1, ResponseError, Http.Res>) -> Completion<S, H>:
  match result:
    case Fail{error}:
      Completed{state, minimal(), entered, True{}, True{}}
    case Done{response}:
      Completed{state, response, entered, True{}, stopped}

def mapped.result(~S: Type, ~E: Data, ~H: Data, entered: List<&2, Policy<H>>, stopped: Bool, result: S & Result<&2, &1, Error<E>, Http.Res>) -> Completion<S, H>:
  (state, outcome) = result
  match outcome:
    case Fail{error}:
      Completed{state, minimal(), entered, True{}, True{}}
    case Done{response}:
      mapped.checked(~S, ~H, state, entered, stopped, validate(response))

def failed(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  mapped: Bool, state: S, config: K, error: Error<E>, entered: List<&2, Policy<H>>, stopped: Bool
) -> IO(Completion<S, H>):
  match mapped:
    case True{}:
      IO.pure(Completion<S, H>, Completed{state, minimal(), entered, True{}, True{}})
    case False{}:
      do IO<Completion<S, H>>:
        result : S & Result<&2, &1, Error<E>, Http.Res> <- mapper(state, config, error)
        return mapped.result(~S, ~E, ~H, entered, stopped, result)

def result(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  config: K, entered: List<&2, Policy<H>>, outcome: S & Result<&2, &1, Error<E>, Http.Res>
) -> IO(Completion<S, H>):
  (state, response) = outcome
  match response:
    case Fail{error}:
      failed(~S, ~K, ~E, ~H, ~mapper, False{}, state, config, error, entered, False{})
    case Done{res}:
      IO.pure(Completion<S, H>, Completed{state, res, entered, False{}, False{}})

def before.next(~S: Type, ~E: Data, step: Step<S, E>, next: S -> IO(Step<S, E>)) -> IO(Step<S, E>):
  match step:
    case Continue{state}:
      next(state)
    case Early{state, response}:
      IO.pure(Step<S, E>, Early{state, response})
    case Reject{state, error}:
      IO.pure(Step<S, E>, Reject{state, error})

def before(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  hooks: List<&2, H>, state: S, +config: K, +meta: Metadata
) -> IO(Step<S, E>):
  match hooks:
    case Nil{}:
      IO.pure(Step<S, E>, Continue{state})
    case h <> rest:
      do IO<Step<S, E>>:
        step : Step<S, E> <- hook(h, state, config, meta)
        before.next(~S, ~E, step, s => before(~S, ~K, ~E, ~H, ~hook, rest, s, config, meta))

def transformed(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  config: K, entered: List<&2, Policy<H>>, mapped: Bool, outcome: S & Result<&2, &1, Error<E>, Http.Res>
) -> IO(Completion<S, H>):
  (state, response) = outcome
  match response:
    case Fail{error}:
      failed(~S, ~K, ~E, ~H, ~mapper, mapped, state, config, error, entered, True{})
    case Done{res}:
      IO.pure(Completion<S, H>, Completed{state, res, entered, mapped, False{}})

def transforms(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  hooks: List<&2, H>, +config: K, completion: Completion<S, H>
) -> IO(Completion<S, H>):
  match hooks:
    case Nil{}:
      IO.pure(Completion<S, H>, completion)
    case h <> rest:
      match completion:
        case Completed{state, response, entered, mapped, True{}}:
          IO.pure(Completion<S, H>, Completed{state, response, entered, mapped, True{}})
        case Completed{state, response, +entered, +mapped, False{}}:
          do IO<Completion<S, H>>:
            changed : S & Result<&2, &1, Error<E>, Http.Res> <- hook(h, state, config, response)
            next : Completion<S, H> <- transformed(~S, ~K, ~E, ~H, ~mapper, config, entered, mapped, changed)
            transforms(~S, ~K, ~E, ~H, ~hook, ~mapper, rest, config, next)

def entered.step(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  config: K, entered: List<&2, Policy<H>>, body: Http.Body, step: Step<S, E>, next: S -> List<&2, Policy<H>> -> Http.Body -> IO(Completion<S, H>)
) -> IO(Completion<S, H>):
  match step:
    case Continue{state}:
      next(state, entered, body)
    case Early{state, response}:
      IO.pure(Completion<S, H>, Completed{state, response, entered, False{}, False{}})
    case Reject{state, error}:
      failed(~S, ~K, ~E, ~H, ~mapper, False{}, state, config, error, entered, False{})

def scopes(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~before_hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  ~after_hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  policies: List<&2, Policy<H>>, state: S, +config: K, +meta: Metadata, entered: List<&2, Policy<H>>, body: Http.Body,
  next: S -> List<&2, Policy<H>> -> Http.Body -> IO(Completion<S, H>)
) -> IO(Completion<S, H>):
  match policies:
    case Nil{}:
      next(state, entered, body)
    case Policy{+id, +hooks, +unwind} <> rest:
      scope = {Policy{id, hooks, unwind} : Policy<H>}
      do IO<Completion<S, H>>:
        step : Step<S, E> <- before(~S, ~K, ~E, ~H, ~before_hook, hooks, state, config, meta)
        inner : Completion<S, H> <- entered.step(~S, ~K, ~E, ~H, ~mapper, config, scope <> entered, body, step, s => ids => b => scopes(~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~mapper, rest, s, config, meta, ids, b, next))
        transforms(~S, ~K, ~E, ~H, ~after_hook, ~mapper, unwind, config, inner)

def finish.checked(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  state: S, config: K, entered: List<&2, Policy<H>>, mapped: Bool, stopped: Bool, checked: Result<&2, &1, ResponseError, Http.Res>
) -> IO(Completion<S, H>):
  match checked:
    case Done{response}:
      IO.pure(Completion<S, H>, Completed{state, response, entered, mapped, stopped})
    case Fail{error}:
      failed(~S, ~K, ~E, ~H, ~mapper, mapped, state, config, ResponseInvalid{}, entered, True{})

def finish(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  config: K, completion: Completion<S, H>
) -> IO(Completion<S, H>):
  Completed{state, response, entered, mapped, stopped} = completion
  finish.checked(~S, ~K, ~E, ~H, ~mapper, state, config, entered, mapped, stopped, validate(response))

def policies.tail(~H: Data, policies: List<&2, Policy<H>>) -> List<&2, Policy<H>>:
  match policies:
    case Nil{}:
      Nil{}
    case root <> rest:
      rest


def endpoint(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~run: A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  action: A, state: S, +config: K, selected: Match<Policy<H>>, meta: Metadata, entered: List<&2, Policy<H>>, body: Http.Body
) -> IO(Completion<S, H>):
  Metadata{method, target, headers} = meta
  do IO<Completion<S, H>>:
    outcome : S & Result<&2, &1, Error<E>, Http.Res> <- run(action, state, config, selected, Http.Req{method, target, headers, body})
    result(~S, ~K, ~E, ~H, ~mapper, config, entered, outcome)

def framework(~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  +status: U32, allow: String, state: S, config: K, entered: List<&2, Policy<H>>, body: Http.Body
) -> IO(Completion<S, H>):
  match status:
    case 204:
      IO.pure(Completion<S, H>, Completed{state, Http.Res{204, Http.set(Http.empty(), "allow", allow), Http.from_string("")}, entered, False{}, False{}})
    case _:
      failed(~S, ~K, ~E, ~H, ~mapper, False{}, state, config, Framework{status, allow}, entered, False{})

def choice(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~before_hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  ~after_hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~run: A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  selected: Router.Choice<Endpoint<A, Policy<H>>>, target: Target.Target,
  groups: List<&2, GroupPlan<Policy<H>>>, state: S, +config: K, +meta: Metadata, entered: List<&2, Policy<H>>, body: Http.Body
) -> IO(Completion<S, H>):
  match selected:
    case Router.NotFound{}:
      framework(~S, ~K, ~E, ~H, ~mapper, 404, "", state, config, entered, body)
    case Router.MethodMissing{ids, allow}:
      policies = groups.prepared(~Policy<H>, groups, ids)
      scopes(~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~mapper, policies, state, config, meta, entered, body,
        s => entered => b => framework(~S, ~K, ~E, ~H, ~mapper, 405, allow, s, config, entered, b))
    case Router.Options{ids, allow}:
      policies = groups.prepared(~Policy<H>, groups, ids)
      scopes(~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~mapper, policies, state, config, meta, entered, body,
        s => entered => b => framework(~S, ~K, ~E, ~H, ~mapper, 204, allow, s, config, entered, b))
    case Router.Found{Endpoint{action, +policies}, params, ids, method, pattern}:
      selected = {Match{target, params, ids, method, pattern, policies} : Match<Policy<H>>}
      scopes(~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~mapper, policies.tail(~H, policies), state, config, meta, entered, body,
        s => entered => b => endpoint(~A, ~S, ~K, ~E, ~H, ~run, ~mapper, action, s, config, selected, meta, entered, b))

def metadata.authority(authority: Maybe<&2, String>, meta: Metadata) -> Metadata:
  match authority:
    case None{}:
      meta
    case Some{host}:
      Metadata{method, target, headers} = meta
      Metadata{method, target, Http.set(headers, "host", host)}

def resolved(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~before_hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  ~after_hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~run: A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  outcome: Result<&2, &2, Router.Error, Router.Resolved<Endpoint<A, Policy<H>>>>,
  groups: List<&2, GroupPlan<Policy<H>>>, state: S, config: K, meta: Metadata, entered: List<&2, Policy<H>>, body: Http.Body
) -> IO(Completion<S, H>):
  match outcome:
    case Fail{error}:
      framework(~S, ~K, ~E, ~H, ~mapper, 400, "", state, config, entered, body)
    case Done{Router.Resolved{+target, selected}}:
      Target.Target{segments, query, authority, star} = target
      choice(~A, ~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~run, ~mapper, selected, target, groups, state, config, metadata.authority(authority, meta), entered, body)

def dispatch.application(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~before_hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  ~after_hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~run: A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  app: Application<A, K, Policy<H>>, state: S, req: Http.Req
) -> IO(Completion<S, H>):
  Application{table, +config, root, groups} = app
  Http.Req{+method, +path, +headers, body} = req
  +meta = {Metadata{method, path, headers} : Metadata}
  do IO<Completion<S, H>>:
    completion : Completion<S, H> <- scopes(~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~mapper, [root], state, config, meta, Nil{}, body,
      s => entered => b => resolved(~A, ~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~run, ~mapper,
        Router.resolve(~Endpoint<A, Policy<H>>, table, method, path), groups, s, config, meta, entered, b))
    finish(~S, ~K, ~E, ~H, ~mapper, config, completion)

def access.disabled(~K: Data, config: K) -> Notices.Access:
  Notices.Disabled{}

def notice.ignore(~N: Data, ~H: Data, ~E: Data, observer: N, policy: Policy<H>, notice: Notices.Notice) -> IO(Result<&2, &2, E, Unit>):
  IO.pure(Result<&2, &2, E, Unit>, Done{Unit{}})

def notice.error.ignore(~N: Data, ~E: Data, observer: N, error: E) -> IO(Unit):
  IO.pure(Unit, Unit{})

def notice.result(~N: Data, ~E: Data, ~report: N -> E -> IO(Unit), observer: N, result: Result<&2, &2, E, Unit>) -> IO(Unit):
  match result:
    case Done{unit}: IO.pure(Unit, Unit{})
    case Fail{error}: report(observer, error)

def notices(~N: Data, ~H: Data, ~E: Data,
  ~notify: N -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: N -> E -> IO(Unit),
  entered: List<&2, Policy<H>>, +observer: N, +notice: Notices.Notice
) -> IO(Unit):
  match entered:
    case Nil{}: IO.pure(Unit, Unit{})
    case policy <> rest:
      do IO<Unit>:
        result : Result<&2, &2, E, Unit> <- notify(observer, policy, notice)
        notice.result(~N, ~E, ~report, observer, result)
        notices(~N, ~H, ~E, ~notify, ~report, rest, observer, notice)

def dispatch.completed(~S: Type, ~N: Data, ~H: Data, ~E: Data,
  ~notify: N -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: N -> E -> IO(Unit),
  observer: N, access: Notices.Access, started: Time.Duration, completion: Completion<S, H>
) -> IO(Completion<S, H>):
  Completed{state, Http.Res{+status, headers, body}, +entered, +mapped, +stopped} = completion
  do IO<Completion<S, H>>:
    ended : Time.Duration <- Time.mono()
    +notice : Notices.Notice = Notices.Notice{status, Time.Duration.sub(ended, started), mapped, stopped, Notices.ApplicationOnly{}}
    notices(~N, ~H, ~E, ~notify, ~report, entered, observer, notice)
    Notices.access(access, notice)
    return Completed{state, Http.Res{status, headers, body}, entered, mapped, stopped}

# The same application pipeline is used live; only this boundary emits direct notices.
def dispatch(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~H: Data, ~N: Data,
  ~before_hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  ~after_hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~run: A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~notify: N -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: N -> E -> IO(Unit),
  observer: N, access: Notices.Access, app: Application<A, K, Policy<H>>, state: S, req: Http.Req
) -> IO(Completion<S, H>):
  do IO<Completion<S, H>>:
    started : Time.Duration <- Time.mono()
    completion : Completion<S, H> <- dispatch.application(~A, ~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~run, ~mapper, app, state, req)
    dispatch.completed(~S, ~N, ~H, ~E, ~notify, ~report, observer, access, started, completion)

# The wrapper owns both pipes until its admitted operation really returns.
# Only disposable HTTP packed buffers cross them, never external handles.
type BufferedRequest is Data:
  BufferedRequest{metadata: Metadata, body: Chan(Http.Body), response: Chan(Http.Res)}

type ApplicationReport<-H: Data> is Data:
  Dispatched{entered: List<&2, Policy<H>>, mapped: Bool, stopped: Bool}
  CapacityRejected{}

type ServingContext<-A: Data, -S: Type, -K: Data, -H: Data> is Data:
  ServingContext{application: Application<A, K, Policy<H>>,
    owner: Context<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>}

type Server<-A: Data, -S: Type, -K: Data, -H: Data> is Type:
  Server{transport: Http.Server<ServingContext<A, S, K, H>>,
    owner: Owner<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>}

type StartupError is Data:
  RegistrationFailed{error: RegistrationError}
  TransportFailed{error: Http.StartupError}
  EmptyBundles{}

type ServerExit<-A: Data, -S: Type, -K: Data, -H: Data> is Type:
  ServerExit{transport: Http.ServerExit, application: OwnerClose<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>}

def server.config(port: U32) -> Http.ServerConfig:
  Http.ServerConfig{"127.0.0.1", port, 1048576, 65536, 128, 128, 128, 5000, 30000, 30000, 30000}

def server.bundles.cons(~S: Type, resource: S, counted: List<S> & Nat) -> List<S> & Nat:
  (returned, count) = counted
  (resource <> returned, 1n+count)

def server.bundles(~S: Type, resources: List<S>) -> List<S> & Nat:
  match resources:
    case Nil{}: (Nil{}, 0n)
    case resource <> rest:
      server.bundles.cons(~S, resource, server.bundles(~S, rest))

def server.work.completed(~S: Type, ~H: Data, response_channel: Chan(Http.Res),
  completion: Completion<S, H>
) -> IO(S & Result<&2, &2, Unit, ApplicationReport<H>>):
  Completed{state, response, entered, mapped, stopped} = completion
  do IO<S & Result<&2, &2, Unit, ApplicationReport<H>>>:
    sent : Bool <- Chan.send(Http.Res, response_channel, response)
    return (state, Done{Dispatched{entered, mapped, stopped}})

def server.work(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~before_hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  ~after_hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~run: A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  state: S, app: Application<A, K, Policy<H>>, input: BufferedRequest
) -> IO(S & Result<&2, &2, Unit, ApplicationReport<H>>):
  BufferedRequest{Metadata{method, target, headers}, body_channel, response_channel} = input
  do IO<S & Result<&2, &2, Unit, ApplicationReport<H>>>:
    body : Http.Body <- receive(Http.Body, body_channel)
    completion : Completion<S, H> <- dispatch.application(~A, ~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~run, ~mapper,
      app, state, Http.Req{method, target, headers, body})
    server.work.completed(~S, ~H, response_channel, completion)

type NoticePayload<-K: Data, -H: Data> is Data:
  NoticePayload{config: K, started: Time.Duration, application: ApplicationReport<H>}

def server.notified(~K: Data, ~H: Data, ~E: Data,
  ~notify: K -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: K -> E -> IO(Unit), ~access: K -> Notices.Access,
  ~done: TransportCompletion.Completion<ApplicationReport<H>> -> IO(Unit),
  +config: K, +notice: Notices.Notice, application: ApplicationReport<H>,
  status: U32, outcome: TransportCompletion.Outcome
) -> IO(Unit):
  match application:
    case Dispatched{+entered, +mapped, +stopped}:
      do IO<Unit>:
        notices(~K, ~H, ~E, ~notify, ~report, entered, config, notice)
        Notices.access(access(config), notice)
        done(TransportCompletion.Completion{Dispatched{entered, mapped, stopped}, status, outcome})
    case CapacityRejected{}:
      do IO<Unit>:
        Notices.access(access(config), notice)
        done(TransportCompletion.Completion{CapacityRejected{}, status, outcome})

def server.completed.report(~K: Data, ~H: Data, ~E: Data,
  ~notify: K -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: K -> E -> IO(Unit), ~access: K -> Notices.Access,
  ~done: TransportCompletion.Completion<ApplicationReport<H>> -> IO(Unit),
  config: K, duration: Time.Duration, application: ApplicationReport<H>, +status: U32, +outcome: TransportCompletion.Outcome
) -> IO(Unit):
  match application:
    case Dispatched{+entered, +mapped, +stopped}:
      server.notified(~K, ~H, ~E, ~notify, ~report, ~access, ~done, config,
        Notices.Notice{status, duration, mapped, stopped, Notices.Transport{outcome}}, Dispatched{entered, mapped, stopped}, status, outcome)
    case CapacityRejected{}:
      server.notified(~K, ~H, ~E, ~notify, ~report, ~access, ~done, config,
        Notices.Notice{status, duration, False{}, False{}, Notices.Transport{outcome}}, CapacityRejected{}, status, outcome)

def server.completed(~K: Data, ~H: Data, ~E: Data,
  ~notify: K -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: K -> E -> IO(Unit), ~access: K -> Notices.Access,
  ~done: TransportCompletion.Completion<ApplicationReport<H>> -> IO(Unit),
  completion: TransportCompletion.Completion<NoticePayload<K, H>>
) -> IO(Unit):
  TransportCompletion.Completion{NoticePayload{config, started, +application}, +status, +outcome} = completion
  do IO<Unit>:
    ended : Time.Duration <- Time.mono()
    server.completed.report(~K, ~H, ~E, ~notify, ~report, ~access, ~done, config, Time.Duration.sub(ended, started), application, status, outcome)

def server.response(~K: Data, ~H: Data,
  ~done: TransportCompletion.Completion<NoticePayload<K, H>> -> IO(Unit),
  config: K, started: Time.Duration, outcome: Outcome<Unit, ApplicationReport<H>>, +body: Chan(Http.Body), +response: Chan(Http.Res)
) -> IO(Http.Reply):
  match outcome:
    case Success{report}:
      do IO<Http.Reply>:
        result : Http.Res <- receive(Http.Res, response)
        Chan.close(Http.Body, body)
        Chan.close(Http.Res, response)
        return Http.reply.complete(~NoticePayload<K, H>, ~done, NoticePayload{config, started, report}, result)
    case _:
      do IO<Http.Reply>:
        # Closing alone retains buffered values in Base. Consume the rejected
        # body before closing; the single room1 send has already completed.
        discarded : Http.Body <- receive(Http.Body, body)
        Chan.close(Http.Body, body)
        Chan.close(Http.Res, response)
        return Http.reply.complete(~NoticePayload<K, H>, ~done, NoticePayload{config, started, CapacityRejected{}},
          Http.Res{503, Http.set(Http.empty(), "connection", "close"), Http.from_string("")})

def server.handle(~A: Data, ~S: Type, ~K: Data, ~H: Data,
  ~done: TransportCompletion.Completion<NoticePayload<K, H>> -> IO(Unit),
  context: ServingContext<A, S, K, H>, req: Http.Req
) -> IO(Http.Reply):
  ServingContext{+app, owner} = context
  Application{table, config, root, groups} = app
  Http.Req{method, target, headers, body} = req
  do IO<Http.Reply>:
    started : Time.Duration <- Time.mono()
    +body_channel : Chan(Http.Body) <- Chan.new(Http.Body, 1)
    +response_channel : Chan(Http.Res) <- Chan.new(Http.Res, 1)
    sent : Bool <- Chan.send(Http.Body, body_channel, body)
    outcome : Outcome<Unit, ApplicationReport<H>> <- call(S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>,
      owner, app, BufferedRequest{Metadata{method, target, headers}, body_channel, response_channel})
    server.response(~K, ~H, ~done, config, started, outcome, body_channel, response_channel)


def server.started(~A: Data, ~S: Type, ~K: Data, ~H: Data,
  ~work: S -> Application<A, K, Policy<H>> -> BufferedRequest -> IO(S & Result<&2, &2, Unit, ApplicationReport<H>>),
  ~destroy: S -> IO(Unit),
  +context: Context<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>,
  room: U32, capacity: Nat,
  started: List<S> & Result<&2, &1, Http.StartupError, Http.Server<ServingContext<A, S, K, H>>>
) -> IO(Result<&2, &1, StartupError, Server<A, S, K, H>>):
  Context{+messages} = context
  (resources, result) = started
  match result:
    case Fail{error}:
      do IO<Result<&2, &1, StartupError, Server<A, S, K, H>>>:
        dispose(~S, ~destroy, resources)
        Chan.close(Message<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>, messages)
        return Fail{TransportFailed{error}}
    case Done{transport}:
      do IO<Result<&2, &1, StartupError, Server<A, S, K, H>>>:
        finished : Chan(Unit) <- IO.fork(Unit, owner(~S, ~Application<A, K, Policy<H>>, ~BufferedRequest, ~Unit, ~ApplicationReport<H>,
          ~work, ~destroy, messages, room, Waiting{resources, Counts{capacity, 0n, 0n, 0n}}))
        return Done{Server{transport, Owner{Context{messages}, finished}}}

def server.prepared(~A: Data, ~S: Type, ~K: Data, ~H: Data,
  ~work: S -> Application<A, K, Policy<H>> -> BufferedRequest -> IO(S & Result<&2, &2, Unit, ApplicationReport<H>>),
  ~destroy: S -> IO(Unit), app: Application<A, K, Policy<H>>, +config: Http.ServerConfig, resources: List<S> & Nat
) -> IO(Result<&2, &1, StartupError, Server<A, S, K, H>>):
  Http.ServerConfig{host, port, body, headers, connections, requests, +buffered, hm, bm, im, wm} = config
  (bundles, capacity) = resources
  match capacity:
    case 0n:
      do IO<Result<&2, &1, StartupError, Server<A, S, K, H>>>:
        dispose(~S, ~destroy, bundles)
        return Fail{EmptyBundles{}}
    case 1n+ +rest:
      do IO<Result<&2, &1, StartupError, Server<A, S, K, H>>>:
        messages : Chan(Message<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>) <-
          Chan.new(Message<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>, buffered)
        +context : Context<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>> = Context{messages}
        started : List<S> & Result<&2, &1, Http.StartupError, Http.Server<ServingContext<A, S, K, H>>> <-
          Http.server.start(~ServingContext<A, S, K, H>, ~List<S>, ServingContext{app, context}, bundles, config)
        server.started(~A, ~S, ~K, ~H, ~work, ~destroy, context, buffered, 1n+rest, started)

def server.valid(~A: Data, ~S: Type, ~K: Data, ~H: Data,
  ~work: S -> Application<A, K, Policy<H>> -> BufferedRequest -> IO(S & Result<&2, &2, Unit, ApplicationReport<H>>),
  ~destroy: S -> IO(Unit), valid: Bool, app: Application<A, K, Policy<H>>, config: Http.ServerConfig, resources: List<S>
) -> IO(Result<&2, &1, StartupError, Server<A, S, K, H>>):
  match valid:
    case False{}:
      do IO<Result<&2, &1, StartupError, Server<A, S, K, H>>>:
        dispose(~S, ~destroy, resources)
        return Fail{TransportFailed{Http.InvalidConfig{}}}
    case True{}:
      server.prepared(~A, ~S, ~K, ~H, ~work, ~destroy, app, config, server.bundles(~S, resources))

def server.registered(~A: Data, ~S: Type, ~K: Data, ~H: Data,
  ~work: S -> Application<A, K, Policy<H>> -> BufferedRequest -> IO(S & Result<&2, &2, Unit, ApplicationReport<H>>),
  ~destroy: S -> IO(Unit), registration: Result<&2, &2, RegistrationError, Application<A, K, Policy<H>>>,
  +config: Http.ServerConfig, resources: List<S>
) -> IO(Result<&2, &1, StartupError, Server<A, S, K, H>>):
  match registration:
    case Fail{error}:
      do IO<Result<&2, &1, StartupError, Server<A, S, K, H>>>:
        dispose(~S, ~destroy, resources)
        return Fail{RegistrationFailed{error}}
    case Done{app}:
      server.valid(~A, ~S, ~K, ~H, ~work, ~destroy, Http.server.config.valid(config), app, config, resources)

def server.start(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~before_hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  ~after_hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~run: A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~destroy: S -> IO(Unit),
  registration: Result<&2, &2, RegistrationError, Application<A, K, Policy<H>>>,
  config: Http.ServerConfig, resources: List<S>
) -> IO(Result<&2, &1, StartupError, Server<A, S, K, H>>):
  server.registered(~A, ~S, ~K, ~H,
    ~(state => app => input => server.work(~A, ~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~run, ~mapper, state, app, input)),
    ~destroy, registration, config, resources)

def server.control.result(~A: Data, ~S: Type, ~K: Data, ~H: Data,
  controlled: Http.Server<ServingContext<A, S, K, H>> & Http.ServerControl,
  owner: Owner<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>
) -> Server<A, S, K, H> & Http.ServerControl:
  (returned, control) = controlled
  (Server{returned, owner}, control)

def server.control(~A: Data, ~S: Type, ~K: Data, ~H: Data, server: Server<A, S, K, H>) -> Server<A, S, K, H> & Http.ServerControl:
  Server{transport, owner} = server
  server.control.result(~A, ~S, ~K, ~H, Http.server.control(~ServingContext<A, S, K, H>, transport), owner)

def server.observer.result(~A: Data, ~S: Type, ~K: Data, ~H: Data,
  observed: Http.Server<ServingContext<A, S, K, H>> & Http.ServerStats,
  owner: Owner<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>
) -> Server<A, S, K, H> & Http.ServerStats:
  (returned, stats) = observed
  (Server{returned, owner}, stats)

def server.observer(~A: Data, ~S: Type, ~K: Data, ~H: Data, server: Server<A, S, K, H>) -> Server<A, S, K, H> & Http.ServerStats:
  Server{transport, owner} = server
  server.observer.result(~A, ~S, ~K, ~H, Http.server.observer(~ServingContext<A, S, K, H>, transport), owner)

def server.dependencies(~A: Data, ~S: Type, ~K: Data, ~H: Data, server: Server<A, S, K, H>
) -> Server<A, S, K, H> & Context<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>>:
  Server{transport, Owner{+context, finished}} = server
  (Server{transport, Owner{context, finished}}, context)

def server.run(~A: Data, ~S: Type, ~K: Data, ~H: Data, ~E: Data,
  ~done: TransportCompletion.Completion<ApplicationReport<H>> -> IO(Unit),
  ~observe: U32 -> TransportCompletion.Outcome -> IO(Unit),
  ~notify: K -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: K -> E -> IO(Unit), ~access: K -> Notices.Access,
  server: Server<A, S, K, H>
) -> IO(ServerExit<A, S, K, H>):
  Server{transport, owner} = server
  do IO<ServerExit<A, S, K, H>>:
    exited : Http.ServerExit <- Http.server.run(~ServingContext<A, S, K, H>,
      ~(context => req => server.handle(~A, ~S, ~K, ~H,
        ~(completion => server.completed(~K, ~H, ~E, ~notify, ~report, ~access, ~done, completion)), context, req)),
      ~(context => status => outcome => observe(status, outcome)), transport)
    closed : OwnerClose<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>> <- close(S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>, owner)
    return ServerExit{exited, closed}

# Without starting the run loop, the caller still explicitly drains transport
# and joins application cleanup. A stop request alone is never completion.
def server.close(~A: Data, ~S: Type, ~K: Data, ~H: Data, server: Server<A, S, K, H>) -> IO(ServerExit<A, S, K, H>):
  Server{transport, owner} = server
  do IO<ServerExit<A, S, K, H>>:
    counts : Http.ServerCounts <- Http.server.close(~ServingContext<A, S, K, H>, transport)
    closed : OwnerClose<S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>> <- close(S, Application<A, K, Policy<H>>, BufferedRequest, Unit, ApplicationReport<H>, owner)
    return ServerExit{Http.ServerStopped{counts}, closed}

def serve.started(~A: Data, ~S: Type, ~K: Data, ~H: Data, ~E: Data,
  ~done: TransportCompletion.Completion<ApplicationReport<H>> -> IO(Unit),
  ~observe: U32 -> TransportCompletion.Outcome -> IO(Unit),
  ~notify: K -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: K -> E -> IO(Unit), ~access: K -> Notices.Access,
  started: Result<&2, &1, StartupError, Server<A, S, K, H>>
) -> IO(Result<&2, &1, StartupError, ServerExit<A, S, K, H>>):
  match started:
    case Fail{error}: IO.pure(Result<&2, &1, StartupError, ServerExit<A, S, K, H>>, Fail{error})
    case Done{server}:
      do IO<Result<&2, &1, StartupError, ServerExit<A, S, K, H>>>:
        exited : ServerExit<A, S, K, H> <- server.run(~A, ~S, ~K, ~H, ~E, ~done, ~observe, ~notify, ~report, ~access, server)
        return Done{exited}

# Owners that need readiness/control use server.start then server.run instead.
def serve(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~before_hook: H -> S -> K -> Metadata -> IO(Step<S, E>),
  ~after_hook: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~run: A -> S -> K -> Match<Policy<H>> -> Http.Req -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~mapper: S -> K -> Error<E> -> IO(S & Result<&2, &1, Error<E>, Http.Res>),
  ~destroy: S -> IO(Unit),
  ~done: TransportCompletion.Completion<ApplicationReport<H>> -> IO(Unit),
  ~observe: U32 -> TransportCompletion.Outcome -> IO(Unit),
  ~notify: K -> Policy<H> -> Notices.Notice -> IO(Result<&2, &2, E, Unit>),
  ~report: K -> E -> IO(Unit), ~access: K -> Notices.Access,
  registration: Result<&2, &2, RegistrationError, Application<A, K, Policy<H>>>,
  config: Http.ServerConfig, resources: List<S>
) -> IO(Result<&2, &1, StartupError, ServerExit<A, S, K, H>>):
  do IO<Result<&2, &1, StartupError, ServerExit<A, S, K, H>>>:
    started : Result<&2, &1, StartupError, Server<A, S, K, H>> <-
      server.start(~A, ~S, ~K, ~E, ~H, ~before_hook, ~after_hook, ~run, ~mapper, ~destroy, registration, config, resources)
    serve.started(~A, ~S, ~K, ~H, ~E, ~done, ~observe, ~notify, ~report, ~access, started)
