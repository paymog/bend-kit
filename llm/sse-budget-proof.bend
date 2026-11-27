import Base
import ./sse.bend as Sse
import ./sse-field-proof.bend as Field
import ./sse-refinement-proof.bend as Refinement
import ./sse-reader-proof.bend as Reader
import ./sse-buffer-proof.bend as Buffer
import ./sse-drain-proof.bend as Drain
import ./sse-state-proof.bend as State
import ./sse-offset-proof.bend as Offset
import ./sse-scan-proof.bend as Scan
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

def is_more(line: Sse.Line) -> Bool:
  match line:
    case Sse.LMore{a, pos, cr, st}: True{}
    case Sse.LWant{a, pos, cr, st}: False{}
    case Sse.LGot{a, pos, cr, st, message}: False{}

def line_progress(+s: U32, +len: U32, -line: Sse.Line) -> Type:
  {is_more(line) == False{} : Bool} |
    (&next: U32 -> {line_position(line) == next : U32} &
      MNat.lt(U32.to_nat(s), U32.to_nat(next)) & MNat.le(U32.to_nat(next), U32.to_nat(len)))

def body_line_progress(+blank: Bool, +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  ep: MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(pos)), pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  line_progress(s, len, Sse.line.body(blank, Tree.reify(U32, src), len, s, e, pos, cr, st)):
  Inr{(pos, body_position(blank, src, len, s, e, pos, cr, old, name, id, retry, st, limit, snapshot),
    MNat.lt_of_lt_of_le(U32.to_nat(s), U32.to_nat((e + 1 : U32)), U32.to_nat(pos),
      MNat.lt_of_le_of_lt(U32.to_nat(s), U32.to_nat(e), U32.to_nat((e + 1 : U32)), se, cursor_strict(e, len, limit, el, hl, hu)), ep), pl)}

def body_one_progress(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +cr: Bool,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  line_progress(s, len, Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e, (e + 1 : U32), cr, st)):
  body_line_progress(U32.is_eq(s, e), src, len, s, e, (e + 1 : U32), cr, old, name, id, retry, st, limit, hl, hu, se, el,
    MNat.le_refl(U32.to_nat((e + 1 : U32))),
    Pair.snd(MNat.le(U32.to_nat(e), U32.to_nat((e + 1 : U32))), MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(len)),
      Drain.cursor_step(e, len, limit, el, hl, hu)), snapshot)

def body_two_progress_of(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(U32.to_nat(len), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit),
  bounds: MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat((e + 2 : U32))) &
    MNat.le(U32.to_nat((e + 2 : U32)), U32.to_nat(len))) ->
  line_progress(s, len, Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e, (e + 2 : U32), False{}, st)):
  (ep, pl) = bounds
  body_line_progress(U32.is_eq(s, e), src, len, s, e, (e + 2 : U32), False{}, old, name, id, retry, st, limit, hl, hu, se, el, ep, pl, snapshot)

def crlf_progress(lf: Bool, +src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  more: {U32.is_lt((e + 1 : U32), len) == True{} : Bool},
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  line_progress(s, len, Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e,
    Bool.pick(U32, lf, (e + 2 : U32), (e + 1 : U32)), False{}, st)):
  match lf:
    case True{}:
      body_two_progress_of(src, len, s, e, old, name, id, retry, st, limit, hl, hu, se, el, snapshot,
        cursor_one_two(e, len, limit, el, hl, hu, more))
    case False{}:
      body_one_progress(src, len, s, e, False{}, old, name, id, retry, st, limit, hl, hu, se, el, snapshot)

def cr_follow_progress(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(U32.to_nat(len), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  more: {U32.is_lt((e + 1 : U32), len) == True{} : Bool},
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  line_progress(s, len, Sse.line.crlf(len, s, e, st, Bytes.peek(Tree.reify(U32, src), (e + 1 : U32)))):
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), (e + 1 : U32)),
    (Tree.reify(U32, src), Packed.peek(src, (e + 1 : U32))), Buffer.tree_peek(src, (e + 1 : U32))) :
    line_progress(s, len, Sse.line.crlf(len, s, e, st, _))
  crlf_progress(U32.is_eq(Packed.peek(src, (e + 1 : U32)), 10), src, len, s, e, old, name, id, retry, st, limit, hl, hu, se, el, more, snapshot)

def cr_progress(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  line_progress(s, len, Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, src), len, s, e, st)):
  State.choose(Field.state_snapshot(name, old, id, retry, st, limit) ->
    line_progress(s, len, Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, src), len, s, e, st)),
    U32.is_lt((e + 1 : U32), len),
    +more => state => (
      %Equal.sym(Bool, U32.is_lt((e + 1 : U32), len), True{}, more) :
        line_progress(s, len, Sse.line.cr(_, Tree.reify(U32, src), len, s, e, st))
      cr_follow_progress(src, len, s, e, old, name, id, retry, st, limit, hl, hu, se, el, more, state)),
    stopped => state => (
      %Equal.sym(Bool, U32.is_lt((e + 1 : U32), len), False{}, stopped) :
        line_progress(s, len, Sse.line.cr(_, Tree.reify(U32, src), len, s, e, st))
      body_one_progress(src, len, s, e, True{}, old, name, id, retry, st, limit, hl, hu, se, el, state)))(snapshot)

def term_progress(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(U32.to_nat(len), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), el: MNat.lt(U32.to_nat(e), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit), terminal: Drain.scan_terminal(src, e)) ->
  line_progress(s, len, Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e))):
  match terminal:
    case Inl{lf}:
      %Equal.sym(Sse.Line, Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e)),
        Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
        Drain.line_term_lf(src, len, s, e, st, lf)) : line_progress(s, len, _)
      body_one_progress(src, len, s, e, False{}, old, name, id, retry, st, limit, hl, hu, se, el, snapshot)
    case Inr{cr}:
      %Equal.sym(Sse.Line, Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e)),
        Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, src), len, s, e, st),
        Drain.line_term_cr(src, len, s, e, st, cr)) : line_progress(s, len, _)
      cr_progress(src, len, s, e, old, name, id, retry, st, limit, hl, hu, se, el, snapshot)

def line_end_progress(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +cr: Bool,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +el: MNat.le(U32.to_nat(e), U32.to_nat(len)),
  result: {e == len : U32} | Drain.scan_terminal(src, e),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  line_progress(s, len, Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st)):
  State.choose(({e == len : U32} | Drain.scan_terminal(src, e)) ->
    Field.state_snapshot(name, old, id, retry, st, limit) ->
    line_progress(s, len, Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st)),
    U32.is_eq(e, len),
    exhausted => result => state => (
      %Equal.sym(Bool, U32.is_eq(e, len), True{}, exhausted) :
        line_progress(s, len, Sse.line.end(_, Tree.reify(U32, src), len, s, e, cr, st))
      Inl{{==}}),
    +not_end => result => state => (
      %Equal.sym(Bool, U32.is_eq(e, len), False{}, not_end) :
        line_progress(s, len, Sse.line.end(_, Tree.reify(U32, src), len, s, e, cr, st))
      term_progress(src, len, s, e, old, name, id, retry, st, limit, hl, hu, se,
        Field.strict_of_le_ne(e, len, el, not_end), state, State.terminal_inside(src, e, len, not_end, result))))(result, snapshot)

