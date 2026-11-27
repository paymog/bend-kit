import Base
import ./sse.bend as Sse
import ./sse-field-proof.bend as Field
import ./sse-reader-proof.bend as Reader
import ./sse-offset-proof.bend as Offset
import ./sse-buffer-proof.bend as Buffer
import ../bytes/append-proof.bend as Packed
import ../lemmas/array.bend as Tree
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ../bytes/bytes.bend as Local
import ../bits/array-proof.bend as Bound
import ./sse-scan-proof.bend as Scan

def split_span(+s: U32, +u: U32, +e: U32,
  +su: MNat.le(U32.to_nat(s), U32.to_nat(u)), +ue: MNat.le(U32.to_nat(u), U32.to_nat(e))) ->
  {Nat.add(U32.to_nat((u - s : U32)), U32.to_nat((e - u : U32))) == U32.to_nat((e - s : U32)) : Nat}:
  %Equal.sym(Nat, U32.to_nat((u - s : U32)), Nat.sub(U32.to_nat(u), U32.to_nat(s)), Lemmas.u32_sub_nat(u, s, su)) :
    {Nat.add(_, U32.to_nat((e - u : U32))) == U32.to_nat((e - s : U32)) : Nat}
  %Equal.sym(Nat, U32.to_nat((e - u : U32)), Nat.sub(U32.to_nat(e), U32.to_nat(u)), Lemmas.u32_sub_nat(e, u, ue)) :
    {Nat.add(Nat.sub(U32.to_nat(u), U32.to_nat(s)), _) == U32.to_nat((e - s : U32)) : Nat}
  Equal.trans(Nat, Nat.add(Nat.sub(U32.to_nat(u), U32.to_nat(s)), Nat.sub(U32.to_nat(e), U32.to_nat(u))), Nat.sub(U32.to_nat(e), U32.to_nat(s)), U32.to_nat((e - s : U32)),
    Reader.span_split(U32.to_nat(e), U32.to_nat(s), U32.to_nat(u), su, ue),
    Equal.sym(Nat, U32.to_nat((e - s : U32)), Nat.sub(U32.to_nat(e), U32.to_nat(s)),
      Lemmas.u32_sub_nat(e, s, MNat.le_trans(U32.to_nat(s), U32.to_nat(u), U32.to_nat(e), su, ue))))

# Keep span rewrites opaque: https://github.com/bendlang/bend/issues/1071.
def observed_relength(+n: Nat, +m: Nat, -a: Array<U32> & U32, -b: Array<U32> & U32, +s: U32, +t: U32,
  length: {n == m : Nat},
  same: {Buffer.observed(m, a, s) == Buffer.observed(m, b, t) : String}) ->
  {Buffer.observed(n, a, s) == Buffer.observed(n, b, t) : String}:
  %Equal.sym(Nat, n, m, length) : {Buffer.observed(_, a, s) == Buffer.observed(_, b, t) : String}
  same

