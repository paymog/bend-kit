# Complete consumer of the published dispatcher/server, with a shared raw prepared-router control.
import Base
import bend-kit-camber@0.19.0.3/camber.bend as C
import bend-kit-camber@0.19.0.3/input.bend as I
import bend-kit-camber@0.19.0.3/notices.bend as N
import bend-kit-http@0.45.0.3/http.bend as Http
import bend-kit-http@0.45.0.3/pure.bend as Pure
import bend-kit-http@0.45.0.3/completion.bend as T
import bend-kit-router@0.2.0.0/router.bend as R
import bend-kit-json@0.7.3.2/json.bend as J
import bend-kit-time@0.3.0.5/pure.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int

type Action is Data:
  Plain{}
  Probe{}
  Json{}
  Parameter{}
  Decode{}
  Echo{}
  Hooks{}
  Route{id: U32}
  Work{mode: String}
type Config is Data:
  Config{gate: Chan(Unit), iterations: U32}

def stamped(+label: String, time: Time.Duration) -> IO(Unit):
  Time.Duration{seconds, nanos} = time
  IO.print(label ++ "\t" ++ Int.I64.show(seconds) ++ "\t" ++ U32.show(nanos))
def stamp(+label: String) -> IO(Unit):
  do IO<Unit>:
    t : Time.Duration <- Http.clock.mono()
    stamped(label, t)

def res(status: U32, media: String, body: String) -> Pure.Res:
  Pure.Res{status, Pure.set(Pure.empty(), "content-type", media), Pure.from_string(body)}
def id(id: U32) -> Pure.Res:
  res(200, "application/json", "{\"id\":" ++ U32.show(id) ++ "}")
def mapped(error: C.Error<String>) -> Pure.Res:
  match error:
    case C.Framework{404, allow}: C.text(404, "not found")
    case C.Framework{405, allow}: Pure.Res{405, Pure.set(Pure.empty(), "allow", allow), Pure.from_string("")}
    case C.Framework{status, allow}: C.empty(status)
    case _: C.empty(500)
def mapper(state: U32, config: Config, error: C.Error<String>) -> IO(U32 & Result<&2, &1, C.Error<String>, Pure.Res>):
  IO.pure(U32 & Result<&2, &1, C.Error<String>, Pure.Res>, (state, Done{mapped(error)}))
def authenticated(ok: Bool, state: U32) -> C.Step<U32, String>:
  match ok:
    case True{}: C.Continue{(state + 1 : U32)}
    case False{}: C.Early{state, Pure.Res{401, Pure.set(Pure.empty(), "www-authenticate", "Bearer"), Pure.from_string("")}}
def before(hook: U32, state: U32, config: Config, metadata: C.Metadata) -> IO(C.Step<U32, String>):
  C.Metadata{method, target, headers} = metadata
  IO.pure(C.Step<U32, String>, authenticated(String.eq(Pure.header(headers, "authorization"), "Bearer alice"), state))
def after(hook: U32, state: U32, config: Config, response: Pure.Res) -> IO(U32 & Result<&2, &1, C.Error<String>, Pure.Res>):
  IO.pure(U32 & Result<&2, &1, C.Error<String>, Pure.Res>, (state, Done{response}))
def notify(config: Config, policy: C.Policy<U32>, notice: N.Notice) -> IO(Result<&2, &2, String, Unit>):
  IO.pure(Result<&2, &2, String, Unit>, Done{Unit{}})
def report(config: Config, error: String) -> IO(Unit):
  IO.die(Unit, 1, "notification failed")
def destroy(state: U32) -> IO(Unit):
  IO.pure(Unit, Unit{})
def name.checked(ok: Bool, name: String) -> Result<&2, &1, U32, String>:
  match ok:
    case True{}: Done{name}
    case False{}: Fail{400}
def name.text(text: Maybe<&2, String>) -> Result<&2, &1, U32, String>:
  match text:
    case None{}: Fail{400}
    case Some{+value}: name.checked(Nat.is_ge(String.length(value), 1n) && Nat.is_le(String.length(value), 100n), value)
