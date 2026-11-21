import Base
import bend-kit-lemmas@0.1.5.1/lemmas.bend as L
import bend-mathlib@0.8.0.0/nat.bend as N
import ./field-proof.bend as Field
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

# Separate literal conversion from bounded addition: https://github.com/bendlang/bend/issues/1071.
def add31_nat(+v: U32, h: N.lt(Nat.add(U32.to_nat(v), 31n), L.pow2(32n))) ->
  {U32.to_nat((v + 31 : U32)) == Nat.add(U32.to_nat(v), 31n) : Nat}:
  %Position.add_word_nat(v, 31) : {_ == Nat.add(U32.to_nat(v), 31n) : Nat}
  Position.word_sum_nat(32n, Field.word(v), Field.word(31), U32.to_nat(v), 31n,
    Field.word_nat(v), {==}, h)

def end_bound(+p: Nat, +n: Nat, h: N.lt(Nat.add(Nat.add(p, n), 31n), L.pow2(32n))) ->
  N.lt(Nat.add(p, n), L.pow2(32n)):
  N.lt_of_le_of_lt(Nat.add(p, n), Nat.add(Nat.add(p, n), 31n), L.pow2(32n),
    N.le_add_right(Nat.add(p, n), 31n), h)

def sum31_nat(+p: U32, +n: U32,
  +h: N.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), L.pow2(32n))) ->
  {U32.to_nat((p + n + 31 : U32)) == Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n) : Nat}:
  +e = Position.position_add_nat(p, n, end_bound(U32.to_nat(p), U32.to_nat(n), h))
  Equal.trans(Nat, U32.to_nat((p + n + 31 : U32)), Nat.add(U32.to_nat((p + n : U32)), 31n),
    Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n),
    add31_nat((p + n : U32),
      (%Equal.sym(Nat, U32.to_nat((p + n : U32)), Nat.add(U32.to_nat(p), U32.to_nat(n)), e) :
        N.lt(Nat.add(_, 31n), L.pow2(32n))
       h)),
    Equal.cong(Nat, Nat, x => Nat.add(x, 31n), U32.to_nat((p + n : U32)),
      Nat.add(U32.to_nat(p), U32.to_nat(n)), e))

def needed_nat(+p: U32, +n: U32,
  h: N.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), L.pow2(32n))) ->
  {U32.to_nat(((p + n + 31) >> 5n : U32)) == needed(U32.to_nat(p), U32.to_nat(n)) : Nat}:
  Equal.trans(Nat, U32.to_nat(((p + n + 31) >> 5n : U32)),
    Nat.div(U32.to_nat((p + n + 31 : U32)), 32n), needed(U32.to_nat(p), U32.to_nat(n)),
    Field.shrn_nat((p + n + 31 : U32), 5n),
    Equal.cong(Nat, Nat, x => Nat.div(x, 32n), U32.to_nat((p + n + 31 : U32)),
      Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), sum31_nat(p, n, h)))

# Transport only opaque Nat capacities across the runtime comparison: https://github.com/bendlang/bend/issues/1071.
def runtime_comparison(+d: U32, +p: U32, +n: U32, hd: N.lt(U32.to_nat(d), 32n),
  h: N.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), L.pow2(32n))) ->
  {U32.is_lt(U32.shln(1, U32.to_nat(d)), ((p + n + 31) >> 5n : U32)) ==
    Nat.is_lt(bits(U32.to_nat(d)), Nat.add(U32.to_nat(p), U32.to_nat(n))) : Bool}:
  %Equal.sym(Bool, U32.is_lt(U32.shln(1, U32.to_nat(d)), ((p + n + 31) >> 5n : U32)),
    Nat.is_lt(U32.to_nat(U32.shln(1, U32.to_nat(d))), U32.to_nat(((p + n + 31) >> 5n : U32))),
    L.u32_is_lt_nat(U32.shln(1, U32.to_nat(d)), ((p + n + 31) >> 5n : U32))) :
    {_ == Nat.is_lt(bits(U32.to_nat(d)), Nat.add(U32.to_nat(p), U32.to_nat(n))) : Bool}
  %Equal.sym(Nat, U32.to_nat(U32.shln(1, U32.to_nat(d))), words(U32.to_nat(d)),
    Field.shln_one_nat(U32.to_nat(d), hd)) :
    {Nat.is_lt(_, U32.to_nat(((p + n + 31) >> 5n : U32))) ==
      Nat.is_lt(bits(U32.to_nat(d)), Nat.add(U32.to_nat(p), U32.to_nat(n))) : Bool}
  %Equal.sym(Nat, U32.to_nat(((p + n + 31) >> 5n : U32)), needed(U32.to_nat(p), U32.to_nat(n)),
    needed_nat(p, n, h)) :
    {Nat.is_lt(words(U32.to_nat(d)), _) == Nat.is_lt(bits(U32.to_nat(d)), Nat.add(U32.to_nat(p), U32.to_nat(n))) : Bool}
  comparison(U32.to_nat(d), U32.to_nat(p), U32.to_nat(n))

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
  h: N.lt(Nat.add(Nat.add(p, n), 31n), L.pow2(32n))) -> N.lt(d, 27n):
  pow_lt_reflect(5n+d, 32n,
    (%bits_power(d) : N.lt(_, L.pow2(32n))
     N.lt_trans(bits(d), Nat.add(p, n), L.pow2(32n), full, end_bound(p, n, h))))

