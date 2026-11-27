import Base
import ./sse.bend as Sse
import ./sse-budget-proof.bend as Budget
import ./sse-drain-proof.bend as Drain
import ./sse-scan-proof.bend as Scan
import ./sse-buffer-proof.bend as Buffer
import ./sse-reader-proof.bend as Reader
import ./sse-field-proof.bend as Field
import ./sse-refinement-proof.bend as Refinement
import ./sse-offset-proof.bend as Offset
import ../lemmas/array.bend as Tree
import ../bytes/append-proof.bend as Packed
import ../bytes/bytes.bend as Local
import ../bits/array-proof.bend as Bound
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat

def clean_lf_empty(fuel: Nat, +src: Tree.Tree<U32>, +pos: U32,
  lf: {Packed.peek(src, pos) == 10 : U32},
  clean: Scan.clean_prefix(fuel, Bytes.peek(Tree.reify(U32, src), pos), pos)) -> {fuel == 0n : Nat}:
  match fuel:
    case 0n: {==}
    case 1n+p:
      canonical : Scan.clean_prefix(1n+p, (Tree.reify(U32, src), Packed.peek(src, pos)), pos) = (
        %Buffer.tree_peek(src, pos) :
          Scan.clean_prefix(1n+p, _, pos)
        clean)
      Scan.clean_lf({1n+p == 0n : Nat}, Packed.peek(src, pos), lf)(
        Pair.fst(Scan.clean(Packed.peek(src, pos)), Scan.clean_prefix(p,
          Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32)), canonical))

def seen_lf_equal(+prefix: String, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  lower: MNat.le(U32.to_nat(pos), U32.to_nat(seen)),
  width: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  lf: {Packed.peek(src, pos) == 10 : U32},
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos)) ->
  {seen == pos : U32}:
  +empty = Equal.trans(Nat, Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), String.length(prefix), 0n,
    width, clean_lf_empty(String.length(prefix), src, pos, lf, clean))
  Lemmas.u32_to_nat_inj(seen, pos,
    Equal.trans(Nat, U32.to_nat(seen), Nat.add(Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), U32.to_nat(pos)), U32.to_nat(pos),
      Equal.sym(Nat, Nat.add(Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), U32.to_nat(pos)), U32.to_nat(seen),
        MNat.sub_add_cancel(U32.to_nat(seen), U32.to_nat(pos), lower)),
      Equal.cong(Nat, Nat, n => Nat.add(n, U32.to_nat(pos)), Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), 0n, empty)))

def pending_valid_restart(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  -st: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  +before: MNat.lt(U32.to_nat(pos), U32.to_nat(len)),
  +lf: {Packed.peek(src, pos) == 10 : U32},
  valid: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, True{}, st}) ==
    Sse.next.at(len, (pos + 1 : U32), st, (Tree.reify(U32, src), (pos + 1 : U32), False{})) : Sse.Reader & Sse.Next}:
  (shape, +hl, lower, upper, width, length, reads, clean) = valid
  %Equal.sym(U32, seen, pos, seen_lf_equal(prefix, src, pos, seen, lower, width, lf, clean)) :
    {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, _, True{}, st}) ==
      Sse.next.at(len, (pos + 1 : U32), st, (Tree.reify(U32, src), (pos + 1 : U32), False{})) : Sse.Reader & Sse.Next}
  Drain.next_pending_restart(len, pos, src, st,
    Equal.trans(Bool, U32.is_lt(pos, len), Nat.is_lt(U32.to_nat(pos), U32.to_nat(len)), True{}, Lemmas.u32_is_lt_nat(pos, len), before), lf,
    Pair.fst(MNat.le(U32.to_nat(pos), U32.to_nat((pos + 1 : U32))), MNat.le(U32.to_nat((pos + 1 : U32)), U32.to_nat(len)),
      Drain.cursor_step(pos, len, limit, before,
        MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu)))

