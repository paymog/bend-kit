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
import ./sse-reader-proof.bend as Reader
import bend-mathlib@0.8.0.0/bool.bend as MBool

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

def kind_pair(+n: U32, +src: Tree.Tree<U32>, +s: U32) ->
  {Sse.kind(n, Tree.reify(U32, src), s) == (Tree.reify(U32, src), P.kind_index(n, src, s)) : Array<U32> & U32}:
  Equal.trans(Array<U32> & U32, Sse.kind(n, Tree.reify(U32, src), s),
    (Tree.reify(U32, src), P.kind_value(n, P.at_match("id", src, s), P.at_match("data", src, s), P.at_match("event", src, s), P.at_match("retry", src, s))),
    (Tree.reify(U32, src), P.kind_index(n, src, s)), P.kind_result(n, src, s),
    Equal.cong(U32, Array<U32> & U32, k => (Tree.reify(U32, src), k),
      P.kind_value(n, P.at_match("id", src, s), P.at_match("data", src, s), P.at_match("event", src, s), P.at_match("retry", src, s)), P.kind_index(n, src, s),
      Equal.sym(U32, P.kind_index(n, src, s), P.kind_value(n, P.at_match("id", src, s), P.at_match("data", src, s), P.at_match("event", src, s), P.at_match("retry", src, s)), P.kind_index_result(n, src, s))))

def colon_index(+f: Nat, +src: Tree.Tree<U32>, +s: U32) -> U32:
  Buffer.index(Sse.colon(f, Bytes.peek(Tree.reify(U32, src), s), s))

def colon_pair(+f: Nat, +src: Tree.Tree<U32>, +s: U32) ->
  {Sse.colon(f, Bytes.peek(Tree.reify(U32, src), s), s) == (Tree.reify(U32, src), colon_index(f, src, s)) : Array<U32> & U32}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), s), (Tree.reify(U32, src), Packed.peek(src, s)), Buffer.tree_peek(src, s)) :
    {Sse.colon(f, _, s) == (Tree.reify(U32, src), Buffer.index(Sse.colon(f, _, s))) : Array<U32> & U32}
  Buffer.colon_buffer(f, src, Packed.peek(src, s), s)

def field_set_pair(+len: U32, +src: Tree.Tree<U32>, +v: U32, +e: U32, +k: U32, -st: Sse.St) ->
  {Sse.field.set(len, v, e, st, (Tree.reify(U32, src), k)) ==
    (Tree.reify(U32, src), Sse.set(k, P.slice_second(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, v, (e - v : U32))), st)) : Array<U32> & Sse.St}:
  %Equal.sym(Bytes.Bytes & Bytes.Bytes,
    Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, v, (e - v : U32)),
    (Bytes.Bytes{len, Tree.reify(U32, src)}, Bytes.Bytes{U32.min((e - v : U32), (len - U32.min(v, len) : U32)),
      Tree.reify(U32, Packed.copy(U32.min((e - v : U32), (len - U32.min(v, len) : U32)), src,
        Packed.alloc(U32.min((e - v : U32), (len - U32.min(v, len) : U32))), U32.min(v, len), 0))}),
    P.slice_at_bridge(len, src, U32.min(v, len), U32.min((e - v : U32), (len - U32.min(v, len) : U32)))) :
    {Sse.field.put(k, st, _) == (Tree.reify(U32, src), Sse.set(k, P.slice_second(_), st)) : Array<U32> & Sse.St}
  {==}

def field_value(+len: U32, +src: Tree.Tree<U32>, +v: U32, +e: U32) -> Bytes.Bytes:
  P.slice_second(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, v, (e - v : U32)))

def field_at_pair(+s: U32, +c: U32, +e: U32, +len: U32, +src: Tree.Tree<U32>, +b: U32, -st: Sse.St) ->
  {Sse.field.at(s, c, e, len, st, (Tree.reify(U32, src), b)) ==
    (Tree.reify(U32, src), Sse.set(P.kind_index((c - s : U32), src, s), field_value(len, src, value_position(c, e, b), e), st)) : Array<U32> & Sse.St}:
  Equal.trans(Array<U32> & Sse.St,
    Sse.field.at(s, c, e, len, st, (Tree.reify(U32, src), b)),
    Sse.field.set(len, value_position(c, e, b), e, st, (Tree.reify(U32, src), P.kind_index((c - s : U32), src, s))),
    (Tree.reify(U32, src), Sse.set(P.kind_index((c - s : U32), src, s), field_value(len, src, value_position(c, e, b), e), st)),
    Equal.cong(Array<U32> & U32, Array<U32> & Sse.St, r => Sse.field.set(len, value_position(c, e, b), e, st, r),
      Sse.kind((c - s : U32), Tree.reify(U32, src), s), (Tree.reify(U32, src), P.kind_index((c - s : U32), src, s)), kind_pair((c - s : U32), src, s)),
    field_set_pair(len, src, value_position(c, e, b), e, P.kind_index((c - s : U32), src, s), st))

def field_colon_pair(+s: U32, +c: U32, +e: U32, +len: U32, +src: Tree.Tree<U32>, -st: Sse.St) ->
  {Sse.field.colon(s, e, len, st, (Tree.reify(U32, src), c)) ==
    (Tree.reify(U32, src), Sse.set(P.kind_index((c - s : U32), src, s),
      field_value(len, src, value_position(c, e, Packed.peek(src, (c + 1 : U32))), e), st)) : Array<U32> & Sse.St}:
  Equal.trans(Array<U32> & Sse.St, Sse.field.colon(s, e, len, st, (Tree.reify(U32, src), c)),
    Sse.field.at(s, c, e, len, st, (Tree.reify(U32, src), Packed.peek(src, (c + 1 : U32)))),
    (Tree.reify(U32, src), Sse.set(P.kind_index((c - s : U32), src, s),
      field_value(len, src, value_position(c, e, Packed.peek(src, (c + 1 : U32))), e), st)),
    Equal.cong(Array<U32> & U32, Array<U32> & Sse.St, r => Sse.field.at(s, c, e, len, st, r),
      Bytes.peek(Tree.reify(U32, src), (c + 1 : U32)), (Tree.reify(U32, src), Packed.peek(src, (c + 1 : U32))), Buffer.tree_peek(src, (c + 1 : U32))),
    field_at_pair(s, c, e, len, src, Packed.peek(src, (c + 1 : U32)), st))

def field_state_result(+len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, st: Sse.St) -> Sse.St:
  +c = colon_index(U32.to_nat((e - s : U32)), src, s)
  Sse.set(P.kind_index((c - s : U32), src, s), field_value(len, src, value_position(c, e, Packed.peek(src, (c + 1 : U32))), e), st)

