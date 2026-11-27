import Base
import ./sse.bend as Sse
import ./LAWS.bend as Laws
import ./sse-field-proof.bend as Field
import ./sse-line-proof.bend as Line
import ./sse-reader-proof.bend as Reader
import ./sse-refinement-proof.bend as Refinement
import ./sse-buffer-proof.bend as Buffer
import ./sse-offset-proof.bend as Offset
import ./sse-feed-proof.bend as Feed
import ../bytes/append-proof.bend as Packed
import ../lemmas/array.bend as Tree
import ../bits/array-proof.bend as Bound
import ../bytes/bytes.bend as Local
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas

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

def line_transport(+len: U32, +other: U32, -left: Sse.Line, -right: Sse.Line,
  -a: Sse.Line, -b: Sse.Line, +limit: Nat,
  ea: {left == a : Sse.Line}, eb: {right == b : Sse.Line},
  cert: line_relation(len, other, a, b, limit)) ->
  line_relation(len, other, left, right, limit):
  %Equal.sym(Sse.Line, left, a, ea) : line_relation(len, other, _, right, limit)
  %Equal.sym(Sse.Line, right, b, eb) : line_relation(len, other, a, _, limit)
  cert

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

