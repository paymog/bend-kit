import Base
import ./int.bend as Int

def u8(x: U32) -> Int.U8:
  Int.U8.from_u32(x)

def u16(x: U32) -> Int.U16:
  Int.U16.from_u32(x)

def u64(x: U32) -> Int.U64:
  Int.U64.from_u32(x)

def i32(x: U32) -> Int.I32:
  Int.I32.from_u32(x)

def n32(x: U32) -> Int.I32:
  Int.I32.neg(Int.I32.from_u32(x))

def i64(x: U32) -> Int.I64:
  Int.I64.from_u32(x)

def n64(x: U32) -> Int.I64:
  Int.I64.neg(Int.I64.from_u32(x))

# 2^32 as a U64.
def u64.big() -> Int.U64:
  Int.U64.shl(u64(1), 32n)

# MAX + 1 in each mode: wrapping goes to MIN, checked fails, saturating stays.
law u8_add_wrap:
  {Int.U8.add(Int.U8.MAX(), u8(1)) == Int.U8.MIN() : Int.U8}

law u8_add_checked:
  {Int.U8.checked_add(Int.U8.MAX(), u8(1)) == None{} : Maybe<&2, Int.U8>}

law u8_add_checked_fits:
  {Int.U8.checked_add(u8(254), u8(1)) == Some{Int.U8.MAX()} :
    Maybe<&2, Int.U8>}

law u8_add_sat:
  {Int.U8.saturating_add(Int.U8.MAX(), u8(1)) == Int.U8.MAX() : Int.U8}

law u16_add_wrap:
  {Int.U16.add(Int.U16.MAX(), u16(1)) == Int.U16.MIN() : Int.U16}

law u16_add_checked:
  {Int.U16.checked_add(Int.U16.MAX(), u16(1)) == None{} : Maybe<&2, Int.U16>}

law u16_add_sat:
  {Int.U16.saturating_add(Int.U16.MAX(), u16(1)) == Int.U16.MAX() : Int.U16}

law u64_add_wrap:
  {Int.U64.add(Int.U64.MAX(), u64(1)) == Int.U64.MIN() : Int.U64}

law u64_add_checked:
  {Int.U64.checked_add(Int.U64.MAX(), u64(1)) == None{} : Maybe<&2, Int.U64>}

law u64_add_sat:
  {Int.U64.saturating_add(Int.U64.MAX(), u64(1)) == Int.U64.MAX() : Int.U64}

law i32_add_wrap:
  {Int.I32.add(Int.I32.MAX(), i32(1)) == Int.I32.MIN() : Int.I32}

law i32_add_checked:
  {Int.I32.checked_add(Int.I32.MAX(), i32(1)) == None{} : Maybe<&2, Int.I32>}

law i32_add_checked_neg:
  {Int.I32.checked_add(n32(1), i32(1)) == Some{i32(0)} : Maybe<&2, Int.I32>}

law i32_add_sat:
  {Int.I32.saturating_add(Int.I32.MAX(), i32(1)) == Int.I32.MAX() : Int.I32}

law i32_add_sat_low:
  {Int.I32.saturating_add(Int.I32.MIN(), n32(1)) == Int.I32.MIN() : Int.I32}

law i64_add_wrap:
  {Int.I64.add(Int.I64.MAX(), i64(1)) == Int.I64.MIN() : Int.I64}

law i64_add_checked:
  {Int.I64.checked_add(Int.I64.MAX(), i64(1)) == None{} : Maybe<&2, Int.I64>}

law i64_add_sat:
  {Int.I64.saturating_add(Int.I64.MAX(), i64(1)) == Int.I64.MAX() : Int.I64}

# MIN - 1 in each mode.
law u8_sub_wrap:
  {Int.U8.sub(Int.U8.MIN(), u8(1)) == Int.U8.MAX() : Int.U8}

law u8_sub_checked:
  {Int.U8.checked_sub(Int.U8.MIN(), u8(1)) == None{} : Maybe<&2, Int.U8>}

law u8_sub_sat:
  {Int.U8.saturating_sub(u8(3), u8(5)) == Int.U8.MIN() : Int.U8}

law u16_sub_checked:
  {Int.U16.checked_sub(u16(5), u16(3)) == Some{u16(2)} : Maybe<&2, Int.U16>}

law u64_sub_wrap:
  {Int.U64.sub(Int.U64.MIN(), u64(1)) == Int.U64.MAX() : Int.U64}

law u64_sub_sat:
  {Int.U64.saturating_sub(Int.U64.MIN(), u64(1)) == Int.U64.MIN() : Int.U64}

