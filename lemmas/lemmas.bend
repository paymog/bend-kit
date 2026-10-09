# Proved laws that relate Word and U32 arithmetic to Nat. Source: https://github.com/paymog/bend-kit/tree/main/lemmas
import Base
import bend-mathlib@0.7.2.0/nat.bend as MNat

# 2^n, by the doubling that Word.to_nat uses.
def pow2(n: Nat) -> Nat:
  match n:
    case 0n:
      1n
    case 1n+p:
      Nat.double(pow2(p))

# The value of a word whose low bit is x and whose upper bits have value t.
def bit(x: Bool, t: Nat) -> Nat:
  match x:
    case False{}:
      Nat.double(t)
    case True{}:
      1n+Nat.double(t)

law to_nat_con:
  for -p: Nat
  for x: Bool
  for -t: Word(p)
  {bit(x, Word.to_nat(p, t)) == Word.to_nat(1n+p, WCon{x, t}) : Nat}

def to_nat_con(p, x, t):
  match x:
    case False{}:
      {==}
    case True{}:
      {==}

law cmp_bit:
  for a: Nat
  for b: Nat
  for x: Bool
  for y: Bool
  {Word.cmp.fin(x, y, Nat.cmp(a, b)) == Nat.cmp(bit(x, a), bit(y, b)) : Cmp}

def cmp_bit(a, b, x, y):
  match a b:
    case 0n 0n:
      match x y:
        case False{} False{}:
          {==}
        case False{} True{}:
          {==}
        case True{} False{}:
          {==}
        case True{} True{}:
          {==}
    case 0n 1n+q:
      match x y:
        case False{} False{}:
          {==}
        case False{} True{}:
          {==}
        case True{} False{}:
          {==}
        case True{} True{}:
          {==}
    case 1n+p 0n:
      match x y:
        case False{} False{}:
          {==}
        case False{} True{}:
          {==}
        case True{} False{}:
          {==}
        case True{} True{}:
          {==}
    case 1n+p 1n+q:
      match x y:
        case False{} False{}:
          cmp_bit(p, q, False{}, False{})
        case False{} True{}:
          cmp_bit(p, q, False{}, True{})
        case True{} False{}:
          cmp_bit(p, q, True{}, False{})
        case True{} True{}:
          cmp_bit(p, q, True{}, True{})

# Comparing two words compares their values.
law word_cmp_nat:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  {Word.cmp(n, a, b) == Nat.cmp(Word.to_nat(n, a), Word.to_nat(n, b)) : Cmp}

def word_cmp_nat(n, a, b):
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match a b:
        case WCon{+x, +at} WCon{+y, +bt}:
          %to_nat_con(p, x, at) : {Word.cmp.fin(x, y, Word.cmp(p, at, bt)) ==
            Nat.cmp(_, Word.to_nat(1n+p, WCon{y, bt})) : Cmp}
          %to_nat_con(p, y, bt) : {Word.cmp.fin(x, y, Word.cmp(p, at, bt)) ==
            Nat.cmp(bit(x, Word.to_nat(p, at)), _) : Cmp}
          %cmp_bit(Word.to_nat(p, at), Word.to_nat(p, bt), x, y) :
            {Word.cmp.fin(x, y, Word.cmp(p, at, bt)) == _ : Cmp}
          %word_cmp_nat(p, at, bt) : {Word.cmp.fin(x, y, Word.cmp(p, at, bt)) ==
            Word.cmp.fin(x, y, _) : Cmp}
          {==}

law u32_cmp_nat:
  for a: U32
  for b: U32
  {U32.cmp(a, b) == Nat.cmp(U32.to_nat(a), U32.to_nat(b)) : Cmp}

def u32_cmp_nat(a, b):
  match a b:
    case U32{x} U32{y}:
      word_cmp_nat(32n, x, y)

law u32_is_lt_nat:
  for a: U32
  for b: U32
  {U32.is_lt(a, b) == Nat.is_lt(U32.to_nat(a), U32.to_nat(b)) : Bool}

def u32_is_lt_nat(a, b):
  Equal.cong(Cmp, Bool, c => Cmp.is_lt(c), U32.cmp(a, b),
    Nat.cmp(U32.to_nat(a), U32.to_nat(b)), u32_cmp_nat(a, b))

law u32_is_le_nat:
  for a: U32
  for b: U32
  {U32.is_le(a, b) == Nat.is_le(U32.to_nat(a), U32.to_nat(b)) : Bool}

def u32_is_le_nat(a, b):
  Equal.cong(Cmp, Bool, c => Cmp.is_le(c), U32.cmp(a, b),
    Nat.cmp(U32.to_nat(a), U32.to_nat(b)), u32_cmp_nat(a, b))

