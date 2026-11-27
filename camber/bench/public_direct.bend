import Base
import ./public_app.bend as A
import ./public_main.bend as M
import bend-kit-camber@0.19.0.2/camber.bend as C
import bend-kit-http@0.45.0.2/http.bend as Http
import bend-kit-http@0.45.0.2/pure.bend as Pure
import bend-kit-bytes@0.3.3.3/bytes.bend as B
import bend-kit-time@0.3.0.5/pure.bend as Time
import bend-kit-int@0.2.0.0/int.bend as Int
import bend-kit-files@0.4.0.3/files.bend as F

def payload(label: String) -> Pure.Body:
  match label:
    case "json-1k": Pure.from_string("{\"name\":\"Cara\"}" ++ String.repeat(" ", 1009n))
    case "echo-64k": B.Bytes{65536, Array.new(U32, B.depth(B.words(65536)), 4278222975)}
    case "echo-4m": B.Bytes{4194304, Array.new(U32, B.depth(B.words(4194304)), 4278222975)}
    case _: Pure.from_string("")
def response.length(status: U32, pair: Pure.Body & U32) -> U32:
  (returned, length) = pair
  (status + length : U32)
def response(res: Pure.Res) -> U32:
  Pure.Res{status, headers, body} = res
  response.length(status, Pure.length(body))
def dispatched(completion: C.Completion<U32, U32>) -> U32:
  C.Completed{state, res, entered, mapped, stopped} = completion
  response(res)
def camber(n: Nat, +app: C.Application<A.Action, A.Config, C.Policy<U32>>, +settings: A.Config, +label: String, +verb: String, +path: String, +headers: Map<&2, List<&2, String>>, total: U32) -> IO(U32):
  match n:
    case 0n: IO.pure(U32, total)
    case 1n+p:
      do IO<U32>:
        completion : C.Completion<U32, U32> <- C.dispatch(~A.Action, ~U32, ~A.Config, ~String, ~U32, ~A.Config, ~A.before, ~A.after, ~A.run, ~A.mapper, ~A.notify, ~A.report, settings, C.access.disabled(~A.Config, settings), app, 0, Pure.Req{verb, path, headers, payload(label)})
        camber(p, app, settings, label, verb, path, headers, (total + dispatched(completion) : U32))
def raw(n: Nat, +context: M.Raw, +label: String, +verb: String, +path: String, +headers: Map<&2, List<&2, String>>, total: U32) -> IO(U32):
  match n:
    case 0n: IO.pure(U32, total)
    case 1n+p:
      do IO<U32>:
        res : Pure.Res <- M.raw.dispatch(context, Pure.Req{verb, path, headers, payload(label)})
        raw(p, context, label, verb, path, headers, (total + response(res) : U32))
def report(elapsed: Time.Duration, sum: U32) -> IO(Unit):
  Time.Duration{seconds, nanos} = elapsed
  IO.print("DIRECT\t" ++ Int.I64.show(seconds) ++ "\t" ++ U32.show(nanos) ++ "\t" ++ U32.show(sum))
def registered(result: Result<&2, &2, C.RegistrationError, C.Application<A.Action, A.Config, C.Policy<U32>>>, +settings: A.Config, +label: String, +verb: String, +path: String, +headers: Map<&2, List<&2, String>>, count: U32) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "construction failed")
    case Done{+app}:
      do IO<Unit>:
        warm : U32 <- camber(10n, app, settings, label, verb, path, headers, 0)
        start : Time.Duration <- Http.clock.mono()
        sum : U32 <- camber(U32.to_nat(count), app, settings, label, verb, path, headers, 0)
        finish : Time.Duration <- Http.clock.mono()
        report(Time.Duration.sub(finish, start), sum)
def headers() -> Map<&2, List<&2, String>>:
  Pure.set(Pure.set(Pure.empty(), "authorization", "Bearer alice"), "content-type", "application/json")
