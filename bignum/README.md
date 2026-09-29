# Big numbers

Import `bigint.bend`, `decimal.bend`, or `rational.bend` directly. The entry
file includes them in the package; Bend does not re-export imports. For a
published package, use `import bend-kit-bignum@0.1.0.0/bigint.bend as Big`.
All arithmetic is pure. `BigInt` stores a signed magnitude as base-10^4 limbs
in `U32` cells. Its decimal `read`
and `show` do not impose a fixed integer width. Division returns `None` on a
zero divisor; the quotient truncates toward zero and the remainder has the
sign of the dividend.

`Decimal` holds an integer coefficient and decimal scale, so decimal input is
exact. This is suitable for money and JSON numbers whose decimal digits must
not round through a binary float. A rational represents an exact quotient;
use it when division has a repeating decimal expansion. No operation silently
rounds a monetary amount.

Run `../scripts/check.sh bignum` from the repository root to check the module,
prove its arithmetic fixtures, and run its smoke scenarios. See `bench/README.md`
for a cross-language arithmetic benchmark.
