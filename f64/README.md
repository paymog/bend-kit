# f64

IEEE 754 binary64 arithmetic, square root, integer conversion, and decimal text. The value is two `U32` halves, high word first.

```bend
import bend-kit-f64@0.1.4.0/f64.bend as F
```

```bend
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(F.F64.show(F.F64.div(F.F64.one(), F.F64.from_u32(3))))
```

Base has no `F64`. This is a pure soft-float, so pure code can add two doubles. It is slow. A `NaN` operand becomes one quiet `NaN`. Payloads are not kept. Rounding is ties to even. `+0` and `-0` compare equal.

`F64.hi` and `F64.lo` are the IEEE bits. `from_u32` is exact. Transcendental functions are not here.

`F64.read` gives the nearest double to decimal text, ties to even. It accepts `[+-]digits[.digits][(e|E)[+-]digits]` with a digit on at least one side of the point, and `inf`, `infinity`, and `nan` in any case. It does not skip spaces. `F64.show` gives the shortest decimal that reads back to the same double, in Python's `repr` format: `1.0`, `0.1`, `1e+16`, `5e-324`, `-0.0`, `inf`, `nan`. The laws prove fixtures only. `python3 text_check.py [count] [seed]` checks that `read` matches Python's `float`, that `show` matches `repr`, and that `read(show(x))` is `x`. It includes random inputs, exact halfway values, and adjacent values at binary and decimal boundaries.

Text conversion first uses 128-bit cached powers of ten. Parsing takes up to 19 significant digits through a 64-by-128-bit product. Both ends of its error interval must round to the same double. Printing scales the value and its two rounding boundaries with the same table. It removes decimal digits while the interval still contains an integer, then rounds the nearest candidate to even. Uncertain bounds and longer inputs use the existing exact big-integer paths.

The table stores `floor(10^k * 2^-e)` with its exactness flag. Dropping the low 64 product bits and bounding the table error puts the true product between `w * 2^64` and `(w + 2) * 2^64`. Printing accepts a floor only when both ends agree. Exact boundaries remain inclusive only for even significands. `python3 powers.py --check` verifies all 701 constants with exact rational arithmetic. `python3 powers.py` emits the table.

References: [Grisu's cached powers and fallback](https://www.cs.tufts.edu/~nr/cs257/archive/florian-loitsch/printf.pdf), [Eisel-Lemire's decimal parsing](https://arxiv.org/abs/2101.11408), and [Ryu's interval digit removal](https://github.com/ulfjack/ryu). This implementation uses conservative intervals, not their full algorithms. See [bench/README.md](bench/README.md) for before-and-after measurements.

On 2026-11-21, `python3 text_check.py 200000 7` matched Python on all inputs with Bend 2.0.38 and 2.0.40. The unchanged laws and `check.bend` passed on both versions.

| def | returns |
|---|---|
| `F64.is_nan(a: F64) -> Bool` | `True{}` for any NaN bit pattern. |
| `F64.read(s: String) -> Maybe<&2, F64>` | The nearest double, or `None{}` for text outside the grammar. |
| `F64.show(x: F64) -> String` | The shortest decimal that reads back to `x`. |
| `F64.sqrt(x: F64) -> F64` | The nearest square root, ties to even. |
| `F64.trunc(x: F64) -> F64` | The integer toward zero, with the sign of zero kept. |
| `F64.floor(x: F64) -> F64` | The greatest integer no greater than `x`. |
| `F64.ceil(x: F64) -> F64` | The least integer no less than `x`. |
| `F64.to_u32(x: F64) -> Maybe<&2, U32>` | The integer toward zero, or `None{}` outside the range. |

`F64.sqrt` preserves signed zero and positive infinity. Negative inputs and NaNs give `F64.nan()`. It normalizes subnormal inputs, then computes 54 root bits with restoring integer square root. The last bit and the exact remainder feed the shared rounding code.

Run `python3 sqrt_check.py [count] [seed]` to compare native result bits with Python's `math.sqrt`. It includes random finite inputs, explicit subnormals, special values, and adjacent inputs around exact squares.

`python3 sqrt_check.py 20000 727` passed all 22067 cases with zero mismatches on 2026-11-13. The run included 20000 random finite bit patterns, 5000 of them subnormal samples, plus fixtures and square-boundary inputs.

`floor`, `ceil`, and `trunc` preserve signed zero and infinities. NaNs give `F64.nan()`. Values at or above 2^52 in magnitude are already integers. `to_u32` gives `None{}` for NaN, infinity, values at or below -1, and values at or above 2^32. Values between -1 and 0 give `Some{0}`.

Run `python3 integer_check.py [count] [seed]` to compare native result bits with Python's `math.floor`, `math.ceil`, and `math.trunc`, and check `to_u32`. It includes random double bit patterns, explicit subnormals, fractional exponents, special values, and adjacent values at integer boundaries. Python returns integers without signed zero, so the check restores the input sign when the result is zero.

`python3 integer_check.py 20000 729` passed all 20038 inputs with zero mismatches on 2026-11-13. The run included 20000 random doubles, with 5000 explicit subnormal samples and 5000 fractional-exponent samples.
