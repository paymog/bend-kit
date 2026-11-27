import Base
import ./sse-packed-proof.bend as P
import ./sse-buffer-proof.bend as Buffer
import ../lemmas/array.bend as Tree
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import ../bytes/append-proof.bend as Packed
import ./sse.bend as Sse
import ./sse-feed-proof.bend as Feed
import ./sse-offset-proof.bend as Offset
import ./sse-window-proof.bend as Window
import ../bytes/bytes.bend as Local
import ../bits/array-proof.bend as Bound
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas

def kind_five_equal(+ea: Bool, +ra: Bool, +eb: Bool, +rb: Bool, pair: {ea == eb : Bool} & {ra == rb : Bool}) ->
  {P.kind_five_value(ea, ra) == P.kind_five_value(eb, rb) : U32}:
  (event, retry) = pair
  %Equal.sym(Bool, ea, eb, event) : {P.kind_five_value(_, ra) == P.kind_five_value(eb, rb) : U32}
  Equal.cong(Bool, U32, b => P.kind_five_value(eb, b), ra, rb, retry)

def guarded_equal(+flag: Bool, +a: U32, +b: U32, +x: U32, +y: U32,
  selected: {flag == True{} : Bool} -> {a == b : U32}, rest: {x == y : U32}) ->
  {Bool.pick(U32, flag, a, x) == Bool.pick(U32, flag, b, y) : U32}:
  match flag:
    case True{}:
      selected({==})
    case False{}:
      rest

def kind_span_scalar(+n: U32, +ia: Bool, +da: Bool, +ea: Bool, +ra: Bool, +ib: Bool, +db: Bool, +eb: Bool, +rb: Bool,
  two: {n == 2 : U32} -> {ia == ib : Bool},
  four: {n == 4 : U32} -> {da == db : Bool},
  five: {n == 5 : U32} -> {ea == eb : Bool} & {ra == rb : Bool}) ->
  {P.kind_value(n, ia, da, ea, ra) == P.kind_value(n, ib, db, eb, rb) : U32}:
  guarded_equal(P.same_u32(n, 2), Bool.pick(U32, ia, 3, 0), Bool.pick(U32, ib, 3, 0),
    Bool.pick(U32, P.same_u32(n, 4), Bool.pick(U32, da, 1, 0), Bool.pick(U32, P.same_u32(n, 5), P.kind_five_value(ea, ra), 0)),
    Bool.pick(U32, P.same_u32(n, 4), Bool.pick(U32, db, 1, 0), Bool.pick(U32, P.same_u32(n, 5), P.kind_five_value(eb, rb), 0)),
    eq => Equal.cong(Bool, U32, b => Bool.pick(U32, b, 3, 0), ia, ib, two(P.same_u32_true(n, 2, eq))),
    guarded_equal(P.same_u32(n, 4), Bool.pick(U32, da, 1, 0), Bool.pick(U32, db, 1, 0),
      Bool.pick(U32, P.same_u32(n, 5), P.kind_five_value(ea, ra), 0), Bool.pick(U32, P.same_u32(n, 5), P.kind_five_value(eb, rb), 0),
      eq => Equal.cong(Bool, U32, b => Bool.pick(U32, b, 1, 0), da, db, four(P.same_u32_true(n, 4, eq))),
      guarded_equal(P.same_u32(n, 5), P.kind_five_value(ea, ra), P.kind_five_value(eb, rb), 0, 0,
        eq => kind_five_equal(ea, ra, eb, rb, five(P.same_u32_true(n, 5, eq))), {==})))

