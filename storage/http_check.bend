import Base
import ./storage.bend as S
import ./pure.bend as P
import ./http.bend as Transport
import bend-kit-http@0.45.0.3/http.bend as Http
import bend-kit-http@0.45.0.3/pure.bend as Pure
import bend-kit-http@0.45.0.3/completion.bend as Completion
import bend-kit-wire@0.4.8.1/wire.bend as Wire
import bend-kit-files@0.4.0.3/files.bend as Files
import bend-kit-http@0.45.0.3/admission.bend as Admission
import bend-kit-time@0.3.0.5/pure.bend as Time
import ./http_stream_check.bend as StreamCheck

type Context is Data:
  Context{dir: String, tamper: Bool, events: Chan(Char)}

def ok(good: Bool, name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok HTTP storage " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad HTTP storage " ++ name)

def reply(bad: Bool, dir: String, request: Pure.Req) -> IO(Http.WriteHead<Transport.Source>):
  match bad:
    case False{}:
      Transport.handle(dir, request)
    case True{}:
      IO.pure(Http.WriteHead<Transport.Source>, Transport.response(200, Pure.from_string("end\n")))

def handle(context: Context, request: Pure.Req) -> IO(Http.WriteHead<Transport.Source>):
  Context{dir, bad, events} = context
  do IO<Http.WriteHead<Transport.Source>>:
    sent : Result<&1, &1, Char, Unit> <- Chan.send(Char, events, 'r')
    reply(bad, dir, request)

def observe(context: Context, status: U32, outcome: Completion.Outcome) -> IO(Unit):
  Completion.ignore(status, outcome)

def connection(context: Context, limits: Pure.Limits, inbox: Chan(Admission.Command), socket: Socket) -> IO(Unit):
  Context{dir, bad, +events} = context
  do IO<Unit>:
    opened : Result<&1, &1, Char, Unit> <- Chan.send(Char, events, 'o')
    Http.serve.write.talk(~Context, ~Transport.Source, ~handle, ~Transport.write, ~Transport.dispose, ~observe, Context{dir, bad, events}, limits, inbox,
      Some{Pure.Serving{(socket, Pure.TurnMore{Pure.sv.none(), False{}}), None{}}})
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

def errors() -> IO(Unit):
  do IO<Unit>:
    ok(String.eq(Transport.error(Pure.ErrUrl{}), "invalid URL"), "URL error")
    ok(String.eq(Transport.error(Pure.ErrDns{}), "DNS lookup failed"), "DNS error")
    ok(String.eq(Transport.error(Pure.ErrConnect{61, "refused"}), "connection failed (61): refused"), "connection error details")
    ok(String.eq(Transport.error(Pure.ErrTls{7, "certificate"}), "TLS failed (7): certificate"), "TLS error details")
    ok(String.eq(Transport.error(Pure.ErrRead{54, "reset"}), "read failed (54): reset"), "read error details")
    ok(String.eq(Transport.error(Pure.ErrWrite{32, "pipe"}), "write failed (32): pipe"), "write error details")
    ok(String.eq(Transport.error(Pure.ErrTimeout{}), "timeout"), "timeout error")
    ok(String.eq(Transport.error(Pure.ErrRedirect{}), "redirect failed"), "redirect error")
    ok(String.eq(Transport.error(Pure.ErrBad{}), "malformed or unsupported response, or response limit exceeded"), "bad response error")
    ok(failed(Maybe<&1, Pure.Body>, Transport.copy.result(Fail{Pure.ErrRead{54, "reset"}}), "storage: HTTP object stream failed: read failed (54): reset"), "stream keeps the HTTP cause")

def matches(root: P.Digest, result: P.Digest & P.Store<P.Digest, P.Blob>) -> IO(Unit):
  (digest, objects) = result
  ok(Cmp.is_eq(P.Digest.cmp(digest, root)), "checkout reconstructs the requested root")

def notfound(result: Result<&1, &1, Pure.Err, Pure.Res>) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit, 1, "HTTP rejection request failed")
    case Done{Pure.Res{status, headers, body}}:
      ok(U32.is_eq(status, 404), "rejects an invalid object request")

