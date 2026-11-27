import Base
import ./sse.bend as Sse
import ./sse-field-proof.bend as Field
import ./sse-refinement-proof.bend as Refinement
import ./sse-reader-proof.bend as Reader
import ./sse-buffer-proof.bend as Buffer
import ./sse-drain-proof.bend as Drain
import ./sse-state-proof.bend as State
import ./sse-offset-proof.bend as Offset
import ../bits/array-proof.bend as Bound
import ../bytes/bytes.bend as Local
import ../bytes/append-proof.bend as Packed
import ../lemmas/array.bend as Tree
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/string.bend as MString

def state_size(st: Sse.St) -> Nat:
  Sse.St{name, Bytes.Bytes{len, src}, id, retry} = st
  U32.to_nat(len)

def snapshot_size(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  snapshot: Field.state_snapshot(name, text, id, retry, st, limit)) ->
  {state_size(st) == String.length(text) : Nat}:
  (len, src, eq, shape, length, bound, reads) = snapshot
  Equal.trans(Nat, state_size(st), U32.to_nat(len), String.length(text),
    Equal.cong(Sse.St, Nat, state_size, st, Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry}, eq), length)

def field_data_size(k: Field.FieldKind, +old: String, +value: String) -> Nat:
  match k:
    case Field.KData{}: String.length((old ++ value) ++ "\n")
    case Field.KEvent{}: String.length(old)
    case Field.KId{}: String.length(old)
    case Field.KRetry{}: String.length(old)
    case Field.KOther{}: String.length(old)

def field_size_snapshot(k: Field.FieldKind, +old: String, +value: String,
  +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  snapshot: Field.set_snapshot_type(k, old, value, name, id, retry, st, limit)) ->
  {state_size(st) == field_data_size(k, old, value) : Nat}:
  match k:
    case Field.KData{}: snapshot_size(name, (old ++ value) ++ "\n", id, retry, st, limit, snapshot)
    case Field.KEvent{}: snapshot_size(value, old, id, retry, st, limit, snapshot)
    case Field.KId{}: snapshot_size(name, old, Bool.pick(String, Sse.has_nul(value), id, value), retry, st, limit, snapshot)
    case Field.KRetry{}: snapshot_size(name, old, id, Sse.set.retry(Sse.digits(value, 0, 0, False{}), retry), st, limit, snapshot)
    case Field.KOther{}: snapshot_size(name, old, id, retry, st, limit, snapshot)

def appended_length(+old: String, +value: String) ->
  {String.length((old ++ value) ++ "\n") == Nat.add(Nat.add(String.length(old), String.length(value)), 1n) : Nat}:
  Equal.trans(Nat, String.length((old ++ value) ++ "\n"), Nat.add(String.length(old ++ value), 1n),
    Nat.add(Nat.add(String.length(old), String.length(value)), 1n),
    MString.length_append(old ++ value, "\n"),
    Equal.cong(Nat, Nat, n => Nat.add(n, 1n), String.length(old ++ value), Nat.add(String.length(old), String.length(value)),
      MString.length_append(old, value)))

def field_size_bound(k: Field.FieldKind, +old: String, +value: String, +span: Nat,
  fits: MNat.le(String.length(value), span)) ->
  MNat.le(field_data_size(k, old, value), Nat.add(Nat.add(String.length(old), span), 1n)):
  match k:
    case Field.KData{}:
      %Equal.sym(Nat, String.length((old ++ value) ++ "\n"), Nat.add(Nat.add(String.length(old), String.length(value)), 1n), appended_length(old, value)) :
        MNat.le(_, Nat.add(Nat.add(String.length(old), span), 1n))
      MNat.add_le_add_right(Nat.add(String.length(old), String.length(value)), Nat.add(String.length(old), span), 1n,
        MNat.add_le_add_left(String.length(value), span, String.length(old), fits))
    case Field.KEvent{}: MNat.le_trans(String.length(old), Nat.add(String.length(old), span), Nat.add(Nat.add(String.length(old), span), 1n), MNat.le_add_right(String.length(old), span), MNat.le_add_right(Nat.add(String.length(old), span), 1n))
    case Field.KId{}: MNat.le_trans(String.length(old), Nat.add(String.length(old), span), Nat.add(Nat.add(String.length(old), span), 1n), MNat.le_add_right(String.length(old), span), MNat.le_add_right(Nat.add(String.length(old), span), 1n))
    case Field.KRetry{}: MNat.le_trans(String.length(old), Nat.add(String.length(old), span), Nat.add(Nat.add(String.length(old), span), 1n), MNat.le_add_right(String.length(old), span), MNat.le_add_right(Nat.add(String.length(old), span), 1n))
    case Field.KOther{}: MNat.le_trans(String.length(old), Nat.add(String.length(old), span), Nat.add(Nat.add(String.length(old), span), 1n), MNat.le_add_right(String.length(old), span), MNat.le_add_right(Nat.add(String.length(old), span), 1n))

