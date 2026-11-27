import Base
import ./sse.bend as Sse
import ./LAWS.bend as Laws
import ./sse-field-proof.bend as Field
import ./sse-line-proof.bend as Line
import ./sse-reader-proof.bend as Reader
import ./sse-refinement-proof.bend as Refinement
import ./sse-scan-proof.bend as Scan
import ./sse-buffer-proof.bend as Buffer
import ./sse-offset-proof.bend as Offset
import ./sse-feed-proof.bend as Feed
import ../bytes/append-proof.bend as Packed
import ../lemmas/array.bend as Tree
import ../bits/array-proof.bend as Bound
import ../bytes/bytes.bend as Local
import ../bytes/decimal-proof.bend as Decimal
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/u32.bend as MU32

def joined(pieces: List<&2, String>) -> String:
  match pieces:
    case Nil{}:
      ""
    case Con{h, t}:
      h ++ joined(t)

law schedule_refines:
  for pieces: List<&2, String>
  for limit: Nat
  for bound: MNat.lt(Nat.add(String.length(joined(pieces)), 3n), limit)
  for ceiling: MNat.le(limit, Lemmas.pow2(32n))
  {Laws.sse(pieces) == Laws.sse([joined(pieces)]) : List<&2, String>}


def skip_pending(+len: U32, +pos: U32, +src: Tree.Tree<U32>,
  available: {U32.is_lt(pos, len) == True{} : Bool},
  lf: {Packed.peek(src, pos) == 10 : U32}) ->
  {Sse.skip(True{}, Tree.reify(U32, src), len, pos) ==
    (Tree.reify(U32, src), (pos + 1 : U32), False{}) : Array<U32> & U32 & Bool}:
  %Equal.sym(Bool, U32.is_lt(pos, len), True{}, available) :
    {Sse.skip.at(_, Tree.reify(U32, src), pos) ==
      (Tree.reify(U32, src), (pos + 1 : U32), False{}) : Array<U32> & U32 & Bool}
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), pos),
    (Tree.reify(U32, src), Packed.peek(src, pos)), Buffer.tree_peek(src, pos)) :
    {Sse.skip.byte(pos, _) ==
      (Tree.reify(U32, src), (pos + 1 : U32), False{}) : Array<U32> & U32 & Bool}
  %Equal.sym(U32, Packed.peek(src, pos), 10, lf) :
    {Sse.skip.byte(pos, (Tree.reify(U32, src), _)) ==
      (Tree.reify(U32, src), (pos + 1 : U32), False{}) : Array<U32> & U32 & Bool}
  {==}

def next_pending(+len: U32, +pos: U32, +seen: U32, +src: Tree.Tree<U32>, -st: Sse.St,
  available: {U32.is_lt(pos, len) == True{} : Bool},
  lf: {Packed.peek(src, pos) == 10 : U32}) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, True{}, st}) ==
    Sse.next.at(len, seen, st, (Tree.reify(U32, src), (pos + 1 : U32), False{})) : Sse.Reader & Sse.Next}:
  Equal.cong(Array<U32> & U32 & Bool, Sse.Reader & Sse.Next, r => Sse.next.at(len, seen, st, r),
    Sse.skip(True{}, Tree.reify(U32, src), len, pos), (Tree.reify(U32, src), (pos + 1 : U32), False{}),
    skip_pending(len, pos, src, available, lf))

def line_state(l: Sse.Line) -> Sse.St:
  match l:
    case Sse.LMore{a, pos, cr, st}:
      st
    case Sse.LWant{a, pos, cr, st}:
      st
    case Sse.LGot{a, pos, cr, st, e}:
      st

def line_field_state(+pos: U32, +cr: Bool, +a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St) ->
  {line_state(Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st)) ==
    Field.field_after(Sse.field(Tree.reify(U32, a), len, s, e, st)) : Sse.St}:
  Equal.trans(Sse.St,
    line_state(Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st)),
    Field.field_state_result(len, a, s, e, st),
    Field.field_after(Sse.field(Tree.reify(U32, a), len, s, e, st)),
    Equal.cong(Array<U32> & Sse.St, Sse.St, r => line_state(Sse.line.set(pos, cr, r)),
      Sse.field(Tree.reify(U32, a), len, s, e, st), (Tree.reify(U32, a), Field.field_state_result(len, a, s, e, st)),
      Field.field_pair(len, a, s, e, st)),
    Equal.sym(Sse.St, Field.field_after(Sse.field(Tree.reify(U32, a), len, s, e, st)), Field.field_state_result(len, a, s, e, st),
      Equal.cong(Array<U32> & Sse.St, Sse.St, Field.field_after,
        Sse.field(Tree.reify(U32, a), len, s, e, st), (Tree.reify(U32, a), Field.field_state_result(len, a, s, e, st)),
        Field.field_pair(len, a, s, e, st))))

def line_field_snapshot(+k: Field.FieldKind, +old: String, +value: String,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  snapshot: Field.set_snapshot_type(k, old, value, name, id, retry,
    Field.field_after(Sse.field(Tree.reify(U32, a), len, s, e, st)), limit)) ->
  Field.set_snapshot_type(k, old, value, name, id, retry,
    line_state(Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st)), limit):
  Field.snapshot_transport(k, old, value, name, id, retry, limit,
    line_state(Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st)),
    Field.field_after(Sse.field(Tree.reify(U32, a), len, s, e, st)),
    line_field_state(pos, cr, a, len, s, e, st), snapshot)

def line_field_refines_type(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +pos: U32, +next_pos: U32, +cr: Bool, +next_cr: Bool, -st: Sse.St, -next: Sse.St, +limit: Nat) -> Type:
  &value: String ->
    Field.set_snapshot_type(Field.field_kind(a, s, e), old, value, name, id, retry,
      line_state(Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st)), limit) &
    Field.set_snapshot_type(Field.field_kind(a, s, e), old, value, name, id, retry,
      line_state(Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, next_pos, next_cr, next)), limit)

def line_field_finish(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +pos: U32, +next_pos: U32, +cr: Bool, +next_cr: Bool, -st: Sse.St, -next: Sse.St, +limit: Nat,
  snapshot: Refinement.field_refines_type(old, name, id, retry, a, b, len, other, s, t, e, f, st, next, limit)) ->
  line_field_refines_type(old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, next_cr, st, next, limit):
  (+value, left, right) = snapshot
  (value,
    line_field_snapshot(Field.field_kind(a, s, e), old, value, name, id, retry, a, len, s, e, pos, cr, st, limit, left),
    line_field_snapshot(Field.field_kind(a, s, e), old, value, name, id, retry, b, other, t, f, next_pos, next_cr, next, limit, right))

def line_field_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +pos: U32, +next_pos: U32, +cr: Bool, +next_cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  el: MNat.le(U32.to_nat(e), U32.to_nat(len)), fo: MNat.le(U32.to_nat(f), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, e, f),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit), right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  same: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  line_field_refines_type(old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, next_cr, st, next, limit):
  line_field_finish(old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, next_cr, st, next, limit,
    Refinement.field_refines(old, name, id, retry, a, b, len, other, s, t, e, f, st, next, delta, limit,
      hl, hr, hu, se, tf, el, fo, starts, ends, hn, left_state, right_state, same))

def dispatch_emitted_type(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, -actual: Sse.St & Maybe<&1, Sse.Message>) -> Type:
  &out: Tree.Tree<U32> ->
    {actual == (Sse.St{"", Bytes.new(0), id, retry},
      Some{Sse.Message{Bool.pick(String, String.is_empty(name), "message", name),
        Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)}, id}}) : Sse.St & Maybe<&1, Sse.Message>} &
    Packed.Reads(text, out, 0)

def dispatch_emitted_finish(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, nonempty: {U32.is_zero(len) == False{} : Bool},
  snapshot: Line.trim_snapshot_type(text, len, src)) ->
  dispatch_emitted_type(text, name, id, retry, len,
    Sse.dispatch(Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry})):
  (+out, eq, reads) = snapshot
  (out,
    (%Equal.sym(Bool, U32.is_zero(len), False{}, nonempty) :
      {Sse.dispatch.of(_, name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry) ==
        (Sse.St{"", Bytes.new(0), id, retry}, Some{Sse.Message{Bool.pick(String, String.is_empty(name), "message", name),
          Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)}, id}}) : Sse.St & Maybe<&1, Sse.Message>}
     Equal.cong(Bytes.Bytes, Sse.St & Maybe<&1, Sse.Message>,
       data => (Sse.St{"", Bytes.new(0), id, retry}, Some{Sse.Message{Bool.pick(String, String.is_empty(name), "message", name), data, id}}),
       Sse.trim(Bytes.Bytes{len, Tree.reify(U32, src)}), Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)}, eq)),
    reads)

def dispatch_emitted(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, +depth: Nat, +limit: Nat,
  nonempty: {U32.is_zero(len) == False{} : Bool},
  hd: MNat.lt(depth, 32n), hl: MNat.lt(U32.to_nat((len - 1 : U32)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  hc: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)),
  length: {U32.to_nat((len - 1 : U32)) == String.length(text) : Nat},
  shape: Bound.shape(depth, Packed.as_bits(src)), reads: Packed.Reads(text, src, 0)) ->
  dispatch_emitted_type(text, name, id, retry, len,
    Sse.dispatch(Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry})):
  dispatch_emitted_finish(text, name, id, retry, len, src, nonempty,
    Line.trim_snapshot(text, len, src, depth, limit, hd, hl, hu, hc, length, shape, reads))

def line_blank_emitted_type(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +a: Tree.Tree<U32>, +pos: U32, +cr: Bool, -actual: Sse.Line) -> Type:
  &out: Tree.Tree<U32> ->
    {actual == Sse.LGot{Tree.reify(U32, a), pos, cr, Sse.St{"", Bytes.new(0), id, retry},
      Sse.Message{Bool.pick(String, String.is_empty(name), "message", name),
        Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)}, id}} : Sse.Line} &
    Packed.Reads(text, out, 0)

def line_blank_emitted(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, +a: Tree.Tree<U32>, +size: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool,
  snapshot: dispatch_emitted_type(text, name, id, retry, len,
    Sse.dispatch(Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry}))) ->
  line_blank_emitted_type(text, name, id, retry, len, a, pos, cr,
    Sse.line.body(True{}, Tree.reify(U32, a), size, s, e, pos, cr,
      Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry})):
  (+out, eq, reads) = snapshot
  (out,
    Equal.cong(Sse.St & Maybe<&1, Sse.Message>, Sse.Line, r => Sse.line.got(Tree.reify(U32, a), pos, cr, r),
      Sse.dispatch(Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry}),
      (Sse.St{"", Bytes.new(0), id, retry}, Some{Sse.Message{Bool.pick(String, String.is_empty(name), "message", name),
        Bytes.Bytes{(len - 1 : U32), Tree.reify(U32, out)}, id}}), eq),
    reads)

def restarted_tail(+len: U32, +src: Tree.Tree<U32>, +pos: U32) -> String:
  Buffer.observed(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), Bytes.peek(Tree.reify(U32, src), pos), pos)

def restarted_buffer(+len: U32, +src: Tree.Tree<U32>, +pos: U32, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hp: MNat.le(U32.to_nat(pos), U32.to_nat(len))) ->
  Reader.valid_buffer("", restarted_tail(len, src, pos), len, src, pos, pos, limit):
  (shape, hl, MNat.le_refl(U32.to_nat(pos)), hp, MNat.sub_self(U32.to_nat(pos)),
    Equal.sym(Nat, String.length(restarted_tail(len, src, pos)), U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)),
      Reader.observed_length(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), Bytes.peek(Tree.reify(U32, src), pos), pos)),
    Reader.observation_reads(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), src, pos), Unit{})

def line_field_pair(+a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool, -st: Sse.St) ->
  {Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st) ==
    Sse.LMore{Tree.reify(U32, a), pos, cr, Field.field_state_result(len, a, s, e, st)} : Sse.Line}:
  Equal.cong(Array<U32> & Sse.St, Sse.Line, r => Sse.line.set(pos, cr, r),
    Sse.field(Tree.reify(U32, a), len, s, e, st), (Tree.reify(U32, a), Field.field_state_result(len, a, s, e, st)),
    Field.field_pair(len, a, s, e, st))

def loop_want(f: Nat, -a: Array<U32>, +len: U32, +pos: U32, +cr: Bool, -st: Sse.St) ->
  {Sse.loop(f, Sse.LWant{a, pos, cr, st}, len) ==
    (Sse.Reader{Bytes.Bytes{len, a}, pos, len, cr, st}, Sse.Want{}) : Sse.Reader & Sse.Next}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      {==}

def loop_got(f: Nat, -a: Array<U32>, +len: U32, +pos: U32, +cr: Bool, -st: Sse.St, -message: Sse.Message) ->
  {Sse.loop(f, Sse.LGot{a, pos, cr, st, message}, len) ==
    (Sse.Reader{Bytes.Bytes{len, a}, pos, pos, cr, st}, Sse.Got{message}) : Sse.Reader & Sse.Next}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      {==}

