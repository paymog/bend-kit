import Base
import ./storage.bend as S
import ./pure.bend as P
import bend-kit-http@0.40.0.1/http.bend as Http
import bend-kit-http@0.40.0.1/completion.bend as Completion
import bend-kit-files@0.4.0.1/files.bend as Files
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

# Git's dumb HTTP object walk: immutable objects are fetched by digest from a known root.
def response(status: U32, body: Http.Body) -> Http.Reply:
  Http.Reply{Http.Res{status, Http.set(Http.empty(), "content-type", "application/octet-stream"), body}, Completion.Unobserved{}}

def served(result: Result<&1, &1, U32 & String, Http.Body>) -> IO(Http.Reply):
  match result:
    case Done{body}:
      IO.pure(Http.Reply, response(200, body))
    case Fail{(code, message)}:
      IO.pure(Http.Reply, response(Bool.pick(U32, U32.is_eq(code, 2), 404, 500), Http.from_string("object unavailable\n")))

def object(+dir: String, digest: Maybe<&2, P.Digest>) -> IO(Http.Reply):
  match digest:
    case None{}:
      IO.pure(Http.Reply, response(404, Http.from_string("not found\n")))
    case Some{d}:
      do IO<Http.Reply>:
        result : Result<&1, &1, U32 & String, Http.Body> <- S.read(S.Disk.object(dir, d))
        served(result)

def route(valid: Bool, dir: String, path: String) -> IO(Http.Reply):
  match valid:
    case False{}:
      IO.pure(Http.Reply, response(404, Http.from_string("not found\n")))
    case True{}:
      object(dir, P.Digest.read(String.drop(path, 9n)))

# Mount on a read-only store; freeze collection while the server serves its roots.
def handle(dir: String, request: Http.Req) -> IO(Http.Reply):
  Http.Req{+method, +path, headers, body} = request
  route(String.eq(method, "GET") && String.starts_with(path, "/objects/"), dir, path)


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

def inspect(path: String, digest: String) -> IO(Result<&1, &1, U32 & String, U32 & String>):
  import "./effs/http.c"
  import "./effs/http.js"

def metadata.file(valid: Bool) -> Maybe<&2, P.Obj<P.Digest, Unit>>:
  match valid:
    case True{}:
      Some{P.OFile{Unit{}}}
    case False{}:
      None{}

def metadata.node(node: Maybe<&2, P.Obj<P.Digest, P.Blob>>) -> Maybe<&2, P.Obj<P.Digest, Unit>>:
  match node:
    case Some{P.OEnd{}}:
      Some{P.OEnd{}}
    case Some{P.OItem{n, c, r}}:
      Some{P.OItem{n, c, r}}
    case _:
      None{}

def metadata.of(file: Bool, +size: U32, +head: String, +d: P.Digest) -> Maybe<&2, P.Obj<P.Digest, Unit>>:
  match file:
    case True{}:
      +digits = String.drop(head, 5n)
      +length = U32.from_nat(String.length(head ++ "\n"))
      metadata.file(Bool.and(U32.is_le(length, size), String.eq(digits, U32.show((size - length : U32)))))
    case False{}:
      metadata.node(P.decode.hashed(d, Http.from_string(head ++ "\n")))

def verified.pair(+d: P.Digest, pair: U32 & String) -> S.Run(P.Obj<P.Digest, Unit>):
  (+size, +head) = pair
  S.Run.some(P.Obj<P.Digest, Unit>, metadata.of(String.starts_with(head, "file "), size, head, d), "object " ++ P.Digest.hex(d) ++ " does not decode")

def verified(+path: String, +d: P.Digest) -> S.Run(P.Obj<P.Digest, Unit>):
  do S.Run<P.Obj<P.Digest, Unit>>:
    pair : U32 & String <- inspect(path, P.Digest.hex(d))
    verified.pair(d, pair)

def error(e: Http.Err) -> String:
  match e:
    case Http.ErrUrl{}:
      "invalid URL"
    case Http.ErrDns{}:
      "DNS lookup failed"
    case Http.ErrConnect{code, why}:
      "connection failed (" ++ U32.show(code) ++ "): " ++ why
    case Http.ErrTls{code, why}:
      "TLS failed (" ++ U32.show(code) ++ "): " ++ why
    case Http.ErrRead{code, why}:
      "read failed (" ++ U32.show(code) ++ "): " ++ why
    case Http.ErrWrite{code, why}:
      "write failed (" ++ U32.show(code) ++ "): " ++ why
    case Http.ErrTimeout{}:
      "timeout"
    case Http.ErrRedirect{}:
      "redirect failed"
    case Http.ErrBad{}:
      "malformed or unsupported response, or response limit exceeded"

