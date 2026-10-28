# hash

Non-cryptographic hashes over `Bytes`: FNV-1a (32 and 64), xxHash (32 and 64), SipHash-1-3, CRC-32, and Adler-32.

```bend
import bend-kit-hash@0.3.0.2/hash.bend as Hash
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
```

Each hash function that takes `Bytes` returns the buffer beside the digest. The buffer is affine.

```bend
def show(r: Bytes.Bytes & U32) -> IO(Unit):
  (b, n) = r
  IO.print(U32.show(n))

def main() -> IO(Unit):
  show(Hash.fnv1a32(Bytes.from_string("")))
```

The FNV-1a 32 result for an empty string is `2166136261`. The `.str` forms take a byte `String` instead of `Bytes`.

64-bit results use `W64{hi, lo}` with two `U32` halves. The `int` package represents `U64` as a bit list. This representation is too slow for hashing. Equal keys for the `collections` type `HMap` must have equal hashes. These functions do not replace `crypto` digests.
