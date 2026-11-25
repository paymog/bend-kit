import Base
import ./http.bend as Http
import ./pure.bend as Pure
import ./completion.bend as Completion
import ./smoke_server.bend as Smoke

def hello(req: Pure.Req) -> IO(Http.Reply):
  Pure.Req{method, path, headers, body} = req
  IO.pure(Http.Reply, Http.Reply{Pure.Res{200, Pure.empty(), Pure.from_string(path)}, Completion.Unobserved{}})

def main() -> IO(Unit):
  do IO<Unit>:
    server : Http.Server<Unit> <- Smoke.start(Pure.serve.max())
    exited : Pure.ServerExit <- Http.server.run(~Unit, ~(context => req => hello(req)),
      ~(context => status => outcome => Completion.ignore(status, outcome)), server)
    Http.server.exited(exited)
