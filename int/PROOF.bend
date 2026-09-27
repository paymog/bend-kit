import Base
import ./int.bend as Int
import ./LAWS.bend as Laws

def Laws.u8_add_wrap():
  {==}

def Laws.u8_add_checked():
  {==}

def Laws.u8_add_checked_fits():
  {==}

def Laws.u8_add_sat():
  {==}

def Laws.u16_add_wrap():
  {==}

def Laws.u16_add_checked():
  {==}

def Laws.u16_add_sat():
  {==}

def Laws.u64_add_wrap():
  {==}

def Laws.u64_add_checked():
  {==}

def Laws.u64_add_sat():
  {==}

def Laws.i32_add_wrap():
  {==}

def Laws.i32_add_checked():
  {==}

def Laws.i32_add_checked_neg():
  {==}

def Laws.i32_add_sat():
  {==}

def Laws.i32_add_sat_low():
  {==}

def Laws.i64_add_wrap():
  {==}

def Laws.i64_add_checked():
  {==}

def Laws.i64_add_sat():
  {==}

def Laws.u8_sub_wrap():
  {==}

def Laws.u8_sub_checked():
  {==}

def Laws.u8_sub_sat():
  {==}

def Laws.u16_sub_checked():
  {==}

def Laws.u64_sub_wrap():
  {==}

def Laws.u64_sub_sat():
  {==}

def Laws.i32_sub_wrap():
  {==}

def Laws.i32_sub_checked():
  {==}

def Laws.i32_sub_sat_high():
  {==}

def Laws.i64_sub_sat():
  {==}

def Laws.i64_sub_checked():
  {==}

def Laws.u8_mul_wrap():
  {==}

def Laws.u8_mul_checked():
  {==}

def Laws.u8_mul_checked_fits():
  {==}

def Laws.u16_mul_sat():
  {==}

def Laws.u64_mul_checked():
  {==}

def Laws.u64_mul_checked_fits():
  {==}

def Laws.i32_mul_sat_high():
  {==}

def Laws.i32_mul_sat_low():
  {==}

def Laws.i32_mul_checked_neg():
  {==}

def Laws.i64_mul_wrap_min_neg1():
  {==}

def Laws.i64_mul_checked_min_neg1():
  {==}

def Laws.i64_mul_sat_min_neg1():
  {==}

def Laws.i32_div_min_neg1():
  {==}

def Laws.i32_mod_min_neg1():
  {==}

def Laws.i32_checked_div_min_neg1():
  {==}

def Laws.i64_checked_mod_min_neg1():
  {==}

def Laws.i64_checked_div_min_1():
  {==}

def Laws.i32_neg_min():
  {==}

def Laws.i64_abs_min():
  {==}

def Laws.i64_abs_neg():
  {==}

def Laws.i32_is_neg():
  {==}

def Laws.i64_is_neg_zero():
  {==}

def Laws.i32_div_nk():
  {==}

def Laws.i32_mod_nk():
  {==}

def Laws.i32_div_kn():
  {==}

def Laws.i32_mod_kn():
  {==}

def Laws.i64_div_nn():
  {==}

def Laws.i64_mod_nn():
  {==}

def Laws.u8_div():
  {==}

def Laws.u16_mod():
  {==}

def Laws.u64_div_max():
  {==}

def Laws.u64_mod_max():
  {==}

def Laws.u8_div_zero():
  {==}

def Laws.i32_mod_zero():
  {==}

def Laws.u64_checked_div_zero():
  {==}

def Laws.u16_checked_mod_zero():
  {==}

def Laws.u8_checked_mod():
  {==}

def Laws.i32_cmp_sign():
  {==}

def Laws.i64_cmp_min_max():
  {==}

def Laws.u8_cmp_max():
  {==}

def Laws.u16_is_eq():
  {==}

def Laws.u64_is_ne():
  {==}

