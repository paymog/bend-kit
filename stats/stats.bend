# Descriptive statistics over F64 lists, and U32 gcd, lcm, and integer square root. Source: https://github.com/paymog/bend-kit/tree/main/stats
import Base
import bend-kit-f64@0.1.3.0/f64.bend as F

def Stats.count(xs: List<&2, F.F64>) -> F.F64:
  F.F64.from_u32(U32.from_nat(List.length(&2, F.F64, xs)))

def Stats.sum.go(xs: List<&2, F.F64>, acc: F.F64) -> F.F64:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      Stats.sum.go(t, F.F64.add(acc, x))

# Left to right, with no compensation.
def Stats.sum(xs: List<&2, F.F64>) -> F.F64:
  Stats.sum.go(xs, F.F64.zero())

def Stats.avg(+xs: List<&2, F.F64>) -> F.F64:
  F.F64.div(Stats.sum(xs), Stats.count(xs))

def Stats.mean(xs: List<&2, F.F64>) -> Maybe<&2, F.F64>:
  match xs:
    case Nil{}:
      None{}
    case Con{h, t}:
      Some{Stats.avg(Con{h, t})}

# The sum of (x - m)^2.
def Stats.ss.go(xs: List<&2, F.F64>, +m: F.F64, acc: F.F64) -> F.F64:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      +d = F.F64.sub(x, m)
      Stats.ss.go(t, m, F.F64.add(acc, F.F64.mul(d, d)))

def Stats.ss(+xs: List<&2, F.F64>) -> F.F64:
  Stats.ss.go(xs, Stats.avg(xs), F.F64.zero())

def Stats.pvariance(xs: List<&2, F.F64>) -> Maybe<&2, F.F64>:
  match xs:
    case Nil{}:
      None{}
    case Con{+h, +t}:
      Some{F.F64.div(Stats.ss(Con{h, t}), Stats.count(Con{h, t}))}

def Stats.variance(xs: List<&2, F.F64>) -> Maybe<&2, F.F64>:
  match xs:
    case Nil{}:
      None{}
    case Con{h, Nil{}}:
      None{}
    case Con{+h, Con{+h2, +t}}:
      Some{F.F64.div(Stats.ss(Con{h, Con{h2, t}}), Stats.count(Con{h2, t}))}

def Stats.pstdev(xs: List<&2, F.F64>) -> Maybe<&2, F.F64>:
  do Maybe<&2, F.F64>:
    v : F.F64 <- Stats.pvariance(xs)
    return F.F64.sqrt(v)

def Stats.stdev(xs: List<&2, F.F64>) -> Maybe<&2, F.F64>:
  do Maybe<&2, F.F64>:
    v : F.F64 <- Stats.variance(xs)
    return F.F64.sqrt(v)

def Stats.interp(exact: Bool, rest: List<&2, F.F64>, +t: F.F64) -> F.F64:
  match exact rest:
    case True{} Con{a, r}:
      a
    case False{} Con{+a, Con{b, r}}:
      F.F64.add(a, F.F64.mul(t, F.F64.sub(b, a)))
    case False{} Con{a, Nil{}}:
      a
    case True{} Nil{}:
      F.F64.nan()
    case False{} Nil{}:
      F.F64.nan()

# Index h = n1 * k / q, split so no product passes q * q.
def Stats.quantile.at(s: List<&2, F.F64>, +n1: U32, +k: U32, +q: U32) -> F.F64:
  +c = ((n1 % q) * k : U32)
  +r = (c % q : U32)
  Stats.interp(U32.is_zero(r), List.drop(&2, F.F64, s, U32.to_nat(((n1 / q) * k + c / q : U32))), F.F64.div(F.F64.from_u32(r), F.F64.from_u32(q)))

def Stats.le(a: F.F64, b: F.F64) -> Bool:
  Bool.not(F.F64.is_lt(b, a))

def Stats.quantile.if(ok: Bool, xs: List<&2, F.F64>, n1: U32, k: U32, q: U32) -> Maybe<&2, F.F64>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Some{Stats.quantile.at(List.sort(~F.F64, ~Stats.le, xs), n1, k, q)}

def Stats.quantile.n(+n: U32, xs: List<&2, F.F64>, +k: U32, +q: U32) -> Maybe<&2, F.F64>:
  +ok = Bool.and(Bool.and(U32.is_gt(n, 0), U32.is_le(k, q)), Bool.and(U32.is_gt(q, 0), U32.is_le(q, 65536)))
  Stats.quantile.if(ok, xs, (n - 1 : U32), k, q)

# The k/q quantile, linear between closest ranks (R type 7, NumPy's default).
def Stats.quantile(+xs: List<&2, F.F64>, k: U32, q: U32) -> Maybe<&2, F.F64>:
  Stats.quantile.n(U32.from_nat(List.length(&2, F.F64, xs)), xs, k, q)

