# random

A seeded xoshiro128** generator. Unbiased ranges, `F32` in `[0, 1)`, and Fisher-Yates shuffles. Not for cryptography. Secrets use `crypto`'s `random.words`.

```bend
import bend-kit-random@0.1.0.0/random.bend as Rand
```

```bend
def show(r: U32 & Rand.Rng) -> IO(Unit):
  (n, next) = r
  IO.print(U32.show(n))

def main() -> IO(Unit):
  show(Rand.below(10, Rand.seed(42)))
```

`seed` builds an `Rng`. The state must not be all zeros. `next`, `below`, `range`, `unit`, and `shuffle` return the drawn value beside the next `Rng`. Pass that `Rng` on. The same seed draws the same stream. No OS entropy enters those functions.

`entropy` reads four `U32` words from the OS. `from_os` seeds an `Rng` from that read. Both are effects in `effs/random.c` and `effs/random.js`. The native lane uses `getentropy`. Proofs do not cover them.

`property` imports `bend-kit-random@0.1.0.0` for its generators.
