# lemmas

Proved laws that relate `Word` and `U32` arithmetic to `Nat`. Use them to prove claims about runtime integers. The Nat and List lemmas come from [`bend-mathlib`](https://github.com/bendlib/bendlib). This package holds the laws that mathlib does not have, such as those bounded by `pow2(n)`, and eleven laws that mathlib's `u32.bend` and `nat.bend` state the same way, kept under their names here and proved by the mathlib laws.

```bend
import bend-kit-lemmas@0.1.4.0/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
```

A `PROOF.bend` inside bend-kit imports `../lemmas/lemmas.bend`. `bytes/PROOF.bend` uses it to prove that `Bytes.fits` admits `n` bytes at `i` exactly when `i + n <= len`:

```bend
def Laws.fits_exact(len, i, n):
  Lemmas.u32_fits_nat(len, i, n)
```

| Law | Claim |
|---|---|
| `u32_to_nat_lt` | `to_nat(a) < 2^32` |
| `u32_to_nat_inj` | equal values give equal `U32`s |
| `u32_cmp_nat`, `u32_is_lt_nat`, `u32_is_le_nat`, `u32_is_eq_nat` | `U32` comparisons give the same result as `Nat` comparisons of the values |
| `u32_add_nat` | `to_nat(a + b) == to_nat(a) + to_nat(b)` when the sum is below `2^32` |
| `u32_add_mod` | `to_nat(a + b) == (to_nat(a) + to_nat(b)) mod 2^32` |
| `u32_sub_nat` | `to_nat(a - b) == to_nat(a) - to_nat(b)` when `b <= a` |
| `u32_sub_wrap` | `to_nat(a - b) == to_nat(a) + 2^32 - to_nat(b)` when `a < b` |
| `u32_mul_nat` | multiplication is exact when the product is below `2^32` |
| `u32_mul_mod` | multiplication wraps modulo `2^32` |
| `u32_divmod_nat` | for a positive divisor, `q*b + r == a` and `r < b` over `Nat` |
| `u32_div_nat`, `u32_mod_nat` | division and remainder equal the corresponding `Nat` operations for a positive divisor |
| `u32_div_mul_add_mod` | `(a / b) * b + a % b == a` as `U32`s, for a positive divisor |
| `u32_xor_twice`, `word_xor_twice` | XOR with the same value twice gives the input back |
| `u32_inc_nat` | `to_nat(U32.inc(a)) == 1 + to_nat(a)` when that is below `2^32` |
| `u32_to_from_nat`, `u32_from_to_nat` | `from_nat` and `to_nat` are inverses below `2^32` |
| `u32_fits_nat` | `n <= len && i <= len - n` holds exactly when `i + n <= len` |

The word laws cover value bounds, injectivity, comparison, addition, subtraction, multiplication, shifts, and increment for every `Word(n)`. They use `pow2(n)` in place of `2^32`. `word_adc_nat` relates the word sum and carry-out to the full sum. `word_shl_put_nat` includes the carry from a shift with an incoming bit. `word_shl_out_nat` states the same equation for the carry and word pair from `Word.shl.out`; `shl_value` sums the word value and carry weight. `word_shl_mod` and `word_mul_mod` give the wrapped values. `word_mul_go_nat` covers any accumulator and multiplier width. `word_sub_wrap` covers subtraction with a borrow. `u32_divmod_go_nat` proves the quotient equation and remainder bound for every input prefix width. There are no `word_` forms of the `U32` conversion or bounds-check laws.

Write `2^32` as `Lemmas.pow2(32n)`. A `Nat` literal stops at `4294967295n`.

| def | result |
|---|---|
| `pow2(n: Nat)` | `Nat`; computes `2^n`. Keep large powers folded in proofs. |

Do not make the checker unfold `pow2(32n)`. When a conversion check must compare two terms that differ somewhere and that contain `pow2(32n)`, it expands `2^32` into successors and overflows the stack (bendlang/bend#1071, a known limit). Move a bound across an equation with `Lemmas.lt_rw` or a `%` rewrite, so that each side matches the other exactly. `u32_add_nat` and `u32_add_mod` show both.
