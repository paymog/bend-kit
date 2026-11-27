import Base
import ./sse.bend as Sse
import ./sse-scan-proof.bend as Scan
import ./sse-buffer-proof.bend as Buffer
import ./sse-packed-proof.bend as P
import ./sse-feed-proof.bend as Feed
import ./sse-capacity-proof.bend as Capacity
import ./sse-offset-proof.bend as Offset
import ../bytes/append-proof.bend as Packed
import ../bytes/bytes.bend as Local
import ../bits/array-proof.bend as Bound
import ../lemmas/array.bend as Tree
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/u32.bend as MU32

def prefix_reads(+prefix: String, +tail: String, +src: Tree.Tree<U32>, +s: U32,
  reads: Packed.Reads(prefix ++ tail, src, s)) -> Packed.Reads(prefix, src, s):
  match prefix:
    case SNil{}:
      Unit{}
    case SCon{Chr{+c}, +rest}:
      (head, more) = reads
      Packed.reads_cons(rest, src, s, c, head, prefix_reads(rest, tail, src, (s + 1 : U32), more))

def clean_reads(+prefix: String, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +j: U32,
  ra: Packed.Reads(prefix, a, i), rb: Packed.Reads(prefix, b, j),
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, a), i), i)) ->
  Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, b), j), j):
  Buffer.clean_observed(String.length(prefix), Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j,
    Equal.trans(String, Buffer.observed(String.length(prefix), Bytes.peek(Tree.reify(U32, a), i), i), prefix,
      Buffer.observed(String.length(prefix), Bytes.peek(Tree.reify(U32, b), j), j), P.reads_observed(prefix, a, i, ra),
      Equal.sym(String, Buffer.observed(String.length(prefix), Bytes.peek(Tree.reify(U32, b), j), j), prefix, P.reads_observed(prefix, b, j, rb))), clean)

def appended_shape(+m: U32, +lb: U32, +left: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(m)), Packed.as_bits(left)),
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(m), U32.to_nat(lb)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  Bound.shape(Local.depth(Local.words((m + lb : U32))), Packed.as_bits(Packed.append(m, left, lb, right))):
  +sum = Nat.add(U32.to_nat(m), U32.to_nat(lb))
  +en = Lemmas.u32_add_nat(m, lb,
    MNat.lt_of_lt_of_le(sum, limit, Lemmas.pow2(32n),
      MNat.lt_of_le_of_lt(sum, Nat.add(sum, 3n), limit, MNat.le_add_right(sum, 3n), hn), hu))
  +h : MNat.le(U32.to_nat(m), U32.to_nat((m + lb : U32))) = (
    %Equal.sym(Nat, U32.to_nat((m + lb : U32)), sum, en) : MNat.le(U32.to_nat(m), _)
    MNat.le_add_right(U32.to_nat(m), U32.to_nat(lb)))
  +hnew : MNat.lt(Nat.add(U32.to_nat((m + lb : U32)), 3n), limit) = (
    %Equal.sym(Nat, U32.to_nat((m + lb : U32)), sum, en) : MNat.lt(Nat.add(_, 3n), limit)
    hn)
  Capacity.append_shape(m, lb, left, right, limit, shape, h, hnew, hu)

def feed_snapshot_type(+zero: Bool, +text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>) -> Type:
  &out: Tree.Tree<U32> ->
    {Sse.feed.at(zero, Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st, Bytes.Bytes{lb, Tree.reify(U32, right)}) ==
      Sse.Reader{Bytes.Bytes{(Feed.input_length(zero, len, pos) + lb : U32), Tree.reify(U32, out)}, 0, Feed.output_seen(zero, seen, pos), cr, st} : Sse.Reader} &
    Bound.shape(Local.depth(Local.words((Feed.input_length(zero, len, pos) + lb : U32))), Packed.as_bits(out)) &
    Packed.Reads(text ++ chunk, out, 0)

