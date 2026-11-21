# Array get after set. Adapted from https://github.com/nuxyel/bend-ml/blob/devel/docs/upstream/array_set_laws.bend
import Base

def sz(-T: Data, a: Array<T>) -> U32:
  Pair.snd(Array<T>, U32, Array.size(T, a))

def G(-T: Data, a: Array<T>, +n: U32, +j: U32, +v: T, +z: Bool) -> Array<T> & T:
  Array.swap.go(T, a, n, j, v, z)

def NA(-T: Data, a: Array<T>, +n: U32, +j: U32, +v: T, +z: Bool) -> Array<T>:
  Array.set.fin(T, G(T, a, n, j, v, z))

def K(-T: Data, a: Array<T>, +n: U32, +j: U32, +v: T, +z: Bool) -> Array<T> & T:
  Array.get.go(T, NA(T, a, n, j, v, z), n, j, z)

def Facts(-T: Data, -a: Array<T>, -n: U32, -j: U32, -v: T, -z: Bool) -> Type:
  {(a, sz(T, a)) == Array.size(T, a) : Array<T> & U32} & {(NA(T, a, n, j, v, z), Pair.snd(Array<T>, T, G(T, a, n, j, v, z))) == G(T, a, n, j, v, z) : Array<T> & T} & {(NA(T, a, n, j, v, z), sz(T, NA(T, a, n, j, v, z))) == Array.size(T, NA(T, a, n, j, v, z)) : Array<T> & U32} & {sz(T, NA(T, a, n, j, v, z)) == sz(T, a) : U32} & {Pair.snd(Array<T>, T, K(T, a, n, j, v, z)) == v : T} & {(Pair.fst(Array<T>, T, K(T, a, n, j, v, z)), Pair.snd(Array<T>, T, K(T, a, n, j, v, z))) == K(T, a, n, j, v, z) : Array<T> & T} & Unit

def size_pair(-T: Data, a: Array<T>) -> {(a, sz(T, a)) == Array.size(T, a) : Array<T> & U32}:
  match a:
    case ALeaf{x}:
      {==}
    case ANode{xs, ys}:
      %size_pair(T, xs) : {(ANode{xs, ys}, Pair.snd(Array<T>, U32, Array.size.node(T, ys, _))) == Array.size.node(T, ys, _) : Array<T> & U32}
      {==}

