# Actual users application; dedicated launchd process, private owner control.
import Base
import ../users.bend as U
import ../users_demo.bend as Demo
import ./signals.bend as S
import bend-kit-camber@0.6.0.0/camber.bend as C
import bend-kit-http@0.30.0.0/http.bend as H
import bend-kit-http@0.30.0.0/completion.bend as T

# Acceptance-only non-yielding CPU fixture. No cancellation or proof claim.
@unsafe
def spin(n: U32) -> U32:
  spin((n + 1 : U32))

def io.returned(result: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (socket, outcome) = result
  Socket.close(socket)

# Cooperative acceptance retains the actual users Store across the yielding work.
def store.work.selected(hold: Bool, store: U.Store, principal: U32, operation: U.Operation) -> IO(U.Store & Result<&2, &2, String, U.User>):
  match hold:
    case True{}:
      do IO<U.Store & Result<&2, &2, String, U.User>>:
        IO.print("STORE HELD")
        IO.print("WORK ADMITTED")
        IO.sleep(1000)
        IO.print("WORK COMPLETED")
        U.store.work(store, principal, operation)
    case False{}: U.store.work(store, principal, operation)

def store.work(store: U.Store, principal: U32, operation: U.Operation) -> IO(U.Store & Result<&2, &2, String, U.User>):
  U.Store{users, next, journal, hold} = store
  # One held operation, then ordinary users work; never enable domain trace logging.
  store.work.selected(hold, U.Store{users, next, journal, False{}}, principal, operation)

# The actual Socket remains affine until recv returns or the process dies.
def work(mode: String, io_port: U32) -> IO(Unit):
  match mode:
    case "cooperative": IO.pure(Unit, Unit{})
    case "cpu":
      do IO<Unit>:
        IO.print("CPU ADMITTED")
        # As in risk_probe.bend: effect-provided input prevents pre-IO pure evaluation.
        seed : U32 <- IO.try(U32, IO.random_u32())
        value : U32 = spin(seed)
        IO.print(U32.show(value))
    case "io":
      do IO<Unit>:
        socket : Socket <- IO.try(Socket, TCP.connect("127.0.0.1", io_port))
        IO.print("IO ADMITTED")
        result : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(socket, 1)
        io.returned(result)
    case _: IO.pure(Unit, Unit{})

def run.me(mode: String, io_port: U32, state: U.State, config: U.Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(U.State & Result<&2, &1, C.Error<String>, H.Res>):
  do IO<U.State & Result<&2, &1, C.Error<String>, H.Res>>:
    work(mode, io_port)
    U.run(U.Me{}, state, config, selected, req)

# Config.fault carries only an explicit acceptance mode; U's fault tracing stays disabled.
def run(action: U.Action, state: U.State, config: U.Config, selected: C.Match<C.Policy<String>>, req: H.Req) -> IO(U.State & Result<&2, &1, C.Error<String>, H.Res>):
  match action:
    case U.Me{}:
      U.Config{store, gate, fault} = config
      # IO fixture port is fixed and loopback, outside public/admin listeners.
      run.me(fault, 19443, state, U.Config{store, gate, ""}, selected, req)
    case U.Health{}:
      U.Config{store, gate, fault} = config
      U.run(U.Health{}, state, U.Config{store, gate, ""}, selected, req)
    case U.ById{}:
      U.Config{store, gate, fault} = config
      U.run(U.ById{}, state, U.Config{store, gate, ""}, selected, req)
    case U.New{}:
      U.Config{store, gate, fault} = config
      U.run(U.New{}, state, U.Config{store, gate, ""}, selected, req)
    case U.Plain{}:
      U.Config{store, gate, fault} = config
      U.run(U.Plain{}, state, U.Config{store, gate, ""}, selected, req)

def target.proof(mode: String, hook: String, target: String, headers: Map<&2, List<&2, String>>) -> IO(Unit):
  match mode hook:
    case "tls-proof" "root":
      do IO<Unit>:
        U.require(String.eq(target, H.header(headers, "x-test-raw-target")), "proxy modified raw target")
        IO.print("RAW TARGET EXACT")
    case _ _: IO.pure(Unit, Unit{})

# Test-only byte oracle before routing; fixed marker, never logs target/header contents.
def before.go(+hook: String, state: U.State, config: U.Config, meta: C.Metadata) -> IO(C.Step<U.State, String>):
  U.Config{store, gate, fault} = config
  C.Metadata{method, +target, +headers} = meta
  do IO<C.Step<U.State, String>>:
    target.proof(fault, hook, target, headers)
    U.before(hook, state, U.Config{store, gate, ""}, C.Metadata{method, target, headers})

def before(hook: String, state: U.State, config: U.Config, meta: C.Metadata) -> IO(C.Step<U.State, String>):
  before.go(hook, state, config, meta)

type Control is Data:
  Control{}

def control(context: Control, req: H.Req) -> IO(H.Reply):
  H.Req{method, path, headers, body} = req
  match method path:
    case "POST" "/stop":
      do IO<H.Reply>:
        IO.print("ADMIN STOP REQUESTED")
        S.request()
        return H.Reply{C.empty(200), T.Unobserved{}}
    case _ _: IO.pure(H.Reply, H.Reply{C.empty(404), T.Unobserved{}})

@unsafe
def poll(application: H.ServerControl, admin: H.ServerControl) -> IO(Unit):
  do IO<Unit>:
    requested : Bool <- S.requested()
    stopping(requested, application, admin)

def stopping(requested: Bool, application: H.ServerControl, admin: H.ServerControl) -> IO(Unit):
  match requested:
    case True{}:
      do IO<Unit>:
        accepted : Bool <- H.server.stop(application)
        stopped : Bool <- H.server.stop(admin)
        U.require(accepted && stopped, "stop controls rejected")
        IO.print("STOP CONTROLS ACCEPTED")
    case False{}:
      do IO<Unit>:
        IO.sleep(10)
        poll(application, admin)

def running(controlled: H.Server<Control> & H.ServerControl, server: C.Server<U.Action, U.State, U.Config, String>, stop: H.ServerControl, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  (admin, admin_stop) = controlled
  do IO<Unit>:
    watcher : Chan(Unit) <- IO.fork(Unit, poll(stop, admin_stop))
    future : Chan(C.ServerExit<U.Action, U.State, U.Config, String>) <- IO.fork(C.ServerExit<U.Action, U.State, U.Config, String>,
      C.server.run(~U.Action, ~U.State, ~U.Config, ~String, ~String, ~Demo.done, ~Demo.observed, ~U.notify, ~U.report, ~C.access.disabled(~U.Config), server))
    IO.print("READY DEDICATED USERS")
    admin_exit : H.ServerExit <- H.server.run(~Control, ~control, ~(context => status => outcome => T.ignore(status, outcome)), admin)
    IO.join(Unit, watcher)
    exited : C.ServerExit<U.Action, U.State, U.Config, String> <- IO.join(C.ServerExit<U.Action, U.State, U.Config, String>, future)
    Demo.server.closed(exited)
    IO.print("TRANSPORT OWNER COMPLETED")
    closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
    Demo.store.closed(closed)
    IO.print("ADMIN OWNER COMPLETED")
    IO.print("NATURAL EXIT READY")

def admin.started(result: Unit & Result<&2, &1, H.StartupError, H.Server<Control>>, server: C.Server<U.Action, U.State, U.Config, String>, stop: H.ServerControl, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  (unit, started) = result
  match started:
    case Done{admin}: running(H.server.control(~Control, admin), server, stop, owner)
    case Fail{error}:
      do IO<Unit>:
        exited : C.ServerExit<U.Action, U.State, U.Config, String> <- C.server.close(~U.Action, ~U.State, ~U.Config, ~String, server)
        Demo.server.closed(exited)
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        Demo.store.closed(closed)
        IO.die(Unit, 1, "private admin startup failed")

def server.controlled(controlled: C.Server<U.Action, U.State, U.Config, String> & H.ServerControl, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, admin_port: U32) -> IO(Unit):
  (server, stop) = controlled
  do IO<Unit>:
    result : Unit & Result<&2, &1, H.StartupError, H.Server<Control>> <- H.server.start(~Control, ~Unit, Control{}, Unit{}, C.server.config(admin_port))
    admin.started(result, server, stop, owner)

def server.started(result: Result<&2, &1, C.StartupError, C.Server<U.Action, U.State, U.Config, String>>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, admin_port: U32) -> IO(Unit):
  match result:
    case Done{server}: server.controlled(C.server.control(~U.Action, ~U.State, ~U.Config, ~String, server), owner, admin_port)
    case Fail{error}:
      do IO<Unit>:
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        Demo.store.closed(closed)
        IO.die(Unit, 1, "users startup failed")

def prepared(pair: C.Owner<U.Store, U32, U.Operation, String, U.User> & C.Context<U.Store, U32, U.Operation, String, U.User>, port: U32, admin_port: U32, mode: String) -> IO(Unit):
  (owner, context) = pair
  do IO<Unit>:
    config : U.Config = U.Config{context, U.Disabled{}, mode}
    result : Result<&2, &1, C.StartupError, C.Server<U.Action, U.State, U.Config, String>> <- C.server.start(~U.Action, ~U.State, ~U.Config, ~String, ~String,
      ~before, ~U.after, ~run, ~U.mapper, ~U.destroy, U.application(config, False{}), C.server.config(port), [U.fresh(), U.fresh(), U.fresh(), U.fresh()])
    server.started(result, owner, admin_port)

def opened(result: Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>>, port: U32, admin_port: U32, mode: String) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "store startup failed")
    case Done{owner}: prepared(C.owner.context(U.Store, U32, U.Operation, String, U.User, owner), port, admin_port, mode)

def start(port: Maybe<&2, U32>, admin: Maybe<&2, U32>, path: String, +mode: String) -> IO(Unit):
  match port admin:
    case Some{number} Some{owner_port}:
      do IO<Unit>:
        S.install()
        result : Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>> <- C.start(~U.StoreConfig, ~U.Store, ~U32, ~U.Operation, ~String, ~U.User,
          ~U.store.open, ~store.work, ~U.store.close, U.StoreConfig{path, String.eq(mode, "cooperative")}, 1n, 16)
        opened(result, number, owner_port, mode)
    case _ _: IO.die(Unit, 1, "expected decimal ports")

def mode.valid(mode: String) -> Bool:
  match mode:
    case "": True{}
    case "cooperative": True{}
    case "cpu": True{}
    case "io": True{}
    case "tls-proof": True{}
    case _: False{}

def args.mode(port: String, admin: String, path: String, +mode: String) -> IO(Unit):
  do IO<Unit>:
    U.require(mode.valid(mode), "unknown acceptance mode")
    start(U32.read(port), U32.read(admin), path, mode)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> port <> admin <> path <> Nil{}: start(U32.read(port), U32.read(admin), path, "")
    case program <> port <> admin <> path <> mode <> Nil{}: args.mode(port, admin, path, mode)
    case _: IO.die(Unit, 1, "usage: users APP-PORT PRIVATE-ADMIN-PORT OWNED-JOURNAL [ACCEPTANCE-MODE]")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
