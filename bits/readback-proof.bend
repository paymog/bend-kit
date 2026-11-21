import Base
import ./bits.bend as Bits
import ./writer-proof.bend as W
import ./array-proof.bend as A
import ./position-proof.bend as P
import ./capacity-proof.bend as C
import ./transition-proof.bend as T
import ./field-proof.bend as Field
import ./invariant-proof.bend as I
import bend-mathlib@0.8.0.0/u32.bend as U
import bend-kit-lemmas@0.1.5.1/lemmas.bend as L
import bend-mathlib@0.8.0.0/nat.bend as N


def image(s: W.State) -> A.Tree:
  W.State{t, dep, p} = s
  t

def depth(s: W.State) -> U32:
  W.State{t, dep, p} = s
  dep

def observed(+msb: Bool, +t: A.Tree, +p: Nat, +n: U32, +v: U32) -> Type:
  {U32.to_nat(Bits.field(msb, n, W.window(msb,
    W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), p))) ==
    Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat}

def div_small(+a: Nat, b: Nat, h: N.lt(a, b)) -> {Nat.div(a, b) == 0n : Nat}:
  match b:
    case 0n:
      Empty.absurd({Nat.div(a, 0n) == 0n : Nat}, N.lt_zero(a)(h))
    case 1n++q:
      N.div_eq_zero_of_le(a, q, N.le_of_lt_succ(a, q, h))

def zero_field(msb: Bool, +v: U32) -> {U32.to_nat(Bits.field(msb, 0, v)) == 0n : Nat}:
  match msb:
    case False{}:
      Equal.trans(Nat, U32.to_nat(U32.and(v, Bits.mask(0))), Nat.mod(U32.to_nat(v), 1n), 0n,
        Field.mask_mod(v, 0, {==}), N.mod_one(U32.to_nat(v)))
    case True{}:
      Equal.trans(Nat, U32.to_nat(U32.shrn(v, 32n)), Nat.div(U32.to_nat(v), L.pow2(32n)), 0n,
        Field.shrn_nat(v, 32n), div_small(U32.to_nat(v), L.pow2(32n), L.u32_to_nat_lt(v)))

def zero_written(+msb: Bool, +t: A.Tree, +p: Nat, +v: U32) -> observed(msb, t, p, 0, v):
  Equal.trans(Nat, U32.to_nat(Bits.field(msb, 0,
    W.window(msb, W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), 0, v)), p))),
    0n, Nat.mod(U32.to_nat(v), 1n),
    zero_field(msb, W.window(msb, W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), 0, v)), p)),
    Equal.sym(Nat, Nat.mod(U32.to_nat(v), 1n), 0n, N.mod_one(U32.to_nat(v))))

def eq_false_sym(+a: U32, +b: U32, h: {U32.is_eq(a, b) == False{} : Bool}) ->
  {U32.is_eq(b, a) == False{} : Bool}:
  Equal.trans(Bool, U32.is_eq(b, a), Nat.is_eq(U32.to_nat(b), U32.to_nat(a)), False{},
    L.u32_is_eq_nat(b, a),
    Equal.trans(Bool, Nat.is_eq(U32.to_nat(b), U32.to_nat(a)), Nat.is_eq(U32.to_nat(a), U32.to_nat(b)), False{},
      N.is_eq_comm(U32.to_nat(b), U32.to_nat(a)),
      Equal.trans(Bool, Nat.is_eq(U32.to_nat(a), U32.to_nat(b)), U32.is_eq(a, b), False{},
        Equal.sym(Bool, U32.is_eq(a, b), Nat.is_eq(U32.to_nat(a), U32.to_nat(b)), L.u32_is_eq_nat(a, b)), h)))

def strict_cross(+p: Nat, +n: U32,
  h: {Nat.is_le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) == False{} : Bool}) ->
  N.lt(32n, Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n))):
  %N.add_sub_of_le(U32.to_nat(P.offset(p)), 32n,
    N.le_trans(U32.to_nat(P.offset(p)), 31n, 32n, P.offset_bound(p), {==})) :
    N.lt(_, Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)))
  N.add_lt_add_left(Nat.sub(32n, U32.to_nat(P.offset(p))), U32.to_nat(n), U32.to_nat(P.offset(p)),
    L.lt_rw(Nat.sub(32n, U32.to_nat(P.offset(p))), U32.to_nat((32 - P.offset(p) : U32)), U32.to_nat(n),
      Equal.sym(Nat, U32.to_nat((32 - P.offset(p) : U32)), Nat.sub(32n, U32.to_nat(P.offset(p))), T.offset_gap_nat(p)),
      N.lt_of_not_le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32)), h)))

