import Base
import ./bytes.bend as Bytes
import ../lemmas/array.bend as Tree
import ./word-proof.bend as WordModel
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ../bits/field-proof.bend as Field
import ../bits/array-proof.bend as Bound

# The tree model keeps array observations copyable without a small-depth bound.
def set.go(t: Tree.Tree<U32>, +n: U32, +i: U32, +v: U32, z: Bool) -> Tree.Tree<U32>:
  match t z:
    case Tree.Leaf{x} _:
      Tree.Leaf{v}
    case Tree.Node{xs, ys} True{}:
      Tree.Node{set.go(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n)))), ys}
    case Tree.Node{xs, ys} False{}:
      Tree.Node{xs, set.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))}

def set(+t: Tree.Tree<U32>, +i: U32, +v: U32) -> Tree.Tree<U32>:
  set.go(t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), v, Tree.Z(i, Tree.size(U32, t)))

def set_bridge.go(+t: Tree.Tree<U32>, +n: U32, +i: U32, +v: U32, +z: Bool) -> {(Tree.reify(U32, set.go(t, n, i, v, z)), Tree.read.go(U32, t, n, i, z)) == Array.swap.go(U32, Tree.reify(U32, t), n, i, v, z) : Array<U32> & U32}:
  match t z:
    case Tree.Leaf{x} _:
      {==}
    case Tree.Node{xs, ys} True{}:
      %set_bridge.go(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n)))) : {(Tree.reify(U32, set.go(t, n, i, v, True{})), Tree.read.go(U32, t, n, i, True{})) == Array.swap.lo(U32, Tree.reify(U32, ys), _) : Array<U32> & U32}
      {==}
    case Tree.Node{xs, ys} False{}:
      %set_bridge.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n)))) : {(Tree.reify(U32, set.go(t, n, i, v, False{})), Tree.read.go(U32, t, n, i, False{})) == Array.swap.hi(U32, Tree.reify(U32, xs), _) : Array<U32> & U32}
      {==}

def set_bridge(+t: Tree.Tree<U32>, +i: U32, +v: U32) -> {Tree.reify(U32, set(t, i, v)) == Array.set(U32, Tree.reify(U32, t), i, v) : Array<U32>}:
  %Tree.tree_size(U32, t) : {Tree.reify(U32, set(t, i, v)) == Array.set.fin(U32, Array.swap.at(U32, i, v, _)) : Array<U32>}
  %set_bridge.go(t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), v, Tree.Z(i, Tree.size(U32, t))) : {Tree.reify(U32, set(t, i, v)) == Array.set.fin(U32, _) : Array<U32>}
  {==}

def peek(+t: Tree.Tree<U32>, +i: U32) -> U32:
  Bytes.b8(U32.shrn(Tree.read(U32, t, U32.shrn(i, 2n)), Bytes.shift(i)))

def peek_bridge(+t: Tree.Tree<U32>, +i: U32) -> {Bytes.peek(Tree.reify(U32, t), i) == (Tree.reify(U32, t), peek(t, i)) : Array<U32> & U32}:
  %Tree.tree_get(U32, t, U32.shrn(i, 2n)) : {Bytes.peek.of(Bytes.shift(i), _) == (Tree.reify(U32, t), peek(t, i)) : Array<U32> & U32}
  {==}

def poke(+t: Tree.Tree<U32>, +i: U32, +v: U32) -> Tree.Tree<U32>:
  +w = Tree.read(U32, t, U32.shrn(i, 2n))
  +sh = Bytes.shift(i)
  set(t, U32.shrn(i, 2n), U32.or(U32.and(w, U32.xor(U32.shln(255, sh), 4294967295)), U32.shln(Bytes.b8(v), sh)))

def poke_bridge(+t: Tree.Tree<U32>, +i: U32, +v: U32) -> {Bytes.poke(Tree.reify(U32, t), i, v) == Tree.reify(U32, poke(t, i, v)) : Array<U32>}:
  %Tree.tree_get(U32, t, U32.shrn(i, 2n)) : {Bytes.poke.of(i, v, _) == Tree.reify(U32, poke(t, i, v)) : Array<U32>}
  Equal.sym(Array<U32>, Tree.reify(U32, poke(t, i, v)), Bytes.poke.of(i, v, (Tree.reify(U32, t), Tree.read(U32, t, U32.shrn(i, 2n)))), set_bridge(t, U32.shrn(i, 2n), U32.or(U32.and(Tree.read(U32, t, U32.shrn(i, 2n)), U32.xor(U32.shln(255, Bytes.shift(i)), 4294967295)), U32.shln(Bytes.b8(v), Bytes.shift(i)))))

def copy.go(n: Nat, +src: Tree.Tree<U32>, dst: Tree.Tree<U32>, +s: U32, +d: U32, +v: U32) -> Tree.Tree<U32>:
  match n:
    case 0n:
      dst
    case 1n+p:
      copy.go(p, src, poke(dst, d, v), U32.add(s, 1), U32.add(d, 1), peek(src, U32.add(s, 1)))

def copy.go_bridge(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +v: U32) -> {Bytes.copy.go(n, (Tree.reify(U32, src), v), Tree.reify(U32, dst), s, d) == (Tree.reify(U32, src), Tree.reify(U32, copy.go(n, src, dst, s, d, v))) : Array<U32> & Array<U32>}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), U32.add(s, 1)), (Tree.reify(U32, src), peek(src, U32.add(s, 1))), peek_bridge(src, U32.add(s, 1))) : {Bytes.copy.go(p, _, Bytes.poke(Tree.reify(U32, dst), d, v), U32.add(s, 1), U32.add(d, 1)) == (Tree.reify(U32, src), Tree.reify(U32, copy.go(n, src, dst, s, d, v))) : Array<U32> & Array<U32>}
      %Equal.sym(Array<U32>, Bytes.poke(Tree.reify(U32, dst), d, v), Tree.reify(U32, poke(dst, d, v)), poke_bridge(dst, d, v)) : {Bytes.copy.go(p, (Tree.reify(U32, src), peek(src, U32.add(s, 1))), _, U32.add(s, 1), U32.add(d, 1)) == (Tree.reify(U32, src), Tree.reify(U32, copy.go(n, src, dst, s, d, v))) : Array<U32> & Array<U32>}
      copy.go_bridge(p, src, poke(dst, d, v), U32.add(s, 1), U32.add(d, 1), peek(src, U32.add(s, 1)))

def copy.bytes(+m: U32, +src: Tree.Tree<U32>, dst: Tree.Tree<U32>, +s: U32, +d: U32) -> Tree.Tree<U32>:
  copy.go(U32.to_nat(m), src, dst, s, d, peek(src, s))

