import Base
import ./bytes.bend as Bytes
import ../lemmas/array.bend as Tree

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
