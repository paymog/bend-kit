# Real production admission paths; admission_check.py drives native/JS sockets.
import Base
import ./http.bend as Http
import ./completion.bend as Completion
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def journal.closed(result: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (file, written) = result
  do IO<Unit>:
    IO.pass(Unit, written)
    File.close(file)

def journal(+line: String) -> IO(Unit):
  do IO<Unit>:
    path : String <- IO.try(String, IO.get_env("ADMISSION_JOURNAL"))
    file : File <- IO.try(File, File.open(path, "a"))
    written : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, line ++ "\n")
    journal.closed(written)
    IO.print("EFFECT " ++ line)

def wait(hold: Bool) -> IO(Unit):
  match hold:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      IO.sleep(1400)

def begin(+path: String) -> IO(Unit):
  do IO<Unit>:
    journal("start " ++ path)
    wait(String.starts_with(path, "/hold"))
    journal("return " ++ path)

def whole(context: Unit, request: Http.Req) -> IO(Http.Reply):
  Http.Req{method, +path, headers, body} = request
  do IO<Http.Reply>:
    begin(path)
    return Http.Reply{Http.Res{200, Http.empty(), body}, Completion.Unobserved{}}

type Upload is Type:
  Upload{path: String, length: U32}

def upload.start(request: Http.Req) -> IO(Upload):
  Http.Req{method, +path, headers, body} = request
  do IO<Upload>:
    begin(path)
    return Upload{path, 0}

def upload.piece(state: Upload, bytes: Http.Body) -> IO(Upload & Bool):
  Upload{path, length} = state
  Bytes.Bytes{size, words} = bytes
  IO.pure(Upload & Bool, (Upload{path, (length + size : U32)}, False{}))

def upload.finish(state: Upload) -> IO(Http.Reply):
  Upload{path, length} = state
  IO.pure(Http.Reply, Http.Reply{Http.Res{200, Http.empty(), Http.from_string(U32.show(length))}, Completion.Unobserved{}})

type Download is Type:
  Download{path: String, body: Http.Body}

def download.start(request: Http.Req) -> IO(Http.WriteHead<Download>):
  Http.Req{method, +path, headers, body} = request
  do IO<Http.WriteHead<Download>>:
    begin(path)
    return Http.WriteHead{200, Http.empty(), None{}, Download{path, body}, Completion.Unobserved{}}

def download.observed(+path: String, writer: Http.Writer) -> IO(Http.Writer):
  Http.Writer{socket, mode, until, outcome} = writer
  match socket:
    case None{}:
      do IO<Http.Writer>:
        journal("write-aborted " ++ path)
        IO.sleep(1400)
        journal("writer-return " ++ path)
        return Http.Writer{None{}, mode, until, outcome}
    case Some{live}:
      IO.die(Http.Writer, 1, "expected failed writer after peer reset")

def download.after(failed: Bool, +path: String, writer: Http.Writer) -> IO(Http.Writer):
  match failed:
    case False{}:
      IO.pure(Http.Writer, writer)
    case True{}:
      do IO<Http.Writer>:
        IO.sleep(80)
        next : Http.Writer <- Http.writer.write(writer, Http.from_string("after-disconnect"))
        download.observed(path, next)

def download.write(state: Download, writer: Http.Writer, receipt: Completion.Receipt) -> IO(Http.Writer & Completion.Receipt):
  Download{+path, body} = state
  do IO<Http.Writer & Completion.Receipt>:
    first : Http.Writer <- Http.writer.write(writer, body)
    returned : Http.Writer <- download.after(String.starts_with(path, "/failed"), path, first)
    return (returned, receipt)

def counts.show(counts: Http.ServerCounts) -> String:
  Http.ServerCounts{c, a, b, ch, ah, bh, cr, ar, br} = counts
  "COUNTS " ++ U32.show(c) ++ "," ++ U32.show(a) ++ "," ++ U32.show(b) ++ "," ++
    U32.show(ch) ++ "," ++ U32.show(ah) ++ "," ++ U32.show(bh) ++ "," ++
    Nat.show(cr) ++ "," ++ Nat.show(ar) ++ "," ++ Nat.show(br)

type Observation is Data:
  Observe{}
  Observed{counts: Maybe<&2, Http.ServerCounts>}

