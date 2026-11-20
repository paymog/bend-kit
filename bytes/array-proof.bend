# Pure perfect-tree Array<U32> laws for the one, two, and four-word decimal buffers.
import Base
import bend-kit-lemmas@0.1.5.1/lemmas.bend as Lemmas
import bend-mathlib@0.8.0.0/nat.bend as MNat
import bend-mathlib@0.8.0.0/bool.bend as MBool

def nth(l: List<&2, U32>, i: Nat) -> U32:
  match l:
    case Nil{}:
      0
    case Con{h, t}:
      match i:
        case 0n:
          h
        case 1n+p:
          nth(t, p)

def upd(l: List<&2, U32>, i: Nat, v: U32) -> List<&2, U32>:
  match l:
    case Nil{}:
      Nil{}
    case Con{h, t}:
      match i:
        case 0n:
          Con{v, t}
        case 1n+p:
          Con{h, upd(t, p, v)}

def len(l: List<&2, U32>) -> Nat:
  match l:
    case Nil{}:
      0n
    case Con{h, t}:
      1n+len(t)

def drop(k: Nat, l: List<&2, U32>) -> List<&2, U32>:
  match k:
    case 0n:
      l
    case 1n+p:
      match l:
        case Nil{}:
          Nil{}
        case Con{h, t}:
          drop(p, t)

# The model itself is unrestricted; the Array bridge below needs only depth < 3.
def build(+d: Nat, +l: List<&2, U32>) -> Array<U32>:
  match d:
    case 0n:
      ALeaf{nth(l, 0n)}
    case 1n++e:
      ANode{build(e, l), build(e, drop(Lemmas.pow2(e), l))}

