import Base
import ./http.bend as Transport
import bend-kit-http@0.44.0.1/http.bend as Http
import bend-kit-http@0.44.0.1/pure.bend as Pure
import bend-kit-http@0.44.0.1/completion.bend as Completion

def observe(dir: String, status: U32, outcome: Completion.Outcome) -> IO(Unit):
  Completion.ignore(status, outcome)

def running(pair: Http.Server<String> & U32) -> IO(Unit):
  (server, port) = pair
  do IO<Unit>:
    IO.print(U32.show(port))
    exit : Pure.ServerExit <- Transport.server.run(~observe, server)
    Http.server.exited(exit)

def started(pair: Unit & Result<&2, &1, Pure.StartupError, Http.Server<String>>) -> IO(Unit):
  (owner, result) = pair
  match result:
    case Fail{error}:
      IO.die(Unit, 1, "origin startup failed")
    case Done{server}:
      running(Http.server.port(~String, server))

def main() -> IO(Unit):
  do IO<Unit>:
    dir : String <- IO.try(String, IO.get_env("STORAGE_ORIGIN_DIR"))
    server : Unit & Result<&2, &1, Pure.StartupError, Http.Server<String>> <- Http.server.start(~String, ~Unit, dir, Unit{}, Pure.server.config("127.0.0.1", 0))
    started(server)
