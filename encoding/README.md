# encoding

UTF-8 between a `String` of code points and `Bytes`. Hex lives on `bytes`, as `to_hex` and `from_hex`.

```bend
import bend-kit-encoding@0.3.0.0/encoding.bend as Enc
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

That bytes hash is the one `encoding.bend` imports. It is not `bend-kit-bytes@0.3.2.0`.

```bend
def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Bytes.to_hex(Enc.utf8.encode("aé€😀z")))
    IO.print(Enc.utf8.decode(Enc.utf8.encode("aé€😀z")))
```

`utf8.encode` writes RFC 3629. `utf8.decode` is WHATWG UTF-8: a bad sequence becomes U+FFFD, and decoding continues. Pass the `Bytes` value `encode` returns straight to `decode`. It is affine.
