import Base
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./bits.bend as Bits
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

def finish_bytes(+p: Nat) -> U32:
  Bits.pos.bytes(p)

def finish_bits(+p: Nat) -> Nat:
  Nat.mul(U32.to_nat(finish_bytes(p)), 8n)

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

def power_div_bound.of(+p: Nat, +d: Nat, +k: Nat,
  h: MNat.lt(p, Lemmas.pow2(Nat.add(d, k)))) ->
  MNat.lt(Nat.div(p, Lemmas.pow2(k)), Lemmas.pow2(d)):
  MNat.lt_of_mul_lt_mul_right(Nat.div(p, Lemmas.pow2(k)), Lemmas.pow2(d), Lemmas.pow2(k),
    (%Field.pow2_add(d, k) :
      MNat.lt(Nat.mul(Nat.div(p, Lemmas.pow2(k)), Lemmas.pow2(k)), _)
     MNat.lt_of_le_of_lt(Nat.mul(Nat.div(p, Lemmas.pow2(k)), Lemmas.pow2(k)),
       p, Lemmas.pow2(Nat.add(d, k)), MNat.div_mul_le_self(p, Lemmas.pow2(k)), h)))

# Transport before specializing powers: concrete normalization expands large naturals.
def power_div_bound(+p: Nat, +d: Nat, +k: Nat, +total: Nat, +unit: Nat,
  et: {total == Nat.add(d, k) : Nat}, eu: {unit == Lemmas.pow2(k) : Nat},
  h: MNat.lt(p, Lemmas.pow2(total))) ->
  MNat.lt(Nat.div(p, unit), Lemmas.pow2(d)):
  %Equal.sym(Nat, unit, Lemmas.pow2(k), eu) : MNat.lt(Nat.div(p, _), Lemmas.pow2(d))
  power_div_bound.of(p, d, k,
    (%Equal.cong(Nat, Nat, a => Lemmas.pow2(a), total, Nat.add(d, k), et) : MNat.lt(p, _)
     h))

def finish_bytes_nat(+p: Nat, h: MNat.lt(Nat.add(p, 7n), Lemmas.pow2(35n))) ->
  {U32.to_nat(finish_bytes(p)) == Nat.div(Nat.add(p, 7n), 8n) : Nat}:
  Lemmas.u32_to_from_nat(Nat.div(Nat.add(p, 7n), 8n),
    power_div_bound(Nat.add(p, 7n), 32n, 3n, 35n, 8n, {==}, {==}, h))

def quotient_product(-bytes: Nat, +p: Nat,
  e: {bytes == Nat.div(Nat.add(p, 7n), 8n) : Nat}) ->
  {Nat.mul(bytes, 8n) == rounded(p) : Nat}:
  Equal.cong(Nat, Nat, a => Nat.mul(a, 8n), bytes, Nat.div(Nat.add(p, 7n), 8n), e)

def finish_product(+p: Nat, h: MNat.lt(Nat.add(p, 7n), Lemmas.pow2(35n))) ->
  {Nat.mul(U32.to_nat(finish_bytes(p)), 8n) == rounded(p) : Nat}:
  quotient_product(U32.to_nat(finish_bytes(p)), p, finish_bytes_nat(p, h))


def finish_bits_nat(+p: Nat, h: MNat.lt(Nat.add(p, 7n), Lemmas.pow2(35n))) ->
  {finish_bits(p) == rounded(p) : Nat}:
  finish_product(p, h)

def read_min(+n: U32, +left: Nat,
  hn: MNat.le(U32.to_nat(n), 32n), hl: MNat.le(U32.to_nat(n), left)) ->
  {Nat.is_le(U32.to_nat(n), Nat.min(32n, left)) == True{} : Bool}:
  MNat.le_min_of_le_of_le(U32.to_nat(n), 32n, left, hn, hl)

def le_left_rw(-a: Nat, -b: Nat, -c: Nat, e: {a == b : Nat}, h: MNat.le(b, c)) -> MNat.le(a, c):
  %Equal.sym(Nat, a, b, e) : MNat.le(_, c)
  h

