import Base
import ./bits.bend as Bits
import ./writer-proof.bend as W
import ./array-proof.bend as A
import ./position-proof.bend as P
import ./field-proof.bend as Field
import ./capacity-proof.bend as C
import ./transition-proof.bend as T
import ./prefix-proof.bend as Prefix
import ./LAWS.bend as Laws
import bend-mathlib@0.8.0.0/u32.bend as MU32
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat

def zero_after_copy.left(-depth: Nat, -xs: A.Tree, -ys: A.Tree, -n: U32, -i: U32, -z: Bool,
  +hr: {ys == A.zeros(depth) : A.Tree},
  copies: A.zero_after.go(depth, xs, n, i, z) & A.zero_after.go(depth, xs, n, i, z)) ->
  (A.zero_after.go(depth, xs, n, i, z) & {ys == A.zeros(depth) : A.Tree}) &
  (A.zero_after.go(depth, xs, n, i, z) & {ys == A.zeros(depth) : A.Tree}):
  (h0, h1) = copies
  ((h0, hr), (h1, hr))

def zero_after_copy.go(+depth: Nat, +t: A.Tree, +n: U32, +i: U32, +z: Bool,
  h: A.zero_after.go(depth, t, n, i, z)) ->
  A.zero_after.go(depth, t, n, i, z) & A.zero_after.go(depth, t, n, i, z):
  match depth t z:
    case 0n A.Leaf{x} _:
      (Unit{}, Unit{})
    case 0n A.Node{xs, ys} _:
      match h:
    case 1n+p A.Leaf{x} _:
      match h:
    case 1n++p A.Node{+xs, +ys} True{}:
      (hl, +hr) = h
      zero_after_copy.left(p, xs, ys, U32.shr(n), i,
        U32.is_lt(i, U32.shr(U32.shr(n))), hr,
        zero_after_copy.go(p, xs, U32.shr(n), i,
          U32.is_lt(i, U32.shr(U32.shr(n))), hl))
    case 1n++p A.Node{xs, +ys} False{}:
      zero_after_copy.go(p, ys, U32.shr(n), U32.sub(i, U32.shr(n)),
        U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), h)

def zero_after_copy(+depth: Nat, +t: A.Tree, +i: U32, h: A.zero_after(depth, t, i)) ->
  A.zero_after(depth, t, i) & A.zero_after(depth, t, i):
  zero_after_copy.go(depth, t, A.size(t), U32.and(i, U32.sub(A.size(t), 1)),
    U32.is_lt(U32.and(i, U32.sub(A.size(t), 1)), U32.shr(A.size(t))), h)

def lo_clean(+msb: Bool, +s: U32, +n: U32, +v: U32, +lo: U32, +end: U32,
  hs: MNat.le(U32.to_nat(s), 32n), hn: MNat.le(U32.to_nat(n), 32n),
  elsb: {U32.to_nat(end) == Nat.add(U32.to_nat(s), U32.to_nat(n)) : Nat},
  emsb: {U32.to_nat((32 - end : U32)) == Nat.sub(U32.to_nat((32 - n : U32)), U32.to_nat(s)) : Nat},
  clean: W.current_clean(msb, s, lo)) ->
  W.current_clean(msb, end, Field.written_lo(msb, s, n, v, lo)):
  match msb:
    case False{}:
      Field.lsb_lo_clean(s, n, v, lo, end, elsb, clean)
    case True{}:
      Field.msb_lo_clean(s, n, v, lo, (32 - end : U32), hs, hn, emsb, clean)

def hi_clean(+msb: Bool, +s: U32, +n: U32, +v: U32, +end: U32,
  elsb: {U32.to_nat(end) == Nat.sub(U32.to_nat(n), U32.to_nat((32 - s : U32))) : Nat},
  emsb: {U32.to_nat((32 - end : U32)) == Nat.add(U32.to_nat((32 - s : U32)), U32.to_nat((32 - n : U32))) : Nat}) ->
  W.current_clean(msb, end, Field.written_hi(msb, s, n, v)):
  match msb:
    case False{}:
      Field.lsb_hi_clean(s, n, v, end, elsb)
    case True{}:
      Field.msb_hi_clean(s, n, v, (32 - end : U32), emsb)

def put_parts_noncross_zero_after(+depth: Nat, +t: A.Tree, +k: U32,
  +msb: Bool, +s: U32, +n: U32, +v: U32,
  hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(U32.to_nat(n), U32.to_nat((32 - s : U32))),
  tail: A.zero_after(depth, t, k)) ->
  A.zero_after(depth, W.put_parts(t, k, Bits.parts(msb, s, n, v)), k):
  %Equal.sym(A.Tree, W.put_parts(t, k, Bits.parts(msb, s, n, v)),
    W.or_if(U32.is_ne(Field.first(Bits.parts(msb, s, n, v)), 0), t, k,
      Field.first(Bits.parts(msb, s, n, v))),
    W.put_parts_no_spill(t, k, Bits.parts(msb, s, n, v), W.no_spill(msb, s, n, v, hn, h))) :
    A.zero_after(depth, _, k)
  W.or_zero_after(depth, U32.is_ne(Field.first(Bits.parts(msb, s, n, v)), 0), t, k,
    Field.first(Bits.parts(msb, s, n, v)), tail)

def put_parts_zero_after_next(+depth: Nat, +t: A.Tree, +k: U32, parts: U32 & U32,
  sh: A.shape(depth, t), tail: A.zero_after(depth, t, k),
  hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(k), Lemmas.pow2(depth)),
  hj: MNat.lt(U32.to_nat((k + 1 : U32)), Lemmas.pow2(depth))) ->
  A.zero_after(depth, W.put_parts(t, k, parts), (k + 1 : U32)):
  (x0, x1) = parts
  W.put_zero_after_next(depth, t, k, x0, x1, sh, tail, hd, hi, hj)

