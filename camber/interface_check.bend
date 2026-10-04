# Prepared Data routes plus a template executor; this is not Camber's public API.
import Base
import ./ownership.bend as Users
import ../http/http.bend as Http
import ../router/router.bend as Router
import ../router/target.bend as Target

type Metadata is Data:
  Metadata{method: String, target: String, headers: Map<&2, List<&2, String>>}

type Plan<-R: Data, -C: Data> is Data:
  Plan{table: Router.Table<R>, config: C}

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def built(~R: Data, ~C: Data, result: Result<&2, &2, Router.Error, Router.Table<R>>, config: C) -> IO(Plan<R, C>):
  match result:
    case Fail{error}:
      IO.die(Plan<R, C>, 1, "invalid route registration")
    case Done{table}:
      IO.pure(Plan<R, C>, Plan{table, config})

def build(~R: Data, ~C: Data, entries: List<&2, Router.Entry<R>>, config: C) -> IO(Plan<R, C>):
  built(~R, ~C, Router.prepare(~R, entries), config)

def with_authority(authority: Maybe<&2, String>, meta: Metadata) -> Metadata:
  match authority:
    case None{}:
      meta
    case Some{host}:
      Metadata{method, target, headers} = meta
      Metadata{method, target, Http.set(headers, "host", host)}

def with_target(target: Target.Target, meta: Metadata) -> Metadata:
  Target.Target{segments, query, authority, star} = target
  with_authority(authority, meta)

def invoke.choice(
  ~S: Type, ~R: Data, ~C: Data,
  ~run: R -> C -> S -> Metadata -> Map<&2, String> -> Http.Body -> IO(S & Http.Res),
  chosen: Router.Choice<R>, config: C, state: S, meta: Metadata, body: Http.Body
) -> IO(S & Http.Res):
  match chosen:
    case Router.NotFound{}:
      IO.pure(S & Http.Res, (state, Users.error(Users.NotFound{})))
    case Router.MethodMissing{groups, allow}:
      IO.pure(S & Http.Res, (state, Http.Res{405, Http.set(Http.empty(), "allow", allow), Http.from_string("")}))
    case Router.Options{groups, allow}:
      IO.pure(S & Http.Res, (state, Http.Res{204, Http.set(Http.empty(), "allow", allow), Http.from_string("")}))
    case Router.Found{action, params, groups, method, pattern}:
      run(action, config, state, meta, params, body)

def invoke.resolved(
  ~S: Type, ~R: Data, ~C: Data,
  ~run: R -> C -> S -> Metadata -> Map<&2, String> -> Http.Body -> IO(S & Http.Res),
  result: Result<&2, &2, Router.Error, Router.Resolved<R>>, config: C, state: S, meta: Metadata, body: Http.Body
) -> IO(S & Http.Res):
  match result:
    case Fail{error}:
      IO.pure(S & Http.Res, (state, Users.error(Users.BadInput{})))
    case Done{Router.Resolved{target, chosen}}:
      invoke.choice(~S, ~R, ~C, ~run, chosen, config, state, with_target(target, meta), body)

def invoke.req(
  ~S: Type, ~R: Data, ~C: Data,
  ~run: R -> C -> S -> Metadata -> Map<&2, String> -> Http.Body -> IO(S & Http.Res),
  req: Http.Req, table: Router.Table<R>, config: C, state: S
) -> IO(S & Http.Res):
  Http.Req{+method, +target, +headers, body} = req
  invoke.resolved(~S, ~R, ~C, ~run, Router.resolve(~R, table, method, target), config, state, Metadata{method, target, headers}, body)

def invoke(
  ~S: Type, ~R: Data, ~C: Data,
  ~run: R -> C -> S -> Metadata -> Map<&2, String> -> Http.Body -> IO(S & Http.Res),
  plan: Plan<R, C>, state: S, req: Http.Req
) -> IO(S & Http.Res):
  Plan{table, config} = plan
  invoke.req(~S, ~R, ~C, ~run, req, table, config, state)

def plain(req: Http.Req) -> IO(Http.Res):
  Http.Req{method, target, headers, body} = req
  IO.pure(Http.Res, Http.Res{200, Http.empty(), body})

