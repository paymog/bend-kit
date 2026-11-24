import Base
import ./storage.bend as S
import bend-kit-http@0.40.0.1/http.bend as Http
import bend-kit-http@0.40.0.1/completion.bend as Completion
import bend-kit-files@0.4.0.1/files.bend as Files

# Git's dumb HTTP object walk: immutable objects are fetched by digest from a known root.
def response(status: U32, body: Http.Body) -> Http.Reply:
  Http.Reply{Http.Res{status, Http.set(Http.empty(), "content-type", "application/octet-stream"), body}, Completion.Unobserved{}}

def served(result: Result<&1, &1, U32 & String, Http.Body>) -> IO(Http.Reply):
  match result:
    case Done{body}:
      IO.pure(Http.Reply, response(200, body))
    case Fail{(code, message)}:
      IO.pure(Http.Reply, response(Bool.pick(U32, U32.is_eq(code, 2), 404, 500), Http.from_string("object unavailable\n")))

def object(+dir: String, digest: Maybe<&2, S.Digest>) -> IO(Http.Reply):
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
      object(dir, S.Digest.read(String.drop(path, 9n)))

# Mount on a read-only store; freeze collection while the server serves its roots.
def handle(dir: String, request: Http.Req) -> IO(Http.Reply):
  Http.Req{+method, +path, headers, body} = request
  route(String.eq(method, "GET") && String.starts_with(path, "/objects/"), dir, path)

def fetched(result: Result<&1, &1, Http.Err, Http.Res>) -> S.Run(Http.Body):
  match result:
    case Fail{error}:
      S.Run.fail(Http.Body, (5, "storage: HTTP object request failed"))
    case Done{Http.Res{+status, headers, body}}:
      do S.Run<Http.Body>:
        S.Run.check(U32.is_eq(status, 200), "HTTP object status " ++ U32.show(status))
        return body

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

def get.received(pair: Http.Pool & Result<&1, &1, Http.Err, Http.Res>) -> IO(Http.Pool & Result<&1, &1, U32 & String, Http.Body>):
  (pool, result) = pair
  Run.lift(Http.Body, fetched(result))(pool)

def get.pooled(base: String, d: S.Digest) -> Run(Http.Body):
  pool => do IO<Http.Pool & Result<&1, &1, U32 & String, Http.Body>>:
    pair : Http.Pool & Result<&1, &1, Http.Err, Http.Res> <- Http.pool.fetch(pool, "GET", base ++ "/objects/" ++ S.Digest.hex(d), Http.empty(), Http.from_string(""))
    get.received(pair)

def get(base: String, d: S.Digest) -> S.Run(Http.Body):
  do IO<Result<&1, &1, U32 & String, Http.Body>>:
    pair : Http.Pool & Result<&1, &1, U32 & String, Http.Body> <- get.pooled(base, d)(Http.pool.new())
    Run.close(Http.Body, pair)

type Step is Type:
  Want{digest: S.Digest}
  Pending{digest: S.Digest, result: S.Index(S.Digest, S.Blob) & U32}
  Missing{digest: S.Digest, seen: Bool}
  Local{digest: S.Digest, there: Bool}
  Children{object: Maybe<&2, S.Obj<S.Digest, S.Blob>>}

# The index is also the visited set; every local or remote object passes ingress once.
def walk(fuel: Nat, +base: String, +dir: String, step: Step, +index: S.Index(S.Digest, S.Blob), +sent: U32) -> Run(S.Index(S.Digest, S.Blob) & U32):
  match fuel step:
    case 0n _:
      Run.lift(S.Index(S.Digest, S.Blob) & U32, S.Run.fail(S.Index(S.Digest, S.Blob) & U32, (36, "storage: HTTP tree is too deep")))
    case 1n+p Want{+d}:
      walk(p, base, dir, Missing{d, S.Index.has(~S.Digest, ~S.Blob, ~S.Digest.cmp, index, d)}, index, sent)
    case 1n+p Missing{d, True{}}:
      Run.pure(S.Index(S.Digest, S.Blob) & U32, (index, sent))
    case 1n+p Missing{+d, False{}}:
      Run.bind(Bool, S.Index(S.Digest, S.Blob) & U32, Run.lift(Bool, S.Run.lift(Bool, Files.exists(S.Disk.object(dir, d)))), e => walk(p, base, dir, Local{d, e}, index, sent))
    case 1n+p Local{+d, True{}}:
      do Run<S.Index(S.Digest, S.Blob) & U32>:
        body : Http.Body <- Run.lift(Http.Body, S.read(S.Disk.object(dir, d)))
        +next : S.Index(S.Digest, S.Blob) <- Run.lift(S.Index(S.Digest, S.Blob), S.receive(index, d, body))
        walk(p, base, dir, Children{S.Index.get(~S.Digest, ~S.Blob, ~S.Digest.cmp, next, d)}, next, sent)
    case 1n+p Local{+d, False{}}:
      do Run<S.Index(S.Digest, S.Blob) & U32>:
        body : Http.Body <- get.pooled(base, d)
        +next : S.Index(S.Digest, S.Blob) <- Run.lift(S.Index(S.Digest, S.Blob), S.Disk.receive(dir, index, d, body))
        walk(p, base, dir, Children{S.Index.get(~S.Digest, ~S.Blob, ~S.Digest.cmp, next, d)}, next, (sent + 1 : U32))
    case 1n+(+p) Children{Some{S.OItem{name, c, r}}}:
      do Run<S.Index(S.Digest, S.Blob) & U32>:
        first : S.Index(S.Digest, S.Blob) & U32 <- walk(p, base, dir, Want{c}, index, sent)
        walk(p, base, dir, Pending{r, first}, S.Index.new(S.Digest, S.Blob), 0)
    case 1n+p Pending{r, (next, n)}:
      walk(p, base, dir, Want{r}, next, n)
    case 1n+p Children{_}:
      Run.pure(S.Index(S.Digest, S.Blob) & U32, (index, sent))

def complete(root: S.Digest, result: S.Index(S.Digest, S.Blob) & U32) -> S.Run(U32):
  (+index, sent) = result
  do S.Run<U32>:
    tree : S.Tree<S.Blob> <- S.Run.some(S.Tree<S.Blob>, S.Index.load(~S.Digest, ~S.Blob, ~S.Digest.cmp, S.limit(), index, root), "HTTP root does not load")
    return sent

# base is an HTTP(S) origin without a trailing slash; root is supplied by the caller.
def sync(+base: String, +dir: String, +root: S.Digest) -> S.Run(U32):
  do S.Run<U32>:
    pair : Http.Pool & Result<&1, &1, U32 & String, S.Index(S.Digest, S.Blob) & U32> <- S.Run.lift(Http.Pool & Result<&1, &1, U32 & String, S.Index(S.Digest, S.Blob) & U32>, walk(Nat.mul(6n, S.limit()), base, dir, Want{root}, S.Index.new(S.Digest, S.Blob), 0)(Http.pool.new()))
    result : S.Index(S.Digest, S.Blob) & U32 <- Run.close(S.Index(S.Digest, S.Blob) & U32, pair)
    complete(root, result)
