# Compiled public output helpers and consumer-visible final response safety.
import Base
import ./camber.bend as Example
import ./dispatch_check.bend as Registry
import bend-kit-http@0.30.0.0/http.bend as Http
import bend-kit-json@0.5.1.0/json.bend as Json

type Domain is Data:
  Domain{name: String, secret: String, internal: U32}

def public(value: Domain) -> Json.Val:
  Domain{name, secret, internal} = value
  Json.Obj{[(Json.utf8("name"), Json.Str{Json.utf8(name)})]}

def body(response: Http.Res, +status: U32, content_type: String, value: String) -> Bool:
  Http.Res{got, headers, bytes} = response
  U32.is_eq(got, status) && String.eq(Http.header(headers, "content-type"), content_type) && String.eq(Http.to_string(bytes), value)

def redirect(result: Result<&2, &1, Example.ResponseError, Http.Res>, +status: U32) -> Bool:
  match result:
    case Fail{error}:
      False{}
    case Done{Http.Res{got, headers, bytes}}:
      U32.is_eq(got, status) && String.eq(Http.header(headers, "location"), "/next") && String.eq(Http.to_string(bytes), "")

def redirects(statuses: List<&2, U32>) -> IO(Unit):
  match statuses:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case +status <> rest:
      do IO<Unit>:
        Registry.require(redirect(Example.redirect(status, "/next"), status), "allowed redirect rejected")
        redirects(rest)

def redirect.bad(result: Result<&2, &1, Example.ResponseError, Http.Res>) -> Bool:
  match result:
    case Fail{Example.InvalidRedirect{}}: True{}
    case _: False{}

def direct.run(status: U32, state: Unit, context: String, matched: Example.Match<Example.Policy<Unit>>, req: Http.Req) -> IO(Unit & Result<&2, &1, Example.Error<Unit>, Http.Res>):
  Http.Req{method, path, headers, bytes} = req
  IO.pure(Unit & Result<&2, &1, Example.Error<Unit>, Http.Res>, (state, Done{Example.raw(status, bytes)}))

def direct(+status: U32) -> IO(Unit):
  do IO<Unit>:
    app : Example.Application<U32, String, Example.Policy<Unit>> <- Registry.ready(Example.application(~U32, ~String, ~Example.Policy<Unit>, [Example.Route{"GET", "/", status, [], Example.policy(~Unit, 1, Nil{}, Nil{})}], [], "", Example.policy(~Unit, 0, Nil{}, Nil{})))
    result : Example.Completion<Unit, Unit> <- Example.dispatch(~U32, ~Unit, ~String, ~Unit, ~Unit, ~Registry.empty.before, ~Registry.empty.after, ~direct.run, ~Example.default.mapper(~Unit, ~String, ~Unit), app, Unit{}, Http.Req{"GET", "/", Http.empty(), Http.from_string("kept")})
    response : Http.Res = Registry.completion(result)
    Registry.require(body(response, status, "", "kept"), "direct dispatch suppressed 204/304 body")

def helpers() -> IO(Unit):
  do IO<Unit>:
    Registry.require(body(Example.json(~Domain, ~public, 200, Domain{"visible", "secret", 42}), 200, "application/json", "{\"name\":\"visible\"}"), "public projection leaked internal fields")
    Registry.require(body(Example.text(200, "café"), 200, "text/plain; charset=utf-8", "caf\u{C3}\u{A9}"), "text not UTF-8")
    Registry.require(body(Example.raw(200, Http.from_string("\0\u{FF}")), 200, "", "\0\u{FF}"), "raw bytes changed")
    Registry.require(body(Example.empty(204), 204, "", ""), "empty response")
    Registry.require(body(Example.problem(400, "quote\"\\café\n", ""), 400, "application/problem+json", "{\"type\":\"about:blank\",\"title\":\"quote\\\"\\\\caf\u{C3}\u{A9}\\n\",\"status\":400}"), "Problem Details title not JSON escaped/UTF-8")
    direct(204)
    direct(304)
    redirects([301, 302, 303, 307, 308])
    Registry.require(redirect.bad(Example.redirect(300, "/next")), "invalid redirect status")
    Registry.require(redirect.bad(Example.redirect(304, "/next")), "304 redirect accepted")
    Registry.require(redirect.bad(Example.redirect(302, "")), "missing Location")
    Registry.require(redirect.bad(Example.redirect(302, "/next\r\nx: y")), "unsafe Location")

def accepted(result: Result<&2, &1, Example.ResponseError, Http.Res>) -> Bool:
  match result:
    case Done{response}:
      True{}
    case Fail{error}:
      False{}

def rejected(result: Result<&2, &1, Example.ResponseError, Http.Res>) -> Bool:
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

def preserved(result: Result<&2, &1, Example.ResponseError, Http.Res>) -> Bool:
  match result:
    case Done{Http.Res{200, headers, body}}:
      cookies(Http.fields(headers, "set-cookie"), body)
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    helpers()
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
