# Proved laws that relate Word and U32 arithmetic to Nat. Source: https://github.com/paymog/bend-kit/tree/main/lemmas
import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/u32.bend as MU32
import bend-mathlib@0.8.0.0/bool.bend as MBool

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
  MU32.word_cmp_to_nat(n, a, b)

law u32_cmp_nat:
  for a: U32
  for b: U32
  {U32.cmp(a, b) == Nat.cmp(U32.to_nat(a), U32.to_nat(b)) : Cmp}

def u32_cmp_nat(a, b):
  MU32.u32_cmp_to_nat(a, b)

law u32_is_lt_nat:
  for a: U32
  for b: U32
  {U32.is_lt(a, b) == Nat.is_lt(U32.to_nat(a), U32.to_nat(b)) : Bool}

def u32_is_lt_nat(a, b):
  MU32.u32_is_lt_to_nat(a, b)

law u32_is_le_nat:
  for a: U32
  for b: U32
  {U32.is_le(a, b) == Nat.is_le(U32.to_nat(a), U32.to_nat(b)) : Bool}

def u32_is_le_nat(a, b):
  MU32.u32_is_le_to_nat(a, b)

law u32_is_eq_nat:
  for a: U32
  for b: U32
  {U32.is_eq(a, b) == Nat.is_eq(U32.to_nat(a), U32.to_nat(b)) : Bool}

def u32_is_eq_nat(a, b):
  MU32.u32_is_eq_to_nat(a, b)

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
  MNat.double_inj(a, b, h)

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
  MU32.word_to_nat_inj(n, a, b, h)

law u32_to_nat_inj:
  for a: U32
  for b: U32
  for h: {U32.to_nat(a) == U32.to_nat(b) : Nat}
  {a == b : U32}

def u32_to_nat_inj(a, b, h):
  MU32.u32_to_nat_inj(a, b, h)

def u32_max_nat(+a: U32, +b: U32) -> {U32.to_nat(U32.max(a, b)) == Nat.max(U32.to_nat(a), U32.to_nat(b)) : Nat}:
  MU32.u32_max_to_nat(a, b)

def u32_max_nat_sym(+a: U32, +b: U32) -> {Nat.max(U32.to_nat(a), U32.to_nat(b)) == U32.to_nat(U32.max(a, b)) : Nat}:
  MU32.u32_max_to_nat_sym(a, b)

def u32_max_comm(+a: U32, +b: U32) -> {U32.max(a, b) == U32.max(b, a) : U32}:
  u32_to_nat_inj(U32.max(a, b), U32.max(b, a),
    %u32_max_nat_sym(a, b) : {_ == U32.to_nat(U32.max(b, a)) : Nat}
    %u32_max_nat_sym(b, a) : {Nat.max(U32.to_nat(a), U32.to_nat(b)) == _ : Nat}
    MNat.max_comm(U32.to_nat(a), U32.to_nat(b)))

def u32_max_assoc(+a: U32, +b: U32, +c: U32) -> {U32.max(U32.max(a, b), c) == U32.max(a, U32.max(b, c)) : U32}:
  u32_to_nat_inj(U32.max(U32.max(a, b), c), U32.max(a, U32.max(b, c)),
    %u32_max_nat_sym(U32.max(a, b), c) : {_ == U32.to_nat(U32.max(a, U32.max(b, c))) : Nat}
    %u32_max_nat_sym(a, b) : {Nat.max(_, U32.to_nat(c)) == U32.to_nat(U32.max(a, U32.max(b, c))) : Nat}
    %u32_max_nat_sym(a, U32.max(b, c)) : {Nat.max(Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(c)) == _ : Nat}
    %u32_max_nat_sym(b, c) : {Nat.max(Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(c)) == Nat.max(U32.to_nat(a), _) : Nat}
    MNat.max_assoc(U32.to_nat(a), U32.to_nat(b), U32.to_nat(c)))

def u32_max_self(+a: U32) -> {U32.max(a, a) == a : U32}:
  u32_to_nat_inj(U32.max(a, a), a,
    %u32_max_nat_sym(a, a) : {_ == U32.to_nat(a) : Nat}
    MNat.max_self(U32.to_nat(a)))

def u32_le_nat_sym(+a: U32, +b: U32) -> {Nat.is_le(U32.to_nat(a), U32.to_nat(b)) == U32.is_le(a, b) : Bool}:
  Equal.sym(Bool, U32.is_le(a, b), Nat.is_le(U32.to_nat(a), U32.to_nat(b)), u32_is_le_nat(a, b))

def u32_le_max_l(+a: U32, +b: U32) -> {U32.is_le(a, U32.max(a, b)) == True{} : Bool}:
  %u32_le_nat_sym(a, U32.max(a, b)) : {_ == True{} : Bool}
  %u32_max_nat_sym(a, b) : {Nat.is_le(U32.to_nat(a), _) == True{} : Bool}
  MNat.le_max_left(U32.to_nat(a), U32.to_nat(b))

def u32_le_max_r(+a: U32, +b: U32) -> {U32.is_le(b, U32.max(a, b)) == True{} : Bool}:
  %u32_le_nat_sym(b, U32.max(a, b)) : {_ == True{} : Bool}
  %u32_max_nat_sym(a, b) : {Nat.is_le(U32.to_nat(b), _) == True{} : Bool}
  MNat.le_max_right(U32.to_nat(a), U32.to_nat(b))

def u32_max_le(
  +a: U32, +b: U32, +c: U32,
  ha: {U32.is_le(a, c) == True{} : Bool}, hb: {U32.is_le(b, c) == True{} : Bool}
) -> {U32.is_le(U32.max(a, b), c) == True{} : Bool}:
  %u32_le_nat_sym(U32.max(a, b), c) : {_ == True{} : Bool}
  %u32_max_nat_sym(a, b) : {Nat.is_le(_, U32.to_nat(c)) == True{} : Bool}
  %Equal.sym(Bool, Nat.is_le(Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(c)),
    Bool.and(Nat.is_le(U32.to_nat(a), U32.to_nat(c)), Nat.is_le(U32.to_nat(b), U32.to_nat(c))),
    MNat.max_le(U32.to_nat(a), U32.to_nat(b), U32.to_nat(c))) : {_ == True{} : Bool}
  %u32_is_le_nat(a, c) : {Bool.and(_, Nat.is_le(U32.to_nat(b), U32.to_nat(c))) == True{} : Bool}
  %u32_is_le_nat(b, c) : {Bool.and(U32.is_le(a, c), _) == True{} : Bool}
  MBool.and_eq_true(U32.is_le(a, c), U32.is_le(b, c), ha, hb)

def u32_cmp_nat_sym(+a: U32, +b: U32) -> {Nat.cmp(U32.to_nat(a), U32.to_nat(b)) == U32.cmp(a, b) : Cmp}:
  Equal.sym(Cmp, U32.cmp(a, b), Nat.cmp(U32.to_nat(a), U32.to_nat(b)), u32_cmp_nat(a, b))

def max_ne0_nat(
  n: Nat, +m: Nat, h: {Bool.not(Cmp.is_eq(Nat.cmp(n, 0n))) == True{} : Bool}
) -> {Bool.not(Cmp.is_eq(Nat.cmp(Nat.max(n, m), 0n))) == True{} : Bool}:
  match n m:
    case 0n _:
      Empty.absurd({Bool.not(Cmp.is_eq(Nat.cmp(Nat.max(0n, m), 0n))) == True{} : Bool}, MBool.false_ne_true()(h))
    case 1n+p 0n:
      {==}
    case 1n+p 1n+q:
      {==}

