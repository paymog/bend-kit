# Non-cryptographic hashes over Bytes: FNV-1a, xxHash, SipHash-1-3, CRC-32, and Adler-32. Source: https://github.com/paymog/bend-kit/tree/main/hash
import Base
# bend-kit-bytes@0.3.0.0
import 0x49814d83de8f70993a43e1002be29ecd/bytes.bend as Bytes

# Each hash hands the buffer back beside its value. A buffer's bytes at or past len are 0.
# Each hash also has a .str form over a byte string (one Char per octet), copied to Bytes first.
#   import bend-kit-hash@0.1.0.0/hash.bend as Hash

# A 64-bit value as two halves. Base has no native U64, and int's U64 is a bit list.
type W64 is Data:
  W64{hi: U32, lo: U32}

def W64.xor(a: W64, b: W64) -> W64:
  match a b:
    case W64{ah, al} W64{bh, bl}:
      W64{U32.xor(ah, bh), U32.xor(al, bl)}

def W64.add.of(+ah: U32, +bh: U32, +al: U32, +lo: U32) -> W64:
  W64{(ah + bh + Bool.pick(U32, U32.is_lt(lo, al), 1, 0) : U32), lo}

def W64.add(a: W64, b: W64) -> W64:
  match a b:
    case W64{+ah, +al} W64{+bh, +bl}:
      W64.add.of(ah, bh, al, (al + bl : U32))

# The full 64-bit product of two U32, from four 16-bit partial products.
def mul32.of(+p00: U32, +p01: U32, +p10: U32, +p11: U32) -> W64:
  +mid = ((p00 >> 16n) + (p01 .&. 65535) + (p10 .&. 65535) : U32)
  W64{(p11 + (p01 >> 16n) + (p10 >> 16n) + (mid >> 16n) : U32), ((p00 .&. 65535) .|. (mid << 16n) : U32)}

def mul32(+x: U32, +y: U32) -> W64:
  +x0 = (x .&. 65535 : U32)
  +x1 = (x >> 16n : U32)
  +y0 = (y .&. 65535 : U32)
  +y1 = (y >> 16n : U32)
  mul32.of((x0 * y0 : U32), (x0 * y1 : U32), (x1 * y0 : U32), (x1 * y1 : U32))

def W64.mul.of(+cross: U32, p: W64) -> W64:
  W64{+h, +l} = p
  W64{(h + cross : U32), l}

def W64.mul(a: W64, b: W64) -> W64:
  match a b:
    case W64{+ah, +al} W64{+bh, +bl}:
      W64.mul.of(((al * bh) + (ah * bl) : U32), mul32(al, bl))

# Rotate left by k, for 0 < k < 32; j is 32 - k.
def W64.rotl(+k: Nat, +j: Nat, a: W64) -> W64:
  match a:
    case W64{+h, +l}:
      W64{((h << k) .|. (l >> j) : U32), ((l << k) .|. (h >> j) : U32)}

def W64.swap(a: W64) -> W64:
  match a:
    case W64{h, l}:
      W64{l, h}

# Shift right by k, for 0 < k < 32; j is 32 - k.
def W64.shr(+k: Nat, +j: Nat, a: W64) -> W64:
  match a:
    case W64{+h, +l}:
      W64{(h >> k : U32), ((l >> k) .|. (h << j) : U32)}

def W64.lo(a: W64) -> U32:
  match a:
    case W64{h, l}:
      l

def rotl32(+x: U32, +k: Nat, +j: Nat) -> U32:
  ((x << k) .|. (x >> j) : U32)

# Folds f over n words from word i on. r holds the array and word i.
def wfold(~T: Type, ~f: T -> @+c: U32 -> T, n: Nat, r: Array<U32> & U32, +i: U32, acc: T) -> Array<U32> & T:
  match n:
    case 0n:
      (a, w) = r
      (a, acc)
    case 1n+p:
      (a, +w) = r
      +j = (i + 1 : U32)
      wfold(~T, ~f, p, Array.get(U32, a, j), j, f(acc, w))

