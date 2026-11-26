# Text utilities: Myers diff with unified output, Levenshtein distance, and word wrap by display width.
import Base
import bend-kit-unicode@0.1.0.0/unicode.bend as Unicode
import bend-kit-tty@0.1.0.1/text.bend as Tty
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes

# ---- edit scripts

# Same pairs an old item with the new item it matched; before keeps old items, after keeps new ones.
type Edit<-A: Data> is Data:
  Same{old: A, new: A}
  Del{old: A}
  Ins{new: A}

type Move is Data:
  MSame{}
  MDel{}
  MIns{}

def before(-A: Data, es: List<&2, Edit<A>>) -> List<&2, A>:
  match es:
    case Nil{}:
      Nil{}
    case Con{Same{o, n}, t}:
      o <> before(A, t)
    case Con{Del{o}, t}:
      o <> before(A, t)
    case Con{Ins{n}, t}:
      before(A, t)

def after(-A: Data, es: List<&2, Edit<A>>) -> List<&2, A>:
  match es:
    case Nil{}:
      Nil{}
    case Con{Same{o, n}, t}:
      n <> after(A, t)
    case Con{Del{o}, t}:
      after(A, t)
    case Con{Ins{n}, t}:
      n <> after(A, t)

def walk.ins(-A: Data, b: List<&2, A>) -> List<&2, Edit<A>>:
  match b:
    case Nil{}:
      Nil{}
    case Con{y, t}:
      Ins{y} <> walk.ins(A, t)

def walk.rest(-A: Data, a: List<&2, A>, b: List<&2, A>) -> List<&2, Edit<A>>:
  match a:
    case Nil{}:
      walk.ins(A, b)
    case Con{x, t}:
      Del{x} <> walk.rest(A, t, b)

# Replays moves over a and b. A move that does not fit is skipped, and leftovers become Del then Ins,
# so before and after give a and b back for any moves.
def walk(-A: Data, ms: List<&2, Move>, a: List<&2, A>, b: List<&2, A>) -> List<&2, Edit<A>>:
  match ms a b:
    case Nil{} _ _:
      walk.rest(A, a, b)
    case Con{MSame{}, t} Con{x, xs} Con{y, ys}:
      Same{x, y} <> walk(A, t, xs, ys)
    case Con{MDel{}, t} Con{x, xs} _:
      Del{x} <> walk(A, t, xs, b)
    case Con{MIns{}, t} _ Con{y, ys}:
      Ins{y} <> walk(A, t, a, ys)
    case Con{_, t} _ _:
      walk(A, t, a, b)

# ---- Myers O(ND) diff in linear space, over arrays

# The items, and the forward and reverse frontiers: v[off + k] is the furthest x on diagonal k = x - y.
type Ctx<-A: Data> is Type:
  Ctx{a: Array<A>, b: Array<A>, vf: Array<U32>, vb: Array<U32>}

# A segment of n items of a from os, and m items of b from ns. off centres the frontiers.
type Geo is Data:
  Geo{os: U32, ns: U32, n: U32, m: U32, off: U32}

type Pt is Data:
  Pt{x: U32, y: U32}

def geo.os(+g: Geo) -> U32:
  match g:
    case Geo{os, _, _, _, _}:
      os

def geo.ns(+g: Geo) -> U32:
  match g:
    case Geo{_, ns, _, _, _}:
      ns

def geo.n(+g: Geo) -> U32:
  match g:
    case Geo{_, _, n, _, _}:
      n

def geo.m(+g: Geo) -> U32:
  match g:
    case Geo{_, _, _, m, _}:
      m

def geo.off(+g: Geo) -> U32:
  match g:
    case Geo{_, _, _, _, off}:
      off

def same.b(~A: Data, ~eq: A -> A -> Bool, x: A, a: Array<A>, r: Array<A> & A) -> Array<A> & Array<A> & Bool:
  (b, y) = r
  (a, b, eq(x, y))

def same.a(~A: Data, ~eq: A -> A -> Bool, r: Array<A> & A, b: Array<A>, +j: U32) -> Array<A> & Array<A> & Bool:
  (a, x) = r
  same.b(~A, ~eq, x, a, Array.get(A, b, j))

def probe.in(~A: Data, ~eq: A -> A -> Bool, inr: Bool, a: Array<A>, b: Array<A>, +rev: Bool, +g: Geo, +x: U32, +y: U32) -> Array<A> & Array<A> & Bool:
  match inr:
    case True{}:
      i = Bool.pick(U32, rev, (geo.os(g) + geo.n(g) - 1 - x : U32), (geo.os(g) + x : U32))
      j = Bool.pick(U32, rev, (geo.ns(g) + geo.m(g) - 1 - y : U32), (geo.ns(g) + y : U32))
      same.a(~A, ~eq, Array.get(A, a, i), b, j)
    case False{}:
      (a, b, False{})

# Whether item x of the segment of a matches item y of the segment of b. rev counts from the segment end.
def probe(~A: Data, ~eq: A -> A -> Bool, a: Array<A>, b: Array<A>, +rev: Bool, +g: Geo, +x: U32, +y: U32) -> Array<A> & Array<A> & Bool:
  probe.in(~A, ~eq, Bool.and(U32.is_lt(x, geo.n(g)), U32.is_lt(y, geo.m(g))), a, b, rev, g, x, y)

def snake(~A: Data, ~eq: A -> A -> Bool, fuel: Nat, r: Array<A> & Array<A> & Bool, +rev: Bool, +g: Geo, +x: U32, +y: U32) -> Array<A> & Array<A> & U32:
  match fuel:
    case 0n:
      (a, b, _) = r
      (a, b, x)
    case 1n+p:
      (a, b, ok) = r
      match ok:
        case True{}:
          snake(~A, ~eq, p, probe(~A, ~eq, a, b, rev, g, (x + 1 : U32), (y + 1 : U32)), rev, g, (x + 1 : U32), (y + 1 : U32))
        case False{}:
          (a, b, x)

# The x where the run of matches from (x, y) ends.
def slide(~A: Data, ~eq: A -> A -> Bool, a: Array<A>, b: Array<A>, +rev: Bool, +g: Geo, +x: U32, +y: U32) -> Array<A> & Array<A> & U32:
  snake(~A, ~eq, U32.to_nat(geo.n(g)), probe(~A, ~eq, a, b, rev, g, x, y), rev, g, x, y)

# v is the frontier that moves, w the other one.
def ctx.mk(~A: Data, rev: Bool, a: Array<A>, b: Array<A>, v: Array<U32>, w: Array<U32>) -> Ctx<A>:
  match rev:
    case True{}:
      Ctx{a, b, w, v}
    case False{}:
      Ctx{a, b, v, w}

