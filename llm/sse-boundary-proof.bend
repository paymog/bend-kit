import Base
import ./sse.bend as Sse
import ./sse-packed-proof.bend as P
import ./sse-reader-proof.bend as Reader
import ./sse-scan-proof.bend as Scan
import ./sse-feed-proof.bend as Feed
import ./sse-offset-proof.bend as Offset
import ../bytes/append-proof.bend as Packed
import ../bytes/bytes.bend as Local
import ../lemmas/array.bend as Tree
import ../bits/array-proof.bend as Bound
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas

def view(r: Sse.Reader) -> Nat & String & U32 & U32 & Bool & Sse.St:
  Sse.Reader{Bytes.Bytes{+len, a}, pos, seen, cr, st} = r
  (U32.to_nat(len), P.observe(U32.to_nat(len), Bytes.Bytes{len, a}, 0), pos, seen, cr, st)

def view_reified(+text: String, +len: U32, +src: Tree.Tree<U32>, +seen: U32, +cr: Bool, -st: Sse.St,
  +length: {U32.to_nat(len) == String.length(text) : Nat}, reads: Packed.Reads(text, src, 0)) ->
  {view(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}) ==
    (String.length(text), text, 0, seen, cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}:
  Equal.trans(Nat & String & U32 & U32 & Bool & Sse.St,
    view(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}),
    (U32.to_nat(len), text, 0, seen, cr, st), (String.length(text), text, 0, seen, cr, st),
    Equal.cong(String, Nat & String & U32 & U32 & Bool & Sse.St, text => (U32.to_nat(len), text, 0, seen, cr, st),
      P.observe(U32.to_nat(len), Bytes.Bytes{len, Tree.reify(U32, src)}, 0), text,
      (%Equal.sym(Nat, U32.to_nat(len), String.length(text), length) :
        {P.observe(_, Bytes.Bytes{len, Tree.reify(U32, src)}, 0) == text : String}
       P.reads_observed(text, src, 0, reads))),
    Equal.cong(Nat, Nat & String & U32 & U32 & Bool & Sse.St, n => (n, text, 0, seen, cr, st),
      U32.to_nat(len), String.length(text), length))

def valid_view(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  valid: Reader.valid_buffer(prefix, tail, len, src, 0, seen, limit)) ->
  {view(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}) ==
    (String.length(prefix ++ tail), prefix ++ tail, 0, seen, cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}:
  (shape, hl, hp, hs, ep, length, reads, clean) = valid
  view_reified(prefix ++ tail, len, src, seen, cr, st, length, reads)

def transport_view(-actual: Sse.Reader, +prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  eq: {actual == Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st} : Sse.Reader},
  valid: Reader.valid_buffer(prefix, tail, len, src, 0, seen, limit)) ->
  {view(actual) == (String.length(prefix ++ tail), prefix ++ tail, 0, seen, cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}:
  Equal.trans(Nat & String & U32 & U32 & Bool & Sse.St,
    view(actual), view(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}),
    (String.length(prefix ++ tail), prefix ++ tail, 0, seen, cr, st),
    Equal.cong(Sse.Reader, Nat & String & U32 & U32 & Bool & Sse.St, view,
      actual, Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, 0, seen, cr, st}, eq),
    valid_view(prefix, tail, len, src, seen, cr, st, limit, valid))

def pair_observed(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  snapshot: Reader.feed_pair_type(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit)) ->
  {view(Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    (String.length(prefix ++ ((tail ++ a) ++ b)), prefix ++ ((tail ++ a) ++ b), 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}:
  (+out, (eq, valid)) = snapshot
  transport_view(Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)}),
    prefix, (tail ++ a) ++ b, ((Feed.input_length(U32.is_zero(pos), len, pos) + la : U32) + lb : U32), out, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st, limit, eq, valid)

def single_observed(+prefix: String, +tail: String, +chunk: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  snapshot: Reader.valid_feed_type(prefix, tail, chunk, len, src, pos, seen, cr, st, lb, right, limit)) ->
  {view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    (String.length(prefix ++ (tail ++ chunk)), prefix ++ (tail ++ chunk), 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}:
  (+out, (eq, valid)) = snapshot
  transport_view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    prefix, tail ++ chunk, (Feed.input_length(U32.is_zero(pos), len, pos) + lb : U32), out, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st, limit, eq, valid)

def duplicate_clean_step(-H: Data, -T: Type, +head: H, pair: T & T) -> (H & T) & (H & T):
  (a, b) = pair
  ((head, a), (head, b))

def duplicate_clean(f: Nat, r: Array<U32> & U32, +i: U32, clean: Scan.clean_prefix(f, r, i)) ->
  Scan.clean_prefix(f, r, i) & Scan.clean_prefix(f, r, i):
  match f:
    case 0n:
      (Unit{}, Unit{})
    case 1n+p:
      (a, +c) = r
      (+head, tail) = clean
      duplicate_clean_step(Scan.clean(c), Scan.clean_prefix(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32)), head,
        duplicate_clean(p, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32), tail))