def zero_snapshot(+text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(len) == String.length(text) : Nat}, eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(len), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(text, src, 0), rb: Packed.Reads(chunk, right, 0),
  shapes: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)) & Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src))) ->
  feed_snapshot_type(True{}, text, chunk, len, src, pos, seen, cr, st, lb, right):
  (ha, hb) = shapes
  (Packed.append(len, src, lb, right),
    (Equal.cong(Bytes.Bytes, Sse.Reader, b => Sse.Reader{b, 0, seen, cr, st},
      Bytes.append(Bytes.Bytes{len, Tree.reify(U32, src)}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
      Bytes.Bytes{(len + lb : U32), Tree.reify(U32, Packed.append(len, src, lb, right))}, P.append_bridge(len, src, lb, right)),
    (appended_shape(len, lb, src, right, limit, ha, hn, hu),
      Packed.append.reads(text, chunk, len, lb, src, right, limit, hb,
        Packed.allocation_depth(len, Packed.alloc_capacity(len, limit, hl, hu)), ea, eb, hn, hu, ra, rb))))

def feed_snapshot(+zero: Bool, +text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(Feed.input_length(zero, len, pos)) == String.length(text) : Nat},
  eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(zero, len, pos)), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(text, src, Feed.input_start(zero, len, pos)), rb: Packed.Reads(chunk, right, 0)) ->
  feed_snapshot_type(zero, text, chunk, len, src, pos, seen, cr, st, lb, right):
  match zero:
    case True{}:
      zero_snapshot(text, chunk, len, src, pos, seen, cr, st, lb, right, limit, hl, hu, ea, eb, hn, ra, rb,
        Bound.shape_copy(Local.depth(Local.words(len)), Packed.as_bits(src), shape))
    case False{}:
      +m = P.compact_length(len, pos)
      +left = P.compact_tree(len, src, pos)
      (Packed.append(m, left, lb, right),
        (P.feed_compact_bridge(len, src, pos, seen, cr, st, lb, right),
        (appended_shape(m, lb, left, right, limit, Feed.compact_shape(len, src, pos), hn, hu),
          Packed.append.reads(text, chunk, m, lb, left, right, limit, Feed.compact_shape(len, src, pos),
            Packed.allocation_depth(m, Packed.alloc_capacity(m, limit, Feed.left_bound(m, lb, limit, hn), hu)), ea, eb, hn, hu,
            Feed.compact_reads(text, len, src, pos, limit, hl, hu, ea, ra), rb))))

def prefix_appended_reads(+prefix: String, +tail: String, +chunk: String, +src: Tree.Tree<U32>, +s: U32,
  reads: Packed.Reads((prefix ++ tail) ++ chunk, src, s)) -> Packed.Reads(prefix, src, s):
  prefix_reads(prefix, tail ++ chunk, src, s,
    (%Packed.append_assoc(prefix, tail, chunk) : Packed.Reads(_, src, s); reads))

def min_left(+a: U32, +b: U32, h: MNat.le(U32.to_nat(a), U32.to_nat(b))) -> {U32.min(a, b) == a : U32}:
  Lemmas.u32_to_nat_inj(U32.min(a, b), a,
    Equal.trans(Nat, U32.to_nat(U32.min(a, b)), Nat.min(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(a),
      MU32.u32_min_to_nat(a, b), MNat.min_eq_left(U32.to_nat(a), U32.to_nat(b), h)))

def max_left(+a: U32, +b: U32, h: MNat.le(U32.to_nat(b), U32.to_nat(a))) -> {U32.max(a, b) == a : U32}:
  Lemmas.u32_to_nat_inj(U32.max(a, b), a,
    Equal.trans(Nat, U32.to_nat(U32.max(a, b)), Nat.max(U32.to_nat(a), U32.to_nat(b)), U32.to_nat(a),
      Lemmas.u32_max_nat(a, b), MNat.max_eq_left(U32.to_nat(a), U32.to_nat(b), h)))

def input_start_selected(zero: Bool, +len: U32, +pos: U32, h: MNat.le(U32.to_nat(pos), U32.to_nat(len)),
  choice: {U32.is_zero(pos) == zero : Bool}) -> {Feed.input_start(zero, len, pos) == pos : U32}:
  match zero:
    case True{}:
      Equal.sym(U32, pos, 0, Packed.u32_eq_true(pos, 0, choice))
    case False{}:
      min_left(pos, len, h)

def input_start_correct(+len: U32, +pos: U32, h: MNat.le(U32.to_nat(pos), U32.to_nat(len))) ->
  {Feed.input_start(U32.is_zero(pos), len, pos) == pos : U32}:
  input_start_selected(U32.is_zero(pos), len, pos, h, {==})

def seen_selected(zero: Bool, +pos: U32, +seen: U32, +h: MNat.le(U32.to_nat(pos), U32.to_nat(seen)),
  choice: {U32.is_zero(pos) == zero : Bool}) ->
  {U32.to_nat(Feed.output_seen(zero, seen, pos)) == Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) : Nat}:
  match zero:
    case True{}:
      %Equal.sym(U32, pos, 0, Packed.u32_eq_true(pos, 0, choice)) : {U32.to_nat(seen) == Nat.sub(U32.to_nat(seen), U32.to_nat(_)) : Nat}
      Equal.sym(Nat, Nat.sub(U32.to_nat(seen), 0n), U32.to_nat(seen), MNat.sub_zero(U32.to_nat(seen)))
    case False{}:
      %Equal.sym(U32, U32.max(seen, pos), seen, max_left(seen, pos, h)) :
        {U32.to_nat((_ - pos : U32)) == Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) : Nat}
      Lemmas.u32_sub_nat(seen, pos, h)

def seen_correct(+pos: U32, +seen: U32, h: MNat.le(U32.to_nat(pos), U32.to_nat(seen))) ->
  {U32.to_nat(Feed.output_seen(U32.is_zero(pos), seen, pos)) == Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) : Nat}:
  seen_selected(U32.is_zero(pos), pos, seen, h, {==})


