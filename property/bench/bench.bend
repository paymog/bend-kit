# Time ten thousand passing properties over seeded U32 inputs.
import Base
import ../../time/time.bend as Time
import bend-kit-random@0.1.0.0/random.bend as Rand
import ../property.bend as Prop
import ../generate.bend as Gen
import ../shrink.bend as Shrink

def copy(+x: U32) -> U32 & U32:
  (x, x)

def valid(x: U32) -> U32 & Bool:
  (x, True{})

def done(result: Maybe<&1, Prop.Failure<U32>>) -> U32:
  match result:
    case None{}:
      10000
    case Some{Prop.Failure{seed, trial, value}}:
      0

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    checksum : U32 = done(Prop.check(~U32, ~Gen.u32, ~(x => copy(x)), ~Shrink.u32, ~valid, 42, 10000n))
    t1 : Time.Duration <- Time.mono()
    IO.print("check\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(checksum))
