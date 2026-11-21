import Base
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/u32.bend as MU32
import ./field-proof.bend as Field

def rounded(+p: Nat) -> Nat:
  Nat.mul(Nat.div(Nat.add(p, 7n), 8n), 8n)

def rounded_step(+p: Nat) -> {rounded(8n+p) == 8n+rounded(p) : Nat}:
  Equal.cong(Nat, Nat, q => Nat.mul(q, 8n), Nat.div(8n+Nat.add(p, 7n), 8n),
    1n+Nat.div(Nat.add(p, 7n), 8n), MNat.add_div_left(Nat.add(p, 7n), 7n))

def rounded_bounds_step(+p: Nat, h: MNat.le(p, rounded(p)) & MNat.le(rounded(p), Nat.add(p, 7n))) ->
  MNat.le(8n+p, rounded(8n+p)) & MNat.le(rounded(8n+p), Nat.add(8n+p, 7n)):
  (lower, upper) = h
  ((%Equal.sym(Nat, rounded(8n+p), 8n+rounded(p), rounded_step(p)) : MNat.le(8n+p, _)
    MNat.add_le_add_left(p, rounded(p), 8n, lower)),
   (%Equal.sym(Nat, rounded(8n+p), 8n+rounded(p), rounded_step(p)) : MNat.le(_, 8n+Nat.add(p, 7n))
    MNat.add_le_add_left(rounded(p), Nat.add(p, 7n), 8n, upper)))

def rounded_bounds(+p: Nat) -> MNat.le(p, rounded(p)) & MNat.le(rounded(p), Nat.add(p, 7n)):
  match p:
    case 0n:
      ({==}, {==})
    case 1n:
      ({==}, {==})
    case 2n:
      ({==}, {==})
    case 3n:
      ({==}, {==})
    case 4n:
      ({==}, {==})
    case 5n:
      ({==}, {==})
    case 6n:
      ({==}, {==})
    case 7n:
      ({==}, {==})
    case 8n+ +q:
      rounded_bounds_step(q, rounded_bounds(q))

def rounded_lower.of(-p: Nat, h: MNat.le(p, rounded(p)) & MNat.le(rounded(p), Nat.add(p, 7n))) -> MNat.le(p, rounded(p)):
  (lower, upper) = h
  lower

def rounded_lower(+p: Nat) -> MNat.le(p, rounded(p)):
  rounded_lower.of(p, rounded_bounds(p))

def rounded_upper.of(-p: Nat, h: MNat.le(p, rounded(p)) & MNat.le(rounded(p), Nat.add(p, 7n))) -> MNat.le(rounded(p), Nat.add(p, 7n)):
  (lower, upper) = h
  upper

def rounded_upper(+p: Nat) -> MNat.le(rounded(p), Nat.add(p, 7n)):
  rounded_upper.of(p, rounded_bounds(p))

def rounded_contains(+p: Nat, +n: Nat) -> MNat.le(p, rounded(Nat.add(p, n))):
  MNat.le_trans(p, Nat.add(p, n), rounded(Nat.add(p, n)), MNat.le_add_right(p, n), rounded_lower(Nat.add(p, n)))

def rounded_remaining(+p: Nat, +n: Nat) -> MNat.le(n, Nat.sub(rounded(Nat.add(p, n)), p)):
  %MNat.add_sub_cancel_left(p, n) : MNat.le(_, Nat.sub(rounded(Nat.add(p, n)), p))
  MNat.sub_le_sub_right(Nat.add(p, n), rounded(Nat.add(p, n)), rounded_lower(Nat.add(p, n)), p)

def finish_bytes(+p: U32) -> U32:
  ((p + 7) >> 3n : U32)

def finish_bits(+p: U32) -> U32:
  (finish_bytes(p) << 3n : U32)

def finish_bytes_shift(+p: U32) ->
  {U32.to_nat(finish_bytes(p)) == Nat.div(U32.to_nat((p + 7 : U32)), 8n) : Nat}:
  Field.shrn_nat((p + 7 : U32), 3n)

# Separate Word arithmetic from U32 refinement: https://github.com/bendlang/bend/issues/1071.
def add_word_nat(+a: U32, +b: U32) ->
  {Word.to_nat(32n, Word.add(32n, Field.word(a), Field.word(b))) == U32.to_nat(U32.add(a, b)) : Nat}:
  match a b:
    case U32{x} U32{y}:
      {==}