def pending_seen_refines_observed(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +left_prefix: String, +left_tail: String, +right_prefix: String, +right_tail: String,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)),
  starts: Offset.offset(delta, (s + 1 : U32), t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left_buffer: Reader.valid_buffer(left_prefix, left_tail, len, a, s, seen, limit),
  right_buffer: Reader.valid_buffer(right_prefix, right_tail, other, b, t, other_seen, limit),
  observation: {Packed.peek(a, s) == 10 : U32} &
    {Buffer.observed(U32.to_nat((len - (s + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, a), (s + 1 : U32)), (s + 1 : U32)) ==
      Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, False{}, next}), limit):
  (left_shape, +hl, lower, upper, width, length, reads, clean) = left_buffer
  (right_shape, +hr, +right_lower, +right_upper, right_width, right_length, right_reads, right_clean) = right_buffer
  (+lf, same) = observation
  %Equal.sym(U32, seen, s, seen_lf_equal(left_prefix, a, s, seen, lower, width, lf, clean)) :
    Budget.next_certificate(len, other,
      Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, _, True{}, st}),
      Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, False{}, next}), limit)
  Budget.next_transport(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, False{}, next}),
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, False{}, next}), limit,
    {==}, Budget.next_at_restart(right_prefix, other, b, t, other_seen, False{}, next, limit,
      hr, hu, right_lower, right_upper, right_width, right_clean),
    Budget.pending_next_refines_observed(old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit,
      hl, hr, hu, sl, MNat.le_trans(U32.to_nat(t), U32.to_nat(other_seen), U32.to_nat(other), right_lower, right_upper),
      starts, ends, hn, left_shape, right_shape, left_state, right_state,
      Drain.cursor_step(s, len, limit, sl,
        MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu),
      (lf, same)))

def byte_eq(+a: U32, +b: U32, eq: {U32.is_eq(a, b) == True{} : Bool}) -> {a == b : U32}:
  Lemmas.u32_to_nat_inj(a, b,
    MNat.eq_of_is_eq(U32.to_nat(a), U32.to_nat(b),
      Equal.trans(Bool, Nat.is_eq(U32.to_nat(a), U32.to_nat(b)), U32.is_eq(a, b), True{},
        Equal.sym(Bool, U32.is_eq(a, b), Nat.is_eq(U32.to_nat(a), U32.to_nat(b)), Lemmas.u32_is_eq_nat(a, b)), eq)))

def restart_type(+len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St) -> Type:
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}) ==
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, cr, st}) : Sse.Reader & Sse.Next}

def restart_pending_byte(lf: Bool, +prefix: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  -st: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit),
  +lower: MNat.le(U32.to_nat(pos), U32.to_nat(seen)), upper: MNat.le(U32.to_nat(seen), U32.to_nat(len)),
  width: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos),
  +available: {U32.is_lt(pos, len) == True{} : Bool},
  +selected: {U32.is_eq(Packed.peek(src, pos), 10) == lf : Bool}) -> restart_type(len, src, pos, seen, True{}, st):
  match lf:
    case True{}:
      %Equal.sym(U32, seen, pos,
        seen_lf_equal(prefix, src, pos, seen, lower, width, byte_eq(Packed.peek(src, pos), 10, selected), clean)) :
        restart_type(len, src, pos, _, True{}, st)
      {==}
    case False{}:
      Equal.trans(Sse.Reader & Sse.Next,
        Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, True{}, st}),
        Sse.next.at(len, seen, st, (Tree.reify(U32, src), pos, False{})),
        Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}),
        Drain.next_pending_non_lf(len, pos, seen, src, st, available, selected),
        Equal.trans(Sse.Reader & Sse.Next,
          Sse.next.at(len, seen, st, (Tree.reify(U32, src), pos, False{})),
          Sse.next.at(len, pos, st, (Tree.reify(U32, src), pos, False{})),
          Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}),
          Budget.next_at_restart(prefix, len, src, pos, seen, False{}, st, limit, hl, hu, lower, upper, width, clean),
          Equal.sym(Sse.Reader & Sse.Next,
            Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}),
            Sse.next.at(len, pos, st, (Tree.reify(U32, src), pos, False{})),
            Drain.next_pending_non_lf(len, pos, pos, src, st, available, selected))))

def restart_pending_available(available: Bool, +prefix: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  -st: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit),
  lower: MNat.le(U32.to_nat(pos), U32.to_nat(seen)), upper: MNat.le(U32.to_nat(seen), U32.to_nat(len)),
  width: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos),
  selected: {U32.is_lt(pos, len) == available : Bool}) -> restart_type(len, src, pos, seen, True{}, st):
  match available:
    case True{}:
      restart_pending_byte(U32.is_eq(Packed.peek(src, pos), 10), prefix, len, src, pos, seen, st, limit,
        hu, hl, lower, upper, width, clean, selected, {==})
    case False{}:
      %Equal.sym(Bool, U32.is_lt(pos, len), False{}, selected) :
        {Sse.next.at(len, seen, st, Sse.skip.at(_, Tree.reify(U32, src), pos)) ==
          Sse.next.at(len, pos, st, Sse.skip.at(_, Tree.reify(U32, src), pos)) : Sse.Reader & Sse.Next}
      Budget.next_at_restart(prefix, len, src, pos, seen, True{}, st, limit, hl, hu, lower, upper, width, clean)

