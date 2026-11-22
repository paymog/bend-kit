# Dependency plans with proved order and closure, incremental invalidation, and a build runner.
import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import bend-kit-hash@0.3.2.2/hash.bend as Hash
import bend-kit-files@0.4.0.1/files.bend as Files
import bend-kit-process@0.5.2.1/process.bend as Proc
import bend-kit-collections@0.1.6.0/omap.bend as OMap
import bend-kit-collections@0.1.6.0/order.bend as Order

# A node and the nodes it requires. Its prerequisites must succeed before it runs.
type Node<-K: Data> is Data:
  Node{id: K, deps: List<&2, K>}

type Error<-K: Data> is Data:
  # node is undefined; chain is the requirement path from a target to the node that names it.
  Missing{node: K, chain: List<&2, K>}
  # Each node requires the next, and the last is the first.
  Cycle{path: List<&2, K>}
  # The candidate failed the plan check. This is a planner bug.
  Refused{}

type Status is Data:
  # The command ran and exited 0.
  Built{}
  # The node was not stale, so its command did not run.
  Fresh{}
  # The command ran and failed.
  Failed{}
  # The node is undefined, or a prerequisite did not succeed.
  Skipped{}

type Entry<-K: Data> is Data:
  Entry{node: K, status: Status}

type Action is Data:
  # Run the command, then record Built or Failed.
  Run{}
  # Record this status without a run.
  Mark{status: Status}
  # The node already has a status.
  Pass{}

def when(-A: Type, rest: Unit -> A, hit: Bool, yes: A) -> A:
  match hit:
    case True{}:
      yes
    case False{}:
      rest(Unit{})

# eq(k, x) for some x of xs.
def member(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +k: K) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+x, t}:
      when(Bool, u => member(~K, ~eq, t, k), eq(k, x), True{})

# Every x of xs is a member of ys.
def all_in(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +ys: List<&2, K>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+x, t}:
      Bool.and(member(~K, ~eq, ys, x), all_in(~K, ~eq, t, ys))

# Some x of xs is a member of ys.
def any_in(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +ys: List<&2, K>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+x, t}:
      Bool.or(member(~K, ~eq, ys, x), any_in(~K, ~eq, t, ys))

# No element occurs twice.
def distinct(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+x, +t}:
      Bool.and(Bool.not(member(~K, ~eq, t, x)), distinct(~K, ~eq, t))

def rev(-K: Data, xs: List<&2, K>, acc: List<&2, K>) -> List<&2, K>:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      rev(K, t, x <> acc)

def cat(-K: Data, xs: List<&2, K>, ys: List<&2, K>) -> List<&2, K>:
  match xs:
    case Nil{}:
      ys
    case Con{x, t}:
      x <> cat(K, t, ys)

# The prerequisites of the first node named k; None when no node is.
def deps(~K: Data, ~eq: K -> K -> Bool, g: List<&2, Node<K>>, +k: K) -> Maybe<&2, List<&2, K>>:
  match g:
    case Nil{}:
      None{}
    case Con{Node{+id, +ds}, t}:
      when(Maybe<&2, List<&2, K>>, u => deps(~K, ~eq, t, k), eq(k, id), Some{ds})

def deps.or_nil(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, Node<K>>, +k: K) -> List<&2, K>:
  Maybe.default(&2, List<&2, K>, deps(~K, ~eq, g, k), Nil{})

# Plan check
# ----------

