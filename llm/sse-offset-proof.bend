import Base
import ./sse.bend as Sse
import ./sse-scan-proof.bend as Scan
import ./sse-buffer-proof.bend as Buffer
import ../bytes/append-proof.bend as Packed
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ../lemmas/array.bend as Tree
import ./sse-packed-proof.bend as P

def offset(+delta: Nat, +i: U32, +j: U32) -> Data:
  {U32.to_nat(i) == Nat.add(delta, U32.to_nat(j)) : Nat}

def increment(+delta: Nat, +i: U32, +j: U32, +limit: Nat,
  hi: MNat.lt(1n+U32.to_nat(i), limit), hj: MNat.lt(1n+U32.to_nat(j), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  same: offset(delta, i, j)) -> offset(delta, (i + 1 : U32), (j + 1 : U32)):
  +ei = Packed.add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), hi, hu))
  +ej = Packed.add_one_nat(j, MNat.lt_of_lt_of_le(1n+U32.to_nat(j), limit, Lemmas.pow2(32n), hj, hu))
  %Equal.sym(Nat, U32.to_nat((i + 1 : U32)), 1n+U32.to_nat(i), ei) : {_ == Nat.add(delta, U32.to_nat((j + 1 : U32))) : Nat}
  %Equal.sym(Nat, U32.to_nat((j + 1 : U32)), 1n+U32.to_nat(j), ej) : {1n+U32.to_nat(i) == Nat.add(delta, _) : Nat}
  Equal.trans(Nat, 1n+U32.to_nat(i), 1n+Nat.add(delta, U32.to_nat(j)), Nat.add(delta, 1n+U32.to_nat(j)),
    Equal.cong(Nat, Nat, x => 1n+x, U32.to_nat(i), Nat.add(delta, U32.to_nat(j)), same),
    Equal.sym(Nat, Nat.add(delta, 1n+U32.to_nat(j)), 1n+Nat.add(delta, U32.to_nat(j)), MNat.add_succ(delta, U32.to_nat(j))))

def increment_bound(+p: Nat, +i: U32, +limit: Nat, h: MNat.lt(Nat.add(1n+p, U32.to_nat(i)), limit)) -> MNat.lt(1n+U32.to_nat(i), limit):
  MNat.lt_of_le_of_lt(1n+U32.to_nat(i), Nat.add(1n+p, U32.to_nat(i)), limit,
    MNat.add_le_add_right(1n, 1n+p, U32.to_nat(i), MNat.le_add_right(1n, p)), h)

def tail_bound(+p: Nat, +i: U32, +limit: Nat, +hu: MNat.le(limit, Lemmas.pow2(32n)), +h: MNat.lt(Nat.add(1n+p, U32.to_nat(i)), limit)) ->
  MNat.lt(Nat.add(p, U32.to_nat((i + 1 : U32))), limit):
  %Equal.sym(Nat, U32.to_nat((i + 1 : U32)), 1n+U32.to_nat(i),
    Packed.add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), increment_bound(p, i, limit, h), hu))) : MNat.lt(Nat.add(p, _), limit)
  %Equal.sym(Nat, Nat.add(p, 1n+U32.to_nat(i)), 1n+Nat.add(p, U32.to_nat(i)), MNat.add_succ(p, U32.to_nat(i))) : MNat.lt(_, limit)
  h

def scan_step(+delta: Nat, +f: Nat, -a: Array<U32>, -b: Array<U32>, +c: U32, +i: U32, +j: U32,
  +here: offset(delta, i, j),
  next: offset(delta, Buffer.index(Sse.eol(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))), Buffer.index(Sse.eol(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))))) ->
  offset(delta, Buffer.index(Sse.eol(1n+f, (a, c), i)), Buffer.index(Sse.eol(1n+f, (b, c), j))):
  -left = Sse.eol(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))
  -right = Sse.eol(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))
  Scan.eol_elim(x => offset(delta, Buffer.index(x), Buffer.index(Sse.eol(1n+f, (b, c), j))), f, a, c, i,
    eq => (%Equal.sym(U32, c, 10, eq) : offset(delta, i, Buffer.index(Sse.eol(1n+f, (b, _), j))); here),
    eq => (%Equal.sym(U32, c, 13, eq) : offset(delta, i, Buffer.index(Sse.eol(1n+f, (b, _), j))); here),
    good => (%Equal.sym(Array<U32> & U32, Sse.eol(1n+f, (b, c), j), right, Scan.eol_step(f, b, c, j, good)) : offset(delta, Buffer.index(left), Buffer.index(_)); next))