def copy.bytes_bridge(+m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32) -> {Bytes.copy.bytes(m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) == (Tree.reify(U32, src), Tree.reify(U32, copy.bytes(m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, src), s), (Tree.reify(U32, src), peek(src, s)), peek_bridge(src, s)) : {Bytes.copy.go(U32.to_nat(m), _, Tree.reify(U32, dst), s, d) == (Tree.reify(U32, src), Tree.reify(U32, copy.bytes(m, src, dst, s, d))) : Array<U32> & Array<U32>}
  copy.go_bridge(U32.to_nat(m), src, dst, s, d, peek(src, s))

def copy.words(n: Nat, +src: Tree.Tree<U32>, dst: Tree.Tree<U32>, +s: U32, +d: U32, +w: U32) -> Tree.Tree<U32>:
  match n:
    case 0n:
      dst
    case 1n+p:
      copy.words(p, src, set(dst, d, w), U32.add(s, 1), U32.add(d, 1), Tree.read(U32, src, U32.add(s, 1)))

def copy.words_bridge(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +w: U32) -> {Bytes.copy.words(n, (Tree.reify(U32, src), w), Tree.reify(U32, dst), s, d) == (Tree.reify(U32, src), Tree.reify(U32, copy.words(n, src, dst, s, d, w))) : Array<U32> & Array<U32>}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Tree.tree_get(U32, src, U32.add(s, 1)) : {Bytes.copy.words(p, _, Array.set(U32, Tree.reify(U32, dst), d, w), U32.add(s, 1), U32.add(d, 1)) == (Tree.reify(U32, src), Tree.reify(U32, copy.words(n, src, dst, s, d, w))) : Array<U32> & Array<U32>}
      %set_bridge(dst, d, w) : {Bytes.copy.words(p, (Tree.reify(U32, src), Tree.read(U32, src, U32.add(s, 1))), _, U32.add(s, 1), U32.add(d, 1)) == (Tree.reify(U32, src), Tree.reify(U32, copy.words(n, src, dst, s, d, w))) : Array<U32> & Array<U32>}
      copy.words_bridge(p, src, set(dst, d, w), U32.add(s, 1), U32.add(d, 1), Tree.read(U32, src, U32.add(s, 1)))

def copy.shift(n: Nat, +src: Tree.Tree<U32>, dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +prev: U32, +k: U32, +d: U32, +w: U32) -> Tree.Tree<U32>:
  match n:
    case 0n:
      dst
    case 1n+p:
      copy.shift(p, src, set(dst, d, U32.or(U32.shrn(prev, lo), U32.shln(w, hi))), lo, hi, w, U32.add(k, 1), U32.add(d, 1), Tree.read(U32, src, U32.add(k, 1)))

def copy.shift_bridge(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +lo: Nat, +hi: Nat, +prev: U32, +k: U32, +d: U32, +w: U32) -> {Bytes.copy.shift(n, lo, hi, prev, (Tree.reify(U32, src), w), Tree.reify(U32, dst), k, d) == (Tree.reify(U32, src), Tree.reify(U32, copy.shift(n, src, dst, lo, hi, prev, k, d, w))) : Array<U32> & Array<U32>}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Tree.tree_get(U32, src, U32.add(k, 1)) : {Bytes.copy.shift(p, lo, hi, w, _, Array.set(U32, Tree.reify(U32, dst), d, U32.or(U32.shrn(prev, lo), U32.shln(w, hi))), U32.add(k, 1), U32.add(d, 1)) == (Tree.reify(U32, src), Tree.reify(U32, copy.shift(n, src, dst, lo, hi, prev, k, d, w))) : Array<U32> & Array<U32>}
      %set_bridge(dst, d, U32.or(U32.shrn(prev, lo), U32.shln(w, hi))) : {Bytes.copy.shift(p, lo, hi, w, (Tree.reify(U32, src), Tree.read(U32, src, U32.add(k, 1))), _, U32.add(k, 1), U32.add(d, 1)) == (Tree.reify(U32, src), Tree.reify(U32, copy.shift(n, src, dst, lo, hi, prev, k, d, w))) : Array<U32> & Array<U32>}
      copy.shift_bridge(p, src, set(dst, d, U32.or(U32.shrn(prev, lo), U32.shln(w, hi))), lo, hi, w, U32.add(k, 1), U32.add(d, 1), Tree.read(U32, src, U32.add(k, 1)))

def copy.shift.at(+w: U32, +lo: U32, +k: U32, +d: U32, +src: Tree.Tree<U32>, dst: Tree.Tree<U32>) -> Tree.Tree<U32>:
  copy.shift(U32.to_nat(w), src, dst, U32.to_nat(lo), U32.to_nat(U32.sub(32, lo)), Tree.read(U32, src, k), U32.add(k, 1), d, Tree.read(U32, src, U32.add(k, 1)))

def copy.shift.at_bridge(+w: U32, +lo: U32, +k: U32, +d: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>) -> {Bytes.copy.shift.at(w, lo, k, d, Array.get(U32, Tree.reify(U32, src), k), Tree.reify(U32, dst)) == (Tree.reify(U32, src), Tree.reify(U32, copy.shift.at(w, lo, k, d, src, dst))) : Array<U32> & Array<U32>}:
  %Tree.tree_get(U32, src, k) : {Bytes.copy.shift.at(w, lo, k, d, _, Tree.reify(U32, dst)) == (Tree.reify(U32, src), Tree.reify(U32, copy.shift.at(w, lo, k, d, src, dst))) : Array<U32> & Array<U32>}
  %Tree.tree_get(U32, src, U32.add(k, 1)) : {Bytes.copy.shift(U32.to_nat(w), U32.to_nat(lo), U32.to_nat(U32.sub(32, lo)), Tree.read(U32, src, k), _, Tree.reify(U32, dst), U32.add(k, 1), d) == (Tree.reify(U32, src), Tree.reify(U32, copy.shift.at(w, lo, k, d, src, dst))) : Array<U32> & Array<U32>}
  copy.shift_bridge(U32.to_nat(w), src, dst, U32.to_nat(lo), U32.to_nat(U32.sub(32, lo)), Tree.read(U32, src, k), U32.add(k, 1), d, Tree.read(U32, src, U32.add(k, 1)))

def copy.pick(aligned: Bool, +m: U32, +src: Tree.Tree<U32>, dst: Tree.Tree<U32>, +s: U32, +d: U32) -> Tree.Tree<U32>:
  match aligned:
    case True{}:
      +w = U32.shrn(m, 2n)
      +k = U32.mul(w, 4)
      copy.bytes(U32.sub(m, k), src, copy.words(U32.to_nat(w), src, dst, U32.shrn(s, 2n), U32.shrn(d, 2n), Tree.read(U32, src, U32.shrn(s, 2n))), U32.add(s, k), U32.add(d, k))
    case False{}:
      +w = U32.shrn(m, 2n)
      +k = U32.mul(w, 4)
      copy.bytes(U32.sub(m, k), src, copy.shift.at(w, U32.mul(U32.and(s, 3), 8), U32.shrn(s, 2n), U32.shrn(d, 2n), src, dst), U32.add(s, k), U32.add(d, k))

def copy.pick_bridge(aligned: Bool, +m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32) -> {Bytes.copy.pick(aligned, m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) == (Tree.reify(U32, src), Tree.reify(U32, copy.pick(aligned, m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  match aligned:
    case True{}:
      +w = U32.shrn(m, 2n)
      +k = U32.mul(w, 4)
      %Tree.tree_get(U32, src, U32.shrn(s, 2n)) : {Bytes.copy.tail(U32.sub(m, k), U32.add(s, k), U32.add(d, k), Bytes.copy.words(U32.to_nat(w), _, Tree.reify(U32, dst), U32.shrn(s, 2n), U32.shrn(d, 2n))) == (Tree.reify(U32, src), Tree.reify(U32, copy.pick(True{}, m, src, dst, s, d))) : Array<U32> & Array<U32>}
      %Equal.sym(Array<U32> & Array<U32>, Bytes.copy.words(U32.to_nat(w), (Tree.reify(U32, src), Tree.read(U32, src, U32.shrn(s, 2n))), Tree.reify(U32, dst), U32.shrn(s, 2n), U32.shrn(d, 2n)), (Tree.reify(U32, src), Tree.reify(U32, copy.words(U32.to_nat(w), src, dst, U32.shrn(s, 2n), U32.shrn(d, 2n), Tree.read(U32, src, U32.shrn(s, 2n))))), copy.words_bridge(U32.to_nat(w), src, dst, U32.shrn(s, 2n), U32.shrn(d, 2n), Tree.read(U32, src, U32.shrn(s, 2n)))) : {Bytes.copy.tail(U32.sub(m, k), U32.add(s, k), U32.add(d, k), _) == (Tree.reify(U32, src), Tree.reify(U32, copy.pick(True{}, m, src, dst, s, d))) : Array<U32> & Array<U32>}
      copy.bytes_bridge(U32.sub(m, k), src, copy.words(U32.to_nat(w), src, dst, U32.shrn(s, 2n), U32.shrn(d, 2n), Tree.read(U32, src, U32.shrn(s, 2n))), U32.add(s, k), U32.add(d, k))
    case False{}:
      +w = U32.shrn(m, 2n)
      +k = U32.mul(w, 4)
      +lo = U32.mul(U32.and(s, 3), 8)
      %Equal.sym(Array<U32> & Array<U32>, Bytes.copy.shift.at(w, lo, U32.shrn(s, 2n), U32.shrn(d, 2n), Array.get(U32, Tree.reify(U32, src), U32.shrn(s, 2n)), Tree.reify(U32, dst)), (Tree.reify(U32, src), Tree.reify(U32, copy.shift.at(w, lo, U32.shrn(s, 2n), U32.shrn(d, 2n), src, dst))), copy.shift.at_bridge(w, lo, U32.shrn(s, 2n), U32.shrn(d, 2n), src, dst)) : {Bytes.copy.tail(U32.sub(m, k), U32.add(s, k), U32.add(d, k), _) == (Tree.reify(U32, src), Tree.reify(U32, copy.pick(False{}, m, src, dst, s, d))) : Array<U32> & Array<U32>}
      copy.bytes_bridge(U32.sub(m, k), src, copy.shift.at(w, lo, U32.shrn(s, 2n), U32.shrn(d, 2n), src, dst), U32.add(s, k), U32.add(d, k))

def copy.dst(aligned: Bool, +m: U32, +src: Tree.Tree<U32>, dst: Tree.Tree<U32>, +s: U32, +d: U32) -> Tree.Tree<U32>:
  match aligned:
    case False{}:
      copy.bytes(m, src, dst, s, d)
    case True{}:
      copy.pick(U32.is_eq(U32.and(s, 3), 0), m, src, dst, s, d)

def copy.dst_bridge(aligned: Bool, +m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32) -> {Bytes.copy.dst(aligned, m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) == (Tree.reify(U32, src), Tree.reify(U32, copy.dst(aligned, m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  match aligned:
    case False{}:
      copy.bytes_bridge(m, src, dst, s, d)
    case True{}:
      copy.pick_bridge(U32.is_eq(U32.and(s, 3), 0), m, src, dst, s, d)

def copy(+m: U32, +src: Tree.Tree<U32>, dst: Tree.Tree<U32>, +s: U32, +d: U32) -> Tree.Tree<U32>:
  copy.dst(U32.is_eq(U32.and(d, 3), 0), m, src, dst, s, d)

def copy_bridge(+m: U32, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32) -> {Bytes.copy(m, Tree.reify(U32, src), Tree.reify(U32, dst), s, d) == (Tree.reify(U32, src), Tree.reify(U32, copy(m, src, dst, s, d))) : Array<U32> & Array<U32>}:
  copy.dst_bridge(U32.is_eq(U32.and(d, 3), 0), m, src, dst, s, d)

def fresh(d: Nat) -> Tree.Tree<U32>:
  match d:
    case 0n:
      Tree.Leaf{0}
    case 1n++p:
      Tree.Node{fresh(p), fresh(p)}

def fresh_bridge(+d: Nat) -> {Tree.reify(U32, fresh(d)) == Array.new(U32, d, 0) : Array<U32>}:
  match d:
    case 0n:
      {==}
    case 1n+p:
      %fresh_bridge(p) : {ANode{Tree.reify(U32, fresh(p)), Tree.reify(U32, fresh(p))} == ANode{_, _} : Array<U32>}
      {==}

def alloc(+n: U32) -> Tree.Tree<U32>:
  fresh(Bytes.depth(Bytes.words(n)))

def flush(full: Bool, t: Tree.Tree<U32>, +k: U32, +w: U32) -> Tree.Tree<U32>:
  match full:
    case True{}:
      set(t, k, w)
    case False{}:
      t

def flush_bridge(full: Bool, +t: Tree.Tree<U32>, +k: U32, +w: U32) -> {Bytes.flush(full, Tree.reify(U32, t), k, w) == Tree.reify(U32, flush(full, t, k, w)) : Array<U32>}:
  match full:
    case True{}:
      Equal.sym(Array<U32>, Tree.reify(U32, set(t, k, w)), Array.set(U32, Tree.reify(U32, t), k, w), set_bridge(t, k, w))
    case False{}:
      {==}

def from.go(s: String, t: Tree.Tree<U32>, +i: U32, +w: U32) -> Tree.Tree<U32>:
  match s:
    case SNil{}:
      +r = U32.and(i, 3)
      flush(U32.is_ne(r, 0), t, U32.shrn(i, 2n), U32.shrn(w, U32.to_nat(U32.mul(U32.and(U32.sub(4, r), 3), 8))))
    case SCon{Chr{+c}, tail}:
      +w2 = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      +full = U32.is_eq(U32.and(i, 3), 3)
      from.go(tail, flush(full, t, U32.shrn(i, 2n), w2), U32.add(i, 1), Bool.pick(U32, full, 0, w2))

def from.go_bridge(+s: String, +t: Tree.Tree<U32>, +i: U32, +w: U32) -> {Bytes.from.go(s, Tree.reify(U32, t), i, w) == Tree.reify(U32, from.go(s, t, i, w)) : Array<U32>}:
  match s:
    case SNil{}:
      +r = U32.and(i, 3)
      flush_bridge(U32.is_ne(r, 0), t, U32.shrn(i, 2n), U32.shrn(w, U32.to_nat(U32.mul(U32.and(U32.sub(4, r), 3), 8))))
    case SCon{Chr{+c}, +tail}:
      +w2 = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      +full = U32.is_eq(U32.and(i, 3), 3)
      %Equal.sym(Array<U32>, Bytes.flush(full, Tree.reify(U32, t), U32.shrn(i, 2n), w2), Tree.reify(U32, flush(full, t, U32.shrn(i, 2n), w2)), flush_bridge(full, t, U32.shrn(i, 2n), w2)) : {Bytes.from.go(tail, _, U32.add(i, 1), Bool.pick(U32, full, 0, w2)) == Tree.reify(U32, from.go(s, t, i, w)) : Array<U32>}
      from.go_bridge(tail, flush(full, t, U32.shrn(i, 2n), w2), U32.add(i, 1), Bool.pick(U32, full, 0, w2))

def from_string(+s: String) -> Tree.Tree<U32>:
  from.go(s, alloc(Bytes.count(s, 0)), 0, 0)

def from_bridge(+s: String) -> {Bytes.from_string(s) == Bytes.Bytes{Bytes.count(s, 0), Tree.reify(U32, from_string(s))} : Bytes.Bytes}:
  %fresh_bridge(Bytes.depth(Bytes.words(Bytes.count(s, 0)))) : {Bytes.Bytes{Bytes.count(s, 0), Bytes.from.go(s, _, 0, 0)} == Bytes.Bytes{Bytes.count(s, 0), Tree.reify(U32, from_string(s))} : Bytes.Bytes}
  Equal.cong(Array<U32>, Bytes.Bytes, a => Bytes.Bytes{Bytes.count(s, 0), a}, Bytes.from.go(s, Tree.reify(U32, alloc(Bytes.count(s, 0))), 0, 0), Tree.reify(U32, from_string(s)), from.go_bridge(s, alloc(Bytes.count(s, 0)), 0, 0))

def to.go(n: Nat, +t: Tree.Tree<U32>, +i: U32, acc: String, +v: U32) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      to.go(p, t, U32.sub(i, 1), SCon{Chr{v}, acc}, peek(t, U32.sub(i, 1)))

def to.go_bridge(n: Nat, +t: Tree.Tree<U32>, +i: U32, +acc: String, +v: U32) -> {Bytes.to.go(n, (Tree.reify(U32, t), v), i, acc) == to.go(n, t, i, acc, v) : String}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, t), U32.sub(i, 1)), (Tree.reify(U32, t), peek(t, U32.sub(i, 1))), peek_bridge(t, U32.sub(i, 1))) : {Bytes.to.go(p, _, U32.sub(i, 1), SCon{Chr{v}, acc}) == to.go(n, t, i, acc, v) : String}
      to.go_bridge(p, t, U32.sub(i, 1), SCon{Chr{v}, acc}, peek(t, U32.sub(i, 1)))

def to_string(+len: U32, +t: Tree.Tree<U32>) -> String:
  to.go(U32.to_nat(len), t, U32.sub(len, 1), SNil{}, peek(t, U32.sub(len, 1)))

def to_bridge(+len: U32, +t: Tree.Tree<U32>) -> {Bytes.to_string(Bytes.Bytes{len, Tree.reify(U32, t)}) == to_string(len, t) : String}:
  %Equal.sym(Array<U32> & U32, Bytes.peek(Tree.reify(U32, t), U32.sub(len, 1)), (Tree.reify(U32, t), peek(t, U32.sub(len, 1))), peek_bridge(t, U32.sub(len, 1))) : {Bytes.to.go(U32.to_nat(len), _, U32.sub(len, 1), SNil{}) == to_string(len, t) : String}
  to.go_bridge(U32.to_nat(len), t, U32.sub(len, 1), SNil{}, peek(t, U32.sub(len, 1)))

def grow.if(fits: Bool, +len: U32, t: Tree.Tree<U32>, +n: U32) -> Tree.Tree<U32>:
  match fits:
    case True{}:
      t
    case False{}:
      copy(len, t, alloc(n), 0, 0)

def grow(+len: U32, t: Tree.Tree<U32>, +n: U32) -> Tree.Tree<U32>:
  grow.if(Bytes.room(len, n), len, t, n)

def grow.if_bridge(fits: Bool, +len: U32, +t: Tree.Tree<U32>, +n: U32) -> {Bytes.grow.if(fits, len, Tree.reify(U32, t), n) == Tree.reify(U32, grow.if(fits, len, t, n)) : Array<U32>}:
  match fits:
    case True{}:
      {==}
    case False{}:
      %fresh_bridge(Bytes.depth(Bytes.words(n))) : {Bytes.dst(Bytes.copy(len, Tree.reify(U32, t), _, 0, 0)) == Tree.reify(U32, grow.if(False{}, len, t, n)) : Array<U32>}
      Equal.cong(Array<U32> & Array<U32>, Array<U32>, Bytes.dst, Bytes.copy(len, Tree.reify(U32, t), Tree.reify(U32, alloc(n)), 0, 0), (Tree.reify(U32, t), Tree.reify(U32, copy(len, t, alloc(n), 0, 0))), copy_bridge(len, t, alloc(n), 0, 0))

def grow_bridge(+len: U32, +t: Tree.Tree<U32>, +n: U32) -> {Bytes.grow(len, Tree.reify(U32, t), n) == Tree.reify(U32, grow(len, t, n)) : Array<U32>}:
  grow.if_bridge(Bytes.room(len, n), len, t, n)

def append(+la: U32, a: Tree.Tree<U32>, +lb: U32, +b: Tree.Tree<U32>) -> Tree.Tree<U32>:
  copy(lb, b, grow(la, a, U32.add(la, lb)), 0, la)

def append_bridge(+la: U32, +a: Tree.Tree<U32>, +lb: U32, +b: Tree.Tree<U32>) -> {Bytes.append(Bytes.Bytes{la, Tree.reify(U32, a)}, Bytes.Bytes{lb, Tree.reify(U32, b)}) == Bytes.Bytes{U32.add(la, lb), Tree.reify(U32, append(la, a, lb, b))} : Bytes.Bytes}:
  %Equal.sym(Array<U32>, Bytes.grow(la, Tree.reify(U32, a), U32.add(la, lb)), Tree.reify(U32, grow(la, a, U32.add(la, lb))), grow_bridge(la, a, U32.add(la, lb))) : {Bytes.Bytes{U32.add(la, lb), Bytes.dst(Bytes.copy(lb, Tree.reify(U32, b), _, 0, la))} == Bytes.Bytes{U32.add(la, lb), Tree.reify(U32, append(la, a, lb, b))} : Bytes.Bytes}
  Equal.cong(Array<U32> & Array<U32>, Bytes.Bytes, r => Bytes.Bytes{U32.add(la, lb), Bytes.dst(r)}, Bytes.copy(lb, Tree.reify(U32, b), Tree.reify(U32, grow(la, a, U32.add(la, lb))), 0, la), (Tree.reify(U32, b), Tree.reify(U32, append(la, a, lb, b))), copy_bridge(lb, b, grow(la, a, U32.add(la, lb)), 0, la))

def canonical_bridge(+a: String, +b: String) -> {Bytes.to_string(Bytes.append(Bytes.from_string(a), Bytes.from_string(b))) == to_string(U32.add(Bytes.count(a, 0), Bytes.count(b, 0)), append(Bytes.count(a, 0), from_string(a), Bytes.count(b, 0), from_string(b))) : String}:
  %Equal.sym(Bytes.Bytes, Bytes.from_string(a), Bytes.Bytes{Bytes.count(a, 0), Tree.reify(U32, from_string(a))}, from_bridge(a)) : {Bytes.to_string(Bytes.append(_, Bytes.from_string(b))) == to_string(U32.add(Bytes.count(a, 0), Bytes.count(b, 0)), append(Bytes.count(a, 0), from_string(a), Bytes.count(b, 0), from_string(b))) : String}
  %Equal.sym(Bytes.Bytes, Bytes.from_string(b), Bytes.Bytes{Bytes.count(b, 0), Tree.reify(U32, from_string(b))}, from_bridge(b)) : {Bytes.to_string(Bytes.append(Bytes.Bytes{Bytes.count(a, 0), Tree.reify(U32, from_string(a))}, _)) == to_string(U32.add(Bytes.count(a, 0), Bytes.count(b, 0)), append(Bytes.count(a, 0), from_string(a), Bytes.count(b, 0), from_string(b))) : String}
  %Equal.sym(Bytes.Bytes, Bytes.append(Bytes.Bytes{Bytes.count(a, 0), Tree.reify(U32, from_string(a))}, Bytes.Bytes{Bytes.count(b, 0), Tree.reify(U32, from_string(b))}), Bytes.Bytes{U32.add(Bytes.count(a, 0), Bytes.count(b, 0)), Tree.reify(U32, append(Bytes.count(a, 0), from_string(a), Bytes.count(b, 0), from_string(b)))}, append_bridge(Bytes.count(a, 0), from_string(a), Bytes.count(b, 0), from_string(b))) : {Bytes.to_string(_) == to_string(U32.add(Bytes.count(a, 0), Bytes.count(b, 0)), append(Bytes.count(a, 0), from_string(a), Bytes.count(b, 0), from_string(b))) : String}
  to_bridge(U32.add(Bytes.count(a, 0), Bytes.count(b, 0)), append(Bytes.count(a, 0), from_string(a), Bytes.count(b, 0), from_string(b)))

def Same(n: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      {peek(a, i) == peek(b, i) : U32} & Same(p, a, b, U32.sub(i, 1))

def observe(+n: Nat, +t: Tree.Tree<U32>, +i: U32, acc: String) -> String:
  to.go(n, t, i, acc, peek(t, i))

def observe_equal(n: Nat, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, +i: U32, +acc: String, h: Same(n, a, b, i)) -> {observe(n, a, i, acc) == observe(n, b, i, acc) : String}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      (head, tail) = h
      %head : {observe(p, a, U32.sub(i, 1), SCon{Chr{peek(a, i)}, acc}) == observe(p, b, U32.sub(i, 1), SCon{Chr{_}, acc}) : String}
      observe_equal(p, a, b, U32.sub(i, 1), SCon{Chr{peek(a, i)}, acc}, tail)

def to_equal(+len: U32, +a: Tree.Tree<U32>, +b: Tree.Tree<U32>, h: Same(U32.to_nat(len), a, b, U32.sub(len, 1))) -> {Bytes.to_string(Bytes.Bytes{len, Tree.reify(U32, a)}) == Bytes.to_string(Bytes.Bytes{len, Tree.reify(U32, b)}) : String}:
  %Equal.sym(String, Bytes.to_string(Bytes.Bytes{len, Tree.reify(U32, a)}), to_string(len, a), to_bridge(len, a)) : {_ == Bytes.to_string(Bytes.Bytes{len, Tree.reify(U32, b)}) : String}
  %Equal.sym(String, Bytes.to_string(Bytes.Bytes{len, Tree.reify(U32, b)}), to_string(len, b), to_bridge(len, b)) : {to_string(len, a) == _ : String}
  observe_equal(U32.to_nat(len), a, b, U32.sub(len, 1), SNil{}, h)

def from.cont(s: String, +tail: String, t: Tree.Tree<U32>, +i: U32, +w: U32) -> Tree.Tree<U32>:
  match s:
    case SNil{}:
      from.go(tail, t, i, w)
    case SCon{Chr{+c}, rest}:
      +w2 = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      +full = U32.is_eq(U32.and(i, 3), 3)
      from.cont(rest, tail, flush(full, t, U32.shrn(i, 2n), w2), U32.add(i, 1), Bool.pick(U32, full, 0, w2))

def from.cont_bridge(+s: String, +tail: String, +t: Tree.Tree<U32>, +i: U32, +w: U32) -> {from.go(s ++ tail, t, i, w) == from.cont(s, tail, t, i, w) : Tree.Tree<U32>}:
  match s:
    case SNil{}:
      {==}
    case SCon{Chr{+c}, +rest}:
      +w2 = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      +full = U32.is_eq(U32.and(i, 3), 3)
      from.cont_bridge(rest, tail, flush(full, t, U32.shrn(i, 2n), w2), U32.add(i, 1), Bool.pick(U32, full, 0, w2))

def count_append(+a: String, +b: String, +n: U32) -> {Bytes.count(a ++ b, n) == Bytes.count(b, Bytes.count(a, n)) : U32}:
  match a:
    case SNil{}:
      {==}
    case SCon{c, +t}:
      count_append(t, b, U32.add(n, 1))

def set_size.go(+t: Tree.Tree<U32>, +n: U32, +i: U32, +v: U32, +z: Bool) -> {Tree.size(U32, set.go(t, n, i, v, z)) == Tree.size(U32, t) : U32}:
  match t z:
    case Tree.Leaf{x} _:
      {==}
    case Tree.Node{xs, ys} True{}:
      Equal.cong(U32, U32, U32.shl, Tree.size(U32, set.go(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))))), Tree.size(U32, xs), set_size.go(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n)))))
    case Tree.Node{xs, ys} False{}:
      {==}

def set_size(+t: Tree.Tree<U32>, +i: U32, +v: U32) -> {Tree.size(U32, set(t, i, v)) == Tree.size(U32, t) : U32}:
  set_size.go(t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), v, Tree.Z(i, Tree.size(U32, t)))

def read_set.go(+t: Tree.Tree<U32>, +n: U32, +i: U32, +v: U32, +z: Bool) -> {Tree.read.go(U32, set.go(t, n, i, v, z), n, i, z) == v : U32}:
  match t z:
    case Tree.Leaf{x} _:
      {==}
    case Tree.Node{xs, ys} True{}:
      read_set.go(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))))
    case Tree.Node{xs, ys} False{}:
      read_set.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))

def read_set(+t: Tree.Tree<U32>, +i: U32, +v: U32) -> {Tree.read(U32, set(t, i, v), i) == v : U32}:
  %Equal.sym(U32, Tree.size(U32, set(t, i, v)), Tree.size(U32, t), set_size(t, i, v)) : {Tree.read.go(U32, set(t, i, v), _, Tree.J(i, _), Tree.Z(i, _)) == v : U32}
  read_set.go(t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), v, Tree.Z(i, Tree.size(U32, t)))

def poke_same_at(+t: Tree.Tree<U32>, +i: U32, +v: U32, +lane: Nat, hs: {Nat.mul(lane, 8n) == Bytes.shift(i) : Nat}, hl: MNat.lt(lane, 4n)) -> {peek(poke(t, i, v), i) == Bytes.b8(v) : U32}:
  +w = Tree.read(U32, t, U32.shrn(i, 2n))
  %Equal.sym(U32, Tree.read(U32, poke(t, i, v), U32.shrn(i, 2n)), U32.or(U32.and(w, U32.xor(U32.shln(255, Bytes.shift(i)), 4294967295)), U32.shln(Bytes.b8(v), Bytes.shift(i))), read_set(t, U32.shrn(i, 2n), U32.or(U32.and(w, U32.xor(U32.shln(255, Bytes.shift(i)), 4294967295)), U32.shln(Bytes.b8(v), Bytes.shift(i))))) : {Bytes.b8(U32.shrn(_, Bytes.shift(i))) == Bytes.b8(v) : U32}
  %hs : {Bytes.b8(U32.shrn(U32.or(U32.and(w, U32.xor(U32.shln(255, _), 4294967295)), U32.shln(Bytes.b8(v), _)), _)) == Bytes.b8(v) : U32}
  WordModel.read_write(w, v, lane, hl)

def low2(+a: Bool, +b: Bool, +t: Word(30n)) -> {U32.and(U32{WCon{a, WCon{b, t}}}, 3) == U32{WCon{a, WCon{b, Word.zero(30n)}}} : U32}:
  %WordModel.and_true(a) : {U32{WCon{Bool.and(a, True{}), WCon{Bool.and(b, True{}), Word.and(30n, t, Word.zero(30n))}}} == U32{WCon{_, WCon{b, Word.zero(30n)}}} : U32}
  %WordModel.and_true(b) : {U32{WCon{Bool.and(a, True{}), WCon{Bool.and(b, True{}), Word.and(30n, t, Word.zero(30n))}}} == U32{WCon{Bool.and(a, True{}), WCon{_, Word.zero(30n)}}} : U32}
  %WordModel.word_and_zero(30n, t) : {U32{WCon{Bool.and(a, True{}), WCon{Bool.and(b, True{}), Word.and(30n, t, Word.zero(30n))}}} == U32{WCon{Bool.and(a, True{}), WCon{Bool.and(b, True{}), _}}} : U32}
  {==}

