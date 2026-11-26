import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool
import bend-kit-cbor@0.3.0.1/cbor.bend as Cbor
import ../lemmas/lemmas.bend as Lemmas
import ./crdt.bend as Crdt
import ./LAWS.bend as Laws

# U32 order facts, read through to_nat.
def le_refl(+a: U32) -> {U32.is_le(a, a) == True{} : Bool}:
  %Lemmas.u32_le_nat_sym(a, a) : {_ == True{} : Bool}
  MNat.le_refl(U32.to_nat(a))

def cmp_lt_le(k: Cmp, h: {Cmp.is_lt(k) == True{} : Bool}) -> {Cmp.is_le(k) == True{} : Bool}:
  match k:
    case LT{}:
      {==}
    case EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, MBool.false_ne_true()(h))
    case GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, MBool.false_ne_true()(h))

def lt_ne0_nat(
  a: Nat, b: Nat, h: {Cmp.is_lt(Nat.cmp(a, b)) == True{} : Bool}
) -> {Bool.not(Cmp.is_eq(Nat.cmp(b, 0n))) == True{} : Bool}:
  match a b:
    case 0n 0n:
      Empty.absurd({Bool.not(Cmp.is_eq(Nat.cmp(0n, 0n))) == True{} : Bool}, MBool.false_ne_true()(h))
    case 1n+p 0n:
      Empty.absurd({Bool.not(Cmp.is_eq(Nat.cmp(0n, 0n))) == True{} : Bool}, MBool.false_ne_true()(h))
    case _ 1n+q:
      {==}

def lt_ne0(
  +c: U32, +n: U32, h: {U32.is_lt(c, n) == True{} : Bool}
) -> {U32.is_ne(n, 0) == True{} : Bool}:
  %Lemmas.u32_cmp_nat_sym(n, 0) : {Bool.not(Cmp.is_eq(_)) == True{} : Bool}
  lt_ne0_nat(U32.to_nat(c), U32.to_nat(n),
    Equal.trans(Bool, Cmp.is_lt(Nat.cmp(U32.to_nat(c), U32.to_nat(n))), U32.is_lt(c, n), True{},
      Equal.cong(Cmp, Bool, k => Cmp.is_lt(k), Nat.cmp(U32.to_nat(c), U32.to_nat(n)), U32.cmp(c, n),
        Lemmas.u32_cmp_nat_sym(c, n)), h))

def eq32(+x: U32, +y: U32, h: {U32.is_eq(x, y) == True{} : Bool}) -> {x == y : U32}:
  Lemmas.u32_to_nat_inj(x, y, MNat.eq_of_is_eq(U32.to_nat(x), U32.to_nat(y),
    Equal.trans(Bool, Nat.is_eq(U32.to_nat(x), U32.to_nat(y)), U32.is_eq(x, y), True{},
      Equal.sym(Bool, U32.is_eq(x, y), Nat.is_eq(U32.to_nat(x), U32.to_nat(y)), Lemmas.u32_is_eq_nat(x, y)), h)))

def cons_eq(
  -x: U32, -y: U32, -s: List<&2, U32>, -t: List<&2, U32>,
  ex: {x == y : U32}, et: {s == t : List<&2, U32>}
) -> {Con{x, s} == Con{y, t} : List<&2, U32>}:
  %ex : {Con{x, s} == Con{_, t} : List<&2, U32>}
  %et : {Con{x, s} == Con{x, _} : List<&2, U32>}
  {==}

def merge_nil_l(b: List<&2, U32>) -> {Crdt.GCounter.merge(Nil{}, b) == b : List<&2, U32>}:
  match b:
    case Nil{}:
      {==}
    case Con{y, ys}:
      {==}

def le_refl_list(s: List<&2, U32>) -> {Crdt.GCounter.le(s, s) == True{} : Bool}:
  match s:
    case Nil{}:
      {==}
    case Con{+x, +xs}:
      MBool.and_eq_true(U32.is_le(x, x), Crdt.GCounter.le(xs, xs), le_refl(x), le_refl_list(xs))

def Laws.merge_comm(a, b):
  match a b:
    case Nil{} Nil{}:
      {==}
    case Nil{} Con{y, ys}:
      {==}
    case Con{x, xs} Nil{}:
      {==}
    case Con{+x, +xs} Con{+y, +ys}:
      cons_eq(U32.max(x, y), U32.max(y, x), Crdt.GCounter.merge(xs, ys), Crdt.GCounter.merge(ys, xs),
        Lemmas.u32_max_comm(x, y), Laws.merge_comm(xs, ys))

def Laws.merge_assoc(a, b, c):
  match a b c:
    case Nil{} Nil{} Nil{}:
      {==}
    case Nil{} Nil{} Con{z, zs}:
      {==}
    case Nil{} Con{y, ys} Nil{}:
      {==}
    case Nil{} Con{y, ys} Con{z, zs}:
      {==}
    case Con{x, xs} Nil{} Nil{}:
      {==}
    case Con{x, xs} Nil{} Con{z, zs}:
      {==}
    case Con{x, xs} Con{y, ys} Nil{}:
      {==}
    case Con{+x, +xs} Con{+y, +ys} Con{+z, +zs}:
      cons_eq(U32.max(U32.max(x, y), z), U32.max(x, U32.max(y, z)),
        Crdt.GCounter.merge(Crdt.GCounter.merge(xs, ys), zs), Crdt.GCounter.merge(xs, Crdt.GCounter.merge(ys, zs)),
        Lemmas.u32_max_assoc(x, y, z), Laws.merge_assoc(xs, ys, zs))

def Laws.merge_idem(a):
  match a:
    case Nil{}:
      {==}
    case Con{+x, +xs}:
      cons_eq(U32.max(x, x), x, Crdt.GCounter.merge(xs, xs), xs, Lemmas.u32_max_self(x), Laws.merge_idem(xs))

def Laws.merge_upper_l(a, b):
  match a b:
    case Nil{} _:
      {==}
    case Con{+x, +xs} Nil{}:
      le_refl_list(Con{x, xs})
    case Con{+x, +xs} Con{+y, +ys}:
      MBool.and_eq_true(U32.is_le(x, U32.max(x, y)), Crdt.GCounter.le(xs, Crdt.GCounter.merge(xs, ys)),
        Lemmas.u32_le_max_l(x, y), Laws.merge_upper_l(xs, ys))

def Laws.merge_upper_r(a, b):
  +a = a
  +b = b
  %Laws.merge_comm(b, a) : {Crdt.GCounter.le(b, _) == True{} : Bool}
  Laws.merge_upper_l(b, a)

def Laws.merge_least(a, b, c, ha, hb):
  match a b c:
    case Nil{} Nil{} _:
      {==}
    case Nil{} Con{y, ys} _:
      hb
    case Con{x, xs} Nil{} _:
      ha
    case Con{+x, +xs} Con{+y, +ys} Nil{}:
      +ha = ha
      +hb = hb
      MBool.and_eq_true(U32.is_eq(U32.max(x, y), 0), Crdt.GCounter.le(Crdt.GCounter.merge(xs, ys), Nil{}),
        Lemmas.u32_max_eq0(x, y,
          MBool.eq_true_of_and_left(U32.is_eq(x, 0), Crdt.GCounter.le(xs, Nil{}), ha),
          MBool.eq_true_of_and_left(U32.is_eq(y, 0), Crdt.GCounter.le(ys, Nil{}), hb)),
        Laws.merge_least(xs, ys, Nil{},
          MBool.eq_true_of_and_right(U32.is_eq(x, 0), Crdt.GCounter.le(xs, Nil{}), ha),
          MBool.eq_true_of_and_right(U32.is_eq(y, 0), Crdt.GCounter.le(ys, Nil{}), hb)))
    case Con{+x, +xs} Con{+y, +ys} Con{+z, +zs}:
      +ha = ha
      +hb = hb
      MBool.and_eq_true(U32.is_le(U32.max(x, y), z), Crdt.GCounter.le(Crdt.GCounter.merge(xs, ys), zs),
        Lemmas.u32_max_le(x, y, z,
          MBool.eq_true_of_and_left(U32.is_le(x, z), Crdt.GCounter.le(xs, zs), ha),
          MBool.eq_true_of_and_left(U32.is_le(y, z), Crdt.GCounter.le(ys, zs), hb)),
        Laws.merge_least(xs, ys, zs,
          MBool.eq_true_of_and_right(U32.is_le(x, z), Crdt.GCounter.le(xs, zs), ha),
          MBool.eq_true_of_and_right(U32.is_le(y, z), Crdt.GCounter.le(ys, zs), hb)))

def Laws.le_refl(a):
  le_refl_list(a)

def le32_trans(
  +a: U32, +b: U32, +c: U32,
  hab: {U32.is_le(a, b) == True{} : Bool}, hbc: {U32.is_le(b, c) == True{} : Bool}
) -> {U32.is_le(a, c) == True{} : Bool}:
  %Lemmas.u32_le_nat_sym(a, c) : {_ == True{} : Bool}
  MNat.le_trans(U32.to_nat(a), U32.to_nat(b), U32.to_nat(c),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(a), U32.to_nat(b)), U32.is_le(a, b), True{}, Lemmas.u32_le_nat_sym(a, b), hab),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(b), U32.to_nat(c)), U32.is_le(b, c), True{}, Lemmas.u32_le_nat_sym(b, c), hbc))

def zero_le32(+a: U32) -> {U32.is_le(0, a) == True{} : Bool}:
  %Lemmas.u32_le_nat_sym(0, a) : {_ == True{} : Bool}
  MNat.zero_le(U32.to_nat(a))

def le32_eq0(
  +x: U32, +y: U32, hxy: {U32.is_le(x, y) == True{} : Bool}, hy: {U32.is_eq(y, 0) == True{} : Bool}
) -> {U32.is_eq(x, 0) == True{} : Bool}:
  Equal.trans(Bool, U32.is_eq(x, 0), U32.is_le(x, 0), True{},
    Lemmas.u32_eq0_le(x), le32_trans(x, y, 0, hxy, Lemmas.u32_eq0_to_le(y, hy)))

def Laws.le_trans(a, b, c, hab, hbc):
  match a b c:
    case Nil{} _ _:
      {==}
    case Con{x, xs} Nil{} Nil{}:
      hab
    case Con{+x, +xs} Nil{} Con{+z, +zs}:
      +hab = hab
      MBool.and_eq_true(U32.is_le(x, z), Crdt.GCounter.le(xs, zs),
        le32_trans(x, 0, z, Lemmas.u32_eq0_to_le(x,
          MBool.eq_true_of_and_left(U32.is_eq(x, 0), Crdt.GCounter.le(xs, Nil{}), hab)), zero_le32(z)),
        Laws.le_trans(xs, Nil{}, zs,
          MBool.eq_true_of_and_right(U32.is_eq(x, 0), Crdt.GCounter.le(xs, Nil{}), hab), {==}))
    case Con{+x, +xs} Con{+y, +ys} Nil{}:
      +hab = hab
      +hbc = hbc
      MBool.and_eq_true(U32.is_eq(x, 0), Crdt.GCounter.le(xs, Nil{}),
        le32_eq0(x, y,
          MBool.eq_true_of_and_left(U32.is_le(x, y), Crdt.GCounter.le(xs, ys), hab),
          MBool.eq_true_of_and_left(U32.is_eq(y, 0), Crdt.GCounter.le(ys, Nil{}), hbc)),
        Laws.le_trans(xs, ys, Nil{},
          MBool.eq_true_of_and_right(U32.is_le(x, y), Crdt.GCounter.le(xs, ys), hab),
          MBool.eq_true_of_and_right(U32.is_eq(y, 0), Crdt.GCounter.le(ys, Nil{}), hbc)))
    case Con{+x, +xs} Con{+y, +ys} Con{+z, +zs}:
      +hab = hab
      +hbc = hbc
      MBool.and_eq_true(U32.is_le(x, z), Crdt.GCounter.le(xs, zs),
        le32_trans(x, y, z,
          MBool.eq_true_of_and_left(U32.is_le(x, y), Crdt.GCounter.le(xs, ys), hab),
          MBool.eq_true_of_and_left(U32.is_le(y, z), Crdt.GCounter.le(ys, zs), hbc)),
        Laws.le_trans(xs, ys, zs,
          MBool.eq_true_of_and_right(U32.is_le(x, y), Crdt.GCounter.le(xs, ys), hab),
          MBool.eq_true_of_and_right(U32.is_le(y, z), Crdt.GCounter.le(ys, zs), hbc)))

def Laws.merge_mono(a, b, c, hab):
  +a = a
  +b = b
  +c = c
  Laws.merge_least(a, c, Crdt.GCounter.merge(b, c),
    Laws.le_trans(a, b, Crdt.GCounter.merge(b, c), hab, Laws.merge_upper_l(b, c)),
    Laws.merge_upper_r(b, c))

def inc_at_grows(
  ok: Bool, +c: U32, +n: U32, +t: List<&2, U32>, h: {U32.is_lt(c, n) == ok : Bool}
) -> {Laws.grows(Con{c, t}, Crdt.GCounter.inc.at(ok, n, t)) == True{} : Bool}:
  match ok:
    case True{}:
      MBool.and_eq_true(U32.is_le(c, n), Crdt.GCounter.le(t, t), cmp_lt_le(U32.cmp(c, n), h), le_refl_list(t))
    case False{}:
      {==}

def cons_grows(
  m: Maybe<&2, List<&2, U32>>, +c: U32, -t: List<&2, U32>, h: {Laws.grows(t, m) == True{} : Bool}
) -> {Laws.grows(Con{c, t}, Crdt.GCounter.cons(c, m)) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{u}:
      MBool.and_eq_true(U32.is_le(c, c), Crdt.GCounter.le(t, u), le_refl(c), h)

def Laws.inc_grows(s, i):
  match s i:
    case Nil{} _:
      {==}
    case Con{+c, +t} 0n:
      inc_at_grows(U32.is_lt(c, U32.inc(c)), c, U32.inc(c), t, {==})
    case Con{+c, +t} 1n+p:
      +p = p
      cons_grows(Crdt.GCounter.inc(t, p), c, t, Laws.inc_grows(t, p))

def valid_go(
  xs: List<&2, U32>, ys: List<&2, U32>, +x: U32, +y: U32,
  hx: {Crdt.GCounter.valid.go(xs, x) == True{} : Bool}, hy: {Crdt.GCounter.valid.go(ys, y) == True{} : Bool}
) -> {Crdt.GCounter.valid.go(Crdt.GCounter.merge(xs, ys), U32.max(x, y)) == True{} : Bool}:
  match xs ys:
    case Nil{} Nil{}:
      Lemmas.u32_ne0_max(x, y, hx)
    case Nil{} Con{v, vs}:
      hy
    case Con{u, us} Nil{}:
      hx
    case Con{u, us} Con{v, vs}:
      valid_go(us, vs, u, v, hx, hy)

def Laws.merge_valid(a, b, ha, hb):
  match a b:
    case Nil{} Nil{}:
      {==}
    case Nil{} Con{y, ys}:
      hb
    case Con{x, xs} Nil{}:
      ha
    case Con{x, xs} Con{y, ys}:
      valid_go(xs, ys, x, y, ha, hb)

def inc_ok.list(s: List<&2, U32>) -> Bool:
  match s:
    case Nil{}:
      False{}
    case Con{c, t}:
      Crdt.GCounter.valid.go(t, c)

# The result of a successful increment is never empty.
def inc_ok(m: Maybe<&2, List<&2, U32>>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{s}:
      inc_ok.list(s)

def pad_go(i: Nat, -c: U32) -> {Crdt.GCounter.valid.go(Crdt.GCounter.pad(i), c) == True{} : Bool}:
  match i:
    case 0n:
      {==}
    case 1n+p:
      pad_go(p, 0)

def pad_ok(i: Nat) -> {inc_ok(Some{Crdt.GCounter.pad(i)}) == True{} : Bool}:
  match i:
    case 0n:
      {==}
    case 1n+p:
      pad_go(p, 0)

def inc_at_ok(
  ok: Bool, +c: U32, +n: U32, t: List<&2, U32>,
  hok: {U32.is_lt(c, n) == ok : Bool}, h: {Crdt.GCounter.valid.go(t, c) == True{} : Bool}
) -> {inc_ok(Crdt.GCounter.inc.at(ok, n, t)) == True{} : Bool}:
  match ok t:
    case True{} Nil{}:
      lt_ne0(c, n, hok)
    case True{} Con{d, u}:
      h
    case False{} _:
      {==}

def cons_ok.list(
  s: List<&2, U32>, -c: U32, h: {inc_ok.list(s) == True{} : Bool}
) -> {inc_ok.list(Con{c, s}) == True{} : Bool}:
  match s:
    case Nil{}:
      Empty.absurd({inc_ok.list([c]) == True{} : Bool}, MBool.false_ne_true()(h))
    case Con{d, u}:
      h

def cons_ok(
  m: Maybe<&2, List<&2, U32>>, -c: U32, h: {inc_ok(m) == True{} : Bool}
) -> {inc_ok(Crdt.GCounter.cons(c, m)) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{s}:
      cons_ok.list(s, c, h)

def valid_tail(t: List<&2, U32>, -c: U32, h: {Crdt.GCounter.valid.go(t, c) == True{} : Bool}) -> {Crdt.GCounter.valid(t) == True{} : Bool}:
  match t:
    case Nil{}:
      {==}
    case Con{d, u}:
      h

def valid_nonempty_not_le_nil(
  t: List<&2, U32>, +x: U32,
  hv: {Crdt.GCounter.valid.go(t, x) == True{} : Bool},
  h: {Crdt.GCounter.le(Con{x, t}, Nil{}) == True{} : Bool}
) -> Empty:
  match t:
    case Nil{}:
      MBool.false_ne_true()(
        %eq32(x, 0, MBool.eq_true_of_and_left(U32.is_eq(x, 0), True{}, h)) : {U32.is_ne(_, 0) == True{} : Bool}
        hv)
    case Con{+y, +ys}:
      valid_nonempty_not_le_nil(ys, y, hv,
        MBool.eq_true_of_and_right(U32.is_eq(x, 0), Crdt.GCounter.le(Con{y, ys}, Nil{}), h))

def le32_antisymm(
  +x: U32, +y: U32, hxy: {U32.is_le(x, y) == True{} : Bool}, hyx: {U32.is_le(y, x) == True{} : Bool}
) -> {x == y : U32}:
  Lemmas.u32_to_nat_inj(x, y, MNat.le_antisymm(U32.to_nat(x), U32.to_nat(y),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(x), U32.to_nat(y)), U32.is_le(x, y), True{}, Lemmas.u32_le_nat_sym(x, y), hxy),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(y), U32.to_nat(x)), U32.is_le(y, x), True{}, Lemmas.u32_le_nat_sym(y, x), hyx)))

