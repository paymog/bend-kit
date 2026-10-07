# IEEE 754 binary64 add, sub, mul, and div. Source: https://github.com/paymog/bend-kit/tree/main/f64
import Base

# ponytail: two U32 halves, not Int.U64. Word(64n) is 64 bools and blows the C word limit. Replace these limbs with Base F64 when bendlang/bend#1120 lands.
# A NaN operand becomes one quiet NaN. Payloads are not kept. Rounding is ties to even.
# exp below is the IEEE biased exponent plus 4096, so a U32 never goes negative.

type W2 is Data:
  W2{hi: U32, lo: U32}

type W4 is Data:
  W4{a: U32, b: U32, c: U32, d: U32}

type Limb is Data:
  Limb{s: U32, c: U32}

type Step is Data:
  Step{rem: W2, q: W4}

type Cls is Data:
  Fin{}
  Inf{}
  Nan{}

type Parts is Data:
  Parts{kind: Cls, sign: U32, exp: U32, sig: W2}

type Norm is Data:
  Norm{sign: U32, exp: U32, w: W4, sticky: Bool}

type F64 is Data:
  F64{hi: U32, lo: U32}

def u01(b: Bool) -> U32:
  match b:
    case True{}:
      1
    case False{}:
      0

def clz.go(k: Nat, z: Bool, n: U32, +x: U32) -> U32:
  match k z:
    case 0n _:
      n
    case 1n+p False{}:
      n
    case 1n+p True{}:
      clz.go(p, U32.is_zero(((x << 1n) .&. 2147483648 : U32)), (n + 1 : U32), (x << 1n : U32))

def clz(+x: U32) -> U32:
  clz.go(32n, U32.is_zero((x .&. 2147483648 : U32)), 0, x)

def F64.nan() -> F64:
  F64{2146959360, 0}

def F64.inf.pos(pos: Bool) -> F64:
  match pos:
    case True{}:
      F64{2146435072, 0}
    case False{}:
      F64{4293918720, 0}

def F64.inf.sign(sign: U32) -> F64:
  F64.inf.pos(U32.is_zero(sign))

def F64.zero.sign(sign: U32) -> F64:
  F64{(sign << 31n : U32), 0}

def F64.pack(sign: U32, exp: U32, sh: U32, sl: U32) -> F64:
  F64{((sign << 31n) .|. (exp << 20n) .|. (sh .&. 1048575) : U32), sl}

def F64.hi(a: F64) -> U32:
  match a:
    case F64{hi, lo}:
      hi

def F64.lo(a: F64) -> U32:
  match a:
    case F64{hi, lo}:
      lo

def W2.nz(w: W2) -> Bool:
  match w:
    case W2{hi, lo}:
      Bool.not(Bool.and(U32.is_zero(hi), U32.is_zero(lo)))

def W2.bit.at(low: Bool, n: U32, hi: U32, lo: U32) -> U32:
  match low:
    case True{}:
      ((lo >> U32.to_nat(n)) .&. 1 : U32)
    case False{}:
      ((hi >> U32.to_nat((n - 32 : U32))) .&. 1 : U32)

def W2.bit(w: W2, +n: U32) -> U32:
  match w:
    case W2{hi, lo}:
      W2.bit.at(U32.is_lt(n, 32), n, hi, lo)

def W2.ge.eq(eq: Bool, al: U32, bl: U32) -> Bool:
  match eq:
    case False{}:
      False{}
    case True{}:
      U32.is_ge(al, bl)

def W2.ge.hi(gt: Bool, eq: Bool, al: U32, bl: U32) -> Bool:
  match gt:
    case True{}:
      True{}
    case False{}:
      W2.ge.eq(eq, al, bl)

def W2.ge(a: W2, b: W2) -> Bool:
  match a b:
    case W2{+ah, al} W2{+bh, bl}:
      W2.ge.hi(U32.is_gt(ah, bh), U32.is_eq(ah, bh), al, bl)

def W2.sub.of(ah: U32, bh: U32, al: U32, bl: U32, lo: U32) -> W2:
  W2{(ah - bh - u01(U32.is_lt(al, bl)) : U32), lo}

def W2.sub(a: W2, b: W2) -> W2:
  match a b:
    case W2{ah, +al} W2{bh, +bl}:
      W2.sub.of(ah, bh, al, bl, (al - bl : U32))

def W2.shl1(w: W2, bit: U32) -> W2:
  match w:
    case W2{hi, +lo}:
      W2{((hi << 1n) .|. (lo >> 31n) : U32), ((lo << 1n) .|. bit : U32)}

def W2.shl.small(z: Bool, +k: U32, hi: U32, +lo: U32) -> W2:
  match z:
    case True{}:
      W2{hi, lo}
    case False{}:
      W2{((hi << U32.to_nat(k)) .|. (lo >> U32.to_nat((32 - k : U32))) : U32), (lo << U32.to_nat(k) : U32)}

def W2.shl.big(big: Bool, +k: U32, w: W2) -> W2:
  match big w:
    case True{} W2{hi, lo}:
      W2{(lo << U32.to_nat((k - 32 : U32)) : U32), 0}
    case False{} W2{hi, lo}:
      W2.shl.small(U32.is_zero(k), k, hi, lo)

def W2.shl(w: W2, +k: U32) -> W2:
  W2.shl.big(U32.is_ge(k, 32), k, w)

def W2.msb.hi(z: Bool, hi: U32, lo: U32) -> U32:
  match z:
    case False{}:
      (63 - clz(hi) : U32)
    case True{}:
      (31 - clz(lo) : U32)

def W2.msb(w: W2) -> U32:
  match w:
    case W2{+hi, lo}:
      W2.msb.hi(U32.is_zero(hi), hi, lo)

def W2.inc.carry(z: Bool, hi: U32, lo: U32) -> W2:
  match z:
    case False{}:
      W2{hi, lo}
    case True{}:
      W2{(hi + 1 : U32), lo}

def W2.inc.of(hi: U32, +lo: U32) -> W2:
  W2.inc.carry(U32.is_zero(lo), hi, lo)

