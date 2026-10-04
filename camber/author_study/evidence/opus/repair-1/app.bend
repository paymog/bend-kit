import Base
import ../contract.bend as Contract
import ./domain.bend as Domain
import ../../../http/http.bend as Http
import ../../../json/json.bend as Json
import ../../../encoding/encoding.bend as Enc
import ../../../router/router.bend as Router
import ../../ownership.bend as Users
import ../../interface_check.bend as Registry
import ../../surface.bend as Surface
import ../../response.bend as Response

type Hook is Data:
  RootAfter{}
  ProtectedAfter{}
  PublishAfter{}
  PublicAfter{}

type Err is Data:
  Unauthorized{}
  BadInput{}
  Unsupported{}
  WriteFailed{}
  Missing{}
  BadTarget{}
  NoMethod{allow: String}
  InvalidResponse{}

type Config is Data:
  Config{root: Surface.Policy<Hook>, protected: Surface.Policy<Hook>, publish: Surface.Policy<Hook>, public: Surface.Policy<Hook>}

type Action is Data:
  Publish{}
  Listing{}

# Input fields seen so far; ok turns False on a duplicate, unknown, or wrongly typed field.
type Slots is Data:
  Slots{title: Maybe<&2, String>, secret: Maybe<&2, String>, published: Maybe<&2, Bool>, ok: Bool}

def Application() -> Data:
  Registry.Plan<Action, Config>

def application() -> IO(Application):
  Registry.build(~Action, ~Config, [Router.Entry{"POST", "/publish", Publish{}, [1]}, Router.Entry{"GET", "/public", Listing{}, [2]}], Config{Surface.policy(~Hook, [RootAfter{}]), Surface.policy(~Hook, [ProtectedAfter{}]), Surface.policy(~Hook, [PublishAfter{}]), Surface.policy(~Hook, [PublicAfter{}])})

def note(state: Contract.State, event: String) -> Contract.State:
  Contract.State{journal, events} = state
  Contract.State{journal, event <> events}

def settings(app: Application) -> Config:
  Registry.Plan{table, config} = app
  config

def policy.root(config: Config) -> Surface.Policy<Hook>:
  Config{root, protected, publish, public} = config
  root

def policy.protected(config: Config) -> Surface.Policy<Hook>:
  Config{root, protected, publish, public} = config
  protected

def policy.publish(config: Config) -> Surface.Policy<Hook>:
  Config{root, protected, publish, public} = config
  publish

def policy.public(config: Config) -> Surface.Policy<Hook>:
  Config{root, protected, publish, public} = config
  public

def plain(status: U32, body: String) -> Http.Res:
  Http.Res{status, Http.empty(), Http.from_string(body)}

def mapped(error: Err, state: Contract.State) -> Contract.State & Result<&2, &1, Err, Http.Res>:
  match error:
    case Unauthorized{}:
      (note(state, "map/unauthorized"), Done{Http.Res{401, Http.set(Http.empty(), "www-authenticate", "Bearer"), Http.from_string("")}})
    case BadInput{}:
      (note(state, "map/input"), Done{plain(400, "invalid input")})
    case Unsupported{}:
      (note(state, "map/media"), Done{plain(415, "unsupported media type")})
    case WriteFailed{}:
      (note(state, "map/write"), Done{plain(503, "store unavailable")})
    case Missing{}:
      (state, Done{plain(404, "not found")})
    case BadTarget{}:
      (state, Done{plain(400, "invalid target")})
    case NoMethod{allow}:
      (state, Done{Http.Res{405, Http.set(Http.empty(), "allow", allow), Http.from_string("")}})
    case InvalidResponse{}:
      (state, Done{plain(500, "invalid response")})

def mapper(state: Contract.State, app: Application, error: Err) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  IO.pure(Contract.State & Result<&2, &1, Err, Http.Res>, mapped(error, state))

