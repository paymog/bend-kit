import Base
import bend-kit-url@0.4.1.0/url.bend as Url

type Query is Data:
  Query{key: String, value: String}

type Target is Data:
  Target{segments: List<&2, String>, query: List<&2, Query>, authority: Maybe<&2, String>, star: Bool}

type Utf is Data:
  Utf{need: U32, lo: U32, hi: U32, cp: U32, out: String}

def between(+c: U32, lo: U32, hi: U32) -> Bool:
  Bool.and(U32.is_le(lo, c), U32.is_le(c, hi))

def utf.lead(+c: U32, out: String, ascii: Bool) -> Maybe<&2, Utf>:
  match ascii:
    case True{}:
      Some{Utf{0, 128, 191, 0, SCon{Chr{c}, out}}}
    case False{}:
      +valid = between(c, 194, 244)
      +need = Bool.pick(U32, U32.is_lt(c, 224), 1, Bool.pick(U32, U32.is_lt(c, 240), 2, 3))
      +lo = Bool.pick(U32, U32.is_eq(c, 224), 160, Bool.pick(U32, U32.is_eq(c, 240), 144, 128))
      +hi = Bool.pick(U32, U32.is_eq(c, 237), 159, Bool.pick(U32, U32.is_eq(c, 244), 143, 191))
      mask = Bool.pick(U32, U32.is_eq(need, 1), 31, Bool.pick(U32, U32.is_eq(need, 2), 15, 7))
      Bool.pick(Maybe<&2, Utf>, valid, Some{Utf{need, lo, hi, (c .&. mask : U32), out}}, None{})

def utf.more(ok: Bool, +need: U32, +cp: U32, +out: String) -> Maybe<&2, Utf>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Utf{(need - 1 : U32), 128, 191, cp, Bool.pick(String, U32.is_eq(need, 1), SCon{Chr{cp}, out}, out)}}

def utf.step(idle: Bool, +c: U32, need: U32, lo: U32, hi: U32, cp: U32, out: String) -> Maybe<&2, Utf>:
  match idle:
    case True{}:
      utf.lead(c, out, U32.is_lt(c, 128))
    case False{}:
      utf.more(between(c, lo, hi), need, (cp * 64 + (c .&. 63 : U32) : U32), out)

def utf.finish(st: Maybe<&2, Utf>) -> Maybe<&2, String>:
  match st:
    case None{}:
      None{}
    case Some{Utf{need, lo, hi, cp, out}}:
      Bool.pick(Maybe<&2, String>, U32.is_eq(need, 0), Some{String.reverse(out)}, None{})

def utf.go(s: String, st: Maybe<&2, Utf>) -> Maybe<&2, String>:
  match s:
    case SNil{}:
      utf.finish(st)
    case SCon{Chr{+c}, t}:
      match st:
        case None{}:
          None{}
        case Some{Utf{+need, lo, hi, cp, out}}:
          utf.go(t, utf.step(U32.is_eq(need, 0), c, need, lo, hi, cp, out))

def text.valid(s: String, +slash: Bool) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.and(U32.is_ne(c, 0), Bool.not(Bool.and(slash, U32.is_eq(c, 47)))), text.valid(t, slash))

def decoded.valid(+s: String, slash: Bool) -> Maybe<&2, String>:
  Bool.pick(Maybe<&2, String>, text.valid(s, slash), Some{s}, None{})

def decoded(st: Maybe<&2, String>, slash: Bool) -> Maybe<&2, String>:
  match st:
    case None{}:
      None{}
    case Some{s}:
      decoded.valid(s, slash)

def percent.got(st: Maybe<&2, String>, slash: Bool) -> Maybe<&2, String>:
  match st:
    case None{}:
      None{}
    case Some{s}:
      decoded(utf.go(s, Some{Utf{0, 128, 191, 0, ""}}), slash)

def percent(s: String, slash: Bool) -> Maybe<&2, String>:
  percent.got(Url.pct.decode(s), slash)

def segments(xs: List<&2, String>) -> Maybe<&2, List<&2, String>>:
  match xs:
    case Nil{}:
      Some{Nil{}}
    case Con{h, t}:
      do Maybe<&2, List<&2, String>>:
        head : String <- percent(h, True{})
        tail : List<&2, String> <- segments(t)
        return head <> tail

