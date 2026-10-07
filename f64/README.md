# f64

IEEE 754 binary64 add, subtract, multiply, and divide. The value is two `U32` halves, high word first.

```bend
import bend-kit-f64@0.1.0.0/f64.bend as F
```

```bend
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(U32.show(F.F64.hi(F.F64.div(F.F64.one(), F.F64.from_u32(3)))))
```

Base has no `F64`. This is a pure soft-float, so pure code can add two doubles. It is slow. A `NaN` operand becomes one quiet `NaN`. Payloads are not kept. Rounding is ties to even. `+0` and `-0` compare equal.

`F64.hi` and `F64.lo` are the IEEE bits. `from_u32` is exact. Decimal text is not here. Square root and the transcendental functions are not here.