def line_progress_witness(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(U32.to_nat(len), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit),
  witness: Drain.line_scan_bounded_type(src, s, len, Refinement.eol_index(U32.to_nat((len - s : U32)), src, s))) ->
  line_progress(s, len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st)):
  (+e, scan, se, el, result) = witness
  %Equal.sym(Sse.Line, Sse.line(Tree.reify(U32, src), len, s, s, cr, st),
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st),
    Drain.line_scanned_at(src, len, s, e, cr, st, scan)) : line_progress(s, len, _)
  line_end_progress(src, len, s, e, cr, old, name, id, retry, st, limit, hl, hu, se, el, result, snapshot)

def line_progress_bounded(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  line_progress(s, len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st)):
  line_progress_witness(src, len, s, cr, old, name, id, retry, st, limit, hl, hu, snapshot,
    Drain.line_scan_bounded(src, s, len, limit, sl, hl, hu))

def line_reserved(+len: U32, line: Sse.Line, +limit: Nat) -> Type:
  MNat.lt(Nat.add(Nat.add(line_mass(len, line), 1n), 3n), limit)

def step_certificate(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, -st: Sse.St, +limit: Nat) -> Type:
  Drain.line_valid(len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st), limit) &
    line_reserved(len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st), limit) &
    line_progress(s, len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st))

def step_certificate_parts(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, st: Sse.St,
  +old: String, +limit: Nat,
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  progress: line_progress(s, len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st)),
  cert: Drain.line_relation(len, len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st),
      Sse.line(Tree.reify(U32, src), len, s, s, cr, st), limit) &
    MNat.le(line_mass(len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st)), Nat.add(String.length(old), U32.to_nat((len - s : U32)))) &
    MNat.le(line_mass(len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st)), Nat.add(String.length(old), U32.to_nat((len - s : U32))))) ->
  step_certificate(src, len, s, cr, st, limit):
  ((views, valid, other), mass, other_mass) = cert
  (valid, reserve_bound(line_mass(len, Sse.line(Tree.reify(U32, src), len, s, s, cr, st)),
    Nat.add(String.length(old), U32.to_nat((len - s : U32))), limit, mass, hn), progress)

def step_certificate_snapshots(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, st: Sse.St,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  shapes: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)) & Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  states: Field.state_snapshot(name, old, id, retry, st, limit) &
    (Field.state_snapshot(name, old, id, retry, st, limit) & Field.state_snapshot(name, old, id, retry, st, limit))) ->
  step_certificate(src, len, s, cr, st, limit):
  (left_shape, right_shape) = shapes
  (progress_state, left_state, right_state) = states
  step_certificate_parts(src, len, s, cr, st, old, limit, hn,
    line_progress_bounded(src, len, s, cr, old, name, id, retry, st, limit,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl),
      hu, sl, progress_state),
    line_refines_budgeted(old, name, id, retry, src, src, len, len, s, s, cr, st, st, 0n, limit,
      hl, hl, hu, sl, sl, {==}, {==}, hn, left_shape, right_shape, left_state, right_state, {==}))

def step_certificate_copy(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, st: Sse.St,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  states: Field.state_snapshot(name, old, id, retry, st, limit) & Field.state_snapshot(name, old, id, retry, st, limit)) ->
  step_certificate(src, len, s, cr, st, limit):
  (progress, pair) = states
  step_certificate_snapshots(src, len, s, cr, st, old, name, id, retry, limit, hl, hu, sl, hn,
    Bound.shape_copy(Local.depth(Local.words(len)), Packed.as_bits(src), shape),
    (progress, snapshot_copy(old, name, id, retry, st, limit, pair)))