def eq0_le_nat(n: Nat) -> {Cmp.is_eq(Nat.cmp(n, 0n)) == Cmp.is_le(Nat.cmp(n, 0n)) : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

def u32_eq0_le(+x: U32) -> {U32.is_eq(x, 0) == U32.is_le(x, 0) : Bool}:
  %u32_cmp_nat_sym(x, 0) : {Cmp.is_eq(_) == Cmp.is_le(_) : Bool}
  eq0_le_nat(U32.to_nat(x))

def u32_eq0_to_le(+x: U32, h: {U32.is_eq(x, 0) == True{} : Bool}) -> {U32.is_le(x, 0) == True{} : Bool}:
  Equal.trans(Bool, U32.is_le(x, 0), U32.is_eq(x, 0), True{},
    Equal.sym(Bool, U32.is_eq(x, 0), U32.is_le(x, 0), u32_eq0_le(x)), h)

def u32_max_eq0(
  +x: U32, +y: U32, hx: {U32.is_eq(x, 0) == True{} : Bool}, hy: {U32.is_eq(y, 0) == True{} : Bool}
) -> {U32.is_eq(U32.max(x, y), 0) == True{} : Bool}:
  Equal.trans(Bool, U32.is_eq(U32.max(x, y), 0), U32.is_le(U32.max(x, y), 0), True{},
    u32_eq0_le(U32.max(x, y)), u32_max_le(x, y, 0, u32_eq0_to_le(x, hx), u32_eq0_to_le(y, hy)))

def u32_ne0_max(
  +x: U32, +y: U32, h: {U32.is_ne(x, 0) == True{} : Bool}
) -> {U32.is_ne(U32.max(x, y), 0) == True{} : Bool}:
  %u32_cmp_nat_sym(U32.max(x, y), 0) : {Bool.not(Cmp.is_eq(_)) == True{} : Bool}
  %u32_max_nat_sym(x, y) : {Bool.not(Cmp.is_eq(Nat.cmp(_, U32.to_nat(0)))) == True{} : Bool}
  max_ne0_nat(U32.to_nat(x), U32.to_nat(y),
    Equal.trans(Bool, Bool.not(Cmp.is_eq(Nat.cmp(U32.to_nat(x), U32.to_nat(0)))), U32.is_ne(x, 0), True{},
      Equal.cong(Cmp, Bool, k => Bool.not(Cmp.is_eq(k)), Nat.cmp(U32.to_nat(x), U32.to_nat(0)), U32.cmp(x, 0),
        u32_cmp_nat_sym(x, 0)), h))

def u32_max0_r(+a: U32) -> {U32.max(a, 0) == a : U32}:
  u32_to_nat_inj(U32.max(a, 0), a,
    %u32_max_nat_sym(a, 0) : {_ == U32.to_nat(a) : Nat}
    MNat.max_zero(U32.to_nat(a)))

def u32_max0_l(+a: U32) -> {U32.max(0, a) == a : U32}:
  Equal.trans(U32, U32.max(0, a), U32.max(a, 0), a, u32_max_comm(0, a), u32_max0_r(a))

def u32_max_left_comm(+p: U32, +a: U32, +t: U32) -> {U32.max(p, U32.max(a, t)) == U32.max(a, U32.max(p, t)) : U32}:
  Equal.trans(U32, U32.max(p, U32.max(a, t)), U32.max(U32.max(p, a), t), U32.max(a, U32.max(p, t)),
    Equal.sym(U32, U32.max(U32.max(p, a), t), U32.max(p, U32.max(a, t)), u32_max_assoc(p, a, t)),
    Equal.trans(U32, U32.max(U32.max(p, a), t), U32.max(U32.max(a, p), t), U32.max(a, U32.max(p, t)),
      Equal.cong(U32, U32, z => U32.max(z, t), U32.max(p, a), U32.max(a, p), u32_max_comm(p, a)),
      u32_max_assoc(a, p, t)))

def u32_max_four(+p: U32, +q: U32, +r: U32, +t: U32) -> {U32.max(U32.max(p, q), U32.max(r, t)) == U32.max(U32.max(p, r), U32.max(q, t)) : U32}:
  Equal.trans(U32, U32.max(U32.max(p, q), U32.max(r, t)), U32.max(p, U32.max(q, U32.max(r, t))),
    U32.max(U32.max(p, r), U32.max(q, t)),
    u32_max_assoc(p, q, U32.max(r, t)),
    Equal.trans(U32, U32.max(p, U32.max(q, U32.max(r, t))), U32.max(p, U32.max(r, U32.max(q, t))),
      U32.max(U32.max(p, r), U32.max(q, t)),
      Equal.cong(U32, U32, z => U32.max(p, z), U32.max(q, U32.max(r, t)), U32.max(r, U32.max(q, t)), u32_max_left_comm(q, r, t)),
      Equal.sym(U32, U32.max(U32.max(p, r), U32.max(q, t)), U32.max(p, U32.max(r, U32.max(q, t))),
        u32_max_assoc(p, r, U32.max(q, t)))))

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
  MU32.word_sub_exact(n, a, b, h)

law u32_sub_nat:
  for a: U32
  for b: U32
  for h: MNat.le(U32.to_nat(b), U32.to_nat(a))
  {U32.to_nat(U32.sub(a, b)) == Nat.sub(U32.to_nat(a), U32.to_nat(b)) : Nat}

def u32_sub_nat(a, b, h):
  MU32.u32_sub_exact(a, b, h)

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
  MU32.u32_from_nat_to_nat(a)

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

def shl_carry(n: Nat, c: Bool, w: Word(n)) -> Bool:
  match n:
    case 0n:
      c
    case 1n+p:
      match w:
        case WCon{b, t}:
          shl_carry(p, b, t)

law bit_add_scale:
  for c: Bool
  for +r: Nat
  for +t: Bool
  for +m: Nat
  {Nat.add(bit(c, r), scale(t, Nat.double(m))) == bit(c, Nat.add(r, scale(t, m))) : Nat}

def bit_add_scale(c, r, t, m):
  match c:
    case False{}:
      %scale_double(t, m) : {Nat.add(Nat.double(r), _) == Nat.double(Nat.add(r, scale(t, m))) : Nat}
      MNat.double_add_sym(r, scale(t, m))
    case True{}:
      %scale_double(t, m) : {1n+Nat.add(Nat.double(r), _) == 1n+Nat.double(Nat.add(r, scale(t, m))) : Nat}
      Equal.cong(Nat, Nat, v => 1n+v,
        Nat.add(Nat.double(r), Nat.double(scale(t, m))), Nat.double(Nat.add(r, scale(t, m))),
        MNat.double_add_sym(r, scale(t, m)))

law bit_nat:
  for c: Bool
  for -v: Nat
  {bit(c, v) == Nat.add(b2n(c), Nat.double(v)) : Nat}

def bit_nat(c, v):
  match c:
    case False{}:
      {==}
    case True{}:
      {==}

law word_shl_put_nat:
  for +n: Nat
  for +c: Bool
  for +w: Word(n)
  {Nat.add(Word.to_nat(n, Word.shl.put(n, c, w)), scale(shl_carry(n, c, w), pow2(n))) ==
    bit(c, Word.to_nat(n, w)) : Nat}

def word_shl_put_nat(n, c, w):
  match n:
    case 0n:
      match c:
        case False{}:
          {==}
        case True{}:
          {==}
    case 1n+ +p:
      match w:
        case WCon{+b, +t}:
          %to_nat_con(p, c, Word.shl.put(p, b, t)) :
            {Nat.add(_, scale(shl_carry(p, b, t), pow2(1n+p))) == bit(c, Word.to_nat(1n+p, WCon{b, t})) : Nat}
          %Equal.sym(Nat,
            Nat.add(bit(c, Word.to_nat(p, Word.shl.put(p, b, t))), scale(shl_carry(p, b, t), Nat.double(pow2(p)))),
            bit(c, Nat.add(Word.to_nat(p, Word.shl.put(p, b, t)), scale(shl_carry(p, b, t), pow2(p)))),
            bit_add_scale(c, Word.to_nat(p, Word.shl.put(p, b, t)), shl_carry(p, b, t), pow2(p))) :
            {_ == bit(c, Word.to_nat(1n+p, WCon{b, t})) : Nat}
          %Equal.sym(Nat, Nat.add(Word.to_nat(p, Word.shl.put(p, b, t)), scale(shl_carry(p, b, t), pow2(p))),
            bit(b, Word.to_nat(p, t)), word_shl_put_nat(p, b, t)) :
            {bit(c, _) == bit(c, Word.to_nat(1n+p, WCon{b, t})) : Nat}
          Equal.cong(Nat, Nat, v => bit(c, v), bit(b, Word.to_nat(p, t)),
            Word.to_nat(1n+p, WCon{b, t}), to_nat_con(p, b, t))

law word_shl_out_put:
  for +n: Nat
  for +c: Bool
  for +w: Word(n)
  {Word.shl.out(n, c, w) == (shl_carry(n, c, w), Word.shl.put(n, c, w)) : Bool & Word(n)}

def word_shl_out_put(n, c, w):
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{+b, +t}:
          %Equal.sym(Bool & Word(p), Word.shl.out(p, b, t),
            (shl_carry(p, b, t), Word.shl.put(p, b, t)), word_shl_out_put(p, b, t)) :
            {Word.shl.out.con(p, c, _) == (shl_carry(p, b, t), WCon{c, Word.shl.put(p, b, t)}) : Bool & Word(1n+p)}
          {==}

def shl_value(+n: Nat, tw: Bool & Word(n)) -> Nat:
  (t, w) = tw
  Nat.add(Word.to_nat(n, w), scale(t, pow2(n)))

law word_shl_out_nat:
  for +n: Nat
  for +c: Bool
  for +w: Word(n)
  {shl_value(n, Word.shl.out(n, c, w)) == Nat.add(b2n(c), Nat.double(Word.to_nat(n, w))) : Nat}

def word_shl_out_nat(n, c, w):
  %Equal.sym(Bool & Word(n), Word.shl.out(n, c, w),
    (shl_carry(n, c, w), Word.shl.put(n, c, w)), word_shl_out_put(n, c, w)) :
    {shl_value(n, _) == Nat.add(b2n(c), Nat.double(Word.to_nat(n, w))) : Nat}
  %Equal.sym(Nat, Nat.add(Word.to_nat(n, Word.shl.put(n, c, w)), scale(shl_carry(n, c, w), pow2(n))),
    bit(c, Word.to_nat(n, w)), word_shl_put_nat(n, c, w)) :
    {_ == Nat.add(b2n(c), Nat.double(Word.to_nat(n, w))) : Nat}
  bit_nat(c, Word.to_nat(n, w))

law word_shl_put_mod:
  for +n: Nat
  for +c: Bool
  for +w: Word(n)
  {Word.to_nat(n, Word.shl.put(n, c, w)) == Nat.mod(bit(c, Word.to_nat(n, w)), pow2(n)) : Nat}

def word_shl_put_mod(n, c, w):
  add_mod_carry(shl_carry(n, c, w), Word.to_nat(n, Word.shl.put(n, c, w)), pow2(n),
    bit(c, Word.to_nat(n, w)), word_shl_put_nat(n, c, w), word_to_nat_lt(n, Word.shl.put(n, c, w)))

law word_shl_mod:
  for +n: Nat
  for +w: Word(n)
  {Word.to_nat(n, Word.shl(n, w)) == Nat.mod(Nat.double(Word.to_nat(n, w)), pow2(n)) : Nat}

def word_shl_mod(n, w):
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{+b, +t}:
          word_shl_put_mod(1n+p, False{}, WCon{b, t})

law mod_add_right:
  for +a: Nat
  for +b: Nat
  for +m: Nat
  {Nat.mod(Nat.add(a, Nat.mod(b, m)), m) == Nat.mod(Nat.add(a, b), m) : Nat}

def mod_add_right(a, b, m):
  %MNat.mod_add_div(b, m) :
    {Nat.mod(Nat.add(a, Nat.mod(b, m)), m) == Nat.mod(Nat.add(a, _), m) : Nat}
  %MNat.add_assoc(a, Nat.mod(b, m), Nat.mul(m, Nat.div(b, m))) :
    {Nat.mod(Nat.add(a, Nat.mod(b, m)), m) == Nat.mod(_, m) : Nat}
  MNat.add_mul_mod_self_left_sym(Nat.add(a, Nat.mod(b, m)), m, Nat.div(b, m))

law mod_add_left:
  for +a: Nat
  for +b: Nat
  for +m: Nat
  {Nat.mod(Nat.add(Nat.mod(a, m), b), m) == Nat.mod(Nat.add(a, b), m) : Nat}

def mod_add_left(a, b, m):
  %MNat.add_comm(b, Nat.mod(a, m)) :
    {Nat.mod(_, m) == Nat.mod(Nat.add(a, b), m) : Nat}
  %MNat.add_comm(b, a) :
    {Nat.mod(Nat.add(b, Nat.mod(a, m)), m) == Nat.mod(_, m) : Nat}
  mod_add_right(b, a, m)

law mod_add_product:
  for +a: Nat
  for +b: Nat
  for +c: Nat
  for +m: Nat
  {Nat.mod(Nat.add(a, Nat.mul(b, Nat.mod(c, m))), m) == Nat.mod(Nat.add(a, Nat.mul(b, c)), m) : Nat}

def mod_add_product(a, b, c, m):
  %MNat.mod_add_div(c, m) :
    {Nat.mod(Nat.add(a, Nat.mul(b, Nat.mod(c, m))), m) == Nat.mod(Nat.add(a, Nat.mul(b, _)), m) : Nat}
  %MNat.mul_add_sym(b, Nat.mod(c, m), Nat.mul(m, Nat.div(c, m))) :
    {Nat.mod(Nat.add(a, Nat.mul(b, Nat.mod(c, m))), m) == Nat.mod(Nat.add(a, _), m) : Nat}
  %MNat.mul_left_comm(m, b, Nat.div(c, m)) :
    {Nat.mod(Nat.add(a, Nat.mul(b, Nat.mod(c, m))), m) == Nat.mod(Nat.add(a, Nat.add(Nat.mul(b, Nat.mod(c, m)), _)), m) : Nat}
  %MNat.add_assoc(a, Nat.mul(b, Nat.mod(c, m)), Nat.mul(m, Nat.mul(b, Nat.div(c, m)))) :
    {Nat.mod(Nat.add(a, Nat.mul(b, Nat.mod(c, m))), m) == Nat.mod(_, m) : Nat}
  MNat.add_mul_mod_self_left_sym(Nat.add(a, Nat.mul(b, Nat.mod(c, m))), m, Nat.mul(b, Nat.div(c, m)))

law mul_bit:
  for b: Bool
  for +a: Nat
  for +v: Nat
  {Nat.mul(bit(b, a), v) == Nat.add(scale(b, v), Nat.mul(a, Nat.double(v))) : Nat}

def mul_bit(b, a, v):
  match b:
    case False{}:
      Equal.trans(Nat, Nat.mul(Nat.double(a), v), Nat.double(Nat.mul(a, v)), Nat.mul(a, Nat.double(v)),
        MNat.double_mul_sym(a, v), MNat.mul_double_sym(a, v))
    case True{}:
      %MNat.mul_double_sym(a, v) :
        {Nat.mul(1n+Nat.double(a), v) == Nat.add(v, _) : Nat}
      %MNat.double_mul(a, v) :
        {Nat.add(v, _) == Nat.add(v, Nat.double(Nat.mul(a, v))) : Nat}
      {==}

law word_mul_go_nat:
  for +m: Nat
  for +n: Nat
  for +a: Word(m)
  for +b: Word(n)
  for +acc: Word(n)
  {Word.to_nat(n, Word.mul.go(n, m, a, b, acc)) ==
    Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(Word.to_nat(m, a), Word.to_nat(n, b))), pow2(n)) : Nat}

