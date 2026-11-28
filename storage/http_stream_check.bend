import Base
import ./storage.bend as S
import ./pure.bend as P
import ./http.bend as Transport
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-files@0.4.0.3/files.bend as Files
import bend-kit-wire@0.4.9.0/wire.bend as Wire

# SHA-256 of "file 17825792\n" followed by 17 MiB of zero octets.
def root() -> P.Digest:
  Maybe.default(&2, P.Digest, P.Digest.read("89c9109ce931e20ac63a1729d6f6a9db03dee9401161eb8a3fbd35c4a09a9528"), P.Digest{Nil{}})

def ok(good: Bool, name: String) -> IO(Unit):
  match good:
    case True{}:
      IO.print("ok HTTP stream " ++ name)
    case False{}:
      IO.die(Unit, 1, "bad HTTP stream " ++ name)

def sent(pair: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Socket):
  (socket, result) = pair
  do IO<Socket>:
    IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, result))
    return socket

def send(socket: Socket, text: String) -> IO(Socket):
  do IO<Socket>:
    pair : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send(socket, text)
    sent(pair)

def chunks(fuel: Nat, socket: Socket) -> IO(Socket):
  match fuel:
    case 0n:
      IO.pure(Socket, socket)
    case 1n+p:
      do IO<Socket>:
        pair : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send.words(socket, 65536, Bytes.alloc(65536))
        next : Socket <- sent(pair)
        chunks(p, next)

def tail(bad: Bool, socket: Socket) -> IO(Socket):
  match bad:
    case True{}:
      send(socket, "x")
    case False{}:
      send(socket, "\u{0}")

def reply(+mode: U32, pair: Socket & Result<&1, &1, U32 & String, String>) -> IO(Unit):
  (socket, result) = pair
  do IO<Unit>:
    head : Socket <- send(socket, "HTTP/1.1 200 OK\r\nContent-Length: 17825806\r\nConnection: close\r\n\r\nfile 17825792\n")
    body : Socket <- chunks(Bool.pick(Nat, U32.is_eq(mode, 1), 136n, 271n), head)
    part : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.send.words(body, 65535, Bytes.alloc(65536))
    final : Socket <- sent(part)
    done : Socket <- tail(U32.is_eq(mode, 2), final)
    Socket.close(done)

def accepted(mode: U32, pair: Listener & Result<&1, &1, U32 & String, Socket>) -> IO(Unit):
  (listener, result) = pair
  do IO<Unit>:
    Listener.close(listener)
    socket : Socket <- IO.try(Socket, IO.pure(Result<&1, &1, U32 & String, Socket>, result))
    request : Socket & Result<&1, &1, U32 & String, String> <- Wire.recv(socket, 65536, 30000)
    reply(mode, request)

def server(mode: U32, listener: Listener) -> IO(Unit):
  do IO<Unit>:
    pair : Listener & Result<&1, &1, U32 & String, Socket> <- TCP.accept(listener)
    accepted(mode, pair)

def result.good(mode: U32, result: Result<&1, &1, U32 & String, U32>) -> Bool:
  match result:
    case Done{count}:
      Bool.and(U32.is_eq(mode, 0), U32.is_eq(count, 1))
    case Fail{e}:
      U32.is_ne(mode, 0)

def exercise(+mode: U32, +dir: String, pair: Listener & U32) -> IO(Unit):
  (listener, port) = pair
  do IO<Unit>:
    done : Chan(Unit) <- IO.fork(Unit, server(mode, listener))
    result : Result<&1, &1, U32 & String, U32> <- Transport.sync("http://127.0.0.1:" ++ U32.show(port), dir, root())
    ok(result.good(mode, result), "large, truncated, or tampered transfer " ++ U32.show(mode))
    IO.join(Unit, done)
    exists : Bool <- Files.exists(S.Disk.object(dir, root()))
    ok(Bool.pick(Bool, exists, U32.is_eq(mode, 0), U32.is_ne(mode, 0)), "only the valid object is published")
    temps : List<&2, String> <- IO.try(List<&2, String>, Files.list_dir(dir ++ "/tmp"))
    ok(Nat.is_eq(List.length(&2, String, temps), 0n), "temporary files are removed")

def reconstructed(pair: P.Digest & P.Store<P.Digest, P.Blob>) -> IO(Unit):
  (digest, objects) = pair
  ok(Cmp.is_eq(P.Digest.cmp(digest, root())), "17 MiB checkout reconstructs the requested root")

def reconstruct(dir: String) -> IO(Unit):
  do IO<Unit>:
    tree : P.Tree<P.Blob> <- IO.try(P.Tree<P.Blob>, S.Disk.checkout(dir, root()))
    pair : P.Digest & P.Store<P.Digest, P.Blob> <- IO.try(P.Digest & P.Store<P.Digest, P.Blob>, S.commit(tree))
    reconstructed(pair)

def one(mode: U32, +dir: String) -> IO(Unit):
  do IO<Unit>:
    IO.try(Unit, S.Disk.init(dir))
    pair : Listener & U32 <- IO.try(Listener & U32, Wire.listen("127.0.0.1", 0))
    exercise(mode, dir, pair)

def refused(result: Result<&1, &1, U32 & String, P.Obj<P.Digest, Unit>>) -> Bool:
  match result:
    case Fail{e}:
      True{}
    case Done{node}:
      False{}

def invalid(+dir: String, +raw: String) -> IO(Unit):
  do IO<Unit>:
    +digest : P.Digest <- IO.try(P.Digest, S.digest(Bytes.from_string(raw)))
    IO.try(Unit, S.write.file(dir ++ "/tmp/invalid", Bytes.from_string(raw)))
    result : Result<&1, &1, U32 & String, P.Obj<P.Digest, Unit>> <- Transport.receive(dir, digest, dir ++ "/tmp/invalid")
    ok(refused(result), "matching hash does not admit a bad encoding")
    exists : Bool <- Files.exists(S.Disk.object(dir, digest))
    ok(Bool.not(exists), "bad encoding is not published")
    temporary : Bool <- Files.exists(dir ++ "/tmp/invalid")
    ok(Bool.not(temporary), "bad encoding removes its temporary file")

def run() -> IO(Unit):
  do IO<Unit>:
    +dir : String <- IO.try(String, Files.temp_dir())
    one(0, dir ++ "/large")
    IO.try(Unit, S.Disk.init(dir ++ "/invalid"))
    invalid(dir ++ "/invalid", "file 01\nx")
    invalid(dir ++ "/invalid", "file 2\nx")
    invalid(dir ++ "/invalid", "end\nx")
    invalid(dir ++ "/invalid", "item bad\n")
    reconstruct(dir ++ "/large")
    one(1, dir ++ "/short")
    one(2, dir ++ "/tamper")

def main() -> IO(Unit):
  run()