def valid_buffer(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +limit: Nat) -> Type:
  Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)) &
  MNat.lt(Nat.add(U32.to_nat(len), 3n), limit) &
  MNat.le(U32.to_nat(pos), U32.to_nat(seen)) &
  MNat.le(U32.to_nat(seen), U32.to_nat(len)) &
  {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat} &
  {U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)) == String.length(prefix ++ tail) : Nat} &
  Packed.Reads(prefix ++ tail, src, pos) &
  Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos)

def prefix_length(+prefix: String, +tail: String) -> MNat.le(String.length(prefix), String.length(prefix ++ tail)):
  %Equal.sym(Nat, String.length(prefix ++ tail), Nat.add(String.length(prefix), String.length(tail)), Packed.length_append(prefix, tail)) :
    MNat.le(String.length(prefix), _)
  MNat.le_add_right(String.length(prefix), String.length(tail))

def sum_nat(+m: U32, +lb: U32, +limit: Nat,
  hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(m), U32.to_nat(lb)), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {U32.to_nat((m + lb : U32)) == Nat.add(U32.to_nat(m), U32.to_nat(lb)) : Nat}:
  +sum = Nat.add(U32.to_nat(m), U32.to_nat(lb))
  Lemmas.u32_add_nat(m, lb, MNat.lt_of_lt_of_le(sum, limit, Lemmas.pow2(32n),
    MNat.lt_of_le_of_lt(sum, Nat.add(sum, 3n), limit, MNat.le_add_right(sum, 3n), hn), hu))

def valid_feed_type(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat) -> Type:
  &out: Tree.Tree<U32> ->
    {Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}) ==
      Sse.Reader{Bytes.Bytes{(Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), Tree.reify(U32, out)}, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st} : Sse.Reader} &
    valid_buffer(prefix, tail ++ chunk, (Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), out, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), limit)

def valid_output(+prefix: String, +tail: String, +chunk: String, +n: U32, +out: Tree.Tree<U32>, +seen: U32, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(n)), Packed.as_bits(out)), hn: MNat.lt(Nat.add(U32.to_nat(n), 3n), limit),
  +es: {U32.to_nat(seen) == String.length(prefix) : Nat}, +en: {U32.to_nat(n) == String.length((prefix ++ tail) ++ chunk) : Nat},
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, out), 0), 0),
  reads: Packed.Reads((prefix ++ tail) ++ chunk, out, 0)) ->
  valid_buffer(prefix, tail ++ chunk, n, out, 0, seen, limit):
  (shape, hn, MNat.zero_le(U32.to_nat(seen)),
    (%Equal.sym(Nat, U32.to_nat(seen), String.length(prefix), es) : MNat.le(_, U32.to_nat(n))
     %Equal.sym(Nat, U32.to_nat(n), String.length((prefix ++ tail) ++ chunk), en) : MNat.le(String.length(prefix), _)
     MNat.le_trans(String.length(prefix), String.length(prefix ++ tail), String.length((prefix ++ tail) ++ chunk),
       prefix_length(prefix, tail), prefix_length(prefix ++ tail, chunk))),
    Equal.trans(Nat, Nat.sub(U32.to_nat(seen), 0n), U32.to_nat(seen), String.length(prefix), MNat.sub_zero(U32.to_nat(seen)), es),
    Equal.trans(Nat, U32.to_nat(n), String.length((prefix ++ tail) ++ chunk), String.length(prefix ++ (tail ++ chunk)), en,
      Equal.cong(String, Nat, String.length, (prefix ++ tail) ++ chunk, prefix ++ (tail ++ chunk), Packed.append_assoc(prefix, tail, chunk))),
    (%Packed.append_assoc(prefix, tail, chunk) : Packed.Reads(_, out, 0); reads), clean)

def finish_valid_feed(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat, +out: Tree.Tree<U32>,
  eq: {Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}) ==
    Sse.Reader{Bytes.Bytes{(Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), Tree.reify(U32, out)}, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st} : Sse.Reader},
  shape: Bound.shape(Local.depth(Local.words((Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32))), Packed.as_bits(out)),
  +ea: {U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)) == String.length(prefix ++ tail) : Nat},
  eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat(lb)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  hp: MNat.le(U32.to_nat(pos), U32.to_nat(seen)), ep: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  ra: Packed.Reads(prefix, src, pos),
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos),
  pair: Packed.Reads((prefix ++ tail) ++ chunk, out, 0) & Packed.Reads((prefix ++ tail) ++ chunk, out, 0)) ->
  valid_feed_type(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit):
  (rb, rc) = pair
  +m = Feed.input_length(U32.is_zero(pos), len, pos)
  +n = (m + lb : U32)
  +en = sum_nat(m, lb, limit, hn, hu)
  +hnew : MNat.lt(Nat.add(U32.to_nat(n), 3n), limit) = (
    %Equal.sym(Nat, U32.to_nat(n), Nat.add(U32.to_nat(m), U32.to_nat(lb)), en) : MNat.lt(Nat.add(_, 3n), limit)
    hn)
  (out, (eq, valid_output(prefix, tail, chunk, n, out, Feed.output_seen(U32.is_zero(pos), seen, pos), limit, shape, hnew,
    Equal.trans(Nat, U32.to_nat(Feed.output_seen(U32.is_zero(pos), seen, pos)), Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), String.length(prefix), seen_correct(pos, seen, hp), ep),
    Feed.sum_length(prefix ++ tail, chunk, m, lb, en, ea, eb),
    clean_reads(prefix, src, out, pos, 0, ra, prefix_appended_reads(prefix, tail, chunk, out, 0, rb), clean), rc)))

