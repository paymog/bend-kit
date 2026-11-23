import Base
import ./http.bend as Http
import ./completion.bend as Completion
import ./smoke_server.bend as Smoke

def hello(req: Http.Req) -> IO(Http.Reply):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.empty(), Http.from_string(path)}, Completion.Unobserved{}})

def main() -> IO(Unit):
  do IO<Unit>:
    server : Http.Server<Unit> <- Smoke.start(Http.serve.max())
    exited : Http.ServerExit <- Http.server.run(~Unit, ~(context => req => hello(req)),
      ~(context => status => outcome => Completion.ignore(status, outcome)), server)
    Http.server.exited(exited)
