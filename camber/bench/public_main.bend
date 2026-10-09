import Base
import ./public_app.bend as A
import bend-kit-camber@0.7.0.0/camber.bend as C
import bend-kit-http@0.32.0.0/http.bend as H
import bend-kit-http@0.32.0.0/completion.bend as T
import bend-kit-router@0.2.0.0/router.bend as R
import bend-kit-time@0.1.2.1/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int

type RawTarget is Data:
  RawTarget{action: A.Action, policy: C.Policy<U32>}
type Raw is Data:
  Raw{table: R.Table<RawTarget>, config: A.Config}
type Control is Data:
  Control{main: H.ServerControl, own: Chan(H.ServerControl), gate: Chan(Unit)}
def config(port: U32) -> H.ServerConfig:
  H.ServerConfig{"127.0.0.1", port, 8388608, 65536, 32, 16, 16, 200, 30000, 30000, 30000}
def entries(routes: List<&2, C.Route<A.Action, C.Policy<U32>>>) -> List<&2, R.Entry<RawTarget>>:
  match routes:
    case Nil{}: Nil{}
    case C.Route{method, pattern, action, groups, policy} <> rest:
      R.Entry{method, pattern, RawTarget{action, policy}, groups} <> entries(rest)
def raw.checked(result: Result<&2, &2, R.Error, R.Table<RawTarget>>, settings: A.Config) -> IO(Raw):
  match result:
    case Done{table}: IO.pure(Raw, Raw{table, settings})
    case Fail{error}: IO.die(Raw, 1, "raw registration failed")
def raw(profile: U32, settings: A.Config) -> IO(Raw):
  raw.checked(R.prepare(~RawTarget, entries(A.registrations(profile))), settings)
def raw.entered(step: C.Step<U32, String>, action: A.Action, settings: A.Config, selected: C.Match<C.Policy<U32>>, req: H.Req) -> IO(H.Res):
  match step:
    case C.Continue{state}: A.business(action, state, settings, selected, req)
    case C.Early{state, response}: IO.pure(H.Res, response)
    case C.Reject{state, error}: IO.pure(H.Res, A.mapped(error))
def raw.selected(choice: R.Resolved<RawTarget>, +settings: A.Config, req: H.Req) -> IO(H.Res):
  R.Resolved{target, selected} = choice
  match selected:
    case R.NotFound{}: IO.pure(H.Res, A.mapped(C.Framework{404, ""}))
    case R.MethodMissing{groups, allow}: IO.pure(H.Res, A.mapped(C.Framework{405, allow}))
    case R.Options{groups, allow}: IO.pure(H.Res, H.Res{204, H.set(H.empty(), "allow", allow), H.from_string("")})
    case R.Found{RawTarget{action, C.Policy{id, hooks, transforms}}, params, groups, method, pattern}:
      H.Req{+verb, +path, +headers, body} = req
      do IO<H.Res>:
        step : C.Step<U32, String> <- C.before(~U32, ~A.Config, ~String, ~U32, ~A.before, hooks, 0, settings, C.Metadata{verb, path, headers})
        raw.entered(step, action, settings, C.Match{target, params, groups, method, pattern, Nil{}}, H.Req{verb, path, headers, body})
def raw.resolved(result: Result<&2, &2, R.Error, R.Resolved<RawTarget>>, settings: A.Config, req: H.Req) -> IO(H.Res):
  match result:
    case Fail{error}: IO.pure(H.Res, C.empty(400))
    case Done{choice}: raw.selected(choice, settings, req)
def raw.dispatch(context: Raw, req: H.Req) -> IO(H.Res):
  Raw{table, settings} = context
  H.Req{+method, +path, headers, body} = req
  raw.resolved(R.resolve(~RawTarget, table, method, path), settings, H.Req{method, path, headers, body})
def raw.reply(context: Raw, req: H.Req) -> IO(H.Reply):
  do IO<H.Reply>:
    response : H.Res <- raw.dispatch(context, req)
    return H.Reply{response, T.Unobserved{}}