def put_parts_high_read(+depth: Nat, +t: A.Tree, +k: U32, parts: U32 & U32,
  sh: A.shape(depth, t), hd: MNat.lt(depth, 32n),
  hi: MNat.lt(U32.to_nat(k), Lemmas.pow2(depth)),
  hj: MNat.lt(U32.to_nat((k + 1 : U32)), Lemmas.pow2(depth)),
  ne: {U32.is_eq(k, (k + 1 : U32)) == False{} : Bool},
  zero: {A.get(t, (k + 1 : U32)) == 0 : U32}) ->
  {A.get(W.put_parts(t, k, parts), (k + 1 : U32)) == Field.second(parts) : U32}:
  match parts:
    case (+x0, +x1):
      Equal.trans(U32, A.get(W.put(t, k, x0, x1), (k + 1 : U32)),
        U32.or(A.get(t, (k + 1 : U32)), x1), x1,
        W.put_read_high(depth, t, k, x0, x1, sh, hd, hi, hj, ne),
        (%Equal.sym(U32, A.get(t, (k + 1 : U32)), 0, zero) : {U32.or(_, x1) == x1 : U32}
         Field.u32_zero_or(x1)))

def write_at_noncross_clean(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  +hn: MNat.le(U32.to_nat(n), 32n),
  +h: MNat.le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))),
  index: {P.index((p + n : U32)) == P.index(p) : U32},
  elsb: {U32.to_nat(P.offset((p + n : U32))) == Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)) : Nat},
  emsb: {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.sub(U32.to_nat((32 - n : U32)), U32.to_nat(P.offset(p))) : Nat},
  tail: A.zero_after(U32.to_nat(dep), t, P.index(p)),
  clean: W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) ->
  A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32))) &
  W.current_clean(msb, P.offset((p + n : U32)),
    A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32)))):
  %Equal.sym(U32, P.index((p + n : U32)), P.index(p), index) :
    A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), _) &
    W.current_clean(msb, P.offset((p + n : U32)), A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), _))
  (put_parts_noncross_zero_after(U32.to_nat(dep), t, P.index(p), msb, P.offset(p), n, v, hn, h, tail),
   (%Equal.sym(U32, A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index(p)),
      Field.written_lo(msb, P.offset(p), n, v, A.get(t, P.index(p))),
      W.put_parts_noncross_read(t, P.index(p), msb, P.offset(p), n, v, hn, h)) :
      W.current_clean(msb, P.offset((p + n : U32)), _)
    lo_clean(msb, P.offset(p), n, v, A.get(t, P.index(p)), P.offset((p + n : U32)),
      MNat.le_trans(U32.to_nat(P.offset(p)), 31n, 32n, P.offset_bound(p), {==}), hn, elsb, emsb, clean)))

def shape_three.of(+depth: Nat, +t: A.Tree,
  copies: A.shape(depth, t) & A.shape(depth, t)) ->
  A.shape(depth, t) & (A.shape(depth, t) & A.shape(depth, t)):
  (sh0, sh1) = copies
  (sh0, A.shape_copy(depth, t, sh1))

def shape_three(+depth: Nat, +t: A.Tree, sh: A.shape(depth, t)) ->
  A.shape(depth, t) & (A.shape(depth, t) & A.shape(depth, t)):
  shape_three.of(depth, t, A.shape_copy(depth, t, sh))

def write_at_cross_clean.of(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  shapes: A.shape(U32.to_nat(dep), t) & (A.shape(U32.to_nat(dep), t) & A.shape(U32.to_nat(dep), t)),
  +hd: MNat.lt(U32.to_nat(dep), 32n),
  +hi: MNat.lt(U32.to_nat(P.index(p)), Lemmas.pow2(U32.to_nat(dep))),
  +hj: MNat.lt(U32.to_nat((P.index(p) + 1 : U32)), Lemmas.pow2(U32.to_nat(dep))),
  ne: {U32.is_eq(P.index(p), (P.index(p) + 1 : U32)) == False{} : Bool},
  index: {P.index((p + n : U32)) == (P.index(p) + 1 : U32) : U32},
  elsb: {U32.to_nat(P.offset((p + n : U32))) == Nat.sub(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) : Nat},
  emsb: {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.add(U32.to_nat((32 - P.offset(p) : U32)), U32.to_nat((32 - n : U32))) : Nat},
  tails: A.zero_after(U32.to_nat(dep), t, P.index(p)) & A.zero_after(U32.to_nat(dep), t, P.index(p))) ->
  A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32))) &
  W.current_clean(msb, P.offset((p + n : U32)),
    A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32)))):
  (sh0, (sh2, sh3)) = shapes
  (tail0, tail1) = tails
  +zero = A.get_after_zero(U32.to_nat(dep), t, P.index(p), (P.index(p) + 1 : U32),
    sh0, tail0, hd, hi, hj, A.next_index_lt(U32.to_nat(dep), P.index(p), hd, hi))
  %Equal.sym(U32, P.index((p + n : U32)), (P.index(p) + 1 : U32), index) :
    A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), _) &
    W.current_clean(msb, P.offset((p + n : U32)), A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), _))
  (put_parts_zero_after_next(U32.to_nat(dep), t, P.index(p), Bits.parts(msb, P.offset(p), n, v),
      sh2, tail1, hd, hi, hj),
   (%Equal.sym(U32, A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), (P.index(p) + 1 : U32)),
      Field.written_hi(msb, P.offset(p), n, v),
      put_parts_high_read(U32.to_nat(dep), t, P.index(p), Bits.parts(msb, P.offset(p), n, v), sh3, hd, hi, hj, ne, zero)) :
      W.current_clean(msb, P.offset((p + n : U32)), _)
    hi_clean(msb, P.offset(p), n, v, P.offset((p + n : U32)), elsb, emsb)))