def timed(mode: String, count: U32, profile: U32, +label: String, +verb: String, +path: String, +settings: A.Config) -> IO(Unit):
  match mode:
    case "raw":
      do IO<Unit>:
        +fields : Map<&2, List<&2, String>> = headers()
        +context : M.Raw <- M.raw(profile, settings)
        warm : U32 <- raw(10n, context, label, verb, path, fields, 0)
        start : Time.Duration <- Http.clock.mono()
        sum : U32 <- raw(U32.to_nat(count), context, label, verb, path, fields, 0)
        finish : Time.Duration <- Http.clock.mono()
        report(Time.Duration.sub(finish, start), sum)
    case "camber": registered(A.application(profile, settings), settings, label, verb, path, headers(), count)
    case _: IO.die(Unit, 1, "expected raw or camber")
def written(pair: File & Result<&1, &1, (U32 & String), Unit>) -> IO(Unit):
  (file, result) = pair
  do IO<Unit>:
    File.close(file)
    IO.pass(Unit, result)
def write(file: File, body: Pure.Body) -> IO(Unit):
  B.Bytes{length, words} = body
  do IO<Unit>:
    result : File & Result<&1, &1, (U32 & String), Unit> <- F.write.words(file, length, words)
    written(result)
def emit.sized(status: U32, +fields: Map<&2, List<&2, String>>, output: String, pair: Pure.Body & U32) -> IO(Unit):
  (body, length) = pair
  do IO<Unit>:
    IO.print("PARITY\t" ++ U32.show(status) ++ "\t" ++ U32.show(length))
    IO.print("HEADER content-type=" ++ Pure.header(fields, "content-type"))
    IO.print("HEADER allow=" ++ Pure.header(fields, "allow"))
    IO.print("HEADER x-hook-count=" ++ Pure.header(fields, "x-hook-count"))
    IO.print("HEADER www-authenticate=" ++ Pure.header(fields, "www-authenticate"))
    file : File <- IO.try(File, File.open(output, "w"))
    write(file, body)
def emit.res(response: Pure.Res, output: String) -> IO(Unit):
  Pure.Res{status, fields, body} = response
  emit.sized(status, fields, output, Pure.length(body))
def emit.completed(completion: C.Completion<U32, U32>, output: String) -> IO(Unit):
  C.Completed{state, response, entered, mapped, stopped} = completion
  emit.res(response, output)
def parity.registered(result: Result<&2, &2, C.RegistrationError, C.Application<A.Action, A.Config, C.Policy<U32>>>, +settings: A.Config, label: String, verb: String, path: String, output: String) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "parity construction failed")
    case Done{app}:
      do IO<Unit>:
        completion : C.Completion<U32, U32> <- C.dispatch(~A.Action, ~U32, ~A.Config, ~String, ~U32, ~A.Config, ~A.before, ~A.after, ~A.run, ~A.mapper, ~A.notify, ~A.report, settings, C.access.disabled(~A.Config, settings), app, 0, Pure.Req{verb, path, headers(), payload(label)})
        emit.completed(completion, output)
def boundary(mode: String, profile: U32, label: String, verb: String, path: String, argument: String, +settings: A.Config) -> IO(Unit):
  match mode:
    case "parity-raw":
      do IO<Unit>:
        context : M.Raw <- M.raw(profile, settings)
        response : Pure.Res <- M.raw.dispatch(context, Pure.Req{verb, path, headers(), payload(label)})
        emit.res(response, argument)
    case "parity-camber": parity.registered(A.application(profile, settings), settings, label, verb, path, argument)
    case _: timed(mode, Maybe.default(&2, U32, U32.read(argument), 1), profile, label, verb, path, settings)
def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> mode <> profile <> label <> verb <> path <> count <> Nil{}:
      do IO<Unit>:
        +gate : Chan(Unit) <- Chan.new(Unit, 1)
        boundary(mode, Maybe.default(&2, U32, U32.read(profile), 0), label, verb, path, count, A.Config{gate, 1})
        Chan.close(Unit, gate)
    case _: IO.die(Unit, 1, "expected mode profile workload verb path iterations")
def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
