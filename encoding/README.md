# encoding

Convert UTF-8 between a `String` of code points and `Bytes`. The `bytes` package provides `to_hex` and `from_hex`.

```bend
import bend-kit-encoding@0.5.0.0/encoding.bend as Enc
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
```

```bend
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Bytes.to_hex(Enc.utf8.encode("aé€😀z")))
    IO.print(Enc.utf8.decode(Enc.utf8.encode("aé€😀z")))
```

`utf8.encode` writes UTF-8 as specified in RFC 3629. `utf8.decode` follows the WHATWG UTF-8 rules. It replaces an invalid sequence with U+FFFD and continues. Pass the `Bytes` value from `utf8.encode` directly to `utf8.decode`. The value is affine.
