# multipart

This package encodes and decodes `multipart/form-data` from RFC 7578. The encoder generates a boundary. The decoder reads `Bytes`.

```bend
import bend-kit-multipart@0.2.0.1/multipart.bend as Mp
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
```

`multipart.bend` imports `bend-kit-bytes@0.3.2.0`. It also imports `bend-kit-crypto@0.2.2.1` to generate the boundary.

`Part` is `Part{name, filename, ctype, body}`. `filename` and `ctype` are `Maybe` values. `form` returns an `IO` result with the `Content-Type` value and body, or an error. `encode` takes a boundary and checks it. `decode` takes that boundary and the complete body. `decode.chunks` takes the boundary and a list of body chunks.

The encoder escapes `"`, CR, and LF in names and filenames as `%22`, `%0D`, and `%0A`. A boundary has 1 to 70 characters from the RFC 2046 `bchars` set. It must not end in a space. `boundary.new` generates `bend-kit-` plus 32 hexadecimal characters from 16 secure random bytes. The call fails if libcrypto is not available.

`http` does not parse multipart bodies. Get the boundary from `Content-Type`. Then use this package to decode the `Http.Body`.
