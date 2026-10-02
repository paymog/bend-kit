# Raw baseline driver. run_raw.py supplies exact generated route registrations.
import Base
import ./raw_http.bend as Raw
import ../http/http.bend as Http
import bend-kit-time@0.1.0.0/time.bend as Time
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
import bend-kit-int@0.2.0.0/int.bend as Int

type Payload is Data:
  Empty{}
  Json1k{}
  Binary{length: U32}

type Job is Data:
  Job{profile: U32, verb: String, target: String, payload: Payload}

def job(label: String) -> Maybe<&2, Job>:
  match label:
    case "text":
      Some{Job{0, "GET", "/text", Empty{}}}
    case "json":
      Some{Job{0, "GET", "/json", Empty{}}}
    case "parameter":
      Some{Job{0, "GET", "/users/7", Empty{}}}
    case "json-1k":
      Some{Job{0, "POST", "/decode", Json1k{}}}
    case "hooks-0":
      Some{Job{0, "GET", "/hooks/0", Empty{}}}
    case "hooks-1":
      Some{Job{0, "GET", "/hooks/1", Empty{}}}
    case "hooks-5":
      Some{Job{0, "GET", "/hooks/5", Empty{}}}
    case "hit-10":
      Some{Job{10, "GET", "/route/9", Empty{}}}
    case "miss-10":
      Some{Job{10, "GET", "/route/10", Empty{}}}
    case "method-10":
      Some{Job{10, "POST", "/route/9", Empty{}}}
    case "hit-100":
      Some{Job{100, "GET", "/route/99", Empty{}}}
    case "miss-100":
      Some{Job{100, "GET", "/route/100", Empty{}}}
    case "method-100":
      Some{Job{100, "POST", "/route/99", Empty{}}}
    case "hit-1000":
      Some{Job{1000, "GET", "/route/999", Empty{}}}
    case "miss-1000":
      Some{Job{1000, "GET", "/route/1000", Empty{}}}
    case "method-1000":
      Some{Job{1000, "POST", "/route/999", Empty{}}}
    case "echo-64k":
      Some{Job{0, "POST", "/echo", Binary{65536}}}
    case "echo-4m":
      Some{Job{0, "POST", "/echo", Binary{4194304}}}
    case _:
      None{}

def payload(input: Payload) -> Http.Body:
  match input:
    case Empty{}:
      Http.from_string("")
    case Json1k{}:
      Http.from_string("{\"name\":\"Cara\"}" ++ String.repeat(" ", 1009n))
    case Binary{+length}:
      Bytes.Bytes{length, Array.new(U32, Bytes.depth(Bytes.words(length)), 4278222975)}

def media(input: Payload) -> String:
  match input:
    case Binary{length}:
      "application/octet-stream"
    case _:
      "application/json"

def size(input: Payload) -> U32:
  match input:
    case Empty{}:
      0
    case Json1k{}:
      1024
    case Binary{length}:
      length

def headers(+input: Payload) -> Map<&2, List<&2, String>>:
  Http.set(Http.set(Http.set(Http.set(Http.set(Http.empty(), "host", "localhost"), "connection", "keep-alive"), "authorization", "Bearer alice"), "content-type", media(input)), "content-length", U32.show(size(input)))

def basic(req: Http.Req) -> IO(Http.Res):
  Raw.basic(req)

def dispatch(
  ~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool,
  profile: U32, req: Http.Req
) -> IO(Http.Res):
  match profile:
    case 0:
      Raw.basic(req)
    case 10:
      Raw.routes(~r10, req)
    case 100:
      Raw.routes(~r100, req)
    case 1000:
      Raw.routes(~r1000, req)
    case _:
      IO.die(Http.Res, 1, "invalid profile")

def response.length(status: U32, result: Http.Body & U32) -> U32:
  (body, length) = result
  (status + length : U32)

def response(result: Http.Res) -> U32:
  Http.Res{status, headers, body} = result
  response.length(status, Http.length(body))

def loops(
  ~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool,
  n: Nat, +work: Job, +fields: Map<&2, List<&2, String>>, total: U32
) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, total)
    case 1n+p:
      Job{profile, verb, target, input} = work
      do IO<U32>:
        result : Http.Res <- dispatch(~r10, ~r100, ~r1000, profile, Http.Req{verb, target, fields, payload(input)})
        loops(~r10, ~r100, ~r1000, p, work, fields, (total + response(result) : U32))

def report(label: String, elapsed: Time.Duration, total: U32) -> IO(Unit):
  Time.Duration{seconds, nanos} = elapsed
  IO.print(label ++ "\t" ++ Int.I64.show(seconds) ++ "\t" ++ U32.show(nanos) ++ "\t" ++ U32.show(total))

def timed(
  ~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool,
  +label: String, n: Nat, +work: Job, +fields: Map<&2, List<&2, String>>
) -> IO(Unit):
  do IO<Unit>:
    warm : U32 <- loops(~r10, ~r100, ~r1000, 10n, work, fields, 0)
    start : Time.Duration <- Time.mono()
    total : U32 <- loops(~r10, ~r100, ~r1000, n, work, fields, 0)
    finish : Time.Duration <- Time.mono()
    report(label, Time.Duration.sub(finish, start), total)

def direct.job(
  ~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool,
  work: Maybe<&2, Job>, label: String, n: U32
) -> IO(Unit):
  match work:
    case None{}:
      IO.die(Unit, 1, "invalid workload")
    case Some{+value}:
      Job{profile, verb, target, input} = value
      timed(~r10, ~r100, ~r1000, label, U32.to_nat(n), value, headers(input))

def serve(
  ~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool,
  profile: String, port: U32
) -> IO(Unit):
  match profile:
    case "0":
      Http.serve.on.with(~basic, "127.0.0.1", port, 8388608n)
    case "10":
      Http.serve.on.with(~(req => Raw.routes(~r10, req)), "127.0.0.1", port, 8388608n)
    case "100":
      Http.serve.on.with(~(req => Raw.routes(~r100, req)), "127.0.0.1", port, 8388608n)
    case "1000":
      Http.serve.on.with(~(req => Raw.routes(~r1000, req)), "127.0.0.1", port, 8388608n)
    case _:
      IO.die(Unit, 1, "invalid server profile")

def mode(
  ~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool,
  operation: String, +label: String, number: Maybe<&2, U32>
) -> IO(Unit):
  match operation:
    case "direct":
      match number:
        case None{}:
          IO.die(Unit, 1, "invalid iterations")
        case Some{n}:
          direct.job(~r10, ~r100, ~r1000, job(label), label, n)
    case "serve":
      match number:
        case None{}:
          IO.die(Unit, 1, "invalid port")
        case Some{port}:
          serve(~r10, ~r100, ~r1000, label, port)
    case _:
      IO.die(Unit, 1, "invalid mode")

def args(~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool, xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> operation <> label <> number <> Nil{}:
      mode(~r10, ~r100, ~r1000, operation, label, U32.read(number))
    case _:
      IO.die(Unit, 1, "usage: direct <workload> <iterations> | serve <profile> <port>")

def run(~r10: U32 -> Bool, ~r100: U32 -> Bool, ~r1000: U32 -> Bool) -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(~r10, ~r100, ~r1000, xs)
