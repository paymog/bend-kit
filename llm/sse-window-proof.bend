import Base
import ../bytes/bytes.bend as Bytes
import ../bits/field-proof.bend as Field
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ../bytes/append-proof.bend as Model
import ../lemmas/array.bend as Tree
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas

def low_or_right_zero(+d: Nat, +n: Nat, +a: Word(d), +b: Word(d),
  h: {Field.low(d, n, b) == Word.zero(d) : Word(d)}) ->
  {Field.low(d, n, Word.or(d, a, b)) == Field.low(d, n, a) : Word(d)}:
  %Equal.sym(Word(d), Field.low(d, n, Word.or(d, a, b)),
    Word.or(d, Field.low(d, n, a), Field.low(d, n, b)), Field.low_or(d, n, a, b)) :
    {_ == Field.low(d, n, a) : Word(d)}
  %Equal.sym(Word(d), Field.low(d, n, b), Word.zero(d), h) :
    {Word.or(d, Field.low(d, n, a), _) == Field.low(d, n, a) : Word(d)}
  Field.word_or_zero(d, Field.low(d, n, a))

def window_low(+d: Nat, +n: Nat, +k: Nat, +lo: Nat, +hi: Nat, +a: Word(d), +b: Word(d),
  h: MNat.le(n, Nat.sub(hi, k))) ->
  {Field.low(d, n, Field.wshr(k, d, Word.or(d, Field.wshr(lo, d, a), Field.wshl(hi, d, b)))) ==
    Field.low(d, n, Field.wshr(Nat.add(k, lo), d, a)) : Word(d)}:
  +left = Field.wshr(lo, d, a)
  +right = Field.wshl(hi, d, b)
  %Equal.sym(Word(d), Field.wshr(k, d, Word.or(d, left, right)),
    Word.or(d, Field.wshr(k, d, left), Field.wshr(k, d, right)), Field.wshr_or(k, d, left, right)) :
    {Field.low(d, n, _) == Field.low(d, n, Field.wshr(Nat.add(k, lo), d, a)) : Word(d)}
  %Equal.sym(Word(d), Field.low(d, n, Word.or(d, Field.wshr(k, d, left), Field.wshr(k, d, right))),
    Field.low(d, n, Field.wshr(k, d, left)),
    low_or_right_zero(d, n, Field.wshr(k, d, left), Field.wshr(k, d, right),
      Field.low_zero_weaken(d, n, Nat.sub(hi, k), Field.wshr(k, d, right), h,
        Field.low_zero_shr(d, hi, k, right, Field.low_shift_zero(d, hi, b))))):
    {_ == Field.low(d, n, Field.wshr(Nat.add(k, lo), d, a)) : Word(d)}
  Equal.cong(Word(d), Word(d), w => Field.low(d, n, w),
    Field.wshr(k, d, left), Field.wshr(Nat.add(k, lo), d, a), Field.wshr_add(k, lo, d, a))

def shifted_window(+d: Nat, +n: Nat, +r: Nat, +lo: Nat, +hi: Nat, +b: Word(d),
  sum: {Nat.add(hi, lo) == d : Nat}, span: MNat.le(Nat.add(r, n), lo)) ->
  {Field.low(d, n, Field.wshr(Nat.add(r, hi), d, Field.wshl(hi, d, b))) ==
    Field.low(d, n, Field.wshr(r, d, b)) : Word(d)}:
  %Field.wshr_add(r, hi, d, Field.wshl(hi, d, b)) :
    {Field.low(d, n, _) == Field.low(d, n, Field.wshr(r, d, b)) : Word(d)}
  %Equal.sym(Word(d), Field.wshr(hi, d, Field.wshl(hi, d, b)), Field.low(d, lo, b), Field.shr_shl(d, hi, lo, b, sum)) :
    {Field.low(d, n, Field.wshr(r, d, _)) == Field.low(d, n, Field.wshr(r, d, b)) : Word(d)}
  %Equal.sym(Word(d), Field.low(d, n, Field.wshr(r, d, Field.low(d, lo, b))),
    Field.wshr(r, d, Field.low(d, Nat.add(r, n), Field.low(d, lo, b))), Field.low_wshr(r, d, n, Field.low(d, lo, b))) :
    {_ == Field.low(d, n, Field.wshr(r, d, b)) : Word(d)}
  %Equal.sym(Word(d), Field.low(d, Nat.add(r, n), Field.low(d, lo, b)),
    Field.low(d, Nat.add(r, n), b), Field.low_nest(d, Nat.add(r, n), lo, b, span)) :
    {Field.wshr(r, d, _) == Field.low(d, n, Field.wshr(r, d, b)) : Word(d)}
  Equal.sym(Word(d), Field.low(d, n, Field.wshr(r, d, b)),
    Field.wshr(r, d, Field.low(d, Nat.add(r, n), b)), Field.low_wshr(r, d, n, b))

def high_bound(+d: Nat, +r: Nat, +lo: Nat, +hi: Nat, sum: {Nat.add(hi, lo) == d : Nat}) ->
  MNat.le(d, Nat.add(Nat.add(r, hi), lo)):
  %Equal.sym(Nat, Nat.add(Nat.add(r, hi), lo), Nat.add(r, Nat.add(hi, lo)), MNat.add_assoc(r, hi, lo)) : MNat.le(d, _)
  %Equal.sym(Nat, Nat.add(hi, lo), d, sum) : MNat.le(d, Nat.add(r, _))
  MNat.le_add_left(d, r)