def Laws.le_antisymm(a, b, va, vb, hab, hba):
  match a b:
    case Nil{} Nil{}:
      {==}
    case Nil{} Con{+y, +ys}:
      Empty.absurd({Nil{} == Con{y, ys} : List<&2, U32>}, valid_nonempty_not_le_nil(ys, y, vb, hba))
    case Con{+x, +xs} Nil{}:
      Empty.absurd({Con{x, xs} == Nil{} : List<&2, U32>}, valid_nonempty_not_le_nil(xs, x, va, hab))
    case Con{+x, +xs} Con{+y, +ys}:
      +hab = hab
      +hba = hba
      cons_eq(x, y, xs, ys,
        le32_antisymm(x, y,
          MBool.eq_true_of_and_left(U32.is_le(x, y), Crdt.GCounter.le(xs, ys), hab),
          MBool.eq_true_of_and_left(U32.is_le(y, x), Crdt.GCounter.le(ys, xs), hba)),
        Laws.le_antisymm(xs, ys, valid_tail(xs, x, va), valid_tail(ys, y, vb),
          MBool.eq_true_of_and_right(U32.is_le(x, y), Crdt.GCounter.le(xs, ys), hab),
          MBool.eq_true_of_and_right(U32.is_le(y, x), Crdt.GCounter.le(ys, xs), hba)))

def inc_valid_ok(s: List<&2, U32>, i: Nat, h: {Crdt.GCounter.valid(s) == True{} : Bool}) -> {inc_ok(Crdt.GCounter.inc(s, i)) == True{} : Bool}:
  match s i:
    case Nil{} _:
      pad_ok(i)
    case Con{+c, t} 0n:
      inc_at_ok(U32.is_lt(c, U32.inc(c)), c, U32.inc(c), t, {==}, h)
    case Con{c, +t} 1n+p:
      +p = p
      cons_ok(Crdt.GCounter.inc(t, p), c, inc_valid_ok(t, p, valid_tail(t, c, h)))

def ok_of_inc_ok.list(s: List<&2, U32>, h: {inc_ok.list(s) == True{} : Bool}) -> {Crdt.GCounter.valid(s) == True{} : Bool}:
  match s:
    case Nil{}:
      {==}
    case Con{c, t}:
      h