def field_pair(+len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, -st: Sse.St) ->
  {Sse.field(Tree.reify(U32, src), len, s, e, st) == (Tree.reify(U32, src), field_state_result(len, src, s, e, st)) : Array<U32> & Sse.St}:
  +c = colon_index(U32.to_nat((e - s : U32)), src, s)
  Equal.trans(Array<U32> & Sse.St, Sse.field(Tree.reify(U32, src), len, s, e, st),
    Sse.field.colon(s, e, len, st, (Tree.reify(U32, src), c)), (Tree.reify(U32, src), field_state_result(len, src, s, e, st)),
    Equal.cong(Array<U32> & U32, Array<U32> & Sse.St, r => Sse.field.colon(s, e, len, st, r),
      Sse.colon(U32.to_nat((e - s : U32)), Bytes.peek(Tree.reify(U32, src), s), s), (Tree.reify(U32, src), c),
      colon_pair(U32.to_nat((e - s : U32)), src, s)),
    field_colon_pair(s, c, e, len, src, st))

def scan_span(+f: Nat, +s: U32, +c: U32) -> Type:
  MNat.le(U32.to_nat(s), U32.to_nat(c)) &
  MNat.le(U32.to_nat(c), Nat.add(f, U32.to_nat(s)))

def scan_span_here(+f: Nat, +s: U32) -> scan_span(f, s, s):
  (MNat.le_refl(U32.to_nat(s)), MNat.le_add_left(U32.to_nat(s), f))

def scan_span_step_of(+p: Nat, +s: U32, +c: U32, +eq: {U32.to_nat((s + 1 : U32)) == 1n+U32.to_nat(s) : Nat},
  span: scan_span(p, (s + 1 : U32), c)) -> scan_span(1n+p, s, c):
  (lower, upper) = span
  (MNat.le_trans(U32.to_nat(s), U32.to_nat((s + 1 : U32)), U32.to_nat(c),
    (%Equal.sym(Nat, U32.to_nat((s + 1 : U32)), 1n+U32.to_nat(s), eq) : MNat.le(U32.to_nat(s), _)
     MNat.le_succ(U32.to_nat(s))), lower),
    (%MNat.add_succ(p, U32.to_nat(s)) : MNat.le(U32.to_nat(c), _)
     %eq : MNat.le(U32.to_nat(c), Nat.add(p, _))
     upper))

def scan_span_step(+p: Nat, +s: U32, +c: U32, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), hn: MNat.lt(Nat.add(1n+p, U32.to_nat(s)), limit),
  span: scan_span(p, (s + 1 : U32), c)) -> scan_span(1n+p, s, c):
  scan_span_step_of(p, s, c,
    Packed.add_one_nat(s, MNat.lt_of_lt_of_le(1n+U32.to_nat(s), limit, Lemmas.pow2(32n), Offset.increment_bound(p, s, limit, hn), hu)), span)

def colon_bounds(f: Nat, +src: Tree.Tree<U32>, +c: U32, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(f, U32.to_nat(s)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  scan_span(f, s, Buffer.index(Sse.colon(f, (Tree.reify(U32, src), c), s))):
  match f:
    case 0n:
      scan_span_here(0n, s)
    case 1n+ +p:
      Buffer.colon_elim(x => scan_span(1n+p, s, Buffer.index(x)), p, Tree.reify(U32, src), c, s,
        eq => scan_span_here(1n+p, s),
        good => (
          %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), (s + 1 : U32)),
            (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), Buffer.tree_peek(src, (s + 1 : U32))) :
            scan_span(1n+p, s, Buffer.index(Sse.colon(p, _, (s + 1 : U32))))
          scan_span_step(p, s, Buffer.index(Sse.colon(p, (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), (s + 1 : U32))), limit, hu, hn,
            colon_bounds(p, src, Packed.peek(src, (s + 1 : U32)), (s + 1 : U32), limit, Offset.tail_bound(p, s, limit, hu, hn), hu))))

def data_tree(+la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>) -> Tree.Tree<U32>:
  Packed.append((la + lb : U32), Packed.append(la, left, lb, right), 1, Packed.from_string("\n"))

def data_bridge(+la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>) ->
  {Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), Sse.lf()) ==
    Bytes.Bytes{((la + lb : U32) + 1 : U32), Tree.reify(U32, data_tree(la, left, lb, right))} : Bytes.Bytes}:
  +first = Packed.append(la, left, lb, right)
  Equal.trans(Bytes.Bytes,
    Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), Sse.lf()),
    Bytes.append(Bytes.Bytes{(la + lb : U32), Tree.reify(U32, first)}, Bytes.Bytes{1, Tree.reify(U32, Packed.from_string("\n"))}),
    Bytes.Bytes{((la + lb : U32) + 1 : U32), Tree.reify(U32, data_tree(la, left, lb, right))},
    Equal.trans(Bytes.Bytes,
      Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), Sse.lf()),
      Bytes.append(Bytes.Bytes{(la + lb : U32), Tree.reify(U32, first)}, Sse.lf()),
      Bytes.append(Bytes.Bytes{(la + lb : U32), Tree.reify(U32, first)}, Bytes.Bytes{1, Tree.reify(U32, Packed.from_string("\n"))}),
      Equal.cong(Bytes.Bytes, Bytes.Bytes, b => Bytes.append(b, Sse.lf()),
        Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
        Bytes.Bytes{(la + lb : U32), Tree.reify(U32, first)}, P.append_bridge(la, left, lb, right)),
      Equal.cong(Bytes.Bytes, Bytes.Bytes, b => Bytes.append(Bytes.Bytes{(la + lb : U32), Tree.reify(U32, first)}, b),
        Sse.lf(), Bytes.Bytes{1, Tree.reify(U32, Packed.from_string("\n"))}, P.from_bridge("\n"))),
    P.append_bridge((la + lb : U32), first, 1, Packed.from_string("\n")))

def data_valid(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat) -> Type:
  Bound.shape(Local.depth(Local.words(((la + lb : U32) + 1 : U32))), Packed.as_bits(data_tree(la, left, lb, right))) &
  {U32.to_nat(((la + lb : U32) + 1 : U32)) == String.length((old ++ value) ++ "\n") : Nat} &
  MNat.lt(Nat.add(U32.to_nat(((la + lb : U32) + 1 : U32)), 3n), limit) &
  Packed.Reads((old ++ value) ++ "\n", data_tree(la, left, lb, right), 0)

