# Text formatting: a string builder, format, padding, and shortest F32 printing.
import Base

# A builder holds its chunks newest first, so add is O(1) and build joins once.
type Builder is Data:
  Builder{rev: List<&2, String>}

def Builder.new() -> Builder:
  Builder{Nil{}}

def Builder.add(b: Builder, s: String) -> Builder:
  match b:
    case Builder{r}:
      Builder{s <> r}

def Builder.build(b: Builder) -> String:
  match b:
    case Builder{r}:
      String.concat(List.reverse(&2, String, r))

def Fmt.fill(n: Nat, +c: Char) -> String:
  String.repeat(SCon{c, SNil{}}, n)

# Pads s with c to w chars; a string at least w long stays as is.
def Fmt.pad_left(+s: String, w: Nat, +c: Char) -> String:
  String.append(Fmt.fill(Nat.sub(w, String.length(s)), c), s)

def Fmt.pad_right(+s: String, w: Nat, +c: Char) -> String:
  String.append(s, Fmt.fill(Nat.sub(w, String.length(s)), c))

def Fmt.center.go(+pad: Nat, s: String, +c: Char) -> String:
  +l = {Nat.div(pad, 2n) : Nat}
  Fmt.fill(l, c) ++ s ++ Fmt.fill(Nat.sub(pad, l), c)

# The odd pad char goes on the right.
def Fmt.center(+s: String, w: Nat, +c: Char) -> String:
  Fmt.center.go(Nat.sub(w, String.length(s)), s, c)

type Tok is Data:
  TChr{c: Char}
  THole{}
  TEnd{}

def Fmt.next.open.if(esc: Bool, hole: Bool, c: Char, u: String) ->
  Tok & String:
  match esc:
    case True{}:
      (TChr{'{'}, u)
    case False{}:
      match hole:
        case True{}:
          (THole{}, u)
        case False{}:
          (TChr{'{'}, SCon{c, u})

def Fmt.next.open(t: String) -> Tok & String:
  match t:
    case SNil{}:
      (TChr{'{'}, SNil{})
    case SCon{Chr{y}, u}:
      +c = {y : U32}
      Fmt.next.open.if(U32.is_eq(c, 123), U32.is_eq(c, 125), Chr{c}, u)

def Fmt.next.close.if(esc: Bool, c: Char, u: String) -> Tok & String:
  match esc:
    case True{}:
      (TChr{'}'}, u)
    case False{}:
      (TChr{'}'}, SCon{c, u})

def Fmt.next.close(t: String) -> Tok & String:
  match t:
    case SNil{}:
      (TChr{'}'}, SNil{})
    case SCon{Chr{y}, u}:
      +c = {y : U32}
      Fmt.next.close.if(U32.is_eq(c, 125), Chr{c}, u)

def Fmt.next.pick(open: Bool, close: Bool, c: Char, t: String) -> Tok & String:
  match open:
    case True{}:
      Fmt.next.open(t)
    case False{}:
      match close:
        case True{}:
          Fmt.next.close(t)
        case False{}:
          (TChr{c}, t)

def Fmt.next(s: String) -> Tok & String:
  match s:
    case SNil{}:
      (TEnd{}, SNil{})
    case SCon{Chr{x}, t}:
      +c = {x : U32}
      Fmt.next.pick(U32.is_eq(c, 123), U32.is_eq(c, 125), Chr{c}, t)

# Each token eats at least one char, so fuel f is the template length.
def Fmt.format.go(f: Nat, p: Tok & String, args: List<&2, String>) -> String:
  match f:
    case 0n:
      SNil{}
    case 1n+g:
      (tok, rest) = p
      match tok:
        case TEnd{}:
          SNil{}
        case TChr{c}:
          SCon{c, Fmt.format.go(g, Fmt.next(rest), args)}
        case THole{}:
          match args:
            case Nil{}:
              "{}" ++ Fmt.format.go(g, Fmt.next(rest), Nil{})
            case Con{a, more}:
              a ++ Fmt.format.go(g, Fmt.next(rest), more)

# "{}" takes the next argument, "{{" and "}}" print one brace, and a "{}"
# past the last argument prints as is.
def Fmt.format(+tpl: String, args: List<&2, String>) -> String:
  Fmt.format.go(String.length(tpl), Fmt.next(tpl), args)

# A Big is a fixed 14 limbs of 16 bits, least significant first: 224 bits.
def Big.zeros(n: Nat) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{0, Big.zeros(p)}