def observed_value_fits(+src: Tree.Tree<U32>, +s: U32, +v: U32, +e: U32,
  sv: MNat.le(U32.to_nat(s), U32.to_nat(v)), ve: MNat.le(U32.to_nat(v), U32.to_nat(e))) ->
  MNat.le(String.length(Buffer.observed(U32.to_nat((e - v : U32)), Bytes.peek(Tree.reify(U32, src), v), v)),
    U32.to_nat((e - s : U32))):
  %Equal.sym(Nat, String.length(Buffer.observed(U32.to_nat((e - v : U32)), Bytes.peek(Tree.reify(U32, src), v), v)),
    U32.to_nat((e - v : U32)), Reader.observed_length(U32.to_nat((e - v : U32)), Bytes.peek(Tree.reify(U32, src), v), v)) :
    MNat.le(_, U32.to_nat((e - s : U32)))
  Refinement.suffix_length_le(s, v, e, sv, ve)

def remaining_after_terminator(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +limit: Nat,
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  +ep: MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(pos)),
  +pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(Nat.add(Nat.add(U32.to_nat((e - s : U32)), 1n), U32.to_nat((len - pos : U32))), U32.to_nat((len - s : U32))):
  %Equal.sym(Nat, U32.to_nat((len - s : U32)),
    Nat.add(U32.to_nat((e - s : U32)), U32.to_nat((len - e : U32))),
    Equal.sym(Nat, Nat.add(U32.to_nat((e - s : U32)), U32.to_nat((len - e : U32))), U32.to_nat((len - s : U32)),
      Refinement.split_span(s, e, len, se, MNat.le_of_lt(U32.to_nat(e), U32.to_nat(len), el)))) :
    MNat.le(Nat.add(Nat.add(U32.to_nat((e - s : U32)), 1n), U32.to_nat((len - pos : U32))), _)
  %Equal.sym(Nat, U32.to_nat((len - e : U32)), 1n+U32.to_nat((len - (e + 1 : U32) : U32)), Drain.remaining_step(len, e, limit, el, hl, hu)) :
    MNat.le(Nat.add(Nat.add(U32.to_nat((e - s : U32)), 1n), U32.to_nat((len - pos : U32))), Nat.add(U32.to_nat((e - s : U32)), _))
  %Equal.sym(Nat, Nat.add(Nat.add(U32.to_nat((e - s : U32)), 1n), U32.to_nat((len - pos : U32))),
    Nat.add(U32.to_nat((e - s : U32)), 1n+U32.to_nat((len - pos : U32))),
    MNat.add_assoc(U32.to_nat((e - s : U32)), 1n, U32.to_nat((len - pos : U32)))) :
    MNat.le(_, Nat.add(U32.to_nat((e - s : U32)), 1n+U32.to_nat((len - (e + 1 : U32) : U32))))
  MNat.add_le_add_left(1n+U32.to_nat((len - pos : U32)), 1n+U32.to_nat((len - (e + 1 : U32) : U32)), U32.to_nat((e - s : U32)),
    MNat.succ_le_succ(U32.to_nat((len - pos : U32)), U32.to_nat((len - (e + 1 : U32) : U32)),
      Refinement.suffix_length_le((e + 1 : U32), pos, len, ep, pl)))

def consumed_budget(+old: Nat, +after: Nat, +consumed: Nat, +remaining: Nat, +whole: Nat,
  growth: MNat.le(after, Nat.add(old, consumed)),
  available: MNat.le(Nat.add(consumed, remaining), whole)) ->
  MNat.le(Nat.add(after, remaining), Nat.add(old, whole)):
  MNat.le_trans(Nat.add(after, remaining), Nat.add(Nat.add(old, consumed), remaining), Nat.add(old, whole),
    MNat.add_le_add_right(after, Nat.add(old, consumed), remaining, growth),
    (%Equal.sym(Nat, Nat.add(Nat.add(old, consumed), remaining), Nat.add(old, Nat.add(consumed, remaining)), MNat.add_assoc(old, consumed, remaining)) :
      MNat.le(_, Nat.add(old, whole))
     MNat.add_le_add_left(Nat.add(consumed, remaining), whole, old, available)))

