import Base
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/u32.bend as MU32
import ./position-proof.bend as P
import ./capacity-proof.bend as C

# Natural arithmetic stays separate from concrete words (bendlang/bend#1071).
def gap_nat(+s: U32, h: MNat.le(U32.to_nat(s), 32n)) ->
  {U32.to_nat((32 - s : U32)) == Nat.sub(32n, U32.to_nat(s)) : Nat}:
  Lemmas.u32_sub_nat(32, s, h)

def offset_gap_nat(+p: U32) ->
  {U32.to_nat((32 - P.offset(p) : U32)) == Nat.sub(32n, U32.to_nat(P.offset(p))) : Nat}:
  gap_nat(P.offset(p), MNat.le_trans(U32.to_nat(P.offset(p)), 31n, 32n, P.offset_bound(p), {==}))

def noncross_room_nat(+s: Nat, +n: Nat, h: MNat.lt(Nat.add(s, n), 32n)) ->
  MNat.le(n, Nat.sub(32n, s)):
  %MNat.add_sub_cancel_left(s, n) : MNat.le(_, Nat.sub(32n, s))
  MNat.sub_le_sub_right(Nat.add(s, n), 32n, MNat.le_of_lt(Nat.add(s, n), 32n, h), s)

def noncross_room(+p: U32, +n: U32,
  h: MNat.lt(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n)) ->
  MNat.le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))):
  P.le_right_rw(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32)),
    Nat.sub(32n, U32.to_nat(P.offset(p))), offset_gap_nat(p),
    noncross_room_nat(U32.to_nat(P.offset(p)), U32.to_nat(n), h))

def noncross_gap_nat(+s: Nat, +n: Nat) ->
  {Nat.sub(32n, Nat.add(s, n)) == Nat.sub(Nat.sub(32n, n), s) : Nat}:
  Equal.trans(Nat, Nat.sub(32n, Nat.add(s, n)), Nat.sub(32n, Nat.add(n, s)),
    Nat.sub(Nat.sub(32n, n), s),
    Equal.cong(Nat, Nat, x => Nat.sub(32n, x), Nat.add(s, n), Nat.add(n, s), MNat.add_comm(s, n)),
    Equal.sym(Nat, Nat.sub(Nat.sub(32n, n), s), Nat.sub(32n, Nat.add(n, s)), MNat.sub_sub(32n, n, s)))

def noncross_gap(+p: U32, +n: U32, hn: MNat.le(U32.to_nat(n), 32n),
  e: {U32.to_nat(P.offset((p + n : U32))) == Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)) : Nat}) ->
  {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.sub(U32.to_nat((32 - n : U32)), U32.to_nat(P.offset(p))) : Nat}:
  %Equal.sym(Nat, U32.to_nat((32 - n : U32)), Nat.sub(32n, U32.to_nat(n)), gap_nat(n, hn)) : {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.sub(_, U32.to_nat(P.offset(p))) : Nat}
  Equal.trans(Nat, U32.to_nat((32 - P.offset((p + n : U32)) : U32)),
    Nat.sub(32n, Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n))),
    Nat.sub(Nat.sub(32n, U32.to_nat(n)), U32.to_nat(P.offset(p))),
    Equal.trans(Nat, U32.to_nat((32 - P.offset((p + n : U32)) : U32)),
      Nat.sub(32n, U32.to_nat(P.offset((p + n : U32)))),
      Nat.sub(32n, Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n))), offset_gap_nat((p + n : U32)),
      Equal.cong(Nat, Nat, x => Nat.sub(32n, x), U32.to_nat(P.offset((p + n : U32))),
        Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), e)),
    noncross_gap_nat(U32.to_nat(P.offset(p)), U32.to_nat(n)))

def cross_end_nat(+s: Nat, +n: Nat, hs: MNat.le(s, 32n)) ->
  {Nat.sub(Nat.add(s, n), 32n) == Nat.sub(n, Nat.sub(32n, s)) : Nat}:
  %MNat.add_sub_of_le(s, 32n, hs) : {Nat.sub(Nat.add(s, n), _) == Nat.sub(n, Nat.sub(32n, s)) : Nat}
  MNat.add_sub_add_left(s, n, Nat.sub(32n, s))

def cross_room_nat(+s: Nat, +n: Nat, h: MNat.le(32n, Nat.add(s, n))) ->
  MNat.le(Nat.sub(32n, s), n):
  %MNat.add_sub_cancel_left(s, n) : MNat.le(Nat.sub(32n, s), _)
  MNat.sub_le_sub_right(32n, Nat.add(s, n), h, s)

