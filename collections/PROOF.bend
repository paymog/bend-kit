import Base
import ./LAWS.bend as Laws
import ./omap.bend as O
import ./nat_order.bend as Ord

def Laws.omap_keys_ascending_puts():
  {==}

def Laws.omap_size_del():
  {==}

def Laws.omap_get_after_rotations():
  {==}

def Laws.omap_keys_del_root():
  {==}

def Laws.omap_get_put():
  {==}

def Laws.omap_get_put_replace():
  {==}

def Laws.omap_get_put_other():
  {==}

def Laws.omap_get_missing():
  {==}

def Laws.omap_keys_sorted():
  {==}

def Laws.omap_size_replace():
  {==}

def Laws.omap_get_del():
  {==}

def Laws.omap_get_del_other():
  {==}

def Laws.omap_keys_del():
  {==}

def Laws.omap_string_keys():
  {==}

def Laws.oset_to_list():
  {==}

def Laws.oset_has_del():
  {==}

def Laws.vec_from_list():
  {==}

def Laws.vec_get():
  {==}

def Laws.vec_get_past_len():
  {==}

def Laws.vec_set():
  {==}

def Laws.vec_pop():
  {==}

def Laws.vec_pop_empty():
  {==}

def Laws.vec_pop_to_list():
  {==}

def Laws.deque_ends():
  {==}

def Laws.heap_sort():
  {==}

def isT(b: Bool) -> Type:
  match b:
    case True{}:
      Unit
    case False{}:
      Empty

def absurd_b(e: {False{} == True{} : Bool}) -> Empty:
  %Equal.sym(Bool, False{}, True{}, e) : isT(_)
  Unit{}

def exfalso(-A: Type, e: Empty) -> A:
  match e:

def and_l(a: Bool, b: Bool, e: {Bool.and(a, b) == True{} : Bool}) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      exfalso({False{} == True{} : Bool}, absurd_b(e))

def and_r(a: Bool, b: Bool, e: {Bool.and(a, b) == True{} : Bool}) -> {b == True{} : Bool}:
  match a:
    case True{}:
      e
    case False{}:
      exfalso({b == True{} : Bool}, absurd_b(e))

def and_i(
  a: Bool, b: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}
) -> {Bool.and(a, b) == True{} : Bool}:
  match a:
    case True{}:
      eb
    case False{}:
      exfalso({Bool.and(False{}, b) == True{} : Bool}, absurd_b(ea))

def c4.a(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool,
  e: {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}
) -> {a == True{} : Bool}:
  and_l(a, b, and_l(Bool.and(a, b), c, and_l(Bool.and(Bool.and(a, b), c), d, e)))

def c4.b(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool,
  e: {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}
) -> {b == True{} : Bool}:
  and_r(a, b, and_l(Bool.and(a, b), c, and_l(Bool.and(Bool.and(a, b), c), d, e)))

def c4.c(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool,
  e: {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}
) -> {c == True{} : Bool}:
  and_r(Bool.and(a, b), c, and_l(Bool.and(Bool.and(a, b), c), d, e))

def c4.d(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool,
  e: {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}
) -> {d == True{} : Bool}:
  and_r(Bool.and(Bool.and(a, b), c), d, e)

def c4.i(
  +a: Bool, +b: Bool, +c: Bool, +d: Bool, ea: {a == True{} : Bool},
  eb: {b == True{} : Bool}, ec: {c == True{} : Bool}, ed: {d == True{} : Bool}
) -> {Bool.and(Bool.and(Bool.and(a, b), c), d) == True{} : Bool}:
  and_i(Bool.and(Bool.and(a, b), c), d,
    and_i(Bool.and(a, b), c, and_i(a, b, ea, eb), ec), ed)


def c3.a(+a: Bool, +b: Bool, +c: Bool, e: {Bool.and(Bool.and(a, b), c) == True{} : Bool}) -> {a == True{} : Bool}:
  and_l(a, b, and_l(Bool.and(a, b), c, e))

def c3.b(+a: Bool, +b: Bool, +c: Bool, e: {Bool.and(Bool.and(a, b), c) == True{} : Bool}) -> {b == True{} : Bool}:
  and_r(a, b, and_l(Bool.and(a, b), c, e))

def c3.c(+a: Bool, +b: Bool, +c: Bool, e: {Bool.and(Bool.and(a, b), c) == True{} : Bool}) -> {c == True{} : Bool}:
  and_r(Bool.and(a, b), c, e)

def c3.i(+a: Bool, +b: Bool, +c: Bool, ea: {a == True{} : Bool}, eb: {b == True{} : Bool}, ec: {c == True{} : Bool})
  -> {Bool.and(Bool.and(a, b), c) == True{} : Bool}:
  and_i(Bool.and(a, b), c, and_i(a, b, ea, eb), ec)

def Laws.omap_new_searchtree(K, V, cmp):
  {==}

def head(-K: Data, xs: List<&2, K>) -> Maybe<&2, K>:
  match xs:
    case Nil{}:
      None{}
    case Con{h, t}:
      Some{h}

# The list is sorted and its first element lies above lb.
def sfrom(~K: Data, ~cmp: K -> K -> Cmp, lb: Maybe<&2, K>, xs: List<&2, K>) -> Bool:
  match lb:
    case None{}:
      Laws.sorted(~K, ~cmp, xs)
    case Some{b}:
      Laws.sorted.go(~K, ~cmp, xs, b)

# lb lies below ub, when both exist.
def lt_m(~K: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, ub: Maybe<&2, K>) -> Bool:
  match ub:
    case None{}:
      True{}
    case Some{u}:
      Laws.above(~K, ~cmp, lb, u)

def lt_m.some(
  ~K: Data, ~cmp: K -> K -> Cmp, ub: Maybe<&2, K>, +k: K,
  e: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}
) -> {lt_m(~K, ~cmp, Some{k}, ub) == True{} : Bool}:
  match ub:
    case None{}:
      {==}
    case Some{u}:
      e

def sfrom.base(
  ~K: Data, ~cmp: K -> K -> Cmp, lb: Maybe<&2, K>, acc: List<&2, K>,
  lt: {lt_m(~K, ~cmp, lb, head(K, acc)) == True{} : Bool},
  sa: {Laws.sorted(~K, ~cmp, acc) == True{} : Bool}
) -> {sfrom(~K, ~cmp, lb, acc) == True{} : Bool}:
  match lb acc:
    case None{} _:
      sa
    case Some{b} Nil{}:
      {==}
    case Some{+b} Con{+h, t}:
      and_i(Cmp.is_lt(cmp(b, h)), Laws.sorted.go(~K, ~cmp, t, h), lt, sa)

def keys_sorted.go(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, t: O.OMap<K, V>, +lb: Maybe<&2, K>,
  +acc: List<&2, K>,
  +bt: {Laws.bounded(~K, ~V, ~cmp, t, lb, head(K, acc)) == True{} : Bool},
  lt: {lt_m(~K, ~cmp, lb, head(K, acc)) == True{} : Bool},
  sa: {Laws.sorted(~K, ~cmp, acc) == True{} : Bool}
) -> {sfrom(~K, ~cmp, lb, O.OMap.keys.go(K, V, t, acc)) == True{} : Bool}:
  match t:
    case O.OTip{}:
      sfrom.base(~K, ~cmp, lb, acc, lt, sa)
    case O.OBin{s, +k, v, +lo, +hi}:
      +A = Laws.above(~K, ~cmp, lb, k)
      +B = Laws.below(~K, ~cmp, head(K, acc), k)
      +L = Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k})
      +H = Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, head(K, acc))
      ih = keys_sorted.go(~K, ~V, ~cmp, hi, Some{k}, acc, c4.d(A, B, L, H, bt),
        lt_m.some(~K, ~cmp, head(K, acc), k, c4.b(A, B, L, H, bt)), sa)
      keys_sorted.go(~K, ~V, ~cmp, lo, lb, k <> O.OMap.keys.go(K, V, hi, acc),
        c4.c(A, B, L, H, bt), c4.a(A, B, L, H, bt), ih)

def Laws.omap_searchtree_keys_sorted(K, V, cmp, m, tree):
  keys_sorted.go(~K, ~V, ~cmp, m, None{}, Nil{}, tree, {==}, {==})

def Trans(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}

def Flip(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> {cmp(y, x) == Laws.flip(cmp(x, y)) : Cmp}

def Refl(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> {cmp(x, x) == EQ{} : Cmp}

def Eq(~K: Data, ~cmp: K -> K -> Cmp) -> Type:
  @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}

def lt_of(c: Cmp, e: {Cmp.is_lt(c) == True{} : Bool}) -> {c == LT{} : Cmp}:
  match c:
    case LT{}:
      {==}
    case EQ{}:
      exfalso({EQ{} == LT{} : Cmp}, absurd_b(e))
    case GT{}:
      exfalso({GT{} == LT{} : Cmp}, absurd_b(e))

def lt_true(-c: Cmp, e: {c == LT{} : Cmp}) -> {Cmp.is_lt(c) == True{} : Bool}:
  Equal.cong(Cmp, Bool, x => Cmp.is_lt(x), c, LT{}, e)

def gt_flip(
  ~K: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp), +x: K, +y: K,
  e: {cmp(x, y) == GT{} : Cmp}
) -> {cmp(y, x) == LT{} : Cmp}:
  Equal.trans(Cmp, cmp(y, x), Laws.flip(cmp(x, y)), LT{}, flip(x, y),
    Equal.cong(Cmp, Cmp, c => Laws.flip(c), cmp(x, y), GT{}, e))

def lt_trans(
  ~K: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp), +x: K, +y: K, +z: K,
  e1: {Cmp.is_lt(cmp(x, y)) == True{} : Bool},
  e2: {Cmp.is_lt(cmp(y, z)) == True{} : Bool}
) -> {Cmp.is_lt(cmp(x, z)) == True{} : Bool}:
  lt_true(cmp(x, z), trans(x, y, z, lt_of(cmp(x, y), e1), lt_of(cmp(y, z), e2)))

def above_trans(
  ~K: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp), lb: Maybe<&2, K>,
  +k: K, +hk: K, ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  e: {Cmp.is_lt(cmp(k, hk)) == True{} : Bool}
) -> {Laws.above(~K, ~cmp, lb, hk) == True{} : Bool}:
  match lb:
    case None{}:
      {==}
    case Some{+b}:
      lt_trans(~K, ~cmp, ~trans, b, k, hk, ea, e)

def below_trans(
  ~K: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp), ub: Maybe<&2, K>,
  +k: K, +hk: K, e: {Cmp.is_lt(cmp(k, hk)) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, hk) == True{} : Bool}
) -> {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}:
  match ub:
    case None{}:
      {==}
    case Some{+u}:
      lt_trans(~K, ~cmp, ~trans, k, hk, u, e, eb)

# Projections and introduction for bounded on one node.
def bn.a(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {Laws.above(~K, ~cmp, lb, k) == True{} : Bool}:
  c4.a(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), e)

def bn.b(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}:
  c4.b(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), e)

def bn.l(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool}:
  c4.c(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), e)

def bn.h(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}:
  c4.d(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), e)

def bn.i(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}:
  c4.i(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
    Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}),
    Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub), ea, eb, el, eh)

def rot_lo.single.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V, +lo: O.OMap<K, V>,
  +hk: K, +hv: V, +hl: O.OMap<K, V>, +hh: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, hk, hv, hl, hh}, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.bin(K, V, hk, hv, O.OMap.bin(K, V, k, v, lo, hl), hh), lb, ub) == True{} : Bool}:
  +h_a = bn.a(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)
  bn.i(~K, ~V, ~cmp, lb, ub, hk, hv, O.OMap.bin(K, V, k, v, lo, hl), hh,
    above_trans(~K, ~cmp, ~trans, lb, k, hk, ea, h_a),
    bn.b(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh),
    bn.i(~K, ~V, ~cmp, lb, Some{hk}, k, v, lo, hl, ea, h_a, el,
      bn.l(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)),
    bn.h(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh))

def rot_lo.double.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  hl: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hk: K, +hv: V, +hh: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, hk, hv, hl, hh}, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.rot_lo.double(K, V, k, v, lo, hk, hv, hl, hh), lb, ub) == True{} : Bool}:
  match hl:
    case O.OTip{}:
      rot_lo.single.bnd(~K, ~V, ~cmp, ~trans, lb, ub, k, v, lo, hk, hv, O.OTip{}, hh,
        ea, el, eh)
    case O.OBin{s, +mk, +mv, +ml, +mh}:
      +hl = {O.OBin{0, mk, mv, ml, mh} : O.OMap<K, V>}
      +h_b = bn.b(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)
      +h_l = bn.l(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)
      +m_a = bn.a(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l)
      +m_b = bn.b(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l)
      bn.i(~K, ~V, ~cmp, lb, ub, mk, mv, O.OMap.bin(K, V, k, v, lo, ml),
        O.OMap.bin(K, V, hk, hv, mh, hh),
        above_trans(~K, ~cmp, ~trans, lb, k, mk, ea, m_a),
        below_trans(~K, ~cmp, ~trans, ub, mk, hk, m_b, h_b),
        bn.i(~K, ~V, ~cmp, lb, Some{mk}, k, v, lo, ml, ea, m_a, el,
          bn.l(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l)),
        bn.i(~K, ~V, ~cmp, Some{mk}, ub, hk, hv, mh, hh, m_b, h_b,
          bn.h(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l),
          bn.h(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)))