def Laws.i32_is_lt():
  {==}

def Laws.i64_is_le():
  {==}

def Laws.u8_is_gt():
  {==}

def Laws.i32_is_ge():
  {==}

def Laws.u64_is_zero():
  {==}

def Laws.u16_and():
  {==}

def Laws.u16_or():
  {==}

def Laws.u8_xor():
  {==}

def Laws.u64_not():
  {==}

def Laws.i32_not():
  {==}

def Laws.u8_shl():
  {==}

def Laws.u8_shl_out():
  {==}

def Laws.u64_shr():
  {==}

def Laws.i64_shr_sign():
  {==}

def Laws.i32_shr_neg():
  {==}

def Laws.i32_shr_pos():
  {==}

def Laws.u8_show_max():
  {==}

def Laws.u16_show_zero():
  {==}

def Laws.u64_show_max():
  {==}

def Laws.i32_show_min():
  {==}

def Laws.i64_show_min():
  {==}

def Laws.i64_show_max():
  {==}

def Laws.u8_read_max():
  {==}

def Laws.u8_read_over():
  {==}

def Laws.u16_read_bad():
  {==}

def Laws.u16_read_empty():
  {==}

def Laws.u64_read_max():
  {==}

def Laws.u64_read_over():
  {==}

def Laws.u64_read_neg():
  {==}

def Laws.i32_read_min():
  {==}

def Laws.i32_read_under():
  {==}

def Laws.i32_read_over():
  {==}

def Laws.i32_read_dash():
  {==}

def Laws.i64_read_max():
  {==}

def Laws.i64_read_neg():
  {==}

def Laws.i64_read_roundtrip():
  {==}

def Laws.u8_show_bin():
  {==}

def Laws.u16_show_b36():
  {==}

def Laws.u32_show_hex():
  {==}

def Laws.i32_show_hex_min():
  {==}

def Laws.u64_show_b36():
  {==}

def Laws.i64_show_oct_min():
  {==}

def Laws.show_radix_clamps():
  {==}

def Laws.u8_read_hex_upper():
  {==}

def Laws.u8_read_plus():
  {==}

def Laws.u8_read_minus():
  {==}

def Laws.u8_read_bad_radix():
  {==}

def Laws.u8_read_digit_over_radix():
  {==}

def Laws.u32_read_hex_over():
  {==}

def Laws.i32_read_hex_min():
  {==}

def Laws.i32_read_hex_under():
  {==}

def Laws.i32_read_hex_over():
  {==}

def Laws.u64_read_b36_over():
  {==}

def Laws.i64_read_bin_sign():
  {==}

def Laws.u8_radix_roundtrip():
  {==}

def Laws.u16_radix_roundtrip():
  {==}

def Laws.u32_radix_roundtrip():
  {==}

def Laws.i32_radix_roundtrip():
  {==}

def Laws.u64_radix_roundtrip():
  {==}

def Laws.i64_radix_roundtrip():
  {==}

def Laws.u8_u32_roundtrip():
  {==}

def Laws.u8_from_u32_wraps():
  {==}

def Laws.u16_u32_roundtrip():
  {==}

def Laws.u64_u32_roundtrip():
  {==}

def Laws.u64_to_u32_truncates():
  {==}

def Laws.i32_u32_roundtrip():
  {==}

def Laws.i32_to_u32_neg():
  {==}

def Laws.i64_to_u32_neg():
  {==}

def Laws.i64_u32_roundtrip():
  {==}

def Laws.u8_nat_roundtrip():
  {==}

def Laws.u8_from_nat_wraps():
  {==}

def Laws.u16_to_nat():
  {==}

def Laws.u64_nat_roundtrip():
  {==}

def Laws.i32_nat_roundtrip():
  {==}

def Laws.i32_to_nat_neg():
  {==}

def Laws.i64_to_nat_neg():
  {==}

def Laws.i64_from_nat():
  {==}
