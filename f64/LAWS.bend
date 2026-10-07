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