def rot_lo.pick.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  single: Bool, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hk: K, +hv: V, +hl: O.OMap<K, V>, +hh: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, hk, hv, hl, hh}, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.rot_lo.pick(K, V, single, k, v, lo, hk, hv, hl, hh), lb, ub) == True{} : Bool}:
  match single:
    case True{}:
      rot_lo.single.bnd(~K, ~V, ~cmp, ~trans, lb, ub, k, v, lo, hk, hv, hl, hh, ea, el, eh)
    case False{}:
      rot_lo.double.bnd(~K, ~V, ~cmp, ~trans, hl, lb, ub, k, v, lo, hk, hv, hh, ea, el, eh)

def rot_lo.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  hi: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lo: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.rot_lo(K, V, k, v, lo, hi), lb, ub) == True{} : Bool}:
  match hi:
    case O.OTip{}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, lo, O.OTip{}, ea, eb, el, eh)
    case O.OBin{s, +hk, +hv, +hl, +hh}:
      rot_lo.pick.bnd(~K, ~V, ~cmp, ~trans,
        U32.is_lt((O.OMap.size(K, V, hl) + 1 : U32),
          (2 * (O.OMap.size(K, V, hh) + 1) : U32)),
        lb, ub, k, v, lo, hk, hv, hl, hh, ea, el, eh)

def rot_hi.single.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V, +lk: K, +lv: V,
  +ll: O.OMap<K, V>, +lh: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, lk, lv, ll, lh}, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.bin(K, V, lk, lv, ll, O.OMap.bin(K, V, k, v, lh, hi)), lb, ub) == True{} : Bool}:
  +l_b = bn.b(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el)
  bn.i(~K, ~V, ~cmp, lb, ub, lk, lv, ll, O.OMap.bin(K, V, k, v, lh, hi),
    bn.a(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el),
    below_trans(~K, ~cmp, ~trans, ub, lk, k, l_b, eb),
    bn.l(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el),
    bn.i(~K, ~V, ~cmp, Some{lk}, ub, k, v, lh, hi, l_b, eb,
      bn.h(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el), eh))

def rot_hi.double.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  lh: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lk: K, +lv: V, +ll: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, lk, lv, ll, lh}, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.rot_hi.double(K, V, k, v, lk, lv, ll, lh, hi), lb, ub) == True{} : Bool}:
  match lh:
    case O.OTip{}:
      rot_hi.single.bnd(~K, ~V, ~cmp, ~trans, lb, ub, k, v, lk, lv, ll, O.OTip{}, hi,
        eb, el, eh)
    case O.OBin{s, +mk, +mv, +ml, +mh}:
      +lh = {O.OBin{0, mk, mv, ml, mh} : O.OMap<K, V>}
      +l_a = bn.a(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el)
      +l_h = bn.h(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el)
      +m_a = bn.a(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h)
      +m_b = bn.b(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h)
      bn.i(~K, ~V, ~cmp, lb, ub, mk, mv, O.OMap.bin(K, V, lk, lv, ll, ml),
        O.OMap.bin(K, V, k, v, mh, hi),
        above_trans(~K, ~cmp, ~trans, lb, lk, mk, l_a, m_a),
        below_trans(~K, ~cmp, ~trans, ub, mk, k, m_b, eb),
        bn.i(~K, ~V, ~cmp, lb, Some{mk}, lk, lv, ll, ml, l_a, m_a,
          bn.l(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el),
          bn.l(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h)),
        bn.i(~K, ~V, ~cmp, Some{mk}, ub, k, v, mh, hi, m_b, eb,
          bn.h(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h), eh))

def rot_hi.pick.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  single: Bool, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +lk: K, +lv: V, +ll: O.OMap<K, V>, +lh: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, lk, lv, ll, lh}, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.rot_hi.pick(K, V, single, k, v, lk, lv, ll, lh, hi), lb, ub) == True{} : Bool}:
  match single:
    case True{}:
      rot_hi.single.bnd(~K, ~V, ~cmp, ~trans, lb, ub, k, v, lk, lv, ll, lh, hi, eb, el, eh)
    case False{}:
      rot_hi.double.bnd(~K, ~V, ~cmp, ~trans, lh, lb, ub, k, v, lk, lv, ll, hi, eb, el, eh)

def rot_hi.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  lo: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +hi: O.OMap<K, V>,
  ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.rot_hi(K, V, k, v, lo, hi), lb, ub) == True{} : Bool}:
  match lo:
    case O.OTip{}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, O.OTip{}, hi, ea, eb, el, eh)
    case O.OBin{s, +lk, +lv, +ll, +lh}:
      rot_hi.pick.bnd(~K, ~V, ~cmp, ~trans,
        U32.is_lt((O.OMap.size(K, V, lh) + 1 : U32),
          (2 * (O.OMap.size(K, V, ll) + 1) : U32)),
        lb, ub, k, v, lk, lv, ll, lh, hi, eb, el, eh)

def balance.if.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  heavy_hi: Bool, heavy_lo: Bool, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K,
  +v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  +el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  +eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.balance.if(K, V, heavy_hi, heavy_lo, k, v, lo, hi), lb, ub) == True{} : Bool}:
  match heavy_hi heavy_lo:
    case True{} _:
      rot_lo.bnd(~K, ~V, ~cmp, ~trans, hi, lb, ub, k, v, lo, ea, eb, el, eh)
    case False{} True{}:
      rot_hi.bnd(~K, ~V, ~cmp, ~trans, lo, lb, ub, k, v, hi, ea, eb, el, eh)
    case False{} False{}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, lo, hi, ea, eb, el, eh)

def balance.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V, +lo: O.OMap<K, V>,
  +hi: O.OMap<K, V>,
  ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.balance(K, V, k, v, lo, hi), lb, ub) == True{} : Bool}:
  +wl = (O.OMap.size(K, V, lo) + 1 : U32)
  +wh = (O.OMap.size(K, V, hi) + 1 : U32)
  balance.if.bnd(~K, ~V, ~cmp, ~trans, U32.is_gt(wh, (3 * wl : U32)),
    U32.is_gt(wl, (3 * wh : U32)), lb, ub, k, v, lo, hi, ea, eb, el, eh)

# Proves a goal about O.Cmp.case by one case per comparison result.
def cmp.split(
  -A: Type, -B: Type, -F: A -> B, -G: B, c: Cmp, -f1: Unit -> A,
  -f2: Unit -> A, -f3: Unit -> A,
  hl: {c == LT{} : Cmp} -> {F(f1(Unit{})) == G : B},
  he: {c == EQ{} : Cmp} -> {F(f2(Unit{})) == G : B},
  hg: {c == GT{} : Cmp} -> {F(f3(Unit{})) == G : B}
) -> {F(O.Cmp.case(A, c, f1, f2, f3)) == G : B}:
  match c:
    case LT{}:
      hl({==})
    case EQ{}:
      he({==})
    case GT{}:
      hg({==})

def put.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp),
  ~trans: Trans(~K, ~cmp), t: O.OMap<K, V>, +lb: Maybe<&2, K>,
  +ub: Maybe<&2, K>, +k: K, +v: V,
  +bt: {Laws.bounded(~K, ~V, ~cmp, t, lb, ub) == True{} : Bool},
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.put(~K, ~V, ~cmp, t, k, v), lb, ub) == True{} : Bool}:
  match t:
    case O.OTip{}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, O.OTip{}, O.OTip{}, ea, eb, {==}, {==})
    case O.OBin{+s, +key, +val, +lo, +hi}:
      +b_a = bn.a(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_b = bn.b(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_l = bn.l(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_h = bn.h(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      cmp.split(O.OMap<K, V>, Bool, x => Laws.bounded(~K, ~V, ~cmp, x, lb, ub), True{},
        cmp(k, key),
        u => O.OMap.balance(K, V, key, val, O.OMap.put(~K, ~V, ~cmp, lo, k, v), hi),
        u => O.OBin{s, key, v, lo, hi},
        u => O.OMap.balance(K, V, key, val, lo, O.OMap.put(~K, ~V, ~cmp, hi, k, v)),
        e => balance.bnd(~K, ~V, ~cmp, ~trans, lb, ub, key, val,
          O.OMap.put(~K, ~V, ~cmp, lo, k, v), hi, b_a, b_b,
          put.bnd(~K, ~V, ~cmp, ~flip, ~trans, lo, lb, Some{key}, k, v, b_l, ea,
            lt_true(cmp(k, key), e)),
          b_h),
        e => bt,
        e => balance.bnd(~K, ~V, ~cmp, ~trans, lb, ub, key, val, lo,
          O.OMap.put(~K, ~V, ~cmp, hi, k, v), b_a, b_b, b_l,
          put.bnd(~K, ~V, ~cmp, ~flip, ~trans, hi, Some{key}, ub, k, v, b_h,
            lt_true(cmp(key, k), gt_flip(~K, ~cmp, ~flip, k, key, e)), eb)))

def Laws.omap_put_searchtree(K, V, cmp, refl, eq, flip, trans, m, tree, k, v):
  put.bnd(~K, ~V, ~cmp, ~flip, ~trans, m, None{}, None{}, k, v, tree, {==}, {==})

def rw(-A: Type, -P: A -> Type, -a: A, -b: A, e: {a == b : A}, p: P(b)) -> P(a):
  %Equal.sym(A, a, b, e) : P(_)
  p

def split(
  -P: Cmp -> Type, c: Cmp, hl: {c == LT{} : Cmp} -> P(LT{}),
  he: {c == EQ{} : Cmp} -> P(EQ{}), hg: {c == GT{} : Cmp} -> P(GT{})
) -> P(c):
  match c:
    case LT{}:
      hl({==})
    case EQ{}:
      he({==})
    case GT{}:
      hg({==})

def gt_of_lt(
  ~K: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp), +x: K, +y: K,
  e: {cmp(x, y) == LT{} : Cmp}
) -> {cmp(y, x) == GT{} : Cmp}:
  Equal.trans(Cmp, cmp(y, x), Laws.flip(cmp(x, y)), GT{}, flip(x, y),
    Equal.cong(Cmp, Cmp, c => Laws.flip(c), cmp(x, y), LT{}, e))

# get on one node, with the comparison result as a parameter.
def getc(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, c: Cmp, +x: K, +val: V,
  lo: O.OMap<K, V>, hi: O.OMap<K, V>
) -> Maybe<&2, V>:
  O.Cmp.case(Maybe<&2, V>, c,
    u => O.OMap.get(~K, ~V, ~cmp, lo, x),
    u => Some{val},
    u => O.OMap.get(~K, ~V, ~cmp, hi, x))

# get finds key k itself in a node keyed by k.
def get.here(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), +k: K, +v: V,
  +lo: O.OMap<K, V>, +hi: O.OMap<K, V>
) -> {O.OMap.get(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, k) == Some{v} : Maybe<&2, V>}:
  rw(Cmp, c => {getc(~K, ~V, ~cmp, c, k, v, lo, hi) == Some{v} : Maybe<&2, V>},
    cmp(k, k), EQ{}, refl(k), {==})

# get on a node goes to lo when the comparison is LT.
def get.lt(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +x: K, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hi: O.OMap<K, V>, e: {cmp(x, k) == LT{} : Cmp}
) -> {O.OMap.get(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, x)
      == O.OMap.get(~K, ~V, ~cmp, lo, x) : Maybe<&2, V>}:
  rw(Cmp, c => {getc(~K, ~V, ~cmp, c, x, v, lo, hi)
      == O.OMap.get(~K, ~V, ~cmp, lo, x) : Maybe<&2, V>},
    cmp(x, k), LT{}, e, {==})

# get on a node goes to hi when the comparison is GT.
def get.gt(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +x: K, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hi: O.OMap<K, V>, e: {cmp(x, k) == GT{} : Cmp}
) -> {O.OMap.get(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, x)
      == O.OMap.get(~K, ~V, ~cmp, hi, x) : Maybe<&2, V>}:
  rw(Cmp, c => {getc(~K, ~V, ~cmp, c, x, v, lo, hi)
      == O.OMap.get(~K, ~V, ~cmp, hi, x) : Maybe<&2, V>},
    cmp(x, k), GT{}, e, {==})

def rot_lo.single.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  +x: K, +k: K, +v: V, +lo: O.OMap<K, V>, +hk: K,
  +hv: V, +hl: O.OMap<K, V>, +hh: O.OMap<K, V>, +khk: {cmp(k, hk) == LT{} : Cmp}
) -> {O.OMap.get(~K, ~V, ~cmp,
       O.OMap.bin(K, V, hk, hv, O.OMap.bin(K, V, k, v, lo, hl), hh), x)
      == O.OMap.get(~K, ~V, ~cmp, O.OBin{0, k, v, lo, O.OBin{0, hk, hv, hl, hh}}, x)
      : Maybe<&2, V>}:
  +inner = {O.OBin{0, k, v, lo, hl} : O.OMap<K, V>}
  +lhs = {O.OBin{0, hk, hv, inner, hh} : O.OMap<K, V>}
  split(c => {O.OMap.get(~K, ~V, ~cmp, lhs, x)
      == getc(~K, ~V, ~cmp, c, x, v, lo, O.OBin{0, hk, hv, hl, hh}) : Maybe<&2, V>},
    cmp(x, k),
    +e => Equal.trans(Maybe<&2, V>, O.OMap.get(~K, ~V, ~cmp, lhs, x),
      O.OMap.get(~K, ~V, ~cmp, inner, x), O.OMap.get(~K, ~V, ~cmp, lo, x),
      get.lt(~K, ~V, ~cmp, x, hk, hv, inner, hh, trans(x, k, hk, e, khk)),
      get.lt(~K, ~V, ~cmp, x, k, v, lo, hl, e)),
    e => rw(K, y => {O.OMap.get(~K, ~V, ~cmp, lhs, y) == Some{v} : Maybe<&2, V>},
      x, k, eq(x, k, e),
      Equal.trans(Maybe<&2, V>, O.OMap.get(~K, ~V, ~cmp, lhs, k),
        O.OMap.get(~K, ~V, ~cmp, inner, k), Some{v},
        get.lt(~K, ~V, ~cmp, k, hk, hv, inner, hh, khk),
        get.here(~K, ~V, ~cmp, ~refl, k, v, lo, hl))),
    e => split(c => {getc(~K, ~V, ~cmp, c, x, hv, inner, hh)
        == getc(~K, ~V, ~cmp, c, x, hv, hl, hh) : Maybe<&2, V>},
      cmp(x, hk),
      e2 => get.gt(~K, ~V, ~cmp, x, k, v, lo, hl, e),
      e2 => {==},
      e2 => {==}))

def g(~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, t: O.OMap<K, V>, +x: K) -> Maybe<&2, V>:
  O.OMap.get(~K, ~V, ~cmp, t, x)

def mtr(
  -V: Data, -a: Maybe<&2, V>, -b: Maybe<&2, V>, -c: Maybe<&2, V>,
  e1: {a == b : Maybe<&2, V>}, e2: {b == c : Maybe<&2, V>}
) -> {a == c : Maybe<&2, V>}:
  Equal.trans(Maybe<&2, V>, a, b, c, e1, e2)

def rot_lo.double.get2(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  +x: K, +k: K, +v: V, +lo: O.OMap<K, V>, +hk: K, +hv: V, +mk: K, +mv: V,
  +ml: O.OMap<K, V>, +mh: O.OMap<K, V>, +hh: O.OMap<K, V>,
  +khm: {cmp(k, mk) == LT{} : Cmp}, +mhk: {cmp(mk, hk) == LT{} : Cmp}
) -> {g(~K, ~V, ~cmp, O.OMap.bin(K, V, mk, mv, O.OMap.bin(K, V, k, v, lo, ml),
        O.OMap.bin(K, V, hk, hv, mh, hh)), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, lo, O.OBin{0, hk, hv, O.OBin{0, mk, mv, ml, mh}, hh}}, x)
      : Maybe<&2, V>}:
  +a = {O.OBin{0, k, v, lo, ml} : O.OMap<K, V>}
  +b = {O.OBin{0, hk, hv, mh, hh} : O.OMap<K, V>}
  +l = {O.OBin{0, mk, mv, a, b} : O.OMap<K, V>}
  +m = {O.OBin{0, mk, mv, ml, mh} : O.OMap<K, V>}
  +r1 = {O.OBin{0, hk, hv, m, hh} : O.OMap<K, V>}
  split(c => {g(~K, ~V, ~cmp, l, x) == getc(~K, ~V, ~cmp, c, x, v, lo, r1) : Maybe<&2, V>},
    cmp(x, k),
    +e => mtr(V, g(~K, ~V, ~cmp, l, x), g(~K, ~V, ~cmp, a, x), g(~K, ~V, ~cmp, lo, x),
      get.lt(~K, ~V, ~cmp, x, mk, mv, a, b, trans(x, k, mk, e, khm)),
      get.lt(~K, ~V, ~cmp, x, k, v, lo, ml, e)),
    e => rw(K, y => {g(~K, ~V, ~cmp, l, y) == Some{v} : Maybe<&2, V>}, x, k, eq(x, k, e),
      mtr(V, g(~K, ~V, ~cmp, l, k), g(~K, ~V, ~cmp, a, k), Some{v},
        get.lt(~K, ~V, ~cmp, k, mk, mv, a, b, khm),
        get.here(~K, ~V, ~cmp, ~refl, k, v, lo, ml))),
    +e => split(c => {g(~K, ~V, ~cmp, l, x) == getc(~K, ~V, ~cmp, c, x, hv, m, hh) : Maybe<&2, V>},
      cmp(x, hk),
      +e2 => split(c => {getc(~K, ~V, ~cmp, c, x, mv, a, b)
          == getc(~K, ~V, ~cmp, c, x, mv, ml, mh) : Maybe<&2, V>},
        cmp(x, mk),
        e3 => get.gt(~K, ~V, ~cmp, x, k, v, lo, ml, e),
        e3 => {==},
        e3 => get.lt(~K, ~V, ~cmp, x, hk, hv, mh, hh, e2)),
      e2 => rw(K, y => {g(~K, ~V, ~cmp, l, y) == Some{hv} : Maybe<&2, V>}, x, hk, eq(x, hk, e2),
        mtr(V, g(~K, ~V, ~cmp, l, hk), g(~K, ~V, ~cmp, b, hk), Some{hv},
          get.gt(~K, ~V, ~cmp, hk, mk, mv, a, b, gt_of_lt(~K, ~cmp, ~flip, mk, hk, mhk)),
          get.here(~K, ~V, ~cmp, ~refl, hk, hv, mh, hh))),
      +e2 => mtr(V, g(~K, ~V, ~cmp, l, x), g(~K, ~V, ~cmp, b, x), g(~K, ~V, ~cmp, hh, x),
        get.gt(~K, ~V, ~cmp, x, mk, mv, a, b,
          gt_of_lt(~K, ~cmp, ~flip, mk, x,
            trans(mk, hk, x, mhk, gt_flip(~K, ~cmp, ~flip, x, hk, e2)))),
        get.gt(~K, ~V, ~cmp, x, hk, hv, mh, hh, e2))))