def ignored(context: Raw, status: U32, outcome: T.Outcome) -> IO(Unit):
  IO.pure(Unit, Unit{})
def done(completion: T.Completion<C.ApplicationReport<U32>>) -> IO(Unit):
  IO.pure(Unit, Unit{})
def observed(status: U32, outcome: T.Outcome) -> IO(Unit):
  match status:
    case 408: A.stamp("TIMEOUT_DELIVERED")
    case _: IO.pure(Unit, Unit{})
def closed(exit: C.ServerExit<A.Action, U32, A.Config, U32>) -> IO(Unit):
  C.ServerExit{transport, application} = exit
  match application:
    case C.OwnerClosed{}: IO.print("APPLICATION JOINED")
    case C.OwnerBusy{owner, counts}: IO.die(Unit, 1, "application failed to drain")
def control(context: Control, req: H.Req) -> IO(H.Reply):
  Control{main, +own, +gate} = context
  H.Req{method, path, headers, body} = req
  match path:
    case "/release":
      do IO<H.Reply>:
        released : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, gate, Unit{})
        return H.Reply{C.empty(200), T.Unobserved{}}
    case "/finish":
      do IO<H.Reply>:
        stopped : Bool <- H.server.stop(main)
        own_stop : H.ServerControl <- C.receive(H.ServerControl, own)
        finished : Bool <- H.server.stop(own_stop)
        return H.Reply{C.empty(200), T.Unobserved{}}
    case _: IO.pure(H.Reply, H.Reply{C.empty(404), T.Unobserved{}})
def control.running(controlled: H.Server<Control> & H.ServerControl, +own: Chan(H.ServerControl)) -> IO(Unit):
  (returned, stop) = controlled
  do IO<Unit>:
    sent : Result<&1, &1, H.ServerControl, Unit> <- Chan.send(H.ServerControl, own, stop)
    IO.print("READY")
    exit : H.ServerExit <- H.server.run(~Control, ~control, ~(context => status => outcome => T.ignore(status, outcome)), returned)
    IO.print("CONTROL JOINED")
def control.run(started: Unit & Result<&2, &1, H.StartupError, H.Server<Control>>, +own: Chan(H.ServerControl)) -> IO(Unit):
  (unit, result) = started
  match result:
    case Fail{error}: IO.die(Unit, 1, "control bind failed")
    case Done{server}: control.running(H.server.control(~Control, server), own)
def controls(stop: H.ServerControl, +gate: Chan(Unit), port: U32) -> IO(Unit):
  do IO<Unit>:
    +own : Chan(H.ServerControl) <- Chan.new(H.ServerControl, 1)
    started : Unit & Result<&2, &1, H.StartupError, H.Server<Control>> <- H.server.start(~Control, ~Unit, Control{stop, own, gate}, Unit{}, config(port))
    control.run(started, own)
    Chan.close(H.ServerControl, own)
def camber.running(controlled: C.Server<A.Action, U32, A.Config, U32> & H.ServerControl, gate: Chan(Unit), port: U32) -> IO(Unit):
  (returned, stop) = controlled
  do IO<Unit>:
    control_future : Chan(Unit) <- IO.fork(Unit, controls(stop, gate, port))
    exit : C.ServerExit<A.Action, U32, A.Config, U32> <- C.server.run(~A.Action, ~U32, ~A.Config, ~U32, ~String, ~done, ~observed, ~A.notify, ~A.report, ~C.access.disabled(~A.Config), returned)
    closed(exit)
    control_done : Unit <- IO.join(Unit, control_future)
    return control_done
def camber.started(result: Result<&2, &1, C.StartupError, C.Server<A.Action, U32, A.Config, U32>>, gate: Chan(Unit), port: U32) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "application startup failed")
    case Done{server}: camber.running(C.server.control(~A.Action, ~U32, ~A.Config, ~U32, server), gate, port)