law u32_is_eq_nat:
  for a: U32
  for b: U32
  {U32.is_eq(a, b) == Nat.is_eq(U32.to_nat(a), U32.to_nat(b)) : Bool}

def u32_is_eq_nat(a, b):
  Equal.cong(Cmp, Bool, c => Cmp.is_eq(c), U32.cmp(a, b),
    Nat.cmp(U32.to_nat(a), U32.to_nat(b)), u32_cmp_nat(a, b))

law odd_lt_double:
  for a: Nat
  for b: Nat
  for h: MNat.lt(a, b)
  MNat.lt(1n+Nat.double(a), Nat.double(b))

def odd_lt_double(a, b, h):
  match a b:
    case 0n 0n:
      Empty.absurd(MNat.lt(1n, 0n), MNat.lt_zero(0n)(h))
    case 0n 1n+q:
      {==}
    case 1n+p 0n:
      Empty.absurd(MNat.lt(1n+Nat.double(1n+p), 0n), MNat.lt_zero(1n+p)(h))
    case 1n+p 1n+q:
      odd_lt_double(p, q, h)

# A word of n bits has a value below 2^n.
law word_to_nat_lt:
  for n: Nat
  for w: Word(n)
  MNat.lt(Word.to_nat(n, w), pow2(n))

def word_to_nat_lt(n, w):
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{False{}, +t}:
          MNat.double_lt_double(Word.to_nat(p, t), pow2(p), word_to_nat_lt(p, t))
        case WCon{True{}, +t}:
          odd_lt_double(Word.to_nat(p, t), pow2(p), word_to_nat_lt(p, t))

law u32_to_nat_word:
  for -x: Word(32n)
  {Word.to_nat(32n, x) == U32.to_nat(U32{x}) : Nat}

def u32_to_nat_word(x):
  {==}

law u32_to_nat_lt:
  for a: U32
  MNat.lt(U32.to_nat(a), pow2(32n))

def u32_to_nat_lt(a):
  match a:
    case U32{+x}:
      # A conversion here expands pow2(32n) and overflows the checker stack (bendlang/bend#1071).
      %u32_to_nat_word(x) : MNat.lt(_, pow2(32n))
      word_to_nat_lt(32n, x)

law double_inj:
  for a: Nat
  for b: Nat
  for h: {Nat.double(a) == Nat.double(b) : Nat}
  {a == b : Nat}

def double_inj(a, b, h):
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+q:
      Empty.absurd({0n == 1n+q : Nat}, MNat.zero_ne_succ(1n+Nat.double(q))(h))
    case 1n+p 0n:
      Empty.absurd({1n+p == 0n : Nat}, MNat.succ_ne_zero(1n+Nat.double(p))(h))
    case 1n+p 1n+q:
      Equal.cong(Nat, Nat, k => 1n+k, p, q,
        double_inj(p, q, MNat.succ_inj(Nat.double(p), Nat.double(q),
          MNat.succ_inj(1n+Nat.double(p), 1n+Nat.double(q), h))))

law double_ne_odd:
  for a: Nat
  for b: Nat
  for h: {Nat.double(a) == 1n+Nat.double(b) : Nat}
  Empty

def double_ne_odd(a, b, h):
  match a b:
    case 0n 0n:
      MNat.zero_ne_succ(0n)(h)
    case 0n 1n+q:
      MNat.zero_ne_succ(2n+Nat.double(q))(h)
    case 1n+p 0n:
      MNat.succ_ne_zero(Nat.double(p))(MNat.succ_inj(1n+Nat.double(p), 0n, h))
    case 1n+p 1n+q:
      double_ne_odd(p, q, MNat.succ_inj(Nat.double(p), 1n+Nat.double(q),
        MNat.succ_inj(1n+Nat.double(p), 2n+Nat.double(q), h)))

# Two words with the same value are the same word.
law word_to_nat_inj:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for h: {Word.to_nat(n, a) == Word.to_nat(n, b) : Nat}
  {a == b : Word(n)}

