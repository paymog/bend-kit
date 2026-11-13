# stats

Descriptive statistics over `F64` lists: sum, mean, variance, quantiles, a histogram, and least-squares linear regression. Also `U32` gcd, lcm, and integer square root.

```bend
import bend-kit-stats@0.1.0.0/stats.bend as S
```

It imports `bend-kit-f64@0.1.1.0`. Pass it values of that `F64` type.

## Example

```bend
import Base
import bend-kit-f64@0.1.1.0/f64.bend as F
import bend-kit-stats@0.1.0.0/stats.bend as S

def n(k: U32) -> F.F64:
  F.F64.from_u32(k)

def show(m: Maybe<&2, F.F64>) -> String:
  match m:
    case Some{x}:
      F.F64.show(x)
    case None{}:
      "none"

def main() -> IO(Unit):
  +xs = {[n(5), n(2), n(9), n(4), n(7), n(4), n(5), n(4)] : List<&2, F.F64>}
  do IO<Unit>:
    IO.print(show(S.Stats.mean(xs)))
    IO.print(show(S.Stats.median(xs)))
    IO.print(show(S.Stats.quantile(xs, 90, 100)))
```

It prints `5.0`, `4.5`, and `7.6`. [check.bend](check.bend) runs every function.

## API

Lists are `List<&2, F.F64>`. A result is `None{}` when the input has too few values.

| def | result |
|---|---|
| `Stats.sum(xs)` | `F64`: the sum, left to right, with no compensation; `0.0` for an empty list |
| `Stats.mean(xs)` | `Maybe`: `sum / n`; `None` for an empty list |
| `Stats.pvariance(xs)` | `Maybe`: the population variance, `ss / n`; `None` for an empty list |
| `Stats.variance(xs)` | `Maybe`: the sample variance, `ss / (n - 1)`; `None` for fewer than 2 values |
| `Stats.quantile(xs, k: U32, q: U32)` | `Maybe`: the `k/q` quantile; `None` for an empty list, `q = 0`, `q > 65536`, or `k > q` |
| `Stats.median(xs)` | `Maybe`: `quantile(xs, 1, 2)` |
| `Stats.histogram(edges, xs)` | `List<&2, U32>`: the count in each bin |
| `Stats.linear_regression(xs, ys)` | `Maybe<&2, Fit>`: `Fit{slope, intercept}` of least squares `y = slope * x + intercept` |
| `U32.gcd(a, b)` | `U32`: the greatest common divisor; `gcd(0, 0)` is `0` |
| `U32.lcm(a, b)` | `Maybe<&2, U32>`: the least common multiple; `None` when it passes 4294967295 |
| `U32.isqrt(n)` | `U32`: the floor of the square root |

`ss` is the sum of `(x - mean)^2`, in two passes, as in Python's `statistics`. A two-pass sum loses less than a one-pass sum of squares, but it still rounds at each step. Python's `statistics.variance` uses exact fractions, so its result can differ in the low bits.

`quantile` sorts the list, then interpolates between the two closest ranks: rank `h = (n - 1) * k / q`, and the result is `s[i] + t * (s[i + 1] - s[i])` with `i` the floor of `h` and `t` its fraction. This is R's type 7 and NumPy's default `linear` method. A percentile `p` is `quantile(xs, p, 100)`. `t` is the exact fraction `r / q` rounded to a double, so the call takes `k` and `q`, not a float.

`histogram` takes `k + 1` ascending edges and gives `k` counts. Bin `i` is `[e(i), e(i+1))`, and the last bin is closed, `[e(k-1), e(k)]`, as in NumPy. A value outside every bin is not counted. It scans the values once per bin.

`linear_regression` gives `slope = sxy / sxx` and `intercept = mean(ys) - slope * mean(xs)`. It is `None` when the lists differ in length, have fewer than 2 points, or every `x` is the same.

A `NaN` in the input gives a `NaN` mean and variance, and an unspecified quantile, because `NaN` has no place in the sort order. A histogram does not count a `NaN`.

There is no standard deviation, because `bend-kit-f64` has no square root yet.

## Laws

`LAWS.bend` states fixtures with exact expected values, and `PROOF.bend` proves each by computation: every function on the data `5 2 9 4 7 4 5 4`, the empty and short cases that give `None`, the closed last histogram bin, a regression that matches Python's `statistics.linear_regression`, `gcd` on the consecutive Fibonacci numbers that need the most steps, `lcm` at and past 4294967295, and `isqrt(4294967295)`.

## Bench

`bench/` times the mean, variance, and median of 10000 doubles against C, Rust, Python, and JavaScript. See [bench/README.md](bench/README.md).
