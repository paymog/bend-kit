# Complete consumer of the published dispatcher/server, with a shared raw prepared-router control.
import Base
import bend-kit-camber@0.7.0.0/camber.bend as C
import bend-kit-camber@0.7.0.0/input.bend as I
import bend-kit-camber@0.7.0.0/notices.bend as N
import bend-kit-http@0.32.0.0/http.bend as H
import bend-kit-http@0.32.0.0/completion.bend as T
import bend-kit-router@0.2.0.0/router.bend as R
import bend-kit-json@0.5.1.0/json.bend as J
import bend-kit-time@0.1.2.1/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int

type Action is Data:
  Text{}
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
    t : Time.Duration <- Time.mono()
    stamped(label, t)

def res(status: U32, media: String, body: String) -> H.Res:
  H.Res{status, H.set(H.empty(), "content-type", media), H.from_string(body)}
def id(id: U32) -> H.Res:
  res(200, "application/json", "{\"id\":" ++ U32.show(id) ++ "}")
def mapped(error: C.Error<String>) -> H.Res:
  match error:
    case C.Framework{404, allow}: C.text(404, "not found")
    case C.Framework{405, allow}: H.Res{405, H.set(H.empty(), "allow", allow), H.from_string("")}
    case C.Framework{status, allow}: C.empty(status)
    case _: C.empty(500)
def mapper(state: U32, config: Config, error: C.Error<String>) -> IO(U32 & Result<&2, &1, C.Error<String>, H.Res>):
  IO.pure(U32 & Result<&2, &1, C.Error<String>, H.Res>, (state, Done{mapped(error)}))
def authenticated(ok: Bool, state: U32) -> C.Step<U32, String>:
  match ok:
    case True{}: C.Continue{(state + 1 : U32)}
    case False{}: C.Early{state, H.Res{401, H.set(H.empty(), "www-authenticate", "Bearer"), H.from_string("")}}
def before(hook: U32, state: U32, config: Config, metadata: C.Metadata) -> IO(C.Step<U32, String>):
  C.Metadata{method, target, headers} = metadata
  IO.pure(C.Step<U32, String>, authenticated(String.eq(H.header(headers, "authorization"), "Bearer alice"), state))
def after(hook: U32, state: U32, config: Config, response: H.Res) -> IO(U32 & Result<&2, &1, C.Error<String>, H.Res>):
  IO.pure(U32 & Result<&2, &1, C.Error<String>, H.Res>, (state, Done{response}))
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
def name.key(key: Maybe<&2, String>, value: H.Body) -> Result<&2, &1, U32, String>:
  match key:
    case Some{"name"}: name.text(I.utf8(value))
    case _: Fail{400}
def name(value: J.Val) -> Result<&2, &1, U32, String>:
  match value:
    case J.Obj{(key, J.Str{text}) <> Nil{}}: name.key(I.utf8(key), text)
    case _: Fail{400}
def decoded(result: Result<&2, &1, U32, String>) -> H.Res:
  match result:
    case Fail{status}: C.text(status, "invalid name")
    case Done{value}: C.json(~String, ~(v => J.Obj{[(J.utf8("name"), J.Str{J.utf8(v)})]}), 200, value)
def decode.capped(ok: Bool, headers: Map<&2, List<&2, String>>, body: H.Body) -> H.Res:
  match ok:
    case False{}: C.empty(413)
    case True{}:
      decoded(do Result<&2, &1, U32, String>:
        value : J.Val <- I.json(headers, body)
        name(value))
def decode.sized(headers: Map<&2, List<&2, String>>, pair: H.Body & U32) -> H.Res:
  (body, length) = pair
  decode.capped(U32.is_le(length, 1048576), headers, body)
def decode(headers: Map<&2, List<&2, String>>, body: H.Body) -> H.Res:
  decode.sized(headers, H.length(body))
def param.id(value: Maybe<&2, U32>) -> H.Res:
  match value:
    case Some{id_value}: id(id_value)
    case None{}: C.text(400, "invalid id")
