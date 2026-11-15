import Base
import ./f64.bend as F

def one() -> F.F64:
  F.F64.one()

def bits(hi: U32, lo: U32) -> F.F64:
  F.F64{hi, lo}

# 1 + 2^-53 is a tie. 1 is even, so the sum stays 1.
law add_tie:
  {F.F64.add(one(), bits(1017118720, 0)) == one() : F.F64}

law add_overflow:
  {F.F64.add(bits(2146435071, 4294967295), bits(2146435071, 4294967295)) == F.F64.inf() : F.F64}

law add_subnormal:
  {F.F64.add(bits(0, 1), bits(0, 1)) == bits(0, 2) : F.F64}

law add_cancel:
  {F.F64.add(one(), F.F64.neg(one())) == F.F64.zero() : F.F64}

law add_neg_zero:
  {F.F64.add(bits(2147483648, 0), bits(2147483648, 0)) == bits(2147483648, 0) : F.F64}

# (1 + 2^-52)^2 rounds to 1 + 2^-51.
law mul_round:
  {F.F64.mul(bits(1072693248, 1), bits(1072693248, 1)) == bits(1072693248, 2) : F.F64}

law mul_neg_zero:
  {F.F64.mul(bits(2147483648, 0), one()) == bits(2147483648, 0) : F.F64}

law div_third:
  {F.F64.div(one(), F.F64.from_u32(3)) == bits(1070945621, 1431655765) : F.F64}

law div_by_zero:
  {F.F64.div(one(), F.F64.zero()) == F.F64.inf() : F.F64}

law div_zero_zero:
  {F.F64.div(F.F64.zero(), F.F64.zero()) == F.F64.nan() : F.F64}

law inf_minus_inf:
  {F.F64.sub(F.F64.inf(), F.F64.inf()) == F.F64.nan() : F.F64}

law nan_add:
  {F.F64.add(F.F64.nan(), one()) == F.F64.nan() : F.F64}

law eq_signed_zero:
  {F.F64.is_eq(bits(2147483648, 0), F.F64.zero()) == True{} : Bool}

law nan_not_eq:
  {F.F64.is_eq(F.F64.nan(), F.F64.nan()) == False{} : Bool}

law lt_sign:
  {F.F64.is_lt(F.F64.neg(one()), one()) == True{} : Bool}

law from_u32:
  {F.F64.from_u32(3) == bits(1074266112, 0) : F.F64}

law is_subnormal:
  {F.F64.is_subnormal(bits(0, 1)) == True{} : Bool}

law show_one:
  {F.F64.show(one()) == "1.0" : String}

law show_tenth:
  {F.F64.show(bits(1069128089, 2576980378)) == "0.1" : String}

law show_big:
  {F.F64.show(bits(1128267776, 0)) == "9007199254740992.0" : String}

law show_sci:
  {F.F64.show(bits(1128383353, 937459712)) == "1e+16" : String}

law show_min_subnormal:
  {F.F64.show(bits(0, 1)) == "5e-324" : String}

law show_neg_zero:
  {F.F64.show(bits(2147483648, 0)) == "-0.0" : String}

law read_tenth:
  {F.F64.read("0.1") == Some{bits(1069128089, 2576980378)} : Maybe<&2, F.F64>}

# 2^53 + 1 is a tie. 2^53 is even, so it wins.
law read_tie:
  {F.F64.read("9007199254740993") == Some{bits(1128267776, 0)} : Maybe<&2, F.F64>}

law read_neg_exp:
  {F.F64.read("-2.5E-3") == Some{bits(3211033313, 1202590843)} : Maybe<&2, F.F64>}

law read_overflow:
  {F.F64.read("1.7976931348623159e308") == Some{F.F64.inf()} : Maybe<&2, F.F64>}

law read_inf:
  {F.F64.read("-Infinity") == Some{F.F64.neg(F.F64.inf())} : Maybe<&2, F.F64>}

law read_no_digits:
  {F.F64.read(".e5") == None{} : Maybe<&2, F.F64>}

law read_no_exp_digits:
  {F.F64.read("1e+") == None{} : Maybe<&2, F.F64>}

