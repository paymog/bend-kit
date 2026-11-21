import Base
import bend-kit-lemmas@0.1.5.1/lemmas.bend as L
import bend-mathlib@0.8.0.0/nat.bend as N
import ./field-proof.bend as Field
import ./bits.bend as Bits
import ./position-proof.bend as Position
def words(+d: Nat) -> Nat:
  L.pow2(d)

def bits(+d: Nat) -> Nat:
  Nat.mul(words(d), 32n)

def needed(+p: Nat, +n: Nat) -> Nat:
  Nat.div(Nat.add(Nat.add(p, n), 31n), 32n)

def depth(full: Bool, d: Nat) -> Nat:
  match full:
    case False{}:
      d
    case True{}:
      1n+d

def pow_le(+a: Nat, +b: Nat, h: N.le(a, b)) -> N.le(L.pow2(a), L.pow2(b)):
  match a:
    case 0n:
      N.succ_le_of_lt(0n, L.pow2(b), Field.pow2_pos(b))
    case 1n+ +p:
      match b:
        case 0n:
          Empty.absurd(N.le(L.pow2(1n+p), L.pow2(0n)), N.internal_false_ne_true(h))
        case 1n+ +q:
          N.double_le_double(L.pow2(p), L.pow2(q), pow_le(p, q, h))

def pow_lt_reflect.if(test: Bool, +a: Nat, +b: Nat,
  e: {test == Nat.is_lt(a, b) : Bool}, h: N.lt(L.pow2(a), L.pow2(b))) -> N.lt(a, b):
  match test:
    case True{}:
      Equal.sym(Bool, True{}, Nat.is_lt(a, b), e)
    case False{}:
      Empty.absurd(N.lt(a, b), N.lt_irrefl(L.pow2(b))(
        N.lt_of_le_of_lt(L.pow2(b), L.pow2(a), L.pow2(b),
          pow_le(b, a, N.le_of_not_lt(a, b, Equal.sym(Bool, False{}, Nat.is_lt(a, b), e))), h)))

def pow_lt_reflect(+a: Nat, +b: Nat, h: N.lt(L.pow2(a), L.pow2(b))) -> N.lt(a, b):
  pow_lt_reflect.if(Nat.is_lt(a, b), a, b, {==}, h)

def bits_power(+d: Nat) -> {bits(d) == L.pow2(5n+d) : Nat}:
  Equal.trans(Nat, Nat.mul(L.pow2(d), 32n), Nat.mul(32n, L.pow2(d)), L.pow2(5n+d),
    N.mul_comm(L.pow2(d), 32n),
    Equal.sym(Nat, L.pow2(5n+d), Nat.mul(32n, L.pow2(d)), Field.pow2_add(5n, d)))

def bits_double(+d: Nat) -> {bits(1n+d) == Nat.double(bits(d)) : Nat}:
  Equal.sym(Nat, Nat.double(bits(d)), bits(1n+d), N.double_mul(words(d), 32n))

def bits_min(+d: Nat) -> N.le(32n, bits(d)):
  %N.one_mul(32n) : N.le(_, bits(d))
  N.mul_le_mul_right(1n, words(d), 32n, N.succ_le_of_lt(0n, words(d), Field.pow2_pos(d)))

def ceil_cmp(+c: Nat, +end: Nat) ->
  {Nat.is_lt(c, Nat.div(Nat.add(end, 31n), 32n)) == Nat.is_lt(Nat.mul(c, 32n), end) : Bool}:
  %Equal.sym(Bool, Nat.is_lt(c, Nat.div(Nat.add(end, 31n), 32n)),
    Nat.is_le(1n+c, Nat.div(Nat.add(end, 31n), 32n)),
    N.is_lt_eq_succ_le(c, Nat.div(Nat.add(end, 31n), 32n))) :
    {_ == Nat.is_lt(Nat.mul(c, 32n), end) : Bool}
  %Equal.sym(Bool, Nat.is_le(1n+c, Nat.div(Nat.add(end, 31n), 32n)),
    Nat.is_le(Nat.mul(1n+c, 32n), Nat.add(end, 31n)),
    N.le_div_iff_mul_le(1n+c, Nat.add(end, 31n), 31n)) :
    {_ == Nat.is_lt(Nat.mul(c, 32n), end) : Bool}
  %Equal.sym(Nat, Nat.add(end, 31n), Nat.add(31n, end), N.add_comm(end, 31n)) :
    {Nat.is_le(Nat.mul(1n+c, 32n), _) == Nat.is_lt(Nat.mul(c, 32n), end) : Bool}
  %N.add_le_add_iff_left(31n, 1n+Nat.mul(c, 32n), end) :
    {_ == Nat.is_lt(Nat.mul(c, 32n), end) : Bool}
  Equal.sym(Bool, Nat.is_lt(Nat.mul(c, 32n), end), Nat.is_le(1n+Nat.mul(c, 32n), end),
    N.is_lt_eq_succ_le(Nat.mul(c, 32n), end))

