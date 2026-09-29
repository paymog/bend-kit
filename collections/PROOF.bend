import Base
import ./LAWS.bend as Laws
import ./omap.bend as O
import ./hmap.bend as M
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

# --- hmap ------------------------------------------------------------------------

def h.sb(-a: Bool, -b: Bool, e: {a == b : Bool}) -> {b == a : Bool}:
  Equal.sym(Bool, a, b, e)

def h.tf(-A: Type, -b: Bool, et: {b == True{} : Bool}, ef: {b == False{} : Bool}) -> A:
  exfalso(A, absurd_b(Equal.trans(Bool, False{}, b, True{}, Equal.sym(Bool, b, False{}, ef), et)))

def h.not_t(b: Bool, e: {Bool.not(b) == True{} : Bool}) -> {b == False{} : Bool}:
  match b:
    case True{}:
      exfalso({True{} == False{} : Bool}, absurd_b(e))
    case False{}:
      {==}

def h.isS(-V: Data, m: Maybe<&2, V>) -> Type:
  match m:
    case None{}:
      Empty
    case Some{x}:
      Unit

def h.some_none.e(-V: Data, -x: V, e: {Some{x} == None{} : Maybe<&2, V>}) -> Empty:
  %e : h.isS(V, _)
  Unit{}

def h.some_none(-A: Type, -V: Data, -x: V, e: {Some{x} == None{} : Maybe<&2, V>}) -> A:
  exfalso(A, h.some_none.e(V, x, e))

def h.none_some(-A: Type, -V: Data, -x: V, e: {None{} == Some{x} : Maybe<&2, V>}) -> A:
  exfalso(A, h.some_none.e(V, x, Equal.sym(Maybe<&2, V>, None{}, Some{x}, e)))

# U32 equality is Word equality, so is_eq is reflexive and sound.
def h.bcmp_refl(b: Bool) -> {Bool.cmp(b, b) == EQ{} : Cmp}:
  match b:
    case True{}:
      {==}
    case False{}:
      {==}

def h.wcmp_refl(n: Nat, w: Word(n)) -> {Word.cmp(n, w, w) == EQ{} : Cmp}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{+b, +t}:
          %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, h.wcmp_refl(p, t)) : {Word.cmp.fin(b, b, _) == EQ{} : Cmp}
          h.bcmp_refl(b)

def h.u_refl(x: U32) -> {U32.is_eq(x, x) == True{} : Bool}:
  match x:
    case U32{+w}:
      %Equal.sym(Cmp, Word.cmp(32n, w, w), EQ{}, h.wcmp_refl(32n, w)) : {Cmp.is_eq(_) == True{} : Bool}
      {==}

def h.fin_eq(t: Cmp, -x: Bool, -y: Bool, e: {Cmp.is_eq(Word.cmp.fin(x, y, t)) == True{} : Bool})
  -> {Cmp.is_eq(t) == True{} : Bool}:
  match t:
    case LT{}:
      exfalso({Cmp.is_eq(LT{}) == True{} : Bool}, absurd_b(e))
    case EQ{}:
      {==}
    case GT{}:
      exfalso({Cmp.is_eq(GT{}) == True{} : Bool}, absurd_b(e))

def h.fin_hd(t: Cmp, x: Bool, y: Bool, e: {Cmp.is_eq(Word.cmp.fin(x, y, t)) == True{} : Bool})
  -> {x == y : Bool}:
  match t:
    case LT{}:
      exfalso({x == y : Bool}, absurd_b(e))
    case EQ{}:
      match x y:
        case False{} False{}:
          {==}
        case False{} True{}:
          exfalso({False{} == True{} : Bool}, absurd_b(e))
        case True{} False{}:
          exfalso({True{} == False{} : Bool}, absurd_b(e))
        case True{} True{}:
          {==}
    case GT{}:
      exfalso({x == y : Bool}, absurd_b(e))

def h.wcmp_sound(+n: Nat, a: Word(n), b: Word(n), +e: {Cmp.is_eq(Word.cmp(n, a, b)) == True{} : Bool})
  -> {a == b : Word(n)}:
  match n:
    case 0n:
      match a b:
        case WNil{} WNil{}:
          {==}
    case 1n+p:
      match a b:
        case WCon{+x, +at} WCon{+y, +bt}:
          +e1 = h.fin_hd(Word.cmp(p, at, bt), x, y, e)
          +e2 = h.wcmp_sound(p, at, bt, h.fin_eq(Word.cmp(p, at, bt), x, y, e))
          %e1 : {WCon{x, at} == WCon{_, bt} : Word(1n+p)}
          %e2 : {WCon{x, at} == WCon{x, _} : Word(1n+p)}
          {==}

def h.u_sound(a: U32, b: U32, e: {U32.is_eq(a, b) == True{} : Bool}) -> {a == b : U32}:
  match a b:
    case U32{+x} U32{+y}:
      %h.wcmp_sound(32n, x, y, e) : {U32{x} == U32{_} : U32}
      {==}

# A mask with at most one set bit routes every hash to one of two sides.
def h.isz(n: Nat, w: Word(n)) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      match w:
        case WCon{b, t}:
          Bool.not(b) && h.isz(p, t)

def h.at1(n: Nat, w: Word(n)) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      match w:
        case WCon{b, t}:
          match b:
            case True{}:
              h.isz(p, t)
            case False{}:
              h.at1(p, t)

def h.onebit(m: U32) -> Bool:
  match m:
    case U32{w}:
      h.at1(32n, w)

def h.and_z(+n: Nat, x: Word(n), m: Word(n), e: {h.isz(n, m) == True{} : Bool})
  -> {Word.and(n, x, m) == Word.zero(n) : Word(n)}:
  match n:
    case 0n:
      match x m:
        case WNil{} WNil{}:
          {==}
    case 1n+p:
      match x m:
        case WCon{+a, +xt} WCon{True{}, +mt}:
          exfalso({Word.and(1n+p, WCon{a, xt}, WCon{True{}, mt}) == Word.zero(1n+p) : Word(1n+p)},
            absurd_b(e))
        case WCon{True{}, +xt} WCon{False{}, +mt}:
          Equal.cong(Word(p), Word(1n+p), w => WCon{False{}, w}, Word.and(p, xt, mt), Word.zero(p),
            h.and_z(p, xt, mt, e))
        case WCon{False{}, +xt} WCon{False{}, +mt}:
          Equal.cong(Word(p), Word(1n+p), w => WCon{False{}, w}, Word.and(p, xt, mt), Word.zero(p),
            h.and_z(p, xt, mt, e))

def h.zc(+n: Nat, +x: Word(n), +m: Word(n), +e: {h.isz(n, m) == True{} : Bool})
  -> {Word.cmp(n, Word.and(n, x, m), Word.zero(n)) == EQ{} : Cmp}:
  %Equal.sym(Word(n), Word.and(n, x, m), Word.zero(n), h.and_z(n, x, m, e)) : {Word.cmp(n, _, Word.zero(n)) == EQ{} : Cmp}
  h.wcmp_refl(n, Word.zero(n))

def h.zc2(+n: Nat, +x: Word(n), +y: Word(n), +m: Word(n), +e: {h.isz(n, m) == True{} : Bool})
  -> {Word.cmp(n, Word.and(n, x, m), Word.and(n, y, m)) == EQ{} : Cmp}:
  %Equal.sym(Word(n), Word.and(n, x, m), Word.zero(n), h.and_z(n, x, m, e)) : {Word.cmp(n, _, Word.and(n, y, m)) == EQ{} : Cmp}
  %Equal.sym(Word(n), Word.and(n, y, m), Word.zero(n), h.and_z(n, y, m, e)) : {Word.cmp(n, Word.zero(n), _) == EQ{} : Cmp}
  h.wcmp_refl(n, Word.zero(n))

# A head bit under a set mask bit, with the rest masked to zero, is set when the word is not zero.
def h.hd_true(
  a: Bool, +p: Nat, +xt: Word(p), +mt: Word(p), +em: {h.isz(p, mt) == True{} : Bool},
  ex: {Cmp.is_eq(Word.cmp.fin(Bool.and(a, True{}), False{}, Word.cmp(p, Word.and(p, xt, mt), Word.zero(p)))) == False{} : Bool}
) -> {a == True{} : Bool}:
  match a:
    case True{}:
      {==}
    case False{}:
      Equal.sym(Bool, True{}, False{},
        rw(Cmp, t => {Cmp.is_eq(Word.cmp.fin(False{}, False{}, t)) == False{} : Bool},
          EQ{}, Word.cmp(p, Word.and(p, xt, mt), Word.zero(p)),
          Equal.sym(Cmp, Word.cmp(p, Word.and(p, xt, mt), Word.zero(p)), EQ{}, h.zc(p, xt, mt, em)), ex))

def h.low(a: Bool, t: Cmp, e: {Cmp.is_eq(Word.cmp.fin(Bool.and(a, False{}), False{}, t)) == False{} : Bool})
  -> {Cmp.is_eq(t) == False{} : Bool}:
  match a:
    case True{}:
      match t:
        case LT{}:
          e
        case EQ{}:
          e
        case GT{}:
          e
    case False{}:
      match t:
        case LT{}:
          e
        case EQ{}:
          e
        case GT{}:
          e

def h.lift0(t: Cmp, ih: {Cmp.is_eq(t) == True{} : Bool})
  -> {Cmp.is_eq(Word.cmp.fin(False{}, False{}, t)) == True{} : Bool}:
  match t:
    case LT{}:
      ih
    case EQ{}:
      {==}
    case GT{}:
      ih

def h.lift(a: Bool, c: Bool, t: Cmp, ih: {Cmp.is_eq(t) == True{} : Bool})
  -> {Cmp.is_eq(Word.cmp.fin(Bool.and(a, False{}), Bool.and(c, False{}), t)) == True{} : Bool}:
  match a c:
    case True{} True{}:
      h.lift0(t, ih)
    case True{} False{}:
      h.lift0(t, ih)
    case False{} True{}:
      h.lift0(t, ih)
    case False{} False{}:
      h.lift0(t, ih)

def h.route_t(
  +a: Bool, +c: Bool, +p: Nat, +xt: Word(p), +yt: Word(p), +mt: Word(p),
  +em: {h.isz(p, mt) == True{} : Bool},
  ex: {Cmp.is_eq(Word.cmp.fin(Bool.and(a, True{}), False{}, Word.cmp(p, Word.and(p, xt, mt), Word.zero(p)))) == False{} : Bool},
  ey: {Cmp.is_eq(Word.cmp.fin(Bool.and(c, True{}), False{}, Word.cmp(p, Word.and(p, yt, mt), Word.zero(p)))) == False{} : Bool}
) -> {Cmp.is_eq(Word.cmp.fin(Bool.and(a, True{}), Bool.and(c, True{}),
       Word.cmp(p, Word.and(p, xt, mt), Word.and(p, yt, mt)))) == True{} : Bool}:
  %Equal.sym(Bool, a, True{}, h.hd_true(a, p, xt, mt, em, ex))
    : {Cmp.is_eq(Word.cmp.fin(Bool.and(_, True{}), Bool.and(c, True{}), Word.cmp(p, Word.and(p, xt, mt), Word.and(p, yt, mt)))) == True{} : Bool}
  %Equal.sym(Bool, c, True{}, h.hd_true(c, p, yt, mt, em, ey))
    : {Cmp.is_eq(Word.cmp.fin(True{}, Bool.and(_, True{}), Word.cmp(p, Word.and(p, xt, mt), Word.and(p, yt, mt)))) == True{} : Bool}
  %Equal.sym(Cmp, Word.cmp(p, Word.and(p, xt, mt), Word.and(p, yt, mt)), EQ{}, h.zc2(p, xt, yt, mt, em))
    : {Cmp.is_eq(Word.cmp.fin(True{}, True{}, _)) == True{} : Bool}
  {==}

def h.route_w(
  +n: Nat, x: Word(n), y: Word(n), m: Word(n),
  em: {h.at1(n, m) == True{} : Bool},
  ex: {Cmp.is_eq(Word.cmp(n, Word.and(n, x, m), Word.zero(n))) == False{} : Bool},
  ey: {Cmp.is_eq(Word.cmp(n, Word.and(n, y, m), Word.zero(n))) == False{} : Bool}
) -> {Cmp.is_eq(Word.cmp(n, Word.and(n, x, m), Word.and(n, y, m))) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match x y m:
        case WCon{+a, +xt} WCon{+c, +yt} WCon{True{}, +mt}:
          h.route_t(a, c, p, xt, yt, mt, em, ex, ey)
        case WCon{+a, +xt} WCon{+c, +yt} WCon{False{}, +mt}:
          h.lift(a, c, Word.cmp(p, Word.and(p, xt, mt), Word.and(p, yt, mt)),
            h.route_w(p, xt, yt, mt, em,
              h.low(a, Word.cmp(p, Word.and(p, xt, mt), Word.zero(p)), ex),
              h.low(c, Word.cmp(p, Word.and(p, yt, mt), Word.zero(p)), ey)))

def h.route(
  x: U32, y: U32, m: U32, em: {h.onebit(m) == True{} : Bool},
  ex: {U32.is_eq((x .&. m : U32), 0) == False{} : Bool},
  ey: {U32.is_eq((y .&. m : U32), 0) == False{} : Bool}
) -> {U32.is_eq((x .&. m : U32), (y .&. m : U32)) == True{} : Bool}:
  match x y m:
    case U32{xw} U32{yw} U32{+mw}:
      h.route_w(32n, xw, yw, mw, em, ex, ey)

def h.isz_put(n: Nat, t: Word(n), e: {h.isz(n, t) == True{} : Bool})
  -> {h.isz(n, Word.shl.put(n, False{}, t)) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match t:
        case WCon{True{}, t2}:
          exfalso({h.isz(1n+p, Word.shl.put(1n+p, False{}, WCon{True{}, t2})) == True{} : Bool}, absurd_b(e))
        case WCon{False{}, t2}:
          h.isz_put(p, t2, e)

def h.at1_put.t(q: Nat, b: Bool, t2: Word(q), e: {h.isz(1n+q, WCon{b, t2}) == True{} : Bool})
  -> {h.isz(q, Word.shl.put(q, b, t2)) == True{} : Bool}:
  match b:
    case True{}:
      exfalso({h.isz(q, Word.shl.put(q, True{}, t2)) == True{} : Bool}, absurd_b(e))
    case False{}:
      h.isz_put(q, t2, e)

def h.at1_put(p: Nat, t: Word(p), c: Bool, e: {h.at1(1n+p, WCon{c, t}) == True{} : Bool})
  -> {h.at1(p, Word.shl.put(p, c, t)) == True{} : Bool}:
  match p:
    case 0n:
      {==}
    case 1n+q:
      match t:
        case WCon{b, t2}:
          match c:
            case True{}:
              h.at1_put.t(q, b, t2, e)
            case False{}:
              h.at1_put(q, t2, b, e)

def h.at1_shl(n: Nat, w: Word(n), e: {h.at1(n, w) == True{} : Bool})
  -> {h.at1(n, Word.shl(n, w)) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{b, t}:
          h.at1_put(p, t, b, e)

def h.onebit_shl(m: U32, e: {h.onebit(m) == True{} : Bool}) -> {h.onebit((m << 1n : U32)) == True{} : Bool}:
  match m:
    case U32{w}:
      h.at1_shl(32n, w, e)

# --- buckets ---------------------------------------------------------------------

def h.egc(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, b: Bool, +val: V,
  rest: List<&2, M.Entry<K, V>>, +k: K
) -> Maybe<&2, V>:
  M.HMap.bool(Maybe<&2, V>, b, u => Some{val}, u => M.HMap.entries.get(~K, ~V, ~eq, rest, k))

def h.epc(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, b: Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +k: K, +v: V
) -> List<&2, M.Entry<K, V>>:
  M.HMap.bool(List<&2, M.Entry<K, V>>, b,
    u => M.Entry{key, v} <> rest,
    u => M.Entry{key, val} <> M.HMap.entries.put(~K, ~V, ~eq, rest, k, v))

def h.edc(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, b: Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +k: K
) -> List<&2, M.Entry<K, V>>:
  M.HMap.bool(List<&2, M.Entry<K, V>>, b,
    u => rest,
    u => M.Entry{key, val} <> M.HMap.entries.del(~K, ~V, ~eq, rest, k))

def h.egc2(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, c: Bool, +val: V,
  +xs: List<&2, M.Entry<K, V>>, +ys: List<&2, M.Entry<K, V>>, +k: K,
  e: {M.HMap.entries.get(~K, ~V, ~eq, xs, k) == M.HMap.entries.get(~K, ~V, ~eq, ys, k) : Maybe<&2, V>}
) -> {h.egc(~K, ~V, ~eq, c, val, xs, k) == h.egc(~K, ~V, ~eq, c, val, ys, k) : Maybe<&2, V>}:
  match c:
    case True{}:
      {==}
    case False{}:
      e

# eq(k, k2) is False when k2 != k.
def h.ne_f.c(
  ~K: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +k2: K, +k: K, ne: {k2 != k : K}, b: Bool, eb: {b == eq(k, k2) : Bool}
) -> {b == False{} : Bool}:
  match b:
    case True{}:
      exfalso({True{} == False{} : Bool},
        ne(Equal.sym(K, k, k2, sound(k, k2, h.sb(True{}, eq(k, k2), eb)))))
    case False{}:
      {==}

def h.ne_f(
  ~K: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +k2: K, +k: K, ne: {k2 != k : K}
) -> {eq(k, k2) == False{} : Bool}:
  h.ne_f.c(~K, ~eq, ~sound, k2, k, ne, eq(k, k2), {==})

# eq(k, key) is False when key is equal to k2 and eq(k, k2) is False.
def h.nk(
  ~K: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +k2: K, +key: K, +k: K, e: {eq(k2, key) == True{} : Bool}, ne: {eq(k, k2) == False{} : Bool}
) -> {eq(k, key) == False{} : Bool}:
  rw(K, z => {eq(k, z) == False{} : Bool}, key, k2, Equal.sym(K, k2, key, sound(k2, key, e)), ne)

def h.eg_put_same.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +k: K, +v: V, b: Bool, eb: {b == eq(k, key) : Bool},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v), k) == Some{v} : Maybe<&2, V>}
) -> {M.HMap.entries.get(~K, ~V, ~eq, h.epc(~K, ~V, ~eq, b, key, val, rest, k, v), k) == Some{v} : Maybe<&2, V>}:
  match b:
    case True{}:
      %eb : {h.egc(~K, ~V, ~eq, _, v, rest, k) == Some{v} : Maybe<&2, V>}
      {==}
    case False{}:
      %eb : {h.egc(~K, ~V, ~eq, _, val, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v), k) == Some{v} : Maybe<&2, V>}
      ih

