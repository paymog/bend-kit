import Base
import ./stream.bend as Stream
import bend-kit-files@0.1.1.1/files.bend as Files
import bend-kit-wire@0.4.6.1/wire.bend as Wire
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes

def outcome(o: Stream.Outcome) -> IO(Unit):
  match o:
    case Stream.Complete{n}:
      IO.print("Complete " ++ U32.show(n))
    case Stream.Failed{n, Stream.BadChunk{}}:
      IO.print("BadChunk " ++ U32.show(n))
    case Stream.Failed{n, Stream.Limit{}}:
      IO.print("Limit " ++ U32.show(n))
    case Stream.Failed{n, Stream.Read{code, why}}:
      IO.print("Read " ++ U32.show(n) ++ " " ++ U32.show(code) ++ " " ++ why)
    case Stream.Failed{n, Stream.Write{code, why}}:
      IO.print("Write " ++ U32.show(n) ++ " " ++ U32.show(code) ++ " " ++ why)

def next(pair: File & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match pair:
    case (f, Fail{(code, why)}):
      do IO<Unit>:
        IO.print("NextError " ++ U32.show(code) ++ " " ++ why)
        File.close(f)
    case (f, Done{(len, words)}):
      do IO<Unit>:
        IO.print("Next " ++ Bytes.to_hex(Bytes.Bytes{len, words}))
        File.close(f)

def files.done(pair: File & File & Stream.Outcome) -> IO(Unit):
  match pair:
    case (a, b, o):
      do IO<Unit>:
        outcome(o)
        File.close(b)
        r : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Files.read.words(a, 16)
        next(r)

def close(tls: Bool, s: Socket) -> IO(Unit):
  match tls:
    case True{}:
      Wire.tls.close(s)
    case False{}:
      Socket.close(s)

def sent(tls: Bool, pair: File & Socket & Stream.Outcome) -> IO(Unit):
  match pair:
    case (f, s, o):
      do IO<Unit>:
        outcome(o)
        close(tls, s)
        r : File & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Files.read.words(f, 16)
        next(r)

def probe(o: Stream.Outcome) -> Bool:
  match o:
    case Stream.Failed{n, Stream.Limit{}}:
      True{}
    case Stream.Failed{n, Stream.BadChunk{}}:
      True{}
    case _:
      False{}

def socket.next.print(tls: Bool, s: Socket, b: U32 & Array<U32>) -> IO(Unit):
  match b:
    case (len, words):
      do IO<Unit>:
        IO.print("Next " ++ Bytes.to_hex(Bytes.Bytes{len, words}))
        close(tls, s)

def socket.next(tls: Bool, p: Socket & Result<&1, &1, U32 & String, U32 & Array<U32>>) -> IO(Unit):
  match p:
    case (s, r):
      do IO<Unit>:
        b : U32 & Array<U32> <- IO.pass(U32 & Array<U32>, r)
        socket.next.print(tls, s, b)

def socket.read(+tls: Bool, s: Socket) -> IO(Unit):
  match tls:
    case True{}:
      do IO<Unit>:
        r : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.tls.recv.words(s, 1, 1000)
        socket.next(tls, r)
    case False{}:
      do IO<Unit>:
        r : Socket & Result<&1, &1, U32 & String, U32 & Array<U32>> <- Wire.recv.words(s, 1, 1000)
        socket.next(tls, r)

def socket.finish(read: Bool, tls: Bool, s: Socket) -> IO(Unit):
  match read:
    case True{}:
      socket.read(tls, s)
    case False{}:
      close(tls, s)

def received.done(+o: Stream.Outcome, tls: Bool, s: Socket, f: File) -> IO(Unit):
  do IO<Unit>:
    outcome(o)
    File.close(f)
    socket.finish(probe(o), tls, s)

def received(tls: Bool, pair: Socket & File & Stream.Outcome) -> IO(Unit):
  match pair:
    case (s, f, o):
      received.done(o, tls, s, f)

def handshake(pair: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(Socket):
  match pair:
    case (s, r):
      do IO<Socket>:
        IO.pass(Unit, r)
        return s

def secure(tls: Bool, s: Socket) -> IO(Socket):
  match tls:
    case False{}:
      IO.pure(Socket, s)
    case True{}:
      do IO<Socket>:
        p : Socket & Result<&1, &1, U32 & String, Unit> <- Wire.tls.connect(s, "localhost", 5000)
        handshake(p)

def network(send: Bool, +tls: Bool, path: String, mode: String, port: U32, chunk: U32, cap: U32, ms: U32) -> IO(Unit):
  match send:
    case True{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open(path, mode))
        s : Socket <- IO.try(Socket, Wire.connect("127.0.0.1", port, 5000))
        s : Socket <- secure(tls, s)
        p : File & Socket & Stream.Outcome <- Stream.file.socket(f, s, tls, chunk, cap)
        sent(tls, p)
    case False{}:
      do IO<Unit>:
        f : File <- IO.try(File, File.open(path, mode))
        s : Socket <- IO.try(Socket, Wire.connect("127.0.0.1", port, 5000))
        s : Socket <- secure(tls, s)
        p : Socket & File & Stream.Outcome <- Stream.socket.file(s, f, tls, chunk, cap, ms)
        received(tls, p)

def run(file: Bool, kind: String, tls: String, path: String, dest: String, +mode: String, port: String, chunk: String, cap: String, ms: String) -> IO(Unit):
  match file:
    case True{}:
      do IO<Unit>:
        a : File <- IO.try(File, File.open(path, "r"))
        b : File <- IO.try(File, File.open(dest, mode))
        p : File & File & Stream.Outcome <- Stream.file.file(a, b, Maybe.default(&2, U32, U32.read(chunk), 0), Maybe.default(&2, U32, U32.read(cap), 0))
        files.done(p)
    case False{}:
      network(String.eq(kind, "send"), String.eq(tls, "tls"), path, mode,
        Maybe.default(&2, U32, U32.read(port), 0), Maybe.default(&2, U32, U32.read(chunk), 0),
        Maybe.default(&2, U32, U32.read(cap), 0), Maybe.default(&2, U32, U32.read(ms), 0))

def args(xs: List<&1, String>) -> IO(Unit):
  match xs:
    case Con{+kind, Con{tls, Con{path, Con{dest, Con{mode, Con{port, Con{chunk, Con{cap, Con{ms, Nil{}}}}}}}}}}:
      run(String.eq(kind, "file"), kind, tls, path, dest, mode, port, chunk, cap, ms)
    case _:
      IO.die(Unit, 1, "usage: live file|send|recv plain|tls path destination mode port chunk cap ms")

def main() -> IO(Unit):
  do IO<Unit>:
    xs : List<&1, String> <- IO.args()
    args(List.tail(&1, String, xs))
