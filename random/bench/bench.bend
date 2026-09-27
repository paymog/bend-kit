# Random benchmark: 2^24 xoshiro128** draws (see README.md).
import Base
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
    t0 : Nat <- IO.now()
    +h : U32 = loop(16777216n, 0, Rand.next(Rand.from_state(1, 2, 3, 4)))
    t1 : Nat <- IO.now()
    IO.print("next\t" ++ Nat.show((t1 - t0 : Nat)) ++ "\t" ++ U32.show(h))
