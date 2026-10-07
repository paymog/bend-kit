# fmt

A string builder, `{}` formatting, padding, and the shortest `F32` text that reads back to the same value.

```bend
import bend-kit-fmt@0.1.0.0/fmt.bend as Fmt
```

```bend
def main() -> IO(Unit):
  b = Fmt.Builder.add(Fmt.Builder.add(Fmt.Builder.new(), "ab"), "cd")
  do IO<Unit>:
    IO.print(Fmt.Builder.build(b))
    IO.print(Fmt.Fmt.format("{} of {}", ["3", "7"]))
```

The def name is `Fmt.format`, so the imported call is `Fmt.Fmt.format`. `F32.shortest` takes an `F32`. `check.bend` builds that `F32` from bits and reads the text back.

`Builder` stores chunks newest-first and joins them once in `build`. `Fmt.format` replaces each `{}` with the next argument. A `{{` or `}}` is an escaped brace. A hole past the last argument is left as text.

`pad_left`, `pad_right`, and `center` pad to a `Nat` width with one `Char`. `F32.shortest` is for finite values. It does not round-trip NaN or infinity.

`time` imports this package for date text. Import `bend-kit-fmt@0.1.0.0` when you pass a string into that code.