def h.eg_put_same(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  xs: List<&2, M.Entry<K, V>>, +k: K, +v: V
) -> {M.HMap.entries.get(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, xs, k, v), k) == Some{v} : Maybe<&2, V>}:
  match xs:
    case Nil{}:
      %h.sb(eq(k, k), True{}, refl(k)) : {h.egc(~K, ~V, ~eq, _, v, Nil{}, k) == Some{v} : Maybe<&2, V>}
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      h.eg_put_same.c(~K, ~V, ~eq, key, val, rest, k, v, eq(k, key), {==},
        h.eg_put_same(~K, ~V, ~eq, ~refl, rest, k, v))

def h.eg_put_other.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +key: K, +val: V, +rest: List<&2, M.Entry<K, V>>, +k2: K, +k: K, +v: V,
  +ne: {eq(k, k2) == False{} : Bool}, b: Bool, eb: {b == eq(k2, key) : Bool},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, rest, k2, v), k)
       == M.HMap.entries.get(~K, ~V, ~eq, rest, k) : Maybe<&2, V>}
) -> {M.HMap.entries.get(~K, ~V, ~eq, h.epc(~K, ~V, ~eq, b, key, val, rest, k2, v), k)
      == h.egc(~K, ~V, ~eq, eq(k, key), val, rest, k) : Maybe<&2, V>}:
  match b:
    case True{}:
      +nk = h.nk(~K, ~eq, ~sound, k2, key, k, h.sb(True{}, eq(k2, key), eb), ne)
      %h.sb(eq(k, key), False{}, nk)
        : {h.egc(~K, ~V, ~eq, _, v, rest, k) == h.egc(~K, ~V, ~eq, eq(k, key), val, rest, k) : Maybe<&2, V>}
      %h.sb(eq(k, key), False{}, nk)
        : {M.HMap.entries.get(~K, ~V, ~eq, rest, k) == h.egc(~K, ~V, ~eq, _, val, rest, k) : Maybe<&2, V>}
      {==}
    case False{}:
      h.egc2(~K, ~V, ~eq, eq(k, key), val, M.HMap.entries.put(~K, ~V, ~eq, rest, k2, v), rest, k, ih)

def h.eg_put_other(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  xs: List<&2, M.Entry<K, V>>, +k2: K, +k: K, +v: V, +ne: {eq(k, k2) == False{} : Bool}
) -> {M.HMap.entries.get(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, xs, k2, v), k)
      == M.HMap.entries.get(~K, ~V, ~eq, xs, k) : Maybe<&2, V>}:
  match xs:
    case Nil{}:
      %h.sb(eq(k, k2), False{}, ne) : {h.egc(~K, ~V, ~eq, _, v, Nil{}, k) == None{} : Maybe<&2, V>}
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      h.eg_put_other.c(~K, ~V, ~eq, ~sound, key, val, rest, k2, k, v, ne, eq(k2, key), {==},
        h.eg_put_other(~K, ~V, ~eq, ~sound, rest, k2, k, v, ne))

# A bucket whose keys all hash to o holds no key hashing elsewhere.
def h.eg_none_hashed.c(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +key: K, +val: V, +rest: List<&2, M.Entry<K, V>>, +o: U32, +k: K,
  hk: {U32.is_eq(o, hash(k)) == False{} : Bool}, hh: {U32.is_eq(o, hash(key)) == True{} : Bool},
  b: Bool, eb: {b == eq(k, key) : Bool},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, rest, k) == None{} : Maybe<&2, V>}
) -> {h.egc(~K, ~V, ~eq, b, val, rest, k) == None{} : Maybe<&2, V>}:
  match b:
    case True{}:
      h.tf({h.egc(~K, ~V, ~eq, True{}, val, rest, k) == None{} : Maybe<&2, V>}, U32.is_eq(o, hash(k)),
        rw(K, z => {U32.is_eq(o, hash(z)) == True{} : Bool}, k, key,
          sound(k, key, h.sb(True{}, eq(k, key), eb)), hh),
        hk)
    case False{}:
      ih

def h.eg_none_hashed(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  xs: List<&2, M.Entry<K, V>>, +o: U32, +k: K, +hk: {U32.is_eq(o, hash(k)) == False{} : Bool},
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, xs, o) == True{} : Bool}
) -> {M.HMap.entries.get(~K, ~V, ~eq, xs, k) == None{} : Maybe<&2, V>}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      +hs = hs
      h.eg_none_hashed.c(~K, ~V, ~hash, ~eq, ~sound, key, val, rest, o, k, hk,
        and_l(U32.is_eq(o, hash(key)), Laws.hmap_hashed(~K, ~V, ~hash, rest, o), hs),
        eq(k, key), {==},
        h.eg_none_hashed(~K, ~V, ~hash, ~eq, ~sound, rest, o, k, hk,
          and_r(U32.is_eq(o, hash(key)), Laws.hmap_hashed(~K, ~V, ~hash, rest, o), hs)))

def h.len(-K: Data, -V: Data, xs: List<&2, M.Entry<K, V>>) -> Nat:
  List.length(&2, M.Entry<K, V>, xs)

def h.elen_put_new.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +k: K, +v: V, b: Bool,
  miss: {h.egc(~K, ~V, ~eq, b, val, rest, k) == None{} : Maybe<&2, V>},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, rest, k) == None{} : Maybe<&2, V>}
    -> {h.len(K, V, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v)) == 1n+h.len(K, V, rest) : Nat}
) -> {h.len(K, V, h.epc(~K, ~V, ~eq, b, key, val, rest, k, v)) == 1n+1n+h.len(K, V, rest) : Nat}:
  match b:
    case True{}:
      h.some_none({h.len(K, V, M.Entry{key, v} <> rest) == 1n+1n+h.len(K, V, rest) : Nat}, V, val, miss)
    case False{}:
      Equal.cong(Nat, Nat, x => 1n+x, h.len(K, V, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v)),
        1n+h.len(K, V, rest), ih(miss))

def h.elen_put_new(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, xs: List<&2, M.Entry<K, V>>, +k: K, +v: V,
  miss: {M.HMap.entries.get(~K, ~V, ~eq, xs, k) == None{} : Maybe<&2, V>}
) -> {h.len(K, V, M.HMap.entries.put(~K, ~V, ~eq, xs, k, v)) == 1n+h.len(K, V, xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      h.elen_put_new.c(~K, ~V, ~eq, key, val, rest, k, v, eq(k, key), miss,
        e => h.elen_put_new(~K, ~V, ~eq, rest, k, v, e))

def h.elen_put_hit.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +k: K, +v: V, -w: V, b: Bool,
  hit: {h.egc(~K, ~V, ~eq, b, val, rest, k) == Some{w} : Maybe<&2, V>},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, rest, k) == Some{w} : Maybe<&2, V>}
    -> {h.len(K, V, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v)) == h.len(K, V, rest) : Nat}
) -> {h.len(K, V, h.epc(~K, ~V, ~eq, b, key, val, rest, k, v)) == 1n+h.len(K, V, rest) : Nat}:
  match b:
    case True{}:
      {==}
    case False{}:
      Equal.cong(Nat, Nat, x => 1n+x, h.len(K, V, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v)),
        h.len(K, V, rest), ih(hit))

def h.elen_put_hit(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, xs: List<&2, M.Entry<K, V>>, +k: K, +v: V, -w: V,
  hit: {M.HMap.entries.get(~K, ~V, ~eq, xs, k) == Some{w} : Maybe<&2, V>}
) -> {h.len(K, V, M.HMap.entries.put(~K, ~V, ~eq, xs, k, v)) == h.len(K, V, xs) : Nat}:
  match xs:
    case Nil{}:
      h.none_some({h.len(K, V, M.HMap.entries.put(~K, ~V, ~eq, Nil{}, k, v)) == 0n : Nat}, V, w, hit)
    case Con{M.Entry{+key, +val}, +rest}:
      h.elen_put_hit.c(~K, ~V, ~eq, key, val, rest, k, v, w, eq(k, key), hit,
        e => h.elen_put_hit(~K, ~V, ~eq, rest, k, v, w, e))

def h.elen_del_hit.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +k: K, -w: V, b: Bool,
  hit: {h.egc(~K, ~V, ~eq, b, val, rest, k) == Some{w} : Maybe<&2, V>},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, rest, k) == Some{w} : Maybe<&2, V>}
    -> {1n+h.len(K, V, M.HMap.entries.del(~K, ~V, ~eq, rest, k)) == h.len(K, V, rest) : Nat}
) -> {1n+h.len(K, V, h.edc(~K, ~V, ~eq, b, key, val, rest, k)) == 1n+h.len(K, V, rest) : Nat}:
  match b:
    case True{}:
      {==}
    case False{}:
      Equal.cong(Nat, Nat, x => 1n+x, 1n+h.len(K, V, M.HMap.entries.del(~K, ~V, ~eq, rest, k)),
        h.len(K, V, rest), ih(hit))

def h.elen_del_hit(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, xs: List<&2, M.Entry<K, V>>, +k: K, -w: V,
  hit: {M.HMap.entries.get(~K, ~V, ~eq, xs, k) == Some{w} : Maybe<&2, V>}
) -> {1n+h.len(K, V, M.HMap.entries.del(~K, ~V, ~eq, xs, k)) == h.len(K, V, xs) : Nat}:
  match xs:
    case Nil{}:
      h.none_some({1n == 0n : Nat}, V, w, hit)
    case Con{M.Entry{+key, +val}, +rest}:
      h.elen_del_hit.c(~K, ~V, ~eq, key, val, rest, k, w, eq(k, key), hit,
        e => h.elen_del_hit(~K, ~V, ~eq, rest, k, w, e))

def h.edel_miss.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +k: K, b: Bool,
  miss: {h.egc(~K, ~V, ~eq, b, val, rest, k) == None{} : Maybe<&2, V>},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, rest, k) == None{} : Maybe<&2, V>}
    -> {M.HMap.entries.del(~K, ~V, ~eq, rest, k) == rest : List<&2, M.Entry<K, V>>}
) -> {h.edc(~K, ~V, ~eq, b, key, val, rest, k) == M.Entry{key, val} <> rest : List<&2, M.Entry<K, V>>}:
  match b:
    case True{}:
      h.some_none({rest == M.Entry{key, val} <> rest : List<&2, M.Entry<K, V>>}, V, val, miss)
    case False{}:
      Equal.cong(List<&2, M.Entry<K, V>>, List<&2, M.Entry<K, V>>, t => M.Entry{key, val} <> t,
        M.HMap.entries.del(~K, ~V, ~eq, rest, k), rest, ih(miss))

def h.edel_miss(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, xs: List<&2, M.Entry<K, V>>, +k: K,
  miss: {M.HMap.entries.get(~K, ~V, ~eq, xs, k) == None{} : Maybe<&2, V>}
) -> {M.HMap.entries.del(~K, ~V, ~eq, xs, k) == xs : List<&2, M.Entry<K, V>>}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      h.edel_miss.c(~K, ~V, ~eq, key, val, rest, k, eq(k, key), miss,
        e => h.edel_miss(~K, ~V, ~eq, rest, k, e))

def h.absent_none(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, xs: List<&2, M.Entry<K, V>>, +k: K,
  ab: {Laws.hmap_absent(~K, ~V, ~eq, xs, k) == True{} : Bool}
) -> {M.HMap.entries.get(~K, ~V, ~eq, xs, k) == None{} : Maybe<&2, V>}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      +ab = ab
      %h.sb(eq(k, key), False{},
        h.not_t(eq(k, key), and_l(Bool.not(eq(k, key)), Laws.hmap_absent(~K, ~V, ~eq, rest, k), ab)))
        : {h.egc(~K, ~V, ~eq, _, val, rest, k) == None{} : Maybe<&2, V>}
      h.absent_none(~K, ~V, ~eq, rest, k,
        and_r(Bool.not(eq(k, key)), Laws.hmap_absent(~K, ~V, ~eq, rest, k), ab))

def h.eg_del_same.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +key: K, +val: V, +rest: List<&2, M.Entry<K, V>>, +k: K, b: Bool, eb: {b == eq(k, key) : Bool},
  ab: {Laws.hmap_absent(~K, ~V, ~eq, rest, key) == True{} : Bool},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, rest, k), k) == None{} : Maybe<&2, V>}
) -> {M.HMap.entries.get(~K, ~V, ~eq, h.edc(~K, ~V, ~eq, b, key, val, rest, k), k) == None{} : Maybe<&2, V>}:
  match b:
    case True{}:
      h.absent_none(~K, ~V, ~eq, rest, k,
        rw(K, z => {Laws.hmap_absent(~K, ~V, ~eq, rest, z) == True{} : Bool}, k, key,
          sound(k, key, h.sb(True{}, eq(k, key), eb)), ab))
    case False{}:
      %eb : {h.egc(~K, ~V, ~eq, _, val, M.HMap.entries.del(~K, ~V, ~eq, rest, k), k) == None{} : Maybe<&2, V>}
      ih