def rejected(+base: String, +root: P.Digest) -> IO(Unit):
  do IO<Unit>:
    traversal : Result<&1, &1, Pure.Err, Pure.Res> <- Http.get(base ++ "/objects/../roots/x")
    notfound(traversal)
    short : Result<&1, &1, Pure.Err, Pure.Res> <- Http.get(base ++ "/objects/" ++ String.drop(P.Digest.hex(root), 1n))
    notfound(short)
    outside : Result<&1, &1, Pure.Err, Pure.Res> <- Http.get(base ++ "/nope")
    notfound(outside)
    method : Result<&1, &1, Pure.Err, Pure.Res> <- Http.fetch("POST", base ++ "/objects/" ++ P.Digest.hex(root), Pure.empty(), Pure.from_string(""))
    notfound(method)

def happy(+base: String, +dir: String, +root: P.Digest, +events: Chan(Char)) -> IO(Unit):
  do IO<Unit>:
    start : Time.Duration <- Http.clock.mono()
    n : U32 <- IO.try(U32, Transport.sync(base, dir, root))
    stop : Time.Duration <- Http.clock.mono()
    elapsed(start, stop)
    events.check("orrrc", events)
    ok(U32.is_eq(n, 3), "fetches only the three missing objects, sharing one file")
    again : U32 <- IO.try(U32, Transport.sync(base, dir, root))
    ok(U32.is_eq(again, 0), "repeated sync fetches nothing")
    tree : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, S.Disk.checkout(dir, root))
    back : P.Digest & P.Store<P.Digest, P.Blob> <- IO.try(P.Digest & P.Store<P.Digest, P.Blob>, S.commit(tree))
    matches(root, back)
    blob : P.Blob <- IO.try(P.Blob, S.Blob.string("shared\u{0}payload"))
    +leaf : P.Digest <- IO.try(P.Digest, S.object.digest(P.OFile{blob}))
    IO.try(Unit, Files.remove(S.Disk.object(dir, leaf)))
    repaired : U32 <- IO.try(U32, Transport.sync(base, dir, root))
    ok(U32.is_eq(repaired, 1), "walks existing parents and repairs one missing shared descendant")
    events.check("orc", events)
    restored : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, S.Disk.checkout(dir, root))
    restored_hash : P.Digest & P.Store<P.Digest, P.Blob> <- IO.try(P.Digest & P.Store<P.Digest, P.Blob>, S.commit(restored))
    matches(root, restored_hash)
    +absent : P.Digest <- IO.try(P.Digest, S.digest(Pure.from_string("not an object")))
    missing : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, absent)
    ok(failed(U32, missing, "storage: object " ++ P.Digest.hex(absent) ++ ": storage: HTTP object status 404"), "missing source object identifies its digest and status")
    events.check("orc", events)
    exists : Bool <- Files.exists(S.Disk.object(dir, absent))
    ok(Bool.not(exists), "missing object is not written")
    rejected(base, root)
    events.check("orcorcorcorc", events)
    IO.try(Unit, S.write.file(S.Disk.object(dir, leaf), Pure.from_string("end\n")))
    corrupt : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, root)
    ok(failed(U32, corrupt, "storage: object " ++ P.Digest.hex(leaf) ++ " does not match its digest"), "refuses a corrupt local object")

def exercise(bad: Bool, +base: String, +dir: String, +root: P.Digest, +events: Chan(Char)) -> IO(Unit):
  match bad:
    case False{}:
      happy(base, dir, root, events)
    case True{}:
      do IO<Unit>:
        refused : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, root)
        ok(failed(U32, refused, "storage: object " ++ P.Digest.hex(root) ++ " does not match its digest"), "tampered response fails ingress")
        events.check("orc", events)
        exists : Bool <- Files.exists(S.Disk.object(dir, root))
        ok(Bool.not(exists), "tampered object is not written")

def running(+bad: Bool, +dir: String, +root: P.Digest, +port: U32, +events: Chan(Char), result: Http.Server<Context> & Http.ServerControl) -> IO(Unit):
  (owned, control) = result
  do IO<Unit>:
    done : Chan(Pure.ServerExit) <- IO.fork(Pure.ServerExit, Http.server.run.loop(~Context, ~connection, Http.ServerListening{owned}))
    exercise(bad, "http://127.0.0.1:" ++ U32.show(port), dir, root, events)
    stopped : Bool <- Http.server.stop(control)
    exit : Pure.ServerExit <- IO.join(Pure.ServerExit, done)
    ok(stopped, "server drains and closes")
    IO.try(Unit, S.Disk.init(dir ++ "/closed"))
    unavailable : Result<&1, &1, U32 & String, U32> <- Transport.sync("http://127.0.0.1:" ++ U32.show(port), dir ++ "/closed", root)
    ok(failed(U32, unavailable, "storage: object " ++ P.Digest.hex(root) ++ ": storage: HTTP object request failed: connection failed ("), "closed server identifies its digest and connection cause")
    Chan.close(Char, events)

