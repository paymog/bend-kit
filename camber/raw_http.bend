# Raw Http.serve benchmark handlers; no Camber registry, scopes, or resource owners.
import Base
import ../http/http.bend as Http
import ../json/json.bend as Json
import ../router/router.bend as Router
import ./ownership.bend as Inputs

def text(status: U32, body: String) -> Http.Res:
  Http.Res{status, Http.set(Http.empty(), "content-type", "text/plain; charset=utf-8"), Http.from_string(body)}

def method(ok: Bool, allow: String, response: Http.Res) -> Http.Res:
  match ok:
    case True{}:
      response
    case False{}:
      Http.Res{405, Http.set(Http.empty(), "allow", allow), Http.from_string("")}

def get(+verb: String, response: Http.Res) -> Http.Res:
  method(String.eq(verb, "GET") || String.eq(verb, "HEAD"), "GET, HEAD", response)

def id_response(id: U32) -> Http.Res:
  Inputs.json(200, Json.Obj{[(Json.utf8("id"), Json.Num{Http.from_string(U32.show(id))})]})

def id.method(valid: Bool, id: U32) -> Http.Res:
  match valid:
    case False{}:
      Http.Res{405, Http.set(Http.empty(), "allow", "GET, HEAD"), Http.from_string("")}
    case True{}:
      id_response(id)

def id.get(+verb: String, id: U32) -> Http.Res:
  id.method(String.eq(verb, "GET") || String.eq(verb, "HEAD"), id)

def user.id(parsed: Maybe<&2, U32>, verb: String) -> Http.Res:
  match parsed:
    case None{}:
      text(400, "invalid id")
    case Some{id}:
      id.get(verb, id)

def user.text(result: Map<&2, String> & String, verb: String) -> Http.Res:
  (params, id) = result
  user.id(Inputs.id(id), verb)

def user.path(matched: Maybe<&2, Map<&2, String>>, verb: String) -> Http.Res:
  match matched:
    case None{}:
      text(404, "not found")
    case Some{params}:
      user.text(Map.get(String, "", params, "id"), verb)

def decoded(value: Maybe<&2, String>) -> Http.Res:
  match value:
    case None{}:
      text(400, "invalid name")
    case Some{name}:
      Inputs.json(200, Json.Obj{[(Json.utf8("name"), Json.Str{Json.utf8(name)})]})

def decode.media(valid: Bool, body: Http.Body) -> Http.Res:
  match valid:
    case False{}:
      text(415, "unsupported media type")
    case True{}:
      decoded(Inputs.name(body))

def decode.verb(valid: Bool, headers: Map<&2, List<&2, String>>, body: Http.Body) -> Http.Res:
  match valid:
    case False{}:
      Http.Res{405, Http.set(Http.empty(), "allow", "POST"), Http.from_string("")}
    case True{}:
      decode.media(String.eq(Http.header(headers, "content-type"), "application/json"), body)

def hook.accept(valid: Bool, total: U32) -> Maybe<&2, U32>:
  match valid:
    case True{}:
      Some{(total + 1 : U32)}
    case False{}:
      None{}

def hook(headers: Map<&2, List<&2, String>>, total: U32) -> IO(Maybe<&2, U32>):
  IO.pure(Maybe<&2, U32>, hook.accept(String.eq(Http.header(headers, "authorization"), "Bearer alice"), total))

def hooks(n: Nat, +headers: Map<&2, List<&2, String>>, result: Maybe<&2, U32>) -> IO(Http.Res):
  match n:
    case 0n:
      match result:
        case None{}:
          IO.pure(Http.Res, Http.Res{401, Http.set(Http.empty(), "www-authenticate", "Bearer"), Http.from_string("")})
        case Some{total}:
          IO.pure(Http.Res, Http.Res{200, Http.set(Http.set(Http.empty(), "content-type", "application/json"), "x-hook-count", U32.show(total)), Http.from_string("{\"ok\":true}")})
    case 1n+p:
      match result:
        case None{}:
          IO.pure(Http.Res, Http.Res{401, Http.set(Http.empty(), "www-authenticate", "Bearer"), Http.from_string("")})
        case Some{total}:
          do IO<Http.Res>:
            next : Maybe<&2, U32> <- hook(headers, total)
            hooks(p, headers, next)

def hooks.verb(valid: Bool, count: Nat, headers: Map<&2, List<&2, String>>) -> IO(Http.Res):
  match valid:
    case False{}:
      IO.pure(Http.Res, Http.Res{405, Http.set(Http.empty(), "allow", "GET, HEAD"), Http.from_string("")})
    case True{}:
      hooks(count, headers, Some{0})

def basic(req: Http.Req) -> IO(Http.Res):
  Http.Req{+verb, path, headers, body} = req
  match path:
    case "/text":
      IO.pure(Http.Res, get(verb, text(200, "OK\n")))
    case "/json":
      IO.pure(Http.Res, get(verb, Http.Res{200, Http.set(Http.empty(), "content-type", "application/json"), Http.from_string("{\"ok\":true}")}))
    case "/decode":
      IO.pure(Http.Res, decode.verb(String.eq(verb, "POST"), headers, body))
    case "/hooks/0":
      hooks.verb(String.eq(verb, "GET") || String.eq(verb, "HEAD"), 0n, headers)
    case "/hooks/1":
      hooks.verb(String.eq(verb, "GET") || String.eq(verb, "HEAD"), 1n, headers)
    case "/hooks/5":
      hooks.verb(String.eq(verb, "GET") || String.eq(verb, "HEAD"), 5n, headers)
    case "/echo":
      IO.pure(Http.Res, method(String.eq(verb, "POST"), "POST", Http.Res{200, Http.set(Http.empty(), "content-type", "application/octet-stream"), body}))
    case _:
      IO.pure(Http.Res, user.path(Router.route("GET", "GET", "/users/:id", path), verb))

def route.checked(known: Bool, id: U32, verb: String) -> Http.Res:
  match known:
    case False{}:
      text(404, "not found")
    case True{}:
      id.get(verb, id)

def route.id(~registered: U32 -> Bool, parsed: Maybe<&2, U32>, path: String, verb: String) -> Http.Res:
  match parsed:
    case None{}:
      text(404, "not found")
    case Some{+id}:
      route.checked(registered(id) && String.eq(path, "/route/" ++ U32.show(id)), id, verb)

def route.text(~registered: U32 -> Bool, result: Map<&2, String> & String, path: String, verb: String) -> Http.Res:
  (params, id) = result
  route.id(~registered, Inputs.id(id), path, verb)

def route.path(~registered: U32 -> Bool, matched: Maybe<&2, Map<&2, String>>, path: String, verb: String) -> Http.Res:
  match matched:
    case None{}:
      text(404, "not found")
    case Some{params}:
      route.text(~registered, Map.get(String, "", params, "id"), path, verb)

def routes(~registered: U32 -> Bool, req: Http.Req) -> IO(Http.Res):
  Http.Req{verb, +path, headers, body} = req
  IO.pure(Http.Res, route.path(~registered, Router.route("GET", "GET", "/route/:id", path), path, verb))