def ordered.node(~K: Data, ~eq: K -> K -> Bool, m: Maybe<&2, List<&2, K>>, +done: List<&2, K>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{ds}:
      all_in(~K, ~eq, ds, done)

# Each node is defined, is not in done, and has every prerequisite in done; it then joins done.
def ordered(~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, Node<K>>, +done: List<&2, K>) -> Bool:
  match p:
    case Nil{}:
      True{}
    case Con{+x, t}:
      Bool.and(Bool.not(member(~K, ~eq, done, x)),
        Bool.and(ordered.node(~K, ~eq, deps(~K, ~eq, g, x), done),
          ordered(~K, ~eq, t, g, x <> done)))

# Over the plan reversed: each node is in want, a target or a prerequisite of a later node.
def needed(~K: Data, ~eq: K -> K -> Bool, r: List<&2, K>, +g: List<&2, Node<K>>, +want: List<&2, K>) -> Bool:
  match r:
    case Nil{}:
      True{}
    case Con{+x, t}:
      Bool.and(member(~K, ~eq, want, x), needed(~K, ~eq, t, g, cat(K, deps.or_nil(~K, ~eq, g, x), want)))

# p is a dependency order of exactly the closure of ts.
def valid(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, Node<K>>, +ts: List<&2, K>, +p: List<&2, K>) -> Bool:
  Bool.and(ordered(~K, ~eq, p, g, Nil{}),
    Bool.and(needed(~K, ~eq, rev(K, p, Nil{}), g, ts), all_in(~K, ~eq, ts, p)))

# Planning
# --------

# The open path from the node eq to k, nearest last, then acc.
def cyc(~K: Data, ~eq: K -> K -> Bool, path: List<&2, K>, +k: K, +acc: List<&2, K>) -> List<&2, K>:
  match path:
    case Nil{}:
      acc
    case Con{+x, t}:
      when(List<&2, K>, u => cyc(~K, ~eq, t, k, x <> acc), eq(k, x), x <> acc)

def cycle(~K: Data, ~eq: K -> K -> Bool, path: List<&2, K>, +k: K) -> Error<K>:
  Cycle{cyc(~K, ~eq, path, k, [k])}

def go.node(-K: Data, -R: Type, m: Maybe<&2, List<&2, K>>, missing: Unit -> R, child: List<&2, K> -> R) -> R:
  match m:
    case None{}:
      missing(Unit{})
    case Some{dd}:
      child(dd)

def go.open(-K: Data, -R: Type, open: Bool, m: Unit -> Maybe<&2, List<&2, K>>, loop: Unit -> R, missing: Unit -> R, child: List<&2, K> -> R) -> R:
  match open:
    case True{}:
      loop(Unit{})
    case False{}:
      go.node(K, R, m(Unit{}), missing, child)

# One node d: skip it when done, report a cycle when open, report it when missing, else visit its prerequisites.
def go.at(
  -K: Data, -R: Type, seen: Bool, open: Unit -> Bool, m: Unit -> Maybe<&2, List<&2, K>>,
  skip: Unit -> R, loop: Unit -> R, missing: Unit -> R, child: List<&2, K> -> R
) -> R:
  match seen:
    case True{}:
      skip(Unit{})
    case False{}:
      go.open(K, R, open(Unit{}), m, loop, missing, child)

def go.then(-K: Data, r: Result<&2, &2, Error<K>, List<&2, K>>, k: List<&2, K> -> Result<&2, &2, Error<K>, List<&2, K>>) -> Result<&2, &2, Error<K>, List<&2, K>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{x}:
      k(x)

def go.out(-K: Data, ds: List<&2, K>, done: List<&2, K>) -> Result<&2, &2, Error<K>, List<&2, K>>:
  match ds:
    case Nil{}:
      Done{done}
    case Con{d, t}:
      Fail{Refused{}}

# A depth-first walk of ds. path holds the open nodes, nearest first; done the finished ones, last first.
# Each level of path costs one unit of fuel.
def go(
  ~K: Data, ~eq: K -> K -> Bool, fuel: Nat, ds: List<&2, K>, +g: List<&2, Node<K>>,
  +path: List<&2, K>, +done: List<&2, K>
) -> Result<&2, &2, Error<K>, List<&2, K>>:
  match fuel:
    case 0n:
      go.out(K, ds, done)
    case 1n+(+f):
      match ds:
        case Nil{}:
          Done{done}
        case Con{+d, +rest}:
          go.at(K, Result<&2, &2, Error<K>, List<&2, K>>, member(~K, ~eq, done, d), u => member(~K, ~eq, path, d), u => deps(~K, ~eq, g, d),
            u => go(~K, ~eq, 1n+f, rest, g, path, done),
            u => Fail{cycle(~K, ~eq, path, d)},
            u => Fail{Missing{d, rev(K, path, Nil{})}},
            dd => go.then(K, go(~K, ~eq, f, dd, g, d <> path, done), r => go(~K, ~eq, 1n+f, rest, g, path, d <> r)))

def plan.ok(-K: Data, c: Bool, p: List<&2, K>) -> Result<&2, &2, Error<K>, List<&2, K>>:
  match c:
    case True{}:
      Done{p}
    case False{}:
      Fail{Refused{}}

def plan.check(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, Node<K>>, +ts: List<&2, K>, r: Result<&2, &2, Error<K>, List<&2, K>>) -> Result<&2, &2, Error<K>, List<&2, K>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{out}:
      +p = rev(K, out, Nil{})
      plan.ok(K, valid(~K, ~eq, g, ts, p), p)

# The closure of ts in dependency order, each node once; or why there is none.
# A path never repeats a node, and each node on it is defined, so one level per node is enough fuel.
def plan(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, Node<K>>, +ts: List<&2, K>) -> Result<&2, &2, Error<K>, List<&2, K>>:
  plan.check(~K, ~eq, g, ts, go(~K, ~eq, 1n+List.length(&2, Node<K>, g), ts, g, Nil{}, Nil{}))

# Indexed planning
# ----------------
# The same plan in O(n log n) comparisons: sets and the graph live in ordered maps under cmp.

def idx(~K: Data, ~cmp: K -> K -> Cmp, xs: List<&2, K>) -> OMap.OSet(K):
  match xs:
    case Nil{}:
      OMap.OSet.new(K)
    case Con{+x, t}:
      OMap.OSet.add(~K, ~cmp, idx(~K, ~cmp, t), x)

# The prerequisites of each node; the first node with an id wins, as deps does.
def gidx(~K: Data, ~cmp: K -> K -> Cmp, g: List<&2, Node<K>>) -> OMap.OMap<K, List<&2, K>>:
  match g:
    case Nil{}:
      OMap.OMap.new(K, List<&2, K>)
    case Con{Node{+id, +ds}, t}:
      OMap.OMap.put(~K, ~List<&2, K>, ~cmp, gidx(~K, ~cmp, t), id, ds)

# A walk's finished nodes and their index.
type Walk<-K: Data> is Data:
  Walk{done: List<&2, K>, idx: OMap.OSet(K)}

def fast.at(-K: Data, -R: Type, seen: Bool, open: Bool, m: Maybe<&2, List<&2, K>>, skip: Unit -> R, loop: Unit -> R, missing: Unit -> R, child: List<&2, K> -> R) -> R:
  match seen:
    case True{}:
      skip(Unit{})
    case False{}:
      match open:
        case True{}:
          loop(Unit{})
        case False{}:
          match m:
            case None{}:
              missing(Unit{})
            case Some{dd}:
              child(dd)

def fast.then(-K: Data, r: Result<&2, &2, Error<K>, Walk<K>>, k: List<&2, K> -> OMap.OSet(K) -> Result<&2, &2, Error<K>, Walk<K>>) -> Result<&2, &2, Error<K>, Walk<K>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{Walk{x, xi}}:
      k(x)(xi)

def fast.out(-K: Data, ds: List<&2, K>, done: List<&2, K>, di: OMap.OSet(K)) -> Result<&2, &2, Error<K>, Walk<K>>:
  match ds:
    case Nil{}:
      Done{Walk{done, di}}
    case Con{d, t}:
      Fail{Refused{}}

# go, with path, done, and the graph also held in ordered maps.
def go.fast(
  ~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, fuel: Nat, ds: List<&2, K>, +gi: OMap.OMap<K, List<&2, K>>,
  +path: List<&2, K>, +pi: OMap.OSet(K), +done: List<&2, K>, +di: OMap.OSet(K)
) -> Result<&2, &2, Error<K>, Walk<K>>:
  match fuel:
    case 0n:
      fast.out(K, ds, done, di)
    case 1n+(+f):
      match ds:
        case Nil{}:
          Done{Walk{done, di}}
        case Con{+d, +rest}:
          fast.at(K, Result<&2, &2, Error<K>, Walk<K>>,
            OMap.OSet.has(~K, ~cmp, di, d), OMap.OSet.has(~K, ~cmp, pi, d), OMap.OMap.get(~K, ~List<&2, K>, ~cmp, gi, d),
            u => go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, done, di),
            u => Fail{cycle(~K, ~eq, path, d)},
            u => Fail{Missing{d, rev(K, path, Nil{})}},
            dd => fast.then(K, go.fast(~K, ~eq, ~cmp, f, dd, gi, d <> path, OMap.OSet.add(~K, ~cmp, pi, d), done, di),
              x => xi => go.fast(~K, ~eq, ~cmp, 1n+f, rest, gi, path, pi, d <> x, OMap.OSet.add(~K, ~cmp, xi, d))))

def any_in.fast(~K: Data, ~cmp: K -> K -> Cmp, xs: List<&2, K>, +s: OMap.OSet(K)) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{+x, t}:
      Bool.or(OMap.OSet.has(~K, ~cmp, s, x), any_in.fast(~K, ~cmp, t, s))

def deps.fast(~K: Data, ~cmp: K -> K -> Cmp, +gi: OMap.OMap<K, List<&2, K>>, +x: K) -> List<&2, K>:
  Maybe.default(&2, List<&2, K>, OMap.OMap.get(~K, ~List<&2, K>, ~cmp, gi, x), Nil{})

def plan.fast.fin(-K: Data, r: Result<&2, &2, Error<K>, Walk<K>>) -> Result<&2, &2, Error<K>, List<&2, K>>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{Walk{out, oi}}:
      Done{rev(K, out, Nil{})}