law i32_sub_wrap:
  {Int.I32.sub(Int.I32.MIN(), i32(1)) == Int.I32.MAX() : Int.I32}

law i32_sub_checked:
  {Int.I32.checked_sub(Int.I32.MIN(), i32(1)) == None{} : Maybe<&2, Int.I32>}

law i32_sub_sat_high:
  {Int.I32.saturating_sub(Int.I32.MAX(), n32(1)) == Int.I32.MAX() : Int.I32}

law i64_sub_sat:
  {Int.I64.saturating_sub(Int.I64.MIN(), i64(1)) == Int.I64.MIN() : Int.I64}

law i64_sub_checked:
  {Int.I64.checked_sub(Int.I64.MIN(), i64(1)) == None{} : Maybe<&2, Int.I64>}

# Products past MAX, and past MIN for signed.
law u8_mul_wrap:
  {Int.U8.mul(u8(16), u8(16)) == u8(0) : Int.U8}

law u8_mul_checked:
  {Int.U8.checked_mul(u8(16), u8(16)) == None{} : Maybe<&2, Int.U8>}

law u8_mul_checked_fits:
  {Int.U8.checked_mul(u8(15), u8(17)) == Some{Int.U8.MAX()} :
    Maybe<&2, Int.U8>}

law u16_mul_sat:
  {Int.U16.saturating_mul(u16(300), u16(300)) == Int.U16.MAX() : Int.U16}

law u64_mul_checked:
  {Int.U64.checked_mul(u64.big(), u64.big()) == None{} : Maybe<&2, Int.U64>}

law u64_mul_checked_fits:
  {Int.U64.checked_mul(u64.big(), u64(4294967295)) ==
    Some{Int.U64.sub(Int.U64.mul(u64.big(), u64.big()), u64.big())} :
    Maybe<&2, Int.U64>}

law i32_mul_sat_high:
  {Int.I32.saturating_mul(Int.I32.MAX(), i32(2)) == Int.I32.MAX() : Int.I32}

law i32_mul_sat_low:
  {Int.I32.saturating_mul(Int.I32.MAX(), n32(2)) == Int.I32.MIN() : Int.I32}

law i32_mul_checked_neg:
  {Int.I32.checked_mul(n32(3), n32(4)) == Some{i32(12)} : Maybe<&2, Int.I32>}

law i64_mul_wrap_min_neg1:
  {Int.I64.mul(Int.I64.MIN(), n64(1)) == Int.I64.MIN() : Int.I64}

law i64_mul_checked_min_neg1:
  {Int.I64.checked_mul(Int.I64.MIN(), n64(1)) == None{} : Maybe<&2, Int.I64>}

law i64_mul_sat_min_neg1:
  {Int.I64.saturating_mul(Int.I64.MIN(), n64(1)) == Int.I64.MAX() : Int.I64}

# Sign edges: MIN / -1 is the one quotient that overflows.
law i32_div_min_neg1:
  {Int.I32.div(Int.I32.MIN(), n32(1)) == Int.I32.MIN() : Int.I32}

law i32_mod_min_neg1:
  {Int.I32.mod(Int.I32.MIN(), n32(1)) == i32(0) : Int.I32}

law i32_checked_div_min_neg1:
  {Int.I32.checked_div(Int.I32.MIN(), n32(1)) == None{} : Maybe<&2, Int.I32>}

law i64_checked_mod_min_neg1:
  {Int.I64.checked_mod(Int.I64.MIN(), n64(1)) == None{} : Maybe<&2, Int.I64>}

law i64_checked_div_min_1:
  {Int.I64.checked_div(Int.I64.MIN(), i64(1)) == Some{Int.I64.MIN()} :
    Maybe<&2, Int.I64>}

law i32_neg_min:
  {Int.I32.neg(Int.I32.MIN()) == Int.I32.MIN() : Int.I32}

law i64_abs_min:
  {Int.I64.abs(Int.I64.MIN()) == Int.I64.MIN() : Int.I64}

law i64_abs_neg:
  {Int.I64.abs(n64(5)) == i64(5) : Int.I64}

law i32_is_neg:
  {Int.I32.is_neg(n32(1)) == True{} : Bool}

law i64_is_neg_zero:
  {Int.I64.is_neg(i64(0)) == False{} : Bool}

# Division truncates toward zero; the remainder takes the sign of the dividend.
law i32_div_nk:
  {Int.I32.div(n32(7), i32(2)) == n32(3) : Int.I32}

law i32_mod_nk:
  {Int.I32.mod(n32(7), i32(2)) == n32(1) : Int.I32}