def index_zero(n: Nat, h: MNat.lt(n, 1n)) -> {0n == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      Empty.absurd({0n == 1n+p : Nat}, MNat.lt_zero(p)(h))

def nth_drop(+k: Nat, +l: List<&2, U32>, +i: Nat) -> {nth(drop(k, l), i) == nth(l, Nat.add(k, i)) : U32}:
  match k:
    case 0n:
      {==}
    case 1n++p:
      match l:
        case Nil{}:
          {==}
        case Con{+a, +t}:
          nth_drop(p, t, i)

def get_leaf(+l: List<&2, U32>, +x: U32, e: {0n == U32.to_nat(x) : Nat}) -> {Array.get(U32, build(0n, l), x) == (build(0n, l), nth(l, 0n)) : Array<U32> & U32}:
  %Lemmas.u32_to_nat_inj(0, x, e) : {Array.get(U32, build(0n, l), _) == (build(0n, l), nth(l, 0n)) : Array<U32> & U32}
  {==}

def get_pair(n: Nat, +l: List<&2, U32>, +x: U32, e: {n == U32.to_nat(x) : Nat}, h: MNat.lt(n, 2n)) -> {Array.get(U32, build(1n, l), x) == (build(1n, l), nth(l, n)) : Array<U32> & U32}:
  match n:
    case 0n:
      %Lemmas.u32_to_nat_inj(0, x, e) : {Array.get(U32, build(1n, l), _) == (build(1n, l), nth(l, 0n)) : Array<U32> & U32}
      {==}
    case 1n+p:
      match p:
        case 0n:
          %Lemmas.u32_to_nat_inj(1, x, e) : {Array.get(U32, build(1n, l), _) == (build(1n, l), nth(l, 1n)) : Array<U32> & U32}
          %nth_drop(1n, l, 0n) : {Array.get(U32, build(1n, l), 1) == (build(1n, l), _) : Array<U32> & U32}
          {==}
        case 1n+q:
          Empty.absurd({Array.get(U32, build(1n, l), x) == (build(1n, l), nth(l, 2n+q)) : Array<U32> & U32}, MNat.lt_zero(q)(h))

def get_quad(n: Nat, +l: List<&2, U32>, +x: U32, e: {n == U32.to_nat(x) : Nat}, h: MNat.lt(n, 4n)) -> {Array.get(U32, build(2n, l), x) == (build(2n, l), nth(l, n)) : Array<U32> & U32}:
  match n:
    case 0n:
      %Lemmas.u32_to_nat_inj(0, x, e) : {Array.get(U32, build(2n, l), _) == (build(2n, l), nth(l, 0n)) : Array<U32> & U32}
      {==}
    case 1n+p:
      match p:
        case 0n:
          %Lemmas.u32_to_nat_inj(1, x, e) : {Array.get(U32, build(2n, l), _) == (build(2n, l), nth(l, 1n)) : Array<U32> & U32}
          %nth_drop(1n, l, 0n) : {Array.get(U32, build(2n, l), 1) == (build(2n, l), _) : Array<U32> & U32}
          {==}
        case 1n+q:
          match q:
            case 0n:
              %Lemmas.u32_to_nat_inj(2, x, e) : {Array.get(U32, build(2n, l), _) == (build(2n, l), nth(l, 2n)) : Array<U32> & U32}
              %nth_drop(2n, l, 0n) : {Array.get(U32, build(2n, l), 2) == (build(2n, l), _) : Array<U32> & U32}
              {==}
            case 1n+r:
              match r:
                case 0n:
                  %Lemmas.u32_to_nat_inj(3, x, e) : {Array.get(U32, build(2n, l), _) == (build(2n, l), nth(l, 3n)) : Array<U32> & U32}
                  %nth_drop(2n, l, 1n) : {Array.get(U32, build(2n, l), 3) == (build(2n, l), _) : Array<U32> & U32}
                  %nth_drop(1n, drop(2n, l), 0n) : {Array.get(U32, build(2n, l), 3) == (build(2n, l), _) : Array<U32> & U32}
                  {==}
                case 1n+s:
                  Empty.absurd({Array.get(U32, build(2n, l), x) == (build(2n, l), nth(l, 4n+s)) : Array<U32> & U32}, MNat.lt_zero(s)(h))

# Read preserves the entire affine tree and returns the logical list entry.
def get_small(+d: Nat, +l: List<&2, U32>, +x: U32, hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(x), Lemmas.pow2(d))) -> {Array.get(U32, build(d, l), x) == (build(d, l), nth(l, U32.to_nat(x))) : Array<U32> & U32}:
  match d:
    case 0n:
      %index_zero(U32.to_nat(x), hi) : {Array.get(U32, build(0n, l), x) == (build(0n, l), nth(l, _)) : Array<U32> & U32}
      get_leaf(l, x, index_zero(U32.to_nat(x), hi))
    case 1n+p:
      match p:
        case 0n:
          get_pair(U32.to_nat(x), l, x, {==}, hi)
        case 1n+q:
          match q:
            case 0n:
              get_quad(U32.to_nat(x), l, x, {==}, hi)
            case 1n+r:
              Empty.absurd({Array.get(U32, build(3n+r, l), x) == (build(3n+r, l), nth(l, U32.to_nat(x))) : Array<U32> & U32}, MNat.lt_zero(r)(hd))

def set_leaf(+a: U32, +t: List<&2, U32>, +x: U32, +v: U32, e: {0n == U32.to_nat(x) : Nat}) -> {Array.set(U32, build(0n, Con{a, t}), x, v) == build(0n, upd(Con{a, t}, U32.to_nat(x), v)) : Array<U32>}:
  %Lemmas.u32_to_nat_inj(0, x, e) : {Array.set(U32, build(0n, Con{a, t}), _, v) == build(0n, upd(Con{a, t}, U32.to_nat(_), v)) : Array<U32>}
  {==}

