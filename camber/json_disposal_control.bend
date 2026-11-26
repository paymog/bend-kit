# Dense-array attribution control, not a general JSON decoder or production remedy.
import Base
import bend-kit-json@0.7.3.0/json.bend as Json
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import ../http/http.bend as Http
import ../http/pure.bend as Pure
import ./json_progress_probe.bend as Progress
import bend-kit-time@0.3.0.3/time.bend as Time

# Explicit traversal isolates automatic-erasure cost: https://github.com/bendlang/bend/issues/1307
def numbers(values: List<&1, Json.Val>, count: U32) -> U32:
  match values:
    case Nil{}:
      count
    case Con{Json.Num{Bytes.Bytes{size, buffer}}, rest}:
      numbers(rest, (count + 1 : U32))
    case _:
      4294967295

def document(value: Json.Val) -> Bool:
  match value:
    case Json.Obj{Con{(key, Json.Arr{values}), Nil{}}}:
      U32.is_eq(numbers(values, 0), 524283)
    case _:
      False{}

def parsed(value: Maybe<&1, Json.Val>, started: Time.Duration) -> IO(Pure.Res):
  match value:
    case None{}:
      Progress.result(False{}, started)
    case Some{value}:
      Progress.result(document(value), started)

def work(body: Pure.Body, started: Time.Duration) -> IO(Pure.Res):
  parsed(Json.parse.bytes(body), started)
