import Base
import bend-mathlib@0.7.2.0/nat.bend as MNat
import bend-mathlib@0.7.2.0/bool.bend as MBool
import bend-kit-cbor@0.2.0.0/cbor.bend as Cbor
import ../lemmas/lemmas.bend as Lemmas
import ./crdt.bend as Crdt
import ./LAWS.bend as Laws

# U32.max picks b when a < b, so its value is the Nat maximum.
def max_pick(
  c: Bool, +a: U32, +b: U32,
  h: {Nat.is_lt(U32.to_nat(a), U32.to_nat(b)) == c : Bool}
) -> {U32.to_nat(Bool.pick(U32, c, b, a)) == Nat.max(U32.to_nat(a), U32.to_nat(b)) : Nat}:
  match c:
    case True{}:
      Equal.sym(Nat, Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(b),
        MNat.max_eq_right(U32.to_nat(a), U32.to_nat(b), MNat.le_of_lt(U32.to_nat(a), U32.to_nat(b), h)))
    case False{}:
      Equal.sym(Nat, Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(a),
        MNat.max_eq_left(U32.to_nat(a), U32.to_nat(b), MNat.le_of_not_lt(U32.to_nat(a), U32.to_nat(b), h)))

def max_nat(a: U32, b: U32) -> {U32.to_nat(U32.max(a, b)) == Nat.max(U32.to_nat(a), U32.to_nat(b)) : Nat}:
  match a b:
    case U32{+x} U32{+y}:
      max_pick(U32.is_lt(U32{x}, U32{y}), U32{x}, U32{y},
        Equal.sym(Bool, U32.is_lt(U32{x}, U32{y}), Nat.is_lt(U32.to_nat(U32{x}), U32.to_nat(U32{y})),
          Lemmas.u32_is_lt_nat(U32{x}, U32{y})))

def max_nat_sym(+a: U32, +b: U32) -> {Nat.max(U32.to_nat(a), U32.to_nat(b)) == U32.to_nat(U32.max(a, b)) : Nat}:
  Equal.sym(Nat, U32.to_nat(U32.max(a, b)), Nat.max(U32.to_nat(a), U32.to_nat(b)), max_nat(a, b))

def max_comm(+a: U32, +b: U32) -> {U32.max(a, b) == U32.max(b, a) : U32}:
  Lemmas.u32_to_nat_inj(U32.max(a, b), U32.max(b, a),
    %max_nat_sym(a, b) : {_ == U32.to_nat(U32.max(b, a)) : Nat}
    %max_nat_sym(b, a) : {Nat.max(U32.to_nat(a), U32.to_nat(b)) == _ : Nat}
    MNat.max_comm(U32.to_nat(a), U32.to_nat(b)))

def max_assoc(+a: U32, +b: U32, +c: U32) -> {U32.max(U32.max(a, b), c) == U32.max(a, U32.max(b, c)) : U32}:
  Lemmas.u32_to_nat_inj(U32.max(U32.max(a, b), c), U32.max(a, U32.max(b, c)),
    %max_nat_sym(U32.max(a, b), c) : {_ == U32.to_nat(U32.max(a, U32.max(b, c))) : Nat}
    %max_nat_sym(a, b) : {Nat.max(_, U32.to_nat(c)) == U32.to_nat(U32.max(a, U32.max(b, c))) : Nat}
    %max_nat_sym(a, U32.max(b, c)) : {Nat.max(Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(c)) == _ : Nat}
    %max_nat_sym(b, c) : {Nat.max(Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(c)) == Nat.max(U32.to_nat(a), _) : Nat}
    MNat.max_assoc(U32.to_nat(a), U32.to_nat(b), U32.to_nat(c)))

def max_self(+a: U32) -> {U32.max(a, a) == a : U32}:
  Lemmas.u32_to_nat_inj(U32.max(a, a), a,
    %max_nat_sym(a, a) : {_ == U32.to_nat(a) : Nat}
    MNat.max_self(U32.to_nat(a)))

# U32 order facts, read through to_nat.
def le_nat_sym(+a: U32, +b: U32) -> {Nat.is_le(U32.to_nat(a), U32.to_nat(b)) == U32.is_le(a, b) : Bool}:
  Equal.sym(Bool, U32.is_le(a, b), Nat.is_le(U32.to_nat(a), U32.to_nat(b)), Lemmas.u32_is_le_nat(a, b))

def le_refl(+a: U32) -> {U32.is_le(a, a) == True{} : Bool}:
  %le_nat_sym(a, a) : {_ == True{} : Bool}
  MNat.le_refl(U32.to_nat(a))