def rot_lo.double.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  hl: O.OMap<K, V>, +x: K, +k: K, +v: V, +lo: O.OMap<K, V>, +hk: K, +hv: V,
  +hh: O.OMap<K, V>, +khk: {cmp(k, hk) == LT{} : Cmp},
  +h_l: {Laws.bounded(~K, ~V, ~cmp, hl, Some{k}, Some{hk}) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.rot_lo.double(K, V, k, v, lo, hk, hv, hl, hh), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, lo, O.OBin{0, hk, hv, hl, hh}}, x) : Maybe<&2, V>}:
  match hl:
    case O.OTip{}:
      rot_lo.single.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, x, k, v, lo, hk, hv,
        O.OTip{}, hh, khk)
    case O.OBin{s, +mk, +mv, +ml, +mh}:
      rot_lo.double.get2(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, x, k, v, lo, hk, hv,
        mk, mv, ml, mh, hh,
        lt_of(cmp(k, mk), bn.a(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l)),
        lt_of(cmp(mk, hk), bn.b(~K, ~V, ~cmp, Some{k}, Some{hk}, mk, mv, ml, mh, h_l)))

def rot_lo.pick.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  single: Bool, +x: K, +k: K, +v: V, +lo: O.OMap<K, V>, +hk: K, +hv: V,
  +hl: O.OMap<K, V>, +hh: O.OMap<K, V>, +khk: {cmp(k, hk) == LT{} : Cmp},
  +h_l: {Laws.bounded(~K, ~V, ~cmp, hl, Some{k}, Some{hk}) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.rot_lo.pick(K, V, single, k, v, lo, hk, hv, hl, hh), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, lo, O.OBin{0, hk, hv, hl, hh}}, x) : Maybe<&2, V>}:
  match single:
    case True{}:
      rot_lo.single.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, x, k, v, lo, hk, hv,
        hl, hh, khk)
    case False{}:
      rot_lo.double.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, hl, x, k, v, lo, hk, hv,
        hh, khk, h_l)

def rot_lo.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  hi: O.OMap<K, V>, +ub: Maybe<&2, K>, +x: K, +k: K, +v: V, +lo: O.OMap<K, V>,
  +eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.rot_lo(K, V, k, v, lo, hi), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, x) : Maybe<&2, V>}:
  match hi:
    case O.OTip{}:
      {==}
    case O.OBin{s, +hk, +hv, +hl, +hh}:
      rot_lo.pick.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans,
        U32.is_lt((O.OMap.size(K, V, hl) + 1 : U32),
          (2 * (O.OMap.size(K, V, hh) + 1) : U32)),
        x, k, v, lo, hk, hv, hl, hh,
        lt_of(cmp(k, hk), bn.a(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh)),
        bn.l(~K, ~V, ~cmp, Some{k}, ub, hk, hv, hl, hh, eh))

def rot_hi.single.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  +x: K, +k: K, +v: V, +lk: K, +lv: V, +ll: O.OMap<K, V>, +lh: O.OMap<K, V>,
  +hi: O.OMap<K, V>, +lkk: {cmp(lk, k) == LT{} : Cmp}
) -> {g(~K, ~V, ~cmp, O.OMap.bin(K, V, lk, lv, ll, O.OMap.bin(K, V, k, v, lh, hi)), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, O.OBin{0, lk, lv, ll, lh}, hi}, x) : Maybe<&2, V>}:
  +b = {O.OBin{0, k, v, lh, hi} : O.OMap<K, V>}
  +l = {O.OBin{0, lk, lv, ll, b} : O.OMap<K, V>}
  +ln = {O.OBin{0, lk, lv, ll, lh} : O.OMap<K, V>}
  split(c => {g(~K, ~V, ~cmp, l, x) == getc(~K, ~V, ~cmp, c, x, v, ln, hi) : Maybe<&2, V>},
    cmp(x, k),
    e => split(c => {getc(~K, ~V, ~cmp, c, x, lv, ll, b)
        == getc(~K, ~V, ~cmp, c, x, lv, ll, lh) : Maybe<&2, V>},
      cmp(x, lk),
      e2 => {==},
      e2 => {==},
      e2 => get.lt(~K, ~V, ~cmp, x, k, v, lh, hi, e)),
    e => rw(K, y => {g(~K, ~V, ~cmp, l, y) == Some{v} : Maybe<&2, V>}, x, k, eq(x, k, e),
      mtr(V, g(~K, ~V, ~cmp, l, k), g(~K, ~V, ~cmp, b, k), Some{v},
        get.gt(~K, ~V, ~cmp, k, lk, lv, ll, b, gt_of_lt(~K, ~cmp, ~flip, lk, k, lkk)),
        get.here(~K, ~V, ~cmp, ~refl, k, v, lh, hi))),
    +e => mtr(V, g(~K, ~V, ~cmp, l, x), g(~K, ~V, ~cmp, b, x), g(~K, ~V, ~cmp, hi, x),
      get.gt(~K, ~V, ~cmp, x, lk, lv, ll, b,
        gt_of_lt(~K, ~cmp, ~flip, lk, x,
          trans(lk, k, x, lkk, gt_flip(~K, ~cmp, ~flip, x, k, e)))),
      get.gt(~K, ~V, ~cmp, x, k, v, lh, hi, e)))

def rot_hi.double.get2(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  +x: K, +k: K, +v: V, +lk: K, +lv: V, +ll: O.OMap<K, V>, +mk: K, +mv: V,
  +ml: O.OMap<K, V>, +mh: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +lkm: {cmp(lk, mk) == LT{} : Cmp}, +mkk: {cmp(mk, k) == LT{} : Cmp}
) -> {g(~K, ~V, ~cmp, O.OMap.bin(K, V, mk, mv, O.OMap.bin(K, V, lk, lv, ll, ml),
        O.OMap.bin(K, V, k, v, mh, hi)), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, O.OBin{0, lk, lv, ll, O.OBin{0, mk, mv, ml, mh}}, hi}, x)
      : Maybe<&2, V>}:
  +a = {O.OBin{0, lk, lv, ll, ml} : O.OMap<K, V>}
  +b = {O.OBin{0, k, v, mh, hi} : O.OMap<K, V>}
  +l = {O.OBin{0, mk, mv, a, b} : O.OMap<K, V>}
  +m = {O.OBin{0, mk, mv, ml, mh} : O.OMap<K, V>}
  +ln = {O.OBin{0, lk, lv, ll, m} : O.OMap<K, V>}
  split(c => {g(~K, ~V, ~cmp, l, x) == getc(~K, ~V, ~cmp, c, x, v, ln, hi) : Maybe<&2, V>},
    cmp(x, k),
    +e => split(c => {g(~K, ~V, ~cmp, l, x) == getc(~K, ~V, ~cmp, c, x, lv, ll, m) : Maybe<&2, V>},
      cmp(x, lk),
      +e2 => mtr(V, g(~K, ~V, ~cmp, l, x), g(~K, ~V, ~cmp, a, x), g(~K, ~V, ~cmp, ll, x),
        get.lt(~K, ~V, ~cmp, x, mk, mv, a, b, trans(x, lk, mk, e2, lkm)),
        get.lt(~K, ~V, ~cmp, x, lk, lv, ll, ml, e2)),
      e2 => rw(K, y => {g(~K, ~V, ~cmp, l, y) == Some{lv} : Maybe<&2, V>}, x, lk, eq(x, lk, e2),
        mtr(V, g(~K, ~V, ~cmp, l, lk), g(~K, ~V, ~cmp, a, lk), Some{lv},
          get.lt(~K, ~V, ~cmp, lk, mk, mv, a, b, lkm),
          get.here(~K, ~V, ~cmp, ~refl, lk, lv, ll, ml))),
      +e2 => split(c => {getc(~K, ~V, ~cmp, c, x, mv, a, b)
          == getc(~K, ~V, ~cmp, c, x, mv, ml, mh) : Maybe<&2, V>},
        cmp(x, mk),
        e3 => get.gt(~K, ~V, ~cmp, x, lk, lv, ll, ml, e2),
        e3 => {==},
        e3 => get.lt(~K, ~V, ~cmp, x, k, v, mh, hi, e))),
    e => rw(K, y => {g(~K, ~V, ~cmp, l, y) == Some{v} : Maybe<&2, V>}, x, k, eq(x, k, e),
      mtr(V, g(~K, ~V, ~cmp, l, k), g(~K, ~V, ~cmp, b, k), Some{v},
        get.gt(~K, ~V, ~cmp, k, mk, mv, a, b, gt_of_lt(~K, ~cmp, ~flip, mk, k, mkk)),
        get.here(~K, ~V, ~cmp, ~refl, k, v, mh, hi))),
    +e => mtr(V, g(~K, ~V, ~cmp, l, x), g(~K, ~V, ~cmp, b, x), g(~K, ~V, ~cmp, hi, x),
      get.gt(~K, ~V, ~cmp, x, mk, mv, a, b,
        gt_of_lt(~K, ~cmp, ~flip, mk, x,
          trans(mk, k, x, mkk, gt_flip(~K, ~cmp, ~flip, x, k, e)))),
      get.gt(~K, ~V, ~cmp, x, k, v, mh, hi, e)))