def set_pair(n: Nat, +a: U32, +b: U32, +t: List<&2, U32>, +x: U32, +v: U32, e: {n == U32.to_nat(x) : Nat}, h: MNat.lt(n, 2n)) -> {Array.set(U32, build(1n, Con{a, Con{b, t}}), x, v) == build(1n, upd(Con{a, Con{b, t}}, U32.to_nat(x), v)) : Array<U32>}:
  match n:
    case 0n:
      %Lemmas.u32_to_nat_inj(0, x, e) : {Array.set(U32, build(1n, Con{a, Con{b, t}}), _, v) == build(1n, upd(Con{a, Con{b, t}}, U32.to_nat(_), v)) : Array<U32>}
      {==}
    case 1n+p:
      match p:
        case 0n:
          %Lemmas.u32_to_nat_inj(1, x, e) : {Array.set(U32, build(1n, Con{a, Con{b, t}}), _, v) == build(1n, upd(Con{a, Con{b, t}}, U32.to_nat(_), v)) : Array<U32>}
          {==}
        case 1n+q:
          Empty.absurd({Array.set(U32, build(1n, Con{a, Con{b, t}}), x, v) == build(1n, upd(Con{a, Con{b, t}}, U32.to_nat(x), v)) : Array<U32>}, MNat.lt_zero(q)(h))

def set_quad(n: Nat, +a: U32, +b: U32, +c: U32, +d: U32, +t: List<&2, U32>, +x: U32, +v: U32, e: {n == U32.to_nat(x) : Nat}, h: MNat.lt(n, 4n)) -> {Array.set(U32, build(2n, Con{a, Con{b, Con{c, Con{d, t}}}}), x, v) == build(2n, upd(Con{a, Con{b, Con{c, Con{d, t}}}}, U32.to_nat(x), v)) : Array<U32>}:
  match n:
    case 0n:
      %Lemmas.u32_to_nat_inj(0, x, e) : {Array.set(U32, build(2n, Con{a, Con{b, Con{c, Con{d, t}}}}), _, v) == build(2n, upd(Con{a, Con{b, Con{c, Con{d, t}}}}, U32.to_nat(_), v)) : Array<U32>}
      {==}
    case 1n+p:
      match p:
        case 0n:
          %Lemmas.u32_to_nat_inj(1, x, e) : {Array.set(U32, build(2n, Con{a, Con{b, Con{c, Con{d, t}}}}), _, v) == build(2n, upd(Con{a, Con{b, Con{c, Con{d, t}}}}, U32.to_nat(_), v)) : Array<U32>}
          {==}
        case 1n+q:
          match q:
            case 0n:
              %Lemmas.u32_to_nat_inj(2, x, e) : {Array.set(U32, build(2n, Con{a, Con{b, Con{c, Con{d, t}}}}), _, v) == build(2n, upd(Con{a, Con{b, Con{c, Con{d, t}}}}, U32.to_nat(_), v)) : Array<U32>}
              {==}
            case 1n+r:
              match r:
                case 0n:
                  %Lemmas.u32_to_nat_inj(3, x, e) : {Array.set(U32, build(2n, Con{a, Con{b, Con{c, Con{d, t}}}}), _, v) == build(2n, upd(Con{a, Con{b, Con{c, Con{d, t}}}}, U32.to_nat(_), v)) : Array<U32>}
                  {==}
                case 1n+s:
                  Empty.absurd({Array.set(U32, build(2n, Con{a, Con{b, Con{c, Con{d, t}}}}), x, v) == build(2n, upd(Con{a, Con{b, Con{c, Con{d, t}}}}, U32.to_nat(x), v)) : Array<U32>}, MNat.lt_zero(s)(h))

