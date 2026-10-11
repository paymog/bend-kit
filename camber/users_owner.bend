# Explicit channel synchronization: direct principal overlap and one-store ownership failures.
import Base
import ./users.bend as U
import ./users_direct.bend as Check
import bend-kit-camber@0.7.0.0/camber.bend as C
import bend-kit-http@0.32.0.0/http.bend as H

def require.success(outcome: C.Outcome<String, U.User>) -> IO(Unit):
  match outcome:
    case C.Success{U.User{id, name, secret}}: U.require(U32.is_eq(id, 7) && String.eq(name, "Alice"), "store recovery returned wrong user")
    case _: IO.die(Unit, 1, "store recovery failed")

def require.exhausted(outcome: C.Outcome<String, U.User>) -> IO(Unit):
  match outcome:
    case C.Exhausted{}: IO.print("EXHAUSTION OBSERVED")
    case _: IO.die(Unit, 1, "held dependency was incorrectly available")

def idle.counts(counts: Maybe<&2, C.Counts>, next: Unit -> IO(Unit)) -> IO(Unit):
  match counts:
    case Some{C.Counts{capacity, 0n, completed, rejected}}: IO.print("RESTORED SINGLE STORE")
    case _: next(Unit{})

def idle(fuel: Nat, +context: C.Context<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit, 1, "store return never observed")
    case 1n+rest:
      do IO<Unit>:
        counts : Maybe<&2, C.Counts> <- C.inspect(U.Store, U32, U.Operation, String, U.User, context)
        idle.counts(counts, x => idle(rest, context))

def disposed(owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, +context: C.Context<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  do IO<Unit>:
    +reply : Chan(C.Outcome<String, U.User>) <- Chan.new(C.Outcome<String, U.User>, 1)
    Chan.close(C.Outcome<String, U.User>, reply)
    sent : Result<&1, &1, C.Message<U.Store, U32, U.Operation, String, U.User>, Unit> <- C.submit(U.Store, U32, U.Operation, String, U.User, context, 8, U.Lookup{8, True{}}, reply)
    U.require(Result.is_done(&1, &1, C.Message<U.Store, U32, U.Operation, String, U.User>, Unit, sent), "disposed reply submission failed")
    idle(1024n, context)
    recovered : C.Outcome<String, U.User> <- C.call(U.Store, U32, U.Operation, String, U.User, context, 7, U.Lookup{7, False{}})
    require.success(recovered)
    IO.print("DISPOSED REPLY RECOVERED")
    closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
    Check.store.closed(closed)

def busy(result: C.OwnerClose<U.Store, U32, U.Operation, String, U.User>, +context: C.Context<U.Store, U32, U.Operation, String, U.User>, +gate: Chan(Unit), +reply: Chan(C.Outcome<String, U.User>)) -> IO(Unit):
  match result:
    case C.OwnerClosed{}: IO.die(Unit, 1, "busy close destroyed held store")
    case C.OwnerBusy{owner, C.Counts{capacity, in_use, completed, rejected}}:
      do IO<Unit>:
        U.require(Nat.is_eq(in_use, 1n) && Nat.is_eq(capacity, 1n), "wrong held capacity")
        sent : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, gate, Unit{})
        result : C.Outcome<String, U.User> <- C.receive(C.Outcome<String, U.User>, reply)
        require.success(result)
        Chan.close(C.Outcome<String, U.User>, reply)
        Chan.close(Unit, gate)
        idle(1024n, context)
        disposed(owner, context)

def held(owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, +context: C.Context<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  do IO<Unit>:
    +gate : Chan(Unit) <- Chan.new(Unit, 1)
    +reply : Chan(C.Outcome<String, U.User>) <- Chan.new(C.Outcome<String, U.User>, 1)
    sent : Result<&1, &1, C.Message<U.Store, U32, U.Operation, String, U.User>, Unit> <- C.submit(U.Store, U32, U.Operation, String, U.User, context, 7, U.Hold{gate}, reply)
    U.require(Result.is_done(&1, &1, C.Message<U.Store, U32, U.Operation, String, U.User>, Unit, sent), "hold submission failed")
    counts : Maybe<&2, C.Counts> <- C.inspect(U.Store, U32, U.Operation, String, U.User, context)
    # FIFO inspection is after the checkout, not a guessed sleep.
    unavailable : C.Outcome<String, U.User> <- C.call(U.Store, U32, U.Operation, String, U.User, context, 8, U.Lookup{8, False{}})
    require.exhausted(unavailable)
    closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
    busy(closed, context, gate, reply)

def concurrent(app: C.Application<U.Action, U.Config, C.Policy<String>>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, +context: C.Context<U.Store, U32, U.Operation, String, U.User>, +arrived: Chan(Unit), +release: Chan(Unit)) -> IO(Unit):
  +application = app
  do IO<Unit>:
    first : Chan(U.State) <- IO.fork(U.State, Check.dispatch(application, U.fresh(), H.Req{"GET", "/users/me", H.set(H.set(H.empty(), "authorization", "Bearer seven"), "x-hold", "yes"), H.from_string("")}))
    C.receive(Unit, arrived)
    failed : U.State <- Check.dispatch(application, U.fresh(), H.Req{"GET", "/users/me", H.set(H.set(H.empty(), "authorization", "Bearer eight"), "x-store-fail", "yes"), H.from_string("")})
    U.destroy(failed)
    sent : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, release, Unit{})
    U.require(Result.is_done(&1, &1, Unit, Unit, sent), "first request release failed")
    restored : U.State <- IO.join(U.State, first)
    U.destroy(restored)
    recovery : U.State <- Check.dispatch(application, U.fresh(), H.Req{"GET", "/users/me", H.set(H.empty(), "authorization", "Bearer eight"), H.from_string("")})
    U.destroy(recovery)
    Chan.close(Unit, arrived)
    Chan.close(Unit, release)
    idle(1024n, context)
    IO.print("PRINCIPAL ISOLATION WITH ACTUAL STORE FAILURE")
    held(owner, context)