def data_valid_of(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +ea: {U32.to_nat(la) == String.length(old) : Nat}, +eb: {U32.to_nat(lb) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, right, 0),
  ha: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  shapes: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)) & Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left))) ->
  data_valid(old, value, la, left, lb, right, limit):
  (hb, hc) = shapes
  +sum = Nat.add(U32.to_nat(la), U32.to_nat(lb))
  +hpair = MNat.lt_of_le_of_lt(Nat.add(sum, 3n), Nat.add(Nat.add(sum, 1n), 3n), limit,
    MNat.add_le_add_right(sum, Nat.add(sum, 1n), 3n, MNat.le_add_right(sum, 1n)), hn)
  +hfirst = Feed.left_bound(la, lb, limit, hpair)
  +en = Reader.sum_nat(la, lb, limit, hpair, hu)
  +n = (la + lb : U32)
  +hm : MNat.lt(Nat.add(Nat.add(U32.to_nat(n), 1n), 3n), limit) = (
    %Equal.sym(Nat, U32.to_nat(n), sum, en) : MNat.lt(Nat.add(Nat.add(_, 1n), 3n), limit)
    hn)
  +last = Reader.sum_nat(n, 1, limit, hm, hu)
  (Reader.appended_shape(n, 1, Packed.append(la, left, lb, right), Packed.from_string("\n"), limit,
      Reader.appended_shape(la, lb, left, right, limit, ha, hpair, hu), hm, hu),
    Feed.sum_length(old ++ value, "\n", n, 1, last, Feed.sum_length(old, value, la, lb, en, ea, eb), {==}),
    (%Equal.sym(Nat, U32.to_nat((n + 1 : U32)), Nat.add(U32.to_nat(n), 1n), last) : MNat.lt(Nat.add(_, 3n), limit); hm),
    Packed.append.reads(old ++ value, "\n", n, 1, Packed.append(la, left, lb, right), Packed.from_string("\n"), limit,
      Reader.appended_shape(la, lb, left, right, limit, hb, hpair, hu),
      Packed.allocation_depth(n, Packed.alloc_capacity(n, limit, Feed.left_bound(n, 1, limit, hm), hu)),
      Feed.sum_length(old, value, la, lb, en, ea, eb), {==}, hm, hu,
      Packed.append.reads(old, value, la, lb, left, right, limit,
        hc,
        Packed.allocation_depth(la, Packed.alloc_capacity(la, limit, hfirst, hu)), ea, eb, hpair, hu, ra, rb),
      Packed.canonical_reads("\n", "", limit, Feed.lf_bound(sum, limit, hn), hu)))

def data_valid_split(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +ea: {U32.to_nat(la) == String.length(old) : Nat}, +eb: {U32.to_nat(lb) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, right, 0),
  shapes: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)) & Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left))) ->
  data_valid(old, value, la, left, lb, right, limit):
  (ha, hb) = shapes
  data_valid_of(old, value, la, left, lb, right, limit, ea, eb, hn, hu, ra, rb, ha,
    Bound.shape_copy(Local.depth(Local.words(la)), Packed.as_bits(left), hb))

def data_valid_build(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +ea: {U32.to_nat(la) == String.length(old) : Nat}, +eb: {U32.to_nat(lb) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, right, 0),
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left))) ->
  data_valid(old, value, la, left, lb, right, limit):
  data_valid_split(old, value, la, left, lb, right, limit, ea, eb, hn, hu, ra, rb,
    Bound.shape_copy(Local.depth(Local.words(la)), Packed.as_bits(left), shape))

def text_data(view: String & String & String & Maybe<&2, U32>) -> String:
  (name, data, id, retry) = view
  data

# Keep field cases finite: https://github.com/bendlang/bend/issues/1071.
type FieldKind is Data:
  KData{}
  KEvent{}
  KId{}
  KRetry{}
  KOther{}

def kind_code(k: FieldKind) -> U32:
  match k:
    case KData{}: 1
    case KEvent{}: 2
    case KId{}: 3
    case KRetry{}: 4
    case KOther{}: 0

def text_set(+k: FieldKind, +value: String, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>) ->
  String & String & String & Maybe<&2, U32>:
  match k:
    case KData{}:
      (name, (old ++ value) ++ "\n", id, retry)
    case KEvent{}:
      (value, old, id, retry)
    case KId{}:
      (name, old, Bool.pick(String, Sse.has_nul(value), id, value), retry)
    case KRetry{}:
      (name, old, id, Sse.set.retry(Sse.digits(value, 0, 0, False{}), retry))
    case KOther{}:
      (name, old, id, retry)

def packed_string(+value: String, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  eb: {U32.to_nat(lb) == String.length(value) : Nat}, hu: MNat.le(limit, Lemmas.pow2(32n)),
  end: MNat.lt(Nat.add(String.length(value), 0n), limit), rb: Packed.Reads(value, right, 0)) ->
  {Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}) == value : String}:
  Equal.trans(String, Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), Packed.to_string(lb, right), value,
    P.to_bridge(lb, right), Packed.reads_to(value, right, lb, limit, eb, hu, end, rb))

def data_value_bound(+la: U32, +lb: U32, +limit: Nat,
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit)) ->
  MNat.lt(Nat.add(U32.to_nat(lb), 0n), limit):
  %Equal.sym(Nat, Nat.add(U32.to_nat(lb), 0n), U32.to_nat(lb), MNat.add_zero(U32.to_nat(lb))) : MNat.lt(_, limit)
  MNat.lt_of_le_of_lt(U32.to_nat(lb), Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit,
    MNat.le_trans(U32.to_nat(lb), Nat.add(U32.to_nat(la), U32.to_nat(lb)), Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n),
      MNat.le_add_left(U32.to_nat(lb), U32.to_nat(la)),
      MNat.le_trans(Nat.add(U32.to_nat(la), U32.to_nat(lb)), Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n),
        MNat.le_add_right(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), MNat.le_add_right(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n))), hn)

def data_value_string(+value: String, +la: U32, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +eb: {U32.to_nat(lb) == String.length(value) : Nat}, hu: MNat.le(limit, Lemmas.pow2(32n)),
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit), rb: Packed.Reads(value, right, 0)) ->
  {Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}) == value : String}:
  packed_string(value, lb, right, limit, eb, hu,
    (%eb : MNat.lt(Nat.add(_, 0n), limit)
     data_value_bound(la, lb, limit, hn)), rb)

def set_observed(+k: FieldKind, +old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat}, +eb: {U32.to_nat(lb) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, right, 0)) ->
  {Feed.state_view(String.length(text_data(text_set(k, value, old, name, id, retry))),
    Sse.set(kind_code(k), Bytes.Bytes{lb, Tree.reify(U32, right)}, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    text_set(k, value, old, name, id, retry) : String & String & String & Maybe<&2, U32>}:
  match k:
    case KData{}:
      Feed.set_data_observed(old, value, la, lb, left, right, limit, name, id, retry, shape, ea, eb, hn, hu, ra, rb)
    case KEvent{}:
      %Equal.sym(String, P.observe(String.length(old), Bytes.Bytes{la, Tree.reify(U32, left)}, 0), old, P.reads_observed(old, left, 0, ra)) :
        {(Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), _, id, retry) == (value, old, id, retry) : String & String & String & Maybe<&2, U32>}
      Equal.cong(String, String & String & String & Maybe<&2, U32>, s => (s, old, id, retry),
        Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), value,
        data_value_string(value, la, lb, right, limit, eb, hu, hn, rb))
    case KId{}:
      %Equal.sym(String, P.observe(String.length(old), Bytes.Bytes{la, Tree.reify(U32, left)}, 0), old, P.reads_observed(old, left, 0, ra)) :
        {(name, _, Bool.pick(String, Sse.has_nul(Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)})), id, Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)})), retry) ==
          (name, old, Bool.pick(String, Sse.has_nul(value), id, value), retry) : String & String & String & Maybe<&2, U32>}
      Equal.cong(String, String & String & String & Maybe<&2, U32>, +s => (name, old, Bool.pick(String, Sse.has_nul(s), id, s), retry),
        Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), value, data_value_string(value, la, lb, right, limit, eb, hu, hn, rb))
    case KRetry{}:
      %Equal.sym(String, P.observe(String.length(old), Bytes.Bytes{la, Tree.reify(U32, left)}, 0), old, P.reads_observed(old, left, 0, ra)) :
        {(name, _, id, Sse.set.retry(Sse.digits(Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), 0, 0, False{}), retry)) ==
          (name, old, id, Sse.set.retry(Sse.digits(value, 0, 0, False{}), retry)) : String & String & String & Maybe<&2, U32>}
      Equal.cong(String, String & String & String & Maybe<&2, U32>, s => (name, old, id, Sse.set.retry(Sse.digits(s, 0, 0, False{}), retry)),
        Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), value, data_value_string(value, la, lb, right, limit, eb, hu, hn, rb))
    case KOther{}:
      Equal.cong(String, String & String & String & Maybe<&2, U32>, s => (name, s, id, retry),
        P.observe(String.length(old), Bytes.Bytes{la, Tree.reify(U32, left)}, 0), old, P.reads_observed(old, left, 0, ra))

