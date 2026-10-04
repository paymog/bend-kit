# Compiled public application consumer; no listener and no transport simulation.
import Base
import ./camber.bend as C
import bend-kit-http@0.25.0.2/http.bend as H
import bend-kit-router@0.2.0.0/router.bend as R
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as B

def require(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, label)


def response(result: Result<&2, &1, C.ResponseError, H.Res>) -> IO(H.Res):
  match result:
    case Fail{error}:
      IO.die(H.Res, 1, "valid response rejected")
    case Done{res}:
      IO.pure(H.Res, res)

def completion(value: C.Completion<Unit, Unit>) -> H.Res:
  C.Completed{state, response, entered, mapped, stopped} = value
  response

def policy.name(id: U32) -> String:
  match id:
    case 0: "root"
    case 1: "users"
    case 2: "nested"
    case 3: "literal"
    case 4: "post"
    case 5: "me"
    case 6: "home"
    case 7: "slash"
    case 8: "head"
    case 9: "options"
    case 10: "get"
    case 11: "unicode"
    case 12: "parameter"
    case 13: "specific"
    case _: "plain"

def policy.id(name: String) -> U32:
  match name:
    case "root": 0
    case "users": 1
    case "nested": 2
    case "literal": 3
    case "post": 4
    case "me": 5
    case "home": 6
    case "slash": 7
    case "head": 8
    case "options": 9
    case "get": 10
    case "unicode": 11
    case "parameter": 12
    case "specific": 13
    case _: 14

def policy(name: String) -> C.Policy<Unit>:
  C.policy(~Unit, policy.id(name), Nil{}, Nil{})

def route.convert(route: C.Route<U32, String>) -> C.Route<U32, C.Policy<Unit>>:
  C.Route{method, path, action, groups, name} = route
  C.Route{method, path, action, groups, policy(name)}

def group.convert(group: C.Group<String>) -> C.Group<C.Policy<Unit>>:
  C.Group{id, ancestors, name} = group
  C.Group{id, ancestors, policy(name)}

def data.map(~A: Data, ~B: Data, ~f: A -> B, xs: List<&2, A>) -> List<&2, B>:
  match xs:
    case Nil{}:
      Nil{}
    case x <> rest:
      f(x) <> data.map(~A, ~B, ~f, rest)

def ready(result: Result<&2, &2, C.RegistrationError, C.Application<U32, String, C.Policy<Unit>>>) -> IO(C.Application<U32, String, C.Policy<Unit>>):
  match result:
    case Fail{error}:
      IO.die(C.Application<U32, String, C.Policy<Unit>>, 1, "valid application rejected")
    case Done{app}:
      IO.pure(C.Application<U32, String, C.Policy<Unit>>, app)

def groups() -> List<&2, C.Group<String>>:
  [C.Group{1, [], "users"}, C.Group{2, [1], "nested"}, C.Group{3, [], "literal"}]

def routes() -> List<&2, C.Route<U32, String>>:
  [C.Route{"POST", "/users/:id", 1, [1, 2], "post"},
   C.Route{"GET", "/users/me", 2, [3], "me"},
   C.Route{"GET", "/", 3, [], "home"},
   C.Route{"GET", "/users/", 4, [1], "slash"},
   C.Route{"HEAD", "/users/me", 5, [3], "head"},
   C.Route{"OPTIONS", "/explicit", 6, [], "options"},
   C.Route{"GET", "/users/:name", 7, [1, 2], "get"},
   C.Route{"GET", "/café", 8, [], "unicode"},
   C.Route{"GET", "/:first/b", 9, [], "parameter"},
   C.Route{"GET", "/a/:second", 10, [], "specific"},
   C.Route{"POST", "/echo", 99, [], "plain"}]

def plain(req: H.Req) -> IO(H.Res):
  H.Req{method, path, headers, body} = req
  IO.pure(H.Res, H.Res{200, H.empty(), body})

def value(pair: Map<&2, String> & String) -> String:
  (params, text) = pair
  text

