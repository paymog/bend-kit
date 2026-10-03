import Base
import ../contract.bend as Contract
import ./domain.bend as Domain
import ../../surface.bend as Surface
import ../../interface_check.bend as Registry
import ../../response.bend as Response
import ../../../http/http.bend as Http
import ../../../json/json.bend as Json
import ../../../encoding/encoding.bend as Enc
import ../../../router/router.bend as Router
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

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
  BadResponse{}

type Owner is Data:
  Owner{id: U32}

type Input is Type:
  Input{record: Contract.Record}

type Action is Data:
  Publish{}
  Public{}

type Config is Data:
  Config{root: Surface.Policy<Hook>, protected: Surface.Policy<Hook>, publish: Surface.Policy<Hook>, public: Surface.Policy<Hook>}

type Seen is Data:
  Seen{title: Maybe<&2, String>, secret: Maybe<&2, String>, published: Maybe<&2, Bool>, bad: Bool}

def Application() -> Data:
  Registry.Plan<Action, Config>

def push(state: Contract.State, event: String) -> Contract.State:
  Contract.State{journal, events} = state
  Contract.State{journal, event <> events}

def settings(+app: Application) -> Config:
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

def hook.header(hook: Hook) -> String:
  match hook:
    case RootAfter{}:
      "x-root-policy"
    case ProtectedAfter{}:
      "x-protected-policy"
    case PublishAfter{}:
      "x-publish-policy"
    case PublicAfter{}:
      "x-public-policy"

def hook.event(hook: Hook) -> String:
  match hook:
    case RootAfter{}:
      "root-after"
    case ProtectedAfter{}:
      "protected-after"
    case PublishAfter{}:
      "publish-after"
    case PublicAfter{}:
      "public-after"

def error_response(error: Err) -> Http.Res:
  match error:
    case Unauthorized{}:
      Http.Res{401, Http.set(Http.empty(), "www-authenticate", "Bearer"), Http.from_string("")}
    case BadInput{}:
      Http.Res{400, Http.empty(), Http.from_string("invalid input")}
    case Unsupported{}:
      Http.Res{415, Http.empty(), Http.from_string("unsupported media type")}
    case WriteFailed{}:
      Http.Res{503, Http.empty(), Http.from_string("store unavailable")}
    case BadResponse{}:
      Http.Res{500, Http.empty(), Http.from_string("")}

def map.name(error: Err) -> String:
  match error:
    case Unauthorized{}:
      "map/unauthorized"
    case BadInput{}:
      "map/input"
    case Unsupported{}:
      "map/media"
    case WriteFailed{}:
      "map/write"
    case BadResponse{}:
      "map/response"

def mapper.recorded(state: Contract.State, +error: Err) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  IO.pure(Contract.State & Result<&2, &1, Err, Http.Res>, (push(state, map.name(error)), Done{error_response(error)}))

def mapper(state: Contract.State, app: Application, error: Err) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  mapper.recorded(state, error)

def validate.checked(ok: Bool, response: Http.Res) -> Result<&2, &1, Err, Http.Res>:
  match ok:
    case True{}:
      Done{response}
    case False{}:
      Fail{BadResponse{}}

def validate(response: Http.Res) -> Result<&2, &1, Err, Http.Res>:
  Http.Res{+status, +headers, body} = response
  validate.checked(Response.valid(status, headers), Http.Res{status, headers, body})

def after.go(+hook: Hook, state: Contract.State, response: Http.Res) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  Http.Res{status, headers, body} = response
  IO.pure(Contract.State & Result<&2, &1, Err, Http.Res>, (push(state, hook.event(hook)), Done{Http.Res{status, Http.set(headers, hook.header(hook), "yes"), body}}))

def after(hook: Hook, state: Contract.State, app: Application, response: Http.Res) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  after.go(hook, state, response)

def authenticate.token(state: Contract.State, token: String) -> IO(Contract.State & Surface.Step<Err, Owner>):
  match token:
    case "Bearer alice":
      IO.pure(Contract.State & Surface.Step<Err, Owner>, (state, Surface.Continue{Owner{7}}))
    case "Bearer bob":
      IO.pure(Contract.State & Surface.Step<Err, Owner>, (state, Surface.Continue{Owner{8}}))
    case _:
      IO.pure(Contract.State & Surface.Step<Err, Owner>, (state, Surface.Reject{Unauthorized{}}))