def h.eg_del_same(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  xs: List<&2, M.Entry<K, V>>, +k: K,
  ds: {Laws.hmap_distinct(~K, ~V, ~eq, xs) == True{} : Bool}
) -> {M.HMap.entries.get(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, xs, k), k) == None{} : Maybe<&2, V>}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      +ds = ds
      h.eg_del_same.c(~K, ~V, ~eq, ~sound, key, val, rest, k, eq(k, key), {==},
        and_l(Laws.hmap_absent(~K, ~V, ~eq, rest, key), Laws.hmap_distinct(~K, ~V, ~eq, rest), ds),
        h.eg_del_same(~K, ~V, ~eq, ~sound, rest, k,
          and_r(Laws.hmap_absent(~K, ~V, ~eq, rest, key), Laws.hmap_distinct(~K, ~V, ~eq, rest), ds)))

def h.eg_del_other.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +key: K, +val: V, +rest: List<&2, M.Entry<K, V>>, +k2: K, +k: K,
  +ne: {eq(k, k2) == False{} : Bool}, b: Bool, eb: {b == eq(k2, key) : Bool},
  ih: {M.HMap.entries.get(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, rest, k2), k)
       == M.HMap.entries.get(~K, ~V, ~eq, rest, k) : Maybe<&2, V>}
) -> {M.HMap.entries.get(~K, ~V, ~eq, h.edc(~K, ~V, ~eq, b, key, val, rest, k2), k)
      == h.egc(~K, ~V, ~eq, eq(k, key), val, rest, k) : Maybe<&2, V>}:
  match b:
    case True{}:
      %h.sb(eq(k, key), False{}, h.nk(~K, ~eq, ~sound, k2, key, k, h.sb(True{}, eq(k2, key), eb), ne))
        : {M.HMap.entries.get(~K, ~V, ~eq, rest, k) == h.egc(~K, ~V, ~eq, _, val, rest, k) : Maybe<&2, V>}
      {==}
    case False{}:
      h.egc2(~K, ~V, ~eq, eq(k, key), val, M.HMap.entries.del(~K, ~V, ~eq, rest, k2), rest, k, ih)

def h.eg_del_other(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  xs: List<&2, M.Entry<K, V>>, +k2: K, +k: K, +ne: {eq(k, k2) == False{} : Bool}
) -> {M.HMap.entries.get(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, xs, k2), k)
      == M.HMap.entries.get(~K, ~V, ~eq, xs, k) : Maybe<&2, V>}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      h.eg_del_other.c(~K, ~V, ~eq, ~sound, key, val, rest, k2, k, ne, eq(k2, key), {==},
        h.eg_del_other(~K, ~V, ~eq, ~sound, rest, k2, k, ne))

# eq is symmetric on False, given refl and sound.
def h.eq_sym_f.c(
  ~K: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +k: K, +key: K, e: {eq(k, key) == False{} : Bool}, b: Bool, eb: {b == eq(key, k) : Bool}
) -> {b == False{} : Bool}:
  match b:
    case True{}:
      h.tf({True{} == False{} : Bool}, eq(k, k), refl(k),
        rw(K, z => {eq(k, z) == False{} : Bool}, k, key,
          Equal.sym(K, key, k, sound(key, k, h.sb(True{}, eq(key, k), eb))), e))
    case False{}:
      {==}

def h.eq_sym_f(
  ~K: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +k: K, +key: K, e: {eq(k, key) == False{} : Bool}
) -> {eq(key, k) == False{} : Bool}:
  h.eq_sym_f.c(~K, ~eq, ~refl, ~sound, k, key, e, eq(key, k), {==})

def h.absent_put.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +key2: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +key: K, +k: K, +v: V, b: Bool,
  +ab: {Laws.hmap_absent(~K, ~V, ~eq, M.Entry{key2, val} <> rest, key) == True{} : Bool},
  ih: {Laws.hmap_absent(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v), key) == True{} : Bool}
) -> {Laws.hmap_absent(~K, ~V, ~eq, h.epc(~K, ~V, ~eq, b, key2, val, rest, k, v), key) == True{} : Bool}:
  match b:
    case True{}:
      ab
    case False{}:
      and_i(Bool.not(eq(key, key2)),
        Laws.hmap_absent(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v), key),
        and_l(Bool.not(eq(key, key2)), Laws.hmap_absent(~K, ~V, ~eq, rest, key), ab), ih)

def h.absent_put(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  xs: List<&2, M.Entry<K, V>>, +key: K, +k: K, +v: V,
  ab: {Laws.hmap_absent(~K, ~V, ~eq, xs, key) == True{} : Bool},
  +nk: {eq(k, key) == False{} : Bool}
) -> {Laws.hmap_absent(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, xs, k, v), key) == True{} : Bool}:
  match xs:
    case Nil{}:
      %h.sb(eq(key, k), False{}, h.eq_sym_f(~K, ~eq, ~refl, ~sound, k, key, nk))
        : {Bool.and(Bool.not(_), True{}) == True{} : Bool}
      {==}
    case Con{M.Entry{+key2, +val}, +rest}:
      +ab = ab
      h.absent_put.c(~K, ~V, ~eq, key2, val, rest, key, k, v, eq(k, key2), ab,
        h.absent_put(~K, ~V, ~eq, ~refl, ~sound, rest, key, k, v,
          and_r(Bool.not(eq(key, key2)), Laws.hmap_absent(~K, ~V, ~eq, rest, key), ab), nk))

def h.distinct_put.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +key: K, +val: V, +rest: List<&2, M.Entry<K, V>>, +k: K, +v: V, b: Bool, eb: {b == eq(k, key) : Bool},
  +ds: {Laws.hmap_distinct(~K, ~V, ~eq, M.Entry{key, val} <> rest) == True{} : Bool},
  ih: {Laws.hmap_distinct(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v)) == True{} : Bool}
) -> {Laws.hmap_distinct(~K, ~V, ~eq, h.epc(~K, ~V, ~eq, b, key, val, rest, k, v)) == True{} : Bool}:
  match b:
    case True{}:
      ds
    case False{}:
      and_i(Laws.hmap_absent(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v), key),
        Laws.hmap_distinct(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v)),
        h.absent_put(~K, ~V, ~eq, ~refl, ~sound, rest, key, k, v,
          and_l(Laws.hmap_absent(~K, ~V, ~eq, rest, key), Laws.hmap_distinct(~K, ~V, ~eq, rest), ds),
          h.sb(False{}, eq(k, key), eb)),
        ih)

def h.distinct_put(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  xs: List<&2, M.Entry<K, V>>, +k: K, +v: V,
  ds: {Laws.hmap_distinct(~K, ~V, ~eq, xs) == True{} : Bool}
) -> {Laws.hmap_distinct(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, xs, k, v)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      +ds = ds
      h.distinct_put.c(~K, ~V, ~eq, ~refl, ~sound, key, val, rest, k, v, eq(k, key), {==}, ds,
        h.distinct_put(~K, ~V, ~eq, ~refl, ~sound, rest, k, v,
          and_r(Laws.hmap_absent(~K, ~V, ~eq, rest, key), Laws.hmap_distinct(~K, ~V, ~eq, rest), ds)))

def h.hashed_put.c(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +o: U32, +k: K, +v: V, b: Bool,
  +hs: {Laws.hmap_hashed(~K, ~V, ~hash, M.Entry{key, val} <> rest, o) == True{} : Bool},
  ih: {Laws.hmap_hashed(~K, ~V, ~hash, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v), o) == True{} : Bool}
) -> {Laws.hmap_hashed(~K, ~V, ~hash, h.epc(~K, ~V, ~eq, b, key, val, rest, k, v), o) == True{} : Bool}:
  match b:
    case True{}:
      hs
    case False{}:
      and_i(U32.is_eq(o, hash(key)),
        Laws.hmap_hashed(~K, ~V, ~hash, M.HMap.entries.put(~K, ~V, ~eq, rest, k, v), o),
        and_l(U32.is_eq(o, hash(key)), Laws.hmap_hashed(~K, ~V, ~hash, rest, o), hs), ih)

def h.hashed_put(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  xs: List<&2, M.Entry<K, V>>, +o: U32, +k: K, +v: V,
  +hk: {U32.is_eq(o, hash(k)) == True{} : Bool},
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, xs, o) == True{} : Bool}
) -> {Laws.hmap_hashed(~K, ~V, ~hash, M.HMap.entries.put(~K, ~V, ~eq, xs, k, v), o) == True{} : Bool}:
  match xs:
    case Nil{}:
      %h.sb(U32.is_eq(o, hash(k)), True{}, hk) : {Bool.and(_, True{}) == True{} : Bool}
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      +hs = hs
      h.hashed_put.c(~K, ~V, ~hash, ~eq, key, val, rest, o, k, v, eq(k, key), hs,
        h.hashed_put(~K, ~V, ~hash, ~eq, rest, o, k, v, hk,
          and_r(U32.is_eq(o, hash(key)), Laws.hmap_hashed(~K, ~V, ~hash, rest, o), hs)))

def h.absent_del.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +key2: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +key: K, +k: K, b: Bool,
  +ab: {Laws.hmap_absent(~K, ~V, ~eq, M.Entry{key2, val} <> rest, key) == True{} : Bool},
  ih: {Laws.hmap_absent(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, rest, k), key) == True{} : Bool}
) -> {Laws.hmap_absent(~K, ~V, ~eq, h.edc(~K, ~V, ~eq, b, key2, val, rest, k), key) == True{} : Bool}:
  match b:
    case True{}:
      and_r(Bool.not(eq(key, key2)), Laws.hmap_absent(~K, ~V, ~eq, rest, key), ab)
    case False{}:
      and_i(Bool.not(eq(key, key2)),
        Laws.hmap_absent(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, rest, k), key),
        and_l(Bool.not(eq(key, key2)), Laws.hmap_absent(~K, ~V, ~eq, rest, key), ab), ih)

def h.absent_del(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, xs: List<&2, M.Entry<K, V>>, +key: K, +k: K,
  ab: {Laws.hmap_absent(~K, ~V, ~eq, xs, key) == True{} : Bool}
) -> {Laws.hmap_absent(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, xs, k), key) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key2, +val}, +rest}:
      +ab = ab
      h.absent_del.c(~K, ~V, ~eq, key2, val, rest, key, k, eq(k, key2), ab,
        h.absent_del(~K, ~V, ~eq, rest, key, k,
          and_r(Bool.not(eq(key, key2)), Laws.hmap_absent(~K, ~V, ~eq, rest, key), ab)))

def h.distinct_del.c(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +k: K, b: Bool,
  +ds: {Laws.hmap_distinct(~K, ~V, ~eq, M.Entry{key, val} <> rest) == True{} : Bool},
  ih: {Laws.hmap_distinct(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, rest, k)) == True{} : Bool}
) -> {Laws.hmap_distinct(~K, ~V, ~eq, h.edc(~K, ~V, ~eq, b, key, val, rest, k)) == True{} : Bool}:
  match b:
    case True{}:
      and_r(Laws.hmap_absent(~K, ~V, ~eq, rest, key), Laws.hmap_distinct(~K, ~V, ~eq, rest), ds)
    case False{}:
      and_i(Laws.hmap_absent(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, rest, k), key),
        Laws.hmap_distinct(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, rest, k)),
        h.absent_del(~K, ~V, ~eq, rest, key, k,
          and_l(Laws.hmap_absent(~K, ~V, ~eq, rest, key), Laws.hmap_distinct(~K, ~V, ~eq, rest), ds)),
        ih)

def h.distinct_del(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, xs: List<&2, M.Entry<K, V>>, +k: K,
  ds: {Laws.hmap_distinct(~K, ~V, ~eq, xs) == True{} : Bool}
) -> {Laws.hmap_distinct(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, xs, k)) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      +ds = ds
      h.distinct_del.c(~K, ~V, ~eq, key, val, rest, k, eq(k, key), ds,
        h.distinct_del(~K, ~V, ~eq, rest, k,
          and_r(Laws.hmap_absent(~K, ~V, ~eq, rest, key), Laws.hmap_distinct(~K, ~V, ~eq, rest), ds)))

def h.hashed_del.c(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +key: K, +val: V,
  +rest: List<&2, M.Entry<K, V>>, +o: U32, +k: K, b: Bool,
  +hs: {Laws.hmap_hashed(~K, ~V, ~hash, M.Entry{key, val} <> rest, o) == True{} : Bool},
  ih: {Laws.hmap_hashed(~K, ~V, ~hash, M.HMap.entries.del(~K, ~V, ~eq, rest, k), o) == True{} : Bool}
) -> {Laws.hmap_hashed(~K, ~V, ~hash, h.edc(~K, ~V, ~eq, b, key, val, rest, k), o) == True{} : Bool}:
  match b:
    case True{}:
      and_r(U32.is_eq(o, hash(key)), Laws.hmap_hashed(~K, ~V, ~hash, rest, o), hs)
    case False{}:
      and_i(U32.is_eq(o, hash(key)),
        Laws.hmap_hashed(~K, ~V, ~hash, M.HMap.entries.del(~K, ~V, ~eq, rest, k), o),
        and_l(U32.is_eq(o, hash(key)), Laws.hmap_hashed(~K, ~V, ~hash, rest, o), hs), ih)

def h.hashed_del(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  xs: List<&2, M.Entry<K, V>>, +o: U32, +k: K,
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, xs, o) == True{} : Bool}
) -> {Laws.hmap_hashed(~K, ~V, ~hash, M.HMap.entries.del(~K, ~V, ~eq, xs, k), o) == True{} : Bool}:
  match xs:
    case Nil{}:
      {==}
    case Con{M.Entry{+key, +val}, +rest}:
      +hs = hs
      h.hashed_del.c(~K, ~V, ~hash, ~eq, key, val, rest, o, k, eq(k, key), hs,
        h.hashed_del(~K, ~V, ~hash, ~eq, rest, o, k,
          and_r(U32.is_eq(o, hash(key)), Laws.hmap_hashed(~K, ~V, ~hash, rest, o), hs)))

# --- tries -----------------------------------------------------------------------

def h.G(~K: Data, ~V: Data, ~eq: K -> K -> Bool, +n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K) -> Maybe<&2, V>:
  M.HMap.get.go(~K, ~V, ~eq, n, mask, m, hk, k)

def h.P(~K: Data, ~V: Data, ~eq: K -> K -> Bool, +n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K, +v: V) -> M.HMap<K, V>:
  M.HMap.put.go(~K, ~V, ~eq, n, mask, m, hk, k, v)

def h.D(~K: Data, ~V: Data, ~eq: K -> K -> Bool, +n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K) -> M.HMap<K, V>:
  M.HMap.del.go(~K, ~V, ~eq, n, mask, m, hk, k)

def h.S(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +n: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V
) -> M.HMap<K, V>:
  M.HMap.split(~K, ~V, ~eq, n, mask, o, es, hk, k, v)

def h.EG(~K: Data, ~V: Data, ~eq: K -> K -> Bool, xs: List<&2, M.Entry<K, V>>, +k: K) -> Maybe<&2, V>:
  M.HMap.entries.get(~K, ~V, ~eq, xs, k)

def h.WF(~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +n: Nat, m: M.HMap<K, V>) -> Bool:
  Laws.hmap_wf.go(~K, ~V, ~hash, ~eq, n, m)

def h.Sz(-K: Data, -V: Data, m: M.HMap<K, V>) -> Nat:
  M.HMap.size(K, V, m)

# The branches of put.go, split, and del.go, with their test as a parameter.
def h.pl(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, b: Bool, +p: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V
) -> M.HMap<K, V>:
  M.HMap.bool(M.HMap<K, V>, b,
    u => M.HLeaf{o, M.HMap.entries.put(~K, ~V, ~eq, es, k, v)},
    u => M.HMap.split(~K, ~V, ~eq, 1n+p, mask, o, es, hk, k, v))

def h.pb(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, b: Bool, +p: Nat, +mask: U32,
  +lo: M.HMap<K, V>, +hi: M.HMap<K, V>, +hk: U32, +k: K, +v: V
) -> M.HMap<K, V>:
  M.HMap.bool(M.HMap<K, V>, b,
    u => M.HBranch{M.HMap.put.go(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v), hi},
    u => M.HBranch{lo, M.HMap.put.go(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v)})

