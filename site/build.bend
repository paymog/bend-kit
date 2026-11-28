# Prerenders every route of the site app to static files.
import Base
import ./app.bend as App
import ../camber/camber.bend as C
import bend-kit-http@0.45.1.0/pure.bend as Pure
import ../template/template.bend as T
import ../files/files.bend as Fs
import ../encoding/encoding.bend as Enc
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes

def read.done(pair: File & Result<&1, &1, U32 & String, Bytes.Bytes>) -> IO(String):
  (file, result) = pair
  do IO<String>:
    File.close(file)
    bytes : Bytes.Bytes <- IO.try(Bytes.Bytes, IO.pure(Result<&1, &1, U32 & String, Bytes.Bytes>, result))
    return Enc.utf8.decode(bytes)

# Files here are far below the 1 MiB that one read returns.
def read.opened(file: File, max: U32) -> IO(String):
  do IO<String>:
    pair : File & Result<&1, &1, U32 & String, Bytes.Bytes> <- Fs.read_bytes(file, max)
    read.done(pair)

def read.text(path: String, max: U32) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File, File.open(path, "r"))
    read.opened(file, max)

def read.maybe.opened(result: Result<&1, &1, U32 & String, File>) -> IO(Maybe<&2, String>):
  match result:
    case Fail{error}:
      IO.pure(Maybe<&2, String>, None{})
    case Done{file}:
      do IO<Maybe<&2, String>>:
        text : String <- read.opened(file, 1048576)
        return Some{text}

def read.maybe(path: String) -> IO(Maybe<&2, String>):
  do IO<Maybe<&2, String>>:
    result : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    read.maybe.opened(result)

def laws.maybe(src: Maybe<&2, String>) -> Maybe<&2, List<&2, App.Law>>:
  match src:
    case None{}:
      None{}
    case Some{text}:
      Some{App.laws(text)}

def at(+root: String, +name: String, file: String) -> String:
  Fs.path.join(Fs.path.join(root, name), file)

def names.copy(xs: List<&1, String>) -> List<&2, String>:
  match xs:
    case Nil{}: Nil{}
    case Con{x, rest}: Con{x, names.copy(rest)}

def names.affine(xs: List<&2, String>) -> List<&1, String>:
  match xs:
    case Nil{}: Nil{}
    case Con{x, rest}: Con{x, names.affine(rest)}

def fragment.status(status: U32, output: String) -> IO(String):
  match status:
    case 0: IO.pure(String, output)
    case _: IO.die(String, 1, "Markdown navigation failed")

def fragment.exited(result: U32 & (String & String)) -> IO(String):
  (status, (output, error)) = result
  fragment.status(status, output)

def fragment(+root: String, name: String, base: String, section: String, names: List<&2, String>, source: String) -> IO(String):
  do IO<String>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("python3", List.append(&1, String, [Fs.path.join(root, "site/render.py"), "--fragment", name, base, section], names.affine(names)), App.gfm(source), 4194304, 30000))
    fragment.exited(result)

def load(+root: String, +name: String, +base: String, +names: List<&2, String>) -> IO(App.Pkg):
  do IO<App.Pkg>:
    +readme : String <- read.text(at(root, name, "README.md"), 1048576)
    version : String <- read.text(at(root, name, "VERSION"), 64)
    entry : String <- read.text(at(root, name, name ++ ".bend"), 4096)
    laws : Maybe<&2, String> <- read.maybe(at(root, name, "LAWS.bend"))
    bench : String <- read.text(at(root, name, "bench/README.md"), 1048576)
    readme_html : String <- fragment(root, name, base, "readme", names, readme)
    bench_html : String <- fragment(root, name, base, "bench", names, bench)
    return App.Pkg{name, String.trim(version), App.about(entry), readme, laws.maybe(laws), bench_html, readme_html}

def load.all(names: List<&2, String>, +root: String, +base: String, +all: List<&2, String>) -> IO(List<&2, App.Pkg>):
  match names:
    case Nil{}:
      IO.pure(List<&2, App.Pkg>, Nil{})
    case Con{name, rest}:
      do IO<List<&2, App.Pkg>>:
        pkg : App.Pkg <- load(root, name, base, all)
        pkgs : List<&2, App.Pkg> <- load.all(rest, root, base, all)
        return Con{pkg, pkgs}

def parsed(+name: String, result: Result<&2, &2, String, List<&2, T.Node>>) -> IO(List<&2, T.Node>):
  match result:
    case Fail{reason}:
      IO.die(List<&2, T.Node>, 1, "template " ++ name ++ ": " ++ reason)
    case Done{nodes}:
      IO.pure(List<&2, T.Node>, nodes)