def started(bad: Bool, dir: String, root: P.Digest, port: U32, events: Chan(Char), result: Unit & Result<&2, &1, Pure.StartupError, Http.Server<Context>>) -> IO(Unit):
  (unit, startup) = result
  match startup:
    case Fail{error}:
      IO.die(Unit, 1, "storage HTTP server failed to start")
    case Done{server}:
      running(bad, dir, root, port, events, Http.server.control(~Context, server))

def bound(+bad: Bool, src: String, dir: String, root: P.Digest, bound: Listener & U32) -> IO(Unit):
  (listener, +port) = bound
  do IO<Unit>:
    +events : Chan(Char) <- Chan.new(Char, 64)
    result : Unit & Result<&2, &1, Pure.StartupError, Http.Server<Context>> <- Http.server.started(~Context, ~Unit, Context{src, bad, events}, Unit{}, Pure.server.config("127.0.0.1", port), Done{listener})
    started(bad, dir, root, port, events, result)

def serve(bad: Bool, src: String, dir: String, root: P.Digest) -> IO(Unit):
  do IO<Unit>:
    listener : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    bound(bad, src, dir, root, listener)

def large.running(+src: String, +dst: String, +port: U32, +events: Chan(Char), pair: Http.Server<Context> & Http.ServerControl) -> IO(Unit):
  (server, control) = pair
  do IO<Unit>:
    done : Chan(Pure.ServerExit) <- IO.fork(Pure.ServerExit, Http.server.run.loop(~Context, ~connection, Http.ServerListening{server}))
    IO.print("HTTP storage real origin transfer on port " ++ U32.show(port))
    count : U32 <- IO.try(U32, Transport.sync("http://127.0.0.1:" ++ U32.show(port), dst, StreamCheck.root()))
    ok(U32.is_eq(count, 1), "real origin streams a 17 MiB object")
    events.check("orc", events)
    stopped : Bool <- Http.server.stop(control)
    exit : Pure.ServerExit <- IO.join(Pure.ServerExit, done)
    ok(stopped, "large origin drains")
    StreamCheck.reconstruct(dst)
    Chan.close(Char, events)

def large.started(src: String, dst: String, port: U32, events: Chan(Char), pair: Unit & Result<&2, &1, Pure.StartupError, Http.Server<Context>>) -> IO(Unit):
  (owner, result) = pair
  match result:
    case Fail{error}:
      IO.die(Unit, 1, "large origin startup failed")
    case Done{server}:
      large.running(src, dst, port, events, Http.server.control(~Context, server))

def large.bound(+src: String, dst: String, pair: Listener & U32) -> IO(Unit):
  (listener, +port) = pair
  do IO<Unit>:
    +events : Chan(Char) <- Chan.new(Char, 64)
    started : Unit & Result<&2, &1, Pure.StartupError, Http.Server<Context>> <- Http.server.started(~Context, ~Unit, Context{src, False{}, events}, Unit{}, Pure.server.config("127.0.0.1", port), Done{listener})
    large.started(src, dst, port, events, started)

def large(+dir: String) -> IO(Unit):
  do IO<Unit>:
    StreamCheck.one(0, dir ++ "/large-src")
    IO.try(Unit, S.Disk.init(dir ++ "/large-dst"))
    pair : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    large.bound(dir ++ "/large-src", dir ++ "/large-dst", pair)

def run() -> IO(Unit):
  do IO<Unit>:
    errors()
    +dir : String <- IO.try(String, Files.temp_dir())
    IO.try(Unit, S.Disk.init(dir ++ "/src"))
    IO.try(Unit, S.Disk.init(dir ++ "/dst"))
    IO.try(Unit, S.Disk.init(dir ++ "/bad"))
    +blob : P.Blob <- IO.try(P.Blob, S.Blob.string("shared\u{0}payload"))
    +leaf : P.Digest <- IO.try(P.Digest, S.Disk.commit(dir ++ "/dst", P.TFile{blob}))
    +root : P.Digest <- IO.try(P.Digest, S.Disk.commit(dir ++ "/src", P.TItem{"a", P.TFile{blob}, P.TItem{"b", P.TFile{blob}, P.TEnd{}}}))
    serve(False{}, dir ++ "/src", dir ++ "/dst", root)
    serve(True{}, dir ++ "/src", dir ++ "/bad", root)
    StreamCheck.run()
    large(dir)
