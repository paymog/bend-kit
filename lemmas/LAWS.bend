import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./lemmas.bend as Lemmas

# A word of n bits has a value below 2^n.
law word_to_nat_lt:
  for n: Nat
  for w: Word(n)
  MNat.lt(Word.to_nat(n, w), Lemmas.pow2(n))

# Two words with the same value are the same word.
law word_to_nat_inj:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for h: {Word.to_nat(n, a) == Word.to_nat(n, b) : Nat}
  {a == b : Word(n)}

# Comparing two words compares their values.
law word_cmp_nat:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  {Word.cmp(n, a, b) == Nat.cmp(Word.to_nat(n, a), Word.to_nat(n, b)) : Cmp}

# The adder is exact: the word sum plus the carry-out weight 2^n is c + a + b.
law word_adc_nat:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for c: Bool
  {Nat.add(Word.to_nat(n, Word.adc(n, a, b, False{}, c)),
    Lemmas.scale(Lemmas.carry(n, a, b, c), Lemmas.pow2(n))) ==
    Nat.add(Lemmas.b2n(c), Nat.add(Word.to_nat(n, a), Word.to_nat(n, b))) : Nat}

# Addition without overflow is exact.
law word_add_nat:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for h: MNat.lt(Nat.add(Word.to_nat(n, a), Word.to_nat(n, b)), Lemmas.pow2(n))
  {Word.to_nat(n, Word.add(n, a, b)) == Nat.add(Word.to_nat(n, a), Word.to_nat(n, b)) : Nat}

# Addition wraps modulo 2^n.
law word_add_mod:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  {Word.to_nat(n, Word.add(n, a, b)) ==
    Nat.mod(Nat.add(Word.to_nat(n, a), Word.to_nat(n, b)), Lemmas.pow2(n)) : Nat}

# The bitwise complement of w has value 2^n - 1 - w.
law word_not_nat:
  for n: Nat
  for w: Word(n)
  {1n+Nat.add(Word.to_nat(n, Word.not(n, w)), Word.to_nat(n, w)) == Lemmas.pow2(n) : Nat}

# Subtraction without wrap is exact.
law word_sub_nat:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for h: MNat.le(Word.to_nat(n, b), Word.to_nat(n, a))
  {Word.to_nat(n, Word.sub(n, a, b)) == Nat.sub(Word.to_nat(n, a), Word.to_nat(n, b)) : Nat}

# Incrementing without overflow adds one.
law word_inc_nat:
  for n: Nat
  for w: Word(n)
  for h: MNat.lt(1n+Word.to_nat(n, w), Lemmas.pow2(n))
  {Word.to_nat(n, Word.inc(n, w)) == 1n+Word.to_nat(n, w) : Nat}

# A U32 has a value below 2^32.
law u32_to_nat_lt:
  for a: U32
  MNat.lt(U32.to_nat(a), Lemmas.pow2(32n))

# Two U32s with the same value are equal.
law u32_to_nat_inj:
  for a: U32
  for b: U32
  for h: {U32.to_nat(a) == U32.to_nat(b) : Nat}
  {a == b : U32}

# Comparison of U32s is comparison of their values.
law u32_cmp_nat:
  for a: U32
  for b: U32
  {U32.cmp(a, b) == Nat.cmp(U32.to_nat(a), U32.to_nat(b)) : Cmp}

law u32_is_lt_nat:
  for a: U32
  for b: U32
  {U32.is_lt(a, b) == Nat.is_lt(U32.to_nat(a), U32.to_nat(b)) : Bool}

law u32_is_le_nat:
  for a: U32
  for b: U32
  {U32.is_le(a, b) == Nat.is_le(U32.to_nat(a), U32.to_nat(b)) : Bool}

law u32_is_eq_nat:
  for a: U32
  for b: U32
  {U32.is_eq(a, b) == Nat.is_eq(U32.to_nat(a), U32.to_nat(b)) : Bool}

law u32_max_nat:
  for a: U32
  for b: U32
  {U32.to_nat(U32.max(a, b)) == Nat.max(U32.to_nat(a), U32.to_nat(b)) : Nat}

law u32_max_comm:
  for a: U32
  for b: U32
  {U32.max(a, b) == U32.max(b, a) : U32}

law u32_max_assoc:
  for a: U32
  for b: U32
  for c: U32
  {U32.max(U32.max(a, b), c) == U32.max(a, U32.max(b, c)) : U32}

law u32_max_self:
  for a: U32
  {U32.max(a, a) == a : U32}

law u32_le_max_l:
  for a: U32
  for b: U32
  {U32.is_le(a, U32.max(a, b)) == True{} : Bool}

law u32_le_max_r:
  for a: U32
  for b: U32
  {U32.is_le(b, U32.max(a, b)) == True{} : Bool}

law u32_max_le:
  for a: U32
  for b: U32
  for c: U32
  for ha: {U32.is_le(a, c) == True{} : Bool}
  for hb: {U32.is_le(b, c) == True{} : Bool}
  {U32.is_le(U32.max(a, b), c) == True{} : Bool}

# Addition without overflow is exact.
law u32_add_nat:
  for a: U32
  for b: U32
  for h: MNat.lt(Nat.add(U32.to_nat(a), U32.to_nat(b)), Lemmas.pow2(32n))
  {U32.to_nat(U32.add(a, b)) == Nat.add(U32.to_nat(a), U32.to_nat(b)) : Nat}

# Addition wraps modulo 2^32.
law u32_add_mod:
  for a: U32
  for b: U32
  {U32.to_nat(U32.add(a, b)) == Nat.mod(Nat.add(U32.to_nat(a), U32.to_nat(b)), Lemmas.pow2(32n)) : Nat}