def word_mul_go_nat(m, n, a, b, acc):
  match m:
    case 0n:
      %MNat.add_zero_sym(Word.to_nat(n, acc)) :
        {Word.to_nat(n, acc) == Nat.mod(_, pow2(n)) : Nat}
      Equal.sym(Nat, Nat.mod(Word.to_nat(n, acc), pow2(n)), Word.to_nat(n, acc),
        MNat.mod_eq_of_lt(Word.to_nat(n, acc), pow2(n), word_to_nat_lt(n, acc)))
    case 1n+ +p:
      match a:
        case WCon{False{}, +at}:
          Equal.trans(Nat, Word.to_nat(n, Word.mul.go(n, p, at, Word.shl(n, b), acc)),
            Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(Word.to_nat(p, at), Word.to_nat(n, Word.shl(n, b)))), pow2(n)),
            Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b))), pow2(n)),
            word_mul_go_nat(p, n, at, Word.shl(n, b), acc),
            (
              %Equal.sym(Nat, Word.to_nat(n, Word.shl(n, b)), Nat.mod(Nat.double(Word.to_nat(n, b)), pow2(n)),
                word_shl_mod(n, b)) :
                {Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(Word.to_nat(p, at), _)), pow2(n)) ==
                  Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b))), pow2(n)) : Nat}
              %MNat.double_mul(Word.to_nat(p, at), Word.to_nat(n, b)) :
                {Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(Word.to_nat(p, at), Nat.mod(Nat.double(Word.to_nat(n, b)), pow2(n)))), pow2(n)) ==
                  Nat.mod(Nat.add(Word.to_nat(n, acc), _), pow2(n)) : Nat}
              %MNat.mul_double(Word.to_nat(p, at), Word.to_nat(n, b)) :
                {Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(Word.to_nat(p, at), Nat.mod(Nat.double(Word.to_nat(n, b)), pow2(n)))), pow2(n)) ==
                  Nat.mod(Nat.add(Word.to_nat(n, acc), _), pow2(n)) : Nat}
              mod_add_product(Word.to_nat(n, acc), Word.to_nat(p, at), Nat.double(Word.to_nat(n, b)), pow2(n))
            ))
        case WCon{True{}, +at}:
          %Equal.sym(Nat, Word.to_nat(n, Word.mul.go(n, p, at, Word.shl(n, b), Word.add(n, acc, b))),
            Nat.mod(Nat.add(Word.to_nat(n, Word.add(n, acc, b)), Nat.mul(Word.to_nat(p, at), Word.to_nat(n, Word.shl(n, b)))), pow2(n)),
            word_mul_go_nat(p, n, at, Word.shl(n, b), Word.add(n, acc, b))) :
            {_ == Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(1n+Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b))), pow2(n)) : Nat}
          %Equal.sym(Nat, Word.to_nat(n, Word.add(n, acc, b)), Nat.mod(Nat.add(Word.to_nat(n, acc), Word.to_nat(n, b)), pow2(n)),
            word_add_mod(n, acc, b)) :
            {Nat.mod(Nat.add(_, Nat.mul(Word.to_nat(p, at), Word.to_nat(n, Word.shl(n, b)))), pow2(n)) ==
              Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(1n+Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b))), pow2(n)) : Nat}
          %Equal.sym(Nat, Word.to_nat(n, Word.shl(n, b)), Nat.mod(Nat.double(Word.to_nat(n, b)), pow2(n)), word_shl_mod(n, b)) :
            {Nat.mod(Nat.add(Nat.mod(Nat.add(Word.to_nat(n, acc), Word.to_nat(n, b)), pow2(n)), Nat.mul(Word.to_nat(p, at), _)), pow2(n)) ==
              Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(1n+Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b))), pow2(n)) : Nat}
          %Equal.sym(Nat,
            Nat.mod(Nat.add(Nat.mod(Nat.add(Word.to_nat(n, acc), Word.to_nat(n, b)), pow2(n)), Nat.mul(Word.to_nat(p, at), Nat.mod(Nat.double(Word.to_nat(n, b)), pow2(n)))), pow2(n)),
            Nat.mod(Nat.add(Nat.add(Word.to_nat(n, acc), Word.to_nat(n, b)), Nat.mul(Word.to_nat(p, at), Nat.mod(Nat.double(Word.to_nat(n, b)), pow2(n)))), pow2(n)),
            mod_add_left(Nat.add(Word.to_nat(n, acc), Word.to_nat(n, b)), Nat.mul(Word.to_nat(p, at), Nat.mod(Nat.double(Word.to_nat(n, b)), pow2(n))), pow2(n))) :
            {_ == Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(1n+Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b))), pow2(n)) : Nat}
          %Equal.sym(Nat,
            Nat.mod(Nat.add(Nat.add(Word.to_nat(n, acc), Word.to_nat(n, b)), Nat.mul(Word.to_nat(p, at), Nat.mod(Nat.double(Word.to_nat(n, b)), pow2(n)))), pow2(n)),
            Nat.mod(Nat.add(Nat.add(Word.to_nat(n, acc), Word.to_nat(n, b)), Nat.mul(Word.to_nat(p, at), Nat.double(Word.to_nat(n, b)))), pow2(n)),
            mod_add_product(Nat.add(Word.to_nat(n, acc), Word.to_nat(n, b)), Word.to_nat(p, at), Nat.double(Word.to_nat(n, b)), pow2(n))) :
            {_ == Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(1n+Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b))), pow2(n)) : Nat}
          %MNat.add_assoc_sym(Word.to_nat(n, acc), Word.to_nat(n, b), Nat.mul(Word.to_nat(p, at), Nat.double(Word.to_nat(n, b)))) :
            {Nat.mod(_, pow2(n)) == Nat.mod(Nat.add(Word.to_nat(n, acc), Nat.mul(1n+Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b))), pow2(n)) : Nat}
          Equal.cong(Nat, Nat, v => Nat.mod(Nat.add(Word.to_nat(n, acc), v), pow2(n)),
            Nat.add(Word.to_nat(n, b), Nat.mul(Word.to_nat(p, at), Nat.double(Word.to_nat(n, b)))),
            Nat.mul(1n+Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b)),
            Equal.sym(Nat, Nat.mul(1n+Nat.double(Word.to_nat(p, at)), Word.to_nat(n, b)),
              Nat.add(Word.to_nat(n, b), Nat.mul(Word.to_nat(p, at), Nat.double(Word.to_nat(n, b)))),
              mul_bit(True{}, Word.to_nat(p, at), Word.to_nat(n, b))))

