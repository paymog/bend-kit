import Base
import ./bigint.bend as Big
import ./decimal.bend as Dec
import ./rational.bend as Rat

def show(m: Maybe<&2, Big.BigInt>) -> String:
  match m:
    case Some{n}:
      Big.BigInt.show(n)
    case None{}:
      "invalid"

def quotient(m: Maybe<&1, Big.BigInt & Big.BigInt>) -> String:
  match m:
    case Some{(q, r)}:
      Big.BigInt.show(q) ++ "," ++ Big.BigInt.show(r)
    case None{}:
      "invalid"

def decimal(m: Maybe<&2, Dec.Decimal>) -> String:
  match m:
    case Some{d}:
      Dec.Decimal.show(d)
    case None{}:
      "invalid"

def rational(m: Maybe<&2, Rat.Rational>) -> String:
  match m:
    case Some{r}:
      Rat.Rational.show(r)
    case None{}:
      "invalid"

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(show(Big.BigInt.read("18446744073709551616")))
    IO.print(Big.BigInt.show(Big.BigInt.mul(
      Big.BigInt.from_u32(4294967295),
      Big.BigInt.from_u32(4294967295))))
    IO.print(quotient(Big.BigInt.divmod(
      Big.BigInt.neg(Big.BigInt.from_u32(17)),
      Big.BigInt.from_u32(5))))
    IO.print(show(Big.BigInt.modpow(
      Big.BigInt.from_u32(4), Big.BigInt.from_u32(13),
      Big.BigInt.from_u32(497))))
    IO.print(decimal(Dec.Decimal.read("-12.50e-2")))
    IO.print(decimal(Dec.Decimal.div_exact(
      Dec.Decimal{Big.BigInt.one(), 0n},
      Dec.Decimal{Big.BigInt.from_u32(8), 0n})))
    IO.print(rational(Rat.Rational.make(
      Big.BigInt.from_u32(2), Big.BigInt.from_u32(4))))