law sqrt_four:
  {F.F64.sqrt(bits(1074790400, 0)) == bits(1073741824, 0) : F.F64}

law sqrt_two:
  {F.F64.sqrt(bits(1073741824, 0)) == bits(1073127582, 1719614413) : F.F64}

law sqrt_min_subnormal:
  {F.F64.sqrt(bits(0, 1)) == bits(509607936, 0) : F.F64}

law sqrt_max_finite:
  {F.F64.sqrt(bits(2146435071, 4294967295)) == bits(1609564159, 4294967295) : F.F64}

law sqrt_neg_zero:
  {F.F64.sqrt(bits(2147483648, 0)) == bits(2147483648, 0) : F.F64}

law sqrt_negative:
  {F.F64.sqrt(F.F64.neg(one())) == F.F64.nan() : F.F64}

law sqrt_inf:
  {F.F64.sqrt(F.F64.inf()) == F.F64.inf() : F.F64}

law sqrt_neg_inf:
  {F.F64.sqrt(F.F64.neg(F.F64.inf())) == F.F64.nan() : F.F64}

law sqrt_nan:
  {F.F64.sqrt(F.F64.nan()) == F.F64.nan() : F.F64}

law floor_neg_half:
  {F.F64.floor(bits(3219128320, 0)) == bits(3220176896, 0) : F.F64}

law floor_pos_fraction:
  {F.F64.floor(bits(1074213683, 858993459)) == bits(1073741824, 0) : F.F64}

law floor_neg_fraction:
  {F.F64.floor(bits(3221697331, 858993459)) == bits(3221749760, 0) : F.F64}

law floor_pos_zero:
  {F.F64.floor(bits(0, 0)) == bits(0, 0) : F.F64}

law floor_neg_zero:
  {F.F64.floor(bits(2147483648, 0)) == bits(2147483648, 0) : F.F64}

law floor_below_large:
  {F.F64.floor(bits(1127219199, 4294967295)) == bits(1127219199, 4294967294) : F.F64}

law floor_large:
  {F.F64.floor(bits(1127219200, 0)) == bits(1127219200, 0) : F.F64}

law floor_above_large:
  {F.F64.floor(bits(1127219200, 1)) == bits(1127219200, 1) : F.F64}

law floor_neg_large:
  {F.F64.floor(bits(3274702848, 1)) == bits(3274702848, 1) : F.F64}

law floor_pos_subnormal:
  {F.F64.floor(bits(0, 1)) == bits(0, 0) : F.F64}

law floor_neg_subnormal:
  {F.F64.floor(bits(2147483648, 1)) == bits(3220176896, 0) : F.F64}

law floor_inf:
  {F.F64.floor(bits(2146435072, 0)) == bits(2146435072, 0) : F.F64}

law floor_neg_inf:
  {F.F64.floor(bits(4293918720, 0)) == bits(4293918720, 0) : F.F64}

law floor_signaling_nan:
  {F.F64.floor(bits(4293918720, 1)) == bits(2146959360, 0) : F.F64}

law ceil_neg_half:
  {F.F64.ceil(bits(3219128320, 0)) == bits(2147483648, 0) : F.F64}

law ceil_pos_fraction:
  {F.F64.ceil(bits(1074213683, 858993459)) == bits(1074266112, 0) : F.F64}

law ceil_neg_fraction:
  {F.F64.ceil(bits(3221697331, 858993459)) == bits(3221225472, 0) : F.F64}

law ceil_pos_zero:
  {F.F64.ceil(bits(0, 0)) == bits(0, 0) : F.F64}

law ceil_neg_zero:
  {F.F64.ceil(bits(2147483648, 0)) == bits(2147483648, 0) : F.F64}

law ceil_below_large:
  {F.F64.ceil(bits(1127219199, 4294967295)) == bits(1127219200, 0) : F.F64}

law ceil_large:
  {F.F64.ceil(bits(1127219200, 0)) == bits(1127219200, 0) : F.F64}

law ceil_above_large:
  {F.F64.ceil(bits(1127219200, 1)) == bits(1127219200, 1) : F.F64}

