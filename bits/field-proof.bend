# Structural word algebra for packed bit fields.
import Base
import ./bits.bend as Bits
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ../bytes/word-proof.bend as WProof

# These definitions saturate at the word length, including the 32-bit mask.
def low_mask(+d: Nat, k: Nat) -> Word(d):
  match d:
    case 0n:
      WNil{}
    case 1n+p:
      match k:
        case 0n:
          Word.zero(1n+p)
        case 1n+q:
          WCon{True{}, low_mask(p, q)}

def low(+d: Nat, k: Nat, w: Word(d)) -> Word(d):
  match d:
    case 0n:
      WNil{}
    case 1n+p:
      match k:
        case 0n:
          Word.zero(1n+p)
        case 1n+q:
          match w:
            case WCon{x, t}:
              WCon{x, low(p, q, t)}

def high(d: Nat, k: Nat, w: Word(d)) -> Nat:
  match d:
    case 0n:
      0n
    case 1n+p:
      match k:
        case 0n:
          Word.to_nat(1n+p, w)
        case 1n+q:
          match w:
            case WCon{x, t}:
              high(p, q, t)

def power(+d: Nat, k: Nat) -> Word(d):
  match d:
    case 0n:
      WNil{}
    case 1n+p:
      match k:
        case 0n:
          WCon{True{}, Word.zero(p)}
        case 1n+q:
          WCon{False{}, power(p, q)}

