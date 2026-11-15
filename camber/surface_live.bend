# Real-socket scoped lifecycle fixture; not a production serving API.
# ponytail: at most two connections and 64 worker turns; production needs admission and cancellation.
import Base
import ./surface_app.bend as Example
import ./author_app.bend as Author
import ./surface_check.bend as Check
import ./interface_check.bend as Registry
import ../http/http.bend as Http
import ../http/context_probe.bend as Transport
import ../json/json.bend as Json
import ../concurrency/concurrency.bend as Conc

type Bundle is Type:
  Bundle{state: Example.State, application: Example.Application}

type Context is Data:
  Context{jobs: Chan(Http.Req & Chan(Http.Res))}

def packed(application: Example.Application, result: Example.State & Http.Res) -> IO(Bundle & Http.Res):
  (Example.State{journal, events}, response) = result
  do IO<Bundle & Http.Res>:
    IO.print("TRACE " ++ Http.text(Http.Res{200, Http.empty(), Json.encode.bytes(Json.Arr{Check.events(List.reverse(&2, Example.Stage, events))})}))
    return (Bundle{Example.State{journal, Nil{}}, application}, response)

def delayed(held: Bool, result: Bundle & Http.Res) -> IO(Bundle & Http.Res):
  match held:
    case False{}:
      IO.pure(Bundle & Http.Res, result)
    case True{}:
      do IO<Bundle & Http.Res>:
        IO.print("RESPONSE HELD")
        IO.sleep(200)
        return result

def work(bundle: Bundle, request: Http.Req) -> IO(Bundle & Http.Res):
  Bundle{state, +application} = bundle
  Http.Req{method, target, +headers, body} = request
  do IO<Bundle & Http.Res>:
    result : Example.State & Http.Res <- Author.dispatch(state, application, Http.Req{method, target, headers, body})
    packed_result : Bundle & Http.Res <- packed(application, result)
    delayed(String.eq(Http.header(headers, "x-delay-response"), "yes"), packed_result)

def receive(value: Maybe<&1, Http.Res>) -> IO(Http.Res):
  match value:
    case None{}:
      IO.die(Http.Res, 1, "scoped reply closed early")
    case Some{response}:
      IO.pure(Http.Res, response)

def handle(context: Context, request: Http.Req) -> IO(Http.Res):
  Context{jobs} = context
  do IO<Http.Res>:
    reply0 : Chan(Http.Res) <- Chan.new(Http.Res, 1)
    +reply : Chan(Http.Res) = reply0
    sent : Result<&1, &1, Http.Req & Chan(Http.Res), Unit> <- Chan.send(Http.Req & Chan(Http.Res), jobs, (request, reply))
    Registry.require(Result.is_done(&1, &1, Http.Req & Chan(Http.Res), Unit, sent), "scoped worker queue closed early")
    response : Maybe<&1, Http.Res> <- Chan.recv(Http.Res, reply)
    receive(response)

def close(mode: String, returned: List<Bundle>) -> IO(Unit):
  match returned:
    case Bundle{Example.State{journal, events}, application} <> Nil{}:
      do IO<Unit>:
        Check.observe.mode(mode, journal, Json.Null{})
        IO.print("SCOPED LIVE PASS")
    case _:
      IO.die(Unit, 1, "scoped worker did not return its affine state")

def start(path: String, +mode: String, fault: String, mapper: String, port: U32, connections: U32) -> IO(Unit):
  do IO<Unit>:
    +application : Example.Application <- Example.application(fault, Check.mapper_mode(mapper))
    journal : File <- IO.try(File, File.open(path, mode))
    jobs0 : Chan(Http.Req & Chan(Http.Res)) <- Chan.new(Http.Req & Chan(Http.Res), 1)
    +jobs : Chan(Http.Req & Chan(Http.Res)) = jobs0
    workers : List<Chan(Bundle)> <- Conc.pool.start(~Bundle, ~Http.Req, ~Http.Res, ~work, [Bundle{Example.State{journal, Nil{}}, application}], 64n, jobs)
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    IO.print("READY")
    done : List<Chan(Unit)> <- Transport.accept(~Context, ~handle, U32.to_nat(connections), Context{jobs}, 8388608n, listener)
    Transport.join(done)
    Chan.close(Http.Req & Chan(Http.Res), jobs)
    returned : List<Bundle> <- Conc.pool.join(Bundle, workers)
    close(mode, returned)

def numbers(port: Maybe<&2, U32>, connections: Maybe<&2, U32>, path: String, mode: String, fault: String, mapper: String) -> IO(Unit):
  match port connections:
    case Some{+value} Some{+count}:
      do IO<Unit>:
        Registry.require(U32.is_gt(value, 0) && U32.is_lt(value, 65536) && U32.is_gt(count, 0) && U32.is_le(count, 2), "invalid fixture port or connection count")
        start(path, mode, fault, mapper, value, count)
    case _ _:
      IO.die(Unit, 1, "invalid port or connection count")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> path <> mode <> fault <> mapper <> port <> connections <> Nil{}:
      numbers(U32.read(port), U32.read(connections), path, mode, fault, mapper)
    case _:
      IO.die(Unit, 1, "usage: surface_live <journal> <mode> <fault> <mapper> <port> <connections>")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