def authenticate(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(Contract.State & Surface.Step<Err, Owner>):
  Registry.Metadata{method, target, headers} = meta
  authenticate.token(push(state, "auth"), Http.header(headers, "authorization"))

def publish_before(state: Contract.State, app: Application, meta: Registry.Metadata, owner: Owner) -> IO(Contract.State & Surface.Step<Err, Owner>):
  IO.pure(Contract.State & Surface.Step<Err, Owner>, (state, Surface.Continue{owner}))

def public_before(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(Contract.State & Surface.Step<Err, Unit>):
  IO.pure(Contract.State & Surface.Step<Err, Unit>, (push(state, "public-before"), Surface.Continue{Unit{}}))

def root_before(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit) -> IO(Contract.State & Surface.Step<Err, Unit>):
  IO.pure(Contract.State & Surface.Step<Err, Unit>, (push(state, "root-before"), Surface.Continue{Unit{}}))

def take.string(value: Json.Val) -> Maybe<&2, String>:
  match value:
    case Json.Str{s}:
      Some{Enc.utf8.decode(s)}
    case _:
      None{}

def take.bool(value: Json.Val) -> Maybe<&2, Bool>:
  match value:
    case Json.Flag{on}:
      Some{on}
    case _:
      None{}

def put.string.new(got: Maybe<&2, String>) -> Maybe<&2, String> & Bool:
  match got:
    case Some{text}:
      (Some{text}, False{})
    case None{}:
      (None{}, True{})

def put.string(slot: Maybe<&2, String>, got: Maybe<&2, String>) -> Maybe<&2, String> & Bool:
  match slot:
    case Some{old}:
      (Some{old}, True{})
    case None{}:
      put.string.new(got)

def put.bool.new(got: Maybe<&2, Bool>) -> Maybe<&2, Bool> & Bool:
  match got:
    case Some{flag}:
      (Some{flag}, False{})
    case None{}:
      (None{}, True{})

def put.bool(slot: Maybe<&2, Bool>, got: Maybe<&2, Bool>) -> Maybe<&2, Bool> & Bool:
  match slot:
    case Some{old}:
      (Some{old}, True{})
    case None{}:
      put.bool.new(got)

def either(a: Bool, b: Bool) -> Bool:
  match a:
    case True{}:
      True{}
    case False{}:
      b

def field.title.put(updated: Maybe<&2, String> & Bool, secret: Maybe<&2, String>, published: Maybe<&2, Bool>, bad: Bool) -> Seen:
  (title, flag) = updated
  Seen{title, secret, published, either(flag, bad)}

def field.title(seen: Seen, value: Json.Val) -> Seen:
  Seen{title, secret, published, bad} = seen
  field.title.put(put.string(title, take.string(value)), secret, published, bad)

def field.secret.put(title: Maybe<&2, String>, updated: Maybe<&2, String> & Bool, published: Maybe<&2, Bool>, bad: Bool) -> Seen:
  (secret, flag) = updated
  Seen{title, secret, published, either(flag, bad)}

def field.secret(seen: Seen, value: Json.Val) -> Seen:
  Seen{title, secret, published, bad} = seen
  field.secret.put(title, put.string(secret, take.string(value)), published, bad)

def field.published.put(title: Maybe<&2, String>, secret: Maybe<&2, String>, updated: Maybe<&2, Bool> & Bool, bad: Bool) -> Seen:
  (published, flag) = updated
  Seen{title, secret, published, either(flag, bad)}

def field.published(seen: Seen, value: Json.Val) -> Seen:
  Seen{title, secret, published, bad} = seen
  field.published.put(title, secret, put.bool(published, take.bool(value)), bad)

def field.extra(seen: Seen) -> Seen:
  Seen{title, secret, published, bad} = seen
  Seen{title, secret, published, True{}}

def field.key(name: String, value: Json.Val, seen: Seen) -> Seen:
  match name:
    case "title":
      field.title(seen, value)
    case "secret":
      field.secret(seen, value)
    case "published":
      field.published(seen, value)
    case _:
      field.extra(seen)

def fields.go(xs: List<&1, Http.Body & Json.Val>, seen: Seen) -> Seen:
  match xs:
    case Nil{}:
      seen
    case (key, value) <> rest:
      fields.go(rest, field.key(Enc.utf8.decode(key), value, seen))

def accepted.ok(owner: Owner, title: String, secret: String, published: Bool) -> Result<&2, &1, Err, Input>:
  Owner{id} = owner
  Done{Input{Contract.Record{id, title, secret, published}}}

def accepted.flag(owner: Owner, title: String, secret: String, published: Maybe<&2, Bool>) -> Result<&2, &1, Err, Input>:
  match published:
    case None{}:
      Fail{BadInput{}}
    case Some{flag}:
      accepted.ok(owner, title, secret, flag)

def accepted.secret(owner: Owner, title: String, secret: Maybe<&2, String>, published: Maybe<&2, Bool>) -> Result<&2, &1, Err, Input>:
  match secret:
    case None{}:
      Fail{BadInput{}}
    case Some{text}:
      accepted.flag(owner, title, text, published)

def accepted.title(owner: Owner, title: Maybe<&2, String>, secret: Maybe<&2, String>, published: Maybe<&2, Bool>) -> Result<&2, &1, Err, Input>:
  match title:
    case None{}:
      Fail{BadInput{}}
    case Some{text}:
      accepted.secret(owner, text, secret, published)

def accepted.bad(bad: Bool, owner: Owner, title: Maybe<&2, String>, secret: Maybe<&2, String>, published: Maybe<&2, Bool>) -> Result<&2, &1, Err, Input>:
  match bad:
    case True{}:
      Fail{BadInput{}}
    case False{}:
      accepted.title(owner, title, secret, published)

def accepted(owner: Owner, seen: Seen) -> Result<&2, &1, Err, Input>:
  Seen{title, secret, published, bad} = seen
  accepted.bad(bad, owner, title, secret, published)

def decode.object(fields: List<&1, Http.Body & Json.Val>, state: Contract.State, owner: Owner) -> IO(Contract.State & Result<&2, &1, Err, Input>):
  IO.pure(Contract.State & Result<&2, &1, Err, Input>, (state, accepted(owner, fields.go(fields, Seen{None{}, None{}, None{}, False{}}))))

def decode.parsed(parsed: Maybe<&1, Json.Val>, state: Contract.State, owner: Owner) -> IO(Contract.State & Result<&2, &1, Err, Input>):
  match parsed:
    case Some{Json.Obj{fields}}:
      decode.object(fields, state, owner)
    case _:
      IO.pure(Contract.State & Result<&2, &1, Err, Input>, (state, Fail{BadInput{}}))

def decode.media(ok: Bool, state: Contract.State, owner: Owner, body: Http.Body) -> IO(Contract.State & Result<&2, &1, Err, Input>):
  match ok:
    case False{}:
      IO.pure(Contract.State & Result<&2, &1, Err, Input>, (state, Fail{Unsupported{}}))
    case True{}:
      decode.parsed(Json.parse.bytes(body), state, owner)

def decode(state: Contract.State, app: Application, meta: Registry.Metadata, owner: Owner, body: Http.Body) -> IO(Contract.State & Result<&2, &1, Err, Input>):
  Registry.Metadata{method, target, headers} = meta
  decode.media(String.eq(Http.header(headers, "content-type"), "application/json"), push(state, "decode"), owner, body)

def written(events: List<&2, String>, body: Bytes.Bytes, result: File & Result<&1, &1, U32 & String, Unit>) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  (journal, outcome) = result
  match outcome:
    case Fail{error}:
      IO.pure(Contract.State & Result<&2, &1, Err, Http.Res>, (Contract.State{journal, events}, Fail{WriteFailed{}}))
    case Done{unit}:
      IO.pure(Contract.State & Result<&2, &1, Err, Http.Res>, (Contract.State{journal, events}, Done{Http.Res{201, Http.empty(), body}}))

def handle.go(state: Contract.State, record: Contract.Record) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  Contract.State{journal, events} = state
  +shown = Domain.view(Domain.publish(record))
  do IO<Contract.State & Result<&2, &1, Err, Http.Res>>:
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(journal, Enc.utf8.decode(Domain.encode(shown)) ++ "\n")
    written(events, Domain.encode(shown), result)

def handle(state: Contract.State, app: Application, input: Input) -> IO(Contract.State & Result<&2, &1, Err, Http.Res>):
  Input{record} = input
  handle.go(push(state, "handle"), record)

def publish_endpoint(state: Contract.State, app: Application, meta: Registry.Metadata, owner: Owner, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Surface.endpoint(~Contract.State, ~Application, ~Err, ~Owner, ~Input, ~decode, ~handle, ~mapper, ~validate, state, app, meta, owner, body)

def publish_route.go(state: Contract.State, +app: Application, meta: Registry.Metadata, owner: Owner, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Surface.scope(~Contract.State, ~Application, ~Err, ~Owner, ~Owner, ~Hook, ~publish_before, ~publish_endpoint, ~after, ~mapper, ~validate, policy.publish(settings(app)), state, app, meta, owner, body)

def publish_route(state: Contract.State, app: Application, meta: Registry.Metadata, owner: Owner, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  publish_route.go(state, app, meta, owner, body)

def protected_group.go(state: Contract.State, +app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Surface.scope(~Contract.State, ~Application, ~Err, ~Unit, ~Owner, ~Hook, ~authenticate, ~publish_route, ~after, ~mapper, ~validate, policy.protected(settings(app)), state, app, meta, context, body)

def protected_group(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  protected_group.go(state, app, meta, context, body)

def public_run(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  IO.pure(Contract.State & Surface.Flow, (push(state, "public-handle"), Surface.Flow{Http.Res{200, Http.empty(), Http.from_string("public")}, False{}, False{}}))

def public_group.go(state: Contract.State, +app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Surface.scope(~Contract.State, ~Application, ~Err, ~Unit, ~Unit, ~Hook, ~public_before, ~public_run, ~after, ~mapper, ~validate, policy.public(settings(app)), state, app, meta, context, body)

def public_group(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  public_group.go(state, app, meta, context, body)

def bare(state: Contract.State, response: Http.Res) -> IO(Contract.State & Surface.Flow):
  IO.pure(Contract.State & Surface.Flow, (state, Surface.Flow{response, False{}, False{}}))

def chosen(choice: Router.Choice<Action>, state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  match choice:
    case Router.Found{Publish{}, params, groups, method, pattern}:
      protected_group(state, app, meta, context, body)
    case Router.Found{Public{}, params, groups, method, pattern}:
      public_group(state, app, meta, context, body)
    case Router.NotFound{}:
      bare(state, Http.Res{404, Http.empty(), Http.from_string("")})
    case Router.MethodMissing{groups, allow}:
      bare(state, Http.Res{405, Http.set(Http.empty(), "allow", allow), Http.from_string("")})
    case Router.Options{groups, allow}:
      bare(state, Http.Res{204, Http.set(Http.empty(), "allow", allow), Http.from_string("")})

def table.of(app: Application) -> Router.Table<Action>:
  Registry.Plan{table, config} = app
  table

def root.resolved(result: Result<&2, &2, Router.Error, Router.Resolved<Action>>, state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  match result:
    case Fail{error}:
      bare(state, Http.Res{400, Http.empty(), Http.from_string("")})
    case Done{Router.Resolved{target, choice}}:
      chosen(choice, state, app, meta, context, body)

def root_inside.go(state: Contract.State, +app: Application, +meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  Registry.Metadata{+method, +target, +headers} = meta
  root.resolved(Router.resolve(~Action, table.of(app), method, target), state, app, Registry.Metadata{method, target, headers}, context, body)

def root_inside(state: Contract.State, app: Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Contract.State & Surface.Flow):
  root_inside.go(state, app, meta, context, body)

def application() -> IO(Application):
  Registry.build(~Action, ~Config, [
    Router.Entry{"POST", "/publish", Publish{}, [1]},
    Router.Entry{"GET", "/public", Public{}, [2]}
  ], Config{Surface.policy(~Hook, [RootAfter{}]), Surface.policy(~Hook, [ProtectedAfter{}]), Surface.policy(~Hook, [PublishAfter{}]), Surface.policy(~Hook, [PublicAfter{}])})

def dispatch(state: Contract.State, +app: Application, req: Http.Req) -> IO(Contract.State & Http.Res):
  Http.Req{method, target, headers, body} = req
  do IO<Contract.State & Http.Res>:
    result : Contract.State & Surface.Flow <- Surface.scope(~Contract.State, ~Application, ~Err, ~Unit, ~Unit, ~Hook, ~root_before, ~root_inside, ~after, ~mapper, ~validate, policy.root(settings(app)), state, app, Registry.Metadata{method, target, headers}, Unit{}, body)
    checked : Contract.State & Surface.Flow <- Surface.finish(~Contract.State, ~Application, ~Err, ~mapper, ~validate, app, result)
    return Surface.response(~Contract.State, checked)
