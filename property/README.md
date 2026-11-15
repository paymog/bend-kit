# Property testing

`property.bend` runs pure checks on generated values. Import `generate.bend` and `shrink.bend` from the same package. The same seed produces the same values. `check` returns the first failure, its zero-based trial index, and its reduced value. `run` also prints a message such as `property failed: seed=42 trial=1 counterexample=[0, 0, 1]` and returns `False`. A passing run returns `True` and prints nothing. `check.bend` contains a list-sum defect. The check reduces its failing input to `[0, 0, 1]`.

```bend
import Base
import bend-kit-property@0.4.0.0/property.bend as Prop
import bend-kit-property@0.4.0.0/generate.bend as Gen
import bend-kit-property@0.4.0.0/shrink.bend as Shrink

# A predicate must return the tested value, including on failure.
def small(+x: U32) -> U32 & Bool:
  (x, U32.is_lt(x, 10))

def copy(+x: U32) -> U32 & U32:
  (x, x)

def main() -> IO(Unit):
  do IO<Unit>:
    ok : Bool <- Prop.run(~U32, ~Gen.u32, ~(x => copy(x)), ~Shrink.u32,
      ~(x => small(x)), ~U32.show, 42, 100n)
    IO.print(Bool.pick(String, ok, "pass", "fail"))
```

This package imports `bend-kit-random@0.1.0.1` and `bend-kit-bytes@0.3.3.0`. Import the same bytes version when you use `Gen.bytes` or `Shrink.bytes`.

`Gen.u32`, `Gen.nat(max, rng)`, `Gen.string(max, rng)`, `Gen.bytes(max, rng)`, `Gen.list(~T, ~gen, max, rng)`, and `Gen.maybe(~T, ~gen, rng)` generate basic types. Lengths range uniformly from zero through `min(max, 1024)`. Strings contain printable ASCII. Byte values range from 0 to 255. `Gen.map`, `Gen.bind`, and `Gen.pair` combine generators. `Gen.list.of` and `Gen.string.of` take an exact `Nat` count. The `~gen` template must be closed. Use `~(r => Gen.list(~U32, ~Gen.u32, 8, r))` for a fixed bound.

`Shrink.u32`, `Shrink.nat`, `Shrink.char`, `Shrink.string`, `Shrink.bytes`, `Shrink.list(~T, ~shrink, xs)`, and `Shrink.maybe(~T, ~shrink, value)` return ordered candidate lists. Numbers try zero, then halve the decrement down to one. Lists try to remove the whole list, then chunks, then to simplify each element. The runner accepts the first failing candidate and repeats. It accepts at most 1024 steps. If it stops before that limit, no candidate from the final value fails. Another value can still be a shorter failing input. Custom shrinkers should return only simpler values. Otherwise, the limit can stop a cycle.

`~copy: T -> T & T` keeps the current failing value while the runner tries candidates. For `Data` values, return `(x, x)` with a reusable binder inside the copy def. For affine `Bytes.Bytes`, copy with `Bytes.slice`. The predicate must return its input. Generation and shrinking use no OS entropy or IO. `run` prints through IO. `check` is pure. Record a seed in each package's `check.bend` to reproduce failures.