# A sufficient source list makes the model's ordinary list update exact.
def set_small(+d: Nat, +l: List<&2, U32>, +x: U32, +v: U32, hd: MNat.lt(d, 3n), hi: MNat.lt(U32.to_nat(x), Lemmas.pow2(d)), hl: MNat.le(Lemmas.pow2(d), len(l))) -> {Array.set(U32, build(d, l), x, v) == build(d, upd(l, U32.to_nat(x), v)) : Array<U32>}:
  match d:
    case 0n:
      match l:
        case Nil{}:
          Empty.absurd({Array.set(U32, build(0n, Nil{}), x, v) == build(0n, upd(Nil{}, U32.to_nat(x), v)) : Array<U32>}, MBool.false_ne_true()(hl))
        case Con{+a, +t}:
          set_leaf(a, t, x, v, index_zero(U32.to_nat(x), hi))
    case 1n+p:
      match p:
        case 0n:
          match l:
            case Nil{}:
              Empty.absurd({Array.set(U32, build(1n, Nil{}), x, v) == build(1n, upd(Nil{}, U32.to_nat(x), v)) : Array<U32>}, MBool.false_ne_true()(hl))
            case Con{+a, +t}:
              match t:
                case Nil{}:
                  Empty.absurd({Array.set(U32, build(1n, [a]), x, v) == build(1n, upd([a], U32.to_nat(x), v)) : Array<U32>}, MBool.false_ne_true()(hl))
                case Con{+b, +u}:
                  set_pair(U32.to_nat(x), a, b, u, x, v, {==}, hi)
        case 1n+q:
          match q:
            case 0n:
              match l:
                case Nil{}:
                  Empty.absurd({Array.set(U32, build(2n, Nil{}), x, v) == build(2n, upd(Nil{}, U32.to_nat(x), v)) : Array<U32>}, MBool.false_ne_true()(hl))
                case Con{+a, +t}:
                  match t:
                    case Nil{}:
                      Empty.absurd({Array.set(U32, build(2n, [a]), x, v) == build(2n, upd([a], U32.to_nat(x), v)) : Array<U32>}, MBool.false_ne_true()(hl))
                    case Con{+b, +u}:
                      match u:
                        case Nil{}:
                          Empty.absurd({Array.set(U32, build(2n, [a, b]), x, v) == build(2n, upd([a, b], U32.to_nat(x), v)) : Array<U32>}, MBool.false_ne_true()(hl))
                        case Con{+c, +s}:
                          match s:
                            case Nil{}:
                              Empty.absurd({Array.set(U32, build(2n, [a, b, c]), x, v) == build(2n, upd([a, b, c], U32.to_nat(x), v)) : Array<U32>}, MBool.false_ne_true()(hl))
                            case Con{+w, +r}:
                              set_quad(U32.to_nat(x), a, b, c, w, r, x, v, {==}, hi)
            case 1n+r:
              Empty.absurd({Array.set(U32, build(3n+r, l), x, v) == build(3n+r, upd(l, U32.to_nat(x), v)) : Array<U32>}, MNat.lt_zero(r)(hd))

def len_upd(+l: List<&2, U32>, +i: Nat, +v: U32) -> {len(upd(l, i, v)) == len(l) : Nat}:
  match l:
    case Nil{}:
      {==}
    case Con{+a, +t}:
      match i:
        case 0n:
          {==}
        case 1n++p:
          %len_upd(t, p, v) : {1n+len(upd(t, p, v)) == 1n+_ : Nat}
          {==}

def nth_upd_same(+l: List<&2, U32>, +i: Nat, +v: U32, h: MNat.lt(i, len(l))) -> {nth(upd(l, i, v), i) == v : U32}:
  match l:
    case Nil{}:
      Empty.absurd({nth(upd(Nil{}, i, v), i) == v : U32}, MNat.lt_zero(i)(h))
    case Con{+a, +t}:
      match i:
        case 0n:
          {==}
        case 1n++p:
          nth_upd_same(t, p, v, h)

def nth_upd_other(+l: List<&2, U32>, +i: Nat, +j: Nat, +v: U32, h: {Nat.is_eq(i, j) == False{} : Bool}) -> {nth(upd(l, i, v), j) == nth(l, j) : U32}:
  match l:
    case Nil{}:
      {==}
    case Con{+a, +t}:
      match i:
        case 0n:
          match j:
            case 0n:
              Empty.absurd({nth(upd(Con{a, t}, 0n, v), 0n) == nth(Con{a, t}, 0n) : U32}, MBool.false_ne_true()(Equal.sym(Bool, True{}, False{}, h)))
            case 1n+q:
              {==}
        case 1n++p:
          match j:
            case 0n:
              {==}
            case 1n++q:
              nth_upd_other(t, p, q, v, h)

# Uniform initialization bridges the actual allocator and the list model.
def replicate(n: Nat, +v: U32) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Con{v, replicate(p, v)}

