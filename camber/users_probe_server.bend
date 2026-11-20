# Published Camber types are distinct from the local regression fixture types.
import Base
import bend-kit-camber@0.16.0.2/camber.bend as C
import bend-kit-http@0.38.6.1/http.bend as H
import ./probe_server.bend as Probe

def prepared(~A: Data, ~S: Type, ~K: Data, ~N: Data,
  ~work: S -> C.Application<A, K, C.Policy<N>> -> C.BufferedRequest -> IO(S & Result<&2, &2, Unit, C.ApplicationReport<N>>),
  ~destroy: S -> IO(Unit), app: C.Application<A, K, C.Policy<N>>, +config: H.ServerConfig, counted: List<S> & Nat
) -> IO(Result<&2, &1, C.StartupError, C.Server<A, S, K, N>>):
  H.ServerConfig{host, port, body, headers, c, a, +buffered, hm, bm, im, wm} = config
  (resources, +capacity) = counted
  do IO<Result<&2, &1, C.StartupError, C.Server<A, S, K, N>>>:
    +messages : Chan(C.Message<S, C.Application<A, K, C.Policy<N>>, C.BufferedRequest, Unit, C.ApplicationReport<N>>) <-
      Chan.new(C.Message<S, C.Application<A, K, C.Policy<N>>, C.BufferedRequest, Unit, C.ApplicationReport<N>>, buffered)
    started : List<S> & Result<&2, &1, H.StartupError, H.Server<C.ServingContext<A, S, K, N>>> <-
      Probe.transport(~C.ServingContext<A, S, K, N>, ~List<S>, C.ServingContext{app, C.Context{messages}}, resources, config)
    C.server.started(~A, ~S, ~K, ~N, ~work, ~destroy, C.Context{messages}, buffered, capacity, started)

def registered(~A: Data, ~S: Type, ~K: Data, ~N: Data,
  ~work: S -> C.Application<A, K, C.Policy<N>> -> C.BufferedRequest -> IO(S & Result<&2, &2, Unit, C.ApplicationReport<N>>),
  ~destroy: S -> IO(Unit), valid: Bool, registration: Result<&2, &2, C.RegistrationError, C.Application<A, K, C.Policy<N>>>,
  config: H.ServerConfig, resources: List<S>
) -> IO(Result<&2, &1, C.StartupError, C.Server<A, S, K, N>>):
  match valid registration resources:
    case True{} Done{app} resource <> rest:
      prepared(~A, ~S, ~K, ~N, ~work, ~destroy, app, config, C.server.bundles(~S, resource <> rest))
    case _ Fail{error} Nil{}:
      C.server.registered(~A, ~S, ~K, ~N, ~work, ~destroy, Fail{error}, config, Nil{})
    case _ Fail{error} resource <> rest:
      C.server.registered(~A, ~S, ~K, ~N, ~work, ~destroy, Fail{error}, config, resource <> rest)
    case _ Done{app} Nil{}:
      C.server.registered(~A, ~S, ~K, ~N, ~work, ~destroy, Done{app}, config, Nil{})
    case False{} Done{app} resource <> rest:
      C.server.registered(~A, ~S, ~K, ~N, ~work, ~destroy, Done{app}, config, resource <> rest)

def start(~A: Data, ~S: Type, ~K: Data, ~E: Data, ~N: Data,
  ~before: N -> S -> K -> C.Metadata -> IO(C.Step<S, E>),
  ~after: N -> S -> K -> H.Res -> IO(S & Result<&2, &1, C.Error<E>, H.Res>),
  ~run: A -> S -> K -> C.Match<C.Policy<N>> -> H.Req -> IO(S & Result<&2, &1, C.Error<E>, H.Res>),
  ~mapper: S -> K -> C.Error<E> -> IO(S & Result<&2, &1, C.Error<E>, H.Res>),
  ~destroy: S -> IO(Unit), registration: Result<&2, &2, C.RegistrationError, C.Application<A, K, C.Policy<N>>>,
  +config: H.ServerConfig, resources: List<S>
) -> IO(Result<&2, &1, C.StartupError, C.Server<A, S, K, N>>):
  registered(~A, ~S, ~K, ~N,
    ~(state => app => input => C.server.work(~A, ~S, ~K, ~E, ~N, ~before, ~after, ~run, ~mapper, state, app, input)),
    ~destroy, H.server.config.valid(config), registration, config, resources)
