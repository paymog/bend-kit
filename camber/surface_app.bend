# Typed application example: no channels, workers, or resource-acquisition protocol.
import Base
import ../http/http.bend as Http
import ../json/json.bend as Json
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import ./ownership.bend as Users
import ./interface_check.bend as Registry
import ./surface.bend as Surface
import ./response.bend as Response
import ../router/router.bend as Router

type Hook is Data:
  RootAfter{}
  UsersFirst{}
  UsersSecond{}
  DocumentFirst{}
  DocumentSecond{}
  PublicAfter{}
  PingAfter{}

type Stage is Data:
  Before{scope: U32, ordinal: U32}
  Decode{}
  Handle{}
  MapError{error: Err}
  Transform{hook: Hook}

type State is Type:
  State{journal: File, events: List<&2, Stage>}

type Document is Type:
  Document{principal: Users.Principal, value: Json.Val}

type Err is Data:
  BadDocument{}
  Unauthorized{}
  Forbidden{}
  Unsupported{}
  Missing{}
  BadTarget{}
  NoMethod{allow: String}
  WriteFailed{}
  TransformFailed{}
  InvalidResponse{}

type MapperMode is Data:
  Normal{}
  Failing{}
  Invalid{}

type Config is Data:
  Config{root: Surface.Policy<Hook>, users: Surface.Policy<Hook>, document: Surface.Policy<Hook>, public: Surface.Policy<Hook>, ping: Surface.Policy<Hook>, fault: String, mapper: MapperMode}

type Action is Data:
  Upload{}
  Ping{}

def Application() -> Data:
  Registry.Plan<Action, Config>

def application(fault: String, mapper: MapperMode) -> IO(Application):
  Registry.build(~Action, ~Config, [Router.Entry{"POST", "/documents", Upload{}, [1]}, Router.Entry{"GET", "/public", Ping{}, [2]}], Config{Surface.policy(~Hook, [RootAfter{}]), Surface.policy(~Hook, [UsersFirst{}, UsersSecond{}]), Surface.policy(~Hook, [DocumentFirst{}, DocumentSecond{}]), Surface.policy(~Hook, [PublicAfter{}]), Surface.policy(~Hook, [PingAfter{}]), fault, mapper})

def record(state: State, event: Stage) -> State:
  State{journal, events} = state
  State{journal, event <> events}

def settings(app: Application) -> Config:
  Registry.Plan{entries, config} = app
  config

def policy.root(config: Config) -> Surface.Policy<Hook>:
  Config{root, users, document, public, ping, fault, mode} = config
  root

def policy.users(config: Config) -> Surface.Policy<Hook>:
  Config{root, users, document, public, ping, fault, mode} = config
  users

def policy.document(config: Config) -> Surface.Policy<Hook>:
  Config{root, users, document, public, ping, fault, mode} = config
  document

def policy.public(config: Config) -> Surface.Policy<Hook>:
  Config{root, users, document, public, ping, fault, mode} = config
  public

def policy.ping(config: Config) -> Surface.Policy<Hook>:
  Config{root, users, document, public, ping, fault, mode} = config
  ping

def error_response(error: Err) -> Http.Res:
  match error:
    case BadDocument{}:
      Http.Res{400, Http.empty(), Http.from_string("invalid document")}
    case Unauthorized{}:
      Http.Res{401, Http.set(Http.empty(), "www-authenticate", "Bearer"), Http.from_string("")}
    case Forbidden{}:
      Http.Res{403, Http.empty(), Http.from_string("forbidden")}
    case Unsupported{}:
      Http.Res{415, Http.empty(), Http.from_string("unsupported media type")}
    case Missing{}:
      Http.Res{404, Http.empty(), Http.from_string("not found")}
    case BadTarget{}:
      Http.Res{400, Http.empty(), Http.from_string("invalid target")}
    case NoMethod{allow}:
      Http.Res{405, Http.set(Http.empty(), "allow", allow), Http.from_string("")}
    case WriteFailed{}:
      Http.Res{503, Http.empty(), Http.from_string("store unavailable")}
    case TransformFailed{}:
      Http.Res{500, Http.empty(), Http.from_string("transform failed")}
    case InvalidResponse{}:
      Http.Res{500, Http.empty(), Http.from_string("invalid response")}