def le_max_l(+a: U32, +b: U32) -> {U32.is_le(a, U32.max(a, b)) == True{} : Bool}:
  %le_nat_sym(a, U32.max(a, b)) : {_ == True{} : Bool}
  %max_nat_sym(a, b) : {Nat.is_le(U32.to_nat(a), _) == True{} : Bool}
  MNat.le_max_left(U32.to_nat(a), U32.to_nat(b))

def le_max_r(+a: U32, +b: U32) -> {U32.is_le(b, U32.max(a, b)) == True{} : Bool}:
  %le_nat_sym(b, U32.max(a, b)) : {_ == True{} : Bool}
  %max_nat_sym(a, b) : {Nat.is_le(U32.to_nat(b), _) == True{} : Bool}
  MNat.le_max_right(U32.to_nat(a), U32.to_nat(b))

def max_le(
  +a: U32, +b: U32, +c: U32,
  ha: {U32.is_le(a, c) == True{} : Bool}, hb: {U32.is_le(b, c) == True{} : Bool}
) -> {U32.is_le(U32.max(a, b), c) == True{} : Bool}:
  %le_nat_sym(U32.max(a, b), c) : {_ == True{} : Bool}
  %max_nat_sym(a, b) : {Nat.is_le(_, U32.to_nat(c)) == True{} : Bool}
  %Equal.sym(Bool, Nat.is_le(Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(c)),
    Bool.and(Nat.is_le(U32.to_nat(a), U32.to_nat(c)), Nat.is_le(U32.to_nat(b), U32.to_nat(c))),
    MNat.max_le(U32.to_nat(a), U32.to_nat(b), U32.to_nat(c))) : {_ == True{} : Bool}
  %Lemmas.u32_is_le_nat(a, c) : {Bool.and(_, Nat.is_le(U32.to_nat(b), U32.to_nat(c))) == True{} : Bool}
  %Lemmas.u32_is_le_nat(b, c) : {Bool.and(U32.is_le(a, c), _) == True{} : Bool}
  MBool.and_eq_true(U32.is_le(a, c), U32.is_le(b, c), ha, hb)

def cmp_lt_le(k: Cmp, h: {Cmp.is_lt(k) == True{} : Bool}) -> {Cmp.is_le(k) == True{} : Bool}:
  match k:
    case LT{}:
      {==}
    case EQ{}:
      Empty.absurd({Cmp.is_le(EQ{}) == True{} : Bool}, MBool.false_ne_true()(h))
    case GT{}:
      Empty.absurd({Cmp.is_le(GT{}) == True{} : Bool}, MBool.false_ne_true()(h))

def cmp_nat_sym(+a: U32, +b: U32) -> {Nat.cmp(U32.to_nat(a), U32.to_nat(b)) == U32.cmp(a, b) : Cmp}:
  Equal.sym(Cmp, U32.cmp(a, b), Nat.cmp(U32.to_nat(a), U32.to_nat(b)), Lemmas.u32_cmp_nat(a, b))

def ne0_nat(
  n: Nat, +m: Nat, h: {Bool.not(Cmp.is_eq(Nat.cmp(n, 0n))) == True{} : Bool}
) -> {Bool.not(Cmp.is_eq(Nat.cmp(Nat.max(n, m), 0n))) == True{} : Bool}:
  match n m:
    case 0n _:
      Empty.absurd({Bool.not(Cmp.is_eq(Nat.cmp(Nat.max(0n, m), 0n))) == True{} : Bool}, MBool.false_ne_true()(h))
    case 1n+p 0n:
      {==}
    case 1n+p 1n+q:
      {==}

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

