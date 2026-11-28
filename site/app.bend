# The bend-kit website as a Camber application: one route per page, rendered from package files.
import Base
import ../camber/camber.bend as C
import bend-kit-http@0.45.1.0/pure.bend as Pure
import ../template/template.bend as T
import ../markdown/markdown.bend as M
import ../encoding/encoding.bend as Enc

type Law is Data:
  Law{name: String, doc: String, statement: String}

type Pkg is Data:
  Pkg{name: String, version: String, about: String, readme: String, laws: Maybe<&2, List<&2, Law>>, bench: String}

# base is the absolute site URL with no trailing slash; templates holds the parsed pages by name.
type Site is Data:
  Site{base: String, list: List<&2, Pkg>, index: Map<&2, Pkg>, templates: Map<&2, List<&2, T.Node>>}

type Page is Data:
  Home{}
  Package{}
  Source{}
  Llms{}

type LState is Data:
  LState{doc: List<&2, String>, open: Bool, name: String, ldoc: String, body: List<&2, String>, out: List<&2, Law>}

def law.name.strip(+s: String) -> String:
  String.take(s, (String.length(s) - 1n : Nat))

def law.name(l: String) -> String:
  law.name.strip(String.trim(String.drop(l, 4n)))

def law.close(name: String, ldoc: String, body: List<&2, String>) -> Law:
  Law{name, ldoc, String.join(List.reverse(&2, String, body), "\n")}

def laws.classify(claim: Bool, comment: Bool, l: String, doc: List<&2, String>, out: List<&2, Law>) -> LState:
  match claim:
    case True{}:
      LState{Nil{}, True{}, law.name(l), String.join(List.reverse(&2, String, doc), " "), Nil{}, out}
    case False{}:
      match comment:
        case True{}:
          LState{Con{String.trim(String.drop(l, 1n)), doc}, False{}, "", "", Nil{}, out}
        case False{}:
          LState{Nil{}, False{}, "", "", Nil{}, out}

def laws.line(+l: String, doc: List<&2, String>, out: List<&2, Law>) -> LState:
  laws.classify(String.starts_with(l, "law "), String.starts_with(l, "#"), l, doc, out)

def laws.open(open: Bool, indented: Bool, +l: String, doc: List<&2, String>, name: String, ldoc: String, body: List<&2, String>, out: List<&2, Law>) -> LState:
  match open:
    case True{}:
      match indented:
        case True{}:
          LState{doc, True{}, name, ldoc, Con{l, body}, out}
        case False{}:
          laws.line(l, doc, Con{law.close(name, ldoc, body), out})
    case False{}:
      laws.line(l, doc, out)

def laws.step(+l: String, st: LState) -> LState:
  LState{doc, open, name, ldoc, body, out} = st
  laws.open(open, String.starts_with(l, "  "), l, doc, name, ldoc, body, out)

def laws.go(lines: List<&2, String>, st: LState) -> LState:
  match lines:
    case Nil{}:
      st
    case Con{l, rest}:
      laws.go(rest, laws.step(l, st))

def laws.flush(open: Bool, name: String, ldoc: String, body: List<&2, String>, out: List<&2, Law>) -> List<&2, Law>:
  match open:
    case True{}:
      List.reverse(&2, Law, Con{law.close(name, ldoc, body), out})
    case False{}:
      List.reverse(&2, Law, out)

def laws.fin(st: LState) -> List<&2, Law>:
  LState{doc, open, name, ldoc, body, out} = st
  laws.flush(open, name, ldoc, body, out)

# Each top-level `law name:` with the comment lines just above it and its indented statement.
def laws(src: String) -> List<&2, Law>:
  laws.fin(laws.go(String.lines(src), LState{Nil{}, False{}, "", "", Nil{}, Nil{}}))

# The text before " Source: ", which the hub description repeats from the package link.
def about.cut(s: String, stop: Bool) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{c, +t}:
      match stop:
        case True{}:
          SNil{}
        case False{}:
          SCon{c, about.cut(t, String.starts_with(t, " Source: "))}

def about.line(l: String) -> String:
  +s = String.trim(String.drop(l, 1n))
  about.cut(s, String.starts_with(s, " Source: "))

def about.first(lines: List<&2, String>) -> String:
  match lines:
    case Nil{}:
      ""
    case Con{l, rest}:
      about.line(l)

# The hub shows the first comment line of the entry file as the package description.
def about(entry: String) -> String:
  about.first(String.lines(entry))

