# Four-route users demo over published Camber; one affine in-memory store, no persistence claim.
import Base
import bend-kit-camber@0.6.0.0/camber.bend as C
import bend-kit-camber@0.6.0.0/input.bend as Input
import bend-kit-camber@0.6.0.0/notices.bend as N
import bend-kit-http@0.30.0.0/http.bend as H
import bend-kit-json@0.5.1.0/json.bend as J
import bend-kit-router@0.2.0.0/target.bend as Target
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as B

type User is Data:
  User{id: U32, name: String, secret: String}
type Operation is Data:
  Lookup{id: U32, fail: Bool}
  Create{name: String}
  Hold{gate: Chan(Unit)}
type Store is Type:
  Store{users: Map<&2, User>, next: U32, journal: File, trace: Bool}
type StoreConfig is Data:
  StoreConfig{path: String, trace: Bool}
type State is Type:
  State{principal: Maybe<&2, U32>, label: String, fail: Bool, hold: Bool}
type Gate is Data:
  Disabled{}
  Gate{arrived: Chan(Unit), release: Chan(Unit)}
type Config is Data:
  Config{store: C.Context<Store, U32, Operation, String, User>, gate: Gate, fault: String}
type Action is Data:
  Health{}
  ById{}
  Me{}
  New{}
  Plain{}

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit, Unit{})
    case False{}: IO.die(Unit, 1, message)

def store.written(result: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (file, outcome) = result
  do IO<File>:
    IO.pass(Unit, outcome)
    return file

def store.record(file: File, text: String) -> IO(File):
  do IO<File>:
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, text ++ "\n")
    store.written(result)

def store.opened(result: Result<&1, &1, U32 & String, File>, trace: Bool) -> Result<&2, &1, String, Store>:
  match result:
    case Fail{error}: Fail{"store open failed"}
    case Done{file}:
      users : Map<&2, User> = Map.set(&2, User, Map.set(&2, User, Map.new(&2, User), "7", User{7, "Alice", "ALICE_SECRET"}), "8", User{8, "Bob", "BOB_SECRET"})
      Done{Store{users, 9, file, trace}}

def store.open(config: StoreConfig, index: Nat) -> IO(Result<&2, &1, String, Store>):
  StoreConfig{path, trace} = config
  do IO<Result<&2, &1, String, Store>>:
    result : Result<&1, &1, U32 & String, File> <- File.open(path, "w")
    return store.opened(result, trace)

def store.close(store: Store) -> IO(Unit):
  Store{users, next, journal, trace} = store
  do IO<Unit>:
    file : File <- store.record(journal, "CLOSED")
    File.close(file)
    IO.print("STORE CLOSED")

def store.got(pair: Map<&2, User> & User, next: U32, journal: File, trace: Bool) -> Store & Result<&2, &2, String, User>:
  (users, user) = pair
  (Store{users, next, journal, trace}, Done{user})

def store.lookup.hit(id: U32, store: Store) -> Store & Result<&2, &2, String, User>:
  Store{users, next, journal, trace} = store
  store.got(Map.get(User, User{0, "", ""}, users, U32.show(id)), next, journal, trace)

def store.lookup(found: Bool, id: U32, store: Store) -> Store & Result<&2, &2, String, User>:
  match found:
    case False{}: (store, Fail{"not found"})
    case True{}: store.lookup.hit(id, store)

def store.found(pair: Map<&2, User> & Bool, next: U32, journal: File, id: U32, trace: Bool) -> Store & Result<&2, &2, String, User>:
  (users, found) = pair
  store.lookup(found, id, Store{users, next, journal, trace})

def store.failure.checked(outcome: Result<&1, &1, U32 & String, Unit>, store: Store) -> IO(Store & Result<&2, &2, String, User>):
  match outcome:
    case Fail{error}:
      do IO<Store & Result<&2, &2, String, User>>:
        IO.print("STORE EXPECTED FILE FAILURE")
        return (store, Fail{"store failure"})
    case Done{unit}: IO.die(Store & Result<&2, &2, String, User>, 1, "read-only store write unexpectedly succeeded")

def store.failure.result(store: Store, result: File & Result<&1, &1, U32 & String, Unit>) -> IO(Store & Result<&2, &2, String, User>):
  (file, outcome) = result
  do IO<Store & Result<&2, &2, String, User>>:
    File.close(file)
    store.failure.checked(outcome, store)