def scan_reads(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +delta: Nat, +i: U32, +j: U32, +limit: Nat,
  +hi: MNat.lt(Nat.add(f, U32.to_nat(i)), limit), +hj: MNat.lt(Nat.add(f, U32.to_nat(j)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +here: offset(delta, i, j), reads: Buffer.matching_reads(f, r, s, i, j)) ->
  offset(delta, Buffer.index(Sse.eol(f, r, i)), Buffer.index(Sse.eol(f, s, j))):
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      here
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = reads
      %head : offset(delta, Buffer.index(Sse.eol(1n+p, (a, c), i)), Buffer.index(Sse.eol(1n+p, (b, _), j)))
      scan_step(delta, p, a, b, c, i, j, here,
        scan_reads(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), delta, (i + 1 : U32), (j + 1 : U32), limit,
          tail_bound(p, i, limit, hu, hi), tail_bound(p, j, limit, hu, hj), hu,
          increment(delta, i, j, limit, increment_bound(p, i, limit, hi), increment_bound(p, j, limit, hj), hu, here), tail))

def scan_observed(+f: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +delta: Nat, +i: U32, +j: U32, +limit: Nat,
  +hi: MNat.lt(Nat.add(f, U32.to_nat(i)), limit), +hj: MNat.lt(Nat.add(f, U32.to_nat(j)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +here: offset(delta, i, j),
  same: {Buffer.observed(f, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(f, Bytes.peek(Tree.reify(U32, b), j), j) : String}) ->
  offset(delta, Buffer.index(Sse.eol(f, Bytes.peek(Tree.reify(U32, a), i), i)), Buffer.index(Sse.eol(f, Bytes.peek(Tree.reify(U32, b), j), j))):
  scan_reads(f, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), delta, i, j, limit, hi, hj, hu, here,
    Buffer.observations_match(f, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j, same))

def scans_read(+text: String, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +delta: Nat, +i: U32, +j: U32, +limit: Nat,
  +hi: MNat.lt(Nat.add(String.length(text), U32.to_nat(i)), limit), +hj: MNat.lt(Nat.add(String.length(text), U32.to_nat(j)), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), +here: offset(delta, i, j),
  ra: Packed.Reads(text, a, i), rb: Packed.Reads(text, b, j)) ->
  offset(delta, Buffer.index(Sse.eol(String.length(text), Bytes.peek(Tree.reify(U32, a), i), i)),
    Buffer.index(Sse.eol(String.length(text), Bytes.peek(Tree.reify(U32, b), j), j))):
  scan_observed(String.length(text), a, b, delta, i, j, limit, hi, hj, hu, here,
    Equal.trans(String, Buffer.observed(String.length(text), Bytes.peek(Tree.reify(U32, a), i), i), text,
      Buffer.observed(String.length(text), Bytes.peek(Tree.reify(U32, b), j), j),
      P.reads_observed(text, a, i, ra),
      Equal.sym(String, Buffer.observed(String.length(text), Bytes.peek(Tree.reify(U32, b), j), j), text, P.reads_observed(text, b, j, rb))))

# Hide copied allocation behind a witness: https://github.com/bendlang/bend/issues/1071.
def copy_snapshot_type(+text: String, +len: U32, +m: U32, +src: Tree.Tree<U32>, +s: U32) -> Type:
  &out: Tree.Tree<U32> ->
    {P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)) == Bytes.Bytes{m, Tree.reify(U32, out)} : Bytes.Bytes} &
    Packed.Reads(text, out, 0)

def copy_snapshot(+text: String, +len: U32, +m: U32, +src: Tree.Tree<U32>, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(U32.to_nat(m), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +elen: {U32.to_nat(m) == String.length(text) : Nat}, +total: MNat.lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), limit),
  reads: Packed.Reads(text, src, s)) -> copy_snapshot_type(text, len, m, src, s):
  (Packed.copy(m, src, Packed.alloc(m), s, 0),
    (Equal.cong(Bytes.Bytes & Bytes.Bytes, Bytes.Bytes, P.slice_second,
      Bytes.slice.at(len, Tree.reify(U32, src), s, m),
      (Bytes.Bytes{len, Tree.reify(U32, src)}, Bytes.Bytes{m, Tree.reify(U32, Packed.copy(m, src, Packed.alloc(m), s, 0))}),
      P.slice_at_bridge(len, src, s, m)),
    P.copy_alloc_reads(text, m, src, s, limit, hn, hu, elen, total, reads)))

