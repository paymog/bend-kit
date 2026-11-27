import Base
import ./sse-packed-proof.bend as P
import ../bytes/append-proof.bend as Packed
import ../lemmas/array.bend as Tree
import ../bits/array-proof.bend as Bound
import ../bytes/bytes.bend as Local
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ./sse.bend as Sse
import ./sse-window-proof.bend as Window
import ./sse-capacity-proof.bend as Capacity

# Keep byte-state transport opaque: https://github.com/bendlang/bend/issues/1071.
def append_transport(+text: String, +chunk: String, +m: U32, +lb: U32, +left: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  -actual: Bytes.Bytes, same: {actual == Bytes.Bytes{m, Tree.reify(U32, left)} : Bytes.Bytes},
  shape: Bound.shape(Local.depth(Local.words(m)), Packed.as_bits(left)), hd: MNat.le(Local.depth(Local.words(m)), 30n),
  ea: {U32.to_nat(m) == String.length(text) : Nat}, eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(m), U32.to_nat(lb)), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(text, left, 0), rb: Packed.Reads(chunk, right, 0)) ->
  {P.observe(String.length(text ++ chunk), Bytes.append(actual, Bytes.Bytes{lb, Tree.reify(U32, right)}), 0) == text ++ chunk : String}:
  Equal.trans(String,
    P.observe(String.length(text ++ chunk), Bytes.append(actual, Bytes.Bytes{lb, Tree.reify(U32, right)}), 0),
    P.observe(String.length(text ++ chunk), Bytes.append(Bytes.Bytes{m, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), 0), text ++ chunk,
    Equal.cong(Bytes.Bytes, String, b => P.observe(String.length(text ++ chunk), Bytes.append(b, Bytes.Bytes{lb, Tree.reify(U32, right)}), 0),
      actual, Bytes.Bytes{m, Tree.reify(U32, left)}, same),
    P.append_observed(text, chunk, m, lb, left, right, limit, shape, hd, ea, eb, hn, hu, ra, rb))

def slice_selected_bridge(+len: U32, +src: Tree.Tree<U32>, +s: U32, +m: U32) ->
  {P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)) ==
    Bytes.Bytes{m, Tree.reify(U32, Packed.copy(m, src, Packed.alloc(m), s, 0))} : Bytes.Bytes}:
  Equal.cong(Bytes.Bytes & Bytes.Bytes, Bytes.Bytes, P.slice_second,
    Bytes.slice.at(len, Tree.reify(U32, src), s, m),
    (Bytes.Bytes{len, Tree.reify(U32, src)}, Bytes.Bytes{m, Tree.reify(U32, Packed.copy(m, src, Packed.alloc(m), s, 0))}),
    P.slice_at_bridge(len, src, s, m))

def slice_shape(+m: U32, +src: Tree.Tree<U32>, +s: U32) ->
  Bound.shape(Local.depth(Local.words(m)), Packed.as_bits(Packed.copy(m, src, Packed.alloc(m), s, 0))):
  Packed.copy_shape(Local.depth(Local.words(m)), m, src, Packed.alloc(m), s, 0, Packed.fresh_shape(Local.depth(Local.words(m))))

def slice_append(+text: String, +chunk: String, +len: U32, +m: U32, +src: Tree.Tree<U32>, +s: U32, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hm: MNat.lt(Nat.add(U32.to_nat(m), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(m) == String.length(text) : Nat}, eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  total: MNat.lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), limit),
  hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(m), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(text, src, s), rb: Packed.Reads(chunk, right, 0)) ->
  {P.observe(String.length(text ++ chunk), Bytes.append(P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), Bytes.Bytes{lb, Tree.reify(U32, right)}), 0) == text ++ chunk : String}:
  append_transport(text, chunk, m, lb, Packed.copy(m, src, Packed.alloc(m), s, 0), right, limit,
    P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), slice_selected_bridge(len, src, s, m),
    slice_shape(m, src, s), Packed.allocation_depth(m, Packed.alloc_capacity(m, limit, hm, hu)), ea, eb, hn, hu,
    P.copy_alloc_reads(text, m, src, s, limit, hm, hu, ea, total, ra), rb)

