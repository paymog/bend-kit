import Base
import ../bytes/bytes.bend as Bytes
import ../bytes/append-proof.bend as Packed
import ../bits/array-proof.bend as Bound
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ../bits/field-proof.bend as Field
import ../lemmas/array.bend as Tree

def depth_floor(f: Nat, more: Bool, +w: U32, +d: Nat, +cap: U32) -> MNat.le(d, Bytes.depth.go(f, more, w, d, cap)):
  match f more:
    case 0n _:
      MNat.le_refl(d)
    case 1n+p False{}:
      MNat.le_refl(d)
    case 1n+ +p True{}:
      MNat.le_trans(d, 1n+d, Bytes.depth.go(p, U32.is_lt((cap * 2 : U32), w), w, 1n+d, (cap * 2 : U32)),
        MNat.le_of_lt(d, 1n+d, MNat.lt_succ_self(d)), depth_floor(p, U32.is_lt((cap * 2 : U32), w), w, 1n+d, (cap * 2 : U32)))

def less(+a: U32, +b: U32, h: MNat.lt(U32.to_nat(a), U32.to_nat(b))) -> {U32.is_lt(a, b) == True{} : Bool}:
  Equal.trans(Bool, U32.is_lt(a, b), Nat.is_lt(U32.to_nat(a), U32.to_nat(b)), True{}, Lemmas.u32_is_lt_nat(a, b), h)

def not_less(+a: U32, +b: U32, h: MNat.le(U32.to_nat(b), U32.to_nat(a))) -> {U32.is_lt(a, b) == False{} : Bool}:
  Equal.trans(Bool, U32.is_lt(a, b), Nat.is_lt(U32.to_nat(a), U32.to_nat(b)), False{}, Lemmas.u32_is_lt_nat(a, b), MNat.not_lt_of_le(U32.to_nat(b), U32.to_nat(a), h))