def scanned_pair(+fuel: Nat, +a: Tree.Tree<U32>, +s: U32) ->
  {Sse.eol(fuel, Bytes.peek(Tree.reify(U32, a), s), s) ==
    (Tree.reify(U32, a), Refinement.eol_index(fuel, a, s)) : Array<U32> & U32}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, a), s),
    (Tree.reify(U32, a), Packed.peek(a, s)), Buffer.tree_peek(a, s)) :
    {Sse.eol(fuel, _, s) == (Tree.reify(U32, a), Buffer.index(Sse.eol(fuel, _, s))) : Array<U32> & U32}
  Buffer.eol_buffer(fuel, a, Packed.peek(a, s), s)

def line_scanned(+a: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, -st: Sse.St) ->
  {Sse.line(Tree.reify(U32, a), len, s, s, cr, st) ==
    Sse.line.end(U32.is_eq(Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), len),
      Tree.reify(U32, a), len, s, Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), cr, st) : Sse.Line}:
  %Equal.sym(U32, U32.max(s, s), s, Lemmas.u32_max_self(s)) :
    {Sse.line.eol(len, s, cr, st, Sse.eol(U32.to_nat((len - _ : U32)), Bytes.peek(Tree.reify(U32, a), _), _)) ==
      Sse.line.end(U32.is_eq(Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), len),
        Tree.reify(U32, a), len, s, Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), cr, st) : Sse.Line}
  Equal.cong(Array<U32> & U32, Sse.Line, r => Sse.line.eol(len, s, cr, st, r),
    Sse.eol(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s),
    (Tree.reify(U32, a), Refinement.eol_index(U32.to_nat((len - s : U32)), a, s)),
    scanned_pair(U32.to_nat((len - s : U32)), a, s))

def line_term_lf(+a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St,
  lf: {Packed.peek(a, e) == 10 : U32}) ->
  {Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, a), e)) ==
    Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, a), e),
    (Tree.reify(U32, a), Packed.peek(a, e)), Buffer.tree_peek(a, e)) :
    {Sse.line.term(len, s, e, st, _) ==
      Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}
  %Equal.sym(U32, Packed.peek(a, e), 10, lf) :
    {Sse.line.term(len, s, e, st, (Tree.reify(U32, a), _)) ==
      Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}
  {==}

def line_term_cr(+a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St,
  cr: {Packed.peek(a, e) == 13 : U32}) ->
  {Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, a), e)) ==
    Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, a), len, s, e, st) : Sse.Line}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, a), e),
    (Tree.reify(U32, a), Packed.peek(a, e)), Buffer.tree_peek(a, e)) :
    {Sse.line.term(len, s, e, st, _) ==
      Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, a), len, s, e, st) : Sse.Line}
  %Equal.sym(U32, Packed.peek(a, e), 13, cr) :
    {Sse.line.term(len, s, e, st, (Tree.reify(U32, a), _)) ==
      Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, a), len, s, e, st) : Sse.Line}
  {==}

def line_cr_pending(+a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St,
  end: {U32.is_lt((e + 1 : U32), len) == False{} : Bool}) ->
  {Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, a), len, s, e, st) ==
    Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), True{}, st) : Sse.Line}:
  Equal.cong(Bool, Sse.Line, more => Sse.line.cr(more, Tree.reify(U32, a), len, s, e, st),
    U32.is_lt((e + 1 : U32), len), False{}, end)

def line_cr_followed(+a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St,
  more: {U32.is_lt((e + 1 : U32), len) == True{} : Bool},
  lf: {Packed.peek(a, (e + 1 : U32)) == 10 : U32}) ->
  {Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, a), len, s, e, st) ==
    Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 2 : U32), False{}, st) : Sse.Line}:
  %Equal.sym(Bool, U32.is_lt((e + 1 : U32), len), True{}, more) :
    {Sse.line.cr(_, Tree.reify(U32, a), len, s, e, st) ==
      Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 2 : U32), False{}, st) : Sse.Line}
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, a), (e + 1 : U32)),
    (Tree.reify(U32, a), Packed.peek(a, (e + 1 : U32))), Buffer.tree_peek(a, (e + 1 : U32))) :
    {Sse.line.crlf(len, s, e, st, _) ==
      Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 2 : U32), False{}, st) : Sse.Line}
  %Equal.sym(U32, Packed.peek(a, (e + 1 : U32)), 10, lf) :
    {Sse.line.crlf(len, s, e, st, (Tree.reify(U32, a), _)) ==
      Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 2 : U32), False{}, st) : Sse.Line}
  {==}

def advance(f: Nat, l: Sse.Line, +len: U32) -> Sse.Line:
  match f:
    case 0n:
      l
    case 1n+p:
      match l:
        case Sse.LMore{a, +pos, cr, st}:
          advance(p, Sse.line(a, len, pos, pos, cr, st), len)
        case Sse.LWant{a, pos, cr, st}:
          Sse.LWant{a, pos, cr, st}
        case Sse.LGot{a, pos, cr, st, e}:
          Sse.LGot{a, pos, cr, st, e}

def loop_advance(f: Nat, l: Sse.Line, +len: U32) ->
  {Sse.loop(f, l, len) == Sse.stop(advance(f, l, len), len) : Sse.Reader & Sse.Next}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      match l:
        case Sse.LMore{a, +pos, cr, st}:
          loop_advance(p, Sse.line(a, len, pos, pos, cr, st), len)
        case Sse.LWant{a, pos, cr, st}:
          {==}
        case Sse.LGot{a, pos, cr, st, e}:
          {==}

def state_view(st: Sse.St) -> String & String & String & Maybe<&2, U32>:
  Sse.St{name, data, id, retry} = st
  (name, Bytes.to_string(data), id, retry)

def line_view_of(+tag: U32, +len: U32, a: Array<U32>, +pos: U32, cr: Bool, st: Sse.St, event: Maybe<&1, Sse.Message>) ->
  U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>:
  (tag, Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(a, pos), pos), cr, state_view(st), Line.message_text(event))

def line_view(+len: U32, l: Sse.Line) ->
  U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>:
  match l:
    case Sse.LMore{a, +pos, cr, st}:
      line_view_of(0, len, a, pos, cr, st, None{})
    case Sse.LWant{a, +pos, cr, st}:
      line_view_of(1, len, a, pos, cr, st, None{})
    case Sse.LGot{a, +pos, cr, st, event}:
      line_view_of(2, len, a, pos, cr, st, Some{event})

def buffer_valid(+len: U32, -a: Array<U32>, +pos: U32, +seen: U32, +limit: Nat) -> Type:
  &src: Tree.Tree<U32> -> &prefix: String -> &tail: String ->
    {a == Tree.reify(U32, src) : Array<U32>} &
    Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)

def state_valid(-st: Sse.St, +limit: Nat) -> Type:
  &name: String -> &text: String -> &id: String -> &retry: Maybe<&2, U32> ->
    Field.state_snapshot(name, text, id, retry, st, limit)

def message_valid(message: Sse.Message, +limit: Nat) -> Type:
  match message:
    case Sse.Message{name, data, id}:
      &text: String -> &len: U32 -> &src: Tree.Tree<U32> ->
        {data == Bytes.Bytes{len, Tree.reify(U32, src)} : Bytes.Bytes} &
        {U32.to_nat(len) == String.length(text) : Nat} &
        MNat.lt(U32.to_nat(len), limit) &
        Packed.Reads(text, src, 0)

def line_valid(+len: U32, line: Sse.Line, +limit: Nat) -> Type:
  match line:
    case Sse.LMore{a, pos, cr, st}:
      buffer_valid(len, a, pos, pos, limit) & state_valid(st, limit)
    case Sse.LWant{a, pos, cr, st}:
      buffer_valid(len, a, pos, len, limit) & state_valid(st, limit)
    case Sse.LGot{a, pos, cr, st, event}:
      buffer_valid(len, a, pos, pos, limit) & state_valid(st, limit) & message_valid(event, limit)

def line_relation(+len: U32, +other: U32, -left: Sse.Line, -right: Sse.Line, +limit: Nat) -> Type:
  {line_view(len, left) == line_view(other, right) :
    U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>} &
    line_valid(len, left, limit) & line_valid(other, right, limit)

def line_valid_transport(+len: U32, -left: Sse.Line, -right: Sse.Line, +limit: Nat,
  eq: {left == right : Sse.Line}, valid: line_valid(len, right, limit)) ->
  line_valid(len, left, limit):
  %Equal.sym(Sse.Line, left, right, eq) : line_valid(len, _, limit)
  valid

def line_transport(+len: U32, +other: U32, -left: Sse.Line, -right: Sse.Line,
  -a: Sse.Line, -b: Sse.Line, +limit: Nat,
  +ea: {left == a : Sse.Line}, +eb: {right == b : Sse.Line},
  cert: line_relation(len, other, a, b, limit)) ->
  line_relation(len, other, left, right, limit):
  (views, left_valid, right_valid) = cert
  -V = U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>
  (Equal.trans(V, line_view(len, left), line_view(len, a), line_view(other, right),
    Equal.cong(Sse.Line, V, x => line_view(len, x), left, a, ea),
    Equal.trans(V, line_view(len, a), line_view(other, b), line_view(other, right), views,
      Equal.sym(V, line_view(other, right), line_view(other, b),
        Equal.cong(Sse.Line, V, x => line_view(other, x), right, b, eb)))),
    line_valid_transport(len, left, a, limit, ea, left_valid),
    line_valid_transport(other, right, b, limit, eb, right_valid))

law line_end_refines:
  for old: String
  for name: String
  for id: String
  for retry: Maybe<&2, U32>
  for a: Tree.Tree<U32>
  for b: Tree.Tree<U32>
  for len: U32
  for other: U32
  for s: U32
  for t: U32
  for cr: Bool
  for -st: Sse.St
  for -next: Sse.St
  for delta: Nat
  for limit: Nat
  for hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit)
  for hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit)
  for hu: MNat.le(limit, Lemmas.pow2(32n))
  for sl: MNat.le(U32.to_nat(s), U32.to_nat(len))
  for to: MNat.le(U32.to_nat(t), U32.to_nat(other))
  for starts: Offset.offset(delta, s, t)
  for ends: Offset.offset(delta, len, other)
  for hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit)
  for shape_left: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a))
  for shape_right: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b))
  for left_state: Field.state_snapshot(name, old, id, retry, st, limit)
  for right_state: Field.state_snapshot(name, old, id, retry, next, limit)
  for same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}
  line_relation(len, other,
    Sse.line.end(U32.is_eq(Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), len),
      Tree.reify(U32, a), len, s, Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), cr, st),
    Sse.line.end(U32.is_eq(Refinement.eol_index(U32.to_nat((other - t : U32)), b, t), other),
      Tree.reify(U32, b), other, t, Refinement.eol_index(U32.to_nat((other - t : U32)), b, t), cr, next), limit)

law line_refines:
  for old: String
  for name: String
  for id: String
  for retry: Maybe<&2, U32>
  for +a: Tree.Tree<U32>
  for +b: Tree.Tree<U32>
  for +len: U32
  for +other: U32
  for +s: U32
  for +t: U32
  for +cr: Bool
  for -st: Sse.St
  for -next: Sse.St
  for delta: Nat
  for +limit: Nat
  for hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit)
  for hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit)
  for hu: MNat.le(limit, Lemmas.pow2(32n))
  for sl: MNat.le(U32.to_nat(s), U32.to_nat(len))
  for to: MNat.le(U32.to_nat(t), U32.to_nat(other))
  for starts: Offset.offset(delta, s, t)
  for ends: Offset.offset(delta, len, other)
  for hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit)
  for shape_left: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a))
  for shape_right: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b))
  for left_state: Field.state_snapshot(name, old, id, retry, st, limit)
  for right_state: Field.state_snapshot(name, old, id, retry, next, limit)
  for same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}
  line_relation(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit)

def line_refines_lift(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +e: U32, +f: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +limit: Nat,
  ea: {Sse.line(Tree.reify(U32, a), len, s, s, cr, st) ==
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, a), len, s, e, cr, st) : Sse.Line},
  eb: {Sse.line(Tree.reify(U32, b), other, t, t, cr, next) ==
    Sse.line.end(U32.is_eq(f, other), Tree.reify(U32, b), other, t, f, cr, next) : Sse.Line},
  cert: line_relation(len, other,
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, a), len, s, e, cr, st),
    Sse.line.end(U32.is_eq(f, other), Tree.reify(U32, b), other, t, f, cr, next), limit)) ->
  line_relation(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit):
  line_transport(len, other,
    Sse.line(Tree.reify(U32, a), len, s, s, cr, st), Sse.line(Tree.reify(U32, b), other, t, t, cr, next),
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, a), len, s, e, cr, st),
    Sse.line.end(U32.is_eq(f, other), Tree.reify(U32, b), other, t, f, cr, next), limit, ea, eb, cert)