def h.sp(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, b1: Bool, +b2: Bool, +p: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V
) -> M.HMap<K, V>:
  M.HMap.bool(M.HMap<K, V>, b1,
    u => M.HMap.bool(M.HMap<K, V>, b2,
      x => M.HBranch{M.HMap.split(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v), M.HNil{}},
      x => M.HBranch{M.HNil{}, M.HMap.split(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v)}),
    u => M.HMap.split.side(K, V, b2, M.HLeaf{o, es}, M.HLeaf{hk, [M.Entry{k, v}]}))

def h.dl(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, b: Bool, +o: U32, +es: List<&2, M.Entry<K, V>>, +k: K
) -> M.HMap<K, V>:
  M.HMap.bool(M.HMap<K, V>, b,
    u => M.HMap.leaf(K, V, o, M.HMap.entries.del(~K, ~V, ~eq, es, k)),
    u => M.HLeaf{o, es})

def h.db(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, b: Bool, +p: Nat, +mask: U32,
  +lo: M.HMap<K, V>, +hi: M.HMap<K, V>, +hk: U32, +k: K
) -> M.HMap<K, V>:
  M.HMap.bool(M.HMap<K, V>, b,
    u => M.HMap.join(K, V, M.HMap.del.go(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k), hi),
    u => M.HMap.join(K, V, lo, M.HMap.del.go(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)))

# get on a bucket, as get.go sees it above the last level.
def h.R(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +k: K
) -> Maybe<&2, V>:
  M.HMap.bool(Maybe<&2, V>, U32.is_eq(o, hash(k)), u => M.HMap.entries.get(~K, ~V, ~eq, es, k), u => None{})

def h.bool_none(-V: Data, b: Bool, -x: Maybe<&2, V>, e: {x == None{} : Maybe<&2, V>})
  -> {M.HMap.bool(Maybe<&2, V>, b, u => x, u => None{}) == None{} : Maybe<&2, V>}:
  match b:
    case True{}:
      e
    case False{}:
      {==}

def h.bnn(-V: Data, b: Bool, -x: Maybe<&2, V>, +e: {x == None{} : Maybe<&2, V>})
  -> {None{} == M.HMap.bool(Maybe<&2, V>, b, u => x, u => x) : Maybe<&2, V>}:
  match b:
    case True{}:
      Equal.sym(Maybe<&2, V>, x, None{}, e)
    case False{}:
      Equal.sym(Maybe<&2, V>, x, None{}, e)

def h.bool_l(-A: Type, b: Bool, -x1: A, -x2: A, -y: A, e: {x1 == x2 : A})
  -> {M.HMap.bool(A, b, u => x1, u => y) == M.HMap.bool(A, b, u => x2, u => y) : A}:
  match b:
    case True{}:
      e
    case False{}:
      {==}

def h.bool_r(-A: Type, b: Bool, -x: A, -y1: A, -y2: A, e: {y1 == y2 : A})
  -> {M.HMap.bool(A, b, u => x, u => y1) == M.HMap.bool(A, b, u => x, u => y2) : A}:
  match b:
    case True{}:
      {==}
    case False{}:
      e

def h.bsel(
  -A: Type, b: Bool, -x: A, -y: A, -z: A,
  ht: {b == True{} : Bool} -> {x == z : A}, hf: {b == False{} : Bool} -> {y == z : A}
) -> {M.HMap.bool(A, b, u => x, u => y) == z : A}:
  match b:
    case True{}:
      ht({==})
    case False{}:
      hf({==})

def h.cnc(c: Bool, e: {c == Bool.not(c) : Bool}) -> Empty:
  match c:
    case True{}:
      absurd_b(Equal.sym(Bool, True{}, False{}, e))
    case False{}:
      absurd_b(e)

# Routing facts about hashes and a mask.
def h.u_ne0.c(
  +x: U32, +y: U32, e1: {U32.is_eq(x, y) == False{} : Bool}, e2: {U32.is_eq(x, 0) == True{} : Bool},
  b: Bool, eb: {b == U32.is_eq(y, 0) : Bool}
) -> {b == False{} : Bool}:
  match b:
    case True{}:
      h.tf({True{} == False{} : Bool}, U32.is_eq(x, y),
        rw(U32, z => {U32.is_eq(x, z) == True{} : Bool}, y, 0,
          h.u_sound(y, 0, h.sb(True{}, U32.is_eq(y, 0), eb)), e2),
        e1)
    case False{}:
      {==}

def h.u_ne0(
  +x: U32, +y: U32, e1: {U32.is_eq(x, y) == False{} : Bool}, e2: {U32.is_eq(x, 0) == True{} : Bool}
) -> {U32.is_eq(y, 0) == False{} : Bool}:
  h.u_ne0.c(x, y, e1, e2, U32.is_eq(y, 0), {==})

def h.u_route_t.c(
  +o: U32, +hk: U32, +mask: U32, ob: {h.onebit(mask) == True{} : Bool},
  e1: {U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)) == False{} : Bool},
  e2: {U32.is_eq((o .&. mask : U32), 0) == False{} : Bool},
  b: Bool, eb: {b == U32.is_eq((hk .&. mask : U32), 0) : Bool}
) -> {b == True{} : Bool}:
  match b:
    case True{}:
      {==}
    case False{}:
      h.tf({False{} == True{} : Bool}, U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)),
        h.route(o, hk, mask, ob, e2, h.sb(False{}, U32.is_eq((hk .&. mask : U32), 0), eb)),
        e1)

def h.u_route_t(
  +o: U32, +hk: U32, +mask: U32, ob: {h.onebit(mask) == True{} : Bool},
  e1: {U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)) == False{} : Bool},
  e2: {U32.is_eq((o .&. mask : U32), 0) == False{} : Bool}
) -> {U32.is_eq((hk .&. mask : U32), 0) == True{} : Bool}:
  h.u_route_t.c(o, hk, mask, ob, e1, e2, U32.is_eq((hk .&. mask : U32), 0), {==})

def h.u_same0(
  +o: U32, +hk: U32, +mask: U32, -c: Bool,
  e1: {U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)) == True{} : Bool},
  e2: {U32.is_eq((o .&. mask : U32), 0) == c : Bool}
) -> {U32.is_eq((hk .&. mask : U32), 0) == c : Bool}:
  rw(U32, z => {U32.is_eq(z, 0) == c : Bool}, (hk .&. mask : U32), (o .&. mask : U32),
    Equal.sym(U32, (o .&. mask : U32), (hk .&. mask : U32),
      h.u_sound((o .&. mask : U32), (hk .&. mask : U32), e1)),
    e2)

def h.u_diff.c(
  +o: U32, +hk: U32, +mask: U32, +c: Bool,
  e2: {U32.is_eq((o .&. mask : U32), 0) == c : Bool},
  ed: {U32.is_eq((hk .&. mask : U32), 0) == Bool.not(c) : Bool},
  b: Bool, eb: {b == U32.is_eq(o, hk) : Bool}
) -> {b == False{} : Bool}:
  match b:
    case True{}:
      +e3 = rw(U32, z => {U32.is_eq((z .&. mask : U32), 0) == c : Bool}, hk, o,
        Equal.sym(U32, o, hk, h.u_sound(o, hk, h.sb(True{}, U32.is_eq(o, hk), eb))), e2)
      exfalso({True{} == False{} : Bool},
        h.cnc(c, Equal.trans(Bool, c, U32.is_eq((hk .&. mask : U32), 0), Bool.not(c),
          Equal.sym(Bool, U32.is_eq((hk .&. mask : U32), 0), c, e3), ed)))
    case False{}:
      {==}

def h.u_diff(
  +o: U32, +hk: U32, +mask: U32, +c: Bool,
  e2: {U32.is_eq((o .&. mask : U32), 0) == c : Bool},
  ed: {U32.is_eq((hk .&. mask : U32), 0) == Bool.not(c) : Bool}
) -> {U32.is_eq(o, hk) == False{} : Bool}:
  h.u_diff.c(o, hk, mask, c, e2, ed, U32.is_eq(o, hk), {==})

# Unfolding get.go by a known test, simple side first.
def h.g_lo(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, e: {U32.is_eq((hk .&. mask : U32), 0) == True{} : Bool}
) -> {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)
      == h.G(~K, ~V, ~eq, 1n+p, mask, M.HBranch{lo, hi}, hk, k) : Maybe<&2, V>}:
  %h.sb(U32.is_eq((hk .&. mask : U32), 0), True{}, e)
    : {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)
       == M.HMap.bool(Maybe<&2, V>, _, u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
         u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) : Maybe<&2, V>}
  {==}

def h.g_hi(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, e: {U32.is_eq((hk .&. mask : U32), 0) == False{} : Bool}
) -> {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)
      == h.G(~K, ~V, ~eq, 1n+p, mask, M.HBranch{lo, hi}, hk, k) : Maybe<&2, V>}:
  %h.sb(U32.is_eq((hk .&. mask : U32), 0), False{}, e)
    : {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)
       == M.HMap.bool(Maybe<&2, V>, _, u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
         u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) : Maybe<&2, V>}
  {==}

def h.g_lf_t(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, e: {U32.is_eq(o, hk) == True{} : Bool}
) -> {h.EG(~K, ~V, ~eq, es, k) == h.G(~K, ~V, ~eq, 1n+p, mask, M.HLeaf{o, es}, hk, k) : Maybe<&2, V>}:
  %h.sb(U32.is_eq(o, hk), True{}, e)
    : {h.EG(~K, ~V, ~eq, es, k)
       == M.HMap.bool(Maybe<&2, V>, _, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) : Maybe<&2, V>}
  {==}

def h.gnil(~K: Data, ~V: Data, ~eq: K -> K -> Bool, n: Nat, +mask: U32, +hk: U32, +k: K)
  -> {h.G(~K, ~V, ~eq, n, mask, M.HNil{}, hk, k) == None{} : Maybe<&2, V>}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

def h.g_nil_leaf(~K: Data, ~V: Data, ~eq: K -> K -> Bool, n: Nat, +mask: U32, +o: U32, +hk: U32, +k: K)
  -> {h.G(~K, ~V, ~eq, n, mask, M.HLeaf{o, Nil{}}, hk, k) == h.G(~K, ~V, ~eq, n, mask, M.HNil{}, hk, k) : Maybe<&2, V>}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      h.bool_none(V, U32.is_eq(o, hk), None{}, {==})

def h.get_leaf(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +n: Nat, +mask: U32, +o: U32,
  xs: List<&2, M.Entry<K, V>>, +hk: U32, +k: K
) -> {h.G(~K, ~V, ~eq, n, mask, M.HLeaf{o, xs}, hk, k)
      == h.G(~K, ~V, ~eq, n, mask, M.HMap.leaf(K, V, o, xs), hk, k) : Maybe<&2, V>}:
  match xs:
    case Nil{}:
      h.g_nil_leaf(~K, ~V, ~eq, n, mask, o, hk, k)
    case Con{e, rest}:
      {==}

def h.size_leaf(-K: Data, -V: Data, +o: U32, xs: List<&2, M.Entry<K, V>>)
  -> {h.len(K, V, xs) == h.Sz(K, V, M.HMap.leaf(K, V, o, xs)) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case Con{e, rest}:
      {==}

def h.get_join(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, lo: M.HMap<K, V>,
  hi: M.HMap<K, V>, +hk: U32, +k: K
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, M.HBranch{lo, hi}, hk, k)
      == h.G(~K, ~V, ~eq, 1n+p, mask, M.HMap.join(K, V, lo, hi), hk, k) : Maybe<&2, V>}:
  match lo:
    case M.HNil{}:
      match hi:
        case M.HNil{}:
          Equal.sym(Maybe<&2, V>, None{},
            M.HMap.bool(Maybe<&2, V>, U32.is_eq((hk .&. mask : U32), 0),
              u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), M.HNil{}, hk, k),
              u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), M.HNil{}, hk, k)),
            h.bnn(V, U32.is_eq((hk .&. mask : U32), 0),
              h.G(~K, ~V, ~eq, p, (mask << 1n : U32), M.HNil{}, hk, k),
              h.gnil(~K, ~V, ~eq, p, (mask << 1n : U32), hk, k)))
        case M.HLeaf{a, b}:
          {==}
        case M.HBranch{a, b}:
          {==}
    case M.HLeaf{a, b}:
      {==}
    case M.HBranch{a, b}:
      {==}

def h.size_join(-K: Data, -V: Data, lo: M.HMap<K, V>, hi: M.HMap<K, V>)
  -> {Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) == h.Sz(K, V, M.HMap.join(K, V, lo, hi)) : Nat}:
  match lo:
    case M.HNil{}:
      match hi:
        case M.HNil{}:
          {==}
        case M.HLeaf{a, b}:
          {==}
        case M.HBranch{a, b}:
          {==}
    case M.HLeaf{a, b}:
      {==}
    case M.HBranch{a, b}:
      {==}

def h.wf_nil(~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, n: Nat)
  -> {h.WF(~K, ~V, ~hash, ~eq, n, M.HNil{}) == True{} : Bool}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      {==}

def h.wf_leaf(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +n: Nat, +o: U32,
  xs: List<&2, M.Entry<K, V>>, w: {h.WF(~K, ~V, ~hash, ~eq, n, M.HLeaf{o, xs}) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, n, M.HMap.leaf(K, V, o, xs)) == True{} : Bool}:
  match xs:
    case Nil{}:
      h.wf_nil(~K, ~V, ~hash, ~eq, n)
    case Con{e, rest}:
      w

def h.wf_join(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +p: Nat, lo: M.HMap<K, V>,
  hi: M.HMap<K, V>, wl: {h.WF(~K, ~V, ~hash, ~eq, p, lo) == True{} : Bool},
  wh: {h.WF(~K, ~V, ~hash, ~eq, p, hi) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, 1n+p, M.HMap.join(K, V, lo, hi)) == True{} : Bool}:
  match lo:
    case M.HNil{}:
      match hi:
        case M.HNil{}:
          {==}
        case M.HLeaf{+a, +b}:
          and_i(h.WF(~K, ~V, ~hash, ~eq, p, M.HNil{}), h.WF(~K, ~V, ~hash, ~eq, p, M.HLeaf{a, b}), wl, wh)
        case M.HBranch{+a, +b}:
          and_i(h.WF(~K, ~V, ~hash, ~eq, p, M.HNil{}), h.WF(~K, ~V, ~hash, ~eq, p, M.HBranch{a, b}), wl, wh)
    case M.HLeaf{+a, +b}:
      and_i(h.WF(~K, ~V, ~hash, ~eq, p, M.HLeaf{a, b}), h.WF(~K, ~V, ~hash, ~eq, p, hi), wl, wh)
    case M.HBranch{+a, +b}:
      and_i(h.WF(~K, ~V, ~hash, ~eq, p, M.HBranch{a, b}), h.WF(~K, ~V, ~hash, ~eq, p, hi), wl, wh)

# get after put, same key.
def h.fresh_get(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  p: Nat, +mm: U32, +hk: U32, +k: K, +v: V
) -> {h.G(~K, ~V, ~eq, p, mm, M.HLeaf{hk, [M.Entry{k, v}]}, hk, k) == Some{v} : Maybe<&2, V>}:
  match p:
    case 0n:
      h.eg_put_same(~K, ~V, ~eq, ~refl, Nil{}, k, v)
    case 1n+q:
      %h.g_lf_t(~K, ~V, ~eq, q, mm, hk, [M.Entry{k, v}], hk, k, h.u_refl(hk)) : {_ == Some{v} : Maybe<&2, V>}
      h.eg_put_same(~K, ~V, ~eq, ~refl, Nil{}, k, v)