def word_sum_nat(+d: Nat, +a: Word(d), +b: Word(d), +an: Nat, +bn: Nat,
  +ea: {Word.to_nat(d, a) == an : Nat}, +eb: {Word.to_nat(d, b) == bn : Nat},
  h: MNat.lt(Nat.add(an, bn), Lemmas.pow2(d))) ->
  {Word.to_nat(d, Word.add(d, a, b)) == Nat.add(an, bn) : Nat}:
  %ea : {Word.to_nat(d, Word.add(d, a, b)) == Nat.add(_, bn) : Nat}
  %eb : {Word.to_nat(d, Word.add(d, a, b)) == Nat.add(Word.to_nat(d, a), _) : Nat}
  Lemmas.word_add_nat(d, a, b,
    (%Equal.sym(Nat, Word.to_nat(d, a), an, ea) : MNat.lt(Nat.add(_, Word.to_nat(d, b)), Lemmas.pow2(d))
     %Equal.sym(Nat, Word.to_nat(d, b), bn, eb) : MNat.lt(Nat.add(an, _), Lemmas.pow2(d))
     h))

def add_seven_nat(+p: U32, h: MNat.lt(Nat.add(U32.to_nat(p), 7n), Lemmas.pow2(32n))) ->
  {U32.to_nat((p + 7 : U32)) == Nat.add(U32.to_nat(p), 7n) : Nat}:
  %add_word_nat(p, 7) : {_ == Nat.add(U32.to_nat(p), 7n) : Nat}
  word_sum_nat(32n, Field.word(p), Field.word(7), U32.to_nat(p), 7n, Field.word_nat(p), {==}, h)

def finish_bytes_nat(+p: U32, h: MNat.lt(Nat.add(U32.to_nat(p), 7n), Lemmas.pow2(32n))) ->
  {U32.to_nat(finish_bytes(p)) == Nat.div(Nat.add(U32.to_nat(p), 7n), 8n) : Nat}:
  %add_seven_nat(p, h) : {U32.to_nat(finish_bytes(p)) == Nat.div(_, 8n) : Nat}
  finish_bytes_shift(p)

def quotient_product(-bytes: Nat, +p: Nat,
  e: {bytes == Nat.div(Nat.add(p, 7n), 8n) : Nat}) ->
  {Nat.mul(bytes, 8n) == rounded(p) : Nat}:
  Equal.cong(Nat, Nat, a => Nat.mul(a, 8n), bytes, Nat.div(Nat.add(p, 7n), 8n), e)

def finish_product(+p: U32, h: MNat.lt(Nat.add(U32.to_nat(p), 7n), Lemmas.pow2(32n))) ->
  {Nat.mul(U32.to_nat(finish_bytes(p)), 8n) == rounded(U32.to_nat(p)) : Nat}:
  quotient_product(U32.to_nat(finish_bytes(p)), U32.to_nat(p), finish_bytes_nat(p, h))

# Transport only Nat terms across the concrete shifts: https://github.com/bendlang/bend/issues/1071.
def rounded_product_bound(+p: Nat, +bytes: Nat, +bound: Nat,
  e: {Nat.mul(bytes, 8n) == rounded(p) : Nat},
  h: MNat.lt(Nat.add(p, 7n), bound)) -> MNat.lt(Nat.mul(bytes, 8n), bound):
  Lemmas.lt_rw(Nat.mul(bytes, 8n), rounded(p), bound, e,
    MNat.lt_of_le_of_lt(rounded(p), Nat.add(p, 7n), bound, rounded_upper(p), h))

# Prove bounded shifts before specializing the word width: https://github.com/bendlang/bend/issues/1071.
def word_scale_nat(+k: Nat, +d: Nat, +w: Word(d), +value: Nat,
  +e: {Word.to_nat(d, w) == value : Nat},
  h: MNat.lt(Nat.mul(value, Lemmas.pow2(k)), Lemmas.pow2(d))) ->
  {Word.to_nat(d, Field.wshl(k, d, w)) == Nat.mul(value, Lemmas.pow2(k)) : Nat}:
  %e : {Word.to_nat(d, Field.wshl(k, d, w)) == Nat.mul(_, Lemmas.pow2(k)) : Nat}
  Equal.trans(Nat, Word.to_nat(d, Field.wshl(k, d, w)),
    Nat.mod(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(k)), Lemmas.pow2(d)),
    Nat.mul(Word.to_nat(d, w), Lemmas.pow2(k)), Field.word_shln_mod(k, d, w),
    MNat.mod_eq_of_lt(Nat.mul(Word.to_nat(d, w), Lemmas.pow2(k)), Lemmas.pow2(d),
      (%Equal.sym(Nat, Word.to_nat(d, w), value, e) :
        MNat.lt(Nat.mul(_, Lemmas.pow2(k)), Lemmas.pow2(d))
       h)))