def scan_transport(+f: Nat, +delta: Nat, +left: U32, +m: U32, +out: Tree.Tree<U32>, -actual: Bytes.Bytes,
  eq: {actual == Bytes.Bytes{m, Tree.reify(U32, out)} : Bytes.Bytes}, result: offset(delta, left, P.scan(f, Bytes.Bytes{m, Tree.reify(U32, out)}, 0))) ->
  offset(delta, left, P.scan(f, actual, 0)):
  %Equal.sym(U32, P.scan(f, actual, 0), P.scan(f, Bytes.Bytes{m, Tree.reify(U32, out)}, 0), Equal.cong(Bytes.Bytes, U32, b => P.scan(f, b, 0), actual, Bytes.Bytes{m, Tree.reify(U32, out)}, eq)) :
    offset(delta, left, _)
  result

def copied_scan_snapshot(+text: String, +len: U32, +m: U32, +src: Tree.Tree<U32>, +s: U32, +limit: Nat,
  +hi: MNat.lt(Nat.add(String.length(text), U32.to_nat(s)), limit), +hj: MNat.lt(Nat.add(String.length(text), 0n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)), reads: Packed.Reads(text, src, s), view: copy_snapshot_type(text, len, m, src, s)) ->
  offset(U32.to_nat(s), P.scan(String.length(text), Bytes.Bytes{len, Tree.reify(U32, src)}, s),
    P.scan(String.length(text), P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), 0)):
  (+out, (eq, rb)) = view
  scan_transport(String.length(text), U32.to_nat(s), P.scan(String.length(text), Bytes.Bytes{len, Tree.reify(U32, src)}, s), m, out,
    P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), eq,
    scans_read(text, src, out, U32.to_nat(s), s, 0, limit, hi, hj, hu,
      Equal.sym(Nat, Nat.add(U32.to_nat(s), 0n), U32.to_nat(s), MNat.add_zero(U32.to_nat(s))), reads, rb))

def reads_duplicate_cons(+tail: String, +src: Tree.Tree<U32>, +s: U32, +c: U32, +head: {Packed.peek(src, s) == c : U32},
  pair: Packed.Reads(tail, src, (s + 1 : U32)) & Packed.Reads(tail, src, (s + 1 : U32))) ->
  Packed.Reads(SCon{Chr{c}, tail}, src, s) & Packed.Reads(SCon{Chr{c}, tail}, src, s):
  (a, b) = pair
  (Packed.reads_cons(tail, src, s, c, head, a), Packed.reads_cons(tail, src, s, c, head, b))

def reads_duplicate(+text: String, +src: Tree.Tree<U32>, +s: U32, reads: Packed.Reads(text, src, s)) ->
  Packed.Reads(text, src, s) & Packed.Reads(text, src, s):
  match text:
    case SNil{}:
      (Unit{}, Unit{})
    case SCon{Chr{+c}, +tail}:
      (+head, rest) = reads
      reads_duplicate_cons(tail, src, s, c, head, reads_duplicate(tail, src, (s + 1 : U32), rest))

def slice_scan_parts(+text: String, +len: U32, +m: U32, +src: Tree.Tree<U32>, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(U32.to_nat(m), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +elen: {U32.to_nat(m) == String.length(text) : Nat}, +total: MNat.lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), limit),
  pair: Packed.Reads(text, src, s) & Packed.Reads(text, src, s)) ->
  offset(U32.to_nat(s), P.scan(String.length(text), Bytes.Bytes{len, Tree.reify(U32, src)}, s),
    P.scan(String.length(text), P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), 0)):
  (ra, rb) = pair
  +hi : MNat.lt(Nat.add(String.length(text), U32.to_nat(s)), limit) = (
    %elen : MNat.lt(Nat.add(_, U32.to_nat(s)), limit)
    total)
  +hj : MNat.lt(Nat.add(String.length(text), 0n), limit) = (
    %elen : MNat.lt(Nat.add(_, 0n), limit)
    %Equal.sym(Nat, Nat.add(U32.to_nat(m), 0n), U32.to_nat(m), MNat.add_zero(U32.to_nat(m))) : MNat.lt(_, limit)
    MNat.lt_of_le_of_lt(U32.to_nat(m), Nat.add(U32.to_nat(m), 3n), limit, MNat.le_add_right(U32.to_nat(m), 3n), hn))
  copied_scan_snapshot(text, len, m, src, s, limit, hi, hj, hu, ra,
    copy_snapshot(text, len, m, src, s, limit, hn, hu, elen, total, rb))