def cross.of(+msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  shapes: A.shape(U32.to_nat(dep), t) & A.shape(U32.to_nat(dep), t),
  +hd: N.lt(U32.to_nat(dep), 31n), +hp: N.le(p, W.capacity(U32.to_nat(dep))),
  +hi: N.lt(U32.to_nat(P.index(p)), L.pow2(U32.to_nat(dep))),
  +hj: N.lt(U32.to_nat((P.index(p) + 1 : U32)), L.pow2(U32.to_nat(dep))),
  hn: N.le(U32.to_nat(n), 32n), tail: A.zero_after(U32.to_nat(dep), t, P.index(p)),
  clean: W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) -> observed(msb, t, p, n, v):
  (sh0, sh1) = shapes
  +hd32 = N.lt_trans(U32.to_nat(dep), 31n, 32n, hd, {==})
  +ne = C.next_index_ne(U32.to_nat(dep), p, hd, hp)
  W.written_field(U32.to_nat(dep), t, p, msb, n, v, sh0, hd32, hi, hj,
    eq_false_sym(P.index(p), (P.index(p) + 1 : U32), ne), ne,
    A.get_after_zero(U32.to_nat(dep), t, P.index(p), (P.index(p) + 1 : U32), sh1, tail, hd32, hi, hj,
      A.next_index_lt(U32.to_nat(dep), P.index(p), hd32, hi)), P.offset_bound(p), hn, clean)

def active.branch(test: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  e: {test == Nat.is_le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) : Bool},
  sh: A.shape(U32.to_nat(dep), t), +hd: N.lt(U32.to_nat(dep), 31n),
  hp: N.le(p, W.capacity(U32.to_nat(dep))),
  inside: N.lt(p, W.capacity(U32.to_nat(dep))),
  bound: N.le(Nat.add(p, U32.to_nat(n)), W.capacity(U32.to_nat(dep))),
  hn: N.le(U32.to_nat(n), 32n),
  tail: A.zero_after(U32.to_nat(dep), t, P.index(p)),
  clean: W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) -> observed(msb, t, p, n, v):
  match test:
    case True{}:
      W.written_noncross_field(t, p, msb, n, v,
        N.le_trans(U32.to_nat(P.offset(p)), 31n, 32n, P.offset_bound(p), {==}), hn,
        Equal.sym(Bool, True{}, Nat.is_le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))), e), clean)
    case False{}:
      cross.of(msb, t, dep, p, n, v, A.shape_copy(U32.to_nat(dep), t, sh), hd, hp,
        C.index_lt(U32.to_nat(dep), p, hd, inside),
        C.cross_next_index_lt(U32.to_nat(dep), p, n, hd, bound,
          strict_cross(p, n, Equal.sym(Bool, False{}, Nat.is_le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))), e))),
        hn, tail, clean)

def active.of(+msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  sh: A.shape(U32.to_nat(dep), t), hd: N.lt(U32.to_nat(dep), 31n),
  hp: N.le(p, W.capacity(U32.to_nat(dep))),
  inside: N.lt(p, W.capacity(U32.to_nat(dep))),
  bound: N.le(Nat.add(p, U32.to_nat(n)), W.capacity(U32.to_nat(dep))),
  hn: N.le(U32.to_nat(n), 32n),
  active: A.zero_after(U32.to_nat(dep), t, P.index(p)) & W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) ->
  observed(msb, t, p, n, v):
  (tail, clean) = active
  active.branch(Nat.is_le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))), msb, t, dep, p, n, v,
    {==}, sh, hd, hp, inside, bound, hn, tail, clean)

def positive_inside(+p: Nat, +n: Nat, +cap: Nat, pos: N.lt(0n, n), bound: N.le(Nat.add(p, n), cap)) -> N.lt(p, cap):
  N.lt_of_lt_of_le(p, Nat.add(p, n), cap,
    (%N.add_zero(p) : N.lt(_, Nat.add(p, n))
     N.add_lt_add_left(0n, n, p, pos)), bound)

