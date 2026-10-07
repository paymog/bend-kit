# hash

Non-cryptographic hashes over `Bytes`: FNV-1a (32 and 64), xxHash (32 and 64), SipHash-1-3, CRC-32, and Adler-32.

```bend
import bend-kit-hash@0.1.0.0/hash.bend as Hash
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes
```

`hash.bend` imports that bytes hash. Each `Bytes` function returns the buffer beside the digest, because the buffer is affine.

```bend
def show(r: Bytes.Bytes & U32) -> IO(Unit):
  (b, n) = r
  IO.print(U32.show(n))

def main() -> IO(Unit):
  show(Hash.fnv1a32(Bytes.from_string("")))
```

The empty-string FNV-1a 32 result is `2166136261`. The `.str` forms take a byte `String` instead of `Bytes`.

64-bit results are `W64{hi, lo}`, two `U32` halves. `int`'s `U64` is a bit list and is too slow for hashing. Equal keys for `collections` `HMap` must hash alike. These functions are not substitutes for `crypto` digests.