def new_small(+d: Nat, +v: U32, hd: MNat.lt(d, 3n)) -> {Array.new(U32, d, v) == build(d, replicate(Lemmas.pow2(d), v)) : Array<U32>}:
  match d:
    case 0n:
      {==}
    case 1n+p:
      match p:
        case 0n:
          {==}
        case 1n+q:
          match q:
            case 0n:
              {==}
            case 1n+r:
              Empty.absurd({Array.new(U32, 3n+r, v) == build(3n+r, replicate(Lemmas.pow2(3n+r), v)) : Array<U32>}, MNat.lt_zero(r)(hd))

def lt_le_trans(+a: Nat, +b: Nat, +c: Nat, hab: MNat.lt(a, b), hbc: MNat.le(b, c)) -> MNat.lt(a, c):
  match a:
    case 0n:
      match b:
        case 0n:
          Empty.absurd(MNat.lt(0n, c), MBool.false_ne_true()(hab))
        case 1n+q:
          match c:
            case 0n:
              Empty.absurd(MNat.lt(0n, 0n), MBool.false_ne_true()(hbc))
            case 1n+r:
              {==}
    case 1n++p:
      match b:
        case 0n:
          Empty.absurd(MNat.lt(1n+p, c), MBool.false_ne_true()(hab))
        case 1n++q:
          match c:
            case 0n:
              Empty.absurd(MNat.lt(1n+p, 0n), MBool.false_ne_true()(hbc))
            case 1n++r:
              lt_le_trans(p, q, r, hab, hbc)

# Both conclusions retain the updated tree, rather than discarding affine state.
def get_set_same(+d: Nat, +l: List<&2, U32>, +x: U32, +v: U32, +hd: MNat.lt(d, 3n), +hi: MNat.lt(U32.to_nat(x), Lemmas.pow2(d)), +hl: MNat.le(Lemmas.pow2(d), len(l))) -> {Array.get(U32, Array.set(U32, build(d, l), x, v), x) == (Array.set(U32, build(d, l), x, v), v) : Array<U32> & U32}:
  %Equal.sym(Array<U32>, Array.set(U32, build(d, l), x, v), build(d, upd(l, U32.to_nat(x), v)), set_small(d, l, x, v, hd, hi, hl)) : {Array.get(U32, _, x) == (_, v) : Array<U32> & U32}
  %nth_upd_same(l, U32.to_nat(x), v, lt_le_trans(U32.to_nat(x), Lemmas.pow2(d), len(l), hi, hl)) : {Array.get(U32, build(d, upd(l, U32.to_nat(x), v)), x) == (build(d, upd(l, U32.to_nat(x), v)), _) : Array<U32> & U32}
  get_small(d, upd(l, U32.to_nat(x), v), x, hd, hi)

def get_set_other(+d: Nat, +l: List<&2, U32>, +x: U32, +y: U32, +v: U32, +hd: MNat.lt(d, 3n), hx: MNat.lt(U32.to_nat(x), Lemmas.pow2(d)), hy: MNat.lt(U32.to_nat(y), Lemmas.pow2(d)), hl: MNat.le(Lemmas.pow2(d), len(l)), hne: {Nat.is_eq(U32.to_nat(x), U32.to_nat(y)) == False{} : Bool}) -> {Array.get(U32, Array.set(U32, build(d, l), x, v), y) == (Array.set(U32, build(d, l), x, v), nth(l, U32.to_nat(y))) : Array<U32> & U32}:
  %Equal.sym(Array<U32>, Array.set(U32, build(d, l), x, v), build(d, upd(l, U32.to_nat(x), v)), set_small(d, l, x, v, hd, hx, hl)) : {Array.get(U32, _, y) == (_, nth(l, U32.to_nat(y))) : Array<U32> & U32}
  %nth_upd_other(l, U32.to_nat(x), U32.to_nat(y), v, hne) : {Array.get(U32, build(d, upd(l, U32.to_nat(x), v)), y) == (build(d, upd(l, U32.to_nat(x), v)), _) : Array<U32> & U32}
  get_small(d, upd(l, U32.to_nat(x), v), y, hd, hy)