def kind_span_observed(+n: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +j: U32,
  +same: {Buffer.observed(U32.to_nat(n), Bytes.peek(Tree.reify(U32, a), i), i) ==
    Buffer.observed(U32.to_nat(n), Bytes.peek(Tree.reify(U32, b), j), j) : String}) ->
  {P.kind_index(n, a, i) == P.kind_index(n, b, j) : U32}:
  Equal.trans(U32, P.kind_index(n, a, i), P.kind_value(n, P.at_match("id", a, i), P.at_match("data", a, i), P.at_match("event", a, i), P.at_match("retry", a, i)), P.kind_index(n, b, j),
    P.kind_index_result(n, a, i),
    Equal.trans(U32, P.kind_value(n, P.at_match("id", a, i), P.at_match("data", a, i), P.at_match("event", a, i), P.at_match("retry", a, i)),
      P.kind_value(n, P.at_match("id", b, j), P.at_match("data", b, j), P.at_match("event", b, j), P.at_match("retry", b, j)), P.kind_index(n, b, j),
      kind_span_scalar(n, P.at_match("id", a, i), P.at_match("data", a, i), P.at_match("event", a, i), P.at_match("retry", a, i),
        P.at_match("id", b, j), P.at_match("data", b, j), P.at_match("event", b, j), P.at_match("retry", b, j),
        eq => Buffer.at_observed("id", True{}, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j,
          (%eq : {Buffer.observed(U32.to_nat(_), Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(U32.to_nat(_), Bytes.peek(Tree.reify(U32, b), j), j) : String}; same)),
        eq => Buffer.at_observed("data", True{}, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j,
          (%eq : {Buffer.observed(U32.to_nat(_), Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(U32.to_nat(_), Bytes.peek(Tree.reify(U32, b), j), j) : String}; same)),
        +eq => (
          Buffer.at_observed("event", True{}, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j,
            (%eq : {Buffer.observed(U32.to_nat(_), Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(U32.to_nat(_), Bytes.peek(Tree.reify(U32, b), j), j) : String}; same)),
          Buffer.at_observed("retry", True{}, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j,
            (%eq : {Buffer.observed(U32.to_nat(_), Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(U32.to_nat(_), Bytes.peek(Tree.reify(U32, b), j), j) : String}; same)))),
      Equal.sym(U32, P.kind_index(n, b, j), P.kind_value(n, P.at_match("id", b, j), P.at_match("data", b, j), P.at_match("event", b, j), P.at_match("retry", b, j)), P.kind_index_result(n, b, j))))

def kind_span_reads(+name: String, +n: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +j: U32,
  length: {U32.to_nat(n) == String.length(name) : Nat}, ra: Packed.Reads(name, a, i), rb: Packed.Reads(name, b, j)) ->
  {P.kind_index(n, a, i) == P.kind_index(n, b, j) : U32}:
  kind_span_observed(n, a, b, i, j,
    (%Equal.sym(Nat, U32.to_nat(n), String.length(name), length) :
       {Buffer.observed(_, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(_, Bytes.peek(Tree.reify(U32, b), j), j) : String}
     Equal.trans(String, Buffer.observed(String.length(name), Bytes.peek(Tree.reify(U32, a), i), i), name,
       Buffer.observed(String.length(name), Bytes.peek(Tree.reify(U32, b), j), j), P.reads_observed(name, a, i, ra),
       Equal.sym(String, Buffer.observed(String.length(name), Bytes.peek(Tree.reify(U32, b), j), j), name, P.reads_observed(name, b, j, rb)))))

def set_data_snapshot(+old: String, +value: String, +la: U32, +m: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +s: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat}, +eb: {U32.to_nat(m) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(m)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(old, left, 0), snapshot: Offset.copy_snapshot_type(value, len, m, src, s)) ->
  {Feed.state_view(String.length((old ++ value) ++ "\n"),
    Sse.set(1, P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    (name, (old ++ value) ++ "\n", id, retry) : String & String & String & Maybe<&2, U32>}:
  (+out, (eq, reads)) = snapshot
  Equal.trans(String & String & String & Maybe<&2, U32>,
    Feed.state_view(String.length((old ++ value) ++ "\n"),
      Sse.set(1, P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    Feed.state_view(String.length((old ++ value) ++ "\n"),
      Sse.set(1, Bytes.Bytes{m, Tree.reify(U32, out)}, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    (name, (old ++ value) ++ "\n", id, retry),
    Equal.cong(Bytes.Bytes, String & String & String & Maybe<&2, U32>,
      v => Feed.state_view(String.length((old ++ value) ++ "\n"), Sse.set(1, v, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
      P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), Bytes.Bytes{m, Tree.reify(U32, out)}, eq),
    Feed.set_data_observed(old, value, la, m, left, out, limit, name, id, retry, shape, ea, eb, hn, hu, ra, reads))

def set_data_slice_of(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +start: U32, +n: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32)))), 1n), 3n), limit),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, src, U32.min(start, len)),
  bounds: MNat.le(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(len)) &
    MNat.le(Nat.add(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(U32.min(start, len))), U32.to_nat(len))) ->
  {Feed.state_view(String.length((old ++ value) ++ "\n"),
    Sse.set(1, P.slice_second(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, start, n)), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    (name, (old ++ value) ++ "\n", id, retry) : String & String & String & Maybe<&2, U32>}:
  (length, end) = bounds
  +m = U32.min(n, (len - U32.min(start, len) : U32))
  +s = U32.min(start, len)
  set_data_snapshot(old, value, la, m, left, len, src, s, limit, name, id, retry, shape, ea, eb, hn, hu, ra,
    Offset.copy_snapshot(value, len, m, src, s, limit,
      MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), 3n), Nat.add(U32.to_nat(len), 3n), limit, MNat.add_le_add_right(U32.to_nat(m), U32.to_nat(len), 3n, length), hl), hu, eb,
      MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), U32.to_nat(len), limit, end,
        MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)), rb))