def subspan_fuels(+p: Nat, +q: Nat, +n: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>,
  +s: U32, +t: U32, +u: U32, +v: U32, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ha: MNat.lt(Nat.add(p, U32.to_nat(s)), limit), hb: MNat.lt(Nat.add(p, U32.to_nat(t)), limit),
  ea: {Nat.add(p, U32.to_nat(s)) == U32.to_nat(u) : Nat}, eb: {Nat.add(p, U32.to_nat(t)) == U32.to_nat(v) : Nat},
  length: {Nat.add(p, q) == n : Nat},
  same: {Buffer.observed(n, Bytes.peek(Tree.reify(U32, a), s), s) == Buffer.observed(n, Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  {Buffer.observed(q, Bytes.peek(Tree.reify(U32, a), u), u) == Buffer.observed(q, Bytes.peek(Tree.reify(U32, b), v), v) : String}:
  Reader.observed_drop(p, q, a, b, s, t, u, v, limit, hu, ha, hb, ea, eb,
    observed_relength(Nat.add(p, q), n, Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t, length, same))

def observed_same_length(+n: Nat, +m: Nat, -a: Array<U32> & U32, -b: Array<U32> & U32, +s: U32, +t: U32,
  length: {n == m : Nat},
  same: {Buffer.observed(n, a, s) == Buffer.observed(m, b, t) : String}) ->
  {Buffer.observed(n, a, s) == Buffer.observed(n, b, t) : String}:
  Equal.trans(String, Buffer.observed(n, a, s), Buffer.observed(m, b, t), Buffer.observed(n, b, t), same,
    Equal.cong(Nat, String, f => Buffer.observed(f, b, t), m, n, Equal.sym(Nat, n, m, length)))

def observed_other_length(+n: Nat, +m: Nat, -a: Array<U32> & U32, -b: Array<U32> & U32, +s: U32, +t: U32,
  length: {n == m : Nat},
  same: {Buffer.observed(n, a, s) == Buffer.observed(n, b, t) : String}) ->
  {Buffer.observed(n, a, s) == Buffer.observed(m, b, t) : String}:
  Equal.trans(String, Buffer.observed(n, a, s), Buffer.observed(n, b, t), Buffer.observed(m, b, t), same,
    Equal.cong(Nat, String, f => Buffer.observed(f, b, t), n, m, length))

def endpoint_bound(+p: Nat, +s: U32, +u: U32, +e: U32, +limit: Nat,
  endpoint: {Nat.add(p, U32.to_nat(s)) == U32.to_nat(u) : Nat},
  inside: MNat.le(U32.to_nat(u), U32.to_nat(e)), bound: MNat.lt(U32.to_nat(e), limit)) ->
  MNat.lt(Nat.add(p, U32.to_nat(s)), limit):
  %Equal.sym(Nat, Nat.add(p, U32.to_nat(s)), U32.to_nat(u), endpoint) : MNat.lt(_, limit)
  MNat.lt_of_le_of_lt(U32.to_nat(u), U32.to_nat(e), limit, inside, bound)

def subspan(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32,
  +u: U32, +v: U32, +delta: Nat, +limit: Nat,
  +su: MNat.le(U32.to_nat(s), U32.to_nat(u)), +tv: MNat.le(U32.to_nat(t), U32.to_nat(v)),
  +ue: MNat.le(U32.to_nat(u), U32.to_nat(e)), +vf: MNat.le(U32.to_nat(v), U32.to_nat(f)),
  he: MNat.lt(U32.to_nat(e), limit), hf: MNat.lt(U32.to_nat(f), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  +starts: Offset.offset(delta, s, t), +middle: Offset.offset(delta, u, v), +ends: Offset.offset(delta, e, f),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  {Buffer.observed(U32.to_nat((e - u : U32)), Bytes.peek(Tree.reify(U32, a), u), u) ==
    Buffer.observed(U32.to_nat((f - v : U32)), Bytes.peek(Tree.reify(U32, b), v), v) : String}:
  +p = U32.to_nat((u - s : U32))
  +q = U32.to_nat((e - u : U32))
  +n = U32.to_nat((e - s : U32))
  +prefix = Field.relocated_width(delta, s, t, u, v, su, tv, starts, middle)
  +ea = Field.span_end(s, u, su)
  +eb = Equal.trans(Nat, Nat.add(p, U32.to_nat(t)), Nat.add(U32.to_nat((v - t : U32)), U32.to_nat(t)), U32.to_nat(v),
    Equal.cong(U32, Nat, x => Nat.add(U32.to_nat(x), U32.to_nat(t)), (u - s : U32), (v - t : U32), prefix), Field.span_end(t, v, tv))
  observed_other_length(q, U32.to_nat((f - v : U32)), Bytes.peek(Tree.reify(U32, a), u), Bytes.peek(Tree.reify(U32, b), v), u, v,
    Equal.cong(U32, Nat, U32.to_nat, (e - u : U32), (f - v : U32), Field.relocated_width(delta, u, v, e, f, ue, vf, middle, ends)),
    subspan_fuels(p, q, n, a, b, s, t, u, v, limit, hu, endpoint_bound(p, s, u, e, limit, ea, ue, he), endpoint_bound(p, t, v, f, limit, eb, vf, hf), ea, eb, split_span(s, u, e, su, ue),
      observed_same_length(n, U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t,
        Equal.cong(U32, Nat, U32.to_nat, (e - s : U32), (f - t : U32),
          Field.relocated_width(delta, s, t, e, f, MNat.le_trans(U32.to_nat(s), U32.to_nat(u), U32.to_nat(e), su, ue),
            MNat.le_trans(U32.to_nat(t), U32.to_nat(v), U32.to_nat(f), tv, vf), starts, ends)), same)))

def prefix_span(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32,
  +c: U32, +d: U32, +delta: Nat,
  +sc: MNat.le(U32.to_nat(s), U32.to_nat(c)), +td: MNat.le(U32.to_nat(t), U32.to_nat(d)),
  +ce: MNat.le(U32.to_nat(c), U32.to_nat(e)), +df: MNat.le(U32.to_nat(d), U32.to_nat(f)),
  +starts: Offset.offset(delta, s, t), +colons: Offset.offset(delta, c, d), +ends: Offset.offset(delta, e, f),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  {Buffer.observed(U32.to_nat((c - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((d - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}:
  +p = U32.to_nat((c - s : U32))
  +q = U32.to_nat((e - c : U32))
  +n = U32.to_nat((e - s : U32))
  observed_other_length(p, U32.to_nat((d - t : U32)), Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t,
    Equal.cong(U32, Nat, U32.to_nat, (c - s : U32), (d - t : U32), Field.relocated_width(delta, s, t, c, d, sc, td, starts, colons)),
    Reader.observed_take(p, q, Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t,
      observed_relength(Nat.add(p, q), n, Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t, split_span(s, c, e, sc, ce),
        observed_same_length(n, U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t,
          Equal.cong(U32, Nat, U32.to_nat, (e - s : U32), (f - t : U32),
            Field.relocated_width(delta, s, t, e, f, MNat.le_trans(U32.to_nat(s), U32.to_nat(c), U32.to_nat(e), sc, ce),
              MNat.le_trans(U32.to_nat(t), U32.to_nat(d), U32.to_nat(f), td, df), starts, ends)), same))))

def offset_right(+delta: Nat, +left: U32, +a: U32, +b: U32,
  relation: Offset.offset(delta, left, a), same: {a == b : U32}) ->
  Offset.offset(delta, left, b):
  %same : Offset.offset(delta, left, _)
  relation

def colon_fuels(+n: Nat, +m: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +delta: Nat, +limit: Nat,
  hi: MNat.lt(Nat.add(n, U32.to_nat(s)), limit), hj: MNat.lt(Nat.add(n, U32.to_nat(t)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  here: Offset.offset(delta, s, t), +length: {n == m : Nat},
  same: {Buffer.observed(n, Bytes.peek(Tree.reify(U32, a), s), s) == Buffer.observed(m, Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Offset.offset(delta, Field.colon_index(n, a, s), Field.colon_index(m, b, t)):
  offset_right(delta, Field.colon_index(n, a, s), Field.colon_index(n, b, t), Field.colon_index(m, b, t),
    Offset.colon_observed(n, a, b, delta, s, t, limit, hi, hj, hu, here,
      observed_same_length(n, m, Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t, length, same)),
    Equal.cong(Nat, U32, f => Field.colon_index(f, b, t), n, m, length))

def colon_relocated(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32, +delta: Nat, +limit: Nat,
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  he: MNat.lt(U32.to_nat(e), limit), hf: MNat.lt(U32.to_nat(f), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  +starts: Offset.offset(delta, s, t), +ends: Offset.offset(delta, e, f),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Offset.offset(delta, Field.colon_index(U32.to_nat((e - s : U32)), a, s), Field.colon_index(U32.to_nat((f - t : U32)), b, t)):
  +width = Field.relocated_width(delta, s, t, e, f, se, tf, starts, ends)
  +n = U32.to_nat((e - s : U32))
  +eb = Equal.trans(Nat, Nat.add(n, U32.to_nat(t)), Nat.add(U32.to_nat((f - t : U32)), U32.to_nat(t)), U32.to_nat(f),
    Equal.cong(U32, Nat, x => Nat.add(U32.to_nat(x), U32.to_nat(t)), (e - s : U32), (f - t : U32), width), Field.span_end(t, f, tf))
  colon_fuels(n, U32.to_nat((f - t : U32)), a, b, s, t, delta, limit,
    endpoint_bound(n, s, e, e, limit, Field.span_end(s, e, se), MNat.le_refl(U32.to_nat(e)), he),
    endpoint_bound(n, t, f, f, limit, eb, MNat.le_refl(U32.to_nat(f)), hf), hu, starts,
    Equal.cong(U32, Nat, U32.to_nat, (e - s : U32), (f - t : U32), width), same)

def reads_observed_equal(+f: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +j: U32,
  same: {Buffer.observed(f, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(f, Bytes.peek(Tree.reify(U32, b), j), j) : String}) ->
  Packed.Reads(Buffer.observed(f, Bytes.peek(Tree.reify(U32, a), i), i), b, j):
  %Equal.sym(String, Buffer.observed(f, Bytes.peek(Tree.reify(U32, a), i), i), Buffer.observed(f, Bytes.peek(Tree.reify(U32, b), j), j), same) : Packed.Reads(_, b, j)
  Reader.observation_reads(f, b, j)

def kinds_from_names(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +c: U32, +d: U32, +delta: Nat,
  +sc: MNat.le(U32.to_nat(s), U32.to_nat(c)), +td: MNat.le(U32.to_nat(t), U32.to_nat(d)),
  +starts: Offset.offset(delta, s, t), +colons: Offset.offset(delta, c, d),
  same: {Buffer.observed(U32.to_nat((c - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((d - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  {Field.classify((c - s : U32), a, s) == Field.classify((d - t : U32), b, t) : Field.FieldKind}:
  +n = U32.to_nat((c - s : U32))
  Field.classify_relocated(Buffer.observed(n, Bytes.peek(Tree.reify(U32, a), s), s), delta, a, b, s, t, c, d, sc, td, starts, colons,
    Equal.sym(Nat, String.length(Buffer.observed(n, Bytes.peek(Tree.reify(U32, a), s), s)), n, Reader.observed_length(n, Bytes.peek(Tree.reify(U32, a), s), s)),
    Reader.observation_reads(n, a, s),
    reads_observed_equal(n, a, b, s, t,
      observed_same_length(n, U32.to_nat((d - t : U32)), Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t,
        Equal.cong(U32, Nat, U32.to_nat, (c - s : U32), (d - t : U32), Field.relocated_width(delta, s, t, c, d, sc, td, starts, colons)), same)))

def peek_head(+f: Nat, +a: Tree.Tree<U32>, +i: U32) ->
  {Buffer.observed.head(Buffer.observed(1n+f, Bytes.peek(Tree.reify(U32, a), i), i)) == Packed.peek(a, i) : U32}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, a), i), (Tree.reify(U32, a), Packed.peek(a, i)), Buffer.tree_peek(a, i)) :
    {Buffer.observed.head(Buffer.observed(1n+f, _, i)) == Packed.peek(a, i) : U32}
  {==}

def peek_observed(f: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +j: U32,
  positive: MNat.lt(0n, f),
  same: {Buffer.observed(f, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(f, Bytes.peek(Tree.reify(U32, b), j), j) : String}) ->
  {Packed.peek(a, i) == Packed.peek(b, j) : U32}:
  match f:
    case 0n:
      Empty.absurd({Packed.peek(a, i) == Packed.peek(b, j) : U32}, MNat.internal_false_ne_true(positive))
    case 1n+ +p:
      Equal.trans(U32, Packed.peek(a, i), Buffer.observed.head(Buffer.observed(1n+p, Bytes.peek(Tree.reify(U32, a), i), i)), Packed.peek(b, j),
        Equal.sym(U32, Buffer.observed.head(Buffer.observed(1n+p, Bytes.peek(Tree.reify(U32, a), i), i)), Packed.peek(a, i), peek_head(p, a, i)),
        Equal.trans(U32, Buffer.observed.head(Buffer.observed(1n+p, Bytes.peek(Tree.reify(U32, a), i), i)), Buffer.observed.head(Buffer.observed(1n+p, Bytes.peek(Tree.reify(U32, b), j), j)), Packed.peek(b, j),
          Equal.cong(String, U32, Buffer.observed.head, Buffer.observed(1n+p, Bytes.peek(Tree.reify(U32, a), i), i), Buffer.observed(1n+p, Bytes.peek(Tree.reify(U32, b), j), j), same), peek_head(p, b, j)))

def value_no_space(+c: U32, +e: U32, +b: U32, no: {U32.is_lt((c + 1 : U32), e) == False{} : Bool}) ->
  {Field.value_position(c, e, b) == Bool.pick(U32, U32.is_eq(c, e), e, (c + 1 : U32)) : U32}:
  Equal.cong(Bool, U32, more => Bool.pick(U32, U32.is_eq(c, e), e,
    Bool.pick(U32, Bool.and(more, U32.is_eq(b, 32)), (c + 2 : U32), (c + 1 : U32))), U32.is_lt((c + 1 : U32), e), False{}, no)

def value_guard_choice(flag: Bool, +delta: Nat, +c: U32, +d: U32, +e: U32, +f: U32, +a: U32, +b: U32,
  +choice: {U32.is_lt((d + 1 : U32), f) == flag : Bool},
  prior: Offset.offset(delta, Field.value_position(c, e, a), Field.value_position(d, f, a)),
  same: {flag == True{} : Bool} -> {a == b : U32}) ->
  Offset.offset(delta, Field.value_position(c, e, a), Field.value_position(d, f, b)):
  match flag:
    case True{}:
      offset_right(delta, Field.value_position(c, e, a), Field.value_position(d, f, a), Field.value_position(d, f, b), prior,
        Equal.cong(U32, U32, x => Field.value_position(d, f, x), a, b, same({==})))
    case False{}:
      offset_right(delta, Field.value_position(c, e, a), Field.value_position(d, f, a), Field.value_position(d, f, b), prior,
        Equal.trans(U32, Field.value_position(d, f, a), Bool.pick(U32, U32.is_eq(d, f), f, (d + 1 : U32)), Field.value_position(d, f, b),
          value_no_space(d, f, a, choice), Equal.sym(U32, Field.value_position(d, f, b), Bool.pick(U32, U32.is_eq(d, f), f, (d + 1 : U32)), value_no_space(d, f, b, choice))))

def peek_inside(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32,
  +u: U32, +v: U32, +delta: Nat, +limit: Nat,
  su: MNat.le(U32.to_nat(s), U32.to_nat(u)), tv: MNat.le(U32.to_nat(t), U32.to_nat(v)),
  +ue: MNat.lt(U32.to_nat(u), U32.to_nat(e)), +vf: MNat.lt(U32.to_nat(v), U32.to_nat(f)),
  he: MNat.lt(U32.to_nat(e), limit), hf: MNat.lt(U32.to_nat(f), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  starts: Offset.offset(delta, s, t), +middle: Offset.offset(delta, u, v), +ends: Offset.offset(delta, e, f),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  {Packed.peek(a, u) == Packed.peek(b, v) : U32}:
  +ha = MNat.le_of_lt(U32.to_nat(u), U32.to_nat(e), ue)
  +hb = MNat.le_of_lt(U32.to_nat(v), U32.to_nat(f), vf)
  peek_observed(U32.to_nat((e - u : U32)), a, b, u, v,
    (%Equal.sym(Nat, U32.to_nat((e - u : U32)), Nat.sub(U32.to_nat(e), U32.to_nat(u)), Lemmas.u32_sub_nat(e, u, ha)) : MNat.lt(0n, _)
     MNat.sub_pos_of_lt(U32.to_nat(u), U32.to_nat(e), ue)),
    observed_same_length(U32.to_nat((e - u : U32)), U32.to_nat((f - v : U32)), Bytes.peek(Tree.reify(U32, a), u), Bytes.peek(Tree.reify(U32, b), v), u, v,
      Equal.cong(U32, Nat, U32.to_nat, (e - u : U32), (f - v : U32), Field.relocated_width(delta, u, v, e, f, ha, hb, middle, ends)),
      subspan(a, b, s, t, e, f, u, v, delta, limit, su, tv, ha, hb, he, hf, hu, starts, middle, ends, same)))

def above_one(+c: U32, +limit: Nat, hc: MNat.lt(1n+U32.to_nat(c), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(U32.to_nat(c), U32.to_nat((c + 1 : U32))):
  %Equal.sym(Nat, U32.to_nat((c + 1 : U32)), 1n+U32.to_nat(c),
    Packed.add_one_nat(c, MNat.lt_of_lt_of_le(1n+U32.to_nat(c), limit, Lemmas.pow2(32n), hc, hu))) : MNat.le(U32.to_nat(c), _)
  MNat.le_succ(U32.to_nat(c))

def values_from_line(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32,
  +c: U32, +d: U32, +delta: Nat, +limit: Nat,
  sc: MNat.le(U32.to_nat(s), U32.to_nat(c)), td: MNat.le(U32.to_nat(t), U32.to_nat(d)),
  he: MNat.lt(U32.to_nat(e), limit), hf: MNat.lt(U32.to_nat(f), limit),
  +hc1: MNat.lt(1n+U32.to_nat(c), limit), +hd1: MNat.lt(1n+U32.to_nat(d), limit),
  hc2: MNat.lt(Nat.add(U32.to_nat(c), 2n), limit), hd2: MNat.lt(Nat.add(U32.to_nat(d), 2n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  starts: Offset.offset(delta, s, t), +colons: Offset.offset(delta, c, d), +ends: Offset.offset(delta, e, f),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Offset.offset(delta, Field.value_position(c, e, Packed.peek(a, (c + 1 : U32))), Field.value_position(d, f, Packed.peek(b, (d + 1 : U32)))):
  +one = Offset.increment(delta, c, d, limit, hc1, hd1, hu, colons)
  +less = Field.less_offsets(delta, (c + 1 : U32), (d + 1 : U32), e, f, one, ends)
  value_guard_choice(U32.is_lt((d + 1 : U32), f), delta, c, d, e, f, Packed.peek(a, (c + 1 : U32)), Packed.peek(b, (d + 1 : U32)), {==},
    Field.value_relocated(delta, c, d, e, f, Packed.peek(a, (c + 1 : U32)), limit,
      (%Equal.sym(Nat, Nat.add(U32.to_nat(c), 1n), 1n+U32.to_nat(c), MNat.add_comm(U32.to_nat(c), 1n)) : MNat.lt(_, limit); hc1),
      (%Equal.sym(Nat, Nat.add(U32.to_nat(d), 1n), 1n+U32.to_nat(d), MNat.add_comm(U32.to_nat(d), 1n)) : MNat.lt(_, limit); hd1), hc2, hd2, hu, colons, ends),
    +more => peek_inside(a, b, s, t, e, f, (c + 1 : U32), (d + 1 : U32), delta, limit,
      MNat.le_trans(U32.to_nat(s), U32.to_nat(c), U32.to_nat((c + 1 : U32)), sc, above_one(c, limit, hc1, hu)),
      MNat.le_trans(U32.to_nat(t), U32.to_nat(d), U32.to_nat((d + 1 : U32)), td, above_one(d, limit, hd1, hu)),
      (%Lemmas.u32_is_lt_nat((c + 1 : U32), e) : {_ == True{} : Bool}
       Equal.trans(Bool, U32.is_lt((c + 1 : U32), e), U32.is_lt((d + 1 : U32), f), True{}, less, more)),
      (%Lemmas.u32_is_lt_nat((d + 1 : U32), f) : {_ == True{} : Bool}; more), he, hf, hu, starts, one, ends, same))

def field_spans_type(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32, +delta: Nat) -> Type:
  {Field.field_kind(a, s, e) == Field.field_kind(b, t, f) : Field.FieldKind} &
  Offset.offset(delta, Field.field_start(a, s, e), Field.field_start(b, t, f)) &
  {Buffer.observed(U32.to_nat((e - Field.field_start(a, s, e) : U32)), Bytes.peek(Tree.reify(U32, a), Field.field_start(a, s, e)), Field.field_start(a, s, e)) ==
    Buffer.observed(U32.to_nat((f - Field.field_start(b, t, f) : U32)), Bytes.peek(Tree.reify(U32, b), Field.field_start(b, t, f)), Field.field_start(b, t, f)) : String}

def field_spans_finish(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32, +delta: Nat, +limit: Nat,
  he: MNat.lt(U32.to_nat(e), limit), hf: MNat.lt(U32.to_nat(f), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, e, f),
  kinds: {Field.field_kind(a, s, e) == Field.field_kind(b, t, f) : Field.FieldKind},
  +values: Offset.offset(delta, Field.field_start(a, s, e), Field.field_start(b, t, f)),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left: MNat.le(U32.to_nat(s), U32.to_nat(Field.field_start(a, s, e))) & MNat.le(U32.to_nat(Field.field_start(a, s, e)), U32.to_nat(e)),
  right: MNat.le(U32.to_nat(t), U32.to_nat(Field.field_start(b, t, f))) & MNat.le(U32.to_nat(Field.field_start(b, t, f)), U32.to_nat(f))) ->
  field_spans_type(a, b, s, t, e, f, delta):
  (sv, ve) = left
  (tw, wf) = right
  (kinds, values, subspan(a, b, s, t, e, f, Field.field_start(a, s, e), Field.field_start(b, t, f), delta, limit, sv, tw, ve, wf, he, hf, hu, starts, values, ends, same))

def field_spans_of(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32, +delta: Nat, +limit: Nat,
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  +he: MNat.lt(Nat.add(U32.to_nat(e), 3n), limit), +hf: MNat.lt(Nat.add(U32.to_nat(f), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +starts: Offset.offset(delta, s, t), +ends: Offset.offset(delta, e, f),
  +same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left: MNat.le(U32.to_nat(s), U32.to_nat(Field.colon_index(U32.to_nat((e - s : U32)), a, s))) &
    MNat.le(U32.to_nat(Field.colon_index(U32.to_nat((e - s : U32)), a, s)), U32.to_nat(e)),
  right: MNat.le(U32.to_nat(t), U32.to_nat(Field.colon_index(U32.to_nat((f - t : U32)), b, t))) &
    MNat.le(U32.to_nat(Field.colon_index(U32.to_nat((f - t : U32)), b, t)), U32.to_nat(f))) ->
  field_spans_type(a, b, s, t, e, f, delta):
  (+sc, +ce) = left
  (+td, +df) = right
  +c = Field.colon_index(U32.to_nat((e - s : U32)), a, s)
  +d = Field.colon_index(U32.to_nat((f - t : U32)), b, t)
  +he0 = MNat.lt_of_le_of_lt(U32.to_nat(e), Nat.add(U32.to_nat(e), 3n), limit, MNat.le_add_right(U32.to_nat(e), 3n), he)
  +hf0 = MNat.lt_of_le_of_lt(U32.to_nat(f), Nat.add(U32.to_nat(f), 3n), limit, MNat.le_add_right(U32.to_nat(f), 3n), hf)
  +colons = colon_relocated(a, b, s, t, e, f, delta, limit, se, tf, he0, hf0, hu, starts, ends, same)
  +hc2 = Field.plus_two_bound(c, e, limit, ce, he)
  +hd2 = Field.plus_two_bound(d, f, limit, df, hf)
  +values = values_from_line(a, b, s, t, e, f, c, d, delta, limit, sc, td, he0, hf0,
    Offset.increment_bound(1n, c, limit, (%MNat.add_comm(U32.to_nat(c), 2n) : MNat.lt(_, limit); hc2)),
    Offset.increment_bound(1n, d, limit, (%MNat.add_comm(U32.to_nat(d), 2n) : MNat.lt(_, limit); hd2)), hc2, hd2, hu, starts, colons, ends, same)
  field_spans_finish(a, b, s, t, e, f, delta, limit, he0, hf0, hu, starts, ends,
    kinds_from_names(a, b, s, t, c, d, delta, sc, td, starts, colons,
      prefix_span(a, b, s, t, e, f, c, d, delta, sc, td, ce, df, starts, colons, ends, same)), values, same,
    Field.field_start_bounds(e, a, s, e, limit, se, MNat.le_refl(U32.to_nat(e)), he, hu),
    Field.field_start_bounds(f, b, t, f, limit, tf, MNat.le_refl(U32.to_nat(f)), hf, hu))

def field_spans(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +e: U32, +f: U32, +delta: Nat, +limit: Nat,
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  +he: MNat.lt(Nat.add(U32.to_nat(e), 3n), limit), +hf: MNat.lt(Nat.add(U32.to_nat(f), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, e, f),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  field_spans_type(a, b, s, t, e, f, delta):
  field_spans_of(a, b, s, t, e, f, delta, limit, se, tf, he, hf, hu, starts, ends, same,
    Field.field_colon_bounds(a, s, e, limit, se, MNat.lt_of_le_of_lt(U32.to_nat(e), Nat.add(U32.to_nat(e), 3n), limit, MNat.le_add_right(U32.to_nat(e), 3n), he), hu),
    Field.field_colon_bounds(b, t, f, limit, tf, MNat.lt_of_le_of_lt(U32.to_nat(f), Nat.add(U32.to_nat(f), 3n), limit, MNat.le_add_right(U32.to_nat(f), 3n), hf), hu))

def unclamped_length(+len: U32, +v: U32, +e: U32,
  +ve: MNat.le(U32.to_nat(v), U32.to_nat(e)), +el: MNat.le(U32.to_nat(e), U32.to_nat(len))) ->
  {U32.min((e - v : U32), (len - U32.min(v, len) : U32)) == (e - v : U32) : U32}:
  %Equal.sym(U32, U32.min(v, len), v, Reader.min_left(v, len, MNat.le_trans(U32.to_nat(v), U32.to_nat(e), U32.to_nat(len), ve, el))) :
    {U32.min((e - v : U32), (len - _ : U32)) == (e - v : U32) : U32}
  Reader.min_left((e - v : U32), (len - v : U32),
    (%Equal.sym(Nat, U32.to_nat((e - v : U32)), Nat.sub(U32.to_nat(e), U32.to_nat(v)), Lemmas.u32_sub_nat(e, v, ve)) :
       MNat.le(_, U32.to_nat((len - v : U32)))
     %Equal.sym(Nat, U32.to_nat((len - v : U32)), Nat.sub(U32.to_nat(len), U32.to_nat(v)),
       Lemmas.u32_sub_nat(len, v, MNat.le_trans(U32.to_nat(v), U32.to_nat(e), U32.to_nat(len), ve, el))) :
       MNat.le(Nat.sub(U32.to_nat(e), U32.to_nat(v)), _)
     MNat.sub_le_sub_right(U32.to_nat(e), U32.to_nat(len), el, U32.to_nat(v))))

def reads_position(+text: String, +src: Tree.Tree<U32>, +s: U32, +t: U32,
  same: {s == t : U32}, reads: Packed.Reads(text, src, s)) -> Packed.Reads(text, src, t):
  %same : Packed.Reads(text, src, _)
  reads

def data_span_bound(+la: U32, +m: U32, +value: String, +limit: Nat,
  length: {U32.to_nat(m) == String.length(value) : Nat},
  bound: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), String.length(value)), 1n), 3n), limit)) ->
  MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(m)), 1n), 3n), limit):
  %Equal.sym(Nat, U32.to_nat(m), String.length(value), length) : MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), _), 1n), 3n), limit)
  bound

def field_valid_span(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat((e - Field.field_start(src, s, e) : U32)) == String.length(value) : Nat},
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), String.length(value)), 1n), 3n), limit),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, src, Field.field_start(src, s, e)),
  +ve: MNat.le(U32.to_nat(Field.field_start(src, s, e)), U32.to_nat(e)), +el: MNat.le(U32.to_nat(e), U32.to_nat(len))) ->
  Field.set_snapshot_type(Field.field_kind(src, s, e), old, value, name, id, retry,
    Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})), limit):
  +v = Field.field_start(src, s, e)
  +m = U32.min((e - v : U32), (len - U32.min(v, len) : U32))
  +length = Equal.trans(Nat, U32.to_nat(m), U32.to_nat((e - v : U32)), String.length(value),
    Equal.cong(U32, Nat, U32.to_nat, m, (e - v : U32), unclamped_length(len, v, e, ve, el)), eb)
  Field.field_valid(old, value, la, left, len, src, s, e, limit, name, id, retry, shape, hl, hu, ea, length,
    data_span_bound(la, m, value, limit, length, hn), ra,
    reads_position(value, src, v, U32.min(v, len), Equal.sym(U32, U32.min(v, len), v,
      Reader.min_left(v, len, MNat.le_trans(U32.to_nat(v), U32.to_nat(e), U32.to_nat(len), ve, el))), rb))

def field_from_snapshot(+old: String, +value: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  eb: {U32.to_nat((e - Field.field_start(src, s, e) : U32)) == String.length(value) : Nat},
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), String.length(value)), 1n), 3n), limit),
  rb: Packed.Reads(value, src, Field.field_start(src, s, e)),
  ve: MNat.le(U32.to_nat(Field.field_start(src, s, e)), U32.to_nat(e)), el: MNat.le(U32.to_nat(e), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  Field.set_snapshot_type(Field.field_kind(src, s, e), old, value, name, id, retry,
    Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, st)), limit):
  (+la, +left, eq, shape, +ea, bound, ra) = snapshot
  Field.snapshot_transport(Field.field_kind(src, s, e), old, value, name, id, retry, limit,
    Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, st)),
    Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    Equal.cong(Sse.St, Sse.St, x => Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, x)),
      st, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry}, eq),
    field_valid_span(old, value, la, left, len, src, s, e, limit, name, id, retry, shape, hl, hu, ea, eb,
      (%Equal.sym(Nat, U32.to_nat(la), String.length(old), ea) : MNat.lt(Nat.add(Nat.add(Nat.add(_, String.length(value)), 1n), 3n), limit); hn), ra, rb, ve, el))

def suffix_length_le(+s: U32, +v: U32, +e: U32,
  +sv: MNat.le(U32.to_nat(s), U32.to_nat(v)), +ve: MNat.le(U32.to_nat(v), U32.to_nat(e))) ->
  MNat.le(U32.to_nat((e - v : U32)), U32.to_nat((e - s : U32))):
  %Equal.sym(Nat, U32.to_nat((e - v : U32)), Nat.sub(U32.to_nat(e), U32.to_nat(v)), Lemmas.u32_sub_nat(e, v, ve)) :
    MNat.le(_, U32.to_nat((e - s : U32)))
  %Equal.sym(Nat, U32.to_nat((e - s : U32)), Nat.sub(U32.to_nat(e), U32.to_nat(s)),
    Lemmas.u32_sub_nat(e, s, MNat.le_trans(U32.to_nat(s), U32.to_nat(v), U32.to_nat(e), sv, ve))) :
    MNat.le(Nat.sub(U32.to_nat(e), U32.to_nat(v)), _)
  MNat.sub_le_sub_left(U32.to_nat(s), U32.to_nat(v), sv, U32.to_nat(e))

def accumulation_bound(+old: Nat, +value: Nat, +span: Nat, +limit: Nat,
  le: MNat.le(value, span),
  bound: MNat.lt(Nat.add(Nat.add(Nat.add(old, span), 1n), 3n), limit)) ->
  MNat.lt(Nat.add(Nat.add(Nat.add(old, value), 1n), 3n), limit):
  MNat.lt_of_le_of_lt(Nat.add(Nat.add(Nat.add(old, value), 1n), 3n), Nat.add(Nat.add(Nat.add(old, span), 1n), 3n), limit,
    MNat.add_le_add_right(Nat.add(Nat.add(old, value), 1n), Nat.add(Nat.add(old, span), 1n), 3n,
      MNat.add_le_add_right(Nat.add(old, value), Nat.add(old, span), 1n, MNat.add_le_add_left(value, span, old, le))), bound)

def kind_snapshot_transport(+a: Field.FieldKind, +b: Field.FieldKind, +old: String, +value: String,
  +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  same: {a == b : Field.FieldKind}, cert: Field.set_snapshot_type(b, old, value, name, id, retry, st, limit)) ->
  Field.set_snapshot_type(a, old, value, name, id, retry, st, limit):
  %Equal.sym(Field.FieldKind, a, b, same) : Field.set_snapshot_type(_, old, value, name, id, retry, st, limit)
  cert

def field_refines_type(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  -st: Sse.St, -next: Sse.St, +limit: Nat) -> Type:
  &value: String ->
    Field.set_snapshot_type(Field.field_kind(a, s, e), old, value, name, id, retry,
      Field.field_after(Sse.field(Tree.reify(U32, a), len, s, e, st)), limit) &
    Field.set_snapshot_type(Field.field_kind(a, s, e), old, value, name, id, retry,
      Field.field_after(Sse.field(Tree.reify(U32, b), other, t, f, next)), limit)

def field_refines_values(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  el: MNat.le(U32.to_nat(e), U32.to_nat(len)), fo: MNat.le(U32.to_nat(f), U32.to_nat(other)), ends: Offset.offset(delta, e, f),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit), right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  spans: field_spans_type(a, b, s, t, e, f, delta),
  left: MNat.le(U32.to_nat(s), U32.to_nat(Field.field_start(a, s, e))) & MNat.le(U32.to_nat(Field.field_start(a, s, e)), U32.to_nat(e)),
  right: MNat.le(U32.to_nat(t), U32.to_nat(Field.field_start(b, t, f))) & MNat.le(U32.to_nat(Field.field_start(b, t, f)), U32.to_nat(f))) ->
  field_refines_type(old, name, id, retry, a, b, len, other, s, t, e, f, st, next, limit):
  (kinds, values, same) = spans
  (sv, +ve) = left
  (tw, +wf) = right
  +v = Field.field_start(a, s, e)
  +w = Field.field_start(b, t, f)
  +n = U32.to_nat((e - v : U32))
  +m = U32.to_nat((f - w : U32))
  +value = Buffer.observed(n, Bytes.peek(Tree.reify(U32, a), v), v)
  +ea = Equal.sym(Nat, String.length(value), n, Reader.observed_length(n, Bytes.peek(Tree.reify(U32, a), v), v))
  +width = Field.relocated_width(delta, v, w, e, f, ve, wf, values, ends)
  +eb = Equal.trans(Nat, m, n, String.length(value), Equal.cong(U32, Nat, U32.to_nat, (f - w : U32), (e - v : U32), Equal.sym(U32, (e - v : U32), (f - w : U32), width)), ea)
  +bound = accumulation_bound(String.length(old), String.length(value), U32.to_nat((e - s : U32)), limit,
    (%ea : MNat.le(_, U32.to_nat((e - s : U32))); suffix_length_le(s, v, e, sv, ve)), hn)
  (value,
    field_from_snapshot(old, value, name, id, retry, len, a, s, e, st, limit, hl, hu, ea, bound, Reader.observation_reads(n, a, v), ve, el, left_state),
    kind_snapshot_transport(Field.field_kind(a, s, e), Field.field_kind(b, t, f), old, value, name, id, retry,
      Field.field_after(Sse.field(Tree.reify(U32, b), other, t, f, next)), limit, kinds,
      field_from_snapshot(old, value, name, id, retry, other, b, t, f, next, limit, hr, hu, eb, bound,
        reads_observed_equal(n, a, b, v, w,
          observed_same_length(n, m, Bytes.peek(Tree.reify(U32, a), v), Bytes.peek(Tree.reify(U32, b), w), v, w,
            Equal.cong(U32, Nat, U32.to_nat, (e - v : U32), (f - w : U32), width), same)), wf, fo, right_state)))