def valid_feed_snapshot(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +ea: {U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)) == String.length(prefix ++ tail) : Nat},
  eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat(lb)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  hp: MNat.le(U32.to_nat(pos), U32.to_nat(seen)), ep: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  ra: Packed.Reads(prefix, src, pos),
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos),
  snapshot: feed_snapshot_type(U32.is_zero(pos), prefix ++ tail, chunk, len, src, pos, seen, cr, st, lb, right)) ->
  valid_feed_type(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit):
  (+out, (eq, shape, reads)) = snapshot
  finish_valid_feed(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, out, eq, shape, ea, eb, hn, hu, hp, ep, ra, clean,
    Offset.reads_duplicate((prefix ++ tail) ++ chunk, out, 0, reads))

def feed_valid_parts(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +hp: MNat.le(U32.to_nat(pos), U32.to_nat(seen)), hs: MNat.le(U32.to_nat(seen), U32.to_nat(len)),
  +ep: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  +ea: {U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)) == String.length(prefix ++ tail) : Nat},
  +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat(lb)), 3n), limit),
  rb: Packed.Reads(chunk, right, 0),
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos),
  reads: Packed.Reads(prefix ++ tail, src, pos) & Packed.Reads(prefix ++ tail, src, pos)) ->
  valid_feed_type(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit):
  (ra, rc) = reads
  +start = input_start_correct(len, pos, MNat.le_trans(U32.to_nat(pos), U32.to_nat(seen), U32.to_nat(len), hp, hs))
  valid_feed_snapshot(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, ea, eb, hn, hu, hp, ep,
    prefix_reads(prefix, tail, src, pos, ra), clean,
    feed_snapshot(U32.is_zero(pos), prefix ++ tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, shape, hl, hu, ea, eb, hn,
      (%Equal.sym(U32, Feed.input_start(U32.is_zero(pos), len, pos), pos, start) : Packed.Reads(prefix ++ tail, src, _); rc), rb))

def feed_valid(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat(lb)), 3n), limit),
  rb: Packed.Reads(chunk, right, 0), valid: valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  valid_feed_type(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit):
  (shape, +hl, +hp, hs, +ep, +ea, reads, clean) = valid
  feed_valid_parts(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit, shape, hl, hu, hp, hs, ep, ea, eb, hn, rb, clean,
    Offset.reads_duplicate(prefix ++ tail, src, pos, reads))

def feed_pair_type(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat) -> Type:
  &out: Tree.Tree<U32> ->
    {Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)}) ==
      Sse.Reader{Bytes.Bytes{((Feed.input_length(U32.is_zero(pos), len, pos) + la : U32) + lb : U32), Tree.reify(U32, out)}, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st} : Sse.Reader} &
    valid_buffer(prefix, (tail ++ a) ++ b, ((Feed.input_length(U32.is_zero(pos), len, pos) + la : U32) + lb : U32), out, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), limit)

def feed_pair_finish(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat, +first: Tree.Tree<U32>,
  eq: {Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}) ==
    Sse.Reader{Bytes.Bytes{(Feed.input_length(U32.is_zero(pos), len, pos) + la : U32), Tree.reify(U32, first)}, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st} : Sse.Reader},
  second: valid_feed_type(prefix, tail ++ a, b, (Feed.input_length(U32.is_zero(pos), len, pos) + la : U32), first, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st, lb, right, limit)) ->
  feed_pair_type(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit):
  (+out, (eq2, valid)) = second
  (out, (Equal.trans(Sse.Reader,
    Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Sse.feed(Sse.Reader{Bytes.Bytes{(Feed.input_length(U32.is_zero(pos), len, pos) + la : U32), Tree.reify(U32, first)}, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Sse.Reader{Bytes.Bytes{((Feed.input_length(U32.is_zero(pos), len, pos) + la : U32) + lb : U32), Tree.reify(U32, out)}, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st},
    Equal.cong(Sse.Reader, Sse.Reader, r => Sse.feed(r, Bytes.Bytes{lb, Tree.reify(U32, right)}),
      Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}),
      Sse.Reader{Bytes.Bytes{(Feed.input_length(U32.is_zero(pos), len, pos) + la : U32), Tree.reify(U32, first)}, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st}, eq), eq2), valid))

