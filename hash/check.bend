import Base
import bend-kit-bytes@0.3.3.1/bytes.bend as Bytes
import ./hash.bend as Hash

def fill(n: Nat, b: Bytes.Bytes, +i: U32, +seed: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      fill(p, Bytes.set(b, i, ((i * 73 + seed) .&. 255 : U32)), (i + 1 : U32), seed)

def bits(n: Nat, +h: U32) -> U32:
  match n:
    case 0n:
      h
    case 1n+p:
      bits(p, ((h >> 1n) .^. Bool.pick(U32, U32.is_eq((h .&. 1 : U32), 1), 3988292384, 0) : U32))

def reference(n: Nat, r: Array<U32> & U32, +i: U32, +h: U32) -> U32:
  match n:
    case 0n:
      (h .^. 4294967295 : U32)
    case 1n+p:
      (a, +c) = r
      reference(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), bits(8n, (h .^. c : U32)))

def expected(b: Bytes.Bytes) -> U32:
  Bytes.Bytes{+len, a} = b
  reference(U32.to_nat(len), Bytes.peek(a, 0), 0, 4294967295)

def compare(r: Bytes.Bytes & U32) -> Bool:
  (b, h) = r
  U32.is_eq(h, expected(b))

def check(+len: U32, +seed: U32) -> Bool:
  b = fill(U32.to_nat(len), Bytes.Bytes{len, [4294967295 : U32*128n]}, 0, seed)
  compare(Hash.crc32(b))

def lengths(n: Nat, +len: U32, ok: Bool) -> Bool:
  match n:
    case 0n:
      ok
    case 1n+p:
      lengths(p, (len + 1 : U32), ok && check(len, 0) && check(len, 197))

# Reference: https://raw.githubusercontent.com/veorq/SipHash/371dd98e3508045bc8346da3ed8225b76ce536f6/vectors.h
def sip.vectors() -> List<Hash.W64>:
  [
    Hash.W64.of(1919933255, 3708685873),
    Hash.W64.of(1962424773, 2480695293),
    Hash.W64.of(225214473, 3651751770),
    Hash.W64.of(2238146198, 3623583277),
    Hash.W64.of(3475477728, 661751735),
    Hash.W64.of(410408292, 3449398925),
    Hash.W64.of(3418965614, 1493099470),
    Hash.W64.of(2869035253, 2332152119),
    Hash.W64.of(2482369913, 2593334370),
    Hash.W64.of(2650833631, 195683504),
    Hash.W64.of(2052963269, 2497559027),
    Hash.W64.of(4105383750, 577482151),
    Hash.W64.of(1964937148, 2249123323),
    Hash.W64.of(350901799, 3229891984),
    Hash.W64.of(4146317968, 2390422254),
    Hash.W64.of(2703870561, 1237206501),
    Hash.W64.of(1059769471, 1472371675),
    Hash.W64.of(1771760117, 750667668),
    Hash.W64.of(1270985712, 2525877148),
    Hash.W64.of(3144534301, 2809749949),
    Hash.W64.of(3201719538, 446885528),
    Hash.W64.of(3505572784, 775645127),
    Hash.W64.of(2471716757, 3819126408),
    Hash.W64.of(2819359628, 3445411528),
    Hash.W64.of(3098366150, 4132024212),
    Hash.W64.of(3168899806, 2324019434),
    Hash.W64.of(400045496, 1538987507),
    Hash.W64.of(791568739, 124506029),
    Hash.W64.of(3729631916, 2803747237),
    Hash.W64.of(2795655270, 2274714993),
    Hash.W64.of(2911347539, 1548349224),
    Hash.W64.of(853054202, 3628188482),
    Hash.W64.of(1898402095, 1928494286),
    Hash.W64.of(2817729350, 4183390435),
    Hash.W64.of(316715034, 3137671736),
    Hash.W64.of(367015124, 262248366),
    Hash.W64.of(827195326, 135635892),
    Hash.W64.of(41521392, 694303105),
    Hash.W64.of(3403470053, 2666794061),
    Hash.W64.of(2596264054, 1781756764),
    Hash.W64.of(238987627, 1392814032),
    Hash.W64.of(2903261910, 4233648530),
    Hash.W64.of(410191560, 2613188009),
    Hash.W64.of(3567651516, 4084804501),
    Hash.W64.of(4181017885, 3841072626),
    Hash.W64.of(2840825604, 427120519),
    Hash.W64.of(3684355551, 4117538064),
    Hash.W64.of(3496777933, 1544123883),
    Hash.W64.of(3859981259, 2664147281),
    Hash.W64.of(3345409580, 4239241110),
    Hash.W64.of(3999548250, 2538798706),
    Hash.W64.of(2710754678, 2990872154),
    Hash.W64.of(176654271, 2395698354),
    Hash.W64.of(2176051005, 548707183),
    Hash.W64.of(2141725195, 2746412266),
    Hash.W64.of(609694145, 1017390233),
    Hash.W64.of(3079520175, 982352829),
    Hash.W64.of(3927627109, 841619979),
    Hash.W64.of(1625693219, 2742636563),
    Hash.W64.of(1711724516, 1177037715),
    Hash.W64.of(1822747825, 1549767137),
    Hash.W64.of(2674027937, 1553343987),
    Hash.W64.of(3843766368, 2398248791),
    Hash.W64.of(2508862028, 3943056754)
  ]