def complement_nat(+g: Nat, +n: Nat, hg: MNat.le(g, n), hn: MNat.le(n, 32n)) ->
  {Nat.sub(32n, Nat.sub(n, g)) == Nat.add(g, Nat.sub(32n, n)) : Nat}:
  %MNat.add_sub_of_le(n, 32n, hn) : {Nat.sub(_, Nat.sub(n, g)) == Nat.add(g, Nat.sub(32n, n)) : Nat}
  %MNat.sub_add_cancel(n, g, hg) : {Nat.sub(Nat.add(_, Nat.sub(32n, n)), Nat.sub(n, g)) == Nat.add(g, Nat.sub(32n, n)) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.add(Nat.sub(n, g), g), Nat.sub(32n, n)),
    Nat.add(Nat.sub(n, g), Nat.add(g, Nat.sub(32n, n))),
    MNat.add_assoc(Nat.sub(n, g), g, Nat.sub(32n, n))) :
    {Nat.sub(_, Nat.sub(n, g)) == Nat.add(g, Nat.sub(32n, n)) : Nat}
  MNat.add_sub_cancel_left(Nat.sub(n, g), Nat.add(g, Nat.sub(32n, n)))

def cross_gap_nat(+s: Nat, +n: Nat, +hs: MNat.le(s, 32n), hn: MNat.le(n, 32n),
  h: MNat.le(32n, Nat.add(s, n))) ->
  {Nat.sub(32n, Nat.sub(Nat.add(s, n), 32n)) == Nat.add(Nat.sub(32n, s), Nat.sub(32n, n)) : Nat}:
  %Equal.sym(Nat, Nat.sub(Nat.add(s, n), 32n), Nat.sub(n, Nat.sub(32n, s)), cross_end_nat(s, n, hs)) : {Nat.sub(32n, _) == Nat.add(Nat.sub(32n, s), Nat.sub(32n, n)) : Nat}
  complement_nat(Nat.sub(32n, s), n, cross_room_nat(s, n, h), hn)

def cross_end(+p: U32, +n: U32,
  e: {U32.to_nat(P.offset((p + n : U32))) == Nat.sub(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n) : Nat}) ->
  {U32.to_nat(P.offset((p + n : U32))) == Nat.sub(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) : Nat}:
  %Equal.sym(Nat, U32.to_nat((32 - P.offset(p) : U32)), Nat.sub(32n, U32.to_nat(P.offset(p))), offset_gap_nat(p)) : {U32.to_nat(P.offset((p + n : U32))) == Nat.sub(U32.to_nat(n), _) : Nat}
  Equal.trans(Nat, U32.to_nat(P.offset((p + n : U32))),
    Nat.sub(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n),
    Nat.sub(U32.to_nat(n), Nat.sub(32n, U32.to_nat(P.offset(p)))), e,
    cross_end_nat(U32.to_nat(P.offset(p)), U32.to_nat(n),
      MNat.le_trans(U32.to_nat(P.offset(p)), 31n, 32n, P.offset_bound(p), {==})))

def cross_gap(+p: U32, +n: U32, +hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(32n, Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n))),
  e: {U32.to_nat(P.offset((p + n : U32))) == Nat.sub(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n) : Nat}) ->
  {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.add(U32.to_nat((32 - P.offset(p) : U32)), U32.to_nat((32 - n : U32))) : Nat}:
  %Equal.sym(Nat, U32.to_nat((32 - P.offset(p) : U32)), Nat.sub(32n, U32.to_nat(P.offset(p))), offset_gap_nat(p)) : {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.add(_, U32.to_nat((32 - n : U32))) : Nat}
  %Equal.sym(Nat, U32.to_nat((32 - n : U32)), Nat.sub(32n, U32.to_nat(n)), gap_nat(n, hn)) : {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.add(Nat.sub(32n, U32.to_nat(P.offset(p))), _) : Nat}
  Equal.trans(Nat, U32.to_nat((32 - P.offset((p + n : U32)) : U32)),
    Nat.sub(32n, Nat.sub(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n)),
    Nat.add(Nat.sub(32n, U32.to_nat(P.offset(p))), Nat.sub(32n, U32.to_nat(n))),
    Equal.trans(Nat, U32.to_nat((32 - P.offset((p + n : U32)) : U32)),
      Nat.sub(32n, U32.to_nat(P.offset((p + n : U32)))),
      Nat.sub(32n, Nat.sub(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n)),
      offset_gap_nat((p + n : U32)), Equal.cong(Nat, Nat, x => Nat.sub(32n, x),
        U32.to_nat(P.offset((p + n : U32))), Nat.sub(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n), e)),
    cross_gap_nat(U32.to_nat(P.offset(p)), U32.to_nat(n),
      MNat.le_trans(U32.to_nat(P.offset(p)), 31n, 32n, P.offset_bound(p), {==}), hn, h))