def field_size_value_witness(+old: String, +value: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ve: MNat.le(U32.to_nat(Field.field_start(src, s, e)), U32.to_nat(e)),
  el: MNat.le(U32.to_nat(e), U32.to_nat(len)),
  +fits: MNat.le(String.length(value), U32.to_nat((e - s : U32))),
  length: {U32.to_nat((e - Field.field_start(src, s, e) : U32)) == String.length(value) : Nat},
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  reads: Packed.Reads(value, src, Field.field_start(src, s, e)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  &after: Nat -> {state_size(Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, st))) == after : Nat} &
    MNat.le(after, Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n)):
  (field_data_size(Field.field_kind(src, s, e), old, value),
    field_size_snapshot(Field.field_kind(src, s, e), old, value, name, id, retry,
      Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, st)), limit,
      Refinement.field_from_snapshot(old, value, name, id, retry, len, src, s, e, st, limit, hl, hu, length,
        Refinement.accumulation_bound(String.length(old), String.length(value), U32.to_nat((e - s : U32)), limit, fits, hn),
        reads, ve, el, snapshot)),
    field_size_bound(Field.field_kind(src, s, e), old, value, U32.to_nat((e - s : U32)), fits))

def field_size_witness_of(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  el: MNat.le(U32.to_nat(e), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit),
  bounds: MNat.le(U32.to_nat(s), U32.to_nat(Field.field_start(src, s, e))) &
    MNat.le(U32.to_nat(Field.field_start(src, s, e)), U32.to_nat(e))) ->
  &after: Nat -> {state_size(Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, st))) == after : Nat} &
    MNat.le(after, Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n)):
  (sv, +ve) = bounds
  field_size_value_witness(old,
    Buffer.observed(U32.to_nat((e - Field.field_start(src, s, e) : U32)),
      Bytes.peek(Tree.reify(U32, src), Field.field_start(src, s, e)), Field.field_start(src, s, e)),
    name, id, retry, src, len, s, e, st, limit, hl, hu, ve, el,
    observed_value_fits(src, s, Field.field_start(src, s, e), e, sv, ve),
    Equal.sym(Nat,
      String.length(Buffer.observed(U32.to_nat((e - Field.field_start(src, s, e) : U32)),
        Bytes.peek(Tree.reify(U32, src), Field.field_start(src, s, e)), Field.field_start(src, s, e))),
      U32.to_nat((e - Field.field_start(src, s, e) : U32)),
      Reader.observed_length(U32.to_nat((e - Field.field_start(src, s, e) : U32)),
        Bytes.peek(Tree.reify(U32, src), Field.field_start(src, s, e)), Field.field_start(src, s, e))),
    hn, Reader.observation_reads(U32.to_nat((e - Field.field_start(src, s, e) : U32)), src, Field.field_start(src, s, e)), snapshot)

def remaining_from_witness(+old: Nat, +span: Nat, +remaining: Nat, +whole: Nat, -st: Sse.St,
  available: MNat.le(Nat.add(Nat.add(span, 1n), remaining), whole),
  witness: &after: Nat -> {state_size(st) == after : Nat} & MNat.le(after, Nat.add(Nat.add(old, span), 1n))) ->
  MNat.le(Nat.add(state_size(st), remaining), Nat.add(old, whole)):
  (+after, eq, growth) = witness
  %Equal.sym(Nat, state_size(st), after, eq) : MNat.le(Nat.add(_, remaining), Nat.add(old, whole))
  consumed_budget(old, after, Nat.add(span, 1n), remaining, whole,
    (%MNat.add_assoc(old, span, 1n) : MNat.le(after, _); growth), available)

def field_remaining_bound(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  ep: MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(pos)), pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(Nat.add(state_size(Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, st))), U32.to_nat((len - pos : U32))),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  remaining_from_witness(String.length(old), U32.to_nat((e - s : U32)), U32.to_nat((len - pos : U32)), U32.to_nat((len - s : U32)),
    Field.field_after(Sse.field(Tree.reify(U32, src), len, s, e, st)),
    remaining_after_terminator(src, len, s, e, pos, limit, se, el, ep, pl,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu),
    field_size_witness_of(old, name, id, retry, src, len, s, e, st, limit, hl, hu,
      MNat.le_of_lt(U32.to_nat(e), U32.to_nat(len), el), hn, snapshot,
      Field.field_start_bounds(len, src, s, e, limit, se, MNat.le_of_lt(U32.to_nat(e), U32.to_nat(len), el), hl, hu)))

def line_position(line: Sse.Line) -> U32:
  match line:
    case Sse.LMore{a, pos, cr, st}: pos
    case Sse.LWant{a, pos, cr, st}: pos
    case Sse.LGot{a, pos, cr, st, message}: pos

def line_mass(+len: U32, line: Sse.Line) -> Nat:
  match line:
    case Sse.LMore{a, +pos, cr, st}: Nat.add(state_size(st), U32.to_nat((len - pos : U32)))
    case Sse.LWant{a, +pos, cr, st}: Nat.add(state_size(st), U32.to_nat((len - pos : U32)))
    case Sse.LGot{a, +pos, cr, st, message}: Nat.add(state_size(st), U32.to_nat((len - pos : U32)))