def rot_hi.double.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  lh: O.OMap<K, V>, +x: K, +k: K, +v: V, +lk: K, +lv: V, +ll: O.OMap<K, V>,
  +hi: O.OMap<K, V>, +lkk: {cmp(lk, k) == LT{} : Cmp},
  +l_h: {Laws.bounded(~K, ~V, ~cmp, lh, Some{lk}, Some{k}) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.rot_hi.double(K, V, k, v, lk, lv, ll, lh, hi), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, O.OBin{0, lk, lv, ll, lh}, hi}, x) : Maybe<&2, V>}:
  match lh:
    case O.OTip{}:
      rot_hi.single.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, x, k, v, lk, lv, ll,
        O.OTip{}, hi, lkk)
    case O.OBin{s, +mk, +mv, +ml, +mh}:
      rot_hi.double.get2(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, x, k, v, lk, lv, ll,
        mk, mv, ml, mh, hi,
        lt_of(cmp(lk, mk), bn.a(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h)),
        lt_of(cmp(mk, k), bn.b(~K, ~V, ~cmp, Some{lk}, Some{k}, mk, mv, ml, mh, l_h)))

def rot_hi.pick.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  single: Bool, +x: K, +k: K, +v: V, +lk: K, +lv: V, +ll: O.OMap<K, V>,
  +lh: O.OMap<K, V>, +hi: O.OMap<K, V>, +lkk: {cmp(lk, k) == LT{} : Cmp},
  +l_h: {Laws.bounded(~K, ~V, ~cmp, lh, Some{lk}, Some{k}) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.rot_hi.pick(K, V, single, k, v, lk, lv, ll, lh, hi), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, O.OBin{0, lk, lv, ll, lh}, hi}, x) : Maybe<&2, V>}:
  match single:
    case True{}:
      rot_hi.single.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, x, k, v, lk, lv, ll,
        lh, hi, lkk)
    case False{}:
      rot_hi.double.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, lh, x, k, v, lk, lv,
        ll, hi, lkk, l_h)

def rot_hi.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  lo: O.OMap<K, V>, +lb: Maybe<&2, K>, +x: K, +k: K, +v: V, +hi: O.OMap<K, V>,
  +el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.rot_hi(K, V, k, v, lo, hi), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, x) : Maybe<&2, V>}:
  match lo:
    case O.OTip{}:
      {==}
    case O.OBin{s, +lk, +lv, +ll, +lh}:
      rot_hi.pick.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans,
        U32.is_lt((O.OMap.size(K, V, lh) + 1 : U32),
          (2 * (O.OMap.size(K, V, ll) + 1) : U32)),
        x, k, v, lk, lv, ll, lh, hi,
        lt_of(cmp(lk, k), bn.b(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el)),
        bn.h(~K, ~V, ~cmp, lb, Some{k}, lk, lv, ll, lh, el))

def balance.if.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  heavy_hi: Bool, heavy_lo: Bool, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +x: K,
  +k: K, +v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.balance.if(K, V, heavy_hi, heavy_lo, k, v, lo, hi), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, x) : Maybe<&2, V>}:
  match heavy_hi heavy_lo:
    case True{} _:
      rot_lo.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, hi, ub, x, k, v, lo, eh)
    case False{} True{}:
      rot_hi.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, lo, lb, x, k, v, hi, el)
    case False{} False{}:
      {==}

def balance.get(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +x: K, +k: K, +v: V, +lo: O.OMap<K, V>,
  +hi: O.OMap<K, V>,
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{k}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.balance(K, V, k, v, lo, hi), x)
      == g(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, x) : Maybe<&2, V>}:
  +wl = (O.OMap.size(K, V, lo) + 1 : U32)
  +wh = (O.OMap.size(K, V, hi) + 1 : U32)
  balance.if.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, U32.is_gt(wh, (3 * wl : U32)),
    U32.is_gt(wl, (3 * wh : U32)), lb, ub, x, k, v, lo, hi, el, eh)

def get_put_same(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  t: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +bt: {Laws.bounded(~K, ~V, ~cmp, t, lb, ub) == True{} : Bool},
  +ea: {Laws.above(~K, ~cmp, lb, k) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.put(~K, ~V, ~cmp, t, k, v), k) == Some{v} : Maybe<&2, V>}:
  match t:
    case O.OTip{}:
      get.here(~K, ~V, ~cmp, ~refl, k, v, O.OTip{}, O.OTip{})
    case O.OBin{+s, +key, +val, +lo, +hi}:
      +b_l = bn.l(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_h = bn.h(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +plo = O.OMap.put(~K, ~V, ~cmp, lo, k, v)
      +phi = O.OMap.put(~K, ~V, ~cmp, hi, k, v)
      cmp.split(O.OMap<K, V>, Maybe<&2, V>, y => g(~K, ~V, ~cmp, y, k), Some{v},
        cmp(k, key),
        u => O.OMap.balance(K, V, key, val, O.OMap.put(~K, ~V, ~cmp, lo, k, v), hi),
        u => O.OBin{s, key, v, lo, hi},
        u => O.OMap.balance(K, V, key, val, lo, O.OMap.put(~K, ~V, ~cmp, hi, k, v)),
        +e => mtr(V, g(~K, ~V, ~cmp, O.OMap.balance(K, V, key, val, plo, hi), k),
          g(~K, ~V, ~cmp, O.OBin{0, key, val, plo, hi}, k), Some{v},
          balance.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, lb, ub, k, key, val, plo, hi,
            put.bnd(~K, ~V, ~cmp, ~flip, ~trans, lo, lb, Some{key}, k, v, b_l, ea,
              lt_true(cmp(k, key), e)),
            b_h),
          mtr(V, g(~K, ~V, ~cmp, O.OBin{0, key, val, plo, hi}, k), g(~K, ~V, ~cmp, plo, k),
            Some{v},
            get.lt(~K, ~V, ~cmp, k, key, val, plo, hi, e),
            get_put_same(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, lo, lb, Some{key}, k, v,
              b_l, ea, lt_true(cmp(k, key), e)))),
        e => rw(Cmp, c => {getc(~K, ~V, ~cmp, c, k, v, lo, hi) == Some{v} : Maybe<&2, V>},
          cmp(k, key), EQ{}, e, {==}),
        +e => mtr(V, g(~K, ~V, ~cmp, O.OMap.balance(K, V, key, val, lo, phi), k),
          g(~K, ~V, ~cmp, O.OBin{0, key, val, lo, phi}, k), Some{v},
          balance.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, lb, ub, k, key, val, lo, phi,
            b_l,
            put.bnd(~K, ~V, ~cmp, ~flip, ~trans, hi, Some{key}, ub, k, v, b_h,
              lt_true(cmp(key, k), gt_flip(~K, ~cmp, ~flip, k, key, e)), eb)),
          mtr(V, g(~K, ~V, ~cmp, O.OBin{0, key, val, lo, phi}, k), g(~K, ~V, ~cmp, phi, k),
            Some{v},
            get.gt(~K, ~V, ~cmp, k, key, val, lo, phi, e),
            get_put_same(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, hi, Some{key}, ub, k, v,
              b_h, lt_true(cmp(key, k), gt_flip(~K, ~cmp, ~flip, k, key, e)), eb))))

def Laws.omap_get_put_same(K, V, cmp, refl, eq, flip, trans, m, tree, k, v):
  get_put_same(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, m, None{}, None{}, k, v, tree,
    {==}, {==})

def neq_false(c: Cmp, ne: {c != EQ{} : Cmp}) -> {Cmp.is_eq(c) == False{} : Bool}:
  match c:
    case LT{}:
      {==}
    case EQ{}:
      exfalso({Cmp.is_eq(EQ{}) == False{} : Bool}, ne({==}))
    case GT{}:
      {==}

def ne_absurd(
  -A: Type, -c: Cmp, nef: {Cmp.is_eq(c) == False{} : Bool}, e: {c == EQ{} : Cmp}
) -> A:
  +tf = Equal.trans(Bool, True{}, Cmp.is_eq(c), False{},
    Equal.sym(Bool, Cmp.is_eq(c), True{}, Equal.cong(Cmp, Bool, x => Cmp.is_eq(x), c, EQ{}, e)),
    nef)
  exfalso(A, absurd_b(Equal.sym(Bool, True{}, False{}, tf)))

def eq_flip(
  ~K: Data, ~cmp: K -> K -> Cmp, ~flip: Flip(~K, ~cmp), +x: K, +y: K,
  e: {cmp(x, y) == EQ{} : Cmp}
) -> {cmp(y, x) == EQ{} : Cmp}:
  Equal.trans(Cmp, cmp(y, x), Laws.flip(cmp(x, y)), EQ{}, flip(x, y),
    Equal.cong(Cmp, Cmp, c => Laws.flip(c), cmp(x, y), EQ{}, e))