def at.point(rev: Bool, +g: Geo, +k: U32, +x: U32, +x0: U32) -> Maybe<&2, Pt>:
  match rev:
    case True{}:
      Some{Pt{(geo.os(g) + geo.n(g) - x : U32), (geo.ns(g) + geo.m(g) - x + k : U32)}}
    case False{}:
      Some{Pt{(geo.os(g) + x0 : U32), (geo.ns(g) + x0 - k : U32)}}

def at.overlap(hit: Bool, rev: Bool, g: Geo, k: U32, x: U32, x0: U32) -> Maybe<&2, Pt>:
  match hit:
    case True{}:
      at.point(rev, g, k, x, x0)
    case False{}:
      None{}

def at.hit(~A: Data, r: Array<U32> & U32, a: Array<A>, b: Array<A>, v: Array<U32>, +rev: Bool, +g: Geo, +k: U32, +x: U32, +x0: U32) -> Ctx<A> & Maybe<&2, Pt>:
  (w, u) = r
  (ctx.mk(~A, rev, a, b, v, w), at.overlap(U32.is_le(geo.n(g), (x + u : U32)), rev, g, k, x, x0))

def at.chk(~A: Data, on: Bool, a: Array<A>, b: Array<A>, v: Array<U32>, w: Array<U32>, +rev: Bool, +g: Geo, +k: U32, +x: U32, +x0: U32) -> Ctx<A> & Maybe<&2, Pt>:
  match on:
    case True{}:
      at.hit(~A, Array.get(U32, w, (geo.off(g) + geo.n(g) - geo.m(g) - k : U32)), a, b, v, rev, g, k, x, x0)
    case False{}:
      (ctx.mk(~A, rev, a, b, v, w), None{})

# Myers' overlap test: forward d-paths meet reverse (d-1)-paths when n - m is odd, reverse d-paths when even.
def at.snk(~A: Data, r: Array<A> & Array<A> & U32, v: Array<U32>, w: Array<U32>, +rev: Bool, +g: Geo, +d: U32, +k: U32, +x0: U32) -> Ctx<A> & Maybe<&2, Pt>:
  (a, bx) = r
  (b, x1) = bx
  +x = {x1 : U32}
  +dl = (geo.n(g) - geo.m(g) : U32)
  +odd = U32.is_eq((dl .&. 1 : U32), 1)
  fwd = Bool.and(Bool.and(odd, U32.is_ne(d, 0)), U32.is_le((k - dl + d - 1 : U32), (d + d - 2 : U32)))
  bwd = Bool.and(Bool.not(odd), U32.is_le((k - dl + d : U32), (d + d : U32)))
  at.chk(~A, Bool.pick(Bool, rev, bwd, fwd), a, b, Array.set(U32, v, (geo.off(g) + k : U32), x), w, rev, g, k, x, x0)

# Myers' rule for diagonal k: go down from k+1 when V[k-1] < V[k+1], else right from k-1.
def at.hi(~A: Data, ~eq: A -> A -> Bool, r: Array<U32> & U32, +lo: U32, a: Array<A>, b: Array<A>, w: Array<U32>, +rev: Bool, +g: Geo, +d: U32, +k: U32) -> Ctx<A> & Maybe<&2, Pt>:
  (v, +hi) = r
  down = Bool.or(U32.is_eq(k, (0 - d : U32)), Bool.and(U32.is_ne(k, d), U32.is_lt(lo, hi)))
  +x0 = Bool.pick(U32, down, hi, (lo + 1 : U32))
  at.snk(~A, slide(~A, ~eq, a, b, rev, g, x0, (x0 - k : U32)), v, w, rev, g, d, k, x0)

def at.lo(~A: Data, ~eq: A -> A -> Bool, r: Array<U32> & U32, a: Array<A>, b: Array<A>, w: Array<U32>, +rev: Bool, +g: Geo, +d: U32, +k: U32) -> Ctx<A> & Maybe<&2, Pt>:
  (v, lo) = r
  at.hi(~A, ~eq, Array.get(U32, v, (geo.off(g) + k + 1 : U32)), lo, a, b, w, rev, g, d, k)

# One diagonal of one sweep.
def at(~A: Data, ~eq: A -> A -> Bool, rev: Bool, c: Ctx<A>, +g: Geo, +d: U32, +k: U32) -> Ctx<A> & Maybe<&2, Pt>:
  match rev c:
    case True{} Ctx{a, b, vf, vb}:
      at.lo(~A, ~eq, Array.get(U32, vb, (geo.off(g) + k - 1 : U32)), a, b, vf, True{}, g, d, k)
    case False{} Ctx{a, b, vf, vb}:
      at.lo(~A, ~eq, Array.get(U32, vf, (geo.off(g) + k - 1 : U32)), a, b, vb, False{}, g, d, k)

# Diagonals k, k + 2, ... until fuel runs out or a sweep meets the other frontier.
def sweep(~A: Data, ~eq: A -> A -> Bool, fuel: Nat, r: Ctx<A> & Maybe<&2, Pt>, +rev: Bool, +g: Geo, +d: U32, +k: U32) -> Ctx<A> & Maybe<&2, Pt>:
  match fuel:
    case 0n:
      (c, s) = r
      (c, s)
    case 1n+p:
      (c, s) = r
      match s:
        case None{}:
          sweep(~A, ~eq, p, at(~A, ~eq, rev, c, g, d, k), rev, g, d, (k + 2 : U32))
        case Some{q}:
          (c, Some{q})

def round.back(~A: Data, ~eq: A -> A -> Bool, r: Ctx<A> & Maybe<&2, Pt>, +g: Geo, +d: U32) -> Ctx<A> & Maybe<&2, Pt>:
  (c, s) = r
  match s:
    case None{}:
      sweep(~A, ~eq, U32.to_nat((d + 1 : U32)), (c, None{}), True{}, g, d, (0 - d : U32))
    case Some{q}:
      (c, Some{q})

def round(~A: Data, ~eq: A -> A -> Bool, c: Ctx<A>, +g: Geo, +d: U32) -> Ctx<A> & Maybe<&2, Pt>:
  round.back(~A, ~eq, sweep(~A, ~eq, U32.to_nat((d + 1 : U32)), (c, None{}), False{}, g, d, (0 - d : U32)), g, d)

def middle.go(~A: Data, ~eq: A -> A -> Bool, fuel: Nat, r: Ctx<A> & Maybe<&2, Pt>, +g: Geo, +d: U32) -> Ctx<A> & Maybe<&2, Pt>:
  match fuel:
    case 0n:
      (c, s) = r
      (c, s)
    case 1n+p:
      (c, s) = r
      match s:
        case None{}:
          middle.go(~A, ~eq, p, round(~A, ~eq, c, g, d), g, (d + 1 : U32))
        case Some{q}:
          (c, Some{q})