def duplicate_valid_parts(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +limit: Nat,
  +hl: MNat.lt(Nat.add(U32.to_nat(len), 3n), limit), +hp: MNat.le(U32.to_nat(pos), U32.to_nat(seen)),
  +hs: MNat.le(U32.to_nat(seen), U32.to_nat(len)), +ep: {Nat.sub(U32.to_nat(seen), U32.to_nat(pos)) == String.length(prefix) : Nat},
  +ea: {U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)) == String.length(prefix ++ tail) : Nat},
  shapes: Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)) & Bound.shape(Local.depth(Local.words(len)), Packed.as_bits(src)),
  reads: Packed.Reads(prefix ++ tail, src, pos) & Packed.Reads(prefix ++ tail, src, pos),
  clean: Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos) & Scan.clean_prefix(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos)) ->
  Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit) & Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit):
  (ha, hb) = shapes
  (ra, rb) = reads
  (ca, cb) = clean
  ((ha, hl, hp, hs, ep, ea, ra, ca), (hb, hl, hp, hs, ep, ea, rb, cb))

def duplicate_valid(+prefix: String, +tail: String, +len: U32, +src: Tree.Tree<U32>, +pos: U32, +seen: U32, +limit: Nat,
  valid: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit) & Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit):
  (shape, +hl, +hp, +hs, +ep, +ea, reads, clean) = valid
  duplicate_valid_parts(prefix, tail, len, src, pos, seen, limit, hl, hp, hs, ep, ea,
    Bound.shape_copy(Local.depth(Local.words(len)), Packed.as_bits(src), shape),
    Offset.reads_duplicate(prefix ++ tail, src, pos, reads),
    duplicate_clean(String.length(prefix), Bytes.peek(Tree.reify(U32, src), pos), pos, clean))

def joined_finish(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>,
  single: {view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st},
    Bytes.Bytes{(la + lb : U32), Tree.reify(U32, Packed.append(la, left, lb, right))})) ==
    (String.length(prefix ++ (tail ++ (a ++ b))), prefix ++ (tail ++ (a ++ b)), 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}) ->
  {view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st},
    Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}))) ==
    (String.length(prefix ++ (tail ++ (a ++ b))), prefix ++ (tail ++ (a ++ b)), 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}:
  -r : Sse.Reader = Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}
  -chunk = Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)})
  -packed : Bytes.Bytes = Bytes.Bytes{(la + lb : U32), Tree.reify(U32, Packed.append(la, left, lb, right))}
  Equal.trans(Nat & String & U32 & U32 & Bool & Sse.St, view(Sse.feed(r, chunk)), view(Sse.feed(r, packed)),
    (String.length(prefix ++ (tail ++ (a ++ b))), prefix ++ (tail ++ (a ++ b)), 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st),
    Equal.cong(Bytes.Bytes, Nat & String & U32 & U32 & Bool & Sse.St, chunk => view(Sse.feed(r, chunk)),
      chunk, packed, P.append_bridge(la, left, lb, right)), single)

def joined_observed(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ea: {U32.to_nat(la) == String.length(a) : Nat}, +eb: {U32.to_nat(lb) == String.length(b) : Nat},
  +hab: MNat.lt(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 3n), limit),
  hc: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat((la + lb : U32))), 3n), limit),
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  ra: Packed.Reads(a, left, 0), rb: Packed.Reads(b, right, 0), valid: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  {view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st},
    Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}))) ==
    (String.length(prefix ++ (tail ++ (a ++ b))), prefix ++ (tail ++ (a ++ b)), 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}:
  joined_finish(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right,
    single_observed(prefix, tail, a ++ b, len, src, pos, seen, cr, st, (la + lb : U32), Packed.append(la, left, lb, right), limit,
      Reader.feed_valid(prefix, tail, a ++ b, len, src, pos, seen, cr, st, (la + lb : U32), Packed.append(la, left, lb, right), limit, hu,
        Feed.sum_length(a, b, la, lb, Reader.sum_nat(la, lb, limit, hab, hu), ea, eb), hc,
        Packed.append.reads(a, b, la, lb, left, right, limit, shape,
          Packed.allocation_depth(la, Packed.alloc_capacity(la, limit, Feed.left_bound(la, lb, limit, hab), hu)), ea, eb, hab, hu, ra, rb), valid)))