def feed_pair_continue(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +eb: {U32.to_nat(lb) == String.length(b) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat((Feed.input_length(U32.is_zero(pos), len, pos) + la : U32)), U32.to_nat(lb)), 3n), limit),
  rb: Packed.Reads(b, right, 0),
  first: valid_feed_type(prefix, tail, a, len, src, pos, seen, cr, st, la, left, limit)) ->
  feed_pair_type(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit):
  (+out, (eq, valid)) = first
  feed_pair_finish(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, out, eq,
    feed_valid(prefix, tail ++ a, b, (Feed.input_length(U32.is_zero(pos), len, pos) + la : U32), out, 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st, lb, right, limit, hu, eb, hn, rb, valid))

def feed_pair_valid(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ea: {U32.to_nat(la) == String.length(a) : Nat}, +eb: {U32.to_nat(lb) == String.length(b) : Nat},
  +ha: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat(la)), 3n), limit),
  +hb: MNat.lt(Nat.add(Nat.add(U32.to_nat((Feed.input_length(U32.is_zero(pos), len, pos) + la : U32)), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(a, left, 0), rb: Packed.Reads(b, right, 0), valid: valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  feed_pair_type(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit):
  feed_pair_continue(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, hu, eb, hb, rb,
    feed_valid(prefix, tail, a, len, src, pos, seen, cr, st, la, left, limit, hu, ea, ha, ra, valid))

def advance_peek(f: Nat, +src: Tree.Tree<U32>, +i: U32) ->
  {Scan.advance(f, Bytes.peek(Tree.reify(U32, src), i), i) ==
    (Bytes.peek(Tree.reify(U32, src), Packed.advance(f, i)), Packed.advance(f, i)) : (Array<U32> & U32) & U32}:
  match f:
    case 0n:
      {==}
    case 1n+ +p:
      %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), i), (Tree.reify(U32, src), Packed.peek(src, i)), Buffer.tree_peek(src, i)) :
        {Scan.advance(1n+p, _, i) == (Bytes.peek(Tree.reify(U32, src), Packed.advance(p, (i + 1 : U32))), Packed.advance(p, (i + 1 : U32))) : (Array<U32> & U32) & U32}
      advance_peek(p, src, (i + 1 : U32))

def advance_to(+f: Nat, +src: Tree.Tree<U32>, +i: U32, +j: U32, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), hn: MNat.lt(Nat.add(f, U32.to_nat(i)), limit),
  end: {Nat.add(f, U32.to_nat(i)) == U32.to_nat(j) : Nat}) ->
  {Scan.advance(f, Bytes.peek(Tree.reify(U32, src), i), i) == (Bytes.peek(Tree.reify(U32, src), j), j) : (Array<U32> & U32) & U32}:
  Equal.trans((Array<U32> & U32) & U32, Scan.advance(f, Bytes.peek(Tree.reify(U32, src), i), i),
    (Bytes.peek(Tree.reify(U32, src), Packed.advance(f, i)), Packed.advance(f, i)), (Bytes.peek(Tree.reify(U32, src), j), j),
    advance_peek(f, src, i),
    Equal.cong(U32, (Array<U32> & U32) & U32, k => (Bytes.peek(Tree.reify(U32, src), k), k), Packed.advance(f, i), j,
      Lemmas.u32_to_nat_inj(Packed.advance(f, i), j,
        Equal.trans(Nat, U32.to_nat(Packed.advance(f, i)), Nat.add(f, U32.to_nat(i)), U32.to_nat(j), Packed.advance_nat(f, i, limit, hu, hn), end))))

def restart_scan(+f: Nat, +g: Nat, +src: Tree.Tree<U32>, +i: U32, +j: U32, +limit: Nat,
  hu: MNat.le(limit, Lemmas.pow2(32n)), hn: MNat.lt(Nat.add(f, U32.to_nat(i)), limit),
  end: {Nat.add(f, U32.to_nat(i)) == U32.to_nat(j) : Nat},
  clean: Scan.clean_prefix(f, Bytes.peek(Tree.reify(U32, src), i), i)) ->
  {Sse.eol(Nat.add(f, g), Bytes.peek(Tree.reify(U32, src), i), i) == Sse.eol(g, Bytes.peek(Tree.reify(U32, src), j), j) : Array<U32> & U32}:
  Equal.trans(Array<U32> & U32, Sse.eol(Nat.add(f, g), Bytes.peek(Tree.reify(U32, src), i), i),
    Scan.resume(g, Scan.advance(f, Bytes.peek(Tree.reify(U32, src), i), i)), Sse.eol(g, Bytes.peek(Tree.reify(U32, src), j), j),
    Scan.extend(f, g, Bytes.peek(Tree.reify(U32, src), i), i, clean),
    Equal.cong((Array<U32> & U32) & U32, Array<U32> & U32, Scan.resume(g),
      Scan.advance(f, Bytes.peek(Tree.reify(U32, src), i), i), (Bytes.peek(Tree.reify(U32, src), j), j), advance_to(f, src, i, j, limit, hu, hn, end)))