def next_restart(cr: Bool, +prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32,
  -st: Sse.St, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)),
  valid: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) -> restart_type(len, src, pos, seen, cr, st):
  match cr:
    case False{}:
      (shape, hl, lower, upper, width, length, reads, clean) = valid
      Budget.next_at_restart(prefix, len, src, pos, seen, False{}, st, limit, hl, hu, lower, upper, width, clean)
    case True{}:
      (shape, hl, lower, upper, width, length, reads, clean) = valid
      restart_pending_available(U32.is_lt(pos, len), prefix, len, src, pos, seen, st, limit,
        hu, hl, lower, upper, width, clean, {==})

def observed_width(+text: String, +src: Tree.Tree<U32>, +pos: U32, +len: U32,
  observation: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos) == text : String}) ->
  {U32.to_nat((len - pos : U32)) == String.length(text) : Nat}:
  Equal.trans(Nat, U32.to_nat((len - pos : U32)),
    String.length(Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos)), String.length(text),
    Equal.sym(Nat, String.length(Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos)),
      U32.to_nat((len - pos : U32)), Reader.observed_length(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos)),
    Equal.cong(String, Nat, String.length,
      Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos), text, observation))

def width_sum(+pos: U32, +len: U32, +width: Nat,
  +lower: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  eq: {U32.to_nat((len - pos : U32)) == width : Nat}) ->
  {Nat.add(width, U32.to_nat(pos)) == U32.to_nat(len) : Nat}:
  Equal.trans(Nat, Nat.add(width, U32.to_nat(pos)), Nat.add(Nat.sub(U32.to_nat(len), U32.to_nat(pos)), U32.to_nat(pos)), U32.to_nat(len),
    Equal.cong(Nat, Nat, n => Nat.add(n, U32.to_nat(pos)), width, Nat.sub(U32.to_nat(len), U32.to_nat(pos)),
      Equal.trans(Nat, width, U32.to_nat((len - pos : U32)), Nat.sub(U32.to_nat(len), U32.to_nat(pos)),
        Equal.sym(Nat, U32.to_nat((len - pos : U32)), width, eq), Lemmas.u32_sub_nat(len, pos, lower))),
    MNat.sub_add_cancel(U32.to_nat(len), U32.to_nat(pos), lower))

def nonempty_available(+pos: U32, +len: U32, +width: Nat,
  lower: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  eq: {U32.to_nat((len - pos : U32)) == 1n+width : Nat}) -> MNat.lt(U32.to_nat(pos), U32.to_nat(len)):
  %width_sum(pos, len, 1n+width, lower, eq) : MNat.lt(U32.to_nat(pos), _)
  MNat.lt_add_of_pos_left(U32.to_nat(pos), width)

def empty_position(+pos: U32, +len: U32,
  lower: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  eq: {U32.to_nat((len - pos : U32)) == 0n : Nat}) -> {pos == len : U32}:
  Lemmas.u32_to_nat_inj(pos, len, width_sum(pos, len, 0n, lower, eq))

def observed_cons_parts(+tail: String, +c: U32, +src: Tree.Tree<U32>, +pos: U32, +len: U32,
  +width: {U32.to_nat((len - pos : U32)) == 1n+String.length(tail) : Nat},
  same: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos) == SCon{Chr{c}, tail} : String}) ->
  {Packed.peek(src, pos) == c : U32} &
    {Buffer.observed(String.length(tail), Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32)) == tail : String}:
  +eq = Equal.trans(String,
    SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(String.length(tail), Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))},
    Buffer.observed(1n+String.length(tail), Bytes.peek(Tree.reify(U32, src), pos), pos), SCon{Chr{c}, tail},
    Equal.sym(String, Buffer.observed(1n+String.length(tail), Bytes.peek(Tree.reify(U32, src), pos), pos),
      SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(String.length(tail), Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))},
      Drain.observed_cons(String.length(tail), src, pos)),
    (%width : {Buffer.observed(_, Bytes.peek(Tree.reify(U32, src), pos), pos) == SCon{Chr{c}, tail} : String}; same))
  (Equal.cong(String, U32, Buffer.observed.head,
    SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(String.length(tail), Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))},
    SCon{Chr{c}, tail}, eq),
    Equal.cong(String, String, Buffer.observed.tail,
      SCon{Chr{Packed.peek(src, pos)}, Buffer.observed(String.length(tail), Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32))},
      SCon{Chr{c}, tail}, eq))

