# Exact rational numbers over BigInt, always in lowest terms.
import Base
import ./bigint.bend as Big
import ./decimal.bend as Dec

# num / den with den > 0 and gcd(num, den) = 1, so zero is 0/1 and equal
# values are equal terms. Build one with make, from_bigint or from_decimal;
# the raw constructor does not normalize.
type Rational is Data:
  Rational{num: Big.BigInt, den: Big.BigInt}

def Rational.low(p: Big.BigInt & Big.BigInt) -> Rational:
  (n, d) = p
  Rational{n, d}

# n / d for a nonzero d.
def Rational.norm(n: Big.BigInt, d: Big.BigInt) -> Rational:
  Rational.low(Dec.Decimal.lowest(n, d))

def Rational.from_bigint(n: Big.BigInt) -> Rational:
  Rational{n, Big.BigInt.one()}

def Rational.make.if(z: Bool, n: Big.BigInt, d: Big.BigInt) ->
  Maybe<&2, Rational>:
  match z:
    case True{}:
      None{}
    case False{}:
      Some{Rational.norm(n, d)}

# n / d in lowest terms, or None when d is zero.
def Rational.make(n: Big.BigInt, +d: Big.BigInt) -> Maybe<&2, Rational>:
  Rational.make.if(Big.BigInt.is_zero(d), n, d)

def Rational.from_decimal(d: Dec.Decimal) -> Rational:
  match d:
    case Dec.Decimal{u, s}:
      Rational.norm(u, Dec.Decimal.pow10(s))

# The exact decimal, or None when it repeats (den has a factor besides 2, 5).
def Rational.to_decimal(r: Rational) -> Maybe<&2, Dec.Decimal>:
  match r:
    case Rational{n, d}:
      Dec.Decimal.from_fraction(n, d)

def Rational.neg(r: Rational) -> Rational:
  match r:
    case Rational{n, d}:
      Rational{Big.BigInt.neg(n), d}

def Rational.is_zero(r: Rational) -> Bool:
  match r:
    case Rational{n, d}:
      Big.BigInt.is_zero(n)

def Rational.add(a: Rational, b: Rational) -> Rational:
  match a b:
    case Rational{an, +ad} Rational{bn, +bd}:
      Rational.norm(Big.BigInt.add(Big.BigInt.mul(an, bd),
        Big.BigInt.mul(bn, ad)), Big.BigInt.mul(ad, bd))

def Rational.sub(a: Rational, b: Rational) -> Rational:
  Rational.add(a, Rational.neg(b))

def Rational.mul(a: Rational, b: Rational) -> Rational:
  match a b:
    case Rational{an, ad} Rational{bn, bd}:
      Rational.norm(Big.BigInt.mul(an, bn), Big.BigInt.mul(ad, bd))

# a / b, or None when b is zero.
def Rational.div(a: Rational, b: Rational) -> Maybe<&2, Rational>:
  match a b:
    case Rational{an, ad} Rational{bn, bd}:
      Rational.make(Big.BigInt.mul(an, bd), Big.BigInt.mul(ad, bn))

# Denominators are positive, so cross-multiplying keeps the order.
def Rational.cmp(a: Rational, b: Rational) -> Cmp:
  match a b:
    case Rational{an, ad} Rational{bn, bd}:
      Big.BigInt.cmp(Big.BigInt.mul(an, bd), Big.BigInt.mul(bn, ad))

def Rational.show.if(whole: Bool, n: Big.BigInt, d: Big.BigInt) -> String:
  match whole:
    case True{}:
      Big.BigInt.show(n)
    case False{}:
      Big.BigInt.show(n) ++ "/" ++ Big.BigInt.show(d)

# "n/d", or "n" when the denominator is 1.
def Rational.show(r: Rational) -> String:
  match r:
    case Rational{n, +d}:
      Rational.show.if(Dec.Decimal.is_one(d), n, d)

def Rational.read.frac(a: Maybe<&2, Big.BigInt>, b: Maybe<&2, Big.BigInt>) ->
  Maybe<&2, Rational>:
  match a b:
    case Some{n} Some{d}:
      Rational.make(n, d)
    case _ _:
      None{}

def Rational.read.dec(m: Maybe<&2, Dec.Decimal>) -> Maybe<&2, Rational>:
  match m:
    case Some{d}:
      Some{Rational.from_decimal(d)}
    case None{}:
      None{}

def Rational.read.parts(ps: List<&2, String>) -> Maybe<&2, Rational>:
  match ps:
    case Con{a, Nil{}}:
      Rational.read.dec(Dec.Decimal.read(a))
    case Con{a, Con{b, Nil{}}}:
      Rational.read.frac(Big.BigInt.read(a), Big.BigInt.read(b))
    case _:
      None{}

# "n/d" with BigInt sides (normalized; a zero d is None), or any number
# Decimal.read takes, such as "-1.25" or "3e-2".
def Rational.read(s: String) -> Maybe<&2, Rational>:
  Rational.read.parts(String.split(s, '/'))
