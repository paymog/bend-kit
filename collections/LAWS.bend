import Base
import ./omap.bend as O
import ./hmap.bend as M
import ./vec.bend as V
import ./deque.bend as D
import ./heap.bend as H

def scmp.fin(r: (String & String) & Cmp) -> Cmp:
  (ab, c) = r
  c

def scmp(a: String, b: String) -> Cmp:
  scmp.fin(String.cmp(a, b))

def m3() -> O.OMap<U32, U32>:
  m = O.OMap.put(~U32, ~U32, ~U32.cmp, O.OMap.new(U32, U32), 5, 50)
  m = O.OMap.put(~U32, ~U32, ~U32.cmp, m, 1, 10)
  O.OMap.put(~U32, ~U32, ~U32.cmp, m, 3, 30)

def m7.go(n: Nat, +i: U32, m: O.OMap<U32, U32>) -> O.OMap<U32, U32>:
  match n:
    case 0n:
      m
    case 1n+p:
      m7.go(p, (i + 1 : U32), O.OMap.put(~U32, ~U32, ~U32.cmp, m, i, (i * 10 : U32)))

def m7() -> O.OMap<U32, U32>:
  m7.go(7n, 1, O.OMap.new(U32, U32))

law omap_keys_ascending_puts:
  {O.OMap.keys(U32, U32, m7()) == [1, 2, 3, 4, 5, 6, 7] : List<&2, U32>}

law omap_size_del:
  {O.OMap.size(U32, U32, O.OMap.del(~U32, ~U32, ~U32.cmp, m7(), 4)) == 6 : U32}

law omap_get_after_rotations:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.del(~U32, ~U32, ~U32.cmp, m7(), 4), 6)
   == Some{60} : Maybe<&2, U32>}

law omap_keys_del_root:
  {O.OMap.keys(U32, U32, O.OMap.del(~U32, ~U32, ~U32.cmp, m7(), 4))
   == [1, 2, 3, 5, 6, 7] : List<&2, U32>}

law omap_get_put:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 4, 40), 4)
   == Some{40} : Maybe<&2, U32>}

law omap_get_put_replace:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 3, 33), 3)
   == Some{33} : Maybe<&2, U32>}

law omap_get_put_other:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 4, 40), 3)
   == O.OMap.get(~U32, ~U32, ~U32.cmp, m3(), 3) : Maybe<&2, U32>}

law omap_get_missing:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, m3(), 2) == None{} : Maybe<&2, U32>}

law omap_keys_sorted:
  {O.OMap.keys(U32, U32, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 4, 40))
   == [1, 3, 4, 5] : List<&2, U32>}

law omap_size_replace:
  {O.OMap.size(U32, U32, O.OMap.put(~U32, ~U32, ~U32.cmp, m3(), 5, 55)) == 3 : U32}

law omap_get_del:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.del(~U32, ~U32, ~U32.cmp, m3(), 3), 3)
   == None{} : Maybe<&2, U32>}

law omap_get_del_other:
  {O.OMap.get(~U32, ~U32, ~U32.cmp, O.OMap.del(~U32, ~U32, ~U32.cmp, m3(), 3), 5)
   == Some{50} : Maybe<&2, U32>}

law omap_keys_del:
  {O.OMap.keys(U32, U32, O.OMap.del(~U32, ~U32, ~U32.cmp, m3(), 5))
   == [1, 3] : List<&2, U32>}

law omap_string_keys:
  {O.OMap.keys(String, U32,
     O.OMap.put(~String, ~U32, ~scmp,
       O.OMap.put(~String, ~U32, ~scmp, O.OMap.new(String, U32), "b", 2),
       "a", 1))
   == ["a", "b"] : List<&2, String>}

law oset_to_list:
  {O.OSet.to_list(U32,
     O.OSet.add(~U32, ~U32.cmp, O.OSet.add(~U32, ~U32.cmp,
       O.OSet.add(~U32, ~U32.cmp, O.OSet.new(U32), 3), 1), 3))
   == [1, 3] : List<&2, U32>}

law oset_has_del:
  {O.OSet.has(~U32, ~U32.cmp,
     O.OSet.del(~U32, ~U32.cmp, O.OSet.add(~U32, ~U32.cmp, O.OSet.new(U32), 3), 3), 3)
   == False{} : Bool}