def word_to_nat_inj(n, a, b, h):
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case 1n+ +p:
      match a b:
        case WCon{False{}, +at} WCon{False{}, +bt}:
          Equal.cong(Word(p), Word(1n+p), t => WCon{False{}, t}, at, bt,
            word_to_nat_inj(p, at, bt, double_inj(Word.to_nat(p, at), Word.to_nat(p, bt), h)))
        case WCon{True{}, +at} WCon{True{}, +bt}:
          Equal.cong(Word(p), Word(1n+p), t => WCon{True{}, t}, at, bt,
            word_to_nat_inj(p, at, bt, double_inj(Word.to_nat(p, at), Word.to_nat(p, bt),
              MNat.succ_inj(Nat.double(Word.to_nat(p, at)), Nat.double(Word.to_nat(p, bt)), h))))
        case WCon{False{}, +at} WCon{True{}, +bt}:
          Empty.absurd({WCon{False{}, at} == WCon{True{}, bt} : Word(1n+p)},
            double_ne_odd(Word.to_nat(p, at), Word.to_nat(p, bt), h))
        case WCon{True{}, +at} WCon{False{}, +bt}:
          Empty.absurd({WCon{True{}, at} == WCon{False{}, bt} : Word(1n+p)},
            double_ne_odd(Word.to_nat(p, bt), Word.to_nat(p, at),
              Equal.sym(Nat, 1n+Nat.double(Word.to_nat(p, at)), Nat.double(Word.to_nat(p, bt)), h)))

law u32_to_nat_inj:
  for a: U32
  for b: U32
  for h: {U32.to_nat(a) == U32.to_nat(b) : Nat}
  {a == b : U32}

def u32_to_nat_inj(a, b, h):
  match a b:
    case U32{+x} U32{+y}:
      Equal.cong(Word(32n), U32, w => U32{w}, x, y, word_to_nat_inj(32n, x, y, h))

def b2n(b: Bool) -> Nat:
  match b:
    case False{}:
      0n
    case True{}:
      1n

# m when q is set, else 0.
def scale(q: Bool, m: Nat) -> Nat:
  match q:
    case False{}:
      0n
    case True{}:
      m

# The carry out of a full adder: set when two or three of the bits are set.
def maj(x: Bool, y: Bool, c: Bool) -> Bool:
  match x y:
    case False{} False{}:
      False{}
    case True{} True{}:
      True{}
    case False{} True{}:
      c
    case True{} False{}:
      c

# The carry out of Word.adc(n, a, b, False{}, c): the bit that a + b + c overflows into.
def carry(n: Nat, a: Word(n), b: Word(n), c: Bool) -> Bool:
  match n:
    case 0n:
      c
    case 1n+p:
      match a b:
        case WCon{x, at} WCon{y, bt}:
          carry(p, at, bt, maj(x, y, c))

law scale_double:
  for q: Bool
  for -m: Nat
  {Nat.double(scale(q, m)) == scale(q, Nat.double(m)) : Nat}

def scale_double(q, m):
  match q:
    case False{}:
      {==}
    case True{}:
      {==}

# One bit of the adder: s + 2k is the sum c + x + y of the three input bits.
law adc_step:
  for +s: Nat
  for +x: Nat
  for +y: Nat
  for +c: Nat
  for +k: Nat
  for +r: Nat
  for +q: Bool
  for +m: Nat
  for +a: Nat
  for +b: Nat
  for ih: {Nat.add(r, scale(q, m)) == Nat.add(k, Nat.add(a, b)) : Nat}
  for fa: {Nat.add(c, Nat.add(x, y)) == Nat.add(s, Nat.double(k)) : Nat}
  {Nat.add(Nat.add(s, Nat.double(r)), scale(q, Nat.double(m))) == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}

def adc_step(s, x, y, c, k, r, q, m, a, b, ih, fa):
  %scale_double(q, m) : {Nat.add(Nat.add(s, Nat.double(r)), _) == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}
  %MNat.add_assoc_sym(s, Nat.double(r), Nat.double(scale(q, m))) : {_ == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}
  %MNat.double_add(r, scale(q, m)) : {Nat.add(s, _) == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}
  %Equal.sym(Nat, Nat.add(r, scale(q, m)), Nat.add(k, Nat.add(a, b)), ih) :
    {Nat.add(s, Nat.double(_)) == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}
  %MNat.double_add_sym(k, Nat.add(a, b)) : {Nat.add(s, _) == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}
  %MNat.double_add_sym(a, b) : {Nat.add(s, Nat.add(Nat.double(k), _)) == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}
  %MNat.add_assoc(s, Nat.double(k), Nat.add(Nat.double(a), Nat.double(b))) : {_ == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}
  %fa : {Nat.add(_, Nat.add(Nat.double(a), Nat.double(b))) == Nat.add(c, Nat.add(Nat.add(x, Nat.double(a)), Nat.add(y, Nat.double(b)))) : Nat}
  %MNat.add_add_add_comm(x, y, Nat.double(a), Nat.double(b)) : {Nat.add(Nat.add(c, Nat.add(x, y)), Nat.add(Nat.double(a), Nat.double(b))) == Nat.add(c, _) : Nat}
  %MNat.add_assoc(c, Nat.add(x, y), Nat.add(Nat.double(a), Nat.double(b))) : {Nat.add(Nat.add(c, Nat.add(x, y)), Nat.add(Nat.double(a), Nat.double(b))) == _ : Nat}
  {==}

