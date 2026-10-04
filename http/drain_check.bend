# Real owner completion and copied controls; drain_check.py drives both host lanes.
import Base
import ./http.bend as Http
import ./completion.bend as Completion
import ./admission_check.bend as Checks
import ../camber/lifecycle_http.bend as Lifecycle
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

def require(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit, Unit{})
    case False{}: IO.die(Unit, 1, "drain fixture invariant failed")

# Regular-file gates let the socket harness request stop/release without a
# second transport, a timer masquerading as completion, or runtime cancellation.
type GateStep is Type:
  GateReading{file: File}
  GateReceived{result: File & Result<&1, &1, U32 & String, List<&2, U32>>}
  GateChecked{ready: Bool, file: File}

@unsafe
def gate.loop(step: GateStep) -> IO(File):
  match step:
    case GateReading{file}:
      do IO<File>:
        result : File & Result<&1, &1, U32 & String, List<&2, U32>> <- File.read_at(file, 0, 2)
        gate.loop(GateReceived{result})
    case GateReceived{result}:
      (returned, got) = result
      match got:
        case Fail{error}:
          do IO<File>:
            File.close(returned)
            IO.die(File, 1, "gate read failed")
        case Done{bytes}:
          gate.loop(GateChecked{Nat.is_eq(List.length(&2, U32, bytes), 2n), returned})
    case GateChecked{ready, file}:
      match ready:
        case True{}: IO.pure(File, file)
        case False{}:
          do IO<File>:
            IO.sleep(20)
            gate.loop(GateReading{file})

def gate.wait(suffix: String) -> IO(Unit):
  do IO<Unit>:
    +path : String <- IO.try(String, IO.get_env("DRAIN_GATE"))
    file : File <- IO.try(File, File.open(path ++ suffix, "r"))
    returned : File <- gate.loop(GateReading{file})
    File.close(returned)

def callback.wait(wait: Bool) -> IO(Unit):
  match wait:
    case True{}: gate.wait(".callback")
    case False{}: IO.pure(Unit, Unit{})

def callback.failed(result: Result<&1, &1, U32 & String, File>) -> IO(Unit):
  match result:
    case Fail{error}:
      (code, message) = error
      Checks.journal("expected-notification-failure " ++ U32.show(code))
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, 1, "expected callback file-open failure did not occur")

# An expected notification error is handled, not thrown or hidden.
def callback.failure(fail: Bool) -> IO(Unit):
  match fail:
    case True{}:
      do IO<Unit>:
        path : String <- IO.try(String, IO.get_env("DRAIN_GATE"))
        result : Result<&1, &1, U32 & String, File> <- File.open(path ++ ".missing", "r")
        callback.failed(result)
    case False{}: IO.pure(Unit, Unit{})

def outcome.show(outcome: Completion.Outcome) -> String:
  match outcome:
    case Completion.HostAccepted{}: "accepted"
    case Completion.WriteFailed{code, message}: "failed-" ++ U32.show(code)
    case Completion.IncompleteResponse{}: "incomplete"

def callback(+path: String, status: U32, outcome: Completion.Outcome) -> IO(Unit):
  do IO<Unit>:
    Checks.journal("callback-begin " ++ path)
    callback.wait(String.eq(path, "/callback") || String.eq(path, "/stuck"))
    callback.failure(String.eq(path, "/expected-failure"))
    Checks.journal("callback-end " ++ path)
    Checks.journal("outcome " ++ path ++ " " ++ outcome.show(outcome))


def callback.done(event: Completion.Completion<String>) -> IO(Unit):
  Completion.Completion{path, status, outcome} = event
  callback(path, status, outcome)

def business.closed(result: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (file, got) = result
  do IO<Unit>:
    IO.pass(Unit, got)
    File.close(file)
    Checks.journal("application-handle-closed")

def business.wait(wait: Bool) -> IO(Unit):
  match wait:
    case True{}: gate.wait(".work")
    case False{}: IO.pure(Unit, Unit{})

def response.body(large: Bool) -> Http.Body:
  match large:
    case True{}: Bytes.new(16777216)
    case False{}: Http.from_string("ok")

def business(profile: U32, req: Http.Req) -> IO(Http.Res):
  Http.Req{method, +path, headers, body} = req
  do IO<Http.Res>:
    Checks.journal("business " ++ path)
    +journal : String <- IO.try(String, IO.get_env("ADMISSION_JOURNAL"))
    file : File <- IO.try(File, File.open(journal ++ ".application", "a"))
    business.wait(String.eq(path, "/work"))
    written : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, path ++ "\n")
    business.closed(written)
    return Http.Res{200, Http.empty(), response.body(String.eq(path, "/write"))}