law word_zero_nat:
  for n: Nat
  {Word.to_nat(n, Word.zero(n)) == 0n : Nat}

def word_zero_nat(n):
  match n:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, v => Nat.double(v), Word.to_nat(p, Word.zero(p)), 0n, word_zero_nat(p))

law word_mul_mod:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  {Word.to_nat(n, Word.mul(n, a, b)) == Nat.mod(Nat.mul(Word.to_nat(n, a), Word.to_nat(n, b)), pow2(n)) : Nat}

def word_mul_mod(n, a, b):
  %word_zero_nat(n) :
    {Word.to_nat(n, Word.mul(n, a, b)) ==
      Nat.mod(Nat.add(_, Nat.mul(Word.to_nat(n, a), Word.to_nat(n, b))), pow2(n)) : Nat}
  word_mul_go_nat(n, n, a, b, Word.zero(n))

law u32_mul_word:
  for -x: Word(32n)
  for -y: Word(32n)
  {Word.to_nat(32n, Word.mul(32n, x, y)) == U32.to_nat(U32.mul(U32{x}, U32{y})) : Nat}

def u32_mul_word(x, y):
  {==}

law u32_mul_mod:
  for +a: U32
  for +b: U32
  {U32.to_nat(U32.mul(a, b)) == Nat.mod(Nat.mul(U32.to_nat(a), U32.to_nat(b)), pow2(32n)) : Nat}

def u32_mul_mod(a, b):
  match a b:
    case U32{+x} U32{+y}:
      %u32_mul_word(x, y) :
        {_ == Nat.mod(Nat.mul(U32.to_nat(U32{x}), U32.to_nat(U32{y})), pow2(32n)) : Nat}
      %u32_to_nat_word(x) :
        {Word.to_nat(32n, Word.mul(32n, x, y)) == Nat.mod(Nat.mul(_, U32.to_nat(U32{y})), pow2(32n)) : Nat}
      %u32_to_nat_word(y) :
        {Word.to_nat(32n, Word.mul(32n, x, y)) == Nat.mod(Nat.mul(Word.to_nat(32n, x), _), pow2(32n)) : Nat}
      word_mul_mod(32n, x, y)

law u32_mul_nat:
  for +a: U32
  for +b: U32
  for h: MNat.lt(Nat.mul(U32.to_nat(a), U32.to_nat(b)), pow2(32n))
  {U32.to_nat(U32.mul(a, b)) == Nat.mul(U32.to_nat(a), U32.to_nat(b)) : Nat}

def u32_mul_nat(a, b, h):
  Equal.trans(Nat, U32.to_nat(U32.mul(a, b)), Nat.mod(Nat.mul(U32.to_nat(a), U32.to_nat(b)), pow2(32n)),
    Nat.mul(U32.to_nat(a), U32.to_nat(b)), u32_mul_mod(a, b),
    MNat.mod_eq_of_lt(Nat.mul(U32.to_nat(a), U32.to_nat(b)), pow2(32n), h))

law complement_sum_sub:
  for +a: Nat
  for +b: Nat
  for +nb: Nat
  for +m: Nat
  for hn: {1n+Nat.add(nb, b) == m : Nat}
  {1n+Nat.add(a, nb) == Nat.sub(Nat.add(a, m), b) : Nat}

def complement_sum_sub(a, b, nb, m, hn):
  %hn : {1n+Nat.add(a, nb) == Nat.sub(Nat.add(a, _), b) : Nat}
  %MNat.add_succ_sym(a, Nat.add(nb, b)) :
    {1n+Nat.add(a, nb) == Nat.sub(_, b) : Nat}
  %MNat.add_assoc(a, nb, b) :
    {1n+Nat.add(a, nb) == Nat.sub(1n+_, b) : Nat}
  MNat.add_sub_cancel_sym(1n+Nat.add(a, nb), b)

law complement_sum_lt:
  for +a: Nat
  for +b: Nat
  for +nb: Nat
  for +m: Nat
  for h: MNat.lt(a, b)
  for hn: {1n+Nat.add(nb, b) == m : Nat}
  MNat.lt(1n+Nat.add(a, nb), m)

def complement_sum_lt(a, b, nb, m, h, hn):
  %hn : MNat.lt(1n+Nat.add(a, nb), _)
  %MNat.add_comm(nb, a) : MNat.lt(1n+_, 1n+Nat.add(nb, b))
  MNat.add_lt_add_left(a, b, 1n+nb, h)

law word_sub_wrap:
  for +n: Nat
  for +a: Word(n)
  for +b: Word(n)
  for +h: MNat.lt(Word.to_nat(n, a), Word.to_nat(n, b))
  {Word.to_nat(n, Word.sub(n, a, b)) == Nat.sub(Nat.add(Word.to_nat(n, a), pow2(n)), Word.to_nat(n, b)) : Nat}