def mapper.mode(mode: MapperMode, state: State, error: Err) -> IO(State & Result<&2, &1, Err, Http.Res>):
  match mode:
    case Normal{}:
      IO.pure(State & Result<&2, &1, Err, Http.Res>, (state, Done{error_response(error)}))
    case Failing{}:
      IO.pure(State & Result<&2, &1, Err, Http.Res>, (state, Fail{WriteFailed{}}))
    case Invalid{}:
      IO.pure(State & Result<&2, &1, Err, Http.Res>, (state, Done{Http.Res{99, Http.empty(), Http.from_string("private diagnostics")}}))

def mapper.config(config: Config, state: State, +error: Err) -> IO(State & Result<&2, &1, Err, Http.Res>):
  Config{root, users, document, public, ping, fault, mode} = config
  mapper.mode(mode, record(state, MapError{error}), error)

def mapper(state: State, app: Application, error: Err) -> IO(State & Result<&2, &1, Err, Http.Res>):
  mapper.config(settings(app), state, error)

def validate.checked(valid: Bool, response: Http.Res) -> Result<&2, &1, Err, Http.Res>:
  match valid:
    case True{}:
      Done{response}
    case False{}:
      Fail{InvalidResponse{}}

def validate(response: Http.Res) -> Result<&2, &1, Err, Http.Res>:
  Http.Res{+status, +headers, body} = response
  validate.checked(Response.valid(status, headers), Http.Res{status, headers, body})

def hook.name(hook: Hook) -> String:
  match hook:
    case RootAfter{}:
      "root"
    case UsersFirst{}:
      "users/first"
    case UsersSecond{}:
      "users/second"
    case DocumentFirst{}:
      "document/first"
    case DocumentSecond{}:
      "document/second"
    case PublicAfter{}:
      "public"
    case PingAfter{}:
      "ping"

def hook.header(hook: Hook) -> String:
  match hook:
    case RootAfter{}:
      "x-root-policy"
    case UsersFirst{}:
      "x-users-policy"
    case UsersSecond{}:
      "x-users-policy"
    case DocumentFirst{}:
      "x-document-policy"
    case DocumentSecond{}:
      "x-document-policy"
    case PublicAfter{}:
      "x-public-policy"
    case PingAfter{}:
      "x-ping-policy"

def after.changed(invalid: Bool, hook: Hook, response: Http.Res) -> Http.Res:
  Http.Res{status, headers, body} = response
  Http.Res{Bool.pick(U32, invalid, 99, status), Http.set(headers, hook.header(hook), "yes"), body}

def after.fault(fail: Bool, invalid: Bool, state: State, hook: Hook, response: Http.Res) -> IO(State & Result<&2, &1, Err, Http.Res>):
  match fail:
    case True{}:
      IO.pure(State & Result<&2, &1, Err, Http.Res>, (state, Fail{TransformFailed{}}))
    case False{}:
      IO.pure(State & Result<&2, &1, Err, Http.Res>, (state, Done{after.changed(invalid, hook, response)}))

def after.unsafe(kind: U32, response: Http.Res) -> Http.Res:
  match kind:
    case 0:
      Http.Res{status, headers, body} = response
      Http.Res{status, Http.set(headers, "x-unsafe", "private\r\ninjected: yes"), body}
    case 1:
      Http.Res{status, headers, body} = response
      Http.Res{status, Http.set(headers, "transfer-encoding", "chunked"), body}
    case _:
      Http.Res{status, headers, body} = response
      Http.Res{status, Http.set(headers, "Content-Length", "999"), body}

def after.root(hook: Hook, kind: U32, response: Http.Res) -> Http.Res:
  match hook:
    case RootAfter{}:
      after.unsafe(kind, response)
    case _:
      response

def after.inject(fault: String, hook: Hook, response: Http.Res) -> Http.Res:
  match fault:
    case "header/root":
      after.root(hook, 0, response)
    case "framing/root":
      after.root(hook, 1, response)
    case "name/root":
      after.root(hook, 2, response)
    case _:
      response

def after.config(config: Config, +hook: Hook, state: State, response: Http.Res) -> IO(State & Result<&2, &1, Err, Http.Res>):
  Config{root, users, document, public, ping, +fault, mode} = config
  after.fault(String.eq(fault, hook.name(hook)), String.eq(fault, "invalid/" ++ hook.name(hook)), record(state, Transform{hook}), hook, after.inject(fault, hook, response))

def after(hook: Hook, state: State, app: Application, response: Http.Res) -> IO(State & Result<&2, &1, Err, Http.Res>):
  after.config(settings(app), hook, state, response)