def comparison(+d: Nat, +p: Nat, +n: Nat) ->
  {Nat.is_lt(words(d), needed(p, n)) == Nat.is_lt(bits(d), Nat.add(p, n)) : Bool}:
  ceil_cmp(words(d), Nat.add(p, n))

def end_bound(+p: Nat, +n: Nat, h: N.lt(Nat.add(Nat.add(p, n), 31n), L.pow2(35n))) ->
  N.lt(Nat.add(p, n), L.pow2(35n)):
  N.lt_of_le_of_lt(Nat.add(p, n), Nat.add(Nat.add(p, n), 31n), L.pow2(35n),
    N.le_add_right(Nat.add(p, n), 31n), h)

def needed_nat.of(+p: Nat, +n: Nat,
  h: N.lt(Nat.add(Nat.add(p, n), 31n), L.pow2(35n))) ->
  {U32.to_nat(Bits.pos.words(Nat.add(p, n))) == needed(p, n) : Nat}:
  Position.index_nat(Nat.add(Nat.add(p, n), 31n),
    Position.index_room(Nat.add(Nat.add(p, n), 31n), h))

def needed_nat(+p: Nat, +n: U32,
  h: N.lt(Nat.add(Nat.add(p, U32.to_nat(n)), 31n), L.pow2(35n))) ->
  {U32.to_nat(Bits.pos.words(Nat.add(p, U32.to_nat(n)))) == needed(p, U32.to_nat(n)) : Nat}:
  needed_nat.of(p, U32.to_nat(n), h)

def runtime_comparison(+d: U32, +p: Nat, +n: U32, hd: N.lt(U32.to_nat(d), 32n),
  h: N.lt(Nat.add(Nat.add(p, U32.to_nat(n)), 31n), L.pow2(35n))) ->
  {U32.is_lt(U32.shln(1, U32.to_nat(d)), Bits.pos.words(Nat.add(p, U32.to_nat(n)))) ==
    Nat.is_lt(bits(U32.to_nat(d)), Nat.add(p, U32.to_nat(n))) : Bool}:
  %Equal.sym(Bool, U32.is_lt(U32.shln(1, U32.to_nat(d)), Bits.pos.words(Nat.add(p, U32.to_nat(n)))),
    Nat.is_lt(U32.to_nat(U32.shln(1, U32.to_nat(d))), U32.to_nat(Bits.pos.words(Nat.add(p, U32.to_nat(n))))),
    L.u32_is_lt_nat(U32.shln(1, U32.to_nat(d)), Bits.pos.words(Nat.add(p, U32.to_nat(n))))) :
    {_ == Nat.is_lt(bits(U32.to_nat(d)), Nat.add(p, U32.to_nat(n))) : Bool}
  %Equal.sym(Nat, U32.to_nat(U32.shln(1, U32.to_nat(d))), words(U32.to_nat(d)),
    Field.shln_one_nat(U32.to_nat(d), hd)) :
    {Nat.is_lt(_, U32.to_nat(Bits.pos.words(Nat.add(p, U32.to_nat(n))))) ==
      Nat.is_lt(bits(U32.to_nat(d)), Nat.add(p, U32.to_nat(n))) : Bool}
  %Equal.sym(Nat, U32.to_nat(Bits.pos.words(Nat.add(p, U32.to_nat(n)))), needed(p, U32.to_nat(n)),
    needed_nat(p, n, h)) :
    {Nat.is_lt(words(U32.to_nat(d)), _) == Nat.is_lt(bits(U32.to_nat(d)), Nat.add(p, U32.to_nat(n))) : Bool}
  comparison(U32.to_nat(d), p, U32.to_nat(n))

def one_doubling(+d: Nat, +p: Nat, +n: Nat, hp: N.le(p, bits(d)), hn: N.le(n, 32n)) ->
  N.le(Nat.add(p, n), bits(1n+d)):
  %Equal.sym(Nat, bits(1n+d), Nat.double(bits(d)), bits_double(d)) : N.le(Nat.add(p, n), _)
  %Equal.sym(Nat, Nat.double(bits(d)), Nat.add(bits(d), bits(d)), N.double_eq_add(bits(d))) :
    N.le(Nat.add(p, n), _)
  N.add_le_add(p, n, bits(d), bits(d), hp, N.le_trans(n, 32n, bits(d), hn, bits_min(d)))