def word_sub_wrap(n, a, b, h):
  %Equal.sym(Word(n), Word.sub(n, a, b), Word.adc(n, a, Word.not(n, b), False{}, True{}),
    word_sub_not(n, a, b, True{})) :
    {Word.to_nat(n, _) == Nat.sub(Nat.add(Word.to_nat(n, a), pow2(n)), Word.to_nat(n, b)) : Nat}
  Equal.trans(Nat, Word.to_nat(n, Word.adc(n, a, Word.not(n, b), False{}, True{})),
    1n+Nat.add(Word.to_nat(n, a), Word.to_nat(n, Word.not(n, b))),
    Nat.sub(Nat.add(Word.to_nat(n, a), pow2(n)), Word.to_nat(n, b)),
    add_no_carry(carry(n, a, Word.not(n, b), True{}),
      Word.to_nat(n, Word.adc(n, a, Word.not(n, b), False{}, True{})), pow2(n),
      1n+Nat.add(Word.to_nat(n, a), Word.to_nat(n, Word.not(n, b))),
      word_adc_nat(n, a, Word.not(n, b), True{}),
      complement_sum_lt(Word.to_nat(n, a), Word.to_nat(n, b), Word.to_nat(n, Word.not(n, b)), pow2(n), h, word_not_nat(n, b))),
    complement_sum_sub(Word.to_nat(n, a), Word.to_nat(n, b), Word.to_nat(n, Word.not(n, b)), pow2(n), word_not_nat(n, b)))

law u32_sub_word:
  for -x: Word(32n)
  for -y: Word(32n)
  {Word.to_nat(32n, Word.sub(32n, x, y)) == U32.to_nat(U32.sub(U32{x}, U32{y})) : Nat}

def u32_sub_word(x, y):
  {==}

law u32_sub_wrap:
  for +a: U32
  for +b: U32
  for +h: MNat.lt(U32.to_nat(a), U32.to_nat(b))
  {U32.to_nat(U32.sub(a, b)) == Nat.sub(Nat.add(U32.to_nat(a), pow2(32n)), U32.to_nat(b)) : Nat}

def u32_sub_wrap(a, b, h):
  match a b:
    case U32{+x} U32{+y}:
      %u32_sub_word(x, y) :
        {_ == Nat.sub(Nat.add(U32.to_nat(U32{x}), pow2(32n)), U32.to_nat(U32{y})) : Nat}
      %u32_to_nat_word(x) :
        {Word.to_nat(32n, Word.sub(32n, x, y)) == Nat.sub(Nat.add(_, pow2(32n)), U32.to_nat(U32{y})) : Nat}
      %u32_to_nat_word(y) :
        {Word.to_nat(32n, Word.sub(32n, x, y)) == Nat.sub(Nat.add(Word.to_nat(32n, x), pow2(32n)), _) : Nat}
      word_sub_wrap(32n, x, y, h)

law double_add_bit:
  for c: Bool
  for +a: Nat
  for +b: Nat
  {Nat.add(Nat.double(a), bit(c, b)) == bit(c, Nat.add(a, b)) : Nat}

def double_add_bit(c, a, b):
  match c:
    case False{}:
      MNat.double_add_sym(a, b)
    case True{}:
      %MNat.add_succ_sym(Nat.double(a), Nat.double(b)) :
        {_ == 1n+Nat.double(Nat.add(a, b)) : Nat}
      Equal.cong(Nat, Nat, v => 1n+v, Nat.add(Nat.double(a), Nat.double(b)),
        Nat.double(Nat.add(a, b)), MNat.double_add_sym(a, b))

law divmod_step_eq:
  for +t: Bool
  for +c: Bool
  for +q: Nat
  for +b: Nat
  for +r: Nat
  for +s: Nat
  for e: {Nat.add(scale(t, b), s) == bit(c, r) : Nat}
  {Nat.add(Nat.mul(bit(t, q), b), s) == bit(c, Nat.add(Nat.mul(q, b), r)) : Nat}

def divmod_step_eq(t, c, q, b, r, s, e):
  %Equal.sym(Nat, Nat.mul(bit(t, q), b), Nat.add(scale(t, b), Nat.mul(q, Nat.double(b))), mul_bit(t, q, b)) :
    {Nat.add(_, s) == bit(c, Nat.add(Nat.mul(q, b), r)) : Nat}
  %MNat.mul_double_sym(q, b) :
    {Nat.add(Nat.add(scale(t, b), _), s) == bit(c, Nat.add(Nat.mul(q, b), r)) : Nat}
  %MNat.add_comm(Nat.double(Nat.mul(q, b)), scale(t, b)) :
    {Nat.add(_, s) == bit(c, Nat.add(Nat.mul(q, b), r)) : Nat}
  %MNat.add_assoc_sym(Nat.double(Nat.mul(q, b)), scale(t, b), s) :
    {_ == bit(c, Nat.add(Nat.mul(q, b), r)) : Nat}
  %Equal.sym(Nat, Nat.add(scale(t, b), s), bit(c, r), e) :
    {Nat.add(Nat.double(Nat.mul(q, b)), _) == bit(c, Nat.add(Nat.mul(q, b), r)) : Nat}
  double_add_bit(c, Nat.mul(q, b), r)

law bit_lt_double:
  for c: Bool
  for +r: Nat
  for +b: Nat
  for h: MNat.lt(r, b)
  MNat.lt(bit(c, r), Nat.double(b))

def bit_lt_double(c, r, b, h):
  match c:
    case False{}:
      MNat.double_lt_double(r, b, h)
    case True{}:
      odd_lt_double(r, b, h)

law remainder_lt:
  for +b: Nat
  for +d: Nat
  for +c: Bool
  for +r: Nat
  for e: {Nat.add(b, d) == bit(c, r) : Nat}
  for h: MNat.lt(r, b)
  MNat.lt(d, b)

def remainder_lt(b, d, c, r, e, h):
  MNat.lt_of_add_lt_add_left(b, d, b,
    lt_rw(Nat.add(b, d), bit(c, r), Nat.add(b, b), e,
      (
        %MNat.double_eq_add(b) : MNat.lt(bit(c, r), _)
        bit_lt_double(c, r, b, h)
      )))

law carry_remainder_lt:
  for +s: Nat
  for +m: Nat
  for +b: Nat
  for +c: Bool
  for +r: Nat
  for e: {Nat.add(s, m) == bit(c, r) : Nat}
  for hr: MNat.lt(r, b)
  for hb: MNat.lt(b, m)
  MNat.lt(s, b)

def carry_remainder_lt(s, m, b, c, r, e, hr, hb):
  MNat.lt_of_add_lt_add_right(s, b, m,
    MNat.lt_of_lt_of_le(Nat.add(s, m), Nat.double(b), Nat.add(b, m),
      lt_rw(Nat.add(s, m), bit(c, r), Nat.double(b), e, bit_lt_double(c, r, b, hr)),
      (
        %MNat.double_eq_add_sym(b) : MNat.le(_, Nat.add(b, m))
        MNat.add_le_add_left(b, m, b, MNat.le_of_lt(b, m, hb))
      )))

def divmod_spec(+m: Nat, +a: Word(m), +b: U32, qr: Word(m) & U32) -> Type:
  (q, +r) = qr
  {Nat.add(Nat.mul(Word.to_nat(m, q), U32.to_nat(b)), U32.to_nat(r)) == Word.to_nat(m, a) : Nat} &
    MNat.lt(U32.to_nat(r), U32.to_nat(b))

law u32_ge_le:
  for +a: U32
  for +b: U32
  {U32.is_ge(a, b) == Nat.is_le(U32.to_nat(b), U32.to_nat(a)) : Bool}

def u32_ge_le(a, b):
  Equal.trans(Bool, U32.is_ge(a, b), Nat.is_ge(U32.to_nat(a), U32.to_nat(b)),
    Nat.is_le(U32.to_nat(b), U32.to_nat(a)), MU32.u32_is_ge_to_nat(a, b),
    MNat.is_ge_eq_is_le(U32.to_nat(a), U32.to_nat(b)))

law divmod_finish:
  for +p: Nat
  for +c: Bool
  for +a: Word(p)
  for +b: U32
  for +q: Word(p)
  for +r: U32
  for +g: Bool
  for +s: U32
  for he: {Nat.add(Nat.mul(Word.to_nat(p, q), U32.to_nat(b)), U32.to_nat(r)) == Word.to_nat(p, a) : Nat}
  for hs: MNat.lt(U32.to_nat(s), U32.to_nat(b))
  for e: {Nat.add(scale(g, U32.to_nat(b)), U32.to_nat(s)) == bit(c, U32.to_nat(r)) : Nat}
  divmod_spec(1n+p, WCon{c, a}, b, (WCon{g, q}, s))