def kind_five_tag(event: Bool, retry: Bool) -> FieldKind:
  match event:
    case True{}: KEvent{}
    case False{}: Bool.pick(FieldKind, retry, KRetry{}, KOther{})

def kind_tag(+n: U32, id: Bool, data: Bool, event: Bool, retry: Bool) -> FieldKind:
  Bool.pick(FieldKind, P.same_u32(n, 2), Bool.pick(FieldKind, id, KId{}, KOther{}),
    Bool.pick(FieldKind, P.same_u32(n, 4), Bool.pick(FieldKind, data, KData{}, KOther{}),
      Bool.pick(FieldKind, P.same_u32(n, 5), kind_five_tag(event, retry), KOther{})))

def code_pick_equal(flag: Bool, +a: FieldKind, +b: FieldKind, +x: U32, +y: U32,
  yes: {kind_code(a) == x : U32}, no: {kind_code(b) == y : U32}) ->
  {kind_code(Bool.pick(FieldKind, flag, a, b)) == Bool.pick(U32, flag, x, y) : U32}:
  match flag:
    case True{}: yes
    case False{}: no

def kind_five_code(event: Bool, +retry: Bool) ->
  {kind_code(kind_five_tag(event, retry)) == P.kind_five_value(event, retry) : U32}:
  match event:
    case True{}: {==}
    case False{}:
      code_pick_equal(retry, KRetry{}, KOther{}, 4, 0, {==}, {==})

def kind_tag_code(+n: U32, +id: Bool, +data: Bool, +event: Bool, +retry: Bool) ->
  {kind_code(kind_tag(n, id, data, event, retry)) == P.kind_value(n, id, data, event, retry) : U32}:
  code_pick_equal(P.same_u32(n, 2), Bool.pick(FieldKind, id, KId{}, KOther{}),
    Bool.pick(FieldKind, P.same_u32(n, 4), Bool.pick(FieldKind, data, KData{}, KOther{}),
      Bool.pick(FieldKind, P.same_u32(n, 5), kind_five_tag(event, retry), KOther{})),
    Bool.pick(U32, id, 3, 0),
    Bool.pick(U32, P.same_u32(n, 4), Bool.pick(U32, data, 1, 0), Bool.pick(U32, P.same_u32(n, 5), P.kind_five_value(event, retry), 0)),
    code_pick_equal(id, KId{}, KOther{}, 3, 0, {==}, {==}),
    code_pick_equal(P.same_u32(n, 4), Bool.pick(FieldKind, data, KData{}, KOther{}),
      Bool.pick(FieldKind, P.same_u32(n, 5), kind_five_tag(event, retry), KOther{}),
      Bool.pick(U32, data, 1, 0), Bool.pick(U32, P.same_u32(n, 5), P.kind_five_value(event, retry), 0),
      code_pick_equal(data, KData{}, KOther{}, 1, 0, {==}, {==}),
      code_pick_equal(P.same_u32(n, 5), kind_five_tag(event, retry), KOther{}, P.kind_five_value(event, retry), 0,
        kind_five_code(event, retry), {==})))

def classify(+n: U32, +src: Tree.Tree<U32>, +s: U32) -> FieldKind:
  kind_tag(n, P.at_match("id", src, s), P.at_match("data", src, s), P.at_match("event", src, s), P.at_match("retry", src, s))

def classify_code(+n: U32, +src: Tree.Tree<U32>, +s: U32) ->
  {kind_code(classify(n, src, s)) == P.kind_index(n, src, s) : U32}:
  Equal.trans(U32, kind_code(classify(n, src, s)),
    P.kind_value(n, P.at_match("id", src, s), P.at_match("data", src, s), P.at_match("event", src, s), P.at_match("retry", src, s)),
    P.kind_index(n, src, s), kind_tag_code(n, P.at_match("id", src, s), P.at_match("data", src, s), P.at_match("event", src, s), P.at_match("retry", src, s)),
    Equal.sym(U32, P.kind_index(n, src, s), P.kind_value(n, P.at_match("id", src, s), P.at_match("data", src, s), P.at_match("event", src, s), P.at_match("retry", src, s)), P.kind_index_result(n, src, s)))

def set_slice_snapshot(+k: FieldKind, +old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +m: U32, +src: Tree.Tree<U32>, +s: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat}, +eb: {U32.to_nat(m) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(m)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(old, left, 0), snapshot: Offset.copy_snapshot_type(value, len, m, src, s)) ->
  {Feed.state_view(String.length(text_data(text_set(k, value, old, name, id, retry))),
    Sse.set(kind_code(k), P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    text_set(k, value, old, name, id, retry) : String & String & String & Maybe<&2, U32>}:
  (+out, (eq, reads)) = snapshot
  Equal.trans(String & String & String & Maybe<&2, U32>,
    Feed.state_view(String.length(text_data(text_set(k, value, old, name, id, retry))),
      Sse.set(kind_code(k), P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    Feed.state_view(String.length(text_data(text_set(k, value, old, name, id, retry))),
      Sse.set(kind_code(k), Bytes.Bytes{m, Tree.reify(U32, out)}, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    text_set(k, value, old, name, id, retry),
    Equal.cong(Bytes.Bytes, String & String & String & Maybe<&2, U32>,
      v => Feed.state_view(String.length(text_data(text_set(k, value, old, name, id, retry))), Sse.set(kind_code(k), v, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
      P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), Bytes.Bytes{m, Tree.reify(U32, out)}, eq),
    set_observed(k, old, value, la, left, m, out, limit, name, id, retry, shape, ea, eb, hn, hu, ra, reads))

def set_slice_observed_of(+k: FieldKind, +old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +v: U32, +e: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32))) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32)))), 1n), 3n), limit),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, src, U32.min(v, len)),
  bounds: MNat.le(U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32))), U32.to_nat(len)) &
    MNat.le(Nat.add(U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32))), U32.to_nat(U32.min(v, len))), U32.to_nat(len))) ->
  {Feed.state_view(String.length(text_data(text_set(k, value, old, name, id, retry))),
    Sse.set(kind_code(k), field_value(len, src, v, e), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    text_set(k, value, old, name, id, retry) : String & String & String & Maybe<&2, U32>}:
  (length, end) = bounds
  +m = U32.min((e - v : U32), (len - U32.min(v, len) : U32))
  +s = U32.min(v, len)
  set_slice_snapshot(k, old, value, la, left, len, m, src, s, limit, name, id, retry, shape, ea, eb, hn, hu, ra,
    Offset.copy_snapshot(value, len, m, src, s, limit,
      MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), 3n), Nat.add(U32.to_nat(len), 3n), limit, MNat.add_le_add_right(U32.to_nat(m), U32.to_nat(len), 3n, length), hl), hu, eb,
      MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), U32.to_nat(len), limit, end,
        MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)), rb))