def le_right_rw(-a: Nat, -b: Nat, -c: Nat, e: {b == c : Nat}, h: MNat.le(a, c)) -> MNat.le(a, b):
  %Equal.sym(Nat, b, c, e) : MNat.le(a, _)
  h

def finish_room(+p: Nat, +n: U32, +end: Nat,
  e: {end == Nat.add(p, U32.to_nat(n)) : Nat},
  h: MNat.lt(Nat.add(Nat.add(p, U32.to_nat(n)), 31n), Lemmas.pow2(35n))) ->
  MNat.lt(Nat.add(end, 7n), Lemmas.pow2(35n)):
  Lemmas.lt_rw(Nat.add(end, 7n), Nat.add(Nat.add(p, U32.to_nat(n)), 7n),
    Lemmas.pow2(35n), Equal.cong(Nat, Nat, a => Nat.add(a, 7n), end,
      Nat.add(p, U32.to_nat(n)), e),
    MNat.lt_of_le_of_lt(Nat.add(Nat.add(p, U32.to_nat(n)), 7n),
      Nat.add(Nat.add(p, U32.to_nat(n)), 31n), Lemmas.pow2(35n),
      MNat.add_le_add_left(7n, 31n, Nat.add(p, U32.to_nat(n)), {==}), h))

# Compose reader bounds over opaque naturals: https://github.com/bendlang/bend/issues/1071.
def rounded_skip_nat(+p: Nat, +n: Nat, +end: Nat, -finished: Nat,
  e: {end == Nat.add(p, n) : Nat},
  ef: {finished == rounded(end) : Nat}) -> MNat.le(p, finished):
  le_right_rw(p, finished, rounded(end), ef,
    le_right_rw(p, rounded(end), rounded(Nat.add(p, n)),
      Equal.cong(Nat, Nat, x => rounded(x), end, Nat.add(p, n), e), rounded_contains(p, n)))

def finished_skip_nat(+p: Nat, +n: U32, +end: Nat,
  +e: {end == Nat.add(p, U32.to_nat(n)) : Nat},
  h: MNat.lt(Nat.add(end, 7n), Lemmas.pow2(35n))) ->
  MNat.le(p, finish_bits(end)):
  rounded_skip_nat(p, U32.to_nat(n), end, finish_bits(end), e, finish_bits_nat(end, h))

def finished_remaining_nat(+p: Nat, +n: U32, +end: Nat,
  e: {end == Nat.add(p, U32.to_nat(n)) : Nat},
  h: MNat.lt(Nat.add(end, 7n), Lemmas.pow2(35n)),
  sk: MNat.le(p, finish_bits(end))) ->
  {Nat.sub(finish_bits(end), p) == Nat.sub(rounded(Nat.add(p, U32.to_nat(n))), p) : Nat}:
  Equal.cong(Nat, Nat, a => Nat.sub(a, p), finish_bits(end),
    rounded(Nat.add(p, U32.to_nat(n))),
    Equal.trans(Nat, finish_bits(end), rounded(end), rounded(Nat.add(p, U32.to_nat(n))),
      finish_bits_nat(end, h),
      Equal.cong(Nat, Nat, x => rounded(x), end, Nat.add(p, U32.to_nat(n)), e)))

def finish_guards(+p: Nat, +n: U32, +end: Nat,
  +e: {end == Nat.add(p, U32.to_nat(n)) : Nat},
  h: MNat.lt(Nat.add(Nat.add(p, U32.to_nat(n)), 31n), Lemmas.pow2(35n)),
  width: MNat.le(U32.to_nat(n), 32n)) ->
  {Nat.is_le(p, finish_bits(end)) == True{} : Bool} &
  {Nat.is_le(U32.to_nat(n), Nat.min(32n, Nat.sub(finish_bits(end), p))) == True{} : Bool}:
  +hf = finish_room(p, n, end, e, h)
  +sk = finished_skip_nat(p, n, end, e, hf)
  (sk, read_min(n, Nat.sub(finish_bits(end), p), width,
    le_right_rw(U32.to_nat(n), Nat.sub(finish_bits(end), p),
      Nat.sub(rounded(Nat.add(p, U32.to_nat(n))), p),
      finished_remaining_nat(p, n, end, e, hf, sk), rounded_remaining(p, U32.to_nat(n)))))