def whole(context: Unit, req: Http.Req) -> IO(Http.Reply):
  Http.Req{+method, +path, +headers, body} = req
  do IO<Http.Reply>:
    response : Http.Res <- business(0, Http.Req{method, path, headers, body})
    return Http.reply.complete(~String, ~callback.done, path, response)

def observed(context: Unit, status: U32, outcome: Completion.Outcome) -> IO(Unit):
  Checks.journal("owner-response " ++ U32.show(status))

type MonitorStep is Type:
  MonitorReading{}
  MonitorReceived{counts: Maybe<&2, Http.ServerCounts>}

@unsafe
def monitor.loop(+stats: Http.ServerStats, step: MonitorStep) -> IO(Unit):
  match step:
    case MonitorReading{}:
      do IO<Unit>:
        counts : Maybe<&2, Http.ServerCounts> <- Http.server.stats(stats)
        monitor.loop(stats, MonitorReceived{counts})
    case MonitorReceived{counts}:
      match counts:
        case None{}: IO.print("ACCOUNTING CLOSED")
        case Some{value}:
          do IO<Unit>:
            IO.print(Checks.counts.show(value))
            IO.sleep(20)
            monitor.loop(stats, MonitorReading{})

def monitor(stats: Http.ServerStats) -> IO(Unit):
  monitor.loop(stats, MonitorReading{})

def stop(+control: Http.ServerControl) -> IO(Unit):
  do IO<Unit>:
    gate.wait(".stop")
    requested : Bool <- Http.server.stop(control)
    Checks.journal("stop-requested")
    repeated : Bool <- Http.server.stop(control)
    require(requested && Bool.not(repeated))
    IO.print("STOP REQUESTED")

def owner.finished(file: File, +stats: Http.ServerStats, +control: Http.ServerControl,
  result: Http.ServerExit) -> IO(Unit):
  match result:
    case Http.ServerAcceptFailed{code, message, counts}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, 1, "unexpected accept failure " ++ U32.show(code) ++ " " ++ message)
    case Http.ServerStopped{+counts}:
      Http.ServerCounts{c, a, b, ch, ah, bh, cr, ar, br} = counts
      do IO<Unit>:
        require(U32.is_zero(c) && U32.is_zero(a) && U32.is_zero(b))
        IO.print("OWNER COMPLETION " ++ Checks.counts.show(counts))
        late : Bool <- Http.server.stop(control)
        require(Bool.not(late))
        after : Maybe<&2, Http.ServerCounts> <- Http.server.stats(stats)
        Checks.stats.closed(after)
        File.close(file)
        IO.print("OWNER HANDLE CLOSED")

type Upload is Type:
  Upload{path: String, file: File, total: U32}

def upload.start(req: Http.Req) -> IO(Upload):
  Http.Req{method, +path, headers, body} = req
  do IO<Upload>:
    Checks.journal("business " ++ path)
    journal : String <- IO.try(String, IO.get_env("ADMISSION_JOURNAL"))
    file : File <- IO.try(File, File.open(journal ++ ".application", "a"))
    Checks.journal("application-opened " ++ path)
    business.wait(String.eq(path, "/work"))
    return Upload{path, file, 0}

def upload.piece(state: Upload, body: Http.Body) -> IO(Upload & Bool):
  Upload{path, file, total} = state
  Bytes.Bytes{len, words} = body
  IO.pure(Upload & Bool, (Upload{path, file, (total + len : U32)}, False{}))

def upload.finish(state: Upload) -> IO(Http.Reply):
  Upload{+path, file, total} = state
  do IO<Http.Reply>:
    written : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, path ++ "\n")
    business.closed(written)
    Checks.journal("upload-complete " ++ path ++ " " ++ U32.show(total))
    Checks.journal("application-closed " ++ path)
    return Http.reply.complete(~String, ~callback.done, path, Http.Res{200, Http.empty(), Http.from_string("ok")})

def upload.operation.show(operation: Http.InputOperation) -> String:
  match operation:
    case Http.ReadInput{}: "read"
    case Http.SendContinue{}: "continue"

def upload.abort.show(reason: Http.StreamAbort) -> String:
  match reason:
    case Http.StreamClosed{}: "closed"
    case Http.StreamFailed{status}: "status " ++ U32.show(status)
    case Http.StreamInputFailed{operation, code, message}: upload.operation.show(operation) ++ " " ++ U32.show(code)

def upload.abort(state: Upload, reason: Http.StreamAbort) -> IO(Unit):
  Upload{+path, file, total} = state
  do IO<Unit>:
    File.close(file)
    Checks.journal("upload-aborted " ++ path ++ " " ++ U32.show(total) ++ " " ++ upload.abort.show(reason))
    Checks.journal("application-closed " ++ path)
    gate.wait(".cleanup")

type Download is Type:
  Download{path: String, file: File}