def covers(full: Bool, +d: Nat, +p: Nat, +n: Nat,
  e: {full == Nat.is_lt(bits(d), Nat.add(p, n)) : Bool},
  hp: N.le(p, bits(d)), hn: N.le(n, 32n)) -> N.le(Nat.add(p, n), bits(depth(full, d))):
  match full:
    case False{}:
      N.le_of_not_lt(bits(d), Nat.add(p, n), Equal.sym(Bool, False{}, Nat.is_lt(bits(d), Nat.add(p, n)), e))
    case True{}:
      one_doubling(d, p, n, hp, hn)

def growth_depth(+d: Nat, +p: Nat, +n: Nat,
  full: N.lt(bits(d), Nat.add(p, n)),
  h: N.lt(Nat.add(Nat.add(p, n), 31n), L.pow2(35n))) -> N.lt(d, 30n):
  pow_lt_reflect(5n+d, 35n,
    (%bits_power(d) : N.lt(_, L.pow2(35n))
     N.lt_trans(bits(d), Nat.add(p, n), L.pow2(35n), full, end_bound(p, n, h))))

def depth_bound(full: Bool, +d: Nat, +p: Nat, +n: Nat,
  e: {full == Nat.is_lt(bits(d), Nat.add(p, n)) : Bool}, hd: N.lt(d, 31n),
  h: N.lt(Nat.add(Nat.add(p, n), 31n), L.pow2(35n))) -> N.lt(depth(full, d), 31n):
  match full:
    case False{}:
      hd
    case True{}:
      growth_depth(d, p, n, Equal.sym(Bool, True{}, Nat.is_lt(bits(d), Nat.add(p, n)), e), h)

# Keep the increment bound separate from the concrete word: https://github.com/bendlang/bend/issues/1071.
def increment_nat(+d: U32, hd: N.lt(U32.to_nat(d), 31n)) ->
  {U32.to_nat((d + 1 : U32)) == 1n+U32.to_nat(d) : Nat}:
  Equal.trans(Nat, U32.to_nat((d + 1 : U32)), Nat.add(U32.to_nat(d), 1n), 1n+U32.to_nat(d),
    (%Position.add_word_nat(d, 1) : {_ == Nat.add(U32.to_nat(d), 1n) : Nat}
     Position.word_sum_nat(32n, Field.word(d), Field.word(1), U32.to_nat(d), 1n,
       Field.word_nat(d), {==},
       N.lt_trans(Nat.add(U32.to_nat(d), 1n), 32n, L.pow2(32n),
         (%Equal.sym(Nat, Nat.add(U32.to_nat(d), 1n), 1n+U32.to_nat(d), N.add_comm(U32.to_nat(d), 1n)) : N.lt(_, 32n)
          hd), {==}))),
    N.add_comm(U32.to_nat(d), 1n))

def runtime_depth(full: Bool, +d: U32, hd: N.lt(U32.to_nat(d), 31n)) ->
  {U32.to_nat(Bool.pick(U32, full, (d + 1 : U32), d)) == depth(full, U32.to_nat(d)) : Nat}:
  match full:
    case False{}:
      {==}
    case True{}:
      increment_nat(d, hd)

def position_bound(+d: Nat, +p: Nat, hd: N.lt(d, 31n), hp: N.le(p, bits(d))) ->
  N.lt(p, L.pow2(37n)):
  N.lt_of_le_of_lt(p, bits(d), L.pow2(37n), hp,
    (%Equal.sym(Nat, bits(d), L.pow2(5n+d), bits_power(d)) : N.lt(_, L.pow2(37n))
     Field.pow2_lt(5n+d, 37n,
       N.lt_trans(5n+d, 36n, 37n, N.add_lt_add_left(d, 31n, 5n, hd), {==}))))

def index_le(+d: Nat, +p: Nat, +hd: N.lt(d, 31n), +hp: N.le(p, bits(d))) ->
  N.le(U32.to_nat(Position.index(p)), words(d)):
  %Equal.sym(Nat, U32.to_nat(Position.index(p)), Nat.div(p, 32n), Position.index_nat(p, position_bound(d, p, hd, hp))) :
    N.le(_, words(d))
  %N.mul_div_cancel(words(d), 31n) : N.le(Nat.div(p, 32n), _)
  N.div_le_div(p, bits(d), 31n, hp)