def next_empty_pending(+len: U32, +pos: U32, +src: Tree.Tree<U32>, -st: Sse.St,
  eq: {pos == len : U32}) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}) ==
    Sse.next.at(len, pos, st, (Tree.reify(U32, src), pos, True{})) : Sse.Reader & Sse.Next}:
  %Equal.sym(U32, pos, len, eq) :
    {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, _, _, True{}, st}) ==
      Sse.next.at(len, _, st, (Tree.reify(U32, src), _, True{})) : Sse.Reader & Sse.Next}
  %Equal.sym(Bool, U32.is_lt(len, len), False{},
    Equal.trans(Bool, U32.is_lt(len, len), Nat.is_lt(U32.to_nat(len), U32.to_nat(len)), False{},
      Lemmas.u32_is_lt_nat(len, len), MNat.not_lt_of_le(U32.to_nat(len), U32.to_nat(len), MNat.le_refl(U32.to_nat(len))))) :
    {Sse.next.at(len, len, st, Sse.skip.at(_, Tree.reify(U32, src), len)) ==
      Sse.next.at(len, len, st, (Tree.reify(U32, src), len, True{})) : Sse.Reader & Sse.Next}
  {==}

def pending_non_lf_pair(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), +to: MNat.lt(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  not_lf_left: {U32.is_eq(Packed.peek(a, s), 10) == False{} : Bool},
  not_lf_right: {U32.is_eq(Packed.peek(b, t), 10) == False{} : Bool},
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}), limit):
  Budget.next_transport(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}),
    Sse.next.at(len, s, st, (Tree.reify(U32, a), s, False{})),
    Sse.next.at(other, t, next, (Tree.reify(U32, b), t, False{})), limit,
    Drain.next_pending_non_lf(len, s, s, a, st,
      Equal.trans(Bool, U32.is_lt(s, len), Nat.is_lt(U32.to_nat(s), U32.to_nat(len)), True{}, Lemmas.u32_is_lt_nat(s, len), sl), not_lf_left),
    Drain.next_pending_non_lf(other, t, t, b, next,
      Equal.trans(Bool, U32.is_lt(t, other), Nat.is_lt(U32.to_nat(t), U32.to_nat(other)), True{}, Lemmas.u32_is_lt_nat(t, other), to), not_lf_right),
    Budget.next_at_refines(old, name, id, retry, a, b, len, other, s, t, False{}, st, next, delta, limit,
      hl, hr, hu, MNat.le_of_lt(U32.to_nat(s), U32.to_nat(len), sl), MNat.le_of_lt(U32.to_nat(t), U32.to_nat(other), to),
      starts, ends, hn, left_shape, right_shape, left_state, right_state, same))


def pending_restart_at(+len: U32, +pos: U32, +u: U32, +src: Tree.Tree<U32>, -st: Sse.St,
  available: {U32.is_lt(pos, len) == True{} : Bool}, lf: {Packed.peek(src, pos) == 10 : U32},
  before: MNat.le(U32.to_nat(pos), U32.to_nat((pos + 1 : U32))), eq: {(pos + 1 : U32) == u : U32}) ->
  {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}) ==
    Sse.next.at(len, u, st, (Tree.reify(U32, src), u, False{})) : Sse.Reader & Sse.Next}:
  %eq : {Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, pos, True{}, st}) ==
    Sse.next.at(len, _, st, (Tree.reify(U32, src), _, False{})) : Sse.Reader & Sse.Next}
  Drain.next_pending_restart(len, pos, src, st, available, lf, before)

def pending_seen_refines(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +left_prefix: String, +left_tail: String, +right_prefix: String, +right_tail: String,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)),
  starts: Offset.offset(delta, (s + 1 : U32), t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left_buffer: Reader.valid_buffer(left_prefix, left_tail, len, a, s, seen, limit),
  right_buffer: Reader.valid_buffer(right_prefix, right_tail, other, b, t, other_seen, limit),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    SCon{Chr{10}, Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t)} : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, False{}, next}), limit):
  pending_seen_refines_observed(old, name, id, retry, a, b, len, other, s, t, seen, other_seen,
    st, next, delta, limit, left_prefix, left_tail, right_prefix, right_tail, hu, sl, starts, ends, hn,
    left_state, right_state, left_buffer, right_buffer,
    Drain.pending_observation(len, s, a, Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t),
      limit, sl, MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu, same))