# plan, in O(n log n) comparisons when cmp is a total order whose EQ agrees with eq.
# The walk is proved valid, so the check that plan runs is left out.
def plan.fast(~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, +g: List<&2, Node<K>>, +ts: List<&2, K>) -> Result<&2, &2, Error<K>, List<&2, K>>:
  plan.fast.fin(K, go.fast(~K, ~eq, ~cmp, 1n+List.length(&2, Node<K>, g), ts, gidx(~K, ~cmp, g), Nil{}, OMap.OSet.new(K), Nil{}, OMap.OSet.new(K)))

# Invalidation
# ------------

def invalidate.if(-K: Data, hit: Bool, x: K, acc: List<&2, K>) -> List<&2, K>:
  match hit:
    case True{}:
      x <> acc
    case False{}:
      acc

def invalidate.go(~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, Node<K>>, +changed: List<&2, K>, +acc: List<&2, K>) -> List<&2, K>:
  match p:
    case Nil{}:
      acc
    case Con{+x, t}:
      invalidate.go(~K, ~eq, t, g, changed,
        invalidate.if(K, Bool.or(member(~K, ~eq, changed, x), any_in(~K, ~eq, deps.or_nil(~K, ~eq, g, x), acc)), x, acc))

# The nodes of p that changed or require a stale node, latest first.
def invalidate(~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, Node<K>>, +changed: List<&2, K>) -> List<&2, K>:
  invalidate.go(~K, ~eq, p, g, changed, Nil{})

def idx.if(~K: Data, ~cmp: K -> K -> Cmp, hit: Bool, +x: K, s: OMap.OSet(K)) -> OMap.OSet(K):
  match hit:
    case True{}:
      OMap.OSet.add(~K, ~cmp, s, x)
    case False{}:
      s

def invalidate.fast.go(
  ~K: Data, ~cmp: K -> K -> Cmp, p: List<&2, K>, +gi: OMap.OMap<K, List<&2, K>>, +ci: OMap.OSet(K), +acc: List<&2, K>, +ai: OMap.OSet(K)
) -> List<&2, K>:
  match p:
    case Nil{}:
      acc
    case Con{+x, t}:
      +hit = Bool.or(OMap.OSet.has(~K, ~cmp, ci, x), any_in.fast(~K, ~cmp, deps.fast(~K, ~cmp, gi, x), ai))
      invalidate.fast.go(~K, ~cmp, t, gi, ci, invalidate.if(K, hit, x, acc), idx.if(~K, ~cmp, hit, x, ai))

# invalidate, in O(n log n) comparisons when cmp is a total order whose EQ agrees with eq.
def invalidate.fast(~K: Data, ~cmp: K -> K -> Cmp, p: List<&2, K>, +g: List<&2, Node<K>>, +changed: List<&2, K>) -> List<&2, K>:
  invalidate.fast.go(~K, ~cmp, p, gidx(~K, ~cmp, g), idx(~K, ~cmp, changed), Nil{}, OMap.OSet.new(K))

# Execution
# ---------

def status(~K: Data, ~eq: K -> K -> Bool, st: List<&2, Entry<K>>, +k: K) -> Maybe<&2, Status>:
  match st:
    case Nil{}:
      None{}
    case Con{Entry{+x, +s}, t}:
      when(Maybe<&2, Status>, u => status(~K, ~eq, t, k), eq(k, x), Some{s})

def Status.ok(s: Status) -> Bool:
  match s:
    case Built{}:
      True{}
    case Fresh{}:
      True{}
    case Failed{}:
      False{}
    case Skipped{}:
      False{}

# Built, Fresh, or Failed: the node was not skipped.
def Status.selected(s: Status) -> Bool:
  match s:
    case Skipped{}:
      False{}
    case _:
      True{}

def ok.at(m: Maybe<&2, Status>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{s}:
      Status.ok(s)

def selected.at(m: Maybe<&2, Status>) -> Bool:
  match m:
    case None{}:
      False{}
    case Some{s}:
      Status.selected(s)

# Every node of ds is Built or Fresh in st.
def ready(~K: Data, ~eq: K -> K -> Bool, ds: List<&2, K>, +st: List<&2, Entry<K>>) -> Bool:
  match ds:
    case Nil{}:
      True{}
    case Con{+d, t}:
      Bool.and(ok.at(status(~K, ~eq, st, d)), ready(~K, ~eq, t, st))

def decide.ready(go: Bool, stale: Bool) -> Action:
  match go:
    case False{}:
      Mark{Skipped{}}
    case True{}:
      match stale:
        case True{}:
          Run{}
        case False{}:
          Mark{Fresh{}}

def decide.node(~K: Data, ~eq: K -> K -> Bool, m: Maybe<&2, List<&2, K>>, stale: Bool, +st: List<&2, Entry<K>>) -> Action:
  match m:
    case None{}:
      Mark{Skipped{}}
    case Some{ds}:
      decide.ready(ready(~K, ~eq, ds, st), stale)

def decide.seen(~K: Data, ~eq: K -> K -> Bool, seen: Bool, +g: List<&2, Node<K>>, +stale: List<&2, K>, +st: List<&2, Entry<K>>, +x: K) -> Action:
  match seen:
    case True{}:
      Pass{}
    case False{}:
      decide.node(~K, ~eq, deps(~K, ~eq, g, x), member(~K, ~eq, stale, x), st)

# What to do with x: run it, mark it without a run, or pass it.
def decide(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, Node<K>>, +stale: List<&2, K>, +st: List<&2, Entry<K>>, +x: K) -> Action:
  decide.seen(~K, ~eq, Maybe.is_some(&2, Status, status(~K, ~eq, st, x)), g, stale, st, x)

def outcome(rs: List<&2, Bool>) -> Status:
  match rs:
    case Con{True{}, t}:
      Built{}
    case _:
      Failed{}

# The status that action a records; a Run takes its result from the head of rs.
def Action.status(a: Action, rs: List<&2, Bool>) -> Maybe<&2, Status>:
  match a:
    case Run{}:
      Some{outcome(rs)}
    case Mark{s}:
      Some{s}
    case Pass{}:
      None{}

def record(-K: Data, m: Maybe<&2, Status>, st: List<&2, Entry<K>>, x: K) -> List<&2, Entry<K>>:
  match m:
    case None{}:
      st
    case Some{s}:
      Entry{x, s} <> st

def step(-K: Data, a: Action, st: List<&2, Entry<K>>, x: K, rs: List<&2, Bool>) -> List<&2, Entry<K>>:
  record(K, Action.status(a, rs), st, x)

def step.rest(a: Action, rs: List<&2, Bool>) -> List<&2, Bool>:
  match a:
    case Run{}:
      List.tail(&2, Bool, rs)
    case _:
      rs

# The model of a run: rs holds the result of each command, in order. Statuses are newest first.
def exec(
  ~K: Data, ~eq: K -> K -> Bool, p: List<&2, K>, +g: List<&2, Node<K>>, +stale: List<&2, K>,
  +st: List<&2, Entry<K>>, +rs: List<&2, Bool>
) -> List<&2, Entry<K>>:
  match p:
    case Nil{}:
      st
    case Con{+x, t}:
      +a = decide(~K, ~eq, g, stale, st, x)
      exec(~K, ~eq, t, g, stale, step(K, a, st, x, rs), step.rest(a, rs))

def keys(-K: Data, st: List<&2, Entry<K>>) -> List<&2, K>:
  match st:
    case Nil{}:
      Nil{}
    case Con{Entry{x, s}, t}:
      x <> keys(K, t)

# Parallel execution
# ------------------

# a <= b.
def le(a: Nat, b: Nat) -> Bool:
  match a b:
    case 0n _:
      True{}
    case 1n+p 0n:
      False{}
    case 1n+p 1n+q:
      le(p, q)

# The statuses so far, the nodes whose commands run now, and every node started, latest first.
type Pool<-K: Data> is Data:
  Pool{st: List<&2, Entry<K>>, running: List<&2, K>, log: List<&2, K>}

# A command finished: its node, and whether it exited 0.
type Fin<-K: Data> is Data:
  Fin{node: K, ok: Bool}

type Step is Data:
  # The node has a status or is running.
  PSkip{}
  # Record this status without a run.
  PMark{status: Status}
  # Start the command.
  PStart{}
  # Wait for a running command to finish: a prerequisite runs, or every slot is busy.
  PWait{}

# xs without the nodes eq to y.
def drop(~K: Data, ~eq: K -> K -> Bool, xs: List<&2, K>, +y: K) -> List<&2, K>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+z, t}:
      invalidate.if(K, Bool.not(eq(y, z)), z, drop(~K, ~eq, t, y))

