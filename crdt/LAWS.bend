import Base
import bend-kit-cbor@0.3.0.0/cbor.bend as Cbor
import ./crdt.bend as Crdt

# True when an increment failed, or when it kept s at most its result.
def grows(s: List<&2, U32>, m: Maybe<&2, List<&2, U32>>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{t}:
      Crdt.GCounter.le(s, t)

# True when m is None or holds a valid state.
def ok_valid(m: Maybe<&2, List<&2, U32>>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{s}:
      Crdt.GCounter.valid(s)

# Equality of two states as lists.
def same(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Nil{} Con{y, ys}:
      False{}
    case Con{x, xs} Nil{}:
      False{}
    case Con{x, xs} Con{y, ys}:
      Bool.and(U32.is_eq(x, y), same(xs, ys))

def member(+x: List<&2, U32>, ys: List<&2, List<&2, U32>>) -> Bool:
  match ys:
    case Nil{}:
      False{}
    case Con{y, t}:
      Bool.or(same(x, y), member(x, t))

# True when every state in xs is also in ys.
def covers(xs: List<&2, List<&2, U32>>, +ys: List<&2, List<&2, U32>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{x, t}:
      Bool.and(member(x, ys), covers(t, ys))

# Merge is a join: commutative, associative, and idempotent.
law merge_comm:
  for a: List<&2, U32>
  for b: List<&2, U32>
  {Crdt.GCounter.merge(a, b) == Crdt.GCounter.merge(b, a) : List<&2, U32>}

law merge_assoc:
  for a: List<&2, U32>
  for b: List<&2, U32>
  for c: List<&2, U32>
  {Crdt.GCounter.merge(Crdt.GCounter.merge(a, b), c)
   == Crdt.GCounter.merge(a, Crdt.GCounter.merge(b, c)) : List<&2, U32>}

law merge_idem:
  for a: List<&2, U32>
  {Crdt.GCounter.merge(a, a) == a : List<&2, U32>}

# Merge is a least upper bound in the component-wise order.
law merge_upper_l:
  for a: List<&2, U32>
  for b: List<&2, U32>
  {Crdt.GCounter.le(a, Crdt.GCounter.merge(a, b)) == True{} : Bool}

law merge_upper_r:
  for a: List<&2, U32>
  for b: List<&2, U32>
  {Crdt.GCounter.le(b, Crdt.GCounter.merge(a, b)) == True{} : Bool}

law merge_least:
  for a: List<&2, U32>
  for b: List<&2, U32>
  for c: List<&2, U32>
  for ha: {Crdt.GCounter.le(a, c) == True{} : Bool}
  for hb: {Crdt.GCounter.le(b, c) == True{} : Bool}
  {Crdt.GCounter.le(Crdt.GCounter.merge(a, b), c) == True{} : Bool}

# A local increment never lowers a count.
law inc_grows:
  for s: List<&2, U32>
  for i: Nat
  {grows(s, Crdt.GCounter.inc(s, i)) == True{} : Bool}

# Merge and increment keep a state valid.
law merge_valid:
  for a: List<&2, U32>
  for b: List<&2, U32>
  for ha: {Crdt.GCounter.valid(a) == True{} : Bool}
  for hb: {Crdt.GCounter.valid(b) == True{} : Bool}
  {Crdt.GCounter.valid(Crdt.GCounter.merge(a, b)) == True{} : Bool}

law inc_valid:
  for s: List<&2, U32>
  for i: Nat
  for h: {Crdt.GCounter.valid(s) == True{} : Bool}
  {ok_valid(Crdt.GCounter.inc(s, i)) == True{} : Bool}

# Two replicas that received the same states, in any order and with any
# duplicates, hold the same state.
law converge:
  for xs: List<&2, List<&2, U32>>
  for ys: List<&2, List<&2, U32>>
  for hx: {covers(xs, ys) == True{} : Bool}
  for hy: {covers(ys, xs) == True{} : Bool}
  {Crdt.GCounter.merge_all(xs) == Crdt.GCounter.merge_all(ys) : List<&2, U32>}

# The CBOR boundary admits only valid states.
law from_cbor_valid:
  for v: Cbor.Val
  for cap: U32
  {ok_valid(Crdt.GCounter.from_cbor(v, cap)) == True{} : Bool}

law cbor_roundtrip:
  for s: List<&2, U32>
  for cap: U32
  for hv: {Crdt.GCounter.valid(s) == True{} : Bool}
  for hc: {U32.is_le(Crdt.GCounter.size(s), cap) == True{} : Bool}
  {Crdt.GCounter.from_cbor(Crdt.GCounter.to_cbor(s), cap) == Some{s} : Maybe<&2, List<&2, U32>>}

law inc_pads:
  {Crdt.GCounter.inc(Crdt.GCounter.new(), 2n) == Some{[0, 0, 1]} : Maybe<&2, List<&2, U32>>}

law inc_overflow:
  {Crdt.GCounter.inc([7, 4294967295], 1n) == None{} : Maybe<&2, List<&2, U32>>}

law get_missing:
  {Crdt.GCounter.get([7], 3n) == 0 : U32}

law merge_fixture:
  {Crdt.GCounter.merge([3, 0, 5], [1, 4]) == [3, 4, 5] : List<&2, U32>}

law value_sum:
  {Crdt.GCounter.value([3, 4, 5]) == Some{12} : Maybe<&2, U32>}

law value_overflow:
  {Crdt.GCounter.value([4294967295, 1]) == None{} : Maybe<&2, U32>}

def uint(n: U32) -> Cbor.Val:
  Cbor.UInt{Cbor.W64{0, n}}

law from_cbor_accepts:
  {Crdt.GCounter.from_cbor(Cbor.Arr{[uint(3), uint(0), uint(5)]}, 3)
   == Some{[3, 0, 5]} : Maybe<&2, List<&2, U32>>}

law from_cbor_trailing_zero:
  {Crdt.GCounter.from_cbor(Cbor.Arr{[uint(3), uint(0)]}, 8)
   == None{} : Maybe<&2, List<&2, U32>>}

law from_cbor_over_cap:
  {Crdt.GCounter.from_cbor(Cbor.Arr{[uint(3), uint(0), uint(5)]}, 2)
   == None{} : Maybe<&2, List<&2, U32>>}

law from_cbor_wide:
  {Crdt.GCounter.from_cbor(Cbor.Arr{[Cbor.UInt{Cbor.W64{1, 0}}]}, 8)
   == None{} : Maybe<&2, List<&2, U32>>}

law from_cbor_negative:
  {Crdt.GCounter.from_cbor(Cbor.Arr{[Cbor.NInt{Cbor.W64{0, 0}}]}, 8)
   == None{} : Maybe<&2, List<&2, U32>>}

law from_cbor_not_array:
  {Crdt.GCounter.from_cbor(uint(3), 8) == None{} : Maybe<&2, List<&2, U32>>}

# KCounter: a G-Counter keyed by sparse IDs. Two states are equal as counters
# when get agrees on every ID, so the join laws quantify over the ID k.
def flip(c: Cmp) -> Cmp:
  match c:
    case LT{}:
      GT{}
    case EQ{}:
      EQ{}
    case GT{}:
      LT{}

def k.grows(~K: Data, ~cmp: K -> K -> Cmp, +s: Crdt.KCounter<K>, m: Maybe<&2, Crdt.KCounter<K>>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{t}:
      Crdt.KCounter.le(~K, ~cmp, s, t)

def k.ok_valid(~K: Data, ~cmp: K -> K -> Cmp, m: Maybe<&2, Crdt.KCounter<K>>) -> Bool:
  match m:
    case None{}:
      True{}
    case Some{s}:
      Crdt.KCounter.valid(~K, ~cmp, s)

# Equality of two states entry by entry, with IDs compared by cmp.
def k.same(~K: Data, ~cmp: K -> K -> Cmp, a: Crdt.KCounter<K>, b: Crdt.KCounter<K>) -> Bool:
  match a b:
    case Crdt.KNil{} Crdt.KNil{}:
      True{}
    case Crdt.KNil{} Crdt.KCon{y, d, t}:
      False{}
    case Crdt.KCon{x, c, r} Crdt.KNil{}:
      False{}
    case Crdt.KCon{x, c, r} Crdt.KCon{y, d, t}:
      Bool.and(Bool.and(Cmp.is_eq(cmp(x, y)), U32.is_eq(c, d)), k.same(~K, ~cmp, r, t))

def k.member(~K: Data, ~cmp: K -> K -> Cmp, +x: Crdt.KCounter<K>, ys: List<&2, Crdt.KCounter<K>>) -> Bool:
  match ys:
    case Nil{}:
      False{}
    case Con{y, t}:
      Bool.or(k.same(~K, ~cmp, x, y), k.member(~K, ~cmp, x, t))

# True when every state in xs is also in ys.
def k.covers(~K: Data, ~cmp: K -> K -> Cmp, xs: List<&2, Crdt.KCounter<K>>, +ys: List<&2, Crdt.KCounter<K>>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{x, t}:
      Bool.and(k.member(~K, ~cmp, x, ys), k.covers(~K, ~cmp, t, ys))

law k_merge_comm:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for a: Crdt.KCounter<K>
  for b: Crdt.KCounter<K>
  for +k: K
  {Crdt.KCounter.get(~K, ~cmp, Crdt.KCounter.merge(~K, ~cmp, a, b), k)
   == Crdt.KCounter.get(~K, ~cmp, Crdt.KCounter.merge(~K, ~cmp, b, a), k) : U32}

law k_merge_assoc:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for a: Crdt.KCounter<K>
  for b: Crdt.KCounter<K>
  for c: Crdt.KCounter<K>
  for +k: K
  {Crdt.KCounter.get(~K, ~cmp, Crdt.KCounter.merge(~K, ~cmp, Crdt.KCounter.merge(~K, ~cmp, a, b), c), k)
   == Crdt.KCounter.get(~K, ~cmp, Crdt.KCounter.merge(~K, ~cmp, a, Crdt.KCounter.merge(~K, ~cmp, b, c)), k) : U32}

law k_merge_idem:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for a: Crdt.KCounter<K>
  for +k: K
  {Crdt.KCounter.get(~K, ~cmp, Crdt.KCounter.merge(~K, ~cmp, a, a), k) == Crdt.KCounter.get(~K, ~cmp, a, k) : U32}

# Merge is a least upper bound in the order le.
law k_merge_upper_l:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~refl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for a: Crdt.KCounter<K>
  for b: Crdt.KCounter<K>
  {Crdt.KCounter.le(~K, ~cmp, a, Crdt.KCounter.merge(~K, ~cmp, a, b)) == True{} : Bool}

law k_merge_upper_r:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~refl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for a: Crdt.KCounter<K>
  for b: Crdt.KCounter<K>
  {Crdt.KCounter.le(~K, ~cmp, b, Crdt.KCounter.merge(~K, ~cmp, a, b)) == True{} : Bool}

law k_merge_least:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for a: Crdt.KCounter<K>
  for b: Crdt.KCounter<K>
  for c: Crdt.KCounter<K>
  for ha: {Crdt.KCounter.le(~K, ~cmp, a, c) == True{} : Bool}
  for hb: {Crdt.KCounter.le(~K, ~cmp, b, c) == True{} : Bool}
  {Crdt.KCounter.le(~K, ~cmp, Crdt.KCounter.merge(~K, ~cmp, a, b), c) == True{} : Bool}

law k_inc_grows:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~refl: @x: K -> {cmp(x, x) == EQ{} : Cmp}
  for s: Crdt.KCounter<K>
  for k: K
  {k.grows(~K, ~cmp, s, Crdt.KCounter.inc(~K, ~cmp, s, k)) == True{} : Bool}

law k_merge_valid:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for ~flip: @x: K -> @y: K -> {cmp(y, x) == flip(cmp(x, y)) : Cmp}
  for a: Crdt.KCounter<K>
  for b: Crdt.KCounter<K>
  for ha: {Crdt.KCounter.valid(~K, ~cmp, a) == True{} : Bool}
  for hb: {Crdt.KCounter.valid(~K, ~cmp, b) == True{} : Bool}
  {Crdt.KCounter.valid(~K, ~cmp, Crdt.KCounter.merge(~K, ~cmp, a, b)) == True{} : Bool}

law k_inc_valid:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~flip: @x: K -> @y: K -> {cmp(y, x) == flip(cmp(x, y)) : Cmp}
  for s: Crdt.KCounter<K>
  for k: K
  for h: {Crdt.KCounter.valid(~K, ~cmp, s) == True{} : Bool}
  {k.ok_valid(~K, ~cmp, Crdt.KCounter.inc(~K, ~cmp, s, k)) == True{} : Bool}

# Two replicas that received the same states, in any order and with any
# duplicates, hold the same counter.
law k_converge:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~eq: @x: K -> @y: K -> {cmp(x, y) == EQ{} : Cmp} -> {x == y : K}
  for xs: List<&2, Crdt.KCounter<K>>
  for ys: List<&2, Crdt.KCounter<K>>
  for hx: {k.covers(~K, ~cmp, xs, ys) == True{} : Bool}
  for hy: {k.covers(~K, ~cmp, ys, xs) == True{} : Bool}
  for +k: K
  {Crdt.KCounter.get(~K, ~cmp, Crdt.KCounter.merge_all(~K, ~cmp, xs), k)
   == Crdt.KCounter.get(~K, ~cmp, Crdt.KCounter.merge_all(~K, ~cmp, ys), k) : U32}

law k_from_cbor_valid:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~dec: Cbor.Val -> Maybe<&2, K>
  for v: Cbor.Val
  for cap: U32
  {k.ok_valid(~K, ~cmp, Crdt.KCounter.from_cbor(~K, ~cmp, ~dec, v, cap)) == True{} : Bool}

law k_cbor_roundtrip:
  for ~K: Data
  for ~cmp: K -> K -> Cmp
  for ~enc: K -> Cbor.Val
  for ~dec: Cbor.Val -> Maybe<&2, K>
  for ~rt: @x: K -> {dec(enc(x)) == Some{x} : Maybe<&2, K>}
  for s: Crdt.KCounter<K>
  for cap: U32
  for hv: {Crdt.KCounter.valid(~K, ~cmp, s) == True{} : Bool}
  for hc: {U32.is_le(Crdt.KCounter.size(K, s), cap) == True{} : Bool}
  {Crdt.KCounter.from_cbor(~K, ~cmp, ~dec, Crdt.KCounter.to_cbor(~K, ~enc, s), cap)
   == Some{s} : Maybe<&2, Crdt.KCounter<K>>}

def kc(+id: U32, +n: U32, r: Crdt.KCounter<U32>) -> Crdt.KCounter<U32>:
  Crdt.KCon{id, n, r}

def k0() -> Crdt.KCounter<U32>:
  Crdt.KNil{}

law k_inc_sparse:
  {Crdt.KCounter.inc(~U32, ~U32.cmp, kc(7, 2, k0()), 1000000)
   == Some{kc(7, 2, kc(1000000, 1, k0()))} : Maybe<&2, Crdt.KCounter<U32>>}

law k_inc_overflow:
  {Crdt.KCounter.inc(~U32, ~U32.cmp, kc(7, 4294967295, k0()), 7) == None{} : Maybe<&2, Crdt.KCounter<U32>>}

law k_get_missing:
  {Crdt.KCounter.get(~U32, ~U32.cmp, kc(7, 2, k0()), 8) == 0 : U32}

law k_merge_fixture:
  {Crdt.KCounter.merge(~U32, ~U32.cmp, kc(3, 1, kc(900, 5, k0())), kc(3, 4, kc(40, 2, k0())))
   == kc(3, 4, kc(40, 2, kc(900, 5, k0()))) : Crdt.KCounter<U32>}

law k_value_sum:
  {Crdt.KCounter.value(U32, kc(3, 4, kc(40, 2, kc(900, 5, k0())))) == Some{11} : Maybe<&2, U32>}

def kv(+id: U32, +n: U32) -> Cbor.Val & Cbor.Val:
  (uint(id), uint(n))

def kdec(v: Cbor.Val) -> Maybe<&2, U32>:
  match v:
    case Cbor.UInt{w}:
      Cbor.W64{+hi, +lo} = w
      Bool.pick(Maybe<&2, U32>, U32.is_eq(hi, 0), Some{lo}, None{})
    case _:
      None{}

def kfrom(v: Cbor.Val, +cap: U32) -> Maybe<&2, Crdt.KCounter<U32>>:
  Crdt.KCounter.from_cbor(~U32, ~U32.cmp, ~kdec, v, cap)

law k_from_cbor_accepts:
  {kfrom(Cbor.Obj{[kv(3, 1), kv(900, 5)]}, 2) == Some{kc(3, 1, kc(900, 5, k0()))} : Maybe<&2, Crdt.KCounter<U32>>}

law k_from_cbor_unsorted:
  {kfrom(Cbor.Obj{[kv(900, 5), kv(3, 1)]}, 8) == None{} : Maybe<&2, Crdt.KCounter<U32>>}

law k_from_cbor_duplicate:
  {kfrom(Cbor.Obj{[kv(3, 1), kv(3, 2)]}, 8) == None{} : Maybe<&2, Crdt.KCounter<U32>>}

law k_from_cbor_zero:
  {kfrom(Cbor.Obj{[kv(3, 0)]}, 8) == None{} : Maybe<&2, Crdt.KCounter<U32>>}

law k_from_cbor_over_cap:
  {kfrom(Cbor.Obj{[kv(3, 1), kv(900, 5)]}, 1) == None{} : Maybe<&2, Crdt.KCounter<U32>>}

law k_from_cbor_bad_id:
  {kfrom(Cbor.Obj{[(Cbor.NInt{Cbor.W64{0, 0}}, uint(1))]}, 8) == None{} : Maybe<&2, Crdt.KCounter<U32>>}

law k_from_cbor_not_map:
  {kfrom(Cbor.Arr{[uint(3)]}, 8) == None{} : Maybe<&2, Crdt.KCounter<U32>>}