def field_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  +el: MNat.le(U32.to_nat(e), U32.to_nat(len)), +fo: MNat.le(U32.to_nat(f), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), +ends: Offset.offset(delta, e, f),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit), right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  field_refines_type(old, name, id, retry, a, b, len, other, s, t, e, f, st, next, limit):
  field_refines_values(old, name, id, retry, a, b, len, other, s, t, e, f, st, next, delta, limit, hl, hr, hu, el, fo, ends, hn, left_state, right_state,
    field_spans(a, b, s, t, e, f, delta, limit, se, tf,
      MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(e), 3n), Nat.add(U32.to_nat(len), 3n), limit, MNat.add_le_add_right(U32.to_nat(e), U32.to_nat(len), 3n, el), hl),
      MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(f), 3n), Nat.add(U32.to_nat(other), 3n), limit, MNat.add_le_add_right(U32.to_nat(f), U32.to_nat(other), 3n, fo), hr), hu, starts, ends, same),
    Field.field_start_bounds(len, a, s, e, limit, se, el, hl, hu), Field.field_start_bounds(other, b, t, f, limit, tf, fo, hr, hu))

def eol_index(+f: Nat, +src: Tree.Tree<U32>, +s: U32) -> U32:
  Buffer.index(Sse.eol(f, Bytes.peek(Tree.reify(U32, src), s), s))