def slice_append_bounded_of(+text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>, +start: U32, +n: U32, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ea: {U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))) == String.length(text) : Nat},
  eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(text, src, U32.min(start, len)), rb: Packed.Reads(chunk, right, 0),
  bounds: MNat.le(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(len)) &
    MNat.le(Nat.add(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(U32.min(start, len))), U32.to_nat(len))) ->
  {P.observe(String.length(text ++ chunk), Bytes.append(P.slice_second(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, start, n)), Bytes.Bytes{lb, Tree.reify(U32, right)}), 0) == text ++ chunk : String}:
  (length, end) = bounds
  +m = U32.min(n, (len - U32.min(start, len) : U32))
  +s = U32.min(start, len)
  slice_append(text, chunk, len, m, src, s, lb, right, limit,
    MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), 3n), Nat.add(U32.to_nat(len), 3n), limit, MNat.add_le_add_right(U32.to_nat(m), U32.to_nat(len), 3n, length), hl),
    hu, ea, eb,
    MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), U32.to_nat(len), limit, end,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)),
    hn, ra, rb)

def slice_append_bounded(+text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>, +start: U32, +n: U32, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ea: {U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))) == String.length(text) : Nat},
  eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(U32.min(n, (len - U32.min(start, len) : U32))), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(text, src, U32.min(start, len)), rb: Packed.Reads(chunk, right, 0)) ->
  {P.observe(String.length(text ++ chunk), Bytes.append(P.slice_second(Bytes.slice(Bytes.Bytes{len, Tree.reify(U32, src)}, start, n)), Bytes.Bytes{lb, Tree.reify(U32, right)}), 0) == text ++ chunk : String}:
  slice_append_bounded_of(text, chunk, len, src, start, n, lb, right, limit, hl, hu, ea, eb, hn, ra, rb, Window.slice_bounds(len, start, n))

def reader_view(f: Nat, r: Sse.Reader) -> String & U32 & U32 & Bool & Sse.St:
  Sse.Reader{buf, pos, seen, cr, st} = r
  (P.observe(f, buf, 0), pos, seen, cr, st)

def view_observed(+f: Nat, -buf: Bytes.Bytes, -text: String, +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St,
  same: {P.observe(f, buf, 0) == text : String}) ->
  {reader_view(f, Sse.Reader{buf, pos, seen, cr, st}) == (text, pos, seen, cr, st) : String & U32 & U32 & Bool & Sse.St}:
  Equal.cong(String, String & U32 & U32 & Bool & Sse.St, s => (s, pos, seen, cr, st), P.observe(f, buf, 0), text, same)