def store.read.normal(+id: U32, store: Store) -> IO(Store & Result<&2, &2, String, User>):
  Store{users, next, journal, trace} = store
  IO.pure(Store & Result<&2, &2, String, User>, store.found(Map.has(&2, User, users, U32.show(id)), next, journal, id, trace))

def store.read(id: U32, fail: Bool, store: Store) -> IO(Store & Result<&2, &2, String, User>):
  match fail:
    case True{}:
      do IO<Store & Result<&2, &2, String, User>>:
        file : File <- IO.try(File, File.open("/dev/null", "r"))
        result : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, "store transaction")
        store.failure.result(store, result)
    case False{}: store.read.normal(id, store)

def store.create.commit(store: Store, +id: U32, name: String) -> IO(Store & Result<&2, &2, String, User>):
  Store{users, next, journal, trace} = store
  +user = {User{id, name, "CREATED_SECRET"} : User}
  IO.pure(Store & Result<&2, &2, String, User>, (Store{Map.set(&2, User, users, U32.show(id), user), (id + 1 : U32), journal, trace}, Done{user}))

def store.create.checked(limit: Bool, store: Store, +next: U32, name: String) -> IO(Store & Result<&2, &2, String, User>):
  match limit:
    case True{}: IO.pure(Store & Result<&2, &2, String, User>, (store, Fail{"store ID limit"}))
    case False{}: store.create.commit(store, next, name)

def store.create(name: String, store: Store) -> IO(Store & Result<&2, &2, String, User>):
  Store{users, +next, journal, trace} = store
  store.create.checked(U32.is_eq(next, 4294967295), Store{users, next, journal, trace}, next, name)

def store.perform(operation: Operation, store: Store) -> IO(Store & Result<&2, &2, String, User>):
  match operation:
    case Lookup{id, fail}: store.read(id, fail, store)
    case Create{name}: store.create(name, store)
    case Hold{gate}:
      do IO<Store & Result<&2, &2, String, User>>:
        IO.print("STORE HELD")
        C.receive(Unit, gate)
        return (store, Done{User{7, "Alice", "ALICE_SECRET"}})

def operation.name(operation: Operation) -> String:
  match operation:
    case Lookup{id, fail}: "lookup " ++ U32.show(id)
    case Create{name}: "create"
    case Hold{gate}: "hold"

def store.work.trace(store: Store, principal: U32, +operation: Operation) -> IO(Store & Result<&2, &2, String, User>):
  Store{users, next, journal, trace} = store
  do IO<Store & Result<&2, &2, String, User>>:
    +event : String = "DOMAIN " ++ U32.show(principal) ++ " " ++ operation.name(operation)
    file : File <- store.record(journal, event)
    IO.print(event)
    store.perform(operation, Store{users, next, file, trace})

def store.work.traced(trace: Bool, store: Store, principal: U32, operation: Operation) -> IO(Store & Result<&2, &2, String, User>):
  match trace:
    case True{}: store.work.trace(store, principal, operation)
    case False{}: store.perform(operation, store)

def store.work.go(store: Store, principal: U32, operation: Operation) -> IO(Store & Result<&2, &2, String, User>):
  Store{users, next, journal, +trace} = store
  store.work.traced(trace, Store{users, next, journal, trace}, principal, operation)

def store.work(store: Store, principal: U32, operation: Operation) -> IO(Store & Result<&2, &2, String, User>):
  store.work.go(store, principal, operation)

# Deliberately explicit projection: the internal secret is discarded here.
def public(user: User) -> J.Val:
  User{id, name, secret} = user
  J.Obj{[(J.utf8("id"), J.Num{J.utf8(U32.show(id))}), (J.utf8("name"), J.Str{J.utf8(name)})]}

def fresh() -> State:
  State{None{}, "", False{}, False{}}

def clear(state: State) -> State:
  State{principal, label, fail, hold} = state
  State{None{}, label, False{}, False{}}

def clean(principal: Maybe<&2, U32>) -> Bool:
  match principal:
    case None{}: True{}
    case Some{id}: False{}

def destroy(state: State) -> IO(Unit):
  State{principal, label, fail, hold} = state
  do IO<Unit>:
    require(clean(principal), "principal leaked into reusable state")
    IO.print("STATE CLOSED")

def credential(value: String) -> Maybe<&2, U32>:
  match value:
    case "Bearer seven": Some{7}
    case "Bearer eight": Some{8}
    case _: None{}