def set_data_slice(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +start: U32, +n: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32)))), 1n), 3n), limit),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, src, U32.min(start, len))) ->
  {Feed.state_view(String.length((old ++ value) ++ "\n"),
    Sse.set(1, P.slice_second(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, start, n)), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    (name, (old ++ value) ++ "\n", id, retry) : String & String & String & Maybe<&2, U32>}:
  set_data_slice_of(old, value, la, left, len, src, start, n, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb, Window.slice_bounds(len, start, n))

def field_state(+f: Nat, r: Array<U32> & Sse.St) -> String & String & String & Maybe<&2, U32>:
  (a, st) = r
  Feed.state_view(f, st)

def field_put_view(+f: Nat, +k: U32, -st: Sse.St, r: Bytes.Bytes & Bytes.Bytes) ->
  {field_state(f, Sse.field.put(k, st, r)) == Feed.state_view(f, Sse.set(k, P.slice_second(r), st)) : String & String & String & Maybe<&2, U32>}:
  (Bytes.Bytes{len, a}, value) = r
  {==}

def field_set_data(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +v: U32, +e: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32))) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32)))), 1n), 3n), limit),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, src, U32.min(v, len))) ->
  {field_state(String.length((old ++ value) ++ "\n"),
    Sse.field.set(len, v, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry}, (Tree.reify(U32, src), 1))) ==
    (name, (old ++ value) ++ "\n", id, retry) : String & String & String & Maybe<&2, U32>}:
  Equal.trans(String & String & String & Maybe<&2, U32>,
    field_state(String.length((old ++ value) ++ "\n"), Sse.field.set(len, v, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry}, (Tree.reify(U32, src), 1))),
    Feed.state_view(String.length((old ++ value) ++ "\n"),
      Sse.set(1, P.slice_second(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, v, (e - v : U32))), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    (name, (old ++ value) ++ "\n", id, retry),
    field_put_view(String.length((old ++ value) ++ "\n"), 1, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry}, Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, v, (e - v : U32))),
    set_data_slice(old, value, la, left, len, src, v, (e - v : U32), limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb))