def ok_of_inc_ok(m: Maybe<&2, List<&2, U32>>, h: {inc_ok(m) == True{} : Bool}) -> {Laws.ok_valid(m) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{s}:
      ok_of_inc_ok.list(s, h)

def Laws.inc_valid(s, i, h):
  +s = s
  +i = i
  ok_of_inc_ok(Crdt.GCounter.inc(s, i), inc_valid_ok(s, i, h))

# Convergence.
def same_sound(a: List<&2, U32>, b: List<&2, U32>, h: {Laws.same(a, b) == True{} : Bool}) -> {a == b : List<&2, U32>}:
  match a b:
    case Nil{} Nil{}:
      {==}
    case Nil{} Con{y, ys}:
      Empty.absurd({Nil{} == Con{y, ys} : List<&2, U32>}, MBool.false_ne_true()(h))
    case Con{x, xs} Nil{}:
      Empty.absurd({Con{x, xs} == Nil{} : List<&2, U32>}, MBool.false_ne_true()(h))
    case Con{+x, +xs} Con{+y, +ys}:
      +h = h
      cons_eq(x, y, xs, ys,
        eq32(x, y, MBool.eq_true_of_and_left(U32.is_eq(x, y), Laws.same(xs, ys), h)),
        same_sound(xs, ys, MBool.eq_true_of_and_right(U32.is_eq(x, y), Laws.same(xs, ys), h)))

def lcomm(+x: List<&2, U32>, +y: List<&2, U32>, +f: List<&2, U32>) -> {Crdt.GCounter.merge(x, Crdt.GCounter.merge(y, f)) == Crdt.GCounter.merge(y, Crdt.GCounter.merge(x, f)) : List<&2, U32>}:
  %Laws.merge_assoc(x, y, f) : {_ == Crdt.GCounter.merge(y, Crdt.GCounter.merge(x, f)) : List<&2, U32>}
  %Laws.merge_assoc(y, x, f) : {Crdt.GCounter.merge(Crdt.GCounter.merge(x, y), f) == _ : List<&2, U32>}
  %Laws.merge_comm(x, y) : {Crdt.GCounter.merge(Crdt.GCounter.merge(x, y), f) == Crdt.GCounter.merge(_, f) : List<&2, U32>}
  {==}

def absorb.go(
  b: Bool, +x: List<&2, U32>, +y: List<&2, U32>, +f: List<&2, U32>, -m: Bool,
  hb: {Laws.same(x, y) == b : Bool}, h: {Bool.or(b, m) == True{} : Bool},
  ih: {m == True{} : Bool} -> {Crdt.GCounter.merge(x, f) == f : List<&2, U32>}
) -> {Crdt.GCounter.merge(x, Crdt.GCounter.merge(y, f)) == Crdt.GCounter.merge(y, f) : List<&2, U32>}:
  match b:
    case True{}:
      %Equal.sym(List<&2, U32>, x, y, same_sound(x, y, hb)) : {Crdt.GCounter.merge(_, Crdt.GCounter.merge(y, f)) == Crdt.GCounter.merge(y, f) : List<&2, U32>}
      %Laws.merge_assoc(y, y, f) : {_ == Crdt.GCounter.merge(y, f) : List<&2, U32>}
      %Laws.merge_idem(y) : {Crdt.GCounter.merge(Crdt.GCounter.merge(y, y), f) == Crdt.GCounter.merge(_, f) : List<&2, U32>}
      {==}
    case False{}:
      Equal.trans(List<&2, U32>, Crdt.GCounter.merge(x, Crdt.GCounter.merge(y, f)), Crdt.GCounter.merge(y, Crdt.GCounter.merge(x, f)),
        Crdt.GCounter.merge(y, f), lcomm(x, y, f),
        Equal.cong(List<&2, U32>, List<&2, U32>, s => Crdt.GCounter.merge(y, s), Crdt.GCounter.merge(x, f), f, ih(h)))

def absorb(
  +x: List<&2, U32>, ys: List<&2, List<&2, U32>>, h: {Laws.member(x, ys) == True{} : Bool}
) -> {Crdt.GCounter.merge(x, Crdt.GCounter.merge_all(ys)) == Crdt.GCounter.merge_all(ys) : List<&2, U32>}:
  match ys:
    case Nil{}:
      Empty.absurd({Crdt.GCounter.merge(x, Nil{}) == Nil{} : List<&2, U32>}, MBool.false_ne_true()(h))
    case Con{+y, +t}:
      absorb.go(Laws.same(x, y), x, y, Crdt.GCounter.merge_all(t), Laws.member(x, t), {==}, h, p => absorb(x, t, p))

def covered(
  xs: List<&2, List<&2, U32>>, +ys: List<&2, List<&2, U32>>, h: {Laws.covers(xs, ys) == True{} : Bool}
) -> {Crdt.GCounter.merge(Crdt.GCounter.merge_all(xs), Crdt.GCounter.merge_all(ys)) == Crdt.GCounter.merge_all(ys) : List<&2, U32>}:
  match xs:
    case Nil{}:
      merge_nil_l(Crdt.GCounter.merge_all(ys))
    case Con{+x, +t}:
      +h = h
      Equal.trans(List<&2, U32>,
        Crdt.GCounter.merge(Crdt.GCounter.merge(x, Crdt.GCounter.merge_all(t)), Crdt.GCounter.merge_all(ys)),
        Crdt.GCounter.merge(x, Crdt.GCounter.merge(Crdt.GCounter.merge_all(t), Crdt.GCounter.merge_all(ys))),
        Crdt.GCounter.merge_all(ys),
        Laws.merge_assoc(x, Crdt.GCounter.merge_all(t), Crdt.GCounter.merge_all(ys)),
        Equal.trans(List<&2, U32>,
          Crdt.GCounter.merge(x, Crdt.GCounter.merge(Crdt.GCounter.merge_all(t), Crdt.GCounter.merge_all(ys))),
          Crdt.GCounter.merge(x, Crdt.GCounter.merge_all(ys)),
          Crdt.GCounter.merge_all(ys),
          Equal.cong(List<&2, U32>, List<&2, U32>, s => Crdt.GCounter.merge(x, s),
            Crdt.GCounter.merge(Crdt.GCounter.merge_all(t), Crdt.GCounter.merge_all(ys)), Crdt.GCounter.merge_all(ys),
            covered(t, ys, MBool.eq_true_of_and_right(Laws.member(x, ys), Laws.covers(t, ys), h))),
          absorb(x, ys, MBool.eq_true_of_and_left(Laws.member(x, ys), Laws.covers(t, ys), h))))

def Laws.converge(xs, ys, hx, hy):
  +xs = xs
  +ys = ys
  Equal.trans(List<&2, U32>, Crdt.GCounter.merge_all(xs),
    Crdt.GCounter.merge(Crdt.GCounter.merge_all(ys), Crdt.GCounter.merge_all(xs)), Crdt.GCounter.merge_all(ys),
    Equal.sym(List<&2, U32>, Crdt.GCounter.merge(Crdt.GCounter.merge_all(ys), Crdt.GCounter.merge_all(xs)),
      Crdt.GCounter.merge_all(xs), covered(ys, xs, hy)),
    Equal.trans(List<&2, U32>,
      Crdt.GCounter.merge(Crdt.GCounter.merge_all(ys), Crdt.GCounter.merge_all(xs)),
      Crdt.GCounter.merge(Crdt.GCounter.merge_all(xs), Crdt.GCounter.merge_all(ys)), Crdt.GCounter.merge_all(ys),
      Laws.merge_comm(Crdt.GCounter.merge_all(ys), Crdt.GCounter.merge_all(xs)), covered(xs, ys, hx)))

# The CBOR boundary.
def gate_valid(
  ok: Bool, +s: List<&2, U32>, -q: Bool, h: {Bool.and(Crdt.GCounter.valid(s), q) == ok : Bool}
) -> {Laws.ok_valid(Crdt.GCounter.from_cbor.gate(ok, s)) == True{} : Bool}:
  match ok:
    case True{}:
      MBool.eq_true_of_and_left(Crdt.GCounter.valid(s), q, h)
    case False{}:
      {==}

def check_valid(m: Maybe<&2, List<&2, U32>>, +cap: U32) -> {Laws.ok_valid(Crdt.GCounter.from_cbor.check(m, cap)) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{+s}:
      gate_valid(Bool.and(Crdt.GCounter.valid(s), U32.is_le(Crdt.GCounter.size(s), cap)), s,
        U32.is_le(Crdt.GCounter.size(s), cap), {==})

def Laws.from_cbor_valid(v, cap):
  match v:
    case Cbor.UInt{w}:
      {==}
    case Cbor.NInt{w}:
      {==}
    case Cbor.BStr{b}:
      {==}
    case Cbor.TStr{b}:
      {==}
    case Cbor.Arr{xs}:
      check_valid(Crdt.GCounter.from_cbor.items(xs), cap)
    case Cbor.Obj{kvs}:
      {==}
    case Cbor.Tag{n, x}:
      {==}
    case Cbor.Sim{x}:
      {==}
    case Cbor.Flt{x}:
      {==}

def items_rt(s: List<&2, U32>) -> {Crdt.GCounter.from_cbor.items(Crdt.GCounter.to_cbor.items(s)) == Some{s} : Maybe<&2, List<&2, U32>>}:
  match s:
    case Nil{}:
      {==}
    case Con{+c, +t}:
      Equal.cong(Maybe<&2, List<&2, U32>>, Maybe<&2, List<&2, U32>>, m => Crdt.GCounter.cons(c, m),
        Crdt.GCounter.from_cbor.items(Crdt.GCounter.to_cbor.items(t)), Some{t}, items_rt(t))

def gate_ok(
  +s: List<&2, U32>, +cap: U32,
  hv: {Crdt.GCounter.valid(s) == True{} : Bool}, hc: {U32.is_le(Crdt.GCounter.size(s), cap) == True{} : Bool}
) -> {Crdt.GCounter.from_cbor.check(Some{s}, cap) == Some{s} : Maybe<&2, List<&2, U32>>}:
  %Equal.sym(Bool, Crdt.GCounter.valid(s), True{}, hv) : {Crdt.GCounter.from_cbor.gate(Bool.and(_, U32.is_le(Crdt.GCounter.size(s), cap)), s) == Some{s} : Maybe<&2, List<&2, U32>>}
  %Equal.sym(Bool, U32.is_le(Crdt.GCounter.size(s), cap), True{}, hc) : {Crdt.GCounter.from_cbor.gate(Bool.and(True{}, _), s) == Some{s} : Maybe<&2, List<&2, U32>>}
  {==}

def Laws.cbor_roundtrip(s, cap, hv, hc):
  +s = s
  +cap = cap
  Equal.trans(Maybe<&2, List<&2, U32>>,
    Crdt.GCounter.from_cbor.check(Crdt.GCounter.from_cbor.items(Crdt.GCounter.to_cbor.items(s)), cap),
    Crdt.GCounter.from_cbor.check(Some{s}, cap), Some{s},
    Equal.cong(Maybe<&2, List<&2, U32>>, Maybe<&2, List<&2, U32>>, m => Crdt.GCounter.from_cbor.check(m, cap),
      Crdt.GCounter.from_cbor.items(Crdt.GCounter.to_cbor.items(s)), Some{s}, items_rt(s)),
    gate_ok(s, cap, hv, hc))

def Laws.inc_pads():
  {==}

def Laws.inc_overflow():
  {==}

def Laws.get_missing():
  {==}

def Laws.merge_fixture():
  {==}

def Laws.value_sum():
  {==}

def Laws.value_overflow():
  {==}

def Laws.from_cbor_accepts():
  {==}

def Laws.from_cbor_trailing_zero():
  {==}

def Laws.from_cbor_over_cap():
  {==}

def Laws.from_cbor_wide():
  {==}

def Laws.from_cbor_negative():
  {==}

def Laws.from_cbor_not_array():
  {==}

def pn_make_grows(
  a: Maybe<&2, List<&2, U32>>, b: Maybe<&2, List<&2, U32>>,
  +p: List<&2, U32>, +n: List<&2, U32>,
  hp: {Laws.grows(p, a) == True{} : Bool}, hn: {Laws.grows(n, b) == True{} : Bool}
) -> {Laws.pn.grows(Crdt.PN{p, n}, Crdt.PNCounter.make(a, b)) == True{} : Bool}:
  match a b:
    case None{} _:
      {==}
    case Some{x} None{}:
      {==}
    case Some{+x} Some{+y}:
      MBool.and_eq_true(Crdt.GCounter.le(p, x), Crdt.GCounter.le(n, y), hp, hn)

def Laws.pn_inc_grows(s, i):
  match s:
    case Crdt.PN{+p, +n}:
      +i = i
      pn_make_grows(Crdt.GCounter.inc(p, i), Some{n}, p, n, Laws.inc_grows(p, i), Laws.le_refl(n))

def Laws.pn_dec_grows(s, i):
  match s:
    case Crdt.PN{+p, +n}:
      +i = i
      pn_make_grows(Some{p}, Crdt.GCounter.inc(n, i), p, n, Laws.le_refl(p), Laws.inc_grows(n, i))

def pn_make_valid(
  a: Maybe<&2, List<&2, U32>>, b: Maybe<&2, List<&2, U32>>,
  hp: {Laws.ok_valid(a) == True{} : Bool}, hn: {Laws.ok_valid(b) == True{} : Bool}
) -> {Laws.pn.ok_valid(Crdt.PNCounter.make(a, b)) == True{} : Bool}:
  match a b:
    case None{} _:
      {==}
    case Some{x} None{}:
      {==}
    case Some{+x} Some{+y}:
      MBool.and_eq_true(Crdt.GCounter.valid(x), Crdt.GCounter.valid(y), hp, hn)

def Laws.pn_inc_valid(s, i, h):
  match s:
    case Crdt.PN{+p, +n}:
      +h = h
      +i = i
      pn_make_valid(Crdt.GCounter.inc(p, i), Some{n},
        Laws.inc_valid(p, i, MBool.eq_true_of_and_left(Crdt.GCounter.valid(p), Crdt.GCounter.valid(n), h)),
        MBool.eq_true_of_and_right(Crdt.GCounter.valid(p), Crdt.GCounter.valid(n), h))

def Laws.pn_dec_valid(s, i, h):
  match s:
    case Crdt.PN{+p, +n}:
      +h = h
      +i = i
      pn_make_valid(Some{p}, Crdt.GCounter.inc(n, i),
        MBool.eq_true_of_and_left(Crdt.GCounter.valid(p), Crdt.GCounter.valid(n), h),
        Laws.inc_valid(n, i, MBool.eq_true_of_and_right(Crdt.GCounter.valid(p), Crdt.GCounter.valid(n), h)))

def Laws.pn_merge_valid(a, b, ha, hb):
  match a b:
    case Crdt.PN{+ap, +an} Crdt.PN{+bp, +bn}:
      +ha = ha
      +hb = hb
      MBool.and_eq_true(Crdt.GCounter.valid(Crdt.GCounter.merge(ap, bp)),
        Crdt.GCounter.valid(Crdt.GCounter.merge(an, bn)),
        Laws.merge_valid(ap, bp,
          MBool.eq_true_of_and_left(Crdt.GCounter.valid(ap), Crdt.GCounter.valid(an), ha),
          MBool.eq_true_of_and_left(Crdt.GCounter.valid(bp), Crdt.GCounter.valid(bn), hb)),
        Laws.merge_valid(an, bn,
          MBool.eq_true_of_and_right(Crdt.GCounter.valid(ap), Crdt.GCounter.valid(an), ha),
          MBool.eq_true_of_and_right(Crdt.GCounter.valid(bp), Crdt.GCounter.valid(bn), hb)))

def pn_make_none_r(a: Maybe<&2, List<&2, U32>>) ->
  {Laws.pn.ok_valid(Crdt.PNCounter.make(a, None{})) == True{} : Bool}:
  match a:
    case None{}:
      {==}
    case Some{x}:
      {==}

def pn_from_right_valid(n: Cbor.Val, +a: Maybe<&2, List<&2, U32>>, +cap: U32,
  ha: {Laws.ok_valid(a) == True{} : Bool}) ->
  {Laws.pn.ok_valid(Crdt.PNCounter.make(a, Crdt.GCounter.from_cbor(n, cap))) == True{} : Bool}:
  match n:
    case Cbor.Arr{ys}:
      +b = Crdt.GCounter.from_cbor.items(ys)
      pn_make_valid(a, Crdt.GCounter.from_cbor.check(b, cap), ha, check_valid(b, cap))
    case Cbor.UInt{w}:
      pn_make_none_r(a)
    case Cbor.NInt{w}:
      pn_make_none_r(a)
    case Cbor.BStr{b}:
      pn_make_none_r(a)
    case Cbor.TStr{b}:
      pn_make_none_r(a)
    case Cbor.Obj{kvs}:
      pn_make_none_r(a)
    case Cbor.Tag{k, v}:
      pn_make_none_r(a)
    case Cbor.Sim{x}:
      pn_make_none_r(a)
    case Cbor.Flt{x}:
      pn_make_none_r(a)

def pn_from_halves_valid(p: Cbor.Val, n: Cbor.Val, +cap: U32) ->
  {Laws.pn.ok_valid(Crdt.PNCounter.make(Crdt.GCounter.from_cbor(p, cap),
    Crdt.GCounter.from_cbor(n, cap))) == True{} : Bool}:
  match p:
    case Cbor.Arr{xs}:
      +a = Crdt.GCounter.from_cbor.items(xs)
      pn_from_right_valid(n, Crdt.GCounter.from_cbor.check(a, cap), cap, check_valid(a, cap))
    case Cbor.UInt{w}:
      {==}
    case Cbor.NInt{w}:
      {==}
    case Cbor.BStr{b}:
      {==}
    case Cbor.TStr{b}:
      {==}
    case Cbor.Obj{kvs}:
      {==}
    case Cbor.Tag{k, v}:
      {==}
    case Cbor.Sim{x}:
      {==}
    case Cbor.Flt{x}:
      {==}

def Laws.pn_from_cbor_valid(v, cap):
  match v:
    case Cbor.Arr{Con{p, Con{n, Nil{}}}}:
      pn_from_halves_valid(p, n, cap)
    case Cbor.Arr{Nil{}}:
      {==}
    case Cbor.Arr{Con{p, Nil{}}}:
      {==}
    case Cbor.Arr{Con{p, Con{n, Con{x, xs}}}}:
      {==}
    case Cbor.UInt{w}:
      {==}
    case Cbor.NInt{w}:
      {==}
    case Cbor.BStr{b}:
      {==}
    case Cbor.TStr{b}:
      {==}
    case Cbor.Obj{kvs}:
      {==}
    case Cbor.Tag{k, v}:
      {==}
    case Cbor.Sim{x}:
      {==}
    case Cbor.Flt{x}:
      {==}

def Laws.pn_cbor_roundtrip(p, n, cap, hv, hp, hn):
  +p = p
  +n = n
  +cap = cap
  +hv = hv
  %Equal.sym(Maybe<&2, List<&2, U32>>,
    Crdt.GCounter.from_cbor(Crdt.GCounter.to_cbor(p), cap), Some{p},
    Laws.cbor_roundtrip(p, cap,
      MBool.eq_true_of_and_left(Crdt.GCounter.valid(p), Crdt.GCounter.valid(n), hv), hp)) :
    {Crdt.PNCounter.make(_, Crdt.GCounter.from_cbor(Crdt.GCounter.to_cbor(n), cap))
     == Some{Crdt.PN{p, n}} : Maybe<&2, Crdt.PNCounter>}
  %Equal.sym(Maybe<&2, List<&2, U32>>,
    Crdt.GCounter.from_cbor(Crdt.GCounter.to_cbor(n), cap), Some{n},
    Laws.cbor_roundtrip(n, cap,
      MBool.eq_true_of_and_right(Crdt.GCounter.valid(p), Crdt.GCounter.valid(n), hv), hn)) :
    {Crdt.PNCounter.make(Some{p}, _) == Some{Crdt.PN{p, n}} : Maybe<&2, Crdt.PNCounter>}
  {==}

def pn_eq(
  -ap: List<&2, U32>, -an: List<&2, U32>, -bp: List<&2, U32>, -bn: List<&2, U32>,
  hp: {ap == bp : List<&2, U32>}, hn: {an == bn : List<&2, U32>}
) -> {Crdt.PN{ap, an} == Crdt.PN{bp, bn} : Crdt.PNCounter}:
  %hp : {Crdt.PN{ap, an} == Crdt.PN{_, bn} : Crdt.PNCounter}
  %hn : {Crdt.PN{ap, an} == Crdt.PN{ap, _} : Crdt.PNCounter}
  {==}

def Laws.pn_merge_comm(a, b):
  match a b:
    case Crdt.PN{+ap, +an} Crdt.PN{+bp, +bn}:
      pn_eq(Crdt.GCounter.merge(ap, bp), Crdt.GCounter.merge(an, bn),
        Crdt.GCounter.merge(bp, ap), Crdt.GCounter.merge(bn, an),
        Laws.merge_comm(ap, bp), Laws.merge_comm(an, bn))

def Laws.pn_merge_assoc(a, b, c):
  match a b c:
    case Crdt.PN{+ap, +an} Crdt.PN{+bp, +bn} Crdt.PN{+cp, +cn}:
      pn_eq(Crdt.GCounter.merge(Crdt.GCounter.merge(ap, bp), cp),
        Crdt.GCounter.merge(Crdt.GCounter.merge(an, bn), cn),
        Crdt.GCounter.merge(ap, Crdt.GCounter.merge(bp, cp)),
        Crdt.GCounter.merge(an, Crdt.GCounter.merge(bn, cn)),
        Laws.merge_assoc(ap, bp, cp), Laws.merge_assoc(an, bn, cn))

def Laws.pn_merge_idem(a):
  match a:
    case Crdt.PN{+p, +n}:
      pn_eq(Crdt.GCounter.merge(p, p), Crdt.GCounter.merge(n, n), p, n,
        Laws.merge_idem(p), Laws.merge_idem(n))

def Laws.pn_merge_upper_l(a, b):
  match a b:
    case Crdt.PN{+ap, +an} Crdt.PN{+bp, +bn}:
      MBool.and_eq_true(Crdt.GCounter.le(ap, Crdt.GCounter.merge(ap, bp)),
        Crdt.GCounter.le(an, Crdt.GCounter.merge(an, bn)),
        Laws.merge_upper_l(ap, bp), Laws.merge_upper_l(an, bn))

def Laws.pn_merge_upper_r(a, b):
  +a = a
  +b = b
  %Laws.pn_merge_comm(b, a) : {Crdt.PNCounter.le(b, _) == True{} : Bool}
  Laws.pn_merge_upper_l(b, a)

def Laws.pn_merge_least(a, b, c, ha, hb):
  match a b c:
    case Crdt.PN{+ap, +an} Crdt.PN{+bp, +bn} Crdt.PN{+cp, +cn}:
      +ha = ha
      +hb = hb
      MBool.and_eq_true(Crdt.GCounter.le(Crdt.GCounter.merge(ap, bp), cp),
        Crdt.GCounter.le(Crdt.GCounter.merge(an, bn), cn),
        Laws.merge_least(ap, bp, cp,
          MBool.eq_true_of_and_left(Crdt.GCounter.le(ap, cp), Crdt.GCounter.le(an, cn), ha),
          MBool.eq_true_of_and_left(Crdt.GCounter.le(bp, cp), Crdt.GCounter.le(bn, cn), hb)),
        Laws.merge_least(an, bn, cn,
          MBool.eq_true_of_and_right(Crdt.GCounter.le(ap, cp), Crdt.GCounter.le(an, cn), ha),
          MBool.eq_true_of_and_right(Crdt.GCounter.le(bp, cp), Crdt.GCounter.le(bn, cn), hb)))

def Laws.pn_le_refl(a):
  match a:
    case Crdt.PN{+p, +n}:
      MBool.and_eq_true(Crdt.GCounter.le(p, p), Crdt.GCounter.le(n, n),
        Laws.le_refl(p), Laws.le_refl(n))

def Laws.pn_le_trans(a, b, c, hab, hbc):
  match a b c:
    case Crdt.PN{+ap, +an} Crdt.PN{+bp, +bn} Crdt.PN{+cp, +cn}:
      +hab = hab
      +hbc = hbc
      MBool.and_eq_true(Crdt.GCounter.le(ap, cp), Crdt.GCounter.le(an, cn),
        Laws.le_trans(ap, bp, cp,
          MBool.eq_true_of_and_left(Crdt.GCounter.le(ap, bp), Crdt.GCounter.le(an, bn), hab),
          MBool.eq_true_of_and_left(Crdt.GCounter.le(bp, cp), Crdt.GCounter.le(bn, cn), hbc)),
        Laws.le_trans(an, bn, cn,
          MBool.eq_true_of_and_right(Crdt.GCounter.le(ap, bp), Crdt.GCounter.le(an, bn), hab),
          MBool.eq_true_of_and_right(Crdt.GCounter.le(bp, cp), Crdt.GCounter.le(bn, cn), hbc)))

def Laws.pn_le_antisymm(a, b, va, vb, hab, hba):
  match a b:
    case Crdt.PN{+ap, +an} Crdt.PN{+bp, +bn}:
      +va = va
      +vb = vb
      +hab = hab
      +hba = hba
      pn_eq(ap, an, bp, bn,
        Laws.le_antisymm(ap, bp,
          MBool.eq_true_of_and_left(Crdt.GCounter.valid(ap), Crdt.GCounter.valid(an), va),
          MBool.eq_true_of_and_left(Crdt.GCounter.valid(bp), Crdt.GCounter.valid(bn), vb),
          MBool.eq_true_of_and_left(Crdt.GCounter.le(ap, bp), Crdt.GCounter.le(an, bn), hab),
          MBool.eq_true_of_and_left(Crdt.GCounter.le(bp, ap), Crdt.GCounter.le(bn, an), hba)),
        Laws.le_antisymm(an, bn,
          MBool.eq_true_of_and_right(Crdt.GCounter.valid(ap), Crdt.GCounter.valid(an), va),
          MBool.eq_true_of_and_right(Crdt.GCounter.valid(bp), Crdt.GCounter.valid(bn), vb),
          MBool.eq_true_of_and_right(Crdt.GCounter.le(ap, bp), Crdt.GCounter.le(an, bn), hab),
          MBool.eq_true_of_and_right(Crdt.GCounter.le(bp, ap), Crdt.GCounter.le(bn, an), hba)))

def Laws.pn_merge_mono(a, b, c, hab):
  match a b c:
    case Crdt.PN{+ap, +an} Crdt.PN{+bp, +bn} Crdt.PN{+cp, +cn}:
      +hab = hab
      MBool.and_eq_true(Crdt.GCounter.le(Crdt.GCounter.merge(ap, cp), Crdt.GCounter.merge(bp, cp)),
        Crdt.GCounter.le(Crdt.GCounter.merge(an, cn), Crdt.GCounter.merge(bn, cn)),
        Laws.merge_mono(ap, bp, cp,
          MBool.eq_true_of_and_left(Crdt.GCounter.le(ap, bp), Crdt.GCounter.le(an, bn), hab)),
        Laws.merge_mono(an, bn, cn,
          MBool.eq_true_of_and_right(Crdt.GCounter.le(ap, bp), Crdt.GCounter.le(an, bn), hab)))

def pn_all_parts(+xs: List<&2, Crdt.PNCounter>) ->
  {Crdt.PNCounter.merge_all(xs) == Crdt.PN{
    Crdt.GCounter.merge_all(Laws.pn.parts(xs, False{})),
    Crdt.GCounter.merge_all(Laws.pn.parts(xs, True{}))} : Crdt.PNCounter}:
  match xs:
    case Nil{}:
      {==}
    case Con{Crdt.PN{+p, +n}, +t}:
      Equal.cong(Crdt.PNCounter, Crdt.PNCounter, s => Crdt.PNCounter.merge(Crdt.PN{p, n}, s),
        Crdt.PNCounter.merge_all(t), Crdt.PN{
          Crdt.GCounter.merge_all(Laws.pn.parts(t, False{})),
          Crdt.GCounter.merge_all(Laws.pn.parts(t, True{}))}, pn_all_parts(t))

def Laws.pn_converge(xs, ys, hx, hy):
  +xs = xs
  +ys = ys
  +hx = hx
  +hy = hy
  +xp = Laws.pn.parts(xs, False{})
  +xn = Laws.pn.parts(xs, True{})
  +yp = Laws.pn.parts(ys, False{})
  +yn = Laws.pn.parts(ys, True{})
  Equal.trans(Crdt.PNCounter, Crdt.PNCounter.merge_all(xs),
    Crdt.PN{Crdt.GCounter.merge_all(xp), Crdt.GCounter.merge_all(xn)}, Crdt.PNCounter.merge_all(ys),
    pn_all_parts(xs),
    Equal.trans(Crdt.PNCounter,
      Crdt.PN{Crdt.GCounter.merge_all(xp), Crdt.GCounter.merge_all(xn)},
      Crdt.PN{Crdt.GCounter.merge_all(yp), Crdt.GCounter.merge_all(yn)}, Crdt.PNCounter.merge_all(ys),
      pn_eq(Crdt.GCounter.merge_all(xp), Crdt.GCounter.merge_all(xn),
        Crdt.GCounter.merge_all(yp), Crdt.GCounter.merge_all(yn),
        Laws.converge(xp, yp,
          MBool.eq_true_of_and_left(Laws.covers(xp, yp), Laws.covers(xn, yn), hx),
          MBool.eq_true_of_and_left(Laws.covers(yp, xp), Laws.covers(yn, xn), hy)),
        Laws.converge(xn, yn,
          MBool.eq_true_of_and_right(Laws.covers(xp, yp), Laws.covers(xn, yn), hx),
          MBool.eq_true_of_and_right(Laws.covers(yp, xp), Laws.covers(yn, xn), hy))),
      Equal.sym(Crdt.PNCounter, Crdt.PNCounter.merge_all(ys),
        Crdt.PN{Crdt.GCounter.merge_all(yp), Crdt.GCounter.merge_all(yn)}, pn_all_parts(ys))))

def Laws.pn_from_cbor_trailing_zero():
  {==}

def Laws.pn_from_cbor_negative():
  {==}

def Laws.pn_from_cbor_over_cap():
  {==}

# KCounter.
def Refl(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> {cmp(x, x) == EQ{} : Cmp}

def Eq(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}

def Flip(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> {cmp(y, x) == Laws.flip(cmp(x, y)) : Cmp}

def KG(~K: Data, ~cmp: K -> K -> Cmp, s: Crdt.KCounter<K>, +k: K) -> U32:
  Crdt.KCounter.get(~K, ~cmp, s, k)

def KM(~K: Data, ~cmp: K -> K -> Cmp, +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>) -> Crdt.KCounter<K>:
  Crdt.KCounter.merge(~K, ~cmp, a, b)

def KL(~K: Data, ~cmp: K -> K -> Cmp, a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>) -> Bool:
  Crdt.KCounter.le(~K, ~cmp, a, b)

def KV(~K: Data, ~cmp: K -> K -> Cmp, s: Crdt.KCounter<K>) -> Bool:
  Crdt.KCounter.valid(~K, ~cmp, s)

def KA(~K: Data, ~cmp: K -> K -> Cmp, s: Crdt.KCounter<K>, +lo: K) -> Bool:
  Crdt.KCounter.above(~K, ~cmp, s, lo)

def KMA(~K: Data, ~cmp: K -> K -> Cmp, xs: List<&2, Crdt.KCounter<K>>) -> Crdt.KCounter<K>:
  Crdt.KCounter.merge_all(~K, ~cmp, xs)

def KMG(~K: Data, ~cmp: K -> K -> Cmp, +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>, q: Cmp) -> Crdt.KCounter<K>:
  Crdt.KCounter.merge.go(~K, ~cmp, a, b, q)

def KH2(~K: Data, ~cmp: K -> K -> Cmp, a: Crdt.KCounter<K>, b: Crdt.KCounter<K>) -> Cmp:
  Crdt.KCounter.heads(~K, ~cmp, a, b)

def KH(~K: Data, ~cmp: K -> K -> Cmp, +x: K, b: Crdt.KCounter<K>) -> Cmp:
  Crdt.KCounter.head(~K, ~cmp, x, b)

def lt_true(c: Cmp, e: {c == LT{} : Cmp}) -> {Cmp.is_lt(c) == True{} : Bool}:
  %Equal.sym(Cmp, c, LT{}, e) : {Cmp.is_lt(_) == True{} : Bool}
  {==}

def eq_of_is_eq(c: Cmp, e: {Cmp.is_eq(c) == True{} : Bool}) -> {c == EQ{} : Cmp}:
  match c:
    case LT{}:
      Empty.absurd({LT{} == EQ{} : Cmp}, MBool.false_ne_true()(e))
    case EQ{}:
      {==}
    case GT{}:
      Empty.absurd({GT{} == EQ{} : Cmp}, MBool.false_ne_true()(e))

def gt_flip(
  ~K: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp), +x: K, +y: K, e: {cmp(x, y) == GT{} : Cmp}
) -> {cmp(y, x) == LT{} : Cmp}:
  Equal.trans(Cmp, cmp(y, x), Laws.flip(cmp(x, y)), LT{}, flip(x, y),
    Equal.cong(Cmp, Cmp, c => Laws.flip(c), cmp(x, y), GT{}, e))

# U32 order and maximum facts.
def zero_le(+a: U32) -> {U32.is_le(0, a) == True{} : Bool}:
  %Lemmas.u32_le_nat_sym(0, a) : {_ == True{} : Bool}
  MNat.zero_le(U32.to_nat(a))

def le_trans(
  +a: U32, +b: U32, +c: U32, ab: {U32.is_le(a, b) == True{} : Bool}, bc: {U32.is_le(b, c) == True{} : Bool}
) -> {U32.is_le(a, c) == True{} : Bool}:
  %Lemmas.u32_le_nat_sym(a, c) : {_ == True{} : Bool}
  MNat.le_trans(U32.to_nat(a), U32.to_nat(b), U32.to_nat(c),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(a), U32.to_nat(b)), U32.is_le(a, b), True{}, Lemmas.u32_le_nat_sym(a, b), ab),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(b), U32.to_nat(c)), U32.is_le(b, c), True{}, Lemmas.u32_le_nat_sym(b, c), bc))