# The laws below hold for every comparator that is a total order, with EQ
# meaning equal keys.
def flip(c: Cmp) -> Cmp:
  match c:
    case LT{}:
      GT{}
    case EQ{}:
      EQ{}
    case GT{}:
      LT{}

def above(~K: Data, ~cmp: K -> K -> Cmp, lb: Maybe<&2, K>, +k: K) -> Bool:
  match lb:
    case None{}:
      True{}
    case Some{b}:
      Cmp.is_lt(cmp(b, k))

def below(~K: Data, ~cmp: K -> K -> Cmp, ub: Maybe<&2, K>, +k: K) -> Bool:
  match ub:
    case None{}:
      True{}
    case Some{b}:
      Cmp.is_lt(cmp(k, b))

# Every key of m lies strictly between the bounds, in search-tree order.
def bounded(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: O.OMap<K, V>, +lb: Maybe<&2, K>,
  +ub: Maybe<&2, K>
) -> Bool:
  match m:
    case O.OTip{}:
      True{}
    case O.OBin{s, +k, v, lo, hi}:
      above(~K, ~cmp, lb, k) && below(~K, ~cmp, ub, k)
        && bounded(~K, ~V, ~cmp, lo, lb, Some{k})
        && bounded(~K, ~V, ~cmp, hi, Some{k}, ub)

def searchtree(~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: O.OMap<K, V>) -> Bool:
  bounded(~K, ~V, ~cmp, m, None{}, None{})

def sorted.go(~K: Data, ~cmp: K -> K -> Cmp, xs: List<&2, K>, +prev: K) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+h, t}:
      Cmp.is_lt(cmp(prev, h)) && sorted.go(~K, ~cmp, t, h)

def sorted(~K: Data, ~cmp: K -> K -> Cmp, xs: List<&2, K>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{+h, t}:
      sorted.go(~K, ~cmp, t, h)

law omap_new_searchtree:
  for ~K: Data
  for ~V: Data
  for ~cmp: K -> K -> Cmp
  {searchtree(~K, ~V, ~cmp, O.OMap.new(K, V)) == True{} : Bool}

law omap_put_searchtree:
  for ~K: Data
  for ~V: Data
  for ~cmp: K -> K -> Cmp
  for ~refl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for ~flip: @x: K -> @y: K -> {cmp(y, x) == flip(cmp(x, y)) : Cmp}
  for ~trans: @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}
  for m: O.OMap<K, V>
  for tree: {searchtree(~K, ~V, ~cmp, m) == True{} : Bool}
  for +k: K
  for +v: V
  {searchtree(~K, ~V, ~cmp, O.OMap.put(~K, ~V, ~cmp, m, k, v)) == True{} : Bool}

law omap_del_searchtree:
  for ~K: Data
  for ~V: Data
  for ~cmp: K -> K -> Cmp
  for ~refl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for ~flip: @x: K -> @y: K -> {cmp(y, x) == flip(cmp(x, y)) : Cmp}
  for ~trans: @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}
  for m: O.OMap<K, V>
  for tree: {searchtree(~K, ~V, ~cmp, m) == True{} : Bool}
  for +k: K
  {searchtree(~K, ~V, ~cmp, O.OMap.del(~K, ~V, ~cmp, m, k)) == True{} : Bool}

law omap_searchtree_keys_sorted:
  for ~K: Data
  for ~V: Data
  for ~cmp: K -> K -> Cmp
  for m: O.OMap<K, V>
  for tree: {searchtree(~K, ~V, ~cmp, m) == True{} : Bool}
  {sorted(~K, ~cmp, O.OMap.keys(K, V, m)) == True{} : Bool}

law omap_get_put_same:
  for ~K: Data
  for ~V: Data
  for ~cmp: K -> K -> Cmp
  for ~refl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for ~flip: @x: K -> @y: K -> {cmp(y, x) == flip(cmp(x, y)) : Cmp}
  for ~trans: @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}
  for m: O.OMap<K, V>
  for tree: {searchtree(~K, ~V, ~cmp, m) == True{} : Bool}
  for +k: K
  for +v: V
  {O.OMap.get(~K, ~V, ~cmp, O.OMap.put(~K, ~V, ~cmp, m, k, v), k) == Some{v} : Maybe<&2, V>}

