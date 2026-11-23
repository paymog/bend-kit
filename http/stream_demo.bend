import Base
import ./http.bend as Http
import ./completion.bend as Completion
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import ./smoke_server.bend as Smoke

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

# Count owns only managed values; an unsuccessful upload has no external handle.
def abort(state: Count, reason: Http.StreamAbort) -> IO(Unit):
  Count{path, length, hash} = state
  IO.pure(Unit, Unit{})

def main() -> IO(Unit):
  do IO<Unit>:
    server : Http.Server<Unit> <- Smoke.start(33554432n)
    exited : Http.ServerExit <- Http.server.stream.run(~Count, ~start, ~piece, ~finish, ~abort, ~Completion.ignore, server)
    Http.server.exited(exited)