def node_t(-T: Data, -xs: Array<T>, -ys: Array<T>, +n: U32, +j: U32, +v: T, f: Facts(T, xs, U32.shr(n), j, v, U32.is_lt(j, U32.shr(U32.shr(n))))) -> Facts(T, ANode{xs, ys}, n, j, v, True{}):
  match f:
    case Tuple{+c1, r1}:
      match r1:
        case Tuple{+c2, r2}:
          match r2:
            case Tuple{+c3, r3}:
              match r3:
                case Tuple{+c4, r4}:
                  match r4:
                    case Tuple{+c5, r5}:
                      match r5:
                        case Tuple{+c6, u}:
                          ({(%c1 : {(ANode{xs, ys}, Pair.snd(Array<T>, U32, Array.size.node(T, ys, _))) == Array.size.node(T, ys, _) : Array<T> & U32}; {==}) : {(ANode{xs, ys}, sz(T, ANode{xs, ys})) == Array.size(T, ANode{xs, ys}) : Array<T> & U32}}, {(%c2 : {(Array.set.fin(T, Array.swap.lo(T, ys, _)), Pair.snd(Array<T>, T, Array.swap.lo(T, ys, _))) == Array.swap.lo(T, ys, _) : Array<T> & T}; {==}) : {(NA(T, ANode{xs, ys}, n, j, v, True{}), Pair.snd(Array<T>, T, G(T, ANode{xs, ys}, n, j, v, True{}))) == G(T, ANode{xs, ys}, n, j, v, True{}) : Array<T> & T}}, {(%c2 : {(Array.set.fin(T, Array.swap.lo(T, ys, _)), sz(T, Array.set.fin(T, Array.swap.lo(T, ys, _)))) == Array.size(T, Array.set.fin(T, Array.swap.lo(T, ys, _))) : Array<T> & U32}; %c3 : {(ANode{Array.set.fin(T, G(T, xs, U32.shr(n), j, v, U32.is_lt(j, U32.shr(U32.shr(n))))), ys}, Pair.snd(Array<T>, U32, Array.size.node(T, ys, _))) == Array.size.node(T, ys, _) : Array<T> & U32}; {==}) : {(NA(T, ANode{xs, ys}, n, j, v, True{}), sz(T, NA(T, ANode{xs, ys}, n, j, v, True{}))) == Array.size(T, NA(T, ANode{xs, ys}, n, j, v, True{})) : Array<T> & U32}}, {(%c2 : {sz(T, Array.set.fin(T, Array.swap.lo(T, ys, _))) == sz(T, ANode{xs, ys}) : U32}; %c3 : {Pair.snd(Array<T>, U32, Array.size.node(T, ys, _)) == sz(T, ANode{xs, ys}) : U32}; %c1 : {U32.shl(sz(T, Array.set.fin(T, G(T, xs, U32.shr(n), j, v, U32.is_lt(j, U32.shr(U32.shr(n))))))) == Pair.snd(Array<T>, U32, Array.size.node(T, ys, _)) : U32}; %c4 : {U32.shl(sz(T, Array.set.fin(T, G(T, xs, U32.shr(n), j, v, U32.is_lt(j, U32.shr(U32.shr(n))))))) == U32.shl(_) : U32}; {==}) : {sz(T, NA(T, ANode{xs, ys}, n, j, v, True{})) == sz(T, ANode{xs, ys}) : U32}}, {(%c2 : {Pair.snd(Array<T>, T, Array.get.go(T, Array.set.fin(T, Array.swap.lo(T, ys, _)), n, j, True{})) == v : T}; %c6 : {Pair.snd(Array<T>, T, Array.swap.lo(T, ys, _)) == v : T}; c5) : {Pair.snd(Array<T>, T, K(T, ANode{xs, ys}, n, j, v, True{})) == v : T}}, {(%c2 : {(Pair.fst(Array<T>, T, Array.get.go(T, Array.set.fin(T, Array.swap.lo(T, ys, _)), n, j, True{})), Pair.snd(Array<T>, T, Array.get.go(T, Array.set.fin(T, Array.swap.lo(T, ys, _)), n, j, True{}))) == Array.get.go(T, Array.set.fin(T, Array.swap.lo(T, ys, _)), n, j, True{}) : Array<T> & T}; %c6 : {(Pair.fst(Array<T>, T, Array.swap.lo(T, ys, _)), Pair.snd(Array<T>, T, Array.swap.lo(T, ys, _))) == Array.swap.lo(T, ys, _) : Array<T> & T}; {==}) : {(Pair.fst(Array<T>, T, K(T, ANode{xs, ys}, n, j, v, True{})), Pair.snd(Array<T>, T, K(T, ANode{xs, ys}, n, j, v, True{}))) == K(T, ANode{xs, ys}, n, j, v, True{}) : Array<T> & T}}, Unit{})

