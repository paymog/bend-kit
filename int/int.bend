# Fixed-width integers U8, U16, U64, I32 and I64: wrapping, checked and saturating arithmetic.
import Base

# The Int.* core serves only U64 and I64. When Base ships a native U64 (bendlang/bend#1027), delete it.
def Int.bits.go(n: Nat, qr: Nat & Nat) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+p:
      (q, r) = qr
      WCon{Nat.is_eq(r, 1n), Int.bits.go(p, Nat.divmod(q, 2n))}

# The low n bits of k: k mod 2^n.
def Int.bits(n: Nat, k: Nat) -> Word(n):
  Int.bits.go(n, Nat.divmod(k, 2n))

def Int.msb.go(n: Nat, b: Bool, w: Word(n)) -> Bool:
  match n:
    case 0n:
      b
    case 1n+p:
      match w:
        case WCon{h, t}:
          Int.msb.go(p, h, t)

def Int.msb(n: Nat, w: Word(n)) -> Bool:
  Int.msb.go(n, False{}, w)

def Int.put_msb.bit(p: Nat, v: Bool, b: Bool) -> Bool:
  match p:
    case 0n:
      v
    case 1n+q:
      b

def Int.put_msb(+n: Nat, +v: Bool, w: Word(n)) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+p:
      match w:
        case WCon{b, t}:
          WCon{Int.put_msb.bit(p, v, b), Int.put_msb(p, v, t)}

def Int.ext(m: Nat, n: Nat, +fill: Bool, w: Word(n)) -> Word(m):
  match m:
    case 0n:
      WNil{}
    case 1n+p:
      match n:
        case 0n:
          WCon{fill, Int.ext(p, 0n, fill, WNil{})}
        case 1n+q:
          match w:
            case WCon{b, t}:
              WCon{b, Int.ext(p, q, fill, t)}

def Int.ones(+n: Nat) -> Word(n):
  Word.not(n, Word.zero(n))

def Int.min(+n: Nat, s: Bool) -> Word(n):
  match s:
    case True{}:
      Int.put_msb(n, True{}, Word.zero(n))
    case False{}:
      Word.zero(n)

def Int.max(+n: Nat, s: Bool) -> Word(n):
  match s:
    case True{}:
      Int.put_msb(n, False{}, Int.ones(n))
    case False{}:
      Int.ones(n)

def Int.is_eq(+n: Nat, a: Word(n), b: Word(n)) -> Bool:
  Cmp.is_eq(Word.cmp(n, a, b))

def Int.is_zero(+n: Nat, w: Word(n)) -> Bool:
  Int.is_eq(n, w, Word.zero(n))

def Int.cmp(+n: Nat, s: Bool, a: Word(n), b: Word(n)) -> Cmp:
  match s:
    case True{}:
      Word.cmp(n, Word.xor(n, a, Int.min(n, True{})),
        Word.xor(n, b, Int.min(n, True{})))
    case False{}:
      Word.cmp(n, a, b)

def Int.neg(+n: Nat, w: Word(n)) -> Word(n):
  Word.sub(n, Word.zero(n), w)

def Int.neg_if(+n: Nat, c: Bool, w: Word(n)) -> Word(n):
  match c:
    case True{}:
      Int.neg(n, w)
    case False{}:
      w

def Int.abs(+n: Nat, +w: Word(n)) -> Word(n):
  Int.neg_if(n, Int.msb(n, w), w)

def Int.udivmod.fin(-p: Nat, q: Word(p), +n: Nat, s: Word(n), b: Word(n),
  g: Bool) -> Word(1n+p) & Word(n):
  match g:
    case True{}:
      (WCon{True{}, q}, Word.sub(n, s, b))
    case False{}:
      (WCon{False{}, q}, s)

def Int.udivmod.shl(-p: Nat, q: Word(p), +n: Nat, +b: Word(n),
  ts: Bool & Word(n)) -> Word(1n+p) & Word(n):
  (t, s) = ts
  +s2 = {s : Word(n)}
  Int.udivmod.fin(p, q, n, s2, b, Bool.or(t, Cmp.is_ge(Word.cmp(n, s2, b))))

def Int.udivmod.rec(-p: Nat, a0: Bool, +n: Nat, +b: Word(n),
  qr: Word(p) & Word(n)) -> Word(1n+p) & Word(n):
  (q, r) = qr
  Int.udivmod.shl(p, q, n, b, Word.shl.out(n, a0, r))

def Int.udivmod.go(m: Nat, a: Word(m), +n: Nat, +b: Word(n)) ->
  Word(m) & Word(n):
  match m a:
    case 0n WNil{}:
      (WNil{}, Word.zero(n))
    case 1n+p WCon{a0, hi}:
      Int.udivmod.rec(p, a0, n, b, Int.udivmod.go(p, hi, n, b))

def Int.sdivmod.fix(+n: Nat, +na: Bool, nb: Bool, qr: Word(n) & Word(n)) ->
  Word(n) & Word(n):
  (q, r) = qr
  (Int.neg_if(n, Bool.xor(na, nb), q), Int.neg_if(n, na, r))

# x / 0 is 0 and x % 0 is x, as in Base's U32. MIN / -1 wraps to MIN.
def Int.divmod.if(z: Bool, s: Bool, +n: Nat, +a: Word(n), +b: Word(n)) ->
  Word(n) & Word(n):
  match z:
    case True{}:
      (Word.zero(n), a)
    case False{}:
      match s:
        case True{}:
          Int.sdivmod.fix(n, Int.msb(n, a), Int.msb(n, b),
            Int.udivmod.go(n, Int.abs(n, a), n, Int.abs(n, b)))
        case False{}:
          Int.udivmod.go(n, a, n, b)