def le_antisymm(
  +a: U32, +b: U32, ab: {U32.is_le(a, b) == True{} : Bool}, ba: {U32.is_le(b, a) == True{} : Bool}
) -> {a == b : U32}:
  Lemmas.u32_to_nat_inj(a, b, MNat.le_antisymm(U32.to_nat(a), U32.to_nat(b),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(a), U32.to_nat(b)), U32.is_le(a, b), True{}, Lemmas.u32_le_nat_sym(a, b), ab),
    Equal.trans(Bool, Nat.is_le(U32.to_nat(b), U32.to_nat(a)), U32.is_le(b, a), True{}, Lemmas.u32_le_nat_sym(b, a), ba)))

# c <= u and u == v give c <= v.
def le_rw(+c: U32, -u: U32, -v: U32, e: {u == v : U32}, h: {U32.is_le(c, u) == True{} : Bool}) -> {U32.is_le(c, v) == True{} : Bool}:
  %e : {U32.is_le(c, _) == True{} : Bool}
  h

def le_rw_l(-u: U32, -v: U32, +c: U32, e: {u == v : U32}, h: {U32.is_le(u, c) == True{} : Bool}) -> {U32.is_le(v, c) == True{} : Bool}:
  %e : {U32.is_le(_, c) == True{} : Bool}
  h

def hit_max(q: Cmp, +c: U32, +d: U32) -> {Crdt.KCounter.hit(q, U32.max(c, d)) == U32.max(Crdt.KCounter.hit(q, c), Crdt.KCounter.hit(q, d)) : U32}:
  match q:
    case LT{}:
      Equal.sym(U32, U32.max(0, 0), 0, Lemmas.u32_max_self(0))
    case EQ{}:
      {==}
    case GT{}:
      Equal.sym(U32, U32.max(0, 0), 0, Lemmas.u32_max_self(0))

# get of a merge is the maximum of the two gets, for any states.
def get_merge.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), a: Crdt.KCounter<K>, b: Crdt.KCounter<K>, q: Cmp, +k: K,
  e: {Crdt.KCounter.heads(~K, ~cmp, a, b) == q : Cmp}
) -> {KG(~K, ~cmp, KMG(~K, ~cmp, a, b, q), k) == U32.max(KG(~K, ~cmp, a, k), KG(~K, ~cmp, b, k)) : U32}:
  match a b q:
    case Crdt.KNil{} +b _:
      Equal.sym(U32, U32.max(0, KG(~K, ~cmp, b, k)), KG(~K, ~cmp, b, k), Lemmas.u32_max0_l(KG(~K, ~cmp, b, k)))
    case Crdt.KCon{+x, +c, +r} Crdt.KNil{} _:
      Equal.sym(U32, U32.max(KG(~K, ~cmp, Crdt.KCon{x, c, r}, k), 0), KG(~K, ~cmp, Crdt.KCon{x, c, r}, k),
        Lemmas.u32_max0_r(KG(~K, ~cmp, Crdt.KCon{x, c, r}, k)))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} LT{}:
      +p = Crdt.KCounter.hit(cmp(k, x), c)
      +gb = KG(~K, ~cmp, Crdt.KCon{y, d, t}, k)
      +gr = KG(~K, ~cmp, r, k)
      Equal.trans(U32, U32.max(p, KG(~K, ~cmp, KM(~K, ~cmp, r, Crdt.KCon{y, d, t}), k)),
        U32.max(p, U32.max(gr, gb)), U32.max(U32.max(p, gr), gb),
        Equal.cong(U32, U32, z => U32.max(p, z), KG(~K, ~cmp, KM(~K, ~cmp, r, Crdt.KCon{y, d, t}), k),
          U32.max(gr, gb), get_merge.go(~K, ~cmp, ~eq, r, Crdt.KCon{y, d, t}, KH2(~K, ~cmp, r, Crdt.KCon{y, d, t}), k, {==})),
        Equal.sym(U32, U32.max(U32.max(p, gr), gb), U32.max(p, U32.max(gr, gb)), Lemmas.u32_max_assoc(p, gr, gb)))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} EQ{}:
      +p = Crdt.KCounter.hit(cmp(k, x), c)
      +px = Crdt.KCounter.hit(cmp(k, x), d)
      +gr = KG(~K, ~cmp, r, k)
      +gt = KG(~K, ~cmp, t, k)
      +m = KG(~K, ~cmp, KM(~K, ~cmp, r, t), k)
      Equal.trans(U32, U32.max(Crdt.KCounter.hit(cmp(k, x), U32.max(c, d)), m),
        U32.max(U32.max(p, px), U32.max(gr, gt)),
        U32.max(U32.max(p, gr), U32.max(Crdt.KCounter.hit(cmp(k, y), d), gt)),
        Equal.trans(U32, U32.max(Crdt.KCounter.hit(cmp(k, x), U32.max(c, d)), m),
          U32.max(U32.max(p, px), m), U32.max(U32.max(p, px), U32.max(gr, gt)),
          Equal.cong(U32, U32, z => U32.max(z, m), Crdt.KCounter.hit(cmp(k, x), U32.max(c, d)), U32.max(p, px),
            hit_max(cmp(k, x), c, d)),
          Equal.cong(U32, U32, z => U32.max(U32.max(p, px), z), m, U32.max(gr, gt),
            get_merge.go(~K, ~cmp, ~eq, r, t, KH2(~K, ~cmp, r, t), k, {==}))),
        Equal.trans(U32, U32.max(U32.max(p, px), U32.max(gr, gt)),
          U32.max(U32.max(p, gr), U32.max(px, gt)),
          U32.max(U32.max(p, gr), U32.max(Crdt.KCounter.hit(cmp(k, y), d), gt)),
          Lemmas.u32_max_four(p, px, gr, gt),
          Equal.cong(K, U32, z => U32.max(U32.max(p, gr), U32.max(Crdt.KCounter.hit(cmp(k, z), d), gt)),
            x, y, eq(x, y, e))))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} GT{}:
      +pq = Crdt.KCounter.hit(cmp(k, y), d)
      +ga = KG(~K, ~cmp, Crdt.KCon{x, c, r}, k)
      +gt = KG(~K, ~cmp, t, k)
      Equal.trans(U32, U32.max(pq, KG(~K, ~cmp, KM(~K, ~cmp, Crdt.KCon{x, c, r}, t), k)),
        U32.max(pq, U32.max(ga, gt)), U32.max(ga, U32.max(pq, gt)),
        Equal.cong(U32, U32, z => U32.max(pq, z), KG(~K, ~cmp, KM(~K, ~cmp, Crdt.KCon{x, c, r}, t), k),
          U32.max(ga, gt), get_merge.go(~K, ~cmp, ~eq, Crdt.KCon{x, c, r}, t, KH2(~K, ~cmp, Crdt.KCon{x, c, r}, t), k, {==})),
        Lemmas.u32_max_left_comm(pq, ga, gt))

def get_merge(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>, +k: K
) -> {KG(~K, ~cmp, KM(~K, ~cmp, a, b), k) == U32.max(KG(~K, ~cmp, a, k), KG(~K, ~cmp, b, k)) : U32}:
  get_merge.go(~K, ~cmp, ~eq, a, b, KH2(~K, ~cmp, a, b), k, {==})

def Laws.k_merge_comm(K, cmp, eq, a, b, k):
  +a = a
  +b = b
  Equal.trans(U32, KG(~K, ~cmp, KM(~K, ~cmp, a, b), k), U32.max(KG(~K, ~cmp, a, k), KG(~K, ~cmp, b, k)),
    KG(~K, ~cmp, KM(~K, ~cmp, b, a), k), get_merge(~K, ~cmp, ~eq, a, b, k),
    Equal.trans(U32, U32.max(KG(~K, ~cmp, a, k), KG(~K, ~cmp, b, k)), U32.max(KG(~K, ~cmp, b, k), KG(~K, ~cmp, a, k)),
      KG(~K, ~cmp, KM(~K, ~cmp, b, a), k), Lemmas.u32_max_comm(KG(~K, ~cmp, a, k), KG(~K, ~cmp, b, k)),
      Equal.sym(U32, KG(~K, ~cmp, KM(~K, ~cmp, b, a), k), U32.max(KG(~K, ~cmp, b, k), KG(~K, ~cmp, a, k)),
        get_merge(~K, ~cmp, ~eq, b, a, k))))

def Laws.k_merge_assoc(K, cmp, eq, a, b, c, k):
  +a = a
  +b = b
  +c = c
  +ga = KG(~K, ~cmp, a, k)
  +gb = KG(~K, ~cmp, b, k)
  +gc = KG(~K, ~cmp, c, k)
  Equal.trans(U32, KG(~K, ~cmp, KM(~K, ~cmp, KM(~K, ~cmp, a, b), c), k),
    U32.max(U32.max(ga, gb), gc), KG(~K, ~cmp, KM(~K, ~cmp, a, KM(~K, ~cmp, b, c)), k),
    Equal.trans(U32, KG(~K, ~cmp, KM(~K, ~cmp, KM(~K, ~cmp, a, b), c), k),
      U32.max(KG(~K, ~cmp, KM(~K, ~cmp, a, b), k), gc), U32.max(U32.max(ga, gb), gc),
      get_merge(~K, ~cmp, ~eq, KM(~K, ~cmp, a, b), c, k),
      Equal.cong(U32, U32, z => U32.max(z, gc), KG(~K, ~cmp, KM(~K, ~cmp, a, b), k), U32.max(ga, gb),
        get_merge(~K, ~cmp, ~eq, a, b, k))),
    Equal.trans(U32, U32.max(U32.max(ga, gb), gc), U32.max(ga, U32.max(gb, gc)),
      KG(~K, ~cmp, KM(~K, ~cmp, a, KM(~K, ~cmp, b, c)), k), Lemmas.u32_max_assoc(ga, gb, gc),
      Equal.sym(U32, KG(~K, ~cmp, KM(~K, ~cmp, a, KM(~K, ~cmp, b, c)), k), U32.max(ga, U32.max(gb, gc)),
        Equal.trans(U32, KG(~K, ~cmp, KM(~K, ~cmp, a, KM(~K, ~cmp, b, c)), k),
          U32.max(ga, KG(~K, ~cmp, KM(~K, ~cmp, b, c), k)), U32.max(ga, U32.max(gb, gc)),
          get_merge(~K, ~cmp, ~eq, a, KM(~K, ~cmp, b, c), k),
          Equal.cong(U32, U32, z => U32.max(ga, z), KG(~K, ~cmp, KM(~K, ~cmp, b, c), k), U32.max(gb, gc),
            get_merge(~K, ~cmp, ~eq, b, c, k))))))

def Laws.k_merge_idem(K, cmp, eq, a, k):
  +a = a
  Equal.trans(U32, KG(~K, ~cmp, KM(~K, ~cmp, a, a), k), U32.max(KG(~K, ~cmp, a, k), KG(~K, ~cmp, a, k)),
    KG(~K, ~cmp, a, k), get_merge(~K, ~cmp, ~eq, a, a, k), Lemmas.u32_max_self(KG(~K, ~cmp, a, k)))

# le, read through get.
def hit_le(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), q: Cmp, +k: K, +x: K, +c: U32, +b: Crdt.KCounter<K>,
  e: {cmp(k, x) == q : Cmp}, h: {U32.is_le(c, KG(~K, ~cmp, b, x)) == True{} : Bool}
) -> {U32.is_le(Crdt.KCounter.hit(q, c), KG(~K, ~cmp, b, k)) == True{} : Bool}:
  match q:
    case LT{}:
      zero_le(KG(~K, ~cmp, b, k))
    case EQ{}:
      %Equal.sym(K, k, x, eq(k, x, e)) : {U32.is_le(c, KG(~K, ~cmp, b, _)) == True{} : Bool}
      h
    case GT{}:
      zero_le(KG(~K, ~cmp, b, k))

def le_get(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>,
  h: {KL(~K, ~cmp, a, b) == True{} : Bool}, +k: K
) -> {U32.is_le(KG(~K, ~cmp, a, k), KG(~K, ~cmp, b, k)) == True{} : Bool}:
  match a:
    case Crdt.KNil{}:
      zero_le(KG(~K, ~cmp, b, k))
    case Crdt.KCon{+x, +c, +r}:
      +h = h
      Lemmas.u32_max_le(Crdt.KCounter.hit(cmp(k, x), c), KG(~K, ~cmp, r, k), KG(~K, ~cmp, b, k),
        hit_le(~K, ~cmp, ~eq, cmp(k, x), k, x, c, b, {==},
          MBool.eq_true_of_and_left(U32.is_le(c, KG(~K, ~cmp, b, x)), KL(~K, ~cmp, r, b), h)),
        le_get(~K, ~cmp, ~eq, r, b,
          MBool.eq_true_of_and_right(U32.is_le(c, KG(~K, ~cmp, b, x)), KL(~K, ~cmp, r, b), h), k))

# Adding an entry to b keeps a <= b.
def le_ext(
  ~K: Data, ~cmp: K -> K -> Cmp, a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>, +x: K, +c: U32,
  h: {KL(~K, ~cmp, a, b) == True{} : Bool}
) -> {KL(~K, ~cmp, a, Crdt.KCon{x, c, b}) == True{} : Bool}:
  match a:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{+y, +d, +r}:
      +h = h
      MBool.and_eq_true(U32.is_le(d, KG(~K, ~cmp, Crdt.KCon{x, c, b}, y)), KL(~K, ~cmp, r, Crdt.KCon{x, c, b}),
        le_trans(d, KG(~K, ~cmp, b, y), KG(~K, ~cmp, Crdt.KCon{x, c, b}, y),
          MBool.eq_true_of_and_left(U32.is_le(d, KG(~K, ~cmp, b, y)), KL(~K, ~cmp, r, b), h),
          Lemmas.u32_le_max_r(Crdt.KCounter.hit(cmp(y, x), c), KG(~K, ~cmp, b, y))),
        le_ext(~K, ~cmp, r, b, x, c,
          MBool.eq_true_of_and_right(U32.is_le(d, KG(~K, ~cmp, b, y)), KL(~K, ~cmp, r, b), h)))