def compact_view_bridge(+f: Nat, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +cr: Bool, st: Sse.St, +lb: U32, +right: Tree.Tree<U32>) ->
  {reader_view(f, Sse.feed.at(False{}, Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st, Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    reader_view(f, Sse.Reader{Bytes.Bytes{(P.compact_length(len, pos) + lb : U32), Tree.reify(U32, Packed.append(P.compact_length(len, pos), P.compact_tree(len, src, pos), lb, right))},
      0, (U32.max(seen, pos) - pos : U32), cr, st}) : String & U32 & U32 & Bool & Sse.St}:
  Equal.cong(Sse.Reader, String & U32 & U32 & Bool & Sse.St, reader_view(f),
    Sse.feed.at(False{}, Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Sse.Reader{Bytes.Bytes{(P.compact_length(len, pos) + lb : U32), Tree.reify(U32, Packed.append(P.compact_length(len, pos), P.compact_tree(len, src, pos), lb, right))},
      0, (U32.max(seen, pos) - pos : U32), cr, st}, P.feed_compact_bridge(len, src, pos, seen, cr, st, lb, right))

def compact_shape(+len: U32, +src: Tree.Tree<U32>, +pos: U32) ->
  Bound.shape(Local.depth(Local.words(P.compact_length(len, pos))), Packed.as_bits(P.compact_tree(len, src, pos))):
  slice_shape(P.compact_length(len, pos), src, P.compact_start(len, pos))

def append_model_observed(+text: String, +chunk: String, +m: U32, +lb: U32, +left: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  +seen: U32, +cr: Bool, -st: Sse.St,
  shape: Bound.shape(Local.depth(Local.words(m)), Packed.as_bits(left)), hd: MNat.le(Local.depth(Local.words(m)), 30n),
  ea: {U32.to_nat(m) == String.length(text) : Nat}, eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(m), U32.to_nat(lb)), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(text, left, 0), rb: Packed.Reads(chunk, right, 0)) ->
  {reader_view(String.length(text ++ chunk), Sse.Reader{Bytes.Bytes{(m + lb : U32), Tree.reify(U32, Packed.append(m, left, lb, right))}, 0, seen, cr, st}) ==
    (text ++ chunk, 0, seen, cr, st) : String & U32 & U32 & Bool & Sse.St}:
  view_observed(String.length(text ++ chunk), Bytes.Bytes{(m + lb : U32), Tree.reify(U32, Packed.append(m, left, lb, right))}, text ++ chunk, 0, seen, cr, st,
    P.reads_observed(text ++ chunk, Packed.append(m, left, lb, right), 0,
      Packed.append.reads(text, chunk, m, lb, left, right, limit, shape, hd, ea, eb, hn, hu, ra, rb)))

def compact_bounds(+len: U32, +pos: U32) ->
  MNat.le(U32.to_nat(P.compact_length(len, pos)), U32.to_nat(len)) &
  MNat.le(Nat.add(U32.to_nat(P.compact_length(len, pos)), U32.to_nat(P.compact_start(len, pos))), U32.to_nat(len)):
  Window.slice_bounds(len, pos, 4294967295)

def compact_reads_of(+text: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ea: {U32.to_nat(P.compact_length(len, pos)) == String.length(text) : Nat},
  ra: Packed.Reads(text, src, P.compact_start(len, pos)),
  bounds: MNat.le(U32.to_nat(P.compact_length(len, pos)), U32.to_nat(len)) &
    MNat.le(Nat.add(U32.to_nat(P.compact_length(len, pos)), U32.to_nat(P.compact_start(len, pos))), U32.to_nat(len))) ->
  Packed.Reads(text, P.compact_tree(len, src, pos), 0):
  (length, end) = bounds
  +m = P.compact_length(len, pos)
  +s = P.compact_start(len, pos)
  P.copy_alloc_reads(text, m, src, s, limit,
    MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), 3n), Nat.add(U32.to_nat(len), 3n), limit, MNat.add_le_add_right(U32.to_nat(m), U32.to_nat(len), 3n, length), hl),
    hu, ea,
    MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), U32.to_nat(len), limit, end,
      MNat.lt_of_le_of_lt(U32.to_nat(len), Nat.add(U32.to_nat(len), 3n), limit, MNat.le_add_right(U32.to_nat(len), 3n), hl)), ra)

def compact_reads(+text: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ea: {U32.to_nat(P.compact_length(len, pos)) == String.length(text) : Nat},
  ra: Packed.Reads(text, src, P.compact_start(len, pos))) ->
  Packed.Reads(text, P.compact_tree(len, src, pos), 0):
  compact_reads_of(text, len, src, pos, limit, hl, hu, ea, ra, compact_bounds(len, pos))

def left_bound(+m: U32, +lb: U32, +limit: Nat,
  hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(m), U32.to_nat(lb)), 3n), limit)) ->
  MNat.lt(Nat.add(U32.to_nat(m), 3n), limit):
  MNat.lt_of_le_of_lt(Nat.add(U32.to_nat(m), 3n), Nat.add(Nat.add(U32.to_nat(m), U32.to_nat(lb)), 3n), limit,
    MNat.add_le_add_right(U32.to_nat(m), Nat.add(U32.to_nat(m), U32.to_nat(lb)), 3n, MNat.le_add_right(U32.to_nat(m), U32.to_nat(lb))), hn)