def Stats.median(xs: List<&2, F.F64>) -> Maybe<&2, F.F64>:
  Stats.quantile(xs, 1, 2)

def Stats.histogram.edges(xs: List<&2, F.F64>, a: Array<F.F64>, +i: U32) -> Array<F.F64>:
  match xs:
    case Nil{}:
      a
    case Con{x, rest}:
      Stats.histogram.edges(rest, Array.set(F.F64, a, i, x), (i + 1 : U32))

def Stats.histogram.probe(active: Bool, edges: Array<F.F64>, mid: U32) -> Array<F.F64> & F.F64:
  match active:
    case False{}:
      (edges, F.F64.zero())
    case True{}:
      Array.get(F.F64, edges, mid)

def Stats.histogram.search(fuel: Nat, active: Bool, +lo: U32, +hi: U32, +mid: U32, +x: F.F64, r: Array<F.F64> & F.F64) -> Array<F.F64> & U32:
  match fuel active:
    case 0n _:
      (edges, pivot) = r
      (edges, lo)
    case 1n+p False{}:
      (edges, pivot) = r
      (edges, lo)
    case 1n+p True{}:
      (edges, pivot) = r
      +left = F.F64.is_lt(x, pivot)
      +a = Bool.pick(U32, left, lo, (mid + 1 : U32))
      +b = Bool.pick(U32, left, mid, hi)
      +next = (a + (b - a) / 2 : U32)
      Stats.histogram.search(p, U32.is_lt(a, b), a, b, next, x, Stats.histogram.probe(U32.is_lt(a, b), edges, next))

def Stats.histogram.store(edges: Array<F.F64>, +i: U32, r: Array<U32> & U32) -> Array<F.F64> & Array<U32>:
  (counts, n) = r
  (edges, Array.set(U32, counts, i, (n + 1 : U32)))

def Stats.histogram.increment(counts: Array<U32>, r: Array<F.F64> & U32) -> Array<F.F64> & Array<U32>:
  (edges, j) = r
  +i = (j - 1 : U32)
  Stats.histogram.store(edges, i, Array.get(U32, counts, i))

def Stats.histogram.hit(valid: Bool, +k: U32, x: F.F64, edges: Array<F.F64>, counts: Array<U32>) -> Array<F.F64> & Array<U32>:
  match valid:
    case False{}:
      (edges, counts)
    case True{}:
      +mid = (1 + (k - 1) / 2 : U32)
      Stats.histogram.increment(counts,
        Stats.histogram.search(32n, U32.is_lt(1, k), 1, k, mid, x, Stats.histogram.probe(U32.is_lt(1, k), edges, mid)))

def Stats.histogram.count(xs: List<&2, F.F64>, +k: U32, +lo: F.F64, +hi: F.F64, state: Array<F.F64> & Array<U32>) -> Array<U32>:
  match xs:
    case Nil{}:
      (edges, counts) = state
      counts
    case Con{+x, rest}:
      (edges, counts) = state
      Stats.histogram.count(rest, k, lo, hi,
        Stats.histogram.hit(Bool.and(F.F64.is_le(lo, x), F.F64.is_le(x, hi)), k, x, edges, counts))