def eol_bounds(f: Nat, +src: Tree.Tree<U32>, +c: U32, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(f, U32.to_nat(s)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  Field.scan_span(f, s, Buffer.index(Sse.eol(f, (Tree.reify(U32, src), c), s))):
  match f:
    case 0n:
      Field.scan_span_here(0n, s)
    case 1n+ +p:
      Scan.eol_elim(x => Field.scan_span(1n+p, s, Buffer.index(x)), p, Tree.reify(U32, src), c, s,
        eq => Field.scan_span_here(1n+p, s),
        eq => Field.scan_span_here(1n+p, s),
        good => (
          %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), (s + 1 : U32)),
            (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), Buffer.tree_peek(src, (s + 1 : U32))) :
            Field.scan_span(1n+p, s, Buffer.index(Sse.eol(p, _, (s + 1 : U32))))
          Field.scan_span_step(p, s, Buffer.index(Sse.eol(p, (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), (s + 1 : U32))), limit, hu, hn,
            eol_bounds(p, src, Packed.peek(src, (s + 1 : U32)), (s + 1 : U32), limit, Offset.tail_bound(p, s, limit, hu, hn), hu))))

def line_end_bounds(+src: Tree.Tree<U32>, +s: U32, +len: U32, +limit: Nat,
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(U32.to_nat(s), U32.to_nat(eol_index(U32.to_nat((len - s : U32)), src, s))) &
  MNat.le(U32.to_nat(eol_index(U32.to_nat((len - s : U32)), src, s)), U32.to_nat(len)):
  %Field.span_end(s, len, sl) :
    (MNat.le(U32.to_nat(s), U32.to_nat(eol_index(U32.to_nat((len - s : U32)), src, s))) &
      MNat.le(U32.to_nat(eol_index(U32.to_nat((len - s : U32)), src, s)), _))
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), s), (Tree.reify(U32, src), Packed.peek(src, s)), Buffer.tree_peek(src, s)) :
    Field.scan_span(U32.to_nat((len - s : U32)), s, Buffer.index(Sse.eol(U32.to_nat((len - s : U32)), _, s)))
  eol_bounds(U32.to_nat((len - s : U32)), src, Packed.peek(src, s), s, limit,
    endpoint_bound(U32.to_nat((len - s : U32)), s, len, len, limit, Field.span_end(s, len, sl), MNat.le_refl(U32.to_nat(len)), hl), hu)