def Lane(+i: U32) -> Type:
  {Nat.mul(U32.to_nat(U32.and(i, 3)), 8n) == Bytes.shift(i) : Nat} & MNat.lt(U32.to_nat(U32.and(i, 3)), 4n)

def lane_normal(+a: Bool, +b: Bool) -> {Nat.mul(U32.to_nat(U32{WCon{a, WCon{b, Word.zero(30n)}}}), 8n) == U32.to_nat(U32.mul(U32{WCon{a, WCon{b, Word.zero(30n)}}}, 8)) : Nat} & MNat.lt(U32.to_nat(U32{WCon{a, WCon{b, Word.zero(30n)}}}), 4n):
  match a b:
    case False{} False{}:
      ({==}, {==})
    case False{} True{}:
      ({==}, {==})
    case True{} False{}:
      ({==}, {==})
    case True{} True{}:
      ({==}, {==})

def lane_bits(+a: Bool, +b: Bool, +t: Word(30n)) -> Lane(U32{WCon{a, WCon{b, t}}}):
  %Equal.sym(U32, U32.and(U32{WCon{a, WCon{b, t}}}, 3), U32{WCon{a, WCon{b, Word.zero(30n)}}}, low2(a, b, t)) : {Nat.mul(U32.to_nat(_), 8n) == U32.to_nat(U32.mul(_, 8)) : Nat} & MNat.lt(U32.to_nat(_), 4n)
  lane_normal(a, b)

def lane_facts(+i: U32) -> Lane(i):
  match i:
    case U32{WCon{+a, WCon{+b, +t}}}:
      lane_bits(a, b, t)

def poke_same.of(+t: Tree.Tree<U32>, +i: U32, +v: U32, facts: Lane(i)) -> {peek(poke(t, i, v), i) == Bytes.b8(v) : U32}:
  (hs, hl) = facts
  poke_same_at(t, i, v, U32.to_nat(U32.and(i, 3)), hs, hl)

def poke_same(+t: Tree.Tree<U32>, +i: U32, +v: U32) -> {peek(poke(t, i, v), i) == Bytes.b8(v) : U32}:
  poke_same.of(t, i, v, lane_facts(i))

def apart.go(t: Tree.Tree<U32>, +n: U32, +i: U32, +j: U32, z: Bool, q: Bool) -> Bool:
  match t z q:
    case Tree.Leaf{x} _ _:
      False{}
    case Tree.Node{xs, ys} True{} True{}:
      apart.go(xs, U32.shr(n), i, j, U32.is_lt(i, U32.shr(U32.shr(n))), U32.is_lt(j, U32.shr(U32.shr(n))))
    case Tree.Node{xs, ys} False{} False{}:
      apart.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.sub(j, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))))
    case Tree.Node{xs, ys} True{} False{}:
      True{}
    case Tree.Node{xs, ys} False{} True{}:
      True{}

def apart(+t: Tree.Tree<U32>, +i: U32, +j: U32) -> Bool:
  apart.go(t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), Tree.J(j, Tree.size(U32, t)), Tree.Z(i, Tree.size(U32, t)), Tree.Z(j, Tree.size(U32, t)))

def read_set_other.go(+t: Tree.Tree<U32>, +n: U32, +i: U32, +j: U32, +v: U32, +z: Bool, +q: Bool, h: {apart.go(t, n, i, j, z, q) == True{} : Bool}) -> {Tree.read.go(U32, set.go(t, n, i, v, z), n, j, q) == Tree.read.go(U32, t, n, j, q) : U32}:
  match t z q:
    case Tree.Leaf{x} _ _:
      Empty.absurd({v == x : U32}, WordModel.false_true(h))
    case Tree.Node{xs, ys} True{} True{}:
      read_set_other.go(xs, U32.shr(n), i, j, v, U32.is_lt(i, U32.shr(U32.shr(n))), U32.is_lt(j, U32.shr(U32.shr(n))), h)
    case Tree.Node{xs, ys} False{} False{}:
      read_set_other.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.sub(j, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))), h)
    case Tree.Node{xs, ys} True{} False{}:
      {==}
    case Tree.Node{xs, ys} False{} True{}:
      {==}

def read_set_other(+t: Tree.Tree<U32>, +i: U32, +j: U32, +v: U32, h: {apart(t, i, j) == True{} : Bool}) -> {Tree.read(U32, set(t, i, v), j) == Tree.read(U32, t, j) : U32}:
  %Equal.sym(U32, Tree.size(U32, set(t, i, v)), Tree.size(U32, t), set_size(t, i, v)) : {Tree.read.go(U32, set(t, i, v), _, Tree.J(j, _), Tree.Z(j, _)) == Tree.read(U32, t, j) : U32}
  read_set_other.go(t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), Tree.J(j, Tree.size(U32, t)), v, Tree.Z(i, Tree.size(U32, t)), Tree.Z(j, Tree.size(U32, t)), h)

def poke_other_word(+t: Tree.Tree<U32>, +i: U32, +j: U32, +v: U32, h: {apart(t, U32.shrn(i, 2n), U32.shrn(j, 2n)) == True{} : Bool}) -> {peek(poke(t, i, v), j) == peek(t, j) : U32}:
  Equal.cong(U32, U32, w => Bytes.b8(U32.shrn(w, Bytes.shift(j))), Tree.read(U32, poke(t, i, v), U32.shrn(j, 2n)), Tree.read(U32, t, U32.shrn(j, 2n)), read_set_other(t, U32.shrn(i, 2n), U32.shrn(j, 2n), U32.or(U32.and(Tree.read(U32, t, U32.shrn(i, 2n)), U32.xor(U32.shln(255, Bytes.shift(i)), 4294967295)), U32.shln(Bytes.b8(v), Bytes.shift(i))), h))

def poke_other_lane_at(+t: Tree.Tree<U32>, +i: U32, +j: U32, +v: U32, +li: Nat, +lj: Nat, es: {U32.shrn(i, 2n) == U32.shrn(j, 2n) : U32}, hi: {Nat.mul(li, 8n) == Bytes.shift(i) : Nat}, hj: {Nat.mul(lj, 8n) == Bytes.shift(j) : Nat}, bi: MNat.lt(li, 4n), bj: MNat.lt(lj, 4n), ne: {li != lj : Nat}) -> {peek(poke(t, i, v), j) == peek(t, j) : U32}:
  +w = Tree.read(U32, t, U32.shrn(i, 2n))
  %es : {Bytes.b8(U32.shrn(Tree.read(U32, poke(t, i, v), _), Bytes.shift(j))) == Bytes.b8(U32.shrn(Tree.read(U32, t, _), Bytes.shift(j))) : U32}
  %Equal.sym(U32, Tree.read(U32, poke(t, i, v), U32.shrn(i, 2n)), U32.or(U32.and(w, U32.xor(U32.shln(255, Bytes.shift(i)), 4294967295)), U32.shln(Bytes.b8(v), Bytes.shift(i))), read_set(t, U32.shrn(i, 2n), U32.or(U32.and(w, U32.xor(U32.shln(255, Bytes.shift(i)), 4294967295)), U32.shln(Bytes.b8(v), Bytes.shift(i))))) : {Bytes.b8(U32.shrn(_, Bytes.shift(j))) == Bytes.b8(U32.shrn(w, Bytes.shift(j))) : U32}
  %hi : {Bytes.b8(U32.shrn(U32.or(U32.and(w, U32.xor(U32.shln(255, _), 4294967295)), U32.shln(Bytes.b8(v), _)), Bytes.shift(j))) == Bytes.b8(U32.shrn(w, Bytes.shift(j))) : U32}
  %hj : {Bytes.b8(U32.shrn(WordModel.write(w, v, li), _)) == Bytes.b8(U32.shrn(w, _)) : U32}
  WordModel.read_write_other(w, v, li, lj, bi, bj, ne)

def poke_other_lane.of(+t: Tree.Tree<U32>, +i: U32, +j: U32, +v: U32, es: {U32.shrn(i, 2n) == U32.shrn(j, 2n) : U32}, ne: {U32.to_nat(U32.and(i, 3)) != U32.to_nat(U32.and(j, 3)) : Nat}, fi: Lane(i), fj: Lane(j)) -> {peek(poke(t, i, v), j) == peek(t, j) : U32}:
  (hi, bi) = fi
  (hj, bj) = fj
  poke_other_lane_at(t, i, j, v, U32.to_nat(U32.and(i, 3)), U32.to_nat(U32.and(j, 3)), es, hi, hj, bi, bj, ne)

def poke_other_lane(+t: Tree.Tree<U32>, +i: U32, +j: U32, +v: U32, es: {U32.shrn(i, 2n) == U32.shrn(j, 2n) : U32}, ne: {U32.to_nat(U32.and(i, 3)) != U32.to_nat(U32.and(j, 3)) : Nat}) -> {peek(poke(t, i, v), j) == peek(t, j) : U32}:
  poke_other_lane.of(t, i, j, v, es, ne, lane_facts(i), lane_facts(j))

def apart_set.go(+t: Tree.Tree<U32>, +n: U32, +i: U32, +j: U32, +k: U32, +v: U32, +z: Bool, +q: Bool, +r: Bool) -> {apart.go(set.go(t, n, i, v, z), n, j, k, q, r) == apart.go(t, n, j, k, q, r) : Bool}:
  match t z q r:
    case Tree.Leaf{x} _ _ _:
      {==}
    case Tree.Node{xs, ys} True{} True{} True{}:
      apart_set.go(xs, U32.shr(n), i, j, k, v, U32.is_lt(i, U32.shr(U32.shr(n))), U32.is_lt(j, U32.shr(U32.shr(n))), U32.is_lt(k, U32.shr(U32.shr(n))))
    case Tree.Node{xs, ys} False{} False{} False{}:
      apart_set.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.sub(j, U32.shr(n)), U32.sub(k, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))), U32.is_lt(U32.sub(k, U32.shr(n)), U32.shr(U32.shr(n))))
    case Tree.Node{xs, ys} True{} False{} False{}:
      {==}
    case Tree.Node{xs, ys} False{} True{} True{}:
      {==}
    case Tree.Node{xs, ys} True{} True{} False{}:
      {==}
    case Tree.Node{xs, ys} True{} False{} True{}:
      {==}
    case Tree.Node{xs, ys} False{} True{} False{}:
      {==}
    case Tree.Node{xs, ys} False{} False{} True{}:
      {==}

def apart_set(+t: Tree.Tree<U32>, +i: U32, +j: U32, +k: U32, +v: U32) -> {apart(set(t, i, v), j, k) == apart(t, j, k) : Bool}:
  %Equal.sym(U32, Tree.size(U32, set(t, i, v)), Tree.size(U32, t), set_size(t, i, v)) : {apart.go(set(t, i, v), _, Tree.J(j, _), Tree.J(k, _), Tree.Z(j, _), Tree.Z(k, _)) == apart(t, j, k) : Bool}
  apart_set.go(t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), Tree.J(j, Tree.size(U32, t)), Tree.J(k, Tree.size(U32, t)), v, Tree.Z(i, Tree.size(U32, t)), Tree.Z(j, Tree.size(U32, t)), Tree.Z(k, Tree.size(U32, t)))

def Outside(n: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      {apart(t, d, j) == True{} : Bool} & Outside(p, t, U32.add(d, 1), j)

def outside_set(n: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32, +i: U32, +v: U32, h: Outside(n, t, d, j)) -> Outside(n, set(t, i, v), d, j):
  match n:
    case 0n:
      Unit{}
    case 1n+p:
      (head, tail) = h
      ((%Equal.sym(Bool, apart(set(t, i, v), d, j), apart(t, d, j), apart_set(t, i, d, j, v)) : {_ == True{} : Bool}; head), outside_set(p, t, U32.add(d, 1), j, i, v, tail))

def copy.words_other(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +w: U32, +j: U32, h: Outside(n, dst, d, j)) -> {Tree.read(U32, copy.words(n, src, dst, s, d, w), j) == Tree.read(U32, dst, j) : U32}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      (head, tail) = h
      Equal.trans(U32, Tree.read(U32, copy.words(n, src, dst, s, d, w), j), Tree.read(U32, set(dst, d, w), j), Tree.read(U32, dst, j), copy.words_other(p, src, set(dst, d, w), U32.add(s, 1), U32.add(d, 1), Tree.read(U32, src, U32.add(s, 1)), j, outside_set(p, dst, U32.add(d, 1), j, d, w, tail)), read_set_other(dst, d, j, w, head))

type ByteApart<-t: Tree.Tree<U32>, -i: U32, -j: U32> is Type:
  WordApart{h: {apart(t, U32.shrn(i, 2n), U32.shrn(j, 2n)) == True{} : Bool}}
  LaneApart{same: {U32.shrn(i, 2n) == U32.shrn(j, 2n) : U32}, different: {U32.to_nat(U32.and(i, 3)) != U32.to_nat(U32.and(j, 3)) : Nat}}

def poke_other(+t: Tree.Tree<U32>, +i: U32, +j: U32, +v: U32, h: ByteApart<t, i, j>) -> {peek(poke(t, i, v), j) == peek(t, j) : U32}:
  match h:
    case WordApart{e}:
      poke_other_word(t, i, j, v, e)
    case LaneApart{es, ne}:
      poke_other_lane(t, i, j, v, es, ne)

def byte_apart_set(+t: Tree.Tree<U32>, +i: U32, +j: U32, +k: U32, +v: U32, h: ByteApart<t, j, k>) -> ByteApart<set(t, i, v), j, k>:
  match h:
    case WordApart{e}:
      WordApart{(%Equal.sym(Bool, apart(set(t, i, v), U32.shrn(j, 2n), U32.shrn(k, 2n)), apart(t, U32.shrn(j, 2n), U32.shrn(k, 2n)), apart_set(t, i, U32.shrn(j, 2n), U32.shrn(k, 2n), v)) : {_ == True{} : Bool}; e)}
    case LaneApart{es, ne}:
      LaneApart{es, ne}

def ByteOutside(n: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32) -> Type:
  match n:
    case 0n:
      Unit
    case 1n+p:
      ByteApart<t, d, j> & ByteOutside(p, t, U32.add(d, 1), j)

def byte_outside_set(n: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32, +i: U32, +v: U32, h: ByteOutside(n, t, d, j)) -> ByteOutside(n, set(t, i, v), d, j):
  match n:
    case 0n:
      Unit{}
    case 1n+p:
      (head, tail) = h
      (byte_apart_set(t, i, d, j, v, head), byte_outside_set(p, t, U32.add(d, 1), j, i, v, tail))

def byte_outside_poke(+n: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32, +i: U32, +v: U32, h: ByteOutside(n, t, d, j)) -> ByteOutside(n, poke(t, i, v), d, j):
  byte_outside_set(n, t, d, j, U32.shrn(i, 2n), U32.or(U32.and(Tree.read(U32, t, U32.shrn(i, 2n)), U32.xor(U32.shln(255, Bytes.shift(i)), 4294967295)), U32.shln(Bytes.b8(v), Bytes.shift(i))), h)

def copy.go_other(n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +v: U32, +j: U32, h: ByteOutside(n, dst, d, j)) -> {peek(copy.go(n, src, dst, s, d, v), j) == peek(dst, j) : U32}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      (head, tail) = h
      Equal.trans(U32, peek(copy.go(n, src, dst, s, d, v), j), peek(poke(dst, d, v), j), peek(dst, j), copy.go_other(p, src, poke(dst, d, v), U32.add(s, 1), U32.add(d, 1), peek(src, U32.add(s, 1)), j, byte_outside_poke(p, dst, U32.add(d, 1), j, d, v, tail)), poke_other(dst, d, j, v, head))

def copy.go_first(+n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +v: U32, h: ByteOutside(n, dst, U32.add(d, 1), d)) -> {peek(copy.go(1n+n, src, dst, s, d, v), d) == Bytes.b8(v) : U32}:
  Equal.trans(U32, peek(copy.go(1n+n, src, dst, s, d, v), d), peek(poke(dst, d, v), d), Bytes.b8(v), copy.go_other(n, src, poke(dst, d, v), U32.add(s, 1), U32.add(d, 1), peek(src, U32.add(s, 1)), d, byte_outside_poke(n, dst, U32.add(d, 1), d, d, v, h)), poke_same(dst, d, v))

def copy.words_first(+n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +w: U32, h: Outside(n, dst, U32.add(d, 1), d)) -> {Tree.read(U32, copy.words(1n+n, src, dst, s, d, w), d) == w : U32}:
  Equal.trans(U32, Tree.read(U32, copy.words(1n+n, src, dst, s, d, w), d), Tree.read(U32, set(dst, d, w), d), w, copy.words_other(n, src, set(dst, d, w), U32.add(s, 1), U32.add(d, 1), Tree.read(U32, src, U32.add(s, 1)), d, outside_set(n, dst, U32.add(d, 1), d, d, w, h)), read_set(dst, d, w))

def retreat(n: Nat, +i: U32) -> U32:
  match n:
    case 0n:
      i
    case 1n+p:
      retreat(p, U32.sub(i, 1))

def observe_split(n: Nat, +m: Nat, +t: Tree.Tree<U32>, +i: U32, +acc: String) -> {observe(Nat.add(n, m), t, i, acc) == observe(m, t, retreat(n, i), observe(n, t, i, acc)) : String}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      observe_split(p, m, t, U32.sub(i, 1), SCon{Chr{peek(t, i)}, acc})

def observe_append(n: Nat, +t: Tree.Tree<U32>, +i: U32, +a: String, +b: String) -> {observe(n, t, i, a ++ b) == observe(n, t, i, a) ++ b : String}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      observe_append(p, t, U32.sub(i, 1), SCon{Chr{peek(t, i)}, a}, b)

def read_fresh.go(+d: Nat, +n: U32, +i: U32, +z: Bool) -> {Tree.read.go(U32, fresh(d), n, i, z) == 0 : U32}:
  match d z:
    case 0n _:
      {==}
    case 1n+p True{}:
      read_fresh.go(p, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n))))
    case 1n+p False{}:
      read_fresh.go(p, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))

def read_fresh(+d: Nat, +i: U32) -> {Tree.read(U32, fresh(d), i) == 0 : U32}:
  read_fresh.go(d, Tree.size(U32, fresh(d)), Tree.J(i, Tree.size(U32, fresh(d))), Tree.Z(i, Tree.size(U32, fresh(d))))