def step_certificate_bounded(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, -st: Sse.St,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  reserved: MNat.lt(Nat.add(Nat.add(Nat.add(state_size(st), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  states: Field.state_snapshot(name, old, id, retry, st, limit) & Field.state_snapshot(name, old, id, retry, st, limit)) ->
  step_certificate(src, len, s, cr, st, limit):
  (bound_state, rest) = states
  (+data_len, +data, eq, data_shape, length, bound, reads) = rest
  +hn : MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit) = (
    %snapshot_size(name, old, id, retry, st, limit, bound_state) :
      MNat.lt(Nat.add(Nat.add(Nat.add(_, U32.to_nat((len - s : U32))), 1n), 3n), limit)
    reserved)
  %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
    step_certificate(src, len, s, cr, _, limit)
  step_certificate_copy(src, len, s, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry},
    old, name, id, retry, limit, hl, hu, sl, hn, shape,
    snapshot_copy(old, name, id, retry, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit,
      (data_len, data, {==}, data_shape, length, bound, reads)))

def step_preserves(+len: U32, -a: Array<U32>, +pos: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  reserved: line_reserved(len, Sse.LMore{a, pos, cr, st}, limit),
  valid: Drain.line_valid(len, Sse.LMore{a, pos, cr, st}, limit)) ->
  Drain.line_valid(len, Sse.line(a, len, pos, pos, cr, st), limit) &
    line_reserved(len, Sse.line(a, len, pos, pos, cr, st), limit) &
    line_progress(pos, len, Sse.line(a, len, pos, pos, cr, st)):
  ((+src, prefix, tail, eq, shape, hl, lower, upper, prefix_length, tail_length, reads, clean),
    +name, +old, +id, +retry, state) = valid
  %Equal.sym(Array<U32>, a, Tree.reify(U32, src), eq) :
    Drain.line_valid(len, Sse.line(_, len, pos, pos, cr, st), limit) &
      line_reserved(len, Sse.line(_, len, pos, pos, cr, st), limit) &
      line_progress(pos, len, Sse.line(_, len, pos, pos, cr, st))
  step_certificate_bounded(src, len, pos, cr, st, old, name, id, retry, limit, hl, hu, upper, reserved,
    shape, snapshot_copy(old, name, id, retry, st, limit, state))

def remaining_strict(+len: U32, +s: U32, +pos: U32,
  +sp: MNat.lt(U32.to_nat(s), U32.to_nat(pos)), pl: MNat.le(U32.to_nat(pos), U32.to_nat(len))) ->
  MNat.lt(U32.to_nat((len - pos : U32)), U32.to_nat((len - s : U32))):
  %Refinement.split_span(s, pos, len, MNat.le_of_lt(U32.to_nat(s), U32.to_nat(pos), sp), pl) :
    MNat.lt(U32.to_nat((len - pos : U32)), _)
  MNat.add_lt_add_right(0n, U32.to_nat((pos - s : U32)), U32.to_nat((len - pos : U32)),
    (%Equal.sym(Nat, U32.to_nat((pos - s : U32)), Nat.sub(U32.to_nat(pos), U32.to_nat(s)),
      Lemmas.u32_sub_nat(pos, s, MNat.le_of_lt(U32.to_nat(s), U32.to_nat(pos), sp))) :
      MNat.lt(0n, _)
     MNat.sub_pos_of_lt(U32.to_nat(s), U32.to_nat(pos), sp)))

def fuel_fits(+fuel: Nat, +len: U32, -line: Sse.Line) -> Type:
  {is_more(line) == True{} : Bool} -> MNat.lt(U32.to_nat((len - line_position(line) : U32)), fuel)

def fuel_after_progress(+fuel: Nat, +len: U32, +s: U32, -line: Sse.Line,
  before: MNat.lt(U32.to_nat((len - s : U32)), 1n+fuel),
  progress: line_progress(s, len, line)) -> fuel_fits(fuel, len, line):
  match progress:
    case Inl{stopped}:
      continued => Empty.absurd(MNat.lt(U32.to_nat((len - line_position(line) : U32)), fuel),
        MNat.internal_false_ne_true(Equal.trans(Bool, False{}, is_more(line), True{},
          Equal.sym(Bool, is_more(line), False{}, stopped), continued)))
    case Inr{(+pos, eq, sp, pl)}:
      continued => (
        %Equal.sym(U32, line_position(line), pos, eq) : MNat.lt(U32.to_nat((len - _ : U32)), fuel)
        MNat.lt_of_lt_of_le(U32.to_nat((len - pos : U32)), U32.to_nat((len - s : U32)), fuel,
          remaining_strict(len, s, pos, sp, pl), MNat.le_of_lt_succ(U32.to_nat((len - s : U32)), fuel, before)))

def loop_halts_step(+fuel: Nat, +len: U32, +pos: U32, -line: Sse.Line, +limit: Nat,
  before: MNat.lt(U32.to_nat((len - pos : U32)), 1n+fuel),
  continue: fuel_fits(fuel, len, line) -> line_reserved(len, line, limit) ->
    Drain.line_valid(len, line, limit) -> Drain.halts_within(fuel, line, len),
  certificate: Drain.line_valid(len, line, limit) & line_reserved(len, line, limit) & line_progress(pos, len, line)) ->
  Drain.halts_within(fuel, line, len):
  (valid, reserved, progress) = certificate
  continue(fuel_after_progress(fuel, len, pos, line, before, progress), reserved, valid)

def halts_goal(+fuel: Nat, +len: U32, -line: Sse.Line, +limit: Nat) -> Type:
  fuel_fits(fuel, len, line) -> line_reserved(len, line, limit) ->
    Drain.line_valid(len, line, limit) -> Drain.halts_within(fuel, line, len)

def loop_halts_zero(+len: U32, line: Sse.Line, +limit: Nat) -> halts_goal(0n, len, line, limit):
  match line:
    case Sse.LMore{a, pos, cr, st}:
      fits => reserved => valid => MNat.lt_zero(U32.to_nat((len - pos : U32)))(fits({==}))
    case Sse.LWant{a, pos, cr, st}: fits => reserved => valid => Unit{}
    case Sse.LGot{a, pos, cr, st, message}: fits => reserved => valid => Unit{}

def loop_halts_succ(+fuel: Nat, +len: U32, +limit: Nat, +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ih: @line: Sse.Line -> halts_goal(fuel, len, line, limit),
  line: Sse.Line) -> halts_goal(1n+fuel, len, line, limit):
  match line:
    case Sse.LMore{a, +pos, +cr, st}:
      fits => reserved => valid =>
        loop_halts_step(fuel, len, pos, Sse.line(a, len, pos, pos, cr, st), limit, fits({==}),
          next_fits => next_reserved => next_valid =>
            ih(Sse.line(a, len, pos, pos, cr, st), next_fits, next_reserved, next_valid),
          step_preserves(len, a, pos, cr, st, limit, hu, reserved, valid))
    case Sse.LWant{a, pos, cr, st}: fits => reserved => valid => Unit{}
    case Sse.LGot{a, pos, cr, st, message}: fits => reserved => valid => Unit{}

def loop_halts(fuel: Nat, +len: U32, +limit: Nat, +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  @line: Sse.Line -> halts_goal(fuel, len, line, limit):
  match fuel:
    case 0n: line => loop_halts_zero(len, line, limit)
    case 1n+ +p:
      line => loop_halts_succ(p, len, limit, hu, loop_halts(p, len, limit, hu), line)

def runtime_halts_of(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  certificate: step_certificate(src, len, s, cr, st, limit)) ->
  Drain.halts_within(Nat.add(U32.to_nat((len - s : U32)), 2n),
    Sse.line(Tree.reify(U32, src), len, s, s, cr, st), len):
  (valid, reserved, progress) = certificate
  loop_halts(Nat.add(U32.to_nat((len - s : U32)), 2n), len, limit, hu,
    Sse.line(Tree.reify(U32, src), len, s, s, cr, st),
    fuel_after_progress(Nat.add(U32.to_nat((len - s : U32)), 2n), len, s,
      Sse.line(Tree.reify(U32, src), len, s, s, cr, st),
      MNat.lt_of_lt_of_le(U32.to_nat((len - s : U32)), 1n+U32.to_nat((len - s : U32)),
        1n+Nat.add(U32.to_nat((len - s : U32)), 2n),
        MNat.lt_succ_self(U32.to_nat((len - s : U32))),
        MNat.succ_le_succ(U32.to_nat((len - s : U32)), Nat.add(U32.to_nat((len - s : U32)), 2n),
          MNat.le_add_right(U32.to_nat((len - s : U32)), 2n))), progress),
    reserved, valid)

def runtime_halts(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, -st: Sse.St,
  +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  snapshot: Field.state_snapshot(name, old, id, retry, st, limit)) ->
  Drain.halts_within(Nat.add(U32.to_nat((len - s : U32)), 2n),
    Sse.line(Tree.reify(U32, src), len, s, s, cr, st), len):
  (+data_len, +data, eq, data_shape, length, bound, reads) = snapshot
  %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
    Drain.halts_within(Nat.add(U32.to_nat((len - s : U32)), 2n),
      Sse.line(Tree.reify(U32, src), len, s, s, cr, _), len)
  runtime_halts_of(src, len, s, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit, hu,
    step_certificate_copy(src, len, s, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry},
      old, name, id, retry, limit, hl, hu, sl, hn, shape,
      snapshot_copy(old, name, id, retry, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit,
        (data_len, data, {==}, data_shape, length, bound, reads))))

def snapshot_for_view(view: String & String & String & Maybe<&2, U32>, -st: Sse.St, +limit: Nat) -> Type:
  (name, text, id, retry) = view
  Field.state_snapshot(name, text, id, retry, st, limit)

def snapshot_view_finish(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +other_name: String, +other_text: String, +other_id: String, +other_retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  target: {Drain.state_view(st) == (name, text, id, retry) : String & String & String & Maybe<&2, U32>},
  snapshot: Field.state_snapshot(other_name, other_text, other_id, other_retry, st, limit),
  observation: {Drain.state_view(st) == (other_name, other_text, other_id, other_retry) :
    String & String & String & Maybe<&2, U32>} & Drain.state_valid(st, limit)) ->
  Field.state_snapshot(name, text, id, retry, st, limit):
  (eq, valid) = observation
  %Equal.trans(String & String & String & Maybe<&2, U32>, (other_name, other_text, other_id, other_retry),
    Drain.state_view(st), (name, text, id, retry),
    Equal.sym(String & String & String & Maybe<&2, U32>, Drain.state_view(st), (other_name, other_text, other_id, other_retry), eq), target) :
    snapshot_for_view(_, st, limit)
  snapshot

def snapshot_view_copies(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +other_name: String, +other_text: String, +other_id: String, +other_retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  target: {Drain.state_view(st) == (name, text, id, retry) : String & String & String & Maybe<&2, U32>},
  states: Field.state_snapshot(other_name, other_text, other_id, other_retry, st, limit) &
    Field.state_snapshot(other_name, other_text, other_id, other_retry, st, limit)) ->
  Field.state_snapshot(name, text, id, retry, st, limit):
  (observe, keep) = states
  snapshot_view_finish(name, text, id, retry, other_name, other_text, other_id, other_retry, st, limit, target, keep,
    Drain.snapshot_observe(other_name, other_text, other_id, other_retry, st, limit, hu, observe))

def snapshot_from_view(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  target: {Drain.state_view(st) == (name, text, id, retry) : String & String & String & Maybe<&2, U32>},
  valid: Drain.state_valid(st, limit)) -> Field.state_snapshot(name, text, id, retry, st, limit):
  (+other_name, +other_text, +other_id, +other_retry, snapshot) = valid
  snapshot_view_copies(name, text, id, retry, other_name, other_text, other_id, other_retry, st, limit, hu, target,
    snapshot_copy(other_text, other_name, other_id, other_retry, st, limit, snapshot))

def common_states(-left: Sse.St, -right: Sse.St, +limit: Nat) -> Type:
  &name: String -> &text: String -> &id: String -> &retry: Maybe<&2, U32> ->
    Field.state_snapshot(name, text, id, retry, left, limit) &
    Field.state_snapshot(name, text, id, retry, right, limit)

def common_states_observed(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  -left: Sse.St, -right: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  same: {Drain.state_view(left) == Drain.state_view(right) : String & String & String & Maybe<&2, U32>},
  snapshot: Field.state_snapshot(name, text, id, retry, left, limit),
  right_valid: Drain.state_valid(right, limit),
  observation: {Drain.state_view(left) == (name, text, id, retry) :
    String & String & String & Maybe<&2, U32>} & Drain.state_valid(left, limit)) ->
  common_states(left, right, limit):
  (eq, valid) = observation
  (name, text, id, retry, snapshot,
    snapshot_from_view(name, text, id, retry, right, limit, hu,
      Equal.trans(String & String & String & Maybe<&2, U32>, Drain.state_view(right), Drain.state_view(left),
        (name, text, id, retry),
        Equal.sym(String & String & String & Maybe<&2, U32>, Drain.state_view(left), Drain.state_view(right), same), eq), right_valid))

def common_states_copies(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  -left: Sse.St, -right: Sse.St, +limit: Nat, +hu: MNat.le(limit, Lemmas.pow2(32n)),
  same: {Drain.state_view(left) == Drain.state_view(right) : String & String & String & Maybe<&2, U32>},
  right_valid: Drain.state_valid(right, limit),
  states: Field.state_snapshot(name, text, id, retry, left, limit) & Field.state_snapshot(name, text, id, retry, left, limit)) ->
  common_states(left, right, limit):
  (observe, keep) = states
  common_states_observed(name, text, id, retry, left, right, limit, hu, same, keep, right_valid,
    Drain.snapshot_observe(name, text, id, retry, left, limit, hu, observe))

def common_states_valid(-left: Sse.St, -right: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  same: {Drain.state_view(left) == Drain.state_view(right) : String & String & String & Maybe<&2, U32>},
  left_valid: Drain.state_valid(left, limit), right_valid: Drain.state_valid(right, limit)) ->
  common_states(left, right, limit):
  (+name, +text, +id, +retry, snapshot) = left_valid
  common_states_copies(name, text, id, retry, left, right, limit, hu, same, right_valid,
    snapshot_copy(text, name, id, retry, left, limit, snapshot))

def span_complete(+s: U32, +len: U32, +sl: MNat.le(U32.to_nat(s), U32.to_nat(len))) ->
  {Nat.add(U32.to_nat(s), U32.to_nat((len - s : U32))) == U32.to_nat(len) : Nat}:
  %Equal.sym(Nat, U32.to_nat((len - s : U32)), Nat.sub(U32.to_nat(len), U32.to_nat(s)), Lemmas.u32_sub_nat(len, s, sl)) :
    {Nat.add(U32.to_nat(s), _) == U32.to_nat(len) : Nat}
  Equal.trans(Nat, Nat.add(U32.to_nat(s), Nat.sub(U32.to_nat(len), U32.to_nat(s))),
    Nat.add(Nat.sub(U32.to_nat(len), U32.to_nat(s)), U32.to_nat(s)), U32.to_nat(len),
    MNat.add_comm(U32.to_nat(s), Nat.sub(U32.to_nat(len), U32.to_nat(s))), MNat.sub_add_cancel(U32.to_nat(len), U32.to_nat(s), sl))

def offsets_from_spans(+s: Nat, +t: Nat, +len: Nat, +other: Nat, +width: Nat, +delta: Nat,
  left: {Nat.add(s, width) == len : Nat}, right: {Nat.add(t, width) == other : Nat},
  ends: {len == Nat.add(delta, other) : Nat}) -> {s == Nat.add(delta, t) : Nat}:
  MNat.add_right_cancel(s, width, Nat.add(delta, t),
    Equal.trans(Nat, Nat.add(s, width), len, Nat.add(Nat.add(delta, t), width), left,
      Equal.trans(Nat, len, Nat.add(delta, other), Nat.add(Nat.add(delta, t), width), ends,
        Equal.trans(Nat, Nat.add(delta, other), Nat.add(delta, Nat.add(t, width)), Nat.add(Nat.add(delta, t), width),
          Equal.cong(Nat, Nat, n => Nat.add(delta, n), other, Nat.add(t, width), Equal.sym(Nat, Nat.add(t, width), other, right)),
          Equal.sym(Nat, Nat.add(Nat.add(delta, t), width), Nat.add(delta, Nat.add(t, width)), MNat.add_assoc(delta, t, width))))))

def offsets_from_widths(+s: U32, +t: U32, +len: U32, +other: U32, +delta: Nat,
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  ends: Offset.offset(delta, len, other),
  width: {U32.to_nat((len - s : U32)) == U32.to_nat((other - t : U32)) : Nat}) -> Offset.offset(delta, s, t):
  offsets_from_spans(U32.to_nat(s), U32.to_nat(t), U32.to_nat(len), U32.to_nat(other), U32.to_nat((len - s : U32)), delta,
    span_complete(s, len, sl),
    (%Equal.sym(Nat, U32.to_nat((len - s : U32)), U32.to_nat((other - t : U32)), width) :
      {Nat.add(U32.to_nat(t), _) == U32.to_nat(other) : Nat}
     span_complete(t, other, to)), ends)

def observed_widths(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  {U32.to_nat((len - s : U32)) == U32.to_nat((other - t : U32)) : Nat}:
  Equal.trans(Nat, U32.to_nat((len - s : U32)),
    String.length(Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s)),
    U32.to_nat((other - t : U32)),
    Equal.sym(Nat, String.length(Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s)),
      U32.to_nat((len - s : U32)), Reader.observed_length(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s)),
    Equal.trans(Nat,
      String.length(Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s)),
      String.length(Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)), U32.to_nat((other - t : U32)),
      Equal.cong(String, Nat, String.length,
        Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s),
        Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t), same),
      Reader.observed_length(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)))