def download.status(path: String) -> U32:
  match path:
    case "/no-body": 204
    case "/not-modified": 304
    case _: 200

def download.head.wait(wait: Bool) -> IO(Unit):
  match wait:
    case False{}: IO.pure(Unit, Unit{})
    case True{}: gate.wait(".head")

def download.start(req: Http.Req) -> IO(Http.WriteHead<Download>):
  Http.Req{method, +path, headers, body} = req
  do IO<Http.WriteHead<Download>>:
    Checks.journal("business " ++ path)
    journal : String <- IO.try(String, IO.get_env("ADMISSION_JOURNAL"))
    file : File <- IO.try(File, File.open(journal ++ ".application", "a"))
    Checks.journal("application-opened " ++ path)
    business.wait(String.eq(path, "/work"))
    download.head.wait(String.eq(path, "/head") || String.eq(path, "/no-body") ||
      String.eq(path, "/not-modified") || String.eq(path, "/header-reset"))
    return Http.WriteHead{download.status(path), Http.empty(), None{}, Download{path, file}, Completion.receipt(~String, ~callback.done, path)}

def download.write(state: Download, writer: Http.Writer, receipt: Completion.Receipt) -> IO(Http.Writer & Completion.Receipt):
  Download{+path, file} = state
  do IO<Http.Writer & Completion.Receipt>:
    Checks.journal("write-begin " ++ path)
    returned : Http.Writer <- Http.writer.write(writer, response.body(String.eq(path, "/write")))
    written : File & Result<&1, &1, U32 & String, Unit> <- File.write(file, path ++ "\n")
    business.closed(written)
    Checks.journal("application-closed " ++ path)
    Checks.journal("write-return " ++ path)
    return (returned, receipt)

def download.dispose(state: Download) -> IO(Unit):
  Download{+path, file} = state
  do IO<Unit>:
    File.close(file)
    Checks.journal("write-disposed " ++ path)
    Checks.journal("application-closed " ++ path)
    gate.wait(".cleanup")

def serve(mode: String, server: Http.Server<Unit>) -> IO(Http.ServerExit):
  match mode:
    case "stream": Http.server.stream.run(~Upload, ~upload.start, ~upload.piece, ~upload.finish, ~upload.abort, ~(status => outcome => observed(Unit{}, status, outcome)), server)
    case "writer": Http.server.write.run(~Download, ~download.start, ~download.write, ~download.dispose, ~(status => outcome => observed(Unit{}, status, outcome)), server)
    case "camber": Lifecycle.serve(~business, ~callback.done, ~(status => outcome => observed(Unit{}, status, outcome)), server)
    case _: Http.server.run(~Unit, ~whole, ~observed, server)

def controlled(file: File, +stats: Http.ServerStats, pair: Http.Server<Unit> & Http.ServerControl) -> IO(Unit):
  (server, +control) = pair
  do IO<Unit>:
    monitor_done : Chan(Unit) <- IO.fork(Unit, monitor(stats))
    stopper : Chan(Unit) <- IO.fork(Unit, stop(control))
    IO.print("READY")
    mode : String <- IO.try(String, IO.get_env("DRAIN_MODE"))
    finished : Chan(Http.ServerExit) <- IO.fork(Http.ServerExit, serve(mode, server))
    result : Http.ServerExit <- IO.join(Http.ServerExit, finished)
    IO.join(Unit, stopper)
    IO.join(Unit, monitor_done)
    owner.finished(file, stats, control, result)

def observing(file: File, pair: Http.Server<Unit> & Http.ServerStats) -> IO(Unit):
  (server, +stats) = pair
  controlled(file, stats, Http.server.control(~Unit, server))

def started(result: File & Result<&2, &1, Http.StartupError, Http.Server<Unit>>) -> IO(Unit):
  (file, got) = result
  match got:
    case Fail{error}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit, 1, "startup failed")
    case Done{server}: observing(file, Http.server.observer(~Unit, server))

def run(mode: String, port: U32) -> IO(Unit):
  do IO<Unit>:
    path : String <- IO.try(String, IO.get_env("ADMISSION_JOURNAL"))
    file : File <- IO.try(File, File.open(path ++ ".owner", "w"))
    result : File & Result<&2, &1, Http.StartupError, Http.Server<Unit>> <-
      Http.server.start(~Unit, ~File, Unit{}, file,
        Http.ServerConfig{"127.0.0.1", port, 1048576, 65536, 16, 4, 16, 2000, 2000, 30000, 1000})
    started(result)

def number.read(mode: String, number: Maybe<&2, U32>) -> IO(Unit):
  match number:
    case Some{port}: run(mode, port)
    case None{}: IO.die(Unit, 1, "invalid port")

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> number <> Nil{}: number.read(mode, U32.read(number))
    case _: IO.die(Unit, 1, "usage: drain_check <whole|camber> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
