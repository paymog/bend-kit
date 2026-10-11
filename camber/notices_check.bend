# Real entered policies, expected notice errors, live stats and retained File effects.
import Base
import ./camber.bend as C
import ./notices.bend as N
import ./serving_check.bend as Existing
import ./input.bend as Input
import bend-kit-json@0.5.1.0/json.bend as J
import bend-kit-http@0.32.0.0/http.bend as H
import bend-kit-http@0.32.0.0/completion.bend as T
import bend-kit-notch@0.1.0.1/notch.bend as Notch
import bend-kit-time@0.1.2.1/time.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as B

type Config is Data:
  Config{mode: String, gate: Chan(Unit), stats: Chan(H.ServerStats)}

def access(config: Config) -> N.Access:
  Config{mode, gate, stats} = config
  match mode:
    case "disabled": N.Disabled{}
    case "disabled-fail": N.Disabled{}
    case _: N.Enabled{Notch.Json{}}

def tag(policy: C.Policy<String>) -> String:
  C.Policy{id, before, transforms} = policy
  match transforms:
    case name <> rest: name
    case Nil{}: "empty"

def snapshot(result: Maybe<&2, H.ServerCounts>) -> IO(Unit):
  match result:
    case Some{H.ServerCounts{connections, +active, +buffered, ch, ah, bh, cr, ar, br}}:
      do IO<Unit>:
        Existing.require(U32.is_ge(active, 1) && U32.is_ge(buffered, 1), "callback escaped admission")
        IO.print("COUNTED " ++ U32.show(active) ++ " " ++ U32.show(buffered))
    case None{}: IO.die(Unit, 1, "callback stats unavailable")

def observed(outcome: N.Outcome, +config: Config) -> IO(Unit):
  match outcome:
    case N.ApplicationOnly{}: IO.pure(Unit, Unit{})
    case N.Transport{actual}:
      Config{mode, gate, +stats} = config
      do IO<Unit>:
        +observer : H.ServerStats <- C.receive(H.ServerStats, stats)
        sent : Result<&1, &1, H.ServerStats, Unit> <- Chan.send(H.ServerStats, stats, observer)
        counts : Maybe<&2, H.ServerCounts> <- H.server.stats(observer)
        snapshot(counts)

def notify.result(mode: String, name: String, gate: Chan(Unit)) -> IO(Result<&2, &2, String, Unit>):
  match mode name:
    case "stall" "route":
      do IO<Result<&2, &2, String, Unit>>:
        IO.print("CALLBACK STALLED")
        C.receive(Unit, gate)
        return Done{Unit{}}
    case "notice-fail" "group": IO.pure(Result<&2, &2, String, Unit>, Fail{"INTERNAL_SECRET"})
    case "disabled-fail" "group": IO.pure(Result<&2, &2, String, Unit>, Fail{"INTERNAL_SECRET"})
    case _ _: IO.pure(Result<&2, &2, String, Unit>, Done{Unit{}})

def notify(+config: Config, +policy: C.Policy<String>, notice: N.Notice) -> IO(Result<&2, &2, String, Unit>):
  Config{mode, gate, stats} = config
  C.Policy{id, before, transforms} = policy
  N.Notice{status, duration, mapped, stopped, +outcome} = notice
  do IO<Result<&2, &2, String, Unit>>:
    observed(outcome, config)
    IO.print("NOTICE " ++ tag(policy) ++ " " ++ U32.show(id) ++ " " ++ U32.show(status) ++ " " ++ N.outcome.name(outcome) ++ " " ++ Int.I64.show(Time.Duration.to_ms(duration)))
    notify.result(mode, tag(policy), gate)

def report(config: Config, error: String) -> IO(Unit):
  IO.print("OWNER NOTICE ERROR")

def before.selected(early: Bool, file: File) -> IO(C.Step<File, String>):
  match early:
    case True{}: IO.pure(C.Step<File, String>, C.Early{file, C.text(202, "early")})
    case False{}: IO.pure(C.Step<File, String>, C.Continue{file})

def before(hook: String, file: File, config: Config, meta: C.Metadata) -> IO(C.Step<File, String>):
  C.Metadata{method, target, headers} = meta
  +deny = H.header(headers, "x-deny")
  before.selected(String.eq(deny, hook), file)

