# Non-cryptographic hashes over Bytes: FNV-1a, xxHash, SipHash-1-3, CRC-32, and Adler-32. Source: https://github.com/paymog/bend-kit/tree/main/hash
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes

# Each hash hands the buffer back beside its value. A buffer's bytes at or past len are 0.
# Each hash also has a .str form over a byte string (one Char per octet), copied to Bytes first.
#   import bend-kit-hash@0.3.0.2/hash.bend as Hash

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
# The 256-entry table as a match, so no call rebuilds it.
def crc.tab(+i: U32) -> U32:
  match i:
    case 0: 0
    case 1: 1996959894
    case 2: 3993919788
    case 3: 2567524794
    case 4: 124634137
    case 5: 1886057615
    case 6: 3915621685
    case 7: 2657392035
    case 8: 249268274
    case 9: 2044508324
    case 10: 3772115230
    case 11: 2547177864
    case 12: 162941995
    case 13: 2125561021
    case 14: 3887607047
    case 15: 2428444049
    case 16: 498536548
    case 17: 1789927666
    case 18: 4089016648
    case 19: 2227061214
    case 20: 450548861
    case 21: 1843258603
    case 22: 4107580753
    case 23: 2211677639
    case 24: 325883990
    case 25: 1684777152
    case 26: 4251122042
    case 27: 2321926636
    case 28: 335633487
    case 29: 1661365465
    case 30: 4195302755
    case 31: 2366115317
    case 32: 997073096
    case 33: 1281953886
    case 34: 3579855332
    case 35: 2724688242
    case 36: 1006888145
    case 37: 1258607687
    case 38: 3524101629
    case 39: 2768942443
    case 40: 901097722
    case 41: 1119000684
    case 42: 3686517206
    case 43: 2898065728
    case 44: 853044451
    case 45: 1172266101
    case 46: 3705015759
    case 47: 2882616665
    case 48: 651767980
    case 49: 1373503546
    case 50: 3369554304
    case 51: 3218104598
    case 52: 565507253
    case 53: 1454621731
    case 54: 3485111705
    case 55: 3099436303
    case 56: 671266974
    case 57: 1594198024
    case 58: 3322730930
    case 59: 2970347812
    case 60: 795835527
    case 61: 1483230225
    case 62: 3244367275
    case 63: 3060149565
    case 64: 1994146192
    case 65: 31158534
    case 66: 2563907772
    case 67: 4023717930
    case 68: 1907459465
    case 69: 112637215
    case 70: 2680153253
    case 71: 3904427059
    case 72: 2013776290
    case 73: 251722036
    case 74: 2517215374
    case 75: 3775830040
    case 76: 2137656763
    case 77: 141376813
    case 78: 2439277719
    case 79: 3865271297
    case 80: 1802195444
    case 81: 476864866
    case 82: 2238001368
    case 83: 4066508878
    case 84: 1812370925
    case 85: 453092731
    case 86: 2181625025
    case 87: 4111451223
    case 88: 1706088902
    case 89: 314042704
    case 90: 2344532202
    case 91: 4240017532
    case 92: 1658658271
    case 93: 366619977
    case 94: 2362670323
    case 95: 4224994405
    case 96: 1303535960
    case 97: 984961486
    case 98: 2747007092
    case 99: 3569037538
    case 100: 1256170817
    case 101: 1037604311
    case 102: 2765210733
    case 103: 3554079995
    case 104: 1131014506
    case 105: 879679996
    case 106: 2909243462
    case 107: 3663771856
    case 108: 1141124467
    case 109: 855842277
    case 110: 2852801631
    case 111: 3708648649
    case 112: 1342533948
    case 113: 654459306
    case 114: 3188396048
    case 115: 3373015174
    case 116: 1466479909
    case 117: 544179635
    case 118: 3110523913
    case 119: 3462522015
    case 120: 1591671054
    case 121: 702138776
    case 122: 2966460450
    case 123: 3352799412
    case 124: 1504918807
    case 125: 783551873
    case 126: 3082640443
    case 127: 3233442989
    case 128: 3988292384
    case 129: 2596254646
    case 130: 62317068
    case 131: 1957810842
    case 132: 3939845945
    case 133: 2647816111
    case 134: 81470997
    case 135: 1943803523
    case 136: 3814918930
    case 137: 2489596804
    case 138: 225274430
    case 139: 2053790376
    case 140: 3826175755
    case 141: 2466906013
    case 142: 167816743
    case 143: 2097651377
    case 144: 4027552580
    case 145: 2265490386
    case 146: 503444072
    case 147: 1762050814
    case 148: 4150417245
    case 149: 2154129355
    case 150: 426522225
    case 151: 1852507879
    case 152: 4275313526
    case 153: 2312317920
    case 154: 282753626
    case 155: 1742555852
    case 156: 4189708143
    case 157: 2394877945
    case 158: 397917763
    case 159: 1622183637
    case 160: 3604390888
    case 161: 2714866558
    case 162: 953729732
    case 163: 1340076626
    case 164: 3518719985
    case 165: 2797360999
    case 166: 1068828381
    case 167: 1219638859
    case 168: 3624741850
    case 169: 2936675148
    case 170: 906185462
    case 171: 1090812512
    case 172: 3747672003
    case 173: 2825379669
    case 174: 829329135
    case 175: 1181335161
    case 176: 3412177804
    case 177: 3160834842
    case 178: 628085408
    case 179: 1382605366
    case 180: 3423369109
    case 181: 3138078467
    case 182: 570562233
    case 183: 1426400815
    case 184: 3317316542
    case 185: 2998733608
    case 186: 733239954
    case 187: 1555261956
    case 188: 3268935591
    case 189: 3050360625
    case 190: 752459403
    case 191: 1541320221
    case 192: 2607071920
    case 193: 3965973030
    case 194: 1969922972
    case 195: 40735498
    case 196: 2617837225
    case 197: 3943577151
    case 198: 1913087877
    case 199: 83908371
    case 200: 2512341634
    case 201: 3803740692
    case 202: 2075208622
    case 203: 213261112
    case 204: 2463272603
    case 205: 3855990285
    case 206: 2094854071
    case 207: 198958881
    case 208: 2262029012
    case 209: 4057260610
    case 210: 1759359992
    case 211: 534414190
    case 212: 2176718541
    case 213: 4139329115
    case 214: 1873836001
    case 215: 414664567
    case 216: 2282248934
    case 217: 4279200368
    case 218: 1711684554
    case 219: 285281116
    case 220: 2405801727
    case 221: 4167216745
    case 222: 1634467795
    case 223: 376229701
    case 224: 2685067896
    case 225: 3608007406
    case 226: 1308918612
    case 227: 956543938
    case 228: 2808555105
    case 229: 3495958263
    case 230: 1231636301
    case 231: 1047427035
    case 232: 2932959818
    case 233: 3654703836
    case 234: 1088359270
    case 235: 936918000
    case 236: 2847714899
    case 237: 3736837829
    case 238: 1202900863
    case 239: 817233897
    case 240: 3183342108
    case 241: 3401237130
    case 242: 1404277552
    case 243: 615818150
    case 244: 3134207493
    case 245: 3453421203
    case 246: 1423857449
    case 247: 601450431
    case 248: 3009837614
    case 249: 3294710456
    case 250: 1567103746
    case 251: 711928724
    case 252: 3020668471
    case 253: 3272380065
    case 254: 1510334235
    case _: 755167117

