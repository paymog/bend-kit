import Base
import ./storage.bend as S
import bend-kit-http@0.39.2.0/http.bend as Http
import bend-kit-http@0.39.2.0/completion.bend as Completion
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

def get(+base: String, d: S.Digest) -> S.Run(Http.Body):
  do S.Run<Http.Body>:
    result : Result<&1, &1, Http.Err, Http.Res> <- S.Run.lift(Result<&1, &1, Http.Err, Http.Res>, Http.get(base ++ "/objects/" ++ S.Digest.hex(d)))
    fetched(result)

type Step is Type:
  Want{digest: S.Digest}
  Pending{digest: S.Digest, result: S.Index(S.Digest, S.Blob) & U32}
  Missing{digest: S.Digest, seen: Bool}
  Local{digest: S.Digest, there: Bool}
  Children{object: Maybe<&2, S.Obj<S.Digest, S.Blob>>}

# The index is also the visited set; every local or remote object passes ingress once.
def walk(fuel: Nat, +base: String, +dir: String, step: Step, +index: S.Index(S.Digest, S.Blob), +sent: U32) -> S.Run(S.Index(S.Digest, S.Blob) & U32):
  match fuel step:
    case 0n _:
      S.Run.fail(S.Index(S.Digest, S.Blob) & U32, (36, "storage: HTTP tree is too deep"))
    case 1n+p Want{+d}:
      walk(p, base, dir, Missing{d, S.Index.has(~S.Digest, ~S.Blob, ~S.Digest.cmp, index, d)}, index, sent)
    case 1n+p Missing{d, True{}}:
      S.Run.pure(S.Index(S.Digest, S.Blob) & U32, (index, sent))
    case 1n+p Missing{+d, False{}}:
      S.Run.bind(Bool, S.Index(S.Digest, S.Blob) & U32, S.Run.lift(Bool, Files.exists(S.Disk.object(dir, d))), e => walk(p, base, dir, Local{d, e}, index, sent))
    case 1n+p Local{+d, True{}}:
      do S.Run<S.Index(S.Digest, S.Blob) & U32>:
        body : Http.Body <- S.read(S.Disk.object(dir, d))
        +next : S.Index(S.Digest, S.Blob) <- S.receive(index, d, body)
        walk(p, base, dir, Children{S.Index.get(~S.Digest, ~S.Blob, ~S.Digest.cmp, next, d)}, next, sent)
    case 1n+p Local{+d, False{}}:
      do S.Run<S.Index(S.Digest, S.Blob) & U32>:
        body : Http.Body <- get(base, d)
        +next : S.Index(S.Digest, S.Blob) <- S.Disk.receive(dir, index, d, body)
        walk(p, base, dir, Children{S.Index.get(~S.Digest, ~S.Blob, ~S.Digest.cmp, next, d)}, next, (sent + 1 : U32))
    case 1n+(+p) Children{Some{S.OItem{name, c, r}}}:
      do S.Run<S.Index(S.Digest, S.Blob) & U32>:
        first : S.Index(S.Digest, S.Blob) & U32 <- walk(p, base, dir, Want{c}, index, sent)
        walk(p, base, dir, Pending{r, first}, S.Index.new(S.Digest, S.Blob), 0)
    case 1n+p Pending{r, (next, n)}:
      walk(p, base, dir, Want{r}, next, n)
    case 1n+p Children{_}:
      S.Run.pure(S.Index(S.Digest, S.Blob) & U32, (index, sent))

def complete(root: S.Digest, result: S.Index(S.Digest, S.Blob) & U32) -> S.Run(U32):
  (+index, sent) = result
  do S.Run<U32>:
    tree : S.Tree<S.Blob> <- S.Run.some(S.Tree<S.Blob>, S.Index.load(~S.Digest, ~S.Blob, ~S.Digest.cmp, S.limit(), index, root), "HTTP root does not load")
    return sent

# base is an HTTP(S) origin without a trailing slash; root is supplied by the caller.
def sync(+base: String, +dir: String, +root: S.Digest) -> S.Run(U32):
  do S.Run<U32>:
    result : S.Index(S.Digest, S.Blob) & U32 <- walk(Nat.mul(6n, S.limit()), base, dir, Want{root}, S.Index.new(S.Digest, S.Blob), 0)
    complete(root, result)
