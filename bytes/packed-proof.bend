# The packed byte memory invariant, linked to the actual Bytes.peek / Bytes.poke.
import Base
import ./bytes.bend as Bytes
import ./array-proof.bend as ArrayModel
import ./word-proof.bend as WordModel
import ../lemmas/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool

def slot(+i: U32) -> Nat:
  U32.to_nat(U32.shrn(i, 2n))

def lane(+i: U32) -> Nat:
  U32.to_nat(U32.and(i, 3))

def byte_at(+l: List<&2, U32>, +i: U32) -> U32:
  WordModel.read(ArrayModel.nth(l, slot(i)), lane(i))

def write_at(+l: List<&2, U32>, +i: U32, +v: U32) -> List<&2, U32>:
  ArrayModel.upd(l, slot(i), WordModel.write(ArrayModel.nth(l, slot(i)), v, lane(i)))

# Capacity is in bytes: pow2(d) * 4, with the recursive factor first.
def capacity(+d: Nat) -> Nat:
  Nat.mul(Lemmas.pow2(d), 4n)

def byte_lt16(+d: Nat, +i: U32, hd: MNat.lt(d, 3n), hi: MNat.lt(U32.to_nat(i), capacity(d))) -> MNat.lt(U32.to_nat(i), 16n):
  match d:
    case 0n:
      ArrayModel.lt_le_trans(U32.to_nat(i), 4n, 16n, hi, {==})
    case 1n:
      ArrayModel.lt_le_trans(U32.to_nat(i), 8n, 16n, hi, {==})
    case 2n:
      hi
    case 3n+p:
      Empty.absurd(MNat.lt(U32.to_nat(i), 16n), MNat.lt_zero(p)(hd))

def Layout(+i: U32) -> Type:
  {Nat.mul(lane(i), 8n) == Bytes.shift(i) : Nat}
  & (MNat.lt(lane(i), 4n)
  & {Nat.add(Nat.mul(slot(i), 4n), lane(i)) == U32.to_nat(i) : Nat})