# Myers' middle snake: grow d-paths from both ends of the segment until they meet. The meeting point is on a shortest path.
def middle(~A: Data, ~eq: A -> A -> Bool, c: Ctx<A>, +g: Geo) -> Ctx<A> & Maybe<&2, Pt>:
  match c:
    case Ctx{a, b, vf, vb}:
      vf = Array.set(U32, vf, (geo.off(g) + 1 : U32), 0)
      vb = Array.set(U32, vb, (geo.off(g) + 1 : U32), 0)
      middle.go(~A, ~eq, U32.to_nat((geo.n(g) + geo.m(g) + 1 : U32)), (Ctx{a, b, vf, vb}, None{}), g, 0)

# A segment still to diff, or moves ready to emit.
type Job is Data:
  JSolve{os: U32, oe: U32, ns: U32, ne: U32}
  JEmit{ms: List<&2, Move>}

def changes(+dels: U32, +ins: U32) -> List<&2, Move>:
  List.append(&2, Move, List.replicate(Move, U32.to_nat(dels), MDel{}), List.replicate(Move, U32.to_nat(ins), MIns{}))

def plan.split(~A: Data, r: Ctx<A> & Maybe<&2, Pt>, +os: U32, +oe: U32, +ns: U32, +ne: U32) -> Ctx<A> & List<&2, Job>:
  (c, s) = r
  match s:
    case Some{Pt{+x, +y}}:
      (c, [JSolve{x, oe, y, ne}, JSolve{os, x, ns, y}])
    case None{}:
      (c, [JEmit{changes((oe - os : U32), (ne - ns : U32))}])

def plan.mid(~A: Data, ~eq: A -> A -> Bool, ea: Bool, eb: Bool, c: Ctx<A>, +os: U32, +oe: U32, +ns: U32, +ne: U32, +off: U32) -> Ctx<A> & List<&2, Job>:
  match ea eb:
    case True{} _:
      (c, [JEmit{changes(0, (ne - ns : U32))}])
    case _ True{}:
      (c, [JEmit{changes((oe - os : U32), 0)}])
    case _ _:
      plan.split(~A, middle(~A, ~eq, c, Geo{os, ns, (oe - os : U32), (ne - ns : U32), off}), os, oe, ns, ne)

def plan.wrap(~A: Data, r: Ctx<A> & List<&2, Job>, +p: U32, +s: U32) -> Ctx<A> & List<&2, Job>:
  (c, js) = r
  same = {[JEmit{List.replicate(Move, U32.to_nat(p), MSame{})}] : List<&2, Job>}
  (c, JEmit{List.replicate(Move, U32.to_nat(s), MSame{})} <> List.append(&2, Job, js, same))

def plan.suf(~A: Data, ~eq: A -> A -> Bool, r: Array<A> & Array<A> & U32, vf: Array<U32>, vb: Array<U32>, +p: U32, +os: U32, +oe: U32, +ns: U32, +ne: U32, +off: U32) -> Ctx<A> & List<&2, Job>:
  (a, b, s1) = r
  +s = {s1 : U32}
  +os2 = (os + p : U32)
  +oe2 = (oe - s : U32)
  +ns2 = (ns + p : U32)
  +ne2 = (ne - s : U32)
  plan.wrap(~A, plan.mid(~A, ~eq, U32.is_eq(os2, oe2), U32.is_eq(ns2, ne2), Ctx{a, b, vf, vb}, os2, oe2, ns2, ne2, off), p, s)

def plan.pre(~A: Data, ~eq: A -> A -> Bool, r: Array<A> & Array<A> & U32, vf: Array<U32>, vb: Array<U32>, +os: U32, +oe: U32, +ns: U32, +ne: U32, +off: U32) -> Ctx<A> & List<&2, Job>:
  (a, b, p1) = r
  +p = {p1 : U32}
  +g : Geo = Geo{(os + p : U32), (ns + p : U32), (oe - os - p : U32), (ne - ns - p : U32), off}
  plan.suf(~A, ~eq, slide(~A, ~eq, a, b, True{}, g, 0, 0), vf, vb, p, os, oe, ns, ne, off)

# Jobs for one segment, last first: the common suffix, the middle, then the common prefix.
def plan(~A: Data, ~eq: A -> A -> Bool, c: Ctx<A>, +os: U32, +oe: U32, +ns: U32, +ne: U32, +off: U32) -> Ctx<A> & List<&2, Job>:
  match c:
    case Ctx{a, b, vf, vb}:
      plan.pre(~A, ~eq, slide(~A, ~eq, a, b, False{}, Geo{os, ns, (oe - os : U32), (ne - ns : U32), off}, 0, 0), vf, vb, os, oe, ns, ne, off)

def plan.then(~A: Data, r: Ctx<A> & List<&2, Job>, t: List<&2, Job>) -> Ctx<A> & List<&2, Job>:
  (c, js) = r
  (c, List.append(&2, Job, js, t))

# Runs jobs from the end of the script back to its start, so each emit prepends.
def solve(~A: Data, ~eq: A -> A -> Bool, fuel: Nat, r: Ctx<A> & List<&2, Job>, +off: U32, acc: List<&2, Move>) -> List<&2, Move>:
  match fuel:
    case 0n:
      (_, _) = r
      acc
    case 1n+f:
      (c, js) = r
      match js:
        case Con{JSolve{os, oe, ns, ne}, t}:
          solve(~A, ~eq, f, plan.then(~A, plan(~A, ~eq, c, os, oe, ns, ne, off), t), off, acc)
        case Con{JEmit{ms}, t}:
          solve(~A, ~eq, f, (c, t), off, List.append(&2, Move, ms, acc))
        case Nil{}:
          acc

def canon.flush(d: Nat, i: Nat, rest: List<&2, Move>) -> List<&2, Move>:
  List.append(&2, Move, List.replicate(Move, d, MDel{}), List.append(&2, Move, List.replicate(Move, i, MIns{}), rest))

# Each run of changes puts its deletes first, as diff does.
def canon(ms: List<&2, Move>, +d: Nat, +i: Nat) -> List<&2, Move>:
  match ms:
    case Nil{}:
      canon.flush(d, i, Nil{})
    case Con{MSame{}, t}:
      canon.flush(d, i, MSame{} <> canon(t, 0n, 0n))
    case Con{MDel{}, t}:
      canon(t, 1n+d, i)
    case Con{MIns{}, t}:
      canon(t, d, 1n+i)

def fill(~A: Data, xs: List<&2, A>, arr: Array<A>, +i: U32) -> Array<A>:
  match xs:
    case Nil{}:
      arr
    case Con{x, t}:
      fill(~A, t, Array.set(A, arr, i, x), (i + 1 : U32))

