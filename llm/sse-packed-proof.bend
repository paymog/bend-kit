import Base
import ./sse.bend as Sse
import ./sse-buffer-proof.bend as Buffer
import ../bytes/append-proof.bend as Packed
import ../lemmas/array.bend as Tree
import bend-kit-bytes@0.3.3.3/bytes.bend as Bytes
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ../bits/array-proof.bend as Bound
import ../bytes/bytes.bend as Local
import ../bits/field-proof.bend as Field

def observe(+f: Nat, b: Bytes.Bytes, +i: U32) -> String:
  Bytes.Bytes{len, a} = b
  Buffer.observed(f, Bytes.peek(a, i), i)

def reads_observed(+s: String, +t: Tree.Tree<U32>, +i: U32, reads: Packed.Reads(s, t, i)) ->
  {Buffer.observed(String.length(s), Bytes.peek(Tree.reify(U32, t), i), i) == s : String}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, +tail}:
      (head, rest) = reads
      %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, t), i), (Tree.reify(U32, t), Packed.peek(t, i)), Buffer.tree_peek(t, i)) :
        {Buffer.observed(1n+String.length(tail), _, i) == SCon{Chr{c}, tail} : String}
      %Equal.sym(U32, Packed.peek(t, i), c, head) :
        {SCon{Chr{_}, Buffer.observed(String.length(tail), Bytes.peek(Tree.reify(U32, t), (i + 1 : U32)), (i + 1 : U32))} == SCon{Chr{c}, tail} : String}
      Equal.cong(String, String, x => SCon{Chr{c}, x}, Buffer.observed(String.length(tail), Bytes.peek(Tree.reify(U32, t), (i + 1 : U32)), (i + 1 : U32)), tail,
        reads_observed(tail, t, (i + 1 : U32), rest))

def poke_bridge(+t: Tree.Tree<U32>, +i: U32, +v: U32) ->
  {Bytes.poke(Tree.reify(U32, t), i, v) == Tree.reify(U32, Packed.poke(t, i, v)) : Array<U32>}:
  %Tree.tree_get(U32, t, (i >> 2n : U32)) :
    {Bytes.poke.of(i, v, _) == Tree.reify(U32, Packed.poke(t, i, v)) : Array<U32>}
  Equal.sym(Array<U32>, Tree.reify(U32, Packed.poke(t, i, v)),
    Array.set(U32, Tree.reify(U32, t), (i >> 2n : U32),
      ((Tree.read(U32, t, (i >> 2n : U32)) .&. ((255 << Bytes.shift(i)) .^. 4294967295)) .|. (Bytes.b8(v) << Bytes.shift(i)) : U32)),
    Packed.set_bridge(t, (i >> 2n : U32),
      ((Tree.read(U32, t, (i >> 2n : U32)) .&. ((255 << Bytes.shift(i)) .^. 4294967295)) .|. (Bytes.b8(v) << Bytes.shift(i)) : U32)))

def copy_go_bridge(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +v: U32) ->
  {Bytes.copy.go(n, (Tree.reify(U32, src), v), Tree.reify(U32, dst), s, d) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.go(n, src, dst, s, d, v))) : Array<U32> & Array<U32>}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), (s + 1 : U32)), (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), Buffer.tree_peek(src, (s + 1 : U32))) :
        {Bytes.copy.go(p, _, Bytes.poke(Tree.reify(U32, dst), d, v), (s + 1 : U32), (d + 1 : U32)) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.go(1n+p, src, dst, s, d, v))) : Array<U32> & Array<U32>}
      %Equal.sym(Array<U32>, Bytes.poke(Tree.reify(U32, dst), d, v), Tree.reify(U32, Packed.poke(dst, d, v)), poke_bridge(dst, d, v)) :
        {Bytes.copy.go(p, (Tree.reify(U32, src), Packed.peek(src, (s + 1 : U32))), _, (s + 1 : U32), (d + 1 : U32)) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.go(1n+p, src, dst, s, d, v))) : Array<U32> & Array<U32>}
      copy_go_bridge(p, src, Packed.poke(dst, d, v), (s + 1 : U32), (d + 1 : U32), Packed.peek(src, (s + 1 : U32)))

def copy_bytes_bridge(+m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32) ->
  {Bytes.copy.bytes(m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.bytes(m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), s), (Tree.reify(U32, src), Packed.peek(src, s)), Buffer.tree_peek(src, s)) :
    {Bytes.copy.go(U32.to_nat(m), _, Tree.reify(U32, dst), s, d) ==
      (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.bytes(m, src, dst, s, d))) : Array<U32> & Array<U32>}
  copy_go_bridge(U32.to_nat(m), src, dst, s, d, Packed.peek(src, s))

def copy_words_bridge(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +w: U32) ->
  {Bytes.copy.words(n, (Tree.reify(U32, src), w), Tree.reify(U32, dst), s, d) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.words(n, src, dst, s, d, w))) : Array<U32> & Array<U32>}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Tree.tree_get(U32, src, (s + 1 : U32)) :
        {Bytes.copy.words(p, _, Array.set(U32, Tree.reify(U32, dst), d, w), (s + 1 : U32), (d + 1 : U32)) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.words(1n+p, src, dst, s, d, w))) : Array<U32> & Array<U32>}
      %Packed.set_bridge(dst, d, w) :
        {Bytes.copy.words(p, (Tree.reify(U32, src), Tree.read(U32, src, (s + 1 : U32))), _, (s + 1 : U32), (d + 1 : U32)) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.words(1n+p, src, dst, s, d, w))) : Array<U32> & Array<U32>}
      copy_words_bridge(p, src, Packed.set(dst, d, w), (s + 1 : U32), (d + 1 : U32), Tree.read(U32, src, (s + 1 : U32)))

def copy_shift_bridge(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +prev: U32, +k: U32, +d: U32, +w: U32) ->
  {Bytes.copy.shift(n, lo, hi, prev, (Tree.reify(U32, src), w), Tree.reify(U32, dst), k, d) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.shift(n, src, dst, lo, hi, prev, k, d, w))) : Array<U32> & Array<U32>}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      +v = (U32.shrn(prev, lo) .|. U32.shln(w, hi) : U32)
      %Tree.tree_get(U32, src, (k + 1 : U32)) :
        {Bytes.copy.shift(p, lo, hi, w, _, Array.set(U32, Tree.reify(U32, dst), d, v), (k + 1 : U32), (d + 1 : U32)) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.shift(1n+p, src, dst, lo, hi, prev, k, d, w))) : Array<U32> & Array<U32>}
      %Packed.set_bridge(dst, d, v) :
        {Bytes.copy.shift(p, lo, hi, w, (Tree.reify(U32, src), Tree.read(U32, src, (k + 1 : U32))), _, (k + 1 : U32), (d + 1 : U32)) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.shift(1n+p, src, dst, lo, hi, prev, k, d, w))) : Array<U32> & Array<U32>}
      copy_shift_bridge(p, src, Packed.set(dst, d, v), lo, hi, w, (k + 1 : U32), (d + 1 : U32), Tree.read(U32, src, (k + 1 : U32)))

def copy_shift_at_bridge(+w: U32, +lo: U32, +k: U32, +d: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>) ->
  {Bytes.copy.shift.at(w, lo, k, d, Array.get(U32, Tree.reify(U32, src), k), Tree.reify(U32, dst)) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.shift.at(w, lo, k, d, src, dst))) : Array<U32> & Array<U32>}:
  %Tree.tree_get(U32, src, k) :
    {Bytes.copy.shift.at(w, lo, k, d, _, Tree.reify(U32, dst)) ==
      (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.shift.at(w, lo, k, d, src, dst))) : Array<U32> & Array<U32>}
  %Tree.tree_get(U32, src, (k + 1 : U32)) :
    {Bytes.copy.shift(U32.to_nat(w), U32.to_nat(lo), U32.to_nat((32 - lo : U32)), Tree.read(U32, src, k), _, Tree.reify(U32, dst), (k + 1 : U32), d) ==
      (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.shift.at(w, lo, k, d, src, dst))) : Array<U32> & Array<U32>}
  copy_shift_bridge(U32.to_nat(w), src, dst, U32.to_nat(lo), U32.to_nat((32 - lo : U32)), Tree.read(U32, src, k), (k + 1 : U32), d, Tree.read(U32, src, (k + 1 : U32)))

def copy_tail_bridge(+m: U32, +s: U32, +d: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>) ->
  {Bytes.copy.tail(m, s, d, (Tree.reify(U32, src), Tree.reify(U32, dst))) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.bytes(m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  copy_bytes_bridge(m, src, dst, s, d)

def copy_pick_bridge(aligned: Bool, +m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32) ->
  {Bytes.copy.pick(aligned, m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.pick(aligned, m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  match aligned:
    case True{}:
      +w = (m >> 2n : U32)
      +k = (w * 4 : U32)
      %Tree.tree_get(U32, src, (s >> 2n : U32)) :
        {Bytes.copy.tail((m - k : U32), (s + k : U32), (d + k : U32), Bytes.copy.words(U32.to_nat(w), _, Tree.reify(U32, dst), (s >> 2n : U32), (d >> 2n : U32))) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.pick(True{}, m, src, dst, s, d))) : Array<U32> & Array<U32>}
      %Equal.sym(Array<U32> & Array<U32>,
        Bytes.copy.words(U32.to_nat(w), (Tree.reify(U32, src), Tree.read(U32, src, (s >> 2n : U32))), Tree.reify(U32, dst), (s >> 2n : U32), (d >> 2n : U32)),
        (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.words(U32.to_nat(w), src, dst, (s >> 2n : U32), (d >> 2n : U32), Tree.read(U32, src, (s >> 2n : U32))))),
        copy_words_bridge(U32.to_nat(w), src, dst, (s >> 2n : U32), (d >> 2n : U32), Tree.read(U32, src, (s >> 2n : U32)))) :
        {Bytes.copy.tail((m - k : U32), (s + k : U32), (d + k : U32), _) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.pick(True{}, m, src, dst, s, d))) : Array<U32> & Array<U32>}
      copy_tail_bridge((m - k : U32), (s + k : U32), (d + k : U32), src,
        Packed.copy.words(U32.to_nat(w), src, dst, (s >> 2n : U32), (d >> 2n : U32), Tree.read(U32, src, (s >> 2n : U32))))
    case False{}:
      +w = (m >> 2n : U32)
      +k = (w * 4 : U32)
      +lo = ((s .&. 3 : U32) * 8 : U32)
      %Equal.sym(Array<U32> & Array<U32>,
        Bytes.copy.shift.at(w, lo, (s >> 2n : U32), (d >> 2n : U32), Array.get(U32, Tree.reify(U32, src), (s >> 2n : U32)), Tree.reify(U32, dst)),
        (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.shift.at(w, lo, (s >> 2n : U32), (d >> 2n : U32), src, dst))),
        copy_shift_at_bridge(w, lo, (s >> 2n : U32), (d >> 2n : U32), src, dst)) :
        {Bytes.copy.tail((m - k : U32), (s + k : U32), (d + k : U32), _) ==
          (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.pick(False{}, m, src, dst, s, d))) : Array<U32> & Array<U32>}
      copy_tail_bridge((m - k : U32), (s + k : U32), (d + k : U32), src,
        Packed.copy.shift.at(w, lo, (s >> 2n : U32), (d >> 2n : U32), src, dst))