# The adder is exact: the word sum plus the carry-out weight 2^n is c + a + b.
law word_adc_nat:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for c: Bool
  {Nat.add(Word.to_nat(n, Word.adc(n, a, b, False{}, c)),
    scale(carry(n, a, b, c), pow2(n))) ==
    Nat.add(b2n(c), Nat.add(Word.to_nat(n, a), Word.to_nat(n, b))) : Nat}

def word_adc_nat(n, a, b, c):
  match n:
    case 0n:
      match c:
        case False{}:
          {==}
        case True{}:
          {==}
    case 1n+ +p:
      match a b c:
        case WCon{False{}, +at} WCon{False{}, +bt} False{}:
          adc_step(0n, 0n, 0n, 0n, 0n,
            Word.to_nat(p, Word.adc(p, at, bt, False{}, False{})), carry(p, at, bt, False{}), pow2(p),
            Word.to_nat(p, at), Word.to_nat(p, bt), word_adc_nat(p, at, bt, False{}), {==})
        case WCon{False{}, +at} WCon{False{}, +bt} True{}:
          adc_step(1n, 0n, 0n, 1n, 0n,
            Word.to_nat(p, Word.adc(p, at, bt, False{}, False{})), carry(p, at, bt, False{}), pow2(p),
            Word.to_nat(p, at), Word.to_nat(p, bt), word_adc_nat(p, at, bt, False{}), {==})
        case WCon{False{}, +at} WCon{True{}, +bt} False{}:
          adc_step(1n, 0n, 1n, 0n, 0n,
            Word.to_nat(p, Word.adc(p, at, bt, False{}, False{})), carry(p, at, bt, False{}), pow2(p),
            Word.to_nat(p, at), Word.to_nat(p, bt), word_adc_nat(p, at, bt, False{}), {==})
        case WCon{False{}, +at} WCon{True{}, +bt} True{}:
          adc_step(0n, 0n, 1n, 1n, 1n,
            Word.to_nat(p, Word.adc(p, at, bt, False{}, True{})), carry(p, at, bt, True{}), pow2(p),
            Word.to_nat(p, at), Word.to_nat(p, bt), word_adc_nat(p, at, bt, True{}), {==})
        case WCon{True{}, +at} WCon{False{}, +bt} False{}:
          adc_step(1n, 1n, 0n, 0n, 0n,
            Word.to_nat(p, Word.adc(p, at, bt, False{}, False{})), carry(p, at, bt, False{}), pow2(p),
            Word.to_nat(p, at), Word.to_nat(p, bt), word_adc_nat(p, at, bt, False{}), {==})
        case WCon{True{}, +at} WCon{False{}, +bt} True{}:
          adc_step(0n, 1n, 0n, 1n, 1n,
            Word.to_nat(p, Word.adc(p, at, bt, False{}, True{})), carry(p, at, bt, True{}), pow2(p),
            Word.to_nat(p, at), Word.to_nat(p, bt), word_adc_nat(p, at, bt, True{}), {==})
        case WCon{True{}, +at} WCon{True{}, +bt} False{}:
          adc_step(0n, 1n, 1n, 0n, 1n,
            Word.to_nat(p, Word.adc(p, at, bt, False{}, True{})), carry(p, at, bt, True{}), pow2(p),
            Word.to_nat(p, at), Word.to_nat(p, bt), word_adc_nat(p, at, bt, True{}), {==})
        case WCon{True{}, +at} WCon{True{}, +bt} True{}:
          adc_step(1n, 1n, 1n, 1n, 1n,
            Word.to_nat(p, Word.adc(p, at, bt, False{}, True{})), carry(p, at, bt, True{}), pow2(p),
            Word.to_nat(p, at), Word.to_nat(p, bt), word_adc_nat(p, at, bt, True{}), {==})

# Moves a strict upper bound across an equation without a conversion check.
law lt_rw:
  for -a: Nat
  for -b: Nat
  for -c: Nat
  for e: {a == b : Nat}
  for h: MNat.lt(b, c)
  MNat.lt(a, c)

def lt_rw(a, b, c, e, h):
  %Equal.sym(Nat, a, b, e) : MNat.lt(_, c)
  h

law add_no_carry:
  for q: Bool
  for +r: Nat
  for +m: Nat
  for +s: Nat
  for e: {Nat.add(r, scale(q, m)) == s : Nat}
  for h: MNat.lt(s, m)
  {r == s : Nat}