def finish_bits_bound(+p: U32, +h: MNat.lt(Nat.add(U32.to_nat(p), 7n), Lemmas.pow2(32n))) ->
  MNat.lt(Nat.mul(U32.to_nat(finish_bytes(p)), 8n), Lemmas.pow2(32n)):
  rounded_product_bound(U32.to_nat(p), U32.to_nat(finish_bytes(p)), Lemmas.pow2(32n),
    finish_product(p, h), h)

def word_scale_three_nat(+d: Nat, +w: Word(d), +value: Nat,
  e: {Word.to_nat(d, w) == value : Nat},
  h: MNat.lt(Nat.mul(value, 8n), Lemmas.pow2(d))) ->
  {Word.to_nat(d, Field.wshl(3n, d, w)) == Nat.mul(value, 8n) : Nat}:
  word_scale_nat(3n, d, w, value, e, h)

def scale_three_nat(+v: U32, h: MNat.lt(Nat.mul(U32.to_nat(v), 8n), Lemmas.pow2(32n))) ->
  {U32.to_nat(U32.shln(v, 3n)) == Nat.mul(U32.to_nat(v), 8n) : Nat}:
  %Field.shln_word_nat(3n, v) : {_ == Nat.mul(U32.to_nat(v), 8n) : Nat}
  word_scale_three_nat(32n, Field.word(v), U32.to_nat(v), Field.word_nat(v), h)

def finish_bits_shift(+p: U32, h: MNat.lt(Nat.mul(U32.to_nat(finish_bytes(p)), 8n), Lemmas.pow2(32n))) ->
  {U32.to_nat(finish_bits(p)) == Nat.mul(U32.to_nat(finish_bytes(p)), 8n) : Nat}:
  scale_three_nat(finish_bytes(p), h)

def finish_bits_nat(+p: U32, +h: MNat.lt(Nat.add(U32.to_nat(p), 7n), Lemmas.pow2(32n))) ->
  {U32.to_nat(finish_bits(p)) == rounded(U32.to_nat(p)) : Nat}:
  %finish_product(p, h) : {U32.to_nat(finish_bits(p)) == _ : Nat}
  finish_bits_shift(p, finish_bits_bound(p, h))

def read_min(+n: U32, +left: U32,
  hn: MNat.le(U32.to_nat(n), 32n), hl: MNat.le(U32.to_nat(n), U32.to_nat(left))) ->
  {U32.is_le(n, U32.min(32, left)) == True{} : Bool}:
  %Equal.sym(Bool, U32.is_le(n, U32.min(32, left)), Nat.is_le(U32.to_nat(n), U32.to_nat(U32.min(32, left))),
    Lemmas.u32_is_le_nat(n, U32.min(32, left))) : {_ == True{} : Bool}
  %Equal.sym(Nat, U32.to_nat(U32.min(32, left)), Nat.min(32n, U32.to_nat(left)),
    MU32.u32_min_to_nat(32, left)) : MNat.le(U32.to_nat(n), _)
  MNat.le_min_of_le_of_le(U32.to_nat(n), 32n, U32.to_nat(left), hn, hl)

def le_left_rw(-a: Nat, -b: Nat, -c: Nat, e: {a == b : Nat}, h: MNat.le(b, c)) -> MNat.le(a, c):
  %Equal.sym(Nat, a, b, e) : MNat.le(_, c)
  h

def le_right_rw(-a: Nat, -b: Nat, -c: Nat, e: {b == c : Nat}, h: MNat.le(a, c)) -> MNat.le(a, b):
  %Equal.sym(Nat, b, c, e) : MNat.le(a, _)
  h

def finish_room(+p: U32, +n: U32, +end: U32,
  e: {U32.to_nat(end) == Nat.add(U32.to_nat(p), U32.to_nat(n)) : Nat},
  h: MNat.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), Lemmas.pow2(32n))) ->
  MNat.lt(Nat.add(U32.to_nat(end), 7n), Lemmas.pow2(32n)):
  Lemmas.lt_rw(Nat.add(U32.to_nat(end), 7n), Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 7n),
    Lemmas.pow2(32n), Equal.cong(Nat, Nat, a => Nat.add(a, 7n), U32.to_nat(end),
      Nat.add(U32.to_nat(p), U32.to_nat(n)), e),
    MNat.lt_of_le_of_lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 7n),
      Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), Lemmas.pow2(32n),
      MNat.add_le_add_left(7n, 31n, Nat.add(U32.to_nat(p), U32.to_nat(n)), {==}), h))

