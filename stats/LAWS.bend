import Base
import bend-kit-f64@0.1.1.0/f64.bend as F
import ./stats.bend as S

def n(k: U32) -> F.F64:
  F.F64.from_u32(k)

def bits(hi: U32, lo: U32) -> F.F64:
  F.F64{hi, lo}

# Sorted, this is 2 4 4 4 5 5 7 9: mean 5, population variance 4.
def data() -> List<&2, F.F64>:
  [n(5), n(2), n(9), n(4), n(7), n(4), n(5), n(4)]

def ten() -> List<&2, F.F64>:
  [n(1), n(2), n(3), n(4), n(5), n(6), n(7), n(8), n(9), n(10)]

def none() -> List<&2, F.F64>:
  Nil{}

law sum:
  {S.Stats.sum(data()) == n(40) : F.F64}

law sum_empty:
  {S.Stats.sum(none()) == F.F64.zero() : F.F64}

law mean:
  {S.Stats.mean(data()) == Some{n(5)} : Maybe<&2, F.F64>}

law mean_empty:
  {S.Stats.mean(none()) == None{} : Maybe<&2, F.F64>}

law pvariance:
  {S.Stats.pvariance(data()) == Some{n(4)} : Maybe<&2, F.F64>}

law pvariance_one:
  {S.Stats.pvariance([n(7)]) == Some{F.F64.zero()} : Maybe<&2, F.F64>}

# 32 / 7, rounded: 4.571428571428571.
law variance:
  {S.Stats.variance(data()) == Some{bits(1074940196, 2454267026)} : Maybe<&2, F.F64>}

law variance_one:
  {S.Stats.variance([n(7)]) == None{} : Maybe<&2, F.F64>}

law median_even:
  {S.Stats.median(data()) == Some{bits(1074921472, 0)} : Maybe<&2, F.F64>}

law median_odd:
  {S.Stats.median([n(3), n(1), n(2)]) == Some{n(2)} : Maybe<&2, F.F64>}

law median_empty:
  {S.Stats.median(none()) == None{} : Maybe<&2, F.F64>}

law quartile_low:
  {S.Stats.quantile(data(), 1, 4) == Some{n(4)} : Maybe<&2, F.F64>}

# Rank 5.25: 5 + 0.25 * (7 - 5).
law quartile_high:
  {S.Stats.quantile(data(), 3, 4) == Some{bits(1075183616, 0)} : Maybe<&2, F.F64>}

law quantile_min:
  {S.Stats.quantile(data(), 0, 1) == Some{n(2)} : Maybe<&2, F.F64>}

law quantile_max:
  {S.Stats.quantile(data(), 1, 1) == Some{n(9)} : Maybe<&2, F.F64>}

# Rank 8.1: 9 + 0.1 * (10 - 9), as NumPy gives 9.1.
law percentile_90:
  {S.Stats.quantile(ten(), 90, 100) == Some{bits(1075983155, 858993459)} : Maybe<&2, F.F64>}

law quantile_past_one:
  {S.Stats.quantile(data(), 5, 4) == None{} : Maybe<&2, F.F64>}

law quantile_zero_q:
  {S.Stats.quantile(data(), 0, 0) == None{} : Maybe<&2, F.F64>}

law quantile_big_q:
  {S.Stats.quantile(data(), 1, 65537) == None{} : Maybe<&2, F.F64>}

# 10 lands in the closed last bin; 11 and -1 land in no bin.
law histogram:
  {S.Stats.histogram([n(0), n(2), n(4), n(6), n(8), n(10)], [n(10), n(11), F.F64.neg(n(1)), n(5), n(2), n(9), n(4), n(7), n(4), n(5), n(4)]) == [0, 1, 5, 1, 2] : List<&2, U32>}

law histogram_no_bins:
  {S.Stats.histogram([n(0)], data()) == Nil{} : List<&2, U32>}

law regression_exact:
  {S.Stats.linear_regression([n(1), n(2), n(3), n(4)], [n(3), n(5), n(7), n(9)]) == Some{S.Fit{n(2), n(1)}} : Maybe<&2, S.Fit>}

# Python's statistics.linear_regression gives slope 0.6 and intercept 2.2.
law regression:
  {S.Stats.linear_regression([n(1), n(2), n(3), n(4), n(5)], [n(2), n(4), n(5), n(4), n(5)]) == Some{S.Fit{bits(1071854387, 858993459), bits(1073846681, 2576980378)}} : Maybe<&2, S.Fit>}

law regression_flat_x:
  {S.Stats.linear_regression([n(3), n(3)], [n(1), n(2)]) == None{} : Maybe<&2, S.Fit>}

law regression_one:
  {S.Stats.linear_regression([n(1)], [n(1)]) == None{} : Maybe<&2, S.Fit>}

law regression_lengths:
  {S.Stats.linear_regression([n(1), n(2), n(3)], [n(1), n(2)]) == None{} : Maybe<&2, S.Fit>}

law gcd:
  {S.U32.gcd(12, 18) == 6 : U32}

law gcd_zero:
  {S.U32.gcd(0, 5) == 5 : U32}

law gcd_zero_zero:
  {S.U32.gcd(0, 0) == 0 : U32}

# The longest Euclid run below 2^32: consecutive Fibonacci numbers.
law gcd_fib:
  {S.U32.gcd(2971215073, 1836311903) == 1 : U32}

law lcm:
  {S.U32.lcm(4, 6) == Some{12} : Maybe<&2, U32>}

law lcm_zero:
  {S.U32.lcm(0, 5) == Some{0} : Maybe<&2, U32>}

law lcm_max:
  {S.U32.lcm(65535, 65537) == Some{4294967295} : Maybe<&2, U32>}

law lcm_overflow:
  {S.U32.lcm(65536, 65537) == None{} : Maybe<&2, U32>}

law isqrt_zero:
  {S.U32.isqrt(0) == 0 : U32}

law isqrt_below:
  {S.U32.isqrt(15) == 3 : U32}

law isqrt_square:
  {S.U32.isqrt(16) == 4 : U32}

law isqrt_max:
  {S.U32.isqrt(4294967295) == 65535 : U32}
