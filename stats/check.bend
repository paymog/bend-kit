import Base
import bend-kit-f64@0.1.3.0/f64.bend as F
import ./stats.bend as S

def n(k: U32) -> F.F64:
  F.F64.from_u32(k)

def show(name: String, m: Maybe<&2, F.F64>) -> IO(Unit):
  match m:
    case None{}:
      IO.print(name ++ " none")
    case Some{x}:
      IO.print(name ++ " " ++ F.F64.show(x))

def show.fit(m: Maybe<&2, S.Fit>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("fit none")
    case Some{f}:
      match f:
        case S.Fit{slope, intercept}:
          IO.print("fit " ++ F.F64.show(slope) ++ " " ++ F.F64.show(intercept))

def counts(cs: List<&2, U32>) -> String:
  match cs:
    case Nil{}:
      ""
    case Con{c, t}:
      " " ++ U32.show(c) ++ counts(t)

def main() -> IO(Unit):
  +xs = {[n(5), n(2), n(9), n(4), n(7), n(4), n(5), n(4)] : List<&2, F.F64>}
  do IO<Unit>:
    show("mean", S.Stats.mean(xs))
    show("pvariance", S.Stats.pvariance(xs))
    show("variance", S.Stats.variance(xs))
    show("median", S.Stats.median(xs))
    show("p75", S.Stats.quantile(xs, 75, 100))
    show("empty", S.Stats.mean(Nil{}))
    IO.print("histogram" ++ counts(S.Stats.histogram([n(0), n(4), n(8), n(12)], xs)))
    show.fit(S.Stats.linear_regression([n(1), n(2), n(3), n(4), n(5)], [n(2), n(4), n(5), n(4), n(5)]))
    IO.print("gcd " ++ U32.show(S.U32.gcd(1071, 462)))
    IO.print("isqrt " ++ U32.show(S.U32.isqrt(1000000)))