def blank_mass_of(empty: Bool, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool,
  +src: Tree.Tree<U32>, +data_len: U32, +data: Tree.Tree<U32>, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +sp: MNat.le(U32.to_nat(s), U32.to_nat(pos)), +pl: MNat.le(U32.to_nat(pos), U32.to_nat(len))) ->
  MNat.le(line_mass(len, Sse.line.got(Tree.reify(U32, src), pos, cr,
    Sse.dispatch.of(empty, name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry))),
    Nat.add(U32.to_nat(data_len), U32.to_nat((len - s : U32)))):
  match empty:
    case True{}:
      MNat.add_le_add_left(U32.to_nat((len - pos : U32)), U32.to_nat((len - s : U32)), U32.to_nat(data_len),
        Refinement.suffix_length_le(s, pos, len, sp, pl))
    case False{}:
      MNat.le_trans(U32.to_nat((len - pos : U32)), U32.to_nat((len - s : U32)),
        Nat.add(U32.to_nat(data_len), U32.to_nat((len - s : U32))),
        Refinement.suffix_length_le(s, pos, len, sp, pl), MNat.le_add_left(U32.to_nat((len - s : U32)), U32.to_nat(data_len)))

def blank_mass(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  sp: MNat.le(U32.to_nat(s), U32.to_nat(pos)), pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.body(True{}, Tree.reify(U32, src), len, s, e, pos, cr, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  (+data_len, +data, eq, shape, +length, bound, reads) = snapshot
  %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
    MNat.le(line_mass(len, Sse.line.body(True{}, Tree.reify(U32, src), len, s, e, pos, cr, _)),
      Nat.add(String.length(old), U32.to_nat((len - s : U32))))
  %length : MNat.le(line_mass(len, Sse.line.body(True{}, Tree.reify(U32, src), len, s, e, pos, cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry})), Nat.add(_, U32.to_nat((len - s : U32))))
  blank_mass_of(U32.is_zero(data_len), len, s, e, pos, cr, src, data_len, data, name, id, retry, sp, pl)

def field_mass(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  ep: MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(pos)), pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.body(False{}, Tree.reify(U32, src), len, s, e, pos, cr, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  %Equal.sym(Sse.Line, Sse.line.body(False{}, Tree.reify(U32, src), len, s, e, pos, cr, st),
    Sse.LMore{Tree.reify(U32, src), pos, cr, Field.field_state_result(len, src, s, e, st)},
    Drain.line_field_pair(src, len, s, e, pos, cr, st)) :
    MNat.le(line_mass(len, _), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
  %Equal.cong(Array<U32> & Sse.St, Sse.St, Field.field_after,
    Sse.field(Tree.reify(U32, src), len, s, e, st), (Tree.reify(U32, src), Field.field_state_result(len, src, s, e, st)),
    Field.field_pair(len, src, s, e, st)) :
    MNat.le(Nat.add(state_size(_), U32.to_nat((len - pos : U32))), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
  field_remaining_bound(old, name, id, retry, src, len, s, e, pos, st, limit, hl, hu, se, el, ep, pl, hn, snapshot)

def body_mass(blank: Bool, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  ep: MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(pos)), pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.body(blank, Tree.reify(U32, src), len, s, e, pos, cr, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  match blank:
    case True{}:
      blank_mass(old, name, id, retry, src, len, s, e, pos, cr, st, limit,
        MNat.le_trans(U32.to_nat(s), U32.to_nat(e), U32.to_nat(pos), se,
          MNat.le_trans(U32.to_nat(e), U32.to_nat((e + 1 : U32)), U32.to_nat(pos),
            Pair.fst(MNat.le(U32.to_nat(e), U32.to_nat((e + 1 : U32))), MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(len)),
              Drain.cursor_step(e, len, limit, el,
                MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu)), ep)), pl, snapshot)
    case False{}:
      field_mass(old, name, id, retry, src, len, s, e, pos, cr, st, limit, hl, hu, se, el, ep, pl, hn, snapshot)

def body_one_mass(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e, (e + 1 : U32), cr, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  body_mass(U32.is_eq(s, e), old, name, id, retry, src, len, s, e, (e + 1 : U32), cr, st, limit, hl, hu, se, el,
    MNat.le_refl(U32.to_nat((e + 1 : U32))),
    Pair.snd(MNat.le(U32.to_nat(e), U32.to_nat((e + 1 : U32))), MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(len)),
      Drain.cursor_step(e, len, limit, el,
        MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu)), hn, snapshot)

# Keep cursor increments abstract: https://github.com/bendlang/bend/issues/1071.
def cursor_steps(+e: U32, +first: U32, +second: U32, +len: U32, +limit: Nat,
  +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +order: MNat.le(U32.to_nat(first), U32.to_nat(second)),
  +upper: MNat.le(Nat.add(U32.to_nat(e), U32.to_nat(second)), U32.to_nat(len))) ->
  MNat.le(U32.to_nat((e + first : U32)), U32.to_nat((e + second : U32))) &
    MNat.le(U32.to_nat((e + second : U32)), U32.to_nat(len)):
  ((%Equal.sym(Nat, U32.to_nat((e + first : U32)), Nat.add(U32.to_nat(e), U32.to_nat(first)),
      Lemmas.u32_add_nat(e, first, MNat.lt_of_lt_of_le(Nat.add(U32.to_nat(e), U32.to_nat(first)), limit, Lemmas.pow2(32n),
        MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(e), U32.to_nat(first)), U32.to_nat(len), limit,
          MNat.le_trans(Nat.add(U32.to_nat(e), U32.to_nat(first)), Nat.add(U32.to_nat(e), U32.to_nat(second)), U32.to_nat(len),
            MNat.add_le_add_left(U32.to_nat(first), U32.to_nat(second), U32.to_nat(e), order), upper), hl), hu))) :
      MNat.le(_, U32.to_nat((e + second : U32)))
    %Equal.sym(Nat, U32.to_nat((e + second : U32)), Nat.add(U32.to_nat(e), U32.to_nat(second)),
      Lemmas.u32_add_nat(e, second, MNat.lt_of_lt_of_le(Nat.add(U32.to_nat(e), U32.to_nat(second)), limit, Lemmas.pow2(32n),
        MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(e), U32.to_nat(second)), U32.to_nat(len), limit, upper, hl), hu))) :
      MNat.le(Nat.add(U32.to_nat(e), U32.to_nat(first)), _)
    MNat.add_le_add_left(U32.to_nat(first), U32.to_nat(second), U32.to_nat(e), order)),
    Pair.snd(MNat.le(U32.to_nat(e), U32.to_nat((e + second : U32))), MNat.le(U32.to_nat((e + second : U32)), U32.to_nat(len)),
      State.cursor_add(e, second, len, limit, upper, hl, hu)))

