import Base
import ./storage.bend as S
import ./pure.bend as P
import bend-kit-http@0.45.1.1/http.bend as Http
import bend-kit-http@0.45.1.1/pure.bend as Pure
import bend-kit-http@0.45.1.1/completion.bend as Completion
import bend-kit-files@0.4.0.3/files.bend as Files
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

type Source is Type:
  Object{file: File, size: U32}
  Message{body: Pure.Body}

# Git's dumb HTTP object walk: immutable objects are fetched by digest from a known root.
def response(status: U32, body: Pure.Body) -> Http.WriteHead<Source>:
  Bytes.Bytes{+len, buf} = body
  Http.WriteHead{status, Pure.set(Pure.empty(), "content-type", "application/octet-stream"), Some{len}, Message{Bytes.Bytes{len, buf}}, Completion.Unobserved{}}

def source.size(info: Files.Info) -> S.Run(U32):
  match info:
    case Files.Info{Files.Regular{}, size, time}:
      S.info.size(Files.Info{Files.Regular{}, size, time})
    case Files.Info{Files.Directory{}, size, time}:
      S.Run.fail(U32, (21, "storage: object is a directory"))
    case Files.Info{Files.Other{}, size, time}:
      S.Run.fail(U32, (22, "storage: object is not a regular file"))

def source(+path: String) -> S.Run(File & U32):
  do S.Run<File & U32>:
    info : Files.Info <- Files.stat(path)
    size : U32 <- source.size(info)
    file : File <- File.open(path, "r")
    return (file, size)

def served(result: Result<&1, &1, U32 & String, File & U32>) -> IO(Http.WriteHead<Source>):
  match result:
    case Done{(file, +size)}:
      IO.pure(Http.WriteHead<Source>, Http.WriteHead{200, Pure.set(Pure.empty(), "content-type", "application/octet-stream"), Some{size}, Object{file, size}, Completion.Unobserved{}})
    case Fail{(code, message)}:
      IO.pure(Http.WriteHead<Source>, response(Bool.pick(U32, U32.is_eq(code, 2), 404, 500), Pure.from_string("object unavailable\n")))

def object(+dir: String, digest: Maybe<&2, P.Digest>) -> IO(Http.WriteHead<Source>):
  match digest:
    case None{}:
      IO.pure(Http.WriteHead<Source>, response(404, Pure.from_string("not found\n")))
    case Some{d}:
      do IO<Http.WriteHead<Source>>:
        result : Result<&1, &1, U32 & String, File & U32> <- source(S.Disk.object(dir, d))
        served(result)

def route(valid: Bool, dir: String, path: String) -> IO(Http.WriteHead<Source>):
  match valid:
    case False{}:
      IO.pure(Http.WriteHead<Source>, response(404, Pure.from_string("not found\n")))
    case True{}:
      object(dir, P.Digest.read(String.drop(path, 9n)))

# Mount on a read-only store; freeze collection while the server serves its roots.
def handle(dir: String, request: Pure.Req) -> IO(Http.WriteHead<Source>):
  Pure.Req{+method, +path, headers, body} = request
  route(String.eq(method, "GET") && String.starts_with(path, "/objects/"), dir, path)

def dispose(state: Source) -> IO(Unit):
  match state:
    case Object{file, size}:
      File.close(file)
    case Message{body}:
      IO.pure(Unit, Unit{})

def close.socket(socket: Maybe<&1, Socket>) -> IO(Unit):
  match socket:
    case None{}:
      IO.pure(Unit, Unit{})
    case Some{s}:
      Socket.close(s)

def send.failed(writer: Http.Writer, code: U32, message: String) -> IO(Http.Writer):
  Http.Writer{socket, mode, until, outcome} = writer
  do IO<Http.Writer>:
    close.socket(socket)
    return Http.Writer{None{}, mode, until, Completion.WriteFailed{code, message}}

type Transfer is Type:
  Remaining{file: File, left: U32}
  Sent{}

def send.piece(empty: Bool, file: File, +left: U32, body: Bytes.Bytes, writer: Http.Writer) -> IO(Transfer & Http.Writer):
  match empty:
    case True{}:
      do IO<Transfer & Http.Writer>:
        File.close(file)
        failed : Http.Writer <- send.failed(writer, 5, "storage: short object read")
        return (Sent{}, failed)
    case False{}:
      Bytes.Bytes{+len, buf} = body
      do IO<Transfer & Http.Writer>:
        sent : Http.Writer <- Http.writer.write(writer, Bytes.Bytes{len, buf})
        return (Remaining{file, (left - len : U32)}, sent)