def adapt(~h: Http.Req -> IO(Http.Res), store: Users.Store, req: Http.Req) -> IO(Users.Store & Http.Res):
  do IO<Users.Store & Http.Res>:
    res : Http.Res <- h(req)
    return (store, res)

def gate.result(
  ~S: Type, ~C: Data, ~handler: S -> C -> Http.Body -> IO(S & Http.Res),
  context: Maybe<&2, C>, state: S, body: Http.Body
) -> IO(S & Http.Res):
  match context:
    case None{}:
      IO.pure(S & Http.Res, (state, Users.error(Users.Unauthorized{})))
    case Some{typed}:
      handler(state, typed, body)

def gate(
  ~S: Type, ~Before: Data, ~After: Data,
  ~before: Metadata -> Before -> Maybe<&2, After>,
  ~handler: S -> After -> Http.Body -> IO(S & Http.Res),
  meta: Metadata, context: Before, state: S, body: Http.Body
) -> IO(S & Http.Res):
  gate.result(~S, ~After, ~handler, before(meta, context), state, body)

def authenticate(meta: Metadata, context: Unit) -> Maybe<&2, Users.Principal>:
  Metadata{method, target, headers} = meta
  Users.auth(Http.header(headers, "authorization"))

def principal_me(store: Users.Store, principal: Users.Principal, body: Http.Body) -> IO(Users.Store & Http.Res):
  Users.me(principal, store)

def protected_me(req: Http.Req, store: Users.Store) -> IO(Users.Store & Http.Res):
  Http.Req{method, target, headers, body} = req
  gate(~Users.Store, ~Unit, ~Users.Principal, ~authenticate, ~principal_me, Metadata{method, target, headers}, Unit{}, store, body)

type Action is Data:
  Health{}
  Lookup{}
  Me{}
  Create{}
  Echo{}

type Config is Data:
  Config{label: String}

def run.path(path: Users.Path, store: Users.Store, req: Http.Req) -> IO(Users.Store & Http.Res):
  Http.Req{method, target, headers, body} = req
  Users.dispatch.path(path, store, method, headers, body)

def lookup.auth(principal: Maybe<&2, Users.Principal>, value: String, store: Users.Store) -> IO(Users.Store & Http.Res):
  match principal:
    case None{}:
      IO.pure(Users.Store & Http.Res, (store, Users.error(Users.Unauthorized{})))
    case Some{typed}:
      Users.endpoint.decoded(~U32, ~Users.lookup, store, typed, Users.id(value), 200)

def lookup.value(pair: Map<&2, String> & String, store: Users.Store, req: Http.Req) -> IO(Users.Store & Http.Res):
  (params, value) = pair
  Http.Req{method, target, headers, body} = req
  lookup.auth(Users.auth(Http.header(headers, "authorization")), value, store)

def run.user(action: Action, store: Users.Store, req: Http.Req, params: Map<&2, String>) -> IO(Users.Store & Http.Res):
  match action:
    case Echo{}:
      adapt(~plain, store, req)
    case Health{}:
      run.path(Users.Health{}, store, req)
    case Me{}:
      protected_me(req, store)
    case Create{}:
      run.path(Users.Users{}, store, req)
    case Lookup{}:
      lookup.value(Map.get(String, "", params, "id"), store, req)

def label.result(config: Config, result: Users.Store & Http.Res) -> Users.Store & Http.Res:
  Config{label} = config
  (store, res) = result
  Http.Res{status, headers, body} = res
  (store, Http.Res{status, Http.set(headers, "x-app", label), body})

def run(action: Action, config: Config, store: Users.Store, meta: Metadata, params: Map<&2, String>, body: Http.Body) -> IO(Users.Store & Http.Res):
  Metadata{method, target, headers} = meta
  do IO<Users.Store & Http.Res>:
    result : Users.Store & Http.Res <- run.user(action, store, Http.Req{method, target, headers, body}, params)
    return label.result(config, result)

