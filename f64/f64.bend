# IEEE 754 binary64 arithmetic and square root. Source: https://github.com/paymog/bend-kit/tree/main/f64
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

type SqrtStep is Data:
  SqrtStep{rem: W2, root: W2}

# Restoring square root consumes 54 bit pairs: 53 significand bits and one guard bit.
def sqrt.step(ge: Bool, rem: W2, root: W2, trial: W2) -> SqrtStep:
  match ge:
    case True{}:
      SqrtStep{W2.sub(rem, trial), W2.inc(root)}
    case False{}:
      SqrtStep{rem, root}

def sqrt.trial(+rem: W2, +root: W2, +trial: W2) -> SqrtStep:
  sqrt.step(W2.ge(rem, trial), rem, root, trial)

def sqrt.advance(w: W4, rem: W2, +root: W2) -> SqrtStep:
  match w:
    case W4{a, b, c, d}:
      sqrt.trial(W2.shl1(W2.shl1(rem, 0), (a >> 30n : U32)), W2.shl1(root, 0), W2.shl1(W2.shl1(root, 0), 1))

def sqrt.finish(exp: U32, rem: W2, root: W2) -> F64:
  match root:
    case W2{+hi, +lo}:
      round.sig(0, exp, (hi >> 1n : U32), ((lo >> 1n) .|. (hi << 31n) : U32), ((lo .&. 1) << 31n : U32), 0, W2.nz(rem))

def sqrt.go(n: Nat, +w: W4, st: SqrtStep, exp: U32) -> F64:
  match n st:
    case 0n SqrtStep{rem, root}:
      sqrt.finish(exp, rem, root)
    case 1n+p SqrtStep{rem, root}:
      sqrt.go(p, W4.shl1(W4.shl1(w)), sqrt.advance(w, rem, root), exp)

def sqrt.sig(+exp: U32, sig: W2) -> F64:
  match sig:
    case W2{hi, lo}:
      sqrt.go(54n, W4.shl(W4{0, 0, hi, lo}, (74 + ((exp + 1) .&. 1) : U32)), SqrtStep{W2{0, 0}, W2{0, 0}}, ((exp + 5119) >> 1n : U32))

def sqrt.norm(exp: U32, sig: W2, +k: U32) -> F64:
  sqrt.sig((exp - k : U32), W2.shl(sig, k))

def sqrt.sign(positive: Bool, exp: U32, +sig: W2) -> F64:
  match positive:
    case False{}:
      F64.nan()
    case True{}:
      sqrt.norm(exp, sig, (52 - W2.msb(sig) : U32))

def sqrt.zero(nz: Bool, +sign: U32, exp: U32, sig: W2) -> F64:
  match nz:
    case False{}:
      F64.zero.sign(sign)
    case True{}:
      sqrt.sign(U32.is_zero(sign), exp, sig)

def sqrt.inf(positive: Bool) -> F64:
  match positive:
    case True{}:
      F64.inf.sign(0)
    case False{}:
      F64.nan()

def sqrt.parts(parts: Parts) -> F64:
  match parts:
    case Parts{Nan{}, sign, exp, sig}:
      F64.nan()
    case Parts{Inf{}, sign, exp, sig}:
      sqrt.inf(U32.is_zero(sign))
    case Parts{Fin{}, sign, exp, +sig}:
      sqrt.zero(W2.nz(sig), sign, exp, sig)

def F64.sqrt(x: F64) -> F64:
  match x:
    case F64{hi, lo}:
      sqrt.parts(unpack(hi, lo))

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

# A match cannot scrutinize a computed Bool, so each branch is a closure.
def Txt.if(-A: Type, c: Bool, t: Unit -> A, e: Unit -> A) -> A:
  match c:
    case True{}:
      t(Unit{})
    case False{}:
      e(Unit{})

# A Big is a natural number in base-2^16 limbs, least significant first, with no zero limb on top.
def Big.lone(z: Bool, x: U32) -> List<&2, U32>:
  match z:
    case True{}:
      Nil{}
    case False{}:
      Con{x, Nil{}}

