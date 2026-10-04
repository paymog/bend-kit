# Upload benchmark: answers the body length. Build with -o, then time a 16 MiB upload:
#   curl -s --data-binary @16m.bin http://127.0.0.1:18093/
import Base
import ../http.bend as Http
import ../completion.bend as Completion
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def len(req: Http.Req) -> IO(Http.Reply):
  Http.Req{method, path, headers, body} = req
  Bytes.Bytes{+n, buf} = body
  IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.empty(), Bytes.from_string(U32.show(n))}, Completion.Unobserved{}})

def main() -> IO(Unit):
  Http.serve.with(~len, ~Completion.ignore, 18093, 33554432n)
