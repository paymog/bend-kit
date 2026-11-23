import Base
import ./http.bend as Http

def ready(server: Http.Server<Unit> & U32) -> IO(Http.Server<Unit>):
  (listening, port) = server
  do IO<Http.Server<Unit>>:
    IO.print("READY " ++ U32.show(port))
    return listening

def started(result: Unit & Result<&2, &1, Http.StartupError, Http.Server<Unit>>) -> IO(Http.Server<Unit>):
  (owner, got) = result
  match got:
    case Fail{error}:
      do IO<Http.Server<Unit>>:
        Http.server.start.failed(error)
        IO.die(Http.Server<Unit>, 1, "server did not start")
    case Done{server}:
      ready(Http.server.port(~Unit, server))

def start(max: Nat) -> IO(Http.Server<Unit>):
  do IO<Http.Server<Unit>>:
    result : Unit & Result<&2, &1, Http.StartupError, Http.Server<Unit>> <-
      Http.server.start(~Unit, ~Unit, Unit{}, Unit{}, Http.server.config.with("127.0.0.1", 0, max))
    started(result)
