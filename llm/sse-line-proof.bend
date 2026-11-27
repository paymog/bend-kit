import Base
import ./sse.bend as Sse
import ./sse-packed-proof.bend as P
import ./sse-offset-proof.bend as Offset
import ../bytes/append-proof.bend as Packed
import ../lemmas/array.bend as Tree
import ../bits/array-proof.bend as Bound
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas

def prefix_head_bound(+p: Nat, +s: U32, +last: U32,
  end: MNat.le(Nat.add(1n+p, U32.to_nat(s)), U32.to_nat(last))) -> MNat.lt(U32.to_nat(s), U32.to_nat(last)):
  MNat.lt_of_lt_of_le(U32.to_nat(s), Nat.add(1n+p, U32.to_nat(s)), U32.to_nat(last),
    MNat.lt_of_lt_of_le(U32.to_nat(s), 1n+U32.to_nat(s), Nat.add(1n+p, U32.to_nat(s)), MNat.lt_succ_self(U32.to_nat(s)),
      MNat.add_le_add_right(1n, 1n+p, U32.to_nat(s), MNat.le_add_right(1n, p))), end)

def prefix_tail_bound(+p: Nat, +s: U32, +last: U32, +limit: Nat,
  +end: MNat.le(Nat.add(1n+p, U32.to_nat(s)), U32.to_nat(last)), hl: MNat.lt(U32.to_nat(last), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(Nat.add(p, U32.to_nat((s + 1 : U32))), U32.to_nat(last)):
  %Equal.sym(Nat, U32.to_nat((s + 1 : U32)), 1n+U32.to_nat(s), Packed.add_one_nat(s,
    MNat.lt_of_lt_of_le(1n+U32.to_nat(s), limit, Lemmas.pow2(32n),
      Offset.increment_bound(p, s, limit, MNat.lt_of_le_of_lt(Nat.add(1n+p, U32.to_nat(s)), U32.to_nat(last), limit, end, hl)), hu))) :
    MNat.le(Nat.add(p, _), U32.to_nat(last))
  %Equal.sym(Nat, Nat.add(p, 1n+U32.to_nat(s)), 1n+Nat.add(p, U32.to_nat(s)), MNat.add_succ(p, U32.to_nat(s))) : MNat.le(_, U32.to_nat(last))
  end

def poke_prefix_cons(+tail: String, +src: Tree.Tree<U32>, +s: U32, +last: U32, +value: U32, +c: U32, +depth: Nat, +limit: Nat,
  hd: MNat.lt(depth, 32n), +hl: MNat.lt(U32.to_nat(last), limit), +hc: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)),
  +before: MNat.lt(U32.to_nat(s), U32.to_nat(last)), head: {Packed.peek(src, s) == c : U32},
  more: Bound.shape(depth, Packed.as_bits(src)) -> Packed.Reads(tail, Packed.poke(src, last, value), (s + 1 : U32)),
  shapes: Bound.shape(depth, Packed.as_bits(src)) & Bound.shape(depth, Packed.as_bits(src))) ->
  Packed.Reads(SCon{Chr{c}, tail}, Packed.poke(src, last, value), s):
  (ha, hb) = shapes
  Packed.reads_cons(tail, Packed.poke(src, last, value), s, c,
    Equal.trans(U32, Packed.peek(Packed.poke(src, last, value), s), Packed.peek(src, s), c,
      Packed.poke_other(src, last, s, value, Packed.byte_apart_bounded(depth, src, last, s, ha, hd,
        MNat.lt_of_lt_of_le(U32.to_nat(last), limit, Nat.mul(Lemmas.pow2(depth), 4n), hl, hc),
        MNat.lt_trans(U32.to_nat(s), U32.to_nat(last), Nat.mul(Lemmas.pow2(depth), 4n), before,
          MNat.lt_of_lt_of_le(U32.to_nat(last), limit, Nat.mul(Lemmas.pow2(depth), 4n), hl, hc)), e => Packed.u32_ne_gt(last, s, before, e))), head), more(hb))

def poke_prefix(text: String, +src: Tree.Tree<U32>, +s: U32, +last: U32, +value: U32, +depth: Nat, +limit: Nat,
  +hd: MNat.lt(depth, 32n), +hl: MNat.lt(U32.to_nat(last), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +hc: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)),
  +end: MNat.le(Nat.add(String.length(text), U32.to_nat(s)), U32.to_nat(last)),
  shape: Bound.shape(depth, Packed.as_bits(src)), reads: Packed.Reads(text, src, s)) ->
  Packed.Reads(text, Packed.poke(src, last, value), s):
  match text:
    case SNil{}:
      Unit{}
    case SCon{Chr{+c}, +tail}:
      (head, rest) = reads
      poke_prefix_cons(tail, src, s, last, value, c, depth, limit, hd, hl, hc, prefix_head_bound(String.length(tail), s, last, end), head,
        h => poke_prefix(tail, src, (s + 1 : U32), last, value, depth, limit, hd, hl, hu, hc, prefix_tail_bound(String.length(tail), s, last, limit, end, hl, hu), h, rest),
        Bound.shape_copy(depth, Packed.as_bits(src), shape))

def trim_bridge(+len: U32, +src: Tree.Tree<U32>) ->
  {Sse.trim(Bytes.Bytes{len, Tree.reify(U32, src)}) ==
    Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, Packed.poke(src, (len - 1 : U32), 0))} : Bytes.Bytes}:
  Equal.cong(Array<U32>, Bytes.Bytes, a => Bytes.Bytes{(len - 1 : U32), a},
    Bytes.poke(Tree.reify(U32, src), (len - 1 : U32), 0), Tree.reify(U32, Packed.poke(src, (len - 1 : U32), 0)), P.poke_bridge(src, (len - 1 : U32), 0))