def W2.inc(w: W2) -> W2:
  match w:
    case W2{hi, lo}:
      W2.inc.of(hi, (lo + 1 : U32))

def W4.nz(w: W4) -> Bool:
  match w:
    case W4{a, b, c, d}:
      Bool.not(Bool.and(Bool.and(U32.is_zero(a), U32.is_zero(b)), Bool.and(U32.is_zero(c), U32.is_zero(d))))

def W4.shl1(w: W4) -> W4:
  match w:
    case W4{a, +b, +c, +d}:
      W4{((a << 1n) .|. (b >> 31n) : U32), ((b << 1n) .|. (c >> 31n) : U32), ((c << 1n) .|. (d >> 31n) : U32), (d << 1n : U32)}

def W4.set0(w: W4) -> W4:
  match w:
    case W4{a, b, c, d}:
      W4{a, b, c, (d .|. 1 : U32)}

def Limb.add.s(+x: U32, c: U32, +s1: U32) -> Limb:
  +s2 = (s1 + c : U32)
  Limb{s2, u01(Bool.or(U32.is_lt(s1, x), U32.is_lt(s2, s1)))}

def Limb.add(+x: U32, y: U32, c: U32) -> Limb:
  Limb.add.s(x, c, (x + y : U32))

def Limb.sub.s(x: U32, y: U32, +br: U32, +s1: U32) -> Limb:
  Limb{(s1 - br : U32), u01(Bool.or(U32.is_lt(x, y), U32.is_lt(s1, br)))}

def Limb.sub(+x: U32, +y: U32, br: U32) -> Limb:
  Limb.sub.s(x, y, br, (x - y : U32))

def W4.add.a(d: U32, c: U32, b: U32, limb: Limb) -> W4:
  match limb:
    case Limb{a, ca}:
      W4{a, b, c, d}

def W4.add.b(xa: U32, ya: U32, d: U32, c: U32, limb: Limb) -> W4:
  match limb:
    case Limb{b, cb}:
      W4.add.a(d, c, b, Limb.add(xa, ya, cb))

def W4.add.c(xa: U32, xb: U32, ya: U32, yb: U32, d: U32, limb: Limb) -> W4:
  match limb:
    case Limb{c, cc}:
      W4.add.b(xa, ya, d, c, Limb.add(xb, yb, cc))

def W4.add.d(xa: U32, xb: U32, xc: U32, ya: U32, yb: U32, yc: U32, limb: Limb) -> W4:
  match limb:
    case Limb{d, cd}:
      W4.add.c(xa, xb, ya, yb, d, Limb.add(xc, yc, cd))

def W4.add(x: W4, y: W4) -> W4:
  match x y:
    case W4{xa, xb, xc, xd} W4{ya, yb, yc, yd}:
      W4.add.d(xa, xb, xc, ya, yb, yc, Limb.add(xd, yd, 0))

def W4.sub.a(d: U32, c: U32, b: U32, limb: Limb) -> W4:
  match limb:
    case Limb{a, ba}:
      W4{a, b, c, d}

def W4.sub.b(xa: U32, ya: U32, d: U32, c: U32, limb: Limb) -> W4:
  match limb:
    case Limb{b, bb}:
      W4.sub.a(d, c, b, Limb.sub(xa, ya, bb))

def W4.sub.c(xa: U32, xb: U32, ya: U32, yb: U32, d: U32, limb: Limb) -> W4:
  match limb:
    case Limb{c, bc}:
      W4.sub.b(xa, ya, d, c, Limb.sub(xb, yb, bc))

def W4.sub.d(xa: U32, xb: U32, xc: U32, ya: U32, yb: U32, yc: U32, limb: Limb) -> W4:
  match limb:
    case Limb{d, bd}:
      W4.sub.c(xa, xb, ya, yb, d, Limb.sub(xc, yc, bd))

def W4.sub(x: W4, y: W4) -> W4:
  match x y:
    case W4{xa, xb, xc, xd} W4{ya, yb, yc, yd}:
      W4.sub.d(xa, xb, xc, ya, yb, yc, Limb.sub(xd, yd, 0))

def W4.one() -> W4:
  W4{0, 0, 0, 1}

def W4.drop1(w: W4) -> W4 & Bool:
  match w:
    case W4{a, b, c, d}:
      (W4{0, a, b, c}, Bool.not(U32.is_zero(d)))

def W4.drop2(w: W4) -> W4 & Bool:
  match w:
    case W4{a, b, c, d}:
      (W4{0, 0, a, b}, Bool.not(Bool.and(U32.is_zero(c), U32.is_zero(d))))

def W4.drop3(w: W4) -> W4 & Bool:
  match w:
    case W4{a, b, c, d}:
      (W4{0, 0, 0, a}, Bool.not(Bool.and(U32.is_zero(b), Bool.and(U32.is_zero(c), U32.is_zero(d)))))

def W4.shr.bits.out(+k: Nat, +j: Nat, +a: U32, +b: U32, +c: U32, d: U32, lost: Bool, low: U32) -> W4 & Bool:
  (W4{(a >> k : U32), ((b >> k) .|. (a << j) : U32), ((c >> k) .|. (b << j) : U32), ((d >> k) .|. (c << j) : U32)}, Bool.or(lost, Bool.not(U32.is_zero(low))))

def W4.shr.bits.go(+k: Nat, j: Nat, w: W4, lost: Bool) -> W4 & Bool:
  match w:
    case W4{+a, +b, +c, +d}:
      W4.shr.bits.out(k, j, a, b, c, d, lost, (d .&. ((1 << k) - 1 : U32) : U32))

def W4.shr.bits.z(z: Bool, +k: U32, w: W4, lost: Bool) -> W4 & Bool:
  match z:
    case True{}:
      (w, lost)
    case False{}:
      W4.shr.bits.go(U32.to_nat(k), U32.to_nat((32 - k : U32)), w, lost)

def W4.shr.bits(+k: U32, w: W4, lost: Bool) -> W4 & Bool:
  W4.shr.bits.z(U32.is_zero(k), k, w, lost)