def le_self(~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), a: Crdt.KCounter<K>) -> {KL(~K, ~cmp, a, a) == True{} : Bool}:
  match a:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{+x, +c, +r}:
      MBool.and_eq_true(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{x, c, r}, x)), KL(~K, ~cmp, r, Crdt.KCon{x, c, r}),
        %Equal.sym(Cmp, cmp(x, x), EQ{}, refl(x)) : {U32.is_le(c, U32.max(Crdt.KCounter.hit(_, c), KG(~K, ~cmp, r, x))) == True{} : Bool}
        Lemmas.u32_le_max_l(c, KG(~K, ~cmp, r, x)),
        le_ext(~K, ~cmp, r, r, x, c, le_self(~K, ~cmp, ~refl, r)))

def le_merge_r(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), s: Crdt.KCounter<K>, +t: Crdt.KCounter<K>, +b: Crdt.KCounter<K>,
  h: {KL(~K, ~cmp, s, t) == True{} : Bool}
) -> {KL(~K, ~cmp, s, KM(~K, ~cmp, t, b)) == True{} : Bool}:
  match s:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{+x, +c, +r}:
      +h = h
      MBool.and_eq_true(U32.is_le(c, KG(~K, ~cmp, KM(~K, ~cmp, t, b), x)), KL(~K, ~cmp, r, KM(~K, ~cmp, t, b)),
        le_rw(c, U32.max(KG(~K, ~cmp, t, x), KG(~K, ~cmp, b, x)), KG(~K, ~cmp, KM(~K, ~cmp, t, b), x),
          Equal.sym(U32, KG(~K, ~cmp, KM(~K, ~cmp, t, b), x), U32.max(KG(~K, ~cmp, t, x), KG(~K, ~cmp, b, x)),
            get_merge(~K, ~cmp, ~eq, t, b, x)),
          le_trans(c, KG(~K, ~cmp, t, x), U32.max(KG(~K, ~cmp, t, x), KG(~K, ~cmp, b, x)),
            MBool.eq_true_of_and_left(U32.is_le(c, KG(~K, ~cmp, t, x)), KL(~K, ~cmp, r, t), h),
            Lemmas.u32_le_max_l(KG(~K, ~cmp, t, x), KG(~K, ~cmp, b, x)))),
        le_merge_r(~K, ~cmp, ~eq, r, t, b,
          MBool.eq_true_of_and_right(U32.is_le(c, KG(~K, ~cmp, t, x)), KL(~K, ~cmp, r, t), h)))

def le_merge_l(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), s: Crdt.KCounter<K>, +t: Crdt.KCounter<K>, +a: Crdt.KCounter<K>,
  h: {KL(~K, ~cmp, s, t) == True{} : Bool}
) -> {KL(~K, ~cmp, s, KM(~K, ~cmp, a, t)) == True{} : Bool}:
  match s:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{+x, +c, +r}:
      +h = h
      MBool.and_eq_true(U32.is_le(c, KG(~K, ~cmp, KM(~K, ~cmp, a, t), x)), KL(~K, ~cmp, r, KM(~K, ~cmp, a, t)),
        le_rw(c, U32.max(KG(~K, ~cmp, a, x), KG(~K, ~cmp, t, x)), KG(~K, ~cmp, KM(~K, ~cmp, a, t), x),
          Equal.sym(U32, KG(~K, ~cmp, KM(~K, ~cmp, a, t), x), U32.max(KG(~K, ~cmp, a, x), KG(~K, ~cmp, t, x)),
            get_merge(~K, ~cmp, ~eq, a, t, x)),
          le_trans(c, KG(~K, ~cmp, t, x), U32.max(KG(~K, ~cmp, a, x), KG(~K, ~cmp, t, x)),
            MBool.eq_true_of_and_left(U32.is_le(c, KG(~K, ~cmp, t, x)), KL(~K, ~cmp, r, t), h),
            Lemmas.u32_le_max_r(KG(~K, ~cmp, a, x), KG(~K, ~cmp, t, x)))),
        le_merge_l(~K, ~cmp, ~eq, r, t, a,
          MBool.eq_true_of_and_right(U32.is_le(c, KG(~K, ~cmp, t, x)), KL(~K, ~cmp, r, t), h)))

def upper_l(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp), +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>
) -> {KL(~K, ~cmp, a, KM(~K, ~cmp, a, b)) == True{} : Bool}:
  le_merge_r(~K, ~cmp, ~eq, a, a, b, le_self(~K, ~cmp, ~refl, a))

def Laws.k_merge_upper_l(K, cmp, refl, eq, a, b):
  upper_l(~K, ~cmp, ~refl, ~eq, a, b)

def Laws.k_merge_upper_r(K, cmp, refl, eq, a, b):
  +b = b
  le_merge_l(~K, ~cmp, ~eq, b, b, a, le_self(~K, ~cmp, ~refl, b))

def least.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), a: Crdt.KCounter<K>, b: Crdt.KCounter<K>, q: Cmp,
  +c: Crdt.KCounter<K>, +ha: {KL(~K, ~cmp, a, c) == True{} : Bool}, +hb: {KL(~K, ~cmp, b, c) == True{} : Bool},
  e: {KH2(~K, ~cmp, a, b) == q : Cmp}
) -> {KL(~K, ~cmp, KMG(~K, ~cmp, a, b, q), c) == True{} : Bool}:
  match a b q:
    case Crdt.KNil{} _ _:
      hb
    case Crdt.KCon{x, d, r} Crdt.KNil{} _:
      ha
    case Crdt.KCon{+x, +cx, +r} Crdt.KCon{+y, +cy, +t} LT{}:
      MBool.and_eq_true(U32.is_le(cx, KG(~K, ~cmp, c, x)), KL(~K, ~cmp, KM(~K, ~cmp, r, Crdt.KCon{y, cy, t}), c),
        MBool.eq_true_of_and_left(U32.is_le(cx, KG(~K, ~cmp, c, x)), KL(~K, ~cmp, r, c), ha),
        least.go(~K, ~cmp, ~eq, r, Crdt.KCon{y, cy, t}, KH2(~K, ~cmp, r, Crdt.KCon{y, cy, t}), c,
          MBool.eq_true_of_and_right(U32.is_le(cx, KG(~K, ~cmp, c, x)), KL(~K, ~cmp, r, c), ha), hb, {==}))
    case Crdt.KCon{+x, +cx, +r} Crdt.KCon{+y, +cy, +t} EQ{}:
      MBool.and_eq_true(U32.is_le(U32.max(cx, cy), KG(~K, ~cmp, c, x)), KL(~K, ~cmp, KM(~K, ~cmp, r, t), c),
        Lemmas.u32_max_le(cx, cy, KG(~K, ~cmp, c, x),
          MBool.eq_true_of_and_left(U32.is_le(cx, KG(~K, ~cmp, c, x)), KL(~K, ~cmp, r, c), ha),
          %Equal.sym(K, x, y, eq(x, y, e)) : {U32.is_le(cy, KG(~K, ~cmp, c, _)) == True{} : Bool}
          MBool.eq_true_of_and_left(U32.is_le(cy, KG(~K, ~cmp, c, y)), KL(~K, ~cmp, t, c), hb)),
        least.go(~K, ~cmp, ~eq, r, t, KH2(~K, ~cmp, r, t), c,
          MBool.eq_true_of_and_right(U32.is_le(cx, KG(~K, ~cmp, c, x)), KL(~K, ~cmp, r, c), ha),
          MBool.eq_true_of_and_right(U32.is_le(cy, KG(~K, ~cmp, c, y)), KL(~K, ~cmp, t, c), hb), {==}))
    case Crdt.KCon{+x, +cx, +r} Crdt.KCon{+y, +cy, +t} GT{}:
      MBool.and_eq_true(U32.is_le(cy, KG(~K, ~cmp, c, y)), KL(~K, ~cmp, KM(~K, ~cmp, Crdt.KCon{x, cx, r}, t), c),
        MBool.eq_true_of_and_left(U32.is_le(cy, KG(~K, ~cmp, c, y)), KL(~K, ~cmp, t, c), hb),
        least.go(~K, ~cmp, ~eq, Crdt.KCon{x, cx, r}, t, KH2(~K, ~cmp, Crdt.KCon{x, cx, r}, t), c, ha,
          MBool.eq_true_of_and_right(U32.is_le(cy, KG(~K, ~cmp, c, y)), KL(~K, ~cmp, t, c), hb), {==}))

def Laws.k_merge_least(K, cmp, eq, a, b, c, ha, hb):
  +a = a
  +b = b
  least.go(~K, ~cmp, ~eq, a, b, KH2(~K, ~cmp, a, b), c, ha, hb, {==})

def KI(~K: Data, ~cmp: K -> K -> Cmp, s: Crdt.KCounter<K>, +k: K) -> Maybe<&2, Crdt.KCounter<K>>:
  Crdt.KCounter.inc(~K, ~cmp, s, k)

# x's own entry is at least c in KCon{x, n, u} when c <= n.
def le_head(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), +x: K, +c: U32, +n: U32, +u: Crdt.KCounter<K>,
  h: {U32.is_le(c, n) == True{} : Bool}
) -> {U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{x, n, u}, x)) == True{} : Bool}:
  %Equal.sym(Cmp, cmp(x, x), EQ{}, refl(x)) : {U32.is_le(c, U32.max(Crdt.KCounter.hit(_, n), KG(~K, ~cmp, u, x))) == True{} : Bool}
  le_trans(c, n, U32.max(n, KG(~K, ~cmp, u, x)), h, Lemmas.u32_le_max_l(n, KG(~K, ~cmp, u, x)))

def k_grows_cons(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), m: Maybe<&2, Crdt.KCounter<K>>, +x: K, +c: U32,
  +r: Crdt.KCounter<K>, h: {Laws.k.grows(~K, ~cmp, r, m) == True{} : Bool}
) -> {Laws.k.grows(~K, ~cmp, Crdt.KCon{x, c, r}, Crdt.KCounter.cons(K, x, c, m)) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{+u}:
      MBool.and_eq_true(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{x, c, u}, x)), KL(~K, ~cmp, r, Crdt.KCon{x, c, u}),
        le_head(~K, ~cmp, ~refl, x, c, c, u, le_refl(c)), le_ext(~K, ~cmp, r, u, x, c, h))

def k_inc_at_grows(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ok: Bool, +x: K, +c: U32, +n: U32, +r: Crdt.KCounter<K>,
  e: {U32.is_lt(c, n) == ok : Bool}
) -> {Laws.k.grows(~K, ~cmp, Crdt.KCon{x, c, r}, Crdt.KCounter.inc.at(K, ok, x, n, r)) == True{} : Bool}:
  match ok:
    case True{}:
      MBool.and_eq_true(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{x, n, r}, x)), KL(~K, ~cmp, r, Crdt.KCon{x, n, r}),
        le_head(~K, ~cmp, ~refl, x, c, n, r, cmp_lt_le(U32.cmp(c, n), e)),
        le_ext(~K, ~cmp, r, r, x, n, le_self(~K, ~cmp, ~refl, r)))
    case False{}:
      {==}

def k_inc_grows.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), +s: Crdt.KCounter<K>, +k: K, q: Cmp
) -> {Laws.k.grows(~K, ~cmp, s, Crdt.KCounter.inc.go(~K, ~cmp, s, k, q)) == True{} : Bool}:
  match s q:
    case Crdt.KNil{} _:
      {==}
    case Crdt.KCon{+x, +c, +r} LT{}:
      le_ext(~K, ~cmp, Crdt.KCon{x, c, r}, Crdt.KCon{x, c, r}, k, 1, le_self(~K, ~cmp, ~refl, Crdt.KCon{x, c, r}))
    case Crdt.KCon{+x, +c, +r} EQ{}:
      k_inc_at_grows(~K, ~cmp, ~refl, U32.is_lt(c, U32.inc(c)), x, c, U32.inc(c), r, {==})
    case Crdt.KCon{+x, +c, +r} GT{}:
      k_grows_cons(~K, ~cmp, ~refl, KI(~K, ~cmp, r, k), x, c, r, k_inc_grows.go(~K, ~cmp, ~refl, r, k, KH(~K, ~cmp, k, r)))

def Laws.k_inc_grows(K, cmp, refl, s, k):
  +s = s
  +k = k
  k_inc_grows.go(~K, ~cmp, ~refl, s, k, KH(~K, ~cmp, k, s))

# Validity.
def above_merge.go(
  ~K: Data, ~cmp: K -> K -> Cmp, a: Crdt.KCounter<K>, b: Crdt.KCounter<K>, q: Cmp, +lo: K,
  +ha: {KA(~K, ~cmp, a, lo) == True{} : Bool}, +hb: {KA(~K, ~cmp, b, lo) == True{} : Bool}
) -> {KA(~K, ~cmp, KMG(~K, ~cmp, a, b, q), lo) == True{} : Bool}:
  match a b q:
    case Crdt.KNil{} _ _:
      hb
    case Crdt.KCon{x, c, r} Crdt.KNil{} _:
      ha
    case Crdt.KCon{x, c, r} Crdt.KCon{y, d, t} LT{}:
      ha
    case Crdt.KCon{x, c, r} Crdt.KCon{y, d, t} EQ{}:
      ha
    case Crdt.KCon{x, c, r} Crdt.KCon{y, d, t} GT{}:
      hb

def above_merge(
  ~K: Data, ~cmp: K -> K -> Cmp, +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>, +lo: K,
  +ha: {KA(~K, ~cmp, a, lo) == True{} : Bool}, +hb: {KA(~K, ~cmp, b, lo) == True{} : Bool}
) -> {KA(~K, ~cmp, KM(~K, ~cmp, a, b), lo) == True{} : Bool}:
  above_merge.go(~K, ~cmp, a, b, KH2(~K, ~cmp, a, b), lo, ha, hb)

def v.ne(~K: Data, ~cmp: K -> K -> Cmp, +x: K, +c: U32, +r: Crdt.KCounter<K>, h: {KV(~K, ~cmp, Crdt.KCon{x, c, r}) == True{} : Bool}) -> {U32.is_ne(c, 0) == True{} : Bool}:
  MBool.eq_true_of_and_left(U32.is_ne(c, 0), KA(~K, ~cmp, r, x),
    MBool.eq_true_of_and_left(Bool.and(U32.is_ne(c, 0), KA(~K, ~cmp, r, x)), KV(~K, ~cmp, r), h))

def v.above(~K: Data, ~cmp: K -> K -> Cmp, +x: K, +c: U32, +r: Crdt.KCounter<K>, h: {KV(~K, ~cmp, Crdt.KCon{x, c, r}) == True{} : Bool}) -> {KA(~K, ~cmp, r, x) == True{} : Bool}:
  MBool.eq_true_of_and_right(U32.is_ne(c, 0), KA(~K, ~cmp, r, x),
    MBool.eq_true_of_and_left(Bool.and(U32.is_ne(c, 0), KA(~K, ~cmp, r, x)), KV(~K, ~cmp, r), h))

def v.tail(~K: Data, ~cmp: K -> K -> Cmp, +x: K, +c: U32, +r: Crdt.KCounter<K>, h: {KV(~K, ~cmp, Crdt.KCon{x, c, r}) == True{} : Bool}) -> {KV(~K, ~cmp, r) == True{} : Bool}:
  MBool.eq_true_of_and_right(Bool.and(U32.is_ne(c, 0), KA(~K, ~cmp, r, x)), KV(~K, ~cmp, r), h)

def v.cons(
  ~K: Data, ~cmp: K -> K -> Cmp, +x: K, +c: U32, +r: Crdt.KCounter<K>,
  hc: {U32.is_ne(c, 0) == True{} : Bool}, ha: {KA(~K, ~cmp, r, x) == True{} : Bool}, hr: {KV(~K, ~cmp, r) == True{} : Bool}
) -> {KV(~K, ~cmp, Crdt.KCon{x, c, r}) == True{} : Bool}:
  MBool.and_eq_true(Bool.and(U32.is_ne(c, 0), KA(~K, ~cmp, r, x)), KV(~K, ~cmp, r),
    MBool.and_eq_true(U32.is_ne(c, 0), KA(~K, ~cmp, r, x), hc, ha), hr)