def cursor_one_two(+e: U32, +len: U32, +limit: Nat,
  +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)), +hl: MNat.lt(U32.to_nat(len), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), more: {U32.is_lt((e + 1 : U32), len) == True{} : Bool}) ->
  MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat((e + 2 : U32))) &
    MNat.le(U32.to_nat((e + 2 : U32)), U32.to_nat(len)):
  cursor_steps(e, 1, 2, len, limit, hl, hu, {==}, State.crlf_upper(e, len, limit, el, hl, hu, more))

def body_two_mass_of(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit),
  bounds: MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat((e + 2 : U32))) &
    MNat.le(U32.to_nat((e + 2 : U32)), U32.to_nat(len))) ->
  MNat.le(line_mass(len, Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e, (e + 2 : U32), False{}, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  (ep, pl) = bounds
  body_mass(U32.is_eq(s, e), old, name, id, retry, src, len, s, e, (e + 2 : U32), False{}, st, limit, hl, hu, se, el, ep, pl, hn, snapshot)

def body_two_mass(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  more: {U32.is_lt((e + 1 : U32), len) == True{} : Bool},
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e, (e + 2 : U32), False{}, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  body_two_mass_of(old, name, id, retry, src, len, s, e, st, limit, hl, hu, se, el, hn, snapshot,
    cursor_one_two(e, len, limit, el,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu, more))

def crlf_mass(lf: Bool, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  more: {U32.is_lt((e + 1 : U32), len) == True{} : Bool},
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e,
    Bool.pick(U32, lf, (e + 2 : U32), (e + 1 : U32)), False{}, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  match lf:
    case True{}: body_two_mass(old, name, id, retry, src, len, s, e, st, limit, hl, hu, se, el, more, hn, snapshot)
    case False{}: body_one_mass(old, name, id, retry, src, len, s, e, False{}, st, limit, hl, hu, se, el, hn, snapshot)

def cr_follow_mass(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  more: {U32.is_lt((e + 1 : U32), len) == True{} : Bool},
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.crlf(len, s, e, st, Bytes.peek(Tree.reify(U32, src), (e + 1 : U32)))),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), (e + 1 : U32)),
    (Tree.reify(U32, src), Packed.peek(src, (e + 1 : U32))), Buffer.tree_peek(src, (e + 1 : U32))) :
    MNat.le(line_mass(len, Sse.line.crlf(len, s, e, st, _)), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
  crlf_mass(U32.is_eq(Packed.peek(src, (e + 1 : U32)), 10), old, name, id, retry, src, len, s, e, st, limit, hl, hu, se, el, more, hn, snapshot)

def cr_mass(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, src), len, s, e, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  State.choose(Field.state_snapshot(name, old, id, retry, st, limit) ->
    MNat.le(line_mass(len, Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, src), len, s, e, st)),
      Nat.add(String.length(old), U32.to_nat((len - s : U32)))), U32.is_lt((e + 1 : U32), len),
    +more => state => (
      %Equal.sym(Bool, U32.is_lt((e + 1 : U32), len), True{}, more) :
        MNat.le(line_mass(len, Sse.line.cr(_, Tree.reify(U32, src), len, s, e, st)), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
      cr_follow_mass(old, name, id, retry, src, len, s, e, st, limit, hl, hu, se, el, more, hn, state)),
    stopped => state => (
      %Equal.sym(Bool, U32.is_lt((e + 1 : U32), len), False{}, stopped) :
        MNat.le(line_mass(len, Sse.line.cr(_, Tree.reify(U32, src), len, s, e, st)), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
      body_one_mass(old, name, id, retry, src, len, s, e, True{}, st, limit, hl, hu, se, el, hn, state)))(snapshot)

def term_mass(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit), terminal: Drain.scan_terminal(src, e)) ->
  MNat.le(line_mass(len, Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e))),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  match terminal:
    case Inl{lf}:
      %Equal.sym(Sse.Line, Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e)),
        Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
        Drain.line_term_lf(src, len, s, e, st, lf)) :
        MNat.le(line_mass(len, _), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
      body_one_mass(old, name, id, retry, src, len, s, e, False{}, st, limit, hl, hu, se, el, hn, snapshot)
    case Inr{cr}:
      %Equal.sym(Sse.Line, Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e)),
        Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, src), len, s, e, st),
        Drain.line_term_cr(src, len, s, e, st, cr)) :
        MNat.le(line_mass(len, _), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
      cr_mass(old, name, id, retry, src, len, s, e, st, limit, hl, hu, se, el, hn, snapshot)

def line_end_mass(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.le(U32.to_nat(e), U32.to_nat(len)),
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  result: {e == len : U32} | Drain.scan_terminal(src, e),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  State.choose(({e == len : U32} | Drain.scan_terminal(src, e)) ->
    Field.state_snapshot(name, old, id, retry, st, limit) ->
    MNat.le(line_mass(len, Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st)),
      Nat.add(String.length(old), U32.to_nat((len - s : U32)))), U32.is_eq(e, len),
    exhausted => result => state => (
      %Equal.sym(Bool, U32.is_eq(e, len), True{}, exhausted) :
        MNat.le(line_mass(len, Sse.line.end(_, Tree.reify(U32, src), len, s, e, cr, st)), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
      %Equal.sym(Nat, state_size(st), String.length(old), snapshot_size(name, old, id, retry, st, limit, state)) :
        MNat.le(Nat.add(_, U32.to_nat((len - s : U32))), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
      MNat.le_refl(Nat.add(String.length(old), U32.to_nat((len - s : U32))))),
    +not_end => result => state => (
      %Equal.sym(Bool, U32.is_eq(e, len), False{}, not_end) :
        MNat.le(line_mass(len, Sse.line.end(_, Tree.reify(U32, src), len, s, e, cr, st)), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
      term_mass(old, name, id, retry, src, len, s, e, st, limit, hl, hu, se, Field.strict_of_le_ne(e, len, el, not_end),
        Refinement.accumulation_bound(String.length(old), U32.to_nat((e - s : U32)), U32.to_nat((len - s : U32)), limit,
          Refinement.prefix_length_le(s, e, len, se, el), hn), state, State.terminal_inside(src, e, len, not_end, result))))(result, snapshot)

def line_mass_witness(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit),
  witness: Drain.line_scan_bounded_type(src, s, len, Refinement.eol_index(U32.to_nat((len - s : U32)), src, s))) ->
  MNat.le(line_mass(len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  (+e, scan, se, el, result) = witness
  %Equal.sym(Sse.Line, Sse.line(Tree.reify(U32, src), len, s, s, cr, st),
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st),
    Drain.line_scanned_at(src, len, s, e, cr, st, scan)) :
    MNat.le(line_mass(len, _), Nat.add(String.length(old), U32.to_nat((len - s : U32))))
  line_end_mass(old, name, id, retry, src, len, s, e, cr, st, limit, hl, hu, se, el, hn, result, snapshot)

def line_mass_bounded(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.le(line_mass(len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32)))):
  line_mass_witness(old, name, id, retry, src, len, s, cr, st, limit, hl, hu, hn, snapshot,
    Drain.line_scan_bounded(src, s, len, limit, sl,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu))

def got_position(-a: Array<U32>, +pos: U32, +cr: Bool, r: Sse.St & Maybe<&1, Sse.Message>) ->
  {line_position(Sse.line.got(a, pos, cr, r)) == pos : U32}:
  match r:
    case (st, None{}): {==}
    case (st, Some{message}): {==}

def set_position(r: Array<U32> & Sse.St, +pos: U32, +cr: Bool) ->
  {line_position(Sse.line.set(pos, cr, r)) == pos : U32}:
  match r:
    case (a, st): {==}

def canonical_body_position(blank: Bool, +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool,
  +name: String, +data_len: U32, +data: Tree.Tree<U32>, +id: String, +retry: Maybe<&2, U32>) ->
  {line_position(Sse.line.body(blank, Tree.reify(U32, src), len, s, e, pos, cr,
    Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry})) == pos : U32}:
  match blank:
    case True{}:
      got_position(Tree.reify(U32, src), pos, cr, Sse.dispatch(Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}))
    case False{}:
      set_position(Sse.field(Tree.reify(U32, src), len, s, e,
        Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}), pos, cr)