def application(label: String) -> IO(Plan<Action, Config>):
  build(~Action, ~Config, [
    Router.Entry{"GET", "/health", Health{}, []},
    Router.Entry{"GET", "/users/me", Me{}, []},
    Router.Entry{"GET", "/alias", Me{}, []},
    Router.Entry{"GET", "/users/:id", Lookup{}, []},
    Router.Entry{"POST", "/users", Create{}, []},
    Router.Entry{"POST", "/echo", Echo{}, []}
  ], Config{label})

def req(method: String, path: String, body: String) -> Http.Req:
  Http.Req{method, path, Http.set(Http.set(Http.empty(), "authorization", "Bearer alice"), "content-type", "application/json"), Http.from_string(body)}

def check(result: Users.Store & Http.Res, status: U32, body: String, label: String) -> IO(Users.Store):
  (store, res) = result
  Http.Res{got_status, headers, got_body} = res
  do IO<Users.Store>:
    require(U32.is_eq(got_status, status), "reusable plan returned wrong status")
    require(String.eq(Http.header(headers, "x-app"), label), "runtime configuration leaked between applications")
    require(String.eq(Http.to_string(got_body), body), "reusable plan changed response bytes")
    return store

def exercise(+plan: Plan<Action, Config>, store: Users.Store, request: Http.Req, status: U32, body: String, label: String) -> IO(Users.Store):
  do IO<Users.Store>:
    result : Users.Store & Http.Res <- invoke(~Users.Store, ~Action, ~Config, ~run, plan, store, request)
    check(result, status, body, label)

def scenario(path: String) -> IO(Unit):
  do IO<Unit>:
    +alpha : Plan<Action, Config> <- application("alpha")
    +beta : Plan<Action, Config> <- application("beta")
    s0 : Users.Store <- Users.open(path, "w")
    s1 : Users.Store <- exercise(alpha, s0, req("GET", "/health", ""), 200, "{\"ok\":true}", "alpha")
    s2 : Users.Store <- exercise(beta, s1, req("GET", "/users/me", ""), 200, "{\"id\":7,\"name\":\"Alice\"}", "beta")
    s3 : Users.Store <- exercise(alpha, s2, req("GET", "/users/7", ""), 200, "{\"id\":7,\"name\":\"Alice\"}", "alpha")
    s4 : Users.Store <- exercise(alpha, s3, req("POST", "/users", "{\"name\":\"Cara\"}"), 201, "{\"id\":9,\"name\":\"Cara\"}", "alpha")
    s5 : Users.Store <- exercise(beta, s4, req("POST", "/echo", "\0\u{80}\u{FF}"), 200, "\0\u{80}\u{FF}", "beta")
    s6 : Users.Store <- exercise(alpha, s5, req("GET", "/users/9", ""), 200, "{\"id\":9,\"name\":\"Cara\"}", "alpha")
    s7 : Users.Store <- exercise(beta, s6, req("GET", "/alias", ""), 200, "{\"id\":7,\"name\":\"Alice\"}", "beta")
    s8 : Users.Store <- exercise(alpha, s7, Http.Req{"GET", "/users/me", Http.empty(), Http.from_string("not JSON")}, 401, "", "alpha")
    s9 : Users.Store <- exercise(beta, s8, Http.Req{"GET", "/health", Http.empty(), Http.from_string("")}, 200, "{\"ok\":true}", "beta")
    s10 : Users.Store <- exercise(alpha, s9, req("HEAD", "/users/7", ""), 200, "{\"id\":7,\"name\":\"Alice\"}", "alpha")
    s11 : Users.Store <- exercise(beta, s10, req("HEAD", "http://example.test/users/%37?tag=a&tag=b", ""), 200, "{\"id\":7,\"name\":\"Alice\"}", "beta")
    s12 : Users.Store <- exercise(alpha, s11, req("GET", "/users/m%65", ""), 200, "{\"id\":7,\"name\":\"Alice\"}", "alpha")
    Users.close(s12)
    IO.print("reusable Data plans, typed before hook, runtime config, template executor, plain packed-body handler: PASS")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> path <> Nil{}:
      scenario(path)
    case _:
      IO.die(Unit, 1, "usage: interface_check <temporary-journal-path>")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