def run(action: U32, context: String, matched: C.Match<String>, req: H.Req) -> IO(H.Res):
  match action:
    case 99:
      plain(req)
    case +id:
      C.Match{target, params, groups, selected, pattern, policies} = matched
      H.Req{method, path, headers, body} = req
      out = H.set(H.set(H.set(H.set(H.set(H.set(H.set(H.empty(), "x-action", U32.show(id)), "x-method", method), "x-selected", selected), "x-capture", value(Map.get(String, "", params, Bool.pick(String, U32.is_eq(id, 1), "id", Bool.pick(String, U32.is_eq(id, 7), "name", "second"))))), "x-policies", String.join(policies, "/")), "x-host", H.header(headers, "host")), "x-context", context)
      IO.pure(H.Res, H.Res{200, out, H.from_string("handler-body")})

def policies.names(policies: List<&2, C.Policy<Unit>>) -> List<&2, String>:
  match policies:
    case Nil{}:
      Nil{}
    case C.Policy{id, before, after} <> rest:
      policy.name(id) <> policies.names(rest)

def empty.before(hook: Unit, state: Unit, config: String, meta: C.Metadata) -> IO(C.Step<Unit, Unit>):
  IO.pure(C.Step<Unit, Unit>, C.Continue{state})

def empty.after(hook: Unit, state: Unit, config: String, response: H.Res) -> IO(Unit & Result<&2, &1, C.Error<Unit>, H.Res>):
  IO.pure(Unit & Result<&2, &1, C.Error<Unit>, H.Res>, (state, Done{response}))

def scoped.run(action: U32, state: Unit, context: String, matched: C.Match<C.Policy<Unit>>, req: H.Req) -> IO(Unit & Result<&2, &1, C.Error<Unit>, H.Res>):
  C.Match{target, params, groups, method, pattern, policies} = matched
  do IO<Unit & Result<&2, &1, C.Error<Unit>, H.Res>>:
    res : H.Res <- run(action, context, C.Match{target, params, groups, method, pattern, policies.names(policies)}, req)
    return (state, Done{res})

def checked(res: H.Res, +status: U32, action: String, allow: String, method: String, selected: String, capture: String, policies: String, host: String) -> IO(Unit):
  H.Res{got, +headers, body} = res
  do IO<Unit>:
    require(U32.is_eq(got, status), "status")
    require(String.eq(H.header(headers, "x-action"), action), "selected action")
    require(String.eq(H.header(headers, "allow"), allow), "Allow")
    require(String.eq(H.header(headers, "x-method"), method), "original method")
    require(String.eq(H.header(headers, "x-selected"), selected), "selected method")
    require(String.eq(H.header(headers, "x-capture"), capture), "single decoded method capture")
    require(String.eq(H.header(headers, "x-policies"), policies), "prepared policies")
    require(String.eq(H.header(headers, "x-host"), host), "absolute-form Host")
    require(String.eq(H.header(headers, "x-context"), Bool.pick(String, U32.is_eq(status, 200), "typed-context", "")), "typed runtime context")
    require(Bool.not(U32.is_eq(status, 200)) || String.eq(B.to_string(body), "handler-body"), "direct dispatch suppressed body")

def check(+app: C.Application<U32, String, C.Policy<Unit>>, +method: String, path: String, +status: U32, action: String, allow: String, selected: String, capture: String, policies: String, host: String) -> IO(Unit):
  do IO<Unit>:
    result : C.Completion<Unit, Unit> <- C.dispatch(~U32, ~Unit, ~String, ~Unit, ~Unit, ~empty.before, ~empty.after, ~scoped.run, ~C.default.mapper(~Unit, ~String, ~Unit), app, Unit{}, H.Req{method, path, H.set(H.empty(), "host", "received.test"), H.from_string("")})
    res : H.Res = completion(result)
    checked(res, status, action, allow, Bool.pick(String, U32.is_eq(status, 200), method, ""), selected, capture, policies, host)

