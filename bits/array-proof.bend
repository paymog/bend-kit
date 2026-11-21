# An exact copyable model of Base Array<U32>, including irregular trees and wrapping.
import Base
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool
import ./field-proof.bend as Field

type Tree is Data:
  Leaf{value: U32}
  Node{xs: Tree, ys: Tree}

def build(t: Tree) -> Array<U32>:
  match t:
    case Leaf{v}:
      ALeaf{v}
    case Node{xs, ys}:
      ANode{build(xs), build(ys)}

# Base measures only the left spine; U32.shl deliberately preserves overflow.
def size(t: Tree) -> U32:
  match t:
    case Leaf{v}:
      1
    case Node{xs, ys}:
      U32.shl(size(xs))

def get.go(t: Tree, n: U32, +i: U32, z: Bool) -> U32:
  match t z:
    case Leaf{v} _:
      v
    case Node{xs, ys} True{}:
      +h = U32.shr(n)
      get.go(xs, h, i, U32.is_lt(i, U32.shr(h)))
    case Node{xs, ys} False{}:
      +h = U32.shr(n)
      +j = U32.sub(i, h)
      get.go(ys, h, j, U32.is_lt(j, U32.shr(h)))

def get(+t: Tree, i: U32) -> U32:
  +n = size(t)
  +j = U32.and(i, U32.sub(n, 1))
  get.go(t, n, j, U32.is_lt(j, U32.shr(n)))

def set.go(t: Tree, n: U32, +i: U32, v: U32, z: Bool) -> Tree:
  match t z:
    case Leaf{x} _:
      Leaf{v}
    case Node{xs, ys} True{}:
      +h = U32.shr(n)
      Node{set.go(xs, h, i, v, U32.is_lt(i, U32.shr(h))), ys}
    case Node{xs, ys} False{}:
      +h = U32.shr(n)
      +j = U32.sub(i, h)
      Node{xs, set.go(ys, h, j, v, U32.is_lt(j, U32.shr(h)))}

def set(+t: Tree, i: U32, v: U32) -> Tree:
  +n = size(t)
  +j = U32.and(i, U32.sub(n, 1))
  set.go(t, n, j, v, U32.is_lt(j, U32.shr(n)))

def size_bridge(+t: Tree) -> {Array.size(U32, build(t)) == (build(t), size(t)) : Array<U32> & U32}:
  match t:
    case Leaf{v}:
      {==}
    case Node{+xs, +ys}:
      %Equal.sym(Array<U32> & U32, Array.size(U32, build(xs)), (build(xs), size(xs)), size_bridge(xs)) : {Array.size.node(U32, build(ys), _) == (build(Node{xs, ys}), size(Node{xs, ys})) : Array<U32> & U32}
      {==}

def get_go_bridge(+t: Tree, +n: U32, +i: U32, +z: Bool) -> {Array.get.go(U32, build(t), n, i, z) == (build(t), get.go(t, n, i, z)) : Array<U32> & U32}:
  match t z:
    case Leaf{v} _:
      {==}
    case Node{+xs, +ys} True{}:
      %Equal.sym(Array<U32> & U32, Array.get.go(U32, build(xs), U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n)))), (build(xs), get.go(xs, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n))))), get_go_bridge(xs, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n))))) : {Array.swap.lo(U32, build(ys), _) == (build(Node{xs, ys}), get.go(Node{xs, ys}, n, i, True{})) : Array<U32> & U32}
      {==}
    case Node{+xs, +ys} False{}:
      %Equal.sym(Array<U32> & U32, Array.get.go(U32, build(ys), U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n)))), (build(ys), get.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))), get_go_bridge(ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))) : {Array.swap.hi(U32, build(xs), _) == (build(Node{xs, ys}), get.go(Node{xs, ys}, n, i, False{})) : Array<U32> & U32}
      {==}

def get_bridge(+t: Tree, +i: U32) -> {Array.get(U32, build(t), i) == (build(t), get(t, i)) : Array<U32> & U32}:
  %Equal.sym(Array<U32> & U32, Array.size(U32, build(t)), (build(t), size(t)), size_bridge(t)) : {Array.get.at(U32, i, _) == (build(t), get(t, i)) : Array<U32> & U32}
  get_go_bridge(t, size(t), U32.and(i, U32.sub(size(t), 1)), U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))))

# The swap bridge also tracks the discarded old value, so set needs no assumptions.
def swap_go_bridge(+t: Tree, +n: U32, +i: U32, +v: U32, +z: Bool) -> {Array.swap.go(U32, build(t), n, i, v, z) == (build(set.go(t, n, i, v, z)), get.go(t, n, i, z)) : Array<U32> & U32}:
  match t z:
    case Leaf{x} _:
      {==}
    case Node{+xs, +ys} True{}:
      %Equal.sym(Array<U32> & U32, Array.swap.go(U32, build(xs), U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n)))), (build(set.go(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))))), get.go(xs, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n))))), swap_go_bridge(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))))) : {Array.swap.lo(U32, build(ys), _) == (build(set.go(Node{xs, ys}, n, i, v, True{})), get.go(Node{xs, ys}, n, i, True{})) : Array<U32> & U32}
      {==}
    case Node{+xs, +ys} False{}:
      %Equal.sym(Array<U32> & U32, Array.swap.go(U32, build(ys), U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n)))), (build(set.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))), get.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))), swap_go_bridge(ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))) : {Array.swap.hi(U32, build(xs), _) == (build(set.go(Node{xs, ys}, n, i, v, False{})), get.go(Node{xs, ys}, n, i, False{})) : Array<U32> & U32}
      {==}

def swap_bridge(+t: Tree, +i: U32, +v: U32) -> {Array.swap(U32, build(t), i, v) == (build(set(t, i, v)), get(t, i)) : Array<U32> & U32}:
  %Equal.sym(Array<U32> & U32, Array.size(U32, build(t)), (build(t), size(t)), size_bridge(t)) : {Array.swap.at(U32, i, v, _) == (build(set(t, i, v)), get(t, i)) : Array<U32> & U32}
  swap_go_bridge(t, size(t), U32.and(i, U32.sub(size(t), 1)), v, U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))))

def set_bridge(+t: Tree, +i: U32, +v: U32) -> {Array.set(U32, build(t), i, v) == build(set(t, i, v)) : Array<U32>}:
  %Equal.sym(Array<U32> & U32, Array.swap(U32, build(t), i, v), (build(set(t, i, v)), get(t, i)), swap_bridge(t, i, v)) : {Array.set.fin(U32, _) == build(set(t, i, v)) : Array<U32>}
  {==}

def zeros(+depth: Nat) -> Tree:
  match depth:
    case 0n:
      Leaf{0}
    case 1n+p:
      Node{zeros(p), zeros(p)}

def zeros_bridge(+depth: Nat) -> {build(zeros(depth)) == Array.new(U32, depth, 0) : Array<U32>}:
  match depth:
    case 0n:
      {==}
    case 1n++p:
      %Equal.sym(Array<U32>, build(zeros(p)), Array.new(U32, p, 0), zeros_bridge(p)) : {ANode{_, _} == Array.new(U32, 1n+p, 0) : Array<U32>}
      {==}