def h.split_same.b(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V, ob: {h.onebit(mask) == True{} : Bool},
  b1: Bool, b2: Bool,
  e1: {b1 == U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)) : Bool},
  e2: {b2 == U32.is_eq((o .&. mask : U32), 0) : Bool},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>},
  fr: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), M.HLeaf{hk, [M.Entry{k, v}]}, hk, k) == Some{v} : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.sp(~K, ~V, ~eq, b1, b2, p, mask, o, es, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>}:
  match b1 b2:
    case True{} True{}:
      %h.g_lo(~K, ~V, ~eq, p, mask, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v), M.HNil{}, hk, k,
        h.u_same0(o, hk, mask, True{},
          h.sb(True{}, U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)), e1),
          h.sb(True{}, U32.is_eq((o .&. mask : U32), 0), e2)))
        : {_ == Some{v} : Maybe<&2, V>}
      ih
    case True{} False{}:
      %h.g_hi(~K, ~V, ~eq, p, mask, M.HNil{}, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v), hk, k,
        h.u_same0(o, hk, mask, False{},
          h.sb(True{}, U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)), e1),
          h.sb(False{}, U32.is_eq((o .&. mask : U32), 0), e2)))
        : {_ == Some{v} : Maybe<&2, V>}
      ih
    case False{} True{}:
      %h.g_hi(~K, ~V, ~eq, p, mask, M.HLeaf{o, es}, M.HLeaf{hk, [M.Entry{k, v}]}, hk, k,
        h.u_ne0((o .&. mask : U32), (hk .&. mask : U32),
          h.sb(False{}, U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)), e1),
          h.sb(True{}, U32.is_eq((o .&. mask : U32), 0), e2)))
        : {_ == Some{v} : Maybe<&2, V>}
      fr
    case False{} False{}:
      %h.g_lo(~K, ~V, ~eq, p, mask, M.HLeaf{hk, [M.Entry{k, v}]}, M.HLeaf{o, es}, hk, k,
        h.u_route_t(o, hk, mask, ob,
          h.sb(False{}, U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)), e1),
          h.sb(False{}, U32.is_eq((o .&. mask : U32), 0), e2)))
        : {_ == Some{v} : Maybe<&2, V>}
      fr

def h.split_same(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  n: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V,
  +ob: {h.onebit(mask) == True{} : Bool}
) -> {h.G(~K, ~V, ~eq, n, mask, h.S(~K, ~V, ~eq, n, mask, o, es, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>}:
  match n:
    case 0n:
      h.eg_put_same(~K, ~V, ~eq, ~refl, es, k, v)
    case 1n+(+p):
      h.split_same.b(~K, ~V, ~eq, p, mask, o, es, hk, k, v, ob,
        U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)), U32.is_eq((o .&. mask : U32), 0), {==}, {==},
        h.split_same(~K, ~V, ~eq, ~refl, p, (mask << 1n : U32), o, es, hk, k, v, h.onebit_shl(mask, ob)),
        h.fresh_get(~K, ~V, ~eq, ~refl, p, (mask << 1n : U32), hk, k, v))

def h.gp_same.lf(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  +p: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V,
  b: Bool, eb: {b == U32.is_eq(o, hk) : Bool},
  sp: {h.G(~K, ~V, ~eq, 1n+p, mask, h.S(~K, ~V, ~eq, 1n+p, mask, o, es, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.pl(~K, ~V, ~eq, b, p, mask, o, es, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>}:
  match b:
    case True{}:
      %h.g_lf_t(~K, ~V, ~eq, p, mask, o, M.HMap.entries.put(~K, ~V, ~eq, es, k, v), hk, k,
        h.sb(True{}, U32.is_eq(o, hk), eb)) : {_ == Some{v} : Maybe<&2, V>}
      h.eg_put_same(~K, ~V, ~eq, ~refl, es, k, v)
    case False{}:
      sp

def h.gp_same.br(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, +v: V,
  b: Bool, eb: {b == U32.is_eq((hk .&. mask : U32), 0) : Bool},
  il: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.pb(~K, ~V, ~eq, b, p, mask, lo, hi, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>}:
  match b:
    case True{}:
      %h.g_lo(~K, ~V, ~eq, p, mask, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v), hi, hk, k,
        h.sb(True{}, U32.is_eq((hk .&. mask : U32), 0), eb)) : {_ == Some{v} : Maybe<&2, V>}
      il
    case False{}:
      %h.g_hi(~K, ~V, ~eq, p, mask, lo, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v), hk, k,
        h.sb(False{}, U32.is_eq((hk .&. mask : U32), 0), eb)) : {_ == Some{v} : Maybe<&2, V>}
      ih

def h.gp_same(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K, +v: V,
  +ob: {h.onebit(mask) == True{} : Bool}, +wf: {h.WF(~K, ~V, ~hash, ~eq, n, m) == True{} : Bool}
) -> {h.G(~K, ~V, ~eq, n, mask, h.P(~K, ~V, ~eq, n, mask, m, hk, k, v), hk, k) == Some{v} : Maybe<&2, V>}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          h.eg_put_same(~K, ~V, ~eq, ~refl, Nil{}, k, v)
        case M.HLeaf{o, es}:
          h.eg_put_same(~K, ~V, ~eq, ~refl, es, k, v)
        case M.HBranch{lo, hi}:
          exfalso({h.G(~K, ~V, ~eq, 0n, mask, M.HBranch{lo, hi}, hk, k) == Some{v} : Maybe<&2, V>}, absurd_b(wf))
    case 1n+(+p):
      match m:
        case M.HNil{}:
          %h.g_lf_t(~K, ~V, ~eq, p, mask, hk, [M.Entry{k, v}], hk, k, h.u_refl(hk)) : {_ == Some{v} : Maybe<&2, V>}
          h.eg_put_same(~K, ~V, ~eq, ~refl, Nil{}, k, v)
        case M.HLeaf{+o, +es}:
          h.gp_same.lf(~K, ~V, ~eq, ~refl, p, mask, o, es, hk, k, v, U32.is_eq(o, hk), {==},
            h.split_same(~K, ~V, ~eq, ~refl, 1n+p, mask, o, es, hk, k, v, ob))
        case M.HBranch{+lo, +hi}:
          h.gp_same.br(~K, ~V, ~eq, p, mask, lo, hi, hk, k, v, U32.is_eq((hk .&. mask : U32), 0), {==},
            h.gp_same(~K, ~V, ~hash, ~eq, ~refl, p, (mask << 1n : U32), lo, hk, k, v, h.onebit_shl(mask, ob),
              and_l(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf)),
            h.gp_same(~K, ~V, ~hash, ~eq, ~refl, p, (mask << 1n : U32), hi, hk, k, v, h.onebit_shl(mask, ob),
              and_r(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf)))

# get after put, other key.
def h.r_eg.c(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +o: U32, +es: List<&2, M.Entry<K, V>>, +k: K,
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  b: Bool, eb: {b == U32.is_eq(o, hash(k)) : Bool}
) -> {h.EG(~K, ~V, ~eq, es, k)
      == M.HMap.bool(Maybe<&2, V>, b, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) : Maybe<&2, V>}:
  match b:
    case True{}:
      {==}
    case False{}:
      h.eg_none_hashed(~K, ~V, ~hash, ~eq, ~sound, es, o, k, h.sb(False{}, U32.is_eq(o, hash(k)), eb), hs)

def h.r_eg(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +o: U32, +es: List<&2, M.Entry<K, V>>, +k: K,
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool}
) -> {h.EG(~K, ~V, ~eq, es, k) == h.R(~K, ~V, ~hash, ~eq, o, es, k) : Maybe<&2, V>}:
  h.r_eg.c(~K, ~V, ~hash, ~eq, ~sound, o, es, k, hs, U32.is_eq(o, hash(k)), {==})

def h.r_none(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +k: K, ne: {U32.is_eq(o, hash(k)) == False{} : Bool}
) -> {None{} == h.R(~K, ~V, ~hash, ~eq, o, es, k) : Maybe<&2, V>}:
  %h.sb(U32.is_eq(o, hash(k)), False{}, ne)
    : {None{} == M.HMap.bool(Maybe<&2, V>, _, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) : Maybe<&2, V>}
  {==}

def h.g_leaf_r(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  p: Nat, +mm: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +k: K,
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool}
) -> {h.G(~K, ~V, ~eq, p, mm, M.HLeaf{o, es}, hash(k), k) == h.R(~K, ~V, ~hash, ~eq, o, es, k) : Maybe<&2, V>}:
  match p:
    case 0n:
      h.r_eg(~K, ~V, ~hash, ~eq, ~sound, o, es, k, hs)
    case 1n+q:
      {==}

def h.g_fresh_none(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  p: Nat, +mm: U32, +h2: U32, +k2: K, +hk: U32, +k: K, +v: V, +nk: {eq(k, k2) == False{} : Bool}
) -> {h.G(~K, ~V, ~eq, p, mm, M.HLeaf{h2, [M.Entry{k2, v}]}, hk, k) == None{} : Maybe<&2, V>}:
  match p:
    case 0n:
      h.eg_put_other(~K, ~V, ~eq, ~sound, Nil{}, k2, k, v, nk)
    case 1n+q:
      h.bool_none(V, U32.is_eq(h2, hk), h.EG(~K, ~V, ~eq, [M.Entry{k2, v}], k),
        h.eg_put_other(~K, ~V, ~eq, ~sound, Nil{}, k2, k, v, nk))

def h.split_other.b(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +p: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +h2: U32, +k2: K, +k: K, +v: V,
  +hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  +nk: {eq(k, k2) == False{} : Bool},
  b1: Bool, b2: Bool,
  e2: {b2 == U32.is_eq((o .&. mask : U32), 0) : Bool},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, h2, k2, v), hash(k), k)
       == h.R(~K, ~V, ~hash, ~eq, o, es, k) : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.sp(~K, ~V, ~eq, b1, b2, p, mask, o, es, h2, k2, v), hash(k), k)
      == h.R(~K, ~V, ~hash, ~eq, o, es, k) : Maybe<&2, V>}:
  match b1 b2:
    case True{} True{}:
      +mm = (mask << 1n : U32)
      +d = U32.is_eq((hash(k) .&. mask : U32), 0)
      +sub = h.S(~K, ~V, ~eq, p, mm, o, es, h2, k2, v)
      +old = {M.HLeaf{o, es} : M.HMap<K, V>}
      +fresh = {M.HLeaf{h2, [M.Entry{k2, v}]} : M.HMap<K, V>}
      +r = h.R(~K, ~V, ~hash, ~eq, o, es, k)
      h.bsel(Maybe<&2, V>, d, h.G(~K, ~V, ~eq, p, mm, sub, hash(k), k),
        h.G(~K, ~V, ~eq, p, mm, M.HNil{}, hash(k), k), r,
        ed => ih,
        ed => Equal.trans(Maybe<&2, V>, h.G(~K, ~V, ~eq, p, mm, M.HNil{}, hash(k), k), None{}, r,
          h.gnil(~K, ~V, ~eq, p, mm, hash(k), k),
          h.r_none(~K, ~V, ~hash, ~eq, o, es, k,
            h.u_diff(o, hash(k), mask, True{}, h.sb(True{}, U32.is_eq((o .&. mask : U32), 0), e2), ed))))
    case True{} False{}:
      +mm = (mask << 1n : U32)
      +d = U32.is_eq((hash(k) .&. mask : U32), 0)
      +sub = h.S(~K, ~V, ~eq, p, mm, o, es, h2, k2, v)
      +old = {M.HLeaf{o, es} : M.HMap<K, V>}
      +fresh = {M.HLeaf{h2, [M.Entry{k2, v}]} : M.HMap<K, V>}
      +r = h.R(~K, ~V, ~hash, ~eq, o, es, k)
      h.bsel(Maybe<&2, V>, d, h.G(~K, ~V, ~eq, p, mm, M.HNil{}, hash(k), k),
        h.G(~K, ~V, ~eq, p, mm, sub, hash(k), k), r,
        ed => Equal.trans(Maybe<&2, V>, h.G(~K, ~V, ~eq, p, mm, M.HNil{}, hash(k), k), None{}, r,
          h.gnil(~K, ~V, ~eq, p, mm, hash(k), k),
          h.r_none(~K, ~V, ~hash, ~eq, o, es, k,
            h.u_diff(o, hash(k), mask, False{}, h.sb(False{}, U32.is_eq((o .&. mask : U32), 0), e2), ed))),
        ed => ih)
    case False{} True{}:
      +mm = (mask << 1n : U32)
      +d = U32.is_eq((hash(k) .&. mask : U32), 0)
      +sub = h.S(~K, ~V, ~eq, p, mm, o, es, h2, k2, v)
      +old = {M.HLeaf{o, es} : M.HMap<K, V>}
      +fresh = {M.HLeaf{h2, [M.Entry{k2, v}]} : M.HMap<K, V>}
      +r = h.R(~K, ~V, ~hash, ~eq, o, es, k)
      h.bsel(Maybe<&2, V>, d, h.G(~K, ~V, ~eq, p, mm, old, hash(k), k),
        h.G(~K, ~V, ~eq, p, mm, fresh, hash(k), k), r,
        ed => h.g_leaf_r(~K, ~V, ~hash, ~eq, ~sound, p, mm, o, es, k, hs),
        ed => Equal.trans(Maybe<&2, V>, h.G(~K, ~V, ~eq, p, mm, fresh, hash(k), k), None{}, r,
          h.g_fresh_none(~K, ~V, ~eq, ~sound, p, mm, h2, k2, hash(k), k, v, nk),
          h.r_none(~K, ~V, ~hash, ~eq, o, es, k,
            h.u_diff(o, hash(k), mask, True{}, h.sb(True{}, U32.is_eq((o .&. mask : U32), 0), e2), ed))))
    case False{} False{}:
      +mm = (mask << 1n : U32)
      +d = U32.is_eq((hash(k) .&. mask : U32), 0)
      +sub = h.S(~K, ~V, ~eq, p, mm, o, es, h2, k2, v)
      +old = {M.HLeaf{o, es} : M.HMap<K, V>}
      +fresh = {M.HLeaf{h2, [M.Entry{k2, v}]} : M.HMap<K, V>}
      +r = h.R(~K, ~V, ~hash, ~eq, o, es, k)
      h.bsel(Maybe<&2, V>, d, h.G(~K, ~V, ~eq, p, mm, fresh, hash(k), k),
        h.G(~K, ~V, ~eq, p, mm, old, hash(k), k), r,
        ed => Equal.trans(Maybe<&2, V>, h.G(~K, ~V, ~eq, p, mm, fresh, hash(k), k), None{}, r,
          h.g_fresh_none(~K, ~V, ~eq, ~sound, p, mm, h2, k2, hash(k), k, v, nk),
          h.r_none(~K, ~V, ~hash, ~eq, o, es, k,
            h.u_diff(o, hash(k), mask, False{}, h.sb(False{}, U32.is_eq((o .&. mask : U32), 0), e2), ed))),
        ed => h.g_leaf_r(~K, ~V, ~hash, ~eq, ~sound, p, mm, o, es, k, hs))

def h.split_other(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  n: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +h2: U32, +k2: K, +k: K, +v: V,
  +hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  +nk: {eq(k, k2) == False{} : Bool}
) -> {h.G(~K, ~V, ~eq, n, mask, h.S(~K, ~V, ~eq, n, mask, o, es, h2, k2, v), hash(k), k)
      == h.R(~K, ~V, ~hash, ~eq, o, es, k) : Maybe<&2, V>}:
  match n:
    case 0n:
      Equal.trans(Maybe<&2, V>, h.EG(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, es, k2, v), k),
        h.EG(~K, ~V, ~eq, es, k), h.R(~K, ~V, ~hash, ~eq, o, es, k),
        h.eg_put_other(~K, ~V, ~eq, ~sound, es, k2, k, v, nk),
        h.r_eg(~K, ~V, ~hash, ~eq, ~sound, o, es, k, hs))
    case 1n+(+p):
      h.split_other.b(~K, ~V, ~hash, ~eq, ~sound, p, mask, o, es, h2, k2, k, v, hs, nk,
        U32.is_eq((o .&. mask : U32), (h2 .&. mask : U32)), U32.is_eq((o .&. mask : U32), 0), {==},
        h.split_other(~K, ~V, ~hash, ~eq, ~sound, p, (mask << 1n : U32), o, es, h2, k2, k, v, hs, nk))