def relocated_width(+delta: Nat, +s: U32, +t: U32, +c: U32, +d: U32,
  hs: MNat.le(U32.to_nat(s), U32.to_nat(c)), ht: MNat.le(U32.to_nat(t), U32.to_nat(d)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, c, d)) ->
  {(c - s : U32) == (d - t : U32) : U32}:
  Lemmas.u32_to_nat_inj((c - s : U32), (d - t : U32),
    Equal.trans(Nat, U32.to_nat((c - s : U32)), Nat.sub(U32.to_nat(c), U32.to_nat(s)), U32.to_nat((d - t : U32)), Lemmas.u32_sub_nat(c, s, hs),
      Equal.trans(Nat, Nat.sub(U32.to_nat(c), U32.to_nat(s)), Nat.sub(Nat.add(delta, U32.to_nat(d)), Nat.add(delta, U32.to_nat(t))), U32.to_nat((d - t : U32)),
        Equal.trans(Nat, Nat.sub(U32.to_nat(c), U32.to_nat(s)), Nat.sub(Nat.add(delta, U32.to_nat(d)), U32.to_nat(s)), Nat.sub(Nat.add(delta, U32.to_nat(d)), Nat.add(delta, U32.to_nat(t))),
          Equal.cong(Nat, Nat, x => Nat.sub(x, U32.to_nat(s)), U32.to_nat(c), Nat.add(delta, U32.to_nat(d)), ends),
          Equal.cong(Nat, Nat, x => Nat.sub(Nat.add(delta, U32.to_nat(d)), x), U32.to_nat(s), Nat.add(delta, U32.to_nat(t)), starts)),
        Equal.trans(Nat, Nat.sub(Nat.add(delta, U32.to_nat(d)), Nat.add(delta, U32.to_nat(t))), Nat.sub(U32.to_nat(d), U32.to_nat(t)), U32.to_nat((d - t : U32)),
          MNat.add_sub_add_left(delta, U32.to_nat(d), U32.to_nat(t)),
          Equal.sym(Nat, U32.to_nat((d - t : U32)), Nat.sub(U32.to_nat(d), U32.to_nat(t)), Lemmas.u32_sub_nat(d, t, ht))))))

def kind_relocated(+name: String, +delta: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +c: U32, +d: U32,
  hs: MNat.le(U32.to_nat(s), U32.to_nat(c)), ht: MNat.le(U32.to_nat(t), U32.to_nat(d)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, c, d),
  length: {U32.to_nat((c - s : U32)) == String.length(name) : Nat},
  ra: Packed.Reads(name, a, s), rb: Packed.Reads(name, b, t)) ->
  {P.kind_index((c - s : U32), a, s) == P.kind_index((d - t : U32), b, t) : U32}:
  Equal.trans(U32, P.kind_index((c - s : U32), a, s), P.kind_index((c - s : U32), b, t), P.kind_index((d - t : U32), b, t),
    kind_span_reads(name, (c - s : U32), a, b, s, t, length, ra, rb),
    Equal.cong(U32, U32, n => P.kind_index(n, b, t), (c - s : U32), (d - t : U32), relocated_width(delta, s, t, c, d, hs, ht, starts, ends)))