def registered(result: Result<&2, &2, C.RegistrationError, C.Application<U.Action, U.Config, C.Policy<String>>>, owner: C.Owner<U.Store, U32, U.Operation, String, U.User>, context: C.Context<U.Store, U32, U.Operation, String, U.User>, arrived: Chan(Unit), release: Chan(Unit)) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "registration failed")
    case Done{app}: concurrent(app, owner, context, arrived, release)
def started.prepared(prepared: C.Owner<U.Store, U32, U.Operation, String, U.User> & C.Context<U.Store, U32, U.Operation, String, U.User>) -> IO(Unit):
  (owner, +context) = prepared
  do IO<Unit>:
    +arrived : Chan(Unit) <- Chan.new(Unit, 1)
    +release : Chan(Unit) <- Chan.new(Unit, 1)
    registered(U.application(U.Config{context, U.Gate{arrived, release}, "testing"}, False{}), owner, context, arrived, release)


def started(result: Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "store startup failed")
    case Done{owner}: started.prepared(C.owner.context(U.Store, U32, U.Operation, String, U.User, owner))

def initializer.failed(result: Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>>) -> IO(Unit):
  match result:
    case Fail{error}: IO.print("INITIALIZER RETURNED EXPECTED FAILURE")
    case Done{owner}:
      do IO<Unit>:
        closed : C.OwnerClose<U.Store, U32, U.Operation, String, U.User> <- C.close(U.Store, U32, U.Operation, String, U.User, owner)
        Check.store.closed(closed)
        IO.die(Unit, 1, "missing parent unexpectedly opened")

def edge.checked(pair: Map<&2, U.User> & Bool, +next: U32, journal: File, trace: Bool) -> IO(Unit):
  (users, present) = pair
  do IO<Unit>:
    U.require(Bool.not(present) && U32.is_eq(next, 4294967295), "ID limit mutated store or wrapped counter")
    U.store.close(U.Store{users, next, journal, trace})
    IO.print("CREATE ID LIMIT PRESERVED STORE")

def edge.store(store: U.Store) -> IO(Unit):
  U.Store{users, next, journal, trace} = store
  edge.checked(Map.has(&2, U.User, users, "4294967295"), next, journal, trace)

def edge.created(result: U.Store & Result<&2, &2, String, U.User>) -> IO(Unit):
  (store, outcome) = result
  match outcome:
    case Fail{error}:
      do IO<Unit>:
        U.require(String.eq(error, "store ID limit"), "wrong ID limit failure")
        edge.store(store)
    case Done{user}:
      do IO<Unit>:
        U.store.close(store)
        IO.die(Unit, 1, "ID limit was accepted")

def edge.opened(result: Result<&2, &1, String, U.Store>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "ID-limit store failed to open")
    case Done{U.Store{users, next, journal, trace}}:
      do IO<Unit>:
        outcome : U.Store & Result<&2, &2, String, U.User> <- U.store.create("NoWrap", U.Store{users, 4294967295, journal, trace})
        edge.created(outcome)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> +path <> Nil{}:
      do IO<Unit>:
        invalid : Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>> <- C.start(~U.StoreConfig, ~U.Store, ~U32, ~U.Operation, ~String, ~U.User,
          ~U.store.open, ~U.store.work, ~U.store.close, U.StoreConfig{path ++ "/absent", True{}}, 1n, 16)
        initializer.failed(invalid)
        edge : Result<&2, &1, String, U.Store> <- U.store.open(U.StoreConfig{path ++ ".edge", True{}}, 0n)
        edge.opened(edge)
        result : Result<&2, &1, String, C.Owner<U.Store, U32, U.Operation, String, U.User>> <- C.start(~U.StoreConfig, ~U.Store, ~U32, ~U.Operation, ~String, ~U.User,
          ~U.store.open, ~U.store.work, ~U.store.close, U.StoreConfig{path, True{}}, 1n, 16)
        started(result)
    case _: IO.die(Unit, 1, "expected journal path")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
