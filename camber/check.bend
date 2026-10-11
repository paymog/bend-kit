# Real File bundles, deterministic concurrent principals, failure and close checks.
import Base
import ./camber.bend as Camber
import ./dispatch_check.bend as Dispatch
import ./response_check.bend as Response
import ./scoped_check.bend as Scoped

type Bundle is Type:
  Bundle{slot: Nat, first: File, second: File}

type Config is Data:
  Config{path: String, fail_start: Bool}

type Input is Data:
  Input{hold: Bool, fail: Bool, reverse: Bool, ready: Chan(Nat), release: Chan(Unit)}

def require(ok: Bool, text: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, text)

def second.path(failed: Bool, path: String) -> String:
  match failed:
    case True{}:
      "/definitely-missing-camber-331/bundle"
    case False{}:
      path

def opened.second(slot: Nat, first: File, result: Result<&1, &1, U32 & String, File>) -> IO(Result<&2, &1, U32, Bundle>):
  match result:
    case Fail{error}:
      do IO<Result<&2, &1, U32, Bundle>>:
        File.close(first)
        IO.print("PARTIAL CLOSED")
        return Fail{91}
    case Done{second}:
      IO.pure(Result<&2, &1, U32, Bundle>, Done{Bundle{slot, first, second}})

def opened.first(+path: String, +slot: Nat, fail_start: Bool, result: Result<&1, &1, U32 & String, File>) -> IO(Result<&2, &1, U32, Bundle>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2, &1, U32, Bundle>, Fail{90})
    case Done{first}:
      do IO<Result<&2, &1, U32, Bundle>>:
        second : Result<&1, &1, U32 & String, File> <- File.open(second.path(fail_start && Nat.is_eq(slot, 0n), path ++ "-b-" ++ Nat.show(slot)), "w")
        opened.second(slot, first, second)

def create(config: Config, slot: Nat) -> IO(Result<&2, &1, U32, Bundle>):
  Config{+path, fail_start} = config
  +slot = slot
  do IO<Result<&2, &1, U32, Bundle>>:
    first : Result<&1, &1, U32 & String, File> <- File.open(path ++ "-a-" ++ Nat.show(slot), "w")
    opened.first(path, slot, fail_start, first)

def destroy(bundle: Bundle) -> IO(Unit):
  Bundle{slot, first, second} = bundle
  do IO<Unit>:
    File.close(first)
    File.close(second)
    IO.print("CLOSED " ++ Nat.show(slot))

def write.result(result: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (file, outcome) = result
  do IO<File>:
    IO.pass(Unit, outcome)
    return file

def write(file: File, text: String) -> IO(File):
  do IO<File>:
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, text)
    write.result(result)

def writes(bundle: Bundle, reverse: Bool, +principal: U32) -> IO(Bundle):
  Bundle{slot, first, second} = bundle
  match reverse:
    case False{}:
      do IO<Bundle>:
        a : File <- write(first, U32.show(principal) ++ "\n")
        b : File <- write(second, U32.show(principal) ++ "\n")
        return Bundle{slot, a, b}
    case True{}:
      do IO<Bundle>:
        b : File <- write(second, U32.show(principal) ++ "\n")
        a : File <- write(first, U32.show(principal) ++ "\n")
        return Bundle{slot, a, b}

def wait(hold: Bool, release: Chan(Unit)) -> IO(Unit):
  match hold:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      Camber.receive(Unit, release)

def outcome(fail: Bool, principal: U32) -> Result<&2, &2, U32, U32>:
  match fail:
    case False{}:
      Done{principal}
    case True{}:
      Fail{principal}

def handler(bundle: Bundle, principal: U32, input: Input) -> IO(Bundle & Result<&2, &2, U32, U32>):
  Bundle{+slot, first, second} = bundle
  Input{hold, fail, reverse, ready, release} = input
  +principal = principal
  do IO<Bundle & Result<&2, &2, U32, U32>>:
    announced : Result<&1, &1, Nat, Unit> <- Chan.send(Nat, ready, slot)
    wait(hold, release)
    returned : Bundle <- writes(Bundle{slot, first, second}, reverse, principal)
    return (returned, outcome(fail, principal))