def write_at_cross_clean(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  sh: A.shape(U32.to_nat(dep), t),
  hd: MNat.lt(U32.to_nat(dep), 32n),
  hi: MNat.lt(U32.to_nat(P.index(p)), Lemmas.pow2(U32.to_nat(dep))),
  hj: MNat.lt(U32.to_nat((P.index(p) + 1 : U32)), Lemmas.pow2(U32.to_nat(dep))),
  ne: {U32.is_eq(P.index(p), (P.index(p) + 1 : U32)) == False{} : Bool},
  index: {P.index((p + n : U32)) == (P.index(p) + 1 : U32) : U32},
  elsb: {U32.to_nat(P.offset((p + n : U32))) == Nat.sub(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) : Nat},
  emsb: {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.add(U32.to_nat((32 - P.offset(p) : U32)), U32.to_nat((32 - n : U32))) : Nat},
  tail: A.zero_after(U32.to_nat(dep), t, P.index(p))) ->
  A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32))) &
  W.current_clean(msb, P.offset((p + n : U32)),
    A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32)))):
  write_at_cross_clean.of(msb, t, dep, p, n, v, shape_three(U32.to_nat(dep), t, sh),
    hd, hi, hj, ne, index, elsb, emsb, zero_after_copy(U32.to_nat(dep), t, P.index(p), tail))

def write_at_valid_active(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  sh: A.shape(U32.to_nat(dep), t), hd: MNat.lt(U32.to_nat(dep), 28n),
  bound: MNat.le(U32.to_nat((p + n : U32)), W.capacity(U32.to_nat(dep))),
  active: {Nat.is_lt(U32.to_nat((p + n : U32)), W.capacity(U32.to_nat(dep))) == True{} : Bool},
  clean: A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32))) &
    W.current_clean(msb, P.offset((p + n : U32)), A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32))))) ->
  W.valid(msb, W.write_at(msb, W.State{t, dep, p}, n, v)):
  (W.put_parts_shape(U32.to_nat(dep), t, P.index(p), Bits.parts(msb, P.offset(p), n, v), sh),
   (hd, (bound,
    (%Equal.sym(Bool, Nat.is_lt(U32.to_nat((p + n : U32)), W.capacity(U32.to_nat(dep))), True{}, active) :
      W.active_clean(_, msb, W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), dep, (p + n : U32))
     clean))))

def write_at_valid_end(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  sh: A.shape(U32.to_nat(dep), t), hd: MNat.lt(U32.to_nat(dep), 28n),
  bound: MNat.le(U32.to_nat((p + n : U32)), W.capacity(U32.to_nat(dep))),
  inactive: {Nat.is_lt(U32.to_nat((p + n : U32)), W.capacity(U32.to_nat(dep))) == False{} : Bool}) ->
  W.valid(msb, W.write_at(msb, W.State{t, dep, p}, n, v)):
  (W.put_parts_shape(U32.to_nat(dep), t, P.index(p), Bits.parts(msb, P.offset(p), n, v), sh),
   (hd, (bound,
    (%Equal.sym(Bool, Nat.is_lt(U32.to_nat((p + n : U32)), W.capacity(U32.to_nat(dep))), False{}, inactive) :
      W.active_clean(_, msb, W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), dep, (p + n : U32))
     Unit{}))))

def room_clean_inside.of(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  shapes: A.shape(U32.to_nat(dep), t) & A.shape(U32.to_nat(dep), t),
  +hd: MNat.lt(1n+U32.to_nat(dep), 32n),
  +hi: MNat.lt(U32.to_nat(P.index(p)), Lemmas.pow2(U32.to_nat(dep))),
  tail: A.zero_after(U32.to_nat(dep), t, P.index(p)),
  clean: W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) ->
  A.zero_after(1n+U32.to_nat(dep), A.grow(t, U32.to_nat(dep)), P.index(p)) &
  W.current_clean(msb, P.offset(p), A.get(A.grow(t, U32.to_nat(dep)), P.index(p))):
  (sh0, sh1) = shapes
  (A.zero_after_grow(U32.to_nat(dep), t, P.index(p), sh0, tail, hd, hi),
   (%Equal.sym(U32, A.get(A.grow(t, U32.to_nat(dep)), P.index(p)), A.get(t, P.index(p)),
      A.get_grow(U32.to_nat(dep), t, P.index(p), sh1, hd, hi)) :
      W.current_clean(msb, P.offset(p), _)
    clean))

def room_clean_inside(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  sh: A.shape(U32.to_nat(dep), t),
  hd: MNat.lt(1n+U32.to_nat(dep), 32n),
  hi: MNat.lt(U32.to_nat(P.index(p)), Lemmas.pow2(U32.to_nat(dep))),
  tail: A.zero_after(U32.to_nat(dep), t, P.index(p)),
  clean: W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) ->
  A.zero_after(1n+U32.to_nat(dep), A.grow(t, U32.to_nat(dep)), P.index(p)) &
  W.current_clean(msb, P.offset(p), A.get(A.grow(t, U32.to_nat(dep)), P.index(p))):
  room_clean_inside.of(msb, t, dep, p, A.shape_copy(U32.to_nat(dep), t, sh), hd, hi, tail, clean)

def room_clean_end.of(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  shapes: A.shape(U32.to_nat(dep), t) & A.shape(U32.to_nat(dep), t),
  +hd: MNat.lt(1n+U32.to_nat(dep), 32n),
  +index: {U32.to_nat(P.index(p)) == Lemmas.pow2(U32.to_nat(dep)) : Nat}) ->
  A.zero_after(1n+U32.to_nat(dep), A.grow(t, U32.to_nat(dep)), P.index(p)) &
  W.current_clean(msb, P.offset(p), A.get(A.grow(t, U32.to_nat(dep)), P.index(p))):
  (sh0, sh1) = shapes
  (A.zero_after_grow_new(U32.to_nat(dep), t, P.index(p), sh0, hd, index),
   (%Equal.sym(U32, A.get(A.grow(t, U32.to_nat(dep)), P.index(p)), 0,
      A.get_grow_new(U32.to_nat(dep), t, P.index(p), sh1, hd, index)) :
      W.current_clean(msb, P.offset(p), _)
    W.zero_clean(msb, P.offset(p))))