def feed_compact_observed(+text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +cr: Bool, st: Sse.St,
  +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(P.compact_length(len, pos)) == String.length(text) : Nat},
  eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(P.compact_length(len, pos)), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(text, src, P.compact_start(len, pos)), rb: Packed.Reads(chunk, right, 0)) ->
  {reader_view(String.length(text ++ chunk), Sse.feed.at(False{}, Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st, Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    (text ++ chunk, 0, (U32.max(seen, pos) - pos : U32), cr, st) : String & U32 & U32 & Bool & Sse.St}:
  +m = P.compact_length(len, pos)
  +left = P.compact_tree(len, src, pos)
  Equal.trans(String & U32 & U32 & Bool & Sse.St,
    reader_view(String.length(text ++ chunk), Sse.feed.at(False{}, Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st, Bytes.Bytes{lb, Tree.reify(U32, right)})),
    reader_view(String.length(text ++ chunk), Sse.Reader{Bytes.Bytes{(m + lb : U32), Tree.reify(U32, Packed.append(m, left, lb, right))}, 0, (U32.max(seen, pos) - pos : U32), cr, st}),
    (text ++ chunk, 0, (U32.max(seen, pos) - pos : U32), cr, st),
    compact_view_bridge(String.length(text ++ chunk), len, src, pos, seen, cr, st, lb, right),
    append_model_observed(text, chunk, m, lb, left, right, limit, (U32.max(seen, pos) - pos : U32), cr, st,
      compact_shape(len, src, pos), Packed.allocation_depth(m, Packed.alloc_capacity(m, limit, left_bound(m, lb, limit, hn), hu)),
      ea, eb, hn, hu, compact_reads(text, len, src, pos, limit, hl, hu, ea, ra), rb))

def input_length(zero: Bool, +len: U32, +pos: U32) -> U32:
  match zero:
    case True{}:
      len
    case False{}:
      P.compact_length(len, pos)

def input_start(zero: Bool, +len: U32, +pos: U32) -> U32:
  match zero:
    case True{}:
      0
    case False{}:
      P.compact_start(len, pos)

def output_seen(zero: Bool, +seen: U32, +pos: U32) -> U32:
  match zero:
    case True{}:
      seen
    case False{}:
      (U32.max(seen, pos) - pos : U32)

def feed_at_observed(+zero: Bool, +text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +cr: Bool, st: Sse.St,
  +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(input_length(zero, len, pos)) == String.length(text) : Nat},
  eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(input_length(zero, len, pos)), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(text, src, input_start(zero, len, pos)), rb: Packed.Reads(chunk, right, 0)) ->
  {reader_view(String.length(text ++ chunk), Sse.feed.at(zero, Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st, Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    (text ++ chunk, 0, output_seen(zero, seen, pos), cr, st) : String & U32 & U32 & Bool & Sse.St}:
  match zero:
    case True{}:
      view_observed(String.length(text ++ chunk), Bytes.append(Bytes.Bytes{len, Tree.reify(U32, src)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), text ++ chunk, 0, seen, cr, st,
        P.append_observed(text, chunk, len, lb, src, right, limit, shape, Packed.allocation_depth(len, Packed.alloc_capacity(len, limit, hl, hu)), ea, eb, hn, hu, ra, rb))
    case False{}:
      feed_compact_observed(text, chunk, len, src, pos, seen, cr, st, lb, right, limit, hl, hu, ea, eb, hn, ra, rb)

def feed_observed(+text: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +cr: Bool, st: Sse.St,
  +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +ea: {U32.to_nat(input_length(U32.is_zero(pos), len, pos)) == String.length(text) : Nat},
  eb: {U32.to_nat(lb) == String.length(chunk) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(input_length(U32.is_zero(pos), len, pos)), U32.to_nat(lb)), 3n), limit),
  ra: Packed.Reads(text, src, input_start(U32.is_zero(pos), len, pos)), rb: Packed.Reads(chunk, right, 0)) ->
  {reader_view(String.length(text ++ chunk), Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    (text ++ chunk, 0, output_seen(U32.is_zero(pos), seen, pos), cr, st) : String & U32 & U32 & Bool & Sse.St}:
  feed_at_observed(U32.is_zero(pos), text, chunk, len, src, pos, seen, cr, st, lb, right, limit, shape, hl, hu, ea, eb, hn, ra, rb)

def sum_length(+a: String, +b: String, +la: U32, +lb: U32,
  en: {U32.to_nat((la + lb : U32)) == Nat.add(U32.to_nat(la), U32.to_nat(lb)) : Nat},
  ea: {U32.to_nat(la) == String.length(a) : Nat}, eb: {U32.to_nat(lb) == String.length(b) : Nat}) ->
  {U32.to_nat((la + lb : U32)) == String.length(a ++ b) : Nat}:
  Equal.trans(Nat, U32.to_nat((la + lb : U32)), Nat.add(U32.to_nat(la), U32.to_nat(lb)), String.length(a ++ b), en,
    (%Equal.sym(Nat, U32.to_nat(la), String.length(a), ea) : {Nat.add(_, U32.to_nat(lb)) == String.length(a ++ b) : Nat}
     %Equal.sym(Nat, U32.to_nat(lb), String.length(b), eb) : {Nat.add(String.length(a), _) == String.length(a ++ b) : Nat}
     Equal.sym(Nat, String.length(a ++ b), Nat.add(String.length(a), String.length(b)), Packed.length_append(a, b))))

def append_twice_of(+a: String, +b: String, +c: String, +la: U32, +lb: U32, +lc: U32,
  +left: Tree.Tree<U32>, +middle: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  +ea: {U32.to_nat(la) == String.length(a) : Nat}, +eb: {U32.to_nat(lb) == String.length(b) : Nat}, ec: {U32.to_nat(lc) == String.length(c) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), U32.to_nat(lc)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(a, left, 0), rb: Packed.Reads(b, middle, 0), rc: Packed.Reads(c, right, 0),
  shapes: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)) & Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left))) ->
  {P.observe(String.length((a ++ b) ++ c), Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, middle)}), Bytes.Bytes{lc, Tree.reify(U32, right)}), 0) == (a ++ b) ++ c : String}:
  (ha, hb) = shapes
  +sum = Nat.add(U32.to_nat(la), U32.to_nat(lb))
  +hfirst = MNat.lt_of_le_of_lt(Nat.add(sum, 3n), Nat.add(Nat.add(sum, U32.to_nat(lc)), 3n), limit, MNat.add_le_add_right(sum, Nat.add(sum, U32.to_nat(lc)), 3n, MNat.le_add_right(sum, U32.to_nat(lc))), hn)
  +small = MNat.lt_of_le_of_lt(sum, Nat.add(sum, 3n), limit, MNat.le_add_right(sum, 3n), hfirst)
  +en = Lemmas.u32_add_nat(la, lb, MNat.lt_of_lt_of_le(sum, limit, Lemmas.pow2(32n), small, hu))
  +n = (la + lb : U32)
  +hnew : MNat.lt(Nat.add(U32.to_nat(n), 3n), limit) = (
    %Equal.sym(Nat, U32.to_nat(n), sum, en) : MNat.lt(Nat.add(_, 3n), limit)
    hfirst)
  +hle : MNat.le(U32.to_nat(la), U32.to_nat(n)) = (
    %Equal.sym(Nat, U32.to_nat(n), sum, en) : MNat.le(U32.to_nat(la), _)
    MNat.le_add_right(U32.to_nat(la), U32.to_nat(lb)))
  +hfinal : MNat.lt(Nat.add(Nat.add(U32.to_nat(n), U32.to_nat(lc)), 3n), limit) = (
    %Equal.sym(Nat, U32.to_nat(n), sum, en) : MNat.lt(Nat.add(Nat.add(_, U32.to_nat(lc)), 3n), limit)
    hn)
  +olddepth = Packed.allocation_depth(la, Packed.alloc_capacity(la, limit, left_bound(la, lb, limit, hfirst), hu))
  append_transport(a ++ b, c, n, lc, Packed.append(la, left, lb, middle), right, limit,
    Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, middle)}), P.append_bridge(la, left, lb, middle),
    Capacity.append_shape(la, lb, left, middle, limit, ha, hle, hnew, hu), Packed.allocation_depth(n, Packed.alloc_capacity(n, limit, hnew, hu)),
    sum_length(a, b, la, lb, en, ea, eb), ec, hfinal, hu,
    Packed.append.reads(a, b, la, lb, left, middle, limit, hb, olddepth, ea, eb, hfirst, hu, ra, rb), rc)

