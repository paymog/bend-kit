# BigInt benchmark

This times `BigInt` parsing, multiplication, addition, division with remainder, and printing, and compares it against OpenSSL `BIGNUM` in C, the `num-bigint` crate in Rust, `int` in Python, and `BigInt` in JavaScript.

## Run

```sh
python3 run.py      # 3 runs per variant, median
python3 run.py 5    # 5 runs
```

You need `bend`, `cc`, `cargo`, `bun`, `node`, `python3`, and OpenSSL 3 (`brew install openssl@3`; set `OPENSSL_PREFIX` if it is not at `/opt/homebrew/opt/openssl@3`). Binaries go to `out/`, which git ignores. It exits non-zero if a build fails, a program prints no result, or two programs disagree on the checksum.

## The op

`modsq` does this, all inside the timer:

1. Read three decimal strings: m = 2^127 − 1 = `170141183460469231731687303715884105727`, x_0 = `123456789012345678901234567890123456789`, and a = `98765432109876543210987654321098765432`.
2. N = 64 times: `(q, x) = divmod(x*x + a, m)`, and add the new x to `acc`, which starts at x_0.
3. Print `acc` in decimal.

The checksum is x_0 + x_1 + … + x_64, a 133-bit number. Taking the remainder each step keeps every operand under 255 bits, so the time goes to arithmetic on fixed-size 128-bit numbers and not to growing ones. Every program computes the quotient, as `BigInt.divmod` does.

| language | type | ops |
|---|---|---|
| Bend | `BigInt` from `../bigint.bend` | `read`, `mul`, `add`, `divmod`, `show` |
| C | OpenSSL `BIGNUM` | `BN_dec2bn`, `BN_mul`, `BN_add`, `BN_div`, `BN_bn2dec` |
| Rust | `num_bigint::BigUint` 0.4 | `parse`, `*`, `+`, `Integer::div_rem`, `to_string` |
| Python | `int` | `int`, `*`, `+`, `divmod`, `str` |
| JavaScript | `BigInt` | `BigInt`, `*`, `+`, `/` and `%`, `toString` |

Baselines print `modsq<TAB>ms<TAB>checksum`. Bend prints `chk<TAB>modsq<TAB>checksum`, then `ms<TAB>modsq<TAB>ms`, so the print forces the work before it reads the clock.

## Results

M4 Pro, macOS, 2026-09-28. Bend 2.0.32, Apple clang 17.0.0 with OpenSSL 3.6.4, rustc 1.91.0 with num-bigint 0.4, Bun 1.3.14, Node 24.0.1, Python 3.14.6. Median of three runs. Times are in milliseconds.

| variant | modsq ms | vs fastest |
|---|---:|---:|
| C | 0.023 | 1.0x |
| Rust | 0.024 | 1.0x |
| Bun | 0.031 | 1.3x |
| Node | 0.039 | 1.7x |
| Python | 0.023 | 1.0x |
| Bend | 0.890 | 38.7x |

Every program prints checksum `5650207468030235740545307866239660910729`.

## Caveats

- Bend times itself with `Time.mono`, a nanosecond clock.
- One machine, one thread.
