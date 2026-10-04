# Application-surface validation primitives, not Camber's public API.
import Base
import ../http/http.bend as Http
import ./interface_check.bend as Registry

type Step<-E: Data, -C: Type> is Type:
  Continue{context: C}
  Early{response: Http.Res}
  Reject{error: E}

type Flow is Type:
  Flow{response: Http.Res, mapped: Bool, stopped: Bool}

type Policy<-H: Data> is Data:
  Policy{unwind: List<&2, H>}

def policy(~H: Data, declared: List<&2, H>) -> Policy<H>:
  Policy{List.reverse(&2, H, declared)}

def minimal() -> Http.Res:
  Http.Res{500, Http.empty(), Http.from_string("")}

def mapped.valid(~S: Type, ~E: Data, state: S, stopped: Bool, checked: Result<&2, &1, E, Http.Res>) -> S & Flow:
  match checked:
    case Fail{error}:
      (state, Flow{minimal(), True{}, True{}})
    case Done{response}:
      (state, Flow{response, True{}, stopped})

def mapped.result(~S: Type, ~E: Data, ~validate: Http.Res -> Result<&2, &1, E, Http.Res>, stopped: Bool, result: S & Result<&2, &1, E, Http.Res>) -> S & Flow:
  (state, outcome) = result
  match outcome:
    case Fail{error}:
      (state, Flow{minimal(), True{}, True{}})
    case Done{response}:
      mapped.valid(~S, ~E, state, stopped, validate(response))

def failed(
  ~S: Type, ~K: Data, ~E: Data,
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  state: S, config: K, error: E, stopped: Bool
) -> IO(S & Flow):
  do IO<S & Flow>:
    result : S & Result<&2, &1, E, Http.Res> <- mapper(state, config, error)
    return mapped.result(~S, ~E, ~validate, stopped, result)

def recover(
  ~S: Type, ~K: Data, ~E: Data,
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  config: K, result: S & Result<&2, &1, E, Http.Res>
) -> IO(S & Flow):
  (state, outcome) = result
  match outcome:
    case Fail{error}:
      failed(~S, ~K, ~E, ~mapper, ~validate, state, config, error, False{})
    case Done{response}:
      IO.pure(S & Flow, (state, Flow{response, False{}, False{}}))

def before.result(
  ~S: Type, ~K: Data, ~E: Data, ~C: Type, ~D: Type,
  ~second: S -> K -> Registry.Metadata -> C -> IO(S & Step<E, D>),
  config: K, meta: Registry.Metadata, result: S & Step<E, C>
) -> IO(S & Step<E, D>):
  (state, step) = result
  match step:
    case Continue{context}:
      second(state, config, meta, context)
    case Early{response}:
      IO.pure(S & Step<E, D>, (state, Early{response}))
    case Reject{error}:
      IO.pure(S & Step<E, D>, (state, Reject{error}))

def before(
  ~S: Type, ~K: Data, ~E: Data, ~B: Type, ~C: Type, ~D: Type,
  ~first: S -> K -> Registry.Metadata -> B -> IO(S & Step<E, C>),
  ~second: S -> K -> Registry.Metadata -> C -> IO(S & Step<E, D>),
  state: S, +config: K, +meta: Registry.Metadata, context: B
) -> IO(S & Step<E, D>):
  do IO<S & Step<E, D>>:
    result : S & Step<E, C> <- first(state, config, meta, context)
    before.result(~S, ~K, ~E, ~C, ~D, ~second, config, meta, result)

def endpoint.decoded(
  ~S: Type, ~K: Data, ~E: Data, ~I: Type,
  ~handler: S -> K -> I -> IO(S & Result<&2, &1, E, Http.Res>),
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  +config: K, result: S & Result<&2, &1, E, I>
) -> IO(S & Flow):
  (state, decoded) = result
  match decoded:
    case Fail{error}:
      failed(~S, ~K, ~E, ~mapper, ~validate, state, config, error, False{})
    case Done{input}:
      do IO<S & Flow>:
        result : S & Result<&2, &1, E, Http.Res> <- handler(state, config, input)
        recover(~S, ~K, ~E, ~mapper, ~validate, config, result)

def endpoint(
  ~S: Type, ~K: Data, ~E: Data, ~C: Type, ~I: Type,
  ~decode: S -> K -> Registry.Metadata -> C -> Http.Body -> IO(S & Result<&2, &1, E, I>),
  ~handler: S -> K -> I -> IO(S & Result<&2, &1, E, Http.Res>),
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  state: S, +config: K, meta: Registry.Metadata, context: C, body: Http.Body
) -> IO(S & Flow):
  do IO<S & Flow>:
    decoded : S & Result<&2, &1, E, I> <- decode(state, config, meta, context, body)
    endpoint.decoded(~S, ~K, ~E, ~I, ~handler, ~mapper, ~validate, config, decoded)