def Fin.status(ok: Bool) -> Status:
  match ok:
    case True{}:
      Built{}
    case False{}:
      Failed{}

def finish.if(-K: Data, run: Bool, +y: K, ok: Bool, st: List<&2, Entry<K>>, running: List<&2, K>, dropped: List<&2, K>, log: List<&2, K>) -> Pool<K>:
  match run:
    case True{}:
      Pool{Entry{y, Fin.status(ok)} <> st, dropped, log}
    case False{}:
      Pool{st, running, log}

# The pool after e; a finish for a node that does not run changes nothing.
def finish(~K: Data, ~eq: K -> K -> Bool, pool: Pool<K>, e: Fin<K>) -> Pool<K>:
  match pool e:
    case Pool{st, +running, log} Fin{+y, ok}:
      finish.if(K, member(~K, ~eq, running, y), y, ok, st, running, drop(~K, ~eq, running, y), log)

def decide.par.room(room: Bool) -> Step:
  match room:
    case True{}:
      PStart{}
    case False{}:
      PWait{}

def decide.par.go(go: Bool, stale: Bool, room: Bool) -> Step:
  match go:
    case False{}:
      PMark{Skipped{}}
    case True{}:
      match stale:
        case False{}:
          PMark{Fresh{}}
        case True{}:
          decide.par.room(room)

def decide.par.wait(busy: Bool, go: Bool, stale: Bool, room: Bool) -> Step:
  match busy:
    case True{}:
      PWait{}
    case False{}:
      decide.par.go(go, stale, room)

def decide.par.node(~K: Data, ~eq: K -> K -> Bool, m: Maybe<&2, List<&2, K>>, +st: List<&2, Entry<K>>, +running: List<&2, K>, stale: Bool, room: Bool) -> Step:
  match m:
    case None{}:
      PMark{Skipped{}}
    case Some{+ds}:
      decide.par.wait(any_in(~K, ~eq, ds, running), ready(~K, ~eq, ds, st), stale, room)

def decide.par.seen(~K: Data, ~eq: K -> K -> Bool, seen: Bool, +g: List<&2, Node<K>>, +stale: List<&2, K>, +limit: Nat, +st: List<&2, Entry<K>>, +running: List<&2, K>, +x: K) -> Step:
  match seen:
    case True{}:
      PSkip{}
    case False{}:
      decide.par.node(~K, ~eq, deps(~K, ~eq, g, x), st, running, member(~K, ~eq, stale, x),
        le(1n+List.length(&2, K, running), limit))

# What to do with x in a parallel run.
def decide.par(~K: Data, ~eq: K -> K -> Bool, +g: List<&2, Node<K>>, +stale: List<&2, K>, +limit: Nat, pool: Pool<K>, +x: K) -> Step:
  match pool:
    case Pool{+st, +running, log}:
      decide.par.seen(~K, ~eq, Bool.or(Maybe.is_some(&2, Status, status(~K, ~eq, st, x)), member(~K, ~eq, running, x)), g, stale, limit, st, running, x)

def apply(-K: Data, a: Step, pool: Pool<K>, +x: K) -> Pool<K>:
  match a:
    case PMark{s}:
      match pool:
        case Pool{st, running, log}:
          Pool{Entry{x, s} <> st, running, log}
    case PStart{}:
      match pool:
        case Pool{st, running, log}:
          Pool{st, x <> running, x <> log}
    case _:
      pool

def par.at(-R: Type, a: Step, wait: Unit -> R, go: Unit -> R) -> R:
  match a:
    case PWait{}:
      wait(Unit{})
    case _:
      go(Unit{})

# The model of a parallel run. Nodes start in plan order, up to limit at once; es holds the finishes, in the order they arrive.
# A node that must wait takes the next finish; the run stops when it must wait and no finish is left.
def par(
  ~K: Data, ~eq: K -> K -> Bool, es: List<&2, Fin<K>>, p: List<&2, K>, +g: List<&2, Node<K>>, +stale: List<&2, K>, +limit: Nat, +pool: Pool<K>
) -> Pool<K>:
  match es:
    case Nil{}:
      match p:
        case Nil{}:
          pool
        case Con{+x, +t}:
          +a = decide.par(~K, ~eq, g, stale, limit, pool, x)
          par.at(Pool<K>, a, u => pool, u => par(~K, ~eq, Nil{}, t, g, stale, limit, apply(K, a, pool, x)))
    case Con{+e, +r}:
      match p:
        case Nil{}:
          par(~K, ~eq, r, Nil{}, g, stale, limit, finish(~K, ~eq, pool, e))
        case Con{+x, +t}:
          +a = decide.par(~K, ~eq, g, stale, limit, pool, x)
          par.at(Pool<K>, a,
            u => par(~K, ~eq, r, x <> t, g, stale, limit, finish(~K, ~eq, pool, e)),
            u => par(~K, ~eq, e <> r, t, g, stale, limit, apply(K, a, pool, x)))

# Indexed parallel execution
# --------------------------
# The same run with the statuses, the graph, and the stale set in ordered maps under cmp.
# running stays a list: it holds at most limit nodes.

# The status of each node; the newest entry wins, as status does.
def sidx(~K: Data, ~cmp: K -> K -> Cmp, st: List<&2, Entry<K>>) -> OMap.OMap<K, Status>:
  match st:
    case Nil{}:
      OMap.OMap.new(K, Status)
    case Con{Entry{+x, +s}, t}:
      OMap.OMap.put(~K, ~Status, ~cmp, sidx(~K, ~cmp, t), x, s)

# A pool and the index of its statuses.
type FPool<-K: Data> is Data:
  FPool{pool: Pool<K>, si: OMap.OMap<K, Status>}

