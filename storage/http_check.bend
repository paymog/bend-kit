import Base
import ./storage.bend as S
import ./http.bend as Transport
import bend-kit-http@0.39.2.0/http.bend as Http
import bend-kit-http@0.39.2.0/completion.bend as Completion
import bend-kit-wire@0.4.8.0/wire.bend as Wire
import bend-kit-files@0.4.0.1/files.bend as Files

type Context is Data:
  Context{dir: String, tamper: Bool}

def ok(good: Bool, name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok HTTP storage " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad HTTP storage " ++ name)

def handle(context: Context, request: Http.Req) -> IO(Http.Reply):
  Context{dir, bad} = context
  match bad:
    case False{}:
      Transport.handle(dir, request)
    case True{}:
      IO.pure(Http.Reply, Transport.response(200, Http.from_string("end\n")))

def observe(context: Context, status: U32, outcome: Completion.Outcome) -> IO(Unit):
  Completion.ignore(status, outcome)

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

def happy(+base: String, +dir: String, +root: S.Digest) -> IO(Unit):
  do IO<Unit>:
    n : U32 <- IO.try(U32, Transport.sync(base, dir, root))
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
    restored : S.Tree<S.Blob> <- IO.try(S.Tree<S.Blob>, S.Disk.checkout(dir, root))
    restored_hash : S.Digest & S.Store<S.Digest, S.Blob> <- IO.try(S.Digest & S.Store<S.Digest, S.Blob>, S.commit(restored))
    matches(root, restored_hash)
    +absent : S.Digest <- IO.try(S.Digest, S.digest(Http.from_string("not an object")))
    missing : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, absent)
    ok(failed(U32, missing, "storage: HTTP object status 404"), "missing source object fails the sync")
    rejected(base, root)
    IO.try(Unit, S.write.file(S.Disk.object(dir, leaf), Http.from_string("end\n")))
    corrupt : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, root)
    ok(failed(U32, corrupt, "storage: object " ++ S.Digest.hex(leaf) ++ " does not match its digest"), "refuses a corrupt local object")

def exercise(bad: Bool, +base: String, +dir: String, +root: S.Digest) -> IO(Unit):
  match bad:
    case False{}:
      happy(base, dir, root)
    case True{}:
      do IO<Unit>:
        refused : Result<&1, &1, U32 & String, U32> <- Transport.sync(base, dir, root)
        ok(failed(U32, refused, "storage: object " ++ S.Digest.hex(root) ++ " does not match its digest"), "tampered response fails ingress")
        exists : Bool <- Files.exists(S.Disk.object(dir, root))
        ok(Bool.not(exists), "tampered object is not written")

def running(+bad: Bool, +dir: String, +root: S.Digest, +port: U32, result: Http.Server<Context> & Http.ServerControl) -> IO(Unit):
  (owned, control) = result
  do IO<Unit>:
    done : Chan(Http.ServerExit) <- IO.fork(Http.ServerExit, Http.server.run(~Context, ~handle, ~observe, owned))
    exercise(bad, "http://127.0.0.1:" ++ U32.show(port), dir, root)
    stopped : Bool <- Http.server.stop(control)
    exit : Http.ServerExit <- IO.join(Http.ServerExit, done)
    ok(stopped, "server drains and closes")
    unavailable : Result<&1, &1, U32 & String, Http.Body> <- Transport.get("http://127.0.0.1:" ++ U32.show(port), root)
    ok(failed(Http.Body, unavailable, "storage: HTTP object request failed"), "closed server fails the request")

def started(bad: Bool, dir: String, root: S.Digest, port: U32, result: Unit & Result<&2, &1, Http.StartupError, Http.Server<Context>>) -> IO(Unit):
  (unit, startup) = result
  match startup:
    case Fail{error}:
      IO.die(Unit, 1, "storage HTTP server failed to start")
    case Done{server}:
      running(bad, dir, root, port, Http.server.control(~Context, server))

def bound(+bad: Bool, src: String, dir: String, root: S.Digest, bound: Listener & U32) -> IO(Unit):
  (listener, +port) = bound
  do IO<Unit>:
    result : Unit & Result<&2, &1, Http.StartupError, Http.Server<Context>> <- Http.server.started(~Context, ~Unit, Context{src, bad}, Unit{}, Http.server.config("127.0.0.1", port), Done{listener})
    started(bad, dir, root, port, result)

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
