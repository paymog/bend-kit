import Base
import ./storage.bend as S
import ./http.bend as Transport
import bend-kit-http@0.40.0.1/http.bend as Http
import bend-kit-http@0.40.0.1/completion.bend as Completion
import bend-kit-wire@0.4.8.1/wire.bend as Wire
import bend-kit-files@0.4.0.1/files.bend as Files
import bend-kit-http@0.40.0.1/admission.bend as Admission
import bend-kit-time@0.3.0.1/time.bend as Time
import ./http_stream_check.bend as StreamCheck

type Context is Data:
  Context{dir: String, tamper: Bool, events: Chan(Char)}

def ok(good: Bool, name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok HTTP storage " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad HTTP storage " ++ name)

def reply(bad: Bool, dir: String, request: Http.Req) -> IO(Http.Reply):
  match bad:
    case False{}:
      Transport.handle(dir, request)
    case True{}:
      IO.pure(Http.Reply, Transport.response(200, Http.from_string("end\n")))

def handle(context: Context, request: Http.Req) -> IO(Http.Reply):
  Context{dir, bad, events} = context
  do IO<Http.Reply>:
    sent : Result<&1, &1, Char, Unit> <- Chan.send(Char, events, 'r')
    reply(bad, dir, request)

def observe(context: Context, status: U32, outcome: Completion.Outcome) -> IO(Unit):
  Completion.ignore(status, outcome)

def connection(context: Context, limits: Http.Limits, inbox: Chan(Admission.Command), socket: Socket) -> IO(Unit):
  Context{dir, bad, +events} = context
  do IO<Unit>:
    opened : Result<&1, &1, Char, Unit> <- Chan.send(Char, events, 'o')
    Http.talk(~Context, ~handle, ~observe, Context{dir, bad, events}, limits, inbox,
      Some{Http.Serving{(socket, Http.TurnMore{Http.sv.none(), False{}}), None{}}})
    closed : Result<&1, &1, Char, Unit> <- Chan.send(Char, events, 'c')
    return Unit{}

def events.read(expected: String, +events: Chan(Char)) -> IO(Bool):
  match expected:
    case SNil{}:
      IO.pure(Bool, True{})
    case SCon{Chr{c}, rest}:
      do IO<Bool>:
        got : Maybe<&1, Char> <- Chan.recv(Char, events)
        ok(Char.is_eq(Maybe.default(&1, Char, got, '!'), Chr{c}), "connection event order")
        events.read(rest, events)

def events.done(result: Maybe<&1, Bool>) -> IO(Unit):
  match result:
    case None{}:
      IO.die(Unit, 1, "HTTP storage pool did not close")
    case Some{good}:
      ok(good, "pool closes after the last response")

def events.check(expected: String, events: Chan(Char)) -> IO(Unit):
  do IO<Unit>:
    result : Maybe<&1, Bool> <- IO.within(Bool, 2000, events.read(expected, events))
    events.done(result)

def elapsed(start: Time.Duration, stop: Time.Duration) -> IO(Unit):
  IO.print("HTTP storage fixed closure: " ++ Time.Duration.show_ms(Time.Duration.sub(stop, start)) ++ " ms")

def failed(-A: Type, result: Result<&1, &1, U32 & String, A>, want: String) -> Bool:
  match result:
    case Done{value}:
      False{}
    case Fail{(code, message)}:
      String.starts_with(message, want)

def matches(root: S.Digest, result: S.Digest & S.Store<S.Digest, S.Blob>) -> IO(Unit):
  (digest, objects) = result
  ok(Cmp.is_eq(S.Digest.cmp(digest, root)), "checkout reconstructs the requested root")

def notfound(result: Result<&1, &1, Http.Err, Http.Res>) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit, 1, "HTTP rejection request failed")
    case Done{Http.Res{status, headers, body}}:
      ok(U32.is_eq(status, 404), "rejects an invalid object request")

def rejected(+base: String, +root: S.Digest) -> IO(Unit):
  do IO<Unit>:
    traversal : Result<&1, &1, Http.Err, Http.Res> <- Http.get(base ++ "/objects/../roots/x")
    notfound(traversal)
    short : Result<&1, &1, Http.Err, Http.Res> <- Http.get(base ++ "/objects/" ++ String.drop(S.Digest.hex(root), 1n))
    notfound(short)
    outside : Result<&1, &1, Http.Err, Http.Res> <- Http.get(base ++ "/nope")
    notfound(outside)
    method : Result<&1, &1, Http.Err, Http.Res> <- Http.fetch("POST", base ++ "/objects/" ++ S.Digest.hex(root), Http.empty(), Http.from_string(""))
    notfound(method)

