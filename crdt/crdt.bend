# Replicated data types: grow-only counters with proved merges. Source: https://github.com/paymog/bend-kit/tree/main/crdt
#
# A GCounter is a list of U32 counts. Entry i is the count of replica i, and a
# missing entry counts as 0. This is the state-based G-Counter of Shapiro et
# al. (2011). Each replica must increment only its own entry. A KCounter is the
# same counter keyed by sparse replica IDs of any Data type.
import Base
import bend-kit-bytes@0.3.3.0/bytes.bend as Bytes
import bend-kit-cbor@0.3.0.0/cbor.bend as Cbor

# The counter with no increments.
def GCounter.new() -> List<&2, U32>:
  Nil{}

# The count of replica i.
def GCounter.get(s: List<&2, U32>, i: Nat) -> U32:
  match s i:
    case Nil{} _:
      0
    case Con{c, t} 0n:
      c
    case Con{c, t} 1n+p:
      GCounter.get(t, p)

# Component-wise maximum. It is commutative, associative, and idempotent.
def GCounter.merge(a: List<&2, U32>, b: List<&2, U32>) -> List<&2, U32>:
  match a b:
    case Nil{} Nil{}:
      Nil{}
    case Nil{} Con{y, ys}:
      Con{y, ys}
    case Con{x, xs} Nil{}:
      Con{x, xs}
    case Con{x, xs} Con{y, ys}:
      Con{U32.max(x, y), GCounter.merge(xs, ys)}