def set_slice_observed(+k: FieldKind, +old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +v: U32, +e: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32))) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32)))), 1n), 3n), limit),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, src, U32.min(v, len))) ->
  {Feed.state_view(String.length(text_data(text_set(k, value, old, name, id, retry))),
    Sse.set(kind_code(k), field_value(len, src, v, e), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    text_set(k, value, old, name, id, retry) : String & String & String & Maybe<&2, U32>}:
  set_slice_observed_of(k, old, value, la, left, len, src, v, e, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb, Window.slice_bounds(len, v, (e - v : U32)))

def decode_kind(+code: U32) -> FieldKind:
  match code:
    case 1: KData{}
    case 2: KEvent{}
    case 3: KId{}
    case 4: KRetry{}
    case _: KOther{}

def decode_code(k: FieldKind) -> {decode_kind(kind_code(k)) == k : FieldKind}:
  match k:
    case KData{}: {==}
    case KEvent{}: {==}
    case KId{}: {==}
    case KRetry{}: {==}
    case KOther{}: {==}

def code_injective(+a: FieldKind, +b: FieldKind, same: {kind_code(a) == kind_code(b) : U32}) -> {a == b : FieldKind}:
  Equal.trans(FieldKind, a, decode_kind(kind_code(a)), b,
    Equal.sym(FieldKind, decode_kind(kind_code(a)), a, decode_code(a)),
    Equal.trans(FieldKind, decode_kind(kind_code(a)), decode_kind(kind_code(b)), b,
      Equal.cong(U32, FieldKind, x => decode_kind(x), kind_code(a), kind_code(b), same), decode_code(b)))

def field_start(+src: Tree.Tree<U32>, +s: U32, +e: U32) -> U32:
  +c = colon_index(U32.to_nat((e - s : U32)), src, s)
  value_position(c, e, Packed.peek(src, (c + 1 : U32)))

def field_kind(+src: Tree.Tree<U32>, +s: U32, +e: U32) -> FieldKind:
  +c = colon_index(U32.to_nat((e - s : U32)), src, s)
  classify((c - s : U32), src, s)

def field_text(+src: Tree.Tree<U32>, +s: U32, +e: U32, +value: String, +old: String, +name: String, +id: String, +retry: Maybe<&2, U32>) ->
  String & String & String & Maybe<&2, U32>:
  text_set(field_kind(src, s, e), value, old, name, id, retry)

def field_observed(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat(U32.min((e - field_start(src, s, e) : U32), (len - U32.min(field_start(src, s, e), len) : U32))) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(U32.min((e - field_start(src, s, e) : U32), (len - U32.min(field_start(src, s, e), len) : U32)))), 1n), 3n), limit),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, src, U32.min(field_start(src, s, e), len))) ->
  {field_state(String.length(text_data(field_text(src, s, e, value, old, name, id, retry))),
    Sse.field(Tree.reify(U32, src), len, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    field_text(src, s, e, value, old, name, id, retry) : String & String & String & Maybe<&2, U32>}:
  +c = colon_index(U32.to_nat((e - s : U32)), src, s)
  +v = field_start(src, s, e)
  +k = field_kind(src, s, e)
  +f = String.length(text_data(text_set(k, value, old, name, id, retry)))
  Equal.trans(String & String & String & Maybe<&2, U32>,
    field_state(f, Sse.field(Tree.reify(U32, src), len, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    Feed.state_view(f, Sse.set(P.kind_index((c - s : U32), src, s), field_value(len, src, v, e), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    text_set(k, value, old, name, id, retry),
    Equal.cong(Array<U32> & Sse.St, String & String & String & Maybe<&2, U32>, r => field_state(f, r),
      Sse.field(Tree.reify(U32, src), len, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry}),
      (Tree.reify(U32, src), field_state_result(len, src, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
      field_pair(len, src, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    (%classify_code((c - s : U32), src, s) :
      {Feed.state_view(f, Sse.set(_, field_value(len, src, v, e), Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) == text_set(k, value, old, name, id, retry) : String & String & String & Maybe<&2, U32>}
     set_slice_observed(k, old, value, la, left, len, src, v, e, limit, name, id, retry, shape, hl, hu, ea, eb, hn, ra, rb)))

def classify_relocated(+name: String, +delta: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +s: U32, +t: U32, +c: U32, +d: U32,
  hs: MNat.le(U32.to_nat(s), U32.to_nat(c)), ht: MNat.le(U32.to_nat(t), U32.to_nat(d)),
  starts: Offset.offset(delta, s, t), ends: Offset.offset(delta, c, d),
  length: {U32.to_nat((c - s : U32)) == String.length(name) : Nat},
  ra: Packed.Reads(name, a, s), rb: Packed.Reads(name, b, t)) ->
  {classify((c - s : U32), a, s) == classify((d - t : U32), b, t) : FieldKind}:
  code_injective(classify((c - s : U32), a, s), classify((d - t : U32), b, t),
    Equal.trans(U32, kind_code(classify((c - s : U32), a, s)), P.kind_index((c - s : U32), a, s), kind_code(classify((d - t : U32), b, t)),
      classify_code((c - s : U32), a, s),
      Equal.trans(U32, P.kind_index((c - s : U32), a, s), P.kind_index((d - t : U32), b, t), kind_code(classify((d - t : U32), b, t)),
        kind_relocated(name, delta, a, b, s, t, c, d, hs, ht, starts, ends, length, ra, rb),
        Equal.sym(U32, kind_code(classify((d - t : U32), b, t)), P.kind_index((d - t : U32), b, t), classify_code((d - t : U32), b, t)))))

def span_end(+s: U32, +e: U32, +hs: MNat.le(U32.to_nat(s), U32.to_nat(e))) ->
  {Nat.add(U32.to_nat((e - s : U32)), U32.to_nat(s)) == U32.to_nat(e) : Nat}:
  Equal.trans(Nat, Nat.add(U32.to_nat((e - s : U32)), U32.to_nat(s)), Nat.add(Nat.sub(U32.to_nat(e), U32.to_nat(s)), U32.to_nat(s)), U32.to_nat(e),
    Equal.cong(Nat, Nat, x => Nat.add(x, U32.to_nat(s)), U32.to_nat((e - s : U32)), Nat.sub(U32.to_nat(e), U32.to_nat(s)), Lemmas.u32_sub_nat(e, s, hs)),
    MNat.sub_add_cancel(U32.to_nat(e), U32.to_nat(s), hs))

def field_colon_bounds(+src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  +hs: MNat.le(U32.to_nat(s), U32.to_nat(e)), he: MNat.lt(U32.to_nat(e), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(U32.to_nat(s), U32.to_nat(colon_index(U32.to_nat((e - s : U32)), src, s))) &
  MNat.le(U32.to_nat(colon_index(U32.to_nat((e - s : U32)), src, s)), U32.to_nat(e)):
  %span_end(s, e, hs) :
    (MNat.le(U32.to_nat(s), U32.to_nat(colon_index(U32.to_nat((e - s : U32)), src, s))) &
      MNat.le(U32.to_nat(colon_index(U32.to_nat((e - s : U32)), src, s)), _))
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), s), (Tree.reify(U32, src), Packed.peek(src, s)), Buffer.tree_peek(src, s)) :
    scan_span(U32.to_nat((e - s : U32)), s, Buffer.index(Sse.colon(U32.to_nat((e - s : U32)), _, s)))
  colon_bounds(U32.to_nat((e - s : U32)), src, Packed.peek(src, s), s, limit,
    (%Equal.sym(Nat, Nat.add(U32.to_nat((e - s : U32)), U32.to_nat(s)), U32.to_nat(e), span_end(s, e, hs)) : MNat.lt(_, limit); he), hu)

def state_snapshot(+name: String, +text: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat) -> Type:
  &len: U32 -> &src: Tree.Tree<U32> ->
    {st == Sse.St{name, Bytes.Bytes{len, Tree.reify(U32, src)}, id, retry} : Sse.St} &
    Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)) &
    {U32.to_nat(len) == String.length(text) : Nat} &
    MNat.lt(Nat.add(U32.to_nat(len), 3n), limit) &
    Packed.Reads(text, src, 0)

def set_snapshot_type(k: FieldKind, +old: String, +value: String, +name: String, +id: String, +retry: Maybe<&2, U32>, -st: Sse.St, +limit: Nat) -> Type:
  match k:
    case KData{}:
      state_snapshot(name, (old ++ value) ++ "\n", id, retry, st, limit)
    case KEvent{}:
      state_snapshot(value, old, id, retry, st, limit)
    case KId{}:
      state_snapshot(name, old, Bool.pick(String, Sse.has_nul(value), id, value), retry, st, limit)
    case KRetry{}:
      state_snapshot(name, old, id, Sse.set.retry(Sse.digits(value, 0, 0, False{}), retry), st, limit)
    case KOther{}:
      state_snapshot(name, old, id, retry, st, limit)

def old_data_bound(+la: U32, +lb: U32, +limit: Nat,
  hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit)) ->
  MNat.lt(Nat.add(U32.to_nat(la), 3n), limit):
  Feed.left_bound(la, lb, limit,
    MNat.lt_of_le_of_lt(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 3n), Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit,
      MNat.add_le_add_right(Nat.add(U32.to_nat(la), U32.to_nat(lb)), Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n,
        MNat.le_add_right(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n)), hn))

def set_valid(+k: FieldKind, +old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat}, +eb: {U32.to_nat(lb) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, right, 0)) ->
  set_snapshot_type(k, old, value, name, id, retry,
    Sse.set(kind_code(k), Bytes.Bytes{lb, Tree.reify(U32, right)}, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry}), limit):
  match k:
    case KData{}:
      (((la + lb : U32) + 1 : U32), data_tree(la, left, lb, right),
        Equal.cong(Bytes.Bytes, Sse.St, b => Sse.St{name, b, id, retry},
          Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), Sse.lf()),
          Bytes.Bytes{((la + lb : U32) + 1 : U32), Tree.reify(U32, data_tree(la, left, lb, right))}, data_bridge(la, left, lb, right)),
        data_valid_build(old, value, la, left, lb, right, limit, ea, eb, hn, hu, ra, rb, shape))
    case KEvent{}:
      (la, left, Equal.cong(String, Sse.St, s => Sse.St{s, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry},
        Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), value, data_value_string(value, la, lb, right, limit, eb, hu, hn, rb)),
        shape, ea, old_data_bound(la, lb, limit, hn), ra)
    case KId{}:
      (la, left, Equal.cong(String, Sse.St, +s => Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, Bool.pick(String, Sse.has_nul(s), id, s), retry},
        Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), value, data_value_string(value, la, lb, right, limit, eb, hu, hn, rb)),
        shape, ea, old_data_bound(la, lb, limit, hn), ra)
    case KRetry{}:
      (la, left, Equal.cong(String, Sse.St, s => Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, Sse.set.retry(Sse.digits(s, 0, 0, False{}), retry)},
        Bytes.to_string(Bytes.Bytes{lb, Tree.reify(U32, right)}), value, data_value_string(value, la, lb, right, limit, eb, hu, hn, rb)),
        shape, ea, old_data_bound(la, lb, limit, hn), ra)
    case KOther{}:
      (la, left, {==}, shape, ea, old_data_bound(la, lb, limit, hn), ra)

