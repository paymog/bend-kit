# multipart

`multipart/form-data` as RFC 7578. The encoder draws a boundary. The decoder walks `Bytes`.

```bend
import bend-kit-multipart@0.1.1.1/multipart.bend as Mp
import bend-kit-bytes@0.3.1.0/bytes.bend as Bytes
```

Those are the versions `multipart.bend` imports. It also imports `bend-kit-crypto@0.2.2.1` for the boundary.

`Part` is `Part{name, filename, ctype, body}`. `filename` and `ctype` are `Maybe`. `form` returns `IO` of the `Content-Type` value and the body. `encode` takes a boundary you already checked. `decode` and `decode.chunks` take that boundary and the body bytes.

Names and filenames escape `"`, CR, and LF as `%22`, `%0D`, and `%0A`. A boundary is 1 to 70 bchars and does not end in a space. `boundary.new` is `bend-kit-` plus 32 hex chars from 16 secure random bytes. A missing libcrypto fails that call.

`http` does not parse multipart bodies. Decode the `Http.Body` with this package after you have the boundary from `Content-Type`.
