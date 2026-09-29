# Exact signed decimals: a BigInt coefficient over a power of ten.
import Base
import ./bigint.bend as Big

# The value is unscaled / 10^scale. Scale is kept as written, so 1.50 stays
# 1.50 (money keeps its cents); cmp is numeric, and normalize strips trailing
# zeros. No operation rounds: an inexact request answers None.
type Decimal is Data:
  Decimal{unscaled: Big.BigInt, scale: Nat}

def Decimal.zero() -> Decimal:
  Decimal{Big.BigInt.zero(), 0n}

def Decimal.pow10(n: Nat) -> Big.BigInt:
  Big.BigInt.pow(Big.BigInt.from_u32(10), n)

# u * 10^k, without a multiply when k is 0.
def Decimal.up(u: Big.BigInt, k: Nat) -> Big.BigInt:
  match k:
    case 0n:
      u
    case 1n+p:
      Big.BigInt.mul(u, Decimal.pow10(1n+p))

def Decimal.neg(d: Decimal) -> Decimal:
  match d:
    case Decimal{u, s}:
      Decimal{Big.BigInt.neg(u), s}

def Decimal.abs(d: Decimal) -> Decimal:
  match d:
    case Decimal{u, s}:
      Decimal{Big.BigInt.abs(u), s}

def Decimal.is_zero(d: Decimal) -> Bool:
  match d:
    case Decimal{u, s}:
      Big.BigInt.is_zero(u)

def Decimal.add(a: Decimal, b: Decimal) -> Decimal:
  match a b:
    case Decimal{ua, +sa} Decimal{ub, +sb}:
      Decimal{Big.BigInt.add(Decimal.up(ua, Nat.sub(sb, sa)),
        Decimal.up(ub, Nat.sub(sa, sb))), Nat.max(sa, sb)}

def Decimal.sub(a: Decimal, b: Decimal) -> Decimal:
  Decimal.add(a, Decimal.neg(b))

def Decimal.mul(a: Decimal, b: Decimal) -> Decimal:
  match a b:
    case Decimal{ua, sa} Decimal{ub, sb}:
      Decimal{Big.BigInt.mul(ua, ub), Nat.add(sa, sb)}

def Decimal.cmp(a: Decimal, b: Decimal) -> Cmp:
  match a b:
    case Decimal{ua, +sa} Decimal{ub, +sb}:
      Big.BigInt.cmp(Decimal.up(ua, Nat.sub(sb, sa)),
        Decimal.up(ub, Nat.sub(sa, sb)))

# The quotient of a division whose divisor is known to be nonzero.
def Decimal.quot(m: Maybe<&1, Big.BigInt & Big.BigInt>) -> Big.BigInt:
  match m:
    case Some{(q, r)}:
      q
    case None{}:
      Big.BigInt.zero()

# (remainder is zero, quotient) of u / k, for a nonzero k.
def Decimal.divk.m(m: Maybe<&1, Big.BigInt & Big.BigInt>) -> Bool & Big.BigInt:
  match m:
    case Some{(q, r)}:
      (Big.BigInt.is_zero(r), q)
    case None{}:
      (False{}, Big.BigInt.zero())

def Decimal.divk(u: Big.BigInt, k: U32) -> Bool & Big.BigInt:
  Decimal.divk.m(Big.BigInt.divmod(u, Big.BigInt.from_u32(k)))

def Decimal.is_one(u: Big.BigInt) -> Bool:
  Cmp.is_eq(Big.BigInt.cmp(u, Big.BigInt.one()))

def Decimal.lowest.fix(neg: Bool, n: Big.BigInt, d: Big.BigInt) ->
  Big.BigInt & Big.BigInt:
  match neg:
    case True{}:
      (Big.BigInt.neg(n), Big.BigInt.neg(d))
    case False{}:
      (n, d)

def Decimal.lowest.den(n: Big.BigInt, +d: Big.BigInt) -> Big.BigInt & Big.BigInt:
  Decimal.lowest.fix(Cmp.is_lt(Big.BigInt.cmp(d, Big.BigInt.zero())), n, d)

def Decimal.lowest.by(n: Big.BigInt, d: Big.BigInt, +g: Big.BigInt) ->
  Big.BigInt & Big.BigInt:
  Decimal.lowest.den(Decimal.quot(Big.BigInt.divmod(n, g)),
    Decimal.quot(Big.BigInt.divmod(d, g)))