def zero_shr(n: Nat) -> {U32.shrn(0, n) == 0 : U32}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %zero_shr(p) : {U32.shr(U32.shrn(0, p)) == U32.shr(_) : U32}
      {==}

def peek_fresh(+d: Nat, +i: U32) -> {peek(fresh(d), i) == 0 : U32}:
  %Equal.sym(U32, Tree.read(U32, fresh(d), U32.shrn(i, 2n)), 0, read_fresh(d, U32.shrn(i, 2n))) : {Bytes.b8(U32.shrn(_, Bytes.shift(i))) == 0 : U32}
  %Equal.sym(U32, U32.shrn(0, Bytes.shift(i)), 0, zero_shr(Bytes.shift(i))) : {Bytes.b8(_) == 0 : U32}
  {==}

def peek_small(+t: Tree.Tree<U32>, +i: U32) -> {U32.is_lt(peek(t, i), 256) == True{} : Bool}:
  WordModel.and255_lt(U32.shrn(Tree.read(U32, t, U32.shrn(i, 2n)), Bytes.shift(i)))

def copy.go_first_value(+n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, h: ByteOutside(n, dst, U32.add(d, 1), d)) -> {peek(copy.go(1n+n, src, dst, s, d, peek(src, s)), d) == peek(src, s) : U32}:
  Equal.trans(U32, peek(copy.go(1n+n, src, dst, s, d, peek(src, s)), d), Bytes.b8(peek(src, s)), peek(src, s), copy.go_first(n, src, dst, s, d, peek(src, s), h), WordModel.and255_small(peek(src, s), peek_small(src, s)))

def le_add_left(+n: Nat, +m: Nat) -> MNat.le(n, Nat.add(m, n)):
  %MNat.add_comm(n, m) : MNat.le(n, _)
  MNat.le_add_right(n, m)

# Keep increment folded to avoid checker expansion: https://github.com/bendlang/bend/issues/1071.
def add_one_nat(+n: U32, h: MNat.lt(1n+U32.to_nat(n), Lemmas.pow2(32n))) -> {U32.to_nat(U32.add(n, 1)) == 1n+U32.to_nat(n) : Nat}:
  Equal.trans(Nat, U32.to_nat(U32.add(n, 1)), U32.to_nat(U32.inc(n)), 1n+U32.to_nat(n), Equal.cong(U32, Nat, U32.to_nat, U32.add(n, 1), U32.inc(n), Lemmas.u32_add_one(n)), Lemmas.u32_inc_nat(n, h))

def count_nat(+s: String, +n: U32, +limit: Nat, +hl: MNat.le(limit, Lemmas.pow2(32n)), +h: MNat.lt(Nat.add(String.length(s), U32.to_nat(n)), limit)) -> {U32.to_nat(Bytes.count(s, n)) == Nat.add(String.length(s), U32.to_nat(n)) : Nat}:
  match s:
    case SNil{}:
      {==}
    case SCon{c, +tail}:
      +hn = MNat.lt_of_le_of_lt(1n+U32.to_nat(n), 1n+Nat.add(String.length(tail), U32.to_nat(n)), limit, le_add_left(U32.to_nat(n), String.length(tail)), h)
      +he = add_one_nat(n, MNat.lt_of_lt_of_le(1n+U32.to_nat(n), limit, Lemmas.pow2(32n), hn, hl))
      +ht : MNat.lt(Nat.add(String.length(tail), U32.to_nat(U32.add(n, 1))), limit) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(n, 1)), 1n+U32.to_nat(n), he) : MNat.lt(Nat.add(String.length(tail), _), limit)
        %Equal.sym(Nat, Nat.add(String.length(tail), 1n+U32.to_nat(n)), 1n+Nat.add(String.length(tail), U32.to_nat(n)), MNat.add_succ(String.length(tail), U32.to_nat(n))) : MNat.lt(_, limit)
        h)
      %MNat.add_succ(String.length(tail), U32.to_nat(n)) : {U32.to_nat(Bytes.count(tail, U32.add(n, 1))) == _ : Nat}
      %he : {U32.to_nat(Bytes.count(tail, U32.add(n, 1))) == Nat.add(String.length(tail), _) : Nat}
      count_nat(tail, U32.add(n, 1), limit, hl, ht)

def advance(n: Nat, +i: U32) -> U32:
  match n:
    case 0n:
      i
    case 1n+p:
      advance(p, U32.add(i, 1))

def source_at(k: Nat, +src: Tree.Tree<U32>, +s: U32, v: U32) -> U32:
  match k:
    case 0n:
      v
    case 1n+p:
      source_at(p, src, U32.add(s, 1), peek(src, U32.add(s, 1)))

def source_at_value(k: Nat, +src: Tree.Tree<U32>, +s: U32) -> {source_at(k, src, s, peek(src, s)) == peek(src, advance(k, s)) : U32}:
  match k:
    case 0n:
      {==}
    case 1n+p:
      source_at_value(p, src, U32.add(s, 1))

def copy.go_at(k: Nat, +n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +v: U32, h: ByteOutside(n, dst, advance(1n+k, d), advance(k, d))) -> {peek(copy.go(Nat.add(k, 1n+n), src, dst, s, d, v), advance(k, d)) == Bytes.b8(source_at(k, src, s, v)) : U32}:
  match k:
    case 0n:
      copy.go_first(n, src, dst, s, d, v, h)
    case 1n+ +p:
      copy.go_at(p, n, src, poke(dst, d, v), U32.add(s, 1), U32.add(d, 1), peek(src, U32.add(s, 1)), byte_outside_poke(n, dst, advance(1n+p, U32.add(d, 1)), advance(p, U32.add(d, 1)), d, v, h))

def copy.bytes_at(+k: Nat, +n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, h: ByteOutside(n, dst, advance(1n+k, d), advance(k, d))) -> {peek(copy.go(Nat.add(k, 1n+n), src, dst, s, d, peek(src, s)), advance(k, d)) == peek(src, advance(k, s)) : U32}:
  Equal.trans(U32, peek(copy.go(Nat.add(k, 1n+n), src, dst, s, d, peek(src, s)), advance(k, d)), Bytes.b8(source_at(k, src, s, peek(src, s))), peek(src, advance(k, s)), copy.go_at(k, n, src, dst, s, d, peek(src, s), h), (
    %Equal.sym(U32, source_at(k, src, s, peek(src, s)), peek(src, advance(k, s)), source_at_value(k, src, s)) : {Bytes.b8(_) == peek(src, advance(k, s)) : U32}
    WordModel.and255_small(peek(src, advance(k, s)), peek_small(src, advance(k, s)))))

def pending_top(+w: U32, +c: U32) -> {U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), 24n) == Bytes.b8(c) : U32}:
  %Equal.sym(U32, U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), 24n), U32.or(U32.shrn(U32.shrn(w, 8n), 24n), U32.shrn(U32.shln(Bytes.b8(c), 24n), 24n)), Field.shrn_or(24n, U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))) : {_ == Bytes.b8(c) : U32}
  %Equal.sym(U32, U32.shrn(U32.shrn(w, 8n), 24n), 0, Field.shrn_shrn_zero(24n, 8n, w, {==})) : {U32.or(_, U32.shrn(U32.shln(Bytes.b8(c), 24n), 24n)) == Bytes.b8(c) : U32}
  %Equal.sym(U32, U32.or(0, U32.shrn(U32.shln(Bytes.b8(c), 24n), 24n)), U32.shrn(U32.shln(Bytes.b8(c), 24n), 24n), Field.u32_zero_or(U32.shrn(U32.shln(Bytes.b8(c), 24n), 24n))) : {_ == Bytes.b8(c) : U32}
  Equal.trans(U32, U32.shrn(U32.shln(Bytes.b8(c), 24n), 24n), Bytes.b8(Bytes.b8(c)), Bytes.b8(c), Field.high_field(8, Bytes.b8(c), {==}), WordModel.and255_small(Bytes.b8(c), WordModel.and255_lt(c)))

def shrn_add(+v: U32, +a: Nat, b: Nat) -> {U32.shrn(U32.shrn(v, a), b) == U32.shrn(v, Nat.add(b, a)) : U32}:
  match b:
    case 0n:
      {==}
    case 1n+ +p:
      Equal.cong(U32, U32, U32.shr, U32.shrn(U32.shrn(v, a), p), U32.shrn(v, Nat.add(p, a)), shrn_add(v, a, p))

def pending_lane(+w: U32, +c: U32, +drop: Nat, +lane: Nat, h: {Nat.add(lane, drop) == 24n : Nat}) -> {Bytes.b8(U32.shrn(U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), drop), lane)) == Bytes.b8(c) : U32}:
  +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
  %Equal.sym(U32, U32.shrn(U32.shrn(v, drop), lane), U32.shrn(v, Nat.add(lane, drop)), shrn_add(v, drop, lane)) : {Bytes.b8(_) == Bytes.b8(c) : U32}
  %Equal.sym(Nat, Nat.add(lane, drop), 24n, h) : {Bytes.b8(U32.shrn(v, _)) == Bytes.b8(c) : U32}
  %Equal.sym(U32, U32.shrn(v, 24n), Bytes.b8(c), pending_top(w, c)) : {Bytes.b8(_) == Bytes.b8(c) : U32}
  WordModel.and255_small(Bytes.b8(c), WordModel.and255_lt(c))

def from_one_zero(+t: Tree.Tree<U32>, +w: U32, +c: U32) -> {peek(from.go(SCon{Chr{c}, SNil{}}, t, 0, w), 0) == Bytes.b8(c) : U32}:
  +v = U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), 24n)
  %Equal.sym(U32, Tree.read(U32, set(t, 0, v), 0), v, read_set(t, 0, v)) : {Bytes.b8(_) == Bytes.b8(c) : U32}
  pending_lane(w, c, 24n, 0n, {==})

def append_unaligned_at(+la: U32, +a: Tree.Tree<U32>, +lb: U32, +b: Tree.Tree<U32>, +k: Nat, +n: Nat, hd: {U32.is_eq(U32.and(la, 3), 0) == False{} : Bool}, hm: {U32.to_nat(lb) == Nat.add(k, 1n+n) : Nat}, h: ByteOutside(n, grow(la, a, U32.add(la, lb)), advance(1n+k, la), advance(k, la))) -> {peek(append(la, a, lb, b), advance(k, la)) == peek(b, advance(k, 0)) : U32}:
  %Equal.sym(Bool, U32.is_eq(U32.and(la, 3), 0), False{}, hd) : {peek(copy.dst(_, lb, b, grow(la, a, U32.add(la, lb)), 0, la), advance(k, la)) == peek(b, advance(k, 0)) : U32}
  %Equal.sym(Nat, U32.to_nat(lb), Nat.add(k, 1n+n), hm) : {peek(copy.go(_, b, grow(la, a, U32.add(la, lb)), 0, la, peek(b, 0)), advance(k, la)) == peek(b, advance(k, 0)) : U32}
  copy.bytes_at(k, n, b, grow(la, a, U32.add(la, lb)), 0, la, h)

def from_one_end(+t: Tree.Tree<U32>, +i: U32, +j: U32, +r: U32, +q: U32, +w: U32, +c: U32) -> Tree.Tree<U32>:
  flush(U32.is_ne(q, 0), flush(U32.is_eq(r, 3), t, U32.shrn(i, 2n), U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))), U32.shrn(j, 2n), U32.shrn(Bool.pick(U32, U32.is_eq(r, 3), 0, U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))), U32.to_nat(U32.mul(U32.and(U32.sub(4, q), 3), 8))))

def from_one_normal(+t: Tree.Tree<U32>, +i: U32, +j: U32, +r: U32, +q: U32, +w: U32, +c: U32, hi: {U32.and(i, 3) == r : U32}, hj: {U32.and(j, 3) == q : U32}, he: {U32.add(i, 1) == j : U32}) -> {from.go(SCon{Chr{c}, SNil{}}, t, i, w) == from_one_end(t, i, j, r, q, w, c) : Tree.Tree<U32>}:
  %Equal.sym(U32, U32.add(i, 1), j, he) : {from.go(SNil{}, flush(U32.is_eq(U32.and(i, 3), 3), t, U32.shrn(i, 2n), U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))), _, Bool.pick(U32, U32.is_eq(U32.and(i, 3), 3), 0, U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)))) == from_one_end(t, i, j, r, q, w, c) : Tree.Tree<U32>}
  %Equal.sym(U32, U32.and(i, 3), r, hi) : {from.go(SNil{}, flush(U32.is_eq(_, 3), t, U32.shrn(i, 2n), U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))), j, Bool.pick(U32, U32.is_eq(_, 3), 0, U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)))) == from_one_end(t, i, j, r, q, w, c) : Tree.Tree<U32>}
  %Equal.sym(U32, U32.and(j, 3), q, hj) : {from_one_end(t, i, j, r, _, w, c) == from_one_end(t, i, j, r, q, w, c) : Tree.Tree<U32>}
  {==}

def from_one_bits(+a: Bool, +b: Bool, +tail: Word(30n), +t: Tree.Tree<U32>, +w: U32, +c: U32) -> {peek(from.go(SCon{Chr{c}, SNil{}}, t, U32{WCon{a, WCon{b, tail}}}, w), U32{WCon{a, WCon{b, tail}}}) == Bytes.b8(c) : U32}:
  match a b:
    case False{} False{}:
      +i : U32 = U32{WCon{False{}, WCon{False{}, tail}}}
      +j : U32 = U32{WCon{True{}, WCon{False{}, tail}}}
      %Equal.sym(Tree.Tree<U32>, from.go(SCon{Chr{c}, SNil{}}, t, i, w), from_one_end(t, i, j, 0, 1, w, c), from_one_normal(t, i, j, 0, 1, w, c, low2(False{}, False{}, tail), low2(True{}, False{}, tail), Lemmas.u32_add_one(i))) : {peek(_, i) == Bytes.b8(c) : U32}
      %Equal.sym(U32, U32.and(i, 3), 0, low2(False{}, False{}, tail)) : {Bytes.b8(U32.shrn(Tree.read(U32, from_one_end(t, i, j, 0, 1, w, c), U32.shrn(i, 2n)), U32.to_nat(U32.mul(_, 8)))) == Bytes.b8(c) : U32}
      +v = U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), 24n)
      %Equal.sym(U32, Tree.read(U32, set(t, U32.shrn(i, 2n), v), U32.shrn(i, 2n)), v, read_set(t, U32.shrn(i, 2n), v)) : {Bytes.b8(_) == Bytes.b8(c) : U32}
      pending_lane(w, c, 24n, 0n, {==})
    case True{} False{}:
      +i : U32 = U32{WCon{True{}, WCon{False{}, tail}}}
      +j : U32 = U32{WCon{False{}, WCon{True{}, tail}}}
      %Equal.sym(Tree.Tree<U32>, from.go(SCon{Chr{c}, SNil{}}, t, i, w), from_one_end(t, i, j, 1, 2, w, c), from_one_normal(t, i, j, 1, 2, w, c, low2(True{}, False{}, tail), low2(False{}, True{}, tail), Lemmas.u32_add_one(i))) : {peek(_, i) == Bytes.b8(c) : U32}
      %Equal.sym(U32, U32.and(i, 3), 1, low2(True{}, False{}, tail)) : {Bytes.b8(U32.shrn(Tree.read(U32, from_one_end(t, i, j, 1, 2, w, c), U32.shrn(i, 2n)), U32.to_nat(U32.mul(_, 8)))) == Bytes.b8(c) : U32}
      +v = U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), 16n)
      %Equal.sym(U32, Tree.read(U32, set(t, U32.shrn(i, 2n), v), U32.shrn(i, 2n)), v, read_set(t, U32.shrn(i, 2n), v)) : {Bytes.b8(U32.shrn(_, 8n)) == Bytes.b8(c) : U32}
      pending_lane(w, c, 16n, 8n, {==})
    case False{} True{}:
      +i : U32 = U32{WCon{False{}, WCon{True{}, tail}}}
      +j : U32 = U32{WCon{True{}, WCon{True{}, tail}}}
      %Equal.sym(Tree.Tree<U32>, from.go(SCon{Chr{c}, SNil{}}, t, i, w), from_one_end(t, i, j, 2, 3, w, c), from_one_normal(t, i, j, 2, 3, w, c, low2(False{}, True{}, tail), low2(True{}, True{}, tail), Lemmas.u32_add_one(i))) : {peek(_, i) == Bytes.b8(c) : U32}
      %Equal.sym(U32, U32.and(i, 3), 2, low2(False{}, True{}, tail)) : {Bytes.b8(U32.shrn(Tree.read(U32, from_one_end(t, i, j, 2, 3, w, c), U32.shrn(i, 2n)), U32.to_nat(U32.mul(_, 8)))) == Bytes.b8(c) : U32}
      +v = U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), 8n)
      %Equal.sym(U32, Tree.read(U32, set(t, U32.shrn(i, 2n), v), U32.shrn(i, 2n)), v, read_set(t, U32.shrn(i, 2n), v)) : {Bytes.b8(U32.shrn(_, 16n)) == Bytes.b8(c) : U32}
      pending_lane(w, c, 8n, 16n, {==})
    case True{} True{}:
      +i : U32 = U32{WCon{True{}, WCon{True{}, tail}}}
      +j : U32 = U32{WCon{False{}, WCon{False{}, Word.inc(30n, tail)}}}
      %Equal.sym(Tree.Tree<U32>, from.go(SCon{Chr{c}, SNil{}}, t, i, w), from_one_end(t, i, j, 3, 0, w, c), from_one_normal(t, i, j, 3, 0, w, c, low2(True{}, True{}, tail), low2(False{}, False{}, Word.inc(30n, tail)), Lemmas.u32_add_one(i))) : {peek(_, i) == Bytes.b8(c) : U32}
      %Equal.sym(U32, U32.and(i, 3), 3, low2(True{}, True{}, tail)) : {Bytes.b8(U32.shrn(Tree.read(U32, from_one_end(t, i, j, 3, 0, w, c), U32.shrn(i, 2n)), U32.to_nat(U32.mul(_, 8)))) == Bytes.b8(c) : U32}
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      %Equal.sym(U32, Tree.read(U32, set(t, U32.shrn(i, 2n), v), U32.shrn(i, 2n)), v, read_set(t, U32.shrn(i, 2n), v)) : {Bytes.b8(U32.shrn(_, 24n)) == Bytes.b8(c) : U32}
      pending_lane(w, c, 0n, 24n, {==})