law i32_div_kn:
  {Int.I32.div(i32(7), n32(2)) == n32(3) : Int.I32}

law i32_mod_kn:
  {Int.I32.mod(i32(7), n32(2)) == i32(1) : Int.I32}

law i64_div_nn:
  {Int.I64.div(n64(7), n64(2)) == i64(3) : Int.I64}

law i64_mod_nn:
  {Int.I64.mod(n64(7), n64(2)) == n64(1) : Int.I64}

law u8_div:
  {Int.U8.div(u8(255), u8(16)) == u8(15) : Int.U8}

law u16_mod:
  {Int.U16.mod(u16(65535), u16(256)) == u16(255) : Int.U16}

law u64_div_max:
  {Int.U64.div(Int.U64.MAX(), u64.big()) == u64(4294967295) : Int.U64}

law u64_mod_max:
  {Int.U64.mod(Int.U64.MAX(), u64(10)) == u64(5) : Int.U64}

# x / 0 is 0 and x % 0 is x, as in Base's U32; checked forms fail.
law u8_div_zero:
  {Int.U8.div(u8(9), u8(0)) == u8(0) : Int.U8}

law i32_mod_zero:
  {Int.I32.mod(n32(9), i32(0)) == n32(9) : Int.I32}

law u64_checked_div_zero:
  {Int.U64.checked_div(u64(9), u64(0)) == None{} : Maybe<&2, Int.U64>}

law u16_checked_mod_zero:
  {Int.U16.checked_mod(u16(9), u16(0)) == None{} : Maybe<&2, Int.U16>}

law u8_checked_mod:
  {Int.U8.checked_mod(u8(9), u8(4)) == Some{u8(1)} : Maybe<&2, Int.U8>}

# Signed order puts negatives first; unsigned order reads the same bits as large.
law i32_cmp_sign:
  {Int.I32.cmp(n32(1), i32(0)) == LT{} : Cmp}

law i64_cmp_min_max:
  {Int.I64.cmp(Int.I64.MIN(), Int.I64.MAX()) == LT{} : Cmp}

law u8_cmp_max:
  {Int.U8.cmp(Int.U8.MAX(), u8(0)) == GT{} : Cmp}

law u16_is_eq:
  {Int.U16.is_eq(u16(7), u16(7)) == True{} : Bool}

law u64_is_ne:
  {Int.U64.is_ne(u64(7), u64(8)) == True{} : Bool}

law i32_is_lt:
  {Int.I32.is_lt(Int.I32.MIN(), n32(1)) == True{} : Bool}

law i64_is_le:
  {Int.I64.is_le(n64(1), n64(1)) == True{} : Bool}

law u8_is_gt:
  {Int.U8.is_gt(u8(128), u8(127)) == True{} : Bool}

law i32_is_ge:
  {Int.I32.is_ge(i32(0), Int.I32.MAX()) == False{} : Bool}

law u64_is_zero:
  {Int.U64.is_zero(Int.U64.add(Int.U64.MAX(), u64(1))) == True{} : Bool}

# Bit operations and shifts.
law u16_and:
  {Int.U16.and(u16(65280), u16(4080)) == u16(3840) : Int.U16}

law u16_or:
  {Int.U16.or(u16(65280), u16(4080)) == u16(65520) : Int.U16}

law u8_xor:
  {Int.U8.xor(u8(255), u8(15)) == u8(240) : Int.U8}

law u64_not:
  {Int.U64.not(Int.U64.MIN()) == Int.U64.MAX() : Int.U64}

law i32_not:
  {Int.I32.not(i32(0)) == n32(1) : Int.I32}

law u8_shl:
  {Int.U8.shl(u8(1), 7n) == u8(128) : Int.U8}

law u8_shl_out:
  {Int.U8.shl(u8(1), 8n) == u8(0) : Int.U8}

law u64_shr:
  {Int.U64.shr(Int.U64.MAX(), 63n) == u64(1) : Int.U64}

law i64_shr_sign:
  {Int.I64.shr(Int.I64.MIN(), 63n) == n64(1) : Int.I64}

law i32_shr_neg:
  {Int.I32.shr(n32(8), 1n) == n32(4) : Int.I32}

law i32_shr_pos:
  {Int.I32.shr(Int.I32.MAX(), 30n) == i32(1) : Int.I32}

# Decimal text.
law u8_show_max:
  {Int.U8.show(Int.U8.MAX()) == "255" : String}

law u16_show_zero:
  {Int.U16.show(u16(0)) == "0" : String}

law u64_show_max:
  {Int.U64.show(Int.U64.MAX()) == "18446744073709551615" : String}

