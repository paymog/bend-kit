import Base
import ./lemmas.bend as Lemmas
import ./LAWS.bend as Laws

def Laws.word_to_nat_lt(n, w):
  Lemmas.word_to_nat_lt(n, w)

def Laws.word_to_nat_inj(n, a, b, h):
  Lemmas.word_to_nat_inj(n, a, b, h)

def Laws.word_cmp_nat(n, a, b):
  Lemmas.word_cmp_nat(n, a, b)

def Laws.word_adc_nat(n, a, b, c):
  Lemmas.word_adc_nat(n, a, b, c)

def Laws.word_add_nat(n, a, b, h):
  Lemmas.word_add_nat(n, a, b, h)

def Laws.word_add_mod(n, a, b):
  Lemmas.word_add_mod(n, a, b)

def Laws.word_not_nat(n, w):
  Lemmas.word_not_nat(n, w)

def Laws.word_sub_nat(n, a, b, h):
  Lemmas.word_sub_nat(n, a, b, h)

def Laws.word_inc_nat(n, w, h):
  Lemmas.word_inc_nat(n, w, h)

def Laws.u32_to_nat_lt(a):
  Lemmas.u32_to_nat_lt(a)

def Laws.u32_to_nat_inj(a, b, h):
  Lemmas.u32_to_nat_inj(a, b, h)

def Laws.u32_cmp_nat(a, b):
  Lemmas.u32_cmp_nat(a, b)

def Laws.u32_is_lt_nat(a, b):
  Lemmas.u32_is_lt_nat(a, b)

def Laws.u32_is_le_nat(a, b):
  Lemmas.u32_is_le_nat(a, b)

def Laws.u32_is_eq_nat(a, b):
  Lemmas.u32_is_eq_nat(a, b)

def Laws.u32_add_nat(a, b, h):
  Lemmas.u32_add_nat(a, b, h)

def Laws.u32_add_mod(a, b):
  Lemmas.u32_add_mod(a, b)

def Laws.u32_sub_nat(a, b, h):
  Lemmas.u32_sub_nat(a, b, h)

def Laws.u32_inc_nat(a, h):
  Lemmas.u32_inc_nat(a, h)

def Laws.u32_to_from_nat(k, h):
  Lemmas.u32_to_from_nat(k, h)

def Laws.u32_from_to_nat(a):
  Lemmas.u32_from_to_nat(a)

def Laws.u32_fits_nat(len, i, n):
  Lemmas.u32_fits_nat(len, i, n)

def Laws.word_shl_put_nat(n, c, w):
  Lemmas.word_shl_put_nat(n, c, w)

def Laws.word_shl_out_nat(n, c, w):
  Lemmas.word_shl_out_nat(n, c, w)

def Laws.word_shl_mod(n, w):
  Lemmas.word_shl_mod(n, w)

def Laws.word_mul_go_nat(m, n, a, b, acc):
  Lemmas.word_mul_go_nat(m, n, a, b, acc)

def Laws.word_mul_mod(n, a, b):
  Lemmas.word_mul_mod(n, a, b)

def Laws.u32_mul_mod(a, b):
  Lemmas.u32_mul_mod(a, b)

def Laws.u32_mul_nat(a, b, h):
  Lemmas.u32_mul_nat(a, b, h)

def Laws.word_sub_wrap(n, a, b, h):
  Lemmas.word_sub_wrap(n, a, b, h)

def Laws.u32_sub_wrap(a, b, h):
  Lemmas.u32_sub_wrap(a, b, h)

def Laws.u32_divmod_go_nat(m, a, b, hb):
  Lemmas.u32_divmod_go_nat(m, a, b, hb)

def Laws.u32_divmod_nat(a, b, hb):
  Lemmas.u32_divmod_nat(a, b, hb)

def Laws.u32_div_nat(a, b, hb):
  Lemmas.u32_div_nat(a, b, hb)

def Laws.u32_mod_nat(a, b, hb):
  Lemmas.u32_mod_nat(a, b, hb)

def Laws.word_xor_twice(n, a, b):
  Lemmas.word_xor_twice(n, a, b)

def Laws.u32_xor_twice(a, b):
  Lemmas.u32_xor_twice(a, b)

def Laws.u32_div_mul_add_mod(a, b, hb):
  Lemmas.u32_div_mul_add_mod(a, b, hb)