def Big.cons(+x: U32, r: List<&2, U32>) -> List<&2, U32>:
  match r:
    case Nil{}:
      Big.lone(U32.is_zero(x), x)
    case s:
      Con{x, s}

def Big.norm(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      Big.cons(x, Big.norm(t))

# a * m + c for m at most 2^16 and c below 2^16.
def Big.mul1(a: List<&2, U32>, +m: U32, +c: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      Big.lone(U32.is_zero(c), c)
    case Con{x, xs}:
      +t = (x * m + c : U32)
      Con{(t .&. 65535 : U32), Big.mul1(xs, m, (t >> 16n : U32))}

def Big.inc(a: List<&2, U32>, z: Bool, +c: U32) -> List<&2, U32>:
  match a z:
    case s True{}:
      s
    case Nil{} False{}:
      Con{c, Nil{}}
    case Con{x, xs} False{}:
      +t = (x + c : U32)
      +k = (t >> 16n : U32)
      Con{(t .&. 65535 : U32), Big.inc(xs, U32.is_zero(k), k)}

def Big.add(a: List<&2, U32>, b: List<&2, U32>, +c: U32) -> List<&2, U32>:
  match a b:
    case Con{x, xs} Con{y, ys}:
      +t = (x + y + c : U32)
      Con{(t .&. 65535 : U32), Big.add(xs, ys, (t >> 16n : U32))}
    case Nil{} s:
      Big.inc(s, U32.is_zero(c), c)
    case s Nil{}:
      Big.inc(s, U32.is_zero(c), c)

def Big.dec(a: List<&2, U32>, z: Bool, +w: U32) -> List<&2, U32>:
  match a z:
    case s True{}:
      s
    case Nil{} False{}:
      Nil{}
    case Con{x, xs} False{}:
      +t = (x + 65536 - w : U32)
      +k = (1 - (t >> 16n) : U32)
      Con{(t .&. 65535 : U32), Big.dec(xs, U32.is_zero(k), k)}

# a - b - w for a >= b + w. Callers norm the result.
def Big.sub(a: List<&2, U32>, b: List<&2, U32>, +w: U32) -> List<&2, U32>:
  match a b:
    case Con{x, xs} Con{y, ys}:
      +t = (x + 65536 - y - w : U32)
      Con{(t .&. 65535 : U32), Big.sub(xs, ys, (1 - (t >> 16n) : U32))}
    case s Nil{}:
      Big.dec(s, U32.is_zero(w), w)
    case Nil{} s:
      Nil{}

def Big.then(hi: Cmp, lo: Cmp) -> Cmp:
  match hi:
    case EQ{}:
      lo
    case LT{}:
      LT{}
    case GT{}:
      GT{}

def Big.cmp(a: List<&2, U32>, b: List<&2, U32>) -> Cmp:
  match a b:
    case Con{x, xs} Con{y, ys}:
      Big.then(Big.cmp(xs, ys), U32.cmp(x, y))
    case Nil{} Nil{}:
      EQ{}
    case Nil{} Con{y, ys}:
      LT{}
    case Con{x, xs} Nil{}:
      GT{}

def Big.zeros(n: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      xs
    case 1n+p:
      Con{0, Big.zeros(p, xs)}

def Big.shl(xs: List<&2, U32>, +k: U32) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case s:
      Big.zeros(U32.to_nat((k >> 4n : U32)), Big.mul1(s, (1 << U32.to_nat((k .&. 15 : U32)) : U32), 0))

def Big.top(xs: List<&2, U32>) -> U32:
  Maybe.default(&2, U32, List.last(&2, U32, xs), 0)

# The bit length of a nonzero Big.
def Big.bits(+xs: List<&2, U32>) -> U32:
  (U32.from_nat(List.length(&2, U32, xs)) * 16 + 16 - clz(Big.top(xs)) : U32)

def Big.times(n: Nat, +m: U32, a: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      Big.times(p, m, Big.mul1(a, m, 0))

def Big.any(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{x, t}:
      Bool.or(Bool.not(U32.is_zero(x)), Big.any(t))

# The low 128 bits as a W4.
def Big.w4(xs: List<&2, U32>) -> W4:
  match xs:
    case Nil{}:
      W4{0, 0, 0, 0}
    case Con{x, t}:
      W4.add(W4.shl(Big.w4(t), 16), W4{0, 0, 0, x})

# (q + t / s, t % s) for t < 10 s, by repeated subtraction.
def Big.digit(f: Nat, ge: Bool, +q: U32, +t: List<&2, U32>, +s: List<&2, U32>) -> U32 & List<&2, U32>:
  match f:
    case 0n:
      (q, t)
    case 1n+g:
      match ge:
        case False{}:
          (q, t)
        case True{}:
          +t2 = Big.norm(Big.sub(t, s, 0))
          Big.digit(g, Cmp.is_ge(Big.cmp(t2, s)), (q + 1 : U32), t2, s)

# Decimal text: d is the digits as one integer, nd counts digits from the first nonzero one,
# frac counts digits after the point, and seen counts all digits.
type Dec is Data:
  Dec{d: List<&2, U32>, nd: U32, frac: U32, seen: U32}

type Ex is Data:
  Ex{rest: String, n: U32, any: Bool}

def Rd.is_digit(+c: U32) -> Bool:
  Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57))

def Dec.push(infrac: Bool, +v: U32, acc: Dec) -> Dec:
  match acc:
    case Dec{d, +nd, frac, seen}:
      Dec{Big.mul1(d, 10, v), (nd + u01(Bool.not(Bool.and(U32.is_zero(nd), U32.is_zero(v)))) : U32), (frac + u01(infrac) : U32), (seen + 1 : U32)}

def Rd.digits(s: String, +infrac: Bool, +acc: Dec) -> String & Dec:
  match s:
    case SNil{}:
      (SNil{}, acc)
    case SCon{Chr{+c}, +t}:
      Txt.if(String & Dec, Rd.is_digit(c),
        u => Rd.digits(t, infrac, Dec.push(infrac, (c - 48 : U32), acc)),
        u => (SCon{Chr{c}, t}, acc))

# The exponent saturates at 999999, far past any finite double.
def Rd.expo(s: String, +n: U32, +any: Bool) -> Ex:
  match s:
    case SNil{}:
      Ex{SNil{}, n, any}
    case SCon{Chr{+c}, +t}:
      Txt.if(Ex, Rd.is_digit(c),
        u => Rd.expo(t, U32.min((n * 10 + c - 48 : U32), 999999), True{}),
        u => Ex{SCon{Chr{c}, t}, n, any})

def Rd.lower(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{Chr{c}, t}:
      SCon{Chr{(c .|. 32 : U32)}, Rd.lower(t)}

def Rd.empty(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{c, t}:
      False{}

# value = d * 2^e for a nonzero d; only the top 8 limbs reach the rounding.
def Rd.pos.cut(sign: U32, +n: List<&2, U32>, +e: U32, +dr: U32) -> F64:
  under(sign, (e + dr * 16 + 5235 : U32), Big.w4(List.drop(&2, U32, n, U32.to_nat(dr))), Big.any(List.take(&2, U32, n, U32.to_nat(dr))))

def Rd.pos(sign: U32, +n: List<&2, U32>, e: U32) -> F64:
  +len = U32.from_nat(List.length(&2, U32, n))
  Rd.pos.cut(sign, n, e, (len - U32.min(len, 8) : U32))

# Restoring division with u = r * 2^i against vv = v * 2^67: 68 quotient bits, then the sticky remainder.
def Div.go(f: Nat, +vv: List<&2, U32>, +u: List<&2, U32>, +q: W4) -> W4 & Bool:
  match f:
    case 0n:
      (q, Big.any(u))
    case 1n+p:
      +g = p
      Txt.if(W4 & Bool, Cmp.is_ge(Big.cmp(u, vv)),
        e => Div.go(g, vv, Big.mul1(Big.norm(Big.sub(u, vv, 0)), 2, 0), W4.set0(W4.shl1(q))),
        e => Div.go(g, vv, Big.mul1(u, 2, 0), W4.shl1(q)))

def Rd.div.q(sign: U32, x: U32, r: W4 & Bool) -> F64:
  (q, sticky) = r
  under(sign, x, q, sticky)

def Rd.div(sign: U32, x: U32, num: List<&2, U32>, den: List<&2, U32>) -> F64:
  Rd.div.q(sign, x, Div.go(68n, Big.shl(den, 67), num, W4{0, 0, 0, 0}))

# value = d / s * 2^-m with s = 5^m. Shift one side so num has 66 more bits than den;
# the quotient then has 65 to 67 bits.
def Rd.neg.go(+sign: U32, +d: List<&2, U32>, +s: List<&2, U32>, +m: U32, +bd: U32, +bs: U32) -> F64:
  Txt.if(F64, U32.is_ge((bs + 66 : U32), bd),
    u => Rd.div(sign, (5169 + bd - m - bs : U32), Big.shl(d, (bs + 66 - bd : U32)), s),
    u => Rd.div(sign, (5169 + bd - m - bs : U32), d, Big.shl(s, (bd - bs - 66 : U32))))

def Rd.neg.s(sign: U32, +d: List<&2, U32>, +s: List<&2, U32>, m: U32) -> F64:
  Rd.neg.go(sign, d, s, m, Big.bits(d), Big.bits(s))

def Rd.neg(sign: U32, d: List<&2, U32>, +m: U32) -> F64:
  Rd.neg.s(sign, d, Big.times(U32.to_nat(m), 5, Con{1, Nil{}}), m)

# eb is the decimal exponent plus 2^30. A value under 10^-324 reads as zero, and one at or over 10^310 as infinity.
def Rd.value(+sign: U32, +d: List<&2, U32>, nd: U32, +eb: U32) -> F64:
  +t = (nd + eb : U32)
  Txt.if(F64, Bool.not(Big.any(d)), u => F64.zero.sign(sign),
    u => Txt.if(F64, U32.is_lt(t, 1073741500), u => F64.zero.sign(sign),
      u => Txt.if(F64, U32.is_gt(t, 1073742134), u => F64.inf.sign(sign),
        u => Txt.if(F64, U32.is_ge(eb, 1073741824),
          u => Rd.pos(sign, Big.times(U32.to_nat((eb - 1073741824 : U32)), 5, d), (eb - 1073741824 : U32)),
          u => Rd.neg(sign, d, (1073741824 - eb : U32))))))

def Rd.done.eb(neg: Bool, +n: U32, +frac: U32) -> U32:
  match neg:
    case True{}:
      (1073741824 - n - frac : U32)
    case False{}:
      (1073741824 + n - frac : U32)

def Rd.done(sign: U32, a: Dec, neg: Bool, n: U32) -> Maybe<&2, F64>:
  match a:
    case Dec{d, nd, frac, +seen}:
      Txt.if(Maybe<&2, F64>, U32.is_zero(seen), u => None{},
        u => Some{Rd.value(sign, d, nd, Rd.done.eb(neg, n, frac))})

def Rd.eend(sign: U32, a: Dec, neg: Bool, ex: Ex) -> Maybe<&2, F64>:
  match ex:
    case Ex{rest, n, any}:
      Txt.if(Maybe<&2, F64>, Bool.and(any, Rd.empty(rest)), u => Rd.done(sign, a, neg, n), u => None{})

def Rd.esign(+sign: U32, +a: Dec, s: String) -> Maybe<&2, F64>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, +t}:
      Txt.if(Maybe<&2, F64>, U32.is_eq(c, 45), u => Rd.eend(sign, a, True{}, Rd.expo(t, 0, False{})),
        u => Txt.if(Maybe<&2, F64>, U32.is_eq(c, 43), u => Rd.eend(sign, a, False{}, Rd.expo(t, 0, False{})),
          u => Rd.eend(sign, a, False{}, Rd.expo(SCon{Chr{c}, t}, 0, False{}))))

def Rd.exp(sign: U32, r: String, a: Dec) -> Maybe<&2, F64>:
  match r:
    case SNil{}:
      Rd.done(sign, a, False{}, 0)
    case SCon{Chr{c}, t}:
      Txt.if(Maybe<&2, F64>, U32.is_eq((c .|. 32 : U32), 101), u => Rd.esign(sign, a, t), u => None{})

def Rd.frac(sign: U32, p: String & Dec) -> Maybe<&2, F64>:
  (r, a) = p
  Rd.exp(sign, r, a)

def Rd.dot(+sign: U32, p: String & Dec) -> Maybe<&2, F64>:
  (r, +a) = p
  match r:
    case SNil{}:
      Rd.done(sign, a, False{}, 0)
    case SCon{Chr{+c}, +t}:
      Txt.if(Maybe<&2, F64>, U32.is_eq(c, 46), u => Rd.frac(sign, Rd.digits(t, True{}, a)),
        u => Rd.exp(sign, SCon{Chr{c}, t}, a))

def Rd.body(+sign: U32, +s: String) -> Maybe<&2, F64>:
  +w = Rd.lower(s)
  Txt.if(Maybe<&2, F64>, Bool.or(String.eq(w, "inf"), String.eq(w, "infinity")), u => Some{F64.inf.sign(sign)},
    u => Txt.if(Maybe<&2, F64>, String.eq(w, "nan"), u => Some{F64.nan()},
      u => Rd.dot(sign, Rd.digits(s, False{}, Dec{Nil{}, 0, 0, 0}))))

# Decimal text to the nearest double, ties to even: [+-]digits[.digits][(e|E)[+-]digits],
# with digits on at least one side of the point, or inf, infinity, or nan in any case.
def F64.read(s: String) -> Maybe<&2, F64>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{+c}, +t}:
      Txt.if(Maybe<&2, F64>, U32.is_eq(c, 45), u => Rd.body(1, t),
        u => Txt.if(Maybe<&2, F64>, U32.is_eq(c, 43), u => Rd.body(0, t), u => Rd.body(0, SCon{Chr{c}, t})))

# Burger and Dybvig's free-format digits: v = r / s, and the neighbours of v sit at (r - mm) / s and (r + mp) / s.
type St is Data:
  St{r: List<&2, U32>, s: List<&2, U32>, mp: List<&2, U32>, mm: List<&2, U32>}

type Dig is Data:
  More{d: U32, st: St}
  Last{d: U32}

# An even mantissa reads back from either bound, so the bounds count.
def Sh.high(even: Bool, r: List<&2, U32>, mp: List<&2, U32>, s: List<&2, U32>) -> Bool:
  match even:
    case True{}:
      Cmp.is_ge(Big.cmp(Big.add(r, mp, 0), s))
    case False{}:
      Cmp.is_gt(Big.cmp(Big.add(r, mp, 0), s))

def Sh.low(even: Bool, r: List<&2, U32>, mm: List<&2, U32>) -> Bool:
  match even:
    case True{}:
      Cmp.is_le(Big.cmp(r, mm))
    case False{}:
      Cmp.is_lt(Big.cmp(r, mm))

# A tie rounds to the even digit.
def Sh.near(c: Cmp, +d: U32) -> U32:
  match c:
    case LT{}:
      d
    case GT{}:
      (d + 1 : U32)
    case EQ{}:
      (d + (d .&. 1) : U32)

def Sh.pick(tc1: Bool, tc2: Bool, +d: U32, +r: List<&2, U32>, +s: List<&2, U32>, mp: List<&2, U32>, mm: List<&2, U32>) -> Dig:
  match tc1:
    case False{}:
      match tc2:
        case False{}:
          More{d, St{r, s, mp, mm}}
        case True{}:
          Last{(d + 1 : U32)}
    case True{}:
      match tc2:
        case False{}:
          Last{d}
        case True{}:
          Last{Sh.near(Big.cmp(Big.mul1(r, 2, 0), s), d)}

def Sh.digit.fin(+even: Bool, qr: U32 & List<&2, U32>, +s: List<&2, U32>, +mp: List<&2, U32>, +mm: List<&2, U32>) -> Dig:
  (d, r) = qr
  +r1 = {r : List<&2, U32>}
  Sh.pick(Sh.low(even, r1, mm), Sh.high(even, r1, mp, s), d, r1, s, mp, mm)

def Sh.digit(+even: Bool, st: St) -> Dig:
  match st:
    case St{r, +s, mp, mm}:
      +r10 = Big.mul1(r, 10, 0)
      Sh.digit.fin(even, Big.digit(10n, Cmp.is_ge(Big.cmp(r10, s)), 0, r10, s), s, Big.mul1(mp, 10, 0), Big.mul1(mm, 10, 0))

def Sh.gen(f: Nat, +even: Bool, o: Dig) -> List<&2, U32>:
  match f:
    case 0n:
      Nil{}
    case 1n+g:
      match o:
        case Last{d}:
          Con{d, Nil{}}
        case More{d, st}:
          Con{d, Sh.gen(g, even, Sh.digit(even, st))}

# k is the decimal exponent plus 400: v = 0.d1d2... * 10^(k - 400).
def Sh.up(f: Nat, +even: Bool, big: Bool, st: St, +k: U32) -> St & U32:
  match f:
    case 0n:
      (st, k)
    case 1n+g:
      match big:
        case False{}:
          (st, k)
        case True{}:
          match st:
            case St{+r, s, +mp, mm}:
              +s10 = Big.mul1(s, 10, 0)
              Sh.up(g, even, Sh.high(even, r, mp, s10), St{r, s10, mp, mm}, (k + 1 : U32))

def Sh.down(f: Nat, +even: Bool, small: Bool, st: St, +k: U32) -> St & U32:
  match f:
    case 0n:
      (st, k)
    case 1n+g:
      match small:
        case False{}:
          (st, k)
        case True{}:
          match st:
            case St{r, +s, mp, mm}:
              +r10 = Big.mul1(r, 10, 0)
              +mp10 = Big.mul1(mp, 10, 0)
              Sh.down(g, even, Bool.not(Sh.high(even, Big.mul1(r10, 10, 0), Big.mul1(mp10, 10, 0), s)), St{r10, s, mp10, Big.mul1(mm, 10, 0)}, (k - 1 : U32))

def Sh.fix.down(+even: Bool, sk: St & U32) -> St & U32:
  (st, k) = sk
  match st:
    case St{+r, +s, +mp, mm}:
      Sh.down(4n, even, Bool.not(Sh.high(even, Big.mul1(r, 10, 0), Big.mul1(mp, 10, 0), s)), St{r, s, mp, mm}, k)

# k starts from an estimate of floor(log10 v) + 1 that is at most 2 off.
def Sh.fix(+even: Bool, st: St, +k: U32) -> St & U32:
  match st:
    case St{+r, +s, +mp, mm}:
      Sh.fix.down(even, Sh.up(4n, even, Sh.high(even, r, mp, s), St{r, s, mp, mm}, k))

def Sh.scale(pos: Bool, +n: Nat, st: St) -> St:
  match pos st:
    case True{} St{r, s, mp, mm}:
      St{r, Big.times(n, 10, s), mp, mm}
    case False{} St{r, s, mp, mm}:
      St{Big.times(n, 10, r), s, Big.times(n, 10, mp), Big.times(n, 10, mm)}

def Sh.chars(ds: List<&2, U32>) -> String:
  match ds:
    case Nil{}:
      SNil{}
    case Con{d, t}:
      SCon{Chr{(48 + d : U32)}, Sh.chars(t)}

def Sh.fill(n: Nat) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{'0', Sh.fill(p)}

def Sh.exp.if(small: Bool, +e: U32) -> String:
  match small:
    case True{}:
      SCon{'0', U32.show(e)}
    case False{}:
      U32.show(e)

def Sh.exp(neg: Bool, +e: U32) -> String:
  match neg:
    case True{}:
      SCon{'-', Sh.exp.if(U32.is_lt(e, 10), e)}
    case False{}:
      SCon{'+', Sh.exp.if(U32.is_lt(e, 10), e)}

def Sh.frac(ds: String) -> String:
  match ds:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{'.', SCon{h, t}}

def Sh.sci(ds: String, +k: U32) -> String:
  match ds:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{h, Sh.frac(t) ++ "e" ++ Sh.exp(U32.is_lt(k, 401), (U32.max(k, 401) - U32.min(k, 401) : U32))}

def Sh.fixed.big(ge: Bool, +ds: String, +kn: Nat) -> String:
  match ge:
    case True{}:
      ds ++ Sh.fill(Nat.sub(kn, String.length(ds))) ++ ".0"
    case False{}:
      String.take(ds, kn) ++ "." ++ String.drop(ds, kn)

def Sh.fixed(pos: Bool, +ds: String, +k: U32) -> String:
  match pos:
    case True{}:
      +kn = U32.to_nat((k - 400 : U32))
      Sh.fixed.big(Nat.is_ge(kn, String.length(ds)), ds, kn)
    case False{}:
      "0." ++ Sh.fill(U32.to_nat((400 - k : U32))) ++ ds

def Sh.show.if(sci: Bool, +ds: String, +k: U32) -> String:
  match sci:
    case True{}:
      Sh.sci(ds, k)
    case False{}:
      Sh.fixed(U32.is_gt(k, 400), ds, k)

# Like Python's repr: plain from 1e-4 up to 1e16, scientific outside.
def Sh.fin(+even: Bool, sk: St & U32) -> String:
  (st, +k) = sk
  Sh.show.if(Bool.or(U32.is_lt(k, 397), U32.is_ge(k, 417)), Sh.chars(Sh.gen(17n, even, Sh.digit(even, st))), k)

# v = f * 2^(be - 1075). A power-of-two f above the least exponent has a nearer lower neighbour, so t = 1 there.
def Sh.finite.go(+f: List<&2, U32>, +be: U32, +t: U32, +even: Bool) -> String:
  +a = (be - U32.min(be, 1075) : U32)
  +b = (1075 - U32.min(be, 1075) : U32)
  +k = (((((be + Big.bits(f) + 24) * 78913) >> 18n) + 70) : U32)
  +one = {Con{1, Nil{}} : List<&2, U32>}
  Sh.fin(even, Sh.fix(even, Sh.scale(U32.is_ge(k, 400), U32.to_nat((U32.max(k, 400) - U32.min(k, 400) : U32)),
    St{Big.shl(f, (a + 1 + t : U32)), Big.shl(one, (b + 1 + t : U32)), Big.shl(one, (a + t : U32)), Big.shl(one, a)}), k))

def Sh.finite(+ex: U32, +mh: U32, +lo: U32) -> String:
  +fh = (mh .|. (U32.min(ex, 1) << 20n) : U32)
  Sh.finite.go(Big.norm(Con{(lo .&. 65535 : U32), Con{(lo >> 16n : U32), Con{(fh .&. 65535 : U32), Con{(fh >> 16n : U32), Nil{}}}}}),
    U32.max(ex, 1), u01(Bool.and(Bool.and(U32.is_zero(mh), U32.is_zero(lo)), U32.is_gt(ex, 1))), U32.is_zero((lo .&. 1 : U32)))

def Sh.sign(neg: Bool, s: String) -> String:
  match neg:
    case True{}:
      SCon{'-', s}
    case False{}:
      s

def Sh.go(naninf: Bool, zero: Bool, +neg: Bool, +ex: U32, +mh: U32, +lo: U32) -> String:
  match naninf:
    case True{}:
      Txt.if(String, Bool.and(U32.is_zero(mh), U32.is_zero(lo)), u => Sh.sign(neg, "inf"), u => "nan")
    case False{}:
      match zero:
        case True{}:
          Sh.sign(neg, "0.0")
        case False{}:
          Sh.sign(neg, Sh.finite(ex, mh, lo))

# The shortest decimal that reads back to x, like Python's repr: "1.0", "0.1", "1e+16", "5e-324", "inf", "nan".
def F64.show(x: F64) -> String:
  match x:
    case F64{+hi, +lo}:
      +ex = ((hi >> 20n) .&. 2047 : U32)
      +mh = (hi .&. 1048575 : U32)
      Sh.go(U32.is_eq(ex, 2047), Bool.and(U32.is_zero(ex), Bool.and(U32.is_zero(mh), U32.is_zero(lo))), U32.is_ge(hi, 2147483648), ex, mh, lo)