def authenticated(state: State, principal: Maybe<&2, U32>) -> IO(C.Step<State, String>):
  State{previous, label, fail, hold} = state
  match principal:
    case None{}: IO.pure(C.Step<State, String>, C.Reject{State{None{}, label, fail, hold}, C.Framework{401, ""}})
    case Some{id}: IO.pure(C.Step<State, String>, C.Continue{State{Some{id}, label, fail, hold}})

# Fixture tracing is opt-in. The reusable/default configuration has an empty fault.
def trace(config: Config, action: Unit -> IO(Unit)) -> IO(Unit):
  Config{store, gate, fault} = config
  match fault:
    case "": IO.pure(Unit, Unit{})
    case _: action(Unit{})

def before.root(state: State, config: Config, +headers: Map<&2, List<&2, String>>) -> IO(C.Step<State, String>):
  State{principal, label, fail, hold} = state
  Config{store, gate, +fault} = config
  do IO<C.Step<State, String>>:
    require(clean(principal), "request began with stale principal")
    return C.Continue{State{None{}, H.header(headers, "x-case"), String.eq(fault, "testing") && String.eq(H.header(headers, "x-store-fail"), "yes"), String.eq(fault, "testing") && String.eq(H.header(headers, "x-hold"), "yes")}}

def before.selected(hook: String, state: State, config: Config, +headers: Map<&2, List<&2, String>>) -> IO(C.Step<State, String>):
  match hook:
    case "root": before.root(state, config, headers)
    case "group": authenticated(state, credential(H.header(headers, "authorization")))
    case _: IO.pure(C.Step<State, String>, C.Continue{state})

def before.go(+hook: String, state: State, +config: Config, meta: C.Metadata) -> IO(C.Step<State, String>):
  C.Metadata{method, target, +headers} = meta
  do IO<C.Step<State, String>>:
    trace(config, x => IO.print("BEFORE " ++ hook))
    before.selected(hook, state, config, headers)

def before(hook: String, state: State, config: Config, meta: C.Metadata) -> IO(C.Step<State, String>):
  before.go(hook, state, config, meta)

def after.selected(fail: Bool, state: State, response: H.Res) -> State & Result<&2, &1, C.Error<String>, H.Res>:
  match fail:
    case True{}: (clear(state), Fail{C.ApplicationError{"transform failure"}})
    case False{}: (clear(state), Done{response})

def after.go(+hook: String, state: State, +config: Config, response: H.Res) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  Config{store, gate, fault} = config
  H.Res{status, headers, body} = response
  do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
    trace(config, x => IO.print("TRANSFORM " ++ hook))
    return after.selected(String.eq(fault, "transform") && String.eq(hook, "route"), state,
      H.Res{status, H.set(headers, "x-" ++ hook, "yes"), body})

def after(hook: String, state: State, config: Config, response: H.Res) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  after.go(hook, state, config, response)

def mapped(error: C.Error<String>) -> H.Res:
  match error:
    case C.Framework{401, allow}: H.Res{401, H.set(H.empty(), "www-authenticate", "Bearer"), H.from_string("")}
    case C.Framework{503, allow}: C.text(503, "store unavailable")
    case C.ApplicationError{"not found"}: C.default.error(~String, C.Framework{404, ""})
    case C.ApplicationError{other}: C.default.error(~String, C.ApplicationError{other})
    case C.Framework{status, allow}: C.default.error(~String, C.Framework{status, allow})
    case C.ResponseInvalid{}: C.default.error(~String, C.ResponseInvalid{})

def mapper(state: State, config: Config, error: C.Error<String>) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
    trace(config, x => IO.print("MAPPER"))
    return (clear(state), Done{mapped(error)})

def name.checked(ok: Bool, name: String) -> Result<&2, &1, U32, String>:
  match ok:
    case True{}: Done{name}
    case False{}: Fail{400}

def name.valid(+name: String) -> Result<&2, &1, U32, String>:
  +length = String.length(name)
  name.checked(Nat.is_ge(length, 1n) && Nat.is_le(length, 100n), name)

def name.field(key: Maybe<&2, String>, value: Maybe<&2, String>) -> Result<&2, &1, U32, String>:
  match key value:
    case Some{"name"} Some{name}: name.valid(name)
    case _ _: Fail{400}

def name.object(value: J.Val) -> Result<&2, &1, U32, String>:
  match value:
    case J.Obj{(key, J.Str{text}) <> Nil{}}: name.field(Input.utf8(key), Input.utf8(text))
    case _: Fail{400}