def room_clean_end(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  sh: A.shape(U32.to_nat(dep), t),
  hd: MNat.lt(1n+U32.to_nat(dep), 32n),
  index: {U32.to_nat(P.index(p)) == Lemmas.pow2(U32.to_nat(dep)) : Nat}) ->
  A.zero_after(1n+U32.to_nat(dep), A.grow(t, U32.to_nat(dep)), P.index(p)) &
  W.current_clean(msb, P.offset(p), A.get(A.grow(t, U32.to_nat(dep)), P.index(p))):
  room_clean_end.of(msb, t, dep, p, A.shape_copy(U32.to_nat(dep), t, sh), hd, index)

def room_valid(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  sh: A.shape(U32.to_nat(dep), t),
  +depth: {U32.to_nat((dep + 1 : U32)) == 1n+U32.to_nat(dep) : Nat},
  hd: MNat.lt(U32.to_nat((dep + 1 : U32)), 28n),
  bound: MNat.le(U32.to_nat(p), W.capacity(U32.to_nat((dep + 1 : U32)))),
  active: {Nat.is_lt(U32.to_nat(p), W.capacity(U32.to_nat((dep + 1 : U32)))) == True{} : Bool},
  clean: A.zero_after(1n+U32.to_nat(dep), A.grow(t, U32.to_nat(dep)), P.index(p)) &
    W.current_clean(msb, P.offset(p), A.get(A.grow(t, U32.to_nat(dep)), P.index(p)))) ->
  W.valid(msb, W.room(True{}, W.State{t, dep, p})):
  ((%Equal.sym(Nat, U32.to_nat((dep + 1 : U32)), 1n+U32.to_nat(dep), depth) :
     A.shape(_, A.grow(t, U32.to_nat(dep)))
    A.grow_shape(U32.to_nat(dep), t, sh)),
   (hd, (bound,
    (%Equal.sym(Bool, Nat.is_lt(U32.to_nat(p), W.capacity(U32.to_nat((dep + 1 : U32)))), True{}, active) :
      W.active_clean(_, msb, A.grow(t, U32.to_nat(dep)), (dep + 1 : U32), p)
     %Equal.sym(Nat, U32.to_nat((dep + 1 : U32)), 1n+U32.to_nat(dep), depth) :
      A.zero_after(_, A.grow(t, U32.to_nat(dep)), P.index(p)) &
        W.current_clean(msb, P.offset(p), A.get(A.grow(t, U32.to_nat(dep)), P.index(p)))
     clean))))

def capacity_grows(+d: Nat) -> MNat.lt(C.bits(d), C.bits(1n+d)):
  %Equal.sym(Nat, C.bits(d), Lemmas.pow2(5n+d), C.bits_power(d)) : MNat.lt(_, C.bits(1n+d))
  %Equal.sym(Nat, C.bits(1n+d), Lemmas.pow2(5n+1n+d), C.bits_power(1n+d)) :
    MNat.lt(Lemmas.pow2(5n+d), _)
  Field.pow2_lt(5n+d, 5n+1n+d, MNat.lt_succ_self(5n+d))

def room_clean_old(active: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  sh: A.shape(U32.to_nat(dep), t),
  hd: MNat.lt(1n+U32.to_nat(dep), 32n),
  +hp: MNat.le(U32.to_nat(p), C.bits(U32.to_nat(dep))),
  e: {Nat.is_lt(U32.to_nat(p), C.bits(U32.to_nat(dep))) == active : Bool},
  clean: W.active_clean(active, msb, t, dep, p)) ->
  A.zero_after(1n+U32.to_nat(dep), A.grow(t, U32.to_nat(dep)), P.index(p)) &
  W.current_clean(msb, P.offset(p), A.get(A.grow(t, U32.to_nat(dep)), P.index(p))):
  match active:
    case True{}:
      (tail, current) = clean
      room_clean_inside(msb, t, dep, p, sh, hd, C.index_lt(U32.to_nat(dep), p, e), tail, current)
    case False{}:
      room_clean_end(msb, t, dep, p, sh, hd,
        C.index_at_capacity(U32.to_nat(dep), p,
          MNat.le_antisymm(U32.to_nat(p), C.bits(U32.to_nat(dep)), hp,
            MNat.le_of_not_lt(U32.to_nat(p), C.bits(U32.to_nat(dep)), e))))

def room_grow_valid(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32,
  shapes: A.shape(U32.to_nat(dep), t) & A.shape(U32.to_nat(dep), t),
  +hd: MNat.lt(U32.to_nat(dep), 28n),
  +hp: MNat.le(U32.to_nat(p), C.bits(U32.to_nat(dep))),
  e: {True{} == Nat.is_lt(C.bits(U32.to_nat(dep)), Nat.add(U32.to_nat(p), U32.to_nat(n))) : Bool},
  room: MNat.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), Lemmas.pow2(32n)),
  clean: W.active_clean(Nat.is_lt(U32.to_nat(p), C.bits(U32.to_nat(dep))), msb, t, dep, p)) ->
  W.valid(msb, W.room(True{}, W.State{t, dep, p})):
  (sh0, sh1) = shapes
  +inc = C.increment_nat(dep, hd)
  +next_depth = C.depth_bound(True{}, U32.to_nat(dep), U32.to_nat(p), U32.to_nat(n), e, hd, room)
  +inside = MNat.lt_of_le_of_lt(U32.to_nat(p), C.bits(U32.to_nat(dep)), C.bits(1n+U32.to_nat(dep)),
    hp, capacity_grows(U32.to_nat(dep)))
  room_valid(msb, t, dep, p, sh0, inc,
    (%Equal.sym(Nat, U32.to_nat((dep + 1 : U32)), 1n+U32.to_nat(dep), inc) : MNat.lt(_, 28n)
     next_depth),
    (%Equal.sym(Nat, U32.to_nat((dep + 1 : U32)), 1n+U32.to_nat(dep), inc) :
      MNat.le(U32.to_nat(p), C.bits(_))
     MNat.le_of_lt(U32.to_nat(p), C.bits(1n+U32.to_nat(dep)), inside)),
    (%Equal.sym(Nat, U32.to_nat((dep + 1 : U32)), 1n+U32.to_nat(dep), inc) :
      {Nat.is_lt(U32.to_nat(p), C.bits(_)) == True{} : Bool}
     inside),
    room_clean_old(Nat.is_lt(U32.to_nat(p), C.bits(U32.to_nat(dep))), msb, t, dep, p, sh1,
      MNat.lt_trans(1n+U32.to_nat(dep), 28n, 32n, next_depth, {==}), hp, {==}, clean))