def node_bridge(+xs: Tree, +ys: Tree) -> {build(Node{xs, ys}) == ANode{build(xs), build(ys)} : Array<U32>}:
  {==}

def grow(t: Tree, depth: Nat) -> Tree:
  Node{t, zeros(depth)}

def grow_bridge(+t: Tree, +depth: Nat) -> {build(grow(t, depth)) == ANode{build(t), Array.new(U32, depth, 0)} : Array<U32>}:
  %Equal.sym(Array<U32>, build(zeros(depth)), Array.new(U32, depth, 0), zeros_bridge(depth)) : {ANode{build(t), _} == ANode{build(t), Array.new(U32, depth, 0)} : Array<U32>}
  {==}

# Balanced shape is separate from the exact, unrestricted runtime mirror.
def shape(+depth: Nat, t: Tree) -> Type:
  match depth t:
    case 0n Leaf{v}:
      Unit
    case 0n Node{xs, ys}:
      Empty
    case 1n+p Leaf{v}:
      Empty
    case 1n+p Node{xs, ys}:
      shape(p, xs) & shape(p, ys)

def set_go_size(+t: Tree, +n: U32, +i: U32, +v: U32, +z: Bool) -> {size(set.go(t, n, i, v, z)) == size(t) : U32}:
  match t z:
    case Leaf{x} _:
      {==}
    case Node{+xs, +ys} True{}:
      %Equal.sym(U32, size(set.go(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))))), size(xs), set_go_size(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))))) : {U32.shl(_) == U32.shl(size(xs)) : U32}
      {==}
    case Node{xs, ys} False{}:
      {==}

def set_size(+t: Tree, +i: U32, +v: U32) -> {size(set(t, i, v)) == size(t) : U32}:
  set_go_size(t, size(t), U32.and(i, U32.sub(size(t), 1)), v, U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))))

def set_go_shape(+depth: Nat, +t: Tree, +n: U32, +i: U32, +v: U32, +z: Bool, h: shape(depth, t)) -> shape(depth, set.go(t, n, i, v, z)):
  match depth t z:
    case 0n Leaf{x} _:
      Unit{}
    case 0n Node{xs, ys} _:
      match h:
    case 1n+p Leaf{x} _:
      match h:
    case 1n++p Node{+xs, +ys} True{}:
      (hx, hy) = h
      (set_go_shape(p, xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))), hx), hy)
    case 1n++p Node{+xs, +ys} False{}:
      (hx, hy) = h
      (hx, set_go_shape(p, ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), hy))

def set_shape(+depth: Nat, +t: Tree, +i: U32, +v: U32, h: shape(depth, t)) -> shape(depth, set(t, i, v)):
  set_go_shape(depth, t, size(t), U32.and(i, U32.sub(size(t), 1)), v, U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))), h)

def get_set_go(+t: Tree, +n: U32, +i: U32, +v: U32, +z: Bool) -> {get.go(set.go(t, n, i, v, z), n, i, z) == v : U32}:
  match t z:
    case Leaf{x} _:
      {==}
    case Node{+xs, +ys} True{}:
      get_set_go(xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))))
    case Node{+xs, +ys} False{}:
      get_set_go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))

def get_set(+t: Tree, +i: U32, +v: U32) -> {get(set(t, i, v), i) == v : U32}:
  %Equal.sym(U32, size(set(t, i, v)), size(t), set_size(t, i, v)) : {get.go(set(t, i, v), _, U32.and(i, U32.sub(_, 1)), U32.is_lt(U32.and(i, U32.sub(_, 1)), U32.shr(_))) == v : U32}
  get_set_go(t, size(t), U32.and(i, U32.sub(size(t), 1)), v, U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))))

def zeros_shape(+depth: Nat) -> shape(depth, zeros(depth)):
  match depth:
    case 0n:
      Unit{}
    case 1n++p:
      (zeros_shape(p), zeros_shape(p))

def zeros_get_go(+depth: Nat, +n: U32, +i: U32, +z: Bool) -> {get.go(zeros(depth), n, i, z) == 0 : U32}:
  match depth z:
    case 0n _:
      {==}
    case 1n++p True{}:
      zeros_get_go(p, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n))))
    case 1n++p False{}:
      zeros_get_go(p, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))

def zeros_get(+depth: Nat, +i: U32) -> {get(zeros(depth), i) == 0 : U32}:
  zeros_get_go(depth, size(zeros(depth)), U32.and(i, U32.sub(size(zeros(depth)), 1)), U32.is_lt(U32.and(i, U32.sub(size(zeros(depth)), 1)), U32.shr(size(zeros(depth)))))

def shape_size(+depth: Nat, +t: Tree, h: shape(depth, t)) -> {size(t) == size(zeros(depth)) : U32}:
  match depth t:
    case 0n Leaf{v}:
      {==}
    case 0n Node{xs, ys}:
      match h:
    case 1n+p Leaf{v}:
      match h:
    case 1n++p Node{+xs, +ys}:
      (hx, hy) = h
      %Equal.sym(U32, size(xs), size(zeros(p)), shape_size(p, xs, hx)) : {U32.shl(_) == size(zeros(1n+p)) : U32}
      {==}

# Separation records only the choices made by Base's traversal, not tree values.
def separate(+depth: Nat, n: U32, +i: U32, +j: U32, zi: Bool, zj: Bool) -> Type:
  match depth zi zj:
    case 0n _ _:
      Empty
    case 1n+p True{} True{}:
      +half = U32.shr(n)
      separate(p, half, i, j, U32.is_lt(i, U32.shr(half)), U32.is_lt(j, U32.shr(half)))
    case 1n+p True{} False{}:
      Unit
    case 1n+p False{} True{}:
      Unit
    case 1n+p False{} False{}:
      +half = U32.shr(n)
      +ii = U32.sub(i, half)
      +jj = U32.sub(j, half)
      separate(p, half, ii, jj, U32.is_lt(ii, U32.shr(half)), U32.is_lt(jj, U32.shr(half)))

def frame_go(+depth: Nat, +t: Tree, +n: U32, +i: U32, +j: U32, +v: U32, +zi: Bool, +zj: Bool, h: shape(depth, t), sep: separate(depth, n, i, j, zi, zj)) -> {get.go(set.go(t, n, i, v, zi), n, j, zj) == get.go(t, n, j, zj) : U32}:
  match depth t zi zj:
    case 0n Leaf{x} _ _:
      match sep:
    case 0n Node{xs, ys} _ _:
      match h:
    case 1n+p Leaf{x} _ _:
      match h:
    case 1n++p Node{+xs, +ys} True{} True{}:
      (hx, hy) = h
      frame_go(p, xs, U32.shr(n), i, j, v, U32.is_lt(i, U32.shr(U32.shr(n))), U32.is_lt(j, U32.shr(U32.shr(n))), hx, sep)
    case 1n+p Node{xs, ys} True{} False{}:
      {==}
    case 1n+p Node{xs, ys} False{} True{}:
      {==}
    case 1n++p Node{+xs, +ys} False{} False{}:
      (hx, hy) = h
      frame_go(p, ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.sub(j, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))), hy, sep)

