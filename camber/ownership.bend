# Executable application-composition experiment, not Camber's public API or router.
import Base
import ../http/http.bend as Http
import ../json/json.bend as Json
import ../encoding/encoding.bend as Enc
import ../router/router.bend as Router

type Principal is Data:
  Principal{id: U32}

type User is Data:
  User{id: U32, name: String, secret: String}

type Store is Type:
  Store{journal: File, users: List<&2, User>, next: U32}

type Err is Data:
  BadInput{}
  Unauthorized{}
  NotFound{}
  Unsupported{}
  StoreFailed{}

type Path is Data:
  Health{}
  Me{}
  Users{}
  UserId{id: String}
  Missing{}

def json(status: U32, value: Json.Val) -> Http.Res:
  Http.Res{status, Http.set(Http.empty(), "content-type", "application/json"), Json.encode.bytes(value)}

def error(e: Err) -> Http.Res:
  match e:
    case BadInput{}:
      json(400, Json.Obj{[(Json.utf8("error"), Json.Str{Json.utf8("invalid input")})]})
    case Unauthorized{}:
      Http.Res{401, Http.set(Http.empty(), "www-authenticate", "Bearer"), Http.from_string("")}
    case NotFound{}:
      json(404, Json.Obj{[(Json.utf8("error"), Json.Str{Json.utf8("not found")})]})
    case Unsupported{}:
      json(415, Json.Obj{[(Json.utf8("error"), Json.Str{Json.utf8("unsupported media type")})]})
    case StoreFailed{}:
      json(500, Json.Obj{[(Json.utf8("error"), Json.Str{Json.utf8("internal error")})]})

def public(user: User) -> Json.Val:
  User{id, name, secret} = user
  Json.Obj{[(Json.utf8("id"), Json.Num{Http.from_string(U32.show(id))}), (Json.utf8("name"), Json.Str{Json.utf8(name)})]}

def respond.success(status: U32, user: User) -> Http.Res:
  match status:
    case 201:
      User{+id, name, secret} = user
      Http.Res{201, Http.set(Http.set(Http.empty(), "content-type", "application/json"), "location", "/users/" ++ U32.show(id)), Json.encode.bytes(public(User{id, name, secret}))}
    case _:
      json(status, public(user))

def respond(status: U32, result: Result<&2, &2, Err, User>) -> Http.Res:
  match result:
    case Fail{e}:
      error(e)
    case Done{user}:
      respond.success(status, user)

def find.pick(found: Bool, user: User, rest: Unit -> Result<&2, &2, Err, User>) -> Result<&2, &2, Err, User>:
  match found:
    case True{}:
      Done{user}
    case False{}:
      rest(Unit{})

def find(users: List<&2, User>, +id: U32) -> Result<&2, &2, Err, User>:
  match users:
    case Nil{}:
      Fail{NotFound{}}
    case User{+uid, name, secret} <> rest:
      find.pick(U32.is_eq(uid, id), User{uid, name, secret}, u => find(rest, id))

def lookup(store: Store, principal: Principal, id: U32) -> IO(Store & Result<&2, &2, Err, User>):
  Store{journal, +users, next} = store
  IO.pure(Store & Result<&2, &2, Err, User>, (Store{journal, users, next}, find(users, id)))

def create.written(+next: U32, users: List<&2, User>, name: String, result: File & Result<&1, &1, U32 & String, Unit>) -> Store & Result<&2, &2, Err, User>:
  (journal, written) = result
  match written:
    case Fail{e}:
      (Store{journal, users, next}, Fail{StoreFailed{}})
    case Done{u}:
      +user = {User{next, name, "private"} : User}
      (Store{journal, user <> users, (next + 1 : U32)}, Done{user})

def create(store: Store, principal: Principal, name: String) -> IO(Store & Result<&2, &2, Err, User>):
  Store{journal, users, +next} = store
  +name = name
  do IO<Store & Result<&2, &2, Err, User>>:
    written : File & Result<&1, &1, U32 & String, Unit> <- File.write(journal, Enc.utf8.decode(Json.encode.bytes(public(User{next, name, "private"}))) ++ "\n")
    return create.written(next, users, name, written)

def digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{+c, t}:
      Char.is_digit(c) && digits(t)

def id.read(ok: Bool, s: String) -> Maybe<&2, U32>:
  match ok:
    case False{}:
      None{}
    case True{}:
      U32.read(s)

def id(+s: String) -> Maybe<&2, U32>:
  id.read(digits(s), s)

def name.valid(ok: Bool, name: String) -> Maybe<&2, String>:
  match ok:
    case True{}:
      Some{name}
    case False{}:
      None{}

def name.value(v: Json.Val) -> Maybe<&2, String>:
  match v:
    case Json.Str{bytes}:
      +text = Enc.utf8.decode(bytes)
      +n = String.length(text)
      name.valid(Nat.is_ge(n, 1n) && Nat.is_le(n, 100n), text)
    case _:
      None{}

def name.key(ok: Bool, value: Json.Val) -> Maybe<&2, String>:
  match ok:
    case True{}:
      name.value(value)
    case False{}:
      None{}