def pending_empty_pair(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  +left_empty: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) == SNil{} : String},
  +right_empty: {Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) == SNil{} : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}), limit):
  Budget.next_transport(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}),
    Sse.next.at(len, s, st, (Tree.reify(U32, a), s, True{})),
    Sse.next.at(other, t, next, (Tree.reify(U32, b), t, True{})), limit,
    next_empty_pending(len, s, a, st, empty_position(s, len, sl, observed_width("", a, s, len, left_empty))),
    next_empty_pending(other, t, b, next, empty_position(t, other, to, observed_width("", b, t, other, right_empty))),
    Budget.next_at_refines(old, name, id, retry, a, b, len, other, s, t, True{}, st, next, delta, limit,
      hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, left_state, right_state,
      Equal.trans(String, Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s), "",
        Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t),
        left_empty, Equal.sym(String, Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t), "", right_empty))))

def pending_lf_pair_observed(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), +to: MNat.lt(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  bounds: MNat.le(U32.to_nat(s), U32.to_nat((s + 1 : U32))) & MNat.le(U32.to_nat((s + 1 : U32)), U32.to_nat(len)),
  right_bounds: MNat.le(U32.to_nat(t), U32.to_nat((t + 1 : U32))) & MNat.le(U32.to_nat((t + 1 : U32)), U32.to_nat(other)),
  lf: {Packed.peek(a, s) == 10 : U32}, right_lf: {Packed.peek(b, t) == 10 : U32},
  same: {Buffer.observed(U32.to_nat((len - (s + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, a), (s + 1 : U32)), (s + 1 : U32)) ==
    Buffer.observed(U32.to_nat((other - (t + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, b), (t + 1 : U32)), (t + 1 : U32)) : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}), limit):
  (+lower, +upper) = bounds
  (other_lower, other_upper) = right_bounds
  Budget.next_transport(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}),
    Sse.next.at(len, (s + 1 : U32), st, (Tree.reify(U32, a), (s + 1 : U32), False{})),
    Sse.next.at(other, (t + 1 : U32), next, (Tree.reify(U32, b), (t + 1 : U32), False{})), limit,
    Drain.next_pending_restart(len, s, a, st,
      Equal.trans(Bool, U32.is_lt(s, len), Nat.is_lt(U32.to_nat(s), U32.to_nat(len)), True{}, Lemmas.u32_is_lt_nat(s, len), sl), lf, lower),
    Drain.next_pending_restart(other, t, b, next,
      Equal.trans(Bool, U32.is_lt(t, other), Nat.is_lt(U32.to_nat(t), U32.to_nat(other)), True{}, Lemmas.u32_is_lt_nat(t, other), to), right_lf, other_lower),
    Budget.next_at_refines(old, name, id, retry, a, b, len, other, (s + 1 : U32), (t + 1 : U32), False{}, st, next, delta, limit,
      hl, hr, hu, upper, other_upper,
      Offset.increment(delta, s, t, limit,
        MNat.lt_of_le_of_lt(1n+U32.to_nat(s), U32.to_nat(len), limit, MNat.succ_le_of_lt(U32.to_nat(s), U32.to_nat(len), sl),
          MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)),
        MNat.lt_of_le_of_lt(1n+U32.to_nat(t), U32.to_nat(other), limit, MNat.succ_le_of_lt(U32.to_nat(t), U32.to_nat(other), to),
          MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr)), hu, starts),
      ends, Refinement.accumulation_bound(String.length(old), U32.to_nat((len - (s + 1 : U32) : U32)), U32.to_nat((len - s : U32)), limit,
        Refinement.suffix_length_le(s, (s + 1 : U32), len, lower, upper), hn),
      left_shape, right_shape, left_state, right_state, same))

def pending_lf_pair_parts(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +tail: String,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), +to: MNat.lt(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left: {Packed.peek(a, s) == 10 : U32} &
    {Buffer.observed(U32.to_nat((len - (s + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, a), (s + 1 : U32)), (s + 1 : U32)) == tail : String},
  right: {Packed.peek(b, t) == 10 : U32} &
    {Buffer.observed(U32.to_nat((other - (t + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, b), (t + 1 : U32)), (t + 1 : U32)) == tail : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}), limit):
  (lf, reads) = left
  (right_lf, right_reads) = right
  pending_lf_pair_observed(old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit,
    hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, left_state, right_state,
    Drain.cursor_step(s, len, limit, sl,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu),
    Drain.cursor_step(t, other, limit, to,
      MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr), hu),
    lf, right_lf, Equal.trans(String,
      Buffer.observed(U32.to_nat((len - (s + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, a), (s + 1 : U32)), (s + 1 : U32)), tail,
      Buffer.observed(U32.to_nat((other - (t + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, b), (t + 1 : U32)), (t + 1 : U32)),
      reads, Equal.sym(String,
        Buffer.observed(U32.to_nat((other - (t + 1 : U32) : U32)), Bytes.peek(Tree.reify(U32, b), (t + 1 : U32)), (t + 1 : U32)), tail, right_reads)))

def pending_lf_pair(+old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +tail: String,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), +to: MNat.lt(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) == SCon{Chr{10}, tail} : String},
  right: {Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) == SCon{Chr{10}, tail} : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}), limit):
  pending_lf_pair_parts(old, name, id, retry, a, b, len, other, s, t, tail, st, next, delta, limit,
    hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, left_state, right_state,
    Drain.pending_observation(len, s, a, tail, limit, sl,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl), hu, left),
    Drain.pending_observation(other, t, b, tail, limit, to,
      MNat.lt_of_le_of_lt(U32.to_nat(other), Nat.add(U32.to_nat(other), 3n), limit, MNat.le_add_right(U32.to_nat(other), 3n), hr), hu, right))