def frame_separate(+depth: Nat, +t: Tree, +i: U32, +j: U32, +v: U32, h: shape(depth, t), sep: separate(depth, size(t), U32.and(i, U32.sub(size(t), 1)), U32.and(j, U32.sub(size(t), 1)), U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))), U32.is_lt(U32.and(j, U32.sub(size(t), 1)), U32.shr(size(t))))) -> {get(set(t, i, v), j) == get(t, j) : U32}:
  %Equal.sym(U32, size(set(t, i, v)), size(t), set_size(t, i, v)) : {get.go(set(t, i, v), _, U32.and(j, U32.sub(_, 1)), U32.is_lt(U32.and(j, U32.sub(_, 1)), U32.shr(_))) == get(t, j) : U32}
  frame_go(depth, t, size(t), U32.and(i, U32.sub(size(t), 1)), U32.and(j, U32.sub(size(t), 1)), v, U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))), U32.is_lt(U32.and(j, U32.sub(size(t), 1)), U32.shr(size(t))), h, sep)

def grow_shape(+depth: Nat, +t: Tree, h: shape(depth, t)) -> shape(1n+depth, grow(t, depth)):
  (h, zeros_shape(depth))

def shape_copy.node(-depth: Nat, -xs: Tree, -ys: Tree, xx: shape(depth, xs) & shape(depth, xs), yy: shape(depth, ys) & shape(depth, ys)) -> shape(1n+depth, Node{xs, ys}) & shape(1n+depth, Node{xs, ys}):
  (xa, xb) = xx
  (ya, yb) = yy
  ((xa, ya), (xb, yb))

def shape_copy(+depth: Nat, +t: Tree, h: shape(depth, t)) -> shape(depth, t) & shape(depth, t):
  match depth t:
    case 0n Leaf{v}:
      (Unit{}, Unit{})
    case 0n Node{xs, ys}:
      match h:
    case 1n+p Leaf{v}:
      match h:
    case 1n++p Node{+xs, +ys}:
      (hx, hy) = h
      shape_copy.node(p, xs, ys, shape_copy(p, xs, hx), shape_copy(p, ys, hy))

def u32_eq_refl(+i: U32) -> {U32.is_eq(i, i) == True{} : Bool}:
  Equal.trans(Bool, U32.is_eq(i, i), Nat.is_eq(U32.to_nat(i), U32.to_nat(i)), True{}, Lemmas.u32_is_eq_nat(i, i), MNat.is_eq_refl(U32.to_nat(i)))

def u32_ne(+i: U32, +j: U32, h: {U32.is_eq(i, j) == False{} : Bool}, e: {i == j : U32}) -> Empty:
  MBool.true_ne_false()(Equal.trans(Bool, True{}, U32.is_eq(i, i), False{}, Equal.sym(Bool, U32.is_eq(i, i), True{}, u32_eq_refl(i)),
    Equal.trans(Bool, U32.is_eq(i, i), U32.is_eq(i, j), False{},
      Equal.cong(U32, Bool, x => U32.is_eq(i, x), i, j, e), h)))

def sub_inj(+a: Nat, +b: Nat, +c: Nat, ha: MNat.le(c, a), hb: MNat.le(c, b), e: {Nat.sub(a, c) == Nat.sub(b, c) : Nat}) -> {a == b : Nat}:
  Equal.trans(Nat, a, Nat.add(c, Nat.sub(a, c)), b,
    Equal.sym(Nat, Nat.add(c, Nat.sub(a, c)), a, MNat.add_sub_of_le(c, a, ha)),
    Equal.trans(Nat, Nat.add(c, Nat.sub(a, c)), Nat.add(c, Nat.sub(b, c)), b,
      Equal.cong(Nat, Nat, x => Nat.add(c, x), Nat.sub(a, c), Nat.sub(b, c), e),
      MNat.add_sub_of_le(c, b, hb)))

def high_lt_half(+a: Nat, +half: Nat, lower: MNat.le(half, a), upper: MNat.lt(a, Nat.double(half))) -> MNat.lt(Nat.sub(a, half), half):
  MNat.lt_of_add_lt_add_left(half, Nat.sub(a, half), half,
    (%Equal.sym(Nat, Nat.add(half, Nat.sub(a, half)), a, MNat.add_sub_of_le(half, a, lower)) : MNat.lt(_, Nat.add(half, half))
     %MNat.double_eq_add(half) : MNat.lt(a, _)
     upper))

def zeros_shln(+depth: Nat) -> {size(zeros(depth)) == U32.shln(1, depth) : U32}:
  match depth:
    case 0n:
      {==}
    case 1n++p:
      Equal.cong(U32, U32, x => U32.shl(x), size(zeros(p)), U32.shln(1, p), zeros_shln(p))

def zeros_size_nat(+depth: Nat, hd: MNat.lt(depth, 32n)) -> {U32.to_nat(size(zeros(depth))) == Lemmas.pow2(depth) : Nat}:
  Equal.trans(Nat, U32.to_nat(size(zeros(depth))), U32.to_nat(U32.shln(1, depth)), Lemmas.pow2(depth),
    Equal.cong(U32, Nat, x => U32.to_nat(x), size(zeros(depth)), U32.shln(1, depth), zeros_shln(depth)),
    Field.shln_one_nat(depth, hd))

def double_div_two(+a: Nat) -> {Nat.div(Nat.double(a), 2n) == a : Nat}:
  %Equal.sym(Nat, Nat.double(a), Nat.mul(2n, a), MNat.double_eq_two_mul(a)) : {Nat.div(_, 2n) == a : Nat}
  MNat.mul_div_cancel_left(a, 1n)

def child_depth(+depth: Nat, hd: MNat.lt(1n+depth, 32n)) -> MNat.lt(depth, 32n):
  MNat.lt_trans(depth, 1n+depth, 32n, MNat.lt_succ_self(depth), hd)

def zeros_half(+depth: Nat, +hd: MNat.lt(1n+depth, 32n)) -> {U32.shr(size(zeros(1n+depth))) == size(zeros(depth)) : U32}:
  Lemmas.u32_to_nat_inj(U32.shr(size(zeros(1n+depth))), size(zeros(depth)),
    Equal.trans(Nat, U32.to_nat(U32.shr(size(zeros(1n+depth)))), Nat.div(U32.to_nat(size(zeros(1n+depth))), 2n), U32.to_nat(size(zeros(depth))),
      Field.shrn_nat(size(zeros(1n+depth)), 1n),
      Equal.trans(Nat, Nat.div(U32.to_nat(size(zeros(1n+depth))), 2n), Lemmas.pow2(depth), U32.to_nat(size(zeros(depth))),
        Equal.trans(Nat, Nat.div(U32.to_nat(size(zeros(1n+depth))), 2n), Nat.div(Lemmas.pow2(1n+depth), 2n), Lemmas.pow2(depth),
          Equal.cong(Nat, Nat, x => Nat.div(x, 2n), U32.to_nat(size(zeros(1n+depth))), Lemmas.pow2(1n+depth), zeros_size_nat(1n+depth, hd)),
          double_div_two(Lemmas.pow2(depth))),
        Equal.sym(Nat, U32.to_nat(size(zeros(depth))), Lemmas.pow2(depth), zeros_size_nat(depth, child_depth(depth, hd))))))