def node_f(-T: Data, -xs: Array<T>, -ys: Array<T>, +n: U32, +j: U32, +v: T, +s: {(xs, sz(T, xs)) == Array.size(T, xs) : Array<T> & U32}, f: Facts(T, ys, U32.shr(n), U32.sub(j, U32.shr(n)), v, U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))))) -> Facts(T, ANode{xs, ys}, n, j, v, False{}):
  match f:
    case Tuple{+c1, r1}:
      match r1:
        case Tuple{+c2, r2}:
          match r2:
            case Tuple{+c3, r3}:
              match r3:
                case Tuple{+c4, r4}:
                  match r4:
                    case Tuple{+c5, r5}:
                      match r5:
                        case Tuple{+c6, u}:
                          ({(%s : {(ANode{xs, ys}, Pair.snd(Array<T>, U32, Array.size.node(T, ys, _))) == Array.size.node(T, ys, _) : Array<T> & U32}; {==}) : {(ANode{xs, ys}, sz(T, ANode{xs, ys})) == Array.size(T, ANode{xs, ys}) : Array<T> & U32}}, {(%c2 : {(Array.set.fin(T, Array.swap.hi(T, xs, _)), Pair.snd(Array<T>, T, Array.swap.hi(T, xs, _))) == Array.swap.hi(T, xs, _) : Array<T> & T}; {==}) : {(NA(T, ANode{xs, ys}, n, j, v, False{}), Pair.snd(Array<T>, T, G(T, ANode{xs, ys}, n, j, v, False{}))) == G(T, ANode{xs, ys}, n, j, v, False{}) : Array<T> & T}}, {(%c2 : {(Array.set.fin(T, Array.swap.hi(T, xs, _)), sz(T, Array.set.fin(T, Array.swap.hi(T, xs, _)))) == Array.size(T, Array.set.fin(T, Array.swap.hi(T, xs, _))) : Array<T> & U32}; %s : {(ANode{xs, Array.set.fin(T, G(T, ys, U32.shr(n), U32.sub(j, U32.shr(n)), v, U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n)))))}, Pair.snd(Array<T>, U32, Array.size.node(T, Array.set.fin(T, G(T, ys, U32.shr(n), U32.sub(j, U32.shr(n)), v, U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))))), _))) == Array.size.node(T, Array.set.fin(T, G(T, ys, U32.shr(n), U32.sub(j, U32.shr(n)), v, U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))))), _) : Array<T> & U32}; {==}) : {(NA(T, ANode{xs, ys}, n, j, v, False{}), sz(T, NA(T, ANode{xs, ys}, n, j, v, False{}))) == Array.size(T, NA(T, ANode{xs, ys}, n, j, v, False{})) : Array<T> & U32}}, {(%c2 : {sz(T, Array.set.fin(T, Array.swap.hi(T, xs, _))) == sz(T, ANode{xs, ys}) : U32}; %s : {Pair.snd(Array<T>, U32, Array.size.node(T, Array.set.fin(T, G(T, ys, U32.shr(n), U32.sub(j, U32.shr(n)), v, U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n))))), _)) == Pair.snd(Array<T>, U32, Array.size.node(T, ys, _)) : U32}; {==}) : {sz(T, NA(T, ANode{xs, ys}, n, j, v, False{})) == sz(T, ANode{xs, ys}) : U32}}, {(%c2 : {Pair.snd(Array<T>, T, Array.get.go(T, Array.set.fin(T, Array.swap.hi(T, xs, _)), n, j, False{})) == v : T}; %c6 : {Pair.snd(Array<T>, T, Array.swap.hi(T, xs, _)) == v : T}; c5) : {Pair.snd(Array<T>, T, K(T, ANode{xs, ys}, n, j, v, False{})) == v : T}}, {(%c2 : {(Pair.fst(Array<T>, T, Array.get.go(T, Array.set.fin(T, Array.swap.hi(T, xs, _)), n, j, False{})), Pair.snd(Array<T>, T, Array.get.go(T, Array.set.fin(T, Array.swap.hi(T, xs, _)), n, j, False{}))) == Array.get.go(T, Array.set.fin(T, Array.swap.hi(T, xs, _)), n, j, False{}) : Array<T> & T}; %c6 : {(Pair.fst(Array<T>, T, Array.swap.hi(T, xs, _)), Pair.snd(Array<T>, T, Array.swap.hi(T, xs, _))) == Array.swap.hi(T, xs, _) : Array<T> & T}; {==}) : {(Pair.fst(Array<T>, T, K(T, ANode{xs, ys}, n, j, v, False{})), Pair.snd(Array<T>, T, K(T, ANode{xs, ys}, n, j, v, False{}))) == K(T, ANode{xs, ys}, n, j, v, False{}) : Array<T> & T}}, Unit{})