def view_type() -> Type:
  U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>

def view_tail(view: view_type()) -> String:
  (tag, tail, cr, state, message) = view
  tail

def view_cr(view: view_type()) -> Bool:
  (tag, tail, cr, state, message) = view
  cr

def view_state(view: view_type()) -> String & String & String & Maybe<&2, U32>:
  (tag, tail, cr, state, message) = view
  state

def paired_certificate(+len: U32, +other: U32, -left: Sse.Line, -right: Sse.Line, +limit: Nat) -> Type:
  Drain.line_relation(len, other, left, right, limit) & line_reserved(len, left, limit)

def paired_certificate_finish(+len: U32, +other: U32, left: Sse.Line, -right: Sse.Line,
  +before: Nat, +limit: Nat, bound: MNat.lt(Nat.add(Nat.add(before, 1n), 3n), limit),
  certificate: Drain.line_relation(len, other, left, right, limit) &
    MNat.le(line_mass(len, left), before) & MNat.le(line_mass(other, right), before)) ->
  paired_certificate(len, other, left, right, limit):
  (relation, mass, other_mass) = certificate
  (relation, reserve_bound(line_mass(len, left), before, limit, mass, bound))

def paired_step_snapshots(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  +starts: Offset.offset(delta, s, t), +ends: Offset.offset(delta, len, other),
  reserved: line_reserved(len, Sse.LMore{Tree.reify(U32, a), s, cr, st}, limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  states: common_states(st, next, limit)) ->
  paired_certificate(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit):
  (+name, +old, +id, +retry, (+data_len, +data, +eq, data_shape, +length, data_bound, reads), right_state) = states
  +hn : MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit) = (
    %Equal.trans(Nat, state_size(st), U32.to_nat(data_len), String.length(old),
      Equal.cong(Sse.St, Nat, state_size, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq), length) :
      MNat.lt(Nat.add(Nat.add(Nat.add(_, U32.to_nat((len - s : U32))), 1n), 3n), limit)
    reserved)
  %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
    paired_certificate(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, _),
      Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit)
  paired_certificate_finish(len, other,
    Sse.line(Tree.reify(U32, a), len, s, s, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), Nat.add(String.length(old), U32.to_nat((len - s : U32))), limit, hn,
    (%Equal.sym(U32, (len - s : U32), (other - t : U32), Field.relocated_width(delta, s, t, len, other, sl, to, starts, ends)) :
      Drain.line_relation(len, other,
        Sse.line(Tree.reify(U32, a), len, s, s, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}),
        Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit) &
      MNat.le(line_mass(len, Sse.line(Tree.reify(U32, a), len, s, s, cr,
        Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry})), Nat.add(String.length(old), U32.to_nat((len - s : U32)))) &
      MNat.le(line_mass(other, Sse.line(Tree.reify(U32, b), other, t, t, cr, next)), Nat.add(String.length(old), U32.to_nat(_)))
     line_refines_budgeted(old, name, id, retry, a, b, len, other, s, t, cr,
       Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, next, delta, limit,
       hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape,
       (data_len, data, {==}, data_shape, length, data_bound, reads), right_state, same)))