def after.result(bad: Bool, file: File, response: H.Res) -> IO(File & Result<&2, &1, C.Error<String>, H.Res>):
  match bad:
    case True{}: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Fail{C.ApplicationError{"INTERNAL_SECRET"}}))
    case False{}: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Done{response}))

def after(hook: String, file: File, config: Config, response: H.Res) -> IO(File & Result<&2, &1, C.Error<String>, H.Res>):
  H.Res{status, +headers, body} = response
  after.result(String.eq(hook, "route") && String.eq(H.header(headers, "x-transform-fail"), "yes"), file, H.Res{status, headers, body})

def mapper.result(file: File, error: C.Error<String>) -> File & Result<&2, &1, C.Error<String>, H.Res>:
  match error:
    case C.Framework{499, allow}: (file, Fail{C.ApplicationError{"INTERNAL_SECRET"}})
    case C.Framework{498, allow}: (file, Done{C.text(99, "INTERNAL_SECRET")})
    case C.Framework{status, allow}: (file, Done{C.default.error(~String, C.Framework{status, allow})})
    case C.ApplicationError{diagnostic}: (file, Done{C.default.error(~String, C.ApplicationError{diagnostic})})
    case C.ResponseInvalid{}: (file, Done{C.default.error(~String, C.ResponseInvalid{})})

def mapper(file: File, config: Config, error: C.Error<String>) -> IO(File & Result<&2, &1, C.Error<String>, H.Res>):
  do IO<File & Result<&2, &1, C.Error<String>, H.Res>>:
    IO.print("MAPPER")
    return mapper.result(file, error)

def decoder(config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> Result<&2, &1, C.Error<String>, J.Val>:
  H.Req{method, target, headers, body} = req
  C.input(~J.Val, ~String, Input.json(headers, body))

def json.handler(file: File, config: Config, value: J.Val) -> IO(File & Result<&2, &1, C.Error<String>, H.Res>):
  do IO<File & Result<&2, &1, C.Error<String>, H.Res>>:
    returned : File <- Existing.record(file, "BUSINESS 1")
    return (returned, Done{C.json(~J.Val, ~(x => x), 201, value)})

def run.result(action: U32, file: File, config: Config, req: H.Req) -> IO(File & Result<&2, &1, C.Error<String>, H.Res>):
  match action:
    case 2: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Fail{C.ApplicationError{"INTERNAL_SECRET"}}))
    case 3: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Done{H.Res{200, H.set(H.empty(), "x-transform-fail", "yes"), H.from_string("")}}))
    case 4: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Done{C.text(99, "INTERNAL_SECRET")}))
    case 5:
      Config{mode, gate, stats} = config
      do IO<File & Result<&2, &1, C.Error<String>, H.Res>>:
        IO.print("EFFECT COMMITTED")
        C.receive(Unit, gate)
        return (file, Done{C.text(200, "BODY_SECRET")})
    case 6: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Fail{C.Framework{499, ""}}))
    case 7: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Fail{C.Framework{498, ""}}))
    case 204: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Done{C.text(204, "BODY_SECRET")}))
    case _: IO.pure(File & Result<&2, &1, C.Error<String>, H.Res>, (file, Done{H.Res{200, H.set(H.empty(), "set-cookie", "COOKIE_SECRET"), H.from_string("BODY_SECRET")}}))

