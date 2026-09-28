# Random benchmark: 2^24 xoshiro128** draws (see README.md).
import Base
import ../../time/time.bend as Time
import ../random.bend as Rand

# Checksum: h = h*31 + x, u32.
def loop(n: Nat, +h: U32, xr: U32 & Rand.Rng) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      (x, r) = xr
      loop(p, (h * 31 + x : U32), Rand.next(r))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Time.Duration <- Time.mono()
    +h : U32 = loop(16777216n, 0, Rand.next(Rand.from_state(1, 2, 3, 4)))
    t1 : Time.Duration <- Time.mono()
    IO.print("next\t" ++ Time.Duration.show_ms(Time.Duration.sub(t1, t0)) ++ "\t" ++ U32.show(h))