def field_after(r: Array<U32> & Sse.St) -> Sse.St:
  (a, st) = r
  st

def snapshot_transport(+k: FieldKind, +old: String, +value: String, +name: String, +id: String, +retry: Maybe<&2, U32>, +limit: Nat,
  -a: Sse.St, -b: Sse.St, same: {a == b : Sse.St}, cert: set_snapshot_type(k, old, value, name, id, retry, b, limit)) ->
  set_snapshot_type(k, old, value, name, id, retry, a, limit):
  %Equal.sym(Sse.St, a, b, same) : set_snapshot_type(k, old, value, name, id, retry, _, limit)
  cert

def field_after_canonical(+len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, -st: Sse.St, +m: U32, +out: Tree.Tree<U32>,
  value: {field_value(len, src, field_start(src, s, e), e) == Bytes.Bytes{m, Tree.reify(U32, out)} : Bytes.Bytes}) ->
  {field_after(Sse.field(Tree.reify(U32, src), len, s, e, st)) ==
    Sse.set(kind_code(field_kind(src, s, e)), Bytes.Bytes{m, Tree.reify(U32, out)}, st) : Sse.St}:
  +c = colon_index(U32.to_nat((e - s : U32)), src, s)
  +v = field_start(src, s, e)
  +k = field_kind(src, s, e)
  Equal.trans(Sse.St, field_after(Sse.field(Tree.reify(U32, src), len, s, e, st)), field_state_result(len, src, s, e, st),
    Sse.set(kind_code(k), Bytes.Bytes{m, Tree.reify(U32, out)}, st),
    Equal.cong(Array<U32> & Sse.St, Sse.St, field_after,
      Sse.field(Tree.reify(U32, src), len, s, e, st), (Tree.reify(U32, src), field_state_result(len, src, s, e, st)), field_pair(len, src, s, e, st)),
    Equal.trans(Sse.St, field_state_result(len, src, s, e, st),
      Sse.set(kind_code(k), field_value(len, src, v, e), st), Sse.set(kind_code(k), Bytes.Bytes{m, Tree.reify(U32, out)}, st),
      Equal.cong(U32, Sse.St, n => Sse.set(n, field_value(len, src, v, e), st),
        P.kind_index((c - s : U32), src, s), kind_code(k),
        Equal.sym(U32, kind_code(k), P.kind_index((c - s : U32), src, s), classify_code((c - s : U32), src, s))),
      Equal.cong(Bytes.Bytes, Sse.St, b => Sse.set(kind_code(k), b, st),
        field_value(len, src, v, e), Bytes.Bytes{m, Tree.reify(U32, out)}, value)))