def span_split(+len: Nat, +pos: Nat, +seen: Nat, hp: MNat.le(pos, seen), hs: MNat.le(seen, len)) ->
  {Nat.add(Nat.sub(seen, pos), Nat.sub(len, seen)) == Nat.sub(len, pos) : Nat}:
  Equal.trans(Nat, Nat.add(Nat.sub(seen, pos), Nat.sub(len, seen)), Nat.add(Nat.sub(len, seen), Nat.sub(seen, pos)), Nat.sub(len, pos),
    MNat.add_comm(Nat.sub(seen, pos), Nat.sub(len, seen)),
    Equal.trans(Nat, Nat.add(Nat.sub(len, seen), Nat.sub(seen, pos)), Nat.sub(Nat.add(Nat.sub(len, seen), seen), pos), Nat.sub(len, pos),
      Equal.sym(Nat, Nat.sub(Nat.add(Nat.sub(len, seen), seen), pos), Nat.add(Nat.sub(len, seen), Nat.sub(seen, pos)), MNat.add_sub_assoc(pos, seen, hp, Nat.sub(len, seen))),
      Equal.cong(Nat, Nat, x => Nat.sub(x, pos), Nat.add(Nat.sub(len, seen), seen), len, MNat.sub_add_cancel(len, seen, hs))))

def line_fuel(+f: Nat, +len: U32, +pos: U32, +seen: U32, +hp: MNat.le(U32.to_nat(pos), U32.to_nat(seen)),
  +hs: MNat.le(U32.to_nat(seen), U32.to_nat(len)), ep: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == f : Nat}) ->
  {U32.to_nat((len - pos : U32)) == Nat.add(f, U32.to_nat((len - seen : U32))) : Nat}:
  Equal.trans(Nat, U32.to_nat((len - pos : U32)), Nat.sub(U32.to_nat(len), U32.to_nat(pos)), Nat.add(f, U32.to_nat((len - seen : U32))),
    Lemmas.u32_sub_nat(len, pos, MNat.le_trans(U32.to_nat(pos), U32.to_nat(seen), U32.to_nat(len), hp, hs)),
    Equal.trans(Nat, Nat.sub(U32.to_nat(len), U32.to_nat(pos)), Nat.add(Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), Nat.sub(U32.to_nat(len), U32.to_nat(seen))), Nat.add(f, U32.to_nat((len - seen : U32))),
      Equal.sym(Nat, Nat.add(Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), Nat.sub(U32.to_nat(len), U32.to_nat(seen))), Nat.sub(U32.to_nat(len), U32.to_nat(pos)), span_split(U32.to_nat(len), U32.to_nat(pos), U32.to_nat(seen), hp, hs)),
      Equal.trans(Nat, Nat.add(Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), Nat.sub(U32.to_nat(len), U32.to_nat(seen))), Nat.add(f, Nat.sub(U32.to_nat(len), U32.to_nat(seen))), Nat.add(f, U32.to_nat((len - seen : U32))),
        Equal.cong(Nat, Nat, x => Nat.add(x, Nat.sub(U32.to_nat(len), U32.to_nat(seen))), Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), f, ep),
        Equal.cong(Nat, Nat, x => Nat.add(f, x), Nat.sub(U32.to_nat(len), U32.to_nat(seen)), U32.to_nat((len - seen : U32)),
          Equal.sym(Nat, U32.to_nat((len - seen : U32)), Nat.sub(U32.to_nat(len), U32.to_nat(seen)), Lemmas.u32_sub_nat(len, seen, hs))))))