def from_one(+t: Tree.Tree<U32>, +i: U32, +w: U32, +c: U32) -> {peek(from.go(SCon{Chr{c}, SNil{}}, t, i, w), i) == Bytes.b8(c) : U32}:
  match i:
    case U32{WCon{+a, WCon{+b, +tail}}}:
      from_one_bits(a, b, tail, t, w, c)

def from_last(+s: String, +t: Tree.Tree<U32>, +i: U32, +w: U32, +c: U32) -> {peek(from.go(s ++ SCon{Chr{c}, SNil{}}, t, i, w), advance(String.length(s), i)) == Bytes.b8(c) : U32}:
  match s:
    case SNil{}:
      from_one(t, i, w, c)
    case SCon{Chr{+a}, +rest}:
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(a), 24n))
      +full = U32.is_eq(U32.and(i, 3), 3)
      from_last(rest, flush(full, t, U32.shrn(i, 2n), v), U32.add(i, 1), Bool.pick(U32, full, 0, v), c)

def copy.words_source(k: Nat, +src: Tree.Tree<U32>, +s: U32, w: U32) -> U32:
  match k:
    case 0n:
      w
    case 1n+p:
      copy.words_source(p, src, U32.add(s, 1), Tree.read(U32, src, U32.add(s, 1)))

def copy.words_source_value(k: Nat, +src: Tree.Tree<U32>, +s: U32) -> {copy.words_source(k, src, s, Tree.read(U32, src, s)) == Tree.read(U32, src, advance(k, s)) : U32}:
  match k:
    case 0n:
      {==}
    case 1n+p:
      copy.words_source_value(p, src, U32.add(s, 1))

def copy.words_at(k: Nat, +n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +w: U32, h: Outside(n, dst, advance(1n+k, d), advance(k, d))) -> {Tree.read(U32, copy.words(Nat.add(k, 1n+n), src, dst, s, d, w), advance(k, d)) == copy.words_source(k, src, s, w) : U32}:
  match k:
    case 0n:
      copy.words_first(n, src, dst, s, d, w, h)
    case 1n+ +p:
      copy.words_at(p, n, src, set(dst, d, w), U32.add(s, 1), U32.add(d, 1), Tree.read(U32, src, U32.add(s, 1)), outside_set(n, dst, advance(1n+p, U32.add(d, 1)), advance(p, U32.add(d, 1)), d, w, h))

def copy.words_value(+k: Nat, +n: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, h: Outside(n, dst, advance(1n+k, d), advance(k, d))) -> {Tree.read(U32, copy.words(Nat.add(k, 1n+n), src, dst, s, d, Tree.read(U32, src, s)), advance(k, d)) == Tree.read(U32, src, advance(k, s)) : U32}:
  Equal.trans(U32, Tree.read(U32, copy.words(Nat.add(k, 1n+n), src, dst, s, d, Tree.read(U32, src, s)), advance(k, d)), copy.words_source(k, src, s, Tree.read(U32, src, s)), Tree.read(U32, src, advance(k, s)), copy.words_at(k, n, src, dst, s, d, Tree.read(U32, src, s), h), copy.words_source_value(k, src, s))

def as_bits(t: Tree.Tree<U32>) -> Bound.Tree:
  match t:
    case Tree.Leaf{x}:
      Bound.Leaf{x}
    case Tree.Node{xs, ys}:
      Bound.Node{as_bits(xs), as_bits(ys)}

def as_bits_size(+t: Tree.Tree<U32>) -> {Tree.size(U32, t) == Bound.size(as_bits(t)) : U32}:
  match t:
    case Tree.Leaf{x}:
      {==}
    case Tree.Node{xs, ys}:
      Equal.cong(U32, U32, U32.shl, Tree.size(U32, xs), Bound.size(as_bits(xs)), as_bits_size(xs))

def apart_separate(+depth: Nat, +t: Tree.Tree<U32>, +n: U32, +i: U32, +j: U32, +z: Bool, +q: Bool, h: Bound.shape(depth, as_bits(t)), sep: Bound.separate(depth, n, i, j, z, q)) -> {apart.go(t, n, i, j, z, q) == True{} : Bool}:
  match depth t z q:
    case 0n Tree.Leaf{x} _ _:
      match sep:
    case 0n Tree.Node{xs, ys} _ _:
      match h:
    case 1n+p Tree.Leaf{x} _ _:
      match h:
    case 1n+ +p Tree.Node{xs, ys} True{} True{}:
      (hl, hr) = h
      apart_separate(p, xs, U32.shr(n), i, j, U32.is_lt(i, U32.shr(U32.shr(n))), U32.is_lt(j, U32.shr(U32.shr(n))), hl, sep)
    case 1n+ +p Tree.Node{xs, ys} False{} False{}:
      (hl, hr) = h
      apart_separate(p, ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.sub(j, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))), hr, sep)
    case 1n+p Tree.Node{xs, ys} True{} False{}:
      {==}
    case 1n+p Tree.Node{xs, ys} False{} True{}:
      {==}

def apart_bounded.of(+depth: Nat, +t: Tree.Tree<U32>, +i: U32, +j: U32, hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), ne: {U32.is_eq(i, j) == False{} : Bool}, hs: Bound.shape(depth, as_bits(t)) & Bound.shape(depth, as_bits(t))) -> {apart(t, i, j) == True{} : Bool}:
  (ha, hb) = hs
  +en = Equal.trans(U32, Tree.size(U32, t), Bound.size(as_bits(t)), Bound.size(Bound.zeros(depth)), as_bits_size(t), Bound.shape_size(depth, as_bits(t), hb))
  apart_separate(depth, t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), Tree.J(j, Tree.size(U32, t)), Tree.Z(i, Tree.size(U32, t)), Tree.Z(j, Tree.size(U32, t)), ha, Bound.separate_in_range(depth, Tree.size(U32, t), i, j, hd, hi, hj, ne, en))

def apart_bounded(+depth: Nat, +t: Tree.Tree<U32>, +i: U32, +j: U32, h: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), ne: {U32.is_eq(i, j) == False{} : Bool}) -> {apart(t, i, j) == True{} : Bool}:
  apart_bounded.of(depth, t, i, j, hd, hi, hj, ne, Bound.shape_copy(depth, as_bits(t), h))

def fresh_shape(+depth: Nat) -> Bound.shape(depth, as_bits(fresh(depth))):
  match depth:
    case 0n:
      Unit{}
    case 1n+ +p:
      (fresh_shape(p), fresh_shape(p))

def set_shape.go(+depth: Nat, +t: Tree.Tree<U32>, +n: U32, +i: U32, +v: U32, +z: Bool, h: Bound.shape(depth, as_bits(t))) -> Bound.shape(depth, as_bits(set.go(t, n, i, v, z))):
  match depth t z:
    case 0n Tree.Leaf{x} _:
      Unit{}
    case 0n Tree.Node{xs, ys} _:
      match h:
    case 1n+p Tree.Leaf{x} _:
      match h:
    case 1n+ +p Tree.Node{xs, ys} True{}:
      (hl, hr) = h
      (set_shape.go(p, xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))), hl), hr)
    case 1n+ +p Tree.Node{xs, ys} False{}:
      (hl, hr) = h
      (hl, set_shape.go(p, ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), hr))

def set_shape(+depth: Nat, +t: Tree.Tree<U32>, +i: U32, +v: U32, h: Bound.shape(depth, as_bits(t))) -> Bound.shape(depth, as_bits(set(t, i, v))):
  set_shape.go(depth, t, Tree.size(U32, t), Tree.J(i, Tree.size(U32, t)), v, Tree.Z(i, Tree.size(U32, t)), h)

def nat_eq_false_gt(+a: Nat, +b: Nat, h: MNat.lt(a, b)) -> {Nat.is_eq(b, a) == False{} : Bool}:
  match a b:
    case 0n 0n:
      Empty.absurd({True{} == False{} : Bool}, WordModel.false_true(h))
    case 0n 1n+p:
      {==}
    case 1n+p 0n:
      Empty.absurd({False{} == False{} : Bool}, WordModel.false_true(h))
    case 1n+p 1n+q:
      nat_eq_false_gt(p, q, h)

def u32_eq_false_gt(+i: U32, +j: U32, h: MNat.lt(U32.to_nat(i), U32.to_nat(j))) -> {U32.is_eq(j, i) == False{} : Bool}:
  Equal.trans(Bool, U32.is_eq(j, i), Nat.is_eq(U32.to_nat(j), U32.to_nat(i)), False{}, Lemmas.u32_is_eq_nat(j, i), nat_eq_false_gt(U32.to_nat(i), U32.to_nat(j), h))

def outside_numeric.of(n: Nat, +depth: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32, +limit: Nat, hs: Bound.shape(depth, as_bits(t)) & Bound.shape(depth, as_bits(t)), +hd: MNat.lt(depth, 32n), +hl: MNat.le(limit, Lemmas.pow2(depth)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +hj: MNat.lt(U32.to_nat(j), U32.to_nat(d)), +end: MNat.lt(Nat.add(n, U32.to_nat(d)), limit)) -> Outside(n, t, d, j):
  match n hs:
    case 0n _:
      Unit{}
    case 1n+ +p Tuple{ha, hb}:
      +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(d), 1n+Nat.add(p, U32.to_nat(d)), limit, le_add_left(U32.to_nat(d), p), end)
      +he = add_one_nat(d, MNat.lt_of_lt_of_le(1n+U32.to_nat(d), limit, Lemmas.pow2(32n), step, hu))
      +db = MNat.lt_trans(U32.to_nat(d), 1n+U32.to_nat(d), limit, MNat.lt_succ_self(U32.to_nat(d)), step)
      +bound = MNat.lt_of_lt_of_le(U32.to_nat(d), limit, Lemmas.pow2(depth), db, hl)
      +head = apart_bounded(depth, t, d, j, ha, hd, bound, MNat.lt_trans(U32.to_nat(j), U32.to_nat(d), Lemmas.pow2(depth), hj, bound), u32_eq_false_gt(j, d, hj))
      +next : MNat.lt(Nat.add(p, U32.to_nat(U32.add(d, 1))), limit) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(d, 1)), 1n+U32.to_nat(d), he) : MNat.lt(Nat.add(p, _), limit)
        %Equal.sym(Nat, Nat.add(p, 1n+U32.to_nat(d)), 1n+Nat.add(p, U32.to_nat(d)), MNat.add_succ(p, U32.to_nat(d))) : MNat.lt(_, limit)
        end)
      +later : MNat.lt(U32.to_nat(j), U32.to_nat(U32.add(d, 1))) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(d, 1)), 1n+U32.to_nat(d), he) : MNat.lt(U32.to_nat(j), _)
        MNat.lt_trans(U32.to_nat(j), U32.to_nat(d), 1n+U32.to_nat(d), hj, MNat.lt_succ_self(U32.to_nat(d))))
      (head, outside_numeric.of(p, depth, t, U32.add(d, 1), j, limit, Bound.shape_copy(depth, as_bits(t), hb), hd, hl, hu, later, next))

def outside_numeric(+n: Nat, +depth: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Lemmas.pow2(depth)), hu: MNat.le(limit, Lemmas.pow2(32n)), hj: MNat.lt(U32.to_nat(j), U32.to_nat(d)), end: MNat.lt(Nat.add(n, U32.to_nat(d)), limit)) -> Outside(n, t, d, j):
  outside_numeric.of(n, depth, t, d, j, limit, Bound.shape_copy(depth, as_bits(t), shape), hd, hl, hu, hj, end)

def advance_nat(n: Nat, +i: U32, +limit: Nat, +hl: MNat.le(limit, Lemmas.pow2(32n)), +h: MNat.lt(Nat.add(n, U32.to_nat(i)), limit)) -> {U32.to_nat(advance(n, i)) == Nat.add(n, U32.to_nat(i)) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+ +p:
      +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(i), 1n+Nat.add(p, U32.to_nat(i)), limit, le_add_left(U32.to_nat(i), p), h)
      +he = add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), step, hl))
      +next : MNat.lt(Nat.add(p, U32.to_nat(U32.add(i, 1))), limit) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : MNat.lt(Nat.add(p, _), limit)
        %Equal.sym(Nat, Nat.add(p, 1n+U32.to_nat(i)), 1n+Nat.add(p, U32.to_nat(i)), MNat.add_succ(p, U32.to_nat(i))) : MNat.lt(_, limit)
        h)
      Equal.trans(Nat, U32.to_nat(advance(p, U32.add(i, 1))), Nat.add(p, U32.to_nat(U32.add(i, 1))), 1n+Nat.add(p, U32.to_nat(i)), advance_nat(p, U32.add(i, 1), limit, hl, next),
        Equal.trans(Nat, Nat.add(p, U32.to_nat(U32.add(i, 1))), Nat.add(p, 1n+U32.to_nat(i)), 1n+Nat.add(p, U32.to_nat(i)), Equal.cong(Nat, Nat, x => Nat.add(p, x), U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he), MNat.add_succ(p, U32.to_nat(i))))

def outside_offset(+k: Nat, +n: Nat, +depth: Nat, +t: Tree.Tree<U32>, +d: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), +hd: MNat.lt(depth, 32n), +hl: MNat.le(limit, Lemmas.pow2(depth)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +end: MNat.lt(Nat.add(n, 1n+Nat.add(k, U32.to_nat(d))), limit)) -> Outside(n, t, advance(1n+k, d), advance(k, d)):
  +kn = Nat.add(k, U32.to_nat(d))
  +hb = MNat.lt_of_le_of_lt(1n+kn, Nat.add(n, 1n+kn), limit, le_add_left(1n+kn, n), end)
  +hk = MNat.lt_trans(kn, 1n+kn, limit, MNat.lt_succ_self(kn), hb)
  +ek = advance_nat(k, d, limit, hu, hk)
  +en = advance_nat(1n+k, d, limit, hu, hb)
  +before : MNat.lt(U32.to_nat(advance(k, d)), U32.to_nat(advance(1n+k, d))) = (
    %Equal.sym(Nat, U32.to_nat(advance(k, d)), kn, ek) : MNat.lt(_, U32.to_nat(advance(1n+k, d)))
    %Equal.sym(Nat, U32.to_nat(advance(1n+k, d)), 1n+kn, en) : MNat.lt(kn, _)
    MNat.lt_succ_self(kn))
  +after : MNat.lt(Nat.add(n, U32.to_nat(advance(1n+k, d))), limit) = (
    %Equal.sym(Nat, U32.to_nat(advance(1n+k, d)), 1n+kn, en) : MNat.lt(Nat.add(n, _), limit)
    end)
  outside_numeric(n, depth, t, advance(1n+k, d), advance(k, d), limit, shape, hd, hl, hu, before, after)

def copy.words_bounded(+k: Nat, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(dst)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Lemmas.pow2(depth)), hu: MNat.le(limit, Lemmas.pow2(32n)), end: MNat.lt(Nat.add(n, 1n+Nat.add(k, U32.to_nat(d))), limit)) -> {Tree.read(U32, copy.words(Nat.add(k, 1n+n), src, dst, s, d, Tree.read(U32, src, s)), advance(k, d)) == Tree.read(U32, src, advance(k, s)) : U32}:
  copy.words_value(k, n, src, dst, s, d, outside_offset(k, n, depth, dst, d, limit, shape, hd, hl, hu, end))

def index_nat(+i: U32) -> {Nat.add(Nat.mul(U32.to_nat(U32.shrn(i, 2n)), 4n), U32.to_nat(U32.and(i, 3))) == U32.to_nat(i) : Nat}:
  %Equal.sym(Nat, U32.to_nat(U32.shrn(i, 2n)), Nat.div(U32.to_nat(i), 4n), Field.shrn_nat(i, 2n)) : {Nat.add(Nat.mul(_, 4n), U32.to_nat(U32.and(i, 3))) == U32.to_nat(i) : Nat}
  %Equal.sym(Nat, U32.to_nat(U32.and(i, 3)), Nat.mod(U32.to_nat(i), 4n), Field.mask_mod(i, 2, {==})) : {Nat.add(Nat.mul(Nat.div(U32.to_nat(i), 4n), 4n), _) == U32.to_nat(i) : Nat}
  MNat.div_mod_eq(U32.to_nat(i), 3n)

def index_inj(+i: U32, +j: U32, hw: {U32.shrn(i, 2n) == U32.shrn(j, 2n) : U32}, hl: {U32.to_nat(U32.and(i, 3)) == U32.to_nat(U32.and(j, 3)) : Nat}) -> {i == j : U32}:
  Lemmas.u32_to_nat_inj(i, j,
    Equal.trans(Nat, U32.to_nat(i), Nat.add(Nat.mul(U32.to_nat(U32.shrn(i, 2n)), 4n), U32.to_nat(U32.and(i, 3))), U32.to_nat(j), Equal.sym(Nat, Nat.add(Nat.mul(U32.to_nat(U32.shrn(i, 2n)), 4n), U32.to_nat(U32.and(i, 3))), U32.to_nat(i), index_nat(i)), (
      %Equal.sym(U32, U32.shrn(i, 2n), U32.shrn(j, 2n), hw) : {Nat.add(Nat.mul(U32.to_nat(_), 4n), U32.to_nat(U32.and(i, 3))) == U32.to_nat(j) : Nat}
      %Equal.sym(Nat, U32.to_nat(U32.and(i, 3)), U32.to_nat(U32.and(j, 3)), hl) : {Nat.add(Nat.mul(U32.to_nat(U32.shrn(j, 2n)), 4n), _) == U32.to_nat(j) : Nat}
      index_nat(j))))

def u32_eq_true(+i: U32, +j: U32, h: {U32.is_eq(i, j) == True{} : Bool}) -> {i == j : U32}:
  Lemmas.u32_to_nat_inj(i, j, MNat.eq_of_is_eq(U32.to_nat(i), U32.to_nat(j), Equal.trans(Bool, Nat.is_eq(U32.to_nat(i), U32.to_nat(j)), U32.is_eq(i, j), True{}, Equal.sym(Bool, U32.is_eq(i, j), Nat.is_eq(U32.to_nat(i), U32.to_nat(j)), Lemmas.u32_is_eq_nat(i, j)), h)))

def div4_lt(+i: U32, +cap: Nat, h: MNat.lt(U32.to_nat(i), Nat.mul(cap, 4n))) -> MNat.lt(U32.to_nat(U32.shrn(i, 2n)), cap):
  %Equal.sym(Nat, U32.to_nat(U32.shrn(i, 2n)), Nat.div(U32.to_nat(i), 4n), Field.shrn_nat(i, 2n)) : MNat.lt(_, cap)
  MNat.lt_of_not_le(cap, Nat.div(U32.to_nat(i), 4n),
    Equal.trans(Bool, Nat.is_le(cap, Nat.div(U32.to_nat(i), 4n)), Nat.is_le(Nat.mul(cap, 4n), U32.to_nat(i)), False{}, MNat.le_div_iff_mul_le(cap, U32.to_nat(i), 3n), MNat.not_le_of_lt(U32.to_nat(i), Nat.mul(cap, 4n), h)))