def divmod_finish(p, c, a, b, q, r, g, s, he, hs, e):
  (
    (
      %to_nat_con(p, g, q) :
        {Nat.add(Nat.mul(_, U32.to_nat(b)), U32.to_nat(s)) == Word.to_nat(1n+p, WCon{c, a}) : Nat}
      Equal.trans(Nat, Nat.add(Nat.mul(bit(g, Word.to_nat(p, q)), U32.to_nat(b)), U32.to_nat(s)),
        bit(c, Nat.add(Nat.mul(Word.to_nat(p, q), U32.to_nat(b)), U32.to_nat(r))),
        Word.to_nat(1n+p, WCon{c, a}),
        divmod_step_eq(g, c, Word.to_nat(p, q), U32.to_nat(b), U32.to_nat(r), U32.to_nat(s), e),
        Equal.trans(Nat, bit(c, Nat.add(Nat.mul(Word.to_nat(p, q), U32.to_nat(b)), U32.to_nat(r))),
          bit(c, Word.to_nat(p, a)), Word.to_nat(1n+p, WCon{c, a}),
          Equal.cong(Nat, Nat, v => bit(c, v),
            Nat.add(Nat.mul(Word.to_nat(p, q), U32.to_nat(b)), U32.to_nat(r)), Word.to_nat(p, a), he),
          to_nat_con(p, c, a)))
    ),
    hs
  )

law u32_sub_prefix:
  for +s: U32
  for +b: U32
  for +x: Nat
  for +h: MNat.le(U32.to_nat(b), U32.to_nat(s))
  for e: {U32.to_nat(s) == x : Nat}
  {Nat.add(U32.to_nat(b), U32.to_nat(U32.sub(s, b))) == x : Nat}

def u32_sub_prefix(s, b, x, h, e):
  %Equal.sym(Nat, U32.to_nat(U32.sub(s, b)), Nat.sub(U32.to_nat(s), U32.to_nat(b)), u32_sub_nat(s, b, h)) :
    {Nat.add(U32.to_nat(b), _) == x : Nat}
  Equal.trans(Nat, Nat.add(U32.to_nat(b), Nat.sub(U32.to_nat(s), U32.to_nat(b))), U32.to_nat(s), x,
    MNat.add_sub_of_le(U32.to_nat(b), U32.to_nat(s), h), e)

law u32_sub_carry_prefix:
  for +s: U32
  for +b: U32
  for +x: Nat
  for +h: MNat.lt(U32.to_nat(s), U32.to_nat(b))
  for e: {Nat.add(U32.to_nat(s), pow2(32n)) == x : Nat}
  {Nat.add(U32.to_nat(b), U32.to_nat(U32.sub(s, b))) == x : Nat}

def u32_sub_carry_prefix(s, b, x, h, e):
  %Equal.sym(Nat, U32.to_nat(U32.sub(s, b)), Nat.sub(Nat.add(U32.to_nat(s), pow2(32n)), U32.to_nat(b)), u32_sub_wrap(s, b, h)) :
    {Nat.add(U32.to_nat(b), _) == x : Nat}
  Equal.trans(Nat, Nat.add(U32.to_nat(b), Nat.sub(Nat.add(U32.to_nat(s), pow2(32n)), U32.to_nat(b))),
    Nat.add(U32.to_nat(s), pow2(32n)), x,
    MNat.add_sub_of_le(U32.to_nat(b), Nat.add(U32.to_nat(s), pow2(32n)),
      MNat.le_trans(U32.to_nat(b), pow2(32n), Nat.add(U32.to_nat(s), pow2(32n)),
        MNat.le_of_lt(U32.to_nat(b), pow2(32n), u32_to_nat_lt(b)), MNat.le_add_left(pow2(32n), U32.to_nat(s)))),
    e)

law scale_false:
  for -m: Nat
  {scale(False{}, m) == 0n : Nat}

def scale_false(m):
  {==}

law scale_true:
  for -m: Nat
  {scale(True{}, m) == m : Nat}

def scale_true(m):
  {==}

law divmod_fin:
  for t: Bool
  for g: Bool
  for +p: Nat
  for +c: Bool
  for +a: Word(p)
  for +b: U32
  for +q: Word(p)
  for +r: U32
  for +s: U32
  for he: {Nat.add(Nat.mul(Word.to_nat(p, q), U32.to_nat(b)), U32.to_nat(r)) == Word.to_nat(p, a) : Nat}
  for +hr: MNat.lt(U32.to_nat(r), U32.to_nat(b))
  for +e: {Nat.add(U32.to_nat(s), scale(t, pow2(32n))) == bit(c, U32.to_nat(r)) : Nat}
  for hg: {g == Bool.or(t, U32.is_ge(s, b)) : Bool}
  divmod_spec(1n+p, WCon{c, a}, b, U32.divmod.go.fin(p, q, s, b, g))

def divmod_fin(t, g, p, c, a, b, q, r, s, he, hr, e, hg):
  match t g:
    case False{} False{}:
      +e0 : {Nat.add(U32.to_nat(s), 0n) == bit(c, U32.to_nat(r)) : Nat} = (
        %scale_false(pow2(32n)) : {Nat.add(U32.to_nat(s), _) == bit(c, U32.to_nat(r)) : Nat}
        e
      )
      divmod_finish(p, c, a, b, q, r, False{}, s, he,
        MNat.lt_of_not_le(U32.to_nat(b), U32.to_nat(s),
          (
            %u32_ge_le(s, b) : {_ == False{} : Bool}
            Equal.sym(Bool, False{}, U32.is_ge(s, b), hg)
          )),
        Equal.trans(Nat, U32.to_nat(s), Nat.add(U32.to_nat(s), 0n), bit(c, U32.to_nat(r)),
          MNat.add_zero_sym(U32.to_nat(s)), e0))
    case False{} True{}:
      +e0 : {Nat.add(U32.to_nat(s), 0n) == bit(c, U32.to_nat(r)) : Nat} = (
        %scale_false(pow2(32n)) : {Nat.add(U32.to_nat(s), _) == bit(c, U32.to_nat(r)) : Nat}
        e
      )
      +hge : MNat.le(U32.to_nat(b), U32.to_nat(s)) = (
        %u32_ge_le(s, b) : {_ == True{} : Bool}
        Equal.sym(Bool, True{}, U32.is_ge(s, b), hg)
      )
      +er = u32_sub_prefix(s, b, bit(c, U32.to_nat(r)), hge,
        Equal.trans(Nat, U32.to_nat(s), Nat.add(U32.to_nat(s), 0n), bit(c, U32.to_nat(r)),
          MNat.add_zero_sym(U32.to_nat(s)), e0))
      divmod_finish(p, c, a, b, q, r, True{}, U32.sub(s, b), he,
        remainder_lt(U32.to_nat(b), U32.to_nat(U32.sub(s, b)), c, U32.to_nat(r), er, hr), er)
    case True{} False{}:
      Empty.absurd(divmod_spec(1n+p, WCon{c, a}, b, (WCon{False{}, q}, s)),
        MNat.zero_ne_succ(0n)(Equal.cong(Bool, Nat, b2n, False{}, True{}, hg)))
    case True{} True{}:
      +e0 : {Nat.add(U32.to_nat(s), pow2(32n)) == bit(c, U32.to_nat(r)) : Nat} = (
        %scale_true(pow2(32n)) : {Nat.add(U32.to_nat(s), _) == bit(c, U32.to_nat(r)) : Nat}
        e
      )
      +er = u32_sub_carry_prefix(s, b, bit(c, U32.to_nat(r)),
        carry_remainder_lt(U32.to_nat(s), pow2(32n), U32.to_nat(b), c, U32.to_nat(r), e0, hr, u32_to_nat_lt(b)), e0)
      divmod_finish(p, c, a, b, q, r, True{}, U32.sub(s, b), he,
        remainder_lt(U32.to_nat(b), U32.to_nat(U32.sub(s, b)), c, U32.to_nat(r), er, hr), er)

law shl_value_word:
  for +n: Nat
  for +t: Bool
  for +w: Word(n)
  {Nat.add(Word.to_nat(n, w), scale(t, pow2(n))) == shl_value(n, (t, w)) : Nat}

def shl_value_word(n, t, w):
  {==}

law shl_value_u32:
  for +t: Bool
  for +w: Word(32n)
  {Nat.add(U32.to_nat(U32{w}), scale(t, pow2(32n))) == shl_value(32n, (t, w)) : Nat}

def shl_value_u32(t, w):
  %u32_to_nat_word(w) : {Nat.add(_, scale(t, pow2(32n))) == shl_value(32n, (t, w)) : Nat}
  shl_value_word(32n, t, w)