def Big.of(+x: U32) -> List<&2, U32>:
  Con{U32.and(x, 65535), Con{U32.shrn(x, 16n), Big.zeros(12n)}}

# m and c stay below 2^16, so a limb product fits a U32.
def Big.mul(a: List<&2, U32>, +m: U32, c: U32) -> List<&2, U32>:
  match a:
    case Nil{}:
      Nil{}
    case Con{x, xs}:
      +t = {U32.add(U32.mul(x, m), c) : U32}
      Con{U32.and(t, 65535), Big.mul(xs, m, U32.shrn(t, 16n))}

def Big.add(a: List<&2, U32>, b: List<&2, U32>, c: U32) -> List<&2, U32>:
  match a b:
    case Con{x, xs} Con{y, ys}:
      +t = {U32.add(U32.add(x, y), c) : U32}
      Con{U32.and(t, 65535), Big.add(xs, ys, U32.shrn(t, 16n))}
    case _ _:
      Nil{}

# a - b for a >= b; w is the borrow.
def Big.sub(a: List<&2, U32>, b: List<&2, U32>, w: U32) -> List<&2, U32>:
  match a b:
    case Con{x, xs} Con{y, ys}:
      +t = {U32.sub(U32.sub(U32.add(x, 65536), y), w) : U32}
      Con{U32.and(t, 65535), Big.sub(xs, ys, U32.sub(1, U32.shrn(t, 16n)))}
    case _ _:
      Nil{}

def Big.cmp.then(hi: Cmp, lo: Cmp) -> Cmp:
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
      Big.cmp.then(Big.cmp(xs, ys), U32.cmp(x, y))
    case _ _:
      EQ{}