def name.key(key: Maybe<&2, String>, value: Pure.Body) -> Result<&2, &1, U32, String>:
  match key:
    case Some{"name"}: name.text(I.utf8(value))
    case _: Fail{400}
def name(value: J.Val) -> Result<&2, &1, U32, String>:
  match value:
    case J.Obj{(key, J.Str{text}) <> Nil{}}: name.key(I.utf8(key), text)
    case _: Fail{400}
def decoded(result: Result<&2, &1, U32, String>) -> Pure.Res:
  match result:
    case Fail{status}: C.text(status, "invalid name")
    case Done{value}: C.json(~String, ~(v => J.Obj{[(J.utf8("name"), J.Str{J.utf8(v)})]}), 200, value)
def decode.capped(ok: Bool, headers: Map<&2, List<&2, String>>, body: Pure.Body) -> Pure.Res:
  match ok:
    case False{}: C.empty(413)
    case True{}:
      decoded(do Result<&2, &1, U32, String>:
        value : J.Val <- I.json(headers, body)
        name(value))
def decode.sized(headers: Map<&2, List<&2, String>>, pair: Pure.Body & U32) -> Pure.Res:
  (body, length) = pair
  decode.capped(U32.is_le(length, 1048576), headers, body)
def decode(headers: Map<&2, List<&2, String>>, body: Pure.Body) -> Pure.Res:
  decode.sized(headers, Pure.length(body))
def param.id(value: Maybe<&2, U32>) -> Pure.Res:
  match value:
    case Some{id_value}: id(id_value)
    case None{}: C.text(400, "invalid id")
def param(result: Map<&2, String> & String) -> Pure.Res:
  (params, value) = result
  param.id(I.u32(value))

# Serial runtime-seeded arithmetic, intentionally no parallel-call claim.
def spin(n: Nat, seed: U32) -> U32:
  match n:
    case 0n: seed
    case 1n+p: spin(p, (seed * 1664525 + 1013904223 : U32))
def spin.blocks(n: Nat, seed: U32) -> U32:
  match n:
    case 0n: seed
    case 1n+p: spin.blocks(p, spin(1024n, seed))
def parsed(result: Maybe<&1, J.Val>) -> Pure.Res:
  match result:
    case None{}: C.text(400, "invalid json")
    case Some{value}: C.text(200, "parsed")
def parse.capped(ok: Bool, body: Pure.Body) -> Pure.Res:
  match ok:
    case False{}: C.empty(413)
    case True{}: parsed(J.parse.strict.bytes(body, 64))
def parse.sized(pair: Pure.Body & U32) -> Pure.Res:
  (body, length) = pair
  parse.capped(U32.is_le(length, 1048576), body)
def worked.cpu(seed_time: Time.Duration, iterations: U32) -> Pure.Res:
  Time.Duration{seconds, seed} = seed_time
  C.text(200, U32.show(spin.blocks(U32.to_nat(U32.div(iterations, 1024)), seed)))
def worked(mode: String, body: Pure.Body, iterations: U32) -> IO(Pure.Res):
  match mode:
    case "yield":
      do IO<Pure.Res>:
        IO.sleep(500)
        return C.text(200, "yielded")
    case "cpu":
      do IO<Pure.Res>:
        seed_time : Time.Duration <- Http.clock.mono()
        return worked.cpu(seed_time, iterations)
    case "parse": IO.pure(Pure.Res, parse.sized(Pure.length(body)))
    case "validate": IO.pure(Pure.Res, decode(Pure.set(Pure.empty(), "content-type", "application/json"), body))
    case _: IO.die(Pure.Res, 1, "unknown work")