# Keep the increment and large limit opaque: https://github.com/bendlang/bend/issues/1071.
def successor_bound(+a: Nat, +b: Nat, +limit: Nat,
  e: {b == 1n+a : Nat}, h: MNat.lt(b, limit)) -> MNat.lt(1n+a, limit):
  Lemmas.lt_rw(1n+a, b, limit, Equal.sym(Nat, b, 1n+a, e), h)

# The next quotient itself witnesses that incrementing the old index fits U32.
def cross_index(+p: U32, +n: U32,
  +e: {U32.to_nat(P.index((p + n : U32))) == 1n+U32.to_nat(P.index(p)) : Nat}) ->
  {P.index((p + n : U32)) == (P.index(p) + 1 : U32) : U32}:
  MU32.u32_to_nat_inj(P.index((p + n : U32)), (P.index(p) + 1 : U32),
    Equal.trans(Nat, U32.to_nat(P.index((p + n : U32))), 1n+U32.to_nat(P.index(p)),
      U32.to_nat((P.index(p) + 1 : U32)), e,
      Equal.sym(Nat, U32.to_nat((P.index(p) + 1 : U32)), 1n+U32.to_nat(P.index(p)),
        C.successor_nat(P.index(p),
          successor_bound(U32.to_nat(P.index(p)), U32.to_nat(P.index((p + n : U32))), Lemmas.pow2(32n),
            e, Lemmas.u32_to_nat_lt(P.index((p + n : U32))))))))

def next_noncross.of(+p: U32, +n: U32,
  hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.lt(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n),
  facts: {U32.to_nat(P.offset((p + n : U32))) == Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)) : Nat} &
    {U32.to_nat(P.index((p + n : U32))) == U32.to_nat(P.index(p)) : Nat}) ->
  MNat.le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) &
  ({P.index((p + n : U32)) == P.index(p) : U32} &
  ({U32.to_nat(P.offset((p + n : U32))) == Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)) : Nat} &
   {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.sub(U32.to_nat((32 - n : U32)), U32.to_nat(P.offset(p))) : Nat})):
  (+es, eq) = facts
  (noncross_room(p, n, h), (MU32.u32_to_nat_inj(P.index((p + n : U32)), P.index(p), eq),
    (es, noncross_gap(p, n, hn, es))))

def next_noncross(+p: U32, +n: U32,
  room: MNat.lt(Nat.add(U32.to_nat(p), U32.to_nat(n)), Lemmas.pow2(32n)),
  hn: MNat.le(U32.to_nat(n), 32n),
  +h: MNat.lt(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n)) ->
  MNat.le(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) &
  ({P.index((p + n : U32)) == P.index(p) : U32} &
  ({U32.to_nat(P.offset((p + n : U32))) == Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)) : Nat} &
   {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.sub(U32.to_nat((32 - n : U32)), U32.to_nat(P.offset(p))) : Nat})):
  next_noncross.of(p, n, hn, h, P.next_noncross(p, n, room, h))

def next_cross.of(+p: U32, +n: U32,
  hn: MNat.le(U32.to_nat(n), 32n),
  h: MNat.le(32n, Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n))),
  facts: {U32.to_nat(P.offset((p + n : U32))) == Nat.sub(Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)), 32n) : Nat} &
    {U32.to_nat(P.index((p + n : U32))) == 1n+U32.to_nat(P.index(p)) : Nat}) ->
  {P.index((p + n : U32)) == (P.index(p) + 1 : U32) : U32} &
  ({U32.to_nat(P.offset((p + n : U32))) == Nat.sub(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) : Nat} &
   {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.add(U32.to_nat((32 - P.offset(p) : U32)), U32.to_nat((32 - n : U32))) : Nat}):
  (+es, eq) = facts
  (cross_index(p, n, eq), (cross_end(p, n, es), cross_gap(p, n, hn, h, es)))

def next_cross(+p: U32, +n: U32,
  room: MNat.lt(Nat.add(U32.to_nat(p), U32.to_nat(n)), Lemmas.pow2(32n)),
  +hn: MNat.le(U32.to_nat(n), 32n),
  +h: MNat.le(32n, Nat.add(U32.to_nat(P.offset(p)), U32.to_nat(n)))) ->
  {P.index((p + n : U32)) == (P.index(p) + 1 : U32) : U32} &
  ({U32.to_nat(P.offset((p + n : U32))) == Nat.sub(U32.to_nat(n), U32.to_nat((32 - P.offset(p) : U32))) : Nat} &
   {U32.to_nat((32 - P.offset((p + n : U32)) : U32)) == Nat.add(U32.to_nat((32 - P.offset(p) : U32)), U32.to_nat((32 - n : U32))) : Nat}):
  next_cross.of(p, n, hn, h, P.next_cross(p, n, room, hn, h))
