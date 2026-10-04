# Shared production transport completion fixture; outcome_check.py drives real sockets.
import Base
import ./http.bend as Http
import ./completion.bend as Completion
import ./admission_check.bend as Checks
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

type Payload is Data:
  Payload{path: String, stage: U32}

def outcome.show(outcome: Completion.Outcome) -> String:
  match outcome:
    case Completion.HostAccepted{}: "accepted"
    case Completion.WriteFailed{code, message}: "failed:" ++ U32.show(code)
    case Completion.IncompleteResponse{}: "incomplete"

def owner(status: U32, outcome: Completion.Outcome) -> IO(Unit):
  Checks.journal("owner " ++ U32.show(status) ++ " " ++ outcome.show(outcome))

def owner.context(context: Unit, status: U32, outcome: Completion.Outcome) -> IO(Unit):
  owner(status, outcome)

def payload.done(event: Completion.Completion<Payload>) -> IO(Unit):
  Completion.Completion{Payload{+path, stage}, status, outcome} = event
  do IO<Unit>:
    Checks.journal("payload " ++ path ++ " " ++ U32.show(stage) ++ " " ++ U32.show(status) ++ " " ++ outcome.show(outcome))
    Checks.wait(String.eq(path, "/completion-hold"))
    Checks.journal("completed " ++ path)

def receipt.closed(pair: Completion.Receipt & Chan(Completion.Completion<Payload>)) -> IO(Completion.Receipt):
  (receipt, channel) = pair
  do IO<Completion.Receipt>:
    Chan.close(Completion.Completion<Payload>, channel)
    return receipt

def receipt(+path: String, stage: U32) -> IO(Completion.Receipt):
  match path:
    case "/absent": IO.pure(Completion.Receipt, Completion.Unobserved{})
    case "/closed":
      do IO<Completion.Receipt>:
        pair : Completion.Receipt & Chan(Completion.Completion<Payload>) <- Completion.open(~Payload, Payload{path, stage})
        receipt.closed(pair)
    case _:
      IO.pure(Completion.Receipt, Completion.receipt(~Payload, ~payload.done, Payload{path, stage}))

def status(+path: String) -> U32:
  Bool.pick(U32, String.eq(path, "/204"), 204, Bool.pick(U32, String.eq(path, "/304"), 304, 200))

def delay(reset: Bool) -> IO(Unit):
  match reset:
    case True{}: IO.sleep(300)
    case False{}: IO.pure(Unit, Unit{})

def response.large(large: Bool) -> Bytes.Bytes:
  match large:
    case True{}: Bytes.new(16777216)
    case False{}: Http.from_string("ok")

def whole(context: Unit, request: Http.Req) -> IO(Http.Reply):
  Http.Req{method, +path, headers, body} = request
  do IO<Http.Reply>:
    Checks.journal("business " ++ path)
    delay(String.eq(path, "/reset"))
    done : Completion.Receipt <- receipt(path, 2)
    return Http.Reply{Http.Res{status(path), Http.empty(), response.large(String.eq(path, "/reset") || String.eq(path, "/deadline"))}, done}

def whole.convenience(request: Http.Req) -> IO(Http.Reply):
  whole(Unit{}, request)

type Upload is Data:
  Upload{path: String, bytes: U32}

def upload.start(request: Http.Req) -> IO(Upload):
  Http.Req{method, +path, headers, body} = request
  do IO<Upload>:
    Checks.journal("business " ++ path)
    return Upload{path, 0}

def upload.piece(state: Upload, bytes: Bytes.Bytes) -> IO(Upload & Bool):
  Upload{path, count} = state
  Bytes.Bytes{length, words} = bytes
  IO.pure(Upload & Bool, (Upload{path, (count + length : U32)}, False{}))

def upload.finish(state: Upload) -> IO(Http.Reply):
  Upload{+path, bytes} = state
  do IO<Http.Reply>:
    delay(String.eq(path, "/reset"))
    done : Completion.Receipt <- receipt(path, 3)
    return Http.Reply{Http.Res{status(path), Http.empty(), response.large(String.eq(path, "/reset") || String.eq(path, "/deadline"))}, done}

def upload.abort(state: Upload, reason: Http.StreamAbort) -> IO(Unit):
  Upload{path, bytes} = state
  IO.pure(Unit, Unit{})

type Download is Data:
  Download{path: String}

def download.length(path: String) -> Maybe<&2, U32>:
  match path:
    case "/known-short": Some{12}
    case "/known-overshoot": Some{8}
    case _: None{}