def get_put_other(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~refl: Refl(~K, ~cmp), ~eq: Eq(~K, ~cmp),
  ~flip: Flip(~K, ~cmp), ~trans: Trans(~K, ~cmp),
  t: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k2: K, +k: K, +v: V,
  +bt: {Laws.bounded(~K, ~V, ~cmp, t, lb, ub) == True{} : Bool},
  +ea: {Laws.above(~K, ~cmp, lb, k2) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k2) == True{} : Bool},
  +nef: {Cmp.is_eq(cmp(k2, k)) == False{} : Bool}
) -> {g(~K, ~V, ~cmp, O.OMap.put(~K, ~V, ~cmp, t, k2, v), k)
      == g(~K, ~V, ~cmp, t, k) : Maybe<&2, V>}:
  match t:
    case O.OTip{}:
      split(c => {getc(~K, ~V, ~cmp, c, k, v, O.OTip{}, O.OTip{}) == None{} : Maybe<&2, V>},
        cmp(k, k2),
        e => {==},
        e => ne_absurd({Some{v} == None{} : Maybe<&2, V>}, cmp(k2, k), nef,
          eq_flip(~K, ~cmp, ~flip, k, k2, e)),
        e => {==})
    case O.OBin{+s, +key, +val, +lo, +hi}:
      +b_l = bn.l(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_h = bn.h(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +plo = O.OMap.put(~K, ~V, ~cmp, lo, k2, v)
      +phi = O.OMap.put(~K, ~V, ~cmp, hi, k2, v)
      +old = {O.OBin{s, key, val, lo, hi} : O.OMap<K, V>}
      cmp.split(O.OMap<K, V>, Maybe<&2, V>, y => g(~K, ~V, ~cmp, y, k),
        g(~K, ~V, ~cmp, old, k), cmp(k2, key),
        u => O.OMap.balance(K, V, key, val, O.OMap.put(~K, ~V, ~cmp, lo, k2, v), hi),
        u => O.OBin{s, key, v, lo, hi},
        u => O.OMap.balance(K, V, key, val, lo, O.OMap.put(~K, ~V, ~cmp, hi, k2, v)),
        +e => mtr(V, g(~K, ~V, ~cmp, O.OMap.balance(K, V, key, val, plo, hi), k),
          g(~K, ~V, ~cmp, O.OBin{0, key, val, plo, hi}, k), g(~K, ~V, ~cmp, old, k),
          balance.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, lb, ub, k, key, val, plo, hi,
            put.bnd(~K, ~V, ~cmp, ~flip, ~trans, lo, lb, Some{key}, k2, v, b_l, ea,
              lt_true(cmp(k2, key), e)),
            b_h),
          split(c => {getc(~K, ~V, ~cmp, c, k, val, plo, hi)
              == getc(~K, ~V, ~cmp, c, k, val, lo, hi) : Maybe<&2, V>},
            cmp(k, key),
            e2 => get_put_other(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, lo, lb, Some{key},
              k2, k, v, b_l, ea, lt_true(cmp(k2, key), e), nef),
            e2 => {==},
            e2 => {==})),
        +e => split(c => {getc(~K, ~V, ~cmp, c, k, v, lo, hi)
            == getc(~K, ~V, ~cmp, c, k, val, lo, hi) : Maybe<&2, V>},
          cmp(k, key),
          e2 => {==},
          e2 => ne_absurd({Some{v} == Some{val} : Maybe<&2, V>}, cmp(k2, k), nef,
            rw(K, y => {cmp(y, k) == EQ{} : Cmp}, k2, key, eq(k2, key, e),
              eq_flip(~K, ~cmp, ~flip, k, key, e2))),
          e2 => {==}),
        +e => mtr(V, g(~K, ~V, ~cmp, O.OMap.balance(K, V, key, val, lo, phi), k),
          g(~K, ~V, ~cmp, O.OBin{0, key, val, lo, phi}, k), g(~K, ~V, ~cmp, old, k),
          balance.get(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, lb, ub, k, key, val, lo, phi,
            b_l,
            put.bnd(~K, ~V, ~cmp, ~flip, ~trans, hi, Some{key}, ub, k2, v, b_h,
              lt_true(cmp(key, k2), gt_flip(~K, ~cmp, ~flip, k2, key, e)), eb)),
          split(c => {getc(~K, ~V, ~cmp, c, k, val, lo, phi)
              == getc(~K, ~V, ~cmp, c, k, val, lo, hi) : Maybe<&2, V>},
            cmp(k, key),
            e2 => {==},
            e2 => {==},
            e2 => get_put_other(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, hi, Some{key}, ub,
              k2, k, v, b_h, lt_true(cmp(key, k2), gt_flip(~K, ~cmp, ~flip, k2, key, e)),
              eb, nef))))

def Laws.omap_get_put_other_key(K, V, cmp, refl, eq, flip, trans, m, tree, k2, k, ne, v):
  get_put_other(~K, ~V, ~cmp, ~refl, ~eq, ~flip, ~trans, m, None{}, None{}, k2, k, v, tree,
    {==}, {==}, neq_false(cmp(k2, k), ne))

# A tree bounded above by a is bounded above by anything above a.
def weaken_hi(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  t: O.OMap<K, V>, +lb: Maybe<&2, K>, +a: K, +ub: Maybe<&2, K>,
  +e: {Laws.bounded(~K, ~V, ~cmp, t, lb, Some{a}) == True{} : Bool},
  +eab: {Laws.below(~K, ~cmp, ub, a) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, t, lb, ub) == True{} : Bool}:
  match t:
    case O.OTip{}:
      {==}
    case O.OBin{s, +k, +v, +lo, +hi}:
      bn.i(~K, ~V, ~cmp, lb, ub, k, v, lo, hi,
        bn.a(~K, ~V, ~cmp, lb, Some{a}, k, v, lo, hi, e),
        below_trans(~K, ~cmp, ~trans, ub, k, a,
          bn.b(~K, ~V, ~cmp, lb, Some{a}, k, v, lo, hi, e), eab),
        bn.l(~K, ~V, ~cmp, lb, Some{a}, k, v, lo, hi, e),
        weaken_hi(~K, ~V, ~cmp, ~trans, hi, Some{k}, a, ub,
          bn.h(~K, ~V, ~cmp, lb, Some{a}, k, v, lo, hi, e), eab))

# What pop_min answers: its key lies between the bounds, and the rest lies above it.
def PM(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  r: K & V & O.OMap<K, V>
) -> Bool:
  (+mk, mv, t) = r
  Bool.and(Bool.and(Laws.above(~K, ~cmp, lb, mk), Laws.below(~K, ~cmp, ub, mk)),
    Laws.bounded(~K, ~V, ~cmp, t, Some{mk}, ub))

def pm.fin.bnd.go(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  +mk: K, +mv: V, +t: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K,
  +v: V, +hi: O.OMap<K, V>,
  +ih: {PM(~K, ~V, ~cmp, lb, Some{k}, {(mk, mv, t) : K & V & O.OMap<K, V>}) == True{} : Bool},
  +eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {PM(~K, ~V, ~cmp, lb, ub,
       O.OMap.pop_min.fin(K, V, k, v, hi, {(mk, mv, t) : K & V & O.OMap<K, V>})) == True{} : Bool}:
  +ab = Bool.and(Laws.above(~K, ~cmp, lb, mk), Laws.below(~K, ~cmp, Some{k}, mk))
  +c = Laws.bounded(~K, ~V, ~cmp, t, Some{mk}, Some{k})
  +eab = and_l(ab, c, ih)
  +mkk = and_r(Laws.above(~K, ~cmp, lb, mk), Laws.below(~K, ~cmp, Some{k}, mk), eab)
  and_i(Bool.and(Laws.above(~K, ~cmp, lb, mk), Laws.below(~K, ~cmp, ub, mk)),
    Laws.bounded(~K, ~V, ~cmp, O.OMap.balance(K, V, k, v, t, hi), Some{mk}, ub),
    and_i(Laws.above(~K, ~cmp, lb, mk), Laws.below(~K, ~cmp, ub, mk),
      and_l(Laws.above(~K, ~cmp, lb, mk), Laws.below(~K, ~cmp, Some{k}, mk), eab),
      below_trans(~K, ~cmp, ~trans, ub, mk, k, mkk, eb)),
    balance.bnd(~K, ~V, ~cmp, ~trans, Some{mk}, ub, k, v, t, hi, mkk, eb,
      and_r(ab, c, ih), eh))

# Workaround for https://github.com/bendlang/bend/issues/1077: bind the tuple without +.
def pm.fin.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  r: K & V & O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +hi: O.OMap<K, V>,
  ih: {PM(~K, ~V, ~cmp, lb, Some{k}, r) == True{} : Bool},
  eb: {Laws.below(~K, ~cmp, ub, k) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub) == True{} : Bool}
) -> {PM(~K, ~V, ~cmp, lb, ub, O.OMap.pop_min.fin(K, V, k, v, hi, r)) == True{} : Bool}:
  (mk, rest) = r
  (mv, t) = rest
  pm.fin.bnd.go(~K, ~V, ~cmp, ~trans, mk, mv, t, lb, ub, k, v, hi, ih, eb, eh)

def pm.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  lo: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K, +v: V,
  +hi: O.OMap<K, V>,
  +e: {Laws.bounded(~K, ~V, ~cmp, O.OBin{0, k, v, lo, hi}, lb, ub) == True{} : Bool}
) -> {PM(~K, ~V, ~cmp, lb, ub, O.OMap.pop_min(K, V, lo, k, v, hi)) == True{} : Bool}:
  match lo:
    case O.OTip{}:
      and_i(Bool.and(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k)),
        Laws.bounded(~K, ~V, ~cmp, hi, Some{k}, ub),
        and_i(Laws.above(~K, ~cmp, lb, k), Laws.below(~K, ~cmp, ub, k),
          bn.a(~K, ~V, ~cmp, lb, ub, k, v, O.OTip{}, hi, e),
          bn.b(~K, ~V, ~cmp, lb, ub, k, v, O.OTip{}, hi, e)),
        bn.h(~K, ~V, ~cmp, lb, ub, k, v, O.OTip{}, hi, e))
    case O.OBin{s, +lk, +lv, +ll, +lh}:
      +lo = {O.OBin{0, lk, lv, ll, lh} : O.OMap<K, V>}
      pm.fin.bnd(~K, ~V, ~cmp, ~trans, O.OMap.pop_min(K, V, ll, lk, lv, lh), lb, ub, k, v, hi,
        pm.bnd(~K, ~V, ~cmp, ~trans, ll, lb, Some{k}, lk, lv, lh,
          bn.l(~K, ~V, ~cmp, lb, ub, k, v, lo, hi, e)),
        bn.b(~K, ~V, ~cmp, lb, ub, k, v, lo, hi, e),
        bn.h(~K, ~V, ~cmp, lb, ub, k, v, lo, hi, e))

def glue.fin.bnd.go(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  +mk: K, +mv: V, +t: O.OMap<K, V>, +lo: O.OMap<K, V>, +lb: Maybe<&2, K>,
  +ub: Maybe<&2, K>, +key: K,
  eka: {Laws.above(~K, ~cmp, lb, key) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{key}) == True{} : Bool},
  +pmr: {PM(~K, ~V, ~cmp, Some{key}, ub, {(mk, mv, t) : K & V & O.OMap<K, V>}) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp,
       O.OMap.glue.fin(K, V, lo, {(mk, mv, t) : K & V & O.OMap<K, V>}), lb, ub) == True{} : Bool}:
  +ab = Bool.and(Laws.above(~K, ~cmp, Some{key}, mk), Laws.below(~K, ~cmp, ub, mk))
  +c = Laws.bounded(~K, ~V, ~cmp, t, Some{mk}, ub)
  +eab = and_l(ab, c, pmr)
  +km = and_l(Laws.above(~K, ~cmp, Some{key}, mk), Laws.below(~K, ~cmp, ub, mk), eab)
  balance.bnd(~K, ~V, ~cmp, ~trans, lb, ub, mk, mv, lo, t,
    above_trans(~K, ~cmp, ~trans, lb, key, mk, eka, km),
    and_r(Laws.above(~K, ~cmp, Some{key}, mk), Laws.below(~K, ~cmp, ub, mk), eab),
    weaken_hi(~K, ~V, ~cmp, ~trans, lo, lb, key, Some{mk}, el, km),
    and_r(ab, c, pmr))

# Workaround for https://github.com/bendlang/bend/issues/1077: bind the tuple without +.
def glue.fin.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  r: K & V & O.OMap<K, V>, +lo: O.OMap<K, V>, +lb: Maybe<&2, K>,
  +ub: Maybe<&2, K>, +key: K,
  eka: {Laws.above(~K, ~cmp, lb, key) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{key}) == True{} : Bool},
  pmr: {PM(~K, ~V, ~cmp, Some{key}, ub, r) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.glue.fin(K, V, lo, r), lb, ub) == True{} : Bool}:
  (mk, rest) = r
  (mv, t) = rest
  glue.fin.bnd.go(~K, ~V, ~cmp, ~trans, mk, mv, t, lo, lb, ub, key, eka, el, pmr)

def glue.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  hi: O.OMap<K, V>, +lo: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>,
  +key: K,
  eka: {Laws.above(~K, ~cmp, lb, key) == True{} : Bool},
  ekb: {Laws.below(~K, ~cmp, ub, key) == True{} : Bool},
  el: {Laws.bounded(~K, ~V, ~cmp, lo, lb, Some{key}) == True{} : Bool},
  eh: {Laws.bounded(~K, ~V, ~cmp, hi, Some{key}, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.glue(K, V, lo, hi), lb, ub) == True{} : Bool}:
  match hi:
    case O.OTip{}:
      weaken_hi(~K, ~V, ~cmp, ~trans, lo, lb, key, ub, el, ekb)
    case O.OBin{s, +k, +v, +hl, +hh}:
      glue.fin.bnd(~K, ~V, ~cmp, ~trans, O.OMap.pop_min(K, V, hl, k, v, hh), lo, lb, ub, key,
        eka, el, pm.bnd(~K, ~V, ~cmp, ~trans, hl, Some{key}, ub, k, v, hh, eh))

