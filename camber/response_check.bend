# Consumer-visible response safety checks for the provisional scoped application.
import Base
import ./surface_app.bend as Example
import ./interface_check.bend as Registry
import ../http/http.bend as Http

def accepted(result: Result<&2, &1, Example.Err, Http.Res>) -> Bool:
  match result:
    case Done{response}:
      True{}
    case Fail{error}:
      False{}

def rejected(result: Result<&2, &1, Example.Err, Http.Res>) -> Bool:
  match result:
    case Done{response}:
      False{}
    case Fail{Example.InvalidResponse{}}:
      True{}
    case Fail{error}:
      False{}

def bad(name: String, value: String) -> IO(Unit):
  Registry.require(rejected(Example.validate(Http.Res{200, Http.set(Http.empty(), name, value), Http.from_string("private")})), "unsafe header accepted")

def forbidden(names: List<&2, String>) -> IO(Unit):
  match names:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case name <> rest:
      do IO<Unit>:
        bad(name, "close")
        forbidden(rest)

def cookies(values: List<&2, String>, body: Http.Body) -> Bool:
  match values:
    case "a=1" <> "b=2" <> Nil{}:
      String.eq(Http.text(Http.Res{200, Http.empty(), body}), "ok")
    case _:
      False{}

def preserved(result: Result<&2, &1, Example.Err, Http.Res>) -> Bool:
  match result:
    case Done{Http.Res{200, headers, body}}:
      cookies(Http.fields(headers, "set-cookie"), body)
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Registry.require(rejected(Example.validate(Http.Res{199, Http.empty(), Http.from_string("private")})), "1xx application response accepted")
    Registry.require(rejected(Example.validate(Http.Res{600, Http.empty(), Http.from_string("private")})), "invalid status accepted")
    forbidden(["content-length", "transfer-encoding", "keep-alive", "upgrade", "te", "trailer", "proxy-connection"])
    bad("connection", "keep-alive")
    bad("connection", "close, upgrade")
    bad("X-Name", "value")
    bad("", "value")
    bad("bad name", "value")
    bad("bad:name", "value")
    bad("x-name", "value\r\ninjected: yes")
    bad("x-name", SCon{Chr{0}, SNil{}})
    bad("x-name", SCon{Chr{1}, SNil{}})
    bad("x-name", SCon{Chr{127}, SNil{}})
    bad("x-name", SCon{Chr{256}, SNil{}})
    Registry.require(accepted(Example.validate(Http.Res{200, Http.set(Http.empty(), "connection", "close"), Http.from_string("ok")})), "explicit close rejected")
    Registry.require(accepted(Example.validate(Http.Res{200, Http.set(Http.empty(), "x-name", "a\tb"), Http.from_string("ok")})), "HTAB rejected")
    Registry.require(accepted(Example.validate(Http.Res{599, Http.set(Http.empty(), "!#$%&'*+-.^_`|~", SCon{Chr{255}, SNil{}}), Http.from_string("ok")})), "valid status, token punctuation, or obs-text rejected")
    Registry.require(preserved(Example.validate(Http.Res{200, Http.add(Http.set(Http.empty(), "set-cookie", "a=1"), "set-cookie", "b=2"), Http.from_string("ok")})), "cookie values or packed body changed")
    IO.print("response safety: PASS")