def equal_offsets(+delta: Nat, +a: U32, +b: U32, +c: U32, +d: U32,
  first: Offset.offset(delta, a, b), second: Offset.offset(delta, c, d)) ->
  {U32.is_eq(a, c) == U32.is_eq(b, d) : Bool}:
  %Equal.sym(Bool, U32.is_eq(a, c), Nat.is_eq(U32.to_nat(a), U32.to_nat(c)), Lemmas.u32_is_eq_nat(a, c)) : {_ == U32.is_eq(b, d) : Bool}
  %Equal.sym(Nat, U32.to_nat(a), Nat.add(delta, U32.to_nat(b)), first) : {Nat.is_eq(_, U32.to_nat(c)) == U32.is_eq(b, d) : Bool}
  %Equal.sym(Nat, U32.to_nat(c), Nat.add(delta, U32.to_nat(d)), second) : {Nat.is_eq(Nat.add(delta, U32.to_nat(b)), _) == U32.is_eq(b, d) : Bool}
  Equal.trans(Bool, Nat.is_eq(Nat.add(delta, U32.to_nat(b)), Nat.add(delta, U32.to_nat(d))), Nat.is_eq(U32.to_nat(b), U32.to_nat(d)), U32.is_eq(b, d),
    Equal.sym(Bool, Nat.is_eq(U32.to_nat(b), U32.to_nat(d)), Nat.is_eq(Nat.add(delta, U32.to_nat(b)), Nat.add(delta, U32.to_nat(d))), MNat.add_left_cancel_iff(delta, U32.to_nat(b), U32.to_nat(d))),
    Equal.sym(Bool, U32.is_eq(b, d), Nat.is_eq(U32.to_nat(b), U32.to_nat(d)), Lemmas.u32_is_eq_nat(b, d)))

def less_offsets(+delta: Nat, +a: U32, +b: U32, +c: U32, +d: U32,
  first: Offset.offset(delta, a, b), second: Offset.offset(delta, c, d)) ->
  {U32.is_lt(a, c) == U32.is_lt(b, d) : Bool}:
  %Equal.sym(Bool, U32.is_lt(a, c), Nat.is_lt(U32.to_nat(a), U32.to_nat(c)), Lemmas.u32_is_lt_nat(a, c)) : {_ == U32.is_lt(b, d) : Bool}
  %Equal.sym(Nat, U32.to_nat(a), Nat.add(delta, U32.to_nat(b)), first) : {Nat.is_lt(_, U32.to_nat(c)) == U32.is_lt(b, d) : Bool}
  %Equal.sym(Nat, U32.to_nat(c), Nat.add(delta, U32.to_nat(d)), second) : {Nat.is_lt(Nat.add(delta, U32.to_nat(b)), _) == U32.is_lt(b, d) : Bool}
  Equal.trans(Bool, Nat.is_lt(Nat.add(delta, U32.to_nat(b)), Nat.add(delta, U32.to_nat(d))), Nat.is_lt(U32.to_nat(b), U32.to_nat(d)), U32.is_lt(b, d),
    Equal.sym(Bool, Nat.is_lt(U32.to_nat(b), U32.to_nat(d)), Nat.is_lt(Nat.add(delta, U32.to_nat(b)), Nat.add(delta, U32.to_nat(d))), MNat.add_lt_add_iff_left(delta, U32.to_nat(b), U32.to_nat(d))),
    Equal.sym(Bool, U32.is_lt(b, d), Nat.is_lt(U32.to_nat(b), U32.to_nat(d)), Lemmas.u32_is_lt_nat(b, d)))

def add_offset(+delta: Nat, +a: U32, +b: U32, +k: U32, +limit: Nat,
  ha: MNat.lt(Nat.add(U32.to_nat(a), U32.to_nat(k)), limit), hb: MNat.lt(Nat.add(U32.to_nat(b), U32.to_nat(k)), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), here: Offset.offset(delta, a, b)) ->
  Offset.offset(delta, (a + k : U32), (b + k : U32)):
  %Equal.sym(Nat, U32.to_nat((a + k : U32)), Nat.add(U32.to_nat(a), U32.to_nat(k)), Lemmas.u32_add_nat(a, k, MNat.lt_of_lt_of_le(Nat.add(U32.to_nat(a), U32.to_nat(k)), limit, Lemmas.pow2(32n), ha, hu))) :
    {_ == Nat.add(delta, U32.to_nat((b + k : U32))) : Nat}
  %Equal.sym(Nat, U32.to_nat((b + k : U32)), Nat.add(U32.to_nat(b), U32.to_nat(k)), Lemmas.u32_add_nat(b, k, MNat.lt_of_lt_of_le(Nat.add(U32.to_nat(b), U32.to_nat(k)), limit, Lemmas.pow2(32n), hb, hu))) :
    {Nat.add(U32.to_nat(a), U32.to_nat(k)) == Nat.add(delta, _) : Nat}
  %Equal.sym(Nat, U32.to_nat(a), Nat.add(delta, U32.to_nat(b)), here) :
    {Nat.add(_, U32.to_nat(k)) == Nat.add(delta, Nat.add(U32.to_nat(b), U32.to_nat(k))) : Nat}
  MNat.add_assoc(delta, U32.to_nat(b), U32.to_nat(k))