# The merge of every state in the list.
def GCounter.merge_all(xs: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{x, t}:
      GCounter.merge(x, GCounter.merge_all(t))

# Zeros for replicas 0 to i - 1, then 1 for replica i.
def GCounter.pad(i: Nat) -> List<&2, U32>:
  match i:
    case 0n:
      [1]
    case 1n+p:
      Con{0, GCounter.pad(p)}

def GCounter.cons(c: U32, m: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match m:
    case None{}:
      None{}
    case Some{t}:
      Some{Con{c, t}}

# ok is false when n wrapped to 0.
def GCounter.inc.at(ok: Bool, n: U32, t: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      Some{Con{n, t}}
    case False{}:
      None{}

# Adds 1 to the count of replica i. None when that count is 4294967295.
def GCounter.inc(s: List<&2, U32>, i: Nat) -> Maybe<&2, List<&2, U32>>:
  match s i:
    case Nil{} _:
      Some{GCounter.pad(i)}
    case Con{+c, t} 0n:
      GCounter.inc.at(U32.is_lt(c, U32.inc(c)), U32.inc(c), t)
    case Con{c, t} 1n+p:
      GCounter.cons(c, GCounter.inc(t, p))

def GCounter.add(m: Maybe<&2, U32>, +c: U32) -> Maybe<&2, U32>:
  match m:
    case None{}:
      None{}
    case Some{+a}:
      Bool.pick(Maybe<&2, U32>, U32.is_le(a, (a + c : U32)), Some{(a + c : U32)}, None{})

def GCounter.value.go(s: List<&2, U32>, acc: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s:
    case Nil{}:
      acc
    case Con{c, t}:
      GCounter.value.go(t, GCounter.add(acc, c))

# The sum of all counts. None when the sum does not fit in a U32.
def GCounter.value(s: List<&2, U32>) -> Maybe<&2, U32>:
  GCounter.value.go(s, Some{0})

# True when a is at most b in every entry.
def GCounter.le(a: List<&2, U32>, b: List<&2, U32>) -> Bool:
  match a b:
    case Nil{} _:
      True{}
    case Con{x, xs} Nil{}:
      Bool.and(U32.is_eq(x, 0), GCounter.le(xs, Nil{}))
    case Con{x, xs} Con{y, ys}:
      Bool.and(U32.is_le(x, y), GCounter.le(xs, ys))

def GCounter.valid.go(t: List<&2, U32>, last: U32) -> Bool:
  match t:
    case Nil{}:
      U32.is_ne(last, 0)
    case Con{c, u}:
      GCounter.valid.go(u, c)

# A valid state has no trailing 0, so each count vector has one form.
def GCounter.valid(s: List<&2, U32>) -> Bool:
  match s:
    case Nil{}:
      True{}
    case Con{c, t}:
      GCounter.valid.go(t, c)

def GCounter.size(s: List<&2, U32>) -> U32:
  match s:
    case Nil{}:
      0
    case Con{c, t}:
      (1 + GCounter.size(t) : U32)

def GCounter.to_cbor.items(s: List<&2, U32>) -> List<&1, Cbor.Val>:
  match s:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      Con{Cbor.UInt{Cbor.W64{0, c}}, GCounter.to_cbor.items(t)}

# A CBOR array of unsigned integers: the count of replica i is item i.
def GCounter.to_cbor(s: List<&2, U32>) -> Cbor.Val:
  Cbor.Arr{GCounter.to_cbor.items(s)}

def GCounter.from_cbor.word(ok: Bool, lo: U32, rest: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      GCounter.cons(lo, rest)
    case False{}:
      None{}

def GCounter.from_cbor.item(v: Cbor.Val, rest: Maybe<&2, List<&2, U32>>) -> Maybe<&2, List<&2, U32>>:
  match v:
    case Cbor.UInt{w}:
      Cbor.W64{+hi, lo} = w
      GCounter.from_cbor.word(U32.is_eq(hi, 0), lo, rest)
    case _:
      None{}

def GCounter.from_cbor.items(xs: List<&1, Cbor.Val>) -> Maybe<&2, List<&2, U32>>:
  match xs:
    case Nil{}:
      Some{Nil{}}
    case Con{v, t}:
      GCounter.from_cbor.item(v, GCounter.from_cbor.items(t))

def GCounter.from_cbor.gate(ok: Bool, s: List<&2, U32>) -> Maybe<&2, List<&2, U32>>:
  match ok:
    case True{}:
      Some{s}
    case False{}:
      None{}

def GCounter.from_cbor.check(m: Maybe<&2, List<&2, U32>>, +cap: U32) -> Maybe<&2, List<&2, U32>>:
  match m:
    case None{}:
      None{}
    case Some{+s}:
      GCounter.from_cbor.gate(Bool.and(GCounter.valid(s), U32.is_le(GCounter.size(s), cap)), s)

# A valid state with at most cap replicas, or None.
def GCounter.from_cbor(v: Cbor.Val, +cap: U32) -> Maybe<&2, List<&2, U32>>:
  match v:
    case Cbor.Arr{xs}:
      GCounter.from_cbor.check(GCounter.from_cbor.items(xs), cap)
    case _:
      None{}

# Always Some: every item is an unsigned integer.
def GCounter.encode(s: List<&2, U32>) -> Maybe<&1, Bytes.Bytes>:
  Cbor.encode(GCounter.to_cbor(s))

def GCounter.decode.go(m: Maybe<&1, Cbor.Val>, +cap: U32) -> Maybe<&2, List<&2, U32>>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      GCounter.from_cbor(v, cap)

# CBOR bytes to a valid state with at most cap replicas, or None.
def GCounter.decode(b: Bytes.Bytes, +cap: U32) -> Maybe<&2, List<&2, U32>>:
  GCounter.decode.go(Cbor.decode(b), cap)

# A G-Counter keyed by replica IDs. A valid state lists IDs in ascending cmp
# order, each with a count above 0.
type KCounter<-K: Data> is Data:
  KNil{}
  KCon{id: K, count: U32, rest: KCounter<K>}

# The counter with no increments.
def KCounter.new(-K: Data) -> KCounter<K>:
  KNil{}

# cmp(x, first ID of b), or EQ when b is empty.
def KCounter.head(~K: Data, ~cmp: K -> K -> Cmp, +x: K, b: KCounter<K>) -> Cmp:
  match b:
    case KNil{}:
      EQ{}
    case KCon{y, d, t}:
      cmp(x, y)

# The comparison of the first IDs of a and b, or EQ when either is empty.
def KCounter.heads(~K: Data, ~cmp: K -> K -> Cmp, a: KCounter<K>, b: KCounter<K>) -> Cmp:
  match a:
    case KNil{}:
      EQ{}
    case KCon{x, c, r}:
      KCounter.head(~K, ~cmp, x, b)

def KCounter.hit(c: Cmp, n: U32) -> U32:
  match c:
    case LT{}:
      0
    case EQ{}:
      n
    case GT{}:
      0

# The count of replica k: the largest count under an ID that cmp makes equal to k.
def KCounter.get(~K: Data, ~cmp: K -> K -> Cmp, s: KCounter<K>, +k: K) -> U32:
  match s:
    case KNil{}:
      0
    case KCon{id, c, r}:
      U32.max(KCounter.hit(cmp(k, id), c), KCounter.get(~K, ~cmp, r, k))

# q is KCounter.heads(a, b). Passing it in lets match pick the step without closures.
def KCounter.merge.go(~K: Data, ~cmp: K -> K -> Cmp, +a: KCounter<K>, +b: KCounter<K>, q: Cmp) -> KCounter<K>:
  match a b q:
    case KNil{} _ _:
      b
    case KCon{x, c, r} KNil{} _:
      KCon{x, c, r}
    case KCon{+x, +c, +r} KCon{+y, +d, +t} LT{}:
      KCon{x, c, KCounter.merge.go(~K, ~cmp, r, KCon{y, d, t}, KCounter.heads(~K, ~cmp, r, KCon{y, d, t}))}
    case KCon{+x, +c, +r} KCon{+y, +d, +t} EQ{}:
      KCon{x, U32.max(c, d), KCounter.merge.go(~K, ~cmp, r, t, KCounter.heads(~K, ~cmp, r, t))}
    case KCon{+x, +c, +r} KCon{+y, +d, +t} GT{}:
      KCon{y, d, KCounter.merge.go(~K, ~cmp, KCon{x, c, r}, t, KCounter.head(~K, ~cmp, x, t))}

# The union of two ID-sorted states, with the maximum count where IDs are equal.
def KCounter.merge(~K: Data, ~cmp: K -> K -> Cmp, +a: KCounter<K>, +b: KCounter<K>) -> KCounter<K>:
  KCounter.merge.go(~K, ~cmp, a, b, KCounter.heads(~K, ~cmp, a, b))

# The merge of every state in the list.
def KCounter.merge_all(~K: Data, ~cmp: K -> K -> Cmp, xs: List<&2, KCounter<K>>) -> KCounter<K>:
  match xs:
    case Nil{}:
      KNil{}
    case Con{x, t}:
      KCounter.merge(~K, ~cmp, x, KCounter.merge_all(~K, ~cmp, t))

def KCounter.cons(-K: Data, k: K, c: U32, m: Maybe<&2, KCounter<K>>) -> Maybe<&2, KCounter<K>>:
  match m:
    case None{}:
      None{}
    case Some{t}:
      Some{KCon{k, c, t}}

# ok is false when n wrapped to 0.
def KCounter.inc.at(-K: Data, ok: Bool, x: K, n: U32, r: KCounter<K>) -> Maybe<&2, KCounter<K>>:
  match ok:
    case True{}:
      Some{KCon{x, n, r}}
    case False{}:
      None{}

# q is KCounter.head(k, s).
def KCounter.inc.go(~K: Data, ~cmp: K -> K -> Cmp, s: KCounter<K>, +k: K, q: Cmp) -> Maybe<&2, KCounter<K>>:
  match s q:
    case KNil{} _:
      Some{KCon{k, 1, KNil{}}}
    case KCon{+x, +c, +r} LT{}:
      Some{KCon{k, 1, KCon{x, c, r}}}
    case KCon{+x, +c, +r} EQ{}:
      KCounter.inc.at(K, U32.is_lt(c, U32.inc(c)), x, U32.inc(c), r)
    case KCon{+x, +c, +r} GT{}:
      KCounter.cons(K, x, c, KCounter.inc.go(~K, ~cmp, r, k, KCounter.head(~K, ~cmp, k, r)))

# Adds 1 to the count of replica k. None when that count is 4294967295.
def KCounter.inc(~K: Data, ~cmp: K -> K -> Cmp, +s: KCounter<K>, +k: K) -> Maybe<&2, KCounter<K>>:
  KCounter.inc.go(~K, ~cmp, s, k, KCounter.head(~K, ~cmp, k, s))

def KCounter.value.go(-K: Data, s: KCounter<K>, acc: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s:
    case KNil{}:
      acc
    case KCon{x, c, r}:
      KCounter.value.go(K, r, GCounter.add(acc, c))

# The sum of all counts. None when the sum does not fit in a U32.
def KCounter.value(-K: Data, s: KCounter<K>) -> Maybe<&2, U32>:
  KCounter.value.go(K, s, Some{0})

# True when each count in a is at most the count of its ID in b.
def KCounter.le(~K: Data, ~cmp: K -> K -> Cmp, a: KCounter<K>, +b: KCounter<K>) -> Bool:
  match a:
    case KNil{}:
      True{}
    case KCon{x, c, r}:
      Bool.and(U32.is_le(c, KCounter.get(~K, ~cmp, b, x)), KCounter.le(~K, ~cmp, r, b))

# True when s is empty or its first ID is above lo.
def KCounter.above(~K: Data, ~cmp: K -> K -> Cmp, s: KCounter<K>, +lo: K) -> Bool:
  match s:
    case KNil{}:
      True{}
    case KCon{x, c, r}:
      Cmp.is_lt(cmp(lo, x))

# A valid state has strictly ascending IDs and no 0 count, so each counter has one form.
def KCounter.valid(~K: Data, ~cmp: K -> K -> Cmp, s: KCounter<K>) -> Bool:
  match s:
    case KNil{}:
      True{}
    case KCon{+x, c, +r}:
      Bool.and(Bool.and(U32.is_ne(c, 0), KCounter.above(~K, ~cmp, r, x)), KCounter.valid(~K, ~cmp, r))

def KCounter.size(-K: Data, s: KCounter<K>) -> U32:
  match s:
    case KNil{}:
      0
    case KCon{x, c, r}:
      (1 + KCounter.size(K, r) : U32)

def KCounter.to_cbor.items(~K: Data, ~enc: K -> Cbor.Val, s: KCounter<K>) -> List<&1, Cbor.Val & Cbor.Val>:
  match s:
    case KNil{}:
      Nil{}
    case KCon{x, c, r}:
      Con{(enc(x), Cbor.UInt{Cbor.W64{0, c}}), KCounter.to_cbor.items(~K, ~enc, r)}

# A CBOR map from each encoded ID to its count, in ID order.
def KCounter.to_cbor(~K: Data, ~enc: K -> Cbor.Val, s: KCounter<K>) -> Cbor.Val:
  Cbor.Obj{KCounter.to_cbor.items(~K, ~enc, s)}

def KCounter.from_cbor.word(-K: Data, ok: Bool, mk: Maybe<&2, K>, lo: U32, rest: Maybe<&2, KCounter<K>>) -> Maybe<&2, KCounter<K>>:
  match ok mk:
    case True{} Some{k}:
      KCounter.cons(K, k, lo, rest)
    case _ _:
      None{}

def KCounter.from_cbor.count(-K: Data, v: Cbor.Val, mk: Maybe<&2, K>, rest: Maybe<&2, KCounter<K>>) -> Maybe<&2, KCounter<K>>:
  match v:
    case Cbor.UInt{w}:
      Cbor.W64{+hi, lo} = w
      KCounter.from_cbor.word(K, U32.is_eq(hi, 0), mk, lo, rest)
    case _:
      None{}

def KCounter.from_cbor.items(~K: Data, ~dec: Cbor.Val -> Maybe<&2, K>, xs: List<&1, Cbor.Val & Cbor.Val>) -> Maybe<&2, KCounter<K>>:
  match xs:
    case Nil{}:
      Some{KNil{}}
    case Con{(k, v), t}:
      KCounter.from_cbor.count(K, v, dec(k), KCounter.from_cbor.items(~K, ~dec, t))

def KCounter.from_cbor.gate(-K: Data, ok: Bool, s: KCounter<K>) -> Maybe<&2, KCounter<K>>:
  match ok:
    case True{}:
      Some{s}
    case False{}:
      None{}

def KCounter.from_cbor.check(~K: Data, ~cmp: K -> K -> Cmp, m: Maybe<&2, KCounter<K>>, +cap: U32) -> Maybe<&2, KCounter<K>>:
  match m:
    case None{}:
      None{}
    case Some{+s}:
      KCounter.from_cbor.gate(K, Bool.and(KCounter.valid(~K, ~cmp, s), U32.is_le(KCounter.size(K, s), cap)), s)

# A valid state with at most cap replicas, or None. dec reads one ID.
def KCounter.from_cbor(
  ~K: Data, ~cmp: K -> K -> Cmp, ~dec: Cbor.Val -> Maybe<&2, K>, v: Cbor.Val, +cap: U32
) -> Maybe<&2, KCounter<K>>:
  match v:
    case Cbor.Obj{kvs}:
      KCounter.from_cbor.check(~K, ~cmp, KCounter.from_cbor.items(~K, ~dec, kvs), cap)
    case _:
      None{}

# None only when enc gives a value with no CBOR form.
def KCounter.encode(~K: Data, ~enc: K -> Cbor.Val, s: KCounter<K>) -> Maybe<&1, Bytes.Bytes>:
  Cbor.encode(KCounter.to_cbor(~K, ~enc, s))

def KCounter.decode.go(
  ~K: Data, ~cmp: K -> K -> Cmp, ~dec: Cbor.Val -> Maybe<&2, K>, m: Maybe<&1, Cbor.Val>, +cap: U32
) -> Maybe<&2, KCounter<K>>:
  match m:
    case None{}:
      None{}
    case Some{v}:
      KCounter.from_cbor(~K, ~cmp, ~dec, v, cap)

# CBOR bytes to a valid state with at most cap replicas, or None.
def KCounter.decode(
  ~K: Data, ~cmp: K -> K -> Cmp, ~dec: Cbor.Val -> Maybe<&2, K>, b: Bytes.Bytes, +cap: U32
) -> Maybe<&2, KCounter<K>>:
  KCounter.decode.go(~K, ~cmp, ~dec, Cbor.decode(b), cap)
