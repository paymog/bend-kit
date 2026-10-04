import Base
import ./http.bend as Http
import ./completion.bend as Completion

def hello(req: Http.Req) -> IO(Http.Reply):
  Http.Req{method, path, headers, body} = req
  IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.empty(), Http.from_string(path)}, Completion.Unobserved{}})

def main() -> IO(Unit):
  Http.serve.on(~hello, ~Completion.ignore, "127.0.0.1", 18080)
