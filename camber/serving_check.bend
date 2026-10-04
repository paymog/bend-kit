# Actual File ownership and explicit gates through published HTTP, native and JS.
import Base
import ./camber.bend as C
import ./input.bend as Input
import bend-kit-http@0.30.0.0/http.bend as H
import bend-kit-http@0.30.0.0/completion.bend as T
import bend-kit-json@0.5.1.0/json.bend as J
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as B

type Config is Data:
  Config{release: Chan(Unit)}

def require(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit, Unit{})
    case False{}: IO.die(Unit, 1, message)

def written(result: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (file, outcome) = result
  do IO<File>:
    IO.pass(Unit, outcome)
    return file

def record(file: File, text: String) -> IO(File):
  do IO<File>:
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, text ++ "\n")
    written(result)

def destroy(file: File) -> IO(Unit):
  do IO<Unit>:
    returned : File <- record(file, "CLOSED")
    File.close(returned)
    IO.print("BUNDLE CLOSED")

def authenticate(denied: String, file: File) -> IO(C.Step<File, Unit>):
  match denied:
    case "yes": IO.pure(C.Step<File, Unit>, C.Reject{file, C.Framework{401, ""}})
    case _: IO.pure(C.Step<File, Unit>, C.Continue{file})

def before(hook: String, file: File, config: Config, meta: C.Metadata) -> IO(C.Step<File, Unit>):
  match hook:
    case "auth":
      C.Metadata{method, target, headers} = meta
      authenticate(H.header(headers, "x-deny"), file)
    case _: IO.pure(C.Step<File, Unit>, C.Continue{file})

def after(hook: String, file: File, config: Config, response: H.Res) -> IO(File & Result<&2, &1, C.Error<Unit>, H.Res>):
  H.Res{status, headers, body} = response
  IO.pure(File & Result<&2, &1, C.Error<Unit>, H.Res>, (file, Done{H.Res{status, H.set(headers, "x-" ++ hook, "yes"), body}}))

def mapper.response(file: File, response: H.Res) -> IO(File & Result<&2, &1, C.Error<Unit>, H.Res>):
  H.Res{status, headers, body} = response
  IO.pure(File & Result<&2, &1, C.Error<Unit>, H.Res>, (file, Done{H.Res{status, H.set(headers, "x-mapped", "once"), body}}))

def mapper(file: File, config: Config, error: C.Error<Unit>) -> IO(File & Result<&2, &1, C.Error<Unit>, H.Res>):
  match error:
    case C.Framework{401, allow}: mapper.response(file, C.text(401, "Unauthorized"))
    case _: mapper.response(file, C.default.error(~Unit, error))

def plain(req: H.Req) -> IO(H.Res):
  H.Req{method, target, headers, body} = req
  IO.pure(H.Res, H.Res{201, H.set(H.empty(), "x-plain", "packed"), body})

def plain.result(file: File, result: Result<&2, &1, C.ResponseError, H.Res>) -> File & Result<&2, &1, C.Error<Unit>, H.Res>:
  match result:
    case Done{response}: (file, Done{response})
    case Fail{error}: (file, Fail{C.ResponseInvalid{}})

def json.result(file: File, result: Result<&2, &1, U32, J.Val>) -> File & Result<&2, &1, C.Error<Unit>, H.Res>:
  match result:
    case Done{value}: (file, Done{C.json(~J.Val, ~(x => x), 201, value)})
    case Fail{status}: (file, Fail{C.Framework{status, ""}})