# Subtraction without wrap is exact.
law u32_sub_nat:
  for a: U32
  for b: U32
  for h: MNat.le(U32.to_nat(b), U32.to_nat(a))
  {U32.to_nat(U32.sub(a, b)) == Nat.sub(U32.to_nat(a), U32.to_nat(b)) : Nat}

# Increment without overflow adds one.
law u32_inc_nat:
  for a: U32
  for h: MNat.lt(1n+U32.to_nat(a), Lemmas.pow2(32n))
  {U32.to_nat(U32.inc(a)) == 1n+U32.to_nat(a) : Nat}

# from_nat and to_nat are inverses below 2^32.
law u32_to_from_nat:
  for k: Nat
  for +h: MNat.lt(k, Lemmas.pow2(32n))
  {U32.to_nat(U32.from_nat(k)) == k : Nat}

law u32_from_to_nat:
  for +a: U32
  {U32.from_nat(U32.to_nat(a)) == a : U32}

# The overflow-safe bounds check n <= len and i <= len - n holds exactly when i + n <= len.
law u32_fits_nat:
  for +len: U32
  for +i: U32
  for +n: U32
  {Bool.and(U32.is_le(n, len), U32.is_le(i, U32.sub(len, n))) == Nat.is_le(Nat.add(U32.to_nat(i), U32.to_nat(n)), U32.to_nat(len)) : Bool}

law word_shl_put_nat:
  for +n: Nat
  for +c: Bool
  for +w: Word(n)
  {Nat.add(Word.to_nat(n, Word.shl.put(n, c, w)), Lemmas.scale(Lemmas.shl_carry(n, c, w), Lemmas.pow2(n))) ==
    Lemmas.bit(c, Word.to_nat(n, w)) : Nat}

law word_shl_out_nat:
  for +n: Nat
  for +c: Bool
  for +w: Word(n)
  {Lemmas.shl_value(n, Word.shl.out(n, c, w)) == Nat.add(Lemmas.b2n(c), Nat.double(Word.to_nat(n, w))) : Nat}

law word_shl_mod:
  for +n: Nat
  for +w: Word(n)
  {Word.to_nat(n, Word.shl(n, w)) == Nat.mod(Nat.double(Word.to_nat(n, w)), Lemmas.pow2(n)) : Nat}

law word_mul_go_nat:
  for +m: Nat
  for +n: Nat
  for +a: Word(m)
  for +b: Word(n)
  for +acc: Word(n)
  {Word.to_nat(n, Word.mul.go(n, m, a, b, acc)) ==
    Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(Word.to_nat(m, a), Word.to_nat(n, b))), Lemmas.pow2(n)) : Nat}

law word_mul_mod:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  {Word.to_nat(n, Word.mul(n, a, b)) == Nat.mod(Nat.mul(Word.to_nat(n, a), Word.to_nat(n, b)), Lemmas.pow2(n)) : Nat}

law u32_mul_mod:
  for +a: U32
  for +b: U32
  {U32.to_nat(U32.mul(a, b)) == Nat.mod(Nat.mul(U32.to_nat(a), U32.to_nat(b)), Lemmas.pow2(32n)) : Nat}

law u32_mul_nat:
  for +a: U32
  for +b: U32
  for h: MNat.lt(Nat.mul(U32.to_nat(a), U32.to_nat(b)), Lemmas.pow2(32n))
  {U32.to_nat(U32.mul(a, b)) == Nat.mul(U32.to_nat(a), U32.to_nat(b)) : Nat}

law word_sub_wrap:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for +h: MNat.lt(Word.to_nat(n, a), Word.to_nat(n, b))
  {Word.to_nat(n, Word.sub(n, a, b)) == Nat.sub(Nat.add(Word.to_nat(n, a), Lemmas.pow2(n)), Word.to_nat(n, b)) : Nat}

law u32_sub_wrap:
  for +a: U32
  for +b: U32
  for +h: MNat.lt(U32.to_nat(a), U32.to_nat(b))
  {U32.to_nat(U32.sub(a, b)) == Nat.sub(Nat.add(U32.to_nat(a), Lemmas.pow2(32n)), U32.to_nat(b)) : Nat}

law u32_divmod_go_nat:
  for +m: Nat
  for +a: Word(m)
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  Lemmas.divmod_spec(m, a, b, U32.divmod.go(m, a, b))

law u32_divmod_nat:
  for +a: U32
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  {Nat.add(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b))) == U32.to_nat(a) : Nat} &
    MNat.lt(U32.to_nat(U32.mod(a, b)), U32.to_nat(b))

law u32_div_nat:
  for +a: U32
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  {U32.to_nat(U32.div(a, b)) == Nat.div(U32.to_nat(a), U32.to_nat(b)) : Nat}

law u32_mod_nat:
  for +a: U32
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  {U32.to_nat(U32.mod(a, b)) == Nat.mod(U32.to_nat(a), U32.to_nat(b)) : Nat}

# XOR with the same word twice gives the word back.
law word_xor_twice:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  {Word.xor(n, Word.xor(n, a, b), b) == a : Word(n)}

law u32_xor_twice:
  for +a: U32
  for +b: U32
  {U32.xor(U32.xor(a, b), b) == a : U32}

# The quotient times the divisor plus the remainder rebuilds a U32.
law u32_div_mul_add_mod:
  for +a: U32
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  {U32.add(U32.mul(U32.div(a, b), b), U32.mod(a, b)) == a : U32}