def eol_fuels(+n: Nat, +m: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +delta: Nat, +limit: Nat,
  hi: MNat.lt(Nat.add(n, U32.to_nat(s)), limit), hj: MNat.lt(Nat.add(n, U32.to_nat(t)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  here: Offset.offset(delta, s, t), +length: {n == m : Nat},
  same: {Buffer.observed(n, Bytes.peek(Tree.reify(U32, a), s), s) == Buffer.observed(m, Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Offset.offset(delta, eol_index(n, a, s), eol_index(m, b, t)):
  offset_right(delta, eol_index(n, a, s), eol_index(n, b, t), eol_index(m, b, t),
    Offset.scan_observed(n, a, b, delta, s, t, limit, hi, hj, hu, here,
      observed_same_length(n, m, Bytes.peek(Tree.reify(U32, a), s), Bytes.peek(Tree.reify(U32, b), t), s, t, length, same)),
    Equal.cong(Nat, U32, f => eol_index(f, b, t), n, m, length))

def eol_relocated(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +len: U32, +other: U32, +delta: Nat, +limit: Nat,
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  hl: MNat.lt(U32.to_nat(len), limit), ho: MNat.lt(U32.to_nat(other), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  +starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Offset.offset(delta, eol_index(U32.to_nat((len - s : U32)), a, s), eol_index(U32.to_nat((other - t : U32)), b, t)):
  +width = Field.relocated_width(delta, s, t, len, other, sl, to, starts, ends)
  +n = U32.to_nat((len - s : U32))
  +eb = Equal.trans(Nat, Nat.add(n, U32.to_nat(t)), Nat.add(U32.to_nat((other - t : U32)), U32.to_nat(t)), U32.to_nat(other),
    Equal.cong(U32, Nat, x => Nat.add(U32.to_nat(x), U32.to_nat(t)), (len - s : U32), (other - t : U32), width), Field.span_end(t, other, to))
  eol_fuels(n, U32.to_nat((other - t : U32)), a, b, s, t, delta, limit,
    endpoint_bound(n, s, len, len, limit, Field.span_end(s, len, sl), MNat.le_refl(U32.to_nat(len)), hl),
    endpoint_bound(n, t, other, other, limit, eb, MNat.le_refl(U32.to_nat(other)), ho), hu, starts,
    Equal.cong(U32, Nat, U32.to_nat, (len - s : U32), (other - t : U32), width), same)

def prefix_length_le(+s: U32, +e: U32, +len: U32,
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.le(U32.to_nat(e), U32.to_nat(len))) ->
  MNat.le(U32.to_nat((e - s : U32)), U32.to_nat((len - s : U32))):
  %Equal.sym(Nat, U32.to_nat((e - s : U32)), Nat.sub(U32.to_nat(e), U32.to_nat(s)), Lemmas.u32_sub_nat(e, s, se)) :
    MNat.le(_, U32.to_nat((len - s : U32)))
  %Equal.sym(Nat, U32.to_nat((len - s : U32)), Nat.sub(U32.to_nat(len), U32.to_nat(s)),
    Lemmas.u32_sub_nat(len, s, MNat.le_trans(U32.to_nat(s), U32.to_nat(e), U32.to_nat(len), se, el))) :
    MNat.le(Nat.sub(U32.to_nat(e), U32.to_nat(s)), _)
  MNat.sub_le_sub_right(U32.to_nat(e), U32.to_nat(len), el, U32.to_nat(s))

def scanned_field_type(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +limit: Nat) -> Type:
  field_refines_type(old, name, id, retry, a, b, len, other, s, t,
    eol_index(U32.to_nat((len - s : U32)), a, s), eol_index(U32.to_nat((other - t : U32)), b, t), st, next, limit)

def scanned_field_finish(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +starts: Offset.offset(delta, s, t), +ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit), right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  +same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left: MNat.le(U32.to_nat(s), U32.to_nat(eol_index(U32.to_nat((len - s : U32)), a, s))) &
    MNat.le(U32.to_nat(eol_index(U32.to_nat((len - s : U32)), a, s)), U32.to_nat(len)),
  right: MNat.le(U32.to_nat(t), U32.to_nat(eol_index(U32.to_nat((other - t : U32)), b, t))) &
    MNat.le(U32.to_nat(eol_index(U32.to_nat((other - t : U32)), b, t)), U32.to_nat(other))) ->
  scanned_field_type(old, name, id, retry, a, b, len, other, s, t, st, next, limit):
  (+se, +el) = left
  (+tf, +fo) = right
  +e = eol_index(U32.to_nat((len - s : U32)), a, s)
  +f = eol_index(U32.to_nat((other - t : U32)), b, t)
  +hl0 = MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)
  +hr0 = MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr)
  +scanned = eol_relocated(a, b, s, t, len, other, delta, limit,
    MNat.le_trans(U32.to_nat(s), U32.to_nat(e), U32.to_nat(len), se, el),
    MNat.le_trans(U32.to_nat(t), U32.to_nat(f), U32.to_nat(other), tf, fo), hl0, hr0, hu, starts, ends, same)
  field_refines(old, name, id, retry, a, b, len, other, s, t, e, f, st, next, delta, limit, hl, hr, hu, se, tf, el, fo, starts, scanned,
    accumulation_bound(String.length(old), U32.to_nat((e - s : U32)), U32.to_nat((len - s : U32)), limit, prefix_length_le(s, e, len, se, el), hn),
    left_state, right_state, prefix_span(a, b, s, t, len, other, e, f, delta, se, tf, el, fo, starts, scanned, ends, same))

def scanned_field_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit), right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  scanned_field_type(old, name, id, retry, a, b, len, other, s, t, st, next, limit):
  scanned_field_finish(old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit, hl, hr, hu, starts, ends, hn, left_state, right_state, same,
    line_end_bounds(a, s, len, limit, sl, MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu),
    line_end_bounds(b, t, other, limit, to, MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr), hu))