def non_lf_parts(+tail: String, +c: U32, +src: Tree.Tree<U32>, +pos: U32,
  not_lf: {U32.is_eq(c, 10) == False{} : Bool},
  parts: {Packed.peek(src, pos) == c : U32} &
    {Buffer.observed(String.length(tail), Bytes.peek(Tree.reify(U32, src), (pos + 1 : U32)), (pos + 1 : U32)) == tail : String}) ->
  {U32.is_eq(Packed.peek(src, pos), 10) == False{} : Bool}:
  (head, rest) = parts
  Equal.trans(Bool, U32.is_eq(Packed.peek(src, pos), 10), U32.is_eq(c, 10), False{},
    Equal.cong(U32, Bool, x => U32.is_eq(x, 10), Packed.peek(src, pos), c, head), not_lf)

def non_lf_observed(+tail: String, +c: U32, +src: Tree.Tree<U32>, +pos: U32, +len: U32,
  not_lf: {U32.is_eq(c, 10) == False{} : Bool},
  width: {U32.to_nat((len - pos : U32)) == 1n+String.length(tail) : Nat},
  reads: {Buffer.observed(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos) == SCon{Chr{c}, tail} : String}) ->
  {U32.is_eq(Packed.peek(src, pos), 10) == False{} : Bool}:
  non_lf_parts(tail, c, src, pos, not_lf, observed_cons_parts(tail, c, src, pos, len, width, reads))

def pending_byte_pair(lf: Bool, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32, +c: U32, +tail: String,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.lt(U32.to_nat(s), U32.to_nat(len)), +to: MNat.lt(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  +left: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) == SCon{Chr{c}, tail} : String},
  +right: {Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) == SCon{Chr{c}, tail} : String},
  +selected: {U32.is_eq(c, 10) == lf : Bool}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}), limit):
  match lf:
    case True{}:
      pending_lf_pair(old, name, id, retry, a, b, len, other, s, t, tail, st, next, delta, limit,
        hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, left_state, right_state,
        (%byte_eq(c, 10, selected) : {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) == SCon{Chr{_}, tail} : String}; left),
        (%byte_eq(c, 10, selected) : {Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) == SCon{Chr{_}, tail} : String}; right))
    case False{}:
      pending_non_lf_pair(old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit,
        hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, left_state, right_state,
        non_lf_observed(tail, c, a, s, len, selected, observed_width(SCon{Chr{c}, tail}, a, s, len, left), left),
        non_lf_observed(tail, c, b, t, other, selected, observed_width(SCon{Chr{c}, tail}, b, t, other, right), right),
        Equal.trans(String, Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s), SCon{Chr{c}, tail},
          Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t),
          left, Equal.sym(String, Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t), SCon{Chr{c}, tail}, right)))

def pending_text_pair(text: String, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hr: MNat.lt(Nat.add(U32.to_nat(other), 3n), limit),
  hu: MNat.le(limit, Lemmas.pow2(32n)),
  +sl: MNat.le(U32.to_nat(s), U32.to_nat(len)), +to: MNat.le(U32.to_nat(t), U32.to_nat(other)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(a)),
  right_shape: Bound.shape(Local.depth(Local.words(other)), Packed.as_bits(b)),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  +left: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) == text : String},
  +right: {Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) == text : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}), limit):
  match text:
    case SNil{}:
      pending_empty_pair(old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit,
        hl, hr, hu, sl, to, starts, ends, hn, left_shape, right_shape, left_state, right_state, left, right)
    case SCon{Chr{+c}, +tail}:
      pending_byte_pair(U32.is_eq(c, 10), old, name, id, retry, a, b, len, other, s, t, c, tail, st, next, delta, limit,
        hl, hr, hu,
        nonempty_available(s, len, String.length(tail), sl, observed_width(SCon{Chr{c}, tail}, a, s, len, left)),
        nonempty_available(t, other, String.length(tail), to, observed_width(SCon{Chr{c}, tail}, b, t, other, right)),
        starts, ends, hn, left_shape, right_shape, left_state, right_state, left, right, {==})