def in_range_mask(+depth: Nat, +i: U32, +hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth))) -> {U32.and(i, U32.sub(size(zeros(depth)), 1)) == i : U32}:
  +e = Lemmas.u32_to_from_nat(depth, MNat.lt_trans(depth, 32n, Lemmas.pow2(32n), hd, {==}))
  %Equal.sym(U32, size(zeros(depth)), U32.shln(1, depth), zeros_shln(depth)) : {U32.and(i, U32.sub(_, 1)) == i : U32}
  %e : {U32.and(i, U32.sub(U32.shln(1, _), 1)) == i : U32}
  Field.and_mask_small(i, U32.from_nat(depth),
    (%Equal.sym(Nat, U32.to_nat(U32.from_nat(depth)), depth, e) : MNat.le(_, 32n)
     MNat.le_of_lt(depth, 32n, hd)),
    (%Equal.sym(Nat, U32.to_nat(U32.from_nat(depth)), depth, e) : MNat.lt(U32.to_nat(i), Lemmas.pow2(_))
     hi))

def u32_lt_bound(+i: U32, +half: U32, h: {U32.is_lt(i, half) == True{} : Bool}) -> MNat.lt(U32.to_nat(i), U32.to_nat(half)):
  Equal.trans(Bool, Nat.is_lt(U32.to_nat(i), U32.to_nat(half)), U32.is_lt(i, half), True{}, Equal.sym(Bool, U32.is_lt(i, half), Nat.is_lt(U32.to_nat(i), U32.to_nat(half)), Lemmas.u32_is_lt_nat(i, half)), h)

def u32_ge_bound(+i: U32, +half: U32, h: {U32.is_lt(i, half) == False{} : Bool}) -> MNat.le(U32.to_nat(half), U32.to_nat(i)):
  MNat.le_of_not_lt(U32.to_nat(i), U32.to_nat(half), Equal.trans(Bool, Nat.is_lt(U32.to_nat(i), U32.to_nat(half)), U32.is_lt(i, half), False{}, Equal.sym(Bool, U32.is_lt(i, half), Nat.is_lt(U32.to_nat(i), U32.to_nat(half)), Lemmas.u32_is_lt_nat(i, half)), h))

def low_bound(+depth: Nat, +i: U32, +hd: MNat.lt(1n+depth, 32n), h: {U32.is_lt(i, U32.shr(size(zeros(1n+depth)))) == True{} : Bool}) -> MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)):
  %zeros_size_nat(depth, child_depth(depth, hd)) : MNat.lt(U32.to_nat(i), _)
  %zeros_half(depth, hd) : MNat.lt(U32.to_nat(i), U32.to_nat(_))
  u32_lt_bound(i, U32.shr(size(zeros(1n+depth))), h)

def high_lower(+depth: Nat, +i: U32, +hd: MNat.lt(1n+depth, 32n), h: {U32.is_lt(i, U32.shr(size(zeros(1n+depth)))) == False{} : Bool}) -> MNat.le(U32.to_nat(size(zeros(depth))), U32.to_nat(i)):
  %zeros_half(depth, hd) : MNat.le(U32.to_nat(_), U32.to_nat(i))
  u32_ge_bound(i, U32.shr(size(zeros(1n+depth))), h)

def high_bound(+depth: Nat, +i: U32, +hd: MNat.lt(1n+depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(1n+depth)), +h: {U32.is_lt(i, U32.shr(size(zeros(1n+depth)))) == False{} : Bool}) -> MNat.lt(U32.to_nat(U32.sub(i, size(zeros(depth)))), Lemmas.pow2(depth)):
  %Equal.sym(Nat, U32.to_nat(U32.sub(i, size(zeros(depth)))), Nat.sub(U32.to_nat(i), U32.to_nat(size(zeros(depth)))), Lemmas.u32_sub_nat(i, size(zeros(depth)), high_lower(depth, i, hd, h))) : MNat.lt(_, Lemmas.pow2(depth))
  %Equal.sym(Nat, U32.to_nat(size(zeros(depth))), Lemmas.pow2(depth), zeros_size_nat(depth, child_depth(depth, hd))) : MNat.lt(Nat.sub(U32.to_nat(i), _), Lemmas.pow2(depth))
  high_lt_half(U32.to_nat(i), Lemmas.pow2(depth),
    (%zeros_size_nat(depth, child_depth(depth, hd)) : MNat.le(_, U32.to_nat(i))
     high_lower(depth, i, hd, h)),
    hi)

def u32_sub_inj(+i: U32, +j: U32, +half: U32, +hi: MNat.le(U32.to_nat(half), U32.to_nat(i)), +hj: MNat.le(U32.to_nat(half), U32.to_nat(j)), e: {U32.sub(i, half) == U32.sub(j, half) : U32}) -> {i == j : U32}:
  Lemmas.u32_to_nat_inj(i, j,
    sub_inj(U32.to_nat(i), U32.to_nat(j), U32.to_nat(half), hi, hj,
      Equal.trans(Nat, Nat.sub(U32.to_nat(i), U32.to_nat(half)), U32.to_nat(U32.sub(i, half)), Nat.sub(U32.to_nat(j), U32.to_nat(half)),
        Equal.sym(Nat, U32.to_nat(U32.sub(i, half)), Nat.sub(U32.to_nat(i), U32.to_nat(half)), Lemmas.u32_sub_nat(i, half, hi)),
        Equal.trans(Nat, U32.to_nat(U32.sub(i, half)), U32.to_nat(U32.sub(j, half)), Nat.sub(U32.to_nat(j), U32.to_nat(half)),
          Equal.cong(U32, Nat, x => U32.to_nat(x), U32.sub(i, half), U32.sub(j, half), e),
          Lemmas.u32_sub_nat(j, half, hj)))))