def skip_non_lf(+len: U32, +pos: U32, +src: Tree.Tree<U32>,
  available: {U32.is_lt(pos, len) == True{} : Bool},
  not_lf: {U32.is_eq(Packed.peek(src, pos), 10) == False{} : Bool}) ->
  {Sse.skip(True{}, Tree.reify(U32, src), len, pos) ==
    (Tree.reify(U32, src), pos, False{}) : Array<U32> & U32 & Bool}:
  %Equal.sym(Bool, U32.is_lt(pos, len), True{}, available) :
    {Sse.skip.at(_, Tree.reify(U32, src), pos) ==
      (Tree.reify(U32, src), pos, False{}) : Array<U32> & U32 & Bool}
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), pos),
    (Tree.reify(U32, src), Packed.peek(src, pos)), Buffer.tree_peek(src, pos)) :
    {Sse.skip.byte(pos, _) ==
      (Tree.reify(U32, src), pos, False{}) : Array<U32> & U32 & Bool}
  %Equal.sym(Bool, U32.is_eq(Packed.peek(src, pos), 10), False{}, not_lf) :
    {(Tree.reify(U32, src), Bool.pick(U32, _, (pos + 1 : U32), pos), False{}) ==
      (Tree.reify(U32, src), pos, False{}) : Array<U32> & U32 & Bool}
  {==}

def line_cr_non_lf(+a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St,
  more: {U32.is_lt((e + 1 : U32), len) == True{} : Bool},
  not_lf: {U32.is_eq(Packed.peek(a, (e + 1 : U32)), 10) == False{} : Bool}) ->
  {Sse.line.cr(U32.is_lt((e + 1 : U32), len), Tree.reify(U32, a), len, s, e, st) ==
    Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}:
  %Equal.sym(Bool, U32.is_lt((e + 1 : U32), len), True{}, more) :
    {Sse.line.cr(_, Tree.reify(U32, a), len, s, e, st) ==
      Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, a), (e + 1 : U32)),
    (Tree.reify(U32, a), Packed.peek(a, (e + 1 : U32))), Buffer.tree_peek(a, (e + 1 : U32))) :
    {Sse.line.crlf(len, s, e, st, _) ==
      Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}
  %Equal.sym(Bool, U32.is_eq(Packed.peek(a, (e + 1 : U32)), 10), False{}, not_lf) :
    {Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e,
      Bool.pick(U32, _, (e + 2 : U32), (e + 1 : U32)), False{}, st) ==
      Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}
  {==}

def scan_not_short(+p: Nat, +i: U32,
  eq: {U32.to_nat(i) == Nat.add(1n+p, U32.to_nat(i)) : Nat}) -> Empty:
  MNat.lt_irrefl(U32.to_nat(i))(
    %Equal.sym(Nat, U32.to_nat(i), Nat.add(1n+p, U32.to_nat(i)), eq) :
      MNat.lt(U32.to_nat(i), _)
    MNat.lt_succ_of_le(U32.to_nat(i), Nat.add(p, U32.to_nat(i)), MNat.le_add_left(U32.to_nat(i), p)))

def scan_total_step(+p: Nat, +i: U32, +limit: Nat,
  hn: MNat.lt(Nat.add(1n+p, U32.to_nat(i)), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {Nat.add(1n+p, U32.to_nat(i)) == Nat.add(p, U32.to_nat((i + 1 : U32))) : Nat}:
  Equal.trans(Nat, Nat.add(1n+p, U32.to_nat(i)), Nat.add(p, 1n+U32.to_nat(i)), Nat.add(p, U32.to_nat((i + 1 : U32))),
    Equal.sym(Nat, Nat.add(p, 1n+U32.to_nat(i)), 1n+Nat.add(p, U32.to_nat(i)), MNat.add_succ(p, U32.to_nat(i))),
    Equal.cong(Nat, Nat, x => Nat.add(p, x), 1n+U32.to_nat(i), U32.to_nat((i + 1 : U32)),
      Equal.sym(Nat, U32.to_nat((i + 1 : U32)), 1n+U32.to_nat(i),
        Packed.add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), Offset.increment_bound(p, i, limit, hn), hu)))))

def eol_exhausted(f: Nat, r: Array<U32> & U32, +i: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(f, U32.to_nat(i)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {U32.to_nat(Buffer.index(Sse.eol(f, r, i))) == Nat.add(f, U32.to_nat(i)) : Nat} ->
  Scan.clean_prefix(f, r, i):
  match f:
    case 0n:
      eq => Unit{}
    case 1n+ +p:
      (a, +c) = r
      Scan.eol_elim(x =>
        {U32.to_nat(Buffer.index(x)) == Nat.add(1n+p, U32.to_nat(i)) : Nat} ->
          Scan.clean_prefix(1n+p, (a, c), i), p, a, c, i,
        lf => eq => Empty.absurd(Scan.clean_prefix(1n+p, (a, c), i), scan_not_short(p, i, eq)),
        cr => eq => Empty.absurd(Scan.clean_prefix(1n+p, (a, c), i), scan_not_short(p, i, eq)),
        good => eq => (good,
          eol_exhausted(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), limit, Offset.tail_bound(p, i, limit, hu, hn), hu)(
            Equal.trans(Nat,
              U32.to_nat(Buffer.index(Sse.eol(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)))),
              Nat.add(1n+p, U32.to_nat(i)), Nat.add(p, U32.to_nat((i + 1 : U32))), eq,
              scan_total_step(p, i, limit, hn, hu)))))

def line_exhausted_clean(+src: Tree.Tree<U32>, +s: U32, +len: U32, +limit: Nat,
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  exhausted: {Refinement.eol_index(U32.to_nat((len - s : U32)), src, s) == len : U32}) ->
  Scan.clean_prefix(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s):
  eol_exhausted(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s, limit,
    Refinement.endpoint_bound(U32.to_nat((len - s : U32)), s, len, len, limit,
      Field.span_end(s, len, sl), MNat.le_refl(U32.to_nat(len)), hl), hu)(
    Equal.trans(Nat,
      U32.to_nat(Refinement.eol_index(U32.to_nat((len - s : U32)), src, s)), U32.to_nat(len),
      Nat.add(U32.to_nat((len - s : U32)), U32.to_nat(s)),
      Equal.cong(U32, Nat, U32.to_nat, Refinement.eol_index(U32.to_nat((len - s : U32)), src, s), len, exhausted),
      Equal.sym(Nat, Nat.add(U32.to_nat((len - s : U32)), U32.to_nat(s)), U32.to_nat(len), Field.span_end(s, len, sl))))

def min_right(+a: U32, +b: U32, h: {U32.is_le(b, a) == True{} : Bool}) ->
  {U32.min(a, b) == b : U32}:
  Lemmas.u32_to_nat_inj(U32.min(a, b), b,
    Equal.trans(Nat, U32.to_nat(U32.min(a, b)), Nat.min(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(b),
      MU32.u32_min_to_nat(a, b),
      MNat.min_eq_right(U32.to_nat(a), U32.to_nat(b),
        Equal.trans(Bool, Nat.is_le(U32.to_nat(b), U32.to_nat(a)), U32.is_le(b, a), True{},
          Equal.sym(Bool, U32.is_le(b, a), Nat.is_le(U32.to_nat(b), U32.to_nat(a)), Lemmas.u32_is_le_nat(b, a)), h))))

def input_width_selected(zero: Bool, +len: U32, +pos: U32, hp: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  choice: {U32.is_zero(pos) == zero : Bool}) ->
  {Feed.input_length(zero, len, pos) == (len - pos : U32) : U32}:
  match zero:
    case True{}:
      %Equal.sym(U32, pos, 0, Packed.u32_eq_true(pos, 0, choice)) : {len == (len - _ : U32) : U32}
      Lemmas.u32_to_nat_inj(len, (len - 0 : U32),
        Equal.sym(Nat, U32.to_nat((len - 0 : U32)), U32.to_nat(len),
          Equal.trans(Nat, U32.to_nat((len - 0 : U32)), Nat.sub(U32.to_nat(len), 0n), U32.to_nat(len),
            Lemmas.u32_sub_nat(len, 0, MNat.zero_le(U32.to_nat(len))), MNat.sub_zero(U32.to_nat(len)))))
    case False{}:
      %Equal.sym(U32, U32.min(pos, len), pos, Reader.min_left(pos, len, hp)) :
        {U32.min(4294967295, (len - _ : U32)) == (len - pos : U32) : U32}
      min_right(4294967295, (len - pos : U32), Decimal.u32_le_max((len - pos : U32)))

def input_width(+len: U32, +pos: U32, hp: MNat.le(U32.to_nat(pos), U32.to_nat(len))) ->
  {Feed.input_length(U32.is_zero(pos), len, pos) == (len - pos : U32) : U32}:
  input_width_selected(U32.is_zero(pos), len, pos, hp, {==})

def want_buffer(+len: U32, +src: Tree.Tree<U32>, +pos: U32, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hp: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  exhausted: {Refinement.eol_index(U32.to_nat((len - pos : U32)), src, pos) == len : U32}) ->
  Reader.valid_buffer(Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos),
    "", len, src, pos, len, limit):
  +text = Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos)
  +length = Reader.observed_length(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos)
  (shape, hl, hp, MNat.le_refl(U32.to_nat(len)),
    Equal.trans(Nat, Nat.sub(U32.to_nat(len), U32.to_nat(pos)), U32.to_nat((len - pos : U32)), String.length(text),
      Equal.sym(Nat, U32.to_nat((len - pos : U32)), Nat.sub(U32.to_nat(len), U32.to_nat(pos)), Lemmas.u32_sub_nat(len, pos, hp)),
      Equal.sym(Nat, String.length(text), U32.to_nat((len - pos : U32)), length)),
    Equal.trans(Nat, U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat((len - pos : U32)), String.length(text ++ ""),
      Equal.cong(U32, Nat, U32.to_nat, Feed.input_length(U32.is_zero(pos), len, pos), (len - pos : U32), input_width(len, pos, hp)),
      Equal.trans(Nat, U32.to_nat((len - pos : U32)), String.length(text), String.length(text ++ ""),
        Equal.sym(Nat, String.length(text), U32.to_nat((len - pos : U32)), length),
        Equal.cong(String, Nat, String.length, text, text ++ "", Equal.sym(String, text ++ "", text, Packed.append_nil(text))))),
    (%Equal.sym(String, text ++ "", text, Packed.append_nil(text)) : Packed.Reads(_, src, pos)
     Reader.observation_reads(U32.to_nat((len - pos : U32)), src, pos)),
    (%Equal.sym(Nat, String.length(text), U32.to_nat((len - pos : U32)), length) :
      Scan.clean_prefix(_, Bytes.peek(Tree.reify(U32, src), pos), pos)
     line_exhausted_clean(src, pos, len, limit, hp,
       MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu, exhausted)))


def line_scanned_at(+a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +cr: Bool, -st: Sse.St,
  scanned: {Refinement.eol_index(U32.to_nat((len - s : U32)), a, s) == e : U32}) ->
  {Sse.line(Tree.reify(U32, a), len, s, s, cr, st) ==
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, a), len, s, e, cr, st) : Sse.Line}:
  Equal.trans(Sse.Line, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line.end(U32.is_eq(Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), len),
      Tree.reify(U32, a), len, s, Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), cr, st),
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, a), len, s, e, cr, st),
    line_scanned(a, len, s, cr, st),
    Equal.cong(U32, Sse.Line, k => Sse.line.end(U32.is_eq(k, len), Tree.reify(U32, a), len, s, k, cr, st),
      Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), e, scanned))


def dispatch_empty(+name: String, +id: String, +retry: Maybe<&2, U32>, +src: Tree.Tree<U32>) ->
  {Sse.dispatch(Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}) ==
    (Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}, None{}) : Sse.St & Maybe<&1, Sse.Message>}:
  {==}

def line_blank_empty(+name: String, +id: String, +retry: Maybe<&2, U32>, +src: Tree.Tree<U32>,
  +a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool) ->
  {Sse.line.body(True{}, Tree.reify(U32, a), len, s, e, pos, cr,
    Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}) ==
    Sse.LMore{Tree.reify(U32, a), pos, cr, Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}} : Sse.Line}:
  Equal.cong(Sse.St & Maybe<&1, Sse.Message>, Sse.Line, r => Sse.line.got(Tree.reify(U32, a), pos, cr, r),
    Sse.dispatch(Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}),
    (Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}, None{}), dispatch_empty(name, id, retry, src))

def copy_reads_step(+c: U32, +text: String, +src: Tree.Tree<U32>, +i: U32,
  +head: {Packed.peek(src, i) == c : U32},
  tails: Packed.Reads(text, src, (i + 1 : U32)) & Packed.Reads(text, src, (i + 1 : U32))) ->
  Packed.Reads(SCon{Chr{c}, text}, src, i) & Packed.Reads(SCon{Chr{c}, text}, src, i):
  (left, right) = tails
  ((head, left), (head, right))

def copy_reads(+text: String, +src: Tree.Tree<U32>, +i: U32, reads: Packed.Reads(text, src, i)) ->
  Packed.Reads(text, src, i) & Packed.Reads(text, src, i):
  match text:
    case SNil{}:
      (Unit{}, Unit{})
    case SCon{Chr{+c}, +tail}:
      (head, rest) = reads
      copy_reads_step(c, tail, src, i, head, copy_reads(tail, src, (i + 1 : U32), rest))

