# cbor

Encode and decode CBOR values over `Bytes` as specified in RFC 8949.

```bend
import bend-kit-cbor@0.3.0.0/cbor.bend as Cbor
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
```

`Val` has these constructors: `UInt`, `NInt`, `BStr`, `TStr`, `Arr`, `Obj`, `Tag`, `Sim`, and `Flt`. Values wider than a `U32` use `W64`. It holds two `U32` halves.

`decode` returns `None` for truncated input, a reserved additional information value, an invalid break, invalid UTF-8 text, or trailing bytes. It combines indefinite strings, arrays, and maps into definite values. `encode` returns `None` for invalid UTF-8 text, half-float bits wider than 16 bits, or an invalid simple value.

`check.bend` decodes and encodes the hex vector `bf61610161629f0203ffff`. This indefinite map decodes to a definite map.
