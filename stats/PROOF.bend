import Base
import ./LAWS.bend as Laws
import ./stats.bend as S
import bend-mathlib@0.8.0.0/nat.bend as N
import bend-mathlib@0.8.0.0/u32.bend as U

def Laws.sum():
  {==}

def Laws.sum_empty():
  {==}

def Laws.mean():
  {==}

def Laws.mean_empty():
  {==}

def Laws.pvariance():
  {==}

def Laws.pvariance_one():
  {==}

def Laws.variance():
  {==}

def Laws.variance_one():
  {==}

def Laws.pstdev():
  {==}

def Laws.stdev():
  {==}

def Laws.pstdev_one():
  {==}

def Laws.stdev_one():
  {==}

def Laws.pstdev_empty():
  {==}

def Laws.stdev_empty():
  {==}

def Laws.median_even():
  {==}

def Laws.median_odd():
  {==}

def Laws.median_empty():
  {==}

def Laws.quartile_low():
  {==}

def Laws.quartile_high():
  {==}

def Laws.quantile_min():
  {==}

def Laws.quantile_max():
  {==}

def Laws.percentile_90():
  {==}

def Laws.quantile_past_one():
  {==}

def Laws.quantile_zero_q():
  {==}

def Laws.quantile_big_q():
  {==}

def Laws.histogram():
  {==}

def Laws.histogram_no_bins():
  {==}

def Laws.regression_exact():
  {==}

def Laws.regression():
  {==}

def Laws.regression_flat_x():
  {==}

def Laws.regression_one():
  {==}

def Laws.regression_lengths():
  {==}

def Laws.gcd():
  {==}

def Laws.gcd_zero():
  {==}

def Laws.gcd_zero_zero():
  {==}

def Laws.gcd_fib():
  {==}

def Laws.lcm():
  {==}

def Laws.lcm_zero():
  {==}

def Laws.lcm_max():
  {==}

def Laws.lcm_overflow():
  {==}

def Laws.isqrt_zero():
  {==}

def Laws.isqrt_below():
  {==}

def Laws.isqrt_square():
  {==}

def Laws.isqrt_max():
  {==}

def min_comm(+a: U32, +b: U32) -> {U32.min(a, b) == U32.min(b, a) : U32}:
  U.u32_to_nat_inj(U32.min(a, b), U32.min(b, a),
    Equal.trans(Nat, U32.to_nat(U32.min(a, b)), Nat.min(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(U32.min(b, a)),
      U.u32_min_to_nat(a, b),
      Equal.trans(Nat, Nat.min(U32.to_nat(a), U32.to_nat(b)), Nat.min(U32.to_nat(b), U32.to_nat(a)), U32.to_nat(U32.min(b, a)),
        N.min_comm(U32.to_nat(a), U32.to_nat(b)),
        Equal.sym(Nat, U32.to_nat(U32.min(b, a)), Nat.min(U32.to_nat(b), U32.to_nat(a)), U.u32_min_to_nat(b, a)))))

def max_comm(+a: U32, +b: U32) -> {U32.max(a, b) == U32.max(b, a) : U32}:
  U.u32_to_nat_inj(U32.max(a, b), U32.max(b, a),
    Equal.trans(Nat, U32.to_nat(U32.max(a, b)), Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(U32.max(b, a)),
      U.u32_max_to_nat(a, b),
      Equal.trans(Nat, Nat.max(U32.to_nat(a), U32.to_nat(b)), Nat.max(U32.to_nat(b), U32.to_nat(a)), U32.to_nat(U32.max(b, a)),
        N.max_comm(U32.to_nat(a), U32.to_nat(b)),
        Equal.sym(Nat, U32.to_nat(U32.max(b, a)), Nat.max(U32.to_nat(b), U32.to_nat(a)), U.u32_max_to_nat(b, a)))))

def Laws.gcd_symmetric(a, b):
  %Equal.sym(U32, U32.min(a, b), U32.min(b, a), min_comm(a, b)) :
    {S.U32.gcd.go(48n, U32.is_zero(_), U32.max(a, b), _) == S.U32.gcd(b, a) : U32}
  %Equal.sym(U32, U32.max(a, b), U32.max(b, a), max_comm(a, b)) :
    {S.U32.gcd.go(48n, U32.is_zero(U32.min(b, a)), _, U32.min(b, a)) == S.U32.gcd(b, a) : U32}
  {==}