def byte_apart_bounded.pick(eq: Bool, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +j: U32, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Nat.mul(Lemmas.pow2(depth), 4n)), hj: MNat.lt(U32.to_nat(j), Nat.mul(Lemmas.pow2(depth), 4n)), ne: {i != j : U32}, he: {U32.is_eq(U32.shrn(i, 2n), U32.shrn(j, 2n)) == eq : Bool}) -> ByteApart<t, i, j>:
  match eq:
    case True{}:
      +same = u32_eq_true(U32.shrn(i, 2n), U32.shrn(j, 2n), he)
      LaneApart{same, e => ne(index_inj(i, j, same, e))}
    case False{}:
      WordApart{apart_bounded(depth, t, U32.shrn(i, 2n), U32.shrn(j, 2n), shape, hd, div4_lt(i, Lemmas.pow2(depth), hi), div4_lt(j, Lemmas.pow2(depth), hj), he)}

def byte_apart_bounded(+depth: Nat, +t: Tree.Tree<U32>, +i: U32, +j: U32, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Nat.mul(Lemmas.pow2(depth), 4n)), hj: MNat.lt(U32.to_nat(j), Nat.mul(Lemmas.pow2(depth), 4n)), ne: {i != j : U32}) -> ByteApart<t, i, j>:
  byte_apart_bounded.pick(U32.is_eq(U32.shrn(i, 2n), U32.shrn(j, 2n)), depth, t, i, j, shape, hd, hi, hj, ne, {==})

def u32_ne_gt(+d: U32, +j: U32, hj: MNat.lt(U32.to_nat(j), U32.to_nat(d)), e: {d == j : U32}) -> Empty:
  MNat.lt_irrefl(U32.to_nat(j))((%e : MNat.lt(U32.to_nat(j), U32.to_nat(_)); hj))

def byte_outside_numeric.of(n: Nat, +depth: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32, +limit: Nat, hs: Bound.shape(depth, as_bits(t)) & Bound.shape(depth, as_bits(t)), +hd: MNat.lt(depth, 32n), +hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +hj: MNat.lt(U32.to_nat(j), U32.to_nat(d)), +end: MNat.lt(Nat.add(n, U32.to_nat(d)), limit)) -> ByteOutside(n, t, d, j):
  match n hs:
    case 0n _:
      Unit{}
    case 1n+ +p Tuple{ha, hb}:
      +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(d), 1n+Nat.add(p, U32.to_nat(d)), limit, le_add_left(U32.to_nat(d), p), end)
      +he = add_one_nat(d, MNat.lt_of_lt_of_le(1n+U32.to_nat(d), limit, Lemmas.pow2(32n), step, hu))
      +db = MNat.lt_trans(U32.to_nat(d), 1n+U32.to_nat(d), limit, MNat.lt_succ_self(U32.to_nat(d)), step)
      +bound = MNat.lt_of_lt_of_le(U32.to_nat(d), limit, Nat.mul(Lemmas.pow2(depth), 4n), db, hl)
      head = byte_apart_bounded(depth, t, d, j, ha, hd, bound, MNat.lt_trans(U32.to_nat(j), U32.to_nat(d), Nat.mul(Lemmas.pow2(depth), 4n), hj, bound), e => u32_ne_gt(d, j, hj, e))
      +next : MNat.lt(Nat.add(p, U32.to_nat(U32.add(d, 1))), limit) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(d, 1)), 1n+U32.to_nat(d), he) : MNat.lt(Nat.add(p, _), limit)
        %Equal.sym(Nat, Nat.add(p, 1n+U32.to_nat(d)), 1n+Nat.add(p, U32.to_nat(d)), MNat.add_succ(p, U32.to_nat(d))) : MNat.lt(_, limit)
        end)
      +later : MNat.lt(U32.to_nat(j), U32.to_nat(U32.add(d, 1))) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(d, 1)), 1n+U32.to_nat(d), he) : MNat.lt(U32.to_nat(j), _)
        MNat.lt_trans(U32.to_nat(j), U32.to_nat(d), 1n+U32.to_nat(d), hj, MNat.lt_succ_self(U32.to_nat(d))))
      (head, byte_outside_numeric.of(p, depth, t, U32.add(d, 1), j, limit, Bound.shape_copy(depth, as_bits(t), hb), hd, hl, hu, later, next))

def byte_outside_numeric(+n: Nat, +depth: Nat, +t: Tree.Tree<U32>, +d: U32, +j: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), hu: MNat.le(limit, Lemmas.pow2(32n)), hj: MNat.lt(U32.to_nat(j), U32.to_nat(d)), end: MNat.lt(Nat.add(n, U32.to_nat(d)), limit)) -> ByteOutside(n, t, d, j):
  byte_outside_numeric.of(n, depth, t, d, j, limit, Bound.shape_copy(depth, as_bits(t), shape), hd, hl, hu, hj, end)

def byte_outside_offset(+k: Nat, +n: Nat, +depth: Nat, +t: Tree.Tree<U32>, +d: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), +hd: MNat.lt(depth, 32n), +hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +end: MNat.lt(Nat.add(n, 1n+Nat.add(k, U32.to_nat(d))), limit)) -> ByteOutside(n, t, advance(1n+k, d), advance(k, d)):
  +kn = Nat.add(k, U32.to_nat(d))
  +hb = MNat.lt_of_le_of_lt(1n+kn, Nat.add(n, 1n+kn), limit, le_add_left(1n+kn, n), end)
  +hk = MNat.lt_trans(kn, 1n+kn, limit, MNat.lt_succ_self(kn), hb)
  +ek = advance_nat(k, d, limit, hu, hk)
  +en = advance_nat(1n+k, d, limit, hu, hb)
  +before : MNat.lt(U32.to_nat(advance(k, d)), U32.to_nat(advance(1n+k, d))) = (
    %Equal.sym(Nat, U32.to_nat(advance(k, d)), kn, ek) : MNat.lt(_, U32.to_nat(advance(1n+k, d)))
    %Equal.sym(Nat, U32.to_nat(advance(1n+k, d)), 1n+kn, en) : MNat.lt(kn, _)
    MNat.lt_succ_self(kn))
  +after : MNat.lt(Nat.add(n, U32.to_nat(advance(1n+k, d))), limit) = (
    %Equal.sym(Nat, U32.to_nat(advance(1n+k, d)), 1n+kn, en) : MNat.lt(Nat.add(n, _), limit)
    end)
  byte_outside_numeric(n, depth, t, advance(1n+k, d), advance(k, d), limit, shape, hd, hl, hu, before, after)

def copy.bytes_bounded(+k: Nat, +n: Nat, +depth: Nat, +src: Tree.Tree<U32>, +dst: Tree.Tree<U32>, +s: U32, +d: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(dst)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), hu: MNat.le(limit, Lemmas.pow2(32n)), end: MNat.lt(Nat.add(n, 1n+Nat.add(k, U32.to_nat(d))), limit)) -> {peek(copy.go(Nat.add(k, 1n+n), src, dst, s, d, peek(src, s)), advance(k, d)) == peek(src, advance(k, s)) : U32}:
  copy.bytes_at(k, n, src, dst, s, d, byte_outside_offset(k, n, depth, dst, d, limit, shape, hd, hl, hu, end))

def flush_shape(full: Bool, +depth: Nat, +t: Tree.Tree<U32>, +k: U32, +w: U32, h: Bound.shape(depth, as_bits(t))) -> Bound.shape(depth, as_bits(flush(full, t, k, w))):
  match full:
    case True{}:
      set_shape(depth, t, k, w, h)
    case False{}:
      h

def flush_frame(full: Bool, +t: Tree.Tree<U32>, +k: U32, +v: U32, +j: U32, h: {apart(t, k, j) == True{} : Bool}) -> {Tree.read(U32, flush(full, t, k, v), j) == Tree.read(U32, t, j) : U32}:
  match full:
    case True{}:
      read_set_other(t, k, j, v, h)
    case False{}:
      {==}

def shr2_inc_mono(+i: U32, he: {U32.to_nat(U32.add(i, 1)) == 1n+U32.to_nat(i) : Nat}) -> MNat.le(U32.to_nat(U32.shrn(i, 2n)), U32.to_nat(U32.shrn(U32.add(i, 1), 2n))):
  %Equal.sym(Nat, U32.to_nat(U32.shrn(i, 2n)), Nat.div(U32.to_nat(i), 4n), Field.shrn_nat(i, 2n)) : MNat.le(_, U32.to_nat(U32.shrn(U32.add(i, 1), 2n)))
  %Equal.sym(Nat, U32.to_nat(U32.shrn(U32.add(i, 1), 2n)), Nat.div(U32.to_nat(U32.add(i, 1)), 4n), Field.shrn_nat(U32.add(i, 1), 2n)) : MNat.le(Nat.div(U32.to_nat(i), 4n), _)
  %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : MNat.le(Nat.div(U32.to_nat(i), 4n), Nat.div(_, 4n))
  MNat.div_le_div(U32.to_nat(i), 1n+U32.to_nat(i), 3n, MNat.le_of_lt(U32.to_nat(i), 1n+U32.to_nat(i), MNat.lt_succ_self(U32.to_nat(i))))

def from_frame.of(+s: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +j: U32, +limit: Nat, hs: Bound.shape(depth, as_bits(t)) & Bound.shape(depth, as_bits(t)), +hd: MNat.lt(depth, 32n), +hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +hj: MNat.lt(U32.to_nat(j), U32.to_nat(U32.shrn(i, 2n))), +end: MNat.lt(Nat.add(String.length(s), U32.to_nat(i)), limit)) -> {Tree.read(U32, from.go(s, t, i, w), j) == Tree.read(U32, t, j) : U32}:
  match s hs:
    case SNil{} Tuple{ha, hb}:
      +ib = MNat.lt_of_lt_of_le(U32.to_nat(i), limit, Nat.mul(Lemmas.pow2(depth), 4n), end, hl)
      +kb = div4_lt(i, Lemmas.pow2(depth), ib)
      +h = apart_bounded(depth, t, U32.shrn(i, 2n), j, ha, hd, kb, MNat.lt_trans(U32.to_nat(j), U32.to_nat(U32.shrn(i, 2n)), Lemmas.pow2(depth), hj, kb), u32_eq_false_gt(j, U32.shrn(i, 2n), hj))
      +r = U32.and(i, 3)
      flush_frame(U32.is_ne(r, 0), t, U32.shrn(i, 2n), U32.shrn(w, U32.to_nat(U32.mul(U32.and(U32.sub(4, r), 3), 8))), j, h)
    case SCon{Chr{+c}, +tail} Tuple{ha, hb}:
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      +full = U32.is_eq(U32.and(i, 3), 3)
      +out = flush(full, t, U32.shrn(i, 2n), v)
      +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(i), 1n+Nat.add(String.length(tail), U32.to_nat(i)), limit, le_add_left(U32.to_nat(i), String.length(tail)), end)
      +he = add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), step, hu))
      +ib = MNat.lt_of_lt_of_le(U32.to_nat(i), limit, Nat.mul(Lemmas.pow2(depth), 4n), MNat.lt_trans(U32.to_nat(i), 1n+U32.to_nat(i), limit, MNat.lt_succ_self(U32.to_nat(i)), step), hl)
      +kb = div4_lt(i, Lemmas.pow2(depth), ib)
      +h = apart_bounded(depth, t, U32.shrn(i, 2n), j, ha, hd, kb, MNat.lt_trans(U32.to_nat(j), U32.to_nat(U32.shrn(i, 2n)), Lemmas.pow2(depth), hj, kb), u32_eq_false_gt(j, U32.shrn(i, 2n), hj))
      +next : MNat.lt(Nat.add(String.length(tail), U32.to_nat(U32.add(i, 1))), limit) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : MNat.lt(Nat.add(String.length(tail), _), limit)
        %Equal.sym(Nat, Nat.add(String.length(tail), 1n+U32.to_nat(i)), 1n+Nat.add(String.length(tail), U32.to_nat(i)), MNat.add_succ(String.length(tail), U32.to_nat(i))) : MNat.lt(_, limit)
        end)
      Equal.trans(U32, Tree.read(U32, from.go(s, t, i, w), j), Tree.read(U32, out, j), Tree.read(U32, t, j),
        from_frame.of(tail, depth, out, U32.add(i, 1), Bool.pick(U32, full, 0, v), j, limit, Bound.shape_copy(depth, as_bits(out), flush_shape(full, depth, t, U32.shrn(i, 2n), v, hb)), hd, hl, hu, MNat.lt_of_lt_of_le(U32.to_nat(j), U32.to_nat(U32.shrn(i, 2n)), U32.to_nat(U32.shrn(U32.add(i, 1), 2n)), hj, shr2_inc_mono(i, he)), next),
        flush_frame(full, t, U32.shrn(i, 2n), v, j, h))

def from_frame(+s: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +j: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), hu: MNat.le(limit, Lemmas.pow2(32n)), hj: MNat.lt(U32.to_nat(j), U32.to_nat(U32.shrn(i, 2n))), end: MNat.lt(Nat.add(String.length(s), U32.to_nat(i)), limit)) -> {Tree.read(U32, from.go(s, t, i, w), j) == Tree.read(U32, t, j) : U32}:
  from_frame.of(s, depth, t, i, w, j, limit, Bound.shape_copy(depth, as_bits(t), shape), hd, hl, hu, hj, end)

def shr2_full_step(+i: U32, he: {U32.to_nat(U32.add(i, 1)) == 1n+U32.to_nat(i) : Nat}, hr: {U32.and(i, 3) == 3 : U32}) -> MNat.lt(U32.to_nat(U32.shrn(i, 2n)), U32.to_nat(U32.shrn(U32.add(i, 1), 2n))):
  +q = U32.to_nat(U32.shrn(i, 2n))
  +ei : {Nat.add(Nat.mul(q, 4n), 3n) == U32.to_nat(i) : Nat} = (
    %hr : {Nat.add(Nat.mul(q, 4n), U32.to_nat(_)) == U32.to_nat(i) : Nat}
    index_nat(i))
  +hm : MNat.le(Nat.mul(1n+q, 4n), U32.to_nat(U32.add(i, 1))) = (
    %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : MNat.le(Nat.mul(1n+q, 4n), _)
    %ei : MNat.le(Nat.mul(1n+q, 4n), 1n+_)
    %Equal.sym(Nat, Nat.add(Nat.mul(q, 4n), 3n), 3n+Nat.mul(q, 4n), MNat.add_comm(Nat.mul(q, 4n), 3n)) : MNat.le(Nat.mul(1n+q, 4n), 1n+_)
    MNat.le_refl(4n+Nat.mul(q, 4n)))
  %Equal.sym(Nat, U32.to_nat(U32.shrn(U32.add(i, 1), 2n)), Nat.div(U32.to_nat(U32.add(i, 1)), 4n), Field.shrn_nat(U32.add(i, 1), 2n)) : MNat.lt(q, _)
  MNat.lt_of_succ_le(q, Nat.div(U32.to_nat(U32.add(i, 1)), 4n),
    Equal.trans(Bool, Nat.is_le(1n+q, Nat.div(U32.to_nat(U32.add(i, 1)), 4n)), Nat.is_le(Nat.mul(1n+q, 4n), U32.to_nat(U32.add(i, 1))), True{}, MNat.le_div_iff_mul_le(1n+q, U32.to_nat(U32.add(i, 1)), 3n), hm))

def from_full_word(+s: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +c: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +hr: {U32.and(i, 3) == 3 : U32}, +end: MNat.lt(Nat.add(String.length(s), 1n+U32.to_nat(i)), limit)) -> {Tree.read(U32, from.go(SCon{Chr{c}, s}, t, i, w), U32.shrn(i, 2n)) == U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)) : U32}:
  +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
  +k = U32.shrn(i, 2n)
  +out = set(t, k, v)
  +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(i), Nat.add(String.length(s), 1n+U32.to_nat(i)), limit, le_add_left(1n+U32.to_nat(i), String.length(s)), end)
  +he = add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), step, hu))
  +next : MNat.lt(Nat.add(String.length(s), U32.to_nat(U32.add(i, 1))), limit) = (
    %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : MNat.lt(Nat.add(String.length(s), _), limit)
    end)
  +hf = from_frame(s, depth, out, U32.add(i, 1), 0, k, limit, set_shape(depth, t, k, v, shape), hd, hl, hu, shr2_full_step(i, he, hr), next)
  %Equal.sym(U32, U32.and(i, 3), 3, hr) : {Tree.read(U32, from.go(s, flush(U32.is_eq(_, 3), t, k, v), U32.add(i, 1), Bool.pick(U32, U32.is_eq(_, 3), 0, v)), k) == v : U32}
  Equal.trans(U32, Tree.read(U32, from.go(s, out, U32.add(i, 1), 0), k), Tree.read(U32, out, k), v, hf, read_set(t, k, v))

def from_full_octet(+s: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +c: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), hu: MNat.le(limit, Lemmas.pow2(32n)), +hr: {U32.and(i, 3) == 3 : U32}, end: MNat.lt(Nat.add(String.length(s), 1n+U32.to_nat(i)), limit)) -> {peek(from.go(SCon{Chr{c}, s}, t, i, w), i) == Bytes.b8(c) : U32}:
  +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
  %Equal.sym(U32, Tree.read(U32, from.go(SCon{Chr{c}, s}, t, i, w), U32.shrn(i, 2n)), v, from_full_word(s, depth, t, i, w, c, limit, shape, hd, hl, hu, hr, end)) : {Bytes.b8(U32.shrn(_, Bytes.shift(i))) == Bytes.b8(c) : U32}
  %Equal.sym(U32, U32.and(i, 3), 3, hr) : {Bytes.b8(U32.shrn(v, U32.to_nat(U32.mul(_, 8)))) == Bytes.b8(c) : U32}
  pending_lane(w, c, 0n, 24n, {==})