law omap_get_put_other_key:
  for ~K: Data
  for ~V: Data
  for ~cmp: K -> K -> Cmp
  for ~refl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for ~flip: @x: K -> @y: K -> {cmp(y, x) == flip(cmp(x, y)) : Cmp}
  for ~trans: @x: K -> @y: K -> @z: K -> {cmp(x, y) == LT{} : Cmp} -> {cmp(y, z) == LT{} : Cmp} -> {cmp(x, z) == LT{} : Cmp}
  for m: O.OMap<K, V>
  for tree: {searchtree(~K, ~V, ~cmp, m) == True{} : Bool}
  for +k2: K
  for +k: K
  for ne: {cmp(k2, k) != EQ{} : Cmp}
  for +v: V
  {O.OMap.get(~K, ~V, ~cmp, O.OMap.put(~K, ~V, ~cmp, m, k2, v), k)
   == O.OMap.get(~K, ~V, ~cmp, m, k) : Maybe<&2, V>}


# Ghost weight from tree shape: weight = stored size + 1, so OTip has weight 1 and
# OBin{lo, hi} has weight w(lo) + w(hi). Balance is Hirai-Yamamoto (delta 3, gamma 2).
def omap_weight(-K: Data, -V: Data, m: O.OMap<K, V>) -> Nat:
  match m:
    case O.OTip{}:
      1n
    case O.OBin{s, k, v, lo, hi}:
      Nat.add(omap_weight(K, V, lo), omap_weight(K, V, hi))

def weight_ok(+wl: Nat, +wh: Nat) -> Bool:
  Nat.is_le(wh, Nat.mul(3n, wl)) && Nat.is_le(wl, Nat.mul(3n, wh))

def weight_balanced(-K: Data, -V: Data, m: O.OMap<K, V>) -> Bool:
  match m:
    case O.OTip{}:
      True{}
    case O.OBin{s, k, v, +lo, +hi}:
      weight_ok(omap_weight(K, V, lo), omap_weight(K, V, hi))
        && weight_balanced(K, V, lo) && weight_balanced(K, V, hi)

# The ghost map below has the shape of OMap: it builds nodes with the same
# OMap.bin and rotations, but it compares Nat weights where OMap compares U32
# sizes. While 3 * (size + 1) stays below 2^32, the U32 tests give the same
# answers, so g_put and g_del give the same tree as put and del. The checker
# cannot see into U32, so that link is an assumption, checked on fixtures below.
def g_heavy_hi(-K: Data, -V: Data, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>) -> Bool:
  Nat.is_gt(omap_weight(K, V, hi), Nat.mul(3n, omap_weight(K, V, lo)))

def g_heavy_lo(-K: Data, -V: Data, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>) -> Bool:
  Nat.is_gt(omap_weight(K, V, lo), Nat.mul(3n, omap_weight(K, V, hi)))

def g_rot_lo(-K: Data, -V: Data, k: K, v: V, lo: O.OMap<K, V>, hi: O.OMap<K, V>) -> O.OMap<K, V>:
  match hi:
    case O.OTip{}:
      O.OMap.bin(K, V, k, v, lo, O.OTip{})
    case O.OBin{s, hk, hv, +hl, +hh}:
      O.OMap.rot_lo.pick(K, V,
        Nat.is_lt(omap_weight(K, V, hl), Nat.mul(2n, omap_weight(K, V, hh))),
        k, v, lo, hk, hv, hl, hh)

def g_rot_hi(-K: Data, -V: Data, k: K, v: V, lo: O.OMap<K, V>, hi: O.OMap<K, V>) -> O.OMap<K, V>:
  match lo:
    case O.OTip{}:
      O.OMap.bin(K, V, k, v, O.OTip{}, hi)
    case O.OBin{s, lk, lv, +ll, +lh}:
      O.OMap.rot_hi.pick(K, V,
        Nat.is_lt(omap_weight(K, V, lh), Nat.mul(2n, omap_weight(K, V, ll))),
        k, v, lk, lv, ll, lh, hi)