def decode.new(config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> Result<&2, &1, C.Error<String>, String>:
  H.Req{method, target, headers, body} = req
  C.input(~String, ~String, do Result<&2, &1, U32, String>:
    value : J.Val <- Input.json(headers, body)
    name.object(value))

def decode.id(config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> Result<&2, &1, C.Error<String>, U32>:
  C.Match{Target.Target{segments, query, authority, star}, params, groups, method, pattern, policies} = selected
  C.input(~U32, ~String, Input.path(~U32, ~Input.u32, params, "id"))

def user.location.put(id: U32, response: H.Res) -> H.Res:
  H.Res{status, headers, body} = response
  H.Res{status, H.set(headers, "location", "/users/" ++ U32.show(id)), body}

def user.location(created: Bool, id: U32, response: H.Res) -> H.Res:
  match created:
    case True{}: user.location.put(id, response)
    case False{}: response

def user.response(+created: Bool, user: User) -> H.Res:
  User{+id, name, secret} = user
  user.location(created, id, C.json(~User, ~public, Bool.pick(U32, created, 201, 200), User{id, name, secret}))

def returned(state: State, created: Bool, result: C.Outcome<String, User>) -> State & Result<&2, &1, C.Error<String>, H.Res>:
  match result:
    case C.Success{user}: (clear(state), Done{user.response(created, user)})
    case C.Expected{error}: (clear(state), Fail{C.ApplicationError{error}})
    case C.Exhausted{}: (clear(state), Fail{C.Framework{503, ""}})
    case C.Stopped{}: (clear(state), Fail{C.Framework{503, ""}})

def business.principal(principal: Maybe<&2, U32>, state: State, config: Config, operation: Operation, created: Bool) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  match principal:
    case None{}: IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (clear(state), Fail{C.Framework{401, ""}}))
    case Some{id}:
      Config{store, gate, fault} = config
      do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
        result : C.Outcome<String, User> <- C.call(Store, U32, Operation, String, User, store, id, operation)
        return returned(state, created, result)

def business(state: State, config: Config, operation: Operation, created: Bool) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  State{+principal, label, fail, hold} = state
  business.principal(principal, State{principal, label, fail, hold}, config, operation, created)

def lookup(state: State, config: Config, id: U32) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  State{principal, label, +fail, hold} = state
  business(State{principal, label, fail, hold}, config, Lookup{id, fail}, False{})

def create(state: State, config: Config, name: String) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  business(state, config, Create{name}, True{})

def me(principal: Maybe<&2, U32>, state: State, config: Config) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  match principal:
    case None{}: IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (clear(state), Fail{C.Framework{401, ""}}))
    case Some{id}: lookup(state, config, id)

def plain.response(fault: String, body: H.Body) -> H.Res:
  match fault:
    case "crlf": H.Res{201, H.set(H.empty(), "x-invalid", "PRIVATE\r\ninjected: yes"), body}
    case "framing": H.Res{201, H.set(H.empty(), "transfer-encoding", "chunked"), body}
    case _: H.Res{201, H.set(H.empty(), "x-plain", "packed"), body}

def plain(req: H.Req) -> IO(H.Res):
  H.Req{method, target, headers, body} = req
  IO.pure(H.Res, plain.response(H.header(headers, "x-invalid"), body))

def plain.result(state: State, result: Result<&2, &1, C.ResponseError, H.Res>) -> State & Result<&2, &1, C.Error<String>, H.Res>:
  match result:
    case Done{res}: (clear(state), Done{res})
    case Fail{err}: (clear(state), Fail{C.ResponseInvalid{}})

def run.me(state: State, config: Config) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  State{+principal, label, fail, hold} = state
  me(principal, State{principal, label, fail, hold}, config)

def run.selected(action: Action, state: State, config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  match action:
    case Health{}: IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (clear(state), Done{C.json(~Unit, ~(x => J.Obj{[(J.utf8("ok"), J.Flag{True{}})]}), 200, Unit{})}))
    case ById{}: C.execute(~U32, ~State, ~Config, ~String, ~String, ~decode.id, ~lookup, state, config, selected, req)
    case New{}: C.execute(~String, ~State, ~Config, ~String, ~String, ~decode.new, ~create, state, config, selected, req)
    case Me{}: run.me(state, config)
    case Plain{}:
      do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
        result : Result<&2, &1, C.ResponseError, H.Res> <- C.plain(~plain, req)
        return plain.result(state, result)