# Compose reader bounds over opaque naturals: https://github.com/bendlang/bend/issues/1071.
def rounded_skip_nat(+p: Nat, +n: Nat, +end: Nat, -finished: Nat,
  e: {end == Nat.add(p, n) : Nat},
  ef: {finished == rounded(end) : Nat}) -> MNat.le(p, finished):
  le_right_rw(p, finished, rounded(end), ef,
    le_right_rw(p, rounded(end), rounded(Nat.add(p, n)),
      Equal.cong(Nat, Nat, x => rounded(x), end, Nat.add(p, n), e), rounded_contains(p, n)))

def finished_skip_nat(+p: U32, +n: U32, +end: U32,
  +e: {U32.to_nat(end) == Nat.add(U32.to_nat(p), U32.to_nat(n)) : Nat},
  h: MNat.lt(Nat.add(U32.to_nat(end), 7n), Lemmas.pow2(32n))) ->
  MNat.le(U32.to_nat(p), U32.to_nat(finish_bits(end))):
  rounded_skip_nat(U32.to_nat(p), U32.to_nat(n), U32.to_nat(end), U32.to_nat(finish_bits(end)),
    e, finish_bits_nat(end, h))

def finished_remaining_nat(+p: U32, +n: U32, +end: U32,
  e: {U32.to_nat(end) == Nat.add(U32.to_nat(p), U32.to_nat(n)) : Nat},
  +h: MNat.lt(Nat.add(U32.to_nat(end), 7n), Lemmas.pow2(32n)),
  sk: MNat.le(U32.to_nat(p), U32.to_nat(finish_bits(end)))) ->
  {U32.to_nat((finish_bits(end) - p : U32)) == Nat.sub(rounded(Nat.add(U32.to_nat(p), U32.to_nat(n))), U32.to_nat(p)) : Nat}:
  Equal.trans(Nat, U32.to_nat((finish_bits(end) - p : U32)),
    Nat.sub(U32.to_nat(finish_bits(end)), U32.to_nat(p)),
    Nat.sub(rounded(Nat.add(U32.to_nat(p), U32.to_nat(n))), U32.to_nat(p)),
    Lemmas.u32_sub_nat(finish_bits(end), p, sk),
    Equal.cong(Nat, Nat, a => Nat.sub(a, U32.to_nat(p)), U32.to_nat(finish_bits(end)),
      rounded(Nat.add(U32.to_nat(p), U32.to_nat(n))),
      Equal.trans(Nat, U32.to_nat(finish_bits(end)), rounded(U32.to_nat(end)),
        rounded(Nat.add(U32.to_nat(p), U32.to_nat(n))), finish_bits_nat(end, h),
        Equal.cong(Nat, Nat, x => rounded(x), U32.to_nat(end), Nat.add(U32.to_nat(p), U32.to_nat(n)), e))))

def finish_guards(+p: U32, +n: U32, +end: U32,
  +e: {U32.to_nat(end) == Nat.add(U32.to_nat(p), U32.to_nat(n)) : Nat},
  h: MNat.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), Lemmas.pow2(32n)),
  width: MNat.le(U32.to_nat(n), 32n)) ->
  {U32.is_le(p, finish_bits(end)) == True{} : Bool} &
  {U32.is_le(n, U32.min(32, (finish_bits(end) - p : U32))) == True{} : Bool}:
  +hf = finish_room(p, n, end, e, h)
  +sk = finished_skip_nat(p, n, end, e, hf)
  (Equal.trans(Bool, U32.is_le(p, finish_bits(end)), Nat.is_le(U32.to_nat(p), U32.to_nat(finish_bits(end))), True{},
    Lemmas.u32_is_le_nat(p, finish_bits(end)), sk),
   read_min(n, (finish_bits(end) - p : U32), width,
     le_right_rw(U32.to_nat(n), U32.to_nat((finish_bits(end) - p : U32)),
       Nat.sub(rounded(Nat.add(U32.to_nat(p), U32.to_nat(n))), U32.to_nat(p)),
       finished_remaining_nat(p, n, end, e, hf, sk), rounded_remaining(U32.to_nat(p), U32.to_nat(n)))))