def line_restart(+prefix: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  +hp: MNat.le(U32.to_nat(pos), U32.to_nat(seen)), +hs: MNat.le(U32.to_nat(seen), U32.to_nat(len)),
  +ep: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos)) ->
  {Sse.line(Tree.reify(U32, src), len, pos, seen, cr, st) == Sse.line(Tree.reify(U32, src), len, pos, pos, cr, st) : Sse.Line}:
  +end = Equal.trans(Nat, Nat.add(String.length(prefix), U32.to_nat(pos)), Nat.add(Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), U32.to_nat(pos)), U32.to_nat(seen),
    Equal.cong(Nat, Nat, x => Nat.add(x, U32.to_nat(pos)), String.length(prefix), Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), Equal.sym(Nat, Nat.sub(U32.to_nat(seen), U32.to_nat(pos)), String.length(prefix), ep)),
    MNat.sub_add_cancel(U32.to_nat(seen), U32.to_nat(pos), hp))
  +hn : MNat.lt(Nat.add(String.length(prefix), U32.to_nat(pos)), limit) = (
    %Equal.sym(Nat, Nat.add(String.length(prefix), U32.to_nat(pos)), U32.to_nat(seen), end) : MNat.lt(_, limit)
    MNat.lt_of_le_of_lt(U32.to_nat(seen), Nat.add(U32.to_nat(len), 3n), limit,
      MNat.le_trans(U32.to_nat(seen), U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), hs, MNat.le_add_right(U32.to_nat(len), 3n)), hl))
  %Equal.sym(U32, U32.max(pos, seen), seen,
    Lemmas.u32_to_nat_inj(U32.max(pos, seen), seen,
      Equal.trans(Nat, U32.to_nat(U32.max(pos, seen)), Nat.max(U32.to_nat(pos), U32.to_nat(seen)), U32.to_nat(seen),
        Lemmas.u32_max_nat(pos, seen), MNat.max_eq_right(U32.to_nat(pos), U32.to_nat(seen), hp)))) :
    {Sse.line.eol(len, pos, cr, st, Sse.eol(U32.to_nat((len - _ : U32)), Bytes.peek(Tree.reify(U32, src), _), _)) == Sse.line(Tree.reify(U32, src), len, pos, pos, cr, st) : Sse.Line}
  %Equal.sym(U32, U32.max(pos, pos), pos, Lemmas.u32_max_self(pos)) :
    {Sse.line.eol(len, pos, cr, st, Sse.eol(U32.to_nat((len - seen : U32)), Bytes.peek(Tree.reify(U32, src), seen), seen)) ==
      Sse.line.eol(len, pos, cr, st, Sse.eol(U32.to_nat((len - _ : U32)), Bytes.peek(Tree.reify(U32, src), _), _)) : Sse.Line}
  Equal.cong(Array<U32> & U32, Sse.Line, r => Sse.line.eol(len, pos, cr, st, r),
    Sse.eol(U32.to_nat((len - seen : U32)), Bytes.peek(Tree.reify(U32, src), seen), seen),
    Sse.eol(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos),
    Equal.sym(Array<U32> & U32,
      Sse.eol(U32.to_nat((len - pos : U32)), Bytes.peek(Tree.reify(U32, src), pos), pos),
      Sse.eol(U32.to_nat((len - seen : U32)), Bytes.peek(Tree.reify(U32, src), seen), seen),
      (%Equal.sym(Nat, U32.to_nat((len - pos : U32)), Nat.add(String.length(prefix), U32.to_nat((len - seen : U32))), line_fuel(String.length(prefix), len, pos, seen, hp, hs, ep)) :
         {Sse.eol(_, Bytes.peek(Tree.reify(U32, src), pos), pos) == Sse.eol(U32.to_nat((len - seen : U32)), Bytes.peek(Tree.reify(U32, src), seen), seen) : Array<U32> & U32}
       restart_scan(String.length(prefix), U32.to_nat((len - seen : U32)), src, pos, seen, limit, hu, hn, end, clean))))

def matching_observed(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  reads: Buffer.matching_reads(f, r, s, i, j)) ->
  {Buffer.observed(f, r, i) == Buffer.observed(f, s, j) : String}:
  match f:
    case 0n:
      {==}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = reads
      %Equal.sym(U32, c, d, head) :
        {SCon{Chr{_}, Buffer.observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))} == Buffer.observed(1n+p, (b, d), j) : String}
      Equal.cong(String, String, t => SCon{Chr{d}, t},
        Buffer.observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)), Buffer.observed(p, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32)),
        matching_observed(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32), tail))

def advanced_observation(+g: Nat, state: (Array<U32> & U32) & U32) -> String:
  (r, i) = state
  Buffer.observed(g, r, i)

def matching_drop(f: Nat, +g: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  reads: Buffer.matching_reads(Nat.add(f, g), r, s, i, j)) ->
  {advanced_observation(g, Scan.advance(f, r, i)) == advanced_observation(g, Scan.advance(f, s, j)) : String}:
  match f:
    case 0n:
      matching_observed(g, r, s, i, j, reads)
    case 1n+p:
      (a, c) = r
      (b, d) = s
      (head, tail) = reads
      matching_drop(p, g, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32), tail)