def index(+p: Nat) -> U32:
  Bits.pos.index(p)

def offset(+p: Nat) -> U32:
  Bits.pos.offset(p)

def index_room(+p: Nat, h: MNat.lt(p, Lemmas.pow2(35n))) -> MNat.lt(p, Lemmas.pow2(37n)):
  MNat.lt_trans(p, Lemmas.pow2(35n), Lemmas.pow2(37n), h, Field.pow2_lt(35n, 37n, {==}))

def index_bound(+p: Nat, h: MNat.lt(p, Lemmas.pow2(37n))) ->
  MNat.lt(Nat.div(p, 32n), Lemmas.pow2(32n)):
  power_div_bound(p, 32n, 5n, 37n, 32n, {==}, {==}, h)

def index_nat(+p: Nat, h: MNat.lt(p, Lemmas.pow2(37n))) ->
  {U32.to_nat(index(p)) == Nat.div(p, 32n) : Nat}:
  Lemmas.u32_to_from_nat(Nat.div(p, 32n), index_bound(p, h))

def offset_nat(+p: Nat) -> {U32.to_nat(offset(p)) == Nat.mod(p, 32n) : Nat}:
  Lemmas.u32_to_from_nat(Nat.mod(p, 32n),
    MNat.lt_trans(Nat.mod(p, 32n), 32n, Lemmas.pow2(32n), MNat.mod_lt(p, 31n), {==}))

# Keep division and bounds opaque to concrete words: https://github.com/bendlang/bend/issues/1071.
def offset_bound_nat(+p: Nat, +s: Nat, e: {s == Nat.mod(p, 32n) : Nat}) -> MNat.le(s, 31n):
  le_left_rw(s, Nat.mod(p, 32n), 31n, e,
    MNat.le_of_lt_succ(Nat.mod(p, 32n), 31n, MNat.mod_lt(p, 31n)))

def offset_bound(+p: Nat) -> MNat.le(U32.to_nat(offset(p)), 31n):
  offset_bound_nat(p, U32.to_nat(offset(p)), offset_nat(p))

def position_split_nat(+p: Nat, +q: Nat, +s: Nat,
  eq: {q == Nat.div(p, 32n) : Nat}, es: {s == Nat.mod(p, 32n) : Nat}) ->
  {Nat.add(Nat.mul(q, 32n), s) == p : Nat}:
  %Equal.sym(Nat, q, Nat.div(p, 32n), eq) : {Nat.add(Nat.mul(_, 32n), s) == p : Nat}
  %Equal.sym(Nat, s, Nat.mod(p, 32n), es) :
    {Nat.add(Nat.mul(Nat.div(p, 32n), 32n), _) == p : Nat}
  MNat.div_mod_eq(p, 31n)

def position_split(+p: Nat, h: MNat.lt(p, Lemmas.pow2(37n))) ->
  {Nat.add(Nat.mul(U32.to_nat(index(p)), 32n), U32.to_nat(offset(p))) == p : Nat}:
  position_split_nat(p, U32.to_nat(index(p)), U32.to_nat(offset(p)), index_nat(p, h), offset_nat(p))

def position_add_nat(+p: Nat, +n: U32) ->
  {Nat.add(p, U32.to_nat(n)) == Nat.add(p, U32.to_nat(n)) : Nat}:
  {==}

def position_step_split(+p: Nat, +n: Nat, +q: Nat, +s: Nat, +end: Nat,
  ep: {Nat.add(Nat.mul(q, 32n), s) == p : Nat},
  ee: {end == Nat.add(p, n) : Nat}) ->
  {Nat.add(Nat.mul(q, 32n), Nat.add(s, n)) == end : Nat}:
  Equal.trans(Nat, Nat.add(Nat.mul(q, 32n), Nat.add(s, n)), Nat.add(p, n), end,
    Equal.trans(Nat, Nat.add(Nat.mul(q, 32n), Nat.add(s, n)),
      Nat.add(Nat.add(Nat.mul(q, 32n), s), n), Nat.add(p, n),
      Equal.sym(Nat, Nat.add(Nat.add(Nat.mul(q, 32n), s), n),
        Nat.add(Nat.mul(q, 32n), Nat.add(s, n)), MNat.add_assoc(Nat.mul(q, 32n), s, n)),
      Equal.cong(Nat, Nat, a => Nat.add(a, n), Nat.add(Nat.mul(q, 32n), s), p, ep)),
    Equal.sym(Nat, end, Nat.add(p, n), ee))