def g_balance.if(
  -K: Data, -V: Data, heavy_hi: Bool, heavy_lo: Bool, k: K, v: V,
  lo: O.OMap<K, V>, hi: O.OMap<K, V>
) -> O.OMap<K, V>:
  match heavy_hi heavy_lo:
    case True{} _:
      g_rot_lo(K, V, k, v, lo, hi)
    case False{} True{}:
      g_rot_hi(K, V, k, v, lo, hi)
    case False{} False{}:
      O.OMap.bin(K, V, k, v, lo, hi)

def g_balance(-K: Data, -V: Data, k: K, v: V, +lo: O.OMap<K, V>, +hi: O.OMap<K, V>) -> O.OMap<K, V>:
  g_balance.if(K, V, g_heavy_hi(K, V, lo, hi), g_heavy_lo(K, V, lo, hi), k, v, lo, hi)

def g_put(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: O.OMap<K, V>, +k: K, +v: V
) -> O.OMap<K, V>:
  match m:
    case O.OTip{}:
      O.OBin{1, k, v, O.OTip{}, O.OTip{}}
    case O.OBin{+s, +key, +val, +lo, +hi}:
      O.Cmp.case(O.OMap<K, V>, cmp(k, key),
        u => g_balance(K, V, key, val, g_put(~K, ~V, ~cmp, lo, k, v), hi),
        u => O.OBin{s, key, v, lo, hi},
        u => g_balance(K, V, key, val, lo, g_put(~K, ~V, ~cmp, hi, k, v)))

def g_pop_min.fin(
  -K: Data, -V: Data, k: K, v: V, hi: O.OMap<K, V>, r: K & V & O.OMap<K, V>
) -> K & V & O.OMap<K, V>:
  (mk, mv, lo) = r
  (mk, mv, g_balance(K, V, k, v, lo, hi))

def g_pop_min(
  -K: Data, -V: Data, lo: O.OMap<K, V>, k: K, v: V, hi: O.OMap<K, V>
) -> K & V & O.OMap<K, V>:
  match lo:
    case O.OTip{}:
      (k, v, hi)
    case O.OBin{s, lk, lv, ll, lh}:
      g_pop_min.fin(K, V, k, v, hi, g_pop_min(K, V, ll, lk, lv, lh))

def g_glue.fin(-K: Data, -V: Data, lo: O.OMap<K, V>, r: K & V & O.OMap<K, V>) -> O.OMap<K, V>:
  (k, v, hi) = r
  g_balance(K, V, k, v, lo, hi)

def g_glue(-K: Data, -V: Data, lo: O.OMap<K, V>, hi: O.OMap<K, V>) -> O.OMap<K, V>:
  match hi:
    case O.OTip{}:
      lo
    case O.OBin{s, k, v, hl, hh}:
      g_glue.fin(K, V, lo, g_pop_min(K, V, hl, k, v, hh))

def g_del(
  ~K: Data, ~V: Data, ~cmp: K -> K -> Cmp, m: O.OMap<K, V>, +k: K
) -> O.OMap<K, V>:
  match m:
    case O.OTip{}:
      O.OTip{}
    case O.OBin{+s, +key, +val, +lo, +hi}:
      O.Cmp.case(O.OMap<K, V>, cmp(k, key),
        u => g_balance(K, V, key, val, g_del(~K, ~V, ~cmp, lo, k), hi),
        u => g_glue(K, V, lo, hi),
        u => g_balance(K, V, key, val, lo, g_del(~K, ~V, ~cmp, hi, k)))

law omap_new_weight_balanced:
  for ~K: Data
  for ~V: Data
  {weight_balanced(K, V, O.OMap.new(K, V)) == True{} : Bool}

law omap_g_put_matches:
  {g_put(~U32, ~U32, ~U32.cmp, m7(), 8, 80)
   == O.OMap.put(~U32, ~U32, ~U32.cmp, m7(), 8, 80) : O.OMap<U32, U32>}

law omap_g_del_matches:
  {g_del(~U32, ~U32, ~U32.cmp, m7(), 4)
   == O.OMap.del(~U32, ~U32, ~U32.cmp, m7(), 4) : O.OMap<U32, U32>}

law omap_put_weight_balanced:
  for ~K: Data
  for ~V: Data
  for ~cmp: K -> K -> Cmp
  for +m: O.OMap<K, V>
  for wb: {weight_balanced(K, V, m) == True{} : Bool}
  for +k: K
  for +v: V
  {weight_balanced(K, V, g_put(~K, ~V, ~cmp, m, k, v)) == True{} : Bool}

