import Base
import ./http.bend as Http
import ./completion.bend as Completion
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

type Count is Data:
  Count{path: String, len: U32, hash: U32}

def hash.go(s: String, +acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{+c}, rest}:
      hash.go(rest, (acc * 33 + c : U32))

def start(req: Http.Req) -> IO(Count):
  Http.Req{method, path, headers, body} = req
  IO.pure(Count, Count{path, 0, 5381})

def piece(st: Count, b: Bytes.Bytes) -> IO(Count & Bool):
  Count{+path, +len, +hash} = st
  Bytes.Bytes{+n, buf} = b
  IO.pure(Count & Bool,
    (Count{path, (len + n : U32), hash.go(Bytes.to_string(Bytes.Bytes{n, buf}), hash)},
      String.eq(path, "/discard")))

def finish(st: Count) -> IO(Http.Reply):
  Count{path, +len, +hash} = st
  IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.empty(), Http.from_string(path ++ ":" ++ U32.show(len) ++ ":" ++ U32.show(hash))}, Completion.Unobserved{}})

def main() -> IO(Unit):
  Http.serve.stream.on.with(~Count, ~start, ~piece, ~finish, ~Completion.ignore, "127.0.0.1", 18081, 33554432n)