def merge_valid.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), ~flip: Flip(~K, ~cmp), a: Crdt.KCounter<K>, b: Crdt.KCounter<K>, q: Cmp,
  +ha: {KV(~K, ~cmp, a) == True{} : Bool}, +hb: {KV(~K, ~cmp, b) == True{} : Bool}, e: {KH2(~K, ~cmp, a, b) == q : Cmp}
) -> {KV(~K, ~cmp, KMG(~K, ~cmp, a, b, q)) == True{} : Bool}:
  match a b q:
    case Crdt.KNil{} _ _:
      hb
    case Crdt.KCon{x, c, r} Crdt.KNil{} _:
      ha
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} LT{}:
      v.cons(~K, ~cmp, x, c, KM(~K, ~cmp, r, Crdt.KCon{y, d, t}), v.ne(~K, ~cmp, x, c, r, ha),
        above_merge(~K, ~cmp, r, Crdt.KCon{y, d, t}, x, v.above(~K, ~cmp, x, c, r, ha), lt_true(cmp(x, y), e)),
        merge_valid.go(~K, ~cmp, ~eq, ~flip, r, Crdt.KCon{y, d, t}, KH2(~K, ~cmp, r, Crdt.KCon{y, d, t}),
          v.tail(~K, ~cmp, x, c, r, ha), hb, {==}))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} EQ{}:
      v.cons(~K, ~cmp, x, U32.max(c, d), KM(~K, ~cmp, r, t), Lemmas.u32_ne0_max(c, d, v.ne(~K, ~cmp, x, c, r, ha)),
        above_merge(~K, ~cmp, r, t, x, v.above(~K, ~cmp, x, c, r, ha),
          %Equal.sym(K, x, y, eq(x, y, e)) : {KA(~K, ~cmp, t, _) == True{} : Bool}
          v.above(~K, ~cmp, y, d, t, hb)),
        merge_valid.go(~K, ~cmp, ~eq, ~flip, r, t, KH2(~K, ~cmp, r, t),
          v.tail(~K, ~cmp, x, c, r, ha), v.tail(~K, ~cmp, y, d, t, hb), {==}))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} GT{}:
      v.cons(~K, ~cmp, y, d, KM(~K, ~cmp, Crdt.KCon{x, c, r}, t), v.ne(~K, ~cmp, y, d, t, hb),
        above_merge(~K, ~cmp, Crdt.KCon{x, c, r}, t, y, lt_true(cmp(y, x), gt_flip(~K, ~cmp, ~flip, x, y, e)),
          v.above(~K, ~cmp, y, d, t, hb)),
        merge_valid.go(~K, ~cmp, ~eq, ~flip, Crdt.KCon{x, c, r}, t, KH2(~K, ~cmp, Crdt.KCon{x, c, r}, t),
          ha, v.tail(~K, ~cmp, y, d, t, hb), {==}))

def merge_valid(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), ~flip: Flip(~K, ~cmp), +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>,
  ha: {KV(~K, ~cmp, a) == True{} : Bool}, hb: {KV(~K, ~cmp, b) == True{} : Bool}
) -> {KV(~K, ~cmp, KM(~K, ~cmp, a, b)) == True{} : Bool}:
  merge_valid.go(~K, ~cmp, ~eq, ~flip, a, b, KH2(~K, ~cmp, a, b), ha, hb, {==})

def Laws.k_merge_valid(K, cmp, eq, flip, a, b, ha, hb):
  merge_valid(~K, ~cmp, ~eq, ~flip, a, b, ha, hb)

# m is None or starts above lo.
def k.oka(~K: Data, ~cmp: K -> K -> Cmp, m: Maybe<&2, Crdt.KCounter<K>>, +lo: K) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{u}:
      KA(~K, ~cmp, u, lo)

def k_at_above(
  ~K: Data, ~cmp: K -> K -> Cmp, ok: Bool, +x: K, +n: U32, r: Crdt.KCounter<K>, +lo: K,
  h: {Cmp.is_lt(cmp(lo, x)) == True{} : Bool}
) -> {k.oka(~K, ~cmp, Crdt.KCounter.inc.at(K, ok, x, n, r), lo) == True{} : Bool}:
  match ok:
    case True{}:
      h
    case False{}:
      {==}

def k_cons_above(
  ~K: Data, ~cmp: K -> K -> Cmp, m: Maybe<&2, Crdt.KCounter<K>>, +x: K, +c: U32, +lo: K,
  h: {Cmp.is_lt(cmp(lo, x)) == True{} : Bool}
) -> {k.oka(~K, ~cmp, Crdt.KCounter.cons(K, x, c, m), lo) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{u}:
      h

# An increment of k keeps the state above lo when k is above lo.
def k_inc_above.go(
  ~K: Data, ~cmp: K -> K -> Cmp, s: Crdt.KCounter<K>, +k: K, q: Cmp, +lo: K,
  +hs: {KA(~K, ~cmp, s, lo) == True{} : Bool}, +hk: {Cmp.is_lt(cmp(lo, k)) == True{} : Bool}
) -> {k.oka(~K, ~cmp, Crdt.KCounter.inc.go(~K, ~cmp, s, k, q), lo) == True{} : Bool}:
  match s q:
    case Crdt.KNil{} _:
      hk
    case Crdt.KCon{x, c, r} LT{}:
      hk
    case Crdt.KCon{+x, +c, +r} EQ{}:
      k_at_above(~K, ~cmp, U32.is_lt(c, U32.inc(c)), x, U32.inc(c), r, lo, hs)
    case Crdt.KCon{+x, +c, +r} GT{}:
      k_cons_above(~K, ~cmp, KI(~K, ~cmp, r, k), x, c, lo, hs)

def k_inc_above(
  ~K: Data, ~cmp: K -> K -> Cmp, +s: Crdt.KCounter<K>, +k: K, +lo: K,
  +hs: {KA(~K, ~cmp, s, lo) == True{} : Bool}, +hk: {Cmp.is_lt(cmp(lo, k)) == True{} : Bool}
) -> {k.oka(~K, ~cmp, KI(~K, ~cmp, s, k), lo) == True{} : Bool}:
  k_inc_above.go(~K, ~cmp, s, k, KH(~K, ~cmp, k, s), lo, hs, hk)

def k_at_valid(
  ~K: Data, ~cmp: K -> K -> Cmp, ok: Bool, +c: U32, +x: K, +n: U32, +r: Crdt.KCounter<K>,
  e: {U32.is_lt(c, n) == ok : Bool}, ha: {KA(~K, ~cmp, r, x) == True{} : Bool}, hv: {KV(~K, ~cmp, r) == True{} : Bool}
) -> {Laws.k.ok_valid(~K, ~cmp, Crdt.KCounter.inc.at(K, ok, x, n, r)) == True{} : Bool}:
  match ok:
    case True{}:
      v.cons(~K, ~cmp, x, n, r, lt_ne0(c, n, e), ha, hv)
    case False{}:
      {==}

def k_cons_valid(
  ~K: Data, ~cmp: K -> K -> Cmp, m: Maybe<&2, Crdt.KCounter<K>>, +x: K, +c: U32, hc: {U32.is_ne(c, 0) == True{} : Bool},
  ha: {k.oka(~K, ~cmp, m, x) == True{} : Bool}, hv: {Laws.k.ok_valid(~K, ~cmp, m) == True{} : Bool}
) -> {Laws.k.ok_valid(~K, ~cmp, Crdt.KCounter.cons(K, x, c, m)) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{+u}:
      v.cons(~K, ~cmp, x, c, u, hc, ha, hv)

def k_inc_valid.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp), s: Crdt.KCounter<K>, +k: K, q: Cmp,
  +h: {KV(~K, ~cmp, s) == True{} : Bool}, e: {KH(~K, ~cmp, k, s) == q : Cmp}
) -> {Laws.k.ok_valid(~K, ~cmp, Crdt.KCounter.inc.go(~K, ~cmp, s, k, q)) == True{} : Bool}:
  match s q:
    case Crdt.KNil{} _:
      v.cons(~K, ~cmp, k, 1, Crdt.KNil{}, {==}, {==}, {==})
    case Crdt.KCon{+x, +c, +r} LT{}:
      v.cons(~K, ~cmp, k, 1, Crdt.KCon{x, c, r}, {==}, lt_true(cmp(k, x), e), h)
    case Crdt.KCon{+x, +c, +r} EQ{}:
      k_at_valid(~K, ~cmp, U32.is_lt(c, U32.inc(c)), c, x, U32.inc(c), r, {==},
        v.above(~K, ~cmp, x, c, r, h), v.tail(~K, ~cmp, x, c, r, h))
    case Crdt.KCon{+x, +c, +r} GT{}:
      k_cons_valid(~K, ~cmp, KI(~K, ~cmp, r, k), x, c, v.ne(~K, ~cmp, x, c, r, h),
        k_inc_above(~K, ~cmp, r, k, x, v.above(~K, ~cmp, x, c, r, h), lt_true(cmp(x, k), gt_flip(~K, ~cmp, ~flip, k, x, e))),
        k_inc_valid.go(~K, ~cmp, ~flip, r, k, KH(~K, ~cmp, k, r), v.tail(~K, ~cmp, x, c, r, h), {==}))

def Laws.k_inc_valid(K, cmp, flip, s, k, h):
  +s = s
  +k = k
  k_inc_valid.go(~K, ~cmp, ~flip, s, k, KH(~K, ~cmp, k, s), h, {==})

# Convergence.
def kcon_eq(
  -K: Data, -x: K, -y: K, -c: U32, -d: U32, -r: Crdt.KCounter<K>, -t: Crdt.KCounter<K>,
  ex: {x == y : K}, ec: {c == d : U32}, er: {r == t : Crdt.KCounter<K>}
) -> {Crdt.KCon{x, c, r} == Crdt.KCon{y, d, t} : Crdt.KCounter<K>}:
  %ex : {Crdt.KCon{x, c, r} == Crdt.KCon{_, d, t} : Crdt.KCounter<K>}
  %ec : {Crdt.KCon{x, c, r} == Crdt.KCon{x, _, t} : Crdt.KCounter<K>}
  %er : {Crdt.KCon{x, c, r} == Crdt.KCon{x, c, _} : Crdt.KCounter<K>}
  {==}

def k_same_sound(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), a: Crdt.KCounter<K>, b: Crdt.KCounter<K>,
  h: {Laws.k.same(~K, ~cmp, a, b) == True{} : Bool}
) -> {a == b : Crdt.KCounter<K>}:
  match a b:
    case Crdt.KNil{} Crdt.KNil{}:
      {==}
    case Crdt.KNil{} Crdt.KCon{y, d, t}:
      Empty.absurd({Crdt.KNil{} == Crdt.KCon{y, d, t} : Crdt.KCounter<K>}, MBool.false_ne_true()(h))
    case Crdt.KCon{x, c, r} Crdt.KNil{}:
      Empty.absurd({Crdt.KCon{x, c, r} == Crdt.KNil{} : Crdt.KCounter<K>}, MBool.false_ne_true()(h))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t}:
      +h = h
      +hd = MBool.eq_true_of_and_left(Bool.and(Cmp.is_eq(cmp(x, y)), U32.is_eq(c, d)), Laws.k.same(~K, ~cmp, r, t), h)
      kcon_eq(K, x, y, c, d, r, t,
        eq(x, y, eq_of_is_eq(cmp(x, y), MBool.eq_true_of_and_left(Cmp.is_eq(cmp(x, y)), U32.is_eq(c, d), hd))),
        eq32(c, d, MBool.eq_true_of_and_right(Cmp.is_eq(cmp(x, y)), U32.is_eq(c, d), hd)),
        k_same_sound(~K, ~cmp, ~eq, r, t,
          MBool.eq_true_of_and_right(Bool.and(Cmp.is_eq(cmp(x, y)), U32.is_eq(c, d)), Laws.k.same(~K, ~cmp, r, t), h)))

def k_absorb.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), b: Bool, +x: Crdt.KCounter<K>, +y: Crdt.KCounter<K>,
  +f: Crdt.KCounter<K>, -m: Bool, +k: K,
  hb: {Laws.k.same(~K, ~cmp, x, y) == b : Bool}, h: {Bool.or(b, m) == True{} : Bool},
  ih: {m == True{} : Bool} -> {U32.is_le(KG(~K, ~cmp, x, k), KG(~K, ~cmp, f, k)) == True{} : Bool}
) -> {U32.is_le(KG(~K, ~cmp, x, k), U32.max(KG(~K, ~cmp, y, k), KG(~K, ~cmp, f, k))) == True{} : Bool}:
  match b:
    case True{}:
      %Equal.sym(Crdt.KCounter<K>, x, y, k_same_sound(~K, ~cmp, ~eq, x, y, hb)) : {U32.is_le(KG(~K, ~cmp, _, k), U32.max(KG(~K, ~cmp, y, k), KG(~K, ~cmp, f, k))) == True{} : Bool}
      Lemmas.u32_le_max_l(KG(~K, ~cmp, y, k), KG(~K, ~cmp, f, k))
    case False{}:
      le_trans(KG(~K, ~cmp, x, k), KG(~K, ~cmp, f, k), U32.max(KG(~K, ~cmp, y, k), KG(~K, ~cmp, f, k)),
        ih(h), Lemmas.u32_le_max_r(KG(~K, ~cmp, y, k), KG(~K, ~cmp, f, k)))

def k_absorb(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), +x: Crdt.KCounter<K>, ys: List<&2, Crdt.KCounter<K>>, +k: K,
  h: {Laws.k.member(~K, ~cmp, x, ys) == True{} : Bool}
) -> {U32.is_le(KG(~K, ~cmp, x, k), KG(~K, ~cmp, KMA(~K, ~cmp, ys), k)) == True{} : Bool}:
  match ys:
    case Nil{}:
      Empty.absurd({U32.is_le(KG(~K, ~cmp, x, k), 0) == True{} : Bool}, MBool.false_ne_true()(h))
    case Con{+y, +t}:
      le_rw(KG(~K, ~cmp, x, k), U32.max(KG(~K, ~cmp, y, k), KG(~K, ~cmp, KMA(~K, ~cmp, t), k)),
        KG(~K, ~cmp, KM(~K, ~cmp, y, KMA(~K, ~cmp, t)), k),
        Equal.sym(U32, KG(~K, ~cmp, KM(~K, ~cmp, y, KMA(~K, ~cmp, t)), k),
          U32.max(KG(~K, ~cmp, y, k), KG(~K, ~cmp, KMA(~K, ~cmp, t), k)), get_merge(~K, ~cmp, ~eq, y, KMA(~K, ~cmp, t), k)),
        k_absorb.go(~K, ~cmp, ~eq, Laws.k.same(~K, ~cmp, x, y), x, y, KMA(~K, ~cmp, t), Laws.k.member(~K, ~cmp, x, t), k,
          {==}, h, p => k_absorb(~K, ~cmp, ~eq, x, t, k, p)))

def k_covered(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp), xs: List<&2, Crdt.KCounter<K>>, +ys: List<&2, Crdt.KCounter<K>>, +k: K,
  h: {Laws.k.covers(~K, ~cmp, xs, ys) == True{} : Bool}
) -> {U32.is_le(KG(~K, ~cmp, KMA(~K, ~cmp, xs), k), KG(~K, ~cmp, KMA(~K, ~cmp, ys), k)) == True{} : Bool}:
  match xs:
    case Nil{}:
      zero_le(KG(~K, ~cmp, KMA(~K, ~cmp, ys), k))
    case Con{+x, +t}:
      +h = h
      le_rw_l(U32.max(KG(~K, ~cmp, x, k), KG(~K, ~cmp, KMA(~K, ~cmp, t), k)),
        KG(~K, ~cmp, KM(~K, ~cmp, x, KMA(~K, ~cmp, t)), k), KG(~K, ~cmp, KMA(~K, ~cmp, ys), k),
        Equal.sym(U32, KG(~K, ~cmp, KM(~K, ~cmp, x, KMA(~K, ~cmp, t)), k),
          U32.max(KG(~K, ~cmp, x, k), KG(~K, ~cmp, KMA(~K, ~cmp, t), k)), get_merge(~K, ~cmp, ~eq, x, KMA(~K, ~cmp, t), k)),
        Lemmas.u32_max_le(KG(~K, ~cmp, x, k), KG(~K, ~cmp, KMA(~K, ~cmp, t), k), KG(~K, ~cmp, KMA(~K, ~cmp, ys), k),
          k_absorb(~K, ~cmp, ~eq, x, ys, k,
            MBool.eq_true_of_and_left(Laws.k.member(~K, ~cmp, x, ys), Laws.k.covers(~K, ~cmp, t, ys), h)),
          k_covered(~K, ~cmp, ~eq, t, ys, k,
            MBool.eq_true_of_and_right(Laws.k.member(~K, ~cmp, x, ys), Laws.k.covers(~K, ~cmp, t, ys), h))))

def Laws.k_converge(K, cmp, eq, xs, ys, hx, hy, k):
  +xs = xs
  +ys = ys
  le_antisymm(KG(~K, ~cmp, KMA(~K, ~cmp, xs), k), KG(~K, ~cmp, KMA(~K, ~cmp, ys), k),
    k_covered(~K, ~cmp, ~eq, xs, ys, k, hx), k_covered(~K, ~cmp, ~eq, ys, xs, k, hy))

# The CBOR boundary.
def k_gate_valid(
  ~K: Data, ~cmp: K -> K -> Cmp, ok: Bool, +s: Crdt.KCounter<K>, -q: Bool, h: {Bool.and(KV(~K, ~cmp, s), q) == ok : Bool}
) -> {Laws.k.ok_valid(~K, ~cmp, Crdt.KCounter.from_cbor.gate(K, ok, s)) == True{} : Bool}:
  match ok:
    case True{}:
      MBool.eq_true_of_and_left(KV(~K, ~cmp, s), q, h)
    case False{}:
      {==}

