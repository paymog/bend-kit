import Base
import bend-mathlib@0.8.0.0/nat.bend as MNat
import ./journal.bend as J

# The laws hold over the list model: J.list.log writes frames, J.list.recover and
# J.list.replay read them. n is the frame budget; enough of it means one per record.

def cat(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  List.append(&2, U32, xs, ys)

# Every payload in rs is at most max octets long.
def fit(+max: U32, rs: List<&2, List<&2, U32>>) -> Bool:
  match rs:
    case Nil{}:
      True{}
    case Con{p, t}:
      Bool.and(Nat.is_le(List.length(&2, U32, p), U32.to_nat(max)), fit(max, t))

def records(r: J.Recovery<&2, List<&2, U32>, List<&2, U32>>) -> List<&2, List<&2, U32>>:
  J.Recovery{rs, t, s} = r
  rs

def tail(r: J.Recovery<&2, List<&2, U32>, List<&2, U32>>) -> J.Tail:
  J.Recovery{rs, t, s} = r
  t

def rest(r: J.Recovery<&2, List<&2, U32>, List<&2, U32>>) -> List<&2, U32>:
  J.Recovery{rs, t, s} = r
  s

# Each record of rs after its header in hs, one after another.
def weave(rs: List<&2, List<&2, U32>>, hs: List<&2, List<&2, U32>>) -> List<&2, U32>:
  match rs hs:
    case Nil{} u:
      Nil{}
    case Con{p, t} Nil{}:
      cat(p, weave(t, Nil{}))
    case Con{p, t} Con{h, u}:
      cat(h, cat(p, weave(t, u)))

def Rec() -> Type:
  J.Recovery<&2, List<&2, U32>, List<&2, U32>>

# Encoding and recovering a valid journal reconstructs its records.
law roundtrip:
  for n: Nat
  for +max: U32
  for +rs: List<&2, List<&2, U32>>
  for fits: {fit(max, rs) == True{} : Bool}
  for enough: MNat.le(List.length(&2, List<&2, U32>, rs), n)
  {J.list.recover(n, max, J.list.log(rs)) == J.Recovery{rs, J.Clean{}, Nil{}} : Rec()}

# A crash during the append of p leaves 1 + k of its octets. Recovery gives exactly the
# records before it, reports the tail as torn, and never applies p.
law torn:
  for n: Nat
  for +max: U32
  for +rs: List<&2, List<&2, U32>>
  for +p: List<&2, U32>
  for +k: Nat
  for fits: {fit(max, rs) == True{} : Bool}
  for enough: MNat.le(List.length(&2, List<&2, U32>, rs), n)
  for small: MNat.le(List.length(&2, U32, p), U32.to_nat(max))
  for cut: MNat.lt(1n+k, List.length(&2, U32, J.list.frame(p)))
  {J.list.recover(n, max, cat(J.list.log(rs), List.take(&2, U32, J.list.frame(p), 1n+k))) == J.Recovery{rs, J.Torn{}, List.take(&2, U32, J.list.frame(p), 1n+k)} : Rec()}

# A whole frame whose payload d fails the checksum written for p stops recovery as corrupt,
# whatever follows it. A torn-looking tail after it does not hide it.
law bad_sum:
  for n: Nat
  for +max: U32
  for +rs: List<&2, List<&2, U32>>
  for +p: List<&2, U32>
  for +d: List<&2, U32>
  for +more: List<&2, U32>
  for fits: {fit(max, rs) == True{} : Bool}
  for enough: MNat.le(List.length(&2, List<&2, U32>, rs), n)
  for small: MNat.le(List.length(&2, U32, p), U32.to_nat(max))
  for same: {List.length(&2, U32, d) == List.length(&2, U32, p) : Nat}
  for differ: {U32.is_eq(J.list.crc(d), J.list.crc(p)) == False{} : Bool}
  {J.list.recover(n, max, cat(J.list.log(rs), cat(J.list.head(U32.from_nat(List.length(&2, U32, p)), J.list.crc(p)), cat(d, more)))) == J.Recovery{rs, J.Corrupt{"checksum mismatch"}, cat(J.list.head(U32.from_nat(List.length(&2, U32, p)), J.list.crc(p)), cat(d, more))} : Rec()}

# Length fields that disagree stop recovery as corrupt, whatever follows them.
law bad_len:
  for n: Nat
  for +max: U32
  for +rs: List<&2, List<&2, U32>>
  for +x: U32
  for +y: U32
  for +more: List<&2, U32>
  for fits: {fit(max, rs) == True{} : Bool}
  for enough: MNat.le(List.length(&2, List<&2, U32>, rs), n)
  for differ: {U32.is_eq(y, U32.not(x)) == False{} : Bool}
  {J.list.recover(n, max, cat(J.list.log(rs), cat([x, 0, 0, 0, y, 0, 0, 0], more))) == J.Recovery{rs, J.Corrupt{"length check mismatch"}, cat([x, 0, 0, 0, y, 0, 0, 0], more)} : Rec()}

# A header that claims more than max octets stops recovery as corrupt, whatever follows it.
law over_max:
  for n: Nat
  for +max: U32
  for +rs: List<&2, List<&2, U32>>
  for +x: U32
  for +z: U32
  for +more: List<&2, U32>
  for fits: {fit(max, rs) == True{} : Bool}
  for enough: MNat.le(List.length(&2, List<&2, U32>, rs), n)
  for big: {U32.is_gt(x, max) == True{} : Bool}
  {J.list.recover(n, max, cat(J.list.log(rs), cat(J.list.head(x, z), more))) == J.Recovery{rs, J.Corrupt{"length over max"}, cat(J.list.head(x, z), more)} : Rec()}

# Recovery keeps order and invents nothing: the input is each recovered record after a
# header, in order, then rest. This holds for every input, valid or not.
law slices:
  for n: Nat
  for +max: U32
  for +xs: List<&2, U32>
  exs hs: List<&2, List<&2, U32>>
  {cat(weave(records(J.list.recover(n, max, xs)), hs), rest(J.list.recover(n, max, xs))) == xs : List<&2, U32>}

# Replay equals folding step over the recovered records, in order, from acc; it ends where
# recovery ends. This holds for every input, valid or not.
law replay:
  for ~A: Type
  for ~step: A -> List<&2, U32> -> A
  for n: Nat
  for +max: U32
  for +xs: List<&2, U32>
  for acc: A
  {J.list.replay(~A, ~step, n, max, xs, acc) == J.Replay{List.foldl(~&2, ~List<&2, U32>, ~A, ~step, records(J.list.recover(n, max, xs)), acc), tail(J.list.recover(n, max, xs)), rest(J.list.recover(n, max, xs))} : J.Replay<A, List<&2, U32>>}