def next_refines(cr: Bool, +text: String, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>,
  +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32, +s: U32, +t: U32,
  +seen: U32, +other_seen: U32, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +left_prefix: String, +left_tail: String, +right_prefix: String, +right_tail: String,
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, len, other),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit),
  left_state: Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit),
  left_buffer: Reader.valid_buffer(left_prefix, left_tail, len, a, s, seen, limit),
  right_buffer: Reader.valid_buffer(right_prefix, right_tail, other, b, t, other_seen, limit),
  left: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) == text : String},
  right: {Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) == text : String}) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, cr, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, cr, next}), limit):
  match cr:
    case False{}:
      Budget.next_at_seen_refines(old, name, id, retry, a, b, len, other, s, t, seen, other_seen, False{}, st, next, delta, limit,
        left_prefix, left_tail, right_prefix, right_tail, hu, starts, ends, hn, left_state, right_state, left_buffer, right_buffer,
        Equal.trans(String, Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s), text,
          Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t),
          left, Equal.sym(String, Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t), text, right)))
    case True{}:
      (left_shape, +hl, +lower, +upper, prefix_length, tail_length, reads, clean) = left_buffer
      (right_shape, +hr, +other_lower, +other_upper, other_prefix_length, other_tail_length, other_reads, other_clean) = right_buffer
      Budget.next_transport(len, other,
        Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, seen, True{}, st}),
        Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, other_seen, True{}, next}),
        Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, True{}, st}),
        Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, True{}, next}), limit,
        restart_pending_available(U32.is_lt(s, len), left_prefix, len, a, s, seen, st, limit,
          hu, hl, lower, upper, prefix_length, clean, {==}),
        restart_pending_available(U32.is_lt(t, other), right_prefix, other, b, t, other_seen, next, limit,
          hu, hr, other_lower, other_upper, other_prefix_length, other_clean, {==}),
        pending_text_pair(text, old, name, id, retry, a, b, len, other, s, t, st, next, delta, limit, hl, hr, hu,
          MNat.le_trans(U32.to_nat(s), U32.to_nat(seen), U32.to_nat(len), lower, upper),
          MNat.le_trans(U32.to_nat(t), U32.to_nat(other_seen), U32.to_nat(other), other_lower, other_upper),
          starts, ends, hn, left_shape, right_shape, left_state, right_state, left, right))

def next_ready_copies(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +left_prefix: String, +left_tail: String, +right_prefix: String, +right_tail: String,
  +name: String, +old: String, +id: String, +retry: Maybe<&2, U32>,
  hu: MNat.le(limit, Lemmas.pow2(32n)), +ends: Offset.offset(delta, len, other),
  reserved: Budget.line_reserved(len, Sse.LMore{Tree.reify(U32, a), s, cr, st}, limit),
  left_buffer: Reader.valid_buffer(left_prefix, left_tail, len, a, s, s, limit),
  right_buffer: Reader.valid_buffer(right_prefix, right_tail, other, b, t, t, limit),
  +same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  states: Field.state_snapshot(name, old, id, retry, st, limit) & Field.state_snapshot(name, old, id, retry, st, limit),
  right_state: Field.state_snapshot(name, old, id, retry, next, limit)) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, cr, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, cr, next}), limit):
  (shape, hl, +lower, +upper, width, length, reads, clean) = left_buffer
  (other_shape, hr, +other_lower, +other_upper, other_width, other_length, other_reads, other_clean) = right_buffer
  (bound_state, left_state) = states
  (+data_len, +data, +eq, data_shape, +data_length, data_bound, data_reads) = bound_state
  hn : MNat.lt(Nat.add(Nat.add(Nat.add(String.length(old), U32.to_nat((len - s : U32))), 1n), 3n), limit) = (
    %Equal.trans(Nat, Budget.state_size(st), U32.to_nat(data_len), String.length(old),
      Equal.cong(Sse.St, Nat, Budget.state_size, st, Sse.St{name, Bytes.Bytes{data_len, Tree.reify(U32, data)}, id, retry}, eq), data_length) :
      MNat.lt(Nat.add(Nat.add(Nat.add(_, U32.to_nat((len - s : U32))), 1n), 3n), limit)
    reserved)
  next_refines(cr, Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s), old, name, id, retry,
    a, b, len, other, s, t, s, t, st, next, delta, limit, left_prefix, left_tail, right_prefix, right_tail, hu,
    Budget.offsets_from_widths(s, t, len, other, delta, upper, other_upper, ends, Budget.observed_widths(a, b, len, other, s, t, same)), ends,
    hn,
    left_state, right_state,
    (shape, hl, lower, upper, width, length, reads, clean),
    (other_shape, hr, other_lower, other_upper, other_width, other_length, other_reads, other_clean),
    {==}, Equal.sym(String,
      Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s),
      Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t), same))

