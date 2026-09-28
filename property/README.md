# Property testing

`property.bend` runs pure generated checks. Import `generate.bend` and `shrink.bend` from the same package. The seed reproduces the same draw stream. `check` returns the first failure with its zero-based trial index and shrunk value; `run` also prints `property failed: seed=42 trial=1 counterexample=[0, 0, 1]` and returns `False`. A passing run returns `True` and prints nothing. `check.bend` contains a complete example that plants a list-sum defect and reduces it to `[0, 0, 1]`.

```bend
import Base
import bend-kit-property@0.1.0.0/property.bend as Prop
import bend-kit-property@0.1.0.0/generate.bend as Gen
import bend-kit-property@0.1.0.0/shrink.bend as Shrink

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

`Gen.u32`, `Gen.nat(max, rng)`, `Gen.string(max, rng)`, `Gen.bytes(max, rng)`, `Gen.list(~T, ~gen, max, rng)`, and `Gen.maybe(~T, ~gen, rng)` cover the basic types. Lengths are uniformly drawn from zero through `min(max, 1024)`; strings contain printable ASCII and bytes cover 0–255. `Gen.map`, `Gen.bind`, and `Gen.pair` compose user-defined generators. `Gen.list.of` and `Gen.string.of` take an exact `Nat` count instead. The `~gen` template must be closed: use `~(r => Gen.list(~U32, ~Gen.u32, 8, r))` for a fixed bound.

`Shrink.u32`, `Shrink.nat`, `Shrink.char`, `Shrink.string`, `Shrink.bytes`, `Shrink.list(~T, ~shrink, xs)`, and `Shrink.maybe(~T, ~shrink, value)` return ordered candidate lists. Numbers try zero and then halving steps down to a decrement of one. Lists try whole and chunk deletions, then simplify individual elements. The runner takes the first failing candidate and repeats, up to 1024 accepted steps. If it stops before that bound, the counterexample is locally minimal under the candidate order; arbitrary predicates need not have a globally shortest result. User-defined shrinkers should only return simpler values, or the bound may stop a cycle.

`~copy: T -> T & T` keeps the current counterexample while trying candidates. For `Data` values, return `(x, x)` with a reusable binder inside the copy def. For affine `Bytes.Bytes`, copy with `Bytes.slice` and pass a predicate that returns its input. No OS entropy or IO enters generation or shrinking; `run` prints through IO, while `check` remains pure. Choose and record a seed in each package's `check.bend` so failures replay exactly.