def state_packed_view(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +src: Tree.Tree<U32>, +limit: Nat,
  +length: {U32.to_nat(len) == String.length(text) : Nat},
  bound: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  reads: Packed.Reads(text, src, 0)) ->
  {state_view(Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry}) ==
    (name, text, id, retry) : String & String & String & Maybe<&2, U32>}:
  Equal.cong(String, String & String & String & Maybe<&2, U32>, value => (name, value, id, retry),
    Bytes.to_string(Bytes.Bytes{len, Tree.reify(U32, src)}), text,
    Field.packed_string(text, len, src, limit, length, hu,
      (%Equal.sym(Nat, String.length(text), U32.to_nat(len), Equal.sym(Nat, U32.to_nat(len), String.length(text), length)) :
        MNat.lt(Nat.add(_, 0n), limit)
       %Equal.sym(Nat, Nat.add(U32.to_nat(len), 0n), U32.to_nat(len), MNat.add_zero(U32.to_nat(len))) : MNat.lt(_, limit)
       MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), bound)),
      reads))

def snapshot_observe_reads(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  -st: Sse.St, +len: U32, +src: Tree.Tree<U32>, +limit: Nat,
  +eq: {st == Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry} : Sse.St},
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  +length: {U32.to_nat(len) == String.length(text) : Nat},
  +bound: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  reads: Packed.Reads(text, src, 0) & Packed.Reads(text, src, 0)) ->
  {state_view(st) == (name, text, id, retry) : String & String & String & Maybe<&2, U32>} &
    state_valid(st, limit):
  (left, right) = reads
  (Equal.trans(String & String & String & Maybe<&2, U32>, state_view(st),
    state_view(Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry}), (name, text, id, retry),
    Equal.cong(Sse.St, String & String & String & Maybe<&2, U32>, state_view,
      st, Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry}, eq),
    state_packed_view(name, text, id, retry, len, src, limit, length, bound, hu, left)),
    (name, text, id, retry, len, src, eq, shape, length, bound, right))

def snapshot_observe(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), snapshot: Field.state_snapshot(name, text, id, retry, st, limit)) ->
  {state_view(st) == (name, text, id, retry) : String & String & String & Maybe<&2, U32>} &
    state_valid(st, limit):
  (+len, +src, eq, shape, length, bound, reads) = snapshot
  snapshot_observe_reads(name, text, id, retry, st, len, src, limit, eq, shape, length, bound, hu, copy_reads(text, src, 0, reads))

def want_view(+len: U32, +src: Tree.Tree<U32>, +pos: U32, +cr: Bool, -st: Sse.St,
  +name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  eq: {state_view(st) == (name, text, id, retry) : String & String & String & Maybe<&2, U32>}) ->
  {line_view(len, Sse.LWant{Tree.reify(U32, src), pos, cr, st}) ==
    (1, Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos),
      cr, (name, text, id, retry), None{}) :
    U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>}:
  Equal.cong(String & String & String & Maybe<&2, U32>,
    U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>,
    view => (1, Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos), cr, view, None{}),
    state_view(st), (name, text, id, retry), eq)

def want_relation_parts(+len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32,
  +cr: Bool, -st: Sse.St, -next: Sse.St, +name: String, +text: String, +id: String, +retry: Maybe<&2, U32>, +limit: Nat,
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left_buffer: Reader.valid_buffer(Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s), "", len, a, s, len, limit),
  right_buffer: Reader.valid_buffer(Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t), "", other, b, t, other, limit),
  left_state: {state_view(st) == (name, text, id, retry) : String & String & String & Maybe<&2, U32>} & state_valid(st, limit),
  right_state: {state_view(next) == (name, text, id, retry) : String & String & String & Maybe<&2, U32>} & state_valid(next, limit)) ->
  line_relation(len, other, Sse.LWant{Tree.reify(U32, a), s, cr, st}, Sse.LWant{Tree.reify(U32, b), t, cr, next}, limit):
  (left_eq, left_valid) = left_state
  (right_eq, right_valid) = right_state
  -V = U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>
  -left_view = line_view(len, Sse.LWant{Tree.reify(U32, a), s, cr, st})
  -right_view = line_view(other, Sse.LWant{Tree.reify(U32, b), t, cr, next})
  +unread_left = Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s)
  +unread_right = Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)
  (Equal.trans(V, left_view, (1, unread_left, cr, (name, text, id, retry), None{}), right_view,
    want_view(len, a, s, cr, st, name, text, id, retry, left_eq),
    Equal.trans(V, (1, unread_left, cr, (name, text, id, retry), None{}), (1, unread_right, cr, (name, text, id, retry), None{}), right_view,
      Equal.cong(String, V, unread => (1, unread, cr, (name, text, id, retry), None{}), unread_left, unread_right, same),
      Equal.sym(V, right_view, (1, unread_right, cr, (name, text, id, retry), None{}),
        want_view(other, b, t, cr, next, name, text, id, retry, right_eq)))),
    ((a, unread_left, "", {==}, left_buffer), left_valid),
    ((b, unread_right, "", {==}, right_buffer), right_valid))

def line_want_refines(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32,
  +cr: Bool, -st: Sse.St, -next: Sse.St, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  exhausted_left: {Refinement.eol_index(U32.to_nat((len - s : U32)), a, s) == len : U32},
  exhausted_right: {Refinement.eol_index(U32.to_nat((other - t : U32)), b, t) == other : U32},
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left_state: Field.state_snapshot(name, text, id, retry, st, limit),
  right_state: Field.state_snapshot(name, text, id, retry, next, limit)) ->
  line_relation(len, other, Sse.LWant{Tree.reify(U32, a), s, cr, st}, Sse.LWant{Tree.reify(U32, b), t, cr, next}, limit):
  want_relation_parts(len, other, a, b, s, t, cr, st, next, name, text, id, retry, limit, same,
    want_buffer(len, a, s, limit, left_shape, hl, sl, hu, exhausted_left),
    want_buffer(other, b, t, limit, right_shape, hr, to, hu, exhausted_right),
    snapshot_observe(name, text, id, retry, st, limit, hu, left_state),
    snapshot_observe(name, text, id, retry, next, limit, hu, right_state))

def offset_exhausted(+delta: Nat, +e: U32, +f: U32, +len: U32, +other: U32,
  scanned: Offset.offset(delta, e, f), ends: Offset.offset(delta, len, other),
  exhausted: {e == len : U32}) -> {f == other : U32}:
  Lemmas.u32_to_nat_inj(f, other,
    MNat.add_left_cancel(delta, U32.to_nat(f), U32.to_nat(other),
      Equal.trans(Nat, Nat.add(delta, U32.to_nat(f)), U32.to_nat(e), Nat.add(delta, U32.to_nat(other)),
        Equal.sym(Nat, U32.to_nat(e), Nat.add(delta, U32.to_nat(f)), scanned),
        Equal.trans(Nat, U32.to_nat(e), U32.to_nat(len), Nat.add(delta, U32.to_nat(other)),
          Equal.cong(U32, Nat, U32.to_nat, e, len, exhausted), ends))))

def endpoint_is_eq(+e: U32, +len: U32, eq: {e == len : U32}) ->
  {U32.is_eq(e, len) == True{} : Bool}:
  %Equal.sym(U32, e, len, eq) : {U32.is_eq(_, len) == True{} : Bool}
  Equal.trans(Bool, U32.is_eq(len, len), Nat.is_eq(U32.to_nat(len), U32.to_nat(len)), True{},
    Lemmas.u32_is_eq_nat(len, len), MNat.is_eq_refl(U32.to_nat(len)))

def line_end_want_at(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32,
  +e: U32, +f: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  left_scan: {Refinement.eol_index(U32.to_nat((len - s : U32)), a, s) == e : U32},
  right_scan: {Refinement.eol_index(U32.to_nat((other - t : U32)), b, t) == f : U32},
  +left_end: {e == len : U32}, +right_end: {f == other : U32},
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left_state: Field.state_snapshot(name, text, id, retry, st, limit),
  right_state: Field.state_snapshot(name, text, id, retry, next, limit)) ->
  line_relation(len, other,
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, a), len, s, e, cr, st),
    Sse.line.end(U32.is_eq(f, other), Tree.reify(U32, b), other, t, f, cr, next), limit):
  %Equal.sym(Bool, U32.is_eq(e, len), True{}, endpoint_is_eq(e, len, left_end)) :
    line_relation(len, other, Sse.line.end(_, Tree.reify(U32, a), len, s, e, cr, st),
      Sse.line.end(U32.is_eq(f, other), Tree.reify(U32, b), other, t, f, cr, next), limit)
  %Equal.sym(Bool, U32.is_eq(f, other), True{}, endpoint_is_eq(f, other, right_end)) :
    line_relation(len, other, Sse.LWant{Tree.reify(U32, a), s, cr, st},
      Sse.line.end(_, Tree.reify(U32, b), other, t, f, cr, next), limit)
  line_want_refines(name, text, id, retry, len, other, a, b, s, t, cr, st, next, limit,
    left_shape, right_shape, hl, hr, hu, sl, to,
    Equal.trans(U32, Refinement.eol_index(U32.to_nat((len - s : U32)), a, s), e, len, left_scan, left_end),
    Equal.trans(U32, Refinement.eol_index(U32.to_nat((other - t : U32)), b, t), f, other, right_scan, right_end),
    same, left_state, right_state)

def scanned_exhausted(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32,
  +len: U32, +other: U32, +delta: Nat, +limit: Nat,
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  hl: MNat.lt(U32.to_nat(len), limit), hr: MNat.lt(U32.to_nat(other), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  starts: Offset.offset(delta, s, t), +ends: Offset.offset(delta, len, other),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  exhausted: {Refinement.eol_index(U32.to_nat((len - s : U32)), a, s) == len : U32}) ->
  {Refinement.eol_index(U32.to_nat((other - t : U32)), b, t) == other : U32}:
  offset_exhausted(delta, Refinement.eol_index(U32.to_nat((len - s : U32)), a, s),
    Refinement.eol_index(U32.to_nat((other - t : U32)), b, t), len, other,
    Refinement.eol_relocated(a, b, s, t, len, other, delta, limit, sl, to, hl, hr, hu, starts, ends, same),
    ends, exhausted)

def line_end_want(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +cr: Bool, -st: Sse.St,
  exhausted: {e == len : U32}) ->
  {Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st) ==
    Sse.LWant{Tree.reify(U32, src), s, cr, st} : Sse.Line}:
  Equal.cong(Bool, Sse.Line, want => Sse.line.end(want, Tree.reify(U32, src), len, s, e, cr, st),
    U32.is_eq(e, len), True{}, endpoint_is_eq(e, len, exhausted))

def line_want_scanned(+src: Tree.Tree<U32>, +len: U32, +s: U32, +cr: Bool, -st: Sse.St,
  exhausted: {Refinement.eol_index(U32.to_nat((len - s : U32)), src, s) == len : U32}) ->
  {Sse.line(Tree.reify(U32, src), len, s, s, cr, st) == Sse.LWant{Tree.reify(U32, src), s, cr, st} : Sse.Line}:
  Equal.trans(Sse.Line, Sse.line(Tree.reify(U32, src), len, s, s, cr, st),
    Sse.line.end(U32.is_eq(len, len), Tree.reify(U32, src), len, s, len, cr, st),
    Sse.LWant{Tree.reify(U32, src), s, cr, st},
    line_scanned_at(src, len, s, len, cr, st, exhausted),
    line_end_want(src, len, s, len, cr, st, {==}))

def line_exhausted_refines(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32,
  +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  +exhausted: {Refinement.eol_index(U32.to_nat((len - s : U32)), a, s) == len : U32},
  +same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left_state: Field.state_snapshot(name, text, id, retry, st, limit),
  right_state: Field.state_snapshot(name, text, id, retry, next, limit)) ->
  line_relation(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit):
  +right_end = scanned_exhausted(a, b, s, t, len, other, delta, limit, sl, to,
    MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl),
    MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr),
    hu, starts, ends, same, exhausted)
  line_transport(len, other,
    Sse.line(Tree.reify(U32, a), len, s, s, cr, st), Sse.line(Tree.reify(U32, b), other, t, t, cr, next),
    Sse.LWant{Tree.reify(U32, a), s, cr, st}, Sse.LWant{Tree.reify(U32, b), t, cr, next}, limit,
    line_want_scanned(a, len, s, cr, st, exhausted), line_want_scanned(b, other, t, cr, next, right_end),
    line_want_refines(name, text, id, retry, len, other, a, b, s, t, cr, st, next, limit,
      left_shape, right_shape, hl, hr, hu, sl, to, exhausted, right_end, same, left_state, right_state))


def next_pending_consumed(+len: U32, +pos: U32, +seen: U32, +src: Tree.Tree<U32>, -st: Sse.St,
  available: {U32.is_lt(pos, len) == True{} : Bool},
  lf: {Packed.peek(src, pos) == 10 : U32}) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, (pos + 1 : U32), seen, False{}, st}) : Sse.Reader & Sse.Next}:
  next_pending(len, pos, seen, src, st, available, lf)

def next_pending_non_lf(+len: U32, +pos: U32, +seen: U32, +src: Tree.Tree<U32>, -st: Sse.St,
  available: {U32.is_lt(pos, len) == True{} : Bool},
  not_lf: {U32.is_eq(Packed.peek(src, pos), 10) == False{} : Bool}) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, False{}, st}) : Sse.Reader & Sse.Next}:
  Equal.cong(Array<U32> & U32 & Bool, Sse.Reader & Sse.Next, r => Sse.next.at(len, seen, st, r),
    Sse.skip(True{}, Tree.reify(U32, src), len, pos), (Tree.reify(U32, src), pos, False{}),
    skip_non_lf(len, pos, src, available, not_lf))

