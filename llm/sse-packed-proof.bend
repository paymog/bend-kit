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