@unsafe
def monitor(fuel: Nat, +observer: Http.ServerStats, step: Observation) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      match step:
        case Observe{}:
          do IO<Unit>:
            counts : Maybe<&2, Http.ServerCounts> <- Http.server.stats(observer)
            monitor(1n+p, observer, Observed{counts})
        case Observed{counts}:
          match counts:
            case None{}:
              IO.print("STATS CLOSED")
            case Some{value}:
              do IO<Unit>:
                IO.print(counts.show(value))
                IO.sleep(25)
                monitor(p, observer, Observe{})

def stats.closed(observation: Maybe<&2, Http.ServerCounts>) -> IO(Unit):
  match observation:
    case None{}:
      IO.print("POST CLOSED")
    case Some{counts}:
      IO.die(Unit, 1, "stats remained open after closing an unused server")

def stats.after.close(fuel: Nat, +observer: Http.ServerStats) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        observation : Maybe<&2, Http.ServerCounts> <- Http.server.stats(observer)
        stats.closed(observation)
        stats.after.close(p, observer)


def config(+profile: String, port: U32) -> Http.ServerConfig:
  Http.ServerConfig{"127.0.0.1", port, 131072, 1024,
    Bool.pick(U32, String.eq(profile, "connections"), 2, 16),
    Bool.pick(U32, String.eq(profile, "active"), 2, 16),
    Bool.pick(U32, String.eq(profile, "buffered"), 2, 16),
    900, 900, 900, 400}

def whole.stopped(result: Http.Server<Unit> & (U32 & String)) -> IO(Unit):
  (returned, error) = result
  Http.server.close(~Unit, returned)

def serve(mode: String, server: Http.Server<Unit>, +observer: Http.ServerStats, first: Chan(Unit)) -> IO(Unit):
  match mode:
    case "whole":
      do IO<Unit>:
        result : Http.Server<Unit> & (U32 & String) <- Http.server.run(~Unit, ~whole, ~(context => status => outcome => Completion.ignore(status, outcome)), server)
        whole.stopped(result)
    case "stream":
      Http.Server{listener, context, config, inbox} = server
      Http.serve.stream.loop(~Upload, ~upload.start, ~upload.piece, ~upload.finish, ~Completion.ignore, Http.limits.config(config), inbox, listener)
    case "writer":
      Http.Server{listener, context, config, inbox} = server
      Http.serve.write.loop(~Download, ~download.start, ~download.write, ~Completion.ignore, Http.limits.config(config), inbox, listener)
    case "stats-close":
      do IO<Unit>:
        second : Chan(Unit) <- IO.fork(Unit, monitor(128n, observer, Observe{}))
        Http.server.close(~Unit, server)
        stats.after.close(128n, observer)
        IO.join(Unit, first)
        IO.join(Unit, second)
        IO.print("OBSERVERS JOINED")
    case _:
      Http.server.close(~Unit, server)

def observed.ready(mode: String, pair: Http.Server<Unit> & Http.ServerStats) -> IO(Unit):
  (returned, +observer) = pair
  do IO<Unit>:
    first : Chan(Unit) <- IO.fork(Unit, monitor(U32.to_nat(2400), observer, Observe{}))
    IO.print("READY")
    serve(mode, returned, observer, first)

def observed(mode: String, server: Http.Server<Unit>) -> IO(Unit):
  observed.ready(mode, Http.server.observer(~Unit, server))

def started(mode: String, result: Unit & Result<&2, &1, Http.StartupError, Http.Server<Unit>>) -> IO(Unit):
  (owner, got) = result
  match got:
    case Fail{error}:
      match error:
        case Http.InvalidConfig{}:
          IO.die(Unit, 1, "invalid admission fixture configuration")
        case Http.BindError{code, message}:
          IO.die(Unit, code, message)
    case Done{server}:
      observed(mode, server)

def run(mode: String, profile: String, port: Maybe<&2, U32>) -> IO(Unit):
  match port:
    case None{}:
      IO.die(Unit, 1, "invalid port")
    case Some{number}:
      do IO<Unit>:
        result : Unit & Result<&2, &1, Http.StartupError, Http.Server<Unit>> <- Http.server.start(~Unit, ~Unit, Unit{}, Unit{}, config(profile, number))
        started(mode, result)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> profile <> port <> Nil{}:
      run(mode, profile, U32.read(port))
    case _:
      IO.die(Unit, 1, "usage: admission_check <whole|stream|writer> <connections|active|buffered> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