def slice_scan(+text: String, +len: U32, +m: U32, +src: Tree.Tree<U32>, +s: U32, +limit: Nat,
  +hn: MNat.lt(Nat.add(U32.to_nat(m), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +elen: {U32.to_nat(m) == String.length(text) : Nat}, +total: MNat.lt(Nat.add(U32.to_nat(m), U32.to_nat(s)), limit),
  reads: Packed.Reads(text, src, s)) ->
  offset(U32.to_nat(s), P.scan(String.length(text), Bytes.Bytes{len, Tree.reify(U32, src)}, s),
    P.scan(String.length(text), P.slice_second(Bytes.slice.at(len, Tree.reify(U32, src), s, m)), 0)):
  slice_scan_parts(text, len, m, src, s, limit, hn, hu, elen, total, reads_duplicate(text, src, s, reads))

def colon_step(+delta: Nat, +f: Nat, -a: Array<U32>, -b: Array<U32>, +c: U32, +i: U32, +j: U32,
  here: offset(delta, i, j),
  next: offset(delta, Buffer.index(Sse.colon(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))), Buffer.index(Sse.colon(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))))) ->
  offset(delta, Buffer.index(Sse.colon(1n+f, (a, c), i)), Buffer.index(Sse.colon(1n+f, (b, c), j))):
  -left = Sse.colon(f, Bytes.peek(a, (i + 1 : U32)), (i + 1 : U32))
  -right = Sse.colon(f, Bytes.peek(b, (j + 1 : U32)), (j + 1 : U32))
  Buffer.colon_elim(x => offset(delta, Buffer.index(x), Buffer.index(Sse.colon(1n+f, (b, c), j))), f, a, c, i,
    eq => (%Equal.sym(U32, c, 58, eq) : offset(delta, i, Buffer.index(Sse.colon(1n+f, (b, _), j))); here),
    good => (%Equal.sym(Array<U32> & U32, Sse.colon(1n+f, (b, c), j), right, Buffer.colon_plain(f, b, c, j, good)) : offset(delta, Buffer.index(left), Buffer.index(_)); next))

def colon_reads(f: Nat, r: Array<U32> & U32, s: Array<U32> & U32, +delta: Nat, +i: U32, +j: U32, +limit: Nat,
  +hi: MNat.lt(Nat.add(f, U32.to_nat(i)), limit), +hj: MNat.lt(Nat.add(f, U32.to_nat(j)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +here: offset(delta, i, j), reads: Buffer.matching_reads(f, r, s, i, j)) ->
  offset(delta, Buffer.index(Sse.colon(f, r, i)), Buffer.index(Sse.colon(f, s, j))):
  match f:
    case 0n:
      (a, c) = r
      (b, d) = s
      here
    case 1n+ +p:
      (a, +c) = r
      (b, +d) = s
      (head, tail) = reads
      %head : offset(delta, Buffer.index(Sse.colon(1n+p, (a, c), i)), Buffer.index(Sse.colon(1n+p, (b, _), j)))
      colon_step(delta, p, a, b, c, i, j, here,
        colon_reads(p, Bytes.peek(a, (i + 1 : U32)), Bytes.peek(b, (j + 1 : U32)), delta, (i + 1 : U32), (j + 1 : U32), limit,
          tail_bound(p, i, limit, hu, hi), tail_bound(p, j, limit, hu, hj), hu,
          increment(delta, i, j, limit, increment_bound(p, i, limit, hi), increment_bound(p, j, limit, hj), hu, here), tail))

def colon_observed(+f: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +delta: Nat, +i: U32, +j: U32, +limit: Nat,
  +hi: MNat.lt(Nat.add(f, U32.to_nat(i)), limit), +hj: MNat.lt(Nat.add(f, U32.to_nat(j)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)),
  +here: offset(delta, i, j),
  same: {Buffer.observed(f, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(f, Bytes.peek(Tree.reify(U32, b), j), j) : String}) ->
  offset(delta, Buffer.index(Sse.colon(f, Bytes.peek(Tree.reify(U32, a), i), i)), Buffer.index(Sse.colon(f, Bytes.peek(Tree.reify(U32, b), j), j))):
  colon_reads(f, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), delta, i, j, limit, hi, hj, hu, here,
    Buffer.observations_match(f, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j, same))