def templates.go(names: List<&2, String>, +dir: String, m: Map<&2, List<&2, T.Node>>) -> IO(Map<&2, List<&2, T.Node>>):
  match names:
    case Nil{}:
      IO.pure(Map<&2, List<&2, T.Node>>, m)
    case Con{+name, rest}:
      do IO<Map<&2, List<&2, T.Node>>>:
        src : String <- read.text(Fs.path.join(dir, name ++ ".mustache"), 1048576)
        nodes : List<&2, T.Node> <- parsed(name, T.parse(src))
        templates.go(rest, dir, Map.set(&2, List<&2, T.Node>, m, name, nodes))

def ready(result: Result<&2, &2, C.RegistrationError, C.Application<App.Page, App.Site, C.Policy<Unit>>>) -> IO(C.Application<App.Page, App.Site, C.Policy<Unit>>):
  match result:
    case Fail{error}:
      IO.die(C.Application<App.Page, App.Site, C.Policy<Unit>>, 1, "route registration failed")
    case Done{app}:
      IO.pure(C.Application<App.Page, App.Site, C.Policy<Unit>>, app)

def written(pair: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (file, result) = pair
  do IO<Unit>:
    File.close(file)
    IO.try(Unit, IO.pure(Result<&1, &1, U32 & String, Unit>, result))

def write.checked(ok: Bool, +out: String, +path: String, body: Pure.Body) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "route did not render: " ++ path)
    case True{}:
      +file = out ++ App.file(path)
      do IO<Unit>:
        IO.try(Unit, Fs.mkdir_all(Fs.path.parent(file)))
        handle : File <- IO.try(File, File.open(file, "w"))
        pair : File & Result<&1, &1, U32 & String, Unit> <- Fs.write_bytes(handle, body)
        written(pair)

def write(+out: String, +path: String, completion: C.Completion<Unit, Unit>) -> IO(Unit):
  C.Completed{state, Pure.Res{+status, headers, body}, entered, mapped, stopped} = completion
  write.checked(U32.is_eq(status, 200), out, path, body)

def render(paths: List<&2, String>, +app: C.Application<App.Page, App.Site, C.Policy<Unit>>, +out: String) -> IO(Unit):
  match paths:
    case Nil{}:
      IO.pure(Unit, Unit{})
    case Con{+path, rest}:
      do IO<Unit>:
        completion : C.Completion<Unit, Unit> <- App.dispatch(app, path)
        write(out, path, completion)
        render(rest, app, out)

def application(+root: String, +base: String, +names: List<&2, String>) -> IO(C.Application<App.Page, App.Site, C.Policy<Unit>> & List<&2, String>):
  do IO<C.Application<App.Page, App.Site, C.Policy<Unit>> & List<&2, String>>:
    +pkgs : List<&2, App.Pkg> <- load.all(names, root, base, names)
    templates : Map<&2, List<&2, T.Node>> <- templates.go(["layout", "index", "package", "llms", "document"], Fs.path.join(root, "site/templates"), Map.new(&2, List<&2, T.Node>))
    guide_source : String <- read.text(Fs.path.join(root, "site/getting-started.md"), 1048576)
    changelog_source : String <- read.text(Fs.path.join(root, "CHANGELOG.md"), 1048576)
    roadmap_source : String <- read.text(Fs.path.join(root, "ROADMAP.md"), 1048576)
    guide : String <- fragment(root, "", base, "readme", names, guide_source)
    changelog : String <- fragment(root, "", base, "readme", names, changelog_source)
    roadmap : String <- fragment(root, "", base, "readme", names, roadmap_source)
    documents : Map<&2, String> = Map.set(&2, String, Map.set(&2, String, Map.set(&2, String, Map.new(&2, String), "getting-started", guide), "changelog", changelog), "roadmap", roadmap)
    app : C.Application<App.Page, App.Site, C.Policy<Unit>> <- ready(App.application(App.site(base, pkgs, templates, documents)))
    return (app, App.paths(pkgs))

def build.loaded(pair: C.Application<App.Page, App.Site, C.Policy<Unit>> & List<&2, String>, +out: String) -> IO(Unit):
  (app, paths) = pair
  do IO<Unit>:
    render(paths, app, out)
    IO.print("site: wrote " ++ out)

def build(root: String, out: String, base: String, names: List<&1, String>) -> IO(Unit):
  do IO<Unit>:
    pair : C.Application<App.Page, App.Site, C.Policy<Unit>> & List<&2, String> <- application(root, base, names.copy(names))
    build.loaded(pair, out)

def run(args: List<&1, String>) -> IO(Unit):
  match args:
    case Con{program, Con{root, Con{out, Con{base, names}}}}:
      build(root, out, base, names)
    case _:
      IO.die(Unit, 2, "usage: build ROOT OUT BASE_URL PACKAGE...")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    run(args)