def lt_one_zero(+a: Nat, h: MNat.lt(a, 1n)) -> {a == 0n : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      Empty.absurd({1n+p == 0n : Nat}, MNat.lt_zero(p)(h))

def zero_index(+i: U32, h: MNat.lt(U32.to_nat(i), 1n)) -> {i == 0 : U32}:
  Lemmas.u32_to_nat_inj(i, 0, lt_one_zero(U32.to_nat(i), h))

def separate_numeric(+depth: Nat, +i: U32, +j: U32, +zi: Bool, +zj: Bool, +hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), +ei: {U32.is_lt(i, U32.shr(size(zeros(depth)))) == zi : Bool}, +ej: {U32.is_lt(j, U32.shr(size(zeros(depth)))) == zj : Bool}, ne: {i != j : U32}) -> separate(depth, size(zeros(depth)), i, j, zi, zj):
  match depth zi zj:
    case 0n _ _:
      ne(Equal.trans(U32, i, 0, j, zero_index(i, hi), Equal.sym(U32, j, 0, zero_index(j, hj))))
    case 1n++p True{} True{}:
      %Equal.sym(U32, U32.shr(size(zeros(1n+p))), size(zeros(p)), zeros_half(p, hd)) : separate(p, _, i, j, U32.is_lt(i, U32.shr(_)), U32.is_lt(j, U32.shr(_)))
      separate_numeric(p, i, j, U32.is_lt(i, U32.shr(size(zeros(p)))), U32.is_lt(j, U32.shr(size(zeros(p)))), child_depth(p, hd), low_bound(p, i, hd, ei), low_bound(p, j, hd, ej), {==}, {==}, ne)
    case 1n+p True{} False{}:
      Unit{}
    case 1n+p False{} True{}:
      Unit{}
    case 1n++p False{} False{}:
      %Equal.sym(U32, U32.shr(size(zeros(1n+p))), size(zeros(p)), zeros_half(p, hd)) : separate(p, _, U32.sub(i, _), U32.sub(j, _), U32.is_lt(U32.sub(i, _), U32.shr(_)), U32.is_lt(U32.sub(j, _), U32.shr(_)))
      separate_numeric(p, U32.sub(i, size(zeros(p))), U32.sub(j, size(zeros(p))), U32.is_lt(U32.sub(i, size(zeros(p))), U32.shr(size(zeros(p)))), U32.is_lt(U32.sub(j, size(zeros(p))), U32.shr(size(zeros(p)))), child_depth(p, hd), high_bound(p, i, hd, hi, ei), high_bound(p, j, hd, hj, ej), {==}, {==},
        e => ne(u32_sub_inj(i, j, size(zeros(p)), high_lower(p, i, hd, ei), high_lower(p, j, hd, ej), e)))

def separate_in_range(+depth: Nat, +n: U32, +i: U32, +j: U32, +hd: MNat.lt(depth, 32n), +hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), +hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), ne: {U32.is_eq(i, j) == False{} : Bool}, en: {n == size(zeros(depth)) : U32}) -> separate(depth, n, U32.and(i, U32.sub(n, 1)), U32.and(j, U32.sub(n, 1)), U32.is_lt(U32.and(i, U32.sub(n, 1)), U32.shr(n)), U32.is_lt(U32.and(j, U32.sub(n, 1)), U32.shr(n))):
  %Equal.sym(U32, n, size(zeros(depth)), en) : separate(depth, _, U32.and(i, U32.sub(_, 1)), U32.and(j, U32.sub(_, 1)), U32.is_lt(U32.and(i, U32.sub(_, 1)), U32.shr(_)), U32.is_lt(U32.and(j, U32.sub(_, 1)), U32.shr(_)))
  %Equal.sym(U32, U32.and(i, U32.sub(size(zeros(depth)), 1)), i, in_range_mask(depth, i, hd, hi)) : separate(depth, size(zeros(depth)), _, U32.and(j, U32.sub(size(zeros(depth)), 1)), U32.is_lt(_, U32.shr(size(zeros(depth)))), U32.is_lt(U32.and(j, U32.sub(size(zeros(depth)), 1)), U32.shr(size(zeros(depth)))))
  %Equal.sym(U32, U32.and(j, U32.sub(size(zeros(depth)), 1)), j, in_range_mask(depth, j, hd, hj)) : separate(depth, size(zeros(depth)), i, _, U32.is_lt(i, U32.shr(size(zeros(depth)))), U32.is_lt(_, U32.shr(size(zeros(depth)))))
  separate_numeric(depth, i, j, U32.is_lt(i, U32.shr(size(zeros(depth)))), U32.is_lt(j, U32.shr(size(zeros(depth)))), hd, hi, hj, {==}, {==}, e => u32_ne(i, j, ne, e))

def frame.of(+depth: Nat, +t: Tree, +i: U32, +j: U32, +v: U32, hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), ne: {U32.is_eq(i, j) == False{} : Bool}, hs: shape(depth, t) & shape(depth, t)) -> {get(set(t, i, v), j) == get(t, j) : U32}:
  (ha, hb) = hs
  frame_separate(depth, t, i, j, v, ha, separate_in_range(depth, size(t), i, j, hd, hi, hj, ne, shape_size(depth, t, hb)))

def frame(+depth: Nat, +t: Tree, +i: U32, +j: U32, +v: U32, h: shape(depth, t), hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), ne: {U32.is_eq(i, j) == False{} : Bool}) -> {get(set(t, i, v), j) == get(t, j) : U32}:
  frame.of(depth, t, i, j, v, hd, hi, hj, ne, shape_copy(depth, t, h))

# Only words strictly after the selected word are constrained.
def zero_after.go(+depth: Nat, t: Tree, n: U32, +i: U32, z: Bool) -> Type:
  match depth t z:
    case 0n Leaf{v} _:
      Unit
    case 0n Node{xs, ys} _:
      Empty
    case 1n+p Leaf{v} _:
      Empty
    case 1n+p Node{xs, ys} True{}:
      +half = U32.shr(n)
      zero_after.go(p, xs, half, i, U32.is_lt(i, U32.shr(half))) & {ys == zeros(p) : Tree}
    case 1n+p Node{xs, ys} False{}:
      +half = U32.shr(n)
      +j = U32.sub(i, half)
      zero_after.go(p, ys, half, j, U32.is_lt(j, U32.shr(half)))

def zero_after(+depth: Nat, +t: Tree, +i: U32) -> Type:
  +n = size(t)
  +j = U32.and(i, U32.sub(n, 1))
  zero_after.go(depth, t, n, j, U32.is_lt(j, U32.shr(n)))

def zeros_zero_after_go(+depth: Nat, +n: U32, +i: U32, +z: Bool) -> zero_after.go(depth, zeros(depth), n, i, z):
  match depth z:
    case 0n _:
      Unit{}
    case 1n++p True{}:
      (zeros_zero_after_go(p, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n)))), {==})
    case 1n++p False{}:
      zeros_zero_after_go(p, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))

def zeros_zero_after(+depth: Nat, +i: U32) -> zero_after(depth, zeros(depth), i):
  zeros_zero_after_go(depth, size(zeros(depth)), U32.and(i, U32.sub(size(zeros(depth)), 1)), U32.is_lt(U32.and(i, U32.sub(size(zeros(depth)), 1)), U32.shr(size(zeros(depth)))))

def zero_after_set_go(+depth: Nat, +t: Tree, +n: U32, +i: U32, +v: U32, +z: Bool, h: zero_after.go(depth, t, n, i, z)) -> zero_after.go(depth, set.go(t, n, i, v, z), n, i, z):
  match depth t z:
    case 0n Leaf{x} _:
      Unit{}
    case 0n Node{xs, ys} _:
      match h:
    case 1n+p Leaf{x} _:
      match h:
    case 1n++p Node{+xs, +ys} True{}:
      (hl, hr) = h
      (zero_after_set_go(p, xs, U32.shr(n), i, v, U32.is_lt(i, U32.shr(U32.shr(n))), hl), hr)
    case 1n++p Node{+xs, +ys} False{}:
      zero_after_set_go(p, ys, U32.shr(n), U32.sub(i, U32.shr(n)), v, U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), h)

