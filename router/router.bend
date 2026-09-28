# Match an HTTP method and path to a handler. Source: https://github.com/paymog/bend-kit/tree/main/router
import Base

# route(wantMethod, gotMethod, "/users/:id", path) → Maybe params.

def segs.one.if(h: String, acc: List<&2, String>, empty: Bool) -> List<&2, String>:
  match empty:
    case True{}:
      acc
    case False{}:
      h <> acc

def segs.one(+h: String, acc: List<&2, String>) -> List<&2, String>:
  segs.one.if(h, acc, String.is_empty(h))

def segs.keep(xs: List<&2, String>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      segs.keep(t, segs.one(h, acc))

def segs(s: String) -> List<&2, String>:
  segs.keep(String.split(s, '/'), Nil{})

def param(+seg: String) -> Bool:
  String.starts_with(seg, ":")

def zip(pat: List<&2, String>, got: List<&2, String>, +m: Map<&2, String>) -> Maybe<&2, Map<&2, String>>:
  match pat:
    case Nil{}:
      match got:
        case Nil{}:
          Some{m}
        case Con{h, t}:
          None{}
    case Con{+p, +pt}:
      match got:
        case Nil{}:
          None{}
        case Con{+g, +gt}:
          Bool.pick(Maybe<&2, Map<&2, String>>, param(p), zip(pt, gt, Map.set(&2, String, m, String.drop(p, 1n), g)), Bool.pick(Maybe<&2, Map<&2, String>>, String.eq(p, g), zip(pt, gt, m), None{}))

def route.ok(pattern: String, path: String, same: Bool) -> Maybe<&2, Map<&2, String>>:
  match same:
    case False{}:
      None{}
    case True{}:
      zip(segs(pattern), segs(path), Map.new(&2, String))

def route(want: String, method: String, pattern: String, path: String) -> Maybe<&2, Map<&2, String>>:
  route.ok(pattern, path, String.eq(want, method))