def Int.divmod(+n: Nat, s: Bool, a: Word(n), +b: Word(n)) ->
  Word(n) & Word(n):
  Int.divmod.if(Int.is_zero(n, b), s, n, a, b)

def Int.fst(-n: Nat, p: Word(n) & Word(n)) -> Word(n):
  (q, r) = p
  q

def Int.snd(-n: Nat, p: Word(n) & Word(n)) -> Word(n):
  (q, r) = p
  r

def Int.div(+n: Nat, s: Bool, a: Word(n), b: Word(n)) -> Word(n):
  Int.fst(n, Int.divmod(n, s, a, b))

def Int.mod(+n: Nat, s: Bool, a: Word(n), b: Word(n)) -> Word(n):
  Int.snd(n, Int.divmod(n, s, a, b))

# True for signed MIN and -1, the one quotient that overflows.
def Int.min_neg1(+n: Nat, s: Bool, a: Word(n), b: Word(n)) -> Bool:
  match s:
    case True{}:
      Bool.and(Int.is_eq(n, a, Int.min(n, True{})),
        Int.is_eq(n, b, Int.ones(n)))
    case False{}:
      False{}

def Int.div_ov(+n: Nat, s: Bool, a: Word(n), +b: Word(n)) -> Bool:
  Bool.or(Int.is_zero(n, b), Int.min_neg1(n, s, a, b))

def Int.add_ov.go(+n: Nat, s: Bool, a: Word(n), b: Word(n), +r: Word(n)) ->
  Bool & Word(n):
  match s:
    case True{}:
      (Int.msb(n, Word.and(n, Word.xor(n, a, r), Word.xor(n, b, r))), r)
    case False{}:
      (Cmp.is_lt(Word.cmp(n, r, a)), r)

def Int.add_ov(+n: Nat, s: Bool, +a: Word(n), +b: Word(n)) -> Bool & Word(n):
  Int.add_ov.go(n, s, a, b, Word.add(n, a, b))

def Int.sub_ov.go(+n: Nat, s: Bool, +a: Word(n), b: Word(n), +r: Word(n)) ->
  Bool & Word(n):
  match s:
    case True{}:
      (Int.msb(n, Word.and(n, Word.xor(n, a, b), Word.xor(n, a, r))), r)
    case False{}:
      (Cmp.is_lt(Word.cmp(n, a, b)), r)

def Int.sub_ov(+n: Nat, s: Bool, +a: Word(n), +b: Word(n)) -> Bool & Word(n):
  Int.sub_ov.go(n, s, a, b, Word.sub(n, a, b))

def Int.mul_ov.go(+n: Nat, +s: Bool, +a: Word(n), +b: Word(n), +r: Word(n)) ->
  Bool & Word(n):
  (Bool.or(Bool.and(Bool.not(Int.is_zero(n, b)),
    Bool.not(Int.is_eq(n, Int.div(n, s, r, b), a))),
    Int.min_neg1(n, s, a, b)), r)

def Int.mul_ov(+n: Nat, s: Bool, +a: Word(n), +b: Word(n)) -> Bool & Word(n):
  Int.mul_ov.go(n, s, a, b, Word.mul(n, a, b))

def Int.checked(-n: Nat, o: Bool & Word(n)) -> Maybe<&2, Word(n)>:
  (ov, r) = o
  match ov:
    case True{}:
      None{}
    case False{}:
      Some{r}

def Int.checked_div(+n: Nat, +s: Bool, +a: Word(n), +b: Word(n)) ->
  Maybe<&2, Word(n)>:
  Int.checked(n, (Int.div_ov(n, s, a, b), Int.div(n, s, a, b)))

def Int.checked_mod(+n: Nat, +s: Bool, +a: Word(n), +b: Word(n)) ->
  Maybe<&2, Word(n)>:
  Int.checked(n, (Int.div_ov(n, s, a, b), Int.mod(n, s, a, b)))

def Int.sat(low: Bool, +n: Nat, s: Bool) -> Word(n):
  match low:
    case True{}:
      Int.min(n, s)
    case False{}:
      Int.max(n, s)

def Int.saturate(+n: Nat, s: Bool, low: Bool, o: Bool & Word(n)) -> Word(n):
  (ov, r) = o
  match ov:
    case True{}:
      Int.sat(low, n, s)
    case False{}:
      r

def Int.saturating_add(+n: Nat, +s: Bool, +a: Word(n), b: Word(n)) -> Word(n):
  Int.saturate(n, s, Bool.and(s, Int.msb(n, a)), Int.add_ov(n, s, a, b))

def Int.saturating_sub(+n: Nat, +s: Bool, +a: Word(n), b: Word(n)) -> Word(n):
  Int.saturate(n, s, Bool.or(Bool.not(s), Int.msb(n, a)),
    Int.sub_ov(n, s, a, b))

def Int.saturating_mul(+n: Nat, +s: Bool, +a: Word(n), +b: Word(n)) ->
  Word(n):
  Int.saturate(n, s, Bool.and(s, Bool.xor(Int.msb(n, a), Int.msb(n, b))),
    Int.mul_ov(n, s, a, b))

def Int.shl(+n: Nat, k: Nat, w: Word(n)) -> Word(n):
  match k:
    case 0n:
      w
    case 1n+j:
      Int.shl(n, j, Word.shl(n, w))

# Signed shifts right are arithmetic: the sign bit fills in from the top.
def Int.shr1(+n: Nat, s: Bool, +w: Word(n)) -> Word(n):
  match s:
    case True{}:
      Int.put_msb(n, Int.msb(n, w), Word.shr(n, w))
    case False{}:
      Word.shr(n, w)

def Int.shr(+n: Nat, +s: Bool, k: Nat, w: Word(n)) -> Word(n):
  match k:
    case 0n:
      w
    case 1n+j:
      Int.shr(n, s, j, Int.shr1(n, s, w))