# A count of 0 compares the same as a count at most 0.
def eq0_le_nat(n: Nat) -> {Cmp.is_eq(Nat.cmp(n, 0n)) == Cmp.is_le(Nat.cmp(n, 0n)) : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

def eq0_le(+x: U32) -> {U32.is_eq(x, 0) == U32.is_le(x, 0) : Bool}:
  %cmp_nat_sym(x, 0) : {Cmp.is_eq(_) == Cmp.is_le(_) : Bool}
  eq0_le_nat(U32.to_nat(x))

def eq0_to_le(+x: U32, h: {U32.is_eq(x, 0) == True{} : Bool}) -> {U32.is_le(x, 0) == True{} : Bool}:
  Equal.trans(Bool, U32.is_le(x, 0), U32.is_eq(x, 0), True{},
    Equal.sym(Bool, U32.is_eq(x, 0), U32.is_le(x, 0), eq0_le(x)), h)

def max_eq0(
  +x: U32, +y: U32, hx: {U32.is_eq(x, 0) == True{} : Bool}, hy: {U32.is_eq(y, 0) == True{} : Bool}
) -> {U32.is_eq(U32.max(x, y), 0) == True{} : Bool}:
  Equal.trans(Bool, U32.is_eq(U32.max(x, y), 0), U32.is_le(U32.max(x, y), 0), True{},
    eq0_le(U32.max(x, y)), max_le(x, y, 0, eq0_to_le(x, hx), eq0_to_le(y, hy)))

def ne0_max(
  +x: U32, +y: U32, h: {U32.is_ne(x, 0) == True{} : Bool}
) -> {U32.is_ne(U32.max(x, y), 0) == True{} : Bool}:
  %cmp_nat_sym(U32.max(x, y), 0) : {Bool.not(Cmp.is_eq(_)) == True{} : Bool}
  %max_nat_sym(x, y) : {Bool.not(Cmp.is_eq(Nat.cmp(_, U32.to_nat(0)))) == True{} : Bool}
  ne0_nat(U32.to_nat(x), U32.to_nat(y),
    Equal.trans(Bool, Bool.not(Cmp.is_eq(Nat.cmp(U32.to_nat(x), U32.to_nat(0)))), U32.is_ne(x, 0), True{},
      Equal.cong(Cmp, Bool, k => Bool.not(Cmp.is_eq(k)), Nat.cmp(U32.to_nat(x), U32.to_nat(0)), U32.cmp(x, 0),
        cmp_nat_sym(x, 0)), h))

def lt_ne0(
  +c: U32, +n: U32, h: {U32.is_lt(c, n) == True{} : Bool}
) -> {U32.is_ne(n, 0) == True{} : Bool}:
  %cmp_nat_sym(n, 0) : {Bool.not(Cmp.is_eq(_)) == True{} : Bool}
  lt_ne0_nat(U32.to_nat(c), U32.to_nat(n),
    Equal.trans(Bool, Cmp.is_lt(Nat.cmp(U32.to_nat(c), U32.to_nat(n))), U32.is_lt(c, n), True{},
      Equal.cong(Cmp, Bool, k => Cmp.is_lt(k), Nat.cmp(U32.to_nat(c), U32.to_nat(n)), U32.cmp(c, n),
        cmp_nat_sym(c, n)), h))

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
        max_comm(x, y), Laws.merge_comm(xs, ys))

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
        max_assoc(x, y, z), Laws.merge_assoc(xs, ys, zs))

def Laws.merge_idem(a):
  match a:
    case Nil{}:
      {==}
    case Con{+x, +xs}:
      cons_eq(U32.max(x, x), x, Crdt.GCounter.merge(xs, xs), xs, max_self(x), Laws.merge_idem(xs))

def Laws.merge_upper_l(a, b):
  match a b:
    case Nil{} _:
      {==}
    case Con{+x, +xs} Nil{}:
      le_refl_list(Con{x, xs})
    case Con{+x, +xs} Con{+y, +ys}:
      MBool.and_eq_true(U32.is_le(x, U32.max(x, y)), Crdt.GCounter.le(xs, Crdt.GCounter.merge(xs, ys)),
        le_max_l(x, y), Laws.merge_upper_l(xs, ys))

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
        max_eq0(x, y,
          MBool.eq_true_of_and_left(U32.is_eq(x, 0), Crdt.GCounter.le(xs, Nil{}), ha),
          MBool.eq_true_of_and_left(U32.is_eq(y, 0), Crdt.GCounter.le(ys, Nil{}), hb)),
        Laws.merge_least(xs, ys, Nil{},
          MBool.eq_true_of_and_right(U32.is_eq(x, 0), Crdt.GCounter.le(xs, Nil{}), ha),
          MBool.eq_true_of_and_right(U32.is_eq(y, 0), Crdt.GCounter.le(ys, Nil{}), hb)))
    case Con{+x, +xs} Con{+y, +ys} Con{+z, +zs}:
      +ha = ha
      +hb = hb
      MBool.and_eq_true(U32.is_le(U32.max(x, y), z), Crdt.GCounter.le(Crdt.GCounter.merge(xs, ys), zs),
        max_le(x, y, z,
          MBool.eq_true_of_and_left(U32.is_le(x, z), Crdt.GCounter.le(xs, zs), ha),
          MBool.eq_true_of_and_left(U32.is_le(y, z), Crdt.GCounter.le(ys, zs), hb)),
        Laws.merge_least(xs, ys, zs,
          MBool.eq_true_of_and_right(U32.is_le(x, z), Crdt.GCounter.le(xs, zs), ha),
          MBool.eq_true_of_and_right(U32.is_le(y, z), Crdt.GCounter.le(ys, zs), hb)))

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
      ne0_max(x, y, hx)
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