def b8_or(+a: U32, +b: U32) -> {Bytes.b8(U32.or(a, b)) == U32.or(Bytes.b8(a), Bytes.b8(b)) : U32}:
  match a b:
    case U32{+x} U32{+y}:
      %Equal.sym(U32, Bytes.b8(U32.or(a, b)), U32{Field.low(32n, 8n, Word.or(32n, x, y))}, Field.and_mask_word(U32.or(a, b), 8)) : {_ == U32.or(Bytes.b8(a), Bytes.b8(b)) : U32}
      %Equal.sym(U32, Bytes.b8(a), U32{Field.low(32n, 8n, x)}, Field.and_mask_word(a, 8)) : {U32{Field.low(32n, 8n, Word.or(32n, x, y))} == U32.or(_, Bytes.b8(b)) : U32}
      %Equal.sym(U32, Bytes.b8(b), U32{Field.low(32n, 8n, y)}, Field.and_mask_word(b, 8)) : {U32{Field.low(32n, 8n, Word.or(32n, x, y))} == U32.or(U32{Field.low(32n, 8n, x)}, _) : U32}
      Equal.cong(Word(32n), U32, z => U32{z}, Field.low(32n, 8n, Word.or(32n, x, y)), Word.or(32n, Field.low(32n, 8n, x), Field.low(32n, 8n, y)), Field.low_or(32n, 8n, x, y))

def pending_keep(+w: U32, +c: U32, +lane: Nat, hz: {Bytes.b8(U32.shrn(U32.shln(Bytes.b8(c), 24n), lane)) == 0 : U32}) -> {Bytes.b8(U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}:
  +a = U32.shrn(U32.shrn(w, 8n), lane)
  +b = U32.shrn(U32.shln(Bytes.b8(c), 24n), lane)
  %Equal.sym(U32, U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), lane), U32.or(a, b), Field.shrn_or(lane, U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))) : {Bytes.b8(_) == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}
  %Equal.sym(U32, Bytes.b8(U32.or(a, b)), U32.or(Bytes.b8(a), Bytes.b8(b)), b8_or(a, b)) : {_ == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}
  %Equal.sym(U32, Bytes.b8(b), 0, hz) : {U32.or(Bytes.b8(a), _) == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}
  %Equal.sym(U32, U32.or(Bytes.b8(a), 0), Bytes.b8(a), Equal.trans(U32, U32.or(Bytes.b8(a), 0), U32.or(0, Bytes.b8(a)), Bytes.b8(a), Field.u32_or_comm(Bytes.b8(a), 0), Field.u32_zero_or(Bytes.b8(a)))) : {_ == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}
  Equal.cong(U32, U32, x => Bytes.b8(x), a, U32.shrn(w, Nat.add(lane, 8n)), shrn_add(w, 8n, lane))

def pending_high_zero(+c: U32, +lane: Nat, h: MNat.le(8n, Nat.sub(24n, lane))) -> {Bytes.b8(U32.shrn(U32.shln(Bytes.b8(c), 24n), lane)) == 0 : U32}:
  +v = U32.shrn(U32.shln(Bytes.b8(c), 24n), lane)
  +w = Field.wshr(lane, 32n, Field.wshl(24n, 32n, Field.word(Bytes.b8(c))))
  +h0 = Field.low_zero_shl(32n, 0n, 24n, Field.word(Bytes.b8(c)), {==})
  +h1 = Field.low_zero_shr(32n, 24n, lane, Field.wshl(24n, 32n, Field.word(Bytes.b8(c))), h0)
  +h2 = Equal.trans(Word(32n), Field.low(32n, 8n, w), Field.low(32n, 8n, Field.low(32n, Nat.sub(24n, lane), w)), Word.zero(32n),
    Equal.sym(Word(32n), Field.low(32n, 8n, Field.low(32n, Nat.sub(24n, lane), w)), Field.low(32n, 8n, w), Field.low_nest(32n, 8n, Nat.sub(24n, lane), w, h)),
    Equal.trans(Word(32n), Field.low(32n, 8n, Field.low(32n, Nat.sub(24n, lane), w)), Field.low(32n, 8n, Word.zero(32n)), Word.zero(32n),
      Equal.cong(Word(32n), Word(32n), x => Field.low(32n, 8n, x), Field.low(32n, Nat.sub(24n, lane), w), Word.zero(32n), h1), Field.low_zero(32n, 8n)))
  %Equal.sym(U32, Bytes.b8(v), U32{Field.low(32n, 8n, Field.word(v))}, Field.and_mask_word(v, 8)) : {_ == 0 : U32}
  %Equal.sym(Word(32n), Field.word(v), w, Field.word_shr_shl(24n, lane, Bytes.b8(c))) : {U32{Field.low(32n, 8n, _)} == 0 : U32}
  Equal.cong(Word(32n), U32, x => U32{x}, Field.low(32n, 8n, w), Word.zero(32n), h2)

def pending_keep_low(+w: U32, +c: U32, +lane: Nat, h: MNat.le(8n, Nat.sub(24n, lane))) -> {Bytes.b8(U32.shrn(U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n)), lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}:
  pending_keep(w, c, lane, pending_high_zero(c, lane, h))

def index_inc_decomp(+i: U32, +r: Nat, he: {U32.to_nat(U32.add(i, 1)) == 1n+U32.to_nat(i) : Nat}, hr: {U32.to_nat(U32.and(i, 3)) == r : Nat}) -> {Nat.add(Nat.mul(U32.to_nat(U32.shrn(i, 2n)), 4n), 1n+r) == U32.to_nat(U32.add(i, 1)) : Nat}:
  +q = U32.to_nat(U32.shrn(i, 2n))
  +ei : {Nat.add(Nat.mul(q, 4n), r) == U32.to_nat(i) : Nat} = (
    %hr : {Nat.add(Nat.mul(q, 4n), _) == U32.to_nat(i) : Nat}
    index_nat(i))
  %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : {Nat.add(Nat.mul(q, 4n), 1n+r) == _ : Nat}
  %Equal.sym(Nat, Nat.add(Nat.mul(q, 4n), 1n+r), 1n+Nat.add(Nat.mul(q, 4n), r), MNat.add_succ(Nat.mul(q, 4n), r)) : {_ == 1n+U32.to_nat(i) : Nat}
  Equal.cong(Nat, Nat, x => 1n+x, Nat.add(Nat.mul(q, 4n), r), U32.to_nat(i), ei)

def shr2_same_inc(+i: U32, +r: Nat, he: {U32.to_nat(U32.add(i, 1)) == 1n+U32.to_nat(i) : Nat}, hr: {U32.to_nat(U32.and(i, 3)) == r : Nat}, small: MNat.lt(1n+r, 4n)) -> {U32.shrn(U32.add(i, 1), 2n) == U32.shrn(i, 2n) : U32}:
  +q = U32.to_nat(U32.shrn(i, 2n))
  +en = index_inc_decomp(i, r, he, hr)
  Lemmas.u32_to_nat_inj(U32.shrn(U32.add(i, 1), 2n), U32.shrn(i, 2n),
    Equal.trans(Nat, U32.to_nat(U32.shrn(U32.add(i, 1), 2n)), Nat.div(U32.to_nat(U32.add(i, 1)), 4n), q, Field.shrn_nat(U32.add(i, 1), 2n),
      Equal.sym(Nat, q, Nat.div(U32.to_nat(U32.add(i, 1)), 4n), Lemmas.div_unique(4n, q, 1n+r, U32.to_nat(U32.add(i, 1)), {==}, small, en))))

def pending_three(+s: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +lane: Nat, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), hu: MNat.le(limit, Lemmas.pow2(32n)), +hr: {U32.and(i, 3) == 3 : U32}, +h: MNat.le(lane, 16n), end: MNat.lt(Nat.add(String.length(s), U32.to_nat(i)), limit)) -> {Bytes.b8(U32.shrn(Tree.read(U32, from.go(s, t, i, w), U32.shrn(i, 2n)), lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}:
  match s:
    case SNil{}:
      +k = U32.shrn(i, 2n)
      +v = U32.shrn(w, 8n)
      %Equal.sym(U32, U32.and(i, 3), 3, hr) : {Bytes.b8(U32.shrn(Tree.read(U32, flush(U32.is_ne(_, 0), t, k, U32.shrn(w, U32.to_nat(U32.mul(U32.and(U32.sub(4, _), 3), 8)))), k), lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}
      %Equal.sym(U32, Tree.read(U32, set(t, k, v), k), v, read_set(t, k, v)) : {Bytes.b8(U32.shrn(_, lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}
      Equal.cong(U32, U32, x => Bytes.b8(x), U32.shrn(v, lane), U32.shrn(w, Nat.add(lane, 8n)), shrn_add(w, 8n, lane))
    case SCon{Chr{+c}, +tail}:
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      %Equal.sym(U32, Tree.read(U32, from.go(s, t, i, w), U32.shrn(i, 2n)), v, from_full_word(tail, depth, t, i, w, c, limit, shape, hd, hl, hu, hr, (
        %Equal.sym(Nat, Nat.add(String.length(tail), 1n+U32.to_nat(i)), 1n+Nat.add(String.length(tail), U32.to_nat(i)), MNat.add_succ(String.length(tail), U32.to_nat(i))) : MNat.lt(_, limit)
        end))) : {Bytes.b8(U32.shrn(_, lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 8n))) : U32}
      pending_keep_low(w, c, lane, MNat.sub_le_sub_left(lane, 16n, h, 24n))

def low_inc_nat(+i: U32, +r: Nat, he: {U32.to_nat(U32.add(i, 1)) == 1n+U32.to_nat(i) : Nat}, hr: {U32.to_nat(U32.and(i, 3)) == r : Nat}, small: MNat.lt(1n+r, 4n)) -> {U32.to_nat(U32.and(U32.add(i, 1), 3)) == 1n+r : Nat}:
  Equal.trans(Nat, U32.to_nat(U32.and(U32.add(i, 1), 3)), Nat.mod(U32.to_nat(U32.add(i, 1)), 4n), 1n+r, Field.mask_mod(U32.add(i, 1), 2, {==}),
    Equal.sym(Nat, 1n+r, Nat.mod(U32.to_nat(U32.add(i, 1)), 4n), Lemmas.mod_unique(U32.to_nat(U32.shrn(i, 2n)), 1n+r, U32.to_nat(U32.add(i, 1)), 4n, small, index_inc_decomp(i, r, he, hr))))

def pending_two(+s: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +lane: Nat, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +hr: {U32.and(i, 3) == 2 : U32}, +h: MNat.le(lane, 8n), +end: MNat.lt(Nat.add(String.length(s), U32.to_nat(i)), limit)) -> {Bytes.b8(U32.shrn(Tree.read(U32, from.go(s, t, i, w), U32.shrn(i, 2n)), lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 16n))) : U32}:
  match s:
    case SNil{}:
      +k = U32.shrn(i, 2n)
      +v = U32.shrn(w, 16n)
      %Equal.sym(U32, U32.and(i, 3), 2, hr) : {Bytes.b8(U32.shrn(Tree.read(U32, flush(U32.is_ne(_, 0), t, k, U32.shrn(w, U32.to_nat(U32.mul(U32.and(U32.sub(4, _), 3), 8)))), k), lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 16n))) : U32}
      %Equal.sym(U32, Tree.read(U32, set(t, k, v), k), v, read_set(t, k, v)) : {Bytes.b8(U32.shrn(_, lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 16n))) : U32}
      Equal.cong(U32, U32, x => Bytes.b8(x), U32.shrn(v, lane), U32.shrn(w, Nat.add(lane, 16n)), shrn_add(w, 16n, lane))
    case SCon{Chr{+c}, +tail}:
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(i), 1n+Nat.add(String.length(tail), U32.to_nat(i)), limit, le_add_left(U32.to_nat(i), String.length(tail)), end)
      +he = add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), step, hu))
      +rn = Equal.cong(U32, Nat, U32.to_nat, U32.and(i, 3), 2, hr)
      +hw = shr2_same_inc(i, 2n, he, rn, {==})
      +hn = Lemmas.u32_to_nat_inj(U32.and(U32.add(i, 1), 3), 3, low_inc_nat(i, 2n, he, rn, {==}))
      +next : MNat.lt(Nat.add(String.length(tail), U32.to_nat(U32.add(i, 1))), limit) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : MNat.lt(Nat.add(String.length(tail), _), limit)
        %Equal.sym(Nat, Nat.add(String.length(tail), 1n+U32.to_nat(i)), 1n+Nat.add(String.length(tail), U32.to_nat(i)), MNat.add_succ(String.length(tail), U32.to_nat(i))) : MNat.lt(_, limit)
        end)
      %Equal.sym(U32, U32.and(i, 3), 2, hr) : {Bytes.b8(U32.shrn(Tree.read(U32, from.go(tail, flush(U32.is_eq(_, 3), t, U32.shrn(i, 2n), v), U32.add(i, 1), Bool.pick(U32, U32.is_eq(_, 3), 0, v)), U32.shrn(i, 2n)), lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 16n))) : U32}
      %hw : {Bytes.b8(U32.shrn(Tree.read(U32, from.go(tail, t, U32.add(i, 1), v), _), lane)) == Bytes.b8(U32.shrn(w, Nat.add(lane, 16n))) : U32}
      Equal.trans(U32, Bytes.b8(U32.shrn(Tree.read(U32, from.go(tail, t, U32.add(i, 1), v), U32.shrn(U32.add(i, 1), 2n)), lane)), Bytes.b8(U32.shrn(v, Nat.add(lane, 8n))), Bytes.b8(U32.shrn(w, Nat.add(lane, 16n))),
        pending_three(tail, depth, t, U32.add(i, 1), v, lane, limit, shape, hd, hl, hu, hn, MNat.le_trans(lane, 8n, 16n, h, {==}), next),
        Equal.trans(U32, Bytes.b8(U32.shrn(v, Nat.add(lane, 8n))), Bytes.b8(U32.shrn(w, Nat.add(Nat.add(lane, 8n), 8n))), Bytes.b8(U32.shrn(w, Nat.add(lane, 16n))), pending_keep_low(w, c, Nat.add(lane, 8n), MNat.sub_le_sub_left(Nat.add(lane, 8n), 16n, MNat.add_le_add_right(lane, 8n, 8n, h), 24n)),
          Equal.cong(Nat, U32, n => Bytes.b8(U32.shrn(w, n)), Nat.add(Nat.add(lane, 8n), 8n), Nat.add(lane, 16n), MNat.add_assoc(lane, 8n, 8n))))

def pending_one(+s: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +hr: {U32.and(i, 3) == 1 : U32}, +end: MNat.lt(Nat.add(String.length(s), U32.to_nat(i)), limit)) -> {Bytes.b8(Tree.read(U32, from.go(s, t, i, w), U32.shrn(i, 2n))) == Bytes.b8(U32.shrn(w, 24n)) : U32}:
  match s:
    case SNil{}:
      +k = U32.shrn(i, 2n)
      +v = U32.shrn(w, 24n)
      %Equal.sym(U32, U32.and(i, 3), 1, hr) : {Bytes.b8(Tree.read(U32, flush(U32.is_ne(_, 0), t, k, U32.shrn(w, U32.to_nat(U32.mul(U32.and(U32.sub(4, _), 3), 8)))), k)) == Bytes.b8(v) : U32}
      Equal.cong(U32, U32, x => Bytes.b8(x), Tree.read(U32, set(t, k, v), k), v, read_set(t, k, v))
    case SCon{Chr{+c}, +tail}:
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(i), 1n+Nat.add(String.length(tail), U32.to_nat(i)), limit, le_add_left(U32.to_nat(i), String.length(tail)), end)
      +he = add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), step, hu))
      +rn = Equal.cong(U32, Nat, U32.to_nat, U32.and(i, 3), 1, hr)
      +hw = shr2_same_inc(i, 1n, he, rn, {==})
      +hn = Lemmas.u32_to_nat_inj(U32.and(U32.add(i, 1), 3), 2, low_inc_nat(i, 1n, he, rn, {==}))
      +next : MNat.lt(Nat.add(String.length(tail), U32.to_nat(U32.add(i, 1))), limit) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : MNat.lt(Nat.add(String.length(tail), _), limit)
        %Equal.sym(Nat, Nat.add(String.length(tail), 1n+U32.to_nat(i)), 1n+Nat.add(String.length(tail), U32.to_nat(i)), MNat.add_succ(String.length(tail), U32.to_nat(i))) : MNat.lt(_, limit)
        end)
      %Equal.sym(U32, U32.and(i, 3), 1, hr) : {Bytes.b8(Tree.read(U32, from.go(tail, flush(U32.is_eq(_, 3), t, U32.shrn(i, 2n), v), U32.add(i, 1), Bool.pick(U32, U32.is_eq(_, 3), 0, v)), U32.shrn(i, 2n))) == Bytes.b8(U32.shrn(w, 24n)) : U32}
      %hw : {Bytes.b8(Tree.read(U32, from.go(tail, t, U32.add(i, 1), v), _)) == Bytes.b8(U32.shrn(w, 24n)) : U32}
      Equal.trans(U32, Bytes.b8(Tree.read(U32, from.go(tail, t, U32.add(i, 1), v), U32.shrn(U32.add(i, 1), 2n))), Bytes.b8(U32.shrn(v, 16n)), Bytes.b8(U32.shrn(w, 24n)),
        pending_two(tail, depth, t, U32.add(i, 1), v, 0n, limit, shape, hd, hl, hu, hn, {==}, next), pending_keep_low(w, c, 16n, {==}))

def next_end(+s: String, +i: U32, +limit: Nat, hu: MNat.le(limit, Lemmas.pow2(32n)), +end: MNat.lt(Nat.add(String.length(s), 1n+U32.to_nat(i)), limit)) -> MNat.lt(Nat.add(String.length(s), U32.to_nat(U32.inc(i))), limit):
  +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(i), Nat.add(String.length(s), 1n+U32.to_nat(i)), limit, le_add_left(1n+U32.to_nat(i), String.length(s)), end)
  +he = Lemmas.u32_inc_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), step, hu))
  %Equal.sym(Nat, U32.to_nat(U32.inc(i)), 1n+U32.to_nat(i), he) : MNat.lt(Nat.add(String.length(s), _), limit)
  end

def from_step_end(+s: String, +t: Tree.Tree<U32>, +i: U32, +j: U32, +r: U32, +w: U32, +c: U32) -> Tree.Tree<U32>:
  +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
  from.go(s, flush(U32.is_eq(r, 3), t, U32.shrn(i, 2n), v), j, Bool.pick(U32, U32.is_eq(r, 3), 0, v))

