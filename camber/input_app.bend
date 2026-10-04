# Reusable public-dispatch application: validated domain inputs precede effects.
import Base
import ./camber.bend as C
import ./input.bend as Input
import bend-kit-http@0.25.0.2/http.bend as H
import bend-kit-router@0.2.0.0/target.bend as Target
import bend-kit-json@0.5.1.0/json.bend as J

type Config is Data:
  Config{journal: String, depth: U32}

type Domain is Type:
  Lookup{id: U32, limit: U32, tags: List<&2, String>, empty_keys: List<&2, String>}
  Binary{body: H.Body}
  Text{value: String}
  Document{value: J.Val}
  Number{value: U32}
  Create{name: String}

# The real journal is an effect witness, not an echoed decoder flag.
def journal.closed(pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (file, result) = pair
  do IO<Unit>:
    IO.pass(Unit, result)
    File.close(file)

def journal(config: Config, event: String) -> IO(Unit):
  Config{path, depth} = config
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "a"))
    written : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, event ++ "\n")
    journal.closed(written)

def authenticated(accepted: Bool, state: Unit) -> C.Step<Unit, Unit>:
  match accepted:
    case False{}: C.Early{state, H.Res{401, H.set(H.empty(), "www-authenticate", "Bearer"), H.from_string("")}}
    case True{}: C.Continue{state}

def before(hook: Unit, state: Unit, config: Config, meta: C.Metadata) -> IO(C.Step<Unit, Unit>):
  C.Metadata{method, target, headers} = meta
  do IO<C.Step<Unit, Unit>>:
    journal(config, "auth")
    return authenticated(String.eq(H.header(headers, "authorization"), "Bearer accepted"), state)

def after(hook: Unit, state: Unit, config: Config, response: H.Res) -> IO(Unit & Result<&2, &1, C.Error<Unit>, H.Res>):
  IO.pure(Unit & Result<&2, &1, C.Error<Unit>, H.Res>, (state, Done{response}))

def mapper(state: Unit, config: Config, error: C.Error<Unit>) -> IO(Unit & Result<&2, &1, C.Error<Unit>, H.Res>):
  +settings = config
  do IO<Unit & Result<&2, &1, C.Error<Unit>, H.Res>>:
    journal(settings, "map")
    C.default.mapper(~Unit, ~Config, ~Unit, state, settings, error)

def name.valid(valid: Bool, name: String) -> Result<&2, &1, C.Error<Unit>, Domain>:
  match valid:
    case False{}: Fail{C.Framework{400, ""}}
    case True{}: Done{Create{name}}

def name.text(text: Maybe<&2, String>) -> Result<&2, &1, C.Error<Unit>, Domain>:
  match text:
    case None{}: Fail{C.Framework{400, ""}}
    case Some{+name}:
      name.valid(Nat.is_ge(String.length(name), 1n) && Nat.is_le(String.length(name), 100n), name)

def creation.key(key: Maybe<&2, String>, name: H.Body) -> Result<&2, &1, C.Error<Unit>, Domain>:
  match key:
    case Some{"name"}: name.text(Input.utf8(name))
    case _: Fail{C.Framework{400, ""}}

def creation(value: J.Val) -> Result<&2, &1, C.Error<Unit>, Domain>:
  match value:
    case J.Obj{(key, J.Str{name}) <> Nil{}}:
      creation.key(Input.utf8(key), name)
    case _: Fail{C.Framework{400, ""}}

def decode.limit(values: List<&2, String>) -> Result<&2, &1, C.Error<Unit>, U32>:
  match values:
    case Nil{}: Done{1}
    case head <> rest: C.input(~U32, ~Unit, Input.scalar.values(~U32, ~Input.u32, head <> rest))

def decode.lookup(params: Map<&2, String>, +query: List<&2, Target.Query>) -> Result<&2, &1, C.Error<Unit>, Domain>:
  do Result<&2, &1, C.Error<Unit>, Domain>:
    id : U32 <- C.input(~U32, ~Unit, Input.path(~U32, ~Input.u32, params, "id"))
    limit : U32 <- decode.limit(Input.query.values(query, "limit"))
    tags : List<&2, String> <- C.input(~List<&2, String>, ~Unit, Input.query.list(~String, ~(x => Some{x}), query, "tag"))
    empty_keys : List<&2, String> <- C.input(~List<&2, String>, ~Unit, Input.query.list(~String, ~(x => Some{x}), query, ""))
    return Lookup{id, limit, tags, empty_keys}