def compose_finish(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>,
  pair: {view(Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    (String.length(prefix ++ ((tail ++ a) ++ b)), prefix ++ ((tail ++ a) ++ b), 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st) : Nat & String & U32 & U32 & Bool & Sse.St},
  joined: {view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st},
    Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}))) ==
    (String.length(prefix ++ (tail ++ (a ++ b))), prefix ++ (tail ++ (a ++ b)), 0, Feed.output_seen(U32.is_zero(pos), seen, pos), cr, st) : Nat & String & U32 & U32 & Bool & Sse.St}) ->
  {view(Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}))) : Nat & String & U32 & U32 & Bool & Sse.St}:
  -l = Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)})
  -r = Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}))
  +next = Feed.output_seen(U32.is_zero(pos), seen, pos)
  Equal.trans(Nat & String & U32 & U32 & Bool & Sse.St, view(l),
    (String.length(prefix ++ ((tail ++ a) ++ b)), prefix ++ ((tail ++ a) ++ b), 0, next, cr, st), view(r), pair,
    Equal.trans(Nat & String & U32 & U32 & Bool & Sse.St,
      (String.length(prefix ++ ((tail ++ a) ++ b)), prefix ++ ((tail ++ a) ++ b), 0, next, cr, st),
      (String.length(prefix ++ (tail ++ (a ++ b))), prefix ++ (tail ++ (a ++ b)), 0, next, cr, st), view(r),
      Equal.cong(String, Nat & String & U32 & U32 & Bool & Sse.St, text => (String.length(prefix ++ text), prefix ++ text, 0, next, cr, st),
        (tail ++ a) ++ b, tail ++ (a ++ b), Packed.append_assoc(tail, a, b)),
      Equal.sym(Nat & String & U32 & U32 & Bool & Sse.St, view(r),
        (String.length(prefix ++ (tail ++ (a ++ b))), prefix ++ (tail ++ (a ++ b)), 0, next, cr, st), joined)))

def compose_parts(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ea: {U32.to_nat(la) == String.length(a) : Nat}, +eb: {U32.to_nat(lb) == String.length(b) : Nat},
  ha: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat(la)), 3n), limit),
  hb: MNat.lt(Nat.add(Nat.add(U32.to_nat((Feed.input_length(U32.is_zero(pos), len, pos) + la : U32)), U32.to_nat(lb)), 3n), limit),
  hab: MNat.lt(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 3n), limit),
  hc: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat((la + lb : U32))), 3n), limit),
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  left_reads: Packed.Reads(a, left, 0) & Packed.Reads(a, left, 0),
  right_reads: Packed.Reads(b, right, 0) & Packed.Reads(b, right, 0),
  valids: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit) & Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  {view(Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}))) : Nat & String & U32 & U32 & Bool & Sse.St}:
  (ra, rc) = left_reads
  (rb, rd) = right_reads
  (va, vb) = valids
  compose_finish(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right,
    pair_observed(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit,
      Reader.feed_pair_valid(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, hu, ea, eb, ha, hb, ra, rb, va)),
    joined_observed(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, hu, ea, eb, hab, hc, shape, rc, rd, vb))

def feed_composition(+prefix: String, +tail: String, +a: String, +b: String, +len: U32, +src: Tree.Tree<U32>,
  +pos: U32, +seen: U32, +cr: Bool, -st: Sse.St, +la: U32, +left: Tree.Tree<U32>, +lb: U32, +right: Tree.Tree<U32>, +limit: Nat,
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +ea: {U32.to_nat(la) == String.length(a) : Nat}, +eb: {U32.to_nat(lb) == String.length(b) : Nat},
  ha: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat(la)), 3n), limit),
  hb: MNat.lt(Nat.add(Nat.add(U32.to_nat((Feed.input_length(U32.is_zero(pos), len, pos) + la : U32)), U32.to_nat(lb)), 3n), limit),
  hab: MNat.lt(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 3n), limit),
  hc: MNat.lt(Nat.add(Nat.add(U32.to_nat(Feed.input_length(U32.is_zero(pos), len, pos)), U32.to_nat((la + lb : U32))), 3n), limit),
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  ra: Packed.Reads(a, left, 0), rb: Packed.Reads(b, right, 0), valid: Reader.valid_buffer(prefix, tail, len, src, pos, seen, limit)) ->
  {view(Sse.feed(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.Bytes{la, Tree.reify(U32, left)}), Bytes.Bytes{lb, Tree.reify(U32, right)})) ==
    view(Sse.feed(Sse.Reader{Bytes.Bytes{len, Tree.reify(U32, src)}, pos, seen, cr, st}, Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}))) : Nat & String & U32 & U32 & Bool & Sse.St}:
  compose_parts(prefix, tail, a, b, len, src, pos, seen, cr, st, la, left, lb, right, limit, hu, ea, eb, ha, hb, hab, hc, shape,
    Offset.reads_duplicate(a, left, 0, ra), Offset.reads_duplicate(b, right, 0, rb), duplicate_valid(prefix, tail, len, src, pos, seen, limit, valid))
