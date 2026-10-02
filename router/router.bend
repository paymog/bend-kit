# Prepared HTTP routes with exact paths, validated registration, and path-first method selection. Source: https://github.com/paymog/bend-kit/tree/main/router
import Base
import ./target.bend as Target

type Segment is Data:
  Literal{text: String}
  Parameter{name: String}

type Entry<-A: Data> is Data:
  Entry{method: String, pattern: String, action: A, groups: List<&2, U32>}

type Handler<-A: Data> is Data:
  Handler{method: String, pattern: String, segments: List<&2, Segment>, action: A}

type Path<-A: Data> is Data:
  Path{segments: List<&2, Segment>, handlers: List<&2, Handler<A>>, groups: List<&2, U32>, allow: String}

type Table<-A: Data> is Data:
  Table{paths: List<&2, Path<A>>, allow: String}

type Error is Data:
  InvalidPattern{pattern: String}
  InvalidMethod{method: String}
  Duplicate{method: String, pattern: String}
  GroupConflict{pattern: String}
  BadTarget{}

type Choice<-A: Data> is Data:
  Found{action: A, params: Map<&2, String>, groups: List<&2, U32>, method: String, pattern: String}
  MethodMissing{groups: List<&2, U32>, allow: String}
  Options{groups: List<&2, U32>, allow: String}
  NotFound{}

type Resolved<-A: Data> is Data:
  Resolved{target: Target.Target, choice: Choice<A>}

type Hidden is Data:
  Hidden{pattern: String, methods: String}

type Description is Data:
  Description{method: String, pattern: String, groups: List<&2, U32>, hidden: List<&2, Hidden>}

def scalar(+c: U32) -> Bool:
  Bool.and(U32.is_le(c, 1114111), Bool.not(Target.between(c, 55296, 57343)))

def literal.valid(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.and(scalar(c), Bool.and(U32.is_ne(c, 0), U32.is_ne(c, 47))), literal.valid(t))

def name.tail(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(Target.alpha(c), Bool.or(Target.between(c, 48, 57), U32.is_eq(c, 95))), name.tail(t))

def name.valid(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(Target.alpha(c), U32.is_eq(c, 95)), name.tail(t))