def decode.route(pattern: String, params: Map<&2, String>, query: List<&2, Target.Query>, depth: U32, headers: Map<&2, List<&2, String>>, body: H.Body) -> Result<&2, &1, C.Error<Unit>, Domain>:
  match pattern:
    case "/users/:id": decode.lookup(params, query)
    case "/raw":
      do Result<&2, &1, C.Error<Unit>, Domain>:
        bytes : H.Body <- C.input(~H.Body, ~Unit, Input.raw(body))
        return Binary{bytes}
    case "/text":
      do Result<&2, &1, C.Error<Unit>, Domain>:
        text : String <- C.input(~String, ~Unit, Input.text(headers, body))
        return Text{text}
    case "/json":
      do Result<&2, &1, C.Error<Unit>, Domain>:
        value : J.Val <- C.input(~J.Val, ~Unit, Input.json.with_depth(headers, body, depth))
        return Document{value}
    case "/number":
      do Result<&2, &1, C.Error<Unit>, Domain>:
        value : J.Val <- C.input(~J.Val, ~Unit, Input.json.with_depth(headers, body, depth))
        number : U32 <- C.input(~U32, ~Unit, Input.number.u32(value))
        return Number{number}
    case "/create":
      do Result<&2, &1, C.Error<Unit>, Domain>:
        value : J.Val <- C.input(~J.Val, ~Unit, Input.json.with_depth(headers, body, depth))
        creation(value)
    case _: Fail{C.Framework{400, ""}}

def decode(config: Config, selected: C.Match<C.Policy<Unit>>, req: H.Req) -> Result<&2, &1, C.Error<Unit>, Domain>:
  Config{journal, depth} = config
  C.Match{Target.Target{segments, query, authority, star}, params, groups, method, pattern, policies} = selected
  H.Req{verb, target, headers, body} = req
  decode.route(pattern, params, query, depth, headers, body)

def tags(values: List<&2, String>) -> List<&1, J.Val>:
  match values:
    case Nil{}: Nil{}
    case head <> rest: J.Str{J.utf8(head)} <> tags(rest)

def output(input: Domain) -> H.Res:
  match input:
    case Lookup{id, limit, values, empty_keys}:
      C.json(~J.Val, ~(v => v), 200, J.Obj{[(J.utf8("id"), J.Num{J.utf8(U32.show(id))}), (J.utf8("limit"), J.Num{J.utf8(U32.show(limit))}), (J.utf8("tags"), J.Arr{tags(values)}), (J.utf8("empty_keys"), J.Arr{tags(empty_keys)})]})
    case Binary{body}: C.raw(200, body)
    case Text{value}: C.text(200, value)
    case Document{value}: C.json(~J.Val, ~(v => v), 200, value)
    case Number{value}: C.text(200, U32.show(value))
    case Create{name}: C.json(~J.Val, ~(v => v), 201, J.Obj{[(J.utf8("name"), J.Str{J.utf8(name)})]})

def handle(state: Unit, config: Config, input: Domain) -> IO(Unit & Result<&2, &1, C.Error<Unit>, H.Res>):
  do IO<Unit & Result<&2, &1, C.Error<Unit>, H.Res>>:
    journal(config, "business")
    return (state, Done{output(input)})

def run(action: Unit, state: Unit, config: Config, selected: C.Match<C.Policy<Unit>>, req: H.Req) -> IO(Unit & Result<&2, &1, C.Error<Unit>, H.Res>):
  +settings = config
  do IO<Unit & Result<&2, &1, C.Error<Unit>, H.Res>>:
    journal(settings, "decode")
    C.execute(~Domain, ~Unit, ~Config, ~Unit, ~Unit, ~decode, ~handle, state, settings, selected, req)

def application(config: Config) -> Result<&2, &2, C.RegistrationError, C.Application<Unit, Config, C.Policy<Unit>>>:
  +route = C.policy(~Unit, 2, Nil{}, Nil{})
  C.application(~Unit, ~Config, ~C.Policy<Unit>, [C.Route{"GET", "/users/:id", Unit{}, [1], route}, C.Route{"POST", "/raw", Unit{}, [1], route}, C.Route{"POST", "/text", Unit{}, [1], route}, C.Route{"POST", "/json", Unit{}, [1], route}, C.Route{"POST", "/number", Unit{}, [1], route}, C.Route{"POST", "/create", Unit{}, [1], route}], [C.Group{1, [], C.policy(~Unit, 1, [Unit{}], Nil{})}], config, C.policy(~Unit, 0, Nil{}, Nil{}))

def dispatch(app: C.Application<Unit, Config, C.Policy<Unit>>, req: H.Req) -> IO(C.Completion<Unit, Unit>):
  C.dispatch(~Unit, ~Unit, ~Config, ~Unit, ~Unit, ~before, ~after, ~run, ~mapper, app, Unit{}, req)
