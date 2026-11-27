# A local upstream for the gateway checks and demo. It prints each request it serves.
import Base
import bend-kit-http@0.45.0.3/http.bend as H
import bend-kit-http@0.45.0.3/pure.bend as Pure
import bend-kit-http@0.45.0.3/completion.bend as T

# /items/gone is missing, /items/broken fails, /items/slow-* answers after 1.5 s.
def kind(target: String) -> U32:
  match target:
    case "/items/gone":
      1
    case "/items/broken":
      2
    case "/items/slow-a":
      3
    case "/items/slow-b":
      3
    case "/items/slow-c":
      3
    case _:
      0

def answer(k: U32, +target: String) -> IO(Pure.Res):
  match k:
    case 1:
      IO.pure(Pure.Res, Pure.Res{404, Pure.empty(), Pure.from_string("")})
    case 2:
      IO.pure(Pure.Res, Pure.Res{500, Pure.empty(), Pure.from_string("")})
    case 3:
      do IO<Pure.Res>:
        IO.sleep(1500)
        return Pure.Res{200, Pure.empty(), Pure.from_string("slow " ++ target)}
    case _:
      IO.pure(Pure.Res, Pure.Res{200, Pure.empty(), Pure.from_string("item " ++ target)})

def handle(context: Unit, req: Pure.Req) -> IO(H.Reply):
  Pure.Req{method, +target, headers, body} = req
  do IO<H.Reply>:
    IO.print("UPSTREAM " ++ method ++ " " ++ target)
    res : Pure.Res <- answer(kind(target), target)
    return H.Reply{res, T.Unobserved{}}

def config(port: U32) -> Pure.ServerConfig:
  Pure.ServerConfig{"127.0.0.1", port, 1048576, 65536, 64, 64, 64, 5000, 30000, 30000, 30000}

def run(server: H.Server<Unit>) -> IO(Pure.ServerExit):
  H.server.run(~Unit, ~handle, ~(context => status => outcome => T.ignore(status, outcome)), server)

# Starts listening. The caller runs the server and stops it through its control.
def start(port: U32) -> IO(Unit & Result<&2, &1, Pure.StartupError, H.Server<Unit>>):
  H.server.start(~Unit, ~Unit, Unit{}, Unit{}, config(port))

def started(result: Unit & Result<&2, &1, Pure.StartupError, H.Server<Unit>>) -> IO(Unit):
  (unit, r) = result
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "upstream: listen failed")
    case Done{server}:
      do IO<Unit>:
        IO.print("UPSTREAM READY")
        exit : Pure.ServerExit <- run(server)
        return Unit{}

def main.port(port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case Some{p}:
      do IO<Unit>:
        result : Unit & Result<&2, &1, Pure.StartupError, H.Server<Unit>> <- start(p)
        started(result)
    case None{}:
      IO.die(Unit, 1, "upstream: expected a decimal port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> port <> Nil{}:
      main.port(U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: upstream PORT")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