def set_snapshot_observe(k: Field.FieldKind, +old: String, +value: String, +name: String, +id: String,
  +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  snapshot: Field.set_snapshot_type(k, old, value, name, id, retry, st, limit)) ->
  {state_view(st) == Field.text_set(k, value, old, name, id, retry) : String & String & String & Maybe<&2, U32>} &
    state_valid(st, limit):
  match k:
    case Field.KData{}:
      snapshot_observe(name, (old ++ value) ++ "\n", id, retry, st, limit, hu, snapshot)
    case Field.KEvent{}:
      snapshot_observe(value, old, id, retry, st, limit, hu, snapshot)
    case Field.KId{}:
      snapshot_observe(name, old, Bool.pick(String, Sse.has_nul(value), id, value), retry, st, limit, hu, snapshot)
    case Field.KRetry{}:
      snapshot_observe(name, old, id, Sse.set.retry(Sse.digits(value, 0, 0, False{}), retry), st, limit, hu, snapshot)
    case Field.KOther{}:
      snapshot_observe(name, old, id, retry, st, limit, hu, snapshot)

def more_relation_parts(+len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32,
  +cr: Bool, -st: Sse.St, -next: Sse.St, -view: String & String & String & Maybe<&2, U32>, +limit: Nat,
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left_buffer: buffer_valid(len, Tree.reify(U32, a), s, s, limit),
  right_buffer: buffer_valid(other, Tree.reify(U32, b), t, t, limit),
  left_state: {state_view(st) == view : String & String & String & Maybe<&2, U32>} & state_valid(st, limit),
  right_state: {state_view(next) == view : String & String & String & Maybe<&2, U32>} & state_valid(next, limit)) ->
  line_relation(len, other, Sse.LMore{Tree.reify(U32, a), s, cr, st}, Sse.LMore{Tree.reify(U32, b), t, cr, next}, limit):
  (left_eq, left_valid) = left_state
  (right_eq, right_valid) = right_state
  -V = U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>
  +left = Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s)
  +right = Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)
  (Equal.trans(V, line_view(len, Sse.LMore{Tree.reify(U32, a), s, cr, st}),
    (0, left, cr, view, None{}), line_view(other, Sse.LMore{Tree.reify(U32, b), t, cr, next}),
    Equal.cong(String & String & String & Maybe<&2, U32>, V, x => (0, left, cr, x, None{}),
      state_view(st), view, left_eq),
    Equal.trans(V, (0, left, cr, view, None{}), (0, right, cr, view, None{}),
      line_view(other, Sse.LMore{Tree.reify(U32, b), t, cr, next}),
      Equal.cong(String, V, x => (0, x, cr, view, None{}), left, right, same),
      Equal.sym(V, line_view(other, Sse.LMore{Tree.reify(U32, b), t, cr, next}), (0, right, cr, view, None{}),
        Equal.cong(String & String & String & Maybe<&2, U32>, V, x => (0, right, cr, x, None{}),
          state_view(next), view, right_eq)))),
    (left_buffer, left_valid), (right_buffer, right_valid))

def field_result_snapshot(+k: Field.FieldKind, +old: String, +value: String,
  +name: String, +id: String, +retry: Maybe<&2, U32>, +a: Tree.Tree<U32>,
  +len: U32, +s: U32, +e: U32, +pos: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  snapshot: Field.set_snapshot_type(k, old, value, name, id, retry,
    line_state(Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st)), limit)) ->
  Field.set_snapshot_type(k, old, value, name, id, retry, Field.field_state_result(len, a, s, e, st), limit):
  Field.snapshot_transport(k, old, value, name, id, retry, limit,
    Field.field_state_result(len, a, s, e, st),
    line_state(Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st)),
    Equal.sym(Sse.St, line_state(Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st)),
      Field.field_state_result(len, a, s, e, st),
      Equal.cong(Sse.Line, Sse.St, line_state,
        Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st),
        Sse.LMore{Tree.reify(U32, a), pos, cr, Field.field_state_result(len, a, s, e, st)},
        line_field_pair(a, len, s, e, pos, cr, st))), snapshot)

def line_field_more_finish(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +e: U32, +f: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  -st: Sse.St, -next: Sse.St, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)), qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(other)),
  same: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, a), pos), pos) ==
    Buffer.observed(U32.to_nat((other - next_pos : U32)), Bytes.peek(Tree.reify(U32, b), next_pos), next_pos) : String},
  cert: line_field_refines_type(old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, cr, st, next, limit)) ->
  line_relation(len, other,
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st),
    Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, next_pos, cr, next), limit):
  (+value, left, right) = cert
  line_transport(len, other,
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st),
    Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, next_pos, cr, next),
    Sse.LMore{Tree.reify(U32, a), pos, cr, Field.field_state_result(len, a, s, e, st)},
    Sse.LMore{Tree.reify(U32, b), next_pos, cr, Field.field_state_result(other, b, t, f, next)}, limit,
    line_field_pair(a, len, s, e, pos, cr, st), line_field_pair(b, other, t, f, next_pos, cr, next),
    more_relation_parts(len, other, a, b, pos, next_pos, cr,
      Field.field_state_result(len, a, s, e, st), Field.field_state_result(other, b, t, f, next),
      Field.text_set(Field.field_kind(a, s, e), value, old, name, id, retry), limit, same,
      (a, "", restarted_tail(len, a, pos), {==}, restarted_buffer(len, a, pos, limit, left_shape, hl, pl)),
      (b, "", restarted_tail(other, b, next_pos), {==}, restarted_buffer(other, b, next_pos, limit, right_shape, hr, qo)),
      set_snapshot_observe(Field.field_kind(a, s, e), old, value, name, id, retry,
        Field.field_state_result(len, a, s, e, st), limit, hu,
        field_result_snapshot(Field.field_kind(a, s, e), old, value, name, id, retry, a, len, s, e, pos, cr, st, limit, left)),
      set_snapshot_observe(Field.field_kind(a, s, e), old, value, name, id, retry,
        Field.field_state_result(other, b, t, f, next), limit, hu,
        field_result_snapshot(Field.field_kind(a, s, e), old, value, name, id, retry, b, other, t, f, next_pos, cr, next, limit, right))))

def line_field_more_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +pos: U32, +next_pos: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  se: MNat.le(U32.to_nat(s), U32.to_nat(e)), tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  el: MNat.le(U32.to_nat(e), U32.to_nat(len)), fo: MNat.le(U32.to_nat(f), U32.to_nat(other)),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)), qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, e, f),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((e - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  fields: {Buffer.observed(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((f - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  suffixes: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, a), pos), pos) ==
    Buffer.observed(U32.to_nat((other - next_pos : U32)), Bytes.peek(Tree.reify(U32, b), next_pos), next_pos) : String}) ->
  line_relation(len, other,
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, pos, cr, st),
    Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, next_pos, cr, next), limit):
  line_field_more_finish(old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, st, next, limit,
    left_shape, right_shape, hl, hr, hu, pl, qo, suffixes,
    line_field_refines(old, name, id, retry, a, b, len, other, s, t, e, f, pos, next_pos, cr, cr, st, next, delta, limit,
      hl, hr, hu, se, tf, el, fo, starts, ends, hn, left_state, right_state, fields))

def scan_terminal(+src: Tree.Tree<U32>, +e: U32) -> Type:
  {Packed.peek(src, e) == 10 : U32} | {Packed.peek(src, e) == 13 : U32}

# Hide scanner endpoints from packed reads: https://github.com/bendlang/bend/issues/1071.
def scan_outcome(+fuel: Nat, +src: Tree.Tree<U32>, +s: U32, -actual: U32) -> Type:
  &e: U32 -> {actual == e : U32} &
    ({U32.to_nat(e) == Nat.add(fuel, U32.to_nat(s)) : Nat} | scan_terminal(src, e))

def scan_outcome_step_result(+p: Nat, +src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  hn: MNat.lt(Nat.add(1n+p, U32.to_nat(s)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  result: {U32.to_nat(e) == Nat.add(p, U32.to_nat((s + 1 : U32))) : Nat} | scan_terminal(src, e)) ->
  {U32.to_nat(e) == Nat.add(1n+p, U32.to_nat(s)) : Nat} | scan_terminal(src, e):
  match result:
    case Inl{eq}:
      Inl{Equal.trans(Nat, U32.to_nat(e), Nat.add(p, U32.to_nat((s + 1 : U32))), Nat.add(1n+p, U32.to_nat(s)),
        eq, Equal.sym(Nat, Nat.add(1n+p, U32.to_nat(s)), Nat.add(p, U32.to_nat((s + 1 : U32))),
          scan_total_step(p, s, limit, hn, hu)))}
    case Inr{terminal}:
      Inr{terminal}

def scan_outcome_step(+p: Nat, +src: Tree.Tree<U32>, +s: U32, -actual: U32, +limit: Nat,
  hn: MNat.lt(Nat.add(1n+p, U32.to_nat(s)), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  outcome: scan_outcome(p, src, (s + 1 : U32), actual)) ->
  scan_outcome(1n+p, src, s, actual):
  (+e, eq, result) = outcome
  (e, eq, scan_outcome_step_result(p, src, s, e, limit, hn, hu, result))

def eol_outcome(fuel: Nat, +src: Tree.Tree<U32>, +c: U32, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(fuel, U32.to_nat(s)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +head: {Packed.peek(src, s) == c : U32}) ->
  scan_outcome(fuel, src, s, Buffer.index(Sse.eol(fuel, (Tree.reify(U32, src), c), s))):
  match fuel:
    case 0n:
      (s, {==}, Inl{{==}})
    case 1n+ +p:
      Scan.eol_elim(x => scan_outcome(1n+p, src, s, Buffer.index(x)), p, Tree.reify(U32, src), c, s,
        lf => (s, {==}, Inr{Inl{Equal.trans(U32, Packed.peek(src, s), c, 10, head, lf)}}),
        cr => (s, {==}, Inr{Inr{Equal.trans(U32, Packed.peek(src, s), c, 13, head, cr)}}),
        good => (
          %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), (s + 1 : U32)),
            (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), Buffer.tree_peek(src, (s + 1 : U32))) :
            scan_outcome(1n+p, src, s, Buffer.index(Sse.eol(p, _, (s + 1 : U32))))
          scan_outcome_step(p, src, s,
            Buffer.index(Sse.eol(p, (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), (s + 1 : U32))), limit, hn, hu,
            eol_outcome(p, src, Packed.peek(src, (s + 1 : U32)), (s + 1 : U32), limit,
              Offset.tail_bound(p, s, limit, hu, hn), hu, {==}))))

def line_scan_result(+src: Tree.Tree<U32>, +s: U32, +len: U32, +e: U32,
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  result: {U32.to_nat(e) == Nat.add(U32.to_nat((len - s : U32)), U32.to_nat(s)) : Nat} | scan_terminal(src, e)) ->
  {e == len : U32} | scan_terminal(src, e):
  match result:
    case Inl{eq}:
      Inl{Lemmas.u32_to_nat_inj(e, len,
        Equal.trans(Nat, U32.to_nat(e), Nat.add(U32.to_nat((len - s : U32)), U32.to_nat(s)), U32.to_nat(len),
          eq, Field.span_end(s, len, sl)))}
    case Inr{terminal}:
      Inr{terminal}

def line_scan_snapshot(+src: Tree.Tree<U32>, +len: U32, -actual: U32) -> Type:
  &e: U32 -> {actual == e : U32} & ({e == len : U32} | scan_terminal(src, e))

def line_scan_finish(+src: Tree.Tree<U32>, +s: U32, +len: U32, -actual: U32,
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), outcome: scan_outcome(U32.to_nat((len - s : U32)), src, s, actual)) ->
  line_scan_snapshot(src, len, actual):
  (+e, eq, result) = outcome
  (e, eq, line_scan_result(src, s, len, e, sl, result))

def line_scan_outcome(+src: Tree.Tree<U32>, +s: U32, +len: U32, +limit: Nat,
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  line_scan_snapshot(src, len, Refinement.eol_index(U32.to_nat((len - s : U32)), src, s)):
  line_scan_finish(src, s, len, Refinement.eol_index(U32.to_nat((len - s : U32)), src, s), sl,
    (%Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), s),
      (Tree.reify(U32, src), Packed.peek(src, s)), Buffer.tree_peek(src, s)) :
      scan_outcome(U32.to_nat((len - s : U32)), src, s, Buffer.index(Sse.eol(U32.to_nat((len - s : U32)), _, s)))
     eol_outcome(U32.to_nat((len - s : U32)), src, Packed.peek(src, s), s, limit,
       Refinement.endpoint_bound(U32.to_nat((len - s : U32)), s, len, len, limit,
         Field.span_end(s, len, sl), MNat.le_refl(U32.to_nat(len)), hl), hu, {==})))


def empty_state_snapshot(+name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(0)), Packed.as_bits(src)),
  bound: MNat.lt(3n, limit)) ->
  Field.state_snapshot(name, "", id, retry,
    Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}, limit):
  (0, src, {==}, shape, {==}, bound, Unit{})