def run(+action: U32, file: File, config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(File & Result<&2, &1, C.Error<String>, H.Res>):
  match action:
    case 1:
      C.execute(~J.Val, ~File, ~Config, ~String, ~String, ~decoder, ~json.handler, file, config, selected, req)
    case _:
      do IO<File & Result<&2, &1, C.Error<String>, H.Res>>:
        returned : File <- Existing.record(file, "BUSINESS " ++ U32.show(action))
        run.result(action, returned, config, req)

def application(config: Config) -> Result<&2, &2, C.RegistrationError, C.Application<U32, Config, C.Policy<String>>>:
  C.application(~U32, ~Config, ~C.Policy<String>,
    [C.Route{"GET", "/ok", 0, [1], C.policy(~String, 7, ["route"], ["route"])},
     C.Route{"POST", "/decode", 1, [1], C.policy(~String, 7, ["route"], ["route"])},
     C.Route{"GET", "/handler", 2, [1], C.policy(~String, 7, ["route"], ["route"])},
     C.Route{"GET", "/transform", 3, [1], C.policy(~String, 7, ["route"], ["route"])},
     C.Route{"GET", "/validation", 4, [1], C.policy(~String, 7, ["route"], ["route"])},
     C.Route{"GET", "/reset", 5, [1], C.policy(~String, 7, ["route"], ["route"])},
     C.Route{"GET", "/mapper-fail", 6, [1], C.policy(~String, 7, ["route"], ["route"])},
     C.Route{"GET", "/mapper-invalid", 7, [1], C.policy(~String, 7, ["route"], ["route"])},
     C.Route{"GET", "/empty", 204, [1], C.policy(~String, 7, ["route"], ["route"])}],
    [C.Group{1, Nil{}, C.policy(~String, 7, ["group"], ["group"])}], config, C.policy(~String, 7, ["root"], ["root"]))

def done(completion: T.Completion<C.ApplicationReport<String>>) -> IO(Unit):
  IO.print("RESPONSE COMPLETED")

def direct.finished(completion: C.Completion<File, String>) -> IO(Unit):
  C.Completed{file, H.Res{status, headers, body}, entered, mapped, stopped} = completion
  B.Bytes{size, buffer} = body
  do IO<Unit>:
    IO.print("STATUS " ++ U32.show(status))
    IO.print("BODY_SIZE " ++ U32.show(size))
    Existing.destroy(file)

def direct.ready(result: Result<&2, &2, C.RegistrationError, C.Application<U32, Config, C.Policy<String>>>, +config: Config, file: File, method: String, target: String, deny: String) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "registration failed")
    case Done{app}:
      do IO<Unit>:
        completion : C.Completion<File, String> <- C.dispatch(~U32, ~File, ~Config, ~String, ~String, ~Config,
          ~before, ~after, ~(a => s => k => selected => req => run(a, s, k, selected, req)), ~mapper,
          ~(k => policy => notice => notify(k, policy, notice)), ~report, config, access(config), app, file,
          H.Req{method, target, H.set(H.set(H.empty(), "content-type", "application/json"), "x-deny", deny), H.from_string("BODY_SECRET")})
        direct.finished(completion)

# Separate finite control server; callbacks may query the real application actor.
type Control is Data:
  Control{application: H.ServerControl, stats: H.ServerStats, gate: Chan(Unit), self: Chan(H.ServerControl)}

def control(context: Control, path: String) -> IO(H.Reply):
  Control{application, stats, gate, +self} = context
  match path:
    case "/counts":
      do IO<H.Reply>:
        counts : Maybe<&2, H.ServerCounts> <- H.server.stats(stats)
        response : H.Res <- Existing.counts(counts)
        return H.Reply{response, T.Unobserved{}}
    case "/release":
      do IO<H.Reply>:
        sent : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, gate, Unit{})
        return H.Reply{C.empty(200), T.Unobserved{}}
    case _:
      do IO<H.Reply>:
        stopped : Bool <- H.server.stop(application)
        own : H.ServerControl <- C.receive(H.ServerControl, self)
        own_stopped : Bool <- H.server.stop(own)
        return H.Reply{C.empty(200), T.Unobserved{}}

def control.reply(context: Control, req: H.Req) -> IO(H.Reply):
  H.Req{method, path, headers, body} = req
  control(context, path)

def final(result: C.ServerExit<U32, File, Config, String>) -> IO(Unit):
  C.ServerExit{transport, application} = result
  match application:
    case C.OwnerClosed{}: IO.print("JOINED CLOSED")
    case C.OwnerBusy{owner, counts}: IO.die(Unit, 1, "drain left application busy")