def and_true(+x: Bool) -> {Bool.and(x, True{}) == x : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      {==}

def and_false(+x: Bool) -> {Bool.and(x, False{}) == False{} : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      {==}

def word_and_zero(+d: Nat, +w: Word(d)) -> {
  Word.and(d, w, Word.zero(d)) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{+x, +t}:
          %and_false(x) : {WCon{Bool.and(x, False{}), Word.and(p, t, Word.zero(p))} == WCon{_, Word.zero(p)} : Word(1n+p)}
          %word_and_zero(p, t) : {WCon{Bool.and(x, False{}), Word.and(p, t, Word.zero(p))} == WCon{Bool.and(x, False{}), _} : Word(1n+p)}
          {==}

def and_low_mask(+d: Nat, +k: Nat, +w: Word(d)) -> {
  Word.and(d, w, low_mask(d, k)) == low(d, k, w) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          word_and_zero(1n+p, w)
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              %and_true(x) : {WCon{Bool.and(x, True{}), Word.and(p, t, low_mask(p, q))} == WCon{_, low(p, q, t)} : Word(1n+p)}
              %and_low_mask(p, q, t) : {WCon{Bool.and(x, True{}), Word.and(p, t, low_mask(p, q))} == WCon{Bool.and(x, True{}), _} : Word(1n+p)}
              {==}

def put_zero(+d: Nat) -> {
  Word.shl.put(d, False{}, Word.zero(d)) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      %put_zero(p) : {WCon{False{}, Word.shl.put(p, False{}, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
      {==}

def put_one(+d: Nat) -> {
  Word.shl.put(d, True{}, Word.zero(d)) == power(d, 0n) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      %put_zero(p) : {WCon{True{}, Word.shl.put(p, False{}, Word.zero(p))} == WCon{True{}, _} : Word(1n+p)}
      {==}

def put_power(+d: Nat, +k: Nat) -> {
  Word.shl.put(d, False{}, power(d, k)) == power(d, 1n+k) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          %put_one(p) : {WCon{False{}, Word.shl.put(p, True{}, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case 1n+ +q:
          %put_power(p, q) : {WCon{False{}, Word.shl.put(p, False{}, power(p, q))} == WCon{False{}, _} : Word(1n+p)}
          {==}

def shl_power(+d: Nat, +k: Nat) -> {
  Word.shl(d, power(d, k)) == power(d, 1n+k) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          %put_one(p) : {WCon{False{}, Word.shl.put(p, True{}, Word.zero(p))} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case 1n+ +q:
          %put_power(p, q) : {WCon{False{}, Word.shl.put(p, False{}, power(p, q))} == WCon{False{}, _} : Word(1n+p)}
          {==}

def shln_one(+k: Nat) -> {U32.shln(1, k) == U32{power(32n, k)} : U32}:
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.trans(U32, U32.shl(U32.shln(1, q)), U32{Word.shl(32n, power(32n, q))},
        U32{power(32n, 1n+q)},
        Equal.cong(U32, U32, x => U32.shl(x), U32.shln(1, q), U32{power(32n, q)}, shln_one(q)),
        Equal.cong(Word(32n), U32, w => U32{w},
          Word.shl(32n, power(32n, q)), power(32n, 1n+q), shl_power(32n, q)))

def adc_zero(+d: Nat) -> {
  Word.adc(d, Word.zero(d), Word.zero(d), True{}, True{}) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      %adc_zero(p) : {WCon{False{}, Word.adc(p, Word.zero(p), Word.zero(p), True{}, True{})} == WCon{False{}, _} : Word(1n+p)}
      {==}

def pred_power(+d: Nat, +k: Nat) -> {
  Word.adc(d, power(d, k), Word.zero(d), True{}, False{}) == low_mask(d, k) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          %adc_zero(p) : {WCon{False{}, Word.adc(p, Word.zero(p), Word.zero(p), True{}, True{})} == WCon{False{}, _} : Word(1n+p)}
          {==}
        case 1n+ +q:
          %pred_power(p, q) : {WCon{True{}, Word.adc(p, power(p, q), Word.zero(p), True{}, False{})} == WCon{True{}, _} : Word(1n+p)}
          {==}

def sub_one_pred(+d: Nat, +w: Word(d)) -> {
  Word.sub(d, w, power(d, 0n)) == Word.adc(d, w, Word.zero(d), True{}, False{}) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{False{}, t}:
          {==}
        case WCon{True{}, t}:
          {==}

def mask_word(+n: U32) -> {Bits.mask(n) == U32{low_mask(32n, U32.to_nat(n))} : U32}:
  Equal.trans(U32, Bits.mask(n), U32{Word.sub(32n, power(32n, U32.to_nat(n)), power(32n, 0n))},
    U32{low_mask(32n, U32.to_nat(n))},
    Equal.cong(U32, U32, x => U32.sub(x, 1),
      U32.shln(1, U32.to_nat(n)), U32{power(32n, U32.to_nat(n))}, shln_one(U32.to_nat(n))),
    Equal.cong(Word(32n), U32, w => U32{w},
      Word.sub(32n, power(32n, U32.to_nat(n)), power(32n, 0n)), low_mask(32n, U32.to_nat(n)),
      Equal.trans(Word(32n), Word.sub(32n, power(32n, U32.to_nat(n)), power(32n, 0n)),
        Word.adc(32n, power(32n, U32.to_nat(n)), Word.zero(32n), True{}, False{}),
        low_mask(32n, U32.to_nat(n)), sub_one_pred(32n, power(32n, U32.to_nat(n))),
        pred_power(32n, U32.to_nat(n)))))

def word(v: U32) -> Word(32n):
  match v:
    case U32{w}:
      w

def and_mask_word(+v: U32, +n: U32) -> {
  U32.and(v, Bits.mask(n)) == U32{low(32n, U32.to_nat(n), word(v))} : U32}:
  match v:
    case U32{+w}:
      Equal.trans(U32, U32.and(U32{w}, Bits.mask(n)),
        U32{Word.and(32n, w, low_mask(32n, U32.to_nat(n)))},
        U32{low(32n, U32.to_nat(n), w)},
        Equal.cong(U32, U32, x => U32.and(U32{w}, x),
          Bits.mask(n), U32{low_mask(32n, U32.to_nat(n))}, mask_word(n)),
        Equal.cong(Word(32n), U32, x => U32{x},
          Word.and(32n, w, low_mask(32n, U32.to_nat(n))), low(32n, U32.to_nat(n), w),
          and_low_mask(32n, U32.to_nat(n), w)))

def pow2_pos(+k: Nat) -> MNat.lt(0n, Lemmas.pow2(k)):
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      Lemmas.bit_lt_double(False{}, 0n, Lemmas.pow2(q), pow2_pos(q))

def low_lt(+d: Nat, +k: Nat, +w: Word(d)) -> {
  Nat.is_lt(Word.to_nat(d, low(d, k, w)), Lemmas.pow2(k)) == True{} : Bool}:
  match d:
    case 0n:
      pow2_pos(k)
    case 1n+ +p:
      match k:
        case 0n:
          %Equal.sym(Nat, Word.to_nat(1n+p, Word.zero(1n+p)), 0n, Lemmas.word_zero_nat(1n+p)) : {Nat.is_lt(_, 1n) == True{} : Bool}
          {==}
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              %Lemmas.to_nat_con(p, x, low(p, q, t)) : {Nat.is_lt(_, Lemmas.pow2(1n+q)) == True{} : Bool}
              Lemmas.bit_lt_double(x, Word.to_nat(p, low(p, q, t)), Lemmas.pow2(q), low_lt(p, q, t))

def split_step(+x: Bool, +q: Nat, +r: Nat, +m: Nat, +a: Nat,
  e: {Nat.add(Nat.mul(q, m), r) == a : Nat}) -> {
  Nat.add(Nat.mul(q, Nat.double(m)), Lemmas.bit(x, r)) == Lemmas.bit(x, a) : Nat}:
  %MNat.mul_double_sym(q, m) : {Nat.add(_, Lemmas.bit(x, r)) == Lemmas.bit(x, a) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.double(Nat.mul(q, m)), Lemmas.bit(x, r)),
    Lemmas.bit(x, Nat.add(Nat.mul(q, m), r)), Lemmas.double_add_bit(x, Nat.mul(q, m), r)) :
    {_ == Lemmas.bit(x, a) : Nat}
  Equal.cong(Nat, Nat, z => Lemmas.bit(x, z), Nat.add(Nat.mul(q, m), r), a, e)

def low_high(+d: Nat, +k: Nat, +w: Word(d)) -> {
  Nat.add(Nat.mul(high(d, k, w), Lemmas.pow2(k)), Word.to_nat(d, low(d, k, w)))
  == Word.to_nat(d, w) : Nat}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          %Equal.sym(Nat, Word.to_nat(1n+p, Word.zero(1n+p)), 0n, Lemmas.word_zero_nat(1n+p)) :
            {Nat.add(Nat.mul(Word.to_nat(1n+p, w), 1n), _) == Word.to_nat(1n+p, w) : Nat}
          %Equal.sym(Nat, Nat.add(Nat.mul(Word.to_nat(1n+p, w), 1n), 0n),
            Nat.mul(Word.to_nat(1n+p, w), 1n), MNat.add_zero(Nat.mul(Word.to_nat(1n+p, w), 1n))) :
            {_ == Word.to_nat(1n+p, w) : Nat}
          MNat.mul_one(Word.to_nat(1n+p, w))
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              %Lemmas.to_nat_con(p, x, low(p, q, t)) :
                {Nat.add(Nat.mul(high(p, q, t), Lemmas.pow2(1n+q)), _) == Word.to_nat(1n+p, WCon{x, t}) : Nat}
              %Lemmas.to_nat_con(p, x, t) :
                {Nat.add(Nat.mul(high(p, q, t), Lemmas.pow2(1n+q)), Lemmas.bit(x, Word.to_nat(p, low(p, q, t)))) == _ : Nat}
              split_step(x, high(p, q, t), Word.to_nat(p, low(p, q, t)), Lemmas.pow2(q),
                Word.to_nat(p, t), low_high(p, q, t))

def low_mod(+d: Nat, +k: Nat, +w: Word(d)) -> {
  Word.to_nat(d, low(d, k, w)) == Nat.mod(Word.to_nat(d, w), Lemmas.pow2(k)) : Nat}:
  Lemmas.mod_unique(high(d, k, w), Word.to_nat(d, low(d, k, w)),
    Word.to_nat(d, w), Lemmas.pow2(k), low_lt(d, k, w), low_high(d, k, w))

def mask_mod(+v: U32, +n: U32, hn: MNat.le(U32.to_nat(n), 32n)) -> {
  U32.to_nat(U32.and(v, Bits.mask(n)))
  == Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  match v:
    case U32{+w}:
      Equal.trans(Nat, U32.to_nat(U32.and(U32{w}, Bits.mask(n))),
        Word.to_nat(32n, low(32n, U32.to_nat(n), w)),
        Nat.mod(Word.to_nat(32n, w), Lemmas.pow2(U32.to_nat(n))),
        Equal.cong(U32, Nat, x => U32.to_nat(x), U32.and(U32{w}, Bits.mask(n)),
          U32{low(32n, U32.to_nat(n), w)}, and_mask_word(U32{w}, n)),
        low_mod(32n, U32.to_nat(n), w))

def and_mask_small(+v: U32, +n: U32,
  hn: MNat.le(U32.to_nat(n), 32n),
  hv: MNat.lt(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n)))) -> {
  U32.and(v, Bits.mask(n)) == v : U32}:
  Lemmas.u32_to_nat_inj(U32.and(v, Bits.mask(n)), v,
    Equal.trans(Nat, U32.to_nat(U32.and(v, Bits.mask(n))),
      Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))), U32.to_nat(v),
      mask_mod(v, n, hn), MNat.mod_eq_of_lt(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n)), hv)))

def pow2_lt(+a: Nat, +b: Nat, h: MNat.lt(a, b)) -> MNat.lt(Lemmas.pow2(a), Lemmas.pow2(b)):
  match a b:
    case 0n 0n:
      Empty.absurd(MNat.lt(Lemmas.pow2(0n), Lemmas.pow2(0n)), MNat.lt_irrefl(0n)(h))
    case 0n 1n+ +q:
      Lemmas.odd_lt_double(0n, Lemmas.pow2(q), pow2_pos(q))
    case 1n+ +p 0n:
      Empty.absurd(MNat.lt(Lemmas.pow2(1n+p), Lemmas.pow2(0n)), MNat.lt_zero(1n+p)(h))
    case 1n+ +p 1n+ +q:
      MNat.double_lt_double(Lemmas.pow2(p), Lemmas.pow2(q), pow2_lt(p, q, h))

def power_nat(+d: Nat, +k: Nat, h: MNat.lt(k, d)) -> {
  Word.to_nat(d, power(d, k)) == Lemmas.pow2(k) : Nat}:
  match d:
    case 0n:
      Empty.absurd({Word.to_nat(0n, power(0n, k)) == Lemmas.pow2(k) : Nat}, MNat.lt_zero(k)(h))
    case 1n+ +p:
      match k:
        case 0n:
          %Equal.sym(Nat, Word.to_nat(p, Word.zero(p)), 0n, Lemmas.word_zero_nat(p)) :
            {1n+Nat.double(_) == 1n : Nat}
          {==}
        case 1n+ +q:
          Equal.cong(Nat, Nat, x => Nat.double(x), Word.to_nat(p, power(p, q)), Lemmas.pow2(q),
            power_nat(p, q, h))

def shln_one_nat(+k: Nat, h: MNat.lt(k, 32n)) -> {
  U32.to_nat(U32.shln(1, k)) == Lemmas.pow2(k) : Nat}:
  Equal.trans(Nat, U32.to_nat(U32.shln(1, k)), Word.to_nat(32n, power(32n, k)),
    Lemmas.pow2(k), Equal.cong(U32, Nat, x => U32.to_nat(x), U32.shln(1, k),
      U32{power(32n, k)}, shln_one(k)), power_nat(32n, k, h))

def pad_nat(+d: Nat, +w: Word(d)) -> {
  Word.to_nat(1n+d, Word.shr.pad(d, w)) == Word.to_nat(d, w) : Nat}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{False{}, +t}:
          Equal.cong(Nat, Nat, x => Nat.double(x),
            Word.to_nat(1n+p, Word.shr.pad(p, t)), Word.to_nat(p, t), pad_nat(p, t))
        case WCon{True{}, +t}:
          Equal.cong(Nat, Nat, x => 1n+Nat.double(x),
            Word.to_nat(1n+p, Word.shr.pad(p, t)), Word.to_nat(p, t), pad_nat(p, t))

def high_pad(+d: Nat, +k: Nat, +w: Word(d)) -> {
  high(1n+d, k, Word.shr.pad(d, w)) == high(d, k, w) : Nat}:
  match d:
    case 0n:
      match k:
        case 0n:
          {==}
        case 1n+q:
          {==}
    case 1n+ +p:
      match k:
        case 0n:
          pad_nat(1n+p, w)
        case 1n+ +q:
          match w:
            case WCon{x, +t}:
              high_pad(p, q, t)

def high_shr(+d: Nat, +k: Nat, +w: Word(d)) -> {
  high(d, k, Word.shr(d, w)) == high(d, 1n+k, w) : Nat}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{x, +t}:
          high_pad(p, k, t)

def shrn_step(+k: Nat, +v: U32) -> {
  U32.shrn(v, 1n+k) == U32.shrn(U32.shr(v), k) : U32}:
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.cong(U32, U32, x => U32.shr(x), U32.shrn(v, 1n+q),
        U32.shrn(U32.shr(v), q), shrn_step(q, v))

def shrn_high(+k: Nat, +v: U32) -> {
  U32.to_nat(U32.shrn(v, k)) == high(32n, k, word(v)) : Nat}:
  match k:
    case 0n:
      match v:
        case U32{w}:
          {==}
    case 1n+ +q:
      match v:
        case U32{+w}:
          Equal.trans(Nat, U32.to_nat(U32.shrn(U32{w}, 1n+q)),
            U32.to_nat(U32.shrn(U32.shr(U32{w}), q)), high(32n, 1n+q, w),
            Equal.cong(U32, Nat, x => U32.to_nat(x), U32.shrn(U32{w}, 1n+q),
              U32.shrn(U32.shr(U32{w}), q), shrn_step(q, U32{w})),
            Equal.trans(Nat, U32.to_nat(U32.shrn(U32.shr(U32{w}), q)),
              high(32n, q, Word.shr(32n, w)), high(32n, 1n+q, w),
              shrn_high(q, U32.shr(U32{w})), high_shr(32n, q, w)))

def high_div(+d: Nat, +k: Nat, +w: Word(d)) -> {
  high(d, k, w) == Nat.div(Word.to_nat(d, w), Lemmas.pow2(k)) : Nat}:
  Lemmas.div_unique(Lemmas.pow2(k), high(d, k, w), Word.to_nat(d, low(d, k, w)),
    Word.to_nat(d, w), pow2_pos(k), low_lt(d, k, w), low_high(d, k, w))

def shrn_nat(+v: U32, +k: Nat) -> {
  U32.to_nat(U32.shrn(v, k)) == Nat.div(U32.to_nat(v), Lemmas.pow2(k)) : Nat}:
  match v:
    case U32{+w}:
      Equal.trans(Nat, U32.to_nat(U32.shrn(U32{w}, k)), high(32n, k, w),
        Nat.div(Word.to_nat(32n, w), Lemmas.pow2(k)), shrn_high(k, U32{w}), high_div(32n, k, w))

def clear_low(+d: Nat, k: Nat, w: Word(d)) -> Word(d):
  match d:
    case 0n:
      WNil{}
    case 1n+p:
      match k:
        case 0n:
          w
        case 1n+q:
          match w:
            case WCon{x, t}:
              WCon{False{}, clear_low(p, q, t)}

def wshl(+k: Nat, +d: Nat, w: Word(d)) -> Word(d):
  match k:
    case 0n:
      w
    case 1n+q:
      Word.shl(d, wshl(q, d, w))

def wshr(+k: Nat, +d: Nat, w: Word(d)) -> Word(d):
  match k:
    case 0n:
      w
    case 1n+q:
      Word.shr(d, wshr(q, d, w))

def init(+d: Nat, w: Word(1n+d)) -> Word(d):
  match w:
    case WCon{x, t}:
      Word.shl.put(d, x, t)

def wshl_step(+k: Nat, +d: Nat, +w: Word(d)) -> {
  wshl(1n+k, d, w) == wshl(k, d, Word.shl(d, w)) : Word(d)}:
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.cong(Word(d), Word(d), x => Word.shl(d, x), wshl(1n+q, d, w),
        wshl(q, d, Word.shl(d, w)), wshl_step(q, d, w))

def wshr_step(+k: Nat, +d: Nat, +w: Word(d)) -> {
  wshr(1n+k, d, w) == wshr(k, d, Word.shr(d, w)) : Word(d)}:
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.cong(Word(d), Word(d), x => Word.shr(d, x), wshr(1n+q, d, w),
        wshr(q, d, Word.shr(d, w)), wshr_step(q, d, w))

def shr_pad(+d: Nat, +w: Word(d)) -> {
  Word.shr(1n+d, Word.shr.pad(d, w)) == Word.shr.pad(d, Word.shr(d, w)) : Word(1n+d)}:
  match d:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+ +p:
      match w:
        case WCon{x, t}:
          {==}

def wshr_pad(+k: Nat, +d: Nat, +w: Word(d)) -> {
  wshr(k, 1n+d, Word.shr.pad(d, w)) == Word.shr.pad(d, wshr(k, d, w)) : Word(1n+d)}:
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.trans(Word(1n+d), Word.shr(1n+d, wshr(q, 1n+d, Word.shr.pad(d, w))),
        Word.shr(1n+d, Word.shr.pad(d, wshr(q, d, w))),
        Word.shr.pad(d, Word.shr(d, wshr(q, d, w))),
        Equal.cong(Word(1n+d), Word(1n+d), x => Word.shr(1n+d, x),
          wshr(q, 1n+d, Word.shr.pad(d, w)), Word.shr.pad(d, wshr(q, d, w)), wshr_pad(q, d, w)),
        shr_pad(d, wshr(q, d, w)))

def wshr_con(+k: Nat, +d: Nat, +x: Bool, +t: Word(d)) -> {
  wshr(1n+k, 1n+d, WCon{x, t}) == Word.shr.pad(d, wshr(k, d, t)) : Word(1n+d)}:
  Equal.trans(Word(1n+d), wshr(1n+k, 1n+d, WCon{x, t}),
    wshr(k, 1n+d, Word.shr.pad(d, t)), Word.shr.pad(d, wshr(k, d, t)),
    wshr_step(k, 1n+d, WCon{x, t}), wshr_pad(k, d, t))

def shl_put_false(+d: Nat, +w: Word(d)) -> {
  Word.shl.put(d, False{}, w) == Word.shl(d, w) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{x, t}:
          {==}

def wshl_zero_con(+k: Nat, +d: Nat, +t: Word(d)) -> {
  wshl(k, 1n+d, WCon{False{}, t}) == WCon{False{}, wshl(k, d, t)} : Word(1n+d)}:
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.trans(Word(1n+d), Word.shl(1n+d, wshl(q, 1n+d, WCon{False{}, t})),
        WCon{False{}, Word.shl.put(d, False{}, wshl(q, d, t))},
        WCon{False{}, Word.shl(d, wshl(q, d, t))},
        Equal.cong(Word(1n+d), Word(1n+d), x => Word.shl(1n+d, x),
          wshl(q, 1n+d, WCon{False{}, t}), WCon{False{}, wshl(q, d, t)}, wshl_zero_con(q, d, t)),
        Equal.cong(Word(d), Word(1n+d), x => WCon{False{}, x},
          Word.shl.put(d, False{}, wshl(q, d, t)), Word.shl(d, wshl(q, d, t)), shl_put_false(d, wshl(q, d, t))))

def wshl_con(+k: Nat, +d: Nat, +w: Word(1n+d)) -> {
  wshl(1n+k, 1n+d, w) == WCon{False{}, wshl(k, d, init(d, w))} : Word(1n+d)}:
  match w:
    case WCon{+x, +t}:
      Equal.trans(Word(1n+d), wshl(1n+k, 1n+d, WCon{x, t}),
        wshl(k, 1n+d, WCon{False{}, Word.shl.put(d, x, t)}),
        WCon{False{}, wshl(k, d, Word.shl.put(d, x, t))},
        wshl_step(k, 1n+d, WCon{x, t}), wshl_zero_con(k, d, Word.shl.put(d, x, t)))

def put_pad(+d: Nat, +c: Bool, +w: Word(d)) -> {
  Word.shl.put(1n+d, c, Word.shr.pad(d, w)) == WCon{c, w} : Word(1n+d)}:
  match d:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+ +p:
      match w:
        case WCon{+x, +t}:
          Equal.cong(Word(1n+p), Word(2n+p), z => WCon{c, z},
            Word.shl.put(1n+p, x, Word.shr.pad(p, t)), WCon{x, t}, put_pad(p, x, t))

def shl_pad(+d: Nat, +w: Word(d)) -> {
  Word.shl(1n+d, Word.shr.pad(d, w)) == WCon{False{}, w} : Word(1n+d)}:
  Equal.trans(Word(1n+d), Word.shl(1n+d, Word.shr.pad(d, w)),
    Word.shl.put(1n+d, False{}, Word.shr.pad(d, w)), WCon{False{}, w},
    Equal.sym(Word(1n+d), Word.shl.put(1n+d, False{}, Word.shr.pad(d, w)),
      Word.shl(1n+d, Word.shr.pad(d, w)), shl_put_false(1n+d, Word.shr.pad(d, w))),
    put_pad(d, False{}, w))

def wshl_pad(+k: Nat, +d: Nat, +w: Word(d)) -> {
  wshl(1n+k, 1n+d, Word.shr.pad(d, w)) == WCon{False{}, wshl(k, d, w)} : Word(1n+d)}:
  Equal.trans(Word(1n+d), wshl(1n+k, 1n+d, Word.shr.pad(d, w)),
    wshl(k, 1n+d, Word.shl(1n+d, Word.shr.pad(d, w))), WCon{False{}, wshl(k, d, w)},
    wshl_step(k, 1n+d, Word.shr.pad(d, w)),
    Equal.trans(Word(1n+d), wshl(k, 1n+d, Word.shl(1n+d, Word.shr.pad(d, w))),
      wshl(k, 1n+d, WCon{False{}, w}), WCon{False{}, wshl(k, d, w)},
      Equal.cong(Word(1n+d), Word(1n+d), x => wshl(k, 1n+d, x),
        Word.shl(1n+d, Word.shr.pad(d, w)), WCon{False{}, w}, shl_pad(d, w)),
      wshl_zero_con(k, d, w)))

def low_all(+d: Nat, +w: Word(d)) -> {low(d, d, w) == w : Word(d)}:
  match d:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+ +p:
      match w:
        case WCon{+x, +t}:
          Equal.cong(Word(p), Word(1n+p), z => WCon{x, z}, low(p, p, t), t, low_all(p, t))

def pad_zero(+d: Nat) -> {Word.shr.pad(d, Word.zero(d)) == Word.zero(1n+d) : Word(1n+d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      Equal.cong(Word(1n+p), Word(2n+p), z => WCon{False{}, z},
        Word.shr.pad(p, Word.zero(p)), Word.zero(1n+p), pad_zero(p))

def pad_low_init(+d: Nat, +c: Nat, +w: Word(1n+d), hc: MNat.le(c, d)) -> {
  Word.shr.pad(d, low(d, c, init(d, w))) == low(1n+d, c, w) : Word(1n+d)}:
  match d:
    case 0n:
      match c:
        case 0n:
          {==}
        case 1n+q:
          Empty.absurd({Word.shr.pad(0n, low(0n, 1n+q, init(0n, w))) == low(1n, 1n+q, w) : Word(1n)},
            MNat.succ_ne_zero(q)(MNat.le_zero_eq(1n+q, hc)))
    case 1n+ +p:
      match c:
        case 0n:
          pad_zero(1n+p)
        case 1n+ +q:
          match w:
            case WCon{+x, WCon{+y, +t}}:
              Equal.cong(Word(1n+p), Word(2n+p), z => WCon{x, z},
                Word.shr.pad(p, low(p, q, init(p, WCon{y, t}))),
                low(1n+p, q, WCon{y, t}), pad_low_init(p, q, WCon{y, t}, hc))

def sum_right_le(+q: Nat, +c: Nat, +p: Nat, h: {Nat.add(q, c) == p : Nat}) -> MNat.le(c, p):
  %h : MNat.le(c, _)
  MNat.le_add_left(c, q)

def shr_shl(+d: Nat, +s: Nat, +c: Nat, +w: Word(d), +h: {Nat.add(s, c) == d : Nat}) -> {
  wshr(s, d, wshl(s, d, w)) == low(d, c, w) : Word(d)}:
  match d:
    case 0n:
      match s:
        case 0n:
          match w:
            case WNil{}:
              {==}
        case 1n+q:
          Empty.absurd({wshr(1n+q, 0n, wshl(1n+q, 0n, w)) == low(0n, c, w) : Word(0n)},
            MNat.succ_ne_zero(Nat.add(q, c))(h))
    case 1n+ +p:
      match s:
        case 0n:
          Equal.trans(Word(1n+p), w, low(1n+p, 1n+p, w), low(1n+p, c, w),
            Equal.sym(Word(1n+p), low(1n+p, 1n+p, w), w, low_all(1n+p, w)),
            Equal.cong(Nat, Word(1n+p), k => low(1n+p, k, w), 1n+p, c, Equal.sym(Nat, c, 1n+p, h)))
        case 1n+ +q:
          %Equal.sym(Word(1n+p), wshl(1n+q, 1n+p, w),
            WCon{False{}, wshl(q, p, init(p, w))}, wshl_con(q, p, w)) :
            {wshr(1n+q, 1n+p, _) == low(1n+p, c, w) : Word(1n+p)}
          %Equal.sym(Word(1n+p), wshr(1n+q, 1n+p, WCon{False{}, wshl(q, p, init(p, w))}),
            Word.shr.pad(p, wshr(q, p, wshl(q, p, init(p, w)))),
            wshr_con(q, p, False{}, wshl(q, p, init(p, w)))) :
            {_ == low(1n+p, c, w) : Word(1n+p)}
          %Equal.sym(Word(p), wshr(q, p, wshl(q, p, init(p, w))), low(p, c, init(p, w)),
            shr_shl(p, q, c, init(p, w), MNat.succ_inj(Nat.add(q, c), p, h))) :
            {Word.shr.pad(p, _) == low(1n+p, c, w) : Word(1n+p)}
          pad_low_init(p, c, w,
            sum_right_le(q, c, p, MNat.succ_inj(Nat.add(q, c), p, h)))

def shl_shr(+d: Nat, +k: Nat, +w: Word(d)) -> {
  wshl(k, d, wshr(k, d, w)) == clear_low(d, k, w) : Word(d)}:
  match d:
    case 0n:
      match k:
        case 0n:
          match w:
            case WNil{}:
              {==}
        case 1n+q:
          {==}
    case 1n+ +p:
      match k:
        case 0n:
          {==}
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              %Equal.sym(Word(1n+p), wshr(1n+q, 1n+p, WCon{x, t}),
                Word.shr.pad(p, wshr(q, p, t)), wshr_con(q, p, x, t)) :
                {wshl(1n+q, 1n+p, _) == WCon{False{}, clear_low(p, q, t)} : Word(1n+p)}
              %Equal.sym(Word(1n+p), wshl(1n+q, 1n+p, Word.shr.pad(p, wshr(q, p, t))),
                WCon{False{}, wshl(q, p, wshr(q, p, t))}, wshl_pad(q, p, wshr(q, p, t))) :
                {_ == WCon{False{}, clear_low(p, q, t)} : Word(1n+p)}
              Equal.cong(Word(p), Word(1n+p), z => WCon{False{}, z},
                wshl(q, p, wshr(q, p, t)), clear_low(p, q, t), shl_shr(p, q, t))

def or_false(+x: Bool) -> {Bool.or(x, False{}) == x : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      {==}

def or_comm(+x: Bool, +y: Bool) -> {Bool.or(x, y) == Bool.or(y, x) : Bool}:
  match x y:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def word_or_zero(+d: Nat, +w: Word(d)) -> {Word.or(d, w, Word.zero(d)) == w : Word(d)}:
  match d:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+ +p:
      match w:
        case WCon{+x, +t}:
          %or_false(x) : {WCon{Bool.or(x, False{}), Word.or(p, t, Word.zero(p))} == WCon{_, t} : Word(1n+p)}
          %word_or_zero(p, t) : {WCon{Bool.or(x, False{}), Word.or(p, t, Word.zero(p))} == WCon{Bool.or(x, False{}), _} : Word(1n+p)}
          {==}

def word_or_comm(+d: Nat, +a: Word(d), +b: Word(d)) -> {
  Word.or(d, a, b) == Word.or(d, b, a) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match a b:
        case WCon{+x, +at} WCon{+y, +bt}:
          %or_comm(x, y) : {WCon{Bool.or(x, y), Word.or(p, at, bt)} == WCon{_, Word.or(p, bt, at)} : Word(1n+p)}
          %word_or_comm(p, at, bt) : {WCon{Bool.or(x, y), Word.or(p, at, bt)} == WCon{Bool.or(x, y), _} : Word(1n+p)}
          {==}

def low_clear(+d: Nat, +k: Nat, +w: Word(d)) -> {
  Word.or(d, low(d, k, w), clear_low(d, k, w)) == w : Word(d)}:
  match d:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+ +p:
      match k:
        case 0n:
          Equal.trans(Word(1n+p), Word.or(1n+p, Word.zero(1n+p), w),
            Word.or(1n+p, w, Word.zero(1n+p)), w,
            word_or_comm(1n+p, Word.zero(1n+p), w), word_or_zero(1n+p, w))
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              %or_false(x) : {WCon{Bool.or(x, False{}), Word.or(p, low(p, q, t), clear_low(p, q, t))} == WCon{_, t} : Word(1n+p)}
              %low_clear(p, q, t) : {WCon{Bool.or(x, False{}), Word.or(p, low(p, q, t), clear_low(p, q, t))} == WCon{Bool.or(x, False{}), _} : Word(1n+p)}
              {==}

def recombine_left(+d: Nat, +s: Nat, +c: Nat, +w: Word(d), h: {Nat.add(s, c) == d : Nat}) -> {
  Word.or(d, wshr(s, d, wshl(s, d, w)), wshl(c, d, wshr(c, d, w))) == w : Word(d)}:
  %Equal.sym(Word(d), wshr(s, d, wshl(s, d, w)), low(d, c, w), shr_shl(d, s, c, w, h)) :
    {Word.or(d, _, wshl(c, d, wshr(c, d, w))) == w : Word(d)}
  %Equal.sym(Word(d), wshl(c, d, wshr(c, d, w)), clear_low(d, c, w), shl_shr(d, c, w)) :
    {Word.or(d, low(d, c, w), _) == w : Word(d)}
  low_clear(d, c, w)

def recombine_right(+d: Nat, +s: Nat, +c: Nat, +w: Word(d), h: {Nat.add(s, c) == d : Nat}) -> {
  Word.or(d, wshl(s, d, wshr(s, d, w)), wshr(c, d, wshl(c, d, w))) == w : Word(d)}:
  Equal.trans(Word(d),
    Word.or(d, wshl(s, d, wshr(s, d, w)), wshr(c, d, wshl(c, d, w))),
    Word.or(d, wshr(c, d, wshl(c, d, w)), wshl(s, d, wshr(s, d, w))), w,
    word_or_comm(d, wshl(s, d, wshr(s, d, w)), wshr(c, d, wshl(c, d, w))),
    recombine_left(d, c, s, w, Equal.trans(Nat, Nat.add(c, s), Nat.add(s, c), d, MNat.add_comm(c, s), h)))

def shln_word(+k: Nat, +v: U32) -> {U32.shln(v, k) == U32{wshl(k, 32n, word(v))} : U32}:
  match k:
    case 0n:
      match v:
        case U32{w}:
          {==}
    case 1n+ +q:
      match v:
        case U32{+w}:
          Equal.cong(U32, U32, x => U32.shl(x), U32.shln(U32{w}, q),
            U32{wshl(q, 32n, w)}, shln_word(q, U32{w}))

def shrn_word(+k: Nat, +v: U32) -> {U32.shrn(v, k) == U32{wshr(k, 32n, word(v))} : U32}:
  match k:
    case 0n:
      match v:
        case U32{w}:
          {==}
    case 1n+ +q:
      match v:
        case U32{+w}:
          Equal.cong(U32, U32, x => U32.shr(x), U32.shrn(U32{w}, q),
            U32{wshr(q, 32n, w)}, shrn_word(q, U32{w}))

def u32_recombine_left(+s: Nat, +c: Nat, +v: U32, h: {Nat.add(s, c) == 32n : Nat}) -> {
  U32.or(U32.shrn(U32.shln(v, s), s), U32.shln(U32.shrn(v, c), c)) == v : U32}:
  match v:
    case U32{+w}:
      %Equal.sym(U32, U32.shln(U32{w}, s), U32{wshl(s, 32n, w)}, shln_word(s, U32{w})) :
        {U32.or(U32.shrn(_, s), U32.shln(U32.shrn(U32{w}, c), c)) == U32{w} : U32}
      %Equal.sym(U32, U32.shrn(U32{wshl(s, 32n, w)}, s), U32{wshr(s, 32n, wshl(s, 32n, w))},
        shrn_word(s, U32{wshl(s, 32n, w)})) :
        {U32.or(_, U32.shln(U32.shrn(U32{w}, c), c)) == U32{w} : U32}
      %Equal.sym(U32, U32.shrn(U32{w}, c), U32{wshr(c, 32n, w)}, shrn_word(c, U32{w})) :
        {U32.or(U32{wshr(s, 32n, wshl(s, 32n, w))}, U32.shln(_, c)) == U32{w} : U32}
      %Equal.sym(U32, U32.shln(U32{wshr(c, 32n, w)}, c), U32{wshl(c, 32n, wshr(c, 32n, w))},
        shln_word(c, U32{wshr(c, 32n, w)})) :
        {U32.or(U32{wshr(s, 32n, wshl(s, 32n, w))}, _) == U32{w} : U32}
      Equal.cong(Word(32n), U32, x => U32{x},
        Word.or(32n, wshr(s, 32n, wshl(s, 32n, w)), wshl(c, 32n, wshr(c, 32n, w))), w,
        recombine_left(32n, s, c, w, h))

def pad_or(+d: Nat, +a: Word(d), +b: Word(d)) -> {
  Word.shr.pad(d, Word.or(d, a, b)) == Word.or(1n+d, Word.shr.pad(d, a), Word.shr.pad(d, b)) : Word(1n+d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match a b:
        case WCon{+x, +at} WCon{+y, +bt}:
          Equal.cong(Word(1n+p), Word(2n+p), z => WCon{Bool.or(x, y), z},
            Word.shr.pad(p, Word.or(p, at, bt)),
            Word.or(1n+p, Word.shr.pad(p, at), Word.shr.pad(p, bt)), pad_or(p, at, bt))

def shr_or(+d: Nat, +a: Word(d), +b: Word(d)) -> {
  Word.shr(d, Word.or(d, a, b)) == Word.or(d, Word.shr(d, a), Word.shr(d, b)) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match a b:
        case WCon{x, +at} WCon{y, +bt}:
          pad_or(p, at, bt)

def put_or(+d: Nat, +x: Bool, +y: Bool, +a: Word(d), +b: Word(d)) -> {
  Word.shl.put(d, Bool.or(x, y), Word.or(d, a, b))
  == Word.or(d, Word.shl.put(d, x, a), Word.shl.put(d, y, b)) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match a b:
        case WCon{+ah, +at} WCon{+bh, +bt}:
          Equal.cong(Word(p), Word(1n+p), z => WCon{Bool.or(x, y), z},
            Word.shl.put(p, Bool.or(ah, bh), Word.or(p, at, bt)),
            Word.or(p, Word.shl.put(p, ah, at), Word.shl.put(p, bh, bt)), put_or(p, ah, bh, at, bt))

def shl_or(+d: Nat, +a: Word(d), +b: Word(d)) -> {
  Word.shl(d, Word.or(d, a, b)) == Word.or(d, Word.shl(d, a), Word.shl(d, b)) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match a b:
        case WCon{+x, +at} WCon{+y, +bt}:
          Equal.cong(Word(p), Word(1n+p), z => WCon{False{}, z},
            Word.shl.put(p, Bool.or(x, y), Word.or(p, at, bt)),
            Word.or(p, Word.shl.put(p, x, at), Word.shl.put(p, y, bt)), put_or(p, x, y, at, bt))

def u32_shr_or(+a: U32, +b: U32) -> {
  U32.shr(U32.or(a, b)) == U32.or(U32.shr(a), U32.shr(b)) : U32}:
  match a b:
    case U32{+x} U32{+y}:
      Equal.cong(Word(32n), U32, w => U32{w}, Word.shr(32n, Word.or(32n, x, y)),
        Word.or(32n, Word.shr(32n, x), Word.shr(32n, y)), shr_or(32n, x, y))

def u32_shl_or(+a: U32, +b: U32) -> {
  U32.shl(U32.or(a, b)) == U32.or(U32.shl(a), U32.shl(b)) : U32}:
  match a b:
    case U32{+x} U32{+y}:
      Equal.cong(Word(32n), U32, w => U32{w}, Word.shl(32n, Word.or(32n, x, y)),
        Word.or(32n, Word.shl(32n, x), Word.shl(32n, y)), shl_or(32n, x, y))

def shrn_or(+k: Nat, +a: U32, +b: U32) -> {
  U32.shrn(U32.or(a, b), k) == U32.or(U32.shrn(a, k), U32.shrn(b, k)) : U32}:
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      %Equal.sym(U32, U32.shrn(U32.or(a, b), q), U32.or(U32.shrn(a, q), U32.shrn(b, q)), shrn_or(q, a, b)) :
        {U32.shr(_) == U32.or(U32.shr(U32.shrn(a, q)), U32.shr(U32.shrn(b, q))) : U32}
      u32_shr_or(U32.shrn(a, q), U32.shrn(b, q))

def shln_or(+k: Nat, +a: U32, +b: U32) -> {
  U32.shln(U32.or(a, b), k) == U32.or(U32.shln(a, k), U32.shln(b, k)) : U32}:
  match k:
    case 0n:
      {==}
    case 1n+ +q:
      %Equal.sym(U32, U32.shln(U32.or(a, b), q), U32.or(U32.shln(a, q), U32.shln(b, q)), shln_or(q, a, b)) :
        {U32.shl(_) == U32.or(U32.shl(U32.shln(a, q)), U32.shl(U32.shln(b, q))) : U32}
      u32_shl_or(U32.shln(a, q), U32.shln(b, q))

def partition_bit(+x: Bool, +m: Bool) -> {
  Bool.or(Bool.and(x, m), Bool.and(x, Bool.not(m))) == x : Bool}:
  match x m:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def word_partition(+d: Nat, +w: Word(d), +m: Word(d)) -> {
  Word.or(d, Word.and(d, w, m), Word.and(d, w, Word.not(d, m))) == w : Word(d)}:
  match d:
    case 0n:
      match w:
        case WNil{}:
          {==}
    case 1n+ +p:
      match w m:
        case WCon{+x, +t} WCon{+mh, +mt}:
          %partition_bit(x, mh) : {
            WCon{Bool.or(Bool.and(x, mh), Bool.and(x, Bool.not(mh))),
              Word.or(p, Word.and(p, t, mt), Word.and(p, t, Word.not(p, mt)))} == WCon{_, t} : Word(1n+p)}
          %word_partition(p, t, mt) : {
            WCon{Bool.or(Bool.and(x, mh), Bool.and(x, Bool.not(mh))),
              Word.or(p, Word.and(p, t, mt), Word.and(p, t, Word.not(p, mt)))} ==
            WCon{Bool.or(Bool.and(x, mh), Bool.and(x, Bool.not(mh))), _} : Word(1n+p)}
          {==}

def prefix_low(+d: Nat, +k: Nat, +w: Word(d),
  h: {Word.and(d, w, Word.not(d, low_mask(d, k))) == Word.zero(d) : Word(d)}) -> {
  w == low(d, k, w) : Word(d)}:
  Equal.trans(Word(d), w,
    Word.or(d, Word.and(d, w, low_mask(d, k)), Word.and(d, w, Word.not(d, low_mask(d, k)))),
    low(d, k, w),
    Equal.sym(Word(d),
      Word.or(d, Word.and(d, w, low_mask(d, k)), Word.and(d, w, Word.not(d, low_mask(d, k)))), w,
      word_partition(d, w, low_mask(d, k))),
    Equal.trans(Word(d),
      Word.or(d, Word.and(d, w, low_mask(d, k)), Word.and(d, w, Word.not(d, low_mask(d, k)))),
      Word.or(d, Word.and(d, w, low_mask(d, k)), Word.zero(d)), low(d, k, w),
      Equal.cong(Word(d), Word(d), x => Word.or(d, Word.and(d, w, low_mask(d, k)), x),
        Word.and(d, w, Word.not(d, low_mask(d, k))), Word.zero(d), h),
      Equal.trans(Word(d), Word.or(d, Word.and(d, w, low_mask(d, k)), Word.zero(d)),
        Word.and(d, w, low_mask(d, k)), low(d, k, w),
        word_or_zero(d, Word.and(d, w, low_mask(d, k))), and_low_mask(d, k, w))))

def high_low(+d: Nat, +k: Nat, +w: Word(d)) -> {high(d, k, low(d, k, w)) == 0n : Nat}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          Lemmas.word_zero_nat(1n+p)
        case 1n+ +q:
          match w:
            case WCon{x, +t}:
              high_low(p, q, t)

def u32_prefix_low(+v: U32, +n: U32, h: {U32.and(v, U32.not(Bits.mask(n))) == 0 : U32}) -> {
  v == U32{low(32n, U32.to_nat(n), word(v))} : U32}:
  match v:
    case U32{+w}:
      Equal.cong(Word(32n), U32, x => U32{x}, w, low(32n, U32.to_nat(n), w),
        prefix_low(32n, U32.to_nat(n), w,
          Equal.cong(U32, Word(32n), word,
            U32{Word.and(32n, w, Word.not(32n, low_mask(32n, U32.to_nat(n))))}, 0,
            Equal.trans(U32, U32.and(U32{w}, U32.not(U32{low_mask(32n, U32.to_nat(n))})),
              U32.and(U32{w}, U32.not(Bits.mask(n))), 0,
              Equal.sym(U32, U32.and(U32{w}, U32.not(Bits.mask(n))),
                U32.and(U32{w}, U32.not(U32{low_mask(32n, U32.to_nat(n))})),
                Equal.cong(U32, U32, x => U32.and(U32{w}, U32.not(x)),
                  Bits.mask(n), U32{low_mask(32n, U32.to_nat(n))}, mask_word(n))), h))))

def prefix_shr_zero(+v: U32, +n: U32, h: {U32.and(v, U32.not(Bits.mask(n))) == 0 : U32}) -> {
  U32.shrn(v, U32.to_nat(n)) == 0 : U32}:
  match v:
    case U32{+w}:
      Lemmas.u32_to_nat_inj(U32.shrn(U32{w}, U32.to_nat(n)), 0,
        Equal.trans(Nat, U32.to_nat(U32.shrn(U32{w}, U32.to_nat(n))),
          high(32n, U32.to_nat(n), w), 0n, shrn_high(U32.to_nat(n), U32{w}),
          Equal.trans(Nat, high(32n, U32.to_nat(n), w),
            high(32n, U32.to_nat(n), low(32n, U32.to_nat(n), w)), 0n,
            Equal.cong(U32, Nat, x => high(32n, U32.to_nat(n), word(x)),
              U32{w}, U32{low(32n, U32.to_nat(n), w)}, u32_prefix_low(U32{w}, n, h)),
            high_low(32n, U32.to_nat(n), w))))

def u32_zero_or(+v: U32) -> {U32.or(0, v) == v : U32}:
  match v:
    case U32{+w}:
      Equal.cong(Word(32n), U32, x => U32{x}, Word.or(32n, Word.zero(32n), w), w,
        Equal.trans(Word(32n), Word.or(32n, Word.zero(32n), w), Word.or(32n, w, Word.zero(32n)), w,
          word_or_comm(32n, Word.zero(32n), w), word_or_zero(32n, w)))

def complement_sum(+s: U32, +hs: MNat.le(U32.to_nat(s), 32n)) -> {
  Nat.add(U32.to_nat(s), U32.to_nat(U32.sub(32, s))) == 32n : Nat}:
  %Equal.sym(Nat, U32.to_nat(U32.sub(32, s)), Nat.sub(32n, U32.to_nat(s)), Lemmas.u32_sub_nat(32, s, hs)) :
    {Nat.add(U32.to_nat(s), _) == 32n : Nat}
  %MNat.add_comm(Nat.sub(32n, U32.to_nat(s)), U32.to_nat(s)) : {_ == 32n : Nat}
  MNat.sub_add_cancel(32n, U32.to_nat(s), hs)

def lsb_join(+s: U32, lo: U32, hi: U32) -> U32:
  U32.or(U32.shrn(lo, U32.to_nat(s)), U32.shln(hi, U32.to_nat(U32.sub(32, s))))

def lsb_recover(+s: U32, +v: U32, +lo: U32,
  hs: MNat.le(U32.to_nat(s), 32n), hl: {U32.and(lo, U32.not(Bits.mask(s))) == 0 : U32}) -> {
  lsb_join(s, U32.or(lo, U32.shln(v, U32.to_nat(s))), U32.shrn(v, U32.to_nat(U32.sub(32, s))))
  == v : U32}:
  %Equal.sym(U32, U32.shrn(U32.or(lo, U32.shln(v, U32.to_nat(s))), U32.to_nat(s)),
    U32.or(U32.shrn(lo, U32.to_nat(s)), U32.shrn(U32.shln(v, U32.to_nat(s)), U32.to_nat(s))),
    shrn_or(U32.to_nat(s), lo, U32.shln(v, U32.to_nat(s)))) :
    {U32.or(_, U32.shln(U32.shrn(v, U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, s)))) == v : U32}
  %Equal.sym(U32, U32.shrn(lo, U32.to_nat(s)), 0, prefix_shr_zero(lo, s, hl)) :
    {U32.or(U32.or(_, U32.shrn(U32.shln(v, U32.to_nat(s)), U32.to_nat(s))),
      U32.shln(U32.shrn(v, U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, s)))) == v : U32}
  %Equal.sym(U32, U32.or(0, U32.shrn(U32.shln(v, U32.to_nat(s)), U32.to_nat(s))),
    U32.shrn(U32.shln(v, U32.to_nat(s)), U32.to_nat(s)),
    u32_zero_or(U32.shrn(U32.shln(v, U32.to_nat(s)), U32.to_nat(s)))) :
    {U32.or(_, U32.shln(U32.shrn(v, U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, s)))) == v : U32}
  u32_recombine_left(U32.to_nat(s), U32.to_nat(U32.sub(32, s)), v, complement_sum(s, hs))

def mask_lt(+v: U32, +n: U32) -> MNat.lt(U32.to_nat(U32.and(v, Bits.mask(n))), Lemmas.pow2(U32.to_nat(n))):
  match v:
    case U32{+w}:
      %Equal.sym(U32, U32.and(U32{w}, Bits.mask(n)), U32{low(32n, U32.to_nat(n), w)}, and_mask_word(U32{w}, n)) :
        MNat.lt(U32.to_nat(_), Lemmas.pow2(U32.to_nat(n)))
      low_lt(32n, U32.to_nat(n), w)

def lsb_after.parts(+s: U32, +n: U32, lo: U32, x: U32 & U32) -> U32:
  (x0, x1) = x
  Bits.field(False{}, n, lsb_join(s, U32.or(lo, x0), x1))

def lsb_after(+s: U32, +n: U32, v: U32, lo: U32) -> U32:
  lsb_after.parts(s, n, lo, Bits.parts(False{}, s, n, v))

def lsb_field(+s: U32, +n: U32, +v: U32, +lo: U32,
  hs: MNat.le(U32.to_nat(s), 32n), +hn: MNat.le(U32.to_nat(n), 32n),
  hl: {U32.and(lo, U32.not(Bits.mask(s))) == 0 : U32}) -> {
  lsb_after(s, n, v, lo) == U32.and(v, Bits.mask(n)) : U32}:
  Equal.trans(U32, lsb_after(s, n, v, lo), U32.and(U32.and(v, Bits.mask(n)), Bits.mask(n)),
    U32.and(v, Bits.mask(n)),
    Equal.cong(U32, U32, w => U32.and(w, Bits.mask(n)),
      lsb_join(s, U32.or(lo, U32.shln(U32.and(v, Bits.mask(n)), U32.to_nat(s))),
        U32.shrn(U32.and(v, Bits.mask(n)), U32.to_nat(U32.sub(32, s)))),
      U32.and(v, Bits.mask(n)), lsb_recover(s, U32.and(v, Bits.mask(n)), lo, hs, hl)),
    and_mask_small(U32.and(v, Bits.mask(n)), n, hn, mask_lt(v, n)))

def lsb_roundtrip(+s: U32, +n: U32, +v: U32, +lo: U32,
  hs: MNat.le(U32.to_nat(s), 31n), +hn: MNat.le(U32.to_nat(n), 32n),
  hl: {U32.and(lo, U32.not(Bits.mask(s))) == 0 : U32}) -> {
  U32.to_nat(lsb_after(s, n, v, lo)) == Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  Equal.trans(Nat, U32.to_nat(lsb_after(s, n, v, lo)), U32.to_nat(U32.and(v, Bits.mask(n))),
    Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))),
    Equal.cong(U32, Nat, x => U32.to_nat(x), lsb_after(s, n, v, lo), U32.and(v, Bits.mask(n)),
      lsb_field(s, n, v, lo, MNat.le_trans(U32.to_nat(s), 31n, 32n, hs, {==}), hn, hl)),
    mask_mod(v, n, hn))

def swap_bit1(+x: Bool) -> {Bool.or(Bool.and(x, True{}), False{}) == x : Bool}:
  match x:
    case False{}:
      {==}
    case True{}:
      {==}

def swap_bit2(+x: Bool, +y: Bool) -> {
  Bool.or(Bool.or(Bool.and(x, True{}), Bool.and(y, False{})), False{}) == x : Bool}:
  match x y:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def swap_bit3(+x: Bool, +y: Bool) -> {
  Bool.or(Bool.or(Bool.or(Bool.and(x, True{}), Bool.and(y, False{})), False{}), False{}) == x : Bool}:
  match x y:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

# One structural spine match; no enumeration of words or offsets.
def swap_raw(v: U32) -> U32:
  match v:
    case U32{WCon{+x0, WCon{+x1, WCon{+x2, WCon{+x3, WCon{+x4, WCon{+x5, WCon{+x6, WCon{+x7, WCon{+x8, WCon{+x9, WCon{+x10, WCon{+x11, WCon{+x12, WCon{+x13, WCon{+x14, WCon{+x15, WCon{+x16, WCon{+x17, WCon{+x18, WCon{+x19, WCon{+x20, WCon{+x21, WCon{+x22, WCon{+x23, WCon{+x24, WCon{+x25, WCon{+x26, WCon{+x27, WCon{+x28, WCon{+x29, WCon{+x30, WCon{+x31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      U32{WCon{x24, WCon{x25, WCon{x26, WCon{x27, WCon{x28, WCon{x29, WCon{x30, WCon{x31, WCon{x16, WCon{x17, WCon{x18, WCon{x19, WCon{x20, WCon{x21, WCon{x22, WCon{x23, WCon{x8, WCon{x9, WCon{x10, WCon{x11, WCon{x12, WCon{x13, WCon{x14, WCon{x15, WCon{x0, WCon{x1, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}

def bswap_eq(+v: U32) -> {Bytes.bswap(v) == swap_raw(v) : U32}:
  match v:
    case U32{WCon{+x0, WCon{+x1, WCon{+x2, WCon{+x3, WCon{+x4, WCon{+x5, WCon{+x6, WCon{+x7, WCon{+x8, WCon{+x9, WCon{+x10, WCon{+x11, WCon{+x12, WCon{+x13, WCon{+x14, WCon{+x15, WCon{+x16, WCon{+x17, WCon{+x18, WCon{+x19, WCon{+x20, WCon{+x21, WCon{+x22, WCon{+x23, WCon{+x24, WCon{+x25, WCon{+x26, WCon{+x27, WCon{+x28, WCon{+x29, WCon{+x30, WCon{+x31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      WProof.u32_ext(Bytes.bswap(U32{WCon{x0, WCon{x1, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, WCon{x8, WCon{x9, WCon{x10, WCon{x11, WCon{x12, WCon{x13, WCon{x14, WCon{x15, WCon{x16, WCon{x17, WCon{x18, WCon{x19, WCon{x20, WCon{x21, WCon{x22, WCon{x23, WCon{x24, WCon{x25, WCon{x26, WCon{x27, WCon{x28, WCon{x29, WCon{x30, WCon{x31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}), U32{WCon{x24, WCon{x25, WCon{x26, WCon{x27, WCon{x28, WCon{x29, WCon{x30, WCon{x31, WCon{x16, WCon{x17, WCon{x18, WCon{x19, WCon{x20, WCon{x21, WCon{x22, WCon{x23, WCon{x8, WCon{x9, WCon{x10, WCon{x11, WCon{x12, WCon{x13, WCon{x14, WCon{x15, WCon{x0, WCon{x1, WCon{x2, WCon{x3, WCon{x4, WCon{x5, WCon{x6, WCon{x7, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}},
        ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, ({==}, (swap_bit1(x16), (swap_bit1(x17), (swap_bit1(x18), (swap_bit1(x19), (swap_bit1(x20), (swap_bit1(x21), (swap_bit1(x22), (swap_bit1(x23), (swap_bit2(x8, x24), (swap_bit2(x9, x25), (swap_bit2(x10, x26), (swap_bit2(x11, x27), (swap_bit2(x12, x28), (swap_bit2(x13, x29), (swap_bit2(x14, x30), (swap_bit2(x15, x31), (swap_bit3(x0, x16), (swap_bit3(x1, x17), (swap_bit3(x2, x18), (swap_bit3(x3, x19), (swap_bit3(x4, x20), (swap_bit3(x5, x21), (swap_bit3(x6, x22), (swap_bit3(x7, x23), Unit{})))))))))))))))))))))))))))))))))

def swap_raw_invol(+v: U32) -> {swap_raw(swap_raw(v)) == v : U32}:
  match v:
    case U32{WCon{+x0, WCon{+x1, WCon{+x2, WCon{+x3, WCon{+x4, WCon{+x5, WCon{+x6, WCon{+x7, WCon{+x8, WCon{+x9, WCon{+x10, WCon{+x11, WCon{+x12, WCon{+x13, WCon{+x14, WCon{+x15, WCon{+x16, WCon{+x17, WCon{+x18, WCon{+x19, WCon{+x20, WCon{+x21, WCon{+x22, WCon{+x23, WCon{+x24, WCon{+x25, WCon{+x26, WCon{+x27, WCon{+x28, WCon{+x29, WCon{+x30, WCon{+x31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}

def swap_raw_or(+a: U32, +b: U32) -> {swap_raw(U32.or(a, b)) == U32.or(swap_raw(a), swap_raw(b)) : U32}:
  match a b:
    case U32{WCon{+x0, WCon{+x1, WCon{+x2, WCon{+x3, WCon{+x4, WCon{+x5, WCon{+x6, WCon{+x7, WCon{+x8, WCon{+x9, WCon{+x10, WCon{+x11, WCon{+x12, WCon{+x13, WCon{+x14, WCon{+x15, WCon{+x16, WCon{+x17, WCon{+x18, WCon{+x19, WCon{+x20, WCon{+x21, WCon{+x22, WCon{+x23, WCon{+x24, WCon{+x25, WCon{+x26, WCon{+x27, WCon{+x28, WCon{+x29, WCon{+x30, WCon{+x31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}} U32{WCon{+y0, WCon{+y1, WCon{+y2, WCon{+y3, WCon{+y4, WCon{+y5, WCon{+y6, WCon{+y7, WCon{+y8, WCon{+y9, WCon{+y10, WCon{+y11, WCon{+y12, WCon{+y13, WCon{+y14, WCon{+y15, WCon{+y16, WCon{+y17, WCon{+y18, WCon{+y19, WCon{+y20, WCon{+y21, WCon{+y22, WCon{+y23, WCon{+y24, WCon{+y25, WCon{+y26, WCon{+y27, WCon{+y28, WCon{+y29, WCon{+y30, WCon{+y31, WNil{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}:
      {==}

def bswap_invol(+v: U32) -> {Bytes.bswap(Bytes.bswap(v)) == v : U32}:
  Equal.trans(U32, Bytes.bswap(Bytes.bswap(v)), swap_raw(Bytes.bswap(v)), v,
    bswap_eq(Bytes.bswap(v)),
    Equal.trans(U32, swap_raw(Bytes.bswap(v)), swap_raw(swap_raw(v)), v,
      Equal.cong(U32, U32, swap_raw, Bytes.bswap(v), swap_raw(v), bswap_eq(v)), swap_raw_invol(v)))

def bswap_or(+a: U32, +b: U32) -> {
  Bytes.bswap(U32.or(a, b)) == U32.or(Bytes.bswap(a), Bytes.bswap(b)) : U32}:
  %Equal.sym(U32, Bytes.bswap(a), swap_raw(a), bswap_eq(a)) :
    {Bytes.bswap(U32.or(a, b)) == U32.or(_, Bytes.bswap(b)) : U32}
  %Equal.sym(U32, Bytes.bswap(b), swap_raw(b), bswap_eq(b)) :
    {Bytes.bswap(U32.or(a, b)) == U32.or(swap_raw(a), _) : U32}
  %Equal.sym(U32, Bytes.bswap(U32.or(a, b)), swap_raw(U32.or(a, b)), bswap_eq(U32.or(a, b))) :
    {_ == U32.or(swap_raw(a), swap_raw(b)) : U32}
  swap_raw_or(a, b)

def double_mod(+a: Nat, +m: Nat) -> {
  Nat.mod(Nat.double(Nat.mod(a, m)), m) == Nat.mod(Nat.double(a), m) : Nat}:
  Equal.trans(Nat, Nat.mod(Nat.double(Nat.mod(a, m)), m),
    Nat.mod(Nat.add(Nat.mod(a, m), Nat.mod(a, m)), m), Nat.mod(Nat.double(a), m),
    Equal.cong(Nat, Nat, x => Nat.mod(x, m), Nat.double(Nat.mod(a, m)),
      Nat.add(Nat.mod(a, m), Nat.mod(a, m)), MNat.double_eq_add(Nat.mod(a, m))),
    Equal.trans(Nat, Nat.mod(Nat.add(Nat.mod(a, m), Nat.mod(a, m)), m),
      Nat.mod(Nat.add(a, Nat.mod(a, m)), m), Nat.mod(Nat.double(a), m),
      Lemmas.mod_add_left(a, Nat.mod(a, m), m),
      Equal.trans(Nat, Nat.mod(Nat.add(a, Nat.mod(a, m)), m),
        Nat.mod(Nat.add(a, a), m), Nat.mod(Nat.double(a), m), Lemmas.mod_add_right(a, a, m),
        Equal.cong(Nat, Nat, x => Nat.mod(x, m), Nat.add(a, a), Nat.double(a),
          Equal.sym(Nat, Nat.double(a), Nat.add(a, a), MNat.double_eq_add(a))))))

# Keep U32 refinement outside the folded modulus goal: https://github.com/bendlang/bend/issues/1071.
def word_nat(+v: U32) -> {Word.to_nat(32n, word(v)) == U32.to_nat(v) : Nat}:
  match v:
    case U32{w}:
      {==}

def shift_nat(+v: U32) -> {Word.to_nat(32n, Word.shl(32n, word(v))) == U32.to_nat(U32.shl(v)) : Nat}:
  match v:
    case U32{w}:
      {==}

def u32_shl_mod(+v: U32) -> {
  U32.to_nat(U32.shl(v)) == Nat.mod(Nat.double(U32.to_nat(v)), Lemmas.pow2(32n)) : Nat}:
  %shift_nat(v) : {_ == Nat.mod(Nat.double(U32.to_nat(v)), Lemmas.pow2(32n)) : Nat}
  %word_nat(v) : {Word.to_nat(32n, Word.shl(32n, word(v))) == Nat.mod(Nat.double(_), Lemmas.pow2(32n)) : Nat}
  Lemmas.word_shl_mod(32n, word(v))

def word_shln_mod(+k: Nat, +d: Nat, +w: Word(d)) -> {
  Word.to_nat(d, wshl(k, d, w)) == Nat.mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(k)), Lemmas.pow2(d)) : Nat}:
  match k:
    case 0n:
      Equal.trans(Nat, Word.to_nat(d, w), Nat.mod(Word.to_nat(d, w), Lemmas.pow2(d)),
        Nat.mod(Nat.mul(Word.to_nat(d, w), 1n), Lemmas.pow2(d)),
        Equal.sym(Nat, Nat.mod(Word.to_nat(d, w), Lemmas.pow2(d)), Word.to_nat(d, w),
          MNat.mod_eq_of_lt(Word.to_nat(d, w), Lemmas.pow2(d), Lemmas.word_to_nat_lt(d, w))),
        Equal.cong(Nat, Nat, x => Nat.mod(x, Lemmas.pow2(d)), Word.to_nat(d, w), Nat.mul(Word.to_nat(d, w), 1n),
          Equal.sym(Nat, Nat.mul(Word.to_nat(d, w), 1n), Word.to_nat(d, w), MNat.mul_one(Word.to_nat(d, w)))))
    case 1n+ +q:
      Equal.trans(Nat, Word.to_nat(d, Word.shl(d, wshl(q, d, w))),
        Nat.mod(Nat.double(Word.to_nat(d, wshl(q, d, w))), Lemmas.pow2(d)),
        Nat.mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(1n+q)), Lemmas.pow2(d)),
        Lemmas.word_shl_mod(d, wshl(q, d, w)),
        Equal.trans(Nat, Nat.mod(Nat.double(Word.to_nat(d, wshl(q, d, w))), Lemmas.pow2(d)),
          Nat.mod(Nat.double(Nat.mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(q)), Lemmas.pow2(d))), Lemmas.pow2(d)),
          Nat.mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(1n+q)), Lemmas.pow2(d)),
          Equal.cong(Nat, Nat, x => Nat.mod(Nat.double(x), Lemmas.pow2(d)), Word.to_nat(d, wshl(q, d, w)),
            Nat.mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(q)), Lemmas.pow2(d)), word_shln_mod(q, d, w)),
          Equal.trans(Nat,
            Nat.mod(Nat.double(Nat.mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(q)), Lemmas.pow2(d))), Lemmas.pow2(d)),
            Nat.mod(Nat.double(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(q))), Lemmas.pow2(d)),
            Nat.mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(1n+q)), Lemmas.pow2(d)),
            double_mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(q)), Lemmas.pow2(d)),
            Equal.cong(Nat, Nat, x => Nat.mod(x, Lemmas.pow2(d)),
              Nat.double(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(q))), Nat.mul(Word.to_nat(d, w), Lemmas.pow2(1n+q)),
              MNat.mul_double_sym(Word.to_nat(d, w), Lemmas.pow2(q))))))

def shln_word_nat(+k: Nat, +v: U32) -> {
  Word.to_nat(32n, wshl(k, 32n, word(v))) == U32.to_nat(U32.shln(v, k)) : Nat}:
  %Equal.sym(U32, U32.shln(v, k), U32{wshl(k, 32n, word(v))}, shln_word(k, v)) :
    {Word.to_nat(32n, wshl(k, 32n, word(v))) == U32.to_nat(_) : Nat}
  {==}

def shln_mod(+k: Nat, +v: U32) -> {
  U32.to_nat(U32.shln(v, k)) == Nat.mod(Nat.mul(U32.to_nat(v), Lemmas.pow2(k)), Lemmas.pow2(32n)) : Nat}:
  %shln_word_nat(k, v) : {_ == Nat.mod(Nat.mul(U32.to_nat(v), Lemmas.pow2(k)), Lemmas.pow2(32n)) : Nat}
  %word_nat(v) : {Word.to_nat(32n, wshl(k, 32n, word(v))) == Nat.mod(Nat.mul(_, Lemmas.pow2(k)), Lemmas.pow2(32n)) : Nat}
  word_shln_mod(k, 32n, word(v))

def shln_nat(+v: U32, +k: Nat,
  h: MNat.lt(Nat.mul(U32.to_nat(v), Lemmas.pow2(k)), Lemmas.pow2(32n))) -> {
  U32.to_nat(U32.shln(v, k)) == Nat.mul(U32.to_nat(v), Lemmas.pow2(k)) : Nat}:
  Equal.trans(Nat, U32.to_nat(U32.shln(v, k)),
    Nat.mod(Nat.mul(U32.to_nat(v), Lemmas.pow2(k)), Lemmas.pow2(32n)),
    Nat.mul(U32.to_nat(v), Lemmas.pow2(k)), shln_mod(k, v),
    MNat.mod_eq_of_lt(Nat.mul(U32.to_nat(v), Lemmas.pow2(k)), Lemmas.pow2(32n), h))

def pow2_add(+a: Nat, +b: Nat) -> {
  Lemmas.pow2(Nat.add(a, b)) == Nat.mul(Lemmas.pow2(a), Lemmas.pow2(b)) : Nat}:
  match a:
    case 0n:
      Equal.sym(Nat, Nat.mul(1n, Lemmas.pow2(b)), Lemmas.pow2(b), MNat.one_mul(Lemmas.pow2(b)))
    case 1n+ +p:
      Equal.trans(Nat, Nat.double(Lemmas.pow2(Nat.add(p, b))),
        Nat.double(Nat.mul(Lemmas.pow2(p), Lemmas.pow2(b))),
        Nat.mul(Nat.double(Lemmas.pow2(p)), Lemmas.pow2(b)),
        Equal.cong(Nat, Nat, Nat.double, Lemmas.pow2(Nat.add(p, b)),
          Nat.mul(Lemmas.pow2(p), Lemmas.pow2(b)), pow2_add(p, b)),
        MNat.double_mul(Lemmas.pow2(p), Lemmas.pow2(b)))

def remove_zero_rem(+q: Nat, +b: Nat, +a: Nat, +r: Nat,
  e: {Nat.add(Nat.mul(q, b), r) == a : Nat}, hr: {r == 0n : Nat}) -> {Nat.mul(q, b) == a : Nat}:
  %MNat.add_zero(Nat.mul(q, b)) : {_ == a : Nat}
  %hr : {Nat.add(Nat.mul(q, b), _) == a : Nat}
  e

def low_zero_multiple(+v: U32, +n: U32, h: {U32.and(v, Bits.mask(n)) == 0 : U32}) -> {
  Nat.mul(high(32n, U32.to_nat(n), word(v)), Lemmas.pow2(U32.to_nat(n))) == U32.to_nat(v) : Nat}:
  match v:
    case U32{+w}:
      remove_zero_rem(high(32n, U32.to_nat(n), w), Lemmas.pow2(U32.to_nat(n)),
        Word.to_nat(32n, w), Word.to_nat(32n, low(32n, U32.to_nat(n), w)),
        low_high(32n, U32.to_nat(n), w),
        Equal.trans(Nat, Word.to_nat(32n, low(32n, U32.to_nat(n), w)),
          U32.to_nat(U32.and(U32{w}, Bits.mask(n))), 0n,
          Equal.cong(U32, Nat, U32.to_nat, U32{low(32n, U32.to_nat(n), w)},
            U32.and(U32{w}, Bits.mask(n)),
            Equal.sym(U32, U32.and(U32{w}, Bits.mask(n)), U32{low(32n, U32.to_nat(n), w)}, and_mask_word(U32{w}, n))),
          Equal.cong(U32, Nat, U32.to_nat, U32.and(U32{w}, Bits.mask(n)), 0, h)))

def pow2_complement(+s: U32, hs: MNat.le(U32.to_nat(s), 32n)) -> {
  Nat.mul(Lemmas.pow2(U32.to_nat(U32.sub(32, s))), Lemmas.pow2(U32.to_nat(s))) == Lemmas.pow2(32n) : Nat}:
  Equal.trans(Nat, Nat.mul(Lemmas.pow2(U32.to_nat(U32.sub(32, s))), Lemmas.pow2(U32.to_nat(s))),
    Lemmas.pow2(Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(s))), Lemmas.pow2(32n),
    Equal.sym(Nat, Lemmas.pow2(Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(s))),
      Nat.mul(Lemmas.pow2(U32.to_nat(U32.sub(32, s))), Lemmas.pow2(U32.to_nat(s))),
      pow2_add(U32.to_nat(U32.sub(32, s)), U32.to_nat(s))),
    Equal.cong(Nat, Nat, Lemmas.pow2, Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(s)), 32n,
      Equal.trans(Nat, Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(s)),
        Nat.add(U32.to_nat(s), U32.to_nat(U32.sub(32, s))), 32n,
        MNat.add_comm(U32.to_nat(U32.sub(32, s)), U32.to_nat(s)), complement_sum(s, hs))))

def shift_multiple_zero.mod(+v: U32, +k: Nat, +b: Nat, +q: Nat,
  e: {Nat.mul(q, b) == U32.to_nat(v) : Nat},
  eb: {Nat.mul(b, Lemmas.pow2(k)) == Lemmas.pow2(32n) : Nat}) -> {
  Nat.mod(Nat.mul(U32.to_nat(v), Lemmas.pow2(k)), Lemmas.pow2(32n)) == 0n : Nat}:
  %e : {Nat.mod(Nat.mul(_, Lemmas.pow2(k)), Lemmas.pow2(32n)) == 0n : Nat}
  %Equal.sym(Nat, Nat.mul(Nat.mul(q, b), Lemmas.pow2(k)), Nat.mul(q, Nat.mul(b, Lemmas.pow2(k))),
    MNat.mul_assoc(q, b, Lemmas.pow2(k))) : {Nat.mod(_, Lemmas.pow2(32n)) == 0n : Nat}
  %Equal.sym(Nat, Nat.mul(b, Lemmas.pow2(k)), Lemmas.pow2(32n), eb) :
    {Nat.mod(Nat.mul(q, _), Lemmas.pow2(32n)) == 0n : Nat}
  MNat.mul_mod_left(q, Lemmas.pow2(32n))

def shift_multiple_zero(+v: U32, +k: Nat, +b: Nat, +q: Nat,
  e: {Nat.mul(q, b) == U32.to_nat(v) : Nat},
  eb: {Nat.mul(b, Lemmas.pow2(k)) == Lemmas.pow2(32n) : Nat}) -> {
  U32.shln(v, k) == 0 : U32}:
  Lemmas.u32_to_nat_inj(U32.shln(v, k), 0,
    Equal.trans(Nat, U32.to_nat(U32.shln(v, k)),
      Nat.mod(Nat.mul(U32.to_nat(v), Lemmas.pow2(k)), Lemmas.pow2(32n)), 0n, shln_mod(k, v),
      shift_multiple_zero.mod(v, k, b, q, e, eb)))

def low_shl_zero(+s: U32, +v: U32, hs: MNat.le(U32.to_nat(s), 32n),
  h: {U32.and(v, Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  U32.shln(v, U32.to_nat(s)) == 0 : U32}:
  shift_multiple_zero(v, U32.to_nat(s), Lemmas.pow2(U32.to_nat(U32.sub(32, s))),
    high(32n, U32.to_nat(U32.sub(32, s)), word(v)), low_zero_multiple(v, U32.sub(32, s), h), pow2_complement(s, hs))

def u32_or_comm(+a: U32, +b: U32) -> {U32.or(a, b) == U32.or(b, a) : U32}:
  match a b:
    case U32{+x} U32{+y}:
      Equal.cong(Word(32n), U32, w => U32{w}, Word.or(32n, x, y), Word.or(32n, y, x), word_or_comm(32n, x, y))

def u32_recombine_right(+s: Nat, +c: Nat, +v: U32, h: {Nat.add(s, c) == 32n : Nat}) -> {
  U32.or(U32.shln(U32.shrn(v, s), s), U32.shrn(U32.shln(v, c), c)) == v : U32}:
  Equal.trans(U32, U32.or(U32.shln(U32.shrn(v, s), s), U32.shrn(U32.shln(v, c), c)),
    U32.or(U32.shrn(U32.shln(v, c), c), U32.shln(U32.shrn(v, s), s)), v,
    u32_or_comm(U32.shln(U32.shrn(v, s), s), U32.shrn(U32.shln(v, c), c)),
    u32_recombine_left(c, s, v, Equal.trans(Nat, Nat.add(c, s), Nat.add(s, c), 32n, MNat.add_comm(c, s), h)))

def msb_recover.normal(+s: U32, +v: U32, +lo: U32,
  +hs: MNat.le(U32.to_nat(s), 32n), hl: {U32.and(lo, Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  U32.or(U32.shln(U32.or(lo, U32.shrn(v, U32.to_nat(s))), U32.to_nat(s)),
    U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, s)))) == v : U32}:
  %Equal.sym(U32, U32.shln(U32.or(lo, U32.shrn(v, U32.to_nat(s))), U32.to_nat(s)),
    U32.or(U32.shln(lo, U32.to_nat(s)), U32.shln(U32.shrn(v, U32.to_nat(s)), U32.to_nat(s))),
    shln_or(U32.to_nat(s), lo, U32.shrn(v, U32.to_nat(s)))) :
    {U32.or(_, U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, s)))) == v : U32}
  %Equal.sym(U32, U32.shln(lo, U32.to_nat(s)), 0, low_shl_zero(s, lo, hs, hl)) :
    {U32.or(U32.or(_, U32.shln(U32.shrn(v, U32.to_nat(s)), U32.to_nat(s))),
      U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, s)))) == v : U32}
  %Equal.sym(U32, U32.or(0, U32.shln(U32.shrn(v, U32.to_nat(s)), U32.to_nat(s))),
    U32.shln(U32.shrn(v, U32.to_nat(s)), U32.to_nat(s)),
    u32_zero_or(U32.shln(U32.shrn(v, U32.to_nat(s)), U32.to_nat(s)))) :
    {U32.or(_, U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, s)))) == v : U32}
  u32_recombine_right(U32.to_nat(s), U32.to_nat(U32.sub(32, s)), v, complement_sum(s, hs))

def bswap_written(+lo: U32, +part: U32) -> {
  Bytes.bswap(U32.or(lo, Bytes.bswap(part))) == U32.or(Bytes.bswap(lo), part) : U32}:
  Equal.trans(U32, Bytes.bswap(U32.or(lo, Bytes.bswap(part))),
    U32.or(Bytes.bswap(lo), Bytes.bswap(Bytes.bswap(part))), U32.or(Bytes.bswap(lo), part),
    bswap_or(lo, Bytes.bswap(part)), Equal.cong(U32, U32, x => U32.or(Bytes.bswap(lo), x),
      Bytes.bswap(Bytes.bswap(part)), part, bswap_invol(part)))

def msb_join(+s: U32, lo: U32, hi: U32) -> U32:
  U32.or(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.shrn(Bytes.bswap(hi), U32.to_nat(U32.sub(32, s))))

def msb_recover(+s: U32, +v: U32, +lo: U32,
  +hs: MNat.le(U32.to_nat(s), 32n), hl: {U32.and(Bytes.bswap(lo), Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  msb_join(s, U32.or(lo, Bytes.bswap(U32.shrn(v, U32.to_nat(s)))),
    Bytes.bswap(U32.shln(v, U32.to_nat(U32.sub(32, s))))) == v : U32}:
  %Equal.sym(U32, Bytes.bswap(U32.or(lo, Bytes.bswap(U32.shrn(v, U32.to_nat(s))))),
    U32.or(Bytes.bswap(lo), U32.shrn(v, U32.to_nat(s))), bswap_written(lo, U32.shrn(v, U32.to_nat(s)))) :
    {U32.or(U32.shln(_, U32.to_nat(s)),
      U32.shrn(Bytes.bswap(Bytes.bswap(U32.shln(v, U32.to_nat(U32.sub(32, s))))), U32.to_nat(U32.sub(32, s)))) == v : U32}
  %Equal.sym(U32, Bytes.bswap(Bytes.bswap(U32.shln(v, U32.to_nat(U32.sub(32, s))))),
    U32.shln(v, U32.to_nat(U32.sub(32, s))), bswap_invol(U32.shln(v, U32.to_nat(U32.sub(32, s))))) :
    {U32.or(U32.shln(U32.or(Bytes.bswap(lo), U32.shrn(v, U32.to_nat(s))), U32.to_nat(s)),
      U32.shrn(_, U32.to_nat(U32.sub(32, s)))) == v : U32}
  msb_recover.normal(s, v, Bytes.bswap(lo), hs, hl)

def u32_shr_shl(+s: Nat, +c: Nat, +v: U32, h: {Nat.add(s, c) == 32n : Nat}) -> {
  U32.shrn(U32.shln(v, s), s) == U32{low(32n, c, word(v))} : U32}:
  match v:
    case U32{+w}:
      %Equal.sym(U32, U32.shln(U32{w}, s), U32{wshl(s, 32n, w)}, shln_word(s, U32{w})) :
        {U32.shrn(_, s) == U32{low(32n, c, w)} : U32}
      %Equal.sym(U32, U32.shrn(U32{wshl(s, 32n, w)}, s), U32{wshr(s, 32n, wshl(s, 32n, w))},
        shrn_word(s, U32{wshl(s, 32n, w)})) : {_ == U32{low(32n, c, w)} : U32}
      Equal.cong(Word(32n), U32, x => U32{x}, wshr(s, 32n, wshl(s, 32n, w)), low(32n, c, w), shr_shl(32n, s, c, w, h))

def high_field(+n: U32, +v: U32, hn: MNat.le(U32.to_nat(n), 32n)) -> {
  U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(U32.sub(32, n))) == U32.and(v, Bits.mask(n)) : U32}:
  Equal.trans(U32, U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(U32.sub(32, n))),
    U32{low(32n, U32.to_nat(n), word(v))}, U32.and(v, Bits.mask(n)),
    u32_shr_shl(U32.to_nat(U32.sub(32, n)), U32.to_nat(n), v,
      Equal.trans(Nat, Nat.add(U32.to_nat(U32.sub(32, n)), U32.to_nat(n)),
        Nat.add(U32.to_nat(n), U32.to_nat(U32.sub(32, n))), 32n,
        MNat.add_comm(U32.to_nat(U32.sub(32, n)), U32.to_nat(n)), complement_sum(n, hn))),
    Equal.sym(U32, U32.and(v, Bits.mask(n)), U32{low(32n, U32.to_nat(n), word(v))}, and_mask_word(v, n)))

def msb_after.parts(+s: U32, +n: U32, lo: U32, x: U32 & U32) -> U32:
  (x0, x1) = x
  Bits.field(True{}, n, msb_join(s, U32.or(lo, x0), x1))

def msb_after(+s: U32, +n: U32, v: U32, lo: U32) -> U32:
  msb_after.parts(s, n, lo, Bits.parts(True{}, s, n, v))

def msb_field(+s: U32, +n: U32, +v: U32, +lo: U32,
  hs: MNat.le(U32.to_nat(s), 32n), hn: MNat.le(U32.to_nat(n), 32n),
  hl: {U32.and(Bytes.bswap(lo), Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  msb_after(s, n, v, lo) == U32.and(v, Bits.mask(n)) : U32}:
  Equal.trans(U32, msb_after(s, n, v, lo),
    U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(U32.sub(32, n))), U32.and(v, Bits.mask(n)),
    Equal.cong(U32, U32, x => U32.shrn(x, U32.to_nat(U32.sub(32, n))),
      msb_join(s, U32.or(lo, Bytes.bswap(U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(s)))),
        Bytes.bswap(U32.shln(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(U32.sub(32, s))))),
      U32.shln(v, U32.to_nat(U32.sub(32, n))),
      msb_recover(s, U32.shln(v, U32.to_nat(U32.sub(32, n))), lo, hs, hl)), high_field(n, v, hn))

def msb_roundtrip(+s: U32, +n: U32, +v: U32, +lo: U32,
  hs: MNat.le(U32.to_nat(s), 31n), +hn: MNat.le(U32.to_nat(n), 32n),
  hl: {U32.and(Bytes.bswap(lo), Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  U32.to_nat(msb_after(s, n, v, lo)) == Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  Equal.trans(Nat, U32.to_nat(msb_after(s, n, v, lo)), U32.to_nat(U32.and(v, Bits.mask(n))),
    Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))),
    Equal.cong(U32, Nat, U32.to_nat, msb_after(s, n, v, lo), U32.and(v, Bits.mask(n)),
      msb_field(s, n, v, lo, MNat.le_trans(U32.to_nat(s), 31n, 32n, hs, {==}), hn, hl)), mask_mod(v, n, hn))

def low_zero(+d: Nat, +k: Nat) -> {low(d, k, Word.zero(d)) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          {==}
        case 1n+ +q:
          Equal.cong(Word(p), Word(1n+p), z => WCon{False{}, z}, low(p, q, Word.zero(p)), Word.zero(p), low_zero(p, q))

def low_idem(+d: Nat, +k: Nat, +w: Word(d)) -> {low(d, k, low(d, k, w)) == low(d, k, w) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          {==}
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              Equal.cong(Word(p), Word(1n+p), z => WCon{x, z}, low(p, q, low(p, q, t)), low(p, q, t), low_idem(p, q, t))

def low_absorb(+d: Nat, +a: Nat, +b: Nat, +w: Word(d), h: MNat.le(a, b)) -> {
  low(d, b, low(d, a, w)) == low(d, a, w) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match a:
        case 0n:
          low_zero(1n+p, b)
        case 1n+ +q:
          match b:
            case 0n:
              Empty.absurd({low(1n+p, 0n, low(1n+p, 1n+q, w)) == low(1n+p, 1n+q, w) : Word(1n+p)},
                MNat.succ_ne_zero(q)(MNat.le_zero_eq(1n+q, h)))
            case 1n+ +r:
              match w:
                case WCon{+x, +t}:
                  Equal.cong(Word(p), Word(1n+p), z => WCon{x, z},
                    low(p, r, low(p, q, t)), low(p, q, t), low_absorb(p, q, r, t, h))

def prefix_grow(+d: Nat, +a: Nat, +b: Nat, +w: Word(d), h: MNat.le(a, b), +hw: {low(d, a, w) == w : Word(d)}) -> {
  low(d, b, w) == w : Word(d)}:
  Equal.trans(Word(d), low(d, b, w), low(d, b, low(d, a, w)), w,
    Equal.cong(Word(d), Word(d), x => low(d, b, x), w, low(d, a, w), Equal.sym(Word(d), low(d, a, w), w, hw)),
    Equal.trans(Word(d), low(d, b, low(d, a, w)), low(d, a, w), w, low_absorb(d, a, b, w, h), hw))

def low_or(+d: Nat, +k: Nat, +a: Word(d), +b: Word(d)) -> {
  low(d, k, Word.or(d, a, b)) == Word.or(d, low(d, k, a), low(d, k, b)) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          Equal.sym(Word(1n+p), Word.or(1n+p, Word.zero(1n+p), Word.zero(1n+p)), Word.zero(1n+p),
            word_or_zero(1n+p, Word.zero(1n+p)))
        case 1n+ +q:
          match a b:
            case WCon{+x, +at} WCon{+y, +bt}:
              Equal.cong(Word(p), Word(1n+p), z => WCon{Bool.or(x, y), z},
                low(p, q, Word.or(p, at, bt)), Word.or(p, low(p, q, at), low(p, q, bt)), low_or(p, q, at, bt))

def put_view(+d: Nat, +c: Bool, +w: Word(1n+d)) -> {
  Word.shl.put(1n+d, c, w) == WCon{c, init(d, w)} : Word(1n+d)}:
  match w:
    case WCon{x, t}:
      {==}

def init_low(+d: Nat, +k: Nat, +w: Word(1n+d)) -> {
  init(d, low(1n+d, k, w)) == low(d, k, init(d, w)) : Word(d)}:
  match d:
    case 0n:
      match k:
        case 0n:
          {==}
        case 1n+q:
          match w:
            case WCon{x, t}:
              {==}
    case 1n+ +p:
      match k:
        case 0n:
          put_zero(1n+p)
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              %Equal.sym(Word(1n+p), Word.shl.put(1n+p, x, low(1n+p, q, t)),
                WCon{x, init(p, low(1n+p, q, t))}, put_view(p, x, low(1n+p, q, t))) :
                {_ == low(1n+p, 1n+q, Word.shl.put(1n+p, x, t)) : Word(1n+p)}
              %Equal.sym(Word(1n+p), Word.shl.put(1n+p, x, t), WCon{x, init(p, t)}, put_view(p, x, t)) :
                {WCon{x, init(p, low(1n+p, q, t))} == low(1n+p, 1n+q, _) : Word(1n+p)}
              Equal.cong(Word(p), Word(1n+p), z => WCon{x, z}, init(p, low(1n+p, q, t)),
                low(p, q, init(p, t)), init_low(p, q, t))

def shl_init(+d: Nat, +w: Word(1n+d)) -> {Word.shl(1n+d, w) == WCon{False{}, init(d, w)} : Word(1n+d)}:
  match w:
    case WCon{x, t}:
      {==}

def low_shl(+d: Nat, +k: Nat, +w: Word(d)) -> {
  low(d, 1n+k, Word.shl(d, w)) == Word.shl(d, low(d, k, w)) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      Equal.trans(Word(1n+p), low(1n+p, 1n+k, Word.shl(1n+p, w)),
        WCon{False{}, low(p, k, init(p, w))}, Word.shl(1n+p, low(1n+p, k, w)),
        Equal.cong(Word(1n+p), Word(1n+p), x => low(1n+p, 1n+k, x), Word.shl(1n+p, w), WCon{False{}, init(p, w)}, shl_init(p, w)),
        Equal.trans(Word(1n+p), WCon{False{}, low(p, k, init(p, w))}, WCon{False{}, init(p, low(1n+p, k, w))},
          Word.shl(1n+p, low(1n+p, k, w)),
          Equal.cong(Word(p), Word(1n+p), x => WCon{False{}, x}, low(p, k, init(p, w)), init(p, low(1n+p, k, w)),
            Equal.sym(Word(p), init(p, low(1n+p, k, w)), low(p, k, init(p, w)), init_low(p, k, w))),
          Equal.sym(Word(1n+p), Word.shl(1n+p, low(1n+p, k, w)), WCon{False{}, init(p, low(1n+p, k, w))}, shl_init(p, low(1n+p, k, w)))))

def low_wshl(+s: Nat, +d: Nat, +n: Nat, +w: Word(d)) -> {
  low(d, Nat.add(s, n), wshl(s, d, w)) == wshl(s, d, low(d, n, w)) : Word(d)}:
  match s:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.trans(Word(d), low(d, 1n+Nat.add(q, n), Word.shl(d, wshl(q, d, w))),
        Word.shl(d, low(d, Nat.add(q, n), wshl(q, d, w))), Word.shl(d, wshl(q, d, low(d, n, w))),
        low_shl(d, Nat.add(q, n), wshl(q, d, w)),
        Equal.cong(Word(d), Word(d), x => Word.shl(d, x), low(d, Nat.add(q, n), wshl(q, d, w)),
          wshl(q, d, low(d, n, w)), low_wshl(q, d, n, w)))

def shifted_low_prefix(+d: Nat, +s: Nat, +n: Nat, +w: Word(d)) -> {
  low(d, Nat.add(s, n), wshl(s, d, low(d, n, w))) == wshl(s, d, low(d, n, w)) : Word(d)}:
  Equal.trans(Word(d), low(d, Nat.add(s, n), wshl(s, d, low(d, n, w))),
    wshl(s, d, low(d, n, low(d, n, w))), wshl(s, d, low(d, n, w)), low_wshl(s, d, n, low(d, n, w)),
    Equal.cong(Word(d), Word(d), x => wshl(s, d, x), low(d, n, low(d, n, w)), low(d, n, w), low_idem(d, n, w)))

def low_pad(+d: Nat, +k: Nat, +w: Word(d)) -> {
  low(1n+d, k, Word.shr.pad(d, w)) == Word.shr.pad(d, low(d, k, w)) : Word(1n+d)}:
  match d:
    case 0n:
      match k:
        case 0n:
          {==}
        case 1n+q:
          {==}
    case 1n+ +p:
      match k:
        case 0n:
          Equal.sym(Word(2n+p), Word.shr.pad(1n+p, Word.zero(1n+p)), Word.zero(2n+p), pad_zero(1n+p))
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              Equal.cong(Word(1n+p), Word(2n+p), z => WCon{x, z}, low(1n+p, q, Word.shr.pad(p, t)),
                Word.shr.pad(p, low(p, q, t)), low_pad(p, q, t))

def low_shr(+d: Nat, +k: Nat, +w: Word(d)) -> {
  low(d, k, Word.shr(d, w)) == Word.shr(d, low(d, 1n+k, w)) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{x, +t}:
          low_pad(p, k, t)

def low_wshr(+s: Nat, +d: Nat, +n: Nat, +w: Word(d)) -> {
  low(d, n, wshr(s, d, w)) == wshr(s, d, low(d, Nat.add(s, n), w)) : Word(d)}:
  match s:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.trans(Word(d), low(d, n, Word.shr(d, wshr(q, d, w))),
        Word.shr(d, low(d, 1n+n, wshr(q, d, w))), Word.shr(d, wshr(q, d, low(d, 1n+Nat.add(q, n), w))),
        low_shr(d, n, wshr(q, d, w)),
        Equal.trans(Word(d), Word.shr(d, low(d, 1n+n, wshr(q, d, w))),
          Word.shr(d, wshr(q, d, low(d, Nat.add(q, 1n+n), w))), Word.shr(d, wshr(q, d, low(d, 1n+Nat.add(q, n), w))),
          Equal.cong(Word(d), Word(d), x => Word.shr(d, x), low(d, 1n+n, wshr(q, d, w)),
            wshr(q, d, low(d, Nat.add(q, 1n+n), w)), low_wshr(q, d, 1n+n, w)),
          Equal.cong(Nat, Word(d), k => Word.shr(d, wshr(q, d, low(d, k, w))), Nat.add(q, 1n+n),
            1n+Nat.add(q, n), MNat.add_succ(q, n))))

def le_sub_sum(+n: Nat, +c: Nat) -> MNat.le(n, Nat.add(c, Nat.sub(n, c))):
  match n c:
    case 0n +b:
      MNat.zero_le(Nat.add(b, 0n))
    case 1n+ +a 0n:
      MNat.le_refl(1n+a)
    case 1n+ +a 1n+ +b:
      le_sub_sum(a, b)

def spilled_low_prefix(+d: Nat, +n: Nat, +c: Nat, +w: Word(d)) -> {
  low(d, Nat.sub(n, c), wshr(c, d, low(d, n, w))) == wshr(c, d, low(d, n, w)) : Word(d)}:
  Equal.trans(Word(d), low(d, Nat.sub(n, c), wshr(c, d, low(d, n, w))),
    wshr(c, d, low(d, Nat.add(c, Nat.sub(n, c)), low(d, n, w))), wshr(c, d, low(d, n, w)),
    low_wshr(c, d, Nat.sub(n, c), low(d, n, w)),
    Equal.cong(Word(d), Word(d), x => wshr(c, d, x), low(d, Nat.add(c, Nat.sub(n, c)), low(d, n, w)),
      low(d, n, w), low_absorb(d, n, Nat.add(c, Nat.sub(n, c)), w, le_sub_sum(n, c))))

def prefix_or(+d: Nat, +k: Nat, +a: Word(d), +b: Word(d),
  ha: {low(d, k, a) == a : Word(d)}, hb: {low(d, k, b) == b : Word(d)}) -> {
  low(d, k, Word.or(d, a, b)) == Word.or(d, a, b) : Word(d)}:
  Equal.trans(Word(d), low(d, k, Word.or(d, a, b)), Word.or(d, low(d, k, a), low(d, k, b)), Word.or(d, a, b), low_or(d, k, a, b),
    Equal.trans(Word(d), Word.or(d, low(d, k, a), low(d, k, b)), Word.or(d, a, low(d, k, b)), Word.or(d, a, b),
      Equal.cong(Word(d), Word(d), x => Word.or(d, x, low(d, k, b)), low(d, k, a), a, ha),
      Equal.cong(Word(d), Word(d), x => Word.or(d, a, x), low(d, k, b), b, hb)))

def wtail(+d: Nat, w: Word(1n+d)) -> Word(d):
  match w:
    case WCon{x, t}:
      t

def low_zero_shr(+d: Nat, +z: Nat, +s: Nat, +w: Word(d),
  h: {low(d, z, w) == Word.zero(d) : Word(d)}) -> {
  low(d, Nat.sub(z, s), wshr(s, d, w)) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match z:
        case 0n:
          {==}
        case 1n+ +k:
          match s:
            case 0n:
              h
            case 1n+ +q:
              match w:
                case WCon{+x, +t}:
                  %Equal.sym(Word(1n+p), wshr(1n+q, 1n+p, WCon{x, t}),
                    Word.shr.pad(p, wshr(q, p, t)), wshr_con(q, p, x, t)) :
                    {low(1n+p, Nat.sub(k, q), _) == Word.zero(1n+p) : Word(1n+p)}
                  %Equal.sym(Word(1n+p), low(1n+p, Nat.sub(k, q), Word.shr.pad(p, wshr(q, p, t))),
                    Word.shr.pad(p, low(p, Nat.sub(k, q), wshr(q, p, t))), low_pad(p, Nat.sub(k, q), wshr(q, p, t))) :
                    {_ == Word.zero(1n+p) : Word(1n+p)}
                  %Equal.sym(Word(p), low(p, Nat.sub(k, q), wshr(q, p, t)), Word.zero(p),
                    low_zero_shr(p, k, q, t,
                      Equal.cong(Word(1n+p), Word(p), wtail(p),
                        low(1n+p, 1n+k, WCon{x, t}), Word.zero(1n+p), h))) :
                    {Word.shr.pad(p, _) == Word.zero(1n+p) : Word(1n+p)}
                  pad_zero(p)

def shl_zero(+d: Nat) -> {Word.shl(d, Word.zero(d)) == Word.zero(d) : Word(d)}:
  Equal.trans(Word(d), Word.shl(d, Word.zero(d)), Word.shl.put(d, False{}, Word.zero(d)), Word.zero(d),
    Equal.sym(Word(d), Word.shl.put(d, False{}, Word.zero(d)), Word.shl(d, Word.zero(d)), shl_put_false(d, Word.zero(d))), put_zero(d))

def wshl_zero(+s: Nat, +d: Nat) -> {wshl(s, d, Word.zero(d)) == Word.zero(d) : Word(d)}:
  match s:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.trans(Word(d), Word.shl(d, wshl(q, d, Word.zero(d))), Word.shl(d, Word.zero(d)), Word.zero(d),
        Equal.cong(Word(d), Word(d), x => Word.shl(d, x), wshl(q, d, Word.zero(d)), Word.zero(d), wshl_zero(q, d)), shl_zero(d))

def low_zero_shl(+d: Nat, +z: Nat, +s: Nat, +w: Word(d),
  h: {low(d, z, w) == Word.zero(d) : Word(d)}) -> {
  low(d, Nat.add(s, z), wshl(s, d, w)) == Word.zero(d) : Word(d)}:
  Equal.trans(Word(d), low(d, Nat.add(s, z), wshl(s, d, w)), wshl(s, d, low(d, z, w)), Word.zero(d),
    low_wshl(s, d, z, w), Equal.trans(Word(d), wshl(s, d, low(d, z, w)), wshl(s, d, Word.zero(d)), Word.zero(d),
      Equal.cong(Word(d), Word(d), x => wshl(s, d, x), low(d, z, w), Word.zero(d), h), wshl_zero(s, d)))

def low_nest(+d: Nat, +a: Nat, +b: Nat, +w: Word(d), h: MNat.le(a, b)) -> {
  low(d, a, low(d, b, w)) == low(d, a, w) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match a:
        case 0n:
          {==}
        case 1n+ +q:
          match b:
            case 0n:
              Empty.absurd({low(1n+p, 1n+q, low(1n+p, 0n, w)) == low(1n+p, 1n+q, w) : Word(1n+p)},
                MNat.succ_ne_zero(q)(MNat.le_zero_eq(1n+q, h)))
            case 1n+ +r:
              match w:
                case WCon{+x, +t}:
                  Equal.cong(Word(p), Word(1n+p), z => WCon{x, z},
                    low(p, q, low(p, r, t)), low(p, q, t), low_nest(p, q, r, t, h))

def low_zero_weaken(+d: Nat, +a: Nat, +b: Nat, +w: Word(d),
  hab: MNat.le(a, b), h: {low(d, b, w) == Word.zero(d) : Word(d)}) -> {
  low(d, a, w) == Word.zero(d) : Word(d)}:
  Equal.trans(Word(d), low(d, a, w), low(d, a, low(d, b, w)), Word.zero(d),
    Equal.sym(Word(d), low(d, a, low(d, b, w)), low(d, a, w), low_nest(d, a, b, w, hab)),
    Equal.trans(Word(d), low(d, a, low(d, b, w)), low(d, a, Word.zero(d)), Word.zero(d),
      Equal.cong(Word(d), Word(d), x => low(d, a, x), low(d, b, w), Word.zero(d), h), low_zero(d, a)))

def low_or_zero(+d: Nat, +k: Nat, +a: Word(d), +b: Word(d),
  ha: {low(d, k, a) == Word.zero(d) : Word(d)}, hb: {low(d, k, b) == Word.zero(d) : Word(d)}) -> {
  low(d, k, Word.or(d, a, b)) == Word.zero(d) : Word(d)}:
  Equal.trans(Word(d), low(d, k, Word.or(d, a, b)), Word.or(d, low(d, k, a), low(d, k, b)), Word.zero(d), low_or(d, k, a, b),
    Equal.trans(Word(d), Word.or(d, low(d, k, a), low(d, k, b)), Word.or(d, Word.zero(d), low(d, k, b)), Word.zero(d),
      Equal.cong(Word(d), Word(d), x => Word.or(d, x, low(d, k, b)), low(d, k, a), Word.zero(d), ha),
      Equal.trans(Word(d), Word.or(d, Word.zero(d), low(d, k, b)), Word.or(d, Word.zero(d), Word.zero(d)), Word.zero(d),
        Equal.cong(Word(d), Word(d), x => Word.or(d, Word.zero(d), x), low(d, k, b), Word.zero(d), hb), word_or_zero(d, Word.zero(d)))))

def first(x: U32 & U32) -> U32:
  (a, b) = x
  a

def second(x: U32 & U32) -> U32:
  (a, b) = x
  b

def written_lo(msb: Bool, s: U32, n: U32, v: U32, lo: U32) -> U32:
  U32.or(lo, first(Bits.parts(msb, s, n, v)))

def written_hi(msb: Bool, s: U32, n: U32, v: U32) -> U32:
  second(Bits.parts(msb, s, n, v))

def word_or(+a: U32, +b: U32) -> {word(U32.or(a, b)) == Word.or(32n, word(a), word(b)) : Word(32n)}:
  match a b:
    case U32{x} U32{y}:
      {==}

def word_shln(+k: Nat, +v: U32) -> {word(U32.shln(v, k)) == wshl(k, 32n, word(v)) : Word(32n)}:
  Equal.cong(U32, Word(32n), word, U32.shln(v, k), U32{wshl(k, 32n, word(v))}, shln_word(k, v))

def word_shrn(+k: Nat, +v: U32) -> {word(U32.shrn(v, k)) == wshr(k, 32n, word(v)) : Word(32n)}:
  Equal.cong(U32, Word(32n), word, U32.shrn(v, k), U32{wshr(k, 32n, word(v))}, shrn_word(k, v))

def lsb_lo_word(+s: U32, +n: U32, +v: U32, +lo: U32) -> {
  word(written_lo(False{}, s, n, v, lo)) ==
  Word.or(32n, word(lo), wshl(U32.to_nat(s), 32n, low(32n, U32.to_nat(n), word(v)))) : Word(32n)}:
  Equal.trans(Word(32n), word(written_lo(False{}, s, n, v, lo)),
    word(U32.or(lo, U32.shln(U32{low(32n, U32.to_nat(n), word(v))}, U32.to_nat(s)))),
    Word.or(32n, word(lo), wshl(U32.to_nat(s), 32n, low(32n, U32.to_nat(n), word(v)))),
    Equal.cong(U32, Word(32n), x => word(U32.or(lo, U32.shln(x, U32.to_nat(s)))),
      U32.and(v, Bits.mask(n)), U32{low(32n, U32.to_nat(n), word(v))}, and_mask_word(v, n)),
    Equal.trans(Word(32n),
      word(U32.or(lo, U32.shln(U32{low(32n, U32.to_nat(n), word(v))}, U32.to_nat(s)))),
      Word.or(32n, word(lo), word(U32.shln(U32{low(32n, U32.to_nat(n), word(v))}, U32.to_nat(s)))),
      Word.or(32n, word(lo), wshl(U32.to_nat(s), 32n, low(32n, U32.to_nat(n), word(v)))),
      word_or(lo, U32.shln(U32{low(32n, U32.to_nat(n), word(v))}, U32.to_nat(s))),
      Equal.cong(Word(32n), Word(32n), x => Word.or(32n, word(lo), x),
        word(U32.shln(U32{low(32n, U32.to_nat(n), word(v))}, U32.to_nat(s))),
        wshl(U32.to_nat(s), 32n, low(32n, U32.to_nat(n), word(v))),
        word_shln(U32.to_nat(s), U32{low(32n, U32.to_nat(n), word(v))}))))

def lsb_hi_word(+s: U32, +n: U32, +v: U32) -> {
  word(written_hi(False{}, s, n, v)) == wshr(U32.to_nat(U32.sub(32, s)), 32n, low(32n, U32.to_nat(n), word(v))) : Word(32n)}:
  Equal.trans(Word(32n), word(written_hi(False{}, s, n, v)),
    word(U32.shrn(U32{low(32n, U32.to_nat(n), word(v))}, U32.to_nat(U32.sub(32, s)))),
    wshr(U32.to_nat(U32.sub(32, s)), 32n, low(32n, U32.to_nat(n), word(v))),
    Equal.cong(U32, Word(32n), x => word(U32.shrn(x, U32.to_nat(U32.sub(32, s)))),
      U32.and(v, Bits.mask(n)), U32{low(32n, U32.to_nat(n), word(v))}, and_mask_word(v, n)),
    word_shrn(U32.to_nat(U32.sub(32, s)), U32{low(32n, U32.to_nat(n), word(v))}))

def lsb_lo_suffix(+s: U32, +n: U32, +v: U32, +lo: U32,
  hl: {U32.and(lo, U32.not(Bits.mask(s))) == 0 : U32}) -> {
  low(32n, Nat.add(U32.to_nat(s), U32.to_nat(n)), word(written_lo(False{}, s, n, v, lo)))
  == word(written_lo(False{}, s, n, v, lo)) : Word(32n)}:
  %Equal.sym(Word(32n), word(written_lo(False{}, s, n, v, lo)),
    Word.or(32n, word(lo), wshl(U32.to_nat(s), 32n, low(32n, U32.to_nat(n), word(v)))), lsb_lo_word(s, n, v, lo)) :
    {low(32n, Nat.add(U32.to_nat(s), U32.to_nat(n)), _) == _ : Word(32n)}
  prefix_or(32n, Nat.add(U32.to_nat(s), U32.to_nat(n)), word(lo),
    wshl(U32.to_nat(s), 32n, low(32n, U32.to_nat(n), word(v))),
    prefix_grow(32n, U32.to_nat(s), Nat.add(U32.to_nat(s), U32.to_nat(n)), word(lo), MNat.le_add_right(U32.to_nat(s), U32.to_nat(n)),
      Equal.sym(Word(32n), word(lo), low(32n, U32.to_nat(s), word(lo)),
        Equal.cong(U32, Word(32n), word, lo, U32{low(32n, U32.to_nat(s), word(lo))}, u32_prefix_low(lo, s, hl)))),
    shifted_low_prefix(32n, U32.to_nat(s), U32.to_nat(n), word(v)))

def lsb_hi_suffix(+s: U32, +n: U32, +v: U32) -> {
  low(32n, Nat.sub(U32.to_nat(n), U32.to_nat(U32.sub(32, s))), word(written_hi(False{}, s, n, v)))
  == word(written_hi(False{}, s, n, v)) : Word(32n)}:
  %Equal.sym(Word(32n), word(written_hi(False{}, s, n, v)),
    wshr(U32.to_nat(U32.sub(32, s)), 32n, low(32n, U32.to_nat(n), word(v))), lsb_hi_word(s, n, v)) :
    {low(32n, Nat.sub(U32.to_nat(n), U32.to_nat(U32.sub(32, s))), _) == _ : Word(32n)}
  spilled_low_prefix(32n, U32.to_nat(n), U32.to_nat(U32.sub(32, s)), word(v))

def and_mask_zero(+v: U32, +n: U32, h: {U32.and(v, Bits.mask(n)) == 0 : U32}) -> {
  low(32n, U32.to_nat(n), word(v)) == Word.zero(32n) : Word(32n)}:
  Equal.trans(Word(32n), low(32n, U32.to_nat(n), word(v)), word(U32.and(v, Bits.mask(n))), Word.zero(32n),
    Equal.cong(U32, Word(32n), word, U32{low(32n, U32.to_nat(n), word(v))}, U32.and(v, Bits.mask(n)),
      Equal.sym(U32, U32.and(v, Bits.mask(n)), U32{low(32n, U32.to_nat(n), word(v))}, and_mask_word(v, n))),
    Equal.cong(U32, Word(32n), word, U32.and(v, Bits.mask(n)), 0, h))

def word_shr_shl(+a: Nat, +b: Nat, +v: U32) -> {
  word(U32.shrn(U32.shln(v, a), b)) == wshr(b, 32n, wshl(a, 32n, word(v))) : Word(32n)}:
  Equal.trans(Word(32n), word(U32.shrn(U32.shln(v, a), b)), wshr(b, 32n, word(U32.shln(v, a))),
    wshr(b, 32n, wshl(a, 32n, word(v))), word_shrn(b, U32.shln(v, a)),
    Equal.cong(Word(32n), Word(32n), x => wshr(b, 32n, x), word(U32.shln(v, a)), wshl(a, 32n, word(v)), word_shln(a, v)))

def word_shl_shl(+a: Nat, +b: Nat, +v: U32) -> {
  word(U32.shln(U32.shln(v, a), b)) == wshl(b, 32n, wshl(a, 32n, word(v))) : Word(32n)}:
  Equal.trans(Word(32n), word(U32.shln(U32.shln(v, a), b)), wshl(b, 32n, word(U32.shln(v, a))),
    wshl(b, 32n, wshl(a, 32n, word(v))), word_shln(b, U32.shln(v, a)),
    Equal.cong(Word(32n), Word(32n), x => wshl(b, 32n, x), word(U32.shln(v, a)), wshl(a, 32n, word(v)), word_shln(a, v)))

def msb_lo_word(+s: U32, +n: U32, +v: U32, +lo: U32) -> {
  word(Bytes.bswap(written_lo(True{}, s, n, v, lo))) ==
  Word.or(32n, word(Bytes.bswap(lo)), wshr(U32.to_nat(s), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v)))) : Word(32n)}:
  Equal.trans(Word(32n), word(Bytes.bswap(written_lo(True{}, s, n, v, lo))),
    word(U32.or(Bytes.bswap(lo), U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(s)))),
    Word.or(32n, word(Bytes.bswap(lo)), wshr(U32.to_nat(s), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v)))),
    Equal.cong(U32, Word(32n), word, Bytes.bswap(written_lo(True{}, s, n, v, lo)),
      U32.or(Bytes.bswap(lo), U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(s))),
      bswap_written(lo, U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(s)))),
    Equal.trans(Word(32n),
      word(U32.or(Bytes.bswap(lo), U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(s)))),
      Word.or(32n, word(Bytes.bswap(lo)), word(U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(s)))),
      Word.or(32n, word(Bytes.bswap(lo)), wshr(U32.to_nat(s), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v)))),
      word_or(Bytes.bswap(lo), U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(s))),
      Equal.cong(Word(32n), Word(32n), x => Word.or(32n, word(Bytes.bswap(lo)), x),
        word(U32.shrn(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(s))),
        wshr(U32.to_nat(s), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v))),
        word_shr_shl(U32.to_nat(U32.sub(32, n)), U32.to_nat(s), v))))

def msb_hi_word(+s: U32, +n: U32, +v: U32) -> {
  word(Bytes.bswap(written_hi(True{}, s, n, v))) ==
  wshl(U32.to_nat(U32.sub(32, s)), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v))) : Word(32n)}:
  Equal.trans(Word(32n), word(Bytes.bswap(written_hi(True{}, s, n, v))),
    word(U32.shln(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(U32.sub(32, s)))),
    wshl(U32.to_nat(U32.sub(32, s)), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v))),
    Equal.cong(U32, Word(32n), word,
      Bytes.bswap(Bytes.bswap(U32.shln(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(U32.sub(32, s))))),
      U32.shln(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(U32.sub(32, s))),
      bswap_invol(U32.shln(U32.shln(v, U32.to_nat(U32.sub(32, n))), U32.to_nat(U32.sub(32, s))))),
    word_shl_shl(U32.to_nat(U32.sub(32, n)), U32.to_nat(U32.sub(32, s)), v))

def msb_suffix_bound(+s: U32, +n: U32,
  hs: MNat.le(U32.to_nat(s), 32n), hn: MNat.le(U32.to_nat(n), 32n)) -> {
  Nat.is_le(Nat.sub(U32.to_nat(U32.sub(32, n)), U32.to_nat(s)), U32.to_nat(U32.sub(32, s))) == True{} : Bool}:
  %Equal.sym(Nat, U32.to_nat(U32.sub(32, n)), Nat.sub(32n, U32.to_nat(n)), Lemmas.u32_sub_nat(32, n, hn)) :
    {Nat.is_le(Nat.sub(_, U32.to_nat(s)), U32.to_nat(U32.sub(32, s))) == True{} : Bool}
  %Equal.sym(Nat, U32.to_nat(U32.sub(32, s)), Nat.sub(32n, U32.to_nat(s)), Lemmas.u32_sub_nat(32, s, hs)) :
    {Nat.is_le(Nat.sub(Nat.sub(32n, U32.to_nat(n)), U32.to_nat(s)), _) == True{} : Bool}
  MNat.sub_le_sub_right(Nat.sub(32n, U32.to_nat(n)), 32n, MNat.sub_le(32n, U32.to_nat(n)), U32.to_nat(s))

def low_at_zero(d: Nat, w: Word(d)) -> {low(d, 0n, w) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+p:
      {==}

def low_shift_zero(+d: Nat, +k: Nat, +w: Word(d)) -> {
  low(d, k, wshl(k, d, w)) == Word.zero(d) : Word(d)}:
  %MNat.add_zero(k) : {low(d, _, wshl(k, d, w)) == Word.zero(d) : Word(d)}
  low_zero_shl(d, 0n, k, w, low_at_zero(d, w))

def msb_lo_suffix(+s: U32, +n: U32, +v: U32, +lo: U32,
  hs: MNat.le(U32.to_nat(s), 32n), hn: MNat.le(U32.to_nat(n), 32n),
  hl: {U32.and(Bytes.bswap(lo), Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  low(32n, Nat.sub(U32.to_nat(U32.sub(32, n)), U32.to_nat(s)), word(Bytes.bswap(written_lo(True{}, s, n, v, lo))))
  == Word.zero(32n) : Word(32n)}:
  %Equal.sym(Word(32n), word(Bytes.bswap(written_lo(True{}, s, n, v, lo))),
    Word.or(32n, word(Bytes.bswap(lo)), wshr(U32.to_nat(s), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v)))),
    msb_lo_word(s, n, v, lo)) :
    {low(32n, Nat.sub(U32.to_nat(U32.sub(32, n)), U32.to_nat(s)), _) == Word.zero(32n) : Word(32n)}
  low_or_zero(32n, Nat.sub(U32.to_nat(U32.sub(32, n)), U32.to_nat(s)), word(Bytes.bswap(lo)),
    wshr(U32.to_nat(s), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v))),
    low_zero_weaken(32n, Nat.sub(U32.to_nat(U32.sub(32, n)), U32.to_nat(s)), U32.to_nat(U32.sub(32, s)), word(Bytes.bswap(lo)),
      msb_suffix_bound(s, n, hs, hn), and_mask_zero(Bytes.bswap(lo), U32.sub(32, s), hl)),
    low_zero_shr(32n, U32.to_nat(U32.sub(32, n)), U32.to_nat(s), wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v)),
      low_shift_zero(32n, U32.to_nat(U32.sub(32, n)), word(v))))

def msb_hi_suffix(+s: U32, +n: U32, +v: U32) -> {
  low(32n, Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(U32.sub(32, n))), word(Bytes.bswap(written_hi(True{}, s, n, v))))
  == Word.zero(32n) : Word(32n)}:
  %Equal.sym(Word(32n), word(Bytes.bswap(written_hi(True{}, s, n, v))),
    wshl(U32.to_nat(U32.sub(32, s)), 32n, wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v))), msb_hi_word(s, n, v)) :
    {low(32n, Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(U32.sub(32, n))), _) == Word.zero(32n) : Word(32n)}
  low_zero_shl(32n, U32.to_nat(U32.sub(32, n)), U32.to_nat(U32.sub(32, s)),
    wshl(U32.to_nat(U32.sub(32, n)), 32n, word(v)), low_shift_zero(32n, U32.to_nat(U32.sub(32, n)), word(v)))

def zero_and(+d: Nat, +w: Word(d)) -> {Word.and(d, Word.zero(d), w) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match w:
        case WCon{x, +t}:
          Equal.cong(Word(p), Word(1n+p), z => WCon{False{}, z}, Word.and(p, Word.zero(p), t), Word.zero(p), zero_and(p, t))

def low_suffix(+d: Nat, +k: Nat, +w: Word(d)) -> {
  Word.and(d, low(d, k, w), Word.not(d, low_mask(d, k))) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      match k:
        case 0n:
          zero_and(1n+p, Word.not(1n+p, Word.zero(1n+p)))
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              %and_false(x) : {WCon{Bool.and(x, False{}), Word.and(p, low(p, q, t), Word.not(p, low_mask(p, q)))} == WCon{_, Word.zero(p)} : Word(1n+p)}
              %low_suffix(p, q, t) : {WCon{Bool.and(x, False{}), Word.and(p, low(p, q, t), Word.not(p, low_mask(p, q)))} == WCon{Bool.and(x, False{}), _} : Word(1n+p)}
              {==}

def prefix_suffix(+d: Nat, +k: Nat, +w: Word(d), h: {low(d, k, w) == w : Word(d)}) -> {
  Word.and(d, w, Word.not(d, low_mask(d, k))) == Word.zero(d) : Word(d)}:
  %h : {Word.and(d, _, Word.not(d, low_mask(d, k))) == Word.zero(d) : Word(d)}
  low_suffix(d, k, w)

# Keep word widths generic to avoid checker expansion: https://github.com/bendlang/bend/issues/1071.
def low_or_shift(+d: Nat, +n: Nat, +c: Nat, +a: Word(d), +b: Word(d), h: MNat.le(n, c)) -> {
  low(d, n, Word.or(d, a, wshl(c, d, b))) == low(d, n, a) : Word(d)}:
  Equal.trans(Word(d), low(d, n, Word.or(d, a, wshl(c, d, b))),
    Word.or(d, low(d, n, a), low(d, n, wshl(c, d, b))), low(d, n, a),
    low_or(d, n, a, wshl(c, d, b)),
    Equal.trans(Word(d), Word.or(d, low(d, n, a), low(d, n, wshl(c, d, b))),
      Word.or(d, low(d, n, a), Word.zero(d)), low(d, n, a),
      Equal.cong(Word(d), Word(d), x => Word.or(d, low(d, n, a), x),
        low(d, n, wshl(c, d, b)), Word.zero(d),
        low_zero_weaken(d, n, c, wshl(c, d, b), h, low_shift_zero(d, c, b))),
      word_or_zero(d, low(d, n, a))))

def shr_zero(+d: Nat) -> {Word.shr(d, Word.zero(d)) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      {==}
    case 1n+ +p:
      pad_zero(p)

def wshr_zero(+s: Nat, +d: Nat) -> {wshr(s, d, Word.zero(d)) == Word.zero(d) : Word(d)}:
  match s:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.trans(Word(d), Word.shr(d, wshr(q, d, Word.zero(d))), Word.shr(d, Word.zero(d)), Word.zero(d),
        Equal.cong(Word(d), Word(d), x => Word.shr(d, x), wshr(q, d, Word.zero(d)), Word.zero(d), wshr_zero(q, d)),
        shr_zero(d))

def wshr_large(+d: Nat, +s: Nat, +w: Word(d), h: MNat.le(d, s)) -> {
  wshr(s, d, w) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      match w:
        case WNil{}:
          wshr_zero(s, 0n)
    case 1n+ +p:
      match s:
        case 0n:
          Empty.absurd({wshr(0n, 1n+p, w) == Word.zero(1n+p) : Word(1n+p)},
            MNat.succ_ne_zero(p)(MNat.le_zero_eq(1n+p, h)))
        case 1n+ +q:
          match w:
            case WCon{+x, +t}:
              Equal.trans(Word(1n+p), wshr(1n+q, 1n+p, WCon{x, t}),
                Word.shr.pad(p, wshr(q, p, t)), Word.zero(1n+p), wshr_con(q, p, x, t),
                Equal.trans(Word(1n+p), Word.shr.pad(p, wshr(q, p, t)), Word.shr.pad(p, Word.zero(p)), Word.zero(1n+p),
                  Equal.cong(Word(p), Word(1n+p), z => Word.shr.pad(p, z), wshr(q, p, t), Word.zero(p), wshr_large(p, q, t, h)),
                  pad_zero(p)))

def wshr_add(+s: Nat, +c: Nat, +d: Nat, +w: Word(d)) -> {
  wshr(s, d, wshr(c, d, w)) == wshr(Nat.add(s, c), d, w) : Word(d)}:
  match s:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.cong(Word(d), Word(d), x => Word.shr(d, x),
        wshr(q, d, wshr(c, d, w)), wshr(Nat.add(q, c), d, w), wshr_add(q, c, d, w))

def wshr_or(+s: Nat, +d: Nat, +a: Word(d), +b: Word(d)) -> {
  wshr(s, d, Word.or(d, a, b)) == Word.or(d, wshr(s, d, a), wshr(s, d, b)) : Word(d)}:
  match s:
    case 0n:
      {==}
    case 1n+ +q:
      Equal.trans(Word(d), Word.shr(d, wshr(q, d, Word.or(d, a, b))),
        Word.shr(d, Word.or(d, wshr(q, d, a), wshr(q, d, b))),
        Word.or(d, Word.shr(d, wshr(q, d, a)), Word.shr(d, wshr(q, d, b))),
        Equal.cong(Word(d), Word(d), x => Word.shr(d, x),
          wshr(q, d, Word.or(d, a, b)), Word.or(d, wshr(q, d, a), wshr(q, d, b)), wshr_or(q, d, a, b)),
        shr_or(d, wshr(q, d, a), wshr(q, d, b)))

def shr_or_shift(+d: Nat, +k: Nat, +c: Nat, +a: Word(d), +b: Word(d), h: MNat.le(d, Nat.add(k, c))) -> {
  wshr(k, d, Word.or(d, a, wshr(c, d, b))) == wshr(k, d, a) : Word(d)}:
  Equal.trans(Word(d), wshr(k, d, Word.or(d, a, wshr(c, d, b))),
    Word.or(d, wshr(k, d, a), wshr(k, d, wshr(c, d, b))), wshr(k, d, a),
    wshr_or(k, d, a, wshr(c, d, b)),
    Equal.trans(Word(d), Word.or(d, wshr(k, d, a), wshr(k, d, wshr(c, d, b))),
      Word.or(d, wshr(k, d, a), Word.zero(d)), wshr(k, d, a),
      Equal.cong(Word(d), Word(d), x => Word.or(d, wshr(k, d, a), x),
        wshr(k, d, wshr(c, d, b)), Word.zero(d),
        Equal.trans(Word(d), wshr(k, d, wshr(c, d, b)), wshr(Nat.add(k, c), d, b), Word.zero(d),
          wshr_add(k, c, d, b), wshr_large(d, Nat.add(k, c), b, h))),
      word_or_zero(d, wshr(k, d, a))))

def lsb_field_join(+s: U32, +n: U32, +lo: U32, +hi: U32,
  h: MNat.le(U32.to_nat(n), U32.to_nat(U32.sub(32, s)))) -> {
  Bits.field(False{}, n, lsb_join(s, lo, hi)) == Bits.field(False{}, n, U32.shrn(lo, U32.to_nat(s))) : U32}:
  %Equal.sym(U32, U32.and(lsb_join(s, lo, hi), Bits.mask(n)),
    U32{low(32n, U32.to_nat(n), word(lsb_join(s, lo, hi)))}, and_mask_word(lsb_join(s, lo, hi), n)) :
    {_ == Bits.field(False{}, n, U32.shrn(lo, U32.to_nat(s))) : U32}
  %Equal.sym(U32, U32.and(U32.shrn(lo, U32.to_nat(s)), Bits.mask(n)),
    U32{low(32n, U32.to_nat(n), word(U32.shrn(lo, U32.to_nat(s))))},
    and_mask_word(U32.shrn(lo, U32.to_nat(s)), n)) :
    {U32{low(32n, U32.to_nat(n), word(lsb_join(s, lo, hi)))} == _ : U32}
  Equal.cong(Word(32n), U32, x => U32{x},
    low(32n, U32.to_nat(n), word(lsb_join(s, lo, hi))),
    low(32n, U32.to_nat(n), word(U32.shrn(lo, U32.to_nat(s)))),
    Equal.trans(Word(32n), low(32n, U32.to_nat(n), word(lsb_join(s, lo, hi))),
      low(32n, U32.to_nat(n), Word.or(32n, word(U32.shrn(lo, U32.to_nat(s))),
        wshl(U32.to_nat(U32.sub(32, s)), 32n, word(hi)))),
      low(32n, U32.to_nat(n), word(U32.shrn(lo, U32.to_nat(s)))),
      Equal.cong(Word(32n), Word(32n), x => low(32n, U32.to_nat(n), x),
        word(lsb_join(s, lo, hi)),
        Word.or(32n, word(U32.shrn(lo, U32.to_nat(s))), wshl(U32.to_nat(U32.sub(32, s)), 32n, word(hi))),
        Equal.trans(Word(32n), word(lsb_join(s, lo, hi)),
          Word.or(32n, word(U32.shrn(lo, U32.to_nat(s))), word(U32.shln(hi, U32.to_nat(U32.sub(32, s))))),
          Word.or(32n, word(U32.shrn(lo, U32.to_nat(s))), wshl(U32.to_nat(U32.sub(32, s)), 32n, word(hi))),
          word_or(U32.shrn(lo, U32.to_nat(s)), U32.shln(hi, U32.to_nat(U32.sub(32, s)))),
          Equal.cong(Word(32n), Word(32n), x => Word.or(32n, word(U32.shrn(lo, U32.to_nat(s))), x),
            word(U32.shln(hi, U32.to_nat(U32.sub(32, s)))), wshl(U32.to_nat(U32.sub(32, s)), 32n, word(hi)),
            word_shln(U32.to_nat(U32.sub(32, s)), hi)))),
      low_or_shift(32n, U32.to_nat(n), U32.to_nat(U32.sub(32, s)), word(U32.shrn(lo, U32.to_nat(s))), word(hi), h)))

def shrn_shrn_zero(+k: Nat, +c: Nat, +v: U32, h: MNat.le(32n, Nat.add(k, c))) -> {
  U32.shrn(U32.shrn(v, c), k) == 0 : U32}:
  Equal.trans(U32, U32.shrn(U32.shrn(v, c), k),
    U32{wshr(k, 32n, wshr(c, 32n, word(v)))}, 0,
    Equal.trans(U32, U32.shrn(U32.shrn(v, c), k),
      U32{wshr(k, 32n, word(U32.shrn(v, c)))},
      U32{wshr(k, 32n, wshr(c, 32n, word(v)))},
      shrn_word(k, U32.shrn(v, c)),
      Equal.cong(Word(32n), U32, x => U32{wshr(k, 32n, x)},
        word(U32.shrn(v, c)), wshr(c, 32n, word(v)), word_shrn(c, v))),
    Equal.cong(Word(32n), U32, x => U32{x},
      wshr(k, 32n, wshr(c, 32n, word(v))), Word.zero(32n),
      Equal.trans(Word(32n), wshr(k, 32n, wshr(c, 32n, word(v))),
        wshr(Nat.add(k, c), 32n, word(v)), Word.zero(32n),
        wshr_add(k, c, 32n, word(v)), wshr_large(32n, Nat.add(k, c), word(v), h))))

def complement_lower(+n: U32, +c: Nat, hn: MNat.le(U32.to_nat(n), 32n), h: MNat.le(U32.to_nat(n), c)) -> 
  MNat.le(32n, Nat.add(U32.to_nat(U32.sub(32, n)), c)):
  %Equal.trans(Nat, Nat.add(U32.to_nat(U32.sub(32, n)), U32.to_nat(n)),
    Nat.add(U32.to_nat(n), U32.to_nat(U32.sub(32, n))), 32n,
    MNat.add_comm(U32.to_nat(U32.sub(32, n)), U32.to_nat(n)), complement_sum(n, hn)) :
    MNat.le(_, Nat.add(U32.to_nat(U32.sub(32, n)), c))
  MNat.add_le_add_left(U32.to_nat(n), c, U32.to_nat(U32.sub(32, n)), h)

def msb_field_join(+s: U32, +n: U32, +lo: U32, +hi: U32,
  hn: MNat.le(U32.to_nat(n), 32n), h: MNat.le(U32.to_nat(n), U32.to_nat(U32.sub(32, s)))) -> {
  Bits.field(True{}, n, msb_join(s, lo, hi)) == Bits.field(True{}, n, U32.shln(Bytes.bswap(lo), U32.to_nat(s))) : U32}:
  Equal.trans(U32, Bits.field(True{}, n, msb_join(s, lo, hi)),
    U32.or(U32.shrn(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.to_nat(U32.sub(32, n))),
      U32.shrn(U32.shrn(Bytes.bswap(hi), U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, n)))),
    Bits.field(True{}, n, U32.shln(Bytes.bswap(lo), U32.to_nat(s))),
    shrn_or(U32.to_nat(U32.sub(32, n)), U32.shln(Bytes.bswap(lo), U32.to_nat(s)),
      U32.shrn(Bytes.bswap(hi), U32.to_nat(U32.sub(32, s)))),
    Equal.trans(U32,
      U32.or(U32.shrn(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.to_nat(U32.sub(32, n))),
        U32.shrn(U32.shrn(Bytes.bswap(hi), U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, n)))),
      U32.or(U32.shrn(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.to_nat(U32.sub(32, n))), 0),
      Bits.field(True{}, n, U32.shln(Bytes.bswap(lo), U32.to_nat(s))),
      Equal.cong(U32, U32, x => U32.or(U32.shrn(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.to_nat(U32.sub(32, n))), x),
        U32.shrn(U32.shrn(Bytes.bswap(hi), U32.to_nat(U32.sub(32, s))), U32.to_nat(U32.sub(32, n))), 0,
        shrn_shrn_zero(U32.to_nat(U32.sub(32, n)), U32.to_nat(U32.sub(32, s)), Bytes.bswap(hi),
          complement_lower(n, U32.to_nat(U32.sub(32, s)), hn, h))),
      Equal.trans(U32, U32.or(U32.shrn(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.to_nat(U32.sub(32, n))), 0),
        U32.or(0, U32.shrn(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.to_nat(U32.sub(32, n)))),
        Bits.field(True{}, n, U32.shln(Bytes.bswap(lo), U32.to_nat(s))),
        u32_or_comm(U32.shrn(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.to_nat(U32.sub(32, n))), 0),
        u32_zero_or(U32.shrn(U32.shln(Bytes.bswap(lo), U32.to_nat(s)), U32.to_nat(U32.sub(32, n)))))))

def lsb_noncrossing_field(+s: U32, +n: U32, +v: U32, +lo: U32, +hi: U32,
  hs: MNat.le(U32.to_nat(s), 32n), hn: MNat.le(U32.to_nat(n), 32n),
  +h: MNat.le(U32.to_nat(n), U32.to_nat(U32.sub(32, s))),
  hl: {U32.and(lo, U32.not(Bits.mask(s))) == 0 : U32}) -> {
  Bits.field(False{}, n, lsb_join(s, written_lo(False{}, s, n, v, lo), hi)) == U32.and(v, Bits.mask(n)) : U32}:
  Equal.trans(U32, Bits.field(False{}, n, lsb_join(s, written_lo(False{}, s, n, v, lo), hi)),
    Bits.field(False{}, n, U32.shrn(written_lo(False{}, s, n, v, lo), U32.to_nat(s))),
    U32.and(v, Bits.mask(n)), lsb_field_join(s, n, written_lo(False{}, s, n, v, lo), hi, h),
    Equal.trans(U32, Bits.field(False{}, n, U32.shrn(written_lo(False{}, s, n, v, lo), U32.to_nat(s))),
      lsb_after(s, n, v, lo), U32.and(v, Bits.mask(n)),
      Equal.sym(U32, lsb_after(s, n, v, lo),
        Bits.field(False{}, n, U32.shrn(written_lo(False{}, s, n, v, lo), U32.to_nat(s))),
        lsb_field_join(s, n, written_lo(False{}, s, n, v, lo), written_hi(False{}, s, n, v), h)),
      lsb_field(s, n, v, lo, hs, hn, hl)))

def msb_noncrossing_field(+s: U32, +n: U32, +v: U32, +lo: U32, +hi: U32,
  hs: MNat.le(U32.to_nat(s), 32n), +hn: MNat.le(U32.to_nat(n), 32n),
  +h: MNat.le(U32.to_nat(n), U32.to_nat(U32.sub(32, s))),
  hl: {U32.and(Bytes.bswap(lo), Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  Bits.field(True{}, n, msb_join(s, written_lo(True{}, s, n, v, lo), hi)) == U32.and(v, Bits.mask(n)) : U32}:
  Equal.trans(U32, Bits.field(True{}, n, msb_join(s, written_lo(True{}, s, n, v, lo), hi)),
    Bits.field(True{}, n, U32.shln(Bytes.bswap(written_lo(True{}, s, n, v, lo)), U32.to_nat(s))),
    U32.and(v, Bits.mask(n)), msb_field_join(s, n, written_lo(True{}, s, n, v, lo), hi, hn, h),
    Equal.trans(U32, Bits.field(True{}, n, U32.shln(Bytes.bswap(written_lo(True{}, s, n, v, lo)), U32.to_nat(s))),
      msb_after(s, n, v, lo), U32.and(v, Bits.mask(n)),
      Equal.sym(U32, msb_after(s, n, v, lo),
        Bits.field(True{}, n, U32.shln(Bytes.bswap(written_lo(True{}, s, n, v, lo)), U32.to_nat(s))),
        msb_field_join(s, n, written_lo(True{}, s, n, v, lo), written_hi(True{}, s, n, v), hn, h)),
      msb_field(s, n, v, lo, hs, hn, hl)))

def prefix_clean(+v: U32, +n: U32, h: {low(32n, U32.to_nat(n), word(v)) == word(v) : Word(32n)}) -> {
  U32.and(v, U32.not(Bits.mask(n))) == 0 : U32}:
  match v:
    case U32{+w}:
      %Equal.sym(U32, Bits.mask(n), U32{low_mask(32n, U32.to_nat(n))}, mask_word(n)) :
        {U32.and(U32{w}, U32.not(_)) == 0 : U32}
      Equal.cong(Word(32n), U32, x => U32{x},
        Word.and(32n, w, Word.not(32n, low_mask(32n, U32.to_nat(n)))), Word.zero(32n),
        prefix_suffix(32n, U32.to_nat(n), w, h))

def low_clean(+v: U32, +n: U32, h: {low(32n, U32.to_nat(n), word(v)) == Word.zero(32n) : Word(32n)}) -> {
  U32.and(v, Bits.mask(n)) == 0 : U32}:
  Equal.trans(U32, U32.and(v, Bits.mask(n)), U32{low(32n, U32.to_nat(n), word(v))}, 0,
    and_mask_word(v, n),
    Equal.cong(Word(32n), U32, x => U32{x}, low(32n, U32.to_nat(n), word(v)), Word.zero(32n), h))

def lsb_noncrossing_roundtrip(+s: U32, +n: U32, +v: U32, +lo: U32, +hi: U32,
  hs: MNat.le(U32.to_nat(s), 32n), +hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(U32.to_nat(n), U32.to_nat(U32.sub(32, s))),
  hl: {U32.and(lo, U32.not(Bits.mask(s))) == 0 : U32}) -> {
  U32.to_nat(Bits.field(False{}, n, lsb_join(s, written_lo(False{}, s, n, v, lo), hi)))
  == Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  Equal.trans(Nat, U32.to_nat(Bits.field(False{}, n, lsb_join(s, written_lo(False{}, s, n, v, lo), hi))),
    U32.to_nat(U32.and(v, Bits.mask(n))), Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))),
    Equal.cong(U32, Nat, U32.to_nat,
      Bits.field(False{}, n, lsb_join(s, written_lo(False{}, s, n, v, lo), hi)), U32.and(v, Bits.mask(n)),
      lsb_noncrossing_field(s, n, v, lo, hi, hs, hn, h, hl)),
    mask_mod(v, n, hn))

def msb_noncrossing_roundtrip(+s: U32, +n: U32, +v: U32, +lo: U32, +hi: U32,
  hs: MNat.le(U32.to_nat(s), 32n), +hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(U32.to_nat(n), U32.to_nat(U32.sub(32, s))),
  hl: {U32.and(Bytes.bswap(lo), Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  U32.to_nat(Bits.field(True{}, n, msb_join(s, written_lo(True{}, s, n, v, lo), hi)))
  == Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))) : Nat}:
  Equal.trans(Nat, U32.to_nat(Bits.field(True{}, n, msb_join(s, written_lo(True{}, s, n, v, lo), hi))),
    U32.to_nat(U32.and(v, Bits.mask(n))), Nat.mod(U32.to_nat(v), Lemmas.pow2(U32.to_nat(n))),
    Equal.cong(U32, Nat, U32.to_nat,
      Bits.field(True{}, n, msb_join(s, written_lo(True{}, s, n, v, lo), hi)), U32.and(v, Bits.mask(n)),
      msb_noncrossing_field(s, n, v, lo, hi, hs, hn, h, hl)),
    mask_mod(v, n, hn))

def lsb_lo_clean(+s: U32, +n: U32, +v: U32, +lo: U32, +end: U32,
  he: {U32.to_nat(end) == Nat.add(U32.to_nat(s), U32.to_nat(n)) : Nat},
  hl: {U32.and(lo, U32.not(Bits.mask(s))) == 0 : U32}) -> {
  U32.and(written_lo(False{}, s, n, v, lo), U32.not(Bits.mask(end))) == 0 : U32}:
  prefix_clean(written_lo(False{}, s, n, v, lo), end,
    Equal.trans(Word(32n), low(32n, U32.to_nat(end), word(written_lo(False{}, s, n, v, lo))),
      low(32n, Nat.add(U32.to_nat(s), U32.to_nat(n)), word(written_lo(False{}, s, n, v, lo))),
      word(written_lo(False{}, s, n, v, lo)),
      Equal.cong(Nat, Word(32n), k => low(32n, k, word(written_lo(False{}, s, n, v, lo))),
        U32.to_nat(end), Nat.add(U32.to_nat(s), U32.to_nat(n)), he),
      lsb_lo_suffix(s, n, v, lo, hl)))

def lsb_hi_clean(+s: U32, +n: U32, +v: U32, +end: U32,
  he: {U32.to_nat(end) == Nat.sub(U32.to_nat(n), U32.to_nat(U32.sub(32, s))) : Nat}) -> {
  U32.and(written_hi(False{}, s, n, v), U32.not(Bits.mask(end))) == 0 : U32}:
  prefix_clean(written_hi(False{}, s, n, v), end,
    Equal.trans(Word(32n), low(32n, U32.to_nat(end), word(written_hi(False{}, s, n, v))),
      low(32n, Nat.sub(U32.to_nat(n), U32.to_nat(U32.sub(32, s))), word(written_hi(False{}, s, n, v))),
      word(written_hi(False{}, s, n, v)),
      Equal.cong(Nat, Word(32n), k => low(32n, k, word(written_hi(False{}, s, n, v))),
        U32.to_nat(end), Nat.sub(U32.to_nat(n), U32.to_nat(U32.sub(32, s))), he),
      lsb_hi_suffix(s, n, v)))

def msb_lo_clean(+s: U32, +n: U32, +v: U32, +lo: U32, +end: U32,
  hs: MNat.le(U32.to_nat(s), 32n), hn: MNat.le(U32.to_nat(n), 32n),
  he: {U32.to_nat(end) == Nat.sub(U32.to_nat(U32.sub(32, n)), U32.to_nat(s)) : Nat},
  hl: {U32.and(Bytes.bswap(lo), Bits.mask(U32.sub(32, s))) == 0 : U32}) -> {
  U32.and(Bytes.bswap(written_lo(True{}, s, n, v, lo)), Bits.mask(end)) == 0 : U32}:
  low_clean(Bytes.bswap(written_lo(True{}, s, n, v, lo)), end,
    Equal.trans(Word(32n), low(32n, U32.to_nat(end), word(Bytes.bswap(written_lo(True{}, s, n, v, lo)))),
      low(32n, Nat.sub(U32.to_nat(U32.sub(32, n)), U32.to_nat(s)), word(Bytes.bswap(written_lo(True{}, s, n, v, lo)))),
      Word.zero(32n),
      Equal.cong(Nat, Word(32n), k => low(32n, k, word(Bytes.bswap(written_lo(True{}, s, n, v, lo)))),
        U32.to_nat(end), Nat.sub(U32.to_nat(U32.sub(32, n)), U32.to_nat(s)), he),
      msb_lo_suffix(s, n, v, lo, hs, hn, hl)))

def msb_hi_clean(+s: U32, +n: U32, +v: U32, +end: U32,
  he: {U32.to_nat(end) == Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(U32.sub(32, n))) : Nat}) -> {
  U32.and(Bytes.bswap(written_hi(True{}, s, n, v)), Bits.mask(end)) == 0 : U32}:
  low_clean(Bytes.bswap(written_hi(True{}, s, n, v)), end,
    Equal.trans(Word(32n), low(32n, U32.to_nat(end), word(Bytes.bswap(written_hi(True{}, s, n, v)))),
      low(32n, Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(U32.sub(32, n))), word(Bytes.bswap(written_hi(True{}, s, n, v)))),
      Word.zero(32n),
      Equal.cong(Nat, Word(32n), k => low(32n, k, word(Bytes.bswap(written_hi(True{}, s, n, v)))),
        U32.to_nat(end), Nat.add(U32.to_nat(U32.sub(32, s)), U32.to_nat(U32.sub(32, n))), he),
      msb_hi_suffix(s, n, v)))