def happy(+base: String, +dir: String, +root: S.Digest, +events: Chan(Char)) -> IO(Unit):
  do IO<Unit>:
    start : Time.Duration <- Time.mono()
    n : U32 <- IO.try(U32, Transport.sync(base, dir, root))
    stop : Time.Duration <- Time.mono()
    elapsed(start, stop)
    events.check("orrrc", events)
    ok(U32.is_eq(n, 3), "fetches only the three missing objects, sharing one file")
    again : U32 <- IO.try(U32, Transport.sync(base, dir, root))
    ok(U32.is_eq(again, 0), "repeated sync fetches nothing")
    tree : S.Tree<S.Blob> <- IO.try(S.Tree<S.Blob>, S.Disk.checkout(dir, root))
    back : S.Digest & S.Store<S.Digest, S.Blob> <- IO.try(S.Digest & S.Store<S.Digest, S.Blob>, S.commit(tree))
    matches(root, back)
    blob : S.Blob <- IO.try(S.Blob, S.Blob.string("shared\u{0}payload"))
    +leaf : S.Digest <- IO.try(S.Digest, S.object.digest(S.OFile{blob}))
    IO.try(Unit, Files.remove(S.Disk.object(dir, leaf)))
    repaired : U32 <- IO.try(U32, Transport.sync(base, dir, root))
    ok(U32.is_eq(repaired, 1), "walks existing parents and repairs one missing shared descendant")
    events.check("orc", events)
    restored : S.Tree<S.Blob> <- IO.try(S.Tree<S.Blob>, S.Disk.checkout(dir, root))
    restored_hash : S.Digest & S.Store<S.Digest, S.Blob> <- IO.try(S.Digest & S.Store<S.Digest, S.Blob>, S.commit(restored))
    matches(root, restored_hash)
    +absent : S.Digest <- IO.try(S.Digest, S.digest(Http.from_string("not an object")))
    missing : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, absent)
    ok(failed(U32, missing, "storage: HTTP object status 404"), "missing source object fails the sync")
    events.check("orc", events)
    exists : Bool <- Files.exists(S.Disk.object(dir, absent))
    ok(Bool.not(exists), "missing object is not written")
    rejected(base, root)
    events.check("orcorcorcorc", events)
    IO.try(Unit, S.write.file(S.Disk.object(dir, leaf), Http.from_string("end\n")))
    corrupt : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, root)
    ok(failed(U32, corrupt, "storage: object " ++ S.Digest.hex(leaf) ++ " does not match its digest"), "refuses a corrupt local object")

def exercise(bad: Bool, +base: String, +dir: String, +root: S.Digest, +events: Chan(Char)) -> IO(Unit):
  match bad:
    case False{}:
      happy(base, dir, root, events)
    case True{}:
      do IO<Unit>:
        refused : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, root)
        ok(failed(U32, refused, "storage: object " ++ S.Digest.hex(root) ++ " does not match its digest"), "tampered response fails ingress")
        events.check("orc", events)
        exists : Bool <- Files.exists(S.Disk.object(dir, root))
        ok(Bool.not(exists), "tampered object is not written")

def running(+bad: Bool, +dir: String, +root: S.Digest, +port: U32, +events: Chan(Char), result: Http.Server<Context> & Http.ServerControl) -> IO(Unit):
  (owned, control) = result
  do IO<Unit>:
    done : Chan(Http.ServerExit) <- IO.fork(Http.ServerExit, Http.server.run.loop(~Context, ~connection, Http.ServerListening{owned}))
    exercise(bad, "http://127.0.0.1:" ++ U32.show(port), dir, root, events)
    stopped : Bool <- Http.server.stop(control)
    exit : Http.ServerExit <- IO.join(Http.ServerExit, done)
    ok(stopped, "server drains and closes")
    IO.try(Unit, S.Disk.init(dir ++ "/closed"))
    unavailable : Result<&1, &1, U32 & String, U32> <- Transport.sync("http://127.0.0.1:" ++ U32.show(port), dir ++ "/closed", root)
    ok(failed(U32, unavailable, "storage: HTTP object request failed"), "closed server fails the request")
    Chan.close(Char, events)

def started(bad: Bool, dir: String, root: S.Digest, port: U32, events: Chan(Char), result: Unit & Result<&2, &1, Http.StartupError, Http.Server<Context>>) -> IO(Unit):
  (unit, startup) = result
  match startup:
    case Fail{error}:
      IO.die(Unit, 1, "storage HTTP server failed to start")
    case Done{server}:
      running(bad, dir, root, port, events, Http.server.control(~Context, server))

def bound(+bad: Bool, src: String, dir: String, root: S.Digest, bound: Listener & U32) -> IO(Unit):
  (listener, +port) = bound
  do IO<Unit>:
    +events : Chan(Char) <- Chan.new(Char, 64)
    result : Unit & Result<&2, &1, Http.StartupError, Http.Server<Context>> <- Http.server.started(~Context, ~Unit, Context{src, bad, events}, Unit{}, Http.server.config("127.0.0.1", port), Done{listener})
    started(bad, dir, root, port, events, result)

def serve(bad: Bool, src: String, dir: String, root: S.Digest) -> IO(Unit):
  do IO<Unit>:
    listener : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    bound(bad, src, dir, root, listener)

def run() -> IO(Unit):
  do IO<Unit>:
    +dir : String <- IO.try(String, Files.temp_dir())
    IO.try(Unit, S.Disk.init(dir ++ "/src"))
    IO.try(Unit, S.Disk.init(dir ++ "/dst"))
    IO.try(Unit, S.Disk.init(dir ++ "/bad"))
    +blob : S.Blob <- IO.try(S.Blob, S.Blob.string("shared\u{0}payload"))
    +leaf : S.Digest <- IO.try(S.Digest, S.Disk.commit(dir ++ "/dst", S.TFile{blob}))
    +root : S.Digest <- IO.try(S.Digest, S.Disk.commit(dir ++ "/src", S.TItem{"a", S.TFile{blob}, S.TItem{"b", S.TFile{blob}, S.TEnd{}}}))
    serve(False{}, dir ++ "/src", dir ++ "/dst", root)
    serve(True{}, dir ++ "/src", dir ++ "/bad", root)
    StreamCheck.run()