def wfrom(~T: Type, ~f: T -> @+c: U32 -> T, n: Nat, a: Array<U32>, +i: U32, acc: T) -> Array<U32> & T:
  wfold(~T, ~f, n, Array.get(U32, a, i), i, acc)

# Words i and i + 1 as one little-endian 64-bit lane.
def get2.of(+lo: U32, r: Array<U32> & U32) -> Array<U32> & W64:
  (a, +hi) = r
  (a, W64{hi, lo})

def get2.lo(+i: U32, r: Array<U32> & U32) -> Array<U32> & W64:
  (a, +lo) = r
  get2.of(lo, Array.get(U32, a, (i + 1 : U32)))

def get2(a: Array<U32>, +i: U32) -> Array<U32> & W64:
  get2.lo(i, Array.get(U32, a, i))

# Folds f over n 64-bit lanes from word i on. r holds the array and the lane at i.
def dfold(~T: Type, ~f: T -> @+m: W64 -> T, n: Nat, r: Array<U32> & W64, +i: U32, acc: T) -> Array<U32> & T:
  match n:
    case 0n:
      (a, m) = r
      (a, acc)
    case 1n+p:
      (a, +m) = r
      +j = (i + 2 : U32)
      dfold(~T, ~f, p, get2(a, j), j, f(acc, m))

def dfrom(~T: Type, ~f: T -> @+m: W64 -> T, n: Nat, a: Array<U32>, +i: U32, acc: T) -> Array<U32> & T:
  dfold(~T, ~f, n, get2(a, i), i, acc)

# Folds f over the low k bytes of w, lowest first.
def tail(~T: Type, ~f: T -> @+c: U32 -> T, k: Nat, +w: U32, acc: T) -> T:
  match k:
    case 0n:
      acc
    case 1n+p:
      tail(~T, ~f, p, (w >> 8n : U32), f(acc, (w .&. 255 : U32)))

def bytewise.last(~T: Type, ~byte: T -> @+c: U32 -> T, +len: U32, acc: T, r: Array<U32> & U32) -> Bytes.Bytes & T:
  (a, +w) = r
  (Bytes.Bytes{len, a}, tail(~T, ~byte, U32.to_nat((len .&. 3 : U32)), w, acc))

def bytewise.rest(~T: Type, ~byte: T -> @+c: U32 -> T, +len: U32, r: Array<U32> & T) -> Bytes.Bytes & T:
  (a, acc) = r
  bytewise.last(~T, ~byte, len, acc, Array.get(U32, a, (len >> 2n : U32)))

# A hash that eats one byte at a time: word takes the four bytes of a word, byte one.
def bytewise(~T: Type, ~byte: T -> @+c: U32 -> T, ~word: T -> @+c: U32 -> T, b: Bytes.Bytes, acc: T) -> Bytes.Bytes & T:
  Bytes.Bytes{+len, buf} = b
  bytewise.rest(~T, ~byte, len, wfrom(~T, ~word, U32.to_nat((len >> 2n : U32)), buf, 0, acc))

# FNV-1a (draft-eastlake-fnv), 32 and 64 bits.
def fnv32.byte(h: U32, +c: U32) -> U32:
  ((h .^. c) * 16777619 : U32)

def fnv32.word(h: U32, +w: U32) -> U32:
  fnv32.byte(fnv32.byte(fnv32.byte(fnv32.byte(h, (w .&. 255 : U32)), ((w >> 8n) .&. 255 : U32)), ((w >> 16n) .&. 255 : U32)), (w >> 24n : U32))

