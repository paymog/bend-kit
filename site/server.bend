# Serves the site through Camber's native HTTP transport.
import Base
import ./app.bend as Web
import ./build.bend as Build
import ../camber/camber.bend as C
import bend-kit-http@0.45.1.0/pure.bend as Pure
import bend-kit-http@0.45.1.0/completion.bend as Completion
import ../files/files.bend as Fs
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

type Action is Data:
  Page{page: Web.Page}
  Asset{path: String, media: String}

def asset.media(+name: String) -> String:
  Bool.pick(String, String.ends_with(name, ".js"), "text/javascript; charset=utf-8",
    Bool.pick(String, String.ends_with(name, ".css"), "text/css; charset=utf-8", "text/html; charset=utf-8"))

def assets(names: List<&2, String>) -> List<&2, C.Route<Action, C.Policy<Unit>>>:
  match names:
    case Nil{}:
      [C.Route{"GET", "/style.css", Asset{"site/dist/style.css", "text/css; charset=utf-8"}, [], Web.none()},
       C.Route{"GET", "/playground/", Asset{"site/dist/playground/index.html", "text/html; charset=utf-8"}, [], Web.none()},
       C.Route{"GET", "/playground", Asset{"site/dist/playground/index.html", "text/html; charset=utf-8"}, [], Web.none()}]
    case Con{+name, rest}:
      Con{C.Route{"GET", "/playground/" ++ name, Asset{"site/dist/playground/" ++ name, asset.media(name)}, [], Web.none()}, assets(rest)}

def routes(xs: List<&2, C.Route<Web.Page, C.Policy<Unit>>>, extra: List<&2, C.Route<Action, C.Policy<Unit>>>) -> List<&2, C.Route<Action, C.Policy<Unit>>>:
  match xs:
    case Nil{}: extra
    case Con{C.Route{method, pattern, page, groups, policy}, rest}:
      Con{C.Route{method, pattern, Page{page}, groups, policy}, routes(rest, extra)}

def asset.chunks(fuel: Nat, pair: File & Result<&1, &1, U32 & String, Bytes.Bytes>, chunks: List<&1, Bytes.Bytes>) -> IO(Bytes.Bytes):
  match fuel:
    case 0n:
      match pair:
        case (file, result):
          do IO<Bytes.Bytes>:
            File.close(file)
            IO.die(Bytes.Bytes, 1, "asset exceeds 32 MiB")
    case 1n+left:
      match pair:
        case (file, Fail{error}):
          do IO<Bytes.Bytes>:
            File.close(file)
            IO.die(Bytes.Bytes, 1, "asset read failed")
        case (file, Done{Bytes.Bytes{+len, words}}):
          match len:
            case 0:
              do IO<Bytes.Bytes>:
                File.close(file)
                return Bytes.concat(List.reverse(&1, Bytes.Bytes, chunks))
            case _:
              do IO<Bytes.Bytes>:
                next : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 1048576)
                asset.chunks(left, next, Con{Bytes.Bytes{len, words}, chunks})

def asset.read(path: String) -> IO(Bytes.Bytes):
  do IO<Bytes.Bytes>:
    file : File <- IO.try(File, File.open(path, "r"))
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, 1048576)
    asset.chunks(33n, pair, Nil{})

def run(action: Action, state: Unit, site: Web.Site, selected: C.Match<C.Policy<Unit>>, req: Pure.Req) -> IO(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>):
  match action:
    case Page{page}: Web.run(page, state, site, selected, req)
    case Asset{path, media}:
      do IO<Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>>:
        body : Bytes.Bytes <- asset.read(path)
        return (state, Done{Pure.Res{200, Pure.set(Pure.empty(), "content-type", media), body}})

def after(hook: Unit, state: Unit, site: Web.Site, response: Pure.Res) -> IO(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>):
  Pure.Res{status, headers, body} = response
  IO.pure(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>,
    (state, Done{Pure.Res{status, Pure.set(headers, "cache-control", "public, max-age=300"), body}}))

def destroy(state: Unit) -> IO(Unit):
  IO.pure(Unit, Unit{})

def done(completion: Completion.Completion<C.ApplicationReport<Unit>>) -> IO(Unit):
  IO.pure(Unit, Unit{})

def observe(status: U32, outcome: Completion.Outcome) -> IO(Unit):
  IO.pure(Unit, Unit{})

def started(result: Result<&2, &1, C.StartupError, C.Server<Action, Unit, Web.Site, Unit>>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit, 1, "site transport startup failed")
    case Done{server}:
      do IO<Unit>:
        IO.print("site: ready")
        exited : C.ServerExit<Action, Unit, Web.Site, Unit> <- C.server.run(~Action, ~Unit, ~Web.Site, ~Unit, ~Unit,
          ~done, ~observe, ~C.notice.ignore(~Web.Site, ~Unit, ~Unit), ~C.notice.error.ignore(~Web.Site, ~Unit), ~C.access.disabled(~Web.Site), server)
        return Unit{}

def loaded(pair: C.Application<Web.Page, Web.Site, C.Policy<Unit>> & List<&2, String>, port: U32) -> IO(Unit):
  (C.Application{table, context, root, groups}, paths) = pair
  do IO<Unit>:
    names : List<&2, String> <- IO.try(List<&2, String>, Fs.list_dir("site/dist/playground"))
    result : Result<&2, &1, C.StartupError, C.Server<Action, Unit, Web.Site, Unit>> <- C.server.start(~Action, ~Unit, ~Web.Site, ~Unit, ~Unit,
      ~Web.before, ~after, ~run, ~C.default.mapper(~Unit, ~Web.Site, ~Unit), ~destroy,
      C.application(~Action, ~Web.Site, ~C.Policy<Unit>, routes(Web.routes(), assets(names)), [], context, C.policy(~Unit, 0, [], [Unit{}])),
      Pure.ServerConfig{"0.0.0.0", port, 1048576, 65536, 128, 128, 128, 5000, 30000, 30000, 30000}, [Unit{}, Unit{}, Unit{}, Unit{}])
    started(result)

def start(port: Maybe<&2, U32>, root: String, base: String, names: List<&1, String>) -> IO(Unit):
  match port:
    case None{}: IO.die(Unit, 2, "expected a decimal port")
    case Some{number}:
      do IO<Unit>:
        pair : C.Application<Web.Page, Web.Site, C.Policy<Unit>> & List<&2, String> <- Build.application(root, base, Build.names.copy(names))
        loaded(pair, number)

def args(values: List<&1, String>) -> IO(Unit):
  match values:
    case program <> port <> root <> base <> names:
      start(U32.read(port), root, base, names)
    case _: IO.die(Unit, 2, "usage: server PORT ROOT BASE_URL PACKAGE...")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<&1, String> <- IO.args()
    args(values)
