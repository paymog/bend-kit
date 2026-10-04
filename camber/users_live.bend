# Published live-only acceptance consumer: same public users application and real transport/Store joins.
import Base
import ./users.bend as U
import bend-kit-camber@0.6.0.0/camber.bend as C
import bend-kit-http@0.30.0.0/http.bend as H
import bend-kit-http@0.30.0.0/completion.bend as T

def store.closed(result: C.OwnerClose<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  match result:
    case C.OwnerClosed{}: IO.print("STORE JOINED")
    case C.OwnerBusy{owner, counts}: IO.die(Unit, 1, "store busy after completion")


type Control is Data:
  Control{stop: H.ServerControl, gate: Chan(Unit), own: Chan(H.ServerControl)}

def control(context: Control, req: H.Req) -> IO(H.Reply):
  Control{stop, +gate, +own} = context
  H.Req{method, path, headers, body} = req
  match path:
    case "/release":
      do IO<H.Reply>:
        sent : Bool <- Chan.send(Unit, gate, Unit{})
        U.require(sent, "release rejected")
        return H.Reply{C.empty(200), T.Unobserved{}}
    case "/stop":
      do IO<H.Reply>:
        accepted : Bool <- H.server.stop(stop)
        U.require(accepted, "stop rejected")
        IO.print("STOP REQUESTED")
        return H.Reply{C.empty(200), T.Unobserved{}}
    case "/finish":
      do IO<H.Reply>:
        accepted : Bool <- H.server.stop(stop)
        own_stop : H.ServerControl <- C.receive(H.ServerControl, own)
        stopped : Bool <- H.server.stop(own_stop)
        U.require(stopped, "control stop rejected")
        return H.Reply{C.empty(200), T.Unobserved{}}
    case _: IO.pure(H.Reply, H.Reply{C.empty(404), T.Unobserved{}})

def done(completion: T.Completion<C.ApplicationReport<String>>) -> IO(Unit):
  IO.print("COMPLETED")

def observed(status: U32, outcome: T.Outcome) -> IO(Unit):
  IO.pure(Unit, Unit{})

def server.closed(result: C.ServerExit<U.Action, U.State, U.Config, String>) -> IO(Unit):
  C.ServerExit{transport, application} = result
  match application:
    case C.OwnerClosed{}: IO.print("APPLICATION JOINED")
    case C.OwnerBusy{owner, counts}: IO.die(Unit, 1, "application busy after transport drain")

def live.running(controlled: H.Server<Control> & H.ServerControl, server: C.Server<U.Action, U.State, U.Config, String>, +own: Chan(H.ServerControl), owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, +gate: Chan(Unit), arrived: Chan(Unit)) -> IO(Unit):
  (control_server, stop) = controlled
  do IO<Unit>:
    sent : Bool <- Chan.send(H.ServerControl, own, stop)
    future : Chan(C.ServerExit<U.Action, U.State, U.Config, String>) <- IO.fork(C.ServerExit<U.Action, U.State, U.Config, String>,
      C.server.run(~U.Action, ~U.State, ~U.Config, ~String, ~String, ~done, ~observed, ~U.notify, ~U.report, ~C.access.disabled(~U.Config), server))
    IO.print("READY")
    control_exit : H.ServerExit <- H.server.run(~Control, ~control, ~(context => status => outcome => T.ignore(status, outcome)), control_server)
    application_exit : C.ServerExit<U.Action, U.State, U.Config, String> <- IO.join(C.ServerExit<U.Action, U.State, U.Config, String>, future)
    server.closed(application_exit)
    closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
    store.closed(closed)
    Chan.close(H.ServerControl, own)
    Chan.close(Unit, arrived)
    Chan.close(Unit, gate)
    IO.print("CONTROL JOINED")

def live.controlled(started: Unit & Result<&2, &1, H.StartupError, H.Server<Control>>, server: C.Server<U.Action, U.State, U.Config, String>, own: Chan(H.ServerControl), owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, gate: Chan(Unit), arrived: Chan(Unit)) -> IO(Unit):
  (unit, result) = started
  match result:
    case Fail{error}:
      do IO<Unit>:
        exited : C.ServerExit<U.Action, U.State, U.Config, String> <- C.server.close(~U.Action, ~U.State, ~U.Config, ~String, server)
        server.closed(exited)
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        store.closed(closed)
        Chan.close(H.ServerControl, own)
        Chan.close(Unit, gate)
        Chan.close(Unit, arrived)
        IO.die(Unit, 1, "control startup failed")
    case Done{transport}: live.running(H.server.control(~Control, transport), server, own, owner, gate, arrived)

def live.prepared(controlled: C.Server<U.Action, U.State, U.Config, String> & H.ServerControl, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, +gate: Chan(Unit), arrived: Chan(Unit), port: U32) -> IO(Unit):
  (server, stop) = controlled
  do IO<Unit>:
    +own : Chan(H.ServerControl) <- Chan.new(H.ServerControl, 1)
    started : Unit & Result<&2, &1, H.StartupError, H.Server<Control>> <- H.server.start(~Control, ~Unit, Control{stop, gate, own}, Unit{}, C.server.config(port))
    live.controlled(started, server, own, owner, gate, arrived)

def live.started(result: Result<&2, &1, C.StartupError, C.Server<U.Action, U.State, U.Config, String>>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, gate: Chan(Unit), arrived: Chan(Unit), port: U32) -> IO(Unit):
  match result:
    case Fail{error}:
      do IO<Unit>:
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        store.closed(closed)
        Chan.close(Unit, gate)
        Chan.close(Unit, arrived)
        IO.die(Unit, 1, "application startup failed")
    case Done{server}: live.prepared(C.server.control(~U.Action, ~U.State, ~U.Config, ~String, server), owner, gate, arrived, port)

def start(app: Result<&2, &2, C.RegistrationError, C.Application<U.Action, U.Config, C.Policy<String>>>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, gate: Chan(Unit), arrived: Chan(Unit), port: U32, control_port: U32) -> IO(Unit):
  do IO<Unit>:
    started : Result<&2, &1, C.StartupError, C.Server<U.Action, U.State, U.Config, String>> <- C.server.start(~U.Action, ~U.State, ~U.Config, ~String, ~String,
      ~U.before, ~U.after, ~U.run, ~U.mapper, ~U.destroy, app, C.server.config(port), [U.fresh(), U.fresh(), U.fresh(), U.fresh()])
    live.started(started, owner, gate, arrived, control_port)

def ordinary(is_plain: Bool, config: U.Config, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, gate: Chan(Unit), arrived: Chan(Unit), reverse: Bool, port: U32, control_port: U32) -> IO(Unit):
  match is_plain:
    case True{}: start(U.fixture(config), owner, gate, arrived, port, control_port)
    case False{}: start(U.application(config, reverse), owner, gate, arrived, port, control_port)

def ready.prepared(prepared: C.Owner<U.Store, U32, U.Operation, String, U.User> & C.Context<U.Store, U32, U.Operation, String, U.User>, fixture: String, reverse: Bool, fault: String, port: U32, control_port: U32) -> IO(Unit):
  (owner, context) = prepared
  do IO<Unit>:
    +gate : Chan(Unit) <- Chan.new(Unit, 1)
    +arrived : Chan(Unit) <- Chan.new(Unit, 16)
    config : U.Config = U.Config{context, U.Gate{arrived, gate}, fault}
    ordinary(String.eq(fixture, "plain"), config, owner, gate, arrived, reverse, port, control_port)

def ready(result: Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>>, fixture: String, reverse: Bool, fault: String, port: U32, control_port: U32) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "store startup failed")
    case Done{owner}: ready.prepared(C.owner.context(U.Store, U32, U.Operation, String, U.User, owner), fixture, reverse, fault, port, control_port)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> +fixture <> order <> fault <> port <> control_port <> journal <> Nil{}:
      do IO<Unit>:
        result : Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>> <- C.start(~U.StoreConfig, ~U.Store, ~U32, ~U.Operation, ~String, ~U.User,
          ~U.store.open, ~U.store.work, ~U.store.close, U.StoreConfig{journal, Bool.not(String.eq(fixture, "default"))}, 1n, 16)
        ready(result, fixture, String.eq(order, "reverse"), fault, Maybe.default(&2, U32, U32.read(port), 0), Maybe.default(&2, U32, U32.read(control_port), 0))
    case _: IO.die(Unit, 1, "expected fixture order fault port control-port journal")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