def positive(+msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  valid: W.valid(msb, W.State{t, dep, p}), pos: N.lt(0n, U32.to_nat(n)),
  +bound: N.le(Nat.add(p, U32.to_nat(n)), W.capacity(U32.to_nat(dep))),
  hn: N.le(U32.to_nat(n), 32n)) -> observed(msb, t, p, n, v):
  (sh, (hd, (hp, clean))) = valid
  +inside = positive_inside(p, U32.to_nat(n), W.capacity(U32.to_nat(dep)), pos, bound)
  active.of(msb, t, dep, p, n, v, sh, hd, hp, inside, bound, hn,
    (%inside :
      W.active_clean(_, msb, t, dep, p)
     clean))

def write_at_field.branch(test: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  e: {test == Nat.is_lt(0n, U32.to_nat(n)) : Bool},
  valid: W.valid(msb, W.State{t, dep, p}),
  bound: N.le(Nat.add(p, U32.to_nat(n)), W.capacity(U32.to_nat(dep))),
  hn: N.le(U32.to_nat(n), 32n)) -> observed(msb, t, p, n, v):
  match test:
    case False{}:
      %Equal.sym(U32, n, 0, L.u32_to_nat_inj(n, 0,
        N.le_zero_eq(U32.to_nat(n), N.le_of_not_lt(0n, U32.to_nat(n),
          Equal.sym(Bool, False{}, Nat.is_lt(0n, U32.to_nat(n)), e))))) : observed(msb, t, p, _, v)
      zero_written(msb, t, p, v)
    case True{}:
      positive(msb, t, dep, p, n, v, valid,
        Equal.sym(Bool, True{}, Nat.is_lt(0n, U32.to_nat(n)), e), bound, hn)

def write_at_field(+msb: Bool, s: W.State, +n: U32, +v: U32,
  valid: W.valid(msb, s),
  bound: N.le(Nat.add(W.position(s), U32.to_nat(n)), W.capacity(U32.to_nat(depth(s)))),
  room: N.lt(Nat.add(W.position(s), U32.to_nat(n)), L.pow2(35n)),
  hn: N.le(U32.to_nat(n), 32n)) ->
  {U32.to_nat(Bits.field(msb, n, W.window(msb, image(W.write_at(msb, s, n, v)), W.position(s)))) ==
    Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat}:
  match s:
    case W.State{+t, +dep, +p}:
      write_at_field.branch(Nat.is_lt(0n, U32.to_nat(n)), msb, t, dep, p, n, v, {==}, valid, bound, hn)

def min_width(+n: U32, hn: N.le(U32.to_nat(n), 32n)) -> {U32.min(n, 32) == n : U32}:
  L.u32_to_nat_inj(U32.min(n, 32), n,
    Equal.trans(Nat, U32.to_nat(U32.min(n, 32)), Nat.min(U32.to_nat(n), 32n), U32.to_nat(n),
      U.u32_min_to_nat(n, 32), N.min_eq_left(U32.to_nat(n), 32n, hn)))

def room_depth(full: Bool, +t: A.Tree, +dep: U32, +p: Nat) ->
  {depth(W.room(full, W.State{t, dep, p})) == Bool.pick(U32, full, (dep + 1 : U32), dep) : U32}:
  match full:
    case False{}:
      {==}
    case True{}:
      {==}

