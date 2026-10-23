import Base
import bend-kit-cbor@0.2.0.0/cbor.bend as Cbor
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