def send.read(writer: Http.Writer, +left: U32, pair: File & Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(Transfer & Http.Writer):
  match pair:
    case (file, Fail{(code, message)}):
      do IO<Transfer & Http.Writer>:
        File.close(file)
        failed : Http.Writer <- send.failed(writer, code, message)
        return (Sent{}, failed)
    case (file, Done{Bytes.Bytes{+len, buf}}):
      send.piece(U32.is_zero(len), file, left, Bytes.Bytes{len, buf}, writer)

def send.step(empty: Bool, file: File, +left: U32, writer: Http.Writer) -> IO(Transfer & Http.Writer):
  match empty:
    case True{}:
      do IO<Transfer & Http.Writer>:
        File.close(file)
        return (Sent{}, writer)
    case False{}:
      Http.Writer{socket, mode, until, outcome} = writer
      match socket:
        case None{}:
          do IO<Transfer & Http.Writer>:
            File.close(file)
            return (Sent{}, Http.Writer{None{}, mode, until, outcome})
        case Some{s}:
          do IO<Transfer & Http.Writer>:
            pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Files.read_bytes(file, U32.min(left, 65536))
            send.read(Http.Writer{Some{s}, mode, until, outcome}, left, pair)

def send(fuel: Nat, state: Transfer & Http.Writer) -> IO(Http.Writer):
  match fuel state:
    case _ Tuple{Sent{}, writer}:
      IO.pure(Http.Writer, writer)
    case 0n Tuple{Remaining{file, left}, writer}:
      do IO<Http.Writer>:
        File.close(file)
        send.failed(writer, 27, "storage: file send limit")
    case 1n+p Tuple{Remaining{file, +left}, writer}:
      do IO<Http.Writer>:
        next : Transfer & Http.Writer <- send.step(U32.is_zero(left), file, left, writer)
        send(p, next)

def write(state: Source, writer: Http.Writer, receipt: Completion.Receipt) -> IO(Http.Writer & Completion.Receipt):
  match state:
    case Object{file, +size}:
      do IO<Http.Writer & Completion.Receipt>:
        sent : Http.Writer <- send(2n+U32.to_nat(size), (Remaining{file, size}, writer))
        return (sent, receipt)
    case Message{body}:
      do IO<Http.Writer & Completion.Receipt>:
        sent : Http.Writer <- Http.writer.write(writer, body)
        return (sent, receipt)

def server.run(~observe: String -> U32 -> Completion.Outcome -> IO(Unit), server: Http.Server<String>) -> IO(Pure.ServerExit):
  Http.server.write.run(~String, ~Source, ~handle, ~write, ~dispose, ~observe, server)



def Run(-A: Type) -> Type:
  Http.Pool -> IO(Http.Pool & Result<&1, &1, U32 & String, A>)

def Run.pure(-A: Type, x: A) -> Run(A):
  pool => IO.pure(Http.Pool & Result<&1, &1, U32 & String, A>, (pool, Done{x}))

def Run.next(-A: Type, -B: Type, pair: Http.Pool & Result<&1, &1, U32 & String, A>, f: A -> Run(B)) -> IO(Http.Pool & Result<&1, &1, U32 & String, B>):
  (pool, result) = pair
  match result:
    case Fail{error}:
      IO.pure(Http.Pool & Result<&1, &1, U32 & String, B>, (pool, Fail{error}))
    case Done{x}:
      f(x)(pool)

def Run.bind(-A: Type, -B: Type, m: Run(A), f: A -> Run(B)) -> Run(B):
  pool => IO.bind(Http.Pool & Result<&1, &1, U32 & String, A>, Http.Pool & Result<&1, &1, U32 & String, B>, m(pool), pair => Run.next(A, B, pair, f))

def Run.lift(-A: Type, m: S.Run(A)) -> Run(A):
  pool => do IO<Http.Pool & Result<&1, &1, U32 & String, A>>:
    result : Result<&1, &1, U32 & String, A> <- m
    return (pool, result)

def Run.close(-A: Type, pair: Http.Pool & Result<&1, &1, U32 & String, A>) -> S.Run(A):
  (pool, result) = pair
  do IO<Result<&1, &1, U32 & String, A>>:
    Http.pool.close(pool)
    return result


def error(e: Pure.Err) -> String:
  match e:
    case Pure.ErrUrl{}:
      "invalid URL"
    case Pure.ErrDns{}:
      "DNS lookup failed"
    case Pure.ErrConnect{code, why}:
      "connection failed (" ++ U32.show(code) ++ "): " ++ why
    case Pure.ErrTls{code, why}:
      "TLS failed (" ++ U32.show(code) ++ "): " ++ why
    case Pure.ErrRead{code, why}:
      "read failed (" ++ U32.show(code) ++ "): " ++ why
    case Pure.ErrWrite{code, why}:
      "write failed (" ++ U32.show(code) ++ "): " ++ why
    case Pure.ErrTimeout{}:
      "timeout"
    case Pure.ErrRedirect{}:
      "redirect failed"
    case Pure.ErrBad{}:
      "malformed or unsupported response, or response limit exceeded"

def copy.result(result: Result<&1, &1, Pure.Err, Maybe<&1, Pure.Body>>) -> Result<&1, &1, U32 & String, Maybe<&1, Pure.Body>>:
  match result:
    case Fail{e}:
      Fail{(5, "storage: HTTP object stream failed: " ++ error(e))}
    case Done{piece}:
      Done{piece}

def copy.read(f: File, pair: Http.Stream & Result<&1, &1, Pure.Err, Maybe<&1, Pure.Body>>) -> Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Pure.Body>>):
  (next, result) = pair
  (next, (f, copy.result(result)))