def window_high(+d: Nat, +n: Nat, +r: Nat, +lo: Nat, +hi: Nat, +a: Word(d), +b: Word(d),
  +sum: {Nat.add(hi, lo) == d : Nat}, span: MNat.le(Nat.add(r, n), lo)) ->
  {Field.low(d, n, Field.wshr(Nat.add(r, hi), d, Word.or(d, Field.wshr(lo, d, a), Field.wshl(hi, d, b)))) ==
    Field.low(d, n, Field.wshr(r, d, b)) : Word(d)}:
  %Equal.sym(Word(d), Word.or(d, Field.wshr(lo, d, a), Field.wshl(hi, d, b)),
    Word.or(d, Field.wshl(hi, d, b), Field.wshr(lo, d, a)), Field.word_or_comm(d, Field.wshr(lo, d, a), Field.wshl(hi, d, b))) :
    {Field.low(d, n, Field.wshr(Nat.add(r, hi), d, _)) == Field.low(d, n, Field.wshr(r, d, b)) : Word(d)}
  %Equal.sym(Word(d), Field.wshr(Nat.add(r, hi), d, Word.or(d, Field.wshl(hi, d, b), Field.wshr(lo, d, a))),
    Field.wshr(Nat.add(r, hi), d, Field.wshl(hi, d, b)),
    Field.shr_or_shift(d, Nat.add(r, hi), lo, Field.wshl(hi, d, b), a, high_bound(d, r, lo, hi, sum))) :
    {Field.low(d, n, _) == Field.low(d, n, Field.wshr(r, d, b)) : Word(d)}
  shifted_window(d, n, r, lo, hi, b, sum, span)

def joined(+a: U32, +b: U32, +lo: Nat, +hi: Nat) -> U32:
  (U32.shrn(a, lo) .|. U32.shln(b, hi) : U32)

def joined_word(+a: U32, +b: U32, +lo: Nat, +hi: Nat) ->
  {Field.word(joined(a, b, lo, hi)) ==
    Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b))) : Word(32n)}:
  %Equal.sym(Word(32n), Field.word(joined(a, b, lo, hi)),
    Word.or(32n, Field.word(U32.shrn(a, lo)), Field.word(U32.shln(b, hi))), Field.word_or(U32.shrn(a, lo), U32.shln(b, hi))) :
    {_ == Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b))) : Word(32n)}
  %Equal.sym(Word(32n), Field.word(U32.shrn(a, lo)), Field.wshr(lo, 32n, Field.word(a)), Field.word_shrn(lo, a)) :
    {Word.or(32n, _, Field.word(U32.shln(b, hi))) == Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b))) : Word(32n)}
  Equal.cong(Word(32n), Word(32n), w => Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), w),
    Field.word(U32.shln(b, hi)), Field.wshl(hi, 32n, Field.word(b)), Field.word_shln(hi, b))

def octet(+v: U32, +k: Nat) -> U32:
  Bytes.b8(U32.shrn(v, k))

def octet_word(+v: U32, +k: Nat) ->
  {octet(v, k) == U32{Field.low(32n, 8n, Field.wshr(k, 32n, Field.word(v)))} : U32}:
  %Equal.sym(U32, Bytes.b8(U32.shrn(v, k)), U32{Field.low(32n, 8n, Field.word(U32.shrn(v, k)))}, Field.and_mask_word(U32.shrn(v, k), 8)) :
    {_ == U32{Field.low(32n, 8n, Field.wshr(k, 32n, Field.word(v)))} : U32}
  Equal.cong(Word(32n), U32, w => U32{Field.low(32n, 8n, w)},
    Field.word(U32.shrn(v, k)), Field.wshr(k, 32n, Field.word(v)), Field.word_shrn(k, v))

def joined_octet_word(+a: U32, +b: U32, +lo: Nat, +hi: Nat, +k: Nat) ->
  {octet(joined(a, b, lo, hi), k) ==
    U32{Field.low(32n, 8n, Field.wshr(k, 32n, Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b)))))} : U32}:
  Equal.trans(U32, octet(joined(a, b, lo, hi), k),
    U32{Field.low(32n, 8n, Field.wshr(k, 32n, Field.word(joined(a, b, lo, hi))))},
    U32{Field.low(32n, 8n, Field.wshr(k, 32n, Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b)))))},
    octet_word(joined(a, b, lo, hi), k),
    Equal.cong(Word(32n), U32, w => U32{Field.low(32n, 8n, Field.wshr(k, 32n, w))},
      Field.word(joined(a, b, lo, hi)),
      Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b))), joined_word(a, b, lo, hi)))

def octet_low(+a: U32, +b: U32, +lo: Nat, +hi: Nat, +k: Nat, h: MNat.le(8n, Nat.sub(hi, k))) ->
  {octet(joined(a, b, lo, hi), k) == octet(a, Nat.add(k, lo)) : U32}:
  %Equal.sym(U32, octet(joined(a, b, lo, hi), k),
    U32{Field.low(32n, 8n, Field.wshr(k, 32n, Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b)))))},
    joined_octet_word(a, b, lo, hi, k)) :
    {_ == octet(a, Nat.add(k, lo)) : U32}
  %Equal.sym(U32, octet(a, Nat.add(k, lo)), U32{Field.low(32n, 8n, Field.wshr(Nat.add(k, lo), 32n, Field.word(a)))}, octet_word(a, Nat.add(k, lo))) :
    {U32{Field.low(32n, 8n, Field.wshr(k, 32n, Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b)))))} == _ : U32}
  Equal.cong(Word(32n), U32, w => U32{w},
    Field.low(32n, 8n, Field.wshr(k, 32n, Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b))))),
    Field.low(32n, 8n, Field.wshr(Nat.add(k, lo), 32n, Field.word(a))),
    window_low(32n, 8n, k, lo, hi, Field.word(a), Field.word(b), h))