def h.gp_other.lf(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +p: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +h2: U32, +k2: K, +k: K, +v: V,
  +nk: {eq(k, k2) == False{} : Bool}, b: Bool,
  sp: {h.G(~K, ~V, ~eq, 1n+p, mask, h.S(~K, ~V, ~eq, 1n+p, mask, o, es, h2, k2, v), hash(k), k)
       == h.G(~K, ~V, ~eq, 1n+p, mask, M.HLeaf{o, es}, hash(k), k) : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.pl(~K, ~V, ~eq, b, p, mask, o, es, h2, k2, v), hash(k), k)
      == h.G(~K, ~V, ~eq, 1n+p, mask, M.HLeaf{o, es}, hash(k), k) : Maybe<&2, V>}:
  match b:
    case True{}:
      h.bool_l(Maybe<&2, V>, U32.is_eq(o, hash(k)),
        h.EG(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, es, k2, v), k), h.EG(~K, ~V, ~eq, es, k), None{},
        h.eg_put_other(~K, ~V, ~eq, ~sound, es, k2, k, v, nk))
    case False{}:
      sp

def h.gp_other.br(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +h2: U32, +k2: K, +hk: U32, +k: K, +v: V, b: Bool,
  il: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, h2, k2, v), hk, k)
       == h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k) : Maybe<&2, V>},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, h2, k2, v), hk, k)
       == h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k) : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.pb(~K, ~V, ~eq, b, p, mask, lo, hi, h2, k2, v), hk, k)
      == h.G(~K, ~V, ~eq, 1n+p, mask, M.HBranch{lo, hi}, hk, k) : Maybe<&2, V>}:
  match b:
    case True{}:
      h.bool_l(Maybe<&2, V>, U32.is_eq((hk .&. mask : U32), 0),
        h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, h2, k2, v), hk, k),
        h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
        h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k), il)
    case False{}:
      h.bool_r(Maybe<&2, V>, U32.is_eq((hk .&. mask : U32), 0),
        h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
        h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, h2, k2, v), hk, k),
        h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k), ih)

def h.gp_other(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  n: Nat, +mask: U32, m: M.HMap<K, V>, +h2: U32, +k2: K, +k: K, +v: V,
  +wf: {h.WF(~K, ~V, ~hash, ~eq, n, m) == True{} : Bool}, +nk: {eq(k, k2) == False{} : Bool}
) -> {h.G(~K, ~V, ~eq, n, mask, h.P(~K, ~V, ~eq, n, mask, m, h2, k2, v), hash(k), k)
      == h.G(~K, ~V, ~eq, n, mask, m, hash(k), k) : Maybe<&2, V>}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          h.eg_put_other(~K, ~V, ~eq, ~sound, Nil{}, k2, k, v, nk)
        case M.HLeaf{o, es}:
          h.eg_put_other(~K, ~V, ~eq, ~sound, es, k2, k, v, nk)
        case M.HBranch{lo, hi}:
          {==}
    case 1n+(+p):
      match m:
        case M.HNil{}:
          h.bool_none(V, U32.is_eq(h2, hash(k)), h.EG(~K, ~V, ~eq, [M.Entry{k2, v}], k),
            h.eg_put_other(~K, ~V, ~eq, ~sound, Nil{}, k2, k, v, nk))
        case M.HLeaf{+o, +es}:
          h.gp_other.lf(~K, ~V, ~hash, ~eq, ~sound, p, mask, o, es, h2, k2, k, v, nk, U32.is_eq(o, h2),
            h.split_other(~K, ~V, ~hash, ~eq, ~sound, 1n+p, mask, o, es, h2, k2, k, v,
              and_l(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf), nk))
        case M.HBranch{+lo, +hi}:
          h.gp_other.br(~K, ~V, ~eq, p, mask, lo, hi, h2, k2, hash(k), k, v, U32.is_eq((h2 .&. mask : U32), 0),
            h.gp_other(~K, ~V, ~hash, ~eq, ~sound, p, (mask << 1n : U32), lo, h2, k2, k, v,
              and_l(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf), nk),
            h.gp_other(~K, ~V, ~hash, ~eq, ~sound, p, (mask << 1n : U32), hi, h2, k2, k, v,
              and_r(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf), nk))

# get after del.
def h.gd_same.lf(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, b: Bool, eb: {b == U32.is_eq(o, hk) : Bool},
  ed: {h.EG(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, es, k), k) == None{} : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.dl(~K, ~V, ~eq, b, o, es, k), hk, k) == None{} : Maybe<&2, V>}:
  match b:
    case True{}:
      %h.get_leaf(~K, ~V, ~eq, 1n+p, mask, o, M.HMap.entries.del(~K, ~V, ~eq, es, k), hk, k) : {_ == None{} : Maybe<&2, V>}
      h.bool_none(V, U32.is_eq(o, hk), h.EG(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, es, k), k), ed)
    case False{}:
      %eb : {M.HMap.bool(Maybe<&2, V>, _, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == None{} : Maybe<&2, V>}
      {==}

def h.gd_same.br(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, b: Bool, eb: {b == U32.is_eq((hk .&. mask : U32), 0) : Bool},
  il: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k), hk, k) == None{} : Maybe<&2, V>},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k), hk, k) == None{} : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.db(~K, ~V, ~eq, b, p, mask, lo, hi, hk, k), hk, k) == None{} : Maybe<&2, V>}:
  match b:
    case True{}:
      +dlo = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)
      +dhi = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)
      %h.get_join(~K, ~V, ~eq, p, mask, dlo, hi, hk, k) : {_ == None{} : Maybe<&2, V>}
      %h.g_lo(~K, ~V, ~eq, p, mask, dlo, hi, hk, k, h.sb(True{}, U32.is_eq((hk .&. mask : U32), 0), eb))
        : {_ == None{} : Maybe<&2, V>}
      il
    case False{}:
      +dlo = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)
      +dhi = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)
      %h.get_join(~K, ~V, ~eq, p, mask, lo, dhi, hk, k) : {_ == None{} : Maybe<&2, V>}
      %h.g_hi(~K, ~V, ~eq, p, mask, lo, dhi, hk, k, h.sb(False{}, U32.is_eq((hk .&. mask : U32), 0), eb))
        : {_ == None{} : Maybe<&2, V>}
      ih

def h.gd_same(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K,
  +wf: {h.WF(~K, ~V, ~hash, ~eq, n, m) == True{} : Bool}
) -> {h.G(~K, ~V, ~eq, n, mask, h.D(~K, ~V, ~eq, n, mask, m, hk, k), hk, k) == None{} : Maybe<&2, V>}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          %h.get_leaf(~K, ~V, ~eq, 0n, mask, o, M.HMap.entries.del(~K, ~V, ~eq, es, k), hk, k) : {_ == None{} : Maybe<&2, V>}
          h.eg_del_same(~K, ~V, ~eq, ~sound, es, k, wf)
        case M.HBranch{lo, hi}:
          {==}
    case 1n+(+p):
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          h.gd_same.lf(~K, ~V, ~eq, p, mask, o, es, hk, k, U32.is_eq(o, hk), {==},
            h.eg_del_same(~K, ~V, ~eq, ~sound, es, k,
              and_r(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf)))
        case M.HBranch{+lo, +hi}:
          h.gd_same.br(~K, ~V, ~eq, p, mask, lo, hi, hk, k, U32.is_eq((hk .&. mask : U32), 0), {==},
            h.gd_same(~K, ~V, ~hash, ~eq, ~sound, p, (mask << 1n : U32), lo, hk, k,
              and_l(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf)),
            h.gd_same(~K, ~V, ~hash, ~eq, ~sound, p, (mask << 1n : U32), hi, hk, k,
              and_r(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf)))

def h.gd_other.lf(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +p: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +k2: K, +hk: U32, +k: K,
  +nk: {eq(k, k2) == False{} : Bool}, b: Bool
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.dl(~K, ~V, ~eq, b, o, es, k2), hk, k)
      == h.G(~K, ~V, ~eq, 1n+p, mask, M.HLeaf{o, es}, hk, k) : Maybe<&2, V>}:
  match b:
    case True{}:
      %h.get_leaf(~K, ~V, ~eq, 1n+p, mask, o, M.HMap.entries.del(~K, ~V, ~eq, es, k2), hk, k)
        : {_ == h.G(~K, ~V, ~eq, 1n+p, mask, M.HLeaf{o, es}, hk, k) : Maybe<&2, V>}
      h.bool_l(Maybe<&2, V>, U32.is_eq(o, hk),
        h.EG(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, es, k2), k), h.EG(~K, ~V, ~eq, es, k), None{},
        h.eg_del_other(~K, ~V, ~eq, ~sound, es, k2, k, nk))
    case False{}:
      {==}

def h.gd_other.br(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +h2: U32, +k2: K, +hk: U32, +k: K, b: Bool,
  il: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, h2, k2), hk, k)
       == h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k) : Maybe<&2, V>},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, h2, k2), hk, k)
       == h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k) : Maybe<&2, V>}
) -> {h.G(~K, ~V, ~eq, 1n+p, mask, h.db(~K, ~V, ~eq, b, p, mask, lo, hi, h2, k2), hk, k)
      == h.G(~K, ~V, ~eq, 1n+p, mask, M.HBranch{lo, hi}, hk, k) : Maybe<&2, V>}:
  match b:
    case True{}:
      +dlo = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, h2, k2)
      +dhi = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, h2, k2)
      +d = U32.is_eq((hk .&. mask : U32), 0)
      %h.get_join(~K, ~V, ~eq, p, mask, dlo, hi, hk, k)
        : {_ == h.G(~K, ~V, ~eq, 1n+p, mask, M.HBranch{lo, hi}, hk, k) : Maybe<&2, V>}
      h.bool_l(Maybe<&2, V>, d, h.G(~K, ~V, ~eq, p, (mask << 1n : U32), dlo, hk, k),
        h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k), h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k), il)
    case False{}:
      +dlo = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, h2, k2)
      +dhi = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, h2, k2)
      +d = U32.is_eq((hk .&. mask : U32), 0)
      %h.get_join(~K, ~V, ~eq, p, mask, lo, dhi, hk, k)
        : {_ == h.G(~K, ~V, ~eq, 1n+p, mask, M.HBranch{lo, hi}, hk, k) : Maybe<&2, V>}
      h.bool_r(Maybe<&2, V>, d, h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
        h.G(~K, ~V, ~eq, p, (mask << 1n : U32), dhi, hk, k), h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k), ih)

def h.gd_other(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  n: Nat, +mask: U32, m: M.HMap<K, V>, +h2: U32, +k2: K, +hk: U32, +k: K,
  +nk: {eq(k, k2) == False{} : Bool}
) -> {h.G(~K, ~V, ~eq, n, mask, h.D(~K, ~V, ~eq, n, mask, m, h2, k2), hk, k)
      == h.G(~K, ~V, ~eq, n, mask, m, hk, k) : Maybe<&2, V>}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          %h.get_leaf(~K, ~V, ~eq, 0n, mask, o, M.HMap.entries.del(~K, ~V, ~eq, es, k2), hk, k)
            : {_ == h.EG(~K, ~V, ~eq, es, k) : Maybe<&2, V>}
          h.eg_del_other(~K, ~V, ~eq, ~sound, es, k2, k, nk)
        case M.HBranch{lo, hi}:
          {==}
    case 1n+(+p):
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          h.gd_other.lf(~K, ~V, ~eq, ~sound, p, mask, o, es, k2, hk, k, nk, U32.is_eq(o, h2))
        case M.HBranch{+lo, +hi}:
          h.gd_other.br(~K, ~V, ~eq, p, mask, lo, hi, h2, k2, hk, k, U32.is_eq((h2 .&. mask : U32), 0),
            h.gd_other(~K, ~V, ~eq, ~sound, p, (mask << 1n : U32), lo, h2, k2, hk, k, nk),
            h.gd_other(~K, ~V, ~eq, ~sound, p, (mask << 1n : U32), hi, h2, k2, hk, k, nk))


# size after put and del.
def h.split_size.b(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V, b1: Bool, b2: Bool,
  ih: {h.Sz(K, V, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v)) == 1n+h.len(K, V, es) : Nat}
) -> {h.Sz(K, V, h.sp(~K, ~V, ~eq, b1, b2, p, mask, o, es, hk, k, v)) == 1n+h.len(K, V, es) : Nat}:
  match b1 b2:
    case True{} True{}:
      Ord.tr(Nat.add(h.Sz(K, V, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v)), 0n),
        h.Sz(K, V, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v)), 1n+h.len(K, V, es),
        Ord.add_zero_right(h.Sz(K, V, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v))), ih)
    case True{} False{}:
      ih
    case False{} True{}:
      Ord.tr(Nat.add(h.len(K, V, es), 1n), 1n+Nat.add(h.len(K, V, es), 0n), 1n+h.len(K, V, es),
        Ord.add_succ_right(h.len(K, V, es), 0n),
        Equal.cong(Nat, Nat, x => 1n+x, Nat.add(h.len(K, V, es), 0n), h.len(K, V, es),
          Ord.add_zero_right(h.len(K, V, es))))
    case False{} False{}:
      {==}

def h.split_size(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, n: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V,
  +miss: {h.EG(~K, ~V, ~eq, es, k) == None{} : Maybe<&2, V>}
) -> {h.Sz(K, V, h.S(~K, ~V, ~eq, n, mask, o, es, hk, k, v)) == 1n+h.len(K, V, es) : Nat}:
  match n:
    case 0n:
      h.elen_put_new(~K, ~V, ~eq, es, k, v, miss)
    case 1n+(+p):
      h.split_size.b(~K, ~V, ~eq, p, mask, o, es, hk, k, v,
        U32.is_eq((o .&. mask : U32), (hk .&. mask : U32)), U32.is_eq((o .&. mask : U32), 0),
        h.split_size(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hk, k, v, miss))

def h.sz_put_new.lf(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +p: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +k: K, +v: V,
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  b: Bool, eb: {b == U32.is_eq(o, hash(k)) : Bool},
  miss: {h.R(~K, ~V, ~hash, ~eq, o, es, k) == None{} : Maybe<&2, V>}
) -> {h.Sz(K, V, h.pl(~K, ~V, ~eq, b, p, mask, o, es, hash(k), k, v)) == 1n+h.len(K, V, es) : Nat}:
  match b:
    case True{}:
      h.elen_put_new(~K, ~V, ~eq, es, k, v,
        rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == None{} : Maybe<&2, V>},
          True{}, U32.is_eq(o, hash(k)), eb, miss))
    case False{}:
      h.split_size(~K, ~V, ~eq, 1n+p, mask, o, es, hash(k), k, v,
        h.eg_none_hashed(~K, ~V, ~hash, ~eq, ~sound, es, o, k, h.sb(False{}, U32.is_eq(o, hash(k)), eb), hs))