def lift(~K: Data, ~cmp: K -> K -> Cmp, pool: Pool<K>) -> FPool<K>:
  match pool:
    case Pool{+st, running, log}:
      FPool{Pool{st, running, log}, sidx(~K, ~cmp, st)}

def status.fast(~K: Data, ~cmp: K -> K -> Cmp, +si: OMap.OMap<K, Status>, +k: K) -> Maybe<&2, Status>:
  OMap.OMap.get(~K, ~Status, ~cmp, si, k)

def ready.fast(~K: Data, ~cmp: K -> K -> Cmp, ds: List<&2, K>, +si: OMap.OMap<K, Status>) -> Bool:
  match ds:
    case Nil{}:
      True{}
    case Con{+d, t}:
      Bool.and(ok.at(status.fast(~K, ~cmp, si, d)), ready.fast(~K, ~cmp, t, si))

def decide.par.node.fast(~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, m: Maybe<&2, List<&2, K>>, +si: OMap.OMap<K, Status>, +running: List<&2, K>, stale: Bool, room: Bool) -> Step:
  match m:
    case None{}:
      PMark{Skipped{}}
    case Some{+ds}:
      decide.par.wait(any_in(~K, ~eq, ds, running), ready.fast(~K, ~cmp, ds, si), stale, room)

def decide.par.seen.fast(
  ~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, seen: Bool, +gi: OMap.OMap<K, List<&2, K>>, +stalei: OMap.OSet(K), +limit: Nat,
  +si: OMap.OMap<K, Status>, +running: List<&2, K>, +x: K
) -> Step:
  match seen:
    case True{}:
      PSkip{}
    case False{}:
      decide.par.node.fast(~K, ~eq, ~cmp, OMap.OMap.get(~K, ~List<&2, K>, ~cmp, gi, x), si, running, OMap.OSet.has(~K, ~cmp, stalei, x),
        le(1n+List.length(&2, K, running), limit))

def decide.par.fast(~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, +gi: OMap.OMap<K, List<&2, K>>, +stalei: OMap.OSet(K), +limit: Nat, fp: FPool<K>, +x: K) -> Step:
  match fp:
    case FPool{Pool{st, +running, log}, +si}:
      decide.par.seen.fast(~K, ~eq, ~cmp, Bool.or(Maybe.is_some(&2, Status, status.fast(~K, ~cmp, si, x)), member(~K, ~eq, running, x)), gi, stalei, limit, si, running, x)

def apply.si(~K: Data, ~cmp: K -> K -> Cmp, a: Step, si: OMap.OMap<K, Status>, +x: K) -> OMap.OMap<K, Status>:
  match a:
    case PMark{s}:
      OMap.OMap.put(~K, ~Status, ~cmp, si, x, s)
    case _:
      si

def apply.fast(~K: Data, ~cmp: K -> K -> Cmp, +a: Step, fp: FPool<K>, +x: K) -> FPool<K>:
  match fp:
    case FPool{pool, si}:
      FPool{apply(K, a, pool, x), apply.si(~K, ~cmp, a, si, x)}

def finish.si(~K: Data, ~cmp: K -> K -> Cmp, run: Bool, si: OMap.OMap<K, Status>, +y: K, ok: Bool) -> OMap.OMap<K, Status>:
  match run:
    case True{}:
      OMap.OMap.put(~K, ~Status, ~cmp, si, y, Fin.status(ok))
    case False{}:
      si

def finish.fast(~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, fp: FPool<K>, e: Fin<K>) -> FPool<K>:
  match fp e:
    case FPool{Pool{st, +running, log}, si} Fin{+y, +ok}:
      +run = member(~K, ~eq, running, y)
      FPool{finish.if(K, run, y, ok, st, running, drop(~K, ~eq, running, y), log), finish.si(~K, ~cmp, run, si, y, ok)}

# par, in O(n log n) comparisons when cmp is a total order whose EQ agrees with eq.
def par.fast(
  ~K: Data, ~eq: K -> K -> Bool, ~cmp: K -> K -> Cmp, es: List<&2, Fin<K>>, p: List<&2, K>, +gi: OMap.OMap<K, List<&2, K>>,
  +stalei: OMap.OSet(K), +limit: Nat, +fp: FPool<K>
) -> FPool<K>:
  match es:
    case Nil{}:
      match p:
        case Nil{}:
          fp
        case Con{+x, +t}:
          +a = decide.par.fast(~K, ~eq, ~cmp, gi, stalei, limit, fp, x)
          par.at(FPool<K>, a, u => fp, u => par.fast(~K, ~eq, ~cmp, Nil{}, t, gi, stalei, limit, apply.fast(~K, ~cmp, a, fp, x)))
    case Con{+e, +r}:
      match p:
        case Nil{}:
          par.fast(~K, ~eq, ~cmp, r, Nil{}, gi, stalei, limit, finish.fast(~K, ~eq, ~cmp, fp, e))
        case Con{+x, +t}:
          +a = decide.par.fast(~K, ~eq, ~cmp, gi, stalei, limit, fp, x)
          par.at(FPool<K>, a,
            u => par.fast(~K, ~eq, ~cmp, r, x <> t, gi, stalei, limit, finish.fast(~K, ~eq, ~cmp, fp, e)),
            u => par.fast(~K, ~eq, ~cmp, e <> r, t, gi, stalei, limit, apply.fast(~K, ~cmp, a, fp, x)))

# Builds
# ------

# Equal strings, as the order that build indexes them by sees them.
def String.same(a: String, b: String) -> Bool:
  Cmp.is_eq(Order.string(a, b))

# A node with its command and the source files it reads.
type Task is Data:
  # argv is the command and its arguments; an empty argv is a group with no command.
  Task{id: String, deps: List<&2, String>, argv: List<&2, String>, inputs: List<&2, String>}

def Run(-A: Type) -> Type:
  IO(Result<&1, &1, U32 & String, A>)

def Run.pure(-A: Type, x: A) -> Run(A):
  IO.pure(Result<&1, &1, U32 & String, A>, Done{x})

def Run.fail(-A: Type, e: U32 & String) -> Run(A):
  IO.pure(Result<&1, &1, U32 & String, A>, Fail{e})

def Run.next(-A: Type, -B: Type, r: Result<&1, &1, U32 & String, A>, f: A -> Run(B)) -> Run(B):
  match r:
    case Done{x}:
      f(x)
    case Fail{e}:
      Run.fail(B, e)

def Run.bind(-A: Type, -B: Type, m: Run(A), f: A -> Run(B)) -> Run(B):
  IO.bind(Result<&1, &1, U32 & String, A>, Result<&1, &1, U32 & String, B>, m, r => Run.next(A, B, r, f))

def Run.lift(-A: Type, m: IO(A)) -> Run(A):
  IO.bind(A, Result<&1, &1, U32 & String, A>, m, x => Run.pure(A, x))

def Task.node(t: Task) -> Node<String>:
  match t:
    case Task{id, ds, a, i}:
      Node{id, ds}