def raw.controlled(controlled: H.Server<Raw> & H.ServerControl, gate: Chan(Unit), port: U32) -> IO(Unit):
  (returned, stop) = controlled
  do IO<Unit>:
    control_future : Chan(Unit) <- IO.fork(Unit, controls(stop, gate, port))
    exit : H.ServerExit <- H.server.run(~Raw, ~raw.reply, ~ignored, returned)
    control_done : Unit <- IO.join(Unit, control_future)
    IO.print("RAW JOINED")
def raw.running(started: Unit & Result<&2, &1, H.StartupError, H.Server<Raw>>, gate: Chan(Unit), port: U32) -> IO(Unit):
  (unit, result) = started
  match result:
    case Fail{error}: IO.die(Unit, 1, "raw startup failed")
    case Done{server}: raw.controlled(H.server.control(~Raw, server), gate, port)
def headroom.config(headroom: Bool, port: U32) -> H.ServerConfig:
  match headroom:
    case False{}: config(port)
    case True{}: H.ServerConfig{"127.0.0.1", port, 8388608, 65536, 32, 18, 18, 200, 30000, 30000, 30000}
def resources(headroom: Bool) -> List<U32>:
  match headroom:
    case False{}: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    case True{}: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
def constructed(result: Result<&2, &2, C.RegistrationError, C.Application<A.Action, A.Config, C.Policy<U32>>>) -> IO(Result<&2, &2, C.RegistrationError, C.Application<A.Action, A.Config, C.Policy<U32>>>):
  match result:
    case Fail{error}: IO.die(Result<&2, &2, C.RegistrationError, C.Application<A.Action, A.Config, C.Policy<U32>>>, 1, "construction failed")
    case Done{app}:
      do IO<Result<&2, &2, C.RegistrationError, C.Application<A.Action, A.Config, C.Policy<U32>>>>:
        A.stamp("CONSTRUCTION_END")
        return Done{app}
def camber.start(+headroom: Bool, profile: U32, port: U32, control_port: U32, settings: A.Config, gate: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    app : Result<&2, &2, C.RegistrationError, C.Application<A.Action, A.Config, C.Policy<U32>>> <- constructed(A.application(profile, settings))
    started : Result<&2, &1, C.StartupError, C.Server<A.Action, U32, A.Config, U32>> <- C.server.start(~A.Action, ~U32, ~A.Config, ~String, ~U32, ~A.before, ~A.after, ~A.run, ~A.mapper, ~A.destroy, app, headroom.config(headroom, port), resources(headroom))
    camber.started(started, gate, control_port)
def serving(mode: String, profile: U32, port: U32, control_port: U32, settings: A.Config, gate: Chan(Unit)) -> IO(Unit):
  match mode:
    case "raw":
      do IO<Unit>:
        context : Raw <- raw(profile, settings)
        A.stamp("CONSTRUCTION_END")
        started : Unit & Result<&2, &1, H.StartupError, H.Server<Raw>> <- H.server.start(~Raw, ~Unit, context, Unit{}, config(port))
        raw.running(started, gate, control_port)
    case "camber": camber.start(False{}, profile, port, control_port, settings, gate)
    case "camber-headroom": camber.start(True{}, profile, port, control_port, settings, gate)
    case _: IO.die(Unit, 1, "expected raw, camber or camber-headroom")
def serve(mode: String, profile: U32, port: U32, control_port: U32, iterations: U32) -> IO(Unit):
  do IO<Unit>:
    +gate : Chan(Unit) <- Chan.new(Unit, 32)
    settings : A.Config = A.Config{gate, iterations}
    stamp : Unit <- A.stamp("CONSTRUCTION_BEGIN")
    serving(mode, profile, port, control_port, settings, gate)
    Chan.close(Unit, gate)
def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> mode <> profile <> port <> control_port <> iterations <> Nil{}:
      serve(mode, Maybe.default(&2, U32, U32.read(profile), 0), Maybe.default(&2, U32, U32.read(port), 0), Maybe.default(&2, U32, U32.read(control_port), 0), Maybe.default(&2, U32, U32.read(iterations), 0))
    case _: IO.die(Unit, 1, "expected raw|camber profile port control-port cpu-iterations")
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
