import Base
import ./http.bend as Http
import ./pure.bend as Pure
import ./completion.bend as Completion
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

type Download is Type:
  Download{path: String}

def big(n: Nat, w: Http.Writer) -> IO(Http.Writer):
  match n:
    case 0n:
      IO.pure(Http.Writer, w)
    case 1n+p:
      do IO<Http.Writer>:
        next : Http.Writer <- Http.writer.write(w, Bytes.new(65536))
        big(p, next)

def short(w: Http.Writer) -> IO(Http.Writer):
  do IO<Http.Writer>:
    a : Http.Writer <- Http.writer.write(w, Bytes.from_string("hello"))
    b : Http.Writer <- Http.writer.write(a, Bytes.new(0))
    Http.writer.write(b, Bytes.from_string(" world"))

def body.large(large: Bool, w: Http.Writer) -> IO(Http.Writer):
  match large:
    case True{}:
      big(272n, w)
    case False{}:
      short(w)

def body(st: Download, w: Http.Writer, receipt: Completion.Receipt) -> IO(Http.Writer & Completion.Receipt):
  Download{+path} = st
  do IO<Http.Writer & Completion.Receipt>:
    written : Http.Writer <- body.large(String.eq(path, "/large"), w)
    return (written, receipt)

def start(prefix: String, req: Pure.Req) -> IO(Http.WriteHead<Download>):
  Pure.Req{method, +path, headers, body} = req
  +status = Bool.pick(U32, String.eq(path, "/none"), 204,
    Bool.pick(U32, String.eq(path, "/not-modified"), 304,
      Bool.pick(U32, String.eq(path, "/interim"), 103, 200)))
  +length = Bool.pick(Maybe<&2, U32>, String.eq(path, "/known"), Some{11},
    Bool.pick(Maybe<&2, U32>, String.eq(path, "/short"), Some{12},
      Bool.pick(Maybe<&2, U32>, String.eq(path, "/over"), Some{2}, None{})))
  +rh = Pure.set(Pure.set(Pure.set(Pure.empty(), "Content-Length", "99"), "Transfer-Encoding", "gzip"), "x-context", prefix)
  IO.pure(Http.WriteHead<Download>, Http.WriteHead{status, rh, length, Download{path}, Completion.Unobserved{}})

# Download owns only managed values; skipped writes have no external handle.
def dispose(state: Download) -> IO(Unit):
  Download{path} = state
  IO.pure(Unit, Unit{})

def ready(pair: Http.Server<String> & U32) -> IO(Http.Server<String>):
  (listening, port) = pair
  do IO<Http.Server<String>>:
    IO.print("READY " ++ U32.show(port))
    return listening

def started(result: Unit & Result<&2, &1, Pure.StartupError, Http.Server<String>>) -> IO(Http.Server<String>):
  (owner, got) = result
  match got:
    case Fail{error}:
      do IO<Http.Server<String>>:
        Http.server.start.failed(error)
        IO.die(Http.Server<String>, 1, "server did not start")
    case Done{server}:
      ready(Http.server.port(~String, server))

def main() -> IO(Unit):
  do IO<Unit>:
    result : Unit & Result<&2, &1, Pure.StartupError, Http.Server<String>> <-
      Http.server.start(~String, ~Unit, "owned", Unit{}, Pure.server.config.with("127.0.0.1", 0, 1048576n))
    server : Http.Server<String> <- started(result)
    exited : Pure.ServerExit <- Http.server.write.run(~String, ~Download, ~start, ~body, ~dispose, ~(context => status => outcome => Completion.ignore(status, outcome)), server)
    Http.server.exited(exited)