def exercise(+app: C.Application<U32, String, C.Policy<Unit>>) -> IO(Unit):
  do IO<Unit>:
    check(app, "POST", "/users/me", 405, "", "GET, HEAD, OPTIONS", "", "", "", "")
    check(app, "GET", "/users/me", 200, "2", "", "GET", "", "root/literal/me", "received.test")
    check(app, "HEAD", "/users/me", 200, "5", "", "HEAD", "", "root/literal/head", "received.test")
    check(app, "HEAD", "/users/7", 200, "7", "", "GET", "7", "root/users/nested/get", "received.test")
    check(app, "POST", "/users/%252F", 200, "1", "", "POST", "%2F", "root/users/nested/post", "received.test")
    check(app, "GET", "/users/a+b", 200, "7", "", "GET", "a+b", "root/users/nested/get", "received.test")
    check(app, "DELETE", "/users/7", 405, "", "GET, HEAD, OPTIONS, POST", "", "", "", "")
    check(app, "OPTIONS", "/users/7", 204, "", "GET, HEAD, OPTIONS, POST", "", "", "", "")
    check(app, "OPTIONS", "/missing", 404, "", "", "", "", "", "")
    check(app, "OPTIONS", "/explicit", 200, "6", "", "OPTIONS", "", "root/options", "received.test")
    check(app, "GET", "/", 200, "3", "", "GET", "", "root/home", "received.test")
    check(app, "GET", "/users/", 200, "4", "", "GET", "", "root/users/slash", "received.test")
    check(app, "GET", "//users/7", 404, "", "", "", "", "", "")
    check(app, "GET", "/users//7", 404, "", "", "", "", "", "")
    check(app, "GET", "/users/7/", 404, "", "", "", "", "", "")
    check(app, "GET", "/USERS/me", 404, "", "", "", "", "", "")
    check(app, "GET", "/a/b", 200, "10", "", "GET", "b", "root/specific", "received.test")
    check(app, "GET", "/caf%C3%A9", 200, "8", "", "GET", "", "root/unicode", "received.test")
    check(app, "GET", "custom+v1://authority.test/users/me?x=y", 200, "2", "", "GET", "", "root/literal/me", "authority.test")
    check(app, "GET", "http://authority.test", 200, "3", "", "GET", "", "root/home", "authority.test")
    check(app, "GET", "*", 400, "", "", "", "", "", "")
    check(app, "OPTIONS", "*", 204, "", "GET, HEAD, OPTIONS, POST", "", "", "", "")

