# int

Fixed-width integers: `U8`, `U16`, `U64`, `I32`, and `I64`. Each has wrapping, checked, and saturating arithmetic, and text in radix 2 to 36.

```bend
import bend-kit-int@0.2.0.0/int.bend as Int
```

`U8`, `U16`, and `I32` are wrappers over Base `U32` and run at native speed. `U64` and `I64` use `Word(64n)` until Base has a native 64-bit word. That path is slow. Do not use `Int.U64` as a hash accumulator. `hash` returns `W64{hi, lo}` for that reason.

`U64.show` and `U64.read` use decimal text. `U32.show_radix` clamps the radix to 2..36. `U32.read_radix` rejects a radix outside that range. Checked division returns `None` for division by zero. The wrapping forms have neither `checked_` nor `saturating_` in their names.

`bytes` imports this package for `get.u64be` and `get.u64le`. Import `bend-kit-int@0.2.0.0` when you read those values.

| def | result |
|---|---|
| `U64.checked_add(a: U64, b: U64)` | `Maybe<&2, U64>`; `None` if the sum overflows. |