def ready_field(+full: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  valid: W.valid(msb, W.room(full, W.State{t, dep, p})),
  bound: N.le(Nat.add(p, U32.to_nat(n)),
    W.capacity(U32.to_nat(Bool.pick(U32, full, (dep + 1 : U32), dep)))),
  room: N.lt(Nat.add(p, U32.to_nat(n)), L.pow2(35n)),
  hn: N.le(U32.to_nat(n), 32n)) ->
  {U32.to_nat(Bits.field(msb, n, W.window(msb,
    image(W.write_at(msb, W.room(full, W.State{t, dep, p}), n, v)), p))) ==
    Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat}:
  %W.room_position(full, W.State{t, dep, p}) :
    {U32.to_nat(Bits.field(msb, n, W.window(msb,
      image(W.write_at(msb, W.room(full, W.State{t, dep, p}), n, v)), _))) ==
      Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat}
  write_at_field(msb, W.room(full, W.State{t, dep, p}), n, v, valid,
    (%Equal.sym(Nat, W.position(W.room(full, W.State{t, dep, p})), p, W.room_position(full, W.State{t, dep, p})) :
       N.le(Nat.add(_, U32.to_nat(n)), W.capacity(U32.to_nat(depth(W.room(full, W.State{t, dep, p})))))
     %Equal.sym(U32, depth(W.room(full, W.State{t, dep, p})),
       Bool.pick(U32, full, (dep + 1 : U32), dep), room_depth(full, t, dep, p)) :
       N.le(Nat.add(p, U32.to_nat(n)), W.capacity(U32.to_nat(_)))
     bound),
    (%Equal.sym(Nat, W.position(W.room(full, W.State{t, dep, p})), p, W.room_position(full, W.State{t, dep, p})) :
       N.lt(Nat.add(_, U32.to_nat(n)), L.pow2(35n))
     room), hn)

def write_field.of(+msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  copies: W.valid(msb, W.State{t, dep, p}) & W.valid(msb, W.State{t, dep, p}),
  +room: N.lt(Nat.add(Nat.add(p, U32.to_nat(n)), 31n), L.pow2(35n)),
  +hn: N.le(U32.to_nat(n), 32n)) ->
  {U32.to_nat(Bits.field(msb, n, W.window(msb,
    image(W.write_at(msb, W.room(U32.is_lt(U32.shln(1, U32.to_nat(dep)),
      Bits.pos.words(Nat.add(p, U32.to_nat(n)))), W.State{t, dep, p}), n, v)), p))) ==
    Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat}:
  (valid0, valid1) = copies
  ready_field(U32.is_lt(U32.shln(1, U32.to_nat(dep)), Bits.pos.words(Nat.add(p, U32.to_nat(n)))),
    msb, t, dep, p, n, v, I.room_preserves(msb, t, dep, p, n, hn, room, valid0),
    I.room_covers(msb, t, dep, p, n, hn, room, valid1),
    C.end_bound(p, U32.to_nat(n), room), hn)

def write_unclamped(+msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  hn: N.le(U32.to_nat(n), 32n)) ->
  {W.write(msb, W.State{t, dep, p}, n, v) ==
    W.write_at(msb, W.room(U32.is_lt(U32.shln(1, U32.to_nat(dep)),
      Bits.pos.words(Nat.add(p, U32.to_nat(n)))), W.State{t, dep, p}), n, v) : W.State}:
  Equal.cong(U32, W.State,
    +m => W.write_at(msb, W.room(U32.is_lt(U32.shln(1, U32.to_nat(dep)),
      Bits.pos.words(Nat.add(p, U32.to_nat(m)))), W.State{t, dep, p}), m, v),
    U32.min(n, 32), n, min_width(n, hn))

def write_field(+msb: Bool, +t: A.Tree, +dep: U32, +p: Nat, +n: U32, +v: U32,
  valid: W.valid(msb, W.State{t, dep, p}),
  room: N.lt(Nat.add(Nat.add(p, U32.to_nat(n)), 31n), L.pow2(35n)),
  +hn: N.le(U32.to_nat(n), 32n)) ->
  {U32.to_nat(Bits.field(msb, n, W.window(msb, image(W.write(msb, W.State{t, dep, p}, n, v)), p))) ==
    Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat}:
  %Equal.sym(W.State, W.write(msb, W.State{t, dep, p}, n, v),
    W.write_at(msb, W.room(U32.is_lt(U32.shln(1, U32.to_nat(dep)),
      Bits.pos.words(Nat.add(p, U32.to_nat(n)))), W.State{t, dep, p}), n, v), write_unclamped(msb, t, dep, p, n, v, hn)) :
    {U32.to_nat(Bits.field(msb, n, W.window(msb, image(_), p))) ==
      Nat.mod(U32.to_nat(v), L.pow2(U32.to_nat(n))) : Nat}
  write_field.of(msb, t, dep, p, n, v, I.valid_copy(msb, W.State{t, dep, p}, valid), room, hn)