# n / d in lowest terms with a positive denominator; d must be nonzero.
def Decimal.lowest(+n: Big.BigInt, +d: Big.BigInt) -> Big.BigInt & Big.BigInt:
  Decimal.lowest.by(n, d, Big.BigInt.gcd(n, d))

# Each step divides d by 2 or 5 and scales n to match, so a d of D digits
# needs fewer than 4D steps; f is that bound.
def Decimal.frac.go(f: Nat, n: Big.BigInt, k: Nat, one: Bool,
  t2: Bool & Big.BigInt, t5: Bool & Big.BigInt) -> Maybe<&2, Decimal>:
  match f:
    case 0n:
      None{}
    case 1n+g:
      match one:
        case True{}:
          Some{Decimal{n, k}}
        case False{}:
          (z2, q2) = t2
          match z2:
            case True{}:
              +d = {q2 : Big.BigInt}
              Decimal.frac.go(g, Big.BigInt.mul(n, Big.BigInt.from_u32(5)),
                1n+k, Decimal.is_one(d), Decimal.divk(d, 2),
                Decimal.divk(d, 5))
            case False{}:
              (z5, q5) = t5
              match z5:
                case True{}:
                  +d = {q5 : Big.BigInt}
                  Decimal.frac.go(g, Big.BigInt.mul(n, Big.BigInt.from_u32(2)),
                    1n+k, Decimal.is_one(d), Decimal.divk(d, 2),
                    Decimal.divk(d, 5))
                case False{}:
                  None{}

def Decimal.frac.run(p: Big.BigInt & Big.BigInt) -> Maybe<&2, Decimal>:
  (n, d) = p
  +e = {d : Big.BigInt}
  Decimal.frac.go(
    (4n * String.length(Big.BigInt.show(e)) + 1n : Nat),
    n, 0n, Decimal.is_one(e), Decimal.divk(e, 2), Decimal.divk(e, 5))

def Decimal.frac.if(z: Bool, n: Big.BigInt, d: Big.BigInt) ->
  Maybe<&2, Decimal>:
  match z:
    case True{}:
      None{}
    case False{}:
      Decimal.frac.run(Decimal.lowest(n, d))

# n / d at the smallest exact scale, or None when d is zero or the decimal
# expansion does not terminate (d has a prime factor other than 2 and 5).
def Decimal.from_fraction(n: Big.BigInt, +d: Big.BigInt) -> Maybe<&2, Decimal>:
  Decimal.frac.if(Big.BigInt.is_zero(d), n, d)

# a / b exactly, at the smallest scale that holds it; None for a zero
# divisor or a repeating quotient (use Rational for those).
def Decimal.div_exact(a: Decimal, b: Decimal) -> Maybe<&2, Decimal>:
  match a b:
    case Decimal{ua, sa} Decimal{ub, sb}:
      Decimal.from_fraction(Big.BigInt.mul(ua, Decimal.pow10(sb)),
        Big.BigInt.mul(ub, Decimal.pow10(sa)))

def Decimal.normalize.go(s: Nat, u: Big.BigInt, qr: Bool & Big.BigInt) ->
  Decimal:
  match s:
    case 0n:
      Decimal{u, 0n}
    case 1n+p:
      (z, q) = qr
      match z:
        case True{}:
          +v = {q : Big.BigInt}
          Decimal.normalize.go(p, v, Decimal.divk(v, 10))
        case False{}:
          Decimal{u, 1n+p}

# The same value at the smallest scale: 1.500 is 1.5, 0.00 is 0.
def Decimal.normalize(d: Decimal) -> Decimal:
  match d:
    case Decimal{+u, s}:
      Decimal.normalize.go(s, u, Decimal.divk(u, 10))

def Decimal.rescale.keep(z: Bool, q: Big.BigInt, t: Nat) -> Maybe<&2, Decimal>:
  match z:
    case True{}:
      Some{Decimal{q, t}}
    case False{}:
      None{}

def Decimal.rescale.cut(t: Nat, m: Maybe<&1, Big.BigInt & Big.BigInt>) ->
  Maybe<&2, Decimal>:
  match m:
    case Some{(q, r)}:
      Decimal.rescale.keep(Big.BigInt.is_zero(r), q, t)
    case None{}:
      None{}