def k_check_valid(
  ~K: Data, ~cmp: K -> K -> Cmp, m: Maybe<&2, Crdt.KCounter<K>>, +cap: U32
) -> {Laws.k.ok_valid(~K, ~cmp, Crdt.KCounter.from_cbor.check(~K, ~cmp, m, cap)) == True{} : Bool}:
  match m:
    case None{}:
      {==}
    case Some{+s}:
      k_gate_valid(~K, ~cmp, Bool.and(KV(~K, ~cmp, s), U32.is_le(Crdt.KCounter.size(K, s), cap)), s,
        U32.is_le(Crdt.KCounter.size(K, s), cap), {==})

def Laws.k_from_cbor_valid(K, cmp, dec, v, cap):
  match v:
    case Cbor.Obj{kvs}:
      k_check_valid(~K, ~cmp, Crdt.KCounter.from_cbor.items(~K, ~dec, kvs), cap)
    case Cbor.UInt{w}:
      {==}
    case Cbor.NInt{w}:
      {==}
    case Cbor.BStr{b}:
      {==}
    case Cbor.TStr{b}:
      {==}
    case Cbor.Arr{xs}:
      {==}
    case Cbor.Tag{n, x}:
      {==}
    case Cbor.Sim{x}:
      {==}
    case Cbor.Flt{x}:
      {==}

def k_items_rt(
  ~K: Data, ~enc: K -> Cbor.Val, ~dec: Cbor.Val -> Maybe<&2, K>, ~rt: @x: K -> {dec(enc(x)) == Some{x} : Maybe<&2, K>},
  s: Crdt.KCounter<K>
) -> {Crdt.KCounter.from_cbor.items(~K, ~dec, Crdt.KCounter.to_cbor.items(~K, ~enc, s)) == Some{s} : Maybe<&2, Crdt.KCounter<K>>}:
  match s:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{+x, +c, +r}:
      +rest = Crdt.KCounter.from_cbor.items(~K, ~dec, Crdt.KCounter.to_cbor.items(~K, ~enc, r))
      Equal.trans(Maybe<&2, Crdt.KCounter<K>>, Crdt.KCounter.from_cbor.word(K, True{}, dec(enc(x)), c, rest),
        Crdt.KCounter.from_cbor.word(K, True{}, Some{x}, c, rest), Some{Crdt.KCon{x, c, r}},
        Equal.cong(Maybe<&2, K>, Maybe<&2, Crdt.KCounter<K>>, m => Crdt.KCounter.from_cbor.word(K, True{}, m, c, rest),
          dec(enc(x)), Some{x}, rt(x)),
        Equal.cong(Maybe<&2, Crdt.KCounter<K>>, Maybe<&2, Crdt.KCounter<K>>, m => Crdt.KCounter.cons(K, x, c, m),
          rest, Some{r}, k_items_rt(~K, ~enc, ~dec, ~rt, r)))

def k_gate_ok(
  ~K: Data, ~cmp: K -> K -> Cmp, +s: Crdt.KCounter<K>, +cap: U32,
  hv: {KV(~K, ~cmp, s) == True{} : Bool}, hc: {U32.is_le(Crdt.KCounter.size(K, s), cap) == True{} : Bool}
) -> {Crdt.KCounter.from_cbor.check(~K, ~cmp, Some{s}, cap) == Some{s} : Maybe<&2, Crdt.KCounter<K>>}:
  %Equal.sym(Bool, KV(~K, ~cmp, s), True{}, hv) : {Crdt.KCounter.from_cbor.gate(K, Bool.and(_, U32.is_le(Crdt.KCounter.size(K, s), cap)), s) == Some{s} : Maybe<&2, Crdt.KCounter<K>>}
  %Equal.sym(Bool, U32.is_le(Crdt.KCounter.size(K, s), cap), True{}, hc) : {Crdt.KCounter.from_cbor.gate(K, Bool.and(True{}, _), s) == Some{s} : Maybe<&2, Crdt.KCounter<K>>}
  {==}

def Laws.k_cbor_roundtrip(K, cmp, enc, dec, rt, s, cap, hv, hc):
  +s = s
  +cap = cap
  Equal.trans(Maybe<&2, Crdt.KCounter<K>>,
    Crdt.KCounter.from_cbor.check(~K, ~cmp, Crdt.KCounter.from_cbor.items(~K, ~dec, Crdt.KCounter.to_cbor.items(~K, ~enc, s)), cap),
    Crdt.KCounter.from_cbor.check(~K, ~cmp, Some{s}, cap), Some{s},
    Equal.cong(Maybe<&2, Crdt.KCounter<K>>, Maybe<&2, Crdt.KCounter<K>>, m => Crdt.KCounter.from_cbor.check(~K, ~cmp, m, cap),
      Crdt.KCounter.from_cbor.items(~K, ~dec, Crdt.KCounter.to_cbor.items(~K, ~enc, s)), Some{s},
      k_items_rt(~K, ~enc, ~dec, ~rt, s)),
    k_gate_ok(~K, ~cmp, s, cap, hv, hc))

def Laws.k_inc_sparse():
  {==}

def Laws.k_inc_overflow():
  {==}

def Laws.k_get_missing():
  {==}

def Laws.k_merge_fixture():
  {==}

def Laws.k_value_sum():
  {==}

def Laws.k_from_cbor_accepts():
  {==}

def Laws.k_from_cbor_unsorted():
  {==}

def Laws.k_from_cbor_duplicate():
  {==}

def Laws.k_from_cbor_zero():
  {==}

def Laws.k_from_cbor_over_cap():
  {==}

def Laws.k_from_cbor_bad_id():
  {==}

def Laws.k_from_cbor_not_map():
  {==}

# Cancel one unit from each half until only one sign remains.
def signed_sum(p: Nat, n: Nat) -> Bool & Nat:
  match p n:
    case 0n 0n:
      (False{}, 0n)
    case 0n 1n+q:
      (True{}, 1n+q)
    case 1n+p 0n:
      (False{}, 1n+p)
    case 1n+p 1n+q:
      signed_sum(p, q)

def exact_diff_step(negative: Bool, p: Nat, n: Nat) ->
  {Crdt.PNCounter.value_exact.diff(negative, 1n+p, 1n+n) ==
   Crdt.PNCounter.value_exact.diff(negative, p, n) : Bool & Nat}:
  match negative:
    case True{}:
      {==}
    case False{}:
      {==}

def exact_diff_spec(+p: Nat, +n: Nat) ->
  {Crdt.PNCounter.value_exact.diff(Nat.is_lt(p, n), p, n) == signed_sum(p, n) : Bool & Nat}:
  match p n:
    case 0n 0n:
      {==}
    case 0n 1n+q:
      {==}
    case 1n+p 0n:
      {==}
    case 1n+p 1n+q:
      Equal.trans(Bool & Nat,
        Crdt.PNCounter.value_exact.diff(Nat.is_lt(p, q), 1n+p, 1n+q),
        Crdt.PNCounter.value_exact.diff(Nat.is_lt(p, q), p, q), signed_sum(p, q),
        exact_diff_step(Nat.is_lt(p, q), p, q), exact_diff_spec(p, q))

def pn_exact_sum(+p: List<&2, U32>, +n: List<&2, U32>) ->
  {Crdt.PNCounter.value_exact(Crdt.PN{p, n}) ==
   signed_sum(Crdt.GCounter.value_exact(p), Crdt.GCounter.value_exact(n)) : Bool & Nat}:
  exact_diff_spec(Crdt.GCounter.value_exact(p), Crdt.GCounter.value_exact(n))

def k_counts(-K: Data, s: Crdt.KCounter<K>) -> List<&2, U32>:
  match s:
    case Crdt.KNil{}:
      Nil{}
    case Crdt.KCon{x, c, r}:
      Con{c, k_counts(K, r)}

def k_exact_sum(-K: Data, +s: Crdt.KCounter<K>) ->
  {Crdt.KCounter.value_exact(K, s) == Crdt.GCounter.value_exact(k_counts(K, s)) : Nat}:
  match s:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{x, +c, +r}:
      Equal.cong(Nat, Nat, n => (U32.to_nat(c) + n : Nat),
        Crdt.KCounter.value_exact(K, r), Crdt.GCounter.value_exact(k_counts(K, r)),
        k_exact_sum(K, r))

def Laws.k_le_refl(K, cmp, refl, a):
  le_self(~K, ~cmp, ~refl, a)

def k_trans(
  ~K: Data, ~cmp: K -> K -> Cmp, ~eq: Eq(~K, ~cmp),
  a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>, +c: Crdt.KCounter<K>,
  +hab: {KL(~K, ~cmp, a, b) == True{} : Bool}, +hbc: {KL(~K, ~cmp, b, c) == True{} : Bool}
) -> {KL(~K, ~cmp, a, c) == True{} : Bool}:
  match a:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{+x, +n, +r}:
      MBool.and_eq_true(U32.is_le(n, KG(~K, ~cmp, c, x)), KL(~K, ~cmp, r, c),
        le_trans(n, KG(~K, ~cmp, b, x), KG(~K, ~cmp, c, x),
          MBool.eq_true_of_and_left(U32.is_le(n, KG(~K, ~cmp, b, x)), KL(~K, ~cmp, r, b), hab),
          le_get(~K, ~cmp, ~eq, b, c, hbc, x)),
        k_trans(~K, ~cmp, ~eq, r, b, c,
          MBool.eq_true_of_and_right(U32.is_le(n, KG(~K, ~cmp, b, x)), KL(~K, ~cmp, r, b), hab), hbc))

def Laws.k_le_trans(K, cmp, eq, a, b, c, hab, hbc):
  k_trans(~K, ~cmp, ~eq, a, b, c, hab, hbc)

def Laws.k_merge_mono(K, cmp, refl, eq, a, b, c, hab):
  +a = a
  +b = b
  +c = c
  least.go(~K, ~cmp, ~eq, a, c, KH2(~K, ~cmp, a, c), KM(~K, ~cmp, b, c),
    k_trans(~K, ~cmp, ~eq, a, b, KM(~K, ~cmp, b, c), hab, upper_l(~K, ~cmp, ~refl, ~eq, b, c)),
    le_merge_l(~K, ~cmp, ~eq, c, c, b, le_self(~K, ~cmp, ~refl, c)), {==})

def Trans(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> @z: K -> {Cmp.is_lt(cmp(x, y)) == True{} : Bool} -> {Cmp.is_lt(cmp(y, z)) == True{} : Bool} -> {Cmp.is_lt(cmp(x, z)) == True{} : Bool}

def above_trans(
  ~K: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp), s: Crdt.KCounter<K>, +x: K, +y: K,
  hxy: {Cmp.is_lt(cmp(x, y)) == True{} : Bool}, hs: {KA(~K, ~cmp, s, y) == True{} : Bool}
) -> {KA(~K, ~cmp, s, x) == True{} : Bool}:
  match s:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{z, n, r}:
      trans(x, y, z, hxy, hs)

def hit_lt(q: Cmp, -n: U32, h: {Cmp.is_lt(q) == True{} : Bool}) -> {Crdt.KCounter.hit(q, n) == 0 : U32}:
  match q:
    case LT{}:
      {==}
    case EQ{}:
      Empty.absurd({n == 0 : U32}, MBool.false_ne_true()(h))
    case GT{}:
      {==}

def get_below(
  ~K: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp), s: Crdt.KCounter<K>, +x: K,
  +hv: {KV(~K, ~cmp, s) == True{} : Bool}, ha: {KA(~K, ~cmp, s, x) == True{} : Bool}
) -> {KG(~K, ~cmp, s, x) == 0 : U32}:
  match s:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{+y, +n, +r}:
      +ha = ha
      %Equal.sym(U32, Crdt.KCounter.hit(cmp(x, y), n), 0, hit_lt(cmp(x, y), n, ha)) : {U32.max(_, KG(~K, ~cmp, r, x)) == 0 : U32}
      %Equal.sym(U32, KG(~K, ~cmp, r, x), 0,
        get_below(~K, ~cmp, ~trans, r, x, v.tail(~K, ~cmp, y, n, r, hv),
          above_trans(~K, ~cmp, ~trans, r, x, y, ha, v.above(~K, ~cmp, y, n, r, hv)))) : {U32.max(0, _) == 0 : U32}
      Lemmas.u32_max_self(0)

def get_first(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  +x: K, +n: U32, +r: Crdt.KCounter<K>, +hv: {KV(~K, ~cmp, Crdt.KCon{x, n, r}) == True{} : Bool}
) -> {KG(~K, ~cmp, Crdt.KCon{x, n, r}, x) == n : U32}:
  %Equal.sym(Cmp, cmp(x, x), EQ{}, refl(x)) : {U32.max(Crdt.KCounter.hit(_, n), KG(~K, ~cmp, r, x)) == n : U32}
  %Equal.sym(U32, KG(~K, ~cmp, r, x), 0,
    get_below(~K, ~cmp, ~trans, r, x, v.tail(~K, ~cmp, x, n, r, hv), v.above(~K, ~cmp, x, n, r, hv))) : {U32.max(n, _) == n : U32}
  Lemmas.u32_max0_r(n)

def hit_reverse(
  ~K: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp), q: Cmp, +x: K, +y: K, -n: U32,
  h: {Cmp.is_lt(q) == True{} : Bool}, e: {cmp(x, y) == q : Cmp}
) -> {Crdt.KCounter.hit(cmp(y, x), n) == 0 : U32}:
  match q:
    case LT{}:
      %Equal.sym(Cmp, cmp(y, x), GT{},
        Equal.trans(Cmp, cmp(y, x), Laws.flip(cmp(x, y)), GT{}, flip(x, y),
          Equal.cong(Cmp, Cmp, z => Laws.flip(z), cmp(x, y), LT{}, e))) : {Crdt.KCounter.hit(_, n) == 0 : U32}
      {==}
    case EQ{}:
      Empty.absurd({Crdt.KCounter.hit(cmp(y, x), n) == 0 : U32}, MBool.false_ne_true()(h))
    case GT{}:
      Empty.absurd({Crdt.KCounter.hit(cmp(y, x), n) == 0 : U32}, MBool.false_ne_true()(h))

def le_drop(
  ~K: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  a: Crdt.KCounter<K>, +x: K, +n: U32, +b: Crdt.KCounter<K>,
  +hv: {KV(~K, ~cmp, a) == True{} : Bool}, ha: {KA(~K, ~cmp, a, x) == True{} : Bool},
  +h: {KL(~K, ~cmp, a, Crdt.KCon{x, n, b}) == True{} : Bool}
) -> {KL(~K, ~cmp, a, b) == True{} : Bool}:
  match a:
    case Crdt.KNil{}:
      {==}
    case Crdt.KCon{+y, +d, +r}:
      +ha = ha
      MBool.and_eq_true(U32.is_le(d, KG(~K, ~cmp, b, y)), KL(~K, ~cmp, r, b),
        le_rw(d, KG(~K, ~cmp, Crdt.KCon{x, n, b}, y), KG(~K, ~cmp, b, y),
          %Equal.sym(U32, Crdt.KCounter.hit(cmp(y, x), n), 0,
            hit_reverse(~K, ~cmp, ~flip, cmp(x, y), x, y, n, ha, {==})) : {U32.max(_, KG(~K, ~cmp, b, y)) == KG(~K, ~cmp, b, y) : U32}
          Lemmas.u32_max0_l(KG(~K, ~cmp, b, y)),
          MBool.eq_true_of_and_left(U32.is_le(d, KG(~K, ~cmp, Crdt.KCon{x, n, b}, y)), KL(~K, ~cmp, r, Crdt.KCon{x, n, b}), h)),
        le_drop(~K, ~cmp, ~flip, ~trans, r, x, n, b, v.tail(~K, ~cmp, y, d, r, hv),
          above_trans(~K, ~cmp, ~trans, r, x, y, ha, v.above(~K, ~cmp, y, d, r, hv)),
          MBool.eq_true_of_and_right(U32.is_le(d, KG(~K, ~cmp, Crdt.KCon{x, n, b}, y)), KL(~K, ~cmp, r, Crdt.KCon{x, n, b}), h)))

def ne_le_zero(+n: U32, hn: {U32.is_ne(n, 0) == True{} : Bool}, h: {U32.is_le(n, 0) == True{} : Bool}) -> Empty:
  MBool.false_ne_true()(
    %eq32(n, 0, Equal.trans(Bool, U32.is_eq(n, 0), U32.is_le(n, 0), True{}, Lemmas.u32_eq0_le(n), h)) : {U32.is_ne(_, 0) == True{} : Bool}
    hn)

def k_cons_equal(
  ~K: Data, -x: K, -y: K, -c: U32, -d: U32, -r: Crdt.KCounter<K>, -t: Crdt.KCounter<K>,
  ex: {x == y : K}, ec: {c == d : U32}, er: {r == t : Crdt.KCounter<K>}
) -> {Crdt.KCon{x, c, r} == Crdt.KCon{y, d, t} : Crdt.KCounter<K>}:
  %ex : {Crdt.KCon{x, c, r} == Crdt.KCon{_, d, t} : Crdt.KCounter<K>}
  %ec : {Crdt.KCon{x, c, r} == Crdt.KCon{x, _, t} : Crdt.KCounter<K>}
  %er : {Crdt.KCon{x, c, r} == Crdt.KCon{x, c, _} : Crdt.KCounter<K>}
  {==}