def put(m: Map<&2, T.Value>, k: String, v: String) -> Map<&2, T.Value>:
  Map.set(&2, T.Value, m, k, T.VStr{v})

def template.got(pair: Map<&2, List<&2, T.Node>> & List<&2, T.Node>) -> List<&2, T.Node>:
  (rest, nodes) = pair
  nodes

def template(templates: Map<&2, List<&2, T.Node>>, name: String) -> List<&2, T.Node>:
  template.got(Map.get(List<&2, T.Node>, Nil{}, templates, name))

def html(+templates: Map<&2, List<&2, T.Node>>, +base: String, title: String, inner: String, ctx: Map<&2, T.Value>) -> Pure.Res:
  content = T.render(template(templates, inner), put(ctx, "base", base))
  page = put(put(put(Map.new(&2, T.Value), "base", base), "title", title), "content", content)
  C.html(200, T.render_bytes(template(templates, "layout"), page))

def text(media: String, body: String) -> Pure.Res:
  Pure.Res{200, Pure.set(Pure.empty(), "content-type", media), Enc.utf8.encode(body)}

def pkg.value(p: Pkg) -> T.Value:
  Pkg{name, version, about, readme, laws, bench} = p
  T.VMap{put(put(put(Map.new(&2, T.Value), "name", name), "version", version), "about", about)}

def law.value(l: Law) -> T.Value:
  Law{name, doc, statement} = l
  T.VMap{put(put(put(Map.new(&2, T.Value), "name", name), "doc", doc), "statement", statement)}

def pkgs.values(xs: List<&2, Pkg>) -> List<&2, T.Value>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{pkg.value(h), pkgs.values(t)}

def laws.values(xs: List<&2, Law>) -> List<&2, T.Value>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      Con{law.value(h), laws.values(t)}

def laws.put(ctx: Map<&2, T.Value>, laws: Maybe<&2, List<&2, Law>>) -> Map<&2, T.Value>:
  match laws:
    case None{}:
      Map.set(&2, T.Value, ctx, "has_laws", T.VBool{False{}})
    case Some{+xs}:
      ctx2 = Map.set(&2, T.Value, ctx, "has_laws", T.VBool{True{}})
      ctx3 = put(ctx2, "law_count", Nat.show(List.length(&2, Law, xs)))
      Map.set(&2, T.Value, ctx3, "laws", T.VList{laws.values(xs)})

def gfm(s: String) -> String:
  M.to_html_with(M.Opts{False{}, True{}}, s)

def home(site: Site) -> Pure.Res:
  Site{+base, +list, index, +templates} = site
  ctx = put(Map.new(&2, T.Value), "count", Nat.show(List.length(&2, Pkg, list)))
  html(templates, base, "bend-kit", "index", Map.set(&2, T.Value, ctx, "packages", T.VList{pkgs.values(list)}))

def package.page(+templates: Map<&2, List<&2, T.Node>>, +base: String, p: Pkg) -> Pure.Res:
  Pkg{+name, +version, about, readme, laws, bench} = p
  ctx = put(put(put(Map.new(&2, T.Value), "name", name), "version", version), "about", about)
  ctx2 = put(put(ctx, "readme", gfm(readme)), "bench", gfm(bench))
  html(templates, base, name ++ " · bend-kit", "package", laws.put(ctx2, laws))

def source.page(p: Pkg) -> Pure.Res:
  Pkg{name, version, about, readme, laws, bench} = p
  text("text/markdown; charset=utf-8", readme)

def missing() -> Result<&2, &1, C.Error<Unit>, Pure.Res>:
  Fail{C.Framework{404, ""}}

def package.found(found: Maybe<&2, Pkg>, raw: Bool, +templates: Map<&2, List<&2, T.Node>>, +base: String) -> Result<&2, &1, C.Error<Unit>, Pure.Res>:
  match found:
    case None{}:
      missing()
    case Some{p}:
      match raw:
        case True{}:
          Done{source.page(p)}
        case False{}:
          Done{package.page(templates, base, p)}

def package.popped(pair: Map<&2, Pkg> & Maybe<&2, Pkg>, raw: Bool, templates: Map<&2, List<&2, T.Node>>, base: String) -> Result<&2, &1, C.Error<Unit>, Pure.Res>:
  (rest, found) = pair
  package.found(found, raw, templates, base)

def package.named(pair: Map<&2, String> & String, raw: Bool, site: Site) -> Result<&2, &1, C.Error<Unit>, Pure.Res>:
  (left, name) = pair
  Site{base, list, index, templates} = site
  package.popped(Map.pop(&2, Pkg, index, name), raw, templates, base)