def copy_dst_bridge(aligned: Bool, +m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32) ->
  {Bytes.copy.dst(aligned, m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy.dst(aligned, m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  match aligned:
    case False{}:
      copy_bytes_bridge(m, src, dst, s, d)
    case True{}:
      copy_pick_bridge(U32.is_eq((s .&. 3 : U32), 0), m, src, dst, s, d)

def copy_bridge(+m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32) ->
  {Bytes.copy(m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) ==
    (Tree.reify(U32, src), Tree.reify(U32, Packed.copy(m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  copy_dst_bridge(U32.is_eq((d .&. 3 : U32), 0), m, src, dst, s, d)

def depth_go_equal(f: Nat, more: Bool, +w: U32, +d: Nat, +cap: U32) ->
  {Bytes.depth.go(f, more, w, d, cap) == Local.depth.go(f, more, w, d, cap) : Nat}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      match more:
        case False{}:
          {==}
        case True{}:
          depth_go_equal(p, U32.is_lt((cap * 2 : U32), w), w, 1n+d, (cap * 2 : U32))

def depth_equal(+w: U32) -> {Bytes.depth(w) == Local.depth(w) : Nat}:
  depth_go_equal(32n, U32.is_lt(1, w), w, 0n, 1)

def alloc_bridge(+n: U32) -> {Bytes.alloc(n) == Tree.reify(U32, Packed.alloc(n)) : Array<U32>}:
  %Equal.sym(Nat, Bytes.depth(Bytes.words(n)), Local.depth(Local.words(n)), depth_equal(Bytes.words(n))) :
    {Array.new(U32, _, 0) == Tree.reify(U32, Packed.alloc(n)) : Array<U32>}
  Equal.sym(Array<U32>, Tree.reify(U32, Packed.alloc(n)), Array.new(U32, Local.depth(Local.words(n)), 0),
    Packed.fresh_bridge(Local.depth(Local.words(n))))

def room_equal(+len: U32, +n: U32) -> {Bytes.room(len, n) == Local.room(len, n) : Bool}:
  %Equal.sym(Nat, Bytes.depth(Bytes.words(len)), Local.depth(Local.words(len)), depth_equal(Bytes.words(len))) :
    {U32.is_le(Bytes.words(n), U32.shln(1, _)) == Local.room(len, n) : Bool}
  {==}

def grow_if_bridge(fits: Bool, +len: U32, +t: Tree.Tree<U32>, +n: U32) ->
  {Bytes.grow.if(fits, len, Tree.reify(U32, t), n) == Tree.reify(U32, Packed.grow.if(fits, len, t, n)) : Array<U32>}:
  match fits:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(Array<U32>, Bytes.alloc(n), Tree.reify(U32, Packed.alloc(n)), alloc_bridge(n)) :
        {Bytes.dst(Bytes.copy(len, Tree.reify(U32, t), _, 0, 0)) == Tree.reify(U32, Packed.grow.if(False{}, len, t, n)) : Array<U32>}
      Equal.cong(Array<U32> & Array<U32>, Array<U32>, Bytes.dst,
        Bytes.copy(len, Tree.reify(U32, t), Tree.reify(U32, Packed.alloc(n)), 0, 0),
        (Tree.reify(U32, t), Tree.reify(U32, Packed.copy(len, t, Packed.alloc(n), 0, 0))),
        copy_bridge(len, t, Packed.alloc(n), 0, 0))

def grow_bridge(+len: U32, +t: Tree.Tree<U32>, +n: U32) ->
  {Bytes.grow(len, Tree.reify(U32, t), n) == Tree.reify(U32, Packed.grow(len, t, n)) : Array<U32>}:
  %Equal.sym(Bool, Bytes.room(len, n), Local.room(len, n), room_equal(len, n)) :
    {Bytes.grow.if(_, len, Tree.reify(U32, t), n) == Tree.reify(U32, Packed.grow(len, t, n)) : Array<U32>}
  grow_if_bridge(Local.room(len, n), len, t, n)

def append_bridge(+la: U32, +a: Tree.Tree<U32>, +lb: U32, +b: Tree.Tree<U32>) ->
  {Bytes.append(Bytes.Bytes{la, Tree.reify(U32, a)}, Bytes.Bytes{lb, Tree.reify(U32, b)}) ==
    Bytes.Bytes{(la + lb : U32), Tree.reify(U32, Packed.append(la, a, lb, b))} : Bytes.Bytes}:
  %Equal.sym(Array<U32>, Bytes.grow(la, Tree.reify(U32, a), (la + lb : U32)), Tree.reify(U32, Packed.grow(la, a, (la + lb : U32))), grow_bridge(la, a, (la + lb : U32))) :
    {Bytes.Bytes{(la + lb : U32), Bytes.dst(Bytes.copy(lb, Tree.reify(U32, b), _, 0, la))} ==
      Bytes.Bytes{(la + lb : U32), Tree.reify(U32, Packed.append(la, a, lb, b))} : Bytes.Bytes}
  Equal.cong(Array<U32> & Array<U32>, Bytes.Bytes, r => Bytes.Bytes{(la + lb : U32), Bytes.dst(r)},
    Bytes.copy(lb, Tree.reify(U32, b), Tree.reify(U32, Packed.grow(la, a, (la + lb : U32))), 0, la),
    (Tree.reify(U32, b), Tree.reify(U32, Packed.append(la, a, lb, b))), copy_bridge(lb, b, Packed.grow(la, a, (la + lb : U32)), 0, la))

def append_observed(+a: String, +b: String, +la: U32, +lb: U32, +left: Tree.Tree<U32>, +right: Tree.Tree<U32>, +limit: Nat,
  shape: Bound.shape(Local.depth(Local.words(la)), Packed.as_bits(left)),
  hd: MNat.le(Local.depth(Local.words(la)), 30n),
  +ea: {U32.to_nat(la) == String.length(a) : Nat},
  eb: {U32.to_nat(lb) == String.length(b) : Nat},
  +hn: MNat.lt(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 3n), limit),
  +hu: MNat.le(limit, Lemmas.pow2(32n)),
  ra: Packed.Reads(a, left, 0), rb: Packed.Reads(b, right, 0)) ->
  {observe(String.length(a ++ b), Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}), 0) == a ++ b : String}:
  %Equal.sym(Bytes.Bytes, Bytes.append(Bytes.Bytes{la, Tree.reify(U32, left)}, Bytes.Bytes{lb, Tree.reify(U32, right)}),
    Bytes.Bytes{(la + lb : U32), Tree.reify(U32, Packed.append(la, left, lb, right))}, append_bridge(la, left, lb, right)) :
    {observe(String.length(a ++ b), _, 0) == a ++ b : String}
  reads_observed(a ++ b, Packed.append(la, left, lb, right), 0,
    Packed.append.reads(a, b, la, lb, left, right, limit, shape, hd, ea, eb, hn, hu, ra, rb))

def count_equal(s: String, +n: U32) -> {Bytes.count(s, n) == Local.count(s, n) : U32}:
  match s:
    case SNil{}:
      {==}
    case SCon{c, t}:
      count_equal(t, (n + 1 : U32))

def flush_bridge(full: Bool, +t: Tree.Tree<U32>, +k: U32, +w: U32) ->
  {Bytes.flush(full, Tree.reify(U32, t), k, w) == Tree.reify(U32, Packed.flush(full, t, k, w)) : Array<U32>}:
  match full:
    case True{}:
      Equal.sym(Array<U32>, Tree.reify(U32, Packed.set(t, k, w)), Array.set(U32, Tree.reify(U32, t), k, w), Packed.set_bridge(t, k, w))
    case False{}:
      {==}

def from_go_bridge(+s: String, +t: Tree.Tree<U32>, +i: U32, +w: U32) ->
  {Bytes.from.go(s, Tree.reify(U32, t), i, w) == Tree.reify(U32, Packed.from.go(s, t, i, w)) : Array<U32>}:
  match s:
    case SNil{}:
      +r = (i .&. 3 : U32)
      flush_bridge(U32.is_ne(r, 0), t, (i >> 2n : U32), U32.shrn(w, U32.to_nat((((4 - r) .&. 3) * 8 : U32))))
    case SCon{Chr{+c}, +tail}:
      +w2 = ((w >> 8n) .|. (Bytes.b8(c) << 24n) : U32)
      +full = U32.is_eq((i .&. 3 : U32), 3)
      %Equal.sym(Array<U32>, Bytes.flush(full, Tree.reify(U32, t), (i >> 2n : U32), w2), Tree.reify(U32, Packed.flush(full, t, (i >> 2n : U32), w2)), flush_bridge(full, t, (i >> 2n : U32), w2)) :
        {Bytes.from.go(tail, _, (i + 1 : U32), Bool.pick(U32, full, 0, w2)) == Tree.reify(U32, Packed.from.go(s, t, i, w)) : Array<U32>}
      from_go_bridge(tail, Packed.flush(full, t, (i >> 2n : U32), w2), (i + 1 : U32), Bool.pick(U32, full, 0, w2))

def from_bridge(+s: String) ->
  {Bytes.from_string(s) == Bytes.Bytes{Local.count(s, 0), Tree.reify(U32, Packed.from_string(s))} : Bytes.Bytes}:
  %Equal.sym(U32, Bytes.count(s, 0), Local.count(s, 0), count_equal(s, 0)) :
    {Bytes.Bytes{_, Bytes.from.go(s, Bytes.alloc(_), 0, 0)} == Bytes.Bytes{Local.count(s, 0), Tree.reify(U32, Packed.from_string(s))} : Bytes.Bytes}
  %Equal.sym(Array<U32>, Bytes.alloc(Local.count(s, 0)), Tree.reify(U32, Packed.alloc(Local.count(s, 0))), alloc_bridge(Local.count(s, 0))) :
    {Bytes.Bytes{Local.count(s, 0), Bytes.from.go(s, _, 0, 0)} == Bytes.Bytes{Local.count(s, 0), Tree.reify(U32, Packed.from_string(s))} : Bytes.Bytes}
  Equal.cong(Array<U32>, Bytes.Bytes, a => Bytes.Bytes{Local.count(s, 0), a},
    Bytes.from.go(s, Tree.reify(U32, Packed.alloc(Local.count(s, 0))), 0, 0), Tree.reify(U32, Packed.from_string(s)),
    from_go_bridge(s, Packed.alloc(Local.count(s, 0)), 0, 0))

def canonical_observed(+s: String, +limit: Nat, hn: MNat.lt(Nat.add(String.length(s), 3n), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {observe(String.length(Packed.mask(s)), Bytes.from_string(s), 0) == Packed.mask(s) : String}:
  %Equal.sym(Bytes.Bytes, Bytes.from_string(s), Bytes.Bytes{Local.count(s, 0), Tree.reify(U32, Packed.from_string(s))}, from_bridge(s)) :
    {observe(String.length(Packed.mask(s)), _, 0) == Packed.mask(s) : String}
  reads_observed(Packed.mask(s), Packed.from_string(s), 0, Packed.canonical_reads(s, SNil{}, limit, hn, hu))

def canonical_append_observed(+a: String, +b: String, +limit: Nat,
  +hn: MNat.lt(Nat.add(Nat.add(String.length(a), String.length(b)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.append(Bytes.from_string(a), Bytes.from_string(b)), 0) == Packed.mask(a) ++ Packed.mask(b) : String}:
  +la = Local.count(a, 0)
  +lb = Local.count(b, 0)
  +sum = Nat.add(String.length(a), String.length(b))
  +ha = MNat.lt_of_le_of_lt(Nat.add(String.length(a), 3n), Nat.add(sum, 3n), limit, MNat.add_le_add_right(String.length(a), sum, 3n, MNat.le_add_right(String.length(a), String.length(b))), hn)
  +hb = MNat.lt_of_le_of_lt(Nat.add(String.length(b), 3n), Nat.add(sum, 3n), limit, MNat.add_le_add_right(String.length(b), sum, 3n, Packed.le_add_left(String.length(b), String.length(a))), hn)
  +ea = Packed.canonical_length(a, limit, ha, hu)
  +eb = Packed.canonical_length(b, limit, hb, hu)
  +ema = Equal.trans(Nat, U32.to_nat(la), String.length(a), String.length(Packed.mask(a)), ea, Equal.sym(Nat, String.length(Packed.mask(a)), String.length(a), Packed.mask_length(a)))
  +emb = Equal.trans(Nat, U32.to_nat(lb), String.length(b), String.length(Packed.mask(b)), eb, Equal.sym(Nat, String.length(Packed.mask(b)), String.length(b), Packed.mask_length(b)))
  +counts : MNat.lt(Nat.add(Nat.add(U32.to_nat(la), U32.to_nat(lb)), 3n), limit) = (
    %Equal.sym(Nat, U32.to_nat(la), String.length(a), ea) : MNat.lt(Nat.add(Nat.add(_, U32.to_nat(lb)), 3n), limit)
    %Equal.sym(Nat, U32.to_nat(lb), String.length(b), eb) : MNat.lt(Nat.add(Nat.add(String.length(a), _), 3n), limit)
    hn)
  +left : MNat.lt(Nat.add(U32.to_nat(la), 3n), limit) = (
    %Equal.sym(Nat, U32.to_nat(la), String.length(a), ea) : MNat.lt(Nat.add(_, 3n), limit)
    ha)
  %Equal.sym(Bytes.Bytes, Bytes.from_string(a), Bytes.Bytes{la, Tree.reify(U32, Packed.from_string(a))}, from_bridge(a)) :
    {observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.append(_, Bytes.from_string(b)), 0) == Packed.mask(a) ++ Packed.mask(b) : String}
  %Equal.sym(Bytes.Bytes, Bytes.from_string(b), Bytes.Bytes{lb, Tree.reify(U32, Packed.from_string(b))}, from_bridge(b)) :
    {observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.append(Bytes.Bytes{la, Tree.reify(U32, Packed.from_string(a))}, _), 0) == Packed.mask(a) ++ Packed.mask(b) : String}
  append_observed(Packed.mask(a), Packed.mask(b), la, lb, Packed.from_string(a), Packed.from_string(b), limit,
    Packed.canonical_shape(a), Packed.allocation_depth(la, Packed.alloc_capacity(la, limit, left, hu)), ema, emb, counts, hu,
    Packed.canonical_reads(a, SNil{}, limit, ha, hu), Packed.canonical_reads(b, SNil{}, limit, hb, hu))

def mask_append(+a: String, +b: String) ->
  {Packed.mask(a ++ b) == Packed.mask(a) ++ Packed.mask(b) : String}:
  match a:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, +tail}:
      Equal.cong(String, String, s => SCon{Chr{Bytes.b8(c)}, s},
        Packed.mask(tail ++ b), Packed.mask(tail) ++ Packed.mask(b), mask_append(tail, b))

def canonical_append_same(+a: String, +b: String, +limit: Nat,
  +hn: MNat.lt(Nat.add(Nat.add(String.length(a), String.length(b)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.append(Bytes.from_string(a), Bytes.from_string(b)), 0) ==
    observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.from_string(a ++ b), 0) : String}:
  +whole_bound : MNat.lt(Nat.add(String.length(a ++ b), 3n), limit) = (
    %Equal.sym(Nat, String.length(a ++ b), Nat.add(String.length(a), String.length(b)), Packed.length_append(a, b)) : MNat.lt(Nat.add(_, 3n), limit)
    hn)
  +whole : {observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.from_string(a ++ b), 0) == Packed.mask(a) ++ Packed.mask(b) : String} = (
    %mask_append(a, b) : {observe(String.length(_), Bytes.from_string(a ++ b), 0) == _ : String}
    canonical_observed(a ++ b, limit, whole_bound, hu))
  Equal.trans(String,
    observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.append(Bytes.from_string(a), Bytes.from_string(b)), 0),
    Packed.mask(a) ++ Packed.mask(b),
    observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.from_string(a ++ b), 0),
    canonical_append_observed(a, b, limit, hn, hu),
    Equal.sym(String, observe(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.from_string(a ++ b), 0), Packed.mask(a) ++ Packed.mask(b), whole))

def scan(f: Nat, b: Bytes.Bytes, +i: U32) -> U32:
  Bytes.Bytes{len, a} = b
  Buffer.index(Sse.eol(f, Bytes.peek(a, i), i))

def scan_observed(+f: Nat, a: Bytes.Bytes, b: Bytes.Bytes, +i: U32,
  same: {observe(f, a, i) == observe(f, b, i) : String}) ->
  {scan(f, a, i) == scan(f, b, i) : U32}:
  Bytes.Bytes{la, left} = a
  Bytes.Bytes{lb, right} = b
  Buffer.eol_observed(f, Bytes.peek(left, i), Bytes.peek(right, i), i, same)

def canonical_append_scan(+a: String, +b: String, +limit: Nat,
  +hn: MNat.lt(Nat.add(Nat.add(String.length(a), String.length(b)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {scan(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.append(Bytes.from_string(a), Bytes.from_string(b)), 0) ==
    scan(String.length(Packed.mask(a) ++ Packed.mask(b)), Bytes.from_string(a ++ b), 0) : U32}:
  scan_observed(String.length(Packed.mask(a) ++ Packed.mask(b)),
    Bytes.append(Bytes.from_string(a), Bytes.from_string(b)), Bytes.from_string(a ++ b), 0, canonical_append_same(a, b, limit, hn, hu))

def reader_observed(f: Nat, r: Sse.Reader) -> String:
  Sse.Reader{buf, pos, seen, cr, st} = r
  observe(f, buf, 0)

def feed_zero_observed(+a: String, +b: String, +seen: U32, +cr: Bool, -st: Sse.St, +limit: Nat,
  +hn: MNat.lt(Nat.add(Nat.add(String.length(a), String.length(b)), 3n), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  {reader_observed(String.length(Packed.mask(a) ++ Packed.mask(b)),
    Sse.feed(Sse.Reader{Bytes.from_string(a), 0, seen, cr, st}, Bytes.from_string(b))) == Packed.mask(a) ++ Packed.mask(b) : String}:
  canonical_append_observed(a, b, limit, hn, hu)

def at_match(+needle: String, +t: Tree.Tree<U32>, +i: U32) -> Bool:
  Buffer.matched(Bytes.at(Tree.reify(U32, t), needle, i))

def at_result(+needle: String, +t: Tree.Tree<U32>, +i: U32) ->
  {Bytes.at(Tree.reify(U32, t), needle, i) == (Tree.reify(U32, t), at_match(needle, t, i)) : Array<U32> & Bool}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, t), i), (Tree.reify(U32, t), Packed.peek(t, i)), Buffer.tree_peek(t, i)) :
    {Bytes.at.go(needle, True{}, _, i) == (Tree.reify(U32, t), Buffer.matched(Bytes.at.go(needle, True{}, _, i))) : Array<U32> & Bool}
  Buffer.at_buffer(needle, True{}, t, Packed.peek(t, i), i)

def kind_five_value(hit: Bool, retry: Bool) -> U32:
  match hit:
    case True{}:
      2
    case False{}:
      Bool.pick(U32, retry, 4, 0)

def kind_five_result(+hit: Bool, +t: Tree.Tree<U32>, +i: U32) ->
  {Sse.kind.five(i, (Tree.reify(U32, t), hit)) ==
    (Tree.reify(U32, t), kind_five_value(hit, at_match("retry", t, i))) : Array<U32> & U32}:
  match hit:
    case True{}:
      {==}
    case False{}:
      %Equal.sym(Array<U32> & Bool, Bytes.at(Tree.reify(U32, t), "retry", i), (Tree.reify(U32, t), at_match("retry", t, i)), at_result("retry", t, i)) :
        {Sse.kind.is(4, _) == (Tree.reify(U32, t), kind_five_value(False{}, at_match("retry", t, i))) : Array<U32> & U32}
      {==}

def kind_value(n: U32, id: Bool, data: Bool, event: Bool, retry: Bool) -> U32:
  match n:
    case 2:
      Bool.pick(U32, id, 3, 0)
    case 4:
      Bool.pick(U32, data, 1, 0)
    case 5:
      kind_five_value(event, retry)
    case _:
      0

def kind_named(+k: U32, +needle: String, +t: Tree.Tree<U32>, +i: U32) ->
  {Sse.kind.is(k, Bytes.at(Tree.reify(U32, t), needle, i)) ==
    (Tree.reify(U32, t), Bool.pick(U32, at_match(needle, t, i), k, 0)) : Array<U32> & U32}:
  %Equal.sym(Array<U32> & Bool, Bytes.at(Tree.reify(U32, t), needle, i), (Tree.reify(U32, t), at_match(needle, t, i)), at_result(needle, t, i)) :
    {Sse.kind.is(k, _) == (Tree.reify(U32, t), Bool.pick(U32, at_match(needle, t, i), k, 0)) : Array<U32> & U32}
  {==}

def kind_event(+t: Tree.Tree<U32>, +i: U32) ->
  {Sse.kind(5, Tree.reify(U32, t), i) ==
    (Tree.reify(U32, t), kind_five_value(at_match("event", t, i), at_match("retry", t, i))) : Array<U32> & U32}:
  %Equal.sym(Array<U32> & Bool, Bytes.at(Tree.reify(U32, t), "event", i), (Tree.reify(U32, t), at_match("event", t, i)), at_result("event", t, i)) :
    {Sse.kind.five(i, _) == (Tree.reify(U32, t), kind_five_value(at_match("event", t, i), at_match("retry", t, i))) : Array<U32> & U32}
  kind_five_result(at_match("event", t, i), t, i)

# Split numeral bits explicitly: https://github.com/bendlang/bend/issues/1071.
def kind_result(+n: U32, +t: Tree.Tree<U32>, +i: U32) ->
  {Sse.kind(n, Tree.reify(U32, t), i) ==
    (Tree.reify(U32, t), kind_value(n, at_match("id", t, i), at_match("data", t, i), at_match("event", t, i), at_match("retry", t, i))) : Array<U32> & U32}:
  match n:
    case U32{w0}:
      match w0:
        case WCon{False{}, w1}:
          match w1:
            case WCon{False{}, w2}:
              match w2:
                case WCon{False{}, w3}:
                  {==}
                case WCon{True{}, w3}:
                  match w3:
                    case WCon{False{}, w4}:
                      match w4:
                        case WCon{False{}, w5}:
                          match w5:
                            case WCon{False{}, w6}:
                              match w6:
                                case WCon{False{}, w7}:
                                  match w7:
                                    case WCon{False{}, w8}:
                                      match w8:
                                        case WCon{False{}, w9}:
                                          match w9:
                                            case WCon{False{}, w10}:
                                              match w10:
                                                case WCon{False{}, w11}:
                                                  match w11:
                                                    case WCon{False{}, w12}:
                                                      match w12:
                                                        case WCon{False{}, w13}:
                                                          match w13:
                                                            case WCon{False{}, w14}:
                                                              match w14:
                                                                case WCon{False{}, w15}:
                                                                  match w15:
                                                                    case WCon{False{}, w16}:
                                                                      match w16:
                                                                        case WCon{False{}, w17}:
                                                                          match w17:
                                                                            case WCon{False{}, w18}:
                                                                              match w18:
                                                                                case WCon{False{}, w19}:
                                                                                  match w19:
                                                                                    case WCon{False{}, w20}:
                                                                                      match w20:
                                                                                        case WCon{False{}, w21}:
                                                                                          match w21:
                                                                                            case WCon{False{}, w22}:
                                                                                              match w22:
                                                                                                case WCon{False{}, w23}:
                                                                                                  match w23:
                                                                                                    case WCon{False{}, w24}:
                                                                                                      match w24:
                                                                                                        case WCon{False{}, w25}:
                                                                                                          match w25:
                                                                                                            case WCon{False{}, w26}:
                                                                                                              match w26:
                                                                                                                case WCon{False{}, w27}:
                                                                                                                  match w27:
                                                                                                                    case WCon{False{}, w28}:
                                                                                                                      match w28:
                                                                                                                        case WCon{False{}, w29}:
                                                                                                                          match w29:
                                                                                                                            case WCon{False{}, w30}:
                                                                                                                              match w30:
                                                                                                                                case WCon{False{}, w31}:
                                                                                                                                  match w31:
                                                                                                                                    case WCon{False{}, w32}:
                                                                                                                                      match w32:
                                                                                                                                        case WNil{}:
                                                                                                                                          kind_named(1, "data", t, i)
                                                                                                                                    case WCon{True{}, w32}:
                                                                                                                                      {==}
                                                                                                                                case WCon{True{}, w31}:
                                                                                                                                  {==}
                                                                                                                            case WCon{True{}, w30}:
                                                                                                                              {==}
                                                                                                                        case WCon{True{}, w29}:
                                                                                                                          {==}
                                                                                                                    case WCon{True{}, w28}:
                                                                                                                      {==}
                                                                                                                case WCon{True{}, w27}:
                                                                                                                  {==}
                                                                                                            case WCon{True{}, w26}:
                                                                                                              {==}
                                                                                                        case WCon{True{}, w25}:
                                                                                                          {==}
                                                                                                    case WCon{True{}, w24}:
                                                                                                      {==}
                                                                                                case WCon{True{}, w23}:
                                                                                                  {==}
                                                                                            case WCon{True{}, w22}:
                                                                                              {==}
                                                                                        case WCon{True{}, w21}:
                                                                                          {==}
                                                                                    case WCon{True{}, w20}:
                                                                                      {==}
                                                                                case WCon{True{}, w19}:
                                                                                  {==}
                                                                            case WCon{True{}, w18}:
                                                                              {==}
                                                                        case WCon{True{}, w17}:
                                                                          {==}
                                                                    case WCon{True{}, w16}:
                                                                      {==}
                                                                case WCon{True{}, w15}:
                                                                  {==}
                                                            case WCon{True{}, w14}:
                                                              {==}
                                                        case WCon{True{}, w13}:
                                                          {==}
                                                    case WCon{True{}, w12}:
                                                      {==}
                                                case WCon{True{}, w11}:
                                                  {==}
                                            case WCon{True{}, w10}:
                                              {==}
                                        case WCon{True{}, w9}:
                                          {==}
                                    case WCon{True{}, w8}:
                                      {==}
                                case WCon{True{}, w7}:
                                  {==}
                            case WCon{True{}, w6}:
                              {==}
                        case WCon{True{}, w5}:
                          {==}
                    case WCon{True{}, w4}:
                      {==}
            case WCon{True{}, w2}:
              match w2:
                case WCon{False{}, w3}:
                  match w3:
                    case WCon{False{}, w4}:
                      match w4:
                        case WCon{False{}, w5}:
                          match w5:
                            case WCon{False{}, w6}:
                              match w6:
                                case WCon{False{}, w7}:
                                  match w7:
                                    case WCon{False{}, w8}:
                                      match w8:
                                        case WCon{False{}, w9}:
                                          match w9:
                                            case WCon{False{}, w10}:
                                              match w10:
                                                case WCon{False{}, w11}:
                                                  match w11:
                                                    case WCon{False{}, w12}:
                                                      match w12:
                                                        case WCon{False{}, w13}:
                                                          match w13:
                                                            case WCon{False{}, w14}:
                                                              match w14:
                                                                case WCon{False{}, w15}:
                                                                  match w15:
                                                                    case WCon{False{}, w16}:
                                                                      match w16:
                                                                        case WCon{False{}, w17}:
                                                                          match w17:
                                                                            case WCon{False{}, w18}:
                                                                              match w18:
                                                                                case WCon{False{}, w19}:
                                                                                  match w19:
                                                                                    case WCon{False{}, w20}:
                                                                                      match w20:
                                                                                        case WCon{False{}, w21}:
                                                                                          match w21:
                                                                                            case WCon{False{}, w22}:
                                                                                              match w22:
                                                                                                case WCon{False{}, w23}:
                                                                                                  match w23:
                                                                                                    case WCon{False{}, w24}:
                                                                                                      match w24:
                                                                                                        case WCon{False{}, w25}:
                                                                                                          match w25:
                                                                                                            case WCon{False{}, w26}:
                                                                                                              match w26:
                                                                                                                case WCon{False{}, w27}:
                                                                                                                  match w27:
                                                                                                                    case WCon{False{}, w28}:
                                                                                                                      match w28:
                                                                                                                        case WCon{False{}, w29}:
                                                                                                                          match w29:
                                                                                                                            case WCon{False{}, w30}:
                                                                                                                              match w30:
                                                                                                                                case WCon{False{}, w31}:
                                                                                                                                  match w31:
                                                                                                                                    case WCon{False{}, w32}:
                                                                                                                                      match w32:
                                                                                                                                        case WNil{}:
                                                                                                                                          kind_named(3, "id", t, i)
                                                                                                                                    case WCon{True{}, w32}:
                                                                                                                                      {==}
                                                                                                                                case WCon{True{}, w31}:
                                                                                                                                  {==}
                                                                                                                            case WCon{True{}, w30}:
                                                                                                                              {==}
                                                                                                                        case WCon{True{}, w29}:
                                                                                                                          {==}
                                                                                                                    case WCon{True{}, w28}:
                                                                                                                      {==}
                                                                                                                case WCon{True{}, w27}:
                                                                                                                  {==}
                                                                                                            case WCon{True{}, w26}:
                                                                                                              {==}
                                                                                                        case WCon{True{}, w25}:
                                                                                                          {==}
                                                                                                    case WCon{True{}, w24}:
                                                                                                      {==}
                                                                                                case WCon{True{}, w23}:
                                                                                                  {==}
                                                                                            case WCon{True{}, w22}:
                                                                                              {==}
                                                                                        case WCon{True{}, w21}:
                                                                                          {==}
                                                                                    case WCon{True{}, w20}:
                                                                                      {==}
                                                                                case WCon{True{}, w19}:
                                                                                  {==}
                                                                            case WCon{True{}, w18}:
                                                                              {==}
                                                                        case WCon{True{}, w17}:
                                                                          {==}
                                                                    case WCon{True{}, w16}:
                                                                      {==}
                                                                case WCon{True{}, w15}:
                                                                  {==}
                                                            case WCon{True{}, w14}:
                                                              {==}
                                                        case WCon{True{}, w13}:
                                                          {==}
                                                    case WCon{True{}, w12}:
                                                      {==}
                                                case WCon{True{}, w11}:
                                                  {==}
                                            case WCon{True{}, w10}:
                                              {==}
                                        case WCon{True{}, w9}:
                                          {==}
                                    case WCon{True{}, w8}:
                                      {==}
                                case WCon{True{}, w7}:
                                  {==}
                            case WCon{True{}, w6}:
                              {==}
                        case WCon{True{}, w5}:
                          {==}
                    case WCon{True{}, w4}:
                      {==}
                case WCon{True{}, w3}:
                  {==}
        case WCon{True{}, w1}:
          match w1:
            case WCon{False{}, w2}:
              match w2:
                case WCon{False{}, w3}:
                  {==}
                case WCon{True{}, w3}:
                  match w3:
                    case WCon{False{}, w4}:
                      match w4:
                        case WCon{False{}, w5}:
                          match w5:
                            case WCon{False{}, w6}:
                              match w6:
                                case WCon{False{}, w7}:
                                  match w7:
                                    case WCon{False{}, w8}:
                                      match w8:
                                        case WCon{False{}, w9}:
                                          match w9:
                                            case WCon{False{}, w10}:
                                              match w10:
                                                case WCon{False{}, w11}:
                                                  match w11:
                                                    case WCon{False{}, w12}:
                                                      match w12:
                                                        case WCon{False{}, w13}:
                                                          match w13:
                                                            case WCon{False{}, w14}:
                                                              match w14:
                                                                case WCon{False{}, w15}:
                                                                  match w15:
                                                                    case WCon{False{}, w16}:
                                                                      match w16:
                                                                        case WCon{False{}, w17}:
                                                                          match w17:
                                                                            case WCon{False{}, w18}:
                                                                              match w18:
                                                                                case WCon{False{}, w19}:
                                                                                  match w19:
                                                                                    case WCon{False{}, w20}:
                                                                                      match w20:
                                                                                        case WCon{False{}, w21}:
                                                                                          match w21:
                                                                                            case WCon{False{}, w22}:
                                                                                              match w22:
                                                                                                case WCon{False{}, w23}:
                                                                                                  match w23:
                                                                                                    case WCon{False{}, w24}:
                                                                                                      match w24:
                                                                                                        case WCon{False{}, w25}:
                                                                                                          match w25:
                                                                                                            case WCon{False{}, w26}:
                                                                                                              match w26:
                                                                                                                case WCon{False{}, w27}:
                                                                                                                  match w27:
                                                                                                                    case WCon{False{}, w28}:
                                                                                                                      match w28:
                                                                                                                        case WCon{False{}, w29}:
                                                                                                                          match w29:
                                                                                                                            case WCon{False{}, w30}:
                                                                                                                              match w30:
                                                                                                                                case WCon{False{}, w31}:
                                                                                                                                  match w31:
                                                                                                                                    case WCon{False{}, w32}:
                                                                                                                                      match w32:
                                                                                                                                        case WNil{}:
                                                                                                                                          kind_event(t, i)
                                                                                                                                    case WCon{True{}, w32}:
                                                                                                                                      {==}
                                                                                                                                case WCon{True{}, w31}:
                                                                                                                                  {==}
                                                                                                                            case WCon{True{}, w30}:
                                                                                                                              {==}
                                                                                                                        case WCon{True{}, w29}:
                                                                                                                          {==}
                                                                                                                    case WCon{True{}, w28}:
                                                                                                                      {==}
                                                                                                                case WCon{True{}, w27}:
                                                                                                                  {==}
                                                                                                            case WCon{True{}, w26}:
                                                                                                              {==}
                                                                                                        case WCon{True{}, w25}:
                                                                                                          {==}
                                                                                                    case WCon{True{}, w24}:
                                                                                                      {==}
                                                                                                case WCon{True{}, w23}:
                                                                                                  {==}
                                                                                            case WCon{True{}, w22}:
                                                                                              {==}
                                                                                        case WCon{True{}, w21}:
                                                                                          {==}
                                                                                    case WCon{True{}, w20}:
                                                                                      {==}
                                                                                case WCon{True{}, w19}:
                                                                                  {==}
                                                                            case WCon{True{}, w18}:
                                                                              {==}
                                                                        case WCon{True{}, w17}:
                                                                          {==}
                                                                    case WCon{True{}, w16}:
                                                                      {==}
                                                                case WCon{True{}, w15}:
                                                                  {==}
                                                            case WCon{True{}, w14}:
                                                              {==}
                                                        case WCon{True{}, w13}:
                                                          {==}
                                                    case WCon{True{}, w12}:
                                                      {==}
                                                case WCon{True{}, w11}:
                                                  {==}
                                            case WCon{True{}, w10}:
                                              {==}
                                        case WCon{True{}, w9}:
                                          {==}
                                    case WCon{True{}, w8}:
                                      {==}
                                case WCon{True{}, w7}:
                                  {==}
                            case WCon{True{}, w6}:
                              {==}
                        case WCon{True{}, w5}:
                          {==}
                    case WCon{True{}, w4}:
                      {==}
            case WCon{True{}, w2}:
              {==}

def kind_index(+n: U32, +t: Tree.Tree<U32>, +i: U32) -> U32:
  Buffer.index(Sse.kind(n, Tree.reify(U32, t), i))

def kind_index_result(+n: U32, +t: Tree.Tree<U32>, +i: U32) ->
  {kind_index(n, t, i) == kind_value(n, at_match("id", t, i), at_match("data", t, i), at_match("event", t, i), at_match("retry", t, i)) : U32}:
  Equal.cong(Array<U32> & U32, U32, Buffer.index,
    Sse.kind(n, Tree.reify(U32, t), i),
    (Tree.reify(U32, t), kind_value(n, at_match("id", t, i), at_match("data", t, i), at_match("event", t, i), at_match("retry", t, i))),
    kind_result(n, t, i))

def kind_value_equal(+n: U32, +ia: Bool, +da: Bool, +ea: Bool, +ra: Bool, +ib: Bool, +db: Bool, +eb: Bool, +rb: Bool,
  id: {ia == ib : Bool}, data: {da == db : Bool}, event: {ea == eb : Bool}, retry: {ra == rb : Bool}) ->
  {kind_value(n, ia, da, ea, ra) == kind_value(n, ib, db, eb, rb) : U32}:
  %Equal.sym(Bool, ia, ib, id) : {kind_value(n, _, da, ea, ra) == kind_value(n, ib, db, eb, rb) : U32}
  %Equal.sym(Bool, da, db, data) : {kind_value(n, ib, _, ea, ra) == kind_value(n, ib, db, eb, rb) : U32}
  %Equal.sym(Bool, ea, eb, event) : {kind_value(n, ib, db, _, ra) == kind_value(n, ib, db, eb, rb) : U32}
  %Equal.sym(Bool, ra, rb, retry) : {kind_value(n, ib, db, eb, _) == kind_value(n, ib, db, eb, rb) : U32}
  {==}

def kind_observed(+n: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +j: U32,
  two: {Buffer.observed(2n, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(2n, Bytes.peek(Tree.reify(U32, b), j), j) : String},
  four: {Buffer.observed(4n, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(4n, Bytes.peek(Tree.reify(U32, b), j), j) : String},
  +five: {Buffer.observed(5n, Bytes.peek(Tree.reify(U32, a), i), i) == Buffer.observed(5n, Bytes.peek(Tree.reify(U32, b), j), j) : String}) ->
  {kind_index(n, a, i) == kind_index(n, b, j) : U32}:
  Equal.trans(U32, kind_index(n, a, i), kind_value(n, at_match("id", a, i), at_match("data", a, i), at_match("event", a, i), at_match("retry", a, i)), kind_index(n, b, j),
    kind_index_result(n, a, i),
    Equal.trans(U32,
      kind_value(n, at_match("id", a, i), at_match("data", a, i), at_match("event", a, i), at_match("retry", a, i)),
      kind_value(n, at_match("id", b, j), at_match("data", b, j), at_match("event", b, j), at_match("retry", b, j)), kind_index(n, b, j),
      kind_value_equal(n, at_match("id", a, i), at_match("data", a, i), at_match("event", a, i), at_match("retry", a, i),
        at_match("id", b, j), at_match("data", b, j), at_match("event", b, j), at_match("retry", b, j),
        Buffer.at_observed("id", True{}, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j, two),
        Buffer.at_observed("data", True{}, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j, four),
        Buffer.at_observed("event", True{}, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j, five),
        Buffer.at_observed("retry", True{}, Bytes.peek(Tree.reify(U32, a), i), Bytes.peek(Tree.reify(U32, b), j), i, j, five)),
      Equal.sym(U32, kind_index(n, b, j), kind_value(n, at_match("id", b, j), at_match("data", b, j), at_match("event", b, j), at_match("retry", b, j)), kind_index_result(n, b, j))))

def shift_other(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +prev: U32, +k: U32, +d: U32, +w: U32, +j: U32,
  h: Packed.Outside(n, dst, d, j)) ->
  {Tree.read(U32, Packed.copy.shift(n, src, dst, lo, hi, prev, k, d, w), j) == Tree.read(U32, dst, j) : U32}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      (head, tail) = h
      +v = (U32.shrn(prev, lo) .|. U32.shln(w, hi) : U32)
      Equal.trans(U32, Tree.read(U32, Packed.copy.shift(n, src, dst, lo, hi, prev, k, d, w), j),
        Tree.read(U32, Packed.set(dst, d, v), j), Tree.read(U32, dst, j),
        shift_other(p, src, Packed.set(dst, d, v), lo, hi, w, (k + 1 : U32), (d + 1 : U32), Tree.read(U32, src, (k + 1 : U32)), j,
          Packed.outside_set(p, dst, (d + 1 : U32), j, d, v, tail)),
        Packed.read_set_other(dst, d, j, v, head))

def shift_first(+n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +prev: U32, +k: U32, +d: U32, +w: U32,
  h: Packed.Outside(n, dst, (d + 1 : U32), d)) ->
  {Tree.read(U32, Packed.copy.shift(1n+n, src, dst, lo, hi, prev, k, d, w), d) ==
    (U32.shrn(prev, lo) .|. U32.shln(w, hi) : U32) : U32}:
  +v = (U32.shrn(prev, lo) .|. U32.shln(w, hi) : U32)
  Equal.trans(U32, Tree.read(U32, Packed.copy.shift(1n+n, src, dst, lo, hi, prev, k, d, w), d),
    Tree.read(U32, Packed.set(dst, d, v), d), v,
    shift_other(n, src, Packed.set(dst, d, v), lo, hi, w, (k + 1 : U32), (d + 1 : U32), Tree.read(U32, src, (k + 1 : U32)), d,
      Packed.outside_set(n, dst, (d + 1 : U32), d, d, v, h)),
    Packed.read_set(dst, d, v))

def shift_source(i: Nat, +src: Tree.Tree<U32>, +lo: Nat, +hi: Nat, prev: U32, +k: U32, +w: U32) -> U32:
  match i:
    case 0n:
      (U32.shrn(prev, lo) .|. U32.shln(w, hi) : U32)
    case 1n+p:
      shift_source(p, src, lo, hi, w, (k + 1 : U32), Tree.read(U32, src, (k + 1 : U32)))

def shift_at(i: Nat, +n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +prev: U32, +k: U32, +d: U32, +w: U32,
  h: Packed.Outside(n, dst, Packed.advance(1n+i, d), Packed.advance(i, d))) ->
  {Tree.read(U32, Packed.copy.shift(Nat.add(i, 1n+n), src, dst, lo, hi, prev, k, d, w), Packed.advance(i, d)) ==
    shift_source(i, src, lo, hi, prev, k, w) : U32}:
  match i:
    case 0n:
      shift_first(n, src, dst, lo, hi, prev, k, d, w, h)
    case 1n+ +p:
      +v = (U32.shrn(prev, lo) .|. U32.shln(w, hi) : U32)
      shift_at(p, n, src, Packed.set(dst, d, v), lo, hi, w, (k + 1 : U32), (d + 1 : U32), Tree.read(U32, src, (k + 1 : U32)),
        Packed.outside_set(n, dst, Packed.advance(1n+p, (d + 1 : U32)), Packed.advance(p, (d + 1 : U32)), d, v, h))

def shift_source_value(i: Nat, +src: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +s: U32) ->
  {shift_source(i, src, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), Tree.read(U32, src, (s + 1 : U32))) ==
    (U32.shrn(Tree.read(U32, src, Packed.advance(i, s)), lo) .|.
      U32.shln(Tree.read(U32, src, Packed.advance(1n+i, s)), hi) : U32) : U32}:
  match i:
    case 0n:
      {==}
    case 1n+ +p:
      shift_source_value(p, src, lo, hi, (s + 1 : U32))

def shift_value(+i: Nat, +n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +s: U32, +d: U32,
  h: Packed.Outside(n, dst, Packed.advance(1n+i, d), Packed.advance(i, d))) ->
  {Tree.read(U32, Packed.copy.shift(Nat.add(i, 1n+n), src, dst, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), d,
    Tree.read(U32, src, (s + 1 : U32))), Packed.advance(i, d)) ==
    (U32.shrn(Tree.read(U32, src, Packed.advance(i, s)), lo) .|.
      U32.shln(Tree.read(U32, src, Packed.advance(1n+i, s)), hi) : U32) : U32}:
  Equal.trans(U32,
    Tree.read(U32, Packed.copy.shift(Nat.add(i, 1n+n), src, dst, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), d,
      Tree.read(U32, src, (s + 1 : U32))), Packed.advance(i, d)),
    shift_source(i, src, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), Tree.read(U32, src, (s + 1 : U32))),
    (U32.shrn(Tree.read(U32, src, Packed.advance(i, s)), lo) .|. U32.shln(Tree.read(U32, src, Packed.advance(1n+i, s)), hi) : U32),
    shift_at(i, n, src, dst, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), d, Tree.read(U32, src, (s + 1 : U32)), h),
    shift_source_value(i, src, lo, hi, s))

def joined_low(+a: U32, +b: U32, +lo: Nat, +hi: Nat, h: MNat.le(8n, hi)) ->
  {Local.b8((U32.shrn(a, lo) .|. U32.shln(b, hi) : U32)) == Local.b8(U32.shrn(a, lo)) : U32}:
  +x = U32.shrn(a, lo)
  +y = U32.shln(b, hi)
  %Equal.sym(U32, Local.b8((x .|. y : U32)), U32{Field.low(32n, 8n, Field.word((x .|. y : U32)))}, Field.and_mask_word((x .|. y : U32), 8)) :
    {_ == Local.b8(x) : U32}
  %Equal.sym(Word(32n), Field.word((x .|. y : U32)), Word.or(32n, Field.word(x), Field.word(y)), Field.word_or(x, y)) :
    {U32{Field.low(32n, 8n, _)} == Local.b8(x) : U32}
  %Equal.sym(Word(32n), Field.word(y), Field.wshl(hi, 32n, Field.word(b)), Field.word_shln(hi, b)) :
    {U32{Field.low(32n, 8n, Word.or(32n, Field.word(x), _))} == Local.b8(x) : U32}
  Equal.trans(U32,
    U32{Field.low(32n, 8n, Word.or(32n, Field.word(x), Field.wshl(hi, 32n, Field.word(b))))},
    U32{Field.low(32n, 8n, Field.word(x))}, Local.b8(x),
    Equal.cong(Word(32n), U32, w => U32{w},
      Field.low(32n, 8n, Word.or(32n, Field.word(x), Field.wshl(hi, 32n, Field.word(b)))), Field.low(32n, 8n, Field.word(x)),
      Field.low_or_shift(32n, 8n, hi, Field.word(x), Field.word(b), h)),
    Equal.sym(U32, Local.b8(x), U32{Field.low(32n, 8n, Field.word(x))}, Field.and_mask_word(x, 8)))

def shift_bounded(+i: Nat, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +s: U32, +d: U32, +limit: Nat,
  shape: Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hl: MNat.le(limit, 1n+Lemmas.pow2(depth)), hu: MNat.le(limit, Lemmas.pow2(32n)),
  end: MNat.lt(Nat.add(n, 1n+Nat.add(i, U32.to_nat(d))), limit)) ->
  {Tree.read(U32, Packed.copy.shift(Nat.add(i, 1n+n), src, dst, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), d,
    Tree.read(U32, src, (s + 1 : U32))), Packed.advance(i, d)) ==
    (U32.shrn(Tree.read(U32, src, Packed.advance(i, s)), lo) .|.
      U32.shln(Tree.read(U32, src, Packed.advance(1n+i, s)), hi) : U32) : U32}:
  shift_value(i, n, src, dst, lo, hi, s, d, Packed.outside_offset(i, n, depth, dst, d, limit, shape, hd, hl, hu, end))

def shift_tail_value(+i: Nat, +n: Nat, +tail: U32, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat,
  +s: U32, +d: U32, +st: U32, +dt: U32, +word_limit: Nat, +byte_limit: Nat,
  hs: Bound.shape(depth, Packed.as_bits(dst)) & Bound.shape(depth, Packed.as_bits(dst)), +hd: MNat.lt(depth, 32n),
  hwl: MNat.le(word_limit, 1n+Lemmas.pow2(depth)), hwu: MNat.le(word_limit, Lemmas.pow2(32n)),
  hbl: MNat.le(byte_limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hbu: MNat.le(byte_limit, Lemmas.pow2(32n)),
  hw: MNat.lt(Nat.add(n, 1n+Nat.add(i, U32.to_nat(d))), word_limit),
  hb: MNat.lt(Nat.add(U32.to_nat(tail), U32.to_nat(dt)), byte_limit),
  hj: MNat.lt(U32.to_nat(Packed.advance(i, d)), U32.to_nat((dt >> 2n : U32)))) ->
  {Tree.read(U32, Packed.copy.bytes(tail, src,
    Packed.copy.shift(Nat.add(i, 1n+n), src, dst, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), d, Tree.read(U32, src, (s + 1 : U32))),
    st, dt), Packed.advance(i, d)) ==
    (U32.shrn(Tree.read(U32, src, Packed.advance(i, s)), lo) .|.
      U32.shln(Tree.read(U32, src, Packed.advance(1n+i, s)), hi) : U32) : U32}:
  (ha, hbshape) = hs
  +words = Packed.copy.shift(Nat.add(i, 1n+n), src, dst, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), d, Tree.read(U32, src, (s + 1 : U32)))
  Equal.trans(U32, Tree.read(U32, Packed.copy.bytes(tail, src, words, st, dt), Packed.advance(i, d)),
    Tree.read(U32, words, Packed.advance(i, d)),
    (U32.shrn(Tree.read(U32, src, Packed.advance(i, s)), lo) .|. U32.shln(Tree.read(U32, src, Packed.advance(1n+i, s)), hi) : U32),
    Packed.copy.go_frame(U32.to_nat(tail), depth, src, words, st, dt, Packed.peek(src, st), Packed.advance(i, d), byte_limit,
      Packed.copy.shift_shape(Nat.add(i, 1n+n), depth, src, dst, lo, hi, Tree.read(U32, src, s), (s + 1 : U32), d, Tree.read(U32, src, (s + 1 : U32)), ha),
      hd, hbl, hbu, hj, hb),
    shift_bounded(i, n, depth, src, dst, lo, hi, s, d, word_limit, hbshape, hd, hwl, hwu, hw))

def shift_hi_normal(a: Bool, b: Bool) ->
  MNat.le(8n, U32.to_nat((32 - (U32{WCon{a, WCon{b, Word.zero(30n)}}} * 8) : U32))):
  match a b:
    case False{} False{}:
      {==}
    case False{} True{}:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def shift_hi_bits(+a: Bool, +b: Bool, +t: Word(30n)) ->
  MNat.le(8n, U32.to_nat((32 - ((U32{WCon{a, WCon{b, t}}} .&. 3) * 8) : U32))):
  %Equal.sym(U32, (U32{WCon{a, WCon{b, t}}} .&. 3 : U32), U32{WCon{a, WCon{b, Word.zero(30n)}}}, Packed.low2(a, b, t)) :
    MNat.le(8n, U32.to_nat((32 - (_ * 8) : U32)))
  shift_hi_normal(a, b)

def shift_hi(+s: U32) -> MNat.le(8n, U32.to_nat((32 - ((s .&. 3) * 8) : U32))):
  match s:
    case U32{WCon{+a, WCon{+b, +t}}}:
      shift_hi_bits(a, b, t)

# Keep scalar transport opaque to avoid expansion: https://github.com/bendlang/bend/issues/1071.
def peek_zero_value(+t: Tree.Tree<U32>, +v: U32, e: {Tree.read(U32, t, 0) == v : U32}) ->
  {Packed.peek(t, 0) == Local.b8(v) : U32}:
  Equal.cong(U32, U32, x => Local.b8(x), Tree.read(U32, t, 0), v, e)

def shift_tail_low(+n: Nat, +tail: U32, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>,
  +lo: Nat, +hi: Nat, +sw: U32, +st: U32, +dt: U32, +word_limit: Nat, +byte_limit: Nat,
  hs: Bound.shape(depth, Packed.as_bits(dst)) & Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hwl: MNat.le(word_limit, 1n+Lemmas.pow2(depth)), hwu: MNat.le(word_limit, Lemmas.pow2(32n)),
  hbl: MNat.le(byte_limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hbu: MNat.le(byte_limit, Lemmas.pow2(32n)),
  hw: MNat.lt(Nat.add(n, 1n), word_limit),
  hb: MNat.lt(Nat.add(U32.to_nat(tail), U32.to_nat(dt)), byte_limit),
  hj: MNat.lt(0n, U32.to_nat((dt >> 2n : U32))), hhi: MNat.le(8n, hi)) ->
  {Packed.peek(Packed.copy.bytes(tail, src,
    Packed.copy.shift(1n+n, src, dst, lo, hi, Tree.read(U32, src, sw), (sw + 1 : U32), 0, Tree.read(U32, src, (sw + 1 : U32))),
    st, dt), 0) == Local.b8(U32.shrn(Tree.read(U32, src, sw), lo)) : U32}:
  +a = Tree.read(U32, src, sw)
  +b = Tree.read(U32, src, (sw + 1 : U32))
  +words = Packed.copy.shift(1n+n, src, dst, lo, hi, a, (sw + 1 : U32), 0, b)
  Equal.trans(U32, Packed.peek(Packed.copy.bytes(tail, src, words, st, dt), 0), Local.b8((U32.shrn(a, lo) .|. U32.shln(b, hi) : U32)), Local.b8(U32.shrn(a, lo)),
    peek_zero_value(Packed.copy.bytes(tail, src, words, st, dt), (U32.shrn(a, lo) .|. U32.shln(b, hi) : U32),
      shift_tail_value(0n, n, tail, depth, src, dst, lo, hi, sw, 0, st, dt, word_limit, byte_limit, hs, hd, hwl, hwu, hbl, hbu, hw, hb, hj)),
    joined_low(a, b, lo, hi, hhi))

def shift_tail_head_fuel(+f: Nat, +n: Nat, +tail: U32, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>,
  +lo: Nat, +hi: Nat, +sw: U32, +st: U32, +dt: U32, +word_limit: Nat, +byte_limit: Nat,
  hs: Bound.shape(depth, Packed.as_bits(dst)) & Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hwl: MNat.le(word_limit, 1n+Lemmas.pow2(depth)), hwu: MNat.le(word_limit, Lemmas.pow2(32n)),
  hbl: MNat.le(byte_limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hbu: MNat.le(byte_limit, Lemmas.pow2(32n)),
  hw: MNat.lt(Nat.add(n, 1n), word_limit),
  hb: MNat.lt(Nat.add(U32.to_nat(tail), U32.to_nat(dt)), byte_limit),
  hj: MNat.lt(0n, U32.to_nat((dt >> 2n : U32))), hhi: MNat.le(8n, hi), e: {f == 1n+n : Nat}) ->
  {Packed.peek(Packed.copy.bytes(tail, src,
    Packed.copy.shift(f, src, dst, lo, hi, Tree.read(U32, src, sw), (sw + 1 : U32), 0, Tree.read(U32, src, (sw + 1 : U32))),
    st, dt), 0) == Local.b8(U32.shrn(Tree.read(U32, src, sw), lo)) : U32}:
  %Equal.sym(Nat, f, 1n+n, e) :
    {Packed.peek(Packed.copy.bytes(tail, src,
      Packed.copy.shift(_, src, dst, lo, hi, Tree.read(U32, src, sw), (sw + 1 : U32), 0, Tree.read(U32, src, (sw + 1 : U32))),
      st, dt), 0) == Local.b8(U32.shrn(Tree.read(U32, src, sw), lo)) : U32}
  shift_tail_low(n, tail, depth, src, dst, lo, hi, sw, st, dt, word_limit, byte_limit, hs, hd, hwl, hwu, hbl, hbu, hw, hb, hj, hhi)

def tail_start_positive.of(+dt: U32, +k: U32, +w: U32, +n: Nat,
  ed: {dt == k : U32}, ek: {U32.to_nat(k) == Nat.mul(U32.to_nat(w), 4n) : Nat}, ew: {U32.to_nat(w) == 1n+n : Nat}) ->
  MNat.lt(0n, U32.to_nat((dt >> 2n : U32))):
  %Equal.sym(U32, dt, k, ed) : MNat.lt(0n, U32.to_nat((_ >> 2n : U32)))
  %Equal.sym(Nat, U32.to_nat((k >> 2n : U32)), U32.to_nat(w), Packed.block_word_nat(k, w, ek)) : MNat.lt(0n, _)
  %Equal.sym(Nat, U32.to_nat(w), 1n+n, ew) : MNat.lt(0n, _)
  {==}

def tail_start_positive(+k: U32, +w: U32, +n: Nat, +limit: Nat,
  ek: {U32.to_nat(k) == Nat.mul(U32.to_nat(w), 4n) : Nat}, ew: {U32.to_nat(w) == 1n+n : Nat},
  hk: MNat.lt(U32.to_nat(k), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) ->
  MNat.lt(0n, U32.to_nat(((0 + k) >> 2n : U32))):
  tail_start_positive.of((0 + k : U32), k, w, n, Packed.zero_add(k, limit, hk, hu), ek, ew)

def shifted_head_full(+m: U32, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>,
  +s: U32, +word_limit: Nat, +byte_limit: Nat,
  hs: Bound.shape(depth, Packed.as_bits(dst)) & Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hwl: MNat.le(word_limit, 1n+Lemmas.pow2(depth)), hwu: MNat.le(word_limit, Lemmas.pow2(32n)),
  hbl: MNat.le(byte_limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), +hbu: MNat.le(byte_limit, Lemmas.pow2(32n)),
  +ew: {U32.to_nat((m >> 2n : U32)) == 1n+n : Nat},
  hw: MNat.lt(Nat.add(n, 1n), word_limit),
  +end: MNat.lt(Nat.add(U32.to_nat(m), 0n), byte_limit)) ->
  {Packed.peek(Packed.copy.pick(False{}, m, src, dst, s, 0), 0) == Packed.peek(src, s) : U32}:
  +w = (m >> 2n : U32)
  +k = (w * 4 : U32)
  +hm : MNat.lt(U32.to_nat(m), byte_limit) = (
    %MNat.add_zero(U32.to_nat(m)) : MNat.lt(_, byte_limit)
    end)
  +ek = Packed.copied_block_nat(m, byte_limit, hm, hbu)
  +hk : MNat.le(U32.to_nat(k), U32.to_nat(m)) = (
    %Equal.sym(Nat, U32.to_nat(k), Nat.mul(U32.to_nat(w), 4n), ek) : MNat.le(_, U32.to_nat(m))
    Packed.copied_words_cover(m))
  +hj = tail_start_positive(k, w, n, byte_limit, ek, ew,
    MNat.lt_of_le_of_lt(U32.to_nat(k), U32.to_nat(m), byte_limit, hk, hm), hbu)
  shift_tail_head_fuel(U32.to_nat(w), n, (m - k : U32), depth, src, dst, Local.shift(s), U32.to_nat((32 - ((s .&. 3) * 8) : U32)),
    (s >> 2n : U32), (s + k : U32), (0 + k : U32), word_limit, byte_limit,
    hs, hd, hwl, hwu, hbl, hbu, hw, Packed.copied_tail_end(m, 0, byte_limit, end, hbu), hj, shift_hi(s), ew)


def bytes_head(+m: U32, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +limit: Nat,
  shape: Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hl: MNat.le(limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hu: MNat.le(limit, Lemmas.pow2(32n)),
  end: MNat.lt(Nat.add(n, 1n), limit), em: {U32.to_nat(m) == 1n+n : Nat}) ->
  {Packed.peek(Packed.copy.bytes(m, src, dst, s, 0), 0) == Packed.peek(src, s) : U32}:
  %Equal.sym(Nat, U32.to_nat(m), 1n+n, em) :
    {Packed.peek(Packed.copy.go(_, src, dst, s, 0, Packed.peek(src, s)), 0) == Packed.peek(src, s) : U32}
  Packed.copy.bytes_bounded(0n, n, depth, src, dst, s, 0, limit, shape, hd, hl, hu, end)

def below_equal(+a: Nat, +b: Nat, +limit: Nat, e: {a == b : Nat}, h: MNat.lt(b, limit)) -> MNat.lt(a, limit):
  %Equal.sym(Nat, a, b, e) : MNat.lt(_, limit)
  h

def right_zero_sum(+a: Nat, +b: Nat, eb: {b == 0n : Nat}) -> {Nat.add(a, b) == a : Nat}:
  Equal.trans(Nat, Nat.add(a, b), Nat.add(b, a), a, MNat.add_comm(a, b), Packed.zero_sum_nat(b, a, eb))

def add_zero_nat(+s: U32, +z: U32, ez: {U32.to_nat(z) == 0n : Nat}) -> {s == (s + z : U32) : U32}:
  +es = right_zero_sum(U32.to_nat(s), U32.to_nat(z), ez)
  Equal.sym(U32, (s + z : U32), s,
    Lemmas.u32_to_nat_inj((s + z : U32), s,
      Equal.trans(Nat, U32.to_nat((s + z : U32)), Nat.add(U32.to_nat(s), U32.to_nat(z)), U32.to_nat(s),
        Lemmas.u32_add_nat(s, z,
          below_equal(Nat.add(U32.to_nat(s), U32.to_nat(z)), U32.to_nat(s), Lemmas.pow2(32n), es, Lemmas.u32_to_nat_lt(s))), es)))

def sub_zero_nat(+s: U32, +z: U32, +ez: {U32.to_nat(z) == 0n : Nat}) -> {s == (s - z : U32) : U32}:
  +hz : MNat.le(U32.to_nat(z), U32.to_nat(s)) = (
    %Equal.sym(Nat, U32.to_nat(z), 0n, ez) : MNat.le(_, U32.to_nat(s))
    MNat.zero_le(U32.to_nat(s)))
  Equal.sym(U32, (s - z : U32), s,
    Lemmas.u32_to_nat_inj((s - z : U32), s,
      Equal.trans(Nat, U32.to_nat((s - z : U32)), Nat.sub(U32.to_nat(s), U32.to_nat(z)), U32.to_nat(s),
        Lemmas.u32_sub_nat(s, z, hz),
        (%Equal.sym(Nat, U32.to_nat(z), 0n, ez) : {Nat.sub(U32.to_nat(s), _) == U32.to_nat(s) : Nat}
         MNat.sub_zero(U32.to_nat(s))))))

def shifted_head_zero(+m: U32, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +limit: Nat,
  shape: Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hl: MNat.le(limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hu: MNat.le(limit, Lemmas.pow2(32n)),
  end: MNat.lt(Nat.add(n, 1n), limit), em: {U32.to_nat(m) == 1n+n : Nat}, ew: {U32.to_nat((m >> 2n : U32)) == 0n : Nat}) ->
  {Packed.peek(Packed.copy.pick(False{}, m, src, dst, s, 0), 0) == Packed.peek(src, s) : U32}:
  %Equal.sym(U32, (m >> 2n : U32), 0, Lemmas.u32_to_nat_inj((m >> 2n : U32), 0, ew)) :
    {Packed.peek(Packed.copy.bytes((m - (_ * 4) : U32), src,
      Packed.copy.shift.at(_, ((s .&. 3) * 8 : U32), (s >> 2n : U32), 0, src, dst),
      (s + (_ * 4) : U32), (0 + (_ * 4) : U32)), 0) == Packed.peek(src, s) : U32}
  %sub_zero_nat(m, 0, {==}) :
    {Packed.peek(Packed.copy.bytes(_, src, dst, (s + 0 : U32), 0), 0) == Packed.peek(src, s) : U32}
  %add_zero_nat(s, 0, {==}) :
    {Packed.peek(Packed.copy.bytes(m, src, dst, _, 0), 0) == Packed.peek(src, s) : U32}
  bytes_head(m, n, depth, src, dst, s, limit, shape, hd, hl, hu, end, em)

def shifted_head_split(f: Nat, +m: U32, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>,
  +s: U32, +word_limit: Nat, +byte_limit: Nat,
  hs: Bound.shape(depth, Packed.as_bits(dst)) & Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hwl: MNat.le(word_limit, 1n+Lemmas.pow2(depth)), hwu: MNat.le(word_limit, Lemmas.pow2(32n)),
  hbl: MNat.le(byte_limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hbu: MNat.le(byte_limit, Lemmas.pow2(32n)),
  hw: MNat.lt(f, word_limit), +hn: MNat.lt(Nat.add(n, 1n), byte_limit),
  +em: {U32.to_nat(m) == 1n+n : Nat}, ef: {f == U32.to_nat((m >> 2n : U32)) : Nat}) ->
  {Packed.peek(Packed.copy.pick(False{}, m, src, dst, s, 0), 0) == Packed.peek(src, s) : U32}:
  match f:
    case 0n:
      (ha, hb) = hs
      shifted_head_zero(m, n, depth, src, dst, s, byte_limit, ha, hd, hbl, hbu, hn, em,
        Equal.sym(Nat, 0n, U32.to_nat((m >> 2n : U32)), ef))
    case 1n+ +p:
      +end : MNat.lt(Nat.add(U32.to_nat(m), 0n), byte_limit) = (
        below_equal(Nat.add(U32.to_nat(m), 0n), Nat.add(n, 1n), byte_limit,
          Equal.trans(Nat, Nat.add(U32.to_nat(m), 0n), U32.to_nat(m), Nat.add(n, 1n), MNat.add_zero(U32.to_nat(m)),
            Equal.trans(Nat, U32.to_nat(m), 1n+n, Nat.add(n, 1n), em, MNat.add_comm(1n, n))), hn))
      shifted_head_full(m, p, depth, src, dst, s, word_limit, byte_limit, hs, hd, hwl, hwu, hbl, hbu,
        Equal.sym(Nat, 1n+p, U32.to_nat((m >> 2n : U32)), ef),
        below_equal(Nat.add(p, 1n), 1n+p, word_limit, MNat.add_comm(p, 1n), hw), end)

def shifted_head(+m: U32, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>,
  +s: U32, +word_limit: Nat, +byte_limit: Nat,
  shape: Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hwl: MNat.le(word_limit, 1n+Lemmas.pow2(depth)), hwu: MNat.le(word_limit, Lemmas.pow2(32n)),
  hbl: MNat.le(byte_limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hbu: MNat.le(byte_limit, Lemmas.pow2(32n)),
  hw: MNat.lt(U32.to_nat((m >> 2n : U32)), word_limit), hn: MNat.lt(Nat.add(n, 1n), byte_limit),
  em: {U32.to_nat(m) == 1n+n : Nat}) ->
  {Packed.peek(Packed.copy.pick(False{}, m, src, dst, s, 0), 0) == Packed.peek(src, s) : U32}:
  shifted_head_split(U32.to_nat((m >> 2n : U32)), m, n, depth, src, dst, s, word_limit, byte_limit,
    Bound.shape_copy(depth, Packed.as_bits(dst), shape), hd, hwl, hwu, hbl, hbu, hw, hn, em, {==})

def peek_value(+t: Tree.Tree<U32>, +i: U32) ->
  {Buffer.index(Bytes.peek(Tree.reify(U32, t), i)) == Packed.peek(t, i) : U32}:
  Equal.cong(Array<U32> & U32, U32, Buffer.index, Bytes.peek(Tree.reify(U32, t), i),
    (Tree.reify(U32, t), Packed.peek(t, i)), Buffer.tree_peek(t, i))

def shifted_copy_head(+m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32) -> U32:
  Buffer.index(Bytes.peek(Bytes.dst(Bytes.copy.pick(False{}, m, Tree.reify(U32, src), Tree.reify(U32, dst), s, 0)), 0))

def shifted_head_observed(+m: U32, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>,
  +s: U32, +word_limit: Nat, +byte_limit: Nat,
  shape: Bound.shape(depth, Packed.as_bits(dst)), hd: MNat.lt(depth, 32n),
  hwl: MNat.le(word_limit, 1n+Lemmas.pow2(depth)), hwu: MNat.le(word_limit, Lemmas.pow2(32n)),
  hbl: MNat.le(byte_limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hbu: MNat.le(byte_limit, Lemmas.pow2(32n)),
  hw: MNat.lt(U32.to_nat((m >> 2n : U32)), word_limit), hn: MNat.lt(Nat.add(n, 1n), byte_limit),
  em: {U32.to_nat(m) == 1n+n : Nat}) ->
  {shifted_copy_head(m, src, dst, s) == Buffer.index(Bytes.peek(Tree.reify(U32, src), s)) : U32}:
  +out = Packed.copy.pick(False{}, m, src, dst, s, 0)
  %Equal.sym(Array<U32> & Array<U32>,
    Bytes.copy.pick(False{}, m, Tree.reify(U32, src), Tree.reify(U32, dst), s, 0),
    (Tree.reify(U32, src), Tree.reify(U32, out)), copy_pick_bridge(False{}, m, src, dst, s, 0)) :
    {Buffer.index(Bytes.peek(Bytes.dst(_), 0)) == Buffer.index(Bytes.peek(Tree.reify(U32, src), s)) : U32}
  Equal.trans(U32, Buffer.index(Bytes.peek(Tree.reify(U32, out), 0)), Packed.peek(out, 0), Buffer.index(Bytes.peek(Tree.reify(U32, src), s)),
    peek_value(out, 0),
    Equal.trans(U32, Packed.peek(out, 0), Packed.peek(src, s), Buffer.index(Bytes.peek(Tree.reify(U32, src), s)),
      shifted_head(m, n, depth, src, dst, s, word_limit, byte_limit, shape, hd, hwl, hwu, hbl, hbu, hw, hn, em),
      Equal.sym(U32, Buffer.index(Bytes.peek(Tree.reify(U32, src), s)), Packed.peek(src, s), peek_value(src, s))))

def shifted_head_capacity(+m: U32, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +limit: Nat,
  shape: Bound.shape(depth, Packed.as_bits(dst)), +hd: MNat.lt(depth, 32n),
  +hl: MNat.le(limit, 1n+Nat.mul(Lemmas.pow2(depth), 4n)), hu: MNat.le(limit, Lemmas.pow2(32n)),
  +hn: MNat.lt(Nat.add(n, 1n), limit), +em: {U32.to_nat(m) == 1n+n : Nat}) ->
  {shifted_copy_head(m, src, dst, s) == Buffer.index(Bytes.peek(Tree.reify(U32, src), s)) : U32}:
  +cap = Lemmas.pow2(depth)
  +hm = below_equal(U32.to_nat(m), Nat.add(n, 1n), limit,
    Equal.trans(Nat, U32.to_nat(m), 1n+n, Nat.add(n, 1n), em, MNat.add_comm(1n, n)), hn)
  +hc = MNat.le_of_lt_succ(U32.to_nat(m), Nat.mul(cap, 4n),
    MNat.lt_of_lt_of_le(U32.to_nat(m), limit, 1n+Nat.mul(cap, 4n), hm, hl))
  +hw : MNat.lt(U32.to_nat((m >> 2n : U32)), 1n+cap) = (
    %Equal.sym(Nat, U32.to_nat((m >> 2n : U32)), Nat.div(U32.to_nat(m), 4n), Field.shrn_nat(m, 2n)) : MNat.lt(_, 1n+cap)
    MNat.lt_succ_of_le(Nat.div(U32.to_nat(m), 4n), cap, Packed.div4_le(U32.to_nat(m), cap, hc)))
  shifted_head_observed(m, n, depth, src, dst, s, 1n+cap, limit, shape, hd, MNat.le_refl(1n+cap),
    MNat.succ_le_of_lt(cap, Lemmas.pow2(32n), Field.pow2_lt(depth, 32n, hd)), hl, hu, hw, hn, em)