def octet_high(+a: U32, +b: U32, +lo: Nat, +hi: Nat, +r: Nat,
  sum: {Nat.add(hi, lo) == 32n : Nat}, span: MNat.le(Nat.add(r, 8n), lo)) ->
  {octet(joined(a, b, lo, hi), Nat.add(r, hi)) == octet(b, r) : U32}:
  %Equal.sym(U32, octet(joined(a, b, lo, hi), Nat.add(r, hi)),
    U32{Field.low(32n, 8n, Field.wshr(Nat.add(r, hi), 32n, Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b)))))},
    joined_octet_word(a, b, lo, hi, Nat.add(r, hi))) :
    {_ == octet(b, r) : U32}
  %Equal.sym(U32, octet(b, r), U32{Field.low(32n, 8n, Field.wshr(r, 32n, Field.word(b)))}, octet_word(b, r)) :
    {U32{Field.low(32n, 8n, Field.wshr(Nat.add(r, hi), 32n, Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b)))))} == _ : U32}
  Equal.cong(Word(32n), U32, w => U32{w},
    Field.low(32n, 8n, Field.wshr(Nat.add(r, hi), 32n, Word.or(32n, Field.wshr(lo, 32n, Field.word(a)), Field.wshl(hi, 32n, Field.word(b))))),
    Field.low(32n, 8n, Field.wshr(r, 32n, Field.word(b))),
    window_high(32n, 8n, r, lo, hi, Field.word(a), Field.word(b), sum, span))

def quotient(+i: U32) -> Nat:
  U32.to_nat((i >> 2n : U32))

def lane(+i: U32) -> Nat:
  U32.to_nat((i .&. 3 : U32))

def mod4_blocks(q: Nat, +r: Nat) ->
  {Nat.mod(Nat.add(Nat.mul(q, 4n), r), 4n) == Nat.mod(r, 4n) : Nat}:
  match q:
    case 0n:
      {==}
    case 1n+ +p:
      Equal.trans(Nat, Nat.mod(Nat.add(Nat.mul(q, 4n), r), 4n),
        Nat.mod(Nat.add(Nat.mul(p, 4n), r), 4n), Nat.mod(r, 4n),
        MNat.add_mod_left(Nat.add(Nat.mul(p, 4n), r), 4n), mod4_blocks(p, r))

