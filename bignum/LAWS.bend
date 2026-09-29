import Base
import ./bigint.bend as Big
import ./decimal.bend as Dec
import ./rational.bend as Rat

# Both sides must compute to the same canonical value.
law add_carry:
  {Some{Big.BigInt.add(Big.BigInt.from_u32(4294967295), Big.BigInt.one())} ==
    Big.BigInt.read("4294967296") : Maybe<&2, Big.BigInt>}

law subtract_inverse:
  {Big.BigInt.sub(Big.BigInt.add(Big.BigInt.from_u32(17),
    Big.BigInt.from_u32(29)), Big.BigInt.from_u32(29)) ==
    Big.BigInt.from_u32(17) : Big.BigInt}

law signed_product:
  {Big.BigInt.mul(Big.BigInt.neg(Big.BigInt.from_u32(7)),
    Big.BigInt.from_u32(9)) ==
    Big.BigInt.neg(Big.BigInt.from_u32(63)) : Big.BigInt}

law divide_negative:
  {Big.BigInt.divmod(Big.BigInt.neg(Big.BigInt.from_u32(17)),
    Big.BigInt.from_u32(5)) ==
    Some{(Big.BigInt.neg(Big.BigInt.from_u32(3)),
      Big.BigInt.neg(Big.BigInt.from_u32(2)))} :
    Maybe<&1, Big.BigInt & Big.BigInt>}

law divide_by_zero:
  {Big.BigInt.divmod(Big.BigInt.one(), Big.BigInt.zero()) ==
    None{} : Maybe<&1, Big.BigInt & Big.BigInt>}

law power:
  {Big.BigInt.pow(Big.BigInt.from_u32(3), 5n) ==
    Big.BigInt.from_u32(243) : Big.BigInt}

law gcd_sign:
  {Big.BigInt.gcd(Big.BigInt.neg(Big.BigInt.from_u32(54)),
    Big.BigInt.from_u32(24)) == Big.BigInt.from_u32(6) : Big.BigInt}

law limb_roundtrip:
  {Big.BigInt.read(Big.BigInt.show(Big.BigInt.add(
    Big.BigInt.from_u32(4294967295), Big.BigInt.one()))) ==
    Some{Big.BigInt.add(Big.BigInt.from_u32(4294967295),
      Big.BigInt.one())} : Maybe<&2, Big.BigInt>}

law negative_roundtrip:
  {Big.BigInt.read(Big.BigInt.show(Big.BigInt.neg(
    Big.BigInt.from_u32(4294967295)))) ==
    Some{Big.BigInt.neg(Big.BigInt.from_u32(4294967295))} :
    Maybe<&2, Big.BigInt>}

law decimal_parse_exponent:
  {Dec.Decimal.read("12.50e-2") ==
    Some{Dec.Decimal{Big.BigInt.from_u32(1250), 4n}} :
    Maybe<&2, Dec.Decimal>}

law decimal_show_cents:
  {Dec.Decimal.show(Dec.Decimal{Big.BigInt.from_u32(125), 2n}) ==
    "1.25" : String}

law decimal_add_scale:
  {Dec.Decimal.add(Dec.Decimal{Big.BigInt.from_u32(125), 2n},
    Dec.Decimal{Big.BigInt.from_u32(5), 1n}) ==
    Dec.Decimal{Big.BigInt.from_u32(175), 2n} : Dec.Decimal}

law decimal_inexact_division:
  {Dec.Decimal.div_exact(Dec.Decimal{Big.BigInt.one(), 0n},
    Dec.Decimal{Big.BigInt.from_u32(3), 0n}) ==
    None{} : Maybe<&2, Dec.Decimal>}

law decimal_exact_division:
  {Dec.Decimal.div_exact(Dec.Decimal{Big.BigInt.one(), 0n},
    Dec.Decimal{Big.BigInt.from_u32(8), 0n}) ==
    Some{Dec.Decimal{Big.BigInt.from_u32(125), 3n}} :
    Maybe<&2, Dec.Decimal>}

law rational_reduce:
  {Rat.Rational.make(Big.BigInt.from_u32(2),
    Big.BigInt.from_u32(4)) ==
    Some{Rat.Rational{Big.BigInt.one(), Big.BigInt.from_u32(2)}} :
    Maybe<&2, Rat.Rational>}

law rational_sum:
  {Rat.Rational.add(Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(2)}, Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(3)}) ==
    Rat.Rational{Big.BigInt.from_u32(5),
      Big.BigInt.from_u32(6)} : Rat.Rational}

law rational_decimal_roundtrip:
  {Rat.Rational.read(Rat.Rational.show(Rat.Rational.from_decimal(
    Dec.Decimal{Big.BigInt.from_u32(125), 2n}))) ==
    Some{Rat.Rational{Big.BigInt.from_u32(5), Big.BigInt.from_u32(4)}} :
    Maybe<&2, Rat.Rational>}

law rational_repeating:
  {Rat.Rational.to_decimal(Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(3)}) == None{} :
    Maybe<&2, Dec.Decimal>}

law integer_abs:
  {Big.BigInt.abs(Big.BigInt.neg(Big.BigInt.from_u32(42))) ==
    Big.BigInt.from_u32(42) : Big.BigInt}