def append_twice(+a: String, +b: String, +c: String, +la: U32, +lb: U32, +lc: U32,
  +left: Tree.Tree<U32>, +middle: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +ea: {U32.to_nat(la) == String.length(a) : Nat}, +eb: {U32.to_nat(lb) == String.length(b) : Nat}, ec: {U32.to_nat(lc) == String.length(c) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), U32.to_nat(lc)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(a, left, 0), rb: Packed.Reads(b, middle, 0), rc: Packed.Reads(c, right, 0)) ->
  {P.observe(String.length((a ++ b) ++ c), Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, middle)}), Bytes.Bytes{lc, Tree.reify(U32, right)}), 0) == (a ++ b) ++ c : String}:
  append_twice_of(a, b, c, la, lb, lc, left, middle, right, limit, ea, eb, ec, hn, hu, ra, rb, rc, Bound.shape_copy(Local.depth(Local.words(la)), Packed.as_bits(left), shape))

def lf_bound(+sum: Nat, +limit: Nat, h: MNat.lt(Nat.add(Nat.add(sum, 1n), 3n), limit)) -> MNat.lt(4n, limit):
  MNat.lt_of_le_of_lt(4n, Nat.add(sum, 4n), limit, MNat.le_add_left(4n, sum),
    (%MNat.add_assoc(sum, 1n, 3n) : MNat.lt(_, limit); h))