def facts(-T: Data, a: Array<T>, +n: U32, +j: U32, +v: T, +z: Bool) -> Facts(T, a, n, j, v, z):
  match a z:
    case ALeaf{x} _:
      ({==}, {==}, {==}, {==}, {==}, {==}, Unit{})
    case ANode{xs, ys} True{}:
      node_t(T, xs, ys, n, j, v, facts(T, xs, U32.shr(n), j, v, U32.is_lt(j, U32.shr(U32.shr(n)))))
    case ANode{xs, ys} False{}:
      node_f(T, xs, ys, n, j, v, size_pair(T, xs), facts(T, ys, U32.shr(n), U32.sub(j, U32.shr(n)), v, U32.is_lt(U32.sub(j, U32.shr(n)), U32.shr(U32.shr(n)))))

def Copy(-T: Data, -a: Array<T>) -> Type:
  &b: Array<T> -> &n: U32 -> {b == a : Array<T>} & {n == sz(T, b) : U32} & {(b, sz(T, b)) == Array.size(T, b) : Array<T> & U32} & Unit

def copy_node(-T: Data, -xs: Array<T>, ys: Array<T>, r: Copy(T, xs)) -> Copy(T, ANode{xs, ys}):
  match r:
    case Tuple{b, r1}:
      match r1:
        case Tuple{+m, r2}:
          match r2:
            case Tuple{+p, r3}:
              match r3:
                case Tuple{+q, r4}:
                  match r4:
                    case Tuple{+s, u}:
                      (ANode{b, ys}, U32.shl(m),
                        {(%p : {ANode{b, ys} == ANode{_, ys} : Array<T>}; {==}) : {ANode{b, ys} == ANode{xs, ys} : Array<T>}},
                        {(%s : {U32.shl(m) == Pair.snd(Array<T>, U32, Array.size.node(T, ys, _)) : U32}; %q : {U32.shl(m) == U32.shl(_) : U32}; {==}) : {U32.shl(m) == sz(T, ANode{b, ys}) : U32}},
                        {(%s : {(ANode{b, ys}, Pair.snd(Array<T>, U32, Array.size.node(T, ys, _))) == Array.size.node(T, ys, _) : Array<T> & U32}; {==}) : {(ANode{b, ys}, sz(T, ANode{b, ys})) == Array.size(T, ANode{b, ys}) : Array<T> & U32}},
                        Unit{})

def copy(-T: Data, a: Array<T>) -> Copy(T, a):
  match a:
    case ALeaf{x}:
      (ALeaf{x}, 1, {==}, {==}, {==}, Unit{})
    case ANode{xs, ys}:
      copy_node(T, xs, ys, copy(T, xs))

def J(+i: U32, +n: U32) -> U32:
  U32.and(i, U32.sub(n, 1))

def Z(+i: U32, +n: U32) -> Bool:
  U32.is_lt(J(i, n), U32.shr(n))

def close_get(-T: Data, -b: Array<T>, +n: U32, +i: U32, +v: T, +q: {n == sz(T, b) : U32}, f: Facts(T, b, n, J(i, n), v, Z(i, n))) -> {Pair.snd(Array<T>, T, Array.get(T, Array.set(T, b, i, v), i)) == v : T}:
  match f:
    case Tuple{+c1, r1}:
      match r1:
        case Tuple{+c2, r2}:
          match r2:
            case Tuple{+c3, r3}:
              match r3:
                case Tuple{+c4, r4}:
                  match r4:
                    case Tuple{+c5, r5}:
                      %c1 : {Pair.snd(Array<T>, T, Array.get.at(T, i, Array.size(T, Array.set.fin(T, Array.swap.at(T, i, v, _))))) == v : T}
                      %q : {Pair.snd(Array<T>, T, Array.get.at(T, i, Array.size(T, Array.set.fin(T, Array.swap.go(T, b, _, J(i, _), v, Z(i, _)))))) == v : T}
                      %c3 : {Pair.snd(Array<T>, T, Array.get.at(T, i, _)) == v : T}
                      %Equal.trans(U32, n, sz(T, b), sz(T, NA(T, b, n, J(i, n), v, Z(i, n))), q, Equal.sym(U32, sz(T, NA(T, b, n, J(i, n), v, Z(i, n))), sz(T, b), c4)) : {Pair.snd(Array<T>, T, Array.get.go(T, NA(T, b, n, J(i, n), v, Z(i, n)), _, J(i, _), Z(i, _))) == v : T}
                      c5