def field_valid_snapshot(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat(U32.min((e - field_start(src, s, e) : U32), (len - U32.min(field_start(src, s, e), len) : U32))) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(U32.min((e - field_start(src, s, e) : U32), (len - U32.min(field_start(src, s, e), len) : U32)))), 1n), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), ra: Packed.Reads(old, left, 0),
  snapshot: Offset.copy_snapshot_type(value, len,
    U32.min((e - field_start(src, s, e) : U32), (len - U32.min(field_start(src, s, e), len) : U32)), src, U32.min(field_start(src, s, e), len))) ->
  set_snapshot_type(field_kind(src, s, e), old, value, name, id, retry,
    field_after(Sse.field(Tree.reify(U32, src), len, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})), limit):
  (+out, (eq, reads)) = snapshot
  +k = field_kind(src, s, e)
  +m = U32.min((e - field_start(src, s, e) : U32), (len - U32.min(field_start(src, s, e), len) : U32))
  snapshot_transport(k, old, value, name, id, retry, limit,
    field_after(Sse.field(Tree.reify(U32, src), len, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})),
    Sse.set(kind_code(k), Bytes.Bytes{m, Tree.reify(U32, out)}, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry}),
    field_after_canonical(len, src, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry}, m, out, eq),
    set_valid(k, old, value, la, left, m, out, limit, name, id, retry, shape, ea, eb, hn, hu, ra, reads))

def value_snapshot_of(+value: String, +len: U32, +src: Tree.Tree<U32>, +v: U32, +e: U32, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +eb: {U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32))) == String.length(value) : Nat},
  reads: Packed.Reads(value, src, U32.min(v, len)),
  bounds: MNat.le(U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32))), U32.to_nat(len)) &
    MNat.le(Nat.add(U32.to_nat(U32.min((e - v : U32), (len - U32.min(v, len) : U32))), U32.to_nat(U32.min(v, len))), U32.to_nat(len))) ->
  Offset.copy_snapshot_type(value, len, U32.min((e - v : U32), (len - U32.min(v, len) : U32)), src, U32.min(v, len)):
  (length, end) = bounds
  +m = U32.min((e - v : U32), (len - U32.min(v, len) : U32))
  +s = U32.min(v, len)
  Offset.copy_snapshot(value, len, m, src, s, limit,
    MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), 3n), Nat.add(U32.to_nat(len), 3n), limit, MNat.add_le_add_right(U32.to_nat(m), U32.to_nat(len), 3n, length), hl), hu, eb,
    MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), U32.to_nat(len), limit, end,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)), reads)

def field_valid(+old: String, +value: String, +la: U32, +left: Tree.Tree<U32>, +len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(la) == String.length(old) : Nat},
  +eb: {U32.to_nat(U32.min((e - field_start(src, s, e) : U32), (len - U32.min(field_start(src, s, e), len) : U32))) == String.length(value) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(U32.min((e - field_start(src, s, e) : U32), (len - U32.min(field_start(src, s, e), len) : U32)))), 1n), 3n), limit),
  ra: Packed.Reads(old, left, 0), rb: Packed.Reads(value, src, U32.min(field_start(src, s, e), len))) ->
  set_snapshot_type(field_kind(src, s, e), old, value, name, id, retry,
    field_after(Sse.field(Tree.reify(U32, src), len, s, e, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})), limit):
  field_valid_snapshot(old, value, la, left, len, src, s, e, limit, name, id, retry, shape, ea, eb, hn, hu, ra,
    value_snapshot_of(value, len, src, field_start(src, s, e), e, limit, hl, hu, eb, rb, Window.slice_bounds(len, field_start(src, s, e), (e - field_start(src, s, e) : U32))))

def strict_of_le_ne(+c: U32, +e: U32, le: MNat.le(U32.to_nat(c), U32.to_nat(e)), ne: {U32.is_eq(c, e) == False{} : Bool}) ->
  MNat.lt(U32.to_nat(c), U32.to_nat(e)):
  Equal.trans(Bool, Nat.is_lt(U32.to_nat(c), U32.to_nat(e)),
    Bool.and(Nat.is_le(U32.to_nat(c), U32.to_nat(e)), Bool.not(Nat.is_eq(U32.to_nat(c), U32.to_nat(e)))), True{},
    MNat.lt_iff_le_and_ne(U32.to_nat(c), U32.to_nat(e)),
    (%Equal.sym(Bool, Nat.is_le(U32.to_nat(c), U32.to_nat(e)), True{}, le) :
      {Bool.and(_, Bool.not(Nat.is_eq(U32.to_nat(c), U32.to_nat(e)))) == True{} : Bool}
     %Lemmas.u32_is_eq_nat(c, e) : {Bool.and(True{}, Bool.not(_)) == True{} : Bool}
     %Equal.sym(Bool, U32.is_eq(c, e), False{}, ne) : {Bool.and(True{}, Bool.not(_)) == True{} : Bool}
     {==}))

def value_bounds_select(equal: Bool, space: Bool, +c: U32, +e: U32, +one: U32, +two: U32,
  ce: MNat.le(U32.to_nat(c), U32.to_nat(e)), c1: MNat.le(U32.to_nat(c), U32.to_nat(one)), c2: MNat.le(U32.to_nat(c), U32.to_nat(two)),
  one_ok: {equal == False{} : Bool} -> MNat.le(U32.to_nat(one), U32.to_nat(e)),
  two_ok: {space == True{} : Bool} -> MNat.le(U32.to_nat(two), U32.to_nat(e))) ->
  MNat.le(U32.to_nat(c), U32.to_nat(Bool.pick(U32, equal, e, Bool.pick(U32, space, two, one)))) &
  MNat.le(U32.to_nat(Bool.pick(U32, equal, e, Bool.pick(U32, space, two, one))), U32.to_nat(e)):
  match equal:
    case True{}:
      (ce, MNat.le_refl(U32.to_nat(e)))
    case False{}:
      match space:
        case True{}:
          (c2, two_ok({==}))
        case False{}:
          (c1, one_ok({==}))