def download.start(request: Http.Req) -> IO(Http.WriteHead<Download>):
  Http.Req{method, +path, headers, body} = request
  do IO<Http.WriteHead<Download>>:
    Checks.journal("business " ++ path)
    delay(String.eq(path, "/header-reset"))
    initial : Completion.Receipt <- receipt(path, 1)
    return Http.WriteHead{status(path), Http.empty(), download.length(path), Download{path}, initial}

def download.write(state: Download, writer: Http.Writer, initial: Completion.Receipt) -> IO(Http.Writer & Completion.Receipt):
  Download{+path} = state
  do IO<Http.Writer & Completion.Receipt>:
    Checks.journal("writer-enter " ++ path)
    prefix : Http.Writer <- Http.writer.write(writer, Http.from_string("prefix-"))
    delay(String.eq(path, "/reset") || String.eq(path, "/partial"))
    written : Http.Writer <- Http.writer.write(prefix, response.large(String.eq(path, "/reset") || String.eq(path, "/partial") || String.eq(path, "/deadline")))
    Checks.journal("writer-written " ++ path)
    delay(String.eq(path, "/terminator-reset"))
    Checks.wait(String.eq(path, "/partial") || String.eq(path, "/deadline"))
    Checks.journal("writer-return " ++ path)
    final : Completion.Receipt <- receipt(path, 2)
    return (written, final)

def download.dispose(state: Download) -> IO(Unit):
  Download{path} = state
  IO.pure(Unit, Unit{})

def config(port: U32) -> Http.ServerConfig:
  Http.ServerConfig{"127.0.0.1", port, 8, 128, 16, 2, 16, 600, 600, 800, 600}

def whole.observed(pair: Http.Server<Unit> & Http.ServerStats) -> IO(Unit):
  (server, observer) = pair
  do IO<Unit>:
    IO.spawn(Unit, Checks.monitor(U32.to_nat(2400), observer, Checks.Observe{}))
    IO.print("READY")
    result : Http.ServerExit <- Http.server.run(~Unit, ~whole, ~owner.context, server)
    return Unit{}

def whole.started(result: Unit & Result<&2, &1, Http.StartupError, Http.Server<Unit>>) -> IO(Unit):
  (owner, started) = result
  match started:
    case Fail{error}: IO.die(Unit, 1, "startup failed")
    case Done{server}: whole.observed(Http.server.observer(~Unit, server))

def checked(result: Result<&2, &2, Http.StartupError, Unit>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "startup failed")
    case Done{unit}: IO.pure(Unit, Unit{})

type LateContext is Data:
  LateContext{observers: Chan(Chan(Completion.Completion<Payload>)), stats: Maybe<&2, Http.ServerStats>}

def late.require(ok: Bool) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit, Unit{})
    case False{}: IO.die(Unit, 1, "late observer check failed")

def late.opened(observers: Chan(Chan(Completion.Completion<Payload>)),
  pair: Completion.Receipt & Chan(Completion.Completion<Payload>)) -> IO(Http.Reply):
  (receipt, observer) = pair
  do IO<Http.Reply>:
    sent : Bool <- Chan.send(Chan(Completion.Completion<Payload>), observers, observer)
    late.require(sent)
    return Http.Reply{Http.Res{200, Http.empty(), Http.from_string("ok")}, receipt}

def late.handle(context: LateContext, request: Http.Req) -> IO(Http.Reply):
  LateContext{observers, stats} = context
  Http.Req{method, path, headers, body} = request
  do IO<Http.Reply>:
    pair : Completion.Receipt & Chan(Completion.Completion<Payload>) <- Completion.open(~Payload, Payload{path, 7})
    late.opened(observers, pair)

def late.counts(result: Maybe<&2, Http.ServerCounts>) -> IO(Unit):
  match result:
    case None{}: IO.die(Unit, 1, "accounting closed before completion callback")
    case Some{Http.ServerCounts{c, a, b, ch, ah, bh, cr, ar, br}}:
      do IO<Unit>:
        late.require(U32.is_eq(c, 1) && U32.is_eq(a, 1) && U32.is_eq(b, 1))
        Checks.journal("owner-stats 1 1 1")

def late.owner.stats(status: U32, outcome: Completion.Outcome, stats: Maybe<&2, Http.ServerStats>) -> IO(Unit):
  match stats:
    case None{}: IO.die(Unit, 1, "missing callback stats observer")
    case Some{observer}:
      do IO<Unit>:
        counts : Maybe<&2, Http.ServerCounts> <- Http.server.stats(observer)
        late.counts(counts)
        owner(status, outcome)

def late.owner(context: LateContext, status: U32, outcome: Completion.Outcome) -> IO(Unit):
  LateContext{observers, stats} = context
  late.owner.stats(status, outcome, stats)