def top_get(-T: Data, -a: Array<T>, +i: U32, +v: T, r: Copy(T, a)) -> {Pair.snd(Array<T>, T, Array.get(T, Array.set(T, a, i, v), i)) == v : T}:
  match r:
    case Tuple{b, r1}:
      match r1:
        case Tuple{+n, r2}:
          match r2:
            case Tuple{+p, r3}:
              match r3:
                case Tuple{+q, r4}:
                  %p : {Pair.snd(Array<T>, T, Array.get(T, Array.set(T, _, i, v), i)) == v : T}
                  close_get(T, b, n, i, v, q, facts(T, b, n, J(i, n), v, Z(i, n)))

law get_after_set:
  for -T: Data
  for a: Array<T>
  for +i: U32
  for +v: T
  {Pair.snd(Array<T>, T, Array.get(T, Array.set(T, a, i, v), i)) == v : T}

def get_after_set(T, a, i, v):
  top_get(T, a, i, v, copy(T, a))


def Read(-T: Data, -r: Array<T> & T, -v: T) -> Type:
  {Pair.snd(Array<T>, T, r) == v : T} & {(Pair.fst(Array<T>, T, r), Pair.snd(Array<T>, T, r)) == r : Array<T> & T} & Unit

def close_read(-T: Data, -b: Array<T>, +n: U32, +i: U32, +v: T, +q: {n == sz(T, b) : U32}, f: Facts(T, b, n, J(i, n), v, Z(i, n))) -> Read(T, Array.get(T, Array.set(T, b, i, v), i), v):
  match f:
    case Tuple{+c1, Tuple{+c2, Tuple{+c3, Tuple{+c4, Tuple{+c5, Tuple{+c6, u}}}}}}:
      %c1 : Read(T, Array.get.at(T, i, Array.size(T, Array.set.fin(T, Array.swap.at(T, i, v, _)))), v)
      %q : Read(T, Array.get.at(T, i, Array.size(T, Array.set.fin(T, Array.swap.go(T, b, _, J(i, _), v, Z(i, _))))), v)
      %c3 : Read(T, Array.get.at(T, i, _), v)
      %Equal.trans(U32, n, sz(T, b), sz(T, NA(T, b, n, J(i, n), v, Z(i, n))), q, Equal.sym(U32, sz(T, NA(T, b, n, J(i, n), v, Z(i, n))), sz(T, b), c4)) : Read(T, Array.get.go(T, NA(T, b, n, J(i, n), v, Z(i, n)), _, J(i, _), Z(i, _)), v)
      (c5, c6, Unit{})

def top_read(-T: Data, -a: Array<T>, +i: U32, +v: T, r: Copy(T, a)) -> Read(T, Array.get(T, Array.set(T, a, i, v), i), v):
  match r:
    case Tuple{b, Tuple{+n, Tuple{+p, Tuple{+q, r4}}}}:
      %p : Read(T, Array.get(T, Array.set(T, _, i, v), i), v)
      close_read(T, b, n, i, v, q, facts(T, b, n, J(i, n), v, Z(i, n)))

def read_after_set(-T: Data, a: Array<T>, +i: U32, +v: T) -> Read(T, Array.get(T, Array.set(T, a, i, v), i), v):
  top_read(T, a, i, v, copy(T, a))

