# Finite socket harness for the submitted dispatch function, not a serving API.
# ponytail: one connection and 64 worker turns; production needs admission and cancellation.
import Base
import ./app.bend as App
import ./driver.bend as Driver
import ../contract.bend as Contract
import ../../interface_check.bend as Registry
import ../../../http/http.bend as Http
import ../../../http/context_probe.bend as Transport
import ../../../json/json.bend as Json
import ../../../concurrency/concurrency.bend as Conc

type Bundle is Type:
  Bundle{state: Contract.State, application: App.Application}

type Context is Data:
  Context{jobs: Chan(Http.Req & Chan(Http.Res))}

def packed(application: App.Application, result: Contract.State & Http.Res) -> IO(Bundle & Http.Res):
  (Contract.State{journal, events}, response) = result
  do IO<Bundle & Http.Res>:
    IO.print("TRACE " ++ Http.text(Http.Res{200, Http.empty(), Json.encode.bytes(Json.Arr{Driver.strings(List.reverse(&2, String, events))})}))
    return (Bundle{Contract.State{journal, Nil{}}, application}, response)

def work(bundle: Bundle, request: Http.Req) -> IO(Bundle & Http.Res):
  Bundle{state, +application} = bundle
  do IO<Bundle & Http.Res>:
    result : Contract.State & Http.Res <- App.dispatch(state, application, request)
    packed(application, result)

def receive(value: Maybe<&1, Http.Res>) -> IO(Http.Res):
  match value:
    case None{}:
      IO.die(Http.Res, 1, "study reply closed early")
    case Some{response}:
      IO.pure(Http.Res, response)

def handle(context: Context, request: Http.Req) -> IO(Http.Res):
  Context{jobs} = context
  do IO<Http.Res>:
    reply0 : Chan(Http.Res) <- Chan.new(Http.Res, 1)
    +reply : Chan(Http.Res) = reply0
    sent : Bool <- Chan.send(Http.Req & Chan(Http.Res), jobs, (request, reply))
    Registry.require(sent, "study worker queue closed early")
    response : Maybe<&1, Http.Res> <- Chan.recv(Http.Res, reply)
    receive(response)

def close(mode: String, returned: List<Bundle>) -> IO(Unit):
  match returned:
    case Bundle{Contract.State{journal, events}, application} <> Nil{}:
      do IO<Unit>:
        Driver.observe.mode(mode, journal, Json.Null{})
        IO.print("STUDY LIVE PASS")
    case _:
      IO.die(Unit, 1, "study worker did not return affine state")

def start(path: String, +mode: String, port: U32) -> IO(Unit):
  do IO<Unit>:
    application : App.Application <- App.application()
    journal : File <- IO.try(File, File.open(path, mode))
    jobs0 : Chan(Http.Req & Chan(Http.Res)) <- Chan.new(Http.Req & Chan(Http.Res), 1)
    +jobs : Chan(Http.Req & Chan(Http.Res)) = jobs0
    workers : List<Chan(Bundle)> <- Conc.pool.start(~Bundle, ~Http.Req, ~Http.Res, ~work, [Bundle{Contract.State{journal, Nil{}}, application}], 64n, jobs)
    listener : Listener <- IO.try(Listener, TCP.listen("127.0.0.1", port))
    done : List<Chan(Unit)> <- Transport.accept(~Context, ~handle, 1n, Context{jobs}, 65536n, listener)
    Transport.join(done)
    Chan.close(Http.Req & Chan(Http.Res), jobs)
    returned : List<Bundle> <- Conc.pool.join(Bundle, workers)
    close(mode, returned)

def number(port: Maybe<&2, U32>, path: String, mode: String) -> IO(Unit):
  match port:
    case Some{+value}:
      do IO<Unit>:
        Registry.require(U32.is_gt(value, 0) && U32.is_lt(value, 65536), "invalid fixture port")
        start(path, mode, value)
    case None{}:
      IO.die(Unit, 1, "invalid port")

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> path <> mode <> port <> Nil{}:
      number(U32.read(port), path, mode)
    case _:
      IO.die(Unit, 1, "expected journal, mode, port")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