def validate.checked(valid: Bool, response: Http.Res) -> Result<&2, &1, Err, Http.Res>:
  match valid:
    case True{}:
      Done{response}
    case False{}:
      Fail{InvalidResponse{}}

def validate(response: Http.Res) -> Result<&2, &1, Err, Http.Res>:
  Http.Res{+status, +headers, body} = response
  validate.checked(Response.valid(status, headers), Http.Res{status, headers, body})

def after.mark(event: String, header: String, state: Contract.State, response: Http.Res) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  Http.Res{status, headers, body} = response
  IO.pure(Contract.State & Result<&2, &1, Err, Http.Res>, (note(state, event), Done{Http.Res{status, Http.set(headers, header, "yes"), body}}))

def after(hook: Hook, state: Contract.State, app: Application, response: Http.Res) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  match hook:
    case RootAfter{}:
      after.mark("root-after", "x-root-policy", state, response)
    case ProtectedAfter{}:
      after.mark("protected-after", "x-protected-policy", state, response)
    case PublishAfter{}:
      after.mark("publish-after", "x-publish-policy", state, response)
    case PublicAfter{}:
      after.mark("public-after", "x-public-policy", state, response)

def root_before(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(Contract.State & Surface.Step<Err, Unit>):
  IO.pure(Contract.State & Surface.Step<Err, Unit>, (note(state, "root-before"), Surface.Continue{Unit{}}))

def authenticated(state: Contract.State, principal: Maybe<&2, Users.Principal>) -> IO(Contract.State & Surface.Step<Err, Users.Principal>):
  match principal:
    case None{}:
      IO.pure(Contract.State & Surface.Step<Err, Users.Principal>, (state, Surface.Reject{Unauthorized{}}))
    case Some{actor}:
      IO.pure(Contract.State & Surface.Step<Err, Users.Principal>, (state, Surface.Continue{actor}))

def authenticate(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(Contract.State & Surface.Step<Err, Users.Principal>):
  Registry.Metadata{method, target, headers} = meta
  authenticated(note(state, "auth"), Users.auth(Http.header(headers, "authorization")))

def publish_enter(state: Contract.State, app: Application, meta: Registry.Metadata, actor: Users.Principal) -> IO(Contract.State & Surface.Step<Err, Users.Principal>):
  IO.pure(Contract.State & Surface.Step<Err, Users.Principal>, (state, Surface.Continue{actor}))

def public_before(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(Contract.State & Surface.Step<Err, Unit>):
  IO.pure(Contract.State & Surface.Step<Err, Unit>, (note(state, "public-before"), Surface.Continue{Unit{}}))

def text(value: Json.Val) -> Maybe<&2, String>:
  match value:
    case Json.Str{bytes}:
      Some{Enc.utf8.decode(bytes)}
    case _:
      None{}

def flag(value: Json.Val) -> Maybe<&2, Bool>:
  match value:
    case Json.Flag{on}:
      Some{on}
    case _:
      None{}

# The slot after one more field, and whether that field was acceptable: empty before, well typed now.
def fill(~A: Data, old: Maybe<&2, A>, got: Maybe<&2, A>) -> Maybe<&2, A> & Bool:
  match old got:
    case None{} Some{value}:
      (Some{value}, True{})
    case _ _:
      (None{}, False{})

def field.title(secret: Maybe<&2, String>, published: Maybe<&2, Bool>, ok: Bool, filled: Maybe<&2, String> & Bool) -> Slots:
  (kept, fine) = filled
  Slots{kept, secret, published, ok && fine}

def field.secret(title: Maybe<&2, String>, published: Maybe<&2, Bool>, ok: Bool, filled: Maybe<&2, String> & Bool) -> Slots:
  (kept, fine) = filled
  Slots{title, kept, published, ok && fine}

def field.published(title: Maybe<&2, String>, secret: Maybe<&2, String>, ok: Bool, filled: Maybe<&2, Bool> & Bool) -> Slots:
  (kept, fine) = filled
  Slots{title, secret, kept, ok && fine}

def field(name: String, value: Json.Val, slots: Slots) -> Slots:
  match name:
    case "title":
      Slots{title, secret, published, ok} = slots
      field.title(secret, published, ok, fill(~String, title, text(value)))
    case "secret":
      Slots{title, secret, published, ok} = slots
      field.secret(title, published, ok, fill(~String, secret, text(value)))
    case "published":
      Slots{title, secret, published, ok} = slots
      field.published(title, secret, ok, fill(~Bool, published, flag(value)))
    case _:
      Slots{None{}, None{}, None{}, False{}}

def fields(kvs: List<&1, Http.Body & Json.Val>, slots: Slots) -> Slots:
  match kvs:
    case Nil{}:
      slots
    case (key, value) <> rest:
      fields(rest, field(Http.to_string(key), value, slots))

def input.record(slots: Slots, actor: Users.Principal) -> Result<&2, &1, Err, Contract.Record>:
  match slots:
    case Slots{Some{title}, Some{secret}, Some{published}, True{}}:
      Users.Principal{id} = actor
      Done{Contract.Record{id, title, secret, published}}
    case _:
      Fail{BadInput{}}

def input(parsed: Maybe<&1, Json.Val>, actor: Users.Principal) -> Result<&2, &1, Err, Contract.Record>:
  match parsed:
    case Some{Json.Obj{kvs}}:
      input.record(fields(kvs, Slots{None{}, None{}, None{}, True{}}), actor)
    case _:
      Fail{BadInput{}}

def decode.media(supported: Bool, state: Contract.State, actor: Users.Principal, body: Http.Body) -> IO(Contract.State & Result<&2, &1, Err, Contract.Record>):
  match supported:
    case False{}:
      IO.pure(Contract.State & Result<&2, &1, Err, Contract.Record>, (state, Fail{Unsupported{}}))
    case True{}:
      IO.pure(Contract.State & Result<&2, &1, Err, Contract.Record>, (state, input(Json.parse.bytes(body), actor)))

def decode(state: Contract.State, app: Application, meta: Registry.Metadata, actor: Users.Principal, body: Http.Body) -> IO(Contract.State & Result<&2, &1, Err, Contract.Record>):
  Registry.Metadata{method, target, headers} = meta
  decode.media(String.eq(Http.header(headers, "content-type"), "application/json"), note(state, "decode"), actor, body)

# A byte string (one Char per octet) as octets, then a newline.
def octets(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      [10]
    case SCon{Chr{c}, t}:
      c <> octets(t)

def written(events: List<&2, String>, output: Contract.Public, result: File & Result<&1, &1, U32 & String, Unit>) -> Contract.State & Result<&2, &1, Err, Http.Res>:
  (journal, outcome) = result
  match outcome:
    case Fail{error}:
      (Contract.State{journal, events}, Fail{WriteFailed{}})
    case Done{unit}:
      (Contract.State{journal, events}, Done{Http.Res{201, Http.empty(), Domain.encode(output)}})

def handle.recorded(state: Contract.State, input: Contract.Record) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  Contract.State{journal, events} = state
  +output = Domain.view(Domain.publish(input))
  do IO<Contract.State & Result<&2, &1, Err, Http.Res>>:
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write_bytes(journal, octets(Http.to_string(Domain.encode(output))))
    return written(events, output, result)

def handle(state: Contract.State, app: Application, input: Contract.Record) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  handle.recorded(note(state, "handle"), input)

def publish_endpoint(state: Contract.State, app: Application, meta: Registry.Metadata, actor: Users.Principal, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Surface.endpoint(~Contract.State, ~Application, ~Err, ~Users.Principal, ~Contract.Record, ~decode, ~handle, ~mapper, ~validate, state, app, meta, actor, body)

def publish_route.go(state: Contract.State, +app: Application, meta: Registry.Metadata, actor: Users.Principal, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Surface.scope(~Contract.State, ~Application, ~Err, ~Users.Principal, ~Users.Principal, ~Hook, ~publish_enter, ~publish_endpoint, ~after, ~mapper, ~validate, policy.publish(settings(app)), state, app, meta, actor, body)

def publish_route(state: Contract.State, app: Application, meta: Registry.Metadata, actor: Users.Principal, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  publish_route.go(state, app, meta, actor, body)

def protected_group.go(state: Contract.State, +app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Surface.scope(~Contract.State, ~Application, ~Err, ~Unit, ~Users.Principal, ~Hook, ~authenticate, ~publish_route, ~after, ~mapper, ~validate, policy.protected(settings(app)), state, app, meta, context, body)

def protected_group(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  protected_group.go(state, app, meta, context, body)

def public_endpoint(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  IO.pure(Contract.State & Surface.Flow, (note(state, "public-handle"), Surface.Flow{plain(200, "public"), False{}, False{}}))

def public_group.go(state: Contract.State, +app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Surface.scope(~Contract.State, ~Application, ~Err, ~Unit, ~Unit, ~Hook, ~public_before, ~public_endpoint, ~after, ~mapper, ~validate, policy.public(settings(app)), state, app, meta, context, body)

def public_group(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  public_group.go(state, app, meta, context, body)

# Misses and generated responses stay in the root scope only.
def chosen(choice: Router.Choice<Action>, state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  match choice:
    case Router.NotFound{}:
      Surface.failed(~Contract.State, ~Application, ~Err, ~mapper, ~validate, state, app, Missing{}, False{})
    case Router.Found{Publish{}, params, groups, method, pattern}:
      protected_group(state, app, meta, context, body)
    case Router.Found{Listing{}, params, groups, method, pattern}:
      public_group(state, app, meta, context, body)
    case Router.MethodMissing{groups, allow}:
      Surface.failed(~Contract.State, ~Application, ~Err, ~mapper, ~validate, state, app, NoMethod{allow}, False{})
    case Router.Options{groups, allow}:
      IO.pure(Contract.State & Surface.Flow, (state, Surface.Flow{Http.Res{204, Http.set(Http.empty(), "allow", allow), Http.from_string("")}, False{}, False{}}))

def root.resolved(result: Result<&2, &2, Router.Error, Router.Resolved<Action>>, state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  match result:
    case Fail{error}:
      Surface.failed(~Contract.State, ~Application, ~Err, ~mapper, ~validate, state, app, BadTarget{}, False{})
    case Done{Router.Resolved{target, choice}}:
      chosen(choice, state, app, Registry.with_target(target, meta), context, body)

def root_inside.go(state: Contract.State, +app: Application, +meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Registry.Plan{table, config} = app
  Registry.Metadata{method, target, headers} = meta
  root.resolved(Router.resolve(~Action, table, method, target), state, app, meta, context, body)

def root_inside(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  root_inside.go(state, app, meta, context, body)

def dispatch.go(state: Contract.State, +app: Application, req: Http.Req) -> IO(Contract.State & Http.Res):
  Http.Req{method, target, headers, body} = req
  do IO<Contract.State & Http.Res>:
    result : Contract.State & Surface.Flow <- Surface.scope(~Contract.State, ~Application, ~Err, ~Unit, ~Unit, ~Hook, ~root_before, ~root_inside, ~after, ~mapper, ~validate, policy.root(settings(app)), state, app, Registry.Metadata{method, target, headers}, Unit{}, body)
    checked : Contract.State & Surface.Flow <- Surface.finish(~Contract.State, ~Application, ~Err, ~mapper, ~validate, app, result)
    return Surface.response(~Contract.State, checked)

def dispatch(state: Contract.State, app: Application, req: Http.Req) -> IO(Contract.State & Http.Res):
  dispatch.go(state, app, req)
