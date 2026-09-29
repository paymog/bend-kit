# BigInt benchmark: the Bend side (see README.md).
import Base
import ../../time/time.bend as Time
import ../bigint.bend as Big

def N() -> Nat:
  64n

def stamp(t0: Time.Duration) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("ms\tmodsq\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

# The remainder of a divmod; d if the divisor was zero.
def rem(qr: Maybe<&1, Big.BigInt & Big.BigInt>, d: Big.BigInt) -> Big.BigInt:
  match qr:
    case None{}:
      d
    case Some{(q, r)}:
      r

# (x*x + a) mod m.
def step(+m: Big.BigInt, a: Big.BigInt, +x: Big.BigInt) -> Big.BigInt:
  rem(Big.BigInt.divmod(Big.BigInt.add(Big.BigInt.mul(x, x), a), m), m)

# x = (x*x + a) mod m, N times; returns acc plus every new x.
def loop(n: Nat, +m: Big.BigInt, +a: Big.BigInt, x: Big.BigInt, acc: Big.BigInt) -> Big.BigInt:
  match n:
    case 0n:
      acc
    case 1n+p:
      +y = step(m, a, x)
      loop(p, m, a, y, Big.BigInt.add(acc, y))

# acc starts at x_0, so the checksum is x_0 + x_1 + ... + x_N.
def run(t0: Time.Duration, m: Maybe<&2, Big.BigInt>, x: Maybe<&2, Big.BigInt>, a: Maybe<&2, Big.BigInt>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("modsq\t0\tbad input")
    case Some{+mv}:
      match x:
        case None{}:
          IO.print("modsq\t0\tbad input")
        case Some{+xv}:
          match a:
            case None{}:
              IO.print("modsq\t0\tbad input")
            case Some{+av}:
              do IO<Unit>:
                IO.print("chk\tmodsq\t" ++ Big.BigInt.show(loop(N(), mv, av, xv, xv)))
                stamp(t0)

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    run(t0, Big.BigInt.read("170141183460469231731687303715884105727"),
      Big.BigInt.read("123456789012345678901234567890123456789"),
      Big.BigInt.read("98765432109876543210987654321098765432"))