def copy.result(result: Result<&1, &1, Http.Err, Maybe<&1, Http.Body>>) -> Result<&1, &1, U32 & String, Maybe<&1, Http.Body>>:
  match result:
    case Fail{e}:
      Fail{(5, "storage: HTTP object stream failed: " ++ error(e))}
    case Done{piece}:
      Done{piece}

def copy.read(f: File, pair: Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Http.Body>>) -> Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Http.Body>>):
  (next, result) = pair
  (next, (f, copy.result(result)))

def copy.next(st: Http.Stream, pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Http.Body>>)):
  (f, result) = pair
  match result:
    case Fail{e}:
      IO.pure(Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Http.Body>>), (st, (f, Fail{e})))
    case Done{u}:
      do IO<Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Http.Body>>)>:
        pair : Http.Stream & Result<&1, &1, Http.Err, Maybe<&1, Http.Body>> <- Http.stream.read(st)
        return copy.read(f, pair)

def copy.write(over: Bool, f: File, body: Http.Body) -> IO(File & Result<&1, &1, U32 & String, Unit>):
  match over:
    case True{}:
      IO.pure(File & Result<&1, &1, U32 & String, Unit>, (f, Fail{(27, "storage: encoded object exceeds 4294967295 octets")}))
    case False{}:
      Files.write_bytes(f, body)

def copy(fuel: Nat, pair: Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Http.Body>>), +total: U32) -> IO(Http.Stream & (File & Result<&1, &1, U32 & String, Unit>)):
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
        next : Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Http.Body>>) <- copy.next(st, written)
        copy(p, next, (total + len : U32))

def status.result(good: Bool, message: String) -> Result<&1, &1, U32 & String, Unit>:
  match good:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{(22, "storage: " ++ message)}

def download.status(+status: U32, st: Http.Stream, f: File) -> IO(Http.Stream & (File & Result<&1, &1, U32 & String, Unit>)):
  do IO<Http.Stream & (File & Result<&1, &1, U32 & String, Unit>)>:
    first : Http.Stream & (File & Result<&1, &1, U32 & String, Maybe<&1, Http.Body>>) <- copy.next(st, (f, status.result(U32.is_eq(status, 200), "HTTP object status " ++ U32.show(status))))
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

def download.response(+tmp: String, f: File, pair: Http.Stream & Http.Res) -> IO(Http.Stream & Result<&1, &1, U32 & String, String>):
  (stream, Http.Res{status, headers, body}) = pair
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

def download.received(+dir: String, pair: Http.Pool & Result<&1, &1, Http.Err, Http.Stream>) -> IO(Http.Pool & Result<&1, &1, U32 & String, String>):
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
    pair : Http.Pool & Maybe<&2, Http.Jar> & Result<&1, &1, Http.Err, Http.Stream> <- Http.pool.open.raw.how(pool, Http.ModeFollow{}, None{}, "", None{}, "GET", base ++ "/objects/" ++ P.Digest.hex(d), Http.set(Http.empty(), "accept-encoding", "identity"), Http.from_string(""), 30000)
    received : Http.Pool & Result<&1, &1, U32 & String, String> <- download.received(dir, Http.pool.stream.only(pair))
    return download.context(d, received)

def publish(+tmp: String, path: String, d: P.Digest) -> S.Run(P.Obj<P.Digest, Unit>):
  do S.Run<P.Obj<P.Digest, Unit>>:
    node : P.Obj<P.Digest, Unit> <- verified(tmp, d)
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
        +node : P.Obj<P.Digest, Unit> <- Run.lift(P.Obj<P.Digest, Unit>, verified(S.Disk.object(dir, d), d))
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
  do S.Run<U32>:
    pair : Http.Pool & Result<&1, &1, U32 & String, P.Index(P.Digest, Unit) & U32> <- S.Run.lift(Http.Pool & Result<&1, &1, U32 & String, P.Index(P.Digest, Unit) & U32>, walk(Nat.mul(6n, P.limit()), base, dir, Want{root}, P.Index.new(P.Digest, Unit), 0)(Http.pool.new()))
    result : P.Index(P.Digest, Unit) & U32 <- Run.close(P.Index(P.Digest, Unit) & U32, pair)
    complete(root, result)