def Decimal.rescale.if(up: Bool, u: Big.BigInt, +s: Nat, +t: Nat) ->
  Maybe<&2, Decimal>:
  match up:
    case True{}:
      Some{Decimal{Decimal.up(u, Nat.sub(t, s)), t}}
    case False{}:
      Decimal.rescale.cut(t, Big.BigInt.divmod(u, Decimal.pow10(Nat.sub(s, t))))

# The same value at scale t, or None when that would drop a nonzero digit:
# rescale(1.5, 2n) is 1.50; rescale(1.25, 1n) is None, never 1.2 or 1.3.
def Decimal.rescale(d: Decimal, +t: Nat) -> Maybe<&2, Decimal>:
  match d:
    case Decimal{u, +s}:
      Decimal.rescale.if(Nat.is_le(s, t), u, s, t)

def Decimal.show.split(+s: Nat, +ds: String) -> String:
  +i = {Nat.sub(String.length(ds), s) : Nat}
  String.append(String.take(ds, i), SCon{Chr{46}, String.drop(ds, i)})

# Digits with a point s places from the right, zero-padded to one whole digit.
def Decimal.show.point(+s: Nat, +ds: String) -> String:
  match s:
    case 0n:
      ds
    case 1n+p:
      Decimal.show.split(1n+p, String.append(
        String.repeat("0", Nat.sub(2n+p, String.length(ds))), ds))

def Decimal.show.sign(neg: Bool, body: String) -> String:
  match neg:
    case True{}:
      SCon{Chr{45}, body}
    case False{}:
      body

# Plain notation with every scale digit: -12.50, 0.001, 7. Never an exponent.
def Decimal.show(d: Decimal) -> String:
  match d:
    case Decimal{+u, s}:
      Decimal.show.sign(Cmp.is_lt(Big.BigInt.cmp(u, Big.BigInt.zero())),
        Decimal.show.point(s, Big.BigInt.show(Big.BigInt.abs(u))))

# A character of a number.
type Class is Data:
  Digit{code: U32}
  Minus{}
  Plus{}
  Point{}
  Expo{}
  Other{}

def Decimal.class.sym(minus: Bool, plus: Bool, point: Bool, expo: Bool) ->
  Class:
  match minus:
    case True{}:
      Minus{}
    case False{}:
      match plus:
        case True{}:
          Plus{}
        case False{}:
          match point:
            case True{}:
              Point{}
            case False{}:
              match expo:
                case True{}:
                  Expo{}
                case False{}:
                  Other{}

def Decimal.class.if(digit: Bool, +c: U32) -> Class:
  match digit:
    case True{}:
      Digit{c}
    case False{}:
      Decimal.class.sym(U32.is_eq(c, 45), U32.is_eq(c, 43), U32.is_eq(c, 46),
        Bool.or(U32.is_eq(c, 101), U32.is_eq(c, 69)))

def Decimal.class(+c: U32) -> Class:
  Decimal.class.if(Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)), c)

# Where the reader is. ds holds the coefficient's digits, last first, without
# leading zeros; sc counts fraction digits; e is the exponent's magnitude.
type Scan is Data:
  Bad{}
  Begin{}
  Signed{neg: Bool}
  Whole{neg: Bool, ds: String}
  Dot{neg: Bool, ds: String}
  Frac{neg: Bool, ds: String, sc: Nat}
  Exp{neg: Bool, ds: String, sc: Nat}
  ExpSigned{neg: Bool, ds: String, sc: Nat, eneg: Bool}
  ExpDigits{neg: Bool, ds: String, sc: Nat, eneg: Bool, e: U32}

def Decimal.read.lead(zero: Bool, c: U32) -> String:
  match zero:
    case True{}:
      SNil{}
    case False{}:
      SCon{Chr{c}, SNil{}}

def Decimal.read.push(+c: U32, ds: String) -> String:
  match ds:
    case SNil{}:
      Decimal.read.lead(U32.is_eq(c, 48), c)
    case SCon{h, t}:
      SCon{Chr{c}, SCon{h, t}}

# ponytail: exponents past 100000 in magnitude are refused, since 1e100000
# materializes 100000 digits; raise the bound if a caller needs more.
def Decimal.read.exp(big: Bool, neg: Bool, ds: String, sc: Nat, eneg: Bool,
  e: U32) -> Scan:
  match big:
    case True{}:
      Bad{}
    case False{}:
      ExpDigits{neg, ds, sc, eneg, e}