type Tree<-T: Data> is Data:
  Leaf{value: T}
  Node{left: Tree<T>, right: Tree<T>}

def reify(-T: Data, t: Tree<T>) -> Array<T>:
  match t:
    case Leaf{x}:
      ALeaf{x}
    case Node{xs, ys}:
      ANode{reify(T, xs), reify(T, ys)}

def size(-T: Data, t: Tree<T>) -> U32:
  match t:
    case Leaf{x}:
      1
    case Node{xs, ys}:
      U32.shl(size(T, xs))

def tree_size(-T: Data, +t: Tree<T>) -> {(reify(T, t), size(T, t)) == Array.size(T, reify(T, t)) : Array<T> & U32}:
  match t:
    case Leaf{x}:
      {==}
    case Node{xs, ys}:
      %tree_size(T, xs) : {(reify(T, t), size(T, t)) == Array.size.node(T, reify(T, ys), _) : Array<T> & U32}
      {==}

def read.go(-T: Data, t: Tree<T>, +n: U32, +i: U32, z: Bool) -> T:
  match t z:
    case Leaf{x} _:
      x
    case Node{xs, ys} True{}:
      read.go(T, xs, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n))))
    case Node{xs, ys} False{}:
      read.go(T, ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n))))

def read(-T: Data, +t: Tree<T>, +i: U32) -> T:
  read.go(T, t, size(T, t), J(i, size(T, t)), Z(i, size(T, t)))

def tree_get.go(-T: Data, +t: Tree<T>, +n: U32, +i: U32, +z: Bool) -> {(reify(T, t), read.go(T, t, n, i, z)) == Array.get.go(T, reify(T, t), n, i, z) : Array<T> & T}:
  match t z:
    case Leaf{x} _:
      {==}
    case Node{xs, ys} True{}:
      %tree_get.go(T, xs, U32.shr(n), i, U32.is_lt(i, U32.shr(U32.shr(n)))) : {(reify(T, t), read.go(T, t, n, i, True{})) == Array.swap.lo(T, reify(T, ys), _) : Array<T> & T}
      {==}
    case Node{xs, ys} False{}:
      %tree_get.go(T, ys, U32.shr(n), U32.sub(i, U32.shr(n)), U32.is_lt(U32.sub(i, U32.shr(n)), U32.shr(U32.shr(n)))) : {(reify(T, t), read.go(T, t, n, i, False{})) == Array.swap.hi(T, reify(T, xs), _) : Array<T> & T}
      {==}

def tree_get(-T: Data, +t: Tree<T>, +i: U32) -> {(reify(T, t), read(T, t, i)) == Array.get(T, reify(T, t), i) : Array<T> & T}:
  %tree_size(T, t) : {(reify(T, t), read(T, t, i)) == Array.get.at(T, i, _) : Array<T> & T}
  tree_get.go(T, t, size(T, t), J(i, size(T, t)), Z(i, size(T, t)))

def Snapshot(-T: Data, -a: Array<T>) -> Type:
  &t: Tree<T> -> {reify(T, t) == a : Array<T>} & Unit

def snapshot_node(-T: Data, -a: Array<T>, -b: Array<T>, sa: Snapshot(T, a), sb: Snapshot(T, b)) -> Snapshot(T, ANode{a, b}):
  match sa sb:
    case Tuple{+ta, Tuple{+ea, ua}} Tuple{+tb, Tuple{+eb, ub}}:
      (Node{ta, tb}, (
        %ea : {ANode{reify(T, ta), reify(T, tb)} == ANode{_, b} : Array<T>}
        %eb : {ANode{reify(T, ta), reify(T, tb)} == ANode{reify(T, ta), _} : Array<T>}
        {==}), Unit{})

def snapshot(-T: Data, a: Array<T>) -> Snapshot(T, a):
  match a:
    case ALeaf{x}:
      (Leaf{x}, {==}, Unit{})
    case ANode{xs, ys}:
      snapshot_node(T, xs, ys, snapshot(T, xs), snapshot(T, ys))