def graph(ts: List<&2, Task>) -> List<&2, Node<String>>:
  match ts:
    case Nil{}:
      Nil{}
    case Con{t, r}:
      Task.node(t) <> graph(r)

# Each task by id; the first task with an id wins.
def tidx(ts: List<&2, Task>) -> OMap.OMap<String, Task>:
  match ts:
    case Nil{}:
      OMap.OMap.new(String, Task)
    case Con{Task{+id, ds, a, i}, r}:
      OMap.OMap.put(~String, ~Task, ~Order.string, tidx(r), id, Task{id, ds, a, i})

def task(+ti: OMap.OMap<String, Task>, +k: String) -> Maybe<&2, Task>:
  OMap.OMap.get(~String, ~Task, ~Order.string, ti, k)

def id.char(c: Char) -> Bool:
  +n = Char.to_u32(c)
  Bool.and((n >= 32 : U32), (n <= 126 : U32))

def id.chars(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{c, t}:
      Bool.and(id.char(c), id.chars(t))

# A stamp file holds one id per line, so an id is printable ASCII and not empty.
def id.ok(+s: String) -> Bool:
  Bool.and(Bool.not(String.is_empty(s)), id.chars(s))

def ids.bad(ts: List<&2, Task>) -> Maybe<&2, String>:
  match ts:
    case Nil{}:
      None{}
    case Con{Task{+id, ds, a, i}, r}:
      when(Maybe<&2, String>, u => ids.bad(r), Bool.not(id.ok(id)), Some{id})

def Error.show(e: Error<String>) -> String:
  match e:
    case Missing{n, Nil{}}:
      "missing node " ++ n
    case Missing{n, chain}:
      "missing node " ++ n ++ ", required by " ++ String.join(chain, " -> ")
    case Cycle{path}:
      "cycle: " ++ String.join(path, " -> ")
    case Refused{}:
      "the plan check refused the candidate; this is a planner bug"

def Status.show(s: Status) -> String:
  match s:
    case Built{}:
      "built"
    case Fresh{}:
      "fresh"
    case Failed{}:
      "failed"
    case Skipped{}:
      "skipped"

# Each code point in decimal, so distinct strings give distinct text.
def text(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{c, t}:
      U32.show(Char.to_u32(c)) ++ "," ++ text(t)

def texts(xs: List<&2, String>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{x, t}:
      text(x) ++ ";" ++ texts(t)

def digest.of(r: Bytes.Bytes & Hash.W64) -> String:
  match r:
    case (b, Hash.W64{hi, lo}):
      U32.show(hi) ++ "." ++ U32.show(lo)

def digest(b: Bytes.Bytes) -> String:
  digest.of(Hash.xxh64(b, Hash.W64{0, 0}))

def file.end(empty: Bool, f: File, acc: Bytes.Bytes, b: Bytes.Bytes, k: File -> Bytes.Bytes -> IO(Bytes.Bytes)) -> IO(Bytes.Bytes):
  match empty:
    case True{}:
      do IO<Bytes.Bytes>:
        File.close(f)
        return acc
    case False{}:
      k(f)(Bytes.append(acc, b))

def file.got(r: File & Result<&1, &1, U32 & String, Bytes.Bytes>, acc: Bytes.Bytes, k: File -> Bytes.Bytes -> IO(Bytes.Bytes)) -> IO(Bytes.Bytes):
  match r:
    case (f, Fail{e}):
      do IO<Bytes.Bytes>:
        File.close(f)
        return Bytes.append(acc, Bytes.from_string("unreadable"))
    case (f, Done{b}):
      Bytes.Bytes{+len, buf} = b
      file.end(U32.is_eq(len, 0), f, acc, Bytes.Bytes{len, buf}, k)

# The rest of f, read 1 MiB at a time, in at most n reads.
def file.more(n: Nat, f: File, acc: Bytes.Bytes) -> IO(Bytes.Bytes):
  match n:
    case 0n:
      do IO<Bytes.Bytes>:
        File.close(f)
        return acc
    case 1n+m:
      IO.bind(File & Result<&1, &1, U32 & String, Bytes.Bytes>, Bytes.Bytes, Files.read_bytes(f, 1048576),
        r => file.got(r, acc, g => b => file.more(m, g, b)))

def file.opened(r: Result<&1, &1, U32 & String, File>) -> IO(String):
  match r:
    case Fail{e}:
      IO.pure(String, "m")
    case Done{f}:
      IO.bind(Bytes.Bytes, String, file.more(4097n, f, Bytes.new(0)), b => IO.pure(String, "f" ++ digest(b)))

# "m" when path does not open, else "f" and the hash of its octets.
def file.stamp(path: String) -> IO(String):
  IO.bind(Result<&1, &1, U32 & String, File>, String, File.open(path, "r"), r => file.opened(r))

def inputs.stamp(xs: List<&2, String>, +dir: String, acc: String) -> IO(String):
  match xs:
    case Nil{}:
      IO.pure(String, acc)
    case Con{+x, t}:
      IO.bind(String, String, file.stamp(Files.path.join(dir, x)), s => inputs.stamp(t, dir, acc ++ text(x) ++ ":" ++ s ++ ";"))

# The hash of the command, the prerequisites, and every input file.
def Task.stamp(t: Task, +dir: String) -> IO(String):
  match t:
    case Task{id, ds, a, ins}:
      IO.bind(String, String, inputs.stamp(ins, dir, "argv:" ++ texts(a) ++ "deps:" ++ texts(ds) ++ "inputs:"),
        s => IO.pure(String, digest(Bytes.from_string(s))))

# A node and the hash of its command, prerequisites, and inputs.
type Stamp is Data:
  Stamp{node: String, hash: String}

# Each stamp by node; the first stamp of a node wins.
def stamps.idx(xs: List<&2, Stamp>) -> OMap.OMap<String, String>:
  match xs:
    case Nil{}:
      OMap.OMap.new(String, String)
    case Con{Stamp{+x, +v}, t}:
      OMap.OMap.put(~String, ~String, ~Order.string, stamps.idx(t), x, v)

def lookup(+xi: OMap.OMap<String, String>, +k: String) -> Maybe<&2, String>:
  OMap.OMap.get(~String, ~String, ~Order.string, xi, k)

def stamps.now(p: List<&2, String>, +ti: OMap.OMap<String, Task>, +dir: String, acc: List<&2, Stamp>) -> IO(List<&2, Stamp>):
  match p:
    case Nil{}:
      IO.pure(List<&2, Stamp>, acc)
    case Con{+x, t}:
      IO.bind(String, List<&2, Stamp>,
        Task.stamp(Maybe.default(&2, Task, task(ti, x), Task{x, Nil{}, Nil{}, Nil{}}), dir),
        s => stamps.now(t, ti, dir, Stamp{x, s} <> acc))

def same(a: Maybe<&2, String>, b: Maybe<&2, String>) -> Bool:
  match a b:
    case Some{x} Some{y}:
      String.eq(x, y)
    case _ _:
      False{}

# The nodes of p whose stamp now is not the recorded one.
def changed(p: List<&2, String>, +old: OMap.OMap<String, String>, +now: OMap.OMap<String, String>) -> List<&2, String>:
  match p:
    case Nil{}:
      Nil{}
    case Con{+x, t}:
      invalidate.if(String, Bool.not(same(lookup(old, x), lookup(now, x))), x, changed(t, old, now))

# The stamps of the nodes that ended Built or Fresh, and the old stamps of nodes the run did not reach.
def after.new(st: List<&2, Entry<String>>, +now: OMap.OMap<String, String>) -> List<&2, Stamp>:
  match st:
    case Nil{}:
      Nil{}
    case Con{Entry{+x, s}, t}:
      +r = after.new(t, now)
      Bool.pick(List<&2, Stamp>, Status.ok(s), Stamp{x, Maybe.default(&2, String, lookup(now, x), "")} <> r, r)

def after.keep(old: List<&2, Stamp>, +done: OMap.OMap<String, Status>) -> List<&2, Stamp>:
  match old:
    case Nil{}:
      Nil{}
    case Con{Stamp{+k, +v}, t}:
      +r = after.keep(t, done)
      Bool.pick(List<&2, Stamp>, Maybe.is_some(&2, Status, status.fast(~String, ~Order.string, done, k)), r, Stamp{k, v} <> r)

def after(+st: List<&2, Entry<String>>, +si: OMap.OMap<String, Status>, +now: OMap.OMap<String, String>, old: List<&2, Stamp>) -> List<&2, Stamp>:
  cat(Stamp, after.new(st, now), after.keep(old, si))

def stamps.line(e: Stamp) -> String:
  match e:
    case Stamp{k, v}:
      v ++ "\t" ++ k ++ "\n"

def stamps.lines(xs: List<&2, Stamp>) -> String:
  match xs:
    case Nil{}:
      ""
    case Con{e, t}:
      stamps.line(e) ++ stamps.lines(t)

def stamps.show(xs: List<&2, Stamp>) -> String:
  stamps.lines(xs)

def stamps.entry(fields: List<&2, String>) -> List<&2, Stamp>:
  match fields:
    case Con{v, Con{k, Nil{}}}:
      [Stamp{k, v}]
    case _:
      Nil{}

def stamps.parse(lines: List<&2, String>) -> List<&2, Stamp>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{l, t}:
      cat(Stamp, stamps.entry(String.split(l, '\t')), stamps.parse(t))

def stamps.got(r: File & Result<&1, &1, U32 & String, String>) -> IO(List<&2, Stamp>):
  match r:
    case (f, Fail{e}):
      do IO<List<&2, Stamp>>:
        File.close(f)
        return Nil{}
    case (f, Done{s}):
      do IO<List<&2, Stamp>>:
        File.close(f)
        return stamps.parse(String.lines(s))

def stamps.opened(r: Result<&1, &1, U32 & String, File>) -> IO(List<&2, Stamp>):
  match r:
    case Fail{e}:
      IO.pure(List<&2, Stamp>, Nil{})
    case Done{f}:
      IO.bind(File & Result<&1, &1, U32 & String, String>, List<&2, Stamp>, File.read(f, 268435456), q => stamps.got(q))

# The recorded stamps; none when the file does not open.
def stamps.read(path: String) -> IO(List<&2, Stamp>):
  IO.bind(Result<&1, &1, U32 & String, File>, List<&2, Stamp>, File.open(path, "r"), r => stamps.opened(r))

def stamps.closed(r: File & Result<&1, &1, U32 & String, Unit>) -> Run(Unit):
  match r:
    case (f, x):
      do IO<Result<&1, &1, U32 & String, Unit>>:
        File.close(f)
        return x

# Writes through path.tmp and a rename, so a reader sees the old file or the new one.
def stamps.write(+path: String, xs: List<&2, Stamp>) -> Run(Unit):
  +tmp = path ++ ".tmp"
  do Run<Unit>:
    f : File <- File.open(tmp, "w")
    r : File & Result<&1, &1, U32 & String, Unit> <- Run.lift(File & Result<&1, &1, U32 & String, Unit>, File.write(f, stamps.show(xs)))
    stamps.closed(r)
    Files.rename(tmp, path)

# What a command left: its exit code and the last 4096 octets of its stdout and stderr, or why it did not start.
type Ran is Data:
  Exited{code: U32, out: String, err: String}
  Unstarted{error: String}

type Log is Data:
  Log{node: String, ran: Ran}

# A planned node, its status, and what its command left; None when no command ran.
type Outcome is Data:
  Outcome{node: String, status: Status, ran: Maybe<&2, Ran>}

def Ran.ok(r: Ran) -> Bool:
  match r:
    case Exited{code, o, e}:
      U32.is_eq(code, 0)
    case Unstarted{e}:
      False{}

def tail.of(r: Bytes.Bytes & Bytes.Bytes) -> String:
  match r:
    case (b, t):
      Bytes.to_string(t)

# The last 4096 octets of b, one Char per octet.
def tail(b: Bytes.Bytes) -> String:
  Bytes.Bytes{+len, buf} = b
  +n = U32.min(len, 4096)
  tail.of(Bytes.slice(Bytes.Bytes{len, buf}, (len - n : U32), n))

def run.ran(r: Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>) -> Ran:
  match r:
    case Fail{(code, msg)}:
      Unstarted{msg}
    case Done{(code, (out, err))}:
      Exited{code, tail(out), tail(err)}

# Runs argv in dir; None for a group with no command.
def run.argv(argv: List<&2, String>, dir: String) -> IO(Maybe<&2, Ran>):
  match argv:
    case Nil{}:
      IO.pure(Maybe<&2, Ran>, None{})
    case Con{cmd, args}:
      IO.bind(Result<&1, &1, U32 & String, U32 & Bytes.Bytes & Bytes.Bytes>, Maybe<&2, Ran>, Proc.run(cmd, args, Nil{}, dir, Bytes.new(0)),
        r => IO.pure(Maybe<&2, Ran>, Some{run.ran(r)}))

def run.task(dir: String, m: Maybe<&2, Task>) -> IO(Maybe<&2, Ran>):
  match m:
    case None{}:
      IO.pure(Maybe<&2, Ran>, Some{Unstarted{"undefined task"}})
    case Some{Task{id, ds, argv, ins}}:
      run.argv(argv, dir)

# A group succeeds; a command succeeds when it exits 0.
def run.ok(m: Maybe<&2, Ran>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{r}:
      Ran.ok(r)

def run.log(+x: String, m: Maybe<&2, Ran>, logs: List<&2, Log>) -> List<&2, Log>:
  match m:
    case None{}:
      logs
    case Some{r}:
      Log{x, r} <> logs

# A finished command, as its job reports it.
type Msg is Data:
  Msg{node: String, ran: Maybe<&2, Ran>}

type Ledger is Data:
  Ledger{pool: FPool<String>, logs: List<&2, Log>}

def run.job(dir: String, m: Maybe<&2, Task>, +x: String, chan: Chan(Msg)) -> IO(Unit):
  do IO<Unit>:
    r : Maybe<&2, Ran> <- run.task(dir, m)
    s : Result<&1, &1, Msg, Unit> <- Chan.send(Msg, chan, Msg{x, r})
    return Unit{}

def run.msg(m: Maybe<&1, Msg>, +pool: FPool<String>, +logs: List<&2, Log>, k: FPool<String> -> List<&2, Log> -> IO(Ledger)) -> IO(Ledger):
  match m:
    case None{}:
      IO.pure(Ledger, Ledger{pool, logs})
    case Some{Msg{+y, +r}}:
      k(finish.fast(~String, ~String.same, ~Order.string, pool, Fin{y, run.ok(r)}), run.log(y, r, logs))

# Takes the next finished command, then goes on with k.
def run.recv(+chan: Chan(Msg), +pool: FPool<String>, +logs: List<&2, Log>, k: FPool<String> -> List<&2, Log> -> IO(Ledger)) -> IO(Ledger):
  IO.bind(Maybe<&1, Msg>, Ledger, Chan.recv(Msg, chan), m => run.msg(m, pool, logs, k))

# Waits for n running commands.
def run.drain(n: Nat, +pool: FPool<String>, +logs: List<&2, Log>, +chan: Chan(Msg)) -> IO(Ledger):
  match n:
    case 0n:
      IO.pure(Ledger, Ledger{pool, logs})
    case 1n+m:
      run.recv(chan, pool, logs, q => l => run.drain(m, q, l, chan))

def Pool.busy(pool: FPool<String>) -> Nat:
  match pool:
    case FPool{Pool{st, running, log}, si}:
      List.length(&2, String, running)

def par.case(-R: Type, a: Step, wait: Unit -> R, start: Unit -> R, other: Unit -> R) -> R:
  match a:
    case PWait{}:
      wait(Unit{})
    case PStart{}:
      start(Unit{})
    case _:
      other(Unit{})

# par, with each finish from a running job. Each wait finishes a node started earlier, so n = 1 + |p| is enough.
def run.par(
  n: Nat, p: List<&2, String>, +ti: OMap.OMap<String, Task>, +gi: OMap.OMap<String, List<&2, String>>, +stale: OMap.OSet(String), +limit: Nat,
  +pool: FPool<String>, +logs: List<&2, Log>, +dir: String, +chan: Chan(Msg)
) -> IO(Ledger):
  match n:
    case 0n:
      run.drain(Pool.busy(pool), pool, logs, chan)
    case 1n+(+m):
      match p:
        case Nil{}:
          run.drain(Pool.busy(pool), pool, logs, chan)
        case Con{+x, +t}:
          +a = decide.par.fast(~String, ~String.same, ~Order.string, gi, stale, limit, pool, x)
          par.case(IO(Ledger), a,
            u => run.recv(chan, pool, logs, q => l => run.par(m, x <> t, ti, gi, stale, limit, q, l, dir, chan)),
            u => IO.bind(Unit, Ledger, IO.spawn(Unit, run.job(dir, task(ti, x), x, chan)),
              v => run.par(1n+m, t, ti, gi, stale, limit, apply.fast(~String, ~Order.string, PStart{}, pool, x), logs, dir, chan)),
            u => run.par(1n+m, t, ti, gi, stale, limit, apply.fast(~String, ~Order.string, a, pool, x), logs, dir, chan))

# What each node's command left; the newest log of a node wins.
def ran.idx(logs: List<&2, Log>) -> OMap.OMap<String, Ran>:
  match logs:
    case Nil{}:
      OMap.OMap.new(String, Ran)
    case Con{Log{+x, +r}, t}:
      OMap.OMap.put(~String, ~Ran, ~Order.string, ran.idx(t), x, r)

def outcome.of(m: Maybe<&2, Status>, +x: String, r: Maybe<&2, Ran>, rest: List<&2, Outcome>) -> List<&2, Outcome>:
  match m:
    case None{}:
      rest
    case Some{s}:
      Outcome{x, s, r} <> rest

# Each node of p that has a status, in plan order.
def outcomes(p: List<&2, String>, +si: OMap.OMap<String, Status>, +ri: OMap.OMap<String, Ran>) -> List<&2, Outcome>:
  match p:
    case Nil{}:
      Nil{}
    case Con{+x, t}:
      outcome.of(status.fast(~String, ~Order.string, si, x), x, OMap.OMap.get(~String, ~Ran, ~Order.string, ri, x), outcomes(t, si, ri))

def build.ids(m: Maybe<&2, String>) -> Run(Unit):
  match m:
    case None{}:
      Run.pure(Unit, Unit{})
    case Some{id}:
      Run.fail(Unit, (22, "task id is empty or not printable ASCII: " ++ text(id)))

def build.plan(r: Result<&2, &2, Error<String>, List<&2, String>>) -> Run(List<&2, String>):
  match r:
    case Fail{e}:
      Run.fail(List<&2, String>, (22, Error.show(e)))
    case Done{p}:
      Run.pure(List<&2, String>, p)

def build.done(+path: String, p: List<&2, String>, +now: OMap.OMap<String, String>, old: List<&2, Stamp>, l: Ledger) -> Run(List<&2, Outcome>):
  match l:
    case Ledger{FPool{Pool{st, running, log}, +si}, logs}:
      do Run<List<&2, Outcome>>:
        stamps.write(path, after(st, si, now, old))
        return outcomes(p, si, ran.idx(logs))

# Plans targets, runs each stale task in dir, up to jobs at once, reuses the rest, and records stamps in path.
# The result is each planned node with its status and command output, in plan order.
def build(+tasks: List<&2, Task>, +targets: List<&2, String>, +dir: String, +path: String, +jobs: U32) -> Run(List<&2, Outcome>):
  +g = graph(tasks)
  +ti = tidx(tasks)
  +limit = U32.to_nat(U32.max(jobs, 1))
  do Run<List<&2, Outcome>>:
    build.ids(ids.bad(tasks))
    +p : List<&2, String> <- build.plan(plan.fast(~String, ~String.same, ~Order.string, g, targets))
    +old : List<&2, Stamp> <- Run.lift(List<&2, Stamp>, stamps.read(path))
    now : List<&2, Stamp> <- Run.lift(List<&2, Stamp>, stamps.now(p, ti, dir, Nil{}))
    +ni : OMap.OMap<String, String> = stamps.idx(now)
    +stale : List<&2, String> = invalidate.fast(~String, ~Order.string, p, g, changed(p, stamps.idx(old), ni))
    +chan : Chan(Msg) <- Run.lift(Chan(Msg), Chan.new(Msg, U32.max(jobs, 1)))
    l : Ledger <- Run.lift(Ledger, run.par(1n+List.length(&2, String, p), p, ti, gidx(~String, ~Order.string, g), idx(~String, ~Order.string, stale), limit,
      FPool{Pool{Nil{}, Nil{}, Nil{}}, OMap.OMap.new(String, Status)}, Nil{}, dir, chan))
    build.done(path, p, ni, old, l)
