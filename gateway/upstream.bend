# A local upstream for the gateway checks and demo. It prints each request it serves.
import Base
import bend-kit-http@0.38.1.1/http.bend as H
import bend-kit-http@0.38.1.1/completion.bend as T

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

def answer(k: U32, +target: String) -> IO(H.Res):
  match k:
    case 1:
      IO.pure(H.Res, H.Res{404, H.empty(), H.from_string("")})
    case 2:
      IO.pure(H.Res, H.Res{500, H.empty(), H.from_string("")})
    case 3:
      do IO<H.Res>:
        IO.sleep(1500)
        return H.Res{200, H.empty(), H.from_string("slow " ++ target)}
    case _:
      IO.pure(H.Res, H.Res{200, H.empty(), H.from_string("item " ++ target)})

def handle(context: Unit, req: H.Req) -> IO(H.Reply):
  H.Req{method, +target, headers, body} = req
  do IO<H.Reply>:
    IO.print("UPSTREAM " ++ method ++ " " ++ target)
    res : H.Res <- answer(kind(target), target)
    return H.Reply{res, T.Unobserved{}}

def config(port: U32) -> H.ServerConfig:
  H.ServerConfig{"127.0.0.1", port, 1048576, 65536, 64, 64, 64, 5000, 30000, 30000, 30000}

def run(server: H.Server<Unit>) -> IO(H.ServerExit):
  H.server.run(~Unit, ~handle, ~(context => status => outcome => T.ignore(status, outcome)), server)

# Starts listening. The caller runs the server and stops it through its control.
def start(port: U32) -> IO(Unit & Result<&2, &1, H.StartupError, H.Server<Unit>>):
  H.server.start(~Unit, ~Unit, Unit{}, Unit{}, config(port))

def started(result: Unit & Result<&2, &1, H.StartupError, H.Server<Unit>>) -> IO(Unit):
  (unit, r) = result
  match r:
    case Fail{e}:
      IO.die(Unit, 1, "upstream: listen failed")
    case Done{server}:
      do IO<Unit>:
        IO.print("UPSTREAM READY")
        exit : H.ServerExit <- run(server)
        return Unit{}

def main.port(port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case Some{p}:
      do IO<Unit>:
        result : Unit & Result<&2, &1, H.StartupError, H.Server<Unit>> <- start(p)
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
