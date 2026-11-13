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

def Stats.bin.add(hit: Bool, acc: U32) -> U32:
  match hit:
    case True{}:
      (acc + 1 : U32)
    case False{}:
      acc

def Stats.bin.count(xs: List<&2, F.F64>, +last: Bool, +lo: F.F64, +hi: F.F64, acc: U32) -> U32:
  match xs:
    case Nil{}:
      acc
    case Con{+x, t}:
      +top = Bool.or(F.F64.is_lt(x, hi), Bool.and(last, F.F64.is_le(x, hi)))
      Stats.bin.count(t, last, lo, hi, Stats.bin.add(Bool.and(F.F64.is_le(lo, x), top), acc))

def Stats.bin.last(rest: List<&2, F.F64>) -> Bool:
  match rest:
    case Nil{}:
      True{}
    case Con{h, t}:
      False{}

def Stats.histogram.go(edges: List<&2, F.F64>, +lo: F.F64, +xs: List<&2, F.F64>) -> List<&2, U32>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{+hi, +rest}:
      Con{Stats.bin.count(xs, Stats.bin.last(rest), lo, hi, 0), Stats.histogram.go(rest, hi, xs)}

# Counts per bin [e0, e1), [e1, e2), ..., [e(k-1), ek], for ascending edges.
def Stats.histogram(edges: List<&2, F.F64>, xs: List<&2, F.F64>) -> List<&2, U32>:
  match edges:
    case Nil{}:
      Nil{}
    case Con{lo, rest}:
      Stats.histogram.go(rest, lo, xs)

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

def U32.gcd(a: U32, +b: U32) -> U32:
  U32.gcd.go(48n, U32.is_zero(b), a, b)

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