def del.bnd(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, ~trans: Trans(~K, ~cmp),
  t: O.OMap<K, V>, +lb: Maybe<&2, K>, +ub: Maybe<&2, K>, +k: K,
  +bt: {Laws.bounded(~K, ~V, ~cmp, t, lb, ub) == True{} : Bool}
) -> {Laws.bounded(~K, ~V, ~cmp, O.OMap.del(~K, ~V, ~cmp, t, k), lb, ub) == True{} : Bool}:
  match t:
    case O.OTip{}:
      {==}
    case O.OBin{+s, +key, +val, +lo, +hi}:
      +b_a = bn.a(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_b = bn.b(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_l = bn.l(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      +b_h = bn.h(~K, ~V, ~cmp, lb, ub, key, val, lo, hi, bt)
      cmp.split(O.OMap<K, V>, Bool, y => Laws.bounded(~K, ~V, ~cmp, y, lb, ub), True{},
        cmp(k, key),
        u => O.OMap.balance(K, V, key, val, O.OMap.del(~K, ~V, ~cmp, lo, k), hi),
        u => O.OMap.glue(K, V, lo, hi),
        u => O.OMap.balance(K, V, key, val, lo, O.OMap.del(~K, ~V, ~cmp, hi, k)),
        e => balance.bnd(~K, ~V, ~cmp, ~trans, lb, ub, key, val,
          O.OMap.del(~K, ~V, ~cmp, lo, k), hi, b_a, b_b,
          del.bnd(~K, ~V, ~cmp, ~trans, lo, lb, Some{key}, k, b_l), b_h),
        e => glue.bnd(~K, ~V, ~cmp, ~trans, hi, lo, lb, ub, key, b_a, b_b, b_l, b_h),
        e => balance.bnd(~K, ~V, ~cmp, ~trans, lb, ub, key, val, lo,
          O.OMap.del(~K, ~V, ~cmp, hi, k), b_a, b_b, b_l,
          del.bnd(~K, ~V, ~cmp, ~trans, hi, Some{key}, ub, k, b_h)))

def Laws.omap_del_searchtree(K, V, cmp, refl, eq, flip, trans, m, tree, k):
  del.bnd(~K, ~V, ~cmp, ~trans, m, None{}, None{}, k, tree)

def Laws.omap_new_weight_balanced(K, V):
  {==}

# --- weight balance -------------------------------------------------------------

def W(-K: Data, -V: Data, t: O.OMap<K, V>) -> Nat:
  Laws.omap_weight(K, V, t)

def WB(-K: Data, -V: Data, t: O.OMap<K, V>) -> Bool:
  Laws.weight_balanced(K, V, t)

# t is balanced and its weight is within one of n.
def PW(-K: Data, -V: Data, +n: Nat, +t: O.OMap<K, V>) -> Bool:
  Bool.and(WB(K, V, t), Ord.near(n, W(K, V, t)))

def PMW(-K: Data, -V: Data, +n: Nat, r: K & V & O.OMap<K, V>) -> Bool:
  (mk, mv, t) = r
  PW(K, V, n, t)

def pos_add(a: Nat, +b: Nat, e: Ord.LE(1n, a)) -> Ord.LE(1n, Nat.add(a, b)):
  match a:
    case 0n:
      exfalso(Ord.LE(1n, b), absurd_b(e))
    case 1n+p:
      Ord.le_zero(Nat.add(p, b))

def w_pos(-K: Data, -V: Data, t: O.OMap<K, V>) -> Ord.LE(1n, W(K, V, t)):
  match t:
    case O.OTip{}:
      {==}
    case O.OBin{s, k, v, +lo, +hi}:
      pos_add(W(K, V, lo), W(K, V, hi), w_pos(K, V, lo))

def wb.ok(
  -K: Data, -V: Data, -k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {WB(K, V, O.OBin{0, k, v, lo, hi}) == True{} : Bool}
) -> {Laws.weight_ok(W(K, V, lo), W(K, V, hi)) == True{} : Bool}:
  c3.a(Laws.weight_ok(W(K, V, lo), W(K, V, hi)), WB(K, V, lo), WB(K, V, hi), e)

def wb.l(
  -K: Data, -V: Data, -k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {WB(K, V, O.OBin{0, k, v, lo, hi}) == True{} : Bool}
) -> {WB(K, V, lo) == True{} : Bool}:
  c3.b(Laws.weight_ok(W(K, V, lo), W(K, V, hi)), WB(K, V, lo), WB(K, V, hi), e)

def wb.h(
  -K: Data, -V: Data, -k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  e: {WB(K, V, O.OBin{0, k, v, lo, hi}) == True{} : Bool}
) -> {WB(K, V, hi) == True{} : Bool}:
  c3.c(Laws.weight_ok(W(K, V, lo), W(K, V, hi)), WB(K, V, lo), WB(K, V, hi), e)

def wb.i(
  -K: Data, -V: Data, -k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  eo: {Laws.weight_ok(W(K, V, lo), W(K, V, hi)) == True{} : Bool},
  el: {WB(K, V, lo) == True{} : Bool}, eh: {WB(K, V, hi) == True{} : Bool}
) -> {WB(K, V, O.OBin{0, k, v, lo, hi}) == True{} : Bool}:
  c3.i(Laws.weight_ok(W(K, V, lo), W(K, V, hi)), WB(K, V, lo), WB(K, V, hi), eo, el, eh)

# Rotations toward lo, after hi grew or lo shrank by one.
def rls.wb(
  -K: Data, -V: Data, +k: K, +v: V, +lo: O.OMap<K, V>, +hk: K, +hv: V,
  +hl: O.OMap<K, V>, +hh: O.OMap<K, V>,
  wbl: {WB(K, V, lo) == True{} : Bool},
  +wbh: {WB(K, V, O.OBin{0, hk, hv, hl, hh}) == True{} : Bool},
  +heavy: Ord.LE(1n+Nat.mul(3n, W(K, V, lo)), Nat.add(W(K, V, hl), W(K, V, hh))),
  +alm: Ord.LE(Nat.add(W(K, V, hl), W(K, V, hh)), Nat.add(3n, Nat.mul(3n, W(K, V, lo)))),
  +hs: Ord.LE(1n+W(K, V, hl), Nat.mul(2n, W(K, V, hh)))
) -> {WB(K, V, O.OMap.bin(K, V, hk, hv, O.OMap.bin(K, V, k, v, lo, hl), hh)) == True{} : Bool}:
  +l = W(K, V, lo)
  +a = W(K, V, hl)
  +b = W(K, V, hh)
  +okh = wb.ok(K, V, hk, hv, hl, hh, wbh)
  +h1 = Ord.wok_r(a, b, okh)
  +h2 = Ord.wok_l(a, b, okh)
  +pl = w_pos(K, V, lo)
  +pa = w_pos(K, V, hl)
  +pb = w_pos(K, V, hh)
  wb.i(K, V, hk, hv, O.OMap.bin(K, V, k, v, lo, hl), hh,
    Ord.rls.w1(l, a, b, h1, h2, heavy, alm, hs, pl, pa, pb),
    wb.i(K, V, k, v, lo, hl, Ord.rls.w0(l, a, b, h1, h2, heavy, alm, hs, pl, pa, pb), wbl,
      wb.l(K, V, hk, hv, hl, hh, wbh)),
    wb.h(K, V, hk, hv, hl, hh, wbh))

def rld.wb(
  -K: Data, -V: Data, hl: O.OMap<K, V>, +k: K, +v: V, +lo: O.OMap<K, V>, +hk: K, +hv: V,
  +hh: O.OMap<K, V>,
  wbl: {WB(K, V, lo) == True{} : Bool},
  +wbh: {WB(K, V, O.OBin{0, hk, hv, hl, hh}) == True{} : Bool},
  +heavy: Ord.LE(1n+Nat.mul(3n, W(K, V, lo)), Nat.add(W(K, V, hl), W(K, V, hh))),
  +alm: Ord.LE(Nat.add(W(K, V, hl), W(K, V, hh)), Nat.add(3n, Nat.mul(3n, W(K, V, lo)))),
  +hd: Ord.LE(Nat.mul(2n, W(K, V, hh)), W(K, V, hl))
) -> {WB(K, V, O.OMap.rot_lo.double(K, V, k, v, lo, hk, hv, hl, hh)) == True{} : Bool}:
  match hl:
    case O.OTip{}:
      exfalso({WB(K, V, O.OMap.rot_lo.double(K, V, k, v, lo, hk, hv, O.OTip{}, hh)) == True{} : Bool},
        Ord.dtip(W(K, V, hh), hd, w_pos(K, V, hh)))
    case O.OBin{s, +mk, +mv, +ml, +mh}:
      +hl = {O.OBin{0, mk, mv, ml, mh} : O.OMap<K, V>}
      +l = W(K, V, lo)
      +x = W(K, V, ml)
      +y = W(K, V, mh)
      +b = W(K, V, hh)
      +okh = wb.ok(K, V, hk, hv, hl, hh, wbh)
      +h1 = Ord.wok_r(Nat.add(x, y), b, okh)
      +h2 = Ord.wok_l(Nat.add(x, y), b, okh)
      +wbm = wb.l(K, V, hk, hv, hl, hh, wbh)
      +okm = wb.ok(K, V, mk, mv, ml, mh, wbm)
      +h5 = Ord.wok_r(x, y, okm)
      +h6 = Ord.wok_l(x, y, okm)
      +pl = w_pos(K, V, lo)
      +px = w_pos(K, V, ml)
      +py = w_pos(K, V, mh)
      +pb = w_pos(K, V, hh)
      wb.i(K, V, mk, mv, O.OMap.bin(K, V, k, v, lo, ml), O.OMap.bin(K, V, hk, hv, mh, hh),
        Ord.rld.w0(l, x, y, b, h1, h2, heavy, alm, hd, h5, h6, pl, px, py, pb),
        wb.i(K, V, k, v, lo, ml, Ord.rld.w1(l, x, y, b, h1, h2, heavy, alm, hd, h5, h6, pl, px, py, pb),
          wbl, wb.l(K, V, mk, mv, ml, mh, wbm)),
        wb.i(K, V, hk, hv, mh, hh, Ord.rld.w2(l, x, y, b, h1, h2, heavy, alm, hd, h5, h6, pl, px, py, pb),
          wb.h(K, V, mk, mv, ml, mh, wbm), wb.h(K, V, hk, hv, hl, hh, wbh)))

def rlp.wb(
  -K: Data, -V: Data, single: Bool, +k: K, +v: V, +lo: O.OMap<K, V>, +hk: K, +hv: V,
  +hl: O.OMap<K, V>, +hh: O.OMap<K, V>,
  es: {Nat.is_lt(W(K, V, hl), Nat.mul(2n, W(K, V, hh))) == single : Bool},
  wbl: {WB(K, V, lo) == True{} : Bool},
  wbh: {WB(K, V, O.OBin{0, hk, hv, hl, hh}) == True{} : Bool},
  heavy: Ord.LE(1n+Nat.mul(3n, W(K, V, lo)), Nat.add(W(K, V, hl), W(K, V, hh))),
  alm: Ord.LE(Nat.add(W(K, V, hl), W(K, V, hh)), Nat.add(3n, Nat.mul(3n, W(K, V, lo))))
) -> {WB(K, V, O.OMap.rot_lo.pick(K, V, single, k, v, lo, hk, hv, hl, hh)) == True{} : Bool}:
  match single:
    case True{}:
      rls.wb(K, V, k, v, lo, hk, hv, hl, hh, wbl, wbh, heavy, alm,
        Ord.lt_le(W(K, V, hl), Nat.mul(2n, W(K, V, hh)), es))
    case False{}:
      rld.wb(K, V, hl, k, v, lo, hk, hv, hh, wbl, wbh, heavy, alm,
        Ord.nlt_le(W(K, V, hl), Nat.mul(2n, W(K, V, hh)), es))

def rl.wb(
  -K: Data, -V: Data, hi: O.OMap<K, V>, +k: K, +v: V, +lo: O.OMap<K, V>,
  wbl: {WB(K, V, lo) == True{} : Bool}, +wbh: {WB(K, V, hi) == True{} : Bool},
  heavy: Ord.LE(1n+Nat.mul(3n, W(K, V, lo)), W(K, V, hi)),
  alm: Ord.LE(W(K, V, hi), Nat.add(3n, Nat.mul(3n, W(K, V, lo))))
) -> {WB(K, V, Laws.g_rot_lo(K, V, k, v, lo, hi)) == True{} : Bool}:
  match hi:
    case O.OTip{}:
      exfalso({WB(K, V, Laws.g_rot_lo(K, V, k, v, lo, O.OTip{})) == True{} : Bool},
        Ord.tiph(W(K, V, lo), heavy, w_pos(K, V, lo)))
    case O.OBin{s, +hk, +hv, +hl, +hh}:
      rlp.wb(K, V, Nat.is_lt(W(K, V, hl), Nat.mul(2n, W(K, V, hh))), k, v, lo, hk, hv, hl, hh,
        {==}, wbl, wbh, heavy, alm)

# Rotations toward hi, after lo grew or hi shrank by one.
def rhs.wb(
  -K: Data, -V: Data, +k: K, +v: V, +lk: K, +lv: V, +ll: O.OMap<K, V>,
  +lh: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +wbl: {WB(K, V, O.OBin{0, lk, lv, ll, lh}) == True{} : Bool},
  wbh: {WB(K, V, hi) == True{} : Bool},
  +heavy: Ord.LE(1n+Nat.mul(3n, W(K, V, hi)), Nat.add(W(K, V, ll), W(K, V, lh))),
  +alm: Ord.LE(Nat.add(W(K, V, ll), W(K, V, lh)), Nat.add(3n, Nat.mul(3n, W(K, V, hi)))),
  +hs: Ord.LE(1n+W(K, V, lh), Nat.mul(2n, W(K, V, ll)))
) -> {WB(K, V, O.OMap.bin(K, V, lk, lv, ll, O.OMap.bin(K, V, k, v, lh, hi))) == True{} : Bool}:
  +l = W(K, V, hi)
  +a = W(K, V, lh)
  +b = W(K, V, ll)
  +okl = wb.ok(K, V, lk, lv, ll, lh, wbl)
  +h1 = Ord.wok_l(b, a, okl)
  +h2 = Ord.wok_r(b, a, okl)
  +pl = w_pos(K, V, hi)
  +pa = w_pos(K, V, lh)
  +pb = w_pos(K, V, ll)
  wb.i(K, V, lk, lv, ll, O.OMap.bin(K, V, k, v, lh, hi),
    Ord.rhs.w0(l, a, b, h1, h2, heavy, alm, hs, pl, pa, pb),
    wb.l(K, V, lk, lv, ll, lh, wbl),
    wb.i(K, V, k, v, lh, hi, Ord.rhs.w1(l, a, b, h1, h2, heavy, alm, hs, pl, pa, pb),
      wb.h(K, V, lk, lv, ll, lh, wbl), wbh))

def rhd.wb(
  -K: Data, -V: Data, lh: O.OMap<K, V>, +k: K, +v: V, +lk: K, +lv: V,
  +ll: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +wbl: {WB(K, V, O.OBin{0, lk, lv, ll, lh}) == True{} : Bool},
  wbh: {WB(K, V, hi) == True{} : Bool},
  +heavy: Ord.LE(1n+Nat.mul(3n, W(K, V, hi)), Nat.add(W(K, V, ll), W(K, V, lh))),
  +alm: Ord.LE(Nat.add(W(K, V, ll), W(K, V, lh)), Nat.add(3n, Nat.mul(3n, W(K, V, hi)))),
  +hd: Ord.LE(Nat.mul(2n, W(K, V, ll)), W(K, V, lh))
) -> {WB(K, V, O.OMap.rot_hi.double(K, V, k, v, lk, lv, ll, lh, hi)) == True{} : Bool}:
  match lh:
    case O.OTip{}:
      exfalso({WB(K, V, O.OMap.rot_hi.double(K, V, k, v, lk, lv, ll, O.OTip{}, hi)) == True{} : Bool},
        Ord.dtip(W(K, V, ll), hd, w_pos(K, V, ll)))
    case O.OBin{s, +mk, +mv, +ml, +mh}:
      +lh = {O.OBin{0, mk, mv, ml, mh} : O.OMap<K, V>}
      +l = W(K, V, hi)
      +x = W(K, V, mh)
      +y = W(K, V, ml)
      +b = W(K, V, ll)
      +okl = wb.ok(K, V, lk, lv, ll, lh, wbl)
      +h1 = Ord.wok_l(b, Nat.add(y, x), okl)
      +h2 = Ord.wok_r(b, Nat.add(y, x), okl)
      +wbm = wb.h(K, V, lk, lv, ll, lh, wbl)
      +okm = wb.ok(K, V, mk, mv, ml, mh, wbm)
      +h5 = Ord.wok_l(y, x, okm)
      +h6 = Ord.wok_r(y, x, okm)
      +pl = w_pos(K, V, hi)
      +px = w_pos(K, V, mh)
      +py = w_pos(K, V, ml)
      +pb = w_pos(K, V, ll)
      wb.i(K, V, mk, mv, O.OMap.bin(K, V, lk, lv, ll, ml), O.OMap.bin(K, V, k, v, mh, hi),
        Ord.rhd.w0(l, x, y, b, h1, h2, heavy, alm, hd, h5, h6, pl, px, py, pb),
        wb.i(K, V, lk, lv, ll, ml, Ord.rhd.w1(l, x, y, b, h1, h2, heavy, alm, hd, h5, h6, pl, px, py, pb),
          wb.l(K, V, lk, lv, ll, lh, wbl), wb.l(K, V, mk, mv, ml, mh, wbm)),
        wb.i(K, V, k, v, mh, hi, Ord.rhd.w2(l, x, y, b, h1, h2, heavy, alm, hd, h5, h6, pl, px, py, pb),
          wb.h(K, V, mk, mv, ml, mh, wbm), wbh))

def rhp.wb(
  -K: Data, -V: Data, single: Bool, +k: K, +v: V, +lk: K, +lv: V, +ll: O.OMap<K, V>,
  +lh: O.OMap<K, V>, +hi: O.OMap<K, V>,
  es: {Nat.is_lt(W(K, V, lh), Nat.mul(2n, W(K, V, ll))) == single : Bool},
  wbl: {WB(K, V, O.OBin{0, lk, lv, ll, lh}) == True{} : Bool},
  wbh: {WB(K, V, hi) == True{} : Bool},
  heavy: Ord.LE(1n+Nat.mul(3n, W(K, V, hi)), Nat.add(W(K, V, ll), W(K, V, lh))),
  alm: Ord.LE(Nat.add(W(K, V, ll), W(K, V, lh)), Nat.add(3n, Nat.mul(3n, W(K, V, hi))))
) -> {WB(K, V, O.OMap.rot_hi.pick(K, V, single, k, v, lk, lv, ll, lh, hi)) == True{} : Bool}:
  match single:
    case True{}:
      rhs.wb(K, V, k, v, lk, lv, ll, lh, hi, wbl, wbh, heavy, alm,
        Ord.lt_le(W(K, V, lh), Nat.mul(2n, W(K, V, ll)), es))
    case False{}:
      rhd.wb(K, V, lh, k, v, lk, lv, ll, hi, wbl, wbh, heavy, alm,
        Ord.nlt_le(W(K, V, lh), Nat.mul(2n, W(K, V, ll)), es))

def rh.wb(
  -K: Data, -V: Data, lo: O.OMap<K, V>, +k: K, +v: V, +hi: O.OMap<K, V>,
  +wbl: {WB(K, V, lo) == True{} : Bool}, wbh: {WB(K, V, hi) == True{} : Bool},
  heavy: Ord.LE(1n+Nat.mul(3n, W(K, V, hi)), W(K, V, lo)),
  alm: Ord.LE(W(K, V, lo), Nat.add(3n, Nat.mul(3n, W(K, V, hi))))
) -> {WB(K, V, Laws.g_rot_hi(K, V, k, v, lo, hi)) == True{} : Bool}:
  match lo:
    case O.OTip{}:
      exfalso({WB(K, V, Laws.g_rot_hi(K, V, k, v, O.OTip{}, hi)) == True{} : Bool},
        Ord.tiph(W(K, V, hi), heavy, w_pos(K, V, hi)))
    case O.OBin{s, +lk, +lv, +ll, +lh}:
      rhp.wb(K, V, Nat.is_lt(W(K, V, lh), Nat.mul(2n, W(K, V, ll))), k, v, lk, lv, ll, lh, hi,
        {==}, wbl, wbh, heavy, alm)

def bif.wb(
  -K: Data, -V: Data, heavy_hi: Bool, heavy_lo: Bool, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  eh: {Laws.g_heavy_hi(K, V, lo, hi) == heavy_hi : Bool},
  el: {Laws.g_heavy_lo(K, V, lo, hi) == heavy_lo : Bool},
  wbl: {WB(K, V, lo) == True{} : Bool}, wbh: {WB(K, V, hi) == True{} : Bool},
  +alm: {Ord.alm(W(K, V, lo), W(K, V, hi)) == True{} : Bool}
) -> {WB(K, V, Laws.g_balance.if(K, V, heavy_hi, heavy_lo, k, v, lo, hi)) == True{} : Bool}:
  match heavy_hi heavy_lo:
    case True{} _:
      rl.wb(K, V, hi, k, v, lo, wbl, wbh,
        Ord.gt_le(W(K, V, hi), Nat.mul(3n, W(K, V, lo)), eh), and_l(Nat.is_le(W(K, V, hi), Nat.add(3n, Nat.mul(3n, W(K, V, lo)))),
          Nat.is_le(W(K, V, lo), Nat.add(3n, Nat.mul(3n, W(K, V, hi)))), alm))
    case False{} True{}:
      rh.wb(K, V, lo, k, v, hi, wbl, wbh,
        Ord.gt_le(W(K, V, lo), Nat.mul(3n, W(K, V, hi)), el), and_r(Nat.is_le(W(K, V, hi), Nat.add(3n, Nat.mul(3n, W(K, V, lo)))),
          Nat.is_le(W(K, V, lo), Nat.add(3n, Nat.mul(3n, W(K, V, hi)))), alm))
    case False{} False{}:
      wb.i(K, V, k, v, lo, hi,
        and_i(Nat.is_le(W(K, V, hi), Nat.mul(3n, W(K, V, lo))),
          Nat.is_le(W(K, V, lo), Nat.mul(3n, W(K, V, hi))),
          Ord.ngt_le(W(K, V, hi), Nat.mul(3n, W(K, V, lo)), eh),
          Ord.ngt_le(W(K, V, lo), Nat.mul(3n, W(K, V, hi)), el)),
        wbl, wbh)

def bal.wb(
  -K: Data, -V: Data, +k: K, +v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  wbl: {WB(K, V, lo) == True{} : Bool}, wbh: {WB(K, V, hi) == True{} : Bool},
  alm: {Ord.alm(W(K, V, lo), W(K, V, hi)) == True{} : Bool}
) -> {WB(K, V, Laws.g_balance(K, V, k, v, lo, hi)) == True{} : Bool}:
  bif.wb(K, V, Laws.g_heavy_hi(K, V, lo, hi), Laws.g_heavy_lo(K, V, lo, hi), k, v, lo, hi,
    {==}, {==}, wbl, wbh, alm)

# Balancing keeps the weight.
def rlp.w(
  -K: Data, -V: Data, single: Bool, -k: K, -v: V, +lo: O.OMap<K, V>, -hk: K, -hv: V,
  hl: O.OMap<K, V>, +hh: O.OMap<K, V>
) -> {Nat.add(W(K, V, lo), Nat.add(W(K, V, hl), W(K, V, hh)))
      == W(K, V, O.OMap.rot_lo.pick(K, V, single, k, v, lo, hk, hv, hl, hh)) : Nat}:
  match single hl:
    case True{} +hl:
      Ord.sy(Nat.add(Nat.add(W(K, V, lo), W(K, V, hl)), W(K, V, hh)),
        Nat.add(W(K, V, lo), Nat.add(W(K, V, hl), W(K, V, hh))),
        Ord.add_assoc(W(K, V, lo), W(K, V, hl), W(K, V, hh)))
    case False{} O.OTip{}:
      Ord.sy(Nat.add(Nat.add(W(K, V, lo), 1n), W(K, V, hh)), Nat.add(W(K, V, lo), Nat.add(1n, W(K, V, hh))),
        Ord.add_assoc(W(K, V, lo), 1n, W(K, V, hh)))
    case False{} O.OBin{s, mk, mv, +ml, +mh}:
      +l = W(K, V, lo)
      +x = W(K, V, ml)
      +y = W(K, V, mh)
      +b = W(K, V, hh)
      Ord.tr(Nat.add(l, Nat.add(Nat.add(x, y), b)), Nat.add(l, Nat.add(x, Nat.add(y, b))),
        Nat.add(Nat.add(l, x), Nat.add(y, b)),
        Ord.cong_add(l, l, Nat.add(Nat.add(x, y), b), Nat.add(x, Nat.add(y, b)), {==}, Ord.add_assoc(x, y, b)),
        Ord.sy(Nat.add(Nat.add(l, x), Nat.add(y, b)), Nat.add(l, Nat.add(x, Nat.add(y, b))),
          Ord.add_assoc(l, x, Nat.add(y, b))))

def rhp.w(
  -K: Data, -V: Data, single: Bool, -k: K, -v: V, -lk: K, -lv: V, +ll: O.OMap<K, V>,
  lh: O.OMap<K, V>, +hi: O.OMap<K, V>
) -> {Nat.add(Nat.add(W(K, V, ll), W(K, V, lh)), W(K, V, hi))
      == W(K, V, O.OMap.rot_hi.pick(K, V, single, k, v, lk, lv, ll, lh, hi)) : Nat}:
  match single lh:
    case True{} +lh:
      Ord.add_assoc(W(K, V, ll), W(K, V, lh), W(K, V, hi))
    case False{} O.OTip{}:
      Ord.add_assoc(W(K, V, ll), 1n, W(K, V, hi))
    case False{} O.OBin{s, mk, mv, +ml, +mh}:
      +l = W(K, V, hi)
      +x = W(K, V, mh)
      +y = W(K, V, ml)
      +b = W(K, V, ll)
      Ord.tr(Nat.add(Nat.add(b, Nat.add(y, x)), l), Nat.add(Nat.add(Nat.add(b, y), x), l),
        Nat.add(Nat.add(b, y), Nat.add(x, l)),
        Ord.cong_add(Nat.add(b, Nat.add(y, x)), Nat.add(Nat.add(b, y), x), l, l,
          Ord.sy(Nat.add(Nat.add(b, y), x), Nat.add(b, Nat.add(y, x)), Ord.add_assoc(b, y, x)), {==}),
        Ord.add_assoc(Nat.add(b, y), x, l))

def rl.w(-K: Data, -V: Data, hi: O.OMap<K, V>, -k: K, -v: V, +lo: O.OMap<K, V>)
  -> {Nat.add(W(K, V, lo), W(K, V, hi)) == W(K, V, Laws.g_rot_lo(K, V, k, v, lo, hi)) : Nat}:
  match hi:
    case O.OTip{}:
      {==}
    case O.OBin{s, hk, hv, +hl, +hh}:
      rlp.w(K, V, Nat.is_lt(W(K, V, hl), Nat.mul(2n, W(K, V, hh))), k, v, lo, hk, hv, hl, hh)

def rh.w(-K: Data, -V: Data, lo: O.OMap<K, V>, -k: K, -v: V, +hi: O.OMap<K, V>)
  -> {Nat.add(W(K, V, lo), W(K, V, hi)) == W(K, V, Laws.g_rot_hi(K, V, k, v, lo, hi)) : Nat}:
  match lo:
    case O.OTip{}:
      {==}
    case O.OBin{s, lk, lv, +ll, +lh}:
      rhp.w(K, V, Nat.is_lt(W(K, V, lh), Nat.mul(2n, W(K, V, ll))), k, v, lk, lv, ll, lh, hi)

def bif.w(
  -K: Data, -V: Data, heavy_hi: Bool, heavy_lo: Bool, -k: K, -v: V,
  +lo: O.OMap<K, V>, +hi: O.OMap<K, V>
) -> {Nat.add(W(K, V, lo), W(K, V, hi))
      == W(K, V, Laws.g_balance.if(K, V, heavy_hi, heavy_lo, k, v, lo, hi)) : Nat}:
  match heavy_hi heavy_lo:
    case True{} _:
      rl.w(K, V, hi, k, v, lo)
    case False{} True{}:
      rh.w(K, V, lo, k, v, hi)
    case False{} False{}:
      {==}

def bal.w(-K: Data, -V: Data, -k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>)
  -> {Nat.add(W(K, V, lo), W(K, V, hi)) == W(K, V, Laws.g_balance(K, V, k, v, lo, hi)) : Nat}:
  bif.w(K, V, Laws.g_heavy_hi(K, V, lo, hi), Laws.g_heavy_lo(K, V, lo, hi), k, v, lo, hi)

def bal.lo.near(
  -K: Data, -V: Data, -k: K, -v: V, +lo: O.OMap<K, V>, +lo2: O.OMap<K, V>, +hi: O.OMap<K, V>,
  n1: Ord.LE(W(K, V, lo), 1n+W(K, V, lo2)), n2: Ord.LE(W(K, V, lo2), 1n+W(K, V, lo))
) -> {Ord.near(Nat.add(W(K, V, lo), W(K, V, hi)), W(K, V, Laws.g_balance(K, V, k, v, lo2, hi))) == True{} : Bool}:
  %bal.w(K, V, k, v, lo2, hi) : {Ord.near(Nat.add(W(K, V, lo), W(K, V, hi)), _) == True{} : Bool}
  Ord.nearlo.w0(W(K, V, lo), W(K, V, lo2), W(K, V, hi), n1, n2)

def bal.hi.near(
  -K: Data, -V: Data, -k: K, -v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>, +hi2: O.OMap<K, V>,
  n1: Ord.LE(W(K, V, hi), 1n+W(K, V, hi2)), n2: Ord.LE(W(K, V, hi2), 1n+W(K, V, hi))
) -> {Ord.near(Nat.add(W(K, V, lo), W(K, V, hi)), W(K, V, Laws.g_balance(K, V, k, v, lo, hi2))) == True{} : Bool}:
  %bal.w(K, V, k, v, lo, hi2) : {Ord.near(Nat.add(W(K, V, lo), W(K, V, hi)), _) == True{} : Bool}
  Ord.nearhi.w0(W(K, V, lo), W(K, V, hi), W(K, V, hi2), n1, n2)

# lo became lo2, one lighter or heavier at most: rebalance the node.
def bal.lo(
  -K: Data, -V: Data, +k: K, +v: V, +lo: O.OMap<K, V>, +lo2: O.OMap<K, V>, +hi: O.OMap<K, V>,
  +ok: {Laws.weight_ok(W(K, V, lo), W(K, V, hi)) == True{} : Bool},
  wbh: {WB(K, V, hi) == True{} : Bool},
  +pw: {PW(K, V, W(K, V, lo), lo2) == True{} : Bool}
) -> {PW(K, V, Nat.add(W(K, V, lo), W(K, V, hi)), Laws.g_balance(K, V, k, v, lo2, hi)) == True{} : Bool}:
  +a = W(K, V, lo)
  +a2 = W(K, V, lo2)
  +c = W(K, V, hi)
  +nr = and_r(WB(K, V, lo2), Ord.near(a, a2), pw)
  +n1 = and_l(Nat.is_le(a, 1n+a2), Nat.is_le(a2, 1n+a), nr)
  +n2 = and_r(Nat.is_le(a, 1n+a2), Nat.is_le(a2, 1n+a), nr)
  and_i(WB(K, V, Laws.g_balance(K, V, k, v, lo2, hi)),
    Ord.near(Nat.add(a, c), W(K, V, Laws.g_balance(K, V, k, v, lo2, hi))),
    bal.wb(K, V, k, v, lo2, hi, and_l(WB(K, V, lo2), Ord.near(a, a2), pw), wbh,
      Ord.almlo.w0(a, c, a2, Ord.wok_l(a, c, ok), Ord.wok_r(a, c, ok), n1, n2)),
    bal.lo.near(K, V, k, v, lo, lo2, hi, n1, n2))

def bal.hi(
  -K: Data, -V: Data, +k: K, +v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>, +hi2: O.OMap<K, V>,
  +ok: {Laws.weight_ok(W(K, V, lo), W(K, V, hi)) == True{} : Bool},
  wbl: {WB(K, V, lo) == True{} : Bool},
  +pw: {PW(K, V, W(K, V, hi), hi2) == True{} : Bool}
) -> {PW(K, V, Nat.add(W(K, V, lo), W(K, V, hi)), Laws.g_balance(K, V, k, v, lo, hi2)) == True{} : Bool}:
  +a = W(K, V, lo)
  +c = W(K, V, hi)
  +c2 = W(K, V, hi2)
  +nr = and_r(WB(K, V, hi2), Ord.near(c, c2), pw)
  +n1 = and_l(Nat.is_le(c, 1n+c2), Nat.is_le(c2, 1n+c), nr)
  +n2 = and_r(Nat.is_le(c, 1n+c2), Nat.is_le(c2, 1n+c), nr)
  and_i(WB(K, V, Laws.g_balance(K, V, k, v, lo, hi2)),
    Ord.near(Nat.add(a, c), W(K, V, Laws.g_balance(K, V, k, v, lo, hi2))),
    bal.wb(K, V, k, v, lo, hi2, wbl, and_l(WB(K, V, hi2), Ord.near(c, c2), pw),
      Ord.almhi.w0(a, c, c2, Ord.wok_l(a, c, ok), Ord.wok_r(a, c, ok), n1, n2)),
    bal.hi.near(K, V, k, v, lo, hi, hi2, n1, n2))

def put.wb(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, t: O.OMap<K, V>, +k: K, +v: V,
  +wb: {WB(K, V, t) == True{} : Bool}
) -> {PW(K, V, W(K, V, t), Laws.g_put(~K, ~V, ~cmp, t, k, v)) == True{} : Bool}:
  match t:
    case O.OTip{}:
      {==}
    case O.OBin{+s, +key, +val, +lo, +hi}:
      +ok = wb.ok(K, V, key, val, lo, hi, wb)
      +wbl = wb.l(K, V, key, val, lo, hi, wb)
      +wbh = wb.h(K, V, key, val, lo, hi, wb)
      +n = Nat.add(W(K, V, lo), W(K, V, hi))
      cmp.split(O.OMap<K, V>, Bool, x => PW(K, V, n, x), True{}, cmp(k, key),
        u => Laws.g_balance(K, V, key, val, Laws.g_put(~K, ~V, ~cmp, lo, k, v), hi),
        u => O.OBin{s, key, v, lo, hi},
        u => Laws.g_balance(K, V, key, val, lo, Laws.g_put(~K, ~V, ~cmp, hi, k, v)),
        e => bal.lo(K, V, key, val, lo, Laws.g_put(~K, ~V, ~cmp, lo, k, v), hi, ok, wbh,
          put.wb(~K, ~V, ~cmp, lo, k, v, wbl)),
        e => and_i(WB(K, V, O.OBin{s, key, v, lo, hi}), Ord.near(n, n), wb, Ord.nearrf.w0(n)),
        e => bal.hi(K, V, key, val, lo, hi, Laws.g_put(~K, ~V, ~cmp, hi, k, v), ok, wbl,
          put.wb(~K, ~V, ~cmp, hi, k, v, wbh)))

def Laws.omap_put_weight_balanced(K, V, cmp, m, wb, k, v):
  and_l(WB(K, V, Laws.g_put(~K, ~V, ~cmp, m, k, v)),
    Ord.near(W(K, V, m), W(K, V, Laws.g_put(~K, ~V, ~cmp, m, k, v))),
    put.wb(~K, ~V, ~cmp, m, k, v, wb))

def pm.fin.wb.go(
  -K: Data, -V: Data, +mk: K, +mv: V, +t: O.OMap<K, V>, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  ok: {Laws.weight_ok(W(K, V, lo), W(K, V, hi)) == True{} : Bool},
  wbh: {WB(K, V, hi) == True{} : Bool},
  ih: {PMW(K, V, W(K, V, lo), {(mk, mv, t) : K & V & O.OMap<K, V>}) == True{} : Bool}
) -> {PMW(K, V, Nat.add(W(K, V, lo), W(K, V, hi)),
       Laws.g_pop_min.fin(K, V, k, v, hi, {(mk, mv, t) : K & V & O.OMap<K, V>})) == True{} : Bool}:
  bal.lo(K, V, k, v, lo, t, hi, ok, wbh, ih)

# Workaround for https://github.com/bendlang/bend/issues/1077: bind the tuple without +.
def pm.fin.wb(
  -K: Data, -V: Data, r: K & V & O.OMap<K, V>, +k: K, +v: V,
  +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  ok: {Laws.weight_ok(W(K, V, lo), W(K, V, hi)) == True{} : Bool},
  wbh: {WB(K, V, hi) == True{} : Bool},
  ih: {PMW(K, V, W(K, V, lo), r) == True{} : Bool}
) -> {PMW(K, V, Nat.add(W(K, V, lo), W(K, V, hi)), Laws.g_pop_min.fin(K, V, k, v, hi, r)) == True{} : Bool}:
  (mk, rest) = r
  (mv, t) = rest
  pm.fin.wb.go(K, V, mk, mv, t, k, v, lo, hi, ok, wbh, ih)

def pm.wb(
  -K: Data, -V: Data, lo: O.OMap<K, V>, +k: K, +v: V, +hi: O.OMap<K, V>,
  +e: {WB(K, V, O.OBin{0, k, v, lo, hi}) == True{} : Bool}
) -> {PMW(K, V, Nat.add(W(K, V, lo), W(K, V, hi)), Laws.g_pop_min(K, V, lo, k, v, hi)) == True{} : Bool}:
  match lo:
    case O.OTip{}:
      and_i(WB(K, V, hi), Ord.near(1n+W(K, V, hi), W(K, V, hi)),
        wb.h(K, V, k, v, O.OTip{}, hi, e), Ord.nearpm.w0(W(K, V, hi)))
    case O.OBin{s, +lk, +lv, +ll, +lh}:
      +lo = {O.OBin{0, lk, lv, ll, lh} : O.OMap<K, V>}
      pm.fin.wb(K, V, Laws.g_pop_min(K, V, ll, lk, lv, lh), k, v, lo, hi,
        wb.ok(K, V, k, v, lo, hi, e), wb.h(K, V, k, v, lo, hi, e),
        pm.wb(K, V, ll, lk, lv, lh, wb.l(K, V, k, v, lo, hi, e)))

def glue.fin.wb.go(
  -K: Data, -V: Data, +mk: K, +mv: V, +t: O.OMap<K, V>, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  ok: {Laws.weight_ok(W(K, V, lo), W(K, V, hi)) == True{} : Bool},
  wbl: {WB(K, V, lo) == True{} : Bool},
  pmr: {PMW(K, V, W(K, V, hi), {(mk, mv, t) : K & V & O.OMap<K, V>}) == True{} : Bool}
) -> {PW(K, V, Nat.add(W(K, V, lo), W(K, V, hi)),
       Laws.g_glue.fin(K, V, lo, {(mk, mv, t) : K & V & O.OMap<K, V>})) == True{} : Bool}:
  bal.hi(K, V, mk, mv, lo, hi, t, ok, wbl, pmr)

# Workaround for https://github.com/bendlang/bend/issues/1077: bind the tuple without +.
def glue.fin.wb(
  -K: Data, -V: Data, r: K & V & O.OMap<K, V>, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>,
  ok: {Laws.weight_ok(W(K, V, lo), W(K, V, hi)) == True{} : Bool},
  wbl: {WB(K, V, lo) == True{} : Bool},
  pmr: {PMW(K, V, W(K, V, hi), r) == True{} : Bool}
) -> {PW(K, V, Nat.add(W(K, V, lo), W(K, V, hi)), Laws.g_glue.fin(K, V, lo, r)) == True{} : Bool}:
  (mk, rest) = r
  (mv, t) = rest
  glue.fin.wb.go(K, V, mk, mv, t, lo, hi, ok, wbl, pmr)

def glue.wb(
  -K: Data, -V: Data, hi: O.OMap<K, V>, +lo: O.OMap<K, V>, -key: K, -val: V,
  +e: {WB(K, V, O.OBin{0, key, val, lo, hi}) == True{} : Bool}
) -> {PW(K, V, Nat.add(W(K, V, lo), W(K, V, hi)), Laws.g_glue(K, V, lo, hi)) == True{} : Bool}:
  match hi:
    case O.OTip{}:
      and_i(WB(K, V, lo), Ord.near(Nat.add(W(K, V, lo), 1n), W(K, V, lo)),
        wb.l(K, V, key, val, lo, O.OTip{}, e), Ord.neargt.w0(W(K, V, lo)))
    case O.OBin{s, +k, +v, +hl, +hh}:
      +hi = {O.OBin{0, k, v, hl, hh} : O.OMap<K, V>}
      glue.fin.wb(K, V, Laws.g_pop_min(K, V, hl, k, v, hh), lo, hi,
        wb.ok(K, V, key, val, lo, hi, e), wb.l(K, V, key, val, lo, hi, e),
        pm.wb(K, V, hl, k, v, hh, wb.h(K, V, key, val, lo, hi, e)))

def del.wb(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, t: O.OMap<K, V>, +k: K,
  +wb: {WB(K, V, t) == True{} : Bool}
) -> {PW(K, V, W(K, V, t), Laws.g_del(~K, ~V, ~cmp, t, k)) == True{} : Bool}:
  match t:
    case O.OTip{}:
      {==}
    case O.OBin{+s, +key, +val, +lo, +hi}:
      +ok = wb.ok(K, V, key, val, lo, hi, wb)
      +wbl = wb.l(K, V, key, val, lo, hi, wb)
      +wbh = wb.h(K, V, key, val, lo, hi, wb)
      +n = Nat.add(W(K, V, lo), W(K, V, hi))
      cmp.split(O.OMap<K, V>, Bool, x => PW(K, V, n, x), True{}, cmp(k, key),
        u => Laws.g_balance(K, V, key, val, Laws.g_del(~K, ~V, ~cmp, lo, k), hi),
        u => Laws.g_glue(K, V, lo, hi),
        u => Laws.g_balance(K, V, key, val, lo, Laws.g_del(~K, ~V, ~cmp, hi, k)),
        e => bal.lo(K, V, key, val, lo, Laws.g_del(~K, ~V, ~cmp, lo, k), hi, ok, wbh,
          del.wb(~K, ~V, ~cmp, lo, k, wbl)),
        e => glue.wb(K, V, hi, lo, key, val, wb),
        e => bal.hi(K, V, key, val, lo, hi, Laws.g_del(~K, ~V, ~cmp, hi, k), ok, wbl,
          del.wb(~K, ~V, ~cmp, hi, k, wbh)))

def Laws.omap_del_weight_balanced(K, V, cmp, m, wb, k):
  and_l(WB(K, V, Laws.g_del(~K, ~V, ~cmp, m, k)),
    Ord.near(W(K, V, m), W(K, V, Laws.g_del(~K, ~V, ~cmp, m, k))),
    del.wb(~K, ~V, ~cmp, m, k, wb))

def Laws.omap_g_put_matches():
  {==}

def Laws.omap_g_del_matches():
  {==}

def Laws.hmap_get_put():
  {==}

def Laws.hmap_get_put_other():
  {==}

def Laws.hmap_collision():
  {==}

def Laws.hmap_replace_collision():
  {==}

def Laws.hmap_high_bit():
  {==}

def Laws.hmap_missing_collision():
  {==}