def copy.next(st: Http.Stream, pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Pure.Body>>)):
  (f, result) = pair
  match result:
    case Fail{e}:
      IO.pure(Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Pure.Body>>), (st, (f, Fail{e})))
    case Done{u}:
      do IO<Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Pure.Body>>)>:
        pair : Http.Stream & Result<&1, &1, Pure.Err, Maybe<&1, Pure.Body>> <- Http.stream.read(st)
        return copy.read(f, pair)

def copy.write(over: Bool, f: File, body: Pure.Body) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  match over:
    case True{}:
      IO.pure(File & Result<&1, &1, U32 & String, Unit>, (f, Fail{(27, "storage: encoded object exceeds 4294967295 octets")}))
    case False{}:
      Files.write_bytes(f, body)

def copy(fuel: Nat, pair: Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Pure.Body>>), +total: U32) -> IO(Http.Stream & (File & Result<&1, &1, U32 & String, Unit>)):
  match fuel pair:
    case 0n Tuple{st, Tuple{f, result}}:
      IO.pure(Http.Stream & (File & Result<&1, &1, U32 & String, Unit>), (st, (f, Fail{(27, "storage: HTTP stream read limit")})))
    case 1n+p Tuple{st, Tuple{f, Fail{e}}}:
      IO.pure(Http.Stream & (File & Result<&1, &1, U32 & String, Unit>), (st, (f, Fail{e})))
    case 1n+p Tuple{st, Tuple{f, Done{None{}}}}:
      IO.pure(Http.Stream & (File & Result<&1, &1, U32 & String, Unit>), (st, (f, Done{Unit{}})))
    case 1n+p Tuple{st, Tuple{f, Done{Some{body}}}}:
      Bytes.Bytes{+len, buf} = body
      do IO<Http.Stream & (File & Result<&1, &1, U32 & String, Unit>)>:
        written : File & Result<&1, &1, U32 & String, Unit> <- copy.write(U32.is_gt(len, (4294967295 - total : U32)), f, Bytes.Bytes{len, buf})
        next : Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Pure.Body>>) <- copy.next(st, written)
        copy(p, next, (total + len : U32))

def status.result(good: Bool, message: String) -> Result<&1, &1, U32 & String, Unit>:
  match good:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{(22, "storage: " ++ message)}

def download.status(+status: U32, st: Http.Stream, f: File) -> IO(Http.Stream & (File & Result<&1, &1, U32 & String, Unit>)):
  do IO<Http.Stream & (File & Result<&1, &1, U32 & String, Unit>)>:
    first : Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Pure.Body>>) <- copy.next(st, (f, status.result(U32.is_eq(status, 200), "HTTP object status " ++ U32.show(status))))
    copy(1n+U32.to_nat(4294967295), first, 0)

def download.path(tmp: String, result: Result<&1, &1, U32 & String, Unit>) -> Result<&1, &1, U32 & String, String>:
  match result:
    case Fail{e}:
      Fail{e}
    case Done{u}:
      Done{tmp}

