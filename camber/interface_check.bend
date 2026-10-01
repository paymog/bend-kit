# Data route descriptions plus a template executor; this is not the prepared-router implementation.
import Base
import ./ownership.bend as Users
import ../http/http.bend as Http
import ../router/router.bend as Router

type Metadata is Data:
  Metadata{method: String, target: String, headers: Map<&2, List<&2, String>>}

type Entry<-R: Data> is Data:
  Entry{method: String, pattern: String, action: R}

type Plan<-R: Data, -C: Data> is Data:
  Plan{entries: List<&2, Entry<R>>, config: C}

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, message)

def choose.next(~R: Data, matched: Maybe<&2, Map<&2, String>>, action: R, later: Unit -> Maybe<&2, R>) -> Maybe<&2, R>:
  match matched:
    case Some{params}:
      Some{action}
    case None{}:
      later(Unit{})

def choose(~R: Data, entries: List<&2, Entry<R>>, +method: String, +target: String) -> Maybe<&2, R>:
  match entries:
    case Nil{}:
      None{}
    case Entry{want, pattern, action} <> rest:
      choose.next(~R, Router.route(want, method, pattern, target), action, u => choose(~R, rest, method, target))

def invoke.chosen(
  ~S: Type, ~R: Data, ~C: Data,
  ~run: R -> C -> S -> Metadata -> Http.Body -> IO(S & Http.Res),
  chosen: Maybe<&2, R>, config: C, state: S, meta: Metadata, body: Http.Body
) -> IO(S & Http.Res):
  match chosen:
    case None{}:
      IO.pure(S & Http.Res, (state, Users.error(Users.NotFound{})))
    case Some{action}:
      run(action, config, state, meta, body)

def invoke.req(
  ~S: Type, ~R: Data, ~C: Data,
  ~run: R -> C -> S -> Metadata -> Http.Body -> IO(S & Http.Res),
  req: Http.Req, entries: List<&2, Entry<R>>, config: C, state: S
) -> IO(S & Http.Res):
  Http.Req{+method, +target, +headers, body} = req
  invoke.chosen(~S, ~R, ~C, ~run, choose(~R, entries, method, target), config, state, Metadata{method, target, headers}, body)

def invoke(
  ~S: Type, ~R: Data, ~C: Data,
  ~run: R -> C -> S -> Metadata -> Http.Body -> IO(S & Http.Res),
  plan: Plan<R, C>, state: S, req: Http.Req
) -> IO(S & Http.Res):
  Plan{entries, config} = plan
  invoke.req(~S, ~R, ~C, ~run, req, entries, config, state)

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

def run.user(action: Action, store: Users.Store, req: Http.Req) -> IO(Users.Store & Http.Res):
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
      Users.dispatch(store, req)

def label.result(config: Config, result: Users.Store & Http.Res) -> Users.Store & Http.Res:
  Config{label} = config
  (store, res) = result
  Http.Res{status, headers, body} = res
  (store, Http.Res{status, Http.set(headers, "x-app", label), body})

def run(action: Action, config: Config, store: Users.Store, meta: Metadata, body: Http.Body) -> IO(Users.Store & Http.Res):
  Metadata{method, target, headers} = meta
  do IO<Users.Store & Http.Res>:
    result : Users.Store & Http.Res <- run.user(action, store, Http.Req{method, target, headers, body})
    return label.result(config, result)

def application(label: String) -> Plan<Action, Config>:
  Plan{[
    Entry{"GET", "/health", Health{}},
    Entry{"GET", "/users/me", Me{}},
    Entry{"GET", "/alias", Me{}},
    Entry{"GET", "/users/:id", Lookup{}},
    Entry{"POST", "/users", Create{}},
    Entry{"POST", "/echo", Echo{}}
  ], Config{label}}

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
  +alpha = application("alpha")
  +beta = application("beta")
  do IO<Unit>:
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
    Users.close(s9)
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
