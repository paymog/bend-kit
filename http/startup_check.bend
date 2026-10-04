# Real-socket startup/context consumer; run with startup_check.py in both lanes.
import Base
import ./http.bend as Http

type Context is Data:
  Context{token: String, calls: Chan(Unit)}

def require(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "startup check failed")

def handle(context: Context, request: Http.Req) -> IO(Http.Res):
  Context{token, calls} = context
  do IO<Http.Res>:
    sent : Bool <- Chan.send(Unit, calls, Unit{})
    require(sent)
    return Http.Res{200, Http.empty(), Http.from_string(token)}

def cleanup.written(written: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (returned, result) = written
  do IO<Unit>:
    IO.pass(Unit, result)
    File.close(returned)
    IO.print("OWNER CLOSED")

def cleanup(file: File, marker: String) -> IO(Unit):
  do IO<Unit>:
    written : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, marker)
    cleanup.written(written)

def second(file: File, +calls: Chan(Unit), first: Chan(Unit), result: Http.Server<Context> & Result<&1, &1, U32 & String, Chan(Unit)>) -> IO(Unit):
  (server, got) = result
  do IO<Unit>:
    finished : Chan(Unit) <- IO.pass(Chan(Unit), got)
    Http.server.close(~Context, server)
    IO.join(Unit, first)
    IO.join(Unit, finished)
    IO.join(Unit, calls)
    IO.join(Unit, calls)
    IO.join(Unit, calls)
    Chan.close(Unit, calls)
    cleanup(file, "success recovered\n")
    IO.print("THREE CALLS")

def accepted(file: File, calls: Chan(Unit), result: Http.Server<Context> & Result<&1, &1, U32 & String, Chan(Unit)>) -> IO(Unit):
  (server, got) = result
  do IO<Unit>:
    finished : Chan(Unit) <- IO.pass(Chan(Unit), got)
    result : Http.Server<Context> & Result<&1, &1, U32 & String, Chan(Unit)> <- Http.server.accept(~Context, ~handle, server)
    second(file, calls, finished, result)

def stopped(file: File, result: Http.Server<Context> & (U32 & String)) -> IO(Unit):
  (server, error) = result
  do IO<Unit>:
    Http.server.close(~Context, server)
    cleanup(file, "accept failed recovered\n")

def success(mode: String, file: File, calls: Chan(Unit), server: Http.Server<Context>) -> IO(Unit):
  match mode:
    case "run":
      do IO<Unit>:
        IO.print("READY")
        result : Http.Server<Context> & (U32 & String) <- Http.server.run(~Context, ~handle, server)
        stopped(file, result)
    case "boundary":
      do IO<Unit>:
        IO.print("READY")
        Http.server.close(~Context, server)
        cleanup(file, "representability boundary accepted\n")
    case _:
      do IO<Unit>:
        IO.print("READY")
        first : Http.Server<Context> & Result<&1, &1, U32 & String, Chan(Unit)> <- Http.server.accept(~Context, ~handle, server)
        accepted(file, calls, first)

def started(mode: String, +calls: Chan(Unit), result: File & Result<&2, &1, Http.StartupError, Http.Server<Context>>) -> IO(Unit):
  (file, startup) = result
  match startup:
    case Fail{error}:
      match error:
        case Http.InvalidConfig{}:
          do IO<Unit>:
            IO.print("INVALID")
            cleanup(file, "invalid recovered\n")
        case Http.BindError{code, message}:
          do IO<Unit>:
            IO.print("BIND FAILED " ++ U32.show(code))
            cleanup(file, "bind recovered\n")
    case Done{server}:
      success(mode, file, calls, server)

def setting(+mode: String, name: String, value: U32) -> U32:
  Bool.pick(U32, String.eq(mode, name), 0, value)

def size(+mode: String, +name: String, value: U32) -> U32:
  Bool.pick(U32, String.eq(mode, "boundary"), Http.limits.representable(),
    Bool.pick(U32, String.eq(mode, name ++ "_over"), (Http.limits.representable() + 1 : U32), setting(mode, name, value)))

def deadline(+mode: String, +name: String, value: U32) -> U32:
  Bool.pick(U32, String.eq(mode, "huge_" ++ name), 2147483648, setting(mode, name, value))

def config(+mode: String, port: U32) -> Http.ServerConfig:
  Http.ServerConfig{"127.0.0.1", Bool.pick(U32, String.eq(mode, "port"), 65536, port),
    size(mode, "body", 16777216), size(mode, "headers", 65536),
    setting(mode, "connections", 128), setting(mode, "requests", 128), setting(mode, "buffered", 128),
    deadline(mode, "header_ms", 5000), deadline(mode, "body_ms", 30000),
    deadline(mode, "idle_ms", 30000), deadline(mode, "write_ms", 30000)}

def run(+mode: String, port: U32, path: String) -> IO(Unit):
  do IO<Unit>:
    token : String <- IO.try(String, IO.get_env("STARTUP_TOKEN"))
    file : File <- IO.try(File, File.open(path, "w"))
    calls0 : Chan(Unit) <- Chan.new(Unit, 4)
    +calls : Chan(Unit) = calls0
    IO.print("CONTEXT CREATED")
    result : File & Result<&2, &1, Http.StartupError, Http.Server<Context>> <- Http.server.start(~Context, ~File, Context{token, calls}, file, config(mode, port))
    started(mode, calls, result)

def port(mode: String, path: String, number: Maybe<&2, U32>) -> IO(Unit):
  match number:
    case Some{value}:
      run(mode, value, path)
    case None{}:
      IO.die(Unit, 1, "invalid port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> number <> path <> Nil{}:
      port(mode, path, U32.read(number))
    case _:
      IO.die(Unit, 1, "usage: startup_check <mode> <port> <owner-path>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
