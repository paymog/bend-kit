# int

Fixed-width integers: `U8`, `U16`, `U64`, `I32`, and `I64`. Each has wrapping, checked, and saturating arithmetic, and text in radix 2 to 36.

```bend
import bend-kit-int@0.2.0.0/int.bend as Int
```

`U8`, `U16`, and `I32` are wrappers over Base `U32` and run at native speed. `U64` and `I64` use `Word(64n)` until Base has a native 64-bit word. That path is slow. Do not use `Int.U64` as a hash accumulator. `hash` returns `W64{hi, lo}` for that reason.

`U64.show` and `U64.read` are decimal. `U32.show_radix` and `U32.read_radix` clamp the radix to 2..36. Division by zero is a checked `None` on the checked forms. The wrapping forms are the ones without `checked_` or `saturating_` in the name.

`bytes` imports this package for `get.u64be` and `get.u64le`. Import `bend-kit-int@0.2.0.0` when you read those values.