def paired_observations(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, -left: Array<U32>, -right: Array<U32>,
  +len: U32, +other: U32, +s: U32, +t: U32,
  ea: {left == Tree.reify(U32, a) : Array<U32>}, eb: {right == Tree.reify(U32, b) : Array<U32>},
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(left, s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(right, t), t) : String}) ->
  {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}:
  %ea : {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(_, s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}
  %eb : {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(left, s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(_, t), t) : String}
  same

def paired_step_controls(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  +ends: Offset.offset(delta, len, other),
  reserved: line_reserved(len, Sse.LMore{Tree.reify(U32, a), s, cr, st}, limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  +same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  states: common_states(st, next, limit)) ->
  paired_certificate(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit):
  paired_step_snapshots(a, b, len, other, s, t, cr, st, next, delta, limit, hl, hr, hu, sl, to,
    offsets_from_widths(s, t, len, other, delta, sl, to, ends, observed_widths(a, b, len, other, s, t, same)), ends,
    reserved, left_shape, right_shape, same, states)

def paired_step_valid(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>,
  +s: U32, +t: U32, +cr: Bool, +next_cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  reserved: line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  relation: Drain.line_relation(len, other, Sse.LMore{a, s, cr, st}, Sse.LMore{b, t, next_cr, next}, limit)) ->
  paired_certificate(len, other, Sse.line(a, len, s, s, cr, st), Sse.line(b, other, t, t, next_cr, next), limit):
  (+views,
    ((+src, prefix, tail, +ea, left_shape, hl, lower, +sl, prefix_length, tail_length, reads, clean), left_state),
    ((+dst, other_prefix, other_tail, +eb, right_shape, hr, other_lower, +to,
      other_prefix_length, other_tail_length, other_reads, other_clean), right_state)) = relation
  %Equal.cong(view_type(), Bool, view_cr,
    Drain.line_view(len, Sse.LMore{a, s, cr, st}), Drain.line_view(other, Sse.LMore{b, t, next_cr, next}), views) :
    paired_certificate(len, other, Sse.line(a, len, s, s, cr, st), Sse.line(b, other, t, t, _, next), limit)
  %Equal.sym(Array<U32>, a, Tree.reify(U32, src), ea) :
    paired_certificate(len, other, Sse.line(_, len, s, s, cr, st), Sse.line(b, other, t, t, cr, next), limit)
  %Equal.sym(Array<U32>, b, Tree.reify(U32, dst), eb) :
    paired_certificate(len, other, Sse.line(Tree.reify(U32, src), len, s, s, cr, st), Sse.line(_, other, t, t, cr, next), limit)
  paired_step_controls(src, dst, len, other, s, t, cr, st, next, delta, limit, hl, hr, hu, sl, to, ends,
    reserved, left_shape, right_shape,
    paired_observations(src, dst, a, b, len, other, s, t, ea, eb,
      Equal.cong(view_type(), String, view_tail, Drain.line_view(len, Sse.LMore{a, s, cr, st}),
        Drain.line_view(other, Sse.LMore{b, t, next_cr, next}), views)),
    common_states_valid(st, next, limit, hu,
      Equal.cong(view_type(), String & String & String & Maybe<&2, U32>, view_state,
        Drain.line_view(len, Sse.LMore{a, s, cr, st}), Drain.line_view(other, Sse.LMore{b, t, next_cr, next}), views),
      left_state, right_state))

def view_tag(view: view_type()) -> U32:
  (tag, tail, cr, state, message) = view
  tag

def unequal_tags(+i: U32, +j: U32, different: {Nat.is_eq(U32.to_nat(i), U32.to_nat(j)) == False{} : Bool},
  same: {i == j : U32}) -> Empty:
  MNat.internal_false_ne_true(Equal.trans(Bool, False{}, Nat.is_eq(U32.to_nat(i), U32.to_nat(j)), True{},
    Equal.sym(Bool, Nat.is_eq(U32.to_nat(i), U32.to_nat(j)), False{}, different),
    (%Equal.cong(U32, Nat, U32.to_nat, i, j, same) : {Nat.is_eq(U32.to_nat(i), _) == True{} : Bool}
     MNat.is_eq_refl(U32.to_nat(i)))))

def advance_pair_goal(+fuel: Nat, +len: U32, +other: U32, -left: Sse.Line, -right: Sse.Line, +limit: Nat) -> Type:
  paired_certificate(len, other, left, right, limit) ->
    paired_certificate(len, other, Drain.advance(fuel, left, len), Drain.advance(fuel, right, other), limit)

def advance_pair_mismatch(+fuel: Nat, +len: U32, +other: U32, -left: Sse.Line, -right: Sse.Line, +limit: Nat,
  +i: U32, +j: U32,
  left_tag: {view_tag(Drain.line_view(len, left)) == i : U32},
  right_tag: {view_tag(Drain.line_view(other, right)) == j : U32},
  different: {Nat.is_eq(U32.to_nat(i), U32.to_nat(j)) == False{} : Bool},
  certificate: paired_certificate(len, other, left, right, limit)) ->
  paired_certificate(len, other, Drain.advance(fuel, left, len), Drain.advance(fuel, right, other), limit):
  ((views, left_valid, right_valid), reserved) = certificate
  Empty.absurd(paired_certificate(len, other, Drain.advance(fuel, left, len), Drain.advance(fuel, right, other), limit),
    unequal_tags(i, j, different,
      Equal.trans(U32, i, view_tag(Drain.line_view(len, left)), j,
        Equal.sym(U32, view_tag(Drain.line_view(len, left)), i, left_tag),
        Equal.trans(U32, view_tag(Drain.line_view(len, left)), view_tag(Drain.line_view(other, right)), j,
          Equal.cong(view_type(), U32, view_tag, Drain.line_view(len, left), Drain.line_view(other, right), views), right_tag))))

def advance_pair_more(+fuel: Nat, +len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>,
  +s: U32, +t: U32, +cr: Bool, +next_cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  continue: advance_pair_goal(fuel, len, other, Sse.line(a, len, s, s, cr, st), Sse.line(b, other, t, t, next_cr, next), limit),
  certificate: paired_certificate(len, other, Sse.LMore{a, s, cr, st}, Sse.LMore{b, t, next_cr, next}, limit)) ->
  paired_certificate(len, other,
    Drain.advance(fuel, Sse.line(a, len, s, s, cr, st), len),
    Drain.advance(fuel, Sse.line(b, other, t, t, next_cr, next), other), limit):
  (relation, reserved) = certificate
  continue(paired_step_valid(len, other, a, b, s, t, cr, next_cr, st, next, delta, limit, hu, ends, reserved, relation))

def advance_pair_succ(+fuel: Nat, +len: U32, +other: U32, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, len, other),
  ih: @left: Sse.Line -> @right: Sse.Line -> advance_pair_goal(fuel, len, other, left, right, limit),
  left: Sse.Line, right: Sse.Line) -> advance_pair_goal(1n+fuel, len, other, left, right, limit):
  match left right:
    case Sse.LMore{a, +s, +cr, st} Sse.LMore{b, +t, +next_cr, next}:
      certificate => advance_pair_more(fuel, len, other, a, b, s, t, cr, next_cr, st, next, delta, limit, hu, ends,
        next_certificate => ih(Sse.line(a, len, s, s, cr, st), Sse.line(b, other, t, t, next_cr, next), next_certificate),
        certificate)
    case Sse.LMore{a, s, cr, st} Sse.LWant{b, t, next_cr, next}:
      certificate => advance_pair_mismatch(1n+fuel, len, other, Sse.LMore{a, s, cr, st}, Sse.LWant{b, t, next_cr, next},
        limit, 0, 1, {==}, {==}, {==}, certificate)
    case Sse.LMore{a, s, cr, st} Sse.LGot{b, t, next_cr, next, message}:
      certificate => advance_pair_mismatch(1n+fuel, len, other, Sse.LMore{a, s, cr, st}, Sse.LGot{b, t, next_cr, next, message},
        limit, 0, 2, {==}, {==}, {==}, certificate)
    case Sse.LWant{a, s, cr, st} Sse.LMore{b, t, next_cr, next}:
      certificate => advance_pair_mismatch(1n+fuel, len, other, Sse.LWant{a, s, cr, st}, Sse.LMore{b, t, next_cr, next},
        limit, 1, 0, {==}, {==}, {==}, certificate)
    case Sse.LWant{a, s, cr, st} Sse.LWant{b, t, next_cr, next}:
      certificate => certificate
    case Sse.LWant{a, s, cr, st} Sse.LGot{b, t, next_cr, next, message}:
      certificate => advance_pair_mismatch(1n+fuel, len, other, Sse.LWant{a, s, cr, st}, Sse.LGot{b, t, next_cr, next, message},
        limit, 1, 2, {==}, {==}, {==}, certificate)
    case Sse.LGot{a, s, cr, st, message} Sse.LMore{b, t, next_cr, next}:
      certificate => advance_pair_mismatch(1n+fuel, len, other, Sse.LGot{a, s, cr, st, message}, Sse.LMore{b, t, next_cr, next},
        limit, 2, 0, {==}, {==}, {==}, certificate)
    case Sse.LGot{a, s, cr, st, message} Sse.LWant{b, t, next_cr, next}:
      certificate => advance_pair_mismatch(1n+fuel, len, other, Sse.LGot{a, s, cr, st, message}, Sse.LWant{b, t, next_cr, next},
        limit, 2, 1, {==}, {==}, {==}, certificate)
    case Sse.LGot{a, s, cr, st, message} Sse.LGot{b, t, next_cr, next, other_message}:
      certificate => certificate

def advance_pair(fuel: Nat, +len: U32, +other: U32, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, len, other)) ->
  @left: Sse.Line -> @right: Sse.Line -> advance_pair_goal(fuel, len, other, left, right, limit):
  match fuel:
    case 0n: left => right => certificate => certificate
    case 1n+ +p:
      left => right => advance_pair_succ(p, len, other, delta, limit, hu, ends,
        advance_pair(p, len, other, delta, limit, hu, ends), left, right)

