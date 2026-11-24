# List-model CRC benchmark; build the input before the timer starts.
import Base
import ../../time/time.bend as Time
import ../pure.bend as J

def input(n: Nat, +i: U32) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{(i .&. 255 : U32), input(p, (i + 1 : U32))}

def size(args: List<&1, String>) -> Nat:
  match args:
    case program <> n <> Nil{}:
      U32.to_nat(Maybe.default(&2, U32, U32.read(n), 16777216))
    case _:
      16777216n

def shown(t0: Time.Duration, +crc: U32) -> IO(Unit):
  do IO<Unit>:
    t1 : Time.Duration <- Time.mono()
    IO.print("crc\t" ++ U32.show(crc))
    IO.print("ms\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<&1, String> <- IO.args()
    xs : List<&2, U32> = input(size(args), 0)
    t0 : Time.Duration <- Time.mono()
    shown(t0, J.list.crc(xs))