def h.sz_put_new.br(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, +v: V, b: Bool, eb: {b == U32.is_eq((hk .&. mask : U32), 0) : Bool},
  miss: {M.HMap.bool(Maybe<&2, V>, U32.is_eq((hk .&. mask : U32), 0),
    u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
    u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == None{} : Maybe<&2, V>},
  il: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k) == None{} : Maybe<&2, V>}
    -> {h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v)) == 1n+h.Sz(K, V, lo) : Nat},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k) == None{} : Maybe<&2, V>}
    -> {h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v)) == 1n+h.Sz(K, V, hi) : Nat}
) -> {h.Sz(K, V, h.pb(~K, ~V, ~eq, b, p, mask, lo, hi, hk, k, v))
      == 1n+Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}:
  match b:
    case True{}:
      Ord.cong_add(h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v)), 1n+h.Sz(K, V, lo),
        h.Sz(K, V, hi), h.Sz(K, V, hi),
        il(rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z,
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == None{} : Maybe<&2, V>},
          True{}, U32.is_eq((hk .&. mask : U32), 0), eb, miss)),
        {==})
    case False{}:
      Ord.tr(Nat.add(h.Sz(K, V, lo), h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v))),
        Nat.add(h.Sz(K, V, lo), 1n+h.Sz(K, V, hi)), 1n+Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)),
        Ord.cong_add(h.Sz(K, V, lo), h.Sz(K, V, lo),
          h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v)), 1n+h.Sz(K, V, hi), {==},
          ih(rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z,
              u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
              u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == None{} : Maybe<&2, V>},
            False{}, U32.is_eq((hk .&. mask : U32), 0), eb, miss))),
        Ord.add_succ_right(h.Sz(K, V, lo), h.Sz(K, V, hi)))

def h.sz_put_new(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  n: Nat, +mask: U32, m: M.HMap<K, V>, +k: K, +v: V,
  +wf: {h.WF(~K, ~V, ~hash, ~eq, n, m) == True{} : Bool},
  miss: {h.G(~K, ~V, ~eq, n, mask, m, hash(k), k) == None{} : Maybe<&2, V>}
) -> {h.Sz(K, V, h.P(~K, ~V, ~eq, n, mask, m, hash(k), k, v)) == 1n+h.Sz(K, V, m) : Nat}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{o, es}:
          h.elen_put_new(~K, ~V, ~eq, es, k, v, miss)
        case M.HBranch{lo, hi}:
          exfalso({h.Sz(K, V, M.HBranch{lo, hi}) == 1n+h.Sz(K, V, M.HBranch{lo, hi}) : Nat}, absurd_b(wf))
    case 1n+(+p):
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          h.sz_put_new.lf(~K, ~V, ~hash, ~eq, ~sound, p, mask, o, es, k, v,
            and_l(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf),
            U32.is_eq(o, hash(k)), {==}, miss)
        case M.HBranch{+lo, +hi}:
          h.sz_put_new.br(~K, ~V, ~eq, p, mask, lo, hi, hash(k), k, v, U32.is_eq((hash(k) .&. mask : U32), 0), {==},
            miss,
            e => h.sz_put_new(~K, ~V, ~hash, ~eq, ~sound, p, (mask << 1n : U32), lo, k, v,
              and_l(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf), e),
            e => h.sz_put_new(~K, ~V, ~hash, ~eq, ~sound, p, (mask << 1n : U32), hi, k, v,
              and_r(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf), e))

def h.sz_put_hit.lf(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, +v: V, -w: V,
  b: Bool, eb: {b == U32.is_eq(o, hk) : Bool},
  hit: {M.HMap.bool(Maybe<&2, V>, U32.is_eq(o, hk), u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == Some{w} : Maybe<&2, V>}
) -> {h.Sz(K, V, h.pl(~K, ~V, ~eq, b, p, mask, o, es, hk, k, v)) == h.len(K, V, es) : Nat}:
  match b:
    case True{}:
      h.elen_put_hit(~K, ~V, ~eq, es, k, v, w,
        rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == Some{w} : Maybe<&2, V>},
          True{}, U32.is_eq(o, hk), eb, hit))
    case False{}:
      h.none_some({h.Sz(K, V, h.S(~K, ~V, ~eq, 1n+p, mask, o, es, hk, k, v)) == h.len(K, V, es) : Nat}, V, w,
        rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == Some{w} : Maybe<&2, V>},
          False{}, U32.is_eq(o, hk), eb, hit))

def h.sz_put_hit.br(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, +v: V, -w: V, b: Bool, eb: {b == U32.is_eq((hk .&. mask : U32), 0) : Bool},
  hit: {M.HMap.bool(Maybe<&2, V>, U32.is_eq((hk .&. mask : U32), 0),
    u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
    u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == Some{w} : Maybe<&2, V>},
  il: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k) == Some{w} : Maybe<&2, V>}
    -> {h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v)) == h.Sz(K, V, lo) : Nat},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k) == Some{w} : Maybe<&2, V>}
    -> {h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v)) == h.Sz(K, V, hi) : Nat}
) -> {h.Sz(K, V, h.pb(~K, ~V, ~eq, b, p, mask, lo, hi, hk, k, v))
      == Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}:
  match b:
    case True{}:
      Ord.cong_add(h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v)), h.Sz(K, V, lo),
        h.Sz(K, V, hi), h.Sz(K, V, hi),
        il(rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z,
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == Some{w} : Maybe<&2, V>},
          True{}, U32.is_eq((hk .&. mask : U32), 0), eb, hit)),
        {==})
    case False{}:
      Ord.cong_add(h.Sz(K, V, lo), h.Sz(K, V, lo),
        h.Sz(K, V, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v)), h.Sz(K, V, hi), {==},
        ih(rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z,
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == Some{w} : Maybe<&2, V>},
          False{}, U32.is_eq((hk .&. mask : U32), 0), eb, hit)))

def h.sz_put_hit(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K, +v: V, -w: V,
  hit: {h.G(~K, ~V, ~eq, n, mask, m, hk, k) == Some{w} : Maybe<&2, V>}
) -> {h.Sz(K, V, h.P(~K, ~V, ~eq, n, mask, m, hk, k, v)) == h.Sz(K, V, m) : Nat}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          h.none_some({h.Sz(K, V, M.HLeaf{hk, [M.Entry{k, v}]}) == 0n : Nat}, V, w, hit)
        case M.HLeaf{o, es}:
          h.elen_put_hit(~K, ~V, ~eq, es, k, v, w, hit)
        case M.HBranch{lo, hi}:
          {==}
    case 1n+(+p):
      match m:
        case M.HNil{}:
          h.none_some({h.Sz(K, V, M.HLeaf{hk, [M.Entry{k, v}]}) == 0n : Nat}, V, w, hit)
        case M.HLeaf{+o, +es}:
          h.sz_put_hit.lf(~K, ~V, ~eq, p, mask, o, es, hk, k, v, w, U32.is_eq(o, hk), {==}, hit)
        case M.HBranch{+lo, +hi}:
          h.sz_put_hit.br(~K, ~V, ~eq, p, mask, lo, hi, hk, k, v, w, U32.is_eq((hk .&. mask : U32), 0), {==}, hit,
            e => h.sz_put_hit(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v, w, e),
            e => h.sz_put_hit(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v, w, e))

def h.sz_del_hit.lf(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K, -w: V,
  b: Bool, eb: {b == U32.is_eq(o, hk) : Bool},
  hit: {M.HMap.bool(Maybe<&2, V>, U32.is_eq(o, hk), u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == Some{w} : Maybe<&2, V>}
) -> {1n+h.Sz(K, V, h.dl(~K, ~V, ~eq, b, o, es, k)) == h.len(K, V, es) : Nat}:
  match b:
    case True{}:
      %h.size_leaf(K, V, o, M.HMap.entries.del(~K, ~V, ~eq, es, k)) : {1n+_ == h.len(K, V, es) : Nat}
      h.elen_del_hit(~K, ~V, ~eq, es, k, w,
        rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == Some{w} : Maybe<&2, V>},
          True{}, U32.is_eq(o, hk), eb, hit))
    case False{}:
      h.none_some({1n+h.len(K, V, es) == h.len(K, V, es) : Nat}, V, w,
        rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == Some{w} : Maybe<&2, V>},
          False{}, U32.is_eq(o, hk), eb, hit))

def h.sz_del_hit.br(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, -w: V, b: Bool, eb: {b == U32.is_eq((hk .&. mask : U32), 0) : Bool},
  hit: {M.HMap.bool(Maybe<&2, V>, U32.is_eq((hk .&. mask : U32), 0),
    u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
    u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == Some{w} : Maybe<&2, V>},
  il: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k) == Some{w} : Maybe<&2, V>}
    -> {1n+h.Sz(K, V, h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)) == h.Sz(K, V, lo) : Nat},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k) == Some{w} : Maybe<&2, V>}
    -> {1n+h.Sz(K, V, h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == h.Sz(K, V, hi) : Nat}
) -> {1n+h.Sz(K, V, h.db(~K, ~V, ~eq, b, p, mask, lo, hi, hk, k))
      == Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}:
  match b:
    case True{}:
      +dlo = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)
      %h.size_join(K, V, dlo, hi) : {1n+_ == Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}
      Ord.cong_add(1n+h.Sz(K, V, dlo), h.Sz(K, V, lo), h.Sz(K, V, hi), h.Sz(K, V, hi),
        il(rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z,
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == Some{w} : Maybe<&2, V>},
          True{}, U32.is_eq((hk .&. mask : U32), 0), eb, hit)),
        {==})
    case False{}:
      +dhi = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)
      %h.size_join(K, V, lo, dhi) : {1n+_ == Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}
      %Ord.add_succ_right(h.Sz(K, V, lo), h.Sz(K, V, dhi)) : {_ == Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}
      Ord.cong_add(h.Sz(K, V, lo), h.Sz(K, V, lo), 1n+h.Sz(K, V, dhi), h.Sz(K, V, hi), {==},
        ih(rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z,
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == Some{w} : Maybe<&2, V>},
          False{}, U32.is_eq((hk .&. mask : U32), 0), eb, hit)))

def h.sz_del_hit(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K, -w: V,
  hit: {h.G(~K, ~V, ~eq, n, mask, m, hk, k) == Some{w} : Maybe<&2, V>}
) -> {1n+h.Sz(K, V, h.D(~K, ~V, ~eq, n, mask, m, hk, k)) == h.Sz(K, V, m) : Nat}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          h.none_some({1n == 0n : Nat}, V, w, hit)
        case M.HLeaf{+o, +es}:
          %h.size_leaf(K, V, o, M.HMap.entries.del(~K, ~V, ~eq, es, k)) : {1n+_ == h.len(K, V, es) : Nat}
          h.elen_del_hit(~K, ~V, ~eq, es, k, w, hit)
        case M.HBranch{+lo, +hi}:
          h.none_some({1n+h.Sz(K, V, M.HBranch{lo, hi}) == h.Sz(K, V, M.HBranch{lo, hi}) : Nat}, V, w, hit)
    case 1n+(+p):
      match m:
        case M.HNil{}:
          h.none_some({1n == 0n : Nat}, V, w, hit)
        case M.HLeaf{+o, +es}:
          h.sz_del_hit.lf(~K, ~V, ~eq, o, es, hk, k, w, U32.is_eq(o, hk), {==}, hit)
        case M.HBranch{+lo, +hi}:
          h.sz_del_hit.br(~K, ~V, ~eq, p, mask, lo, hi, hk, k, w, U32.is_eq((hk .&. mask : U32), 0), {==}, hit,
            e => h.sz_del_hit(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, w, e),
            e => h.sz_del_hit(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, w, e))

def h.sz_del_miss.lf(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +hk: U32, +k: K,
  b: Bool, eb: {b == U32.is_eq(o, hk) : Bool},
  miss: {M.HMap.bool(Maybe<&2, V>, U32.is_eq(o, hk), u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == None{} : Maybe<&2, V>}
) -> {h.Sz(K, V, h.dl(~K, ~V, ~eq, b, o, es, k)) == h.len(K, V, es) : Nat}:
  match b:
    case True{}:
      %h.size_leaf(K, V, o, M.HMap.entries.del(~K, ~V, ~eq, es, k)) : {_ == h.len(K, V, es) : Nat}
      Equal.cong(List<&2, M.Entry<K, V>>, Nat, xs => h.len(K, V, xs), M.HMap.entries.del(~K, ~V, ~eq, es, k), es,
        h.edel_miss(~K, ~V, ~eq, es, k,
          rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z, u => h.EG(~K, ~V, ~eq, es, k), u => None{}) == None{} : Maybe<&2, V>},
            True{}, U32.is_eq(o, hk), eb, miss)))
    case False{}:
      {==}

def h.sz_del_miss.br(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, b: Bool, eb: {b == U32.is_eq((hk .&. mask : U32), 0) : Bool},
  miss: {M.HMap.bool(Maybe<&2, V>, U32.is_eq((hk .&. mask : U32), 0),
    u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
    u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == None{} : Maybe<&2, V>},
  il: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k) == None{} : Maybe<&2, V>}
    -> {h.Sz(K, V, h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)) == h.Sz(K, V, lo) : Nat},
  ih: {h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k) == None{} : Maybe<&2, V>}
    -> {h.Sz(K, V, h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == h.Sz(K, V, hi) : Nat}
) -> {h.Sz(K, V, h.db(~K, ~V, ~eq, b, p, mask, lo, hi, hk, k))
      == Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}:
  match b:
    case True{}:
      +dlo = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)
      %h.size_join(K, V, dlo, hi) : {_ == Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}
      Ord.cong_add(h.Sz(K, V, dlo), h.Sz(K, V, lo), h.Sz(K, V, hi), h.Sz(K, V, hi),
        il(rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z,
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == None{} : Maybe<&2, V>},
          True{}, U32.is_eq((hk .&. mask : U32), 0), eb, miss)),
        {==})
    case False{}:
      +dhi = h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)
      %h.size_join(K, V, lo, dhi) : {_ == Nat.add(h.Sz(K, V, lo), h.Sz(K, V, hi)) : Nat}
      Ord.cong_add(h.Sz(K, V, lo), h.Sz(K, V, lo), h.Sz(K, V, dhi), h.Sz(K, V, hi), {==},
        ih(rw(Bool, z => {M.HMap.bool(Maybe<&2, V>, z,
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k),
            u => h.G(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == None{} : Maybe<&2, V>},
          False{}, U32.is_eq((hk .&. mask : U32), 0), eb, miss)))

def h.sz_del_miss(
  ~K: Data, ~V: Data, ~eq: K -> K -> Bool, n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K,
  miss: {h.G(~K, ~V, ~eq, n, mask, m, hk, k) == None{} : Maybe<&2, V>}
) -> {h.Sz(K, V, h.D(~K, ~V, ~eq, n, mask, m, hk, k)) == h.Sz(K, V, m) : Nat}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          %h.size_leaf(K, V, o, M.HMap.entries.del(~K, ~V, ~eq, es, k)) : {_ == h.len(K, V, es) : Nat}
          Equal.cong(List<&2, M.Entry<K, V>>, Nat, xs => h.len(K, V, xs), M.HMap.entries.del(~K, ~V, ~eq, es, k), es,
            h.edel_miss(~K, ~V, ~eq, es, k, miss))
        case M.HBranch{lo, hi}:
          {==}
    case 1n+(+p):
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          h.sz_del_miss.lf(~K, ~V, ~eq, o, es, hk, k, U32.is_eq(o, hk), {==}, miss)
        case M.HBranch{+lo, +hi}:
          h.sz_del_miss.br(~K, ~V, ~eq, p, mask, lo, hi, hk, k, U32.is_eq((hk .&. mask : U32), 0), {==}, miss,
            e => h.sz_del_miss(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, e),
            e => h.sz_del_miss(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, e))

# put and del keep the map well formed.
def h.wf_fresh(~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, p: Nat, +k: K, +v: V)
  -> {h.WF(~K, ~V, ~hash, ~eq, p, M.HLeaf{hash(k), [M.Entry{k, v}]}) == True{} : Bool}:
  match p:
    case 0n:
      {==}
    case 1n+q:
      %h.sb(U32.is_eq(hash(k), hash(k)), True{}, h.u_refl(hash(k)))
        : {Bool.and(Bool.and(_, True{}), True{}) == True{} : Bool}
      {==}

def h.wf_leaf_o(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, p: Nat, +o: U32,
  +es: List<&2, M.Entry<K, V>>,
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  ds: {Laws.hmap_distinct(~K, ~V, ~eq, es) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, p, M.HLeaf{o, es}) == True{} : Bool}:
  match p:
    case 0n:
      ds
    case 1n+q:
      and_i(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), hs, ds)