def result_line(result: Sse.Reader & Sse.Next) -> Sse.Line:
  (Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, next) = result
  match next:
    case Sse.Want{}: Sse.LWant{a, pos, cr, st}
    case Sse.Got{message}: Sse.LGot{a, pos, cr, st, message}

def canonical_seen(result: Sse.Reader & Sse.Next) -> Type:
  (Sse.Reader{Bytes.Bytes{len, a}, pos, seen, cr, st}, next) = result
  match next:
    case Sse.Want{}: {seen == len : U32}
    case Sse.Got{message}: {seen == pos : U32}

def next_certificate(+len: U32, +other: U32, -left: Sse.Reader & Sse.Next, -right: Sse.Reader & Sse.Next, +limit: Nat) -> Type:
  paired_certificate(len, other, result_line(left), result_line(right), limit) &
    canonical_seen(left) & canonical_seen(right)

def advance_stopped(fuel: Nat, line: Sse.Line, +len: U32, halted: Drain.halts_within(fuel, line, len)) ->
  {is_more(Drain.advance(fuel, line, len)) == False{} : Bool}:
  match fuel:
    case 0n:
      match line:
        case Sse.LMore{a, pos, cr, st}: Empty.absurd({True{} == False{} : Bool}, halted)
        case Sse.LWant{a, pos, cr, st}: {==}
        case Sse.LGot{a, pos, cr, st, message}: {==}
    case 1n+p:
      match line:
        case Sse.LMore{a, +pos, cr, st}: advance_stopped(p, Sse.line(a, len, pos, pos, cr, st), len, halted)
        case Sse.LWant{a, pos, cr, st}: {==}
        case Sse.LGot{a, pos, cr, st, message}: {==}

def stop_certificate(+len: U32, line: Sse.Line, stopped: {is_more(line) == False{} : Bool}) ->
  {result_line(Sse.stop(line, len)) == line : Sse.Line} & canonical_seen(Sse.stop(line, len)):
  match line:
    case Sse.LMore{a, pos, cr, st}:
      Empty.absurd({result_line(Sse.stop(Sse.LMore{a, pos, cr, st}, len)) == Sse.LMore{a, pos, cr, st} : Sse.Line} &
        canonical_seen(Sse.stop(Sse.LMore{a, pos, cr, st}, len)),
        MNat.internal_false_ne_true(Equal.sym(Bool, True{}, False{}, stopped)))
    case Sse.LWant{a, pos, cr, st}: ({==}, {==})
    case Sse.LGot{a, pos, cr, st, message}: ({==}, {==})