def sip.string(n: Nat, +i: U32) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{Chr{(i .&. 255 : U32)}, sip.string(p, (i + 1 : U32))}

def sip.fill(n: Nat, b: Bytes.Bytes, +i: U32) -> Bytes.Bytes:
  match n:
    case 0n:
      b
    case 1n+p:
      sip.fill(p, Bytes.set(b, i, (i .&. 255 : U32)), (i + 1 : U32))

def sip.equal(+a: Hash.W64, +b: Hash.W64) -> Bool:
  U32.is_eq(Hash.W64.hi(a), Hash.W64.hi(b)) && U32.is_eq(Hash.W64.lo(a), Hash.W64.lo(b))

def sip.check(+len: U32, +want: Hash.W64) -> Bool:
  +s = sip.string(U32.to_nat(len), 0)
  +k0 = Hash.W64.of(117835012, 50462976)
  +k1 = Hash.W64.of(252579084, 185207048)
  clean = Hash.v64(Hash.siphash24(Bytes.from_string(s), k0, k1))
  dirty = sip.fill(U32.to_nat(len), Bytes.Bytes{len, [4294967295 : U32*256n]}, 0)
  padded = Hash.v64(Hash.siphash24(dirty, k0, k1))
  text = Hash.siphash24.str(s, k0, k1)
  sip.equal(clean, want) && sip.equal(padded, want) && sip.equal(text, want)

def sip13.check(+len: U32, +want: Hash.W64) -> Bool:
  +s = sip.string(U32.to_nat(len), 0)
  +k0 = Hash.W64.of(117835012, 50462976)
  +k1 = Hash.W64.of(252579084, 185207048)
  clean = Hash.v64(Hash.siphash13(Bytes.from_string(s), k0, k1))
  dirty = sip.fill(U32.to_nat(len), Bytes.Bytes{len, [4294967295 : U32*256n]}, 0)
  padded = Hash.v64(Hash.siphash13(dirty, k0, k1))
  text = Hash.siphash13.str(s, k0, k1)
  sip.equal(clean, want) && sip.equal(padded, want) && sip.equal(text, want)

def sip.result(ok: Bool, +len: U32) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "FAIL SipHash reference, byte-string parity, or dirty padding at length " ++ U32.show(len))

def sip.lengths(vectors: List<Hash.W64>, +len: U32) -> IO(Unit):
  match vectors:
    case Nil{}:
      IO.print("ok SipHash-2-4 reference lengths 0 through 63, byte-string parity, dirty padding")
    case Con{want, rest}:
      do IO<Unit>:
        sip.result(sip.check(len, want), len)
        sip.lengths(rest, (len + 1 : U32))

def sip.boundaries() -> IO(Unit):
  do IO<Unit>:
    sip.result(sip.check(255, Hash.W64.of(2848025086, 3343757850)), 255)
    sip.result(sip.check(256, Hash.W64.of(2577204518, 3534208983)), 256)
    sip.result(sip.check(257, Hash.W64.of(2323741581, 1437767496)), 257)
    sip.result(sip.check(511, Hash.W64.of(2526217168, 1583018562)), 511)
    sip.result(sip.check(512, Hash.W64.of(2285590467, 3847936526)), 512)
    sip.result(sip.check(513, Hash.W64.of(2427847039, 540107307)), 513)
    IO.print("ok SipHash-2-4 lengths 255, 256, 257, 511, 512, 513, byte-string parity, dirty padding")

def sip13.boundaries() -> IO(Unit):
  do IO<Unit>:
    sip.result(sip13.check(255, Hash.W64.of(4150400227, 356272661)), 255)
    sip.result(sip13.check(256, Hash.W64.of(1974724174, 377348976)), 256)
    sip.result(sip13.check(257, Hash.W64.of(1569717414, 557609912)), 257)
    sip.result(sip13.check(511, Hash.W64.of(2276097623, 1131805261)), 511)
    sip.result(sip13.check(512, Hash.W64.of(622999479, 1573115622)), 512)
    sip.result(sip13.check(513, Hash.W64.of(2399211897, 573359008)), 513)
    IO.print("ok SipHash-1-3 lengths 255, 256, 257, 511, 512, 513, byte-string parity, dirty padding")

def finish(ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("ok CRC-32 lengths 0 through 257, two byte patterns, dirty padding")
    case False{}:
      IO.die(Unit, 1, "FAIL CRC-32 boundaries")

def main() -> IO(Unit):
  do IO<Unit>:
    finish(lengths(258n, 0, True{}))
    sip.lengths(sip.vectors(), 0)
    sip.boundaries()
    sip13.boundaries()