def anti.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  a: Crdt.KCounter<K>, b: Crdt.KCounter<K>, q: Cmp,
  +va: {KV(~K, ~cmp, a) == True{} : Bool}, +vb: {KV(~K, ~cmp, b) == True{} : Bool},
  +hab: {KL(~K, ~cmp, a, b) == True{} : Bool}, +hba: {KL(~K, ~cmp, b, a) == True{} : Bool},
  e: {KH2(~K, ~cmp, a, b) == q : Cmp}
) -> {a == b : Crdt.KCounter<K>}:
  match a b q:
    case Crdt.KNil{} Crdt.KNil{} _:
      {==}
    case Crdt.KNil{} Crdt.KCon{+y, +d, +t} _:
      Empty.absurd({Crdt.KNil{} == Crdt.KCon{y, d, t} : Crdt.KCounter<K>},
        ne_le_zero(d, v.ne(~K, ~cmp, y, d, t, vb),
          MBool.eq_true_of_and_left(U32.is_le(d, 0), KL(~K, ~cmp, t, Crdt.KNil{}), hba)))
    case Crdt.KCon{+x, +c, +r} Crdt.KNil{} _:
      Empty.absurd({Crdt.KCon{x, c, r} == Crdt.KNil{} : Crdt.KCounter<K>},
        ne_le_zero(c, v.ne(~K, ~cmp, x, c, r, va),
          MBool.eq_true_of_and_left(U32.is_le(c, 0), KL(~K, ~cmp, r, Crdt.KNil{}), hab)))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} LT{}:
      Empty.absurd({Crdt.KCon{x, c, r} == Crdt.KCon{y, d, t} : Crdt.KCounter<K>},
        ne_le_zero(c, v.ne(~K, ~cmp, x, c, r, va),
          le_rw(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x), 0,
            get_below(~K, ~cmp, ~trans, Crdt.KCon{y, d, t}, x, vb, lt_true(cmp(x, y), e)),
            MBool.eq_true_of_and_left(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x)), KL(~K, ~cmp, r, Crdt.KCon{y, d, t}), hab))))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} EQ{}:
      +ex = eq(x, y, e)
      k_cons_equal(~K, x, y, c, d, r, t, ex,
        le_antisymm(c, d,
          le_rw(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x), d,
            %Equal.sym(K, x, y, ex) : {KG(~K, ~cmp, Crdt.KCon{y, d, t}, _) == d : U32}
            get_first(~K, ~cmp, ~refl, ~trans, y, d, t, vb),
            MBool.eq_true_of_and_left(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x)), KL(~K, ~cmp, r, Crdt.KCon{y, d, t}), hab)),
          le_rw(d, KG(~K, ~cmp, Crdt.KCon{x, c, r}, y), c,
            %ex : {KG(~K, ~cmp, Crdt.KCon{x, c, r}, _) == c : U32}
            get_first(~K, ~cmp, ~refl, ~trans, x, c, r, va),
            MBool.eq_true_of_and_left(U32.is_le(d, KG(~K, ~cmp, Crdt.KCon{x, c, r}, y)), KL(~K, ~cmp, t, Crdt.KCon{x, c, r}), hba))),
        anti.go(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, r, t, KH2(~K, ~cmp, r, t),
          v.tail(~K, ~cmp, x, c, r, va), v.tail(~K, ~cmp, y, d, t, vb),
          le_drop(~K, ~cmp, ~flip, ~trans, r, y, d, t, v.tail(~K, ~cmp, x, c, r, va),
            %ex : {KA(~K, ~cmp, r, _) == True{} : Bool}
            v.above(~K, ~cmp, x, c, r, va),
            MBool.eq_true_of_and_right(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x)), KL(~K, ~cmp, r, Crdt.KCon{y, d, t}), hab)),
          le_drop(~K, ~cmp, ~flip, ~trans, t, x, c, r, v.tail(~K, ~cmp, y, d, t, vb),
            %Equal.sym(K, x, y, ex) : {KA(~K, ~cmp, t, _) == True{} : Bool}
            v.above(~K, ~cmp, y, d, t, vb),
            MBool.eq_true_of_and_right(U32.is_le(d, KG(~K, ~cmp, Crdt.KCon{x, c, r}, y)), KL(~K, ~cmp, t, Crdt.KCon{x, c, r}), hba)), {==}))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} GT{}:
      Empty.absurd({Crdt.KCon{x, c, r} == Crdt.KCon{y, d, t} : Crdt.KCounter<K>},
        ne_le_zero(d, v.ne(~K, ~cmp, y, d, t, vb),
          le_rw(d, KG(~K, ~cmp, Crdt.KCon{x, c, r}, y), 0,
            get_below(~K, ~cmp, ~trans, Crdt.KCon{x, c, r}, y, va, lt_true(cmp(y, x), gt_flip(~K, ~cmp, ~flip, x, y, e))),
            MBool.eq_true_of_and_left(U32.is_le(d, KG(~K, ~cmp, Crdt.KCon{x, c, r}, y)), KL(~K, ~cmp, t, Crdt.KCon{x, c, r}), hba))))

def Laws.k_le_antisymm(K, cmp, refl, eq, flip, trans, a, b, va, vb, hab, hba):
  +a = a
  +b = b
  anti.go(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, a, b, KH2(~K, ~cmp, a, b), va, vb, hab, hba, {==})

def k_exact_mono.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  a: Crdt.KCounter<K>, b: Crdt.KCounter<K>, q: Cmp,
  +va: {KV(~K, ~cmp, a) == True{} : Bool}, +vb: {KV(~K, ~cmp, b) == True{} : Bool},
  +hab: {KL(~K, ~cmp, a, b) == True{} : Bool}, e: {KH2(~K, ~cmp, a, b) == q : Cmp}
) -> {Nat.is_le(Crdt.KCounter.value_exact(K, a), Crdt.KCounter.value_exact(K, b)) == True{} : Bool}:
  match a b q:
    case Crdt.KNil{} _ _:
      MNat.zero_le(Crdt.KCounter.value_exact(K, b))
    case Crdt.KCon{+x, +c, +r} Crdt.KNil{} _:
      Empty.absurd({Nat.is_le(Crdt.KCounter.value_exact(K, Crdt.KCon{x, c, r}), 0n) == True{} : Bool},
        ne_le_zero(c, v.ne(~K, ~cmp, x, c, r, va),
          MBool.eq_true_of_and_left(U32.is_le(c, 0), KL(~K, ~cmp, r, Crdt.KNil{}), hab)))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} LT{}:
      Empty.absurd({Nat.is_le(Crdt.KCounter.value_exact(K, Crdt.KCon{x, c, r}), Crdt.KCounter.value_exact(K, Crdt.KCon{y, d, t})) == True{} : Bool},
        ne_le_zero(c, v.ne(~K, ~cmp, x, c, r, va),
          le_rw(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x), 0,
            get_below(~K, ~cmp, ~trans, Crdt.KCon{y, d, t}, x, vb, lt_true(cmp(x, y), e)),
            MBool.eq_true_of_and_left(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x)), KL(~K, ~cmp, r, Crdt.KCon{y, d, t}), hab))))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} EQ{}:
      +ex = eq(x, y, e)
      MNat.add_le_add(U32.to_nat(c), Crdt.KCounter.value_exact(K, r), U32.to_nat(d), Crdt.KCounter.value_exact(K, t),
        Equal.trans(Bool, Nat.is_le(U32.to_nat(c), U32.to_nat(d)), U32.is_le(c, d), True{},
          Lemmas.u32_le_nat_sym(c, d),
          le_rw(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x), d,
            %Equal.sym(K, x, y, ex) : {KG(~K, ~cmp, Crdt.KCon{y, d, t}, _) == d : U32}
            get_first(~K, ~cmp, ~refl, ~trans, y, d, t, vb),
            MBool.eq_true_of_and_left(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x)), KL(~K, ~cmp, r, Crdt.KCon{y, d, t}), hab))),
        k_exact_mono.go(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, r, t, KH2(~K, ~cmp, r, t),
          v.tail(~K, ~cmp, x, c, r, va), v.tail(~K, ~cmp, y, d, t, vb),
          le_drop(~K, ~cmp, ~flip, ~trans, r, y, d, t, v.tail(~K, ~cmp, x, c, r, va),
            %ex : {KA(~K, ~cmp, r, _) == True{} : Bool}
            v.above(~K, ~cmp, x, c, r, va),
            MBool.eq_true_of_and_right(U32.is_le(c, KG(~K, ~cmp, Crdt.KCon{y, d, t}, x)), KL(~K, ~cmp, r, Crdt.KCon{y, d, t}), hab)), {==}))
    case Crdt.KCon{+x, +c, +r} Crdt.KCon{+y, +d, +t} GT{}:
      MNat.le_trans(Crdt.KCounter.value_exact(K, Crdt.KCon{x, c, r}), Crdt.KCounter.value_exact(K, t),
        Crdt.KCounter.value_exact(K, Crdt.KCon{y, d, t}),
        k_exact_mono.go(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, Crdt.KCon{x, c, r}, t, KH2(~K, ~cmp, Crdt.KCon{x, c, r}, t),
          va, v.tail(~K, ~cmp, y, d, t, vb),
          le_drop(~K, ~cmp, ~flip, ~trans, Crdt.KCon{x, c, r}, y, d, t, va,
            lt_true(cmp(y, x), gt_flip(~K, ~cmp, ~flip, x, y, e)), hab), {==}),
        MNat.le_add_left(Crdt.KCounter.value_exact(K, t), U32.to_nat(d)))

def k_exact_mono(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>,
  va: {KV(~K, ~cmp, a) == True{} : Bool}, vb: {KV(~K, ~cmp, b) == True{} : Bool},
  hab: {KL(~K, ~cmp, a, b) == True{} : Bool}
) -> {Nat.is_le(Crdt.KCounter.value_exact(K, a), Crdt.KCounter.value_exact(K, b)) == True{} : Bool}:
  k_exact_mono.go(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, a, b, KH2(~K, ~cmp, a, b), va, vb, hab, {==})

def k_exact_merge_grows_l(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp), +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>,
  +va: {KV(~K, ~cmp, a) == True{} : Bool}, vb: {KV(~K, ~cmp, b) == True{} : Bool}
) -> {Nat.is_le(Crdt.KCounter.value_exact(K, a), Crdt.KCounter.value_exact(K, KM(~K, ~cmp, a, b))) == True{} : Bool}:
  k_exact_mono(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, a, KM(~K, ~cmp, a, b), va,
    merge_valid(~K, ~cmp, ~eq, ~flip, a, b, va, vb), upper_l(~K, ~cmp, ~refl, ~eq, a, b))

def k_exact_merge_grows_r(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp), +a: Crdt.KCounter<K>, +b: Crdt.KCounter<K>,
  va: {KV(~K, ~cmp, a) == True{} : Bool}, +vb: {KV(~K, ~cmp, b) == True{} : Bool}
) -> {Nat.is_le(Crdt.KCounter.value_exact(K, b), Crdt.KCounter.value_exact(K, KM(~K, ~cmp, a, b))) == True{} : Bool}:
  k_exact_mono(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, b, KM(~K, ~cmp, a, b), vb,
    merge_valid(~K, ~cmp, ~eq, ~flip, a, b, va, vb), le_merge_l(~K, ~cmp, ~eq, b, b, a, le_self(~K, ~cmp, ~refl, b)))

def k_exact_inc_grows(
  ~K: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp), +s: Crdt.KCounter<K>, +k: K, +u: Crdt.KCounter<K>,
  +vs: {KV(~K, ~cmp, s) == True{} : Bool}, ok: {KI(~K, ~cmp, s, k) == Some{u} : Maybe<&2, Crdt.KCounter<K>>}
) -> {Nat.is_le(Crdt.KCounter.value_exact(K, s), Crdt.KCounter.value_exact(K, u)) == True{} : Bool}:
  +ok = ok
  k_exact_mono(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, s, u, vs,
    Equal.trans(Bool, KV(~K, ~cmp, u), Laws.k.ok_valid(~K, ~cmp, KI(~K, ~cmp, s, k)), True{},
      Equal.sym(Bool, Laws.k.ok_valid(~K, ~cmp, KI(~K, ~cmp, s, k)), KV(~K, ~cmp, u),
        Equal.cong(Maybe<&2, Crdt.KCounter<K>>, Bool, m => Laws.k.ok_valid(~K, ~cmp, m), KI(~K, ~cmp, s, k), Some{u}, ok)),
      k_inc_valid.go(~K, ~cmp, ~flip, s, k, KH(~K, ~cmp, k, s), vs, {==})),
    Equal.trans(Bool, KL(~K, ~cmp, s, u), Laws.k.grows(~K, ~cmp, s, KI(~K, ~cmp, s, k)), True{},
      Equal.sym(Bool, Laws.k.grows(~K, ~cmp, s, KI(~K, ~cmp, s, k)), KL(~K, ~cmp, s, u),
        Equal.cong(Maybe<&2, Crdt.KCounter<K>>, Bool, m => Laws.k.grows(~K, ~cmp, s, m), KI(~K, ~cmp, s, k), Some{u}, ok)),
      k_inc_grows.go(~K, ~cmp, ~refl, s, k, KH(~K, ~cmp, k, s))))

def Laws.k_merge_comm_state(K, cmp, refl, eq, flip, trans, a, b, va, vb):
  +a = a
  +b = b
  +va = va
  +vb = vb
  Laws.k_le_antisymm(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, KM(~K, ~cmp, a, b), KM(~K, ~cmp, b, a),
    merge_valid(~K, ~cmp, ~eq, ~flip, a, b, va, vb),
    merge_valid(~K, ~cmp, ~eq, ~flip, b, a, vb, va),
    Laws.k_merge_least(~K, ~cmp, ~eq, a, b, KM(~K, ~cmp, b, a),
      Laws.k_merge_upper_r(~K, ~cmp, ~refl, ~eq, b, a), upper_l(~K, ~cmp, ~refl, ~eq, b, a)),
    Laws.k_merge_least(~K, ~cmp, ~eq, b, a, KM(~K, ~cmp, a, b),
      Laws.k_merge_upper_r(~K, ~cmp, ~refl, ~eq, a, b), upper_l(~K, ~cmp, ~refl, ~eq, a, b)))

def Laws.k_merge_assoc_state(K, cmp, refl, eq, flip, trans, a, b, c, va, vb, vc):
  +a = a
  +b = b
  +c = c
  +va = va
  +vb = vb
  +vc = vc
  +ab = KM(~K, ~cmp, a, b)
  +bc = KM(~K, ~cmp, b, c)
  +l = KM(~K, ~cmp, ab, c)
  +r = KM(~K, ~cmp, a, bc)
  +bl = Laws.k_le_trans(~K, ~cmp, ~eq, b, ab, l,
    Laws.k_merge_upper_r(~K, ~cmp, ~refl, ~eq, a, b), upper_l(~K, ~cmp, ~refl, ~eq, ab, c))
  +br = Laws.k_le_trans(~K, ~cmp, ~eq, b, bc, r,
    upper_l(~K, ~cmp, ~refl, ~eq, b, c), Laws.k_merge_upper_r(~K, ~cmp, ~refl, ~eq, a, bc))
  Laws.k_le_antisymm(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, l, r,
    merge_valid(~K, ~cmp, ~eq, ~flip, ab, c, merge_valid(~K, ~cmp, ~eq, ~flip, a, b, va, vb), vc),
    merge_valid(~K, ~cmp, ~eq, ~flip, a, bc, va, merge_valid(~K, ~cmp, ~eq, ~flip, b, c, vb, vc)),
    Laws.k_merge_least(~K, ~cmp, ~eq, ab, c, r,
      Laws.k_merge_least(~K, ~cmp, ~eq, a, b, r, upper_l(~K, ~cmp, ~refl, ~eq, a, bc), br),
      Laws.k_le_trans(~K, ~cmp, ~eq, c, bc, r,
        Laws.k_merge_upper_r(~K, ~cmp, ~refl, ~eq, b, c), Laws.k_merge_upper_r(~K, ~cmp, ~refl, ~eq, a, bc))),
    Laws.k_merge_least(~K, ~cmp, ~eq, a, bc, l,
      Laws.k_le_trans(~K, ~cmp, ~eq, a, ab, l,
        upper_l(~K, ~cmp, ~refl, ~eq, a, b), upper_l(~K, ~cmp, ~refl, ~eq, ab, c)),
      Laws.k_merge_least(~K, ~cmp, ~eq, b, c, l, bl, Laws.k_merge_upper_r(~K, ~cmp, ~refl, ~eq, ab, c))))

def Laws.k_merge_idem_state(K, cmp, refl, eq, flip, trans, a, va):
  +a = a
  +va = va
  +ha = le_self(~K, ~cmp, ~refl, a)
  Laws.k_le_antisymm(~K, ~cmp, ~refl, ~eq, ~flip, ~trans, KM(~K, ~cmp, a, a), a,
    merge_valid(~K, ~cmp, ~eq, ~flip, a, a, va, va), va,
    Laws.k_merge_least(~K, ~cmp, ~eq, a, a, a, ha, ha), upper_l(~K, ~cmp, ~refl, ~eq, a, a))