def zero_after_set(+depth: Nat, +t: Tree, +i: U32, +v: U32, h: zero_after(depth, t, i)) -> zero_after(depth, set(t, i, v), i):
  %Equal.sym(U32, size(set(t, i, v)), size(t), set_size(t, i, v)) : zero_after.go(depth, set(t, i, v), _, U32.and(i, U32.sub(_, 1)), U32.is_lt(U32.and(i, U32.sub(_, 1)), U32.shr(_)))
  zero_after_set_go(depth, t, size(t), U32.and(i, U32.sub(size(t), 1)), v, U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))), h)

def set_current_go(+t: Tree, +n: U32, +i: U32, +z: Bool) -> {set.go(t, n, i, get.go(t, n, i, z), z) == t : Tree}:
  match t z:
    case Leaf{v} _:
      {==}
    case Node{+xs, +ys} True{}:
      Equal.cong(Tree, Tree, x => Node{x, ys}, set.go(xs, U32.shr(n), i, get.go(xs, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n)))), U32.is_lt(i, U32.shr(U32.shr(n)))), xs, set_current_go(xs, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n)))))
    case Node{+xs, +ys} False{}:
      Equal.cong(Tree, Tree, y => Node{xs, y}, set.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), get.go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n)))), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n)))), ys, set_current_go(ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n)))))

def set_current(+t: Tree, +i: U32) -> {set(t, i, get(t, i)) == t : Tree}:
  set_current_go(t, size(t), U32.and(i, U32.sub(size(t), 1)), U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))))

def follows(+depth: Nat, n: U32, +i: U32, +j: U32, zi: Bool, zj: Bool) -> Type:
  match depth zi zj:
    case 0n _ _:
      Empty
    case 1n+p True{} True{}:
      +half = U32.shr(n)
      follows(p, half, i, j, U32.is_lt(i, U32.shr(half)), U32.is_lt(j, U32.shr(half)))
    case 1n+p True{} False{}:
      Unit
    case 1n+p False{} True{}:
      Empty
    case 1n+p False{} False{}:
      +half = U32.shr(n)
      +ii = U32.sub(i, half)
      +jj = U32.sub(j, half)
      follows(p, half, ii, jj, U32.is_lt(ii, U32.shr(half)), U32.is_lt(jj, U32.shr(half)))

def get_after_zero_go(+depth: Nat, +t: Tree, +n: U32, +i: U32, +j: U32, +zi: Bool, +zj: Bool, h: zero_after.go(depth, t, n, i, zi), later: follows(depth, n, i, j, zi, zj)) -> {get.go(t, n, j, zj) == 0 : U32}:
  match depth t zi zj:
    case 0n Leaf{x} _ _:
      match later:
    case 0n Node{xs, ys} _ _:
      match h:
    case 1n+p Leaf{x} _ _:
      match h:
    case 1n++p Node{+xs, +ys} True{} True{}:
      (hl, hr) = h
      get_after_zero_go(p, xs, U32.shr(n), i, j, U32.is_lt(i, U32.shr(U32.shr(n))), U32.is_lt(j, U32.shr(U32.shr(n))), hl, later)
    case 1n++p Node{+xs, +ys} True{} False{}:
      (hl, hr) = h
      %Equal.sym(Tree, ys, zeros(p), hr) : {get.go(_, U32.shr(n), U32.sub(j, U32.shr(n)), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n)))) == 0 : U32}
      zeros_get_go(p, U32.shr(n), U32.sub(j, U32.shr(n)), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))))
    case 1n+p Node{xs, ys} False{} True{}:
      match later:
    case 1n++p Node{+xs, +ys} False{} False{}:
      get_after_zero_go(p, ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.sub(j, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))), h, later)

def zero_after_advance_go(+depth: Nat, +t: Tree, +n: U32, +i: U32, +j: U32, +zi: Bool, +zj: Bool, h: zero_after.go(depth, t, n, i, zi), later: follows(depth, n, i, j, zi, zj)) -> zero_after.go(depth, t, n, j, zj):
  match depth t zi zj:
    case 0n Leaf{x} _ _:
      match later:
    case 0n Node{xs, ys} _ _:
      match h:
    case 1n+p Leaf{x} _ _:
      match h:
    case 1n++p Node{+xs, +ys} True{} True{}:
      (hl, hr) = h
      (zero_after_advance_go(p, xs, U32.shr(n), i, j, U32.is_lt(i, U32.shr(U32.shr(n))), U32.is_lt(j, U32.shr(U32.shr(n))), hl, later), hr)
    case 1n++p Node{+xs, +ys} True{} False{}:
      (hl, hr) = h
      %Equal.sym(Tree, ys, zeros(p), hr) : zero_after.go(p, _, U32.shr(n), U32.sub(j, U32.shr(n)), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))))
      zeros_zero_after_go(p, U32.shr(n), U32.sub(j, U32.shr(n)), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))))
    case 1n+p Node{xs, ys} False{} True{}:
      match later:
    case 1n++p Node{+xs, +ys} False{} False{}:
      zero_after_advance_go(p, ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.sub(j, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))), U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))), h, later)

def sub_lt_sub(+a: Nat, +b: Nat, +c: Nat, ha: MNat.le(c, a), hb: MNat.le(c, b), h: MNat.lt(a, b)) -> MNat.lt(Nat.sub(a, c), Nat.sub(b, c)):
  MNat.lt_of_add_lt_add_left(c, Nat.sub(a, c), Nat.sub(b, c),
    (%Equal.sym(Nat, Nat.add(c, Nat.sub(a, c)), a, MNat.add_sub_of_le(c, a, ha)) : MNat.lt(_, Nat.add(c, Nat.sub(b, c)))
     %Equal.sym(Nat, Nat.add(c, Nat.sub(b, c)), b, MNat.add_sub_of_le(c, b, hb)) : MNat.lt(a, _)
     h))

def high_order(+depth: Nat, +i: U32, +j: U32, +hd: MNat.lt(1n+depth, 32n), ei: {U32.is_lt(i, U32.shr(size(zeros(1n+depth)))) == False{} : Bool}, ej: {U32.is_lt(j, U32.shr(size(zeros(1n+depth)))) == False{} : Bool}, h: MNat.lt(U32.to_nat(i), U32.to_nat(j))) -> MNat.lt(U32.to_nat(U32.sub(i, size(zeros(depth)))), U32.to_nat(U32.sub(j, size(zeros(depth))))):
  +li = high_lower(depth, i, hd, ei)
  +lj = high_lower(depth, j, hd, ej)
  %Equal.sym(Nat, U32.to_nat(U32.sub(i, size(zeros(depth)))), Nat.sub(U32.to_nat(i), U32.to_nat(size(zeros(depth)))), Lemmas.u32_sub_nat(i, size(zeros(depth)), li)) : MNat.lt(_, U32.to_nat(U32.sub(j, size(zeros(depth)))))
  %Equal.sym(Nat, U32.to_nat(U32.sub(j, size(zeros(depth)))), Nat.sub(U32.to_nat(j), U32.to_nat(size(zeros(depth)))), Lemmas.u32_sub_nat(j, size(zeros(depth)), lj)) : MNat.lt(Nat.sub(U32.to_nat(i), U32.to_nat(size(zeros(depth)))), _)
  sub_lt_sub(U32.to_nat(i), U32.to_nat(j), U32.to_nat(size(zeros(depth))), li, lj, h)

