import Base
import ./bytes.bend as Bytes
import ../lemmas/array.bend as Tree
import ./word-proof.bend as WordModel
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import ../bits/field-proof.bend as Field

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