def observed_drop(+f: Nat, +g: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +j: U32, +u: U32, +v: U32, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), ha: MNat.lt(Nat.add(f, U32.to_nat(i)), limit), hb: MNat.lt(Nat.add(f, U32.to_nat(j)), limit),
  ea: {Nat.add(f, U32.to_nat(i)) == U32.to_nat(u) : Nat}, eb: {Nat.add(f, U32.to_nat(j)) == U32.to_nat(v) : Nat},
  same: {Buffer.observed(Nat.add(f, g), Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(Nat.add(f, g), Bytes.peek(Tree.reify(U32, b), j), j) : String}) ->
  {Buffer.observed(g, Bytes.peek(Tree.reify(U32, a), u), u) == Buffer.observed(g, Bytes.peek(Tree.reify(U32, b), v), v) : String}:
  Equal.trans(String, Buffer.observed(g, Bytes.peek(Tree.reify(U32, a), u), u),
    advanced_observation(g, Scan.advance(f, Bytes.peek(Tree.reify(U32, a), i), i)), Buffer.observed(g, Bytes.peek(Tree.reify(U32, b), v), v),
    Equal.sym(String, advanced_observation(g, Scan.advance(f, Bytes.peek(Tree.reify(U32, a), i), i)), Buffer.observed(g, Bytes.peek(Tree.reify(U32, a), u), u),
      Equal.cong((Array<U32> & U32) & U32, String, advanced_observation(g),
        Scan.advance(f, Bytes.peek(Tree.reify(U32, a), i), i), (Bytes.peek(Tree.reify(U32, a), u), u), advance_to(f, a, i, u, limit, hu, ha, ea))),
    Equal.trans(String, advanced_observation(g, Scan.advance(f, Bytes.peek(Tree.reify(U32, a), i), i)),
      advanced_observation(g, Scan.advance(f, Bytes.peek(Tree.reify(U32, b), j), j)), Buffer.observed(g, Bytes.peek(Tree.reify(U32, b), v), v),
      matching_drop(f, g, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j,
        Buffer.observations_match(Nat.add(f, g), Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j, same)),
      Equal.cong((Array<U32> & U32) & U32, String, advanced_observation(g),
        Scan.advance(f, Bytes.peek(Tree.reify(U32, b), j), j), (Bytes.peek(Tree.reify(U32, b), v), v), advance_to(f, b, j, v, limit, hu, hb, eb))))

def observed_take(+f: Nat, +g: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +i: U32, +j: U32,
  +same: {Buffer.observed(Nat.add(f, g), r, i) == Buffer.observed(Nat.add(f, g), s, j) : String}) ->
  {Buffer.observed(f, r, i) == Buffer.observed(f, s, j) : String}:
  match f:
    case 0n:
      {==}
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      -left = Buffer.observed(1n+Nat.add(p, g), (a, c), i)
      -right = Buffer.observed(1n+Nat.add(p, g), (b, d), j)
      %Equal.sym(U32, c, d, Equal.cong(String, U32, Buffer.observed.head, left, right, same)) :
        {SCon{Chr{_}, Buffer.observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))} == Buffer.observed(1n+p, (b, d), j) : String}
      Equal.cong(String, String, t => SCon{Chr{d}, t},
        Buffer.observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)), Buffer.observed(p, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32)),
        observed_take(p, g, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), (i + 1 : U32), (j + 1 : U32),
          Equal.cong(String, String, Buffer.observed.tail, left, right, same)))

def observed_span(+f: Nat, +g: Nat, +h: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +j: U32, +u: U32, +v: U32, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), ha: MNat.lt(Nat.add(f, U32.to_nat(i)), limit), hb: MNat.lt(Nat.add(f, U32.to_nat(j)), limit),
  ea: {Nat.add(f, U32.to_nat(i)) == U32.to_nat(u) : Nat}, eb: {Nat.add(f, U32.to_nat(j)) == U32.to_nat(v) : Nat},
  same: {Buffer.observed(Nat.add(Nat.add(f, g), h), Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(Nat.add(Nat.add(f, g), h), Bytes.peek(Tree.reify(U32, b), j), j) : String}) ->
  {Buffer.observed(g, Bytes.peek(Tree.reify(U32, a), u), u) == Buffer.observed(g, Bytes.peek(Tree.reify(U32, b), v), v) : String}:
  observed_drop(f, g, a, b, i, j, u, v, limit, hu, ha, hb, ea, eb,
    observed_take(Nat.add(f, g), h, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j, same))

def observed_length(f: Nat, r: Array<U32> & U32, +i: U32) ->
  {String.length(Buffer.observed(f, r, i)) == f : Nat}:
  match f:
    case 0n:
      {==}
    case 1n+ +p:
      (a, c) = r
      Equal.cong(Nat, Nat, n => 1n+n, String.length(Buffer.observed(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))), p,
        observed_length(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)))

def observation_reads(f: Nat, +src: Tree.Tree<U32>, +s: U32) ->
  Packed.Reads(Buffer.observed(f, Bytes.peek(Tree.reify(U32, src), s), s), src, s):
  match f:
    case 0n:
      Unit{}
    case 1n+ +p:
      %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), s), (Tree.reify(U32, src), Packed.peek(src, s)), Buffer.tree_peek(src, s)) :
        Packed.Reads(Buffer.observed(1n+p, _, s), src, s)
      Packed.reads_cons(Buffer.observed(p, Bytes.peek(Tree.reify(U32, src), (s + 1 : U32)), (s + 1 : U32)), src, s, Packed.peek(src, s), {==}, observation_reads(p, src, (s + 1 : U32)))