def nat_lt_ne(+a: Nat, +b: Nat, h: MNat.lt(a, b), e: {a == b : Nat}) -> Empty:
  MNat.lt_irrefl(a)(
    (%Equal.sym(Nat, a, b, e) : MNat.lt(a, _)
     h))

def follows_numeric(+depth: Nat, +i: U32, +j: U32, +zi: Bool, +zj: Bool, +hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), +ei: {U32.is_lt(i, U32.shr(size(zeros(depth)))) == zi : Bool}, +ej: {U32.is_lt(j, U32.shr(size(zeros(depth)))) == zj : Bool}, hij: MNat.lt(U32.to_nat(i), U32.to_nat(j))) -> follows(depth, size(zeros(depth)), i, j, zi, zj):
  match depth zi zj:
    case 0n _ _:
      nat_lt_ne(U32.to_nat(i), U32.to_nat(j), hij, Equal.trans(Nat, U32.to_nat(i), 0n, U32.to_nat(j), lt_one_zero(U32.to_nat(i), hi), Equal.sym(Nat, U32.to_nat(j), 0n, lt_one_zero(U32.to_nat(j), hj))))
    case 1n++p True{} True{}:
      %Equal.sym(U32, U32.shr(size(zeros(1n+p))), size(zeros(p)), zeros_half(p, hd)) : follows(p, _, i, j, U32.is_lt(i, U32.shr(_)), U32.is_lt(j, U32.shr(_)))
      follows_numeric(p, i, j, U32.is_lt(i, U32.shr(size(zeros(p)))), U32.is_lt(j, U32.shr(size(zeros(p)))), child_depth(p, hd), low_bound(p, i, hd, ei), low_bound(p, j, hd, ej), {==}, {==}, hij)
    case 1n+p True{} False{}:
      Unit{}
    case 1n++p False{} True{}:
      MNat.lt_irrefl(Lemmas.pow2(p))(
        MNat.lt_of_le_of_lt(Lemmas.pow2(p), U32.to_nat(i), Lemmas.pow2(p),
          (%zeros_size_nat(p, child_depth(p, hd)) : MNat.le(_, U32.to_nat(i))
           high_lower(p, i, hd, ei)),
          MNat.lt_trans(U32.to_nat(i), U32.to_nat(j), Lemmas.pow2(p), hij, low_bound(p, j, hd, ej))))
    case 1n++p False{} False{}:
      %Equal.sym(U32, U32.shr(size(zeros(1n+p))), size(zeros(p)), zeros_half(p, hd)) : follows(p, _, U32.sub(i, _), U32.sub(j, _), U32.is_lt(U32.sub(i, _), U32.shr(_)), U32.is_lt(U32.sub(j, _), U32.shr(_)))
      follows_numeric(p, U32.sub(i, size(zeros(p))), U32.sub(j, size(zeros(p))), U32.is_lt(U32.sub(i, size(zeros(p))), U32.shr(size(zeros(p)))), U32.is_lt(U32.sub(j, size(zeros(p))), U32.shr(size(zeros(p)))), child_depth(p, hd), high_bound(p, i, hd, hi, ei), high_bound(p, j, hd, hj, ej), {==}, {==}, high_order(p, i, j, hd, ei, ej, hij))

def follows_in_range(+depth: Nat, +n: U32, +i: U32, +j: U32, +hd: MNat.lt(depth, 32n), +hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), +hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), hij: MNat.lt(U32.to_nat(i), U32.to_nat(j)), en: {n == size(zeros(depth)) : U32}) -> follows(depth, n, U32.and(i, U32.sub(n, 1)), U32.and(j, U32.sub(n, 1)), U32.is_lt(U32.and(i, U32.sub(n, 1)), U32.shr(n)), U32.is_lt(U32.and(j, U32.sub(n, 1)), U32.shr(n))):
  %Equal.sym(U32, n, size(zeros(depth)), en) : follows(depth, _, U32.and(i, U32.sub(_, 1)), U32.and(j, U32.sub(_, 1)), U32.is_lt(U32.and(i, U32.sub(_, 1)), U32.shr(_)), U32.is_lt(U32.and(j, U32.sub(_, 1)), U32.shr(_)))
  %Equal.sym(U32, U32.and(i, U32.sub(size(zeros(depth)), 1)), i, in_range_mask(depth, i, hd, hi)) : follows(depth, size(zeros(depth)), _, U32.and(j, U32.sub(size(zeros(depth)), 1)), U32.is_lt(_, U32.shr(size(zeros(depth)))), U32.is_lt(U32.and(j, U32.sub(size(zeros(depth)), 1)), U32.shr(size(zeros(depth)))))
  %Equal.sym(U32, U32.and(j, U32.sub(size(zeros(depth)), 1)), j, in_range_mask(depth, j, hd, hj)) : follows(depth, size(zeros(depth)), i, _, U32.is_lt(i, U32.shr(size(zeros(depth)))), U32.is_lt(_, U32.shr(size(zeros(depth)))))
  follows_numeric(depth, i, j, U32.is_lt(i, U32.shr(size(zeros(depth)))), U32.is_lt(j, U32.shr(size(zeros(depth)))), hd, hi, hj, {==}, {==}, hij)

def get_after_zero(+depth: Nat, +t: Tree, +i: U32, +j: U32, sh: shape(depth, t), h: zero_after(depth, t, i), hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), hij: MNat.lt(U32.to_nat(i), U32.to_nat(j))) -> {get(t, j) == 0 : U32}:
  get_after_zero_go(depth, t, size(t), U32.and(i, U32.sub(size(t), 1)), U32.and(j, U32.sub(size(t), 1)), U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))), U32.is_lt(U32.and(j, U32.sub(size(t), 1)), U32.shr(size(t))), h, follows_in_range(depth, size(t), i, j, hd, hi, hj, hij, shape_size(depth, t, sh)))

def zero_after_advance(+depth: Nat, +t: Tree, +i: U32, +j: U32, sh: shape(depth, t), h: zero_after(depth, t, i), hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), hij: MNat.lt(U32.to_nat(i), U32.to_nat(j))) -> zero_after(depth, t, j):
  zero_after_advance_go(depth, t, size(t), U32.and(i, U32.sub(size(t), 1)), U32.and(j, U32.sub(size(t), 1)), U32.is_lt(U32.and(i, U32.sub(size(t), 1)), U32.shr(size(t))), U32.is_lt(U32.and(j, U32.sub(size(t), 1)), U32.shr(size(t))), h, follows_in_range(depth, size(t), i, j, hd, hi, hj, hij, shape_size(depth, t, sh)))

def zero_after_set_later(+depth: Nat, +t: Tree, +i: U32, +j: U32, +v: U32, sh: shape(depth, t), h: zero_after(depth, t, i), hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(j), Lemmas.pow2(depth)), hij: MNat.lt(U32.to_nat(i), U32.to_nat(j))) -> zero_after(depth, set(t, j, v), j):
  zero_after_set(depth, t, j, v, zero_after_advance(depth, t, i, j, sh, h, hd, hi, hj, hij))