def fnv1a32(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  bytewise(~U32, ~fnv32.byte, ~fnv32.word, b, 2166136261)

def fnv64.byte(h: W64, +c: U32) -> W64:
  match h:
    case W64{hi, lo}:
      W64.mul(W64{hi, (lo .^. c : U32)}, W64{256, 435})

def fnv64.word(h: W64, +w: U32) -> W64:
  fnv64.byte(fnv64.byte(fnv64.byte(fnv64.byte(h, (w .&. 255 : U32)), ((w >> 8n) .&. 255 : U32)), ((w >> 16n) .&. 255 : U32)), (w >> 24n : U32))

def fnv1a64(b: Bytes.Bytes) -> Bytes.Bytes & W64:
  bytewise(~W64, ~fnv64.byte, ~fnv64.word, b, W64{3421674724, 2216829733})

# CRC-32 (ISO-HDLC, as in gzip and zlib): reflected, polynomial 0xEDB88320.
def crc.bit(+c: U32) -> U32:
  Bool.pick(U32, U32.is_eq((c .&. 1 : U32), 1), ((c >> 1n) .^. 3988292384 : U32), (c >> 1n : U32))

def crc.bits(k: Nat, +c: U32) -> U32:
  match k:
    case 0n:
      c
    case 1n+p:
      crc.bits(p, crc.bit(c))

def crc.fill(k: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match k:
    case 0n:
      a
    case 1n+p:
      crc.fill(p, (i + 1 : U32), Array.set(U32, a, i, crc.bits(8n, i)))

# The table and the running register.
type Crc is Type:
  Crc{t: Array<U32>, h: U32}

def crc.mix(+c: U32, r: Array<U32> & U32) -> Crc:
  (a, +t) = r
  Crc{a, (t .^. (c >> 8n) : U32)}

def crc.byte(st: Crc, +c: U32) -> Crc:
  Crc{a, +h} = st
  crc.mix(h, Array.get(U32, a, ((h .^. c) .&. 255 : U32)))

def crc.word(st: Crc, +w: U32) -> Crc:
  crc.byte(crc.byte(crc.byte(crc.byte(st, (w .&. 255 : U32)), ((w >> 8n) .&. 255 : U32)), ((w >> 16n) .&. 255 : U32)), (w >> 24n : U32))

def crc.fin(r: Bytes.Bytes & Crc) -> Bytes.Bytes & U32:
  (b, Crc{t, +h}) = r
  (b, (h .^. 4294967295 : U32))

def crc32(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  crc.fin(bytewise(~Crc, ~crc.byte, ~crc.word, b, Crc{crc.fill(256n, 0, Array.new(U32, 8n, 0)), 4294967295}))

# Adler-32 (RFC 1950 §9). The state is the checksum itself: s2 << 16 | s1.
# A word takes mod 65521 once, after four bytes; no sum reaches 2^32 first.
def adler.of(+s1: U32, +s2: U32) -> U32:
  (((s2 % 65521) << 16n) .|. (s1 % 65521) : U32)

def adler.byte(h0: U32, +c: U32) -> U32:
  +h = h0
  +s1 = ((h .&. 65535) + c : U32)
  adler.of(s1, ((h >> 16n) + s1 : U32))

def adler.word(h0: U32, +w: U32) -> U32:
  +h = h0
  +a0 = ((h .&. 65535) + (w .&. 255) : U32)
  +a1 = (a0 + ((w >> 8n) .&. 255) : U32)
  +a2 = (a1 + ((w >> 16n) .&. 255) : U32)
  +a3 = (a2 + (w >> 24n) : U32)
  adler.of(a3, ((h >> 16n) + a0 + a1 + a2 + a3 : U32))

def adler32(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  bytewise(~U32, ~adler.byte, ~adler.word, b, 1)

# xxHash32 (XXH32, xxHash spec 0.1.1).
type V4 is Data:
  V4{a: U32, b: U32, c: U32, d: U32}

def x32.round(+acc: U32, +x: U32) -> U32:
  (rotl32((acc + x * 2246822519 : U32), 13n, 19n) * 2654435761 : U32)

# The four accumulators take lanes in turn: v1 eats this word and moves to the back.
def x32.lane(v: V4, +w: U32) -> V4:
  match v:
    case V4{a, b, c, d}:
      V4{b, c, d, x32.round(a, w)}

def x32.merge(r: Array<U32> & V4) -> Array<U32> & U32:
  (buf, V4{+a, +b, +c, +d}) = r
  (buf, (rotl32(a, 1n, 31n) + rotl32(b, 7n, 25n) + rotl32(c, 12n, 20n) + rotl32(d, 18n, 14n) : U32))

def x32.word(h: U32, +w: U32) -> U32:
  (rotl32((h + w * 3266489917 : U32), 17n, 15n) * 668265263 : U32)

def x32.byte(h: U32, +c: U32) -> U32:
  (rotl32((h + c * 374761393 : U32), 11n, 21n) * 2654435761 : U32)

def x32.aval.c(+h: U32) -> U32:
  (h .^. (h >> 16n) : U32)

def x32.aval.b(+h: U32) -> U32:
  x32.aval.c(((h .^. (h >> 13n)) * 3266489917 : U32))

def x32.aval(+h: U32) -> U32:
  x32.aval.b(((h .^. (h >> 15n)) * 2246822519 : U32))

def x32.tail(+len: U32, +h: U32, r: Array<U32> & U32) -> Bytes.Bytes & U32:
  (a, +w) = r
  (Bytes.Bytes{len, a}, x32.aval(tail(~U32, ~x32.byte, U32.to_nat((len .&. 3 : U32)), w, h)))

def x32.rest(+len: U32, r: Array<U32> & U32) -> Bytes.Bytes & U32:
  (a, +h) = r
  x32.tail(len, h, Array.get(U32, a, (len >> 2n : U32)))

def x32.mid(+len: U32, r: Array<U32> & U32) -> Bytes.Bytes & U32:
  (a, +h) = r
  x32.rest(len, wfrom(~U32, ~x32.word, U32.to_nat(((len .&. 15) >> 2n : U32)), a, ((len >> 4n) << 2n : U32), (h + len : U32)))

def x32.start(big: Bool, +len: U32, +seed: U32, a: Array<U32>) -> Array<U32> & U32:
  match big:
    case True{}:
      x32.merge(wfrom(~V4, ~x32.lane, U32.to_nat(((len >> 4n) << 2n : U32)), a, 0, V4{(seed + 606290984 : U32), (seed + 2246822519 : U32), seed, (seed + 1640531535 : U32)}))
    case False{}:
      (a, (seed + 374761393 : U32))

def xxh32(b: Bytes.Bytes, +seed: U32) -> Bytes.Bytes & U32:
  Bytes.Bytes{+len, buf} = b
  x32.mid(len, x32.start(U32.is_le(16, len), len, seed, buf))

# xxHash64 (XXH64, xxHash spec 0.1.1).
type V64 is Data:
  V64{a: W64, b: W64, c: W64, d: W64}

def x64.P1() -> W64:
  W64{2654435761, 2246822535}

def x64.P2() -> W64:
  W64{3266489917, 668265295}

def x64.P3() -> W64:
  W64{374761393, 2654435833}

def x64.P4() -> W64:
  W64{2246822519, 3266489955}

def x64.P5() -> W64:
  W64{668265263, 374761413}

def x64.round(acc: W64, x: W64) -> W64:
  W64.mul(W64.rotl(31n, 1n, W64.add(acc, W64.mul(x, x64.P2()))), x64.P1())

def x64.lane(v: V64, +m: W64) -> V64:
  match v:
    case V64{a, b, c, d}:
      V64{b, c, d, x64.round(a, m)}

def x64.fold(h: W64, v: W64) -> W64:
  W64.add(W64.mul(W64.xor(h, x64.round(W64{0, 0}, v)), x64.P1()), x64.P4())

def x64.merge(r: Array<U32> & V64) -> Array<U32> & W64:
  (buf, V64{+a, +b, +c, +d}) = r
  +h = W64.add(W64.add(W64.rotl(1n, 31n, a), W64.rotl(7n, 25n, b)), W64.add(W64.rotl(12n, 20n, c), W64.rotl(18n, 14n, d)))
  (buf, x64.fold(x64.fold(x64.fold(x64.fold(h, a), b), c), d))

def x64.word(h: W64, +m: W64) -> W64:
  W64.add(W64.mul(W64.rotl(27n, 5n, W64.xor(h, x64.round(W64{0, 0}, m))), x64.P1()), x64.P4())

def x64.byte(h: W64, +c: U32) -> W64:
  W64.mul(W64.rotl(11n, 21n, W64.xor(h, W64.mul(W64{0, c}, x64.P5()))), x64.P1())

def x64.four(h: W64, +w: U32) -> W64:
  W64.add(W64.mul(W64.rotl(23n, 9n, W64.xor(h, W64.mul(W64{0, w}, x64.P1()))), x64.P2()), x64.P3())

def x64.aval.c(h: W64) -> W64:
  match h:
    case W64{+hi, lo}:
      W64{hi, (lo .^. hi : U32)}

def x64.aval.b(+h: W64) -> W64:
  x64.aval.c(W64.mul(W64.xor(h, W64.shr(29n, 3n, h)), x64.P3()))

def x64.aval(h: W64) -> W64:
  match h:
    case W64{+hi, lo}:
      x64.aval.b(W64.mul(W64{hi, (lo .^. (hi >> 1n) : U32)}, x64.P2()))

# The last len % 8 bytes: a 4-byte lane when there is one, then single bytes.
def x64.bytes(four: Bool, +k: Nat, h: W64, m: W64) -> W64:
  match four:
    case True{}:
      match m:
        case W64{+hi, +lo}:
          tail(~W64, ~x64.byte, k, hi, x64.four(h, lo))
    case False{}:
      match m:
        case W64{hi, +lo}:
          tail(~W64, ~x64.byte, k, lo, h)

def x64.tail(+len: U32, +h: W64, r: Array<U32> & W64) -> Bytes.Bytes & W64:
  (a, m) = r
  (Bytes.Bytes{len, a}, x64.aval(x64.bytes(U32.is_ne((len .&. 4 : U32), 0), U32.to_nat((len .&. 3 : U32)), h, m)))

def x64.rest(+len: U32, r: Array<U32> & W64) -> Bytes.Bytes & W64:
  (a, h) = r
  x64.tail(len, h, get2(a, ((len >> 3n) << 1n : U32)))

def x64.mid(+len: U32, r: Array<U32> & W64) -> Bytes.Bytes & W64:
  (a, h) = r
  x64.rest(len, dfrom(~W64, ~x64.word, U32.to_nat(((len .&. 31) >> 3n : U32)), a, ((len >> 5n) << 3n : U32), W64.add(h, W64{0, len})))

def x64.start(big: Bool, +len: U32, +seed: W64, a: Array<U32>) -> Array<U32> & W64:
  match big:
    case True{}:
      x64.merge(dfrom(~V64, ~x64.lane, U32.to_nat(((len >> 5n) << 2n : U32)), a, 0, V64{W64.add(seed, W64{1625958382, 2915087830}), W64.add(seed, x64.P2()), seed, W64.add(seed, W64{1640531534, 2048144761})}))
    case False{}:
      (a, W64.add(seed, x64.P5()))

def xxh64(b: Bytes.Bytes, +seed: W64) -> Bytes.Bytes & W64:
  Bytes.Bytes{+len, buf} = b
  x64.mid(len, x64.start(U32.is_le(32, len), len, seed, buf))

# SipHash-1-3 (Aumasson and Bernstein, 2012): one round per block, three to finish.
type S4 is Data:
  S4{v0: W64, v1: W64, v2: W64, v3: W64}

def sip.round(s: S4) -> S4:
  S4{v0, +v1, v2, +v3} = s
  +a0 = W64.add(v0, v1)
  +b1 = W64.xor(W64.rotl(13n, 19n, v1), a0)
  +a2 = W64.add(v2, v3)
  +b3 = W64.xor(W64.rotl(16n, 16n, v3), a2)
  +c0 = W64.add(W64.swap(a0), b3)
  +c2 = W64.add(a2, b1)
  S4{c0, W64.xor(W64.rotl(17n, 15n, b1), c2), W64.swap(c2), W64.xor(W64.rotl(21n, 11n, b3), c0)}

def sip.post(+m: W64, s: S4) -> S4:
  S4{v0, v1, v2, v3} = s
  S4{W64.xor(v0, m), v1, v2, v3}

def sip.block(s: S4, +m: W64) -> S4:
  S4{v0, v1, v2, v3} = s
  sip.post(m, sip.round(S4{v0, v1, v2, W64.xor(v3, m)}))

def sip.fin(s: S4) -> W64:
  S4{v0, v1, v2, v3} = s
  W64.xor(W64.xor(v0, v1), W64.xor(v2, v3))

def sip.end(s: S4) -> W64:
  S4{v0, v1, v2, v3} = s
  sip.fin(sip.round(sip.round(sip.round(S4{v0, v1, W64.xor(v2, W64{0, 255}), v3}))))

# The last block: the len % 8 bytes left, and len mod 256 in the top byte.
def sip.last(+len: U32, r: Array<U32> & W64, s: S4) -> Bytes.Bytes & W64:
  (a, W64{+hi, +lo}) = r
  +k = (len .&. 7 : U32)
  +top = ((len .&. 255) << 24n : U32)
  (Bytes.Bytes{len, a}, sip.end(sip.block(s, W64{(Bool.pick(U32, U32.is_lt(4, k), hi, 0) .|. top : U32), Bool.pick(U32, U32.is_lt(0, k), lo, 0)})))

def sip.rest(+len: U32, r: Array<U32> & S4) -> Bytes.Bytes & W64:
  (a, s) = r
  sip.last(len, get2(a, ((len >> 3n) << 1n : U32)), s)

def siphash13(b: Bytes.Bytes, +k0: W64, +k1: W64) -> Bytes.Bytes & W64:
  Bytes.Bytes{+len, buf} = b
  sip.rest(len, dfrom(~S4, ~sip.block, U32.to_nat((len >> 3n : U32)), buf, 0, S4{W64.xor(k0, W64{1936682341, 1886610805}), W64.xor(k1, W64{1685025377, 1852075885}), W64.xor(k0, W64{1819895653, 1852142177}), W64.xor(k1, W64{1952801890, 2037671283})}))

# The same hashes over a byte string. ponytail: copies to Bytes; hash short strings in place if the copy shows up in profiles.
def v32(r: Bytes.Bytes & U32) -> U32:
  (b, h) = r
  h

def v64(r: Bytes.Bytes & W64) -> W64:
  (b, h) = r
  h

def fnv1a32.str(+s: String) -> U32:
  v32(fnv1a32(Bytes.from_string(s)))

def fnv1a64.str(+s: String) -> W64:
  v64(fnv1a64(Bytes.from_string(s)))

def xxh32.str(+s: String, +seed: U32) -> U32:
  v32(xxh32(Bytes.from_string(s), seed))

def xxh64.str(+s: String, +seed: W64) -> W64:
  v64(xxh64(Bytes.from_string(s), seed))

def siphash13.str(+s: String, +k0: W64, +k1: W64) -> W64:
  v64(siphash13(Bytes.from_string(s), k0, k1))

def crc32.str(+s: String) -> U32:
  v32(crc32(Bytes.from_string(s)))

def adler32.str(+s: String) -> U32:
  v32(adler32(Bytes.from_string(s)))