def add_no_carry(q, r, m, s, e, h):
  match q:
    case False{}:
      Equal.trans(Nat, r, Nat.add(r, 0n), s, MNat.add_zero_sym(r), e)
    case True{}:
      Empty.absurd({r == s : Nat}, MNat.lt_irrefl(m)(MNat.lt_of_le_of_lt(m, Nat.add(r, m), m,
        MNat.le_add_left(m, r), lt_rw(Nat.add(r, m), s, m, e, h))))

law add_mod_carry:
  for q: Bool
  for +r: Nat
  for +m: Nat
  for +s: Nat
  for e: {Nat.add(r, scale(q, m)) == s : Nat}
  for h: MNat.lt(r, m)
  {r == Nat.mod(s, m) : Nat}

def add_mod_carry(q, r, m, s, e, h):
  match q:
    case False{}:
      %e : {r == Nat.mod(_, m) : Nat}
      %MNat.add_zero_sym(r) : {r == Nat.mod(_, m) : Nat}
      Equal.sym(Nat, Nat.mod(r, m), r, MNat.mod_eq_of_lt(r, m, h))
    case True{}:
      %e : {r == Nat.mod(_, m) : Nat}
      %MNat.add_comm(m, r) : {r == Nat.mod(_, m) : Nat}
      %MNat.add_mod_left_sym(r, m) : {r == _ : Nat}
      Equal.sym(Nat, Nat.mod(r, m), r, MNat.mod_eq_of_lt(r, m, h))

# Addition without overflow is exact.
law word_add_nat:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for h: MNat.lt(Nat.add(Word.to_nat(n, a), Word.to_nat(n, b)), pow2(n))
  {Word.to_nat(n, Word.add(n, a, b)) == Nat.add(Word.to_nat(n, a), Word.to_nat(n, b)) : Nat}

def word_add_nat(n, a, b, h):
  add_no_carry(carry(n, a, b, False{}), Word.to_nat(n, Word.adc(n, a, b, False{}, False{})), pow2(n),
    Nat.add(Word.to_nat(n, a), Word.to_nat(n, b)), word_adc_nat(n, a, b, False{}), h)

# Addition wraps modulo 2^n.
law word_add_mod:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  {Word.to_nat(n, Word.add(n, a, b)) ==
    Nat.mod(Nat.add(Word.to_nat(n, a), Word.to_nat(n, b)), pow2(n)) : Nat}

def word_add_mod(n, a, b):
  add_mod_carry(carry(n, a, b, False{}), Word.to_nat(n, Word.adc(n, a, b, False{}, False{})), pow2(n),
    Nat.add(Word.to_nat(n, a), Word.to_nat(n, b)), word_adc_nat(n, a, b, False{}),
    word_to_nat_lt(n, Word.adc(n, a, b, False{}, False{})))

law u32_add_word:
  for -x: Word(32n)
  for -y: Word(32n)
  {Word.to_nat(32n, Word.add(32n, x, y)) == U32.to_nat(U32.add(U32{x}, U32{y})) : Nat}

def u32_add_word(x, y):
  {==}

law u32_add_nat:
  for a: U32
  for b: U32
  for h: MNat.lt(Nat.add(U32.to_nat(a), U32.to_nat(b)), pow2(32n))
  {U32.to_nat(U32.add(a, b)) == Nat.add(U32.to_nat(a), U32.to_nat(b)) : Nat}

def u32_add_nat(a, b, h):
  match a b:
    case U32{+x} U32{+y}:
      word_add_nat(32n, x, y, lt_rw(Nat.add(Word.to_nat(32n, x), Word.to_nat(32n, y)),
        Nat.add(U32.to_nat(U32{x}), U32.to_nat(U32{y})), pow2(32n), {==}, h))

law u32_add_mod:
  for a: U32
  for b: U32
  {U32.to_nat(U32.add(a, b)) == Nat.mod(Nat.add(U32.to_nat(a), U32.to_nat(b)), pow2(32n)) : Nat}

def u32_add_mod(a, b):
  match a b:
    case U32{+x} U32{+y}:
      %u32_add_word(x, y) :
        {_ == Nat.mod(Nat.add(U32.to_nat(U32{x}), U32.to_nat(U32{y})), pow2(32n)) : Nat}
      %u32_to_nat_word(x) : {Word.to_nat(32n, Word.add(32n, x, y)) ==
        Nat.mod(Nat.add(_, U32.to_nat(U32{y})), pow2(32n)) : Nat}
      %u32_to_nat_word(y) : {Word.to_nat(32n, Word.add(32n, x, y)) ==
        Nat.mod(Nat.add(Word.to_nat(32n, x), _), pow2(32n)) : Nat}
      word_add_mod(32n, x, y)