def download.closed(+tmp: String, pair: Http.Stream & (File & Result<&1, &1, U32 & String, Unit>)) -> IO(Http.Stream & Result<&1, &1, U32 & String, String>):
  (next, written) = pair
  do IO<Http.Stream & Result<&1, &1, U32 & String, String>>:
    closed : Result<&1, &1, U32 & String, Unit> <- S.write.close(written)
    cleaned : Result<&1, &1, U32 & String, Unit> <- S.write.cleanup(tmp, closed)
    return (next, download.path(tmp, cleaned))

def download.response(+tmp: String, f: File, pair: Http.Stream & Pure.Res) -> IO(Http.Stream & Result<&1, &1, U32 & String, String>):
  (stream, Pure.Res{status, headers, body}) = pair
  do IO<Http.Stream & Result<&1, &1, U32 & String, String>>:
    written : Http.Stream & (File & Result<&1, &1, U32 & String, Unit>) <- download.status(status, stream, f)
    download.closed(tmp, written)

def download.opened(st: Http.Stream, opened: Result<&1, &1, U32 & String, String & File>) -> IO(Http.Stream & Result<&1, &1, U32 & String, String>):
  match opened:
    case Fail{e}:
      IO.pure(Http.Stream & Result<&1, &1, U32 & String, String>, (st, Fail{e}))
    case Done{(+tmp, f)}:
      download.response(tmp, f, Http.stream.res(st))

def download.idle(pool: Http.Pool, pair: Http.Stream & Result<&1, &1, U32 & String, String>) -> IO(Http.Pool & Result<&1, &1, U32 & String, String>):
  (next, result) = pair
  do IO<Http.Pool & Result<&1, &1, U32 & String, String>>:
    idle : Http.Pool <- Http.pool.stream.close(pool, next)
    return (idle, result)

def download.received(+dir: String, pair: Http.Pool & Result<&1, &1, Pure.Err, Http.Stream>) -> IO(Http.Pool & Result<&1, &1, U32 & String, String>):
  (pool, result) = pair
  match result:
    case Fail{e}:
      IO.pure(Http.Pool & Result<&1, &1, U32 & String, String>, (pool, Fail{(5, "storage: HTTP object request failed: " ++ error(e))}))
    case Done{st}:
      do IO<Http.Pool & Result<&1, &1, U32 & String, String>>:
        opened : Result<&1, &1, U32 & String, String & File> <- S.write.temp(dir ++ "/tmp/http")
        pair : Http.Stream & Result<&1, &1, U32 & String, String> <- download.opened(st, opened)
        download.idle(pool, pair)

def download.context(+d: P.Digest, pair: Http.Pool & Result<&1, &1, U32 & String, String>) -> Http.Pool & Result<&1, &1, U32 & String, String>:
  (pool, result) = pair
  match result:
    case Fail{(code, message)}:
      (pool, Fail{(code, "storage: object " ++ P.Digest.hex(d) ++ ": " ++ message)})
    case Done{path}:
      (pool, Done{path})

def download(base: String, dir: String, +d: P.Digest) -> Run(String):
  pool => do IO<Http.Pool & Result<&1, &1, U32 & String, String>>:
    pair : Http.Pool & Maybe<&2, Pure.Jar> & Result<&1, &1, Pure.Err, Http.Stream> <- Http.pool.open.raw.how(pool, Pure.ModeFollow{}, None{}, "", None{}, "GET", base ++ "/objects/" ++ P.Digest.hex(d), Pure.set(Pure.empty(), "accept-encoding", "identity"), Pure.from_string(""), 30000)
    received : Http.Pool & Result<&1, &1, U32 & String, String> <- download.received(dir, Http.pool.stream.only(pair))
    return download.context(d, received)

def publish(+tmp: String, path: String, d: P.Digest) -> S.Run(P.Obj<P.Digest, Unit>):
  do S.Run<P.Obj<P.Digest, Unit>>:
    node : P.Obj<P.Digest, Unit> <- S.verified(tmp, d)
    S.write.durable(tmp, path, 0)
    return node

def publish.cleaned(+tmp: String, result: Result<&1, &1, U32 & String, P.Obj<P.Digest, Unit>>) -> S.Run(P.Obj<P.Digest, Unit>):
  match result:
    case Done{node}:
      S.Run.pure(P.Obj<P.Digest, Unit>, node)
    case Fail{e}:
      do IO<Result<&1, &1, U32 & String, P.Obj<P.Digest, Unit>>>:
        removed : Result<&1, &1, U32 & String, Unit> <- Files.remove(tmp)
        return Fail{e}

