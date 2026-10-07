# cbor

CBOR encode and decode over `Bytes`, RFC 8949.

```bend
import bend-kit-cbor@0.1.0.1/cbor.bend as Cbor
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

`Val` is `UInt`, `NInt`, `BStr`, `TStr`, `Arr`, `Obj`, `Tag`, `Sim`, or `Flt`. Widths that do not fit in a `U32` use `W64`, two `U32` halves.

`decode` returns `None` on truncation, a reserved additional-info, a bad break, non-UTF-8 text, or trailing bytes. Indefinite strings, arrays, and maps come back as one definite value. `encode` returns `None` when a text string is not UTF-8, a half-float does not fit in 16 bits, or a simple value is not valid.

`check.bend` round-trips the hex vector `bf61610161629f0203ffff`, an indefinite map that decodes to a definite map.