# The bitwise complement of w has value 2^n - 1 - w.
law word_not_nat:
  for n: Nat
  for w: Word(n)
  {1n+Nat.add(Word.to_nat(n, Word.not(n, w)), Word.to_nat(n, w)) == pow2(n) : Nat}

def word_not_nat(n, w):
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{False{}, +t}:
          %word_not_nat(p, t) : {2n+Nat.add(Nat.double(Word.to_nat(p, Word.not(p, t))), Nat.double(Word.to_nat(p, t))) == Nat.double(_) : Nat}
          %MNat.double_add_sym(Word.to_nat(p, Word.not(p, t)), Word.to_nat(p, t)) : {2n+Nat.add(Nat.double(Word.to_nat(p, Word.not(p, t))), Nat.double(Word.to_nat(p, t))) == 2n+_ : Nat}
          {==}
        case WCon{True{}, +t}:
          %MNat.add_succ_sym(Nat.double(Word.to_nat(p, Word.not(p, t))), Nat.double(Word.to_nat(p, t))) : {1n+_ == pow2(1n+p) : Nat}
          %word_not_nat(p, t) : {2n+Nat.add(Nat.double(Word.to_nat(p, Word.not(p, t))), Nat.double(Word.to_nat(p, t))) == Nat.double(_) : Nat}
          %MNat.double_add_sym(Word.to_nat(p, Word.not(p, t)), Word.to_nat(p, t)) : {2n+Nat.add(Nat.double(Word.to_nat(p, Word.not(p, t))), Nat.double(Word.to_nat(p, t))) == 2n+_ : Nat}
          {==}

# Subtraction is addition of the complement with a carry in.
law word_sub_not:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  for +c: Bool
  {Word.adc(n, a, b, True{}, c) == Word.adc(n, a, Word.not(n, b), False{}, c) : Word(n)}

def word_sub_not(n, a, b, c):
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match a b:
        case WCon{False{}, +at} WCon{+y, +bt}:
          Equal.cong(Word(p), Word(1n+p), w => WCon{Bool.xor(Bool.not(y), c), w},
            Word.adc(p, at, bt, True{}, Bool.and(Bool.not(y), c)),
            Word.adc(p, at, Word.not(p, bt), False{}, Bool.and(Bool.not(y), c)),
            word_sub_not(p, at, bt, Bool.and(Bool.not(y), c)))
        case WCon{True{}, +at} WCon{+y, +bt}:
          Equal.cong(Word(p), Word(1n+p), w => WCon{Bool.not(Bool.xor(Bool.not(y), c)), w},
            Word.adc(p, at, bt, True{}, Bool.or(Bool.not(y), c)),
            Word.adc(p, at, Word.not(p, bt), False{}, Bool.or(Bool.not(y), c)),
            word_sub_not(p, at, bt, Bool.or(Bool.not(y), c)))

law sub_arith:
  for +a: Nat
  for +b: Nat
  for +nb: Nat
  for +m: Nat
  for h: MNat.le(b, a)
  for hn: {1n+Nat.add(nb, b) == m : Nat}
  {1n+Nat.add(a, nb) == Nat.add(Nat.sub(a, b), m) : Nat}

def sub_arith(a, b, nb, m, h, hn):
  %hn : {1n+Nat.add(a, nb) == Nat.add(Nat.sub(a, b), _) : Nat}
  %MNat.add_succ_sym(Nat.sub(a, b), Nat.add(nb, b)) : {1n+Nat.add(a, nb) == _ : Nat}
  %MNat.sub_add_cancel(a, b, h) : {1n+Nat.add(_, nb) == 1n+Nat.add(Nat.sub(a, b), Nat.add(nb, b)) : Nat}
  %MNat.add_assoc_sym(Nat.sub(a, b), b, nb) : {1n+_ == 1n+Nat.add(Nat.sub(a, b), Nat.add(nb, b)) : Nat}
  %MNat.add_comm(nb, b) : {1n+Nat.add(Nat.sub(a, b), _) == 1n+Nat.add(Nat.sub(a, b), Nat.add(nb, b)) : Nat}
  {==}

law sub_fin:
  for q: Bool
  for +r: Nat
  for +d: Nat
  for +m: Nat
  for e: {Nat.add(r, scale(q, m)) == Nat.add(d, m) : Nat}
  for h: MNat.lt(r, m)
  {r == d : Nat}