# An array of n slots or more.
def array(~A: Data, +n: U32, +v: A) -> Array<A>:
  Array.new(A, Nat.add(U32.log2(n), 1n), v)

# Each split leaves two smaller segments, and each segment plans at most 4 jobs.
def moves.go(~A: Data, ~eq: A -> A -> Bool, +x: A, +y: A, +a: List<&2, A>, +b: List<&2, A>) -> List<&2, Move>:
  +n = U32.from_nat(List.length(&2, A, a))
  +m = U32.from_nat(List.length(&2, A, b))
  +off = (n + m + 2 : U32)
  c : Ctx<A> = Ctx{fill(~A, a, array(~A, n, x), 0), fill(~A, b, array(~A, m, y), 0), array(~U32, (off + off : U32), 0), array(~U32, (off + off : U32), 0)}
  +size = Nat.add(List.length(&2, A, a), List.length(&2, A, b))
  canon(solve(~A, ~eq, Nat.add(Nat.mul(8n, size), 8n), (c, [JSolve{0, n, 0, m}]), off, Nil{}), 0n, 0n)

def moves(~A: Data, ~eq: A -> A -> Bool, +a: List<&2, A>, +b: List<&2, A>) -> List<&2, Move>:
  match a b:
    case Con{+x, +xs} Con{+y, +ys}:
      moves.go(~A, ~eq, x, y, x <> xs, y <> ys)
    case Nil{} Con{+y, +ys}:
      List.replicate(Move, List.length(&2, A, y <> ys), MIns{})
    case Con{+x, +xs} Nil{}:
      List.replicate(Move, List.length(&2, A, x <> xs), MDel{})
    case Nil{} Nil{}:
      Nil{}

# A shortest edit script from a to b. eq decides which items match.
def diff(~A: Data, ~eq: A -> A -> Bool, +a: List<&2, A>, +b: List<&2, A>) -> List<&2, Edit<A>>:
  walk(A, moves(~A, ~eq, a, b), a, b)

