# Fixed prepared HTTP applications and bounded affine dependency bundles.
import Base
import bend-kit-http@0.25.0.2/http.bend as Http
import bend-kit-router@0.2.0.0/router.bend as Router
import bend-kit-router@0.2.0.0/target.bend as Target
import bend-kit-json@0.5.1.0/json.bend as Json
import ./response.bend as Response

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

# Policies are prepared Data, not callbacks. Later lifecycle stages can consume
# these root-to-route declarations without splitting patterns or finding groups.
type Group<-P: Data> is Data:
  Group{id: U32, ancestors: List<&2, U32>, policy: P}

type Route<-A: Data, -P: Data> is Data:
  Route{method: String, pattern: String, action: A, groups: List<&2, U32>, policy: P}

type Endpoint<-A: Data, -P: Data> is Data:
  Endpoint{action: A, policies: List<&2, P>}

type Application<-A: Data, -C: Data, -P: Data> is Data:
  Application{table: Router.Table<Endpoint<A, P>>, context: C, root: P}

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

def application.table(~A: Data, ~C: Data, ~P: Data, result: Result<&2, &2, Router.Error, Router.Table<Endpoint<A, P>>>, context: C, root: P) -> Result<&2, &2, RegistrationError, Application<A, C, P>>:
  match result:
    case Fail{error}:
      Fail{RouteError{error}}
    case Done{table}:
      Done{Application{table, context, root}}

def application.valid(~A: Data, ~C: Data, ~P: Data, valid: Bool, routes: List<&2, Route<A, P>>, groups: List<&2, Group<P>>, context: C, +root: P) -> Result<&2, &2, RegistrationError, Application<A, C, P>>:
  match valid:
    case False{}:
      Fail{InvalidGroups{Nil{}}}
    case True{}:
      do Result<&2, &2, RegistrationError, Application<A, C, P>>:
        entries : List<&2, Router.Entry<Endpoint<A, P>>> <- routes.prepare(~A, ~P, routes, groups, root)
        application.table(~A, ~C, ~P, Router.prepare(~Endpoint<A, P>, entries), context, root)

# Construction is pure and fallible; no listener or owner is started here.
def application(~A: Data, ~C: Data, ~P: Data, routes: List<&2, Route<A, P>>, +groups: List<&2, Group<P>>, context: C, root: P) -> Result<&2, &2, RegistrationError, Application<A, C, P>>:
  application.valid(~A, ~C, ~P, groups.valid(~P, groups, groups), routes, groups, context, root)

def describe(~A: Data, ~C: Data, ~P: Data, app: Application<A, C, P>) -> List<&2, Router.Description>:
  Application{table, context, root} = app
  Router.describe(~Endpoint<A, P>, table)

def request.authority(authority: Maybe<&2, String>, req: Http.Req) -> Http.Req:
  match authority:
    case None{}:
      req
    case Some{host}:
      Http.Req{method, path, headers, body} = req
      Http.Req{method, path, Http.set(headers, "host", host), body}

# A closed template can run repeatedly; an affine callback registry cannot.
def plain(~handler: Http.Req -> IO(Http.Res), req: Http.Req) -> IO(Result<&2, &1, ResponseError, Http.Res>):
  do IO<Result<&2, &1, ResponseError, Http.Res>>:
    response : Http.Res <- handler(req)
    return validate(response)

def dispatch.choice(~A: Data, ~C: Data, ~P: Data,
  ~run: A -> C -> Match<P> -> Http.Req -> IO(Http.Res),
  choice: Router.Choice<Endpoint<A, P>>, context: C, target: Target.Target, req: Http.Req
) -> IO(Http.Res):
  match choice:
    case Router.NotFound{}:
      IO.pure(Http.Res, Http.Res{404, Http.empty(), Http.from_string("")})
    case Router.MethodMissing{groups, allow}:
      IO.pure(Http.Res, Http.Res{405, Http.set(Http.empty(), "allow", allow), Http.from_string("")})
    case Router.Options{groups, allow}:
      IO.pure(Http.Res, Http.Res{204, Http.set(Http.empty(), "allow", allow), Http.from_string("")})
    case Router.Found{Endpoint{action, policies}, params, groups, method, pattern}:
      run(action, context, Match{target, params, groups, method, pattern, policies}, req)

def dispatch.resolved(~A: Data, ~C: Data, ~P: Data,
  ~run: A -> C -> Match<P> -> Http.Req -> IO(Http.Res),
  result: Result<&2, &2, Router.Error, Router.Resolved<Endpoint<A, P>>>, context: C, req: Http.Req
) -> IO(Http.Res):
  match result:
    case Fail{error}:
      IO.pure(Http.Res, Http.Res{400, Http.empty(), Http.from_string("")})
    case Done{Router.Resolved{+target, choice}}:
      Target.Target{segments, query, authority, star} = target
      dispatch.choice(~A, ~C, ~P, ~run, choice, context, target, request.authority(authority, req))

# Dispatch moves the original packed body once and returns application bytes.
# In particular it never performs transport's HEAD/204/304 body suppression.
def dispatch(~A: Data, ~C: Data, ~P: Data,
  ~run: A -> C -> Match<P> -> Http.Req -> IO(Http.Res),
  app: Application<A, C, P>, req: Http.Req
) -> IO(Result<&2, &1, ResponseError, Http.Res>):
  Application{table, context, root} = app
  Http.Req{+method, +path, headers, body} = req
  do IO<Result<&2, &1, ResponseError, Http.Res>>:
    response : Http.Res <- dispatch.resolved(~A, ~C, ~P, ~run, Router.resolve(~Endpoint<A, P>, table, method, path), context, Http.Req{method, path, headers, body})
    return validate(response)
