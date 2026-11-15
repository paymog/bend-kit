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

def same(a: Maybe<&2, F.F64>, b: Maybe<&2, F.F64>) -> Bool:
  match a b:
    case None{} None{}:
      True{}
    case Some{F.F64{ah, al}} Some{F.F64{bh, bl}}:
      Bool.and(U32.is_eq(ah, bh), U32.is_eq(al, bl))
    case None{} Some{x}:
      False{}
    case Some{x} None{}:
      False{}

def reference.interp(exact: Bool, rest: List<&2, F.F64>, t: F.F64) -> F.F64:
  match exact rest:
    case True{} Con{a, tail}:
      a
    case False{} Con{+a, Con{b, tail}}:
      F.F64.add(a, F.F64.mul(t, F.F64.sub(b, a)))
    case False{} Con{a, Nil{}}:
      a
    case True{} Nil{}:
      F.F64.nan()
    case False{} Nil{}:
      F.F64.nan()

def reference(xs: List<&2, F.F64>, +k: U32, +q: U32) -> Maybe<&2, F.F64>:
  match xs:
    case Nil{}:
      None{}
    case Con{+h, +tail}:
      +ys = {Con{h, tail} : List<&2, F.F64>}
      +n1 = (U32.from_nat(List.length(&2, F.F64, ys)) - 1 : U32)
      +c = ((n1 % q) * k : U32)
      +r = (c % q : U32)
      Some{reference.interp(U32.is_zero(r),
        List.drop(&2, F.F64, List.sort(~F.F64, ~S.Stats.le, ys), U32.to_nat(((n1 / q) * k + c / q : U32))),
        F.F64.div(F.F64.from_u32(r), F.F64.from_u32(q)))}

def selection.ranks(i: Nat, +xs: List<&2, F.F64>, +q: U32) -> Bool:
  match i:
    case 0n:
      True{}
    case 1n+ +p:
      +k = U32.from_nat(p)
      Bool.and(same(S.Stats.quantile(xs, k, q), reference(xs, k, q)), selection.ranks(p, xs, q))

def selection.denominators(q: Nat, +xs: List<&2, F.F64>) -> Bool:
  match q:
    case 0n:
      Bool.and(same(S.Stats.quantile(xs, 1, 65536), reference(xs, 1, 65536)),
        Bool.and(same(S.Stats.quantile(xs, 32769, 65536), reference(xs, 32769, 65536)),
          same(S.Stats.quantile(xs, 65536, 65536), reference(xs, 65536, 65536))))
    case 1n+ +p:
      Bool.and(selection.ranks(2n+p, xs, U32.from_nat(1n+p)), selection.denominators(p, xs))

def selection.lists(depth: Nat, +xs: List<&2, F.F64>) -> Bool:
  match depth:
    case 0n:
      selection.denominators(4n, xs)
    case 1n+ +p:
      Bool.and(selection.denominators(4n, xs),
        Bool.and(selection.lists(p, Con{F.F64.neg(n(1)), xs}),
          Bool.and(selection.lists(p, Con{F.F64.neg(F.F64.zero()), xs}),
            Bool.and(selection.lists(p, Con{F.F64.zero(), xs}),
              Bool.and(selection.lists(p, Con{n(1), xs}), selection.lists(p, Con{n(2), xs}))))))

def selection.pair(r: F.F64 & F.F64, a: F.F64, b: F.F64) -> Bool:
  (x, y) = r
  Bool.and(same(Some{x}, Some{a}), same(Some{y}, Some{b}))

def selection.fallback() -> Bool:
  Bool.and(
    selection.pair(S.Stats.select.go(0n, S.Selection{[n(3), n(1), n(2)], 1, 3, False{}, None{}}), n(2), n(3)),
    selection.pair(S.Stats.select.go(0n, S.Selection{[n(1)], 0, 1, False{}, Some{n(2)}}), n(1), n(2)))

def selection.assert(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS selection matches stable sort on 781 lists and forced fallback")
    case False{}:
      IO.die(Unit, 1, "FAIL selection differs from stable sort")

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
    selection.assert(Bool.and(selection.lists(4n, Nil{}), selection.fallback()))