def Stats.histogram.list(n: Nat, +i: U32, r: Array<U32> & U32, acc: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      acc
    case 1n:
      (counts, x) = r
      Con{x, acc}
    case 2n+p:
      (counts, x) = r
      +j = (i - 1 : U32)
      Stats.histogram.list(1n+p, j, Array.get(U32, counts, j), Con{x, acc})

def Stats.histogram.finish(+k: U32, counts: Array<U32>) -> List<&2, U32>:
  +i = (k - 1 : U32)
  Stats.histogram.list(U32.to_nat(k), i, Array.get(U32, counts, i), Nil{})

def Stats.histogram.bounds(+k: U32, xs: List<&2, F.F64>, depth: Nat, lo: F.F64, r: Array<F.F64> & F.F64) -> List<&2, U32>:
  (a, hi) = r
  Stats.histogram.finish(k, Stats.histogram.count(xs, k, lo, hi, (a, Array.new(U32, depth, 0))))

def Stats.histogram.first(+k: U32, xs: List<&2, F.F64>, depth: Nat, r: Array<F.F64> & F.F64) -> List<&2, U32>:
  (a, lo) = r
  Stats.histogram.bounds(k, xs, depth, lo, Array.get(F.F64, a, k))

def Stats.histogram.of(nonempty: Bool, +k: U32, edges: List<&2, F.F64>, xs: List<&2, F.F64>) -> List<&2, U32>:
  match nonempty:
    case False{}:
      Nil{}
    case True{}:
      +depth = {1n+U32.log2(k) : Nat}
      a = Stats.histogram.edges(edges, Array.new(F.F64, depth, F.F64.zero()), 0)
      Stats.histogram.first(k, xs, depth, Array.get(F.F64, a, 0))

# Binary search over ascending edges; the last bin includes its upper edge.
def Stats.histogram(+edges: List<&2, F.F64>, xs: List<&2, F.F64>) -> List<&2, U32>:
  +k = U32.from_nat(Nat.sub(List.length(&2, F.F64, edges), 1n))
  Stats.histogram.of(U32.is_gt(k, 0), k, edges, xs)

type Fit is Data:
  Fit{slope: F.F64, intercept: F.F64}

def Stats.sxy.go(xs: List<&2, F.F64>, ys: List<&2, F.F64>, +mx: F.F64, +my: F.F64, acc: F.F64) -> F.F64:
  match xs ys:
    case Con{x, xt} Con{y, yt}:
      Stats.sxy.go(xt, yt, mx, my, F.F64.add(acc, F.F64.mul(F.F64.sub(x, mx), F.F64.sub(y, my))))
    case Con{x, xt} Nil{}:
      acc
    case Nil{} _:
      acc

def Stats.fit(flat: Bool, +sxx: F.F64, sxy: F.F64, +mx: F.F64, +my: F.F64) -> Maybe<&2, Fit>:
  match flat:
    case True{}:
      None{}
    case False{}:
      +slope = F.F64.div(sxy, sxx)
      Some{Fit{slope, F.F64.sub(my, F.F64.mul(slope, mx))}}

def Stats.fit.of(+xs: List<&2, F.F64>, ys: List<&2, F.F64>, +mx: F.F64, +my: F.F64) -> Maybe<&2, Fit>:
  +sxx = Stats.ss.go(xs, mx, F.F64.zero())
  Stats.fit(F.F64.is_zero(sxx), sxx, Stats.sxy.go(xs, ys, mx, my, F.F64.zero()), mx, my)

def Stats.regress.if(ok: Bool, +xs: List<&2, F.F64>, +ys: List<&2, F.F64>) -> Maybe<&2, Fit>:
  match ok:
    case False{}:
      None{}
    case True{}:
      Stats.fit.of(xs, ys, Stats.avg(xs), Stats.avg(ys))

# Least squares y = slope * x + intercept. None for unequal lengths, fewer than 2 points, or constant xs.
def Stats.linear_regression(+xs: List<&2, F.F64>, +ys: List<&2, F.F64>) -> Maybe<&2, Fit>:
  +n = List.length(&2, F.F64, xs)
  Stats.regress.if(Bool.and(Nat.is_eq(n, List.length(&2, F.F64, ys)), Nat.is_lt(1n, n)), xs, ys)

# 48 steps cover U32: consecutive Fibonacci numbers below 2^32 need 46.
def U32.gcd.go(k: Nat, z: Bool, +a: U32, +b: U32) -> U32:
  match k z:
    case 0n _:
      a
    case 1n+p True{}:
      a
    case 1n+p False{}:
      U32.gcd.go(p, U32.is_zero((a % b : U32)), b, (a % b : U32))

def U32.gcd(+a: U32, +b: U32) -> U32:
  +lo = U32.min(a, b)
  U32.gcd.go(48n, U32.is_zero(lo), U32.max(a, b), lo)

def U32.lcm.if(ov: Bool, q: U32, b: U32) -> Maybe<&2, U32>:
  match ov:
    case True{}:
      None{}
    case False{}:
      Some{(q * b : U32)}

def U32.lcm.of(+q: U32, +b: U32) -> Maybe<&2, U32>:
  U32.lcm.if(Bool.and(Bool.not(U32.is_zero(b)), U32.is_gt(q, (4294967295 / b : U32))), q, b)

# None when the result passes 4294967295.
def U32.lcm(+a: U32, +b: U32) -> Maybe<&2, U32>:
  U32.lcm.of((a / U32.gcd(a, b) : U32), b)

def U32.isqrt.pick(ok: Bool, c: U32, r: U32) -> U32:
  match ok:
    case True{}:
      c
    case False{}:
      r

def U32.isqrt.go(+k: Nat, +n: U32, +r: U32) -> U32:
  match k:
    case 0n:
      r
    case 1n+p:
      +c = (r .|. (1 << p) : U32)
      U32.isqrt.go(p, n, U32.isqrt.pick(U32.is_le((c * c : U32), n), c, r))

# The floor of the square root.
def U32.isqrt(+n: U32) -> U32:
  U32.isqrt.go(16n, n, 0)