def sub_fin(q, r, d, m, e, h):
  match q:
    case False{}:
      Empty.absurd({r == d : Nat}, MNat.lt_irrefl(m)(MNat.lt_of_le_of_lt(m, Nat.add(d, m), m,
        MNat.le_add_left(m, d), lt_rw(Nat.add(d, m), r, m,
          Equal.sym(Nat, r, Nat.add(d, m),
            Equal.trans(Nat, r, Nat.add(r, 0n), Nat.add(d, m), MNat.add_zero_sym(r), e)), h))))
    case True{}:
      MNat.add_right_cancel(r, m, d, e)

# Subtraction without wrap is exact.
law word_sub_nat:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for h: MNat.le(Word.to_nat(n, b), Word.to_nat(n, a))
  {Word.to_nat(n, Word.sub(n, a, b)) == Nat.sub(Word.to_nat(n, a), Word.to_nat(n, b)) : Nat}

def word_sub_nat(n, a, b, h):
  %Equal.sym(Word(n), Word.adc(n, a, b, True{}, True{}),
    Word.adc(n, a, Word.not(n, b), False{}, True{}), word_sub_not(n, a, b, True{})) :
    {Word.to_nat(n, _) == Nat.sub(Word.to_nat(n, a), Word.to_nat(n, b)) : Nat}
  sub_fin(carry(n, a, Word.not(n, b), True{}),
    Word.to_nat(n, Word.adc(n, a, Word.not(n, b), False{}, True{})),
    Nat.sub(Word.to_nat(n, a), Word.to_nat(n, b)), pow2(n),
    Equal.trans(Nat,
      Nat.add(Word.to_nat(n, Word.adc(n, a, Word.not(n, b), False{}, True{})),
        scale(carry(n, a, Word.not(n, b), True{}), pow2(n))),
      1n+Nat.add(Word.to_nat(n, a), Word.to_nat(n, Word.not(n, b))),
      Nat.add(Nat.sub(Word.to_nat(n, a), Word.to_nat(n, b)), pow2(n)),
      word_adc_nat(n, a, Word.not(n, b), True{}),
      sub_arith(Word.to_nat(n, a), Word.to_nat(n, b), Word.to_nat(n, Word.not(n, b)), pow2(n), h,
        word_not_nat(n, b))),
    word_to_nat_lt(n, Word.adc(n, a, Word.not(n, b), False{}, True{})))

law u32_sub_nat:
  for a: U32
  for b: U32
  for h: MNat.le(U32.to_nat(b), U32.to_nat(a))
  {U32.to_nat(U32.sub(a, b)) == Nat.sub(U32.to_nat(a), U32.to_nat(b)) : Nat}

def u32_sub_nat(a, b, h):
  match a b:
    case U32{x} U32{y}:
      word_sub_nat(32n, x, y, h)

law lt_of_double_lt:
  for a: Nat
  for b: Nat
  for h: MNat.lt(Nat.double(a), Nat.double(b))
  MNat.lt(a, b)

def lt_of_double_lt(a, b, h):
  match a b:
    case 0n 0n:
      Empty.absurd(MNat.lt(0n, 0n), MNat.lt_zero(0n)(h))
    case 1n+p 0n:
      Empty.absurd(MNat.lt(1n+p, 0n), MNat.lt_zero(2n+Nat.double(p))(h))
    case 0n 1n+q:
      {==}
    case 1n+p 1n+q:
      lt_of_double_lt(p, q, h)

# Incrementing without overflow adds one.
law word_inc_nat:
  for n: Nat
  for w: Word(n)
  for h: MNat.lt(1n+Word.to_nat(n, w), pow2(n))
  {Word.to_nat(n, Word.inc(n, w)) == 1n+Word.to_nat(n, w) : Nat}

def word_inc_nat(n, w, h):
  match n:
    case 0n:
      Empty.absurd({0n == 1n : Nat}, MNat.lt_irrefl(1n)(h))
    case 1n+ +p:
      match w:
        case WCon{False{}, t}:
          {==}
        case WCon{True{}, +t}:
          Equal.cong(Nat, Nat, v => Nat.double(v), Word.to_nat(p, Word.inc(p, t)),
            1n+Word.to_nat(p, t),
            word_inc_nat(p, t, lt_of_double_lt(1n+Word.to_nat(p, t), pow2(p), h)))

law u32_inc_nat:
  for a: U32
  for h: MNat.lt(1n+U32.to_nat(a), pow2(32n))
  {U32.to_nat(U32.inc(a)) == 1n+U32.to_nat(a) : Nat}

def u32_inc_nat(a, h):
  match a:
    case U32{+x}:
      word_inc_nat(32n, x, lt_rw(1n+Word.to_nat(32n, x), 1n+U32.to_nat(U32{x}), pow2(32n), {==}, h))