def control.running(controlled: H.Server<Control> & H.ServerControl, server: C.Server<U32, File, Config, String>, +self: Chan(H.ServerControl)) -> IO(Unit):
  (transport, stop) = controlled
  do IO<Unit>:
    sent : Result<&1, &1, H.ServerControl, Unit> <- Chan.send(H.ServerControl, self, stop)
    finished : Chan(C.ServerExit<U32, File, Config, String>) <- IO.fork(C.ServerExit<U32, File, Config, String>,
      C.server.run(~U32, ~File, ~Config, ~String, ~String, ~done, ~T.ignore,
        ~(k => policy => notice => notify(k, policy, notice)), ~report, ~access, server))
    IO.print("READY")
    control_exit : H.ServerExit <- H.server.run(~Control, ~control.reply, ~(context => status => outcome => T.ignore(status, outcome)), transport)
    exited : C.ServerExit<U32, File, Config, String> <- IO.join(C.ServerExit<U32, File, Config, String>, finished)
    final(exited)
    Chan.close(H.ServerControl, self)
    IO.print("CONTROL JOINED")

def control.started(result: Unit & Result<&2, &1, H.StartupError, H.Server<Control>>, server: C.Server<U32, File, Config, String>, +self: Chan(H.ServerControl)) -> IO(Unit):
  (unit, started) = result
  match started:
    case Fail{error}: IO.die(Unit, 1, "control startup failed")
    case Done{transport}: control.running(H.server.control(~Control, transport), server, self)

def application.observed(observed: C.Server<U32, File, Config, String> & H.ServerStats, stop: H.ServerControl, config: Config, control_port: U32) -> IO(Unit):
  (server, +stats) = observed
  Config{mode, +gate, +channel} = config
  do IO<Unit>:
    sent : Result<&1, &1, H.ServerStats, Unit> <- Chan.send(H.ServerStats, channel, stats)
    +self : Chan(H.ServerControl) <- Chan.new(H.ServerControl, 1)
    control_result : Unit & Result<&2, &1, H.StartupError, H.Server<Control>> <- H.server.start(~Control, ~Unit, Control{stop, stats, gate, self}, Unit{}, C.server.config(control_port))
    control.started(control_result, server, self)
    discarded : H.ServerStats <- C.receive(H.ServerStats, channel)
    Chan.close(H.ServerStats, channel)
    Chan.close(Unit, gate)

def application.controlled(controlled: C.Server<U32, File, Config, String> & H.ServerControl, config: Config, control_port: U32) -> IO(Unit):
  (server, stop) = controlled
  application.observed(C.server.observer(~U32, ~File, ~Config, ~String, server), stop, config, control_port)

def started(result: Result<&2, &1, C.StartupError, C.Server<U32, File, Config, String>>, config: Config, control_port: U32) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "application startup failed")
    case Done{server}: application.controlled(C.server.control(~U32, ~File, ~Config, ~String, server), config, control_port)

def ports(mode: String, port: Maybe<&2, U32>, path: String, control_port: Maybe<&2, U32>) -> IO(Unit):
  match port control_port:
    case Some{p} Some{cp}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(path, "w"))
        +gate : Chan(Unit) <- Chan.new(Unit, 1)
        +stats : Chan(H.ServerStats) <- Chan.new(H.ServerStats, 1)
        +config : Config = Config{mode, gate, stats}
        result : Result<&2, &1, C.StartupError, C.Server<U32, File, Config, String>> <- C.server.start(~U32, ~File, ~Config, ~String, ~String,
          ~before, ~after, ~(a => s => k => selected => req => run(a, s, k, selected, req)), ~mapper, ~Existing.destroy, application(config), C.server.config(p), [file])
        started(result, config, cp)
    case _ _: IO.die(Unit, 1, "invalid ports")

def args(args: List<&1, String>) -> IO(Unit):
  match args:
    case program <> "direct" <> path <> method <> target <> deny <> Nil{}:
      do IO<Unit>:
        file : File <- IO.try(File, File.open(path, "w"))
        +gate : Chan(Unit) <- Chan.new(Unit, 1)
        +stats : Chan(H.ServerStats) <- Chan.new(H.ServerStats, 1)
        +config : Config = Config{"direct", gate, stats}
        direct.ready(application(config), config, file, method, target, deny)
        Chan.close(Unit, gate)
        Chan.close(H.ServerStats, stats)
    case program <> mode <> port <> path <> control_port <> Nil{}:
      ports(mode, U32.read(port), path, U32.read(control_port))
    case _: IO.die(Unit, 1, "notices_check mode port journal control-port | direct journal method target deny")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
