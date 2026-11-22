# hash

Non-cryptographic hashes over `Bytes`: FNV-1a (32 and 64), xxHash (32 and 64), SipHash-1-3, SipHash-2-4, CRC-32, and Adler-32.

```bend
import bend-kit-hash@0.3.2.1/hash.bend as Hash
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

64-bit results use `W64` with two `U32` halves. Build seeds and keys with `W64.of(hi, lo)`. Read the halves with `W64.hi` and `W64.lo`.

`siphash24(bytes, k0, k1)` uses two compression rounds and four final rounds. `siphash13` keeps its one and three rounds. Both take the two little-endian 64-bit words of a 16-byte key. Both also have `.str` forms. The [SipHash paper](https://www.aumasson.jp/siphash/siphash.pdf) defines SipHash-2-4; the laws use its reference vectors.

```bend
def halves() -> U32 & U32:
  +word = Hash.W64.of(3421674724, 2216829733)
  (Hash.W64.hi(word), Hash.W64.lo(word))

def seeded() -> Hash.W64:
  Hash.xxh64.str("hello", Hash.W64.of(0, 1))
```

The `int` package represents `U64` as a bit list. This representation is too slow for hashing. Equal keys for the `collections` type `HMap` must have equal hashes. These functions do not replace `crypto` digests.
