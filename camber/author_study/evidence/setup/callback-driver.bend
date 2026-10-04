import Base
import ../../../http/http.bend as Http
import ../../../json/json.bend as Json
import ./app.bend as App
import ../contract.bend as Contract

def strings(xs: List<&2, String>) -> List<&1, Json.Val>:
  match xs:
    case Nil{}:
      Nil{}
    case head <> tail:
      Json.Str{Json.utf8(head)} <> strings(tail)

def emit(journal: File, report: Json.Val, readback: String) -> IO(Unit):
  do IO<Unit>:
    File.close(journal)
    IO.print(Http.text(Http.Res{200, Http.empty(), Json.encode.bytes(Json.Obj{[(Json.utf8("response"), report), (Json.utf8("readback"), Json.Str{Json.utf8(readback)})]})}))

def readback(report: Json.Val, result: File & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (journal, outcome) = result
  match outcome:
    case Done{text}:
      emit(journal, report, text)
    case Fail{error}:
      do IO<Unit>:
        File.close(journal)
        IO.die(Unit, 1, "returned journal handle could not read")

def observe.mode(mode: String, journal: File, report: Json.Val) -> IO(Unit):
  match mode:
    case "r":
      do IO<Unit>:
        result : File & Result<&1, &1, U32 & String, String> <- File.read(journal, 4096)
        readback(report, result)
    case _:
      emit(journal, report, "")

def observed(mode: String, result: Contract.State & Http.Res) -> IO(Unit):
  (Contract.State{journal, trace}, Http.Res{+status, +headers, body}) = result
  report : Json.Val = Json.Obj{[
    (Json.utf8("status"), Json.Num{Http.from_string(U32.show(status))}),
    (Json.utf8("body"), Json.Str{Json.utf8(Http.text(Http.Res{status, Http.empty(), body}))}),
    (Json.utf8("root"), Json.Str{Json.utf8(Http.header(headers, "x-root-policy"))}),
    (Json.utf8("protected"), Json.Str{Json.utf8(Http.header(headers, "x-protected-policy"))}),
    (Json.utf8("publish"), Json.Str{Json.utf8(Http.header(headers, "x-publish-policy"))}),
    (Json.utf8("public"), Json.Str{Json.utf8(Http.header(headers, "x-public-policy"))}),
    (Json.utf8("authenticate"), Json.Str{Json.utf8(Http.header(headers, "www-authenticate"))}),
    (Json.utf8("allow"), Json.Str{Json.utf8(Http.header(headers, "allow"))}),
    (Json.utf8("trace"), Json.Arr{strings(List.reverse(&2, String, trace))})]}
  observe.mode(mode, journal, report)

def invoke(~execute: Contract.State -> App.Application -> Http.Req -> IO(Contract.State & Http.Res), state: Contract.State, app: App.Application, request: Http.Req) -> IO(Contract.State & Http.Res):
  execute(state, app, request)

def run(path: String, +mode: String, method: String, target: String, token: String, media: String, body: String) -> IO(Unit):
  do IO<Unit>:
    application : App.Application <- App.application()
    journal : File <- IO.try(File, File.open(path, mode))
    result : Contract.State & Http.Res <- invoke(~App.dispatch, Contract.State{journal, Nil{}}, application, Http.Req{method, target, Http.set(Http.set(Http.empty(), "authorization", token), "content-type", media), Json.utf8(body)})
    observed(mode, result)

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> path <> mode <> method <> target <> token <> media <> body <> Nil{}:
      run(path, mode, method, target, token, media, body)
    case _:
      IO.die(Unit, 1, "expected journal, mode, method, target, token, media, body")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