def param(result: Map<&2, String> & String) -> H.Res:
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
def parsed(result: Maybe<&1, J.Val>) -> H.Res:
  match result:
    case None{}: C.text(400, "invalid json")
    case Some{value}: C.text(200, "parsed")
def parse.capped(ok: Bool, body: H.Body) -> H.Res:
  match ok:
    case False{}: C.empty(413)
    case True{}: parsed(J.parse.strict.bytes(body, 64))
def parse.sized(pair: H.Body & U32) -> H.Res:
  (body, length) = pair
  parse.capped(U32.is_le(length, 1048576), body)
def worked.cpu(seed_time: Time.Duration, iterations: U32) -> H.Res:
  Time.Duration{seconds, seed} = seed_time
  C.text(200, U32.show(spin.blocks(U32.to_nat(U32.div(iterations, 1024)), seed)))
def worked(mode: String, body: H.Body, iterations: U32) -> IO(H.Res):
  match mode:
    case "yield":
      do IO<H.Res>:
        IO.sleep(500)
        return C.text(200, "yielded")
    case "cpu":
      do IO<H.Res>:
        seed_time : Time.Duration <- Time.mono()
        return worked.cpu(seed_time, iterations)
    case "parse": IO.pure(H.Res, parse.sized(H.length(body)))
    case "validate": IO.pure(H.Res, decode(H.set(H.empty(), "content-type", "application/json"), body))
    case _: IO.die(H.Res, 1, "unknown work")
def work(+mode: String, +identifier: String, body: H.Body, config: Config) -> IO(H.Res):
  Config{gate, iterations} = config
  do IO<H.Res>:
    stamp("ARM " ++ mode ++ " " ++ identifier)
    released : Unit <- C.receive(Unit, gate)
    stamp("BEGIN " ++ mode ++ " " ++ identifier)
    response : H.Res <- worked(mode, body, iterations)
    stamp("END " ++ mode ++ " " ++ identifier)
    return response

def business(action: Action, state: U32, config: Config, selected: C.Match<C.Policy<U32>>, req: H.Req) -> IO(H.Res):
  match action:
    case Text{}: IO.pure(H.Res, C.text(200, "OK\n"))
    case Probe{}:
      do IO<H.Res>:
        stamp("ORDINARY")
        return C.text(200, "OK\n")
    case Json{}: IO.pure(H.Res, res(200, "application/json", "{\"ok\":true}"))
    case Parameter{}:
      C.Match{target, params, groups, method, pattern, policies} = selected
      IO.pure(H.Res, param(Map.get(String, "", params, "id")))
    case Decode{}:
      H.Req{verb, path, headers, body} = req
      IO.pure(H.Res, decode(headers, body))
    case Echo{}:
      H.Req{verb, path, headers, body} = req
      IO.pure(H.Res, H.Res{200, H.set(H.empty(), "content-type", "application/octet-stream"), body})
    case Hooks{}: IO.pure(H.Res, H.Res{200, H.set(H.set(H.empty(), "content-type", "application/json"), "x-hook-count", U32.show(state)), H.from_string("{\"ok\":true}")})
    case Route{id_value}: IO.pure(H.Res, id(id_value))
    case Work{mode}:
      H.Req{verb, path, headers, body} = req
      work(mode, H.header(headers, "x-work-id"), body, config)
def run(action: Action, state: U32, config: Config, selected: C.Match<C.Policy<U32>>, req: H.Req) -> IO(U32 & Result<&2, &1, C.Error<String>, H.Res>):
  do IO<U32 & Result<&2, &1, C.Error<String>, H.Res>>:
    response : H.Res <- business(action, state, config, selected, req)
    return (0, Done{response})

def routes(n: Nat) -> List<&2, C.Route<Action, C.Policy<U32>>>:
  match n:
    case 0n: Nil{}
    case 1n+ +p:
      C.Route{"GET", "/route/" ++ Nat.show(p), Route{U32.from_nat(p)}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})} <> routes(p)
def basic() -> List<&2, C.Route<Action, C.Policy<U32>>>:
  [C.Route{"GET", "/text", Text{}, Nil{}, C.policy(~U32, 0, Nil{}, Nil{})},
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