def work(+mode: String, +identifier: String, body: Pure.Body, config: Config) -> IO(Pure.Res):
  Config{gate, iterations} = config
  do IO<Pure.Res>:
    stamp("ARM " ++ mode ++ " " ++ identifier)
    released : Unit <- C.receive(Unit, gate)
    stamp("BEGIN " ++ mode ++ " " ++ identifier)
    response : Pure.Res <- worked(mode, body, iterations)
    stamp("END " ++ mode ++ " " ++ identifier)
    return response

def business(action: Action, state: U32, config: Config, selected: C.Match<C.Policy<U32>>, req: Pure.Req) -> IO(Pure.Res):
  match action:
    case Plain{}: IO.pure(Pure.Res, C.text(200, "OK\n"))
    case Probe{}:
      do IO<Pure.Res>:
        stamp("ORDINARY")
        return C.text(200, "OK\n")
    case Json{}: IO.pure(Pure.Res, res(200, "application/json", "{\"ok\":true}"))
    case Parameter{}:
      C.Match{target, params, groups, method, pattern, policies} = selected
      IO.pure(Pure.Res, param(Map.get(String, "", params, "id")))
    case Decode{}:
      Pure.Req{verb, path, headers, body} = req
      IO.pure(Pure.Res, decode(headers, body))
    case Echo{}:
      Pure.Req{verb, path, headers, body} = req
      IO.pure(Pure.Res, Pure.Res{200, Pure.set(Pure.empty(), "content-type", "application/octet-stream"), body})
    case Hooks{}: IO.pure(Pure.Res, Pure.Res{200, Pure.set(Pure.set(Pure.empty(), "content-type", "application/json"), "x-hook-count", U32.show(state)), Pure.from_string("{\"ok\":true}")})
    case Route{id_value}: IO.pure(Pure.Res, id(id_value))
    case Work{mode}:
      Pure.Req{verb, path, headers, body} = req
      work(mode, Pure.header(headers, "x-work-id"), body, config)
def run(action: Action, state: U32, config: Config, selected: C.Match<C.Policy<U32>>, req: Pure.Req) -> IO(U32 & Result<&2, &1, C.Error<String>, Pure.Res>):
  do IO<U32 & Result<&2, &1, C.Error<String>, Pure.Res>>:
    response : Pure.Res <- business(action, state, config, selected, req)
    return (0, Done{response})

def routes(n: Nat) -> List<&2, C.Route<Action, C.Policy<U32>>>:
  match n:
    case 0n: Nil{}
    case 1n+ +p:
      C.Route{"GET", "/route/" ++ Nat.show(p), Route{U32.from_nat(p)}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})} <> routes(p)
def basic() -> List<&2, C.Route<Action, C.Policy<U32>>>:
  [C.Route{"GET", "/text", Plain{}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"GET", "/json", Json{}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"GET", "/users/:id", Parameter{}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"POST", "/decode", Decode{}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"POST", "/echo", Echo{}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"GET", "/hooks/0", Hooks{}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"GET", "/hooks/1", Hooks{}, Nil{}, C.policy(~U32, 1, [1], Nil{})},
   C.Route{"GET", "/hooks/5", Hooks{}, Nil{}, C.policy(~U32, 5, [1, 2, 3, 4, 5], Nil{})}]
def controls() -> List<&2, C.Route<Action, C.Policy<U32>>>:
  [C.Route{"POST", "/work/yield", Work{"yield"}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"POST", "/work/cpu", Work{"cpu"}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"POST", "/work/parse", Work{"parse"}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"POST", "/work/validate", Work{"validate"}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
   C.Route{"GET", "/probe", Probe{}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})}]
def registrations(profile: U32) -> List<&2, C.Route<Action, C.Policy<U32>>>:
  match profile:
    case 0: List.append(&2, C.Route<Action, C.Policy<U32>>, basic(), controls())
    case _: routes(U32.to_nat(profile))
def application(profile: U32, config: Config) -> Result<&2, &2, C.RegistrationError, C.Application<Action, Config, C.Policy<U32>>>:
  C.application(~Action, ~Config, ~C.Policy<U32>, registrations(profile), Nil{}, config, C.policy(~U32, 0, Nil{}, Nil{}))