def room_preserves.if(full: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32,
  e: {full == Nat.is_lt(C.bits(U32.to_nat(dep)), Nat.add(U32.to_nat(p), U32.to_nat(n))) : Bool},
  room: MNat.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), Lemmas.pow2(32n)),
  valid: W.valid(msb, W.State{t, dep, p})) ->
  W.valid(msb, W.room(full, W.State{t, dep, p})):
  match full:
    case False{}:
      valid
    case True{}:
      (sh, (hd, (hp, clean))) = valid
      room_grow_valid(msb, t, dep, p, n, A.shape_copy(U32.to_nat(dep), t, sh), hd, hp, e, room, clean)


def room_preserves(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32,
  width: MNat.le(U32.to_nat(n), 32n),
  +room: MNat.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), Lemmas.pow2(32n)),
  valid: W.valid(msb, W.State{t, dep, p})) ->
  W.valid(msb, W.room(U32.is_lt(U32.shln(1, U32.to_nat(dep)),
    ((p + n + 31) >> 5n : U32)), W.State{t, dep, p})):
  (sh, (+hd, (hp, clean))) = valid
  room_preserves.if(U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((p + n + 31) >> 5n : U32)),
    msb, t, dep, p, n,
    C.runtime_comparison(dep, p, n, MNat.lt_trans(U32.to_nat(dep), 28n, 32n, hd, {==}), room),
    room, (sh, (hd, (hp, clean))))

def room_covers(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32,
  width: MNat.le(U32.to_nat(n), 32n),
  room: MNat.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(n)), 31n), Lemmas.pow2(32n)),
  valid: W.valid(msb, W.State{t, dep, p})) ->
  MNat.le(Nat.add(U32.to_nat(p), U32.to_nat(n)),
    C.bits(U32.to_nat(Bool.pick(U32,
      U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((p + n + 31) >> 5n : U32)),
      (dep + 1 : U32), dep)))):
  (sh, (+hd, (hp, clean))) = valid
  C.runtime_covers(U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((p + n + 31) >> 5n : U32)),
    dep, p, n,
    C.runtime_comparison(dep, p, n, MNat.lt_trans(U32.to_nat(dep), 28n, 32n, hd, {==}), room),
    hd, hp, width)

def index_ne.if(test: Bool, +i: U32, +j: U32,
  h: MNat.lt(U32.to_nat(i), U32.to_nat(j)), e: {U32.is_eq(i, j) == test : Bool}) ->
  {U32.is_eq(i, j) == False{} : Bool}:
  match test:
    case False{}:
      e
    case True{}:
      Empty.absurd({U32.is_eq(i, j) == False{} : Bool},
        A.nat_lt_ne(U32.to_nat(i), U32.to_nat(j), h,
          MNat.eq_of_is_eq(U32.to_nat(i), U32.to_nat(j),
            Equal.trans(Bool, Nat.is_eq(U32.to_nat(i), U32.to_nat(j)), U32.is_eq(i, j), True{},
              Equal.sym(Bool, U32.is_eq(i, j), Nat.is_eq(U32.to_nat(i), U32.to_nat(j)),
                Lemmas.u32_is_eq_nat(i, j)), e))))

def index_ne(+i: U32, +j: U32, h: MNat.lt(U32.to_nat(i), U32.to_nat(j))) ->
  {U32.is_eq(i, j) == False{} : Bool}:
  index_ne.if(U32.is_eq(i, j), i, j, h, {==})

def transition_noncross(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  hn: MNat.le(U32.to_nat(n), 32n),
  facts: MNat.le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) &
    ({P.index((p + n : U32)) == P.index(p) : U32} &
    ({U32.to_nat(P.offset((p + n : U32))) == Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)) : Nat} &
     {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.sub(U32.to_nat((32 - n : U32)), U32.to_nat(P.offset(p))) : Nat})),
  tail: A.zero_after(U32.to_nat(dep), t, P.index(p)),
  clean: W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) ->
  A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32))) &
  W.current_clean(msb, P.offset((p + n : U32)), A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32)))):
  (gap, (index, (elsb, emsb))) = facts
  write_at_noncross_clean(msb, t, dep, p, n, v, hn, gap, index, elsb, emsb, tail, clean)

def transition_cross(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  sh: A.shape(U32.to_nat(dep), t),
  +hd: MNat.lt(U32.to_nat(dep), 32n),
  +hi: MNat.lt(U32.to_nat(P.index(p)), C.words(U32.to_nat(dep))),
  hj: MNat.lt(U32.to_nat(P.index((p + n : U32))), C.words(U32.to_nat(dep))),
  facts: {P.index((p + n : U32)) == (P.index(p) + 1 : U32) : U32} &
    ({U32.to_nat(P.offset((p + n : U32))) == Nat.sub(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) : Nat} &
     {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.add(U32.to_nat((32 - P.offset(p) : U32)), U32.to_nat((32 - n : U32))) : Nat}),
  tail: A.zero_after(U32.to_nat(dep), t, P.index(p))) ->
  A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32))) &
  W.current_clean(msb, P.offset((p + n : U32)), A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32)))):
  (+index, (elsb, emsb)) = facts
  write_at_cross_clean(msb, t, dep, p, n, v, sh, hd, hi,
    (%index : MNat.lt(U32.to_nat(_), C.words(U32.to_nat(dep)))
     hj),
    index_ne(P.index(p), (P.index(p) + 1 : U32), A.next_index_lt(U32.to_nat(dep), P.index(p), hd, hi)),
    index, elsb, emsb, tail)

