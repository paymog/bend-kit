# Paired lifecycle control: same business work and route decisions as raw_http.
import Base
import ./raw_http.bend as Raw
import ./surface.bend as Surface
import ./interface_check.bend as Registry
import ../http/http.bend as Http
import ../http/completion.bend as Completion

type Input is Type:
  Request{request: Http.Req, hooks: U32}

def validate.checked(valid: Bool, response: Http.Res) -> Result<&2, &1, U32, Http.Res>:
  match valid:
    case True{}:
      Done{response}
    case False{}:
      Fail{500}

def validate(response: Http.Res) -> Result<&2, &1, U32, Http.Res>:
  Http.Res{+status, headers, body} = response
  validate.checked(U32.is_ge(status, 200) && U32.is_le(status, 599), Http.Res{status, headers, body})

def mapper(state: Unit, profile: U32, error: U32) -> IO(Unit & Result<&2, &1, U32, Http.Res>):
  match error:
    case 401:
      IO.pure(Unit & Result<&2, &1, U32, Http.Res>, (state, Done{Http.Res{401, Http.set(Http.empty(), "www-authenticate", "Bearer"), Http.from_string("")}}))
    case _:
      IO.pure(Unit & Result<&2, &1, U32, Http.Res>, (state, Done{Http.Res{500, Http.empty(), Http.from_string("")}}))

def unchanged(hook: Unit, state: Unit, profile: U32, response: Http.Res) -> IO(Unit & Result<&2, &1, U32, Http.Res>):
  IO.pure(Unit & Result<&2, &1, U32, Http.Res>, (state, Done{response}))

def accepted(state: Unit, result: Maybe<&2, U32>) -> Unit & Surface.Step<U32, U32>:
  match result:
    case None{}:
      (state, Surface.Reject{401})
    case Some{count}:
      (state, Surface.Continue{count})

def one(state: Unit, profile: U32, meta: Registry.Metadata, count: U32) -> IO(Unit & Surface.Step<U32, U32>):
  Registry.Metadata{method, target, headers} = meta
  do IO<Unit & Surface.Step<U32, U32>>:
    result : Maybe<&2, U32> <- Raw.hook(headers, count)
    return accepted(state, result)

def two(state: Unit, profile: U32, meta: Registry.Metadata, count: U32) -> IO(Unit & Surface.Step<U32, U32>):
  Surface.before(~Unit, ~U32, ~U32, ~U32, ~U32, ~U32, ~one, ~one, state, profile, meta, count)

def four(state: Unit, profile: U32, meta: Registry.Metadata, count: U32) -> IO(Unit & Surface.Step<U32, U32>):
  Surface.before(~Unit, ~U32, ~U32, ~U32, ~U32, ~U32, ~two, ~two, state, profile, meta, count)

def five(state: Unit, profile: U32, meta: Registry.Metadata, count: U32) -> IO(Unit & Surface.Step<U32, U32>):
  Surface.before(~Unit, ~U32, ~U32, ~U32, ~U32, ~U32, ~four, ~one, state, profile, meta, count)

def enter.allowed(valid: Bool, count: U32, state: Unit, profile: U32, meta: Registry.Metadata, total: U32) -> IO(Unit & Surface.Step<U32, U32>):
  match valid:
    case False{}:
      IO.pure(Unit & Surface.Step<U32, U32>, (state, Surface.Early{Http.Res{405, Http.set(Http.empty(), "allow", "GET, HEAD"), Http.from_string("")}}))
    case True{}:
      match count:
        case 1:
          one(state, profile, meta, total)
        case 5:
          five(state, profile, meta, total)
        case _:
          IO.pure(Unit & Surface.Step<U32, U32>, (state, Surface.Continue{total}))

def enter.basic(state: Unit, profile: U32, +meta: Registry.Metadata, total: U32) -> IO(Unit & Surface.Step<U32, U32>):
  Registry.Metadata{+method, target, headers} = meta
  match target:
    case "/hooks/1":
      enter.allowed(String.eq(method, "GET") || String.eq(method, "HEAD"), 1, state, profile, meta, total)
    case "/hooks/5":
      enter.allowed(String.eq(method, "GET") || String.eq(method, "HEAD"), 5, state, profile, meta, total)
    case _:
      IO.pure(Unit & Surface.Step<U32, U32>, (state, Surface.Continue{total}))