def sum_blocks(+s: U32, +i: U32, +limit: Nat,
  h: MNat.lt(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {U32.to_nat((s + i : U32)) ==
    Nat.add(Nat.mul(Nat.add(quotient(s), quotient(i)), 4n), Nat.add(lane(s), lane(i))) : Nat}:
  %Equal.sym(Nat, U32.to_nat((s + i : U32)), Nat.add(U32.to_nat(s), U32.to_nat(i)),
    Lemmas.u32_add_nat(s, i, MNat.lt_of_lt_of_le(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit, Lemmas.pow2(32n), h, hu))) :
    {_ == Nat.add(Nat.mul(Nat.add(quotient(s), quotient(i)), 4n), Nat.add(lane(s), lane(i))) : Nat}
  %Model.index_nat(s) :
    {Nat.add(_, U32.to_nat(i)) == Nat.add(Nat.mul(Nat.add(quotient(s), quotient(i)), 4n), Nat.add(lane(s), lane(i))) : Nat}
  %Model.index_nat(i) :
    {Nat.add(Nat.add(Nat.mul(quotient(s), 4n), lane(s)), _) ==
      Nat.add(Nat.mul(Nat.add(quotient(s), quotient(i)), 4n), Nat.add(lane(s), lane(i))) : Nat}
  Equal.trans(Nat,
    Nat.add(Nat.add(Nat.mul(quotient(s), 4n), lane(s)), Nat.add(Nat.mul(quotient(i), 4n), lane(i))),
    Nat.add(Nat.add(Nat.mul(quotient(s), 4n), Nat.mul(quotient(i), 4n)), Nat.add(lane(s), lane(i))),
    Nat.add(Nat.mul(Nat.add(quotient(s), quotient(i)), 4n), Nat.add(lane(s), lane(i))),
    MNat.add_add_add_comm(Nat.mul(quotient(s), 4n), lane(s), Nat.mul(quotient(i), 4n), lane(i)),
    Equal.cong(Nat, Nat, q => Nat.add(q, Nat.add(lane(s), lane(i))),
      Nat.add(Nat.mul(quotient(s), 4n), Nat.mul(quotient(i), 4n)), Nat.mul(Nat.add(quotient(s), quotient(i)), 4n),
      Equal.sym(Nat, Nat.mul(Nat.add(quotient(s), quotient(i)), 4n),
        Nat.add(Nat.mul(quotient(s), 4n), Nat.mul(quotient(i), 4n)), MNat.add_mul(quotient(s), quotient(i), 4n))))

def sum_word_nat(+s: U32, +i: U32, +limit: Nat,
  h: MNat.lt(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {quotient((s + i : U32)) == Nat.add(Nat.add(quotient(s), quotient(i)), Nat.div(Nat.add(lane(s), lane(i)), 4n)) : Nat}:
  %Equal.sym(Nat, quotient((s + i : U32)), Nat.div(U32.to_nat((s + i : U32)), 4n), Field.shrn_nat((s + i : U32), 2n)) :
    {_ == Nat.add(Nat.add(quotient(s), quotient(i)), Nat.div(Nat.add(lane(s), lane(i)), 4n)) : Nat}
  %Equal.sym(Nat, U32.to_nat((s + i : U32)),
    Nat.add(Nat.mul(Nat.add(quotient(s), quotient(i)), 4n), Nat.add(lane(s), lane(i))), sum_blocks(s, i, limit, h, hu)) :
    {Nat.div(_, 4n) == Nat.add(Nat.add(quotient(s), quotient(i)), Nat.div(Nat.add(lane(s), lane(i)), 4n)) : Nat}
  Model.div4_blocks(Nat.add(quotient(s), quotient(i)), Nat.add(lane(s), lane(i)))

def sum_lane_nat(+s: U32, +i: U32, +limit: Nat,
  h: MNat.lt(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {lane((s + i : U32)) == Nat.mod(Nat.add(lane(s), lane(i)), 4n) : Nat}:
  %Equal.sym(Nat, lane((s + i : U32)), Nat.mod(U32.to_nat((s + i : U32)), 4n), Field.mask_mod((s + i : U32), 2, {==})) :
    {_ == Nat.mod(Nat.add(lane(s), lane(i)), 4n) : Nat}
  %Equal.sym(Nat, U32.to_nat((s + i : U32)),
    Nat.add(Nat.mul(Nat.add(quotient(s), quotient(i)), 4n), Nat.add(lane(s), lane(i))), sum_blocks(s, i, limit, h, hu)) :
    {Nat.mod(_, 4n) == Nat.mod(Nat.add(lane(s), lane(i)), 4n) : Nat}
  mod4_blocks(Nat.add(quotient(s), quotient(i)), Nat.add(lane(s), lane(i)))

# Keep the ceiling abstract to avoid checker expansion: https://github.com/bendlang/bend/issues/1071.
def sum_word_of(+s: U32, +i: U32, +n: Nat, +limit: Nat,
  +h: MNat.lt(quotient((s + i : U32)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  +e: {quotient((s + i : U32)) == Nat.add(n, quotient(s)) : Nat}) ->
  {((s + i) >> 2n : U32) == Model.advance(n, (s >> 2n : U32)) : U32}:
  Model.advance_equal(((s + i) >> 2n : U32), (s >> 2n : U32), n, limit, e,
    (%e : MNat.lt(_, limit); h), hu)

def sum_word(+s: U32, +i: U32, +limit: Nat,
  +h: MNat.lt(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {((s + i) >> 2n : U32) ==
    Model.advance(Nat.add(quotient(i), Nat.div(Nat.add(lane(s), lane(i)), 4n)), (s >> 2n : U32)) : U32}:
  +carry = Nat.div(Nat.add(lane(s), lane(i)), 4n)
  +hs : MNat.lt(U32.to_nat((s + i : U32)), limit) = (
    %Equal.sym(Nat, U32.to_nat((s + i : U32)), Nat.add(U32.to_nat(s), U32.to_nat(i)),
      Lemmas.u32_add_nat(s, i, MNat.lt_of_lt_of_le(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit, Lemmas.pow2(32n), h, hu))) :
      MNat.lt(_, limit)
    h)
  sum_word_of(s, i, Nat.add(quotient(i), carry), limit,
    MNat.lt_of_le_of_lt(quotient((s + i : U32)), U32.to_nat((s + i : U32)), limit, Model.shr2_le((s + i : U32)), hs), hu,
    Equal.trans(Nat, quotient((s + i : U32)), Nat.add(Nat.add(quotient(s), quotient(i)), carry),
      Nat.add(Nat.add(quotient(i), carry), quotient(s)), sum_word_nat(s, i, limit, h, hu),
      Equal.trans(Nat, Nat.add(Nat.add(quotient(s), quotient(i)), carry), Nat.add(quotient(s), Nat.add(quotient(i), carry)),
        Nat.add(Nat.add(quotient(i), carry), quotient(s)), MNat.add_assoc(quotient(s), quotient(i), carry), MNat.add_comm(quotient(s), Nat.add(quotient(i), carry)))))

def shift_lane_of(+i: U32, facts: Model.Lane(i)) -> {Bytes.shift(i) == Nat.mul(lane(i), 8n) : Nat}:
  (e, h) = facts
  Equal.sym(Nat, Nat.mul(lane(i), 8n), Bytes.shift(i), e)

def shift_lane(+i: U32) -> {Bytes.shift(i) == Nat.mul(lane(i), 8n) : Nat}:
  shift_lane_of(i, Model.lane_facts(i))

def sum_shift(+s: U32, +i: U32, +limit: Nat,
  h: MNat.lt(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {Bytes.shift((s + i : U32)) == Nat.mul(Nat.mod(Nat.add(lane(s), lane(i)), 4n), 8n) : Nat}:
  Equal.trans(Nat, Bytes.shift((s + i : U32)), Nat.mul(lane((s + i : U32)), 8n),
    Nat.mul(Nat.mod(Nat.add(lane(s), lane(i)), 4n), 8n), shift_lane((s + i : U32)),
    Equal.cong(Nat, Nat, r => Nat.mul(r, 8n), lane((s + i : U32)), Nat.mod(Nat.add(lane(s), lane(i)), 4n), sum_lane_nat(s, i, limit, h, hu)))

def source_octet(+src: Tree.Tree<U32>, +s: U32, +i: U32, +limit: Nat,
  +h: MNat.lt(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {Model.peek(src, (s + i : U32)) ==
    octet(Tree.read(U32, src, Model.advance(Nat.add(quotient(i), Nat.div(Nat.add(lane(s), lane(i)), 4n)), (s >> 2n : U32))),
      Nat.mul(Nat.mod(Nat.add(lane(s), lane(i)), 4n), 8n)) : U32}:
  %Equal.sym(U32, ((s + i) >> 2n : U32),
    Model.advance(Nat.add(quotient(i), Nat.div(Nat.add(lane(s), lane(i)), 4n)), (s >> 2n : U32)), sum_word(s, i, limit, h, hu)) :
    {octet(Tree.read(U32, src, _), Bytes.shift((s + i : U32))) ==
      octet(Tree.read(U32, src, Model.advance(Nat.add(quotient(i), Nat.div(Nat.add(lane(s), lane(i)), 4n)), (s >> 2n : U32))),
        Nat.mul(Nat.mod(Nat.add(lane(s), lane(i)), 4n), 8n)) : U32}
  Equal.cong(Nat, U32, k => octet(Tree.read(U32, src,
    Model.advance(Nat.add(quotient(i), Nat.div(Nat.add(lane(s), lane(i)), 4n)), (s >> 2n : U32))), k),
    Bytes.shift((s + i : U32)), Nat.mul(Nat.mod(Nat.add(lane(s), lane(i)), 4n), 8n), sum_shift(s, i, limit, h, hu))

def two_bits(a: Bool, b: Bool) -> Nat:
  match a b:
    case False{} False{}:
      0n
    case True{} False{}:
      1n
    case False{} True{}:
      2n
    case True{} True{}:
      3n

def two_bits_value(+a: Bool, +b: Bool) ->
  {U32.to_nat(U32{WCon{a, WCon{b, Word.zero(30n)}}}) == two_bits(a, b) : Nat}:
  match a b:
    case False{} False{}:
      {==}
    case True{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} True{}:
      {==}

def lane_bits(+a: Bool, +b: Bool, +t: Word(30n)) ->
  {lane(U32{WCon{a, WCon{b, t}}}) == two_bits(a, b) : Nat}:
  Equal.trans(Nat, lane(U32{WCon{a, WCon{b, t}}}), U32.to_nat(U32{WCon{a, WCon{b, Word.zero(30n)}}}), two_bits(a, b),
    Equal.cong(U32, Nat, U32.to_nat, (U32{WCon{a, WCon{b, t}}} .&. 3 : U32), U32{WCon{a, WCon{b, Word.zero(30n)}}}, Model.low2(a, b, t)),
    two_bits_value(a, b))

def lane_octet(+a: U32, +b: U32, ra: Bool, rb: Bool, ia: Bool, ib: Bool) ->
  {octet(joined(a, b, Nat.mul(two_bits(ra, rb), 8n), Nat.mul(Nat.sub(4n, two_bits(ra, rb)), 8n)), Nat.mul(two_bits(ia, ib), 8n)) ==
    octet(Bool.pick(U32, Nat.is_lt(Nat.add(two_bits(ra, rb), two_bits(ia, ib)), 4n), a, b),
      Nat.mul(Nat.mod(Nat.add(two_bits(ra, rb), two_bits(ia, ib)), 4n), 8n)) : U32}:
  match ra rb ia ib:
    case False{} False{} False{} False{}:
      octet_low(a, b, 0n, 32n, 0n, {==})
    case False{} False{} True{} False{}:
      octet_low(a, b, 0n, 32n, 8n, {==})
    case False{} False{} False{} True{}:
      octet_low(a, b, 0n, 32n, 16n, {==})
    case False{} False{} True{} True{}:
      octet_low(a, b, 0n, 32n, 24n, {==})
    case True{} False{} False{} False{}:
      octet_low(a, b, 8n, 24n, 0n, {==})
    case True{} False{} True{} False{}:
      octet_low(a, b, 8n, 24n, 8n, {==})
    case True{} False{} False{} True{}:
      octet_low(a, b, 8n, 24n, 16n, {==})
    case True{} False{} True{} True{}:
      octet_high(a, b, 8n, 24n, 0n, {==}, {==})
    case False{} True{} False{} False{}:
      octet_low(a, b, 16n, 16n, 0n, {==})
    case False{} True{} True{} False{}:
      octet_low(a, b, 16n, 16n, 8n, {==})
    case False{} True{} False{} True{}:
      octet_high(a, b, 16n, 16n, 0n, {==}, {==})
    case False{} True{} True{} True{}:
      octet_high(a, b, 16n, 16n, 8n, {==}, {==})
    case True{} True{} False{} False{}:
      octet_low(a, b, 24n, 8n, 0n, {==})
    case True{} True{} True{} False{}:
      octet_high(a, b, 24n, 8n, 0n, {==}, {==})
    case True{} True{} False{} True{}:
      octet_high(a, b, 24n, 8n, 8n, {==}, {==})
    case True{} True{} True{} True{}:
      octet_high(a, b, 24n, 8n, 16n, {==}, {==})

def lanes_goal(+a: U32, +b: U32, +rs: Nat, +ri: Nat) -> Type:
  {octet(joined(a, b, Nat.mul(rs, 8n), Nat.mul(Nat.sub(4n, rs), 8n)), Nat.mul(ri, 8n)) ==
    octet(Bool.pick(U32, Nat.is_lt(Nat.add(rs, ri), 4n), a, b), Nat.mul(Nat.mod(Nat.add(rs, ri), 4n), 8n)) : U32}

def lanes_of(+a: U32, +b: U32, +rs: Nat, +ri: Nat, +ra: Bool, +rb: Bool, +ia: Bool, +ib: Bool,
  es: {rs == two_bits(ra, rb) : Nat}, ei: {ri == two_bits(ia, ib) : Nat}) -> lanes_goal(a, b, rs, ri):
  %Equal.sym(Nat, rs, two_bits(ra, rb), es) : lanes_goal(a, b, _, ri)
  %Equal.sym(Nat, ri, two_bits(ia, ib), ei) : lanes_goal(a, b, two_bits(ra, rb), _)
  lane_octet(a, b, ra, rb, ia, ib)

def lanes(+s: U32, +i: U32, +a: U32, +b: U32) -> lanes_goal(a, b, lane(s), lane(i)):
  match s i:
    case U32{WCon{+ra, WCon{+rb, +st}}} U32{WCon{+ia, WCon{+ib, +it}}}:
      lanes_of(a, b, lane(s), lane(i), ra, rb, ia, ib, lane_bits(ra, rb, st), lane_bits(ia, ib, it))

def carry_bits(ra: Bool, rb: Bool, ia: Bool, ib: Bool) ->
  {Nat.div(Nat.add(two_bits(ra, rb), two_bits(ia, ib)), 4n) ==
    Bool.pick(Nat, Nat.is_lt(Nat.add(two_bits(ra, rb), two_bits(ia, ib)), 4n), 0n, 1n) : Nat}:
  match ra rb ia ib:
    case False{} False{} False{} False{}: {==}
    case False{} False{} True{} False{}: {==}
    case False{} False{} False{} True{}: {==}
    case False{} False{} True{} True{}: {==}
    case True{} False{} False{} False{}: {==}
    case True{} False{} True{} False{}: {==}
    case True{} False{} False{} True{}: {==}
    case True{} False{} True{} True{}: {==}
    case False{} True{} False{} False{}: {==}
    case False{} True{} True{} False{}: {==}
    case False{} True{} False{} True{}: {==}
    case False{} True{} True{} True{}: {==}
    case True{} True{} False{} False{}: {==}
    case True{} True{} True{} False{}: {==}
    case True{} True{} False{} True{}: {==}
    case True{} True{} True{} True{}: {==}

def carry_goal(+rs: Nat, +ri: Nat) -> Type:
  {Nat.div(Nat.add(rs, ri), 4n) == Bool.pick(Nat, Nat.is_lt(Nat.add(rs, ri), 4n), 0n, 1n) : Nat}

def carry_of(+rs: Nat, +ri: Nat, +ra: Bool, +rb: Bool, +ia: Bool, +ib: Bool,
  es: {rs == two_bits(ra, rb) : Nat}, ei: {ri == two_bits(ia, ib) : Nat}) -> carry_goal(rs, ri):
  %Equal.sym(Nat, rs, two_bits(ra, rb), es) : carry_goal(_, ri)
  %Equal.sym(Nat, ri, two_bits(ia, ib), ei) : carry_goal(two_bits(ra, rb), _)
  carry_bits(ra, rb, ia, ib)

def carry(+s: U32, +i: U32) -> carry_goal(lane(s), lane(i)):
  match s i:
    case U32{WCon{+ra, WCon{+rb, +st}}} U32{WCon{+ia, WCon{+ib, +it}}}:
      carry_of(lane(s), lane(i), ra, rb, ia, ib, lane_bits(ra, rb, st), lane_bits(ia, ib, it))

def carry_word(flag: Bool, +src: Tree.Tree<U32>, +q: Nat, +s: U32) ->
  {Bool.pick(U32, flag, Tree.read(U32, src, Model.advance(q, s)), Tree.read(U32, src, Model.advance(1n+q, s))) ==
    Tree.read(U32, src, Model.advance(Nat.add(q, Bool.pick(Nat, flag, 0n, 1n)), s)) : U32}:
  match flag:
    case True{}:
      Equal.cong(Nat, U32, n => Tree.read(U32, src, Model.advance(n, s)), q, Nat.add(q, 0n),
        Equal.sym(Nat, Nat.add(q, 0n), q, MNat.add_zero(q)))
    case False{}:
      Equal.cong(Nat, U32, n => Tree.read(U32, src, Model.advance(n, s)), 1n+q, Nat.add(q, 1n),
        Equal.sym(Nat, Nat.add(q, 1n), 1n+q, MNat.add_comm(q, 1n)))

def lane_read(+src: Tree.Tree<U32>, +s: U32, +i: U32) ->
  {octet(joined(Tree.read(U32, src, Model.advance(quotient(i), (s >> 2n : U32))),
    Tree.read(U32, src, Model.advance(1n+quotient(i), (s >> 2n : U32))), Nat.mul(lane(s), 8n), Nat.mul(Nat.sub(4n, lane(s)), 8n)), Nat.mul(lane(i), 8n)) ==
    octet(Tree.read(U32, src, Model.advance(Nat.add(quotient(i), Nat.div(Nat.add(lane(s), lane(i)), 4n)), (s >> 2n : U32))),
      Nat.mul(Nat.mod(Nat.add(lane(s), lane(i)), 4n), 8n)) : U32}:
  +a = Tree.read(U32, src, Model.advance(quotient(i), (s >> 2n : U32)))
  +b = Tree.read(U32, src, Model.advance(1n+quotient(i), (s >> 2n : U32)))
  +flag = Nat.is_lt(Nat.add(lane(s), lane(i)), 4n)
  +sh = Nat.mul(Nat.mod(Nat.add(lane(s), lane(i)), 4n), 8n)
  %Equal.sym(U32, octet(joined(a, b, Nat.mul(lane(s), 8n), Nat.mul(Nat.sub(4n, lane(s)), 8n)), Nat.mul(lane(i), 8n)),
    octet(Bool.pick(U32, flag, a, b), sh), lanes(s, i, a, b)) :
    {_ == octet(Tree.read(U32, src, Model.advance(Nat.add(quotient(i), Nat.div(Nat.add(lane(s), lane(i)), 4n)), (s >> 2n : U32))), sh) : U32}
  %Equal.sym(Nat, Nat.div(Nat.add(lane(s), lane(i)), 4n), Bool.pick(Nat, flag, 0n, 1n), carry(s, i)) :
    {octet(Bool.pick(U32, flag, a, b), sh) ==
      octet(Tree.read(U32, src, Model.advance(Nat.add(quotient(i), _), (s >> 2n : U32))), sh) : U32}
  Equal.cong(U32, U32, w => octet(w, sh), Bool.pick(U32, flag, a, b),
    Tree.read(U32, src, Model.advance(Nat.add(quotient(i), Bool.pick(Nat, flag, 0n, 1n)), (s >> 2n : U32))),
    carry_word(flag, src, quotient(i), (s >> 2n : U32)))

def complement_goal(+r: U32) -> Type:
  {U32.to_nat((32 - (r * 8) : U32)) == Nat.mul(Nat.sub(4n, U32.to_nat(r)), 8n) : Nat}

def complement_normal(a: Bool, b: Bool) -> complement_goal(U32{WCon{a, WCon{b, Word.zero(30n)}}}):
  match a b:
    case False{} False{}: {==}
    case True{} False{}: {==}
    case False{} True{}: {==}
    case True{} True{}: {==}

def complement_bits(+a: Bool, +b: Bool, +t: Word(30n)) ->
  complement_goal((U32{WCon{a, WCon{b, t}}} .&. 3 : U32)):
  %Equal.sym(U32, (U32{WCon{a, WCon{b, t}}} .&. 3 : U32), U32{WCon{a, WCon{b, Word.zero(30n)}}}, Model.low2(a, b, t)) :
    complement_goal(_)
  complement_normal(a, b)

def complement(+s: U32) -> complement_goal((s .&. 3 : U32)):
  match s:
    case U32{WCon{+a, WCon{+b, +t}}}:
      complement_bits(a, b, t)

def window_parameters(+a: U32, +b: U32, +s: U32, +i: U32) ->
  {octet(joined(a, b, Bytes.shift(s), U32.to_nat((32 - ((s .&. 3) * 8) : U32))), Bytes.shift(i)) ==
    octet(joined(a, b, Nat.mul(lane(s), 8n), Nat.mul(Nat.sub(4n, lane(s)), 8n)), Nat.mul(lane(i), 8n)) : U32}:
  %Equal.sym(Nat, Bytes.shift(s), Nat.mul(lane(s), 8n), shift_lane(s)) :
    {octet(joined(a, b, _, U32.to_nat((32 - ((s .&. 3) * 8) : U32))), Bytes.shift(i)) ==
      octet(joined(a, b, Nat.mul(lane(s), 8n), Nat.mul(Nat.sub(4n, lane(s)), 8n)), Nat.mul(lane(i), 8n)) : U32}
  %Equal.sym(Nat, U32.to_nat((32 - ((s .&. 3) * 8) : U32)), Nat.mul(Nat.sub(4n, lane(s)), 8n), complement(s)) :
    {octet(joined(a, b, Nat.mul(lane(s), 8n), _), Bytes.shift(i)) ==
      octet(joined(a, b, Nat.mul(lane(s), 8n), Nat.mul(Nat.sub(4n, lane(s)), 8n)), Nat.mul(lane(i), 8n)) : U32}
  Equal.cong(Nat, U32, k => octet(joined(a, b, Nat.mul(lane(s), 8n), Nat.mul(Nat.sub(4n, lane(s)), 8n)), k),
    Bytes.shift(i), Nat.mul(lane(i), 8n), shift_lane(i))

def input_window(+src: Tree.Tree<U32>, +s: U32, +i: U32) -> U32:
  octet(joined(Tree.read(U32, src, Model.advance(quotient(i), (s >> 2n : U32))),
    Tree.read(U32, src, Model.advance(1n+quotient(i), (s >> 2n : U32))),
    Bytes.shift(s), U32.to_nat((32 - ((s .&. 3) * 8) : U32))), Bytes.shift(i))

def input_window_value(+src: Tree.Tree<U32>, +s: U32, +i: U32, +limit: Nat,
  h: MNat.lt(Nat.add(U32.to_nat(s), U32.to_nat(i)), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {input_window(src, s, i) == Model.peek(src, (s + i : U32)) : U32}:
  +a = Tree.read(U32, src, Model.advance(quotient(i), (s >> 2n : U32)))
  +b = Tree.read(U32, src, Model.advance(1n+quotient(i), (s >> 2n : U32)))
  +out = octet(Tree.read(U32, src, Model.advance(Nat.add(quotient(i), Nat.div(Nat.add(lane(s), lane(i)), 4n)), (s >> 2n : U32))),
    Nat.mul(Nat.mod(Nat.add(lane(s), lane(i)), 4n), 8n))
  Equal.trans(U32, input_window(src, s, i),
    octet(joined(a, b, Nat.mul(lane(s), 8n), Nat.mul(Nat.sub(4n, lane(s)), 8n)), Nat.mul(lane(i), 8n)), Model.peek(src, (s + i : U32)),
    window_parameters(a, b, s, i),
    Equal.trans(U32, octet(joined(a, b, Nat.mul(lane(s), 8n), Nat.mul(Nat.sub(4n, lane(s)), 8n)), Nat.mul(lane(i), 8n)),
      out, Model.peek(src, (s + i : U32)), lane_read(src, s, i),
      Equal.sym(U32, Model.peek(src, (s + i : U32)), out, source_octet(src, s, i, limit, h, hu))))

def wshl_large(+d: Nat, +k: Nat, +w: Word(d), h: MNat.le(d, k)) ->
  {Field.wshl(k, d, w) == Word.zero(d) : Word(d)}:
  match d:
    case 0n:
      match k:
        case 0n:
          match w:
            case WNil{}: {==}
        case 1n+p:
          {==}
    case 1n+ +p:
      match k:
        case 0n:
          Empty.absurd({Field.wshl(0n, 1n+p, w) == Word.zero(1n+p) : Word(1n+p)},
            MNat.succ_ne_zero(p)(MNat.le_zero_eq(1n+p, h)))
        case 1n+ +q:
          %Equal.sym(Word(1n+p), Field.wshl(1n+q, 1n+p, w),
            WCon{False{}, Field.wshl(q, p, Field.init(p, w))}, Field.wshl_con(q, p, w)) :
            {_ == Word.zero(1n+p) : Word(1n+p)}
          Equal.cong(Word(p), Word(1n+p), t => WCon{False{}, t}, Field.wshl(q, p, Field.init(p, w)), Word.zero(p),
            wshl_large(p, q, Field.init(p, w), h))

def or_zero(+a: U32) -> {(a .|. 0 : U32) == a : U32}:
  match a:
    case U32{+w}:
      Equal.cong(Word(32n), U32, t => U32{t}, Word.or(32n, w, Word.zero(32n)), w, Field.word_or_zero(32n, w))

def joined_aligned(+a: U32, +b: U32) -> {joined(a, b, 0n, 32n) == a : U32}:
  %Equal.sym(U32, U32.shln(b, 32n), U32{Field.wshl(32n, 32n, Field.word(b))}, Field.shln_word(32n, b)) :
    {(a .|. _ : U32) == a : U32}
  %Equal.sym(Word(32n), Field.wshl(32n, 32n, Field.word(b)), Word.zero(32n),
    wshl_large(32n, 32n, Field.word(b), MNat.le_refl(32n))) :
    {(a .|. U32{_} : U32) == a : U32}
  or_zero(a)

def min_pick(+a: U32, +b: U32) -> {U32.min(a, b) == Bool.pick(U32, U32.is_lt(a, b), a, b) : U32}:
  match a b:
    case U32{x} U32{y}: {==}

def min_bounds_pick(flag: Bool, +a: U32, +b: U32, h: {Nat.is_lt(U32.to_nat(a), U32.to_nat(b)) == flag : Bool}) ->
  MNat.le(U32.to_nat(Bool.pick(U32, flag, a, b)), U32.to_nat(a)) & MNat.le(U32.to_nat(Bool.pick(U32, flag, a, b)), U32.to_nat(b)):
  match flag:
    case True{}:
      (MNat.le_refl(U32.to_nat(a)), MNat.le_of_lt(U32.to_nat(a), U32.to_nat(b), h))
    case False{}:
      (MNat.le_of_not_lt(U32.to_nat(a), U32.to_nat(b), h), MNat.le_refl(U32.to_nat(b)))

def min_bounds(+a: U32, +b: U32) ->
  MNat.le(U32.to_nat(U32.min(a, b)), U32.to_nat(a)) & MNat.le(U32.to_nat(U32.min(a, b)), U32.to_nat(b)):
  %Equal.sym(U32, U32.min(a, b), Bool.pick(U32, U32.is_lt(a, b), a, b), min_pick(a, b)) :
    MNat.le(U32.to_nat(_), U32.to_nat(a)) & MNat.le(U32.to_nat(_), U32.to_nat(b))
  min_bounds_pick(U32.is_lt(a, b), a, b,
    Equal.sym(Bool, U32.is_lt(a, b), Nat.is_lt(U32.to_nat(a), U32.to_nat(b)), Lemmas.u32_is_lt_nat(a, b)))

def slice_bounds_of(+len: U32, +s: U32, +m: U32, +hs: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  hm: MNat.le(U32.to_nat(m), U32.to_nat((len - s : U32)))) ->
  MNat.le(U32.to_nat(m), U32.to_nat(len)) & MNat.le(Nat.add(U32.to_nat(m), U32.to_nat(s)), U32.to_nat(len)):
  +bound : MNat.le(Nat.add(U32.to_nat(m), U32.to_nat(s)), U32.to_nat(len)) = (
    %MNat.sub_add_cancel(U32.to_nat(len), U32.to_nat(s), hs) : MNat.le(Nat.add(U32.to_nat(m), U32.to_nat(s)), _)
    MNat.add_le_add_right(U32.to_nat(m), Nat.sub(U32.to_nat(len), U32.to_nat(s)), U32.to_nat(s),
      (%Lemmas.u32_sub_nat(len, s, hs) : MNat.le(U32.to_nat(m), _); hm)))
  (MNat.le_trans(U32.to_nat(m), Nat.add(U32.to_nat(m), U32.to_nat(s)), U32.to_nat(len), MNat.le_add_right(U32.to_nat(m), U32.to_nat(s)), bound), bound)

def slice_bounds_min(+len: U32, +start: U32, +n: U32,
  sb: MNat.le(U32.to_nat(U32.min(start, len)), U32.to_nat(start)) & MNat.le(U32.to_nat(U32.min(start, len)), U32.to_nat(len)),
  mb: MNat.le(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(n)) &
    MNat.le(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat((len - U32.min(start, len) : U32)))) ->
  MNat.le(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(len)) &
    MNat.le(Nat.add(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(U32.min(start, len))), U32.to_nat(len)):
  (sa, sl) = sb
  (mn, mr) = mb
  slice_bounds_of(len, U32.min(start, len), U32.min(n, (len - U32.min(start, len) : U32)), sl, mr)

def slice_bounds(+len: U32, +start: U32, +n: U32) ->
  MNat.le(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(len)) &
    MNat.le(Nat.add(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(U32.min(start, len))), U32.to_nat(len)):
  slice_bounds_min(len, start, n, min_bounds(start, len), min_bounds(n, (len - U32.min(start, len) : U32)))