def run(action: U32, file: File, config: Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(File & Result<&2, &1, C.Error<Unit>, H.Res>):
  match action:
    case 0:
      do IO<File & Result<&2, &1, C.Error<Unit>, H.Res>>:
        returned : File <- record(file, "BUSINESS plain")
        result : Result<&2, &1, C.ResponseError, H.Res> <- C.plain(~plain, req)
        return plain.result(returned, result)
    case 1:
      H.Req{method, target, headers, body} = req
      IO.pure(File & Result<&2, &1, C.Error<Unit>, H.Res>, json.result(file, Input.json(headers, body)))
    case 2:
      IO.pure(File & Result<&2, &1, C.Error<Unit>, H.Res>, (file, Fail{C.ApplicationError{Unit{}}}))
    case 3:
      Config{release} = config
      do IO<File & Result<&2, &1, C.Error<Unit>, H.Res>>:
        returned : File <- record(file, "BUSINESS hold")
        IO.print("HELD")
        C.receive(Unit, release)
        return (returned, Done{C.text(200, "released")})
    case _:
      IO.pure(File & Result<&2, &1, C.Error<Unit>, H.Res>, (file, Done{C.text(action, "suppressed")}))

def registration(bad: Bool, config: Config) -> Result<&2, &2, C.RegistrationError, C.Application<U32, Config, C.Policy<String>>>:
  match bad:
    case True{}:
      C.application(~U32, ~Config, ~C.Policy<String>, [C.Route{"GET", "invalid", 0, Nil{}, C.policy(~String, 2, Nil{}, Nil{})}], Nil{}, config, C.policy(~String, 0, Nil{}, Nil{}))
    case False{}:
      C.application(~U32, ~Config, ~C.Policy<String>,
        [C.Route{"POST", "/plain", 0, [1], C.policy(~String, 2, Nil{}, ["route"])},
         C.Route{"GET", "/plain", 0, [1], C.policy(~String, 2, Nil{}, ["route"])},
         C.Route{"POST", "/json", 1, [1], C.policy(~String, 2, Nil{}, ["route"])},
         C.Route{"GET", "/error", 2, [1], C.policy(~String, 2, Nil{}, ["route"])},
         C.Route{"GET", "/hold", 3, Nil{}, C.policy(~String, 2, Nil{}, Nil{})},
         C.Route{"GET", "/empty", 204, Nil{}, C.policy(~String, 2, Nil{}, Nil{})},
         C.Route{"GET", "/cached", 304, Nil{}, C.policy(~String, 2, Nil{}, Nil{})}],
        [C.Group{1, Nil{}, C.policy(~String, 1, ["auth"], ["group"])}], config, C.policy(~String, 0, Nil{}, ["root"]))

def done(report: T.Completion<C.ApplicationReport<String>>) -> IO(Unit):
  T.Completion{payload, status, outcome} = report
  match payload:
    case C.Dispatched{entered, mapped, stopped}: IO.print("APPLICATION " ++ U32.show(status))
    case C.CapacityRejected{}: IO.print("CAPACITY REJECTED")

def observe(status: U32, outcome: T.Outcome) -> IO(Unit):
  match outcome:
    case T.HostAccepted{}: IO.print("TRANSPORT ACCEPTED " ++ U32.show(status))
    case _: IO.print("TRANSPORT FAILED " ++ U32.show(status))

def final(result: C.ServerExit<U32, File, Config, String>) -> IO(Unit):
  C.ServerExit{transport, application} = result
  match application:
    case C.OwnerClosed{}: IO.print("JOINED CLOSED")
    case C.OwnerBusy{owner, counts}: IO.die(Unit, 1, "drain left application busy")

def waiting.prepared(prepared: C.Server<U32, File, Config, String> & C.Context<File, C.Application<U32, Config, C.Policy<String>>, C.BufferedRequest, Unit, C.ApplicationReport<String>>
) -> IO(C.Server<U32, File, Config, String> & Maybe<&2, Chan(C.Counts)>):
  (retained, C.Context{messages}) = prepared
  do IO<C.Server<U32, File, Config, String> & Maybe<&2, Chan(C.Counts)>>:
    +reply : Chan(C.Counts) <- Chan.new(C.Counts, 1)
    filled : Bool <- Chan.send(C.Counts, reply, C.Counts{0n, 0n, 0n, 0n})
    queued : Bool <- Chan.send(C.Message<File, C.Application<U32, Config, C.Policy<String>>, C.BufferedRequest, Unit, C.ApplicationReport<String>>,
      messages, C.Inspect{reply})
    require(filled && queued, "dependency wait setup failed")
    return (retained, Some{reply})

def waiting(flag: Bool, server: C.Server<U32, File, Config, String>
) -> IO(C.Server<U32, File, Config, String> & Maybe<&2, Chan(C.Counts)>):
  match flag:
    case False{}:
      IO.pure(C.Server<U32, File, Config, String> & Maybe<&2, Chan(C.Counts)>, (server, None{}))
    case True{}:
      waiting.prepared(C.server.dependencies(~U32, ~File, ~Config, ~String, server))

def release(blocked: Maybe<&2, Chan(C.Counts)>) -> IO(Unit):
  match blocked:
    case None{}: IO.pure(Unit, Unit{})
    case Some{+reply}:
      do IO<Unit>:
        dummy : C.Counts <- C.receive(C.Counts, reply)
        actual : C.Counts <- C.receive(C.Counts, reply)
        Chan.close(C.Counts, reply)
        IO.print("DEPENDENCY RELEASED")

type Control is Data:
  Control{stop: H.ServerControl, stats: H.ServerStats, release: Chan(Unit),
    blocked: Maybe<&2, Chan(C.Counts)>, self: Chan(H.ServerControl)}

def counts(result: Maybe<&2, H.ServerCounts>) -> IO(H.Res):
  match result:
    case None{}: IO.die(H.Res, 1, "counts unavailable")
    case Some{H.ServerCounts{c, a, b, ch, ah, bh, cr, ar, br}}:
      IO.pure(H.Res, C.text(200, U32.show(a) ++ " " ++ U32.show(b)))

def control(path: String, context: Control, req: H.Req) -> IO(H.Res):
  match path:
    case "/plain": plain(req)
    case "/counts":
      Control{stop, stats, release, blocked, self} = context
      do IO<H.Res>:
        snapshot : Maybe<&2, H.ServerCounts> <- H.server.stats(stats)
        counts(snapshot)
    case "/stop":
      Control{stop, stats, release, blocked, self} = context
      do IO<H.Res>:
        accepted : Bool <- H.server.stop(stop)
        require(accepted, "stop not accepted")
        IO.print("STOP REQUESTED")
        return C.empty(200)
    case "/release":
      Control{stop, stats, gate, blocked, self} = context
      do IO<H.Res>:
        release(blocked)
        sent : Bool <- Chan.send(Unit, gate, Unit{})
        require(sent, "release failed")
        return C.empty(200)
    case "/finish":
      Control{stop, stats, release, blocked, +self} = context
      do IO<H.Res>:
        accepted : Bool <- H.server.stop(stop)
        own : H.ServerControl <- C.receive(H.ServerControl, self)
        own_stopped : Bool <- H.server.stop(own)
        require(own_stopped, "control stop not accepted")
        return C.empty(200)
    case _: IO.pure(H.Res, C.empty(404))

def control.reply(context: Control, req: H.Req) -> IO(H.Reply):
  H.Req{method, +path, headers, body} = req
  do IO<H.Reply>:
    response : H.Res <- control(path, context, H.Req{method, path, headers, body})
    return H.Reply{response, T.Unobserved{}}

def control.running(controlled: H.Server<Control> & H.ServerControl,
  server: C.Server<U32, File, Config, String>, +gate: Chan(Unit), +self: Chan(H.ServerControl)
) -> IO(Unit):
  (transport, own_control) = controlled
  do IO<Unit>:
    sent : Bool <- Chan.send(H.ServerControl, self, own_control)
    finished : Chan(C.ServerExit<U32, File, Config, String>) <- IO.fork(C.ServerExit<U32, File, Config, String>,
      C.server.run(~U32, ~File, ~Config, ~String, ~done, ~observe, server))
    IO.print("READY")
    control_exit : H.ServerExit <- H.server.run(~Control, ~control.reply, ~(context => status => outcome => T.ignore(status, outcome)), transport)
    exited : C.ServerExit<U32, File, Config, String> <- IO.join(C.ServerExit<U32, File, Config, String>, finished)
    final(exited)
    Chan.close(Unit, gate)
    Chan.close(H.ServerControl, self)
    IO.print("CONTROL JOINED")

def control.started(server: C.Server<U32, File, Config, String>, +gate: Chan(Unit),
  +self: Chan(H.ServerControl), started: Unit & Result<&2, &1, H.StartupError, H.Server<Control>>
) -> IO(Unit):
  (owner, result) = started
  match result:
    case Fail{error}:
      do IO<Unit>:
        exited : C.ServerExit<U32, File, Config, String> <- C.server.close(~U32, ~File, ~Config, ~String, server)
        final(exited)
        Chan.close(Unit, gate)
        Chan.close(H.ServerControl, self)
        IO.die(Unit, 1, "control bind failed")
    case Done{transport}:
      control.running(H.server.control(~Control, transport), server, gate, self)

def application.observed(observed: C.Server<U32, File, Config, String> & H.ServerStats,
  stop: H.ServerControl, blocked: Maybe<&2, Chan(C.Counts)>, +gate: Chan(Unit), control_port: U32
) -> IO(Unit):
  (server, stats) = observed
  do IO<Unit>:
    +self : Chan(H.ServerControl) <- Chan.new(H.ServerControl, 1)
    control_result : Unit & Result<&2, &1, H.StartupError, H.Server<Control>> <-
      H.server.start(~Control, ~Unit, Control{stop, stats, gate, blocked, self}, Unit{}, C.server.config(control_port))
    control.started(server, gate, self, control_result)

def application.controlled(controlled: C.Server<U32, File, Config, String> & H.ServerControl,
  blocked: Maybe<&2, Chan(C.Counts)>, gate: Chan(Unit), control_port: U32
) -> IO(Unit):
  (server, stop) = controlled
  application.observed(C.server.observer(~U32, ~File, ~Config, ~String, server), stop, blocked, gate, control_port)

def application.waited(prepared: C.Server<U32, File, Config, String> & Maybe<&2, Chan(C.Counts)>,
  gate: Chan(Unit), control_port: U32
) -> IO(Unit):
  (server, blocked) = prepared
  application.controlled(C.server.control(~U32, ~File, ~Config, ~String, server), blocked, gate, control_port)

def started(result: Result<&2, &1, C.StartupError, C.Server<U32, File, Config, String>>,
  +mode: String, config: Config, control_port: U32
) -> IO(Unit):
  match result:
    case Fail{error}:
      Config{gate} = config
      do IO<Unit>:
        Chan.close(Unit, gate)
        IO.print("STARTUP FAILED")
    case Done{server}:
      match mode:
        case "small":
          Config{gate} = config
          do IO<Unit>:
            exit : C.ServerExit<U32, File, Config, String> <- C.server.close(~U32, ~File, ~Config, ~String, server)
            final(exit)
            Chan.close(Unit, gate)
        case _:
          Config{+gate} = config
          do IO<Unit>:
            prepared : C.Server<U32, File, Config, String> & Maybe<&2, Chan(C.Counts)> <- waiting(String.eq(mode, "wait"), server)
            application.waited(prepared, gate, control_port)

def config.adjust(+mode: String, configured: H.ServerConfig) -> H.ServerConfig:
  H.ServerConfig{host, p, body, headers, c, a, b, hm, bm, im, wm} = configured
  H.ServerConfig{host, p, Bool.pick(U32, String.eq(mode, "invalid"), 0, body), headers, 8, 4, 4, hm, bm, im, wm}

def config(mode: String, port: U32) -> H.ServerConfig:
  config.adjust(mode, C.server.config(port))

def start(+mode: String, port: U32, path: String, control_port: U32) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    gate : Chan(Unit) <- Chan.new(Unit, 1)
    +application_config : Config = Config{gate}
    result : Result<&2, &1, C.StartupError, C.Server<U32, File, Config, String>> <-
      C.server.start(~U32, ~File, ~Config, ~Unit, ~String, ~before, ~after, ~run, ~mapper, ~destroy,
        registration(String.eq(mode, "registration"), application_config), config(mode, port), [file])
    started(result, mode, application_config, control_port)

def headers(names: List<&2, String>, +fields: Map<&2, List<&2, String>>) -> IO(Unit):
  match names:
    case Nil{}: IO.pure(Unit, Unit{})
    case +name <> rest:
      do IO<Unit>:
        IO.print("HEADER " ++ name ++ "=" ++ H.header(fields, name))
        headers(rest, fields)

def direct.completed(result: C.Completion<File, String>) -> IO(Unit):
  C.Completed{file, H.Res{status, fields, body}, entered, mapped, stopped} = result
  do IO<Unit>:
    IO.print("STATUS " ++ U32.show(status))
    headers(["content-type", "allow", "x-root", "x-group", "x-route", "x-plain", "x-mapped"], fields)
    IO.print("BODY " ++ B.to_hex(body))
    destroy(file)

def direct.ready(app: Result<&2, &2, C.RegistrationError, C.Application<U32, Config, C.Policy<String>>>,
  body: Maybe<&1, B.Bytes>, file: File, method: String, target: String, media: String, deny: String
) -> IO(Unit):
  match app body:
    case Done{application} Some{packed}:
      do IO<Unit>:
        completion : C.Completion<File, String> <- C.dispatch(~U32, ~File, ~Config, ~Unit, ~String, ~before, ~after, ~run, ~mapper,
          application, file, H.Req{method, target, H.set(H.set(H.empty(), "content-type", media), "x-deny", deny), packed})
        direct.completed(completion)
    case _ _:
      do IO<Unit>:
        destroy(file)
        IO.die(Unit, 1, "invalid direct fixture")

def direct(path: String, method: String, target: String, media: String, deny: String, hex: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    +gate : Chan(Unit) <- Chan.new(Unit, 1)
    direct.ready(registration(False{}, Config{gate}), B.from_hex(hex), file, method, target, media, deny)
    Chan.close(Unit, gate)

def ports(mode: String, app_port: Maybe<&2, U32>, path: String, control_port: Maybe<&2, U32>) -> IO(Unit):
  match app_port control_port:
    case Some{number} Some{control}: start(mode, number, path, control)
    case _ _: IO.die(Unit, 1, "invalid port")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> mode <> number <> path <> control <> Nil{}: ports(mode, U32.read(number), path, U32.read(control))
    case program <> "direct" <> path <> method <> target <> media <> deny <> hex <> Nil{}:
      direct(path, method, target, media, deny, hex)
    case _: IO.die(Unit, 1, "usage: serving_check mode port journal control-port")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
