# Paired raw/scoped measurements with identical request factories and routing.
import Base
import ./raw_bench.bend as Raw
import ./lifecycle_http.bend as Scoped
import ../http/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time

def loops(~dispatch: U32 -> Http.Req -> IO(Http.Res), n: Nat, +work: Raw.Job, +fields: Map<&2, List<&2, String>>, total: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, total)
    case 1n+p:
      Raw.Job{profile, verb, target, input} = work
      do IO<U32>:
        response : Http.Res <- dispatch(profile, Http.Req{verb, target, fields, Raw.payload(input)})
        loops(~dispatch, p, work, fields, (total + Raw.response(response) : U32))

def timed(~dispatch: U32 -> Http.Req -> IO(Http.Res), +label: String, n: U32, +work: Raw.Job, +fields: Map<&2, List<&2, String>>) -> IO(Unit):
  do IO<Unit>:
    warm : U32 <- loops(~dispatch, 100n, work, fields, 0)
    start : Time.Duration <- Time.mono()
    total : U32 <- loops(~dispatch, U32.to_nat(n), work, fields, 0)
    finish : Time.Duration <- Time.mono()
    Raw.report(label, Time.Duration.sub(finish, start), total)

def direct(~dispatch: U32 -> Http.Req -> IO(Http.Res), label: String, n: U32, work: Maybe<&2, Raw.Job>) -> IO(Unit):
  match work:
    case None{}:
      IO.die(Unit, 1, "invalid workload")
    case Some{+job}:
      Raw.Job{profile, verb, target, input} = job
      timed(~dispatch, label, n, job, Raw.headers(input))

def serve(~dispatch: U32 -> Http.Req -> IO(Http.Res), profile: String, port: U32) -> IO(Unit):
  match profile:
    case "0":
      Http.serve.on.with(~(req => dispatch(0, req)), "127.0.0.1", port, 8388608n)
    case "10":
      Http.serve.on.with(~(req => dispatch(10, req)), "127.0.0.1", port, 8388608n)
    case "100":
      Http.serve.on.with(~(req => dispatch(100, req)), "127.0.0.1", port, 8388608n)
    case "1000":
      Http.serve.on.with(~(req => dispatch(1000, req)), "127.0.0.1", port, 8388608n)
    case _:
      IO.die(Unit, 1, "invalid profile")

def execute(~business: U32 -> Http.Req -> IO(Http.Res), number: Maybe<&2, U32>, operation: String, +label: String) -> IO(Unit):
  match number:
    case None{}:
      IO.die(Unit, 1, "invalid count or port")
    case Some{n}:
      match operation:
        case "raw-direct":
          direct(~business, label, n, Raw.job(label))
        case "scoped-direct":
          direct(~(profile => req => Scoped.dispatch(~business, profile, req)), label, n, Raw.job(label))
        case "raw-serve":
          serve(~business, label, n)
        case "scoped-serve":
          serve(~(profile => req => Scoped.dispatch(~business, profile, req)), label, n)
        case _:
          IO.die(Unit, 1, "invalid operation")

def args(~business: U32 -> Http.Req -> IO(Http.Res), xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> operation <> label <> number <> Nil{}:
      execute(~business, U32.read(number), operation, label)
    case _:
      IO.die(Unit, 1, "usage: <raw|scoped>-<direct|serve> <workload|profile> <iterations|port>")

def run(~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool) -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(~(profile => req => Raw.dispatch(~r10, ~r100, ~r1000, profile, req)), xs)