def split.path(+path: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, String.eq(path, "/"), Nil{}, String.split(String.drop(path, 1n), '/'))

def plus(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{+c}, t}:
      SCon{Chr{Bool.pick(U32, U32.is_eq(c, 43), 32, c)}, plus(t)}

def query.pair(pair: String & String) -> Maybe<&2, Query>:
  (key, value) = pair
  do Maybe<&2, Query>:
    k : String <- percent(plus(key), False{})
    v : String <- percent(plus(value), False{})
    return Query{k, v}

def query.field(field: String) -> Maybe<&2, Query>:
  query.pair(Url.take_to(field, 61))

def query(xs: List<&2, String>, acc: List<&2, Query>) -> Maybe<&2, List<&2, Query>>:
  match xs:
    case Nil{}:
      Some{List.reverse(&2, Query, acc)}
    case "" <> t:
      query(t, acc)
    case h <> t:
      do Maybe<&2, List<&2, Query>>:
        pair : Query <- query.field(h)
        query(t, pair <> acc)

def raw.valid(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.and(between(c, 33, 126), U32.is_ne(c, 35)), raw.valid(t))

def origin(path: String, q: String, authority: Maybe<&2, String>) -> Maybe<&2, Target>:
  do Maybe<&2, Target>:
    ss : List<&2, String> <- segments(split.path(path))
    pairs : List<&2, Query> <- query(String.split(q, '&'), Nil{})
    return Target{ss, pairs, authority, False{}}

def origin.split(pair: String & String, authority: Maybe<&2, String>) -> Maybe<&2, Target>:
  (path, q) = pair
  origin(path, q, authority)

def alpha(+c: U32) -> Bool:
  Bool.or(between(c, 65, 90), between(c, 97, 122))

def scheme.tail(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(Bool.or(alpha(c), Bool.or(between(c, 48, 57), Bool.or(U32.is_eq(c, 43), Bool.or(U32.is_eq(c, 45), U32.is_eq(c, 46))))), scheme.tail(t))

def scheme(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{Chr{c}, t}:
      Bool.and(alpha(c), scheme.tail(t))

def authority.take(s: String, acc: String) -> String & String:
  match s:
    case SNil{}:
      (String.reverse(acc), "/")
    case SCon{Chr{47}, t}:
      (String.reverse(acc), SCon{Chr{47}, t})
    case SCon{Chr{63}, t}:
      (String.reverse(acc), SCon{Chr{47}, SCon{Chr{63}, t}})
    case SCon{h, t}:
      authority.take(t, SCon{h, acc})

def absolute.authority(ok: Bool, authority: String, path: String) -> Maybe<&2, Target>:
  match ok:
    case False{}:
      None{}
    case True{}:
      origin.split(Url.take_to(path, 63), Some{authority})

def absolute.taken(pair: String & String) -> Maybe<&2, Target>:
  (+host, path) = pair
  absolute.authority(Bool.not(String.is_empty(host)), host, path)

def absolute.rest(rest: String) -> Maybe<&2, Target>:
  match rest:
    case SCon{Chr{47}, SCon{Chr{47}, t}}:
      absolute.taken(authority.take(t, ""))
    case _:
      None{}

def absolute.scheme(ok: Bool, rest: String) -> Maybe<&2, Target>:
  match ok:
    case False{}:
      None{}
    case True{}:
      absolute.rest(rest)

def absolute.split(pair: String & String) -> Maybe<&2, Target>:
  (+protocol, rest) = pair
  absolute.scheme(scheme(protocol), rest)

def parse.form(target: String, method: String) -> Maybe<&2, Target>:
  match target:
    case "*":
      Bool.pick(Maybe<&2, Target>, String.eq(method, "OPTIONS"), Some{Target{Nil{}, Nil{}, None{}, True{}}}, None{})
    case SCon{Chr{47}, t}:
      origin.split(Url.take_to(SCon{Chr{47}, t}, 63), None{})
    case SNil{}:
      None{}
    case SCon{h, t}:
      absolute.split(Url.take_to(SCon{h, t}, 58))

def parse.valid(ok: Bool, target: String, method: String) -> Maybe<&2, Target>:
  match ok:
    case False{}:
      None{}
    case True{}:
      parse.form(target, method)

def parse(+target: String, method: String) -> Maybe<&2, Target>:
  parse.valid(raw.valid(target), target, method)