def keys(~A: Data, ~key: A -> U32, xs: List<&2, A>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      key(x) <> keys(~A, ~key, t)

# Whether every pair that walk would match is equal by eq.
def paired(~A: Data, ~eq: A -> A -> Bool, ms: List<&2, Move>, a: List<&2, A>, b: List<&2, A>) -> Bool:
  match ms a b:
    case Nil{} _ _:
      True{}
    case Con{MSame{}, t} Con{x, xs} Con{y, ys}:
      Bool.and(eq(x, y), paired(~A, ~eq, t, xs, ys))
    case Con{MDel{}, t} Con{_, xs} _:
      paired(~A, ~eq, t, xs, b)
    case Con{MIns{}, t} _ Con{_, ys}:
      paired(~A, ~eq, t, a, ys)
    case Con{_, t} _ _:
      paired(~A, ~eq, t, a, b)

def moves_by.pick(~A: Data, ~eq: A -> A -> Bool, ok: Bool, ms: List<&2, Move>, +a: List<&2, A>, +b: List<&2, A>) -> List<&2, Move>:
  match ok:
    case True{}:
      ms
    case False{}:
      moves(~A, ~eq, a, b)

# Diffs the keys, then checks each matched pair with eq. If two unequal items share a key and get matched, it diffs the items instead.
def moves_by(~A: Data, ~eq: A -> A -> Bool, ~key: A -> U32, +a: List<&2, A>, +b: List<&2, A>) -> List<&2, Move>:
  +ms = moves(~U32, ~U32.is_eq, keys(~A, ~key, a), keys(~A, ~key, b))
  moves_by.pick(~A, ~eq, paired(~A, ~eq, ms, a, b), ms, a, b)

# diff, but Myers compares U32 keys, which is much faster than comparing items such as strings.
# Equal items must have equal keys. The script is the same length as diff's.
def diff_by(~A: Data, ~eq: A -> A -> Bool, ~key: A -> U32, +a: List<&2, A>, +b: List<&2, A>) -> List<&2, Edit<A>>:
  walk(A, moves_by(~A, ~eq, ~key, a, b), a, b)

def lines.push(c: Char, ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case Nil{}:
      [SCon{c, SNil{}}]
    case Con{h, t}:
      SCon{c, h} <> t

def lines.pick(nl: Bool, c: Char, ls: List<&2, String>) -> List<&2, String>:
  match nl:
    case True{}:
      SCon{c, SNil{}} <> ls
    case False{}:
      lines.push(c, ls)

# Lines with their "\n". Only the last line can lack one, and joining the lines gives s back.
def lines(s: String) -> List<&2, String>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{+c, t}:
      lines.pick(Char.is_eq(c, '\n'), c, lines(t))

# 32-bit FNV-1a, a key for diff_by.
def fnv.go(s: String, +h: U32) -> U32:
  match s:
    case SNil{}:
      h
    case SCon{Chr{c}, t}:
      fnv.go(t, (U32.xor(h, c) * 16777619 : U32))

def fnv(s: String) -> U32:
  fnv.go(s, 2166136261)

def diff_lines(a: String, b: String) -> List<&2, Edit<String>>:
  diff_by(~String, ~String.eq, ~fnv, lines(a), lines(b))

def diff_chars(a: String, b: String) -> List<&2, Edit<Char>>:
  diff(~Char, ~Char.is_eq, String.to_list(a), String.to_list(b))

# ---- packed-input line diff

type ByteRange is Data:
  ByteRange{offset: U32, length: U32, key: U32}

def byte_range.key(r: ByteRange) -> U32:
  match r:
    case ByteRange{_, _, k}:
      k

def byte_lines.finish(last: Bool, +start: U32, +end: U32, h: U32, out: List<&2, ByteRange>) -> List<&2, ByteRange>:
  match last:
    case True{}:
      List.reverse(&2, ByteRange, ByteRange{start, (end - start : U32), h} <> out)
    case False{}:
      List.reverse(&2, ByteRange, out)

def byte_lines.step(nl: Bool, +start: U32, +end: U32, +h: U32, out: List<&2, ByteRange>) -> U32 & U32 & List<&2, ByteRange>:
  match nl:
    case True{}:
      (end, 2166136261, ByteRange{start, (end - start : U32), h} <> out)
    case False{}:
      (start, h, out)


def byte_lines.go(f: Nat, r: Array<U32> & U32, +i: U32, st: U32 & U32 & List<&2, ByteRange>) -> Array<U32> & List<&2, ByteRange>:
  match f:
    case 0n:
      (a, _) = r
      (+start, h, out) = st
      (a, byte_lines.finish(U32.is_lt(start, i), start, i, h, out))
    case 1n+p:
      (a, +v) = r
      (start, h, out) = st
      byte_lines.go(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), byte_lines.step(U32.is_eq(v, 10), start, (i + 1 : U32), (U32.xor(h, v) * 16777619 : U32), out))

def byte_lines.wrap(+n: U32, r: Array<U32> & List<&2, ByteRange>) -> Bytes.Bytes & List<&2, ByteRange>:
  (a, rs) = r
  (Bytes.Bytes{n, a}, rs)

# Ranges include LF; CR and all other octets are ordinary bytes.
def byte_lines(b: Bytes.Bytes) -> Bytes.Bytes & List<&2, ByteRange>:
  Bytes.Bytes{+n, a} = b
  byte_lines.wrap(n, byte_lines.go(U32.to_nat(n), Bytes.peek(a, 0), 0, (0, 2166136261, Nil{})))

def byte_equal.b(a: Array<U32>, x: U32, r: Array<U32> & U32) -> Array<U32> & Array<U32> & Bool:
  (b, y) = r
  (a, b, U32.is_eq(x, y))

def byte_equal.a(r: Array<U32> & U32, b: Array<U32>, j: U32) -> Array<U32> & Array<U32> & Bool:
  (a, x) = r
  byte_equal.b(a, x, Bytes.peek(b, j))

def byte_equal.go(f: Nat, r: Array<U32> & Array<U32> & Bool, +i: U32, +j: U32, +ok: Bool) -> Array<U32> & Array<U32> & Bool:
  match f:
    case 0n:
      (a, b, _) = r
      (a, b, ok)
    case 1n+p:
      (a, b, eq) = r
      byte_equal.go(p, byte_equal.a(Bytes.peek(a, (i + 1 : U32)), b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32), Bool.and(ok, eq))

def byte_equal.size(eq: Bool, a: Array<U32>, b: Array<U32>, +i: U32, +j: U32, n: U32) -> Array<U32> & Array<U32> & Bool:
  match eq:
    case True{}:
      byte_equal.go(U32.to_nat(n), byte_equal.a(Bytes.peek(a, i), b, j), i, j, True{})
    case False{}:
      (a, b, False{})

def byte_paired(es: List<&2, Edit<ByteRange>>, r: Array<U32> & Array<U32> & Bool, +ok: Bool) -> Array<U32> & Array<U32> & Bool:
  match es:
    case Nil{}:
      (a, b, eq) = r
      (a, b, Bool.and(ok, eq))
    case Con{Same{ByteRange{i, +n, _}, ByteRange{j, m, _}}, t}:
      (a, b, eq) = r
      byte_paired(t, byte_equal.size(U32.is_eq(n, m), a, b, i, j, n), Bool.and(ok, eq))
    case Con{_, t}:
      byte_paired(t, r, ok)

def byte_values.word.high(r: Array<U32> & U32, low: U32, +shift: Nat) -> Array<U32> & U32:
  (a, high) = r
  (a, (U32.shrn(low, shift) .|. U32.shln(high, Nat.sub(32n, shift)) : U32))

def byte_values.word.pick(aligned: Bool, r: Array<U32> & U32, +i: U32) -> Array<U32> & U32:
  match aligned:
    case True{}:
      r
    case False{}:
      (a, low) = r
      byte_values.word.high(Array.get(U32, a, ((i >> 2n) + 1 : U32)), low, Bytes.shift(i))

def byte_values.word(a: Array<U32>, +i: U32) -> Array<U32> & U32:
  byte_values.word.pick(U32.is_eq((i .&. 3 : U32), 0), Array.get(U32, a, (i >> 2n : U32)), i)

def byte_values.tail(r: Array<U32> & U32, n: U32, out: List<&2, U32>) -> Array<U32> & List<&2, U32>:
  (a, tail) = r
  (a, n <> tail <> out)

def byte_values.go(f: Nat, r: Array<U32> & U32, +i: U32, +n: U32, out: List<&2, U32>) -> Array<U32> & List<&2, U32>:
  match f:
    case 0n:
      (a, _) = r
      byte_values.tail(Bytes.uint.go(U32.to_nat((n .&. 3 : U32)), Bytes.peek(a, i), i, True{}, 0), n, out)
    case 1n+p:
      (a, v) = r
      byte_values.go(p, byte_values.word(a, (i + 4 : U32)), (i + 4 : U32), n, v <> out)

def byte_values.push(first: Bool, vs: List<&2, U32>, out: List<&2, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  match first:
    case True{}:
      out
    case False{}:
      vs <> out

def byte_values(rs: List<&2, ByteRange>, r: Array<U32> & List<&2, U32>, out: List<&2, List<&2, U32>>, +first: Bool) -> Array<U32> & List<&2, List<&2, U32>>:
  match rs:
    case Nil{}:
      (a, vs) = r
      (a, List.reverse(&2, List<&2, U32>, byte_values.push(first, vs, out)))
    case Con{ByteRange{+i, +n, _}, t}:
      (a, vs) = r
      byte_values(t, byte_values.go(U32.to_nat((n >> 2n : U32)), byte_values.word(a, i), i, n, Nil{}), byte_values.push(first, vs, out), False{})

def byte_values.eq(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x, xs} Con{y, ys}:
      Bool.and(U32.is_eq(x, y), byte_values.eq(xs, ys))
    case _ _:
      False{}

def byte_diff.fallback.b(a: Array<U32>, av: List<&2, List<&2, U32>>, r: Array<U32> & List<&2, List<&2, U32>>, old: List<&2, ByteRange>, new: List<&2, ByteRange>) -> Array<U32> & Array<U32> & List<&2, Edit<ByteRange>>:
  (b, bv) = r
  (a, b, walk(ByteRange, moves(~List<&2, U32>, ~byte_values.eq, av, bv), old, new))

def byte_diff.fallback.a(r: Array<U32> & List<&2, List<&2, U32>>, b: Array<U32>, old: List<&2, ByteRange>, +new: List<&2, ByteRange>) -> Array<U32> & Array<U32> & List<&2, Edit<ByteRange>>:
  (a, av) = r
  byte_diff.fallback.b(a, av, byte_values(new, (b, Nil{}), Nil{}, True{}), old, new)

# A collision compares exact packed words, a partial word, and the byte length.
def byte_diff.pick(ok: Bool, es: List<&2, Edit<ByteRange>>, a: Array<U32>, b: Array<U32>, +old: List<&2, ByteRange>, +new: List<&2, ByteRange>) -> Array<U32> & Array<U32> & List<&2, Edit<ByteRange>>:
  match ok:
    case True{}:
      (a, b, es)
    case False{}:
      byte_diff.fallback.a(byte_values(old, (a, Nil{}), Nil{}, True{}), b, old, new)

def byte_diff.checked(r: Array<U32> & Array<U32> & Bool, es: List<&2, Edit<ByteRange>>, old: List<&2, ByteRange>, new: List<&2, ByteRange>) -> Array<U32> & Array<U32> & List<&2, Edit<ByteRange>>:
  (a, b, ok) = r
  byte_diff.pick(ok, es, a, b, old, new)

def byte_diff.wrap(an: U32, bn: U32, r: Array<U32> & Array<U32> & List<&2, Edit<ByteRange>>) -> Bytes.Bytes & Bytes.Bytes & List<&2, Edit<ByteRange>>:
  (a, b, es) = r
  (Bytes.Bytes{an, a}, Bytes.Bytes{bn, b}, es)

def byte_diff.arrays(a: Bytes.Bytes, b: Bytes.Bytes, +old: List<&2, ByteRange>, +new: List<&2, ByteRange>) -> Bytes.Bytes & Bytes.Bytes & List<&2, Edit<ByteRange>>:
  Bytes.Bytes{an, aa} = a
  Bytes.Bytes{bn, ba} = b
  +es = walk(ByteRange, moves(~U32, ~U32.is_eq, keys(~ByteRange, ~byte_range.key, old), keys(~ByteRange, ~byte_range.key, new)), old, new)
  byte_diff.wrap(an, bn, byte_diff.checked(byte_paired(es, (aa, ba, True{}), True{}), es, old, new))

def byte_diff.new(a: Bytes.Bytes, old: List<&2, ByteRange>, r: Bytes.Bytes & List<&2, ByteRange>) -> Bytes.Bytes & Bytes.Bytes & List<&2, Edit<ByteRange>>:
  (b, new) = r
  byte_diff.arrays(a, b, old, new)

def byte_diff.old(r: Bytes.Bytes & List<&2, ByteRange>, b: Bytes.Bytes) -> Bytes.Bytes & Bytes.Bytes & List<&2, Edit<ByteRange>>:
  (a, old) = r
  byte_diff.new(a, old, byte_lines(b))

# Returns both owned buffers and a shortest line script whose ranges refer to them.
def diff_bytes(a: Bytes.Bytes, b: Bytes.Bytes) -> Bytes.Bytes & Bytes.Bytes & List<&2, Edit<ByteRange>>:
  byte_diff.old(byte_lines(a), b)

# ---- unified output

def far() -> U32:
  1000000000

def ahead.next(+r: List<&2, U32>) -> U32:
  match r:
    case Nil{}:
      far()
    case Con{d, _}:
      U32.min((d + 1 : U32), far())

def ahead.cons(+change: Bool, +r: List<&2, U32>) -> List<&2, U32>:
  Bool.pick(U32, change, 0, ahead.next(r)) <> r

def is_change(-A: Data, e: Edit<A>) -> Bool:
  match e:
    case Same{_, _}:
      False{}
    case _:
      True{}

# For each edit, how many edits ahead the next change is: 0 for a change.
def ahead(-A: Data, es: List<&2, Edit<A>>) -> List<&2, U32>:
  match es:
    case Nil{}:
      Nil{}
    case Con{+e, t}:
      ahead.cons(is_change(A, e), ahead(A, t))

# A Gap is a Same line outside every hunk. dold and dnew count the old and new lines a row consumes.
type Row is Data:
  Gap{}
  Line{text: String, dold: U32, dnew: U32}

def rows(es: List<&2, Edit<String>>, ds: List<&2, U32>, +ctx: U32, +back: U32) -> List<&2, Row>:
  match es ds:
    case Con{Same{_, n}, t} Con{+d, dt}:
      +b = U32.min((back + 1 : U32), far())
      Bool.pick(Row, U32.is_le(b, ctx) || U32.is_le(d, ctx), Line{" " ++ n, 1, 1}, Gap{}) <> rows(t, dt, ctx, b)
    case Con{Del{o}, t} Con{_, dt}:
      Line{"-" ++ o, 1, 0} <> rows(t, dt, ctx, 0)
    case Con{Ins{n}, t} Con{_, dt}:
      Line{"+" ++ n, 0, 1} <> rows(t, dt, ctx, 0)
    case _ _:
      Nil{}

type Hunk is Data:
  Hunk{o: U32, n: U32, ol: U32, nl: U32, body: List<&2, String>}

# GNU form: an empty range names the line before it, and a one-line range drops ",1".
def range.pick(empty: Bool, +start: U32, +len: U32) -> String:
  match empty:
    case True{}:
      U32.show(start) ++ ",0"
    case False{}:
      Bool.pick(String, U32.is_eq(len, 1), U32.show((start + 1 : U32)),
        U32.show((start + 1 : U32)) ++ "," ++ U32.show(len))

def range(+start: U32, +len: U32) -> String:
  range.pick(U32.is_eq(len, 0), start, len)

def hunk.show(h: Hunk) -> String:
  match h:
    case Hunk{o, n, ol, nl, body}:
      "@@ -" ++ range(o, ol) ++ " +" ++ range(n, nl) ++ " @@\n" ++
        String.concat(List.reverse(&2, String, body))

def close(cur: Maybe<&2, Hunk>, out: List<&2, String>) -> List<&2, String>:
  match cur:
    case None{}:
      out
    case Some{h}:
      hunk.show(h) <> out

def open(cur: Maybe<&2, Hunk>, +o: U32, +n: U32) -> Hunk:
  match cur:
    case None{}:
      Hunk{o, n, 0, 0, Nil{}}
    case Some{h}:
      h

# Text whose line lacks "\n" is the last line of its file, as diff -u marks it.
def eol(+text: String) -> String:
  Bool.pick(String, String.ends_with(text, "\n"), "", "\n\\ No newline at end of file\n")

def hunk.add(h: Hunk, +text: String, +dold: U32, +dnew: U32) -> Hunk:
  match h:
    case Hunk{o, n, ol, nl, body}:
      Hunk{o, n, (ol + dold : U32), (nl + dnew : U32), (text ++ eol(text)) <> body}

# o and n count the old and new lines before the row.
def emit(rs: List<&2, Row>, +o: U32, +n: U32, cur: Maybe<&2, Hunk>, out: List<&2, String>) -> List<&2, String>:
  match rs:
    case Nil{}:
      close(cur, out)
    case Con{Gap{}, t}:
      emit(t, (o + 1 : U32), (n + 1 : U32), None{}, close(cur, out))
    case Con{Line{text, +dold, +dnew}, t}:
      emit(t, (o + dold : U32), (n + dnew : U32), Some{hunk.add(open(cur, o, n), text, dold, dnew)}, out)

def unified.fin(hs: List<&2, String>, old_name: String, new_name: String) -> String:
  match hs:
    case Nil{}:
      ""
    case Con{_, _}:
      "--- " ++ old_name ++ "\n+++ " ++ new_name ++ "\n" ++ String.concat(List.reverse(&2, String, hs))

# Unified diff text with ctx lines of context around each change; "" when nothing changed.
# Each line must end with "\n" except the last line of a file, as lines() gives them.
def unified(old_name: String, new_name: String, +es: List<&2, Edit<String>>, +ctx: U32) -> String:
  unified.fin(emit(rows(es, ahead(String, es), ctx, far()), 0, 0, None{}, Nil{}), old_name, new_name)

# ---- Levenshtein distance

def lev.row(~A: Data, ~eq: A -> A -> Bool, b: List<&2, A>, up: List<&2, U32>, +x: A, +diag: U32, +left: U32) -> List<&2, U32>:
  match b up:
    case Con{+y, bt} Con{+u, ut}:
      +v = U32.min(U32.min((u + 1 : U32), (left + 1 : U32)), (diag + Bool.pick(U32, eq(x, y), 0, 1) : U32))
      v <> lev.row(~A, ~eq, bt, ut, x, u, v)
    case _ _:
      Nil{}

def lev.last(xs: List<&2, U32>, +d: U32) -> U32:
  match xs:
    case Nil{}:
      d
    case Con{+h, t}:
      lev.last(t, h)

def lev.init(n: Nat, +i: U32) -> List<&2, U32>:
  match n:
    case 0n:
      [i]
    case 1n+p:
      i <> lev.init(p, (i + 1 : U32))

def lev.go(~A: Data, ~eq: A -> A -> Bool, a: List<&2, A>, +b: List<&2, A>, prev: List<&2, U32>, +i: U32) -> U32:
  match a prev:
    case Con{+x, at} Con{+p0, pt}:
      +j = (i + 1 : U32)
      lev.go(~A, ~eq, at, b, j <> lev.row(~A, ~eq, b, pt, x, p0, j), j)
    case _ _:
      lev.last(prev, 0)

# Fewest inserts, deletes, and substitutions that turn a into b.
def edit_distance(~A: Data, ~eq: A -> A -> Bool, a: List<&2, A>, +b: List<&2, A>) -> U32:
  lev.go(~A, ~eq, a, b, lev.init(List.length(&2, A, b), 0), 0)

# Levenshtein distance by code point.
def distance(a: String, b: String) -> U32:
  edit_distance(~Char, ~Char.is_eq, String.to_list(a), String.to_list(b))

# ---- word wrap

def words.flush(cur: String, out: List<&2, String>) -> List<&2, String>:
  match cur:
    case SNil{}:
      out
    case SCon{h, t}:
      String.reverse(SCon{h, t}) <> out

# cur holds the word being read, reversed.
def words.step(sp: Bool, +c: Char, st: String & List<&2, String>) -> String & List<&2, String>:
  match sp:
    case True{}:
      (cur, out) = st
      (SNil{}, words.flush(cur, out))
    case False{}:
      (cur, out) = st
      (SCon{c, cur}, out)

def words.go(s: String, st: String & List<&2, String>) -> List<&2, String>:
  match s:
    case SNil{}:
      (cur, out) = st
      List.reverse(&2, String, words.flush(cur, out))
    case SCon{+c, t}:
      words.go(t, words.step(Char.is_space(c), c, st))

# Runs of non-space chars.
def words(s: String) -> List<&2, String>:
  words.go(s, (SNil{}, Nil{}))

def fits(+line: String, +width: U32) -> Bool:
  U32.is_le(Tty.width(line), width)

def single.of(gs: List<&2, String>) -> Bool:
  match gs:
    case Con{_, Nil{}}:
      True{}
    case _:
      False{}

# One grapheme cluster: the only kind of line that may be wider than the width.
def single(+s: String) -> Bool:
  single.of(Unicode.graphemes(s))

def ok.pick(f: Bool, +s: String) -> Bool:
  match f:
    case True{}:
      True{}
    case False{}:
      single(s)

# What wrap promises for each line: it fits, or it is one grapheme cluster.
def ok(+s: String, +width: U32) -> Bool:
  ok.pick(fits(s, width), s)

# The finished lines, newest first, and the line being built.
type Wr is Data:
  Wr{out: List<&2, String>, cur: Maybe<&2, String>}

def step0.pick(f: Bool, out: List<&2, String>, s: String, +c: Char) -> Wr:
  match f:
    case True{}:
      Wr{out, Some{s ++ SCon{c, SNil{}}}}
    case False{}:
      Wr{s <> out, Some{SCon{c, SNil{}}}}

def step0(st: Wr, +c: Char, +width: U32) -> Wr:
  match st:
    case Wr{out, None{}}:
      Wr{out, Some{SCon{c, SNil{}}}}
    case Wr{out, Some{+s}}:
      step0.pick(fits(s ++ SCon{c, SNil{}}, width), out, s, c)

# Code points, for a piece that neither fits nor segments as one cluster. One code point is one cluster.
def run0(s: String, +width: U32, st: Wr) -> Wr:
  match s:
    case SNil{}:
      st
    case SCon{c, t}:
      run0(t, width, step0(st, c, width))

def start1(ok: Bool, out: List<&2, String>, +g: String, +width: U32) -> Wr:
  match ok:
    case True{}:
      Wr{out, Some{g}}
    case False{}:
      run0(g, width, Wr{out, None{}})

def step1.pick(f: Bool, out: List<&2, String>, s: String, +g: String, +width: U32) -> Wr:
  match f:
    case True{}:
      Wr{out, Some{s ++ g}}
    case False{}:
      start1(ok(g, width), s <> out, g, width)

def step1(st: Wr, +g: String, +width: U32) -> Wr:
  match st:
    case Wr{out, None{}}:
      start1(ok(g, width), out, g, width)
    case Wr{out, Some{+s}}:
      step1.pick(fits(s ++ g, width), out, s, g, width)

# Grapheme clusters, for a word wider than the line.
def run1(gs: List<&2, String>, +width: U32, st: Wr) -> Wr:
  match gs:
    case Nil{}:
      st
    case Con{g, t}:
      run1(t, width, step1(st, g, width))

def start2(ok: Bool, out: List<&2, String>, +w: String, +width: U32) -> Wr:
  match ok:
    case True{}:
      Wr{out, Some{w}}
    case False{}:
      run1(Unicode.graphemes(w), width, Wr{out, None{}})

def step2.pick(f: Bool, out: List<&2, String>, s: String, +w: String, +width: U32) -> Wr:
  match f:
    case True{}:
      Wr{out, Some{s ++ " " ++ w}}
    case False{}:
      start2(ok(w, width), s <> out, w, width)

def step2(st: Wr, +w: String, +width: U32) -> Wr:
  match st:
    case Wr{out, None{}}:
      start2(ok(w, width), out, w, width)
    case Wr{out, Some{+s}}:
      step2.pick(fits(s ++ " " ++ w, width), out, s, w, width)

def run2(ws: List<&2, String>, +width: U32, st: Wr) -> Wr:
  match ws:
    case Nil{}:
      st
    case Con{w, t}:
      run2(t, width, step2(st, w, width))

def wrap.lines(st: Wr) -> List<&2, String>:
  match st:
    case Wr{out, None{}}:
      List.reverse(&2, String, out)
    case Wr{out, Some{s}}:
      List.reverse(&2, String, s <> out)

# Wraps by measuring each candidate line whole. wrap falls back to it.
def wrap.slow(text: String, +width: U32) -> List<&2, String>:
  wrap.lines(run2(words(text), width, Wr{Nil{}, None{}}))

def all_ok(ls: List<&2, String>, +width: U32) -> Bool:
  match ls:
    case Nil{}:
      True{}
    case Con{l, t}:
      Bool.and(ok(l, width), all_ok(t, width))

def printable(+c: U32) -> Bool:
  U32.is_lt((c - 33 : U32), 94)

# Only printable ASCII, so each char is one cluster one column wide.
def ascii(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+c}, t}:
      Bool.and(printable(c), ascii(t))

def last.go(s: String, +c: U32) -> U32:
  match s:
    case SNil{}:
      c
    case SCon{Chr{+d}, t}:
      last.go(t, d)

# The last code point of s, or 0.
def last(s: String) -> U32:
  last.go(s, 0)

def two(gs: List<&2, String>) -> Bool:
  match gs:
    case Con{_, Con{_, Nil{}}}:
      True{}
    case _:
      False{}

# Whether a cluster boundary falls between code point c and a space. Only a Prepend c joins one.
def apart(+c: U32) -> Bool:
  two(Unicode.graphemes(SCon{Chr{c}, " "}))

# The end of a line after word w. Any printable ASCII char stands for the last char of a printable ASCII word.
def fw.end(aw: Bool, w: String) -> U32:
  match aw:
    case True{}:
      97
    case False{}:
      last(w)

# The finished lines, newest first; the words of the open line, newest first; its width; and its last code point.
type Fw is Data:
  Fw{out: List<&2, String>, cur: List<&2, String>, cw: U32, end: U32}

def fw.line(cur: List<&2, String>) -> String:
  String.join(List.reverse(&2, String, cur), " ")

def fw.close(out: List<&2, String>, cur: List<&2, String>) -> List<&2, String>:
  match cur:
    case Nil{}:
      out
    case Con{h, t}:
      fw.line(Con{h, t}) <> out

def fw.from(st: Wr) -> Fw:
  match st:
    case Wr{out, None{}}:
      Fw{out, Nil{}, 0, 0}
    case Wr{out, Some{+s}}:
      Fw{out, [s], Tty.width(s), last(s)}

def fw.begin(fits: Bool, out: List<&2, String>, +w: String, +ww: U32, +width: U32, +aw: Bool) -> Fw:
  match fits:
    case True{}:
      Fw{out, [w], ww, fw.end(aw, w)}
    case False{}:
      fw.from(start2(ok(w, width), out, w, width))

def fw.start(asc: Bool, out: List<&2, String>, +w: String, +width: U32) -> Fw:
  match asc:
    case True{}:
      +ww = U32.from_nat(String.length(w))
      fw.begin(U32.is_le(ww, width), out, w, ww, width, True{})
    case False{}:
      +ww = Tty.width(w)
      fw.begin(U32.is_le(ww, width), out, w, ww, width, False{})

def fw.add(fits: Bool, out: List<&2, String>, +cur: List<&2, String>, +nw: U32, +w: String, +width: U32, +aw: Bool) -> Fw:
  match fits:
    case True{}:
      Fw{out, w <> cur, nw, fw.end(aw, w)}
    case False{}:
      fw.start(aw, fw.close(out, cur), w, width)

# A boundary between the line and the space keeps the line's clusters apart from those of the space and the word, so the widths add.
def fw.join(sure: Bool, +gs: List<&2, String>, out: List<&2, String>, +cur: List<&2, String>, +cw: U32, +w: String, +width: U32, +aw: Bool) -> Fw:
  match sure:
    case True{}:
      +nw = (cw + Tty.width.go(gs, 0) : U32)
      fw.add(U32.is_le(nw, width), out, cur, nw, w, width, aw)
    case False{}:
      +nw = Tty.width(fw.line(cur) ++ " " ++ w)
      fw.add(U32.is_le(nw, width), out, cur, nw, w, width, aw)

# Printable ASCII on both sides of the space needs no segmentation: each char is one cluster one column wide.
def fw.next(asc: Bool, out: List<&2, String>, +cur: List<&2, String>, +cw: U32, +end: U32, +w: String, +width: U32, +aw: Bool) -> Fw:
  match asc:
    case True{}:
      +nw = (cw + 1 + U32.from_nat(String.length(w)) : U32)
      fw.add(U32.is_le(nw, width), out, cur, nw, w, width, aw)
    case False{}:
      fw.join(apart(end), Unicode.graphemes(" " ++ w), out, cur, cw, w, width, aw)

def fw.step.go(st: Fw, +aw: Bool, +w: String, +width: U32) -> Fw:
  match st:
    case Fw{out, Nil{}, _, _}:
      fw.start(aw, out, w, width)
    case Fw{out, Con{+h, +t}, +cw, +end}:
      fw.next(Bool.and(printable(end), aw), out, Con{h, t}, cw, end, w, width, aw)

def fw.step(st: Fw, +w: String, +width: U32) -> Fw:
  fw.step.go(st, ascii(w), w, width)

def fw.run(ws: List<&2, String>, +width: U32, st: Fw) -> Fw:
  match ws:
    case Nil{}:
      st
    case Con{w, t}:
      fw.run(t, width, fw.step(st, w, width))

def fw.lines(st: Fw) -> List<&2, String>:
  match st:
    case Fw{out, cur, _, _}:
      List.reverse(&2, String, fw.close(out, cur))

# The same lines as wrap.slow, adding widths when no cluster spans the joining space.
def wrap.fast(text: String, +width: U32) -> List<&2, String>:
  fw.lines(fw.run(words(text), width, Fw{Nil{}, Nil{}, 0, 0}))

def wrap.pick(good: Bool, ls: List<&2, String>, text: String, +width: U32) -> List<&2, String>:
  match good:
    case True{}:
      ls
    case False{}:
      wrap.slow(text, width)

# Greedy word wrap to width display columns. Whitespace runs separate words; lines join words with one space.
# A word wider than width breaks between grapheme clusters; a cluster wider than width stays whole on its own line.
# The fast path's lines are checked with ok; if one fails, every line is measured whole instead.
def wrap(+text: String, +width: U32) -> List<&2, String>:
  +ls = wrap.fast(text, width)
  wrap.pick(all_ok(ls, width), ls, text, width)