def depth_bound(full: Bool, +d: Nat, +p: Nat, +n: Nat,
  e: {full == Nat.is_lt(bits(d), Nat.add(p, n)) : Bool}, hd: N.lt(d, 28n),
  h: N.lt(Nat.add(Nat.add(p, n), 31n), L.pow2(32n))) -> N.lt(depth(full, d), 28n):
  match full:
    case False{}:
      hd
    case True{}:
      growth_depth(d, p, n, Equal.sym(Bool, True{}, Nat.is_lt(bits(d), Nat.add(p, n)), e), h)

# Keep the increment bound separate from the concrete word: https://github.com/bendlang/bend/issues/1071.
def increment_nat(+d: U32, hd: N.lt(U32.to_nat(d), 28n)) ->
  {U32.to_nat((d + 1 : U32)) == 1n+U32.to_nat(d) : Nat}:
  Equal.trans(Nat, U32.to_nat((d + 1 : U32)), Nat.add(U32.to_nat(d), 1n), 1n+U32.to_nat(d),
    (%Position.add_word_nat(d, 1) : {_ == Nat.add(U32.to_nat(d), 1n) : Nat}
     Position.word_sum_nat(32n, Field.word(d), Field.word(1), U32.to_nat(d), 1n,
       Field.word_nat(d), {==},
       N.lt_trans(Nat.add(U32.to_nat(d), 1n), 29n, L.pow2(32n),
         (%Equal.sym(Nat, Nat.add(U32.to_nat(d), 1n), 1n+U32.to_nat(d), N.add_comm(U32.to_nat(d), 1n)) : N.lt(_, 29n)
          hd), {==}))),
    N.add_comm(U32.to_nat(d), 1n))

def runtime_depth(full: Bool, +d: U32, hd: N.lt(U32.to_nat(d), 28n)) ->
  {U32.to_nat(Bool.pick(U32, full, (d + 1 : U32), d)) == depth(full, U32.to_nat(d)) : Nat}:
  match full:
    case False{}:
      {==}
    case True{}:
      increment_nat(d, hd)

def index_le(+d: Nat, +p: U32, hp: N.le(U32.to_nat(p), bits(d))) ->
  N.le(U32.to_nat(Position.index(p)), words(d)):
  %Equal.sym(Nat, U32.to_nat(Position.index(p)), Nat.div(U32.to_nat(p), 32n), Position.index_nat(p)) :
    N.le(_, words(d))
  %N.mul_div_cancel(words(d), 31n) : N.le(Nat.div(U32.to_nat(p), 32n), _)
  N.div_le_div(U32.to_nat(p), bits(d), 31n, hp)

def index_lt(+d: Nat, +p: U32, hp: N.lt(U32.to_nat(p), bits(d))) ->
  N.lt(U32.to_nat(Position.index(p)), words(d)):
  %Equal.sym(Nat, U32.to_nat(Position.index(p)), Nat.div(U32.to_nat(p), 32n), Position.index_nat(p)) :
    N.lt(_, words(d))
  N.lt_of_mul_lt_mul_right(Nat.div(U32.to_nat(p), 32n), words(d), 32n,
    N.lt_of_le_of_lt(Nat.mul(Nat.div(U32.to_nat(p), 32n), 32n), U32.to_nat(p), bits(d),
      N.div_mul_le_self(U32.to_nat(p), 32n), hp))