def blank_empty_refines(+name: String, +id: String, +retry: Maybe<&2, U32>,
  +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>,
  +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +pos: U32, +next_pos: U32, +cr: Bool, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  state_left_shape: Bound.shape(Local.depth(Local.words(0)), Packed.as_bits(src)),
  state_right_shape: Bound.shape(Local.depth(Local.words(0)), Packed.as_bits(dst)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +bound: MNat.lt(3n, limit),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)), qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(other)),
  same: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, a), pos), pos) ==
    Buffer.observed(U32.to_nat((other - next_pos : U32)), Bytes.peek(Tree.reify(U32, b), next_pos), next_pos) : String}) ->
  line_relation(len, other,
    Sse.line.body(True{}, Tree.reify(U32, a), len, s, e, pos, cr,
      Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}),
    Sse.line.body(True{}, Tree.reify(U32, b), other, t, f, next_pos, cr,
      Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, dst)}, id, retry}), limit):
  line_transport(len, other,
    Sse.line.body(True{}, Tree.reify(U32, a), len, s, e, pos, cr,
      Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}),
    Sse.line.body(True{}, Tree.reify(U32, b), other, t, f, next_pos, cr,
      Sse.St{name, Bytes.Bytes{0, Tree.reify(U32, dst)}, id, retry}),
    Sse.LMore{Tree.reify(U32, a), pos, cr, Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}},
    Sse.LMore{Tree.reify(U32, b), next_pos, cr, Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, dst)}, id, retry}}, limit,
    line_blank_empty(name, id, retry, src, a, len, s, e, pos, cr),
    line_blank_empty(name, id, retry, dst, b, other, t, f, next_pos, cr),
    more_relation_parts(len, other, a, b, pos, next_pos, cr,
      Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry},
      Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, dst)}, id, retry}, ("", "", id, retry), limit, same,
      (a, "", restarted_tail(len, a, pos), {==}, restarted_buffer(len, a, pos, limit, left_shape, hl, pl)),
      (b, "", restarted_tail(other, b, next_pos), {==}, restarted_buffer(other, b, next_pos, limit, right_shape, hr, qo)),
      snapshot_observe("", "", id, retry, Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, src)}, id, retry}, limit, hu,
        empty_state_snapshot("", id, retry, src, limit, state_left_shape, bound)),
      snapshot_observe("", "", id, retry, Sse.St{"", Bytes.Bytes{0, Tree.reify(U32, dst)}, id, retry}, limit, hu,
        empty_state_snapshot("", id, retry, dst, limit, state_right_shape, bound))))

def advance_want(f: Nat, -a: Array<U32>, +len: U32, +pos: U32, +cr: Bool, -st: Sse.St) ->
  {advance(f, Sse.LWant{a, pos, cr, st}, len) == Sse.LWant{a, pos, cr, st} : Sse.Line}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      {==}

def advance_got(f: Nat, -a: Array<U32>, +len: U32, +pos: U32, +cr: Bool, -st: Sse.St, -event: Sse.Message) ->
  {advance(f, Sse.LGot{a, pos, cr, st, event}, len) == Sse.LGot{a, pos, cr, st, event} : Sse.Line}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      {==}

def advance_add(f: Nat, +g: Nat, l: Sse.Line, +len: U32) ->
  {advance(Nat.add(f, g), l, len) == advance(g, advance(f, l, len), len) : Sse.Line}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      match l:
        case Sse.LMore{a, +pos, cr, st}:
          advance_add(p, g, Sse.line(a, len, pos, pos, cr, st), len)
        case Sse.LWant{a, pos, cr, st}:
          Equal.sym(Sse.Line, advance(g, Sse.LWant{a, pos, cr, st}, len), Sse.LWant{a, pos, cr, st},
            advance_want(g, a, len, pos, cr, st))
        case Sse.LGot{a, pos, cr, st, event}:
          Equal.sym(Sse.Line, advance(g, Sse.LGot{a, pos, cr, st, event}, len), Sse.LGot{a, pos, cr, st, event},
            advance_got(g, a, len, pos, cr, st, event))

def loop_add(f: Nat, +g: Nat, l: Sse.Line, +len: U32) ->
  {Sse.loop(Nat.add(f, g), l, len) == Sse.loop(g, advance(f, l, len), len) : Sse.Reader & Sse.Next}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      match l:
        case Sse.LMore{a, +pos, cr, st}:
          loop_add(p, g, Sse.line(a, len, pos, pos, cr, st), len)
        case Sse.LWant{a, pos, cr, st}:
          Equal.sym(Sse.Reader & Sse.Next, Sse.loop(g, Sse.LWant{a, pos, cr, st}, len),
            (Sse.Reader{Bytes.Bytes{len, a}, pos, len, cr, st}, Sse.Want{}), loop_want(g, a, len, pos, cr, st))
        case Sse.LGot{a, pos, cr, st, event}:
          Equal.sym(Sse.Reader & Sse.Next, Sse.loop(g, Sse.LGot{a, pos, cr, st, event}, len),
            (Sse.Reader{Bytes.Bytes{len, a}, pos, pos, cr, st}, Sse.Got{event}), loop_got(g, a, len, pos, cr, st, event))

def scan_bounds(+fuel: Nat, +s: U32, +e: U32) -> Type:
  MNat.le(U32.to_nat(s), U32.to_nat(e)) &
    MNat.le(U32.to_nat(e), Nat.add(fuel, U32.to_nat(s)))

def scan_bounds_stop(+fuel: Nat, +s: U32) -> scan_bounds(fuel, s, s):
  (MNat.le_refl(U32.to_nat(s)), MNat.le_add_left(U32.to_nat(s), fuel))

def scan_bounds_step(+p: Nat, +s: U32, +e: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(1n+p, U32.to_nat(s)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  bounds: scan_bounds(p, (s + 1 : U32), e)) ->
  scan_bounds(1n+p, s, e):
  (lower, upper) = bounds
  +inc = Packed.add_one_nat(s,
    MNat.lt_of_lt_of_le(1n+U32.to_nat(s), limit, Lemmas.pow2(32n), Offset.increment_bound(p, s, limit, hn), hu))
  (MNat.le_trans(U32.to_nat(s), U32.to_nat((s + 1 : U32)), U32.to_nat(e),
    (%Equal.sym(Nat, U32.to_nat((s + 1 : U32)), 1n+U32.to_nat(s), inc) : MNat.le(U32.to_nat(s), _)
     MNat.le_succ(U32.to_nat(s))), lower),
    (%Equal.sym(Nat, Nat.add(1n+p, U32.to_nat(s)), Nat.add(p, U32.to_nat((s + 1 : U32))), scan_total_step(p, s, limit, hn, hu)) :
      MNat.le(U32.to_nat(e), _)
     upper))

def eol_bounds(fuel: Nat, +src: Tree.Tree<U32>, +c: U32, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(fuel, U32.to_nat(s)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  scan_bounds(fuel, s, Buffer.index(Sse.eol(fuel, (Tree.reify(U32, src), c), s))):
  match fuel:
    case 0n:
      scan_bounds_stop(0n, s)
    case 1n+ +p:
      Scan.eol_elim(x => scan_bounds(1n+p, s, Buffer.index(x)), p, Tree.reify(U32, src), c, s,
        lf => scan_bounds_stop(1n+p, s),
        cr => scan_bounds_stop(1n+p, s),
        good => (
          %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), (s + 1 : U32)),
            (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), Buffer.tree_peek(src, (s + 1 : U32))) :
            scan_bounds(1n+p, s, Buffer.index(Sse.eol(p, _, (s + 1 : U32))))
          scan_bounds_step(p, s,
            Buffer.index(Sse.eol(p, (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), (s + 1 : U32))), limit,
            hn, hu, eol_bounds(p, src, Packed.peek(src, (s + 1 : U32)), (s + 1 : U32), limit,
              Offset.tail_bound(p, s, limit, hu, hn), hu))))

def scan_bounds_at(+fuel: Nat, +s: U32, -actual: U32, +e: U32,
  eq: {actual == e : U32}, bounds: scan_bounds(fuel, s, actual)) ->
  scan_bounds(fuel, s, e):
  %eq : scan_bounds(fuel, s, _)
  bounds

def line_scan_bounded_type(+src: Tree.Tree<U32>, +s: U32, +len: U32, -actual: U32) -> Type:
  &e: U32 -> {actual == e : U32} &
    MNat.le(U32.to_nat(s), U32.to_nat(e)) & MNat.le(U32.to_nat(e), U32.to_nat(len)) &
    ({e == len : U32} | scan_terminal(src, e))

def line_scan_bounded_parts(+src: Tree.Tree<U32>, +s: U32, +len: U32, -actual: U32, +e: U32,
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), eq: {actual == e : U32},
  result: {e == len : U32} | scan_terminal(src, e),
  bounds: scan_bounds(U32.to_nat((len - s : U32)), s, e)) ->
  line_scan_bounded_type(src, s, len, actual):
  (lower, upper) = bounds
  (e, eq, lower,
    (%Field.span_end(s, len, sl) : MNat.le(U32.to_nat(e), _)
     upper), result)

def line_scan_bounded_finish(+src: Tree.Tree<U32>, +s: U32, +len: U32, -actual: U32,
  sl: MNat.le(U32.to_nat(s), U32.to_nat(len)),
  bounds: scan_bounds(U32.to_nat((len - s : U32)), s, actual),
  snapshot: line_scan_snapshot(src, len, actual)) ->
  line_scan_bounded_type(src, s, len, actual):
  (+e, +eq, result) = snapshot
  line_scan_bounded_parts(src, s, len, actual, e, sl, eq, result,
    scan_bounds_at(U32.to_nat((len - s : U32)), s, actual, e, eq, bounds))

def line_scan_bounded(+src: Tree.Tree<U32>, +s: U32, +len: U32, +limit: Nat,
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +hl: MNat.lt(U32.to_nat(len), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  line_scan_bounded_type(src, s, len, Refinement.eol_index(U32.to_nat((len - s : U32)), src, s)):
  line_scan_bounded_finish(src, s, len, Refinement.eol_index(U32.to_nat((len - s : U32)), src, s), sl,
    (%Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), s),
      (Tree.reify(U32, src), Packed.peek(src, s)), Buffer.tree_peek(src, s)) :
      scan_bounds(U32.to_nat((len - s : U32)), s, Buffer.index(Sse.eol(U32.to_nat((len - s : U32)), _, s)))
     eol_bounds(U32.to_nat((len - s : U32)), src, Packed.peek(src, s), s, limit,
       Refinement.endpoint_bound(U32.to_nat((len - s : U32)), s, len, len, limit,
         Field.span_end(s, len, sl), MNat.le_refl(U32.to_nat(len)), hl), hu)),
    line_scan_outcome(src, s, len, limit, sl, hl, hu))

def reset_state_valid(+id: String, +retry: Maybe<&2, U32>, +limit: Nat, bound: MNat.lt(3n, limit)) ->
  state_valid(Sse.St{"", Bytes.new(0), id, retry}, limit):
  ("", "", id, retry, 0, Packed.alloc(0), {==},
    Packed.fresh_shape(Local.depth(Local.words(0))), {==}, bound, Unit{})

def message_observe_parts(+name: String, +text: String, +id: String,
  +len: U32, +src: Tree.Tree<U32>, +limit: Nat,
  +length: {U32.to_nat(len) == String.length(text) : Nat},
  +hl: MNat.lt(U32.to_nat(len), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  reads: Packed.Reads(text, src, 0) & Packed.Reads(text, src, 0)) ->
  {Line.message_text(Some{Sse.Message{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id}}) ==
    Some{(name, text, id)} : Maybe<&1, String & String & String>} &
    message_valid(Sse.Message{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id}, limit):
  (left, right) = reads
  (Equal.cong(String, Maybe<&1, String & String & String>, value => Some{(name, value, id)},
    Bytes.to_string(Bytes.Bytes{len, Tree.reify(U32, src)}), text,
    Field.packed_string(text, len, src, limit, length, hu,
      (%length : MNat.lt(Nat.add(_, 0n), limit)
       %Equal.sym(Nat, Nat.add(U32.to_nat(len), 0n), U32.to_nat(len), MNat.add_zero(U32.to_nat(len))) : MNat.lt(_, limit)
       hl), left)),
    (text, len, src, {==}, length, hl, right))

def message_observe(+name: String, +text: String, +id: String,
  +len: U32, +src: Tree.Tree<U32>, +limit: Nat,
  length: {U32.to_nat(len) == String.length(text) : Nat},
  hl: MNat.lt(U32.to_nat(len), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  reads: Packed.Reads(text, src, 0)) ->
  {Line.message_text(Some{Sse.Message{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id}}) ==
    Some{(name, text, id)} : Maybe<&1, String & String & String>} &
    message_valid(Sse.Message{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id}, limit):
  message_observe_parts(name, text, id, len, src, limit, length, hl, hu, copy_reads(text, src, 0, reads))

def got_relation_views(+len: U32, +other: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32,
  +cr: Bool, +id: String, +retry: Maybe<&2, U32>, -left: Sse.Message, -right: Sse.Message,
  -view: Maybe<&1, String & String & String>, +limit: Nat,
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  left_buffer: buffer_valid(len, Tree.reify(U32, a), s, s, limit),
  right_buffer: buffer_valid(other, Tree.reify(U32, b), t, t, limit),
  +bound: MNat.lt(3n, limit),
  left_message: {Line.message_text(Some{left}) == view : Maybe<&1, String & String & String>} & message_valid(left, limit),
  right_message: {Line.message_text(Some{right}) == view : Maybe<&1, String & String & String>} & message_valid(right, limit)) ->
  line_relation(len, other,
    Sse.LGot{Tree.reify(U32, a), s, cr, Sse.St{"", Bytes.new(0), id, retry}, left},
    Sse.LGot{Tree.reify(U32, b), t, cr, Sse.St{"", Bytes.new(0), id, retry}, right}, limit):
  (ea, va) = left_message
  (eb, vb) = right_message
  -V = U32 & String & Bool & (String & String & String & Maybe<&2, U32>) & Maybe<&1, String & String & String>
  +unread_left = Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s)
  +unread_right = Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)
  -state = state_view(Sse.St{"", Bytes.new(0), id, retry})
  (Equal.trans(V,
    (2, unread_left, cr, state, Line.message_text(Some{left})), (2, unread_left, cr, state, view),
    (2, unread_right, cr, state, Line.message_text(Some{right})),
    Equal.cong(Maybe<&1, String & String & String>, V, x => (2, unread_left, cr, state, x),
      Line.message_text(Some{left}), view, ea),
    Equal.trans(V, (2, unread_left, cr, state, view), (2, unread_right, cr, state, view),
      (2, unread_right, cr, state, Line.message_text(Some{right})),
      Equal.cong(String, V, x => (2, x, cr, state, view), unread_left, unread_right, same),
      Equal.sym(V, (2, unread_right, cr, state, Line.message_text(Some{right})), (2, unread_right, cr, state, view),
        Equal.cong(Maybe<&1, String & String & String>, V, x => (2, unread_right, cr, state, x),
          Line.message_text(Some{right}), view, eb)))),
    (left_buffer, reset_state_valid(id, retry, limit, bound), va),
    (right_buffer, reset_state_valid(id, retry, limit, bound), vb))