def body_position(+blank: Bool, +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  {line_position(Sse.line.body(blank, Tree.reify(U32, src), len, s, e, pos, cr, st)) == pos : U32}:
  (+data_len, +data, eq, shape, length, bound, reads) = snapshot
  %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
    {line_position(Sse.line.body(blank, Tree.reify(U32, src), len, s, e, pos, cr, _)) == pos : U32}
  canonical_body_position(blank, src, len, s, e, pos, cr, name, data_len, data, id, retry)

def cursor_strict(+e: U32, +len: U32, +limit: Nat,
  el: MNat.lt(U32.to_nat(e), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.lt(U32.to_nat(e), U32.to_nat((e + 1 : U32))):
  %Equal.sym(Nat, U32.to_nat((e + 1 : U32)), 1n+U32.to_nat(e),
    Packed.add_one_nat(e, MNat.lt_of_lt_of_le(1n+U32.to_nat(e), limit, Lemmas.pow2(32n),
      MNat.lt_of_le_of_lt(1n+U32.to_nat(e), U32.to_nat(len), limit, MNat.succ_le_of_lt(U32.to_nat(e), U32.to_nat(len), el), hl), hu))) :
    MNat.lt(U32.to_nat(e), _)
  MNat.lt_succ_self(U32.to_nat(e))

def body_progress(+blank: Bool, +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(U32.to_nat(len), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  ep: MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(pos)), pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  MNat.lt(U32.to_nat(s), U32.to_nat(line_position(Sse.line.body(blank, Tree.reify(U32, src), len, s, e, pos, cr, st)))) &
    MNat.le(U32.to_nat(line_position(Sse.line.body(blank, Tree.reify(U32, src), len, s, e, pos, cr, st))), U32.to_nat(len)):
  %Equal.sym(U32, line_position(Sse.line.body(blank, Tree.reify(U32, src), len, s, e, pos, cr, st)), pos,
    body_position(blank, src, len, s, e, pos, cr, old, name, id, retry, st, limit, snapshot)) :
    MNat.lt(U32.to_nat(s), U32.to_nat(_)) & MNat.le(U32.to_nat(_), U32.to_nat(len))
  (MNat.lt_of_lt_of_le(U32.to_nat(s), U32.to_nat((e + 1 : U32)), U32.to_nat(pos),
    MNat.lt_of_le_of_lt(U32.to_nat(s), U32.to_nat(e), U32.to_nat((e + 1 : U32)), se, cursor_strict(e, len, limit, el, hl, hu)), ep), pl)

def reads_copy_step(+c: U32, +tail: String, +src: Tree.Tree<U32>, +i: U32,
  +head: {Packed.peek(src, i) == c : U32},
  rest: Packed.Reads(tail, src, (i + 1 : U32)) & Packed.Reads(tail, src, (i + 1 : U32))) ->
  Packed.Reads(SCon{Chr{c}, tail}, src, i) & Packed.Reads(SCon{Chr{c}, tail}, src, i):
  (left, right) = rest
  ((head, left), (head, right))

def reads_copy(text: String, +src: Tree.Tree<U32>, +i: U32, reads: Packed.Reads(text, src, i)) ->
  Packed.Reads(text, src, i) & Packed.Reads(text, src, i):
  match text:
    case SNil{}: (Unit{}, Unit{})
    case SCon{Chr{+c}, +tail}:
      (head, rest) = reads
      reads_copy_step(c, tail, src, i, head, reads_copy(tail, src, (i + 1 : U32), rest))

def snapshot_copy_parts(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, -st: Sse.St, +limit: Nat,
  +eq: {st == Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry} : Sse.St},
  +length: {U32.to_nat(len) == String.length(old) : Nat},
  +bound: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit),
  shapes: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)) &
    Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  observations: Packed.Reads(old, src, 0) & Packed.Reads(old, src, 0)) ->
  Field.state_snapshot(name, old, id, retry, st, limit) & Field.state_snapshot(name, old, id, retry, st, limit):
  (left_shape, right_shape) = shapes
  (left_reads, right_reads) = observations
  ((len, src, eq, left_shape, length, bound, left_reads), (len, src, eq, right_shape, length, bound, right_reads))