law i32_show_min:
  {Int.I32.show(Int.I32.MIN()) == "-2147483648" : String}

law i64_show_min:
  {Int.I64.show(Int.I64.MIN()) == "-9223372036854775808" : String}

law i64_show_max:
  {Int.I64.show(Int.I64.MAX()) == "9223372036854775807" : String}

law u8_read_max:
  {Int.U8.read("255") == Some{Int.U8.MAX()} : Maybe<&2, Int.U8>}

law u8_read_over:
  {Int.U8.read("256") == None{} : Maybe<&2, Int.U8>}

law u16_read_bad:
  {Int.U16.read("12a") == None{} : Maybe<&2, Int.U16>}

law u16_read_empty:
  {Int.U16.read("") == None{} : Maybe<&2, Int.U16>}

law u64_read_max:
  {Int.U64.read("18446744073709551615") == Some{Int.U64.MAX()} :
    Maybe<&2, Int.U64>}

law u64_read_over:
  {Int.U64.read("18446744073709551616") == None{} : Maybe<&2, Int.U64>}

law u64_read_neg:
  {Int.U64.read("-1") == None{} : Maybe<&2, Int.U64>}

law i32_read_min:
  {Int.I32.read("-2147483648") == Some{Int.I32.MIN()} : Maybe<&2, Int.I32>}

law i32_read_under:
  {Int.I32.read("-2147483649") == None{} : Maybe<&2, Int.I32>}

law i32_read_over:
  {Int.I32.read("2147483648") == None{} : Maybe<&2, Int.I32>}

law i32_read_dash:
  {Int.I32.read("-") == None{} : Maybe<&2, Int.I32>}

law i64_read_max:
  {Int.I64.read("9223372036854775807") == Some{Int.I64.MAX()} :
    Maybe<&2, Int.I64>}

law i64_read_neg:
  {Int.I64.read("-42") == Some{n64(42)} : Maybe<&2, Int.I64>}

law i64_read_roundtrip:
  {Int.I64.read(Int.I64.show(Int.I64.MIN())) == Some{Int.I64.MIN()} :
    Maybe<&2, Int.I64>}

# Conversions: narrowing truncates, signed widening sign-extends.
law u8_u32_roundtrip:
  {Int.U8.from_u32(Int.U8.to_u32(Int.U8.MAX())) == Int.U8.MAX() : Int.U8}

law u8_from_u32_wraps:
  {Int.U8.from_u32(256) == u8(0) : Int.U8}

law u16_u32_roundtrip:
  {Int.U16.to_u32(Int.U16.from_u32(65535)) == 65535 : U32}

law u64_u32_roundtrip:
  {Int.U64.to_u32(Int.U64.from_u32(4294967295)) == 4294967295 : U32}

law u64_to_u32_truncates:
  {Int.U64.to_u32(Int.U64.MAX()) == 4294967295 : U32}

law i32_u32_roundtrip:
  {Int.I32.from_u32(Int.I32.to_u32(Int.I32.MIN())) == Int.I32.MIN() : Int.I32}

law i32_to_u32_neg:
  {Int.I32.to_u32(n32(1)) == 4294967295 : U32}

law i64_to_u32_neg:
  {Int.I64.to_u32(n64(1)) == 4294967295 : U32}

law i64_u32_roundtrip:
  {Int.I64.to_u32(Int.I64.from_u32(123456789)) == 123456789 : U32}

law u8_nat_roundtrip:
  {Int.U8.from_nat(Int.U8.to_nat(Int.U8.MAX())) == Int.U8.MAX() : Int.U8}

law u8_from_nat_wraps:
  {Int.U8.from_nat(257n) == u8(1) : Int.U8}

law u16_to_nat:
  {Int.U16.to_nat(Int.U16.from_u32(1000)) == 1000n : Nat}

# A Nat literal near 2^32 overflows the checker's stack, so these stay small.
law u64_nat_roundtrip:
  {Int.U64.to_nat(Int.U64.from_nat(1000n)) == 1000n : Nat}

law i32_nat_roundtrip:
  {Int.I32.to_nat(Int.I32.from_nat(1000n)) == Some{1000n} :
    Maybe<&2, Nat>}

law i32_to_nat_neg:
  {Int.I32.to_nat(n32(1)) == None{} : Maybe<&2, Nat>}

law i64_to_nat_neg:
  {Int.I64.to_nat(Int.I64.MIN()) == None{} : Maybe<&2, Nat>}

law i64_from_nat:
  {Int.I64.from_nat(7n) == i64(7) : Int.I64}
