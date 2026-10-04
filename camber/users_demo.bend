# Runnable loopback users demo plus a separate loopback owner-stop listener; no supervisor claim.
import Base
import ./users.bend as U
import bend-kit-camber@0.6.0.0/camber.bend as C
import bend-kit-http@0.30.0.0/http.bend as H
import bend-kit-http@0.30.0.0/completion.bend as T

def done(completion: T.Completion<C.ApplicationReport<String>>) -> IO(Unit):
  IO.pure(Unit, Unit{})

def observed(status: U32, outcome: T.Outcome) -> IO(Unit):
  IO.pure(Unit, Unit{})

def store.closed(result: C.OwnerClose<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  match result:
    case C.OwnerClosed{}: IO.print("STORE JOINED")
    case C.OwnerBusy{owner, counts}: IO.die(Unit, 1, "store remains busy")

def server.closed(result: C.ServerExit<U.Action, U.State, U.Config, String>) -> IO(Unit):
  C.ServerExit{transport, application} = result
  match application:
    case C.OwnerClosed{}: IO.print("APPLICATION JOINED")
    case C.OwnerBusy{owner, counts}: IO.die(Unit, 1, "application remains busy")

type Control is Data:
  Control{application: H.ServerControl, self: Chan(H.ServerControl)}

# Owner control is not a fifth public application route and is not a supervisor.
def control(context: Control, req: H.Req) -> IO(H.Reply):
  Control{application, +self} = context
  H.Req{method, path, headers, body} = req
  match method path:
    case "POST" "/stop":
      do IO<H.Reply>:
        accepted : Bool <- H.server.stop(application)
        own : H.ServerControl <- C.receive(H.ServerControl, self)
        own_stopped : Bool <- H.server.stop(own)
        U.require(accepted && own_stopped, "owner stop rejected")
        return H.Reply{C.empty(200), T.Unobserved{}}
    case _ _: IO.pure(H.Reply, H.Reply{C.empty(404), T.Unobserved{}})

def running(controlled: H.Server<Control> & H.ServerControl, server: C.Server<U.Action, U.State, U.Config, String>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, +self: Chan(H.ServerControl)) -> IO(Unit):
  (control_server, stop) = controlled
  do IO<Unit>:
    sent : Bool <- Chan.send(H.ServerControl, self, stop)
    U.require(sent, "owner control initialization failed")
    future : Chan(C.ServerExit<U.Action, U.State, U.Config, String>) <- IO.fork(C.ServerExit<U.Action, U.State, U.Config, String>,
      C.server.run(~U.Action, ~U.State, ~U.Config, ~String, ~String, ~done, ~observed, ~U.notify, ~U.report, ~C.access.disabled(~U.Config), server))
    IO.print("READY users demo (loopback; demonstration bearer seven/eight)")
    control_exit : H.ServerExit <- H.server.run(~Control, ~control, ~(context => status => outcome => T.ignore(status, outcome)), control_server)
    exited : C.ServerExit<U.Action, U.State, U.Config, String> <- IO.join(C.ServerExit<U.Action, U.State, U.Config, String>, future)
    server.closed(exited)
    closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
    store.closed(closed)
    Chan.close(H.ServerControl, self)
    IO.print("OWNER CONTROL JOINED")

def control.started(result: Unit & Result<&2, &1, H.StartupError, H.Server<Control>>, server: C.Server<U.Action, U.State, U.Config, String>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, self: Chan(H.ServerControl)) -> IO(Unit):
  (unit, started) = result
  match started:
    case Fail{error}:
      do IO<Unit>:
        exited : C.ServerExit<U.Action, U.State, U.Config, String> <- C.server.close(~U.Action, ~U.State, ~U.Config, ~String, server)
        server.closed(exited)
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        store.closed(closed)
        Chan.close(H.ServerControl, self)
        IO.die(Unit, 1, "owner control startup failed")
    case Done{transport}: running(H.server.control(~Control, transport), server, owner, self)

def server.controlled(controlled: C.Server<U.Action, U.State, U.Config, String> & H.ServerControl, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, control_port: U32) -> IO(Unit):
  (server, stop) = controlled
  do IO<Unit>:
    +self : Chan(H.ServerControl) <- Chan.new(H.ServerControl, 1)
    result : Unit & Result<&2, &1, H.StartupError, H.Server<Control>> <- H.server.start(~Control, ~Unit, Control{stop, self}, Unit{}, C.server.config(control_port))
    control.started(result, server, owner, self)

def server.started(result: Result<&2, &1, C.StartupError, C.Server<U.Action, U.State, U.Config, String>>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, control_port: U32) -> IO(Unit):
  match result:
    case Fail{error}:
      do IO<Unit>:
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        store.closed(closed)
        IO.die(Unit, 1, "users startup failed")
    case Done{server}: server.controlled(C.server.control(~U.Action, ~U.State, ~U.Config, ~String, server), owner, control_port)

def prepared(prepared: C.Owner<U.Store, U32, U.Operation, String, U.User> & C.Context<U.Store, U32, U.Operation, String, U.User>, port: U32, control_port: U32) -> IO(Unit):
  (owner, context) = prepared
  do IO<Unit>:
    config : U.Config = U.Config{context, U.Disabled{}, ""}
    result : Result<&2, &1, C.StartupError, C.Server<U.Action, U.State, U.Config, String>> <- C.server.start(~U.Action, ~U.State, ~U.Config, ~String, ~String,
      ~U.before, ~U.after, ~U.run, ~U.mapper, ~U.destroy, U.application(config, False{}), C.server.config(port), [U.fresh(), U.fresh(), U.fresh(), U.fresh()])
    server.started(result, owner, control_port)

def opened(result: Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>>, port: U32, control_port: U32) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "store startup failed")
    case Done{owner}: prepared(C.owner.context(U.Store, U32, U.Operation, String, U.User, owner), port, control_port)

def start(port: Maybe<&2, U32>, control: Maybe<&2, U32>, path: String) -> IO(Unit):
  match port control:
    case Some{number} Some{owner_port}:
      do IO<Unit>:
        result : Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>> <- C.start(~U.StoreConfig, ~U.Store, ~U32, ~U.Operation, ~String, ~U.User,
          ~U.store.open, ~U.store.work, ~U.store.close, U.StoreConfig{path, False{}}, 1n, 16)
        opened(result, number, owner_port)
    case _ _: IO.die(Unit, 1, "expected decimal ports")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> port <> control_port <> path <> Nil{}: start(U32.read(port), U32.read(control_port), path)
    case _: IO.die(Unit, 1, "usage: users-demo APP-PORT OWNER-CONTROL-PORT OWNED-JOURNAL-PATH")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