def package(raw: Bool, site: Site, params: Map<&2, String>) -> Result<&2, &1, C.Error<Unit>, Pure.Res>:
  package.named(Map.get(String, "", params, "name"), raw, site)

def llms(site: Site) -> Pure.Res:
  Site{+base, list, index, +templates} = site
  ctx = put(Map.new(&2, T.Value), "base", base)
  text("text/plain; charset=utf-8", T.render(template(templates, "llms"), Map.set(&2, T.Value, ctx, "packages", T.VList{pkgs.values(list)})))

def respond(page: Page, site: Site, params: Map<&2, String>) -> Result<&2, &1, C.Error<Unit>, Pure.Res>:
  match page:
    case Home{}:
      Done{home(site)}
    case Llms{}:
      Done{llms(site)}
    case Package{}:
      package(False{}, site, params)
    case Source{}:
      package(True{}, site, params)

def run(page: Page, state: Unit, site: Site, selected: C.Match<C.Policy<Unit>>, req: Pure.Req) -> IO(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>):
  C.Match{target, params, groups, method, pattern, policies} = selected
  IO.pure(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>, (state, respond(page, site, params)))

def before(hook: Unit, state: Unit, site: Site, meta: C.Metadata) -> IO(C.Step<Unit, Unit>):
  IO.pure(C.Step<Unit, Unit>, C.Continue{state})

def after(hook: Unit, state: Unit, site: Site, response: Pure.Res) -> IO(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>):
  IO.pure(Unit & Result<&2, &1, C.Error<Unit>, Pure.Res>, (state, Done{response}))

def none() -> C.Policy<Unit>:
  C.policy(~Unit, 0, Nil{}, Nil{})

def routes() -> List<&2, C.Route<Page, C.Policy<Unit>>>:
  [C.Route{"GET", "/", Home{}, [], none()},
   C.Route{"GET", "/llms.txt", Llms{}, [], none()},
   C.Route{"GET", "/packages/:name", Package{}, [], none()},
   C.Route{"GET", "/packages/:name/README.md", Source{}, [], none()}]

def index.go(pkgs: List<&2, Pkg>, m: Map<&2, Pkg>) -> Map<&2, Pkg>:
  match pkgs:
    case Nil{}:
      m
    case Con{Pkg{+name, version, about, readme, laws, bench}, rest}:
      index.go(rest, Map.set(&2, Pkg, m, name, Pkg{name, version, about, readme, laws, bench}))

def site(base: String, +pkgs: List<&2, Pkg>, templates: Map<&2, List<&2, T.Node>>) -> Site:
  Site{base, pkgs, index.go(pkgs, Map.new(&2, Pkg)), templates}

def application(site: Site) -> Result<&2, &2, C.RegistrationError, C.Application<Page, Site, C.Policy<Unit>>>:
  C.application(~Page, ~Site, ~C.Policy<Unit>, routes(), [], site, none())

def dispatch(app: C.Application<Page, Site, C.Policy<Unit>>, path: String) -> IO(C.Completion<Unit, Unit>):
  C.dispatch(~Page, ~Unit, ~Site, ~Unit, ~Unit, ~Unit, ~before, ~after, ~run, ~C.default.mapper(~Unit, ~Site, ~Unit), ~C.notice.ignore(~Unit, ~Unit, ~Unit), ~C.notice.error.ignore(~Unit, ~Unit), Unit{}, C.access.disabled(~Unit, Unit{}), app, Unit{}, Pure.Req{"GET", path, Pure.set(Pure.empty(), "host", "bend-kit.site"), Pure.from_string("")})

def paths.go(pkgs: List<&2, Pkg>, acc: List<&2, String>) -> List<&2, String>:
  match pkgs:
    case Nil{}:
      acc
    case Con{Pkg{+name, version, about, readme, laws, bench}, rest}:
      paths.go(rest, Con{"/packages/" ++ name, Con{"/packages/" ++ name ++ "/README.md", acc}})

# Every route the static build writes.
def paths(pkgs: List<&2, Pkg>) -> List<&2, String>:
  paths.go(pkgs, ["/", "/llms.txt"])

def file.pick(file: Bool, +path: String) -> String:
  match file:
    case True{}:
      path
    case False{}:
      String.append(path, "/index.html")

# The file a route is written to: "/" and page routes become directories with index.html.
def file(+path: String) -> String:
  file.pick(String.ends_with(path, ".md") || String.ends_with(path, ".txt"), Bool.pick(String, String.eq(path, "/"), "", path))