def next_index_lt(+depth: Nat, +i: U32, hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth))) -> MNat.lt(U32.to_nat(i), U32.to_nat(U32.add(i, 1))):
  +hs = Equal.trans(Bool, Nat.is_le(1n+U32.to_nat(i), Lemmas.pow2(depth)), Nat.is_lt(U32.to_nat(i), Lemmas.pow2(depth)), True{},
    Equal.sym(Bool, Nat.is_lt(U32.to_nat(i), Lemmas.pow2(depth)), Nat.is_le(1n+U32.to_nat(i), Lemmas.pow2(depth)), MNat.is_lt_eq_succ_le(U32.to_nat(i), Lemmas.pow2(depth))), hi)
  +hb = MNat.lt_of_le_of_lt(1n+U32.to_nat(i), Lemmas.pow2(depth), Lemmas.pow2(32n), hs, Field.pow2_lt(depth, 32n, hd))
  +e = Lemmas.u32_add_nat(i, 1,
    Lemmas.lt_rw(Nat.add(U32.to_nat(i), U32.to_nat(1)), 1n+U32.to_nat(i), Lemmas.pow2(32n), MNat.add_comm(U32.to_nat(i), 1n), hb))
  %Equal.sym(Nat, U32.to_nat(U32.add(i, 1)), Nat.add(U32.to_nat(i), 1n), e) : MNat.lt(U32.to_nat(i), _)
  %Equal.sym(Nat, Nat.add(U32.to_nat(i), 1n), 1n+U32.to_nat(i), MNat.add_comm(U32.to_nat(i), 1n)) : MNat.lt(U32.to_nat(i), _)
  MNat.lt_succ_self(U32.to_nat(i))

def zero_after_next(+depth: Nat, +t: Tree, +i: U32, sh: shape(depth, t), h: zero_after(depth, t, i), +hd: MNat.lt(depth, 32n), +hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(U32.add(i, 1)), Lemmas.pow2(depth))) -> zero_after(depth, t, U32.add(i, 1)):
  zero_after_advance(depth, t, i, U32.add(i, 1), sh, h, hd, hi, hj, next_index_lt(depth, i, hd, hi))

def zero_after_set_next(+depth: Nat, +t: Tree, +i: U32, +v: U32, sh: shape(depth, t), h: zero_after(depth, t, i), +hd: MNat.lt(depth, 32n), +hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), hj: MNat.lt(U32.to_nat(U32.add(i, 1)), Lemmas.pow2(depth))) -> zero_after(depth, set(t, U32.add(i, 1), v), U32.add(i, 1)):
  zero_after_set(depth, t, U32.add(i, 1), v, zero_after_next(depth, t, i, sh, h, hd, hi, hj))

def zero_after_normalize(+depth: Nat, +t: Tree, +i: U32, +hd: MNat.lt(depth, 32n), +hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), en: {size(t) == size(zeros(depth)) : U32}, h: zero_after(depth, t, i)) -> zero_after.go(depth, t, size(zeros(depth)), i, U32.is_lt(i, U32.shr(size(zeros(depth))))):
  %in_range_mask(depth, i, hd, hi) : zero_after.go(depth, t, size(zeros(depth)), _, U32.is_lt(_, U32.shr(size(zeros(depth)))))
  %en : zero_after.go(depth, t, _, U32.and(i, U32.sub(_, 1)), U32.is_lt(U32.and(i, U32.sub(_, 1)), U32.shr(_)))
  h

def zero_after_denormalize(+depth: Nat, +t: Tree, +i: U32, +hd: MNat.lt(depth, 32n), +hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), en: {size(t) == size(zeros(depth)) : U32}, h: zero_after.go(depth, t, size(zeros(depth)), i, U32.is_lt(i, U32.shr(size(zeros(depth)))))) -> zero_after(depth, t, i):
  %Equal.sym(U32, size(t), size(zeros(depth)), en) : zero_after.go(depth, t, _, U32.and(i, U32.sub(_, 1)), U32.is_lt(U32.and(i, U32.sub(_, 1)), U32.shr(_)))
  %Equal.sym(U32, U32.and(i, U32.sub(size(zeros(depth)), 1)), i, in_range_mask(depth, i, hd, hi)) : zero_after.go(depth, t, size(zeros(depth)), _, U32.is_lt(_, U32.shr(size(zeros(depth)))))
  h

def below_size(+depth: Nat, +i: U32, hd: MNat.lt(depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth))) -> {U32.is_lt(i, size(zeros(depth))) == True{} : Bool}:
  Equal.trans(Bool, U32.is_lt(i, size(zeros(depth))), Nat.is_lt(U32.to_nat(i), U32.to_nat(size(zeros(depth)))), True{}, Lemmas.u32_is_lt_nat(i, size(zeros(depth))),
    (%Equal.sym(Nat, U32.to_nat(size(zeros(depth))), Lemmas.pow2(depth), zeros_size_nat(depth, hd)) : MNat.lt(U32.to_nat(i), _)
     hi))

def zero_after_grow_root(+depth: Nat, +t: Tree, +i: U32, +hd: MNat.lt(1n+depth, 32n), hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth)), h: zero_after.go(depth, t, size(zeros(depth)), i, U32.is_lt(i, U32.shr(size(zeros(depth)))))) -> zero_after.go(1n+depth, grow(t, depth), size(zeros(1n+depth)), i, U32.is_lt(i, U32.shr(size(zeros(1n+depth))))):
  +e = Equal.trans(Bool, U32.is_lt(i, U32.shr(size(zeros(1n+depth)))), U32.is_lt(i, size(zeros(depth))), True{},
    Equal.cong(U32, Bool, x => U32.is_lt(i, x), U32.shr(size(zeros(1n+depth))), size(zeros(depth)), zeros_half(depth, hd)), below_size(depth, i, child_depth(depth, hd), hi))
  %Equal.sym(Bool, U32.is_lt(i, U32.shr(size(zeros(1n+depth)))), True{}, e) : zero_after.go(1n+depth, grow(t, depth), size(zeros(1n+depth)), i, _)
  ((%Equal.sym(U32, U32.shr(size(zeros(1n+depth))), size(zeros(depth)), zeros_half(depth, hd)) : zero_after.go(depth, t, _, i, U32.is_lt(i, U32.shr(_)))
    h), {==})

def zero_after_grow(+depth: Nat, +t: Tree, +i: U32, sh: shape(depth, t), h: zero_after(depth, t, i), +hd: MNat.lt(1n+depth, 32n), +hi: MNat.lt(U32.to_nat(i), Lemmas.pow2(depth))) -> zero_after(1n+depth, grow(t, depth), i):
  +en = shape_size(depth, t, sh)
  zero_after_denormalize(1n+depth, grow(t, depth), i, hd,
    MNat.lt_trans(U32.to_nat(i), Lemmas.pow2(depth), Lemmas.pow2(1n+depth), hi, Field.pow2_lt(depth, 1n+depth, MNat.lt_succ_self(depth))),
    Equal.cong(U32, U32, x => U32.shl(x), size(t), size(zeros(depth)), en),
    zero_after_grow_root(depth, t, i, hd, hi, zero_after_normalize(depth, t, i, child_depth(depth, hd), hi, en, h)))