def blank_emitted_refines(+text: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +data_len: U32, +next_data_len: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>,
  +len: U32, +other: U32, +pos: U32, +next_pos: U32, +cr: Bool,
  -left: Sse.Line, -right: Sse.Line, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), bound: MNat.lt(3n, limit),
  pl: MNat.le(U32.to_nat(pos), U32.to_nat(len)), qo: MNat.le(U32.to_nat(next_pos), U32.to_nat(other)),
  left_length: {U32.to_nat((data_len - 1 : U32)) == String.length(text) : Nat},
  right_length: {U32.to_nat((next_data_len - 1 : U32)) == String.length(text) : Nat},
  left_bound: MNat.lt(U32.to_nat((data_len - 1 : U32)), limit),
  right_bound: MNat.lt(U32.to_nat((next_data_len - 1 : U32)), limit),
  same: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, a), pos), pos) ==
    Buffer.observed(U32.to_nat((other - next_pos : U32)), Bytes.peek(Tree.reify(U32, b), next_pos), next_pos) : String},
  left_snapshot: line_blank_emitted_type(text, name, id, retry, data_len, a, pos, cr, left),
  right_snapshot: line_blank_emitted_type(text, name, id, retry, next_data_len, b, next_pos, cr, right)) ->
  line_relation(len, other, left, right, limit):
  (+out, left_eq, left_reads) = left_snapshot
  (+next_out, right_eq, right_reads) = right_snapshot
  +event_name = Bool.pick(String, String.is_empty(name), "message", name)
  line_transport(len, other, left, right,
    Sse.LGot{Tree.reify(U32, a), pos, cr, Sse.St{"", Bytes.new(0), id, retry},
      Sse.Message{event_name, Bytes.Bytes{(data_len - 1 : U32), Tree.reify(U32, out)}, id}},
    Sse.LGot{Tree.reify(U32, b), next_pos, cr, Sse.St{"", Bytes.new(0), id, retry},
      Sse.Message{event_name, Bytes.Bytes{(next_data_len - 1 : U32), Tree.reify(U32, next_out)}, id}},
    limit, left_eq, right_eq,
    got_relation_views(len, other, a, b, pos, next_pos, cr, id, retry,
      Sse.Message{event_name, Bytes.Bytes{(data_len - 1 : U32), Tree.reify(U32, out)}, id},
      Sse.Message{event_name, Bytes.Bytes{(next_data_len - 1 : U32), Tree.reify(U32, next_out)}, id},
      Some{(event_name, text, id)}, limit, same,
      (a, "", restarted_tail(len, a, pos), {==}, restarted_buffer(len, a, pos, limit, left_shape, hl, pl)),
      (b, "", restarted_tail(other, b, next_pos), {==}, restarted_buffer(other, b, next_pos, limit, right_shape, hr, qo)),
      bound,
      message_observe(event_name, text, id, (data_len - 1 : U32), out, limit, left_length, left_bound, hu, left_reads),
      message_observe(event_name, text, id, (next_data_len - 1 : U32), next_out, limit, right_length, right_bound, hu, right_reads)))

def next_scan(+len: U32, +pos: U32, +i: U32, a: Array<U32>, cr: Bool, st: Sse.St) -> Sse.Reader & Sse.Next:
  Sse.loop(Nat.add(U32.to_nat((len - pos : U32)), 2n),
    Sse.line.eol(len, pos, cr, st, Sse.eol(U32.to_nat((len - i : U32)), Bytes.peek(a, i), i)), len)

def next_at_restart(+len: U32, +seen: U32, +pos: U32, -a: Array<U32>, +cr: Bool, -st: Sse.St,
  before: MNat.le(U32.to_nat(seen), U32.to_nat(pos))) ->
  {Sse.next.at(len, seen, st, (a, pos, cr)) == Sse.next.at(len, pos, st, (a, pos, cr)) : Sse.Reader & Sse.Next}:
  Equal.cong(U32, Sse.Reader & Sse.Next, i => next_scan(len, pos, i, a, cr, st),
    U32.max(pos, seen), U32.max(pos, pos),
    Equal.trans(U32, U32.max(pos, seen), pos, U32.max(pos, pos),
      Reader.max_left(pos, seen, before), Equal.sym(U32, U32.max(pos, pos), pos, Lemmas.u32_max_self(pos))))

def cursor_step(+pos: U32, +len: U32, +limit: Nat,
  +before: MNat.lt(U32.to_nat(pos), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(U32.to_nat(pos), U32.to_nat((pos + 1 : U32))) &
    MNat.le(U32.to_nat((pos + 1 : U32)), U32.to_nat(len)):
  +upper = MNat.succ_le_of_lt(U32.to_nat(pos), U32.to_nat(len), before)
  +inc = Packed.add_one_nat(pos,
    MNat.lt_of_lt_of_le(1n+U32.to_nat(pos), limit, Lemmas.pow2(32n),
      MNat.lt_of_le_of_lt(1n+U32.to_nat(pos), U32.to_nat(len), limit, upper, hl), hu))
  ((%Equal.sym(Nat, U32.to_nat((pos + 1 : U32)), 1n+U32.to_nat(pos), inc) : MNat.le(U32.to_nat(pos), _)
    MNat.le_succ(U32.to_nat(pos))),
    (%Equal.sym(Nat, U32.to_nat((pos + 1 : U32)), 1n+U32.to_nat(pos), inc) : MNat.le(_, U32.to_nat(len))
     upper))

def next_pending_restart(+len: U32, +pos: U32, +src: Tree.Tree<U32>, -st: Sse.St,
  available: {U32.is_lt(pos, len) == True{} : Bool},
  lf: {Packed.peek(src, pos) == 10 : U32},
  before: MNat.le(U32.to_nat(pos), U32.to_nat((pos + 1 : U32)))) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, (pos + 1 : U32), (pos + 1 : U32), False{}, st}) :
      Sse.Reader & Sse.Next}:
  Equal.trans(Sse.Reader & Sse.Next,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}),
    Sse.next.at(len, pos, st, (Tree.reify(U32, src), (pos + 1 : U32), False{})),
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, (pos + 1 : U32), (pos + 1 : U32), False{}, st}),
    next_pending(len, pos, pos, src, st, available, lf),
    next_at_restart(len, pos, (pos + 1 : U32), Tree.reify(U32, src), False{}, st, before))

def pending_restart_parts(+len: U32, +pos: U32, +src: Tree.Tree<U32>, -st: Sse.St, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit),
  available: {U32.is_lt(pos, len) == True{} : Bool}, lf: {Packed.peek(src, pos) == 10 : U32},
  bounds: MNat.le(U32.to_nat(pos), U32.to_nat((pos + 1 : U32))) &
    MNat.le(U32.to_nat((pos + 1 : U32)), U32.to_nat(len))) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, (pos + 1 : U32), (pos + 1 : U32), False{}, st}) :
      Sse.Reader & Sse.Next} &
    buffer_valid(len, Tree.reify(U32, src), (pos + 1 : U32), (pos + 1 : U32), limit):
  (lower, upper) = bounds
  (next_pending_restart(len, pos, src, st, available, lf, lower),
    (src, "", restarted_tail(len, src, (pos + 1 : U32)), {==},
      restarted_buffer(len, src, (pos + 1 : U32), limit, shape, hl, upper)))

def pending_restart_valid(+len: U32, +pos: U32, +src: Tree.Tree<U32>, -st: Sse.St, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  +before: MNat.lt(U32.to_nat(pos), U32.to_nat(len)), lf: {Packed.peek(src, pos) == 10 : U32}) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, (pos + 1 : U32), (pos + 1 : U32), False{}, st}) :
      Sse.Reader & Sse.Next} &
    buffer_valid(len, Tree.reify(U32, src), (pos + 1 : U32), (pos + 1 : U32), limit):
  pending_restart_parts(len, pos, src, st, limit, shape, hl,
    Equal.trans(Bool, U32.is_lt(pos, len), Nat.is_lt(U32.to_nat(pos), U32.to_nat(len)), True{},
      Lemmas.u32_is_lt_nat(pos, len), before), lf,
    cursor_step(pos, len, limit, before,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu))

def line_lf_nonblank(+a: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, -st: Sse.St,
  lf: {Packed.peek(a, e) == 10 : U32}, nonblank: {U32.is_eq(s, e) == False{} : Bool}) ->
  {Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, a), e)) ==
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}:
  Equal.trans(Sse.Line,
    Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, a), e)),
    Sse.line.body(U32.is_eq(s, e), Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st),
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st),
    line_term_lf(a, len, s, e, st, lf),
    Equal.cong(Bool, Sse.Line, blank => Sse.line.body(blank, Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st),
      U32.is_eq(s, e), False{}, nonblank))

def lt_eq_false(a: Nat, b: Nat, h: MNat.lt(a, b)) -> {Nat.is_eq(a, b) == False{} : Bool}:
  match a b:
    case 0n 0n:
      Empty.absurd({Nat.is_eq(0n, 0n) == False{} : Bool}, MNat.lt_irrefl(0n)(h))
    case 0n 1n+p:
      {==}
    case 1n+p 0n:
      Empty.absurd({Nat.is_eq(1n+p, 0n) == False{} : Bool}, MNat.lt_irrefl(0n)(h))
    case 1n+p 1n+q:
      lt_eq_false(p, q, h)

def endpoint_is_ne(+e: U32, +len: U32, h: MNat.lt(U32.to_nat(e), U32.to_nat(len))) ->
  {U32.is_eq(e, len) == False{} : Bool}:
  Equal.trans(Bool, U32.is_eq(e, len), Nat.is_eq(U32.to_nat(e), U32.to_nat(len)), False{},
    Lemmas.u32_is_eq_nat(e, len), lt_eq_false(U32.to_nat(e), U32.to_nat(len), h))

def line_end_term(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +cr: Bool, -st: Sse.St,
  before: MNat.lt(U32.to_nat(e), U32.to_nat(len))) ->
  {Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st) ==
    Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e)) : Sse.Line}:
  Equal.cong(Bool, Sse.Line, want => Sse.line.end(want, Tree.reify(U32, src), len, s, e, cr, st),
    U32.is_eq(e, len), False{}, endpoint_is_ne(e, len, before))

def line_scanned_lf(+src: Tree.Tree<U32>, +len: U32, +s: U32, +e: U32, +cr: Bool, -st: Sse.St,
  scan: {Refinement.eol_index(U32.to_nat((len - s : U32)), src, s) == e : U32},
  before: MNat.lt(U32.to_nat(e), U32.to_nat(len)), lf: {Packed.peek(src, e) == 10 : U32},
  nonblank: {U32.is_eq(s, e) == False{} : Bool}) ->
  {Sse.line(Tree.reify(U32, src), len, s, s, cr, st) ==
    Sse.line.body(False{}, Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st) : Sse.Line}:
  Equal.trans(Sse.Line, Sse.line(Tree.reify(U32, src), len, s, s, cr, st),
    Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st),
    Sse.line.body(False{}, Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
    line_scanned_at(src, len, s, e, cr, st, scan),
    Equal.trans(Sse.Line, Sse.line.end(U32.is_eq(e, len), Tree.reify(U32, src), len, s, e, cr, st),
      Sse.line.term(len, s, e, st, Bytes.peek(Tree.reify(U32, src), e)),
      Sse.line.body(False{}, Tree.reify(U32, src), len, s, e, (e + 1 : U32), False{}, st),
      line_end_term(src, len, s, e, cr, st, before), line_lf_nonblank(src, len, s, e, st, lf, nonblank)))