def enter.go(state: Unit, +profile: U32, meta: Registry.Metadata, total: U32) -> IO(Unit & Surface.Step<U32, U32>):
  match profile:
    case 0:
      enter.basic(state, profile, meta, total)
    case _:
      IO.pure(Unit & Surface.Step<U32, U32>, (state, Surface.Continue{total}))

def enter(state: Unit, profile: U32, meta: Registry.Metadata, total: U32) -> IO(Unit & Surface.Step<U32, U32>):
  enter.go(state, profile, meta, total)

def decode(state: Unit, profile: U32, meta: Registry.Metadata, count: U32, body: Http.Body) -> IO(Unit & Result<&2, &1, U32, Input>):
  Registry.Metadata{method, target, headers} = meta
  IO.pure(Unit & Result<&2, &1, U32, Input>, (state, Done{Request{Http.Req{method, target, headers, body}, count}}))

def handle.basic(~business: U32 -> Http.Req -> IO(Http.Res), state: Unit, profile: U32, count: U32, request: Http.Req) -> IO(Unit & Result<&2, &1, U32, Http.Res>):
  Http.Req{method, +target, headers, body} = request
  match target:
    case "/hooks/1":
      do IO<Unit & Result<&2, &1, U32, Http.Res>>:
        response : Http.Res <- Raw.hooks(0n, headers, Some{count})
        return (state, Done{response})
    case "/hooks/5":
      do IO<Unit & Result<&2, &1, U32, Http.Res>>:
        response : Http.Res <- Raw.hooks(0n, headers, Some{count})
        return (state, Done{response})
    case _:
      do IO<Unit & Result<&2, &1, U32, Http.Res>>:
        response : Http.Res <- business(profile, Http.Req{method, target, headers, body})
        return (state, Done{response})

def handle(~business: U32 -> Http.Req -> IO(Http.Res), state: Unit, +profile: U32, input: Input) -> IO(Unit & Result<&2, &1, U32, Http.Res>):
  match profile:
    case 0:
      Request{request, count} = input
      handle.basic(~business, state, profile, count, request)
    case _:
      Request{request, count} = input
      do IO<Unit & Result<&2, &1, U32, Http.Res>>:
        response : Http.Res <- business(profile, request)
        return (state, Done{response})

def endpoint(~business: U32 -> Http.Req -> IO(Http.Res), state: Unit, profile: U32, meta: Registry.Metadata, count: U32, body: Http.Body) -> IO(Unit & Surface.Flow):
  Surface.endpoint(~Unit, ~U32, ~U32, ~U32, ~Input, ~decode, ~(state => profile => input => handle(~business, state, profile, input)), ~mapper, ~validate, state, profile, meta, count, body)

def response(result: Unit & Surface.Flow) -> Http.Res:
  (state, Surface.Flow{response, mapped, stopped}) = result
  response

def dispatch(~business: U32 -> Http.Req -> IO(Http.Res), +profile: U32, req: Http.Req) -> IO(Http.Res):
  Http.Req{method, target, headers, body} = req
  do IO<Http.Res>:
    result : Unit & Surface.Flow <- Surface.scope(~Unit, ~U32, ~U32, ~U32, ~U32, ~Unit, ~enter, ~(state => profile => meta => count => body => endpoint(~business, state, profile, meta, count, body)), ~unchanged, ~mapper, ~validate, Surface.Policy{Nil{}}, Unit{}, profile, Registry.Metadata{method, target, headers}, 0, body)
    checked : Unit & Surface.Flow <- Surface.finish(~Unit, ~U32, ~U32, ~mapper, ~validate, profile, result)
    return response(checked)

# The cooperative lifecycle probe uses this same scoped dispatch, the shared
# transport owner and typed request-local completion, not a second server.
def serve.reply(~business: U32 -> Http.Req -> IO(Http.Res),
  ~done: Completion.Completion<String> -> IO(Unit), context: Unit, req: Http.Req) -> IO(Http.Reply):
  Http.Req{method, +path, headers, body} = req
  do IO<Http.Reply>:
    response : Http.Res <- dispatch(~business, 0, Http.Req{method, path, headers, body})
    return Http.reply.complete(~String, ~done, path, response)

def serve(~business: U32 -> Http.Req -> IO(Http.Res),
  ~done: Completion.Completion<String> -> IO(Unit),
  ~observe: U32 -> Completion.Outcome -> IO(Unit), server: Http.Server<Unit>) -> IO(Http.ServerExit):
  Http.server.run(~Unit, ~(context => req => serve.reply(~business, ~done, context, req)),
    ~(context => status => outcome => observe(status, outcome)), server)