def depth_interval(f: Nat, more: Bool, +a: U32, +b: U32, +d: Nat, +cap: U32, +limit: Nat,
  +ha: MNat.le(U32.to_nat(a), U32.to_nat(b)),
  hb: MNat.le(U32.to_nat(b), Lemmas.pow2(Bytes.depth.go(f, more, a, d, cap))),
  +hd: MNat.le(Bytes.depth.go(f, more, a, d, cap), 30n), +hc: {U32.to_nat(cap) == Lemmas.pow2(d) : Nat},
  +hp: MNat.lt(Lemmas.pow2(30n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  emore: {U32.is_lt(cap, a) == more : Bool}) ->
  {Bytes.depth.go(f, more, a, d, cap) == Bytes.depth.go(f, U32.is_lt(cap, b), b, d, cap) : Nat}:
  match f more:
    case 0n _:
      {==}
    case 1n+ +p False{}:
      +bound : MNat.le(U32.to_nat(b), U32.to_nat(cap)) = (
        %Equal.sym(Nat, U32.to_nat(cap), Lemmas.pow2(d), hc) : MNat.le(U32.to_nat(b), _)
        hb)
      %Equal.sym(Bool, U32.is_lt(cap, b), False{}, not_less(cap, b, bound)) : {d == Bytes.depth.go(1n+p, _, b, d, cap) : Nat}
      {==}
    case 1n+ +p True{}:
      +next = U32.is_lt((cap * 2 : U32), a)
      +dn = Bytes.depth.go(p, next, a, 1n+d, (cap * 2 : U32))
      +hnext = MNat.le_trans(1n+d, dn, 30n, depth_floor(p, next, a, 1n+d, (cap * 2 : U32)), hd)
      +step = MNat.lt_of_le_of_lt(Lemmas.pow2(1n+d), Lemmas.pow2(30n), limit, Packed.pow2_le(1n+d, 30n, hnext), hp)
      +capnext = Packed.cap_double(cap, 2, Lemmas.pow2(d), limit, hc, {==}, step, hu)
      +moreb = less(cap, b, MNat.lt_of_lt_of_le(U32.to_nat(cap), U32.to_nat(a), U32.to_nat(b), Bound.u32_lt_bound(cap, a, emore), ha))
      %Equal.sym(Bool, U32.is_lt(cap, b), True{}, moreb) : {dn == Bytes.depth.go(1n+p, _, b, d, cap) : Nat}
      depth_interval(p, next, a, b, 1n+d, (cap * 2 : U32), limit, ha, hb, hd, capnext, hp, hu, {==})

def depth_room(+a: U32, +b: U32, +limit: Nat,
  ha: MNat.le(U32.to_nat(a), U32.to_nat(b)), +hd: MNat.le(Bytes.depth(a), 30n),
  room: {U32.is_le(b, U32.shln(1, Bytes.depth(a))) == True{} : Bool},
  hp: MNat.lt(Lemmas.pow2(30n), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {Bytes.depth(a) == Bytes.depth(b) : Nat}:
  +hwidth = MNat.lt_of_le_of_lt(Bytes.depth(a), 30n, 32n, hd, {==})
  +hb : MNat.le(U32.to_nat(b), Lemmas.pow2(Bytes.depth(a))) = (
    %Field.shln_one_nat(Bytes.depth(a), hwidth) : MNat.le(U32.to_nat(b), _)
    %Lemmas.u32_is_le_nat(b, U32.shln(1, Bytes.depth(a))) : {_ == True{} : Bool}
    room)
  depth_interval(32n, U32.is_lt(1, a), a, b, 0n, 1, limit, ha, hb, hd, {==}, hp, hu, {==})

def words_monotone(+a: U32, +b: U32, +limit: Nat, +h: MNat.le(U32.to_nat(a), U32.to_nat(b)),
  +hn: MNat.lt(Nat.add(U32.to_nat(b), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(U32.to_nat(Bytes.words(a)), U32.to_nat(Bytes.words(b))):
  +ha = MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(a), 3n), Nat.add(U32.to_nat(b), 3n), limit, MNat.add_le_add_right(U32.to_nat(a), U32.to_nat(b), 3n, h), hn)
  %Equal.sym(Nat, U32.to_nat(Bytes.words(a)), Nat.div(Nat.add(U32.to_nat(a), 3n), 4n), Packed.words_nat(a, limit, ha, hu)) :
    MNat.le(_, U32.to_nat(Bytes.words(b)))
  %Equal.sym(Nat, U32.to_nat(Bytes.words(b)), Nat.div(Nat.add(U32.to_nat(b), 3n), 4n), Packed.words_nat(b, limit, hn, hu)) :
    MNat.le(Nat.div(Nat.add(U32.to_nat(a), 3n), 4n), _)
  MNat.div_le_div(Nat.add(U32.to_nat(a), 3n), Nat.add(U32.to_nat(b), 3n), 3n, MNat.add_le_add_right(U32.to_nat(a), U32.to_nat(b), 3n, h))

def room_depth(+a: U32, +b: U32, +limit: Nat, +h: MNat.le(U32.to_nat(a), U32.to_nat(b)),
  +hn: MNat.lt(Nat.add(U32.to_nat(b), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  room: {Bytes.room(a, b) == True{} : Bool}) ->
  {Bytes.depth(Bytes.words(a)) == Bytes.depth(Bytes.words(b)) : Nat}:
  +ha = MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(a), 3n), Nat.add(U32.to_nat(b), 3n), limit, MNat.add_le_add_right(U32.to_nat(a), U32.to_nat(b), 3n, h), hn)
  depth_room(Bytes.words(a), Bytes.words(b), Lemmas.pow2(32n), words_monotone(a, b, limit, h, hn, hu),
    Packed.allocation_depth(a, Packed.alloc_capacity(a, limit, ha, hu)), room, Field.pow2_lt(30n, 32n, {==}), MNat.le_refl(Lemmas.pow2(32n)))

def grow_shape(fits: Bool, +a: U32, +b: U32, +src: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Bytes.depth(Bytes.words(a)), Packed.as_bits(src)),
  +h: MNat.le(U32.to_nat(a), U32.to_nat(b)), +hn: MNat.lt(Nat.add(U32.to_nat(b), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  room: {Bytes.room(a, b) == fits : Bool}) ->
  Bound.shape(Bytes.depth(Bytes.words(b)), Packed.as_bits(Packed.grow.if(fits, a, src, b))):
  match fits:
    case False{}:
      Packed.copy_shape(Bytes.depth(Bytes.words(b)), a, src, Packed.alloc(b), 0, 0, Packed.fresh_shape(Bytes.depth(Bytes.words(b))))
    case True{}:
      %room_depth(a, b, limit, h, hn, hu, room) : Bound.shape(_, Packed.as_bits(src))
      shape

def append_shape(+a: U32, +b: U32, +left: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Bytes.depth(Bytes.words(a)), Packed.as_bits(left)),
  +h: MNat.le(U32.to_nat(a), U32.to_nat((a + b : U32))),
  +hn: MNat.lt(Nat.add(U32.to_nat((a + b : U32)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  Bound.shape(Bytes.depth(Bytes.words((a + b : U32))), Packed.as_bits(Packed.append(a, left, b, right))):
  Packed.copy_shape(Bytes.depth(Bytes.words((a + b : U32))), b, right, Packed.grow(a, left, (a + b : U32)), 0, a,
    grow_shape(Bytes.room(a, (a + b : U32)), a, (a + b : U32), left, limit, shape, h, hn, hu, {==}))
