# Actual effect order and lifecycle boundary regressions, native and JC.
import Base
import ./camber.bend as C
import ./dispatch_check.bend as Check
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as B
import bend-kit-http@0.25.0.2/http.bend as H

type Principal is Data:
  Principal{subject: String}

type State is Data:
  State{events: List<&2, String>, principal: Principal}

def record(state: State, +event: String) -> IO(State):
  State{events, Principal{+principal}} = state
  do IO<State>:
    IO.print("effect:" ++ event ++ ":" ++ principal)
    return State{List.append(&2, String, events, [event]), Principal{principal}}

def decision.early(yes: Bool, state: State) -> IO(C.Step<State, String>):
  match yes:
    case True{}:
      IO.pure(C.Step<State, String>, C.Early{state, C.empty(202)})
    case False{}:
      IO.pure(C.Step<State, String>, C.Continue{state})

def decision.fail(yes: Bool, state: State) -> IO(C.Step<State, String>):
  match yes:
    case True{}:
      IO.pure(C.Step<State, String>, C.Reject{state, C.ApplicationError{"secret-before"}})
    case False{}:
      IO.pure(C.Step<State, String>, C.Continue{state})

def decision(+mode: String, hook: String, state: State) -> IO(C.Step<State, String>):
  match mode:
    case "early-root":
      IO.pure(C.Step<State, String>, C.Early{state, C.empty(202)})
    case "early-group":
      decision.early(String.eq(hook, "g1"), state)
    case "early-route":
      decision.early(String.eq(hook, "r1"), state)
    case "fail-group":
      decision.fail(String.eq(hook, "g1"), state)
    case "fail-route":
      decision.fail(String.eq(hook, "r1"), state)
    case _:
      IO.pure(C.Step<State, String>, C.Continue{state})

def before(+hook: String, +state: State, mode: String, meta: C.Metadata) -> IO(C.Step<State, String>):
  State{events, Principal{subject}} = state
  C.Metadata{method, target, headers} = meta
  do IO<C.Step<State, String>>:
    Check.require(String.eq(H.header(headers, "x-principal"), subject), "metadata/context before decode")
    next : State <- record(state, "b" ++ hook)
    decision(mode, hook, next)

def after.result(fail: Bool, state: State, response: H.Res) -> State & Result<&2, &1, C.Error<String>, H.Res>:
  match fail:
    case True{}:
      (state, Fail{C.ApplicationError{"secret-transform"}})
    case False{}:
      (state, Done{response})

def after.response(invalid: Bool, response: H.Res) -> H.Res:
  match invalid:
    case True{}: C.text(99, "secret-after-map")
    case False{}: response

def after(+hook: String, state: State, +mode: String, response: H.Res) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
    next : State <- record(state, "t" ++ hook)
    return after.result((String.eq(mode, "transform") || String.eq(mode, "mapped-transform")) && String.eq(hook, "r2"), next, after.response(String.eq(mode, "mapped-invalid") && String.eq(hook, "r2"), response))

def mapper.result(mode: String, state: State, error: C.Error<String>) -> State & Result<&2, &1, C.Error<String>, H.Res>:
  match mode:
    case "mapper-fail":
      (state, Fail{C.ApplicationError{"secret-mapper"}})
    case "mapper-invalid":
      (state, Done{C.text(99, "secret-output")})
    case "mapped-invalid":
      (state, Done{C.text(200, "mapped")})
    case _:
      (state, Done{C.default.error(~String, error)})

def mapper(state: State, mode: String, error: C.Error<String>) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
    next : State <- record(state, "map")
    return mapper.result(mode, next, error)

def handler.mode(mode: String, state: State, body: H.Body) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  match mode:
    case "handler":
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Fail{C.ApplicationError{"secret-handler"}}))
    case "invalid":
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Done{C.text(99, "secret-response")}))
    case _:
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Done{C.raw(200, body)}))

def decoded(mode: String, state: State, body: H.Body) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  match mode:
    case "decoder":
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Fail{C.Framework{400, ""}}))
    case "unsupported":
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Fail{C.Framework{415, ""}}))
    case "mapper-fail":
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Fail{C.ApplicationError{"secret"}}))
    case "mapper-invalid":
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Fail{C.ApplicationError{"secret"}}))
    case "mapped-transform":
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Fail{C.ApplicationError{"secret"}}))
    case "mapped-invalid":
      IO.pure(State & Result<&2, &1, C.Error<String>, H.Res>, (state, Fail{C.ApplicationError{"secret"}}))
    case _:
      do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
        next : State <- record(state, "handler")
        handler.mode(mode, next, body)