def receive(+dir: String, +d: P.Digest, +tmp: String) -> S.Run(P.Obj<P.Digest, Unit>):
  do IO<Result<&1, &1, U32 & String, P.Obj<P.Digest, Unit>>>:
    result : Result<&1, &1, U32 & String, P.Obj<P.Digest, Unit>> <- publish(tmp, S.Disk.object(dir, d), d)
    publish.cleaned(tmp, result)

type Step is Type:
  Want{digest: P.Digest}
  Pending{digest: P.Digest, result: P.Index(P.Digest, Unit) & U32}
  Missing{digest: P.Digest, seen: Bool}
  Local{digest: P.Digest, there: Bool}
  Children{object: P.Obj<P.Digest, Unit>}

# The index holds only links and the visited set, never file payloads.
def walk(fuel: Nat, +base: String, +dir: String, step: Step, +index: P.Index(P.Digest, Unit), +sent: U32) -> Run(P.Index(P.Digest, Unit) & U32):
  match fuel step:
    case 0n _:
      Run.lift(P.Index(P.Digest, Unit) & U32, S.Run.fail(P.Index(P.Digest, Unit) & U32, (36, "storage: HTTP tree is too deep")))
    case 1n+p Want{+d}:
      walk(p, base, dir, Missing{d, P.Index.has(~P.Digest, ~Unit, ~P.Digest.cmp, index, d)}, index, sent)
    case 1n+p Missing{d, True{}}:
      Run.pure(P.Index(P.Digest, Unit) & U32, (index, sent))
    case 1n+p Missing{+d, False{}}:
      Run.bind(Bool, P.Index(P.Digest, Unit) & U32, Run.lift(Bool, S.Run.lift(Bool, Files.exists(S.Disk.object(dir, d)))), e => walk(p, base, dir, Local{d, e}, index, sent))
    case 1n+p Local{+d, True{}}:
      do Run<P.Index(P.Digest, Unit) & U32>:
        +node : P.Obj<P.Digest, Unit> <- Run.lift(P.Obj<P.Digest, Unit>, S.verified(S.Disk.object(dir, d), d))
        walk(p, base, dir, Children{node}, P.Index.put(~P.Digest, ~Unit, ~P.Digest.cmp, index, d, node), sent)
    case 1n+p Local{+d, False{}}:
      do Run<P.Index(P.Digest, Unit) & U32>:
        tmp : String <- download(base, dir, d)
        +node : P.Obj<P.Digest, Unit> <- Run.lift(P.Obj<P.Digest, Unit>, receive(dir, d, tmp))
        walk(p, base, dir, Children{node}, P.Index.put(~P.Digest, ~Unit, ~P.Digest.cmp, index, d, node), (sent + 1 : U32))
    case 1n+(+p) Children{P.OItem{name, c, r}}:
      do Run<P.Index(P.Digest, Unit) & U32>:
        first : P.Index(P.Digest, Unit) & U32 <- walk(p, base, dir, Want{c}, index, sent)
        walk(p, base, dir, Pending{r, first}, P.Index.new(P.Digest, Unit), 0)
    case 1n+p Pending{r, (next, n)}:
      walk(p, base, dir, Want{r}, next, n)
    case 1n+p Children{_}:
      Run.pure(P.Index(P.Digest, Unit) & U32, (index, sent))

def complete(root: P.Digest, result: P.Index(P.Digest, Unit) & U32) -> S.Run(U32):
  (index, sent) = result
  do S.Run<U32>:
    tree : P.Tree<Unit> <- S.Run.some(P.Tree<Unit>, P.Index.load(~P.Digest, ~Unit, ~P.Digest.cmp, P.limit(), index, root), "HTTP root does not load")
    return sent

# base is an HTTP(S) origin without a trailing slash; root is supplied by the caller.
def sync(+base: String, +dir: String, +root: P.Digest) -> S.Run(U32):
  S.Disk.coordinated(U32, dir, False{}, u => do S.Run<U32>:
    pair : Http.Pool & Result<&1, &1, U32 & String, P.Index(P.Digest, Unit) & U32> <- S.Run.lift(Http.Pool & Result<&1, &1, U32 & String, P.Index(P.Digest, Unit) & U32>, walk(Nat.mul(6n, P.limit()), base, dir, Want{root}, P.Index.new(P.Digest, Unit), 0)(Http.pool.new()))
    result : P.Index(P.Digest, Unit) & U32 <- Run.close(P.Index(P.Digest, Unit) & U32, pair)
    complete(root, result))