def late.received(result: Maybe<&1, Completion.Completion<Payload>>) -> IO(Unit):
  match result:
    case None{}: IO.die(Unit, 1, "late completion observer lost queued outcome")
    case Some{Completion.Completion{Payload{+path, stage}, status, outcome}}:
      do IO<Unit>:
        late.require(String.eq(path, "/late") && U32.is_eq(stage, 7) && U32.is_eq(status, 200))
        Checks.journal("late-observed " ++ path ++ " " ++ outcome.show(outcome))

def late.accepted(+observers: Chan(Chan(Completion.Completion<Payload>)),
  accepted: Http.Server<LateContext> & Result<&1, &1, U32 & String, Chan(Unit)>) -> IO(Unit):
  (server, result) = accepted
  do IO<Unit>:
    finished : Chan(Unit) <- IO.pass(Chan(Unit), result)
    IO.join(Unit, finished)
    drained : Http.ServerCounts <- Http.server.close(~LateContext, server)
    IO.print("TRANSPORT RETURNED BEFORE OBSERVER RECEIVE")
    observer : Chan(Completion.Completion<Payload>) <- IO.join(Chan(Completion.Completion<Payload>), observers)
    event : Maybe<&1, Completion.Completion<Payload>> <- IO.within(Completion.Completion<Payload>, 1000,
      IO.join(Completion.Completion<Payload>, observer))
    late.received(event)

def late.ready(+observers: Chan(Chan(Completion.Completion<Payload>)),
  pair: Http.Server<LateContext> & Http.ServerStats) -> IO(Unit):
  (server, stats) = pair
  Http.Server{listener, context, config, inbox, drained} = server
  do IO<Unit>:
    IO.print("READY")
    accepted : Http.Server<LateContext> & Result<&1, &1, U32 & String, Chan(Unit)> <-
      Http.server.accept(~LateContext, ~late.handle, ~late.owner,
        Http.Server{listener, LateContext{observers, Some{stats}}, config, inbox, drained})
    late.accepted(observers, accepted)

def late.started(+observers: Chan(Chan(Completion.Completion<Payload>)),
  result: Unit & Result<&2, &1, Http.StartupError, Http.Server<LateContext>>) -> IO(Unit):
  (owner, started) = result
  match started:
    case Fail{error}: IO.die(Unit, 1, "late startup failed")
    case Done{server}:
      late.ready(observers, Http.server.observer(~LateContext, server))

def run(mode: String, port: U32) -> IO(Unit):
  match mode:
    case "late":
      do IO<Unit>:
        +observers : Chan(Chan(Completion.Completion<Payload>)) <- Chan.new(Chan(Completion.Completion<Payload>), 1)
        started : Unit & Result<&2, &1, Http.StartupError, Http.Server<LateContext>> <-
          Http.server.start(~LateContext, ~Unit, LateContext{observers, None{}}, Unit{}, config(port))
        late.started(observers, started)
    case "whole":
      do IO<Unit>:
        started : Unit & Result<&2, &1, Http.StartupError, Http.Server<Unit>> <- Http.server.start(~Unit, ~Unit, Unit{}, Unit{}, config(port))
        whole.started(started)
    case "stream":
      do IO<Unit>:
        started : Result<&2, &2, Http.StartupError, Unit> <- Http.serve.stream.config(~Upload, ~upload.start, ~upload.piece, ~upload.finish, ~upload.abort, ~owner, config(port))
        checked(started)
    case "writer":
      do IO<Unit>:
        started : Result<&2, &2, Http.StartupError, Unit> <- Http.serve.write.config(~Download, ~download.start, ~download.write, ~download.dispose, ~owner, config(port))
        checked(started)
    case "whole-convenience": Http.serve.on.with(~whole.convenience, ~owner, "127.0.0.1", port, 8n)
    case "stream-convenience": Http.serve.stream.on.with(~Upload, ~upload.start, ~upload.piece, ~upload.finish, ~upload.abort, ~owner, "127.0.0.1", port, 8n)
    case "writer-convenience": Http.serve.write.on.with(~Download, ~download.start, ~download.write, ~download.dispose, ~owner, "127.0.0.1", port, 8n)
    case _: IO.die(Unit, 1, "invalid mode")

def port(mode: String, number: Maybe<&2, U32>) -> IO(Unit):
  match number:
    case None{}: IO.die(Unit, 1, "invalid port")
    case Some{value}: run(mode, value)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> mode <> value <> Nil{}:
      port(mode, U32.read(value))
    case _: IO.die(Unit, 1, "usage: outcome_check <mode> <port>")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