def line_lf_field_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +e: U32, +f: U32,
  +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +se: MNat.le(U32.to_nat(s), U32.to_nat(e)), +tf: MNat.le(U32.to_nat(t), U32.to_nat(f)),
  +el: MNat.lt(U32.to_nat(e), U32.to_nat(len)), +fo: MNat.lt(U32.to_nat(f), U32.to_nat(other)),
  +starts: Offset.offset(delta, s, t), +scanned: Offset.offset(delta, e, f), +ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left_scan: {Refinement.eol_index(U32.to_nat((len - s : U32)), a, s) == e : U32},
  right_scan: {Refinement.eol_index(U32.to_nat((other - t : U32)), b, t) == f : U32},
  left_lf: {Packed.peek(a, e) == 10 : U32}, right_lf: {Packed.peek(b, f) == 10 : U32},
  left_nonblank: {U32.is_eq(s, e) == False{} : Bool}, right_nonblank: {U32.is_eq(t, f) == False{} : Bool},
  +same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  line_relation(len, other, Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next), limit):
  +hl0 = MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)
  +hr0 = MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr)
  +ep = Pair.fst(MNat.le(U32.to_nat(e), U32.to_nat((e + 1 : U32))), MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(len)),
    cursor_step(e, len, limit, el, hl0, hu))
  +fq = Pair.fst(MNat.le(U32.to_nat(f), U32.to_nat((f + 1 : U32))), MNat.le(U32.to_nat((f + 1 : U32)), U32.to_nat(other)),
    cursor_step(f, other, limit, fo, hr0, hu))
  +pl = Pair.snd(MNat.le(U32.to_nat(e), U32.to_nat((e + 1 : U32))), MNat.le(U32.to_nat((e + 1 : U32)), U32.to_nat(len)),
    cursor_step(e, len, limit, el, hl0, hu))
  +qo = Pair.snd(MNat.le(U32.to_nat(f), U32.to_nat((f + 1 : U32))), MNat.le(U32.to_nat((f + 1 : U32)), U32.to_nat(other)),
    cursor_step(f, other, limit, fo, hr0, hu))
  +el0 = MNat.le_of_lt(U32.to_nat(e), U32.to_nat(len), el)
  +fo0 = MNat.le_of_lt(U32.to_nat(f), U32.to_nat(other), fo)
  +advanced = Offset.increment(delta, e, f, limit,
    MNat.lt_of_le_of_lt(1n+U32.to_nat(e), U32.to_nat(len), limit, MNat.succ_le_of_lt(U32.to_nat(e), U32.to_nat(len), el), hl0),
    MNat.lt_of_le_of_lt(1n+U32.to_nat(f), U32.to_nat(other), limit, MNat.succ_le_of_lt(U32.to_nat(f), U32.to_nat(other), fo), hr0), hu, scanned)
  line_transport(len, other,
    Sse.line(Tree.reify(U32, a), len, s, s, cr, st),
    Sse.line(Tree.reify(U32, b), other, t, t, cr, next),
    Sse.line.body(False{}, Tree.reify(U32, a), len, s, e, (e + 1 : U32), False{}, st),
    Sse.line.body(False{}, Tree.reify(U32, b), other, t, f, (f + 1 : U32), False{}, next), limit,
    line_scanned_lf(a, len, s, e, cr, st, left_scan, el, left_lf, left_nonblank),
    line_scanned_lf(b, other, t, f, cr, next, right_scan, fo, right_lf, right_nonblank),
    line_field_more_refines(old, name, id, retry, a, b, len, other, s, t, e, f, (e + 1 : U32), (f + 1 : U32), False{},
      st, next, delta, limit, left_shape, right_shape, hl, hr, hu, se, tf, el0, fo0, pl, qo, starts, scanned,
      Refinement.accumulation_bound(String.length(old), U32.to_nat((e - s : U32)), U32.to_nat((len - s : U32)), limit,
        Refinement.prefix_length_le(s, e, len, se, el0), hn), left_state, right_state,
      Refinement.prefix_span(a, b, s, t, len, other, e, f, delta, se, tf, el0, fo0, starts, scanned, ends, same),
      Refinement.subspan(a, b, s, t, len, other, (e + 1 : U32), (f + 1 : U32), delta, limit,
        MNat.le_trans(U32.to_nat(s), U32.to_nat(e), U32.to_nat((e + 1 : U32)), se, ep),
        MNat.le_trans(U32.to_nat(t), U32.to_nat(f), U32.to_nat((f + 1 : U32)), tf, fq),
        pl, qo, hl0, hr0, hu, starts, advanced, ends, same)))

def cursor_width(+pos: U32, +limit: Nat,
  before: MNat.le(U32.to_nat(pos), U32.to_nat((pos + 1 : U32))),
  bound: MNat.lt(1n+U32.to_nat(pos), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {U32.to_nat(((pos + 1 : U32) - pos : U32)) == 1n : Nat}:
  MNat.add_right_cancel(U32.to_nat(((pos + 1 : U32) - pos : U32)), U32.to_nat(pos), 1n,
    Equal.trans(Nat, Nat.add(U32.to_nat(((pos + 1 : U32) - pos : U32)), U32.to_nat(pos)),
      U32.to_nat((pos + 1 : U32)), 1n+U32.to_nat(pos), Field.span_end(pos, (pos + 1 : U32), before),
      Packed.add_one_nat(pos, MNat.lt_of_lt_of_le(1n+U32.to_nat(pos), limit, Lemmas.pow2(32n), bound, hu))))

def remaining_step_parts(+len: U32, +pos: U32, +limit: Nat,
  +before: MNat.lt(U32.to_nat(pos), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  bounds: MNat.le(U32.to_nat(pos), U32.to_nat((pos + 1 : U32))) &
    MNat.le(U32.to_nat((pos + 1 : U32)), U32.to_nat(len))) ->
  {U32.to_nat((len - pos : U32)) == 1n+U32.to_nat((len - (pos + 1 : U32) : U32)) : Nat}:
  (+lower, upper) = bounds
  Equal.trans(Nat, U32.to_nat((len - pos : U32)),
    Nat.add(U32.to_nat(((pos + 1 : U32) - pos : U32)), U32.to_nat((len - (pos + 1 : U32) : U32))),
    1n+U32.to_nat((len - (pos + 1 : U32) : U32)),
    Equal.sym(Nat,
      Nat.add(U32.to_nat(((pos + 1 : U32) - pos : U32)), U32.to_nat((len - (pos + 1 : U32) : U32))),
      U32.to_nat((len - pos : U32)), Refinement.split_span(pos, (pos + 1 : U32), len, lower, upper)),
    Equal.cong(Nat, Nat, n => Nat.add(n, U32.to_nat((len - (pos + 1 : U32) : U32))),
      U32.to_nat(((pos + 1 : U32) - pos : U32)), 1n,
      cursor_width(pos, limit, lower,
        MNat.lt_of_le_of_lt(1n+U32.to_nat(pos), U32.to_nat(len), limit, MNat.succ_le_of_lt(U32.to_nat(pos), U32.to_nat(len), before), hl), hu)))

def remaining_step(+len: U32, +pos: U32, +limit: Nat,
  +before: MNat.lt(U32.to_nat(pos), U32.to_nat(len)), +hl: MNat.lt(U32.to_nat(len), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {U32.to_nat((len - pos : U32)) == 1n+U32.to_nat((len - (pos + 1 : U32) : U32)) : Nat}:
  remaining_step_parts(len, pos, limit, before, hl, hu, cursor_step(pos, len, limit, before, hl, hu))

def observed_cons(+fuel: Nat, +src: Tree.Tree<U32>, +pos: U32) ->
  {Buffer.observed(1n+fuel, Bytes.peek(Tree.reify(U32, src), pos), pos) ==
    SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(fuel, Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))} : String}:
  Equal.cong(Array<U32> & U32, String, r => Buffer.observed(1n+fuel, r, pos),
    Bytes.peek(Tree.reify(U32, src), pos), (Tree.reify(U32, src), Packed.peek(src, pos)), Buffer.tree_peek(src, pos))

def observed_lf_tail(+fuel: Nat, +src: Tree.Tree<U32>, +pos: U32, +tail: String,
  same: {Buffer.observed(1n+fuel, Bytes.peek(Tree.reify(U32, src), pos), pos) == SCon{Chr{10}, tail} : String}) ->
  {Packed.peek(src, pos) == 10 : U32} &
    {Buffer.observed(fuel, Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32)) == tail : String}:
  +eq = Equal.trans(String,
    SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(fuel, Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))},
    Buffer.observed(1n+fuel, Bytes.peek(Tree.reify(U32, src), pos), pos), SCon{Chr{10}, tail},
    Equal.sym(String, Buffer.observed(1n+fuel, Bytes.peek(Tree.reify(U32, src), pos), pos),
      SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(fuel, Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))},
      observed_cons(fuel, src, pos)), same)
  (Equal.cong(String, U32, Buffer.observed.head,
    SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(fuel, Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))},
    SCon{Chr{10}, tail}, eq),
    Equal.cong(String, String, Buffer.observed.tail,
      SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(fuel, Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))},
      SCon{Chr{10}, tail}, eq))

def pending_observation(+len: U32, +pos: U32, +src: Tree.Tree<U32>, +tail: String, +limit: Nat,
  before: MNat.lt(U32.to_nat(pos), U32.to_nat(len)), hl: MNat.lt(U32.to_nat(len), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  same: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos) == SCon{Chr{10}, tail} : String}) ->
  {Packed.peek(src, pos) == 10 : U32} &
    {Buffer.observed(U32.to_nat((len - (pos + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32)) == tail : String}:
  observed_lf_tail(U32.to_nat((len - (pos + 1 : U32) : U32)), src, pos, tail,
    (%remaining_step(len, pos, limit, before, hl, hu) :
      {Buffer.observed(_, Bytes.peek(Tree.reify(U32, src), pos), pos) == SCon{Chr{10}, tail} : String}
     same))

def pending_cross_buffer_parts(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +limit: Nat,
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  left_state: Field.state_snapshot(name, text, id, retry, st, limit),
  right_state: Field.state_snapshot(name, text, id, retry, next, limit),
  same: {Buffer.observed(U32.to_nat((len - (s + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, a), (s + 1 : U32)), (s + 1 : U32)) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  certificate: {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, (s + 1 : U32), (s + 1 : U32), False{}, st}) : Sse.Reader & Sse.Next} &
    buffer_valid(len, Tree.reify(U32, a), (s + 1 : U32), (s + 1 : U32), limit)) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, (s + 1 : U32), (s + 1 : U32), False{}, st}) : Sse.Reader & Sse.Next} &
    line_relation(len, other,
      Sse.LMore{Tree.reify(U32, a), (s + 1 : U32), False{}, st},
      Sse.LMore{Tree.reify(U32, b), t, False{}, next}, limit):
  (eq, valid) = certificate
  (eq, more_relation_parts(len, other, a, b, (s + 1 : U32), t, False{}, st, next, (name, text, id, retry), limit,
    same, valid,
    (b, "", restarted_tail(other, b, t), {==}, restarted_buffer(other, b, t, limit, right_shape, hr, to)),
    snapshot_observe(name, text, id, retry, st, limit, hu, left_state),
    snapshot_observe(name, text, id, retry, next, limit, hu, right_state)))

def pending_cross_buffer_observed(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  left_state: Field.state_snapshot(name, text, id, retry, st, limit),
  right_state: Field.state_snapshot(name, text, id, retry, next, limit),
  observed: {Packed.peek(a, s) == 10 : U32} &
    {Buffer.observed(U32.to_nat((len - (s + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, a), (s + 1 : U32)), (s + 1 : U32)) ==
      Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, (s + 1 : U32), (s + 1 : U32), False{}, st}) : Sse.Reader & Sse.Next} &
    line_relation(len, other,
      Sse.LMore{Tree.reify(U32, a), (s + 1 : U32), False{}, st},
      Sse.LMore{Tree.reify(U32, b), t, False{}, next}, limit):
  (lf, same) = observed
  pending_cross_buffer_parts(name, text, id, retry, a, b, len, other, s, t, st, next, limit,
    right_shape, hr, hu, to, left_state, right_state, same,
    pending_restart_valid(len, s, a, st, limit, left_shape, hl, hu, sl, lf))

def pending_cross_buffer(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +limit: Nat,
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  left_state: Field.state_snapshot(name, text, id, retry, st, limit),
  right_state: Field.state_snapshot(name, text, id, retry, next, limit),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    SCon{Chr{10}, Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)} : String}) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, (s + 1 : U32), (s + 1 : U32), False{}, st}) : Sse.Reader & Sse.Next} &
    line_relation(len, other,
      Sse.LMore{Tree.reify(U32, a), (s + 1 : U32), False{}, st},
      Sse.LMore{Tree.reify(U32, b), t, False{}, next}, limit):
  pending_cross_buffer_observed(name, text, id, retry, a, b, len, other, s, t, st, next, limit,
    left_shape, right_shape, hl, hr, hu, sl, to, left_state, right_state,
    pending_observation(len, s, a,
      Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t), limit, sl,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu, same))