def transforms.failure(
  ~S: Type, ~K: Data, ~E: Data,
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  mapped: Bool, state: S, config: K, error: E
) -> IO(S & Flow):
  match mapped:
    case True{}:
      IO.pure(S & Flow, (state, Flow{minimal(), True{}, True{}}))
    case False{}:
      failed(~S, ~K, ~E, ~mapper, ~validate, state, config, error, True{})

def transforms.result(
  ~S: Type, ~K: Data, ~E: Data,
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  config: K, mapped: Bool, result: S & Result<&2, &1, E, Http.Res>
) -> IO(S & Flow):
  (state, transformed) = result
  match transformed:
    case Fail{error}:
      transforms.failure(~S, ~K, ~E, ~mapper, ~validate, mapped, state, config, error)
    case Done{response}:
      IO.pure(S & Flow, (state, Flow{response, mapped, False{}}))

def transforms(
  ~S: Type, ~K: Data, ~E: Data, ~H: Data,
  ~after: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, E, Http.Res>),
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  hooks: List<&2, H>, +config: K, result: S & Flow
) -> IO(S & Flow):
  match hooks:
    case Nil{}:
      IO.pure(S & Flow, result)
    case hook <> rest:
      (state, flow) = result
      match flow:
        case Flow{response, mapped, True{}}:
          IO.pure(S & Flow, (state, Flow{response, mapped, True{}}))
        case Flow{response, +mapped, False{}}:
          do IO<S & Flow>:
            changed : S & Result<&2, &1, E, Http.Res> <- after(hook, state, config, response)
            next : S & Flow <- transforms.result(~S, ~K, ~E, ~mapper, ~validate, config, mapped, changed)
            transforms(~S, ~K, ~E, ~H, ~after, ~mapper, ~validate, rest, config, next)

def scope.result(
  ~S: Type, ~K: Data, ~E: Data, ~C: Type,
  ~inner: S -> K -> Registry.Metadata -> C -> Http.Body -> IO(S & Flow),
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  config: K, meta: Registry.Metadata, body: Http.Body, result: S & Step<E, C>
) -> IO(S & Flow):
  (state, step) = result
  match step:
    case Continue{context}:
      inner(state, config, meta, context, body)
    case Early{response}:
      IO.pure(S & Flow, (state, Flow{response, False{}, False{}}))
    case Reject{error}:
      failed(~S, ~K, ~E, ~mapper, ~validate, state, config, error, False{})

def scope(
  ~S: Type, ~K: Data, ~E: Data, ~B: Type, ~C: Type, ~H: Data,
  ~enter: S -> K -> Registry.Metadata -> B -> IO(S & Step<E, C>),
  ~inner: S -> K -> Registry.Metadata -> C -> Http.Body -> IO(S & Flow),
  ~after: H -> S -> K -> Http.Res -> IO(S & Result<&2, &1, E, Http.Res>),
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  policy: Policy<H>, state: S, +config: K, +meta: Registry.Metadata, context: B, body: Http.Body
) -> IO(S & Flow):
  Policy{unwind} = policy
  do IO<S & Flow>:
    entered : S & Step<E, C> <- enter(state, config, meta, context)
    result : S & Flow <- scope.result(~S, ~K, ~E, ~C, ~inner, ~mapper, ~validate, config, meta, body, entered)
    transforms(~S, ~K, ~E, ~H, ~after, ~mapper, ~validate, unwind, config, result)

def finish.checked(
  ~S: Type, ~K: Data, ~E: Data,
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  state: S, config: K, mapped: Bool, stopped: Bool, checked: Result<&2, &1, E, Http.Res>
) -> IO(S & Flow):
  match checked:
    case Done{response}:
      IO.pure(S & Flow, (state, Flow{response, mapped, stopped}))
    case Fail{error}:
      transforms.failure(~S, ~K, ~E, ~mapper, ~validate, mapped, state, config, error)

def finish(
  ~S: Type, ~K: Data, ~E: Data,
  ~mapper: S -> K -> E -> IO(S & Result<&2, &1, E, Http.Res>),
  ~validate: Http.Res -> Result<&2, &1, E, Http.Res>,
  config: K, result: S & Flow
) -> IO(S & Flow):
  (state, Flow{response, mapped, stopped}) = result
  finish.checked(~S, ~K, ~E, ~mapper, ~validate, state, config, mapped, stopped, validate(response))

def response(~S: Type, result: S & Flow) -> S & Http.Res:
  (state, Flow{response, mapped, stopped}) = result
  (state, response)