def name.object(v: Json.Val) -> Maybe<&2, String>:
  match v:
    case Json.Obj{Con{(key, value), Nil{}}}:
      name.key(String.eq(Enc.utf8.decode(key), "name"), value)
    case _:
      None{}

def name.parsed(v: Maybe<&1, Json.Val>) -> Maybe<&2, String>:
  match v:
    case None{}:
      None{}
    case Some{value}:
      name.object(value)

def name(body: Http.Body) -> Maybe<&2, String>:
  name.parsed(Json.parse.bytes(body))

def endpoint.respond(status: U32, result: Store & Result<&2, &2, Err, User>) -> IO(Store & Http.Res):
  (store, outcome) = result
  IO.pure(Store & Http.Res, (store, respond(status, outcome)))

def endpoint.decoded(
  ~I: Data, ~handler: Store -> Principal -> I -> IO(Store & Result<&2, &2, Err, User>),
  store: Store, principal: Principal, input: Maybe<&2, I>, status: U32
) -> IO(Store & Http.Res):
  match input:
    case None{}:
      IO.pure(Store & Http.Res, (store, error(BadInput{})))
    case Some{value}:
      do IO<Store & Http.Res>:
        result : Store & Result<&2, &2, Err, User> <- handler(store, principal, value)
        endpoint.respond(status, result)

def auth(token: String) -> Maybe<&2, Principal>:
  match token:
    case "Bearer alice":
      Some{Principal{7}}
    case "Bearer bob":
      Some{Principal{8}}
    case _:
      None{}

def select.exact(ok: Bool, value: String) -> Path:
  match ok:
    case True{}:
      UserId{value}
    case False{}:
      Missing{}

def select.value(r: Map<&2, String> & String, path: String) -> Path:
  (rest, +value) = r
  select.exact(String.eq(path, "/users/" ++ value), value)

def select.id(m: Maybe<&2, Map<&2, String>>, +path: String) -> Path:
  match m:
    case None{}:
      Missing{}
    case Some{params}:
      select.value(Map.get(String, "", params, "id"), path)

# Fixture selection reuses today's router; target decoding and route registration are not tested here.
def select(+path: String) -> Path:
  match path:
    case "/health":
      Health{}
    case "/users/me":
      Me{}
    case "/users":
      Users{}
    case _:
      select.id(Router.route("GET", "GET", "/users/:id", path), path)

def creation(media: String, store: Store, principal: Principal, body: Http.Body) -> IO(Store & Http.Res):
  match media:
    case "application/json":
      endpoint.decoded(~String, ~create, store, principal, name(body), 201)
    case _:
      IO.pure(Store & Http.Res, (store, error(Unsupported{})))

def me(principal: Principal, store: Store) -> IO(Store & Http.Res):
  Principal{+uid} = principal
  endpoint.decoded(~U32, ~lookup, store, Principal{uid}, Some{uid}, 200)

def route(path: Path, store: Store, principal: Principal, method: String, headers: Map<&2, List<&2, String>>, body: Http.Body) -> IO(Store & Http.Res):
  match path method:
    case Me{} "GET":
      me(principal, store)
    case UserId{value} "GET":
      endpoint.decoded(~U32, ~lookup, store, principal, id(value), 200)
    case Users{} "POST":
      creation(Http.header(headers, "content-type"), store, principal, body)
    case _ _:
      IO.pure(Store & Http.Res, (store, Http.Res{405, Http.set(Http.empty(), "allow", "GET, HEAD, OPTIONS"), Http.from_string("")}))

def authenticated(authenticated: Maybe<&2, Principal>, path: Path, store: Store, method: String, headers: Map<&2, List<&2, String>>, body: Http.Body) -> IO(Store & Http.Res):
  match authenticated:
    case None{}:
      IO.pure(Store & Http.Res, (store, error(Unauthorized{})))
    case Some{principal}:
      route(path, store, principal, method, headers, body)

def dispatch.path(path: Path, store: Store, method: String, +headers: Map<&2, List<&2, String>>, body: Http.Body) -> IO(Store & Http.Res):
  match path:
    case Health{}:
      IO.pure(Store & Http.Res, (store, json(200, Json.Obj{[(Json.utf8("ok"), Json.Flag{True{}})]})))
    case Missing{}:
      IO.pure(Store & Http.Res, (store, error(NotFound{})))
    case Me{}:
      authenticated(auth(Http.header(headers, "authorization")), Me{}, store, method, headers, body)
    case Users{}:
      authenticated(auth(Http.header(headers, "authorization")), Users{}, store, method, headers, body)
    case UserId{value}:
      authenticated(auth(Http.header(headers, "authorization")), UserId{value}, store, method, headers, body)

def dispatch(store: Store, req: Http.Req) -> IO(Store & Http.Res):
  Http.Req{method, target, headers, body} = req
  dispatch.path(select(target), store, method, headers, body)

def open(path: String, mode: String) -> IO(Store):
  do IO<Store>:
    journal : File <- IO.try(File, File.open(path, mode))
    return Store{journal, [User{7, "Alice", "alice-password"}, User{8, "Bob", "bob-password"}], 9}

def close(store: Store) -> IO(Unit):
  Store{journal, users, next} = store
  File.close(journal)