def index_lt(+d: Nat, +p: Nat, +hd: N.lt(d, 31n), +hp: N.lt(p, bits(d))) ->
  N.lt(U32.to_nat(Position.index(p)), words(d)):
  %Equal.sym(Nat, U32.to_nat(Position.index(p)), Nat.div(p, 32n), Position.index_nat(p, position_bound(d, p, hd, N.le_of_lt(p, bits(d), hp)))) :
    N.lt(_, words(d))
  N.lt_of_mul_lt_mul_right(Nat.div(p, 32n), words(d), 32n,
    N.lt_of_le_of_lt(Nat.mul(Nat.div(p, 32n), 32n), p, bits(d),
      N.div_mul_le_self(p, 32n), hp))

def index_at_capacity(+d: Nat, +p: Nat, +hd: N.lt(d, 31n), +ep: {p == bits(d) : Nat}) ->
  {U32.to_nat(Position.index(p)) == words(d) : Nat}:
  Equal.trans(Nat, U32.to_nat(Position.index(p)), Nat.div(p, 32n), words(d),
    Position.index_nat(p, position_bound(d, p, hd, Position.le_left_rw(p, bits(d), bits(d), ep, N.le_refl(bits(d))))),
    Equal.trans(Nat, Nat.div(p, 32n), Nat.div(bits(d), 32n), words(d),
      Equal.cong(Nat, Nat, x => Nat.div(x, 32n), p, bits(d), ep),
      N.mul_div_cancel(words(d), 31n)))

# Keep the split position opaque while cancelling capacity: https://github.com/bendlang/bend/issues/1071.
def cross_index_nat(+c: Nat, +p: Nat, +n: Nat, +q: Nat, +s: Nat,
  ep: {Nat.add(Nat.mul(q, 32n), s) == p : Nat},
  room: N.le(Nat.add(p, n), Nat.mul(c, 32n)), cross: N.lt(32n, Nat.add(s, n))) ->
  N.lt(1n+q, c):
  N.lt_of_mul_lt_mul_right(1n+q, c, 32n,
    N.lt_of_lt_of_le(Nat.mul(1n+q, 32n), Nat.add(p, n), Nat.mul(c, 32n),
      (%Equal.sym(Nat, Nat.mul(1n+q, 32n), Nat.add(Nat.mul(q, 32n), 32n), N.succ_mul(q, 32n)) :
        N.lt(_, Nat.add(p, n))
       %Position.position_step_split(p, n, q, s, Nat.add(p, n), ep, {==}) :
        N.lt(Nat.add(Nat.mul(q, 32n), 32n), _)
       N.add_lt_add_left(32n, Nat.add(s, n), Nat.mul(q, 32n), cross)), room))

def cross_index_lt(+d: Nat, +p: Nat, +n: U32, +hd: N.lt(d, 31n),
  +room: N.le(Nat.add(p, U32.to_nat(n)), bits(d)),
  cross: N.lt(32n, Nat.add(U32.to_nat(Position.offset(p)), U32.to_nat(n)))) ->
  N.lt(1n+U32.to_nat(Position.index(p)), words(d)):
  cross_index_nat(words(d), p, U32.to_nat(n),
    U32.to_nat(Position.index(p)), U32.to_nat(Position.offset(p)), Position.position_split(p, position_bound(d, p, hd,
      N.le_trans(p, Nat.add(p, U32.to_nat(n)), bits(d), N.le_add_right(p, U32.to_nat(n)), room))), room, cross)

# Keep the large limit opaque during commutation: https://github.com/bendlang/bend/issues/1071.
def successor_bound(+i: Nat, +limit: Nat, h: N.lt(1n+i, limit)) -> N.lt(Nat.add(i, 1n), limit):
  L.lt_rw(Nat.add(i, 1n), 1n+i, limit, N.add_comm(i, 1n), h)

def successor_nat(+i: U32, h: N.lt(1n+U32.to_nat(i), L.pow2(32n))) ->
  {U32.to_nat((i + 1 : U32)) == 1n+U32.to_nat(i) : Nat}:
  Equal.trans(Nat, U32.to_nat((i + 1 : U32)), Nat.add(U32.to_nat(i), 1n), 1n+U32.to_nat(i),
    (%Position.add_word_nat(i, 1) : {_ == Nat.add(U32.to_nat(i), 1n) : Nat}
     Position.word_sum_nat(32n, Field.word(i), Field.word(1), U32.to_nat(i), 1n,
       Field.word_nat(i), {==},
       successor_bound(U32.to_nat(i), L.pow2(32n), h))),
    N.add_comm(U32.to_nat(i), 1n))