def layout_at(n: Nat, +i: U32, e: {n == U32.to_nat(i) : Nat}, h: MNat.lt(n, 16n)) -> Layout(i):
  match n:
    case 0n:
      %Lemmas.u32_to_nat_inj(0, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 1n:
      %Lemmas.u32_to_nat_inj(1, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 2n:
      %Lemmas.u32_to_nat_inj(2, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 3n:
      %Lemmas.u32_to_nat_inj(3, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 4n:
      %Lemmas.u32_to_nat_inj(4, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 5n:
      %Lemmas.u32_to_nat_inj(5, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 6n:
      %Lemmas.u32_to_nat_inj(6, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 7n:
      %Lemmas.u32_to_nat_inj(7, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 8n:
      %Lemmas.u32_to_nat_inj(8, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 9n:
      %Lemmas.u32_to_nat_inj(9, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 10n:
      %Lemmas.u32_to_nat_inj(10, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 11n:
      %Lemmas.u32_to_nat_inj(11, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 12n:
      %Lemmas.u32_to_nat_inj(12, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 13n:
      %Lemmas.u32_to_nat_inj(13, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 14n:
      %Lemmas.u32_to_nat_inj(14, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 15n:
      %Lemmas.u32_to_nat_inj(15, i, e) : Layout(_)
      ({==}, ({==}, {==}))
    case 16n+p:
      Empty.absurd(Layout(i), MNat.lt_zero(p)(h))

def layout(+i: U32, h: MNat.lt(U32.to_nat(i), 16n)) -> Layout(i):
  layout_at(U32.to_nat(i), i, {==}, h)

def shift_exact.of(-i: U32, r: Layout(i)) -> {Nat.mul(lane(i), 8n) == Bytes.shift(i) : Nat}:
  (hs, rest) = r
  hs

def shift_exact(+i: U32, h: MNat.lt(U32.to_nat(i), 16n)) -> {Nat.mul(lane(i), 8n) == Bytes.shift(i) : Nat}:
  shift_exact.of(i, layout(i, h))

def lane_bound.of(-i: U32, r: Layout(i)) -> MNat.lt(lane(i), 4n):
  (hs, rest) = r
  (hl, he) = rest
  hl

def lane_bound(+i: U32, h: MNat.lt(U32.to_nat(i), 16n)) -> MNat.lt(lane(i), 4n):
  lane_bound.of(i, layout(i, h))

def address_split.of(-i: U32, r: Layout(i)) -> {Nat.add(Nat.mul(slot(i), 4n), lane(i)) == U32.to_nat(i) : Nat}:
  (hs, rest) = r
  (hl, he) = rest
  he

def address_split(+i: U32, h: MNat.lt(U32.to_nat(i), 16n)) -> {Nat.add(Nat.mul(slot(i), 4n), lane(i)) == U32.to_nat(i) : Nat}:
  address_split.of(i, layout(i, h))

def scale_bound(+q: Nat, +r: Nat, +c: Nat, h: MNat.lt(Nat.add(Nat.mul(q, 4n), r), Nat.mul(c, 4n))) -> MNat.lt(q, c):
  match q:
    case 0n:
      match c:
        case 0n:
          Empty.absurd(MNat.lt(0n, 0n), MNat.lt_zero(r)(h))
        case 1n+s:
          {==}
    case 1n++p:
      match c:
        case 0n:
          Empty.absurd(MNat.lt(1n+p, 0n), MNat.lt_zero(Nat.add(Nat.mul(1n+p, 4n), r))(h))
        case 1n++s:
          scale_bound(p, r, s, h)

def slot_bound(+d: Nat, +i: U32, +hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(i), capacity(d))) -> MNat.lt(slot(i), Lemmas.pow2(d)):
  scale_bound(slot(i), lane(i), Lemmas.pow2(d),
    %Equal.sym(Nat, Nat.add(Nat.mul(slot(i), 4n), lane(i)), U32.to_nat(i), address_split(i, byte_lt16(d, i, hd, hi))) : MNat.lt(_, capacity(d))
    hi)

def peek_model(+d: Nat, +l: List<&2, U32>, +i: U32, +hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(i), capacity(d))) -> {Bytes.peek(ArrayModel.build(d, l), i) == (ArrayModel.build(d, l), byte_at(l, i)) : Array<U32> & U32}:
  %Equal.sym(Array<U32> & U32, Array.get(U32, ArrayModel.build(d, l), U32.shrn(i, 2n)), (ArrayModel.build(d, l), ArrayModel.nth(l, slot(i))), ArrayModel.get_small(d, l, U32.shrn(i, 2n), hd, slot_bound(d, i, hd, hi))) : {Bytes.peek.of(Bytes.shift(i), _) == (ArrayModel.build(d, l), byte_at(l, i)) : Array<U32> & U32}
  %shift_exact(i, byte_lt16(d, i, hd, hi)) : {Bytes.peek.of(_, (ArrayModel.build(d, l), ArrayModel.nth(l, slot(i)))) == (ArrayModel.build(d, l), byte_at(l, i)) : Array<U32> & U32}
  {==}

def poke_model(+d: Nat, +l: List<&2, U32>, +i: U32, +v: U32, +hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(i), capacity(d)), hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l))) -> {Bytes.poke(ArrayModel.build(d, l), i, v) == ArrayModel.build(d, write_at(l, i, v)) : Array<U32>}:
  %Equal.sym(Array<U32> & U32, Array.get(U32, ArrayModel.build(d, l), U32.shrn(i, 2n)), (ArrayModel.build(d, l), ArrayModel.nth(l, slot(i))), ArrayModel.get_small(d, l, U32.shrn(i, 2n), hd, slot_bound(d, i, hd, hi))) : {Bytes.poke.of(i, v, _) == ArrayModel.build(d, write_at(l, i, v)) : Array<U32>}
  %shift_exact(i, byte_lt16(d, i, hd, hi)) : {Array.set(U32, ArrayModel.build(d, l), U32.shrn(i, 2n), U32.or(U32.and(ArrayModel.nth(l, slot(i)), U32.xor(U32.shln(255, _), 4294967295)), U32.shln(U32.and(v, 255), _))) == ArrayModel.build(d, write_at(l, i, v)) : Array<U32>}
  ArrayModel.set_small(d, l, U32.shrn(i, 2n), WordModel.write(ArrayModel.nth(l, slot(i)), v, lane(i)), hd, slot_bound(d, i, hd, hi), hl)

def write_length(+l: List<&2, U32>, +i: U32, +v: U32) -> {ArrayModel.len(write_at(l, i, v)) == ArrayModel.len(l) : Nat}:
  ArrayModel.len_upd(l, slot(i), WordModel.write(ArrayModel.nth(l, slot(i)), v, lane(i)))

def byte_write_same(+l: List<&2, U32>, +i: U32, +v: U32, hs: MNat.lt(slot(i), ArrayModel.len(l)), hl: MNat.lt(lane(i), 4n)) -> {byte_at(write_at(l, i, v), i) == U32.and(v, 255) : U32}:
  %Equal.sym(U32, ArrayModel.nth(write_at(l, i, v), slot(i)), WordModel.write(ArrayModel.nth(l, slot(i)), v, lane(i)), ArrayModel.nth_upd_same(l, slot(i), WordModel.write(ArrayModel.nth(l, slot(i)), v, lane(i)), hs)) : {WordModel.read(_, lane(i)) == U32.and(v, 255) : U32}
  WordModel.read_write(ArrayModel.nth(l, slot(i)), v, lane(i), hl)

def nat_eq_true(+a: Nat, +b: Nat, h: {Nat.is_eq(a, b) == True{} : Bool}) -> {a == b : Nat}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+q:
      Empty.absurd({0n == 1n+q : Nat}, MBool.false_ne_true()(h))
    case 1n+p 0n:
      Empty.absurd({1n+p == 0n : Nat}, MBool.false_ne_true()(h))
    case 1n++p 1n++q:
      %nat_eq_true(p, q, h) : {1n+p == 1n+_ : Nat}
      {==}

def address_inj(+i: U32, +j: U32, hi: MNat.lt(U32.to_nat(i), 16n), hj: MNat.lt(U32.to_nat(j), 16n), es: {slot(i) == slot(j) : Nat}, el: {lane(i) == lane(j) : Nat}) -> {i == j : U32}:
  Lemmas.u32_to_nat_inj(i, j,
    %address_split(i, hi) : {_ == U32.to_nat(j) : Nat}
    %address_split(j, hj) : {Nat.add(Nat.mul(slot(i), 4n), lane(i)) == _ : Nat}
    %es : {Nat.add(Nat.mul(slot(i), 4n), lane(i)) == Nat.add(Nat.mul(_, 4n), lane(j)) : Nat}
    %el : {Nat.add(Nat.mul(slot(i), 4n), lane(i)) == Nat.add(Nat.mul(slot(i), 4n), _) : Nat}
    {==})

def byte_write_other.if(same: Bool, +l: List<&2, U32>, +i: U32, +j: U32, +v: U32, +hi: MNat.lt(U32.to_nat(i), 16n), +hj: MNat.lt(U32.to_nat(j), 16n), hs: MNat.lt(slot(i), ArrayModel.len(l)), ne: {i != j : U32}, e: {same == Nat.is_eq(slot(i), slot(j)) : Bool}) -> {byte_at(write_at(l, i, v), j) == byte_at(l, j) : U32}:
  match same:
    case False{}:
      %Equal.sym(U32, ArrayModel.nth(write_at(l, i, v), slot(j)), ArrayModel.nth(l, slot(j)), ArrayModel.nth_upd_other(l, slot(i), slot(j), WordModel.write(ArrayModel.nth(l, slot(i)), v, lane(i)), Equal.sym(Bool, False{}, Nat.is_eq(slot(i), slot(j)), e))) : {WordModel.read(_, lane(j)) == byte_at(l, j) : U32}
      {==}
    case True{}:
      +es = nat_eq_true(slot(i), slot(j), Equal.sym(Bool, True{}, Nat.is_eq(slot(i), slot(j)), e))
      %es : {WordModel.read(ArrayModel.nth(write_at(l, i, v), _), lane(j)) == WordModel.read(ArrayModel.nth(l, _), lane(j)) : U32}
      %Equal.sym(U32, ArrayModel.nth(write_at(l, i, v), slot(i)), WordModel.write(ArrayModel.nth(l, slot(i)), v, lane(i)), ArrayModel.nth_upd_same(l, slot(i), WordModel.write(ArrayModel.nth(l, slot(i)), v, lane(i)), hs)) : {WordModel.read(_, lane(j)) == WordModel.read(ArrayModel.nth(l, slot(i)), lane(j)) : U32}
      WordModel.read_write_other(ArrayModel.nth(l, slot(i)), v, lane(i), lane(j), lane_bound(i, hi), lane_bound(j, hj), el => ne(address_inj(i, j, hi, hj, es, el)))

def byte_write_other(+l: List<&2, U32>, +i: U32, +j: U32, +v: U32, hi: MNat.lt(U32.to_nat(i), 16n), hj: MNat.lt(U32.to_nat(j), 16n), hs: MNat.lt(slot(i), ArrayModel.len(l)), ne: {i != j : U32}) -> {byte_at(write_at(l, i, v), j) == byte_at(l, j) : U32}:
  byte_write_other.if(Nat.is_eq(slot(i), slot(j)), l, i, j, v, hi, hj, hs, ne, {==})

def peek_poke_same(+d: Nat, +l: List<&2, U32>, +i: U32, +v: U32, +hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(i), capacity(d)), +hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l))) -> {Bytes.peek(Bytes.poke(ArrayModel.build(d, l), i, v), i) == (Bytes.poke(ArrayModel.build(d, l), i, v), Bytes.b8(v)) : Array<U32> & U32}:
  %Equal.sym(Array<U32>, Bytes.poke(ArrayModel.build(d, l), i, v), ArrayModel.build(d, write_at(l, i, v)), poke_model(d, l, i, v, hd, hi, hl)) : {Bytes.peek(_, i) == (_, Bytes.b8(v)) : Array<U32> & U32}
  %byte_write_same(l, i, v, ArrayModel.lt_le_trans(slot(i), Lemmas.pow2(d), ArrayModel.len(l), slot_bound(d, i, hd, hi), hl), lane_bound(i, byte_lt16(d, i, hd, hi))) : {Bytes.peek(ArrayModel.build(d, write_at(l, i, v)), i) == (ArrayModel.build(d, write_at(l, i, v)), _) : Array<U32> & U32}
  peek_model(d, write_at(l, i, v), i, hd, hi)

def peek_poke_other(+d: Nat, +l: List<&2, U32>, +i: U32, +j: U32, +v: U32, +hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(i), capacity(d)), +hj: MNat.lt(U32.to_nat(j), capacity(d)), +hl: MNat.le(Lemmas.pow2(d), ArrayModel.len(l)), ne: {i != j : U32}) -> {Bytes.peek(Bytes.poke(ArrayModel.build(d, l), i, v), j) == (Bytes.poke(ArrayModel.build(d, l), i, v), byte_at(l, j)) : Array<U32> & U32}:
  %Equal.sym(Array<U32>, Bytes.poke(ArrayModel.build(d, l), i, v), ArrayModel.build(d, write_at(l, i, v)), poke_model(d, l, i, v, hd, hi, hl)) : {Bytes.peek(_, j) == (_, byte_at(l, j)) : Array<U32> & U32}
  %byte_write_other(l, i, j, v, byte_lt16(d, i, hd, hi), byte_lt16(d, j, hd, hj), ArrayModel.lt_le_trans(slot(i), Lemmas.pow2(d), ArrayModel.len(l), slot_bound(d, i, hd, hi), hl), ne) : {Bytes.peek(ArrayModel.build(d, write_at(l, i, v)), j) == (ArrayModel.build(d, write_at(l, i, v)), _) : Array<U32> & U32}
  peek_model(d, write_at(l, i, v), j, hd, hj)