def W4.shr.pair(bits: U32, r: W4 & Bool) -> W4 & Bool:
  (w, lost) = r
  W4.shr.bits(bits, w, lost)

def W4.shr.limbs(k: Nat, bits: U32, w: W4) -> W4 & Bool:
  match k:
    case 0n:
      W4.shr.bits(bits, w, False{})
    case 1n:
      W4.shr.pair(bits, W4.drop1(w))
    case 2n:
      W4.shr.pair(bits, W4.drop2(w))
    case 3n:
      W4.shr.pair(bits, W4.drop3(w))
    case 4n+p:
      (W4{0, 0, 0, 0}, W4.nz(w))

def W4.shr.wide(wide: Bool, +n: U32, w: W4) -> W4 & Bool:
  match wide:
    case True{}:
      (W4{0, 0, 0, 0}, W4.nz(w))
    case False{}:
      W4.shr.limbs(U32.to_nat((n >> 5n : U32)), (n .&. 31 : U32), w)

def W4.shr(w: W4, +n: U32) -> W4 & Bool:
  W4.shr.wide(U32.is_ge(n, 128), n, w)

def W4.slide1(w: W4) -> W4:
  match w:
    case W4{a, b, c, d}:
      W4{b, c, d, 0}

def W4.slide2(w: W4) -> W4:
  match w:
    case W4{a, b, c, d}:
      W4{c, d, 0, 0}

def W4.slide3(w: W4) -> W4:
  match w:
    case W4{a, b, c, d}:
      W4{d, 0, 0, 0}

def W4.shl.bits.go(+k: Nat, +j: Nat, w: W4) -> W4:
  match w:
    case W4{+a, +b, +c, +d}:
      W4{((a << k) .|. (b >> j) : U32), ((b << k) .|. (c >> j) : U32), ((c << k) .|. (d >> j) : U32), (d << k : U32)}

def W4.shl.bits.z(z: Bool, +k: U32, w: W4) -> W4:
  match z:
    case True{}:
      w
    case False{}:
      W4.shl.bits.go(U32.to_nat(k), U32.to_nat((32 - k : U32)), w)

def W4.shl.bits(+k: U32, w: W4) -> W4:
  W4.shl.bits.z(U32.is_zero(k), k, w)

def W4.shl.limbs(k: Nat, bits: U32, w: W4) -> W4:
  match k:
    case 0n:
      W4.shl.bits(bits, w)
    case 1n:
      W4.shl.bits(bits, W4.slide1(w))
    case 2n:
      W4.shl.bits(bits, W4.slide2(w))
    case 3n:
      W4.shl.bits(bits, W4.slide3(w))
    case 4n+p:
      W4{0, 0, 0, 0}

def W4.shl.wide(wide: Bool, +n: U32, w: W4) -> W4:
  match wide:
    case True{}:
      W4{0, 0, 0, 0}
    case False{}:
      W4.shl.limbs(U32.to_nat((n >> 5n : U32)), (n .&. 31 : U32), w)

def W4.shl(w: W4, +n: U32) -> W4:
  W4.shl.wide(U32.is_ge(n, 128), n, w)

def W4.msb.d(z: Bool, d: U32) -> Maybe<&2, U32>:
  match z:
    case True{}:
      None{}
    case False{}:
      Some{(31 - clz(d) : U32)}

def W4.msb.c(z: Bool, c: U32, +d: U32) -> Maybe<&2, U32>:
  match z:
    case False{}:
      Some{(63 - clz(c) : U32)}
    case True{}:
      W4.msb.d(U32.is_zero(d), d)

def W4.msb.b(z: Bool, b: U32, +c: U32, d: U32) -> Maybe<&2, U32>:
  match z:
    case False{}:
      Some{(95 - clz(b) : U32)}
    case True{}:
      W4.msb.c(U32.is_zero(c), c, d)

def W4.msb.a(z: Bool, a: U32, +b: U32, c: U32, d: U32) -> Maybe<&2, U32>:
  match z:
    case False{}:
      Some{(127 - clz(a) : U32)}
    case True{}:
      W4.msb.b(U32.is_zero(b), b, c, d)

def W4.msb(w: W4) -> Maybe<&2, U32>:
  match w:
    case W4{+a, b, c, d}:
      W4.msb.a(U32.is_zero(a), a, b, c, d)

def mul32.of(+p00: U32, +p01: U32, +p10: U32, +p11: U32) -> W2:
  +mid = ((p00 >> 16n) + (p01 .&. 65535) + (p10 .&. 65535) : U32)
  W2{(p11 + (p01 >> 16n) + (p10 >> 16n) + (mid >> 16n) : U32), ((p00 .&. 65535) .|. (mid << 16n) : U32)}

def mul32(+x: U32, +y: U32) -> W2:
  +x0 = (x .&. 65535 : U32)
  +x1 = (x >> 16n : U32)
  +y0 = (y .&. 65535 : U32)
  +y1 = (y >> 16n : U32)
  mul32.of((x0 * y0 : U32), (x0 * y1 : U32), (x1 * y0 : U32), (x1 * y1 : U32))

def mul.sum6(d: U32, c: U32, h11: U32, b12: U32, limb: Limb) -> W4:
  match limb:
    case Limb{b, b3}:
      W4{(h11 + (b12 + b3 : U32) : U32), b, c, d}

def mul.sum5(d: U32, c: U32, h11: U32, +b: U32, b12: U32, carry: U32) -> W4:
  mul.sum6(d, c, h11, b12, Limb.add(b, carry, 0))

def mul.sum4(d: U32, c: U32, h11: U32, b1: U32, carry: U32, limb: Limb) -> W4:
  match limb:
    case Limb{+b, b2}:
      mul.sum5(d, c, h11, b, (b1 + b2 : U32), carry)

def mul.sum3(d: U32, c: U32, h10: U32, h11: U32, carry: U32, limb: Limb) -> W4:
  match limb:
    case Limb{b, b1}:
      mul.sum4(d, c, h11, b1, carry, Limb.add(b, h10, 0))

