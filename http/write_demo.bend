import Base
import ./http.bend as Http
import ./completion.bend as Completion
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

type Download is Data:
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

def start(req: Http.Req) -> IO(Http.WriteHead<Download>):
  Http.Req{method, +path, headers, body} = req
  +status = Bool.pick(U32, String.eq(path, "/none"), 204,
    Bool.pick(U32, String.eq(path, "/not-modified"), 304,
      Bool.pick(U32, String.eq(path, "/interim"), 103, 200)))
  +length = Bool.pick(Maybe<&2, U32>, String.eq(path, "/known"), Some{11},
    Bool.pick(Maybe<&2, U32>, String.eq(path, "/short"), Some{12},
      Bool.pick(Maybe<&2, U32>, String.eq(path, "/over"), Some{2}, None{})))
  +rh = Http.set(Http.set(Http.empty(), "Content-Length", "99"), "Transfer-Encoding", "gzip")
  IO.pure(Http.WriteHead<Download>, Http.WriteHead{status, rh, length, Download{path}, Completion.Unobserved{}})

def main() -> IO(Unit):
  Http.serve.write.on.with(~Download, ~start, ~body, ~Completion.ignore, "127.0.0.1", 18082, 1048576n)
