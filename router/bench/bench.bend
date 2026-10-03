# Router benchmark: match 16 requests against 8 routes, N rounds (see README.md).
import Base
import ../../time/time.bend as Time
import ../router.bend as R

type Action is Data:
  Action{index: U32, names: List<&2, String>}

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

def chosen(choice: R.Choice<Action>, h: U32) -> U32:
  match choice:
    case R.Found{Action{i, names}, params, groups, method, pattern}:
      hit(i, names, params, h)
    case _:
      mix(h, 0)

def resolved(result: Result<&2, &2, R.Error, R.Resolved<Action>>, h: U32) -> U32:
  match result:
    case Fail{error}:
      mix(h, 0)
    case Done{R.Resolved{target, choice}}:
      chosen(choice, h)

def routes() -> List<&2, R.Entry<Action>>:
  [
    R.Entry{"GET", "/health", Action{1, []}, []},
    R.Entry{"GET", "/users", Action{2, []}, []},
    R.Entry{"POST", "/users", Action{3, []}, []},
    R.Entry{"GET", "/users/:id", Action{4, ["id"]}, []},
    R.Entry{"PUT", "/users/:id", Action{5, ["id"]}, []},
    R.Entry{"GET", "/users/:id/posts", Action{6, ["id"]}, []},
    R.Entry{"GET", "/users/:id/posts/:post", Action{7, ["id", "post"]}, []},
    R.Entry{"GET", "/orgs/:org/repos/:repo/issues/:num", Action{8, ["org", "repo", "num"]}, []}
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

def each(rs: List<&2, Req>, +table: R.Table<Action>, h: U32) -> U32:
  match rs:
    case Nil{}:
      h
    case Con{Req{method, path}, t}:
      each(t, table, resolved(R.resolve(~Action, table, method, path), h))

def rounds(n: Nat, +table: R.Table<Action>, h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      rounds(p, table, each(requests(), table, h))

def ready(result: Result<&2, &2, R.Error, R.Table<Action>>) -> IO(R.Table<Action>):
  match result:
    case Fail{error}:
      IO.die(R.Table<Action>, 1, "benchmark registration rejected")
    case Done{table}:
      IO.pure(R.Table<Action>, table)

def main() -> IO(Unit):
  do IO<Unit>:
    table : R.Table<Action> <- ready(R.prepare(~Action, routes()))
    t0 : Time.Duration <- Time.mono()
    chk : U32 = rounds(10000n, table, 0)
    t1 : Time.Duration <- Time.mono()
    IO.print("route\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(chk))