law divmod_shl:
  for +p: Nat
  for +c: Bool
  for +a: Word(p)
  for +b: U32
  for +q: Word(p)
  for +r: U32
  for ts: Bool & Word(32n)
  for he: {Nat.add(Nat.mul(Word.to_nat(p, q), U32.to_nat(b)), U32.to_nat(r)) == Word.to_nat(p, a) : Nat}
  for hr: MNat.lt(U32.to_nat(r), U32.to_nat(b))
  for e: {shl_value(32n, ts) == bit(c, U32.to_nat(r)) : Nat}
  divmod_spec(1n+p, WCon{c, a}, b, U32.divmod.go.shl(p, q, b, ts))

def divmod_shl(p, c, a, b, q, r, ts, he, hr, e):
  (+t, +w) = ts
  divmod_fin(t, Bool.or(t, U32.is_ge(U32{w}, b)), p, c, a, b, q, r, U32{w}, he, hr,
    Equal.trans(Nat, Nat.add(U32.to_nat(U32{w}), scale(t, pow2(32n))), shl_value(32n, (t, w)),
      bit(c, U32.to_nat(r)), shl_value_u32(t, w), e), {==})

law divmod_rec_u32:
  for +p: Nat
  for +c: Bool
  for +a: Word(p)
  for +b: U32
  for +q: Word(p)
  for +r: U32
  for he: {Nat.add(Nat.mul(Word.to_nat(p, q), U32.to_nat(b)), U32.to_nat(r)) == Word.to_nat(p, a) : Nat}
  for hr: MNat.lt(U32.to_nat(r), U32.to_nat(b))
  divmod_spec(1n+p, WCon{c, a}, b, U32.divmod.go.rec(p, c, b, (q, r)))

def divmod_rec_u32(p, c, a, b, q, r, he, hr):
  match r:
    case U32{+rw}:
      divmod_shl(p, c, a, b, q, U32{rw}, Word.shl.out(32n, c, rw), he, hr,
        (
          %u32_to_nat_word(rw) :
            {shl_value(32n, Word.shl.out(32n, c, rw)) == bit(c, _) : Nat}
          Equal.trans(Nat, shl_value(32n, Word.shl.out(32n, c, rw)),
            Nat.add(b2n(c), Nat.double(Word.to_nat(32n, rw))), bit(c, Word.to_nat(32n, rw)),
            word_shl_out_nat(32n, c, rw),
            Equal.sym(Nat, bit(c, Word.to_nat(32n, rw)), Nat.add(b2n(c), Nat.double(Word.to_nat(32n, rw))),
              bit_nat(c, Word.to_nat(32n, rw))))
        ))

law divmod_rec:
  for +p: Nat
  for +c: Bool
  for +a: Word(p)
  for +b: U32
  for qr: Word(p) & U32
  for h: divmod_spec(p, a, b, qr)
  divmod_spec(1n+p, WCon{c, a}, b, U32.divmod.go.rec(p, c, b, qr))

def divmod_rec(p, c, a, b, qr, h):
  (q, r) = qr
  (he, hr) = h
  divmod_rec_u32(p, c, a, b, q, r, he, hr)

law u32_divmod_go_nat:
  for +m: Nat
  for +a: Word(m)
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  divmod_spec(m, a, b, U32.divmod.go(m, a, b))

def u32_divmod_go_nat(m, a, b, hb):
  match m a:
    case 0n WNil{}:
      ({==}, hb)
    case 1n+ +p WCon{+c, +at}:
      divmod_rec(p, c, at, b, U32.divmod.go(p, at, b), u32_divmod_go_nat(p, at, b, hb))

law pos_not_zero:
  for n: Nat
  for h: MNat.lt(0n, n)
  {Nat.is_eq(n, 0n) == False{} : Bool}

def pos_not_zero(n, h):
  match n:
    case 0n:
      Empty.absurd({Nat.is_eq(0n, 0n) == False{} : Bool}, MNat.lt_irrefl(0n)(h))
    case 1n+p:
      {==}

law u32_nonzero:
  for +b: U32
  for h: MNat.lt(0n, U32.to_nat(b))
  {U32.is_zero(b) == False{} : Bool}

def u32_nonzero(b, h):
  %MU32.u32_is_eq_to_nat_sym(b, 0) :
    {_ == False{} : Bool}
  pos_not_zero(U32.to_nat(b), h)

law divmod_project:
  for +a: Word(32n)
  for +b: U32
  for qr: Word(32n) & U32
  for h: divmod_spec(32n, a, b, qr)
  {Nat.add(Nat.mul(U32.to_nat(U32.div.fin(qr)), U32.to_nat(b)), U32.to_nat(U32.mod.fin(qr))) == Word.to_nat(32n, a) : Nat} &
    MNat.lt(U32.to_nat(U32.mod.fin(qr)), U32.to_nat(b))

def divmod_project(a, b, qr, h):
  (+q, +r) = qr
  (he, hr) = h
  (
    (
      %u32_to_nat_word(q) :
        {Nat.add(Nat.mul(_, U32.to_nat(b)), U32.to_nat(r)) == Word.to_nat(32n, a) : Nat}
      he
    ),
    hr
  )

law divmod_if:
  for +a: Word(32n)
  for +b: U32
  for +z: Bool
  for hz: {z == False{} : Bool}
  for hb: MNat.lt(0n, U32.to_nat(b))
  {Nat.add(Nat.mul(U32.to_nat(U32.div.if(a, b, z)), U32.to_nat(b)), U32.to_nat(U32.mod.if(a, b, z))) == Word.to_nat(32n, a) : Nat} &
    MNat.lt(U32.to_nat(U32.mod.if(a, b, z)), U32.to_nat(b))

def divmod_if(a, b, z, hz, hb):
  %Equal.sym(Bool, z, False{}, hz) :
    {Nat.add(Nat.mul(U32.to_nat(U32.div.if(a, b, _)), U32.to_nat(b)), U32.to_nat(U32.mod.if(a, b, _))) == Word.to_nat(32n, a) : Nat} &
      MNat.lt(U32.to_nat(U32.mod.if(a, b, _)), U32.to_nat(b))
  divmod_project(a, b, U32.divmod.go(32n, a, b), u32_divmod_go_nat(32n, a, b, hb))

law u32_divmod_nat:
  for +a: U32
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  {Nat.add(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b))) == U32.to_nat(a) : Nat} &
    MNat.lt(U32.to_nat(U32.mod(a, b)), U32.to_nat(b))

def u32_divmod_nat(a, b, hb):
  match a b:
    case U32{+aw} U32{+bw}:
      %u32_to_nat_word(aw) :
        {Nat.add(Nat.mul(U32.to_nat(U32.div(U32{aw}, U32{bw})), U32.to_nat(U32{bw})), U32.to_nat(U32.mod(U32{aw}, U32{bw}))) == _ : Nat} &
          MNat.lt(U32.to_nat(U32.mod(U32{aw}, U32{bw})), U32.to_nat(U32{bw}))
      divmod_if(aw, U32{bw}, U32.is_zero(U32{bw}), u32_nonzero(U32{bw}, hb), hb)

law mod_unique:
  for +q: Nat
  for +r: Nat
  for +a: Nat
  for +b: Nat
  for hr: MNat.lt(r, b)
  for e: {Nat.add(Nat.mul(q, b), r) == a : Nat}
  {r == Nat.mod(a, b) : Nat}

def mod_unique(q, r, a, b, hr, e):
  %e : {r == Nat.mod(_, b) : Nat}
  %MNat.add_comm(r, Nat.mul(q, b)) : {r == Nat.mod(_, b) : Nat}
  %MNat.add_mul_mod_self_right_sym(r, b, q) : {r == _ : Nat}
  Equal.sym(Nat, Nat.mod(r, b), r, MNat.mod_eq_of_lt(r, b, hr))

law div_unique:
  for +b: Nat
  for +q: Nat
  for +r: Nat
  for +a: Nat
  for hb: MNat.lt(0n, b)
  for hr: MNat.lt(r, b)
  for e: {Nat.add(Nat.mul(q, b), r) == a : Nat}
  {q == Nat.div(a, b) : Nat}

def div_unique(b, q, r, a, hb, hr, e):
  match b:
    case 0n:
      Empty.absurd({q == Nat.div(a, 0n) : Nat}, MNat.lt_irrefl(0n)(hb))
    case 1n+ +p:
      %e : {q == Nat.div(_, 1n+p) : Nat}
      %MNat.add_comm(r, Nat.mul(q, 1n+p)) : {q == Nat.div(_, 1n+p) : Nat}
      %MNat.add_mul_div_right_sym(r, q, p) : {q == _ : Nat}
      %Equal.sym(Nat, Nat.div(r, 1n+p), 0n,
        MNat.div_eq_zero_of_le(r, p, MNat.le_of_lt_succ(r, p, hr))) :
        {q == Nat.add(_, q) : Nat}
      {==}