law omap_del_weight_balanced:
  for ~K: Data
  for ~V: Data
  for ~cmp: K -> K -> Cmp
  for +m: O.OMap<K, V>
  for wb: {weight_balanced(K, V, m) == True{} : Bool}
  for +k: K
  {weight_balanced(K, V, g_del(~K, ~V, ~cmp, m, k)) == True{} : Bool}


law vec_from_list:
  {V.Vec.to_list(~U32, V.Vec.from_list(~U32, [1, 2, 3, 4, 5]))
   == [1, 2, 3, 4, 5] : List<&2, U32>}

law vec_get:
  {Pair.snd(V.Vec<U32>, Maybe<&2, U32>, V.Vec.get(~U32, V.Vec.from_list(~U32, [1, 2, 3]), 2))
   == Some{3} : Maybe<&2, U32>}

law vec_get_past_len:
  {Pair.snd(V.Vec<U32>, Maybe<&2, U32>, V.Vec.get(~U32, V.Vec.from_list(~U32, [1, 2, 3]), 3))
   == None{} : Maybe<&2, U32>}

law vec_set:
  {V.Vec.to_list(~U32, V.Vec.set(~U32, V.Vec.from_list(~U32, [1, 2, 3]), 1, 9))
   == [1, 9, 3] : List<&2, U32>}

law vec_pop:
  {Pair.snd(V.Vec<U32>, Maybe<&2, U32>, V.Vec.pop(~U32, V.Vec.from_list(~U32, [1, 2, 3])))
   == Some{3} : Maybe<&2, U32>}

law vec_pop_empty:
  {Pair.snd(V.Vec<U32>, Maybe<&2, U32>, V.Vec.pop(~U32, V.Vec.new(~U32)))
   == None{} : Maybe<&2, U32>}

law vec_pop_to_list:
  {V.Vec.to_list(~U32, Pair.fst(V.Vec<U32>, Maybe<&2, U32>,
     V.Vec.pop(~U32, V.Vec.from_list(~U32, [1, 2, 3]))))
   == [1, 2] : List<&2, U32>}

law deque_ends:
  {D.Deque.to_list(&2, U32, D.Deque.push_front(&2, U32, 0,
     D.Deque.push_back(&2, U32, 2, D.Deque.push_back(&2, U32, 1, D.Deque.new(&2, U32)))))
   == [0, 1, 2] : List<&2, U32>}

law heap_sort:
  {H.Heap.sort(~U32, ~U32.is_le, [3, 1, 4, 1, 5]) == [1, 1, 3, 4, 5] : List<&2, U32>}

def hkey(k: U32) -> U32:
  (k .&. 1 : U32)

def hm() -> M.HMap<U32, U32>:
  m = M.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, M.HMap.new(U32, U32), 2, 20)
  M.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, m, 3, 30)

law hmap_get_put:
  {M.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq,
     M.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, hm(), 4, 40), 4)
   == Some{40} : Maybe<&2, U32>}

law hmap_get_put_other:
  {M.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq,
     M.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, hm(), 4, 40), 3)
   == M.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq, hm(), 3) : Maybe<&2, U32>}

law hmap_collision:
  {M.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq,
     M.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, hm(), 4, 40), 2)
   == Some{20} : Maybe<&2, U32>}

law hmap_replace_collision:
  {M.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq,
     M.HMap.put(~U32, ~U32, ~hkey, ~U32.is_eq, hm(), 2, 22), 2)
   == Some{22} : Maybe<&2, U32>}

def full(k: U32) -> U32:
  k

law hmap_high_bit:
  {M.HMap.get(~U32, ~U32, ~full, ~U32.is_eq,
     M.HMap.put(~U32, ~U32, ~full, ~U32.is_eq,
       M.HMap.put(~U32, ~U32, ~full, ~U32.is_eq, M.HMap.new(U32, U32), 0, 10),
       2147483648, 20), 0)
   == Some{10} : Maybe<&2, U32>}

law hmap_missing_collision:
  {M.HMap.get(~U32, ~U32, ~hkey, ~U32.is_eq, hm(), 4)
   == None{} : Maybe<&2, U32>}