law integer_zero:
  {Big.BigInt.is_zero(Big.BigInt.sub(Big.BigInt.one(), Big.BigInt.one())) ==
    True{} : Bool}

law integer_order:
  {Big.BigInt.cmp(Big.BigInt.neg(Big.BigInt.one()), Big.BigInt.zero()) ==
    LT{} : Cmp}

law integer_modpower:
  {Big.BigInt.modpow(Big.BigInt.from_u32(4), Big.BigInt.from_u32(13),
    Big.BigInt.from_u32(497)) ==
    Some{Big.BigInt.from_u32(445)} : Maybe<&2, Big.BigInt>}

law decimal_zero:
  {Dec.Decimal.is_zero(Dec.Decimal.zero()) == True{} : Bool}

law decimal_negative:
  {Dec.Decimal.abs(Dec.Decimal.neg(Dec.Decimal{
    Big.BigInt.from_u32(25), 1n})) ==
    Dec.Decimal{Big.BigInt.from_u32(25), 1n} : Dec.Decimal}

law decimal_subtract:
  {Dec.Decimal.sub(Dec.Decimal{Big.BigInt.one(), 1n},
    Dec.Decimal{Big.BigInt.from_u32(30), 2n}) ==
    Dec.Decimal{Big.BigInt.neg(Big.BigInt.from_u32(20)), 2n} : Dec.Decimal}

law decimal_multiply:
  {Dec.Decimal.mul(Dec.Decimal{Big.BigInt.from_u32(15), 1n},
    Dec.Decimal{Big.BigInt.from_u32(2), 1n}) ==
    Dec.Decimal{Big.BigInt.from_u32(30), 2n} : Dec.Decimal}

law decimal_order:
  {Dec.Decimal.cmp(Dec.Decimal{Big.BigInt.from_u32(150), 2n},
    Dec.Decimal{Big.BigInt.from_u32(15), 1n}) == EQ{} : Cmp}

law decimal_normalize:
  {Dec.Decimal.normalize(Dec.Decimal{Big.BigInt.from_u32(1500), 3n}) ==
    Dec.Decimal{Big.BigInt.from_u32(15), 1n} : Dec.Decimal}

law decimal_rescale_exact:
  {Dec.Decimal.rescale(Dec.Decimal{Big.BigInt.from_u32(15), 1n}, 2n) ==
    Some{Dec.Decimal{Big.BigInt.from_u32(150), 2n}} :
    Maybe<&2, Dec.Decimal>}

law decimal_rescale_inexact:
  {Dec.Decimal.rescale(Dec.Decimal{Big.BigInt.from_u32(125), 2n}, 1n) ==
    None{} : Maybe<&2, Dec.Decimal>}

law decimal_fraction:
  {Dec.Decimal.from_fraction(Big.BigInt.one(), Big.BigInt.from_u32(4)) ==
    Some{Dec.Decimal{Big.BigInt.from_u32(25), 2n}} :
    Maybe<&2, Dec.Decimal>}

law rational_integer:
  {Rat.Rational.from_bigint(Big.BigInt.from_u32(9)) ==
    Rat.Rational{Big.BigInt.from_u32(9), Big.BigInt.one()} :
    Rat.Rational}

law rational_negative:
  {Rat.Rational.neg(Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(2)}) ==
    Rat.Rational{Big.BigInt.neg(Big.BigInt.one()),
      Big.BigInt.from_u32(2)} : Rat.Rational}

law rational_zero:
  {Rat.Rational.is_zero(Rat.Rational.from_bigint(Big.BigInt.zero())) ==
    True{} : Bool}

law rational_subtract:
  {Rat.Rational.sub(Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(2)}, Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(3)}) ==
    Rat.Rational{Big.BigInt.one(), Big.BigInt.from_u32(6)} :
    Rat.Rational}

law rational_multiply:
  {Rat.Rational.mul(Rat.Rational{Big.BigInt.from_u32(2),
    Big.BigInt.from_u32(3)}, Rat.Rational{Big.BigInt.from_u32(3),
    Big.BigInt.from_u32(4)}) ==
    Rat.Rational{Big.BigInt.one(), Big.BigInt.from_u32(2)} :
    Rat.Rational}

law rational_divide:
  {Rat.Rational.div(Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(2)}, Rat.Rational{Big.BigInt.from_u32(3),
    Big.BigInt.from_u32(4)}) ==
    Some{Rat.Rational{Big.BigInt.from_u32(2),
      Big.BigInt.from_u32(3)}} : Maybe<&2, Rat.Rational>}

law rational_divide_zero:
  {Rat.Rational.div(Rat.Rational.from_bigint(Big.BigInt.one()),
    Rat.Rational.from_bigint(Big.BigInt.zero())) ==
    None{} : Maybe<&2, Rat.Rational>}

law rational_order:
  {Rat.Rational.cmp(Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(3)}, Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(2)}) == LT{} : Cmp}

law rational_exact_decimal:
  {Rat.Rational.to_decimal(Rat.Rational{Big.BigInt.one(),
    Big.BigInt.from_u32(8)}) ==
    Some{Dec.Decimal{Big.BigInt.from_u32(125), 3n}} :
    Maybe<&2, Dec.Decimal>}