law u32_to_from_nat:
  for k: Nat
  for +h: MNat.lt(k, pow2(32n))
  {U32.to_nat(U32.from_nat(k)) == k : Nat}

def u32_to_from_nat(k, h):
  match k:
    case 0n:
      {==}
    case 1n+ +j:
      +ih = u32_to_from_nat(j, MNat.lt_trans(j, 1n+j, pow2(32n), MNat.lt_succ_self(j), h))
      Equal.trans(Nat, U32.to_nat(U32.inc(U32.from_nat(j))), 1n+U32.to_nat(U32.from_nat(j)), 1n+j,
        u32_inc_nat(U32.from_nat(j), lt_rw(1n+U32.to_nat(U32.from_nat(j)), 1n+j, pow2(32n),
          Equal.cong(Nat, Nat, v => 1n+v, U32.to_nat(U32.from_nat(j)), j, ih), h)),
        Equal.cong(Nat, Nat, v => 1n+v, U32.to_nat(U32.from_nat(j)), j, ih))

law u32_from_to_nat:
  for +a: U32
  {U32.from_nat(U32.to_nat(a)) == a : U32}

def u32_from_to_nat(a):
  u32_to_nat_inj(U32.from_nat(U32.to_nat(a)), a, u32_to_from_nat(U32.to_nat(a), u32_to_nat_lt(a)))

law and_le_sub:
  for c: Bool
  for +a: Nat
  for +b: Nat
  for +l: Nat
  for -s: Nat
  for +hc: {Nat.is_le(a, l) == c : Bool}
  for hs: MNat.le(a, l) -> {s == Nat.sub(l, a) : Nat}
  {Bool.and(c, Nat.is_le(b, s)) == Nat.is_le(Nat.add(a, b), l) : Bool}

def and_le_sub(c, a, b, l, s, hc, hs):
  match c:
    case True{}:
      %Equal.sym(Nat, s, Nat.sub(l, a), hs(hc)) :
        {Bool.and(True{}, Nat.is_le(b, _)) == Nat.is_le(Nat.add(a, b), l) : Bool}
      %hc : {Bool.and(_, Nat.is_le(b, Nat.sub(l, a))) == Nat.is_le(Nat.add(a, b), l) : Bool}
      MNat.le_and_le_sub_iff_add_le(a, b, l)
    case False{}:
      %MNat.le_and_le_sub_iff_add_le(a, b, l) : {Bool.and(False{}, Nat.is_le(b, s)) == _ : Bool}
      %Equal.sym(Bool, Nat.is_le(a, l), False{}, hc) :
        {Bool.and(False{}, Nat.is_le(b, s)) == Bool.and(_, Nat.is_le(b, Nat.sub(l, a))) : Bool}
      {==}

# The overflow-safe bounds check n <= len and i <= len - n holds exactly when i + n <= len.
law u32_fits_nat:
  for +len: U32
  for +i: U32
  for +n: U32
  {Bool.and(U32.is_le(n, len), U32.is_le(i, U32.sub(len, n))) == Nat.is_le(Nat.add(U32.to_nat(i), U32.to_nat(n)), U32.to_nat(len)) : Bool}

def u32_fits_nat(len, i, n):
  %Equal.sym(Bool, U32.is_le(n, len), Nat.is_le(U32.to_nat(n), U32.to_nat(len)), u32_is_le_nat(n, len)) :
    {Bool.and(_, U32.is_le(i, U32.sub(len, n))) == Nat.is_le(Nat.add(U32.to_nat(i), U32.to_nat(n)), U32.to_nat(len)) : Bool}
  %Equal.sym(Bool, U32.is_le(i, U32.sub(len, n)), Nat.is_le(U32.to_nat(i), U32.to_nat(U32.sub(len, n))), u32_is_le_nat(i, U32.sub(len, n))) :
    {Bool.and(Nat.is_le(U32.to_nat(n), U32.to_nat(len)), _) == Nat.is_le(Nat.add(U32.to_nat(i), U32.to_nat(n)), U32.to_nat(len)) : Bool}
  %MNat.add_comm(U32.to_nat(n), U32.to_nat(i)) :
    {Bool.and(Nat.is_le(U32.to_nat(n), U32.to_nat(len)), Nat.is_le(U32.to_nat(i), U32.to_nat(U32.sub(len, n)))) == Nat.is_le(_, U32.to_nat(len)) : Bool}
  and_le_sub(Nat.is_le(U32.to_nat(n), U32.to_nat(len)), U32.to_nat(n), U32.to_nat(i), U32.to_nat(len), U32.to_nat(U32.sub(len, n)), {==}, h => u32_sub_nat(len, n, h))