# z is set once the value left to print is zero; fuel n bounds the digits.
def Int.show.go(f: Nat, +n: Nat, acc: String, z: Bool,
  qr: Word(n) & Word(n)) -> String:
  match f:
    case 0n:
      acc
    case 1n+g:
      match z:
        case True{}:
          acc
        case False{}:
          (q, r) = qr
          +q2 = {q : Word(n)}
          Int.show.go(g, n,
            SCon{Chr{U32.add(48, U32.from_nat(Word.to_nat(n, r)))}, acc},
            Int.is_zero(n, q2), Int.udivmod.go(n, q2, n, Int.bits(n, 10n)))

def Int.show.u(+n: Nat, w: Word(n)) -> String:
  Int.show.go(n, n, SNil{}, False{}, Int.udivmod.go(n, w, n, Int.bits(n, 10n)))

def Int.show.if(neg: Bool, +n: Nat, w: Word(n)) -> String:
  match neg:
    case True{}:
      SCon{Chr{45}, Int.show.u(n, Int.neg(n, w))}
    case False{}:
      Int.show.u(n, w)

def Int.show(+n: Nat, s: Bool, +w: Word(n)) -> String:
  match s:
    case True{}:
      Int.show.if(Int.msb(n, w), n, w)
    case False{}:
      Int.show.u(n, w)

def Int.read.add(+n: Nat, d: Word(n), o: Bool & Word(n)) -> Maybe<&2, Word(n)>:
  (ov, m) = o
  match ov:
    case True{}:
      None{}
    case False{}:
      Int.checked(n, Int.add_ov(n, False{}, m, d))

def Int.read.dig(ok: Bool, +n: Nat, acc: Word(n), x: U32) ->
  Maybe<&2, Word(n)>:
  match ok:
    case True{}:
      Int.read.add(n, Int.bits(n, U32.to_nat(U32.sub(x, 48))),
        Int.mul_ov(n, False{}, acc, Int.bits(n, 10n)))
    case False{}:
      None{}

def Int.read.step(+n: Nat, st: Maybe<&2, Word(n)>, x: U32) ->
  Maybe<&2, Word(n)>:
  match st:
    case None{}:
      None{}
    case Some{acc}:
      +c = {x : U32}
      Int.read.dig(Bool.and(U32.is_ge(c, 48), U32.is_le(c, 57)), n, acc, c)

def Int.read.go(s: String, +n: Nat, st: Maybe<&2, Word(n)>) ->
  Maybe<&2, Word(n)>:
  match s:
    case SNil{}:
      st
    case SCon{Chr{x}, t}:
      Int.read.go(t, n, Int.read.step(n, st, x))

def Int.read.u(+n: Nat, s: String) -> Maybe<&2, Word(n)>:
  match s:
    case SNil{}:
      None{}
    case SCon{h, t}:
      Int.read.go(SCon{h, t}, n, Some{Word.zero(n)})

def Int.read.fit(bad: Bool, -n: Nat, w: Word(n)) -> Maybe<&2, Word(n)>:
  match bad:
    case True{}:
      None{}
    case False{}:
      Some{w}

def Int.read.pos(+n: Nat, m: Maybe<&2, Word(n)>) -> Maybe<&2, Word(n)>:
  match m:
    case None{}:
      None{}
    case Some{w}:
      +v = {w : Word(n)}
      Int.read.fit(Int.msb(n, v), n, v)

def Int.read.neg(+n: Nat, m: Maybe<&2, Word(n)>) -> Maybe<&2, Word(n)>:
  match m:
    case None{}:
      None{}
    case Some{w}:
      +v = {w : Word(n)}
      Int.read.fit(Cmp.is_gt(Word.cmp(n, v, Int.min(n, True{}))), n,
        Int.neg(n, v))

def Int.read.sign(neg: Bool, +n: Nat, t: String, c: U32) -> Maybe<&2, Word(n)>:
  match neg:
    case True{}:
      Int.read.neg(n, Int.read.u(n, t))
    case False{}:
      Int.read.pos(n, Int.read.u(n, SCon{Chr{c}, t}))

def Int.read(+n: Nat, s: Bool, str: String) -> Maybe<&2, Word(n)>:
  match s:
    case False{}:
      Int.read.u(n, str)
    case True{}:
      match str:
        case SNil{}:
          None{}
        case SCon{Chr{x}, t}:
          +c = {x : U32}
          Int.read.sign(U32.is_eq(c, 45), n, t, c)

def Int.to_nat.s(neg: Bool, n: Nat, w: Word(n)) -> Maybe<&2, Nat>:
  match neg:
    case True{}:
      None{}
    case False{}:
      Some{Word.to_nat(n, w)}

# Signed values below zero have no Nat.
def Int.to_nat(+n: Nat, +w: Word(n)) -> Maybe<&2, Nat>:
  Int.to_nat.s(Int.msb(n, w), n, w)

def Int.sext(m: Nat, +n: Nat, +w: Word(n)) -> Word(m):
  Int.ext(m, n, Int.msb(n, w), w)

# U8 and U16 hold their value in a U32 below 2^w, and m is 2^w - 1.
def Nar.opt(ov: Bool, r: U32) -> Maybe<&2, U32>:
  match ov:
    case True{}:
      None{}
    case False{}:
      Some{r}

def Nar.over(+m: U32, +r: U32) -> Maybe<&2, U32>:
  Nar.opt(U32.is_gt(r, m), r)

def Nar.checked_sub(+a: U32, +b: U32) -> Maybe<&2, U32>:
  Nar.opt(U32.is_lt(a, b), U32.sub(a, b))

