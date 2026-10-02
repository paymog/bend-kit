import Base
import ../http/http.bend as Http
import ../json/json.bend as Json
import ./surface_app.bend as Example

def error_kind(error: Example.Err) -> String:
  match error:
    case Example.BadDocument{}:
      "bad-document"
    case Example.Unauthorized{}:
      "unauthorized"
    case Example.Forbidden{}:
      "forbidden"
    case Example.Unsupported{}:
      "unsupported"
    case Example.Missing{}:
      "missing"
    case Example.WriteFailed{}:
      "write"
    case Example.TransformFailed{}:
      "transform"
    case Example.InvalidResponse{}:
      "invalid-response"

def event(value: Example.Stage) -> Json.Val:
  match value:
    case Example.Before{scope, ordinal}:
      Json.Arr{[Json.Str{Json.utf8("before")}, Json.Num{Http.from_string(U32.show(scope))}, Json.Num{Http.from_string(U32.show(ordinal))}]}
    case Example.Decode{}:
      Json.Str{Json.utf8("decode")}
    case Example.Handle{}:
      Json.Str{Json.utf8("handle")}
    case Example.MapError{error}:
      Json.Arr{[Json.Str{Json.utf8("map")}, Json.Str{Json.utf8(error_kind(error))}]}
    case Example.Transform{hook}:
      Json.Arr{[Json.Str{Json.utf8("after")}, Json.Str{Json.utf8(Example.hook.name(hook))}]}

def events(xs: List<&2, Example.Stage>) -> List<&1, Json.Val>:
  match xs:
    case Nil{}:
      Nil{}
    case head <> tail:
      event(head) <> events(tail)

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

def observed(mode: String, result: Example.State & Http.Res) -> IO(Unit):
  (Example.State{journal, trace}, Http.Res{+status, +headers, body}) = result
  report : Json.Val = Json.Obj{[
    (Json.utf8("status"), Json.Num{Http.from_string(U32.show(status))}),
    (Json.utf8("body"), Json.Str{Json.utf8(Http.text(Http.Res{status, Http.empty(), body}))}),
    (Json.utf8("root"), Json.Str{Json.utf8(Http.header(headers, "x-root-policy"))}),
    (Json.utf8("users"), Json.Str{Json.utf8(Http.header(headers, "x-users-policy"))}),
    (Json.utf8("document"), Json.Str{Json.utf8(Http.header(headers, "x-document-policy"))}),
    (Json.utf8("public"), Json.Str{Json.utf8(Http.header(headers, "x-public-policy"))}),
    (Json.utf8("ping"), Json.Str{Json.utf8(Http.header(headers, "x-ping-policy"))}),
    (Json.utf8("authenticate"), Json.Str{Json.utf8(Http.header(headers, "www-authenticate"))}),
    (Json.utf8("trace"), Json.Arr{events(List.reverse(&2, Example.Stage, trace))})]}
  observe.mode(mode, journal, report)

def mapper_mode(mode: String) -> Example.MapperMode:
  match mode:
    case "fail":
      Example.Failing{}
    case "invalid":
      Example.Invalid{}
    case _:
      Example.Normal{}

def run(path: String, +mode: String, fault: String, mapper: String, method: String, target: String, token: String, media: String, body: String, control: String) -> IO(Unit):
  do IO<Unit>:
    journal : File <- IO.try(File, File.open(path, mode))
    result : Example.State & Http.Res <- Example.dispatch(Example.State{journal, Nil{}}, Example.application(fault, mapper_mode(mapper)), Http.Req{method, target, Http.set(Http.set(Http.set(Http.empty(), "authorization", token), "content-type", media), "x-group-control", control), Json.utf8(body)})
    observed(mode, result)

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case program <> path <> mode <> fault <> mapper <> method <> target <> token <> media <> body <> control <> Nil{}:
      run(path, mode, fault, mapper, method, target, token, media, body, control)
    case _:
      IO.die(Unit, 1, "expected journal, mode, fault, mapper, method, target, token, media, body, control")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(xs)