def from_step_normal(+s: String, +t: Tree.Tree<U32>, +i: U32, +j: U32, +r: U32, +w: U32, +c: U32, hi: {U32.and(i, 3) == r : U32}, he: {U32.add(i, 1) == j : U32}) -> {from.go(SCon{Chr{c}, s}, t, i, w) == from_step_end(s, t, i, j, r, w, c) : Tree.Tree<U32>}:
  %Equal.sym(U32, U32.add(i, 1), j, he) : {from_step_end(s, t, i, _, U32.and(i, 3), w, c) == from_step_end(s, t, i, j, r, w, c) : Tree.Tree<U32>}
  %Equal.sym(U32, U32.and(i, 3), r, hi) : {from_step_end(s, t, i, j, _, w, c) == from_step_end(s, t, i, j, r, w, c) : Tree.Tree<U32>}
  {==}

def from_head_bits(+a: Bool, +b: Bool, +tail: Word(30n), +s: String, +depth: Nat, +t: Tree.Tree<U32>, +w: U32, +c: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), end: MNat.lt(Nat.add(String.length(s), 1n+U32.to_nat(U32{WCon{a, WCon{b, tail}}})), limit), next: MNat.lt(Nat.add(String.length(s), U32.to_nat(U32.inc(U32{WCon{a, WCon{b, tail}}}))), limit)) -> {peek(from.go(SCon{Chr{c}, s}, t, U32{WCon{a, WCon{b, tail}}}, w), U32{WCon{a, WCon{b, tail}}}) == Bytes.b8(c) : U32}:
  match a b:
    case False{} False{}:
      +i : U32 = U32{WCon{False{}, WCon{False{}, tail}}}
      +j : U32 = U32{WCon{True{}, WCon{False{}, tail}}}
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      %Equal.sym(Tree.Tree<U32>, from.go(SCon{Chr{c}, s}, t, i, w), from_step_end(s, t, i, j, 0, w, c), from_step_normal(s, t, i, j, 0, w, c, low2(False{}, False{}, tail), Lemmas.u32_add_one(i))) : {peek(_, i) == Bytes.b8(c) : U32}
      %Equal.sym(U32, U32.and(i, 3), 0, low2(False{}, False{}, tail)) : {Bytes.b8(U32.shrn(Tree.read(U32, from_step_end(s, t, i, j, 0, w, c), U32.shrn(i, 2n)), U32.to_nat(U32.mul(_, 8)))) == Bytes.b8(c) : U32}
      Equal.trans(U32, Bytes.b8(Tree.read(U32, from.go(s, t, j, v), U32.shrn(j, 2n))), Bytes.b8(U32.shrn(v, 24n)), Bytes.b8(c),
        pending_one(s, depth, t, j, v, limit, shape, hd, hl, hu, low2(True{}, False{}, tail), next), pending_lane(w, c, 0n, 24n, {==}))
    case True{} False{}:
      +i : U32 = U32{WCon{True{}, WCon{False{}, tail}}}
      +j : U32 = U32{WCon{False{}, WCon{True{}, tail}}}
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      %Equal.sym(Tree.Tree<U32>, from.go(SCon{Chr{c}, s}, t, i, w), from_step_end(s, t, i, j, 1, w, c), from_step_normal(s, t, i, j, 1, w, c, low2(True{}, False{}, tail), Lemmas.u32_add_one(i))) : {peek(_, i) == Bytes.b8(c) : U32}
      %Equal.sym(U32, U32.and(i, 3), 1, low2(True{}, False{}, tail)) : {Bytes.b8(U32.shrn(Tree.read(U32, from_step_end(s, t, i, j, 1, w, c), U32.shrn(i, 2n)), U32.to_nat(U32.mul(_, 8)))) == Bytes.b8(c) : U32}
      Equal.trans(U32, Bytes.b8(U32.shrn(Tree.read(U32, from.go(s, t, j, v), U32.shrn(j, 2n)), 8n)), Bytes.b8(U32.shrn(v, 24n)), Bytes.b8(c),
        pending_two(s, depth, t, j, v, 8n, limit, shape, hd, hl, hu, low2(False{}, True{}, tail), {==}, next), pending_lane(w, c, 0n, 24n, {==}))
    case False{} True{}:
      +i : U32 = U32{WCon{False{}, WCon{True{}, tail}}}
      +j : U32 = U32{WCon{True{}, WCon{True{}, tail}}}
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(c), 24n))
      %Equal.sym(Tree.Tree<U32>, from.go(SCon{Chr{c}, s}, t, i, w), from_step_end(s, t, i, j, 2, w, c), from_step_normal(s, t, i, j, 2, w, c, low2(False{}, True{}, tail), Lemmas.u32_add_one(i))) : {peek(_, i) == Bytes.b8(c) : U32}
      %Equal.sym(U32, U32.and(i, 3), 2, low2(False{}, True{}, tail)) : {Bytes.b8(U32.shrn(Tree.read(U32, from_step_end(s, t, i, j, 2, w, c), U32.shrn(i, 2n)), U32.to_nat(U32.mul(_, 8)))) == Bytes.b8(c) : U32}
      Equal.trans(U32, Bytes.b8(U32.shrn(Tree.read(U32, from.go(s, t, j, v), U32.shrn(j, 2n)), 16n)), Bytes.b8(U32.shrn(v, 24n)), Bytes.b8(c),
        pending_three(s, depth, t, j, v, 16n, limit, shape, hd, hl, hu, low2(True{}, True{}, tail), {==}, next), pending_lane(w, c, 0n, 24n, {==}))
    case True{} True{}:
      from_full_octet(s, depth, t, U32{WCon{True{}, WCon{True{}, tail}}}, w, c, limit, shape, hd, hl, hu, low2(True{}, True{}, tail), end)

def from_head(+s: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +c: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), hd: MNat.lt(depth, 32n), hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +end: MNat.lt(Nat.add(String.length(s), 1n+U32.to_nat(i)), limit)) -> {peek(from.go(SCon{Chr{c}, s}, t, i, w), i) == Bytes.b8(c) : U32}:
  match i:
    case U32{WCon{+a, WCon{+b, +tail}}}:
      from_head_bits(a, b, tail, s, depth, t, w, c, limit, shape, hd, hl, hu, end, next_end(s, i, limit, hu, end))

def from_at(+prefix: String, +tail: String, +depth: Nat, +t: Tree.Tree<U32>, +i: U32, +w: U32, +c: U32, +limit: Nat, shape: Bound.shape(depth, as_bits(t)), +hd: MNat.lt(depth, 32n), +hl: MNat.le(limit, Nat.mul(Lemmas.pow2(depth), 4n)), +hu: MNat.le(limit, Lemmas.pow2(32n)), +end: MNat.lt(Nat.add(Nat.add(String.length(prefix), 1n+String.length(tail)), U32.to_nat(i)), limit)) -> {peek(from.go(prefix ++ SCon{Chr{c}, tail}, t, i, w), advance(String.length(prefix), i)) == Bytes.b8(c) : U32}:
  match prefix:
    case SNil{}:
      from_head(tail, depth, t, i, w, c, limit, shape, hd, hl, hu, (
        %Equal.sym(Nat, Nat.add(String.length(tail), 1n+U32.to_nat(i)), 1n+Nat.add(String.length(tail), U32.to_nat(i)), MNat.add_succ(String.length(tail), U32.to_nat(i))) : MNat.lt(_, limit)
        end))
    case SCon{Chr{+a}, +rest}:
      +v = U32.or(U32.shrn(w, 8n), U32.shln(Bytes.b8(a), 24n))
      +full = U32.is_eq(U32.and(i, 3), 3)
      +out = flush(full, t, U32.shrn(i, 2n), v)
      +n = Nat.add(String.length(rest), 1n+String.length(tail))
      +step = MNat.lt_of_le_of_lt(1n+U32.to_nat(i), 1n+Nat.add(n, U32.to_nat(i)), limit, le_add_left(U32.to_nat(i), n), end)
      +he = add_one_nat(i, MNat.lt_of_lt_of_le(1n+U32.to_nat(i), limit, Lemmas.pow2(32n), step, hu))
      +next : MNat.lt(Nat.add(n, U32.to_nat(U32.add(i, 1))), limit) = (
        %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), 1n+U32.to_nat(i), he) : MNat.lt(Nat.add(n, _), limit)
        %Equal.sym(Nat, Nat.add(n, 1n+U32.to_nat(i)), 1n+Nat.add(n, U32.to_nat(i)), MNat.add_succ(n, U32.to_nat(i))) : MNat.lt(_, limit)
        end)
      from_at(rest, tail, depth, out, U32.add(i, 1), Bool.pick(U32, full, 0, v), c, limit, flush_shape(full, depth, t, U32.shrn(i, 2n), v, shape), hd, hl, hu, next)

def depth_bound(+f: Nat, +more: Bool, +w: U32, +d: Nat, +cap: U32) -> MNat.le(Bytes.depth.go(f, more, w, d, cap), Nat.add(f, d)):
  match f more:
    case 0n _:
      MNat.le_refl(d)
    case 1n+p False{}:
      le_add_left(d, 1n+p)
    case 1n+ +p True{}:
      %MNat.add_succ(p, d) : MNat.le(Bytes.depth.go(p, U32.is_lt(U32.mul(cap, 2), w), w, 1n+d, U32.mul(cap, 2)), _)
      depth_bound(p, U32.is_lt(U32.mul(cap, 2), w), w, 1n+d, U32.mul(cap, 2))

def mul_two(+n: Nat) -> {Nat.mul(n, 2n) == Nat.double(n) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      Equal.cong(Nat, Nat, x => 2n+x, Nat.mul(p, 2n), Nat.double(p), mul_two(p))

# Keep the multiplier symbolic to avoid checker expansion: https://github.com/bendlang/bend/issues/1071.
def cap_double(+cap: U32, +two: U32, +power: Nat, +limit: Nat, hcap: {U32.to_nat(cap) == power : Nat}, ht: {U32.to_nat(two) == 2n : Nat}, hp: MNat.lt(Nat.double(power), limit), hu: MNat.le(limit, Lemmas.pow2(32n))) -> {U32.to_nat(U32.mul(cap, two)) == Nat.double(power) : Nat}:
  +he = Equal.trans(Nat, Nat.mul(U32.to_nat(cap), U32.to_nat(two)), Nat.mul(power, U32.to_nat(two)), Nat.double(power),
    Equal.cong(Nat, Nat, x => Nat.mul(x, U32.to_nat(two)), U32.to_nat(cap), power, hcap),
    Equal.trans(Nat, Nat.mul(power, U32.to_nat(two)), Nat.mul(power, 2n), Nat.double(power), Equal.cong(Nat, Nat, x => Nat.mul(power, x), U32.to_nat(two), 2n, ht), mul_two(power)))
  +hb : MNat.lt(Nat.mul(U32.to_nat(cap), U32.to_nat(two)), limit) = (
    %Equal.sym(Nat, Nat.mul(U32.to_nat(cap), U32.to_nat(two)), Nat.double(power), he) : MNat.lt(_, limit)
    hp)
  Equal.trans(Nat, U32.to_nat(U32.mul(cap, two)), Nat.mul(U32.to_nat(cap), U32.to_nat(two)), Nat.double(power), Lemmas.u32_mul_nat(cap, two, MNat.lt_of_lt_of_le(Nat.mul(U32.to_nat(cap), U32.to_nat(two)), limit, Lemmas.pow2(32n), hb, hu)), he)


def pow2_le(+a: Nat, +b: Nat, h: MNat.le(a, b)) -> MNat.le(Lemmas.pow2(a), Lemmas.pow2(b)):
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+p:
      MNat.le_of_lt(1n, Lemmas.pow2(1n+p), Field.pow2_lt(0n, 1n+p, {==}))
    case 1n+p 0n:
      Empty.absurd(MNat.le(Lemmas.pow2(1n+p), 1n), WordModel.false_true(h))
    case 1n+p 1n+q:
      MNat.double_le_double(Lemmas.pow2(p), Lemmas.pow2(q), pow2_le(p, q, h))

def depth_sufficient(+f: Nat, +more: Bool, +w: U32, +d: Nat, +cap: U32, +limit: Nat, +hcap: {U32.to_nat(cap) == Lemmas.pow2(d) : Nat}, hw: MNat.le(U32.to_nat(w), Lemmas.pow2(Nat.add(f, d))), +hp: MNat.lt(Lemmas.pow2(Nat.add(f, d)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)), emore: {U32.is_lt(cap, w) == more : Bool}) -> MNat.le(U32.to_nat(w), Lemmas.pow2(Bytes.depth.go(f, more, w, d, cap))):
  match f more:
    case 0n _:
      hw
    case 1n+p False{}:
      %hcap : MNat.le(U32.to_nat(w), _)
      Bound.u32_ge_bound(cap, w, emore)
    case 1n+ +p True{}:
      +step = MNat.lt_of_le_of_lt(Lemmas.pow2(1n+d), Lemmas.pow2(1n+Nat.add(p, d)), limit, pow2_le(1n+d, 1n+Nat.add(p, d), le_add_left(d, p)), hp)
      +hc = cap_double(cap, 2, Lemmas.pow2(d), limit, hcap, {==}, step, hu)
      +next : MNat.le(U32.to_nat(w), Lemmas.pow2(Nat.add(p, 1n+d))) = (
        %Equal.sym(Nat, Nat.add(p, 1n+d), 1n+Nat.add(p, d), MNat.add_succ(p, d)) : MNat.le(U32.to_nat(w), Lemmas.pow2(_))
        hw)
      +np : MNat.lt(Lemmas.pow2(Nat.add(p, 1n+d)), limit) = (
        %Equal.sym(Nat, Nat.add(p, 1n+d), 1n+Nat.add(p, d), MNat.add_succ(p, d)) : MNat.lt(Lemmas.pow2(_), limit)
        hp)
      depth_sufficient(p, U32.is_lt(U32.mul(cap, 2), w), w, 1n+d, U32.mul(cap, 2), limit, hc, next, np, hu, {==})

def depth_false(+f: Nat, +w: U32, +d: Nat, +cap: U32) -> {Bytes.depth.go(f, False{}, w, d, cap) == d : Nat}:
  match f:
    case 0n:
      {==}
    case 1n+p:
      {==}

def depth_stable(+f: Nat, +extra: Nat, +more: Bool, +w: U32, +d: Nat, +cap: U32, +limit: Nat, +hcap: {U32.to_nat(cap) == Lemmas.pow2(d) : Nat}, hw: MNat.le(U32.to_nat(w), Lemmas.pow2(Nat.add(f, d))), +hp: MNat.lt(Lemmas.pow2(Nat.add(f, d)), limit), +hu: MNat.le(limit, Lemmas.pow2(32n)), emore: {U32.is_lt(cap, w) == more : Bool}) -> {Bytes.depth.go(Nat.add(f, extra), more, w, d, cap) == Bytes.depth.go(f, more, w, d, cap) : Nat}:
  match f more:
    case 0n False{}:
      depth_false(extra, w, d, cap)
    case 0n True{}:
      Empty.absurd({Bytes.depth.go(extra, True{}, w, d, cap) == d : Nat},
        MNat.lt_irrefl(U32.to_nat(w))(MNat.lt_of_le_of_lt(U32.to_nat(w), Lemmas.pow2(d), U32.to_nat(w), hw,
          (%hcap : MNat.lt(_, U32.to_nat(w)); Bound.u32_lt_bound(cap, w, emore)))))
    case 1n+p False{}:
      {==}
    case 1n+ +p True{}:
      +step = MNat.lt_of_le_of_lt(Lemmas.pow2(1n+d), Lemmas.pow2(1n+Nat.add(p, d)), limit, pow2_le(1n+d, 1n+Nat.add(p, d), le_add_left(d, p)), hp)
      +hc = cap_double(cap, 2, Lemmas.pow2(d), limit, hcap, {==}, step, hu)
      +next : MNat.le(U32.to_nat(w), Lemmas.pow2(Nat.add(p, 1n+d))) = (
        %Equal.sym(Nat, Nat.add(p, 1n+d), 1n+Nat.add(p, d), MNat.add_succ(p, d)) : MNat.le(U32.to_nat(w), Lemmas.pow2(_))
        hw)
      +np : MNat.lt(Lemmas.pow2(Nat.add(p, 1n+d)), limit) = (
        %Equal.sym(Nat, Nat.add(p, 1n+d), 1n+Nat.add(p, d), MNat.add_succ(p, d)) : MNat.lt(Lemmas.pow2(_), limit)
        hp)
      depth_stable(p, extra, U32.is_lt(U32.mul(cap, 2), w), w, 1n+d, U32.mul(cap, 2), limit, hc, next, np, hu, {==})

def depth_actual(+w: U32, +f: Nat, +extra: Nat, +limit: Nat, +hsum: {Nat.add(f, extra) == 32n : Nat}, hw: MNat.le(U32.to_nat(w), Lemmas.pow2(f)), hp: MNat.lt(Lemmas.pow2(f), limit), +hu: MNat.le(limit, Lemmas.pow2(32n))) -> MNat.le(U32.to_nat(w), Lemmas.pow2(Bytes.depth(w))) & MNat.le(Bytes.depth(w), f):
  +hw0 : MNat.le(U32.to_nat(w), Lemmas.pow2(Nat.add(f, 0n))) = (
    %Equal.sym(Nat, Nat.add(f, 0n), f, MNat.add_zero(f)) : MNat.le(U32.to_nat(w), Lemmas.pow2(_))
    hw)
  +hp0 : MNat.lt(Lemmas.pow2(Nat.add(f, 0n)), limit) = (
    %Equal.sym(Nat, Nat.add(f, 0n), f, MNat.add_zero(f)) : MNat.lt(Lemmas.pow2(_), limit)
    hp)
  +e : {Bytes.depth(w) == Bytes.depth.go(f, U32.is_lt(1, w), w, 0n, 1) : Nat} = (
    %hsum : {Bytes.depth.go(_, U32.is_lt(1, w), w, 0n, 1) == Bytes.depth.go(f, U32.is_lt(1, w), w, 0n, 1) : Nat}
    depth_stable(f, extra, U32.is_lt(1, w), w, 0n, 1, limit, {==}, hw0, hp0, hu, {==}))
  ((%Equal.sym(Nat, Bytes.depth(w), Bytes.depth.go(f, U32.is_lt(1, w), w, 0n, 1), e) : MNat.le(U32.to_nat(w), Lemmas.pow2(_))
    depth_sufficient(f, U32.is_lt(1, w), w, 0n, 1, limit, {==}, hw0, hp0, hu, {==})),
   (%Equal.sym(Nat, Bytes.depth(w), Bytes.depth.go(f, U32.is_lt(1, w), w, 0n, 1), e) : MNat.le(_, f)
    %MNat.add_zero(f) : MNat.le(Bytes.depth.go(f, U32.is_lt(1, w), w, 0n, 1), _)
    depth_bound(f, U32.is_lt(1, w), w, 0n, 1)))
