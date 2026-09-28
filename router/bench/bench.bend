# Router benchmark: match 16 requests against 8 routes, N rounds (see README.md).
import Base
import ../../time/time.bend as Time
import ../router.bend as R

type Route is Data:
  Route{want: String, pat: String, names: List<&2, String>}

type Req is Data:
  Req{method: String, path: String}

def mix(h: U32, +x: U32) -> U32:
  ((h * 31 : U32) + x : U32)

def sum(s: String, h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      sum(t, mix(h, c))

def params.got(r: Map<&2, String> & String, h: U32) -> Map<&2, String> & U32:
  (m, v) = r
  (m, sum(v, h))

def params(ns: List<&2, String>, st: Map<&2, String> & U32) -> U32:
  match ns:
    case Nil{}:
      (m, h) = st
      h
    case Con{k, t}:
      (m, h) = st
      params(t, params.got(Map.get(String, "", m, k), h))

# Route i (1-based) is the first match: fold i, then each param value, in the route's name order.
def hit(+i: U32, ns: List<&2, String>, m: Map<&2, String>, h: U32) -> U32:
  params(ns, (m, mix(h, i)))

def find(routes: List<&2, Route>, got: Maybe<&2, Map<&2, String>>, ns: List<&2, String>, +i: U32, +method: String, +path: String, h: U32) -> U32:
  match routes:
    case Nil{}:
      match got:
        case None{}:
          mix(h, 0)
        case Some{m}:
          hit(i, ns, m, h)
    case Con{Route{want, pat, names}, t}:
      match got:
        case Some{m}:
          hit(i, ns, m, h)
        case None{}:
          find(t, R.route(want, method, pat, path), names, (i + 1 : U32), method, path, h)

def routes() -> List<&2, Route>:
  [
    Route{"GET", "/health", []},
    Route{"GET", "/users", []},
    Route{"POST", "/users", []},
    Route{"GET", "/users/:id", ["id"]},
    Route{"PUT", "/users/:id", ["id"]},
    Route{"GET", "/users/:id/posts", ["id"]},
    Route{"GET", "/users/:id/posts/:post", ["id", "post"]},
    Route{"GET", "/orgs/:org/repos/:repo/issues/:num", ["org", "repo", "num"]}
  ]

def requests() -> List<&2, Req>:
  [
    Req{"GET", "/health"},
    Req{"GET", "/users"},
    Req{"POST", "/users"},
    Req{"GET", "/users/42"},
    Req{"PUT", "/users/42"},
    Req{"DELETE", "/users/42"},
    Req{"GET", "/users/7/posts"},
    Req{"GET", "/users/7/posts/99"},
    Req{"GET", "/orgs/bendlang/repos/bend/issues/1077"},
    Req{"GET", "/orgs/bendlang/repos/bend"},
    Req{"GET", "/missing"},
    Req{"POST", "/health"},
    Req{"GET", "/users/alice"},
    Req{"GET", "/users/alice/posts/first"},
    Req{"PUT", "/users/bob/posts"},
    Req{"GET", "/orgs/paymog/repos/bend-kit/issues/73"}
  ]

def each(rs: List<&2, Req>, h: U32) -> U32:
  match rs:
    case Nil{}:
      h
    case Con{Req{method, path}, t}:
      each(t, find(routes(), None{}, Nil{}, 0, method, path, h))

def rounds(n: Nat, h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      rounds(p, each(requests(), h))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    chk : U32 = rounds(10000n, 0)
    t1 : Time.Duration <- Time.mono()
    IO.print("route\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk))