def transition_clean.if(noncross: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  sh: A.shape(U32.to_nat(dep), t),
  hd: MNat.lt(U32.to_nat(dep), 32n),
  oldactive: MNat.lt(U32.to_nat(p), C.bits(U32.to_nat(dep))),
  nextactive: MNat.lt(U32.to_nat((p + n : U32)), C.bits(U32.to_nat(dep))),
  room: MNat.lt(Nat.add(U32.to_nat(p), U32.to_nat(n)), Lemmas.pow2(32n)),
  +hn: MNat.le(U32.to_nat(n), 32n),
  e: {Nat.is_lt(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n) == noncross : Bool},
  clean: A.zero_after(U32.to_nat(dep), t, P.index(p)) &
    W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) ->
  A.zero_after(U32.to_nat(dep), W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32))) &
  W.current_clean(msb, P.offset((p + n : U32)), A.get(W.put_parts(t, P.index(p), Bits.parts(msb, P.offset(p), n, v)), P.index((p + n : U32)))):
  match noncross:
    case True{}:
      (tail, current) = clean
      transition_noncross(msb, t, dep, p, n, v, hn, T.next_noncross(p, n, room, hn, e), tail, current)
    case False{}:
      (tail, current) = clean
      transition_cross(msb, t, dep, p, n, v, sh, hd,
        C.index_lt(U32.to_nat(dep), p, oldactive), C.index_lt(U32.to_nat(dep), (p + n : U32), nextactive),
        T.next_cross(p, n, room, hn,
          MNat.le_of_not_lt(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n, e)), tail)

def write_at_preserves.active(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  shapes: A.shape(U32.to_nat(dep), t) & A.shape(U32.to_nat(dep), t),
  +hd: MNat.lt(U32.to_nat(dep), 28n),
  bound: MNat.le(U32.to_nat((p + n : U32)), C.bits(U32.to_nat(dep))),
  +active: MNat.lt(U32.to_nat((p + n : U32)), C.bits(U32.to_nat(dep))),
  +room: MNat.lt(Nat.add(U32.to_nat(p), U32.to_nat(n)), Lemmas.pow2(32n)),
  hn: MNat.le(U32.to_nat(n), 32n),
  clean: W.active_clean(Nat.is_lt(U32.to_nat(p), C.bits(U32.to_nat(dep))), msb, t, dep, p)) ->
  W.valid(msb, W.write_at(msb, W.State{t, dep, p}, n, v)):
  (sh0, sh1) = shapes
  +oldactive = MNat.lt_of_le_of_lt(U32.to_nat(p), U32.to_nat((p + n : U32)), C.bits(U32.to_nat(dep)),
    P.le_right_rw(U32.to_nat(p), U32.to_nat((p + n : U32)), Nat.add(U32.to_nat(p), U32.to_nat(n)),
      P.position_add_nat(p, n, room), MNat.le_add_right(U32.to_nat(p), U32.to_nat(n))), active)
  write_at_valid_active(msb, t, dep, p, n, v, sh0, hd, bound, active,
    transition_clean.if(Nat.is_lt(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n),
      msb, t, dep, p, n, v, sh1, MNat.lt_trans(U32.to_nat(dep), 28n, 32n, hd, {==}),
      oldactive, active, room, hn, {==},
      (%oldactive :
        W.active_clean(_, msb, t, dep, p)
       clean)))

def write_at_preserves.if(active: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  valid: W.valid(msb, W.State{t, dep, p}),
  bound: MNat.le(U32.to_nat((p + n : U32)), C.bits(U32.to_nat(dep))),
  room: MNat.lt(Nat.add(U32.to_nat(p), U32.to_nat(n)), Lemmas.pow2(32n)),
  hn: MNat.le(U32.to_nat(n), 32n),
  e: {Nat.is_lt(U32.to_nat((p + n : U32)), C.bits(U32.to_nat(dep))) == active : Bool}) ->
  W.valid(msb, W.write_at(msb, W.State{t, dep, p}, n, v)):
  match active:
    case False{}:
      (sh, (hd, (hp, clean))) = valid
      write_at_valid_end(msb, t, dep, p, n, v, sh, hd, bound, e)
    case True{}:
      (sh, (hd, (hp, clean))) = valid
      write_at_preserves.active(msb, t, dep, p, n, v, A.shape_copy(U32.to_nat(dep), t, sh),
        hd, bound, e, room, hn, clean)

def write_at_preserves(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  valid: W.valid(msb, W.State{t, dep, p}),
  bound: MNat.le(U32.to_nat((p + n : U32)), C.bits(U32.to_nat(dep))),
  room: MNat.lt(Nat.add(U32.to_nat(p), U32.to_nat(n)), Lemmas.pow2(32n)),
  hn: MNat.le(U32.to_nat(n), 32n)) ->
  W.valid(msb, W.write_at(msb, W.State{t, dep, p}, n, v)):
  write_at_preserves.if(Nat.is_lt(U32.to_nat((p + n : U32)), C.bits(U32.to_nat(dep))),
    msb, t, dep, p, n, v, valid, bound, room, hn, {==})

def write_at_preserves_nat(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  valid: W.valid(msb, W.State{t, dep, p}),
  bound: MNat.le(Nat.add(U32.to_nat(p), U32.to_nat(n)), C.bits(U32.to_nat(dep))),
  +room: MNat.lt(Nat.add(U32.to_nat(p), U32.to_nat(n)), Lemmas.pow2(32n)),
  hn: MNat.le(U32.to_nat(n), 32n)) ->
  W.valid(msb, W.write_at(msb, W.State{t, dep, p}, n, v)):
  write_at_preserves(msb, t, dep, p, n, v, valid,
    P.le_left_rw(U32.to_nat((p + n : U32)), Nat.add(U32.to_nat(p), U32.to_nat(n)),
      C.bits(U32.to_nat(dep)), P.position_add_nat(p, n, room), bound),
    room, hn)