def offset_pick(flag: Bool, +delta: Nat, +a: U32, +b: U32, +c: U32, +d: U32,
  yes: Offset.offset(delta, a, c), no: Offset.offset(delta, b, d)) ->
  Offset.offset(delta, Bool.pick(U32, flag, a, b), Bool.pick(U32, flag, c, d)):
  match flag:
    case True{}:
      yes
    case False{}:
      no

def value_position(+c: U32, +e: U32, +b: U32) -> U32:
  Bool.pick(U32, U32.is_eq(c, e), e,
    Bool.pick(U32, Bool.and(U32.is_lt((c + 1 : U32), e), U32.is_eq(b, 32)), (c + 2 : U32), (c + 1 : U32)))

def value_relocated(+delta: Nat, +c: U32, +d: U32, +e: U32, +f: U32, +b: U32, +limit: Nat,
  hc1: MNat.lt(Nat.add(U32.to_nat(c), 1n), limit), hd1: MNat.lt(Nat.add(U32.to_nat(d), 1n), limit),
  hc2: MNat.lt(Nat.add(U32.to_nat(c), 2n), limit), hd2: MNat.lt(Nat.add(U32.to_nat(d), 2n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +colons: Offset.offset(delta, c, d), +ends: Offset.offset(delta, e, f)) ->
  Offset.offset(delta, value_position(c, e, b), value_position(d, f, b)):
  +one = add_offset(delta, c, d, 1, limit, hc1, hd1, hu, colons)
  +two = add_offset(delta, c, d, 2, limit, hc2, hd2, hu, colons)
  %Equal.sym(Bool, U32.is_eq(c, e), U32.is_eq(d, f), equal_offsets(delta, c, d, e, f, colons, ends)) :
    Offset.offset(delta, Bool.pick(U32, _, e, Bool.pick(U32, Bool.and(U32.is_lt((c + 1 : U32), e), U32.is_eq(b, 32)), (c + 2 : U32), (c + 1 : U32))), value_position(d, f, b))
  %Equal.sym(Bool, U32.is_lt((c + 1 : U32), e), U32.is_lt((d + 1 : U32), f), less_offsets(delta, (c + 1 : U32), (d + 1 : U32), e, f, one, ends)) :
    Offset.offset(delta, Bool.pick(U32, U32.is_eq(d, f), e, Bool.pick(U32, Bool.and(_, U32.is_eq(b, 32)), (c + 2 : U32), (c + 1 : U32))), value_position(d, f, b))
  offset_pick(U32.is_eq(d, f), delta, e,
    Bool.pick(U32, Bool.and(U32.is_lt((d + 1 : U32), f), U32.is_eq(b, 32)), (c + 2 : U32), (c + 1 : U32)), f,
    Bool.pick(U32, Bool.and(U32.is_lt((d + 1 : U32), f), U32.is_eq(b, 32)), (d + 2 : U32), (d + 1 : U32)), ends,
    offset_pick(Bool.and(U32.is_lt((d + 1 : U32), f), U32.is_eq(b, 32)), delta, (c + 2 : U32), (c + 1 : U32), (d + 2 : U32), (d + 1 : U32), two, one))
