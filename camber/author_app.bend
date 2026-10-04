# An author-owned plain handler extension; no change to the lifecycle primitives.
import Base
import ./surface_app.bend as Example
import ./surface.bend as Surface
import ./interface_check.bend as Registry
import ../http/http.bend as Http

def echo(request: Http.Req) -> IO(Http.Res):
  Http.Req{method, target, headers, body} = request
  IO.pure(Http.Res, Http.Res{200, Http.set(Http.empty(), "content-type", "application/octet-stream"), body})

def endpoint(state: Example.State, application: Example.Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Example.State & Surface.Flow):
  Registry.Metadata{method, target, headers} = meta
  do IO<Example.State & Surface.Flow>:
    response : Http.Res <- echo(Http.Req{method, target, headers, body})
    return (Example.record(state, Example.Handle{}), Surface.Flow{response, False{}, False{}})

def group.go(state: Example.State, +application: Example.Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Example.State & Surface.Flow):
  Surface.scope(~Example.State, ~Example.Application, ~Example.Err, ~Unit, ~Unit, ~Example.Hook, ~Example.public_before, ~endpoint, ~Example.after, ~Example.mapper, ~Example.validate, Example.policy.public(Example.settings(application)), state, application, meta, context, body)

def group(state: Example.State, application: Example.Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Example.State & Surface.Flow):
  group.go(state, application, meta, context, body)

def method(valid: Bool, state: Example.State, application: Example.Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Example.State & Surface.Flow):
  match valid:
    case False{}:
      IO.pure(Example.State & Surface.Flow, (state, Surface.Flow{Http.Res{405, Http.set(Http.empty(), "allow", "POST"), Http.from_string("")}, False{}, False{}}))
    case True{}:
      group(state, application, meta, context, body)

def inside.go(state: Example.State, application: Example.Application, +meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Example.State & Surface.Flow):
  Registry.Metadata{verb, target, headers} = meta
  match target:
    case "/echo":
      method(String.eq(verb, "POST"), state, application, meta, context, body)
    case _:
      Example.root_inside(state, application, meta, context, body)

def inside(state: Example.State, application: Example.Application, meta: Registry.Metadata, context: Unit, body: Http.Body) -> IO(Example.State & Surface.Flow):
  inside.go(state, application, meta, context, body)

def dispatch(state: Example.State, +application: Example.Application, request: Http.Req) -> IO(Example.State & Http.Res):
  Http.Req{method, target, headers, body} = request
  do IO<Example.State & Http.Res>:
    result : Example.State & Surface.Flow <- Surface.scope(~Example.State, ~Example.Application, ~Example.Err, ~Unit, ~Unit, ~Example.Hook, ~Example.root_before, ~inside, ~Example.after, ~Example.mapper, ~Example.validate, Example.policy.root(Example.settings(application)), state, application, Registry.Metadata{method, target, headers}, Unit{}, body)
    checked : Example.State & Surface.Flow <- Surface.finish(~Example.State, ~Example.Application, ~Example.Err, ~Example.mapper, ~Example.validate, application, result)
    return Surface.response(~Example.State, checked)