def div_unique_pair(+b: Nat, +q: Nat, +r: Nat, +a: Nat, hb: MNat.lt(0n, b),
  h: {Nat.add(Nat.mul(q, b), r) == a : Nat} & MNat.lt(r, b)) -> {q == Nat.div(a, b) : Nat}:
  (e, hr) = h
  div_unique(b, q, r, a, hb, hr, e)

def mod_unique_pair(+q: Nat, +r: Nat, +a: Nat, +b: Nat,
  h: {Nat.add(Nat.mul(q, b), r) == a : Nat} & MNat.lt(r, b)) -> {r == Nat.mod(a, b) : Nat}:
  (e, hr) = h
  mod_unique(q, r, a, b, hr, e)

law u32_div_nat:
  for +a: U32
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  {U32.to_nat(U32.div(a, b)) == Nat.div(U32.to_nat(a), U32.to_nat(b)) : Nat}

def u32_div_nat(a, b, hb):
  div_unique_pair(U32.to_nat(b), U32.to_nat(U32.div(a, b)), U32.to_nat(U32.mod(a, b)), U32.to_nat(a), hb,
    u32_divmod_nat(a, b, hb))

law u32_mod_nat:
  for +a: U32
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  {U32.to_nat(U32.mod(a, b)) == Nat.mod(U32.to_nat(a), U32.to_nat(b)) : Nat}

def u32_mod_nat(a, b, hb):
  mod_unique_pair(U32.to_nat(U32.div(a, b)), U32.to_nat(U32.mod(a, b)), U32.to_nat(a), U32.to_nat(b),
    u32_divmod_nat(a, b, hb))

def xor_twice(x: Bool, y: Bool) -> {Bool.xor(Bool.xor(x, y), y) == x : Bool}:
  match x y:
    case True{} True{}:
      {==}
    case True{} False{}:
      {==}
    case False{} True{}:
      {==}
    case False{} False{}:
      {==}

# XOR with the same word twice gives the word back.
law word_xor_twice:
  for n: Nat
  for a: Word(n)
  for b: Word(n)
  {Word.xor(n, Word.xor(n, a, b), b) == a : Word(n)}

def word_xor_twice(n, a, b):
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case 1n+p:
      match a b:
        case WCon{+x, +at} WCon{+y, +bt}:
          %Equal.sym(Bool, Bool.xor(Bool.xor(x, y), y), x, xor_twice(x, y)) :
            {WCon{_, Word.xor(p, Word.xor(p, at, bt), bt)} == WCon{x, at} : Word(1n+p)}
          %Equal.sym(Word(p), Word.xor(p, Word.xor(p, at, bt), bt), at, word_xor_twice(p, at, bt)) :
            {WCon{x, _} == WCon{x, at} : Word(1n+p)}
          {==}

law u32_xor_twice:
  for +a: U32
  for +b: U32
  {U32.xor(U32.xor(a, b), b) == a : U32}

def u32_xor_twice(a, b):
  match a b:
    case U32{+aw} U32{+bw}:
      Equal.cong(Word(32n), U32, w => U32{w}, Word.xor(32n, Word.xor(32n, aw, bw), bw), aw, word_xor_twice(32n, aw, bw))

def div_mul_add_mod.le(+qb: Nat, +r: Nat, +a: Nat, e: {Nat.add(qb, r) == a : Nat}) -> MNat.le(qb, a):
  %e : MNat.le(qb, _)
  MNat.le_add_right(qb, r)

def div_mul_add_mod.sum(+m: U32, +qb: Nat, +r: Nat, +a: Nat, em: {U32.to_nat(m) == qb : Nat}, e: {Nat.add(qb, r) == a : Nat}) -> {Nat.add(U32.to_nat(m), r) == a : Nat}:
  %Equal.sym(Nat, U32.to_nat(m), qb, em) : {Nat.add(_, r) == a : Nat}
  e

def div_mul_add_mod.go(+a: U32, +b: U32, +e: {Nat.add(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b))) == U32.to_nat(a) : Nat}) ->
  {U32.add(U32.mul(U32.div(a, b), b), U32.mod(a, b)) == a : U32}:
  +em = u32_mul_nat(U32.div(a, b), b,
    MNat.lt_of_le_of_lt(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(a), pow2(32n),
      div_mul_add_mod.le(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b)), U32.to_nat(a), e), u32_to_nat_lt(a)))
  +es = div_mul_add_mod.sum(U32.mul(U32.div(a, b), b), Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b)), U32.to_nat(a), em, e)
  u32_to_nat_inj(U32.add(U32.mul(U32.div(a, b), b), U32.mod(a, b)), a,
    Equal.trans(Nat, U32.to_nat(U32.add(U32.mul(U32.div(a, b), b), U32.mod(a, b))), Nat.add(U32.to_nat(U32.mul(U32.div(a, b), b)), U32.to_nat(U32.mod(a, b))), U32.to_nat(a),
      u32_add_nat(U32.mul(U32.div(a, b), b), U32.mod(a, b),
        lt_rw(Nat.add(U32.to_nat(U32.mul(U32.div(a, b), b)), U32.to_nat(U32.mod(a, b))), U32.to_nat(a), pow2(32n), es, u32_to_nat_lt(a))),
      es))

def div_mul_add_mod.pair(+a: U32, +b: U32,
  h: {Nat.add(Nat.mul(U32.to_nat(U32.div(a, b)), U32.to_nat(b)), U32.to_nat(U32.mod(a, b))) == U32.to_nat(a) : Nat} & MNat.lt(U32.to_nat(U32.mod(a, b)), U32.to_nat(b))) ->
  {U32.add(U32.mul(U32.div(a, b), b), U32.mod(a, b)) == a : U32}:
  (e, hr) = h
  div_mul_add_mod.go(a, b, e)

# The quotient times the divisor plus the remainder rebuilds a U32.
law u32_div_mul_add_mod:
  for +a: U32
  for +b: U32
  for +hb: MNat.lt(0n, U32.to_nat(b))
  {U32.add(U32.mul(U32.div(a, b), b), U32.mod(a, b)) == a : U32}

def u32_div_mul_add_mod(a, b, hb):
  div_mul_add_mod.pair(a, b, u32_divmod_nat(a, b, hb))

def adc_zero(+n: Nat, w: Word(n), c: Bool) -> {Word.adc(n, w, Word.zero(n), False{}, c) == Bool.pick(Word(n), c, Word.inc(n, w), w) : Word(n)}:
  match n:
    case 0n:
      match w:
        case WNil{}:
          match c:
            case False{}:
              {==}
            case True{}:
              {==}
    case 1n+p:
      match w:
        case WCon{False{}, +t}:
          match c:
            case False{}:
              %Equal.sym(Word(p), Word.adc(p, t, Word.zero(p), False{}, False{}), t, adc_zero(p, t, False{})) : {WCon{False{}, _} == WCon{False{}, t} : Word(1n+p)}
              {==}
            case True{}:
              %Equal.sym(Word(p), Word.adc(p, t, Word.zero(p), False{}, False{}), t, adc_zero(p, t, False{})) : {WCon{True{}, _} == WCon{True{}, t} : Word(1n+p)}
              {==}
        case WCon{True{}, +t}:
          match c:
            case False{}:
              %Equal.sym(Word(p), Word.adc(p, t, Word.zero(p), False{}, False{}), t, adc_zero(p, t, False{})) : {WCon{True{}, _} == WCon{True{}, t} : Word(1n+p)}
              {==}
            case True{}:
              %Equal.sym(Word(p), Word.adc(p, t, Word.zero(p), False{}, True{}), Word.inc(p, t), adc_zero(p, t, True{})) : {WCon{False{}, _} == WCon{False{}, Word.inc(p, t)} : Word(1n+p)}
              {==}

def one(n: Nat) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+p:
      WCon{True{}, Word.zero(p)}

def add_one_word(+n: Nat, w: Word(n)) -> {Word.add(n, w, one(n)) == Word.inc(n, w) : Word(n)}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{False{}, +t}:
          %Equal.sym(Word(p), Word.adc(p, t, Word.zero(p), False{}, False{}), t, adc_zero(p, t, False{})) : {WCon{True{}, _} == WCon{True{}, t} : Word(1n+p)}
          {==}
        case WCon{True{}, +t}:
          %Equal.sym(Word(p), Word.adc(p, t, Word.zero(p), False{}, True{}), Word.inc(p, t), adc_zero(p, t, True{})) : {WCon{False{}, _} == WCon{False{}, Word.inc(p, t)} : Word(1n+p)}
          {==}

def u32_add_one(+n: U32) -> {U32.add(n, 1) == U32.inc(n) : U32}:
  match n:
    case U32{+w}:
      Equal.cong(Word(32n), U32, t => U32{t}, Word.add(32n, w, one(32n)), Word.inc(32n, w), add_one_word(32n, w))