def stopped_pair_finish(+len: U32, +other: U32, -left: Sse.Line, -right: Sse.Line, +limit: Nat,
  certificate: paired_certificate(len, other, left, right, limit),
  left_stop: {result_line(Sse.stop(left, len)) == left : Sse.Line} & canonical_seen(Sse.stop(left, len)),
  right_stop: {result_line(Sse.stop(right, other)) == right : Sse.Line} & canonical_seen(Sse.stop(right, other))) ->
  next_certificate(len, other, Sse.stop(left, len), Sse.stop(right, other), limit):
  (relation, reserved) = certificate
  (+ea, left_seen) = left_stop
  (+eb, right_seen) = right_stop
  ((Drain.line_transport(len, other, result_line(Sse.stop(left, len)), result_line(Sse.stop(right, other)),
      left, right, limit, ea, eb, relation),
    (%Equal.sym(Sse.Line, result_line(Sse.stop(left, len)), left, ea) : line_reserved(len, _, limit); reserved)),
    left_seen, right_seen)

def stopped_pair(+len: U32, +other: U32, left: Sse.Line, right: Sse.Line, +limit: Nat,
  left_stopped: {is_more(left) == False{} : Bool}, right_stopped: {is_more(right) == False{} : Bool},
  certificate: paired_certificate(len, other, left, right, limit)) ->
  next_certificate(len, other, Sse.stop(left, len), Sse.stop(right, other), limit):
  stopped_pair_finish(len, other, left, right, limit, certificate,
    stop_certificate(len, left, left_stopped), stop_certificate(other, right, right_stopped))

# Rebuild affine scanner inputs from data: https://github.com/bendlang/bend/issues/1071.
type Run is Data:
  Run{scanner: State.Scanner, name: String, data_len: U32, data: Tree.Tree<U32>, id: String, retry: Maybe<&2, U32>}

def run_length(r: Run) -> U32:
  Run{scanner, name, data_len, data, id, retry} = r
  State.scanner_length(scanner)

def run_line(r: Run) -> Sse.Line:
  Run{scanner, name, data_len, data, id, retry} = r
  State.scanner_line(scanner, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry})

def loop_pair_transport(+fuel: Nat, +len: U32, +other: U32, -left: Sse.Line, -right: Sse.Line, +limit: Nat,
  ea: {Sse.loop(fuel, left, len) == Sse.stop(Drain.advance(fuel, left, len), len) : Sse.Reader & Sse.Next},
  eb: {Sse.loop(fuel, right, other) == Sse.stop(Drain.advance(fuel, right, other), other) : Sse.Reader & Sse.Next},
  certificate: next_certificate(len, other,
    Sse.stop(Drain.advance(fuel, left, len), len), Sse.stop(Drain.advance(fuel, right, other), other), limit)) ->
  next_certificate(len, other, Sse.loop(fuel, left, len), Sse.loop(fuel, right, other), limit):
  %Equal.sym(Sse.Reader & Sse.Next, Sse.loop(fuel, left, len), Sse.stop(Drain.advance(fuel, left, len), len), ea) :
    next_certificate(len, other, _, Sse.loop(fuel, right, other), limit)
  %Equal.sym(Sse.Reader & Sse.Next, Sse.loop(fuel, right, other), Sse.stop(Drain.advance(fuel, right, other), other), eb) :
    next_certificate(len, other, Sse.stop(Drain.advance(fuel, left, len), len), _, limit)
  certificate

def loop_pair(+fuel: Nat, +left: Run, +right: Run, +delta: Nat, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, run_length(left), run_length(right)),
  left_halted: Drain.halts_within(fuel, run_line(left), run_length(left)),
  right_halted: Drain.halts_within(fuel, run_line(right), run_length(right)),
  certificate: paired_certificate(run_length(left), run_length(right), run_line(left), run_line(right), limit)) ->
  next_certificate(run_length(left), run_length(right),
    Sse.loop(fuel, run_line(left), run_length(left)), Sse.loop(fuel, run_line(right), run_length(right)), limit):
  loop_pair_transport(fuel, run_length(left), run_length(right), run_line(left), run_line(right), limit,
    Drain.loop_advance(fuel, run_line(left), run_length(left)), Drain.loop_advance(fuel, run_line(right), run_length(right)),
    stopped_pair(run_length(left), run_length(right), Drain.advance(fuel, run_line(left), run_length(left)),
      Drain.advance(fuel, run_line(right), run_length(right)), limit,
      advance_stopped(fuel, run_line(left), run_length(left), left_halted),
      advance_stopped(fuel, run_line(right), run_length(right), right_halted),
      advance_pair(fuel, run_length(left), run_length(right), delta, limit, hu, ends, run_line(left), run_line(right), certificate)))

def next_at_refines_parts(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +cr: Bool, +data_len: U32, +data: Tree.Tree<U32>, +next_len: U32, +next_data: Tree.Tree<U32>,
  +name: String, +old: String, +id: String, +retry: Maybe<&2, U32>, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  +starts: Offset.offset(delta, s, t), +ends: Offset.offset(delta, len, other),
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  length: {U32.to_nat(data_len) == String.length(old) : Nat},
  left_shapes: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)) & Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shapes: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)) & Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_states: Field.state_snapshot(name, old, id, retry, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit) &
    Field.state_snapshot(name, old, id, retry, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit),
  right_states: Field.state_snapshot(name, old, id, retry, Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry}, limit) &
    Field.state_snapshot(name, old, id, retry, Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry}, limit),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  next_certificate(len, other,
    Sse.next.at(len, s, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, (Tree.reify(U32, a), s, cr)),
    Sse.next.at(other, t, Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry}, (Tree.reify(U32, b), t, cr)), limit):
  (left_shape, left_halt_shape) = left_shapes
  (right_shape, right_halt_shape) = right_shapes
  (left_state, left_halt_state) = left_states
  (right_state, right_halt_state) = right_states
  %Field.relocated_width(delta, s, t, len, other, sl, to, starts, ends) :
    next_certificate(len, other,
      Sse.loop(Nat.add(U32.to_nat((len - s : U32)), 2n),
        Sse.line(Tree.reify(U32, a), len, s, s, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}), len),
      Sse.loop(Nat.add(U32.to_nat(_), 2n),
        Sse.line(Tree.reify(U32, b), other, t, t, cr, Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry}), other), limit)
  loop_pair(Nat.add(U32.to_nat((len - s : U32)), 2n),
    Run{State.Scanner{a, len, s, cr}, name, data_len, data, id, retry},
    Run{State.Scanner{b, other, t, cr}, name, next_len, next_data, id, retry}, delta, limit, hu, ends,
    runtime_halts(a, len, s, cr, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry},
      old, name, id, retry, limit, hl, hu, sl, hn, left_halt_shape, left_halt_state),
    (%Equal.sym(U32, (len - s : U32), (other - t : U32), Field.relocated_width(delta, s, t, len, other, sl, to, starts, ends)) :
      Drain.halts_within(Nat.add(U32.to_nat(_), 2n),
        Sse.line(Tree.reify(U32, b), other, t, t, cr, Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry}), other)
     runtime_halts(b, other, t, cr, Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry},
       old, name, id, retry, limit, hr, hu, to,
       (%Field.relocated_width(delta, s, t, len, other, sl, to, starts, ends) :
         MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat(_)), 1n), 3n), limit); hn),
       right_halt_shape, right_halt_state)),
    paired_step_snapshots(a, b, len, other, s, t, cr,
      Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry},
      Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry}, delta, limit,
      hl, hr, hu, sl, to, starts, ends,
      (%Equal.sym(Nat, U32.to_nat(data_len), String.length(old), length) :
        MNat.lt(Nat.add(Nat.add(Nat.add(_, U32.to_nat((len - s : U32))), 1n), 3n), limit); hn),
      left_shape, right_shape, same, (name, old, id, retry, left_state, right_state)))