def snapshot_copy(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  Field.state_snapshot(name, old, id, retry, st, limit) & Field.state_snapshot(name, old, id, retry, st, limit):
  (+len, +src, eq, shape, length, bound, reads) = snapshot
  snapshot_copy_parts(old, name, id, retry, len, src, st, limit, eq, length, bound,
    Bound.shape_copy(Local.depth(Local.words(len)), Packed.as_bits(src), shape), reads_copy(old, src, 0, reads))

def line_refines_budgeted_parts(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  +starts: Offset.offset(delta, s, t), +ends: Offset.offset(delta, len, other),
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left_states: Field.state_snapshot(name, old, id, retry, st, limit) & Field.state_snapshot(name, old, id, retry, st, limit),
  right_states: Field.state_snapshot(name, old, id, retry, next, limit) & Field.state_snapshot(name, old, id, retry, next, limit)) ->
  Drain.line_relation(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit) &
    MNat.le(line_mass(len, Sse.line(Tree.reify(U32, a), len, s, s, cr, st)), Nat.add(String.length(old), U32.to_nat((len - s : U32)))) &
    MNat.le(line_mass(other, Sse.line(Tree.reify(U32, b), other, t, t, cr, next)), Nat.add(String.length(old), U32.to_nat((other - t : U32)))):
  (left_relation, left_mass) = left_states
  (right_relation, right_mass) = right_states
  (State.line_refines(old, name, id, retry, a, b, len, other, s, t, cr, st, next, delta, limit,
      hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, left_relation, right_relation, same),
    line_mass_bounded(old, name, id, retry, a, len, s, cr, st, limit, hl, hu, sl, hn, left_mass),
    line_mass_bounded(old, name, id, retry, b, other, t, cr, next, limit, hr, hu, to,
      (%Field.relocated_width(delta, s, t, len, other, sl, to, starts, ends) :
        MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat(_)), 1n), 3n), limit)
       hn), right_mass))

