# Production whole/stream/writer socket acceptance; run limits_check.py.
import Base
import ./http.bend as Http
import ./completion.bend as Completion
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def config(port: U32) -> Http.ServerConfig:
  Http.ServerConfig{"127.0.0.1", port, 8, 128, 128, 128, 128, 600, 600, 800, 600}

def whole(context: String, req: Http.Req) -> IO(Http.Reply):
  Http.Req{method, +path, headers, body} = req
  match path:
    case "/large":
      IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.empty(), Bytes.new(16777216)}, Completion.Unobserved{}})
    case "/cpu":
      do IO<Http.Reply>:
        IO.sleep(1000)
        return Http.Reply{Http.Res{200, Http.empty(), body}, Completion.Unobserved{}}
    case _:
      IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.set(Http.empty(), "x-context", context), body}, Completion.Unobserved{}})

type Upload is Data:
  Upload{count: U32, discard: Bool, large: Bool}

def upload.wait(slow: Bool, state: Upload) -> IO(Upload):
  match slow:
    case True{}:
      do IO<Upload>:
        IO.sleep(450)
        return state
    case False{}:
      IO.pure(Upload, state)

def upload.start(req: Http.Req) -> IO(Upload):
  Http.Req{method, +path, headers, body} = req
  upload.wait(String.eq(path, "/slow-start"), Upload{0, String.eq(path, "/discard"), String.eq(path, "/large")})

def upload.piece(state: Upload, b: Bytes.Bytes) -> IO(Upload & Bool):
  Upload{count, +discard, large} = state
  Bytes.Bytes{len, words} = b
  IO.pure(Upload & Bool, (Upload{(count + len : U32), discard, large}, discard))

def upload.response(large: Bool, count: U32) -> Http.Res:
  match large:
    case True{}:
      Http.Res{200, Http.empty(), Bytes.new(16777216)}
    case False{}:
      Http.Res{200, Http.empty(), Http.from_string(U32.show(count))}

def upload.finish(state: Upload) -> IO(Http.Reply):
  Upload{count, discard, large} = state
  IO.pure(Http.Reply, Http.Reply{upload.response(large, count), Completion.Unobserved{}})

def upload.abort(state: Upload, reason: Http.StreamAbort) -> IO(Unit):
  Upload{count, discard, large} = state
  IO.pure(Unit, Unit{})

def download.large(large: Bool, body: Bytes.Bytes) -> Bytes.Bytes:
  match large:
    case True{}:
      Bytes.new(16777216)
    case False{}:
      body

type Download is Type:
  Download{body: Bytes.Bytes, progress: Bool}

def download.head(+progress: Bool, data: Bytes.Bytes) -> Http.WriteHead<Download>:
  Bytes.Bytes{+len, words} = data
  Http.WriteHead{200, Http.empty(), Some{Bool.pick(U32, progress, 8, len)},
    Download{Bytes.Bytes{len, words}, progress}, Completion.Unobserved{}}

def download.start(req: Http.Req) -> IO(Http.WriteHead<Download>):
  Http.Req{method, +path, headers, body} = req
  IO.pure(Http.WriteHead<Download>, download.head(String.eq(path, "/progress"),
    download.large(String.eq(path, "/large"), body)))

def download.observed(w: Http.Writer) -> IO(Http.Writer):
  Http.Writer{socket, +mode, +until, outcome} = w
  match socket:
    case None{}:
      do IO<Http.Writer>:
        IO.print("WRITE_FAILED_CLOSED")
        return Http.Writer{None{}, mode, until, outcome}
    case Some{s}:
      IO.pure(Http.Writer, Http.Writer{Some{s}, mode, until, outcome})

def download.progress(n: Nat, w: Http.Writer) -> IO(Http.Writer):
  match n:
    case 0n:
      download.observed(w)
    case 1n+p:
      do IO<Http.Writer>:
        sent : Http.Writer <- Http.writer.write(w, Http.from_string("x"))
        IO.sleep(150)
        download.progress(p, sent)

def download.body(progress: Bool, body: Bytes.Bytes, w: Http.Writer) -> IO(Http.Writer):
  match progress:
    case True{}:
      download.progress(8n, w)
    case False{}:
      do IO<Http.Writer>:
        sent : Http.Writer <- Http.writer.write(w, body)
        download.observed(sent)

def download.write(state: Download, w: Http.Writer, receipt: Completion.Receipt) -> IO(Http.Writer & Completion.Receipt):
  Download{body, progress} = state
  do IO<Http.Writer & Completion.Receipt>:
    returned : Http.Writer <- download.body(progress, body, w)
    return (returned, receipt)

def download.dispose(state: Download) -> IO(Unit):
  Download{body, progress} = state
  IO.pure(Unit, Unit{})

def whole.started(result: Unit & Result<&2, &1, Http.StartupError, Http.Server<String>>) -> IO(Unit):
  (owner, got) = result
  match got:
    case Fail{error}:
      IO.die(Unit, 1, "startup failed")
    case Done{server}:
      do IO<Unit>:
        IO.print("READY")
        stopped : Http.ServerExit <- Http.server.run(~String, ~whole, ~(context => status => outcome => Completion.ignore(status, outcome)), server)
        return Unit{}

def checked(result: Result<&2, &2, Http.StartupError, Unit>) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit, 1, "startup failed")
    case Done{unit}:
      IO.pure(Unit, Unit{})

def run(mode: String, port: U32) -> IO(Unit):
  match mode:
    case "whole":
      do IO<Unit>:
        context : String <- IO.try(String, IO.get_env("LIMITS_CONTEXT"))
        started : Unit & Result<&2, &1, Http.StartupError, Http.Server<String>> <- Http.server.start(~String, ~Unit, context, Unit{}, config(port))
        whole.started(started)
    case "stream":
      do IO<Unit>:
        result : Result<&2, &2, Http.StartupError, Unit> <- Http.serve.stream.config(~Upload, ~upload.start, ~upload.piece, ~upload.finish, ~upload.abort, ~Completion.ignore, config(port))
        checked(result)
    case "writer":
      do IO<Unit>:
        result : Result<&2, &2, Http.StartupError, Unit> <- Http.serve.write.config(~Download, ~download.start, ~download.write, ~download.dispose, ~Completion.ignore, config(port))
        checked(result)
    case _:
      IO.die(Unit, 1, "invalid mode")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> number <> Nil{}:
      run(mode, Maybe.default(&2, U32, U32.read(number), 0))
    case _:
      IO.die(Unit, 1, "usage: limits_check whole|stream|writer port")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