def root_before(state: State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(State & Surface.Step<Err, Unit>):
  IO.pure(State & Surface.Step<Err, Unit>, (record(state, Before{0, 1}), Surface.Continue{Unit{}}))

def authenticated(state: State, principal: Maybe<&2, Users.Principal>) -> IO(State & Surface.Step<Err, Users.Principal>):
  match principal:
    case None{}:
      IO.pure(State & Surface.Step<Err, Users.Principal>, (state, Surface.Reject{Unauthorized{}}))
    case Some{actor}:
      IO.pure(State & Surface.Step<Err, Users.Principal>, (state, Surface.Continue{actor}))

def authenticate(state: State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(State & Surface.Step<Err, Users.Principal>):
  Registry.Metadata{method, target, headers} = meta
  authenticated(record(state, Before{1, 1}), Users.auth(Http.header(headers, "authorization")))

def group.checked(control: String, state: State, actor: Users.Principal) -> IO(State & Surface.Step<Err, Users.Principal>):
  match control:
    case "early":
      IO.pure(State & Surface.Step<Err, Users.Principal>, (state, Surface.Early{Http.Res{409, Http.empty(), Http.from_string("closed")}}))
    case "reject":
      IO.pure(State & Surface.Step<Err, Users.Principal>, (state, Surface.Reject{Forbidden{}}))
    case _:
      IO.pure(State & Surface.Step<Err, Users.Principal>, (state, Surface.Continue{actor}))

def group_check(state: State, app: Application, meta: Registry.Metadata, actor: Users.Principal) -> IO(State & Surface.Step<Err, Users.Principal>):
  Registry.Metadata{method, target, headers} = meta
  group.checked(Http.header(headers, "x-group-control"), record(state, Before{1, 2}), actor)

def users_before(state: State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(State & Surface.Step<Err, Users.Principal>):
  Surface.before(~State, ~Application, ~Err, ~Unit, ~Users.Principal, ~Users.Principal, ~authenticate, ~group_check, state, app, meta, context)

def route_before(state: State, app: Application, meta: Registry.Metadata, actor: Users.Principal) -> IO(State & Surface.Step<Err, Users.Principal>):
  IO.pure(State & Surface.Step<Err, Users.Principal>, (record(state, Before{2, 1}), Surface.Continue{actor}))

def public_before(state: State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(State & Surface.Step<Err, Unit>):
  IO.pure(State & Surface.Step<Err, Unit>, (record(state, Before{3, 1}), Surface.Continue{Unit{}}))

def quiet_before(state: State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(State & Surface.Step<Err, Unit>):
  IO.pure(State & Surface.Step<Err, Unit>, (state, Surface.Continue{Unit{}}))

def document.key_equal(result: Http.Body & Http.Body & Bool) -> Bool:
  (left, right, equal) = result
  equal

def document.key(valid: Bool, state: State, actor: Users.Principal, value: Json.Val) -> IO(State & Result<&2, &1, Err, Document>):
  match valid:
    case True{}:
      IO.pure(State & Result<&2, &1, Err, Document>, (state, Done{Document{actor, value}}))
    case False{}:
      IO.pure(State & Result<&2, &1, Err, Document>, (state, Fail{BadDocument{}}))

def document.fields(fields: List<&1, Http.Body & Json.Val>, state: State, actor: Users.Principal) -> IO(State & Result<&2, &1, Err, Document>):
  match fields:
    case (key, value) <> Nil{}:
      document.key(document.key_equal(Bytes.eq(key, Json.utf8("doc"))), state, actor, value)
    case _:
      IO.pure(State & Result<&2, &1, Err, Document>, (state, Fail{BadDocument{}}))

def document.value(parsed: Maybe<&1, Json.Val>, state: State, actor: Users.Principal) -> IO(State & Result<&2, &1, Err, Document>):
  match parsed:
    case Some{Json.Obj{fields}}:
      document.fields(fields, state, actor)
    case _:
      IO.pure(State & Result<&2, &1, Err, Document>, (state, Fail{BadDocument{}}))

def document.media(supported: Bool, state: State, actor: Users.Principal, body: Http.Body) -> IO(State & Result<&2, &1, Err, Document>):
  match supported:
    case False{}:
      IO.pure(State & Result<&2, &1, Err, Document>, (state, Fail{Unsupported{}}))
    case True{}:
      document.value(Json.parse.bytes(body), record(state, Decode{}), actor)

def decode(state: State, app: Application, meta: Registry.Metadata, actor: Users.Principal, body: Http.Body) -> IO(State & Result<&2, &1, Err, Document>):
  Registry.Metadata{method, target, headers} = meta
  document.media(String.eq(Http.header(headers, "content-type"), "application/json"), state, actor, body)

def written(events: List<&2, Stage>, actor: Users.Principal, value: Json.Val, result: File & Result<&1, &1, U32 & String, Unit>) -> IO(State & Result<&2, &1, Err, Http.Res>):
  Users.Principal{id} = actor
  (journal, outcome) = result
  match outcome:
    case Fail{error}:
      IO.pure(State & Result<&2, &1, Err, Http.Res>, (State{journal, events}, Fail{WriteFailed{}}))
    case Done{unit}:
      IO.pure(State & Result<&2, &1, Err, Http.Res>, (State{journal, events}, Done{Users.json(201, Json.Obj{[(Json.utf8("owner"), Json.Num{Http.from_string(U32.show(id))}), (Json.utf8("doc"), value)]})}))

def handle.recorded(state: State, input: Document) -> IO(State & Result<&2, &1, Err, Http.Res>):
  State{journal, events} = state
  Document{actor, value} = input
  Users.Principal{+id} = actor
  do IO<State & Result<&2, &1, Err, Http.Res>>:
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(journal, "{\"owner\":" ++ U32.show(id) ++ "}\n")
    written(events, Users.Principal{id}, value, result)

def handle(state: State, app: Application, input: Document) -> IO(State & Result<&2, &1, Err, Http.Res>):
  handle.recorded(record(state, Handle{}), input)

def document_endpoint(state: State, app: Application, meta: Registry.Metadata, actor: Users.Principal, body: Http.Body) -> IO(State & Surface.Flow):
  Surface.endpoint(~State, ~Application, ~Err, ~Users.Principal, ~Document, ~decode, ~handle, ~mapper, ~validate, state, app, meta, actor, body)

def document_route.go(state: State, +app: Application, meta: Registry.Metadata, actor: Users.Principal, body: Http.Body) -> IO(State & Surface.Flow):
  Surface.scope(~State, ~Application, ~Err, ~Users.Principal, ~Users.Principal, ~Hook, ~route_before, ~document_endpoint, ~after, ~mapper, ~validate, policy.document(settings(app)), state, app, meta, actor, body)

def document_route(state: State, app: Application, meta: Registry.Metadata, actor: Users.Principal, body: Http.Body) -> IO(State & Surface.Flow):
  document_route.go(state, app, meta, actor, body)

def users_group.go(state: State, +app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  Surface.scope(~State, ~Application, ~Err, ~Unit, ~Users.Principal, ~Hook, ~users_before, ~document_route, ~after, ~mapper, ~validate, policy.users(settings(app)), state, app, meta, context, body)

def users_group(state: State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  users_group.go(state, app, meta, context, body)

def ping_endpoint(state: State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  IO.pure(State & Surface.Flow, (state, Surface.Flow{Http.Res{200, Http.empty(), Http.from_string("public")}, False{}, False{}}))

def ping_route.go(state: State, +app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  Surface.scope(~State, ~Application, ~Err, ~Unit, ~Unit, ~Hook, ~quiet_before, ~ping_endpoint, ~after, ~mapper, ~validate, policy.ping(settings(app)), state, app, meta, context, body)

def ping_route(state: State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  ping_route.go(state, app, meta, context, body)

def public_group.go(state: State, +app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  Surface.scope(~State, ~Application, ~Err, ~Unit, ~Unit, ~Hook, ~public_before, ~ping_route, ~after, ~mapper, ~validate, policy.public(settings(app)), state, app, meta, context, body)

def public_group(state: State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  public_group.go(state, app, meta, context, body)

type Generated is Data:
  Generated{options: Bool, allow: String}

def generated.terminal(options: Bool, allow: String, state: State, app: Application) -> IO(State & Surface.Flow):
  match options:
    case True{}:
      IO.pure(State & Surface.Flow, (state, Surface.Flow{Http.Res{204, Http.set(Http.empty(), "allow", allow), Http.from_string("")}, False{}, False{}}))
    case False{}:
      Surface.failed(~State, ~Application, ~Err, ~mapper, ~validate, state, app, NoMethod{allow}, False{})

def generated.endpoint(state: State, app: Application, meta: Registry.Metadata, decision: Generated, body: Http.Body) -> IO(State & Surface.Flow):
  Generated{options, allow} = decision
  generated.terminal(options, allow, state, app)

def generated.checked(~C: Type, decision: Generated, result: State & Surface.Step<Err, C>) -> State & Surface.Step<Err, Generated>:
  (state, step) = result
  match step:
    case Surface.Continue{context}:
      (state, Surface.Continue{decision})
    case Surface.Early{response}:
      (state, Surface.Early{response})
    case Surface.Reject{error}:
      (state, Surface.Reject{error})

def generated.users_enter(state: State, app: Application, meta: Registry.Metadata, decision: Generated) -> IO(State & Surface.Step<Err, Generated>):
  do IO<State & Surface.Step<Err, Generated>>:
    result : State & Surface.Step<Err, Users.Principal> <- users_before(state, app, meta, Unit{})
    return generated.checked(~Users.Principal, decision, result)

def generated.public_enter(state: State, app: Application, meta: Registry.Metadata, decision: Generated) -> IO(State & Surface.Step<Err, Generated>):
  do IO<State & Surface.Step<Err, Generated>>:
    result : State & Surface.Step<Err, Unit> <- public_before(state, app, meta, Unit{})
    return generated.checked(~Unit, decision, result)

def generated.group(groups: List<&2, U32>, state: State, +app: Application, meta: Registry.Metadata, decision: Generated, body: Http.Body) -> IO(State & Surface.Flow):
  match groups:
    case Nil{}:
      generated.endpoint(state, app, meta, decision, body)
    case 1 <> Nil{}:
      Surface.scope(~State, ~Application, ~Err, ~Generated, ~Generated, ~Hook, ~generated.users_enter, ~generated.endpoint, ~after, ~mapper, ~validate, policy.users(settings(app)), state, app, meta, decision, body)
    case 2 <> Nil{}:
      Surface.scope(~State, ~Application, ~Err, ~Generated, ~Generated, ~Hook, ~generated.public_enter, ~generated.endpoint, ~after, ~mapper, ~validate, policy.public(settings(app)), state, app, meta, decision, body)
    case _:
      IO.die(State & Surface.Flow, 1, "unknown fixture route group")

def chosen(action: Router.Choice<Action>, state: State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  match action:
    case Router.NotFound{}:
      Surface.failed(~State, ~Application, ~Err, ~mapper, ~validate, state, app, Missing{}, False{})
    case Router.Found{Upload{}, params, groups, method, pattern}:
      users_group(state, app, meta, context, body)
    case Router.Found{Ping{}, params, groups, method, pattern}:
      public_group(state, app, meta, context, body)
    case Router.MethodMissing{groups, allow}:
      generated.group(groups, state, app, meta, Generated{False{}, allow}, body)
    case Router.Options{groups, allow}:
      generated.group(groups, state, app, meta, Generated{True{}, allow}, body)

def root.resolved(result: Result<&2, &2, Router.Error, Router.Resolved<Action>>, state: State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  match result:
    case Fail{error}:
      Surface.failed(~State, ~Application, ~Err, ~mapper, ~validate, state, app, BadTarget{}, False{})
    case Done{Router.Resolved{target, action}}:
      chosen(action, state, app, Registry.with_target(target, meta), context, body)

def root_inside.go(state: State, +app: Application, +meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  Registry.Plan{table, config} = app
  Registry.Metadata{method, target, headers} = meta
  root.resolved(Router.resolve(~Action, table, method, target), state, app, meta, context, body)

def root_inside(state: State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(State & Surface.Flow):
  root_inside.go(state, app, meta, context, body)

def dispatch(state: State, +app: Application, req: Http.Req) -> IO(State & Http.Res):
  Http.Req{method, target, headers, body} = req
  do IO<State & Http.Res>:
    result : State & Surface.Flow <- Surface.scope(~State, ~Application, ~Err, ~Unit, ~Unit, ~Hook, ~root_before, ~root_inside, ~after, ~mapper, ~validate, policy.root(settings(app)), state, app, Registry.Metadata{method, target, headers}, Unit{}, body)
    checked : State & Surface.Flow <- Surface.finish(~State, ~Application, ~Err, ~mapper, ~validate, app, result)
    return Surface.response(~State, checked)