def value_bounds_of(+c: U32, +e: U32, +b: U32,
  +ce: MNat.le(U32.to_nat(c), U32.to_nat(e)),
  +e1: {U32.to_nat((c + 1 : U32)) == 1n+U32.to_nat(c) : Nat}, +e2: {U32.to_nat((c + 2 : U32)) == 2n+U32.to_nat(c) : Nat}) ->
  MNat.le(U32.to_nat(c), U32.to_nat(value_position(c, e, b))) &
  MNat.le(U32.to_nat(value_position(c, e, b)), U32.to_nat(e)):
  value_bounds_select(U32.is_eq(c, e), Bool.and(U32.is_lt((c + 1 : U32), e), U32.is_eq(b, 32)), c, e, (c + 1 : U32), (c + 2 : U32), ce,
    (%Equal.sym(Nat, U32.to_nat((c + 1 : U32)), 1n+U32.to_nat(c), e1) : MNat.le(U32.to_nat(c), _)
     MNat.le_succ(U32.to_nat(c))),
    (%Equal.sym(Nat, U32.to_nat((c + 2 : U32)), 2n+U32.to_nat(c), e2) : MNat.le(U32.to_nat(c), _)
     MNat.le_trans(U32.to_nat(c), 1n+U32.to_nat(c), 2n+U32.to_nat(c), MNat.le_succ(U32.to_nat(c)), MNat.le_succ(1n+U32.to_nat(c)))),
    ne => (
      %Equal.sym(Nat, U32.to_nat((c + 1 : U32)), 1n+U32.to_nat(c), e1) : MNat.le(_, U32.to_nat(e))
      MNat.succ_le_of_lt(U32.to_nat(c), U32.to_nat(e), strict_of_le_ne(c, e, ce, ne))),
    space => (
      %Equal.sym(Nat, U32.to_nat((c + 2 : U32)), 2n+U32.to_nat(c), e2) : MNat.le(_, U32.to_nat(e))
      %e1 : MNat.le(1n+_, U32.to_nat(e))
      MNat.succ_le_of_lt(U32.to_nat((c + 1 : U32)), U32.to_nat(e),
        (%Lemmas.u32_is_lt_nat((c + 1 : U32), e) : {_ == True{} : Bool}
         MBool.eq_true_of_and_left(U32.is_lt((c + 1 : U32), e), U32.is_eq(b, 32), space)))))

def addition_nat(+a: U32, +b: U32, +limit: Nat,
  h: MNat.lt(Nat.add(U32.to_nat(a), U32.to_nat(b)), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {U32.to_nat((a + b : U32)) == Nat.add(U32.to_nat(a), U32.to_nat(b)) : Nat}:
  Lemmas.u32_add_nat(a, b, MNat.lt_of_lt_of_le(Nat.add(U32.to_nat(a), U32.to_nat(b)), limit, Lemmas.pow2(32n), h, hu))

def value_bounds(+c: U32, +e: U32, +b: U32, +limit: Nat,
  ce: MNat.le(U32.to_nat(c), U32.to_nat(e)),
  hc1: MNat.lt(1n+U32.to_nat(c), limit), hc2: MNat.lt(Nat.add(U32.to_nat(c), 2n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(U32.to_nat(c), U32.to_nat(value_position(c, e, b))) &
  MNat.le(U32.to_nat(value_position(c, e, b)), U32.to_nat(e)):
  value_bounds_of(c, e, b, ce,
    Packed.add_one_nat(c, MNat.lt_of_lt_of_le(1n+U32.to_nat(c), limit, Lemmas.pow2(32n), hc1, hu)),
    Equal.trans(Nat, U32.to_nat((c + 2 : U32)), Nat.add(U32.to_nat(c), 2n), 2n+U32.to_nat(c),
      addition_nat(c, 2, limit, hc2, hu), MNat.add_comm(U32.to_nat(c), 2n)))

def plus_two_bound(+c: U32, +len: U32, +limit: Nat,
  h: MNat.le(U32.to_nat(c), U32.to_nat(len)), hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit)) ->
  MNat.lt(Nat.add(U32.to_nat(c), 2n), limit):
  MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(c), 2n), Nat.add(U32.to_nat(len), 3n), limit,
    MNat.le_trans(Nat.add(U32.to_nat(c), 2n), Nat.add(U32.to_nat(len), 2n), Nat.add(U32.to_nat(len), 3n),
      MNat.add_le_add_right(U32.to_nat(c), U32.to_nat(len), 2n, h), MNat.add_le_add_left(2n, 3n, U32.to_nat(len), {==})), hl)

def field_start_bounds_finish(+s: U32, +c: U32, +e: U32, +b: U32,
  lower: MNat.le(U32.to_nat(s), U32.to_nat(c)),
  bounds: MNat.le(U32.to_nat(c), U32.to_nat(value_position(c, e, b))) &
    MNat.le(U32.to_nat(value_position(c, e, b)), U32.to_nat(e))) ->
  MNat.le(U32.to_nat(s), U32.to_nat(value_position(c, e, b))) &
  MNat.le(U32.to_nat(value_position(c, e, b)), U32.to_nat(e)):
  (first, last) = bounds
  (MNat.le_trans(U32.to_nat(s), U32.to_nat(c), U32.to_nat(value_position(c, e, b)), lower, first), last)

def field_start_bounds_of(+len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  he: MNat.le(U32.to_nat(e), U32.to_nat(len)), +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  bounds: MNat.le(U32.to_nat(s), U32.to_nat(colon_index(U32.to_nat((e - s : U32)), src, s))) &
    MNat.le(U32.to_nat(colon_index(U32.to_nat((e - s : U32)), src, s)), U32.to_nat(e))) ->
  MNat.le(U32.to_nat(s), U32.to_nat(field_start(src, s, e))) &
  MNat.le(U32.to_nat(field_start(src, s, e)), U32.to_nat(e)):
  (lower, +upper) = bounds
  +c = colon_index(U32.to_nat((e - s : U32)), src, s)
  +h2 = plus_two_bound(c, len, limit, MNat.le_trans(U32.to_nat(c), U32.to_nat(e), U32.to_nat(len), upper, he), hl)
  field_start_bounds_finish(s, c, e, Packed.peek(src, (c + 1 : U32)), lower,
    value_bounds(c, e, Packed.peek(src, (c + 1 : U32)), limit, upper,
      Offset.increment_bound(1n, c, limit,
        (%MNat.add_comm(U32.to_nat(c), 2n) : MNat.lt(_, limit); h2)), h2, hu))

def field_start_bounds(+len: U32, +src: Tree.Tree<U32>, +s: U32, +e: U32, +limit: Nat,
  hs: MNat.le(U32.to_nat(s), U32.to_nat(e)), +he: MNat.le(U32.to_nat(e), U32.to_nat(len)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.le(U32.to_nat(s), U32.to_nat(field_start(src, s, e))) &
  MNat.le(U32.to_nat(field_start(src, s, e)), U32.to_nat(e)):
  field_start_bounds_of(len, src, s, e, limit, he, hl, hu,
    field_colon_bounds(src, s, e, limit, hs,
      MNat.lt_of_le_of_lt(U32.to_nat(e), Nat.add(U32.to_nat(len), 3n), limit,
        MNat.le_trans(U32.to_nat(e), U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), he, MNat.le_add_right(U32.to_nat(len), 3n)), hl), hu))