def h.split_wf.b(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +k: K, +v: V,
  +hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  +ds: {Laws.hmap_distinct(~K, ~V, ~eq, es) == True{} : Bool},
  b1: Bool, b2: Bool,
  ih: {h.WF(~K, ~V, ~hash, ~eq, p, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hash(k), k, v)) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, 1n+p, h.sp(~K, ~V, ~eq, b1, b2, p, mask, o, es, hash(k), k, v)) == True{} : Bool}:
  match b1 b2:
    case True{} True{}:
      and_i(h.WF(~K, ~V, ~hash, ~eq, p, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hash(k), k, v)),
        h.WF(~K, ~V, ~hash, ~eq, p, M.HNil{}), ih, h.wf_nil(~K, ~V, ~hash, ~eq, p))
    case True{} False{}:
      and_i(h.WF(~K, ~V, ~hash, ~eq, p, M.HNil{}),
        h.WF(~K, ~V, ~hash, ~eq, p, h.S(~K, ~V, ~eq, p, (mask << 1n : U32), o, es, hash(k), k, v)),
        h.wf_nil(~K, ~V, ~hash, ~eq, p), ih)
    case False{} True{}:
      and_i(h.WF(~K, ~V, ~hash, ~eq, p, M.HLeaf{o, es}),
        h.WF(~K, ~V, ~hash, ~eq, p, M.HLeaf{hash(k), [M.Entry{k, v}]}),
        h.wf_leaf_o(~K, ~V, ~hash, ~eq, p, o, es, hs, ds), h.wf_fresh(~K, ~V, ~hash, ~eq, p, k, v))
    case False{} False{}:
      and_i(h.WF(~K, ~V, ~hash, ~eq, p, M.HLeaf{hash(k), [M.Entry{k, v}]}),
        h.WF(~K, ~V, ~hash, ~eq, p, M.HLeaf{o, es}),
        h.wf_fresh(~K, ~V, ~hash, ~eq, p, k, v), h.wf_leaf_o(~K, ~V, ~hash, ~eq, p, o, es, hs, ds))

def h.split_wf(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  n: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +k: K, +v: V,
  +hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  +ds: {Laws.hmap_distinct(~K, ~V, ~eq, es) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, n, h.S(~K, ~V, ~eq, n, mask, o, es, hash(k), k, v)) == True{} : Bool}:
  match n:
    case 0n:
      h.distinct_put(~K, ~V, ~eq, ~refl, ~sound, es, k, v, ds)
    case 1n+(+p):
      h.split_wf.b(~K, ~V, ~hash, ~eq, p, mask, o, es, k, v, hs, ds,
        U32.is_eq((o .&. mask : U32), (hash(k) .&. mask : U32)), U32.is_eq((o .&. mask : U32), 0),
        h.split_wf(~K, ~V, ~hash, ~eq, ~refl, ~sound, p, (mask << 1n : U32), o, es, k, v, hs, ds))

def h.wf_put.lf(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  +p: Nat, +mask: U32, +o: U32, +es: List<&2, M.Entry<K, V>>, +k: K, +v: V,
  hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  ds: {Laws.hmap_distinct(~K, ~V, ~eq, es) == True{} : Bool},
  b: Bool, eb: {b == U32.is_eq(o, hash(k)) : Bool},
  sp: {h.WF(~K, ~V, ~hash, ~eq, 1n+p, h.S(~K, ~V, ~eq, 1n+p, mask, o, es, hash(k), k, v)) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, 1n+p, h.pl(~K, ~V, ~eq, b, p, mask, o, es, hash(k), k, v)) == True{} : Bool}:
  match b:
    case True{}:
      and_i(Laws.hmap_hashed(~K, ~V, ~hash, M.HMap.entries.put(~K, ~V, ~eq, es, k, v), o),
        Laws.hmap_distinct(~K, ~V, ~eq, M.HMap.entries.put(~K, ~V, ~eq, es, k, v)),
        h.hashed_put(~K, ~V, ~hash, ~eq, es, o, k, v, h.sb(True{}, U32.is_eq(o, hash(k)), eb), hs),
        h.distinct_put(~K, ~V, ~eq, ~refl, ~sound, es, k, v, ds))
    case False{}:
      sp

def h.wf_put.br(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, +v: V, b: Bool,
  wl: {h.WF(~K, ~V, ~hash, ~eq, p, lo) == True{} : Bool},
  wh: {h.WF(~K, ~V, ~hash, ~eq, p, hi) == True{} : Bool},
  il: {h.WF(~K, ~V, ~hash, ~eq, p, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v)) == True{} : Bool},
  ih: {h.WF(~K, ~V, ~hash, ~eq, p, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v)) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, 1n+p, h.pb(~K, ~V, ~eq, b, p, mask, lo, hi, hk, k, v)) == True{} : Bool}:
  match b:
    case True{}:
      and_i(h.WF(~K, ~V, ~hash, ~eq, p, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k, v)),
        h.WF(~K, ~V, ~hash, ~eq, p, hi), il, wh)
    case False{}:
      and_i(h.WF(~K, ~V, ~hash, ~eq, p, lo),
        h.WF(~K, ~V, ~hash, ~eq, p, h.P(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k, v)), wl, ih)

def h.wf_put(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, ~refl: @x: K -> {eq(x, x) == True{} : Bool},
  ~sound: @x: K -> @y: K -> {eq(x, y) == True{} : Bool} -> {x == y : K},
  n: Nat, +mask: U32, m: M.HMap<K, V>, +k: K, +v: V,
  +wf: {h.WF(~K, ~V, ~hash, ~eq, n, m) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, n, h.P(~K, ~V, ~eq, n, mask, m, hash(k), k, v)) == True{} : Bool}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{o, es}:
          h.distinct_put(~K, ~V, ~eq, ~refl, ~sound, es, k, v, wf)
        case M.HBranch{lo, hi}:
          wf
    case 1n+(+p):
      match m:
        case M.HNil{}:
          h.wf_fresh(~K, ~V, ~hash, ~eq, 1n+p, k, v)
        case M.HLeaf{+o, +es}:
          h.wf_put.lf(~K, ~V, ~hash, ~eq, ~refl, ~sound, p, mask, o, es, k, v,
            and_l(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf),
            and_r(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf),
            U32.is_eq(o, hash(k)), {==},
            h.split_wf(~K, ~V, ~hash, ~eq, ~refl, ~sound, 1n+p, mask, o, es, k, v,
              and_l(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf),
              and_r(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf)))
        case M.HBranch{+lo, +hi}:
          h.wf_put.br(~K, ~V, ~hash, ~eq, p, mask, lo, hi, hash(k), k, v, U32.is_eq((hash(k) .&. mask : U32), 0),
            and_l(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf),
            and_r(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf),
            h.wf_put(~K, ~V, ~hash, ~eq, ~refl, ~sound, p, (mask << 1n : U32), lo, k, v,
              and_l(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf)),
            h.wf_put(~K, ~V, ~hash, ~eq, ~refl, ~sound, p, (mask << 1n : U32), hi, k, v,
              and_r(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf)))

def h.wf_del.lf(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +p: Nat, +o: U32,
  +es: List<&2, M.Entry<K, V>>, +k: K,
  +hs: {Laws.hmap_hashed(~K, ~V, ~hash, es, o) == True{} : Bool},
  +ds: {Laws.hmap_distinct(~K, ~V, ~eq, es) == True{} : Bool}, b: Bool
) -> {h.WF(~K, ~V, ~hash, ~eq, 1n+p, h.dl(~K, ~V, ~eq, b, o, es, k)) == True{} : Bool}:
  match b:
    case True{}:
      h.wf_leaf(~K, ~V, ~hash, ~eq, 1n+p, o, M.HMap.entries.del(~K, ~V, ~eq, es, k),
        and_i(Laws.hmap_hashed(~K, ~V, ~hash, M.HMap.entries.del(~K, ~V, ~eq, es, k), o),
          Laws.hmap_distinct(~K, ~V, ~eq, M.HMap.entries.del(~K, ~V, ~eq, es, k)),
          h.hashed_del(~K, ~V, ~hash, ~eq, es, o, k, hs), h.distinct_del(~K, ~V, ~eq, es, k, ds)))
    case False{}:
      and_i(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), hs, ds)

def h.wf_del.br(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool, +p: Nat, +mask: U32, +lo: M.HMap<K, V>,
  +hi: M.HMap<K, V>, +hk: U32, +k: K, b: Bool,
  wl: {h.WF(~K, ~V, ~hash, ~eq, p, lo) == True{} : Bool},
  wh: {h.WF(~K, ~V, ~hash, ~eq, p, hi) == True{} : Bool},
  il: {h.WF(~K, ~V, ~hash, ~eq, p, h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k)) == True{} : Bool},
  ih: {h.WF(~K, ~V, ~hash, ~eq, p, h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k)) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, 1n+p, h.db(~K, ~V, ~eq, b, p, mask, lo, hi, hk, k)) == True{} : Bool}:
  match b:
    case True{}:
      h.wf_join(~K, ~V, ~hash, ~eq, p, h.D(~K, ~V, ~eq, p, (mask << 1n : U32), lo, hk, k), hi, il, wh)
    case False{}:
      h.wf_join(~K, ~V, ~hash, ~eq, p, lo, h.D(~K, ~V, ~eq, p, (mask << 1n : U32), hi, hk, k), wl, ih)

def h.wf_del(
  ~K: Data, ~V: Data, ~hash: K -> U32, ~eq: K -> K -> Bool,
  n: Nat, +mask: U32, m: M.HMap<K, V>, +hk: U32, +k: K,
  +wf: {h.WF(~K, ~V, ~hash, ~eq, n, m) == True{} : Bool}
) -> {h.WF(~K, ~V, ~hash, ~eq, n, h.D(~K, ~V, ~eq, n, mask, m, hk, k)) == True{} : Bool}:
  match n:
    case 0n:
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          h.wf_leaf(~K, ~V, ~hash, ~eq, 0n, o, M.HMap.entries.del(~K, ~V, ~eq, es, k),
            h.distinct_del(~K, ~V, ~eq, es, k, wf))
        case M.HBranch{lo, hi}:
          wf
    case 1n+(+p):
      match m:
        case M.HNil{}:
          {==}
        case M.HLeaf{+o, +es}:
          h.wf_del.lf(~K, ~V, ~hash, ~eq, p, o, es, k,
            and_l(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf),
            and_r(Laws.hmap_hashed(~K, ~V, ~hash, es, o), Laws.hmap_distinct(~K, ~V, ~eq, es), wf),
            U32.is_eq(o, hk))
        case M.HBranch{+lo, +hi}:
          h.wf_del.br(~K, ~V, ~hash, ~eq, p, mask, lo, hi, hk, k, U32.is_eq((hk .&. mask : U32), 0),
            and_l(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf),
            and_r(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf),
            h.wf_del(~K, ~V, ~hash, ~eq, p, (mask << 1n : U32), lo, hk, k,
              and_l(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf)),
            h.wf_del(~K, ~V, ~hash, ~eq, p, (mask << 1n : U32), hi, hk, k,
              and_r(h.WF(~K, ~V, ~hash, ~eq, p, lo), h.WF(~K, ~V, ~hash, ~eq, p, hi), wf)))

# --- hmap laws -------------------------------------------------------------------

def Laws.hmap_new_wf(K, V, hash, eq):
  {==}

def Laws.hmap_put_wf(K, V, hash, eq, refl, sound, m, wf, k, v):
  h.wf_put(~K, ~V, ~hash, ~eq, ~refl, ~sound, 32n, 1, m, k, v, wf)

def Laws.hmap_del_wf(K, V, hash, eq, m, wf, k):
  h.wf_del(~K, ~V, ~hash, ~eq, 32n, 1, m, hash(k), k, wf)

def Laws.hmap_get_put_same(K, V, hash, eq, refl, m, wf, k, v):
  h.gp_same(~K, ~V, ~hash, ~eq, ~refl, 32n, 1, m, hash(k), k, v, {==}, wf)

def Laws.hmap_get_put_other_key(K, V, hash, eq, sound, m, wf, k2, k, ne, v):
  h.gp_other(~K, ~V, ~hash, ~eq, ~sound, 32n, 1, m, hash(k2), k2, k, v, wf,
    h.ne_f(~K, ~eq, ~sound, k2, k, ne))

def Laws.hmap_get_del_same(K, V, hash, eq, sound, m, wf, k):
  h.gd_same(~K, ~V, ~hash, ~eq, ~sound, 32n, 1, m, hash(k), k, wf)

def Laws.hmap_get_del_other_key(K, V, hash, eq, sound, m, k2, k, ne):
  h.gd_other(~K, ~V, ~eq, ~sound, 32n, 1, m, hash(k2), k2, hash(k), k, h.ne_f(~K, ~eq, ~sound, k2, k, ne))

def Laws.hmap_size_put_new(K, V, hash, eq, sound, m, wf, k, v, miss):
  h.sz_put_new(~K, ~V, ~hash, ~eq, ~sound, 32n, 1, m, k, v, wf, miss)

def Laws.hmap_size_put_replace(K, V, hash, eq, m, k, v, w, hit):
  h.sz_put_hit(~K, ~V, ~eq, 32n, 1, m, hash(k), k, v, w, hit)

def Laws.hmap_size_del(K, V, hash, eq, m, k, w, hit):
  h.sz_del_hit(~K, ~V, ~eq, 32n, 1, m, hash(k), k, w, hit)

def Laws.hmap_size_del_missing(K, V, hash, eq, m, k, miss):
  h.sz_del_miss(~K, ~V, ~eq, 32n, 1, m, hash(k), k, miss)

def Laws.hmap_collision_get(K, V, hash, eq, refl, sound, m, wf, k1, k2, ne, same, v1, v2):
  +m1 = M.HMap.put(~K, ~V, ~hash, ~eq, m, k1, v1)
  Equal.trans(Maybe<&2, V>,
    M.HMap.get(~K, ~V, ~hash, ~eq, M.HMap.put(~K, ~V, ~hash, ~eq, m1, k2, v2), k1),
    M.HMap.get(~K, ~V, ~hash, ~eq, m1, k1), Some{v1},
    h.gp_other(~K, ~V, ~hash, ~eq, ~sound, 32n, 1, m1, hash(k2), k2, k1, v2,
      h.wf_put(~K, ~V, ~hash, ~eq, ~refl, ~sound, 32n, 1, m, k1, v1, wf),
      h.ne_f(~K, ~eq, ~sound, k2, k1, ne)),
    h.gp_same(~K, ~V, ~hash, ~eq, ~refl, 32n, 1, m, hash(k1), k1, v1, {==}, wf))

def Laws.hmap_collision_size(K, V, hash, eq, refl, sound, m, wf, k1, k2, ne, same, v1, v2, miss1, miss2):
  +m1 = M.HMap.put(~K, ~V, ~hash, ~eq, m, k1, v1)
  Equal.trans(Nat, M.HMap.size(K, V, M.HMap.put(~K, ~V, ~hash, ~eq, m1, k2, v2)),
    1n+M.HMap.size(K, V, m1), 2n+M.HMap.size(K, V, m),
    Laws.hmap_size_put_new(~K, ~V, ~hash, ~eq, ~sound, m1,
      Laws.hmap_put_wf(~K, ~V, ~hash, ~eq, ~refl, ~sound, m, wf, k1, v1), k2, v2,
      Equal.trans(Maybe<&2, V>, M.HMap.get(~K, ~V, ~hash, ~eq, m1, k2),
        M.HMap.get(~K, ~V, ~hash, ~eq, m, k2), None{},
        Laws.hmap_get_put_other_key(~K, ~V, ~hash, ~eq, ~sound, m, wf, k1, k2, ne, v1), miss2)),
    Equal.cong(Nat, Nat, x => 1n+x, M.HMap.size(K, V, m1), 1n+M.HMap.size(K, V, m),
      Laws.hmap_size_put_new(~K, ~V, ~hash, ~eq, ~sound, m, wf, k1, v1, miss1)))