def Decimal.read.step(st: Scan, cl: Class) -> Scan:
  match st:
    case Begin{}:
      match cl:
        case Digit{c}:
          Whole{False{}, Decimal.read.push(c, SNil{})}
        case Minus{}:
          Signed{True{}}
        case Plus{}:
          Signed{False{}}
        case _:
          Bad{}
    case Signed{neg}:
      match cl:
        case Digit{c}:
          Whole{neg, Decimal.read.push(c, SNil{})}
        case _:
          Bad{}
    case Whole{neg, ds}:
      match cl:
        case Digit{c}:
          Whole{neg, Decimal.read.push(c, ds)}
        case Point{}:
          Dot{neg, ds}
        case Expo{}:
          Exp{neg, ds, 0n}
        case _:
          Bad{}
    case Dot{neg, ds}:
      match cl:
        case Digit{c}:
          Frac{neg, Decimal.read.push(c, ds), 1n}
        case _:
          Bad{}
    case Frac{neg, ds, sc}:
      match cl:
        case Digit{c}:
          Frac{neg, Decimal.read.push(c, ds), 1n+sc}
        case Expo{}:
          Exp{neg, ds, sc}
        case _:
          Bad{}
    case Exp{neg, ds, sc}:
      match cl:
        case Digit{c}:
          ExpDigits{neg, ds, sc, False{}, U32.sub(c, 48)}
        case Minus{}:
          ExpSigned{neg, ds, sc, True{}}
        case Plus{}:
          ExpSigned{neg, ds, sc, False{}}
        case _:
          Bad{}
    case ExpSigned{neg, ds, sc, eneg}:
      match cl:
        case Digit{c}:
          ExpDigits{neg, ds, sc, eneg, U32.sub(c, 48)}
        case _:
          Bad{}
    case ExpDigits{neg, ds, sc, eneg, e}:
      match cl:
        case Digit{c}:
          +x = (e * 10 + c - 48 : U32)
          Decimal.read.exp(U32.is_gt(x, 100000), neg, ds, sc, eneg, x)
        case _:
          Bad{}
    case _:
      Bad{}

def Decimal.read.go(s: String, st: Scan) -> Scan:
  match s:
    case SNil{}:
      st
    case SCon{Chr{x}, t}:
      Decimal.read.go(t, Decimal.read.step(st, Decimal.class(x)))

def Decimal.read.abs(m: Maybe<&2, Big.BigInt>) -> Big.BigInt:
  match m:
    case Some{v}:
      v
    case None{}:
      Big.BigInt.zero()

# The coefficient; ds holds only digits, so read cannot fail.
def Decimal.read.coef(neg: Bool, ds: String) -> Big.BigInt:
  match neg:
    case True{}:
      Big.BigInt.neg(Decimal.read.abs(Big.BigInt.read(String.reverse(ds))))
    case False{}:
      Decimal.read.abs(Big.BigInt.read(String.reverse(ds)))

def Decimal.read.digits(neg: Bool, ds: String) -> Big.BigInt:
  match ds:
    case SNil{}:
      Big.BigInt.zero()
    case SCon{h, t}:
      Decimal.read.coef(neg, SCon{h, t})

# A negative exponent adds scale; a positive one spends scale, then multiplies.
def Decimal.read.shift(u: Big.BigInt, +sc: Nat, eneg: Bool, +e: Nat) -> Decimal:
  match eneg:
    case True{}:
      Decimal{u, Nat.add(sc, e)}
    case False{}:
      Decimal{Decimal.up(u, Nat.sub(e, sc)), Nat.sub(sc, e)}

def Decimal.read.fin(st: Scan) -> Maybe<&2, Decimal>:
  match st:
    case Whole{neg, ds}:
      Some{Decimal{Decimal.read.digits(neg, ds), 0n}}
    case Frac{neg, ds, sc}:
      Some{Decimal{Decimal.read.digits(neg, ds), sc}}
    case ExpDigits{neg, ds, sc, eneg, e}:
      Some{Decimal.read.shift(Decimal.read.digits(neg, ds), sc, eneg,
        U32.to_nat(e))}
    case _:
      None{}

# [+-]digits[.digits][(e|E)[+-]digits], a superset of JSON's number grammar
# (it also takes a leading + and leading zeros). The scale is the number of
# fraction digits less the exponent, floored at zero: "1.50" has scale 2,
# "1.5e1" is 15, "25e-3" is 0.025.
def Decimal.read(s: String) -> Maybe<&2, Decimal>:
  Decimal.read.fin(Decimal.read.go(s, Begin{}))