def ordinary(req: H.Req) -> IO(H.Res):
  H.Req{method, target, headers, body} = req
  IO.pure(H.Res, C.raw(200, body))

def run.mode(mode: String, state: State, req: H.Req) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  match mode:
    case "plain":
      do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
        next : State <- record(state, "handler")
        response : H.Res <- ordinary(req)
        return (next, Done{response})
    case other:
      H.Req{method, target, headers, body} = req
      do IO<State & Result<&2, &1, C.Error<String>, H.Res>>:
        next : State <- record(state, "decode")
        decoded(other, next, body)

def run(action: U32, state: State, mode: String, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(State & Result<&2, &1, C.Error<String>, H.Res>):
  run.mode(mode, state, req)

def application(mode: String, reverse: Bool) -> Result<&2, &2, C.RegistrationError, C.Application<U32, String, C.Policy<String>>>:
  +routes = {[C.Route{"POST", "/users", 1, [1, 2], C.policy(~String, 3, ["r1", "r2"], ["r1", "r2"])}, C.Route{"GET", "/public", 2, [4], C.policy(~String, 5, Nil{}, ["p"])}] : List<&2, C.Route<U32, C.Policy<String>>>}
  C.application(~U32, ~String, ~C.Policy<String>, Bool.pick(List<&2, C.Route<U32, C.Policy<String>>>, reverse, List.reverse(&2, C.Route<U32, C.Policy<String>>, routes), routes), [C.Group{4, Nil{}, C.policy(~String, 4, Nil{}, ["s"])}, C.Group{2, [1], C.policy(~String, 2, Nil{}, ["e"])}, C.Group{1, Nil{}, C.policy(~String, 1, ["g1", "g2"], ["g1", "g2"])}], mode, C.policy(~String, 0, ["a1", "a2"], ["a1", "a2"]))

def join(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case x <> rest:
      x ++ "," ++ join(rest)

def entered(xs: List<&2, C.Policy<String>>) -> String:
  match xs:
    case Nil{}:
      ""
    case C.Policy{x, hooks, transforms} <> rest:
      U32.show(x) ++ "," ++ entered(rest)

def entered.policy(id: U32, before: String, after: String) -> Bool:
  match id:
    case 0: String.eq(before, "a1,a2,") && String.eq(after, "a2,a1,")
    case 1: String.eq(before, "g1,g2,") && String.eq(after, "g2,g1,")
    case 2: String.eq(before, "") && String.eq(after, "e,")
    case 3: String.eq(before, "r1,r2,") && String.eq(after, "r2,r1,")
    case 4: String.eq(before, "") && String.eq(after, "s,")
    case 5: String.eq(before, "") && String.eq(after, "p,")
    case _: False{}

def entered.policies(xs: List<&2, C.Policy<String>>) -> Bool:
  match xs:
    case Nil{}: True{}
    case C.Policy{id, before, after} <> rest:
      entered.policy(id, join(before), join(after)) && entered.policies(rest)

def checked(completion: C.Completion<State, String>, +trace: String, scopes: String, +status: U32, mapped: Bool, +principal: String) -> IO(Unit):
  C.Completed{State{+events, Principal{actual_principal}}, H.Res{actual_status, headers, body}, +ids, actual_mapped, stopped} = completion
  do IO<Unit>:
    Check.require(String.eq(join(events), trace), "effect order: " ++ join(events) ++ " expected " ++ trace)
    Check.require(String.eq(entered(ids), scopes), "entered scopes")
    Check.require(entered.policies(ids), "completion lost actual entered policy")
    Check.require(U32.is_eq(actual_status, status), "status")
    Check.require(Bool.not(Bool.xor(actual_mapped, mapped)), "mapping")
    Check.require(String.eq(actual_principal, principal), "principal isolation")
    Check.require(String.eq(B.to_string(body), Bool.pick(String, U32.is_eq(status, 200), "raw-body", Bool.pick(String, U32.is_eq(status, 500) || U32.is_eq(status, 202) || U32.is_eq(status, 204), "", "{\"type\":\"about:blank\",\"title\":\"" ++ Bool.pick(String, U32.is_eq(status, 400), "Bad Request", Bool.pick(String, U32.is_eq(status, 404), "Not Found", Bool.pick(String, U32.is_eq(status, 405), "Method Not Allowed", "Unsupported Media Type"))) ++ "\",\"status\":" ++ U32.show(status) ++ "}"))), "body retention or secret leak")
    IO.print("PASS:" ++ trace)

def scenario(result: Result<&2, &2, C.RegistrationError, C.Application<U32, String, C.Policy<String>>>, method: String, path: String, trace: String, scopes: String, status: U32, mapped: Bool, +principal: String) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit, 1, "registration")
    case Done{app}:
      do IO<Unit>:
        completion : C.Completion<State, String> <- C.dispatch(~U32, ~State, ~String, ~String, ~String, ~(h => s => k => m => before(h, s, k, m)), ~(h => s => k => r => after(h, s, k, r)), ~run, ~mapper, app, State{Nil{}, Principal{principal}}, H.Req{method, path, H.set(H.empty(), "x-principal", principal), H.from_string("raw-body")})
        checked(completion, trace, scopes, status, mapped, principal)

def check() -> IO(Unit):
  do IO<Unit>:
    scenario(application("normal", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,handler,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 200, False{}, "alice")
    scenario(application("normal", True{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,handler,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 200, False{}, "bob")
    scenario(application("normal", False{}), "GET", "/public", "ba1,ba2,decode,handler,tp,ts,ta2,ta1,", "5,4,0,", 200, False{}, "carol")
    scenario(application("normal", False{}), "GET", "/%GG", "ba1,ba2,map,ta2,ta1,", "0,", 400, True{}, "a")
    scenario(application("normal", False{}), "GET", "*", "ba1,ba2,map,ta2,ta1,", "0,", 400, True{}, "a")
    scenario(application("normal", False{}), "GET", "/missing", "ba1,ba2,map,ta2,ta1,", "0,", 404, True{}, "a")
    scenario(application("normal", False{}), "OPTIONS", "*", "ba1,ba2,ta2,ta1,", "0,", 204, False{}, "a")
    scenario(application("normal", False{}), "GET", "/users", "ba1,ba2,bg1,bg2,map,te,tg2,tg1,ta2,ta1,", "2,1,0,", 405, True{}, "a")
    scenario(application("normal", False{}), "OPTIONS", "/users", "ba1,ba2,bg1,bg2,te,tg2,tg1,ta2,ta1,", "2,1,0,", 204, False{}, "a")
    scenario(application("early-root", False{}), "GET", "/%GG", "ba1,ta2,ta1,", "0,", 202, False{}, "a")
    scenario(application("early-group", False{}), "POST", "/users", "ba1,ba2,bg1,tg2,tg1,ta2,ta1,", "1,0,", 202, False{}, "a")
    scenario(application("fail-group", False{}), "POST", "/users", "ba1,ba2,bg1,map,tg2,tg1,ta2,ta1,", "1,0,", 500, True{}, "a")
    scenario(application("early-route", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 202, False{}, "a")
    scenario(application("fail-route", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,map,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 500, True{}, "a")
    scenario(application("decoder", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,map,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 400, True{}, "a")
    scenario(application("unsupported", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,map,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 415, True{}, "a")
    scenario(application("handler", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,handler,map,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 500, True{}, "a")
    scenario(application("transform", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,handler,tr2,map,", "3,2,1,0,", 500, True{}, "a")
    scenario(application("mapped-transform", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,map,tr2,", "3,2,1,0,", 500, True{}, "a")
    scenario(application("invalid", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,handler,tr2,tr1,te,tg2,tg1,ta2,ta1,map,", "3,2,1,0,", 500, True{}, "a")
    scenario(application("mapper-fail", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,map,", "3,2,1,0,", 500, True{}, "a")
    scenario(application("mapper-invalid", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,map,", "3,2,1,0,", 500, True{}, "a")
    scenario(application("mapped-invalid", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,map,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 500, True{}, "a")
    scenario(application("plain", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,handler,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 200, False{}, "ordinary")
    left : Chan(Unit) <- IO.fork(Unit, scenario(application("normal", False{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,handler,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 200, False{}, "parallel-alice"))
    right : Chan(Unit) <- IO.fork(Unit, scenario(application("normal", True{}), "POST", "/users", "ba1,ba2,bg1,bg2,br1,br2,decode,handler,tr2,tr1,te,tg2,tg1,ta2,ta1,", "3,2,1,0,", 200, False{}, "parallel-bob"))
    l : Unit <- IO.join(Unit, left)
    r : Unit <- IO.join(Unit, right)
    return Unit{}

def main() -> IO(Unit):
  check()