def member(xs: List<&2, String>, +s: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(String.eq(h, s), member(t, s))

def pattern.segment(s: String, names: List<&2, String>) -> Maybe<&2, Segment>:
  match s:
    case SCon{Chr{58}, +t}:
      Bool.pick(Maybe<&2, Segment>, Bool.and(name.valid(t), Bool.not(member(names, t))), Some{Parameter{t}}, None{})
    case SNil{}:
      Some{Literal{""}}
    case SCon{+h, +t}:
      +lit = {SCon{h, t} : String}
      Bool.pick(Maybe<&2, Segment>, literal.valid(lit), Some{Literal{lit}}, None{})

def pattern.names(segment: Segment, names: List<&2, String>) -> List<&2, String>:
  match segment:
    case Literal{text}:
      names
    case Parameter{name}:
      name <> names

def pattern.parts(xs: List<&2, String>, +names: List<&2, String>, acc: List<&2, Segment>) -> Maybe<&2, List<&2, Segment>>:
  match xs:
    case Nil{}:
      Some{List.reverse(&2, Segment, acc)}
    case "" <> Nil{}:
      Some{List.reverse(&2, Segment, Literal{""} <> acc)}
    case "" <> t:
      None{}
    case h <> t:
      do Maybe<&2, List<&2, Segment>>:
        seg : Segment <- pattern.segment(h, names)
        +part : Segment = seg
        pattern.parts(t, pattern.names(part, names), part <> acc)

def pattern(s: String) -> Maybe<&2, List<&2, Segment>>:
  match s:
    case "/":
      Some{Nil{}}
    case SCon{Chr{47}, t}:
      pattern.parts(String.split(t, '/'), Nil{}, Nil{})
    case _:
      None{}

def token(+c: U32) -> Bool:
  Bool.or(Target.alpha(c), Bool.or(Target.between(c, 48, 57), Bool.or(U32.is_eq(c, 33), Bool.or(Target.between(c, 35, 39), Bool.or(Target.between(c, 42, 43), Bool.or(Target.between(c, 45, 46), Bool.or(Target.between(c, 94, 96), Bool.or(U32.is_eq(c, 124), U32.is_eq(c, 126)))))))))

def method.tail(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{c}, t}:
      Bool.and(token(c), method.tail(t))

def method.valid(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, t}:
      Bool.and(token(c), method.tail(t))

def continue(ok: Bool, later: Unit -> Bool) -> Bool:
  match ok:
    case False{}:
      False{}
    case True{}:
      later(Unit{})

def matches(pat: List<&2, Segment>, got: List<&2, String>) -> Bool:
  match pat got:
    case Nil{} Nil{}:
      True{}
    case Literal{p} <> pt g <> gt:
      continue(String.eq(p, g), u => matches(pt, gt))
    case Parameter{name} <> pt +g <> gt:
      continue(Bool.not(String.is_empty(g)), u => matches(pt, gt))
    case _ _:
      False{}

def capture(pat: List<&2, Segment>, got: List<&2, String>, acc: Map<&2, String>) -> Map<&2, String>:
  match pat got:
    case Parameter{name} <> pt g <> gt:
      capture(pt, gt, Map.set(&2, String, acc, name, g))
    case Literal{text} <> pt g <> gt:
      capture(pt, gt, acc)
    case _ _:
      acc

def shape(a: List<&2, Segment>, b: List<&2, Segment>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Literal{x} <> at Literal{y} <> bt:
      continue(String.eq(x, y), u => shape(at, bt))
    case Parameter{x} <> at Parameter{y} <> bt:
      shape(at, bt)
    case _ _:
      False{}

def specific(a: List<&2, Segment>, b: List<&2, Segment>) -> Bool:
  match a b:
    case Literal{x} <> at Parameter{y} <> bt:
      True{}
    case Parameter{x} <> at Literal{y} <> bt:
      False{}
    case Literal{x} <> at Literal{y} <> bt:
      specific(at, bt)
    case Parameter{x} <> at Parameter{y} <> bt:
      specific(at, bt)
    case _ _:
      False{}

def groups.eq(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case x <> at y <> bt:
      continue(U32.is_eq(x, y), u => groups.eq(at, bt))
    case _ _:
      False{}

def handler.has(~A: Data, xs: List<&2, Handler<A>>, +method: String) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Handler{want, pattern, segments, action} <> t:
      Bool.or(String.eq(want, method), handler.has(~A, t, method))

def insert.merge(~A: Data, duplicate: Bool, same_groups: Bool, entry: Handler<A>, segments: List<&2, Segment>, handlers: List<&2, Handler<A>>, groups: List<&2, U32>, rest: List<&2, Path<A>>) -> Result<&2, &2, Error, List<&2, Path<A>>>:
  match duplicate same_groups:
    case True{} _:
      Handler{method, pattern, ss, action} = entry
      Fail{Duplicate{method, pattern}}
    case False{} False{}:
      Handler{method, pattern, ss, action} = entry
      Fail{GroupConflict{pattern}}
    case False{} True{}:
      Done{Path{segments, entry <> handlers, groups, ""} <> rest}

def insert.branch(~A: Data, same: Bool, segments: List<&2, Segment>, +handlers: List<&2, Handler<A>>, +old_groups: List<&2, U32>, allowed: String, tail: List<&2, Path<A>>, entry: Handler<A>, groups: List<&2, U32>, rest: Unit -> Result<&2, &2, Error, List<&2, Path<A>>>) -> Result<&2, &2, Error, List<&2, Path<A>>>:
  match same:
    case True{}:
      Handler{+method, pattern, ss, action} = entry
      insert.merge(~A, handler.has(~A, handlers, method), groups.eq(old_groups, groups), Handler{method, pattern, ss, action}, segments, handlers, old_groups, tail)
    case False{}:
      do Result<&2, &2, Error, List<&2, Path<A>>>:
        remaining : List<&2, Path<A>> <- rest(Unit{})
        return Path{segments, handlers, old_groups, allowed} <> remaining

# ponytail: preparation merges shapes in O(routes²); replace with a shape index if construction becomes a bottleneck.
def insert(~A: Data, paths: List<&2, Path<A>>, +entry: Handler<A>, +groups: List<&2, U32>) -> Result<&2, &2, Error, List<&2, Path<A>>>:
  match paths:
    case Nil{}:
      Handler{method, pattern, +ss, action} = entry
      Done{[Path{ss, [Handler{method, pattern, ss, action}], groups, ""}]}
    case Path{+ss, +handlers, +old_groups, +allow} <> +t:
      Handler{+method, +pattern, +es, +action} = entry
      candidate = {Handler{method, pattern, es, action} : Handler<A>}
      insert.branch(~A, shape(ss, es), ss, handlers, old_groups, allow, t, candidate, groups, u => insert(~A, t, Handler{method, pattern, es, action}, groups))

def method.prepend(get: Bool, method: String, tail: List<&2, String>) -> List<&2, String>:
  match get:
    case True{}:
      method <> "HEAD" <> tail
    case False{}:
      method <> tail

def method.names(~A: Data, xs: List<&2, Handler<A>>) -> List<&2, String>:
  match xs:
    case Nil{}:
      ["OPTIONS"]
    case Handler{+method, pattern, ss, action} <> t:
      method.prepend(String.eq(method, "GET"), method, method.names(~A, t))

def unique(xs: List<&2, String>, prev: String, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      List.reverse(&2, String, acc)
    case +h <> t:
      unique(t, h, Bool.pick(List<&2, String>, String.eq(h, prev), acc, h <> acc))

def allow(xs: List<&2, String>) -> String:
  String.join(unique(List.sort(~String, ~String.is_le, xs), "", Nil{}), ", ")

def finish.paths(~A: Data, paths: List<&2, Path<A>>) -> List<&2, Path<A>>:
  match paths:
    case Nil{}:
      Nil{}
    case Path{segments, +handlers, groups, old_allow} <> t:
      Path{segments, handlers, groups, allow(method.names(~A, handlers))} <> finish.paths(~A, t)

def all.methods(~A: Data, paths: List<&2, Path<A>>) -> List<&2, String>:
  match paths:
    case Nil{}:
      ["OPTIONS"]
    case Path{ss, handlers, groups, allowed} <> t:
      List.append(&2, String, method.names(~A, handlers), all.methods(~A, t))

def prepare.pattern(~A: Data, parsed: Maybe<&2, List<&2, Segment>>, method: String, pattern: String, action: A, groups: List<&2, U32>, paths: List<&2, Path<A>>) -> Result<&2, &2, Error, List<&2, Path<A>>>:
  match parsed:
    case None{}:
      Fail{InvalidPattern{pattern}}
    case Some{ss}:
      insert(~A, paths, Handler{method, pattern, ss, action}, groups)

def prepare.entry(~A: Data, valid: Bool, entry: Entry<A>, paths: List<&2, Path<A>>) -> Result<&2, &2, Error, List<&2, Path<A>>>:
  match valid:
    case False{}:
      Entry{method, p, action, groups} = entry
      Fail{InvalidMethod{method}}
    case True{}:
      Entry{method, +p, action, groups} = entry
      prepare.pattern(~A, pattern(p), method, p, action, groups, paths)

def prepare.go(~A: Data, entries: List<&2, Entry<A>>, paths: List<&2, Path<A>>) -> Result<&2, &2, Error, Table<A>>:
  match entries:
    case Nil{}:
      +prepared = finish.paths(~A, paths)
      Done{Table{prepared, allow(all.methods(~A, prepared))}}
    case Entry{+method, p, action, groups} <> t:
      do Result<&2, &2, Error, Table<A>>:
        next : List<&2, Path<A>> <- prepare.entry(~A, method.valid(method), Entry{method, p, action, groups}, paths)
        prepare.go(~A, t, next)

def prepare(~A: Data, entries: List<&2, Entry<A>>) -> Result<&2, &2, Error, Table<A>>:
  prepare.go(~A, entries, Nil{})

def best.compare(~A: Data, candidate: Path<A>, old: Path<A>) -> Maybe<&2, Path<A>>:
  Path{+cs, +ch, +cg, +ca} = candidate
  Path{+ss, +handlers, +groups, +allowed} = old
  Bool.pick(Maybe<&2, Path<A>>, specific(cs, ss), Some{Path{cs, ch, cg, ca}}, Some{Path{ss, handlers, groups, allowed}})

def best.pick(~A: Data, best: Maybe<&2, Path<A>>, candidate: Path<A>) -> Maybe<&2, Path<A>>:
  match best:
    case None{}:
      Some{candidate}
    case Some{old}:
      best.compare(~A, candidate, old)

def best.step(~A: Data, matched: Bool, candidate: Path<A>, best: Maybe<&2, Path<A>>) -> Maybe<&2, Path<A>>:
  match matched:
    case False{}:
      best
    case True{}:
      best.pick(~A, best, candidate)

# ponytail: lookup scans prepared paths in O(routes × segments); use a trie if measured dispatch cost warrants it.
def best(~A: Data, paths: List<&2, Path<A>>, +segments: List<&2, String>, acc: Maybe<&2, Path<A>>) -> Maybe<&2, Path<A>>:
  match paths:
    case Nil{}:
      acc
    case Path{+ss, handlers, groups, allowed} <> t:
      best(~A, t, segments, best.step(~A, matches(ss, segments), Path{ss, handlers, groups, allowed}, acc))

def handler.next(~A: Data, same: Bool, here: Handler<A>, later: Unit -> Maybe<&2, Handler<A>>) -> Maybe<&2, Handler<A>>:
  match same:
    case True{}:
      Some{here}
    case False{}:
      later(Unit{})

def handler(~A: Data, xs: List<&2, Handler<A>>, +method: String) -> Maybe<&2, Handler<A>>:
  match xs:
    case Nil{}:
      None{}
    case Handler{+want, pattern, ss, action} <> t:
      handler.next(~A, String.eq(want, method), Handler{want, pattern, ss, action}, u => handler(~A, t, method))

def chosen(~A: Data, hit: Maybe<&2, Handler<A>>, segments: List<&2, String>, +groups: List<&2, U32>, +allowed: String, options: Bool) -> Choice<A>:
  match hit:
    case Some{Handler{method, pattern, ss, action}}:
      Found{action, capture(ss, segments, Map.new(&2, String)), groups, method, pattern}
    case None{}:
      Bool.pick(Choice<A>, options, Options{groups, allowed}, MethodMissing{groups, allowed})

def choose.fallback(~A: Data, head: Bool, handlers: List<&2, Handler<A>>, method: String, segments: List<&2, String>, groups: List<&2, U32>, allowed: String) -> Choice<A>:
  match head:
    case True{}:
      chosen(~A, handler(~A, handlers, "GET"), segments, groups, allowed, False{})
    case False{}:
      chosen(~A, None{}, segments, groups, allowed, String.eq(method, "OPTIONS"))

def choose.method(~A: Data, direct: Maybe<&2, Handler<A>>, +handlers: List<&2, Handler<A>>, +method: String, segments: List<&2, String>, groups: List<&2, U32>, allowed: String) -> Choice<A>:
  match direct:
    case Some{h}:
      chosen(~A, Some{h}, segments, groups, allowed, False{})
    case None{}:
      choose.fallback(~A, String.eq(method, "HEAD"), handlers, method, segments, groups, allowed)

def choose.path(~A: Data, path: Maybe<&2, Path<A>>, +method: String, segments: List<&2, String>) -> Choice<A>:
  match path:
    case None{}:
      NotFound{}
    case Some{Path{ss, +handlers, groups, allowed}}:
      choose.method(~A, handler(~A, handlers, method), handlers, method, segments, groups, allowed)

def resolve.star(~A: Data, star: Bool, paths: List<&2, Path<A>>, allowed: String, target: Target.Target, method: String, +segments: List<&2, String>) -> Resolved<A>:
  match star:
    case True{}:
      Resolved{target, Options{Nil{}, allowed}}
    case False{}:
      Resolved{target, choose.path(~A, best(~A, paths, segments, None{}), method, segments)}

def resolve.target(~A: Data, parsed: Maybe<&2, Target.Target>, table: Table<A>, method: String) -> Result<&2, &2, Error, Resolved<A>>:
  match parsed:
    case None{}:
      Fail{BadTarget{}}
    case Some{Target.Target{+segments, +query, +authority, +star}}:
      Table{paths, allowed} = table
      Done{resolve.star(~A, star, paths, allowed, Target.Target{segments, query, authority, star}, method, segments)}

def resolve(~A: Data, table: Table<A>, +method: String, target: String) -> Result<&2, &2, Error, Resolved<A>>:
  resolve.target(~A, Target.parse(target, method), table, method)

def route.match(ok: Bool, ss: List<&2, Segment>, got: List<&2, String>) -> Maybe<&2, Map<&2, String>>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{capture(ss, got, Map.new(&2, String))}

def route.path(star: Bool, +ss: List<&2, Segment>, +got: List<&2, String>) -> Maybe<&2, Map<&2, String>>:
  match star:
    case True{}:
      None{}
    case False{}:
      route.match(matches(ss, got), ss, got)

def route.target(parsed: Maybe<&2, Target.Target>, +ss: List<&2, Segment>) -> Maybe<&2, Map<&2, String>>:
  match parsed:
    case None{}:
      None{}
    case Some{Target.Target{+got, query, authority, star}}:
      route.path(star, ss, got)

def route.pattern(parsed: Maybe<&2, List<&2, Segment>>, path: String, method: String) -> Maybe<&2, Map<&2, String>>:
  match parsed:
    case None{}:
      None{}
    case Some{ss}:
      route.target(Target.parse(path, method), ss)

def route.method(same: Bool, p: String, path: String, method: String) -> Maybe<&2, Map<&2, String>>:
  match same:
    case False{}:
      None{}
    case True{}:
      route.pattern(pattern(p), path, method)

def route(want: String, +method: String, pattern: String, path: String) -> Maybe<&2, Map<&2, String>>:
  route.method(String.eq(want, method), pattern, path, method)

def overlap(a: List<&2, Segment>, b: List<&2, Segment>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Literal{x} <> at Literal{y} <> bt:
      continue(String.eq(x, y), u => overlap(at, bt))
    case Literal{x} <> at Parameter{y} <> bt:
      continue(Bool.not(String.is_empty(x)), u => overlap(at, bt))
    case Parameter{x} <> at Literal{y} <> bt:
      continue(Bool.not(String.is_empty(y)), u => overlap(at, bt))
    case Parameter{x} <> at Parameter{y} <> bt:
      overlap(at, bt)
    case _ _:
      False{}

def unavailable.prepend(keep: Bool, h: String, tail: List<&2, String>) -> List<&2, String>:
  match keep:
    case False{}:
      tail
    case True{}:
      h <> tail

def unavailable(xs: List<&2, String>, +present: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case +h <> t:
      unavailable.prepend(Bool.not(member(present, h)), h, unavailable(t, present))

def hidden.add(empty: Bool, pattern: String, methods: String, tail: List<&2, Hidden>) -> List<&2, Hidden>:
  match empty:
    case True{}:
      tail
    case False{}:
      Hidden{pattern, methods} <> tail

def hidden.handlers(~A: Data, handlers: List<&2, Handler<A>>, +present: List<&2, String>, tail: List<&2, Hidden>) -> List<&2, Hidden>:
  match handlers:
    case Nil{}:
      tail
    case Handler{+method, +pattern, ss, action} <> rest:
      +missing = allow(unavailable(method.prepend(String.eq(method, "GET"), method, Nil{}), present))
      hidden.add(String.is_empty(missing), pattern, missing, hidden.handlers(~A, rest, present, tail))

def hidden.path(~A: Data, hides: Bool, handlers: List<&2, Handler<A>>, present: List<&2, String>, tail: List<&2, Hidden>) -> List<&2, Hidden>:
  match hides:
    case False{}:
      tail
    case True{}:
      hidden.handlers(~A, handlers, present, tail)

def hidden.scan(~A: Data, paths: List<&2, Path<A>>, +segments: List<&2, Segment>, +methods: List<&2, String>) -> List<&2, Hidden>:
  match paths:
    case Nil{}:
      Nil{}
    case Path{+ss, handlers, groups, allowed} <> t:
      hidden.path(~A, Bool.and(specific(segments, ss), overlap(segments, ss)), handlers, methods, hidden.scan(~A, t, segments, methods))

def description.handlers(~A: Data, handlers: List<&2, Handler<A>>, +groups: List<&2, U32>, +hidden: List<&2, Hidden>) -> List<&2, Description>:
  match handlers:
    case Nil{}:
      Nil{}
    case Handler{method, pattern, ss, action} <> t:
      Description{method, pattern, groups, hidden} <> description.handlers(~A, t, groups, hidden)

def description.paths(~A: Data, paths: List<&2, Path<A>>, +all: List<&2, Path<A>>) -> List<&2, Description>:
  match paths:
    case Nil{}:
      Nil{}
    case Path{segments, +handlers, groups, allowed} <> t:
      List.append(&2, Description, description.handlers(~A, handlers, groups, hidden.scan(~A, all, segments, method.names(~A, handlers))), description.paths(~A, t, all))

def describe(~A: Data, table: Table<A>) -> List<&2, Description>:
  Table{+paths, allowed} = table
  description.paths(~A, paths, paths)
