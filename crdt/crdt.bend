# Replicated data types: a grow-only counter with a proved merge. Source: https://github.com/paymog/bend-kit/tree/main/crdt
#
# A GCounter is a list of U32 counts. Entry i is the count of replica i, and a
# missing entry counts as 0. This is the state-based G-Counter of Shapiro et
# al. (2011). Each replica must increment only its own entry.
import Base
import bend-kit-bytes@0.3.2.0/bytes.bend as Bytes
import bend-kit-cbor@0.2.0.0/cbor.bend as Cbor

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