def mul.sum2(d: U32, c1: U32, h01: U32, h10: U32, h11: U32, l11: U32, limb: Limb) -> W4:
  match limb:
    case Limb{c, c2}:
      mul.sum3(d, c, h10, h11, (c1 + c2 : U32), Limb.add(l11, h01, 0))

def mul.sum1(d: U32, h01: U32, l10: U32, h10: U32, h11: U32, l11: U32, limb: Limb) -> W4:
  match limb:
    case Limb{c, c1}:
      mul.sum2(d, c1, h01, h10, h11, l11, Limb.add(c, l10, 0))

def mul.acc(p00: W2, p01: W2, p10: W2, p11: W2) -> W4:
  match p00 p01 p10 p11:
    case W2{h00, l00} W2{h01, l01} W2{h10, l10} W2{h11, l11}:
      mul.sum1(l00, h01, l10, h10, h11, l11, Limb.add(h00, l01, 0))

def mul.wide(+xh: U32, +xl: U32, +yh: U32, +yl: U32) -> W4:
  mul.acc(mul32(xl, yl), mul32(xl, yh), mul32(xh, yl), mul32(xh, yh))

def div.bit.small(small: Bool, idx: U32, ma: W2) -> U32:
  match small:
    case True{}:
      0
    case False{}:
      W2.bit(ma, (idx - 116 : U32))

def div.bit(+p: Nat, ma: W2) -> U32:
  div.bit.small(U32.is_lt(U32.from_nat(p), 116), U32.from_nat(p), ma)

def div.ge(ge: Bool, rem: W2, q: W4, mb: W2) -> Step:
  match ge:
    case True{}:
      Step{W2.sub(rem, mb), W4.set0(q)}
    case False{}:
      Step{rem, q}

def div.rem(+rem: W2, q: W4, +mb: W2) -> Step:
  div.ge(W2.ge(rem, mb), rem, q, mb)

def div.advance(p: Nat, st: Step, mb: W2, ma: W2) -> Step:
  match st:
    case Step{rem, q}:
      div.rem(W2.shl1(rem, div.bit(p, ma)), W4.shl1(q), mb)

def div.finish(st: Step) -> W4 & Bool:
  match st:
    case Step{rem, q}:
      (q, W2.nz(rem))

def div.go(k: Nat, st: Step, +mb: W2, +ma: W2) -> W4 & Bool:
  match k:
    case 0n:
      div.finish(st)
    case 1n+p:
      +q = p
      div.go(q, div.advance(q, st, mb, ma), mb, ma)

def div.q(ma: W2, mb: W2) -> W4 & Bool:
  div.go(169n, Step{W2{0, 0}, W4{0, 0, 0, 0}}, mb, ma)

def round.sub(sub: Bool, sign: U32, exp: U32, sh: U32, sl: U32) -> F64:
  match sub:
    case True{}:
      F64.pack(sign, 0, sh, sl)
    case False{}:
      F64.pack(sign, exp, sh, sl)

def round.zero.lo(zl: Bool, sign: U32, exp: U32, +sh: U32, sl: U32) -> F64:
  match zl:
    case True{}:
      F64.zero.sign(sign)
    case False{}:
      round.sub(U32.is_lt(sh, 1048576), sign, (exp - 4096 : U32), sh, sl)

def round.zero(zh: Bool, zl: Bool, sign: U32, exp: U32, +sh: U32, sl: U32) -> F64:
  match zh:
    case False{}:
      round.sub(U32.is_lt(sh, 1048576), sign, (exp - 4096 : U32), sh, sl)
    case True{}:
      round.zero.lo(zl, sign, exp, sh, sl)

def round.inf(big: Bool, sign: U32, exp: U32, +sh: U32, +sl: U32) -> F64:
  match big:
    case True{}:
      F64.inf.sign(sign)
    case False{}:
      round.zero(U32.is_zero(sh), U32.is_zero(sl), sign, exp, sh, sl)

def round.pack(sign: U32, +exp: U32, sh: U32, sl: U32) -> F64:
  round.inf(U32.is_ge((exp - 4096 : U32), 2047), sign, exp, sh, sl)

def round.ov(ov: Bool, sign: U32, exp: U32, sh: U32, sl: U32) -> F64:
  match ov:
    case True{}:
      round.pack(sign, (exp + 1 : U32), 1048576, 0)
    case False{}:
      round.pack(sign, exp, sh, sl)

def round.inc(sign: U32, exp: U32, w: W2) -> F64:
  match w:
    case W2{+sh, sl}:
      round.ov(U32.is_ge(sh, 2097152), sign, exp, sh, sl)

def round.should(+c: U32, d: U32, sl: U32, sticky: Bool) -> Bool:
  Bool.and(U32.is_ge(c, 2147483648), Bool.or(Bool.or(sticky, Bool.not(U32.is_zero((c .&. 2147483647 : U32)))), Bool.or(Bool.not(U32.is_zero(d)), U32.is_eq((sl .&. 1 : U32), 1))))

def round.up(up: Bool, sign: U32, exp: U32, sh: U32, sl: U32) -> F64:
  match up:
    case False{}:
      round.pack(sign, exp, sh, sl)
    case True{}:
      round.inc(sign, exp, W2.inc(W2{sh, sl}))

def round.sig(sign: U32, exp: U32, sh: U32, +sl: U32, c: U32, d: U32, sticky: Bool) -> F64:
  round.up(round.should(c, d, sl, sticky), sign, exp, sh, sl)