def Nar.checked_div(a: U32, +b: U32) -> Maybe<&2, U32>:
  Nar.opt(U32.is_zero(b), U32.div(a, b))

def Nar.checked_mod(a: U32, +b: U32) -> Maybe<&2, U32>:
  Nar.opt(U32.is_zero(b), U32.mod(a, b))

def Nar.sat_sub(lt: Bool, a: U32, b: U32) -> U32:
  match lt:
    case True{}:
      0
    case False{}:
      U32.sub(a, b)

def Nar.saturating_sub(+a: U32, +b: U32) -> U32:
  Nar.sat_sub(U32.is_lt(a, b), a, b)

def Nar.read(+m: U32, r: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match r:
    case None{}:
      None{}
    case Some{x}:
      +v = {x : U32}
      Nar.over(m, v)

# I32 holds its two's-complement bits in a U32.
def S32.MIN() -> U32:
  2147483648

def S32.is_neg(x: U32) -> Bool:
  U32.is_ge(x, S32.MIN())

def S32.neg(x: U32) -> U32:
  U32.sub(0, x)

def S32.neg_if(c: Bool, x: U32) -> U32:
  match c:
    case True{}:
      S32.neg(x)
    case False{}:
      x

def S32.abs(+x: U32) -> U32:
  S32.neg_if(S32.is_neg(x), x)

def S32.cmp(a: U32, b: U32) -> Cmp:
  U32.cmp(U32.xor(a, S32.MIN()), U32.xor(b, S32.MIN()))

# x / 0 is 0 and x % 0 is x, as in Base's U32. MIN / -1 wraps to MIN.
def S32.divmod.if(z: Bool, +a: U32, +b: U32) -> U32 & U32:
  match z:
    case True{}:
      (0, a)
    case False{}:
      (S32.neg_if(Bool.xor(S32.is_neg(a), S32.is_neg(b)),
        U32.div(S32.abs(a), S32.abs(b))),
        S32.neg_if(S32.is_neg(a), U32.mod(S32.abs(a), S32.abs(b))))

def S32.fst(p: U32 & U32) -> U32:
  (q, r) = p
  q

def S32.snd(p: U32 & U32) -> U32:
  (q, r) = p
  r

def S32.div(a: U32, +b: U32) -> U32:
  S32.fst(S32.divmod.if(U32.is_zero(b), a, b))

def S32.mod(a: U32, +b: U32) -> U32:
  S32.snd(S32.divmod.if(U32.is_zero(b), a, b))

# True for MIN and -1, the one quotient that overflows.
def S32.min_neg1(a: U32, b: U32) -> Bool:
  Bool.and(U32.is_eq(a, S32.MIN()), U32.is_eq(b, 4294967295))

def S32.div_ov(+a: U32, +b: U32) -> Bool:
  Bool.or(U32.is_zero(b), S32.min_neg1(a, b))

def S32.add_ov.go(a: U32, b: U32, +r: U32) -> Bool & U32:
  (S32.is_neg(U32.and(U32.xor(a, r), U32.xor(b, r))), r)

def S32.add_ov(+a: U32, +b: U32) -> Bool & U32:
  S32.add_ov.go(a, b, U32.add(a, b))

def S32.sub_ov.go(+a: U32, b: U32, +r: U32) -> Bool & U32:
  (S32.is_neg(U32.and(U32.xor(a, b), U32.xor(a, r))), r)

def S32.sub_ov(+a: U32, +b: U32) -> Bool & U32:
  S32.sub_ov.go(a, b, U32.sub(a, b))

def S32.mul_ov.go(+a: U32, +b: U32, +r: U32) -> Bool & U32:
  (Bool.or(Bool.and(Bool.not(U32.is_zero(b)),
    Bool.not(U32.is_eq(S32.div(r, b), a))), S32.min_neg1(a, b)), r)

def S32.mul_ov(+a: U32, +b: U32) -> Bool & U32:
  S32.mul_ov.go(a, b, U32.mul(a, b))

def S32.checked(o: Bool & U32) -> Maybe<&2, U32>:
  (ov, r) = o
  Nar.opt(ov, r)

def S32.checked_div(+a: U32, +b: U32) -> Maybe<&2, U32>:
  Nar.opt(S32.div_ov(a, b), S32.div(a, b))

def S32.checked_mod(+a: U32, +b: U32) -> Maybe<&2, U32>:
  Nar.opt(S32.div_ov(a, b), S32.mod(a, b))

def S32.sat(low: Bool) -> U32:
  match low:
    case True{}:
      S32.MIN()
    case False{}:
      2147483647

def S32.saturate(low: Bool, o: Bool & U32) -> U32:
  (ov, r) = o
  match ov:
    case True{}:
      S32.sat(low)
    case False{}:
      r

# Shifts right are arithmetic: the sign bit fills in from the top.
def S32.shr.if(neg: Bool, x: U32, k: Nat) -> U32:
  match neg:
    case True{}:
      U32.not(U32.shrn(U32.not(x), k))
    case False{}:
      U32.shrn(x, k)

def S32.show.if(neg: Bool, x: U32) -> String:
  match neg:
    case True{}:
      SCon{Chr{45}, U32.show(S32.neg(x))}
    case False{}:
      U32.show(x)

def S32.read.neg(r: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match r:
    case None{}:
      None{}
    case Some{x}:
      +v = {x : U32}
      Nar.opt(U32.is_gt(v, S32.MIN()), S32.neg(v))

def S32.read.pos(r: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match r:
    case None{}:
      None{}
    case Some{x}:
      +v = {x : U32}
      Nar.opt(S32.is_neg(v), v)

def S32.read.sign(neg: Bool, t: String, c: U32) -> Maybe<&2, U32>:
  match neg:
    case True{}:
      S32.read.neg(U32.read(t))
    case False{}:
      S32.read.pos(U32.read(SCon{Chr{c}, t}))

def S32.read(s: String) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      None{}
    case SCon{Chr{x}, t}:
      +c = {x : U32}
      S32.read.sign(U32.is_eq(c, 45), t, c)

def S32.to_nat.if(neg: Bool, x: U32) -> Maybe<&2, Nat>:
  match neg:
    case True{}:
      None{}
    case False{}:
      Some{U32.to_nat(x)}

type U8 is Data:
  U8{data: U32}

def U8.some(m: Maybe<&2, U32>) -> Maybe<&2, U8>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{U8{x}}

def U8.MIN() -> U8:
  U8{0}

def U8.MAX() -> U8:
  U8{255}

def U8.add(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.and(U32.add(x, y), 255)}

def U8.sub(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.and(U32.sub(x, y), 255)}

def U8.mul(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.and(U32.mul(x, y), 255)}

def U8.and(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.and(x, y)}

def U8.or(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.or(x, y)}

def U8.xor(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.xor(x, y)}

def U8.div(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.div(x, y)}

def U8.mod(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.mod(x, y)}

def U8.checked_add(a: U8, b: U8) -> Maybe<&2, U8>:
  match a b:
    case U8{x} U8{y}:
      U8.some(Nar.over(255, U32.add(x, y)))

def U8.checked_sub(a: U8, b: U8) -> Maybe<&2, U8>:
  match a b:
    case U8{x} U8{y}:
      U8.some(Nar.checked_sub(x, y))

def U8.checked_mul(a: U8, b: U8) -> Maybe<&2, U8>:
  match a b:
    case U8{x} U8{y}:
      U8.some(Nar.over(255, U32.mul(x, y)))

def U8.checked_div(a: U8, b: U8) -> Maybe<&2, U8>:
  match a b:
    case U8{x} U8{y}:
      U8.some(Nar.checked_div(x, y))

def U8.checked_mod(a: U8, b: U8) -> Maybe<&2, U8>:
  match a b:
    case U8{x} U8{y}:
      U8.some(Nar.checked_mod(x, y))

def U8.saturating_add(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.min(U32.add(x, y), 255)}

def U8.saturating_sub(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{Nar.saturating_sub(x, y)}

def U8.saturating_mul(a: U8, b: U8) -> U8:
  match a b:
    case U8{x} U8{y}:
      U8{U32.min(U32.mul(x, y), 255)}

def U8.cmp(a: U8, b: U8) -> Cmp:
  match a b:
    case U8{x} U8{y}:
      U32.cmp(x, y)

def U8.is_eq(a: U8, b: U8) -> Bool:
  Cmp.is_eq(U8.cmp(a, b))

def U8.is_lt(a: U8, b: U8) -> Bool:
  Cmp.is_lt(U8.cmp(a, b))

def U8.is_le(a: U8, b: U8) -> Bool:
  Cmp.is_le(U8.cmp(a, b))

def U8.is_gt(a: U8, b: U8) -> Bool:
  Cmp.is_gt(U8.cmp(a, b))

def U8.is_ge(a: U8, b: U8) -> Bool:
  Cmp.is_ge(U8.cmp(a, b))

def U8.is_ne(a: U8, b: U8) -> Bool:
  Bool.not(Cmp.is_eq(U8.cmp(a, b)))

def U8.is_zero(a: U8) -> Bool:
  match a:
    case U8{x}:
      U32.is_zero(x)

def U8.not(a: U8) -> U8:
  match a:
    case U8{x}:
      U8{U32.xor(x, 255)}

def U8.shl(a: U8, k: Nat) -> U8:
  match a:
    case U8{x}:
      U8{U32.and(U32.shln(x, k), 255)}

def U8.shr(a: U8, k: Nat) -> U8:
  match a:
    case U8{x}:
      U8{U32.shrn(x, k)}

def U8.show(a: U8) -> String:
  match a:
    case U8{x}:
      U32.show(x)

def U8.read(s: String) -> Maybe<&2, U8>:
  U8.some(Nar.read(255, U32.read(s)))

def U8.to_u32(a: U8) -> U32:
  match a:
    case U8{x}:
      x

def U8.from_u32(a: U32) -> U8:
  U8{U32.and(a, 255)}

def U8.to_nat(a: U8) -> Nat:
  match a:
    case U8{x}:
      U32.to_nat(x)

def U8.from_nat(k: Nat) -> U8:
  U8{U32.and(U32.from_nat(k), 255)}

type U16 is Data:
  U16{data: U32}

def U16.some(m: Maybe<&2, U32>) -> Maybe<&2, U16>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{U16{x}}

def U16.MIN() -> U16:
  U16{0}

def U16.MAX() -> U16:
  U16{65535}

def U16.add(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.and(U32.add(x, y), 65535)}

def U16.sub(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.and(U32.sub(x, y), 65535)}

def U16.mul(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.and(U32.mul(x, y), 65535)}

def U16.and(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.and(x, y)}

def U16.or(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.or(x, y)}

def U16.xor(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.xor(x, y)}

def U16.div(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.div(x, y)}

def U16.mod(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.mod(x, y)}

def U16.checked_add(a: U16, b: U16) -> Maybe<&2, U16>:
  match a b:
    case U16{x} U16{y}:
      U16.some(Nar.over(65535, U32.add(x, y)))

def U16.checked_sub(a: U16, b: U16) -> Maybe<&2, U16>:
  match a b:
    case U16{x} U16{y}:
      U16.some(Nar.checked_sub(x, y))

def U16.checked_mul(a: U16, b: U16) -> Maybe<&2, U16>:
  match a b:
    case U16{x} U16{y}:
      U16.some(Nar.over(65535, U32.mul(x, y)))

def U16.checked_div(a: U16, b: U16) -> Maybe<&2, U16>:
  match a b:
    case U16{x} U16{y}:
      U16.some(Nar.checked_div(x, y))

def U16.checked_mod(a: U16, b: U16) -> Maybe<&2, U16>:
  match a b:
    case U16{x} U16{y}:
      U16.some(Nar.checked_mod(x, y))

def U16.saturating_add(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.min(U32.add(x, y), 65535)}

def U16.saturating_sub(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{Nar.saturating_sub(x, y)}

def U16.saturating_mul(a: U16, b: U16) -> U16:
  match a b:
    case U16{x} U16{y}:
      U16{U32.min(U32.mul(x, y), 65535)}

def U16.cmp(a: U16, b: U16) -> Cmp:
  match a b:
    case U16{x} U16{y}:
      U32.cmp(x, y)

def U16.is_eq(a: U16, b: U16) -> Bool:
  Cmp.is_eq(U16.cmp(a, b))

def U16.is_lt(a: U16, b: U16) -> Bool:
  Cmp.is_lt(U16.cmp(a, b))

def U16.is_le(a: U16, b: U16) -> Bool:
  Cmp.is_le(U16.cmp(a, b))

def U16.is_gt(a: U16, b: U16) -> Bool:
  Cmp.is_gt(U16.cmp(a, b))

def U16.is_ge(a: U16, b: U16) -> Bool:
  Cmp.is_ge(U16.cmp(a, b))

def U16.is_ne(a: U16, b: U16) -> Bool:
  Bool.not(Cmp.is_eq(U16.cmp(a, b)))

def U16.is_zero(a: U16) -> Bool:
  match a:
    case U16{x}:
      U32.is_zero(x)

def U16.not(a: U16) -> U16:
  match a:
    case U16{x}:
      U16{U32.xor(x, 65535)}

def U16.shl(a: U16, k: Nat) -> U16:
  match a:
    case U16{x}:
      U16{U32.and(U32.shln(x, k), 65535)}

def U16.shr(a: U16, k: Nat) -> U16:
  match a:
    case U16{x}:
      U16{U32.shrn(x, k)}

def U16.show(a: U16) -> String:
  match a:
    case U16{x}:
      U32.show(x)

def U16.read(s: String) -> Maybe<&2, U16>:
  U16.some(Nar.read(65535, U32.read(s)))

def U16.to_u32(a: U16) -> U32:
  match a:
    case U16{x}:
      x

def U16.from_u32(a: U32) -> U16:
  U16{U32.and(a, 65535)}

def U16.to_nat(a: U16) -> Nat:
  match a:
    case U16{x}:
      U32.to_nat(x)

def U16.from_nat(k: Nat) -> U16:
  U16{U32.and(U32.from_nat(k), 65535)}

# ponytail: Word(64n) costs about 68 us per op. When Base ships a native U64
# (bendlang/bend#1027), store Base's U64 here, as U8 and U16 store Base's U32.
type U64 is Data:
  U64{data: Word(64n)}

def U64.some(m: Maybe<&2, Word(64n)>) -> Maybe<&2, U64>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{U64{x}}

def U64.MIN() -> U64:
  U64{Int.min(64n, False{})}

def U64.MAX() -> U64:
  U64{Int.max(64n, False{})}

def U64.add(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Word.add(64n, x, y)}

def U64.sub(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Word.sub(64n, x, y)}

def U64.mul(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Word.mul(64n, x, y)}

def U64.and(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Word.and(64n, x, y)}

def U64.or(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Word.or(64n, x, y)}

def U64.xor(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Word.xor(64n, x, y)}

def U64.div(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Int.div(64n, False{}, x, y)}

def U64.mod(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Int.mod(64n, False{}, x, y)}

def U64.checked_add(a: U64, b: U64) -> Maybe<&2, U64>:
  match a b:
    case U64{x} U64{y}:
      U64.some(Int.checked(64n, Int.add_ov(64n, False{}, x, y)))

def U64.checked_sub(a: U64, b: U64) -> Maybe<&2, U64>:
  match a b:
    case U64{x} U64{y}:
      U64.some(Int.checked(64n, Int.sub_ov(64n, False{}, x, y)))

def U64.checked_mul(a: U64, b: U64) -> Maybe<&2, U64>:
  match a b:
    case U64{x} U64{y}:
      U64.some(Int.checked(64n, Int.mul_ov(64n, False{}, x, y)))

def U64.checked_div(a: U64, b: U64) -> Maybe<&2, U64>:
  match a b:
    case U64{x} U64{y}:
      U64.some(Int.checked_div(64n, False{}, x, y))

def U64.checked_mod(a: U64, b: U64) -> Maybe<&2, U64>:
  match a b:
    case U64{x} U64{y}:
      U64.some(Int.checked_mod(64n, False{}, x, y))

def U64.saturating_add(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Int.saturating_add(64n, False{}, x, y)}

def U64.saturating_sub(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Int.saturating_sub(64n, False{}, x, y)}

def U64.saturating_mul(a: U64, b: U64) -> U64:
  match a b:
    case U64{x} U64{y}:
      U64{Int.saturating_mul(64n, False{}, x, y)}

def U64.cmp(a: U64, b: U64) -> Cmp:
  match a b:
    case U64{x} U64{y}:
      Int.cmp(64n, False{}, x, y)

def U64.is_eq(a: U64, b: U64) -> Bool:
  Cmp.is_eq(U64.cmp(a, b))

def U64.is_lt(a: U64, b: U64) -> Bool:
  Cmp.is_lt(U64.cmp(a, b))

def U64.is_le(a: U64, b: U64) -> Bool:
  Cmp.is_le(U64.cmp(a, b))

def U64.is_gt(a: U64, b: U64) -> Bool:
  Cmp.is_gt(U64.cmp(a, b))

def U64.is_ge(a: U64, b: U64) -> Bool:
  Cmp.is_ge(U64.cmp(a, b))

def U64.is_ne(a: U64, b: U64) -> Bool:
  Bool.not(Cmp.is_eq(U64.cmp(a, b)))

def U64.is_zero(a: U64) -> Bool:
  match a:
    case U64{x}:
      Int.is_zero(64n, x)

def U64.not(a: U64) -> U64:
  match a:
    case U64{x}:
      U64{Word.not(64n, x)}

def U64.shl(a: U64, k: Nat) -> U64:
  match a:
    case U64{x}:
      U64{Int.shl(64n, k, x)}

def U64.shr(a: U64, k: Nat) -> U64:
  match a:
    case U64{x}:
      U64{Int.shr(64n, False{}, k, x)}

def U64.show(a: U64) -> String:
  match a:
    case U64{x}:
      Int.show(64n, False{}, x)

def U64.read(s: String) -> Maybe<&2, U64>:
  U64.some(Int.read(64n, False{}, s))

def U64.to_u32(a: U64) -> U32:
  match a:
    case U64{x}:
      U32{Int.ext(32n, 64n, False{}, x)}

def U64.from_u32(a: U32) -> U64:
  match a:
    case U32{x}:
      U64{Int.ext(64n, 32n, False{}, x)}

# A native build stops on a Nat past 2^48 - 1, so large U64 values have no native Nat.
def U64.to_nat(a: U64) -> Nat:
  match a:
    case U64{x}:
      Word.to_nat(64n, x)

def U64.from_nat(k: Nat) -> U64:
  U64{Int.bits(64n, k)}

type I32 is Data:
  I32{data: U32}

def I32.some(m: Maybe<&2, U32>) -> Maybe<&2, I32>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{I32{x}}

def I32.MIN() -> I32:
  I32{S32.MIN()}

def I32.MAX() -> I32:
  I32{2147483647}

def I32.add(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      I32{U32.add(x, y)}

def I32.sub(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      I32{U32.sub(x, y)}

def I32.mul(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      I32{U32.mul(x, y)}

def I32.and(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      I32{U32.and(x, y)}

def I32.or(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      I32{U32.or(x, y)}

def I32.xor(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      I32{U32.xor(x, y)}

def I32.div(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      I32{S32.div(x, y)}

def I32.mod(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      I32{S32.mod(x, y)}

def I32.checked_add(a: I32, b: I32) -> Maybe<&2, I32>:
  match a b:
    case I32{x} I32{y}:
      I32.some(S32.checked(S32.add_ov(x, y)))

def I32.checked_sub(a: I32, b: I32) -> Maybe<&2, I32>:
  match a b:
    case I32{x} I32{y}:
      I32.some(S32.checked(S32.sub_ov(x, y)))

def I32.checked_mul(a: I32, b: I32) -> Maybe<&2, I32>:
  match a b:
    case I32{x} I32{y}:
      I32.some(S32.checked(S32.mul_ov(x, y)))

def I32.checked_div(a: I32, b: I32) -> Maybe<&2, I32>:
  match a b:
    case I32{x} I32{y}:
      I32.some(S32.checked_div(x, y))

def I32.checked_mod(a: I32, b: I32) -> Maybe<&2, I32>:
  match a b:
    case I32{x} I32{y}:
      I32.some(S32.checked_mod(x, y))

def I32.cmp(a: I32, b: I32) -> Cmp:
  match a b:
    case I32{x} I32{y}:
      S32.cmp(x, y)

def I32.saturating_add(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      +v = {x : U32}
      I32{S32.saturate(S32.is_neg(v), S32.add_ov(v, y))}

def I32.saturating_sub(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      +v = {x : U32}
      I32{S32.saturate(S32.is_neg(v), S32.sub_ov(v, y))}

def I32.saturating_mul(a: I32, b: I32) -> I32:
  match a b:
    case I32{x} I32{y}:
      +v = {x : U32}
      +w = {y : U32}
      I32{S32.saturate(Bool.xor(S32.is_neg(v), S32.is_neg(w)), S32.mul_ov(v, w))}

def I32.is_eq(a: I32, b: I32) -> Bool:
  Cmp.is_eq(I32.cmp(a, b))

def I32.is_lt(a: I32, b: I32) -> Bool:
  Cmp.is_lt(I32.cmp(a, b))

def I32.is_le(a: I32, b: I32) -> Bool:
  Cmp.is_le(I32.cmp(a, b))

def I32.is_gt(a: I32, b: I32) -> Bool:
  Cmp.is_gt(I32.cmp(a, b))

def I32.is_ge(a: I32, b: I32) -> Bool:
  Cmp.is_ge(I32.cmp(a, b))

def I32.is_ne(a: I32, b: I32) -> Bool:
  Bool.not(Cmp.is_eq(I32.cmp(a, b)))

def I32.is_zero(a: I32) -> Bool:
  match a:
    case I32{x}:
      U32.is_zero(x)

def I32.not(a: I32) -> I32:
  match a:
    case I32{x}:
      I32{U32.not(x)}

def I32.shl(a: I32, k: Nat) -> I32:
  match a:
    case I32{x}:
      I32{U32.shln(x, k)}

def I32.shr(a: I32, k: Nat) -> I32:
  match a:
    case I32{x}:
      +v = {x : U32}
      I32{S32.shr.if(S32.is_neg(v), v, k)}

def I32.neg(a: I32) -> I32:
  match a:
    case I32{x}:
      I32{S32.neg(x)}

def I32.abs(a: I32) -> I32:
  match a:
    case I32{x}:
      I32{S32.abs(x)}

def I32.is_neg(a: I32) -> Bool:
  match a:
    case I32{x}:
      S32.is_neg(x)

def I32.show(a: I32) -> String:
  match a:
    case I32{x}:
      +v = {x : U32}
      S32.show.if(S32.is_neg(v), v)

def I32.read(s: String) -> Maybe<&2, I32>:
  I32.some(S32.read(s))

def I32.to_u32(a: I32) -> U32:
  match a:
    case I32{x}:
      x

def I32.from_u32(a: U32) -> I32:
  I32{a}

def I32.to_nat(a: I32) -> Maybe<&2, Nat>:
  match a:
    case I32{x}:
      +v = {x : U32}
      S32.to_nat.if(S32.is_neg(v), v)

def I32.from_nat(k: Nat) -> I32:
  I32{U32.from_nat(k)}

# ponytail: Word(64n) costs about 68 us per op. When Base ships a native U64
# (bendlang/bend#1027), store its bits in Base's U64, as I32 does with Base's U32.
type I64 is Data:
  I64{data: Word(64n)}

def I64.some(m: Maybe<&2, Word(64n)>) -> Maybe<&2, I64>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{I64{x}}

def I64.MIN() -> I64:
  I64{Int.min(64n, True{})}

def I64.MAX() -> I64:
  I64{Int.max(64n, True{})}

def I64.add(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Word.add(64n, x, y)}

def I64.sub(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Word.sub(64n, x, y)}

def I64.mul(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Word.mul(64n, x, y)}

def I64.and(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Word.and(64n, x, y)}

def I64.or(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Word.or(64n, x, y)}

def I64.xor(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Word.xor(64n, x, y)}

def I64.div(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Int.div(64n, True{}, x, y)}

def I64.mod(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Int.mod(64n, True{}, x, y)}

def I64.checked_add(a: I64, b: I64) -> Maybe<&2, I64>:
  match a b:
    case I64{x} I64{y}:
      I64.some(Int.checked(64n, Int.add_ov(64n, True{}, x, y)))

def I64.checked_sub(a: I64, b: I64) -> Maybe<&2, I64>:
  match a b:
    case I64{x} I64{y}:
      I64.some(Int.checked(64n, Int.sub_ov(64n, True{}, x, y)))

def I64.checked_mul(a: I64, b: I64) -> Maybe<&2, I64>:
  match a b:
    case I64{x} I64{y}:
      I64.some(Int.checked(64n, Int.mul_ov(64n, True{}, x, y)))

def I64.checked_div(a: I64, b: I64) -> Maybe<&2, I64>:
  match a b:
    case I64{x} I64{y}:
      I64.some(Int.checked_div(64n, True{}, x, y))

def I64.checked_mod(a: I64, b: I64) -> Maybe<&2, I64>:
  match a b:
    case I64{x} I64{y}:
      I64.some(Int.checked_mod(64n, True{}, x, y))

def I64.saturating_add(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Int.saturating_add(64n, True{}, x, y)}

def I64.saturating_sub(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Int.saturating_sub(64n, True{}, x, y)}

def I64.saturating_mul(a: I64, b: I64) -> I64:
  match a b:
    case I64{x} I64{y}:
      I64{Int.saturating_mul(64n, True{}, x, y)}

def I64.cmp(a: I64, b: I64) -> Cmp:
  match a b:
    case I64{x} I64{y}:
      Int.cmp(64n, True{}, x, y)

def I64.is_eq(a: I64, b: I64) -> Bool:
  Cmp.is_eq(I64.cmp(a, b))

def I64.is_lt(a: I64, b: I64) -> Bool:
  Cmp.is_lt(I64.cmp(a, b))

def I64.is_le(a: I64, b: I64) -> Bool:
  Cmp.is_le(I64.cmp(a, b))

def I64.is_gt(a: I64, b: I64) -> Bool:
  Cmp.is_gt(I64.cmp(a, b))

def I64.is_ge(a: I64, b: I64) -> Bool:
  Cmp.is_ge(I64.cmp(a, b))

def I64.is_ne(a: I64, b: I64) -> Bool:
  Bool.not(Cmp.is_eq(I64.cmp(a, b)))

def I64.is_zero(a: I64) -> Bool:
  match a:
    case I64{x}:
      Int.is_zero(64n, x)

def I64.not(a: I64) -> I64:
  match a:
    case I64{x}:
      I64{Word.not(64n, x)}

def I64.shl(a: I64, k: Nat) -> I64:
  match a:
    case I64{x}:
      I64{Int.shl(64n, k, x)}

def I64.shr(a: I64, k: Nat) -> I64:
  match a:
    case I64{x}:
      I64{Int.shr(64n, True{}, k, x)}

def I64.neg(a: I64) -> I64:
  match a:
    case I64{x}:
      I64{Int.neg(64n, x)}

def I64.abs(a: I64) -> I64:
  match a:
    case I64{x}:
      I64{Int.abs(64n, x)}

def I64.is_neg(a: I64) -> Bool:
  match a:
    case I64{x}:
      Int.msb(64n, x)

def I64.show(a: I64) -> String:
  match a:
    case I64{x}:
      Int.show(64n, True{}, x)

def I64.read(s: String) -> Maybe<&2, I64>:
  I64.some(Int.read(64n, True{}, s))

def I64.to_u32(a: I64) -> U32:
  match a:
    case I64{x}:
      U32{Int.sext(32n, 64n, x)}

def I64.from_u32(a: U32) -> I64:
  match a:
    case U32{x}:
      I64{Int.ext(64n, 32n, False{}, x)}

def I64.to_nat(a: I64) -> Maybe<&2, Nat>:
  match a:
    case I64{x}:
      Int.to_nat(64n, x)

def I64.from_nat(k: Nat) -> I64:
  I64{Int.bits(64n, k)}