def next_noncross_nat(+p: Nat, +n: Nat, +q: Nat, +s: Nat, +end: Nat,
  ep: {Nat.add(Nat.mul(q, 32n), s) == p : Nat},
  ee: {end == Nat.add(p, n) : Nat}, +h: MNat.lt(Nat.add(s, n), 32n)) ->
  {Nat.mod(end, 32n) == Nat.add(s, n) : Nat} & {Nat.div(end, 32n) == q : Nat}:
  +e = position_step_split(p, n, q, s, end, ep, ee)
  (Equal.sym(Nat, Nat.add(s, n), Nat.mod(end, 32n),
    Lemmas.mod_unique(q, Nat.add(s, n), end, 32n, h, e)),
   Equal.sym(Nat, q, Nat.div(end, 32n),
    Lemmas.div_unique(32n, q, Nat.add(s, n), end, {==}, h, e)))

def cross_remainder_bound(+s: Nat, +n: Nat, hs: MNat.le(s, 31n), hn: MNat.le(n, 32n)) ->
  MNat.lt(Nat.sub(Nat.add(s, n), 32n), 32n):
  MNat.lt_succ_of_le(Nat.sub(Nat.add(s, n), 32n), 31n,
    MNat.sub_le_sub_right(Nat.add(s, n), 63n, MNat.add_le_add(s, n, 31n, 32n, hs, hn), 32n))

def cross_split(+q: Nat, +t: Nat, h: MNat.le(32n, t)) ->
  {Nat.add(Nat.mul(1n+q, 32n), Nat.sub(t, 32n)) == Nat.add(Nat.mul(q, 32n), t) : Nat}:
  %Equal.sym(Nat, Nat.mul(1n+q, 32n), Nat.add(Nat.mul(q, 32n), 32n), MNat.succ_mul(q, 32n)) :
    {Nat.add(_, Nat.sub(t, 32n)) == Nat.add(Nat.mul(q, 32n), t) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(Nat.mul(q, 32n), 32n), Nat.sub(t, 32n)),
    Nat.add(Nat.mul(q, 32n), Nat.add(32n, Nat.sub(t, 32n))),
    MNat.add_assoc(Nat.mul(q, 32n), 32n, Nat.sub(t, 32n))) :
    {_ == Nat.add(Nat.mul(q, 32n), t) : Nat}
  Equal.cong(Nat, Nat, a => Nat.add(Nat.mul(q, 32n), a),
    Nat.add(32n, Nat.sub(t, 32n)), t, MNat.add_sub_of_le(32n, t, h))

def next_cross_nat(+p: Nat, +n: Nat, +q: Nat, +s: Nat, +end: Nat,
  ep: {Nat.add(Nat.mul(q, 32n), s) == p : Nat},
  ee: {end == Nat.add(p, n) : Nat},
  hs: MNat.le(s, 31n), hn: MNat.le(n, 32n), h: MNat.le(32n, Nat.add(s, n))) ->
  {Nat.mod(end, 32n) == Nat.sub(Nat.add(s, n), 32n) : Nat} &
  {Nat.div(end, 32n) == 1n+q : Nat}:
  +hr = cross_remainder_bound(s, n, hs, hn)
  +e = Equal.trans(Nat, Nat.add(Nat.mul(1n+q, 32n), Nat.sub(Nat.add(s, n), 32n)),
    Nat.add(Nat.mul(q, 32n), Nat.add(s, n)), end,
    cross_split(q, Nat.add(s, n), h), position_step_split(p, n, q, s, end, ep, ee))
  (Equal.sym(Nat, Nat.sub(Nat.add(s, n), 32n), Nat.mod(end, 32n),
    Lemmas.mod_unique(1n+q, Nat.sub(Nat.add(s, n), 32n), end, 32n, hr, e)),
   Equal.sym(Nat, 1n+q, Nat.div(end, 32n),
    Lemmas.div_unique(32n, 1n+q, Nat.sub(Nat.add(s, n), 32n), end, {==}, hr, e)))