def round.go(sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  match w:
    case W4{a, b, c, d}:
      round.sig(sign, exp, (a .&. 2097151 : U32), b, c, d, sticky)


def norm.right.pair(sign: U32, exp: U32, sticky: Bool, r: W4 & Bool) -> F64:
  (w, lost) = r
  round.go(sign, exp, w, Bool.or(sticky, lost))

def norm.right.sh(+sh: U32, sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  norm.right.pair(sign, (exp + sh : U32), sticky, W4.shr(w, sh))

def norm.right(top: U32, sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  norm.right.sh((top - 116 : U32), sign, exp, w, sticky)

def norm.left.room0(z: Bool, room: U32, sign: U32, w: W4, sticky: Bool) -> F64:
  match z:
    case True{}:
      round.go(sign, 4097, w, sticky)
    case False{}:
      round.go(sign, 4097, W4.shl(w, room), sticky)

def norm.left.fit(fit: Bool, +need: U32, +room: U32, sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  match fit:
    case True{}:
      round.go(sign, (exp - need : U32), W4.shl(w, need), sticky)
    case False{}:
      norm.left.room0(U32.is_zero(room), room, sign, w, sticky)

def norm.left.room(+need: U32, +room: U32, sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  norm.left.fit(U32.is_le(need, room), need, room, sign, exp, w, sticky)

def norm.left.need(need: U32, sign: U32, +exp: U32, w: W4, sticky: Bool) -> F64:
  norm.left.room(need, (exp - 4097 : U32), sign, exp, w, sticky)

def norm.left(top: U32, sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  norm.left.need((116 - top : U32), sign, exp, w, sticky)

def norm.lo(lo: Bool, top: U32, sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  match lo:
    case True{}:
      norm.left(top, sign, exp, w, sticky)
    case False{}:
      round.go(sign, exp, w, sticky)

def norm.hi(hi: Bool, +top: U32, sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  match hi:
    case True{}:
      norm.right(top, sign, exp, w, sticky)
    case False{}:
      norm.lo(U32.is_lt(top, 116), top, sign, exp, w, sticky)
def norm.top(m: Maybe<&2, U32>, sign: U32, exp: U32, w: W4, sticky: Bool) -> F64:
  match m:
    case None{}:
      F64.zero.sign(sign)
    case Some{+top}:
      norm.hi(U32.is_gt(top, 116), top, sign, exp, w, sticky)

def norm.z(nz: Bool, sign: U32, exp: U32, +w: W4, sticky: Bool) -> F64:
  match nz:
    case False{}:
      F64.zero.sign(sign)
    case True{}:
      norm.top(W4.msb(w), sign, exp, w, sticky)

def norm.go(st: Norm) -> F64:
  match st:
    case Norm{sign, exp, +w, sticky}:
      norm.z(W4.nz(w), sign, exp, w, sticky)

def under.pair(sign: U32, sticky: Bool, r: W4 & Bool) -> F64:
  (w, lost) = r
  norm.go(Norm{sign, 4097, w, Bool.or(sticky, lost)})

def under.shr(sign: U32, w: W4, sticky: Bool, sh: U32) -> F64:
  under.pair(sign, sticky, W4.shr(w, sh))

def under.low(low: Bool, exp: U32, sign: U32, w: W4, sticky: Bool) -> F64:
  match low:
    case False{}:
      norm.go(Norm{sign, exp, w, sticky})
    case True{}:
      under.shr(sign, w, sticky, (4097 - exp : U32))

def under(sign: U32, +exp: U32, w: W4, sticky: Bool) -> F64:
  under.low(U32.is_lt(exp, 4097), exp, sign, w, sticky)

def mag.eq(eq: Bool, al: U32, bl: U32) -> Bool:
  match eq:
    case False{}:
      False{}
    case True{}:
      U32.is_lt(al, bl)

def mag.hi(lt: Bool, eq: Bool, al: U32, bl: U32) -> Bool:
  match lt:
    case True{}:
      True{}
    case False{}:
      mag.eq(eq, al, bl)

def mag.same(eq: Bool, ma: W2, mb: W2) -> Bool:
  match eq ma mb:
    case False{} W2{ah, al} W2{bh, bl}:
      False{}
    case True{} W2{+ah, al} W2{+bh, bl}:
      mag.hi(U32.is_lt(ah, bh), U32.is_eq(ah, bh), al, bl)

def mag.exp(lt: Bool, eq: Bool, ma: W2, mb: W2) -> Bool:
  match lt:
    case True{}:
      True{}
    case False{}:
      mag.same(eq, ma, mb)

def mag.lt(+ea: U32, ma: W2, +eb: U32, mb: W2) -> Bool:
  mag.exp(U32.is_lt(ea, eb), U32.is_eq(ea, eb), ma, mb)

def add.cancel(nz: Bool, sign: U32, exp: U32, total: W4, sticky: Bool) -> F64:
  match nz:
    case False{}:
      F64{0, 0}
    case True{}:
      norm.go(Norm{sign, exp, total, sticky})

def add.borrow(sign: U32, exp: U32, +total: W4) -> F64:
  add.cancel(W4.nz(total), sign, exp, total, True{})

def add.sub.lost(lost: Bool, sign: U32, exp: U32, +total: W4) -> F64:
  match lost:
    case False{}:
      add.cancel(W4.nz(total), sign, exp, total, False{})
    case True{}:
      add.borrow(sign, exp, W4.sub(total, W4.one()))

def add.sign(same: Bool, sign: U32, exp: U32, +aa: W4, +trunc: W4, lost: Bool) -> F64:
  match same:
    case True{}:
      norm.go(Norm{sign, exp, W4.add(aa, trunc), lost})
    case False{}:
      add.sub.lost(lost, sign, exp, W4.sub(aa, trunc))

def add.pair(same: Bool, sign: U32, exp: U32, aa: W4, r: W4 & Bool) -> F64:
  (trunc, lost) = r
  add.sign(same, sign, exp, aa, trunc, lost)

def add.de(same: Bool, sa: U32, ea: U32, ma: W2, de: U32, mb: W2) -> F64:
  match ma mb:
    case W2{ah, al} W2{bh, bl}:
      add.pair(same, sa, ea, W4{ah, al, 0, 0}, W4.shr(W4{bh, bl, 0, 0}, de))
def add.ord(swap: Bool, +sa: U32, +ea: U32, +ma: W2, +sb: U32, +eb: U32, +mb: W2) -> F64:
  match swap:
    case True{}:
      add.de(U32.is_eq(sb, sa), sb, eb, mb, (eb - ea : U32), ma)
    case False{}:
      add.de(U32.is_eq(sa, sb), sa, ea, ma, (ea - eb : U32), mb)


def add.fin(+sa: U32, +ea: U32, +ma: W2, +sb: U32, +eb: U32, +mb: W2) -> F64:
  add.ord(mag.lt(ea, ma, eb, mb), sa, ea, ma, sb, eb, mb)

def add.fin.z(na: Bool, nb: Bool, a: F64, b: F64, +sa: U32, ea: U32, ma: W2, sb: U32, eb: U32, mb: W2) -> F64:
  match na nb:
    case False{} False{}:
      F64.zero.sign(u01(Bool.and(U32.is_eq(sa, sb), U32.is_eq(sa, 1))))
    case False{} True{}:
      b
    case True{} False{}:
      a
    case True{} True{}:
      add.fin(sa, ea, ma, sb, eb, mb)

def add.kb(kb: Cls, a: F64, b: F64, sa: U32, ea: U32, +ma: W2, sb: U32, eb: U32, +mb: W2) -> F64:
  match kb:
    case Nan{}:
      F64.nan()
    case Inf{}:
      F64.inf.sign(sb)
    case Fin{}:
      add.fin.z(W2.nz(ma), W2.nz(mb), a, b, sa, ea, ma, sb, eb, mb)

def add.inf.both(same: Bool, sa: U32) -> F64:
  match same:
    case True{}:
      F64.inf.sign(sa)
    case False{}:
      F64.nan()

def add.inf.a(kb: Cls, +sa: U32, sb: U32) -> F64:
  match kb:
    case Nan{}:
      F64.nan()
    case Inf{}:
      add.inf.both(U32.is_eq(sa, sb), sa)
    case Fin{}:
      F64.inf.sign(sa)

def add.ka(ka: Cls, kb: Cls, a: F64, b: F64, sa: U32, ea: U32, ma: W2, sb: U32, eb: U32, mb: W2) -> F64:
  match ka:
    case Nan{}:
      F64.nan()
    case Inf{}:
      add.inf.a(kb, sa, sb)
    case Fin{}:
      add.kb(kb, a, b, sa, ea, ma, sb, eb, mb)

def add.both(a: F64, b: F64, pa: Parts, pb: Parts) -> F64:
  match pa pb:
    case Parts{ka, sa, ea, ma} Parts{kb, sb, eb, mb}:
      add.ka(ka, kb, a, b, sa, ea, ma, sb, eb, mb)

def unpack.sub(sub: Bool, exp: U32, +h: U32, l: U32) -> Parts:
  match sub:
    case True{}:
      Parts{Fin{}, (h >> 31n : U32), 4097, W2{(h .&. 1048575 : U32), l}}
    case False{}:
      Parts{Fin{}, (h >> 31n : U32), (exp + 4096 : U32), W2{((h .&. 1048575) .|. 1048576 : U32), l}}

def unpack.nan(z: Bool, h: U32) -> Parts:
  match z:
    case True{}:
      Parts{Inf{}, (h >> 31n : U32), 0, W2{0, 0}}
    case False{}:
      Parts{Nan{}, 0, 0, W2{0, 0}}

def unpack.special(naninf: Bool, sub: Bool, exp: U32, +h: U32, l: U32) -> Parts:
  match naninf:
    case True{}:
      unpack.nan(Bool.and(U32.is_zero((h .&. 1048575 : U32)), U32.is_zero(l)), h)
    case False{}:
      unpack.sub(sub, exp, h, l)

def unpack(+h: U32, l: U32) -> Parts:
  unpack.special(U32.is_eq(((h >> 20n) .&. 2047 : U32), 2047), U32.is_zero(((h >> 20n) .&. 2047 : U32)), ((h >> 20n) .&. 2047 : U32), h, l)

def F64.add(a: F64, b: F64) -> F64:
  match a b:
    case F64{+ah, +al} F64{+bh, +bl}:
      add.both(F64{ah, al}, F64{bh, bl}, unpack(ah, al), unpack(bh, bl))

def F64.neg(a: F64) -> F64:
  match a:
    case F64{hi, lo}:
      F64{(hi .^. 2147483648 : U32), lo}

def F64.sub(a: F64, b: F64) -> F64:
  F64.add(a, F64.neg(b))

def mul.sig(sa: U32, ea: U32, ma: W2, sb: U32, eb: U32, mb: W2) -> F64:
  match ma mb:
    case W2{ah, al} W2{bh, bl}:
      under((sa .^. sb : U32), (ea + eb - 5119 : U32), W4.shl(mul.wide(ah, al, bh, bl), 12), False{})

def mul.z(az: Bool, bz: Bool, sign: U32, sa: U32, ea: U32, ma: W2, sb: U32, eb: U32, mb: W2) -> F64:
  match az bz:
    case True{} _:
      F64.zero.sign(sign)
    case False{} True{}:
      F64.zero.sign(sign)
    case False{} False{}:
      mul.sig(sa, ea, ma, sb, eb, mb)

def Cls.inf(k: Cls) -> Bool:
  match k:
    case Inf{}:
      True{}
    case Fin{}:
      False{}
    case Nan{}:
      False{}

def Cls.fin(k: Cls) -> Bool:
  match k:
    case Fin{}:
      True{}
    case Inf{}:
      False{}
    case Nan{}:
      False{}

def Cls.nan(k: Cls) -> Bool:
  match k:
    case Nan{}:
      True{}
    case Fin{}:
      False{}
    case Inf{}:
      False{}

def mul.inf.z(z: Bool, sign: U32) -> F64:
  match z:
    case True{}:
      F64.nan()
    case False{}:
      F64.inf.sign(sign)

def mul.inf(inf: Bool, az: Bool, bz: Bool, sign: U32, sa: U32, ea: U32, ma: W2, sb: U32, eb: U32, mb: W2) -> F64:
  match inf:
    case True{}:
      mul.inf.z(Bool.or(az, bz), sign)
    case False{}:
      mul.z(az, bz, sign, sa, ea, ma, sb, eb, mb)

def mul.nan(nan: Bool, +ca: Cls, +cb: Cls, +sa: U32, ea: U32, +ma: W2, +sb: U32, eb: U32, +mb: W2) -> F64:
  match nan:
    case True{}:
      F64.nan()
    case False{}:
      mul.inf(Bool.or(Cls.inf(ca), Cls.inf(cb)), Bool.and(Cls.fin(ca), Bool.not(W2.nz(ma))), Bool.and(Cls.fin(cb), Bool.not(W2.nz(mb))), (sa .^. sb : U32), sa, ea, ma, sb, eb, mb)

def mul.parts(pa: Parts, pb: Parts) -> F64:
  match pa pb:
    case Parts{+ka, sa, ea, ma} Parts{+kb, sb, eb, mb}:
      mul.nan(Bool.or(Cls.nan(ka), Cls.nan(kb)), ka, kb, sa, ea, ma, sb, eb, mb)

def F64.mul(a: F64, b: F64) -> F64:
  match a b:
    case F64{ah, al} F64{bh, bl}:
      mul.parts(unpack(ah, al), unpack(bh, bl))

def div.norm(k: U32, mb: W2) -> W2:
  W2.shl(mb, k)

def div.sig.q(sign: U32, exp: U32, r: W4 & Bool) -> F64:
  (q, sticky) = r
  under(sign, exp, q, sticky)

def div.sig(sign: U32, ea: U32, ma: W2, eb: U32, mb: W2, +k: U32) -> F64:
  div.sig.q(sign, (ea + 5119 + k - eb : U32), div.q(ma, div.norm(k, mb)))

def div.k(sign: U32, ea: U32, ma: W2, eb: U32, +mb: W2) -> F64:
  div.sig(sign, ea, ma, eb, mb, (52 - W2.msb(mb) : U32))

def div.by0(na: Bool, sign: U32) -> F64:
  match na:
    case False{}:
      F64.nan()
    case True{}:
      F64.inf.sign(sign)

def div.num0(na: Bool, sign: U32, ea: U32, ma: W2, eb: U32, mb: W2) -> F64:
  match na:
    case False{}:
      F64.zero.sign(sign)
    case True{}:
      div.k(sign, ea, ma, eb, mb)

def div.fin.z(nb: Bool, na: Bool, sign: U32, ea: U32, ma: W2, eb: U32, mb: W2) -> F64:
  match nb:
    case False{}:
      div.by0(na, sign)
    case True{}:
      div.num0(na, sign, ea, ma, eb, mb)

def div.fin.a(ia: Bool, nb: Bool, na: Bool, sign: U32, ea: U32, ma: W2, eb: U32, mb: W2) -> F64:
  match ia:
    case True{}:
      F64.inf.sign(sign)
    case False{}:
      div.fin.z(nb, na, sign, ea, ma, eb, mb)

def div.fin.b(ib: Bool, ia: Bool, nb: Bool, na: Bool, sign: U32, ea: U32, ma: W2, eb: U32, mb: W2) -> F64:
  match ib:
    case True{}:
      F64.zero.sign(sign)
    case False{}:
      div.fin.a(ia, nb, na, sign, ea, ma, eb, mb)

def div.fin(+ca: Cls, +cb: Cls, sign: U32, ea: U32, +ma: W2, eb: U32, +mb: W2) -> F64:
  div.fin.b(Cls.inf(cb), Cls.inf(ca), W2.nz(mb), W2.nz(ma), sign, ea, ma, eb, mb)

def div.both(both: Bool, ca: Cls, cb: Cls, sign: U32, ea: U32, ma: W2, eb: U32, mb: W2) -> F64:
  match both:
    case True{}:
      F64.nan()
    case False{}:
      div.fin(ca, cb, sign, ea, ma, eb, mb)

def div.nan(nan: Bool, both: Bool, ca: Cls, cb: Cls, sign: U32, ea: U32, ma: W2, eb: U32, mb: W2) -> F64:
  match nan:
    case True{}:
      F64.nan()
    case False{}:
      div.both(both, ca, cb, sign, ea, ma, eb, mb)

def div.parts(pa: Parts, pb: Parts) -> F64:
  match pa pb:
    case Parts{+ka, +sa, ea, ma} Parts{+kb, +sb, eb, mb}:
      div.nan(Bool.or(Cls.nan(ka), Cls.nan(kb)), Bool.and(Cls.inf(ka), Cls.inf(kb)), ka, kb, (sa .^. sb : U32), ea, ma, eb, mb)

def F64.div(a: F64, b: F64) -> F64:
  match a b:
    case F64{ah, al} F64{bh, bl}:
      div.parts(unpack(ah, al), unpack(bh, bl))

def F64.nan.bits(+h: U32, l: U32) -> Bool:
  Bool.and(U32.is_eq(((h >> 20n) .&. 2047 : U32), 2047), Bool.not(Bool.and(U32.is_zero((h .&. 1048575 : U32)), U32.is_zero(l))))

def F64.zero.bits(h: U32, l: U32) -> Bool:
  Bool.and(U32.is_zero((h .&. 2147483647 : U32)), U32.is_zero(l))

def F64.is_nan(a: F64) -> Bool:
  match a:
    case F64{hi, lo}:
      F64.nan.bits(hi, lo)

def F64.is_inf(a: F64) -> Bool:
  match a:
    case F64{+hi, lo}:
      Bool.and(U32.is_eq(((hi >> 20n) .&. 2047 : U32), 2047), F64.zero.bits((hi .&. 2147483647 : U32), lo))

def F64.is_zero(a: F64) -> Bool:
  match a:
    case F64{hi, lo}:
      F64.zero.bits(hi, lo)

def F64.is_subnormal(a: F64) -> Bool:
  match a:
    case F64{+hi, lo}:
      Bool.and(U32.is_zero(((hi >> 20n) .&. 2047 : U32)), Bool.not(F64.zero.bits(hi, lo)))

def F64.eq.bits(ah: U32, al: U32, bh: U32, bl: U32) -> Bool:
  Bool.and(U32.is_eq(ah, bh), U32.is_eq(al, bl))

def F64.eq.zb(zb: Bool, ah: U32, al: U32, bh: U32, bl: U32) -> Bool:
  match zb:
    case True{}:
      False{}
    case False{}:
      F64.eq.bits(ah, al, bh, bl)

def F64.eq.zero(za: Bool, zb: Bool, ah: U32, al: U32, bh: U32, bl: U32) -> Bool:
  match za:
    case True{}:
      zb
    case False{}:
      F64.eq.zb(zb, ah, al, bh, bl)

def F64.eq.nb(nb: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> Bool:
  match nb:
    case True{}:
      False{}
    case False{}:
      F64.eq.zero(F64.zero.bits(ah, al), F64.zero.bits(bh, bl), ah, al, bh, bl)

def F64.eq.nan(na: Bool, nb: Bool, ah: U32, al: U32, bh: U32, bl: U32) -> Bool:
  match na:
    case True{}:
      False{}
    case False{}:
      F64.eq.nb(nb, ah, al, bh, bl)

def F64.is_eq(a: F64, b: F64) -> Bool:
  match a b:
    case F64{+ah, +al} F64{+bh, +bl}:
      F64.eq.nan(F64.nan.bits(ah, al), F64.nan.bits(bh, bl), ah, al, bh, bl)

def F64.lt.eq(eq: Bool, al: U32, bl: U32) -> Bool:
  match eq:
    case False{}:
      False{}
    case True{}:
      U32.is_lt(al, bl)

def F64.lt.hi(lt: Bool, eq: Bool, al: U32, bl: U32) -> Bool:
  match lt:
    case True{}:
      True{}
    case False{}:
      F64.lt.eq(eq, al, bl)

def F64.lt.mag(+ah: U32, al: U32, +bh: U32, bl: U32) -> Bool:
  F64.lt.hi(U32.is_lt(ah, bh), U32.is_eq(ah, bh), al, bl)

def F64.lt.neg(nb: Bool, ah: U32, al: U32, bh: U32, bl: U32) -> Bool:
  match nb:
    case False{}:
      True{}
    case True{}:
      F64.lt.mag(bh, bl, ah, al)

def F64.lt.pos(nb: Bool, ah: U32, al: U32, bh: U32, bl: U32) -> Bool:
  match nb:
    case True{}:
      False{}
    case False{}:
      F64.lt.mag(ah, al, bh, bl)

def F64.lt.sign(na: Bool, nb: Bool, ah: U32, al: U32, bh: U32, bl: U32) -> Bool:
  match na:
    case True{}:
      F64.lt.neg(nb, ah, al, bh, bl)
    case False{}:
      F64.lt.pos(nb, ah, al, bh, bl)

def F64.lt.zb(zb: Bool, +ah: U32, al: U32, +bh: U32, bl: U32) -> Bool:
  match zb:
    case True{}:
      False{}
    case False{}:
      F64.lt.sign(U32.is_ge(ah, 2147483648), U32.is_ge(bh, 2147483648), ah, al, bh, bl)

def F64.lt.zero(za: Bool, zb: Bool, +ah: U32, al: U32, +bh: U32, bl: U32) -> Bool:
  match za:
    case True{}:
      F64.lt.zb(zb, ah, al, bh, bl)
    case False{}:
      F64.lt.sign(U32.is_ge(ah, 2147483648), U32.is_ge(bh, 2147483648), ah, al, bh, bl)

def F64.lt.nb(nb: Bool, +ah: U32, +al: U32, +bh: U32, +bl: U32) -> Bool:
  match nb:
    case True{}:
      False{}
    case False{}:
      F64.lt.zero(F64.zero.bits(ah, al), F64.zero.bits(bh, bl), ah, al, bh, bl)

def F64.lt.nan(na: Bool, nb: Bool, ah: U32, al: U32, bh: U32, bl: U32) -> Bool:
  match na:
    case True{}:
      False{}
    case False{}:
      F64.lt.nb(nb, ah, al, bh, bl)

def F64.is_lt(a: F64, b: F64) -> Bool:
  match a b:
    case F64{+ah, +al} F64{+bh, +bl}:
      F64.lt.nan(F64.nan.bits(ah, al), F64.nan.bits(bh, bl), ah, al, bh, bl)

def F64.is_ne(a: F64, b: F64) -> Bool:
  Bool.not(F64.is_eq(a, b))

def F64.is_le(+a: F64, +b: F64) -> Bool:
  Bool.or(F64.is_lt(a, b), F64.is_eq(a, b))

def F64.is_gt(a: F64, b: F64) -> Bool:
  F64.is_lt(b, a)

def F64.is_ge(+a: F64, +b: F64) -> Bool:
  Bool.or(F64.is_lt(b, a), F64.is_eq(a, b))

def F64.abs(a: F64) -> F64:
  match a:
    case F64{hi, lo}:
      F64{(hi .&. 2147483647 : U32), lo}

def F64.from.lo(+z: U32, +n: U32, hi_sh: U32, lo_sh: U32) -> F64:
  F64.pack(0, (1054 - z : U32), (n >> U32.to_nat(hi_sh) : U32), (n << U32.to_nat(lo_sh) : U32))

def F64.from.small(small: Bool, +z: U32, +n: U32) -> F64:
  match small:
    case True{}:
      F64.from.lo(z, n, (11 - z : U32), (21 + z : U32))
    case False{}:
      F64.pack(0, (1054 - z : U32), (n << U32.to_nat((z - 11 : U32)) : U32), 0)

def F64.from.clz(+z: U32, n: U32) -> F64:
  F64.from.small(U32.is_lt(z, 11), z, n)

def F64.from.z(z: Bool, +n: U32) -> F64:
  match z:
    case True{}:
      F64{0, 0}
    case False{}:
      F64.from.clz(clz(n), n)

def F64.from_u32(+n: U32) -> F64:
  F64.from.z(U32.is_zero(n), n)

def F64.one() -> F64:
  F64{1072693248, 0}

def F64.zero() -> F64:
  F64{0, 0}

def F64.inf() -> F64:
  F64{2146435072, 0}