# Bound through a variable power, not the literal 2^28: https://github.com/bendlang/bend/issues/1071.
def successor_word_bound(+i: Nat, +d: Nat, +limit: Nat, hi: N.le(i, L.pow2(d)),
  hd: N.lt(L.pow2(1n+d), limit)) -> N.lt(1n+i, limit):
  N.lt_of_le_of_lt(1n+i, L.pow2(1n+d), limit,
    N.succ_le_of_lt(i, L.pow2(1n+d),
      N.lt_of_le_of_lt(i, L.pow2(d), L.pow2(1n+d), hi,
        Field.pow2_lt(d, 1n+d, N.lt_succ_self(d)))),
    hd)


def next_power_bound(+d: Nat, hd: N.lt(d, 31n)) -> N.lt(L.pow2(1n+d), L.pow2(32n)):
  Field.pow2_lt(1n+d, 32n,
    N.lt_of_le_of_lt(1n+d, 31n, 32n, N.succ_le_of_lt(d, 31n, hd), {==}))


def next_index_nat(+d: Nat, +p: Nat, +hd: N.lt(d, 31n), hp: N.le(p, bits(d))) ->
  {U32.to_nat((Position.index(p) + 1 : U32)) == 1n+U32.to_nat(Position.index(p)) : Nat}:
  successor_nat(Position.index(p),
    successor_word_bound(U32.to_nat(Position.index(p)), d, L.pow2(32n), index_le(d, p, hd, hp),
      next_power_bound(d, hd)))

def adjacent_ne(+a: Nat) -> {Nat.is_eq(a, 1n+a) == False{} : Bool}:
  match a:
    case 0n:
      {==}
    case 1n+ +q:
      adjacent_ne(q)

def next_index_ne(+d: Nat, +p: Nat, hd: N.lt(d, 31n), hp: N.le(p, bits(d))) ->
  {U32.is_eq(Position.index(p), (Position.index(p) + 1 : U32)) == False{} : Bool}:
  Equal.trans(Bool, U32.is_eq(Position.index(p), (Position.index(p) + 1 : U32)),
    Nat.is_eq(U32.to_nat(Position.index(p)), U32.to_nat((Position.index(p) + 1 : U32))), False{},
    L.u32_is_eq_nat(Position.index(p), (Position.index(p) + 1 : U32)),
    Equal.trans(Bool, Nat.is_eq(U32.to_nat(Position.index(p)), U32.to_nat((Position.index(p) + 1 : U32))),
      Nat.is_eq(U32.to_nat(Position.index(p)), 1n+U32.to_nat(Position.index(p))), False{},
      Equal.cong(Nat, Bool, x => Nat.is_eq(U32.to_nat(Position.index(p)), x),
        U32.to_nat((Position.index(p) + 1 : U32)), 1n+U32.to_nat(Position.index(p)), next_index_nat(d, p, hd, hp)),
      adjacent_ne(U32.to_nat(Position.index(p)))))

def cross_next_index_lt(+d: Nat, +p: Nat, +n: U32, +hd: N.lt(d, 31n),
  +room: N.le(Nat.add(p, U32.to_nat(n)), bits(d)),
  cross: N.lt(32n, Nat.add(U32.to_nat(Position.offset(p)), U32.to_nat(n)))) ->
  N.lt(U32.to_nat((Position.index(p) + 1 : U32)), words(d)):
  %Equal.sym(Nat, U32.to_nat((Position.index(p) + 1 : U32)), 1n+U32.to_nat(Position.index(p)),
    next_index_nat(d, p, hd,
      N.le_trans(p, Nat.add(p, U32.to_nat(n)), bits(d),
        N.le_add_right(p, U32.to_nat(n)), room))) : N.lt(_, words(d))
  cross_index_lt(d, p, n, hd, room, cross)

def runtime_covers(+full: Bool, +d: U32, +p: Nat, +n: U32,
  e: {full == Nat.is_lt(bits(U32.to_nat(d)), Nat.add(p, U32.to_nat(n))) : Bool},
  hd: N.lt(U32.to_nat(d), 31n), hp: N.le(p, bits(U32.to_nat(d))),
  hn: N.le(U32.to_nat(n), 32n)) ->
  N.le(Nat.add(p, U32.to_nat(n)), bits(U32.to_nat(Bool.pick(U32, full, (d + 1 : U32), d)))):
  Position.le_right_rw(Nat.add(p, U32.to_nat(n)),
    bits(U32.to_nat(Bool.pick(U32, full, (d + 1 : U32), d))), bits(depth(full, U32.to_nat(d))),
    Equal.cong(Nat, Nat, x => bits(x), U32.to_nat(Bool.pick(U32, full, (d + 1 : U32), d)),
      depth(full, U32.to_nat(d)), runtime_depth(full, d, hd)),
    covers(full, U32.to_nat(d), p, U32.to_nat(n), e, hp, hn))
