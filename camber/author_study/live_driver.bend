# Finite socket harness for the submitted dispatch function, not a serving API.
# ponytail: one connection and 64 worker turns; production needs admission and cancellation.
import Base
import ./app.bend as App
import ./driver.bend as Driver
import ../contract.bend as Contract
import ../../interface_check.bend as Registry
import ../../../http/http.bend as Http
import ../../../http/pure.bend as Pure
import ../../../http/context_probe.bend as Transport
import bend-kit-json@0.7.3.0/json.bend as Json
import ../../../concurrency/concurrency.bend as Conc
import bend-kit-wire@0.4.8.1/wire.bend as Wire

type Bundle is Type:
  Bundle{state: Contract.State, application: App.Application}

type Context is Data:
  Context{jobs: Chan(Pure.Req & Chan(Pure.Res))}

def packed(application: App.Application, result: Contract.State & Pure.Res) -> IO(Bundle & Pure.Res):
  (Contract.State{journal, events}, response) = result
  do IO<Bundle & Pure.Res>:
    IO.print("TRACE " ++ Pure.text(Pure.Res{200, Pure.empty(), Json.encode.bytes(Json.Arr{Driver.strings(List.reverse(&2, String, events))})}))
    return (Bundle{Contract.State{journal, Nil{}}, application}, response)

def work(bundle: Bundle, request: Pure.Req) -> IO(Bundle & Pure.Res):
  Bundle{state, +application} = bundle
  do IO<Bundle & Pure.Res>:
    result : Contract.State & Pure.Res <- App.dispatch(state, application, request)
    packed(application, result)

def receive(value: Maybe<&1, Pure.Res>) -> IO(Pure.Res):
  match value:
    case None{}:
      IO.die(Pure.Res, 1, "study reply closed early")
    case Some{response}:
      IO.pure(Pure.Res, response)

def handle(context: Context, request: Pure.Req) -> IO(Pure.Res):
  Context{jobs} = context
  do IO<Pure.Res>:
    reply0 : Chan(Pure.Res) <- Chan.new(Pure.Res, 1)
    +reply : Chan(Pure.Res) = reply0
    sent : Result<&1, &1, Pure.Req & Chan(Pure.Res), Unit> <- Chan.send(Pure.Req & Chan(Pure.Res), jobs, (request, reply))
    Registry.require(Result.is_done(&1, &1, Pure.Req & Chan(Pure.Res), Unit, sent), "study worker queue closed early")
    response : Maybe<&1, Pure.Res> <- Chan.recv(Pure.Res, reply)
    receive(response)

def close(mode: String, returned: List<Bundle>) -> IO(Unit):
  match returned:
    case Bundle{Contract.State{journal, events}, application} <> Nil{}:
      do IO<Unit>:
        Driver.observe.mode(mode, journal, Json.Null{})
        IO.print("STUDY LIVE PASS")
    case _:
      IO.die(Unit, 1, "study worker did not return affine state")

def bound(bound: Listener & U32, +jobs: Chan(Pure.Req & Chan(Pure.Res)), workers: List<Chan(Bundle)>, mode: String) -> IO(Unit):
  (listener, port) = bound
  do IO<Unit>:
    IO.print("READY " ++ U32.show(port))
    done : List<Chan(Unit)> <- Transport.accept(~Context, ~handle, 1n, Context{jobs}, 65536n, listener)
    Transport.join(done)
    Chan.close(Pure.Req & Chan(Pure.Res), jobs)
    returned : List<Bundle> <- Conc.pool.join(Bundle, workers)
    close(mode, returned)

def start(path: String, +mode: String, port: U32) -> IO(Unit):
  do IO<Unit>:
    application : App.Application <- App.application()
    journal : File <- IO.try(File, File.open(path, mode))
    jobs0 : Chan(Pure.Req & Chan(Pure.Res)) <- Chan.new(Pure.Req & Chan(Pure.Res), 1)
    +jobs : Chan(Pure.Req & Chan(Pure.Res)) = jobs0
    workers : List<Chan(Bundle)> <- Conc.pool.start(~Bundle, ~Pure.Req, ~Pure.Res, ~work, [Bundle{Contract.State{journal, Nil{}}, application}], 64n, jobs)
    listener : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", port))
    bound(listener, jobs, workers, mode)

def number(port: Maybe<&2, U32>, path: String, mode: String) -> IO(Unit):
  match port:
    case Some{+value}:
      do IO<Unit>:
        Registry.require(U32.is_lt(value, 65536), "invalid fixture port")
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
