# In-process measurements of the experiments, not Camber throughput or its release overhead gate.
import Base
import ./ownership.bend as Users
import ./interface_check.bend as Interface
import ../http/http.bend as Http
import ../time/time.bend as Time

type Workload is Data:
  Dispatch{method: String, path: String}
  Decode{payload: String}
  Echo{payload: String}
  Registry{plan: Interface.Plan<Interface.Action, Interface.Config>, payload: String}

def decoded(value: Maybe<&2, String>) -> U32:
  match value:
    case None{}:
      0
    case Some{text}:
      U32.from_nat(String.length(text))

def response.length(store: Users.Store, status: U32, result: Http.Body & U32) -> Users.Store & U32:
  (body, length) = result
  (store, (status + length : U32))

def response(result: Users.Store & Http.Res) -> Users.Store & U32:
  (store, res) = result
  Http.Res{status, headers, body} = res
  response.length(store, status, Http.length(body))

def sample(job: Workload, store: Users.Store) -> IO(Users.Store & U32):
  match job:
    case Dispatch{method, path}:
      do IO<Users.Store & U32>:
        result : Users.Store & Http.Res <- Users.dispatch(store, Interface.req(method, path, ""))
        return response(result)
    case Decode{payload}:
      IO.pure(Users.Store & U32, (store, decoded(Users.name(Http.from_string(payload)))))
    case Echo{payload}:
      do IO<Users.Store & U32>:
        result : Users.Store & Http.Res <- Interface.run(Interface.Echo{}, Interface.Config{"bench"}, store, Interface.Metadata{"POST", "/echo", Http.set(Http.set(Http.empty(), "authorization", "Bearer alice"), "content-type", "application/json")}, Http.from_string(payload))
        return response(result)
    case Registry{plan, payload}:
      do IO<Users.Store & U32>:
        result : Users.Store & Http.Res <- Interface.invoke(~Users.Store, ~Interface.Action, ~Interface.Config, ~Interface.run, plan, store, Interface.req("POST", "/echo", payload))
        return response(result)

def add(result: Users.Store & U32, hash: U32) -> Users.Store & U32:
  (store, value) = result
  (store, (hash + value : U32))

def loops(n: Nat, +job: Workload, state: Users.Store & U32) -> IO(Users.Store & U32):
  match n:
    case 0n:
      IO.pure(Users.Store & U32, state)
    case 1n+p:
      (store, hash) = state
      do IO<Users.Store & U32>:
        result : Users.Store & U32 <- sample(job, store)
        loops(p, job, add(result, hash))

def report(label: String, dt: Time.Duration, result: Users.Store & U32) -> IO(Users.Store):
  (store, hash) = result
  do IO<Users.Store>:
    IO.print(label ++ "\t" ++ Time.Duration.show_ms(dt) ++ "\t" ++ U32.show(hash))
    return store

def timed.warmed(label: String, n: Nat, job: Workload, warm: Users.Store & U32) -> IO(Users.Store):
  (store, ignored) = warm
  do IO<Users.Store>:
    start : Time.Duration <- Time.mono()
    result : Users.Store & U32 <- loops(n, job, (store, 0))
    finish : Time.Duration <- Time.mono()
    report(label, Time.Duration.sub(finish, start), result)

def timed(label: String, n: Nat, +job: Workload, store: Users.Store) -> IO(Users.Store):
  do IO<Users.Store>:
    warm : Users.Store & U32 <- loops(100n, job, (store, 0))
    timed.warmed(label, n, job, warm)

def entries(n: Nat, tail: List<&2, Interface.Entry<Interface.Action>>) -> List<&2, Interface.Entry<Interface.Action>>:
  match n:
    case 0n:
      tail
    case 1n+ +p:
      entries(p, Interface.Entry{"POST", "/noise/" ++ Nat.show(p), Interface.Echo{}} <> tail)

def registry(size: Nat, payload: String) -> Workload:
  Registry{Interface.Plan{entries(Nat.sub(size, 1n), [Interface.Entry{"POST", "/echo", Interface.Echo{}}]), Interface.Config{"bench"}}, payload}

def scenario(+n: Nat, path: String) -> IO(Unit):
  +json_payload = "{\"name\":\"Cara\"}" ++ String.repeat(" ", 1009n)
  +echo_payload = String.repeat("x", 1024n)
  +ten = registry(10n, echo_payload)
  +hundred = registry(100n, echo_payload)
  +thousand = registry(1000n, echo_payload)
  do IO<Unit>:
    s0 : Users.Store <- Users.open(path, "w")
    s2 : Users.Store <- timed("health", n, Dispatch{"GET", "/health"}, s0)
    s3 : Users.Store <- timed("parameter", n, Dispatch{"GET", "/users/7"}, s2)
    s4 : Users.Store <- timed("invalid-id", n, Dispatch{"GET", "/users/abc"}, s3)
    s5 : Users.Store <- timed("json-1k", n, Decode{json_payload}, s4)
    s6 : Users.Store <- timed("echo-1k", n, Echo{echo_payload}, s5)
    s7 : Users.Store <- timed("registry-10", n, ten, s6)
    s8 : Users.Store <- timed("registry-100", n, hundred, s7)
    s9 : Users.Store <- timed("registry-1000", n, thousand, s8)
    Users.close(s9)

def count(value: Maybe<&2, Nat>, path: String) -> IO(Unit):
  match value:
    case None{}:
      IO.die(Unit, 1, "invalid iteration count")
    case Some{n}:
      scenario(n, path)

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> n <> path <> Nil{}:
      count(Nat.read(n), path)
    case _:
      IO.die(Unit, 1, "usage: dispatch_bench <iterations> <temporary-journal-path>")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