def line_refines_budgeted(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Drain.line_relation(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit) &
    MNat.le(line_mass(len, Sse.line(Tree.reify(U32, a), len, s, s, cr, st)), Nat.add(String.length(old), U32.to_nat((len - s : U32)))) &
    MNat.le(line_mass(other, Sse.line(Tree.reify(U32, b), other, t, t, cr, next)), Nat.add(String.length(old), U32.to_nat((other - t : U32)))):
  line_refines_budgeted_parts(old, name, id, retry, a, b, len, other, s, t, cr, st, next, delta, limit,
    hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, same,
    snapshot_copy(old, name, id, retry, st, limit, left_state), snapshot_copy(old, name, id, retry, next, limit, right_state))

def reserve_bound(+after: Nat, +before: Nat, +limit: Nat,
  mass: MNat.le(after, before), bound: MNat.lt(Nat.add(Nat.add(before, 1n), 3n), limit)) ->
  MNat.lt(Nat.add(Nat.add(after, 1n), 3n), limit):
  MNat.lt_of_le_of_lt(Nat.add(Nat.add(after, 1n), 3n), Nat.add(Nat.add(before, 1n), 3n), limit,
    MNat.add_le_add_right(Nat.add(after, 1n), Nat.add(before, 1n), 3n,
      MNat.add_le_add_right(after, before, 1n, mass)), bound)

def continuation_bound(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  -st: Sse.St, +remaining: Nat, +before: Nat, +limit: Nat,
  mass: MNat.le(Nat.add(state_size(st), remaining), before),
  bound: MNat.lt(Nat.add(Nat.add(before, 1n), 3n), limit),
  snapshot: Field.state_snapshot(name, text, id, retry, st, limit)) ->
  MNat.lt(Nat.add(Nat.add(Nat.add(String.length(text), remaining), 1n), 3n), limit):
  reserve_bound(Nat.add(String.length(text), remaining), before, limit,
    (%snapshot_size(name, text, id, retry, st, limit, snapshot) :
      MNat.le(Nat.add(_, remaining), before)
     mass), bound)