def next_at_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +cr: Bool,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
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
  next_certificate(len, other,
    Sse.next.at(len, s, st, (Tree.reify(U32, a), s, cr)),
    Sse.next.at(other, t, next, (Tree.reify(U32, b), t, cr)), limit):
  (+data_len, +data, eq, data_shape, +length, data_bound, reads) = left_state
  (+next_len, +next_data, next_eq, next_shape, next_length, next_bound, next_reads) = right_state
  %Equal.sym(Sse.St, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq) :
    next_certificate(len, other, Sse.next.at(len, s, _, (Tree.reify(U32, a), s, cr)),
      Sse.next.at(other, t, next, (Tree.reify(U32, b), t, cr)), limit)
  %Equal.sym(Sse.St, next, Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry}, next_eq) :
    next_certificate(len, other,
      Sse.next.at(len, s, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, (Tree.reify(U32, a), s, cr)),
      Sse.next.at(other, t, _, (Tree.reify(U32, b), t, cr)), limit)
  next_at_refines_parts(a, b, len, other, s, t, cr, data_len, data, next_len, next_data, name, old, id, retry, delta, limit,
    hl, hr, hu, sl, to, starts, ends, hn, length,
    Bound.shape_copy(Local.depth(Local.words(len)), Packed.as_bits(a), left_shape),
    Bound.shape_copy(Local.depth(Local.words(other)), Packed.as_bits(b), right_shape),
    snapshot_copy(old, name, id, retry, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, limit,
      (data_len, data, {==}, data_shape, length, data_bound, reads)),
    snapshot_copy(old, name, id, retry, Sse.St{name, Bytes.Bytes{next_len, Tree.reify(U32, next_data)}, id, retry}, limit,
      (next_len, next_data, {==}, next_shape, next_length, next_bound, next_reads)), same)

def next_transport(+len: U32, +other: U32, -left: Sse.Reader & Sse.Next, -right: Sse.Reader & Sse.Next,
  -restarted_left: Sse.Reader & Sse.Next, -restarted_right: Sse.Reader & Sse.Next, +limit: Nat,
  ea: {left == restarted_left : Sse.Reader & Sse.Next}, eb: {right == restarted_right : Sse.Reader & Sse.Next},
  certificate: next_certificate(len, other, restarted_left, restarted_right, limit)) ->
  next_certificate(len, other, left, right, limit):
  %Equal.sym(Sse.Reader & Sse.Next, left, restarted_left, ea) : next_certificate(len, other, _, right, limit)
  %Equal.sym(Sse.Reader & Sse.Next, right, restarted_right, eb) : next_certificate(len, other, restarted_left, _, limit)
  certificate

def next_at_restart(+prefix: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  +cr: Bool, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  hp: MNat.le(U32.to_nat(pos), U32.to_nat(seen)), hs: MNat.le(U32.to_nat(seen), U32.to_nat(len)),
  ep: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos)) ->
  {Sse.next.at(len, seen, st, (Tree.reify(U32, src), pos, cr)) ==
    Sse.next.at(len, pos, st, (Tree.reify(U32, src), pos, cr)) : Sse.Reader & Sse.Next}:
  Equal.cong(Sse.Line, Sse.Reader & Sse.Next,
    line => Sse.loop(Nat.add(U32.to_nat((len - pos : U32)), 2n), line, len),
    Sse.line(Tree.reify(U32, src), len, pos, seen, cr, st), Sse.line(Tree.reify(U32, src), len, pos, pos, cr, st),
    Reader.line_restart(prefix, len, src, pos, seen, cr, st, limit, hl, hu, hp, hs, ep, clean))

def next_at_seen_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +left_prefix: String, +left_tail: String, +right_prefix: String, +right_tail: String,
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left_buffer: Reader.valid_buffer(left_prefix, left_tail, len, a, s, seen, limit),
  right_buffer: Reader.valid_buffer(right_prefix, right_tail, other, b, t, other_seen, limit),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  next_certificate(len, other, Sse.next.at(len, seen, st, (Tree.reify(U32, a), s, cr)),
    Sse.next.at(other, other_seen, next, (Tree.reify(U32, b), t, cr)), limit):
  (left_shape, +hl, +lower, +upper, prefix_length, tail_length, reads, clean) = left_buffer
  (right_shape, +hr, +other_lower, +other_upper, other_prefix_length, other_tail_length, other_reads, other_clean) = right_buffer
  next_transport(len, other, Sse.next.at(len, seen, st, (Tree.reify(U32, a), s, cr)),
    Sse.next.at(other, other_seen, next, (Tree.reify(U32, b), t, cr)),
    Sse.next.at(len, s, st, (Tree.reify(U32, a), s, cr)), Sse.next.at(other, t, next, (Tree.reify(U32, b), t, cr)), limit,
    next_at_restart(left_prefix, len, a, s, seen, cr, st, limit, hl, hu, lower, upper, prefix_length, clean),
    next_at_restart(right_prefix, other, b, t, other_seen, cr, next, limit, hr, hu, other_lower, other_upper, other_prefix_length, other_clean),
    next_at_refines(old, name, id, retry, a, b, len, other, s, t, cr, st, next, delta, limit, hl, hr, hu,
      MNat.le_trans(U32.to_nat(s), U32.to_nat(seen), U32.to_nat(len), lower, upper),
      MNat.le_trans(U32.to_nat(t), U32.to_nat(other_seen), U32.to_nat(other), other_lower, other_upper),
      starts, ends, hn, left_shape, right_shape, left_state, right_state, same))

def pending_next_refines_observed(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, (s + 1 : U32), t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  bounds: MNat.le(U32.to_nat(s), U32.to_nat((s + 1 : U32))) & MNat.le(U32.to_nat((s + 1 : U32)), U32.to_nat(len)),
  observation: {Packed.peek(a, s) == 10 : U32} &
    {Buffer.observed(U32.to_nat((len - (s + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, a), (s + 1 : U32)), (s + 1 : U32)) ==
      Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, False{}, next}), limit):
  (+lower, +upper) = bounds
  (lf, same) = observation
  next_transport(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, False{}, next}),
    Sse.next.at(len, (s + 1 : U32), st, (Tree.reify(U32, a), (s + 1 : U32), False{})),
    Sse.next.at(other, t, next, (Tree.reify(U32, b), t, False{})), limit,
    Drain.next_pending_restart(len, s, a, st,
      Equal.trans(Bool, U32.is_lt(s, len), Nat.is_lt(U32.to_nat(s), U32.to_nat(len)), True{}, Lemmas.u32_is_lt_nat(s, len), sl),
      lf, lower), {==},
    next_at_refines(old, name, id, retry, a, b, len, other, (s + 1 : U32), t, False{}, st, next, delta, limit,
      hl, hr, hu, upper, to, starts, ends,
      Refinement.accumulation_bound(String.length(old), U32.to_nat((len - (s + 1 : U32) : U32)),
        U32.to_nat((len - s : U32)), limit, Refinement.suffix_length_le(s, (s + 1 : U32), len, lower, upper), hn),
      left_shape, right_shape, left_state, right_state, same))

def pending_next_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, (s + 1 : U32), t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    SCon{Chr{10}, Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)} : String}) ->
  next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, False{}, next}), limit):
  pending_next_refines_observed(old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit,
    hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, left_state, right_state,
    Drain.cursor_step(s, len, limit, sl,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu),
    Drain.pending_observation(len, s, a, Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t),
      limit, sl,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu, same))