def crc.byte(h: U32, +c: U32) -> U32:
  +x = h
  (crc.tab(((x .^. c) .&. 255 : U32)) .^. (x >> 8n) : U32)

def crc.word(h: U32, +w: U32) -> U32:
  crc.byte(crc.byte(crc.byte(crc.byte(h, (w .&. 255 : U32)), ((w >> 8n) .&. 255 : U32)), ((w >> 16n) .&. 255 : U32)), (w >> 24n : U32))

def crc.fin(r: Bytes.Bytes & U32) -> Bytes.Bytes & U32:
  (b, +h) = r
  (b, (h .^. 4294967295 : U32))

def crc32(b: Bytes.Bytes) -> Bytes.Bytes & U32:
  crc.fin(bytewise(~U32, ~crc.byte, ~crc.word, b, 4294967295))

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

# The low n bytes of w, for n <= 4, so bytes past len never reach the hash.
def sip.keep(+w: U32, +n: U32) -> U32:
  Bool.pick(U32, U32.is_lt(n, 4), (w .&. (U32.shln(1, U32.to_nat((n * 8 : U32))) - 1) : U32), w)

# The last block: the len % 8 bytes left, and len mod 256 in the top byte.
def sip.last(+len: U32, r: Array<U32> & W64, s: S4) -> Bytes.Bytes & W64:
  (a, W64{+hi, +lo}) = r
  +k = (len .&. 7 : U32)
  +top = ((len .&. 255) << 24n : U32)
  (Bytes.Bytes{len, a}, sip.end(sip.block(s, W64{(sip.keep(hi, Bool.pick(U32, U32.is_lt(4, k), (k - 4 : U32), 0)) .|. top : U32), sip.keep(lo, U32.min(k, 4))})))

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