def Big.shl(k: Nat, a: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      a
    case 1n+j:
      Big.shl(j, Big.mul(a, 2, 0))

# (q + t / s, t % s) for t < 10 s, by repeated subtraction.
def Big.divsmall(f: Nat, ge: Bool, +q: U32, +t: List<&2, U32>,
  +s: List<&2, U32>) -> U32 & List<&2, U32>:
  match f:
    case 0n:
      (q, t)
    case 1n+g:
      match ge:
        case False{}:
          (q, t)
        case True{}:
          +t2 = {Big.sub(t, s, 0) : List<&2, U32>}
          Big.divsmall(g, Cmp.is_ge(Big.cmp(t2, s)), U32.add(q, 1), t2, s)

# Burger and Dybvig's free-format digits: v = r / s, and the neighbours of
# v sit at (r - mm) / s and (r + mp) / s.
type St is Data:
  St{r: List<&2, U32>, s: List<&2, U32>, mp: List<&2, U32>,
    mm: List<&2, U32>}

type Dig is Data:
  More{d: U32, st: St}
  Last{d: U32}

# An even mantissa reads back from either bound, so the bounds count.
def Short.high(even: Bool, r: List<&2, U32>, mp: List<&2, U32>,
  s: List<&2, U32>) -> Bool:
  match even:
    case True{}:
      Cmp.is_ge(Big.cmp(Big.add(r, mp, 0), s))
    case False{}:
      Cmp.is_gt(Big.cmp(Big.add(r, mp, 0), s))

def Short.low(even: Bool, r: List<&2, U32>, mm: List<&2, U32>) -> Bool:
  match even:
    case True{}:
      Cmp.is_le(Big.cmp(r, mm))
    case False{}:
      Cmp.is_lt(Big.cmp(r, mm))

# A tie rounds to the even digit.
def Short.near(c: Cmp, +d: U32) -> U32:
  match c:
    case LT{}:
      d
    case GT{}:
      U32.add(d, 1)
    case EQ{}:
      U32.add(d, U32.and(d, 1))

def Short.pick(tc1: Bool, tc2: Bool, +d: U32, +r: List<&2, U32>,
  +s: List<&2, U32>, mp: List<&2, U32>, mm: List<&2, U32>) -> Dig:
  match tc1:
    case False{}:
      match tc2:
        case False{}:
          More{d, St{r, s, mp, mm}}
        case True{}:
          Last{U32.add(d, 1)}
    case True{}:
      match tc2:
        case False{}:
          Last{d}
        case True{}:
          Last{Short.near(Big.cmp(Big.mul(r, 2, 0), s), d)}

def Short.digit.fin(+even: Bool, qr: U32 & List<&2, U32>, +s: List<&2, U32>,
  +mp: List<&2, U32>, +mm: List<&2, U32>) -> Dig:
  (d, r) = qr
  +r1 = {r : List<&2, U32>}
  Short.pick(Short.low(even, r1, mm), Short.high(even, r1, mp, s), d, r1, s,
    mp, mm)

def Short.digit(+even: Bool, st: St) -> Dig:
  match st:
    case St{r, s, mp, mm}:
      +s1 = {s : List<&2, U32>}
      +r10 = {Big.mul(r, 10, 0) : List<&2, U32>}
      Short.digit.fin(even,
        Big.divsmall(10n, Cmp.is_ge(Big.cmp(r10, s1)), 0, r10, s1), s1,
        Big.mul(mp, 10, 0), Big.mul(mm, 10, 0))

def Short.gen(f: Nat, +even: Bool, o: Dig) -> List<&2, U32>:
  match f:
    case 0n:
      Nil{}
    case 1n+g:
      match o:
        case Last{d}:
          Con{d, Nil{}}
        case More{d, st}:
          Con{d, Short.gen(g, even, Short.digit(even, st))}

# k is the decimal exponent plus 64: v = 0.d1d2... * 10^(k - 64).
def Short.up(f: Nat, +even: Bool, big: Bool, st: St, +k: U32) -> St & U32:
  match f:
    case 0n:
      (st, k)
    case 1n+g:
      match big:
        case False{}:
          (st, k)
        case True{}:
          match st:
            case St{r, s, mp, mm}:
              +r1 = {r : List<&2, U32>}
              +mp1 = {mp : List<&2, U32>}
              +s10 = {Big.mul(s, 10, 0) : List<&2, U32>}
              Short.up(g, even, Short.high(even, r1, mp1, s10),
                St{r1, s10, mp1, mm}, U32.add(k, 1))

def Short.down(f: Nat, +even: Bool, small: Bool, st: St, +k: U32) ->
  St & U32:
  match f:
    case 0n:
      (st, k)
    case 1n+g:
      match small:
        case False{}:
          (st, k)
        case True{}:
          match st:
            case St{r, s, mp, mm}:
              +r10 = {Big.mul(r, 10, 0) : List<&2, U32>}
              +mp10 = {Big.mul(mp, 10, 0) : List<&2, U32>}
              +s1 = {s : List<&2, U32>}
              Short.down(g, even,
                Bool.not(Short.high(even, Big.mul(r10, 10, 0),
                  Big.mul(mp10, 10, 0), s1)),
                St{r10, s1, mp10, Big.mul(mm, 10, 0)}, U32.sub(k, 1))

def Short.fix.down(+even: Bool, sk: St & U32) -> St & U32:
  (st, k) = sk
  match st:
    case St{r, s, mp, mm}:
      +r1 = {r : List<&2, U32>}
      +s1 = {s : List<&2, U32>}
      +mp1 = {mp : List<&2, U32>}
      Short.down(64n, even,
        Bool.not(Short.high(even, Big.mul(r1, 10, 0), Big.mul(mp1, 10, 0), s1)),
        St{r1, s1, mp1, mm}, k)

def Short.fix(+even: Bool, st: St) -> St & U32:
  match st:
    case St{r, s, mp, mm}:
      +r1 = {r : List<&2, U32>}
      +s1 = {s : List<&2, U32>}
      +mp1 = {mp : List<&2, U32>}
      Short.fix.down(even,
        Short.up(64n, even, Short.high(even, r1, mp1, s1), St{r1, s1, mp1, mm},
          64))

def Short.chars(ds: List<&2, U32>) -> String:
  match ds:
    case Nil{}:
      SNil{}
    case Con{d, t}:
      SCon{Chr{U32.add(48, d)}, Short.chars(t)}

def Short.exp.if(small: Bool, +e: U32) -> String:
  match small:
    case True{}:
      SCon{'0', U32.show(e)}
    case False{}:
      U32.show(e)

def Short.exp(neg: Bool, +e: U32) -> String:
  match neg:
    case True{}:
      SCon{'-', Short.exp.if(U32.is_lt(e, 10), e)}
    case False{}:
      SCon{'+', Short.exp.if(U32.is_lt(e, 10), e)}

def Short.frac(ds: String) -> String:
  match ds:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{'.', SCon{h, t}}

def Short.sci(ds: String, +k: U32) -> String:
  match ds:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{h, Short.frac(t) ++ "e" ++
        Short.exp(U32.is_lt(k, 65), U32.sub(U32.max(k, 65), U32.min(k, 65)))}

def Short.fixed.big(ge: Bool, +ds: String, +kn: Nat) -> String:
  match ge:
    case True{}:
      ds ++ Fmt.fill(Nat.sub(kn, String.length(ds)), '0') ++ ".0"
    case False{}:
      String.take(ds, kn) ++ "." ++ String.drop(ds, kn)

def Short.fixed(pos: Bool, +ds: String, +k: U32) -> String:
  match pos:
    case True{}:
      +kn = {U32.to_nat(U32.sub(k, 64)) : Nat}
      Short.fixed.big(Nat.is_ge(kn, String.length(ds)), ds, kn)
    case False{}:
      "0." ++ Fmt.fill(U32.to_nat(U32.sub(64, k)), '0') ++ ds

def Short.show.if(sci: Bool, +ds: String, +k: U32) -> String:
  match sci:
    case True{}:
      Short.sci(ds, k)
    case False{}:
      Short.fixed(U32.is_gt(k, 64), ds, k)

# Like Python's repr: plain from 1e-4 up to 1e16, scientific outside.
def Short.show(ds: String, +k: U32) -> String:
  Short.show.if(Bool.or(U32.is_lt(k, 61), U32.is_ge(k, 81)), ds, k)

def Short.digits(+even: Bool, st: St) -> String:
  Short.chars(Short.gen(12n, even, Short.digit(even, st)))

def Short.finite.fin(+even: Bool, sk: St & U32) -> String:
  (st, k) = sk
  Short.show(Short.digits(even, st), k)

# v = f * 2^(be - 150); a power-of-two f above the least exponent has a
# nearer lower neighbour, so t = 1 there. A and B are the positive and
# negative parts of the binary exponent.
def Short.finite.go(+f: U32, +be: U32, t: Nat) -> String:
  +tt = {t : Nat}
  +a = {Nat.sub(U32.to_nat(be), 150n) : Nat}
  +b = {Nat.sub(150n, U32.to_nat(be)) : Nat}
  +even = {U32.is_zero(U32.and(f, 1)) : Bool}
  Short.finite.fin(even, Short.fix(even,
    St{Big.shl(Nat.add(Nat.add(a, 1n), tt), Big.of(f)),
      Big.shl(Nat.add(Nat.add(b, 1n), tt), Big.of(1)),
      Big.shl(Nat.add(a, tt), Big.of(1)), Big.shl(a, Big.of(1))}))

def Short.edge(e: Bool) -> Nat:
  match e:
    case True{}:
      1n
    case False{}:
      0n

def Short.finite(+ex: U32, +mant: U32) -> String:
  Short.finite.go(U32.or(mant, U32.shln(U32.min(ex, 1), 23n)), U32.max(ex, 1),
    Short.edge(Bool.and(U32.is_zero(mant), U32.is_gt(ex, 1))))

def Short.sign(neg: Bool, s: String) -> String:
  match neg:
    case True{}:
      SCon{'-', s}
    case False{}:
      s

def Short.special(inf: Bool, neg: Bool) -> String:
  match inf:
    case True{}:
      Short.sign(neg, "inf")
    case False{}:
      "nan"

def Short.go(inf: Bool, zero: Bool, +neg: Bool, +ex: U32, +mant: U32) ->
  String:
  match inf:
    case True{}:
      Short.special(U32.is_zero(mant), neg)
    case False{}:
      match zero:
        case True{}:
          Short.sign(neg, "0.0")
        case False{}:
          Short.sign(neg, Short.finite(ex, mant))

# Base's F32.bits does not reduce in the checker, so proofs could not run it.
def Short.bits(x: F32) -> U32:
  match x:
    case F32{w}:
      U32{w}

# The shortest decimal that reads back to x, with ".0" on whole numbers.
def F32.shortest(x: F32) -> String:
  +b = {Short.bits(x) : U32}
  +ex = {U32.and(U32.shrn(b, 23n), 255) : U32}
  +mant = {U32.and(b, 8388607) : U32}
  Short.go(U32.is_eq(ex, 255), Bool.and(U32.is_zero(ex), U32.is_zero(mant)),
    U32.is_ge(b, 2147483648), ex, mant)
