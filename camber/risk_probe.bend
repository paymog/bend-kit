# Observe runtime boundaries, not Camber's public lifecycle or a cancellation implementation.
import Base
import ../http/http.bend as Http
import ../http/context_probe.bend as Transport

def receive(-A: Type, channel: Chan(A)) -> IO(A):
  IO.join(A, channel)

def written(result: File & Result<&1, &1, U32 & String, Unit>) -> IO(File):
  (file, status) = result
  do IO<File>:
    IO.pass(Unit, status)
    return file

def write(file: File, text: String) -> IO(File):
  do IO<File>:
    result : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, text)
    written(result)

def spin(n: Nat, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      spin(p, (acc * 1664525 + 1013904223 : U32))

def cpu(n: Nat) -> IO(Unit):
  do IO<Unit>:
    IO.print("WORK_BEGIN")
    seed : U32 <- IO.try(U32, IO.random_u32())
    IO.print("WORK_END " ++ U32.show(spin(n, seed)))

def unrelated(path: String) -> IO(Unit):
  do IO<Unit>:
    IO.sleep(500)
    file : File <- IO.try(File, File.open(path, "w"))
    done : File <- write(file, "unrelated completed\n")
    File.close(done)
    IO.print("UNRELATED_DONE")

def force() -> IO(Unit):
  do IO<Unit>:
    IO.sleep(100)
    IO.print("FORCE_PROGRAM_HALT")
    IO.die(Unit, 1, "forced whole-program halt, not scoped cancellation")

def held(mode: String, file: File, n: Nat) -> IO(File):
  match mode:
    case "yield_exit":
      do IO<File>:
        IO.print("WORK_BEGIN")
        IO.sleep(5000)
        done : File <- write(file, "late\n")
        IO.print("WORK_END")
        return done
    case "cpu_exit":
      do IO<File>:
        cpu(n)
        done : File <- write(file, "late\n")
        return done
    case _:
      IO.die(File, 1, "unknown forced-exit probe")

def forced(mode: String, +path: String, n: Nat) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    committed : File <- write(file, "committed\n")
    IO.spawn(Unit, unrelated(path ++ ".unrelated"))
    IO.print("TIMER_ARMED")
    IO.spawn(Unit, force())
    done : Chan(File) <- IO.fork(File, held(mode, committed, n))
    returned : File <- receive(File, done)
    File.close(returned)
    IO.print("OWNED_FILE_CLOSED")

def stopped(result: Maybe<&1, Unit>, file: File) -> IO(File):
  match result:
    case None{}:
      do IO<File>:
        IO.print("COOPERATIVE_RETURN")
        return file
    case Some{unit}:
      write(file, "late\n")

def cooperative.work(file: File, stop: Chan(Unit), ready: Chan(Unit)) -> IO(File):
  do IO<File>:
    announced : Bool <- Chan.send(Unit, ready, Unit{})
    result : Maybe<&1, Unit> <- Chan.recv(Unit, stop)
    stopped(result, file)

def cooperative(+path: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    committed : File <- write(file, "committed\n")
    stop0 : Chan(Unit) <- Chan.new(Unit, 1)
    +stop : Chan(Unit) = stop0
    ready0 : Chan(Unit) <- Chan.new(Unit, 1)
    +ready : Chan(Unit) = ready0
    done : Chan(File) <- IO.fork(File, cooperative.work(committed, stop, ready))
    other : Chan(Unit) <- IO.fork(Unit, unrelated(path ++ ".unrelated"))
    receive(Unit, ready)
    IO.print("COOPERATIVE_STOP")
    Chan.close(Unit, stop)
    returned : File <- receive(File, done)
    File.close(returned)
    IO.print("OWNED_FILE_CLOSED")
    receive(Unit, other)
    IO.print("SERVER_WORK_DONE")

def delivery(sent: Bool) -> IO(Unit):
  match sent:
    case True{}:
      IO.die(Unit, 1, "closed result channel accepted a File")
    case False{}:
      IO.print("AFFINE_RESULT_DROPPED")

def deliver(file: File, reply: Chan(File), go: Chan(Unit), finished: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    receive(Unit, go)
    sent : Bool <- Chan.send(File, reply, file)
    delivery(sent)
    reported : Bool <- Chan.send(Unit, finished, Unit{})
    return Unit{}

def abandoned(+path: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    committed : File <- write(file, "committed\n")
    reply0 : Chan(File) <- Chan.new(File, 1)
    +reply : Chan(File) = reply0
    go0 : Chan(Unit) <- Chan.new(Unit, 1)
    +go : Chan(Unit) = go0
    finished0 : Chan(Unit) <- Chan.new(Unit, 1)
    +finished : Chan(Unit) = finished0
    IO.spawn(Unit, deliver(committed, reply, go, finished))
    Chan.close(File, reply)
    sent : Bool <- Chan.send(Unit, go, Unit{})
    receive(Unit, finished)
    IO.print("INSPECT_OPEN_FILES")
    IO.sleep(1500)
    IO.print("SERVER_WORK_DONE")

def handler(context: Unit, request: Http.Req) -> IO(Http.Res):
  do IO<Http.Res>:
    IO.print("HANDLER_ENTERED")
    return Http.Res{200, Http.empty(), Http.from_string("ok")}

def idle(+path: String, port: U32) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    committed : File <- write(file, "committed\n")
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("READY")
    connections : List<Chan(Unit)> <- Transport.accept(~Unit, ~handler, 1n, Unit{}, 1024n, listener)
    Transport.join(connections)
    File.close(committed)
    IO.print("OWNED_FILE_CLOSED")
    IO.print("SERVER_WORK_DONE")

def external(path: String, n: Nat) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File, File.open(path, "w"))
    committed : File <- write(file, "committed\n")
    cpu(n)
    done : File <- write(committed, "late\n")
    File.close(done)
    IO.print("OWNED_FILE_CLOSED")

def run(mode: String, path: String, count: Maybe<&2, Nat>, port: Maybe<&2, U32>) -> IO(Unit):
  match mode count port:
    case "cpu_only" Some{n} Some{p}:
      cpu(n)
    case "external_cpu" Some{n} Some{p}:
      external(path, n)
    case "yield_exit" Some{n} Some{p}:
      forced("yield_exit", path, n)
    case "cpu_exit" Some{n} Some{p}:
      forced("cpu_exit", path, n)
    case "cooperative" Some{n} Some{p}:
      cooperative(path)
    case "abandoned" Some{n} Some{p}:
      abandoned(path)
    case "idle" Some{n} Some{p}:
      idle(path, p)
    case _ _ _:
      IO.die(Unit, 1, "invalid risk probe arguments")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> mode <> path <> count <> port <> Nil{}:
      run(mode, path, Nat.read(count), U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: risk_probe <mode> <owned-path> <iterations> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