def index_at_capacity(+d: Nat, +p: U32, ep: {U32.to_nat(p) == bits(d) : Nat}) ->
  {U32.to_nat(Position.index(p)) == words(d) : Nat}:
  Equal.trans(Nat, U32.to_nat(Position.index(p)), Nat.div(U32.to_nat(p), 32n), words(d),
    Position.index_nat(p),
    Equal.trans(Nat, Nat.div(U32.to_nat(p), 32n), Nat.div(bits(d), 32n), words(d),
      Equal.cong(Nat, Nat, x => Nat.div(x, 32n), U32.to_nat(p), bits(d), ep),
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

def cross_index_lt(+d: Nat, +p: U32, +n: U32,
  room: N.le(Nat.add(U32.to_nat(p), U32.to_nat(n)), bits(d)),
  cross: N.lt(32n, Nat.add(U32.to_nat(Position.offset(p)), U32.to_nat(n)))) ->
  N.lt(1n+U32.to_nat(Position.index(p)), words(d)):
  cross_index_nat(words(d), U32.to_nat(p), U32.to_nat(n),
    U32.to_nat(Position.index(p)), U32.to_nat(Position.offset(p)), Position.position_split(p), room, cross)

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


def next_power_bound(+d: Nat, hd: N.lt(d, 28n)) -> N.lt(L.pow2(1n+d), L.pow2(32n)):
  Field.pow2_lt(1n+d, 32n,
    N.lt_of_le_of_lt(1n+d, 28n, 32n, N.succ_le_of_lt(d, 28n, hd), {==}))


def next_index_nat(+d: Nat, +p: U32, hd: N.lt(d, 28n), hp: N.le(U32.to_nat(p), bits(d))) ->
  {U32.to_nat((Position.index(p) + 1 : U32)) == 1n+U32.to_nat(Position.index(p)) : Nat}:
  successor_nat(Position.index(p),
    successor_word_bound(U32.to_nat(Position.index(p)), d, L.pow2(32n), index_le(d, p, hp),
      next_power_bound(d, hd)))

def adjacent_ne(+a: Nat) -> {Nat.is_eq(a, 1n+a) == False{} : Bool}:
  match a:
    case 0n:
      {==}
    case 1n+ +q:
      adjacent_ne(q)

def next_index_ne(+d: Nat, +p: U32, hd: N.lt(d, 28n), hp: N.le(U32.to_nat(p), bits(d))) ->
  {U32.is_eq(Position.index(p), (Position.index(p) + 1 : U32)) == False{} : Bool}:
  Equal.trans(Bool, U32.is_eq(Position.index(p), (Position.index(p) + 1 : U32)),
    Nat.is_eq(U32.to_nat(Position.index(p)), U32.to_nat((Position.index(p) + 1 : U32))), False{},
    L.u32_is_eq_nat(Position.index(p), (Position.index(p) + 1 : U32)),
    Equal.trans(Bool, Nat.is_eq(U32.to_nat(Position.index(p)), U32.to_nat((Position.index(p) + 1 : U32))),
      Nat.is_eq(U32.to_nat(Position.index(p)), 1n+U32.to_nat(Position.index(p))), False{},
      Equal.cong(Nat, Bool, x => Nat.is_eq(U32.to_nat(Position.index(p)), x),
        U32.to_nat((Position.index(p) + 1 : U32)), 1n+U32.to_nat(Position.index(p)), next_index_nat(d, p, hd, hp)),
      adjacent_ne(U32.to_nat(Position.index(p)))))

def cross_next_index_lt(+d: Nat, +p: U32, +n: U32, +hd: N.lt(d, 28n),
  +room: N.le(Nat.add(U32.to_nat(p), U32.to_nat(n)), bits(d)),
  cross: N.lt(32n, Nat.add(U32.to_nat(Position.offset(p)), U32.to_nat(n)))) ->
  N.lt(U32.to_nat((Position.index(p) + 1 : U32)), words(d)):
  %Equal.sym(Nat, U32.to_nat((Position.index(p) + 1 : U32)), 1n+U32.to_nat(Position.index(p)),
    next_index_nat(d, p, hd,
      N.le_trans(U32.to_nat(p), Nat.add(U32.to_nat(p), U32.to_nat(n)), bits(d),
        N.le_add_right(U32.to_nat(p), U32.to_nat(n)), room))) : N.lt(_, words(d))
  cross_index_lt(d, p, n, room, cross)

def runtime_covers(+full: Bool, +d: U32, +p: U32, +n: U32,
  e: {full == Nat.is_lt(bits(U32.to_nat(d)), Nat.add(U32.to_nat(p), U32.to_nat(n))) : Bool},
  hd: N.lt(U32.to_nat(d), 28n), hp: N.le(U32.to_nat(p), bits(U32.to_nat(d))),
  hn: N.le(U32.to_nat(n), 32n)) ->
  N.le(Nat.add(U32.to_nat(p), U32.to_nat(n)), bits(U32.to_nat(Bool.pick(U32, full, (d + 1 : U32), d)))):
  Position.le_right_rw(Nat.add(U32.to_nat(p), U32.to_nat(n)),
    bits(U32.to_nat(Bool.pick(U32, full, (d + 1 : U32), d))), bits(depth(full, U32.to_nat(d))),
    Equal.cong(Nat, Nat, x => bits(x), U32.to_nat(Bool.pick(U32, full, (d + 1 : U32), d)),
      depth(full, U32.to_nat(d)), runtime_depth(full, d, hd)),
    covers(full, U32.to_nat(d), U32.to_nat(p), U32.to_nat(n), e, hp, hn))