def wait.gate(gate: Gate) -> IO(Unit):
  match gate:
    case Disabled{}: IO.die(Unit, 1, "hold requires an explicit acceptance gate")
    case Gate{arrived, release}:
      do IO<Unit>:
        IO.print("REQUEST HELD")
        sent : Bool <- Chan.send(Unit, arrived, Unit{})
        require(sent, "hold arrival signal failed")
        C.receive(Unit, release)

def wait(hold: Bool, gate: Gate) -> IO(Unit):
  match hold:
    case False{}: IO.pure(Unit, Unit{})
    case True{}: wait.gate(gate)

def phase(action: Action) -> String:
  match action:
    case ById{}: "DECODE id"
    case New{}: "DECODE json"
    case _: "HANDLE"

def query.values(values: List<&2, String>) -> IO(Unit):
  match values:
    case Nil{}: IO.pure(Unit, Unit{})
    case value <> rest:
      do IO<Unit>:
        IO.print("QUERY tag=" ++ value)
        query.values(rest)

def observe(selected: C.Match<C.Policy<String>>, headers: Map<&2, List<&2, String>>) -> IO(Unit):
  C.Match{Target.Target{segments, query, authority, star}, params, groups, method, pattern, policies} = selected
  do IO<Unit>:
    IO.print("HOST " ++ H.header(headers, "host"))
    query.values(Input.query.values(query, "tag"))

def run.go(+action: Action, state: State, +config: Config, +selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  State{principal, +label, fail, +hold} = state
  Config{store, +gate, fault} = config
  H.Req{method, target, +headers, body} = req
  do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
    trace(config, x => do IO<Unit>:
      IO.print(phase(action) ++ " " ++ label)
      observe(selected, headers))
    wait(hold, gate)
    run.selected(action, State{principal, label, fail, hold}, config, selected, H.Req{method, target, headers, body})

def run(action: Action, state: State, config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  run.go(action, state, config, selected, req)

# Both insertion orders describe the same four routes; the plain fixture is separate.
def routes.users(reverse: Bool, id: C.Route<Action, C.Policy<String>>, me: C.Route<Action, C.Policy<String>>) -> List<&2, C.Route<Action, C.Policy<String>>>:
  match reverse:
    case True{}: [me, id]
    case False{}: [id, me]

def application(config: Config, reverse: Bool) -> Result<&2, &2, C.RegistrationError, C.Application<Action, Config, C.Policy<String>>>:
  id = {C.Route{"GET", "/users/:id", ById{}, [1], C.policy(~String, 2, ["route"], ["route"])} : C.Route<Action, C.Policy<String>>}
  me = {C.Route{"GET", "/users/me", Me{}, [1], C.policy(~String, 2, ["route"], ["route"])} : C.Route<Action, C.Policy<String>>}
  C.application(~Action, ~Config, ~C.Policy<String>,
    C.Route{"GET", "/health", Health{}, Nil{}, C.policy(~String, 2, ["route"], ["route"])} <>
    C.Route{"POST", "/users", New{}, [1], C.policy(~String, 2, ["route"], ["route"])} <>
    routes.users(reverse, id, me),
    [C.Group{1, Nil{}, C.policy(~String, 1, ["group"], ["group"])}], config, C.policy(~String, 0, ["root"], ["root"]))

def fixture(config: Config) -> Result<&2, &2, C.RegistrationError, C.Application<Action, Config, C.Policy<String>>>:
  C.application(~Action, ~Config, ~C.Policy<String>, [C.Route{"POST", "/plain", Plain{}, [1], C.policy(~String, 2, ["route"], ["route"])}],
    [C.Group{1, Nil{}, C.policy(~String, 1, ["group"], ["group"])}], config, C.policy(~String, 0, ["root"], ["root"]))

def notify(config: Config, policy: C.Policy<String>, notice: N.Notice) -> IO(Result<&2, &2, String, Unit>):
  C.Policy{id, before, transforms} = policy
  N.Notice{status, duration, mapped, stopped, outcome} = notice
  do IO<Result<&2, &2, String, Unit>>:
    trace(config, x => IO.print("NOTICE " ++ U32.show(id) ++ " " ++ N.outcome.name(outcome)))
    return Done{Unit{}}

def report(config: Config, error: String) -> IO(Unit):
  IO.print("NOTICE ERROR")