def trim_snapshot_type(+text: String, +len: U32, +src: Tree.Tree<U32>) -> Type:
  &out: Tree.Tree<U32> ->
    {Sse.trim(Bytes.Bytes{len, Tree.reify(U32, src)}) == Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)} : Bytes.Bytes} &
    Packed.Reads(text, out, 0)

def trim_snapshot(+text: String, +len: U32, +src: Tree.Tree<U32>, +depth: Nat, +limit: Nat,
  hd: MNat.lt(depth, 32n), hl: MNat.lt(U32.to_nat((len - 1 : U32)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  hc: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), length: {U32.to_nat((len - 1 : U32)) == String.length(text) : Nat},
  shape: Bound.shape(depth, Packed.as_bits(src)), reads: Packed.Reads(text, src, 0)) ->
  trim_snapshot_type(text, len, src):
  (Packed.poke(src, (len - 1 : U32), 0), trim_bridge(len, src),
    poke_prefix(text, src, 0, (len - 1 : U32), 0, depth, limit, hd, hl, hu, hc,
      (%length : MNat.le(Nat.add(_, 0n), U32.to_nat((len - 1 : U32)))
       %Equal.sym(Nat, Nat.add(U32.to_nat((len - 1 : U32)), 0n), U32.to_nat((len - 1 : U32)), MNat.add_zero(U32.to_nat((len - 1 : U32)))) : MNat.le(_, U32.to_nat((len - 1 : U32)))
       MNat.le_refl(U32.to_nat((len - 1 : U32)))), shape, reads))

def trim_string_snapshot(+text: String, +len: U32, +src: Tree.Tree<U32>, +limit: Nat,
  +length: {U32.to_nat((len - 1 : U32)) == String.length(text) : Nat},
  +hl: MNat.lt(U32.to_nat((len - 1 : U32)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  snapshot: trim_snapshot_type(text, len, src)) ->
  {Bytes.to_string(Sse.trim(Bytes.Bytes{len, Tree.reify(U32, src)})) == text : String}:
  (+out, (eq, reads)) = snapshot
  Equal.trans(String, Bytes.to_string(Sse.trim(Bytes.Bytes{len, Tree.reify(U32, src)})), Bytes.to_string(Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)}), text,
    Equal.cong(Bytes.Bytes, String, Bytes.to_string, Sse.trim(Bytes.Bytes{len, Tree.reify(U32, src)}), Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)}, eq),
    Equal.trans(String, Bytes.to_string(Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)}), Packed.to_string((len - 1 : U32), out), text,
      P.to_bridge((len - 1 : U32), out),
      Packed.reads_to(text, out, (len - 1 : U32), limit, length, hu,
        (%length : MNat.lt(Nat.add(_, 0n), limit)
         %Equal.sym(Nat, Nat.add(U32.to_nat((len - 1 : U32)), 0n), U32.to_nat((len - 1 : U32)), MNat.add_zero(U32.to_nat((len - 1 : U32)))) : MNat.lt(_, limit); hl), reads)))

def trim_string(+text: String, +len: U32, +src: Tree.Tree<U32>, +depth: Nat, +limit: Nat,
  hd: MNat.lt(depth, 32n), +hl: MNat.lt(U32.to_nat((len - 1 : U32)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  hc: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +length: {U32.to_nat((len - 1 : U32)) == String.length(text) : Nat},
  shape: Bound.shape(depth, Packed.as_bits(src)), reads: Packed.Reads(text, src, 0)) ->
  {Bytes.to_string(Sse.trim(Bytes.Bytes{len, Tree.reify(U32, src)})) == text : String}:
  trim_string_snapshot(text, len, src, limit, length, hl, hu, trim_snapshot(text, len, src, depth, limit, hd, hl, hu, hc, length, shape, reads))

def message_text(m: Maybe<&1, Sse.Message>) -> Maybe<&1, String & String & String>:
  match m:
    case None{}:
      None{}
    case Some{Sse.Message{name, data, id}}:
      Some{(name, Bytes.to_string(data), id)}

def dispatch_text(r: Sse.St & Maybe<&1, Sse.Message>) -> Maybe<&1, String & String & String>:
  (st, m) = r
  message_text(m)

def dispatch_nonempty(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, +depth: Nat, +limit: Nat,
  nonempty: {U32.is_zero(len) == False{} : Bool},
  hd: MNat.lt(depth, 32n), +hl: MNat.lt(U32.to_nat((len - 1 : U32)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  hc: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +length: {U32.to_nat((len - 1 : U32)) == String.length(text) : Nat},
  shape: Bound.shape(depth, Packed.as_bits(src)), reads: Packed.Reads(text, src, 0)) ->
  {dispatch_text(Sse.dispatch(Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry})) ==
    Some{(Bool.pick(String, String.is_empty(name), "message", name), text, id)} : Maybe<&1, String & String & String>}:
  %Equal.sym(Bool, U32.is_zero(len), False{}, nonempty) :
    {dispatch_text(Sse.dispatch.of(_, name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry)) ==
      Some{(Bool.pick(String, String.is_empty(name), "message", name), text, id)} : Maybe<&1, String & String & String>}
  Equal.cong(String, Maybe<&1, String & String & String>,
    value => Some{(Bool.pick(String, String.is_empty(name), "message", name), value, id)},
    Bytes.to_string(Sse.trim(Bytes.Bytes{len, Tree.reify(U32, src)})), text,
    trim_string(text, len, src, depth, limit, hd, hl, hu, hc, length, shape, reads))