def current_clean_copy(msb: Bool, +offset: U32, +word: U32,
  h: W.current_clean(msb, offset, word)) ->
  W.current_clean(msb, offset, word) & W.current_clean(msb, offset, word):
  match msb:
    case False{}:
      +proof : {U32.and(word, U32.not(Bits.mask(offset))) == 0 : U32} = h
      (proof, proof)
    case True{}:
      +proof : {U32.and(Bytes.bswap(word), Bits.mask((32 - offset : U32))) == 0 : U32} = h
      (proof, proof)

def active_clean_copy.true(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  tails: A.zero_after(U32.to_nat(dep), t, P.index(p)) & A.zero_after(U32.to_nat(dep), t, P.index(p)),
  currents: W.current_clean(msb, P.offset(p), A.get(t, P.index(p))) &
    W.current_clean(msb, P.offset(p), A.get(t, P.index(p)))) ->
  W.active_clean(True{}, msb, t, dep, p) & W.active_clean(True{}, msb, t, dep, p):
  (tail0, tail1) = tails
  (current0, current1) = currents
  ((tail0, current0), (tail1, current1))

def active_clean_copy(active: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  h: W.active_clean(active, msb, t, dep, p)) ->
  W.active_clean(active, msb, t, dep, p) & W.active_clean(active, msb, t, dep, p):
  match active:
    case False{}:
      (Unit{}, Unit{})
    case True{}:
      (tail, current) = h
      active_clean_copy.true(msb, t, dep, p, zero_after_copy(U32.to_nat(dep), t, P.index(p), tail),
        current_clean_copy(msb, P.offset(p), A.get(t, P.index(p)), current))

def valid_copy.of(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32,
  shapes: A.shape(U32.to_nat(dep), t) & A.shape(U32.to_nat(dep), t),
  +hd: MNat.lt(U32.to_nat(dep), 28n),
  +hp: MNat.le(U32.to_nat(p), W.capacity(U32.to_nat(dep))),
  cleans: W.active_clean(Nat.is_lt(U32.to_nat(p), W.capacity(U32.to_nat(dep))), msb, t, dep, p) &
    W.active_clean(Nat.is_lt(U32.to_nat(p), W.capacity(U32.to_nat(dep))), msb, t, dep, p)) ->
  W.valid(msb, W.State{t, dep, p}) & W.valid(msb, W.State{t, dep, p}):
  (sh0, sh1) = shapes
  (clean0, clean1) = cleans
  ((sh0, (hd, (hp, clean0))), (sh1, (hd, (hp, clean1))))

def valid_copy(+msb: Bool, +s: W.State, h: W.valid(msb, s)) ->
  W.valid(msb, s) & W.valid(msb, s):
  match s:
    case W.State{+t, +dep, +p}:
      (sh, (hd, (hp, clean))) = h
      valid_copy.of(msb, t, dep, p, A.shape_copy(U32.to_nat(dep), t, sh), hd, hp,
        active_clean_copy(Nat.is_lt(U32.to_nat(p), W.capacity(U32.to_nat(dep))), msb, t, dep, p, clean))

def room_state(+full: Bool, +t: A.Tree, +dep: U32, p: U32) -> W.State:
  W.State{Bool.pick(A.Tree, full, A.grow(t, U32.to_nat(dep)), t),
    Bool.pick(U32, full, (dep + 1 : U32), dep), p}

def room_state_eta(full: Bool, +t: A.Tree, +dep: U32, +p: U32) ->
  {W.room(full, W.State{t, dep, p}) == room_state(full, t, dep, p) : W.State}:
  match full:
    case False{}:
      {==}
    case True{}:
      {==}

def write_room_preserves(+full: Bool, +msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n: U32, +v: U32,
  valid: W.valid(msb, W.room(full, W.State{t, dep, p})),
  bound: MNat.le(Nat.add(U32.to_nat(p), U32.to_nat(n)),
    C.bits(U32.to_nat(Bool.pick(U32, full, (dep + 1 : U32), dep)))),
  room: MNat.lt(Nat.add(U32.to_nat(p), U32.to_nat(n)), Lemmas.pow2(32n)),
  width: MNat.le(U32.to_nat(n), 32n)) ->
  W.valid(msb, W.write_at(msb, W.room(full, W.State{t, dep, p}), n, v)):
  %Equal.sym(W.State, W.room(full, W.State{t, dep, p}), room_state(full, t, dep, p),
    room_state_eta(full, t, dep, p)) : W.valid(msb, W.write_at(msb, _, n, v))
  write_at_preserves_nat(msb, Bool.pick(A.Tree, full, A.grow(t, U32.to_nat(dep)), t),
    Bool.pick(U32, full, (dep + 1 : U32), dep), p, n, v,
    (%room_state_eta(full, t, dep, p) : W.valid(msb, _)
     valid),
    bound, room, width)

def clamped_width(+n: U32) -> MNat.le(U32.to_nat(U32.min(n, 32)), 32n):
  %Equal.sym(Nat, U32.to_nat(U32.min(n, 32)), Nat.min(U32.to_nat(n), 32n),
    MU32.u32_min_to_nat(n, 32)) : MNat.le(_, 32n)
  MNat.min_le_right(U32.to_nat(n), 32n)

def write_preserves.of(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n0: U32, +v: U32,
  +room: MNat.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(U32.min(n0, 32))), 31n), Lemmas.pow2(32n)),
  valids: W.valid(msb, W.State{t, dep, p}) & W.valid(msb, W.State{t, dep, p})) ->
  W.valid(msb, W.write(msb, W.State{t, dep, p}, n0, v)):
  (valid0, valid1) = valids
  +n = U32.min(n0, 32)
  +full = U32.is_lt(U32.shln(1, U32.to_nat(dep)), ((p + n + 31) >> 5n : U32))
  write_room_preserves(full, msb, t, dep, p, n, v,
    room_preserves(msb, t, dep, p, n, clamped_width(n0), room, valid0),
    room_covers(msb, t, dep, p, n, clamped_width(n0), room, valid1),
    C.end_bound(U32.to_nat(p), U32.to_nat(n), room), clamped_width(n0))