def next_ready_states(+a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +len: U32, +other: U32,
  +s: U32, +t: U32, +cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +left_prefix: String, +left_tail: String, +right_prefix: String, +right_tail: String,
  hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  reserved: Budget.line_reserved(len, Sse.LMore{Tree.reify(U32, a), s, cr, st}, limit),
  left_buffer: Reader.valid_buffer(left_prefix, left_tail, len, a, s, s, limit),
  right_buffer: Reader.valid_buffer(right_prefix, right_tail, other, b, t, t, limit),
  same: {Buffer.observed(U32.to_nat((len - s : U32)), Bytes.peek(Tree.reify(U32, a), s), s) ==
    Buffer.observed(U32.to_nat((other - t : U32)), Bytes.peek(Tree.reify(U32, b), t), t) : String},
  states: Budget.common_states(st, next, limit)) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, a)}, s, s, cr, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, Tree.reify(U32, b)}, t, t, cr, next}), limit):
  (+name, +old, +id, +retry, left_state, right_state) = states
  next_ready_copies(a, b, len, other, s, t, cr, st, next, delta, limit, left_prefix, left_tail, right_prefix, right_tail,
    name, old, id, retry, hu, ends, reserved, left_buffer, right_buffer, same,
    Budget.snapshot_copy(old, name, id, retry, st, limit, left_state), right_state)

def next_ready(+len: U32, +other: U32, -a: Array<U32>, -b: Array<U32>,
  +s: U32, +t: U32, +cr: Bool, +other_cr: Bool, -st: Sse.St, -next: Sse.St, +delta: Nat, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), ends: Offset.offset(delta, len, other),
  reserved: Budget.line_reserved(len, Sse.LMore{a, s, cr, st}, limit),
  relation: Drain.line_relation(len, other, Sse.LMore{a, s, cr, st}, Sse.LMore{b, t, other_cr, next}, limit)) ->
  Budget.next_certificate(len, other,
    Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}),
    Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, other_cr, next}), limit):
  (+views, ((+src, +prefix, +tail, +ea, left_buffer), left_state),
    ((+dst, +other_prefix, +other_tail, +eb, right_buffer), right_state)) = relation
  %Equal.cong(Budget.view_type(), Bool, Budget.view_cr,
    Drain.line_view(len, Sse.LMore{a, s, cr, st}), Drain.line_view(other, Sse.LMore{b, t, other_cr, next}), views) :
    Budget.next_certificate(len, other, Sse.next(Sse.Reader{Bytes.Bytes{len, a}, s, s, cr, st}),
      Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, _, next}), limit)
  %Equal.sym(Array<U32>, a, Tree.reify(U32, src), ea) :
    Budget.next_certificate(len, other, Sse.next(Sse.Reader{Bytes.Bytes{len, _}, s, s, cr, st}),
      Sse.next(Sse.Reader{Bytes.Bytes{other, b}, t, t, cr, next}), limit)
  %Equal.sym(Array<U32>, b, Tree.reify(U32, dst), eb) :
    Budget.next_certificate(len, other, Sse.next(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, s, s, cr, st}),
      Sse.next(Sse.Reader{Bytes.Bytes{other, _}, t, t, cr, next}), limit)
  next_ready_states(src, dst, len, other, s, t, cr, st, next, delta, limit, prefix, tail, other_prefix, other_tail, hu, ends,
    (%ea : Budget.line_reserved(len, Sse.LMore{_, s, cr, st}, limit); reserved),
    left_buffer, right_buffer,
    Budget.paired_observations(src, dst, a, b, len, other, s, t, ea, eb,
      Equal.cong(Budget.view_type(), String, Budget.view_tail,
        Drain.line_view(len, Sse.LMore{a, s, cr, st}), Drain.line_view(other, Sse.LMore{b, t, other_cr, next}), views)),
    Budget.common_states_valid(st, next, limit, hu,
      Equal.cong(Budget.view_type(), String & String & String & Maybe<&2, U32>, Budget.view_state,
        Drain.line_view(len, Sse.LMore{a, s, cr, st}), Drain.line_view(other, Sse.LMore{b, t, other_cr, next}), views),
      left_state, right_state))