law ceil_neg_large:
  {F.F64.ceil(bits(3274702848, 1)) == bits(3274702848, 1) : F.F64}

law ceil_pos_subnormal:
  {F.F64.ceil(bits(0, 1)) == bits(1072693248, 0) : F.F64}

law ceil_neg_subnormal:
  {F.F64.ceil(bits(2147483648, 1)) == bits(2147483648, 0) : F.F64}

law ceil_inf:
  {F.F64.ceil(bits(2146435072, 0)) == bits(2146435072, 0) : F.F64}

law ceil_neg_inf:
  {F.F64.ceil(bits(4293918720, 0)) == bits(4293918720, 0) : F.F64}

law ceil_signaling_nan:
  {F.F64.ceil(bits(4293918720, 1)) == bits(2146959360, 0) : F.F64}

law trunc_neg_half:
  {F.F64.trunc(bits(3219128320, 0)) == bits(2147483648, 0) : F.F64}

law trunc_pos_fraction:
  {F.F64.trunc(bits(1074213683, 858993459)) == bits(1073741824, 0) : F.F64}

law trunc_neg_fraction:
  {F.F64.trunc(bits(3221697331, 858993459)) == bits(3221225472, 0) : F.F64}

law trunc_pos_zero:
  {F.F64.trunc(bits(0, 0)) == bits(0, 0) : F.F64}

law trunc_neg_zero:
  {F.F64.trunc(bits(2147483648, 0)) == bits(2147483648, 0) : F.F64}

law trunc_below_large:
  {F.F64.trunc(bits(1127219199, 4294967295)) == bits(1127219199, 4294967294) : F.F64}

law trunc_large:
  {F.F64.trunc(bits(1127219200, 0)) == bits(1127219200, 0) : F.F64}

law trunc_above_large:
  {F.F64.trunc(bits(1127219200, 1)) == bits(1127219200, 1) : F.F64}

law trunc_neg_large:
  {F.F64.trunc(bits(3274702848, 1)) == bits(3274702848, 1) : F.F64}

law trunc_pos_subnormal:
  {F.F64.trunc(bits(0, 1)) == bits(0, 0) : F.F64}

law trunc_neg_subnormal:
  {F.F64.trunc(bits(2147483648, 1)) == bits(2147483648, 0) : F.F64}

law trunc_inf:
  {F.F64.trunc(bits(2146435072, 0)) == bits(2146435072, 0) : F.F64}

law trunc_neg_inf:
  {F.F64.trunc(bits(4293918720, 0)) == bits(4293918720, 0) : F.F64}

law trunc_signaling_nan:
  {F.F64.trunc(bits(4293918720, 1)) == bits(2146959360, 0) : F.F64}

law to_u32_max:
  {F.F64.to_u32(bits(1106247679, 4292870144)) == Some{4294967295} : Maybe<&2, U32>}

law to_u32_overflow:
  {F.F64.to_u32(bits(1106247680, 0)) == None{} : Maybe<&2, U32>}

law to_u32_neg_half:
  {F.F64.to_u32(bits(3219128320, 0)) == Some{0} : Maybe<&2, U32>}

law to_u32_neg_one:
  {F.F64.to_u32(bits(3220176896, 0)) == None{} : Maybe<&2, U32>}

law to_u32_nan:
  {F.F64.to_u32(bits(2146959360, 0)) == None{} : Maybe<&2, U32>}

law to_u32_inf:
  {F.F64.to_u32(bits(2146435072, 0)) == None{} : Maybe<&2, U32>}

law to_u32_neg_inf:
  {F.F64.to_u32(bits(4293918720, 0)) == None{} : Maybe<&2, U32>}

law to_u32_fraction:
  {F.F64.to_u32(bits(1074213683, 858993459)) == Some{2} : Maybe<&2, U32>}

law to_u32_word_boundary:
  {F.F64.to_u32(bits(1093664768, 3221225472)) == Some{1048576} : Maybe<&2, U32>}

law to_u32_subnormal:
  {F.F64.to_u32(bits(2147483648, 1)) == Some{0} : Maybe<&2, U32>}