def started(result: Result<&2, &1, U32, Camber.Owner<Bundle, U32, Input, U32, U32>>) -> IO(Camber.Owner<Bundle, U32, Input, U32, U32>):
  match result:
    case Fail{error}:
      IO.die(Camber.Owner<Bundle, U32, Input, U32, U32>, 1, "unexpected startup failure")
    case Done{context}:
      IO.pure(Camber.Owner<Bundle, U32, Input, U32, U32>, context)

def counts(value: Maybe<&2, Camber.Counts>, busy: Nat, completed: Nat, rejected: Nat) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "owner unexpectedly closed")
    case Some{Camber.Counts{+capacity, +in_use, +done, +lost}}:
      do IO<Unit>:
        require(Nat.is_eq(capacity, 2n) && Nat.is_eq(in_use, busy) && Nat.is_eq(done, completed) && Nat.is_eq(lost, rejected), "wrong owner counts")
        IO.print("COUNTS capacity=" ++ Nat.show(capacity) ++ " in_use=" ++ Nat.show(in_use) ++ " completed=" ++ Nat.show(done) ++ " rejected=" ++ Nat.show(lost))

def checked(result: Camber.Outcome<U32, U32>, expected: U32, failed: Bool) -> IO(Unit):
  match result:
    case Camber.Success{+value}:
      do IO<Unit>:
        require(Bool.not(failed) && U32.is_eq(value, expected), "principal success mismatch")
        IO.print("SUCCESS principal=" ++ U32.show(value))
    case Camber.Expected{+error}:
      do IO<Unit>:
        require(failed && U32.is_eq(error, expected), "principal failure mismatch")
        IO.print("EXPECTED principal=" ++ U32.show(error))
    case _:
      IO.die(Unit, 1, "unexpected operation outcome")

def exhausted(result: Camber.Outcome<U32, U32>) -> IO(Unit):
  match result:
    case Camber.Exhausted{}:
      IO.pure(Unit, Unit{})
    case _:
      IO.die(Unit, 1, "exhaustion did not reject")

def busy(result: Camber.OwnerClose<Bundle, U32, Input, U32, U32>) -> IO(Camber.Owner<Bundle, U32, Input, U32, U32>):
  match result:
    case Camber.OwnerBusy{owner, Camber.Counts{capacity, in_use, completed, rejected}}:
      do IO<Camber.Owner<Bundle, U32, Input, U32, U32>>:
        require(Nat.is_eq(in_use, 2n), "close lost occupied capacity")
        return owner
    case Camber.OwnerClosed{}:
      IO.die(Camber.Owner<Bundle, U32, Input, U32, U32>, 1, "closed active resources")

def closed(result: Camber.OwnerClose<Bundle, U32, Input, U32, U32>) -> IO(Unit):
  match result:
    case Camber.OwnerClosed{}:
      IO.pure(Unit, Unit{})
    case Camber.OwnerBusy{owner, counts}:
      IO.die(Unit, 1, "idle close failed")

def failed.start(result: Result<&2, &1, U32, Camber.Owner<Bundle, U32, Input, U32, U32>>) -> IO(Unit):
  match result:
    case Fail{error}:
      require(U32.is_eq(error, 91), "wrong startup error")
    case Done{context}:
      IO.die(Unit, 1, "startup unexpectedly succeeded")

def stopped(result: Camber.Outcome<U32, U32>) -> IO(Unit):
  match result:
    case Camber.Stopped{}:
      IO.pure(Unit, Unit{})
    case _:
      IO.die(Unit, 1, "closed owner accepted work")

def recovery.value(value: Maybe<&2, Camber.Counts>) -> Bool:
  match value:
    case Some{Camber.Counts{capacity, in_use, completed, rejected}}:
      Nat.is_eq(in_use, 0n) && Nat.is_eq(completed, 3n)
    case None{}:
      False{}