def write_preserves(+msb: Bool, +t: A.Tree, +dep: U32, +p: U32, +n0: U32, +v: U32,
  room: MNat.lt(Nat.add(Nat.add(U32.to_nat(p), U32.to_nat(U32.min(n0, 32))), 31n), Lemmas.pow2(32n)),
  valid: W.valid(msb, W.State{t, dep, p})) ->
  W.valid(msb, W.write(msb, W.State{t, dep, p}, n0, v)):
  write_preserves.of(msb, t, dep, p, n0, v, room, valid_copy(msb, W.State{t, dep, p}, valid))

# Transport the state before adding its large bound: https://github.com/bendlang/bend/issues/1071.
def write_state_transport(+msb: Bool, +s: W.State, +n0: U32, +v: U32,
  valid: W.valid(msb, W.write(msb, W.State{Prefix.image(s), Prefix.depth(s), W.position(s)}, n0, v))) ->
  W.valid(msb, W.write(msb, s, n0, v)):
  %Equal.sym(W.State, s, W.State{Prefix.image(s), Prefix.depth(s), W.position(s)}, Prefix.state_eta(s)) :
    W.valid(msb, W.write(msb, _, n0, v))
  valid

def write_preserves_state(+msb: Bool, +s: W.State, +n0: U32, +v: U32,
  room: MNat.lt(Nat.add(Nat.add(U32.to_nat(W.position(s)), U32.to_nat(U32.min(n0, 32))), 31n), Lemmas.pow2(32n)),
  valid: W.valid(msb, s)) ->
  W.valid(msb, W.write(msb, s, n0, v)):
  write_state_transport(msb, s, n0, v,
    write_preserves(msb, Prefix.image(s), Prefix.depth(s), W.position(s), n0, v, room,
      Prefix.valid_eta(msb, s, valid)))

def prefix_room_step(+p: Nat, +n: Nat, +tail: Nat, +limit: Nat,
  h: MNat.lt(Nat.add(Nat.add(p, Nat.add(n, tail)), 31n), limit)) ->
  MNat.lt(Nat.add(Nat.add(p, n), 31n), limit):
  MNat.lt_of_le_of_lt(Nat.add(Nat.add(p, n), 31n), Nat.add(Nat.add(p, Nat.add(n, tail)), 31n), limit,
    MNat.add_le_add_right(Nat.add(p, n), Nat.add(p, Nat.add(n, tail)), 31n,
      MNat.add_le_add_left(n, Nat.add(n, tail), p, MNat.le_add_right(n, tail))), h)

def prefix_room_next(+p: Nat, +next: Nat, +n: Nat, +tail: Nat, +limit: Nat,
  step: {next == Nat.add(p, n) : Nat},
  h: MNat.lt(Nat.add(Nat.add(p, Nat.add(n, tail)), 31n), limit)) ->
  MNat.lt(Nat.add(Nat.add(next, tail), 31n), limit):
  Lemmas.lt_rw(Nat.add(Nat.add(next, tail), 31n), Nat.add(Nat.add(p, Nat.add(n, tail)), 31n), limit,
    Equal.cong(Nat, Nat, x => Nat.add(x, 31n), Nat.add(next, tail), Nat.add(p, Nat.add(n, tail)),
      W.append_position(p, next, n, tail, step)), h)


# Keep the induction limit abstract while refining its prefix: https://github.com/bendlang/bend/issues/1071.
def room_limit(+p: Nat, +n: Nat, +limit: Nat,
  h: MNat.lt(Nat.add(Nat.add(p, n), 31n), limit),
  le: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.lt(Nat.add(Nat.add(p, n), 31n), Lemmas.pow2(32n)):
  MNat.lt_of_lt_of_le(Nat.add(Nat.add(p, n), 31n), limit, Lemmas.pow2(32n), h, le)

def puts_preserves_bound(+fs: List<&2, Laws.F>, +msb: Bool, +s: W.State, +limit: Nat,
  +limit_ok: MNat.le(limit, Lemmas.pow2(32n)),
  valid: W.valid(msb, s),
  +room: MNat.lt(Nat.add(Nat.add(U32.to_nat(W.position(s)), Laws.prefix_bits(fs)), 31n), limit)) ->
  W.valid(msb, W.puts(fs, msb, s)):
  match fs:
    case Nil{}:
      valid
    case Con{Laws.F{+n, +v}, +tail}:
      +p = U32.to_nat(W.position(s))
      +width = U32.to_nat(U32.min(n, 32))
      +next = W.write(msb, s, n, v)
      +headroom = prefix_room_step(p, width, Laws.prefix_bits(tail), limit, room)
      +step_room = room_limit(p, width, limit, headroom, limit_ok)
      puts_preserves_bound(tail, msb, next, limit, limit_ok,
        write_preserves_state(msb, s, n, v, step_room, valid),
        prefix_room_next(p, U32.to_nat(W.position(next)), width, Laws.prefix_bits(tail), limit,
          W.write_position_nat(msb, s, n, v, C.end_bound(p, width, step_room)), room))

def puts_preserves(+fs: List<&2, Laws.F>, +msb: Bool, +s: W.State,
  valid: W.valid(msb, s),
  room: MNat.lt(Nat.add(Nat.add(U32.to_nat(W.position(s)), Laws.prefix_bits(fs)), 31n), Lemmas.pow2(32n))) ->
  W.valid(msb, W.puts(fs, msb, s)):
  puts_preserves_bound(fs, msb, s, Lemmas.pow2(32n), MNat.le_refl(Lemmas.pow2(32n)), valid, room)