def invalids(xs: List<&2, String>, +app: C.Application<U32, String, C.Policy<Unit>>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case path <> rest:
      do IO<Unit>:
        check(app, "GET", path, 400, "", "", "", "", "", "")
        invalids(rest, app)

def error(result: Result<&2, &2, C.RegistrationError, C.Application<U32, String, String>>) -> String:
  match result:
    case Done{app}:
      "accepted"
    case Fail{C.InvalidGroups{ids}}:
      "ancestry"
    case Fail{C.RouteError{R.InvalidPattern{pattern}}}:
      "pattern"
    case Fail{C.RouteError{R.InvalidMethod{method}}}:
      "method"
    case Fail{C.RouteError{R.Duplicate{method, pattern}}}:
      "duplicate"
    case Fail{C.RouteError{R.GroupConflict{pattern}}}:
      "conflict"
    case Fail{C.RouteError{R.BadTarget{}}}:
      "target"

def registration(routes: List<&2, C.Route<U32, String>>, expected: String) -> IO(Unit):
  require(String.eq(error(C.application(~U32, ~String, ~String, routes, groups(), "typed-context", "root")), expected), "construction rejection")

def patterns(xs: List<&2, String>) -> IO(Unit):
  match xs:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case path <> rest:
      do IO<Unit>:
        registration([C.Route{"GET", path, 0, [], "route"}], "pattern")
        patterns(rest)

def description(xs: List<&2, R.Description>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case R.Description{method, pattern, ids, hidden} <> rest:
      match hidden:
        case R.Hidden{p, methods} <> Nil{}:
          (String.eq(method, "GET") && String.eq(pattern, "/users/me") && C.groups.equal(ids, [3]) && String.eq(p, "/users/:id") && String.eq(methods, "POST")) || description(rest)
        case _:
          description(rest)

def packed.word(pair: Array<U32> & U32, status: U32, len: U32) -> IO(Unit):
  (buf, word) = pair
  require(U32.is_eq(status, 200) && U32.is_eq(len, 4) && U32.is_eq(word, 796983040), "plain packed body changed")

def packed.checked(res: H.Res) -> IO(Unit):
  H.Res{status, headers, B.Bytes{len, buf}} = res
  packed.word(buf[0], status, len)

def packed(app: C.Application<U32, String, C.Policy<Unit>>) -> IO(Unit):
  # One little-endian packed word: NUL, FF, 80, slash. Not UTF-8 text.
  do IO<Unit>:
    dispatched : C.Completion<Unit, Unit> <- C.dispatch(~U32, ~Unit, ~String, ~Unit, ~Unit, ~empty.before, ~empty.after, ~scoped.run, ~C.default.mapper(~Unit, ~String, ~Unit), app, Unit{}, H.Req{"POST", "/echo", H.empty(), B.Bytes{4, [796983040 : U32*1n]}})
    res : H.Res = completion(dispatched)
    packed.checked(res)
    adapted : Result<&2, &1, C.ResponseError, H.Res> <- C.plain(~plain, H.Req{"POST", "/echo", H.empty(), B.Bytes{4, [796983040 : U32*1n]}})
    plain_res : H.Res <- response(adapted)
    packed.checked(plain_res)

def main() -> IO(Unit):
  do IO<Unit>:
    +app : C.Application<U32, String, C.Policy<Unit>> <- ready(C.application(~U32, ~String, ~C.Policy<Unit>, data.map(~C.Route<U32, String>, ~C.Route<U32, C.Policy<Unit>>, ~route.convert, routes()), data.map(~C.Group<String>, ~C.Group<C.Policy<Unit>>, ~group.convert, groups()), "typed-context", policy("root")))
    reversed : C.Application<U32, String, C.Policy<Unit>> <- ready(C.application(~U32, ~String, ~C.Policy<Unit>, data.map(~C.Route<U32, String>, ~C.Route<U32, C.Policy<Unit>>, ~route.convert, List.reverse(&2, C.Route<U32, String>, routes())), data.map(~C.Group<String>, ~C.Group<C.Policy<Unit>>, ~group.convert, List.reverse(&2, C.Group<String>, groups())), "typed-context", policy("root")))
    exercise(app)
    exercise(reversed)
    invalids(["/x%", "/x%0", "/x%GG", "/x%00", "/x%2f", "/x%C0%AF", "/x%ED%A0%80", "/x%F4%90%80%80", "/x%E2%82", "/x#y", "/x y", "/x\u{80}", "/x\u{7F}", "/?x=%00", "/?x=%FF", "http:///x", "not-a-target"], app)
    patterns(["", "users", "//users", "/users//", "/:id/:id", "/:", "/:9id", "/:a-b", "/x\0"])
    registration([C.Route{"GET", "/users/:id", 1, [], "a"}, C.Route{"GET", "/users/:name", 2, [], "b"}], "duplicate")
    registration([C.Route{"GET", "/x", 1, [1], "a"}, C.Route{"POST", "/x", 2, [3], "b"}], "conflict")
    registration([C.Route{"GET", "/x", 1, [2], "a"}], "ancestry")
    registration([C.Route{"GET", "/x", 1, [9], "a"}], "ancestry")
    registration([C.Route{"bad method", "/x", 1, [], "a"}], "method")
    require(String.eq(error(C.application(~U32, ~String, ~String, [], [C.Group{1, [], "a"}, C.Group{1, [], "b"}], "context", "root")), "ancestry"), "duplicate group")
    require(String.eq(error(C.application(~U32, ~String, ~String, [], [C.Group{1, [2], "a"}, C.Group{2, [1], "b"}], "context", "root")), "ancestry"), "cyclic group")
    require(description(C.describe(~U32, ~String, ~C.Policy<Unit>, app)), "hidden method description")
    packed(app)
    IO.print("camber registration/direct dispatch: PASS")