def recovery.step(done: Bool, next: Unit -> IO(Unit)) -> IO(Unit):
  match done:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      next(Unit{})

def recovery(fuel: Nat, +context: Camber.Context<Bundle, U32, Input, U32, U32>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit, 1, "closed reply did not restore capacity")
    case 1n+p:
      do IO<Unit>:
        IO.sleep(1)
        value : Maybe<&2, Camber.Counts> <- Camber.inspect(Bundle, U32, Input, U32, U32, context)
        recovery.step(recovery.value(value), u => recovery(p, context))

def bind.failed(result: Result<&1, &1, U32 & String, Listener>) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.pure(Unit, Unit{})
    case Done{listener}:
      do IO<Unit>:
        Listener.close(listener)
        IO.die(Unit, 1, "invalid bind unexpectedly succeeded")

def scenario.opened(opened: Camber.Owner<Bundle, U32, Input, U32, U32>, +path: String) -> IO(Unit):
  Camber.Owner{+context, finished} = opened
  do IO<Unit>:
    IO.print("JOURNAL " ++ path)
    owner : Camber.Owner<Bundle, U32, Input, U32, U32> = Camber.Owner{context, finished}
    ready0 : Chan(Nat) <- Chan.new(Nat, 8)
    +ready : Chan(Nat) = ready0
    release0 : Chan(Unit) <- Chan.new(Unit, 2)
    +release : Chan(Unit) = release0
    a0 : Chan(Camber.Outcome<U32, U32>) <- Chan.new(Camber.Outcome<U32, U32>, 1)
    +a : Chan(Camber.Outcome<U32, U32>) = a0
    b0 : Chan(Camber.Outcome<U32, U32>) <- Chan.new(Camber.Outcome<U32, U32>, 1)
    +b : Chan(Camber.Outcome<U32, U32>) = b0
    sent_a : Result<&1, &1, Camber.Message<Bundle, U32, Input, U32, U32>, Unit> <- Camber.submit(Bundle, U32, Input, U32, U32, context, 7, Input{True{}, False{}, False{}, ready, release}, a)
    sent_b : Result<&1, &1, Camber.Message<Bundle, U32, Input, U32, U32>, Unit> <- Camber.submit(Bundle, U32, Input, U32, U32, context, 8, Input{True{}, True{}, True{}, ready, release}, b)
    require(Result.is_done(&1, &1, Camber.Message<Bundle, U32, Input, U32, U32>, Unit, sent_a) && Result.is_done(&1, &1, Camber.Message<Bundle, U32, Input, U32, U32>, Unit, sent_b), "submissions failed")
    +slot_a : Nat <- Camber.receive(Nat, ready)
    slot_b : Nat <- Camber.receive(Nat, ready)
    require(Bool.not(Nat.is_eq(slot_a, slot_b)), "duplicate handle use")
    held : Maybe<&2, Camber.Counts> <- Camber.inspect(Bundle, U32, Input, U32, U32, context)
    counts(held, 2n, 0n, 0n)
    overflow : Camber.Outcome<U32, U32> <- Camber.call(Bundle, U32, Input, U32, U32, context, 9, Input{False{}, False{}, False{}, ready, release})
    exhausted(overflow)
    close_busy : Camber.OwnerClose<Bundle, U32, Input, U32, U32> <- Camber.close(Bundle, U32, Input, U32, U32, owner)
    returned_owner : Camber.Owner<Bundle, U32, Input, U32, U32> <- busy(close_busy)
    still_held : Maybe<&2, Camber.Counts> <- Camber.inspect(Bundle, U32, Input, U32, U32, context)
    counts(still_held, 2n, 0n, 1n)
    release_a : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, release, Unit{})
    release_b : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, release, Unit{})
    result_a : Camber.Outcome<U32, U32> <- IO.join(Camber.Outcome<U32, U32>, a)
    result_b : Camber.Outcome<U32, U32> <- IO.join(Camber.Outcome<U32, U32>, b)
    checked(result_a, 7, False{})
    checked(result_b, 8, True{})
    Chan.close(Camber.Outcome<U32, U32>, a)
    Chan.close(Camber.Outcome<U32, U32>, b)
    # Reply closure does not close the private resource-return channel.
    abandoned0 : Chan(Camber.Outcome<U32, U32>) <- Chan.new(Camber.Outcome<U32, U32>, 1)
    +abandoned : Chan(Camber.Outcome<U32, U32>) = abandoned0
    Chan.close(Camber.Outcome<U32, U32>, abandoned)
    abandoned_sent : Result<&1, &1, Camber.Message<Bundle, U32, Input, U32, U32>, Unit> <- Camber.submit(Bundle, U32, Input, U32, U32, context, 10, Input{True{}, False{}, False{}, ready, release}, abandoned)
    require(Result.is_done(&1, &1, Camber.Message<Bundle, U32, Input, U32, U32>, Unit, abandoned_sent), "closed reply prevented admission")
    # The next announcement belongs to the closed-reply operation.
    abandoned_slot : Nat <- Camber.receive(Nat, ready)
    recovery_release : Result<&1, &1, Unit, Unit> <- Chan.send(Unit, release, Unit{})
    # Yield to native file helper threads; bound recovery to 5000 observations.
    recovery(5000n, context)
    recovered : Camber.Outcome<U32, U32> <- Camber.call(Bundle, U32, Input, U32, U32, context, 12, Input{False{}, False{}, True{}, ready, release})
    checked(recovered, 12, False{})
    recovered_slot : Nat <- Camber.receive(Nat, ready)
    final : Maybe<&2, Camber.Counts> <- Camber.inspect(Bundle, U32, Input, U32, U32, context)
    counts(final, 0n, 4n, 1n)
    close_idle : Camber.OwnerClose<Bundle, U32, Input, U32, U32> <- Camber.close(Bundle, U32, Input, U32, U32, returned_owner)
    closed(close_idle)
    after : Camber.Outcome<U32, U32> <- Camber.call(Bundle, U32, Input, U32, U32, context, 11, Input{False{}, False{}, False{}, ready, release})
    stopped(after)
    Chan.close(Nat, ready)
    Chan.close(Unit, release)
    failed : Result<&2, &1, U32, Camber.Owner<Bundle, U32, Input, U32, U32>> <- Camber.start(~Config, ~Bundle, ~U32, ~Input, ~U32, ~U32, ~create, ~handler, ~destroy, Config{path ++ "-startup", True{}}, 2n, 8)
    failed.start(failed)
    late_start : Result<&2, &1, U32, Camber.Owner<Bundle, U32, Input, U32, U32>> <- Camber.start(~Config, ~Bundle, ~U32, ~Input, ~U32, ~U32, ~create, ~handler, ~destroy, Config{path ++ "-bind", False{}}, 2n, 8)
    late_owner : Camber.Owner<Bundle, U32, Input, U32, U32> <- started(late_start)
    bind_result : Result<&1, &1, U32 & String, Listener> <- TCP.listen("not-an-ipv4-address", 0)
    bind.failed(bind_result)
    late_closed : Camber.OwnerClose<Bundle, U32, Input, U32, U32> <- Camber.close(Bundle, U32, Input, U32, U32, late_owner)
    closed(late_closed)
    IO.print("camber owner: PASS")

def scenario(+path: String) -> IO(Unit):
  do IO<Unit>:
    startup : Result<&2, &1, U32, Camber.Owner<Bundle, U32, Input, U32, U32>> <- Camber.start(~Config, ~Bundle, ~U32, ~Input, ~U32, ~U32, ~create, ~handler, ~destroy, Config{path, False{}}, 2n, 8)
    opened : Camber.Owner<Bundle, U32, Input, U32, U32> <- started(startup)
    scenario.opened(opened, path)

def main() -> IO(Unit):
  do IO<Unit>:
    seed : U32 <- IO.try(U32, IO.random_u32())
    scenario("camber-owner-336-" ++ U32.show(seed))
    Dispatch.main()
    Response.main()
    Scoped.check()
