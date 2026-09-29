# Arbitrary-precision signed integers: add, sub, mul, divmod, pow, modpow, gcd and decimal text.
import Base

# A magnitude is a list of base-10^4 limbs in U32, least significant first,
# with no zero limb on top. Base 10^4 keeps every limb product and its carries
# below 2^32, and makes decimal show and read linear. Zero is never negative.
type BigInt is Data:
  BigInt{neg: Bool, mag: List<&2, U32>}

# A match cannot scrutinize a computed Bool, so each branch is a closure.
def Mag.if(-A: Type, c: Bool, t: Unit -> A, e: Unit -> A) -> A:
  match c:
    case True{}:
      t(Unit{})
    case False{}:
      e(Unit{})

def Mag.lone(z: Bool, x: U32) -> List<&2, U32>:
  match z:
    case True{}:
      Nil{}
    case False{}:
      Con{x, Nil{}}

# x + r * 10^4, dropping a zero limb on top.
def Mag.cons(+x: U32, r: List<&2, U32>) -> List<&2, U32>:
  match r:
    case Nil{}:
      Mag.lone(U32.is_zero(x), x)
    case s:
      Con{x, s}

def Mag.norm(xs: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      Mag.cons(x, Mag.norm(t))

def Mag.len(xs: List<&2, U32>) -> Nat:
  List.length(&2, U32, xs)

def Mag.at(xs: List<&2, U32>, i: Nat) -> U32:
  Maybe.default(&2, U32, List.get(&2, U32, xs, i), 0)

def Mag.top(xs: List<&2, U32>) -> U32:
  Maybe.default(&2, U32, List.last(&2, U32, xs), 0)

def Mag.odd(xs: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case Con{x, t}:
      U32.is_eq(U32.and(x, 1), 1)

# The limbs are 0 or 1 in z: z says the carry c is 0, so a stays as is.
def Mag.inc(a: List<&2, U32>, z: Bool, +c: U32) -> List<&2, U32>:
  match a z:
    case s True{}:
      s
    case Nil{} False{}:
      Con{c, Nil{}}
    case Con{x, xs} False{}:
      +t = (x + c : U32)
      +k = (t / 10000 : U32)
      Con{(t % 10000 : U32), Mag.inc(xs, U32.is_zero(k), k)}

def Mag.add(a: List<&2, U32>, b: List<&2, U32>, +c: U32) -> List<&2, U32>:
  match a b:
    case Con{x, xs} Con{y, ys}:
      +t = (x + y + c : U32)
      Con{(t % 10000 : U32), Mag.add(xs, ys, (t / 10000 : U32))}
    case Nil{} s:
      Mag.inc(s, U32.is_zero(c), c)
    case s Nil{}:
      Mag.inc(s, U32.is_zero(c), c)

# a - w for the borrow w; z says w is 0. Leaves zero limbs on top.
def Mag.dec(a: List<&2, U32>, z: Bool, +w: U32) -> List<&2, U32>:
  match a z:
    case s True{}:
      s
    case Nil{} False{}:
      Nil{}
    case Con{x, xs} False{}:
      +t = (x + 10000 - w : U32)
      +k = (1 - t / 10000 : U32)
      Con{(t % 10000 : U32), Mag.dec(xs, U32.is_zero(k), k)}

# a - b - w for a >= b + w. Leaves zero limbs on top: callers norm.
def Mag.sub(a: List<&2, U32>, b: List<&2, U32>, +w: U32) -> List<&2, U32>:
  match a b:
    case Con{x, xs} Con{y, ys}:
      +t = (x + 10000 - y - w : U32)
      Con{(t % 10000 : U32), Mag.sub(xs, ys, (1 - t / 10000 : U32))}
    case s Nil{}:
      Mag.dec(s, U32.is_zero(w), w)
    case Nil{} s:
      Nil{}

def Mag.then(hi: Cmp, lo: Cmp) -> Cmp:
  match hi:
    case EQ{}:
      lo
    case LT{}:
      LT{}
    case GT{}:
      GT{}

# Both canonical, so the longer one is larger.
def Mag.cmp(a: List<&2, U32>, b: List<&2, U32>) -> Cmp:
  match a b:
    case Con{x, xs} Con{y, ys}:
      Mag.then(Mag.cmp(xs, ys), U32.cmp(x, y))
    case Nil{} Nil{}:
      EQ{}
    case Nil{} Con{y, ys}:
      LT{}
    case Con{x, xs} Nil{}:
      GT{}

# a * m + c for m, c below 10^4.
def Mag.mul1(a: List<&2, U32>, +m: U32, +c: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      Mag.lone(U32.is_zero(c), c)
    case Con{x, xs}:
      +t = (x * m + c : U32)
      Con{(t % 10000 : U32), Mag.mul1(xs, m, (t / 10000 : U32))}

def Mag.scale(+a: List<&2, U32>, +m: U32) -> List<&2, U32>:
  Mag.if(List<&2, U32>, U32.is_zero(m), u => Nil{}, u => Mag.mul1(a, m, 0))

def Mag.school.put(p: List<&2, U32>, r: List<&2, U32>) -> List<&2, U32>:
  match p:
    case Nil{}:
      Mag.cons(0, r)
    case Con{h, t}:
      Mag.cons(h, Mag.add(t, r, 0))

def Mag.school(a: List<&2, U32>, +b: List<&2, U32>) -> List<&2, U32>:
  match a:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      Mag.school.put(Mag.scale(b, x), Mag.school(t, b))

def Mag.zeros(n: Nat, xs: List<&2, U32>) -> List<&2, U32>:
  match n:
    case 0n:
      xs
    case 1n+p:
      Con{0, Mag.zeros(p, xs)}

# xs * 10^(4 n).
def Mag.shift(xs: List<&2, U32>, n: Nat) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case s:
      Mag.zeros(n, s)

def Mag.lo(xs: List<&2, U32>, k: Nat) -> List<&2, U32>:
  Mag.norm(List.take(&2, U32, xs, k))

# z0 + (s - z0 - z2) B^k + z2 B^2k, with B = 10^(4 k).
def Mag.kara(+k: Nat, +z0: List<&2, U32>, +z2: List<&2, U32>,
  s: List<&2, U32>) -> List<&2, U32>:
  +mid = Mag.norm(Mag.sub(Mag.norm(Mag.sub(s, z0, 0)), z2, 0))
  Mag.add(z0, Mag.shift(Mag.add(mid, Mag.shift(z2, k), 0), k), 0)

# Karatsuba while both sides have at least 32 limbs, schoolbook below. f caps
# the depth; 32 halvings outrun any list that fits in memory.
def Mag.kmul(+f: Nat, +a: List<&2, U32>, +b: List<&2, U32>) -> List<&2, U32>:
  match f:
    case 0n:
      Mag.school(a, b)
    case 1n+p:
      +k = Nat.div(Nat.min(Mag.len(a), Mag.len(b)), 2n)
      +a0 = Mag.lo(a, k)
      +a1 = List.drop(&2, U32, a, k)
      +b0 = Mag.lo(b, k)
      +b1 = List.drop(&2, U32, b, k)
      Mag.if(List<&2, U32>, Nat.is_lt(k, 16n),
        u => Mag.school(a, b),
        u => Mag.kara(k, Mag.kmul(p, a0, b0), Mag.kmul(p, a1, b1),
          Mag.kmul(p, Mag.add(a0, a1, 0), Mag.add(b0, b1, 0))))

def Mag.mul(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  Mag.kmul(32n, a, b)

# Short division of a big-endian list by d below 10^4 with remainder rem:
# the quotient comes out little-endian, with zero limbs on top.
def Mag.dsmall(xs: List<&2, U32>, +d: U32, +rem: U32, acc: List<&2, U32>) ->
  List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{x, t}:
      +v = (rem * 10000 + x : U32)
      Mag.dsmall(t, d, (v % d : U32), Con{(v / d : U32), acc})

def Mag.half(+xs: List<&2, U32>) -> List<&2, U32>:
  Mag.norm(Mag.dsmall(List.reverse(&2, U32, xs), 2, 0, Nil{}))

# Knuth's Algorithm D step D6: the estimate d is at most 2 over the true
# quotient digit, so f = 3 steps of p - bn always settle it.
def Mag.fix(+f: Nat, +d: U32, +p: List<&2, U32>, +r: List<&2, U32>,
  +bn: List<&2, U32>, +q: List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  match f:
    case 0n:
      (Con{d, q}, Mag.norm(Mag.sub(r, p, 0)))
    case 1n+g:
      Mag.if(List<&2, U32> & List<&2, U32>, Cmp.is_gt(Mag.cmp(p, r)),
        u => Mag.fix(g, (d - 1 : U32), Mag.norm(Mag.sub(p, bn, 0)), r, bn, q),
        u => (Con{d, q}, Mag.norm(Mag.sub(r, p, 0))))

# One quotient digit: bring limb x down into r, estimate from r's top two
# limbs over bn's top limb vt, and correct.
def Mag.step(x: U32, +bn: List<&2, U32>, +n: Nat, +n1: Nat, +vt: U32,
  qr: List<&2, U32> & List<&2, U32>) -> List<&2, U32> & List<&2, U32>:
  (q, r) = qr
  +r2 = Mag.cons(x, r)
  +d = U32.min(((Mag.at(r2, n) * 10000 + Mag.at(r2, n1)) / vt : U32), 9999)
  Mag.fix(3n, d, Mag.scale(bn, d), r2, bn, q)

# Long division over the dividend's limbs, most significant first. Quotient
# digits are consed, so the quotient comes out little-endian.
def Mag.long(xs: List<&2, U32>, +bn: List<&2, U32>, +n: Nat, +n1: Nat,
  +vt: U32, qr: List<&2, U32> & List<&2, U32>) ->
  List<&2, U32> & List<&2, U32>:
  match xs:
    case Nil{}:
      qr
    case Con{x, t}:
      Mag.long(t, bn, n, n1, vt, Mag.step(x, bn, n, n1, vt, qr))

def Mag.divmod.fin(+f: U32, qr: List<&2, U32> & List<&2, U32>) ->
  List<&2, U32> & List<&2, U32>:
  (q, r) = qr
  (Mag.norm(q), Mag.norm(Mag.dsmall(List.reverse(&2, U32, r), f, 0, Nil{})))

# a / b and a % b for b above 0. Both scale by f so that b's top limb is at
# least 10^4 / 2 (Knuth D1), and the remainder scales back.
def Mag.divmod(a: List<&2, U32>, +b: List<&2, U32>) ->
  List<&2, U32> & List<&2, U32>:
  +f = (10000 / (Mag.top(b) + 1) : U32)
  +bn = Mag.mul1(b, f, 0)
  +n = Mag.len(bn)
  Mag.divmod.fin(f, Mag.long(List.reverse(&2, U32, Mag.mul1(a, f, 0)), bn, n,
    Nat.sub(n, 1n), Mag.top(bn),
    {(Nil{}, Nil{}) : List<&2, U32> & List<&2, U32>}))

def Mag.snd(qr: List<&2, U32> & List<&2, U32>) -> List<&2, U32>:
  (q, r) = qr
  r

def Mag.rem(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  Mag.snd(Mag.divmod(a, b))

# b^e * acc by squaring; e <= f, and e halves as f counts down.
def Mag.pow(+f: Nat, +b: List<&2, U32>, +e: Nat, +acc: List<&2, U32>) ->
  List<&2, U32>:
  match f:
    case 0n:
      acc
    case 1n+g:
      +h = Nat.div(e, 2n)
      +acc2 = Mag.if(List<&2, U32>, Nat.is_eq(Nat.mod(e, 2n), 1n),
        u => Mag.mul(acc, b), u => acc)
      Mag.if(List<&2, U32>, Nat.is_eq(h, 0n), u => acc2,
        u => Mag.pow(g, Mag.mul(b, b), h, acc2))

# b^e * acc mod m, with b and acc below m. f counts e's bits: 14 per limb,
# since 10^4 < 2^14.
def Mag.modpow(+f: Nat, +b: List<&2, U32>, +e: List<&2, U32>,
  +acc: List<&2, U32>, +m: List<&2, U32>) -> List<&2, U32>:
  match f:
    case 0n:
      acc
    case 1n+g:
      +h = Mag.half(e)
      +acc2 = Mag.if(List<&2, U32>, Mag.odd(e),
        u => Mag.rem(Mag.mul(acc, b), m), u => acc)
      Mag.if(List<&2, U32>, List.is_empty(&2, U32, h), u => acc2,
        u => Mag.modpow(g, Mag.rem(Mag.mul(b, b), m), h, acc2, m))

# Euclid. Lame: under 5 steps per decimal digit of the smaller, so f from
# 20 per limb of both never runs out.
def Mag.gcd(+f: Nat, +a: List<&2, U32>, +b: List<&2, U32>) -> List<&2, U32>:
  match f:
    case 0n:
      a
    case 1n+g:
      Mag.if(List<&2, U32>, List.is_empty(&2, U32, b), u => a,
        u => Mag.gcd(g, b, Mag.rem(a, b)))

def Mag.dig(d: U32) -> Char:
  Chr{(48 + d : U32)}

def Mag.d4(+x: U32, acc: String) -> String:
  SCon{Mag.dig((x / 1000 : U32)), SCon{Mag.dig(((x / 100) % 10 : U32)),
    SCon{Mag.dig(((x / 10) % 10 : U32)), SCon{Mag.dig((x % 10 : U32)), acc}}}}

# The top limb unpadded, every lower limb as four digits.
def Mag.show(xs: List<&2, U32>, acc: String) -> String:
  match xs:
    case Nil{}:
      acc
    case Con{x, Nil{}}:
      U32.show(x) ++ acc
    case Con{x, t}:
      Mag.show(t, Mag.d4(x, acc))

# The digit values of s, last first, and whether every char was a digit.
def Mag.digits(s: String, ok: Bool, acc: List<&2, U32>) ->
  Bool & List<&2, U32>:
  match s:
    case SNil{}:
      (ok, acc)
    case SCon{Chr{c}, t}:
      +d = (c - 48 : U32)
      Mag.digits(t, Bool.and(ok, U32.is_lt(d, 10)), Con{d, acc})

# Digits, least significant first, four to a limb.
def Mag.group(ds: List<&2, U32>) -> List<&2, U32>:
  match ds:
    case Con{a, Con{b, Con{c, Con{d, t}}}}:
      Con{(a + 10 * b + 100 * c + 1000 * d : U32), Mag.group(t)}
    case Con{a, Con{b, Con{c, Nil{}}}}:
      Con{(a + 10 * b + 100 * c : U32), Nil{}}
    case Con{a, Con{b, Nil{}}}:
      Con{(a + 10 * b : U32), Nil{}}
    case Con{a, Nil{}}:
      Con{a, Nil{}}
    case Nil{}:
      Nil{}

def BigInt.mk(neg: Bool, m: List<&2, U32>) -> BigInt:
  match m:
    case Nil{}:
      BigInt{False{}, Nil{}}
    case s:
      BigInt{neg, s}

def BigInt.zero() -> BigInt:
  BigInt{False{}, Nil{}}

def BigInt.one() -> BigInt:
  BigInt{False{}, Con{1, Nil{}}}

def BigInt.from_u32(+x: U32) -> BigInt:
  BigInt{False{}, Mag.norm(Con{(x % 10000 : U32),
    Con{((x / 10000) % 10000 : U32), Con{(x / 100000000 : U32), Nil{}}}})}

def BigInt.neg(x: BigInt) -> BigInt:
  match x:
    case BigInt{s, m}:
      BigInt.mk(Bool.not(s), m)

def BigInt.abs(x: BigInt) -> BigInt:
  match x:
    case BigInt{s, m}:
      BigInt{False{}, m}

def BigInt.is_zero(x: BigInt) -> Bool:
  match x:
    case BigInt{s, m}:
      List.is_empty(&2, U32, m)

def BigInt.cmp(a: BigInt, b: BigInt) -> Cmp:
  match a b:
    case BigInt{False{}, x} BigInt{False{}, y}:
      Mag.cmp(x, y)
    case BigInt{True{}, x} BigInt{True{}, y}:
      Mag.cmp(y, x)
    case BigInt{False{}, x} BigInt{True{}, y}:
      GT{}
    case BigInt{True{}, x} BigInt{False{}, y}:
      LT{}

# Signs differ: the larger magnitude keeps its sign.
def BigInt.add.mixed(c: Cmp, +sa: Bool, x: List<&2, U32>, y: List<&2, U32>) ->
  BigInt:
  match c:
    case LT{}:
      BigInt.mk(Bool.not(sa), Mag.norm(Mag.sub(y, x, 0)))
    case EQ{}:
      BigInt.zero()
    case GT{}:
      BigInt.mk(sa, Mag.norm(Mag.sub(x, y, 0)))

def BigInt.add.go(diff: Bool, sa: Bool, +x: List<&2, U32>,
  +y: List<&2, U32>) -> BigInt:
  match diff:
    case True{}:
      BigInt.add.mixed(Mag.cmp(x, y), sa, x, y)
    case False{}:
      BigInt{sa, Mag.add(x, y, 0)}

def BigInt.add(a: BigInt, b: BigInt) -> BigInt:
  match a b:
    case BigInt{+sa, x} BigInt{sb, y}:
      BigInt.add.go(Bool.xor(sa, sb), sa, x, y)

def BigInt.sub(a: BigInt, b: BigInt) -> BigInt:
  BigInt.add(a, BigInt.neg(b))

def BigInt.mul(a: BigInt, b: BigInt) -> BigInt:
  match a b:
    case BigInt{sa, x} BigInt{sb, y}:
      BigInt.mk(Bool.xor(sa, sb), Mag.mul(x, y))

def BigInt.divmod.fin(+sa: Bool, sb: Bool,
  qr: List<&2, U32> & List<&2, U32>) -> BigInt & BigInt:
  (q, r) = qr
  (BigInt.mk(Bool.xor(sa, sb), q), BigInt.mk(sa, r))

# Truncates toward zero: the remainder takes the dividend's sign.
def BigInt.divmod(a: BigInt, b: BigInt) -> Maybe<&1, BigInt & BigInt>:
  match a b:
    case BigInt{sa, x} BigInt{sb, Nil{}}:
      None{}
    case BigInt{sa, x} BigInt{sb, y}:
      Some{BigInt.divmod.fin(sa, sb, Mag.divmod(x, y))}

def BigInt.pow(b: BigInt, +e: Nat) -> BigInt:
  match b:
    case BigInt{s, x}:
      BigInt.mk(Bool.and(s, Nat.is_eq(Nat.mod(e, 2n), 1n)),
        Mag.pow(e, x, e, Con{1, Nil{}}))

# The base's residue in [0, m).
def Mag.base(neg: Bool, +r: List<&2, U32>, +m: List<&2, U32>) ->
  List<&2, U32>:
  match neg:
    case True{}:
      Mag.if(List<&2, U32>, List.is_empty(&2, U32, r), u => r,
        u => Mag.norm(Mag.sub(m, r, 0)))
    case False{}:
      r

def BigInt.modpow.go(neg_e: Bool, sb: Bool, x: List<&2, U32>,
  +y: List<&2, U32>, +m: List<&2, U32>) -> Maybe<&2, BigInt>:
  match neg_e:
    case True{}:
      None{}
    case False{}:
      Some{BigInt{False{}, Mag.modpow(Nat.mul(Mag.len(y), 14n),
        Mag.base(sb, Mag.rem(x, m), m), y, Mag.rem(Con{1, Nil{}}, m), m)}}

# b^e mod |m| in [0, |m|). None for m = 0 or e < 0.
def BigInt.modpow(b: BigInt, e: BigInt, m: BigInt) -> Maybe<&2, BigInt>:
  match b e m:
    case BigInt{sb, x} BigInt{se, y} BigInt{sm, Nil{}}:
      None{}
    case BigInt{sb, x} BigInt{se, y} BigInt{sm, z}:
      BigInt.modpow.go(se, sb, x, y, z)

# Never negative; gcd(0, 0) is 0.
def BigInt.gcd(a: BigInt, b: BigInt) -> BigInt:
  match a b:
    case BigInt{sa, +x} BigInt{sb, +y}:
      BigInt{False{}, Mag.gcd(
        Nat.add(Nat.mul(Nat.add(Mag.len(x), Mag.len(y)), 20n), 2n), x, y)}

def BigInt.show(x: BigInt) -> String:
  match x:
    case BigInt{s, Nil{}}:
      "0"
    case BigInt{True{}, m}:
      SCon{'-', Mag.show(m, SNil{})}
    case BigInt{False{}, m}:
      Mag.show(m, SNil{})

def BigInt.read.fin(neg: Bool, r: Bool & List<&2, U32>) -> Maybe<&2, BigInt>:
  (ok, ds) = r
  match ok ds:
    case True{} Nil{}:
      None{}
    case True{} s:
      Some{BigInt.mk(neg, Mag.norm(Mag.group(s)))}
    case False{} s:
      None{}

# An optional '-' and at least one ASCII digit; leading zeros are fine.
def BigInt.read(s: String) -> Maybe<&2, BigInt>:
  match s:
    case SCon{'-', t}:
      BigInt.read.fin(True{}, Mag.digits(t, True{}, Nil{}))
    case t:
      BigInt.read.fin(False{}, Mag.digits(t, True{}, Nil{}))