def position_step.of(+end: Nat, +s: Nat, +q: Nat, bound: MNat.lt(end, Lemmas.pow2(35n)),
  h: {Nat.mod(end, 32n) == s : Nat} & {Nat.div(end, 32n) == q : Nat}) ->
  {U32.to_nat(offset(end)) == s : Nat} & {U32.to_nat(index(end)) == q : Nat}:
  (es, eq) = h
  (Equal.trans(Nat, U32.to_nat(offset(end)), Nat.mod(end, 32n), s, offset_nat(end), es),
   Equal.trans(Nat, U32.to_nat(index(end)), Nat.div(end, 32n), q, index_nat(end, index_room(end, bound)), eq))

def position_step_noncross(+p: Nat, +n: U32, +end: Nat,
  +room: MNat.lt(p, Lemmas.pow2(35n)), +bound: MNat.lt(end, Lemmas.pow2(35n)),
  ee: {end == Nat.add(p, U32.to_nat(n)) : Nat},
  h: MNat.lt(Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)), 32n)) ->
  {U32.to_nat(offset(end)) == Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)) : Nat} &
  {U32.to_nat(index(end)) == U32.to_nat(index(p)) : Nat}:
  position_step.of(end, Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)), U32.to_nat(index(p)), bound,
    next_noncross_nat(p, U32.to_nat(n), U32.to_nat(index(p)),
      U32.to_nat(offset(p)), end, position_split(p, index_room(p, room)), ee, h))

def position_step_cross(+p: Nat, +n: U32, +end: Nat,
  +room: MNat.lt(p, Lemmas.pow2(35n)), +bound: MNat.lt(end, Lemmas.pow2(35n)),
  ee: {end == Nat.add(p, U32.to_nat(n)) : Nat},
  hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(32n, Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)))) ->
  {U32.to_nat(offset(end)) == Nat.sub(Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)), 32n) : Nat} &
  {U32.to_nat(index(end)) == 1n+U32.to_nat(index(p)) : Nat}:
  position_step.of(end, Nat.sub(Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)), 32n),
    1n+U32.to_nat(index(p)), bound,
    next_cross_nat(p, U32.to_nat(n), U32.to_nat(index(p)),
      U32.to_nat(offset(p)), end, position_split(p, index_room(p, room)), ee, offset_bound(p), hn, h))

def next_noncross(+p: Nat, +n: U32,
  +room: MNat.lt(Nat.add(p, U32.to_nat(n)), Lemmas.pow2(35n)),
  h: MNat.lt(Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)), 32n)) ->
  {U32.to_nat(offset(Nat.add(p, U32.to_nat(n)))) == Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)) : Nat} &
  {U32.to_nat(index(Nat.add(p, U32.to_nat(n)))) == U32.to_nat(index(p)) : Nat}:
  position_step_noncross(p, n, Nat.add(p, U32.to_nat(n)),
    MNat.lt_of_le_of_lt(p, Nat.add(p, U32.to_nat(n)), Lemmas.pow2(35n), MNat.le_add_right(p, U32.to_nat(n)), room),
    room, position_add_nat(p, n), h)

def next_cross(+p: Nat, +n: U32,
  +room: MNat.lt(Nat.add(p, U32.to_nat(n)), Lemmas.pow2(35n)),
  hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(32n, Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)))) ->
  {U32.to_nat(offset(Nat.add(p, U32.to_nat(n)))) == Nat.sub(Nat.add(U32.to_nat(offset(p)), U32.to_nat(n)), 32n) : Nat} &
  {U32.to_nat(index(Nat.add(p, U32.to_nat(n)))) == 1n+U32.to_nat(index(p)) : Nat}:
  position_step_cross(p, n, Nat.add(p, U32.to_nat(n)),
    MNat.lt_of_le_of_lt(p, Nat.add(p, U32.to_nat(n)), Lemmas.pow2(35n), MNat.le_add_right(p, U32.to_nat(n)), room),
    room, position_add_nat(p, n), hn, h)