def data_append_observed(+a: String, +b: String, +la: U32, +lb: U32, +left: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +ea: {U32.to_nat(la) == String.length(a) : Nat}, +eb: {U32.to_nat(lb) == String.length(b) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(a, left, 0), rb: Packed.Reads(b, right, 0)) ->
  {P.observe(String.length((a ++ b) ++ "\n"), Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), Sse.lf()), 0) == (a ++ b) ++ "\n" : String}:
  +f = String.length((a ++ b) ++ "\n")
  Equal.trans(String,
    P.observe(f, Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), Sse.lf()), 0),
    P.observe(f, Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), Bytes.Bytes{1, Tree.reify(U32, Packed.from_string("\n"))}), 0), (a ++ b) ++ "\n",
    Equal.cong(Bytes.Bytes, String, x => P.observe(f, Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), x), 0),
      Sse.lf(), Bytes.Bytes{1, Tree.reify(U32, Packed.from_string("\n"))}, P.from_bridge("\n")),
    append_twice(a, b, "\n", la, lb, 1, left, right, Packed.from_string("\n"), limit, shape, ea, eb, {==}, hn, hu, ra, rb,
      Packed.canonical_reads("\n", "", limit, lf_bound(Nat.add(U32.to_nat(la), U32.to_nat(lb)), limit, hn), hu)))

def state_view(f: Nat, st: Sse.St) -> String & String & String & Maybe<&2, U32>:
  Sse.St{name, data, id, retry} = st
  (name, P.observe(f, data, 0), id, retry)

def set_data_observed(+a: String, +b: String, +la: U32, +lb: U32, +left: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  +name: String, +id: String, +retry: Maybe<&2, U32>,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  +ea: {U32.to_nat(la) == String.length(a) : Nat}, +eb: {U32.to_nat(lb) == String.length(b) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 1n), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(a, left, 0), rb: Packed.Reads(b, right, 0)) ->
  {state_view(String.length((a ++ b) ++ "\n"), Sse.set(1, Bytes.Bytes{lb, Tree.reify(U32, right)}, Sse.St{name, Bytes.Bytes{la, Tree.reify(U32, left)}, id, retry})) ==
    (name, (a ++ b) ++ "\n", id, retry) : String & String & String & Maybe<&2, U32>}:
  Equal.cong(String, String & String & String & Maybe<&2, U32>, s => (name, s, id, retry),
    P.observe(String.length((a ++ b) ++ "\n"), Bytes.append(Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), Sse.lf()), 0),
    (a ++ b) ++ "\n", data_append_observed(a, b, la, lb, left, right, limit, shape, ea, eb, hn, hu, ra, rb))

def event_values(-a: Bytes.Bytes, -b: Bytes.Bytes, st: Sse.St, same: {Bytes.to_string(a) == Bytes.to_string(b) : String}) ->
  {Sse.set(2, a, st) == Sse.set(2, b, st) : Sse.St}:
  Sse.St{name, data, id, retry} = st
  Equal.cong(String, Sse.St, s => Sse.St{s, data, id, retry}, Bytes.to_string(a), Bytes.to_string(b), same)

def id_values(-a: Bytes.Bytes, -b: Bytes.Bytes, st: Sse.St, same: {Bytes.to_string(a) == Bytes.to_string(b) : String}) ->
  {Sse.set(3, a, st) == Sse.set(3, b, st) : Sse.St}:
  Sse.St{name, data, old, retry} = st
  Equal.cong(String, Sse.St, +s => Sse.St{name, data, Bool.pick(String, Sse.has_nul(s), old, s), retry}, Bytes.to_string(a), Bytes.to_string(b), same)

def retry_values(-a: Bytes.Bytes, -b: Bytes.Bytes, st: Sse.St, same: {Bytes.to_string(a) == Bytes.to_string(b) : String}) ->
  {Sse.set(4, a, st) == Sse.set(4, b, st) : Sse.St}:
  Sse.St{name, data, id, old} = st
  Equal.cong(String, Sse.St, s => Sse.St{name, data, id, Sse.set.retry(Sse.digits(s, 0, 0, False{}), old)}, Bytes.to_string(a), Bytes.to_string(b), same)
